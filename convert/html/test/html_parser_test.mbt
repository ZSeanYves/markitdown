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
  @utf8.decode(bytes, ignore_bom=false) catch {
    _ => fail("utf8 decode failed")
  }
}

///|
fn test_tmp_root() -> String {
  ".tmp/convert-html-test"
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
    if !@fs.path_exists(next) {
      @fs.create_dir(next)
    }
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
fn write_utf8_text(path : String, text : String) -> Unit raise {
  @fs.write_string_to_file(path, text, encoding="utf8") catch {
    e => fail("write sample failed: " + e.to_string())
  }
}

///|
fn restore_env_var(name : String, previous : String?) -> Unit {
  match previous {
    Some(value) => @sys.set_env_var(name, value)
    None => @sys.unset_env_var(name)
  }
}

///|
fn remove_file_if_exists(path : String) -> Unit {
  if @fs.path_exists(path) {
    @fs.remove_file(path) catch {
      _ => ()
    }
  }
}

///|
fn html_profile_counter(report : String, name : String) -> Int raise {
  let needle = name + "="
  for raw_token in report.split(" ") {
    let token = raw_token.to_owned().trim().to_owned()
    if token.has_prefix(needle) {
      return parse_html_profile_counter_digits(
        token[needle.length():].to_owned(),
      )
    }
  }
  fail("missing html profile counter: " + name)
}

///|
fn html_profile_has_stage(report : String, stage : String) -> Bool {
  report.contains("stage=" + stage + " ")
}

///|
fn parse_html_profile_counter_digits(raw : String) -> Int raise {
  let mut value = 0
  let mut saw_digit = false
  for ch in raw {
    let code = ch.to_int()
    if code >= '0'.to_int() && code <= '9'.to_int() {
      value = value * 10 + (code - '0'.to_int())
      saw_digit = true
    } else {
      break
    }
  }
  if !saw_digit {
    fail("invalid html profile counter value: " + raw)
  }
  value
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
      "samples/main_process/html/expected/html_bom_utf8.md",
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
      "samples/main_process/html/expected/html_details_summary.md",
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
      "samples/main_process/html/expected/html_semantic_sectioning.md",
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
      "samples/main_process/html/expected/html_remote_image_current_behavior.md",
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
      "samples/main_process/html/expected/html_remote_figure_current_behavior.md",
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
      "samples/main_process/html/expected/html_unknown_entity_literal.md",
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
      "samples/main_process/html/expected/html_script_style_ignored.md",
    ),
  )
  assert_eq(@cor.emit_markdown(script_style_doc), script_style_expected)
}

///|
test "html parser validation summary is available for convert integration" {
  let summary = @html.collect_html_parser_issue_summary_from_text(
    "<html><body><script>bad()</script><style>.x{}</style><a href='javascript:bad'>x</a><div class='a' class='b'><p>ok</div></span></body></html>",
  ).unwrap_or_else(() => fail("expected parser issue summary"))

  assert_eq(summary.issue_count, 6)
  assert_eq(summary.warning_count, 6)
  assert_eq(summary.error_count, 0)
  assert_eq(summary.script_count, 1)
  assert_eq(summary.style_count, 1)
  assert_eq(summary.unsafe_url_count, 1)
  assert_eq(summary.duplicate_attribute_count, 1)
  assert_eq(summary.unexpected_closing_count, 1)
  assert_eq(summary.unclosed_element_count, 1)
}

///|
test "html semantic block summary is available without changing simple output" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_semantic_summary_probe.html"
  write_utf8_text(
    sample_path, "<article><h1>Title</h1><p>Body <a href='https://example.com'>link</a>.</p><ul><li>One</li></ul><table><tr><th>K</th><td>V</td></tr></table></article>\n",
  )

  let summary = @html.collect_html_semantic_block_summary_from_text(
    read_html_parser_utf8_text(sample_path),
  ).unwrap_or_else(() => fail("expected semantic block summary"))
  assert_eq(summary.heading_count, 1)
  assert_eq(summary.paragraph_count, 1)
  assert_eq(summary.list_count, 1)
  assert_eq(summary.list_item_count, 1)
  assert_eq(summary.table_count, 1)
  assert_eq(summary.table_row_count, 1)
  assert_eq(summary.table_cell_count, 2)
  assert_eq(summary.semantic_table_fact_count, 1)
  assert_eq(summary.semantic_table_fact_row_count, 1)
  assert_eq(summary.semantic_table_fact_cell_count, 2)
  assert_eq(summary.semantic_table_caption_count, 0)
  assert_true(summary.inline_count > 0)
  assert_eq(summary.link_inline_count, 1)
  assert_eq(summary.semantic_link_count, 1)
  assert_eq(summary.external_link_count, 1)
  assert_eq(summary.semantic_image_count, 0)

  let doc = @html.parse_html(sample_path, "", 6)
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("# Title"))
  assert_true(markdown.contains("[link](https://example.com)"))
  assert_true(markdown.contains("- One"))
  assert_true(markdown.contains("| K | V |"))
}

///|
test "html semantic table summary is available without changing table output" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_semantic_table_summary_probe.html"
  write_utf8_text(
    sample_path, "<article><table><caption>Scores</caption><thead><tr><th scope='col'>Name</th><th scope='col'>Score</th></tr></thead><tbody><tr><td>Alice</td><td>42</td></tr></tbody><tfoot><tr><td>Total</td><td>42</td></tr></tfoot></table></article>\n",
  )

  let summary = @html.collect_html_semantic_table_summary_from_text(
    read_html_parser_utf8_text(sample_path),
  ).unwrap_or_else(() => fail("expected semantic table summary"))
  assert_eq(summary.table_count, 1)
  assert_eq(summary.table_row_count, 3)
  assert_eq(summary.table_cell_count, 6)
  assert_eq(summary.semantic_table_fact_count, 1)
  assert_eq(summary.semantic_table_section_count, 3)
  assert_eq(summary.semantic_table_head_section_count, 1)
  assert_eq(summary.semantic_table_body_section_count, 1)
  assert_eq(summary.semantic_table_foot_section_count, 1)
  assert_eq(summary.semantic_table_caption_count, 1)
  assert_eq(summary.semantic_table_fact_row_count, 3)
  assert_eq(summary.semantic_table_fact_cell_count, 6)
  assert_eq(summary.semantic_table_header_cell_count, 2)
  assert_eq(summary.semantic_table_data_cell_count, 4)
  assert_eq(summary.semantic_max_table_row_count, 3)
  assert_eq(summary.semantic_max_table_cell_count, 6)
  assert_eq(summary.semantic_table_warning_count, 0)

  let doc = @html.parse_html(sample_path, "", 6)
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("| Name | Score |"))
  assert_true(markdown.contains("| Alice | 42 |"))
  assert_true(markdown.contains("| Total | 42 |"))
}

///|
test "html semantic polished summary is available without changing rich block output" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_semantic_polished_summary_probe.html"
  write_utf8_text(
    sample_path, "<article><ol start='2' type='a'><li>One<ul><li>Nested</li></ul></li></ol><blockquote cite='https://example.com/q'><p>Quote</p></blockquote><pre class='language-moonbit'>let x = 1\n  x</pre><figure><img src='local.png' alt='Logo'><figcaption>Caption</figcaption></figure></article>\n",
  )

  let summary = @html.collect_html_semantic_polished_summary_from_text(
    read_html_parser_utf8_text(sample_path),
  ).unwrap_or_else(() => fail("expected semantic polished summary"))
  assert_eq(summary.semantic_list_fact_count, 2)
  assert_eq(summary.semantic_ordered_list_fact_count, 1)
  assert_eq(summary.semantic_unordered_list_fact_count, 1)
  assert_eq(summary.semantic_list_item_fact_count, 2)
  assert_eq(summary.semantic_max_list_depth, 2)
  assert_eq(summary.semantic_blockquote_fact_count, 1)
  assert_eq(summary.semantic_max_quote_depth, 1)
  assert_eq(summary.semantic_code_block_fact_count, 1)
  assert_eq(summary.semantic_code_block_language_hint_count, 1)
  assert_eq(summary.semantic_figure_fact_count, 1)
  assert_eq(summary.semantic_figure_caption_count, 1)
  assert_eq(summary.semantic_figure_image_count, 1)

  let markdown = @cor.emit_markdown(@html.parse_html(sample_path, "", 6))
  assert_true(markdown.contains("1. One"))
  assert_true(markdown.contains("- Nested"))
  assert_true(markdown.contains("> Quote"))
}

///|
test "html semantic inline link image summary is available without changing output" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_semantic_inline_summary_probe.html"
  write_utf8_text(
    sample_path, "<article><p>Alpha <em>one</em> <strong>two</strong> <code>three</code> <a href='mailto:a@example.com' title='Mail'>mail</a><br><img src='local.png' alt='Logo' title='Logo title' width='12' height='14'></p></article>\n",
  )

  let summary = @html.collect_html_semantic_inline_summary_from_text(
    read_html_parser_utf8_text(sample_path),
  ).unwrap_or_else(() => fail("expected semantic inline summary"))
  assert_eq(summary.paragraph_count, 1)
  assert_true(summary.inline_count > 0)
  assert_eq(summary.emphasis_inline_count, 1)
  assert_eq(summary.strong_inline_count, 1)
  assert_eq(summary.code_inline_count, 1)
  assert_eq(summary.link_inline_count, 1)
  assert_eq(summary.image_inline_count, 1)
  assert_eq(summary.break_inline_count, 1)
  assert_eq(summary.semantic_link_count, 1)
  assert_eq(summary.mailto_link_count, 1)
  assert_eq(summary.semantic_image_count, 1)
  assert_eq(summary.local_image_count, 1)
  assert_eq(summary.warning_count, 0)

  let doc = @html.parse_html(sample_path, "", 6)
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("Alpha one two three"))
  assert_true(markdown.contains("[mail](mailto:a@example.com)"))
  assert_true(markdown.contains("[Logo]"))
}

///|
test "html semantic paragraph spacing summary is available without changing output" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_semantic_paragraph_spacing_probe.html"
  write_utf8_text(
    sample_path, "<article><p>hello   <a href='https://example.com'>world</a> !\n<em>em</em><strong>strong</strong><code> x  y </code><br><img src='local.png' alt='Alt'></p><div>candidate text</div><p>   </p></article>\n",
  )

  let summary = @html.collect_html_semantic_paragraph_summary_from_text(
    read_html_parser_utf8_text(sample_path),
  ).unwrap_or_else(() => fail("expected semantic paragraph summary"))
  assert_eq(summary.semantic_paragraph_fact_count, 3)
  assert_eq(summary.semantic_paragraph_with_link_count, 1)
  assert_eq(summary.semantic_paragraph_with_image_count, 1)
  assert_eq(summary.semantic_paragraph_with_code_count, 1)
  assert_eq(summary.semantic_paragraph_with_emphasis_count, 1)
  assert_eq(summary.semantic_paragraph_with_strong_count, 1)
  assert_eq(summary.semantic_paragraph_with_break_count, 1)
  assert_eq(summary.semantic_paragraph_meaningful_text_count, 2)
  assert_eq(summary.semantic_paragraph_candidate_count, 1)
  assert_eq(summary.semantic_paragraph_repeated_whitespace_count, 2)
  assert_eq(summary.semantic_paragraph_newline_count, 1)
  assert_true(summary.semantic_leading_whitespace_inline_count > 0)
  assert_true(summary.semantic_trailing_whitespace_inline_count > 0)
  assert_true(summary.semantic_repeated_whitespace_inline_count > 0)
  assert_true(summary.semantic_newline_inline_count > 0)
  assert_eq(summary.semantic_whitespace_preserving_inline_count, 1)
  assert_true(summary.semantic_inline_with_surrounding_text_count > 0)

  let markdown = @cor.emit_markdown(@html.parse_html(sample_path, "", 6))
  assert_true(markdown.contains("[world](https://example.com)"))
  assert_true(markdown.contains("<br>"))
  assert_true(markdown.contains("[Alt]"))
  assert_true(markdown.contains("candidate text"))
  assert_false(markdown.contains("semantic_paragraph"))
}

///|
test "html semantic warning summary is available without changing unsupported output" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_semantic_warning_summary_probe.html"
  write_utf8_text(
    sample_path, "<article><h1>Visible</h1><script>skip()</script><style>.x{}</style><iframe src='frame.html'></iframe><p><a href='javascript:bad()'>bad</a><a href='data:text/plain,hi'>data</a><a>empty</a><img src='https://example.com/a.png'><img src='data:image/png;base64,abcdef'><img alt='missing'></p></article>\n",
  )

  let summary = @html.collect_html_semantic_warning_summary_from_text(
    read_html_parser_utf8_text(sample_path),
  ).unwrap_or_else(() => fail("expected semantic warning summary"))
  assert_eq(summary.heading_count, 1)
  assert_eq(summary.unsupported_script_count, 1)
  assert_eq(summary.unsupported_style_count, 1)
  assert_eq(summary.unsupported_iframe_count, 1)
  assert_eq(summary.unsupported_remote_image_count, 1)
  assert_eq(summary.unsupported_data_image_count, 1)
  assert_eq(summary.unsupported_unsafe_url_count, 2)
  assert_eq(summary.unsupported_empty_url_count, 2)
  assert_true(summary.unsupported_fact_count >= 8)
  assert_true(summary.warning_count >= 8)
  assert_true(summary.warning_info_count >= 3)
  assert_true(summary.warning_warning_count >= 5)

  let markdown = @cor.emit_markdown(@html.parse_html(sample_path, "", 6))
  assert_true(markdown.contains("# Visible"))
  assert_false(markdown.contains("skip()"))
  assert_false(markdown.contains(".x{}"))
}

///|
test "html semantic m95 summary exposes notes scope noise table and complex inline facts without changing output" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_semantic_m95_summary_probe.html"
  write_utf8_text(
    sample_path, "<html><head><title>M95</title><meta name='description' content='Probe'></head><body><article><nav>Nav</nav><p>Body <a epub:type='noteref' href='#fn1'>1</a><a href='https://example.com'><img src='local.png' srcset='local-2x.png 2x' alt='Local'></a><a href='javascript:bad'>bad</a></p><table><caption>Cap</caption><tr><th colspan='2'>H</th><th>Extra</th></tr><tr><td><img src='cell.png' alt='Cell'></td></tr></table><aside epub:type='footnote' id='fn1'>Note <a epub:type='backlink' href='#ref1'>back</a></aside></article></body></html>\n",
  )

  let text = read_html_parser_utf8_text(sample_path)
  let note_summary = @html.collect_html_semantic_note_summary_from_text(text).unwrap_or_else(() => {
      fail("expected note summary")
    },
  )
  assert_true(note_summary.semantic_note_fact_count >= 2)
  assert_true(note_summary.semantic_note_ref_fact_count >= 2)
  assert_eq(note_summary.semantic_note_body_fact_count, 1)
  assert_true(note_summary.semantic_backref_note_count >= 1)

  let scope_summary = @html.collect_html_semantic_scope_summary_from_text(text).unwrap_or_else(() => {
      fail("expected scope summary")
    },
  )
  assert_eq(scope_summary.semantic_scope_fact_count, 1)
  assert_eq(scope_summary.semantic_scope_body_count, 1)
  assert_eq(scope_summary.semantic_scope_missing_body_count, 0)

  let noise_summary = @html.collect_html_semantic_noise_summary_from_text(text).unwrap_or_else(() => {
      fail("expected noise summary")
    },
  )
  assert_true(noise_summary.semantic_noise_candidate_count >= 1)
  assert_true(noise_summary.semantic_noise_nav_like_count >= 1)

  let inline_summary = @html.collect_html_semantic_complex_inline_summary_from_text(
    text,
  ).unwrap_or_else(() => fail("expected inline summary"))
  assert_true(inline_summary.semantic_linked_image_count >= 1)
  assert_true(inline_summary.semantic_image_in_link_count >= 1)
  assert_true(inline_summary.semantic_note_ref_inline_count >= 1)
  assert_true(inline_summary.semantic_srcset_image_count >= 1)
  assert_eq(inline_summary.unsafe_link_count, 1)

  let table_summary = @html.collect_html_semantic_table_summary_from_text(text).unwrap_or_else(() => {
      fail("expected table summary")
    },
  )
  assert_eq(table_summary.semantic_table_caption_count, 1)
  assert_true(table_summary.semantic_table_span_cell_count >= 1)
  assert_true(table_summary.semantic_table_ragged_row_count >= 1)
  assert_true(table_summary.semantic_table_image_cell_count >= 1)
  assert_true(table_summary.semantic_table_complex_cell_count >= 1)

  let markdown = @cor.emit_markdown(@html.parse_html(sample_path, "", 6))
  assert_true(markdown.contains("Body"))
  assert_true(markdown.contains("[Local]"))
  assert_false(markdown.contains("semantic_note"))
  assert_false(markdown.contains("Nav"))
}

///|
test "html semantic table lowering handles safe simple tables without changing output" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_semantic_lowering_table_safe.html"
  let profile_path = dir + "/html-semantic-lowering-table-safe.txt"
  write_utf8_text(
    sample_path, "<article><table><tr><th>Name</th><th>Score</th></tr><tr><td>Alice</td><td>42</td></tr></table><table><thead><tr><th>Kind</th><th>Value</th></tr></thead><tbody><tr><td><a href='https://example.com'>link</a></td><td><em>em</em><strong>strong</strong><code> x </code><br>tail</td></tr></tbody></table></article>\n",
  )

  let prev_enabled = @sys.get_env_var("MARKITDOWN_PROFILE_HTML")
  let prev_path = @sys.get_env_var("MARKITDOWN_PROFILE_HTML_PATH")
  defer {
    restore_env_var("MARKITDOWN_PROFILE_HTML", prev_enabled)
    restore_env_var("MARKITDOWN_PROFILE_HTML_PATH", prev_path)
  }
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML", "1")
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML_PATH", profile_path)

  let doc = @html.parse_html(sample_path, "", 6)
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("| Name | Score |"))
  assert_true(markdown.contains("| Alice | 42 |"))
  assert_true(markdown.contains("| Kind | Value |"))
  assert_true(markdown.contains("| [link](https://example.com) |"))
  assert_true(markdown.contains("emstrong x <br>tail"))

  match doc.blocks.val[0] {
    @cor.Block::RichTable(table) => {
      assert_eq(table.header_rows, 1)
      assert_true(table.rows[0] == ["Name", "Score"])
      assert_true(table.rows[1] == ["Alice", "42"])
    }
    _ => fail("safe th table should emit RichTable")
  }
  match doc.blocks.val[1] {
    @cor.Block::RichTable(table) => {
      assert_eq(table.header_rows, 1)
      assert_true(table.rows[0] == ["Kind", "Value"])
      assert_eq(table.rows[1][0], "[link](https://example.com)")
      assert_eq(table.rows[1][1], "emstrong x <br>tail")
    }
    _ => fail("safe thead table should emit RichTable")
  }

  let report = read_html_parser_utf8_text(profile_path)
  assert_eq(html_profile_counter(report, "semantic_table_candidate_count"), 2)
  assert_eq(html_profile_counter(report, "semantic_table_lowered_count"), 2)
  assert_eq(
    html_profile_counter(report, "semantic_table_existing_path_count"),
    0,
  )
  assert_eq(html_profile_counter(report, "semantic_table_guard_count"), 0)
  assert_eq(
    html_profile_counter(report, "semantic_table_mismatch_guard_count"),
    0,
  )
}

///|
test "html semantic table lowering uses parser facts for complex tables" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_semantic_lowering_table_guarded.html"
  let profile_path = dir + "/html-semantic-lowering-table-guarded.txt"
  write_utf8_text(
    sample_path,
    "<article>" +
    "<table><caption>Cap</caption><tr><th>A</th><th>B</th></tr><tr><td>1</td><td>2</td></tr></table>" +
    "<table><tr><th colspan='2'>Wide</th></tr><tr><td>A</td><td>B</td></tr></table>" +
    "<table><tr><th>A</th><th>B</th></tr><tr><td>Only one</td></tr></table>" +
    "<table><tr><th>A</th><th>B</th></tr><tr><td><img src='local.png' alt='Alt'></td><td>Text</td></tr></table>" +
    "<table><tr><th>A</th><th>B</th></tr><tr><td><ul><li>One</li></ul></td><td><blockquote>Q</blockquote></td></tr><tr><td><pre>code</pre></td><td>Plain</td></tr></table>" +
    "<table><tr><th>A</th></tr><tr><td>Outer <table><tr><th>N</th></tr><tr><td>Inner</td></tr></table></td></tr></table>" +
    "</article>\n",
  )

  let prev_enabled = @sys.get_env_var("MARKITDOWN_PROFILE_HTML")
  let prev_path = @sys.get_env_var("MARKITDOWN_PROFILE_HTML_PATH")
  defer {
    restore_env_var("MARKITDOWN_PROFILE_HTML", prev_enabled)
    restore_env_var("MARKITDOWN_PROFILE_HTML_PATH", prev_path)
  }
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML", "1")
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML_PATH", profile_path)

  let doc = @html.parse_html(sample_path, "", 6)
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("| A | B |"))
  assert_true(markdown.contains("| Wide |  |"))
  assert_true(markdown.contains("| Only one |  |"))
  assert_true(markdown.contains("| Alt | Text |"))
  assert_true(markdown.contains("| One | Q |"))
  assert_true(markdown.contains("| code | Plain |"))
  assert_true(markdown.contains("| Inner |"))

  let report = read_html_parser_utf8_text(profile_path)
  assert_true(html_profile_has_stage(report, "html_parser_fact_model"))
  assert_eq(html_profile_counter(report, "semantic_table_candidate_count"), 0)
  assert_true(html_profile_counter(report, "semantic_table_lowered_count") >= 6)
  assert_eq(
    html_profile_counter(report, "semantic_table_existing_path_count"),
    0,
  )
  assert_true(
    html_profile_counter(report, "semantic_table_span_guard_count") >= 1,
  )
  assert_true(
    html_profile_counter(report, "semantic_table_caption_guard_count") >= 1,
  )
  assert_true(
    html_profile_counter(report, "semantic_table_nested_guard_count") >= 1,
  )
  assert_true(
    html_profile_counter(report, "semantic_table_complex_cell_guard_count") >= 2,
  )
  assert_true(
    html_profile_counter(report, "semantic_table_ragged_guard_count") >= 1,
  )
}

///|
test "html semantic table runtime handles malformed and empty tables conservatively" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_semantic_table_malformed_runtime.html"
  let profile_path = dir + "/html-semantic-table-malformed-runtime.txt"
  write_utf8_text(
    sample_path,
    "<article>" +
    "<table><tr><th>Broken<th>Header<tr><td>Only</table>" +
    "<table><tbody></tbody></table>" +
    "<table><tr><td>Outer <table><tr><td>Inner</td></tr></table></td></tr></table>" +
    "</article>\n",
  )

  let prev_enabled = @sys.get_env_var("MARKITDOWN_PROFILE_HTML")
  let prev_path = @sys.get_env_var("MARKITDOWN_PROFILE_HTML_PATH")
  defer {
    restore_env_var("MARKITDOWN_PROFILE_HTML", prev_enabled)
    restore_env_var("MARKITDOWN_PROFILE_HTML_PATH", prev_path)
  }
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML", "1")
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML_PATH", profile_path)

  let doc = @html.parse_html(sample_path, "", 6)
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("Broken"))
  assert_true(markdown.contains("Inner"))
  assert_true(doc.blocks.val.length() >= 2)

  let report = read_html_parser_utf8_text(profile_path)
  assert_true(html_profile_has_stage(report, "html_parser_fact_model"))
  assert_true(html_profile_counter(report, "semantic_table_lowered_count") >= 2)
  assert_true(html_profile_counter(report, "semantic_table_guard_count") >= 1)
  assert_true(
    html_profile_counter(report, "semantic_table_nested_guard_count") >= 1,
  )
  assert_true(report.contains("semantic_table_malformed_warning_count=1"))
}

///|
test "html semantic lowering path handles simple paragraph inlines without changing output" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_semantic_lowering_paragraph_probe.html"
  let profile_path = dir + "/html-semantic-lowering-paragraph-profile.txt"
  write_utf8_text(
    sample_path, "<article><p>hello   <em>one</em><strong>two</strong><code> x  y </code><br>tail</p></article>\n",
  )

  let prev_enabled = @sys.get_env_var("MARKITDOWN_PROFILE_HTML")
  let prev_path = @sys.get_env_var("MARKITDOWN_PROFILE_HTML_PATH")
  defer {
    restore_env_var("MARKITDOWN_PROFILE_HTML", prev_enabled)
    restore_env_var("MARKITDOWN_PROFILE_HTML_PATH", prev_path)
  }
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML", "1")
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML_PATH", profile_path)

  let doc = @html.parse_html(sample_path, "", 6)
  assert_eq(@cor.emit_markdown(doc), "hello   onetwo x  y <br>tail\n")

  let report = read_html_parser_utf8_text(profile_path)
  assert_true(report.contains("semantic_lowering_available=true"))
  assert_true(report.contains("semantic_paragraph_candidate_count=1"))
  assert_true(report.contains("semantic_paragraph_lowered_count=1"))
  assert_true(report.contains("semantic_paragraph_existing_path_count=0"))
  assert_true(report.contains("semantic_inline_lowered_count=3"))
  assert_true(report.contains("semantic_blockquote_candidate_count=0"))
  assert_true(report.contains("semantic_code_block_candidate_count=0"))
}

///|
test "html semantic lowering path handles headings and safe link paragraphs without changing output" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_semantic_lowering_heading_link.html"
  let profile_path = dir + "/html-semantic-lowering-heading-link.txt"
  write_utf8_text(
    sample_path, "<article><h2>Head <em>em</em><code>x</code><br>tail</h2><p>Go <a href='https://example.com'>external</a> and <a href='#top'>internal</a> plus <a href='mailto:a@example.com'>mail</a> and <a href='tel:+123'>tel</a>.</p></article>\n",
  )

  let prev_enabled = @sys.get_env_var("MARKITDOWN_PROFILE_HTML")
  let prev_path = @sys.get_env_var("MARKITDOWN_PROFILE_HTML_PATH")
  defer {
    restore_env_var("MARKITDOWN_PROFILE_HTML", prev_enabled)
    restore_env_var("MARKITDOWN_PROFILE_HTML_PATH", prev_path)
  }
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML", "1")
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML_PATH", profile_path)

  let doc = @html.parse_html(sample_path, "", 6)
  assert_eq(
    @cor.emit_markdown(doc),
    "## Head emx<br>tail\n\nGo [external](https://example.com) and [internal](#top) plus [mail](mailto:a@example.com) and [tel](tel:+123).\n",
  )

  let report = read_html_parser_utf8_text(profile_path)
  assert_true(report.contains("semantic_lowering_available=true"))
  assert_true(report.contains("semantic_heading_candidate_count=1"))
  assert_true(report.contains("semantic_heading_lowered_count=1"))
  assert_true(report.contains("semantic_heading_existing_path_count=0"))
  assert_true(report.contains("semantic_link_paragraph_candidate_count=1"))
  assert_true(report.contains("semantic_link_paragraph_lowered_count=1"))
  assert_true(report.contains("semantic_link_paragraph_existing_path_count=0"))
}

///|
test "html semantic heading lowering respects max heading clamp" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_semantic_lowering_heading_clamp.html"
  let profile_path = dir + "/html-semantic-lowering-heading-clamp.txt"
  write_utf8_text(sample_path, "<article><h5>Small title</h5></article>\n")

  let prev_enabled = @sys.get_env_var("MARKITDOWN_PROFILE_HTML")
  let prev_path = @sys.get_env_var("MARKITDOWN_PROFILE_HTML_PATH")
  defer {
    restore_env_var("MARKITDOWN_PROFILE_HTML", prev_enabled)
    restore_env_var("MARKITDOWN_PROFILE_HTML_PATH", prev_path)
  }
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML", "1")
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML_PATH", profile_path)

  let doc = @html.parse_html(sample_path, "", 3)
  assert_eq(@cor.emit_markdown(doc), "### Small title\n")

  let report = read_html_parser_utf8_text(profile_path)
  assert_true(report.contains("semantic_heading_candidate_count=1"))
  assert_true(report.contains("semantic_heading_lowered_count=1"))
}

///|
test "html semantic paragraph lowering handles unsafe links and image placeholders from facts" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let link_path = dir + "/html_semantic_lowering_paragraph_unsafe_link.html"
  let link_profile_path = dir +
    "/html-semantic-lowering-paragraph-unsafe-link.txt"
  write_utf8_text(
    link_path, "<article><p>hello <a href='javascript:bad'>bad</a> and <a>empty</a> !</p></article>\n",
  )

  let prev_enabled = @sys.get_env_var("MARKITDOWN_PROFILE_HTML")
  let prev_path = @sys.get_env_var("MARKITDOWN_PROFILE_HTML_PATH")
  defer {
    restore_env_var("MARKITDOWN_PROFILE_HTML", prev_enabled)
    restore_env_var("MARKITDOWN_PROFILE_HTML_PATH", prev_path)
  }
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML", "1")
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML_PATH", link_profile_path)

  let link_doc = @html.parse_html(link_path, "", 6)
  assert_eq(@cor.emit_markdown(link_doc), "hello bad and empty !\n")

  let link_report = read_html_parser_utf8_text(link_profile_path)
  assert_true(html_profile_has_stage(link_report, "html_parser_fact_model"))
  assert_true(link_report.contains("semantic_paragraph_candidate_count=0"))
  assert_true(link_report.contains("semantic_paragraph_lowered_count=1"))
  assert_true(link_report.contains("semantic_paragraph_existing_path_count=0"))
  assert_true(link_report.contains("semantic_paragraph_empty_guard_count=0"))
  assert_true(
    link_report.contains("semantic_paragraph_render_mismatch_guard_count=0"),
  )
  assert_true(
    link_report.contains("semantic_paragraph_unsupported_guard_count=0"),
  )
  assert_true(link_report.contains("semantic_link_paragraph_candidate_count=0"))
  assert_true(link_report.contains("semantic_link_paragraph_lowered_count=1"))
  assert_true(
    link_report.contains("semantic_link_paragraph_existing_path_count=0"),
  )

  let image_path = dir + "/html_semantic_lowering_paragraph_image.html"
  let image_profile_path = dir + "/html-semantic-lowering-paragraph-image.txt"
  write_utf8_text(
    image_path, "<article><p>before <img src='remote.png' alt='Alt'> after</p></article>\n",
  )
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML_PATH", image_profile_path)

  let image_doc = @html.parse_html(image_path, "", 6)
  assert_eq(@cor.emit_markdown(image_doc), "before\n\n[Alt]\n\nafter\n")

  let image_report = read_html_parser_utf8_text(image_profile_path)
  assert_true(html_profile_has_stage(image_report, "html_parser_fact_model"))
  assert_true(image_report.contains("semantic_paragraph_candidate_count=0"))
  assert_true(image_report.contains("semantic_paragraph_lowered_count=3"))
  assert_true(image_report.contains("semantic_paragraph_existing_path_count=0"))
  assert_true(image_report.contains("semantic_paragraph_empty_guard_count=0"))
  assert_true(
    image_report.contains("semantic_paragraph_render_mismatch_guard_count=0"),
  )
  assert_true(
    image_report.contains("semantic_paragraph_unsupported_guard_count=0"),
  )
  assert_true(image_report.contains("semantic_image_existing_path_count=1"))
}

///|
test "html semantic lowering path handles simple list items without changing output" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_semantic_lowering_list_probe.html"
  let profile_path = dir + "/html-semantic-lowering-list-profile.txt"
  write_utf8_text(
    sample_path, "<article><ul><li>Alpha <em>em</em><code>x</code><br>tail</li><li>Go <a href='https://example.com'>link</a></li></ul><ol><li>One</li></ol></article>\n",
  )

  let prev_enabled = @sys.get_env_var("MARKITDOWN_PROFILE_HTML")
  let prev_path = @sys.get_env_var("MARKITDOWN_PROFILE_HTML_PATH")
  defer {
    restore_env_var("MARKITDOWN_PROFILE_HTML", prev_enabled)
    restore_env_var("MARKITDOWN_PROFILE_HTML_PATH", prev_path)
  }
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML", "1")
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML_PATH", profile_path)

  let doc = @html.parse_html(sample_path, "", 6)
  assert_eq(
    @cor.emit_markdown(doc),
    "- Alpha emx<br>tail\n- Go [link](https://example.com)\n1. One\n",
  )

  let report = read_html_parser_utf8_text(profile_path)
  assert_true(report.contains("semantic_list_candidate_count=3"))
  assert_true(report.contains("semantic_list_lowered_count=3"))
  assert_true(report.contains("semantic_list_existing_path_count=0"))
  assert_true(report.contains("semantic_list_item_lowered_count=3"))
  assert_true(report.contains("semantic_list_item_existing_path_count=0"))
  assert_true(report.contains("semantic_list_nested_guard_count=0"))
}

///|
test "html semantic list lowering uses parser facts for complex list items" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_semantic_lowering_list_guarded.html"
  let profile_path = dir + "/html-semantic-lowering-list-guarded.txt"
  write_utf8_text(
    sample_path, "<article><ul><li>Nested<ul><li>Child</li></ul></li><li>Image <img src='local.png' alt='Alt'></li><li><table><tr><td>A</td></tr></table></li></ul></article>\n",
  )

  let prev_enabled = @sys.get_env_var("MARKITDOWN_PROFILE_HTML")
  let prev_path = @sys.get_env_var("MARKITDOWN_PROFILE_HTML_PATH")
  defer {
    restore_env_var("MARKITDOWN_PROFILE_HTML", prev_enabled)
    restore_env_var("MARKITDOWN_PROFILE_HTML_PATH", prev_path)
  }
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML", "1")
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML_PATH", profile_path)

  let doc = @html.parse_html(sample_path, "", 6)
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("- Nested"))
  assert_true(markdown.contains("- Child"))
  assert_true(markdown.contains("- Image Alt"))
  assert_true(markdown.contains("- A"))

  let report = read_html_parser_utf8_text(profile_path)
  assert_true(html_profile_has_stage(report, "html_parser_fact_model"))
  assert_true(report.contains("semantic_list_candidate_count=1"))
  assert_true(report.contains("semantic_list_lowered_count=3"))
  assert_true(report.contains("semantic_list_existing_path_count=1"))
  assert_true(report.contains("semantic_list_item_lowered_count=3"))
  assert_true(report.contains("semantic_list_item_existing_path_count=1"))
  assert_true(report.contains("semantic_list_nested_guard_count=0"))
  assert_true(report.contains("semantic_list_empty_guard_count=0"))
  assert_true(report.contains("semantic_list_render_mismatch_guard_count=0"))
  assert_true(report.contains("semantic_list_unsupported_guard_count=0"))
}

///|
test "html semantic image and figure lowering uses parser facts without changing output" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)
  let img_dir = dir + "/img"
  ensure_dir_tree(img_dir)
  write_utf8_text(img_dir + "/photo.png", "not-a-real-png")
  write_utf8_text(img_dir + "/figure.png", "not-a-real-figure")

  let sample_path = dir + "/html_semantic_lowering_image_figure.html"
  let profile_path = dir + "/html-semantic-lowering-image-figure.txt"
  write_utf8_text(
    sample_path, "<article><p>Before <img src='img/photo.png' alt='Photo' title='Photo title'> After</p><figure><img src='img/figure.png' alt='Figure' title='Figure title'><figcaption>Figure caption</figcaption></figure></article>\n",
  )

  let prev_enabled = @sys.get_env_var("MARKITDOWN_PROFILE_HTML")
  let prev_path = @sys.get_env_var("MARKITDOWN_PROFILE_HTML_PATH")
  defer {
    restore_env_var("MARKITDOWN_PROFILE_HTML", prev_enabled)
    restore_env_var("MARKITDOWN_PROFILE_HTML_PATH", prev_path)
  }
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML", "1")
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML_PATH", profile_path)

  let out_dir = dir + "/out"
  ensure_dir_tree(out_dir)
  let doc = @html.parse_html(sample_path, out_dir, 6)
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("Before"))
  assert_true(markdown.contains("After"))
  assert_true(markdown.contains("![Photo](assets/image"))
  assert_true(markdown.contains("\n*Photo title*\n"))
  assert_true(markdown.contains("![Figure](assets/image"))
  assert_true(markdown.contains("\n*Figure title*\n"))
  assert_true(markdown.contains("\nFigure caption\n"))

  let mut image_block_count = 0
  for block in doc.blocks.val {
    match block {
      @cor.Block::ImageBlock(_) => image_block_count += 1
      _ => ()
    }
  }
  assert_eq(image_block_count, 2)

  let report = read_html_parser_utf8_text(profile_path)
  assert_true(report.contains("semantic_image_candidate_count=1"))
  assert_true(report.contains("semantic_image_lowered_count=1"))
  assert_true(report.contains("semantic_image_existing_path_count=0"))
  assert_true(report.contains("semantic_figure_candidate_count=1"))
  assert_true(report.contains("semantic_figure_lowered_count=1"))
  assert_true(report.contains("semantic_figure_existing_path_count=0"))
  assert_true(report.contains("semantic_image_guard_count=0"))
  assert_true(report.contains("semantic_figure_guard_count=0"))
}

///|
test "html semantic image and figure lowering records conservative fact paths" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_semantic_lowering_image_figure_guarded.html"
  let profile_path = dir + "/html-semantic-lowering-image-figure-guarded.txt"
  write_utf8_text(
    sample_path, "<article><p><img src='https://example.com/r.png' alt='Remote'></p><p><img src='data:image/png;base64,abc' alt='Data'></p><figure><a href='full.png'><img src='local.png' alt='Linked'></a><figcaption>Linked caption</figcaption></figure><figure><img src='one.png' alt='One'><img src='two.png' alt='Two'><figcaption>Two images</figcaption></figure></article>\n",
  )

  let prev_enabled = @sys.get_env_var("MARKITDOWN_PROFILE_HTML")
  let prev_path = @sys.get_env_var("MARKITDOWN_PROFILE_HTML_PATH")
  defer {
    restore_env_var("MARKITDOWN_PROFILE_HTML", prev_enabled)
    restore_env_var("MARKITDOWN_PROFILE_HTML_PATH", prev_path)
  }
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML", "1")
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML_PATH", profile_path)

  let doc = @html.parse_html(sample_path, "", 6)
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("[Remote]"))
  assert_true(markdown.contains("[Data]"))
  assert_false(markdown.contains("![Linked]"))
  assert_false(markdown.contains("![One]"))

  let report = read_html_parser_utf8_text(profile_path)
  assert_true(html_profile_has_stage(report, "html_parser_fact_model"))
  assert_true(report.contains("semantic_image_candidate_count=0"))
  assert_true(report.contains("semantic_image_lowered_count=0"))
  assert_true(report.contains("semantic_image_existing_path_count=2"))
  assert_true(report.contains("semantic_image_empty_guard_count=0"))
  assert_true(report.contains("semantic_image_render_mismatch_guard_count=0"))
  assert_true(report.contains("semantic_image_identity_guard_count=0"))
  assert_true(report.contains("semantic_image_unsupported_guard_count=0"))
  assert_true(report.contains("semantic_figure_candidate_count=0"))
  assert_true(report.contains("semantic_figure_lowered_count=0"))
  assert_true(report.contains("semantic_figure_existing_path_count=2"))
  assert_true(report.contains("semantic_figure_empty_guard_count=0"))
  assert_true(report.contains("semantic_figure_render_mismatch_guard_count=0"))
  assert_true(report.contains("semantic_figure_identity_guard_count=0"))
  assert_true(report.contains("semantic_figure_unsupported_guard_count=0"))
  assert_true(report.contains("semantic_image_guard_count=0"))
  assert_true(report.contains("semantic_figure_guard_count=0"))
}

///|
test "html semantic lowering path handles blockquote without changing output" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_semantic_lowering_quote_probe.html"
  let profile_path = dir + "/html-semantic-lowering-quote-profile.txt"
  write_utf8_text(sample_path, "<blockquote><p>Quoted line.</p></blockquote>\n")

  let prev_enabled = @sys.get_env_var("MARKITDOWN_PROFILE_HTML")
  let prev_path = @sys.get_env_var("MARKITDOWN_PROFILE_HTML_PATH")
  defer {
    restore_env_var("MARKITDOWN_PROFILE_HTML", prev_enabled)
    restore_env_var("MARKITDOWN_PROFILE_HTML_PATH", prev_path)
  }
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML", "1")
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML_PATH", profile_path)

  let doc = @html.parse_html(sample_path, "", 6)
  assert_eq(@cor.emit_markdown(doc), "> Quoted line.\n")

  let report = read_html_parser_utf8_text(profile_path)
  assert_true(report.contains("semantic_lowering_available=true"))
  assert_true(report.contains("semantic_blockquote_candidate_count=1"))
  assert_true(report.contains("semantic_blockquote_lowered_count=1"))
  assert_true(report.contains("semantic_blockquote_existing_path_count=0"))
  assert_true(report.contains("semantic_blockquote_unsupported_guard_count=0"))
  assert_true(report.contains("semantic_code_block_candidate_count=0"))
  assert_true(report.contains("semantic_code_block_lowered_count=0"))
  assert_true(report.contains("semantic_code_block_existing_path_count=0"))
  assert_true(report.contains("semantic_code_block_empty_guard_count=0"))
  assert_true(report.contains("semantic_code_block_incomplete_guard_count=0"))
}

///|
test "html semantic lowering path handles pre code without changing output" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_semantic_lowering_code_probe.html"
  let profile_path = dir + "/html-semantic-lowering-code-profile.txt"
  write_utf8_text(
    sample_path, "<pre><code class='language-moonbit'>let x = 1\n  x + 1</code></pre>\n",
  )

  let prev_enabled = @sys.get_env_var("MARKITDOWN_PROFILE_HTML")
  let prev_path = @sys.get_env_var("MARKITDOWN_PROFILE_HTML_PATH")
  defer {
    restore_env_var("MARKITDOWN_PROFILE_HTML", prev_enabled)
    restore_env_var("MARKITDOWN_PROFILE_HTML_PATH", prev_path)
  }
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML", "1")
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML_PATH", profile_path)

  let doc = @html.parse_html(sample_path, "", 6)
  assert_eq(@cor.emit_markdown(doc), "```\nlet x = 1\n  x + 1\n```\n")

  let report = read_html_parser_utf8_text(profile_path)
  assert_true(report.contains("semantic_lowering_available=true"))
  assert_true(report.contains("semantic_blockquote_candidate_count=0"))
  assert_true(report.contains("semantic_blockquote_lowered_count=0"))
  assert_true(report.contains("semantic_blockquote_existing_path_count=0"))
  assert_true(report.contains("semantic_blockquote_unsupported_guard_count=0"))
  assert_true(report.contains("semantic_code_block_candidate_count=1"))
  assert_true(report.contains("semantic_code_block_lowered_count=1"))
  assert_true(report.contains("semantic_code_block_existing_path_count=0"))
  assert_true(report.contains("semantic_code_block_empty_guard_count=0"))
  assert_true(report.contains("semantic_code_block_incomplete_guard_count=0"))
  assert_true(
    report.contains("semantic_code_block_language_hint_lowered_count=1"),
  )
}

///|
test "html semantic lowering keeps complex blockquotes on fact conservative path" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_semantic_lowering_complex_quote.html"
  let profile_path = dir + "/html-semantic-lowering-complex-profile.txt"
  write_utf8_text(
    sample_path, "<article><blockquote><p>outer</p><blockquote><p>inner</p></blockquote></blockquote></article>\n",
  )

  let prev_enabled = @sys.get_env_var("MARKITDOWN_PROFILE_HTML")
  let prev_path = @sys.get_env_var("MARKITDOWN_PROFILE_HTML_PATH")
  defer {
    restore_env_var("MARKITDOWN_PROFILE_HTML", prev_enabled)
    restore_env_var("MARKITDOWN_PROFILE_HTML_PATH", prev_path)
  }
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML", "1")
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML_PATH", profile_path)

  let doc = @html.parse_html(sample_path, "", 6)
  assert_eq(@cor.emit_markdown(doc), "> outer\n> \n> inner\n")

  let report = read_html_parser_utf8_text(profile_path)
  assert_true(html_profile_has_stage(report, "html_parser_fact_model"))
  assert_true(report.contains("semantic_blockquote_candidate_count=1"))
  assert_true(report.contains("semantic_blockquote_lowered_count=0"))
  assert_true(report.contains("semantic_blockquote_existing_path_count=1"))
  assert_true(report.contains("semantic_blockquote_unsupported_guard_count=0"))
}

///|
test "html semantic lowering handles linked blockquotes from parser facts" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_semantic_lowering_link_quote.html"
  let profile_path = dir + "/html-semantic-lowering-link-profile.txt"
  write_utf8_text(
    sample_path, "<article><blockquote><p>Quoted <a href='https://example.com/q'>reference</a> line.</p></blockquote></article>\n",
  )

  let prev_enabled = @sys.get_env_var("MARKITDOWN_PROFILE_HTML")
  let prev_path = @sys.get_env_var("MARKITDOWN_PROFILE_HTML_PATH")
  defer {
    restore_env_var("MARKITDOWN_PROFILE_HTML", prev_enabled)
    restore_env_var("MARKITDOWN_PROFILE_HTML_PATH", prev_path)
  }
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML", "1")
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML_PATH", profile_path)

  let doc = @html.parse_html(sample_path, "", 6)
  assert_eq(
    @cor.emit_markdown(doc),
    "> Quoted [reference](https://example.com/q) line.\n",
  )

  let report = read_html_parser_utf8_text(profile_path)
  assert_true(html_profile_has_stage(report, "html_parser_fact_model"))
  assert_true(report.contains("semantic_blockquote_candidate_count=1"))
  assert_true(report.contains("semantic_blockquote_lowered_count=1"))
  assert_true(report.contains("semantic_blockquote_existing_path_count=0"))
  assert_true(report.contains("semantic_blockquote_unsupported_guard_count=0"))
}

///|
test "html semantic code lowering keeps incomplete pre on existing output path" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_semantic_lowering_large_code.html"
  let profile_path = dir + "/html-semantic-lowering-large-code-profile.txt"
  let mut code = ""
  for i in 0..<140000 {
    let _ = i
    code = code + "x"
  }
  write_utf8_text(sample_path, "<pre>" + code + "</pre>\n")

  let prev_enabled = @sys.get_env_var("MARKITDOWN_PROFILE_HTML")
  let prev_path = @sys.get_env_var("MARKITDOWN_PROFILE_HTML_PATH")
  defer {
    restore_env_var("MARKITDOWN_PROFILE_HTML", prev_enabled)
    restore_env_var("MARKITDOWN_PROFILE_HTML_PATH", prev_path)
  }
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML", "1")
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML_PATH", profile_path)

  let doc = @html.parse_html(sample_path, "", 6)
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.has_prefix("```\nxxx"))
  assert_true(markdown.has_suffix("\n```\n"))

  let report = read_html_parser_utf8_text(profile_path)
  assert_true(report.contains("semantic_code_block_candidate_count=1"))
  assert_true(report.contains("semantic_code_block_lowered_count=0"))
  assert_true(report.contains("semantic_code_block_existing_path_count=1"))
  assert_true(report.contains("semantic_code_block_empty_guard_count=0"))
  assert_true(report.contains("semantic_code_block_incomplete_guard_count=1"))
}

///|
test "html profile reports parser analysis scope and skip observability" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_profile_observability.html"
  let profile_path = dir + "/html-profile-observability.txt"
  write_utf8_text(
    sample_path, "<html><body><article><h1>Profile Title</h1><script>skip()</script><p>Visible body <a href='https://example.com/profile'>link</a><a epub:type='noteref' href='#fn-profile'>1</a>.</p><table><tr><th>K</th><th>V</th></tr><tr><td>A</td><td>B</td></tr></table><aside epub:type='footnote' id='fn-profile'>Profile note.</aside></article></body></html>\n",
  )

  let prev_enabled = @sys.get_env_var("MARKITDOWN_PROFILE_HTML")
  let prev_path = @sys.get_env_var("MARKITDOWN_PROFILE_HTML_PATH")
  defer {
    restore_env_var("MARKITDOWN_PROFILE_HTML", prev_enabled)
    restore_env_var("MARKITDOWN_PROFILE_HTML_PATH", prev_path)
  }
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML", "1")
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML_PATH", profile_path)

  let doc = @html.parse_html(sample_path, "", 6)
  assert_true(@cor.emit_markdown(doc).contains("Visible body"))

  let report = read_html_parser_utf8_text(profile_path)
  assert_true(html_profile_has_stage(report, "html_parser_fact_model"))
  assert_true(report.contains("parser_analysis_attempted=true"))
  assert_true(report.contains("parser_analysis_used=true"))
  assert_true(report.contains("parser_scope_from_events=true"))
  assert_true(report.contains("parser_skip_range_count=0"))
  assert_true(report.contains("parser_scope_source_reason=parser_facts"))
  assert_true(report.contains("semantic_block_count="))
  assert_true(html_profile_counter(report, "semantic_document_node_count") > 0)
  assert_true(html_profile_counter(report, "semantic_block_fact_count") > 0)
  assert_true(html_profile_counter(report, "semantic_inline_fact_count") > 0)
  assert_eq(html_profile_counter(report, "semantic_table_fact_count"), 1)
  assert_true(html_profile_counter(report, "semantic_note_fact_count") >= 1)
  assert_true(html_profile_counter(report, "semantic_noise_fact_count") >= 1)
  assert_true(html_profile_counter(report, "semantic_warning_count") >= 1)
  assert_true(
    html_profile_counter(report, "semantic_estimated_preview_bytes") > 0,
  )
  assert_eq(html_profile_counter(report, "fact_runtime_lowering_attempts"), 1)
  assert_true(report.contains("semantic_heading_count=1"))
  assert_true(report.contains("semantic_table_count=1"))
  assert_true(report.contains("semantic_list_fact_count=0"))
  assert_true(report.contains("semantic_blockquote_fact_count=0"))
  assert_true(report.contains("semantic_code_block_fact_count=0"))
  assert_true(report.contains("semantic_figure_fact_count=0"))
  assert_true(report.contains("semantic_paragraph_fact_count="))
  assert_true(report.contains("semantic_paragraph_with_link_count="))
  assert_true(report.contains("semantic_paragraph_candidate_count="))
  assert_true(report.contains("semantic_paragraph_repeated_whitespace_count="))
  assert_true(report.contains("semantic_repeated_whitespace_inline_count="))
  assert_true(report.contains("semantic_newline_inline_count="))
  assert_true(report.contains("semantic_whitespace_preserving_inline_count="))
  assert_true(report.contains("semantic_inline_with_surrounding_text_count="))
  assert_true(report.contains("semantic_table_fact_count=1"))
  assert_true(report.contains("semantic_table_fact_row_count=2"))
  assert_true(report.contains("semantic_table_fact_cell_count=4"))
  assert_true(report.contains("semantic_table_caption_count=0"))
  assert_true(report.contains("semantic_table_warning_count=0"))
  assert_true(report.contains("semantic_table_span_cell_count=0"))
  assert_true(report.contains("semantic_table_ragged_row_count=0"))
  assert_true(report.contains("semantic_table_nested_cell_count=0"))
  assert_true(report.contains("semantic_table_complex_cell_count=0"))
  assert_true(report.contains("semantic_table_image_cell_count=0"))
  assert_true(report.contains("semantic_inline_count="))
  assert_true(report.contains("semantic_link_fact_count=2"))
  assert_true(report.contains("semantic_image_fact_count=0"))
  assert_true(report.contains("semantic_note_fact_count="))
  assert_true(report.contains("semantic_note_ref_fact_count=1"))
  assert_true(report.contains("semantic_note_body_fact_count=1"))
  assert_true(report.contains("semantic_broken_note_ref_count=0"))
  assert_true(report.contains("semantic_scope_fact_count=1"))
  assert_true(report.contains("semantic_scope_body_count=1"))
  assert_true(report.contains("semantic_scope_missing_body_count=0"))
  assert_true(report.contains("semantic_noise_candidate_count="))
  assert_true(report.contains("semantic_noise_script_style_template_count=1"))
  assert_true(report.contains("semantic_note_ref_inline_count=1"))
  assert_true(report.contains("semantic_warning_info_count="))
  assert_true(report.contains("semantic_warning_warning_count="))
  assert_true(report.contains("semantic_warning_error_count=0"))
  assert_true(report.contains("semantic_unsupported_fact_count="))
  assert_true(report.contains("semantic_unsupported_script_count=1"))
  assert_true(report.contains("semantic_unsupported_remote_image_count=0"))
  assert_true(report.contains("semantic_unsupported_data_image_count=0"))
  assert_true(report.contains("semantic_unsupported_unsafe_url_count=0"))
  assert_true(report.contains("semantic_unsupported_empty_url_count=0"))
  assert_true(report.contains("semantic_lowering_available=true"))
  assert_true(report.contains("semantic_heading_empty_guard_count=0"))
  assert_true(report.contains("semantic_heading_render_mismatch_guard_count=0"))
  assert_true(report.contains("semantic_heading_unsupported_guard_count=0"))
  assert_true(report.contains("semantic_paragraph_empty_guard_count=0"))
  assert_true(
    report.contains("semantic_paragraph_render_mismatch_guard_count=0"),
  )
  assert_true(report.contains("semantic_paragraph_unsupported_guard_count=0"))
  assert_true(report.contains("semantic_blockquote_candidate_count=0"))
  assert_true(report.contains("semantic_code_block_candidate_count=0"))
  assert_true(report.contains("table_count=1"))
  assert_true(report.contains("image_count=0"))
  assert_true(report.contains("link_count=1"))
  assert_true(report.contains("note_definition_count=1"))
  assert_true(report.contains("note_ref_count=1"))
}

///|
test "html profile disabled does not write profile report" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_profile_disabled.html"
  let profile_path = dir + "/html-profile-disabled.txt"
  write_utf8_text(
    sample_path, "<html><body><article><p>No profile output.</p></article></body></html>\n",
  )
  remove_file_if_exists(profile_path)

  let prev_enabled = @sys.get_env_var("MARKITDOWN_PROFILE_HTML")
  let prev_path = @sys.get_env_var("MARKITDOWN_PROFILE_HTML_PATH")
  defer {
    restore_env_var("MARKITDOWN_PROFILE_HTML", prev_enabled)
    restore_env_var("MARKITDOWN_PROFILE_HTML_PATH", prev_path)
  }
  @sys.unset_env_var("MARKITDOWN_PROFILE_HTML")
  @sys.set_env_var("MARKITDOWN_PROFILE_HTML_PATH", profile_path)

  let doc = @html.parse_html(sample_path, "", 6)
  assert_true(@cor.emit_markdown(doc).contains("No profile output."))
  assert_false(@fs.path_exists(profile_path))
}

///|
test "html comments do not leak commented markup into output" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_comment_ignored.html"
  write_utf8_text(
    sample_path, "<article><h1>Visible</h1><p>Before.</p><!-- <section><h2>Hidden</h2><p><a href=\"https://example.com/secret\">Secret Link</a></p></section> --><p>After.</p></article>\n",
  )

  let markdown = @cor.emit_markdown(@html.parse_html(sample_path, "", 6))
  assert_true(markdown.contains("# Visible"))
  assert_true(markdown.contains("Before."))
  assert_true(markdown.contains("After."))
  assert_false(markdown.contains("Hidden"))
  assert_false(markdown.contains("Secret Link"))
  assert_false(markdown.contains("-->"))
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
      "samples/main_process/html/expected/html_semantic_wrappers.md",
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
      "samples/main_process/html/expected/html_table_thead_th.md",
    ),
  )
  assert_eq(@cor.emit_markdown(thead_doc), thead_expected)
  match thead_doc.blocks.val[0] {
    @cor.Block::RichTable(table) => {
      assert_eq(table.header_rows, 1)
      assert_true(table.rows[0] == ["Name", "Score"])
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
      "samples/main_process/html/expected/html_table_cell_br_entities.md",
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
test "html table span boundaries and local image boundaries are explicit" {
  let span_doc = @html.parse_html(
    resolve_html_parser_sample_path(
      "samples/main_process/html/html_table_rowspan_colspan_boundary.html",
    ),
    "",
    6,
  )
  let span_expected = read_html_parser_utf8_text(
    resolve_html_parser_sample_path(
      "samples/main_process/html/expected/html_table_rowspan_colspan_boundary.md",
    ),
  )
  assert_eq(@cor.emit_markdown(span_doc), span_expected)
  match span_doc.blocks.val[0] {
    @cor.Block::RichTable(table) =>
      match table.hints {
        Some(hints) =>
          match hints.span_cells {
            Some(span_cells) => {
              assert_eq(span_cells.length(), 2)
              assert_eq(span_cells[0].row_index, 1)
              assert_eq(span_cells[0].column_index, 1)
              assert_eq(span_cells[0].rowspan, 2)
              assert_eq(span_cells[1].colspan, 2)
            }
            None => fail("expected span_cells hint on HTML span table")
          }
        None => fail("expected table hints on HTML span table")
      }
    _ => fail("span boundary sample should emit RichTable")
  }

  let image_doc = @html.parse_html(
    resolve_html_parser_sample_path(
      "samples/main_process/html/html_image_remote_data_uri_boundary.html",
    ),
    "",
    6,
  )
  let image_expected = read_html_parser_utf8_text(
    resolve_html_parser_sample_path(
      "samples/main_process/html/expected/html_image_remote_data_uri_boundary.md",
    ),
  )
  assert_eq(@cor.emit_markdown(image_doc), image_expected)
}

///|
test "html table list note primitives keep mixed casing and decoded attrs stable" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_mixed_case_table_list_note.html"
  write_utf8_text(
    sample_path, "<HTML><BODY><ARTICLE><TABLE><THEAD><TR><TH>Name&nbsp;A</TH><TH>Score</TH></TR></THEAD><TBODY><TR><TD ROWSPAN='2'>A&amp;B</TD><TD COLSPAN='2'>42</TD></TR><TR><TD>Tail</TD></TR></TBODY></TABLE><OL><LI>One&nbsp;item</LI><LI><UL><LI>Nested item</LI></UL></LI></OL><P>Note<A EPUB:TYPE='noteref' HREF='#fn&amp;1'>1</A>.</P><ASIDE EPUB:TYPE='footnote' ID='fn&amp;1'>Foot&nbsp;note.</ASIDE></ARTICLE></BODY></HTML>\n",
  )

  let doc = @html.parse_html(sample_path, "", 6)
  let markdown = @cor.emit_markdown(doc)
  match doc.blocks.val[0] {
    @cor.Block::RichTable(table) => {
      assert_eq(table.header_rows, 1)
      assert_eq(table.rows[0][0], "Name A")
      assert_eq(table.rows[1][0], "A&B")
      assert_eq(table.rows[1][1], "42")
      match table.hints {
        Some(hints) =>
          match hints.span_cells {
            Some(span_cells) => {
              assert_eq(span_cells.length(), 2)
              assert_eq(span_cells[0].rowspan, 2)
              assert_eq(span_cells[1].colspan, 2)
            }
            None => fail("expected span hints for mixed-case table")
          }
        None => fail("expected hints for mixed-case table")
      }
    }
    _ => fail("mixed-case table should emit RichTable")
  }

  assert_true(markdown.contains("One item"))
  assert_true(markdown.contains("Nested item"))
  assert_true(markdown.contains("Note[^fn&1]."))
  assert_eq(doc.note_definitions.val.length(), 1)
  let note = doc.note_definitions.val[0]
  assert_eq(note.note_id, "fn&1")
  assert_eq(note.marker, "1")
  match note.blocks[0] {
    @cor.Block::Paragraph(text) => assert_eq(text, "Foot note.")
    _ => fail("mixed-case note should keep body text")
  }
}

///|
test "html semantic containers and pre/code entity handling are stable" {
  let semantic_doc = @html.parse_html(
    resolve_html_parser_sample_path(
      "samples/main_process/html/html_semantic_containers.html",
    ),
    "",
    6,
  )
  let semantic_expected = read_html_parser_utf8_text(
    resolve_html_parser_sample_path(
      "samples/main_process/html/expected/html_semantic_containers.md",
    ),
  )
  assert_eq(@cor.emit_markdown(semantic_doc), semantic_expected)

  let code_doc = @html.parse_html(
    resolve_html_parser_sample_path(
      "samples/main_process/html/html_pre_code_entities.html",
    ),
    "",
    6,
  )
  let code_expected = read_html_parser_utf8_text(
    resolve_html_parser_sample_path(
      "samples/main_process/html/expected/html_pre_code_entities.md",
    ),
  )
  assert_eq(@cor.emit_markdown(code_doc), code_expected)
}

///|
test "html text nodes use shared cleanup while pre/code stays literal" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_text_cleanup_probe.html"
  write_utf8_text(
    sample_path, "<p>Alpha&nbsp;Beta\u{2009}Gamma\u{2007}Delta\u{202F}Epsilon\u{200B}Zeta hy\u{00AD}phen ﬁ ﬂ ﬀ ﬃ ﬄ</p>\n<pre>Alpha&nbsp;Beta\u{2009}Gamma\u{200B}hy\u{00AD}phen ﬁ</pre>\n",
  )

  let doc = @html.parse_html(sample_path, "", 6)
  assert_eq(
    @cor.emit_markdown(doc),
    "Alpha Beta Gamma Delta EpsilonZeta hyphen fi fl ff ffi ffl\n\n```\nAlpha Beta\u{2009}Gamma\u{200B}hy\u{00AD}phen ﬁ\n```\n",
  )
  assert_eq(doc.blocks.val.length(), 2)

  match doc.blocks.val[0] {
    @cor.Block::Paragraph(_) =>
      fail("expected shared cleanup probe to preserve rich paragraph text node")
    @cor.Block::RichParagraph(inlines) =>
      match inlines[0] {
        @cor.Inline::Text(text) =>
          assert_eq(
            text, "Alpha Beta Gamma Delta EpsilonZeta hyphen fi fl ff ffi ffl",
          )
        _ => fail("expected cleaned text inline in first html block")
      }
    _ => fail("expected first html block to be a paragraph")
  }

  match doc.blocks.val[1] {
    @cor.Block::CodeBlock(text) =>
      assert_eq(text, "Alpha Beta\u{2009}Gamma\u{200B}hy\u{00AD}phen ﬁ")
    _ => fail("expected second html block to stay a code block")
  }
}

///|
test "html prefers main content and skips nested script style noise" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_main_scope_noise.html"
  write_utf8_text(
    sample_path, "<html><head><title>Ignored title</title><style>.global{display:none}.recommendationsTableTitle{color:red}</style><script>window.headNoise=function(){return 'HEAD_NOISE';}</script></head><body><header><a href=\"/\">Home</a><form><textarea>Search query</textarea><button>Go</button></form><script>window.headerNoise=function(){return 'HEADER_NOISE';}</script></header><main><article><h1>Main Title</h1><p>Visible body <script>window.innerNoise=function(){return 'INNER_NOISE';}</script><style>.inner{color:blue}</style>tail.</p><ul><li>First<script>window.itemNoise=1</script></li><li><a href=\"https://example.com\">Docs</a></li></ul></article></main><footer><p>Privacy and Cookies</p></footer></body></html>\n",
  )

  let doc = @html.parse_html(sample_path, "", 6)
  let markdown = @cor.emit_markdown(doc)

  assert_true(markdown.contains("# Main Title"))
  assert_true(markdown.contains("Visible body tail."))
  assert_true(markdown.contains("- First"))
  assert_true(markdown.contains("[Docs](https://example.com)"))

  assert_false(markdown.contains("HEAD_NOISE"))
  assert_false(markdown.contains("HEADER_NOISE"))
  assert_false(markdown.contains("INNER_NOISE"))
  assert_false(markdown.contains("recommendationsTableTitle"))
  assert_false(markdown.contains("Privacy and Cookies"))
  assert_false(markdown.contains("Search query"))
  assert_false(markdown.contains("Home"))
}

///|
test "html prefers inner content root over main shell chrome" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_inner_content_root_scope.html"
  write_utf8_text(
    sample_path, "<html><body><main id=\"content\"><header><button>Toggle the table of contents</button><div class=\"lang-menu\">154 languages</div></header><div id=\"bodyContent\"><div id=\"mw-content-text\"><div class=\"lead\"><p>Lead summary.</p></div><div class=\"content-body\"><h1>Actual Title</h1><p>Actual article body.</p><ul><li>Fact A</li><li>Fact B</li></ul></div></div></div><footer><p>Footer legal</p></footer></main></body></html>\n",
  )

  let doc = @html.parse_html(sample_path, "", 6)
  let markdown = @cor.emit_markdown(doc)

  assert_true(markdown.contains("Lead summary."))
  assert_true(markdown.contains("# Actual Title"))
  assert_true(markdown.contains("Actual article body."))
  assert_true(markdown.contains("- Fact A"))
  assert_true(markdown.contains("- Fact B"))

  assert_false(markdown.contains("Toggle the table of contents"))
  assert_false(markdown.contains("154 languages"))
  assert_false(markdown.contains("Footer legal"))
}

///|
test "html skips strong-noise containers but preserves ordinary content tables" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_noise_container_pruning.html"
  write_utf8_text(
    sample_path, "<html><body><main><article><header><h1>Article Title</h1></header><div class=\"infobox\"><table><tr><th>Noise</th><td>Skip me</td></tr></table></div><nav role=\"navigation\"><ul><li>Section chrome</li></ul></nav><p>Lead paragraph.</p><table><thead><tr><th>Name</th><th>Score</th></tr></thead><tbody><tr><td>Alice</td><td>42</td></tr></tbody></table><div class=\"navbox\">Related series</div></article></main></body></html>\n",
  )

  let doc = @html.parse_html(sample_path, "", 6)
  let markdown = @cor.emit_markdown(doc)

  assert_true(markdown.contains("# Article Title"))
  assert_true(markdown.contains("Lead paragraph."))
  assert_true(markdown.contains("| Name | Score |"))
  assert_true(markdown.contains("| Alice | 42 |"))

  assert_false(markdown.contains("Skip me"))
  assert_false(markdown.contains("Section chrome"))
  assert_false(markdown.contains("Related series"))
}

///|
test "html preserves toc-nav sections when they contain substantial prose" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_toc_nav_contentful_section.html"
  write_utf8_text(
    sample_path, "<html><body><article><section id=\"toc-nav\"><h2><code>toc nav</code></h2><p>Tests whether the toc nav can be accessed and whether document-level linking works for real reading-system scenarios.</p><p>To complete this test, first bring up the table of contents and activate the glossary link.</p></section></article></body></html>\n",
  )

  let doc = @html.parse_html(sample_path, "", 6)
  let markdown = @cor.emit_markdown(doc)

  assert_true(markdown.contains("## toc nav"))
  assert_true(markdown.contains("Tests whether the toc nav can be accessed"))
  assert_true(markdown.contains("activate the glossary link"))
}

///|
test "html keeps ordinary article header and does not over-prune body content" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_article_header_not_pruned.html"
  write_utf8_text(
    sample_path, "<html><body><article><header><h1>Release Notes</h1><p>Updated May 2026.</p></header><section><p>Main body survives.</p><blockquote><p>Important quote.</p></blockquote></section></article></body></html>\n",
  )

  let doc = @html.parse_html(sample_path, "", 6)
  let markdown = @cor.emit_markdown(doc)

  assert_true(markdown.contains("# Release Notes"))
  assert_true(markdown.contains("Updated May 2026."))
  assert_true(markdown.contains("Main body survives."))
  assert_true(markdown.contains("> Important quote."))
}

///|
test "html token scope keeps nested article tail and skips script style" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_token_scope_nested_article.html"
  write_utf8_text(
    sample_path, "<html><head><title>Ignored</title><script>HEAD_NOISE</script></head><body><p>\u{524D}\u{7F6E} ignored</p><article><h1>Outer Title</h1><article><p>Inner body.</p><script>INNER_NOISE</script><style>.inner{display:none}</style></article><p>Outer tail survives.</p></article><footer><p>Footer noise</p></footer></body></html>\n",
  )

  let doc = @html.parse_html(sample_path, "", 6)
  let markdown = @cor.emit_markdown(doc)

  assert_true(markdown.contains("# Outer Title"))
  assert_true(markdown.contains("Inner body."))
  assert_true(markdown.contains("Outer tail survives."))
  assert_false(markdown.contains("HEAD_NOISE"))
  assert_false(markdown.contains("INNER_NOISE"))
  assert_false(markdown.contains("display:none"))
  assert_false(markdown.contains("ignored"))
  assert_false(markdown.contains("Footer noise"))
}

///|
test "html token skip ranges coexist with scope and preserve pre text" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_token_skip_ranges.html"
  write_utf8_text(
    sample_path, "<html><head><noscript>HEAD_NOSCRIPT</noscript><script>HEAD_SKIP</script><style>.head{}</style></head><body><main><article><h1>Skip Range Title</h1><script>ARTICLE_SKIP</script><style>.article{}</style><noscript><p>NO_SCRIPT_BODY</p></noscript><p>Visible <script>INLINE_SKIP</script>tail.</p><pre><script>literal code</script></pre></article></main><footer>Footer noise</footer></body></html>\n",
  )

  let doc = @html.parse_html(sample_path, "", 6)
  let markdown = @cor.emit_markdown(doc)

  assert_true(markdown.contains("# Skip Range Title"))
  assert_true(markdown.contains("Visible tail."))
  assert_true(markdown.contains("literal code"))
  assert_false(markdown.contains("HEAD_NOSCRIPT"))
  assert_false(markdown.contains("HEAD_SKIP"))
  assert_false(markdown.contains("ARTICLE_SKIP"))
  assert_false(markdown.contains("INLINE_SKIP"))
  assert_false(markdown.contains("NO_SCRIPT_BODY"))
  assert_false(markdown.contains("Footer noise"))
}

///|
test "html prefers strong content root over teaser article shell" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_role_main_beats_teaser_article.html"
  write_utf8_text(
    sample_path, "<html><body><article class=\"summary-card\"><h2>Teaser</h2><p>Short promo.</p></article><div role=\"main\"><h1>Release Plan</h1><p>Actual body.</p></div></body></html>\n",
  )

  let doc = @html.parse_html(sample_path, "", 6)
  let markdown = @cor.emit_markdown(doc)

  assert_true(markdown.contains("# Release Plan"))
  assert_true(markdown.contains("Actual body."))
  assert_false(markdown.contains("Teaser"))
  assert_false(markdown.contains("Short promo."))
}

///|
test "html prefers post content root over outer main chrome" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_post_content_scope.html"
  write_utf8_text(
    sample_path, "<html><body><main><header><a href=\"/\">Home</a><p>Search</p></header><section class=\"post-content\"><h1>Guide</h1><p>Useful text.</p></section><footer><p>Legal</p></footer></main></body></html>\n",
  )

  let doc = @html.parse_html(sample_path, "", 6)
  let markdown = @cor.emit_markdown(doc)

  assert_true(markdown.contains("# Guide"))
  assert_true(markdown.contains("Useful text."))
  assert_false(markdown.contains("Home"))
  assert_false(markdown.contains("Search"))
  assert_false(markdown.contains("Legal"))
}

///|
test "html strong content heuristic skips article footer noise before real body" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_article_footer_noise_scope.html"
  write_utf8_text(
    sample_path, "<html><body><section class=\"content-section article-footer\"><p>Footer CTA</p></section><section class=\"post-content\"><h1>Guide</h1><p>Actual body.</p></section></body></html>\n",
  )

  let doc = @html.parse_html(sample_path, "", 6)
  let markdown = @cor.emit_markdown(doc)

  assert_true(markdown.contains("# Guide"))
  assert_true(markdown.contains("Actual body."))
  assert_false(markdown.contains("Footer CTA"))
}

///|
test "html prefers exact content id over body chrome fallback" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let sample_path = dir + "/html_content_id_scope.html"
  write_utf8_text(
    sample_path, "<html><body><div class=\"site-header\"><p>Docs nav</p></div><div id=\"content\"><h1>FAQ</h1><p>Real answer.</p></div><aside><p>Sidebar tip</p></aside></body></html>\n",
  )

  let doc = @html.parse_html(sample_path, "", 6)
  let markdown = @cor.emit_markdown(doc)

  assert_true(markdown.contains("# FAQ"))
  assert_true(markdown.contains("Real answer."))
  assert_false(markdown.contains("Docs nav"))
  assert_false(markdown.contains("Sidebar tip"))
}

///|
test "html parse_html keeps malformed unsafe signal sample output stable" {
  let doc = @html.parse_html(
    resolve_html_parser_sample_path(
      "samples/main_process/html/html_parser_signal_malformed_unsafe.html",
    ),
    "",
    6,
  )
  let expected = read_html_parser_utf8_text(
    resolve_html_parser_sample_path(
      "samples/main_process/html/expected/html_parser_signal_malformed_unsafe.md",
    ),
  )
  assert_eq(@cor.emit_markdown(doc), expected)
}

///|
fn trim_one_trailing_newline(text : String) -> String {
  if text.has_suffix("\n") {
    text[:text.length() - 1].to_owned()
  } else {
    text
  }
}
