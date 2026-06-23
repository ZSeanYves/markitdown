///|
test "json parser handles object array and inspect depth" {
  let doc = @json.parse_json_document(
    "{\"name\":\"Ada\",\"items\":[1,true,null,{\"x\":2}]}",
  )
  let report = @json.inspect_json_document(doc)
  assert_eq(report.root_kind, "object")
  assert_eq(report.object_count, 2)
  assert_eq(report.array_count, 1)
  assert_eq(report.scalar_count, 5)
  assert_eq(report.member_count, 3)
  assert_eq(report.max_depth, 4)
}

///|
test "json parser handles escapes and unicode surrogate pairs" {
  let doc = @json.parse_json_document(
    "{\"text\":\"line\\nquote: \\\"hi\\\"\",\"emoji\":\"\\uD83D\\uDE00\"}",
  )
  match doc.root {
    @json.JsonValue::Object(members) => {
      assert_eq(members[0].key, "text")
      assert_eq(members[1].key, "emoji")
      match members[1].value {
        @json.JsonValue::String(s) => assert_eq(s, "😀")
        _ => fail("emoji field should stay string")
      }
    }
    _ => fail("expected object root")
  }
}

///|
test "json parser normalizes bom and crlf" {
  let doc = @json.parse_json_document("\u{FEFF}{\r\n\"a\":1\r\n}\r\n")
  let report = @json.inspect_json_document(doc)
  assert_eq(report.node_count, 2)
}

///|
test "json malformed input fails closed and classifies" {
  assert_true(
    (try @json.parse_json_document("{\"a\":1,}") |> Ok catch {
      e => Err(e)
    })
    is Err(_),
  )

  let info = @json.classify_json_error(
    @json.JsonError::ParseError("unexpected character"),
  )
  assert_true(info.kind == @json.JsonErrorKind::UnexpectedCharacter)
}

///|
test "json parser handles number formats and trailing content errors" {
  let doc = @json.parse_json_document(
    "{\"int\":0,\"neg\":-12,\"frac\":3.14,\"exp\":6.02e23}",
  )
  let report = @json.inspect_json_document(doc)
  assert_eq(report.member_count, 4)
  assert_true(
    (try @json.parse_json_document("{\"a\":1} trailing") |> Ok catch {
      e => Err(e)
    })
    is Err(_),
  )

  let info = @json.classify_json_error(
    @json.JsonError::ParseError("trailing content"),
  )
  assert_true(info.kind == @json.JsonErrorKind::TrailingContent)
}

///|
test "json classifier covers malformed string and unicode cases" {
  let bad_escape = @json.classify_json_error(
    @json.JsonError::ParseError("invalid escape"),
  )
  assert_true(bad_escape.kind == @json.JsonErrorKind::InvalidEscape)

  let bad_unicode = @json.classify_json_error(
    @json.JsonError::ParseError("invalid unicode escape"),
  )
  assert_true(bad_unicode.kind == @json.JsonErrorKind::InvalidUnicodeEscape)

  let bad_surrogate = @json.classify_json_error(
    @json.JsonError::ParseError("invalid unicode surrogate pair"),
  )
  assert_true(
    bad_surrogate.kind == @json.JsonErrorKind::InvalidUnicodeSurrogate,
  )
}

///|
test "json parser stays model-only and does not lower to conversion policy" {
  let doc = @json.parse_json_document("[{\"name\":\"Ada\"},{\"name\":\"Bob\"}]")
  match doc.root {
    @json.JsonValue::Array(values) => {
      assert_eq(values.length(), 2)
      match values[0] {
        @json.JsonValue::Object(members) => assert_eq(members[0].key, "name")
        _ => fail("expected object element")
      }
    }
    _ => fail("expected array root")
  }
}

///|
test "json profile keeps stage details" {
  let profiled = @json.profile_json_document("{\"a\":1}")
  assert_true(profiled.report.stages.length() > 0)
  let mut has_root_detail = false
  for stage in profiled.report.stages {
    match stage.detail {
      Some(detail) => if detail.contains("root=") { has_root_detail = true }
      None => ()
    }
  }
  assert_true(has_root_detail)
}

///|
test "json stream parser emits structural events with pointers and summary" {
  let streamed = @json.parse_json_stream(
    "{\"name\":\"Ada\",\"items\":[1,true,null,{\"x\":2}]}",
  )
  assert_true(streamed.events.length() > 0)
  assert_eq(streamed.summary.root_kind, "object")
  assert_eq(streamed.summary.object_count, 2)
  assert_eq(streamed.summary.array_count, 1)
  assert_eq(streamed.summary.scalar_count, 5)
  assert_eq(streamed.summary.max_depth, 4)
  assert_true(streamed.events[0].kind == @json.JsonStreamEventKind::ObjectStart)
  let key_event = streamed.events[1]
  assert_true(key_event.kind == @json.JsonStreamEventKind::Key)
  assert_eq(key_event.pointer, "/name")
  assert_eq(key_event.text.unwrap_or(""), "name")
}

///|
test "json stream parser normalizes bom and crlf source positions" {
  let streamed = @json.parse_json_stream("\u{FEFF}{\r\n\"a\":1\r\n}\r\n")
  assert_true(streamed.events.length() >= 3)
  let key_event = streamed.events[1]
  assert_true(key_event.source.line == 2)
  assert_true(key_event.source.column >= 1)
  assert_eq(key_event.pointer, "/a")
}
