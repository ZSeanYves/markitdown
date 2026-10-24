///|
async test "opaque PDF session borrows a live input owner and extracts once" {
  let source = @input.input_from_path_with_format(
    "samples/fixtures/contracts/pdf/text_simple.pdf",
    Some(Pdf),
  )
  let owner = @input.begin_input_session(source)
  let session = @pdf.open_pdf_native_session(owner.source).unwrap()
  let facts = @pdf.pdf_structural_facts(session)
  assert_eq(facts.page_count, Some(1))
  assert_true(!facts.deferred_repair)
  let document = @pdf.extract_pdf_native_document_from_session(session).unwrap()
  assert_eq(document.pages.length(), 1)
  assert_true(
    @pdf.extract_pdf_native_document_from_session(session)
    is Err(ParseFailed(_)),
  )
  @input.end_input_session(owner)
  assert_true(
    @pdf.extract_pdf_native_document_from_session(session) is Err(ReadFailed(_)),
  )
}
