///|
priv struct XlsxParsedSheetXml {
  dimension_ref : String?
  hidden_rows : Map[Int, Bool]
  merged_ranges : Array[String]
  cells : Array[XlsxCell]
}

///|
fn xlsx_parse_dimension_ref(sheet_xml : String) -> String? {
  let tag0 = xlsx_find_sub(sheet_xml, "<dimension", 0)
  match tag0 {
    None => None
    Some(start0) => {
      let tag1 = xlsx_find_sub(sheet_xml, ">", start0)
      match tag1 {
        None => None
        Some(end1) => {
          let value = xlsx_get_attr_range(sheet_xml, start0, end1, "ref").unwrap_or(
            "",
          )
          if xlsx_is_blank_text(value) {
            None
          } else {
            Some(value)
          }
        }
      }
    }
  }
}

///|
fn xlsx_parse_sheet_xml_bytes(
  sheet_info : XlsxSheetInfo,
  sheet_xml_bytes : Bytes,
  shared_strings : Array[String],
  styles : XlsxStyles,
  uses_date_1904 : Bool,
  build_cell_source_refs? : Bool = true,
  cell_window_bounds? : (Int, Int, Int, Int)? = None,
) -> XlsxParsedSheetXml {
  xlsx_parse_sheet_xml_reference(
    sheet_info,
    xlsx_decode_sheet_xml(sheet_xml_bytes),
    shared_strings,
    styles,
    uses_date_1904,
    build_cell_source_refs~,
    cell_window_bounds~,
  )
}

///|
fn xlsx_decode_sheet_xml(sheet_xml_bytes : Bytes) -> String {
  @utf8.decode(sheet_xml_bytes, ignore_bom=false) catch {
    _ => {
      let chars : Array[Char] = []
      for b in sheet_xml_bytes {
        let value = b.to_int()
        chars.push(
          Int::unsafe_to_char(if value >= 0 { value } else { value + 256 }),
        )
      }
      String::from_array(chars)
    }
  }
}

///|
fn xlsx_parse_sheet_xml_reference(
  sheet_info : XlsxSheetInfo,
  sheet_xml : String,
  shared_strings : Array[String],
  styles : XlsxStyles,
  uses_date_1904 : Bool,
  build_cell_source_refs? : Bool = true,
  cell_window_bounds? : (Int, Int, Int, Int)? = None,
) -> XlsxParsedSheetXml {
  let hidden_rows : Map[Int, Bool] = Map([])
  let merged_ranges : Array[String] = []
  let cells : Array[XlsxCell] = []
  let mut pos = 0
  let n = sheet_xml.length()
  let mut dimension_ref : String? = None
  let mut active_row_hidden = false
  let sheet_data_end_len = "</sheetData>".length()
  while pos < n {
    if xlsx_sheet_char_at(sheet_xml, pos) != '<' {
      pos += 1
      continue
    }
    if xlsx_is_dimension_tag(sheet_xml, pos, n) {
      match xlsx_find_tag_end(sheet_xml, pos, n) {
        None => break
        Some(end1) => {
          if dimension_ref is None {
            let value = xlsx_get_attr_range(sheet_xml, pos, end1, "ref").unwrap_or(
              "",
            )
            if !xlsx_is_blank_text(value) {
              dimension_ref = Some(value)
            }
          }
          pos = end1 + 1
          continue
        }
      }
    }
    if xlsx_is_row_tag(sheet_xml, pos, n) {
      match xlsx_find_tag_end(sheet_xml, pos, n) {
        None => break
        Some(end1) => {
          let row_index = xlsx_parse_int(
            xlsx_get_attr_range(sheet_xml, pos, end1, "r").unwrap_or(""),
          )
          if xlsx_row_exceeds_window(row_index, cell_window_bounds) {
            match xlsx_find_sub(sheet_xml, "</sheetData>", end1 + 1) {
              Some(sheet_data_end) => {
                pos = sheet_data_end + sheet_data_end_len
                continue
              }
              None => break
            }
          }
          active_row_hidden = row_index > 0 &&
            xlsx_get_attr_range(sheet_xml, pos, end1, "hidden").unwrap_or("") ==
            "1"
          if active_row_hidden {
            hidden_rows.set(row_index, true)
          }
          pos = end1 + 1
          continue
        }
      }
    }
    if xlsx_is_merge_cell_tag(sheet_xml, pos, n) {
      match xlsx_find_tag_end(sheet_xml, pos, n) {
        None => break
        Some(end1) => {
          let value = xlsx_get_attr_range(sheet_xml, pos, end1, "ref").unwrap_or(
            "",
          )
          if value != "" && xlsx_parse_range_ref(value) is Some(_) {
            merged_ranges.push(value)
          }
          pos = end1 + 1
          continue
        }
      }
    }
    if xlsx_is_cell_tag(sheet_xml, pos, n) {
      match xlsx_find_tag_end(sheet_xml, pos, n) {
        None => break
        Some(end1) => {
          let cell_ref_bounds = xlsx_attr_value_bounds(
            sheet_xml, pos, end1, "r",
          )
          let cell_ref = match cell_ref_bounds {
            Some((cell_ref_start, cell_ref_end)) =>
              sheet_xml[cell_ref_start:cell_ref_end].to_owned()
            None => ""
          }
          let cell_type = xlsx_get_attr_range(sheet_xml, pos, end1, "t").unwrap_or(
            "",
          )
          let style_bounds = xlsx_attr_value_bounds(sheet_xml, pos, end1, "s")
          let style_id = match style_bounds {
            Some((style_start, style_end)) =>
              Some(sheet_xml[style_start:style_end].to_owned())
            None => None
          }
          let style_index = match style_bounds {
            Some((style_start, style_end)) =>
              xlsx_parse_int_range(sheet_xml, style_start, style_end)
            None => -1
          }
          let (row_index, column_index) = match cell_ref_bounds {
            Some((cell_ref_start, cell_ref_end)) =>
              xlsx_cell_ref_to_rc_range(sheet_xml, cell_ref_start, cell_ref_end)
            None => (0, 0)
          }
          let (inner_start, inner_end, next_pos) = if xlsx_tag_is_self_closing(
              sheet_xml, pos, end1,
            ) {
            (end1 + 1, end1 + 1, end1 + 1)
          } else {
            match xlsx_find_cell_close(sheet_xml, end1 + 1, n) {
              Some(end2) => (end1 + 1, end2, end2 + 4)
              None => (end1 + 1, end1 + 1, end1 + 1)
            }
          }
          pos = next_pos
          if row_index <= 0 || column_index <= 0 {
            continue
          }
          if xlsx_cell_outside_window(
              row_index, column_index, cell_window_bounds,
            ) {
            continue
          }
          let raw_value = if inner_start >= inner_end {
            None
          } else {
            xlsx_tag_text_range(sheet_xml, inner_start, inner_end, "v")
          }
          let formula_info = if inner_start >= inner_end {
            None
          } else {
            xlsx_extract_formula_info_range(sheet_xml, inner_start, inner_end)
          }
          let formula_text = match formula_info {
            Some(info) => if info.text == "" { None } else { Some(info.text) }
            None => None
          }
          let inline_text = if inner_start >= inner_end {
            None
          } else {
            xlsx_parse_inline_string_range(sheet_xml, inner_start, inner_end)
          }
          let (display_text, _, shared_string_index) = xlsx_resolve_cell_display(
            cell_type, raw_value, inline_text, formula_text, style_index, shared_strings,
            styles, uses_date_1904,
          )
          let formula_kind = match formula_info {
            Some(info) => info.formula_type.unwrap_or("")
            None => ""
          }
          cells.push({
            row_index,
            column_index,
            display_text,
            formula_text,
            is_shared_formula: formula_kind == "shared",
            is_array_formula: formula_kind == "array",
            source_ref: if build_cell_source_refs {
              Some(
                xlsx_cell_source_ref(
                  sheet_info,
                  cell_ref,
                  row_index,
                  column_index,
                  formula_text,
                  style_id,
                  shared_string_index,
                  None,
                ),
              )
            } else {
              None
            },
          })
          continue
        }
      }
    }
    pos += 1
  }
  { dimension_ref, hidden_rows, merged_ranges, cells }
}

///|
fn xlsx_cell_outside_window(
  row_index : Int,
  column_index : Int,
  bounds : (Int, Int, Int, Int)?,
) -> Bool {
  match bounds {
    Some((min_row, min_col, max_row, max_col)) =>
      row_index < min_row ||
      row_index > max_row ||
      column_index < min_col ||
      column_index > max_col
    None => false
  }
}

///|
fn xlsx_row_exceeds_window(
  row_index : Int,
  bounds : (Int, Int, Int, Int)?,
) -> Bool {
  match bounds {
    Some((_, _, max_row, _)) => row_index > max_row
    None => false
  }
}

///|
fn xlsx_sheet_char_at(text : String, index : Int) -> Char {
  text.unsafe_get(index).unsafe_to_char()
}

///|
fn xlsx_is_xml_name_boundary(ch : Char) -> Bool {
  ch == '>' || ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t' || ch == '/'
}

///|
fn xlsx_is_dimension_tag(text : String, start : Int, n : Int) -> Bool {
  start + 10 < n &&
  xlsx_sheet_char_at(text, start) == '<' &&
  xlsx_sheet_char_at(text, start + 1) == 'd' &&
  xlsx_sheet_char_at(text, start + 2) == 'i' &&
  xlsx_sheet_char_at(text, start + 3) == 'm' &&
  xlsx_sheet_char_at(text, start + 4) == 'e' &&
  xlsx_sheet_char_at(text, start + 5) == 'n' &&
  xlsx_sheet_char_at(text, start + 6) == 's' &&
  xlsx_sheet_char_at(text, start + 7) == 'i' &&
  xlsx_sheet_char_at(text, start + 8) == 'o' &&
  xlsx_sheet_char_at(text, start + 9) == 'n' &&
  xlsx_is_xml_name_boundary(xlsx_sheet_char_at(text, start + 10))
}

///|
fn xlsx_is_row_tag(text : String, start : Int, n : Int) -> Bool {
  start + 4 < n &&
  xlsx_sheet_char_at(text, start) == '<' &&
  xlsx_sheet_char_at(text, start + 1) == 'r' &&
  xlsx_sheet_char_at(text, start + 2) == 'o' &&
  xlsx_sheet_char_at(text, start + 3) == 'w' &&
  xlsx_is_xml_name_boundary(xlsx_sheet_char_at(text, start + 4))
}

///|
fn xlsx_is_merge_cell_tag(text : String, start : Int, n : Int) -> Bool {
  start + 10 < n &&
  xlsx_sheet_char_at(text, start) == '<' &&
  xlsx_sheet_char_at(text, start + 1) == 'm' &&
  xlsx_sheet_char_at(text, start + 2) == 'e' &&
  xlsx_sheet_char_at(text, start + 3) == 'r' &&
  xlsx_sheet_char_at(text, start + 4) == 'g' &&
  xlsx_sheet_char_at(text, start + 5) == 'e' &&
  xlsx_sheet_char_at(text, start + 6) == 'C' &&
  xlsx_sheet_char_at(text, start + 7) == 'e' &&
  xlsx_sheet_char_at(text, start + 8) == 'l' &&
  xlsx_sheet_char_at(text, start + 9) == 'l' &&
  xlsx_is_xml_name_boundary(xlsx_sheet_char_at(text, start + 10))
}

///|
fn xlsx_is_cell_tag(text : String, start : Int, n : Int) -> Bool {
  start + 2 < n &&
  xlsx_sheet_char_at(text, start) == '<' &&
  xlsx_sheet_char_at(text, start + 1) == 'c' &&
  xlsx_is_xml_name_boundary(xlsx_sheet_char_at(text, start + 2))
}

///|
fn xlsx_find_tag_end(text : String, start : Int, n : Int) -> Int? {
  let mut i = start
  while i < n {
    if xlsx_sheet_char_at(text, i) == '>' {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn xlsx_find_cell_close(text : String, start : Int, n : Int) -> Int? {
  let mut i = start
  while i + 3 < n {
    if xlsx_sheet_char_at(text, i) == '<' &&
      xlsx_sheet_char_at(text, i + 1) == '/' &&
      xlsx_sheet_char_at(text, i + 2) == 'c' &&
      xlsx_sheet_char_at(text, i + 3) == '>' {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn xlsx_tag_is_self_closing(
  text : String,
  tag_start : Int,
  tag_end : Int,
) -> Bool {
  let mut i = tag_end - 1
  while i > tag_start {
    let ch = xlsx_sheet_char_at(text, i)
    if ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t' {
      i -= 1
      continue
    }
    return ch == '/'
  }
  false
}

///|
priv struct XlsxFormulaInfo {
  formula_type : String?
  text : String
}

///|
fn xlsx_find_named_open_tag_range(
  text : String,
  name : String,
  start : Int,
  end_ : Int,
) -> Int? {
  let pattern = "<" + name
  let mut pos = start
  let mut result : Int? = None
  while pos < end_ && result is None {
    match xlsx_find_sub_range(text, pattern, pos, end_) {
      None => pos = end_
      Some(found) => {
        let boundary = found + pattern.length()
        if boundary < end_ &&
          xlsx_is_xml_name_boundary(xlsx_sheet_char_at(text, boundary)) {
          result = Some(found)
        } else {
          pos = found + pattern.length()
        }
      }
    }
  }
  result
}

///|
fn xlsx_tag_text_range(
  xml : String,
  range_start : Int,
  range_end : Int,
  name : String,
) -> String? {
  match xlsx_find_named_open_tag_range(xml, name, range_start, range_end) {
    None => None
    Some(start0) => {
      let tag1 = xlsx_find_char(xml, '>', start0, range_end)
      match tag1 {
        None => None
        Some(start1) =>
          if xlsx_tag_is_self_closing(xml, start0, start1) {
            Some("")
          } else {
            let end0 = xlsx_find_sub_range(
              xml,
              "</" + name + ">",
              start1 + 1,
              range_end,
            )
            match end0 {
              Some(end1) =>
                Some(xlsx_xml_unescape(xml[start1 + 1:end1].to_owned()))
              None => None
            }
          }
      }
    }
  }
}

///|
fn xlsx_extract_formula_info_range(
  xml : String,
  range_start : Int,
  range_end : Int,
) -> XlsxFormulaInfo? {
  match xlsx_find_named_open_tag_range(xml, "f", range_start, range_end) {
    None => None
    Some(start0) => {
      let tag1 = xlsx_find_char(xml, '>', start0, range_end)
      match tag1 {
        None => None
        Some(start1) => {
          let formula_type = xlsx_get_attr_range(xml, start0, start1, "t")
          if xlsx_tag_is_self_closing(xml, start0, start1) {
            Some({ formula_type, text: "" })
          } else {
            let end0 = xlsx_find_sub_range(xml, "</f>", start1 + 1, range_end)
            match end0 {
              Some(end1) =>
                Some({
                  formula_type,
                  text: xlsx_xml_unescape(xml[start1 + 1:end1].to_owned()),
                })
              None => None
            }
          }
        }
      }
    }
  }
}

///|
fn xlsx_resolve_cell_display(
  cell_type : String,
  raw_value : String?,
  inline_text : String?,
  formula_text : String?,
  style_index : Int,
  shared_strings : Array[String],
  styles : XlsxStyles,
  uses_date_1904 : Bool,
) -> (String, String, Int?) {
  let raw = raw_value.unwrap_or("")
  match formula_text {
    Some(formula) =>
      if !xlsx_is_blank_text(raw) {
        let (display_text, _, shared_string_index) = xlsx_resolve_base_cell_value(
          cell_type, raw_value, inline_text, style_index, shared_strings, styles,
          uses_date_1904,
        )
        (display_text, "formula_cached_value", shared_string_index)
      } else {
        ("=" + formula, "formula_missing_cache", None)
      }
    None =>
      xlsx_resolve_base_cell_value(
        cell_type, raw_value, inline_text, style_index, shared_strings, styles, uses_date_1904,
      )
  }
}

///|
fn xlsx_resolve_base_cell_value(
  cell_type : String,
  raw_value : String?,
  inline_text : String?,
  style_index : Int,
  shared_strings : Array[String],
  styles : XlsxStyles,
  uses_date_1904 : Bool,
) -> (String, String, Int?) {
  let raw = raw_value.unwrap_or("")
  if cell_type == "s" {
    let index = xlsx_parse_int(raw)
    if index >= 0 && index < shared_strings.length() {
      return (shared_strings[index], "string", Some(index))
    }
    return ("", "string", None)
  }
  if cell_type == "inlineStr" {
    return (inline_text.unwrap_or(""), "string", None)
  }
  if cell_type == "b" {
    return (if raw == "1" { "TRUE" } else { "FALSE" }, "boolean", None)
  }
  if cell_type == "e" {
    return (raw, "error", None)
  }
  if cell_type == "str" {
    return (xlsx_xml_unescape(raw), "string", None)
  }
  if xlsx_is_blank_text(raw) {
    return ("", "blank", None)
  }
  let formatted = xlsx_format_value(raw, style_index, styles, uses_date_1904)
  let semantic_type = xlsx_semantic_type_for_style(raw, style_index, styles)
  (formatted, semantic_type, None)
}

///|
fn xlsx_format_value(
  raw : String,
  style_index : Int,
  styles : XlsxStyles,
  uses_date_1904 : Bool,
) -> String {
  let num_fmt_id = xlsx_style_numfmt(styles, style_index)
  if num_fmt_id >= 0 && xlsx_numfmt_is_datetime_like(num_fmt_id, styles) {
    return xlsx_format_excel_datetime(
      raw,
      num_fmt_id,
      styles.custom_numfmts.get(num_fmt_id),
      uses_date_1904,
    )
  }
  raw
}

///|
fn xlsx_semantic_type_for_style(
  raw : String,
  style_index : Int,
  styles : XlsxStyles,
) -> String {
  let num_fmt_id = xlsx_style_numfmt(styles, style_index)
  if num_fmt_id < 0 {
    return "number"
  }
  if xlsx_numfmt_is_datetime_like(num_fmt_id, styles) {
    let lower = styles.custom_numfmts.get(num_fmt_id).unwrap_or("").to_lower()
    if lower.contains("h") ||
      num_fmt_id == 20 ||
      num_fmt_id == 21 ||
      num_fmt_id == 45 ||
      num_fmt_id == 46 ||
      num_fmt_id == 47 {
      if lower.contains("y") || lower.contains("d") || num_fmt_id == 22 {
        "datetime"
      } else {
        "time"
      }
    } else {
      "date"
    }
  } else if xlsx_is_blank_text(raw) {
    "blank"
  } else {
    "number"
  }
}

///|
fn xlsx_parse_inline_string_range(
  xml : String,
  range_start : Int,
  range_end : Int,
) -> String? {
  match xlsx_find_named_open_tag_range(xml, "is", range_start, range_end) {
    None => {
      let text = xlsx_concat_text_runs_range(xml, range_start, range_end)
      if text == "" {
        None
      } else {
        Some(text)
      }
    }
    Some(start0) => {
      let end0 = xlsx_find_sub_range(xml, "</is>", start0, range_end)
      let text = match end0 {
        Some(end1) => xlsx_concat_text_runs_range(xml, start0, end1)
        None => xlsx_concat_text_runs_range(xml, range_start, range_end)
      }
      if text == "" {
        None
      } else {
        Some(text)
      }
    }
  }
}

///|
fn xlsx_concat_text_runs(inner : String) -> String {
  let mut out = ""
  let mut pos = 0
  while true {
    let t0 = xlsx_find_sub(inner, "<t", pos)
    match t0 {
      None => break
      Some(start0) => {
        let next_char = if start0 + 2 < inner.length() {
          Some(inner[start0 + 2])
        } else {
          None
        }
        match next_char {
          Some(ch) =>
            if ch != '>' && ch != ' ' && ch != '\n' && ch != '\r' && ch != '\t' {
              pos = start0 + 2
              continue
            }
          None => {
            pos = start0 + 2
            continue
          }
        }
        let tag1 = xlsx_find_sub(inner, ">", start0)
        match tag1 {
          None => break
          Some(start1) => {
            let end0 = xlsx_find_sub(inner, "</t>", start1 + 1)
            match end0 {
              None => break
              Some(end1) => {
                out = out + xlsx_xml_unescape(inner[start1 + 1:end1].to_owned())
                pos = end1 + 4
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
fn xlsx_concat_text_runs_range(
  xml : String,
  range_start : Int,
  range_end : Int,
) -> String {
  let out = StringBuilder::new()
  let mut pos = range_start
  while true {
    match xlsx_find_named_open_tag_range(xml, "t", pos, range_end) {
      None => break
      Some(start0) => {
        let tag1 = xlsx_find_char(xml, '>', start0, range_end)
        match tag1 {
          None => break
          Some(start1) => {
            let end0 = xlsx_find_sub_range(xml, "</t>", start1 + 1, range_end)
            match end0 {
              None => break
              Some(end1) => {
                out.write_string(xml[start1 + 1:end1].to_owned())
                pos = end1 + 4
              }
            }
          }
        }
      }
    }
  }
  xlsx_xml_unescape(out.to_string())
}

///|
fn xlsx_parse_comments_part(
  pkg : @ox.OoxmlPackage,
  part_name : String,
) -> Array[XlsxComment] raise @ox.OoxmlError {
  let xml = @ox.read_part_text_transient(pkg, part_name)
  let authors = xlsx_comment_authors(xml)
  let out : Array[XlsxComment] = []
  let mut pos = 0
  while true {
    let next = xlsx_find_sub(xml, "<comment", pos)
    match next {
      None => break
      Some(start0) => {
        let next_char = if start0 + 8 < xml.length() {
          Some(xml[start0 + 8])
        } else {
          None
        }
        match next_char {
          Some(ch) =>
            if ch != '>' && ch != ' ' && ch != '\n' && ch != '\r' && ch != '\t' {
              pos = start0 + 8
              continue
            }
          None => {
            pos = start0 + 8
            continue
          }
        }
        let tag1 = xlsx_find_sub(xml, ">", start0)
        match tag1 {
          None => break
          Some(start1) => {
            let tag = xml[start0:start1 + 1].to_owned()
            let end0 = xlsx_find_sub(xml, "</comment>", start1 + 1)
            match end0 {
              None => break
              Some(end1) => {
                let inner = xml[start1 + 1:end1].to_owned()
                let cell_ref = xlsx_get_attr(tag, "ref").unwrap_or("")
                let author_id = xlsx_parse_int(
                  xlsx_get_attr(tag, "authorId").unwrap_or(""),
                )
                let author = if author_id >= 0 && author_id < authors.length() {
                  let name = authors[author_id].trim().to_owned()
                  if name == "" {
                    None
                  } else {
                    Some(name)
                  }
                } else {
                  None
                }
                let text = xlsx_concat_text_runs(inner).trim().to_owned()
                let normalized = xlsx_comment_strip_author_prefix(author, text)
                if cell_ref != "" && normalized != "" {
                  out.push({ cell_ref, author, text: normalized })
                }
                pos = end1 + 10
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
fn xlsx_comment_authors(xml : String) -> Array[String] {
  let out : Array[String] = []
  let mut pos = 0
  while true {
    let next = xlsx_find_sub(xml, "<author>", pos)
    match next {
      None => break
      Some(start0) => {
        let end0 = xlsx_find_sub(xml, "</author>", start0 + 8)
        match end0 {
          None => break
          Some(end1) => {
            out.push(xlsx_xml_unescape(xml[start0 + 8:end1].to_owned()))
            pos = end1 + 9
          }
        }
      }
    }
  }
  out
}

///|
fn xlsx_comment_strip_author_prefix(author : String?, text : String) -> String {
  let trimmed = text.trim().to_owned()
  match author {
    Some(name) =>
      if !xlsx_is_blank_text(name) && trimmed.has_prefix(name + ":") {
        trimmed[name.length() + 1:].trim().to_owned()
      } else {
        trimmed
      }
    None => trimmed
  }
}

///|
fn xlsx_effective_bounds(
  dimension_ref : String?,
  cells : Array[XlsxCell],
  hidden_rows : Map[Int, Bool],
  max_rows : Int,
  max_cols : Int,
  max_cells : Int,
) -> (Int, Int, Int, Int, Bool, Bool) {
  let base_bounds = match
    xlsx_bounds_from_visible_cells(cells, hidden_rows, true) {
    Some(bounds) => Some(bounds)
    None =>
      match dimension_ref {
        Some(value) => xlsx_parse_range_ref(value)
        None => xlsx_bounds_from_visible_cells(cells, hidden_rows, false)
      }
  }
  match base_bounds {
    None => (0, 0, 0, 0, false, true)
    Some((min_row0, min_col0, max_row0, max_col0)) => {
      if cells.length() == 0 {
        return (0, 0, 0, 0, false, true)
      }
      let mut clipped = false
      let min_row = min_row0
      let min_col = min_col0
      let mut max_row = max_row0
      let mut max_col = max_col0
      if max_row - min_row + 1 > max_rows {
        max_row = min_row + max_rows - 1
        clipped = true
      }
      if max_col - min_col + 1 > max_cols {
        max_col = min_col + max_cols - 1
        clipped = true
      }
      let width = max_col - min_col + 1
      if width > 0 && max_cells > 0 {
        let max_rows_by_cells = if max_cells / width > 0 {
          max_cells / width
        } else {
          1
        }
        let effective_rows = max_row - min_row + 1
        if effective_rows > max_rows_by_cells {
          max_row = min_row + max_rows_by_cells - 1
          clipped = true
        }
      }
      (min_row, min_col, max_row, max_col, clipped, false)
    }
  }
}

///|
fn xlsx_sheet_is_effectively_empty(
  base_is_empty : Bool,
  non_empty_cell_count : Int,
  formula_count : Int,
) -> Bool {
  base_is_empty || (non_empty_cell_count == 0 && formula_count == 0)
}

///|
fn xlsx_bounds_from_visible_cells(
  cells : Array[XlsxCell],
  hidden_rows : Map[Int, Bool],
  semantic_only : Bool,
) -> (Int, Int, Int, Int)? {
  let mut found = false
  let mut min_row = 0
  let mut min_col = 0
  let mut max_row = 0
  let mut max_col = 0
  for cell in cells {
    if xlsx_row_is_hidden(hidden_rows, cell.row_index) {
      continue
    }
    if semantic_only && !xlsx_cell_has_semantic_content(cell) {
      continue
    }
    if !found {
      found = true
      min_row = cell.row_index
      min_col = cell.column_index
      max_row = cell.row_index
      max_col = cell.column_index
      continue
    }
    if cell.row_index < min_row {
      min_row = cell.row_index
    }
    if cell.column_index < min_col {
      min_col = cell.column_index
    }
    if cell.row_index > max_row {
      max_row = cell.row_index
    }
    if cell.column_index > max_col {
      max_col = cell.column_index
    }
  }
  if !found {
    None
  } else {
    Some((min_row, min_col, max_row, max_col))
  }
}

///|
fn xlsx_row_is_hidden(hidden_rows : Map[Int, Bool], row_index : Int) -> Bool {
  match hidden_rows.get(row_index) {
    Some(value) => value
    None => false
  }
}

///|
fn xlsx_cell_has_semantic_content(cell : XlsxCell) -> Bool {
  !xlsx_is_blank_text(cell.display_text) || cell.formula_text is Some(_)
}

///|
fn xlsx_visible_row_count(
  hidden_rows : Map[Int, Bool],
  min_row : Int,
  max_row : Int,
) -> Int {
  if min_row > max_row {
    return 0
  }
  let mut count = 0
  let mut row = min_row
  while row <= max_row {
    if !xlsx_row_is_hidden(hidden_rows, row) {
      count += 1
    }
    row += 1
  }
  count
}

///|
fn xlsx_filter_merge_ranges(
  ranges : Array[String],
  min_row : Int,
  min_col : Int,
  max_row : Int,
  max_col : Int,
  is_empty : Bool,
) -> Array[String] {
  if is_empty {
    return []
  }
  let out : Array[String] = []
  for range_ref in ranges {
    match xlsx_parse_range_ref(range_ref) {
      Some((r1, c1, r2, c2)) =>
        if !(r2 < min_row || r1 > max_row || c2 < min_col || c1 > max_col) {
          out.push(range_ref)
        }
      None => ()
    }
  }
  out
}

///|
fn xlsx_fill_merge_lookup(
  lookup : Map[String, String],
  ranges : Array[String],
) -> Unit {
  for range_ref in ranges {
    match xlsx_parse_range_ref(range_ref) {
      Some((r1, c1, r2, c2)) => {
        let mut row = r1
        while row <= r2 {
          let mut col = c1
          while col <= c2 {
            lookup.set(xlsx_lookup_key(row, col), range_ref)
            col += 1
          }
          row += 1
        }
      }
      None => ()
    }
  }
}

///|
priv struct XlsxLoweringResult {
  blocks : Array[@core.CoreBlock]
  metadata : @core.DocumentMetadata
  assets : Array[@core.AssetRef]
}
