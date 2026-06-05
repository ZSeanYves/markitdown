///|
fn clamp_heading(level : Int, max_h : Int) -> Int {
  if level < 1 {
    1
  } else if level > max_h {
    max_h
  } else {
    level
  }
}

///|
fn compat_workbook_model_from_semantic(
  source_name : String,
  workbook : @dpxlsx.XlsxWorkbook,
) -> XlsxWorkbookModel {
  let sheets : Array[XlsxSheetModel] = []
  for sheet in workbook.sheets {
    sheets.push(compat_sheet_model_from_semantic(sheet))
  }
  { source_name, uses_date_1904: workbook.uses_date_1904, sheets }
}

///|
fn compat_sheet_model_from_semantic(
  sheet : @dpxlsx.XlsxSheet,
) -> XlsxSheetModel {
  let cells = compat_cells_from_semantic(sheet.cells)
  let hidden_rows = copy_hidden_rows(sheet.hidden_rows)
  let (rows, row_numbers) = render_sheet_rows_from_cells(
    cells,
    hidden_rows,
    sheet.used_min_row,
    sheet.used_min_col,
    sheet.used_max_row,
    sheet.used_max_col,
  )
  {
    name: sheet.name,
    relationship_id: sheet.relationship_id,
    relationship_type: sheet.relationship_type,
    part_target: sheet.part_target,
    state: compat_sheet_state_from_semantic(sheet.state),
    is_supported_worksheet: sheet.is_supported_worksheet,
    has_sheet_xml: sheet.has_sheet_xml,
    cells,
    merged_ranges: compat_merged_ranges_from_semantic(sheet.merged_ranges),
    comments: compat_comments_from_semantic(sheet.comments),
    hidden_rows,
    table_rows: rows,
    table_row_numbers: row_numbers,
    header_rows: xlsx_header_rows(rows),
    used_min_row: sheet.used_min_row,
    used_min_col: sheet.used_min_col,
    used_max_row: sheet.used_max_row,
    used_max_col: sheet.used_max_col,
  }
}

///|
fn compat_comments_from_semantic(
  comments : Array[@dpxlsx.XlsxComment],
) -> Array[XlsxComment] {
  let out : Array[XlsxComment] = []
  for comment in comments {
    out.push({
      reference: comment.reference,
      row: comment.row,
      column: comment.column,
      author_name: comment.author_name,
      text: comment.text,
    })
  }
  out
}

///|
fn copy_hidden_rows(rows : Array[Int]) -> Array[Int] {
  let out : Array[Int] = []
  for row in rows {
    out.push(row)
  }
  out
}

///|
fn compat_cells_from_semantic(
  cells : Array[@dpxlsx.XlsxCell],
) -> Array[XlsxCellModel] {
  let out : Array[XlsxCellModel] = []
  for cell in cells {
    out.push(compat_cell_from_semantic(cell))
  }
  out
}

///|
fn compat_cell_from_semantic(cell : @dpxlsx.XlsxCell) -> XlsxCellModel {
  {
    reference: cell.reference,
    row: cell.row,
    column: cell.column,
    kind: compat_cell_kind_from_semantic(cell.kind),
    display_text: cell.display_text,
    source_value: cell.source_value,
    formula_text: cell.formula_text,
    semantic_type: compat_semantic_type_from_semantic(cell.semantic_type),
    style_index: cell.style_index,
    num_format_id: cell.num_format_id,
    formula_trace: compat_formula_trace_from_semantic(cell.formula_trace),
  }
}

///|
fn compat_formula_trace_from_semantic(
  trace : @dpxlsx.XlsxFormulaTrace?,
) -> XlsxFormulaTrace? {
  match trace {
    Some(value) =>
      Some({
        policy: compat_formula_policy_from_semantic(value.policy),
        evaluated_value: value.evaluated_value,
        unsupported_reason: value.unsupported_reason,
        error_reason: value.error_reason,
        referenced_cells: value.referenced_cells,
        referenced_ranges: value.referenced_ranges,
      })
    None => None
  }
}

///|
fn compat_merged_ranges_from_semantic(
  ranges : Array[@dpxlsx.XlsxMergedRange],
) -> Array[XlsxMergedRange] {
  let out : Array[XlsxMergedRange] = []
  for range_ in ranges {
    out.push({
      range_ref: range_.range_ref,
      start_row: range_.start_row,
      start_col: range_.start_col,
      end_row: range_.end_row,
      end_col: range_.end_col,
    })
  }
  out
}

///|
fn compat_sheet_state_from_semantic(
  state : @dpxlsx.XlsxSheetState,
) -> XlsxSheetState {
  match state {
    @dpxlsx.XlsxSheetState::Visible => XlsxSheetState::Visible
    @dpxlsx.XlsxSheetState::Hidden => XlsxSheetState::Hidden
    @dpxlsx.XlsxSheetState::VeryHidden => XlsxSheetState::VeryHidden
  }
}

///|
fn compat_cell_kind_from_semantic(kind : @dpxlsx.XlsxCellKind) -> XlsxCellKind {
  match kind {
    @dpxlsx.XlsxCellKind::SharedString => XlsxCellKind::SharedString
    @dpxlsx.XlsxCellKind::InlineString => XlsxCellKind::InlineString
    @dpxlsx.XlsxCellKind::Boolean => XlsxCellKind::Boolean
    @dpxlsx.XlsxCellKind::StringResult => XlsxCellKind::StringResult
    @dpxlsx.XlsxCellKind::Error => XlsxCellKind::Error
    @dpxlsx.XlsxCellKind::Number => XlsxCellKind::Number
    @dpxlsx.XlsxCellKind::Blank => XlsxCellKind::Blank
  }
}

///|
fn compat_semantic_type_from_semantic(
  semantic_type : @dpxlsx.XlsxCellSemanticType,
) -> XlsxCellSemanticType {
  match semantic_type {
    @dpxlsx.XlsxCellSemanticType::String => XlsxCellSemanticType::String
    @dpxlsx.XlsxCellSemanticType::Number => XlsxCellSemanticType::Number
    @dpxlsx.XlsxCellSemanticType::Boolean => XlsxCellSemanticType::Boolean
    @dpxlsx.XlsxCellSemanticType::Date => XlsxCellSemanticType::Date
    @dpxlsx.XlsxCellSemanticType::DateTime => XlsxCellSemanticType::DateTime
    @dpxlsx.XlsxCellSemanticType::Time => XlsxCellSemanticType::Time
    @dpxlsx.XlsxCellSemanticType::Blank => XlsxCellSemanticType::Blank
    @dpxlsx.XlsxCellSemanticType::Error => XlsxCellSemanticType::Error
    @dpxlsx.XlsxCellSemanticType::FormulaCachedValue =>
      XlsxCellSemanticType::FormulaCachedValue
    @dpxlsx.XlsxCellSemanticType::FormulaMissingCache =>
      XlsxCellSemanticType::FormulaMissingCache
  }
}

///|
fn compat_formula_policy_from_semantic(
  policy : @dpxlsx.XlsxFormulaPolicy,
) -> XlsxFormulaPolicy {
  match policy {
    @dpxlsx.XlsxFormulaPolicy::Cached => XlsxFormulaPolicy::Cached
    @dpxlsx.XlsxFormulaPolicy::EvaluatedMissingCache =>
      XlsxFormulaPolicy::EvaluatedMissingCache
    @dpxlsx.XlsxFormulaPolicy::UnsupportedFormula =>
      XlsxFormulaPolicy::UnsupportedFormula
    @dpxlsx.XlsxFormulaPolicy::FormulaError => XlsxFormulaPolicy::FormulaError
  }
}

///|
fn render_sheet_rows_from_cells(
  cells : Array[XlsxCellModel],
  hidden_rows : Array[Int],
  min_r : Int,
  min_c : Int,
  max_r : Int,
  max_c : Int,
) -> (Array[Array[String]], Array[Int]) {
  if xlsx_dense_sheet_guard_triggered(min_r, min_c, max_r, max_c) {
    return ([], [])
  }

  let cell_texts : Map[String, String] = Map([])
  for cell in cells {
    cell_texts.set(
      cell.row.to_string() + "," + cell.column.to_string(),
      cell.display_text,
    )
  }
  render_sheet_rows(cell_texts, hidden_rows, min_r, min_c, max_r, max_c)
}

///|
fn xlsx_dense_sheet_area_cap() -> Int {
  1_000_000
}

///|
fn xlsx_sparse_preview_cell_cap() -> Int {
  100
}

///|
fn xlsx_dense_sheet_guard_triggered(
  min_r : Int,
  min_c : Int,
  max_r : Int,
  max_c : Int,
) -> Bool {
  if max_r == 0 || max_c == 0 || max_r < min_r || max_c < min_c {
    return false
  }

  let rows = max_r - min_r + 1
  let cols = max_c - min_c + 1
  let cap = xlsx_dense_sheet_area_cap()
  rows > cap / cols
}

///|
fn xlsx_dense_sheet_area_string(
  min_r : Int,
  min_c : Int,
  max_r : Int,
  max_c : Int,
) -> String {
  if max_r == 0 || max_c == 0 || max_r < min_r || max_c < min_c {
    return "0"
  }

  ((max_r - min_r + 1) * (max_c - min_c + 1)).to_string()
}

///|
fn render_sheet_rows(
  cells : Map[String, String],
  hidden_rows : Array[Int],
  min_r : Int,
  min_c : Int,
  max_r : Int,
  max_c : Int,
) -> (Array[Array[String]], Array[Int]) {
  if max_r == 0 || max_c == 0 || max_r < min_r || max_c < min_c {
    return ([], [])
  }

  let hidden_lookup : Map[String, Bool] = Map([])
  for row in hidden_rows {
    hidden_lookup.set(row.to_string(), true)
  }

  let table0 : Array[Array[String]] = []
  let row_numbers0 : Array[Int] = []
  for r in min_r..<(max_r + 1) {
    if hidden_lookup.get(r.to_string()).unwrap_or(false) {
      continue
    }
    let row : Array[String] = []
    for c in min_c..<(max_c + 1) {
      let k = r.to_string() + "," + c.to_string()
      row.push(cells.get(k).unwrap_or(""))
    }
    table0.push(trim_row_right(row))
    row_numbers0.push(r)
  }

  let (table1, row_numbers1) = trim_table_bottom_with_row_numbers(
    table0, row_numbers0,
  )
  (normalize_table_width(table1), row_numbers1)
}

///|
fn xlsx_header_rows(rows : Array[Array[String]]) -> Int {
  if rows.length() == 0 {
    0
  } else {
    1
  }
}

///|
fn trim_row_right(row : Array[String]) -> Array[String] {
  let mut end = row.length()

  while end > 0 {
    if @cor.trim_string(row[end - 1]) == "" {
      end = end - 1
    } else {
      break
    }
  }

  let out : Array[String] = []
  for i in 0..<end {
    out.push(row[i])
  }
  out
}

///|
fn trim_table_bottom(table : Array[Array[String]]) -> Array[Array[String]] {
  let mut end = table.length()

  while end > 0 {
    if row_is_blank(table[end - 1]) {
      end = end - 1
    } else {
      break
    }
  }

  let out : Array[Array[String]] = []
  for i in 0..<end {
    out.push(table[i])
  }
  out
}

///|
fn trim_table_bottom_with_row_numbers(
  table : Array[Array[String]],
  row_numbers : Array[Int],
) -> (Array[Array[String]], Array[Int]) {
  let trimmed = trim_table_bottom(table)
  let out_rows : Array[Int] = []
  for i in 0..<trimmed.length() {
    out_rows.push(row_numbers[i])
  }
  (trimmed, out_rows)
}

///|
fn row_is_blank(row : Array[String]) -> Bool {
  for cell in row {
    if @cor.trim_string(cell) != "" {
      return false
    }
  }
  true
}

///|
fn rightmost_nonblank_col(row : Array[String]) -> Int {
  let mut end = row.length()
  while end > 0 {
    if @cor.trim_string(row[end - 1]) == "" {
      end = end - 1
    } else {
      break
    }
  }
  end
}

///|
fn normalize_table_width(table : Array[Array[String]]) -> Array[Array[String]] {
  let mut width = 0

  for row in table {
    let w = rightmost_nonblank_col(row)
    if w > width {
      width = w
    }
  }

  let out : Array[Array[String]] = []
  for row in table {
    let trimmed = trim_row_right(row)
    let new_row : Array[String] = []
    for cell in trimmed {
      new_row.push(cell)
    }
    while new_row.length() < width {
      new_row.push("")
    }
    out.push(new_row)
  }

  out
}
