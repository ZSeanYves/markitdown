///|
fn object_facts_name(name : String) -> @pdf.PdfObject {
  Name(@pdf.PdfName::of_string(name))
}

///|
fn object_facts_rect(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> @pdf.PdfObject {
  Array([Real(x0), Real(y0), Real(x1), Real(y1)])
}

///|
fn object_facts_close(a : Double, b : Double) -> Unit raise {
  let diff = (a - b).abs()
  assert_true(diff < 0.000001)
}

///|
fn object_facts_assert_rect(
  pdf : @pdf.Pdf,
  rect : @pdf.PdfObject,
  expected : (Double, Double, Double, Double),
) -> Unit raise {
  let (x0, y0, x1, y1) = pdf.parse_rectangle(rect)
  object_facts_close(x0, expected.0)
  object_facts_close(y0, expected.1)
  object_facts_close(x1, expected.2)
  object_facts_close(y1, expected.3)
}

///|
fn object_facts_single_page_pdf(
  pdf0 : @pdf.Pdf,
  page_num : Int,
  pages_extras : Array[(String, @pdf.PdfObject)],
  root_extras : Array[(String, @pdf.PdfObject)],
) -> @pdf.Pdf raise {
  let entries : Array[(String, @pdf.PdfObject)] = [
    ("/Type", object_facts_name("/Pages")),
    ("/Kids", Array([Indirect(page_num)])),
    ("/Count", Integer(1)),
  ]
  entries.append(pages_extras[:])
  let pages_num = pdf0.addobj(Dictionary(entries))
  @pdfpage.PdfPageDoc::new(pdf0).add_root(pages_num, root_extras)
}

///|
test "object facts contract reads page boxes rotation and raw user unit" {
  let pdf0 = @pdf.Pdf::empty()
  let media = object_facts_rect(0.0, 0.0, 200.0, 100.0)
  let crop = object_facts_rect(10.0, 20.0, 190.0, 90.0)
  let page_num = pdf0.addobj(
    Dictionary([
      ("/Type", object_facts_name("/Page")),
      ("/MediaBox", media),
      ("/CropBox", crop),
      ("/Rotate", Integer(90)),
      ("/UserUnit", Real(2.0)),
    ]),
  )
  let pdf = object_facts_single_page_pdf(pdf0, page_num, [], [])
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  assert_eq(pages.length(), 1)
  object_facts_assert_rect(pdf, pages[0].mediabox, (0.0, 0.0, 200.0, 100.0))
  match pages[0].cropbox {
    Some(cropbox) =>
      object_facts_assert_rect(pdf, cropbox, (10.0, 20.0, 190.0, 90.0))
    None => fail("expected /CropBox")
  }
  match (pages[0].rotate : @pdfpage.Rotation) {
    Rotate90 => ()
    _ => fail("expected /Rotate 90")
  }
  match pages[0].rest.lookup_immediate("/MediaBox") {
    None => ()
    _ => fail("expected /MediaBox to be typed, not rest")
  }
  // UserUnit is not typed on Page today; keep the raw value reachable for PDF v2.
  match pages[0].rest.lookup_immediate("/UserUnit") {
    Some(unit) => object_facts_close(pdf.getnum(unit), 2.0)
    None => fail("expected raw /UserUnit in page rest")
  }
}

///|
test "object facts contract keeps inherited resources and xobject refs reachable" {
  let pdf0 = @pdf.Pdf::empty()
  let form_dict : @pdf.PdfObject = Dictionary([
    ("/Type", object_facts_name("/XObject")),
    ("/Subtype", object_facts_name("/Form")),
    ("/BBox", object_facts_rect(0.0, 0.0, 20.0, 10.0)),
  ])
  let form_num = pdf0.addobj(
    Stream(Ref((form_dict, @pdf.Stream::Got(@pdfio.mkbytes(0))))),
  )
  let image_dict : @pdf.PdfObject = Dictionary([
    ("/Type", object_facts_name("/XObject")),
    ("/Subtype", object_facts_name("/Image")),
    ("/Width", Integer(2)),
    ("/Height", Integer(1)),
    ("/ColorSpace", object_facts_name("/DeviceRGB")),
    ("/BitsPerComponent", Integer(8)),
  ])
  let image_num = pdf0.addobj(
    Stream(Ref((image_dict, @pdf.Stream::Got(@pdfio.mkbytes(6))))),
  )
  let resources : @pdf.PdfObject = Dictionary([
    (
      "/XObject",
      Dictionary([("/Fm1", Indirect(form_num)), ("/Im1", Indirect(image_num))]),
    ),
  ])
  let page_num = pdf0.addobj(
    Dictionary([
      ("/Type", object_facts_name("/Page")),
      ("/MediaBox", object_facts_rect(0.0, 0.0, 200.0, 100.0)),
    ]),
  )
  let pdf = object_facts_single_page_pdf(
    pdf0,
    page_num,
    [("/Resources", resources)],
    [],
  )
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  assert_eq(pages.length(), 1)
  let xobjects = match pdf.lookup_direct("/XObject", pages[0].resources) {
    Some(Dictionary(_) as obj) => obj
    _ => fail("expected inherited /XObject resources")
  }
  match xobjects.lookup_immediate("/Fm1") {
    Some(Indirect(n)) => assert_eq(n, form_num)
    _ => fail("expected /Fm1 form reference")
  }
  match xobjects.lookup_immediate("/Im1") {
    Some(Indirect(n)) => assert_eq(n, image_num)
    _ => fail("expected /Im1 image reference")
  }
  match pdf.lookup_direct("/Subtype", pdf.lookup_obj(form_num)) {
    Some(Name(name)) if name.equal_string_bytes("/Form") => ()
    _ => fail("expected form xobject subtype")
  }
  match pdf.lookup_direct("/Width", pdf.lookup_obj(image_num)) {
    Some(Integer(2)) => ()
    _ => fail("expected image width")
  }
}

///|
test "object facts contract keeps link annotation geometry and uri action" {
  let pdf0 = @pdf.Pdf::empty()
  let page_base : @pdf.PdfObject = Dictionary([
    ("/Type", object_facts_name("/Page")),
    ("/MediaBox", object_facts_rect(0.0, 0.0, 300.0, 200.0)),
  ])
  let page_num = pdf0.addobj(page_base)
  let link_rect = object_facts_rect(50.0, 40.0, 150.0, 80.0)
  let link_num = pdf0.addobj(
    Dictionary([
      ("/Type", object_facts_name("/Annot")),
      ("/Subtype", object_facts_name("/Link")),
      ("/Rect", link_rect),
      (
        "/A",
        Dictionary([
          ("/S", object_facts_name("/URI")),
          ("/URI", String("https://example.test/link")),
        ]),
      ),
    ]),
  )
  pdf0.addobj_given_num(
    (page_num, page_base.add_entry("/Annots", Array([Indirect(link_num)]))),
  )
  let pdf = object_facts_single_page_pdf(pdf0, page_num, [], [])
  let page = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()[0]
  match page.rest.lookup_immediate("/Annots") {
    Some(Array([Indirect(n)])) => assert_eq(n, link_num)
    _ => fail("expected page /Annots link reference")
  }
  let link = pdf.lookup_obj(link_num)
  match pdf.lookup_direct("/Subtype", link) {
    Some(Name(name)) if name.equal_string_bytes("/Link") => ()
    _ => fail("expected link annotation subtype")
  }
  match pdf.lookup_direct("/Rect", link) {
    Some(rect) => object_facts_assert_rect(pdf, rect, (50.0, 40.0, 150.0, 80.0))
    None => fail("expected link /Rect")
  }
  let action = match pdf.lookup_direct("/A", link) {
    Some(Dictionary(_) as obj) => obj
    _ => fail("expected link /A action")
  }
  match pdf.lookup_direct("/S", action) {
    Some(Name(name)) if name.equal_string_bytes("/URI") => ()
    _ => fail("expected URI action")
  }
  match pdf.lookup_direct("/URI", action) {
    Some(String(uri)) => assert_eq(uri, "https://example.test/link")
    _ => fail("expected URI string")
  }
}

///|
test "object facts contract keeps widget annotation and acroform facts" {
  let pdf0 = @pdf.Pdf::empty()
  let page_base : @pdf.PdfObject = Dictionary([
    ("/Type", object_facts_name("/Page")),
    ("/MediaBox", object_facts_rect(0.0, 0.0, 300.0, 200.0)),
  ])
  let page_num = pdf0.addobj(page_base)
  let appearance_dict : @pdf.PdfObject = Dictionary([
    ("/Type", object_facts_name("/XObject")),
    ("/Subtype", object_facts_name("/Form")),
    ("/BBox", object_facts_rect(0.0, 0.0, 40.0, 12.0)),
  ])
  let appearance_num = pdf0.addobj(
    Stream(Ref((appearance_dict, @pdf.Stream::Got(@pdfio.mkbytes(0))))),
  )
  let widget_rect = object_facts_rect(20.0, 30.0, 180.0, 54.0)
  let widget_num = pdf0.addobj(
    Dictionary([
      ("/Type", object_facts_name("/Annot")),
      ("/Subtype", object_facts_name("/Widget")),
      ("/Rect", widget_rect),
      ("/T", String("name")),
      ("/TU", String("Full name")),
      ("/V", String("Ada Lovelace")),
      ("/AP", Dictionary([("/N", Indirect(appearance_num))])),
    ]),
  )
  pdf0.addobj_given_num(
    (page_num, page_base.add_entry("/Annots", Array([Indirect(widget_num)]))),
  )
  let acroform : @pdf.PdfObject = Dictionary([
    ("/Fields", Array([Indirect(widget_num)])),
    ("/NeedAppearances", Boolean(true)),
  ])
  let pdf = object_facts_single_page_pdf(pdf0, page_num, [], [
    ("/AcroForm", acroform),
  ])
  let catalog = pdf.catalog_of_pdf()
  let fields = match pdf.lookup_direct("/AcroForm", catalog) {
    Some(Dictionary(_) as form) =>
      match pdf.lookup_direct("/Fields", form) {
        Some(Array(fields)) => fields
        _ => fail("expected AcroForm /Fields")
      }
    _ => fail("expected catalog /AcroForm")
  }
  match fields {
    [Indirect(n)] => assert_eq(n, widget_num)
    _ => fail("expected widget in AcroForm fields")
  }
  let page = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()[0]
  match page.rest.lookup_immediate("/Annots") {
    Some(Array([Indirect(n)])) => assert_eq(n, widget_num)
    _ => fail("expected page /Annots widget reference")
  }
  let widget = pdf.lookup_obj(widget_num)
  match pdf.lookup_direct("/Subtype", widget) {
    Some(Name(name)) if name.equal_string_bytes("/Widget") => ()
    _ => fail("expected widget subtype")
  }
  match pdf.lookup_direct("/T", widget) {
    Some(String(name)) => assert_eq(name, "name")
    _ => fail("expected /T")
  }
  match pdf.lookup_direct("/TU", widget) {
    Some(String(label)) => assert_eq(label, "Full name")
    _ => fail("expected /TU")
  }
  match pdf.lookup_direct("/V", widget) {
    Some(String(value)) => assert_eq(value, "Ada Lovelace")
    _ => fail("expected /V")
  }
  match pdf.lookup_direct("/Rect", widget) {
    Some(rect) => object_facts_assert_rect(pdf, rect, (20.0, 30.0, 180.0, 54.0))
    None => fail("expected widget /Rect")
  }
  match pdf.lookup_direct("/AP", widget) {
    Some(Dictionary(_) as ap) =>
      match ap.lookup_immediate("/N") {
        Some(Indirect(n)) => assert_eq(n, appearance_num)
        _ => fail("expected raw widget normal appearance reference")
      }
    _ => fail("expected widget appearance dictionary")
  }
  match pdf.lookup_chain(widget, ["/AP", "/N"][:]) {
    Some(Stream(_)) => ()
    _ => fail("expected direct widget normal appearance stream")
  }
}

///|
test "object facts contract keeps outline title and destination target" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let refs = pdf.page_reference_numbers()
  let mark : @pdfmarks.Bookmark = {
    level: 0,
    text: "Intro",
    target: @pdfdest.Destination::XYZ(
      @pdfdest.TargetPage::PageObject(refs[0]),
      Some(12.0),
      Some(34.0),
      Some(1.25),
    ),
    isopen: true,
    colour: (0.0, 0.0, 0.0),
    flags: 0,
  }
  let pdf_with = @pdfmarks.PdfMarks::new(pdf).add_bookmarks([mark])
  let catalog = pdf_with.catalog_of_pdf()
  let outlines = match pdf_with.lookup_direct("/Outlines", catalog) {
    Some(obj) => obj
    None => fail("expected catalog /Outlines")
  }
  let first = match pdf_with.lookup_direct("/First", outlines) {
    Some(obj) => obj
    None => fail("expected outlines /First")
  }
  match pdf_with.lookup_direct("/Title", first) {
    Some(String(title)) => assert_eq(title, "Intro")
    _ => fail("expected outline title")
  }
  let dest_obj = match pdf_with.lookup_direct("/Dest", first) {
    Some(obj) => obj
    None => fail("expected outline /Dest")
  }
  match @pdfdest.Destination::read(pdf_with, dest_obj, shallow=true) {
    @pdfdest.Destination::XYZ(
      @pdfdest.TargetPage::PageObject(n),
      Some(left),
      Some(top),
      Some(zoom)
    ) => {
      assert_eq(n, refs[0])
      object_facts_close(left, 12.0)
      object_facts_close(top, 34.0)
      object_facts_close(zoom, 1.25)
    }
    _ => fail("expected XYZ outline destination")
  }
}
