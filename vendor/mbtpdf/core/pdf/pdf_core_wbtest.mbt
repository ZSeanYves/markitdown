///|
test "toget and predicates" {
  assert_true(is_whitespace(' '))
  assert_true(is_whitespace('\n'))
  assert_true(!is_whitespace('A'))
  let input = @pdfio.Input::of_string("abc", source="test")
  let t = ToGet::new(input, 1, 2)
  assert_eq(ToGet::length(t), 2)
}

///|
test "objmap basics" {
  let map0 = pdfobjmap_empty()
  assert_eq(pdfobjmap_bindings(map0).length(), 0)
  // Basic map operations are tested via the Pdf structure
  let pdf = Pdf::empty()
  pdf.addobj_given_num((1, PdfObject::Null))
  pdf.addobj_given_num((2, PdfObject::Integer(42)))
  assert_eq(pdf.objnumbers().length(), 2)
}

///|
fn make_stream(dict : PdfObject, data : @pdfio.MutableBytes) -> PdfObject {
  PdfObject::Stream(Ref::new((dict, Stream::Got(data))))
}

///|
fn assert_integer(obj : PdfObject, expected : Int) -> Unit raise {
  match obj {
    PdfObject::Integer(value) => assert_eq(value, expected)
    _ => fail("expected integer")
  }
}

///|
fn assert_some_integer(obj : PdfObject?, expected : Int) -> Unit raise {
  match obj {
    Some(PdfObject::Integer(value)) => assert_eq(value, expected)
    Some(_) => fail("expected integer")
    None => fail("expected some")
  }
}

///|
test "dictionary helpers" {
  let dict = PdfObject::Dictionary([
    ("/A", PdfObject::Integer(1)),
    ("/B", PdfObject::Integer(2)),
  ])
  match dict.remove_entry("/A") {
    PdfObject::Dictionary(entries) => assert_eq(entries.length(), 1)
    _ => fail("expected dictionary")
  }
  let data = @pdfio.bytes_of_string("hi")
  let stream_dict = PdfObject::Dictionary([
    ("/Length", PdfObject::Integer(2)),
    ("/A", PdfObject::Integer(1)),
  ])
  let stream_obj = make_stream(stream_dict, data)
  match stream_obj.remove_entry("/A") {
    PdfObject::Stream(r) =>
      match r.val {
        (PdfObject::Dictionary(entries), _) =>
          assert_true(entries.search_by(pair => pair.0 == "/A") is None)
        _ => fail("expected stream dictionary")
      }
    _ => fail("expected stream")
  }
  assert_is_err(try? PdfObject::Integer(1).remove_entry("/A"))
  match PdfObject::Null.replace_entry("/A", PdfObject::Integer(1)) {
    PdfObject::Dictionary(entries) => assert_eq(entries.length(), 1)
    _ => fail("expected dictionary from null")
  }
  assert_is_err(
    try? PdfObject::Dictionary([("/B", PdfObject::Integer(2))]).replace_entry(
      "/A",
      PdfObject::Integer(1),
    ),
  )
  let stream_obj2 = make_stream(
    PdfObject::Dictionary([("/A", PdfObject::Integer(1))]),
    data,
  )
  match stream_obj2.replace_entry("/A", PdfObject::Integer(9)) {
    PdfObject::Stream(r) =>
      match r.val {
        (PdfObject::Dictionary(entries), _) =>
          match entries.search_by(pair => pair.0 == "/A") {
            Some(i) => assert_integer(entries[i].1, 9)
            None => fail("expected replaced key")
          }
        _ => fail("expected stream dictionary")
      }
    _ => fail("expected stream")
  }
  assert_is_err(
    try? PdfObject::Integer(1).replace_entry("/A", PdfObject::Integer(2)),
  )
  match PdfObject::Null.add_entry("/A", PdfObject::Integer(1)) {
    PdfObject::Dictionary(entries) => assert_eq(entries.length(), 1)
    _ => fail("expected dictionary from null")
  }
  match
    PdfObject::Dictionary([("/A", PdfObject::Integer(1))]).add_entry(
      "/A",
      PdfObject::Integer(2),
    ) {
    PdfObject::Dictionary(entries) =>
      match entries.search_by(pair => pair.0 == "/A") {
        Some(i) => assert_integer(entries[i].1, 2)
        None => fail("expected updated key")
      }
    _ => fail("expected dictionary")
  }
  let stream_obj3 = make_stream(
    PdfObject::Dictionary([("/A", PdfObject::Integer(1))]),
    data,
  )
  match stream_obj3.add_entry("/B", PdfObject::Integer(3)) {
    PdfObject::Stream(r) =>
      match r.val {
        (PdfObject::Dictionary(entries), _) =>
          assert_true(entries.search_by(pair => pair.0 == "/B") is Some(_))
        _ => fail("expected stream dictionary")
      }
    _ => fail("expected stream")
  }
  assert_is_err(
    try? PdfObject::Integer(1).add_entry("/A", PdfObject::Integer(2)),
  )
}

///|
test "lookup and chains" {
  let pdf = Pdf::empty()
  pdf.addobj_given_num((1, PdfObject::Integer(99)))
  pdf.addobj_given_num(
    (
      2,
      PdfObject::Dictionary([
        ("/A", PdfObject::Indirect(1)),
        ("/B", PdfObject::Integer(5)),
      ]),
    ),
  )
  assert_integer(pdf.lookup_obj(1), 99)
  assert_integer(pdf.direct(PdfObject::Indirect(1)), 99)
  assert_some_integer(
    pdf.lookup_direct(
      "/A",
      PdfObject::Dictionary([("/A", PdfObject::Indirect(1))]),
    ),
    99,
  )
  match
    PdfObject::Dictionary([("/A", PdfObject::Indirect(1))]).lookup_immediate(
      "/A",
    ) {
    Some(PdfObject::Indirect(1)) => ()
    _ => fail("expected indirect")
  }
  let data = @pdfio.bytes_of_string("ok")
  let stream_obj = make_stream(
    PdfObject::Dictionary([("/A", PdfObject::Integer(7))]),
    data,
  )
  assert_some_integer(pdf.lookup_direct("/A", stream_obj), 7)
  assert_some_integer(stream_obj.lookup_immediate("/A"), 7)
  match stream_obj.lookup_immediate("/Missing") {
    None => ()
    _ => fail("expected none")
  }
  match pdf.lookup_direct("/A", PdfObject::Integer(1)) {
    None => ()
    _ => fail("expected none")
  }
  let bad_stream = make_stream(PdfObject::Integer(1), data)
  match pdf.lookup_direct("/A", bad_stream) {
    None => ()
    _ => fail("expected none")
  }
  match bad_stream.lookup_immediate("/A") {
    None => ()
    _ => fail("expected none")
  }
  match PdfObject::Integer(1).lookup_immediate("/A") {
    None => ()
    _ => fail("expected none")
  }
  let arr_dict = PdfObject::Dictionary([
    ("/Arr", PdfObject::Array([PdfObject::Integer(1), PdfObject::Integer(2)])),
  ])
  assert_some_integer(pdf.lookup_chain(arr_dict, ["/Arr", "/[1]"][:]), 2)
  match pdf.lookup_chain(arr_dict, ["/[x]"][:]) {
    None => ()
    _ => fail("expected none")
  }
  match pdf.lookup_chain(PdfObject::Integer(1), ["/[0]"][:]) {
    None => ()
    _ => fail("expected none")
  }
  let pdf2 = Pdf::empty()
  pdf2.trailerdict = PdfObject::Dictionary([
    ("/A", PdfObject::Array([PdfObject::Integer(1), PdfObject::Integer(2)])),
  ])
  pdf2.replace_chain(["/A", "/[1]"][:], PdfObject::Integer(9))
  assert_some_integer(pdf2.lookup_chain(pdf2.trailerdict, ["/A", "/[1]"][:]), 9)
  assert_is_err(
    try? pdf2.replace_chain(["/A", "/[5]"][:], PdfObject::Integer(3)),
  )
  assert_is_err(
    try? pdf2.replace_chain(["/A", "/[0]", "/B"][:], PdfObject::Integer(3)),
  )
  assert_is_err(try? pdf2.replace_chain(["/[0]"][:], PdfObject::Integer(1)))
  let dict_chain = ["/X", "/Y"]
  pdf2.replace_chain(dict_chain[:], PdfObject::Integer(7))
  assert_some_integer(pdf2.lookup_chain(pdf2.trailerdict, dict_chain[:]), 7)
  let pdf_null = Pdf::empty()
  pdf_null.trailerdict = PdfObject::Null
  pdf_null.replace_chain(["/A", "/B"][:], PdfObject::Integer(1))
  assert_some_integer(
    pdf_null.lookup_chain(pdf_null.trailerdict, ["/A", "/B"][:]),
    1,
  )
  let pdf_stream_replace = Pdf::empty()
  pdf_stream_replace.trailerdict = make_stream(
    PdfObject::Dictionary([("/A", PdfObject::Integer(1))]),
    data,
  )
  pdf_stream_replace.replace_chain(["/A"][:], PdfObject::Integer(2))
  match pdf_stream_replace.trailerdict {
    PdfObject::Stream(r) =>
      match r.val {
        (PdfObject::Dictionary(entries), _) =>
          match entries.search_by(pair => pair.0 == "/A") {
            Some(i) => assert_integer(entries[i].1, 2)
            None => fail("expected updated /A")
          }
        _ => fail("expected stream dictionary")
      }
    _ => fail("expected stream")
  }
  let dict_indirect = PdfObject::Dictionary([("/A", PdfObject::Indirect(1))])
  assert_eq(pdf.indirect_number("/A", dict_indirect), Some(1))
  assert_eq(pdf.indirect_number("/B", dict_indirect), None)
  let dict_direct = PdfObject::Dictionary([("/A", PdfObject::Integer(2))])
  assert_eq(pdf.indirect_number("/A", dict_direct), None)
  let stream_indirect = make_stream(dict_indirect, data)
  assert_eq(pdf.indirect_number("/A", stream_indirect), Some(1))
  assert_eq(pdf.indirect_number("/A", PdfObject::Integer(1)), None)
  let dict_alt = PdfObject::Dictionary([("/Alt", PdfObject::Integer(3))])
  assert_some_integer(pdf.lookup_direct_orelse("/Missing", "/Alt", dict_alt), 3)
  let pdf_parse = Pdf::empty()
  pdf_parse.objects.objects.set(10, (Ref::new(ObjectData::ToParse), 0))
  match pdf_parse.lookup_obj(10) {
    PdfObject::Null => ()
    _ => fail("expected null")
  }
  let map_none : Map[Int, Array[Int]] = Map::new()
  let ref_none = Ref::new(
    ObjectData::ToParseFromObjectStream(map_none, 5, 0, (_stream, _idx) => []),
  )
  pdf_parse.objects.objects.set(11, (ref_none, 0))
  match pdf_parse.lookup_obj(11) {
    PdfObject::Null => ()
    _ => fail("expected null")
  }
  let map_missing : Map[Int, Array[Int]] = Map::new()
  map_missing.set(12, [0])
  let ref_missing = Ref::new(
    ObjectData::ToParseFromObjectStream(map_missing, 6, 0, (_stream, _idx) => [
      (13, (Ref::new(ObjectData::Parsed(PdfObject::Integer(7))), 0)),
    ]),
  )
  pdf_parse.objects.objects.set(12, (ref_missing, 0))
  match pdf_parse.lookup_obj(12) {
    PdfObject::Null => ()
    _ => fail("expected null")
  }
  let map_found : Map[Int, Array[Int]] = Map::new()
  map_found.set(14, [0])
  let ref_found = Ref::new(
    ObjectData::ToParseFromObjectStream(map_found, 7, 0, (_stream, _idx) => [
      (14, (Ref::new(ObjectData::Parsed(PdfObject::Integer(8))), 0)),
    ]),
  )
  pdf_parse.objects.objects.set(14, (ref_found, 0))
  assert_integer(pdf_parse.lookup_obj(14), 8)
}
