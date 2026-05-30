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

  let leading_and_trailing_start = @yaml.parse_yaml_document(
    "---\ntitle: Example\n---\n",
  )
  match leading_and_trailing_start.root {
    Some(@yaml.YamlValue::Mapping(members)) =>
      assert_eq(members[0].key, "title")
    _ => fail("expected mapping root for leading + trailing start marker case")
  }

  let leading_and_trailing_start_with_comment = @yaml.parse_yaml_document(
    "---\ntitle: Example\n---\n# end comment\n",
  )
  match leading_and_trailing_start_with_comment.root {
    Some(@yaml.YamlValue::Mapping(members)) =>
      assert_eq(members[0].key, "title")
    _ =>
      fail(
        "expected mapping root for leading + trailing start marker comment case",
      )
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

  let trailing_start_marker = @yaml.parse_yaml_document("title: Example\n---\n")
  match trailing_start_marker.root {
    Some(@yaml.YamlValue::Mapping(members)) =>
      assert_eq(members[0].key, "title")
    _ => fail("expected mapping root for trailing start marker case")
  }

  let trailing_start_marker_with_comment = @yaml.parse_yaml_document(
    "title: Example\n---\n# end comment\n",
  )
  match trailing_start_marker_with_comment.root {
    Some(@yaml.YamlValue::Mapping(members)) =>
      assert_eq(members[0].key, "title")
    _ =>
      fail("expected mapping root for trailing start marker with comment case")
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
  assert_true((try? @yaml.parse_yaml_document("a: 1\n---\nb: 2\n")) is Err(_))
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

///|
test "yaml parser handles mapping child sequence followed by sibling keys" {
  let doc = @yaml.parse_yaml_document(
    "references:\n" +
    "- author:\n" +
    "  - family: Doe\n" +
    "    given: John\n" +
    "  id: item1\n",
  )
  let report = @yaml.inspect_yaml_document(doc)
  assert_eq(report.mapping_count, 3)
  assert_eq(report.sequence_count, 2)
  assert_eq(report.scalar_count, 3)
}

///|
test "yaml parser handles conservative flow sequence" {
  let doc = @yaml.parse_yaml_document("[one, two, true, null]")
  match doc.root {
    Some(@yaml.YamlValue::Sequence(values)) => {
      assert_eq(values.length(), 4)
      match values[2] {
        @yaml.YamlValue::Bool(value) => assert_true(value)
        _ => fail("expected bool flow item")
      }
      match values[3] {
        @yaml.YamlValue::Null => ()
        _ => fail("expected null flow item")
      }
    }
    _ => fail("expected flow sequence root")
  }
}

///|
test "yaml parser handles flow values in mappings" {
  let sequence_doc = @yaml.parse_yaml_document("items: [one, two]\n")
  match sequence_doc.root {
    Some(@yaml.YamlValue::Mapping(members)) =>
      match members[0].value {
        @yaml.YamlValue::Sequence(values) => assert_eq(values.length(), 2)
        _ => fail("expected flow sequence value")
      }
    _ => fail("expected mapping root")
  }

  let object_doc = @yaml.parse_yaml_document(
    "person: {name: Ada, active: true}\n",
  )
  match object_doc.root {
    Some(@yaml.YamlValue::Mapping(members)) =>
      match members[0].value {
        @yaml.YamlValue::Mapping(person) => {
          assert_eq(person[0].key, "name")
          match person[1].value {
            @yaml.YamlValue::Bool(value) => assert_true(value)
            _ => fail("expected bool flow mapping value")
          }
        }
        _ => fail("expected flow mapping value")
      }
    _ => fail("expected mapping root")
  }
}

///|
test "yaml parser handles nested and quoted flow values" {
  let nested = @yaml.parse_yaml_document(
    "root: {items: [one, {two: three}]}\n",
  )
  let nested_report = @yaml.inspect_yaml_document(nested)
  assert_eq(nested_report.mapping_count, 3)
  assert_eq(nested_report.sequence_count, 1)
  assert_eq(nested_report.scalar_count, 2)

  let quoted = @yaml.parse_yaml_document("text: [\"a,b\", \"x:y\"]\n")
  match quoted.root {
    Some(@yaml.YamlValue::Mapping(members)) =>
      match members[0].value {
        @yaml.YamlValue::Sequence(values) => {
          match values[0] {
            @yaml.YamlValue::String(value) => assert_eq(value, "a,b")
            _ => fail("expected quoted comma string")
          }
          match values[1] {
            @yaml.YamlValue::String(value) => assert_eq(value, "x:y")
            _ => fail("expected quoted colon string")
          }
        }
        _ => fail("expected quoted flow sequence")
      }
    _ => fail("expected mapping root")
  }
}

///|
test "yaml parser handles empty flow collections" {
  let doc = @yaml.parse_yaml_document("empty_list: []\nempty_map: {}\n")
  match doc.root {
    Some(@yaml.YamlValue::Mapping(members)) => {
      match members[0].value {
        @yaml.YamlValue::Sequence(values) => assert_eq(values.length(), 0)
        _ => fail("expected empty flow sequence")
      }
      match members[1].value {
        @yaml.YamlValue::Mapping(values) => assert_eq(values.length(), 0)
        _ => fail("expected empty flow mapping")
      }
    }
    _ => fail("expected mapping root")
  }
}

///|
test "yaml parser rejects malformed flow collections" {
  assert_true((try? @yaml.parse_yaml_document("[one, two")) is Err(_))
  assert_true((try? @yaml.parse_yaml_document("{name Ada}")) is Err(_))
  assert_true((try? @yaml.parse_yaml_document("{name: Ada,}")) is Err(_))
}

///|
test "yaml profile keeps stage details" {
  let profiled = @yaml.profile_yaml_document("name: Ada\n")
  assert_true(profiled.report.stages.length() > 0)
  let mut has_root_detail = false
  for stage in profiled.report.stages {
    match stage.detail {
      Some(detail) =>
        if detail.contains("root=") {
          has_root_detail = true
        }
      None => ()
    }
  }
  assert_true(has_root_detail)
}
