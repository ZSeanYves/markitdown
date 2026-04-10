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
    "   /Resources << /Font << /F1 5 0 R >> >>\n" +
    "   /Contents 4 0 R\n" +
    ">>\n" +
    "endobj\n",
  )

  // 4 0 obj: content stream
  let stream_data = "BT\n" +
    "/F1 12 Tf\n" +
    "72 120 Td\n" +
    "(Hello PDF) Tj\n" +
    "ET\n"
  let stream_len = byte_len(stream_data)

  add_obj(
    "4 0 obj\n" +
    "<< /Length " +
    stream_len.to_string() +
    " >>\n" +
    "stream\n" +
    stream_data +
    "endstream\n" +
    "endobj\n",
  )

  // 5 0 obj: font
  add_obj(
    "5 0 obj\n" +
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\n" +
    "endobj\n",
  )

  let xref_offset = cur
  add("xref\n")
  add("0 6\n")
  add("0000000000 65535 f \n")
  for off in offsets {
    add(zpad(off, 10) + " 00000 n \n")
  }

  add("trailer\n")
  add("<< /Size 6 /Root 1 0 R >>\n")
  add("startxref\n")
  add(xref_offset.to_string() + "\n")
  add("%%EOF\n")

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
