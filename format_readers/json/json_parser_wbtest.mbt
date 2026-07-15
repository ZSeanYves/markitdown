///|
test "JSON parser classifies complete fail-closed taxonomy" {
  let cases : Array[(JsonError, JsonErrorKind)] = [
    (ParseError("trailing content"), TrailingContent),
    (ParseError("unexpected end of input"), UnexpectedEnd),
    (ParseError("unexpected character x"), UnexpectedCharacter),
    (ParseError("object key must be a string"), ObjectKeyMustBeString),
    (ParseError("unterminated string"), UnterminatedString),
    (ParseError("unterminated escape"), InvalidEscape),
    (ParseError("invalid unicode escape"), InvalidUnicodeEscape),
    (ParseError("invalid unicode surrogate pair"), InvalidUnicodeSurrogate),
    (ParseError("lone low surrogate"), InvalidUnicodeSurrogate),
    (ParseError("invalid fraction"), InvalidFraction),
    (ParseError("invalid exponent"), InvalidExponent),
    (ParseError("invalid leading zero"), InvalidNumber),
    (ParseError("raw newline in string"), RawNewlineInString),
    (ParseError("raw control character in string"), RawControlCharacterInString),
    (ParseError("expected character :"), ExpectedToken),
    (ParseError("other"), Unknown),
  ]
  for pair in cases {
    let (error, expected) = pair
    assert_true(classify_json_error(error).kind == expected)
  }
}

///|
test "JSON DOM and stream parsers reject symmetric malformed boundaries" {
  let malformed = [
    "", " ", "{", "[", "{1:2}", "{\"a\" 1}", "{\"a\":1,}", "[1,]", "[1 2]", "01",
    "-", "1.", "1e", "1e+", "\"unterminated", "\"bad\\", "\"\\u12xz\"", "\"\\uD800x\"",
    "\"\\uDC00\"", "true false",
  ]
  for text in malformed {
    let dom_failed = try {
      ignore(parse_json_document(text))
      false
    } catch {
      _ => true
    }
    let stream_failed = try {
      ignore(parse_json_stream(text))
      false
    } catch {
      _ => true
    }
    assert_true(dom_failed)
    assert_true(stream_failed)
  }
}

///|
test "JSON stream tracks escaped pointers scalars and source positions" {
  let stream = parse_json_stream(
    "\u{FEFF}{\r\n  \"a/b~c\": [null, true, false, -1.25e+2, \"x\\n\\t\\/y\"],\r\n  \"empty\": {}\r\n}",
  )
  assert_true(stream.summary.object_count >= 2)
  assert_eq(stream.summary.array_count, 1)
  assert_true(stream.summary.scalar_count >= 5)
  assert_true(stream.summary.max_depth >= 3)
  assert_true(stream.events.any(event => event.pointer.contains("a~1b~0c")))
  assert_true(
    stream.events.all(event => {
      event.source.line >= 1 && event.source.column >= 1
    }),
  )
  let profile = profile_json_document("{\"a\":[1,2,3]}")
  assert_true(profile.report.stages.length() >= 3)
}

///|
test "JSON summary stream validates and counts without retaining events" {
  let text = "[{\"a\":1,\"b\":[true,null]},{\"a\":2}]"
  let full = parse_json_stream(text)
  let summary = parse_json_stream_summary(text)
  assert_eq(summary.events.length(), 0)
  assert_eq(summary.summary.token_count, full.summary.token_count)
  assert_eq(summary.summary.object_count, full.summary.object_count)
  assert_eq(summary.summary.array_count, full.summary.array_count)
  assert_eq(summary.summary.scalar_count, full.summary.scalar_count)
  assert_eq(summary.summary.max_depth, full.summary.max_depth)
}

///|
test "native JSON bridge preserves nested escapes unicode and number text" {
  let text = "{\"text\":\"caf\\u00e9\\nline\",\"values\":[-12.50e+2,true,false,null,{\"x\":1}]}"
  let native = parse_json_document_native(text)
  let canonical = parse_json_document(text)
  let native_inspect = inspect_json_document(native)
  let canonical_inspect = inspect_json_document(canonical)
  assert_eq(native_inspect.node_count, canonical_inspect.node_count)
  assert_eq(native_inspect.object_count, canonical_inspect.object_count)
  assert_eq(native_inspect.array_count, canonical_inspect.array_count)
  match native.root {
    Object(members) => {
      let text_member = members.filter(item => item.key == "text")[0]
      match text_member.value {
        String(value) => assert_eq(value, "caf\u{00E9}\nline")
        _ => fail("expected native string")
      }
      let values = members.filter(item => item.key == "values")[0].value
      match values {
        Array(items) => {
          match items[0] {
            Number(value) => assert_eq(value, "-12.50e+2")
            _ => fail("expected native number")
          }
          assert_true(items[1] is Bool(true))
          assert_true(items[3] is Null)
        }
        _ => fail("expected native array")
      }
    }
    _ => fail("expected native object")
  }
}

///|
test "JSON preparation does not retain a DOM above the streaming limit" {
  let text = "[" + "{\"value\":1},".repeat(25_000) + "null]"
  let prepared = prepare_json_document_from_source(
    @input.input_from_text_with_format(text, "large.json", Some(Json)),
  ).unwrap()
  assert_true(prepared.stream is Some(_))
  assert_true(prepared.document is None)
  assert_true(prepared.inspect is None)
}
