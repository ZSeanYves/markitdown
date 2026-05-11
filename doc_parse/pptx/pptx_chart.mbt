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
fn parse_chart_series_categories(series_xml : Bytes) -> Array[String] raise {
  match extract_first_named_block(series_xml, "<c:cat", "c:cat") {
    Some(cat_xml) => {
      let strings = parse_chart_cache_values(
        cat_xml, "<c:strCache", "c:strCache",
      )
      if strings.length() > 0 {
        strings
      } else {
        parse_chart_cache_values(cat_xml, "<c:numCache", "c:numCache")
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
fn parse_chart_series_blocks(chart_xml : Bytes) -> Array[PptxChartSeries] raise {
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
      categories: parse_chart_series_categories(series_xml),
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
  Some({
    title: read_chart_title_from_xml(chart_xml),
    series: parse_chart_series_blocks(chart_xml),
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
