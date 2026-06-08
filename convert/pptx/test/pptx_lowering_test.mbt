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
fn content_types() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">" +
  "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>" +
  "<Default Extension=\"xml\" ContentType=\"application/xml\"/>" +
  "<Default Extension=\"png\" ContentType=\"image/png\"/>" +
  "<Override PartName=\"/ppt/presentation.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\"/>" +
  "<Override PartName=\"/ppt/slides/slide1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>" +
  "<Override PartName=\"/ppt/notesSlides/notesSlide1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.notesSlide+xml\"/>" +
  "<Override PartName=\"/ppt/comments/comment1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.comments+xml\"/>" +
  "<Override PartName=\"/ppt/commentAuthors.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.commentAuthors+xml\"/>" +
  "<Override PartName=\"/ppt/charts/chart1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.drawingml.chart+xml\"/>" +
  "<Override PartName=\"/ppt/diagrams/data1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.drawingml.diagramData+xml\"/>" +
  "<Override PartName=\"/ppt/embeddings/oleObject1.bin\" ContentType=\"application/vnd.openxmlformats-officedocument.oleObject\"/>" +
  "<Override PartName=\"/docProps/core.xml\" ContentType=\"application/vnd.openxmlformats-package.core-properties+xml\"/>" +
  "<Override PartName=\"/docProps/app.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.extended-properties+xml\"/>" +
  "<Override PartName=\"/docProps/custom.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.custom-properties+xml\"/>" +
  "</Types>"
}

///|
fn slide_xml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<p:sld xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" " +
  "xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\" " +
  "xmlns:dgm=\"http://schemas.openxmlformats.org/drawingml/2006/diagram\" " +
  "xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" " +
  "xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
  "<p:cSld><p:spTree>" +
  "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
  "<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>" +
  "<p:sp><p:nvSpPr><p:cNvPr id=\"2\" name=\"Title\"/><p:cNvSpPr/><p:nvPr><p:ph type=\"title\"/></p:nvPr></p:nvSpPr>" +
  "<p:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"5000000\" cy=\"500000\"/></a:xfrm></p:spPr>" +
  "<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>Deck Title</a:t></a:r></a:p></p:txBody></p:sp>" +
  "<p:sp><p:nvSpPr><p:cNvPr id=\"3\" name=\"Body\"/><p:cNvSpPr/><p:nvPr><p:ph type=\"body\" idx=\"1\"/></p:nvPr></p:nvSpPr>" +
  "<p:spPr><a:xfrm><a:off x=\"0\" y=\"1000000\"/><a:ext cx=\"5000000\" cy=\"3000000\"/></a:xfrm></p:spPr>" +
  "<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:pPr lvl=\"1\"><a:buChar char=\"*\"/></a:pPr><a:r><a:t>First bullet</a:t></a:r><a:br/><a:r><a:rPr><a:hlinkClick r:id=\"rIdLink\"/></a:rPr><a:t>Example</a:t></a:r></a:p></p:txBody></p:sp>" +
  "<p:pic><p:nvPicPr><p:cNvPr id=\"4\" name=\"Picture\" descr=\"Diagram\" title=\"System diagram\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr><p:blipFill><a:blip r:embed=\"rIdImg\"/></p:blipFill><p:spPr><a:xfrm><a:off x=\"100\" y=\"200\"/><a:ext cx=\"300\" cy=\"400\"/></a:xfrm></p:spPr></p:pic>" +
  "<p:sp><p:nvSpPr><p:cNvPr id=\"13\" name=\"Figure Caption\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x=\"100\" y=\"650\"/><a:ext cx=\"300\" cy=\"120\"/></a:xfrm></p:spPr><p:txBody><a:p><a:r><a:t>Figure 1: System diagram</a:t></a:r></a:p></p:txBody></p:sp>" +
  "<p:pic><p:nvPicPr><p:cNvPr id=\"5\" name=\"External Picture\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr><p:blipFill><a:blip r:link=\"rIdExt\"/></p:blipFill><p:spPr><a:xfrm><a:off x=\"100\" y=\"1000\"/><a:ext cx=\"300\" cy=\"400\"/></a:xfrm></p:spPr></p:pic>" +
  "<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id=\"6\" name=\"Table\"/></p:nvGraphicFramePr><a:graphic><a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/table\"><a:tbl><a:tr><a:tc><a:txBody><a:p><a:r><a:t>Quarter</a:t></a:r></a:p></a:txBody></a:tc><a:tc><a:txBody><a:p><a:r><a:t>Revenue</a:t></a:r></a:p></a:txBody></a:tc></a:tr><a:tr><a:tc><a:txBody><a:p><a:r><a:t>Q1</a:t></a:r></a:p></a:txBody></a:tc><a:tc><a:txBody><a:p><a:r><a:t>42</a:t></a:r></a:p></a:txBody></a:tc></a:tr></a:tbl></a:graphicData></a:graphic></p:graphicFrame>" +
  "<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id=\"7\" name=\"Chart\"/></p:nvGraphicFramePr><a:graphic><a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/chart\"><c:chart r:id=\"rIdChart\"/></a:graphicData></a:graphic></p:graphicFrame>" +
  "<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id=\"8\" name=\"Unknown\"/></p:nvGraphicFramePr><a:graphic><a:graphicData uri=\"unknown\"/></a:graphic></p:graphicFrame>" +
  "<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id=\"9\" name=\"SmartArt\"/></p:nvGraphicFramePr><a:graphic><a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/diagram\"><dgm:relIds r:dm=\"rIdDm\"/></a:graphicData></a:graphic></p:graphicFrame>" +
  "<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id=\"10\" name=\"OLE\"/></p:nvGraphicFramePr><a:graphic><a:graphicData uri=\"ole\"><p:oleObj r:id=\"rIdOle\"/></a:graphicData></a:graphic></p:graphicFrame>" +
  "<p:cxnSp><p:nvCxnSpPr><p:cNvPr id=\"11\" name=\"Connector\"/><p:cNvCxnSpPr/><p:nvPr/></p:nvCxnSpPr><p:spPr><a:xfrm><a:off x=\"1\" y=\"1\"/><a:ext cx=\"10\" cy=\"10\"/></a:xfrm></p:spPr></p:cxnSp>" +
  "<p:sp><p:nvSpPr><p:cNvPr id=\"12\" name=\"Decoration\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:prstGeom prst=\"rect\"/></p:spPr></p:sp>" +
  "</p:spTree></p:cSld></p:sld>"
}

///|
fn notes_xml() -> String {
  "<p:notes xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\"><p:cSld><p:spTree><p:sp><p:nvSpPr><p:cNvPr id=\"9\" name=\"Notes\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:txBody><a:p><a:r><a:t>Speaker note</a:t></a:r></a:p></p:txBody></p:sp></p:spTree></p:cSld></p:notes>"
}

///|
fn comments_xml() -> String {
  "<p:cmLst xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\"><p:cm authorId=\"0\" idx=\"1\"><p:text>Review this</p:text></p:cm></p:cmLst>"
}

///|
fn sample_pkg() -> @ox.OoxmlPackage raise {
  build_store_zip([
    ("[Content_Types].xml", content_types()),
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
    ("ppt/slides/slide1.xml", slide_xml()),
    (
      "ppt/slides/_rels/slide1.xml.rels",
      rels(
        "<Relationship Id=\"rIdImg\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"../media/image1.png\"/>" +
        "<Relationship Id=\"rIdExt\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"https://example.com/image.png\" TargetMode=\"External\"/>" +
        "<Relationship Id=\"rIdLink\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink\" Target=\"https://example.com\" TargetMode=\"External\"/>" +
        "<Relationship Id=\"rIdNotes\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesSlide\" Target=\"../notesSlides/notesSlide1.xml\"/>" +
        "<Relationship Id=\"rIdComments\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments\" Target=\"../comments/comment1.xml\"/>" +
        "<Relationship Id=\"rIdChart\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart\" Target=\"../charts/chart1.xml\"/>" +
        "<Relationship Id=\"rIdDm\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/diagramData\" Target=\"../diagrams/data1.xml\"/>" +
        "<Relationship Id=\"rIdOle\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/oleObject\" Target=\"../embeddings/oleObject1.bin\"/>",
      ),
    ),
    ("ppt/media/image1.png", "PNGDATA"),
    ("ppt/notesSlides/notesSlide1.xml", notes_xml()),
    ("ppt/comments/comment1.xml", comments_xml()),
    (
      "ppt/commentAuthors.xml", "<p:cmAuthorLst xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\"><p:cmAuthor id=\"0\" name=\"Author\" initials=\"A\"/></p:cmAuthorLst>",
    ),
    (
      "ppt/charts/chart1.xml", "<c:chartSpace xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\"><c:chart><c:title><c:tx><c:rich><a:p><a:r><a:t>Sales Chart</a:t></a:r></a:p></c:rich></c:tx></c:title><c:plotArea><c:barChart><c:ser><c:tx><c:strRef><c:strCache><c:pt idx=\"0\"><c:v>Series A</c:v></c:pt></c:strCache></c:strRef></c:tx><c:cat><c:strRef><c:strCache><c:pt idx=\"0\"><c:v>Q1</c:v></c:pt></c:strCache></c:strRef></c:cat><c:val><c:numRef><c:numCache><c:pt idx=\"0\"><c:v>42</c:v></c:pt></c:numCache></c:numRef></c:val></c:ser></c:barChart></c:plotArea></c:chart></c:chartSpace>",
    ),
    ("ppt/diagrams/data1.xml", "<dgm:dataModel/>"),
    ("ppt/embeddings/oleObject1.bin", "OLE"),
    (
      "docProps/core.xml", "<cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\"><dc:title>Fixture Deck</dc:title><dc:creator>MoonBit</dc:creator></cp:coreProperties>",
    ),
    (
      "docProps/app.xml", "<Properties><Application>MarkItDown</Application><Slides>1</Slides></Properties>",
    ),
    (
      "docProps/custom.xml", "<Properties xmlns:vt=\"http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes\"><property name=\"Audience\"><vt:lpwstr>QA</vt:lpwstr></property></Properties>",
    ),
  ])
  |> @ox.open_ooxml_package
}

///|
fn sample_doc() -> @pptx.PptxDocument raise {
  @pptx.normalize_pptx_source(@pptx.parse_pptx_source(sample_pkg()))
}

///|
fn ensure_dir(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    @fs.create_dir(path)
  }
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
  ensure_dir(".tmp")
  ensure_dir(path)
}

///|
test "pptx lowering consumes normalized model and emits markdown ir" {
  let doc = @lower.lower_pptx_document(sample_doc(), "fixture.pptx", "", 6)
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("## Slide 1"))
  assert_true(markdown.contains("### Deck Title"))
  assert_true(
    markdown.contains("  - First bullet<br>[Example](https://example.com)"),
  )
  assert_true(markdown.contains("| Quarter | Revenue |"))
  assert_true(
    markdown.contains("[Unsupported PPTX media: https://example.com/image.png]"),
  )
  assert_true(
    markdown.contains(
      "[Unsupported PPTX chart: ppt/charts/chart1.xml; series=Series A; categories=Q1; values=42]",
    ),
  )
  assert_true(
    markdown.contains("[Unsupported PPTX SmartArt: ppt/diagrams/data1.xml]"),
  )
  assert_true(
    markdown.contains(
      "[Unsupported PPTX OLE object: ppt/embeddings/oleObject1.bin]",
    ),
  )
  assert_true(markdown.contains("[PPTX connector omitted: Connector]"))
  assert_true(markdown.contains("[PPTX decorative shape omitted: Decoration]"))
  assert_true(
    markdown.contains("[Unsupported PPTX object: UnknownGraphicFrame]"),
  )
  assert_true(markdown.contains("### Comments"))
  assert_true(markdown.contains("- Author: Review this"))
  assert_true(markdown.contains("### Speaker Notes"))
  assert_true(markdown.contains("Speaker note"))
  assert_true(markdown.contains("## PPTX Warnings"))
  assert_true(
    markdown.contains("- unsupported graphic frame: UnknownGraphicFrame"),
  )
  assert_true(markdown.contains("- unsupported graphic frame: SmartArt"))
  assert_true(markdown.contains("- unsupported graphic frame: OLE"))
}

///|
test "pptx lowering exports internal image assets with origin metadata" {
  let out_dir = ".tmp/convert-pptx-v2-test"
  recreate_clean_dir(out_dir)
  let doc = @lower.lower_pptx_document(sample_doc(), "fixture.pptx", out_dir, 6)
  let mut image_path : String? = None
  for block in doc.blocks.val {
    match block {
      @cor.Block::ImageBlock(img) => {
        image_path = Some(img.path)
        assert_true(img.alt_text == Some("Diagram"))
        assert_true(img.title == Some("System diagram"))
        assert_true(img.caption == Some("Figure 1: System diagram"))
      }
      _ => ()
    }
  }
  let rel_path = image_path.unwrap_or_else(() => fail("expected image block"))
  assert_true(rel_path.has_prefix("assets/"))
  assert_true(rel_path.has_suffix(".png"))
  assert_true(@fs.path_exists(out_dir + "/" + rel_path))
  assert_true(doc.asset_origins.val.contains(rel_path))
  let origin = doc.asset_origins.val
    .get(rel_path)
    .unwrap_or_else(() => fail("expected asset origin"))
  assert_true(origin.slide == Some(1))
  assert_true(origin.object_ref == Some("picture-4"))
  assert_true(origin.relationship_id == Some("rIdImg"))
  assert_true(origin.nearby_caption == Some("Figure 1: System diagram"))
  remove_dir_recursive(out_dir)
}

///|
test "pptx lowering exposes model docProps metadata" {
  let pptx_doc = sample_doc()
  let props = @lower.pptx_metadata_document_properties(pptx_doc).unwrap_or_else(() => {
      fail("expected metadata properties")
    },
  )
  assert_true(props.title == Some("Fixture Deck"))
  assert_true(props.creator == Some("MoonBit"))
  assert_true(props.application == Some("MarkItDown"))
  assert_true(props.slides == Some("1"))
  assert_eq(pptx_doc.metadata.custom_properties.length(), 1)
  assert_true(pptx_doc.metadata.custom_properties[0].name == "Audience")
  assert_true(pptx_doc.metadata.custom_properties[0].value == "QA")
}

///|
fn region_slide(inner : String) -> String {
  "<p:sld xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" " +
  "xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\">" +
  "<p:cSld><p:spTree>" +
  "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
  "<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>" +
  inner +
  "</p:spTree></p:cSld></p:sld>"
}

///|
fn region_text_shape(
  id : Int,
  name : String,
  x : Int,
  y : Int,
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
  "\"/><a:ext cx=\"300000\" cy=\"150000\"/></a:xfrm></p:spPr><p:txBody><a:p><a:r><a:t>" +
  text +
  "</a:t></a:r></a:p></p:txBody></p:sp>"
}

///|
fn region_pkg(slide : String) -> @ox.OoxmlPackage raise {
  build_store_zip([
    ("[Content_Types].xml", content_types()),
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
    ("ppt/slides/_rels/slide1.xml.rels", rels("")),
  ])
  |> @ox.open_ooxml_package
}

///|
test "pptx lowering consumes inferred table-like and card-like regions" {
  let table_doc = @pptx.parse_pptx_document_from_package(
    region_pkg(
      region_slide(
        region_text_shape(2, "Cell A1", 0, 0, "Metric") +
        region_text_shape(3, "Cell A2", 500000, 0, "Value") +
        region_text_shape(4, "Cell B1", 0, 400000, "Q1") +
        region_text_shape(5, "Cell B2", 500000, 400000, "42"),
      ),
    ),
  )
  let table_lowered = @lower.lower_pptx_document(
    table_doc, "regions.pptx", "", 6,
  )
  let table_md = @cor.emit_markdown(table_lowered)
  assert_true(table_md.contains("| Metric | Value |"))
  assert_true(table_md.contains("| Q1 | 42 |"))

  let card_doc = @pptx.parse_pptx_document_from_package(
    region_pkg(
      region_slide(
        region_text_shape(2, "Card One", 0, 0, "Plan") +
        region_text_shape(3, "Card Two", 500000, 0, "Build"),
      ),
    ),
  )
  let card_lowered = @lower.lower_pptx_document(card_doc, "regions.pptx", "", 6)
  let mut saw_card_block = false
  for block in card_lowered.blocks.val {
    match block {
      @cor.Block::BlockQuote(text) =>
        if text.contains("Plan") && text.contains("Build") {
          saw_card_block = true
        }
      _ => ()
    }
  }
  assert_true(saw_card_block)
}

///|
test "pptx lowering bounds table span expansion" {
  let table_xml =
    "<p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id=\"5\" name=\"Table\"/></p:nvGraphicFramePr><a:graphic><a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/table\"><a:tbl><a:tr><a:tc gridSpan=\"2000\"><a:txBody><a:p><a:r><a:t>Wide</a:t></a:r></a:p></a:txBody></a:tc></a:tr></a:tbl></a:graphicData></a:graphic></p:graphicFrame>"
  let pptx_doc = @pptx.parse_pptx_document_from_package(
    region_pkg(region_slide(table_xml)),
  )
  let lowered = @lower.lower_pptx_document(
    pptx_doc, "wide-table.pptx", "", 6,
  )
  let markdown = @cor.emit_markdown(lowered)
  assert_true(markdown.contains("Wide"))
  assert_true(markdown.length() < 10_000)
}
