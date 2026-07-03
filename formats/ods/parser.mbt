///|
const ODS_PARSER_NAME : String = "ods_parser"

///|
pub fn ods_parser_capability() -> @parser.ParserCapability {
  @parser.package_with_block_route_parser_capability(
    @parser.StreamingGranularity::Row,
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
  @parser.make_parser(
    ODS_PARSER_NAME,
    @parser.ParserMode::PackageSinglePass,
    capability,
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      parse_ods_document_result(source, context, capability)
    },
  )
}

///|
fn parse_ods_document_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
  capability : @parser.ParserCapability,
) -> Result[@parser.ParseResult, String] {
  let bytes = match @input.read_input_bytes(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let diagnostics = @fshared.empty_parser_diagnostics(
    ODS_PARSER_NAME,
    @parser.ParserMode::PackageSinglePass,
    source,
    "ods",
  )
  ods_init_diagnostics(diagnostics, source, context)
  let opened = try @dodf.open_ods_document(bytes) |> Ok catch {
    e => Err(e.to_string())
  }
  let document = match opened {
    Ok(value) => value
    Err(err) =>
      return Ok(
        ods_malformed_parse_result(
          source,
          diagnostics,
          "open ods failed: " + err,
          capability,
          bytes,
          context,
        ),
      )
  }
  let inspect = @dodf.inspect_ods_document(document)
  ods_fill_metrics(diagnostics, document, inspect, bytes)
  if context.requested_mode == Some(@parser.ParserMode::BlockStreaming) {
    let lowered = ods_lower_block_stream_document(source, document)
    diagnostics.metrics.set("parser_mode", "block_streaming")
    diagnostics.metrics.set("effective_mode", "block_streaming")
    diagnostics.metrics.set("ir_input_kind", "block_stream")
    diagnostics.metrics.set("event_granularity", "row")
    diagnostics.metrics.set("event_semantics", "ods_row_block_stream")
    diagnostics.metrics.set("block_count", lowered.blocks.length().to_string())
    diagnostics.metrics.set("asset_count", "0")
    @fshared.refresh_parser_count_metrics(diagnostics, "block_stream")
    diagnostics.pass_trace.push("parse:ods_parser:block_stream_route")
    diagnostics.pass_trace.push("lower:ods_block_stream")
    diagnostics.pass_trace.push("parse:ods_parser")
    return Ok(
      @parser.parse_result_with_blocks_capability(
        ODS_PARSER_NAME,
        @parser.ParserMode::BlockStreaming,
        lowered.blocks,
        diagnostics,
        capability,
        metadata=lowered.metadata,
        source_map=Some(lowered.source_map),
      ),
    )
  }
  let lowered = ods_lower_document_ir(source, document)
  diagnostics.metrics.set("parser_mode", "package_single_pass")
  diagnostics.metrics.set("effective_mode", "package_single_pass")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("event_granularity", "row")
  diagnostics.metrics.set("event_semantics", "package_single_pass")
  diagnostics.metrics.set("block_count", lowered.blocks.length().to_string())
  diagnostics.metrics.set("asset_count", "0")
  @fshared.refresh_parser_count_metrics(diagnostics, "document")
  diagnostics.pass_trace.push("parse:ods_parser:package_single_pass")
  diagnostics.pass_trace.push("parse:ods_parser")
  let final_document = @core.document_with_diagnostics(lowered, diagnostics)
  Ok(
    @parser.parse_result_with_document_capability(
      ODS_PARSER_NAME,
      @parser.ParserMode::PackageSinglePass,
      final_document,
      diagnostics,
      capability,
    ),
  )
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
    @parser.ParserMode::PackageSinglePass,
    @parser.ParserMode::PackageSinglePass,
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
  diagnostics.metrics.set("max_sheet_rows", "0")
  diagnostics.metrics.set("max_sheet_cols", "0")
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
  diagnostics.metrics.set("max_sheet_rows", inspect.max_sheet_rows.to_string())
  diagnostics.metrics.set("max_sheet_cols", inspect.max_sheet_cols.to_string())
}

///|
priv struct OdsLoweredProduct {
  blocks : Array[@core.CoreBlock]
  metadata : @core.DocumentMetadata
  source_map : @core.SourceMap
}

///|
fn ods_lower_document_ir(
  source : @input.InputSource,
  document : @dodf.OdsDocument,
) -> @core.DocumentIR {
  let lowered = ods_lower_common(source, document, false)
  @core.document_with_source_map(
    @core.document_with_metadata(
      @core.document_with_blocks(@core.empty_document_ir(), lowered.blocks),
      lowered.metadata,
    ),
    Some(lowered.source_map),
  )
}

///|
fn ods_lower_block_stream_document(
  source : @input.InputSource,
  document : @dodf.OdsDocument,
) -> OdsLoweredProduct {
  ods_lower_common(source, document, true)
}

///|
fn ods_lower_common(
  source : @input.InputSource,
  document : @dodf.OdsDocument,
  stream : Bool,
) -> OdsLoweredProduct {
  let blocks : Array[@core.CoreBlock] = []
  let metadata = ods_metadata(document)
  let source_map = @core.empty_source_map()
  for sheet in document.sheets {
    if !sheet.visible {
      continue
    }
    let visible_rows : Array[@dodf.OdsRow] = []
    for row in sheet.rows {
      if ods_row_has_visible_content(row) {
        visible_rows.push(row)
      }
    }
    if visible_rows.length() == 0 {
      continue
    }
    let heading_ref = ods_sheet_source_ref(source, document, sheet, None)
    let heading = @core.make_block(
      @core.BlockKind::Heading,
      sheet.name,
      source_ref=heading_ref,
    )
    source_map.block_entries.push(
      @core.make_source_map_entry(primary_ref=Some(heading_ref), refs=[
        heading_ref,
      ]),
    )
    blocks.push(heading)
    if stream {
      for row in sheet.rows {
        if !ods_row_has_visible_content(row) {
          continue
        }
        let row_ref = ods_sheet_source_ref(
          source,
          document,
          sheet,
          Some(row.row_index),
        )
        let table = @core.make_block(
          @core.BlockKind::Table,
          "row",
          source_ref=row_ref,
        )
        let row_block = @core.make_block(
          @core.BlockKind::TableRow,
          "",
          source_ref=row_ref,
        )
        for cell in row.cells {
          row_block.children.push(
            @core.make_block(
              @core.BlockKind::TableCell,
              cell.text,
              source_ref=row_ref,
            ),
          )
        }
        table.children.push(row_block)
        table.attrs.set("sheet", sheet.name)
        table.attrs.set("row_index", row.row_index.to_string())
        blocks.push(table)
        source_map.block_entries.push(
          @core.make_source_map_entry(primary_ref=Some(row_ref), refs=[row_ref]),
        )
      }
    } else {
      let table_ref = ods_sheet_source_ref(source, document, sheet, None)
      let table = @core.make_block(
        @core.BlockKind::Table,
        "table",
        source_ref=table_ref,
      )
      for row in visible_rows {
        let row_ref = ods_sheet_source_ref(
          source,
          document,
          sheet,
          Some(row.row_index),
        )
        let row_block = @core.make_block(
          @core.BlockKind::TableRow,
          "",
          source_ref=row_ref,
        )
        for cell in row.cells {
          if cell.covered && cell.text == "" && cell.formula is None {
            continue
          }
          let cell_block = @core.make_block(
            @core.BlockKind::TableCell,
            cell.text,
            source_ref=row_ref,
          )
          match cell.formula {
            Some(value) => cell_block.attrs.set("formula", value)
            None => ()
          }
          row_block.children.push(cell_block)
        }
        table.children.push(row_block)
      }
      table.attrs.set("sheet", sheet.name)
      blocks.push(table)
      source_map.block_entries.push(
        @core.make_source_map_entry(primary_ref=Some(table_ref), refs=[
          table_ref,
        ]),
      )
    }
  }
  { blocks, metadata, source_map }
}

///|
fn ods_metadata(document : @dodf.OdsDocument) -> @core.DocumentMetadata {
  let metadata : @core.DocumentMetadata = Map([])
  metadata.set("format", @core.JsonValue::String("ods"))
  metadata.set(
    "description",
    @core.JsonValue::String(
      "OpenDocument spreadsheet with " +
      document.sheets.length().to_string() +
      " sheets",
    ),
  )
  match document.metadata.title {
    Some(value) => metadata.set("title", @core.JsonValue::String(value))
    None => ()
  }
  match document.metadata.subject {
    Some(value) => metadata.set("subject", @core.JsonValue::String(value))
    None => ()
  }
  match document.metadata.language {
    Some(value) => metadata.set("language", @core.JsonValue::String(value))
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
  let container_path = source.path.unwrap_or(source.source_name)
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
    if context.requested_mode == Some(@parser.ParserMode::BlockStreaming) {
      "block_stream"
    } else {
      "document"
    },
  )
  if context.requested_mode == Some(@parser.ParserMode::BlockStreaming) {
    diagnostics.metrics.set("parser_mode", "block_streaming")
    diagnostics.metrics.set("effective_mode", "block_streaming")
    diagnostics.metrics.set("ir_input_kind", "block_stream")
    diagnostics.metrics.set("event_semantics", "ods_row_block_stream")
    let raw = @core.make_block(
      @core.BlockKind::Code,
      "binary ods package (" + bytes.length().to_string() + " bytes)",
      source_ref=ods_fallback_source_ref(source),
    )
    raw.attrs.set("info", "ods")
    return @parser.parse_result_with_blocks_capability(
      ODS_PARSER_NAME,
      @parser.ParserMode::BlockStreaming,
      [raw],
      diagnostics,
      capability,
    )
  }
  let raw = @core.make_block(
    @core.BlockKind::Code,
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
    @parser.ParserMode::PackageSinglePass,
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
fn ods_row_has_visible_content(row : @dodf.OdsRow) -> Bool {
  for cell in row.cells {
    if cell.text != "" || cell.formula is Some(_) {
      return true
    }
  }
  false
}
