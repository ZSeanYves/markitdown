///|
test "TOML parser classifies complete fail-closed taxonomy" {
  let cases : Array[(TomlError, TomlErrorKind)] = [
    (ParseError("unexpected end"), UnexpectedEnd),
    (ParseError("trailing content"), TrailingContent),
    (ParseError("duplicate key x"), DuplicateKey),
    (ParseError("invalid header"), InvalidHeader),
    (ParseError("invalid key"), InvalidKey),
    (ParseError("invalid escape"), InvalidEscape),
    (ParseError("unterminated string"), InvalidString),
    (ParseError("invalid value"), InvalidValue),
    (ParseError("expected character"), ExpectedToken),
    (ParseError("unsupported token"), UnsupportedFeature),
    (ParseError("other"), Unknown),
  ]
  for pair in cases {
    let (error, expected) = pair
    assert_true(classify_toml_error(error).kind == expected)
  }
}

///|
test "TOML parser rejects malformed collection string and table boundaries" {
  let malformed = [
    "= 1", "key", "key =", "key = 1 trailing", "key = [1,,2]", "key = [1, 2", "key = {a = 1,}",
    "key = {a = 1, a = 2}", "key = {a 1}", "key = \"unterminated", "key = \"bad\\q\"",
    "key = '''unterminated", "[]", "[[x]", "[x]]", "[x]\n[x]", "x = 1\nx = 2", "[x]\na = 1\na = 2",
    "key = 2024-99-99",
  ]
  for text in malformed {
    let failed = try {
      ignore(parse_toml_document(text))
      false
    } catch {
      _ => true
    }
    if !failed {
      fail("expected TOML parse failure: " + text)
    }
  }
}

///|
test "TOML parser accepts conservative scalar and table edge corpus" {
  let document = parse_toml_document(
    "\u{FEFF}bare = true\r\n" +
    "\"quoted.key\" = \"line\\n\\t\\\"quote\\\"\" # comment\r\n" +
    "literal = 'C:\\\\path'\n" +
    "multiline = \"\"\"first\\\n  continued\nthird\"\"\"\n" +
    "literal_multi = '''alpha\nbeta'''\n" +
    "ints = [+1, -2, 1, 3_000]\n" +
    "bare_tokens = [true, nan]\n" +
    "exponents = [1e2, -2e-3]\n" +
    "floats = [1.5, -2.5e+2]\n" +
    "when = 2024-01-02T03:04:05Z\n" +
    "inline = { name = \"x\", nested = { ok = false } }\n" +
    "[[products]]\nname = \"one\"\n" +
    "[[products]]\nname = \"two\"\n",
  )
  assert_true(document.root_members.length() >= 8)
  assert_eq(document.tables.length(), 2)
  assert_true(document.tables.all(table => table.is_array_item))
  assert_eq(toml_segments_to_path(["a", "b", "c"]), "/a/b/c")
  let indexed = toml_append_array_item_segment(["a"], 2)
  assert_true(indexed.length() == 1 && indexed[0] == "a[2]")
}

///|
test "TOML large homogeneous array suffix is strict and lossless" {
  let out = StringBuilder::new(size_hint=1_200_000)
  out.write_string("title = 'prefix'\n")
  let padding = "x".repeat(1000)
  for i in 0..<1024 {
    out.write_string("[[bench.items]]\n")
    out.write_string("name = \"case-")
    out.write_string(i.to_string())
    out.write_string("\"\nweight = ")
    out.write_string((i % 17).to_string())
    out.write_string("\nenabled = ")
    out.write_string(if i % 2 == 0 { "true" } else { "false" })
    out.write_string("\nnotes = \"")
    out.write_string(padding)
    out.write_string("\"\n")
  }
  let fast = prepare_fast_array_table_suffix(out.to_string()).unwrap()
  assert_eq(fast.0, "title = 'prefix'")
  assert_eq(fast.1.base_path, "/bench/items")
  assert_eq(fast.1.table_count, 1024)
  assert_eq(fast.1.keys.length(), 4)
  assert_eq(fast.1.keys[0], "name")
  assert_eq(fast.1.keys[1], "weight")
  assert_eq(fast.1.keys[2], "enabled")
  assert_eq(fast.1.keys[3], "notes")
  assert_eq(fast.1.rows[17][1], "0")
  assert_true(fast_scalar_cell("\"bad\\nvalue\"", 1) is None)
  assert_true(fast_array_header("[[a.b]]") == Some("a.b"))
  assert_true(fast_array_header("[a.b]") is None)
}
