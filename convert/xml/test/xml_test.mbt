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
test "xml preserves source as fenced xml block" {
  let sample = resolve_sample_path("samples/main_process/xml/xml_basic.xml")
  let expected = read_utf8_text(
    resolve_sample_path("samples/main_process/expected/xml/xml_basic.md"),
  )

  let doc = @xml.parse_xml(sample, "", 6)
  assert_eq(@cor.emit_markdown(doc), expected)
  assert_eq(doc.blocks.val.length(), 1)
  assert_true(doc.blocks.val[0] is @cor.Block::CodeBlock(_))
}

///|
test "xml normalizes crlf and strips utf8 bom" {
  let crlf_doc = @xml.parse_xml(
    resolve_sample_path("samples/main_process/xml/xml_crlf.xml"),
    "",
    6,
  )
  let crlf_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/expected/xml/xml_crlf.md"),
  )
  assert_eq(@cor.emit_markdown(crlf_doc), crlf_expected)

  let bom_doc = @xml.parse_xml(
    resolve_sample_path("samples/main_process/xml/xml_bom_utf8.xml"),
    "",
    6,
  )
  let bom_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/expected/xml/xml_bom_utf8.md"),
  )
  assert_eq(@cor.emit_markdown(bom_doc), bom_expected)
}

///|
test "xml blank-only input emits empty document" {
  let doc = @xml.parse_xml(
    resolve_sample_path("samples/main_process/xml/xml_blank.xml"),
    "",
    6,
  )
  assert_eq(doc.blocks.val.length(), 0)
  assert_eq(@cor.emit_markdown(doc), "")
}

///|
test "xml grows fence width when source contains triple backticks" {
  let doc = @xml.parse_xml(
    resolve_sample_path("samples/main_process/xml/xml_backticks.xml"),
    "",
    6,
  )
  let expected = read_utf8_text(
    resolve_sample_path("samples/main_process/expected/xml/xml_backticks.md"),
  )
  assert_eq(@cor.emit_markdown(doc), expected)
}
