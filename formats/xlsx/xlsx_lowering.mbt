///|
fn xlsx_collect_package_media_assets(
  source : @input.InputSource,
  pkg : @ox.OoxmlPackage,
  diagnostics : @core.Diagnostics,
  context : @parser.ParseContext,
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
          context,
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
      context,
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
  context : @parser.ParseContext,
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
  let observed = part.size.to_int64()
  let materialized = xlsx_declared_asset_bytes(assets)
  if !@parser.asset_payload_within_limits(context, observed, materialized) {
    let asset_id = "xlsx:" + part.part_name
    @parser.record_asset_payload_budget_skip(
      diagnostics,
      asset_id,
      "single_or_total_asset_bytes",
      observed,
      @parser.max_asset_payload_bytes(context),
    )
    let source_ref = @core.source_ref_with_container_entry(
      @core.empty_source_ref(),
      @input.input_path(source),
      Some("xlsx"),
      @input.input_path(source),
      Some(part.part_name),
      Some(index - 1),
      Some(ext),
      None,
    )
    let unavailable = @core.make_block(
      BlockQuote,
      "Asset unavailable: " + part.part_name,
      source_ref~,
    )
    unavailable.attrs.set("asset_missing", "true")
    unavailable.attrs.set("asset_source_path", part.part_name)
    unavailable.attrs.set("payload_skipped", "asset_limit")
    blocks.push(unavailable)
    return
  }
  let output_path = "assets/xlsx-image" +
    xlsx_asset_two_digits(index) +
    "." +
    ext
  let source_ref = @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    @input.input_path(source),
    Some("xlsx"),
    @input.input_path(source),
    Some(part.part_name),
    Some(index - 1),
    Some(ext),
    None,
  )
  let asset_id = "xlsx:" + part.part_name
  let asset = @core.make_asset_ref(Image, asset_id, source_ref~)
  let next_asset = {
    ..asset,
    path: Some(output_path),
    mime_type: part.content_type,
  }
  next_asset.attrs.set("zip_entry_path", part.part_name)
  next_asset.attrs.set("zip_container_format", "xlsx")
  match @input.input_path(source) {
    Some(path) => next_asset.attrs.set("zip_container_path", path)
    None => ()
  }
  next_asset.attrs.set("alt", xlsx_media_basename(part.part_name))
  next_asset.attrs.set("declared_asset_bytes", part.size.to_string())
  match sheet_name {
    Some(value) => next_asset.attrs.set("sheet", value)
    None => ()
  }
  match relationship_id {
    Some(value) => next_asset.attrs.set("relationship_id", value)
    None => ()
  }
  assets.push(next_asset)
  let block = @core.make_block(Image, "", source_ref~)
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
fn xlsx_declared_asset_bytes(assets : Array[@core.AssetRef]) -> Int64 {
  let mut total = 0L
  for asset in assets {
    match asset.attrs.get("declared_asset_bytes") {
      Some(raw) => total += (@string.parse_int(raw) catch { _ => 0 }).to_int64()
      None => ()
    }
  }
  total
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
      if drawing_rel.target_mode == External ||
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
            rel.target_mode != External &&
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
  metadata.set("source_name", String(source.source_name))
  metadata.set("format", String("xlsx"))
  metadata.set("workbook_part", String(shared.workbook_part))
  metadata.set(
    "sheet_count",
    Number(effective_sheet_infos.length().to_string()),
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
      Visible => {
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
      Hidden => {
        hidden_sheet_count += 1
        diagnostics.warnings.push(
          "hidden xlsx sheet skipped: " + sheet_info.sheet_name,
        )
        diagnostics.degraded_features.push("xlsx_hidden_sheet_skipped")
        diagnostics.same_mode_degradation.push(
          "xlsx_hidden_sheet_skipped:" + sheet_info.sheet_name,
        )
      }
      VeryHidden => {
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
  metadata.set("visible_sheet_count", Number(visible_sheet_count.to_string()))
  metadata.set(
    "shared_string_count",
    Number(shared.shared_strings.length().to_string()),
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
  metadata.set("source_name", String(source.source_name))
  metadata.set("format", String("xlsx"))
  metadata.set("workbook_part", String(workbook.workbook_part))
  metadata.set("sheet_count", Number(workbook.sheet_count.to_string()))
  metadata.set(
    "visible_sheet_count",
    Number(workbook.visible_sheet_count.to_string()),
  )
  metadata.set(
    "shared_string_count",
    Number(workbook.shared_strings.length().to_string()),
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
  let heading = xlsx_trim_lowered_block_text(
    @core.make_block(Heading, sheet.sheet_name, source_ref=heading_ref),
  )
  heading.attrs.set("level", "2")
  blocks.push(heading)

  if sheet.is_empty {
    let raw = @core.make_block(
      Raw,
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
                Heading,
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
            Heading,
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
  let table = @core.make_block(Table, "table", source_ref=table_ref)
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
    let row_block = @core.make_block(TableRow, "", source_ref=row_ref)
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
              let source_ref = cell.source_ref
              let cell_block = xlsx_apply_cell_rich_content(
                match source_ref {
                  Some(value) =>
                    @core.make_block(
                      TableCell,
                      cell.display_text,
                      source_ref=value,
                    )
                  None =>
                    @core.make_block_without_source_ref(
                      TableCell,
                      cell.display_text,
                    )
                },
                cell,
                source_ref,
              )
              row_block.children.push(
                @core.block_with_column_index(cell_block, col - min_col + 1),
              )
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
              TableCell,
              cell.display_text,
              source_ref~,
            )
            let cell_block = xlsx_apply_cell_rich_content(
              cell_block0,
              cell,
              Some(source_ref),
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
            let cell_block = @core.make_block(TableCell, "", source_ref~)
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
