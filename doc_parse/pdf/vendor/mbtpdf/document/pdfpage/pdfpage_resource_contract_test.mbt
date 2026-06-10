///|
fn resource_contract_name(name : String) -> @pdf.PdfObject {
  Name(@pdf.PdfName::of_string(name))
}

///|
fn resource_contract_rect(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> @pdf.PdfObject {
  Array([Real(x0), Real(y0), Real(x1), Real(y1)])
}

///|
fn resource_contract_form(pdf : @pdf.Pdf, width : Double) -> Int {
  let dict : @pdf.PdfObject = Dictionary([
    ("/Type", resource_contract_name("/XObject")),
    ("/Subtype", resource_contract_name("/Form")),
    ("/BBox", resource_contract_rect(0.0, 0.0, width, 10.0)),
  ])
  pdf.addobj(Stream(Ref((dict, @pdf.Stream::Got(@pdfio.mkbytes(0))))))
}

///|
fn resource_contract_xobjects(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
) -> @pdf.PdfObject raise {
  match pdf.lookup_direct("/XObject", resources) {
    Some(Dictionary(_) as obj) => obj
    _ => fail("expected /XObject dictionary")
  }
}

///|
fn resource_contract_assert_ref(
  pdf : @pdf.Pdf,
  xobjects : @pdf.PdfObject,
  key : String,
  expected : Int,
) -> Unit raise {
  assert_true(pdf.indirect_number(key, xobjects) == Some(expected))
  match pdf.lookup_direct("/Subtype", pdf.lookup_obj(expected)) {
    Some(Name(name)) if name.equal_string_bytes("/Form") => ()
    _ => fail("expected form xobject subtype")
  }
}

///|
test "resource contract records page-local resource override and explicit merge" {
  let pdf0 = @pdf.Pdf::empty()
  let inherited_form_num = resource_contract_form(pdf0, 20.0)
  let local_form_num = resource_contract_form(pdf0, 30.0)
  let inherited_resources : @pdf.PdfObject = Dictionary([
    (
      "/XObject",
      Dictionary([
        ("/FmParent", Indirect(inherited_form_num)),
        ("/Shared", Indirect(inherited_form_num)),
      ]),
    ),
    ("/Font", Dictionary([("/FParent", Null)])),
  ])
  let local_resources : @pdf.PdfObject = Dictionary([
    (
      "/XObject",
      Dictionary([
        ("/Shared", Indirect(local_form_num)),
        ("/FmLocal", Indirect(local_form_num)),
      ]),
    ),
    (
      "/ColorSpace",
      Dictionary([("/CsLocal", resource_contract_name("/DeviceRGB"))]),
    ),
  ])
  let page_num = pdf0.addobj(
    Dictionary([
      ("/Type", resource_contract_name("/Page")),
      ("/MediaBox", resource_contract_rect(0.0, 0.0, 100.0, 100.0)),
      ("/Resources", local_resources),
    ]),
  )
  let pages_root_num = pdf0.addobj(
    Dictionary([
      ("/Type", resource_contract_name("/Pages")),
      ("/Kids", Array([Indirect(page_num)])),
      ("/Count", Integer(1)),
      ("/Resources", inherited_resources),
    ]),
  )
  let pdf = @pdfpage.PdfPageDoc::new(pdf0).add_root(pages_root_num, [])
  let page = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()[0]
  let page_xobjects = resource_contract_xobjects(pdf, page.resources)
  resource_contract_assert_ref(pdf, page_xobjects, "/FmLocal", local_form_num)
  resource_contract_assert_ref(pdf, page_xobjects, "/Shared", local_form_num)
  match page_xobjects.lookup_immediate("/FmParent") {
    None => ()
    _ => fail("expected page-local resources to override inherited resources")
  }

  let combined = @pdfpage.PdfPageDoc::new(pdf).combine_pdf_resources(
    local_resources, inherited_resources,
  )
  let combined_xobjects = resource_contract_xobjects(pdf, combined)
  resource_contract_assert_ref(
    pdf, combined_xobjects, "/FmLocal", local_form_num,
  )
  resource_contract_assert_ref(
    pdf, combined_xobjects, "/FmParent", inherited_form_num,
  )
  resource_contract_assert_ref(
    pdf, combined_xobjects, "/Shared", local_form_num,
  )
  assert_eq(combined_xobjects.lookup_immediate_all("/Shared").length(), 2)
  match pdf.lookup_direct("/ColorSpace", combined) {
    Some(Dictionary(entries)) => assert_eq(entries.length(), 1)
    _ => fail("expected local colorspace resources")
  }
  match pdf.lookup_direct("/Font", combined) {
    Some(Dictionary(entries)) => assert_eq(entries.length(), 1)
    _ => fail("expected inherited font resources")
  }
}
