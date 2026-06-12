///|
fn has_capability(
  values : Array[@pdfv2.PdfV2CoreCapability],
  target : @pdfv2.PdfV2CoreCapability,
) -> Bool {
  for value in values {
    if value == target {
      return true
    }
  }
  false
}

///|
fn has_warning_reason(
  warnings : Array[@pdfv2.PdfV2Warning],
  tag : String,
) -> Bool {
  for warning in warnings {
    if warning.reason_tags.contains(tag) {
      return true
    }
  }
  false
}

///|
fn has_risk_reason(risks : Array[@pdfv2.PdfV2Risk], tag : String) -> Bool {
  for risk in risks {
    if risk.reason_tags.contains(tag) {
      return true
    }
  }
  false
}

///|
test "pdf v2 model exposes source refs warnings risks and bbox" {
  let source_ref : @pdfv2.PdfV2SourceRef = {
    page_index: Some(0),
    object_id: Some("12 0 R"),
    stream_index: Some(1),
    op_index: Some(2),
    content_order_index: Some(3),
    kind: @pdfv2.PdfV2SourceKind::Glyph,
  }
  let bbox : @pdfv2.PdfV2BBox = { x0: 1.0, y0: 2.0, x1: 3.0, y1: 4.0 }
  let warning = @pdfv2.pdf_v2_warning(
    @pdfv2.PdfV2WarningKind::DecodeIssue,
    @pdfv2.PdfV2Severity::Warning,
    "decode confidence below contract threshold",
    [source_ref],
    ["decode_low_confidence"],
  )
  let risk : @pdfv2.PdfV2Risk = {
    kind: @pdfv2.PdfV2RiskKind::DecodeLowConfidence,
    severity: @pdfv2.PdfV2Severity::Warning,
    message: "low confidence glyph decode",
    source_refs: [source_ref],
    reason_tags: ["decode_low_confidence"],
  }
  let event : @pdfv2.PdfV2SourceEvent = {
    kind: @pdfv2.PdfV2SourceEventKind::Glyph,
    page_index: Some(0),
    text: Some("A"),
    bbox: Some(bbox),
    object_ref: Some("12 0 R"),
    source_ref,
    reason_tags: ["glyph"],
    warnings: [warning],
    risks: [],
    text_state: None,
    text_show: None,
    glyph_candidate: None,
    object_fact: None,
  }

  assert_true(event.warnings.length() == 1)
  assert_true(risk.source_refs.length() == 1)
  assert_true(event.source_ref.kind == @pdfv2.PdfV2SourceKind::Glyph)
}

///|
test "pdf v2 empty document keeps parser facts separate from markdown policy" {
  let doc = @pdfv2.build_empty_pdf_v2_document()
  assert_true(doc.pages.length() == 0)
  assert_true(doc.source_events.length() == 0)
  assert_true(doc.source_summary.one_pass_scan)
  assert_true(!doc.source_summary.fallback_used)
  assert_true(!doc.source_summary.external_model_files_read)
  assert_true(doc.layout.confidence == 0.0)
}

///|
test "pdf v2 core facade capabilities cover reader substrate directions" {
  let capabilities = @pdfv2.pdf_v2_core_supported_capabilities()
  assert_true(has_capability(capabilities, @pdfv2.PdfV2CoreCapability::Fonts))
  assert_true(has_capability(capabilities, @pdfv2.PdfV2CoreCapability::Images))
  assert_true(has_capability(capabilities, @pdfv2.PdfV2CoreCapability::Vectors))
  assert_true(
    has_capability(capabilities, @pdfv2.PdfV2CoreCapability::Annotations),
  )
  assert_true(has_capability(capabilities, @pdfv2.PdfV2CoreCapability::Forms))
  assert_true(has_capability(capabilities, @pdfv2.PdfV2CoreCapability::Filters))
}

///|
test "pdf v2 model assembly rejects invalid candidate page index" {
  let page_ref : @pdfv2.PdfV2SourceRef = {
    page_index: Some(0),
    object_id: Some("3 0 R"),
    stream_index: None,
    op_index: None,
    content_order_index: None,
    kind: @pdfv2.PdfV2SourceKind::Page,
  }
  let bad_ref : @pdfv2.PdfV2SourceRef = {
    page_index: Some(99),
    object_id: Some("4 0 R"),
    stream_index: Some(0),
    op_index: Some(0),
    content_order_index: Some(0),
    kind: @pdfv2.PdfV2SourceKind::TextOp,
  }
  let bbox : @pdfv2.PdfV2BBox = { x0: 0.0, y0: 0.0, x1: 100.0, y1: 100.0 }
  let page : @pdfv2.PdfV2Page = {
    page_index: 0,
    page_label: None,
    media_box: bbox,
    crop_box: None,
    rotate: 0,
    user_unit: None,
    resources_present: false,
    bbox,
    source_ref: page_ref,
    events: [],
    text_blocks: [],
    layout_regions: [],
    warnings: [],
    risks: [],
  }
  let block : @pdfv2.PdfV2BlockCandidate = {
    page_index: Some(99),
    block_index: 0,
    text: "bad",
    lines: [],
    source_refs: [bad_ref],
    decode_confidence: @pdfv2.PdfV2TextDecodeConfidence::Medium,
    geometry_confidence: @pdfv2.PdfV2GeometryConfidence::Unknown,
    warnings: [],
    reason_tags: ["block_candidate"],
    merge_reason_tags: [],
    break_reason_tags: [],
    boundary_signal: @pdfv2.pdf_v2_empty_block_boundary_signal(),
    bbox: None,
    writing_direction: @pdfv2.PdfV2WritingDirection::Unknown,
    rotation: None,
    block_kind_hint: @pdfv2.PdfV2BlockKindHint::TextLike,
  }
  let source : @pdfv2.PdfV2SourceDocument = {
    source_events: [],
    pages: [page],
    font_cache: {
      fonts_seen: [],
      decode_profiles: [],
      cache_hits: 0,
      cache_misses: 0,
      warnings: [],
      risks: [],
    },
    char_candidates: [],
    span_candidates: [],
    line_candidates: [],
    block_candidates: [block],
    table_candidates: [],
    image_candidates: [],
    inline_image_candidates: [],
    annotation_candidates: [],
    link_candidates: [],
    form_candidates: [],
    outline_candidates: [],
    destination_candidates: [],
    resource_candidates: [],
    metadata_candidates: [],
    unsupported_capabilities: [],
    partial_fact_reports: [],
    object_summary: @pdfv2.pdf_v2_empty_object_summary(),
    reconstruction_summary: @pdfv2.pdf_v2_empty_reconstruction_summary(),
    summary: @pdfv2.pdf_v2_source_summary(0, 1, 0, 0),
    warnings: [],
    risks: [],
  }

  match @pdfv2.pdf_v2_document_model_from_source(source) {
    ModelAssemblyOk(_) => fail("expected invalid page index to fail closed")
    ModelAssemblyErr(warnings, risks, _) => {
      assert_true(has_warning_reason(warnings, "invalid_candidate_page_index"))
      assert_true(has_risk_reason(risks, "invalid_candidate_page_index"))
    }
  }
}
