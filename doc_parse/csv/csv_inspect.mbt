///|
pub fn inspect_csv_document(doc : CsvDocument) -> CsvInspectReport {
  let mut empty_cell_count = 0
  let mut ragged_row_count = 0
  let mut multiline_row_count = 0
  let mut multiline_field_count = 0

  for row in doc.rows {
    if row.original_field_count != doc.column_count {
      ragged_row_count += 1
    }
    if row.line_end > row.line_start {
      multiline_row_count += 1
    }
    for field in row.fields {
      if field == "" {
        empty_cell_count += 1
      }
      if field.contains("\n") {
        multiline_field_count += 1
      }
    }
  }

  {
    delimiter: doc.delimiter,
    row_count: doc.rows.length(),
    column_count: doc.column_count,
    line_count: doc.line_count,
    empty_cell_count,
    ragged_row_count,
    multiline_row_count,
    multiline_field_count,
  }
}

///|
pub fn collect_csv_validation_issues(
  doc : CsvDocument,
) -> Array[CsvValidationIssue] {
  let issues : Array[CsvValidationIssue] = []
  if doc.column_count == 0 {
    return issues
  }

  for i in 0..<doc.rows.length() {
    let row = doc.rows[i]
    if row.original_field_count != doc.column_count {
      issues.push({
        kind: CsvValidationIssueKind::RaggedRow,
        severity: CsvValidationSeverity::Warning,
        row_index: i + 1,
        actual_field_count: row.original_field_count,
        expected_field_count: doc.column_count,
        message: "row has ragged field count",
      })
    }
  }

  issues
}

///|
pub fn validate_csv_document(doc : CsvDocument) -> CsvValidationReport {
  let issues = collect_csv_validation_issues(doc)
  let mut warning_count = 0
  let mut error_count = 0

  for issue in issues {
    match issue.severity {
      CsvValidationSeverity::Warning => warning_count += 1
      CsvValidationSeverity::Error => error_count += 1
    }
  }

  {
    row_count: doc.rows.length(),
    column_count: doc.column_count,
    issue_count: issues.length(),
    warning_count,
    error_count,
    issues,
  }
}
