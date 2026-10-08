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
test "PDF native formats pipeline lowers main contract corpus to IR" {
  let paths = [
    "samples/fixtures/contracts/pdf/hardwrap_en.pdf", "samples/fixtures/contracts/pdf/pdf_header_footer_variants_phase15.pdf",
    "samples/fixtures/contracts/pdf/pdf_metadata_table_like.pdf", "samples/fixtures/contracts/pdf/pdf_metadata_uri_link.pdf",
    "samples/fixtures/contracts/pdf/pdf_ocr_single_page.pdf", "samples/fixtures/contracts/pdf/pdf_ocr_two_page.pdf",
    "samples/fixtures/contracts/pdf/pdf_simple_table_like.pdf", "samples/fixtures/contracts/pdf/root_native_text_baseline.pdf",
    "samples/fixtures/contracts/pdf/text_multipage.pdf", "samples/fixtures/contracts/pdf/text_simple.pdf",
  ]
  let parser = pdf_native_parser()
  let context = @parser.new_parse_context(Pdf)
  let mut succeeded = 0
  let mut failed = 0
  let mut blocks = 0
  let mut assets = 0
  for path in paths {
    match (parser.parse)(@input.input_from_path(path), context) {
      Ok(result) => {
        succeeded += 1
        let document = result.document.unwrap()
        blocks += document.blocks.length()
        assets += document.assets.length()
        assert_true(
          result.diagnostics.metrics.get("pdf_native_backend") is Some(_),
        )
      }
      Err(error) => {
        failed += 1
        assert_true(error != "")
      }
    }
  }
  assert_true(succeeded >= 8)
  assert_true(blocks > 0)
  assert_true(assets >= 0)
  assert_eq(succeeded + failed, paths.length())
}
