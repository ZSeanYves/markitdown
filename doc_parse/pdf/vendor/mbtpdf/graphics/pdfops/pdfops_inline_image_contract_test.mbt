///|
fn inline_contract_name(name : String) -> @pdf.PdfObject {
  Name(@pdf.PdfName::of_string(name))
}

///|
test "inline image contract keeps metadata and source attribution" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let dict : @pdf.PdfObject = Dictionary([
    ("/W", Integer(1)),
    ("/H", Integer(1)),
    ("/BPC", Integer(8)),
    ("/CS", inline_contract_name("/DeviceRGB")),
    ("/F", inline_contract_name("/DCT")),
  ])
  let inline_data = @pdfio.bytes_of_list([0xFF, 0xD9])
  let stream = @pdfops.Op::stream_of_ops([
    @pdfops.Op::Opq,
    @pdfops.Op::InlineImage((dict, None, inline_data)),
    @pdfops.Op::OpQ,
  ])
  let stream_num = pdf.addobj(stream)
  let located = @pdfops.Op::parse_operators_with_source(pdf, resources, [
    Indirect(stream_num),
  ])
  assert_eq(located.length(), 3)
  match located[0].op {
    Opq => ()
    _ => fail("expected leading q")
  }
  match located[1].op {
    InlineImage((image_dict, decode_params, data)) => {
      assert_true(decode_params is None)
      match pdf.lookup_direct("/W", image_dict) {
        Some(Integer(1)) => ()
        _ => fail("expected inline image width")
      }
      match pdf.lookup_direct("/H", image_dict) {
        Some(Integer(1)) => ()
        _ => fail("expected inline image height")
      }
      match pdf.lookup_direct("/BPC", image_dict) {
        Some(Integer(8)) => ()
        _ => fail("expected inline image bits per component")
      }
      match pdf.lookup_direct("/CS", image_dict) {
        Some(Name(name)) if name.equal_string_bytes("/DeviceRGB") => ()
        _ => fail("expected inline image colorspace")
      }
      match pdf.lookup_direct("/F", image_dict) {
        Some(Name(name)) if name.equal_string_bytes("/DCT") => ()
        _ => fail("expected inline image filter metadata")
      }
      assert_eq(@pdfio.bytes_size(data), 2)
      assert_eq(@pdfio.bget_unsafe(data, 0), 0xFF)
      assert_eq(@pdfio.bget_unsafe(data, 1), 0xD9)
    }
    _ => fail("expected inline image op")
  }
  assert_eq(located[1].source_stream_index, 0)
  assert_eq(located[1].source_op_index, 1)
  assert_true(located[1].source_object_ref == Some(stream_num))
  match located[2].op {
    OpQ => ()
    _ => fail("expected trailing Q")
  }
}
