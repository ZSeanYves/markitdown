///|
/// Private support helpers for PDF layout gate evidence and decision plumbing.
fn gate_footer_noise_evidence(features : Map[String, Double]) -> Bool {
  if gate_feature_bool(features, "cleanup_shell_signal") {
    return false
  }

  gate_feature_bool(features, "repeated_edge_candidate") ||
  (
    gate_feature_num(features, "repeated_text_score") >= 0.34 &&
    (
      gate_feature_bool(features, "top_zone_candidate") ||
      gate_feature_bool(features, "bottom_zone_candidate")
    )
  ) ||
  gate_feature_bool(features, "page_label_pattern_signal") ||
  gate_feature_bool(features, "is_page_number_candidate") ||
  gate_feature_bool(features, "is_header_footer_candidate") ||
  gate_feature_bool(features, "is_artifact_candidate")
}

///|
fn gate_receipt_form_evidence(features : Map[String, Double]) -> Bool {
  gate_feature_bool(features, "receipt_line_item_signal") ||
  gate_feature_bool(features, "payment_card_signal") ||
  gate_feature_bool(features, "quantity_price_signal")
}

///|
fn gate_receipt_settlement_heading_evidence(
  block : PdfConvertBlock,
  prev : PdfConvertBlock?,
  next : PdfConvertBlock?,
  features : Map[String, Double],
) -> Bool {
  if !gate_feature_bool(features, "is_heading_candidate") {
    return false
  }
  if gate_feature_bool(features, "sentence_like_signal") ||
    gate_feature_bool(features, "contains_clause_punctuation") ||
    gate_feature_bool(features, "has_terminal_period") {
    return false
  }
  if !gate_feature_bool(features, "contains_currency") {
    return false
  }
  let word_count = gate_feature_num(features, "word_count")
  if word_count <= 0.0 || word_count > 3.0 {
    return false
  }
  let relative_font = gate_feature_num(features, "relative_font_size")
  if relative_font < 1.0 || relative_font > 1.2 {
    return false
  }

  let text = normalize_pdf_comparison_text(block.text)
  if !looks_like_receipt_settlement_heading_text(text) {
    return false
  }

  let prev_separator = block_neighbor_is_separator(prev)
  let next_separator = block_neighbor_is_separator(next)

  prev_separator && next_separator
}

///|
fn looks_like_receipt_settlement_heading_text(text : String) -> Bool {
  let upper = text.trim().to_upper()
  if upper == "" {
    return false
  }

  let words : Array[String] = []
  for part in upper.split(" ") {
    if part != "" {
      words.push(part.to_owned())
    }
  }
  if words.length() == 0 {
    return false
  }
  let head = words[0]
  let second = if words.length() > 1 { words[1] } else { "" }

  head == "TOTAL" ||
  head == "SUBTOTAL" ||
  head == "DISCOUNT" ||
  (head == "SALES" && second == "TAX") ||
  (head == "REWARDS" && second == "APPLIED") ||
  (head == "BALANCE" && second == "DUE") ||
  (head == "AMOUNT" && second == "DUE")
}

///|
fn block_neighbor_is_separator(block : PdfConvertBlock?) -> Bool {
  match block {
    Some(value) =>
      looks_like_separator_line_for_ir(value.text.trim().to_owned())
    None => false
  }
}

///|
fn gate_technical_keep_as_text_evidence(features : Map[String, Double]) -> Bool {
  if gate_feature_bool(features, "visible_url_without_annotation") ||
    gate_feature_bool(features, "contains_url_or_email") {
    return false
  }
  if gate_feature_bool(features, "repeated_edge_candidate") &&
    gate_feature_num(features, "repeated_text_score") >= 0.5 {
    return false
  }
  if gate_receipt_form_evidence(features) {
    return false
  }
  if gate_feature_bool(features, "sentence_like_signal") ||
    gate_feature_bool(features, "figure_reference_sentence_signal") ||
    gate_feature_bool(features, "section_reference_sentence_signal") ||
    gate_feature_bool(features, "technical_sentence_guard_signal") ||
    gate_feature_bool(features, "citation_reference_signal") {
    return false
  }
  if (
      gate_feature_bool(features, "contains_currency") ||
      gate_feature_bool(features, "contains_time") ||
      gate_feature_bool(features, "contains_date")
    ) &&
    !(gate_feature_bool(features, "contains_path_like") ||
    gate_feature_bool(features, "identifier_like_signal") ||
    gate_feature_bool(features, "option_like_signal")) {
    return false
  }

  gate_feature_bool(features, "technical_literal_signal") ||
  gate_feature_bool(features, "identifier_like_signal") ||
  gate_feature_bool(features, "contains_path_like") ||
  gate_feature_bool(features, "code_like_signal") ||
  gate_feature_bool(features, "option_like_signal") ||
  gate_feature_bool(features, "monospace_hint")
}

///|
fn gate_heading_separator_or_sentence_evidence(
  block : PdfConvertBlock,
  next : PdfConvertBlock?,
  features : Map[String, Double],
) -> Bool {
  if gate_feature_bool(features, "cleanup_shell_signal") {
    return false
  }

  if gate_feature_bool(features, "looks_like_separator") {
    return true
  }

  if gate_feature_bool(features, "looks_like_bullet") &&
    gate_feature_num(features, "word_count") <= 2.0 {
    return true
  }

  if gate_feature_bool(features, "sentence_like_signal") ||
    gate_feature_bool(features, "figure_reference_sentence_signal") ||
    gate_feature_bool(features, "section_reference_sentence_signal") ||
    gate_feature_bool(features, "citation_reference_signal") ||
    gate_feature_bool(features, "technical_sentence_guard_signal") {
    return true
  }

  if gate_feature_bool(features, "has_terminal_period") ||
    gate_feature_bool(features, "contains_clause_punctuation") {
    return true
  }

  let text = normalize_pdf_comparison_text(block.text)
  gate_feature_num(features, "word_count") >= 6.0 &&
  next_block_looks_like_body(next) &&
  !looks_like_section_heading(text)
}

///|
fn standalone_bullet_text_signal(
  text : String,
  item_text : String,
  features : Map[String, Double],
) -> Bool {
  if gate_feature_bool(features, "looks_like_separator") {
    return true
  }
  if item_text.trim() == "" {
    return true
  }
  let word_count = count_feature_words(item_text)
  if word_count <= 2 &&
    !gate_feature_bool(features, "sentence_like_signal") &&
    !gate_feature_bool(features, "contains_clause_punctuation") &&
    !gate_feature_bool(features, "has_terminal_period") {
    return true
  }
  let trimmed = text.trim().to_owned()
  trimmed == "•" || trimmed == "-" || trimmed == "*"
}

///|
fn gate_hard_constraints(
  features : Map[String, Double],
  allow_heading_constraints : Bool,
) -> Array[String] {
  let out : Array[String] = []
  if gate_feature_bool(features, "is_table_cell_candidate") {
    out.push("table_geometry")
  }
  if gate_feature_bool(features, "is_caption_candidate") {
    out.push("caption_geometry")
  }
  if gate_strong_link_payload_signal(features) {
    out.push("link_payload")
  }
  if allow_heading_constraints &&
    gate_feature_bool(features, "page_number_like_link") {
    out.push("page_reference_integrity")
  }
  out
}

///|
fn gate_strong_link_payload_signal(features : Map[String, Double]) -> Bool {
  gate_feature_bool(features, "has_link_inline") ||
  gate_feature_bool(features, "is_link_only_candidate") ||
  gate_feature_bool(features, "link_target_uri") ||
  gate_feature_bool(features, "link_target_internal") ||
  gate_feature_bool(features, "link_target_named")
}

///|
fn layout_gate_feature_values(
  doc_ctx : PdfLayoutGateDocContext,
  page : PdfConvertPage,
  block : PdfConvertBlock,
  prev : PdfConvertBlock?,
  next : PdfConvertBlock?,
  page_font_median : Double?,
) -> Map[String, Double] {
  block_layout_feature_values(
    page,
    block,
    prev,
    next,
    pdf_layout_gate_repeated_text_score(
      doc_ctx.repeated_counts,
      block.text,
      doc_ctx.page_count,
    ),
    pdf_layout_gate_nearest_image_distance(page.images, block._bbox),
    page_font_median,
  )
}

///|
fn build_pdf_layout_gate_doc_context(
  doc : PdfConvertDocument,
) -> PdfLayoutGateDocContext {
  {
    repeated_counts: build_pdf_layout_gate_repeated_counts(doc),
    page_count: doc.pages.length(),
  }
}

///|
fn build_pdf_layout_gate_repeated_counts(
  doc : PdfConvertDocument,
) -> Map[String, Int] {
  let counts : Map[String, Int] = Map([])
  for page in doc.pages {
    for block in page.blocks {
      let key = normalize_noise_key(block.text)
      if key == "" {
        continue
      }
      let prev = counts.get(key).unwrap_or(0)
      counts.set(key, prev + 1)
    }
  }
  counts
}

///|
fn pdf_layout_gate_repeated_text_score(
  counts : Map[String, Int],
  text : String,
  page_count : Int,
) -> Double {
  let key = normalize_noise_key(text)
  if key == "" || page_count <= 0 {
    return 0.0
  }
  let count = counts.get(key).unwrap_or(0)
  if count <= 1 {
    0.0
  } else {
    count.to_double() / page_count.to_double()
  }
}

///|
fn pdf_layout_gate_nearest_image_distance(
  images : Array[PdfConvertImage],
  block_box : @model.PdfRect,
) -> Double? {
  if images.is_empty() {
    return None
  }

  let mut best : Double? = None
  for image in images {
    let distance = pdf_layout_gate_rect_vertical_distance(
      block_box,
      image._bbox,
    )
    match best {
      Some(cur) => if distance < cur { best = Some(distance) }
      None => best = Some(distance)
    }
  }
  best
}

///|
fn pdf_layout_gate_rect_vertical_distance(
  a : @model.PdfRect,
  b : @model.PdfRect,
) -> Double {
  if a.y1 < b.y0 {
    b.y0 - a.y1
  } else if b.y1 < a.y0 {
    a.y0 - b.y1
  } else {
    0.0
  }
}

///|
fn parse_pdf_layout_gate_env(value : String?) -> Bool {
  match value {
    None => true
    Some(raw) => {
      let normalized = raw.trim().to_lower()
      normalized != "0" &&
      normalized != "false" &&
      normalized != "off" &&
      normalized != "no" &&
      normalized != "disable" &&
      normalized != "disabled"
    }
  }
}

///|
fn make_pdf_layout_gate_decision(
  stage : PdfLayoutGateStage,
  block : PdfConvertBlock,
  rule_label : String,
  suggested_label : String?,
  final_label : String,
  output_kind : String,
  score : Double,
  confidence : Double,
  hard_constraints_applied : Array[String],
  override_allowed : Bool,
  override_reason : String?,
  override_blocked_reason : String?,
  reason_tags : Array[String],
) -> PdfLayoutGateDecision {
  {
    stage,
    target_id: pdf_layout_gate_target_id(block),
    page_index: block._page_index,
    block_index: block.block_index,
    text: block.text,
    rule_label,
    suggested_label,
    final_label,
    output_kind,
    score,
    confidence,
    hard_constraints_applied,
    override_allowed,
    override_reason,
    override_blocked_reason,
    reason_tags,
  }
}

///|
fn pdf_layout_gate_target_id(block : PdfConvertBlock) -> String {
  "p" +
  (block._page_index + 1).to_string() +
  ".b" +
  block.block_index.to_string()
}

///|
fn candidate_score_value(candidate : PdfLayoutGateCandidateScore?) -> Double {
  match candidate {
    Some(c) => c.score
    None => 0.0
  }
}

///|
fn candidate_confidence_value(
  candidate : PdfLayoutGateCandidateScore?,
) -> Double {
  match candidate {
    Some(c) => c.confidence
    None => 0.0
  }
}

///|
fn candidate_label_opt(candidate : PdfLayoutGateCandidateScore?) -> String? {
  match candidate {
    Some(c) => Some(c.label)
    None => None
  }
}

///|
fn top_gate_candidate(
  candidates : Array[PdfLayoutGateCandidateScore],
) -> PdfLayoutGateCandidateScore? {
  if candidates.is_empty() {
    return None
  }

  let mut best = candidates[0]
  for i = 1; i < candidates.length(); i = i + 1 {
    let cur = candidates[i]
    if cur.score > best.score {
      best = cur
    }
  }
  Some(best)
}

///|
fn cap_gate_confidence(score : Double) -> Double {
  if score < 0.0 {
    0.0
  } else if score > 0.99 {
    0.99
  } else {
    score
  }
}

///|
fn collect_gate_reason_tags(
  features : Map[String, Double],
  keys : Array[String],
) -> Array[String] {
  let out : Array[String] = []
  for key in keys {
    match key {
      "repeated_text_score" =>
        if gate_feature_num(features, key) > 0.0 {
          out.push(key)
        }
      "word_count" => if gate_feature_num(features, key) > 0.0 { out.push(key) }
      _ => if gate_feature_bool(features, key) { out.push(key) }
    }
  }
  out
}

///|
fn gate_feature_num(features : Map[String, Double], key : String) -> Double {
  features.get(key).unwrap_or(0.0)
}

///|
fn gate_feature_bool(features : Map[String, Double], key : String) -> Bool {
  gate_feature_num(features, key) >= 0.5
}
