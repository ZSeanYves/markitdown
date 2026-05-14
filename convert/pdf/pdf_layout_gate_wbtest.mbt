///|
fn gate_rect(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> @model.PdfRect {
  { x0, y0, x1, y1 }
}

///|
fn make_gate_block(
  block_index : Int,
  kind : PdfConvertBlockKind,
  text : String,
  font_size : Double?,
  top_y : Double,
  line_gap_before : Double?,
) -> PdfConvertBlock {
  let bbox = gate_rect(40.0, top_y - 12.0, 320.0, top_y)
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
    is_heading_candidate: kind == PdfConvertBlockKind::Heading,
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
    first_baseline_y: Some(top_y - 6.0),
    last_baseline_y: Some(top_y - 6.0),
    first_is_wrapped_candidate: false,
    last_is_wrapped_candidate: false,
    first_is_same_paragraph_with_prev_candidate: false,
    last_is_same_paragraph_with_prev_candidate: false,
  }
}

///|
fn with_table_candidate(block : PdfConvertBlock) -> PdfConvertBlock {
  { ..block, is_table_cell_candidate: true }
}

///|
fn make_gate_page(blocks : Array[PdfConvertBlock]) -> PdfConvertPage {
  {
    _page_index: 0,
    media_box: Some(gate_rect(0.0, 0.0, 595.0, 842.0)),
    crop_box: None,
    lines: [],
    blocks,
    images: [],
    annotations: [],
    objects: blocks.map(fn(block) { PdfConvertPageObject::TextBlock(block) }),
  }
}

///|
fn decision_for_target(
  summary : PdfLayoutGateSummary,
  target_id : String,
  stage : PdfLayoutGateStage,
) -> PdfLayoutGateDecision? {
  for decision in summary.decisions {
    if decision.target_id == target_id && decision.stage == stage {
      return Some(decision)
    }
  }
  None
}

///|
test "pdf layout gate demotes weak technical heading to paragraph" {
  let heading = make_gate_block(
    0,
    PdfConvertBlockKind::Heading,
    "BookReporter.py",
    Some(12.0),
    760.0,
    Some(2.0),
  )
  let body = make_gate_block(
    1,
    PdfConvertBlockKind::Paragraph,
    "The exporter writes rows to disk.",
    Some(12.0),
    736.0,
    Some(4.0),
  )
  let doc = { pages: [make_gate_page([heading, body])] }
  let gated = apply_pdf_layout_gate(doc, config={ enabled: true })
  assert_true(gated.pages[0].blocks[0].kind == PdfConvertBlockKind::Paragraph)

  let summary = build_pdf_layout_gate_summary(doc, gated, config={
    enabled: true,
  })
  match
    decision_for_target(summary, "p1.b0", PdfLayoutGateStage::HeadingDemotion) {
    Some(decision) => {
      assert_true(decision.override_allowed)
      assert_eq(decision.final_label, "keep_as_text")
      assert_eq(decision.output_kind, "paragraph")
    }
    None => fail("expected heading gate decision")
  }
}

///|
test "pdf layout gate keeps strong numbered heading" {
  let heading = make_gate_block(
    0,
    PdfConvertBlockKind::Heading,
    "1. Introduction",
    Some(16.0),
    760.0,
    Some(12.0),
  )
  let body = make_gate_block(
    1,
    PdfConvertBlockKind::Paragraph,
    "This section introduces the system design.",
    Some(12.0),
    734.0,
    Some(4.0),
  )
  let doc = { pages: [make_gate_page([heading, body])] }
  let gated = apply_pdf_layout_gate(doc, config={ enabled: true })
  assert_true(gated.pages[0].blocks[0].kind == PdfConvertBlockKind::Heading)

  let summary = build_pdf_layout_gate_summary(doc, gated, config={
    enabled: true,
  })
  match
    decision_for_target(summary, "p1.b0", PdfLayoutGateStage::HeadingDemotion) {
    Some(decision) =>
      assert_true(
        match decision.override_blocked_reason {
          Some(reason) => reason == "strong_heading_support"
          None => false
        },
      )
    None => fail("expected heading gate decision")
  }
}

///|
test "pdf layout gate hard constraints block weak heading override" {
  let heading = with_table_candidate(
    make_gate_block(
      0,
      PdfConvertBlockKind::Heading,
      "TOTAL $821.14",
      Some(12.0),
      760.0,
      Some(2.0),
    ),
  )
  let body = make_gate_block(
    1,
    PdfConvertBlockKind::Paragraph,
    "Receipt footer body paragraph.",
    Some(12.0),
    736.0,
    Some(4.0),
  )
  let doc = { pages: [make_gate_page([heading, body])] }
  let gated = apply_pdf_layout_gate(doc, config={ enabled: true })
  assert_true(gated.pages[0].blocks[0].kind == PdfConvertBlockKind::Heading)

  let summary = build_pdf_layout_gate_summary(doc, gated, config={
    enabled: true,
  })
  match
    decision_for_target(summary, "p1.b0", PdfLayoutGateStage::HeadingDemotion) {
    Some(decision) =>
      assert_true(decision.hard_constraints_applied.contains("table_geometry"))
    None => fail("expected constrained heading gate decision")
  }
}

///|
test "pdf layout gate suppresses technical bullets" {
  let block = make_gate_block(
    0,
    PdfConvertBlockKind::Paragraph,
    "- --timeout 30",
    Some(12.0),
    760.0,
    Some(4.0),
  )
  let page = make_gate_page([block])
  let doc = { pages: [page] }
  let ctx = build_pdf_layout_gate_doc_context(doc)
  let page_font_median = page_median_font_size(page)

  match
    decide_pdf_layout_list_gate(ctx, page, 0, page_font_median, {
      enabled: true,
    }) {
    Some(decision) => {
      assert_true(decision.override_allowed)
      assert_eq(decision.final_label, "paragraph")
      assert_eq(decision.output_kind, "paragraph")
      assert_true(
        !should_emit_pdf_bullet_list_item(ctx, page, 0, page_font_median, {
          enabled: true,
        }),
      )
    }
    None => fail("expected list suppression decision")
  }
}

///|
test "pdf layout gate keeps real bullet list items" {
  let block = make_gate_block(
    0,
    PdfConvertBlockKind::Paragraph,
    "* Important note about rollout.",
    Some(12.0),
    760.0,
    Some(4.0),
  )
  let page = make_gate_page([block])
  let doc = { pages: [page] }
  let ctx = build_pdf_layout_gate_doc_context(doc)
  let page_font_median = page_median_font_size(page)

  match
    decide_pdf_layout_list_gate(ctx, page, 0, page_font_median, {
      enabled: true,
    }) {
    Some(decision) => {
      assert_eq(decision.final_label, "list_item")
      assert_eq(decision.output_kind, "list_item")
      assert_true(
        match decision.override_blocked_reason {
          Some(reason) => reason == "strong_list_support"
          None => false
        },
      )
    }
    None => fail("expected list decision")
  }
}

///|
test "pdf layout gate disable switch keeps old heading behavior" {
  let heading = make_gate_block(
    0,
    PdfConvertBlockKind::Heading,
    "BookReporter.py",
    Some(12.0),
    760.0,
    Some(2.0),
  )
  let body = make_gate_block(
    1,
    PdfConvertBlockKind::Paragraph,
    "Body paragraph follows here.",
    Some(12.0),
    736.0,
    Some(4.0),
  )
  let doc = { pages: [make_gate_page([heading, body])] }
  let gated = apply_pdf_layout_gate(doc, config={ enabled: false })
  assert_true(gated.pages[0].blocks[0].kind == PdfConvertBlockKind::Heading)

  let summary = build_pdf_layout_gate_summary(doc, gated, config={
    enabled: false,
  })
  match
    decision_for_target(summary, "p1.b0", PdfLayoutGateStage::HeadingDemotion) {
    Some(decision) =>
      assert_true(
        match decision.override_blocked_reason {
          Some(reason) => reason == "gate_disabled"
          None => false
        },
      )
    None => fail("expected disabled heading gate decision")
  }
}

///|
test "pdf layout gate env parser accepts explicit off values" {
  assert_true(!parse_pdf_layout_gate_env(Some("0")))
  assert_true(!parse_pdf_layout_gate_env(Some("false")))
  assert_true(!parse_pdf_layout_gate_env(Some("off")))
  assert_true(parse_pdf_layout_gate_env(None))
  assert_true(parse_pdf_layout_gate_env(Some("1")))
}
