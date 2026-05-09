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
  assert_true((try? @json.parse_json_document("{\"a\":1,}")) is Err(_))

  let info = @json.classify_json_error(
    @json.JsonError::ParseError("unexpected character"),
  )
  assert_true(info.kind == @json.JsonErrorKind::UnexpectedCharacter)
}
