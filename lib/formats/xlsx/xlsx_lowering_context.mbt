///|
fn xlsx_comment_item_text(comment : XlsxComment) -> String {
  match comment.author {
    Some(author) =>
      if author.trim() == "" {
        comment.cell_ref + ": " + comment.text
      } else {
        comment.cell_ref + " (" + author + "): " + comment.text
      }
    None => comment.cell_ref + ": " + comment.text
  }
}

///|
fn xlsx_row_source_ref(
  source_name : String,
  sheet : XlsxSheet,
  row_index : Int,
) -> @core.SourceRef {
  @core.source_ref_with_extra(
    xlsx_sheet_table_source_ref(source_name, sheet),
    "row_index",
    row_index.to_string(),
  )
}

///|
fn xlsx_cell_source_ref(
  sheet_info : XlsxSheetInfo,
  cell_ref : String,
  row_index : Int,
  column_index : Int,
  formula_text : String?,
  style_id : String?,
  shared_string_index : Int?,
  merge_range : String?,
) -> @core.SourceRef {
  let base = @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some(sheet_info.sheet_name),
    Some("xlsx"),
    Some(sheet_info.sheet_name),
    Some(sheet_info.part_name),
    None,
    Some("xlsx"),
    Some(
      "/worksheet/sheetData/row[" +
      row_index.to_string() +
      "]/c[" +
      cell_ref +
      "]",
    ),
  )
  let office = @core.source_ref_with_office_fields(
    base,
    Some(sheet_info.sheet_name),
    Some("xlsx"),
    Some(
      "/worksheet/sheetData/row[" +
      row_index.to_string() +
      "]/c[" +
      cell_ref +
      "]",
    ),
    Some(sheet_info.sheet_name),
    Some(cell_ref),
    None,
    None,
    Some(sheet_info.relationship_id),
  )
  let mut source_ref = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.source_ref_with_extra(
        @core.source_ref_with_extra(
          @core.source_ref_with_extra(
            @core.source_ref_with_extra(
              office,
              "part_name",
              sheet_info.part_name,
            ),
            "sheet_name",
            sheet_info.sheet_name,
          ),
          "sheet_visibility",
          @shared.xlsx_sheet_visibility_name(sheet_info.visibility),
        ),
        "cell_ref",
        cell_ref,
      ),
      "row_index",
      row_index.to_string(),
    ),
    "column_index",
    column_index.to_string(),
  )
  source_ref = @core.source_ref_with_extra(
    source_ref,
    "relationship_id",
    sheet_info.relationship_id,
  )
  match sheet_info.sheet_id {
    Some(value) =>
      source_ref = @core.source_ref_with_extra(source_ref, "sheet_id", value)
    None => ()
  }
  match formula_text {
    Some(_) =>
      source_ref = @core.source_ref_with_extra(
        source_ref, "formula_ref", cell_ref,
      )
    None => ()
  }
  match style_id {
    Some(value) =>
      if value.trim() != "" {
        source_ref = @core.source_ref_with_extra(source_ref, "style_id", value)
      }
    None => ()
  }
  match shared_string_index {
    Some(value) =>
      source_ref = @core.source_ref_with_extra(
        source_ref,
        "shared_string_index",
        value.to_string(),
      )
    None => ()
  }
  match merge_range {
    Some(value) =>
      source_ref = @core.source_ref_with_extra(source_ref, "merge_range", value)
    None => ()
  }
  source_ref
}

///|
fn xlsx_blank_cell_source_ref(
  source_name : String,
  sheet : XlsxSheet,
  cell_ref : String,
  row_index : Int,
  column_index : Int,
  merge_range : String?,
) -> @core.SourceRef {
  let info : XlsxSheetInfo = {
    sheet_name: sheet.sheet_name,
    sheet_id: sheet.sheet_id,
    relationship_id: sheet.relationship_id,
    part_name: sheet.part_name,
    visibility: sheet.visibility,
  }
  ignore(source_name)
  xlsx_cell_source_ref(
    info,
    cell_ref,
    row_index,
    column_index,
    None,
    None,
    None,
    merge_range,
  )
}

///|
fn xlsx_merged_cell_area(ranges : Array[String]) -> Int {
  let mut total = 0
  for range_ref in ranges {
    match xlsx_parse_range_ref(range_ref) {
      Some((r1, c1, r2, c2)) => total += (r2 - r1 + 1) * (c2 - c1 + 1)
      None => ()
    }
  }
  total
}

///|
fn xlsx_lookup_key(row_index : Int, column_index : Int) -> String {
  row_index.to_string() + "," + column_index.to_string()
}

///|
fn xlsx_parse_range_ref(range_ref : String) -> (Int, Int, Int, Int)? {
  match xlsx_find_char(range_ref, ':', 0, range_ref.length()) {
    Some(split) => {
      let (r1, c1) = xlsx_cell_ref_to_rc_range(range_ref, 0, split)
      let (r2, c2) = xlsx_cell_ref_to_rc_range(
        range_ref,
        split + 1,
        range_ref.length(),
      )
      if r1 > 0 && c1 > 0 && r2 > 0 && c2 > 0 {
        Some((r1, c1, r2, c2))
      } else {
        None
      }
    }
    None => {
      let (row, col) = xlsx_cell_ref_to_rc_range(
        range_ref,
        0,
        range_ref.length(),
      )
      if row > 0 && col > 0 {
        Some((row, col, row, col))
      } else {
        None
      }
    }
  }
}

///|
fn xlsx_cell_ref_to_rc_range(
  text : String,
  start : Int,
  end_ : Int,
) -> (Int, Int) {
  let (trimmed_start, trimmed_end) = xlsx_trimmed_slice_bounds(
    text, start, end_,
  )
  let mut col = 0
  let mut i = trimmed_start
  while i < trimmed_end {
    let ch = text.unsafe_get(i).unsafe_to_char()
    if ch == '$' {
      i += 1
      continue
    }
    if (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') {
      let upper = if ch >= 'a' && ch <= 'z' {
        ch.to_int() - 'a'.to_int() + 'A'.to_int()
      } else {
        ch.to_int()
      }
      col = col * 26 + (upper - 'A'.to_int() + 1)
      i += 1
    } else {
      break
    }
  }
  let mut row = 0
  while i < trimmed_end {
    let ch = text.unsafe_get(i).unsafe_to_char()
    if ch == '$' {
      i += 1
      continue
    }
    if ch >= '0' && ch <= '9' {
      row = row * 10 + (ch.to_int() - '0'.to_int())
      i += 1
    } else {
      return (0, 0)
    }
  }
  (row, col)
}

///|
fn xlsx_rc_to_cell_ref(row : Int, col : Int) -> String {
  if row <= 0 || col <= 0 {
    return ""
  }
  let out : Array[String] = []
  let mut current = col
  while current > 0 {
    let rem = (current - 1) % 26
    out.push(String::from_array([Int::unsafe_to_char('A'.to_int() + rem)]))
    current = (current - 1) / 26
  }
  let rev : Array[String] = []
  let mut i = out.length() - 1
  while i >= 0 {
    rev.push(out[i])
    if i == 0 {
      break
    }
    i -= 1
  }
  rev.join("") + row.to_string()
}

///|
fn xlsx_parse_int(text : String) -> Int {
  xlsx_parse_int_range(text, 0, text.length())
}

///|
fn xlsx_parse_int_range(text : String, start : Int, end_ : Int) -> Int {
  let (trimmed_start, trimmed_end) = xlsx_trimmed_slice_bounds(
    text, start, end_,
  )
  if trimmed_start >= trimmed_end {
    return -1
  }
  let mut i = trimmed_start
  let mut sign = 1
  let first = text.unsafe_get(i).unsafe_to_char()
  if first == '+' {
    i += 1
  } else if first == '-' {
    sign = -1
    i += 1
  }
  if i >= trimmed_end {
    return -1
  }
  let mut value = 0
  let mut saw_digit = false
  while i < trimmed_end {
    let ch = text.unsafe_get(i).unsafe_to_char()
    if ch < '0' || ch > '9' {
      return -1
    }
    saw_digit = true
    value = value * 10 + (ch.to_int() - '0'.to_int())
    i += 1
  }
  if !saw_digit {
    -1
  } else {
    value * sign
  }
}

///|
fn xlsx_find_sub(text : String, pattern : String, start : Int) -> Int? {
  xlsx_find_sub_range(text, pattern, start, text.length())
}

///|
fn xlsx_find_char(
  text : String,
  target : Char,
  start : Int,
  end_ : Int,
) -> Int? {
  let limit = if end_ > text.length() { text.length() } else { end_ }
  let mut i = if start < 0 { 0 } else { start }
  while i < limit {
    if text.unsafe_get(i).unsafe_to_char() == target {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn xlsx_find_sub_range(
  text : String,
  pattern : String,
  start : Int,
  end_ : Int,
) -> Int? {
  let n = text.length()
  let m = pattern.length()
  if m == 0 {
    return Some(start)
  }
  let limit = if end_ > n { n } else { end_ }
  if start < 0 || start >= limit || limit - start < m {
    return None
  }
  let last = limit - m
  let mut i = start
  while i <= last {
    let mut matched = true
    let mut j = 0
    while j < m {
      if text.unsafe_get(i + j) != pattern.unsafe_get(j) {
        matched = false
        break
      }
      j += 1
    }
    if matched {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn xlsx_get_attr(tag : String, key : String) -> String? {
  let pattern = key + "=\""
  let start0 = xlsx_find_sub(tag, pattern, 0)
  match start0 {
    None => None
    Some(i0) => {
      let value_start = i0 + pattern.length()
      let end0 = xlsx_find_sub(tag, "\"", value_start)
      match end0 {
        None => None
        Some(i1) => Some(tag[value_start:i1].to_owned())
      }
    }
  }
}

///|
fn xlsx_attr_value_bounds(
  text : String,
  tag_start : Int,
  tag_end : Int,
  key : String,
) -> (Int, Int)? {
  let pattern = key + "=\""
  let start0 = xlsx_find_sub_range(text, pattern, tag_start, tag_end + 1)
  match start0 {
    None => None
    Some(i0) => {
      let value_start = i0 + pattern.length()
      let end0 = xlsx_find_char(text, '"', value_start, tag_end + 1)
      match end0 {
        None => None
        Some(i1) => Some((value_start, i1))
      }
    }
  }
}

///|
fn xlsx_get_attr_range(
  text : String,
  tag_start : Int,
  tag_end : Int,
  key : String,
) -> String? {
  match xlsx_attr_value_bounds(text, tag_start, tag_end, key) {
    Some((value_start, value_end)) =>
      Some(text[value_start:value_end].to_owned())
    None => None
  }
}

///|
fn xlsx_xml_unescape(text : String) -> String {
  if !xlsx_contains_char(text, '&') {
    return text
  }
  let basic = text
    .replace(old="&lt;", new="<")
    .replace(old="&gt;", new=">")
    .replace(old="&amp;", new="&")
    .replace(old="&quot;", new="\"")
    .replace(old="&apos;", new="'")
  xlsx_decode_numeric_entities(basic)
}

///|
fn xlsx_decode_numeric_entities(text : String) -> String {
  let chars = text.to_array()
  let out : Array[Char] = []
  let mut i = 0
  while i < chars.length() {
    if i + 2 < chars.length() && chars[i] == '&' && chars[i + 1] == '#' {
      let mut j = i + 2
      while j < chars.length() && chars[j] != ';' {
        j += 1
      }
      if j < chars.length() && chars[j] == ';' {
        let body = String::from_array(chars[i + 2:j]).trim().to_owned()
        let codepoint = if body.has_prefix("x") || body.has_prefix("X") {
          xlsx_parse_hex_int(body[1:].to_owned())
        } else {
          xlsx_parse_dec_int(body)
        }
        match codepoint {
          Some(value) => {
            out.push(Int::unsafe_to_char(value))
            i = j + 1
            continue
          }
          None => ()
        }
      }
    }
    out.push(chars[i])
    i += 1
  }
  String::from_array(out)
}

///|
fn xlsx_trimmed_slice_bounds(
  text : String,
  start : Int,
  end_ : Int,
) -> (Int, Int) {
  let limit = if end_ > text.length() { text.length() } else { end_ }
  let mut left = if start < 0 { 0 } else { start }
  let mut right = limit
  while left < right &&
        xlsx_is_ascii_whitespace(text.unsafe_get(left).unsafe_to_char()) {
    left += 1
  }
  while right > left &&
        xlsx_is_ascii_whitespace(text.unsafe_get(right - 1).unsafe_to_char()) {
    right -= 1
  }
  (left, right)
}

///|
fn xlsx_is_ascii_whitespace(ch : Char) -> Bool {
  ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t'
}

///|
fn xlsx_contains_char(text : String, target : Char) -> Bool {
  let mut i = 0
  let n = text.length()
  while i < n {
    if text.unsafe_get(i).unsafe_to_char() == target {
      return true
    }
    i += 1
  }
  false
}

///|
fn xlsx_is_blank_text(text : String) -> Bool {
  let mut i = 0
  let n = text.length()
  while i < n {
    if !xlsx_is_ascii_whitespace(text.unsafe_get(i).unsafe_to_char()) {
      return false
    }
    i += 1
  }
  true
}

///|
fn xlsx_parse_dec_int(text : String) -> Int? {
  if text == "" {
    return None
  }
  let chars = text.to_array()
  let mut value = 0
  let mut i = 0
  while i < chars.length() {
    let ch = chars[i]
    if ch < '0' || ch > '9' {
      return None
    }
    value = value * 10 + (ch.to_int() - '0'.to_int())
    i += 1
  }
  Some(value)
}

///|
fn xlsx_parse_hex_int(text : String) -> Int? {
  if text == "" {
    return None
  }
  let chars = text.to_array()
  let mut value = 0
  let mut i = 0
  while i < chars.length() {
    let ch = chars[i]
    let digit = if ch >= '0' && ch <= '9' {
      ch.to_int() - '0'.to_int()
    } else if ch >= 'a' && ch <= 'f' {
      ch.to_int() - 'a'.to_int() + 10
    } else if ch >= 'A' && ch <= 'F' {
      ch.to_int() - 'A'.to_int() + 10
    } else {
      return None
    }
    value = value * 16 + digit
    i += 1
  }
  Some(value)
}

///|
fn xlsx_style_numfmt(styles : XlsxStyles, style_index : Int) -> Int {
  if style_index < 0 || style_index >= styles.xf_numfmts.length() {
    -1
  } else {
    styles.xf_numfmts[style_index]
  }
}

///|
fn xlsx_numfmt_is_datetime_like(num_fmt_id : Int, styles : XlsxStyles) -> Bool {
  if xlsx_builtin_datetime_numfmt(num_fmt_id) {
    return true
  }
  match styles.custom_numfmts.get(num_fmt_id) {
    Some(code) => xlsx_datetime_code_like(code)
    None => false
  }
}

///|
fn xlsx_builtin_datetime_numfmt(num_fmt_id : Int) -> Bool {
  num_fmt_id == 14 ||
  num_fmt_id == 15 ||
  num_fmt_id == 16 ||
  num_fmt_id == 17 ||
  num_fmt_id == 18 ||
  num_fmt_id == 19 ||
  num_fmt_id == 20 ||
  num_fmt_id == 21 ||
  num_fmt_id == 22 ||
  num_fmt_id == 45 ||
  num_fmt_id == 46 ||
  num_fmt_id == 47
}

///|
fn xlsx_datetime_code_like(code : String) -> Bool {
  let lower = code.to_lower()
  if lower.contains("[h]") || lower.contains("h") || lower.contains("s") {
    return true
  }
  lower.contains("y") || lower.contains("d") || lower.contains("m")
}

///|
fn xlsx_format_excel_datetime(
  raw : String,
  num_fmt_id : Int,
  custom_code : String?,
  uses_date_1904 : Bool,
) -> String {
  match xlsx_parse_excel_serial(raw) {
    None => raw
    Some((days, frac_num, frac_den)) => {
      let (carry, hh, mm, ss) = xlsx_frac_to_hms(frac_num, frac_den)
      let serial_day = days + carry
      let lower = custom_code.unwrap_or("").to_lower()
      let is_date_only = if custom_code is Some(_) {
        (lower.contains("y") || lower.contains("d")) &&
        !lower.contains("h") &&
        !lower.contains("s")
      } else {
        num_fmt_id == 14 ||
        num_fmt_id == 15 ||
        num_fmt_id == 16 ||
        num_fmt_id == 17
      }
      let is_time_only = if custom_code is Some(_) {
        !lower.contains("y") &&
        !lower.contains("d") &&
        (lower.contains("h") || lower.contains("s"))
      } else {
        num_fmt_id == 18 ||
        num_fmt_id == 19 ||
        num_fmt_id == 20 ||
        num_fmt_id == 21 ||
        num_fmt_id == 45 ||
        num_fmt_id == 46 ||
        num_fmt_id == 47
      }
      let is_datetime = if custom_code is Some(_) {
        (lower.contains("y") || lower.contains("d")) &&
        (lower.contains("h") || lower.contains("s"))
      } else {
        num_fmt_id == 22
      }
      if is_time_only {
        return xlsx_pad2(hh) + ":" + xlsx_pad2(mm) + ":" + xlsx_pad2(ss)
      }
      let (year, month, day) = xlsx_excel_serial_to_ymd(
        serial_day, uses_date_1904,
      )
      if is_date_only && !is_datetime {
        return xlsx_pad4(year) + "-" + xlsx_pad2(month) + "-" + xlsx_pad2(day)
      }
      if is_datetime || frac_num != 0 {
        return xlsx_pad4(year) +
          "-" +
          xlsx_pad2(month) +
          "-" +
          xlsx_pad2(day) +
          " " +
          xlsx_pad2(hh) +
          ":" +
          xlsx_pad2(mm) +
          ":" +
          xlsx_pad2(ss)
      }
      xlsx_pad4(year) + "-" + xlsx_pad2(month) + "-" + xlsx_pad2(day)
    }
  }
}

///|
fn xlsx_parse_excel_serial(text : String) -> (Int, Int, Int)? {
  let trimmed = text.trim()
  if trimmed == "" {
    return None
  }
  let chars = trimmed.to_array()
  let mut i = 0
  let n = chars.length()
  if i < n && (chars[i] == '-' || chars[i] == '+') {
    return None
  }
  let mut days = 0
  let mut has_int = false
  while i < n {
    let ch = chars[i]
    if ch >= '0' && ch <= '9' {
      days = days * 10 + (ch.to_int() - '0'.to_int())
      has_int = true
      i += 1
    } else {
      break
    }
  }
  if i == n {
    if has_int {
      Some((days, 0, 1))
    } else {
      None
    }
  } else if chars[i] != '.' {
    None
  } else {
    i += 1
    let mut frac_num = 0
    let mut frac_den = 1
    let mut has_frac = false
    let mut digits = 0
    while i < n {
      let ch = chars[i]
      if ch >= '0' && ch <= '9' {
        if digits < 6 {
          frac_num = frac_num * 10 + (ch.to_int() - '0'.to_int())
          frac_den = frac_den * 10
          digits += 1
        }
        has_frac = true
        i += 1
      } else {
        return None
      }
    }
    if !has_int && !has_frac {
      None
    } else {
      Some((days, frac_num, frac_den))
    }
  }
}

///|
fn xlsx_frac_to_hms(frac_num : Int, frac_den : Int) -> (Int, Int, Int, Int) {
  if frac_den <= 0 || frac_num <= 0 {
    return (0, 0, 0, 0)
  }
  let hh = frac_num * 24 / frac_den
  let rem_h = frac_num * 24 % frac_den
  let mm = rem_h * 60 / frac_den
  let rem_m = rem_h * 60 % frac_den
  let mut ss = (rem_m * 60 + frac_den / 2) / frac_den
  let mut hh2 = hh
  let mut mm2 = mm
  let mut carry = 0
  if ss >= 60 {
    ss -= 60
    mm2 += 1
  }
  if mm2 >= 60 {
    mm2 -= 60
    hh2 += 1
  }
  if hh2 >= 24 {
    hh2 -= 24
    carry = 1
  }
  (carry, hh2, mm2, ss)
}

///|
fn xlsx_excel_serial_to_ymd(
  serial : Int,
  uses_date_1904 : Bool,
) -> (Int, Int, Int) {
  if uses_date_1904 {
    return xlsx_excel_serial_to_ymd_1904(serial)
  }
  if serial <= 0 {
    return (1899, 12, 30)
  }
  if serial == 60 {
    return (1900, 2, 29)
  }
  let mut year = 1900
  let mut month = 1
  let mut day = 1
  let mut days_left = if serial < 60 { serial - 1 } else { serial - 2 }
  while true {
    let days_in_year = if xlsx_is_leap_year(year) { 366 } else { 365 }
    if days_left >= days_in_year {
      days_left -= days_in_year
      year += 1
    } else {
      break
    }
  }
  while true {
    let dim = xlsx_days_in_month(year, month)
    if days_left >= dim {
      days_left -= dim
      month += 1
    } else {
      break
    }
  }
  day += days_left
  (year, month, day)
}

///|
fn xlsx_excel_serial_to_ymd_1904(serial : Int) -> (Int, Int, Int) {
  if serial < 0 {
    return (1903, 12, 31)
  }
  let mut year = 1904
  let mut month = 1
  let mut day = 1
  let mut days_left = serial
  while true {
    let days_in_year = if xlsx_is_leap_year(year) { 366 } else { 365 }
    if days_left >= days_in_year {
      days_left -= days_in_year
      year += 1
    } else {
      break
    }
  }
  while true {
    let dim = xlsx_days_in_month(year, month)
    if days_left >= dim {
      days_left -= dim
      month += 1
    } else {
      break
    }
  }
  day += days_left
  (year, month, day)
}

///|
fn xlsx_is_leap_year(year : Int) -> Bool {
  if year % 400 == 0 {
    true
  } else if year % 100 == 0 {
    false
  } else {
    year % 4 == 0
  }
}

///|
fn xlsx_days_in_month(year : Int, month : Int) -> Int {
  if month == 1 ||
    month == 3 ||
    month == 5 ||
    month == 7 ||
    month == 8 ||
    month == 10 ||
    month == 12 {
    31
  } else if month == 4 || month == 6 || month == 9 || month == 11 {
    30
  } else if xlsx_is_leap_year(year) {
    29
  } else {
    28
  }
}

///|
fn xlsx_pad2(value : Int) -> String {
  if value < 10 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn xlsx_pad4(value : Int) -> String {
  let text = value.to_string()
  if text.length() >= 4 {
    text
  } else if text.length() == 3 {
    "0" + text
  } else if text.length() == 2 {
    "00" + text
  } else {
    "000" + text
  }
}
