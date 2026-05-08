///|
/// XLSX lower-layer aware parser (MoonBit)
///
/// Product policy:
/// - cached values are used when present
/// - a lightweight evaluator is only used for safe missing-cache formulas
/// - merged ranges are detected but not visually reconstructed
/// - hidden sheets are emitted in workbook order
/// - output remains conservative heading + table lowering
pub fn parse_xlsx(
  input_path : String,
  _out_dir : String,
  max_heading : Int,
) -> @cor.Document raise {
  parse_xlsx_with_profile(input_path, _out_dir, max_heading).0
}

///|
pub fn inspect_xlsx(input_path : String) -> XlsxWorkbookModel raise {
  let (workbook, _) = inspect_xlsx_with_profile(input_path)
  workbook
}

///|
pub fn parse_xlsx_with_profile(
  input_path : String,
  _out_dir : String,
  max_heading : Int,
) -> (@cor.Document, XlsxProfileReport?) raise {
  let (workbook, profile) = inspect_xlsx_with_profile(input_path)
  let build_started = @env.now()
  let doc = build_xlsx_document(workbook, max_heading)
  xlsx_profile_push_stage(
    profile,
    "ir_lowering",
    @env.now() - build_started,
    Some("blocks=" + doc.blocks.val.length().to_string()),
  )
  (doc, profile)
}

///|
pub fn inspect_xlsx_with_profile(
  input_path : String,
) -> (XlsxWorkbookModel, XlsxProfileReport?) raise {
  let profile = if xlsx_profile_enabled() {
    Some(new_xlsx_profile_report(input_path))
  } else {
    None
  }

  let semantic_started = @env.now()
  let semantic = @dpxlsx.open_xlsx_workbook(input_path) catch {
    e =>
      raise @cor.AppError(
        "xlsx: semantic workbook parse failed: " + e.to_string(),
      )
  }
  xlsx_profile_push_stage(
    profile,
    "semantic_workbook_parse",
    @env.now() - semantic_started,
    Some(
      "sheets=" +
      semantic.sheets.length().to_string() +
      " shared_strings=" +
      semantic.shared_strings.length().to_string(),
    ),
  )

  let workbook = compat_workbook_model_from_semantic(
    @cor.basename(input_path),
    semantic,
  )
  for sheet in workbook.sheets {
    xlsx_profile_record_sheet(profile, sheet)
  }
  (workbook, profile)
}

///|
fn build_xlsx_document(
  workbook : XlsxWorkbookModel,
  max_heading : Int,
) -> @cor.Document {
  let doc = @cor.new_document()
  let src = workbook.source_name

  if workbook.sheets.length() == 0 {
    @cor.push_with_origin(
      doc,
      @cor.Block::Paragraph("(no sheets found)"),
      Some({
        source_name: Some(src),
        page: None,
        slide: None,
        sheet: None,
        block_index: Some(doc.blocks.val.length()),
        heading_path: None,
        line_start: None,
        line_end: None,
        row_index: None,
        column_index: None,
        object_ref: None,
        relationship_id: None,
        key_path: None,
      }),
    )
    return doc
  }

  for sheet in workbook.sheets {
    push_sheet_blocks(doc, src, sheet, max_heading)
  }

  doc
}

///|
fn push_sheet_blocks(
  doc : @cor.Document,
  src : String,
  sheet : XlsxSheetModel,
  max_heading : Int,
) -> Unit {
  @cor.push_with_origin(
    doc,
    @cor.Block::Heading(clamp_heading(2, max_heading), sheet.name),
    Some({
      source_name: Some(src),
      page: None,
      slide: None,
      sheet: Some(sheet.name),
      block_index: Some(doc.blocks.val.length()),
      heading_path: None,
      line_start: None,
      line_end: None,
      row_index: None,
      column_index: None,
      object_ref: None,
      relationship_id: sheet.relationship_id,
      key_path: None,
    }),
  )

  if !sheet.is_supported_worksheet {
    @cor.push_with_origin(
      doc,
      @cor.Block::Paragraph("(unsupported sheet type)"),
      Some({
        source_name: Some(src),
        page: None,
        slide: None,
        sheet: Some(sheet.name),
        block_index: Some(doc.blocks.val.length()),
        heading_path: None,
        line_start: None,
        line_end: None,
        row_index: None,
        column_index: None,
        object_ref: None,
        relationship_id: sheet.relationship_id,
        key_path: None,
      }),
    )
  } else if !sheet.has_sheet_xml {
    @cor.push_with_origin(
      doc,
      @cor.Block::Paragraph(
        "(missing sheet xml: " + sheet.part_target.unwrap_or("") + ")",
      ),
      Some({
        source_name: Some(src),
        page: None,
        slide: None,
        sheet: Some(sheet.name),
        block_index: Some(doc.blocks.val.length()),
        heading_path: None,
        line_start: None,
        line_end: None,
        row_index: None,
        column_index: None,
        object_ref: None,
        relationship_id: sheet.relationship_id,
        key_path: None,
      }),
    )
  } else if sheet.table_rows.length() == 0 {
    @cor.push_with_origin(
      doc,
      @cor.Block::Paragraph("(empty sheet)"),
      Some({
        source_name: Some(src),
        page: None,
        slide: None,
        sheet: Some(sheet.name),
        block_index: Some(doc.blocks.val.length()),
        heading_path: None,
        line_start: None,
        line_end: None,
        row_index: None,
        column_index: None,
        object_ref: None,
        relationship_id: sheet.relationship_id,
        key_path: None,
      }),
    )
  } else {
    @cor.push_with_origin(
      doc,
      @cor.Block::RichTable({
        rows: sheet.table_rows,
        header_rows: sheet.header_rows,
        hints: Some(sheet_table_hints(sheet)),
      }),
      Some({
        source_name: Some(src),
        page: None,
        slide: None,
        sheet: Some(sheet.name),
        block_index: Some(doc.blocks.val.length()),
        heading_path: None,
        line_start: Some(sheet.used_min_row),
        line_end: Some(sheet.used_max_row),
        row_index: Some(sheet.used_min_row),
        column_index: Some(sheet.used_min_col),
        object_ref: None,
        relationship_id: sheet.relationship_id,
        key_path: None,
      }),
    )
  }

  @cor.push_with_origin(
    doc,
    @cor.Block::BlankLine,
    Some({
      source_name: Some(src),
      page: None,
      slide: None,
      sheet: Some(sheet.name),
      block_index: Some(doc.blocks.val.length()),
      heading_path: None,
      line_start: None,
      line_end: None,
      row_index: None,
      column_index: None,
      object_ref: None,
      relationship_id: sheet.relationship_id,
      key_path: None,
    }),
  )
}

///|
fn sheet_table_hints(sheet : XlsxSheetModel) -> @cor.TableHints {
  let merged_ranges = if sheet.merged_ranges.length() == 0 {
    None
  } else {
    let out : Array[String] = []
    for range_ in sheet.merged_ranges {
      out.push(range_.range_ref)
    }
    Some(out)
  }

  let formula_cells = sheet_formula_hints(sheet)
  let semantic_types = sheet_semantic_type_matrix(sheet)
  {
    format: Some("xlsx"),
    sheet_state: Some(sheet_state_string(sheet.state)),
    merged_ranges,
    formula_cells,
    semantic_types,
    span_cells: None,
  }
}

///|
fn sheet_state_string(state : XlsxSheetState) -> String {
  match state {
    XlsxSheetState::Visible => "visible"
    XlsxSheetState::Hidden => "hidden"
    XlsxSheetState::VeryHidden => "veryHidden"
  }
}

///|
fn sheet_formula_hints(sheet : XlsxSheetModel) -> Array[@cor.TableFormulaHint]? {
  let out : Array[@cor.TableFormulaHint] = []
  for cell in sheet.cells {
    match cell.formula_text {
      Some(text) =>
        if text.trim() != "" {
          out.push({
            reference: cell.reference,
            row_index: cell.row,
            column_index: cell.column,
            formula_text: text,
            cached_value: cell.source_value,
            display_text: cell.display_text,
            cell_kind: xlsx_cell_kind_string(cell.kind),
            semantic_type: xlsx_semantic_type_string(cell.semantic_type),
            policy: xlsx_formula_policy_string(cell.formula_trace),
            evaluated_value: xlsx_formula_evaluated_value(cell.formula_trace),
            unsupported_reason: xlsx_formula_unsupported_reason(
              cell.formula_trace,
            ),
            error_reason: xlsx_formula_error_reason(cell.formula_trace),
            referenced_cells: xlsx_formula_referenced_cells(cell.formula_trace),
            referenced_ranges: xlsx_formula_referenced_ranges(
              cell.formula_trace,
            ),
          })
        }
      None => ()
    }
  }
  if out.length() == 0 {
    None
  } else {
    Some(out)
  }
}

///|
fn xlsx_formula_policy_string(trace : XlsxFormulaTrace?) -> String? {
  match trace {
    Some(v) =>
      Some(
        match v.policy {
          XlsxFormulaPolicy::Cached => "cached"
          XlsxFormulaPolicy::EvaluatedMissingCache => "evaluated_missing_cache"
          XlsxFormulaPolicy::UnsupportedFormula => "unsupported_formula"
          XlsxFormulaPolicy::FormulaError => "formula_error"
        },
      )
    None => None
  }
}

///|
fn xlsx_formula_evaluated_value(trace : XlsxFormulaTrace?) -> String? {
  match trace {
    Some(v) => v.evaluated_value
    None => None
  }
}

///|
fn xlsx_formula_unsupported_reason(trace : XlsxFormulaTrace?) -> String? {
  match trace {
    Some(v) => v.unsupported_reason
    None => None
  }
}

///|
fn xlsx_formula_error_reason(trace : XlsxFormulaTrace?) -> String? {
  match trace {
    Some(v) => v.error_reason
    None => None
  }
}

///|
fn xlsx_formula_referenced_cells(trace : XlsxFormulaTrace?) -> Array[String]? {
  match trace {
    Some(v) => v.referenced_cells
    None => None
  }
}

///|
fn xlsx_formula_referenced_ranges(trace : XlsxFormulaTrace?) -> Array[String]? {
  match trace {
    Some(v) => v.referenced_ranges
    None => None
  }
}

///|
fn sheet_semantic_type_matrix(sheet : XlsxSheetModel) -> Array[Array[String]]? {
  if sheet.table_rows.length() == 0 {
    return None
  }

  let mut max_col = 0
  for row in sheet.table_rows {
    if row.length() > max_col {
      max_col = row.length()
    }
  }
  if max_col == 0 {
    return None
  }

  let lookup : Map[String, String] = Map::new()
  for cell in sheet.cells {
    lookup.set(
      cell.row.to_string() + "," + cell.column.to_string(),
      xlsx_semantic_type_string(cell.semantic_type),
    )
  }

  let out : Array[Array[String]] = []
  for row_offset in 0..<sheet.table_rows.length() {
    let row : Array[String] = []
    let actual_row = sheet.used_min_row + row_offset
    for col_offset in 0..<max_col {
      let actual_col = sheet.used_min_col + col_offset
      row.push(
        lookup
        .get(actual_row.to_string() + "," + actual_col.to_string())
        .unwrap_or("blank"),
      )
    }
    out.push(row)
  }
  Some(out)
}

///|
fn xlsx_cell_kind_string(kind : XlsxCellKind) -> String {
  match kind {
    XlsxCellKind::SharedString => "shared_string"
    XlsxCellKind::InlineString => "inline_string"
    XlsxCellKind::Boolean => "boolean"
    XlsxCellKind::StringResult => "string_result"
    XlsxCellKind::Error => "error"
    XlsxCellKind::Number => "number"
    XlsxCellKind::Blank => "blank"
  }
}

///|
fn xlsx_semantic_type_string(kind : XlsxCellSemanticType) -> String {
  match kind {
    XlsxCellSemanticType::String => "string"
    XlsxCellSemanticType::Number => "number"
    XlsxCellSemanticType::Boolean => "boolean"
    XlsxCellSemanticType::Date => "date"
    XlsxCellSemanticType::DateTime => "datetime"
    XlsxCellSemanticType::Time => "time"
    XlsxCellSemanticType::Blank => "blank"
    XlsxCellSemanticType::Error => "error"
    XlsxCellSemanticType::FormulaCachedValue => "formula_cached_value"
    XlsxCellSemanticType::FormulaMissingCache => "formula_missing_cache"
  }
}
