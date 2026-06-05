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
  @utf8.decode(bytes, ignore_bom=false) catch {
    _ => fail("utf8 decode failed")
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
fn restore_env_var(name : String, previous : String?) -> Unit {
  match previous {
    Some(value) => @sys.set_env_var(name, value)
    None => @sys.unset_env_var(name)
  }
}

///|
test "yaml mapping emits key-value table" {
  let input = resolve_sample_path(
    "samples/main_process/yaml/yaml_mapping_basic.yaml",
  )
  let expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/yaml/expected/yaml_mapping_basic.md",
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
test "yaml profile disabled returns no report" {
  let prev_enabled = @sys.get_env_var("MARKITDOWN_PROFILE_YAML")
  defer restore_env_var("MARKITDOWN_PROFILE_YAML", prev_enabled)
  @sys.unset_env_var("MARKITDOWN_PROFILE_YAML")

  let (doc, profile) = @yaml.parse_yaml_with_profile(
    resolve_sample_path("samples/main_process/yaml/yaml_mapping_basic.yaml"),
    "",
    6,
  )
  assert_true(@cor.emit_markdown(doc).contains("| Key | Value |"))
  match profile {
    None => ()
    Some(_) => fail("disabled yaml profile should not create a report")
  }
}

///|
test "yaml profile enabled preserves stage details" {
  let prev_enabled = @sys.get_env_var("MARKITDOWN_PROFILE_YAML")
  defer restore_env_var("MARKITDOWN_PROFILE_YAML", prev_enabled)
  @sys.set_env_var("MARKITDOWN_PROFILE_YAML", "1")

  let (_doc, profile) = @yaml.parse_yaml_with_profile(
    resolve_sample_path(
      "samples/main_process/yaml/yaml_sequence_objects_table.yaml",
    ),
    "",
    6,
  )
  let report = match profile {
    Some(rep) => @yaml.yaml_profile_render_report(rep)
    None => fail("enabled yaml profile should create a report")
  }
  assert_true(report.contains("yaml_profile stage=yaml_file_read"))
  assert_true(report.contains("detail=bytes="))
  assert_true(report.contains("yaml_profile stage=yaml_bytes_to_string"))
  assert_true(report.contains("chars="))
  assert_true(report.contains("yaml_profile stage=yaml_detect_table"))
  assert_true(report.contains("kind=sequence_table rows="))
  assert_true(report.contains("yaml_profile stage=yaml_to_ir"))
  assert_true(report.contains("blocks="))
}

///|
test "yaml scalar sequence emits bullet list" {
  let input = resolve_sample_path(
    "samples/main_process/yaml/yaml_sequence_scalars.yaml",
  )
  let expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/yaml/expected/yaml_sequence_scalars.md",
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
      "samples/main_process/yaml/expected/yaml_sequence_objects_table.md",
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
      "samples/main_process/yaml/expected/yml_extension_basic.md",
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
      "samples/main_process/yaml/expected/yaml_nested_mapping.md",
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
      "samples/main_process/yaml/expected/yaml_quoted_strings.md",
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

}

///|
test "yaml single-document markers normalize without changing output" {
  let root = yaml_test_root()
  let out_dir = root + "/document-markers"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let base_path = out_dir + "/base.yaml"
  let leading_path = out_dir + "/leading.yaml"
  let trailing_path = out_dir + "/trailing.yaml"
  let trailing_comment_path = out_dir + "/trailing-comment.yaml"
  let trailing_start_path = out_dir + "/trailing-start.yaml"
  let trailing_start_comment_path = out_dir + "/trailing-start-comment.yaml"
  let leading_trailing_start_path = out_dir + "/leading-trailing-start.yaml"
  let leading_trailing_start_comment_path = out_dir +
    "/leading-trailing-start-comment.yaml"

  let base_text = "title: Example\ncount: 1\n"
  write_utf8_text(base_path, base_text)
  write_utf8_text(leading_path, "---\n" + base_text)
  write_utf8_text(trailing_path, base_text + "...\n")
  write_utf8_text(trailing_comment_path, base_text + "...\n# end comment\n")
  write_utf8_text(trailing_start_path, base_text + "---\n")
  write_utf8_text(
    trailing_start_comment_path,
    base_text + "---\n# end comment\n",
  )
  write_utf8_text(leading_trailing_start_path, "---\n" + base_text + "---\n")
  write_utf8_text(
    leading_trailing_start_comment_path,
    "---\n" + base_text + "---\n# end comment\n",
  )

  let base_doc = @yaml.parse_yaml(base_path, "", 6)
  let base_md = @cor.emit_markdown(base_doc)

  let leading_doc = @yaml.parse_yaml(leading_path, "", 6)
  assert_eq(@cor.emit_markdown(leading_doc), base_md)

  let trailing_doc = @yaml.parse_yaml(trailing_path, "", 6)
  assert_eq(@cor.emit_markdown(trailing_doc), base_md)

  let trailing_comment_doc = @yaml.parse_yaml(trailing_comment_path, "", 6)
  assert_eq(@cor.emit_markdown(trailing_comment_doc), base_md)

  let trailing_start_doc = @yaml.parse_yaml(trailing_start_path, "", 6)
  assert_eq(@cor.emit_markdown(trailing_start_doc), base_md)

  let trailing_start_comment_doc = @yaml.parse_yaml(
    trailing_start_comment_path, "", 6,
  )
  assert_eq(@cor.emit_markdown(trailing_start_comment_doc), base_md)

  let leading_trailing_start_doc = @yaml.parse_yaml(
    leading_trailing_start_path, "", 6,
  )
  assert_eq(@cor.emit_markdown(leading_trailing_start_doc), base_md)

  let leading_trailing_start_comment_doc = @yaml.parse_yaml(
    leading_trailing_start_comment_path, "", 6,
  )
  assert_eq(@cor.emit_markdown(leading_trailing_start_comment_doc), base_md)
}

///|
test "yaml real multi-document content stays unsupported" {
  let root = yaml_test_root()
  let out_dir = root + "/multi-doc-unsupported"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let second_doc_path = out_dir + "/second-doc.yaml"
  write_utf8_text(second_doc_path, "---\na: 1\n---\nb: 2\n")
  assert_true((try? @yaml.parse_yaml(second_doc_path, "", 6)) is Err(_))

  let after_end_path = out_dir + "/after-end.yaml"
  write_utf8_text(after_end_path, "a: 1\n...\nb: 2\n")
  assert_true((try? @yaml.parse_yaml(after_end_path, "", 6)) is Err(_))
}

///|
test "yaml bibliography-style nested sequence mappings stay parseable" {
  let root = yaml_test_root()
  let out_dir = root + "/bibliography-style"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let path = out_dir + "/biblio-like.yaml"
  write_utf8_text(
    path,
    "---\n" +
    "references:\n" +
    "- author:\n" +
    "  - family: Doe\n" +
    "    given: John\n" +
    "  id: item1\n" +
    "---\n",
  )

  let doc = @yaml.parse_yaml(path, "", 6)
  let md = @cor.emit_markdown(doc)
  assert_true(md.contains("Doe"))
  assert_true(md.contains("item1"))
}

///|
test "yaml comments blank lines and quoted colons stay deterministic" {
  let comments_doc = @yaml.parse_yaml(
    resolve_sample_path("samples/main_process/yaml/yaml_comments.yaml"),
    "",
    6,
  )
  let comments_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/yaml/expected/yaml_comments.md"),
  )
  assert_eq(@cor.emit_markdown(comments_doc), comments_expected)

  let quoted_doc = @yaml.parse_yaml(
    resolve_sample_path("samples/main_process/yaml/yaml_quoted_strings.yaml"),
    "",
    6,
  )
  let quoted_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/yaml/expected/yaml_quoted_strings.md",
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

///|
test "yaml flow collections convert through parser model" {
  let root = yaml_test_root()
  let out_dir = root + "/flow-collections"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let path = out_dir + "/flow.yaml"
  write_utf8_text(path, "items: [1, 2]\nperson: {name: Ada}\n")

  let doc = @yaml.parse_yaml(path, "", 6)
  let md = @cor.emit_markdown(doc)
  assert_true(md.contains("[1, 2]"))
  assert_true(md.contains("{name: Ada}"))
}

///|
test "yaml invalid utf8 fails closed" {
  let root = yaml_test_root()
  let out_dir = root + "/invalid-utf8"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let path = out_dir + "/invalid.yaml"
  @fs.write_bytes_to_file(path, Bytes::from_array([0xC3, 0x28])) catch {
    e => fail("write sample failed: " + e.to_string())
  }

  assert_true((try? @yaml.parse_yaml(path, "", 6)) is Err(_))
}

///|
test "yaml preserves legacy non-bmp literal behavior" {
  let root = yaml_test_root()
  let out_dir = root + "/non-bmp"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let path = out_dir + "/emoji.yaml"
  write_utf8_text(path, "label: \"🙂\"\n")

  let doc = @yaml.parse_yaml(path, "", 6)
  assert_eq(
    @cor.emit_markdown(doc),
    "| Key | Value |\n| --- | --- |\n| label | &#128578; |\n",
  )
}
