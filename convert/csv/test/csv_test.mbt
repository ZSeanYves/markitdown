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
test "csv core samples stay stable" {
  let basic_doc = @csv.parse_csv(
    resolve_sample_path("samples/main_process/csv/csv_basic.csv"),
    "",
    6,
  )
  let basic_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/expected/csv/csv_basic.md"),
  )
  assert_eq(@cor.emit_markdown(basic_doc), basic_expected)
  assert_eq(basic_doc.blocks.val.length(), 1)

  let ragged_doc = @csv.parse_csv(
    resolve_sample_path("samples/main_process/csv/csv_ragged_rows.csv"),
    "",
    6,
  )
  let ragged_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/expected/csv/csv_ragged_rows.md"),
  )
  assert_eq(@cor.emit_markdown(ragged_doc), ragged_expected)
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
      "samples/main_process/expected/csv/csv_quoted_newline.md",
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
      "samples/main_process/expected/csv/csv_markdown_pipes.md",
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
    resolve_sample_path("samples/main_process/expected/csv/csv_bom_utf8.md"),
  )
  assert_eq(@cor.emit_markdown(bom_doc), bom_expected)

  let crlf_doc = @csv.parse_csv(
    resolve_sample_path("samples/main_process/csv/csv_crlf.csv"),
    "",
    6,
  )
  let crlf_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/expected/csv/csv_crlf.md"),
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
    resolve_sample_path("samples/main_process/expected/tsv/tsv_basic.md"),
  )
  assert_eq(@cor.emit_markdown(basic_doc), basic_expected)

  let pipe_doc = @csv.parse_tsv(
    resolve_sample_path("samples/main_process/tsv/tsv_markdown_pipes.tsv"),
    "",
    6,
  )
  let pipe_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/tsv/tsv_markdown_pipes.md",
    ),
  )
  assert_eq(@cor.emit_markdown(pipe_doc), pipe_expected)

  let bom_doc = @csv.parse_tsv(
    resolve_sample_path("samples/main_process/tsv/tsv_bom_utf8.tsv"),
    "",
    6,
  )
  let bom_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/expected/tsv/tsv_bom_utf8.md"),
  )
  assert_eq(@cor.emit_markdown(bom_doc), bom_expected)
}
