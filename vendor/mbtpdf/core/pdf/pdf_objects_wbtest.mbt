///|
fn make_basic_pdf() -> Pdf {
  let base = Pdf::empty()
  let pages = PdfObject::Dictionary([
    ("/Type", PdfObject::Name(PdfName::of_string("/Pages"))),
    ("/Kids", PdfObject::Array([PdfObject::Indirect(2)])),
  ])
  let page = PdfObject::Dictionary([
    ("/Type", PdfObject::Name(PdfName::of_string("/Page"))),
  ])
  let catalog = PdfObject::Dictionary([
    ("/Type", PdfObject::Name(PdfName::of_string("/Catalog"))),
    ("/Pages", PdfObject::Indirect(1)),
  ])
  base.addobj_given_num((1, pages))
  base.addobj_given_num((2, page))
  base.addobj_given_num((3, catalog))
  Pdf::{
    major: base.major,
    minor: base.minor,
    root: 3,
    objects: base.objects,
    trailerdict: PdfObject::Dictionary([("/Root", PdfObject::Indirect(3))]),
    was_linearized: base.was_linearized,
    saved_encryption: base.saved_encryption,
  }
}

///|
test "lookup helpers and catalog" {
  let pdf = Pdf::empty()
  let dict = PdfObject::Dictionary([("/A", PdfObject::Integer(1))])
  assert_integer(pdf.lookup_fail("err", "/A", dict), 1)
  assert_is_err(try? pdf.lookup_fail("err", "/B", dict))
  let dict_indirect = PdfObject::Dictionary([("/A", PdfObject::Indirect(5))])
  assert_eq(dict_indirect.find_indirect("/A"), Some(5))
  let dict_non_indirect = PdfObject::Dictionary([("/A", PdfObject::Integer(7))])
  assert_eq(dict_non_indirect.find_indirect("/A"), None)
  assert_is_err(try? PdfObject::Integer(1).find_indirect("/A"))
  let catalog_pdf = make_basic_pdf()
  match catalog_pdf.catalog_of_pdf() {
    PdfObject::Dictionary(_) => ()
    _ => fail("expected catalog")
  }
  let missing = Pdf::empty()
  assert_is_err(try? missing.catalog_of_pdf())
}

///|
test "recurse and iterators" {
  let pdf = Pdf::empty()
  pdf.addobj_given_num((2, PdfObject::Integer(2)))
  pdf.addobj_given_num((1, PdfObject::Integer(1)))
  match
    recurse_array(
      obj => match obj {
        PdfObject::Integer(v) => PdfObject::Integer(v + 1)
        _ => obj
      },
      [PdfObject::Integer(1), PdfObject::Integer(2)],
    ) {
    PdfObject::Array(values) => assert_eq(values.length(), 2)
    _ => fail("expected array")
  }
  let seen = Ref::new(([] : Array[Int]))
  pdf.objiter((num, _) => seen.val.push(num))
  assert_eq(seen.val, [1, 2])
  let seen_gen = Ref::new(([] : Array[(Int, Int)]))
  pdf.objiter_gen((num, gen, _) => seen_gen.val.push((num, gen)))
  assert_eq(seen_gen.val, [(1, 0), (2, 0)])
  let seen_inorder = Ref::new(([] : Array[Int]))
  pdf.objiter_inorder((num, _) => seen_inorder.val.push(num))
  assert_eq(seen_inorder.val, [1, 2])
  pdf.objects.objects.set(
    3,
    ({ val: ObjectData::ParsedAlreadyDecrypted(PdfObject::Integer(5)) }, 0),
  )
  pdf.objselfmap(obj => match obj {
    PdfObject::Integer(v) => PdfObject::Integer(v + 1)
    _ => obj
  })
  assert_integer(pdf.lookup_obj(3), 6)
  let stream = make_stream(
    PdfObject::Dictionary([]),
    @pdfio.bytes_of_string("x"),
  )
  pdf.addobj_given_num((4, stream))
  let selected = pdf.objselect(obj => match obj {
    PdfObject::Integer(_) => true
    _ => false
  })
  assert_true(selected.contains(1))
}

///|
test "references and renumbering" {
  let pdf = make_basic_pdf()
  pdf.addobj_given_num((4, PdfObject::Integer(99)))
  let referenced = pdf.objects_referenced([], [], PdfObject::Indirect(2))
  assert_true(referenced.contains(2))
  pdf.remove_unreferenced()
  let nums = pdf.objnumbers()
  assert_true(!nums.contains(4))
  let pages = pdf.page_reference_numbers()
  assert_eq(pages, [2])
  let table = pdf.changes()
  assert_eq(table.get(2), Some(2))
  let renum_table : Map[Int, Int] = Map::new()
  renum_table.set(1, 10)
  renum_table.set(2, 11)
  renum_table.set(3, 12)
  let renumbered = pdf.renumber(renum_table)
  assert_eq(renumbered.root, 12)
  assert_eq(renumbered.objnumbers(), [10, 11, 12])
  let pdfs = renumber_pdfs([make_basic_pdf(), make_basic_pdf()])
  let first_nums = pdfs[0].objnumbers()
  let second_nums = pdfs[1].objnumbers()
  assert_true(first_nums.length() > 0)
  assert_true(second_nums.length() > 0)
  assert_true(first_nums.last().unwrap() < second_nums[0])
  let copied = pdf.deep_copy()
  pdf.trailerdict = PdfObject::Dictionary([])
  match copied.trailerdict {
    PdfObject::Dictionary(entries) => assert_true(entries.length() > 0)
    _ => fail("expected dictionary")
  }
  match pdf.generate_id("path", () => 1.0) {
    PdfObject::Array(values) => {
      assert_eq(values.length(), 2)
      match (values[0], values[1]) {
        (PdfObject::String(a), PdfObject::String(b)) => assert_eq(a, b)
        _ => fail("expected id strings")
      }
    }
    _ => fail("expected id array")
  }
  pdf.change_id("path-")
  match pdf.trailerdict.lookup_immediate("/ID") {
    Some(PdfObject::Array(values)) => assert_eq(values.length(), 2)
    _ => fail("expected id entry")
  }
  let bad = Pdf::empty()
  bad.trailerdict = PdfObject::Integer(1)
  assert_is_err(try? bad.change_id("path-"))
}
