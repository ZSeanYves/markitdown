///|
test "JSON parser lowers complex document and streaming structure routes" {
  let json = "{\"title\":\"Report\",\"rows\":[{\"name\":\"alpha\",\"value\":1},{\"name\":\"beta\",\"value\":2}],\"nested\":{\"enabled\":true,\"none\":null}}"
  let source = @input.input_from_text_with_format(
    json,
    "complex.json",
    Some(@input.DetectedFormat::Json),
  )
  let document = (json_parser().parse)(
    source,
    @parser.new_parse_context(@input.DetectedFormat::Json),
  ).unwrap()
  assert_true(document.document.unwrap().blocks.length() > 0)
  assert_true(document.diagnostics.metrics.get("json_valid") == Some("true"))
  assert_true(document.diagnostics.metrics.get("root_kind") == Some("object"))
  let stream_context = @parser.parse_context_with_limits(
    @parser.new_parse_context(@input.DetectedFormat::Json),
    Some(@parser.ParserMode::StreamingEvent),
    None,
    None,
    None,
    None,
    false,
  )
  let streamed = (json_parser().parse)(source, stream_context).unwrap()
  assert_true(streamed.event_stream.unwrap().length() > 0)
  assert_true(
    streamed.diagnostics.metrics.get("effective_mode") ==
    Some("streaming_event"),
  )
  assert_true(streamed.diagnostics.metrics.get("object_count") != Some("0"))
}

///|
test "JSON malformed document produces explicit raw fallback diagnostics" {
  let source = @input.input_from_text_with_format(
    "{\"broken\": [1,}",
    "broken.json",
    Some(@input.DetectedFormat::Json),
  )
  let result = (json_parser().parse)(
    source,
    @parser.new_parse_context(@input.DetectedFormat::Json),
  ).unwrap()
  assert_true(result.document.unwrap().blocks.length() == 1)
  assert_true(result.diagnostics.warnings.length() == 1)
  assert_true(
    result.diagnostics.degraded_features.contains("json_raw_fenced_fallback"),
  )
  assert_true(result.diagnostics.metrics.get("json_valid") == Some("false"))
  assert_true(result.diagnostics.metrics.get("syntax_error_count") == Some("1"))
}

///|
test "JSONL parser emits valid records and fails closed on a malformed line" {
  let text = "{\"id\":1}\n\n[1,2,3]\n{\"id\":2,\"text\":\"ok\"}"
  let source = @input.input_from_text_with_format(
    text,
    "records.jsonl",
    Some(@input.DetectedFormat::Jsonl),
  )
  let result = (jsonl_parser().parse)(
    source,
    @parser.new_parse_context(@input.DetectedFormat::Jsonl),
  ).unwrap()
  assert_true(result.event_stream.unwrap().length() > 0)
  assert_true(result.diagnostics.metrics.get("record_count") == Some("3"))
  assert_true(
    result.diagnostics.metrics.get("invalid_record_count") == Some("0"),
  )
  assert_true(result.diagnostics.warnings.length() == 1)
  assert_true(
    result.diagnostics.degraded_features.contains("jsonl_blank_line_skipped"),
  )
  let broken_source = @input.input_from_text_with_format(
    "{\"id\":1}\ninvalid",
    "broken.jsonl",
    Some(@input.DetectedFormat::Jsonl),
  )
  let fallback = (jsonl_parser().parse)(
    broken_source,
    @parser.new_parse_context(@input.DetectedFormat::Jsonl),
  ).unwrap()
  assert_true(fallback.document is Some(_))
  assert_true(fallback.diagnostics.warnings.length() == 1)
  assert_true(
    fallback.diagnostics.degraded_features.contains("jsonl_raw_fenced_fallback"),
  )
}

///|
test "NDJSON parser handles empty input and capability distinctions" {
  let source = @input.input_from_text_with_format(
    "",
    "empty.ndjson",
    Some(@input.DetectedFormat::Ndjson),
  )
  let result = (ndjson_parser().parse)(
    source,
    @parser.new_parse_context(@input.DetectedFormat::Ndjson),
  ).unwrap()
  assert_eq(result.event_stream.unwrap().length(), 0)
  assert_true(result.diagnostics.metrics.get("record_count") == Some("0"))
  assert_true(json_parser_capability().supports_document_ir)
  assert_true(jsonl_parser_capability().supports_streaming)
  assert_true(ndjson_parser_capability().supports_streaming)
}

///|
test "JSON lowering covers every root and array product shape" {
  let cases = [
    ("\"text root\"", @core.BlockKind::Paragraph),
    ("42", @core.BlockKind::Paragraph),
    ("true", @core.BlockKind::Paragraph),
    ("false", @core.BlockKind::Paragraph),
    ("null", @core.BlockKind::Paragraph),
    ("[]", @core.BlockKind::Code),
    ("[1,\"two\",false,null]", @core.BlockKind::List),
    ("[{\"a\":1,\"b\":2},{\"a\":3,\"b\":4}]", @core.BlockKind::Table),
    ("[{\"a\":1},[2,3]]", @core.BlockKind::Code),
  ]
  for indexed in 0..<cases.length() {
    let (text, expected_kind) = cases[indexed]
    let result = (json_parser().parse)(
      @input.input_from_text_with_format(
        text,
        "root-" + indexed.to_string() + ".json",
        Some(@input.DetectedFormat::Json),
      ),
      @parser.new_parse_context(@input.DetectedFormat::Json),
    ).unwrap()
    let blocks = result.document.unwrap().blocks
    assert_true(blocks.length() >= 1)
    assert_true(blocks[0].kind == expected_kind)
  }
}

///|
test "JSON streaming and line-delimited lowering cover heterogeneous bounded records" {
  let stream_context = @parser.parse_context_with_limits(
    @parser.new_parse_context(@input.DetectedFormat::Json),
    Some(@parser.ParserMode::StreamingEvent),
    None,
    None,
    None,
    None,
    false,
  )
  for
    text in ["{}", "[]", "[1,{\"nested\":[true,null]}]", "\"scalar\"", "false"] {
    let result = (json_parser().parse)(
      @input.input_from_text_with_format(
        text,
        "stream.json",
        Some(@input.DetectedFormat::Json),
      ),
      stream_context,
    ).unwrap()
    assert_true(result.event_stream.unwrap().length() > 0)
  }
  let limited = @parser.parse_context_with_limits(
    @parser.new_parse_context(@input.DetectedFormat::Jsonl),
    None,
    Some(3),
    None,
    None,
    None,
    false,
  )
  let text = "\u{001E}\u{FEFF}{\"a\":1,\"b\":2}\n\n" +
    "{\"a\":3,\"b\":4}\n" +
    "{\"b\":5,\"a\":6}\n" +
    "[7,8]\n" +
    "{\"a\":9,\"b\":10}\n"
  let result = (jsonl_parser().parse)(
    @input.input_from_text_with_format(
      text,
      "bounded.jsonl",
      Some(@input.DetectedFormat::Jsonl),
    ),
    limited,
  ).unwrap()
  assert_true(result.event_stream.unwrap().length() > 0)
  assert_true(result.diagnostics.metrics.get("record_count") == Some("3"))
  assert_true(result.diagnostics.metrics.get("blank_line_count") == Some("1"))
}

///|
test "JSON compact root array events preserve previews pointers and ranges" {
  let text = "[{\"id\":1,\"tags\":[\"a\",\"b\"],\"nested\":{\"ok\":true}},{\"id\":2}]"
  let source = @input.input_from_text_with_format(
    text,
    "compact.json",
    Some(@input.DetectedFormat::Json),
  )
  let stream = @djson.parse_json_stream(text)
  let events = json_compact_root_array_events_from_stream(stream, source)
  assert_eq(events.length(), 2)
  assert_true(events[0].text.contains("3 keys"))
  assert_true(events[0].text.contains("tags: [ 2 items: a, b ]"))
  let first_ref = events[0].source_ref.unwrap()
  assert_true(first_ref.json_pointer == Some("/0"))
  assert_true(first_ref.byte_start == Some(1))
  assert_true(first_ref.byte_end is Some(_))
  assert_true(first_ref.extra.get("ir_event_encoding") == Some("json_list_v1"))
}

///|
test "JSON direct root array lowering matches compact event semantics" {
  let text = "[\n{\"id\":1,\"tags\":[\"a\",\"b\"],\"nested\":{\"ok\":true}},\n{\"id\":2}]"
  let source = @input.input_from_text_with_format(
    text,
    "compact-direct.json",
    Some(@input.DetectedFormat::Json),
  )
  let retained = json_compact_root_array_events_from_stream(
    @djson.parse_json_stream(text),
    source,
  )
  let direct = json_compact_root_array_events_direct(text, source).unwrap()
  assert_eq(direct.length(), retained.length())
  for i in 0..<direct.length() {
    assert_eq(direct[i].text, retained[i].text)
    assert_true(
      direct[i].source_ref.unwrap().json_pointer ==
      retained[i].source_ref.unwrap().json_pointer,
    )
  }
  assert_true(direct[0].source_ref.unwrap().line_start == Some(2))
  assert_true(direct[1].source_ref.unwrap().line_start == Some(3))
}
