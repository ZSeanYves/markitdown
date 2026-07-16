///|
const ODS_PARSER_NAME : String = "ods_parser"

///|
const ODS_MAX_MATERIALIZED_ROW_REPEAT : Int = 10_000

///|
pub fn ods_parser_capability() -> @parser.ParserCapability {
  @parser.package_with_block_route_parser_capability(
    Row,
    true,
    true,
    false,
    true,
    false,
    true,
    true,
    false,
    true,
    false,
  )
}

///|
pub fn ods_parser() -> @parser.Parser {
  let capability = ods_parser_capability()
  @parser.make_parser(ODS_PARSER_NAME, PackageSinglePass, capability, fn(
    source : @input.InputSource,
    context : @parser.ParseContext,
  ) -> Result[@parser.ParseResult, String] {
    parse_ods_document_result(source, context, capability)
  })
}

///|
fn parse_ods_document_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
  capability : @parser.ParserCapability,
) -> Result[@parser.ParseResult, String] {
  let prepared = match @dodf.prepare_ods_document_from_source(source) {
    Ok(value) => value
    Err(err) => {
      let diagnostics = @fshared.empty_parser_diagnostics(
        ODS_PARSER_NAME,
        PackageSinglePass,
        source,
        "ods",
      )
      ods_init_diagnostics(diagnostics, source, context)
      return Ok(
        ods_malformed_parse_result(
          source,
          diagnostics,
          "open ods failed: " + err,
          capability,
          @input.input_bytes(source).unwrap_or(Bytes::from_array([])),
          context,
        ),
      )
    }
  }
  Ok(
    ods_parse_with_open_document(
      prepared.prepared_source,
      context,
      prepared.document,
      prepared.inspect,
    ),
  )
}

///|
pub fn ods_parse_with_prepared_document(
  source : @input.InputSource,
  context : @parser.ParseContext,
  prepared : @dodf.PreparedOdsDocument,
) -> @parser.ParseResult {
  ods_parse_with_open_document(
    source,
    context,
    prepared.document,
    prepared.inspect,
  )
}

///|
pub fn ods_parse_with_open_document(
  source : @input.InputSource,
  context : @parser.ParseContext,
  document : @dodf.OdsDocument,
  inspect : @dodf.OdsInspectReport,
) -> @parser.ParseResult {
  let capability = ods_parser_capability()
  let diagnostics = @fshared.empty_parser_diagnostics(
    ODS_PARSER_NAME,
    PackageSinglePass,
    source,
    "ods",
  )
  ods_init_diagnostics(diagnostics, source, context)
  let bytes = @input.input_bytes(source).unwrap_or(Bytes::from_array([]))
  ods_fill_metrics(diagnostics, document, inspect, bytes)
  ods_apply_repeat_diagnostics(diagnostics, document)
  if context.requested_mode == Some(BlockStreaming) {
    let lowered = ods_lower_block_stream_document(
      source, document, context, diagnostics,
    )
    diagnostics.metrics.set("parser_mode", "block_streaming")
    diagnostics.metrics.set("effective_mode", "block_streaming")
    diagnostics.metrics.set("ir_input_kind", "block_stream")
    diagnostics.metrics.set("event_granularity", "row")
    diagnostics.metrics.set("event_semantics", "ods_row_block_stream")
    diagnostics.metrics.set("block_count", lowered.blocks.length().to_string())
    diagnostics.metrics.set("asset_count", lowered.assets.length().to_string())
    @fshared.refresh_parser_count_metrics(diagnostics, "block_stream")
    diagnostics.pass_trace.push("parse:ods_parser:block_stream_route")
    diagnostics.pass_trace.push("lower:ods_block_stream")
    diagnostics.pass_trace.push("parse:ods_parser")
    return @parser.parse_result_with_blocks_capability(
      ODS_PARSER_NAME,
      BlockStreaming,
      lowered.blocks,
      diagnostics,
      capability,
      metadata=lowered.metadata,
      assets=lowered.assets,
      source_map=Some(lowered.source_map),
    )
  }
  let lowered = ods_lower_document_ir(source, document, context, diagnostics)
  diagnostics.metrics.set("parser_mode", "package_single_pass")
  diagnostics.metrics.set("effective_mode", "package_single_pass")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("event_granularity", "row")
  diagnostics.metrics.set("event_semantics", "package_single_pass")
  diagnostics.metrics.set("block_count", lowered.blocks.length().to_string())
  diagnostics.metrics.set("asset_count", lowered.assets.length().to_string())
  @fshared.refresh_parser_count_metrics(diagnostics, "document")
  diagnostics.pass_trace.push("parse:ods_parser:package_single_pass")
  diagnostics.pass_trace.push("parse:ods_parser")
  let final_document = @core.document_with_diagnostics(lowered, diagnostics)
  @parser.parse_result_with_document_capability(
    ODS_PARSER_NAME,
    PackageSinglePass,
    final_document,
    diagnostics,
    capability,
  )
}

///|
fn ods_apply_repeat_diagnostics(
  diagnostics : @core.Diagnostics,
  document : @dodf.OdsDocument,
) -> Unit {
  let mut truncated_rows = 0
  let mut omitted_rows = 0
  for sheet in document.sheets {
    for row in sheet.rows {
      if row.repeat_count > ODS_MAX_MATERIALIZED_ROW_REPEAT &&
        ods_row_has_visible_content(row, true) {
        truncated_rows += 1
        omitted_rows += row.repeat_count - ODS_MAX_MATERIALIZED_ROW_REPEAT
      }
    }
  }
  diagnostics.metrics.set("repeated_rows_truncated", truncated_rows.to_string())
  diagnostics.metrics.set("repeated_rows_omitted", omitted_rows.to_string())
  if truncated_rows > 0 {
    diagnostics.warnings.push(
      "ODS content-bearing repeated rows were bounded during lowering",
    )
    diagnostics.degraded_features.push("ods_repeated_rows_bounded")
    diagnostics.metrics.set("resource_limit_hit", "true")
  }
}

///|
fn ods_init_diagnostics(
  diagnostics : @core.Diagnostics,
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Unit {
  @fshared.init_parser_route_metrics(
    diagnostics,
    source,
    context,
    "ods",
    ODS_PARSER_NAME,
    PackageSinglePass,
    PackageSinglePass,
    "document",
    "row",
    "package_single_pass",
  )
  @fshared.init_parser_product_mode_metrics(diagnostics, context)
  diagnostics.metrics.set("builder_input_kind", "document")
  diagnostics.metrics.set("office_document_kind", "ods")
  diagnostics.metrics.set("format_family", "package_document")
  diagnostics.metrics.set("product_path_enabled", "true")
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("syntax_error_count", "0")
  @fshared.init_parser_count_metrics(diagnostics)
  diagnostics.metrics.set("sheet_count", "0")
  diagnostics.metrics.set("visible_sheet_count", "0")
  diagnostics.metrics.set("hidden_sheet_count", "0")
  diagnostics.metrics.set("row_count", "0")
  diagnostics.metrics.set("non_empty_row_count", "0")
  diagnostics.metrics.set("cell_count", "0")
  diagnostics.metrics.set("used_cell_count", "0")
  diagnostics.metrics.set("max_sheet_rows", "0")
  diagnostics.metrics.set("max_sheet_cols", "0")
  diagnostics.metrics.set("max_used_cols", "0")
  @fshared.apply_product_metrics(diagnostics, "ods")
}

///|
fn ods_fill_metrics(
  diagnostics : @core.Diagnostics,
  document : @dodf.OdsDocument,
  inspect : @dodf.OdsInspectReport,
  bytes : Bytes,
) -> Unit {
  diagnostics.metrics.set("package_mimetype", document.package_info.mimetype)
  diagnostics.metrics.set(
    "manifest_seen",
    @fshared.bool_string(document.package_info.manifest_seen),
  )
  diagnostics.metrics.set("content_path", document.package_info.content_path)
  diagnostics.metrics.set(
    "meta_seen",
    @fshared.bool_string(document.package_info.meta_path is Some(_)),
  )
  diagnostics.metrics.set(
    "styles_seen",
    @fshared.bool_string(document.package_info.styles_path is Some(_)),
  )
  diagnostics.metrics.set("archive_bytes", bytes.length().to_string())
  diagnostics.metrics.set("sheet_count", inspect.sheet_count.to_string())
  diagnostics.metrics.set(
    "visible_sheet_count",
    inspect.visible_sheet_count.to_string(),
  )
  diagnostics.metrics.set(
    "hidden_sheet_count",
    inspect.hidden_sheet_count.to_string(),
  )
  diagnostics.metrics.set("row_count", inspect.row_count.to_string())
  diagnostics.metrics.set(
    "non_empty_row_count",
    inspect.non_empty_row_count.to_string(),
  )
  diagnostics.metrics.set("cell_count", inspect.cell_count.to_string())
  diagnostics.metrics.set(
    "used_cell_count",
    inspect.used_cell_count.to_string(),
  )
  diagnostics.metrics.set(
    "hidden_row_count",
    inspect.hidden_row_count.to_string(),
  )
  diagnostics.metrics.set(
    "covered_cell_count",
    inspect.covered_cell_count.to_string(),
  )
  diagnostics.metrics.set("max_sheet_rows", inspect.max_sheet_rows.to_string())
  diagnostics.metrics.set("max_sheet_cols", inspect.max_sheet_cols.to_string())
  diagnostics.metrics.set("max_used_cols", inspect.max_used_cols.to_string())
}

///|
priv struct OdsLoweredProduct {
  blocks : Array[@core.CoreBlock]
  assets : Array[@core.AssetRef]
  metadata : @core.DocumentMetadata
  source_map : @core.SourceMap
}

///|
fn ods_lower_document_ir(
  source : @input.InputSource,
  document : @dodf.OdsDocument,
  context : @parser.ParseContext,
  diagnostics : @core.Diagnostics,
) -> @core.DocumentIR {
  let lowered = ods_lower_common(source, document, false, context, diagnostics)
  @core.document_with_source_map(
    @core.document_with_assets(
      @core.document_with_metadata(
        @core.document_with_blocks(@core.empty_document_ir(), lowered.blocks),
        lowered.metadata,
      ),
      lowered.assets,
    ),
    Some(lowered.source_map),
  )
}

///|
fn ods_lower_block_stream_document(
  source : @input.InputSource,
  document : @dodf.OdsDocument,
  context : @parser.ParseContext,
  diagnostics : @core.Diagnostics,
) -> OdsLoweredProduct {
  ods_lower_common(source, document, true, context, diagnostics)
}

///|
fn ods_lower_common(
  source : @input.InputSource,
  document : @dodf.OdsDocument,
  stream : Bool,
  context : @parser.ParseContext,
  diagnostics : @core.Diagnostics,
) -> OdsLoweredProduct {
  let blocks : Array[@core.CoreBlock] = []
  let assets : Array[@core.AssetRef] = []
  let asset_paths_by_href : Map[String, String] = Map([])
  let asset_ids_by_href : Map[String, String] = Map([])
  let metadata = ods_metadata(document)
  let source_map = @core.empty_source_map()
  let accurate_semantic = context.lowering_profile == AccurateSemantic
  let include_hidden_sheets = accurate_semantic &&
    @product.accurate_feature_enabled(
      context.accurate_features,
      OdsHiddenSheets,
    )
  let include_hidden_rows = accurate_semantic &&
    @product.accurate_feature_enabled(context.accurate_features, OdsHiddenRows)
  let include_covered_spans = accurate_semantic &&
    @product.accurate_feature_enabled(
      context.accurate_features,
      OdsCoveredCellSpans,
    )
  for sheet in document.sheets {
    if !sheet.visible && !include_hidden_sheets {
      continue
    }
    let visible_rows : Array[@dodf.OdsRow] = []
    for row in sheet.rows {
      if ods_row_has_visible_content(row, include_hidden_rows) {
        visible_rows.push(row)
      }
    }
    if visible_rows.length() == 0 && sheet.images.length() == 0 {
      continue
    }
    let heading_ref = ods_sheet_source_ref(source, document, sheet, None)
    let heading = @core.make_block(Heading, sheet.name, source_ref=heading_ref)
    source_map.block_entries.push(
      @core.make_source_map_entry(primary_ref=Some(heading_ref), refs=[
        heading_ref,
      ]),
    )
    blocks.push(heading)
    if stream {
      for row in sheet.rows {
        if !ods_row_has_visible_content(row, include_hidden_rows) {
          continue
        }
        for repeat_offset in 0..<ods_effective_row_repeat(row) {
          let row_index = row.row_index + repeat_offset
          let row_ref = ods_sheet_source_ref(
            source,
            document,
            sheet,
            Some(row_index),
          )
          let table = @core.make_block(Table, "row", source_ref=row_ref)
          let row_block = @core.make_block(TableRow, "", source_ref=row_ref)
          for cell in ods_effective_row_cells(row) {
            row_block.children.push(
              @core.make_block(TableCell, cell.text, source_ref=row_ref),
            )
          }
          table.children.push(row_block)
          table.attrs.set("sheet", sheet.name)
          table.attrs.set("row_index", row_index.to_string())
          table.attrs.set("render_table_mode", "sparse")
          blocks.push(table)
          source_map.block_entries.push(
            @core.make_source_map_entry(primary_ref=Some(row_ref), refs=[
              row_ref,
            ]),
          )
        }
      }
    } else {
      let table_ref = ods_sheet_source_ref(source, document, sheet, None)
      let table = @core.make_block(Table, "table", source_ref=table_ref)
      if include_covered_spans && ods_sheet_has_span_cells(sheet) {
        table.attrs.set("render_html_table", "true")
      }
      if context.lowering_profile == LargeAdaptive {
        table.attrs.set("render_table_mode", "sparse")
      }
      for row in visible_rows {
        for repeat_offset in 0..<ods_effective_row_repeat(row) {
          let row_ref = ods_sheet_source_ref(
            source,
            document,
            sheet,
            Some(row.row_index + repeat_offset),
          )
          let row_block = @core.make_block(TableRow, "", source_ref=row_ref)
          for cell in ods_effective_row_cells(row) {
            if cell.covered &&
              cell.text == "" &&
              cell.formula is None &&
              !include_covered_spans {
              continue
            }
            let cell_block = @core.make_block(
              TableCell,
              cell.text,
              source_ref=row_ref,
            )
            if include_covered_spans && !cell.covered {
              if cell.row_span > 1 {
                cell_block.attrs.set("rowspan", cell.row_span.to_string())
              }
              if cell.col_span > 1 {
                cell_block.attrs.set("colspan", cell.col_span.to_string())
              }
            }
            if include_covered_spans && cell.covered {
              cell_block.attrs.set("covered_cell", "true")
            }
            match cell.formula {
              Some(value) => cell_block.attrs.set("formula", value)
              None => ()
            }
            row_block.children.push(cell_block)
          }
          table.children.push(row_block)
        }
      }
      table.attrs.set("sheet", sheet.name)
      blocks.push(table)
      source_map.block_entries.push(
        @core.make_source_map_entry(primary_ref=Some(table_ref), refs=[
          table_ref,
        ]),
      )
    }
    for image in sheet.images {
      let image_ref = ods_sheet_source_ref(source, document, sheet, None)
      if image.bytes is None {
        let unavailable = @core.make_block(
          BlockQuote,
          "Asset unavailable: " + image.href,
          source_ref=image_ref,
        )
        unavailable.attrs.set("asset_missing", "true")
        unavailable.attrs.set("asset_source_path", image.href)
        unavailable.attrs.set("sheet", sheet.name)
        blocks.push(unavailable)
        continue
      }
      let observed = match image.bytes {
        Some(bytes) => bytes.length().to_int64()
        None => 0L
      }
      if !@parser.asset_payload_within_limits(
          context,
          observed,
          @parser.materialized_asset_payload_bytes(assets),
        ) {
        @parser.record_asset_payload_budget_skip(
          diagnostics,
          "ods-image-" + (assets.length() + 1).to_string(),
          "single_or_total_asset_bytes",
          observed,
          @parser.max_asset_payload_bytes(context),
        )
        let unavailable = @core.make_block(
          BlockQuote,
          "Asset unavailable: " + image.href,
          source_ref=image_ref,
        )
        unavailable.attrs.set("asset_missing", "true")
        unavailable.attrs.set("asset_source_path", image.href)
        unavailable.attrs.set("payload_skipped", "asset_limit")
        unavailable.attrs.set("sheet", sheet.name)
        blocks.push(unavailable)
        continue
      }
      let identity = image.href.trim().to_owned().replace_all(old="\\", new="/")
      let (asset_id, output_path) = match
        (asset_ids_by_href.get(identity), asset_paths_by_href.get(identity)) {
        (Some(id), Some(path)) => (id, path)
        _ => {
          let path = ods_asset_output_path(image.href, assets.length() + 1)
          let id = "ods-image-" + (assets.length() + 1).to_string()
          let asset = @core.make_asset_ref(Image, id, source_ref=image_ref)
          let next_asset = {
            ..asset,
            path: Some(path),
            mime_type: image.media_type,
          }
          next_asset.attrs.set("zip_entry_path", identity)
          match @input.input_path(source) {
            Some(container) =>
              next_asset.attrs.set("zip_container_path", container)
            None => ()
          }
          match image.bytes {
            Some(bytes) => next_asset.payload = Some(Bytes(bytes))
            None => ()
          }
          assets.push(next_asset)
          asset_ids_by_href.set(identity, id)
          asset_paths_by_href.set(identity, path)
          (id, path)
        }
      }
      let image_block = @core.make_block(Image, "", source_ref=image_ref)
      image_block.attrs.set("asset_id", asset_id)
      image_block.attrs.set("path", output_path)
      image_block.attrs.set("alt", image.alt.unwrap_or("ods image"))
      image_block.attrs.set("sheet", sheet.name)
      blocks.push(image_block)
      source_map.block_entries.push(
        @core.make_source_map_entry(primary_ref=Some(image_ref), refs=[
          image_ref,
        ]),
      )
    }
  }
  { blocks, assets, metadata, source_map }
}

///|
fn ods_asset_output_path(href : String, index : Int) -> String {
  let trimmed = href.trim().replace_all(old="\\", new="/")
  let basename = trimmed.split("/").last().unwrap_or("image.bin").to_owned()
  let slug : Array[Char] = []
  for ch in basename.to_lower().to_array() {
    if (ch >= 'a' && ch <= 'z') ||
      (ch >= '0' && ch <= '9') ||
      ch == '.' ||
      ch == '-' ||
      ch == '_' {
      slug.push(ch)
    }
  }
  let name = String::from_array(slug)
  let safe_name = if name == "" { "image.bin" } else { name }
  "assets/ods-image" + index.to_string() + "-" + safe_name
}

///|
fn ods_metadata(document : @dodf.OdsDocument) -> @core.DocumentMetadata {
  let metadata : @core.DocumentMetadata = Map([])
  metadata.set("format", String("ods"))
  metadata.set(
    "description",
    String(
      "OpenDocument spreadsheet with " +
      document.sheets.length().to_string() +
      " sheets",
    ),
  )
  match document.metadata.title {
    Some(value) => metadata.set("title", String(value))
    None => ()
  }
  match document.metadata.subject {
    Some(value) => metadata.set("subject", String(value))
    None => ()
  }
  match document.metadata.language {
    Some(value) => metadata.set("language", String(value))
    None => ()
  }
  metadata
}

///|
fn ods_sheet_source_ref(
  source : @input.InputSource,
  document : @dodf.OdsDocument,
  sheet : @dodf.OdsSheet,
  row_index : Int?,
) -> @core.SourceRef {
  let container_path = @input.input_path(source).unwrap_or(source.source_name)
  let base = @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some(source.source_name),
    Some("ods"),
    Some(container_path),
    Some(document.package_info.content_path),
    None,
    Some("xml"),
    Some(document.package_info.content_path),
  )
  let office = @core.source_ref_with_office_fields(
    base,
    Some(source.source_name),
    Some("ods"),
    Some(document.package_info.content_path),
    Some(sheet.name),
    None,
    None,
    None,
    None,
  )
  let with_sheet = @core.source_ref_with_extra(office, "ods_sheet", sheet.name)
  match row_index {
    Some(value) =>
      @core.source_ref_with_extra(
        with_sheet,
        "ods_row_index",
        value.to_string(),
      )
    None => with_sheet
  }
}

///|
fn ods_malformed_parse_result(
  source : @input.InputSource,
  diagnostics : @core.Diagnostics,
  err : String,
  capability : @parser.ParserCapability,
  bytes : Bytes,
  context : @parser.ParseContext,
) -> @parser.ParseResult {
  diagnostics.warnings.push("ods parse failed; returned raw fenced fallback")
  diagnostics.errors.push(err)
  diagnostics.degraded_features.push("ods_raw_fenced_fallback")
  diagnostics.fallback_trace.push("ods_raw_fenced_fallback")
  diagnostics.metrics.set("syntax_error_count", "1")
  @fshared.refresh_parser_count_metrics(
    diagnostics,
    if context.requested_mode == Some(BlockStreaming) {
      "block_stream"
    } else {
      "document"
    },
  )
  if context.requested_mode == Some(BlockStreaming) {
    diagnostics.metrics.set("parser_mode", "block_streaming")
    diagnostics.metrics.set("effective_mode", "block_streaming")
    diagnostics.metrics.set("ir_input_kind", "block_stream")
    diagnostics.metrics.set("event_semantics", "ods_row_block_stream")
    let raw = @core.make_block(
      Code,
      "binary ods package (" + bytes.length().to_string() + " bytes)",
      source_ref=ods_fallback_source_ref(source),
    )
    raw.attrs.set("info", "ods")
    return @parser.parse_result_with_blocks_capability(
      ODS_PARSER_NAME,
      BlockStreaming,
      [raw],
      diagnostics,
      capability,
    )
  }
  let raw = @core.make_block(
    Code,
    "binary ods package (" + bytes.length().to_string() + " bytes)",
    source_ref=ods_fallback_source_ref(source),
  )
  raw.attrs.set("info", "ods")
  let document = @core.document_with_diagnostics(
    @core.document_with_blocks(@core.empty_document_ir(), [raw]),
    diagnostics,
  )
  @parser.parse_result_with_document_capability(
    ODS_PARSER_NAME,
    PackageSinglePass,
    document,
    diagnostics,
    capability,
  )
}

///|
fn ods_fallback_source_ref(source : @input.InputSource) -> @core.SourceRef {
  @core.source_ref_with_lines(
    @core.empty_source_ref(),
    Some(source.source_name),
    Some("ods"),
    None,
    None,
  )
}

///|
fn ods_row_has_visible_content(
  row : @dodf.OdsRow,
  include_hidden_rows : Bool,
) -> Bool {
  if row.hidden && !include_hidden_rows {
    return false
  }
  for cell in row.cells {
    if cell.text != "" || cell.formula is Some(_) {
      return true
    }
  }
  false
}

///|
fn ods_effective_row_repeat(row : @dodf.OdsRow) -> Int {
  if row.repeat_count > ODS_MAX_MATERIALIZED_ROW_REPEAT {
    ODS_MAX_MATERIALIZED_ROW_REPEAT
  } else if row.repeat_count > 0 {
    row.repeat_count
  } else {
    1
  }
}

///|
priv struct OdsEffectiveCell {
  text : String
  formula : String?
  covered : Bool
  col_span : Int
  row_span : Int
}

///|
fn ods_effective_row_cells(row : @dodf.OdsRow) -> Array[OdsEffectiveCell] {
  let expanded : Array[OdsEffectiveCell] = []
  let last_used_index = ods_last_used_cell_index(row)
  if last_used_index < 0 {
    return expanded
  }
  let mut flat_index = 0
  for cell in row.cells {
    let repeat = if cell.repeat_count > 0 { cell.repeat_count } else { 1 }
    for _ in 0..<repeat {
      if flat_index > last_used_index {
        return expanded
      }
      expanded.push({
        text: cell.text,
        formula: cell.formula,
        covered: cell.covered,
        col_span: cell.col_span,
        row_span: cell.row_span,
      })
      flat_index += 1
    }
  }
  expanded
}

///|
fn ods_sheet_has_span_cells(sheet : @dodf.OdsSheet) -> Bool {
  for row in sheet.rows {
    for cell in row.cells {
      if cell.col_span > 1 || cell.row_span > 1 {
        return true
      }
    }
  }
  false
}

///|
fn ods_last_used_cell_index(row : @dodf.OdsRow) -> Int {
  let mut flat_index = 0
  let mut last_used_index = -1
  for cell in row.cells {
    let repeat = if cell.repeat_count > 0 { cell.repeat_count } else { 1 }
    let is_used = !cell.covered && (cell.text != "" || cell.formula is Some(_))
    if is_used {
      let width = if cell.col_span > 1 { cell.col_span } else { 1 }
      let used_end = flat_index + width - 1
      if used_end > last_used_index {
        last_used_index = used_end
      }
    }
    flat_index += repeat
  }
  last_used_index
}
