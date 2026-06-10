///|
test "pdf v2 lowering scaffold consumes parser model without raw scan fallback" {
  let model = @pdfv2.build_empty_pdf_v2_document()
  let lowered = @pdfv2conv.lower_pdf_v2_document_scaffold(model)

  assert_true(lowered.fragments.length() == 0)
  assert_true(!lowered.fallback_used)
  assert_true(!lowered.raw_pdf_scanned_by_convert)
  assert_true(lowered.risks.length() == model.risks.length())
}

///|
test "pdf v2 markdown policy defaults to preserving uncertain text" {
  let policy = @pdfv2conv.default_pdf_v2_markdown_policy()
  assert_true(@pdfv2conv.pdf_v2_policy_keeps_uncertain_text(policy))
}
