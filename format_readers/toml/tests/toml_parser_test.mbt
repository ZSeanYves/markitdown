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
    String(value) => assert_eq(value, "hello\nworld\n")
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
    InlineTable(entries) => {
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
    String(value) => assert_eq(value, "hello world")
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
test "toml parser validates 1.0 numeric forms datetime bounds and special floats" {
  let document = @toml.parse_toml_document(
    "decimal = 1_000\nhex = 0xDEAD_BEEF\noctal = 0o755\nbinary = 0b1010_0110\nfloat = -1_234.5_6e+7\npos_inf = +inf\nquiet_nan = nan\nleap = 2024-02-29T23:59:59.123Z\nlocal_time = 07:32:00\n",
  )
  assert_eq(document.root_members.length(), 9)
  match document.root_members[0].value {
    Integer(value) => assert_eq(value, "1_000")
    _ => fail("expected decimal integer")
  }
  match document.root_members[4].value {
    Float(value) => assert_eq(value, "-1_234.5_6e+7")
    _ => fail("expected exponent float")
  }
  match document.root_members[7].value {
    Datetime(value) => assert_eq(value, "2024-02-29T23:59:59.123Z")
    _ => fail("expected offset datetime")
  }
  for
    invalid in [
      "value = 01\n", "value = 0xZZ\n", "value = 0o8\n", "value = 0b102\n", "value = 1__2\n",
      "value = 1._0\n", "value = 1e_2\n", "value = 2023-02-29\n", "value = 2024-04-31\n",
    ] {
    assert_true(
      (try @toml.parse_toml_document(invalid) |> Ok catch {
        _ => Err(())
      })
      is Err(_),
    )
  }
}

///|
test "toml malformed input fails closed and classifies" {
  assert_true(
    (try @toml.parse_toml_document("title = [1, 2") |> Ok catch {
      e => Err(e)
    })
    is Err(_),
  )
  let info = @toml.classify_toml_error(ParseError("expected closing ]"))
  assert_true(info.kind == ExpectedToken)
}
