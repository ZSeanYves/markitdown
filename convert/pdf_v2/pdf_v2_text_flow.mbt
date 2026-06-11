///|
fn pdf_v2_text_flow_from_fragments(
  fragments : Array[PdfV2FactFragment],
  options : PdfV2ProductBridgeOptions,
) -> Array[PdfV2TextFlowUnit] {
  let paragraphs = pdf_v2_text_output_paragraphs(fragments, options)
  pdf_v2_text_flow_from_paragraphs(fragments, paragraphs)
}

///|
fn pdf_v2_text_flow_from_paragraphs(
  fragments : Array[PdfV2FactFragment],
  paragraphs : Array[PdfV2TextOutputParagraph],
) -> Array[PdfV2TextFlowUnit] {
  let units : Array[PdfV2TextFlowUnit] = []
  let mut previous_heading = false
  for i in 0..<paragraphs.length() {
    let paragraph = paragraphs[i]
    let fragment = fragments[paragraph.fragment_index]
    let text = paragraph.text
    let normalized_text = pdf_v2_normalize_paragraph_text(text)
    let line_count = if paragraph.line_count > fragment.line_count {
      paragraph.line_count
    } else {
      fragment.line_count
    }
    let next_text = if i + 1 < paragraphs.length() {
      Some(paragraphs[i + 1].text)
    } else {
      None
    }
    let marker = pdf_v2_text_flow_parse_marker(normalized_text)
    let marker_kind = match marker {
      Some(value) => Some(value.kind)
      None => None
    }
    let signals = pdf_v2_text_flow_signals(
      normalized_text, line_count, marker, next_text, previous_heading,
    )
    let unit : PdfV2TextFlowUnit = {
      page_index: fragment.page_index,
      block_index: fragment.block_index,
      flow_index: i,
      fragment_index: paragraph.fragment_index,
      line_start: None,
      line_end: None,
      text,
      normalized_text,
      line_count,
      char_count: normalized_text.to_array().length(),
      starts_with_marker: marker is Some(_),
      marker_kind,
      marker,
      indent_level: pdf_v2_text_flow_best_indent_level(fragment.text, text),
      source_refs: fragment.source_refs,
      reason_tags: fragment.reason_tags,
      signals,
    }
    units.push(unit)
    previous_heading = pdf_v2_text_flow_unit_shape_is_heading(unit)
  }
  units
}

///|
fn pdf_v2_text_flow_parse_marker(text : String) -> PdfV2TextFlowMarker? {
  let t = text.trim().to_owned()
  if t == "" {
    return None
  }
  match pdf_v2_text_flow_parse_heading_marker(t) {
    Some(marker) => return Some(marker)
    None => ()
  }
  match pdf_v2_text_flow_parse_unordered_marker(t) {
    Some(marker) => return Some(marker)
    None => ()
  }
  pdf_v2_text_flow_parse_ordered_marker(t)
}

///|
fn pdf_v2_text_flow_parse_heading_marker(text : String) -> PdfV2TextFlowMarker? {
  let chars = text.to_array()
  if chars.length() < 3 || chars[0] != '#' {
    return None
  }
  let mut count = 0
  while count < chars.length() && chars[count] == '#' {
    count = count + 1
  }
  if count <= 0 || count > 6 || count >= chars.length() || chars[count] != ' ' {
    return None
  }
  let body = String::from_array(chars[count + 1:].to_owned()).trim().to_owned()
  if body == "" {
    return None
  }
  Some({
    kind: PdfV2TextFlowMarkerKind::HeadingMarker,
    marker_text: "#".repeat(count),
    body_text: body,
    level_hint: Some(count),
  })
}

///|
fn pdf_v2_text_flow_parse_unordered_marker(
  text : String,
) -> PdfV2TextFlowMarker? {
  let chars = text.to_array()
  if chars.length() < 3 {
    return None
  }
  let marker = chars[0]
  if marker != '-' && marker != '*' && marker != '•' {
    return None
  }
  if chars[1] != ' ' {
    return None
  }
  let body = String::from_array(chars[2:].to_owned()).trim().to_owned()
  if body == "" || pdf_v2_text_flow_is_separator_line(body) {
    return None
  }
  Some({
    kind: PdfV2TextFlowMarkerKind::UnorderedListMarker,
    marker_text: marker.to_string(),
    body_text: body,
    level_hint: Some(0),
  })
}

///|
fn pdf_v2_text_flow_parse_ordered_marker(text : String) -> PdfV2TextFlowMarker? {
  match pdf_v2_text_flow_parse_ascii_ordered_marker(text) {
    Some(marker) => return Some(marker)
    None => ()
  }
  match pdf_v2_text_flow_parse_parenthesized_digit_marker(text) {
    Some(marker) => return Some(marker)
    None => ()
  }
  pdf_v2_text_flow_parse_cjk_ordered_marker(text)
}

///|
fn pdf_v2_text_flow_parse_ascii_ordered_marker(
  text : String,
) -> PdfV2TextFlowMarker? {
  let chars = text.to_array()
  if chars.length() < 4 || !pdf_v2_is_ascii_digit(chars[0]) {
    return None
  }
  let mut i = 0
  while i < chars.length() && pdf_v2_is_ascii_digit(chars[i]) {
    i = i + 1
  }
  if i == 0 || i + 1 >= chars.length() {
    return None
  }
  let marker_end = chars[i]
  if marker_end != '.' && marker_end != ')' && marker_end != '）' {
    return None
  }
  if marker_end == '.' &&
    i + 1 < chars.length() &&
    pdf_v2_is_ascii_digit(chars[i + 1]) {
    return None
  }
  if chars[i + 1] != ' ' {
    return None
  }
  let body = String::from_array(chars[i + 2:].to_owned()).trim().to_owned()
  if body == "" {
    return None
  }
  Some({
    kind: PdfV2TextFlowMarkerKind::OrderedListMarker,
    marker_text: String::from_array(chars[:i + 1].to_owned()),
    body_text: body,
    level_hint: Some(0),
  })
}

///|
fn pdf_v2_text_flow_parse_parenthesized_digit_marker(
  text : String,
) -> PdfV2TextFlowMarker? {
  let chars = text.to_array()
  if chars.length() < 5 || (chars[0] != '(' && chars[0] != '（') {
    return None
  }
  let close = if chars[0] == '(' { ')' } else { '）' }
  let mut i = 1
  while i < chars.length() && pdf_v2_is_ascii_digit(chars[i]) {
    i = i + 1
  }
  if i == 1 ||
    i + 1 >= chars.length() ||
    chars[i] != close ||
    chars[i + 1] != ' ' {
    return None
  }
  let body = String::from_array(chars[i + 2:].to_owned()).trim().to_owned()
  if body == "" {
    return None
  }
  Some({
    kind: PdfV2TextFlowMarkerKind::OrderedListMarker,
    marker_text: String::from_array(chars[:i + 1].to_owned()),
    body_text: body,
    level_hint: Some(0),
  })
}

///|
fn pdf_v2_text_flow_parse_cjk_ordered_marker(
  text : String,
) -> PdfV2TextFlowMarker? {
  let chars = text.to_array()
  if chars.length() < 4 {
    return None
  }
  let close_index = if chars[0] == '（' {
    2
  } else if chars[0] == '(' {
    2
  } else {
    -1
  }
  if close_index < 0 || chars.length() <= close_index {
    return None
  }
  let close = if chars[0] == '（' { '）' } else { ')' }
  if chars[close_index] != close ||
    !pdf_v2_text_flow_is_cjk_order_token(chars[1]) {
    return None
  }
  let body_start = close_index + 1
  if body_start >= chars.length() {
    return None
  }
  let body = String::from_array(chars[body_start:].to_owned()).trim().to_owned()
  if body == "" {
    return None
  }
  Some({
    kind: PdfV2TextFlowMarkerKind::OrderedListMarker,
    marker_text: String::from_array(chars[:close_index + 1].to_owned()),
    body_text: body,
    level_hint: Some(0),
  })
}

///|
fn pdf_v2_text_flow_signals(
  text : String,
  line_count : Int,
  marker : PdfV2TextFlowMarker?,
  next_text : String?,
  previous_heading : Bool,
) -> PdfV2TextFlowSignals {
  let char_count = text.to_array().length()
  {
    is_single_line: line_count <= 1,
    is_short: char_count <= 72,
    ends_with_sentence_punctuation: pdf_v2_heading_ends_sentence(text),
    starts_with_ordered_marker: match marker {
      Some(value) => value.kind == PdfV2TextFlowMarkerKind::OrderedListMarker
      None => false
    },
    starts_with_unordered_marker: match marker {
      Some(value) => value.kind == PdfV2TextFlowMarkerKind::UnorderedListMarker
      None => false
    },
    starts_with_heading_marker: match marker {
      Some(value) => value.kind == PdfV2TextFlowMarkerKind::HeadingMarker
      None => false
    },
    looks_like_page_number: pdf_v2_is_page_number_like_noise(text),
    looks_like_caption_marker: pdf_v2_heading_looks_like_caption(text),
    has_following_body: pdf_v2_heading_next_looks_like_body(next_text),
    has_previous_heading: previous_heading,
    continuation_candidate: line_count > 1 ||
    pdf_v2_text_flow_continuation_shape(text),
  }
}

///|
fn pdf_v2_text_flow_indent_level(text : String) -> Int? {
  let mut spaces = 0
  for ch in text {
    if ch == ' ' {
      spaces = spaces + 1
    } else if ch == '\t' {
      spaces = spaces + 2
    } else {
      break
    }
  }
  if spaces <= 0 {
    None
  } else {
    Some(spaces / 2)
  }
}

///|
fn pdf_v2_text_flow_best_indent_level(raw_text : String, text : String) -> Int? {
  match pdf_v2_text_flow_indent_level(raw_text) {
    Some(level) => Some(level)
    None => pdf_v2_text_flow_indent_level(text)
  }
}

///|
fn pdf_v2_text_flow_unit_shape_is_heading(unit : PdfV2TextFlowUnit) -> Bool {
  if unit.signals.starts_with_heading_marker {
    return true
  }
  unit.signals.is_single_line &&
  unit.signals.is_short &&
  !unit.signals.ends_with_sentence_punctuation &&
  !unit.signals.looks_like_page_number &&
  !unit.signals.looks_like_caption_marker &&
  pdf_v2_heading_has_title_shape(unit.normalized_text)
}

///|
fn pdf_v2_text_flow_continuation_shape(text : String) -> Bool {
  match pdf_v2_first_char(text) {
    Some(ch) => ch >= 'a' && ch <= 'z'
    None => false
  }
}

///|
fn pdf_v2_text_flow_is_separator_line(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t.length() < 3 {
    return false
  }
  for ch in t {
    if ch != '-' && ch != '=' && ch != '_' && ch != '*' {
      return false
    }
  }
  true
}

///|
fn pdf_v2_text_flow_is_cjk_order_token(ch : Char) -> Bool {
  ch == '一' ||
  ch == '二' ||
  ch == '三' ||
  ch == '四' ||
  ch == '五' ||
  ch == '六' ||
  ch == '七' ||
  ch == '八' ||
  ch == '九' ||
  ch == '十'
}
