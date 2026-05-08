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
  assert_true((try? @yaml.parse_yaml_document("---\na: 1\n")) is Err(_))

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

  let multi_doc = @yaml.classify_yaml_error(
    @yaml.YamlError::ParseError(
      "multi-document markers are unsupported at line 1",
    ),
  )
  assert_true(multi_doc.kind == @yaml.YamlErrorKind::MultiDocumentUnsupported)
}

///|
test "yaml parser handles empty documents and nested sequences deterministically" {
  let empty = @yaml.parse_yaml_document("\n# only comment\n")
  let empty_report = @yaml.inspect_yaml_document(empty)
  assert_true(empty_report.is_empty)
  assert_eq(empty_report.node_count, 0)

  let nested = @yaml.parse_yaml_document(
    "items:\n  - name: Ada\n    city: Paris\n",
  )
  let nested_report = @yaml.inspect_yaml_document(nested)
  assert_eq(nested_report.mapping_count, 2)
  assert_eq(nested_report.sequence_count, 1)
  assert_eq(nested_report.scalar_count, 2)
}
