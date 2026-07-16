///|
test "TeX parser lowers headings lists environments tables and includes" {
  let text = [
    "\\section{Title}", "Paragraph with \\textbf{bold} and \\href{https://example.test}{link}.",
    "\\begin{itemize}", "\\item First", "\\item Second", "\\end{itemize}", "\\begin{quote}",
    "Quoted body", "\\end{quote}", "\\begin{tabular}{ll}", "Name & Value \\\\", "A & 1 \\\\",
    "\\end{tabular}", "\\input{chapter.tex}", "\\begin{verbatim}", "raw code", "\\end{verbatim}",
  ].join("\n")
  let result = (tex_parser().parse)(
    @input.input_from_text_with_format(text, "complex.tex", Some(Tex)),
    @parser.new_parse_context(Tex),
  ).unwrap()
  assert_true(result.document.unwrap().blocks.length() >= 4)
  assert_true(result.diagnostics.metrics.get("heading_count") != Some("0"))
  assert_true(result.diagnostics.metrics.get("block_count") != Some("0"))
  assert_true(result.diagnostics.pass_trace.contains("parse:tex_parser"))
  assert_true(@fshared.text_markup_parser_capability().supports_document_ir)
}

///|
test "TeX semantic edge cases keep empty environments and local includes readable" {
  let text = [
    "\\input{appendix.tex}", "\\begin{quote}", "\\end{quote}", "\\begin{figure}",
    "\\caption{A retained caption}", "\\end{figure}", "Unknown \\custommacro{visible argument}.",
  ].join("\n")
  let result = (tex_parser().parse)(
    @input.input_from_text_with_format(text, "edge.tex", Some(Tex)),
    @parser.new_parse_context(Tex),
  ).unwrap()
  let blocks = result.document.unwrap().blocks
  assert_true(blocks.any(block => block.text.contains("appendix.tex")))
  assert_true(blocks.any(block => block.text.contains("visible argument")))
  assert_eq(text_markup_environment_body("quote", "quote"), "")
  assert_eq(text_markup_environment_body("quote\nbody", "quote"), "body")
  assert_eq(text_markup_environment_body("body", "quote"), "body")
  assert_eq(text_markup_display_label(""), "")
  assert_eq(text_markup_display_label("  mixed   CASE "), "Mixed Case")
}

///|
test "TeX semantic hooks keep recoverable unknown structure explicit" {
  let source_ref = @core.empty_source_ref()
  let parsed = @dmark.parse_tex_document(
    "\\input{appendix.tex}\n\\begin{futurebox}\nbody\n\\end{futurebox}\nplain",
  )
  let include_blocks = parsed.blocks.filter(block => {
    block.meta.get("semantic_kind") == Some("include")
  })
  let environment_blocks = parsed.blocks.filter(block => {
    block.meta.get("semantic_kind") == Some("environment")
  })
  let plain_blocks = parsed.blocks.filter(block => {
    block.meta.get("semantic_kind") is None && block.text.contains("plain")
  })
  assert_true(include_blocks.length() > 0)
  assert_true(environment_blocks.length() > 0)
  assert_true(plain_blocks.length() > 0)
  let include_source = include_blocks[0]
  let include_block = text_markup_semantic_block(
    include_source, source_ref, "tex",
  ).unwrap()
  assert_eq(include_block.text, "Include: appendix.tex")
  assert_true(include_block.attrs.get("literal") == Some("true"))
  let raw_include = text_markup_semantic_raw_block(
    include_source, source_ref, "tex",
  ).unwrap()
  assert_eq(raw_include.text, "Include: appendix.tex")

  let environment = environment_blocks[0]
  let environment_block = text_markup_semantic_block(
    environment, source_ref, "tex",
  ).unwrap()
  assert_true(environment_block.text.contains("Environment: Futurebox"))
  assert_true(environment_block.text.contains("body"))
  let raw_environment = text_markup_semantic_raw_block(
    environment, source_ref, "tex",
  ).unwrap()
  assert_true(raw_environment.text.contains("Environment: Futurebox"))
  assert_true(
    text_markup_semantic_quote_text(environment, "tex").contains("body"),
  )

  let plain = plain_blocks[0]
  assert_eq(text_markup_semantic_quote_text(plain, "tex"), "plain")
  assert_true(text_markup_semantic_block(plain, source_ref, "tex") is None)
  assert_true(text_markup_semantic_raw_block(plain, source_ref, "tex") is None)
  plain.meta.set("semantic_kind", "future")
  assert_true(text_markup_semantic_block(plain, source_ref, "tex") is None)

  let empty_environment = @dmark.parse_tex_document(
      "\\begin{futurebox}\n\\end{futurebox}",
    ).blocks[0]
  assert_eq(
    text_markup_semantic_block(empty_environment, source_ref, "tex").unwrap().text,
    "Environment: Futurebox",
  )
  assert_eq(
    text_markup_semantic_raw_block(empty_environment, source_ref, "tex").unwrap().text,
    "Environment: Futurebox",
  )
}

///|
test "TeX malformed unclosed environment degrades under control" {
  let parsed = @dmark.parse_tex_document("\\begin{quote}\nvisible body")
  assert_true(parsed.blocks.length() > 0)
  assert_true(parsed.blocks.any(block => block.text.contains("visible body")))
}

///|
test "TeX nested ordered and unordered lists retain every item" {
  let parsed = @dmark.parse_tex_document(
    "\\begin{enumerate}\n\\item one\n\\begin{itemize}\n\\item nested\n\\end{itemize}\n\\item two\n\\end{enumerate}",
  )
  let joined = parsed.blocks.map(block => block.text).join("\n")
  assert_true(joined.contains("one"))
  assert_true(joined.contains("nested"))
  assert_true(joined.contains("two"))
}

///|
test "TeX footnote label ref and citation stay readable" {
  let parsed = @dmark.parse_tex_document(
    "Body\\footnote{note text} \\label{sec:a} \\ref{sec:a} \\cite{paper}.",
  )
  let joined = parsed.blocks.map(block => block.text).join("\n")
  assert_true(joined.contains("note text"))
  assert_true(joined.contains("sec:a"))
  assert_true(joined.contains("paper"))
}

///|
test "TeX figure caption and link commands preserve visible arguments" {
  let parsed = @dmark.parse_tex_document(
    "\\begin{figure}\n\\caption{Visible caption}\n\\end{figure}\n\\url{https://example.test/a}\n\\href{https://example.test/b}{Visible link}",
  )
  let joined = parsed.blocks.map(block => block.text).join("\n")
  assert_true(joined.contains("Visible caption"))
  assert_true(joined.contains("https://example.test/a"))
  assert_true(joined.contains("Visible link"))
}

///|
test "TeX inline display math and verbatim remain literal" {
  let parsed = @dmark.parse_tex_document(
    "Inline $x+y$ and \\[z^2\\].\n\\begin{verbatim}\nraw <tag> & value\n\\end{verbatim}",
  )
  let joined = parsed.blocks.map(block => block.text).join("\n")
  assert_true(joined.contains("x+y"))
  assert_true(joined.contains("z^2"))
  assert_true(joined.contains("raw <tag> & value"))
}

///|
test "TeX unknown macro preserves readable argument" {
  let parsed = @dmark.parse_tex_document(
    "before \\futuremacro{kept argument} after",
  )
  let joined = parsed.blocks.map(block => block.text).join("\n")
  assert_true(joined.contains("kept argument"))
}

///|
test "TeX table rows retain cells and caption context" {
  let parsed = @dmark.parse_tex_document(
    "\\begin{table}\n\\caption{Numbers}\n\\begin{tabular}{ll}\nA & 1 \\\\nB & 2 \\\\n\\end{tabular}\n\\end{table}",
  )
  let joined = parsed.blocks.map(block => block.text).join("\n")
  assert_true(joined.contains("Numbers"))
  assert_true(joined.contains("A"))
  assert_true(joined.contains("2"))
}

///|
test "TeX parser exports includegraphics as a sidecar asset" {
  let result = (tex_parser().parse)(
    @input.input_from_text_with_format(
      "\\includegraphics[width=4cm]{figure.png}",
      "image.tex",
      Some(Tex),
    ),
    @parser.new_parse_context(Tex),
  ).unwrap()
  let images = result.document.unwrap().blocks.filter(block => {
    block.kind == Image
  })
  assert_eq(images.length(), 1)
  let image = images[0]
  assert_true(image.attrs.get("path") == Some("assets/tex-figure.png"))
  assert_true(image.attrs.get("source_path") == Some("figure.png"))
}
