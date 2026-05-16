///|
fn render_tj_text(values : Array[@pdf.PdfObject], font_size : Double) -> String {
  let parts = extract_text_fragments_from_tj_array(
    @pdf.PdfObject::Array(values),
    Some(font_size),
  )
  parts.join("")
}

///|
fn build_minimal_pdf() -> @pdf.Pdf {
  let pdf : @pdf.Pdf = {
    major: 2,
    minor: 0,
    root: 4,
    objects: {
      max_obj_num: 0,
      parse: None,
      objects: @pdf.pdfobjmap_empty(),
      object_stream_ids: Map([]),
    },
    trailerdict: Dictionary([]),
    was_linearized: false,
    saved_encryption: None,
  }
  let content = "BT /F0 12 Tf (Hello) Tj ET\n"
  let stream_bytes = @pdfio.bytes_of_string(content)
  let stream_dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(stream_bytes))),
  ])
  let stream_obj : @pdf.PdfObject = Stream(
    Ref((stream_dict, @pdf.Stream::Got(stream_bytes))),
  )
  let font_dict : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/Font"))),
    ("/Subtype", Name(@pdf.PdfName::of_string("/Type1"))),
    ("/BaseFont", Name(@pdf.PdfName::of_string("/Times-Roman"))),
  ])
  let resources : @pdf.PdfObject = Dictionary([
    ("/Font", Dictionary([("/F0", font_dict)])),
  ])
  let page : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/Page"))),
    ("/Parent", Indirect(1)),
    ("/Resources", resources),
    ("/MediaBox", Array([Integer(0), Integer(0), Integer(300), Integer(300)])),
    ("/Contents", Indirect(2)),
  ])
  let pages : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/Pages"))),
    ("/Kids", Array([Indirect(3)])),
    ("/Count", Integer(1)),
  ])
  let catalog : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/Catalog"))),
    ("/Pages", Indirect(1)),
  ])
  pdf.addobj_given_num((1, pages))
  pdf.addobj_given_num((2, stream_obj))
  pdf.addobj_given_num((3, page))
  pdf.addobj_given_num((4, catalog))
  pdf
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
fn find_last_substring(haystack : String, needle : String) -> Int? {
  let hay_len = haystack.length()
  let needle_len = needle.length()
  if needle_len == 0 || hay_len < needle_len {
    return None
  }

  let mut i = hay_len - needle_len
  while i > 0 {
    let mut matched = true
    let mut j = 0
    while matched && j < needle_len {
      if haystack[i + j] != needle[j] {
        matched = false
      }
      j = j + 1
    }
    if matched {
      return Some(i)
    }
    i = i - 1
  }

  let mut matched = true
  let mut j = 0
  while matched && j < needle_len {
    if haystack[j] != needle[j] {
      matched = false
    }
    j = j + 1
  }
  if matched { Some(0) } else { None }
}

///|
fn build_malformed_xref_stream_pdf() -> Array[Byte] raise {
  let (output, buffer) = @pdfio.Output::of_bytes(512)
  @pdfwrite.PdfWrite::new().pdf_to_output(
    preserve_objstm=true,
    None,
    false,
    build_minimal_pdf(),
    output,
  )
  let bytes = output.extract_bytes(buffer)
  let text = @pdfio.string_of_bytes(bytes)
  let startxref_marker = "startxref\n"
  let startxref_index = match find_last_substring(text, startxref_marker) {
    Some(i) => i + startxref_marker.length()
    None => fail("startxref marker not found")
  }
  let eof_index = match find_last_substring(text, "\n%%EOF\n") {
    Some(i) => i
    None => fail("EOF marker not found")
  }
  let xref_offset_text = text[startxref_index:eof_index]
  let xref_type_index = match find_last_substring(text, "/Type /XRef") {
    Some(i) => i
    None => fail("xref type marker not found")
  }
  let xref_prefix = text[:xref_type_index].to_owned()
  let xref_dict_index = match find_last_substring(xref_prefix, "<<") {
    Some(i) => i
    None => fail("xref dict marker not found")
  }
  let malformed_offset_text = xref_dict_index.to_string()
  if malformed_offset_text.length() != xref_offset_text.length() {
    fail("malformed offset changed width")
  }
  let corrupted = (text[:startxref_index] +
    malformed_offset_text +
    text[eof_index:]).to_owned()
  bytes_of_string(corrupted)
}

///|
async test "extract raw document keeps malformed xref repair logs out of adapter output" {
  let corrupted = build_malformed_xref_stream_pdf()
  let out_dir = ".tmp/doc_parse_pdf_raw"
  let _ = try? @fs.mkdir(out_dir, permission=0o755, recursive=true)
  let path = out_dir + "/minimal_bad_xref_stream_offset.pdf"
  let _ = try? @fs.remove(path)
  @fs.write_file(path, Bytes::from_array(corrupted), create=0o644, truncate=true) catch {
    e => fail("write corrupted fixture failed: " + e.to_string())
  }

  let messages : Array[String] = []
  let prev_logger = @pdfe.logger.val
  try {
    @pdfe.logger.val = fn(message) { messages.push(message) }
    let extraction = extract_raw_document_with_mbtpdf(path)
    assert_eq(messages.length(), 0)
    match extraction {
      Ok(doc) => assert_true(doc.page_count > 0)
      Err(err) => fail("extraction failed: " + err.to_string())
    }
    let _ = try? @fs.remove(path)
    @pdfe.logger.val = prev_logger
  } catch {
    err => {
      let _ = try? @fs.remove(path)
      @pdfe.logger.val = prev_logger
      raise err
    }
  }
}

///|
test "TJ negative spacing inserts word spaces for english fragments" {
  let text = render_tj_text(
    [
      String("While"),
      Integer(-361),
      String("there"),
      Integer(-362),
      String("is"),
    ],
    10.0,
  )
  assert_eq(text, "While there is")
}

///|
test "TJ small kerning does not insert space inside split word" {
  let text = render_tj_text(
    [String("Lar"), Integer(18), String("ge"), Integer(-40), String("language")],
    10.0,
  )
  assert_eq(text, "Largelanguage")
}

///|
test "TJ appendix letter spacing inserts word boundaries" {
  let text = render_tj_text(
    [
      String("refer"),
      Integer(-250),
      String("to"),
      Integer(-250),
      String("Appendix"),
      Integer(-250),
      String("A"),
    ],
    10.0,
  )
  assert_eq(text, "refer to Appendix A")
}

///|
test "TJ acronym and parentheses keep tight punctuation but separate next word" {
  let text = render_tj_text(
    [
      String("models"),
      Integer(-250),
      String("(LLMs)"),
      Integer(-250),
      String("are"),
    ],
    10.0,
  )
  assert_eq(text, "models(LLMs) are")
}

///|
test "TJ hyphenated words stay joined but next word may separate" {
  let text = render_tj_text(
    [
      String("multi"),
      Integer(-20),
      String("-"),
      Integer(-20),
      String("agent"),
      Integer(-250),
      String("approaches"),
    ],
    10.0,
  )
  assert_eq(text, "multi-agent approaches")
}

///|
test "TJ explicit space glyph does not double insert spaces" {
  let text = render_tj_text(
    [String("While "), Integer(-361), String("there")],
    10.0,
  )
  assert_eq(text, "While there")
}

///|
test "TJ cjk fragments stay compact despite large negative spacing" {
  let text = render_tj_text(
    [
      String("中"),
      Integer(-300),
      String("文"),
      Integer(-300),
      String("测试"),
    ],
    10.0,
  )
  assert_eq(text, "中文测试")
}

///|
test "TJ punctuation does not add space before comma but may after comma" {
  let text = render_tj_text(
    [
      String("hello"),
      Integer(-250),
      String(","),
      Integer(-250),
      String("world"),
    ],
    10.0,
  )
  assert_eq(text, "hello, world")
}

///|
test "TJ decimal fragments stay tight before following word" {
  let text = render_tj_text(
    [
      String("3"),
      Integer(-20),
      String("."),
      Integer(-20),
      String("14"),
      Integer(-250),
      String("value"),
    ],
    10.0,
  )
  assert_eq(text, "3.14 value")
}
