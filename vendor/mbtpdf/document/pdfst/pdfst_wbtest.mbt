///|
fn sample_rect() -> @pdf.PdfObject {
  Array([Integer(0), Integer(0), Integer(100), Integer(100)])
}

///|
fn build_page_pdf(count : Int) -> @pdf.Pdf raise {
  let pdf = @pdf.Pdf::empty()

  // Create placeholder /Pages root so pages can reference it as /Parent.
  let pages_root_num = pdf.addobj(
    Dictionary([
      ("/Type", Name(@pdf.PdfName::of_string("/Pages"))),
      ("/Kids", Array([])),
      ("/Count", Integer(count)),
    ]),
  )
  let kids : Array[@pdf.PdfObject] = []
  let mut i = 0
  while i < count {
    let page_obj : @pdf.PdfObject = Dictionary([
      ("/Type", Name(@pdf.PdfName::of_string("/Page"))),
      ("/Parent", Indirect(pages_root_num)),
      ("/MediaBox", sample_rect()),
    ])
    let page_num = pdf.addobj(page_obj)
    kids.push(Indirect(page_num))
    i = i + 1
  }

  // Fill /Kids now that we have page object numbers.
  pdf.addobj_given_num(
    (
      pages_root_num,
      Dictionary([
        ("/Type", Name(@pdf.PdfName::of_string("/Pages"))),
        ("/Kids", Array(kids)),
        ("/Count", Integer(count)),
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
fn build_two_page_pdf() -> @pdf.Pdf raise {
  build_page_pdf(2)
}

///|
fn install_struct_root(pdf : @pdf.Pdf, root : @pdf.PdfObject) -> Int raise {
  let root_num = pdf.addobj(root)
  let catalog_num = match
    (pdf.trailerdict.lookup_immediate("/Root") : @pdf.PdfObject?) {
    Some(Indirect(i)) => i
    _ => raise @pdf.PdfError::Msg("missing root")
  }
  let catalog = pdf.lookup_obj(catalog_num)
  let updated = catalog.add_entry("/StructTreeRoot", Indirect(root_num))
  pdf.addobj_given_num((catalog_num, updated))
  root_num
}

///|
fn add_struct_tree(pdf : @pdf.Pdf) -> (Int, Int) raise {
  let page_refs = pdf.page_reference_numbers()
  let struct1 : @pdf.PdfObject = Dictionary([("/Pg", Indirect(page_refs[0]))])
  let struct2 : @pdf.PdfObject = Dictionary([("/Pg", Indirect(page_refs[1]))])
  let struct1_num = pdf.addobj(struct1)
  let struct2_num = pdf.addobj(struct2)
  let root : @pdf.PdfObject = Dictionary([
    ("/K", Array([Indirect(struct1_num), Indirect(struct2_num)])),
  ])
  let root_num = pdf.addobj(root)
  let catalog_num = match
    (pdf.trailerdict.lookup_immediate("/Root") : @pdf.PdfObject?) {
    Some(Indirect(i)) => i
    _ => raise @pdf.PdfError::Msg("missing root")
  }
  let catalog = pdf.lookup_obj(catalog_num)
  let updated = catalog.add_entry("/StructTreeRoot", Indirect(root_num))
  pdf.addobj_given_num((catalog_num, updated))
  (root_num, struct2_num)
}

///|
test "trim_structure_tree removes entries" {
  let pdf = build_two_page_pdf()
  let (root_num, removed_num) = add_struct_tree(pdf)
  PdfStructTree::new(pdf).trim_structure_tree([1])
  assert_true(!pdf.objnumbers().contains(removed_num))
  let root = pdf.lookup_obj(root_num)
  match (root.lookup_immediate("/K") : @pdf.PdfObject?) {
    Some(Array(items)) => assert_eq(items.length(), 1)
    Some(Indirect(_)) => ()
    _ => fail("expected updated /K")
  }
}

///|
test "trim_structure_tree updates nested k arrays" {
  let pdf = build_page_pdf(3)
  let page_refs = pdf.page_reference_numbers()
  let keep_obj : @pdf.PdfObject = Dictionary([("/Pg", Indirect(page_refs[0]))])
  let keep = pdf.addobj(keep_obj)
  let remove_pg_obj : @pdf.PdfObject = Dictionary([
    ("/Pg", Indirect(page_refs[1])),
  ])
  let remove_pg = pdf.addobj(remove_pg_obj)
  let remove_obj_obj : @pdf.PdfObject = Dictionary([
    ("/Obj", Indirect(page_refs[2])),
  ])
  let remove_obj = pdf.addobj(remove_obj_obj)
  let parent_keep_obj : @pdf.PdfObject = Dictionary([
    (
      "/K",
      Array([
        Indirect(keep),
        Indirect(remove_pg),
        Indirect(999),
        Integer(7),
        Indirect(remove_obj),
      ]),
    ),
  ])
  let parent_keep = pdf.addobj(parent_keep_obj)
  let parent_remove_obj : @pdf.PdfObject = Dictionary([
    ("/K", Array([Indirect(remove_pg)])),
  ])
  let parent_remove = pdf.addobj(parent_remove_obj)
  let parent_int_obj : @pdf.PdfObject = Dictionary([("/K", Integer(1))])
  let parent_int = pdf.addobj(parent_int_obj)
  let root_dict : @pdf.PdfObject = Dictionary([
    (
      "/K",
      Array([
        Indirect(parent_keep),
        Indirect(parent_remove),
        Indirect(parent_int),
      ]),
    ),
  ])
  let root_num = install_struct_root(pdf, root_dict)
  let stream_dict : @pdf.PdfObject = Dictionary([("/Length", Integer(0))])
  let stream_obj : @pdf.PdfObject = Stream(
    Ref::new((stream_dict, @pdf.Stream::Got(([] : Array[Byte])))),
  )
  ignore(pdf.addobj(stream_obj))
  PdfStructTree::new(pdf).trim_structure_tree([1])
  assert_true(!pdf.objnumbers().contains(parent_remove))
  let root = pdf.lookup_obj(root_num)
  match (root.lookup_immediate("/K") : @pdf.PdfObject?) {
    Some(Array(items)) => assert_eq(items.length(), 2)
    _ => fail("expected root /K array")
  }
  let parent = pdf.lookup_obj(parent_keep)
  match (parent.lookup_immediate("/K") : @pdf.PdfObject?) {
    Some(Array(items)) => assert_eq(items.length(), 2)
    _ => fail("expected updated parent /K array")
  }
}

///|
test "renumber_parent_trees with empty parents" {
  let pdf1 = build_two_page_pdf()
  let pdf2 = build_two_page_pdf()
  inspect(
    try? PdfStructTrees::new([pdf1, pdf2]).renumber_parent_trees(),
    content="Ok(())",
  )
}

///|
test "renumber_parent_trees handles single pdf" {
  let pdf = build_two_page_pdf()
  PdfStructTrees::new([pdf]).renumber_parent_trees()
}

///|
test "renumber_parent_trees remaps struct parents" {
  let pdf1 = build_page_pdf(1)
  let pdf2 = build_page_pdf(1)
  let obj1_dict : @pdf.PdfObject = Dictionary([("/StructParent", Integer(0))])
  let obj1 = pdf1.addobj(obj1_dict)
  let obj2_dict : @pdf.PdfObject = Dictionary([("/StructParent", Integer(0))])
  let obj2 = pdf2.addobj(obj2_dict)
  let obj3_dict : @pdf.PdfObject = Dictionary([
    ("/StructParents", Array([Integer(0)])),
  ])
  let obj3 = pdf2.addobj(obj3_dict)
  ignore(obj3)
  let stream_dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(0)),
    ("/StructParent", Integer(0)),
  ])
  let stream : @pdf.PdfObject = Stream(
    Ref::new((stream_dict, @pdf.Stream::Got(([] : Array[Byte])))),
  )
  let stream_num = pdf2.addobj(stream)
  let tree1 = @pdftree.PdfTree::new(pdf1).build_name_tree(true, [("0", Null)])
  let tree2 = @pdftree.PdfTree::new(pdf2).build_name_tree(true, [("0", Null)])
  let tree1_num = pdf1.addobj(tree1)
  let tree2_num = pdf2.addobj(tree2)
  let root1 : @pdf.PdfObject = Dictionary([("/ParentTree", Indirect(tree1_num))])
  ignore(install_struct_root(pdf1, root1))
  let root2 : @pdf.PdfObject = Dictionary([("/ParentTree", Indirect(tree2_num))])
  ignore(install_struct_root(pdf2, root2))
  PdfStructTrees::new([pdf1, pdf2]).renumber_parent_trees()
  match
    (
      pdf1.lookup_direct("/StructParent", pdf1.lookup_obj(obj1)) :
      @pdf.PdfObject?) {
    Some(Integer(0)) => ()
    _ => fail("expected pdf1 StructParent unchanged")
  }
  match
    (
      pdf2.lookup_direct("/StructParent", pdf2.lookup_obj(obj2)) :
      @pdf.PdfObject?) {
    Some(Integer(1)) => ()
    _ => fail("expected pdf2 StructParent remapped")
  }
  match
    (
      pdf2.lookup_direct("/StructParent", pdf2.lookup_obj(stream_num)) :
      @pdf.PdfObject?) {
    Some(Integer(1)) => ()
    _ => fail("expected stream StructParent remapped")
  }
  match
    pdf2.lookup_chain(pdf2.trailerdict, [
      "/Root", "/StructTreeRoot", "/ParentTree",
    ]) {
    Some(tree) =>
      match @pdftree.PdfTree::new(pdf2).read_number_tree(tree) {
        [(key, _)] => assert_eq(key, "1")
        _ => fail("expected renumbered parent tree")
      }
    None => fail("expected parent tree")
  }
}

///|
test "merge_structure_trees returns none" {
  let pdf = @pdf.Pdf::empty()
  let input = build_two_page_pdf()
  match PdfStructTree::new(pdf).merge_structure_trees([input]) {
    None => ()
    _ => fail("expected none")
  }
}

///|
test "merge_structure_trees returns single root" {
  let pdf_out = @pdf.Pdf::empty()
  let pdf = build_two_page_pdf()
  let root_num = install_struct_root(pdf, Dictionary([]))
  match PdfStructTree::new(pdf_out).merge_structure_trees([pdf]) {
    Some(id) => assert_eq(id, root_num)
    _ => fail("expected root objnum")
  }
}

///|
test "merge_structure_trees merges roots" {
  let pdf_out = @pdf.Pdf::empty()
  let pdf1 = build_page_pdf(1)
  let pdf2 = build_page_pdf(1)
  let page_refs1 = pdf1.page_reference_numbers()
  let page_refs2 = pdf2.page_reference_numbers()
  let kid1_obj : @pdf.PdfObject = Dictionary([("/Pg", Indirect(page_refs1[0]))])
  let kid1 = pdf1.addobj(kid1_obj)
  let idtree1 = @pdftree.PdfTree::new(pdf1).build_name_tree(false, [("A", Null)])
  let parenttree1 = @pdftree.PdfTree::new(pdf1).build_name_tree(true, [
    ("0", Null),
  ])
  let root1 : @pdf.PdfObject = Dictionary([
    ("/K", Indirect(kid1)),
    ("/IDTree", idtree1),
    ("/ParentTree", parenttree1),
    ("/RoleMap", Dictionary([("/Sect", Name(@pdf.PdfName::of_string("/Div")))])),
    ("/Namespaces", Array([Dictionary([("/NS", String("ns1"))])])),
    ("/PronunciationLexicon", Array([])),
  ])
  ignore(install_struct_root(pdf1, root1))
  let kid2 : @pdf.PdfObject = Dictionary([("/Pg", Indirect(page_refs2[0]))])
  let idtree2 = @pdftree.PdfTree::new(pdf2).build_name_tree(false, [("B", Null)])
  let parenttree2 = @pdftree.PdfTree::new(pdf2).build_name_tree(true, [
    ("0", Null),
  ])
  let root2 : @pdf.PdfObject = Dictionary([
    ("/K", Array([kid2, Integer(3)])),
    ("/IDTree", idtree2),
    ("/ParentTree", parenttree2),
    ("/RoleMap", Name(@pdf.PdfName::of_string("/NotADict"))),
    (
      "/ClassMap",
      Dictionary([("/Class", Name(@pdf.PdfName::of_string("/Span")))]),
    ),
    ("/Namespaces", Dictionary([])),
    ("/AF", Array([Name(@pdf.PdfName::of_string("/File"))])),
  ])
  ignore(install_struct_root(pdf2, root2))
  let merged = @pdfe.with_logger(_ => (), fn() {
    PdfStructTree::new(pdf_out).merge_structure_trees(
      [pdf1, pdf2],
      add_toplevel_document=true,
    )
  })
  match merged {
    Some(root_num) =>
      match (pdf_out.lookup_obj(root_num) : @pdf.PdfObject) {
        Dictionary(_) as dict =>
          match (pdf_out.lookup_direct("/Type", dict) : @pdf.PdfObject?) {
            Some(Name(n)) if n.equal_string_bytes("/StructTreeRoot") => ()
            _ => fail("expected StructTreeRoot type")
          }
        _ => fail("expected merged root dict")
      }
    _ => fail("expected merged struct tree")
  }
  let merged_no_top = @pdfe.with_logger(_ => (), fn() {
    PdfStructTree::new(pdf_out).merge_structure_trees([pdf1, pdf2])
  })
  assert_true(merged_no_top is Some(_))
}
