///|
pub struct PdfLayoutGateConfig {
  enabled : Bool
}

///|
pub enum PdfLayoutGateStage {
  HeadingDemotion
  ListSuppression
} derive(Eq)

///|
pub struct PdfLayoutGateDecision {
  stage : PdfLayoutGateStage
  target_id : String
  page_index : Int
  block_index : Int
  text : String
  rule_label : String
  suggested_label : String?
  final_label : String
  output_kind : String
  score : Double
  confidence : Double
  hard_constraints_applied : Array[String]
  override_allowed : Bool
  override_reason : String?
  override_blocked_reason : String?
  reason_tags : Array[String]
}

///|
pub struct PdfLayoutGateSummary {
  enabled : Bool
  heading_candidate_count : Int
  list_candidate_count : Int
  decision_count : Int
  changed_count : Int
  blocked_count : Int
  decisions : Array[PdfLayoutGateDecision]
}

///|
priv struct PdfLayoutGateDocContext {
  repeated_counts : Map[String, Int]
  page_count : Int
}

///|
priv struct PdfLayoutGateCandidateScore {
  label : String
  score : Double
  confidence : Double
  reason : String
  reason_tags : Array[String]
}

///|
const PDF_LAYOUT_GATE_ENV = "MARKITDOWN_PDF_LAYOUT_GATE"

///|
pub fn default_pdf_layout_gate_config() -> PdfLayoutGateConfig {
  { enabled: parse_pdf_layout_gate_env(@sys.get_env_var(PDF_LAYOUT_GATE_ENV)) }
}

///|
pub fn pdf_layout_gate_enabled() -> Bool {
  default_pdf_layout_gate_config().enabled
}

///|
pub fn apply_pdf_layout_gate(
  doc : PdfConvertDocument,
  config? : PdfLayoutGateConfig = default_pdf_layout_gate_config(),
) -> PdfConvertDocument {
  if !config.enabled || doc.pages.is_empty() {
    return doc
  }

  let ctx = build_pdf_layout_gate_doc_context(doc)
  let pages = Array::new()

  for page in doc.pages {
    pages.push(apply_pdf_layout_gate_to_page(ctx, page, config))
  }

  { pages, }
}

///|
pub fn build_pdf_layout_gate_summary(
  classified_doc : PdfConvertDocument,
  merged_doc : PdfConvertDocument,
  config? : PdfLayoutGateConfig = default_pdf_layout_gate_config(),
) -> PdfLayoutGateSummary {
  let decisions : Array[PdfLayoutGateDecision] = []
  let heading_ctx = build_pdf_layout_gate_doc_context(classified_doc)
  let list_ctx = build_pdf_layout_gate_doc_context(merged_doc)
  let mut heading_candidate_count = 0
  let mut list_candidate_count = 0
  let mut changed_count = 0
  let mut blocked_count = 0

  for page in classified_doc.pages {
    let page_font_median = page_median_font_size(page)
    for i = 0; i < page.blocks.length(); i = i + 1 {
      match
        decide_pdf_layout_heading_gate(
          heading_ctx, page, i, page_font_median, config,
        ) {
        Some(decision) => {
          heading_candidate_count += 1
          if decision.final_label != decision.rule_label {
            changed_count += 1
          }
          if !decision.hard_constraints_applied.is_empty() ||
            decision.override_blocked_reason is Some(_) {
            blocked_count += 1
          }
          decisions.push(decision)
        }
        None => ()
      }
    }
  }

  for page in merged_doc.pages {
    let page_font_median = page_median_font_size(page)
    for i = 0; i < page.blocks.length(); i = i + 1 {
      match
        decide_pdf_layout_list_gate(list_ctx, page, i, page_font_median, config) {
        Some(decision) => {
          list_candidate_count += 1
          if decision.final_label != decision.rule_label {
            changed_count += 1
          }
          if !decision.hard_constraints_applied.is_empty() ||
            decision.override_blocked_reason is Some(_) {
            blocked_count += 1
          }
          decisions.push(decision)
        }
        None => ()
      }
    }
  }

  {
    enabled: config.enabled,
    heading_candidate_count,
    list_candidate_count,
    decision_count: decisions.length(),
    changed_count,
    blocked_count,
    decisions,
  }
}

///|
fn decide_pdf_layout_list_gate(
  doc_ctx : PdfLayoutGateDocContext,
  page : PdfConvertPage,
  block_index : Int,
  page_font_median : Double?,
  config : PdfLayoutGateConfig,
) -> PdfLayoutGateDecision? {
  if block_index < 0 || block_index >= page.blocks.length() {
    return None
  }

  let block = page.blocks[block_index]
  if block.kind != PdfConvertBlockKind::Paragraph {
    return None
  }

  let text = block.text.trim().to_owned()
  let item_text = match try_parse_bullet_list_item_for_ir(text) {
    Some(v) => v
    None => return None
  }
  let prev = if block_index > 0 {
    Some(page.blocks[block_index - 1])
  } else {
    None
  }
  let next = if block_index + 1 < page.blocks.length() {
    Some(page.blocks[block_index + 1])
  } else {
    None
  }
  let features = layout_gate_feature_values(
    doc_ctx, page, block, prev, next, page_font_median,
  )
  let constraints = gate_hard_constraints(features, false)
  let strong_support = gate_strong_list_item_support(features, item_text)
  let candidate = select_list_suppression_candidate(features, text, item_text)
  let suggested = candidate_label_opt(candidate)
  let reason_tags = match candidate {
    Some(c) => c.reason_tags
    None => []
  }

  if !config.enabled {
    return Some(
      make_pdf_layout_gate_decision(
        PdfLayoutGateStage::ListSuppression,
        block,
        "list_item",
        suggested,
        "list_item",
        "list_item",
        candidate_score_value(candidate),
        candidate_confidence_value(candidate),
        constraints,
        false,
        None,
        Some("gate_disabled"),
        reason_tags,
      ),
    )
  }

  if !constraints.is_empty() {
    return Some(
      make_pdf_layout_gate_decision(
        PdfLayoutGateStage::ListSuppression,
        block,
        "list_item",
        suggested,
        "list_item",
        "list_item",
        candidate_score_value(candidate),
        candidate_confidence_value(candidate),
        constraints,
        false,
        None,
        Some("hard_constraints"),
        reason_tags,
      ),
    )
  }

  if strong_support {
    return Some(
      make_pdf_layout_gate_decision(
        PdfLayoutGateStage::ListSuppression,
        block,
        "list_item",
        suggested,
        "list_item",
        "list_item",
        candidate_score_value(candidate),
        candidate_confidence_value(candidate),
        constraints,
        false,
        None,
        Some("strong_list_support"),
        reason_tags,
      ),
    )
  }

  match candidate {
    Some(c) =>
      if c.confidence >= 0.80 {
        Some(
          make_pdf_layout_gate_decision(
            PdfLayoutGateStage::ListSuppression,
            block,
            "list_item",
            Some(c.label),
            c.label,
            "paragraph",
            c.score,
            c.confidence,
            constraints,
            true,
            Some(c.reason),
            None,
            c.reason_tags,
          ),
        )
      } else {
        Some(
          make_pdf_layout_gate_decision(
            PdfLayoutGateStage::ListSuppression,
            block,
            "list_item",
            Some(c.label),
            "list_item",
            "list_item",
            c.score,
            c.confidence,
            constraints,
            false,
            None,
            Some("low_confidence"),
            c.reason_tags,
          ),
        )
      }
    None =>
      Some(
        make_pdf_layout_gate_decision(
          PdfLayoutGateStage::ListSuppression,
          block,
          "list_item",
          None,
          "list_item",
          "list_item",
          0.0,
          0.0,
          constraints,
          false,
          None,
          Some("no_low_risk_override"),
          [],
        ),
      )
  }
}

///|
fn should_emit_pdf_bullet_list_item(
  doc_ctx : PdfLayoutGateDocContext,
  page : PdfConvertPage,
  block_index : Int,
  page_font_median : Double?,
  config : PdfLayoutGateConfig,
) -> Bool {
  match
    decide_pdf_layout_list_gate(
      doc_ctx, page, block_index, page_font_median, config,
    ) {
    Some(decision) => decision.output_kind == "list_item"
    None => true
  }
}

///|
fn apply_pdf_layout_gate_to_page(
  doc_ctx : PdfLayoutGateDocContext,
  page : PdfConvertPage,
  config : PdfLayoutGateConfig,
) -> PdfConvertPage {
  let blocks = Array::new()
  let page_font_median = page_median_font_size(page)

  for i = 0; i < page.blocks.length(); i = i + 1 {
    let block = page.blocks[i]
    match
      decide_pdf_layout_heading_gate(doc_ctx, page, i, page_font_median, config) {
      Some(decision) =>
        blocks.push(apply_heading_gate_decision(block, decision))
      None => blocks.push(block)
    }
  }

  rebuild_page_objects({ ..page, blocks, objects: [] })
}

///|
fn decide_pdf_layout_heading_gate(
  doc_ctx : PdfLayoutGateDocContext,
  page : PdfConvertPage,
  block_index : Int,
  page_font_median : Double?,
  config : PdfLayoutGateConfig,
) -> PdfLayoutGateDecision? {
  if block_index < 0 || block_index >= page.blocks.length() {
    return None
  }

  let block = page.blocks[block_index]
  if block.kind != PdfConvertBlockKind::Heading {
    return None
  }

  let prev = if block_index > 0 {
    Some(page.blocks[block_index - 1])
  } else {
    None
  }
  let next = if block_index + 1 < page.blocks.length() {
    Some(page.blocks[block_index + 1])
  } else {
    None
  }
  let features = layout_gate_feature_values(
    doc_ctx, page, block, prev, next, page_font_median,
  )
  let constraints = gate_hard_constraints(features, true)
  let strong_support = gate_strong_heading_support(block, prev, next, features)
  let candidate = select_heading_demotion_candidate(block, next, features)
  let suggested = candidate_label_opt(candidate)
  let reason_tags = match candidate {
    Some(c) => c.reason_tags
    None => []
  }

  if !config.enabled {
    return Some(
      make_pdf_layout_gate_decision(
        PdfLayoutGateStage::HeadingDemotion,
        block,
        "heading",
        suggested,
        "heading",
        "heading",
        candidate_score_value(candidate),
        candidate_confidence_value(candidate),
        constraints,
        false,
        None,
        Some("gate_disabled"),
        reason_tags,
      ),
    )
  }

  if !constraints.is_empty() {
    return Some(
      make_pdf_layout_gate_decision(
        PdfLayoutGateStage::HeadingDemotion,
        block,
        "heading",
        suggested,
        "heading",
        "heading",
        candidate_score_value(candidate),
        candidate_confidence_value(candidate),
        constraints,
        false,
        None,
        Some("hard_constraints"),
        reason_tags,
      ),
    )
  }

  if strong_support {
    return Some(
      make_pdf_layout_gate_decision(
        PdfLayoutGateStage::HeadingDemotion,
        block,
        "heading",
        suggested,
        "heading",
        "heading",
        candidate_score_value(candidate),
        candidate_confidence_value(candidate),
        constraints,
        false,
        None,
        Some("strong_heading_support"),
        reason_tags,
      ),
    )
  }

  match candidate {
    Some(c) =>
      if c.confidence >= 0.82 {
        let final_label = c.label
        let output_kind = if final_label == "footer_header_noise" {
          "noise"
        } else {
          "paragraph"
        }
        Some(
          make_pdf_layout_gate_decision(
            PdfLayoutGateStage::HeadingDemotion,
            block,
            "heading",
            Some(c.label),
            final_label,
            output_kind,
            c.score,
            c.confidence,
            constraints,
            true,
            Some(c.reason),
            None,
            c.reason_tags,
          ),
        )
      } else {
        Some(
          make_pdf_layout_gate_decision(
            PdfLayoutGateStage::HeadingDemotion,
            block,
            "heading",
            Some(c.label),
            "heading",
            "heading",
            c.score,
            c.confidence,
            constraints,
            false,
            None,
            Some("low_confidence"),
            c.reason_tags,
          ),
        )
      }
    None =>
      Some(
        make_pdf_layout_gate_decision(
          PdfLayoutGateStage::HeadingDemotion,
          block,
          "heading",
          None,
          "heading",
          "heading",
          0.0,
          0.0,
          constraints,
          false,
          None,
          Some("no_low_risk_override"),
          [],
        ),
      )
  }
}

///|
fn apply_heading_gate_decision(
  block : PdfConvertBlock,
  decision : PdfLayoutGateDecision,
) -> PdfConvertBlock {
  if !decision.override_allowed {
    return block
  }

  match decision.output_kind {
    "noise" => copy_block_with_kind(block, PdfConvertBlockKind::Noise)
    "paragraph" => copy_block_with_kind(block, PdfConvertBlockKind::Paragraph)
    _ => block
  }
}

///|
fn select_heading_demotion_candidate(
  block : PdfConvertBlock,
  next : PdfConvertBlock?,
  features : Map[String, Double],
) -> PdfLayoutGateCandidateScore? {
  let candidates : Array[PdfLayoutGateCandidateScore] = []

  if gate_footer_noise_evidence(features) {
    let mut score = 0.86
    let reasons : Array[String] = [
      "repeated_edge_candidate", "repeated_text_score", "page_label_pattern_signal",
      "is_page_number_candidate", "is_header_footer_candidate", "is_artifact_candidate",
      "top_zone_candidate", "bottom_zone_candidate",
    ]
    if gate_feature_bool(features, "repeated_edge_candidate") {
      score += 0.08
    }
    if gate_feature_num(features, "repeated_text_score") >= 0.90 {
      score += 0.04
    }
    if gate_feature_bool(features, "page_label_pattern_signal") {
      score += 0.04
    }
    if gate_feature_bool(features, "is_page_number_candidate") ||
      gate_feature_bool(features, "is_header_footer_candidate") {
      score += 0.04
    }
    candidates.push({
      label: "footer_header_noise",
      score,
      confidence: cap_gate_confidence(score),
      reason: "weak_heading_repeated_edge_noise",
      reason_tags: collect_gate_reason_tags(features, reasons),
    })
  }

  if gate_receipt_form_evidence(features) {
    let mut score = 0.86
    let reasons : Array[String] = [
      "receipt_line_item_signal", "payment_card_signal", "quantity_price_signal",
      "contains_currency", "contains_time", "contains_date",
    ]
    if gate_feature_bool(features, "payment_card_signal") {
      score += 0.08
    } else if gate_feature_bool(features, "receipt_line_item_signal") {
      score += 0.06
    } else if gate_feature_bool(features, "quantity_price_signal") {
      score += 0.04
    }
    candidates.push({
      label: "form_row",
      score,
      confidence: cap_gate_confidence(score),
      reason: "weak_heading_receipt_form_row",
      reason_tags: collect_gate_reason_tags(features, reasons),
    })
  }

  if gate_technical_keep_as_text_evidence(features) {
    let mut score = 0.84
    let reasons : Array[String] = [
      "technical_literal_signal", "identifier_like_signal", "contains_path_like",
      "code_like_signal", "option_like_signal", "monospace_hint",
    ]
    if gate_feature_bool(features, "identifier_like_signal") ||
      gate_feature_bool(features, "contains_path_like") {
      score += 0.08
    } else if gate_feature_bool(features, "option_like_signal") ||
      gate_feature_bool(features, "code_like_signal") {
      score += 0.06
    }
    candidates.push({
      label: "keep_as_text",
      score,
      confidence: cap_gate_confidence(score),
      reason: "weak_heading_technical_literal",
      reason_tags: collect_gate_reason_tags(features, reasons),
    })
  }

  if gate_heading_separator_or_sentence_evidence(block, next, features) {
    let mut score = 0.82
    let reasons : Array[String] = [
      "looks_like_separator", "looks_like_bullet", "looks_like_list_marker_token",
      "sentence_like_signal", "figure_reference_sentence_signal", "section_reference_sentence_signal",
      "citation_reference_signal", "technical_sentence_guard_signal", "has_terminal_period",
      "contains_clause_punctuation", "word_count",
    ]
    if gate_feature_bool(features, "looks_like_separator") ||
      gate_feature_bool(features, "looks_like_bullet") {
      score += 0.06
    }
    if gate_feature_bool(features, "sentence_like_signal") ||
      gate_feature_bool(features, "figure_reference_sentence_signal") ||
      gate_feature_bool(features, "section_reference_sentence_signal") {
      score += 0.04
    }
    candidates.push({
      label: "paragraph",
      score,
      confidence: cap_gate_confidence(score),
      reason: "weak_heading_sentence_or_separator",
      reason_tags: collect_gate_reason_tags(features, reasons),
    })
  }

  top_gate_candidate(candidates)
}

///|
fn select_list_suppression_candidate(
  features : Map[String, Double],
  text : String,
  item_text : String,
) -> PdfLayoutGateCandidateScore? {
  let candidates : Array[PdfLayoutGateCandidateScore] = []

  if gate_feature_bool(features, "looks_like_separator") ||
    looks_like_separator_line_for_ir(item_text) {
    candidates.push({
      label: "separator",
      score: 0.96,
      confidence: 0.96,
      reason: "separator_not_list_item",
      reason_tags: collect_gate_reason_tags(features, [
        "looks_like_separator", "looks_like_bullet", "looks_like_list_marker_token",
      ]),
    })
  }

  if gate_technical_keep_as_text_evidence(features) &&
    !gate_feature_bool(features, "sentence_like_signal") {
    let mut score = 0.86
    if gate_feature_bool(features, "option_like_signal") ||
      gate_feature_bool(features, "code_like_signal") {
      score += 0.04
    }
    candidates.push({
      label: "keep_as_text",
      score,
      confidence: cap_gate_confidence(score),
      reason: "technical_bullet_should_stay_text",
      reason_tags: collect_gate_reason_tags(features, [
        "technical_literal_signal", "identifier_like_signal", "contains_path_like",
        "code_like_signal", "option_like_signal", "monospace_hint",
      ]),
    })
  }

  if standalone_bullet_text_signal(text, item_text, features) {
    candidates.push({
      label: "paragraph",
      score: 0.82,
      confidence: 0.82,
      reason: "weak_bullet_without_natural_language",
      reason_tags: collect_gate_reason_tags(features, [
        "looks_like_bullet", "looks_like_list_marker_token", "word_count",
      ]),
    })
  }

  top_gate_candidate(candidates)
}

///|
fn gate_strong_heading_support(
  block : PdfConvertBlock,
  prev : PdfConvertBlock?,
  next : PdfConvertBlock?,
  features : Map[String, Double],
) -> Bool {
  if gate_technical_keep_as_text_evidence(features) ||
    gate_receipt_form_evidence(features) ||
    gate_footer_noise_evidence(features) {
    return false
  }

  let text = normalize_pdf_comparison_text(block.text)
  let heading_shape = looks_like_section_heading(text) ||
    looks_like_short_english_heading(text) ||
    looks_like_short_cjk_heading(text)
  let relative_font = gate_feature_num(features, "relative_font_size")
  let font_delta = gate_feature_num(features, "prev_font_size_delta") >= 0.5 ||
    gate_feature_num(features, "next_font_size_delta") >= 0.5 ||
    is_visually_larger_than_neighbors(prev, block, next)
  let gap_support = has_heading_like_gap_before(block)
  let next_support = next_block_looks_like_body(next) ||
    next_block_looks_like_list_item(next)

  if gate_feature_bool(features, "cleanup_shell_signal") {
    return true
  }

  if heading_shape && (gap_support || font_delta || next_support) {
    return true
  }

  gate_feature_bool(features, "is_heading_candidate") &&
  relative_font >= 1.12 &&
  (gap_support || font_delta || next_support)
}

///|
fn gate_strong_list_item_support(
  features : Map[String, Double],
  item_text : String,
) -> Bool {
  if gate_feature_bool(features, "looks_like_separator") {
    return false
  }
  if gate_technical_keep_as_text_evidence(features) {
    return false
  }
  if gate_feature_bool(features, "receipt_line_item_signal") ||
    gate_feature_bool(features, "payment_card_signal") {
    return false
  }

  let word_count = count_feature_words(item_text)
  if word_count >= 5 {
    return true
  }

  word_count >= 3 &&
  (
    gate_feature_bool(features, "sentence_like_signal") ||
    gate_feature_bool(features, "has_terminal_period") ||
    gate_feature_bool(features, "contains_clause_punctuation")
  )
}

///|
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
