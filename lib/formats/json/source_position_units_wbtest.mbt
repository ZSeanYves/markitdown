///|
fn units_json_reader(bytes : Bytes) -> @input.InputSource {
  @input.input_from_reader_with_format(
    @input.make_async_input_reader(
      async fn(offset, length) {
        @async.pause()
        let start = offset.to_int()
        let end = (start + length.min(1)).min(bytes.length())
        Ok(bytes.exact_view(start~, end~).to_owned())
      },
      size=bytes.length().to_int64(),
    ),
    "units.json",
    Some(Json),
  )
}

///|
fn units_json_token(
  text : String,
  stream : JsonStreamDocument,
  pointer : String,
  kind : JsonStreamEventKind,
  lexeme : String,
) -> Unit raise {
  let index = text.find(lexeme).unwrap()
  let start = @utf8.encode(text[:index].to_owned()).length()
  let end = start + @utf8.encode(lexeme).length()
  let event = stream.events.filter(event => {
      event.pointer == pointer && event.kind == kind
    })[0]
  assert_eq(event.source.byte_start, start)
  assert_eq(event.source.byte_end, end)
  assert_eq(
    @utf8.encode(text).exact_view(start~, end~).to_owned(),
    @utf8.encode(lexeme),
  )
}

///|
test "JSON stream positions count original token UTF8 rather than decoded scalar or UTF16 lengths" {
  let normalized = "{\n\"é\":\"\\u0061😀\", \"n\":-12.5e+2, \"truth\":true, \"nil\":null\n}"
  let input = "\u{FEFF}" + normalized.replace_all(old="\n", new="\r\n")
  let stream = parse_json_stream(input)
  units_json_token(normalized, stream, "/é", Key, "\"é\"")
  units_json_token(normalized, stream, "/é", StringValue, "\"\\u0061😀\"")
  units_json_token(normalized, stream, "/n", NumberValue, "-12.5e+2")
  units_json_token(normalized, stream, "/truth", BoolValue, "true")
  units_json_token(normalized, stream, "/nil", NullValue, "null")
  let ascii = "{\"n\":12,\"b\":true,\"z\":null}"
  let control = parse_json_stream(ascii)
  units_json_token(ascii, control, "/n", NumberValue, "12")
  units_json_token(ascii, control, "/b", BoolValue, "true")
  units_json_token(ascii, control, "/z", NullValue, "null")
}

///|
async test "JSON Text Bytes short Reader and explicit UTF16 decode expose normalized UTF8 basis not physical offsets" {
  let text = "\u{FEFF}{\r\n\"é\":\"😀\",\r\n\"n\":12\r\n}"
  let normalized = "{\n\"é\":\"😀\",\n\"n\":12\n}"
  let bytes = @utf8.encode(text)
  let sources = [
    @input.input_from_text_with_format(text, "units.json", Some(Json)),
    @input.input_from_bytes_with_format(bytes, "units.json", Some(Json)),
    units_json_reader(bytes),
  ]
  for source in sources {
    let prepared = prepare_json_document_from_source(source).unwrap()
    let stream = prepared.stream.unwrap()
    units_json_token(normalized, stream, "/é", StringValue, "\"😀\"")
    units_json_token(normalized, stream, "/n", NumberValue, "12")
    let event = stream.events.filter(event => {
        event.pointer == "/n" && event.kind == NumberValue
      })[0]
    let reference = json_stream_source_ref(
      source,
      "/n",
      event.source.line,
      event.source.byte_start,
      event.source.byte_end,
    )
    assert_eq(
      reference.extra.get("byte_basis"),
      Some("normalized_decoded_utf8"),
    )
    assert_eq(
      reference.extra.get("byte_normalization"),
      Some("leading_bom_removed_crlf_to_lf"),
    )
    assert_true(reference.byte_end.unwrap() < bytes.length())
  }
  let utf16 = b"\xFF\xFE{\x00\"\x00x\x00\"\x00:\x00\"\x00\xE9\x00\"\x00}\x00"
  assert_true(
    prepare_json_document_from_source(
      @input.input_from_bytes_with_format(utf16, "encoded.json", Some(Json)),
    )
    is Err(_),
  )
  assert_true(
    prepare_json_document_from_source(units_json_reader(utf16)) is Err(_),
  )
  // An explicit supported decoder can supply a prepared Text representation.
  // Its physical proof still counts UTF16 bytes, while positions count UTF8.
  let decoded = @sourceio.read_source_text_with_utf16_bom(
    @input.input_from_bytes(utf16),
  ).unwrap()
  let prepared = prepare_json_document_from_source(decoded.prepared_source).unwrap()
  units_json_token(
    "{\"x\":\"é\"}",
    prepared.stream.unwrap(),
    "/x",
    StringValue,
    "\"é\"",
  )
  assert_true(@utf8.encode(decoded.text).length() != utf16.length())
}

///|
test "JSON direct positions are UTF8 ranges of its actual lexical view" {
  let text = "[\r\n{\"é\":\"😀\\u0061\"},\r\n{\"n\":12}\r\n]"
  let source = @input.input_from_text(text)
  let direct = json_compact_root_array_events_direct(text, source).unwrap()
  assert_eq(direct.length(), 2)
  let lexemes = ["{\"é\":\"😀\\u0061\"}", "{\"n\":12}"]
  for index in 0..<lexemes.length() {
    let lexeme = lexemes[index]
    let offset = text.find(lexeme).unwrap()
    let start = @utf8.encode(text[:offset].to_owned()).length()
    let end = start + @utf8.encode(lexeme).length()
    let reference = direct[index].source_ref.unwrap()
    assert_eq(reference.byte_start, Some(start))
    assert_eq(reference.byte_end, Some(end))
    assert_eq(
      reference.extra.get("byte_basis"),
      Some("normalized_decoded_utf8"),
    )
    assert_eq(reference.extra.get("byte_normalization"), Some("none"))
  }
}

///|
test "JSON direct large input checks every original lexical boundary against a linear independent oracle and stream view" {
  let rows : Array[String] = []
  let ranges : Array[(Int32, Int32, Int32, Int32)] = []
  let mut direct_offset = 3 // [ CR LF; the BOM is outside the coordinate view
  let mut stream_offset = 2 // [ LF after the stream's existing normalization
  for index in 0..<3000 {
    let row = "{\"id\":" +
      index.to_string() +
      ",\"ascii\":\"" +
      "A".repeat(2800) +
      "\",\"bmp\":\"é\",\"astral\":\"😀\",\"escape\":\"\\u0061\\n\"}"
    let width = @utf8.encode(row).length()
    ranges.push(
      (
        direct_offset,
        direct_offset + width,
        stream_offset,
        stream_offset + width,
      ),
    )
    rows.push(row)
    direct_offset += width + 3 // comma CR LF
    stream_offset += width + 2 // comma LF
  }
  let original = "[\r\n" + rows.join(",\r\n") + "\r\n]"
  assert_true(original.length() > 8_388_608)
  let original_bytes = @utf8.encode(original)
  let normalized = original.replace_all(old="\r\n", new="\n")
  let normalized_bytes = @utf8.encode(normalized)
  let source = @input.input_from_text(original)
  let stream = parse_json_stream("\u{FEFF}" + original)
  let starts = stream.events.filter(event => event.kind == ObjectStart)
  let ends = stream.events.filter(event => event.kind == ObjectEnd)
  assert_eq(starts.length(), rows.length())
  assert_eq(ends.length(), rows.length())
  for text in [original, "\u{FEFF}" + original] {
    let direct = json_compact_root_array_events_direct(text, source).unwrap()
    assert_eq(direct.length(), rows.length())
    for index in 0..<rows.length() {
      let range = ranges[index]
      let reference = direct[index].source_ref.unwrap()
      assert_eq(reference.byte_start, Some(range.0))
      assert_eq(reference.byte_end, Some(range.1))
      assert_eq(reference.line_start, Some(index + 2))
      assert_eq(
        reference.extra.get("byte_normalization"),
        Some(
          if text.has_prefix("\u{FEFF}") {
            "leading_bom_removed"
          } else {
            "none"
          },
        ),
      )
      assert_eq(starts[index].source.byte_start, range.2)
      assert_eq(ends[index].source.byte_end, range.3)
      assert_eq(starts[index].source.line, index + 2)
      let expected = @utf8.encode(rows[index])
      assert_eq(
        original_bytes.exact_view(start=range.0, end=range.1).to_owned(),
        expected,
      )
      assert_eq(
        normalized_bytes.exact_view(start=range.2, end=range.3).to_owned(),
        expected,
      )
    }
  }
}

///|
test "JSON stream source counter refuses UTF8 Int32 overflow before advancing" {
  let parser = new_json_stream_parser("é", true, true)
  parser.byte_offset = 2147483646
  let rejected = try {
    ignore(parser.advance_char())
    false
  } catch {
    ParseError(message) =>
      message == "JSON source position exceeds Int32 UTF8 range"
    _ => false
  }
  assert_true(rejected)
  assert_eq(parser.byte_offset, 2147483646)
  assert_eq(parser.pos, 0)
}
