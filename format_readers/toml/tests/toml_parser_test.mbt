///|
test "toml parser handles dotted keys tables arrays and inspect depth" {
  let doc = @toml.parse_toml_document(
    "title = \"Example\"\n" +
    "site.owner = \"Ada\"\n" +
    "numbers = [1, 2, 3]\n" +
    "[database]\n" +
    "server = \"db.local\"\n",
  )
  let report = @toml.inspect_toml_document(doc)
  assert_eq(report.root_kind, "document")
  assert_eq(report.table_count, 2)
  assert_true(report.scalar_count >= 3)
  assert_true(report.array_count >= 1)
  assert_true(report.max_depth >= 2)
  assert_true(doc.tables[0].path == "/site")
  assert_true(
    doc.tables[0].members.map(fn(item) { item.path }).contains("/site/owner"),
  )
}

///|
test "toml parser handles array of tables and multiline strings" {
  let doc = @toml.parse_toml_document(
    "bio = \"\"\"\nhello\nworld\n\"\"\"\n" +
    "[[products]]\nname = \"Hammer\"\nsku = 1\n" +
    "[[products]]\nname = \"Nail\"\nsku = 2\n",
  )
  let report = @toml.inspect_toml_document(doc)
  assert_eq(report.table_count, 2)
  assert_true(report.table_like_count >= 2)
  assert_true(report.scalar_count >= 5)
  match doc.root_members[0].value {
    @toml.TomlValue::String(value) => assert_eq(value, "hello\nworld\n")
    _ => fail("expected multiline string")
  }
  assert_true(doc.tables[0].is_array_item)
}

///|
test "toml parser handles inline tables bom crlf and comments" {
  let doc = @toml.parse_toml_document(
    "\u{FEFF}title = \"Example\"\r\n" +
    "point = { x = 1, y = 2 }\r\n" +
    "# keep comment ignored\r\n",
  )
  let report = @toml.inspect_toml_document(doc)
  assert_eq(report.node_count, 8)
  match doc.root_members[1].value {
    @toml.TomlValue::InlineTable(entries) => {
      assert_eq(entries.length(), 2)
      assert_eq(entries[0].key, "x")
    }
    _ => fail("expected inline table")
  }
}

///|
test "toml parser rejects inline table duplicate keys" {
  assert_true(
    (try @toml.parse_toml_document("a = { b = 1, b = 2 }\n") |> Ok catch {
      e => Err(e)
    })
    is Err(_),
  )
}

///|
test "toml parser accepts multiline continuation with whitespace before newline" {
  let doc = @toml.parse_toml_document(
    "value = \"\"\"\\\n" + "  hello \\   \n" + "  world\\\t\n" + "\"\"\"\n",
  )
  match doc.root_members[0].value {
    @toml.TomlValue::String(value) => assert_eq(value, "hello world")
    _ => fail("expected multiline string")
  }
}

///|
test "toml parser rejects invalid datetime token" {
  assert_true(
    (try @toml.parse_toml_document("foo = 1997-09-0909:09:09\n") |> Ok catch {
      e => Err(e)
    })
    is Err(_),
  )
}

///|
test "toml malformed input fails closed and classifies" {
  assert_true(
    (try @toml.parse_toml_document("title = [1, 2") |> Ok catch {
      e => Err(e)
    })
    is Err(_),
  )
  let info = @toml.classify_toml_error(
    @toml.TomlError::ParseError("expected closing ]"),
  )
  assert_true(info.kind == @toml.TomlErrorKind::ExpectedToken)
}
