///|
test "yaml parser handles mapping sequence scalar and inspect counts" {
  let doc = @yaml.parse_yaml_document("name: Ada\nitems:\n  - one\n  - two\n")
  let report = @yaml.inspect_yaml_document(doc)
  assert_eq(report.is_empty, false)
  assert_eq(report.mapping_count, 1)
  assert_eq(report.sequence_count, 1)
  assert_eq(report.scalar_count, 3)
  assert_eq(report.max_depth, 3)
}

///|
test "yaml parser handles nested subset and quoted strings" {
  let doc = @yaml.parse_yaml_document(
    "root:\n  title: \"Ada\"\n  note: 'say ''hi'''\n",
  )
  match doc.root {
    Some(@yaml.YamlValue::Mapping(members)) => assert_eq(members[0].key, "root")
    _ => fail("expected mapping root")
  }
}

///|
test "yaml unsupported features fail closed and classify" {
  assert_true((try? @yaml.parse_yaml_document("note: |\n  long\n")) is Err(_))
  assert_true((try? @yaml.parse_yaml_document("a:\n\tb: 1\n")) is Err(_))

  let unsupported = @yaml.classify_yaml_error(
    @yaml.YamlError::ParseError("block scalars are unsupported at line 1"),
  )
  assert_true(unsupported.kind == @yaml.YamlErrorKind::UnsupportedFeature)

  let tabs = @yaml.classify_yaml_error(
    @yaml.YamlError::ParseError(
      "tabs are unsupported for indentation at line 2",
    ),
  )
  assert_true(tabs.kind == @yaml.YamlErrorKind::TabsUnsupported)
}
