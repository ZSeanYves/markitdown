///|
test "tsv parser uses tab delimiter and keeps ragged rows visible" {
  let doc = @tsv.parse_tsv_document(
    "name\tage\tcity\nAda\t12\nBob\t13\tParis\n",
  )
  assert_true(doc.delimiter == @csv.CsvDelimiter::Tab)
  assert_eq(doc.column_count, 3)
  assert_true(doc.rows[1].fields == ["Ada", "12", ""])

  let issues = @tsv.collect_tsv_validation_issues(doc)
  assert_eq(issues.length(), 1)
  assert_true(issues[0].kind == @csv.CsvValidationIssueKind::RaggedRow)
}

///|
test "tsv parser handles quoted tabs" {
  let doc = @tsv.parse_tsv_document("a\tb\n\"x\ty\"\tz\n")
  assert_eq(doc.rows[1].fields[0], "x\ty")
  let report = @tsv.inspect_tsv_document(doc)
  assert_eq(report.row_count, 2)
}
