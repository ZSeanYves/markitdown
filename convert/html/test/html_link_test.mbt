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
fn has_note_ref(
  xs : Array[@cor.Inline],
  note_id : String,
  marker : String,
  source_kind : @cor.NoteSourceKind,
) -> Bool {
  for x in xs {
    match x {
      @cor.Inline::NoteRef(note) =>
        if note.note_id == note_id &&
          note.marker == marker &&
          note.source_kind == source_kind {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn has_any_note_ref(xs : Array[@cor.Inline]) -> Bool {
  for x in xs {
    match x {
      @cor.Inline::NoteRef(_) => return true
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
test "html shared parser primitives keep tricky attributes stable" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)
  let img_dir = dir + "/img"
  ensure_dir_tree(img_dir)

  let sample_path = dir + "/html_shared_primitive_attrs.html"
  let image_path = img_dir + "/test%20asset.png"
  write_utf8_text(image_path, "not-a-real-png-but-good-enough-for-export")
  write_utf8_text(
    sample_path, "<main><p><a data-href=\"https://wrong.example/\" href='https://example.com/a?x=1&amp;y=2'>A&nbsp;&#169;</a></p><p><img data-src=\"missing.png\" src='img/test%20asset.png?cache=1&amp;size=2' alt='Alt&nbsp;&#169;' title='Title &amp; More'></p></main>\n",
  )

  let out_dir = dir + "/shared-out"
  ensure_dir_tree(out_dir)
  let doc = @html.parse_html(sample_path, out_dir, 6)
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.has_prefix("[A ©](https://example.com/a?x=1&y=2)\n\n"))
  assert_true(!markdown.contains("wrong.example"))
  assert_true(markdown.contains("![Alt ©](assets/image"))
  assert_true(markdown.contains("\n*Title & More*\n"))

  match doc.blocks.val[0] {
    @cor.Block::RichParagraph(inlines) =>
      assert_true(has_link(inlines, "A ©", "https://example.com/a?x=1&y=2"))
    _ => fail("expected first block to be a rich paragraph with link")
  }
  match doc.blocks.val[1] {
    @cor.Block::ImageBlock(img) => {
      assert_eq(img.alt_text.unwrap_or(""), "Alt ©")
      assert_eq(img.title.unwrap_or(""), "Title & More")
      assert_true(img.path.has_prefix("assets/image"))
    }
    _ => fail("expected second block to be an exported image")
  }
}

///|
test "html unwraps bing click redirect links to canonical targets" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_bing_redirect.html"
  write_utf8_text(
    sample_path, "<p><a href=\"https://www.bing.com/ck/a?!&&amp;p=abc&amp;u=a1aHR0cHM6Ly9leGFtcGxlLmNvbS9kb2Nz&amp;ntb=1\">Docs</a></p>\n",
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

///|
test "html explicit epub noteref emits note ir and suppresses body" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_epub_noteref.html"
  write_utf8_text(
    sample_path, "<html><body><p>Text<a epub:type=\"noteref\" href=\"#fn1\">1</a>.</p><aside epub:type=\"footnote\" id=\"fn1\">Footnote body.</aside></body></html>\n",
  )

  let doc = @html.parse_html(sample_path, "", 6)
  assert_eq(@cor.emit_markdown(doc), "Text[^fn1].\n\n[^fn1]: Footnote body.\n")
  assert_eq(doc.blocks.val.length(), 1)
  assert_eq(doc.note_definitions.val.length(), 1)

  match doc.blocks.val[0] {
    @cor.Block::RichParagraph(inlines) =>
      assert_true(
        has_note_ref(inlines, "fn1", "1", @cor.NoteSourceKind::HtmlNoteRef),
      )
    _ => fail("explicit noteref should stay in a rich paragraph")
  }

  let note = doc.note_definitions.val[0]
  assert_eq(note.note_id, "fn1")
  assert_eq(note.marker, "1")
  assert_true(note.source_kind == @cor.NoteSourceKind::HtmlFootnoteBody)
  match note.blocks[0] {
    @cor.Block::Paragraph(text) => assert_eq(text, "Footnote body.")
    _ => fail("html note definition should keep body text")
  }
}

///|
test "html role noteref variant emits resolved note definition" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_role_noteref.html"
  write_utf8_text(
    sample_path, "<html><body><p>Role<a role=\"doc-noteref\" href=\"#note-a\">a</a>.</p><section role=\"doc-footnote\" id=\"note-a\">Role body.</section></body></html>\n",
  )

  let doc = @html.parse_html(sample_path, "", 6)
  assert_eq(
    @cor.emit_markdown(doc),
    "Role[^note-a].\n\n[^note-a]: Role body.\n",
  )
  assert_eq(doc.blocks.val.length(), 1)
  assert_eq(doc.note_definitions.val.length(), 1)
  match doc.blocks.val[0] {
    @cor.Block::RichParagraph(inlines) =>
      assert_true(
        has_note_ref(inlines, "note-a", "a", @cor.NoteSourceKind::HtmlNoteRef),
      )
    _ => fail("role noteref should stay in a rich paragraph")
  }
}

///|
test "html explicit noteref suppresses li note body targets" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_li_noteref.html"
  write_utf8_text(
    sample_path, "<html><body><p>Item<a epub:type=\"noteref\" href=\"#fn-li\">li</a>.</p><ol><li id=\"fn-li\" epub:type=\"footnote\">List note body.</li></ol></body></html>\n",
  )

  let doc = @html.parse_html(sample_path, "", 6)
  assert_eq(
    @cor.emit_markdown(doc),
    "Item[^fn-li].\n\n[^fn-li]: List note body.\n",
  )
  assert_eq(doc.blocks.val.length(), 1)
  assert_eq(doc.note_definitions.val.length(), 1)
}

///|
test "html plain sup normal anchors and missing noteref targets stay non-note" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_non_note_links.html"
  write_utf8_text(
    sample_path, "<html><body><p>Plain<sup>1</sup> <a href=\"#section1\">go</a> <a epub:type=\"noteref\" href=\"#missing\">2</a>.</p><section id=\"section1\">Section body.</section></body></html>\n",
  )

  let doc = @html.parse_html(sample_path, "", 6)
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("Plain1 [go](#section1) [2](#missing)."))
  assert_eq(doc.note_definitions.val.length(), 0)
  match doc.blocks.val[0] {
    @cor.Block::RichParagraph(inlines) => {
      assert_true(has_link(inlines, "go", "#section1"))
      assert_true(has_link(inlines, "2", "#missing"))
      assert_true(!has_any_note_ref(inlines))
    }
    _ => fail("non-note anchor sample should stay a rich paragraph")
  }
}
