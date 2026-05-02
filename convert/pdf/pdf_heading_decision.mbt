///|
priv enum PdfHeadingDecisionStatus {
  PromoteHeading
  KeepHeading
  DemoteToParagraph
  ToNoise
  KeepParagraph
  KeepNoise
}

///|
priv struct PdfHeadingEvidence {
  empty_text : Bool
  max_heading_disabled : Bool
  short_line : Bool
  isolated_line : Bool
  page_lead : Bool
  core_candidate : Bool
  chapter_prefix : Bool
  numbering_prefix : Bool
  english_section_word : Bool
  short_english_heading : Bool
  short_cjk_heading : Bool
  gap_before : Bool
  font_size_delta : Bool
  next_body : Bool
  next_list : Bool
  layout_candidate : Bool
  single_token_too_short : Bool
  noise_guard : Bool
  bullet_guard : Bool
  list_item_guard : Bool
  colon_guard : Bool
  side_marker_guard : Bool
  intro_phrase_guard : Bool
  caption_guard : Bool
  noise_tail_guard : Bool
  numbered_body_guard : Bool
  sentence_like_guard : Bool
  punctuation_guard : Bool
  too_long_guard : Bool
  prev_heading_guard : Bool
}

///|
priv struct PdfHeadingDecision {
  status : PdfHeadingDecisionStatus
  reason_tags : Array[String]
}

///|
fn decide_heading_classification(
  prev : PdfConvertBlock?,
  block : PdfConvertBlock,
  next : PdfConvertBlock?,
  max_heading : Int,
) -> PdfHeadingDecision {
  let text = block.text.trim().to_owned()
  let evidence = collect_heading_evidence(prev, block, next, text, max_heading)

  match block.kind {
    PdfConvertBlockKind::Noise =>
      {
        status: PdfHeadingDecisionStatus::KeepNoise,
        reason_tags: guard_reason_tags(evidence),
      }
    PdfConvertBlockKind::Paragraph =>
      if evidence.noise_guard {
        {
          status: PdfHeadingDecisionStatus::ToNoise,
          reason_tags: guard_reason_tags(evidence),
        }
      } else {
        match paragraph_promotion_reason_tags(evidence) {
          Some(reason_tags) =>
            { status: PdfHeadingDecisionStatus::PromoteHeading, reason_tags }
          None =>
            {
              status: PdfHeadingDecisionStatus::KeepParagraph,
              reason_tags: paragraph_reason_tags(evidence),
            }
        }
      }
    PdfConvertBlockKind::Heading =>
      if evidence.noise_guard {
        {
          status: PdfHeadingDecisionStatus::ToNoise,
          reason_tags: guard_reason_tags(evidence),
        }
      } else {
        match heading_keep_reason_tags_from_evidence(evidence) {
          Some(reason_tags) =>
            { status: PdfHeadingDecisionStatus::KeepHeading, reason_tags }
          None =>
            {
              status: PdfHeadingDecisionStatus::DemoteToParagraph,
              reason_tags: demotion_reason_tags(evidence),
            }
        }
      }
  }
}

///|
fn collect_heading_evidence(
  prev : PdfConvertBlock?,
  block : PdfConvertBlock,
  next : PdfConvertBlock?,
  text : String,
  max_heading : Int,
) -> PdfHeadingEvidence {
  let t = text.trim().to_owned()
  let font_size_delta = is_visually_larger_than_neighbors(prev, block, next)
  let colon_guard = looks_like_colon_label(t)
  let bullet_guard = looks_like_bullet_item(t)
  let list_item_guard = looks_like_list_item_sentence(t)
  let side_marker_guard = looks_like_side_marker_label_line(t)
  let intro_phrase_guard = @text.looks_like_intro_phrase(t)
  let caption_guard = @text.looks_like_figure_or_table_caption(t)
  let noise_guard = should_be_noise(t)
  let numbered_body_guard = looks_like_numbered_body_sentence(t)
  let sentence_like_guard = is_obvious_body_sentence(t)
  let punctuation_guard = ends_with_strong_sentence_punct(t)
  let too_long_guard = is_too_long_for_heading(t)
  let next_body = next_block_looks_like_body(next)
  let next_list = next_block_looks_like_list_item(next)
  let gap_before = has_heading_like_gap_before(block)
  let prev_heading_guard = match prev {
    Some(p) =>
      p.kind == PdfConvertBlockKind::Heading && (colon_guard || bullet_guard)
    None => false
  }

  {
    empty_text: t == "",
    max_heading_disabled: max_heading <= 0,
    short_line: t.length() <= 40,
    isolated_line: block.line_count == 1,
    page_lead: block._page_index == 0 && block.block_index <= 2,
    core_candidate: block.is_heading_candidate,
    chapter_prefix: t.has_prefix("第"),
    numbering_prefix: starts_with_digit_section(t),
    english_section_word: starts_with_english_section_word(t),
    short_english_heading: looks_like_short_english_heading(t),
    short_cjk_heading: looks_like_short_cjk_heading(t),
    gap_before,
    font_size_delta,
    next_body,
    next_list,
    layout_candidate: looks_like_layout_heading_candidate(prev, block, next, t),
    single_token_too_short: @text.word_count(t) <= 1 &&
    t.length() <= 3 &&
    !font_size_delta,
    noise_guard,
    bullet_guard,
    list_item_guard,
    colon_guard,
    side_marker_guard,
    intro_phrase_guard,
    caption_guard,
    noise_tail_guard: ends_with_noise_tail(t),
    numbered_body_guard,
    sentence_like_guard,
    punctuation_guard,
    too_long_guard,
    prev_heading_guard,
  }
}

///|
fn has_heading_like_gap_before(block : PdfConvertBlock) -> Bool {
  match (block.first_line_gap_before, block.first_line_height) {
    (Some(gap), Some(height)) => gap >= 6.0 && gap >= height * 0.50
    (Some(gap), None) => gap >= 8.0
    _ => false
  }
}

///|
fn has_blocking_heading_guard(evidence : PdfHeadingEvidence) -> Bool {
  evidence.empty_text ||
  evidence.max_heading_disabled ||
  evidence.noise_guard ||
  evidence.single_token_too_short ||
  evidence.bullet_guard ||
  evidence.list_item_guard ||
  evidence.colon_guard ||
  evidence.side_marker_guard ||
  evidence.intro_phrase_guard ||
  evidence.caption_guard ||
  evidence.noise_tail_guard ||
  evidence.numbered_body_guard ||
  evidence.sentence_like_guard ||
  evidence.punctuation_guard ||
  evidence.too_long_guard ||
  evidence.prev_heading_guard
}

///|
fn has_structured_heading_shape(evidence : PdfHeadingEvidence) -> Bool {
  evidence.chapter_prefix ||
  evidence.numbering_prefix ||
  evidence.english_section_word
}

///|
fn has_compact_heading_shape(evidence : PdfHeadingEvidence) -> Bool {
  evidence.short_english_heading || evidence.short_cjk_heading
}

///|
fn has_any_heading_shape(evidence : PdfHeadingEvidence) -> Bool {
  has_structured_heading_shape(evidence) || has_compact_heading_shape(evidence)
}

///|
fn has_contextual_heading_support(evidence : PdfHeadingEvidence) -> Bool {
  evidence.gap_before ||
  evidence.next_body ||
  evidence.next_list ||
  evidence.font_size_delta ||
  evidence.layout_candidate
}

///|
fn paragraph_promotion_reason_tags(
  evidence : PdfHeadingEvidence,
) -> Array[String]? {
  if has_blocking_heading_guard(evidence) {
    return None
  }

  match strong_structured_heading_reason_tags(evidence) {
    Some(tags) => return Some(tags)
    None => ()
  }

  match core_supported_heading_reason_tags(evidence) {
    Some(tags) => return Some(tags)
    None => ()
  }

  match font_context_heading_reason_tags(evidence) {
    Some(tags) => return Some(tags)
    None => ()
  }

  page_lead_heading_reason_tags(evidence)
}

///|
fn heading_keep_reason_tags_from_evidence(
  evidence : PdfHeadingEvidence,
) -> Array[String]? {
  if has_blocking_heading_guard(evidence) {
    return None
  }

  match paragraph_promotion_reason_tags(evidence) {
    Some(tags) => return Some(tags)
    None => ()
  }

  if evidence.core_candidate &&
    evidence.short_line &&
    evidence.isolated_line &&
    (
      has_any_heading_shape(evidence) ||
      has_contextual_heading_support(evidence)
    ) {
    return Some(
      make_heading_reason_tags(evidence, [
        "core_candidate", "short_line", "isolated_line", "gap_before", "font_size_delta",
        "next_body", "next_list", "layout_candidate", "page_lead", "chapter_prefix",
        "numbering_prefix", "english_section_word", "short_english", "short_cjk",
      ]),
    )
  }

  None
}

///|
fn strong_structured_heading_reason_tags(
  evidence : PdfHeadingEvidence,
) -> Array[String]? {
  if !evidence.short_line || !evidence.isolated_line {
    return None
  }

  if !has_structured_heading_shape(evidence) {
    return None
  }

  if !has_contextual_heading_support(evidence) {
    return None
  }

  Some(
    make_heading_reason_tags(evidence, [
      "chapter_prefix", "numbering_prefix", "english_section_word", "short_line",
      "isolated_line", "gap_before", "font_size_delta", "next_body", "next_list",
      "layout_candidate", "page_lead",
    ]),
  )
}

///|
fn core_supported_heading_reason_tags(
  evidence : PdfHeadingEvidence,
) -> Array[String]? {
  if !evidence.core_candidate || !evidence.short_line || !evidence.isolated_line {
    return None
  }

  if !(has_any_heading_shape(evidence) ||
    has_contextual_heading_support(evidence)) {
    return None
  }

  Some(
    make_heading_reason_tags(evidence, [
      "core_candidate", "short_line", "isolated_line", "chapter_prefix", "numbering_prefix",
      "english_section_word", "short_english", "short_cjk", "gap_before", "font_size_delta",
      "next_body", "next_list", "layout_candidate", "page_lead",
    ]),
  )
}

///|
fn font_context_heading_reason_tags(
  evidence : PdfHeadingEvidence,
) -> Array[String]? {
  if !evidence.font_size_delta || !evidence.next_body {
    return None
  }

  if !evidence.short_line || !evidence.isolated_line {
    return None
  }

  if !(has_compact_heading_shape(evidence) || evidence.layout_candidate) {
    return None
  }

  Some(
    make_heading_reason_tags(evidence, [
      "font_size_delta", "next_body", "short_line", "isolated_line", "short_english",
      "short_cjk", "layout_candidate", "gap_before", "page_lead",
    ]),
  )
}

///|
fn page_lead_heading_reason_tags(
  evidence : PdfHeadingEvidence,
) -> Array[String]? {
  if !evidence.page_lead || !evidence.short_line || !evidence.isolated_line {
    return None
  }

  if !has_any_heading_shape(evidence) {
    return None
  }

  if !(evidence.gap_before ||
    evidence.font_size_delta ||
    evidence.core_candidate) {
    return None
  }

  Some(
    make_heading_reason_tags(evidence, [
      "page_lead", "short_line", "isolated_line", "chapter_prefix", "numbering_prefix",
      "english_section_word", "short_english", "short_cjk", "gap_before", "font_size_delta",
      "core_candidate",
    ]),
  )
}

///|
fn make_heading_reason_tags(
  evidence : PdfHeadingEvidence,
  candidates : Array[String],
) -> Array[String] {
  let out : Array[String] = []

  for tag in candidates {
    if heading_reason_tag_matches(evidence, tag) {
      out.push(tag)
    }
  }

  out
}

///|
fn heading_reason_tag_matches(
  evidence : PdfHeadingEvidence,
  tag : String,
) -> Bool {
  match tag {
    "core_candidate" => evidence.core_candidate
    "chapter_prefix" => evidence.chapter_prefix
    "numbering_prefix" => evidence.numbering_prefix
    "english_section_word" => evidence.english_section_word
    "short_english" => evidence.short_english_heading
    "short_cjk" => evidence.short_cjk_heading
    "short_line" => evidence.short_line
    "isolated_line" => evidence.isolated_line
    "gap_before" => evidence.gap_before
    "font_size_delta" => evidence.font_size_delta
    "next_body" => evidence.next_body
    "next_list" => evidence.next_list
    "layout_candidate" => evidence.layout_candidate
    "page_lead" => evidence.page_lead
    _ => false
  }
}

///|
fn paragraph_reason_tags(evidence : PdfHeadingEvidence) -> Array[String] {
  let out = guard_reason_tags(evidence)
  if out.is_empty() {
    if has_any_heading_shape(evidence) ||
      evidence.short_line ||
      evidence.isolated_line ||
      evidence.page_lead ||
      evidence.font_size_delta ||
      evidence.gap_before ||
      evidence.next_body ||
      evidence.next_list ||
      evidence.layout_candidate {
      out.push("insufficient_heading_context")
    } else {
      out.push("no_heading_evidence")
    }
  }
  out
}

///|
fn demotion_reason_tags(evidence : PdfHeadingEvidence) -> Array[String] {
  let out = guard_reason_tags(evidence)
  if out.is_empty() {
    if has_any_heading_shape(evidence) ||
      evidence.core_candidate ||
      evidence.font_size_delta ||
      evidence.layout_candidate ||
      evidence.page_lead {
      out.push("insufficient_heading_context")
    } else if evidence.next_body {
      out.push("next_body_guard")
    } else {
      out.push("demote_unconfirmed_heading")
    }
  }
  out
}

///|
fn guard_reason_tags(evidence : PdfHeadingEvidence) -> Array[String] {
  let out : Array[String] = []

  if evidence.empty_text {
    out.push("empty_text")
  }
  if evidence.max_heading_disabled {
    out.push("max_heading_disabled")
  }
  if evidence.noise_guard {
    out.push("noise_guard")
  }
  if evidence.single_token_too_short {
    out.push("single_token_too_short")
  }
  if evidence.bullet_guard {
    out.push("bullet_guard")
  }
  if evidence.list_item_guard {
    out.push("list_item_guard")
  }
  if evidence.colon_guard {
    out.push("colon_guard")
  }
  if evidence.side_marker_guard {
    out.push("side_marker_guard")
  }
  if evidence.intro_phrase_guard {
    out.push("intro_phrase_guard")
  }
  if evidence.caption_guard {
    out.push("caption_guard")
  }
  if evidence.noise_tail_guard {
    out.push("noise_tail_guard")
  }
  if evidence.numbered_body_guard {
    out.push("numbered_body_guard")
  }
  if evidence.sentence_like_guard {
    out.push("sentence_like")
  }
  if evidence.punctuation_guard {
    out.push("punctuation_guard")
  }
  if evidence.too_long_guard {
    out.push("too_long")
  }
  if evidence.prev_heading_guard {
    out.push("prev_heading_guard")
  }

  out
}

///|
fn heading_decision_status_str(status : PdfHeadingDecisionStatus) -> String {
  match status {
    PdfHeadingDecisionStatus::PromoteHeading => "promote"
    PdfHeadingDecisionStatus::KeepHeading => "keep_heading"
    PdfHeadingDecisionStatus::DemoteToParagraph => "demote"
    PdfHeadingDecisionStatus::ToNoise => "noise"
    PdfHeadingDecisionStatus::KeepParagraph => "keep_paragraph"
    PdfHeadingDecisionStatus::KeepNoise => "keep_noise"
  }
}

///|
fn render_heading_reason_tags(reason_tags : Array[String]) -> String {
  if reason_tags.is_empty() {
    "none"
  } else {
    reason_tags.join("+")
  }
}

///|
fn render_pdf_heading_decision(
  page_index : Int,
  block_index : Int,
  decision : PdfHeadingDecision,
  text : String,
) -> String {
  "[pdf-heading] page=" +
  page_index.to_string() +
  " block=" +
  block_index.to_string() +
  " status=" +
  heading_decision_status_str(decision.status) +
  " reason=" +
  render_heading_reason_tags(decision.reason_tags) +
  " text=\"" +
  text +
  "\""
}
