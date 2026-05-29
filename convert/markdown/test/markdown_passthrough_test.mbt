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
fn test_tmp_root() -> String {
  ".tmp/convert-markdown-test"
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
fn write_bytes(path : String, bytes : Bytes) -> Unit raise {
  @fs.write_bytes_to_file(path, bytes) catch {
    e => fail("write sample failed: " + e.to_string())
  }
}

///|
fn write_utf8_text(path : String, text : String) -> Unit raise {
  @fs.write_string_to_file(path, text, encoding="utf8") catch {
    e => fail("write sample failed: " + e.to_string())
  }
}

///|
fn markdown_inline_text_for_test(inlines : Array[@cor.Inline]) -> String {
  let out = StringBuilder::new()
  for inline in inlines {
    match inline {
      @cor.Inline::Text(text) => out.write_string(text)
      @cor.Inline::Break => out.write_string("\n")
      @cor.Inline::Link(text, _href) => out.write_string(text)
      @cor.Inline::NoteRef(note) =>
        if note.body_status == @cor.NoteBodyStatus::Resolved &&
          note.note_id.trim() != "" {
          out.write_string("[^" + note.note_id.trim().to_owned() + "]")
        } else if note.marker.trim() != "" {
          if note.marker.has_prefix("^") {
            out.write_string(note.marker)
          } else {
            out.write_string("^" + note.marker)
          }
        }
    }
  }
  out.to_string()
}

///|
test "markdown passthrough preserves basic heading and paragraph" {
  let input = resolve_sample_path(
    "samples/main_process/markdown/markdown_basic_heading_paragraph.md",
  )
  let expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/markdown/expected/markdown_basic_heading_paragraph.md",
    ),
  )

  let doc = @md.parse_markdown(input, "", 6)
  assert_eq(@cor.emit_markdown(doc), expected)
  assert_eq(doc.blocks.val.length(), 2)
  assert_eq(doc.asset_origins.val.length(), 0)
}

///|
test "markdown passthrough preserves fenced code and frontmatter as conservative blocks" {
  let code_doc = @md.parse_markdown(
    resolve_sample_path("samples/main_process/markdown/markdown_code_fence.md"),
    "",
    6,
  )
  assert_eq(code_doc.blocks.val.length(), 1)
  assert_true(code_doc.blocks.val[0] is @cor.Block::CodeBlock(_))

  let frontmatter_doc = @md.parse_markdown(
    resolve_sample_path(
      "samples/main_process/markdown/markdown_frontmatter_passthrough.markdown",
    ),
    "",
    6,
  )
  assert_eq(frontmatter_doc.blocks.val.length(), 3)
  assert_true(frontmatter_doc.blocks.val[0] is @cor.Block::Paragraph(_))
}

///|
test "markdown passthrough normalizes missing trailing newline only at output" {
  let input = resolve_sample_path(
    "samples/main_process/markdown/markdown_no_trailing_newline.md",
  )
  let raw = read_utf8_text(input)
  assert_true(!raw.has_suffix("\n"))

  let expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/markdown/expected/markdown_no_trailing_newline.md",
    ),
  )
  let doc = @md.parse_markdown(input, "", 6)
  assert_eq(@cor.emit_markdown(doc), expected)
  assert_eq(doc.blocks.val.length(), 1)
}

///|
test "markdown normalizes crlf and strips utf8 bom" {
  let crlf_doc = @md.parse_markdown(
    resolve_sample_path("samples/main_process/markdown/markdown_crlf.md"),
    "",
    6,
  )
  let crlf_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/markdown/expected/markdown_crlf.md",
    ),
  )
  assert_eq(@cor.emit_markdown(crlf_doc), crlf_expected)

  let bom_doc = @md.parse_markdown(
    resolve_sample_path("samples/main_process/markdown/markdown_bom_utf8.md"),
    "",
    6,
  )
  let bom_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/markdown/expected/markdown_bom_utf8.md",
    ),
  )
  assert_eq(@cor.emit_markdown(bom_doc), bom_expected)
}

///|
test "markdown passthrough preserves literal markdown constructs" {
  let ordered_doc = @md.parse_markdown(
    resolve_sample_path(
      "samples/main_process/markdown/markdown_ordered_list.md",
    ),
    "",
    6,
  )
  let ordered_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/markdown/expected/markdown_ordered_list.md",
    ),
  )
  assert_eq(@cor.emit_markdown(ordered_doc), ordered_expected)

  let html_doc = @md.parse_markdown(
    resolve_sample_path(
      "samples/main_process/markdown/markdown_raw_html_literal.md",
    ),
    "",
    6,
  )
  let html_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/markdown/expected/markdown_raw_html_literal.md",
    ),
  )
  assert_eq(@cor.emit_markdown(html_doc), html_expected)
}

///|
test "markdown true empty file and cr-only input normalize conservatively" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let empty_path = dir + "/markdown_true_empty.md"
  write_bytes(empty_path, Bytes::from_array([]))
  let empty_doc = @md.parse_markdown(empty_path, "", 6)
  assert_eq(empty_doc.blocks.val.length(), 0)
  assert_eq(@cor.emit_markdown(empty_doc), "")

  let cr_only_path = dir + "/markdown_cr_only.md"
  write_bytes(cr_only_path, Bytes::from_array([35, 32, 65, 13, 13, 66]))
  let cr_only_doc = @md.parse_markdown(cr_only_path, "", 6)
  assert_eq(@cor.emit_markdown(cr_only_doc), "# A\n\nB\n")
  assert_eq(cr_only_doc.blocks.val.length(), 2)
}

///|
test "markdown footnotes map to unified note ir and preserve full output" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)
  let path = dir + "/markdown_footnote_basic.md"
  write_utf8_text(path, "Text with note[^1].\n\n[^1]: Footnote body.\n")

  let doc = @md.parse_markdown(path, "", 6)
  assert_eq(
    @cor.emit_markdown(doc),
    "Text with note[^1].\n\n[^1]: Footnote body.\n",
  )
  assert_eq(doc.note_definitions.val.length(), 1)
  match doc.blocks.val[0] {
    @cor.Block::RichParagraph(inlines) => {
      assert_eq(markdown_inline_text_for_test(inlines), "Text with note[^1].")
      match inlines[1] {
        @cor.Inline::NoteRef(note) => {
          assert_eq(note.note_id, "1")
          assert_eq(note.marker, "1")
          assert_true(note.kind == @cor.NoteKind::Footnote)
          assert_true(
            note.source_kind == @cor.NoteSourceKind::MarkdownFootnoteRef,
          )
          assert_true(note.body_status == @cor.NoteBodyStatus::Resolved)
        }
        _ => fail("expected markdown footnote ref inline")
      }
    }
    _ => fail("expected markdown footnote paragraph to become rich paragraph")
  }
  let definition = doc.note_definitions.val[0]
  assert_eq(definition.note_id, "1")
  assert_eq(definition.marker, "1")
  assert_true(definition.kind == @cor.NoteKind::Footnote)
  assert_true(
    definition.source_kind == @cor.NoteSourceKind::MarkdownFootnoteBody,
  )
  assert_true(definition.body_status == @cor.NoteBodyStatus::Resolved)
}

///|
test "markdown missing footnote body falls back to marker-only output" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)
  let path = dir + "/markdown_footnote_missing.md"
  write_utf8_text(path, "Text with note[^missing].\n")

  let doc = @md.parse_markdown(path, "", 6)
  assert_eq(@cor.emit_markdown(doc), "Text with note^missing.\n")
  assert_eq(doc.note_definitions.val.length(), 0)
  match doc.blocks.val[0] {
    @cor.Block::RichParagraph(inlines) => {
      assert_eq(
        markdown_inline_text_for_test(inlines),
        "Text with note^missing.",
      )
      match inlines[1] {
        @cor.Inline::NoteRef(note) => {
          assert_eq(note.note_id, "missing")
          assert_eq(note.marker, "missing")
          assert_true(note.body_status == @cor.NoteBodyStatus::Missing)
        }
        _ => fail("expected markdown footnote ref inline")
      }
    }
    _ =>
      fail(
        "expected markdown missing-footnote paragraph to become rich paragraph",
      )
  }
}

///|
test "markdown multiline paragraph keeps cached missing footnote refs" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)
  let path = dir + "/markdown_footnote_missing_multiline.md"
  write_utf8_text(path, "Text with note[^missing]\nwrapped to second line.\n")

  let doc = @md.parse_markdown(path, "", 6)
  assert_eq(
    @cor.emit_markdown(doc),
    "Text with note^missing\nwrapped to second line.\n",
  )
  match doc.blocks.val[0] {
    @cor.Block::RichParagraph(inlines) => {
      assert_eq(
        markdown_inline_text_for_test(inlines),
        "Text with note^missing\nwrapped to second line.",
      )
      assert_true(inlines[2] is @cor.Inline::Break)
      match inlines[1] {
        @cor.Inline::NoteRef(note) => {
          assert_eq(note.note_id, "missing")
          assert_true(note.body_status == @cor.NoteBodyStatus::Missing)
        }
        _ => fail("expected markdown multiline footnote ref inline")
      }
    }
    _ =>
      fail("expected markdown multiline missing-footnote paragraph to be rich")
  }
}

///|
test "markdown orphan footnote definition stays stable and is recorded in note definitions" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)
  let path = dir + "/markdown_footnote_orphan.md"
  write_utf8_text(path, "[^orphan]: Orphan note.\n")

  let doc = @md.parse_markdown(path, "", 6)
  assert_eq(@cor.emit_markdown(doc), "[^orphan]: Orphan note.\n")
  assert_eq(doc.note_definitions.val.length(), 1)
  assert_eq(doc.note_definitions.val[0].note_id, "orphan")
}

///|
test "markdown code fence inline code and reference links do not misparse footnotes" {
  let dir = test_tmp_root()
  ensure_dir_tree(dir)

  let fence_path = dir + "/markdown_footnote_code_fence.md"
  write_utf8_text(fence_path, "```\n[^1]: not a note\n```\n")
  let fence_doc = @md.parse_markdown(fence_path, "", 6)
  assert_eq(@cor.emit_markdown(fence_doc), "```\n[^1]: not a note\n```\n")
  assert_eq(fence_doc.note_definitions.val.length(), 0)
  assert_true(fence_doc.blocks.val[0] is @cor.Block::CodeBlock(_))

  let inline_code_path = dir + "/markdown_footnote_inline_code.md"
  write_utf8_text(
    inline_code_path, "Use `[^1]` literally.\n\n[^1]: Footnote body.\n",
  )
  let inline_code_doc = @md.parse_markdown(inline_code_path, "", 6)
  assert_eq(
    @cor.emit_markdown(inline_code_doc),
    "Use `[^1]` literally.\n\n[^1]: Footnote body.\n",
  )
  assert_eq(inline_code_doc.note_definitions.val.length(), 1)
  assert_true(inline_code_doc.blocks.val[0] is @cor.Block::Paragraph(_))

  let ref_link_path = dir + "/markdown_reference_link.md"
  write_utf8_text(ref_link_path, "[foo]: https://example.com\n")
  let ref_link_doc = @md.parse_markdown(ref_link_path, "", 6)
  assert_eq(@cor.emit_markdown(ref_link_doc), "[foo]: https://example.com\n")
  assert_eq(ref_link_doc.note_definitions.val.length(), 0)
}
