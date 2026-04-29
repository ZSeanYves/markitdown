///|
fn minimum_valid_pdf() -> @pdf.Pdf raise {
  let pdf = @pdf.Pdf::empty()
  let pages_root_num = pdf.addobj(
    Dictionary([
      ("/Type", Name(@pdf.PdfName::of_string("/Pages"))),
      ("/Kids", Array([])),
      ("/Count", Integer(1)),
    ]),
  )
  let page_num = pdf.addobj(
    Dictionary([
      ("/Type", Name(@pdf.PdfName::of_string("/Page"))),
      ("/Parent", Indirect(pages_root_num)),
      ("/MediaBox", Array([Integer(0), Integer(0), Integer(100), Integer(100)])),
    ]),
  )
  pdf.addobj_given_num(
    (
      pages_root_num,
      Dictionary([
        ("/Type", Name(@pdf.PdfName::of_string("/Pages"))),
        ("/Kids", Array([Indirect(page_num)])),
        ("/Count", Integer(1)),
      ]),
    ),
  )
  let catalog_num = pdf.addobj(
    Dictionary([
      ("/Type", Name(@pdf.PdfName::of_string("/Catalog"))),
      ("/Pages", Indirect(pages_root_num)),
    ]),
  )
  let trailerdict = pdf.trailerdict.add_entry("/Root", Indirect(catalog_num))
  {
    major: pdf.major,
    minor: pdf.minor,
    root: catalog_num,
    objects: pdf.objects,
    trailerdict,
    was_linearized: pdf.was_linearized,
    saved_encryption: pdf.saved_encryption,
  }
}

///|
fn assert_close(a : Double, b : Double) -> Unit raise {
  let diff = (a - b).abs()
  assert_true(diff < 0.000001)
}

///|
fn outlines_root(pdf : @pdf.Pdf) -> @pdf.PdfObject raise {
  let catalog = pdf.catalog_of_pdf()
  match pdf.lookup_direct("/Outlines", catalog) {
    Some(obj) => obj
    None => fail("expected /Outlines")
  }
}

///|
test "string_of_bookmark includes text" {
  let mark : @pdfmarks.Bookmark = {
    level: 1,
    text: "Chapter",
    target: @pdfdest.Destination::NullDestination,
    isopen: true,
    colour: (0.1, 0.2, 0.3),
    flags: 0,
  }
  let text = mark.to_string()
  assert_true(text.contains("Chapter"))
  assert_true(text.contains("true"))
}

///|
test "remove_bookmarks clears outlines" {
  let pdf = minimum_valid_pdf()
  let marks : Array[@pdfmarks.Bookmark] = [
    {
      level: 0,
      text: "Intro",
      target: @pdfdest.Destination::NullDestination,
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
  ]
  let pdf_with = @pdfmarks.PdfMarks::new(pdf).add_bookmarks(marks)
  assert_eq(@pdfmarks.PdfMarks::new(pdf_with).read_bookmarks().length(), 1)
  let removed = @pdfmarks.PdfMarks::new(pdf_with).remove_bookmarks()
  assert_eq(@pdfmarks.PdfMarks::new(removed).read_bookmarks().length(), 0)
}

///|
test "transform_bookmark translates destination" {
  let pdf = @pdf.Pdf::empty()
  let mark : @pdfmarks.Bookmark = {
    level: 0,
    text: "Move",
    target: @pdfdest.Destination::XYZ(
      @pdfdest.TargetPage::PageObject(1),
      Some(10.0),
      Some(20.0),
      Some(1.0),
    ),
    isopen: false,
    colour: (0.0, 0.0, 0.0),
    flags: 0,
  }
  let tr = @pdftransform.TransformMatrix::translate(5.0, -3.0)
  let moved = mark.transform(pdf, tr)
  match moved.target {
    @pdfdest.Destination::XYZ(_, Some(left), Some(top), Some(zoom)) => {
      assert_close(left, 15.0)
      assert_close(top, 17.0)
      assert_close(zoom, 1.0)
    }
    _ => fail("expected transformed XYZ destination")
  }
}

///|
test "add_bookmarks links siblings and counts" {
  let pdf = minimum_valid_pdf()
  let marks : Array[@pdfmarks.Bookmark] = [
    {
      level: 0,
      text: "A",
      target: @pdfdest.Destination::NullDestination,
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 1,
      text: "A1",
      target: @pdfdest.Destination::NullDestination,
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 0,
      text: "B",
      target: @pdfdest.Destination::NullDestination,
      isopen: true,
      colour: (0.1, 0.2, 0.3),
      flags: 2,
    },
    {
      level: 1,
      text: "B1",
      target: @pdfdest.Destination::NullDestination,
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 1,
      text: "B2",
      target: @pdfdest.Destination::NullDestination,
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
  ]
  let pdf_with = @pdfmarks.PdfMarks::new(pdf).add_bookmarks(marks)
  let outlines = outlines_root(pdf_with)
  match pdf_with.lookup_direct("/Count", outlines) {
    Some(Integer(i)) => assert_eq(i, 4)
    _ => fail("expected /Count on outlines")
  }
  let first = match pdf_with.lookup_direct("/First", outlines) {
    Some(obj) => obj
    None => fail("expected /First")
  }
  let last = match pdf_with.lookup_direct("/Last", outlines) {
    Some(obj) => obj
    None => fail("expected /Last")
  }
  match
    (
      pdf_with.lookup_direct("/Title", first),
      pdf_with.lookup_direct("/Title", last),
    ) {
    (Some(String(a)), Some(String(b))) => {
      assert_eq(a, "A")
      assert_eq(b, "B")
    }
    _ => fail("expected titles")
  }
  match pdf_with.lookup_direct("/Next", first) {
    Some(next) =>
      match pdf_with.lookup_direct("/Title", next) {
        Some(String(s)) => assert_eq(s, "B")
        _ => fail("expected /Next title")
      }
    None => fail("expected /Next")
  }
  match pdf_with.lookup_direct("/Prev", last) {
    Some(prev) =>
      match pdf_with.lookup_direct("/Title", prev) {
        Some(String(s)) => assert_eq(s, "A")
        _ => fail("expected /Prev title")
      }
    None => fail("expected /Prev")
  }
  match pdf_with.lookup_direct("/Count", first) {
    Some(Integer(i)) => assert_eq(i, -1)
    _ => fail("expected negative /Count for closed node")
  }
  match pdf_with.lookup_direct("/Count", last) {
    Some(Integer(i)) => assert_eq(i, 2)
    _ => fail("expected positive /Count for open node")
  }
  let marks_read = @pdfmarks.PdfMarks::new(pdf_with).read_bookmarks()
  assert_eq(marks_read.length(), 5)
  match marks_read[2] {
    { text: "B", colour: (r, g, b), flags: f, .. } => {
      assert_close(r, 0.1)
      assert_close(g, 0.2)
      assert_close(b, 0.3)
      assert_eq(f, 2)
    }
    _ => fail("expected mark B")
  }
}

///|
test "read_bookmarks toggles action preservation" {
  let pdf = minimum_valid_pdf()
  let action : @pdf.PdfObject = Dictionary([
    ("/S", Name(@pdf.PdfName::of_string("/GoTo"))),
    ("/D", String("dest")),
  ])
  let marks : Array[@pdfmarks.Bookmark] = [
    {
      level: 0,
      text: "Action",
      target: @pdfdest.Destination::Action(action),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
  ]
  let pdf_with = @pdfmarks.PdfMarks::new(pdf).add_bookmarks(marks)
  let preserved = @pdfmarks.PdfMarks::new(pdf_with).read_bookmarks(
    preserve_actions=true,
  )
  match preserved[0].target {
    @pdfdest.Destination::Action(_) => ()
    _ => fail("expected action preserved")
  }
  let resolved = @pdfmarks.PdfMarks::new(pdf_with).read_bookmarks(
    preserve_actions=false,
  )
  match resolved[0].target {
    @pdfdest.Destination::StringDestination("dest") => ()
    _ => fail("expected string destination")
  }
}
