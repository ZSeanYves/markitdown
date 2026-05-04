// ============================
// worksheet xml -> structured sheet model
// ============================

///|
priv struct ParsedCellXml {
  reference : String
  cell_type : String
  style_index : Int
  value : String
  formula_text : String?
  inner : String
}

///|
fn parse_sheet_model(
  sheet_name : String,
  relationship_id : String?,
  relationship_type : String?,
  part_target : String?,
  state : XlsxSheetState,
  sheet_xml : String,
  shared : Array[String],
  styles : XlsxStyles,
  uses_date_1904 : Bool,
) -> XlsxSheetModel {
  let parsed_cells = collect_sheet_cells(sheet_xml)
  let merged_ranges = parse_merged_ranges(sheet_xml)
  let cells : Array[XlsxCellModel] = []

  let mut min_r = 0
  let mut min_c = 0
  let mut max_r = 0
  let mut max_c = 0
  let cell_texts : Map[String, String] = Map::new()

  for parsed in parsed_cells {
    let (rr, cc) = cell_ref_to_rc(parsed.reference)
    if rr <= 0 || cc <= 0 {
      continue
    }

    let num_format_id = style_index_numfmt(styles, parsed.style_index)
    let (kind, text) = resolve_cell_display(
      parsed.cell_type,
      parsed.inner,
      parsed.value,
      shared,
      styles,
      num_format_id,
      uses_date_1904,
    )

    let source_value = if parsed.value.trim() == "" {
      None
    } else {
      Some(parsed.value)
    }
    let formula_text = parsed.formula_text
    cells.push({
      reference: parsed.reference,
      row: rr,
      column: cc,
      kind,
      display_text: text,
      source_value,
      formula_text,
      style_index: parsed.style_index,
      num_format_id,
    })
    cell_texts.set(rr.to_string() + "," + cc.to_string(), text)

    if @cor.trim_string(text) != "" {
      if min_r == 0 || rr < min_r {
        min_r = rr
      }
      if min_c == 0 || cc < min_c {
        min_c = cc
      }
      if rr > max_r {
        max_r = rr
      }
      if cc > max_c {
        max_c = cc
      }
    }
  }

  let rows = render_sheet_rows(cell_texts, min_r, min_c, max_r, max_c)
  {
    name: sheet_name,
    relationship_id,
    relationship_type,
    part_target,
    state,
    is_supported_worksheet: true,
    has_sheet_xml: true,
    cells,
    merged_ranges,
    table_rows: rows,
    header_rows: xlsx_header_rows(rows),
    used_min_row: min_r,
    used_min_col: min_c,
    used_max_row: if rows.length() == 0 {
      0
    } else {
      min_r + rows.length() - 1
    },
    used_max_col: table_width(rows),
  }
}

///|
fn empty_sheet_model(
  sheet_name : String,
  relationship_id : String?,
  relationship_type : String?,
  part_target : String?,
  state : XlsxSheetState,
  is_supported_worksheet : Bool,
  has_sheet_xml : Bool,
) -> XlsxSheetModel {
  {
    name: sheet_name,
    relationship_id,
    relationship_type,
    part_target,
    state,
    is_supported_worksheet,
    has_sheet_xml,
    cells: [],
    merged_ranges: [],
    table_rows: [],
    header_rows: 0,
    used_min_row: 0,
    used_min_col: 0,
    used_max_row: 0,
    used_max_col: 0,
  }
}

///|
fn collect_sheet_cells(sheet_xml : String) -> Array[ParsedCellXml] {
  let out : Array[ParsedCellXml] = []
  let mut pos = 0

  while true {
    let c0 = find_sub(sheet_xml, "<c ", pos)
    match c0 {
      None => break
      Some(i0) => {
        let ctag_end0 = find_sub(sheet_xml, ">", i0)
        match ctag_end0 {
          None => break
          Some(i1) => {
            let ctag = sheet_xml[i0:i1 + 1].to_owned()
            let rref = get_attr(ctag, "r").unwrap_or("")
            let cell_type = get_attr(ctag, "t").unwrap_or("")
            let style_idx = parse_int(get_attr(ctag, "s").unwrap_or(""))
            let c_end0 = find_sub(sheet_xml, "</c>", i1 + 1)
            match c_end0 {
              None => break
              Some(c_end) => {
                let inner = sheet_xml[i1 + 1:c_end].to_owned()
                let value = tag_text(inner, "v").unwrap_or("")
                let formula_text = tag_text(inner, "f")
                out.push({
                  reference: rref,
                  cell_type,
                  style_index: style_idx,
                  value,
                  formula_text,
                  inner,
                })
                pos = c_end + 4
              }
            }
          }
        }
      }
    }
  }

  out
}

///|
fn parse_merged_ranges(sheet_xml : String) -> Array[XlsxMergedRange] {
  let out : Array[XlsxMergedRange] = []
  let start0 = find_sub(sheet_xml, "<mergeCells", 0)
  match start0 {
    None => out
    Some(mc0) => {
      let gt0 = find_sub(sheet_xml, ">", mc0)
      match gt0 {
        None => out
        Some(mc1) => {
          let end0 = find_sub(sheet_xml, "</mergeCells>", mc1 + 1)
          match end0 {
            None => out
            Some(mc_end) => {
              let inner = sheet_xml[mc1 + 1:mc_end].to_owned()
              let mut pos = 0
              while true {
                let merge0 = find_sub(inner, "<mergeCell", pos)
                match merge0 {
                  None => break
                  Some(i0) => {
                    let merge1 = find_sub(inner, ">", i0)
                    match merge1 {
                      None => break
                      Some(i1) => {
                        let tag = inner[i0:i1 + 1].to_owned()
                        let range_ref = get_attr(tag, "ref").unwrap_or("")
                        match parse_merge_ref(range_ref) {
                          Some((r1, c1, r2, c2)) =>
                            out.push({
                              range_ref,
                              start_row: r1,
                              start_col: c1,
                              end_row: r2,
                              end_col: c2,
                            })
                          None => ()
                        }
                        pos = i1 + 1
                      }
                    }
                  }
                }
              }
              out
            }
          }
        }
      }
    }
  }
}

///|
fn parse_merge_ref(range_ref : String) -> (Int, Int, Int, Int)? {
  let parts : Array[String] = []
  for part in range_ref.split(":") {
    parts.push(part.to_owned())
  }
  if parts.length() != 2 {
    return None
  }
  let (r1, c1) = cell_ref_to_rc(parts[0])
  let (r2, c2) = cell_ref_to_rc(parts[1])
  if r1 <= 0 || c1 <= 0 || r2 <= 0 || c2 <= 0 {
    None
  } else {
    Some((r1, c1, r2, c2))
  }
}

///|
fn resolve_cell_display(
  cell_type : String,
  inner : String,
  val : String,
  shared : Array[String],
  styles : XlsxStyles,
  num_format_id : Int,
  uses_date_1904 : Bool,
) -> (XlsxCellKind, String) {
  if cell_type == "s" {
    let idx = parse_int(val)
    if idx >= 0 && idx < shared.length() {
      (XlsxCellKind::SharedString, shared[idx])
    } else {
      (XlsxCellKind::SharedString, "")
    }
  } else if cell_type == "inlineStr" {
    (XlsxCellKind::InlineString, parse_inline_str(inner))
  } else if cell_type == "b" {
    let v = @cor.trim_string(val)
    if v == "1" {
      (XlsxCellKind::Boolean, "TRUE")
    } else if v == "0" {
      (XlsxCellKind::Boolean, "FALSE")
    } else {
      (XlsxCellKind::Boolean, xml_unescape(v))
    }
  } else if cell_type == "str" {
    (XlsxCellKind::StringResult, xml_unescape(val))
  } else if cell_type == "e" {
    let v = @cor.trim_string(val)
    if v == "" {
      (XlsxCellKind::Error, "#ERROR!")
    } else {
      (XlsxCellKind::Error, v)
    }
  } else if @cor.trim_string(val) == "" {
    (XlsxCellKind::Blank, "")
  } else {
    let raw = xml_unescape(val)
    let rendered = if numfmt_is_builtin_datetime_like(num_format_id) {
      format_excel_datetime(raw, num_format_id, None, uses_date_1904)
    } else {
      match custom_numfmt_code(styles, num_format_id) {
        Some(code) =>
          if numfmt_code_is_datetime_like(code) {
            format_excel_datetime(
              raw,
              num_format_id,
              Some(code),
              uses_date_1904,
            )
          } else {
            raw
          }
        None => raw
      }
    }
    (XlsxCellKind::Number, rendered)
  }
}

///|
fn parse_inline_str(inner : String) -> String {
  let mut tpos = 0
  let mut acc = ""

  while true {
    let t0 = find_sub(inner, "<t", tpos)
    match t0 {
      None => break
      Some(t_start) => {
        let ttag_end = find_sub(inner, ">", t_start)
        match ttag_end {
          None => break
          Some(t_end_tag) => {
            let content_start = t_end_tag + 1
            let t1 = find_sub(inner, "</t>", content_start)
            match t1 {
              None => break
              Some(t_end) => {
                let content = inner[content_start:t_end].to_owned()
                acc = acc + xml_unescape(content)
                tpos = t_end + 4
              }
            }
          }
        }
      }
    }
  }

  acc
}

///|
fn render_sheet_rows(
  cells : Map[String, String],
  min_r : Int,
  min_c : Int,
  max_r : Int,
  max_c : Int,
) -> Array[Array[String]] {
  if max_r == 0 || max_c == 0 {
    return []
  }

  let table0 : Array[Array[String]] = []
  for r in min_r..<(max_r + 1) {
    let row : Array[String] = []
    for c in min_c..<(max_c + 1) {
      let k = r.to_string() + "," + c.to_string()
      row.push(cells.get(k).unwrap_or(""))
    }
    table0.push(trim_row_right(row))
  }

  let table1 = trim_table_bottom(table0)
  normalize_table_width(table1)
}

///|
fn xlsx_header_rows(rows : Array[Array[String]]) -> Int {
  if rows.length() == 0 {
    0
  } else {
    1
  }
}

///|
fn table_width(rows : Array[Array[String]]) -> Int {
  let mut width = 0
  for row in rows {
    if row.length() > width {
      width = row.length()
    }
  }
  width
}

///|
fn tag_text(xml : String, name : String) -> String? {
  let open = "<" + name
  let t0 = find_sub(xml, open, 0)
  match t0 {
    None => None
    Some(start0) => {
      let gt0 = find_sub(xml, ">", start0)
      match gt0 {
        None => None
        Some(start1) => {
          let end0 = find_sub(xml, "</" + name + ">", start1 + 1)
          match end0 {
            None => None
            Some(end1) => Some(xml[start1 + 1:end1].to_owned())
          }
        }
      }
    }
  }
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

///|
fn trim_row_right(row : Array[String]) -> Array[String] {
  let mut end = row.length()

  while end > 0 {
    if @cor.trim_string(row[end - 1]) == "" {
      end = end - 1
    } else {
      break
    }
  }

  let out : Array[String] = []
  for i in 0..<end {
    out.push(row[i])
  }
  out
}

///|
fn trim_table_bottom(table : Array[Array[String]]) -> Array[Array[String]] {
  let mut end = table.length()

  while end > 0 {
    if row_is_blank(table[end - 1]) {
      end = end - 1
    } else {
      break
    }
  }

  let out : Array[Array[String]] = []
  for i in 0..<end {
    out.push(table[i])
  }
  out
}

///|
fn row_is_blank(row : Array[String]) -> Bool {
  for cell in row {
    if @cor.trim_string(cell) != "" {
      return false
    }
  }
  true
}

///|
fn rightmost_nonblank_col(row : Array[String]) -> Int {
  let mut end = row.length()
  while end > 0 {
    if @cor.trim_string(row[end - 1]) == "" {
      end = end - 1
    } else {
      break
    }
  }
  end
}

///|
fn normalize_table_width(table : Array[Array[String]]) -> Array[Array[String]] {
  let mut width = 0

  for row in table {
    let w = rightmost_nonblank_col(row)
    if w > width {
      width = w
    }
  }

  let out : Array[Array[String]] = []
  for row in table {
    let trimmed = trim_row_right(row)
    let new_row : Array[String] = []
    for cell in trimmed {
      new_row.push(cell)
    }
    while new_row.length() < width {
      new_row.push("")
    }
    out.push(new_row)
  }

  out
}
