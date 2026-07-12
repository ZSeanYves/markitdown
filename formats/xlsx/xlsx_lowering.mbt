///|
fn xlsx_collect_package_media_assets(
  source : @input.InputSource,
  pkg : @ox.OoxmlPackage,
  diagnostics : @core.Diagnostics,
) -> (Array[@core.CoreBlock], Array[@core.AssetRef]) {
  let blocks : Array[@core.CoreBlock] = []
  let assets : Array[@core.AssetRef] = []
  let inventory = @ox.inspect_ooxml_inventory(pkg)
  let ordered_media = xlsx_drawing_media_order(pkg)
  let seen : Map[String, Bool] = Map([])
  for item in ordered_media {
    match xlsx_inventory_part(inventory.parts, item.0) {
      Some(part) => {
        xlsx_append_package_media_asset(
          source,
          part,
          Some(item.1),
          Some(item.2),
          blocks,
          assets,
          diagnostics,
        )
        seen.set(part.part_name, true)
      }
      None => ()
    }
  }
  for part in inventory.parts {
    if !part.part_name.has_prefix("xl/media/") || part.part_name.has_suffix("/") {
      continue
    }
    if seen.get(part.part_name) == Some(true) {
      continue
    }
    xlsx_append_package_media_asset(
      source,
      part,
      None,
      None,
      blocks,
      assets,
      diagnostics,
    )
  }
  if assets.length() > 0 {
    diagnostics.warnings.push(
      "xlsx images follow sheet and drawing relationship order; exact anchor placement remains partial",
    )
    diagnostics.degraded_features.push("xlsx_drawing_anchor_placement_partial")
  }
  diagnostics.metrics.set(
    "materialized_asset_count",
    assets.length().to_string(),
  )
  (blocks, assets)
}

///|
fn xlsx_append_package_media_asset(
  source : @input.InputSource,
  part : @ox.OoxmlPartInfo,
  sheet_name : String?,
  relationship_id : String?,
  blocks : Array[@core.CoreBlock],
  assets : Array[@core.AssetRef],
  diagnostics : @core.Diagnostics,
) -> Unit {
  let ext = match xlsx_media_part_ext(part.part_name) {
    Some(value) => value
    None => {
      diagnostics.warnings.push(
        "xlsx media part has unsupported asset format: " + part.part_name,
      )
      diagnostics.degraded_features.push("xlsx_media_format_unsupported")
      return
    }
  }
  let index = assets.length() + 1
  let output_path = "assets/xlsx-image" +
    xlsx_asset_two_digits(index) +
    "." +
    ext
  let source_ref = @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    source.path,
    Some("xlsx"),
    source.path,
    Some(part.part_name),
    Some(index - 1),
    Some(ext),
    None,
  )
  let asset_id = "xlsx:" + part.part_name
  let asset = @core.make_asset_ref(
    @core.AssetKind::Image,
    asset_id,
    source_ref~,
  )
  let next_asset = {
    ..asset,
    path: Some(output_path),
    mime_type: part.content_type,
  }
  next_asset.attrs.set("zip_entry_path", part.part_name)
  next_asset.attrs.set("zip_container_format", "xlsx")
  match source.path {
    Some(path) => next_asset.attrs.set("zip_container_path", path)
    None => ()
  }
  next_asset.attrs.set("alt", xlsx_media_basename(part.part_name))
  match sheet_name {
    Some(value) => next_asset.attrs.set("sheet", value)
    None => ()
  }
  match relationship_id {
    Some(value) => next_asset.attrs.set("relationship_id", value)
    None => ()
  }
  assets.push(next_asset)
  let block = @core.make_block(@core.BlockKind::Image, "", source_ref~)
  block.attrs.set("asset_id", asset_id)
  block.attrs.set("path", output_path)
  block.attrs.set("alt", xlsx_media_basename(part.part_name))
  match sheet_name {
    Some(value) => block.attrs.set("sheet", value)
    None => ()
  }
  match relationship_id {
    Some(value) => block.attrs.set("relationship_id", value)
    None => ()
  }
  blocks.push(block)
}

///|
fn xlsx_inventory_part(
  parts : Array[@ox.OoxmlPartInfo],
  path : String,
) -> @ox.OoxmlPartInfo? {
  for part in parts {
    if part.part_name == path {
      return Some(part)
    }
  }
  None
}

///|
fn xlsx_drawing_media_order(
  pkg : @ox.OoxmlPackage,
) -> Array[(String, String, String)] {
  let ordered : Array[(String, String, String)] = []
  let shared = xlsx_load_workbook_shared_state(pkg) catch {
    _ => return ordered
  }
  for sheet in shared.sheet_infos {
    let sheet_rels = @ox.read_part_relationships(pkg, sheet.part_name) catch {
      _ => continue
    }
    for drawing_rel in sheet_rels {
      if drawing_rel.target_mode == @ox.OoxmlTargetMode::External ||
        !drawing_rel.rel_type.contains("relationships/drawing") {
        continue
      }
      let drawing_xml = @ox.read_part_text(pkg, drawing_rel.resolved_target) catch {
        _ => continue
      }
      let drawing_rels = @ox.read_part_relationships(
        pkg,
        drawing_rel.resolved_target,
      ) catch {
        _ => continue
      }
      let mut offset = 0
      while true {
        let start = match xlsx_find_sub(drawing_xml, "r:embed=\"", offset) {
          Some(value) => value + "r:embed=\"".length()
          None => break
        }
        let end_ = match xlsx_find_sub(drawing_xml, "\"", start) {
          Some(value) => value
          None => break
        }
        let id = drawing_xml[start:end_].to_owned()
        for rel in drawing_rels {
          if rel.id == id &&
            rel.target_mode != @ox.OoxmlTargetMode::External &&
            rel.rel_type.contains("relationships/image") {
            ordered.push((rel.resolved_target, sheet.sheet_name, id))
            break
          }
        }
        offset = end_ + 1
      }
    }
  }
  ordered
}

///|
fn xlsx_media_part_ext(path : String) -> String? {
  let lower = path.to_lower()
  for ext in ["png", "jpg", "jpeg", "gif", "webp", "svg"] {
    if lower.has_suffix("." + ext) {
      return Some(if ext == "jpeg" { "jpg" } else { ext })
    }
  }
  None
}

///|
fn xlsx_media_basename(path : String) -> String {
  path.split("/").to_array().last().unwrap_or(path).to_owned()
}

///|
fn xlsx_asset_two_digits(value : Int) -> String {
  if value < 10 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

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
          false,
          false,
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

  if !sparse_rows && sheet.tables.length() > 0 {
    xlsx_append_sheet_table_regions(blocks, source_name, sheet)
    xlsx_append_sheet_comments(blocks, source_name, sheet)
    return
  }

  xlsx_append_sheet_grid_table(blocks, source_name, sheet, sparse_rows)
  xlsx_append_sheet_comments(blocks, source_name, sheet)
}

///|
fn xlsx_append_sheet_table_regions(
  blocks : Array[@core.CoreBlock],
  source_name : String,
  sheet : XlsxSheet,
) -> Unit {
  let covered : Map[String, Bool] = Map([])
  let mut emitted = false
  for table_def in sheet.tables {
    match xlsx_build_sheet_table_block(source_name, sheet, table_def, covered) {
      Some(table) => {
        xlsx_append_region_spacer(blocks, emitted, table)
        match table_def.display_name {
          Some(name) =>
            if name.trim() != "" && name.trim() != sheet.sheet_name {
              let heading = @core.make_block(
                @core.BlockKind::Heading,
                name,
                source_ref=table.source_ref.unwrap_or(@core.empty_source_ref()),
              )
              heading.attrs.set("level", "3")
              blocks.push(heading)
            }
          None => ()
        }
        blocks.push(table)
        emitted = true
      }
      None => ()
    }
  }
  let residual_ranges = xlsx_collect_residual_sheet_ranges(sheet, covered)
  let mut residual_index = 0
  while residual_index < residual_ranges.length() {
    let (min_row, min_col, max_row, max_col) = residual_ranges[residual_index]
    let region_ref = xlsx_range_ref_from_bounds(
      min_row, min_col, max_row, max_col,
    )
    let region_name = xlsx_residual_region_display_name(
      sheet,
      residual_index,
      residual_ranges.length(),
    )
    match
      xlsx_build_table_block_from_bounds(
        source_name,
        sheet,
        min_row,
        min_col,
        max_row,
        max_col,
        xlsx_sheet_table_region_source_ref(
          source_name,
          sheet,
          region_ref,
          relationship_id=None,
          table_part_name=None,
          table_name=None,
          display_name=Some(region_name),
          column_names=[],
        ),
        sparse_rows=false,
      ) {
      Some(table) => {
        xlsx_append_region_spacer(blocks, emitted, table)
        if region_name != sheet.sheet_name {
          let heading = @core.make_block(
            @core.BlockKind::Heading,
            region_name,
            source_ref=table.source_ref.unwrap_or(@core.empty_source_ref()),
          )
          heading.attrs.set("level", "3")
          blocks.push(heading)
        }
        blocks.push(table)
        emitted = true
      }
      None => ()
    }
    residual_index += 1
  }
  if !emitted {
    xlsx_append_sheet_grid_table(blocks, source_name, sheet, false)
  }
}

///|
fn xlsx_build_sheet_table_block(
  source_name : String,
  sheet : XlsxSheet,
  table_def : XlsxSheetTable,
  covered : Map[String, Bool],
) -> @core.CoreBlock? {
  match xlsx_parse_range_ref(table_def.range_ref) {
    Some((min_row, min_col, max_row, max_col)) =>
      xlsx_build_table_block_from_bounds(
        source_name,
        sheet,
        min_row,
        min_col,
        max_row,
        max_col,
        xlsx_sheet_table_region_source_ref(
          source_name,
          sheet,
          table_def.range_ref,
          relationship_id=Some(table_def.relationship_id),
          table_part_name=Some(table_def.part_name),
          table_name=table_def.table_name,
          display_name=table_def.display_name,
          column_names=table_def.column_names,
        ),
        sparse_rows=false,
        covered=Some(covered),
      )
    None => None
  }
}

///|
fn xlsx_build_table_block_from_bounds(
  source_name : String,
  sheet : XlsxSheet,
  min_row : Int,
  min_col : Int,
  max_row : Int,
  max_col : Int,
  table_ref : @core.SourceRef,
  sparse_rows? : Bool = false,
  covered? : Map[String, Bool]? = None,
) -> @core.CoreBlock? {
  let table = @core.make_block(
    @core.BlockKind::Table,
    "table",
    source_ref=table_ref,
  )
  table.attrs.set("header_rows", "1")
  table.attrs.set("table_column_count", (max_col - min_col + 1).to_string())
  if sheet.include_merge_layout {
    table.attrs.set("render_html_table", "true")
  }
  let mut row = min_row
  while row <= max_row {
    if xlsx_should_skip_hidden_row(
        sheet.include_hidden_rows,
        sheet.hidden_rows,
        row,
      ) {
      row += 1
      continue
    }
    let row_ref = if min_row == sheet.min_row &&
      min_col == sheet.min_col &&
      max_row == sheet.max_row &&
      max_col == sheet.max_col {
      xlsx_row_source_ref(source_name, sheet, row)
    } else {
      @core.source_ref_with_extra(table_ref, "row_index", row.to_string())
    }
    let row_block = @core.make_block(
      @core.BlockKind::TableRow,
      "",
      source_ref=row_ref,
    )
    let sparse_row_payload = StringBuilder::new()
    let mut sparse_row_payload_has_entry = false
    if sparse_rows {
      row_block.attrs.set("sparse_cell_columns", "true")
      row_block.attrs.set(
        "declared_column_count",
        (max_col - min_col + 1).to_string(),
      )
    }
    let mut col = min_col
    while col <= max_col {
      let key = xlsx_lookup_key(row, col)
      let merge_range = sheet.merged_lookup.get(key)
      if sheet.include_merge_layout &&
        xlsx_should_skip_merged_placeholder_cell(merge_range, row, col) {
        col += 1
        continue
      }
      match sheet.cell_lookup.get(key) {
        Some(cell) =>
          if sparse_rows {
            ignore(merge_range)
            if !xlsx_is_blank_text(cell.display_text) ||
              cell.formula_text is Some(_) {
              xlsx_write_sparse_row_payload_entry(
                sparse_row_payload,
                col,
                cell.display_text,
                sparse_row_payload_has_entry,
              )
              sparse_row_payload_has_entry = true
            }
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
            let cell_block0 = @core.make_block(
              @core.BlockKind::TableCell,
              cell.display_text,
              source_ref~,
            )
            let cell_block = xlsx_apply_cell_rich_content(
              cell_block0, cell, source_ref,
            )
            xlsx_apply_merge_attrs(cell_block, merge_range, row, col)
            row_block.children.push(cell_block)
          }
        None =>
          if !sparse_rows {
            let cell_ref = xlsx_rc_to_cell_ref(row, col)
            let source_ref = xlsx_blank_cell_source_ref(
              source_name, sheet, cell_ref, row, col, merge_range,
            )
            let cell_block = @core.make_block(
              @core.BlockKind::TableCell,
              "",
              source_ref~,
            )
            xlsx_apply_merge_attrs(cell_block, merge_range, row, col)
            row_block.children.push(cell_block)
          } else {
            ignore(merge_range)
          }
      }
      match covered {
        Some(marked) => marked.set(key, true)
        None => ()
      }
      col += 1
    }
    row_block.attrs.set("sparse_row_payload", sparse_row_payload.to_string())
    table.children.push(row_block)
    row += 1
  }
  if table.children.length() == 0 {
    None
  } else {
    Some(table)
  }
}

///|
fn xlsx_append_sheet_grid_table(
  blocks : Array[@core.CoreBlock],
  source_name : String,
  sheet : XlsxSheet,
  sparse_rows : Bool,
) -> Unit {
  match
    xlsx_build_table_block_from_bounds(
      source_name,
      sheet,
      sheet.min_row,
      sheet.min_col,
      sheet.max_row,
      sheet.max_col,
      xlsx_sheet_table_source_ref(source_name, sheet),
      sparse_rows~,
    ) {
    Some(table) => blocks.push(table)
    None => ()
  }
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
    if xlsx_should_skip_hidden_row(
        sheet.include_hidden_rows,
        sheet.hidden_rows,
        row,
      ) {
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
fn xlsx_append_region_spacer(
  blocks : Array[@core.CoreBlock],
  emitted : Bool,
  table : @core.CoreBlock,
) -> Unit {
  if !emitted {
    return
  }
  let spacer = @core.make_block(
    @core.BlockKind::Raw,
    "",
    source_ref=table.source_ref.unwrap_or(@core.empty_source_ref()),
  )
  spacer.attrs.set("raw_kind", "markdown_literal")
  blocks.push(spacer)
}

///|
fn xlsx_sheet_table_region_source_ref(
  source_name : String,
  sheet : XlsxSheet,
  range_ref : String,
  relationship_id? : String? = None,
  table_part_name? : String? = None,
  table_name? : String? = None,
  display_name? : String? = None,
  column_names? : Array[String] = [],
) -> @core.SourceRef {
  let mut source_ref = @core.source_ref_with_extra(
    xlsx_sheet_table_source_ref(source_name, sheet),
    "cell_range",
    range_ref,
  )
  match relationship_id {
    Some(value) =>
      source_ref = @core.source_ref_with_extra(
        source_ref, "relationship_id", value,
      )
    None => ()
  }
  match table_part_name {
    Some(value) =>
      source_ref = @core.source_ref_with_extra(source_ref, "table_part", value)
    None => ()
  }
  match table_name {
    Some(value) =>
      source_ref = @core.source_ref_with_extra(source_ref, "table_name", value)
    None => ()
  }
  match display_name {
    Some(value) =>
      if value.trim() != "" {
        source_ref = @core.source_ref_with_extra(
          source_ref, "table_display_name", value,
        )
      }
    None => ()
  }
  if column_names.length() > 0 {
    source_ref = @core.source_ref_with_extra(
      source_ref,
      "table_columns",
      column_names.join("|"),
    )
  }
  source_ref
}

///|
fn xlsx_collect_residual_sheet_ranges(
  sheet : XlsxSheet,
  covered : Map[String, Bool],
) -> Array[(Int, Int, Int, Int)] {
  let buckets : Array[(Int, Int)] = []
  let mut row = sheet.min_row
  while row <= sheet.max_row {
    if xlsx_should_skip_hidden_row(
        sheet.include_hidden_rows,
        sheet.hidden_rows,
        row,
      ) {
      row += 1
      continue
    }
    let mut col = sheet.min_col
    let mut active_start = -1
    let mut active_end = -1
    while col <= sheet.max_col {
      if xlsx_residual_cell_exists(sheet, covered, row, col) {
        if active_start < 0 {
          active_start = col
        }
        active_end = col
      } else if active_start >= 0 {
        xlsx_push_residual_range_bucket(buckets, active_start, active_end)
        active_start = -1
        active_end = -1
      }
      col += 1
    }
    if active_start >= 0 {
      xlsx_push_residual_range_bucket(buckets, active_start, active_end)
    }
    row += 1
  }
  xlsx_residual_bucket_map_to_ranges(sheet, covered, buckets)
}

///|
fn xlsx_push_residual_range_bucket(
  buckets : Array[(Int, Int)],
  start_col : Int,
  end_col : Int,
) -> Unit {
  for bucket in buckets {
    if bucket.0 == start_col && bucket.1 == end_col {
      return
    }
  }
  buckets.push((start_col, end_col))
}

///|
fn xlsx_residual_bucket_map_to_ranges(
  sheet : XlsxSheet,
  covered : Map[String, Bool],
  buckets : Array[(Int, Int)],
) -> Array[(Int, Int, Int, Int)] {
  let keyed : Array[(Int, Int)] = []
  keyed.append(buckets[:])
  keyed.sort_by(fn(a, b) {
    let primary = a.0.compare(b.0)
    if primary != 0 {
      primary
    } else {
      a.1.compare(b.1)
    }
  })
  let ranges : Array[(Int, Int, Int, Int)] = []
  let mut i = 0
  while i < keyed.length() {
    let start_col = keyed[i].0
    let end_col = keyed[i].1
    let mut min_row = -1
    let mut max_row = -1
    let mut row = sheet.min_row
    while row <= sheet.max_row {
      if xlsx_should_skip_hidden_row(
          sheet.include_hidden_rows,
          sheet.hidden_rows,
          row,
        ) {
        row += 1
        continue
      }
      if xlsx_residual_range_row_has_content(
          sheet, covered, row, start_col, end_col,
        ) {
        if min_row < 0 {
          min_row = row
        }
        max_row = row
      }
      row += 1
    }
    if min_row > 0 && max_row >= min_row {
      ranges.push((min_row, start_col, max_row, end_col))
    }
    i += 1
  }
  ranges
}

///|
fn xlsx_residual_cell_exists(
  sheet : XlsxSheet,
  covered : Map[String, Bool],
  row : Int,
  col : Int,
) -> Bool {
  let key = xlsx_lookup_key(row, col)
  if covered.get(key) == Some(true) {
    return false
  }
  match sheet.cell_lookup.get(key) {
    Some(cell) =>
      !xlsx_is_blank_text(cell.display_text) || cell.formula_text is Some(_)
    None => false
  }
}

///|
fn xlsx_residual_range_row_has_content(
  sheet : XlsxSheet,
  covered : Map[String, Bool],
  row : Int,
  start_col : Int,
  end_col : Int,
) -> Bool {
  let mut col = start_col
  while col <= end_col {
    if xlsx_residual_cell_exists(sheet, covered, row, col) {
      return true
    }
    col += 1
  }
  false
}

///|
fn xlsx_residual_region_display_name(
  sheet : XlsxSheet,
  residual_index : Int,
  residual_count : Int,
) -> String {
  if residual_count <= 1 {
    sheet.sheet_name
  } else {
    sheet.sheet_name + " Region " + (residual_index + 1).to_string()
  }
}

///|
fn xlsx_range_ref_from_bounds(
  min_row : Int,
  min_col : Int,
  max_row : Int,
  max_col : Int,
) -> String {
  xlsx_rc_to_cell_ref(min_row, min_col) +
  ":" +
  xlsx_rc_to_cell_ref(max_row, max_col)
}

///|
fn xlsx_should_skip_hidden_row(
  include_hidden_rows : Bool,
  hidden_rows : Map[Int, Bool],
  row_index : Int,
) -> Bool {
  !include_hidden_rows && xlsx_row_is_hidden(hidden_rows, row_index)
}

///|
fn xlsx_should_skip_merged_placeholder_cell(
  merge_range : String?,
  row_index : Int,
  column_index : Int,
) -> Bool {
  match merge_range {
    Some(range_ref) =>
      match xlsx_parse_range_ref(range_ref) {
        Some((r1, c1, _, _)) => row_index != r1 || column_index != c1
        None => false
      }
    None => false
  }
}

///|
fn xlsx_apply_merge_attrs(
  cell_block : @core.CoreBlock,
  merge_range : String?,
  row_index : Int,
  column_index : Int,
) -> Unit {
  match merge_range {
    Some(range_ref) =>
      match xlsx_parse_range_ref(range_ref) {
        Some((r1, c1, r2, c2)) =>
          if row_index == r1 && column_index == c1 {
            let rowspan = r2 - r1 + 1
            let colspan = c2 - c1 + 1
            if rowspan > 1 {
              cell_block.attrs.set("rowspan", rowspan.to_string())
            }
            if colspan > 1 {
              cell_block.attrs.set("colspan", colspan.to_string())
            }
            cell_block.attrs.set("merge_range", range_ref)
          }
        None => ()
      }
    None => ()
  }
}

///|
fn xlsx_apply_cell_rich_content(
  cell_block : @core.CoreBlock,
  cell : XlsxCell,
  source_ref : @core.SourceRef,
) -> @core.CoreBlock {
  match cell.hyperlink_target {
    Some(target) =>
      if cell.display_text.trim() != "" && target.trim() != "" {
        let link_ref = match cell.hyperlink_relationship_id {
          Some(rel_id) =>
            @core.source_ref_with_extra(source_ref, "relationship_id", rel_id)
          None => source_ref
        }
        return @core.block_with_rich_inlines(
          cell_block,
          Some([
            @core.make_inline_link(
              cell.display_text,
              target,
              source_ref=link_ref,
            ),
          ]),
        )
      }
    None => ()
  }
  cell_block
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
