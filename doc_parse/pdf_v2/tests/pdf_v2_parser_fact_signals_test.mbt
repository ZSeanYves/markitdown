///|
fn reset8_page_ref(page_index : Int) -> @pdfv2.PdfV2SourceRef {
  {
    page_index: Some(page_index),
    object_id: Some("\{page_index + 3} 0 R"),
    stream_index: None,
    op_index: None,
    content_order_index: None,
    kind: @pdfv2.PdfV2SourceKind::Page,
  }
}

///|
fn reset8_text_ref(page_index : Int, order : Int) -> @pdfv2.PdfV2SourceRef {
  {
    page_index: Some(page_index),
    object_id: Some("\{page_index + 10} 0 R"),
    stream_index: Some(0),
    op_index: Some(order),
    content_order_index: Some(order),
    kind: @pdfv2.PdfV2SourceKind::TextOp,
  }
}

///|
fn reset12_text_show_event(
  page_index : Int,
  order : Int,
  text : String,
  x : Double,
  y : Double,
) -> @pdfv2.PdfV2SourceEvent {
  let source_ref = reset8_text_ref(page_index, order)
  let show : @pdfv2.PdfV2TextShowFact = {
    raw_operator_kind: @pdfv2.PdfV2TextShowOperatorKind::Tj,
    raw_bytes_or_string: text,
    decoded_text: Some(text),
    font_ref: Some("/F1"),
    font_size: Some(12.0),
    text_matrix_snapshot: Some({ a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: x, f: y }),
    source_ref,
    decode_confidence: @pdfv2.PdfV2TextDecodeConfidence::High,
    warnings: [],
    reason_tags: ["text_show", "operator_Tj"],
  }
  {
    kind: @pdfv2.PdfV2SourceEventKind::TextShow,
    page_index: Some(page_index),
    text: Some(text),
    bbox: None,
    object_ref: source_ref.object_id,
    source_ref,
    reason_tags: ["text_show", "operator_Tj"],
    warnings: [],
    risks: [],
    text_state: None,
    text_show: Some(show),
    glyph_candidate: None,
    object_fact: None,
  }
}

///|
fn reset8_bbox() -> @pdfv2.PdfV2BBox {
  { x0: 0.0, y0: 0.0, x1: 612.0, y1: 792.0 }
}

///|
fn reset8_line(
  page_index : Int,
  line_index : Int,
  text : String,
) -> @pdfv2.PdfV2LineCandidate {
  reset8_line_with_bbox(page_index, line_index, text, None)
}

///|
fn reset8_line_with_bbox(
  page_index : Int,
  line_index : Int,
  text : String,
  bbox : @pdfv2.PdfV2BBox?,
) -> @pdfv2.PdfV2LineCandidate {
  let source_ref = reset8_text_ref(page_index, line_index)
  {
    page_index: Some(page_index),
    line_index,
    text,
    spans: [],
    source_refs: [source_ref],
    decode_confidence: @pdfv2.PdfV2TextDecodeConfidence::High,
    geometry_confidence: @pdfv2.PdfV2GeometryConfidence::Unknown,
    warnings: [],
    reason_tags: ["line_candidate"],
    merge_reason_tags: [],
    break_reason_tags: [],
    text_signal: @pdfv2.pdf_v2_build_line_text_signal(
      text,
      @pdfv2.PdfV2TextDecodeConfidence::High,
      [source_ref],
      ["line_candidate"],
    ),
    bbox,
    baseline: None,
    writing_direction: @pdfv2.PdfV2WritingDirection::Unknown,
    rotation: None,
  }
}

///|
fn reset8_top_line(
  page_index : Int,
  line_index : Int,
  text : String,
) -> @pdfv2.PdfV2LineCandidate {
  reset8_line_with_bbox(
    page_index,
    line_index,
    text,
    Some({ x0: 72.0, y0: 742.0, x1: 300.0, y1: 760.0 }),
  )
}

///|
fn reset8_bottom_line(
  page_index : Int,
  line_index : Int,
  text : String,
) -> @pdfv2.PdfV2LineCandidate {
  reset8_line_with_bbox(
    page_index,
    line_index,
    text,
    Some({ x0: 72.0, y0: 32.0, x1: 300.0, y1: 50.0 }),
  )
}

///|
fn reset8_body_line(
  page_index : Int,
  line_index : Int,
  text : String,
) -> @pdfv2.PdfV2LineCandidate {
  reset8_line_with_bbox(
    page_index,
    line_index,
    text,
    Some({ x0: 72.0, y0: 360.0, x1: 300.0, y1: 378.0 }),
  )
}

///|
fn reset8_block(
  page_index : Int,
  block_index : Int,
  lines : Array[@pdfv2.PdfV2LineCandidate],
) -> @pdfv2.PdfV2BlockCandidate {
  let refs : Array[@pdfv2.PdfV2SourceRef] = []
  let parts : Array[String] = []
  for line in lines {
    refs.append(line.source_refs)
    parts.push(line.text)
  }
  let effective_refs = if refs.length() == 0 {
    [reset8_text_ref(page_index, block_index)]
  } else {
    refs
  }
  {
    page_index: Some(page_index),
    block_index,
    text: parts.join("\n"),
    lines,
    source_refs: effective_refs,
    decode_confidence: @pdfv2.PdfV2TextDecodeConfidence::High,
    geometry_confidence: @pdfv2.PdfV2GeometryConfidence::Unknown,
    warnings: [],
    reason_tags: ["block_candidate"],
    merge_reason_tags: [],
    break_reason_tags: [],
    boundary_signal: @pdfv2.pdf_v2_build_block_boundary_signal(
      lines,
      ["block_candidate"],
      None,
    ),
    bbox: None,
    writing_direction: @pdfv2.PdfV2WritingDirection::Unknown,
    rotation: None,
    block_kind_hint: @pdfv2.PdfV2BlockKindHint::TextLike,
  }
}

///|
fn reset17_block_with_bbox(
  page_index : Int,
  block_index : Int,
  lines : Array[@pdfv2.PdfV2LineCandidate],
  bbox : @pdfv2.PdfV2BBox?,
) -> @pdfv2.PdfV2BlockCandidate {
  { ..reset8_block(page_index, block_index, lines), bbox, }
}

///|
fn reset8_lines_from_blocks(
  blocks : Array[@pdfv2.PdfV2BlockCandidate],
) -> Array[@pdfv2.PdfV2LineCandidate] {
  let lines : Array[@pdfv2.PdfV2LineCandidate] = []
  for block in blocks {
    lines.append(block.lines)
  }
  lines
}

///|
fn reset8_page(
  page_index : Int,
  blocks : Array[@pdfv2.PdfV2BlockCandidate],
) -> @pdfv2.PdfV2PageModel {
  let page_ref = reset8_page_ref(page_index)
  let bbox = reset8_bbox()
  {
    page_index,
    page_label: None,
    media_box: bbox,
    crop_box: None,
    rotate: 0,
    user_unit: None,
    resources_present: false,
    source_ref: page_ref,
    blocks,
    lines: reset8_lines_from_blocks(blocks),
    spans: [],
    chars: [],
    images: [],
    inline_images: [],
    annotations: [],
    links: [],
    tables: [],
    forms: [],
    resources: [],
    metadata_refs: [],
    page_warnings: [],
    page_risks: [],
    text_blocks: [],
    layout_regions: [],
  }
}

///|
fn reset17_image_ref(
  page_index : Int,
  order : Int,
  object_ref : String,
) -> @pdfv2.PdfV2SourceRef {
  {
    page_index: Some(page_index),
    object_id: Some(object_ref),
    stream_index: Some(0),
    op_index: Some(order),
    content_order_index: Some(order),
    kind: @pdfv2.PdfV2SourceKind::Image,
  }
}

///|
fn reset17_image(
  page_index : Int,
  order : Int,
  object_ref : String,
  bbox : @pdfv2.PdfV2BBox?,
) -> @pdfv2.PdfV2ImageCandidate {
  let source_ref = reset17_image_ref(page_index, order, object_ref)
  {
    page_index: Some(page_index),
    object_ref: Some(object_ref),
    width: Some(640),
    height: Some(360),
    color_space: Some("/DeviceRGB"),
    bits_per_component: Some(8),
    filters: ["/DCTDecode"],
    image_mask: None,
    mask_present: false,
    smask_present: false,
    inline: false,
    bbox,
    nesting: None,
    placement: None,
    caption: None,
    source_ref,
    warnings: [],
    risks: [],
    reason_tags: ["image_candidate"],
    decode_status: @pdfv2.PdfV2ImageDecodeStatus::DecodeAvailable,
    asset: None,
  }
}

///|
fn reset8_model(
  pages : Array[@pdfv2.PdfV2PageModel],
) -> @pdfv2.PdfV2DocumentModel {
  let source_ref = if pages.length() == 0 {
    @pdfv2.pdf_v2_document_source_ref()
  } else {
    pages[0].source_ref
  }
  {
    document_id: None,
    page_count: pages.length(),
    metadata: {
      title: None,
      author: None,
      subject: None,
      creator: None,
      producer: None,
      keywords: None,
      created: None,
      modified: None,
      source_refs: [source_ref],
    },
    pages,
    source_events: [],
    outlines: [],
    destinations: [],
    metadata_candidates: [],
    unsupported_capabilities: [],
    partial_fact_reports: [],
    object_summary: @pdfv2.pdf_v2_empty_object_summary(),
    layout: @pdfv2.recover_pdf_v2_layout_noop([source_ref]),
    warnings: [],
    risks: [],
    source_summary: @pdfv2.pdf_v2_source_summary(0, pages.length(), 0, 0),
    reconstruction_summary: @pdfv2.pdf_v2_empty_reconstruction_summary(),
    capabilities: @pdfv2.pdf_v2_core_supported_capabilities(),
    one_pass: true,
    no_fallback: true,
    model_version: "pdf-v2-reset8-test",
  }
}

///|
fn reset8_has_artifact_kind(
  values : Array[@pdfv2.PdfV2PageArtifactCandidate],
  kind : @pdfv2.PdfV2PageArtifactKind,
) -> Bool {
  for value in values {
    if value.kind == kind {
      return true
    }
  }
  false
}

///|
test "pdf v2 line text signal exposes normalized markers and guards" {
  let normalized = @pdfv2.pdf_v2_build_line_text_signal(
    "  Hello\tworld\n中文  ",
    @pdfv2.PdfV2TextDecodeConfidence::Medium,
    [reset8_text_ref(0, 0)],
    ["unit_test"],
  )
  assert_true(normalized.normalized_text == "Hello world 中文")
  assert_true(
    normalized.decode_confidence == @pdfv2.PdfV2TextDecodeConfidence::Medium,
  )
  assert_true(normalized.reason_tags.contains("parser_owned_line_text_signal"))

  let unordered = @pdfv2.pdf_v2_build_line_text_signal(
    "• item",
    @pdfv2.PdfV2TextDecodeConfidence::High,
    [reset8_text_ref(0, 1)],
    [],
  )
  assert_true(unordered.starts_with_unordered_marker)
  match unordered.marker_candidate {
    Some(marker) => assert_true(marker.body_text == "item")
    None => fail("expected unordered marker")
  }

  let ordered = @pdfv2.pdf_v2_build_line_text_signal(
    "（一）事项",
    @pdfv2.PdfV2TextDecodeConfidence::High,
    [reset8_text_ref(0, 2)],
    [],
  )
  assert_true(ordered.starts_with_ordered_marker)
  assert_true(ordered.marker_candidate is Some(_))

  let page_number = @pdfv2.pdf_v2_build_line_text_signal(
    "Page 1 of 10",
    @pdfv2.PdfV2TextDecodeConfidence::High,
    [reset8_text_ref(0, 3)],
    [],
  )
  assert_true(page_number.starts_with_page_number)
  assert_true(page_number.looks_like_noise_line)

  let chapter = @pdfv2.pdf_v2_build_line_text_signal(
    "第一章 绪论",
    @pdfv2.PdfV2TextDecodeConfidence::High,
    [reset8_text_ref(0, 4)],
    [],
  )
  assert_true(!chapter.starts_with_page_number)
  assert_true(chapter.looks_like_title_line)

  let caption = @pdfv2.pdf_v2_build_line_text_signal(
    "Figure 1 Pipeline",
    @pdfv2.PdfV2TextDecodeConfidence::High,
    [reset8_text_ref(0, 5)],
    [],
  )
  assert_true(caption.starts_with_caption_marker)
  assert_true(!caption.looks_like_title_line)
}

///|
test "pdf v2 block boundary signal scores parser evidence without semantics" {
  let title = reset8_line(0, 0, "Introduction")
  let body = reset8_line(0, 1, "This paragraph explains the topic.")
  let heading_block = reset8_block(0, 0, [title, body])
  assert_true(heading_block.boundary_signal.heading_candidate_score >= 0.80)
  assert_true(
    heading_block.boundary_signal.reason_tags.contains(
      "heading_boundary_candidate",
    ),
  )
  assert_true(heading_block.boundary_signal.boundary_confidence <= 0.50)

  let list_block = reset8_block(0, 1, [reset8_line(0, 2, "- item")])
  assert_true(list_block.boundary_signal.list_candidate_score >= 0.90)

  let hardwrap = reset8_block(0, 2, [
    reset8_line(0, 3, "This is a hardwrapped"),
    reset8_line(0, 4, "paragraph continuation"),
  ])
  assert_true(hardwrap.boundary_signal.continuation_candidate_score >= 0.50)

  let page_number = reset8_block(0, 3, [reset8_line(0, 5, "- 1 -")])
  assert_true(page_number.boundary_signal.artifact_candidate_score >= 0.90)
}

///|
test "pdf v2 text flow candidates split heading body and inline list facts" {
  let heading_block = reset8_block(0, 0, [
    reset8_line(0, 0, "Introduction"),
    reset8_line(0, 1, "This paragraph explains the topic."),
  ])
  let inline_list = reset8_block(0, 1, [
    reset8_line(0, 2, "Key points: • First item • Second item"),
  ])
  let page = reset8_page(0, [heading_block, inline_list])
  let model = reset8_model([page])
  let candidates = @pdfv2.pdf_v2_build_text_flow_candidates(model)

  assert_true(candidates.length() == 5)
  assert_true(candidates[0].normalized_text == "Introduction")
  assert_true(candidates[1].normalized_text.contains("paragraph explains"))
  assert_true(candidates[0].line_indices[0] == 0)
  assert_true(candidates[0].source_refs.length() > 0)
  assert_true(candidates[2].normalized_text == "Key points:")
  assert_true(candidates[3].normalized_text == "• First item")
  assert_true(candidates[3].line_signals[0].starts_with_unordered_marker)
  assert_true(candidates[4].normalized_text == "• Second item")
}

///|
test "pdf v2 parser builds pipe and aligned table candidates conservatively" {
  let pipe_block = reset8_block(0, 0, [
    reset8_line(0, 0, "| Product | Revenue |"),
    reset8_line(0, 1, "| --- | --- |"),
    reset8_line(0, 2, "| Alpha | 12 |"),
    reset8_line(0, 3, "| Beta | 34 |"),
  ])
  let aligned_block = reset8_block(0, 1, [
    reset8_line(0, 4, "Product  Revenue"),
    reset8_line(0, 5, "Alpha    12"),
    reset8_line(0, 6, "Beta     34"),
  ])
  let candidates = @pdfv2.pdf_v2_build_table_candidates([], [
    pipe_block, aligned_block,
  ])

  assert_true(candidates.length() == 2)
  assert_true(candidates[0].table_kind == @pdfv2.PdfV2TableKind::PipeSeparated)
  assert_true(candidates[0].has_header)
  assert_true(candidates[0].rows[0] == ["Product", "Revenue"])
  assert_true(candidates[0].rows[2] == ["Beta", "34"])
  assert_true(
    candidates[1].table_kind == @pdfv2.PdfV2TableKind::WhitespaceAligned,
  )
  assert_true(candidates[1].rows[1] == ["Alpha", "12"])
}

///|
test "pdf v2 parser builds coordinate grid table candidates from text shows" {
  let block = reset8_block(0, 0, [
    reset8_line(0, 0, "Product Region Status Alpha East Open Beta West Closed"),
  ])
  let events = [
    reset12_text_show_event(0, 0, "Product", 40.0, 710.0),
    reset12_text_show_event(0, 1, "Region", 180.0, 710.0),
    reset12_text_show_event(0, 2, "Status", 300.0, 710.0),
    reset12_text_show_event(0, 3, "Alpha", 40.0, 688.0),
    reset12_text_show_event(0, 4, "East", 180.0, 688.0),
    reset12_text_show_event(0, 5, "Open", 300.0, 688.0),
    reset12_text_show_event(0, 6, "Beta", 40.0, 666.0),
    reset12_text_show_event(0, 7, "West", 180.0, 666.0),
    reset12_text_show_event(0, 8, "Closed", 300.0, 666.0),
  ]
  let candidates = @pdfv2.pdf_v2_build_table_candidates(events, [block])

  assert_true(candidates.length() == 1)
  let table = candidates[0]
  assert_true(table.table_kind == @pdfv2.PdfV2TableKind::CoordinateGrid)
  assert_true(table.confidence >= 0.90)
  assert_true(table.block_indices == [0])
  assert_true(table.line_indices.length() == 9)
  assert_true(table.source_refs.length() == 9)
  assert_true(table.rows.length() == 3)
  assert_true(table.columns == 3)
  assert_true(table.rows[0] == ["Product", "Region", "Status"])
  assert_true(table.rows[1] == ["Alpha", "East", "Open"])
  assert_true(table.rows[2] == ["Beta", "West", "Closed"])
}

///|
test "pdf v2 parser rejects weak table-like paragraphs lists and captions" {
  let paragraph = reset8_block(0, 0, [
    reset8_line(0, 0, "This ordinary paragraph mentions Product and Revenue."),
  ])
  let listish = reset8_block(0, 1, [
    reset8_line(0, 1, "- Product  Revenue"),
    reset8_line(0, 2, "- Alpha    12"),
  ])
  let caption = reset8_block(0, 2, [
    reset8_line(0, 3, "Table 1  Revenue"),
    reset8_line(0, 4, "Alpha    12"),
  ])
  let ragged = reset8_block(0, 3, [
    reset8_line(0, 5, "Product  Revenue"),
    reset8_line(0, 6, "Alpha    12  Extra"),
  ])
  let candidates = @pdfv2.pdf_v2_build_table_candidates([], [
    paragraph, listish, caption, ragged,
  ])

  assert_true(candidates.length() == 0)
}

///|
test "pdf v2 page artifact candidates stay conservative" {
  let first = reset8_page(0, [
    reset8_block(0, 0, [reset8_line(0, 0, "Page 1")]),
    reset8_block(0, 1, [reset8_line(0, 1, "Draft")]),
    reset8_block(0, 2, [reset8_line(0, 2, "第一章 绪论")]),
  ])
  let second = reset8_page(1, [
    reset8_block(1, 0, [reset8_line(1, 0, "第2页")]),
    reset8_block(1, 1, [reset8_line(1, 1, "Draft")]),
    reset8_block(1, 2, [reset8_line(1, 2, "Body sentence.")]),
  ])
  let artifacts = @pdfv2.pdf_v2_build_page_artifact_candidates(
    reset8_model([first, second]),
  )

  assert_true(
    reset8_has_artifact_kind(
      artifacts,
      @pdfv2.PdfV2PageArtifactKind::PageNumberLike,
    ),
  )
  assert_true(
    reset8_has_artifact_kind(
      artifacts,
      @pdfv2.PdfV2PageArtifactKind::RepeatedLineLike,
    ),
  )
  for artifact in artifacts {
    assert_true(artifact.normalized_text != "第一章 绪论")
  }
}

///|
test "pdf v2 page artifact candidates classify repeated edge headers and footers" {
  let first = reset8_page(0, [
    reset8_block(0, 0, [reset8_top_line(0, 0, "Confidential")]),
    reset8_block(0, 1, [reset8_body_line(0, 1, "Alpha body sentence.")]),
    reset8_block(0, 2, [reset8_bottom_line(0, 2, "draft footer")]),
  ])
  let second = reset8_page(1, [
    reset8_block(1, 0, [reset8_top_line(1, 0, "Confidential")]),
    reset8_block(1, 1, [reset8_body_line(1, 1, "Beta body sentence.")]),
    reset8_block(1, 2, [reset8_bottom_line(1, 2, "draft footer")]),
  ])
  let artifacts = @pdfv2.pdf_v2_build_page_artifact_candidates(
    reset8_model([first, second]),
  )

  let mut header_seen = false
  let mut footer_seen = false
  for artifact in artifacts {
    if artifact.normalized_text == "Confidential" {
      header_seen = true
      assert_true(artifact.kind == @pdfv2.PdfV2PageArtifactKind::HeaderLike)
      assert_true(artifact.position_band == @pdfv2.PdfV2PagePositionBand::Top)
      assert_true(artifact.confidence >= 0.90)
    }
    if artifact.normalized_text == "draft footer" {
      footer_seen = true
      assert_true(artifact.kind == @pdfv2.PdfV2PageArtifactKind::FooterLike)
      assert_true(
        artifact.position_band == @pdfv2.PdfV2PagePositionBand::Bottom,
      )
      assert_true(artifact.confidence >= 0.90)
    }
  }
  assert_true(header_seen)
  assert_true(footer_seen)
}

///|
test "pdf v2 page artifact candidates preserve repeated body titles and content" {
  let first = reset8_page(0, [
    reset8_block(0, 0, [reset8_body_line(0, 0, "Project Overview")]),
    reset8_block(0, 1, [reset8_body_line(0, 1, "第一章 绪论")]),
    reset8_block(0, 2, [reset8_body_line(0, 2, "Revenue 2026")]),
  ])
  let second = reset8_page(1, [
    reset8_block(1, 0, [reset8_body_line(1, 0, "Project Overview")]),
    reset8_block(1, 1, [reset8_body_line(1, 1, "第一章 绪论")]),
    reset8_block(1, 2, [reset8_body_line(1, 2, "Revenue 2026")]),
  ])
  let artifacts = @pdfv2.pdf_v2_build_page_artifact_candidates(
    reset8_model([first, second]),
  )

  for artifact in artifacts {
    assert_true(artifact.normalized_text != "Project Overview")
    assert_true(artifact.normalized_text != "第一章 绪论")
    assert_true(artifact.normalized_text != "Revenue 2026")
  }
}

///|
test "pdf v2 line signals recognize standalone page number variants" {
  let p_label = @pdfv2.pdf_v2_build_line_text_signal(
    "p. 7",
    @pdfv2.PdfV2TextDecodeConfidence::High,
    [reset8_text_ref(0, 0)],
    ["line_candidate"],
  )
  let fraction = @pdfv2.pdf_v2_build_line_text_signal(
    "3/10",
    @pdfv2.PdfV2TextDecodeConfidence::High,
    [reset8_text_ref(0, 1)],
    ["line_candidate"],
  )
  let cjk_fraction = @pdfv2.pdf_v2_build_line_text_signal(
    "第 3/10 页",
    @pdfv2.PdfV2TextDecodeConfidence::High,
    [reset8_text_ref(0, 2)],
    ["line_candidate"],
  )
  let chapter = @pdfv2.pdf_v2_build_line_text_signal(
    "第一章 绪论",
    @pdfv2.PdfV2TextDecodeConfidence::High,
    [reset8_text_ref(0, 3)],
    ["line_candidate"],
  )

  assert_true(p_label.starts_with_page_number)
  assert_true(fraction.starts_with_page_number)
  assert_true(cjk_fraction.starts_with_page_number)
  assert_true(!chapter.starts_with_page_number)
}

///|
test "pdf v2 parity facts expose cross-page and heading risks without product behavior" {
  let first = reset8_page(0, [
    reset8_block(0, 0, [reset8_line(0, 0, "This sentence continues")]),
  ])
  let second = reset8_page(1, [
    reset8_block(1, 0, [reset8_line(1, 0, "onto the next page.")]),
    reset8_block(1, 1, [reset8_line(1, 1, "Short Heading")]),
  ])
  let facts = @pdfv2.pdf_v2_parity_facts_from_model(
    reset8_model([first, second]),
  )

  assert_true(facts.cross_page_boundaries.length() == 1)
  let boundary = facts.cross_page_boundaries[0]
  assert_true(boundary.page_from == 0)
  assert_true(boundary.page_to == 1)
  assert_true(boundary.prev_open_ended)
  assert_true(boundary.confidence >= 0.50)
  assert_true(boundary.reason_tags.contains("cross_page_boundary_fact"))
  assert_true(boundary.source_refs.length() >= 2)

  let mut short_heading_seen = false
  for fact in facts.heading_boundaries {
    if fact.block_ref == Some(1) {
      short_heading_seen = true
      assert_true(fact.short_text_risk)
      assert_true(fact.font_layout_evidence == "layout_score_only")
      assert_true(fact.reason_tags.contains("heading_boundary_fact"))
    }
  }
  assert_true(short_heading_seen)
  assert_true(facts.reason_tags.contains("not_product_behavior"))
}

///|
test "pdf v2 parity facts expose image text boundary and unknown geometry" {
  let caption = reset8_block(0, 0, [
    reset8_line(0, 6, "Figure 1 System diagram"),
  ])
  let page = {
    ..reset8_page(0, [caption]),
    images: [reset17_image(0, 5, "9 0 R", None)],
  }
  let facts = @pdfv2.pdf_v2_parity_facts_from_model(reset8_model([page]))

  assert_true(facts.image_text_boundaries.length() == 1)
  let image_fact = facts.image_text_boundaries[0]
  assert_true(image_fact.image_ref == "9 0 R")
  assert_true(image_fact.caption_candidate)
  assert_true(image_fact.relation == @pdfv2.PdfV2ParityTextRelation::After)
  assert_true(image_fact.distance == "unknown")
  assert_true(image_fact.page_band == @pdfv2.PdfV2ParityVerticalBand::Unknown)
  assert_true(image_fact.confidence >= 0.60)
  assert_true(image_fact.reason_tags.contains("image_geometry_unknown"))
  assert_true(image_fact.source_refs.length() >= 2)
}

///|
test "pdf v2 parity facts expose repeated header footer variants" {
  let first = reset8_page(0, [
    reset8_block(0, 0, [reset8_top_line(0, 0, "Confidential 1")]),
    reset8_block(0, 1, [reset8_bottom_line(0, 1, "draft footer")]),
  ])
  let second = reset8_page(1, [
    reset8_block(1, 0, [reset8_top_line(1, 0, "Confidential 2")]),
    reset8_block(1, 1, [reset8_bottom_line(1, 1, "draft footer")]),
  ])
  let facts = @pdfv2.pdf_v2_parity_facts_from_model(
    reset8_model([first, second]),
  )

  let mut footer_seen = false
  let mut header_variant_seen = false
  for fact in facts.header_footer_variants {
    if fact.repeated_text_cluster == "draft footer" {
      footer_seen = true
      assert_true(fact.normalized_key == "draft footer")
      assert_true(fact.page_positions == [0, 1])
      assert_true(fact.page_coverage_ratio == 1.0)
      assert_true(fact.position_band == @pdfv2.PdfV2ParityVerticalBand::Bottom)
      assert_true(fact.reason_tags.contains("header_footer_variant_fact"))
    }
    if fact.normalized_key == "confidential #" {
      header_variant_seen = true
      assert_true(fact.repeated_text_cluster.contains("Confidential 1"))
      assert_true(fact.repeated_text_cluster.contains("Confidential 2"))
      assert_true(fact.page_positions == [0, 1])
      assert_true(fact.position_band == @pdfv2.PdfV2ParityVerticalBand::Top)
      assert_true(fact.reason_tags.contains("edge_variant_cluster"))
    }
  }
  assert_true(footer_seen)
  assert_true(header_variant_seen)
}

///|
test "pdf v2 parity facts mark column layout unknown before geometry is reliable" {
  let unknown_page = reset8_page(0, [
    reset8_block(0, 0, [reset8_line(0, 0, "Left column maybe")]),
    reset8_block(0, 1, [reset8_line(0, 1, "Right column maybe")]),
  ])
  let known_page = reset8_page(1, [
    reset17_block_with_bbox(
      1,
      0,
      [reset8_line(1, 0, "Left column")],
      Some({ x0: 40.0, y0: 600.0, x1: 240.0, y1: 620.0 }),
    ),
    reset17_block_with_bbox(
      1,
      1,
      [reset8_line(1, 1, "Right column")],
      Some({ x0: 360.0, y0: 600.0, x1: 560.0, y1: 620.0 }),
    ),
  ])
  let facts = @pdfv2.pdf_v2_parity_facts_from_model(
    reset8_model([unknown_page, known_page]),
  )

  assert_true(facts.column_layouts.length() == 2)
  assert_true(facts.column_layouts[0].detected_column_count == "unknown")
  assert_true(facts.column_layouts[0].ambiguity_flag)
  assert_true(
    facts.column_layouts[0].reason_tags.contains("column_geometry_unknown"),
  )
  assert_true(facts.column_layouts[1].detected_column_count == "2")
  assert_true(facts.column_layouts[1].column_assignments == ["left", "right"])
  assert_true(
    facts.column_layouts[1].reason_tags.contains("two_column_candidate"),
  )
}
