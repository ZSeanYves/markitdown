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
  styles : XlsxStyles,
) -> Array[Array[String]] raise {
  let cells : Map[String, String] = Map::new()
  let mut min_r = 0
  let mut min_c = 0
  let mut max_r = 0
  let mut max_c = 0

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
            let ctag = sheet_xml[i0:i1 + 1].to_string()

            let rref = get_attr(ctag, "r").unwrap_or("")
            let t = get_attr(ctag, "t").unwrap_or("")
            let s = get_attr(ctag, "s").unwrap_or("")
            let style_idx = parse_int(s)

            let c_end0 = find_sub(sheet_xml, "</c>", i1 + 1)
            match c_end0 {
              None => break
              Some(c_end) => {
                let inner = sheet_xml[i1 + 1:c_end].to_string()

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
                  let text = resolve_cell_text(
                    t, inner, val, shared, styles, style_idx,
                  )
                  cells.set(rr.to_string() + "," + cc.to_string(), text)

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
// ============================
// Utilities
// ============================

///|
fn resolve_cell_text(
  t : String,
  inner : String,
  val : String,
  shared : Array[String],
  styles : XlsxStyles,
  style_idx : Int,
) -> String raise {
  if t == "s" {
    let idx = parse_int(val)
    if idx >= 0 && idx < shared.length() {
      shared[idx]
    } else {
      ""
    }
  } else if t == "inlineStr" {
    parse_inline_str(inner)
  } else if t == "b" {
    let v = @cor.trim_string(val)
    if v == "1" {
      "TRUE"
    } else if v == "0" {
      "FALSE"
    } else {
      xml_unescape(v)
    }
  } else if t == "str" {
    xml_unescape(val)
  } else if t == "e" {
    let v = @cor.trim_string(val)
    if v == "" {
      "#ERROR!"
    } else {
      v
    }
  } else {
    // numeric / formula cached result / other types
    let raw = xml_unescape(val)
    let num_fmt_id = style_index_numfmt(styles, style_idx)

    if numfmt_is_datetime_like(num_fmt_id) {
      format_excel_datetime(raw, num_fmt_id)
    } else {
      raw
    }
  }
}

///|
fn parse_inline_str(inner : String) -> String raise {
  // Collect all <t>...</t> inside the cell inner xml
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
                let content = inner[content_start:t_end].to_string()
                acc = acc + content
                tpos = t_end + 4
              }
            }
          }
        }
      }
    }
  }

  xml_unescape(acc)
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
