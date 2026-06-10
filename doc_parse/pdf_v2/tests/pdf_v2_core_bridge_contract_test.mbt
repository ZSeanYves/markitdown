///|
fn bridge_source_ref(kind : @pdfv2.PdfV2SourceKind) -> @pdfv2.PdfV2SourceRef {
  {
    page_index: Some(0),
    object_id: Some("7 0 R"),
    stream_index: Some(1),
    op_index: Some(2),
    content_order_index: Some(3),
    kind,
  }
}

///|
fn bridge_bbox() -> @pdfv2.PdfV2BBox {
  { x0: 1.0, y0: 2.0, x1: 3.0, y1: 4.0 }
}

///|
fn bridge_warning(source_ref : @pdfv2.PdfV2SourceRef) -> @pdfv2.PdfV2Warning {
  @pdfv2.pdf_v2_warning(
    @pdfv2.PdfV2WarningKind::UnsupportedCapability,
    @pdfv2.PdfV2Severity::Warning,
    "unsupported source feature preserved as warning",
    [source_ref],
    ["unsupported", "no_fallback"],
  )
}

///|
fn bridge_risk(source_ref : @pdfv2.PdfV2SourceRef) -> @pdfv2.PdfV2Risk {
  {
    kind: @pdfv2.PdfV2RiskKind::UnsupportedFeature,
    severity: @pdfv2.PdfV2Severity::Warning,
    message: "unsupported source feature preserved as risk",
    source_refs: [source_ref],
    reason_tags: ["unsupported", "no_fallback"],
  }
}

///|
fn bridge_page_fact(
  source_ref : @pdfv2.PdfV2SourceRef,
) -> @pdfv2.PdfV2CorePageFact {
  {
    page_index: 0,
    page_label: Some("1"),
    media_box: bridge_bbox(),
    crop_box: None,
    rotate: 0,
    user_unit: Some(1.0),
    resources_present: true,
    source_ref,
  }
}

///|
fn bridge_core_document(
  source_ref : @pdfv2.PdfV2SourceRef,
) -> @pdfv2.PdfV2CoreDocument {
  {
    page_count: 1,
    capabilities: @pdfv2.pdf_v2_core_supported_capabilities(),
    page_facts: [bridge_page_fact(source_ref)],
    warnings: [bridge_warning(source_ref)],
    risks: [bridge_risk(source_ref)],
    source_summary: @pdfv2.pdf_v2_empty_source_summary(),
  }
}

///|
test "pdf v2 core open options expose collection flags and performance caps" {
  let options : @pdfv2.PdfV2CoreOpenOptions = {
    collect_text: true,
    collect_images: false,
    collect_vectors: true,
    collect_annotations: true,
    collect_forms: false,
    collect_outlines: true,
    collect_metadata: true,
    max_pages: Some(3),
    max_objects: Some(100),
    max_stream_bytes: Some(4096),
    max_events: Some(20),
    object_caps: @pdfv2.pdf_v2_default_object_cap_options(),
    fail_on_encrypted: true,
  }
  assert_true(options.collect_text)
  assert_true(!options.collect_images)
  assert_true(options.max_pages == Some(3))
  assert_true(options.max_objects == Some(100))
  assert_true(options.max_stream_bytes == Some(4096))
  assert_true(options.max_events == Some(20))
  assert_true(options.fail_on_encrypted)

  let defaults = @pdfv2.default_pdf_v2_core_open_options()
  assert_true(defaults.collect_images)
  assert_true(defaults.collect_vectors)
  assert_true(defaults.max_pages is None)
}

///|
test "pdf v2 core events represent parser substrate event classes" {
  let source_ref = bridge_source_ref(@pdfv2.PdfV2SourceKind::TextOp)
  let kinds : Array[@pdfv2.PdfV2CoreEventKind] = [
    PageBegin,
    TextShow,
    Image,
    InlineImage,
    VectorPath,
    Annotation,
    Form,
    Malformed,
    Unsupported,
  ]
  let events = kinds.map(fn(kind) { @pdfv2.pdf_v2_core_event(kind, source_ref) })
  assert_true(events.length() == 9)
  assert_true(events[0].kind == @pdfv2.PdfV2CoreEventKind::PageBegin)
  assert_true(events[1].kind == @pdfv2.PdfV2CoreEventKind::TextShow)
  assert_true(events[2].kind == @pdfv2.PdfV2CoreEventKind::Image)
  assert_true(events[3].kind == @pdfv2.PdfV2CoreEventKind::InlineImage)
  assert_true(events[4].kind == @pdfv2.PdfV2CoreEventKind::VectorPath)
  assert_true(events[5].kind == @pdfv2.PdfV2CoreEventKind::Annotation)
  assert_true(events[6].kind == @pdfv2.PdfV2CoreEventKind::Form)
  assert_true(events[7].kind == @pdfv2.PdfV2CoreEventKind::Malformed)
  assert_true(events[8].kind == @pdfv2.PdfV2CoreEventKind::Unsupported)
}

///|
test "pdf v2 raw bridge preserves source refs warnings and reason tags" {
  let source_ref = bridge_source_ref(@pdfv2.PdfV2SourceKind::TextOp)
  let warning = bridge_warning(source_ref)
  let core_event : @pdfv2.PdfV2CoreEvent = {
    kind: @pdfv2.PdfV2CoreEventKind::TextShow,
    page_index: Some(0),
    text: Some("Hello"),
    bbox: Some(bridge_bbox()),
    object_ref: Some("7 0 R"),
    source_ref,
    reason_tags: ["text_show", "source_attributed"],
    warnings: [warning],
    text_state: None,
    text_show: None,
    glyph_candidate: None,
    object_fact: None,
  }
  let events = @pdfv2.pdf_v2_source_events_from_core_events([core_event])
  assert_true(events.length() == 1)
  assert_true(events[0].kind == @pdfv2.PdfV2SourceEventKind::TextShow)
  assert_true(events[0].text == Some("Hello"))
  assert_true(events[0].source_ref.stream_index == Some(1))
  assert_true(events[0].source_ref.op_index == Some(2))
  assert_true(events[0].object_ref == Some("7 0 R"))
  assert_true(events[0].reason_tags.length() == 2)
  assert_true(events[0].warnings.length() == 1)
}

///|
test "pdf v2 source document summary preserves warnings risks and avoids grouping" {
  let source_ref = bridge_source_ref(@pdfv2.PdfV2SourceKind::Page)
  let core = bridge_core_document(source_ref)
  let page_begin = @pdfv2.pdf_v2_core_event(
    @pdfv2.PdfV2CoreEventKind::PageBegin,
    source_ref,
  )
  let unsupported : @pdfv2.PdfV2CoreEvent = {
    kind: @pdfv2.PdfV2CoreEventKind::Unsupported,
    page_index: Some(0),
    text: None,
    bbox: None,
    object_ref: Some("7 0 R"),
    source_ref,
    reason_tags: ["unsupported_filter"],
    warnings: [bridge_warning(source_ref)],
    text_state: None,
    text_show: None,
    glyph_candidate: None,
    object_fact: None,
  }
  let source_doc = @pdfv2.pdf_v2_source_document_from_core(core, [
    page_begin, unsupported,
  ])
  assert_true(source_doc.source_events.length() == 2)
  assert_true(source_doc.pages.length() == 1)
  assert_true(source_doc.pages[0].events.length() == 2)
  assert_true(source_doc.pages[0].text_blocks.length() == 0)
  assert_true(source_doc.pages[0].layout_regions.length() == 0)
  assert_true(source_doc.summary.event_count == 2)
  assert_true(source_doc.summary.page_count == 1)
  assert_true(source_doc.summary.warning_count == 2)
  assert_true(source_doc.summary.risk_count == 1)
  assert_true(source_doc.summary.one_pass_scan)
  assert_true(!source_doc.summary.fallback_used)
  assert_true(!source_doc.summary.external_model_files_read)
  assert_true(source_doc.warnings.length() == 2)
  assert_true(source_doc.risks.length() == 1)
}

///|
test "pdf v2 parser boundary exposes source facts without convert policy" {
  let source_ref = bridge_source_ref(@pdfv2.PdfV2SourceKind::Page)
  let core = bridge_core_document(source_ref)
  let source_doc = @pdfv2.pdf_v2_source_document_from_core(core, [])
  assert_true(source_doc.summary.one_pass_scan)
  assert_true(!source_doc.summary.fallback_used)
  assert_true(source_doc.source_events.length() == 0)
  assert_true(source_doc.pages[0].text_blocks.length() == 0)
}
