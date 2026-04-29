///|
test "colspace and bpc handle image masks" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([("/ImageMask", Boolean(true))])
  let space = @pdfimage.Image::colspace(pdf, dict, Dictionary([]))
  match space {
    @pdfspace.ColourSpace::DeviceGray => ()
    _ => fail("expected DeviceGray")
  }
  match (@pdfimage.Image::bpc(pdf, dict) : @pdf.PdfObject?) {
    Some(Integer(1)) => ()
    _ => fail("expected bpc of 1")
  }
}

///|
test "get_image_24bpp decodes raw rgb image" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Image"))),
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/ColorSpace", Name(@pdf.PdfName::of_string("/DeviceRGB"))),
    ("/BitsPerComponent", Integer(8)),
    ("/Length", Integer(3)),
  ])
  let data = @pdfio.bytes_of_list([0x10, 0x20, 0x30])
  let stream : @pdf.PdfObject = Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  let image = @pdfimage.Image::get_image_24bpp(pdf, Dictionary([]), stream)
  match image {
    Image::Raw(w, h, _, bytes) => {
      assert_eq(w, 1)
      assert_eq(h, 1)
      assert_true(@pdfio.bytes_size(bytes) > 0)
    }
    _ => fail("expected raw image")
  }
}

///|
test "get_image_24bpp applies decode for 1bpp" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Image"))),
    ("/Width", Integer(1)),
    ("/Height", Integer(1)),
    ("/ColorSpace", Name(@pdf.PdfName::of_string("/DeviceGray"))),
    ("/BitsPerComponent", Integer(1)),
    ("/Decode", Array([Real(1.0), Real(0.0)])),
    ("/Length", Integer(1)),
  ])
  let data = @pdfio.bytes_of_list([0x00])
  let stream : @pdf.PdfObject = Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  let image = @pdfimage.Image::get_image_24bpp(pdf, Dictionary([]), stream)
  match image {
    Image::Raw(w, h, _, bytes) => {
      assert_eq(w, 1)
      assert_eq(h, 1)
      assert_true(@pdfio.bytes_size(bytes) > 0)
    }
    _ => fail("expected raw image")
  }
}
