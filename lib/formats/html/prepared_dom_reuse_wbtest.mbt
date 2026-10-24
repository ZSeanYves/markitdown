///|
async test "HTML prepared and direct DOM routes keep multiple BOM byte ranges in their once normalized view" {
  for count in [1, 2, 3, 4] {
    let text = "\u{FEFF}".repeat(count) + "<p>Body</p>"
    for byte_input in [false, true] {
      let source = if byte_input {
        @input.input_from_bytes_with_format(
          @utf8.encode(text),
          "bom.html",
          Some(Html),
        )
      } else {
        @input.input_from_text_with_format(text, "bom.html", Some(Html))
      }
      let prepared = @dhtml.prepare_html_document_from_source(source).unwrap()
      assert_eq(
        prepared.normalized_text,
        "\u{FEFF}".repeat(count - 1) + "<p>Body</p>",
      )
      let context = @parser.new_parse_context(Html)
      let reused = html_parse_with_prepared_document(
        prepared.prepared_source,
        context,
        prepared,
      )
      let direct = (html_parser().parse)(source, context).unwrap()
      for result in [reused, direct] {
        let blocks = result.document.unwrap().blocks.filter(block => {
          block.kind == Paragraph && block.text == "Body"
        })
        assert_eq(blocks.length(), 1)
        let location = @core.block_source_ref(blocks[0]).unwrap()
        assert_eq(location.byte_start, Some((count - 1) * 3))
        assert_eq(location.byte_end, Some((count - 1) * 3 + 11))
        assert_eq(location.line_start, Some(1))
        assert_eq(location.line_end, Some(1))
      }
    }
  }
}
