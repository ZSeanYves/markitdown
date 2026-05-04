///|
fn resolve_html_parser_sample_path(path : String) -> String raise {
  if @fs.path_exists(path) {
    return path
  }

  let fallback = "../../../" + path
  if @fs.path_exists(fallback) {
    return fallback
  }

  fail("sample file not found: " + path)
}

///|
fn read_html_parser_utf8_text(path : String) -> String raise {
  let bytes = @fs.read_file_to_bytes(path) catch {
    e => fail("read sample failed: " + e.to_string())
  }
  @cor.utf8_bytes_to_string(bytes) catch {
    e => fail("utf8 decode failed: " + e.to_string())
  }
}

///|
test "html strips utf8 bom and normalizes crlf" {
  let doc = @html.parse_html(
    resolve_html_parser_sample_path(
      "samples/main_process/html/html_bom_utf8.html",
    ),
    "",
    6,
  )
  let expected = read_html_parser_utf8_text(
    resolve_html_parser_sample_path(
      "samples/main_process/expected/html/html_bom_utf8.md",
    ),
  )
  assert_eq(@cor.emit_markdown(doc), expected)
}

///|
test "html keeps current conservative entity and wrapper behavior stable" {
  let entities_doc = @html.parse_html(
    resolve_html_parser_sample_path(
      "samples/main_process/html/html_entities.html",
    ),
    "",
    6,
  )
  let entities_markdown = @cor.emit_markdown(entities_doc)
  assert_true(entities_markdown.contains("Alpha"))
  assert_true(entities_markdown.contains("Beta"))
  assert_true(entities_markdown.contains("&copy;"))
  assert_true(entities_markdown.contains("©"))
  assert_true(entities_markdown.contains("<ok>"))

  let details_doc = @html.parse_html(
    resolve_html_parser_sample_path(
      "samples/main_process/html/html_details_summary.html",
    ),
    "",
    6,
  )
  let details_expected = read_html_parser_utf8_text(
    resolve_html_parser_sample_path(
      "samples/main_process/expected/html/html_details_summary.md",
    ),
  )
  assert_eq(@cor.emit_markdown(details_doc), details_expected)

  let semantic_doc = @html.parse_html(
    resolve_html_parser_sample_path(
      "samples/main_process/html/html_semantic_sectioning.html",
    ),
    "",
    6,
  )
  let semantic_expected = read_html_parser_utf8_text(
    resolve_html_parser_sample_path(
      "samples/main_process/expected/html/html_semantic_sectioning.md",
    ),
  )
  assert_eq(@cor.emit_markdown(semantic_doc), semantic_expected)
}

///|
test "html remote images keep current downgrade policy" {
  let inline_doc = @html.parse_html(
    resolve_html_parser_sample_path(
      "samples/main_process/html/html_remote_image_current_behavior.html",
    ),
    "",
    6,
  )
  let inline_expected = read_html_parser_utf8_text(
    resolve_html_parser_sample_path(
      "samples/main_process/expected/html/html_remote_image_current_behavior.md",
    ),
  )
  assert_eq(@cor.emit_markdown(inline_doc), inline_expected)

  let figure_doc = @html.parse_html(
    resolve_html_parser_sample_path(
      "samples/main_process/html/html_remote_figure_current_behavior.html",
    ),
    "",
    6,
  )
  let figure_expected = read_html_parser_utf8_text(
    resolve_html_parser_sample_path(
      "samples/main_process/expected/html/html_remote_figure_current_behavior.md",
    ),
  )
  assert_eq(
    trim_one_trailing_newline(@cor.emit_markdown(figure_doc)),
    trim_one_trailing_newline(figure_expected),
  )
}

///|
test "html entities decode conservatively and unknown entities stay literal" {
  let entities_doc = @html.parse_html(
    resolve_html_parser_sample_path(
      "samples/main_process/html/html_entities_extended.html",
    ),
    "",
    6,
  )
  let entities_markdown = @cor.emit_markdown(entities_doc)
  assert_true(entities_markdown.contains("A B"))
  assert_true(entities_markdown.contains("&copy;"))
  assert_true(entities_markdown.contains("©"))
  assert_true(entities_markdown.contains("😀"))
  assert_true(entities_markdown.contains("[A & B]"))

  let unknown_doc = @html.parse_html(
    resolve_html_parser_sample_path(
      "samples/main_process/html/html_unknown_entity_literal.html",
    ),
    "",
    6,
  )
  let unknown_expected = read_html_parser_utf8_text(
    resolve_html_parser_sample_path(
      "samples/main_process/expected/html/html_unknown_entity_literal.md",
    ),
  )
  assert_eq(@cor.emit_markdown(unknown_doc), unknown_expected)
}

///|
test "html details summary and script style handling are explicit" {
  let details_doc = @html.parse_html(
    resolve_html_parser_sample_path(
      "samples/main_process/html/html_details_summary.html",
    ),
    "",
    6,
  )
  assert_eq(details_doc.blocks.val.length(), 2)
  match details_doc.blocks.val[0] {
    @cor.Block::RichParagraph(inlines) =>
      match inlines[0] {
        @cor.Inline::Text(text) => assert_eq(text, "Open")
        _ => fail("details summary should start with visible text")
      }
    @cor.Block::Paragraph(text) => assert_eq(text, "Open")
    _ => fail("details summary should emit visible summary text")
  }

  let script_style_doc = @html.parse_html(
    resolve_html_parser_sample_path(
      "samples/main_process/html/html_script_style_ignored.html",
    ),
    "",
    6,
  )
  let script_style_expected = read_html_parser_utf8_text(
    resolve_html_parser_sample_path(
      "samples/main_process/expected/html/html_script_style_ignored.md",
    ),
  )
  assert_eq(@cor.emit_markdown(script_style_doc), script_style_expected)
}

///|
test "html semantic wrappers and table header semantics are stable" {
  let wrappers_doc = @html.parse_html(
    resolve_html_parser_sample_path(
      "samples/main_process/html/html_semantic_wrappers.html",
    ),
    "",
    6,
  )
  let wrappers_expected = read_html_parser_utf8_text(
    resolve_html_parser_sample_path(
      "samples/main_process/expected/html/html_semantic_wrappers.md",
    ),
  )
  assert_eq(@cor.emit_markdown(wrappers_doc), wrappers_expected)

  let thead_doc = @html.parse_html(
    resolve_html_parser_sample_path(
      "samples/main_process/html/html_table_thead_th.html",
    ),
    "",
    6,
  )
  let thead_expected = read_html_parser_utf8_text(
    resolve_html_parser_sample_path(
      "samples/main_process/expected/html/html_table_thead_th.md",
    ),
  )
  assert_eq(@cor.emit_markdown(thead_doc), thead_expected)
  match thead_doc.blocks.val[0] {
    @cor.Block::RichTable(table) => {
      assert_eq(table.header_rows, 1)
      assert_eq(table.rows[0], ["Name", "Score"])
    }
    _ => fail("thead/th table should emit RichTable")
  }

  let body_only_doc = @html.parse_html(
    resolve_html_parser_sample_path(
      "samples/main_process/html/html_br_table.html",
    ),
    "",
    6,
  )
  match body_only_doc.blocks.val[0] {
    @cor.Block::RichTable(table) => {
      assert_eq(table.header_rows, 0)
      assert_eq(table.rows[0][0], "a<br>b")
    }
    _ => fail("body-only table should still emit RichTable")
  }
}

///|
test "html table cells keep entities breaks and pipes stable" {
  let table_doc = @html.parse_html(
    resolve_html_parser_sample_path(
      "samples/main_process/html/html_table_cell_br_entities.html",
    ),
    "",
    6,
  )
  let table_expected = read_html_parser_utf8_text(
    resolve_html_parser_sample_path(
      "samples/main_process/expected/html/html_table_cell_br_entities.md",
    ),
  )
  assert_eq(@cor.emit_markdown(table_doc), table_expected)

  match table_doc.blocks.val[0] {
    @cor.Block::RichTable(table) => {
      assert_eq(table.header_rows, 1)
      assert_eq(table.rows[1][0], "A<br>B")
      assert_eq(table.rows[1][1], "Tom & Jerry")
      assert_eq(table.rows[1][2], "C|D")
    }
    _ => fail("table cell entity sample should emit RichTable")
  }
}

///|
fn trim_one_trailing_newline(text : String) -> String {
  if text.has_suffix("\n") {
    text[:text.length() - 1].to_owned()
  } else {
    text
  }
}
