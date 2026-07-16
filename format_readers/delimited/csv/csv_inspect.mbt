///|
/// Summarize structure for a parsed CSV document.
pub fn inspect_csv_document(doc : CsvDocument) -> CsvInspectReport {
  let mut empty_cell_count = 0
  let mut blank_row_count = 0
  let mut ragged_row_count = 0
  let mut multiline_row_count = 0
  let mut multiline_field_count = 0
  let mut min_field_count = 0
  let mut max_field_count = 0

  for i in 0..<doc.rows.length() {
    let row = doc.rows[i]
    if i == 0 || row.original_field_count < min_field_count {
      min_field_count = row.original_field_count
    }
    if row.original_field_count > max_field_count {
      max_field_count = row.original_field_count
    }
    if csv_inspect_row_is_blank(row.fields) {
      blank_row_count += 1
    }
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
    min_field_count,
    max_field_count,
    empty_cell_count,
    blank_row_count,
    ragged_row_count,
    multiline_row_count,
    multiline_field_count,
  }
}

///|
fn csv_inspect_row_is_blank(fields : Array[String]) -> Bool {
  for field in fields {
    if field != "" {
      return false
    }
  }
  true
}

///|
/// Return CSV validation issues without treating them as hard parse failures.
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
        kind: RaggedRow,
        severity: Warning,
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
/// Aggregate CSV validation counts and issues into a deterministic report.
pub fn validate_csv_document(doc : CsvDocument) -> CsvValidationReport {
  let issues = collect_csv_validation_issues(doc)
  let mut warning_count = 0
  let mut error_count = 0

  for issue in issues {
    match issue.severity {
      Warning => warning_count += 1
      Error => error_count += 1
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
