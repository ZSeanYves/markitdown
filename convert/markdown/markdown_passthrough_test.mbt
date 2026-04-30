///|
fn resolve_sample_path(path : String) -> String raise {
  if @fs.path_exists(path) {
    return path
  }

  let fallback = "../../" + path
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
test "markdown passthrough preserves basic heading and paragraph" {
  let input = resolve_sample_path(
    "samples/main_process/markdown/markdown_basic_heading_paragraph.md",
  )
  let expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/markdown/markdown_basic_heading_paragraph.md",
    ),
  )

  let doc = parse_markdown(input, "", 6)
  assert_eq(@cor.emit_markdown(doc), expected)
  assert_eq(doc.blocks.val.length(), 2)
  assert_eq(doc.asset_origins.val.length(), 0)
}

///|
test "markdown passthrough preserves fenced code and frontmatter as conservative blocks" {
  let code_doc = parse_markdown(
    resolve_sample_path("samples/main_process/markdown/markdown_code_fence.md"),
    "",
    6,
  )
  assert_eq(code_doc.blocks.val.length(), 1)
  assert_true(code_doc.blocks.val[0] is @cor.Block::CodeBlock(_))

  let frontmatter_doc = parse_markdown(
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
  let doc = parse_markdown(input, "", 6)
  assert_eq(@cor.emit_markdown(doc), expected)
  assert_eq(doc.blocks.val.length(), 1)
}
