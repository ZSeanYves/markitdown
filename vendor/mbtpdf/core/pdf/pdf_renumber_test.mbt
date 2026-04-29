///|
test "renumber_object_parsed handles indirect and stream" {
  let pdf = Pdf::empty()
  let changes : Map[Int, Int] = Map::new()
  match pdf.renumber_object_parsed(changes, PdfObject::Indirect(5)) {
    PdfObject::Indirect(5) => ()
    _ => fail("expected unchanged indirect")
  }
  let changes2 : Map[Int, Int] = Map::new()
  changes2.set(1, 10)
  let stream = make_stream(
    PdfObject::Dictionary([("/Ref", PdfObject::Indirect(1))]),
    @pdfio.bytes_of_string("x"),
  )
  match pdf.renumber_object_parsed(changes2, stream) {
    PdfObject::Stream(r) =>
      match r.val {
        (dict_obj, _) =>
          match dict_obj.lookup_immediate("/Ref") {
            Some(PdfObject::Indirect(10)) => ()
            _ => fail("expected renumbered ref")
          }
      }
    _ => fail("expected stream")
  }
}

///|
test "renumber keeps root when missing change" {
  let pdf = make_basic_pdf()
  pdf.addobj_given_num((5, PdfObject::Integer(1)))
  pdf.addobj_given_num((6, PdfObject::Integer(2)))
  pdf.objects.object_stream_ids.set(5, 1)
  pdf.objects.object_stream_ids.set(6, 2)
  let change_table : Map[Int, Int] = Map::new()
  change_table.set(5, 7)
  let renumbered = pdf.renumber(change_table)
  assert_eq(renumbered.root, pdf.root)
  assert_eq(renumbered.objects.object_stream_ids.get(7), Some(1))
  assert_true(renumbered.objnumbers().contains(7))
}
