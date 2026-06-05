///|
test "ColourSpace::to_string basic" {
  let s = ColourSpace::DeviceRGB.to_string()
  assert_eq(s, "/DeviceRGB")
}

///|
test "read_colourspace device rgb" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let space = ColourSpace::read(
    pdf,
    resources,
    Name(@pdf.PdfName::of_string("/DeviceRGB")),
  )
  match space {
    ColourSpace::DeviceRGB => ()
    _ => fail("expected DeviceRGB")
  }
}

///|
test "read_colourspace indexed" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let lookup_bytes = @pdfio.bytes_of_list([1, 2, 3])
  let lookup : @pdf.PdfObject = String(@pdfio.string_of_bytes(lookup_bytes))
  let space = ColourSpace::read(
    pdf,
    resources,
    Array([
      Name(@pdf.PdfName::of_string("/Indexed")),
      Name(@pdf.PdfName::of_string("/DeviceRGB")),
      Integer(0),
      lookup,
    ]),
  )
  match space {
    ColourSpace::Indexed(ColourSpace::DeviceRGB, table) =>
      match table.get(0) {
        Some(values) => {
          assert_eq(values.length(), 3)
          assert_eq(values[0], 1)
          assert_eq(values[1], 2)
          assert_eq(values[2], 3)
        }
        None => fail("missing indexed table entry")
      }
    _ => fail("expected Indexed DeviceRGB")
  }
}
