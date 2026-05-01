///|
fn resolve_sample_path(path : String) -> String raise {
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
fn read_utf8_text(path : String) -> String raise {
  let bytes = @fs.read_file_to_bytes(path) catch {
    e => fail("read sample failed: " + e.to_string())
  }
  @cor.utf8_bytes_to_string(bytes) catch {
    e => fail("utf8 decode failed: " + e.to_string())
  }
}

///|
fn has_link(xs : Array[@cor.Inline], text : String, href : String) -> Bool {
  for x in xs {
    match x {
      @cor.Inline::Link(t, h) => if t == text && h == href { return true }
      _ => ()
    }
  }
  false
}

///|
fn has_any_link(xs : Array[@cor.Inline]) -> Bool {
  for x in xs {
    match x {
      @cor.Inline::Link(_, _) => return true
      _ => ()
    }
  }
  false
}

///|
test "html links are preserved in rich paragraph inlines" {
  let basic_doc = @html.parse_html(
    resolve_sample_path("samples/main_process/html/html_link_basic.html"),
    "",
    6,
  )
  let basic_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/expected/html/html_link_basic.md"),
  )
  assert_eq(@cor.emit_markdown(basic_doc), basic_expected)
  match basic_doc.blocks.val[0] {
    @cor.Block::RichParagraph(inlines) =>
      assert_true(has_link(inlines, "Basic link", "https://example.com/basic"))
    _ => fail("html_link_basic should emit RichParagraph")
  }

  let paragraph_doc = @html.parse_html(
    resolve_sample_path("samples/main_process/html/html_link_in_paragraph.html"),
    "",
    6,
  )
  let paragraph_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/html/html_link_in_paragraph.md",
    ),
  )
  assert_eq(@cor.emit_markdown(paragraph_doc), paragraph_expected)
  match paragraph_doc.blocks.val[0] {
    @cor.Block::RichParagraph(inlines) =>
      assert_true(
        has_link(inlines, "the docs", "https://example.com/paragraph"),
      )
    _ => fail("html_link_in_paragraph should emit RichParagraph")
  }
}

///|
test "html links are preserved in list items and nested inline text" {
  let list_doc = @html.parse_html(
    resolve_sample_path("samples/main_process/html/html_link_in_list.html"),
    "",
    6,
  )
  let list_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/html/html_link_in_list.md",
    ),
  )
  assert_eq(@cor.emit_markdown(list_doc), list_expected)
  match list_doc.blocks.val[0] {
    @cor.Block::RichListItem(false, 0, inlines) =>
      assert_true(
        has_link(inlines, "the list docs", "https://example.com/list"),
      )
    _ => fail("html_link_in_list should emit RichListItem")
  }

  let nested_doc = @html.parse_html(
    resolve_sample_path(
      "samples/main_process/html/html_link_nested_inline.html",
    ),
    "",
    6,
  )
  let nested_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/html/html_link_nested_inline.md",
    ),
  )
  assert_eq(@cor.emit_markdown(nested_doc), nested_expected)
  match nested_doc.blocks.val[0] {
    @cor.Block::RichParagraph(inlines) =>
      assert_true(
        has_link(inlines, "nested docs", "https://example.com/nested"),
      )
    _ => fail("html_link_nested_inline should emit RichParagraph")
  }
}

///|
test "html table cell links render and missing href stays plain text" {
  let table_doc = @html.parse_html(
    resolve_sample_path("samples/main_process/html/html_link_in_table.html"),
    "",
    6,
  )
  let table_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/html/html_link_in_table.md",
    ),
  )
  assert_eq(@cor.emit_markdown(table_doc), table_expected)
  match table_doc.blocks.val[0] {
    @cor.Block::RichTable(table) => {
      assert_eq(table.header_rows, 1)
      let rows = table.rows
      assert_eq(rows[1][1], "[Open docs](https://example.com/table)")
    }
    _ => fail("html_link_in_table should emit RichTable")
  }

  let negative_doc = @html.parse_html(
    resolve_sample_path(
      "samples/main_process/html/html_link_missing_href_negative.html",
    ),
    "",
    6,
  )
  let negative_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/html/html_link_missing_href_negative.md",
    ),
  )
  assert_eq(@cor.emit_markdown(negative_doc), negative_expected)
  match negative_doc.blocks.val[0] {
    @cor.Block::RichParagraph(inlines) => assert_true(!has_any_link(inlines))
    _ => fail("html_link_missing_href_negative should emit RichParagraph")
  }
}

///|
test "html table without explicit header keeps legacy table" {
  let doc = @html.parse_html(
    resolve_sample_path("samples/main_process/html/html_br_table.html"),
    "",
    6,
  )
  match doc.blocks.val[0] {
    @cor.Block::Table(rows) => assert_eq(rows[0][0], "a<br>b")
    _ => fail("html_br_table should keep legacy Table without th or thead")
  }
}
