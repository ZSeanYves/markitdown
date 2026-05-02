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
test "xlsx main process samples stay stable" {
  let simple_doc = @xlsx.parse_xlsx(
    resolve_sample_path("samples/main_process/xlsx/sheet_simple.xlsx"),
    "",
    6,
  )
  let simple_markdown = @cor.emit_markdown(simple_doc)
  assert_true(simple_markdown.contains("## Sheet1"))
  assert_true(simple_markdown.contains("| Bob | 2.5 | emoji🙂 |"))
  assert_true(simple_markdown.contains("## Data"))

  let formula_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_cached_value_current_policy.xlsx",
    ),
    "",
    6,
  )
  let formula_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/xlsx/xlsx_formula_cached_value_current_policy.md",
    ),
  )
  assert_eq(@cor.emit_markdown(formula_doc), formula_expected)

  let hidden_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_hidden_sheet_current_behavior.xlsx",
    ),
    "",
    6,
  )
  let hidden_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/xlsx/xlsx_hidden_sheet_current_behavior.md",
    ),
  )
  assert_eq(@cor.emit_markdown(hidden_doc), hidden_expected)
}

///|
test "xlsx sheets now emit RichTable with explicit header semantics" {
  let doc = @xlsx.parse_xlsx(
    resolve_sample_path("samples/main_process/xlsx/sheet_simple.xlsx"),
    "",
    6,
  )

  match doc.blocks.val[1] {
    @cor.Block::RichTable(table) => {
      assert_eq(table.header_rows, 1)
      assert_eq(table.rows[0], ["Name", "Value", "备注"])
    }
    _ => fail("sheet_simple should emit RichTable")
  }
}

///|
test "xlsx inspect surface keeps hidden sheets, merged ranges, and formula text" {
  let hidden_book = @xlsx.inspect_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_hidden_sheet_current_behavior.xlsx",
    ),
  )
  assert_eq(hidden_book.sheets.length(), 2)
  match hidden_book.sheets[0].state {
    @xlsx.XlsxSheetState::Visible => ()
    _ => fail("first sheet should be visible")
  }
  match hidden_book.sheets[1].state {
    @xlsx.XlsxSheetState::Hidden => ()
    _ => fail("second sheet should be hidden")
  }

  let merged_book = @xlsx.inspect_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_merged_cells_current_policy.xlsx",
    ),
  )
  if merged_book.sheets[0].merged_ranges.length() == 0 {
    fail("merged sheet should expose merged_ranges")
  }

  let formula_book = @xlsx.inspect_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_cached_value_current_policy.xlsx",
    ),
  )
  let mut saw_formula = false
  for cell in formula_book.sheets[0].cells {
    match cell.formula_text {
      Some(text) => if text.trim() != "" { saw_formula = true }
      None => ()
    }
  }
  assert_true(saw_formula)
}

///|
test "xlsx inspect surface keeps sparse used range and cell kinds" {
  let sparse_book = @xlsx.inspect_xlsx(
    resolve_sample_path("samples/main_process/xlsx/xlsx_sparse_edges.xlsx"),
  )
  let sparse_sheet = sparse_book.sheets[0]
  assert_true(sparse_sheet.used_min_row > 0)
  assert_true(sparse_sheet.used_min_col > 0)
  assert_true(sparse_sheet.used_max_row >= sparse_sheet.used_min_row)
  assert_true(sparse_sheet.used_max_col >= sparse_sheet.used_min_col)

  let cell_types = @xlsx.inspect_xlsx(
    resolve_sample_path("samples/main_process/xlsx/xlsx_cell_types.xlsx"),
  )
  let mut saw_shared = false
  let mut saw_error = false
  let mut saw_bool = false
  let mut saw_number = false
  for cell in cell_types.sheets[0].cells {
    match cell.kind {
      @xlsx.XlsxCellKind::SharedString =>
        if cell.display_text == "inline ok" {
          saw_shared = true
        }
      @xlsx.XlsxCellKind::Error => saw_error = true
      @xlsx.XlsxCellKind::Boolean => saw_bool = true
      @xlsx.XlsxCellKind::Number =>
        if cell.display_text == "42" {
          saw_number = true
        }
      _ => ()
    }
  }
  assert_true(saw_shared)
  assert_true(saw_error)
  assert_true(saw_bool)
  assert_true(saw_number)
}

///|
test "xlsx second-round policy samples stay stable" {
  let formula_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/xlsx/xlsx_formula_cached_values.md",
    ),
  )
  let formula_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_cached_values.xlsx",
    ),
    "",
    6,
  )
  assert_eq(@cor.emit_markdown(formula_doc), formula_expected)

  let missing_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/xlsx/xlsx_formula_missing_cache.md",
    ),
  )
  let missing_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_missing_cache.xlsx",
    ),
    "",
    6,
  )
  assert_eq(@cor.emit_markdown(missing_doc), missing_expected)

  let merged_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/xlsx/xlsx_merged_cells_policy.md",
    ),
  )
  let merged_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_merged_cells_policy.xlsx",
    ),
    "",
    6,
  )
  assert_eq(@cor.emit_markdown(merged_doc), merged_expected)

  let hidden_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/xlsx/xlsx_hidden_sheets_policy.md",
    ),
  )
  let hidden_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_hidden_sheets_policy.xlsx",
    ),
    "",
    6,
  )
  assert_eq(@cor.emit_markdown(hidden_doc), hidden_expected)

  let typed_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/xlsx/xlsx_typed_cells_matrix.md",
    ),
  )
  let typed_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_typed_cells_matrix.xlsx",
    ),
    "",
    6,
  )
  assert_eq(@cor.emit_markdown(typed_doc), typed_expected)

  let arithmetic_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/xlsx/xlsx_formula_eval_arithmetic.md",
    ),
  )
  let arithmetic_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_eval_arithmetic.xlsx",
    ),
    "",
    6,
  )
  assert_eq(@cor.emit_markdown(arithmetic_doc), arithmetic_expected)

  let ranges_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/xlsx/xlsx_formula_eval_ranges.md",
    ),
  )
  let ranges_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_eval_ranges.xlsx",
    ),
    "",
    6,
  )
  assert_eq(@cor.emit_markdown(ranges_doc), ranges_expected)

  let if_round_text_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/xlsx/xlsx_formula_eval_if_round_text.md",
    ),
  )
  let if_round_text_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_eval_if_round_text.xlsx",
    ),
    "",
    6,
  )
  assert_eq(@cor.emit_markdown(if_round_text_doc), if_round_text_expected)

  let unsupported_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/xlsx/xlsx_formula_eval_unsupported.md",
    ),
  )
  let unsupported_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_eval_unsupported.xlsx",
    ),
    "",
    6,
  )
  assert_eq(@cor.emit_markdown(unsupported_doc), unsupported_expected)

  let errors_expected = read_utf8_text(
    resolve_sample_path(
      "samples/main_process/expected/xlsx/xlsx_formula_eval_errors.md",
    ),
  )
  let errors_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_eval_errors.xlsx",
    ),
    "",
    6,
  )
  assert_eq(@cor.emit_markdown(errors_doc), errors_expected)
}

///|
test "xlsx RichTable hints expose formula, merged, semantic-type, and sheet-state policy" {
  let formula_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_cached_values.xlsx",
    ),
    "",
    6,
  )
  match formula_doc.blocks.val[1] {
    @cor.Block::RichTable(table) =>
      match table.hints {
        Some(hints) => {
          if hints.format != Some("xlsx") {
            fail("expected xlsx format hint on formula policy sheet")
          }
          if hints.sheet_state != Some("visible") {
            fail("expected visible sheet_state on formula policy sheet")
          }
          match hints.formula_cells {
            Some(cells) => {
              assert_eq(cells.length(), 5)
              assert_eq(cells[0].semantic_type, "formula_cached_value")
              if cells[0].policy != Some("cached") {
                fail("expected cached policy on cached formula cell")
              }
              assert_eq(cells[4].semantic_type, "number")
              if cells[4].policy != Some("evaluated_missing_cache") {
                fail("expected evaluated_missing_cache policy")
              }
              if cells[4].evaluated_value != Some("5") {
                fail("expected evaluated missing-cache formula value 5")
              }
            }
            None => fail("formula policy sheet should expose formula_cells")
          }
          match hints.semantic_types {
            Some(rows) => {
              assert_eq(rows[1][1], "formula_cached_value")
              assert_eq(rows[5][1], "number")
              assert_eq(rows[6][1], "string")
            }
            None => fail("formula policy sheet should expose semantic_types")
          }
        }
        None => fail("xlsx RichTable should expose hints")
      }
    _ => fail("xlsx formula policy should emit RichTable")
  }

  let merged_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_merged_cells_policy.xlsx",
    ),
    "",
    6,
  )
  match merged_doc.blocks.val[1] {
    @cor.Block::RichTable(table) =>
      match table.hints {
        Some(hints) =>
          match hints.merged_ranges {
            Some(ranges) => assert_eq(ranges, ["B2:C2", "B3:C4", "B5:C5"])
            None => fail("merged policy should expose merged_ranges")
          }
        None => fail("merged policy should expose hints")
      }
    _ => fail("merged policy should emit RichTable")
  }

  let hidden_book = @xlsx.inspect_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_hidden_sheets_policy.xlsx",
    ),
  )
  assert_eq(hidden_book.sheets.length(), 3)
  match hidden_book.sheets[2].state {
    @xlsx.XlsxSheetState::VeryHidden => ()
    _ => fail("third sheet should be veryHidden")
  }

  let typed_book = @xlsx.inspect_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_typed_cells_matrix.xlsx",
    ),
  )
  let mut saw_string = false
  let mut saw_boolean = false
  let mut saw_error = false
  let mut saw_number = false
  for cell in typed_book.sheets[0].cells {
    match cell.semantic_type {
      @xlsx.XlsxCellSemanticType::String => saw_string = true
      @xlsx.XlsxCellSemanticType::Boolean => saw_boolean = true
      @xlsx.XlsxCellSemanticType::Error => saw_error = true
      @xlsx.XlsxCellSemanticType::Number => saw_number = true
      _ => ()
    }
  }
  assert_true(saw_string)
  assert_true(saw_boolean)
  assert_true(saw_error)
  assert_true(saw_number)
}

///|
test "xlsx metadata hints expose evaluated, unsupported, and error formula policy" {
  let eval_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_eval_if_round_text.xlsx",
    ),
    "",
    6,
  )
  match eval_doc.blocks.val[1] {
    @cor.Block::RichTable(table) =>
      match table.hints {
        Some(hints) =>
          match hints.formula_cells {
            Some(cells) => {
              assert_eq(cells.length(), 5)
              assert_eq(cells[0].reference, "D2")
              if cells[0].policy != Some("evaluated_missing_cache") {
                fail("expected evaluated_missing_cache policy on IF sample")
              }
              if cells[0].evaluated_value != Some("high") {
                fail("expected IF sample evaluated value high")
              }
              match cells[0].referenced_cells {
                Some(refs) => assert_eq(refs, ["A2"])
                None => fail("expected IF sample referenced_cells")
              }
            }
            None => fail("expected formula hints on IF/ROUND/TEXT sample")
          }
        None => fail("expected table hints on IF/ROUND/TEXT sample")
      }
    _ => fail("expected RichTable for IF/ROUND/TEXT sample")
  }

  let unsupported_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_eval_unsupported.xlsx",
    ),
    "",
    6,
  )
  match unsupported_doc.blocks.val[1] {
    @cor.Block::RichTable(table) =>
      match table.hints {
        Some(hints) =>
          match hints.formula_cells {
            Some(cells) => {
              assert_eq(cells.length(), 4)
              if cells[0].policy != Some("unsupported_formula") {
                fail("expected unsupported_formula policy for VLOOKUP")
              }
              match cells[0].unsupported_reason {
                Some(reason) =>
                  assert_true(reason.contains("unsupported function"))
                None => fail("expected unsupported reason for VLOOKUP")
              }
              if cells[1].policy != Some("unsupported_formula") {
                fail(
                  "expected unsupported_formula policy for cross-sheet formula",
                )
              }
              if cells[3].policy != Some("unsupported_formula") {
                fail(
                  "expected unsupported_formula policy for range scalar coercion",
                )
              }
              match cells[3].unsupported_reason {
                Some(reason) =>
                  assert_true(
                    reason.contains("range scalar coercion unsupported"),
                  )
                None =>
                  fail("expected unsupported reason for range scalar coercion")
              }
            }
            None => fail("expected formula hints on unsupported sample")
          }
        None => fail("expected table hints on unsupported sample")
      }
    _ => fail("expected RichTable for unsupported sample")
  }

  let error_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/xlsx_formula_eval_errors.xlsx",
    ),
    "",
    6,
  )
  match error_doc.blocks.val[1] {
    @cor.Block::RichTable(table) =>
      match table.hints {
        Some(hints) =>
          match hints.formula_cells {
            Some(cells) => {
              assert_eq(cells.length(), 5)
              if cells[0].policy != Some("formula_error") {
                fail("expected formula_error policy on division by zero cell")
              }
              if cells[0].error_reason != Some("division by zero") {
                fail("expected division by zero error reason")
              }
              if cells[2].policy != Some("formula_error") {
                fail("expected formula_error policy in error sample")
              }
              if cells[2].error_reason != Some("#N/A") {
                fail("expected #N/A error reason in formula error sample")
              }
            }
            None => fail("expected formula hints on error sample")
          }
        None => fail("expected table hints on error sample")
      }
    _ => fail("expected RichTable for error sample")
  }
}
