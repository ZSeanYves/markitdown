///|
test "nametree lookup" {
  let pdf = Pdf::empty()
  let names = PdfObject::Array([
    PdfObject::String("A"),
    PdfObject::Integer(1),
    PdfObject::String("B"),
    PdfObject::Integer(2),
  ])
  let tree = PdfObject::Dictionary([("/Names", names)])
  assert_some_integer(pdf.nametree_lookup(PdfObject::String("A"), tree), 1)
  match pdf.nametree_lookup(PdfObject::String("C"), tree) {
    None => ()
    _ => fail("expected none")
  }
  let tree_limits_low = PdfObject::Dictionary([
    (
      "/Limits",
      PdfObject::Array([PdfObject::String("B"), PdfObject::String("C")]),
    ),
    (
      "/Names",
      PdfObject::Array([PdfObject::String("B"), PdfObject::Integer(2)]),
    ),
  ])
  match pdf.nametree_lookup(PdfObject::String("A"), tree_limits_low) {
    None => ()
    _ => fail("expected none")
  }
  let tree_limits_high = PdfObject::Dictionary([
    (
      "/Limits",
      PdfObject::Array([PdfObject::String("A"), PdfObject::String("B")]),
    ),
    (
      "/Names",
      PdfObject::Array([PdfObject::String("A"), PdfObject::Integer(1)]),
    ),
  ])
  match pdf.nametree_lookup(PdfObject::String("Z"), tree_limits_high) {
    None => ()
    _ => fail("expected none")
  }
  let tree_limits_ok = PdfObject::Dictionary([
    (
      "/Limits",
      PdfObject::Array([PdfObject::String("A"), PdfObject::String("Z")]),
    ),
    (
      "/Names",
      PdfObject::Array([PdfObject::String("M"), PdfObject::Integer(3)]),
    ),
  ])
  assert_some_integer(
    pdf.nametree_lookup(PdfObject::String("M"), tree_limits_ok),
    3,
  )
  let kid_missing = PdfObject::Dictionary([
    (
      "/Names",
      PdfObject::Array([PdfObject::String("X"), PdfObject::Integer(1)]),
    ),
  ])
  let kid = PdfObject::Dictionary([
    (
      "/Names",
      PdfObject::Array([PdfObject::String("K"), PdfObject::Integer(9)]),
    ),
  ])
  let parent = PdfObject::Dictionary([
    ("/Kids", PdfObject::Array([kid_missing, kid])),
  ])
  assert_some_integer(pdf.nametree_lookup(PdfObject::String("K"), parent), 9)
  let bad_parent = PdfObject::Dictionary([("/Kids", PdfObject::Integer(1))])
  assert_is_err(try? pdf.nametree_lookup(PdfObject::String("A"), bad_parent))
  let int_tree = PdfObject::Dictionary([
    (
      "/Names",
      PdfObject::Array([PdfObject::Integer(1), PdfObject::String("one")]),
    ),
  ])
  match pdf.nametree_lookup(PdfObject::Integer(1), int_tree) {
    Some(PdfObject::String("one")) => ()
    _ => fail("expected integer key match")
  }
  let missing = PdfObject::Dictionary([])
  assert_is_err(try? pdf.nametree_lookup(PdfObject::String("A"), missing))
  let malformed = PdfObject::Dictionary([("/Limits", PdfObject::Integer(1))])
  assert_is_err(try? pdf.nametree_lookup(PdfObject::String("A"), malformed))
  let bad_names = PdfObject::Dictionary([("/Names", PdfObject::Integer(1))])
  assert_is_err(try? pdf.nametree_lookup(PdfObject::String("A"), bad_names))
  let kids_pdf = Pdf::empty()
  let kid1 = PdfObject::Dictionary([
    (
      "/Names",
      PdfObject::Array([PdfObject::String("A"), PdfObject::Integer(1)]),
    ),
  ])
  let kid2 = PdfObject::Dictionary([
    (
      "/Names",
      PdfObject::Array([PdfObject::String("M"), PdfObject::Integer(2)]),
    ),
  ])
  kids_pdf.addobj_given_num((2, kid1))
  kids_pdf.addobj_given_num((3, kid2))
  let parent_with_kids = PdfObject::Dictionary([
    (
      "/Limits",
      PdfObject::Array([PdfObject::String("A"), PdfObject::String("Z")]),
    ),
    (
      "/Kids",
      PdfObject::Array([PdfObject::Indirect(2), PdfObject::Indirect(3)]),
    ),
  ])
  assert_some_integer(
    kids_pdf.nametree_lookup(PdfObject::String("M"), parent_with_kids),
    2,
  )
  match
    kids_pdf.nametree_lookup(
      PdfObject::Name(PdfName::of_string("/M")),
      parent_with_kids,
    ) {
    None => ()
    _ => fail("expected none for name key")
  }
  let malformed_entry = PdfObject::Dictionary([
    (
      "/Limits",
      PdfObject::Array([PdfObject::String("A"), PdfObject::String("Z")]),
    ),
  ])
  assert_is_err(
    try? kids_pdf.nametree_lookup(PdfObject::String("A"), malformed_entry),
  )
}

///|
test "contents_of_nametree" {
  let pdf = Pdf::empty()
  let tree = PdfObject::Dictionary([
    (
      "/Names",
      PdfObject::Array([
        PdfObject::String("A"),
        PdfObject::Integer(1),
        PdfObject::String("B"),
      ]),
    ),
  ])
  let contents = @pdfe.with_logger(_ => (), fn() {
    pdf.contents_of_nametree(tree)
  })
  assert_eq(contents.length(), 1)
  match contents[0] {
    (PdfObject::String("A"), PdfObject::Integer(1)) => ()
    _ => fail("expected name pair")
  }
  let kid1 = PdfObject::Dictionary([
    (
      "/Names",
      PdfObject::Array([PdfObject::String("K"), PdfObject::Integer(9)]),
    ),
  ])
  let kid2 = PdfObject::Dictionary([
    (
      "/Names",
      PdfObject::Array([PdfObject::String("L"), PdfObject::Integer(10)]),
    ),
  ])
  let parent = PdfObject::Dictionary([("/Kids", PdfObject::Array([kid1, kid2]))])
  let flattened = pdf.contents_of_nametree(parent)
  assert_eq(flattened.length(), 2)
  let bad = PdfObject::Dictionary([
    ("/Type", PdfObject::Name(PdfName::of_string("/Other"))),
  ])
  assert_is_err(try? pdf.contents_of_nametree(bad))
}
