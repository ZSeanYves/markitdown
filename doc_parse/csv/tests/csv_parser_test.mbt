///|
test "csv parser handles simple rows and inspect counts" {
  let doc = @csv.parse_csv_document("name,age\nAda,12\nBob,13\n")
  assert_eq(doc.rows.length(), 3)
  assert_eq(doc.column_count, 2)
  assert_eq(doc.line_count, 3)
  assert_eq(doc.rows[1].fields, ["Ada", "12"])

  let report = @csv.inspect_csv_document(doc)
  assert_eq(report.row_count, 3)
  assert_eq(report.column_count, 2)
  assert_eq(report.ragged_row_count, 0)
}

///|
test "csv parser handles quoted field escaped quote and multiline field" {
  let doc = @csv.parse_csv_document(
    "\"name\",\"note\"\n\"Ada\",\"line 1\nline 2\"\n\"Bob\",\"say \"\"hi\"\"\"\n",
  )
  assert_eq(doc.rows.length(), 3)
  assert_eq(doc.rows[1].fields[1], "line 1\nline 2")
  assert_eq(doc.rows[2].fields[1], "say \"hi\"")
  assert_eq(doc.rows[1].line_start, 2)
  assert_eq(doc.rows[1].line_end, 3)

  let report = @csv.inspect_csv_document(doc)
  assert_eq(report.multiline_row_count, 1)
  assert_eq(report.multiline_field_count, 1)
}

///|
test "csv validation reports ragged rows and empty cells" {
  let doc = @csv.parse_csv_document("a,b,c\n1,2\n3,,5\n")
  assert_eq(doc.column_count, 3)
  assert_eq(doc.rows[1].fields, ["1", "2", ""])

  let issues = @csv.collect_csv_validation_issues(doc)
  assert_eq(issues.length(), 1)
  assert_true(issues[0].kind == @csv.CsvValidationIssueKind::RaggedRow)
  assert_eq(issues[0].row_index, 2)

  let report = @csv.inspect_csv_document(doc)
  assert_eq(report.empty_cell_count, 2)
}

///|
test "csv malformed quote fails closed and classifies" {
  assert_true((try? @csv.parse_csv_document("\"a,b")) is Err(_))

  let info = @csv.classify_csv_error(
    @csv.CsvError::ParseError("unterminated quoted field"),
  )
  assert_true(info.kind == @csv.CsvErrorKind::UnterminatedQuotedField)
}
