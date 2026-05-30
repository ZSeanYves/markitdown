///|
priv struct MetadataTableBlock {
  rows : Array[Array[String]]
  header_rows : Int
  format : String?
  sheet_state : String?
  merged_ranges : Array[String]?
  formula_cells : Array[MetadataFormulaCell]?
  semantic_types : Array[Array[String]]?
  span_cells : Array[MetadataTableSpanCell]?
}

///|
priv struct MetadataTableSpanCell {
  row_index : Int
  column_index : Int
  rowspan : Int
  colspan : Int
  text : String?
}

///|
priv struct MetadataFormulaCell {
  reference : String
  row_index : Int
  column_index : Int
  formula_text : String
  cached_value : String?
  display_text : String
  cell_kind : String
  semantic_type : String
  policy : String?
  evaluated_value : String?
  unsupported_reason : String?
  error_reason : String?
  referenced_cells : Array[String]?
  referenced_ranges : Array[String]?
}

///|
fn rich_table_metadata_block(table : TableData) -> MetadataTableBlock {
  let (
    format,
    sheet_state,
    merged_ranges,
    formula_cells,
    semantic_types,
    span_cells,
  ) = match table.hints {
    None => (None, None, None, None, None, None)
    Some(hints) =>
      (
        hints.format,
        hints.sheet_state,
        hints.merged_ranges,
        metadata_formula_cells(hints.formula_cells),
        hints.semantic_types,
        metadata_span_cells(hints.span_cells),
      )
  }

  {
    rows: table.rows,
    header_rows: table.header_rows,
    format,
    sheet_state,
    merged_ranges,
    formula_cells,
    semantic_types,
    span_cells,
  }
}

///|
fn serialize_table_block(table : MetadataTableBlock) -> String {
  let fields : Array[String] = []

  fields.push("\"rows\": " + serialize_string_matrix(table.rows))
  fields.push("\"header_rows\": " + table.header_rows.to_string())
  meta_push_json_string_field(fields, "format", table.format)
  meta_push_json_string_field(fields, "sheet_state", table.sheet_state)
  meta_push_json_string_array_field(
    fields,
    "merged_ranges",
    table.merged_ranges,
  )
  push_json_formula_cells_field(fields, "formula_cells", table.formula_cells)
  meta_push_json_string_matrix_field(
    fields,
    "semantic_types",
    table.semantic_types,
  )
  push_json_span_cells_field(fields, "span_cells", table.span_cells)

  "{\n" + meta_indent_lines(meta_join_json_fields(fields), 2) + "\n}"
}

///|
fn push_json_table_field(
  fields : Array[String],
  name : String,
  value : MetadataTableBlock?,
) -> Unit {
  match value {
    Some(v) => fields.push("\"" + name + "\": " + serialize_table_block(v))
    None => ()
  }
}

///|
fn metadata_span_cells(
  hints : Array[TableSpanHint]?,
) -> Array[MetadataTableSpanCell]? {
  match hints {
    None => None
    Some(arr) => {
      let out : Array[MetadataTableSpanCell] = []
      for hint in arr {
        out.push({
          row_index: hint.row_index,
          column_index: hint.column_index,
          rowspan: hint.rowspan,
          colspan: hint.colspan,
          text: hint.text,
        })
      }
      Some(out)
    }
  }
}

///|
fn metadata_formula_cells(
  hints : Array[TableFormulaHint]?,
) -> Array[MetadataFormulaCell]? {
  match hints {
    None => None
    Some(arr) => {
      let out : Array[MetadataFormulaCell] = []
      for hint in arr {
        out.push({
          reference: hint.reference,
          row_index: hint.row_index,
          column_index: hint.column_index,
          formula_text: hint.formula_text,
          cached_value: hint.cached_value,
          display_text: hint.display_text,
          cell_kind: hint.cell_kind,
          semantic_type: hint.semantic_type,
          policy: hint.policy,
          evaluated_value: hint.evaluated_value,
          unsupported_reason: hint.unsupported_reason,
          error_reason: hint.error_reason,
          referenced_cells: hint.referenced_cells,
          referenced_ranges: hint.referenced_ranges,
        })
      }
      Some(out)
    }
  }
}

///|
fn serialize_string_matrix(rows : Array[Array[String]]) -> String {
  let parts : Array[String] = []
  for row in rows {
    parts.push(serialize_string_array(row))
  }
  "[\n" + meta_indent_lines(meta_join_json_items(parts), 2) + "\n]"
}

///|
fn meta_push_json_string_matrix_field(
  fields : Array[String],
  name : String,
  value : Array[Array[String]]?,
) -> Unit {
  match value {
    Some(v) => fields.push("\"" + name + "\": " + serialize_string_matrix(v))
    None => ()
  }
}

///|
fn push_json_formula_cells_field(
  fields : Array[String],
  name : String,
  value : Array[MetadataFormulaCell]?,
) -> Unit {
  match value {
    Some(v) => fields.push("\"" + name + "\": " + serialize_formula_cells(v))
    None => ()
  }
}

///|
fn push_json_span_cells_field(
  fields : Array[String],
  name : String,
  value : Array[MetadataTableSpanCell]?,
) -> Unit {
  match value {
    Some(v) => fields.push("\"" + name + "\": " + serialize_span_cells(v))
    None => ()
  }
}

///|
fn serialize_span_cells(cells : Array[MetadataTableSpanCell]) -> String {
  let parts : Array[String] = []
  for cell in cells {
    parts.push(serialize_span_cell(cell))
  }
  "[\n" + meta_indent_lines(meta_join_json_items(parts), 2) + "\n]"
}

///|
fn serialize_span_cell(cell : MetadataTableSpanCell) -> String {
  let fields : Array[String] = []
  fields.push("\"row_index\": " + cell.row_index.to_string())
  fields.push("\"column_index\": " + cell.column_index.to_string())
  fields.push("\"rowspan\": " + cell.rowspan.to_string())
  fields.push("\"colspan\": " + cell.colspan.to_string())
  meta_push_json_string_field(fields, "text", cell.text)
  "{\n" + meta_indent_lines(meta_join_json_fields(fields), 2) + "\n}"
}

///|
fn serialize_formula_cells(cells : Array[MetadataFormulaCell]) -> String {
  let parts : Array[String] = []
  for cell in cells {
    parts.push(serialize_formula_cell(cell))
  }
  "[\n" + meta_indent_lines(meta_join_json_items(parts), 2) + "\n]"
}

///|
fn serialize_formula_cell(cell : MetadataFormulaCell) -> String {
  let fields : Array[String] = []
  fields.push("\"reference\": " + meta_json_string(cell.reference))
  fields.push("\"row_index\": " + cell.row_index.to_string())
  fields.push("\"column_index\": " + cell.column_index.to_string())
  fields.push("\"formula_text\": " + meta_json_string(cell.formula_text))
  fields.push("\"cached_value\": " + meta_json_string_opt(cell.cached_value))
  fields.push("\"display_text\": " + meta_json_string(cell.display_text))
  fields.push("\"cell_kind\": " + meta_json_string(cell.cell_kind))
  fields.push("\"semantic_type\": " + meta_json_string(cell.semantic_type))
  meta_push_json_string_field(fields, "policy", cell.policy)
  meta_push_json_string_field(fields, "evaluated_value", cell.evaluated_value)
  meta_push_json_string_field(
    fields,
    "unsupported_reason",
    cell.unsupported_reason,
  )
  meta_push_json_string_field(fields, "error_reason", cell.error_reason)
  meta_push_json_string_array_field(
    fields,
    "referenced_cells",
    cell.referenced_cells,
  )
  meta_push_json_string_array_field(
    fields,
    "referenced_ranges",
    cell.referenced_ranges,
  )
  "{\n" + meta_indent_lines(meta_join_json_fields(fields), 2) + "\n}"
}
