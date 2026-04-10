///|
fn zpad(n : Int, width : Int) -> String {
  let s = n.to_string()
  let mut out = s
  while out.length() < width {
    out = "0" + out
  }
  out
}

///|
fn byte_len(s : String) -> Int {
  @utf8.encode(s).length()
}

///|
fn build_min_pdf() -> Bytes {
  build_pdf_with_contents("4 0 R", [
    "BT\n/F1 12 Tf\n72 120 Td\n(Hello PDF) Tj\nET\n",
  ])
}

///|
fn build_pdf_with_contents(
  contents_ref : String,
  stream_datas : Array[String],
) -> Bytes {
  let chunks : Array[String] = []
  let offsets : Array[Int] = []
  let mut cur = 0

  let add = fn(s : String) {
    chunks.push(s)
    cur = cur + byte_len(s)
  }

  let add_obj = fn(obj_src : String) {
    offsets.push(cur)
    add(obj_src)
  }

  add("%PDF-1.4\n")

  let font_obj_num = 4 + stream_datas.length()

  // 1 0 obj: catalog
  add_obj("1 0 obj\n" + "<< /Type /Catalog /Pages 2 0 R >>\n" + "endobj\n")

  // 2 0 obj: pages
  add_obj(
    "2 0 obj\n" + "<< /Type /Pages /Kids [3 0 R] /Count 1 >>\n" + "endobj\n",
  )

  // 3 0 obj: page
  add_obj(
    "3 0 obj\n" +
    "<< /Type /Page\n" +
    "   /Parent 2 0 R\n" +
    "   /MediaBox [0 0 200 200]\n" +
    "   /Resources << /Font << /F1 " +
    font_obj_num.to_string() +
    " 0 R >> >>\n" +
    "   /Contents " +
    contents_ref +
    "\n" +
    ">>\n" +
    "endobj\n",
  )

  // 4..N obj: content streams
  let mut obj_num = 4
  for stream_data in stream_datas {
    let stream_len = byte_len(stream_data)
    add_obj(
      obj_num.to_string() +
      " 0 obj\n" +
      "<< /Length " +
      stream_len.to_string() +
      " >>\n" +
      "stream\n" +
      stream_data +
      "endstream\n" +
      "endobj\n",
    )
    obj_num = obj_num + 1
  }

  // N+1 0 obj: font
  add_obj(
    font_obj_num.to_string() +
    " 0 obj\n" +
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\n" +
    "endobj\n",
  )

  let xref_offset = cur
  add("xref\n")
  let total_objects = font_obj_num
  add("0 " + (total_objects + 1).to_string() + "\n")
  add("0000000000 65535 f \n")
  for off in offsets {
    add(zpad(off, 10) + " 00000 n \n")
  }

  add("trailer\n")
  add("<< /Size " + (total_objects + 1).to_string() + " /Root 1 0 R >>\n")
  add("startxref\n")
  add(xref_offset.to_string() + "\n")
  add("%%EOF\n")

  @utf8.encode(chunks.join(""))
}

///|
fn build_pdf_with_inherited_resources_page() -> Bytes {
  let chunks : Array[String] = []
  let offsets : Array[Int] = []
  let mut cur = 0
  let add = fn(s : String) {
    chunks.push(s)
    cur = cur + byte_len(s)
  }
  let add_obj = fn(s : String) {
    offsets.push(cur)
    add(s)
  }

  add("%PDF-1.4\n")
  add_obj("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
  add_obj(
    "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 /Resources << /Font << /F1 5 0 R >> >> >>\nendobj\n",
  )
  add_obj(
    "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Contents 4 0 R >>\nendobj\n",
  )
  let stream_data = "BT\n/F1 12 Tf\n(Hello Inherited) Tj\nET\n"
  add_obj(
    "4 0 obj\n<< /Length " +
    byte_len(stream_data).to_string() +
    " >>\nstream\n" +
    stream_data +
    "endstream\nendobj\n",
  )
  add_obj(
    "5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n",
  )

  let xref_offset = cur
  add("xref\n0 6\n0000000000 65535 f \n")
  for off in offsets {
    add(zpad(off, 10) + " 00000 n \n")
  }
  add(
    "trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n" +
    xref_offset.to_string() +
    "\n%%EOF\n",
  )
  @utf8.encode(chunks.join(""))
}

///|
fn build_pdf_with_indirect_length() -> Bytes {
  let chunks : Array[String] = []
  let offsets : Array[Int] = []
  let mut cur = 0
  let add = fn(s : String) {
    chunks.push(s)
    cur = cur + byte_len(s)
  }
  let add_obj = fn(s : String) {
    offsets.push(cur)
    add(s)
  }
  let stream_data = "BT\n(Hello LenRef) Tj\nET\n"

  add("%PDF-1.4\n")
  add_obj("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
  add_obj("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")
  add_obj(
    "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Resources << /Font << /F1 6 0 R >> >> /Contents 4 0 R >>\nendobj\n",
  )
  add_obj(
    "4 0 obj\n<< /Length 5 0 R >>\nstream\n" +
    stream_data +
    "endstream\nendobj\n",
  )
  add_obj("5 0 obj\n" + byte_len(stream_data).to_string() + "\nendobj\n")
  add_obj(
    "6 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n",
  )
  let xref_offset = cur
  add("xref\n0 7\n0000000000 65535 f \n")
  for off in offsets {
    add(zpad(off, 10) + " 00000 n \n")
  }
  add(
    "trailer\n<< /Size 7 /Root 1 0 R >>\nstartxref\n" +
    xref_offset.to_string() +
    "\n%%EOF\n",
  )
  @utf8.encode(chunks.join(""))
}

///|
fn build_pdf_with_two_fonts(stream_data : String) -> Bytes {
  let chunks : Array[String] = []
  let offsets : Array[Int] = []
  let mut cur = 0
  let add = fn(s : String) {
    chunks.push(s)
    cur = cur + byte_len(s)
  }
  let add_obj = fn(s : String) {
    offsets.push(cur)
    add(s)
  }

  add("%PDF-1.4\n")
  add_obj("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
  add_obj("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")
  add_obj(
    "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> /Contents 4 0 R >>\nendobj\n",
  )
  add_obj(
    "4 0 obj\n<< /Length " +
    byte_len(stream_data).to_string() +
    " >>\nstream\n" +
    stream_data +
    "endstream\nendobj\n",
  )
  add_obj("5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n")
  add_obj("6 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>\nendobj\n")
  let xref_offset = cur
  add("xref\n0 7\n0000000000 65535 f \n")
  for off in offsets {
    add(zpad(off, 10) + " 00000 n \n")
  }
  add(
    "trailer\n<< /Size 7 /Root 1 0 R >>\nstartxref\n" +
    xref_offset.to_string() +
    "\n%%EOF\n",
  )
  @utf8.encode(chunks.join(""))
}

///|
test "pdf phase1 can open find pages and read content stream" {
  let bs = build_min_pdf()
  let doc = @pdfc.open_pdf(bs)

  inspect(@pdfc.pdf_version(doc), content="1.4")
  assert_eq(@pdfc.count_pages(doc), 1)

  let pages = @pdfc.list_page_refs(doc)
  assert_eq(pages.length(), 1)

  let (page_obj, page_gen) = pages[0]
  assert_eq(page_obj, 3)
  assert_eq(page_gen, 0)

  let streams = @pdfc.get_page_content_stream_bytes(doc, page_obj, page_gen)
  assert_eq(streams.length(), 1)

  let stream_text = @cor.utf8_bytes_to_string(streams[0])
  assert_eq(stream_text.contains("Hello PDF"), true)

  let obj4 = @pdfc.get_indirect_object(doc, 4, 0)
  let obj4_stream = match obj4.stream {
    Some(bs) => bs
    None => Bytes::default()
  }
  let obj4_text = @cor.utf8_bytes_to_string(obj4_stream)
  assert_eq(obj4_text.contains("Hello PDF"), true)
}

///|
test "pdf phase2 can extract plain text from content stream" {
  let bs = build_min_pdf()
  let doc = @pdfc.open_pdf(bs)
  let pages = @pdfc.list_page_refs(doc)
  let (page_obj, page_gen) = pages[0]
  let streams = @pdfc.get_page_content_stream_bytes(doc, page_obj, page_gen)

  let text = @pdfc.extract_plain_text_from_page_stream(streams[0])
  assert_eq(text, "Hello PDF")

  let ops = @pdfc.extract_text_ops_from_page_stream(streams[0])
  assert_eq(ops.length() >= 3, true)
}

///|
test "pdf phase2.5 parse escaped and nested string literal in Tj" {
  let stream = @utf8.encode(
    "BT\n(Hello \\(PDF\\) \\(v1\\)\\040OK) Tj\n(outer(inner)) Tj\nET\n",
  )
  let text = @pdfc.extract_plain_text_from_page_stream(stream)
  assert_eq(text, "Hello (PDF) (v1) OKouter(inner)")
}

///|
test "pdf phase2.5 can extract text from TJ array" {
  let stream = @utf8.encode("BT\n[(Hello) 120 ( ) -40 (PDF)] TJ\nET\n")
  let text = @pdfc.extract_plain_text_from_page_stream(stream)
  assert_eq(text, "Hello PDF")
}

///|
test "pdf phase2.5 can extract text from multiple content streams" {
  let bs = build_pdf_with_contents("[4 0 R 5 0 R]", [
    "BT\n/F1 12 Tf\n72 120 Td\n(Hello) Tj\nET\n", "BT\n/F1 12 Tf\n72 100 Td\n[( ) 20 (PDF)] TJ\nET\n",
  ])
  let doc = @pdfc.open_pdf(bs)
  let pages = @pdfc.list_page_refs(doc)
  let (page_obj, page_gen) = pages[0]
  let streams = @pdfc.get_page_content_stream_bytes(doc, page_obj, page_gen)
  assert_eq(streams.length(), 2)
  let text = @pdfc.extract_plain_text_from_page_streams(streams)
  assert_eq(text, "Hello\n PDF")
}

///|
test "pdf phase3 parses richer literal string escapes and line breaks" {
  let stream = @utf8.encode(
    "BT\n(One\\nTwo\\rThree\\tTab\\050L\\051\\134\\\\\nKeep\\\r\nGoing\rNext\nLine) Tj\nET\n",
  )
  let text = @pdfc.extract_plain_text_from_page_stream(stream)
  assert_eq(text, "One\nTwo\rThree\tTab(L)\\\\KeepGoing\nNext\nLine")
}

///|
test "pdf phase3 uses nearest Tj or TJ operands" {
  let stream = @utf8.encode(
    "BT\n/F1 12 Tf\n(Hello) Tj\n/F1 12 Tf [(A) 20 (B)] TJ\nET\n",
  )
  let text = @pdfc.extract_plain_text_from_page_stream(stream)
  assert_eq(text, "HelloAB")
}

///|
test "pdf phase4 supports stream length indirect reference" {
  let bs = build_pdf_with_indirect_length()
  let doc = @pdfc.open_pdf(bs)
  let pages = @pdfc.list_page_refs(doc)
  let (page_obj, page_gen) = pages[0]
  let streams = @pdfc.get_page_content_stream_bytes(doc, page_obj, page_gen)
  assert_eq(streams.length(), 1)
  let text = @pdfc.extract_plain_text_from_page_stream(streams[0])
  assert_eq(text, "Hello LenRef")
}

///|
test "pdf phase4 inherited page resources can resolve fonts" {
  let bs = build_pdf_with_inherited_resources_page()
  let doc = @pdfc.open_pdf(bs)
  let pages = @pdfc.list_page_refs(doc)
  let (page_obj, page_gen) = pages[0]
  let fonts = @pdfc.resolve_page_fonts(doc, page_obj, page_gen)
  let has_f1 = match fonts.get("F1") {
    Some(_) => true
    None => false
  }
  assert_eq(has_f1, true)
  let text = @pdfc.extract_text_from_document(doc)
  assert_eq(text.contains("Hello Inherited"), true)
}

///|
test "pdf phase4 missing ToUnicode falls back to string bytes" {
  let bs = build_min_pdf()
  let doc = @pdfc.open_pdf(bs)
  let pages = @pdfc.list_page_refs(doc)
  let (page_obj, page_gen) = pages[0]
  let fonts = @pdfc.resolve_page_fonts(doc, page_obj, page_gen)
  let has_f1 = match fonts.get("F1") {
    Some(_) => true
    None => false
  }
  assert_eq(has_f1, true)
  let f1 = fonts.get("F1").unwrap()
  let text = @pdfc.decode_text_operand(
    doc,
    f1,
    @pdfc.PdfContentOperand::String("ABC"),
  )
  assert_eq(text, "ABC")
}

///|
test "pdf phase4 parse basic ToUnicode cmap" {
  let cmap_stream = @utf8.encode(
    "1 beginbfchar\n<41> <0041>\nendbfchar\n1 beginbfrange\n<42> <43> <0042>\nendbfrange\n",
  )
  let cmap = @pdfc.parse_tounicode_cmap(cmap_stream)
  assert_eq(cmap.get(0x41).unwrap_or(""), "A")
  assert_eq(cmap.get(0x42).unwrap_or(""), "B")
  assert_eq(cmap.get(0x43).unwrap_or(""), "C")
}

///|
test "pdf phase5 tracks Tf state across Tj and TJ text events" {
  let stream_data =
    "BT\n/F1 12 Tf\n(A) Tj\n/F2 10 Tf\n[(B) 120 (C)] TJ\n/F1 12 Tf\n(D) Tj\nET\n"
  let bs = build_pdf_with_two_fonts(stream_data)
  let doc = @pdfc.open_pdf(bs)
  let pages = @pdfc.list_page_refs(doc)
  let (page_obj, page_gen) = pages[0]
  let events = @pdfc.extract_text_events_from_page(doc, page_obj, page_gen)
  assert_eq(events.length(), 3)
  assert_eq(events[0].font_name.unwrap_or(""), "F1")
  assert_eq(events[0].text, "A")
  assert_eq(events[1].font_name.unwrap_or(""), "F2")
  assert_eq(events[1].text, "BC")
  assert_eq(events[2].font_name.unwrap_or(""), "F1")
  assert_eq(events[2].text, "D")
  let page_text = @pdfc.extract_text_from_page(doc, page_obj, page_gen)
  assert_eq(page_text, "ABCD")
}
