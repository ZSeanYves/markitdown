///|
test "@pdfsyntax.PdfSyntax::new().lex_keyword rewinds endobj suffix" {
  let input = @pdfio.Input::of_string("endobj123 0 obj")
  let token = @pdfsyntax.PdfSyntax::new().lex_keyword(input)
  match token {
    @pdfgenlex.Token::LexEndObj => ()
    _ => fail("expected LexEndObj")
  }
  match @pdfsyntax.PdfSyntax::new().lex_number(input) {
    @pdfgenlex.Token::LexInt(123) => ()
    _ => fail("expected 123")
  }
}

///|
test "@pdfsyntax.PdfSyntax::new().lex_next returns LexNone for unknown uppercase" {
  let input = @pdfio.Input::of_string("T")
  let dict_level : Ref[Int] = { val: 0 }
  let array_level : Ref[Int] = { val: 0 }
  let previous = Array::new()
  let token = @pdfsyntax.PdfSyntax::new().lex_next(
    dict_level,
    array_level,
    false,
    input,
    previous,
    true,
    _ => [],
  )
  match token {
    @pdfgenlex.Token::LexNone => ()
    _ => fail("expected LexNone")
  }
}

///|
test "@pdfsyntax.PdfSyntax::new().lex_next recovers from lex errors" {
  let input = @pdfio.Input::of_string("(")
  let dict_level : Ref[Int] = { val: 0 }
  let array_level : Ref[Int] = { val: 0 }
  let previous = Array::new()
  let token = @pdfe.with_logger(_ => (), () => {
    @pdfsyntax.PdfSyntax::new().lex_next(
      dict_level,
      array_level,
      false,
      input,
      previous,
      true,
      _ => [],
    )
  })
  match token {
    @pdfgenlex.Token::StopLexing => ()
    _ => fail("expected StopLexing")
  }
}

///|
test "@pdfsyntax.PdfSyntax::new().lex_hexstring rejects invalid hex" {
  let input = @pdfio.Input::of_string("<G>")
  let res : Result[@pdfgenlex.Token, Error] = try? @pdfsyntax.PdfSyntax::new().lex_hexstring(
    input,
  )
  match res {
    Err(_) => ()
    _ => fail("expected @pdfsyntax.PdfSyntax::new().lex_hexstring failure")
  }
}

///|
test "@pdfsyntax.PdfSyntax::new().lex_hexstring pads odd nibble" {
  let input = @pdfio.Input::of_string("<F>")
  let token = @pdfsyntax.PdfSyntax::new().lex_hexstring(input)
  match token {
    @pdfgenlex.Token::LexString(s) => {
      let bytes = @pdfio.bytes_of_string(s)
      assert_eq(bytes.length(), 1)
      assert_eq(bytes[0].to_int(), 0xF0)
    }
    _ => fail("expected LexString")
  }
}

///|
test "@pdfsyntax.PdfSyntax::new().lex_hexstring ignores whitespace" {
  let input = @pdfio.Input::of_string("<0F 0A>")
  let token = @pdfsyntax.PdfSyntax::new().lex_hexstring(input)
  match token {
    @pdfgenlex.Token::LexString(s) => {
      let bytes = @pdfio.bytes_of_string(s)
      assert_eq(bytes.length(), 2)
      assert_eq(bytes[0].to_int(), 0x0F)
      assert_eq(bytes[1].to_int(), 0x0A)
    }
    _ => fail("expected LexString")
  }
}

///|
test "@pdfsyntax.PdfSyntax::new().lex_dictionary minus_one stops after closing dict" {
  let input = @pdfio.Input::of_string("/Type /Example >> trailer")
  let tokens = @pdfsyntax.PdfSyntax::new().lex_dictionary(true, input)
  if tokens.length() == 0 {
    fail("expected tokens")
  }
  let last = tokens[tokens.length() - 1]
  match last {
    @pdfgenlex.Token::LexRightDict => ()
    _ => fail("expected closing dict")
  }
}

///|
test "@pdfsyntax.PdfSyntax::new().lex_name rejects invalid hex" {
  let input = @pdfio.Input::of_string("/#GZ")
  let res : Result[@pdfgenlex.Token, Error] = try? @pdfsyntax.PdfSyntax::new().lex_name(
    input,
  )
  match res {
    Err(_) => ()
    _ => fail("expected @pdfsyntax.PdfSyntax::new().lex_name failure")
  }
}

///|
test "@pdfsyntax.PdfSyntax::new().lex_name rejects truncated hex" {
  let input = @pdfio.Input::of_string("/#1")
  let res : Result[@pdfgenlex.Token, Error] = try? @pdfsyntax.PdfSyntax::new().lex_name(
    input,
  )
  match res {
    Err(_) => ()
    _ => fail("expected @pdfsyntax.PdfSyntax::new().lex_name failure")
  }
}

///|
fn make_realistic_widget_objstm_source() -> (String, Int) {
  let obj1 = "<</AP<</N 75 0 R>>/DA(/MyriadPro-Regular 10.00 Tf 0 g)/F 4/FT/Tx/MK<<>>/P 48 0 R/Parent 17 0 R/Q 0/Rect[147.171 751.323 591.465 771.165]/StructParent 0/Subtype/Widget/T(\u{00FE}\u{00FF}\u{0000}T\u{0000}e\u{0000}k\u{0000}s\u{0000}t\u{0000}v\u{0000}e\u{0000}l\u{0000}d\u{0000}1\u{0000}[\u{0000}0\u{0000}])/TU(Single line, unlimited length)/Type/Annot/V(Lorem ipsum dolor sit amet, consectetur adipiscing elit.)>>"
  let obj2 = "<</AP<</N 74 0 R>>/DA(/MyriadPro-Regular 10.00 Tf 0 g)/F 4/FT/Tx/MK<<>>/MaxLen 10/P 48 0 R/Parent 17 0 R/Q 0/Rect[147.171 715.323 591.465 735.165]/StructParent 1/Subtype/Widget/T(\u{00FE}\u{00FF}\u{0000}T\u{0000}e\u{0000}k\u{0000}s\u{0000}t\u{0000}v\u{0000}e\u{0000}l\u{0000}d\u{0000}2\u{0000}[\u{0000}0\u{0000}])/TU(Single line, length 10)/Type/Annot/V(Lorem ipsu)>>"
  let offset2 = @pdfio.bytes_of_string(obj1).length()
  let header = "61 0 62 \{offset2} "
  let payload = header + obj1 + obj2
  let first = @pdfio.bytes_of_string(header).length()
  let payload_len = @pdfio.bytes_of_string(payload).length()
  let source = "81 0 obj\n" +
    "<< /First " +
    first.to_string() +
    " /Length " +
    payload_len.to_string() +
    " /N 2 /Type /ObjStm >>\n" +
    "stream\n" +
    payload +
    "\nendstream\n" +
    "endobj"
  (source, first)
}

///|
fn widget_obj1() -> String {
  "<</AP<</N 75 0 R>>/DA(/MyriadPro-Regular 10.00 Tf 0 g)/F 4/FT/Tx/MK<<>>/P 48 0 R/Parent 17 0 R/Q 0/Rect[147.171 751.323 591.465 771.165]/StructParent 0/Subtype/Widget/T(\u{00FE}\u{00FF}\u{0000}T\u{0000}e\u{0000}k\u{0000}s\u{0000}t\u{0000}v\u{0000}e\u{0000}l\u{0000}d\u{0000}1\u{0000}[\u{0000}0\u{0000}])/TU(Single line, unlimited length)/Type/Annot/V(Lorem ipsum dolor sit amet, consectetur adipiscing elit.)>>"
}

///|
fn widget_obj2() -> String {
  "<</AP<</N 74 0 R>>/DA(/MyriadPro-Regular 10.00 Tf 0 g)/F 4/FT/Tx/MK<<>>/MaxLen 10/P 48 0 R/Parent 17 0 R/Q 0/Rect[147.171 715.323 591.465 735.165]/StructParent 1/Subtype/Widget/T(\u{00FE}\u{00FF}\u{0000}T\u{0000}e\u{0000}k\u{0000}s\u{0000}t\u{0000}v\u{0000}e\u{0000}l\u{0000}d\u{0000}2\u{0000}[\u{0000}0\u{0000}])/TU(Single line, length 10)/Type/Annot/V(Lorem ipsu)>>"
}

///|
fn acroform_obj54() -> String {
  "<</DA(/Helv 0 Tf 0 g )/DR<</Font<</Helv 18 0 R/MyriadPro-Regular 19 0 R>>>>/Fields[16 0 R]/XFA[(xdp:xdp)77 0 R(config)2 0 R(template)3 0 R(localeSet)4 0 R(xmpmeta)5 0 R(form)78 0 R(datasets)79 0 R(</xdp:xdp>)80 0 R]>>"
}

///|
test "parse_object_stream preserves widget boundary keys in minimal objstm" {
  let (source, _first) = make_realistic_widget_objstm_source()
  let input = @pdfio.Input::of_string(source)
  let xrefs : Map[Int, XRef] = Map([])
  xrefs.set(81, XRef::Plain(0, 0))
  let partial_pdf = @pdf.Pdf::{
    major: 0,
    minor: 0,
    root: 0,
    objects: {
      max_obj_num: 81,
      parse: None,
      objects: Map([]),
      object_stream_ids: Map([]),
    },
    trailerdict: @pdf.PdfObject::Dictionary([]),
    was_linearized: false,
    saved_encryption: None,
  }
  let parsed_result : Result[Array[(Int, @pdf.PdfObject)], Error] = try? parse_object_stream(
    input,
    xrefs,
    81,
    None,
    None,
    partial_pdf,
  )
  let parsed : Array[(Int, @pdf.PdfObject)] = match parsed_result {
    Ok(value) => value
    Err(err) =>
      match err {
        @pdf.PdfError::Msg(msg) =>
          fail("minimal objstm parse_object_stream failed: " + msg)
        _ =>
          fail("minimal objstm parse_object_stream failed: " + err.to_string())
      }
  }
  let first_widget = match parsed.search_by(pair => pair.0 == 61) {
    Some(i) => parsed[i].1
    None => fail("expected object 61")
  }
  if first_widget.lookup_immediate("/AP") is None {
    fail("minimal objstm lost /AP")
  }
  match first_widget.lookup_immediate("/V") {
    Some(
      @pdf.PdfObject::String(
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
      )
    ) => ()
    Some(other) => fail("minimal objstm unexpected /V: " + other.to_string())
    None => fail("minimal objstm lost /V")
  }
}

///|
test "parse_object_stream preserves widget boundary keys in flated minimal objstm" {
  let (plain_source, first) = make_realistic_widget_objstm_source()
  let marker = "stream\n"
  let stream_pos = match plain_source.find(marker) {
    Some(v) => v + marker.length()
    None => fail("expected stream marker")
  }
  let end_marker = "\nendstream"
  let end_pos = match plain_source.find(end_marker) {
    Some(v) => v
    None => fail("expected endstream marker")
  }
  let payload = plain_source[stream_pos:end_pos].to_owned()
  let compressed = @pdfcodec.PdfCodec::new().encode_flate(
    @pdfio.bytes_of_string(payload),
  )
  let source = "81 0 obj\n" +
    "<< /Filter /FlateDecode /First " +
    first.to_string() +
    " /Length " +
    compressed.length().to_string() +
    " /N 2 /Type /ObjStm >>\n" +
    "stream\n" +
    @pdfio.string_of_bytes(compressed) +
    "\nendstream\n" +
    "endobj"
  let input = @pdfio.Input::of_string(source)
  let xrefs : Map[Int, XRef] = Map([])
  xrefs.set(81, XRef::Plain(0, 0))
  let partial_pdf = @pdf.Pdf::{
    major: 0,
    minor: 0,
    root: 0,
    objects: {
      max_obj_num: 81,
      parse: None,
      objects: Map([]),
      object_stream_ids: Map([]),
    },
    trailerdict: @pdf.PdfObject::Dictionary([]),
    was_linearized: false,
    saved_encryption: None,
  }
  let parsed_result : Result[Array[(Int, @pdf.PdfObject)], Error] = try? parse_object_stream(
    input,
    xrefs,
    81,
    None,
    None,
    partial_pdf,
  )
  let parsed : Array[(Int, @pdf.PdfObject)] = match parsed_result {
    Ok(value) => value
    Err(err) =>
      match err {
        @pdf.PdfError::Msg(msg) =>
          fail("flated minimal objstm parse_object_stream failed: " + msg)
        _ =>
          fail(
            "flated minimal objstm parse_object_stream failed: " +
            err.to_string(),
          )
      }
  }
  let first_widget = match parsed.search_by(pair => pair.0 == 61) {
    Some(i) => parsed[i].1
    None => fail("expected object 61")
  }
  if first_widget.lookup_immediate("/AP") is None {
    fail("flated minimal objstm lost /AP")
  }
  match first_widget.lookup_immediate("/V") {
    Some(
      @pdf.PdfObject::String(
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
      )
    ) => ()
    Some(other) =>
      fail("flated minimal objstm unexpected /V: " + other.to_string())
    None => fail("flated minimal objstm lost /V")
  }
}

///|
test "parse_object_stream preserves widget keys after real acroform object in flated objstm" {
  let obj54 = acroform_obj54()
  let obj61 = widget_obj1()
  let obj62 = widget_obj2()
  let off61 = @pdfio.bytes_of_string(obj54).length()
  let off62 = off61 + @pdfio.bytes_of_string(obj61).length()
  let header = "54 0 61 \{off61} 62 \{off62} "
  let payload = header + obj54 + obj61 + obj62
  let first = @pdfio.bytes_of_string(header).length()
  let compressed = @pdfcodec.PdfCodec::new().encode_flate(
    @pdfio.bytes_of_string(payload),
  )
  let source = "81 0 obj\n" +
    "<< /Filter /FlateDecode /First " +
    first.to_string() +
    " /Length " +
    compressed.length().to_string() +
    " /N 3 /Type /ObjStm >>\n" +
    "stream\n" +
    @pdfio.string_of_bytes(compressed) +
    "\nendstream\n" +
    "endobj"
  let input = @pdfio.Input::of_string(source)
  let xrefs : Map[Int, XRef] = Map([])
  xrefs.set(81, XRef::Plain(0, 0))
  let partial_pdf = @pdf.Pdf::{
    major: 0,
    minor: 0,
    root: 0,
    objects: {
      max_obj_num: 81,
      parse: None,
      objects: Map([]),
      object_stream_ids: Map([]),
    },
    trailerdict: @pdf.PdfObject::Dictionary([]),
    was_linearized: false,
    saved_encryption: None,
  }
  let parsed_result : Result[Array[(Int, @pdf.PdfObject)], Error] = try? parse_object_stream(
    input,
    xrefs,
    81,
    None,
    None,
    partial_pdf,
  )
  let parsed : Array[(Int, @pdf.PdfObject)] = match parsed_result {
    Ok(value) => value
    Err(err) =>
      match err {
        @pdf.PdfError::Msg(msg) =>
          fail("flated 54/61/62 objstm parse_object_stream failed: " + msg)
        _ =>
          fail(
            "flated 54/61/62 objstm parse_object_stream failed: " +
            err.to_string(),
          )
      }
  }
  let first_widget = match parsed.search_by(pair => pair.0 == 61) {
    Some(i) => parsed[i].1
    None => fail("expected object 61")
  }
  if first_widget.lookup_immediate("/AP") is None {
    fail("flated 54/61/62 objstm lost /AP on object 61")
  }
  match first_widget.lookup_immediate("/V") {
    Some(
      @pdf.PdfObject::String(
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
      )
    ) => ()
    Some(other) =>
      fail("flated 54/61/62 objstm unexpected /V: " + other.to_string())
    None => fail("flated 54/61/62 objstm lost /V on object 61")
  }
}
