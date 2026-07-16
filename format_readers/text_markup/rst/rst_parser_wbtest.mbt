///|
test "RST facade delegates parsing inspection and inline lowering" {
  let text = "Title\n=====\n\nBody `link <https://example.test>`_."
  let doc = parse_rst_document(text)
  assert_true(inspect_text_markup_document(doc, text).block_count > 0)
  assert_true(
    parse_text_markup_inlines("Body `link <https://example.test>`_", Rst).length() >
    0,
  )
}
