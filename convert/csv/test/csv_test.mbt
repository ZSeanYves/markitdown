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
  ".tmp/convert-csv-test"
}

///|
fn write_bytes(path : String, bytes : Bytes) -> Unit raise {
  @fs.write_bytes_to_file(path, bytes) catch {
    e => fail("write sample failed: " + e.to_string())
  }
}

///|
fn write_utf8_text(path : String, text : String) -> Unit raise {
  @fs.write_string_to_file(path, text, encoding="utf8") catch {
    e => fail("write sample failed: " + e.to_string())
  }
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
fn csv_test_root() -> String raise {
  ensure_dir_tree(test_tmp_root())
  let dir = test_tmp_root() + "/cases"
  ensure_dir(dir)
  dir
}

///|
test "csv core samples stay stable" {
  let basic_doc = @csv.parse_csv(
    resolve_sample_path("samples/main_process/csv/csv_basic.csv"),
    "",
    6,
  )
  let basic_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/csv/expected/csv_basic.md"),
  )
  assert_eq(@cor.emit_markdown(basic_doc), basic_expected)
  assert_eq(basic_doc.blocks.val.length(), 1)

  let ragged_doc = @csv.parse_csv(
    resolve_sample_path("samples/main_process/csv/csv_ragged_rows.csv"),
    "",
    6,
  )
  let ragged_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/csv/expected/csv_ragged_rows.md"),
  )
  assert_eq(@cor.emit_markdown(ragged_doc), ragged_expected)

  match basic_doc.blocks.val[0] {
    @cor.Block::RichTable(table) => {
      assert_eq(table.header_rows, 1)
      assert_true(table.rows[0] == ["Name", "Role"])
    }
    _ => fail("csv_basic should emit RichTable")
  }
}

///|
test "csv and tsv profile disabled return no report" {
  let prev_enabled = @sys.get_env_var("MARKITDOWN_PROFILE_CSV")
  defer restore_env_var("MARKITDOWN_PROFILE_CSV", prev_enabled)
  @sys.unset_env_var("MARKITDOWN_PROFILE_CSV")

  let (csv_doc, csv_profile) = @csv.parse_csv_with_profile(
    resolve_sample_path("samples/main_process/csv/csv_basic.csv"),
    "",
    6,
  )
  assert_true(@cor.emit_markdown(csv_doc).contains("| Name | Role |"))
  match csv_profile {
    None => ()
    Some(_) => fail("disabled csv profile should not create a report")
  }

  let (tsv_doc, tsv_profile) = @csv.parse_tsv_with_profile(
    resolve_sample_path("samples/main_process/tsv/tsv_basic.tsv"),
    "",
    6,
  )
  assert_true(@cor.emit_markdown(tsv_doc).contains("| Name | Role |"))
  match tsv_profile {
    None => ()
    Some(_) => fail("disabled tsv profile should not create a report")
  }
}

///|
test "csv and tsv profile enabled preserve stage details" {
  let prev_enabled = @sys.get_env_var("MARKITDOWN_PROFILE_CSV")
  defer restore_env_var("MARKITDOWN_PROFILE_CSV", prev_enabled)
  @sys.set_env_var("MARKITDOWN_PROFILE_CSV", "1")

  let (_csv_doc, csv_profile) = @csv.parse_csv_with_profile(
    resolve_sample_path("samples/main_process/csv/csv_basic.csv"),
    "",
    6,
  )
  let csv_report = match csv_profile {
    Some(rep) => @csv.csv_profile_render_report(rep)
    None => fail("enabled csv profile should create a report")
  }
  assert_true(csv_report.contains("csv_profile input="))
  assert_true(csv_report.contains("format=csv"))
  assert_true(csv_report.contains("csv_profile stage=csv_file_read"))
  assert_true(csv_report.contains("detail=bytes="))
  assert_true(csv_report.contains("csv_profile stage=csv_bytes_to_string"))
  assert_true(csv_report.contains("chars="))
  assert_true(csv_report.contains("csv_profile stage=csv_parse_records"))
  assert_true(csv_report.contains("rows="))
  assert_true(csv_report.contains("csv_profile stage=csv_to_rich_table"))
  assert_true(csv_report.contains("blocks="))

  let (_tsv_doc, tsv_profile) = @csv.parse_tsv_with_profile(
    resolve_sample_path("samples/main_process/tsv/tsv_basic.tsv"),
    "",
    6,
  )
  let tsv_report = match tsv_profile {
    Some(rep) => @csv.csv_profile_render_report(rep)
    None => fail("enabled tsv profile should create a report")
  }
  assert_true(tsv_report.contains("format=tsv"))
  assert_true(tsv_report.contains("csv_profile stage=csv_parse_records"))
  assert_true(tsv_report.contains("rows="))
}

///|
test "csv quoted fields and markdown pipes stay readable" {
  let quoted_doc = @csv.parse_csv(
    resolve_sample_path("samples/main_process/csv/csv_quoted_newline.csv"),
    "",
    6,
  )
  let quoted_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/csv/expected/csv_quoted_newline.md",
    ),
  )
  assert_eq(@cor.emit_markdown(quoted_doc), quoted_expected)

  let pipe_doc = @csv.parse_csv(
    resolve_sample_path("samples/main_process/csv/csv_markdown_pipes.csv"),
    "",
    6,
  )
  let pipe_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/csv/expected/csv_markdown_pipes.md",
    ),
  )
  assert_eq(@cor.emit_markdown(pipe_doc), pipe_expected)
}

///|
test "csv strips utf8 bom and normalizes crlf without dropping empty output" {
  let bom_doc = @csv.parse_csv(
    resolve_sample_path("samples/main_process/csv/csv_bom_utf8.csv"),
    "",
    6,
  )
  let bom_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/csv/expected/csv_bom_utf8.md"),
  )
  assert_eq(@cor.emit_markdown(bom_doc), bom_expected)

  let crlf_doc = @csv.parse_csv(
    resolve_sample_path("samples/main_process/csv/csv_crlf.csv"),
    "",
    6,
  )
  let crlf_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/csv/expected/csv_crlf.md"),
  )
  assert_eq(@cor.emit_markdown(crlf_doc), crlf_expected)

  let empty_doc = @csv.parse_csv(
    resolve_sample_path("samples/main_process/csv/csv_empty.csv"),
    "",
    6,
  )
  assert_eq(empty_doc.blocks.val.length(), 0)
  assert_eq(@cor.emit_markdown(empty_doc), "")
}

///|
test "tsv samples stay stable" {
  let basic_doc = @csv.parse_tsv(
    resolve_sample_path("samples/main_process/tsv/tsv_basic.tsv"),
    "",
    6,
  )
  let basic_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/tsv/expected/tsv_basic.md"),
  )
  assert_eq(@cor.emit_markdown(basic_doc), basic_expected)

  let pipe_doc = @csv.parse_tsv(
    resolve_sample_path("samples/main_process/tsv/tsv_markdown_pipes.tsv"),
    "",
    6,
  )
  let pipe_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/tsv/expected/tsv_markdown_pipes.md",
    ),
  )
  assert_eq(@cor.emit_markdown(pipe_doc), pipe_expected)

  let bom_doc = @csv.parse_tsv(
    resolve_sample_path("samples/main_process/tsv/tsv_bom_utf8.tsv"),
    "",
    6,
  )
  let bom_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/tsv/expected/tsv_bom_utf8.md"),
  )
  assert_eq(@cor.emit_markdown(bom_doc), bom_expected)

  match basic_doc.blocks.val[0] {
    @cor.Block::RichTable(table) => {
      assert_eq(table.header_rows, 1)
      assert_true(table.rows[0] == ["Name", "Role"])
    }
    _ => fail("tsv_basic should emit RichTable")
  }
}

///|
test "csv parser keeps trailing empty cells and skips blank rows" {
  let dir = csv_test_root()
  let case_dir = dir + "/csv-blank-and-trailing"
  recreate_clean_dir(case_dir)
  defer cleanup_temp_dir(case_dir)

  let path = case_dir + "/blank_and_trailing.csv"
  write_utf8_text(path, "a,b,\n\nc,d,\n")

  let doc = @csv.parse_csv(path, "", 6)
  let expected = "| a | b |  |\n| --- | --- | --- |\n| c | d |  |\n"
  assert_eq(@cor.emit_markdown(doc), expected)

  match doc.blocks.val[0] {
    @cor.Block::RichTable(table) => {
      assert_eq(table.rows.length(), 2)
      assert_true(table.rows[0] == ["a", "b", ""])
      assert_true(table.rows[1] == ["c", "d", ""])
    }
    _ => fail("csv trailing delimiter case should emit RichTable")
  }
}

///|
test "csv parser handles single-column cells quoted delimiters and quoted newlines" {
  let dir = csv_test_root()
  let case_dir = dir + "/csv-shapes"
  recreate_clean_dir(case_dir)
  defer cleanup_temp_dir(case_dir)

  let single_path = case_dir + "/single_column.csv"
  write_utf8_text(single_path, "Only\nAlpha\nBeta\n")
  let single_doc = @csv.parse_csv(single_path, "", 6)
  assert_eq(
    @cor.emit_markdown(single_doc),
    "| Only |\n| --- |\n| Alpha |\n| Beta |\n",
  )

  let quoted_path = case_dir + "/quoted_bits.csv"
  write_utf8_text(quoted_path, "\"a,b\",c\n\"a\"\"b\",d\n")
  let quoted_doc = @csv.parse_csv(quoted_path, "", 6)
  match quoted_doc.blocks.val[0] {
    @cor.Block::RichTable(table) => {
      assert_true(table.rows[0] == ["a,b", "c"])
      assert_true(table.rows[1] == ["a\"b", "d"])
    }
    _ => fail("csv quoted delimiter sample should emit RichTable")
  }

  let newline_path = case_dir + "/quoted_newline.csv"
  write_utf8_text(newline_path, "Name,Note\nAlice,\"line1\nline2\"\n")
  let newline_doc = @csv.parse_csv(newline_path, "", 6)
  assert_eq(
    @cor.emit_markdown(newline_doc),
    "| Name | Note |\n| --- | --- |\n| Alice | line1<br>line2 |\n",
  )
}

///|
test "csv parser normalizes cr-only input and fails closed on unterminated quotes" {
  let dir = csv_test_root()
  let case_dir = dir + "/csv-cr-and-errors"
  recreate_clean_dir(case_dir)
  defer cleanup_temp_dir(case_dir)

  let cr_only_path = case_dir + "/cr_only.csv"
  write_bytes(
    cr_only_path,
    Bytes::from_array([97, 44, 98, 13, 99, 44, 100, 13]),
  )
  let cr_only_doc = @csv.parse_csv(cr_only_path, "", 6)
  assert_eq(
    @cor.emit_markdown(cr_only_doc),
    "| a | b |\n| --- | --- |\n| c | d |\n",
  )

  let bad_path = case_dir + "/unterminated.csv"
  write_utf8_text(bad_path, "a,b\n\"c,d\n")
  try @csv.parse_csv(bad_path, "", 6) catch {
    _ => ()
  } noraise {
    _ => fail("unterminated quoted csv should fail closed")
  }
}

///|
test "tsv parser keeps trailing empty cells quoted tabs and skips blank rows" {
  let dir = csv_test_root()
  let case_dir = dir + "/tsv-blank-and-trailing"
  recreate_clean_dir(case_dir)
  defer cleanup_temp_dir(case_dir)

  let path = case_dir + "/blank_and_trailing.tsv"
  write_utf8_text(path, "a\tb\t\n\nc\td\t\n")

  let doc = @csv.parse_tsv(path, "", 6)
  assert_eq(
    @cor.emit_markdown(doc),
    "| a | b |  |\n| --- | --- | --- |\n| c | d |  |\n",
  )

  let quoted_path = case_dir + "/quoted_tab.tsv"
  write_utf8_text(quoted_path, "\"a\tb\"\tc\nx\t|\n")
  let quoted_doc = @csv.parse_tsv(quoted_path, "", 6)
  assert_eq(
    @cor.emit_markdown(quoted_doc),
    "| a\tb | c |\n| --- | --- |\n| x | \\| |\n",
  )
}

///|
test "csv invalid utf8 fails closed" {
  let dir = csv_test_root()
  let case_dir = dir + "/csv-invalid-utf8"
  recreate_clean_dir(case_dir)
  defer cleanup_temp_dir(case_dir)

  let bad_path = case_dir + "/invalid.csv"
  write_bytes(bad_path, Bytes::from_array([0xC3, 0x28]))
  assert_true((try? @csv.parse_csv(bad_path, "", 6)) is Err(_))
}

///|
test "csv cp932 fixture bytes decode without mojibake" {
  let dir = csv_test_root()
  let case_dir = dir + "/csv-cp932"
  recreate_clean_dir(case_dir)
  defer cleanup_temp_dir(case_dir)

  let path = case_dir + "/mskanji.csv"
  write_bytes(
    path,
    Bytes::from_array([
      0x96, 0xBC, 0x91, 0x4F, 0x2C, 0x94, 0x4E, 0x97, 0xEE, 0x2C, 0x8F, 0x5A, 0x8F,
      0x8A, 0x0D, 0x0A, 0x8D, 0xB2, 0x93, 0xA1, 0x91, 0xBE, 0x98, 0x59, 0x2C, 0x33,
      0x30, 0x2C, 0x93, 0x8C, 0x8B, 0x9E, 0x0D, 0x0A, 0x8E, 0x4F, 0x96, 0xD8, 0x89,
      0x70, 0x8E, 0x71, 0x2C, 0x32, 0x35, 0x2C, 0x91, 0xE5, 0x8D, 0xE3, 0x0D, 0x0A,
      0xEE, 0xE0, 0x8B, 0xB4, 0x8F, 0x7E, 0x2C, 0x33, 0x35, 0x2C, 0x96, 0xBC, 0x8C,
      0xC3, 0x89, 0xAE, 0x0D, 0x0A,
    ]),
  )
  let doc = @csv.parse_csv(path, "", 6)
  assert_eq(
    @cor.emit_markdown(doc),
    "| 名前 | 年齢 | 住所 |\n| --- | --- | --- |\n| 佐藤太郎 | 30 | 東京 |\n| 三木英子 | 25 | 大阪 |\n| 髙橋淳 | 35 | 名古屋 |\n",
  )
}

///|
test "csv preserves legacy non-bmp literal behavior" {
  let dir = csv_test_root()
  let case_dir = dir + "/csv-non-bmp"
  recreate_clean_dir(case_dir)
  defer cleanup_temp_dir(case_dir)

  let path = case_dir + "/emoji.csv"
  write_utf8_text(path, "label,value\nemoji,🙂\n")
  let doc = @csv.parse_csv(path, "", 6)
  assert_eq(
    @cor.emit_markdown(doc),
    "| label | value |\n| --- | --- |\n| emoji | &#128578; |\n",
  )
}
