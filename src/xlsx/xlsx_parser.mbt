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
) -> @cor.Document {
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

    let target0 = sh.target.trim().to_string()
    let target = if target0.has_prefix("/") { target0[1:] } else { target0 }
    let sheet_path = if target.has_prefix("xl/") {
      target.to_string()
    } else {
      "xl/" + target.to_string()
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
async fn read_zip_utf8(z : @cor.ZipReader, name : String) -> String {
  //println(".. xlsx: reading " + name)
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
fn xml_unescape(s : String) -> String raise {
  let t = s
    .replace(old="&lt;", new="<")
    .replace(old="&gt;", new=">")
    .replace(old="&amp;", new="&")
    .replace(old="&quot;", new="\"")
    .replace(old="&apos;", new="'")

  decode_numeric_entities(t)
}

///|
/// Decode numeric character references: &#1234; and &#x1F600;
fn decode_numeric_entities(s : String) -> String raise {
  let n = s.length()
  let out : Array[Char] = []
  let mut i = 0

  while i < n {
    // try "&#...;"
    if i + 1 < n && s[i] == '&' && s[i + 1] == '#' {
      // find ';'
      let mut j = i + 2
      while j < n && s[j] != ';' {
        j = j + 1
      }

      if j < n && s[j] == ';' {
        let body = s[i + 2:j].to_string().trim().to_string()

        let cp_opt = if body.has_prefix("x") || body.has_prefix("X") {
          parse_hex_int(body[1:].to_string())
        } else {
          parse_dec_int(body)
        }

        match cp_opt {
          Some(cp) => {
            out.push(Int::unsafe_to_char(cp))
            i = j + 1
            continue
          }
          None => () // fallthrough
        }
      }
    }

    // normal char: push char directly (DO NOT use to_string here)
    out.push(
      match s[i].to_char() {
        None => '_' // should not happen for valid UTF-8
        Some(c) => c
      },
    )
    i = i + 1
  }

  String::from_array(out)
}

///|
fn parse_dec_int(s : String) -> Int? {
  if s == "" {
    return None
  }
  let chars = s.to_array()
  let mut i = 0
  let mut acc = 0
  while i < chars.length() {
    let c = chars[i]
    if c >= '0' && c <= '9' {
      acc = acc * 10 + (c.to_int() - '0'.to_int())
      i = i + 1
    } else {
      return None
    }
  }
  Some(acc)
}

///|
fn hex_val(c : Char) -> Int? {
  if c >= '0' && c <= '9' {
    return Some(c.to_int() - '0'.to_int())
  }
  if c >= 'a' && c <= 'f' {
    return Some(c.to_int() - 'a'.to_int() + 10)
  }
  if c >= 'A' && c <= 'F' {
    return Some(c.to_int() - 'A'.to_int() + 10)
  }
  None
}

///|
fn parse_hex_int(s : String) -> Int? {
  if s == "" {
    return None
  }
  let chars = s.to_array()
  let mut i = 0
  let mut acc = 0
  while i < chars.length() {
    match hex_val(chars[i]) {
      None => return None
      Some(v) => {
        acc = (acc << 4) | v
        i = i + 1
      }
    }
  }
  Some(acc)
}
