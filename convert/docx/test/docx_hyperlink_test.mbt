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
fn has_docx_list_block(
  doc : @cor.Document,
  ordered : Bool,
  level : Int,
) -> Bool {
  for block in doc.blocks.val {
    match block {
      @cor.Block::ListItem(v_ordered, v_level, _) =>
        if v_ordered == ordered && v_level == level {
          return true
        }
      @cor.Block::RichListItem(v_ordered, v_level, _) =>
        if v_ordered == ordered && v_level == level {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn ensure_dir(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    @fs.create_dir(path)
  }
}

///|
fn ensure_dir_tree(path : String) -> Unit raise {
  let trimmed = path.trim()
  if trimmed == "" {
    return
  }

  let chars = trimmed.to_array()
  let mut current = if chars.length() > 0 && chars[0] == '/' { "/" } else { "" }
  let part : Array[Char] = []

  fn flush(part : Array[Char], current : String) -> String raise {
    if part.length() == 0 {
      return current
    }

    let segment = String::from_array(part)
    part.clear()
    let next = if current == "" || current == "/" {
      current + segment
    } else {
      current + "/" + segment
    }
    ensure_dir(next)
    next
  }

  for ch in chars {
    if ch == '/' {
      current = flush(part, current)
    } else {
      part.push(ch)
    }
  }

  ignore(flush(part, current))
}

///|
fn remove_dir_recursive(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    return
  }

  for name in @fs.read_dir(path) {
    let child = path + "/" + name
    if @fs.is_dir(child) {
      remove_dir_recursive(child)
    } else if @fs.is_file(child) {
      @fs.remove_file(child)
    }
  }

  @fs.remove_dir(path)
}

///|
fn recreate_clean_dir(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    remove_dir_recursive(path)
  }
  @fs.create_dir(path)
}

///|
fn test_tmp_root() -> String {
  ".tmp"
}

///|
fn docx_test_out_dir(name : String) -> String raise {
  ensure_dir_tree(test_tmp_root())
  let root = test_tmp_root() + "/docx"
  ensure_dir(root)
  let dir = root + "/" + name
  recreate_clean_dir(dir)
  dir
}

///|
test "docx hyperlink basic and paragraph preservation" {
  let basic_out = docx_test_out_dir("link_basic")
  let basic_doc = @doc.parse_docx(
    resolve_sample_path("samples/main_process/docx/docx_link_basic.docx"),
    basic_out,
    6,
  )
  let basic_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/expected/docx/docx_link_basic.md"),
  )
  assert_eq(@cor.emit_markdown(basic_doc), basic_expected)
  match basic_doc.blocks.val[0] {
    @cor.Block::RichParagraph(inlines) =>
      assert_true(has_link(inlines, "OpenAI", "https://openai.com"))
    _ => fail("docx_link_basic should emit RichParagraph")
  }

  let para_out = docx_test_out_dir("link_in_paragraph")
  let para_doc = @doc.parse_docx(
    resolve_sample_path("samples/main_process/docx/docx_link_in_paragraph.docx"),
    para_out,
    6,
  )
  let para_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/docx/docx_link_in_paragraph.md",
    ),
  )
  assert_eq(@cor.emit_markdown(para_doc), para_expected)
  match para_doc.blocks.val[0] {
    @cor.Block::RichParagraph(inlines) =>
      assert_true(has_link(inlines, "OpenAI", "https://openai.com"))
    _ => fail("docx_link_in_paragraph should emit RichParagraph")
  }
}

///|
test "docx hyperlink merges multiple runs and missing rel degrades to text" {
  let multi_out = docx_test_out_dir("link_multiple_runs")
  let multi_doc = @doc.parse_docx(
    resolve_sample_path(
      "samples/main_process/docx/docx_link_multiple_runs.docx",
    ),
    multi_out,
    6,
  )
  let multi_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/docx/docx_link_multiple_runs.md",
    ),
  )
  assert_eq(@cor.emit_markdown(multi_doc), multi_expected)
  match multi_doc.blocks.val[0] {
    @cor.Block::RichParagraph(inlines) =>
      assert_true(has_link(inlines, "OpenAI Docs", "https://openai.com/docs"))
    _ => fail("docx_link_multiple_runs should emit RichParagraph")
  }

  let negative_out = docx_test_out_dir("link_missing_rel_negative")
  let negative_doc = @doc.parse_docx(
    resolve_sample_path(
      "samples/main_process/docx/docx_link_missing_rel_negative.docx",
    ),
    negative_out,
    6,
  )
  let negative_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/docx/docx_link_missing_rel_negative.md",
    ),
  )
  assert_eq(@cor.emit_markdown(negative_doc), negative_expected)
  match negative_doc.blocks.val[0] {
    @cor.Block::RichParagraph(inlines) => assert_true(!has_any_link(inlines))
    _ => fail("docx_link_missing_rel_negative should emit RichParagraph")
  }
}

///|
test "docx list and table samples keep stable markdown while exposing richer IR" {
  let list_out = docx_test_out_dir("list_nested")
  let list_doc = @doc.parse_docx(
    resolve_sample_path("samples/main_process/docx/docx_list_nested.docx"),
    list_out,
    6,
  )
  let list_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/docx/docx_list_nested.md",
    ),
  )
  assert_eq(@cor.emit_markdown(list_doc), list_expected)
  assert_true(has_docx_list_block(list_doc, false, 0))
  assert_true(has_docx_list_block(list_doc, false, 1))

  let table_out = docx_test_out_dir("table_multiline_cell")
  let table_doc = @doc.parse_docx(
    resolve_sample_path(
      "samples/main_process/docx/docx_table_multiline_cell.docx",
    ),
    table_out,
    6,
  )
  let table_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/docx/docx_table_multiline_cell.md",
    ),
  )
  assert_eq(@cor.emit_markdown(table_doc), table_expected)
  match table_doc.blocks.val[0] {
    @cor.Block::RichTable(table) => {
      assert_eq(table.header_rows, 1)
      assert_eq(table.rows[0][0], "Col A")
      assert_eq(table.rows[1][0], "Line 1\nLine 2")
    }
    _ => fail("docx_table_multiline_cell should emit RichTable")
  }
}

///|
test "docx footnotes endnotes and comments append conservative sections" {
  let footnote_out = docx_test_out_dir("footnote_basic")
  let footnote_doc = @doc.parse_docx(
    resolve_sample_path("samples/main_process/docx/docx_footnote_basic.docx"),
    footnote_out,
    6,
  )
  let footnote_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/docx/docx_footnote_basic.md",
    ),
  )
  assert_eq(@cor.emit_markdown(footnote_doc), footnote_expected)

  let endnote_out = docx_test_out_dir("endnote_basic")
  let endnote_doc = @doc.parse_docx(
    resolve_sample_path("samples/main_process/docx/docx_endnote_basic.docx"),
    endnote_out,
    6,
  )
  let endnote_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/docx/docx_endnote_basic.md",
    ),
  )
  assert_eq(@cor.emit_markdown(endnote_doc), endnote_expected)

  let comment_out = docx_test_out_dir("comment_basic")
  let comment_doc = @doc.parse_docx(
    resolve_sample_path("samples/main_process/docx/docx_comment_basic.docx"),
    comment_out,
    6,
  )
  let comment_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/docx/docx_comment_basic.md",
    ),
  )
  assert_eq(@cor.emit_markdown(comment_doc), comment_expected)

  let multi_out = docx_test_out_dir("multiple_notes_order")
  let multi_doc = @doc.parse_docx(
    resolve_sample_path(
      "samples/main_process/docx/docx_multiple_notes_order.docx",
    ),
    multi_out,
    6,
  )
  let multi_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/docx/docx_multiple_notes_order.md",
    ),
  )
  let multi_markdown = @cor.emit_markdown(multi_doc)
  assert_eq(multi_markdown, multi_expected)
  assert_true(multi_markdown.contains("## Footnotes"))
  assert_true(multi_markdown.contains("## Endnotes"))
  assert_true(multi_markdown.contains("## Comments"))
}

///|
test "docx headers and footers append conservative sections while skipping page-only noise" {
  let header_out = docx_test_out_dir("header_basic")
  let header_doc = @doc.parse_docx(
    resolve_sample_path("samples/main_process/docx/docx_header_basic.docx"),
    header_out,
    6,
  )
  let header_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/docx/docx_header_basic.md",
    ),
  )
  assert_eq(@cor.emit_markdown(header_doc), header_expected)

  let footer_out = docx_test_out_dir("footer_basic")
  let footer_doc = @doc.parse_docx(
    resolve_sample_path("samples/main_process/docx/docx_footer_basic.docx"),
    footer_out,
    6,
  )
  let footer_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/docx/docx_footer_basic.md",
    ),
  )
  assert_eq(@cor.emit_markdown(footer_doc), footer_expected)

  let page_out = docx_test_out_dir("page_number_footer_current_policy")
  let page_doc = @doc.parse_docx(
    resolve_sample_path(
      "samples/main_process/docx/docx_page_number_footer_current_policy.docx",
    ),
    page_out,
    6,
  )
  let page_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/docx/docx_page_number_footer_current_policy.md",
    ),
  )
  let page_markdown = @cor.emit_markdown(page_doc)
  assert_eq(page_markdown, page_expected)
  assert_true(!page_markdown.contains("## Footers"))

  let dedup_out = docx_test_out_dir("header_footer_dedup")
  let dedup_doc = @doc.parse_docx(
    resolve_sample_path(
      "samples/main_process/docx/docx_header_footer_dedup.docx",
    ),
    dedup_out,
    6,
  )
  let dedup_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/docx/docx_header_footer_dedup.md",
    ),
  )
  let dedup_markdown = @cor.emit_markdown(dedup_doc)
  assert_eq(dedup_markdown, dedup_expected)
  assert_true(dedup_markdown.contains("### Header 1 Default"))
  assert_true(dedup_markdown.contains("### Footer 2 Even"))
  assert_eq(dedup_markdown.split("Shared Header").collect().length(), 2)
}

///|
test "docx text boxes append conservative section without duplicating body text" {
  let basic_out = docx_test_out_dir("textbox_basic")
  let basic_doc = @doc.parse_docx(
    resolve_sample_path("samples/main_process/docx/docx_textbox_basic.docx"),
    basic_out,
    6,
  )
  let basic_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/docx/docx_textbox_basic.md",
    ),
  )
  let basic_markdown = @cor.emit_markdown(basic_doc)
  assert_eq(basic_markdown, basic_expected)
  assert_eq(basic_markdown.split("Text box body.").collect().length(), 2)

  let multiline_out = docx_test_out_dir("textbox_multiline")
  let multiline_doc = @doc.parse_docx(
    resolve_sample_path("samples/main_process/docx/docx_textbox_multiline.docx"),
    multiline_out,
    6,
  )
  let multiline_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/docx/docx_textbox_multiline.md",
    ),
  )
  assert_eq(@cor.emit_markdown(multiline_doc), multiline_expected)

  let link_out = docx_test_out_dir("textbox_with_link")
  let link_doc = @doc.parse_docx(
    resolve_sample_path("samples/main_process/docx/docx_textbox_with_link.docx"),
    link_out,
    6,
  )
  let link_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/docx/docx_textbox_with_link.md",
    ),
  )
  let link_markdown = @cor.emit_markdown(link_doc)
  assert_eq(link_markdown, link_expected)
  assert_true(link_markdown.contains("[OpenAI Docs](https://openai.com/docs)"))

  let table_out = docx_test_out_dir("textbox_in_table")
  let table_doc = @doc.parse_docx(
    resolve_sample_path("samples/main_process/docx/docx_textbox_in_table.docx"),
    table_out,
    6,
  )
  let table_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/docx/docx_textbox_in_table.md",
    ),
  )
  assert_eq(@cor.emit_markdown(table_doc), table_expected)

  let empty_out = docx_test_out_dir("textbox_empty_current_policy")
  let empty_doc = @doc.parse_docx(
    resolve_sample_path(
      "samples/main_process/docx/docx_textbox_empty_current_policy.docx",
    ),
    empty_out,
    6,
  )
  let empty_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/docx/docx_textbox_empty_current_policy.md",
    ),
  )
  let empty_markdown = @cor.emit_markdown(empty_doc)
  assert_eq(empty_markdown, empty_expected)
  assert_true(!empty_markdown.contains("## Text Boxes"))
}
