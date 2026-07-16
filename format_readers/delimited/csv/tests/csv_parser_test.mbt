///|
test "csv parser handles simple rows and inspect counts" {
  let doc = @csv.parse_csv_document("name,age\nAda,12\nBob,13\n")
  assert_eq(doc.rows.length(), 3)
  assert_eq(doc.column_count, 2)
  assert_eq(doc.line_count, 4)
  assert_true(doc.rows[1].fields == ["Ada", "12"])

  let report = @csv.inspect_csv_document(doc)
  assert_eq(report.row_count, 3)
  assert_eq(report.column_count, 2)
  assert_eq(report.min_field_count, 2)
  assert_eq(report.max_field_count, 2)
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
  assert_true(doc.rows[1].fields == ["1", "2", ""])

  let issues = @csv.collect_csv_validation_issues(doc)
  assert_eq(issues.length(), 1)
  assert_true(issues[0].kind == RaggedRow)
  assert_eq(issues[0].row_index, 2)

  let report = @csv.inspect_csv_document(doc)
  assert_eq(report.min_field_count, 2)
  assert_eq(report.max_field_count, 3)
  assert_eq(report.empty_cell_count, 2)
}

///|
test "csv malformed quote fails closed and classifies" {
  assert_true(
    (try @csv.parse_csv_document("\"a,b") |> Ok catch {
      e => Err(e)
    })
    is Err(_),
  )

  let info = @csv.classify_csv_error(ParseError("unterminated quoted field"))
  assert_true(info.kind == UnterminatedQuotedField)
}

///|
test "csv parse options stay header-neutral and can preserve blank rows" {
  let doc = @csv.parse_csv_with_options(
    "name,age\n\nAda,12\nsolo\n",
    @csv.new_csv_parse_options(Comma, '"', true, false, false),
  )

  assert_eq(doc.rows.length(), 4)
  assert_true(doc.rows[1].fields == [""])
  assert_true(doc.rows[3].fields == ["solo"])
  assert_eq(doc.rows[3].original_field_count, 1)

  let issues = @csv.collect_csv_validation_issues(doc)
  assert_eq(issues.length(), 2)
  assert_eq(issues[0].row_index, 2)
  assert_eq(issues[1].row_index, 4)

  let report = @csv.inspect_csv_document(doc)
  assert_eq(report.blank_row_count, 1)
}

///|
test "csv validation issue ordering stays deterministic" {
  let doc = @csv.parse_csv_with_options(
    "a,b,c\nx\n\n1,2\n",
    @csv.new_csv_parse_options(Comma, '"', true, false, false),
  )
  let issues = @csv.collect_csv_validation_issues(doc)
  assert_eq(issues.length(), 3)
  assert_eq(issues[0].row_index, 2)
  assert_eq(issues[1].row_index, 3)
  assert_eq(issues[2].row_index, 4)
}
