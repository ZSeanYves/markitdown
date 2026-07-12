///|
fn yaml_test_parse(text : String) -> @parser.ParseResult {
  let source = @input.input_from_text_with_format(
    text,
    "contract.yaml",
    Some(@input.DetectedFormat::Yaml),
  )
  (yaml_parser().parse)(
    source,
    @parser.new_parse_context(@input.DetectedFormat::Yaml),
  ).unwrap()
}

///|
test "YAML lowering covers scalar sequence table mapping and fallback shapes" {
  let cases = [
    "[]", "- alpha\n- 2\n- true\n- null", "- name: alpha\n  value: 1\n- name: beta\n  value: 2",
    "- name: alpha\n  value: 1\n- value: 2\n  extra: beta", "service:\n  name: api\n  ports:\n    - 80\n    - 443\nenabled: true",
    "plain scalar", "42", "false", "null",
  ]
  let results = cases.map(yaml_test_parse)
  assert_true(
    results.all(result => result.document.unwrap().blocks.length() == 1),
  )
  assert_true(
    results.any(result => {
      result.document.unwrap().blocks[0].kind == @core.BlockKind::List
    }),
  )
  assert_true(
    results.any(result => {
      result.document.unwrap().blocks[0].kind == @core.BlockKind::Table
    }),
  )
  assert_true(
    results.any(result => {
      result.document.unwrap().blocks[0].kind == @core.BlockKind::Code
    }),
  )
  assert_true(
    results.any(result => {
      result.document.unwrap().blocks[0].kind == @core.BlockKind::Paragraph
    }),
  )
}

///|
test "YAML prepared structure events reproduce canonical document lowering" {
  let text = "items:\n  - name: alpha\n    tags: [one, two]\n  - name: beta\n    tags: [three]\nmeta: {ready: true, count: 2}"
  let source = @input.input_from_text_with_format(
    text,
    "events.yaml",
    Some(@input.DetectedFormat::Yaml),
  )
  let prepared = @dyaml.prepare_yaml_document_from_source(source).unwrap()
  let stream_context = @parser.parse_context_with_limits(
    @parser.new_parse_context(@input.DetectedFormat::Yaml),
    Some(@parser.ParserMode::StreamingEvent),
    None,
    None,
    None,
    None,
    false,
  )
  let result = yaml_parse_with_prepared_document(
    prepared.prepared_source,
    stream_context,
    prepared,
  )
  assert_true(result.event_stream.unwrap().length() > 1)
  assert_true(
    result.diagnostics.metrics.get("probe_artifact_reused") == Some("true"),
  )
  assert_true(result.diagnostics.metrics.get("mapping_count") != Some("0"))
}

///|
test "YAML malformed and unsupported documents fail closed with diagnostics" {
  for text in ["key:\n\tbad: tab", "key: \"unterminated"] {
    match
      (yaml_parser().parse)(
        @input.input_from_text_with_format(
          text,
          "broken.yaml",
          Some(@input.DetectedFormat::Yaml),
        ),
        @parser.new_parse_context(@input.DetectedFormat::Yaml),
      ) {
      Ok(result) =>
        assert_true(
          result.diagnostics.errors.length() > 0 ||
          result.diagnostics.degraded_features.length() > 0,
        )
      Err(message) => assert_true(message != "")
    }
  }
}

///|
test "YAML unknown directives preserve the complete source in raw fallback" {
  let text = "%FOO  bar baz # Should be retained\n---\n\"foo\"\n"
  let result = yaml_test_parse(text)
  let document = result.document.unwrap()
  assert_eq(document.blocks.length(), 1)
  assert_true(document.blocks[0].kind == @core.BlockKind::Raw)
  assert_eq(document.blocks[0].text, text)
  assert_true(result.diagnostics.degraded_features.contains("yaml_fail_closed"))
}

///|
test "YAML multi-document streams lower without whole-document fallback" {
  let result = (yaml_parser().parse)(
    @input.input_from_text_with_format(
      "---\na: 1\n---\nb: 2\n",
      "stream.yaml",
      Some(@input.DetectedFormat::Yaml),
    ),
    @parser.new_parse_context(@input.DetectedFormat::Yaml),
  ).unwrap()
  assert_true(result.document is Some(_))
  assert_true(result.diagnostics.errors.length() == 0)
  assert_true(result.document.unwrap().blocks.length() > 0)
}

///|
test "YAML lowering helpers preserve quoting block and pointer contracts" {
  let complex = @dyaml.parse_yaml_document(
    "'needs space': ['true', \"line\\nbreak\", 1.5, false, null]\n" +
    "nested: {quote: \"a\\\"b\\\\c\\t\"}",
  ).root.unwrap()
  let inline = yaml_stringify_inline(complex)
  let block = yaml_stringify_block(complex, 0)
  assert_true(inline.contains("\"needs space\""))
  assert_true(inline.contains("\"true\""))
  assert_true(block.contains("nested:"))
  assert_true(block.contains("  quote:"))
  for text in ["", "true", "false", "null", "~", "- item", "1.5", "a b", "a:b"] {
    assert_true(yaml_needs_quotes(text))
  }
  assert_true(!yaml_needs_quotes("plain"))
  assert_true(yaml_scalar_text_looks_numeric("+1.5"))
  assert_true(!yaml_scalar_text_looks_numeric("+"))
  assert_true(!yaml_scalar_text_looks_numeric("1..2"))
  assert_eq(yaml_join_index("/items", 2), "/items[2]")
  let empty = lower_yaml_document(
    @dyaml.parse_yaml_document(""),
    @input.input_from_text_with_format(
      "",
      "empty.yaml",
      Some(@input.DetectedFormat::Yaml),
    ),
  )
  assert_eq(empty.blocks.length(), 0)
}

///|
test "YAML streaming lowering covers root and nested event shapes" {
  let context = @parser.parse_context_with_limits(
    @parser.new_parse_context(@input.DetectedFormat::Yaml),
    Some(@parser.ParserMode::StreamingEvent),
    None,
    None,
    None,
    None,
    false,
  )
  for
    text in [
      "plain", "false", "null", "[]", "[1, two, true]", "a: 1\nb: false", "- one\n- nested:\n    value: 2",
    ] {
    let result = (yaml_parser().parse)(
      @input.input_from_text_with_format(
        text,
        "stream.yaml",
        Some(@input.DetectedFormat::Yaml),
      ),
      context,
    ).unwrap()
    assert_true(result.event_stream.unwrap().length() > 0)
  }
}
