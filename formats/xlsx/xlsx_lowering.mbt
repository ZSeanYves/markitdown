///|
fn xlsx_lower_block_stream_document(
  source : @input.InputSource,
  pkg : @ox.OoxmlPackage,
  diagnostics : @core.Diagnostics,
  context : @parser.ParseContext,
) -> XlsxLoweringResult raise @ox.OoxmlError {
  let shared = xlsx_load_workbook_shared_state(pkg)
  let max_rows = context.max_rows.unwrap_or(2000)
  let max_cols = context.max_cols.unwrap_or(50)
  let max_cells = context.max_cells.unwrap_or(100000)
  let max_sheets = 200

  let effective_sheet_infos = if shared.sheet_infos.length() > max_sheets {
    diagnostics.warnings.push(
      "xlsx sheet count exceeded limit; remaining sheets were skipped",
    )
    diagnostics.degraded_features.push("xlsx_sheets_truncated")
    diagnostics.metrics.set("resource_limit_hit", "true")
    diagnostics.same_mode_degradation.push("xlsx_sheet_window_truncated")
    shared.sheet_infos[:max_sheets]
  } else {
    shared.sheet_infos[:]
  }

  let metadata : @core.DocumentMetadata = Map([])
  let blocks : Array[@core.CoreBlock] = []
  metadata.set("source_name", @core.JsonValue::String(source.source_name))
  metadata.set("format", @core.JsonValue::String("xlsx"))
  metadata.set("workbook_part", @core.JsonValue::String(shared.workbook_part))
  metadata.set(
    "sheet_count",
    @core.JsonValue::Number(effective_sheet_infos.length().to_string()),
  )
  let mut visible_sheet_count = 0
  let mut hidden_sheet_count = 0
  let mut very_hidden_sheet_count = 0
  let mut row_count = 0
  let mut cell_count = 0
  let mut non_empty_cell_count = 0
  let mut merged_cell_count = 0
  let mut formula_count = 0
  let mut shared_formula_count = 0
  let mut array_formula_count = 0
  let mut drawing_count = 0
  let mut image_count = 0
  let mut external_link_count = 0

  for sheet_info in effective_sheet_infos {
    match sheet_info.visibility {
      @shared.XlsxSheetVisibility::Visible => {
        visible_sheet_count += 1
        let sheet = xlsx_parse_sheet_view(
          pkg,
          sheet_info,
          shared.shared_strings,
          shared.styles,
          shared.uses_date_1904,
          max_rows,
          max_cols,
          max_cells,
          diagnostics,
          build_cell_source_refs=false,
          prefer_streaming_scan=true,
        )
        row_count += sheet.row_count
        cell_count += sheet.cell_count
        non_empty_cell_count += sheet.non_empty_cell_count
        merged_cell_count += xlsx_merged_cell_area(sheet.merged_ranges)
        formula_count += sheet.formula_count
        shared_formula_count += sheet.shared_formula_count
        array_formula_count += sheet.array_formula_count
        drawing_count += sheet.drawing_count
        image_count += sheet.image_count
        external_link_count += sheet.external_link_count
        xlsx_append_sparse_sheet_view_blocks(blocks, source.source_name, sheet)
      }
      @shared.XlsxSheetVisibility::Hidden => {
        hidden_sheet_count += 1
        diagnostics.warnings.push(
          "hidden xlsx sheet skipped: " + sheet_info.sheet_name,
        )
        diagnostics.degraded_features.push("xlsx_hidden_sheet_skipped")
        diagnostics.same_mode_degradation.push(
          "xlsx_hidden_sheet_skipped:" + sheet_info.sheet_name,
        )
      }
      @shared.XlsxSheetVisibility::VeryHidden => {
        very_hidden_sheet_count += 1
        diagnostics.warnings.push(
          "very hidden xlsx sheet skipped: " + sheet_info.sheet_name,
        )
        diagnostics.degraded_features.push("xlsx_very_hidden_sheet_skipped")
        diagnostics.same_mode_degradation.push(
          "xlsx_very_hidden_sheet_skipped:" + sheet_info.sheet_name,
        )
      }
    }
  }
  metadata.set(
    "visible_sheet_count",
    @core.JsonValue::Number(visible_sheet_count.to_string()),
  )
  metadata.set(
    "shared_string_count",
    @core.JsonValue::Number(shared.shared_strings.length().to_string()),
  )
  diagnostics.metrics.set(
    "xlsx_sheet_count",
    effective_sheet_infos.length().to_string(),
  )
  diagnostics.metrics.set(
    "xlsx_visible_sheet_count",
    visible_sheet_count.to_string(),
  )
  diagnostics.metrics.set(
    "xlsx_hidden_sheet_count",
    hidden_sheet_count.to_string(),
  )
  diagnostics.metrics.set(
    "xlsx_very_hidden_sheet_count",
    very_hidden_sheet_count.to_string(),
  )
  diagnostics.metrics.set("xlsx_row_count", row_count.to_string())
  diagnostics.metrics.set("xlsx_cell_count", cell_count.to_string())
  diagnostics.metrics.set(
    "xlsx_non_empty_cell_count",
    non_empty_cell_count.to_string(),
  )
  diagnostics.metrics.set(
    "xlsx_merged_cell_count",
    merged_cell_count.to_string(),
  )
  diagnostics.metrics.set("xlsx_formula_count", formula_count.to_string())
  diagnostics.metrics.set(
    "xlsx_shared_formula_count",
    shared_formula_count.to_string(),
  )
  diagnostics.metrics.set(
    "xlsx_array_formula_count",
    array_formula_count.to_string(),
  )
  diagnostics.metrics.set(
    "xlsx_shared_string_count",
    shared.shared_strings.length().to_string(),
  )
  diagnostics.metrics.set(
    "xlsx_style_count",
    shared.styles.xf_numfmts.length().to_string(),
  )
  diagnostics.metrics.set("xlsx_workbook_part", shared.workbook_part)
  diagnostics.metrics.set("xlsx_drawing_count", drawing_count.to_string())
  diagnostics.metrics.set("xlsx_image_count", image_count.to_string())
  diagnostics.metrics.set(
    "external_link_count",
    external_link_count.to_string(),
  )
  { blocks, metadata, assets: [] }
}

///|
fn xlsx_lower_workbook_document(
  source : @input.InputSource,
  workbook : XlsxWorkbook,
  diagnostics : @core.Diagnostics,
) -> XlsxLoweringResult {
  let metadata : @core.DocumentMetadata = Map([])
  let blocks : Array[@core.CoreBlock] = []
  metadata.set("source_name", @core.JsonValue::String(source.source_name))
  metadata.set("format", @core.JsonValue::String("xlsx"))
  metadata.set("workbook_part", @core.JsonValue::String(workbook.workbook_part))
  metadata.set(
    "sheet_count",
    @core.JsonValue::Number(workbook.sheet_count.to_string()),
  )
  metadata.set(
    "visible_sheet_count",
    @core.JsonValue::Number(workbook.visible_sheet_count.to_string()),
  )
  metadata.set(
    "shared_string_count",
    @core.JsonValue::Number(workbook.shared_strings.length().to_string()),
  )

  for sheet in workbook.sheets {
    xlsx_append_sheet_blocks(blocks, source.source_name, sheet, false)
  }

  diagnostics.metrics.set("xlsx_sheet_count", workbook.sheet_count.to_string())
  diagnostics.metrics.set(
    "xlsx_visible_sheet_count",
    workbook.visible_sheet_count.to_string(),
  )
  diagnostics.metrics.set(
    "xlsx_hidden_sheet_count",
    workbook.hidden_sheet_count.to_string(),
  )
  diagnostics.metrics.set(
    "xlsx_very_hidden_sheet_count",
    workbook.very_hidden_sheet_count.to_string(),
  )
  diagnostics.metrics.set("xlsx_row_count", workbook.row_count.to_string())
  diagnostics.metrics.set("xlsx_cell_count", workbook.cell_count.to_string())
  diagnostics.metrics.set(
    "xlsx_non_empty_cell_count",
    workbook.non_empty_cell_count.to_string(),
  )
  diagnostics.metrics.set(
    "xlsx_merged_cell_count",
    workbook.merged_cell_count.to_string(),
  )
  diagnostics.metrics.set(
    "xlsx_formula_count",
    workbook.formula_count.to_string(),
  )
  diagnostics.metrics.set(
    "xlsx_shared_formula_count",
    workbook.shared_formula_count.to_string(),
  )
  diagnostics.metrics.set(
    "xlsx_array_formula_count",
    workbook.array_formula_count.to_string(),
  )
  diagnostics.metrics.set(
    "xlsx_shared_string_count",
    workbook.shared_strings.length().to_string(),
  )
  diagnostics.metrics.set("xlsx_style_count", workbook.style_count.to_string())
  diagnostics.metrics.set("xlsx_workbook_part", workbook.workbook_part)
  diagnostics.metrics.set(
    "xlsx_drawing_count",
    workbook.drawing_count.to_string(),
  )
  diagnostics.metrics.set("xlsx_image_count", workbook.image_count.to_string())
  diagnostics.metrics.set(
    "external_link_count",
    workbook.external_link_count.to_string(),
  )
  { blocks, metadata, assets: [] }
}

///|
fn xlsx_append_sheet_blocks(
  blocks : Array[@core.CoreBlock],
  source_name : String,
  sheet : XlsxSheet,
  sparse_rows : Bool,
) -> Unit {
  let heading_ref = xlsx_sheet_heading_source_ref(source_name, sheet)
  let heading = @core.make_block(
    @core.BlockKind::Heading,
    sheet.sheet_name,
    source_ref=heading_ref,
  )
  heading.attrs.set("level", "2")
  blocks.push(heading)

  if sheet.is_empty {
    let raw = @core.make_block(
      @core.BlockKind::Raw,
      "(empty sheet)",
      source_ref=xlsx_sheet_table_source_ref(source_name, sheet),
    )
    raw.attrs.set("raw_kind", "xlsx_empty_sheet")
    blocks.push(raw)
    return
  }

  let table = @core.make_block(
    @core.BlockKind::Table,
    "table",
    source_ref=xlsx_sheet_table_source_ref(source_name, sheet),
  )
  table.attrs.set("header_rows", "1")
  table.attrs.set(
    "table_column_count",
    (sheet.max_col - sheet.min_col + 1).to_string(),
  )

  let mut row = sheet.min_row
  while row <= sheet.max_row {
    if xlsx_row_is_hidden(sheet.hidden_rows, row) {
      row += 1
      continue
    }
    let row_block0 = @core.make_block(
      @core.BlockKind::TableRow,
      "",
      source_ref=xlsx_row_source_ref(source_name, sheet, row),
    )
    let row_block = row_block0
    let sparse_row_payload = StringBuilder::new()
    let mut sparse_row_payload_has_entry = false
    if sparse_rows {
      row_block.attrs.set("sparse_cell_columns", "true")
      row_block.attrs.set(
        "declared_column_count",
        (sheet.max_col - sheet.min_col + 1).to_string(),
      )
    }
    let mut col = sheet.min_col
    while col <= sheet.max_col {
      let key = xlsx_lookup_key(row, col)
      let merge_range = sheet.merged_lookup.get(key)
      match sheet.cell_lookup.get(key) {
        Some(cell) =>
          if sparse_rows {
            ignore(merge_range)
            xlsx_write_sparse_row_payload_entry(
              sparse_row_payload,
              col,
              cell.display_text,
              sparse_row_payload_has_entry,
            )
            sparse_row_payload_has_entry = true
          } else {
            let source_ref = match merge_range {
              Some(range_ref) =>
                @core.source_ref_with_extra(
                  cell.source_ref.unwrap_or(@core.empty_source_ref()),
                  "merge_range",
                  range_ref,
                )
              None => cell.source_ref.unwrap_or(@core.empty_source_ref())
            }
            let cell_block = @core.make_block(
              @core.BlockKind::TableCell,
              cell.display_text,
              source_ref~,
            )
            row_block.children.push(cell_block)
          }
        None =>
          if !sparse_rows {
            let cell_ref = xlsx_rc_to_cell_ref(row, col)
            let source_ref = xlsx_blank_cell_source_ref(
              source_name, sheet, cell_ref, row, col, merge_range,
            )
            row_block.children.push(
              @core.make_block(@core.BlockKind::TableCell, "", source_ref~),
            )
          } else {
            ignore(merge_range)
          }
      }
      col += 1
    }
    row_block.attrs.set("sparse_row_payload", sparse_row_payload.to_string())
    table.children.push(row_block)
    row += 1
  }
  blocks.push(table)
  xlsx_append_sheet_comments(blocks, source_name, sheet)
}

///|
fn xlsx_append_sparse_sheet_view_blocks(
  blocks : Array[@core.CoreBlock],
  source_name : String,
  sheet : XlsxParsedSheetView,
) -> Unit {
  let heading_ref = xlsx_sheet_heading_source_ref_view(source_name, sheet)
  let heading = @core.make_block(
    @core.BlockKind::Heading,
    sheet.sheet_name,
    source_ref=heading_ref,
  )
  heading.attrs.set("level", "2")
  blocks.push(heading)

  if sheet.is_empty {
    let raw = @core.make_block(
      @core.BlockKind::Raw,
      "(empty sheet)",
      source_ref=xlsx_sheet_table_source_ref_view(source_name, sheet),
    )
    raw.attrs.set("raw_kind", "xlsx_empty_sheet")
    blocks.push(raw)
    return
  }

  let table = @core.make_block(
    @core.BlockKind::Table,
    "table",
    source_ref=xlsx_sheet_table_source_ref_view(source_name, sheet),
  )
  table.attrs.set("header_rows", "1")
  table.attrs.set(
    "table_column_count",
    (sheet.max_col - sheet.min_col + 1).to_string(),
  )
  let table_ref = xlsx_sheet_table_source_ref_view(source_name, sheet)
  let mut cell_index = sheet.first_cell_index
  let cell_count = sheet.last_cell_index_exclusive
  let mut row = sheet.min_row
  while row <= sheet.max_row {
    if xlsx_row_is_hidden(sheet.hidden_rows, row) {
      row += 1
      continue
    }
    let row_block = @core.make_block(
      @core.BlockKind::TableRow,
      "",
      source_ref=@core.source_ref_with_extra(
        table_ref,
        "row_index",
        row.to_string(),
      ),
    )
    row_block.attrs.set("sparse_cell_columns", "true")
    row_block.attrs.set(
      "declared_column_count",
      (sheet.max_col - sheet.min_col + 1).to_string(),
    )
    let sparse_row_payload = StringBuilder::new()
    let mut sparse_row_payload_has_entry = false
    while cell_index < cell_count && sheet.cells[cell_index].row_index < row {
      cell_index += 1
    }
    let mut scan_index = cell_index
    while scan_index < cell_count && sheet.cells[scan_index].row_index == row {
      let cell = sheet.cells[scan_index]
      xlsx_write_sparse_row_payload_entry(
        sparse_row_payload,
        cell.column_index,
        cell.display_text,
        sparse_row_payload_has_entry,
      )
      sparse_row_payload_has_entry = true
      scan_index += 1
    }
    cell_index = scan_index
    row_block.attrs.set("sparse_row_payload", sparse_row_payload.to_string())
    table.children.push(row_block)
    row += 1
  }
  blocks.push(table)
  xlsx_append_sheet_comments_view(blocks, source_name, sheet)
}

///|
fn xlsx_write_sparse_row_payload_entry(
  out : StringBuilder,
  column_index : Int,
  text : String,
  has_entry : Bool,
) -> Unit {
  if has_entry {
    out.write_char('\n')
  }
  out.write_string(column_index.to_string())
  out.write_char('\t')
  out.write_string(xlsx_escape_sparse_row_cell(text))
}

///|
fn xlsx_escape_sparse_row_cell(text : String) -> String {
  let out : Array[Char] = []
  for ch in text.to_array() {
    if ch == '\\' {
      out.push('\\')
      out.push('\\')
    } else if ch == '\t' {
      out.push('\\')
      out.push('t')
    } else if ch == '\n' {
      out.push('\\')
      out.push('n')
    } else {
      out.push(ch)
    }
  }
  String::from_array(out)
}

///|
fn xlsx_fill_package_metrics(
  diagnostics : @core.Diagnostics,
  pkg : @ox.OoxmlPackage,
) -> Unit {
  let validation = @ox.validate_ooxml_package(pkg)
  let inventory = @ox.inspect_ooxml_inventory(pkg)
  let package_relationship_count = (@ox.read_package_relationships(pkg) catch {
    _ => []
  }).length()
  let part_relationship_count = inventory.relationship_source_parts.fold(
    init=0,
    fn(acc, source_part) {
      acc +
      (@ox.read_part_relationships(pkg, source_part) catch { _ => [] }).length()
    },
  )
  diagnostics.metrics.set("ooxml_part_count", inventory.part_count.to_string())
  diagnostics.metrics.set(
    "relationship_count",
    (package_relationship_count + part_relationship_count).to_string(),
  )
  diagnostics.metrics.set(
    "content_type_count",
    inventory.content_type_entry_count.to_string(),
  )
  diagnostics.metrics.set(
    "media_asset_count",
    count_xlsx_media_parts(inventory.parts).to_string(),
  )
  diagnostics.metrics.set(
    "external_relationship_count",
    xlsx_count_validation_kind(
      validation.issues,
      @ox.OoxmlValidationIssueKind::ExternalRelationship,
    ).to_string(),
  )
  diagnostics.metrics.set(
    "missing_relationship_target_count",
    xlsx_count_validation_kind(
      validation.issues,
      @ox.OoxmlValidationIssueKind::MissingRelationshipTarget,
    ).to_string(),
  )
  diagnostics.metrics.set("unsupported_relationship_count", "0")
  diagnostics.metrics.set("duplicate_part_count", "0")
  diagnostics.metrics.set(
    "total_uncompressed_bytes",
    xlsx_total_uncompressed_bytes(inventory.parts).to_string(),
  )
  diagnostics.metrics.set(
    "macro_part_count",
    xlsx_count_macro_parts(inventory.parts).to_string(),
  )
  diagnostics.metrics.set(
    "ole_object_count",
    xlsx_count_ole_parts(inventory.parts).to_string(),
  )
}

///|
fn xlsx_count_validation_kind(
  issues : Array[@ox.OoxmlValidationIssue],
  kind : @ox.OoxmlValidationIssueKind,
) -> Int {
  let mut count = 0
  for issue in issues {
    if issue.kind == kind {
      count += 1
    }
  }
  count
}

///|
fn xlsx_total_uncompressed_bytes(parts : Array[@ox.OoxmlPartInfo]) -> Int {
  let mut total = 0
  for part in parts {
    total += part.size
  }
  total
}

///|
fn xlsx_count_macro_parts(parts : Array[@ox.OoxmlPartInfo]) -> Int {
  let mut count = 0
  for part in parts {
    match part.content_type {
      Some(value) => if value.contains("macroEnabled") { count += 1 }
      None => ()
    }
  }
  count
}

///|
fn xlsx_count_ole_parts(parts : Array[@ox.OoxmlPartInfo]) -> Int {
  let mut count = 0
  for part in parts {
    if part.part_name.contains("/embeddings/") ||
      part.part_name.contains("oleObject") {
      count += 1
    }
  }
  count
}

///|
fn count_xlsx_media_parts(parts : Array[@ox.OoxmlPartInfo]) -> Int {
  let mut count = 0
  for part in parts {
    if part.part_name.has_prefix("xl/media/") && !part.part_name.has_suffix("/") {
      count += 1
    }
  }
  count
}

///|
fn xlsx_sheet_heading_source_ref(
  source_name : String,
  sheet : XlsxSheet,
) -> @core.SourceRef {
  let base = @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some(source_name),
    Some("xlsx"),
    Some(source_name),
    Some(sheet.part_name),
    None,
    Some("xlsx"),
    Some("/worksheet"),
  )
  let office = @core.source_ref_with_office_fields(
    base,
    Some(source_name),
    Some("xlsx"),
    Some("/worksheet"),
    Some(sheet.sheet_name),
    None,
    None,
    None,
    Some(sheet.relationship_id),
  )
  let with_sheet = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.source_ref_with_extra(
        @core.source_ref_with_extra(office, "part_name", sheet.part_name),
        "sheet_name",
        sheet.sheet_name,
      ),
      "sheet_visibility",
      @shared.xlsx_sheet_visibility_name(sheet.visibility),
    ),
    "relationship_id",
    sheet.relationship_id,
  )
  match sheet.sheet_id {
    Some(value) => @core.source_ref_with_extra(with_sheet, "sheet_id", value)
    None => with_sheet
  }
}

///|
fn xlsx_sheet_table_source_ref(
  source_name : String,
  sheet : XlsxSheet,
) -> @core.SourceRef {
  let base = @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some(source_name),
    Some("xlsx"),
    Some(source_name),
    Some(sheet.part_name),
    None,
    Some("xlsx"),
    Some("/worksheet/sheetData"),
  )
  let office = @core.source_ref_with_office_fields(
    base,
    Some(source_name),
    Some("xlsx"),
    Some("/worksheet/sheetData"),
    Some(sheet.sheet_name),
    sheet.dimension_ref,
    None,
    None,
    Some(sheet.relationship_id),
  )
  let mut with_keys = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.source_ref_with_extra(
        @core.source_ref_with_extra(office, "part_name", sheet.part_name),
        "sheet_name",
        sheet.sheet_name,
      ),
      "sheet_visibility",
      @shared.xlsx_sheet_visibility_name(sheet.visibility),
    ),
    "relationship_id",
    sheet.relationship_id,
  )
  match sheet.sheet_id {
    Some(value) =>
      with_keys = @core.source_ref_with_extra(with_keys, "sheet_id", value)
    None => ()
  }
  match sheet.dimension_ref {
    Some(value) =>
      with_keys = @core.source_ref_with_extra(with_keys, "cell_range", value)
    None => ()
  }
  if !sheet.is_empty {
    with_keys = @core.source_ref_with_extra(
      @core.source_ref_with_extra(
        with_keys,
        "row_index",
        sheet.min_row.to_string(),
      ),
      "column_index",
      sheet.min_col.to_string(),
    )
  }
  with_keys
}

///|
fn xlsx_append_sheet_comments(
  blocks : Array[@core.CoreBlock],
  source_name : String,
  sheet : XlsxSheet,
) -> Unit {
  if sheet.comments.length() == 0 {
    return
  }
  let heading = @core.make_block(
    @core.BlockKind::Heading,
    "Comments",
    source_ref=@core.source_ref_with_extra(
      xlsx_sheet_table_source_ref(source_name, sheet),
      "section",
      "comments",
    ),
  )
  heading.attrs.set("level", "3")
  blocks.push(heading)
  for comment in sheet.comments {
    let item = @core.make_block(
      @core.BlockKind::ListItem,
      xlsx_comment_item_text(comment),
      source_ref=@core.source_ref_with_extra(
        xlsx_sheet_table_source_ref(source_name, sheet),
        "cell_ref",
        comment.cell_ref,
      ),
    )
    item.attrs.set("ordered", "false")
    item.attrs.set("level", "0")
    blocks.push(item)
  }
}

///|
fn xlsx_sheet_heading_source_ref_view(
  source_name : String,
  sheet : XlsxParsedSheetView,
) -> @core.SourceRef {
  let base = @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some(source_name),
    Some("xlsx"),
    Some(source_name),
    Some(sheet.part_name),
    None,
    Some("xlsx"),
    Some("/worksheet"),
  )
  let office = @core.source_ref_with_office_fields(
    base,
    Some(source_name),
    Some("xlsx"),
    Some("/worksheet"),
    Some(sheet.sheet_name),
    None,
    None,
    None,
    Some(sheet.relationship_id),
  )
  let with_sheet = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.source_ref_with_extra(
        @core.source_ref_with_extra(office, "part_name", sheet.part_name),
        "sheet_name",
        sheet.sheet_name,
      ),
      "sheet_visibility",
      @shared.xlsx_sheet_visibility_name(sheet.visibility),
    ),
    "relationship_id",
    sheet.relationship_id,
  )
  match sheet.sheet_id {
    Some(value) => @core.source_ref_with_extra(with_sheet, "sheet_id", value)
    None => with_sheet
  }
}

///|
fn xlsx_sheet_table_source_ref_view(
  source_name : String,
  sheet : XlsxParsedSheetView,
) -> @core.SourceRef {
  let base = @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some(source_name),
    Some("xlsx"),
    Some(source_name),
    Some(sheet.part_name),
    None,
    Some("xlsx"),
    Some("/worksheet/sheetData"),
  )
  let office = @core.source_ref_with_office_fields(
    base,
    Some(source_name),
    Some("xlsx"),
    Some("/worksheet/sheetData"),
    Some(sheet.sheet_name),
    sheet.dimension_ref,
    None,
    None,
    Some(sheet.relationship_id),
  )
  let mut with_keys = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.source_ref_with_extra(
        @core.source_ref_with_extra(office, "part_name", sheet.part_name),
        "sheet_name",
        sheet.sheet_name,
      ),
      "sheet_visibility",
      @shared.xlsx_sheet_visibility_name(sheet.visibility),
    ),
    "relationship_id",
    sheet.relationship_id,
  )
  match sheet.sheet_id {
    Some(value) =>
      with_keys = @core.source_ref_with_extra(with_keys, "sheet_id", value)
    None => ()
  }
  match sheet.dimension_ref {
    Some(value) =>
      with_keys = @core.source_ref_with_extra(with_keys, "cell_range", value)
    None => ()
  }
  if !sheet.is_empty {
    with_keys = @core.source_ref_with_extra(
      @core.source_ref_with_extra(
        with_keys,
        "row_index",
        sheet.min_row.to_string(),
      ),
      "column_index",
      sheet.min_col.to_string(),
    )
  }
  with_keys
}

///|
fn xlsx_append_sheet_comments_view(
  blocks : Array[@core.CoreBlock],
  source_name : String,
  sheet : XlsxParsedSheetView,
) -> Unit {
  if sheet.comments.length() == 0 {
    return
  }
  let heading = @core.make_block(
    @core.BlockKind::Heading,
    "Comments",
    source_ref=@core.source_ref_with_extra(
      xlsx_sheet_table_source_ref_view(source_name, sheet),
      "section",
      "comments",
    ),
  )
  heading.attrs.set("level", "3")
  blocks.push(heading)
  for comment in sheet.comments {
    let item = @core.make_block(
      @core.BlockKind::ListItem,
      xlsx_comment_item_text(comment),
      source_ref=@core.source_ref_with_extra(
        xlsx_sheet_table_source_ref_view(source_name, sheet),
        "cell_ref",
        comment.cell_ref,
      ),
    )
    item.attrs.set("ordered", "false")
    item.attrs.set("level", "0")
    blocks.push(item)
  }
}

///|
