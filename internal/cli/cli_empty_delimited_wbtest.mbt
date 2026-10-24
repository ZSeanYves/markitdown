///|
async fn assert_cli_empty_delimited_with_provenance(
  format : @input.DetectedFormat,
  extension : String,
) -> Unit {
  let root = test_tmp_root() + "/empty-provenance-" + extension
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  let input = root + "/empty." + extension
  let streamed_path = root + "/streamed.md"
  let collected_path = root + "/collected.md"
  let provenance_path = root + "/provenance.json"
  write_utf8_text(input, "")
  let streamed = run_cli(
    cli_options(input, Some(streamed_path), Some(format), Markdown),
  ).unwrap()
  let collected = run_cli(
    cli_options(
      input,
      Some(collected_path),
      Some(format),
      Markdown,
      provenance_output=Some(provenance_path),
    ),
  ).unwrap()
  assert_eq(streamed, "")
  assert_eq(collected, streamed)
  assert_eq(read_utf8_text(streamed_path), "")
  assert_eq(read_utf8_text(collected_path), "")
  let sidecar = read_utf8_text(provenance_path)
  assert_true(sidecar.contains("\"detected_format\": \"" + extension + "\""))
  assert_true(sidecar.contains("\"budget_usage\":"))
  assert_true(sidecar.contains("\"stage_timings_ms\":"))
}

///|
async test "main CLI provenance accepts empty CSV with unchanged output" {
  assert_cli_empty_delimited_with_provenance(Csv, "csv")
}

///|
async test "main CLI provenance accepts empty TSV with unchanged output" {
  assert_cli_empty_delimited_with_provenance(Tsv, "tsv")
}
