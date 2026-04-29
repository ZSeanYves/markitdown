///|
fn assert_close(a : Double, b : Double) -> Unit raise {
  let diff = (a - b).abs()
  assert_true(diff < 0.000001)
}

///|
test "minimum_valid_pdf has one page" {
  let pdf = @pdfpage.PdfPageDoc::minimum_valid()
  assert_eq(@pdfpage.PdfPageDoc::new(pdf).endpage(), 1)
  assert_eq(@pdfpage.PdfPageDoc::new(pdf).endpage_fast(), 1)
  assert_eq(@pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree().length(), 1)
}

///|
test "add_pagetree builds page objects" {
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(100.0),
    Real(100.0),
  ])
  let pages = [@pdfpage.Page::custom(rect), @pdfpage.Page::custom(rect)]
  let (pdf0, pageroot) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree(
    pages,
  )
  let pdf = @pdfpage.PdfPageDoc::new(pdf0).add_root(pageroot, [])
  assert_eq(@pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree().length(), 2)
  match @pdfpage.PdfPageDoc::new(pdf).page_object_number(1) {
    Some(n) => assert_true(n > 0)
    _ => fail("expected page object number")
  }
}

///|
test "pages_of_pagetree handles missing mediabox and non-stream contents" {
  let rect1 : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(100.0),
    Real(120.0),
  ])
  let rect2 : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(200.0),
    Real(220.0),
  ])
  let pages = [@pdfpage.Page::custom(rect1), @pdfpage.Page::custom(rect2)]
  let (pdf1, pageroot) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree(
    pages,
  )
  let pdf = @pdfpage.PdfPageDoc::new(pdf1).add_root(pageroot, [])
  let page1_num = match @pdfpage.PdfPageDoc::new(pdf).page_object_number(1) {
    Some(n) => n
    None => fail("expected page object number")
  }
  let page2_num = match @pdfpage.PdfPageDoc::new(pdf).page_object_number(2) {
    Some(n) => n
    None => fail("expected page object number")
  }
  let page1_obj = pdf.lookup_obj(page1_num)
  let page1_updated = page1_obj.add_entry("/Contents", Array([Integer(1)]))
  pdf.addobj_given_num((page1_num, page1_updated))
  let page2_obj = pdf.lookup_obj(page2_num)
  let page2_updated = page2_obj
    .remove_entry("/MediaBox")
    .remove_entry("/Resources")
    .add_entry("/Contents", Integer(2))
  pdf.addobj_given_num((page2_num, page2_updated))
  let out_pages = @pdfe.with_logger(_ => (), fn() {
    @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  })
  assert_eq(out_pages.length(), 2)
  assert_eq(out_pages[0].content.length(), 0)
  assert_eq(out_pages[1].content.length(), 0)
  match (out_pages[1].mediabox : @pdf.PdfObject) {
    Array(vals) =>
      match ((vals[2], vals[3]) : (@pdf.PdfObject, _)) {
        (Real(w), Real(h)) => {
          assert_close(w, 100.0)
          assert_close(h, 120.0)
        }
        _ => fail("expected mediabox numbers")
      }
    _ => fail("expected mediabox array")
  }
  match (out_pages[1].resources : @pdf.PdfObject) {
    Dictionary(entries) => assert_eq(entries.length(), 0)
    _ => fail("expected resources dictionary")
  }
}

///|
test "change_pages rewrites bookmarks and mixed annotations" {
  let pdf0 = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(100.0),
    Real(100.0),
  ])
  let pages_in = [@pdfpage.Page::custom(rect), @pdfpage.Page::custom(rect)]
  let (pdf1, pageroot) = @pdfpage.PdfPageDoc::new(pdf0).add_pagetree(pages_in)
  let pdf = @pdfpage.PdfPageDoc::new(pdf1).add_root(pageroot, [])
  let refs = pdf.page_reference_numbers()
  let dest1 : @pdf.PdfObject = Array([
    Indirect(refs[0]),
    Name(@pdf.PdfName::of_string("/Fit")),
  ])
  let dest2 : @pdf.PdfObject = Array([
    Indirect(refs[1]),
    Name(@pdf.PdfName::of_string("/Fit")),
  ])
  let annot_dest1 : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Link"))),
    ("/Rect", rect),
    ("/Dest", dest1),
  ])
  let annot_dest2 : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Link"))),
    ("/Rect", rect),
    ("/Dest", dest2),
  ])
  let annot_action_missing : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Link"))),
    ("/Rect", rect),
    ("/A", Dictionary([("/S", Name(@pdf.PdfName::of_string("/GoTo")))])),
  ])
  let annot_action_other : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Link"))),
    ("/Rect", rect),
    ("/A", Dictionary([("/S", Name(@pdf.PdfName::of_string("/URI")))])),
  ])
  let annot_action_none : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Link"))),
    ("/Rect", rect),
    (
      "/A",
      Dictionary([("/S", Name(@pdf.PdfName::of_string("/GoTo"))), ("/D", dest2)]),
    ),
  ])
  let annot_nums = [
    pdf.addobj(annot_dest1),
    pdf.addobj(annot_dest2),
    pdf.addobj(annot_action_missing),
    pdf.addobj(annot_action_other),
    pdf.addobj(annot_action_none),
  ]
  let annots : @pdf.PdfObject = Array(annot_nums.map(fn(n) { Indirect(n) }))
  let page1_obj = pdf.lookup_obj(refs[0])
  let page1_updated = page1_obj.add_entry("/Annots", annots)
  pdf.addobj_given_num((refs[0], page1_updated))
  let bookmarks : Array[@pdfmarks.Bookmark] = [
    {
      level: 0,
      text: "P1",
      target: @pdfdest.Destination::Fit(
        @pdfdest.TargetPage::PageObject(refs[0]),
      ),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 0,
      text: "P2",
      target: @pdfdest.Destination::Fit(
        @pdfdest.TargetPage::PageObject(refs[1]),
      ),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 0,
      text: "Missing",
      target: @pdfdest.Destination::Fit(@pdfdest.TargetPage::PageObject(9999)),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 0,
      text: "Other",
      target: @pdfdest.Destination::Fit(
        @pdfdest.TargetPage::OtherDocPageNumber(2),
      ),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
    {
      level: 0,
      text: "Named",
      target: @pdfdest.Destination::NamedDestination(
        @pdf.PdfName::of_string("/Named"),
      ),
      isopen: false,
      colour: (0.0, 0.0, 0.0),
      flags: 0,
    },
  ]
  let pdf = @pdfmarks.PdfMarks::new(pdf).add_bookmarks(bookmarks)
  let catalog = pdf.catalog_of_pdf()
  let catalog = catalog.add_entry("/OpenAction", dest1)
  pdf.addobj_given_num((pdf.root, catalog))
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  let matrix = @pdftransform.TransformMatrix::translate(10.0, 0.0)
  let updated = @pdfe.with_logger(_ => (), fn() {
    @pdfpage.PdfPageDoc::new(pdf).change_pages(true, pages, matrices=[
      (1, matrix),
    ])
  })
  assert_eq(@pdfpage.PdfPageDoc::new(updated).endpage(), 2)
}

///|
test "pdf_of_pages extracts subset" {
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(100.0),
    Real(100.0),
  ])
  let pages = [
    @pdfpage.Page::custom(rect),
    @pdfpage.Page::custom(rect),
    @pdfpage.Page::custom(rect),
  ]
  let (pdf0, pageroot) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree(
    pages,
  )
  let pdf = @pdfpage.PdfPageDoc::new(pdf0).add_root(pageroot, [])
  let subset = @pdfpage.PdfPageDoc::new(pdf).pdf_of_pages(
    [2],
    retain_numbering=false,
    process_struct_tree=false,
  )
  assert_eq(@pdfpage.PdfPageDoc::new(subset).endpage(), 1)
}

///|
test "prepend/postpend operators update content" {
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(100.0),
    Real(100.0),
  ])
  let base_page = @pdfpage.Page::custom(rect)
  let base_ops : Array[@pdfops.Op] = [Opq, OpQ]
  let page = Page::{
    content: [@pdfops.Op::stream_of_ops(base_ops)],
    mediabox: base_page.mediabox,
    resources: base_page.resources,
    rotate: base_page.rotate,
    rest: base_page.rest,
  }
  let pre = page.prepend_operators(pdf, [Opw(2.0)])
  let ops_pre = @pdfops.Op::parse_operators(pdf, pre.resources, pre.content)
  match (ops_pre[0] : @pdfops.Op) {
    Opw(2.0) => ()
    _ => fail("expected prepend to be first")
  }
  let post = pre.postpend_operators(pdf, [Opw(3.0)])
  let ops_post = @pdfops.Op::parse_operators(pdf, post.resources, post.content)
  let last = ops_post[ops_post.length() - 1]
  match (last : @pdfops.Op) {
    Opw(3.0) => ()
    _ => fail("expected postpend to be last")
  }
}

///|
test "rotation_of_int rejects invalid" {
  let res : Result[@pdfpage.Rotation, Error] = try? @pdfpage.Rotation::from_int(
    13,
  )
  match res {
    Err(_) => ()
    _ => fail("expected error")
  }
}

///|
test "fixup_duplicate_pages creates unique refs" {
  let pdf0 = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(100.0),
    Real(100.0),
  ])
  let page : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/Page"))),
    ("/MediaBox", rect),
    ("/Parent", Indirect(2)),
  ])
  let pages : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/Pages"))),
    ("/Kids", Array([Indirect(1), Indirect(1)])),
    ("/Count", Integer(2)),
  ])
  pdf0.addobj_given_num((1, page))
  pdf0.addobj_given_num((2, pages))
  let pdf = @pdfpage.PdfPageDoc::new(pdf0).add_root(2, [])
  @pdfpage.PdfPageDoc::new(pdf).fixup_duplicate_pages()
  let refs = pdf.page_reference_numbers()
  assert_eq(refs.length(), 2)
  assert_true(refs[0] != refs[1])
}

///|
test "replace_inherit fills mediabox" {
  let pdf0 = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(100.0),
    Real(100.0),
  ])
  let page : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/Page"))),
    ("/Parent", Indirect(2)),
  ])
  let pages : @pdf.PdfObject = Dictionary([
    ("/Type", Name(@pdf.PdfName::of_string("/Pages"))),
    ("/Kids", Array([Indirect(1)])),
    ("/Count", Integer(1)),
    ("/MediaBox", rect),
  ])
  pdf0.addobj_given_num((1, page))
  pdf0.addobj_given_num((2, pages))
  let pdf = @pdfpage.PdfPageDoc::new(pdf0).add_root(2, [])
  @pdfpage.PdfPageDoc::new(pdf).replace_inherit([1])
  let updated = pdf.lookup_obj(1)
  match pdf.lookup_direct("/MediaBox", updated) {
    Some(_) => ()
    _ => fail("expected MediaBox to be inherited")
  }
}

///|
test "renumber_pages updates resources and operators" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([
    ("/Font", Dictionary([("/F1", Null)])),
  ])
  let ops : Array[@pdfops.Op] = [OpBT, OpTf("/F1", 12.0), OpTj("Hi"), OpET]
  let page : @pdfpage.Page = {
    content: [@pdfops.Op::stream_of_ops(ops)],
    mediabox: Array([Real(0.0), Real(0.0), Real(100.0), Real(100.0)]),
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
  let updated = @pdfpage.PdfPageDoc::new(pdf).renumber_pages([page])
  let renamed = updated[0]
  match pdf.lookup_direct("/Font", renamed.resources) {
    Some(Dictionary(entries)) => {
      assert_eq(entries.length(), 1)
      assert_true(entries[0].0 != "/F1")
    }
    _ => fail("expected renamed font dictionary")
  }
  let ops_updated = @pdfops.Op::parse_operators(
    pdf,
    renamed.resources,
    renamed.content,
  )
  match (ops_updated : Array[@pdfops.Op]) {
    [OpBT, OpTf(name, _), ..] => assert_true(name != "/F1")
    _ => fail("expected renamed font operator")
  }
}

///|
test "add_prefix rewrites resources and content" {
  let pdf0 = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([
    ("/Font", Dictionary([("/F1", Null)])),
  ])
  let ops : Array[@pdfops.Op] = [OpBT, OpTf("/F1", 12.0), OpTj("Hi"), OpET]
  let page : @pdfpage.Page = {
    content: [@pdfops.Op::stream_of_ops(ops)],
    mediabox: Array([Real(0.0), Real(0.0), Real(100.0), Real(100.0)]),
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
  let (pdf1, pageroot) = @pdfpage.PdfPageDoc::new(pdf0).add_pagetree([page])
  let pdf = @pdfpage.PdfPageDoc::new(pdf1).add_root(pageroot, [])
  @pdfpage.PdfPageDoc::new(pdf).add_prefix("p")
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  let page0 = pages[0]
  match pdf.lookup_direct("/Font", page0.resources) {
    Some(Dictionary(entries)) => {
      assert_eq(entries.length(), 1)
      assert_eq(entries[0].0, "/pF1")
    }
    _ => fail("expected prefixed font dictionary")
  }
  let ops_updated = @pdfops.Op::parse_operators(
    pdf,
    page0.resources,
    page0.content,
  )
  match (ops_updated : Array[@pdfops.Op]) {
    [OpBT, OpTf(name, _), ..] => assert_eq(name, "/pF1")
    _ => fail("expected prefixed font operator")
  }
}

///|
test "shortest_unused_prefix skips used names" {
  let pdf0 = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([
    ("/Font", Dictionary([("/a1", Null)])),
  ])
  let page : @pdfpage.Page = {
    content: [],
    mediabox: Array([Real(0.0), Real(0.0), Real(100.0), Real(100.0)]),
    resources,
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
  let (pdf1, pageroot) = @pdfpage.PdfPageDoc::new(pdf0).add_pagetree([page])
  let pdf = @pdfpage.PdfPageDoc::new(pdf1).add_root(pageroot, [])
  assert_eq(@pdfpage.PdfPageDoc::new(pdf).shortest_unused_prefix(), "b")
}

///|
test "change_pages rewrites annotation and openaction" {
  let pdf0 = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(100.0),
    Real(100.0),
  ])
  let page = @pdfpage.Page::custom(rect)
  let (pdf1, pageroot) = @pdfpage.PdfPageDoc::new(pdf0).add_pagetree([page])
  let pdf = @pdfpage.PdfPageDoc::new(pdf1).add_root(pageroot, [])
  let refs = pdf.page_reference_numbers()
  let dest_array : @pdf.PdfObject = Array([
    Indirect(refs[0]),
    Name(@pdf.PdfName::of_string("/XYZ")),
    Real(10.0),
    Real(20.0),
    Real(1.0),
  ])
  let annot_dest : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Link"))),
    ("/Dest", dest_array),
  ])
  let annot_action : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Link"))),
    (
      "/A",
      Dictionary([
        ("/S", Name(@pdf.PdfName::of_string("/GoTo"))),
        ("/D", dest_array),
      ]),
    ),
  ])
  let annot1 = pdf.addobj(annot_dest)
  let annot2 = pdf.addobj(annot_action)
  let page_obj = pdf.lookup_obj(refs[0])
  let annots : @pdf.PdfObject = Array([Indirect(annot1), Indirect(annot2)])
  let updated_page = page_obj.add_entry("/Annots", annots)
  pdf.addobj_given_num((refs[0], updated_page))
  let catalog = pdf.catalog_of_pdf()
  let updated_catalog = catalog.add_entry("/OpenAction", dest_array)
  pdf.addobj_given_num((pdf.root, updated_catalog))
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  let translated = @pdfpage.PdfPageDoc::new(pdf).change_pages(true, pages, matrices=[
    (1, @pdftransform.TransformMatrix::translate(5.0, -3.0)),
  ])
  let catalog2 = translated.catalog_of_pdf()
  let openaction = match translated.lookup_direct("/OpenAction", catalog2) {
    Some(dest) => dest
    None => fail("expected OpenAction")
  }
  match @pdfdest.Destination::read(translated, openaction) {
    @pdfdest.Destination::XYZ(_, Some(left), Some(top), _) => {
      assert_close(left, 15.0)
      assert_close(top, 17.0)
    }
    _ => fail("expected updated openaction destination")
  }
  let refs2 = translated.page_reference_numbers()
  let page2 = translated.lookup_obj(refs2[0])
  let annots = match translated.lookup_direct("/Annots", page2) {
    Some(Array(arr)) => arr
    _ => fail("expected annots")
  }
  for annot in annots {
    match (annot : @pdf.PdfObject) {
      Indirect(i) => {
        let obj = translated.lookup_obj(i)
        let dest = match translated.lookup_direct("/Dest", obj) {
          Some(d) => d
          None =>
            match translated.lookup_direct("/A", obj) {
              Some(Dictionary(_) as act) =>
                match translated.lookup_direct("/D", act) {
                  Some(d) => d
                  _ => fail("expected action dest")
                }
              _ => fail("expected action")
            }
        }
        match @pdfdest.Destination::read(translated, dest) {
          @pdfdest.Destination::XYZ(_, Some(left), Some(top), _) => {
            assert_close(left, 15.0)
            assert_close(top, 17.0)
          }
          _ => fail("expected updated annotation destination")
        }
      }
      _ => fail("expected indirect annotation")
    }
  }
}
