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

  let multi_doc = @yaml.classify_yaml_error(
    @yaml.YamlError::ParseError(
      "multi-document markers are unsupported at line 1",
    ),
  )
  assert_true(multi_doc.kind == @yaml.YamlErrorKind::MultiDocumentUnsupported)
}

///|
test "yaml parser accepts single-document start and end markers" {
  let leading = @yaml.parse_yaml_document("---\ntitle: Example\ncount: 1\n")
  match leading.root {
    Some(@yaml.YamlValue::Mapping(members)) => {
      assert_eq(members.length(), 2)
      assert_eq(members[0].key, "title")
      assert_eq(members[1].key, "count")
    }
    _ => fail("expected mapping root for leading marker case")
  }

  let leading_with_comment = @yaml.parse_yaml_document(
    "--- # document\ntitle: Example\n",
  )
  match leading_with_comment.root {
    Some(@yaml.YamlValue::Mapping(members)) =>
      assert_eq(members[0].key, "title")
    _ => fail("expected mapping root for commented leading marker case")
  }

  let trailing = @yaml.parse_yaml_document("title: Example\n...\n")
  match trailing.root {
    Some(@yaml.YamlValue::Mapping(members)) =>
      assert_eq(members[0].key, "title")
    _ => fail("expected mapping root for trailing marker case")
  }

  let trailing_with_comment = @yaml.parse_yaml_document(
    "title: Example\n...\n# end comment\n\n",
  )
  match trailing_with_comment.root {
    Some(@yaml.YamlValue::Mapping(members)) =>
      assert_eq(members[0].key, "title")
    _ => fail("expected mapping root for trailing marker with comment case")
  }

  let marker_only = @yaml.parse_yaml_document("---\n...\n")
  let marker_only_report = @yaml.inspect_yaml_document(marker_only)
  assert_true(marker_only_report.is_empty)
}

///|
test "yaml parser keeps multi-document stream markers unsupported" {
  assert_true(
    (try? @yaml.parse_yaml_document("---\na: 1\n---\nb: 2\n")) is Err(_),
  )
  assert_true((try? @yaml.parse_yaml_document("a: 1\n...\nb: 2\n")) is Err(_))
  assert_true((try? @yaml.parse_yaml_document("a: 1\n---\n")) is Err(_))
}

///|
test "yaml parser keeps marker-like scalars as scalar content" {
  let doc = @yaml.parse_yaml_document("a: \"---\"\nb: \"...\"\n")
  match doc.root {
    Some(@yaml.YamlValue::Mapping(members)) => {
      match members[0].value {
        @yaml.YamlValue::String(value) => assert_eq(value, "---")
        _ => fail("expected scalar string for a")
      }
      match members[1].value {
        @yaml.YamlValue::String(value) => assert_eq(value, "...")
        _ => fail("expected scalar string for b")
      }
    }
    _ => fail("expected mapping root for marker-like scalar case")
  }
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
