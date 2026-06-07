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
  ".tmp/convert-xml-test"
}

///|
fn test_tmp_case(name : String) -> String {
  test_tmp_root() + "/" + name
}

///|
fn assert_code_block(block : @cor.Block) -> Unit raise {
  match block {
    @cor.Block::CodeBlock(_) => ()
    _ => fail("expected CodeBlock")
  }
}

///|
fn assert_not_code_block(block : @cor.Block) -> Unit raise {
  match block {
    @cor.Block::CodeBlock(_) => fail("expected non-CodeBlock")
    _ => ()
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
fn cleanup_temp_dir(path : String) -> Unit {
  ignore(try? remove_dir_recursive(path))
}

///|
fn write_bytes(path : String, bytes : Bytes) -> Unit raise {
  @fs.write_bytes_to_file(path, bytes) catch {
    e => fail("write sample failed: " + e.to_string())
  }
}

///|
test "xml converts simple source to structured blocks" {
  let sample = resolve_sample_path("samples/main_process/xml/xml_basic.xml")
  let expected = read_utf8_text(
    resolve_sample_path("samples/main_process/xml/expected/xml_basic.md"),
  )

  let doc = @xml.parse_xml(sample, "", 6)
  assert_eq(@cor.emit_markdown(doc), expected)
  assert_true(doc.blocks.val.length() > 1)
  assert_not_code_block(doc.blocks.val[0])
}

///|
test "xml normalizes crlf and strips utf8 bom" {
  let crlf_doc = @xml.parse_xml(
    resolve_sample_path("samples/main_process/xml/xml_crlf.xml"),
    "",
    6,
  )
  let crlf_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/xml/expected/xml_crlf.md"),
  )
  assert_eq(@cor.emit_markdown(crlf_doc), crlf_expected)

  let bom_doc = @xml.parse_xml(
    resolve_sample_path("samples/main_process/xml/xml_bom_utf8.xml"),
    "",
    6,
  )
  let bom_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/xml/expected/xml_bom_utf8.md"),
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
test "xml grows fence width for mixed content fallback with triple backticks" {
  let doc = @xml.parse_xml(
    resolve_sample_path("samples/main_process/xml/xml_backticks.xml"),
    "",
    6,
  )
  let expected = read_utf8_text(
    resolve_sample_path("samples/main_process/xml/expected/xml_backticks.md"),
  )
  assert_eq(@cor.emit_markdown(doc), expected)
  assert_code_block(doc.blocks.val[0])
}

///|
test "xml structures declarations comments and attributes while doctype falls back" {
  let declaration_doc = @xml.parse_xml(
    resolve_sample_path("samples/main_process/xml/xml_declaration.xml"),
    "",
    6,
  )
  let declaration_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/xml/expected/xml_declaration.md"),
  )
  assert_eq(@cor.emit_markdown(declaration_doc), declaration_expected)
  assert_not_code_block(declaration_doc.blocks.val[0])

  let comments_doc = @xml.parse_xml(
    resolve_sample_path("samples/main_process/xml/xml_comments.xml"),
    "",
    6,
  )
  let comments_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/xml/expected/xml_comments.md"),
  )
  assert_eq(@cor.emit_markdown(comments_doc), comments_expected)
  assert_not_code_block(comments_doc.blocks.val[0])

  let attributes_doc = @xml.parse_xml(
    resolve_sample_path("samples/main_process/xml/xml_attributes.xml"),
    "",
    6,
  )
  let attributes_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/xml/expected/xml_attributes.md"),
  )
  assert_eq(@cor.emit_markdown(attributes_doc), attributes_expected)
  let attributes_markdown = @cor.emit_markdown(attributes_doc)
  assert_true(attributes_markdown.contains("@id: r1"))
  assert_true(attributes_markdown.contains("@priority: high"))

  let doctype_doc = @xml.parse_xml(
    resolve_sample_path(
      "samples/main_process/xml/xml_doctype_entity_literal.xml",
    ),
    "",
    6,
  )
  let doctype_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/xml/expected/xml_doctype_entity_literal.md",
    ),
  )
  assert_eq(@cor.emit_markdown(doctype_doc), doctype_expected)
  assert_code_block(doctype_doc.blocks.val[0])
}

///|
test "xml preserves markdown-sensitive text and multiline nesting structurally" {
  let markdown_doc = @xml.parse_xml(
    resolve_sample_path(
      "samples/main_process/xml/xml_markdown_sensitive_chars.xml",
    ),
    "",
    6,
  )
  let markdown_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/xml/expected/xml_markdown_sensitive_chars.md",
    ),
  )
  assert_eq(@cor.emit_markdown(markdown_doc), markdown_expected)
  assert_not_code_block(markdown_doc.blocks.val[0])

  let nested_doc = @xml.parse_xml(
    resolve_sample_path("samples/main_process/xml/xml_nested.xml"),
    "",
    6,
  )
  let nested_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/xml/expected/xml_nested.md"),
  )
  assert_eq(@cor.emit_markdown(nested_doc), nested_expected)
  let nested_markdown = @cor.emit_markdown(nested_doc)
  assert_true(nested_markdown.contains("item: One"))
  assert_true(nested_markdown.contains("item: Two"))
}

///|
test "xml structured output covers processing instruction cdata namespace and entity refs fallback" {
  let pi_doc = @xml.parse_xml(
    resolve_sample_path(
      "samples/main_process/xml/xml_processing_instruction.xml",
    ),
    "",
    6,
  )
  let pi_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/xml/expected/xml_processing_instruction.md",
    ),
  )
  assert_eq(@cor.emit_markdown(pi_doc), pi_expected)
  assert_not_code_block(pi_doc.blocks.val[0])

  let cdata_doc = @xml.parse_xml(
    resolve_sample_path("samples/main_process/xml/xml_cdata.xml"),
    "",
    6,
  )
  let cdata_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/xml/expected/xml_cdata.md"),
  )
  assert_eq(@cor.emit_markdown(cdata_doc), cdata_expected)
  assert_true(@cor.emit_markdown(cdata_doc).contains("<not-a-tag>&still-text;"))

  let namespace_doc = @xml.parse_xml(
    resolve_sample_path("samples/main_process/xml/xml_namespace_syntax.xml"),
    "",
    6,
  )
  let namespace_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/xml/expected/xml_namespace_syntax.md",
    ),
  )
  assert_eq(@cor.emit_markdown(namespace_doc), namespace_expected)
  assert_true(@cor.emit_markdown(namespace_doc).contains("<x:root>"))
  assert_true(@cor.emit_markdown(namespace_doc).contains("x:item: Namespaced"))

  let entity_doc = @xml.parse_xml(
    resolve_sample_path("samples/main_process/xml/xml_entity_refs_literal.xml"),
    "",
    6,
  )
  let entity_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/xml/expected/xml_entity_refs_literal.md",
    ),
  )
  assert_eq(@cor.emit_markdown(entity_doc), entity_expected)
  assert_code_block(entity_doc.blocks.val[0])
  assert_true(@cor.emit_markdown(entity_doc).contains("&custom;"))
  assert_true(@cor.emit_markdown(entity_doc).contains("&#169;"))
}

///|
test "xml mixed content and malformed sources fall back to fenced xml" {
  let out_dir = test_tmp_case("fallback")
  ensure_dir_tree(out_dir)
  defer cleanup_temp_dir(out_dir)

  let mixed_path = out_dir + "/xml_mixed.xml"
  @fs.write_string_to_file(
    mixed_path,
    "<root>before <b>bold</b> after</root>",
    encoding="utf8",
  ) catch {
    e => fail("write mixed sample failed: " + e.to_string())
  }
  let mixed_doc = @xml.parse_xml(mixed_path, "", 6)
  assert_eq(
    @cor.emit_markdown(mixed_doc),
    "```xml\n<root>before <b>bold</b> after</root>\n```\n",
  )
  assert_code_block(mixed_doc.blocks.val[0])

  let malformed_path = out_dir + "/xml_malformed.xml"
  @fs.write_string_to_file(
    malformed_path,
    "<root><item></root>",
    encoding="utf8",
  ) catch {
    e => fail("write malformed sample failed: " + e.to_string())
  }
  let malformed_doc = @xml.parse_xml(malformed_path, "", 6)
  assert_eq(
    @cor.emit_markdown(malformed_doc),
    "```xml\n<root><item></root>\n```\n",
  )
  assert_code_block(malformed_doc.blocks.val[0])
}

///|
test "xml conservative structured guards fall back to fenced xml" {
  let out_dir = test_tmp_case("conservative-fallback")
  ensure_dir_tree(out_dir)
  defer cleanup_temp_dir(out_dir)

  let default_ns_path = out_dir + "/xml_default_namespace.xml"
  @fs.write_string_to_file(
    default_ns_path,
    "<root xmlns=\"urn:test\"><item>Namespaced</item></root>",
    encoding="utf8",
  ) catch {
    e => fail("write default namespace sample failed: " + e.to_string())
  }
  let default_ns_doc = @xml.parse_xml(default_ns_path, "", 6)
  assert_eq(
    @cor.emit_markdown(default_ns_doc),
    "```xml\n<root xmlns=\"urn:test\"><item>Namespaced</item></root>\n```\n",
  )
  assert_code_block(default_ns_doc.blocks.val[0])

  let long_attr_path = out_dir + "/xml_long_attr.xml"
  let long_attr_value = "x".repeat(600)
  @fs.write_string_to_file(
    long_attr_path,
    "<root value=\"" + long_attr_value + "\" />",
    encoding="utf8",
  ) catch {
    e => fail("write long attribute sample failed: " + e.to_string())
  }
  let long_attr_doc = @xml.parse_xml(long_attr_path, "", 6)
  assert_code_block(long_attr_doc.blocks.val[0])
  assert_true(@cor.emit_markdown(long_attr_doc).contains(long_attr_value))

  let long_text_path = out_dir + "/xml_long_text.xml"
  let long_text_value = "y".repeat(600)
  @fs.write_string_to_file(
    long_text_path,
    "<root><body>" + long_text_value + "</body></root>",
    encoding="utf8",
  ) catch {
    e => fail("write long text sample failed: " + e.to_string())
  }
  let long_text_doc = @xml.parse_xml(long_text_path, "", 6)
  assert_code_block(long_text_doc.blocks.val[0])
  assert_true(@cor.emit_markdown(long_text_doc).contains(long_text_value))
}

///|
test "xml large guard falls back before structured parse" {
  let out_dir = test_tmp_case("large")
  ensure_dir_tree(out_dir)
  defer cleanup_temp_dir(out_dir)

  let large_path = out_dir + "/xml_large.xml"
  let out = StringBuilder::new()
  out.write_string("<root>\n")
  for i in 0..<75000 {
    out.write_string("  <item>")
    out.write_string(i.to_string())
    out.write_string("012345678901234567890123456789</item>\n")
  }
  out.write_string("</root>\n")
  @fs.write_string_to_file(large_path, out.to_string(), encoding="utf8") catch {
    e => fail("write large sample failed: " + e.to_string())
  }

  let doc = @xml.parse_xml(large_path, "", 6)
  assert_eq(doc.blocks.val.length(), 1)
  assert_code_block(doc.blocks.val[0])
  assert_true(@cor.emit_markdown(doc).has_prefix("```xml\n<root>\n"))
  assert_true(
    @cor.emit_markdown(doc).contains("74999012345678901234567890123456789"),
  )
}

///|
test "xml honors declared latin1 and utf16 source encodings" {
  let out_dir = test_tmp_case("encoding")
  ensure_dir_tree(out_dir)
  defer cleanup_temp_dir(out_dir)

  let latin1_path = out_dir + "/xml_latin1_decl.xml"
  write_bytes(
    latin1_path,
    Bytes::from_array([
      0x3C, 0x3F, 0x78, 0x6D, 0x6C, 0x20, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6F, 0x6E,
      0x3D, 0x22, 0x31, 0x2E, 0x30, 0x22, 0x20, 0x65, 0x6E, 0x63, 0x6F, 0x64, 0x69,
      0x6E, 0x67, 0x3D, 0x22, 0x69, 0x73, 0x6F, 0x2D, 0x38, 0x38, 0x35, 0x39, 0x2D,
      0x31, 0x22, 0x3F, 0x3E, 0x0A, 0x3C, 0x72, 0x6F, 0x6F, 0x74, 0x3E, 0x63, 0x61,
      0x66, 0xE9, 0x20, 0x26, 0x20, 0x70, 0x69, 0xF1, 0x61, 0x74, 0x61, 0x3C, 0x2F,
      0x72, 0x6F, 0x6F, 0x74, 0x3E, 0x0A,
    ]),
  )
  let latin1_doc = @xml.parse_xml(latin1_path, "", 6)
  assert_eq(
    @cor.emit_markdown(latin1_doc),
    "```xml\n<?xml version=\"1.0\" encoding=\"iso-8859-1\"?>\n<root>café & piñata</root>\n```\n",
  )
  assert_code_block(latin1_doc.blocks.val[0])

  let utf16_path = out_dir + "/xml_utf16_decl.xml"
  let utf16_source = "<?xml version=\"1.0\" encoding=\"UTF-16\"?>\n<root>Wide</root>\n"
  write_bytes(
    utf16_path,
    @utf16.encode(utf16_source, bom=true, endianness=@utf16.Endian::Little),
  )
  let utf16_doc = @xml.parse_xml(utf16_path, "", 6)
  assert_eq(@cor.emit_markdown(utf16_doc), "# <root>\n\n- Wide\n")
  assert_not_code_block(utf16_doc.blocks.val[0])
}
