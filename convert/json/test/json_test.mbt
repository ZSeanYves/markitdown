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
