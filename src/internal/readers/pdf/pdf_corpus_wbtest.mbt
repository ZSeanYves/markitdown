///|
test "PDF native backend directly parses the main contract corpus" {
  let paths = [
    "samples/fixtures/contracts/pdf/hardwrap_en.pdf", "samples/fixtures/contracts/pdf/pdf_header_footer_variants_phase15.pdf",
    "samples/fixtures/contracts/pdf/pdf_metadata_table_like.pdf", "samples/fixtures/contracts/pdf/pdf_metadata_uri_link.pdf",
    "samples/fixtures/contracts/pdf/pdf_ocr_single_page.pdf", "samples/fixtures/contracts/pdf/pdf_ocr_two_page.pdf",
    "samples/fixtures/contracts/pdf/pdf_simple_table_like.pdf", "samples/fixtures/contracts/pdf/root_native_text_baseline.pdf",
    "samples/fixtures/contracts/pdf/text_multipage.pdf", "samples/fixtures/contracts/pdf/text_simple.pdf",
  ]
  let mut succeeded = 0
  let mut failed = 0
  let mut page_count = 0
  let mut text_block_count = 0
  for path in paths {
    match extract_pdf_native_document_from_path(path) {
      Ok(document) => {
        succeeded += 1
        page_count += document.pages.length()
        for page in document.pages {
          text_block_count += page.text_blocks.length()
          assert_true(page.geometry.page_no > 0)
        }
        assert_true(document.diagnostics.metrics.length() > 0)
      }
      Err(_) => failed += 1
    }
  }
  assert_true(succeeded >= 8)
  assert_true(page_count >= succeeded)
  assert_true(text_block_count > 0)
  assert_eq(succeeded + failed, paths.length())
}

///|
test "PDF native backend fails closed for empty invalid encrypted and truncated bytes" {
  let cases : Array[(@input.InputSource, String)] = [
    (@input.input_from_bytes(Bytes::from_array([])), "empty"),
    (@input.input_from_text("not a pdf"), "not_pdf"),
    (
      @input.input_from_text(
        "%PDF-1.7\n1 0 obj << /Encrypt true >> endobj\n%%EOF",
      ),
      "encrypted",
    ),
    (@input.input_from_text("%PDF-1.7\ntruncated"), "truncated"),
  ]
  for fixture in cases {
    let failed = match extract_pdf_native_document(fixture.0) {
      Err(_) => true
      Ok(_) => false
    }
    assert_true(failed, msg="expected controlled PDF failure: " + fixture.1)
  }
}
