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
test "txt paragraphs stay plain text paragraphs" {
  let sample = resolve_sample_path(
    "samples/main_process/txt/txt_paragraphs.txt",
  )
  let expected = read_utf8_text(
    resolve_sample_path("samples/main_process/expected/txt/txt_paragraphs.md"),
  )

  let doc = @txt.parse_txt(sample, "", 6)
  assert_eq(@cor.emit_markdown(doc), expected)
  assert_eq(doc.blocks.val.length(), 2)

  match doc.blocks.val[0] {
    @cor.Block::Paragraph(text) => assert_eq(text, "First line continues here")
    _ => fail("expected first txt block to be Paragraph")
  }

  match doc.blocks.val[1] {
    @cor.Block::Paragraph(text) =>
      assert_eq(text, "# Not a heading - Not a list")
    _ => fail("expected second txt block to be Paragraph")
  }
}

///|
test "txt normalizes crlf and strips utf8 bom" {
  let crlf_doc = @txt.parse_txt(
    resolve_sample_path("samples/main_process/txt/txt_crlf.txt"),
    "",
    6,
  )
  let crlf_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/expected/txt/txt_crlf.md"),
  )
  assert_eq(@cor.emit_markdown(crlf_doc), crlf_expected)

  let bom_doc = @txt.parse_txt(
    resolve_sample_path("samples/main_process/txt/txt_bom_utf8.txt"),
    "",
    6,
  )
  let bom_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/expected/txt/txt_bom_utf8.md"),
  )
  assert_eq(@cor.emit_markdown(bom_doc), bom_expected)
}

///|
test "txt blank-only input emits empty document" {
  let doc = @txt.parse_txt(
    resolve_sample_path("samples/main_process/txt/txt_empty_lines.txt"),
    "",
    6,
  )
  assert_eq(doc.blocks.val.length(), 0)
  assert_eq(@cor.emit_markdown(doc), "")
}
