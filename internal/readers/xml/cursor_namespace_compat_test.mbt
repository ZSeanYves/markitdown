///|
test "XML cursor unbound prefix compatibility is explicit and strict remains default" {
  let limits = @xml.XmlCursorLimits::new(
    MeasurementOnly,
    max_depth=None,
    max_token_bytes=None,
    max_attributes=None,
    max_tokens=None,
    text_fragment_bytes=8,
  ).unwrap()
  for compatible in [false, true] {
    let cursor = @xml.new_xml_cursor(limits, allow_unbound_prefixes=compatible).unwrap()
    defer cursor.close()
    cursor.feed(b"<cp:r><dc:title>text</dc:title></cp:r>", eof=true).unwrap()
    let names : Array[(String, String, String?)] = []
    let mut failed = false
    while true {
      match cursor.next() {
        Err(Syntax(InvalidName, _, _)) => {
          failed = true
          break
        }
        Err(_) => fail("unexpected XML failure")
        Ok(End) => break
        Ok(Token(StartElement(name, _, _, _))) =>
          names.push((name.raw, name.local_name, name.namespace_uri))
        _ => ()
      }
    }
    assert_eq(failed, !compatible)
    if compatible {
      assert_eq(names, [("cp:r", "r", None), ("dc:title", "title", None)])
    }
  }
}

///|
test "XML prefix compatibility preserves declared bindings rebinding and restoration" {
  let limits = @xml.XmlCursorLimits::new(
    MeasurementOnly,
    max_depth=None,
    max_token_bytes=None,
    max_attributes=None,
    max_tokens=None,
    text_fragment_bytes=8,
  ).unwrap()
  let cursor = @xml.new_xml_cursor(limits, allow_unbound_prefixes=true).unwrap()
  defer cursor.close()
  cursor
  .feed(
    b"<r xmlns:p='urn:first'><p:x/><n xmlns:p='urn:second'><p:y/></n><p:z/><q:last/></r>",
    eof=true,
  )
  .unwrap()
  let names : Array[(String, String?)] = []
  while true {
    match cursor.next().unwrap() {
      End => break
      Token(StartElement(name, _, _, _)) =>
        names.push((name.raw, name.namespace_uri))
      _ => ()
    }
  }
  assert_eq(names, [
    ("r", None),
    ("p:x", Some("urn:first")),
    ("n", None),
    ("p:y", Some("urn:second")),
    ("p:z", Some("urn:first")),
    ("q:last", None),
  ])
}

///|
test "XML compatibility keeps unbound raw attribute names distinct and rejects real expanded duplicates" {
  let limits = @xml.XmlCursorLimits::new(
    MeasurementOnly,
    max_depth=None,
    max_token_bytes=None,
    max_attributes=None,
    max_tokens=None,
    text_fragment_bytes=8,
  ).unwrap()
  for bound in [false, true] {
    let cursor = @xml.new_xml_cursor(limits, allow_unbound_prefixes=true).unwrap()
    defer cursor.close()
    let bytes = if bound {
      b"<r xmlns:p='urn:same' xmlns:q='urn:same' p:a='1' q:a='2'/>"
    } else {
      b"<r p:a='1' q:a='2'/>"
    }
    cursor.feed(bytes, eof=true).unwrap()
    match cursor.next() {
      Err(Syntax(DuplicateAttribute, _, _)) => assert_true(bound)
      Ok(Token(StartElement(_, attrs, _, _))) => {
        assert_false(bound)
        assert_eq(attrs.map(attr => (attr.name.raw, attr.name.namespace_uri)), [
          ("p:a", None),
          ("q:a", None),
        ])
      }
      _ => fail("unexpected expanded attribute result")
    }
  }
}

///|
test "XML unbound compatibility preserves reserved xmlns and xml namespace constraints" {
  let limits = @xml.XmlCursorLimits::new(
    MeasurementOnly,
    max_depth=None,
    max_token_bytes=None,
    max_attributes=None,
    max_tokens=None,
    text_fragment_bytes=8,
  ).unwrap()
  let observed : Array[(Bool, Int32, Bool)] = []
  let invalid = [
    b"<xmlns:r/>", b"<r xmlns:xml='urn:bad'/>", b"<r xmlns:xmlns='urn:bad'/>", b"<r xmlns:p='http://www.w3.org/XML/1998/namespace'/>",
    b"<r xmlns='http://www.w3.org/XML/1998/namespace'/>",
  ]
  for compatible in [false, true] {
    for index in 0..<invalid.length() {
      let cursor = @xml.new_xml_cursor(
        limits,
        allow_unbound_prefixes=compatible,
      ).unwrap()
      defer cursor.close()
      cursor.feed(invalid[index], eof=true).unwrap()
      observed.push(
        (compatible, index, cursor.next() is Err(Syntax(InvalidName, _, _))),
      )
    }
    let cursor = @xml.new_xml_cursor(limits, allow_unbound_prefixes=compatible).unwrap()
    defer cursor.close()
    cursor.feed(b"<xml:r xml:lang='en'/>", eof=true).unwrap()
    match cursor.next().unwrap() {
      Token(StartElement(name, attributes, _, _)) => {
        assert_eq(
          name.namespace_uri,
          Some("http://www.w3.org/XML/1998/namespace"),
        )
        assert_eq(attributes[0].name.namespace_uri, name.namespace_uri)
      }
      _ => fail("implicit standard xml binding must remain available")
    }
  }
  assert_eq(observed, [
    (false, 0, true),
    (false, 1, true),
    (false, 2, true),
    (false, 3, true),
    (false, 4, true),
    (true, 0, true),
    (true, 1, true),
    (true, 2, true),
    (true, 3, true),
    (true, 4, true),
  ])
}
