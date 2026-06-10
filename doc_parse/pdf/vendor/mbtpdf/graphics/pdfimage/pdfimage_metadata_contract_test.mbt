///|
fn image_metadata_name(name : String) -> @pdf.PdfObject {
  Name(@pdf.PdfName::of_string(name))
}

///|
test "object facts contract keeps image xobject metadata reachable" {
  let pdf = @pdf.Pdf::empty()
  let image_dict : @pdf.PdfObject = Dictionary([
    ("/Type", image_metadata_name("/XObject")),
    ("/Subtype", image_metadata_name("/Image")),
    ("/Width", Integer(320)),
    ("/Height", Integer(200)),
    ("/ColorSpace", image_metadata_name("/DeviceRGB")),
    ("/BitsPerComponent", Integer(8)),
    ("/Filter", image_metadata_name("/DCTDecode")),
  ])
  let image_num = pdf.addobj(
    Stream(Ref((image_dict, @pdf.Stream::Got(@pdfio.bytes_of_list([1, 2, 3]))))),
  )
  let resources : @pdf.PdfObject = Dictionary([
    ("/XObject", Dictionary([("/Im1", Indirect(image_num))])),
  ])
  let xobjects = match pdf.lookup_direct("/XObject", resources) {
    Some(Dictionary(_) as obj) => obj
    _ => fail("expected /XObject resources")
  }
  let image = match xobjects.lookup_immediate("/Im1") {
    Some(Indirect(n)) => {
      assert_eq(n, image_num)
      pdf.lookup_obj(n)
    }
    _ => fail("expected image object reference")
  }
  match pdf.lookup_direct("/Subtype", image) {
    Some(Name(name)) if name.equal_string_bytes("/Image") => ()
    _ => fail("expected image subtype")
  }
  match pdf.lookup_direct("/Width", image) {
    Some(Integer(width)) => assert_eq(width, 320)
    _ => fail("expected image width")
  }
  match pdf.lookup_direct("/Height", image) {
    Some(Integer(height)) => assert_eq(height, 200)
    _ => fail("expected image height")
  }
  match @pdfimage.Image::colspace(pdf, image, Dictionary([])) {
    @pdfspace.ColourSpace::DeviceRGB => ()
    _ => fail("expected DeviceRGB colorspace")
  }
  match @pdfimage.Image::bpc(pdf, image) {
    Some(Integer(bits)) => assert_eq(bits, 8)
    _ => fail("expected image bits per component")
  }
  match pdf.lookup_direct("/Filter", image) {
    Some(Name(name)) if name.equal_string_bytes("/DCTDecode") => ()
    _ => fail("expected DCTDecode filter")
  }
}
