///|
test "YAML parser classifies complete fail-closed taxonomy" {
  let cases : Array[(YamlError, YamlErrorKind)] = [
    (ParseError("unexpected end of input"), UnexpectedEnd),
    (ParseError("unexpected indentation at line 2"), UnexpectedIndentation),
    (ParseError("unexpected trailing content at line 2"), TrailingContent),
    (ParseError("empty key at line 1"), EmptyKey),
    (ParseError("expected mapping entry at line 2"), ExpectedMappingEntry),
    (ParseError("expected sequence item at line 2"), ExpectedSequenceItem),
    (
      ParseError("unterminated double-quoted string at line 1"),
      UnterminatedQuotedScalar,
    ),
    (ParseError("invalid escape at line 1"), InvalidEscape),
    (ParseError("tabs are unsupported"), TabsUnsupported),
    (
      ParseError("multi-document markers are unsupported"),
      MultiDocumentUnsupported,
    ),
    (ParseError("anchors are unsupported"), UnsupportedFeature),
    (ParseError("other failure"), Unknown),
  ]
  for pair in cases {
    let (error, expected) = pair
    assert_true(classify_yaml_error(error).kind == expected)
  }
}

///|
test "YAML structure and scalar boundary branches stay deterministic" {
  assert_eq(parse_yaml_structure_document("").events.length(), 0)
  assert_eq(parse_yaml_structure_events("---\n...\n").length(), 0)
  for
    text in [
      "scalar\n  nested", "[one]\n  nested", "key: value\n  invalid: child", "- one\n  - invalid",
      ": empty", "? complex: value", "key: |x\n  value", "key: value\n...\nother: value",
      "  ---", "key:\tvalue", "[one,,two]", "{one: 1,}", "[one}",
    ] {
    let failed = try {
      ignore(parse_yaml_document(text))
      false
    } catch {
      _ => true
    }
    assert_true(failed, msg="expected YAML failure: " + text)
  }
  let parsed = parse_yaml_document(
    "\u{FEFF}quoted: \"a # b\\nline\" # comment\r\n" +
    "single: 'it''s # data'\r" +
    "literal: |+\n  first\n  \n  third\n" +
    "folded: >2-\n  alpha\n  beta\n" +
    "numbers: [+1, -2, 3.5, 6e2, .5, 1.]\n" +
    "nested: {items: [\"a,b\", 'c:d'], flag: true}\n" +
    "empty_item:\n-\n",
  )
  assert_true(parsed.root is Some(_))
  let profile = profile_yaml_document("a: 1\nb:\n  - 2\n  - 3\n")
  assert_true(profile.report.stages.length() >= 3)
}

///|
test "YAML private scalar helpers cover numeric quote and flow edges" {
  for value in ["0", "+1", "-1", "1.0", ".5", "1."] {
    assert_true(yaml_is_number_scalar(value))
  }
  for value in ["", "+", "-", ".", "1..2", "e2", "1e", "1e2", "-2E-3", "1-2"] {
    assert_true(!yaml_is_number_scalar(value))
  }
  assert_eq(
    parse_double_quoted_scalar("\"a\\\"b\\\\c\\n\\r\\t\"", 1),
    "a\"b\\c\n\r\t",
  )
  assert_eq(parse_single_quoted_scalar("'it''s'", 1), "it's")
  let bad_double = try {
    ignore(parse_double_quoted_scalar("\"bad\\\"", 1))
    false
  } catch {
    _ => true
  }
  let bad_single = try {
    ignore(parse_single_quoted_scalar("'bad", 1))
    false
  } catch {
    _ => true
  }
  assert_true(bad_double)
  assert_true(bad_single)
  assert_eq(split_flow_items("'a,b', {x: [1, 2]}, \"c,d\"", 1).length(), 3)
  let bad_items = try {
    ignore(split_flow_items("a,,b", 1))
    false
  } catch {
    _ => true
  }
  let bad_mapping = try {
    ignore(find_flow_mapping_colon("{broken]", 1))
    false
  } catch {
    _ => true
  }
  assert_true(bad_items)
  assert_true(bad_mapping)
}

///|
test "YAML directives fail closed before document splitting" {
  let text = "%FOO  bar baz # retained\n---\n\"foo\"\n"
  inspect(
    try {
      ignore(parse_yaml_document(text))
      "parsed"
    } catch {
      ParseError(message) => message
      _ => "unexpected error"
    },
    content="YAML directives are unsupported at line 1",
  )
}
