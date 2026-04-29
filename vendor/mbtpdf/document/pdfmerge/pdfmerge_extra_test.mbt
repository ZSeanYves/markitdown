///|
fn merge_rect() -> @pdf.PdfObject {
  Array([Real(0.0), Real(0.0), Real(100.0), Real(100.0)])
}

///|
fn make_pdf_pages(count : Int) -> @pdf.Pdf raise {
  let rect = merge_rect()
  let pages = Array::new(capacity=count)
  for _ in 0..<count {
    pages.push(@pdfpage.Page::custom(rect))
  }
  let (pdf, pageroot) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree(
    pages,
  )
  @pdfpage.PdfPageDoc::new(pdf).add_root(pageroot, [])
}

///|

///|
fn add_names_dests(
  pdf : @pdf.Pdf,
  entries : Array[(String, @pdf.PdfObject)],
) -> Unit raise {
  let tree = @pdftree.PdfTree::new(pdf).build_name_tree(false, entries)
  let names_dict : @pdf.PdfObject = Dictionary([("/Dests", tree)])
  set_catalog_entry(pdf, "/Names", names_dict)
}

///|
fn page_ref(pdf : @pdf.Pdf, index : Int) -> Int raise {
  let refs = pdf.page_reference_numbers()
  refs[index - 1]
}

///|
fn dest_dict_for_page(pdf : @pdf.Pdf, index : Int) -> @pdf.PdfObject raise {
  let target = @pdfdest.TargetPage::PageObject(page_ref(pdf, index))
  let dest = @pdfdest.Destination::Fit(target)
  Dictionary([("/D", dest.to_pdf_object())])
}

///|
fn dest_dict(dest : @pdfdest.Destination) -> @pdf.PdfObject {
  Dictionary([("/D", dest.to_pdf_object())])
}

///|
fn with_version(pdf : @pdf.Pdf, major : Int, minor : Int) -> @pdf.Pdf {
  {
    major,
    minor,
    root: pdf.root,
    objects: pdf.objects,
    trailerdict: pdf.trailerdict,
    was_linearized: pdf.was_linearized,
    saved_encryption: pdf.saved_encryption,
  }
}

///|
test "merge_pdfs keeps named and action bookmarks while dropping out of range" {
  let pdf = make_pdf_pages(2)
  let entries : Array[(String, @pdf.PdfObject)] = [
    ("/DestA", dest_dict_for_page(pdf, 1)),
    ("DestB", dest_dict_for_page(pdf, 1)),
  ]
  add_names_dests(pdf, entries)
  let action : @pdf.PdfObject = Dictionary([
    ("/S", Name(@pdf.PdfName::of_string("/GoTo"))),
    ("/D", String("DestB")),
  ])
  let bookmarks : Array[@pdfmarks.Bookmark] = [
    {
      level: 0,
      text: "Named",
      target: @pdfdest.Destination::NamedDestination(
        @pdf.PdfName::of_string("/DestA"),
      ),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 0,
      text: "Action",
      target: @pdfdest.Destination::Action(action),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 0,
      text: "Drop",
      target: @pdfdest.Destination::Fit(
        @pdfdest.TargetPage::PageObject(page_ref(pdf, 2)),
      ),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
  ]
  let pdf = @pdfmarks.PdfMarks::new(pdf).add_bookmarks(bookmarks)
  let merged = PdfMerger::new(["one"], [pdf], [[1]]).merge_pdfs(
    false,
    false,
    process_struct_trees=false,
    add_toplevel_document=false,
  )
  let marks = @pdfmarks.PdfMarks::new(merged).read_bookmarks(
    preserve_actions=true,
  )
  assert_eq(marks.length(), 2)
}

///|
test "merge_pdfs handles malformed names and optional catalog entries" {
  let pdf1 = make_pdf_pages(1)
  let pdf2 = make_pdf_pages(1)
  let bad_tree : @pdf.PdfObject = Dictionary([
    ("/Names", Array([String("A"), Null, String("B")])),
  ])
  let names_dict : @pdf.PdfObject = Dictionary([("/Dests", bad_tree)])
  set_catalog_entry(pdf1, "/Names", names_dict)
  set_catalog_entry(
    pdf1,
    "/OCProperties",
    Dictionary([("/OCGs", Array([Name(@pdf.PdfName::of_string("/OCG1"))]))]),
  )
  set_catalog_entry(pdf1, "/AcroForm", Null)
  set_catalog_entry(pdf2, "/AcroForm", Dictionary([("/Fields", Array([Null]))]))
  let merged = @pdfe.with_logger(_ => (), fn() {
    PdfMerger::new(["one", "two"], [pdf1, pdf2], [[1], [1]]).merge_pdfs(
      false,
      false,
      process_struct_trees=false,
      add_toplevel_document=false,
    )
  })
  let catalog = merged.catalog_of_pdf()
  match merged.lookup_direct("/OCProperties", catalog) {
    Some(ocp) =>
      match merged.lookup_direct("/OCGs", ocp) {
        Some(Array(arr)) => assert_eq(arr.length(), 1)
        _ => fail("expected /OCGs array")
      }
    _ => fail("expected /OCProperties")
  }
  match merged.lookup_direct("/AcroForm", catalog) {
    Some(form) =>
      match merged.lookup_direct("/Fields", form) {
        Some(Array(arr)) => assert_eq(arr.length(), 1)
        _ => fail("expected /Fields array")
      }
    _ => fail("expected /AcroForm")
  }
}

///|
test "merge_pdfs warns on duplicate names with struct trees" {
  let pdf1 = @pdfpage.PdfPageDoc::minimum_valid()
  let pdf2 = @pdfpage.PdfPageDoc::minimum_valid()
  let res : Result[@pdf.Pdf, Error] = try? @pdfe.with_logger(_ => (), fn() {
    PdfMerger::new(["dup", "dup"], [pdf1, pdf2], [[1], [1]]).merge_pdfs(
      false,
      false,
      process_struct_trees=true,
      add_toplevel_document=false,
    )
  })
  match res {
    Ok(merged) =>
      assert_eq(@pdfpage.PdfPageDoc::new(merged).pages_of_pagetree_quick(), 2)
    Err(err) => fail("merge_pdfs failed: \{err}")
  }
}

///|
test "merge_pdfs rewrites string and legacy named bookmarks" {
  let pdf = make_pdf_pages(1)
  // Name tree entry for string destinations.
  add_names_dests(pdf, [("DestB", dest_dict_for_page(pdf, 1))])
  // Legacy catalog /Dests dictionary for name destinations.
  let target = @pdfdest.TargetPage::PageObject(page_ref(pdf, 1))
  let dest_obj = @pdfdest.Destination::Fit(target).to_pdf_object()
  set_catalog_entry(pdf, "/Dests", Dictionary([("/DestA", dest_obj)]))
  let bookmarks : Array[@pdfmarks.Bookmark] = [
    {
      level: 0,
      text: "String",
      target: @pdfdest.Destination::StringDestination("DestB"),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 0,
      text: "Named",
      target: @pdfdest.Destination::NamedDestination(
        @pdf.PdfName::of_string("/DestA"),
      ),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 0,
      text: "Null",
      target: @pdfdest.Destination::NullDestination,
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
  ]
  let pdf = @pdfmarks.PdfMarks::new(pdf).add_bookmarks(bookmarks)
  let merged = PdfMerger::new(["one"], [pdf], [[1]]).merge_pdfs(
    false,
    false,
    process_struct_trees=false,
    add_toplevel_document=false,
  )
  let marks = @pdfmarks.PdfMarks::new(merged).read_bookmarks(
    preserve_actions=true,
  )
  assert_true(marks.length() >= 2)
}

///|
test "merge_pdfs uses highest version and removes duplicates" {
  let pdf1 = with_version(@pdfpage.PdfPageDoc::minimum_valid(), 1, 4)
  let pdf2 = with_version(@pdfpage.PdfPageDoc::minimum_valid(), 1, 6)
  let res : Result[@pdf.Pdf, Error] = try? PdfMerger::new(
    ["one", "two"],
    [pdf1, pdf2],
    [[1], [1]],
  ).merge_pdfs(
    false,
    true,
    process_struct_trees=false,
    add_toplevel_document=false,
  )
  match res {
    Ok(merged) => {
      assert_eq(merged.major, 1)
      assert_eq(merged.minor, 6)
    }
    Err(@pdf.PdfError::Msg(msg)) => fail("merge_pdfs failed: \{msg}")
    Err(err) => fail("merge_pdfs failed: \{err}")
  }
}

///|
test "remove_duplicate_fonts updates object_stream_ids" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([("/Length", Integer(1))])
  let stream1 : @pdf.PdfObject = Stream(
    Ref::new((dict, @pdf.Stream::Got([0x01]))),
  )
  let stream2 : @pdf.PdfObject = Stream(
    Ref::new((dict, @pdf.Stream::Got([0x01]))),
  )
  let obj1 = pdf.addobj(stream1)
  let obj2 = pdf.addobj(stream2)
  pdf.objects.object_stream_ids.set(obj1, 10)
  pdf.objects.object_stream_ids.set(obj2, 20)
  PdfMergeDoc::new(pdf).remove_duplicate_fonts()
  assert_eq(pdf.objects.object_stream_ids.length(), 1)
}

///|
test "remove_duplicate_fonts keeps distinct stream lengths" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([("/Length", Integer(1))])
  let stream1 : @pdf.PdfObject = Stream(
    Ref::new((dict, @pdf.Stream::Got([0x01]))),
  )
  let stream2 : @pdf.PdfObject = Stream(
    Ref::new((dict, @pdf.Stream::Got([0x01, 0x02]))),
  )
  ignore(pdf.addobj(stream1))
  ignore(pdf.addobj(stream2))
  let before = pdf.objcard()
  PdfMergeDoc::new(pdf).remove_duplicate_fonts()
  assert_eq(pdf.objcard(), before)
}

///|
test "merge_pdfs errors on empty inputs" {
  let res : Result[@pdf.Pdf, Error] = try? PdfMerger::new([], [], []).merge_pdfs(
    false,
    false,
    process_struct_trees=false,
    add_toplevel_document=false,
  )
  assert_true(res is Err(_))
}

///|
test "merge_pdfs errors on mismatched names" {
  let pdf = make_pdf_pages(1)
  let res : Result[@pdf.Pdf, Error] = try? PdfMerger::new(
    ["one", "two"],
    [pdf],
    [[1]],
  ).merge_pdfs(
    false,
    false,
    process_struct_trees=false,
    add_toplevel_document=false,
  )
  assert_true(res is Err(_))
}

///|
test "merge_pdfs errors on page out of range" {
  let pdf = make_pdf_pages(1)
  let res : Result[@pdf.Pdf, Error] = try? PdfMerger::new(["one"], [pdf], [[2]]).merge_pdfs(
    false,
    false,
    process_struct_trees=false,
    add_toplevel_document=false,
  )
  assert_true(res is Err(_))
}

///|
test "merge_pdfs errors on non-positive page indices" {
  let pdf = make_pdf_pages(1)
  let res : Result[@pdf.Pdf, Error] = try? PdfMerger::new(["one"], [pdf], [[0]]).merge_pdfs(
    false,
    false,
    process_struct_trees=false,
    add_toplevel_document=false,
  )
  assert_true(res is Err(_))
}

///|
test "merge_pdfs rewrites and preserves diverse destination bookmark targets" {
  fn mk_mark(
    text : String,
    target : @pdfdest.Destination,
  ) -> @pdfmarks.Bookmark {
    { level: 0, text, target, isopen: false, colour: (0.0, 0.0, 0.0), flags: 0 }
  }

  let pdf = make_pdf_pages(2)
  let tp1 = @pdfdest.TargetPage::PageObject(page_ref(pdf, 1))

  // Legacy catalog /Dests dictionary (used for NamedDestination lookups).
  let legacy_fit = @pdfdest.Destination::Fit(tp1).to_pdf_object()
  let legacy_other = @pdfdest.Destination::Fit(
    @pdfdest.TargetPage::OtherDocPageNumber(1),
  ).to_pdf_object()
  set_catalog_entry(
    pdf,
    "/Dests",
    Dictionary([("/LegacyFit", legacy_fit), ("/LegacyOther", legacy_other)]),
  )
  let bookmarks : Array[@pdfmarks.Bookmark] = [
    mk_mark(
      "LegacyFit",
      @pdfdest.Destination::NamedDestination(
        @pdf.PdfName::of_string("/LegacyFit"),
      ),
    ),
    mk_mark(
      "LegacyOther",
      @pdfdest.Destination::NamedDestination(
        @pdf.PdfName::of_string("/LegacyOther"),
      ),
    ),
    mk_mark("DirectFitH", @pdfdest.Destination::FitH(tp1, Some(0.0))),
    mk_mark("DirectFitV", @pdfdest.Destination::FitV(tp1, Some(0.0))),
    mk_mark("DirectFitR", @pdfdest.Destination::FitR(tp1, 0.0, 0.0, 1.0, 1.0)),
    mk_mark("DirectFitB", @pdfdest.Destination::FitB(tp1)),
    mk_mark("DirectFitBH", @pdfdest.Destination::FitBH(tp1, Some(0.0))),
    mk_mark("DirectFitBV", @pdfdest.Destination::FitBV(tp1, Some(0.0))),
  ]
  let pdf = @pdfmarks.PdfMarks::new(pdf).add_bookmarks(bookmarks)
  let merged = PdfMerger::new(["one"], [pdf], [[1]]).merge_pdfs(
    false,
    false,
    process_struct_trees=false,
    add_toplevel_document=false,
  )
  let marks = @pdfmarks.PdfMarks::new(merged).read_bookmarks(
    preserve_actions=true,
  )
  let texts = marks.map(m => m.text)
  assert_true(texts.contains("LegacyFit"))
  assert_true(texts.contains("DirectFitH"))
  assert_true(texts.contains("DirectFitV"))
  assert_true(texts.contains("DirectFitR"))
  assert_true(texts.contains("DirectFitB"))
  assert_true(texts.contains("DirectFitBH"))
  assert_true(texts.contains("DirectFitBV"))
  // Some destinations should be dropped because they don't map to a selected page.
  assert_true(!texts.contains("LegacyOther"))
}

///|
test "merge_pdfs resolves NamedDestination via name tree when /Dests missing" {
  let pdf = make_pdf_pages(1)
  let tp1 = @pdfdest.TargetPage::PageObject(page_ref(pdf, 1))
  add_names_dests(pdf, [
    ("/OnlyInTree", dest_dict(@pdfdest.Destination::Fit(tp1))),
    ("TreeStr", dest_dict(@pdfdest.Destination::FitH(tp1, Some(0.0)))),
    (
      "/OtherDocNamed",
      dest_dict(
        @pdfdest.Destination::Fit(@pdfdest.TargetPage::OtherDocPageNumber(1)),
      ),
    ),
    ("/NoDNamed", Dictionary([])),
    (
      "OtherDocStr",
      dest_dict(
        @pdfdest.Destination::Fit(@pdfdest.TargetPage::OtherDocPageNumber(1)),
      ),
    ),
    ("NoDStr", Dictionary([])),
  ])
  let action_goto : @pdf.PdfObject = Dictionary([
    ("/S", Name(@pdf.PdfName::of_string("/GoTo"))),
    ("/D", String("TreeStr")),
  ])
  let action_bad_d : @pdf.PdfObject = Dictionary([
    ("/S", Name(@pdf.PdfName::of_string("/GoTo"))),
    ("/D", Integer(0)),
  ])
  let action_bad_s : @pdf.PdfObject = Dictionary([
    ("/S", Name(@pdf.PdfName::of_string("/NotGoTo"))),
    ("/D", String("TreeStr")),
  ])
  let action_missing_dest : @pdf.PdfObject = Dictionary([
    ("/S", Name(@pdf.PdfName::of_string("/GoTo"))),
    ("/D", String("MissingStr")),
  ])
  let action_no_d : @pdf.PdfObject = Dictionary([
    ("/S", Name(@pdf.PdfName::of_string("/GoTo"))),
    ("/D", String("NoDStr")),
  ])
  let bookmarks : Array[@pdfmarks.Bookmark] = [
    {
      level: 0,
      text: "TreeOnly",
      target: @pdfdest.Destination::NamedDestination(
        @pdf.PdfName::of_string("/OnlyInTree"),
      ),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 0,
      text: "TreeStr",
      target: @pdfdest.Destination::StringDestination("TreeStr"),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 0,
      text: "TreeAction",
      target: @pdfdest.Destination::Action(action_goto),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 0,
      text: "OtherDocNamed",
      target: @pdfdest.Destination::NamedDestination(
        @pdf.PdfName::of_string("/OtherDocNamed"),
      ),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 0,
      text: "NoDNamed",
      target: @pdfdest.Destination::NamedDestination(
        @pdf.PdfName::of_string("/NoDNamed"),
      ),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 0,
      text: "OtherDocStr",
      target: @pdfdest.Destination::StringDestination("OtherDocStr"),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 0,
      text: "NoDStr",
      target: @pdfdest.Destination::StringDestination("NoDStr"),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 0,
      text: "MissingStr",
      target: @pdfdest.Destination::StringDestination("MissingStr"),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 0,
      text: "BadActionD",
      target: @pdfdest.Destination::Action(action_bad_d),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 0,
      text: "BadActionS",
      target: @pdfdest.Destination::Action(action_bad_s),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 0,
      text: "BadActionMissingDest",
      target: @pdfdest.Destination::Action(action_missing_dest),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 0,
      text: "BadActionNoD",
      target: @pdfdest.Destination::Action(action_no_d),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
  ]
  let pdf = @pdfmarks.PdfMarks::new(pdf).add_bookmarks(bookmarks)
  let merged = PdfMerger::new(["one"], [pdf], [[1]]).merge_pdfs(
    false,
    false,
    process_struct_trees=false,
    add_toplevel_document=false,
  )
  let marks = @pdfmarks.PdfMarks::new(merged).read_bookmarks(
    preserve_actions=true,
  )
  let texts = marks.map(m => m.text)
  assert_true(texts.contains("TreeOnly"))
  assert_true(texts.contains("TreeStr"))
  assert_true(texts.contains("TreeAction"))
  assert_true(!texts.contains("OtherDocNamed"))
  assert_true(!texts.contains("NoDNamed"))
  assert_true(!texts.contains("OtherDocStr"))
  assert_true(!texts.contains("NoDStr"))
  assert_true(!texts.contains("MissingStr"))
  assert_true(!texts.contains("BadActionD"))
  assert_true(!texts.contains("BadActionS"))
  assert_true(!texts.contains("BadActionMissingDest"))
  assert_true(!texts.contains("BadActionNoD"))
}

///|
test "merge_pdfs drops NamedDestination when no destination trees exist" {
  let pdf = make_pdf_pages(1)
  let bookmarks : Array[@pdfmarks.Bookmark] = [
    {
      level: 0,
      text: "MissingDest",
      target: @pdfdest.Destination::NamedDestination(
        @pdf.PdfName::of_string("/MissingDest"),
      ),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
  ]
  let pdf = @pdfmarks.PdfMarks::new(pdf).add_bookmarks(bookmarks)
  let merged = PdfMerger::new(["one"], [pdf], [[1]]).merge_pdfs(
    false,
    false,
    process_struct_trees=false,
    add_toplevel_document=false,
  )
  let marks = @pdfmarks.PdfMarks::new(merged).read_bookmarks(
    preserve_actions=true,
  )
  assert_eq(marks.length(), 0)
}
