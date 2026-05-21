///|
fn read_chart_relationship_id(frame_xml : Bytes) -> String? raise {
  read_attr_value_in_first_tag_bytes(frame_xml, "<c:chart", "r:id")
}

///|
fn collect_tag_text_values(
  xml : Bytes,
  open_tag : String,
  close_tag : String,
) -> Array[String] raise {
  let out : Array[String] = []
  let open_pat = pat(open_tag)
  let close_pat = pat(close_tag)
  let mut pos = 0
  while pos < xml.length() {
    let start0 = find_bytes(xml, open_pat, pos).unwrap_or(-1)
    if start0 < 0 {
      break
    }
    let content_start = start0 + open_pat.length()
    let end0 = find_bytes(xml, close_pat, content_start).unwrap_or(-1)
    if end0 < 0 {
      break
    }
    let raw = bytes_slice_to_string(xml, content_start, end0)
    let value = xml_unescape(raw).trim().to_owned()
    if value != "" {
      out.push(value)
    }
    pos = end0 + close_pat.length()
  }
  out
}

///|
fn first_tag_text_value(
  xml : Bytes,
  open_tag : String,
  close_tag : String,
) -> String? raise {
  let values = collect_tag_text_values(xml, open_tag, close_tag)
  if values.length() == 0 {
    None
  } else {
    Some(values[0])
  }
}

///|
fn extract_first_named_block(
  xml : Bytes,
  open_pat : String,
  tag_name : String,
) -> Bytes? raise {
  let start0 = find_bytes(xml, pat(open_pat), 0).unwrap_or(-1)
  if start0 < 0 {
    return None
  }
  let end0 = find_matching_named_element_close(xml, start0, tag_name).unwrap_or(
    -1,
  )
  if end0 < 0 {
    return None
  }
  Some(xml[start0:end0].to_owned())
}

///|
fn read_chart_title_from_xml(chart_xml : Bytes) -> String? raise {
  match extract_first_named_block(chart_xml, "<c:title", "c:title") {
    Some(title_block) => {
      let parts = collect_tag_text_values(title_block, "<a:t>", "</a:t>")
      let title = parts.join("").trim().to_owned()
      if title == "" {
        None
      } else {
        Some(title)
      }
    }
    None => None
  }
}

///|
fn parse_chart_points_from_cache(cache_xml : Bytes) -> Array[String] raise {
  let out_pairs : Array[(Int, String)] = []
  let mut pos = 0
  while pos < cache_xml.length() {
    let pt_start = find_bytes(cache_xml, pat("<c:pt"), pos).unwrap_or(-1)
    if pt_start < 0 {
      break
    }
    let pt_gt = find_bytes(cache_xml, pat(">"), pt_start).unwrap_or(-1)
    if pt_gt < 0 {
      break
    }
    let pt_end = find_bytes(cache_xml, pat("</c:pt>"), pt_gt + 1).unwrap_or(-1)
    if pt_end < 0 {
      break
    }
    let pt_tag = cache_xml[pt_start:pt_gt + 1].to_owned()
    let idx = match read_attr_value_in_tag_bytes(pt_tag, "idx") {
      Some(value) => parse_nonneg_int(value)
      None => out_pairs.length()
    }
    let value = first_tag_text_value(
      cache_xml[pt_gt + 1:pt_end].to_owned(),
      "<c:v>",
      "</c:v>",
    ).unwrap_or("")
    out_pairs.push((idx, value))
    pos = pt_end + pat("</c:pt>").length()
  }
  out_pairs.sort_by(fn(a, b) { a.0 - b.0 })
  let out : Array[String] = []
  for pair in out_pairs {
    let (_, value) = pair
    out.push(value)
  }
  out
}

///|
fn parse_chart_cache_values(
  scope_xml : Bytes,
  cache_open_pat : String,
  cache_tag_name : String,
) -> Array[String] raise {
  match extract_first_named_block(scope_xml, cache_open_pat, cache_tag_name) {
    Some(cache_xml) => parse_chart_points_from_cache(cache_xml)
    None => []
  }
}

///|
fn parse_chart_multilevel_string_cache(
  scope_xml : Bytes,
) -> Array[String] raise {
  match
    extract_first_named_block(
      scope_xml, "<c:multiLvlStrCache", "c:multiLvlStrCache",
    ) {
    Some(cache_xml) => {
      let levels : Array[Array[String]] = []
      let mut pos = 0
      while pos < cache_xml.length() {
        let lvl_start = find_bytes(cache_xml, pat("<c:lvl"), pos).unwrap_or(-1)
        if lvl_start < 0 {
          break
        }
        let lvl_end = find_matching_named_element_close(
          cache_xml, lvl_start, "c:lvl",
        ).unwrap_or(-1)
        if lvl_end < 0 {
          break
        }
        let lvl_xml = cache_xml[lvl_start:lvl_end].to_owned()
        let values = parse_chart_points_from_cache(lvl_xml)
        if values.length() > 0 {
          levels.push(values)
        }
        pos = lvl_end
      }

      if levels.length() == 0 {
        return []
      }

      let last = levels[levels.length() - 1]
      if last.length() > 0 {
        last
      } else {
        []
      }
    }
    None => []
  }
}

///|
fn parse_chart_series_name(
  series_xml : Bytes,
  fallback_index : Int,
) -> String raise {
  match extract_first_named_block(series_xml, "<c:tx", "c:tx") {
    Some(tx_xml) =>
      match first_tag_text_value(tx_xml, "<c:v>", "</c:v>") {
        Some(value) => value
        None => {
          let cached = parse_chart_cache_values(
            tx_xml, "<c:strCache", "c:strCache",
          )
          if cached.length() > 0 {
            cached[0]
          } else {
            "Series " + fallback_index.to_string()
          }
        }
      }
    None => "Series " + fallback_index.to_string()
  }
}

///|
fn read_chart_cache_format_code(
  scope_xml : Bytes,
  cache_open_pat : String,
  cache_tag_name : String,
) -> String? raise {
  match extract_first_named_block(scope_xml, cache_open_pat, cache_tag_name) {
    Some(cache_xml) =>
      first_tag_text_value(cache_xml, "<c:formatCode>", "</c:formatCode>")
    None => None
  }
}

///|
fn read_chartspace_date1904(chart_xml : Bytes) -> Bool raise {
  match extract_first_named_block(chart_xml, "<c:date1904", "c:date1904") {
    Some(block) =>
      match read_attr_value_in_tag_bytes(block, "val") {
        Some(value) => {
          let trimmed = value.trim().to_owned()
          trimmed == "1" || trimmed.to_lower() == "true"
        }
        None => false
      }
    None => false
  }
}

///|
fn chart_format_code_is_date_like(code : String) -> Bool {
  let lower = code.trim().to_lower()
  if lower == "" || lower == "general" {
    return false
  }

  let mut has_year = false
  let mut has_date_part = false
  for ch in lower.to_array() {
    if ch == 'y' {
      has_year = true
      has_date_part = true
    } else if ch == 'm' || ch == 'd' {
      has_date_part = true
    }
  }
  has_year && has_date_part
}

///|
fn format_chart_cached_category_value(
  raw : String,
  format_code : String?,
  uses_date_1904 : Bool,
) -> String {
  match format_code {
    Some(code) =>
      if chart_format_code_is_date_like(code) {
        match parse_chart_excel_serial(raw) {
          Some(serial) => {
            let (y, m, d) = chart_excel_serial_to_ymd(serial, uses_date_1904)
            chart_pad4(y) + "-" + chart_pad2(m) + "-" + chart_pad2(d)
          }
          None => raw
        }
      } else {
        raw
      }
    None => raw
  }
}

///|
fn parse_chart_excel_serial(s : String) -> Int? {
  let t = @cor.trim_string(s)
  if t == "" {
    return None
  }

  let cs = t.to_array()
  let mut i = 0
  let n = cs.length()
  let mut days = 0
  let mut has_int = false

  if i < n && (cs[i] == '-' || cs[i] == '+') {
    return None
  }

  while i < n {
    let ch = cs[i]
    if ch >= '0' && ch <= '9' {
      days = days * 10 + (ch.to_int() - '0'.to_int())
      has_int = true
      i += 1
    } else {
      break
    }
  }

  if !has_int {
    return None
  }

  if i == n {
    return Some(days)
  }

  if cs[i] != '.' {
    return None
  }

  i += 1
  while i < n {
    let ch = cs[i]
    if ch < '0' || ch > '9' {
      return None
    }
    i += 1
  }

  Some(days)
}

///|
fn chart_excel_serial_to_ymd(
  serial : Int,
  uses_date_1904 : Bool,
) -> (Int, Int, Int) {
  if uses_date_1904 {
    return chart_excel_serial_to_ymd_1904(serial)
  }

  if serial <= 0 {
    return (1899, 12, 30)
  }

  if serial == 60 {
    return (1900, 2, 29)
  }

  let mut y = 1900
  let mut m = 1
  let mut d = 1
  let mut days_left = if serial < 60 { serial - 1 } else { serial - 2 }

  while true {
    let diy = if chart_is_leap_year(y) { 366 } else { 365 }
    if days_left >= diy {
      days_left = days_left - diy
      y = y + 1
    } else {
      break
    }
  }

  while true {
    let dim = chart_days_in_month(y, m)
    if days_left >= dim {
      days_left = days_left - dim
      m = m + 1
    } else {
      break
    }
  }

  d = d + days_left
  (y, m, d)
}

///|
fn chart_excel_serial_to_ymd_1904(serial : Int) -> (Int, Int, Int) {
  if serial < 0 {
    return (1903, 12, 31)
  }

  let mut y = 1904
  let mut m = 1
  let mut d = 1
  let mut days_left = serial

  while true {
    let diy = if chart_is_leap_year(y) { 366 } else { 365 }
    if days_left >= diy {
      days_left = days_left - diy
      y = y + 1
    } else {
      break
    }
  }

  while true {
    let dim = chart_days_in_month(y, m)
    if days_left >= dim {
      days_left = days_left - dim
      m = m + 1
    } else {
      break
    }
  }

  d = d + days_left
  (y, m, d)
}

///|
fn chart_is_leap_year(y : Int) -> Bool {
  if y % 400 == 0 {
    true
  } else if y % 100 == 0 {
    false
  } else {
    y % 4 == 0
  }
}

///|
fn chart_days_in_month(y : Int, m : Int) -> Int {
  if m == 1 {
    31
  } else if m == 2 {
    if chart_is_leap_year(y) {
      29
    } else {
      28
    }
  } else if m == 3 {
    31
  } else if m == 4 {
    30
  } else if m == 5 {
    31
  } else if m == 6 {
    30
  } else if m == 7 {
    31
  } else if m == 8 {
    31
  } else if m == 9 {
    30
  } else if m == 10 {
    31
  } else if m == 11 {
    30
  } else {
    31
  }
}

///|
fn chart_pad2(n : Int) -> String {
  if n < 10 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

///|
fn chart_pad4(n : Int) -> String {
  if n < 10 {
    "000" + n.to_string()
  } else if n < 100 {
    "00" + n.to_string()
  } else if n < 1000 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

///|
fn parse_chart_series_categories(
  series_xml : Bytes,
  uses_date_1904 : Bool,
) -> Array[String] raise {
  match extract_first_named_block(series_xml, "<c:cat", "c:cat") {
    Some(cat_xml) => {
      let multilevel_strings = parse_chart_multilevel_string_cache(cat_xml)
      if multilevel_strings.length() > 0 {
        multilevel_strings
      } else {
        let strings = parse_chart_cache_values(
          cat_xml, "<c:strCache", "c:strCache",
        )
        if strings.length() > 0 {
          strings
        } else {
          let numbers = parse_chart_cache_values(
            cat_xml, "<c:numCache", "c:numCache",
          )
          let format_code = read_chart_cache_format_code(
            cat_xml, "<c:numCache", "c:numCache",
          )
          let formatted : Array[String] = []
          for value in numbers {
            formatted.push(
              format_chart_cached_category_value(
                value, format_code, uses_date_1904,
              ),
            )
          }
          formatted
        }
      }
    }
    None => []
  }
}

///|
fn parse_chart_series_values(series_xml : Bytes) -> Array[String] raise {
  match extract_first_named_block(series_xml, "<c:val", "c:val") {
    Some(val_xml) =>
      parse_chart_cache_values(val_xml, "<c:numCache", "c:numCache")
    None => []
  }
}

///|
fn parse_chart_series_blocks(
  chart_xml : Bytes,
  uses_date_1904 : Bool,
) -> Array[PptxChartSeries] raise {
  let out : Array[PptxChartSeries] = []
  let mut pos = 0
  let mut index = 1
  while pos < chart_xml.length() {
    let ser_start = find_bytes(chart_xml, pat("<c:ser"), pos).unwrap_or(-1)
    if ser_start < 0 {
      break
    }
    let ser_end = find_matching_named_element_close(
      chart_xml, ser_start, "c:ser",
    ).unwrap_or(-1)
    if ser_end < 0 {
      break
    }
    let series_xml = chart_xml[ser_start:ser_end].to_owned()
    out.push({
      name: parse_chart_series_name(series_xml, index),
      categories: parse_chart_series_categories(series_xml, uses_date_1904),
      values: parse_chart_series_values(series_xml),
    })
    index += 1
    pos = ser_end
  }
  out
}

///|
fn parse_pptx_chart_cache_from_xml(
  chart_xml : Bytes,
  source_part : String,
  relationship_id : String?,
) -> PptxChartData? raise {
  if !contains_bytes(chart_xml, pat("<c:chartSpace")) {
    return None
  }
  let uses_date_1904 = read_chartspace_date1904(chart_xml)
  Some({
    title: read_chart_title_from_xml(chart_xml),
    series: parse_chart_series_blocks(chart_xml, uses_date_1904),
    source_part,
    relationship_id,
    has_external_data: contains_bytes(chart_xml, pat("<c:externalData")),
  })
}

///|
fn read_chart_data_from_frame(
  frame_xml : Bytes,
  ctx : PptxShapeParseContext,
  object_ref : String?,
) -> PptxChartData? raise {
  match read_chart_relationship_id(frame_xml) {
    Some(rel_id) =>
      match find_pptx_relationship_by_id(ctx.rels, rel_id) {
        Some(rel) =>
          if rel.rel_type.has_suffix("/chart") &&
            rel.resolved_target.trim() != "" &&
            @ox.has_part(ctx.pkg, rel.resolved_target) {
            let chart_xml = @ox.read_part_bytes(ctx.pkg, rel.resolved_target) catch {
              _ => return None
            }
            parse_pptx_chart_cache_from_xml(
              chart_xml,
              rel.resolved_target,
              Some(rel.id),
            )
          } else {
            None
          }
        None => {
          ctx.issues.push(
            pptx_issue(
              PptxValidationIssueKind::MissingRelationshipTarget,
              PptxValidationSeverity::Warning,
              Some(ctx.source_part),
              Some(rel_id),
              object_ref,
              "missing chart relationship target: " + rel_id,
            ),
          )
          None
        }
      }
    None => None
  }
}
