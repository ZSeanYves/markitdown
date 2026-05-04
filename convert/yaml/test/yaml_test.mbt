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
fn read_utf8_text(path : String) -> String raise {
  let bytes = @fs.read_file_to_bytes(path) catch {
    e => fail("read sample failed: " + e.to_string())
  }
  @cor.utf8_bytes_to_string(bytes) catch {
    e => fail("utf8 decode failed: " + e.to_string())
  }
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
  ".tmp/yaml-test"
}

///|
fn yaml_test_root() -> String raise {
  ensure_dir_tree(test_tmp_root())
  let dir = test_tmp_root() + "/cases"
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
  ensure_dir_tree(path)
}

///|
fn cleanup_temp_dir(path : String) -> Unit {
  ignore(try? remove_dir_recursive(path))
}

///|
test "yaml mapping emits key-value table" {
  let input = resolve_sample_path(
    "samples/main_process/yaml/yaml_mapping_basic.yaml",
  )
  let expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/yaml/yaml_mapping_basic.md",
    ),
  )

  let doc = @yaml.parse_yaml(input, "", 6)
  assert_eq(@cor.emit_markdown(doc), expected)
  assert_eq(doc.blocks.val.length(), 1)
  match doc.blocks.val[0] {
    @cor.Block::RichTable(table) => assert_eq(table.header_rows, 1)
    _ => fail("yaml_mapping_basic should emit RichTable")
  }
}

///|
test "yaml scalar sequence emits bullet list" {
  let input = resolve_sample_path(
    "samples/main_process/yaml/yaml_sequence_scalars.yaml",
  )
  let expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/yaml/yaml_sequence_scalars.md",
    ),
  )

  let doc = @yaml.parse_yaml(input, "", 6)
  assert_eq(@cor.emit_markdown(doc), expected)
  assert_eq(doc.blocks.val.length(), 4)
}

///|
test "yaml object sequence and yml extension are supported" {
  let table_doc = @yaml.parse_yaml(
    resolve_sample_path(
      "samples/main_process/yaml/yaml_sequence_objects_table.yaml",
    ),
    "",
    6,
  )
  let table_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/yaml/yaml_sequence_objects_table.md",
    ),
  )
  assert_eq(@cor.emit_markdown(table_doc), table_expected)
  match table_doc.blocks.val[0] {
    @cor.Block::RichTable(table) => assert_eq(table.header_rows, 1)
    _ => fail("yaml_sequence_objects_table should emit RichTable")
  }

  let yml_doc = @yaml.parse_yaml(
    resolve_sample_path("samples/main_process/yaml/yml_extension_basic.yml"),
    "",
    6,
  )
  let yml_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/yaml/yml_extension_basic.md",
    ),
  )
  assert_eq(@cor.emit_markdown(yml_doc), yml_expected)
}

///|
test "yaml nested mapping and quoted strings stay deterministic" {
  let nested_doc = @yaml.parse_yaml(
    resolve_sample_path("samples/main_process/yaml/yaml_nested_mapping.yaml"),
    "",
    6,
  )
  let nested_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/yaml/yaml_nested_mapping.md",
    ),
  )
  assert_eq(@cor.emit_markdown(nested_doc), nested_expected)

  let quoted_doc = @yaml.parse_yaml(
    resolve_sample_path("samples/main_process/yaml/yaml_quoted_strings.yaml"),
    "",
    6,
  )
  let quoted_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/yaml/yaml_quoted_strings.md",
    ),
  )
  assert_eq(@cor.emit_markdown(quoted_doc), quoted_expected)
}

///|
test "yaml unsupported features fail closed" {
  let anchors_result = try? @yaml.parse_yaml(
    resolve_sample_path(
      "samples/main_process/yaml/yaml_anchors_aliases_current_behavior.key",
    ),
    "",
    6,
  )
  assert_true(anchors_result is Err(_))

  let document_result = try? @yaml.parse_yaml(
    resolve_sample_path("samples/main_process/yaml/yaml_document_separator.key"),
    "",
    6,
  )
  assert_true(document_result is Err(_))

  let multiline_result = try? @yaml.parse_yaml(
    resolve_sample_path("samples/main_process/yaml/yaml_multiline_scalar.key"),
    "",
    6,
  )
  assert_true(multiline_result is Err(_))

  let empty_mapping_result = try? @yaml.parse_yaml(
    resolve_sample_path("samples/main_process/yaml/yaml_empty_mapping.key"),
    "",
    6,
  )
  assert_true(empty_mapping_result is Err(_))

  let empty_sequence_result = try? @yaml.parse_yaml(
    resolve_sample_path("samples/main_process/yaml/yaml_empty_sequence.key"),
    "",
    6,
  )
  assert_true(empty_sequence_result is Err(_))
}

///|
test "yaml comments blank lines and quoted colons stay deterministic" {
  let comments_doc = @yaml.parse_yaml(
    resolve_sample_path("samples/main_process/yaml/yaml_comments.yaml"),
    "",
    6,
  )
  let comments_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/expected/yaml/yaml_comments.md"),
  )
  assert_eq(@cor.emit_markdown(comments_doc), comments_expected)

  let quoted_doc = @yaml.parse_yaml(
    resolve_sample_path("samples/main_process/yaml/yaml_quoted_strings.yaml"),
    "",
    6,
  )
  let quoted_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/yaml/yaml_quoted_strings.md",
    ),
  )
  assert_eq(@cor.emit_markdown(quoted_doc), quoted_expected)

  let empty_doc = @yaml.parse_yaml(
    resolve_sample_path("samples/main_process/yaml/yaml_empty.yaml"),
    "",
    6,
  )
  assert_eq(@cor.emit_markdown(empty_doc), "")
  assert_eq(empty_doc.blocks.val.length(), 0)
}

///|
test "yaml sequence of mappings supports reordered keys with stable header order" {
  let root = yaml_test_root()
  let out_dir = root + "/reordered-keys"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let path = out_dir + "/yaml_sequence_mappings_reordered.yaml"
  write_utf8_text(
    path, "- name: Alice\n  role: Engineer\n- role: Designer\n  name: Bob\n",
  )

  let doc = @yaml.parse_yaml(path, "", 6)
  assert_eq(
    @cor.emit_markdown(doc),
    "| name | role |\n| --- | --- |\n| Alice | Engineer |\n| Bob | Designer |\n",
  )
}

///|
test "yaml unsupported subset features fail closed from direct cases" {
  let root = yaml_test_root()
  let out_dir = root + "/unsupported"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let cases = [
    ("flow_mapping.yaml", "item: {a: 1}\n"),
    ("flow_sequence.yaml", "item: [1, 2]\n"),
    ("tag.yaml", "item: !Thing value\n"),
    ("folded_scalar.yaml", "item: >\n  folded\n"),
    ("bad_indent.yaml", "name: Alice\n role: Engineer\n"),
    ("comment_only.yaml", "# comment only\n# another\n"),
  ]

  for i in 0..<cases.length() {
    let entry = cases[i]
    let path = out_dir + "/" + entry.0
    write_utf8_text(path, entry.1)
    if entry.0 == "comment_only.yaml" {
      let doc = @yaml.parse_yaml(path, "", 6)
      assert_eq(doc.blocks.val.length(), 0)
    } else {
      assert_true((try? @yaml.parse_yaml(path, "", 6)) is Err(_))
    }
  }
}
