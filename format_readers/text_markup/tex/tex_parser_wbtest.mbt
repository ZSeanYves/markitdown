///|
test "TeX facade delegates parsing inspection and inline lowering" {
  let text = "\\section{Title}\nBody \\href{/x}{link}"
  let doc = parse_tex_document(text)
  assert_true(inspect_text_markup_document(doc, text).block_count > 0)
  assert_true(
    parse_text_markup_inlines("Body \\href{/x}{link}", Tex).length() > 0,
  )
  assert_true(
    prepare_tex_document_from_source(
      @input.input_from_text_with_format(text, "facade.tex", Some(Tex)),
    )
    is Ok(_),
  )
}
