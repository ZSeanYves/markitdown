///|

///|
test "PDF fail-closed diagnostics expose the internal reader boundary" {
  let diagnostics = pdf_native_fail_closed_diagnostics(
    @input.input_from_text_with_format("%PDF-1.4", "blocked.pdf", Some(Pdf)),
    @parser.new_parse_context(Pdf),
  )
  assert_true(
    diagnostics.metrics.get("native_impl_location") ==
    Some("internal/readers/pdf"),
  )
  assert_true(
    diagnostics.metrics.get("pdf_reader_impl") == Some("internal/readers/pdf"),
  )
}

///|
async test "PDF native formats pipeline lowers main contract corpus to IR" {
  let paths = [
    "samples/fixtures/contracts/pdf/hardwrap_en.pdf", "samples/fixtures/contracts/pdf/pdf_header_footer_variants_phase15.pdf",
    "samples/fixtures/contracts/pdf/pdf_metadata_table_like.pdf", "samples/fixtures/contracts/pdf/pdf_metadata_uri_link.pdf",
    "samples/fixtures/contracts/pdf/pdf_ocr_single_page.pdf", "samples/fixtures/contracts/pdf/pdf_ocr_two_page.pdf",
    "samples/fixtures/contracts/pdf/pdf_simple_table_like.pdf", "samples/fixtures/contracts/pdf/root_native_text_baseline.pdf",
    "samples/fixtures/contracts/pdf/text_multipage.pdf", "samples/fixtures/contracts/pdf/text_simple.pdf",
  ]
  let parser = pdf_native_parser()
  let context = @parser.new_parse_context(Pdf)
  for path in paths {
    match (parser.parse)(@input.input_from_path(path), context) {
      Ok(result) => {
        let document = result.document.unwrap()
        assert_true(document.blocks.length() > 0, msg=path)
        if path.contains("pdf_ocr_") {
          assert_true(document.assets.length() > 0, msg=path)
        }
        assert_true(
          result.diagnostics.metrics.get("pdf_native_backend") is Some(_),
        )
      }
      Err(error) => fail(path + ": " + error)
    }
  }
}
