///|
/// Caption, object-proximity, asset, link, and code-like layout text signals.
fn caption_marker_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  if trimmed == "" {
    return false
  }
  count_feature_words(trimmed) <= 12 &&
  (
    starts_with_enumerated_caption_prefix(lower, "figure ") ||
    starts_with_enumerated_caption_prefix(lower, "fig. ") ||
    starts_with_enumerated_caption_prefix(lower, "fig ") ||
    starts_with_enumerated_caption_prefix(lower, "table ") ||
    starts_with_enumerated_caption_prefix(lower, "chart ")
  )
}

///|
fn caption_marker_figure_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  if trimmed == "" {
    return false
  }
  starts_with_enumerated_caption_prefix(lower, "figure ") ||
  starts_with_enumerated_caption_prefix(lower, "fig. ") ||
  starts_with_enumerated_caption_prefix(lower, "fig ") ||
  lower.has_prefix("图 ") ||
  lower == "图"
}

///|
fn caption_marker_table_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  if trimmed == "" {
    return false
  }
  starts_with_enumerated_caption_prefix(lower, "table ") ||
  starts_with_enumerated_caption_prefix(lower, "chart ") ||
  lower.has_prefix("表 ") ||
  lower == "表"
}

///|
fn caption_marker_starts_line_signal(text : String) -> Bool {
  caption_marker_figure_signal(text) || caption_marker_table_signal(text)
}

///|
fn caption_reference_only_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  if trimmed == "" || caption_marker_starts_line_signal(trimmed) {
    return false
  }
  lower.contains("figure ") ||
  lower.contains("fig. ") ||
  lower.contains("fig ") ||
  lower.contains("table ") ||
  lower.contains("chart ") ||
  lower.contains("图 ") ||
  lower.contains("表 ")
}

///|
fn caption_lead_in_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  if trimmed == "" {
    return false
  }
  if caption_reference_only_signal(trimmed) {
    return true
  }
  if !caption_marker_starts_line_signal(trimmed) {
    return false
  }
  let word_count = count_feature_words(trimmed)
  if ends_with_colon_signal(trimmed) && word_count >= 6 {
    return true
  }
  if has_terminal_period_signal(trimmed) && word_count >= 10 {
    return true
  }
  lower.contains(" illustrates ") ||
  lower.contains(" illustrate ") ||
  lower.contains(" shows ") ||
  lower.contains(" show ") ||
  lower.contains(" below ") ||
  lower.contains(" above ") ||
  lower.contains(" depicts ") ||
  lower.contains(" presents ") ||
  lower.contains(" describes ") ||
  lower.contains(" following ")
}

///|
fn starts_with_enumerated_caption_prefix(
  lower : String,
  prefix : String,
) -> Bool {
  if !lower.has_prefix(prefix) {
    return false
  }
  let chars = lower.to_array()
  let prefix_len = prefix.length()
  if prefix_len >= chars.length() {
    return false
  }
  let next = chars[prefix_len]
  is_ascii_digit(next) || (next >= 'a' && next <= 'z')
}

///|
fn near_image_object_signal(near_image_distance : Double?) -> Bool {
  match near_image_distance {
    Some(distance) => distance >= 0.0 && distance <= 36.0
    None => false
  }
}

///|
fn normalized_object_distance_ratio(
  near_image_distance : Double?,
  page_height : Double,
) -> Double? {
  match near_image_distance {
    Some(distance) =>
      if page_height > 0.0 {
        Some(distance / page_height)
      } else {
        None
      }
    None => None
  }
}

///|
fn caption_heading_conflict_signal(
  caption_marker_starts_line : Bool,
  block : PdfConvertBlock,
  page_box : @model.PdfRect,
  page_median_font_size : Double?,
) -> Bool {
  if !caption_marker_starts_line {
    return false
  }
  if block.is_caption_candidate {
    return false
  }
  let relative = relative_font_size(
    block.dominant_font_size,
    page_median_font_size,
  )
  let font_conflict = match relative {
    Some(value) => value >= 1.18 && block.line_count <= 2
    None => false
  }
  (top_zone_candidate(block._bbox, page_box) && font_conflict) || font_conflict
}

///|
fn asset_metadata_noise_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  if trimmed == "" {
    return false
  }
  if lower.contains(".png") ||
    lower.contains(".jpg") ||
    lower.contains(".jpeg") ||
    lower.contains(".gif") ||
    lower.contains(".svg") ||
    lower.contains(".tif") ||
    lower.contains(".bmp") {
    return true
  }
  if looks_like_uuidish_signal(trimmed) {
    return true
  }
  count_feature_words(trimmed) <= 2 &&
  contains_path_like_signal(trimmed) &&
  (
    lower.contains("/images/") ||
    lower.contains("\\images\\") ||
    lower.contains("/assets/") ||
    lower.contains("\\assets\\") ||
    lower.contains("/media/") ||
    lower.contains("\\media\\")
  )
}

///|
fn toc_like_anchor_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" || count_feature_words(trimmed) < 3 {
    return false
  }
  has_dotted_leader_page_token_signal(trimmed)
}

///|
fn visible_url_without_annotation_signal(
  contains_url : Bool,
  contains_email : Bool,
  link_summary : PdfBlockLinkFeatureSummary,
) -> Bool {
  (contains_url || contains_email) &&
  !link_summary.has_uri_target &&
  !link_summary.has_internal_target &&
  !link_summary.has_named_target &&
  link_summary.text_coverage_ratio < 0.05
}

///|
fn code_like_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  if trimmed == "" {
    return false
  }
  option_like_signal(trimmed) ||
  contains_path_like_signal(trimmed) ||
  trimmed.has_prefix("--") ||
  trimmed.has_prefix("$ ") ||
  trimmed.contains("::") ||
  trimmed.contains("->") ||
  trimmed.contains("=>") ||
  trimmed.contains("{}") ||
  trimmed.contains("[]") ||
  trimmed.contains("()") ||
  lower.contains("usage:") ||
  lower.contains("command line") ||
  lower.contains(".json") ||
  lower.contains(".xml") ||
  lower.contains(".xhtml") ||
  lower.contains(".epub")
}

///|
fn monospace_hint(block : PdfConvertBlock) -> Bool {
  match block.dominant_font_name {
    Some(name) => {
      let lower = name.to_lower()
      lower.contains("courier") ||
      lower.contains("mono") ||
      lower.contains("monaco") ||
      lower.contains("consola") ||
      lower.contains("menlo") ||
      lower.contains("inconsolata") ||
      lower.contains("sourcecode") ||
      lower.contains("liberationmono") ||
      lower.contains("dejavusansmono")
    }
    None => false
  }
}
