///|
fn heading_rect(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> @model.PdfRect {
  { x0, y0, x1, y1 }
}

///|
fn make_test_block(
  block_index : Int,
  kind : PdfConvertBlockKind,
  text : String,
  font_size : Double?,
  top_y : Double,
  line_gap_before : Double?,
) -> PdfConvertBlock {
  let bbox = heading_rect(40.0, top_y - 12.0, 220.0, top_y)
  {
    _page_index: 0,
    block_index,
    kind,
    text,
    rich_inlines: None,
    line_start: block_index,
    line_end: block_index,
    source_block_index: block_index,
    source_block_line_count: 1,
    source_block_kind: @model.PdfTextBlockKind::Text,
    source_block_bbox: bbox,
    source_block_dominant_font_size: font_size,
    source_block_dominant_font_name: Some("Test"),
    is_heading_candidate: false,
    is_noise_candidate: false,
    is_header_footer_candidate: false,
    is_artifact_candidate: false,
    is_caption_candidate: false,
    is_table_cell_candidate: false,
    dominant_language: None,
    writing_direction: @model.PdfWritingDirection::LeftToRight,
    _bbox: bbox,
    dominant_font_size: font_size,
    dominant_font_name: Some("Test"),
    top_y,
    left_x: 40.0,
    line_count: 1,
    first_indent_left: Some(40.0),
    last_indent_left: Some(40.0),
    first_indent_right: None,
    last_indent_right: None,
    first_alignment_hint: Some("left"),
    last_alignment_hint: Some("left"),
    first_line_gap_before: line_gap_before,
    last_line_gap_after: Some(6.0),
    first_line_height: Some(12.0),
    last_line_height: Some(12.0),
    first_baseline_y: None,
    last_baseline_y: None,
    first_is_wrapped_candidate: false,
    last_is_wrapped_candidate: false,
    first_is_same_paragraph_with_prev_candidate: false,
    last_is_same_paragraph_with_prev_candidate: false,
  }
}

///|
fn block_with_core_candidate(block : PdfConvertBlock) -> PdfConvertBlock {
  { ..block, is_heading_candidate: true }
}

///|
test "pdf heading decision promotes chapter heading with attribution" {
  let block = make_test_block(
    0,
    PdfConvertBlockKind::Paragraph,
    "第一章 项目概述",
    Some(16.0),
    760.0,
    Some(14.0),
  )
  let next = make_test_block(
    1,
    PdfConvertBlockKind::Paragraph,
    "这是正文第一段",
    Some(12.0),
    730.0,
    Some(4.0),
  )

  let decision = decide_heading_classification(None, block, Some(next), 6)
  match decision.status {
    PdfHeadingDecisionStatus::PromoteHeading => ()
    _ => fail("expected PromoteHeading decision")
  }
  if !decision.reason_tags.contains("chapter_prefix") {
    fail("expected chapter_prefix reason")
  }
  if !decision.reason_tags.contains("short_line") {
    fail("expected short_line reason")
  }
  if !decision.reason_tags.contains("gap_before") {
    fail("expected gap_before reason")
  }
}

///|
test "pdf heading decision demotes short sentence with punctuation guard" {
  let block = make_test_block(
    0,
    PdfConvertBlockKind::Heading,
    "This is a short sentence.",
    Some(12.0),
    760.0,
    Some(4.0),
  )
  let next = make_test_block(
    1,
    PdfConvertBlockKind::Paragraph,
    "Body paragraph follows here.",
    Some(12.0),
    736.0,
    Some(4.0),
  )

  let decision = decide_heading_classification(None, block, Some(next), 6)
  match decision.status {
    PdfHeadingDecisionStatus::DemoteToParagraph => ()
    _ => fail("expected DemoteToParagraph decision")
  }
  if !decision.reason_tags.contains("sentence_like") {
    fail("expected sentence_like reason")
  }
  if !decision.reason_tags.contains("punctuation_guard") {
    fail("expected punctuation_guard reason")
  }
}

///|
test "pdf heading decision supports numbered section headings" {
  let block = make_test_block(
    0,
    PdfConvertBlockKind::Paragraph,
    "1.2 Evaluation Setup",
    Some(15.0),
    760.0,
    Some(12.0),
  )
  let next = make_test_block(
    1,
    PdfConvertBlockKind::Paragraph,
    "We evaluate the system on held-out data",
    Some(12.0),
    734.0,
    Some(4.0),
  )

  let decision = decide_heading_classification(None, block, Some(next), 6)
  match decision.status {
    PdfHeadingDecisionStatus::PromoteHeading => ()
    _ => fail("expected PromoteHeading decision")
  }
  if !decision.reason_tags.contains("numbering_prefix") {
    fail("expected numbering_prefix reason")
  }
  if !decision.reason_tags.contains("isolated_line") {
    fail("expected isolated_line reason")
  }
}

///|
test "pdf heading decision keeps short non-heading sentence as paragraph" {
  let block = make_test_block(
    0,
    PdfConvertBlockKind::Paragraph,
    "This is short.",
    Some(12.0),
    760.0,
    Some(4.0),
  )
  let next = make_test_block(
    1,
    PdfConvertBlockKind::Paragraph,
    "Body paragraph follows here.",
    Some(12.0),
    736.0,
    Some(4.0),
  )

  let decision = decide_heading_classification(None, block, Some(next), 6)
  match decision.status {
    PdfHeadingDecisionStatus::KeepParagraph => ()
    _ => fail("expected KeepParagraph decision")
  }
  if !decision.reason_tags.contains("sentence_like") {
    fail("expected sentence_like reason")
  }
  if decision.reason_tags.contains("short_line") {
    fail("short_line alone should not drive promotion")
  }
}

///|
test "pdf heading decision preserves core candidate with strong context" {
  let block = block_with_core_candidate(
    make_test_block(
      0,
      PdfConvertBlockKind::Heading,
      "Introduction",
      Some(15.0),
      760.0,
      Some(10.0),
    ),
  )
  let next = make_test_block(
    1,
    PdfConvertBlockKind::Paragraph,
    "This section introduces the background.",
    Some(12.0),
    734.0,
    Some(4.0),
  )

  let decision = decide_heading_classification(None, block, Some(next), 6)
  match decision.status {
    PdfHeadingDecisionStatus::KeepHeading => ()
    _ => fail("expected KeepHeading decision")
  }
  if !decision.reason_tags.contains("core_candidate") {
    fail("expected core_candidate reason")
  }
}

///|
test "pdf heading decision promotes font-sized heading only with context" {
  let block = make_test_block(
    0,
    PdfConvertBlockKind::Paragraph,
    "System Overview",
    Some(16.0),
    760.0,
    Some(10.0),
  )
  let next = make_test_block(
    1,
    PdfConvertBlockKind::Paragraph,
    "This section explains the system architecture.",
    Some(12.0),
    734.0,
    Some(4.0),
  )

  let decision = decide_heading_classification(None, block, Some(next), 6)
  match decision.status {
    PdfHeadingDecisionStatus::PromoteHeading => ()
    _ => fail("expected PromoteHeading decision")
  }
  if !decision.reason_tags.contains("font_size_delta") {
    fail("expected font_size_delta reason")
  }
  if !decision.reason_tags.contains("next_body") {
    fail("expected next_body reason")
  }
}

///|
test "pdf heading decision does not promote short line alone" {
  let block = make_test_block(
    0,
    PdfConvertBlockKind::Paragraph,
    "Overview",
    Some(12.0),
    760.0,
    Some(4.0),
  )
  let next = make_test_block(
    1,
    PdfConvertBlockKind::Paragraph,
    "Summary bullets follow",
    Some(12.0),
    736.0,
    Some(4.0),
  )

  let decision = decide_heading_classification(None, block, Some(next), 6)
  match decision.status {
    PdfHeadingDecisionStatus::KeepParagraph => ()
    _ => fail("expected KeepParagraph decision")
  }
  if !decision.reason_tags.contains("insufficient_heading_context") {
    fail("expected insufficient_heading_context reason")
  }
}

///|
test "pdf heading decision does not promote page lead alone" {
  let block = make_test_block(
    1,
    PdfConvertBlockKind::Paragraph,
    "Overview",
    Some(12.0),
    740.0,
    Some(4.0),
  )
  let next = make_test_block(
    2,
    PdfConvertBlockKind::Paragraph,
    "Body paragraph starts here.",
    Some(12.0),
    716.0,
    Some(4.0),
  )

  let decision = decide_heading_classification(None, block, Some(next), 6)
  match decision.status {
    PdfHeadingDecisionStatus::KeepParagraph => ()
    _ => fail("expected KeepParagraph decision")
  }
  if !decision.reason_tags.contains("insufficient_heading_context") {
    fail("expected insufficient_heading_context reason")
  }
}

///|
test "pdf heading decision keeps noise guard stronger than heading-like shape" {
  let block = {
    ..make_test_block(
      0,
      PdfConvertBlockKind::Paragraph,
      "Page 2",
      Some(16.0),
      760.0,
      Some(10.0),
    ),
    is_heading_candidate: true,
  }
  let next = make_test_block(
    1,
    PdfConvertBlockKind::Paragraph,
    "Body paragraph starts here.",
    Some(12.0),
    736.0,
    Some(4.0),
  )

  let decision = decide_heading_classification(None, block, Some(next), 6)
  match decision.status {
    PdfHeadingDecisionStatus::ToNoise => ()
    _ => fail("expected ToNoise decision")
  }
  if !decision.reason_tags.contains("noise_guard") {
    fail("expected noise_guard reason")
  }
}

///|
test "pdf heading decision keeps caption guard stronger than short-line evidence" {
  let block = make_test_block(
    0,
    PdfConvertBlockKind::Paragraph,
    "Figure 1. System Overview",
    Some(16.0),
    760.0,
    Some(12.0),
  )
  let next = make_test_block(
    1,
    PdfConvertBlockKind::Paragraph,
    "Body paragraph starts here.",
    Some(12.0),
    734.0,
    Some(4.0),
  )

  let decision = decide_heading_classification(None, block, Some(next), 6)
  match decision.status {
    PdfHeadingDecisionStatus::KeepParagraph => ()
    _ => fail("expected KeepParagraph decision")
  }
  if !decision.reason_tags.contains("caption_guard") {
    fail("expected caption_guard reason")
  }
}

///|
test "pdf heading decision uses prev heading guard on colon label" {
  let prev = make_test_block(
    0,
    PdfConvertBlockKind::Heading,
    "Introduction",
    Some(16.0),
    760.0,
    Some(10.0),
  )
  let block = make_test_block(
    1,
    PdfConvertBlockKind::Paragraph,
    "Key points:",
    Some(16.0),
    736.0,
    Some(8.0),
  )
  let next = make_test_block(
    2,
    PdfConvertBlockKind::Paragraph,
    "First bullet follows.",
    Some(12.0),
    710.0,
    Some(4.0),
  )

  let decision = decide_heading_classification(Some(prev), block, Some(next), 6)
  match decision.status {
    PdfHeadingDecisionStatus::KeepParagraph => ()
    _ => fail("expected KeepParagraph decision")
  }
  if !decision.reason_tags.contains("prev_heading_guard") {
    fail("expected prev_heading_guard reason")
  }
}
