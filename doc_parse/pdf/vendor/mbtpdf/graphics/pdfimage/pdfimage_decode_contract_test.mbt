///|
fn image_decode_contract_name(name : String) -> @pdf.PdfObject {
  Name(@pdf.PdfName::of_string(name))
}

///|
fn image_decode_contract_stream(
  dict : @pdf.PdfObject,
  data : @pdfio.MutableBytes,
) -> @pdf.PdfObject {
  Stream(Ref((dict, @pdf.Stream::Got(data))))
}

///|
test "image decode contract reads tiny raw gray image and mask metadata" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", image_decode_contract_name("/DeviceGray")),
    ("/Mask", Array([Integer(0), Integer(1)])),
    ("/SMask", Indirect(99)),
  ])
  let stream = image_decode_contract_stream(dict, @pdfio.bytes_of_list([0x7f]))
  match
    (@pdfimage.Image::get_image_24bpp(pdf, resources, stream) : @pdfimage.Image) {
    Raw(width, height, layout, bytes) => {
      assert_eq(width, 1)
      assert_eq(height, 1)
      match (layout : @pdfimage.PixelLayout) {
        BPP24 => ()
        _ => fail("expected BPP24")
      }
      assert_eq(@pdfio.bytes_size(bytes), 3)
      assert_eq(@pdfio.bget_unsafe(bytes, 0), 0x7f)
      assert_eq(@pdfio.bget_unsafe(bytes, 1), 0x7f)
      assert_eq(@pdfio.bget_unsafe(bytes, 2), 0x7f)
    }
    _ => fail("expected raw gray image")
  }
  match pdf.lookup_direct("/Mask", dict) {
    Some(Array([Integer(0), Integer(1)])) => ()
    _ => fail("expected raw /Mask metadata")
  }
  match dict.lookup_immediate("/SMask") {
    Some(Indirect(99)) => ()
    _ => fail("expected raw /SMask metadata")
  }

  let image_mask : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/ImageMask", Boolean(true)),
  ])
  match @pdfimage.Image::colspace(pdf, image_mask, resources) {
    @pdfspace.ColourSpace::DeviceGray => ()
    _ => fail("expected image mask to imply DeviceGray")
  }
  match @pdfimage.Image::bpc(pdf, image_mask) {
    Some(Integer(1)) => ()
    _ => fail("expected image mask to imply 1 bpc")
  }
}

///|
test "image decode contract treats compressed and heavy filters explicitly" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let flate_dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", image_decode_contract_name("/DeviceGray")),
    ("/Filter", image_decode_contract_name("/FlateDecode")),
  ])
  let flate_stream = image_decode_contract_stream(
    flate_dict,
    @pdfcodec.PdfCodec::new().encode_flate(@pdfio.bytes_of_list([0x7f])),
  )
  let flate_result : Result[@pdfimage.Image, Error] = try
    @pdfimage.Image::get_image_24bpp(pdf, resources, flate_stream) |> Ok
  catch {
    err => Err(err)
  }
  assert_true(flate_result is Err(_))

  let jpx_dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/ColorSpace", image_decode_contract_name("/DeviceRGB")),
    ("/Filter", image_decode_contract_name("/JPXDecode")),
  ])
  let jpx_stream = image_decode_contract_stream(
    jpx_dict,
    @pdfio.bytes_of_list([0x01, 0x02]),
  )
  match
    (
      @pdfimage.Image::get_image_24bpp(pdf, resources, jpx_stream) :
      @pdfimage.Image) {
    JPEG2000(bytes, _) => assert_eq(@pdfio.bytes_size(bytes), 2)
    _ => fail("expected JPXDecode to surface as JPEG2000 payload")
  }

  let globals_num = pdf.addobj(
    image_decode_contract_stream(
      Dictionary([("/Length", Integer(1))]),
      @pdfio.bytes_of_list([0x00]),
    ),
  )
  let jbig2_dict : @pdf.PdfObject = Dictionary([
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/BitsPerComponent", Integer(1)),
    ("/ImageMask", Boolean(true)),
    ("/Filter", image_decode_contract_name("/JBIG2Decode")),
    ("/DecodeParms", Dictionary([("/JBIG2Globals", Indirect(globals_num))])),
  ])
  let jbig2_stream = image_decode_contract_stream(
    jbig2_dict,
    @pdfio.bytes_of_list([0xAA]),
  )
  match
    (
      @pdfimage.Image::get_image_24bpp(pdf, resources, jbig2_stream) :
      @pdfimage.Image) {
    JBIG2(bytes, _, Some(global_ref)) => {
      assert_eq(@pdfio.bytes_size(bytes), 1)
      assert_eq(global_ref, globals_num)
    }
    _ => fail("expected JBIG2 payload with globals ref")
  }
}
