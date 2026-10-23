///|
test "native upgrade XML decimal entities reject integer wraparound" {
  let parsed = try parse_xml_document("<r>&#4294967361;</r>") |> Ok catch {
    error => Err(error)
  }
  match parsed {
    Err(ParseError(_)) => ()
    _ => fail("an out-of-range decimal entity must not wrap to a valid scalar")
  }
}

///|
test "native upgrade XML hex entities reject integer wraparound" {
  let parsed = try parse_xml_document("<r>&#x100000041;</r>") |> Ok catch {
    error => Err(error)
  }
  match parsed {
    Err(ParseError(_)) => ()
    _ =>
      fail("an out-of-range hexadecimal entity must not wrap to a valid scalar")
  }
}

///|
test "native upgrade XML numeric entities preserve valid Unicode scalars" {
  let document = parse_xml_document("<r>&#65;&#x41;&#x1F600;</r>")
  let root = document.root.unwrap()
  match root.children[0] {
    Text(text) => assert_eq(text.text, "AA😀")
    _ => fail("numeric entities must decode to a text node")
  }
}
