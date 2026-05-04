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
