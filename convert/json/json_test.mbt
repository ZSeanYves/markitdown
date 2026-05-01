///|
fn resolve_sample_path(path : String) -> String raise {
  if @fs.path_exists(path) {
    return path
  }

  let fallback = "../../" + path
  if @fs.path_exists(fallback) {
    return fallback
  }

  fail("sample file not found: " + path)
}

///|
test "json object table uses explicit header semantics" {
  let doc = parse_json(
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
  let doc = parse_json(
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
