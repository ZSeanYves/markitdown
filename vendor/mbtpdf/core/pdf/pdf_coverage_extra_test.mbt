///|
test "serialization escapes extra cases" {
  let minimal = PdfObject::Name(PdfName::of_string("/"))
  assert_eq(minimal.to_string(), "/")
  let delimiter = PdfObject::Name(PdfName::of_string("/A(B"))
  assert_true(delimiter.to_string().contains("#28"))
  let control = PdfObject::Name(PdfName::of_string("/\u0013"))
  assert_true(control.to_string().contains("#13"))
  let escaped = PdfObject::String("\t\u000C")
  let rendered = escaped.to_string()
  assert_true(rendered.contains("\\t"))
  assert_true(rendered.contains("\\f"))
}

///|
test "serialization includes stream data when requested" {
  let bytes = @pdfio.bytes_of_string("abc")
  let dict : PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(bytes))),
  ])
  let stream_ref = Ref::new((dict, Stream::Got(bytes)))
  let obj = PdfObject::Stream(stream_ref)
  let rendered = obj.to_string_including_data()
  assert_true(rendered.contains("stream"))
  assert_true(rendered.contains("abc"))
  assert_true(rendered.contains("endstream"))
}

///|
test "bigarray_of_stream rejects non-stream objects" {
  let res : Result[@pdfio.MutableBytes, Error] = try? PdfObject::Integer(0).bigarray_of_stream()
  assert_true(res is Err(_))
}
