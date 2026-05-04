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
fn write_utf8_text(path : String, text : String) -> Unit raise {
  @fs.write_string_to_file(path, text, encoding="utf8") catch {
    e => fail("write sample failed: " + e.to_string())
  }
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
fn test_tmp_root() -> String {
  ".tmp"
}

///|
fn ensure_test_tmp_root() -> Unit raise {
  ensure_dir_tree(test_tmp_root())
}

///|
fn xml_test_root() -> String raise {
  ensure_test_tmp_root()
  let dir = test_tmp_root() + "/xml-test"
  ensure_dir(dir)
  dir
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
fn cleanup_temp_dir(path : String) -> Unit {
  ignore(try? remove_dir_recursive(path))
}

///|
fn assert_event_kind_name(
  event : @xml.XmlEvent,
  expected_name : String,
) -> Unit raise {
  match event {
    @xml.XmlEvent::Declaration(_, _, _) =>
      assert_eq(expected_name, "Declaration")
    @xml.XmlEvent::ProcessingInstruction(_, _, _, _) =>
      assert_eq(expected_name, "ProcessingInstruction")
    @xml.XmlEvent::StartTag(_, _, _, _) => assert_eq(expected_name, "StartTag")
    @xml.XmlEvent::EndTag(_, _, _) => assert_eq(expected_name, "EndTag")
    @xml.XmlEvent::EmptyElementTag(_, _, _, _) =>
      assert_eq(expected_name, "EmptyElementTag")
    @xml.XmlEvent::Text(_, _, _) => assert_eq(expected_name, "Text")
    @xml.XmlEvent::Comment(_, _, _) => assert_eq(expected_name, "Comment")
    @xml.XmlEvent::CData(_, _, _) => assert_eq(expected_name, "CData")
    @xml.XmlEvent::Doctype(_, _, _) => assert_eq(expected_name, "Doctype")
    @xml.XmlEvent::EntityRef(_, _, _) => assert_eq(expected_name, "EntityRef")
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

///|
test "xml preserves declarations comments attributes and doctype literally" {
  let declaration_doc = @xml.parse_xml(
    resolve_sample_path("samples/main_process/xml/xml_declaration.xml"),
    "",
    6,
  )
  let declaration_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/expected/xml/xml_declaration.md"),
  )
  assert_eq(@cor.emit_markdown(declaration_doc), declaration_expected)

  let comments_doc = @xml.parse_xml(
    resolve_sample_path("samples/main_process/xml/xml_comments.xml"),
    "",
    6,
  )
  let comments_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/expected/xml/xml_comments.md"),
  )
  assert_eq(@cor.emit_markdown(comments_doc), comments_expected)

  let attributes_doc = @xml.parse_xml(
    resolve_sample_path("samples/main_process/xml/xml_attributes.xml"),
    "",
    6,
  )
  let attributes_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/expected/xml/xml_attributes.md"),
  )
  assert_eq(@cor.emit_markdown(attributes_doc), attributes_expected)

  let doctype_doc = @xml.parse_xml(
    resolve_sample_path(
      "samples/main_process/xml/xml_doctype_entity_literal.xml",
    ),
    "",
    6,
  )
  let doctype_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/xml/xml_doctype_entity_literal.md",
    ),
  )
  assert_eq(@cor.emit_markdown(doctype_doc), doctype_expected)
}

///|
test "xml preserves markdown-sensitive text and multiline nesting" {
  let markdown_doc = @xml.parse_xml(
    resolve_sample_path(
      "samples/main_process/xml/xml_markdown_sensitive_chars.xml",
    ),
    "",
    6,
  )
  let markdown_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/xml/xml_markdown_sensitive_chars.md",
    ),
  )
  assert_eq(@cor.emit_markdown(markdown_doc), markdown_expected)

  let nested_doc = @xml.parse_xml(
    resolve_sample_path("samples/main_process/xml/xml_nested.xml"),
    "",
    6,
  )
  let nested_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/expected/xml/xml_nested.md"),
  )
  assert_eq(@cor.emit_markdown(nested_doc), nested_expected)
}

///|
test "xml source preserving covers processing instruction cdata namespace and entity refs" {
  let pi_doc = @xml.parse_xml(
    resolve_sample_path(
      "samples/main_process/xml/xml_processing_instruction.xml",
    ),
    "",
    6,
  )
  let pi_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/xml/xml_processing_instruction.md",
    ),
  )
  assert_eq(@cor.emit_markdown(pi_doc), pi_expected)

  let cdata_doc = @xml.parse_xml(
    resolve_sample_path("samples/main_process/xml/xml_cdata.xml"),
    "",
    6,
  )
  let cdata_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/expected/xml/xml_cdata.md"),
  )
  assert_eq(@cor.emit_markdown(cdata_doc), cdata_expected)

  let namespace_doc = @xml.parse_xml(
    resolve_sample_path("samples/main_process/xml/xml_namespace_syntax.xml"),
    "",
    6,
  )
  let namespace_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/xml/xml_namespace_syntax.md",
    ),
  )
  assert_eq(@cor.emit_markdown(namespace_doc), namespace_expected)

  let entity_doc = @xml.parse_xml(
    resolve_sample_path("samples/main_process/xml/xml_entity_refs_literal.xml"),
    "",
    6,
  )
  let entity_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/xml/xml_entity_refs_literal.md",
    ),
  )
  assert_eq(@cor.emit_markdown(entity_doc), entity_expected)
}

///|
test "xml tokenizer emits safe event surface for valid syntax" {
  let events = @xml.tokenize_xml_text(
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
    "<?xml-stylesheet type=\"text/xsl\" href=\"style.xsl\"?>\n" +
    "<!DOCTYPE note SYSTEM \"note.dtd\">\n" +
    "<x:root xmlns:x=\"urn:test\">\n" +
    "  <!-- comment -->\n" +
    "  <item id=\"1\" name='x'>Hello &amp; <![CDATA[<not-tag>]]><br/></item>\n" +
    "</x:root>\n",
  )

  assert_eq(events.length(), 20)
  assert_event_kind_name(events[0], "Declaration")
  assert_event_kind_name(events[1], "Text")
  assert_event_kind_name(events[2], "ProcessingInstruction")
  assert_event_kind_name(events[3], "Text")
  assert_event_kind_name(events[4], "Doctype")
  assert_event_kind_name(events[5], "Text")
  assert_event_kind_name(events[6], "StartTag")
  assert_event_kind_name(events[7], "Text")
  assert_event_kind_name(events[8], "Comment")
  assert_event_kind_name(events[9], "Text")
  assert_event_kind_name(events[10], "StartTag")
  assert_event_kind_name(events[11], "Text")
  assert_event_kind_name(events[12], "EntityRef")
  assert_event_kind_name(events[13], "Text")
  assert_event_kind_name(events[14], "CData")
  assert_event_kind_name(events[15], "EmptyElementTag")
  assert_event_kind_name(events[16], "EndTag")
  assert_event_kind_name(events[17], "Text")
  assert_event_kind_name(events[18], "EndTag")

  match events[2] {
    @xml.XmlEvent::ProcessingInstruction(name, body, line_start, line_end) => {
      assert_eq(name, "xml-stylesheet")
      assert_eq(body, "type=\"text/xsl\" href=\"style.xsl\"")
      assert_eq(line_start, 2)
      assert_eq(line_end, 2)
    }
    _ => fail("expected processing instruction event")
  }

  match events[6] {
    @xml.XmlEvent::StartTag(name, attrs, line_start, line_end) => {
      assert_eq(name, "x:root")
      assert_eq(attrs.length(), 1)
      assert_eq(attrs[0], ("xmlns:x", "urn:test"))
      assert_eq(line_start, 4)
      assert_eq(line_end, 4)
    }
    _ => fail("expected start-tag event")
  }

  match events[10] {
    @xml.XmlEvent::StartTag(name, attrs, _, _) => {
      assert_eq(name, "item")
      assert_eq(attrs.length(), 2)
      assert_eq(attrs[0], ("id", "1"))
      assert_eq(attrs[1], ("name", "x"))
    }
    _ => fail("expected item start-tag event")
  }

  match events[12] {
    @xml.XmlEvent::EntityRef(text, line_start, line_end) => {
      assert_eq(text, "&amp;")
      assert_eq(line_start, 6)
      assert_eq(line_end, 6)
    }
    _ => fail("expected entity-ref event")
  }

  match events[14] {
    @xml.XmlEvent::CData(text, line_start, line_end) => {
      assert_eq(text, "<not-tag>")
      assert_eq(line_start, 6)
      assert_eq(line_end, 6)
    }
    _ => fail("expected cdata event")
  }
}

///|
test "xml tokenizer handles line tracking and empty tags" {
  let events = @xml.tokenize_xml_text(
    "<root>\r\n  <br/>\r\n  <child>ok</child>\r\n</root>\r\n",
  )

  assert_eq(events.length(), 10)
  match events[2] {
    @xml.XmlEvent::EmptyElementTag(name, attrs, line_start, line_end) => {
      assert_eq(name, "br")
      assert_eq(attrs.length(), 0)
      assert_eq(line_start, 2)
      assert_eq(line_end, 2)
    }
    _ => fail("expected empty-element event")
  }

  match events[4] {
    @xml.XmlEvent::StartTag(name, _, line_start, line_end) => {
      assert_eq(name, "child")
      assert_eq(line_start, 3)
      assert_eq(line_end, 3)
    }
    _ => fail("expected child start-tag")
  }

  match events[5] {
    @xml.XmlEvent::Text(text, line_start, line_end) => {
      assert_eq(text, "ok")
      assert_eq(line_start, 3)
      assert_eq(line_end, 3)
    }
    _ => fail("expected text event")
  }
}

///|
test "xml tokenizer rejects malformed syntax and mismatched tags" {
  let root = xml_test_root()
  let out_dir = root + "/malformed"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let cases : Array[(String, String)] = [
    ("unclosed_tag.xml", "<root><child></root>\n"),
    ("mismatched_closing.xml", "<root><a></b></root>\n"),
    ("unclosed_comment.xml", "<root><!-- no end</root>\n"),
    ("unclosed_cdata.xml", "<root><![CDATA[broken</root>\n"),
    ("unquoted_attr.xml", "<root a=1></root>\n"),
    ("bad_attr.xml", "<root a \"1\"></root>\n"),
    ("bad_pi.xml", "<?broken\n"),
    ("bad_doctype.xml", "<!DOCTYPE note [ <!ENTITY a \"x\"> \n"),
  ]

  for i in 0..<cases.length() {
    let (name, text) = cases[i]
    let path = out_dir + "/" + name
    write_utf8_text(path, text)
    let input = read_utf8_text(path)
    assert_true((try? @xml.tokenize_xml_text(input)) is Err(_))
  }
}
