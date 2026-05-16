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
  ensure_dir_tree(path)
}

///|
fn cleanup_temp_dir(path : String) -> Unit {
  ignore(try? remove_dir_recursive(path))
}

///|
fn test_tmp_root() -> String {
  ".tmp/convert-pptx-test"
}

///|
fn write_bytes(path : String, bytes : Bytes) -> Unit raise {
  @fs.write_bytes_to_file(path, bytes) catch {
    e => fail("write sample failed: " + e.to_string())
  }
}

///|
fn minimal_content_types_xml(overrides : String) -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">" +
  "<Default Extension=\"xml\" ContentType=\"application/xml\"/>" +
  "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>" +
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
fn chart_pptx_bytes(chart_xml : String, slide_rels_inner : String) -> Bytes {
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
  build_store_zip([
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
    ("ppt/slides/_rels/slide1.xml.rels", minimal_rels_xml(slide_rels_inner)),
    ("ppt/charts/chart1.xml", chart_xml),
  ])
}

///|
fn single_series_chart_xml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<c:chartSpace xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\" xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" +
  "<c:chart><c:plotArea><c:barChart>" +
  "<c:ser><c:idx val=\"0\"/><c:order val=\"0\"/>" +
  "<c:tx><c:strRef><c:strCache><c:pt idx=\"0\"><c:v>Series 1</c:v></c:pt></c:strCache></c:strRef></c:tx>" +
  "<c:cat><c:strRef><c:strCache>" +
  "<c:pt idx=\"0\"><c:v>2000</c:v></c:pt>" +
  "<c:pt idx=\"1\"><c:v>2001</c:v></c:pt>" +
  "<c:pt idx=\"2\"><c:v>2002</c:v></c:pt>" +
  "<c:pt idx=\"3\"><c:v>2003</c:v></c:pt>" +
  "</c:strCache></c:strRef></c:cat>" +
  "<c:val><c:numRef><c:numCache>" +
  "<c:pt idx=\"0\"><c:v>4.3</c:v></c:pt>" +
  "<c:pt idx=\"1\"><c:v>2.5</c:v></c:pt>" +
  "<c:pt idx=\"2\"><c:v>3.5</c:v></c:pt>" +
  "<c:pt idx=\"3\"><c:v>4.5</c:v></c:pt>" +
  "</c:numCache></c:numRef></c:val>" +
  "</c:ser></c:barChart></c:plotArea></c:chart>" +
  "<c:externalData r:id=\"rIdWorkbook\"/>" +
  "</c:chartSpace>"
}

///|
fn mismatch_chart_xml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<c:chartSpace xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\" xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\">" +
  "<c:chart><c:plotArea><c:lineChart>" +
  "<c:ser><c:idx val=\"0\"/><c:order val=\"0\"/>" +
  "<c:tx><c:v>Series 1</c:v></c:tx>" +
  "<c:cat><c:strRef><c:strCache>" +
  "<c:pt idx=\"0\"><c:v>A</c:v></c:pt>" +
  "<c:pt idx=\"1\"><c:v>B</c:v></c:pt>" +
  "</c:strCache></c:strRef></c:cat>" +
  "<c:val><c:numRef><c:numCache>" +
  "<c:pt idx=\"0\"><c:v>1</c:v></c:pt>" +
  "</c:numCache></c:numRef></c:val>" +
  "</c:ser></c:lineChart></c:plotArea></c:chart>" +
  "</c:chartSpace>"
}

///|
fn titled_date_chart_xml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<c:chartSpace xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\" xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\">" +
  "<c:date1904 val=\"0\"/>" +
  "<c:chart><c:title><c:tx><c:rich><a:p><a:r><a:t>On The Radar</a:t></a:r></a:p></c:rich></c:tx></c:title><c:plotArea><c:radarChart>" +
  "<c:ser><c:idx val=\"0\"/><c:order val=\"0\"/><c:tx><c:v>Series 1</c:v></c:tx>" +
  "<c:cat><c:numRef><c:numCache><c:formatCode>m/d/yy</c:formatCode>" +
  "<c:pt idx=\"0\"><c:v>37261.0</c:v></c:pt>" +
  "<c:pt idx=\"1\"><c:v>37262.0</c:v></c:pt>" +
  "<c:pt idx=\"2\"><c:v>37263.0</c:v></c:pt>" +
  "<c:pt idx=\"3\"><c:v>37264.0</c:v></c:pt>" +
  "<c:pt idx=\"4\"><c:v>37265.0</c:v></c:pt>" +
  "</c:numCache></c:numRef></c:cat>" +
  "<c:val><c:numRef><c:numCache>" +
  "<c:pt idx=\"0\"><c:v>32.0</c:v></c:pt>" +
  "<c:pt idx=\"1\"><c:v>32.0</c:v></c:pt>" +
  "<c:pt idx=\"2\"><c:v>28.0</c:v></c:pt>" +
  "<c:pt idx=\"3\"><c:v>12.0</c:v></c:pt>" +
  "<c:pt idx=\"4\"><c:v>15.0</c:v></c:pt>" +
  "</c:numCache></c:numRef></c:val></c:ser></c:radarChart></c:plotArea></c:chart></c:chartSpace>"
}

///|
fn comments_pptx_bytes(
  comments_xml : String,
  slide_rels_inner : String,
  comment_authors_xml : String?,
  notes_xml : String?,
) -> Bytes {
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
  let overrides = if notes_xml == None {
    if comment_authors_xml == None {
      "<Override PartName=\"/ppt/presentation.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\"/>" +
      "<Override PartName=\"/ppt/slides/slide1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>" +
      "<Override PartName=\"/ppt/comments/comment1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.comments+xml\"/>"
    } else {
      "<Override PartName=\"/ppt/presentation.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\"/>" +
      "<Override PartName=\"/ppt/slides/slide1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>" +
      "<Override PartName=\"/ppt/comments/comment1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.comments+xml\"/>" +
      "<Override PartName=\"/ppt/commentAuthors.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.commentAuthors+xml\"/>"
    }
  } else {
    "<Override PartName=\"/ppt/presentation.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\"/>" +
    "<Override PartName=\"/ppt/slides/slide1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>" +
    "<Override PartName=\"/ppt/comments/comment1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.comments+xml\"/>" +
    "<Override PartName=\"/ppt/commentAuthors.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.commentAuthors+xml\"/>" +
    "<Override PartName=\"/ppt/notesSlides/notesSlide1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.notesSlide+xml\"/>"
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
  match notes_xml {
    Some(notes) => entries.push(("ppt/notesSlides/notesSlide1.xml", notes))
    None => ()
  }
  build_store_zip(entries)
}

///|
fn comment_authors_xml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<p:cmAuthorLst xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\">" +
  "<p:cmAuthor id=\"0\" name=\"Harshal Doshi\" initials=\"HD\"/>" +
  "</p:cmAuthorLst>"
}

///|
fn comment_list_xml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<p:cmLst xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\">" +
  "<p:cm authorId=\"0\" idx=\"1\"><p:text>PowerPoint Rocks!!!</p:text></p:cm>" +
  "<p:cm authorId=\"0\" idx=\"2\"><p:text>PowerPoint Logo!</p:text></p:cm>" +
  "</p:cmLst>"
}

///|
fn note_slide_xml() -> String {
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" +
  "<p:notes xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\">" +
  "<p:cSld><p:spTree>" +
  "<p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>" +
  "<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>" +
  "<p:sp><p:nvSpPr><p:cNvPr id=\"2\" name=\"Notes\"/><p:cNvSpPr txBox=\"1\"/><p:nvPr/></p:nvSpPr>" +
  "<p:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"10\" cy=\"10\"/></a:xfrm></p:spPr>" +
  "<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>Speaker note body</a:t></a:r></a:p></p:txBody>" +
  "</p:sp>" +
  "</p:spTree></p:cSld></p:notes>"
}

///|
test "pptx baseline samples keep existing body extraction stable" {
  let doc = @pptx.parse_pptx(
    resolve_sample_path("samples/main_process/pptx/pptx_simple.pptx"),
    "",
    6,
  )
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("## Slide 1"))
  assert_true(markdown.contains("PPTX MVP 测试"))
  assert_true(markdown.contains("- 项目符号 1"))
  assert_true(markdown.contains("## Slide 2"))
  assert_true(markdown.contains("第二页标题：Data Overview"))
}

///|
test "pptx notes are emitted under owning slide" {
  let doc = @pptx.parse_pptx(
    resolve_sample_path(
      "samples/main_process/pptx/pptx_speaker_notes_basic.pptx",
    ),
    "",
    6,
  )
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("### Speaker Notes"))
  assert_true(markdown.contains("本页核心信息"))
  assert_true(markdown.contains("第二页备注"))
  assert_true(markdown.contains("最后页备注"))
}

///|
test "pptx hidden slides are preserved with marker" {
  let doc = @pptx.parse_pptx(
    resolve_sample_path(
      "samples/main_process/pptx/pptx_hidden_slide_basic.pptx",
    ),
    "",
    6,
  )
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("## Slide 1"))
  assert_true(markdown.contains("## Slide 2 (hidden)"))
  assert_true(markdown.contains("### First"))
}

///|
test "pptx explicit tables emit RichTable when present" {
  let doc = @pptx.parse_pptx(
    resolve_sample_path(
      "samples/main_process/pptx/pptx_explicit_table_basic.pptx",
    ),
    "",
    6,
  )
  let mut saw_table = false
  for block in doc.blocks.val {
    match block {
      @cor.Block::RichTable(table) => {
        saw_table = true
        assert_eq(table.header_rows, 1)
        assert_true(table.rows[0] == ["Quarter", "Revenue", "Profit"])
      }
      _ => ()
    }
  }
  if !saw_table {
    fail("pptx explicit table sample should emit RichTable")
  }
}

///|
test "pptx grouped text sample preserves nested grouped text in stable order" {
  let doc = @pptx.parse_pptx(
    resolve_sample_path(
      "samples/main_process/pptx/pptx_small_grouped_notes.pptx",
    ),
    "",
    6,
  )
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("## Slide 1"))
  assert_true(markdown.contains("### Highlights"))
  assert_true(markdown.contains("Item A"))
  assert_true(markdown.contains("Item B"))
  assert_true(markdown.contains("Item C"))
  assert_true(markdown.contains("Main paragraph"))
  assert_true(markdown.contains("Item A\n\nItem B\n\nItem C\n\nMain paragraph"))
}

///|
test "pptx footer page number sample keeps body text and drops page number noise" {
  let doc = @pptx.parse_pptx(
    resolve_sample_path(
      "samples/main_process/pptx/pptx_footer_page_number.pptx",
    ),
    "",
    6,
  )
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("### Report Summary"))
  assert_true(markdown.contains("Main content"))
  assert_true(!markdown.contains("\n\n1\n\n"))
}

///|
test "pptx cached chart data lowers to markdown table when categories align" {
  let root = test_tmp_root()
  ensure_dir_tree(root)
  let case_dir = root + "/chart-single-series"
  recreate_clean_dir(case_dir)
  defer cleanup_temp_dir(case_dir)
  let path = case_dir + "/sample.pptx"
  write_bytes(
    path,
    chart_pptx_bytes(
      single_series_chart_xml(),
      "<Relationship Id=\"rIdChart\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart\" Target=\"../charts/chart1.xml\"/>",
    ),
  )

  let doc = @pptx.parse_pptx(path, "", 6)
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("A chart to test parsing:"))
  assert_true(markdown.contains("| Category | Series 1 |"))
  assert_true(markdown.contains("| 2000 | 4.3 |"))
  assert_true(markdown.contains("| 2003 | 4.5 |"))
}

///|
test "pptx cached chart mismatch falls back to stable text instead of crashing" {
  let root = test_tmp_root()
  ensure_dir_tree(root)
  let case_dir = root + "/chart-mismatch-fallback"
  recreate_clean_dir(case_dir)
  defer cleanup_temp_dir(case_dir)
  let path = case_dir + "/sample.pptx"
  write_bytes(
    path,
    chart_pptx_bytes(
      mismatch_chart_xml(),
      "<Relationship Id=\"rIdChart\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart\" Target=\"../charts/chart1.xml\"/>",
    ),
  )

  let doc = @pptx.parse_pptx(path, "", 6)
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("A chart to test parsing:"))
  assert_true(markdown.contains("Chart<br>Series: Series 1<br>A: 1"))
  assert_true(!markdown.contains("| Category | Series 1 |"))
}

///|
test "pptx cached chart rendering keeps chart title and readable date categories" {
  let root = test_tmp_root()
  ensure_dir_tree(root)
  let case_dir = root + "/chart-title-date"
  recreate_clean_dir(case_dir)
  defer cleanup_temp_dir(case_dir)
  let path = case_dir + "/sample.pptx"
  write_bytes(
    path,
    chart_pptx_bytes(
      titled_date_chart_xml(),
      "<Relationship Id=\"rIdChart\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart\" Target=\"../charts/chart1.xml\"/>",
    ),
  )

  let doc = @pptx.parse_pptx(path, "", 6)
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("A chart to test parsing:"))
  assert_true(markdown.contains("On The Radar"))
  assert_true(markdown.contains("| 2002-01-05 | 32.0 |"))
  assert_true(markdown.contains("| 2002-01-09 | 15.0 |"))
}

///|
test "pptx comments emit stable appendix with author and text" {
  let root = test_tmp_root()
  ensure_dir_tree(root)
  let case_dir = root + "/comments-basic"
  recreate_clean_dir(case_dir)
  defer cleanup_temp_dir(case_dir)
  let path = case_dir + "/sample.pptx"
  write_bytes(
    path,
    comments_pptx_bytes(
      comment_list_xml(),
      "<Relationship Id=\"rIdComment\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments\" Target=\"../comments/comment1.xml\"/>",
      Some(comment_authors_xml()),
      None,
    ),
  )

  let doc = @pptx.parse_pptx(path, "", 6)
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("### Comments"))
  assert_true(markdown.contains("Harshal Doshi: PowerPoint Rocks!!!"))
  assert_true(markdown.contains("Harshal Doshi: PowerPoint Logo!"))
}

///|
test "pptx comments preserve order and stay before speaker notes" {
  let root = test_tmp_root()
  ensure_dir_tree(root)
  let case_dir = root + "/comments-and-notes"
  recreate_clean_dir(case_dir)
  defer cleanup_temp_dir(case_dir)
  let path = case_dir + "/sample.pptx"
  write_bytes(
    path,
    comments_pptx_bytes(
      comment_list_xml(),
      "<Relationship Id=\"rIdComment\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments\" Target=\"../comments/comment1.xml\"/>" +
      "<Relationship Id=\"rIdNotes\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesSlide\" Target=\"../notesSlides/notesSlide1.xml\"/>",
      Some(comment_authors_xml()),
      Some(note_slide_xml()),
    ),
  )

  let doc = @pptx.parse_pptx(path, "", 6)
  let markdown = @cor.emit_markdown(doc)
  assert_true(
    markdown.contains(
      "### Comments\n\n- Harshal Doshi: PowerPoint Rocks!!!\n- Harshal Doshi: PowerPoint Logo!\n\n### Speaker Notes",
    ),
  )
  assert_true(markdown.contains("Harshal Doshi: PowerPoint Rocks!!!"))
  assert_true(markdown.contains("Speaker note body"))
}
