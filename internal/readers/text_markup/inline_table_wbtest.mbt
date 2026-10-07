///|
fn markup_test_block(
  text : String,
  synthetic? : Bool = false,
) -> TextMarkupBlock {
  let meta : Map[String, String] = Map([])
  if synthetic {
    meta.set("synthetic_table", "true")
  }
  {
    kind: Table,
    text,
    level: 0,
    ordered: false,
    line_start: 1,
    line_end: 1,
    meta,
  }
}

///|
test "text markup inline parsers cover links code text and truncation" {
  let rst = parse_text_markup_inlines(
    "prefix ``literal`` `Docs <https://example.test>`_ `code` suffix",
    Rst,
  )
  assert_true(rst.any(item => item.kind == Link))
  assert_true(rst.filter(item => item.kind == Code).length() == 2)
  assert_true(rst.any(item => item.kind == Text))
  let rst_note = parse_text_markup_inlines(
    "See [1]_ and [RFC]_ for details.",
    Rst,
  )
  assert_true(rst_note.any(item => item.href == Some("#1")))
  assert_true(rst_note.any(item => item.href == Some("#RFC")))
  let asciidoc = parse_text_markup_inlines(
    "prefix link:https://example.test[Docs] and `code` suffix",
    Asciidoc,
  )
  assert_true(asciidoc.any(item => item.href == Some("https://example.test")))
  assert_true(asciidoc.any(item => item.kind == Code))
  let tex = parse_text_markup_inlines(
    "prefix \\href{https://example.test}{Docs} and \\texttt{code} suffix",
    Tex,
  )
  assert_true(tex.any(item => item.href == Some("https://example.test")))
  assert_true(tex.any(item => item.kind == Code))
  let tex_refs = parse_text_markup_inlines(
    "See \\url{https://example.test}, \\ref{section-one}, \\cite{paper}, and \\footnote{detail}.",
    Tex,
  )
  assert_true(tex_refs.any(item => item.href == Some("https://example.test")))
  assert_true(tex_refs.any(item => item.href == Some("#section-one")))
  assert_true(tex_refs.any(item => item.text == "[paper]"))
  assert_true(tex_refs.any(item => item.text == "detail"))
  let asciidoc_refs = parse_text_markup_inlines(
    "xref:chapter[Chapter] and <<target,Target>> footnote:[detail]",
    Asciidoc,
  )
  assert_true(asciidoc_refs.any(item => item.href == Some("#chapter")))
  assert_true(asciidoc_refs.any(item => item.href == Some("#target")))
  assert_true(asciidoc_refs.any(item => item.text == "detail"))
  let unmatched = parse_text_markup_inlines("`unterminated", Rst)
  assert_true(unmatched.all(item => item.kind == Text))
  let double_unmatched = parse_text_markup_inlines("``unterminated", Rst)
  assert_true(double_unmatched.any(item => item.kind == Code))
  assert_true(
    parse_text_markup_inlines("`label <url>`", Rst).any(item => {
      item.kind == Code
    }),
  )
  assert_true(
    parse_text_markup_inlines("link:url[unterminated", Asciidoc).all(item => {
      item.kind == Text
    }),
  )
  assert_true(
    parse_text_markup_inlines("\\href{url}{unterminated", Tex).all(item => {
      item.kind == Text
    }),
  )
  assert_true(
    parse_text_markup_inlines("\\texttt{unterminated", Tex).all(item => {
      item.kind == Text
    }),
  )
}

///|
test "text markup inline helper consumers reject invalid offsets" {
  let chars = "abc`code`".to_array()
  assert_true(consume_delimited(chars, 0, '`', '`') is None)
  assert_true(consume_delimited(chars, 3, '`', '`') == Some(("code", 9)))
  assert_true(rst_consume_named_link(chars, 0) is None)
  assert_true(rst_consume_literal(chars, 0) is None)
  assert_true(asciidoc_consume_link("plain".to_array(), 0) is None)
  assert_true(tex_consume_link("plain".to_array(), 0) is None)
  assert_true(tex_consume_inline_code("plain".to_array(), 0) is None)
  assert_true(tex_consume_reference("plain".to_array(), 0) is None)
  assert_true(asciidoc_consume_xref("plain".to_array(), 0) is None)
  assert_true(!chars_match_literal("abc".to_array(), 2, "bc"))
  assert_true(chars_match_literal("abc".to_array(), 1, "bc"))
  let out : Array[TextMarkupInline] = []
  let empty : Array[Char] = []
  flush_inline_text_chars(out, empty)
  assert_eq(out.length(), 0)
}

///|
test "text markup table parsers cover pipe AsciiDoc and TeX layouts" {
  let pipe = parse_text_markup_table(
    markup_test_block("| Name | Value |\n| alpha | one |", synthetic=true),
    Rst,
  ).unwrap()
  assert_true(pipe.header == ["Name", "Value"])
  assert_true(pipe.rows[0] == ["alpha", "one"])
  let rst = parse_text_markup_table(
    markup_test_block("ignored\n| H1 | H2 |\n| A | B |"),
    Rst,
  ).unwrap()
  assert_eq(rst.rows.length(), 1)
  let rst_simple = parse_text_markup_table(
    markup_test_block(
      "==========  ==================\nName        Description\n==========  ==================\nalpha       first value\nbeta        second value\n==========  ==================",
    ),
    Rst,
  ).unwrap()
  assert_true(rst_simple.header == ["Name", "Description"])
  assert_true(rst_simple.rows[0] == ["alpha", "first value"])
  assert_eq(rst_simple.rows.length(), 2)
  let asciidoc = parse_text_markup_table(
    markup_test_block("|Name |Value\n|alpha\n|one\n|beta |two"),
    Asciidoc,
  ).unwrap()
  assert_true(asciidoc.header == ["Name", "Value"])
  assert_eq(asciidoc.rows.length(), 2)
  let tex = parse_text_markup_table(
    markup_test_block(
      "Name & Value \\\\\n\\hline\nalpha & one \\\\\nbeta & two",
    ),
    Tex,
  ).unwrap()
  assert_true(tex.header == ["Name", "Value"])
  assert_eq(tex.rows.length(), 2)
}

///|
test "text markup table parsers fail closed on incomplete structures" {
  for format in [TextMarkupFormat::Rst, Asciidoc, Tex] {
    assert_true(
      parse_text_markup_table(markup_test_block("one row"), format) is None,
    )
  }
  assert_true(parse_pipe_table_literal("| only |") is None)
  assert_true(parse_pipe_row("not pipe").length() == 0)
  assert_true(parse_asciidoc_table_block("| H1 | H2\nignored") is None)
  assert_true(parse_tex_table_block("A & B") is None)
  assert_true(parse_rst_simple_table("=== ===\nonly one row\n=== ===") is None)
}
