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
fn open_sample_package(path : String) -> @ox.OoxmlPackage raise {
  let bytes = @fs.read_file_to_bytes(resolve_sample_path(path)) catch {
    e => fail("read sample failed: " + e.to_string())
  }
  @ox.open_ooxml_package(bytes) catch {
    e => fail("open sample package failed: " + e.to_string())
  }
}

///|
fn bytes_of_string(s : String) -> Array[Byte] {
  let out : Array[Byte] = []
  for ch in s.to_array() {
    out.push(ch.to_int().to_byte())
  }
  out
}

///|
fn append_u16_le(out : Array[Byte], value : Int) -> Unit {
  out.push((value & 0xFF).to_byte())
  out.push(((value >> 8) & 0xFF).to_byte())
}

///|
fn append_u32_le(out : Array[Byte], value : Int) -> Unit {
  out.push((value & 0xFF).to_byte())
  out.push(((value >> 8) & 0xFF).to_byte())
  out.push(((value >> 16) & 0xFF).to_byte())
  out.push(((value >> 24) & 0xFF).to_byte())
}

///|
fn add_store_entry(
  out : Array[Byte],
  central : Array[(String, Int, Int)],
  name : String,
  data : String,
) -> Unit {
  let local_offset = out.length()
  let name_bytes = bytes_of_string(name)
  let data_bytes = bytes_of_string(data)

  append_u32_le(out, 0x04034b50)
  append_u16_le(out, 20)
  append_u16_le(out, 0)
  append_u16_le(out, 0)
  append_u16_le(out, 0)
  append_u16_le(out, 0)
  append_u32_le(out, 0)
  append_u32_le(out, data_bytes.length())
  append_u32_le(out, data_bytes.length())
  append_u16_le(out, name_bytes.length())
  append_u16_le(out, 0)
  for b in name_bytes {
    out.push(b)
  }
  for b in data_bytes {
    out.push(b)
  }

  central.push((name, data_bytes.length(), local_offset))
}

///|
fn build_store_zip(entries : Array[(String, String)]) -> Bytes {
  let out : Array[Byte] = []
  let central : Array[(String, Int, Int)] = []

  for entry in entries {
    let (name, data) = entry
    add_store_entry(out, central, name, data)
  }

  let cd_offset = out.length()
  for entry in central {
    let (name, size, local_offset) = entry
    let name_bytes = bytes_of_string(name)
    append_u32_le(out, 0x02014b50)
    append_u16_le(out, 20)
    append_u16_le(out, 20)
    append_u16_le(out, 0)
    append_u16_le(out, 0)
    append_u16_le(out, 0)
    append_u16_le(out, 0)
    append_u32_le(out, 0)
    append_u32_le(out, size)
    append_u32_le(out, size)
    append_u16_le(out, name_bytes.length())
    append_u16_le(out, 0)
    append_u16_le(out, 0)
    append_u16_le(out, 0)
    append_u16_le(out, 0)
    append_u32_le(out, 0)
    append_u32_le(out, local_offset)
    for b in name_bytes {
      out.push(b)
    }
  }
  let cd_size = out.length() - cd_offset

  append_u32_le(out, 0x06054b50)
  append_u16_le(out, 0)
  append_u16_le(out, 0)
  append_u16_le(out, central.length())
  append_u16_le(out, central.length())
  append_u32_le(out, cd_size)
  append_u32_le(out, cd_offset)
  append_u16_le(out, 0)

  Bytes::from_array(out)
}

///|
fn minimal_content_types_xml(overrides : String) -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">" +
  "<Default Extension=\"xml\" ContentType=\"application/xml\"/>" +
  "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>" +
  "<Default Extension=\"png\" ContentType=\"image/png\"/>" +
  overrides +
  "</Types>"
}

///|
fn minimal_rels_xml(inner : String) -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
  inner +
  "</Relationships>"
}

///|
fn generated_docx_pkg_from_parts(
  document_xml : String,
  document_rels_xml : String,
  extra_entries : Array[(String, String)],
  content_type_overrides : String,
) -> @ox.OoxmlPackage raise {
  let entries : Array[(String, String)] = [
    ("[Content_Types].xml", minimal_content_types_xml(content_type_overrides)),
    (
      "_rels/.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rIdMain\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/>",
      ),
    ),
    ("word/document.xml", document_xml),
    ("word/_rels/document.xml.rels", document_rels_xml),
  ]
  for entry in extra_entries {
    entries.push(entry)
  }
  @ox.open_ooxml_package(build_store_zip(entries)) catch {
    e => fail("open generated docx package failed: " + e.to_string())
  }
}

///|
fn generated_docx_validation_pkg() -> @ox.OoxmlPackage raise {
  let document_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
    "<w:body>" +
    "<w:p><w:hyperlink r:id=\"rIdMissing\"><w:r><w:t>Missing link</w:t></w:r></w:hyperlink></w:p>" +
    "<w:p><w:r><w:drawing><a:blip xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" r:embed=\"rIdImage\"/></w:drawing></w:r></w:p>" +
    "<w:p><w:pPr><w:pStyle w:val=\"MissingStyle\"/></w:pPr><w:r><w:t>Style</w:t></w:r></w:p>" +
    "<w:p><w:pPr><w:numPr><w:ilvl w:val=\"0\"/><w:numId w:val=\"9\"/></w:numPr></w:pPr><w:r><w:t>Numbering</w:t></w:r></w:p>" +
    "</w:body>" +
    "</w:document>"
  let document_rels_xml = minimal_rels_xml(
    "<Relationship Id=\"rIdImage\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/missing.png\"/>",
  )
  let styles_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<w:styles xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
    "<w:style w:type=\"paragraph\" w:styleId=\"Normal\"><w:name w:val=\"Normal\"/></w:style>" +
    "</w:styles>"
  let numbering_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<w:numbering xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
    "<w:abstractNum w:abstractNumId=\"1\"><w:lvl w:ilvl=\"0\"><w:numFmt w:val=\"decimal\"/></w:lvl></w:abstractNum>" +
    "<w:num w:numId=\"1\"><w:abstractNumId w:val=\"1\"/></w:num>" +
    "</w:numbering>"
  generated_docx_pkg_from_parts(
    document_xml,
    document_rels_xml,
    [("word/styles.xml", styles_xml), ("word/numbering.xml", numbering_xml)],
    "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>" +
    "<Override PartName=\"/word/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml\"/>" +
    "<Override PartName=\"/word/numbering.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml\"/>",
  )
}

///|
fn generated_docx_tab_pkg() -> @ox.OoxmlPackage raise {
  generated_docx_pkg_from_parts(
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
    "<w:body><w:p><w:r><w:t>Left</w:t><w:tab/><w:t>Right</w:t></w:r></w:p></w:body>" +
    "</w:document>",
    minimal_rels_xml(""),
    [],
    "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>",
  )
}

///|
fn generated_malformed_docx_pkg() -> @ox.OoxmlPackage raise {
  generated_docx_pkg_from_parts(
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?><w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:p><w:r><w:t>No body</w:t></w:r></w:p></w:document>",
    minimal_rels_xml(""),
    [],
    "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>",
  )
}

///|
fn first_paragraph(doc : @docx.DocxDocument) -> @docx.DocxParagraph raise {
  match doc.body_blocks[0] {
    @docx.DocxBodyBlock::Paragraph(p) => p
    _ => fail("expected first block to be paragraph")
  }
}

///|
test "docx semantic document preserves paragraphs, runs, tabs, breaks, and hyperlinks" {
  let link_doc = @docx.open_docx_document(
    resolve_sample_path("samples/main_process/docx/docx_link_in_paragraph.docx"),
  )
  let link_p = first_paragraph(link_doc)
  assert_eq(link_p.hyperlink_refs.length(), 1)
  assert_eq(link_p.hyperlink_refs[0].text, "OpenAI")
  match link_p.hyperlink_refs[0].target {
    Some(target) => assert_eq(target, "https://openai.com")
    None => fail("expected external hyperlink target")
  }

  let tab_doc = @docx.parse_docx_document_from_package(generated_docx_tab_pkg())
  let tab_p = first_paragraph(tab_doc)
  let saw_tab : Ref[Bool] = { val: false }
  for run in tab_p.runs {
    for inline in run.inlines {
      match inline {
        @docx.DocxInline::Tab => saw_tab.val = true
        _ => ()
      }
    }
  }
  assert_true(saw_tab.val)

  let break_doc = @docx.open_docx_document(
    resolve_sample_path(
      "samples/main_process/docx/docx_paragraph_linebreak.docx",
    ),
  )
  let break_p = first_paragraph(break_doc)
  let saw_break : Ref[Bool] = { val: false }
  for run in break_p.runs {
    for inline in run.inlines {
      match inline {
        @docx.DocxInline::LineBreak => saw_break.val = true
        _ => ()
      }
    }
  }
  assert_true(saw_break.val)
}

///|
test "docx semantic table model preserves rows, cells, and nested paragraph text" {
  let doc = @docx.open_docx_document(
    resolve_sample_path(
      "samples/main_process/docx/docx_table_multiline_cell.docx",
    ),
  )
  let table_block : Ref[@docx.DocxTable?] = { val: None }
  for block in doc.body_blocks {
    match block {
      @docx.DocxBodyBlock::Table(table) => {
        table_block.val = Some(table)
        break
      }
      _ => ()
    }
  }
  match table_block.val {
    Some(table) => {
      assert_eq(table.rows.length(), 2)
      assert_eq(table.rows[0].cells.length(), 2)
      match table.rows[1].cells[0].body_blocks[0] {
        @docx.DocxBodyBlock::Paragraph(first_p) => {
          assert_eq(table.rows[1].cells[0].body_blocks.length(), 1)
          match first_p.runs[0].inlines[0] {
            @docx.DocxInline::Text(text) => assert_eq(text, "Line 1")
            _ => fail("expected first cell paragraph text")
          }
          let saw_break : Ref[Bool] = { val: false }
          match first_p.runs[1].inlines[0] {
            @docx.DocxInline::LineBreak => saw_break.val = true
            _ => ()
          }
          assert_true(saw_break.val)
          match first_p.runs[2].inlines[0] {
            @docx.DocxInline::Text(text) => assert_eq(text, "Line 2")
            _ => fail("expected second line text")
          }
        }
        _ => fail("expected first body block in multiline cell to be paragraph")
      }
      match table.rows[1].cells[1].body_blocks[0] {
        @docx.DocxBodyBlock::Paragraph(value_p) =>
          match value_p.runs[0].inlines[0] {
            @docx.DocxInline::Text(text) => assert_eq(text, "Value")
            _ => fail("expected value cell text")
          }
        _ => fail("expected value cell paragraph")
      }
    }
    None => fail("expected one table block in document body")
  }
}

///|
test "docx semantic model preserves styles numbering notes headers footers and text boxes" {
  let styled = @docx.open_docx_document(
    resolve_sample_path(
      "samples/main_process/docx/docx_style_linked_headings.docx",
    ),
  )
  assert_true(styled.styles.styles.length() > 0)
  let heading_level : Ref[Int] = { val: 0 }
  for style in styled.styles.styles {
    match style.raw_heading_level {
      Some(level) => if level > heading_level.val { heading_level.val = level }
      None => ()
    }
  }
  assert_true(heading_level.val > 0)

  let listed = @docx.open_docx_document(
    resolve_sample_path("samples/main_process/docx/docx_list_nested.docx"),
  )
  let inspect_listed = @docx.inspect_docx_document(listed)
  assert_true(inspect_listed.numbering_ref_count > 0)

  let note_doc = @docx.open_docx_document(
    resolve_sample_path("samples/main_process/docx/docx_footnote_basic.docx"),
  )
  assert_true(note_doc.notes.footnotes.length() > 0)

  let comment_doc = @docx.open_docx_document(
    resolve_sample_path("samples/main_process/docx/docx_comment_basic.docx"),
  )
  assert_true(comment_doc.notes.comments.length() > 0)

  let header_doc = @docx.open_docx_document(
    resolve_sample_path("samples/main_process/docx/docx_header_basic.docx"),
  )
  assert_true(header_doc.headers.length() > 0)

  let footer_doc = @docx.open_docx_document(
    resolve_sample_path("samples/main_process/docx/docx_footer_basic.docx"),
  )
  assert_true(footer_doc.footers.length() > 0)

  let textbox_doc = @docx.open_docx_document(
    resolve_sample_path("samples/main_process/docx/docx_textbox_basic.docx"),
  )
  assert_true(textbox_doc.text_boxes.length() > 0)
}

///|
test "docx semantic parse facade from package matches direct open and inspect counts stay stable" {
  let path = "samples/main_process/docx/docx_link_basic.docx"
  let opened = @docx.open_docx_document(resolve_sample_path(path))
  let pkg = open_sample_package(path)
  let parsed = @docx.parse_docx_document_from_package(pkg)

  let opened_inspect = @docx.inspect_docx_document(opened)
  let parsed_inspect = @docx.inspect_docx_document(parsed)
  assert_eq(opened_inspect.paragraph_count, parsed_inspect.paragraph_count)
  assert_eq(opened_inspect.hyperlink_count, parsed_inspect.hyperlink_count)
  assert_eq(opened_inspect.style_count, parsed_inspect.style_count)
}

///|
test "docx semantic validation reports relationship media style and numbering gaps deterministically" {
  let pkg = generated_docx_validation_pkg()
  let doc = @docx.parse_docx_document_from_package(pkg)
  let issues = @docx.collect_docx_validation_issues(doc)
  let report = @docx.validate_docx_document(doc)

  assert_eq(issues.length(), report.issue_count)
  assert_true(
    issues[0].kind == @docx.DocxValidationIssueKind::MissingRelationshipTarget,
  )
  assert_true(issues[1].kind == @docx.DocxValidationIssueKind::MissingMediaPart)
  assert_true(issues[2].kind == @docx.DocxValidationIssueKind::MissingStyle)
  assert_true(issues[3].kind == @docx.DocxValidationIssueKind::MissingNumbering)

  let inspect = @docx.inspect_docx_document(doc)
  assert_eq(inspect.issue_count, report.issue_count)
  assert_eq(inspect.error_count, report.error_count)
  assert_eq(inspect.warning_count, report.warning_count)
}

///|
test "docx semantic classifier recognizes malformed main document xml" {
  let pkg = generated_malformed_docx_pkg()
  let result = try? @docx.parse_docx_document_from_package(pkg)
  assert_true(result is Err(_))
  let info = @docx.classify_docx_error(
    @docx.DocxError::ParseError("malformed document xml: missing <w:body>"),
  )
  assert_true(info.kind == @docx.DocxErrorKind::MalformedDocumentXml)
}
