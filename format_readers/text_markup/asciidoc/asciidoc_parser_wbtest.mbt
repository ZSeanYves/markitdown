///|
test "AsciiDoc facade delegates parsing inspection and inline lowering" {
  let text = "= Title\n\nBody https://example.test[link]."
  let doc = parse_asciidoc_document(text)
  assert_true(inspect_text_markup_document(doc, text).block_count > 0)
  assert_true(
    parse_text_markup_inlines(
      "Body https://example.test[link]",
      TextMarkupFormat::Asciidoc,
    ).length() >
    0,
  )
}
