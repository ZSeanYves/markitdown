///|
fn contract_partial_pdf(max_obj_num : Int) -> @pdf.Pdf {
  {
    major: 0,
    minor: 0,
    root: 0,
    objects: {
      max_obj_num,
      parse: None,
      objects: Map([]),
      object_stream_ids: Map([]),
    },
    trailerdict: @pdf.PdfObject::Dictionary([]),
    was_linearized: false,
    saved_encryption: None,
  }
}

///|
fn contract_widget_obj(name : String, label : String, value : String) -> String {
  "<</Subtype/Widget/AP<</N 75 0 R>>/T(" +
  name +
  ")/TU(" +
  label +
  ")/V(" +
  value +
  ")>>"
}

///|
fn contract_parse_objstm(
  payload : String,
  first : Int,
) -> Array[(Int, @pdf.PdfObject)] raise {
  let data = @pdfio.bytes_of_string(payload)
  let source = "81 0 obj\n" +
    "<< /First " +
    first.to_string() +
    " /Length " +
    data.length().to_string() +
    " /N 2 /Type /ObjStm >>\n" +
    "stream\n" +
    payload +
    "\nendstream\n" +
    "endobj"
  let xrefs : Map[Int, XRef] = Map([])
  xrefs.set(81, XRef::Plain(0, 0))
  parse_object_stream(
    @pdfio.Input::of_string(source),
    xrefs,
    81,
    None,
    None,
    contract_partial_pdf(81),
  )
}

///|
fn contract_expect_widget(
  objects : Array[(Int, @pdf.PdfObject)],
  objnum : Int,
  value : String,
) -> Unit raise {
  let obj = match objects.search_by(pair => pair.0 == objnum) {
    Some(index) => objects[index].1
    None => fail("expected object " + objnum.to_string())
  }
  match obj.lookup_immediate("/Subtype") {
    Some(@pdf.PdfObject::Name(name)) if name.equal_string_bytes("/Widget") => ()
    Some(other) => fail("expected /Subtype /Widget, got " + other.to_string())
    None => fail("expected /Subtype /Widget")
  }
  if obj.lookup_immediate("/AP") is None {
    fail("expected widget /AP to survive object stream parsing")
  }
  if obj.lookup_immediate("/T") is None {
    fail("expected widget /T to survive object stream parsing")
  }
  if obj.lookup_immediate("/TU") is None {
    fail("expected widget /TU to survive object stream parsing")
  }
  match obj.lookup_immediate("/V") {
    Some(@pdf.PdfObject::String(actual)) => assert_eq(actual, value)
    Some(other) => fail("expected widget /V string, got " + other.to_string())
    None => fail("expected widget /V to survive object stream parsing")
  }
}

///|
test "replacement contract: object stream preserves compact widget boundaries" {
  let first_widget = contract_widget_obj("field1", "First label", "alpha")
  let second_widget = contract_widget_obj("field2", "Second label", "beta")
  let header = "61 0 62 " +
    @pdfio.bytes_of_string(first_widget).length().to_string() +
    " "
  let payload = header + first_widget + second_widget
  let parsed = contract_parse_objstm(
    payload,
    @pdfio.bytes_of_string(header).length(),
  )
  contract_expect_widget(parsed, 61, "alpha")
  contract_expect_widget(parsed, 62, "beta")
}

///|
test "replacement contract: malformed reader strict mode fails closed" {
  let data =
    #|%PDF-1.4
    #|1 0 obj
    #|<< /Type /Catalog /Pages 2 0 R >>
    #|endobj
    #|2 0 obj
    #|<< /Type /Pages /Count 0 /Kids [] >>
    #|endobj
    #|%%EOF
  let strict = PdfRead::new(error_on_malformed=true, logger=_ => ())
  let res : Result[@pdf.Pdf, Error] = try
    @pdfe.with_silenced_logs(fn() raise {
      strict.pdf_of_input(None, None, @pdfio.Input::of_string(data))
    })
    |> Ok
  catch {
    e => Err(e)
  }
  assert_true(res is Err(_))
}
