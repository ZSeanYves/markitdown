///|
/// Represent members as ordered pairs so comparison cannot hide duplicate keys
/// or coerce number lexemes through floating-point JSON values.
fn prepared_json_contract_value(value : JsonValue) -> Json {
  match value {
    Object(members) =>
      Json::array([
        Json("object"),
        Json::array(
          members.map(entry => {
            Json::array([
              Json(entry.key),
              prepared_json_contract_value(entry.value),
            ])
          }),
        ),
      ])
    Array(items) =>
      Json::array([
        Json("array"),
        Json::array(items.map(prepared_json_contract_value)),
      ])
    String(text) => Json::array([Json("string"), Json(text)])
    Number(text) => Json::array([Json("number"), Json(text)])
    Bool(value) => Json::array([Json("bool"), Json(value)])
    Null => Json::array([Json("null")])
  }
}

///|
async test "prepared JSON document preserves source model lexemes and ordered duplicate keys" {
  for
    text in [
      "null", "true", "false", "[]", "{}", "-0", "1.2300e+004", "9e999999", "\"&amp;\\u0026lt;\\n\\t\\/\\\\\\\"😀\"",
      "{\"\":0,\"\":1,\"dup\":-0,\"dup\":1.200e+03,\"a/b~\":[9e-2,true,false,null,{},[]]}",
      "{\"\\u0061\":\"\\uD83D\\uDE00\",\"a\":\"\\\\u0041\",\"nested\":{\"\":\"<&😀\"}}",
      "\u{FEFF}{\r\n \"x\": [\"一😀\", 12.50e-2]\r\n}",
    ] {
    let prepared = prepare_json_document_from_source(
      @input.input_from_text(text, source_name="contract.json"),
    ).unwrap()
    guard prepared.document is Some(actual) && prepared.stream is Some(stream) else {
      fail("valid prepared JSON must contain both projections")
    }
    let expected = parse_json_document(prepared.original_text)
    assert_eq(
      prepared_json_contract_value(actual.root),
      prepared_json_contract_value(expected.root),
    )
    let original_stream = parse_json_stream(prepared.original_text)
    assert_eq(stream.events.length(), original_stream.events.length())
    for index, event in stream.events {
      let old = original_stream.events[index]
      assert_true(event.kind == old.kind)
      assert_eq(event.pointer, old.pointer)
      assert_eq(event.depth, old.depth)
      assert_eq(event.text, old.text)
      assert_eq(
        (
          event.source.line,
          event.source.column,
          event.source.byte_start,
          event.source.byte_end,
        ),
        (
          old.source.line,
          old.source.column,
          old.source.byte_start,
          old.source.byte_end,
        ),
      )
    }
    let observed = inspect_json_document(actual)
    let old = inspect_json_document(expected)
    assert_eq(
      (
        observed.node_count,
        observed.object_count,
        observed.array_count,
        observed.scalar_count,
        observed.member_count,
        observed.max_depth,
        observed.root_kind,
      ),
      (
        old.node_count,
        old.object_count,
        old.array_count,
        old.scalar_count,
        old.member_count,
        old.max_depth,
        old.root_kind,
      ),
    )
    assert_eq(prepared.parse_error, None)
  }
}

///|
async test "prepared JSON retains exact DOM threshold and first lexical errors" {
  let body = "{\"n\":1.200e+03}"
  for size in [255999, 256000, 256001] {
    let prepared = prepare_json_document_from_source(
      @input.input_from_text(" ".repeat(size - body.length()) + body),
    ).unwrap()
    assert_eq(prepared.original_text.length(), size)
    assert_eq(prepared.document is Some(_), size <= 256000)
    assert_eq(prepared.inspect is Some(_), size <= 256000)
    assert_true(prepared.stream is Some(_))
    assert_eq(
      prepared.parse_error,
      if size <= 256000 {
        None
      } else {
        Some("json DOM preparation skipped above the streaming limit")
      },
    )
  }
  for
    text in [
      "", "{", "[1,]", "01", "-", "1.", "1e+", "true false", "\"\\uD800x\"", "\"\\uDC00\"",
      "\"raw\nline\"", "{\"a\":1,}",
    ] {
    let prepared = prepare_json_document_from_source(
      @input.input_from_text(text),
    ).unwrap()
    let error = try {
      ignore(parse_json_stream(prepared.original_text))
      None
    } catch {
      error => Some(error.to_string())
    }
    assert_true(error is Some(_))
    assert_eq(prepared.parse_error, error)
    assert_true(
      prepared.document is None &&
      prepared.inspect is None &&
      prepared.stream is None,
    )
  }
}

///|
async test "prepared JSON tree owns container arrays independently of lexical events" {
  let prepared = prepare_json_document_from_source(
    @input.input_from_text("{\"a\":[1,2],\"a\":3}"),
  ).unwrap()
  let document = prepared.document.unwrap()
  let stream = prepared.stream.unwrap()
  let value = prepared_json_contract_value(document.root)
  stream.events.clear()
  assert_eq(prepared_json_contract_value(document.root), value)
  assert_true(document.root is Object(members) && members.length() == 2)
}
