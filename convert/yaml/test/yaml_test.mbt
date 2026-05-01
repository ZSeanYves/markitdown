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
