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
fn open_sample_package(path : String) -> @ox.OoxmlPackage raise {
  let bytes = @fs.read_file_to_bytes(resolve_sample_path(path)) catch {
    e => fail("read sample failed: " + e.to_string())
  }
  @ox.open_ooxml_package(bytes) catch {
    e => fail("open sample package failed: " + e.to_string())
  }
}

///|
test "xlsx semantic workbook preserves sheet order, targets, and visibility" {
  let workbook = @xlsx.open_xlsx_workbook(
    resolve_sample_path("samples/main_process/xlsx/sheet_simple.xlsx"),
  )
  assert_eq(workbook.sheets.length(), 2)
  assert_eq(workbook.sheets[0].name, "Sheet1")
  assert_eq(workbook.sheets[1].name, "Data")
  if workbook.sheets[0].part_target != Some("xl/worksheets/sheet1.xml") {
    fail("expected first sheet target xl/worksheets/sheet1.xml")
  }

  let hidden = @xlsx.open_xlsx_workbook(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_hidden_sheets_policy.xlsx",
    ),
  )
  match hidden.sheets[2].state {
    @xlsx.XlsxSheetState::VeryHidden => ()
    _ => fail("third sheet should preserve veryHidden state")
  }
}

///|
test "xlsx semantic package parse matches path open and keeps shared strings" {
  let workbook = @xlsx.open_xlsx_workbook(
    resolve_sample_path("samples/main_process/xlsx/xlsx_cell_types.xlsx"),
  )
  let pkg = open_sample_package(
    "samples/main_process/xlsx/xlsx_cell_types.xlsx",
  )
  let parsed = @xlsx.parse_xlsx_workbook_from_package(pkg)
  assert_eq(parsed.sheets.length(), workbook.sheets.length())
  assert_eq(parsed.sheets[0].name, workbook.sheets[0].name)
  assert_true(parsed.shared_strings.length() > 0)
}

///|
test "xlsx semantic cells preserve kinds semantic types and raw formulas" {
  let typed = @xlsx.open_xlsx_workbook(
    resolve_sample_path("samples/main_process/xlsx/xlsx_cell_types.xlsx"),
  )
  let mut saw_shared = false
  let mut saw_bool = false
  let mut saw_error = false
  let mut saw_number = false
  for cell in typed.sheets[0].cells {
    match cell.kind {
      @xlsx.XlsxCellKind::SharedString =>
        if cell.display_text == "inline ok" {
          saw_shared = true
        }
      @xlsx.XlsxCellKind::Boolean => saw_bool = true
      @xlsx.XlsxCellKind::Error => saw_error = true
      @xlsx.XlsxCellKind::Number =>
        if cell.display_text == "42" {
          saw_number = true
        }
      _ => ()
    }
  }
  assert_true(saw_shared)
  assert_true(saw_bool)
  assert_true(saw_error)
  assert_true(saw_number)

  let formula = @xlsx.open_xlsx_workbook(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_cached_values.xlsx",
    ),
  )
  let mut saw_formula = false
  for cell in formula.sheets[0].cells {
    match cell.formula_text {
      Some(text) =>
        if text.trim() != "" {
          saw_formula = true
          break
        }
      None => ()
    }
  }
  assert_true(saw_formula)
}

///|
test "xlsx semantic formula trace captures cached evaluated and unsupported policies" {
  let cached = @xlsx.open_xlsx_workbook(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_cached_values.xlsx",
    ),
  )
  let mut saw_cached = false
  for cell in cached.sheets[0].cells {
    match cell.formula_trace {
      Some(trace) =>
        if trace.policy == @xlsx.XlsxFormulaPolicy::Cached {
          saw_cached = true
        }
      None => ()
    }
  }
  assert_true(saw_cached)

  let evaluated = @xlsx.open_xlsx_workbook(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_eval_if_round_text.xlsx",
    ),
  )
  let mut saw_evaluated = false
  for cell in evaluated.sheets[0].cells {
    match cell.formula_trace {
      Some(trace) =>
        if trace.policy == @xlsx.XlsxFormulaPolicy::EvaluatedMissingCache &&
          trace.evaluated_value == Some("high") {
          saw_evaluated = true
        }
      None => ()
    }
  }
  assert_true(saw_evaluated)

  let unsupported = @xlsx.open_xlsx_workbook(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_eval_unsupported.xlsx",
    ),
  )
  let unsupported_report = @xlsx.validate_xlsx_workbook(unsupported)
  let mut saw_unsupported_issue = false
  for issue in unsupported_report.issues {
    if issue.kind == @xlsx.XlsxValidationIssueKind::UnsupportedFormulaEvaluation {
      saw_unsupported_issue = true
    }
  }
  assert_true(saw_unsupported_issue)
}

///|
test "xlsx semantic inspect counts hidden sheets merged ranges and formulas" {
  let workbook = @xlsx.open_xlsx_workbook(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_merged_cells_policy.xlsx",
    ),
  )
  let inspect = @xlsx.inspect_xlsx_workbook(workbook)
  assert_true(inspect.sheet_count > 0)
  assert_true(inspect.merged_range_count > 0)

  let hidden = @xlsx.open_xlsx_workbook(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_hidden_sheets_policy.xlsx",
    ),
  )
  let hidden_inspect = @xlsx.inspect_xlsx_workbook(hidden)
  assert_true(hidden_inspect.hidden_sheet_count > 0)

  let formula = @xlsx.open_xlsx_workbook(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_eval_ranges.xlsx",
    ),
  )
  let formula_inspect = @xlsx.inspect_xlsx_workbook(formula)
  assert_true(formula_inspect.formula_cell_count > 0)
}

///|
test "xlsx classifier is stable for open and parse failures" {
  let open_info = @xlsx.classify_xlsx_error(
    @xlsx.XlsxError::OpenFailed("missing.xlsx"),
  )
  if open_info.kind != @xlsx.XlsxErrorKind::OpenFailed {
    fail("expected OpenFailed classification")
  }

  let parse_info = @xlsx.classify_xlsx_error(
    @xlsx.XlsxError::ParseError("invalid cell reference: A0"),
  )
  if parse_info.kind != @xlsx.XlsxErrorKind::InvalidCellReference {
    fail("expected InvalidCellReference classification")
  }
}
