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
  let defined_names = compat_defined_names_from_semantic(workbook.defined_names)
  let unsupported_features = compat_unsupported_features_from_semantic(
    workbook.unsupported_features,
  )
  let sheets : Array[XlsxSheetModel] = []
  for sheet in workbook.sheets {
    sheets.push(compat_sheet_model_from_semantic(sheet, defined_names))
  }
  {
    source_name,
    metadata: compat_workbook_metadata_from_semantic(workbook.metadata),
    uses_date_1904: workbook.uses_date_1904,
    defined_names,
    unsupported_features,
    sheets,
  }
}

///|
fn compat_workbook_metadata_from_semantic(
  metadata : @dpxlsx.XlsxWorkbookMetadata,
) -> XlsxWorkbookMetadata {
  {
    core: {
      title: metadata.core.title,
      subject: metadata.core.subject,
      creator: metadata.core.creator,
      last_modified_by: metadata.core.last_modified_by,
      created: metadata.core.created,
      modified: metadata.core.modified,
      keywords: metadata.core.keywords,
      description: metadata.core.description,
      category: metadata.core.category,
    },
    app: {
      company: metadata.app.company,
      manager: metadata.app.manager,
      application: metadata.app.application,
      pages: metadata.app.pages,
      words: metadata.app.words,
      slides: metadata.app.slides,
      sheets: metadata.app.sheets,
    },
    custom_properties: compat_custom_properties_from_semantic(
      metadata.custom_properties,
    ),
  }
}

///|
fn compat_custom_properties_from_semantic(
  props : Array[@dpxlsx.XlsxCustomProperty],
) -> Array[XlsxCustomProperty] {
  let out : Array[XlsxCustomProperty] = []
  for prop in props {
    out.push({ name: prop.name, value: prop.value, value_type: prop.value_type })
  }
  out
}

///|
fn compat_sheet_model_from_semantic(
  sheet : @dpxlsx.XlsxSheet,
  workbook_defined_names : Array[XlsxDefinedName],
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
    hyperlinks: compat_hyperlinks_from_semantic(sheet.hyperlinks),
    tables: compat_tables_from_semantic(sheet.tables),
    defined_names: sheet_defined_names_for_compat(
      workbook_defined_names,
      sheet.name,
    ),
    unsupported_features: compat_unsupported_features_from_semantic(
      sheet.unsupported_features,
    ),
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
fn sheet_defined_names_for_compat(
  defined_names : Array[XlsxDefinedName],
  sheet_name : String,
) -> Array[XlsxDefinedName] {
  let out : Array[XlsxDefinedName] = []
  for name in defined_names {
    if name.sheet_scope == Some(sheet_name) ||
      name.target_sheet == Some(sheet_name) {
      out.push(name)
    }
  }
  out
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
    hyperlink: compat_hyperlink_from_semantic(cell.hyperlink),
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
fn compat_tables_from_semantic(
  tables : Array[@dpxlsx.XlsxTable],
) -> Array[XlsxTable] {
  let out : Array[XlsxTable] = []
  for table in tables {
    out.push({
      table_id: table.table_id,
      name: table.name,
      display_name: table.display_name,
      style_name: table.style_name,
      auto_filter_ref: table.auto_filter_ref,
      header_row_visible: table.header_row_visible,
      totals_row_visible: table.totals_row_visible,
      range_ref: table.range_ref,
      start_row: table.start_row,
      start_col: table.start_col,
      end_row: table.end_row,
      end_col: table.end_col,
      header_row_count: table.header_row_count,
      totals_row_count: table.totals_row_count,
      column_names: copy_string_array(table.column_names),
      columns: compat_table_columns_from_semantic(table.columns),
      sheet_name: table.sheet_name,
      source_part: table.source_part,
      relationship_id: table.relationship_id,
    })
  }
  out
}

///|
fn compat_table_columns_from_semantic(
  columns : Array[@dpxlsx.XlsxTableColumn],
) -> Array[XlsxTableColumn] {
  let out : Array[XlsxTableColumn] = []
  for column in columns {
    out.push({
      column_id: column.column_id,
      name: column.name,
      totals_row_function: column.totals_row_function,
      totals_row_label: column.totals_row_label,
    })
  }
  out
}

///|
fn compat_defined_names_from_semantic(
  defined_names : Array[@dpxlsx.XlsxDefinedName],
) -> Array[XlsxDefinedName] {
  let out : Array[XlsxDefinedName] = []
  for defined_name in defined_names {
    out.push({
      name: defined_name.name,
      text: defined_name.text,
      sheet_scope: defined_name.sheet_scope,
      sheet_scope_index: defined_name.sheet_scope_index,
      kind: compat_defined_name_kind_from_semantic(defined_name.kind),
      target_sheet: defined_name.target_sheet,
      target_range: defined_name.target_range,
      hidden: defined_name.hidden,
      source: defined_name.source,
    })
  }
  out
}

///|
fn compat_defined_name_kind_from_semantic(
  kind : @dpxlsx.XlsxDefinedNameKind,
) -> XlsxDefinedNameKind {
  match kind {
    @dpxlsx.XlsxDefinedNameKind::NamedRange => XlsxDefinedNameKind::NamedRange
    @dpxlsx.XlsxDefinedNameKind::PrintArea => XlsxDefinedNameKind::PrintArea
    @dpxlsx.XlsxDefinedNameKind::AutoFilter => XlsxDefinedNameKind::AutoFilter
    @dpxlsx.XlsxDefinedNameKind::FormulaLike => XlsxDefinedNameKind::FormulaLike
    @dpxlsx.XlsxDefinedNameKind::Unknown => XlsxDefinedNameKind::Unknown
  }
}

///|
fn compat_unsupported_features_from_semantic(
  features : Array[@dpxlsx.XlsxUnsupportedFeature],
) -> Array[XlsxUnsupportedFeature] {
  let out : Array[XlsxUnsupportedFeature] = []
  for feature in features {
    out.push({
      kind: compat_unsupported_feature_kind_from_semantic(feature.kind),
      severity: compat_validation_severity_string(feature.severity),
      sheet_name: feature.sheet_name,
      relationship_id: feature.relationship_id,
      part_target: feature.part_target,
      source: feature.source,
      message: feature.message,
    })
  }
  out
}

///|
fn compat_unsupported_feature_kind_from_semantic(
  kind : @dpxlsx.XlsxUnsupportedFeatureKind,
) -> XlsxUnsupportedFeatureKind {
  match kind {
    @dpxlsx.XlsxUnsupportedFeatureKind::Drawing =>
      XlsxUnsupportedFeatureKind::Drawing
    @dpxlsx.XlsxUnsupportedFeatureKind::Chart =>
      XlsxUnsupportedFeatureKind::Chart
    @dpxlsx.XlsxUnsupportedFeatureKind::Image =>
      XlsxUnsupportedFeatureKind::Image
    @dpxlsx.XlsxUnsupportedFeatureKind::PivotTable =>
      XlsxUnsupportedFeatureKind::PivotTable
    @dpxlsx.XlsxUnsupportedFeatureKind::VbaMacro =>
      XlsxUnsupportedFeatureKind::VbaMacro
    @dpxlsx.XlsxUnsupportedFeatureKind::OleObject =>
      XlsxUnsupportedFeatureKind::OleObject
    @dpxlsx.XlsxUnsupportedFeatureKind::ExternalLink =>
      XlsxUnsupportedFeatureKind::ExternalLink
    @dpxlsx.XlsxUnsupportedFeatureKind::ThreadedComment =>
      XlsxUnsupportedFeatureKind::ThreadedComment
    @dpxlsx.XlsxUnsupportedFeatureKind::SheetProtection =>
      XlsxUnsupportedFeatureKind::SheetProtection
    @dpxlsx.XlsxUnsupportedFeatureKind::WorkbookProtection =>
      XlsxUnsupportedFeatureKind::WorkbookProtection
    @dpxlsx.XlsxUnsupportedFeatureKind::Unknown =>
      XlsxUnsupportedFeatureKind::Unknown
  }
}

///|
fn compat_validation_severity_string(
  severity : @dpxlsx.XlsxValidationSeverity,
) -> String {
  match severity {
    @dpxlsx.XlsxValidationSeverity::Warning => "warning"
    @dpxlsx.XlsxValidationSeverity::Error => "error"
  }
}

///|
fn copy_string_array(values : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for value in values {
    out.push(value)
  }
  out
}

///|
fn compat_hyperlinks_from_semantic(
  hyperlinks : Array[@dpxlsx.XlsxHyperlink],
) -> Array[XlsxHyperlink] {
  let out : Array[XlsxHyperlink] = []
  for hyperlink in hyperlinks {
    out.push(compat_hyperlink_from_semantic_value(hyperlink))
  }
  out
}

///|
fn compat_hyperlink_from_semantic(
  hyperlink : @dpxlsx.XlsxHyperlink?,
) -> XlsxHyperlink? {
  match hyperlink {
    Some(value) => Some(compat_hyperlink_from_semantic_value(value))
    None => None
  }
}

///|
fn compat_hyperlink_from_semantic_value(
  hyperlink : @dpxlsx.XlsxHyperlink,
) -> XlsxHyperlink {
  {
    reference: hyperlink.reference,
    start_row: hyperlink.start_row,
    start_col: hyperlink.start_col,
    end_row: hyperlink.end_row,
    end_col: hyperlink.end_col,
    relationship_id: hyperlink.relationship_id,
    target: hyperlink.target,
    location: hyperlink.location,
    tooltip: hyperlink.tooltip,
    display: hyperlink.display,
    kind: compat_hyperlink_kind_from_semantic(hyperlink.kind),
    warning: hyperlink.warning,
  }
}

///|
fn compat_hyperlink_kind_from_semantic(
  kind : @dpxlsx.XlsxHyperlinkKind,
) -> XlsxHyperlinkKind {
  match kind {
    @dpxlsx.XlsxHyperlinkKind::External => XlsxHyperlinkKind::External
    @dpxlsx.XlsxHyperlinkKind::Internal => XlsxHyperlinkKind::Internal
    @dpxlsx.XlsxHyperlinkKind::Unknown => XlsxHyperlinkKind::Unknown
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
      xlsx_cell_table_text(cell),
    )
  }
  render_sheet_rows(cell_texts, hidden_rows, min_r, min_c, max_r, max_c)
}

///|
fn xlsx_cell_table_text(cell : XlsxCellModel) -> String {
  match cell.hyperlink {
    Some(link) =>
      match xlsx_hyperlink_markdown_target(link) {
        Some(target) => {
          let label = xlsx_hyperlink_label(cell, link)
          if label == "" {
            cell.display_text
          } else {
            "[" +
            escape_xlsx_markdown_link_text(label) +
            "](" +
            escape_xlsx_markdown_link_target(target) +
            ")"
          }
        }
        None => cell.display_text
      }
    None => cell.display_text
  }
}

///|
fn xlsx_hyperlink_label(cell : XlsxCellModel, link : XlsxHyperlink) -> String {
  if cell.display_text.trim() != "" {
    cell.display_text
  } else {
    match link.display {
      Some(display) => display
      None =>
        match link.target {
          Some(target) => target
          None => link.location.unwrap_or("")
        }
    }
  }
}

///|
fn xlsx_hyperlink_markdown_target(link : XlsxHyperlink) -> String? {
  match link.kind {
    XlsxHyperlinkKind::External => link.target
    XlsxHyperlinkKind::Internal =>
      match link.location {
        Some(location) =>
          if location.has_prefix("#") {
            Some(location)
          } else {
            Some("#" + location)
          }
        None => link.target
      }
    XlsxHyperlinkKind::Unknown => link.target
  }
}

///|
fn escape_xlsx_markdown_link_text(text : String) -> String {
  text
  .replace(old="\\", new="\\\\")
  .replace(old="[", new="\\[")
  .replace(old="]", new="\\]")
}

///|
fn escape_xlsx_markdown_link_target(target : String) -> String {
  target.replace(old=" ", new="%20").replace(old=")", new="%29")
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
