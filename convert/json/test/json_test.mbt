///|
fn resolve_sample_path(path : String) -> String raise {
  if @fs.path_exists(path) {
    return path
  }

  let fallback = "../../../" + path
  if @fs.path_exists(fallback) {
    return fallback
  }

  fail("sample file not found: " + path)
}

///|
fn write_utf8_text(path : String, text : String) -> Unit raise {
  @fs.write_string_to_file(path, text, encoding="utf8") catch {
    e => fail("write sample failed: " + e.to_string())
  }
}

///|
fn ensure_dir(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    @fs.create_dir(path)
  }
}

///|
fn ensure_dir_tree(path : String) -> Unit raise {
  let trimmed = path.trim()
  if trimmed == "" {
    return
  }

  let chars = trimmed.to_array()
  let mut current = if chars.length() > 0 && chars[0] == '/' { "/" } else { "" }
  let part : Array[Char] = []

  fn flush(part : Array[Char], current : String) -> String raise {
    if part.length() == 0 {
      return current
    }

    let segment = String::from_array(part)
    part.clear()
    let next = if current == "" || current == "/" {
      current + segment
    } else {
      current + "/" + segment
    }
    ensure_dir(next)
    next
  }

  for ch in chars {
    if ch == '/' {
      current = flush(part, current)
    } else {
      part.push(ch)
    }
  }

  ignore(flush(part, current))
}

///|
fn test_tmp_root() -> String {
  ".tmp"
}

///|
fn ensure_test_tmp_root() -> Unit raise {
  ensure_dir_tree(test_tmp_root())
}

///|
fn json_test_root() -> String raise {
  ensure_test_tmp_root()
  let dir = test_tmp_root() + "/json-test"
  ensure_dir(dir)
  dir
}

///|
fn remove_dir_recursive(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    return
  }

  for name in @fs.read_dir(path) {
    let child = path + "/" + name
    if @fs.is_dir(child) {
      remove_dir_recursive(child)
    } else if @fs.is_file(child) {
      @fs.remove_file(child)
    }
  }

  @fs.remove_dir(path)
}

///|
fn recreate_clean_dir(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    remove_dir_recursive(path)
  }
  @fs.create_dir(path)
}

///|
fn cleanup_temp_dir(path : String) -> Unit {
  ignore(try? remove_dir_recursive(path))
}

///|
fn read_utf8_text(path : String) -> String raise {
  let bytes = @fs.read_file_to_bytes(path) catch {
    e => fail("read sample failed: " + e.to_string())
  }
  @cor.utf8_bytes_to_string(bytes) catch {
    e => fail("utf8 decode failed: " + e.to_string())
  }
}

///|
test "json object table uses explicit header semantics" {
  let doc = @json.parse_json(
    resolve_sample_path("samples/main_process/json/json_object_basic.json"),
    "",
    6,
  )

  match doc.blocks.val[0] {
    @cor.Block::RichTable(table) => {
      assert_eq(table.header_rows, 1)
      assert_eq(table.rows[0], ["Key", "Value"])
    }
    _ => fail("json_object_basic should emit RichTable")
  }
}

///|
test "json array of objects table uses explicit header semantics" {
  let doc = @json.parse_json(
    resolve_sample_path(
      "samples/main_process/json/json_array_objects_table.json",
    ),
    "",
    6,
  )

  match doc.blocks.val[0] {
    @cor.Block::RichTable(table) => {
      assert_eq(table.header_rows, 1)
      assert_true(table.rows.length() > 1)
    }
    _ => fail("json_array_objects_table should emit RichTable")
  }
}

///|
test "json nested and mixed fallbacks stay deterministic" {
  let nested_doc = @json.parse_json(
    resolve_sample_path("samples/main_process/json/json_nested_object.json"),
    "",
    6,
  )
  let nested_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/json/json_nested_object.md",
    ),
  )
  assert_eq(@cor.emit_markdown(nested_doc), nested_expected)

  let mixed_doc = @json.parse_json(
    resolve_sample_path("samples/main_process/json/json_mixed_array.json"),
    "",
    6,
  )
  let mixed_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/json/json_mixed_array.md",
    ),
  )
  assert_eq(@cor.emit_markdown(mixed_doc), mixed_expected)
}

///|
test "json handles escapes, empty values, and bom/crlf normalization" {
  let escapes_doc = @json.parse_json(
    resolve_sample_path("samples/main_process/json/json_string_escapes.json"),
    "",
    6,
  )
  let escapes_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/json/json_string_escapes.md",
    ),
  )
  assert_eq(@cor.emit_markdown(escapes_doc), escapes_expected)

  let empty_array_doc = @json.parse_json(
    resolve_sample_path("samples/main_process/json/json_empty_array.json"),
    "",
    6,
  )
  let empty_array_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/json/json_empty_array.md",
    ),
  )
  assert_eq(@cor.emit_markdown(empty_array_doc), empty_array_expected)

  let bom_doc = @json.parse_json(
    resolve_sample_path("samples/main_process/json/json_bom_utf8.json"),
    "",
    6,
  )
  let bom_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/expected/json/json_bom_utf8.md"),
  )
  assert_eq(@cor.emit_markdown(bom_doc), bom_expected)

  let crlf_doc = @json.parse_json(
    resolve_sample_path("samples/main_process/json/json_crlf.json"),
    "",
    6,
  )
  let crlf_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/expected/json/json_crlf.md"),
  )
  assert_eq(@cor.emit_markdown(crlf_doc), crlf_expected)
}

///|
test "json malformed input fails closed" {
  let root = json_test_root()
  let out_dir = root + "/malformed"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let malformed = out_dir + "/json_malformed.json"
  write_utf8_text(malformed, "{\"a\":1,}\n")
  let result = try? @json.parse_json(malformed, "", 6)
  assert_true(result is Err(_))
}

///|
test "json decodes unicode escapes and surrogate pairs" {
  let unicode_doc = @json.parse_json(
    resolve_sample_path("samples/main_process/json/json_unicode_escape.json"),
    "",
    6,
  )
  let unicode_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/json/json_unicode_escape.md",
    ),
  )
  assert_eq(@cor.emit_markdown(unicode_doc), unicode_expected)

  let root = json_test_root()
  let out_dir = root + "/unicode"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let surrogate_path = out_dir + "/surrogate.json"
  write_utf8_text(surrogate_path, "{\"emoji\":\"\\ud83d\\ude00\"}\n")
  let surrogate_doc = @json.parse_json(surrogate_path, "", 6)
  assert_eq(
    @cor.emit_markdown(surrogate_doc),
    "| Key | Value |\n| --- | --- |\n| emoji | 😀 |\n",
  )
}

///|
test "json number grammar stays strict and complete" {
  let root = json_test_root()
  let out_dir = root + "/numbers"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let valid_path = out_dir + "/valid.json"
  write_utf8_text(
    valid_path, "{\"i\":0,\"neg\":-1,\"dec\":3.14,\"frac\":-0.5,\"exp\":1e10,\"negexp\":-2.5E-3}\n",
  )
  let valid_doc = @json.parse_json(valid_path, "", 6)
  assert_eq(
    @cor.emit_markdown(valid_doc),
    "| Key | Value |\n| --- | --- |\n| i | 0 |\n| neg | -1 |\n| dec | 3.14 |\n| frac | -0.5 |\n| exp | 1e10 |\n| negexp | -2.5E-3 |\n",
  )

  let invalid_cases = [
    ("leading_zero.json", "{\"n\":01}\n"),
    ("trailing_dot.json", "{\"n\":1.}\n"),
    ("leading_dot.json", "{\"n\":.5}\n"),
    ("bad_exp.json", "{\"n\":1e}\n"),
    ("nan.json", "{\"n\":NaN}\n"),
    ("infinity.json", "{\"n\":Infinity}\n"),
  ]

  for i in 0..<invalid_cases.length() {
    let entry = invalid_cases[i]
    let path = out_dir + "/" + entry.0
    write_utf8_text(path, entry.1)
    assert_true((try? @json.parse_json(path, "", 6)) is Err(_))
  }
}

///|
test "json array lowering keeps stable RichTable and conservative fallback" {
  let table_doc = @json.parse_json(
    resolve_sample_path(
      "samples/main_process/json/json_array_objects_table.json",
    ),
    "",
    6,
  )
  match table_doc.blocks.val[0] {
    @cor.Block::RichTable(table) => {
      assert_eq(table.header_rows, 1)
      assert_eq(table.rows[0], ["name", "role"])
    }
    _ => fail("uniform object array should emit RichTable")
  }

  let root = json_test_root()
  let out_dir = root + "/arrays"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let reorder_path = out_dir + "/reordered.json"
  write_utf8_text(
    reorder_path, "[{\"name\":\"Alice\",\"role\":\"Engineer\"},{\"role\":\"Designer\",\"name\":\"Bob\"}]\n",
  )
  let reorder_doc = @json.parse_json(reorder_path, "", 6)
  assert_eq(
    @cor.emit_markdown(reorder_doc),
    "| name | role |\n| --- | --- |\n| Alice | Engineer |\n| Bob | Designer |\n",
  )

  let nested_path = out_dir + "/nested_values.json"
  write_utf8_text(
    nested_path, "[{\"name\":\"Alice\",\"meta\":{\"team\":\"Search\"}},{\"name\":\"Bob\",\"meta\":{\"team\":\"Infra\"}}]\n",
  )
  let nested_doc = @json.parse_json(nested_path, "", 6)
  assert_eq(
    @cor.emit_markdown(nested_doc),
    "| name | meta |\n| --- | --- |\n| Alice | {\"team\":\"Search\"} |\n| Bob | {\"team\":\"Infra\"} |\n",
  )
}

///|
test "json invalid escapes and control characters fail closed" {
  let root = json_test_root()
  let out_dir = root + "/invalid-strings"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let invalid_cases = [
    ("bad_unicode.json", "{\"text\":\"\\uZZZZ\"}\n"),
    ("lone_high.json", "{\"text\":\"\\ud83d\"}\n"),
    ("lone_low.json", "{\"text\":\"\\ude00\"}\n"),
    ("bad_control.json", "{\"text\":\"" + "\u{0001}" + "\"}\n"),
    ("trailing_comma.json", "[1,2,]\n"),
    ("unclosed_string.json", "{\"text\":\"abc}\n"),
  ]

  for i in 0..<invalid_cases.length() {
    let entry = invalid_cases[i]
    let path = out_dir + "/" + entry.0
    write_utf8_text(path, entry.1)
    assert_true((try? @json.parse_json(path, "", 6)) is Err(_))
  }
}
