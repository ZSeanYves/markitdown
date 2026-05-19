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
  @utf8.decode(bytes, ignore_bom=false) catch {
    _ => fail("utf8 decode failed")
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
    resolve_sample_path("samples/main_process/html/expected/html_link_basic.md"),
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
      "samples/main_process/html/expected/html_link_in_paragraph.md",
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
      "samples/main_process/html/expected/html_link_in_list.md",
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
      "samples/main_process/html/expected/html_link_nested_inline.md",
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
      "samples/main_process/html/expected/html_link_in_table.md",
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
      "samples/main_process/html/expected/html_link_missing_href_negative.md",
    ),
  )
  assert_eq(@cor.emit_markdown(negative_doc), negative_expected)
  match negative_doc.blocks.val[0] {
    @cor.Block::RichParagraph(inlines) => assert_true(!has_any_link(inlines))
    _ => fail("html_link_missing_href_negative should emit RichParagraph")
  }
}

///|
test "html table without explicit header keeps rich table metadata with header_rows=0" {
  let doc = @html.parse_html(
    resolve_sample_path("samples/main_process/html/html_br_table.html"),
    "",
    6,
  )
  match doc.blocks.val[0] {
    @cor.Block::RichTable(table) => {
      assert_eq(table.header_rows, 0)
      assert_eq(table.rows[0][0], "a<br>b")
    }
    _ => fail("html_br_table should emit RichTable with header_rows=0")
  }
}

///|
test "html unsafe links fail closed while safe variants stay links" {
  let safe_doc = @html.parse_html(
    resolve_sample_path("samples/main_process/html/html_links_variants.html"),
    "",
    6,
  )
  let safe_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/html/expected/html_links_variants.md",
    ),
  )
  assert_eq(@cor.emit_markdown(safe_doc), safe_expected)
  match safe_doc.blocks.val[0] {
    @cor.Block::RichParagraph(inlines) =>
      assert_true(has_link(inlines, "Absolute", "https://example.com/abs"))
    _ => fail("expected rich paragraph for absolute link")
  }

  let unsafe_doc = @html.parse_html(
    resolve_sample_path(
      "samples/main_process/html/html_link_unsafe_javascript.html",
    ),
    "",
    6,
  )
  let unsafe_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/html/expected/html_link_unsafe_javascript.md",
    ),
  )
  assert_eq(@cor.emit_markdown(unsafe_doc), unsafe_expected)
  for block in unsafe_doc.blocks.val {
    match block {
      @cor.Block::RichParagraph(inlines) => assert_true(!has_any_link(inlines))
      @cor.Block::Paragraph(_) => ()
      _ => fail("unsafe-link sample should only emit paragraphs")
    }
  }
}

///|
test "html text cleanup does not alter href src alt or title attributes" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)
  let img_dir = dir + "/img"
  ensure_dir_tree(img_dir)

  let sample_path = dir + "/html_attr_cleanup_probe.html"
  let image_path = img_dir + "/test%20asset.png"
  write_utf8_text(image_path, "not-a-real-png-but-good-enough-for-export")
  write_utf8_text(
    sample_path, "<p><a href=\"https://example.com/a?x=1&amp;y=2\">Link&nbsp;ﬁ</a></p>\n<p><img src=\"./img/test%20asset.png?x=1&amp;y=2\" alt=\"Alt&nbsp;ﬁ\" title=\"Title&nbsp;ﬁ\"></p>\n",
  )

  let out_dir = dir + "/out"
  ensure_dir_tree(out_dir)
  let doc = @html.parse_html(sample_path, out_dir, 6)
  let markdown = @cor.emit_markdown(doc)
  assert_true(
    markdown.has_prefix("[Link fi](https://example.com/a?x=1&y=2)\n\n"),
  )
  assert_true(markdown.contains("![Alt ﬁ](assets/image"))
  assert_true(markdown.contains("\n*Title ﬁ*\n"))
  assert_eq(doc.blocks.val.length(), 2)

  match doc.blocks.val[0] {
    @cor.Block::RichParagraph(inlines) =>
      assert_true(has_link(inlines, "Link fi", "https://example.com/a?x=1&y=2"))
    _ => fail("expected first html block to be a rich paragraph with link")
  }

  match doc.blocks.val[1] {
    @cor.Block::ImageBlock(img) => {
      assert_eq(img.alt_text.unwrap_or(""), "Alt ﬁ")
      assert_eq(img.title.unwrap_or(""), "Title ﬁ")
      assert_true(img.path.has_prefix("assets/image"))
      assert_true(img.path.has_suffix(".png"))
    }
    _ => fail("expected exported image block for local html image")
  }
}

///|
test "html unwraps bing click redirect links to canonical targets" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_bing_redirect.html"
  write_utf8_text(
    sample_path,
    "<p><a href=\"https://www.bing.com/ck/a?!&&amp;p=abc&amp;u=a1aHR0cHM6Ly9leGFtcGxlLmNvbS9kb2Nz&amp;ntb=1\">Docs</a></p>\n",
  )

  let doc = @html.parse_html(sample_path, "", 6)
  let markdown = @cor.emit_markdown(doc)
  assert_eq(markdown, "[Docs](https://example.com/docs)\n")

  match doc.blocks.val[0] {
    @cor.Block::RichParagraph(inlines) =>
      assert_true(has_link(inlines, "Docs", "https://example.com/docs"))
    _ => fail("expected rich paragraph for bing redirect sample")
  }
}
