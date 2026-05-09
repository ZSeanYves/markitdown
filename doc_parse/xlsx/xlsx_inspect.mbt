///|
pub fn collect_xlsx_validation_issues(
  workbook : XlsxWorkbook,
) -> Array[XlsxValidationIssue] {
  let issues : Array[XlsxValidationIssue] = []

  for issue in workbook.issues {
    issues.push(issue)
  }
  for sheet in workbook.sheets {
    for issue in sheet.issues {
      issues.push(issue)
    }
    for cell in sheet.cells {
      for issue in cell.issues {
        issues.push(issue)
      }
    }
  }

  issues
}

///|
pub fn validate_xlsx_workbook(workbook : XlsxWorkbook) -> XlsxValidationReport {
  let issues = collect_xlsx_validation_issues(workbook)
  let mut warning_count = 0
  let mut error_count = 0
  let mut cell_count = 0

  for sheet in workbook.sheets {
    cell_count += sheet.cells.length()
  }

  for issue in issues {
    match issue.severity {
      XlsxValidationSeverity::Warning => warning_count += 1
      XlsxValidationSeverity::Error => error_count += 1
    }
  }

  {
    sheet_count: workbook.sheets.length(),
    cell_count,
    issue_count: issues.length(),
    warning_count,
    error_count,
    issues,
  }
}

///|
pub fn inspect_xlsx_workbook(workbook : XlsxWorkbook) -> XlsxInspectReport {
  let validation = validate_xlsx_workbook(workbook)
  let mut hidden_sheet_count = 0
  let mut cell_count = 0
  let mut non_empty_cell_count = 0
  let mut formula_cell_count = 0
  let mut merged_range_count = 0

  for sheet in workbook.sheets {
    match sheet.state {
      XlsxSheetState::Hidden | XlsxSheetState::VeryHidden =>
        hidden_sheet_count += 1
      _ => ()
    }
    cell_count += sheet.cells.length()
    merged_range_count += sheet.merged_ranges.length()

    for cell in sheet.cells {
      if @cor.trim_string(cell.display_text) != "" {
        non_empty_cell_count += 1
      }
      match cell.formula_text {
        Some(text) => if text.trim() != "" { formula_cell_count += 1 }
        None => ()
      }
    }
  }

  {
    sheet_count: workbook.sheets.length(),
    hidden_sheet_count,
    cell_count,
    non_empty_cell_count,
    formula_cell_count,
    merged_range_count,
    shared_string_count: workbook.shared_strings.length(),
    style_count: workbook.styles.xf_numfmts.length(),
    uses_date_1904: workbook.uses_date_1904,
    issue_count: validation.issue_count,
    warning_count: validation.warning_count,
    error_count: validation.error_count,
  }
}
