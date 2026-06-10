///|
fn pdfspace_contract_name(name : String) -> @pdf.PdfObject {
  Name(@pdf.PdfName::of_string(name))
}

///|
test "colourspace contract reads device and indexed boundaries" {
  let pdf = @pdf.Pdf::empty()
  let empty_resources : @pdf.PdfObject = Dictionary([])
  match
    ColourSpace::read(
      pdf,
      empty_resources,
      pdfspace_contract_name("/DeviceGray"),
    ) {
    ColourSpace::DeviceGray => ()
    _ => fail("expected DeviceGray")
  }
  match
    ColourSpace::read(
      pdf,
      empty_resources,
      pdfspace_contract_name("/DeviceRGB"),
    ) {
    ColourSpace::DeviceRGB => ()
    _ => fail("expected DeviceRGB")
  }
  match
    ColourSpace::read(
      pdf,
      empty_resources,
      pdfspace_contract_name("/DeviceCMYK"),
    ) {
    ColourSpace::DeviceCMYK => ()
    _ => fail("expected DeviceCMYK")
  }

  let indexed : @pdf.PdfObject = Array([
    pdfspace_contract_name("/Indexed"),
    pdfspace_contract_name("/DeviceRGB"),
    Integer(1),
    String("\u{0010}\u{0020}\u{0030}\u{0040}\u{0050}\u{0060}"),
  ])
  match ColourSpace::read(pdf, empty_resources, indexed) {
    ColourSpace::Indexed(ColourSpace::DeviceRGB, table) => {
      match table.get(0) {
        Some([0x10, 0x20, 0x30]) => ()
        _ => fail("expected first indexed RGB row")
      }
      match table.get(1) {
        Some([0x40, 0x50, 0x60]) => ()
        _ => fail("expected second indexed RGB row")
      }
    }
    _ => fail("expected indexed DeviceRGB colourspace")
  }
}

///|
test "colourspace contract resolves named resources and fails closed on unknowns" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([
    (
      "/ColorSpace",
      Dictionary([
        ("/CsGray", pdfspace_contract_name("/DeviceGray")),
        (
          "/CsIndexed",
          Array([
            pdfspace_contract_name("/Indexed"),
            pdfspace_contract_name("/DeviceRGB"),
            Integer(0),
            String("\u{0001}\u{0002}\u{0003}"),
          ]),
        ),
      ]),
    ),
  ])
  match ColourSpace::read(pdf, resources, pdfspace_contract_name("/CsGray")) {
    ColourSpace::DeviceGray => ()
    _ => fail("expected named DeviceGray")
  }
  match
    ColourSpace::read(pdf, resources, pdfspace_contract_name("/CsIndexed")) {
    ColourSpace::Indexed(ColourSpace::DeviceRGB, table) =>
      match table.get(0) {
        Some([1, 2, 3]) => ()
        _ => fail("expected named indexed table")
      }
    _ => fail("expected named indexed colourspace")
  }
  let missing : Result[ColourSpace, Error] = try
    ColourSpace::read(pdf, resources, pdfspace_contract_name("/Missing")) |> Ok
  catch {
    err => Err(err)
  }
  assert_true(missing is Err(_))
  let unsupported : Result[ColourSpace, Error] = try
    ColourSpace::read(pdf, Dictionary([]), Integer(1)) |> Ok
  catch {
    err => Err(err)
  }
  assert_true(unsupported is Err(_))
}
