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
    Some(Mapping(members)) => assert_eq(members[0].key, "root")
    _ => fail("expected mapping root")
  }
}

///|
test "yaml unsupported features fail closed and classify" {
  assert_true(
    (try @yaml.parse_yaml_document("a:\n\tb: 1\n") |> Ok catch {
      e => Err(e)
    })
    is Err(_),
  )

  let unsupported = @yaml.classify_yaml_error(
    ParseError("anchors, aliases, and tags are unsupported at line 1"),
  )
  assert_true(unsupported.kind == UnsupportedFeature)

  let tabs = @yaml.classify_yaml_error(
    ParseError("tabs are unsupported for indentation at line 2"),
  )
  assert_true(tabs.kind == TabsUnsupported)

  let multi_doc = @yaml.classify_yaml_error(
    ParseError("multi-document markers are unsupported at line 1"),
  )
  assert_true(multi_doc.kind == MultiDocumentUnsupported)
}

///|
test "yaml parser accepts single-document start and end markers" {
  let leading = @yaml.parse_yaml_document("---\ntitle: Example\ncount: 1\n")
  match leading.root {
    Some(Mapping(members)) => {
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
    Some(Mapping(members)) => assert_eq(members[0].key, "title")
    _ => fail("expected mapping root for commented leading marker case")
  }

  let leading_and_trailing_start = @yaml.parse_yaml_document(
    "---\ntitle: Example\n---\n",
  )
  match leading_and_trailing_start.root {
    Some(Mapping(members)) => assert_eq(members[0].key, "title")
    _ => fail("expected mapping root for leading + trailing start marker case")
  }

  let leading_and_trailing_start_with_comment = @yaml.parse_yaml_document(
    "---\ntitle: Example\n---\n# end comment\n",
  )
  match leading_and_trailing_start_with_comment.root {
    Some(Mapping(members)) => assert_eq(members[0].key, "title")
    _ =>
      fail(
        "expected mapping root for leading + trailing start marker comment case",
      )
  }

  let trailing = @yaml.parse_yaml_document("title: Example\n...\n")
  match trailing.root {
    Some(Mapping(members)) => assert_eq(members[0].key, "title")
    _ => fail("expected mapping root for trailing marker case")
  }

  let trailing_with_comment = @yaml.parse_yaml_document(
    "title: Example\n...\n# end comment\n\n",
  )
  match trailing_with_comment.root {
    Some(Mapping(members)) => assert_eq(members[0].key, "title")
    _ => fail("expected mapping root for trailing marker with comment case")
  }

  let trailing_start_marker = @yaml.parse_yaml_document("title: Example\n---\n")
  match trailing_start_marker.root {
    Some(Mapping(members)) => assert_eq(members[0].key, "title")
    _ => fail("expected mapping root for trailing start marker case")
  }

  let trailing_start_marker_with_comment = @yaml.parse_yaml_document(
    "title: Example\n---\n# end comment\n",
  )
  match trailing_start_marker_with_comment.root {
    Some(Mapping(members)) => assert_eq(members[0].key, "title")
    _ =>
      fail("expected mapping root for trailing start marker with comment case")
  }

  let marker_only = @yaml.parse_yaml_document("---\n...\n")
  let marker_only_report = @yaml.inspect_yaml_document(marker_only)
  assert_true(marker_only_report.is_empty)
}

///|
test "yaml parser represents multi-document streams as a root sequence" {
  let stream = @yaml.parse_yaml_document("---\na: 1\n---\nb: 2\n")
  match stream.root {
    Some(Sequence(documents)) => {
      assert_eq(documents.length(), 2)
      match documents[0] {
        Mapping(members) => assert_eq(members[0].key, "a")
        _ => fail("expected first mapping document")
      }
      match documents[1] {
        Mapping(members) => assert_eq(members[0].key, "b")
        _ => fail("expected second mapping document")
      }
    }
    _ => fail("expected multi-document root sequence")
  }
  assert_true(
    (try @yaml.parse_yaml_document("a: 1\n...\nb: 2\n") |> Ok catch {
      e => Err(e)
    })
    is Err(_),
  )
  let implicit_first = @yaml.parse_yaml_document("a: 1\n---\nb: 2\n")
  match implicit_first.root {
    Some(Sequence(documents)) => assert_eq(documents.length(), 2)
    _ => fail("expected implicit first document plus explicit second document")
  }
}

///|
test "yaml parser keeps marker-like scalars as scalar content" {
  let doc = @yaml.parse_yaml_document("a: \"---\"\nb: \"...\"\n")
  match doc.root {
    Some(Mapping(members)) => {
      match members[0].value {
        String(value) => assert_eq(value, "---")
        _ => fail("expected scalar string for a")
      }
      match members[1].value {
        String(value) => assert_eq(value, "...")
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
    Some(Sequence(values)) => {
      assert_eq(values.length(), 4)
      match values[2] {
        Bool(value) => assert_true(value)
        _ => fail("expected bool flow item")
      }
      match values[3] {
        Null => ()
        _ => fail("expected null flow item")
      }
    }
    _ => fail("expected flow sequence root")
  }
}

///|
test "yaml parser preserves numbers as first-class scalars" {
  let doc = @yaml.parse_yaml_document("count: 42\nratio: 3.14\nneg: -7\n")
  match doc.root {
    Some(Mapping(members)) => {
      match members[0].value {
        Number(value) => assert_eq(value, "42")
        _ => fail("expected number for count")
      }
      match members[1].value {
        Number(value) => assert_eq(value, "3.14")
        _ => fail("expected number for ratio")
      }
      match members[2].value {
        Number(value) => assert_eq(value, "-7")
        _ => fail("expected number for neg")
      }
    }
    _ => fail("expected mapping root")
  }
}

///|
test "yaml parser handles literal and folded block scalars" {
  let literal = @yaml.parse_yaml_document("note: |\n  line one\n  line two\n")
  match literal.root {
    Some(Mapping(members)) =>
      match members[0].value {
        String(value) => assert_eq(value, "line one\nline two\n")
        _ => fail("expected literal block scalar string")
      }
    _ => fail("expected mapping root for literal block scalar")
  }

  let folded = @yaml.parse_yaml_document(
    "note: >\n  line one\n  line two\n  tail\n",
  )
  match folded.root {
    Some(Mapping(members)) =>
      match members[0].value {
        String(value) => assert_eq(value, "line one line two tail\n")
        _ => fail("expected folded block scalar string")
      }
    _ => fail("expected mapping root for folded block scalar")
  }
}

///|
test "yaml block scalar chomping and explicit indentation follow YAML semantics" {
  let parsed = @yaml.parse_yaml_document(
    "clip: |\n  one\n\nstrip: |-\n  two\n\nkeep: |+\n  three\n  \n  \nfolded: >2-\n  alpha\n  beta\n",
  )
  match parsed.root {
    Some(Mapping(entries)) => {
      match entries[0].value {
        String(value) => assert_eq(value, "one\n")
        _ => fail("expected clipped literal scalar")
      }
      match entries[1].value {
        String(value) => assert_eq(value, "two")
        _ => fail("expected stripped literal scalar")
      }
      match entries[2].value {
        String(value) => assert_eq(value, "three\n\n\n")
        _ => fail("expected kept literal scalar")
      }
      match entries[3].value {
        String(value) => assert_eq(value, "alpha beta")
        _ => fail("expected stripped folded scalar")
      }
    }
    _ => fail("expected mapping root for block scalar chomping")
  }
}

///|
test "yaml parser supports safe core scalar tags and rejects custom tags" {
  let document = @yaml.parse_yaml_document(
    "text: !!str 001\nquoted: !!str \"true\"\ncount: !!int -12\nratio: !!float 3.5\nactive: !!bool true\nempty: !!null ~\n",
  )
  match document.root {
    Some(Mapping(members)) => {
      assert_eq(members.length(), 6)
      match members[0].value {
        String(value) => assert_eq(value, "001")
        _ => fail("!!str must not implicitly coerce")
      }
      match members[1].value {
        String(value) => assert_eq(value, "true")
        _ => fail("quoted !!str must stay text")
      }
      match members[2].value {
        Number(value) => assert_eq(value, "-12")
        _ => fail("expected tagged integer")
      }
      assert_true(members[4].value is Bool(true))
      assert_true(members[5].value is Null)
    }
    _ => fail("expected safe-tag mapping")
  }
  assert_true(
    (try @yaml.parse_yaml_document("value: !unsafe payload\n") |> Ok catch {
      _ => Err(())
    })
    is Err(_),
  )
  assert_true(
    (try @yaml.parse_yaml_document("value: !!int 1.5\n") |> Ok catch {
      _ => Err(())
    })
    is Err(_),
  )
}

///|
test "yaml parser resolves anchors aliases and merge keys with explicit override" {
  let document = @yaml.parse_yaml_document(
    "defaults: &defaults\n" +
    "  adapter: postgres\n" +
    "  host: localhost\n" +
    "development:\n" +
    "  <<: *defaults\n" +
    "  host: dev.example\n" +
    "copy: *defaults\n",
  )
  match document.root {
    Some(Mapping(root)) => {
      assert_eq(root.length(), 3)
      match root[1].value {
        Mapping(values) => {
          assert_eq(values.length(), 2)
          assert_eq(values[0].key, "adapter")
          assert_eq(values[1].key, "host")
          match values[1].value {
            String(value) => assert_eq(value, "dev.example")
            _ => fail("expected explicit merge override")
          }
        }
        _ => fail("expected merged development mapping")
      }
      match root[2].value {
        Mapping(values) => assert_eq(values.length(), 2)
        _ => fail("expected mapping alias copy")
      }
    }
    _ => fail("expected anchored root mapping")
  }
}

///|
test "yaml parser resolves inline sequence anchors and merge precedence" {
  let document = @yaml.parse_yaml_document(
    "first: &first {a: 1, shared: first}\n" +
    "second: &second {b: 2, shared: second}\n" +
    "combined:\n" +
    "  <<: [*first, *second]\n" +
    "items:\n" +
    "  - &item\n" +
    "    name: alpha\n" +
    "alias: *item\n",
  )
  match document.root {
    Some(Mapping(root)) => {
      match root[2].value {
        Mapping(values) => {
          assert_eq(values.length(), 3)
          assert_eq(values[0].key, "a")
          assert_eq(values[1].key, "shared")
          assert_eq(values[2].key, "b")
          match values[1].value {
            String(value) => assert_eq(value, "first")
            _ => fail("first merge mapping must take precedence")
          }
        }
        _ => fail("expected merge-sequence mapping")
      }
      assert_true(root[4].value is Mapping(_))
    }
    _ => fail("expected root mapping")
  }
}

///|
test "yaml aliases reject undefined forward duplicate and invalid references" {
  for
    text in [
      "value: *missing\n", "copy: *later\nlater: &later value\n", "one: &same 1\ntwo: &same 2\n",
      "value: *bad/name\n", "value:\n  <<: scalar\n",
    ] {
    assert_true(
      (try @yaml.parse_yaml_document(text) |> Ok catch {
        _ => Err(())
      })
      is Err(_),
      msg="expected controlled YAML alias failure: " + text,
    )
  }
}

///|
test "yaml parser handles flow values in mappings" {
  let sequence_doc = @yaml.parse_yaml_document("items: [one, two]\n")
  match sequence_doc.root {
    Some(Mapping(members)) =>
      match members[0].value {
        Sequence(values) => assert_eq(values.length(), 2)
        _ => fail("expected flow sequence value")
      }
    _ => fail("expected mapping root")
  }

  let object_doc = @yaml.parse_yaml_document(
    "person: {name: Ada, active: true}\n",
  )
  match object_doc.root {
    Some(Mapping(members)) =>
      match members[0].value {
        Mapping(person) => {
          assert_eq(person[0].key, "name")
          match person[1].value {
            Bool(value) => assert_true(value)
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
  let nested = @yaml.parse_yaml_document("root: {items: [one, {two: three}]}\n")
  let nested_report = @yaml.inspect_yaml_document(nested)
  assert_eq(nested_report.mapping_count, 3)
  assert_eq(nested_report.sequence_count, 1)
  assert_eq(nested_report.scalar_count, 2)

  let quoted = @yaml.parse_yaml_document("text: [\"a,b\", \"x:y\"]\n")
  match quoted.root {
    Some(Mapping(members)) =>
      match members[0].value {
        Sequence(values) => {
          match values[0] {
            String(value) => assert_eq(value, "a,b")
            _ => fail("expected quoted comma string")
          }
          match values[1] {
            String(value) => assert_eq(value, "x:y")
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
    Some(Mapping(members)) => {
      match members[0].value {
        Sequence(values) => assert_eq(values.length(), 0)
        _ => fail("expected empty flow sequence")
      }
      match members[1].value {
        Mapping(values) => assert_eq(values.length(), 0)
        _ => fail("expected empty flow mapping")
      }
    }
    _ => fail("expected mapping root")
  }
}

///|
test "yaml parser rejects malformed flow collections" {
  assert_true(
    (try @yaml.parse_yaml_document("[one, two") |> Ok catch {
      e => Err(e)
    })
    is Err(_),
  )
  assert_true(
    (try @yaml.parse_yaml_document("{name Ada}") |> Ok catch {
      e => Err(e)
    })
    is Err(_),
  )
  assert_true(
    (try @yaml.parse_yaml_document("{name: Ada,}") |> Ok catch {
      e => Err(e)
    })
    is Err(_),
  )
}

///|
test "yaml profile keeps stage details" {
  let profiled = @yaml.profile_yaml_document("name: Ada\n")
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
