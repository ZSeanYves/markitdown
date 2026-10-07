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
  "<Default Extension=\"svg\" ContentType=\"image/svg+xml\"/>" +
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
test "docx parses two body paragraphs from generated package" {
  let pkg = generated_docx_package(
    "<w:p><w:r><w:t>First</w:t></w:r></w:p>" +
    "<w:p><w:r><w:t>Second</w:t></w:r></w:p>",
  )
  let doc = @docx.parse_docx_document_from_package(pkg)
  assert_eq(doc.main_part, "word/document.xml")
  assert_eq(doc.body.length(), 2)
  match doc.body[0] {
    Paragraph(p) => assert_eq(p.text, "First")
    _ => fail("expected first paragraph")
  }
  match doc.body[1] {
    Paragraph(p) => {
      assert_eq(p.text, "Second")
      assert_eq(p.source_key.block_index, 1)
    }
    _ => fail("expected second paragraph")
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
    Paragraph(p) => {
      assert_eq(p.text, "[image: Diagram alt]")
      match p.inlines[0] {
        Drawing(drawing) => {
          assert_true(drawing.owner_part == "word/document.xml")
          assert_true(drawing.descr == Some("Diagram alt"))
          assert_true(drawing.title == Some("Diagram title"))
          let media = drawing.media.unwrap()
          assert_true(media.relationship_id == Some("rIdImage"))
          assert_true(media.target == Some("media/image1.png"))
          assert_true(media.resolved_target == Some("word/media/image1.png"))
          assert_true(media.target_exists == Some(true))
          assert_true(media.content_type == Some("image/png"))
        }
        _ => fail("expected drawing inline")
      }
    }
    _ => fail("expected paragraph")
  }
}
