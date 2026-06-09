///|
test "pdf v2 model can carry block facts and layout reading order" {
  let block = @pdfv2.pdf_v2_make_scaffold_block(0, "p0_b0", "Body text")
  let text_model : @pdfv2.PdfV2TextModel = {
    pages: [{ page_index: 0, blocks: [block], warnings: [] }],
    warnings: [],
    risks: [],
  }
  let source : @pdfv2.PdfV2SourceDocument = {
    core_bytes_len: 4,
    pages: [
      {
        page_index: 0,
        boxes: @pdfv2.pdf_v2_default_boxes(),
        rotation: 0,
        user_unit: None,
        events: [],
        source_refs: [@pdfv2.pdf_v2_source_ref_for_page(0)],
        warnings: [],
      },
    ],
    warnings: [],
    risks: [],
    scanned_once: true,
  }
  let layout = @pdfv2.recover_pdf_v2_layout(
    text_model,
    @pdfv2.default_pdf_v2_layout_options(),
  )
  let doc = @pdfv2.build_pdf_v2_document_model(source, text_model, layout)
  assert_eq(doc.pages.length(), 1)
  assert_eq(doc.pages[0].text_blocks[0].id, "p0_b0")
  assert_eq(doc.pages[0].reading_order.ordered_block_ids[0], "p0_b0")
}

///|
test "pdf v2 feature contract includes caption list heading and abstain signals" {
  let fields = @pdfv2.pdf_v2_default_feature_contract()
  assert_eq(fields.length() >= 7, true)
  assert_eq(fields[2].name, "line.hanging_indent_delta")
  assert_eq(fields[3].name, "block.near_image_distance")
  assert_eq(fields[5].name, "page.low_signal_risk")
}
