///|
let write_ctx : PdfWrite = PdfWrite::new()

///|
test "string_of_pdf escapes carriage return and form feed" {
  let obj : @pdf.PdfObject = String("a\r\f")
  let rendered = write_ctx.string_of_pdf(obj)
  assert_true(rendered.contains("\\r"))
  assert_true(rendered.contains("\\f"))
}

///|
test "string_of_pdf escapes newline" {
  let obj : @pdf.PdfObject = String("a\nb")
  let rendered = write_ctx.string_of_pdf(obj)
  assert_true(rendered.contains("\\n"))
}

///|
test "string_of_pdf expands scientific notation" {
  let rendered = write_ctx.string_of_pdf(Real(1.2e20))
  assert_true(!rendered.contains("e") && !rendered.contains("E"))
}

///|
test "string_of_pdf expands negative exponent" {
  let rendered = write_ctx.string_of_pdf(Real(1.2e-5))
  assert_true(!rendered.contains("e") && !rendered.contains("E"))
  assert_true(rendered.has_prefix("0."))
}

///|
test "string_of_pdf expands large positive exponent" {
  let rendered = write_ctx.string_of_pdf(Real(1.2e100))
  assert_eq(rendered.length(), 101)
  assert_true(rendered.has_prefix("12"))
  assert_true(rendered.has_suffix("0"))
}

///|
test "string_of_pdf expands tiny exponent with leading zeros" {
  let rendered = write_ctx.string_of_pdf(Real(1.2e-20))
  assert_eq(rendered.length(), 23)
  assert_true(rendered.has_prefix("0."))
  assert_true(rendered.has_suffix("12"))
}

///|
test "string_of_pdf expands negative scientific values" {
  let rendered = write_ctx.string_of_pdf(Real(-1.2e-20))
  assert_eq(rendered.length(), 24)
  assert_true(rendered.has_prefix("-0."))
  assert_true(rendered.has_suffix("12"))
}

///|
test "string_of_pdf encodes control and delimiter bytes" {
  let bytes = @pdfio.bytes_of_list([
    0x2f, 0x14, 0x16, 0x1a, 0x28, 0x29, 0x3c, 0x25,
  ])
  let name = @pdfio.string_of_bytes(bytes)
  let rendered = write_ctx.string_of_pdf(Name(@pdf.PdfName::of_string(name)))
  assert_true(rendered.contains("#14"))
  assert_true(rendered.contains("#16"))
  assert_true(rendered.contains("#1A"))
  assert_true(rendered.contains("#28"))
  assert_true(rendered.contains("#29"))
  assert_true(rendered.contains("#3C"))
  assert_true(rendered.contains("#25"))
}

///|
test "string_of_pdf encodes greater-than in names" {
  let rendered = write_ctx.string_of_pdf(Name(@pdf.PdfName::of_string("/A>")))
  assert_true(rendered.contains("#3E"))
}

///|
test "string_of_pdf encodes delimiter bytes in names" {
  let cases = [("/[", "/#5B"), ("/]", "/#5D"), ("/{", "/#7B"), ("/}", "/#7D")]
  for pair in cases {
    let rendered = write_ctx.string_of_pdf(
      Name(@pdf.PdfName::of_string(pair.0)),
    )
    assert_eq(rendered, pair.1)
  }
}

///|
test "string_of_pdf handles short names" {
  let rendered = write_ctx.string_of_pdf(Name(@pdf.PdfName::of_string("/")))
  assert_eq(rendered, "/")
}

///|
test "make_hex_pdf_string encodes bytes" {
  assert_eq(make_hex_pdf_string("Hi"), "<4869>")
}

///|
test "make_hex_pdf_string covers hex digits" {
  let raw = @pdfio.string_of_int_array([0x7B, 0xBD, 0xD0])
  assert_eq(make_hex_pdf_string(raw), "<7bbdd0>")
}

///|
test "pdf_to_output generates object streams with indirect lengths" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let length_obj = pdf.addobj(Integer(3))
  let data = @pdfio.bytes_of_string("abc")
  let dict : @pdf.PdfObject = Dictionary([("/Length", Indirect(length_obj))])
  let stream_num = pdf.addobj(Stream(Ref::new((dict, @pdf.Stream::Got(data)))))
  let marked_obj = pdf.addobj(Integer(123))
  pdf.objects.object_stream_ids.set(marked_obj, stream_num)
  pdf.objects.object_stream_ids.set(stream_num, stream_num)
  let payload = "A".repeat(1000)
  let payload_ids = Array::new()
  for _ in 0..<=30 {
    let objnum = pdf.addobj(String(payload))
    payload_ids.push(objnum)
  }
  for objnum in payload_ids {
    pdf.objects.object_stream_ids.set(objnum, stream_num)
  }
  let objs_in_stream = payload_ids.copy()
  objs_in_stream.push(marked_obj)
  objs_in_stream.sort_by((a, b) => a - b)
  let object_strings = Array::new()
  let offsets = Array::new()
  let mut offset = 0
  for objnum in objs_in_stream {
    let obj = pdf.lookup_obj(objnum)
    let s = write_ctx.string_of_pdf(obj) + " "
    object_strings.push(s)
    offsets.push(offset)
    offset = offset + s.length()
  }
  let header = StringBuilder::new()
  let mut i = 0
  while i < objs_in_stream.length() {
    header.write_string(objs_in_stream[i].to_string())
    header.write_char(' ')
    header.write_string(offsets[i].to_string())
    header.write_char(' ')
    i = i + 1
  }
  let header_str = header.to_string()
  let data_sb = StringBuilder::new()
  data_sb.write_string(header_str)
  for s in object_strings {
    data_sb.write_string(s)
  }
  let objstm_data = @pdfio.bytes_of_string(data_sb.to_string())
  let encoded = @pdfcodec.PdfCodec::new().encode_flate(objstm_data)
  let should_compress = @pdfio.bytes_size(encoded) + 20 <
    @pdfio.bytes_size(objstm_data)
  let (output, buffer) = @pdfio.Output::of_bytes(4096)
  write_ctx.pdf_to_output(
    generate_objstm=true,
    preserve_objstm=true,
    compress_objstm=true,
    None,
    false,
    pdf,
    output,
  )
  let bytes = output.extract_bytes(buffer)
  let text = @pdfio.string_of_bytes(bytes)
  assert_true(text.contains("/ObjStm"))
  let has_flate = text.contains("/FlateDecode")
  assert_eq(has_flate, should_compress)
}

///|
test "pdf_to_output skips indirect length objects for objstm hints" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let length_obj = pdf.addobj(Integer(4))
  let data = @pdfio.bytes_of_string("data")
  let dict : @pdf.PdfObject = Dictionary([("/Length", Indirect(length_obj))])
  let stream_num = pdf.addobj(Stream(Ref::new((dict, @pdf.Stream::Got(data)))))
  pdf.objects.object_stream_ids.set(stream_num, stream_num)
  pdf.objects.object_stream_ids.set(length_obj, stream_num)
  let (output, buffer) = @pdfio.Output::of_bytes(1024)
  write_ctx.pdf_to_output(
    generate_objstm=true,
    preserve_objstm=false,
    compress_objstm=false,
    None,
    false,
    pdf,
    output,
  )
  let bytes = output.extract_bytes(buffer)
  let text = @pdfio.string_of_bytes(bytes)
  assert_true(text.contains("/ObjStm"))
}

///|

///|
test "pdf_to_output drops invalid object stream ids and writes toget" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let data = @pdfio.bytes_of_string("a")
  let input = @pdfio.Input::of_bytes(data, source="toget-output")
  let deferred : @pdf.DeferredEncryption = {
    crypt_type: @pdfcryptprimitives.Encryption::AESV2,
    file_encryption_key: None,
    obj: 1,
    gen: 0,
    key: [],
    keylength: 128,
    r: 5,
  }
  let toget = @pdf.ToGet::new(
    input,
    0,
    4,
    crypt=@pdf.ToGetCrypt::ToDecrypt(deferred),
  )
  let dict : @pdf.PdfObject = Dictionary([("/Length", Integer(4))])
  let stream : @pdf.PdfObject = Stream(
    Ref::new((dict, @pdf.Stream::ToGet(toget))),
  )
  let stream_num = pdf.addobj(stream)
  pdf.objects.object_stream_ids.set(9999, stream_num)
  pdf.objects.object_stream_ids.set(stream_num, stream_num)
  let (output, buffer) = @pdfio.Output::of_bytes(4096)
  write_ctx.pdf_to_output(
    preserve_objstm=true,
    generate_objstm=false,
    compress_objstm=false,
    None,
    false,
    pdf,
    output,
  )
  assert_true(pdf.objects.object_stream_ids.get(9999) is None)
  assert_true(pdf.objects.object_stream_ids.get(stream_num) is None)
  let bytes = output.extract_bytes(buffer)
  assert_true(bytes.length() > 0)
}

///|
async test "pdf_to_file writes output" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let path = "pdfwrite_async_test.pdf"
  let file = @fs.open(path, mode=WriteOnly, create=0o644, truncate=true)
  defer file.close()
  let output = @pdfiofs.output_of_channel(file)
  write_ctx.pdf_to_output(None, true, pdf, output)
  (output.flush)()
  let file = @fs.open(path, mode=ReadOnly)
  let bytes = @pdfiofs.bytes_of_input_channel(file)
  assert_true(bytes.length() > 0)
  file.close()
  @fs.remove(path)
}

///|
test "pdf_to_output supports recrypt" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let (output, _) = @pdfio.Output::of_bytes(2048)
  let res : Result[Unit, Error] = try? write_ctx.pdf_to_output(
    recrypt="pass",
    None,
    true,
    pdf,
    output,
  )
  assert_true(res is Err(_))
}
