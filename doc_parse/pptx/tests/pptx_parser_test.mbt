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
    i = i + 1
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
fn generated_pptx_pkg(
  entries : Array[(String, String)],
) -> @ox.OoxmlPackage raise {
  @ox.open_ooxml_package(build_store_zip(entries)) catch {
    e => fail("open generated pptx package failed: " + e.to_string())
  }
}

///|
fn grouped_pptx_pkg() -> @ox.OoxmlPackage raise {
  let slide_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<p:sld xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" " +
    "xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" " +
    "xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/><a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>" +
    "<p:grpSp>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"20\" name=\"Outer Group\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/><a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>" +
    "<p:grpSp>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"21\" name=\"Inner Group\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/><a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>" +
    "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"22\" name=\"Nested Text\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr><a:xfrm><a:off x=\"200\" y=\"200\"/><a:ext cx=\"100\" cy=\"100\"/></a:xfrm></p:spPr>" +
    "<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>Nested Text</a:t></a:r></a:p></p:txBody>" +
    "</p:sp>" +
    "</p:grpSp>" +
    "<p:pic>" +
    "<p:nvPicPr><p:cNvPr id=\"3\" name=\"Grouped Pic\" descr=\"grouped alt\" title=\"hero\"/>" +
    "<p:cNvPicPr/><p:nvPr/></p:nvPicPr>" +
    "<p:blipFill><a:blip r:embed=\"rId5\"/></p:blipFill>" +
    "</p:pic>" +
    "<p:graphicFrame>" +
    "<p:nvGraphicFramePr><p:cNvPr id=\"7\" name=\"Grouped Table\"/></p:nvGraphicFramePr>" +
    "<a:graphic><a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/table\">" +
    "<a:tbl><a:tr><a:tc><a:txBody><a:p><a:r><a:t>H</a:t></a:r></a:p></a:txBody></a:tc></a:tr></a:tbl>" +
    "</a:graphicData></a:graphic>" +
    "</p:graphicFrame>" +
    "<p:sp>" +
    "<p:nvSpPr><p:cNvPr id=\"23\" name=\"Linked Text\"/><p:cNvSpPr txBox=\"1\"/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr><a:xfrm><a:off x=\"300\" y=\"300\"/><a:ext cx=\"100\" cy=\"100\"/></a:xfrm></p:spPr>" +
    "<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr><a:hlinkClick r:id=\"rId7\"/></a:rPr><a:t>Visit</a:t></a:r></a:p></p:txBody>" +
    "</p:sp>" +
    "</p:grpSp>" +
    "</p:spTree></p:cSld></p:sld>"
  let notes_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<p:notes xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" " +
    "xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>" +
    "<p:sp><p:nvSpPr><p:cNvPr id=\"2\" name=\"Notes\"/><p:cNvSpPr txBox=\"1\"/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"10\" cy=\"10\"/></a:xfrm></p:spPr>" +
    "<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>Speaker note</a:t></a:r></a:p></p:txBody></p:sp>" +
    "</p:spTree></p:cSld></p:notes>"
  generated_pptx_pkg([
    (
      "[Content_Types].xml",
      minimal_content_types_xml(
        "<Override PartName=\"/ppt/presentation.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\"/>" +
        "<Override PartName=\"/ppt/slides/slide1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>" +
        "<Override PartName=\"/ppt/notesSlides/notesSlide1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.notesSlide+xml\"/>",
      ),
    ),
    (
      "_rels/.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rIdMain\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"ppt/presentation.xml\"/>",
      ),
    ),
    (
      "ppt/presentation.xml", "<?xml version=\"1.0\" encoding=\"UTF-8\"?><p:presentation xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><p:sldIdLst><p:sldId id=\"256\" r:id=\"rId1\"/></p:sldIdLst></p:presentation>",
    ),
    (
      "ppt/_rels/presentation.xml.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide1.xml\"/>",
      ),
    ),
    ("ppt/slides/slide1.xml", slide_xml),
    (
      "ppt/slides/_rels/slide1.xml.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rId5\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"../media/image1.png\"/>" +
        "<Relationship Id=\"rId7\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink\" Target=\"https://example.com\" TargetMode=\"External\"/>" +
        "<Relationship Id=\"rId9\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesSlide\" Target=\"../notesSlides/notesSlide1.xml\"/>",
      ),
    ),
    ("ppt/notesSlides/notesSlide1.xml", notes_xml),
    ("ppt/media/image1.png", "PNG"),
  ])
}

///|
fn validation_pptx_pkg() -> @ox.OoxmlPackage raise {
  let slide_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<p:sld xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" " +
    "xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" " +
    "xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>" +
    "<p:sp><p:nvSpPr><p:cNvPr id=\"2\" name=\"Link\"/><p:cNvSpPr txBox=\"1\"/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"10\" cy=\"10\"/></a:xfrm></p:spPr>" +
    "<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr><a:hlinkClick r:id=\"rIdMissing\"/></a:rPr><a:t>Missing</a:t></a:r></a:p></p:txBody></p:sp>" +
    "<p:pic><p:nvPicPr><p:cNvPr id=\"3\" name=\"Pic\" descr=\"alt\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr><p:blipFill><a:blip r:embed=\"rIdImage\"/></p:blipFill></p:pic>" +
    "</p:spTree></p:cSld></p:sld>"
  generated_pptx_pkg([
    (
      "[Content_Types].xml",
      minimal_content_types_xml(
        "<Override PartName=\"/ppt/presentation.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\"/>" +
        "<Override PartName=\"/ppt/slides/slide1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>",
      ),
    ),
    (
      "_rels/.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rIdMain\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"ppt/presentation.xml\"/>",
      ),
    ),
    (
      "ppt/presentation.xml", "<?xml version=\"1.0\" encoding=\"UTF-8\"?><p:presentation xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><p:sldIdLst><p:sldId id=\"256\" r:id=\"rId1\"/><p:sldId id=\"257\" r:id=\"rId2\" show=\"0\"/></p:sldIdLst></p:presentation>",
    ),
    (
      "ppt/_rels/presentation.xml.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide1.xml\"/>" +
        "<Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/missing.xml\"/>",
      ),
    ),
    ("ppt/slides/slide1.xml", slide_xml),
    (
      "ppt/slides/_rels/slide1.xml.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rIdImage\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"../media/missing.png\"/>",
      ),
    ),
  ])
}

///|
fn chart_pptx_pkg(
  chart_xml : String,
  slide_rels_inner : String,
) -> @ox.OoxmlPackage raise {
  let slide_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<p:sld xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" " +
    "xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\" " +
    "xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" " +
    "xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>" +
    "<p:sp><p:nvSpPr><p:cNvPr id=\"2\" name=\"Chart Title\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"10\" cy=\"10\"/></a:xfrm></p:spPr>" +
    "<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>A chart to test parsing:</a:t></a:r></a:p></p:txBody></p:sp>" +
    "<p:graphicFrame>" +
    "<p:nvGraphicFramePr><p:cNvPr id=\"7\" name=\"Chart Frame\"/></p:nvGraphicFramePr>" +
    "<p:xfrm><a:off x=\"100\" y=\"200\"/><a:ext cx=\"300\" cy=\"200\"/></p:xfrm>" +
    "<a:graphic><a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/chart\">" +
    "<c:chart r:id=\"rIdChart\"/>" +
    "</a:graphicData></a:graphic>" +
    "</p:graphicFrame>" +
    "</p:spTree></p:cSld></p:sld>"
  generated_pptx_pkg([
    (
      "[Content_Types].xml",
      minimal_content_types_xml(
        "<Override PartName=\"/ppt/presentation.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\"/>" +
        "<Override PartName=\"/ppt/slides/slide1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>" +
        "<Override PartName=\"/ppt/charts/chart1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.drawingml.chart+xml\"/>",
      ),
    ),
    (
      "_rels/.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rIdMain\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"ppt/presentation.xml\"/>",
      ),
    ),
    (
      "ppt/presentation.xml", "<?xml version=\"1.0\" encoding=\"UTF-8\"?><p:presentation xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><p:sldIdLst><p:sldId id=\"256\" r:id=\"rId1\"/></p:sldIdLst></p:presentation>",
    ),
    (
      "ppt/_rels/presentation.xml.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide1.xml\"/>",
      ),
    ),
    ("ppt/slides/slide1.xml", slide_xml),
    ("ppt/charts/chart1.xml", chart_xml),
    ("ppt/slides/_rels/slide1.xml.rels", minimal_rels_xml(slide_rels_inner)),
  ])
}

///|
fn single_series_chart_xml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<c:chartSpace xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\" " +
  "xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" " +
  "xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
  "<c:chart><c:title><c:tx><c:rich><a:p><a:r><a:t>Chart UUID</a:t></a:r></a:p></c:rich></c:tx></c:title>" +
  "<c:plotArea><c:barChart><c:ser><c:idx val=\"0\"/><c:order val=\"0\"/>" +
  "<c:tx><c:strRef><c:strCache><c:pt idx=\"0\"><c:v>Series 1</c:v></c:pt></c:strCache></c:strRef></c:tx>" +
  "<c:cat><c:numRef><c:numCache>" +
  "<c:pt idx=\"0\"><c:v>2000</c:v></c:pt><c:pt idx=\"1\"><c:v>2001</c:v></c:pt>" +
  "<c:pt idx=\"2\"><c:v>2002</c:v></c:pt><c:pt idx=\"3\"><c:v>2003</c:v></c:pt>" +
  "</c:numCache></c:numRef></c:cat>" +
  "<c:val><c:numRef><c:numCache>" +
  "<c:pt idx=\"0\"><c:v>4.3</c:v></c:pt><c:pt idx=\"1\"><c:v>2.5</c:v></c:pt>" +
  "<c:pt idx=\"2\"><c:v>3.7</c:v></c:pt><c:pt idx=\"3\"><c:v>6.1</c:v></c:pt>" +
  "</c:numCache></c:numRef></c:val></c:ser></c:barChart></c:plotArea>" +
  "<c:externalData r:id=\"rIdWorkbook\"/></c:chart></c:chartSpace>"
}

///|
fn multi_series_chart_xml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<c:chartSpace xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\" " +
  "xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
  "<c:chart><c:plotArea><c:lineChart>" +
  "<c:ser><c:idx val=\"0\"/><c:order val=\"0\"/><c:tx><c:v>Series 1</c:v></c:tx>" +
  "<c:cat><c:strRef><c:strCache><c:pt idx=\"0\"><c:v>A</c:v></c:pt><c:pt idx=\"1\"><c:v>B</c:v></c:pt></c:strCache></c:strRef></c:cat>" +
  "<c:val><c:numRef><c:numCache><c:pt idx=\"0\"><c:v>1</c:v></c:pt><c:pt idx=\"1\"><c:v>2</c:v></c:pt></c:numCache></c:numRef></c:val></c:ser>" +
  "<c:ser><c:idx val=\"1\"/><c:order val=\"1\"/><c:tx><c:v>Series 2</c:v></c:tx>" +
  "<c:cat><c:strRef><c:strCache><c:pt idx=\"0\"><c:v>A</c:v></c:pt><c:pt idx=\"1\"><c:v>B</c:v></c:pt></c:strCache></c:strRef></c:cat>" +
  "<c:val><c:numRef><c:numCache><c:pt idx=\"0\"><c:v>3</c:v></c:pt><c:pt idx=\"1\"><c:v>4</c:v></c:pt></c:numCache></c:numRef></c:val></c:ser>" +
  "</c:lineChart></c:plotArea></c:chart></c:chartSpace>"
}

///|
fn mismatch_chart_xml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<c:chartSpace xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\">" +
  "<c:chart><c:plotArea><c:barChart><c:ser><c:idx val=\"0\"/><c:order val=\"0\"/><c:tx><c:v>Series 1</c:v></c:tx>" +
  "<c:cat><c:strRef><c:strCache><c:pt idx=\"0\"><c:v>A</c:v></c:pt><c:pt idx=\"1\"><c:v>B</c:v></c:pt></c:strCache></c:strRef></c:cat>" +
  "<c:val><c:numRef><c:numCache><c:pt idx=\"0\"><c:v>9</c:v></c:pt></c:numCache></c:numRef></c:val>" +
  "</c:ser></c:barChart></c:plotArea></c:chart></c:chartSpace>"
}

///|
fn no_cache_chart_xml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<c:chartSpace xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\" " +
  "xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
  "<c:chart><c:plotArea><c:barChart><c:ser><c:idx val=\"0\"/><c:order val=\"0\"/><c:tx><c:v>Series 1</c:v></c:tx>" +
  "<c:cat><c:numRef><c:f>Sheet1!$A$1:$A$2</c:f></c:numRef></c:cat>" +
  "<c:val><c:numRef><c:f>Sheet1!$B$1:$B$2</c:f></c:numRef></c:val>" +
  "</c:ser></c:barChart></c:plotArea><c:externalData r:id=\"rIdWorkbook\"/></c:chart></c:chartSpace>"
}

///|
fn date_category_chart_xml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<c:chartSpace xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\" " +
  "xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\">" +
  "<c:date1904 val=\"0\"/>" +
  "<c:chart><c:title><c:tx><c:rich><a:p><a:r><a:t>On The Radar</a:t></a:r></a:p></c:rich></c:tx></c:title>" +
  "<c:plotArea><c:radarChart>" +
  "<c:ser><c:idx val=\"0\"/><c:order val=\"0\"/><c:tx><c:v>Series 1</c:v></c:tx>" +
  "<c:cat><c:numRef><c:numCache><c:formatCode>m/d/yy</c:formatCode>" +
  "<c:pt idx=\"0\"><c:v>37261.0</c:v></c:pt><c:pt idx=\"1\"><c:v>37262.0</c:v></c:pt>" +
  "<c:pt idx=\"2\"><c:v>37263.0</c:v></c:pt><c:pt idx=\"3\"><c:v>37264.0</c:v></c:pt>" +
  "<c:pt idx=\"4\"><c:v>37265.0</c:v></c:pt></c:numCache></c:numRef></c:cat>" +
  "<c:val><c:numRef><c:numCache><c:pt idx=\"0\"><c:v>32.0</c:v></c:pt><c:pt idx=\"1\"><c:v>32.0</c:v></c:pt>" +
  "<c:pt idx=\"2\"><c:v>28.0</c:v></c:pt><c:pt idx=\"3\"><c:v>12.0</c:v></c:pt><c:pt idx=\"4\"><c:v>15.0</c:v></c:pt>" +
  "</c:numCache></c:numRef></c:val></c:ser></c:radarChart></c:plotArea></c:chart></c:chartSpace>"
}

///|
fn malformed_presentation_pptx_pkg() -> @ox.OoxmlPackage raise {
  generated_pptx_pkg([
    (
      "[Content_Types].xml",
      minimal_content_types_xml(
        "<Override PartName=\"/ppt/presentation.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\"/>",
      ),
    ),
    (
      "_rels/.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rIdMain\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"ppt/presentation.xml\"/>",
      ),
    ),
    ("ppt/presentation.xml", "<?xml version=\"1.0\" encoding=\"UTF-8\"?><bad/>"),
  ])
}

///|
fn malformed_slide_pptx_pkg() -> @ox.OoxmlPackage raise {
  generated_pptx_pkg([
    (
      "[Content_Types].xml",
      minimal_content_types_xml(
        "<Override PartName=\"/ppt/presentation.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\"/>" +
        "<Override PartName=\"/ppt/slides/slide1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>",
      ),
    ),
    (
      "_rels/.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rIdMain\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"ppt/presentation.xml\"/>",
      ),
    ),
    (
      "ppt/presentation.xml", "<?xml version=\"1.0\" encoding=\"UTF-8\"?><p:presentation xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><p:sldIdLst><p:sldId id=\"256\" r:id=\"rId1\"/></p:sldIdLst></p:presentation>",
    ),
    (
      "ppt/_rels/presentation.xml.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide1.xml\"/>",
      ),
    ),
    (
      "ppt/slides/slide1.xml", "<?xml version=\"1.0\" encoding=\"UTF-8\"?><bad/>",
    ),
  ])
}

///|
fn comments_pptx_pkg(
  comments_xml : String,
  slide_rels_inner : String,
  comment_authors_xml : String?,
) -> @ox.OoxmlPackage raise {
  let slide_xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
    "<p:sld xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" " +
    "xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\">" +
    "<p:cSld><p:spTree>" +
    "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
    "<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>" +
    "<p:sp><p:nvSpPr><p:cNvPr id=\"2\" name=\"Title\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>" +
    "<p:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"10\" cy=\"10\"/></a:xfrm></p:spPr>" +
    "<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>Visible Slide Text</a:t></a:r></a:p></p:txBody>" +
    "</p:sp>" +
    "</p:spTree></p:cSld></p:sld>"
  let overrides = if comment_authors_xml == None {
    "<Override PartName=\"/ppt/presentation.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\"/>" +
    "<Override PartName=\"/ppt/slides/slide1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>" +
    "<Override PartName=\"/ppt/comments/comment1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.comments+xml\"/>"
  } else {
    "<Override PartName=\"/ppt/presentation.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\"/>" +
    "<Override PartName=\"/ppt/slides/slide1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>" +
    "<Override PartName=\"/ppt/comments/comment1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.comments+xml\"/>" +
    "<Override PartName=\"/ppt/commentAuthors.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.commentAuthors+xml\"/>"
  }
  let entries : Array[(String, String)] = [
    ("[Content_Types].xml", minimal_content_types_xml(overrides)),
    (
      "_rels/.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rIdMain\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"ppt/presentation.xml\"/>",
      ),
    ),
    (
      "ppt/presentation.xml", "<?xml version=\"1.0\" encoding=\"UTF-8\"?><p:presentation xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><p:sldIdLst><p:sldId id=\"256\" r:id=\"rId1\"/></p:sldIdLst></p:presentation>",
    ),
    (
      "ppt/_rels/presentation.xml.rels",
      minimal_rels_xml(
        "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide1.xml\"/>",
      ),
    ),
    ("ppt/slides/slide1.xml", slide_xml),
    ("ppt/slides/_rels/slide1.xml.rels", minimal_rels_xml(slide_rels_inner)),
    ("ppt/comments/comment1.xml", comments_xml),
  ]
  match comment_authors_xml {
    Some(authors) => entries.push(("ppt/commentAuthors.xml", authors))
    None => ()
  }
  generated_pptx_pkg(entries)
}

///|
fn comment_authors_xml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<p:cmAuthorLst xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\">" +
  "<p:cmAuthor id=\"0\" name=\"Harshal Doshi\" initials=\"HD\" lastIdx=\"2\" clrIdx=\"0\"/>" +
  "</p:cmAuthorLst>"
}

///|
fn comment_list_xml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<p:cmLst xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\">" +
  "<p:cm authorId=\"0\" dt=\"2008-02-01T13:48:50.465\" idx=\"1\"><p:text>PowerPoint Rocks!!!</p:text></p:cm>" +
  "<p:cm authorId=\"0\" dt=\"2008-02-01T13:49:03.280\" idx=\"2\"><p:text>PowerPoint Logo!</p:text></p:cm>" +
  "</p:cmLst>"
}

///|
test "pptx semantic presentation preserves slide order hidden signal hyperlinks notes and media refs" {
  let order_doc = @pptx.open_pptx_presentation(
    resolve_sample_path("samples/main_process/pptx/pptx_slide_order.pptx"),
  )
  assert_true(order_doc.slides.length() > 1)
  assert_eq(order_doc.slides[0].index, 1)
  assert_eq(order_doc.slides[1].index, 2)
  match order_doc.slides[0].relationship_id {
    Some(_rid) => ()
    None => fail("expected slide relationship id")
  }

  let hidden_doc = @pptx.open_pptx_presentation(
    resolve_sample_path(
      "samples/main_process/pptx/pptx_hidden_slide_basic.pptx",
    ),
  )
  let hidden_inspect = @pptx.inspect_pptx_presentation(hidden_doc)
  assert_true(hidden_inspect.hidden_slide_count > 0)

  let link_doc = @pptx.open_pptx_presentation(
    resolve_sample_path("samples/main_process/pptx/pptx_link_in_paragraph.pptx"),
  )
  assert_true(link_doc.hyperlink_refs.length() > 0)
  match link_doc.hyperlink_refs[0].target {
    Some(target) => assert_true(target.contains("https://"))
    None => fail("expected hyperlink target")
  }

  let notes_doc = @pptx.open_pptx_presentation(
    resolve_sample_path(
      "samples/main_process/pptx/pptx_speaker_notes_basic.pptx",
    ),
  )
  let notes_inspect = @pptx.inspect_pptx_presentation(notes_doc)
  assert_true(notes_inspect.notes_count > 0)

  let media_doc = @pptx.open_pptx_presentation(
    resolve_sample_path("samples/main_process/pptx/pptx_image_alt_title.pptx"),
  )
  assert_true(media_doc.media_refs.length() > 0)
  match media_doc.media_refs[0].alt_text {
    Some(alt) => assert_true(alt != "")
    None => fail("expected alt text signal")
  }
  match media_doc.media_refs[0].content_type {
    Some(content_type) => assert_true(content_type.has_prefix("image/"))
    None => fail("expected image content type")
  }
  match media_doc.media_refs[0].target_part {
    Some(target_part) => assert_true(target_part.has_prefix("ppt/media/"))
    None => fail("expected media target part")
  }
}

///|
test "pptx semantic table model preserves rows cells and raw paragraphs" {
  let doc = @pptx.open_pptx_presentation(
    resolve_sample_path(
      "samples/main_process/pptx/pptx_explicit_table_basic.pptx",
    ),
  )
  assert_true(doc.slides.length() > 0)
  assert_true(doc.slides[0].tables.length() > 0)
  let table = doc.slides[0].tables[0]
  assert_eq(table.rows.length(), 3)
  assert_eq(table.rows[0].cells.length(), 3)
  assert_eq(table.rows[0].cells[0].paragraphs[0].runs[0].text, "Quarter")
  let value_cell = table.rows[1].cells[2]
  assert_true(value_cell.paragraphs.length() > 0)
}

///|
test "pptx semantic grouped shape tree preserves nested children object refs and notes" {
  let doc = @pptx.parse_pptx_presentation_from_package(grouped_pptx_pkg())
  assert_eq(doc.slides.length(), 1)
  let slide = doc.slides[0]
  assert_eq(slide.shape_tree.length(), 1)
  let outer = slide.shape_tree[0]
  assert_true(outer.kind == @pptx.PptxShapeKind::Group)
  assert_true(outer.children.length() >= 3)

  let nested_group = outer.children[0]
  assert_true(nested_group.kind == @pptx.PptxShapeKind::Group)
  let nested_text = nested_group.children[0]
  match nested_text.object_ref {
    Some(obj_ref) => assert_eq(obj_ref, "group-20/group-21/shape-22")
    None => fail("expected nested text object_ref")
  }
  assert_eq(nested_text.text_paragraphs[0].runs[0].text, "Nested Text")

  let picture = outer.children[1]
  assert_true(picture.kind == @pptx.PptxShapeKind::Picture)
  match picture.media_ref {
    Some(media) => {
      assert_true(media.kind == @pptx.PptxMediaKind::Image)
      match media.alt_text {
        Some(alt) => assert_eq(alt, "grouped alt")
        None => fail("expected grouped picture alt text")
      }
    }
    None => fail("expected grouped picture media ref")
  }

  let table = outer.children[2]
  assert_true(table.kind == @pptx.PptxShapeKind::Table)
  match table.table {
    Some(tbl) => assert_eq(tbl.rows[0].cells[0].paragraphs[0].runs[0].text, "H")
    None => fail("expected grouped table model")
  }

  let linked_text = outer.children[3]
  assert_true(linked_text.kind == @pptx.PptxShapeKind::TextBox)
  assert_eq(linked_text.text_paragraphs[0].runs[0].text, "Visit")
  match linked_text.hyperlink_refs[0].target {
    Some(target) => assert_eq(target, "https://example.com")
    None => fail("expected linked text target")
  }

  match slide.notes {
    Some(notes) => assert_eq(notes.paragraphs[0].runs[0].text, "Speaker note")
    None => fail("expected speaker notes")
  }

  let inspect = @pptx.inspect_pptx_presentation(doc)
  assert_eq(inspect.slide_count, 1)
  assert_eq(inspect.group_shape_count, 2)
  assert_eq(inspect.table_count, 1)
  assert_eq(inspect.notes_count, 1)
  assert_eq(inspect.media_ref_count, 1)
  assert_eq(inspect.hyperlink_count, 1)
}

///|
test "pptx semantic comment authors and slide comments preserve author mapping and order" {
  let doc = @pptx.parse_pptx_presentation_from_package(
    comments_pptx_pkg(
      comment_list_xml(),
      "<Relationship Id=\"rIdComment\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments\" Target=\"../comments/comment1.xml\"/>",
      Some(comment_authors_xml()),
    ),
  )
  assert_eq(doc.comment_authors.length(), 1)
  assert_eq(doc.comment_authors[0].id, "0")
  assert_eq(doc.comment_authors[0].name, "Harshal Doshi")
  let slide = doc.slides[0]
  assert_eq(slide.comments.length(), 2)
  assert_eq(slide.comments[0].author_id, "0")
  match slide.comments[0].author_name {
    Some(name) => assert_eq(name, "Harshal Doshi")
    None => fail("expected author name")
  }
  assert_eq(slide.comments[0].text, "PowerPoint Rocks!!!")
  assert_eq(slide.comments[1].text, "PowerPoint Logo!")
  let inspect = @pptx.inspect_pptx_presentation(doc)
  assert_eq(inspect.comment_count, 2)
}

///|
test "pptx semantic comments fall back when commentAuthors part is missing" {
  let doc = @pptx.parse_pptx_presentation_from_package(
    comments_pptx_pkg(
      comment_list_xml(),
      "<Relationship Id=\"rIdComment\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments\" Target=\"../comments/comment1.xml\"/>",
      None,
    ),
  )
  let slide = doc.slides[0]
  assert_eq(slide.comments.length(), 2)
  match slide.comments[0].author_name {
    Some(_) => fail("expected missing author name fallback")
    None => ()
  }
  assert_eq(slide.comments[0].author_id, "0")
}

///|
test "pptx semantic comments missing relationship keep existing behavior unchanged" {
  let doc = @pptx.parse_pptx_presentation_from_package(
    comments_pptx_pkg(comment_list_xml(), "", Some(comment_authors_xml())),
  )
  assert_eq(doc.slides[0].comments.length(), 0)
}

///|
test "pptx semantic comments missing part does not crash" {
  let doc = @pptx.parse_pptx_presentation_from_package(
    generated_pptx_pkg([
      (
        "[Content_Types].xml",
        minimal_content_types_xml(
          "<Override PartName=\"/ppt/presentation.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\"/>" +
          "<Override PartName=\"/ppt/slides/slide1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>",
        ),
      ),
      (
        "_rels/.rels",
        minimal_rels_xml(
          "<Relationship Id=\"rIdMain\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"ppt/presentation.xml\"/>",
        ),
      ),
      (
        "ppt/presentation.xml", "<?xml version=\"1.0\" encoding=\"UTF-8\"?><p:presentation xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><p:sldIdLst><p:sldId id=\"256\" r:id=\"rId1\"/></p:sldIdLst></p:presentation>",
      ),
      (
        "ppt/_rels/presentation.xml.rels",
        minimal_rels_xml(
          "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide1.xml\"/>",
        ),
      ),
      (
        "ppt/slides/slide1.xml", "<?xml version=\"1.0\" encoding=\"UTF-8\"?><p:sld xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\"><p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr><p:sp><p:nvSpPr><p:cNvPr id=\"2\" name=\"Title\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"10\" cy=\"10\"/></a:xfrm></p:spPr><p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>Visible Slide Text</a:t></a:r></a:p></p:txBody></p:sp></p:spTree></p:cSld></p:sld>",
      ),
      (
        "ppt/slides/_rels/slide1.xml.rels",
        minimal_rels_xml(
          "<Relationship Id=\"rIdComment\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments\" Target=\"../comments/comment1.xml\"/>",
        ),
      ),
      ("ppt/commentAuthors.xml", comment_authors_xml()),
    ]),
  )
  assert_eq(doc.slides[0].comments.length(), 0)
  let issues = @pptx.collect_pptx_validation_issues(doc)
  assert_true(issues.length() > 0)
}

///|
test "pptx semantic chart cache preserves single-series data" {
  let doc = @pptx.parse_pptx_presentation_from_package(
    chart_pptx_pkg(
      single_series_chart_xml(),
      "<Relationship Id=\"rIdChart\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart\" Target=\"../charts/chart1.xml\"/>",
    ),
  )
  let slide = doc.slides[0]
  assert_eq(slide.shape_tree.length(), 2)
  let chart = slide.shape_tree[1]
  assert_true(chart.kind == @pptx.PptxShapeKind::Chart)
  match chart.chart {
    Some(data) => {
      assert_eq(data.source_part, "ppt/charts/chart1.xml")
      assert_true(data.has_external_data)
      assert_eq(data.series.length(), 1)
      assert_eq(data.series[0].name, "Series 1")
      assert_eq(data.series[0].categories[0], "2000")
      assert_eq(data.series[0].values[3], "6.1")
    }
    None => fail("expected chart data")
  }
  let inspect = @pptx.inspect_pptx_presentation(doc)
  assert_eq(inspect.chart_count, 1)
}

///|
test "pptx semantic chart cache formats date-like category serials and keeps titles" {
  let doc = @pptx.parse_pptx_presentation_from_package(
    chart_pptx_pkg(
      date_category_chart_xml(),
      "<Relationship Id=\"rIdChart\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart\" Target=\"../charts/chart1.xml\"/>",
    ),
  )
  let chart = doc.slides[0].shape_tree[1]
  match chart.chart {
    Some(data) => {
      match data.title {
        Some("On The Radar") => ()
        _ => fail("expected chart title to stay available")
      }
      assert_true(
        data.series[0].categories ==
        ["2002-01-05", "2002-01-06", "2002-01-07", "2002-01-08", "2002-01-09"],
      )
    }
    None => fail("expected chart data")
  }
}

///|
test "pptx semantic chart cache preserves multiple aligned series" {
  let doc = @pptx.parse_pptx_presentation_from_package(
    chart_pptx_pkg(
      multi_series_chart_xml(),
      "<Relationship Id=\"rIdChart\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart\" Target=\"../charts/chart1.xml\"/>",
    ),
  )
  let chart = doc.slides[0].shape_tree[1]
  match chart.chart {
    Some(data) => {
      assert_eq(data.series.length(), 2)
      assert_true(data.series[0].categories == ["A", "B"])
      assert_true(data.series[1].values == ["3", "4"])
    }
    None => fail("expected chart data")
  }
}

///|
test "pptx semantic chart cache preserves mismatch without crashing" {
  let doc = @pptx.parse_pptx_presentation_from_package(
    chart_pptx_pkg(
      mismatch_chart_xml(),
      "<Relationship Id=\"rIdChart\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart\" Target=\"../charts/chart1.xml\"/>",
    ),
  )
  let chart = doc.slides[0].shape_tree[1]
  match chart.chart {
    Some(data) => {
      assert_eq(data.series.length(), 1)
      assert_eq(data.series[0].categories.length(), 2)
      assert_eq(data.series[0].values.length(), 1)
    }
    None => fail("expected chart data")
  }
}

///|
test "pptx semantic chart externalData without cache stays non-crashing" {
  let doc = @pptx.parse_pptx_presentation_from_package(
    chart_pptx_pkg(
      no_cache_chart_xml(),
      "<Relationship Id=\"rIdChart\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart\" Target=\"../charts/chart1.xml\"/>",
    ),
  )
  let chart = doc.slides[0].shape_tree[1]
  match chart.chart {
    Some(data) => {
      assert_true(data.has_external_data)
      assert_eq(data.series.length(), 1)
      assert_eq(data.series[0].categories.length(), 0)
      assert_eq(data.series[0].values.length(), 0)
    }
    None => fail("expected chart data")
  }
}

///|
test "pptx semantic chart missing relationship remains unknown" {
  let doc = @pptx.parse_pptx_presentation_from_package(
    chart_pptx_pkg(single_series_chart_xml(), ""),
  )
  let chart = doc.slides[0].shape_tree[1]
  assert_true(chart.kind == @pptx.PptxShapeKind::Unknown)
  match chart.chart {
    None => ()
    Some(_) => fail("expected no chart data")
  }
}

///|
test "pptx semantic parse facade from package matches direct open and inspect counts stay stable" {
  let path = "samples/main_process/pptx/pptx_simple.pptx"
  let opened = @pptx.open_pptx_presentation(resolve_sample_path(path))
  let parsed = @pptx.parse_pptx_presentation_from_package(
    open_sample_package(path),
  )

  let opened_inspect = @pptx.inspect_pptx_presentation(opened)
  let parsed_inspect = @pptx.inspect_pptx_presentation(parsed)
  let opened_issues = @pptx.collect_pptx_validation_issues(opened)
  let parsed_issues = @pptx.collect_pptx_validation_issues(parsed)
  let opened_report = @pptx.validate_pptx_presentation(opened)
  let parsed_report = @pptx.validate_pptx_presentation(parsed)
  assert_eq(opened_inspect.slide_count, parsed_inspect.slide_count)
  assert_eq(opened_inspect.paragraph_count, parsed_inspect.paragraph_count)
  assert_eq(opened_inspect.hyperlink_count, parsed_inspect.hyperlink_count)
  assert_eq(opened_issues.length(), opened_report.issue_count)
  assert_eq(parsed_issues.length(), parsed_report.issue_count)
  let error_info = @pptx.classify_pptx_error(
    @pptx.PptxError::OpenFailed("missing.pptx: not found"),
  )
  assert_true(error_info.kind == @pptx.PptxErrorKind::OpenFailed)
}

///|
test "pptx semantic validation reports missing slide relationship and media gaps deterministically" {
  let pres = @pptx.parse_pptx_presentation_from_package(validation_pptx_pkg())
  let issues = @pptx.collect_pptx_validation_issues(pres)
  let report = @pptx.validate_pptx_presentation(pres)

  assert_eq(issues.length(), report.issue_count)
  assert_eq(issues.length(), 3)
  assert_true(
    issues[0].kind == @pptx.PptxValidationIssueKind::MissingRelationshipTarget,
  )
  match issues[0].relationship_id {
    Some(rid) => assert_eq(rid, "rIdMissing")
    None => fail("expected missing hyperlink relationship id")
  }
  assert_true(issues[1].kind == @pptx.PptxValidationIssueKind::MissingMediaPart)
  match issues[1].relationship_id {
    Some(rid) => assert_eq(rid, "rIdImage")
    None => fail("expected missing media relationship id")
  }
  assert_true(issues[2].kind == @pptx.PptxValidationIssueKind::MissingSlidePart)
  match issues[2].relationship_id {
    Some(rid) => assert_eq(rid, "rId2")
    None => fail("expected missing slide relationship id")
  }
  match issues[2].part_path {
    Some(part_path) => assert_eq(part_path, "ppt/slides/missing.xml")
    None => fail("expected missing slide part path")
  }

  let inspect = @pptx.inspect_pptx_presentation(pres)
  assert_eq(inspect.issue_count, report.issue_count)
  assert_eq(inspect.warning_count, report.warning_count)
  assert_eq(inspect.error_count, report.error_count)
}

///|
test "pptx semantic classifier recognizes malformed presentation and slide xml" {
  let bad_pres = try? @pptx.parse_pptx_presentation_from_package(
    malformed_presentation_pptx_pkg(),
  )
  assert_true(bad_pres is Err(_))

  let bad_slide = try? @pptx.parse_pptx_presentation_from_package(
    malformed_slide_pptx_pkg(),
  )
  assert_true(bad_slide is Err(_))

  let pres_info = @pptx.classify_pptx_error(
    @pptx.PptxError::ParseError(
      "malformed presentation xml: missing <p:presentation>",
    ),
  )
  assert_true(pres_info.kind == @pptx.PptxErrorKind::MalformedPresentationXml)

  let slide_info = @pptx.classify_pptx_error(
    @pptx.PptxError::ParseError("malformed slide xml: missing <p:sld>"),
  )
  assert_true(slide_info.kind == @pptx.PptxErrorKind::MalformedSlideXml)
}
