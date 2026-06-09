///|
test "test_uncompressed_single_page_text_pdf_produces_source_text_event" {
  let source = @source_event.build_pdf_v2_source_event_document(
    @pdfv2.open_pdf_core_v2(pdf_v2_minimal_text_pdf_bytes()),
    [],
  )
  assert_eq(source.summary.page_count, 1)
  assert_eq(source.pages[0].events.length() >= 2, true)
  assert_eq(source_text_event_count(source.events), 1)
}

///|
test "test_text_reconstruction_from_real_source_event_produces_block_text" {
  let source = @source_event.build_pdf_v2_source_event_document(
    @pdfv2.open_pdf_core_v2(pdf_v2_minimal_text_pdf_bytes()),
    [],
  )
  let model = @text_reconstruction.build_pdf_v2_text_model_from_source(
    source,
    @text_reconstruction.default_pdf_v2_text_reconstruction_options(),
  )
  assert_eq(model.summary.block_count, 1)
  assert_eq(model.pages[0].blocks[0].text, "Hello PDF v2")
  assert_eq(model.pages[0].blocks[0].object_refs[0], "4 0 R")
}

///|
test "test_text_reconstruction_from_flate_source_event_produces_block_text" {
  let source = @source_event.build_pdf_v2_source_event_document(
    @pdfv2.open_pdf_core_v2(pdf_v2_flate_valid_text_pdf_bytes()),
    [],
  )
  assert_eq(source_text_event_count(source.events), 1)
  let model = @text_reconstruction.build_pdf_v2_text_model_from_source(
    source,
    @text_reconstruction.default_pdf_v2_text_reconstruction_options(),
  )
  assert_eq(model.summary.block_count, 1)
  assert_eq(model.pages[0].blocks[0].text, "Hello Flate v2")
  assert_eq(model.pages[0].blocks[0].object_refs[0], "4 0 R")
}

///|
test "test_real_source_event_preserves_decode_warning_without_loss" {
  let source = @source_event.build_pdf_v2_source_event_document(
    @pdfv2.open_pdf_core_v2(pdf_v2_missing_font_pdf_bytes()),
    [],
  )
  let model = @text_reconstruction.build_pdf_v2_text_model_from_source(
    source,
    @text_reconstruction.default_pdf_v2_text_reconstruction_options(),
  )
  assert_eq(model.pages[0].blocks[0].text, "Missing Font")
  assert_eq(model.pages[0].blocks[0].warnings.length() > 0, true)
  assert_eq(model.pages[0].blocks[0].risks.length() > 0, true)
}

///|
fn source_text_event_count(
  events : Array[@source_event.PdfV2SourceEvent],
) -> Int {
  let mut count = 0
  for event in events {
    if event.kind == @source_event.PdfV2SourceEventKind::TextPayload {
      count = count + 1
    }
  }
  count
}
