///|
fn docx_from_body(body : String) -> @docx.DocxDocument raise {
  let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
    "<w:body>" +
    body +
    "</w:body></w:document>"
  @docx.normalize_docx_source(
    @docx.parse_docx_source_document_xml("word/document.xml", xml),
  )
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
fn crc32_of_string(s : String) -> Int {
  let mut crc : UInt = 0xFFFFFFFF
  for ch in s.to_array() {
    crc = crc32_update_uint(crc, ch.to_int().reinterpret_as_uint())
  }
  UInt::lxor(crc, 0xFFFFFFFF).reinterpret_as_int()
}

///|
fn crc32_update_uint(crc : UInt, value : UInt) -> UInt {
  let mut acc = UInt::lxor(crc, value)
  let mut i = 0
  while i < 8 {
    if UInt::land(acc, 1) != 0 {
      acc = UInt::lxor(acc >> 1, 0xEDB88320)
    } else {
      acc = acc >> 1
    }
    i += 1
  }
  acc
}

///|
fn add_store_entry(
  out : Array[Byte],
  central : Array[(String, Int, Int, Int)],
  name : String,
  data : String,
) -> Unit {
  let local_offset = out.length()
  let name_bytes = bytes_of_string(name)
  let data_bytes = bytes_of_string(data)
  let crc32 = crc32_of_string(data)
  append_u32_le(out, 0x04034b50)
  append_u16_le(out, 20)
  append_u16_le(out, 0)
  append_u16_le(out, 0)
  append_u16_le(out, 0)
  append_u16_le(out, 0)
  append_u32_le(out, crc32)
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
  central.push((name, data_bytes.length(), local_offset, crc32))
}

///|
fn build_store_zip(entries : Array[(String, String)]) -> Bytes {
  let out : Array[Byte] = []
  let central : Array[(String, Int, Int, Int)] = []
  for entry in entries {
    let (name, data) = entry
    add_store_entry(out, central, name, data)
  }
  let cd_offset = out.length()
  for entry in central {
    let (name, size, local_offset, crc32) = entry
    let name_bytes = bytes_of_string(name)
    append_u32_le(out, 0x02014b50)
    append_u16_le(out, 20)
    append_u16_le(out, 20)
    append_u16_le(out, 0)
    append_u16_le(out, 0)
    append_u16_le(out, 0)
    append_u16_le(out, 0)
    append_u32_le(out, crc32)
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
fn generated_docx_package(
  body : String,
  document_rels : String,
  extra_entries : Array[(String, String)],
) -> @ox.OoxmlPackage raise {
  let document_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
    "<w:body>" +
    body +
    "</w:body></w:document>"
  let entries : Array[(String, String)] = [
    (
      "[Content_Types].xml", "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"xml\" ContentType=\"application/xml\"/><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"png\" ContentType=\"image/png\"/><Default Extension=\"jpg\" ContentType=\"image/jpeg\"/><Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/></Types>",
    ),
    (
      "_rels/.rels", "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rIdMain\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/></Relationships>",
    ),
    ("word/document.xml", document_xml),
  ]
  if document_rels != "" {
    entries.push(
      (
        "word/_rels/document.xml.rels",
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
        document_rels +
        "</Relationships>",
      ),
    )
  }
  for entry in extra_entries {
    entries.push(entry)
  }
  @ox.open_ooxml_package(build_store_zip(entries)) catch {
    e => fail("open generated docx failed: " + e.to_string())
  }
}

///|
fn fresh_docx_test_dir(name : String) -> String raise {
  let mut idx = 0
  while idx < 1000 {
    idx += 1
    let path = "/private/tmp/docx_reset11_" + name + "_" + idx.to_string()
    if !@fs.path_exists(path) {
      @fs.create_dir(path) catch {
        e => fail("create temp dir failed: " + e.to_string())
      }
      return path
    }
  }
  fail("could not allocate temp dir")
}

///|
fn generated_docx_image_xml(
  rid : String,
  descr : String,
  title : String,
) -> String {
  "<w:drawing>" +
  "<wp:inline xmlns:wp=\"http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing\">" +
  "<wp:docPr id=\"1\" name=\"Picture 1\" descr=\"" +
  descr +
  "\" title=\"" +
  title +
  "\"/>" +
  "<a:graphic xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\"><a:graphicData>" +
  "<pic:pic xmlns:pic=\"http://schemas.openxmlformats.org/drawingml/2006/picture\"><pic:blipFill><a:blip r:embed=\"" +
  rid +
  "\"/></pic:blipFill></pic:pic>" +
  "</a:graphicData></a:graphic></wp:inline></w:drawing>"
}

///|
fn assert_docx_contains(markdown : String, expected : String) -> Unit raise {
  if !markdown.contains(expected) {
    fail("expected markdown to contain: " + expected + "\nactual:\n" + markdown)
  }
}

///|
fn assert_docx_graph_part(
  graph : @docx.DocxPartGraph,
  kind : @docx.DocxDiscoveredPartKind,
  source : @docx.DocxPartDiscoverySource,
  part_name : String,
) -> Unit raise {
  for part in graph.parts {
    if part.kind == kind && part.source == source && part.part_name == part_name {
      return
    }
  }
  fail("expected discovered DOCX part: " + part_name)
}

///|
fn first_docx_image_block(doc : @cor.Document) -> @cor.ImageData? {
  for block in doc.blocks.val {
    match block {
      @cor.Block::ImageBlock(img) => return Some(img)
      _ => ()
    }
  }
  None
}

///|
fn assert_docx_paragraph_block(
  doc : @cor.Document,
  index : Int,
  text : String,
) -> Unit raise {
  match doc.blocks.val[index] {
    @cor.Block::Paragraph(value) => assert_eq(value, text)
    _ => fail("expected paragraph block at index " + index.to_string())
  }
}

///|
fn assert_docx_image_block(
  doc : @cor.Document,
  index : Int,
  path : String,
  alt_text : String,
) -> Unit raise {
  match doc.blocks.val[index] {
    @cor.Block::ImageBlock(img) => {
      assert_eq(img.path, path)
      assert_true(img.alt_text == Some(alt_text))
    }
    _ => fail("expected image block at index " + index.to_string())
  }
}

///|
fn assert_docx_note_definition(
  doc : @cor.Document,
  index : Int,
  note_id : String,
  marker : String,
  kind : @cor.NoteKind,
  source_kind : @cor.NoteSourceKind,
  body : String,
) -> Unit raise {
  let note = doc.note_definitions.val[index]
  assert_eq(note.note_id, note_id)
  assert_eq(note.marker, marker)
  assert_true(note.kind == kind)
  assert_true(note.source_kind == source_kind)
  assert_true(note.body_status == @cor.NoteBodyStatus::Resolved)
  assert_eq(note.blocks.length(), 1)
  match note.blocks[0] {
    @cor.Block::Paragraph(text) => assert_eq(text, body)
    _ => fail("expected note definition body to be a paragraph")
  }
}

///|
fn assert_docx_expected_sample(path : String, expected : String) -> Unit raise {
  let sample = resolve_docx_sample_path(path)
  let markdown = @docxir.render_docx_markdown_file(sample)
  assert_eq(markdown, expected)
}

///|
fn docx_expected_paragraph_linebreak() -> String {
  "First line<br>Second line\n"
}

///|
fn docx_expected_hyperlink_basic() -> String {
  "This is a normal paragraph before the hyperlink.\n\n" +
  "Visit [OpenAI](https://openai.com) for more information.\n"
}

///|
fn docx_expected_table_multiline_cell() -> String {
  "| Col A | Col B |\n" + "| --- | --- |\n" + "| Line 1<br>Line 2 | Value |\n"
}

///|
fn docx_expected_heading_levels() -> String {
  "# Heading Level 1\n\n" +
  "Paragraph under heading 1.\n\n" +
  "## Heading Level 2\n\n" +
  "Paragraph under heading 2.\n\n" +
  "### Heading Level 3\n\n" +
  "Paragraph under heading 3.\n\n" +
  "#### Heading Level 4\n\n" +
  "Paragraph under heading 4.\n\n" +
  "##### Heading Level 5\n\n" +
  "Paragraph under heading 5.\n\n" +
  "###### Heading Level 6\n\n" +
  "Paragraph under heading 6.\n"
}

///|
fn docx_expected_list_basic() -> String {
  "# DOCX List Test\n\n" +
  "This is a normal paragraph.\n\n" +
  "- item A\n" +
  "- item B\n\n" +
  "## Sub Section\n\n" +
  "Another paragraph after the list.\n"
}

///|
fn docx_expected_notes_comments() -> String {
  "Footnote[^1] then comment [comment 1]\n\n" +
  "Endnote[^e1]\n\n" +
  "## Comments\n\n" +
  "1. Alice: Comment body.\n\n" +
  "[^1]: Footnote body.\n\n" +
  "[^e1]: Endnote body.\n"
}

///|
test "docx expected tier real sample markdown baselines" {
  // These baselines are v2-owned experimental expectations, not legacy sample expected files.
  assert_docx_expected_sample(
    "samples/main_process/docx/docx_paragraph_linebreak.docx",
    docx_expected_paragraph_linebreak(),
  )
  assert_docx_expected_sample(
    "samples/main_process/docx/docx_hyperlink_basic.docx",
    docx_expected_hyperlink_basic(),
  )
  assert_docx_expected_sample(
    "samples/main_process/docx/docx_table_multiline_cell.docx",
    docx_expected_table_multiline_cell(),
  )
  assert_docx_expected_sample(
    "samples/main_process/docx/docx_heading_levels.docx",
    docx_expected_heading_levels(),
  )
  assert_docx_expected_sample(
    "samples/main_process/docx/docx_list_basic.docx",
    docx_expected_list_basic(),
  )
  assert_docx_expected_sample(
    "samples/main_process/docx/docx_footnotes_endnotes_comments.docx",
    docx_expected_notes_comments(),
  )
}

///|
test "docx lowering emits deterministic paragraph markdown" {
  let docx = docx_from_body(
    "<w:p><w:r><w:t>Left</w:t><w:tab/><w:t>Right</w:t></w:r></w:p>",
  )
  assert_eq(@docxir.render_docx_plain_text(docx), "Left\tRight")
  assert_eq(
    @cor.emit_markdown(@docxir.lower_docx_document(docx)),
    "Left\tRight\n",
  )
}

///|
test "docx lowering emits deterministic simple table markdown" {
  let docx = docx_from_body(
    "<w:tbl>" +
    "<w:tr><w:tc><w:p><w:r><w:t>A1</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>B1</w:t></w:r></w:p></w:tc></w:tr>" +
    "<w:tr><w:tc><w:p><w:r><w:t>A2</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>B2</w:t></w:r></w:p></w:tc></w:tr>" +
    "</w:tbl>",
  )
  assert_eq(@docxir.render_docx_plain_text(docx), "A1\tB1\nA2\tB2")
  assert_eq(
    @cor.emit_markdown(@docxir.lower_docx_document(docx)),
    "| Column 1 | Column 2 |\n| --- | --- |\n| A1 | B1 |\n| A2 | B2 |\n",
  )
  assert_eq(docx.warnings.length(), 0)
}

///|
test "docx lowering explicit table header row sets RichTable header_rows" {
  let docx = docx_from_body(
    "<w:tbl>" +
    "<w:tr><w:trPr><w:tblHeader/></w:trPr><w:tc><w:p><w:r><w:t>Head</w:t></w:r></w:p></w:tc></w:tr>" +
    "<w:tr><w:tc><w:p><w:r><w:t>Body</w:t></w:r></w:p></w:tc></w:tr>" +
    "</w:tbl>",
  )
  let lowered = @docxir.lower_docx_document(docx)
  match lowered.blocks.val[0] {
    @cor.Block::RichTable(table) => {
      assert_eq(table.header_rows, 1)
      assert_eq(table.rows[0][0], "Head")
    }
    _ => fail("expected rich table")
  }
}

///|
test "docx lowering infers styled first table row as header" {
  let docx = docx_from_body(
    "<w:tbl>" +
    "<w:tr>" +
    "<w:tc><w:p><w:pPr><w:jc w:val=\"center\"/></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t>Module</w:t></w:r></w:p></w:tc>" +
    "<w:tc><w:p><w:pPr><w:jc w:val=\"center\"/></w:pPr><w:r><w:rPr><w:b/></w:rPr><w:t>Status</w:t></w:r></w:p></w:tc>" +
    "</w:tr>" +
    "<w:tr><w:tc><w:p><w:r><w:t>core</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>done</w:t></w:r></w:p></w:tc></w:tr>" +
    "</w:tbl>",
  )
  let lowered = @docxir.lower_docx_document(docx)
  match lowered.blocks.val[0] {
    @cor.Block::RichTable(table) => {
      assert_eq(table.header_rows, 1)
      assert_eq(table.rows[0][0], "Module")
    }
    _ => fail("expected rich table")
  }
}

///|
test "docx lowering table without marker keeps header_rows zero" {
  let docx = docx_from_body(
    "<w:tbl><w:tr><w:tc><w:p><w:r><w:t>Head-ish</w:t></w:r></w:p></w:tc></w:tr></w:tbl>",
  )
  let lowered = @docxir.lower_docx_document(docx)
  match lowered.blocks.val[0] {
    @cor.Block::RichTable(table) => assert_eq(table.header_rows, 0)
    _ => fail("expected rich table")
  }
}

///|
test "docx lowering table hyperlink cell is deterministic" {
  let docx = docx_from_body(
    "<w:tbl><w:tr><w:tc><w:p><w:hyperlink w:anchor=\"target\"><w:r><w:t>Jump</w:t></w:r></w:hyperlink></w:p></w:tc></w:tr></w:tbl>",
  )
  assert_eq(
    @cor.emit_markdown(@docxir.lower_docx_document(docx)),
    "| Column 1 |\n| --- |\n| [Jump](#target) |\n",
  )
}

///|
test "docx lowering nested table preserves inner table text" {
  let docx = docx_from_body(
    "<w:tbl><w:tr><w:tc>" +
    "<w:p><w:r><w:t>Outer</w:t></w:r></w:p>" +
    "<w:tbl><w:tr><w:tc><w:p><w:r><w:t>Inner</w:t></w:r></w:p></w:tc></w:tr></w:tbl>" +
    "</w:tc></w:tr></w:tbl>",
  )
  assert_eq(
    @cor.emit_markdown(@docxir.lower_docx_document(docx)),
    "| Column 1 |\n| --- |\n| Outer<br>Inner |\n",
  )
  assert_eq(docx.warnings.length(), 0)
}

///|
test "docx lowering emits deterministic anchor hyperlink markdown" {
  let docx = docx_from_body(
    "<w:p><w:hyperlink w:anchor=\"target\"><w:r><w:t>Jump</w:t></w:r></w:hyperlink></w:p>",
  )
  assert_eq(@docxir.render_docx_plain_text(docx), "Jump")
  assert_eq(
    @cor.emit_markdown(@docxir.lower_docx_document(docx)),
    "[Jump](#target)\n",
  )
}

///|
test "docx lowering style and numbering refs do not change text output" {
  let docx = docx_from_body(
    "<w:p><w:pPr><w:pStyle w:val=\"Heading1\"/><w:numPr><w:ilvl w:val=\"0\"/><w:numId w:val=\"7\"/></w:numPr></w:pPr>" +
    "<w:r><w:t>Styled</w:t></w:r></w:p>",
  )
  assert_eq(@cor.emit_markdown(@docxir.lower_docx_document(docx)), "Styled\n")
  match docx.body[0] {
    @docx.DocxBlock::Paragraph(p) => {
      assert_true(p.style_id == Some("Heading1"))
      assert_true(p.numbering_ref is Some(_))
    }
    _ => fail("expected paragraph")
  }
}

///|
test "docx lowering heading style from styles service is stable" {
  let pkg = generated_docx_package(
    "<w:p><w:pPr><w:pStyle w:val=\"Heading1\"/></w:pPr><w:r><w:t>Styled Heading</w:t></w:r></w:p>",
    "<Relationship Id=\"rIdStyles\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>",
    [
      (
        "word/styles.xml",
        "<w:styles xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
        "<w:style w:type=\"paragraph\" w:styleId=\"Heading1\"><w:name w:val=\"heading 1\"/></w:style>" +
        "</w:styles>",
      ),
    ],
  )
  let docx = @docx.parse_docx_document_from_package(pkg)
  assert_eq(
    @cor.emit_markdown(@docxir.lower_docx_document(docx)),
    "# Styled Heading\n",
  )
}

///|
test "docx lowering bullet numbering from numbering service is stable" {
  let pkg = generated_docx_package(
    "<w:p><w:pPr><w:numPr><w:ilvl w:val=\"0\"/><w:numId w:val=\"7\"/></w:numPr></w:pPr><w:r><w:t>Bullet</w:t></w:r></w:p>",
    "<Relationship Id=\"rIdNumbering\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering\" Target=\"numbering.xml\"/>",
    [
      (
        "word/numbering.xml",
        "<w:numbering xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
        "<w:abstractNum w:abstractNumId=\"10\"><w:lvl w:ilvl=\"0\"><w:numFmt w:val=\"bullet\"/></w:lvl></w:abstractNum>" +
        "<w:num w:numId=\"7\"><w:abstractNumId w:val=\"10\"/></w:num>" +
        "</w:numbering>",
      ),
    ],
  )
  let docx = @docx.parse_docx_document_from_package(pkg)
  assert_eq(@cor.emit_markdown(@docxir.lower_docx_document(docx)), "- Bullet\n")
}

///|
test "docx lowering decimal numbering from numbering service is stable" {
  let pkg = generated_docx_package(
    "<w:p><w:pPr><w:numPr><w:ilvl w:val=\"1\"/><w:numId w:val=\"8\"/></w:numPr></w:pPr><w:r><w:t>Decimal</w:t></w:r></w:p>",
    "<Relationship Id=\"rIdNumbering\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering\" Target=\"numbering.xml\"/>",
    [
      (
        "word/numbering.xml",
        "<w:numbering xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
        "<w:abstractNum w:abstractNumId=\"20\"><w:lvl w:ilvl=\"1\"><w:numFmt w:val=\"decimal\"/></w:lvl></w:abstractNum>" +
        "<w:num w:numId=\"8\"><w:abstractNumId w:val=\"20\"/></w:num>" +
        "</w:numbering>",
      ),
    ],
  )
  let docx = @docx.parse_docx_document_from_package(pkg)
  assert_eq(
    @cor.emit_markdown(@docxir.lower_docx_document(docx)),
    "  1. Decimal\n",
  )
}

///|
test "docx lowering style linked numbering uses typed hints" {
  let pkg = generated_docx_package(
    "<w:p><w:pPr><w:pStyle w:val=\"ListParagraph\"/></w:pPr><w:r><w:t>Styled decimal</w:t></w:r></w:p>",
    "<Relationship Id=\"rIdNumbering\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering\" Target=\"numbering.xml\"/>",
    [
      (
        "word/numbering.xml",
        "<w:numbering xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
        "<w:abstractNum w:abstractNumId=\"30\"><w:lvl w:ilvl=\"0\"><w:numFmt w:val=\"decimal\"/><w:lvlText w:val=\"%1.\"/><w:pStyle w:val=\"ListParagraph\"/></w:lvl></w:abstractNum>" +
        "<w:num w:numId=\"10\"><w:abstractNumId w:val=\"30\"/></w:num>" +
        "</w:numbering>",
      ),
    ],
  )
  let docx = @docx.parse_docx_document_from_package(pkg)
  assert_eq(
    @cor.emit_markdown(@docxir.lower_docx_document(docx)),
    "1. Styled decimal\n",
  )
}

///|
fn docx_deep_table_xml(depth : Int) -> String {
  let mut inner = "<w:p><w:r><w:t>Leaf</w:t></w:r></w:p>"
  for i in 0..<depth {
    inner = "<w:tbl><w:tr><w:tc><w:p><w:r><w:t>D" +
      i.to_string() +
      "</w:t></w:r></w:p>" +
      inner +
      "</w:tc></w:tr></w:tbl>"
  }
  inner
}

///|
test "docx lowering deep table guard keeps bounded placeholder" {
  let docx = docx_from_body(docx_deep_table_xml(8))
  let markdown = @cor.emit_markdown(@docxir.lower_docx_document(docx))
  assert_true(markdown.contains("Unsupported DOCX nested table depth limit"))
  let mut has_nested_warning = false
  for warning in docx.warnings {
    if warning.kind == @docx.DocxWarningKind::NestedTable {
      has_nested_warning = true
    }
  }
  assert_true(has_nested_warning)
}

///|
test "docx lowering unknown style remains paragraph" {
  let pkg = generated_docx_package(
    "<w:p><w:pPr><w:pStyle w:val=\"Fancy\"/></w:pPr><w:r><w:t>Plain</w:t></w:r></w:p>",
    "<Relationship Id=\"rIdStyles\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>",
    [
      (
        "word/styles.xml",
        "<w:styles xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
        "<w:style w:type=\"paragraph\" w:styleId=\"Fancy\"><w:name w:val=\"Fancy\"/></w:style>" +
        "</w:styles>",
      ),
    ],
  )
  let docx = @docx.parse_docx_document_from_package(pkg)
  assert_eq(@cor.emit_markdown(@docxir.lower_docx_document(docx)), "Plain\n")
}

///|
test "docx lowering referenced missing numbering warns and falls back" {
  let pkg = generated_docx_package(
    "<w:p><w:pPr><w:numPr><w:ilvl w:val=\"0\"/><w:numId w:val=\"99\"/></w:numPr></w:pPr><w:r><w:t>Loose</w:t></w:r></w:p>",
    "",
    [],
  )
  let docx = @docx.parse_docx_document_from_package(pkg)
  assert_eq(@cor.emit_markdown(@docxir.lower_docx_document(docx)), "Loose\n")
  let mut has_missing_numbering = false
  for warning in docx.warnings {
    if warning.kind == @docx.DocxWarningKind::MissingNumberingPart {
      has_missing_numbering = true
    }
  }
  assert_true(has_missing_numbering)
}

///|
test "docx lowering typed unsupported inlines and tracked changes do not crash" {
  let docx = docx_from_body(
    "<w:p><w:r><w:fldChar w:fldCharType=\"begin\"/><w:bookmarkStart w:id=\"1\" w:name=\"mark\"/><w:t>A</w:t></w:r>" +
    "<w:ins><w:r><w:t>Inserted</w:t></w:r></w:ins></w:p>",
  )
  assert_eq(
    @docxir.render_docx_plain_text(docx),
    "[field: fldChar:begin]AInserted",
  )
  assert_eq(
    @cor.emit_markdown(@docxir.lower_docx_document(docx)),
    "[field: fldChar:begin]AInserted\n",
  )
  assert_true(docx.warnings.length() >= 2)
}

///|
test "docx lowering fields is deterministic and unevaluated" {
  let docx = docx_from_body(
    "<w:p><w:r><w:instrText> PAGE </w:instrText></w:r>" +
    "<w:fldSimple w:instr=\"DATE\"><w:r><w:t>June 5</w:t></w:r></w:fldSimple></w:p>",
  )
  assert_eq(@docxir.render_docx_plain_text(docx), "[field: PAGE]June 5")
  assert_eq(
    @cor.emit_markdown(@docxir.lower_docx_document(docx)),
    "[field: PAGE]June 5\n",
  )
}

///|
test "docx lowering math is deterministic and unevaluated" {
  let docx = docx_from_body(
    "<w:p><m:oMath xmlns:m=\"http://schemas.openxmlformats.org/officeDocument/2006/math\"><m:r><m:t>x+1</m:t></m:r></m:oMath></w:p>",
  )
  assert_eq(@docxir.render_docx_plain_text(docx), "[math: x+1]")
  assert_eq(
    @cor.emit_markdown(@docxir.lower_docx_document(docx)),
    "[math: x+1]\n",
  )
}

///|
test "docx lowering bookmarks has no visible output" {
  let docx = docx_from_body(
    "<w:p><w:bookmarkStart w:id=\"1\" w:name=\"mark\"/>" +
    "<w:r><w:t>A</w:t></w:r><w:bookmarkEnd w:id=\"1\"/></w:p>",
  )
  assert_eq(@docxir.render_docx_plain_text(docx), "A")
  assert_eq(@cor.emit_markdown(@docxir.lower_docx_document(docx)), "A\n")
}

///|
test "docx lowering symbol hyphen and breaks is deterministic" {
  let docx = docx_from_body(
    "<w:p><w:r><w:t>A</w:t><w:sym w:char=\"002A\"/><w:softHyphen/>" +
    "<w:t>B</w:t><w:noBreakHyphen/><w:t>C</w:t>" +
    "<w:br w:type=\"page\"/><w:t>D</w:t><w:br w:type=\"textWrapping\"/><w:t>E</w:t></w:r></w:p>",
  )
  assert_eq(@docxir.render_docx_plain_text(docx), "A*B-C[break: page]D\nE")
  assert_eq(
    @cor.emit_markdown(@docxir.lower_docx_document(docx)),
    "A*B-C[break: page]D<br>E\n",
  )
}

///|
test "docx lowering tracked changes keeps insertions only" {
  let docx = docx_from_body(
    "<w:p><w:ins><w:r><w:t>Inserted</w:t></w:r></w:ins>" +
    "<w:del><w:r><w:delText>Deleted</w:delText></w:r></w:del>" +
    "<w:moveFrom><w:r><w:t>Moved from</w:t></w:r></w:moveFrom>" +
    "<w:moveTo><w:r><w:t>Moved to</w:t></w:r></w:moveTo></w:p>",
  )
  assert_eq(@docxir.render_docx_plain_text(docx), "InsertedMoved to")
  assert_eq(
    @cor.emit_markdown(@docxir.lower_docx_document(docx)),
    "InsertedMoved to\n",
  )
}

///|
test "docx lowering unknown inline is deterministic" {
  let docx = docx_from_body(
    "<w:p><w:r><w:t>A</w:t><w:nope/><w:t>B</w:t></w:r></w:p>",
  )
  assert_eq(@docxir.render_docx_plain_text(docx), "A[unsupported DOCX inline]B")
  assert_eq(
    @cor.emit_markdown(@docxir.lower_docx_document(docx)),
    "A[unsupported DOCX inline]B\n",
  )
}

///|
test "docx lowering body note and comment refs as deterministic markers" {
  let docx = docx_from_body(
    "<w:p><w:r><w:t>Refs</w:t><w:footnoteReference w:id=\"1\"/><w:endnoteReference w:id=\"2\"/><w:commentReference w:id=\"3\"/></w:r></w:p>",
  )
  assert_eq(
    @cor.emit_markdown(@docxir.lower_docx_document(docx)),
    "Refs[^1][^e2] [comment 3]\n",
  )
}

///|
test "docx lowering appends resolved footnote section" {
  let pkg = generated_docx_package(
    "<w:p><w:r><w:t>Main</w:t><w:footnoteReference w:id=\"1\"/></w:r></w:p>",
    "<Relationship Id=\"rIdFoot\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes\" Target=\"footnotes.xml\"/>",
    [
      (
        "word/footnotes.xml", "<w:footnotes xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:footnote w:id=\"1\"><w:p><w:r><w:t>Footnote body</w:t></w:r></w:p></w:footnote></w:footnotes>",
      ),
    ],
  )
  let docx = @docx.parse_docx_document_from_package(pkg)
  assert_docx_graph_part(
    docx.part_graph,
    @docx.DocxDiscoveredPartKind::Footnotes,
    @docx.DocxPartDiscoverySource::Relationship,
    "word/footnotes.xml",
  )
  let doc = @docxir.lower_docx_document(docx)
  assert_eq(doc.note_definitions.val.length(), 1)
  assert_docx_note_definition(
    doc,
    0,
    "1",
    "1",
    @cor.NoteKind::Footnote,
    @cor.NoteSourceKind::DocxFootnoteBody,
    "Footnote body",
  )
  let markdown = @cor.emit_markdown(doc)
  assert_eq(markdown, "Main[^1]\n\n[^1]: Footnote body\n")
}

///|
test "docx lowering appends resolved endnote section" {
  let pkg = generated_docx_package(
    "<w:p><w:r><w:t>Main</w:t><w:endnoteReference w:id=\"2\"/></w:r></w:p>",
    "<Relationship Id=\"rIdEnd\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/endnotes\" Target=\"endnotes.xml\"/>",
    [
      (
        "word/endnotes.xml", "<w:endnotes xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:endnote w:id=\"2\"><w:p><w:r><w:t>Endnote body</w:t></w:r></w:p></w:endnote></w:endnotes>",
      ),
    ],
  )
  let docx = @docx.parse_docx_document_from_package(pkg)
  assert_docx_graph_part(
    docx.part_graph,
    @docx.DocxDiscoveredPartKind::Endnotes,
    @docx.DocxPartDiscoverySource::Relationship,
    "word/endnotes.xml",
  )
  let doc = @docxir.lower_docx_document(docx)
  assert_eq(doc.note_definitions.val.length(), 1)
  assert_docx_note_definition(
    doc,
    0,
    "e2",
    "e2",
    @cor.NoteKind::Endnote,
    @cor.NoteSourceKind::DocxEndnoteBody,
    "Endnote body",
  )
  let markdown = @cor.emit_markdown(doc)
  assert_eq(markdown, "Main[^e2]\n\n[^e2]: Endnote body\n")
}

///|
test "docx lowering appends resolved comment section" {
  let pkg = generated_docx_package(
    "<w:p><w:r><w:t>Main</w:t><w:commentReference w:id=\"3\"/></w:r></w:p>",
    "<Relationship Id=\"rIdComments\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments\" Target=\"comments.xml\"/>",
    [
      (
        "word/comments.xml", "<w:comments xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:comment w:id=\"3\" w:author=\"Alice\"><w:p><w:r><w:t>Comment body</w:t></w:r></w:p></w:comment></w:comments>",
      ),
    ],
  )
  let docx = @docx.parse_docx_document_from_package(pkg)
  assert_docx_graph_part(
    docx.part_graph,
    @docx.DocxDiscoveredPartKind::Comments,
    @docx.DocxPartDiscoverySource::Relationship,
    "word/comments.xml",
  )
  let markdown = @cor.emit_markdown(@docxir.lower_docx_document(docx))
  assert_docx_contains(markdown, "Main [comment 1]")
  assert_docx_contains(markdown, "## Comments")
  assert_docx_contains(markdown, "1. Alice: Comment body")
}

///|
test "docx lowering duplicate refs produce one appendix entry" {
  let pkg = generated_docx_package(
    "<w:p><w:r><w:t>Main</w:t><w:footnoteReference w:id=\"1\"/><w:t> again </w:t><w:footnoteReference w:id=\"1\"/></w:r></w:p>",
    "<Relationship Id=\"rIdFoot\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes\" Target=\"footnotes.xml\"/>",
    [
      (
        "word/footnotes.xml", "<w:footnotes xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:footnote w:id=\"1\"><w:p><w:r><w:t>Footnote body</w:t></w:r></w:p></w:footnote></w:footnotes>",
      ),
    ],
  )
  let docx = @docx.parse_docx_document_from_package(pkg)
  let doc = @docxir.lower_docx_document(docx)
  let markdown = @cor.emit_markdown(doc)
  assert_docx_contains(markdown, "Main[^1] again [^1]")
  assert_eq(doc.note_definitions.val.length(), 1)
  assert_docx_note_definition(
    doc,
    0,
    "1",
    "1",
    @cor.NoteKind::Footnote,
    @cor.NoteSourceKind::DocxFootnoteBody,
    "Footnote body",
  )
}

///|
test "docx lowering uses conventional discovered notes without rels" {
  let pkg = generated_docx_package(
    "<w:p><w:r><w:t>Main</w:t><w:footnoteReference w:id=\"1\"/><w:endnoteReference w:id=\"2\"/><w:commentReference w:id=\"3\"/></w:r></w:p>",
    "",
    [
      (
        "word/footnotes.xml", "<w:footnotes xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:footnote w:id=\"1\"><w:p><w:r><w:t>Conventional footnote</w:t></w:r></w:p></w:footnote></w:footnotes>",
      ),
      (
        "word/endnotes.xml", "<w:endnotes xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:endnote w:id=\"2\"><w:p><w:r><w:t>Conventional endnote</w:t></w:r></w:p></w:endnote></w:endnotes>",
      ),
      (
        "word/comments.xml", "<w:comments xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:comment w:id=\"3\" w:author=\"Alice\"><w:p><w:r><w:t>Conventional comment</w:t></w:r></w:p></w:comment></w:comments>",
      ),
    ],
  )
  let docx = @docx.parse_docx_document_from_package(pkg)
  assert_docx_graph_part(
    docx.part_graph,
    @docx.DocxDiscoveredPartKind::Footnotes,
    @docx.DocxPartDiscoverySource::ConventionalPath,
    "word/footnotes.xml",
  )
  assert_docx_graph_part(
    docx.part_graph,
    @docx.DocxDiscoveredPartKind::Endnotes,
    @docx.DocxPartDiscoverySource::ConventionalPath,
    "word/endnotes.xml",
  )
  assert_docx_graph_part(
    docx.part_graph,
    @docx.DocxDiscoveredPartKind::Comments,
    @docx.DocxPartDiscoverySource::ConventionalPath,
    "word/comments.xml",
  )
  assert_eq(
    @cor.emit_markdown(@docxir.lower_docx_document(docx)),
    "Main[^1][^e2] [comment 1]\n\n" +
    "## Comments\n\n" +
    "1. Alice: Conventional comment\n\n" +
    "[^1]: Conventional footnote\n\n" +
    "[^e2]: Conventional endnote\n",
  )
}

///|
test "docx lowering missing refs stay unresolved and warn" {
  let docx = docx_from_body(
    "<w:p><w:r><w:t>Refs</w:t><w:footnoteReference w:id=\"9\"/><w:endnoteReference w:id=\"8\"/><w:commentReference w:id=\"7\"/></w:r></w:p>",
  )
  let markdown = @cor.emit_markdown(@docxir.lower_docx_document(docx))
  assert_eq(markdown, "Refs[^9][^e8] [comment 7]\n")
  let summary = @docxir.render_docx_warning_summary(docx)
  assert_docx_contains(summary, "UnresolvedFootnoteRef\tWarning\t")
  assert_docx_contains(summary, "unresolved footnote ref: 9")
  assert_docx_contains(summary, "UnresolvedEndnoteRef\tWarning\t")
  assert_docx_contains(summary, "unresolved endnote ref: 8")
  assert_docx_contains(summary, "UnresolvedCommentRef\tWarning\t")
  assert_docx_contains(summary, "unresolved comment ref: 7")
}

///|
test "docx lowering drawing media emits deterministic text placeholder" {
  let docx = docx_from_body(
    "<w:p><w:r><w:t>Before </w:t></w:r>" +
    "<w:r><w:drawing><wp:inline xmlns:wp=\"http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing\">" +
    "<wp:docPr id=\"1\" name=\"Picture 1\" descr=\"Diagram alt\"/>" +
    "<a:graphic xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\"><a:graphicData>" +
    "<pic:pic xmlns:pic=\"http://schemas.openxmlformats.org/drawingml/2006/picture\"><pic:blipFill><a:blip r:embed=\"rIdMissing\"/></pic:blipFill></pic:pic>" +
    "</a:graphicData></a:graphic></wp:inline></w:drawing></w:r>" +
    "<w:r><w:t> After</w:t></w:r></w:p>",
  )
  assert_eq(
    @docxir.render_docx_plain_text(docx),
    "Before [image: Diagram alt] After",
  )
  match docx.body[0] {
    @docx.DocxBlock::Paragraph(p) =>
      match p.inlines[1] {
        @docx.DocxInline::Drawing(drawing) => {
          assert_true(drawing.descr == Some("Diagram alt"))
          assert_true(drawing.media is Some(_))
        }
        _ => fail("expected drawing anchor")
      }
    _ => fail("expected paragraph")
  }
  assert_eq(
    @cor.emit_markdown(@docxir.lower_docx_document(docx)),
    "Before [image: Diagram alt] After\n",
  )
}

///|
test "docx asset lowering exports internal image as ImageBlock" {
  let pkg = generated_docx_package(
    "<w:p><w:r>" +
    generated_docx_image_xml("rIdImage", "Diagram alt", "Diagram title") +
    "</w:r></w:p>",
    "<Relationship Id=\"rIdImage\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/image1.png\"/>",
    [("word/media/image1.png", "png-bytes")],
  )
  let docx = @docx.parse_docx_document_from_package(pkg)
  let out_dir = fresh_docx_test_dir("internal")
  let lowered = @docxir.lower_docx_document_with_assets(docx, pkg, out_dir)
  assert_eq(lowered.assets.length(), 1)
  assert_eq(lowered.assets[0].path, "assets/image01.png")
  assert_eq(lowered.assets[0].source_part, "word/media/image1.png")
  assert_true(lowered.assets[0].content_type == Some("image/png"))
  assert_true(lowered.assets[0].relationship_id == Some("rIdImage"))
  assert_true(@fs.path_exists(out_dir + "/assets/image01.png"))
  match first_docx_image_block(lowered.document) {
    Some(img) => {
      assert_eq(img.path, "assets/image01.png")
      assert_true(img.alt_text == Some("Diagram alt"))
      assert_true(img.title == Some("Diagram title"))
      match img.origin {
        Some(origin) => {
          assert_true(origin.source_name == Some("word/document.xml"))
          assert_true(origin.block_index == Some(0))
          assert_true(origin.relationship_id == Some("rIdImage"))
          assert_true(origin.object_ref is Some(_))
        }
        None => fail("expected image origin")
      }
    }
    None => fail("expected ImageBlock")
  }
  match lowered.document.asset_origins.val.get("assets/image01.png") {
    Some(origin) => {
      assert_true(origin.source_name == Some("word/document.xml"))
      assert_true(origin.relationship_id == Some("rIdImage"))
      assert_true(origin.source_path == Some("word/media/image1.png"))
      assert_true(origin.origin_id is Some(_))
      assert_true(origin.key_path is Some(_))
    }
    None => fail("expected asset origin")
  }
  assert_eq(
    @cor.emit_markdown(lowered.document),
    "![Diagram alt](assets/image01.png)\n*Diagram title*\n",
  )
}

///|
test "docx asset lowering splits text image text paragraph" {
  let pkg = generated_docx_package(
    "<w:p><w:r><w:t>Before </w:t></w:r><w:r>" +
    generated_docx_image_xml("rIdImage", "Diagram alt", "Diagram title") +
    "</w:r><w:r><w:t> After</w:t></w:r></w:p>",
    "<Relationship Id=\"rIdImage\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/image1.png\"/>",
    [("word/media/image1.png", "png-bytes")],
  )
  let docx = @docx.parse_docx_document_from_package(pkg)
  let out_dir = fresh_docx_test_dir("mixed")
  let lowered = @docxir.lower_docx_document_with_assets(docx, pkg, out_dir)
  assert_eq(lowered.assets.length(), 1)
  assert_eq(lowered.document.blocks.val.length(), 3)
  assert_docx_paragraph_block(lowered.document, 0, "Before ")
  assert_docx_image_block(
    lowered.document,
    1,
    "assets/image01.png",
    "Diagram alt",
  )
  assert_docx_paragraph_block(lowered.document, 2, " After")
  assert_eq(
    @cor.emit_markdown(lowered.document),
    "Before\n\n![Diagram alt](assets/image01.png)\n*Diagram title*\n\nAfter\n",
  )
}

///|
test "docx asset lowering splits two images in one paragraph deterministically" {
  let pkg = generated_docx_package(
    "<w:p><w:r><w:t>A</w:t></w:r><w:r>" +
    generated_docx_image_xml("rIdOne", "One", "") +
    "</w:r><w:r><w:t>B</w:t></w:r><w:r>" +
    generated_docx_image_xml("rIdTwo", "Two", "") +
    "</w:r><w:r><w:t>C</w:t></w:r></w:p>",
    "<Relationship Id=\"rIdOne\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/one.png\"/>" +
    "<Relationship Id=\"rIdTwo\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/two.png\"/>",
    [("word/media/one.png", "one-bytes"), ("word/media/two.png", "two-bytes")],
  )
  let docx = @docx.parse_docx_document_from_package(pkg)
  let out_dir = fresh_docx_test_dir("two_images")
  let lowered = @docxir.lower_docx_document_with_assets(docx, pkg, out_dir)
  assert_eq(lowered.assets.length(), 2)
  assert_eq(lowered.assets[0].path, "assets/image01.png")
  assert_eq(lowered.assets[1].path, "assets/image02.png")
  assert_eq(lowered.document.blocks.val.length(), 5)
  assert_docx_paragraph_block(lowered.document, 0, "A")
  assert_docx_image_block(lowered.document, 1, "assets/image01.png", "One")
  assert_docx_paragraph_block(lowered.document, 2, "B")
  assert_docx_image_block(lowered.document, 3, "assets/image02.png", "Two")
  assert_docx_paragraph_block(lowered.document, 4, "C")
}

///|
test "docx asset lowering exports real sample image with alt and title" {
  let sample = resolve_docx_sample_path(
    "samples/main_process/docx/docx_image_alt_title.docx",
  )
  let out_dir = fresh_docx_test_dir("real_image")
  let lowered = @docxir.open_docx_document_with_assets(sample, out_dir)
  assert_eq(lowered.assets.length(), 1)
  assert_eq(lowered.assets[0].path, "assets/image01.png")
  assert_true(lowered.assets[0].source_part == "word/media/image1.png")
  assert_true(lowered.assets[0].alt_text == Some("Figure alt text"))
  assert_true(lowered.assets[0].title == Some("Figure title text"))
  assert_true(@fs.path_exists(out_dir + "/assets/image01.png"))
  match first_docx_image_block(lowered.document) {
    Some(img) => {
      assert_eq(img.path, "assets/image01.png")
      assert_true(img.alt_text == Some("Figure alt text"))
      assert_true(img.title == Some("Figure title text"))
    }
    None => fail("expected ImageBlock")
  }
  let markdown = @cor.emit_markdown(lowered.document)
  assert_true(markdown.contains("![Figure alt text](assets/image01.png)"))
  assert_true(markdown.contains("*Figure title text*"))
}

///|
test "docx lowering table cell media uses model placeholder" {
  let docx = docx_from_body(
    "<w:tbl><w:tr><w:tc><w:p><w:r><w:drawing>" +
    "<wp:inline xmlns:wp=\"http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing\"><wp:docPr id=\"1\" name=\"Picture 1\" descr=\"Table image\"/>" +
    "<a:graphic xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\"><a:graphicData><pic:pic xmlns:pic=\"http://schemas.openxmlformats.org/drawingml/2006/picture\"><pic:blipFill><a:blip r:embed=\"rIdMissing\"/></pic:blipFill></pic:pic></a:graphicData></a:graphic>" +
    "</wp:inline></w:drawing></w:r></w:p></w:tc></w:tr></w:tbl>",
  )
  assert_eq(@docxir.render_docx_plain_text(docx), "[image: Table image]")
  assert_eq(
    @cor.emit_markdown(@docxir.lower_docx_document(docx)),
    "| Column 1 |\n| --- |\n| [image: Table image] |\n",
  )
}

///|
test "docx asset lowering exports table cell image while preserving table placeholder" {
  let pkg = generated_docx_package(
    "<w:tbl><w:tr><w:tc><w:p><w:r>" +
    generated_docx_image_xml("rIdImage", "Table image", "") +
    "</w:r></w:p></w:tc></w:tr></w:tbl>",
    "<Relationship Id=\"rIdImage\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/image1.png\"/>",
    [("word/media/image1.png", "png-bytes")],
  )
  let docx = @docx.parse_docx_document_from_package(pkg)
  let out_dir = fresh_docx_test_dir("table")
  let lowered = @docxir.lower_docx_document_with_assets(docx, pkg, out_dir)
  assert_eq(lowered.assets.length(), 1)
  assert_eq(lowered.assets[0].path, "assets/image01.png")
  assert_true(@fs.path_exists(out_dir + "/assets/image01.png"))
  assert_eq(
    @cor.emit_markdown(lowered.document),
    "| Column 1 |\n| --- |\n| [image: Table image] |\n",
  )
}

///|
test "docx asset lowering missing media part keeps placeholder and warning" {
  let pkg = generated_docx_package(
    "<w:p><w:r>" +
    generated_docx_image_xml("rIdImage", "Missing image", "") +
    "</w:r></w:p>",
    "<Relationship Id=\"rIdImage\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/missing.png\"/>",
    [],
  )
  let docx = @docx.parse_docx_document_from_package(pkg)
  let out_dir = fresh_docx_test_dir("missing_part")
  let lowered = @docxir.lower_docx_document_with_assets(docx, pkg, out_dir)
  assert_eq(lowered.assets.length(), 0)
  assert_eq(@cor.emit_markdown(lowered.document), "[image: Missing image]\n")
  let summary = @docxir.render_docx_warning_summary(docx)
  assert_docx_contains(summary, "MissingMediaPart\tWarning\t")
  assert_docx_contains(summary, "media part is missing: word/media/missing.png")
}

///|
test "docx asset lowering external linked image keeps placeholder and warning" {
  let pkg = generated_docx_package(
    "<w:p><w:r><w:drawing><a:blip xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" r:link=\"rIdLinked\"/></w:drawing></w:r></w:p>",
    "<Relationship Id=\"rIdLinked\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"https://example.com/image.png\" TargetMode=\"External\"/>",
    [],
  )
  let docx = @docx.parse_docx_document_from_package(pkg)
  let out_dir = fresh_docx_test_dir("external")
  let lowered = @docxir.lower_docx_document_with_assets(docx, pkg, out_dir)
  assert_eq(lowered.assets.length(), 0)
  assert_eq(
    @cor.emit_markdown(lowered.document),
    "[image: https://example.com/image.png]\n",
  )
  let summary = @docxir.render_docx_warning_summary(docx)
  assert_docx_contains(summary, "UnsupportedMedia\tWarning\t")
  assert_docx_contains(
    summary, "external linked media not exported: https://example.com/image.png",
  )
}

///|
test "docx asset lowering mixed missing and external images stay placeholders" {
  let pkg = generated_docx_package(
    "<w:p><w:r><w:t>Before </w:t></w:r><w:r>" +
    generated_docx_image_xml("rIdMissing", "Missing image", "") +
    "</w:r><w:r><w:t> and </w:t></w:r><w:r><w:drawing><a:blip xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" r:link=\"rIdLinked\"/></w:drawing></w:r><w:r><w:t> after</w:t></w:r></w:p>",
    "<Relationship Id=\"rIdMissing\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/missing.png\"/>" +
    "<Relationship Id=\"rIdLinked\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"https://example.com/image.png\" TargetMode=\"External\"/>",
    [],
  )
  let docx = @docx.parse_docx_document_from_package(pkg)
  let out_dir = fresh_docx_test_dir("mixed_missing_external")
  let lowered = @docxir.lower_docx_document_with_assets(docx, pkg, out_dir)
  assert_eq(lowered.assets.length(), 0)
  assert_eq(
    @cor.emit_markdown(lowered.document),
    "Before [image: Missing image] and [image: https://example.com/image.png] after\n",
  )
  let summary = @docxir.render_docx_warning_summary(docx)
  assert_docx_contains(summary, "MissingMediaPart\tWarning\t")
  assert_docx_contains(summary, "UnsupportedMedia\tWarning\t")
}

///|
test "docx lowering emits typed secondary container appendices" {
  let pkg = generated_docx_package(
    "<w:p><w:r><w:t>Main</w:t></w:r></w:p>",
    "<Relationship Id=\"rIdFoot\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes\" Target=\"footnotes.xml\"/>" +
    "<Relationship Id=\"rIdComments\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments\" Target=\"comments.xml\"/>" +
    "<Relationship Id=\"rIdHeader\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/header\" Target=\"header1.xml\"/>" +
    "<Relationship Id=\"rIdFooter\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer\" Target=\"footer1.xml\"/>",
    [
      (
        "word/footnotes.xml", "<w:footnotes xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:footnote w:id=\"1\"><w:p><w:r><w:t>Footnote body</w:t></w:r></w:p></w:footnote></w:footnotes>",
      ),
      (
        "word/comments.xml", "<w:comments xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:comment w:id=\"3\" w:author=\"Alice\"><w:p><w:r><w:t>Comment body</w:t></w:r></w:p></w:comment></w:comments>",
      ),
      (
        "word/header1.xml", "<w:hdr xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:p><w:r><w:t>Header body</w:t></w:r></w:p></w:hdr>",
      ),
      (
        "word/footer1.xml", "<w:ftr xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:p><w:r><w:t>Footer body</w:t></w:r></w:p></w:ftr>",
      ),
    ],
  )
  let docx = @docx.parse_docx_document_from_package(pkg)
  assert_eq(docx.footnotes.length(), 1)
  assert_eq(docx.comments.length(), 1)
  assert_eq(docx.headers.length(), 1)
  assert_eq(docx.footers.length(), 1)
  assert_eq(
    @cor.emit_markdown(@docxir.lower_docx_document(docx)),
    "Main\n\n" +
    "## Headers\n\n" +
    "### Header 1 Default\n\n" +
    "Header body\n\n" +
    "## Footers\n\n" +
    "### Footer 1 Default\n\n" +
    "Footer body\n",
  )
}

///|
test "docx lowering empty content controls are silent typed blocks" {
  let docx = docx_from_body("<w:sdt><w:sdtContent/></w:sdt>")
  assert_eq(@docxir.render_docx_plain_text(docx), "")
  assert_eq(@cor.emit_markdown(@docxir.lower_docx_document(docx)), "")
  assert_eq(docx.warnings.length(), 0)
}

///|
test "docx lowering benign structural body nodes are silent" {
  let docx = docx_from_body(
    "<w:bookmarkStart w:id=\"1\" w:name=\"mark\"/>" +
    "<w:proofErr w:type=\"spellStart\"/>" +
    "<w:permStart w:id=\"2\"/>" +
    "<w:p><w:r><w:t>Visible</w:t></w:r></w:p>" +
    "<w:sectPr><w:pgSz w:w=\"12240\" w:h=\"15840\"/><w:pgMar w:top=\"1440\"/></w:sectPr>",
  )
  assert_eq(@cor.emit_markdown(@docxir.lower_docx_document(docx)), "Visible\n")
  assert_true(!@docxir.render_docx_plain_text(docx).contains("Unsupported"))
}

///|
test "docx lowering comment range boundaries are silent but refs remain" {
  let docx = docx_from_body(
    "<w:p><w:commentRangeStart w:id=\"3\"/><w:r><w:t>Text</w:t><w:commentReference w:id=\"3\"/></w:r><w:commentRangeEnd w:id=\"3\"/></w:p>",
  )
  assert_eq(
    @cor.emit_markdown(@docxir.lower_docx_document(docx)),
    "Text [comment 3]\n",
  )
}

///|
test "docx lowering appends textbox appendix body" {
  let docx = docx_from_body(
    "<w:p><w:r><w:t>Body before.</w:t></w:r></w:p>" +
    "<w:p><w:r><w:t>Body after.</w:t></w:r></w:p>" +
    "<w:p><w:r><w:txbxContent><w:p><w:r><w:t>Text box body.</w:t></w:r></w:p></w:txbxContent></w:r></w:p>",
  )
  let markdown = @cor.emit_markdown(@docxir.lower_docx_document(docx))
  assert_true(!markdown.contains("[unsupported DOCX inline]"))
  assert_true(!markdown.contains("[image]"))
  assert_eq(@docxir.render_docx_plain_text(docx), "Body before.\n\nBody after.")
  assert_eq(docx.textboxes.length(), 1)
  assert_true(docx.textboxes[0].anchor_id == "word/document.xml#textbox:0")
  match docx.body[2] {
    @docx.DocxBlock::Paragraph(p) =>
      match p.inlines[0] {
        @docx.DocxInline::TextBoxRef(textbox_ref) =>
          assert_true(
            textbox_ref.anchor_id == Some("word/document.xml#textbox:0"),
          )
        _ => fail("expected textbox ref")
      }
    _ => fail("expected paragraph")
  }
  assert_docx_contains(markdown, "Body before.")
  assert_docx_contains(markdown, "Body after.")
  assert_docx_contains(markdown, "## Text Boxes")
  assert_docx_contains(markdown, "### Text Box 1")
  assert_docx_contains(markdown, "Text box body.")
}

///|
test "docx lowering vml textbox shape is appendix not image" {
  let docx = docx_from_body(
    "<w:p><w:r><w:t>Before</w:t></w:r></w:p>" +
    "<w:p><w:r><w:pict><v:shape xmlns:v=\"urn:schemas-microsoft-com:vml\" id=\"shape1\" alt=\"Shape text\">" +
    "<w:txbxContent><w:p><w:r><w:t>VML textbox body.</w:t></w:r></w:p></w:txbxContent>" +
    "</v:shape></w:pict></w:r></w:p>",
  )
  let markdown = @cor.emit_markdown(@docxir.lower_docx_document(docx))
  assert_true(!markdown.contains("[image]"))
  assert_true(!markdown.contains("[unsupported DOCX inline]"))
  assert_docx_contains(markdown, "Before")
  assert_docx_contains(markdown, "## Text Boxes")
  assert_docx_contains(markdown, "VML textbox body.")
  match docx.body[1] {
    @docx.DocxBlock::Paragraph(p) =>
      match p.inlines[0] {
        @docx.DocxInline::Shape(shape) => {
          assert_true(shape.media is None)
          assert_true(shape.text_box_ref is Some(_))
        }
        _ => fail("expected shape anchor")
      }
    _ => fail("expected paragraph")
  }
}

///|
test "docx lowering move range and rendered page break controls are silent" {
  let docx = docx_from_body(
    "<w:p><w:moveFromRangeStart w:id=\"4\"/><w:r><w:t>A</w:t>" +
    "<w:lastRenderedPageBreak/><w:t>B</w:t></w:r><w:moveToRangeEnd w:id=\"4\"/></w:p>",
  )
  assert_eq(@docxir.render_docx_plain_text(docx), "AB")
  assert_eq(@cor.emit_markdown(@docxir.lower_docx_document(docx)), "AB\n")
  assert_true(!@docxir.render_docx_plain_text(docx).contains("Unsupported"))
}

///|
test "docx lowering content controls and smart tags preserve children" {
  let docx = docx_from_body(
    "<w:sdt><w:sdtContent><w:p><w:r><w:t>Content control</w:t></w:r></w:p></w:sdtContent></w:sdt>" +
    "<w:p><w:r><w:t>A</w:t></w:r><w:smartTag><w:r><w:t>Smart</w:t></w:r></w:smartTag></w:p>",
  )
  let text = @docxir.render_docx_plain_text(docx)
  assert_true(text.contains("Content control"))
  assert_true(text.contains("ASmart"))
  let markdown = @cor.emit_markdown(@docxir.lower_docx_document(docx))
  assert_docx_contains(markdown, "Content control")
  assert_docx_contains(markdown, "ASmart")
  assert_true(!markdown.contains("[unsupported DOCX inline]"))
  assert_true(!markdown.contains("Unsupported DOCX node"))
  assert_eq(docx.warnings.length(), 0)
}

///|
fn resolve_docx_sample_path(path : String) -> String raise {
  if @fs.path_exists(path) {
    return path
  }

  let sample_root_candidate = "../../../" + path
  if @fs.path_exists(sample_root_candidate) {
    return sample_root_candidate
  }

  fail("sample file not found: " + path)
}

///|
fn open_docx_sample(
  path : String,
) -> (@docx.DocxDocument, @cor.Document, String) raise {
  let sample = resolve_docx_sample_path(path)
  let model = @docxir.open_docx_model(sample)
  let doc = @docxir.lower_docx_document(model)
  let markdown = @cor.emit_markdown(doc)
  (model, doc, markdown)
}

///|
fn docx_has_warning_kind(
  docx : @docx.DocxDocument,
  kind : @docx.DocxWarningKind,
) -> Bool {
  for warning in docx.warnings {
    if warning.kind == kind {
      return true
    }
  }
  false
}

///|
fn docx_markdown_has_table(doc : @cor.Document) -> Bool {
  for block in doc.blocks.val {
    match block {
      @cor.Block::RichTable(_) | @cor.Block::Table(_) => return true
      _ => ()
    }
  }
  false
}

///|
fn docx_markdown_has_list_item(doc : @cor.Document) -> Bool {
  for block in doc.blocks.val {
    match block {
      @cor.Block::ListItem(_, _, _) | @cor.Block::RichListItem(_, _, _) =>
        return true
      _ => ()
    }
  }
  false
}

///|
test "docx real sample smoke parses and lowers simple paragraph" {
  let (model, doc, markdown) = open_docx_sample(
    "samples/main_process/docx/docx_paragraph_linebreak.docx",
  )
  assert_true(model.body.length() > 0)
  assert_true(doc.blocks.val.length() > 0)
  assert_true(markdown.contains("First line"))
  assert_true(markdown.contains("Second line"))
  assert_true(markdown.contains("<br>"))
}

///|
test "docx real sample smoke preserves hyperlink text and target" {
  let (model, doc, markdown) = open_docx_sample(
    "samples/main_process/docx/docx_hyperlink_basic.docx",
  )
  assert_true(model.body.length() >= 2)
  assert_true(doc.blocks.val.length() >= 2)
  assert_true(markdown.contains("Visit"))
  assert_true(markdown.contains("[OpenAI](https://openai.com)"))
  assert_true(
    !docx_has_warning_kind(model, @docx.DocxWarningKind::MissingHyperlinkTarget),
  )
}

///|
test "docx real sample smoke lowers simple table cell text" {
  let (model, doc, markdown) = open_docx_sample(
    "samples/main_process/docx/docx_table_multiline_cell.docx",
  )
  assert_true(model.body.length() > 0)
  assert_true(docx_markdown_has_table(doc))
  assert_true(markdown.contains("Col A"))
  assert_true(markdown.contains("Line 1<br>Line 2"))
  assert_true(markdown.contains("Value"))
}

///|
test "docx real sample smoke lowers image placeholder" {
  let (model, doc, markdown) = open_docx_sample(
    "samples/main_process/docx/docx_image_alt_title.docx",
  )
  assert_true(model.body.length() > 0)
  assert_true(doc.blocks.val.length() > 0)
  assert_true(markdown.contains("[image: Figure alt text]"))
  assert_true(@docxir.render_docx_plain_text(model).contains("[image:"))
}

///|
test "docx real sample smoke lowers headings and list refs" {
  let (_, heading_doc, heading_markdown) = open_docx_sample(
    "samples/main_process/docx/docx_heading_levels.docx",
  )
  assert_true(heading_doc.blocks.val.length() > 0)
  assert_true(heading_markdown.contains("# Heading Level 1"))
  assert_true(heading_markdown.contains("###### Heading Level 6"))

  let (list_model, list_doc, list_markdown) = open_docx_sample(
    "samples/main_process/docx/docx_list_basic.docx",
  )
  assert_true(list_model.numbering.levels.length() > 0)
  assert_true(docx_markdown_has_list_item(list_doc))
  assert_true(list_markdown.contains("- item A"))
  assert_true(list_markdown.contains("- item B"))
}

///|
test "docx real sample smoke parses note and comment refs conservatively" {
  let (model, doc, markdown) = open_docx_sample(
    "samples/main_process/docx/docx_footnotes_endnotes_comments.docx",
  )
  assert_true(doc.blocks.val.length() > 0)
  assert_true(model.footnotes.length() > 0)
  assert_true(model.endnotes.length() > 0)
  assert_true(model.comments.length() > 0)
  assert_true(markdown.contains("[^1]"))
  assert_true(markdown.contains("[^e1]"))
  assert_true(markdown.contains("[comment 1]"))
  assert_true(markdown.contains("## Comments"))
  assert_true(markdown.contains("Footnote[^1] then comment [comment 1]"))
  assert_true(markdown.contains("Endnote[^e1]"))
  assert_true(markdown.contains("Footnote body."))
  assert_true(markdown.contains("Endnote body."))
  assert_true(markdown.contains("1. Alice: Comment body."))
}

///|
test "docx real sample smoke appends textbox appendix" {
  let (_, _, markdown) = open_docx_sample(
    "samples/main_process/docx/docx_textbox_basic.docx",
  )
  assert_true(markdown.contains("## Text Boxes"))
  assert_true(markdown.contains("### Text Box 1"))
  assert_true(markdown.contains("Text box body."))
}

///|
test "docx real sample smoke warning summary is deterministic for missing hyperlink rel" {
  let (model, _, markdown) = open_docx_sample(
    "samples/main_process/docx/docx_hyperlink_missing_rel_negative.docx",
  )
  assert_true(markdown.contains("Visit"))
  assert_true(markdown.contains("Broken Link"))
  assert_true(
    docx_has_warning_kind(model, @docx.DocxWarningKind::MissingHyperlinkTarget),
  )
  let summary = @docxir.render_docx_warning_summary(model)
  assert_true(summary.contains("MissingHyperlinkTarget\tWarning\t"))
  assert_true(summary.contains("hyperlink relationship not found: rId9"))
  assert_true(
    summary.contains("word/document.xml#0:word/document.xml:p:0:hyperlink:1"),
  )
}
