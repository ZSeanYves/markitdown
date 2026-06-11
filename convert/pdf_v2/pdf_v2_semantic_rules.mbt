///|
fn pdf_v2_semantic_blocks_from_fragments(
  fragments : Array[PdfV2FactFragment],
  options : PdfV2ProductBridgeOptions,
) -> Array[PdfV2SemanticBlock] {
  let flow = pdf_v2_text_flow_from_fragments(fragments, options)
  pdf_v2_semantic_blocks_from_flow(flow, options)
}

///|
fn pdf_v2_semantic_blocks_from_flow(
  flow : Array[PdfV2TextFlowUnit],
  options : PdfV2ProductBridgeOptions,
) -> Array[PdfV2SemanticBlock] {
  let blocks : Array[PdfV2SemanticBlock] = []
  for unit in flow {
    let rule_decision = pdf_v2_semantic_rule_decision(unit, options)
    let arbitration = pdf_v2_arbitrate_semantic_decision({
      rule_decision,
      model_hint: None,
      disagreement_policy: PdfV2SemanticDisagreementPolicy::RuleHardConstraintsFirst,
    })
    blocks.push(pdf_v2_semantic_block_from_decision(unit, arbitration.decision))
  }
  blocks
}

///|
fn pdf_v2_semantic_rule_decision(
  unit : PdfV2TextFlowUnit,
  options : PdfV2ProductBridgeOptions,
) -> PdfV2RuleDecision {
  if options.enable_noise_guards {
    match pdf_v2_semantic_noise_guard_decision(unit) {
      Some(decision) => return decision
      None => ()
    }
  }
  if options.enable_list_rules {
    match pdf_v2_semantic_list_decision(unit) {
      Some(decision) => return decision
      None => ()
    }
  }
  if options.enable_heading_rules {
    match pdf_v2_semantic_heading_decision(unit) {
      Some(decision) => return decision
      None => ()
    }
  }
  pdf_v2_semantic_paragraph_decision(unit)
}

///|
fn pdf_v2_semantic_noise_guard_decision(
  unit : PdfV2TextFlowUnit,
) -> PdfV2RuleDecision? {
  if unit.normalized_text == "" {
    return Some(
      pdf_v2_semantic_decision(
        PdfV2SemanticBlockKind::Unknown,
        1.0,
        "noise.empty_line_guard",
        ["noise_guard", "empty_line"],
        [],
        unit.source_refs,
        ["hard_negative_rule", "noise_guard"],
      ),
    )
  }
  if unit.signals.looks_like_page_number {
    return Some(
      pdf_v2_semantic_decision(
        PdfV2SemanticBlockKind::PlainText,
        1.0,
        "noise.page_number_guard",
        ["noise_guard", "page_number_like"],
        ["not_heading", "not_list"],
        unit.source_refs,
        ["hard_negative_rule", "noise_guard"],
      ),
    )
  }
  None
}

///|
fn pdf_v2_semantic_list_decision(
  unit : PdfV2TextFlowUnit,
) -> PdfV2RuleDecision? {
  if pdf_v2_semantic_indent_unsupported(unit) {
    return None
  }
  match unit.marker {
    Some(marker) =>
      match marker.kind {
        PdfV2TextFlowMarkerKind::UnorderedListMarker =>
          Some(
            pdf_v2_semantic_decision(
              PdfV2SemanticBlockKind::UnorderedListItem,
              0.93,
              "list.unordered_marker",
              ["list_marker", "unordered_marker", marker.marker_text],
              [],
              unit.source_refs,
              [],
            ),
          )
        PdfV2TextFlowMarkerKind::OrderedListMarker =>
          Some(
            pdf_v2_semantic_decision(
              PdfV2SemanticBlockKind::OrderedListItem,
              0.90,
              "list.ordered_marker",
              ["list_marker", "ordered_marker", marker.marker_text],
              [],
              unit.source_refs,
              [],
            ),
          )
        PdfV2TextFlowMarkerKind::HeadingMarker => None
      }
    None => None
  }
}

///|
fn pdf_v2_semantic_heading_decision(
  unit : PdfV2TextFlowUnit,
) -> PdfV2RuleDecision? {
  if unit.signals.starts_with_heading_marker {
    return Some(
      pdf_v2_semantic_decision(
        PdfV2SemanticBlockKind::Heading,
        0.98,
        "heading.marker_prefix",
        ["heading_marker", "marker_prefix"],
        [],
        unit.source_refs,
        [],
      ),
    )
  }
  let t = pdf_v2_heading_normalize(unit.normalized_text)
  if t == "" {
    return None
  }
  if !unit.signals.is_single_line {
    return None
  }
  if !pdf_v2_heading_basic_shape_ok(t) {
    return None
  }
  if pdf_v2_heading_has_title_shape(t) {
    if unit.signals.has_following_body {
      return Some(
        pdf_v2_semantic_decision(
          PdfV2SemanticBlockKind::Heading,
          0.86,
          "heading.short_single_line_followed_by_body",
          ["short_single_line", "following_body", "title_shape"],
          [],
          unit.source_refs,
          [],
        ),
      )
    }
    if unit.flow_index == 0 {
      return Some(
        pdf_v2_semantic_decision(
          PdfV2SemanticBlockKind::Heading,
          0.78,
          "heading.document_lead_title_shape",
          ["document_lead", "short_single_line", "title_shape"],
          [],
          unit.source_refs,
          [],
        ),
      )
    }
  }
  None
}

///|
fn pdf_v2_semantic_paragraph_decision(
  unit : PdfV2TextFlowUnit,
) -> PdfV2RuleDecision {
  if unit.signals.continuation_candidate && unit.line_count > 1 {
    return pdf_v2_semantic_decision(
      PdfV2SemanticBlockKind::Continuation,
      0.60,
      "continuation.hardwrap_join",
      ["hardwrap_join", "paragraph_continuation"],
      [],
      unit.source_refs,
      [],
    )
  }
  if unit.signals.ends_with_sentence_punctuation {
    return pdf_v2_semantic_decision(
      PdfV2SemanticBlockKind::Paragraph,
      0.76,
      "paragraph.sentence_guard",
      ["sentence_punctuation", "paragraph_guard"],
      [],
      unit.source_refs,
      [],
    )
  }
  pdf_v2_semantic_decision(
    PdfV2SemanticBlockKind::Paragraph,
    0.55,
    "paragraph.default",
    ["paragraph_default"],
    [],
    unit.source_refs,
    [],
  )
}

///|
fn pdf_v2_semantic_block_from_decision(
  unit : PdfV2TextFlowUnit,
  decision : PdfV2RuleDecision,
) -> PdfV2SemanticBlock {
  let text = pdf_v2_semantic_block_text(unit, decision.kind)
  {
    kind: decision.kind,
    text,
    level: pdf_v2_semantic_heading_level(unit, decision.kind),
    ordered: pdf_v2_semantic_ordered_flag(decision.kind),
    list_level: 0,
    page_index: unit.page_index,
    block_index: unit.block_index,
    fragment_index: unit.fragment_index,
    source_refs: unit.source_refs,
    reason_tags: pdf_v2_semantic_merge_tags(
      unit.reason_tags,
      decision.reason_tags,
    ),
    risk_tags: decision.risk_tags,
    decision,
  }
}

///|
fn pdf_v2_semantic_block_text(
  unit : PdfV2TextFlowUnit,
  kind : PdfV2SemanticBlockKind,
) -> String {
  match kind {
    PdfV2SemanticBlockKind::Heading =>
      match unit.marker {
        Some(marker) =>
          if marker.kind == PdfV2TextFlowMarkerKind::HeadingMarker {
            pdf_v2_semantic_normalize_heading_text(marker.body_text)
          } else {
            pdf_v2_semantic_normalize_heading_text(unit.normalized_text)
          }
        None => pdf_v2_semantic_normalize_heading_text(unit.normalized_text)
      }
    PdfV2SemanticBlockKind::OrderedListItem
    | PdfV2SemanticBlockKind::UnorderedListItem =>
      match unit.marker {
        Some(marker) => marker.body_text
        None => unit.normalized_text
      }
    _ => unit.normalized_text
  }
}

///|
fn pdf_v2_semantic_heading_level(
  unit : PdfV2TextFlowUnit,
  kind : PdfV2SemanticBlockKind,
) -> Int? {
  if kind != PdfV2SemanticBlockKind::Heading {
    return None
  }
  match unit.marker {
    Some(marker) =>
      if marker.kind == PdfV2TextFlowMarkerKind::HeadingMarker {
        marker.level_hint
      } else {
        Some(pdf_v2_semantic_infer_heading_level(unit))
      }
    None => Some(pdf_v2_semantic_infer_heading_level(unit))
  }
}

///|
fn pdf_v2_semantic_ordered_flag(kind : PdfV2SemanticBlockKind) -> Bool? {
  match kind {
    PdfV2SemanticBlockKind::OrderedListItem => Some(true)
    PdfV2SemanticBlockKind::UnorderedListItem => Some(false)
    _ => None
  }
}

///|
fn pdf_v2_semantic_infer_heading_level(unit : PdfV2TextFlowUnit) -> Int {
  let text = unit.normalized_text
  if pdf_v2_semantic_numbered_section_depth(text) >= 2 {
    2
  } else if unit.signals.has_previous_heading &&
    pdf_v2_heading_looks_like_common_english_section_label(text) {
    2
  } else {
    1
  }
}

///|
fn pdf_v2_semantic_numbered_section_depth(text : String) -> Int {
  let chars = text.trim().to_owned().to_array()
  if chars.length() == 0 || !pdf_v2_is_ascii_digit(chars[0]) {
    return 0
  }
  let mut i = 0
  let mut dots = 0
  let mut saw_digit = false
  while i < chars.length() {
    let ch = chars[i]
    if pdf_v2_is_ascii_digit(ch) {
      saw_digit = true
      i = i + 1
    } else if ch == '.' {
      dots = dots + 1
      i = i + 1
    } else {
      break
    }
  }
  if saw_digit {
    dots + 1
  } else {
    0
  }
}

///|
fn pdf_v2_semantic_normalize_heading_text(text : String) -> String {
  pdf_v2_semantic_normalize_cjk_heading_spacing(text.trim().to_owned())
}

///|
fn pdf_v2_semantic_normalize_cjk_heading_spacing(text : String) -> String {
  let chars = text.to_array()
  let out = StringBuilder::new()
  for i in 0..<chars.length() {
    let ch = chars[i]
    out.write_char(ch)
    if (ch == '章' || ch == '节') &&
      i + 1 < chars.length() &&
      chars[i + 1] != ' ' &&
      pdf_v2_is_cjk(chars[i + 1]) {
      out.write_char(' ')
    }
  }
  out.to_string()
}

///|
fn pdf_v2_semantic_indent_unsupported(unit : PdfV2TextFlowUnit) -> Bool {
  match unit.indent_level {
    Some(level) => level > 0
    None => false
  }
}

///|
fn pdf_v2_semantic_decision(
  kind : PdfV2SemanticBlockKind,
  confidence : Double,
  rule_id : String,
  reason_tags : Array[String],
  negative_reason_tags : Array[String],
  source_refs : Array[@pdfv2.PdfV2SourceRef],
  risk_tags : Array[String],
) -> PdfV2RuleDecision {
  {
    kind,
    confidence,
    rule_id,
    reason_tags: pdf_v2_semantic_merge_tags(
      ["pdf_v2_semantic_rule"],
      reason_tags,
    ),
    negative_reason_tags,
    source_refs,
    risk_tags,
  }
}

///|
fn pdf_v2_semantic_merge_tags(
  left : Array[String],
  right : Array[String],
) -> Array[String] {
  let out : Array[String] = []
  out.append(left)
  for tag in right {
    if !out.contains(tag) {
      out.push(tag)
    }
  }
  out
}

///|
fn pdf_v2_heading_normalize(text : String) -> String {
  pdf_v2_normalize_paragraph_text(text).trim().to_owned()
}

///|
fn pdf_v2_heading_basic_shape_ok(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }
  if t.length() < 4 || t.length() > 72 {
    return false
  }
  if t.contains("\n") || t.contains("<br") || t.contains("://") {
    return false
  }
  if pdf_v2_heading_ends_sentence(t) ||
    t.has_suffix(":") ||
    t.has_suffix("：") ||
    t.has_suffix(",") ||
    t.has_suffix("，") ||
    t.has_suffix(";") ||
    t.has_suffix("；") {
    return false
  }
  if pdf_v2_is_page_number_like_noise(t) ||
    pdf_v2_heading_looks_like_caption(t) ||
    pdf_v2_heading_looks_like_bullet_or_list_item(t) ||
    pdf_v2_heading_looks_like_complete_statement(t) ||
    pdf_v2_heading_looks_like_intro_phrase(t) {
    return false
  }
  true
}

///|
fn pdf_v2_heading_has_title_shape(text : String) -> Bool {
  pdf_v2_heading_looks_like_chapter_title(text) ||
  pdf_v2_heading_looks_like_numbered_section(text) ||
  pdf_v2_heading_looks_like_english_title(text) ||
  pdf_v2_heading_looks_like_common_english_section_label(text) ||
  pdf_v2_heading_looks_like_cjk_title(text)
}

///|
fn pdf_v2_heading_next_looks_like_body(next_text : String?) -> Bool {
  match next_text {
    None => false
    Some(value) => {
      let t = pdf_v2_heading_normalize(value)
      if t == "" {
        return false
      }
      if pdf_v2_heading_looks_like_bullet_or_list_item(t) {
        return true
      }
      if pdf_v2_heading_ends_sentence(t) {
        return true
      }
      if t.length() >= 24 || pdf_v2_heading_word_count(t) >= 5 {
        return true
      }
      false
    }
  }
}

///|
fn pdf_v2_heading_looks_like_chapter_title(text : String) -> Bool {
  if !text.has_prefix("第") {
    return false
  }
  let n = text.to_array().length()
  n >= 4 && n <= 30 && !pdf_v2_heading_contains_sentence_punct(text)
}

///|
fn pdf_v2_heading_looks_like_numbered_section(text : String) -> Bool {
  let chars = text.to_array()
  if chars.length() < 3 || chars.length() > 48 {
    return false
  }
  let mut i = 0
  let mut saw_digit = false
  while i < chars.length() && pdf_v2_is_ascii_digit(chars[i]) {
    saw_digit = true
    i = i + 1
  }
  if !saw_digit || i >= chars.length() || chars[i] != '.' {
    return false
  }
  i = i + 1
  let mut saw_section_digit = false
  while i < chars.length() {
    let ch = chars[i]
    if pdf_v2_is_ascii_digit(ch) {
      saw_section_digit = true
      i = i + 1
    } else if ch == '.' {
      i = i + 1
    } else {
      break
    }
  }
  if !saw_section_digit || i >= chars.length() {
    return false
  }
  let tail = String::from_array(chars[i:].to_owned()).trim().to_owned()
  tail != "" &&
  tail.length() <= 32 &&
  !pdf_v2_heading_ends_sentence(tail) &&
  !pdf_v2_heading_looks_like_numbered_body_sentence(text)
}

///|
fn pdf_v2_heading_looks_like_english_title(text : String) -> Bool {
  let words = pdf_v2_heading_words(text)
  if words.length() < 2 || words.length() > 6 {
    return false
  }
  let first = pdf_v2_heading_ascii_lower(
    pdf_v2_heading_strip_edge_punct(words[0]),
  )
  if first == "this" || first == "the" || first == "a" || first == "an" {
    return false
  }
  let mut latin_words = 0
  let mut capitalized_words = 0
  let mut has_title_keyword = false
  let mut has_connector = false
  for word in words {
    let stripped = pdf_v2_heading_strip_edge_punct(word)
    let lower = pdf_v2_heading_ascii_lower(stripped)
    if lower == "vs" || lower == "and" || lower == "or" {
      has_connector = true
    }
    if pdf_v2_heading_is_common_english_section_word(lower) ||
      lower == "report" ||
      lower == "pipeline" ||
      lower == "test" ||
      lower == "sample" ||
      lower == "heading" {
      has_title_keyword = true
    }
    if pdf_v2_heading_starts_latin(stripped) {
      latin_words = latin_words + 1
      match pdf_v2_first_char(stripped) {
        Some(ch) =>
          if ch >= 'A' && ch <= 'Z' {
            capitalized_words = capitalized_words + 1
          }
        None => ()
      }
    }
  }
  latin_words >= 2 &&
  capitalized_words >= 2 &&
  (has_title_keyword || has_connector || capitalized_words == latin_words)
}

///|
fn pdf_v2_heading_looks_like_common_english_section_label(
  text : String,
) -> Bool {
  let lower = pdf_v2_heading_ascii_lower(text.trim().to_owned())
  pdf_v2_heading_is_common_english_section_word(lower)
}

///|
fn pdf_v2_heading_is_common_english_section_word(text : String) -> Bool {
  text == "abstract" ||
  text == "introduction" ||
  text == "background" ||
  text == "method" ||
  text == "methods" ||
  text == "results" ||
  text == "discussion" ||
  text == "summary" ||
  text == "details" ||
  text == "conclusion" ||
  text == "references"
}

///|
fn pdf_v2_heading_looks_like_cjk_title(text : String) -> Bool {
  let chars = text.to_array()
  if chars.length() < 4 || chars.length() > 16 {
    return false
  }
  if text.contains(" ") || pdf_v2_heading_contains_sentence_punct(text) {
    return false
  }
  if text.has_prefix("本") ||
    text.has_prefix("该") ||
    text.has_prefix("此") ||
    text.has_prefix("这") {
    return false
  }
  let mut cjkish = 0
  for ch in chars {
    if pdf_v2_is_cjk(ch) {
      cjkish = cjkish + 1
    } else if !pdf_v2_is_ascii_digit(ch) && ch != '.' {
      return false
    }
  }
  cjkish >= 4 && pdf_v2_heading_looks_like_common_cjk_section_label(text)
}

///|
fn pdf_v2_heading_looks_like_common_cjk_section_label(text : String) -> Bool {
  text == "研究内容" ||
  text == "技术路线" ||
  text == "研究方法" ||
  text == "研究目标" ||
  text == "研究背景" ||
  text == "项目概述" ||
  text == "系统概述" ||
  text == "方案概述" ||
  text == "总结" ||
  text == "结论" ||
  text == "下一节"
}

///|
fn pdf_v2_heading_ends_sentence(text : String) -> Bool {
  let t = text.trim().to_owned()
  t.has_suffix(".") ||
  t.has_suffix("!") ||
  t.has_suffix("?") ||
  t.has_suffix("。") ||
  t.has_suffix("！") ||
  t.has_suffix("？")
}

///|
fn pdf_v2_heading_contains_sentence_punct(text : String) -> Bool {
  text.contains("。") ||
  text.contains("！") ||
  text.contains("？") ||
  text.contains("；") ||
  text.contains(";")
}

///|
fn pdf_v2_heading_looks_like_caption(text : String) -> Bool {
  let lower = pdf_v2_heading_ascii_lower(text.trim().to_owned())
  lower.has_prefix("figure ") ||
  lower.has_prefix("fig. ") ||
  lower.has_prefix("table ") ||
  lower.has_prefix("chart ") ||
  lower.has_prefix("image ") ||
  text.has_prefix("图") ||
  text.has_prefix("表")
}

///|
fn pdf_v2_heading_looks_like_bullet_or_list_item(text : String) -> Bool {
  match pdf_v2_text_flow_parse_marker(text) {
    Some(marker) =>
      marker.kind == PdfV2TextFlowMarkerKind::OrderedListMarker ||
      marker.kind == PdfV2TextFlowMarkerKind::UnorderedListMarker
    None => false
  }
}

///|
fn pdf_v2_heading_looks_like_numbered_body_sentence(text : String) -> Bool {
  let lower = pdf_v2_heading_ascii_lower(text.trim().to_owned())
  lower.contains(" this ") ||
  lower.contains(" is ") ||
  lower.contains(" inside ") ||
  lower.contains(" should ") ||
  lower.contains(" paragraph ")
}

///|
fn pdf_v2_heading_looks_like_intro_phrase(text : String) -> Bool {
  let lower = pdf_v2_heading_ascii_lower(text.trim().to_owned())
  lower == "in conclusion," ||
  lower == "in conclusion" ||
  lower == "key points:" ||
  lower == "key points" ||
  lower == "as follows" ||
  text.has_suffix("如下。") ||
  text.has_suffix("如下")
}

///|
fn pdf_v2_heading_looks_like_complete_statement(text : String) -> Bool {
  let words = pdf_v2_heading_words(text)
  if words.length() >= 8 {
    return true
  }
  let lower = pdf_v2_heading_ascii_lower(text)
  if lower.contains(" actually ") ||
    lower.contains(" should ") ||
    lower.contains(" remain ") ||
    lower.contains(" across ") ||
    lower.contains(" method") {
    return true
  }
  false
}

///|
fn pdf_v2_heading_words(text : String) -> Array[String] {
  let out : Array[String] = []
  for raw in text.split(" ") {
    let word = raw.trim().to_owned()
    if word != "" {
      out.push(word)
    }
  }
  out
}

///|
fn pdf_v2_heading_word_count(text : String) -> Int {
  pdf_v2_heading_words(text).length()
}

///|
fn pdf_v2_heading_starts_latin(text : String) -> Bool {
  match pdf_v2_first_char(text) {
    Some(ch) => (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')
    None => false
  }
}

///|
fn pdf_v2_heading_strip_edge_punct(text : String) -> String {
  let chars = text.trim().to_owned().to_array()
  if chars.length() == 0 {
    return ""
  }
  let mut start = 0
  let mut end = chars.length()
  while start < end && pdf_v2_heading_edge_punct(chars[start]) {
    start = start + 1
  }
  while end > start && pdf_v2_heading_edge_punct(chars[end - 1]) {
    end = end - 1
  }
  String::from_array(chars[start:end].to_owned())
}

///|
fn pdf_v2_heading_edge_punct(ch : Char) -> Bool {
  ch == '"' ||
  ch == '\'' ||
  ch == '(' ||
  ch == ')' ||
  ch == '[' ||
  ch == ']' ||
  ch == ',' ||
  ch == '.' ||
  ch == ':' ||
  ch == ';'
}

///|
fn pdf_v2_heading_ascii_lower(text : String) -> String {
  text.to_lower()
}
