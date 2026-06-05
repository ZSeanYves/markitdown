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
fn minimal_content_types_xml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">" +
  "<Default Extension=\"xml\" ContentType=\"application/xml\"/>" +
  "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>" +
  "<Default Extension=\"png\" ContentType=\"image/png\"/>" +
  "<Default Extension=\"jpg\" ContentType=\"image/jpeg\"/>" +
  "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>" +
  "</Types>"
}

///|
fn minimal_rels_xml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
  "<Relationship Id=\"rIdMain\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/>" +
  "</Relationships>"
}

///|
fn document_rels_xml(inner : String) -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
  inner +
  "</Relationships>"
}

///|
fn generated_docx_package(document_body : String) -> @ox.OoxmlPackage raise {
  generated_docx_package_with_document_rels(document_body, "")
}

///|
fn generated_docx_package_with_document_rels(
  document_body : String,
  document_rels : String,
) -> @ox.OoxmlPackage raise {
  generated_docx_package_with_document_rels_and_entries(
    document_body,
    document_rels,
    [],
  )
}

///|
fn generated_docx_package_with_document_rels_and_entries(
  document_body : String,
  document_rels : String,
  extra_entries : Array[(String, String)],
) -> @ox.OoxmlPackage raise {
  let document_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" " +
    "xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
    "<w:body>" +
    document_body +
    "</w:body></w:document>"
  let entries : Array[(String, String)] = [
    ("[Content_Types].xml", minimal_content_types_xml()),
    ("_rels/.rels", minimal_rels_xml()),
    ("word/document.xml", document_xml),
  ]
  if document_rels != "" {
    entries.push(
      ("word/_rels/document.xml.rels", document_rels_xml(document_rels)),
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
fn generated_docx_drawing_xml(
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
  "<a:graphic xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\">" +
  "<a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/picture\">" +
  "<pic:pic xmlns:pic=\"http://schemas.openxmlformats.org/drawingml/2006/picture\">" +
  "<pic:blipFill><a:blip r:embed=\"" +
  rid +
  "\"/></pic:blipFill>" +
  "</pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing>"
}

///|
fn count_docx_discovered_parts(
  graph : @docx.DocxPartGraph,
  kind : @docx.DocxDiscoveredPartKind,
  source : @docx.DocxPartDiscoverySource,
) -> Int {
  let mut count = 0
  for part in graph.parts {
    if part.kind == kind && part.source == source {
      count += 1
    }
  }
  count
}

///|
fn assert_docx_discovered_part(
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
test "docx parses two body paragraphs from generated package" {
  let pkg = generated_docx_package(
    "<w:p><w:r><w:t>First</w:t></w:r></w:p>" +
    "<w:p><w:r><w:t>Second</w:t></w:r></w:p>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  assert_eq(doc.main_part, "word/document.xml")
  assert_eq(doc.body.length(), 2)
  match doc.body[0] {
    @docx.DocxBlock::Paragraph(p) => assert_eq(p.text, "First")
    _ => fail("expected first paragraph")
  }
  match doc.body[1] {
    @docx.DocxBlock::Paragraph(p) => assert_eq(p.source_key.block_index, 1)
    _ => fail("expected second paragraph")
  }
}

///|
test "docx parses text tab and line break in paragraph model" {
  let pkg = generated_docx_package(
    "<w:p><w:r><w:t>Left</w:t><w:tab/><w:t>Right</w:t><w:br/><w:t>Next</w:t></w:r></w:p>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Paragraph(p) => {
      assert_eq(p.text, "Left\tRight\nNext")
      assert_eq(p.inlines.length(), 5)
      assert_true(p.inlines[1] is @docx.DocxInline::Tab)
      match p.inlines[3] {
        @docx.DocxInline::Break(value) =>
          assert_true(value.kind == @docx.DocxBreakKind::Line)
        _ => fail("expected typed break")
      }
    }
    _ => fail("expected paragraph")
  }
}

///|
test "docx preserves paragraph table paragraph source order" {
  let pkg = generated_docx_package(
    "<w:p><w:r><w:t>Before</w:t></w:r></w:p>" +
    "<w:tbl><w:tr><w:tc><w:p><w:r><w:t>Cell</w:t></w:r></w:p></w:tc></w:tr></w:tbl>" +
    "<w:p><w:r><w:t>After</w:t></w:r></w:p>",
  )
  let source = @docx.parse_docx_source_from_package(pkg)
  assert_eq(source.parts[0].blocks.length(), 3)
  assert_true(
    source.parts[0].blocks[0].kind == @docx.DocxSourceBlockKind::Paragraph,
  )
  assert_true(
    source.parts[0].blocks[1].kind == @docx.DocxSourceBlockKind::Table,
  )
  assert_true(
    source.parts[0].blocks[2].kind == @docx.DocxSourceBlockKind::Paragraph,
  )
  let doc = @docx.normalize_docx_source(source)
  assert_true(doc.body[1] is @docx.DocxBlock::Table(_))
}

///|
test "docx parses simple 2x2 table row cell order and text" {
  let pkg = generated_docx_package(
    "<w:tbl>" +
    "<w:tr><w:tc><w:p><w:r><w:t>A1</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>B1</w:t></w:r></w:p></w:tc></w:tr>" +
    "<w:tr><w:tc><w:p><w:r><w:t>A2</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>B2</w:t></w:r></w:p></w:tc></w:tr>" +
    "</w:tbl>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Table(table) => {
      assert_eq(table.rows.length(), 2)
      assert_eq(table.rows[0].cells.length(), 2)
      assert_eq(table.rows[0].cells[0].text, "A1")
      assert_eq(table.rows[0].cells[1].text, "B1")
      assert_eq(table.rows[1].cells[0].text, "A2")
      assert_eq(table.rows[1].cells[1].text, "B2")
    }
    _ => fail("expected parsed table")
  }
}

///|
test "docx captures explicit table header row marker" {
  let pkg = generated_docx_package(
    "<w:tbl>" +
    "<w:tr><w:trPr><w:tblHeader/></w:trPr><w:tc><w:p><w:r><w:t>Head</w:t></w:r></w:p></w:tc></w:tr>" +
    "<w:tr><w:tc><w:p><w:r><w:t>Body</w:t></w:r></w:p></w:tc></w:tr>" +
    "</w:tbl>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Table(table) => {
      assert_true(table.rows[0].is_header)
      assert_true(!table.rows[1].is_header)
    }
    _ => fail("expected parsed table")
  }
}

///|
test "docx table without header marker remains non-header" {
  let pkg = generated_docx_package(
    "<w:tbl><w:tr><w:tc><w:p><w:r><w:t>Head-ish</w:t></w:r></w:p></w:tc></w:tr></w:tbl>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Table(table) => assert_true(!table.rows[0].is_header)
    _ => fail("expected parsed table")
  }
}

///|
test "docx table cell hyperlink reuses paragraph hyperlink parser" {
  let pkg = generated_docx_package(
    "<w:tbl><w:tr><w:tc><w:p><w:hyperlink w:anchor=\"target\"><w:r><w:t>Jump</w:t></w:r></w:hyperlink></w:p></w:tc></w:tr></w:tbl>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Table(table) =>
      match table.rows[0].cells[0].blocks[0] {
        @docx.DocxBlock::Paragraph(p) =>
          match p.inlines[0] {
            @docx.DocxInline::Hyperlink(link) => {
              assert_eq(link.text, "Jump")
              assert_true(link.target == Some("#target"))
            }
            _ => fail("expected hyperlink inline")
          }
        _ => fail("expected paragraph cell block")
      }
    _ => fail("expected parsed table")
  }
}

///|
test "docx table gridSpan and vMerge refs are captured" {
  let pkg = generated_docx_package(
    "<w:tbl>" +
    "<w:tr><w:tc><w:tcPr><w:gridSpan w:val=\"2\"/><w:vMerge w:val=\"restart\"/></w:tcPr><w:p><w:r><w:t>Merged</w:t></w:r></w:p></w:tc></w:tr>" +
    "<w:tr><w:tc><w:tcPr><w:vMerge/></w:tcPr><w:p><w:r><w:t>Continue</w:t></w:r></w:p></w:tc></w:tr>" +
    "</w:tbl>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Table(table) => {
      assert_true(table.rows[0].cells[0].grid_span == Some("2"))
      assert_true(table.rows[0].cells[0].vertical_merge == Some("restart"))
      assert_true(table.rows[1].cells[0].vertical_merge == Some("continue"))
    }
    _ => fail("expected parsed table")
  }
}

///|
test "docx nested table preserves child table structure" {
  let pkg = generated_docx_package(
    "<w:tbl><w:tr><w:tc>" +
    "<w:p><w:r><w:t>Outer</w:t></w:r></w:p>" +
    "<w:tbl><w:tr><w:tc><w:p><w:r><w:t>Inner</w:t></w:r></w:p></w:tc></w:tr></w:tbl>" +
    "</w:tc></w:tr></w:tbl>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Table(table) => {
      let cell = table.rows[0].cells[0]
      assert_true(cell.has_nested_table)
      assert_eq(cell.nesting_depth, 0)
      assert_eq(cell.max_nested_depth, 1)
      match cell.blocks[1] {
        @docx.DocxBlock::Table(nested) => {
          assert_eq(nested.nesting_depth, 1)
          assert_eq(nested.rows[0].cells[0].text, "Inner")
        }
        _ => fail("expected nested table")
      }
      assert_eq(doc.warnings.length(), 0)
    }
    _ => fail("expected parsed table")
  }
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
test "docx deep nested table guard is bounded and typed" {
  let pkg = generated_docx_package(docx_deep_table_xml(8))
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Table(table) => {
      assert_eq(table.nesting_depth, 0)
      assert_true(table.max_nested_depth >= 7)
      assert_true(table.deep_table_guard_triggered)
    }
    _ => fail("expected table")
  }
  let mut has_nested_warning = false
  for warning in doc.warnings {
    if warning.kind == @docx.DocxWarningKind::NestedTable {
      has_nested_warning = true
    }
  }
  assert_true(has_nested_warning)
}

///|
test "docx preserves empty content control as typed block" {
  let pkg = generated_docx_package(
    "<w:p><w:r><w:t>Known</w:t></w:r></w:p><w:sdt><w:sdtContent/></w:sdt>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  assert_eq(doc.body.length(), 2)
  match doc.body[1] {
    @docx.DocxBlock::ContentControl(control) => {
      assert_eq(control.tag, "w:sdt")
      assert_eq(control.blocks.length(), 0)
      assert_eq(control.inlines.length(), 0)
    }
    _ => fail("expected content control")
  }
  assert_eq(doc.warnings.length(), 0)
}

///|
test "docx classifies body sectPr as structural marker" {
  let pkg = generated_docx_package(
    "<w:p><w:r><w:t>Known</w:t></w:r></w:p>" +
    "<w:sectPr><w:pgSz w:w=\"12240\" w:h=\"15840\"/><w:pgMar w:top=\"1440\"/></w:sectPr>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  assert_eq(doc.body.length(), 2)
  match doc.body[1] {
    @docx.DocxBlock::StructuralMarker(marker) => {
      assert_true(marker.kind == @docx.DocxStructuralKind::SectionProperties)
      assert_eq(marker.tag, "w:sectPr")
    }
    _ => fail("expected structural marker")
  }
}

///|
test "docx classifies body bookmark proof and permission markers" {
  let pkg = generated_docx_package(
    "<w:bookmarkStart w:id=\"1\" w:name=\"mark\"/>" +
    "<w:proofErr w:type=\"spellStart\"/>" +
    "<w:permStart w:id=\"2\"/>" +
    "<w:permEnd w:id=\"2\"/>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  assert_eq(doc.body.length(), 4)
  match doc.body[0] {
    @docx.DocxBlock::StructuralMarker(marker) =>
      assert_true(marker.kind == @docx.DocxStructuralKind::BookmarkBoundary)
    _ => fail("expected bookmark marker")
  }
  match doc.body[1] {
    @docx.DocxBlock::StructuralMarker(marker) =>
      assert_true(marker.kind == @docx.DocxStructuralKind::ProofError)
    _ => fail("expected proof marker")
  }
  match doc.body[2] {
    @docx.DocxBlock::StructuralMarker(marker) =>
      assert_true(marker.kind == @docx.DocxStructuralKind::PermissionBoundary)
    _ => fail("expected permission marker")
  }
}

///|
test "docx classifies comment range boundaries but keeps comment ref inline" {
  let pkg = generated_docx_package(
    "<w:p><w:commentRangeStart w:id=\"3\"/><w:r><w:t>Text</w:t><w:commentReference w:id=\"3\"/></w:r><w:commentRangeEnd w:id=\"3\"/></w:p>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Paragraph(p) => {
      assert_eq(p.text, "Text[comment:3]")
      let mut has_comment_ref = false
      let mut has_structural = false
      for inline in p.inlines {
        match inline {
          @docx.DocxInline::CommentRef(_) => has_comment_ref = true
          @docx.DocxInline::StructuralMarker(_) => has_structural = true
          _ => ()
        }
      }
      assert_true(has_comment_ref)
      assert_true(has_structural)
    }
    _ => fail("expected paragraph")
  }
}

///|
test "docx classifies move range and rendered page break controls" {
  let pkg = generated_docx_package(
    "<w:p><w:moveFromRangeStart w:id=\"4\"/><w:r><w:t>A</w:t>" +
    "<w:lastRenderedPageBreak/><w:t>B</w:t></w:r><w:moveToRangeEnd w:id=\"4\"/></w:p>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Paragraph(p) => {
      assert_eq(p.text, "AB")
      let mut has_move_range = false
      let mut has_page_break = false
      for inline in p.inlines {
        match inline {
          @docx.DocxInline::StructuralMarker(marker) =>
            if marker.kind == @docx.DocxStructuralKind::MoveRangeBoundary {
              has_move_range = true
            } else if marker.kind ==
              @docx.DocxStructuralKind::LastRenderedPageBreak {
              has_page_break = true
            }
          _ => ()
        }
      }
      assert_true(has_move_range)
      assert_true(has_page_break)
    }
    _ => fail("expected paragraph")
  }
}

///|
test "docx keeps content-bearing controls and smart tags typed" {
  let pkg = generated_docx_package(
    "<w:sdt><w:sdtContent><w:p><w:r><w:t>Content control</w:t></w:r></w:p></w:sdtContent></w:sdt>" +
    "<w:p><w:r><w:t>A</w:t></w:r><w:smartTag><w:r><w:t>Smart</w:t></w:r></w:smartTag></w:p>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  assert_eq(doc.body.length(), 2)
  match doc.body[0] {
    @docx.DocxBlock::ContentControl(control) => {
      assert_eq(control.text, "Content control")
      assert_eq(control.blocks.length(), 1)
    }
    _ => fail("expected content control")
  }
  match doc.body[1] {
    @docx.DocxBlock::Paragraph(p) => {
      let mut has_smart_tag = false
      for inline in p.inlines {
        match inline {
          @docx.DocxInline::SmartTag(smart_tag) => {
            has_smart_tag = true
            assert_eq(smart_tag.child_inlines.length(), 1)
          }
          _ => ()
        }
      }
      assert_true(has_smart_tag)
    }
    _ => fail("expected paragraph")
  }
  assert_eq(doc.warnings.length(), 0)
}

///|
test "docx parses external hyperlink relationship target and display text" {
  let pkg = generated_docx_package_with_document_rels(
    "<w:p><w:hyperlink r:id=\"rIdLink\"><w:r><w:t>Example</w:t></w:r></w:hyperlink></w:p>",
    "<Relationship Id=\"rIdLink\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink\" Target=\"https://example.com/spec\" TargetMode=\"External\"/>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Paragraph(p) => {
      assert_eq(p.text, "Example")
      match p.inlines[0] {
        @docx.DocxInline::Hyperlink(link) => {
          assert_eq(link.text, "Example")
          assert_true(link.relationship_id == Some("rIdLink"))
          assert_true(link.target == Some("https://example.com/spec"))
          assert_true(link.target_mode == Some(@docx.DocxTargetMode::External))
        }
        _ => fail("expected hyperlink inline")
      }
    }
    _ => fail("expected paragraph")
  }
}

///|
test "docx parses anchor hyperlink target and display text" {
  let pkg = generated_docx_package(
    "<w:p><w:hyperlink w:anchor=\"bookmark-one\"><w:r><w:t>Jump</w:t></w:r></w:hyperlink></w:p>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Paragraph(p) =>
      match p.inlines[0] {
        @docx.DocxInline::Hyperlink(link) => {
          assert_true(link.anchor == Some("bookmark-one"))
          assert_true(link.target == Some("#bookmark-one"))
          assert_eq(link.text, "Jump")
        }
        _ => fail("expected hyperlink inline")
      }
    _ => fail("expected paragraph")
  }
}

///|
test "docx captures paragraph style numbering and run style refs" {
  let pkg = generated_docx_package(
    "<w:p><w:pPr><w:pStyle w:val=\"Heading1\"/><w:numPr><w:ilvl w:val=\"2\"/><w:numId w:val=\"9\"/></w:numPr></w:pPr>" +
    "<w:r><w:rPr><w:rStyle w:val=\"Strong\"/></w:rPr><w:t>Styled</w:t></w:r></w:p>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Paragraph(p) => {
      assert_true(p.style_id == Some("Heading1"))
      assert_true(p.alignment == None)
      match p.numbering_ref {
        Some(numbering) => {
          assert_eq(numbering.num_id, "9")
          assert_true(numbering.ilvl == Some("2"))
        }
        None => fail("expected numbering ref")
      }
      assert_true(p.runs[0].style_id == Some("Strong"))
      assert_true(!p.runs[0].bold)
      assert_eq(p.text, "Styled")
    }
    _ => fail("expected paragraph")
  }
}

///|
test "docx captures paragraph alignment and bold run hints" {
  let pkg = generated_docx_package(
    "<w:p><w:pPr><w:jc w:val=\"center\"/></w:pPr>" +
    "<w:r><w:rPr><w:b/></w:rPr><w:t>Head</w:t></w:r></w:p>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Paragraph(p) => {
      assert_true(p.alignment == Some("center"))
      assert_eq(p.runs.length(), 1)
      assert_true(p.runs[0].bold)
    }
    _ => fail("expected paragraph")
  }
}

///|
test "docx parses styles service heading style record" {
  let pkg = generated_docx_package_with_document_rels_and_entries(
    "<w:p><w:pPr><w:pStyle w:val=\"Heading1\"/></w:pPr><w:r><w:t>Title</w:t></w:r></w:p>",
    "<Relationship Id=\"rIdStyles\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>",
    [
      (
        "word/styles.xml",
        "<w:styles xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
        "<w:style w:type=\"paragraph\" w:styleId=\"Heading1\"><w:name w:val=\"heading 1\"/><w:basedOn w:val=\"Normal\"/><w:pPr><w:keepNext/></w:pPr></w:style>" +
        "</w:styles>",
      ),
    ],
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  assert_eq(doc.styles.styles.length(), 1)
  let style = doc.styles.styles[0]
  assert_eq(style.style_id, "Heading1")
  assert_true(style.style_type == Some("paragraph"))
  assert_true(style.name == Some("heading 1"))
  assert_true(style.based_on == Some("Normal"))
  assert_eq(style.paragraph_properties.length(), 1)
  assert_eq(style.paragraph_properties[0], "w:keepNext")
}

///|
test "docx resolves paragraph style ref to style record" {
  let pkg = generated_docx_package_with_document_rels_and_entries(
    "<w:p><w:pPr><w:pStyle w:val=\"Heading1\"/></w:pPr><w:r><w:t>Title</w:t></w:r></w:p>",
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
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Paragraph(p) =>
      match @docx.docx_resolve_paragraph_style(doc, p) {
        Some(style) => assert_eq(style.style_id, "Heading1")
        None => fail("expected resolved style")
      }
    _ => fail("expected paragraph")
  }
}

///|
test "docx parses numbering service bullet and decimal levels" {
  let pkg = generated_docx_package_with_document_rels_and_entries(
    "<w:p><w:r><w:t>List</w:t></w:r></w:p>",
    "<Relationship Id=\"rIdNumbering\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering\" Target=\"numbering.xml\"/>",
    [
      (
        "word/numbering.xml",
        "<w:numbering xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
        "<w:abstractNum w:abstractNumId=\"10\"><w:lvl w:ilvl=\"0\"><w:start w:val=\"1\"/><w:numFmt w:val=\"bullet\"/></w:lvl><w:lvl w:ilvl=\"1\"><w:start w:val=\"3\"/><w:numFmt w:val=\"decimal\"/></w:lvl></w:abstractNum>" +
        "<w:num w:numId=\"7\"><w:abstractNumId w:val=\"10\"/></w:num>" +
        "</w:numbering>",
      ),
    ],
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  assert_eq(doc.numbering.nums.length(), 1)
  assert_eq(doc.numbering.nums[0].num_id, "7")
  assert_true(doc.numbering.nums[0].abstract_num_id == Some("10"))
  assert_eq(doc.numbering.levels.length(), 2)
  match
    @docx.docx_resolve_numbering_level_by_id(doc.numbering, "7", Some("0")) {
    Some(level) => {
      assert_true(level.num_fmt == Some("bullet"))
      assert_true(level.start == Some("1"))
    }
    None => fail("expected bullet level")
  }
  match
    @docx.docx_resolve_numbering_level_by_id(doc.numbering, "7", Some("1")) {
    Some(level) => {
      assert_true(level.num_fmt == Some("decimal"))
      assert_true(level.start == Some("3"))
    }
    None => fail("expected decimal level")
  }
}

///|
test "docx captures numbering lvlText style link and start overrides" {
  let pkg = generated_docx_package_with_document_rels_and_entries(
    "<w:p><w:pPr><w:pStyle w:val=\"ListParagraph\"/></w:pPr><w:r><w:t>Styled item</w:t></w:r></w:p>",
    "<Relationship Id=\"rIdNumbering\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering\" Target=\"numbering.xml\"/>",
    [
      (
        "word/numbering.xml",
        "<w:numbering xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
        "<w:abstractNum w:abstractNumId=\"11\"><w:styleLink w:val=\"ListStyle\"/><w:numStyleLink w:val=\"LinkedList\"/>" +
        "<w:lvl w:ilvl=\"0\"><w:start w:val=\"4\"/><w:numFmt w:val=\"decimal\"/><w:lvlText w:val=\"%1.\"/><w:pStyle w:val=\"ListParagraph\"/></w:lvl></w:abstractNum>" +
        "<w:num w:numId=\"9\"><w:abstractNumId w:val=\"11\"/><w:lvlOverride w:ilvl=\"0\"><w:startOverride w:val=\"7\"/></w:lvlOverride></w:num>" +
        "</w:numbering>",
      ),
    ],
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  assert_eq(doc.numbering.nums.length(), 1)
  assert_eq(doc.numbering.nums[0].start_overrides.length(), 1)
  assert_eq(doc.numbering.nums[0].start_overrides[0].ilvl, "0")
  assert_true(doc.numbering.nums[0].start_overrides[0].start == Some("7"))
  match
    @docx.docx_resolve_numbering_level_by_id(doc.numbering, "9", Some("0")) {
    Some(level) => {
      assert_true(level.lvl_text == Some("%1."))
      assert_true(level.paragraph_style_id == Some("ListParagraph"))
      assert_true(level.style_link == Some("ListStyle"))
      assert_true(level.num_style_link == Some("LinkedList"))
    }
    None => fail("expected resolved numbering level")
  }
}

///|
test "docx resolves paragraph numbering ref to numbering level" {
  let pkg = generated_docx_package_with_document_rels_and_entries(
    "<w:p><w:pPr><w:numPr><w:ilvl w:val=\"1\"/><w:numId w:val=\"7\"/></w:numPr></w:pPr><w:r><w:t>Item</w:t></w:r></w:p>",
    "<Relationship Id=\"rIdNumbering\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering\" Target=\"numbering.xml\"/>",
    [
      (
        "word/numbering.xml",
        "<w:numbering xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
        "<w:abstractNum w:abstractNumId=\"10\"><w:lvl w:ilvl=\"1\"><w:numFmt w:val=\"decimal\"/></w:lvl></w:abstractNum>" +
        "<w:num w:numId=\"7\"><w:abstractNumId w:val=\"10\"/></w:num>" +
        "</w:numbering>",
      ),
    ],
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Paragraph(p) =>
      match @docx.docx_resolve_paragraph_numbering_level(doc, p) {
        Some(level) => {
          assert_eq(level.abstract_num_id, "10")
          assert_eq(level.ilvl, "1")
          assert_true(level.num_fmt == Some("decimal"))
        }
        None => fail("expected resolved numbering level")
      }
    _ => fail("expected paragraph")
  }
}

///|
test "docx missing styles and numbering service behavior is stable" {
  let plain_pkg = generated_docx_package(
    "<w:p><w:r><w:t>Plain</w:t></w:r></w:p>",
  )
  let plain = @docx.parse_docx_document_from_package(plain_pkg)
  let mut plain_has_missing_numbering = false
  for warning in plain.warnings {
    if warning.kind == @docx.DocxWarningKind::MissingNumberingPart {
      plain_has_missing_numbering = true
    }
  }
  assert_true(!plain_has_missing_numbering)

  let referenced_pkg = generated_docx_package(
    "<w:p><w:pPr><w:pStyle w:val=\"MissingStyle\"/><w:numPr><w:ilvl w:val=\"0\"/><w:numId w:val=\"9\"/></w:numPr></w:pPr><w:r><w:t>Referenced</w:t></w:r></w:p>",
  )
  let referenced = @docx.parse_docx_document_from_package(referenced_pkg)
  assert_eq(referenced.styles.styles.length(), 0)
  assert_eq(referenced.numbering.levels.length(), 0)
  let mut has_missing_styles = false
  let mut has_missing_numbering = false
  for warning in referenced.warnings {
    if warning.kind == @docx.DocxWarningKind::MissingStylesPart {
      has_missing_styles = true
    }
    if warning.kind == @docx.DocxWarningKind::MissingNumberingPart {
      has_missing_numbering = true
    }
  }
  assert_true(has_missing_styles)
  assert_true(has_missing_numbering)
}

///|
test "docx preserves field bookmark and unknown run children as typed warnings" {
  let pkg = generated_docx_package(
    "<w:p><w:r><w:t>A</w:t><w:fldChar w:fldCharType=\"begin\"/><w:instrText> PAGE </w:instrText>" +
    "<w:bookmarkStart w:id=\"1\" w:name=\"mark\"/><w:nope/></w:r>" +
    "<w:fldSimple w:instr=\"DATE\"><w:r><w:t>ignored</w:t></w:r></w:fldSimple></w:p>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Paragraph(p) => {
      let mut has_field = false
      let mut has_bookmark = false
      let mut has_unknown = false
      for inline in p.inlines {
        match inline {
          @docx.DocxInline::FieldUnsupported(_) => has_field = true
          @docx.DocxInline::Bookmark(_) => has_bookmark = true
          @docx.DocxInline::UnsupportedInline(_) => has_unknown = true
          _ => ()
        }
      }
      assert_true(has_field)
      assert_true(has_bookmark)
      assert_true(has_unknown)
      assert_true(doc.warnings.length() >= 3)
    }
    _ => fail("expected paragraph")
  }
}

///|
test "docx parses footnotes part note id and body paragraph" {
  let pkg = generated_docx_package_with_document_rels_and_entries(
    "<w:p><w:r><w:t>Main</w:t></w:r></w:p>",
    "<Relationship Id=\"rIdFoot\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes\" Target=\"footnotes.xml\"/>",
    [
      (
        "word/footnotes.xml", "<w:footnotes xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:footnote w:id=\"1\"><w:p><w:r><w:t>Footnote body</w:t></w:r></w:p></w:footnote></w:footnotes>",
      ),
    ],
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  assert_docx_discovered_part(
    doc.part_graph,
    @docx.DocxDiscoveredPartKind::Footnotes,
    @docx.DocxPartDiscoverySource::Relationship,
    "word/footnotes.xml",
  )
  assert_eq(doc.footnotes.length(), 1)
  assert_eq(doc.footnotes[0].note_id, "1")
  match doc.footnotes[0].blocks[0] {
    @docx.DocxBlock::Paragraph(p) => assert_eq(p.text, "Footnote body")
    _ => fail("expected footnote paragraph")
  }
}

///|
test "docx parses endnotes part note id and body paragraph" {
  let pkg = generated_docx_package_with_document_rels_and_entries(
    "<w:p><w:r><w:t>Main</w:t></w:r></w:p>",
    "<Relationship Id=\"rIdEnd\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/endnotes\" Target=\"endnotes.xml\"/>",
    [
      (
        "word/endnotes.xml", "<w:endnotes xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:endnote w:id=\"2\"><w:p><w:r><w:t>Endnote body</w:t></w:r></w:p></w:endnote></w:endnotes>",
      ),
    ],
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  assert_docx_discovered_part(
    doc.part_graph,
    @docx.DocxDiscoveredPartKind::Endnotes,
    @docx.DocxPartDiscoverySource::Relationship,
    "word/endnotes.xml",
  )
  assert_eq(doc.endnotes.length(), 1)
  assert_eq(doc.endnotes[0].note_id, "2")
  match doc.endnotes[0].blocks[0] {
    @docx.DocxBlock::Paragraph(p) => assert_eq(p.text, "Endnote body")
    _ => fail("expected endnote paragraph")
  }
}

///|
test "docx parses comments part id author and body paragraph" {
  let pkg = generated_docx_package_with_document_rels_and_entries(
    "<w:p><w:r><w:t>Main</w:t></w:r></w:p>",
    "<Relationship Id=\"rIdComments\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments\" Target=\"comments.xml\"/>",
    [
      (
        "word/comments.xml", "<w:comments xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:comment w:id=\"3\" w:author=\"Alice\" w:date=\"2026-06-05T00:00:00Z\"><w:p><w:r><w:t>Comment body</w:t></w:r></w:p></w:comment></w:comments>",
      ),
    ],
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  assert_docx_discovered_part(
    doc.part_graph,
    @docx.DocxDiscoveredPartKind::Comments,
    @docx.DocxPartDiscoverySource::Relationship,
    "word/comments.xml",
  )
  assert_eq(doc.comments.length(), 1)
  assert_eq(doc.comments[0].comment_id, "3")
  assert_true(doc.comments[0].author == Some("Alice"))
  match doc.comments[0].blocks[0] {
    @docx.DocxBlock::Paragraph(p) => assert_eq(p.text, "Comment body")
    _ => fail("expected comment paragraph")
  }
}

///|
test "docx lookup helpers resolve note and comment containers by id" {
  let pkg = generated_docx_package_with_document_rels_and_entries(
    "<w:p><w:r><w:t>Main</w:t><w:footnoteReference w:id=\"1\"/><w:endnoteReference w:id=\"2\"/><w:commentReference w:id=\"3\"/></w:r></w:p>",
    "<Relationship Id=\"rIdFoot\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes\" Target=\"footnotes.xml\"/>" +
    "<Relationship Id=\"rIdEnd\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/endnotes\" Target=\"endnotes.xml\"/>" +
    "<Relationship Id=\"rIdComments\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments\" Target=\"comments.xml\"/>",
    [
      (
        "word/footnotes.xml", "<w:footnotes xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:footnote w:id=\"1\"><w:p><w:r><w:t>Footnote body</w:t></w:r></w:p></w:footnote></w:footnotes>",
      ),
      (
        "word/endnotes.xml", "<w:endnotes xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:endnote w:id=\"2\"><w:p><w:r><w:t>Endnote body</w:t></w:r></w:p></w:endnote></w:endnotes>",
      ),
      (
        "word/comments.xml", "<w:comments xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:comment w:id=\"3\"><w:p><w:r><w:t>Comment body</w:t></w:r></w:p></w:comment></w:comments>",
      ),
    ],
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match @docx.docx_find_footnote(doc, "1") {
    Some(note) => assert_eq(note.note_id, "1")
    None => fail("expected footnote")
  }
  match @docx.docx_find_endnote(doc, "2") {
    Some(note) => assert_eq(note.note_id, "2")
    None => fail("expected endnote")
  }
  match @docx.docx_find_comment(doc, "3") {
    Some(comment) => assert_eq(comment.comment_id, "3")
    None => fail("expected comment")
  }
  assert_true(@docx.docx_find_footnote(doc, "99") is None)
  assert_true(@docx.docx_find_endnote(doc, "99") is None)
  assert_true(@docx.docx_find_comment(doc, "99") is None)
}

///|
test "docx parses conventional note and comment parts without rels" {
  let pkg = generated_docx_package_with_document_rels_and_entries(
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
  let doc = @docx.parse_docx_document_from_package(pkg)
  assert_docx_discovered_part(
    doc.part_graph,
    @docx.DocxDiscoveredPartKind::Footnotes,
    @docx.DocxPartDiscoverySource::ConventionalPath,
    "word/footnotes.xml",
  )
  assert_docx_discovered_part(
    doc.part_graph,
    @docx.DocxDiscoveredPartKind::Endnotes,
    @docx.DocxPartDiscoverySource::ConventionalPath,
    "word/endnotes.xml",
  )
  assert_docx_discovered_part(
    doc.part_graph,
    @docx.DocxDiscoveredPartKind::Comments,
    @docx.DocxPartDiscoverySource::ConventionalPath,
    "word/comments.xml",
  )
  assert_eq(doc.footnotes.length(), 1)
  assert_eq(doc.endnotes.length(), 1)
  assert_eq(doc.comments.length(), 1)
  match @docx.docx_find_footnote(doc, "1") {
    Some(note) =>
      match note.blocks[0] {
        @docx.DocxBlock::Paragraph(p) =>
          assert_eq(p.text, "Conventional footnote")
        _ => fail("expected footnote paragraph")
      }
    None => fail("expected conventional footnote")
  }
  match @docx.docx_find_comment(doc, "3") {
    Some(comment) => assert_true(comment.author == Some("Alice"))
    None => fail("expected conventional comment")
  }
}

///|
test "docx missing conventional note and comment parts are not discovered" {
  let pkg = generated_docx_package_with_document_rels_and_entries(
    "<w:p><w:r><w:t>Main</w:t><w:footnoteReference w:id=\"1\"/><w:endnoteReference w:id=\"2\"/><w:commentReference w:id=\"3\"/></w:r></w:p>",
    "",
    [],
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  assert_eq(doc.footnotes.length(), 0)
  assert_eq(doc.endnotes.length(), 0)
  assert_eq(doc.comments.length(), 0)
  assert_eq(
    count_docx_discovered_parts(
      doc.part_graph,
      @docx.DocxDiscoveredPartKind::Footnotes,
      @docx.DocxPartDiscoverySource::ConventionalPath,
    ),
    0,
  )
  assert_eq(
    count_docx_discovered_parts(
      doc.part_graph,
      @docx.DocxDiscoveredPartKind::Comments,
      @docx.DocxPartDiscoverySource::ConventionalPath,
    ),
    0,
  )
}

///|
test "docx parses header and footer body paragraphs" {
  let pkg = generated_docx_package_with_document_rels_and_entries(
    "<w:p><w:r><w:t>Main</w:t></w:r></w:p>",
    "<Relationship Id=\"rIdHeader\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/header\" Target=\"header1.xml\"/>" +
    "<Relationship Id=\"rIdFooter\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer\" Target=\"footer1.xml\"/>",
    [
      (
        "word/header1.xml", "<w:hdr xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:p><w:r><w:t>Header body</w:t></w:r></w:p></w:hdr>",
      ),
      (
        "word/footer1.xml", "<w:ftr xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:p><w:r><w:t>Footer body</w:t></w:r></w:p></w:ftr>",
      ),
    ],
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  assert_eq(doc.headers.length(), 1)
  assert_eq(doc.footers.length(), 1)
  match doc.headers[0].blocks[0] {
    @docx.DocxBlock::Paragraph(p) => assert_eq(p.text, "Header body")
    _ => fail("expected header paragraph")
  }
  match doc.footers[0].blocks[0] {
    @docx.DocxBlock::Paragraph(p) => assert_eq(p.text, "Footer body")
    _ => fail("expected footer paragraph")
  }
}

///|
test "docx preserves main body note and comment reference ids" {
  let pkg = generated_docx_package(
    "<w:p><w:r><w:t>Refs</w:t><w:footnoteReference w:id=\"1\"/><w:endnoteReference w:id=\"2\"/><w:commentReference w:id=\"3\"/></w:r></w:p>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Paragraph(p) => {
      assert_eq(p.text, "Refs[footnote:1][endnote:2][comment:3]")
      assert_true(p.inlines[1] is @docx.DocxInline::FootnoteRef(_))
      assert_true(p.inlines[2] is @docx.DocxInline::EndnoteRef(_))
      assert_true(p.inlines[3] is @docx.DocxInline::CommentRef(_))
    }
    _ => fail("expected paragraph")
  }
}

///|
test "docx missing secondary part creates warning without crash" {
  let pkg = generated_docx_package_with_document_rels_and_entries(
    "<w:p><w:r><w:t>Main</w:t></w:r></w:p>",
    "<Relationship Id=\"rIdMissingHeader\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/header\" Target=\"missing-header.xml\"/>",
    [],
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  let mut has_missing = false
  for warning in doc.warnings {
    if warning.kind == @docx.DocxWarningKind::MissingContainerPart {
      has_missing = true
    }
  }
  assert_true(has_missing)
}

///|
test "docx parses textbox content as secondary part body" {
  let pkg = generated_docx_package(
    "<w:p><w:r><w:t>Main</w:t></w:r></w:p>" +
    "<w:p><w:r><w:txbxContent><w:p><w:r><w:t>Textbox body</w:t></w:r></w:p></w:txbxContent></w:r></w:p>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  assert_eq(doc.textboxes.length(), 1)
  assert_true(doc.textboxes[0].anchor_id == "word/document.xml#textbox:0")
  assert_true(doc.textboxes[0].owner_part == "word/document.xml")
  assert_true(doc.textboxes[0].part_name == "word/document.xml#textbox:0")
  match doc.body[1] {
    @docx.DocxBlock::Paragraph(p) => {
      assert_eq(p.text, "")
      match p.inlines[0] {
        @docx.DocxInline::TextBoxRef(textbox_ref) =>
          assert_true(
            textbox_ref.anchor_id == Some("word/document.xml#textbox:0"),
          )
        _ => fail("expected textbox ref inline")
      }
    }
    _ => fail("expected paragraph")
  }
  match doc.textboxes[0].blocks[0] {
    @docx.DocxBlock::Paragraph(p) => assert_eq(p.text, "Textbox body")
    _ => fail("expected textbox paragraph")
  }
}

///|
test "docx parses drawing media relationship target and image metadata" {
  let pkg = generated_docx_package_with_document_rels_and_entries(
    "<w:p><w:r>" +
    generated_docx_drawing_xml("rIdImage", "Diagram alt", "Diagram title") +
    "</w:r></w:p>",
    "<Relationship Id=\"rIdImage\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/image1.png\"/>",
    [("word/media/image1.png", "png-bytes")],
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Paragraph(p) => {
      assert_eq(p.text, "[image: Diagram alt]")
      match p.inlines[0] {
        @docx.DocxInline::Drawing(drawing) => {
          assert_true(drawing.owner_part == "word/document.xml")
          assert_true(drawing.doc_pr_id == Some("1"))
          assert_true(drawing.doc_pr_name == Some("Picture 1"))
          assert_true(drawing.descr == Some("Diagram alt"))
          assert_true(drawing.title == Some("Diagram title"))
          let media = drawing.media.unwrap()
          assert_true(media.relationship_id == Some("rIdImage"))
          assert_true(
            media.relationship_kind == @docx.DocxMediaRelationshipKind::Embed,
          )
          assert_true(
            media.container_kind == @docx.DocxMediaContainerKind::Drawing,
          )
          assert_true(media.target == Some("media/image1.png"))
          assert_true(media.resolved_target == Some("word/media/image1.png"))
          assert_true(media.target_part == Some("word/media/image1.png"))
          assert_true(media.target_exists == Some(true))
          assert_true(media.content_type == Some("image/png"))
          assert_true(media.alt_text == Some("Diagram alt"))
          assert_true(media.title == Some("Diagram title"))
        }
        _ => fail("expected drawing inline")
      }
    }
    _ => fail("expected paragraph")
  }
}

///|
test "docx parses linked drawing media as external relationship" {
  let pkg = generated_docx_package_with_document_rels(
    "<w:p><w:r><w:drawing><a:blip xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" r:link=\"rIdLinked\"/></w:drawing></w:r></w:p>",
    "<Relationship Id=\"rIdLinked\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"https://example.com/image.png\" TargetMode=\"External\"/>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Paragraph(p) =>
      match p.inlines[0] {
        @docx.DocxInline::Drawing(drawing) => {
          let media = drawing.media.unwrap()
          assert_true(
            media.relationship_kind == @docx.DocxMediaRelationshipKind::Link,
          )
          assert_true(media.target_mode == Some(@docx.DocxTargetMode::External))
          assert_true(
            media.resolved_target == Some("https://example.com/image.png"),
          )
          assert_true(media.target_part is None)
        }
        _ => fail("expected drawing inline")
      }
    _ => fail("expected paragraph")
  }
}

///|
test "docx parses vml pict media relationship and alt title" {
  let pkg = generated_docx_package_with_document_rels_and_entries(
    "<w:p><w:r><w:pict><v:shape xmlns:v=\"urn:schemas-microsoft-com:vml\" xmlns:o=\"urn:schemas-microsoft-com:office:office\" alt=\"VML alt\"><v:imagedata r:id=\"rIdVml\" o:title=\"VML title\"/></v:shape></w:pict></w:r></w:p>",
    "<Relationship Id=\"rIdVml\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/vml.jpg\"/>",
    [("word/media/vml.jpg", "jpg-bytes")],
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Paragraph(p) =>
      match p.inlines[0] {
        @docx.DocxInline::Shape(shape) => {
          assert_true(shape.owner_part == "word/document.xml")
          assert_true(shape.alt_text == Some("VML alt"))
          assert_true(shape.title == Some("VML title"))
          let media = shape.media.unwrap()
          assert_true(
            media.container_kind == @docx.DocxMediaContainerKind::Pict,
          )
          assert_true(
            media.relationship_kind == @docx.DocxMediaRelationshipKind::Embed,
          )
          assert_true(media.alt_text == Some("VML alt"))
          assert_true(media.title == Some("VML title"))
          assert_true(media.content_type == Some("image/jpeg"))
        }
        _ => fail("expected shape inline")
      }
    _ => fail("expected paragraph")
  }
}

///|
test "docx parses vml textbox shape as textbox anchor not image" {
  let pkg = generated_docx_package(
    "<w:p><w:r><w:pict><v:shape xmlns:v=\"urn:schemas-microsoft-com:vml\" id=\"shape1\" style=\"width:1in\" alt=\"Text shape\">" +
    "<w:txbxContent><w:p><w:r><w:t>VML textbox body</w:t></w:r></w:p></w:txbxContent>" +
    "</v:shape></w:pict></w:r></w:p>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  assert_eq(doc.textboxes.length(), 1)
  assert_true(doc.textboxes[0].shape_id == Some("shape1"))
  assert_true(doc.textboxes[0].title == Some("Text shape"))
  match doc.body[0] {
    @docx.DocxBlock::Paragraph(p) => {
      assert_eq(p.text, "")
      match p.inlines[0] {
        @docx.DocxInline::Shape(shape) => {
          assert_true(shape.media is None)
          assert_true(shape.text_box_ref is Some(_))
          assert_true(shape.shape_id == Some("shape1"))
        }
        _ => fail("expected shape inline")
      }
    }
    _ => fail("expected paragraph")
  }
}

///|
test "docx missing media relationship is explicit warning" {
  let pkg = generated_docx_package(
    "<w:p><w:r>" +
    generated_docx_drawing_xml("rIdMissing", "Missing alt", "") +
    "</w:r></w:p>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Paragraph(p) =>
      match p.inlines[0] {
        @docx.DocxInline::Drawing(drawing) => {
          let media = drawing.media.unwrap()
          assert_true(media.relationship_id == Some("rIdMissing"))
          assert_true(media.target is None)
        }
        _ => fail("expected drawing inline")
      }
    _ => fail("expected paragraph")
  }
  let mut has_missing = false
  for warning in doc.warnings {
    if warning.kind == @docx.DocxWarningKind::MissingMediaTarget {
      has_missing = true
    }
  }
  assert_true(has_missing)
}

///|
test "docx parses field instrText and fldSimple source facts" {
  let pkg = generated_docx_package(
    "<w:p><w:r><w:instrText> PAGE </w:instrText></w:r>" +
    "<w:fldSimple w:instr=\"DATE\"><w:r><w:t>June 5</w:t></w:r></w:fldSimple></w:p>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Paragraph(p) => {
      match p.inlines[0] {
        @docx.DocxInline::FieldUnsupported(field) => {
          assert_eq(field.kind, "instrText")
          assert_true(field.instruction == Some(" PAGE "))
          assert_true(field.result_text is None)
        }
        _ => fail("expected instrText field")
      }
      match p.inlines[1] {
        @docx.DocxInline::FieldUnsupported(field) => {
          assert_eq(field.kind, "fldSimple")
          assert_true(field.instruction == Some("DATE"))
          assert_true(field.result_text == Some("June 5"))
        }
        _ => fail("expected fldSimple field")
      }
    }
    _ => fail("expected paragraph")
  }
}

///|
test "docx field preserves child inline structure" {
  let pkg = generated_docx_package(
    "<w:p><w:fldSimple w:instr=\"REF mark\"><w:r><w:t>Field result</w:t></w:r></w:fldSimple></w:p>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Paragraph(p) =>
      match p.inlines[0] {
        @docx.DocxInline::FieldUnsupported(field) => {
          assert_true(field.instruction == Some("REF mark"))
          assert_true(field.result_text == Some("Field result"))
          assert_eq(field.child_inlines.length(), 1)
          assert_true(field.child_inlines[0] is @docx.DocxInline::Text(_))
        }
        _ => fail("expected field")
      }
    _ => fail("expected paragraph")
  }
}

///|
test "docx parses OMML math source fact without conversion" {
  let pkg = generated_docx_package(
    "<w:p><m:oMath xmlns:m=\"http://schemas.openxmlformats.org/officeDocument/2006/math\"><m:r><m:t>x+1</m:t></m:r></m:oMath></w:p>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Paragraph(p) =>
      match p.inlines[0] {
        @docx.DocxInline::Math(math) => {
          assert_eq(math.kind, "m:oMath")
          assert_true(math.text_signature == Some("x+1"))
        }
        _ => fail("expected math inline")
      }
    _ => fail("expected paragraph")
  }
  let mut has_math_warning = false
  for warning in doc.warnings {
    if warning.kind == @docx.DocxWarningKind::UnsupportedMath {
      has_math_warning = true
    }
  }
  assert_true(has_math_warning)
}

///|
test "docx parses bookmark start and end source facts" {
  let pkg = generated_docx_package(
    "<w:p><w:bookmarkStart w:id=\"7\" w:name=\"mark\"/>" +
    "<w:r><w:t>A</w:t></w:r><w:bookmarkEnd w:id=\"7\"/></w:p>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Paragraph(p) => {
      match p.inlines[0] {
        @docx.DocxInline::Bookmark(bookmark) => {
          assert_true(bookmark.kind == @docx.DocxBookmarkKind::Start)
          assert_true(bookmark.bookmark_id == Some("7"))
          assert_true(bookmark.name == Some("mark"))
        }
        _ => fail("expected bookmark start")
      }
      match p.inlines[2] {
        @docx.DocxInline::Bookmark(bookmark) => {
          assert_true(bookmark.kind == @docx.DocxBookmarkKind::End)
          assert_true(bookmark.bookmark_id == Some("7"))
        }
        _ => fail("expected bookmark end")
      }
    }
    _ => fail("expected paragraph")
  }
}

///|
test "docx parses symbol soft hyphen and no break hyphen source facts" {
  let pkg = generated_docx_package(
    "<w:p><w:r><w:t>A</w:t><w:sym w:font=\"Wingdings\" w:char=\"002A\"/>" +
    "<w:softHyphen/><w:t>B</w:t><w:noBreakHyphen/><w:t>C</w:t></w:r></w:p>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Paragraph(p) => {
      assert_eq(p.text, "A*B-C")
      match p.inlines[1] {
        @docx.DocxInline::Symbol(symbol) => {
          assert_true(symbol.font == Some("Wingdings"))
          assert_true(symbol.char_hex == Some("002A"))
        }
        _ => fail("expected symbol")
      }
      assert_true(p.inlines[2] is @docx.DocxInline::Hyphen(_))
      assert_true(p.inlines[4] is @docx.DocxInline::Hyphen(_))
    }
    _ => fail("expected paragraph")
  }
}

///|
test "docx parses typed break source facts" {
  let pkg = generated_docx_package(
    "<w:p><w:r><w:br w:type=\"page\"/><w:br w:type=\"column\"/><w:br w:type=\"textWrapping\"/><w:cr/></w:r></w:p>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Paragraph(p) => {
      match p.inlines[0] {
        @docx.DocxInline::Break(value) =>
          assert_true(value.kind == @docx.DocxBreakKind::Page)
        _ => fail("expected page break")
      }
      match p.inlines[1] {
        @docx.DocxInline::Break(value) =>
          assert_true(value.kind == @docx.DocxBreakKind::Column)
        _ => fail("expected column break")
      }
      match p.inlines[2] {
        @docx.DocxInline::Break(value) =>
          assert_true(value.kind == @docx.DocxBreakKind::TextWrapping)
        _ => fail("expected text wrapping break")
      }
      match p.inlines[3] {
        @docx.DocxInline::Break(value) =>
          assert_true(value.kind == @docx.DocxBreakKind::CarriageReturn)
        _ => fail("expected carriage return")
      }
    }
    _ => fail("expected paragraph")
  }
}

///|
test "docx parses tracked change source facts" {
  let pkg = generated_docx_package(
    "<w:p><w:ins><w:r><w:t>Inserted</w:t></w:r></w:ins>" +
    "<w:del><w:r><w:delText>Deleted</w:delText></w:r></w:del>" +
    "<w:moveFrom><w:r><w:t>Moved from</w:t></w:r></w:moveFrom>" +
    "<w:moveTo><w:r><w:t>Moved to</w:t></w:r></w:moveTo></w:p>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Paragraph(p) => {
      match p.inlines[0] {
        @docx.DocxInline::TrackedChange(change) => {
          assert_eq(change.kind, "w:ins")
          assert_eq(change.text, "Inserted")
          assert_eq(change.child_inlines.length(), 1)
        }
        _ => fail("expected insert tracked change")
      }
      match p.inlines[1] {
        @docx.DocxInline::TrackedChange(change) => {
          assert_eq(change.kind, "w:del")
          assert_eq(change.text, "Deleted")
        }
        _ => fail("expected delete tracked change")
      }
      match p.inlines[3] {
        @docx.DocxInline::TrackedChange(change) => {
          assert_eq(change.kind, "w:moveTo")
          assert_eq(change.text, "Moved to")
        }
        _ => fail("expected moveTo tracked change")
      }
    }
    _ => fail("expected paragraph")
  }
}

///|
test "docx unknown run child preserves unsupported inline fact and warning" {
  let pkg = generated_docx_package(
    "<w:p><w:r><w:t>A</w:t><w:nope/></w:r></w:p>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  match doc.body[0] {
    @docx.DocxBlock::Paragraph(p) =>
      match p.inlines[1] {
        @docx.DocxInline::UnsupportedInline(inline) => {
          assert_eq(inline.tag, "w:nope")
          assert_eq(inline.reason, "unsupported run child")
        }
        _ => fail("expected unsupported inline")
      }
    _ => fail("expected paragraph")
  }
  let mut has_unknown_warning = false
  for warning in doc.warnings {
    if warning.kind == @docx.DocxWarningKind::UnsupportedInline {
      has_unknown_warning = true
    }
  }
  assert_true(has_unknown_warning)
}
