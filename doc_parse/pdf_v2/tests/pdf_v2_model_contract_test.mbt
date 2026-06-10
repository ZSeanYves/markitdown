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
