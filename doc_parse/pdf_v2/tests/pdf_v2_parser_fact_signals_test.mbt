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
fn reset8_bbox() -> @pdfv2.PdfV2BBox {
  { x0: 0.0, y0: 0.0, x1: 612.0, y1: 792.0 }
}

///|
fn reset8_line(
  page_index : Int,
  line_index : Int,
  text : String,
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
    bbox: None,
    baseline: None,
    writing_direction: @pdfv2.PdfV2WritingDirection::Unknown,
    rotation: None,
  }
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
