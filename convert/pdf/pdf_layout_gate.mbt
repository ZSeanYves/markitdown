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
  let strong_support = gate_strong_list_item_support(
    prev, next, features, item_text,
  )
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
  let candidate = select_heading_demotion_candidate(block, prev, next, features)
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
  prev : PdfConvertBlock?,
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

  if gate_receipt_settlement_heading_evidence(block, prev, next, features) {
    let score = 0.90
    let reasons : Array[String] = [
      "contains_currency", "word_count", "relative_font_size",
    ]
    candidates.push({
      label: "paragraph",
      score,
      confidence: cap_gate_confidence(score),
      reason: "weak_heading_receipt_settlement_line",
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
    gate_footer_noise_evidence(features) ||
    gate_receipt_settlement_heading_evidence(block, prev, next, features) {
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
  prev : PdfConvertBlock?,
  next : PdfConvertBlock?,
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
  let contextual_support = gate_neighboring_list_context(prev, next)
  if contextual_support && word_count >= 2 {
    return true
  }

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
fn gate_neighboring_list_context(
  prev : PdfConvertBlock?,
  next : PdfConvertBlock?,
) -> Bool {
  let prev_list_item = match prev {
    Some(block) =>
      looks_like_bullet_item(block.text) ||
      looks_like_numbered_body_sentence(block.text)
    None => false
  }
  let prev_list_lead_in = match prev {
    Some(block) =>
      looks_like_colon_label(normalize_pdf_comparison_text(block.text))
    None => false
  }

  prev_list_item || prev_list_lead_in || next_block_looks_like_list_item(next)
}
