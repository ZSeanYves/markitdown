///|
test "source IO preserves prepared byte and text payloads across input kinds" {
  let text_source = @input.input_from_text("hello", source_name="hello.txt")
  match read_source_text(text_source) {
    Ok(payload) => {
      assert_eq(payload.text, "hello")
      assert_true(@input.input_text(payload.prepared_source) == Some("hello"))
    }
    Err(error) => fail(error)
  }
  match read_source_bytes(text_source) {
    Ok(payload) => {
      assert_eq(payload.bytes.length(), 5)
      assert_true(@input.input_bytes(payload.prepared_source) is Some(_))
    }
    Err(error) => fail(error)
  }
  let bytes_source = @input.input_from_bytes(
    @utf8.encode("world"),
    source_name="world.txt",
  )
  match read_source_text(bytes_source) {
    Ok(payload) =>
      assert_true(@input.input_text(payload.prepared_source) == Some("world"))
    Err(error) => fail(error)
  }
  match read_source_bytes(bytes_source) {
    Ok(payload) =>
      assert_true(@input.input_bytes(payload.prepared_source) is Some(_))
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
      assert_true(@input.input_text(payload.prepared_source) == Some("AB"))
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
    Ok(payload) =>
      assert_true(@input.input_text(payload.prepared_source) is Some(_))
    Err(error) => fail(error)
  }
}

///|
fn chunked_source_io_reader(
  bytes : Bytes,
  max_chunk : Int,
) -> @input.InputSource {
  let reader = @input.make_input_reader(
    fn(offset, length) {
      let start = offset.to_int()
      let end = (start + length.min(max_chunk)).min(bytes.length())
      Ok(bytes.view(start~, end~).to_owned())
    },
    size=bytes.length().to_int64(),
  )
  @input.input_from_reader(reader, source_name="chunked.txt")
}

///|
test "streaming UTF8 reader preserves emoji CRLF and provenance offsets" {
  let text = "A\r\n😀B"
  let bytes = @utf8.encode(text)
  let reader = open_source_text_chunk_reader(
    chunked_source_io_reader(bytes, 1),
    chunk_size=1,
  ).unwrap()
  let collected = StringBuilder::new()
  let mut last : SourceTextChunk? = None
  while true {
    match (reader.next)().unwrap() {
      Some(chunk) => {
        collected.write_string(chunk.text)
        last = Some(chunk)
      }
      None => break
    }
  }
  assert_eq(collected.to_string(), text)
  let last = last.unwrap()
  assert_eq(last.byte_end, bytes.length().to_int64())
  assert_eq(last.line_end, 2)
  assert_eq(last.utf16_end, 6)
}

///|
test "streaming UTF8 reader preserves markup entities and CSV multiline quotes" {
  for
    text in [
      "<p title=\"x&amp;y\">😀</p>\r\n", "name,value\r\nalpha,\"line one\r\nline two\"\r\n",
    ] {
    let bytes = @utf8.encode(text)
    assert_true(
      collect_source_text_chunks(chunked_source_io_reader(bytes, 2)) == Ok(text),
    )
  }
  let invalid = chunked_source_io_reader(
    Bytes::from_array([0xF0, 0x28, 0x8C, 0x28]),
    1,
  )
  assert_true(collect_source_text_chunks(invalid) == Err("utf8 decode failed"))
}

///|
test "physical line reader preserves CRLF emoji and trailing records" {
  let source = @input.input_from_text(
    "\u{FEFF}alpha\r\nemoji 😀\rblank\n\nlast",
  )
  let reader = open_source_text_line_reader(source, max_line_chars=64).unwrap()
  let values : Array[SourceTextLine] = []
  while true {
    match (reader.next)().unwrap() {
      Some(line) => values.push(line)
      None => break
    }
  }
  assert_eq(values.length(), 5)
  assert_eq(values[0].text, "alpha")
  assert_eq(values[1].text, "emoji 😀")
  assert_eq(values[2].text, "blank")
  assert_eq(values[3].text, "")
  assert_eq(values[4].text, "last")
  assert_eq(values[4].line_no, 5)
}

///|
test "block reader retains one bounded record and line provenance" {
  let reader = open_source_text_block_reader(
    @input.input_from_text("one\ntwo\n\nthree\n\nfour\nfive\nsix"),
    max_block_lines=2,
  ).unwrap()
  let first = (reader.next)().unwrap().unwrap()
  assert_eq(first.lines, ["one", "two"])
  assert_eq(first.line_start, 1)
  assert_eq(first.line_end, 2)
  assert_false(first.truncated)
  let second = (reader.next)().unwrap().unwrap()
  assert_eq(second.lines, ["three"])
  let third = (reader.next)().unwrap().unwrap()
  assert_eq(third.lines, ["four", "five"])
  assert_true(third.truncated)
  assert_true((reader.next)().unwrap() is None)
}

///|
test "line readers reject invalid limits and missing sources" {
  match
    open_source_text_line_reader(
      @input.input_from_text("value"),
      max_line_chars=0,
    ) {
    Err(message) => assert_eq(message, "text line limit must be positive")
    Ok(_) => fail("non-positive line limit should fail")
  }
  let missing = @input.input_from_path(
    "/definitely/missing/source-line-reader.txt",
  )
  assert_true(open_source_text_line_reader(missing) is Err(_))
  assert_true(open_source_text_block_reader(missing) is Err(_))
}
