///|
/// XLSX MVP parser (MoonBit)
/// - ZIP: reuse src/docx/zip_min.mbt
/// - XML parsing: lightweight string scanning (good enough for MVP)
/// - Output: Heading + Table per sheet
///
/// Limitations (MVP):
/// - no styles, no formula evaluation
/// - merged cells ignored
/// - inlineStr not handled yet (only sharedStrings "t=s" and numeric/default)
pub async fn parse_xlsx(
  input_path : String,
  _out_dir : String,
  max_heading : Int,
) -> @cor.Document raise {
  // 1) open zip
  let z = @cor.open_zip(input_path) catch {
    e => raise @cor.AppError("xlsx: open zip failed: " + e.to_string())
  }

  // 2) read workbook.xml + rels
  let wb_xml = read_zip_utf8(z, "xl/workbook.xml")
  let rels_xml = read_zip_utf8(z, "xl/_rels/workbook.xml.rels")

  // 3) sharedStrings.xml is optional
  let shared : Array[String] = if @cor.ZipReader::has_entry(
      z, "xl/sharedStrings.xml",
    ) {
    let ss_xml = read_zip_utf8(z, "xl/sharedStrings.xml")
    parse_shared_strings(ss_xml)
  } else {
    []
  }

  // 4) parse sheets
  let sheets = parse_workbook_sheets(wb_xml, rels_xml)

  // 5) build IR
  let doc = @cor.new_document()
  @cor.push(doc, @cor.Block::Heading(clamp_heading(1, max_heading), "XLSX"))

  if sheets.length() == 0 {
    @cor.push(doc, @cor.Block::Paragraph("(no sheets found)"))
    return doc
  }

  for i in 0..<sheets.length() {
    let sh = sheets[i]
    @cor.push(doc, @cor.Block::Heading(clamp_heading(2, max_heading), sh.name))

    let sheet_path = if sh.target.has_prefix("/") {
      // uncommon
      sh.target.trim().to_string()
    } else {
      // usually: "worksheets/sheet1.xml"
      "xl/" + sh.target
    }

    if !@cor.ZipReader::has_entry(z, sheet_path) {
      @cor.push(
        doc,
        @cor.Block::Paragraph("(missing sheet xml: " + sheet_path + ")"),
      )
      @cor.push(doc, @cor.Block::BlankLine)
      continue
    }

    let sh_xml = read_zip_utf8(z, sheet_path)
    let table = parse_sheet_table(sh_xml, shared)

    if table.length() == 0 {
      @cor.push(doc, @cor.Block::Paragraph("(empty sheet)"))
    } else {
      @cor.push(doc, @cor.Block::Table(table))
    }

    @cor.push(doc, @cor.Block::BlankLine)
  }

  doc
}

// ============================
// Types
// ============================

///|
pub(all) struct SheetInfo {
  name : String
  rid : String
  target : String
}

// ============================
// ZIP -> UTF8 string
// ============================

///|
async fn read_zip_utf8(z : @cor.ZipReader, name : String) -> String raise {
  let bs = @cor.ZipReader::read_entry_bytes(z, name) catch {
    e =>
      raise @cor.AppError(
        "xlsx: read zip entry failed: " + name + ": " + e.to_string(),
      )
  }
  @cor.utf8_bytes_to_string(bs) catch {
    e =>
      raise @cor.AppError(
        "xlsx: invalid utf8 in " + name + ": " + e.to_string(),
      )
  }
}

// ============================
// Workbook + rels parsing
// ============================

///|
fn parse_workbook_sheets(
  wb_xml : String,
  rels_xml : String,
) -> Array[SheetInfo] raise {
  let rel_map = parse_rels_id_to_target(rels_xml)
  let out : Array[SheetInfo] = []

  let mut pos = 0
  while true {
    let idx = find_sub(wb_xml, "<sheet", pos)
    match idx {
      None => break
      Some(i0) => {
        let j = find_sub(wb_xml, ">", i0)
        match j {
          None => break
          Some(i1) => {
            let tag = wb_xml[i0:i1 + 1].to_string()
            let name = get_attr(tag, "name").unwrap_or("Sheet")
            let rid = get_attr(tag, "r:id").unwrap_or("")
            if rid != "" {
              let target = rel_map.get(rid).unwrap_or("")
              out.push({ name, rid, target })
            }
            pos = i1 + 1
          }
        }
      }
    }
  }

  out
}

// <Relationship Id="rId1" Target="worksheets/sheet1.xml" .../>

///|
fn parse_rels_id_to_target(rels_xml : String) -> Map[String, String] raise {
  let m : Map[String, String] = Map::new()
  let mut pos = 0

  while true {
    let idx = find_sub(rels_xml, "<Relationship", pos)
    match idx {
      None => break
      Some(i0) => {
        let j = find_sub(rels_xml, ">", i0)
        match j {
          None => break
          Some(i1) => {
            let tag = rels_xml[i0:i1 + 1].to_string()
            let id = get_attr(tag, "Id").unwrap_or("")
            let target = get_attr(tag, "Target").unwrap_or("")
            if id != "" && target != "" {
              m.set(id, target)
            }
            pos = i1 + 1
          }
        }
      }
    }
  }

  m
}

// ============================
// sharedStrings.xml parsing
// ============================
//
// Common:
// <si><t>hello</t></si>
// Rich text:
// <si><r><t>he</t></r><r><t>llo</t></r></si>
// MVP: concat all <t> contents inside <si>

///|
fn parse_shared_strings(ss_xml : String) -> Array[String] raise {
  let out : Array[String] = []
  let mut pos = 0

  while true {
    let si0 = find_sub(ss_xml, "<si", pos)
    match si0 {
      None => break
      Some(si_start) => {
        let si_end0 = find_sub(ss_xml, "</si>", si_start)
        match si_end0 {
          None => break
          Some(si_end) => {
            let chunk = ss_xml[si_start:si_end].to_string()

            let mut tpos = 0
            let mut acc = ""
            while true {
              let t0 = find_sub(chunk, "<t", tpos)
              match t0 {
                None => break
                Some(t_start) => {
                  let ttag_end = find_sub(chunk, ">", t_start)
                  match ttag_end {
                    None => break
                    Some(t_end_tag) => {
                      let content_start = t_end_tag + 1
                      let t1 = find_sub(chunk, "</t>", content_start)
                      match t1 {
                        None => break
                        Some(t_end) => {
                          let content = chunk[content_start:t_end].to_string()
                          acc = acc + content
                          tpos = t_end + 4
                        }
                      }
                    }
                  }
                }
              }
            }

            out.push(xml_unescape(acc))
            pos = si_end + 5
          }
        }
      }
    }
  }

  out
}

// ============================
// sheet xml -> table
// ============================
//
// Scan for cells:
// <c r="A1" t="s"><v>0</v></c>
// - r: cell reference
// - t="s": sharedStrings index in <v>
// - otherwise: <v> literal (usually number)

///|
fn parse_sheet_table(
  sheet_xml : String,
  shared : Array[String],
) -> Array[Array[String]] raise {
  let cells : Map[String, String] = Map::new()
  let mut max_r = 0
  let mut max_c = 0

  let mut pos = 0
  while true {
    let c0 = find_sub(sheet_xml, "<c", pos)
    match c0 {
      None => break
      Some(i0) => {
        let ctag_end0 = find_sub(sheet_xml, ">", i0)
        match ctag_end0 {
          None => break
          Some(i1) => {
            let ctag = sheet_xml[i0:i1 + 1].to_string()

            let rref = get_attr(ctag, "r").unwrap_or("")
            let t = get_attr(ctag, "t").unwrap_or("") // "s" for shared string

            let c_end0 = find_sub(sheet_xml, "</c>", i1 + 1)
            match c_end0 {
              None => break
              Some(c_end) => {
                let inner = sheet_xml[i1 + 1:c_end].to_string()

                // first <v>...</v>
                let mut val = ""
                let v0 = find_sub(inner, "<v>", 0)
                match v0 {
                  None => ()
                  Some(v_start0) => {
                    let vs = v_start0 + 3
                    let v1 = find_sub(inner, "</v>", vs)
                    match v1 {
                      None => ()
                      Some(v_end) => val = inner[vs:v_end].to_string()
                    }
                  }
                }

                let (rr, cc) = cell_ref_to_rc(rref)
                if rr > 0 && cc > 0 {
                  if rr > max_r {
                    max_r = rr
                  }
                  if cc > max_c {
                    max_c = cc
                  }

                  let text = if t == "s" {
                    let idx = parse_int(val)
                    if idx >= 0 && idx < shared.length() {
                      shared[idx]
                    } else {
                      ""
                    }
                  } else {
                    // Note: could also be boolean/date/formula cached value etc.
                    xml_unescape(val)
                  }

                  cells.set(rr.to_string() + "," + cc.to_string(), text)
                }

                pos = c_end + 4
              }
            }
          }
        }
      }
    }
  }

  if max_r == 0 || max_c == 0 {
    return []
  }

  let table : Array[Array[String]] = []
  for r in 1..<(max_r + 1) {
    let row : Array[String] = []
    for c in 1..<(max_c + 1) {
      let k = r.to_string() + "," + c.to_string()
      row.push(cells.get(k).unwrap_or(""))
    }
    table.push(row)
  }
  table
}

// ============================
// Utilities
// ============================

///|
fn clamp_heading(level : Int, max_h : Int) -> Int {
  if level < 1 {
    1
  } else if level > max_h {
    max_h
  } else {
    level
  }
}

///|
fn parse_int(s : String) -> Int {
  let t = @cor.trim_string(s)
  if t == "" {
    return -1
  }
  let chars = t.to_array()
  let mut i = 0
  let mut acc = 0
  while i < chars.length() {
    let ch = chars[i]
    if ch >= '0' && ch <= '9' {
      acc = acc * 10 + (ch.to_int() - '0'.to_int())
      i += 1
    } else {
      break
    }
  }
  acc
}

// cell ref like "BC12" -> (12, 55)

///|
fn cell_ref_to_rc(r : String) -> (Int, Int) {
  if r == "" {
    return (0, 0)
  }
  let chars = r.to_array()
  let mut i = 0
  let mut col = 0

  while i < chars.length() {
    let ch = chars[i]
    if ch >= 'A' && ch <= 'Z' {
      col = col * 26 + (ch.to_int() - 'A'.to_int() + 1)
      i += 1
    } else if ch >= 'a' && ch <= 'z' {
      col = col * 26 + (ch.to_int() - 'a'.to_int() + 1)
      i += 1
    } else {
      break
    }
  }

  let mut row = 0
  while i < chars.length() {
    let ch = chars[i]
    if ch >= '0' && ch <= '9' {
      row = row * 10 + (ch.to_int() - '0'.to_int())
      i += 1
    } else {
      break
    }
  }

  (row, col)
}

// naive substring search (MVP)

///|
fn find_sub(s : String, pat : String, start : Int) -> Int? raise {
  let n = s.length()
  let m = pat.length()
  if m == 0 {
    return Some(start)
  }
  if start < 0 || start >= n {
    return None
  }
  if n < m {
    return None
  }

  let last = n - m
  let mut i = start
  while i <= last {
    if s[i:i + m] == pat {
      return Some(i)
    }
    i += 1
  }
  None
}

// parse attr="value" (double quotes only, MVP)

///|
fn get_attr(tag : String, key : String) -> String? raise {
  let pat = key + "=\""
  let i0 = find_sub(tag, pat, 0)
  match i0 {
    None => None
    Some(p) => {
      let s0 = p + pat.length()
      let i1 = find_sub(tag, "\"", s0)
      match i1 {
        None => None
        Some(q) => Some(tag[s0:q].to_string())
      }
    }
  }
}

///|
fn xml_unescape(s : String) -> String {
  s
  .replace(old="&lt;", new="<")
  .replace(old="&gt;", new=">")
  .replace(old="&amp;", new="&")
  .replace(old="&quot;", new="\"")
  .replace(old="&apos;", new="'")
}
