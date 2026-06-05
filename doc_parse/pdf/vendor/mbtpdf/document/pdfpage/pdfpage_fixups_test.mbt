///|
fn fixups_sample_rect() -> @pdf.PdfObject {
  Array([Real(0.0), Real(0.0), Real(100.0), Real(100.0)])
}

///|
fn annot_numbers(pdf : @pdf.Pdf, page_obj : @pdf.PdfObject) -> Array[Int] {
  match (pdf.lookup_direct("/Annots", page_obj) : @pdf.PdfObject?) {
    Some(Array(arr)) =>
      arr.filter_map(fn(obj) {
        match (obj : @pdf.PdfObject) {
          Indirect(i) => Some(i)
          _ => None
        }
      })
    _ => []
  }
}

///|
test "add_pagetree handles large page sets" {
  let pages : Array[@pdfpage.Page] = []
  for _ in 0..<12 {
    pages.push(@pdfpage.Page::custom(fixups_sample_rect()))
  }
  let (pdf0, pageroot) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree(
    pages,
  )
  let pdf = @pdfpage.PdfPageDoc::new(pdf0).add_root(pageroot, [])
  assert_eq(@pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree().length(), 12)
}

///|
test "fixup_duplicate_annots clones duplicates and updates popup" {
  let pdf0 = @pdf.Pdf::empty()
  let page = @pdfpage.Page::custom(fixups_sample_rect())
  let (pdf1, pageroot) = @pdfpage.PdfPageDoc::new(pdf0).add_pagetree([
    page, page,
  ])
  let pdf = @pdfpage.PdfPageDoc::new(pdf1).add_root(pageroot, [])
  let annot_base : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Text"))),
  ])
  let unrelated_num = pdf.addobj(annot_base)
  let annot_num = pdf.addobj(annot_base)
  let annot_with_popup = annot_base
    .add_entry("/Popup", Indirect(annot_num))
    .add_entry("/Parent", Indirect(unrelated_num))
  pdf.addobj_given_num((annot_num, annot_with_popup))
  let refs = pdf.page_reference_numbers()
  for refnum in refs {
    let page_obj = pdf.lookup_obj(refnum)
    let annots : @pdf.PdfObject = Array([Indirect(annot_num), Integer(0)])
    let updated = page_obj.add_entry("/Annots", annots)
    pdf.addobj_given_num((refnum, updated))
  }
  @pdfpage.PdfPageDoc::new(pdf).fixup_duplicate_annots()
  let refs2 = pdf.page_reference_numbers()
  let annots1 = annot_numbers(pdf, pdf.lookup_obj(refs2[0]))
  let annots2 = annot_numbers(pdf, pdf.lookup_obj(refs2[1]))
  assert_eq(annots1.length(), 1)
  assert_eq(annots2.length(), 1)
  assert_true(annots1[0] != annots2[0])
  match (pdf.lookup_obj(annots2[0]) : @pdf.PdfObject) {
    Null => fail("expected copied annotation")
    _ => ()
  }
}

///|
test "fixup_destinations removes nulled entries" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  let null_num = pdf.addobj(Null)
  let dead_dest : @pdf.PdfObject = Array([
    Indirect(null_num),
    Name(@pdf.PdfName::of_string("/Fit")),
  ])
  let tree_ctx = @pdftree.PdfTree::new(pdf)
  let tree = tree_ctx.build_name_tree(false, [("Dead", dead_dest)])
  let names : @pdf.PdfObject = Dictionary([("/Dests", tree)])
  let catalog = pdf.catalog_of_pdf()
  let updated_catalog = catalog.add_entry("/Names", names)
  pdf.addobj_given_num((pdf.root, updated_catalog))
  let trailerdict = pdf.trailerdict.add_entry("/Root", updated_catalog)
  let pdf_direct : @pdf.Pdf = {
    major: pdf.major,
    minor: pdf.minor,
    root: pdf.root,
    objects: pdf.objects,
    trailerdict,
    was_linearized: pdf.was_linearized,
    saved_encryption: pdf.saved_encryption,
  }
  @pdfpage.PdfPageDoc::new(pdf_direct).fixup_destinations()
  let updated_tree = match
    pdf_direct.lookup_chain(pdf_direct.trailerdict, [
      "/Root", "/Names", "/Dests",
    ]) {
    Some(t) => t
    None => fail("expected destinations tree")
  }
  let entries = @pdftree.PdfTree::new(pdf_direct).read_name_tree(updated_tree)
  assert_eq(entries.length(), 0)
}

///|
test "fixup_parents raises without page tree" {
  let res : Result[Unit, Error] = try? @pdfpage.PdfPageDoc::new(
    @pdf.Pdf::empty(),
  ).fixup_parents()
  match res {
    Err(_) => ()
    _ => fail("expected missing /Pages error")
  }
}

///|
test "fixup_parents skips direct kids" {
  let pdf0 = @pdf.Pdf::empty()
  let page : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/Page"))),
    ("/Resources", Dictionary([])),
    ("/MediaBox", fixups_sample_rect()),
  ])
  let pages : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/Pages"))),
    ("/Kids", Array([page])),
    ("/Count", Integer(1)),
  ])
  let pages_num = pdf0.addobj(pages)
  let pdf = @pdfpage.PdfPageDoc::new(pdf0).add_root(pages_num, [])
  @pdfpage.PdfPageDoc::new(pdf).fixup_parents()
}

///|
test "fixup_duplicate_pages errors on malformed root entries" {
  let base = @pdf.Pdf::empty()
  // Root is not a dictionary.
  base.addobj_given_num((1, @pdf.PdfObject::Integer(0)))
  let pdf_bad_root : @pdf.Pdf = {
    major: base.major,
    minor: base.minor,
    root: 1,
    objects: base.objects,
    trailerdict: base.trailerdict,
    was_linearized: base.was_linearized,
    saved_encryption: base.saved_encryption,
  }
  let bad_root_res : Result[Unit, Error] = try? @pdfpage.PdfPageDoc::new(
    pdf_bad_root,
  ).fixup_duplicate_pages()
  assert_true(bad_root_res is Err(_))

  // Root dictionary missing /Pages.
  let base2 = @pdf.Pdf::empty()
  let root_num = base2.addobj(@pdf.PdfObject::Dictionary([]))
  let pdf_missing_pages : @pdf.Pdf = {
    major: base2.major,
    minor: base2.minor,
    root: root_num,
    objects: base2.objects,
    trailerdict: base2.trailerdict,
    was_linearized: base2.was_linearized,
    saved_encryption: base2.saved_encryption,
  }
  let missing_pages_res : Result[Unit, Error] = try? @pdfpage.PdfPageDoc::new(
    pdf_missing_pages,
  ).fixup_duplicate_pages()
  assert_true(missing_pages_res is Err(_))

  // Root dictionary has /Pages but not an indirect reference.
  let base3 = @pdf.Pdf::empty()
  let root_num3 = base3.addobj(
    @pdf.PdfObject::Dictionary([("/Pages", @pdf.PdfObject::Integer(1))]),
  )
  let pdf_pages_not_indirect : @pdf.Pdf = {
    major: base3.major,
    minor: base3.minor,
    root: root_num3,
    objects: base3.objects,
    trailerdict: base3.trailerdict,
    was_linearized: base3.was_linearized,
    saved_encryption: base3.saved_encryption,
  }
  let pages_not_indirect_res : Result[Unit, Error] = try? @pdfpage.PdfPageDoc::new(
    pdf_pages_not_indirect,
  ).fixup_duplicate_pages()
  assert_true(pages_not_indirect_res is Err(_))
}

///|
test "fixup_duplicate_pages scans malformed page trees" {
  let base = @pdf.Pdf::empty()
  // Pages node with a non-indirect kid.
  let pages_num = base.addobj(
    @pdf.PdfObject::Dictionary([
      ("/Type", Name(@pdf.PdfName::of_string("/Pages"))),
      ("/Kids", Array([@pdf.PdfObject::Integer(1)])),
      ("/Count", Integer(1)),
    ]),
  )
  let root_num = base.addobj(
    @pdf.PdfObject::Dictionary([("/Pages", Indirect(pages_num))]),
  )
  let pdf : @pdf.Pdf = {
    major: base.major,
    minor: base.minor,
    root: root_num,
    objects: base.objects,
    trailerdict: base.trailerdict,
    was_linearized: base.was_linearized,
    saved_encryption: base.saved_encryption,
  }
  @pdfpage.PdfPageDoc::new(pdf).fixup_duplicate_pages()

  // Pages node with /Kids not an array (forces unordered traversal fallback).
  let base2 = @pdf.Pdf::empty()
  let pages_num2 = base2.addobj(
    @pdf.PdfObject::Dictionary([
      ("/Type", Name(@pdf.PdfName::of_string("/Pages"))),
      ("/Kids", Integer(1)),
      ("/Count", Integer(1)),
    ]),
  )
  let root_num2 = base2.addobj(
    @pdf.PdfObject::Dictionary([("/Pages", Indirect(pages_num2))]),
  )
  let pdf2 : @pdf.Pdf = {
    major: base2.major,
    minor: base2.minor,
    root: root_num2,
    objects: base2.objects,
    trailerdict: base2.trailerdict,
    was_linearized: base2.was_linearized,
    saved_encryption: base2.saved_encryption,
  }
  @pdfpage.PdfPageDoc::new(pdf2).fixup_duplicate_pages()
}
