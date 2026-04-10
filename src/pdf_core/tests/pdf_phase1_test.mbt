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
fn build_min_pdf() -> Bytes {
  let lines : Array[String] = []
  let offsets : Array[Int] = []
  let mut cur = 0

  let add = fn (s : String) {
    lines.push(s)
    cur = cur + @utf8.encode(s).length()
  }

  add("%PDF-1.4\n")

  let obj1 = "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n"
  offsets.push(cur)
  add(obj1)

  let obj2 = "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n"
  offsets.push(cur)
  add(obj2)

  let obj3 = "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Contents 4 0 R >>\nendobj\n"
  offsets.push(cur)
  add(obj3)

  let stream_data = "BT\n/F1 12 Tf\n72 120 Td\n(Hello PDF) Tj\nET\n"
  let len = @utf8.encode(stream_data).length()
  let obj4 =
    "4 0 obj\n<< /Length " +
    len.to_string() +
    " >>\nstream\n" +
    stream_data +
    "endstream\nendobj\n"
  offsets.push(cur)
  add(obj4)

  let xref_offset = cur
  add("xref\n")
  add("0 5\n")
  add("0000000000 65535 f \n")
  for off in offsets {
    add(zpad(off, 10) + " 00000 n \n")
  }

  add("trailer\n")
  add("<< /Size 5 /Root 1 0 R >>\n")
  add("startxref\n")
  add(xref_offset.to_string() + "\n")
  add("%%EOF\n")

  @utf8.encode(lines.join(separator=""))
}

///|
test "pdf phase1 can open/find pages/read content stream" {
  let bs = build_min_pdf()
  let doc = @pdfc.open_pdf(bs)

  inspect(@pdfc.pdf_version(doc), content="1.4")
  inspect(@pdfc.count_pages(doc), content=1)

  let pages = @pdfc.list_page_refs(doc)
  inspect(pages.length(), content=1)

  let (pobj, pgen) = pages[0]
  let streams = @pdfc.get_page_content_stream_bytes(doc, pobj, pgen)
  inspect(streams.length(), content=1)

  let text = @pdfc.get_indirect_object(doc, 4, 0).stream.unwrap_or(Bytes::new())
  inspect(@cor.utf8_bytes_to_string(text).contains("Hello PDF"), content=true)
}
