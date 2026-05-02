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
test "markdown passthrough preserves basic heading and paragraph" {
  let input = resolve_sample_path(
    "samples/main_process/markdown/markdown_basic_heading_paragraph.md",
  )
  let expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/markdown/markdown_basic_heading_paragraph.md",
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
      "samples/main_process/expected/markdown/markdown_no_trailing_newline.md",
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
      "samples/main_process/expected/markdown/markdown_crlf.md",
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
      "samples/main_process/expected/markdown/markdown_bom_utf8.md",
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
      "samples/main_process/expected/markdown/markdown_ordered_list.md",
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
      "samples/main_process/expected/markdown/markdown_raw_html_literal.md",
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
