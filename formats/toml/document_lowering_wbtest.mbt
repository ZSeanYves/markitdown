///|
test "TOML parser and lowering cover rich tables arrays and scalar kinds" {
  let text =
    #|title = "TOML Contract"
    #|unicode = "snowman \u2603"
    #|literal = 'C:\Users\contract'
    #|multiline = """first line
    #|second line"""
    #|literal_multiline = '''alpha
    #|beta'''
    #|enabled = true
    #|count = 42
    #|ratio = 1.25e2
    #|created = 2026-07-10T12:30:45Z
    #|local_date = 2026-07-10
    #|ports = [8000, 8001, 8002]
    #|points = [{x = 1, y = 2}, {x = 3, y = 4}]
    #|mixed = [1, "two", false]
    #|
    #|[owner]
    #|name = "Ada"
    #|contact = { email = "ada@example.test", active = true }
    #|
    #|[database.settings]
    #|pool = 8
    #|
    #|[[products]]
    #|name = "alpha"
    #|price = 10.5
    #|
    #|[[products]]
    #|name = "beta"
    #|price = 20.0
  let source = @input.input_from_text_with_format(
    text,
    "complex.toml",
    Some(Toml),
  )
  let result = (toml_parser().parse)(source, @parser.new_parse_context(Toml)).unwrap()
  let document = result.document.unwrap()
  assert_true(document.blocks.length() >= 7)
  assert_true(document.blocks.any(block => block.kind == Heading))
  assert_true(document.blocks.any(block => block.kind == Table))
  assert_true(result.diagnostics.metrics.get("table_count") != Some("0"))
  assert_true(result.diagnostics.metrics.get("array_count") != Some("0"))
  let prepared = @dtoml.prepare_toml_document_from_source(source).unwrap()
  let reused = toml_parse_with_prepared_document(
    prepared.prepared_source,
    @parser.new_parse_context(Toml),
    prepared,
  )
  assert_true(
    reused.document.unwrap().blocks.length() == document.blocks.length(),
  )
  assert_true(
    reused.diagnostics.metrics.get("probe_artifact_reused") == Some("true"),
  )
}

///|
test "TOML malformed structures fail closed with classified diagnostics" {
  for
    text in [
      "key = \"unterminated", "key = \"bad \\u12xz\"", "key = [1, 2", "key = { a = 1",
      "[table\nkey = 1",
    ] {
    match
      (toml_parser().parse)(
        @input.input_from_text_with_format(text, "broken.toml", Some(Toml)),
        @parser.new_parse_context(Toml),
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
test "TOML lowering covers empty and heterogeneous table product shapes" {
  for text in ["", "[empty]\n", "items = []\n"] {
    let result = (toml_parser().parse)(
      @input.input_from_text_with_format(text, "edge.toml", Some(Toml)),
      @parser.new_parse_context(Toml),
    ).unwrap()
    assert_true(result.document.unwrap().blocks.length() >= 1)
  }
  let heterogeneous =
    #|[[products]]
    #|name = "alpha"
    #|price = 10
    #|
    #|[[products]]
    #|name = "beta"
    #|description = "different keys"
  let result = (toml_parser().parse)(
    @input.input_from_text_with_format(
      heterogeneous,
      "heterogeneous.toml",
      Some(Toml),
    ),
    @parser.new_parse_context(Toml),
  ).unwrap()
  let blocks = result.document.unwrap().blocks
  assert_true(blocks.any(block => block.text == "Item 1"))
  assert_true(blocks.any(block => block.text == "Item 2"))
  assert_true(blocks.all(block => block.source_ref is Some(_)))
}
