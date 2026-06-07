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
fn crc32_of_string(s : String) -> Int {
  let mut crc : UInt = 0xFFFFFFFF
  for ch in s.to_array() {
    crc = crc32_update_uint(crc, ch.to_int().reinterpret_as_uint())
  }
  UInt::lxor(crc, 0xFFFFFFFF).reinterpret_as_int()
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
  let central_offset = out.length()
  for item in central {
    let (name, size, local_offset, crc32) = item
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
  let central_size = out.length() - central_offset
  append_u32_le(out, 0x06054b50)
  append_u16_le(out, 0)
  append_u16_le(out, 0)
  append_u16_le(out, central.length())
  append_u16_le(out, central.length())
  append_u32_le(out, central_size)
  append_u32_le(out, central_offset)
  append_u16_le(out, 0)
  Bytes::from_array(out)
}

///|
fn rels(inner : String) -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">" +
  inner +
  "</Relationships>"
}

///|
fn content_types(extra : String) -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">" +
  "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>" +
  "<Default Extension=\"xml\" ContentType=\"application/xml\"/>" +
  "<Default Extension=\"png\" ContentType=\"image/png\"/>" +
  "<Override PartName=\"/ppt/presentation.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\"/>" +
  "<Override PartName=\"/ppt/slides/slide1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>" +
  "<Override PartName=\"/ppt/slides/slide2.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>" +
  extra +
  "</Types>"
}

///|
fn slide_xml(title : String, body : String, rel_id : String) -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<p:sld xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" " +
  "xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" " +
  "xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
  "<p:cSld><p:spTree>" +
  "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
  "<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>" +
  "<p:sp><p:nvSpPr><p:cNvPr id=\"2\" name=\"Title\"/><p:cNvSpPr/><p:nvPr><p:ph type=\"title\"/></p:nvPr></p:nvSpPr>" +
  "<p:spPr><a:xfrm rot=\"0\"><a:off x=\"0\" y=\"0\"/><a:ext cx=\"5000000\" cy=\"500000\"/></a:xfrm></p:spPr>" +
  "<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>" +
  title +
  "</a:t></a:r></a:p></p:txBody></p:sp>" +
  "<p:sp><p:nvSpPr><p:cNvPr id=\"3\" name=\"Body\"/><p:cNvSpPr/><p:nvPr><p:ph type=\"body\" idx=\"1\"/></p:nvPr></p:nvSpPr>" +
  "<p:spPr><a:xfrm><a:off x=\"0\" y=\"1000000\"/><a:ext cx=\"5000000\" cy=\"3000000\"/></a:xfrm></p:spPr>" +
  "<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:pPr lvl=\"1\"><a:buChar char=\"*\"/></a:pPr><a:r><a:t>" +
  body +
  "</a:t></a:r><a:br/><a:r><a:rPr><a:hlinkClick r:id=\"rIdLink\"/></a:rPr><a:t>Link</a:t></a:r></a:p></p:txBody></p:sp>" +
  "<p:pic><p:nvPicPr><p:cNvPr id=\"4\" name=\"Picture\" descr=\"Alt\" title=\"Title\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr><p:blipFill><a:blip r:embed=\"" +
  rel_id +
  "\"/></p:blipFill><p:spPr><a:xfrm><a:off x=\"100\" y=\"200\"/><a:ext cx=\"300\" cy=\"400\"/></a:xfrm></p:spPr></p:pic>" +
  "<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id=\"5\" name=\"Table\"/></p:nvGraphicFramePr><a:graphic><a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/table\"><a:tbl><a:tr><a:tc><a:txBody><a:p><a:r><a:t>H</a:t></a:r></a:p></a:txBody></a:tc></a:tr><a:tr><a:tc gridSpan=\"2\"><a:txBody><a:p><a:r><a:t>V</a:t></a:r></a:p></a:txBody></a:tc></a:tr></a:tbl></a:graphicData></a:graphic></p:graphicFrame>" +
  "<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id=\"6\" name=\"Unknown\"/></p:nvGraphicFramePr><a:graphic><a:graphicData uri=\"unknown\"/></a:graphic></p:graphicFrame>" +
  "</p:spTree></p:cSld></p:sld>"
}

///|
fn notes_xml() -> String {
  "<p:notes xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\"><p:cSld><p:spTree><p:sp><p:nvSpPr><p:cNvPr id=\"8\" name=\"Notes\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:txBody><a:p><a:r><a:t>Speaker note</a:t></a:r></a:p></p:txBody></p:sp></p:spTree></p:cSld></p:notes>"
}

///|
fn comments_xml() -> String {
  "<p:cmLst xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\"><p:cm authorId=\"0\" idx=\"1\"><p:text>Comment text</p:text></p:cm><p:cm authorId=\"missing\" idx=\"2\"><p:text>Missing author</p:text></p:cm></p:cmLst>"
}

///|
fn sample_pkg() -> @ox.OoxmlPackage raise {
  let pptx = build_store_zip([
    (
      "[Content_Types].xml",
      content_types(
        "<Override PartName=\"/ppt/slideLayouts/slideLayout1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml\"/>" +
        "<Override PartName=\"/ppt/slideMasters/slideMaster1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml\"/>" +
        "<Override PartName=\"/ppt/notesSlides/notesSlide1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.notesSlide+xml\"/>" +
        "<Override PartName=\"/ppt/comments/comment1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.comments+xml\"/>" +
        "<Override PartName=\"/docProps/core.xml\" ContentType=\"application/vnd.openxmlformats-package.core-properties+xml\"/>" +
        "<Override PartName=\"/docProps/app.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.extended-properties+xml\"/>" +
        "<Override PartName=\"/docProps/custom.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.custom-properties+xml\"/>",
      ),
    ),
    (
      "_rels/.rels",
      rels(
        "<Relationship Id=\"rIdMain\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"ppt/presentation.xml\"/>",
      ),
    ),
    (
      "ppt/presentation.xml", "<p:presentation xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><p:sldIdLst><p:sldId id=\"257\" r:id=\"rId2\" show=\"0\"/><p:sldId id=\"256\" r:id=\"rId1\"/></p:sldIdLst></p:presentation>",
    ),
    (
      "ppt/_rels/presentation.xml.rels",
      rels(
        "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide1.xml\"/>" +
        "<Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide2.xml\"/>",
      ),
    ),
    ("ppt/slides/slide1.xml", slide_xml("One", "Body", "rIdImg")),
    ("ppt/slides/slide2.xml", slide_xml("Two", "Hidden", "rIdExt")),
    (
      "ppt/slides/_rels/slide1.xml.rels",
      rels(
        "<Relationship Id=\"rIdLayout\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout\" Target=\"../slideLayouts/slideLayout1.xml\"/>" +
        "<Relationship Id=\"rIdImg\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"../media/image1.png\"/>" +
        "<Relationship Id=\"rIdLink\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink\" Target=\"https://example.com\" TargetMode=\"External\"/>" +
        "<Relationship Id=\"rIdNotes\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesSlide\" Target=\"../notesSlides/notesSlide1.xml\"/>" +
        "<Relationship Id=\"rIdComments\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments\" Target=\"../comments/comment1.xml\"/>",
      ),
    ),
    (
      "ppt/slides/_rels/slide2.xml.rels",
      rels(
        "<Relationship Id=\"rIdExt\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"https://example.com/image.png\" TargetMode=\"External\"/>",
      ),
    ),
    (
      "ppt/slideLayouts/slideLayout1.xml",
      slide_xml("Layout Title", "Layout Body", "rIdMissing"),
    ),
    (
      "ppt/slideLayouts/_rels/slideLayout1.xml.rels",
      rels(
        "<Relationship Id=\"rIdMaster\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster\" Target=\"../slideMasters/slideMaster1.xml\"/>",
      ),
    ),
    (
      "ppt/slideMasters/slideMaster1.xml",
      slide_xml("Master Title", "Master Body", "rIdMissing"),
    ),
    ("ppt/notesSlides/notesSlide1.xml", notes_xml()),
    ("ppt/comments/comment1.xml", comments_xml()),
    (
      "ppt/commentAuthors.xml", "<p:cmAuthorLst xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\"><p:cmAuthor id=\"0\" name=\"Author\" initials=\"A\"/></p:cmAuthorLst>",
    ),
    ("ppt/media/image1.png", "PNGDATA"),
    (
      "docProps/core.xml", "<cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:dcterms=\"http://purl.org/dc/terms/\"><dc:title>Spec Deck</dc:title><dc:subject>Parity</dc:subject><dc:creator>MoonBit</dc:creator><dc:description>PPTX metadata fixture</dc:description><cp:keywords>pptx,v2</cp:keywords><dcterms:created>2026-01-01T00:00:00Z</dcterms:created><dcterms:modified>2026-01-02T00:00:00Z</dcterms:modified></cp:coreProperties>",
    ),
    (
      "docProps/app.xml", "<Properties><Application>MarkItDown</Application><Slides>2</Slides><Words>42</Words></Properties>",
    ),
    (
      "docProps/custom.xml", "<Properties xmlns:vt=\"http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes\"><property name=\"Audience\"><vt:lpwstr>Engineering</vt:lpwstr></property></Properties>",
    ),
  ])
  @ox.open_ooxml_package(pptx)
}

///|
test "pptx M0-M10 source and model facts" {
  let pkg = sample_pkg()
  assert_true(@ox.has_part(pkg, "ppt/slides/slide1.xml"))
  let raw_slide = @ox.read_part_text(pkg, "ppt/slides/slide1.xml")
  assert_true(raw_slide.contains("<p:spTree"))
  let source = @pptx.parse_pptx_source(pkg)
  assert_true(source.metadata.title == Some("Spec Deck"))
  assert_true(source.metadata.application == Some("MarkItDown"))
  assert_eq(source.metadata.custom_properties.length(), 1)
  assert_true(source.metadata.custom_properties[0].name == "Audience")
  assert_true(source.metadata.custom_properties[0].value == "Engineering")
  assert_eq(source.slides.length(), 2)
  if source.slides[1].objects.length() == 0 {
    fail(
      "expected source slide objects for " +
      source.slides[1].slide_ref.part_name +
      "; warnings=" +
      source.warnings.length().to_string(),
    )
  }
  let doc = @pptx.normalize_pptx_source(source)
  assert_true(doc.metadata.title == Some("Spec Deck"))
  assert_true(doc.metadata.slides == Some("2"))
  assert_true(doc.part_graph.parts.length() > 0)
  match doc.part_graph.root_presentation_part {
    Some(part) => assert_eq(part, "ppt/presentation.xml")
    None => fail("expected root presentation")
  }
  assert_eq(doc.slides.length(), 2)
  assert_eq(doc.slides[0].part_name, "ppt/slides/slide2.xml")
  assert_eq(doc.slides[0].hidden, true)
  assert_eq(doc.slides[1].part_name, "ppt/slides/slide1.xml")
  assert_true(doc.layouts.length() >= 1)
  assert_true(doc.masters.length() >= 1)
  let slide = doc.slides[1]
  if slide.objects.length() < 5 {
    fail(
      "expected at least 5 slide objects, got " +
      slide.objects.length().to_string(),
    )
  }
  match slide.notes {
    Some(notes) => assert_true(notes.paragraphs.length() > 0)
    None => fail("expected notes")
  }
  assert_eq(slide.comments.length(), 2)
  let mut saw_table = false
  let mut saw_unknown = false
  let mut saw_title_hint = false
  let mut saw_picture = false
  let mut saw_picture_media = false
  for obj in slide.objects {
    match obj {
      @pptx.PptxObject::Table(table) => {
        saw_table = true
        assert_eq(table.rows.length(), 2)
      }
      @pptx.PptxObject::Unsupported(_) => saw_unknown = true
      @pptx.PptxObject::Picture(pic) => {
        saw_picture = true
        match pic.media {
          Some(_) => saw_picture_media = true
          None => ()
        }
      }
      @pptx.PptxObject::Shape(shape) =>
        match shape.placeholder {
          Some(ph) =>
            if ph.kind == @pptx.PptxPlaceholderKind::Title {
              saw_title_hint = true
            }
          None => ()
        }
      _ => ()
    }
  }
  assert_true(saw_table)
  assert_true(saw_unknown)
  assert_true(saw_title_hint)
  assert_true(saw_picture)
  assert_true(saw_picture_media)
  assert_true(doc.media.length() >= 1)
  let mut saw_external_media_warning = false
  let mut saw_missing_author_warning = false
  for warning in doc.warnings {
    if warning.kind == @pptx.PptxWarningKind::ExternalMedia {
      saw_external_media_warning = true
    }
    if warning.kind == @pptx.PptxWarningKind::MissingCommentAuthor {
      saw_missing_author_warning = true
    }
  }
  assert_true(saw_external_media_warning)
  assert_true(saw_missing_author_warning)
}

///|
fn m11_slide_xml() -> String {
  "<p:sld xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" " +
  "xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\" " +
  "xmlns:dgm=\"http://schemas.openxmlformats.org/drawingml/2006/diagram\" " +
  "xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" " +
  "xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
  "<p:cSld><p:spTree>" +
  "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
  "<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>" +
  "<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id=\"2\" name=\"Chart\"/></p:nvGraphicFramePr><a:graphic><a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/chart\"><c:chart r:id=\"rIdChart\"/></a:graphicData></a:graphic></p:graphicFrame>" +
  "<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id=\"3\" name=\"Missing Chart\"/></p:nvGraphicFramePr><a:graphic><a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/chart\"><c:chart r:id=\"rIdMissingChart\"/></a:graphicData></a:graphic></p:graphicFrame>" +
  "<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id=\"4\" name=\"SmartArt\"/></p:nvGraphicFramePr><a:graphic><a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/diagram\"><dgm:relIds r:dm=\"rIdDm\"/></a:graphicData></a:graphic></p:graphicFrame>" +
  "<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id=\"5\" name=\"OLE\"/></p:nvGraphicFramePr><a:graphic><a:graphicData uri=\"ole\"><p:oleObj r:id=\"rIdOle\"/></a:graphicData></a:graphic></p:graphicFrame>" +
  "<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id=\"6\" name=\"Unknown\"/></p:nvGraphicFramePr><a:graphic><a:graphicData uri=\"unknown\"/></a:graphic></p:graphicFrame>" +
  "</p:spTree></p:cSld></p:sld>"
}

///|
fn m11_chart_xml() -> String {
  "<c:chartSpace xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\">" +
  "<c:chart><c:title><c:tx><c:rich><a:p><a:r><a:t>Sales Chart</a:t></a:r></a:p></c:rich></c:tx></c:title>" +
  "<c:plotArea><c:barChart><c:ser><c:tx><c:strRef><c:strCache><c:pt idx=\"0\"><c:v>Series A</c:v></c:pt></c:strCache></c:strRef></c:tx>" +
  "<c:cat><c:strRef><c:strCache><c:pt idx=\"0\"><c:v>Q1</c:v></c:pt><c:pt idx=\"1\"><c:v>Q2</c:v></c:pt></c:strCache></c:strRef></c:cat>" +
  "<c:val><c:numRef><c:numCache><c:pt idx=\"0\"><c:v>42</c:v></c:pt></c:numCache></c:numRef></c:val>" +
  "</c:ser></c:barChart></c:plotArea><c:externalData r:id=\"rIdWorkbook\"/></c:chart></c:chartSpace>"
}

///|
fn m11_pkg() -> @ox.OoxmlPackage raise {
  build_store_zip([
    (
      "[Content_Types].xml",
      content_types(
        "<Override PartName=\"/ppt/charts/chart1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.drawingml.chart+xml\"/>" +
        "<Override PartName=\"/ppt/diagrams/data1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.drawingml.diagramData+xml\"/>" +
        "<Override PartName=\"/ppt/embeddings/oleObject1.bin\" ContentType=\"application/vnd.openxmlformats-officedocument.oleObject\"/>",
      ),
    ),
    (
      "_rels/.rels",
      rels(
        "<Relationship Id=\"rIdMain\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"ppt/presentation.xml\"/>",
      ),
    ),
    (
      "ppt/presentation.xml", "<p:presentation xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><p:sldIdLst><p:sldId id=\"256\" r:id=\"rId1\"/></p:sldIdLst></p:presentation>",
    ),
    (
      "ppt/_rels/presentation.xml.rels",
      rels(
        "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide1.xml\"/>",
      ),
    ),
    ("ppt/slides/slide1.xml", m11_slide_xml()),
    (
      "ppt/slides/_rels/slide1.xml.rels",
      rels(
        "<Relationship Id=\"rIdChart\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart\" Target=\"../charts/chart1.xml\"/>" +
        "<Relationship Id=\"rIdDm\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/diagramData\" Target=\"../diagrams/data1.xml\"/>" +
        "<Relationship Id=\"rIdOle\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/oleObject\" Target=\"../embeddings/oleObject1.bin\"/>",
      ),
    ),
    ("ppt/charts/chart1.xml", m11_chart_xml()),
    ("ppt/diagrams/data1.xml", "<dgm:dataModel/>"),
    ("ppt/embeddings/oleObject1.bin", "OLE"),
  ])
  |> @ox.open_ooxml_package
}

///|
test "pptx M11 graphic frames produce typed refs and warnings" {
  let doc = @pptx.parse_pptx_document_from_package(m11_pkg())
  let slide = doc.slides[0]
  let mut saw_chart = false
  let mut saw_missing_chart = false
  let mut saw_smart_art = false
  let mut saw_ole = false
  let mut saw_unknown = false
  for obj in slide.objects {
    match obj {
      @pptx.PptxObject::Chart(chart) =>
        match chart.relationship_id {
          Some("rIdChart") => {
            saw_chart = true
            assert_true(chart.target_part == Some("ppt/charts/chart1.xml"))
            assert_true(chart.title == Some("Sales Chart"))
            assert_true(chart.cached_text.contains("Series A"))
            assert_true(chart.cached_categories.contains("Q1"))
            assert_true(chart.cached_values.contains("42"))
            assert_true(chart.cached_series.length() == 1)
            assert_true(chart.cached_series[0].name == Some("Series A"))
            assert_true(chart.cached_series[0].categories.contains("Q2"))
            assert_true(chart.cached_series[0].values.contains("42"))
          }
          Some("rIdMissingChart") => {
            saw_missing_chart = true
            assert_true(chart.target_part is None)
          }
          _ => ()
        }
      @pptx.PptxObject::SmartArt(smart) => {
        saw_smart_art = true
        assert_true(smart.relationship_id == Some("rIdDm"))
        assert_true(smart.target_part == Some("ppt/diagrams/data1.xml"))
      }
      @pptx.PptxObject::Ole(ole) => {
        saw_ole = true
        assert_true(ole.relationship_id == Some("rIdOle"))
        assert_true(ole.target_part == Some("ppt/embeddings/oleObject1.bin"))
      }
      @pptx.PptxObject::Unsupported(unsupported) =>
        if unsupported.kind == "UnknownGraphicFrame" {
          saw_unknown = true
        }
      _ => ()
    }
  }
  assert_true(saw_chart)
  assert_true(saw_missing_chart)
  assert_true(saw_smart_art)
  assert_true(saw_ole)
  assert_true(saw_unknown)
  let mut saw_missing_rel_warning = false
  let mut unsupported_warnings = 0
  for warning in doc.warnings {
    if warning.kind == @pptx.PptxWarningKind::MissingRelationshipTarget {
      saw_missing_rel_warning = true
    }
    if warning.kind == @pptx.PptxWarningKind::UnsupportedObject {
      unsupported_warnings += 1
    }
  }
  assert_true(saw_missing_rel_warning)
  assert_true(unsupported_warnings >= 4)
}

///|
fn m12_group_child_xml() -> String {
  "<p:grpSp><p:nvGrpSpPr><p:cNvPr id=\"2\" name=\"Group\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
  "<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"400\" cy=\"400\"/><a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"400\" cy=\"400\"/></a:xfrm></p:grpSpPr>" +
  "<p:sp><p:nvSpPr><p:cNvPr id=\"3\" name=\"Grouped Text\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:txBody><a:p><a:r><a:t>Grouped body</a:t></a:r></a:p></p:txBody></p:sp>" +
  "</p:grpSp>"
}

///|
fn deep_group_xml(depth : Int) -> String {
  if depth <= 0 {
    "<p:sp><p:nvSpPr><p:cNvPr id=\"90\" name=\"Too Deep\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:txBody><a:p><a:r><a:t>Too deep</a:t></a:r></a:p></p:txBody></p:sp>"
  } else {
    "<p:grpSp><p:nvGrpSpPr><p:cNvPr id=\"" +
    (100 + depth).to_string() +
    "\" name=\"Deep\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"1\" cy=\"1\"/><a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"1\" cy=\"1\"/></a:xfrm></p:grpSpPr>" +
    deep_group_xml(depth - 1) +
    "</p:grpSp>"
  }
}

///|
fn m12_slide_xml() -> String {
  "<p:sld xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\">" +
  "<p:cSld><p:spTree>" +
  "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
  "<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>" +
  m12_group_child_xml() +
  "<p:cxnSp><p:nvCxnSpPr><p:cNvPr id=\"4\" name=\"Connector\"/><p:cNvCxnSpPr/><p:nvPr/></p:nvCxnSpPr><p:spPr><a:xfrm><a:off x=\"1\" y=\"1\"/><a:ext cx=\"10\" cy=\"10\"/></a:xfrm></p:spPr></p:cxnSp>" +
  "<p:sp><p:nvSpPr><p:cNvPr id=\"5\" name=\"Decoration\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:prstGeom prst=\"rect\"/></p:spPr></p:sp>" +
  deep_group_xml(28) +
  "</p:spTree></p:cSld></p:sld>"
}

///|
fn m12_pkg() -> @ox.OoxmlPackage raise {
  build_store_zip([
    ("[Content_Types].xml", content_types("")),
    (
      "_rels/.rels",
      rels(
        "<Relationship Id=\"rIdMain\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"ppt/presentation.xml\"/>",
      ),
    ),
    (
      "ppt/presentation.xml", "<p:presentation xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><p:sldIdLst><p:sldId id=\"256\" r:id=\"rId1\"/></p:sldIdLst></p:presentation>",
    ),
    (
      "ppt/_rels/presentation.xml.rels",
      rels(
        "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide1.xml\"/>",
      ),
    ),
    ("ppt/slides/slide1.xml", m12_slide_xml()),
    ("ppt/slides/_rels/slide1.xml.rels", rels("")),
  ])
  |> @ox.open_ooxml_package
}

///|
test "pptx M12 groups connectors decorative shapes and depth guard" {
  let doc = @pptx.parse_pptx_document_from_package(m12_pkg())
  let slide = doc.slides[0]
  let mut saw_group_child = false
  let mut saw_connector = false
  let mut saw_decorative = false
  for obj in slide.objects {
    match obj {
      @pptx.PptxObject::Group(group) =>
        for child in group.children {
          match child {
            @pptx.PptxObject::Shape(shape) =>
              match shape.text_body {
                Some(body) =>
                  if body.paragraphs.length() > 0 {
                    saw_group_child = true
                  }
                None => ()
              }
            _ => ()
          }
        }
      @pptx.PptxObject::Connector(conn) => {
        saw_connector = true
        assert_true(conn.name == Some("Connector"))
      }
      @pptx.PptxObject::Shape(shape) =>
        if shape.name == Some("Decoration") && shape.text_body is None {
          match shape.reading_order {
            Some(hint) =>
              if hint.bucket == @pptx.PptxReadingBucket::Decorative {
                saw_decorative = true
              }
            None => ()
          }
        }
      _ => ()
    }
  }
  assert_true(saw_group_child)
  assert_true(saw_connector)
  assert_true(saw_decorative)
  let mut saw_depth_guard = false
  for warning in doc.warnings {
    if warning.kind == @pptx.PptxWarningKind::OverBudget &&
      warning.message.contains("group depth") {
      saw_depth_guard = true
    }
  }
  assert_true(saw_depth_guard)
}

///|
fn one_slide_pkg(
  slide : String,
  slide_rels : String,
  extra_content_types : String,
  extra_entries : Array[(String, String)],
) -> @ox.OoxmlPackage raise {
  let entries : Array[(String, String)] = [
    ("[Content_Types].xml", content_types(extra_content_types)),
    (
      "_rels/.rels",
      rels(
        "<Relationship Id=\"rIdMain\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"ppt/presentation.xml\"/>",
      ),
    ),
    (
      "ppt/presentation.xml", "<p:presentation xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><p:sldIdLst><p:sldId id=\"256\" r:id=\"rId1\"/></p:sldIdLst></p:presentation>",
    ),
    (
      "ppt/_rels/presentation.xml.rels",
      rels(
        "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide1.xml\"/>",
      ),
    ),
    ("ppt/slides/slide1.xml", slide),
    ("ppt/slides/_rels/slide1.xml.rels", rels(slide_rels)),
  ]
  for entry in extra_entries {
    entries.push(entry)
  }
  build_store_zip(entries) |> @ox.open_ooxml_package
}

///|
fn simple_slide(inner : String) -> String {
  "<p:sld xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" " +
  "xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" " +
  "xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
  "<p:cSld><p:spTree>" +
  "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
  "<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>" +
  inner +
  "</p:spTree></p:cSld></p:sld>"
}

///|
fn text_shape(
  id : Int,
  name : String,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  text : String,
) -> String {
  "<p:sp><p:nvSpPr><p:cNvPr id=\"" +
  id.to_string() +
  "\" name=\"" +
  name +
  "\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x=\"" +
  x.to_string() +
  "\" y=\"" +
  y.to_string() +
  "\"/><a:ext cx=\"" +
  w.to_string() +
  "\" cy=\"" +
  h.to_string() +
  "\"/></a:xfrm></p:spPr><p:txBody><a:p><a:r><a:t>" +
  text +
  "</a:t></a:r></a:p></p:txBody></p:sp>"
}

///|
fn placeholder_shape(
  id : Int,
  name : String,
  ph_type : String,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  text : String,
) -> String {
  "<p:sp><p:nvSpPr><p:cNvPr id=\"" +
  id.to_string() +
  "\" name=\"" +
  name +
  "\"/><p:cNvSpPr/><p:nvPr><p:ph type=\"" +
  ph_type +
  "\"/></p:nvPr></p:nvSpPr><p:spPr><a:xfrm><a:off x=\"" +
  x.to_string() +
  "\" y=\"" +
  y.to_string() +
  "\"/><a:ext cx=\"" +
  w.to_string() +
  "\" cy=\"" +
  h.to_string() +
  "\"/></a:xfrm></p:spPr><p:txBody><a:p><a:r><a:t>" +
  text +
  "</a:t></a:r></a:p></p:txBody></p:sp>"
}

///|
fn picture_shape(
  id : Int,
  name : String,
  rel_id : String,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
  descr : String,
  title : String,
) -> String {
  "<p:pic><p:nvPicPr><p:cNvPr id=\"" +
  id.to_string() +
  "\" name=\"" +
  name +
  "\" descr=\"" +
  descr +
  "\" title=\"" +
  title +
  "\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr><p:blipFill><a:blip r:embed=\"" +
  rel_id +
  "\"/></p:blipFill><p:spPr><a:xfrm><a:off x=\"" +
  x.to_string() +
  "\" y=\"" +
  y.to_string() +
  "\"/><a:ext cx=\"" +
  w.to_string() +
  "\" cy=\"" +
  h.to_string() +
  "\"/></a:xfrm></p:spPr></p:pic>"
}

///|
fn image_rel(id : String, target : String) -> String {
  "<Relationship Id=\"" +
  id +
  "\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"" +
  target +
  "\"/>"
}

///|
test "pptx A image caption pairs preserve image metadata" {
  let slide = simple_slide(
    picture_shape(
      2, "System Image", "rIdImg", 100000, 100000, 1000000, 800000, "System diagram alt",
      "System diagram title",
    ) +
    text_shape(
      3, "Figure Caption", 100000, 950000, 1000000, 150000, "Figure 1: System diagram",
    ),
  )
  let doc = @pptx.parse_pptx_document_from_package(
    one_slide_pkg(slide, image_rel("rIdImg", "../media/image1.png"), "", [
      ("ppt/media/image1.png", "PNGDATA"),
    ]),
  )
  let slide0 = doc.slides[0]
  assert_eq(slide0.image_caption_pairs.length(), 1)
  let pair = slide0.image_caption_pairs[0]
  assert_true(pair.owning_slide_part == "ppt/slides/slide1.xml")
  assert_true(pair.image_shape_id == Some("2"))
  assert_true(pair.image_name == Some("System Image"))
  assert_true(pair.image_alt_text == Some("System diagram alt"))
  assert_true(pair.image_title == Some("System diagram title"))
  assert_true(pair.caption_text == "Figure 1: System diagram")
  assert_true(pair.confidence == @pptx.PptxConfidence::High)
  assert_true(slide0.layout_regions.length() >= 2)
  let mut saw_caption_bucket = false
  for obj in slide0.objects {
    match obj {
      @pptx.PptxObject::Shape(shape) =>
        match shape.reading_order {
          Some(hint) =>
            if hint.bucket == @pptx.PptxReadingBucket::CaptionLike {
              saw_caption_bucket = true
            }
          None => ()
        }
      _ => ()
    }
  }
  assert_true(saw_caption_bucket)
}

///|
test "pptx B inferred table grid card and two-column regions" {
  let table_doc = @pptx.parse_pptx_document_from_package(
    one_slide_pkg(
      simple_slide(
        text_shape(2, "Cell A1", 0, 0, 400000, 200000, "Metric") +
        text_shape(3, "Cell A2", 500000, 0, 400000, 200000, "Value") +
        text_shape(4, "Cell B1", 0, 400000, 400000, 200000, "Q1") +
        text_shape(5, "Cell B2", 500000, 400000, 400000, 200000, "42"),
      ),
      "",
      "",
      [],
    ),
  )
  let mut saw_table_like = false
  let mut saw_explicit_table = false
  for obj in table_doc.slides[0].objects {
    match obj {
      @pptx.PptxObject::Table(_) => saw_explicit_table = true
      _ => ()
    }
  }
  for region in table_doc.slides[0].layout_regions {
    if region.kind == @pptx.PptxLayoutRegionKind::TableLike &&
      region.confidence == @pptx.PptxConfidence::High {
      saw_table_like = true
    }
  }
  assert_true(saw_table_like)
  assert_true(!saw_explicit_table)

  let two_col_doc = @pptx.parse_pptx_document_from_package(
    one_slide_pkg(
      simple_slide(
        text_shape(
          2, "Right Column", 3000000, 1000000, 1000000, 300000, "Right",
        ) +
        text_shape(3, "Left Column", 0, 1000000, 1000000, 300000, "Left"),
      ),
      "",
      "",
      [],
    ),
  )
  let mut saw_two_column = false
  for region in two_col_doc.slides[0].layout_regions {
    if region.kind == @pptx.PptxLayoutRegionKind::TwoColumn {
      saw_two_column = true
    }
  }
  assert_true(saw_two_column)

  let grid_doc = @pptx.parse_pptx_document_from_package(
    one_slide_pkg(
      simple_slide(
        picture_shape(2, "Grid 1", "rId1", 0, 0, 200000, 200000, "A", "") +
        picture_shape(3, "Grid 2", "rId2", 400000, 0, 200000, 200000, "B", "") +
        picture_shape(4, "Grid 3", "rId3", 0, 400000, 200000, 200000, "C", "") +
        picture_shape(
          5, "Grid 4", "rId4", 400000, 400000, 200000, 200000, "D", "",
        ),
      ),
      image_rel("rId1", "../media/image1.png") +
      image_rel("rId2", "../media/image2.png") +
      image_rel("rId3", "../media/image3.png") +
      image_rel("rId4", "../media/image4.png"),
      "",
      [
        ("ppt/media/image1.png", "PNG1"),
        ("ppt/media/image2.png", "PNG2"),
        ("ppt/media/image3.png", "PNG3"),
        ("ppt/media/image4.png", "PNG4"),
      ],
    ),
  )
  let mut saw_grid = false
  for region in grid_doc.slides[0].layout_regions {
    if region.kind == @pptx.PptxLayoutRegionKind::GridLike {
      saw_grid = true
    }
  }
  assert_true(saw_grid)

  let card_doc = @pptx.parse_pptx_document_from_package(
    one_slide_pkg(
      simple_slide(
        text_shape(2, "Card One", 0, 0, 800000, 400000, "Plan") +
        text_shape(3, "Card Two", 1000000, 0, 800000, 400000, "Build"),
      ),
      "",
      "",
      [],
    ),
  )
  let mut saw_card = false
  for region in card_doc.slides[0].layout_regions {
    if region.kind == @pptx.PptxLayoutRegionKind::CardLike &&
      region.confidence == @pptx.PptxConfidence::High {
      saw_card = true
    }
  }
  assert_true(saw_card)
}

///|
test "pptx E reading order policy uses placeholders geometry and grouping" {
  let slide = simple_slide(
    placeholder_shape(2, "Title", "title", 0, 0, 4000000, 300000, "Title") +
    text_shape(3, "Right Body", 3000000, 900000, 1000000, 300000, "Right") +
    text_shape(4, "Left Body", 0, 900000, 1000000, 300000, "Left") +
    placeholder_shape(5, "Footer", "ftr", 0, 5000000, 4000000, 200000, "Footer") +
    "<p:grpSp><p:nvGrpSpPr><p:cNvPr id=\"6\" name=\"Group\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"1600000\"/><a:ext cx=\"1200000\" cy=\"700000\"/><a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"1200000\" cy=\"700000\"/></a:xfrm></p:grpSpPr>" +
    text_shape(7, "Grouped Later", 600000, 0, 400000, 200000, "Grouped B") +
    text_shape(8, "Grouped First", 0, 0, 400000, 200000, "Grouped A") +
    "</p:grpSp>" +
    "<p:sp><p:nvSpPr><p:cNvPr id=\"9\" name=\"Decoration\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:prstGeom prst=\"rect\"/></p:spPr></p:sp>",
  )
  let doc = @pptx.parse_pptx_document_from_package(
    one_slide_pkg(slide, "", "", []),
  )
  let slide0 = doc.slides[0]
  assert_true(slide0.reading_order[0].node_key == "shape-2")
  assert_true(slide0.reading_order[1].node_key == "shape-4")
  assert_true(slide0.reading_order[2].node_key == "shape-3")
  let mut saw_footer = false
  let mut saw_decorative = false
  let mut saw_group_order = false
  for obj in slide0.objects {
    match obj {
      @pptx.PptxObject::Shape(shape) =>
        match shape.reading_order {
          Some(hint) => {
            if shape.name == Some("Footer") &&
              hint.bucket == @pptx.PptxReadingBucket::Footer {
              saw_footer = true
            }
            if shape.name == Some("Decoration") &&
              hint.bucket == @pptx.PptxReadingBucket::Decorative {
              saw_decorative = true
            }
          }
          None => ()
        }
      @pptx.PptxObject::Group(group) => {
        let sorted = group.children.copy()
        let keyed : Array[(String, String)] = []
        for child in sorted {
          match child {
            @pptx.PptxObject::Shape(shape) =>
              match shape.reading_order {
                Some(hint) =>
                  keyed.push((hint.order_key, shape.name.unwrap_or("")))
                None => ()
              }
            _ => ()
          }
        }
        keyed.sort_by(fn(a, b) { a.0.compare(b.0) })
        if keyed.length() == 2 && keyed[0].0.compare(keyed[1].0) <= 0 {
          saw_group_order = true
        }
      }
      _ => ()
    }
  }
  assert_true(saw_footer)
  assert_true(saw_decorative)
  assert_true(saw_group_order)
}
