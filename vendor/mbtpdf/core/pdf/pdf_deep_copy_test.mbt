///|
test "deep_copy copies streams and object data" {
  let pdf = make_basic_pdf()
  let bytes = @pdfio.bytes_of_string("data")
  let stream = make_stream(
    PdfObject::Dictionary([("/Ref", PdfObject::Indirect(2))]),
    bytes,
  )
  pdf.addobj_given_num((4, stream))
  pdf.objects.object_stream_ids.set(4, 99)
  let input = @pdfio.Input::of_string("xyz", source="toget")
  let toget_stream = PdfObject::Stream(
    Ref::new(
      (
        PdfObject::Dictionary([("/Length", PdfObject::Integer(3))]),
        Stream::ToGet(ToGet::new(input, 0, 3)),
      ),
    ),
  )
  pdf.addobj_given_num((7, toget_stream))
  pdf.objects.objects.set(
    5,
    ({ val: ObjectData::ParsedAlreadyDecrypted(PdfObject::String("x")) }, 0),
  )
  let themap : Map[Int, Array[Int]] = Map::new()
  let parser = (_ : Int, _ : Array[Int]) => (
    [] : Array[(Int, (Ref[ObjectData], Int))])
  pdf.objects.objects.set(
    6,
    ({ val: ObjectData::ToParseFromObjectStream(themap, 1, 2, parser) }, 0),
  )
  pdf.objects.objects.set(8, ({ val: ObjectData::ToParse }, 0))
  if pdf.objects.max_obj_num < 8 {
    pdf.objects.max_obj_num = 8
  }
  let copied = pdf.deep_copy()
  match pdf.lookup_obj(4) {
    PdfObject::Stream(r) =>
      match r.val {
        (_, Stream::Got(original_bytes)) => original_bytes[0] = (88).to_byte()
        _ => fail("expected stream bytes")
      }
    _ => fail("expected stream")
  }
  match copied.lookup_obj(4) {
    PdfObject::Stream(r) =>
      match r.val {
        (_, Stream::Got(copied_bytes)) =>
          assert_true(copied_bytes[0].to_int() != 88)
        _ => fail("expected copied stream bytes")
      }
    _ => fail("expected stream copy")
  }
  assert_eq(copied.objects.object_stream_ids.get(4), Some(99))
}
