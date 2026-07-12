///|
test "source IO preserves prepared byte and text payloads across input kinds" {
  let text_source = @input.input_from_text("hello", source_name="hello.txt")
  match read_source_text(text_source) {
    Ok(payload) => {
      assert_eq(payload.text, "hello")
      assert_true(payload.prepared_source.text == Some("hello"))
    }
    Err(error) => fail(error)
  }
  match read_source_bytes(text_source) {
    Ok(payload) => {
      assert_eq(payload.bytes.length(), 5)
      assert_true(payload.prepared_source.bytes is Some(_))
    }
    Err(error) => fail(error)
  }
  let bytes_source = @input.input_from_bytes(
    @utf8.encode("world"),
    source_name="world.txt",
  )
  match read_source_text(bytes_source) {
    Ok(payload) => assert_true(payload.prepared_source.text == Some("world"))
    Err(error) => fail(error)
  }
  match read_source_bytes(bytes_source) {
    Ok(payload) => assert_true(payload.prepared_source.bytes is Some(_))
    Err(error) => fail(error)
  }
  let missing = @input.input_from_path(
    "/definitely/missing/source-io-contract.txt",
  )
  assert_true(read_source_bytes(missing) is Err(_))
  assert_true(read_source_text(missing) is Err(_))
}

///|
test "source IO decodes UTF16 BOM text in little and big endian" {
  let le = Bytes::from_array([0xFF, 0xFE, 0x41, 0, 0x42, 0].map(Int::to_byte))
  let be = Bytes::from_array([0xFE, 0xFF, 0, 0x41, 0, 0x42].map(Int::to_byte))
  assert_true(decode_utf16_text_bytes(le) == Some("AB"))
  assert_true(decode_utf16_text_bytes(be) == Some("AB"))
  assert_true(decode_utf16_text_bytes(Bytes::new(0)) is None)
  assert_true(decode_utf16_text_bytes(@utf8.encode("AB")) is None)
  let source = @input.input_from_bytes(le, source_name="utf16.txt")
  match read_source_text_with_utf16_bom(source) {
    Ok(payload) => {
      assert_eq(payload.text, "AB")
      assert_true(payload.prepared_source.text == Some("AB"))
    }
    Err(error) => fail(error)
  }
  match
    read_source_text_with_utf16_bom(
      @input.input_from_bytes(@utf8.encode("plain"), source_name="plain.txt"),
    ) {
    Ok(payload) => assert_eq(payload.text, "plain")
    Err(error) => fail(error)
  }
}

///|
test "source IO sniffs XML encodings and fails closed on invalid UTF8" {
  let latin = Bytes::from_array(
    [
      0x3C, 0x3F, 0x78, 0x6D, 0x6C, 0x20, 0x65, 0x6E, 0x63, 0x6F, 0x64, 0x69, 0x6E,
      0x67, 0x3D, 0x22, 0x49, 0x53, 0x4F, 0x2D, 0x38, 0x38, 0x35, 0x39, 0x2D, 0x31,
      0x22, 0x3F, 0x3E, 0xE9,
    ].map(Int::to_byte),
  )
  assert_true(sniff_xml_declared_encoding(latin) == Some("iso-8859-1"))
  match decode_xml_input_bytes(latin) {
    Ok(text) => assert_true(text.has_suffix("é"))
    Err(error) => fail(error)
  }
  let utf8_xml = @utf8.encode("<?xml version='1.0'?><root>ok</root>")
  assert_true(sniff_xml_declared_encoding(utf8_xml) is None)
  assert_true(decode_xml_input_bytes(utf8_xml) is Ok(_))
  assert_true(
    decode_xml_input_bytes(Bytes::from_array([0xC3, 0x28].map(Int::to_byte)))
    is Err(_),
  )
  for
    malformed in [
      "<?xml encoding ?>", "<?xml encoding=unquoted?>", "<?xml encoding=\"open?>",
    ] {
    assert_true(sniff_xml_declared_encoding(@utf8.encode(malformed)) is None)
  }
  let text_source = @input.input_from_text("<root/>", source_name="root.xml")
  match read_xml_source_text(text_source) {
    Ok(payload) => assert_eq(payload.text, "<root/>")
    Err(error) => fail(error)
  }
  match
    read_xml_source_text(
      @input.input_from_bytes(utf8_xml, source_name="bytes.xml"),
    ) {
    Ok(payload) => assert_true(payload.prepared_source.text is Some(_))
    Err(error) => fail(error)
  }
}
