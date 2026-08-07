///|
/// Capability for the canonical XLSX package parser.
pub fn xlsx_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    PackageSinglePass,
    true,
    XlsxRow,
    true,
    true,
    true,
    false,
    true,
    true,
    true,
    true,
    false,
    true,
    false,
    true,
    true,
    true,
    true,
    true,
  )
}

///|
/// Construct the canonical XLSX parser entrypoint.
pub fn xlsx_parser() -> @parser.Parser {
  let capability = xlsx_parser_capability()
  @parser.make_parser("xlsx_parser", PackageSinglePass, capability, fn(
    source : @input.InputSource,
    context : @parser.ParseContext,
  ) -> Result[@parser.ParseResult, String] {
    xlsx_parse_document_result(source, context, capability)
  })
}

///|
/// Reuse an already-opened OOXML package to produce an XLSX parse result.
pub fn xlsx_parse_with_package(
  source : @input.InputSource,
  context : @parser.ParseContext,
  pkg : @ox.OoxmlPackage,
) -> @parser.ParseResult {
  xlsx_parse_document_result_from_package(
    source,
    context,
    xlsx_parser_capability(),
    pkg,
    probe_artifact_reused=true,
  )
}

///|
pub fn xlsx_parse_with_prepared_package(
  _source : @input.InputSource,
  context : @parser.ParseContext,
  prepared : @drxlsx.PreparedXlsxPackage,
  probe_artifact_reused? : Bool = true,
) -> @parser.ParseResult {
  xlsx_parse_document_result_from_package(
    prepared.prepared_source,
    context,
    xlsx_parser_capability(),
    prepared.opened_package,
    probe_artifact_reused~,
  )
}

///|
/// Benchmark-oriented helper that parses workbook-level OOXML structures and
/// returns the included visible sheet count.
pub fn xlsx_workbook_metric(source : @input.InputSource) -> Result[Int, String] {
  let prepared = match @drxlsx.prepare_xlsx_package_from_source(source) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let workbook = try
    xlsx_parse_workbook(
      prepared.opened_package,
      @core.empty_diagnostics(),
      xlsx_benchmark_parse_context(),
    )
    |> Ok
  catch {
    err => Err(err.to_string())
  }
  match workbook {
    Ok(value) => Ok(value.sheets.length())
    Err(err) => Err(err)
  }
}

///|
/// Benchmark-oriented helper that parses workbook structures and returns the
/// non-empty cell count of the first included sheet.
pub fn xlsx_first_sheet_metric(
  source : @input.InputSource,
) -> Result[Int, String] {
  let workbook = xlsx_workbook_from_source(source)
  match workbook {
    Ok(value) =>
      if value.sheets.length() == 0 {
        Ok(0)
      } else {
        Ok(value.sheets[0].non_empty_cell_count)
      }
    Err(err) => Err(err)
  }
}

///|
/// Cheap workbook-level summary used by route probing and benchmarks.
pub struct XlsxPreflightSummary {
  sheet_count : Int
  visible_sheet_count : Int
  hidden_sheet_count : Int
  very_hidden_sheet_count : Int
  max_sheet_rows : Int
  max_sheet_cols : Int
  estimated_cells : Int
}

///|
/// Build a workbook preflight summary directly from an input source.
pub fn xlsx_preflight_summary(
  source : @input.InputSource,
) -> Result[XlsxPreflightSummary, String] {
  let prepared = match @drxlsx.prepare_xlsx_package_from_source(source) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  xlsx_preflight_summary_with_package(prepared.opened_package)
}

///|
/// Build a workbook preflight summary from an already-opened OOXML package.
pub fn xlsx_preflight_summary_with_package(
  pkg : @ox.OoxmlPackage,
) -> Result[XlsxPreflightSummary, String] {
  let shared = try xlsx_load_workbook_shared_state(pkg) |> Ok catch {
    err => Err(err.to_string())
  }
  let shared = match shared {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let mut visible_sheet_count = 0
  let mut hidden_sheet_count = 0
  let mut very_hidden_sheet_count = 0
  let mut max_sheet_rows = 0
  let mut max_sheet_cols = 0
  let mut estimated_cells = 0
  for sheet_info in shared.sheet_infos {
    match sheet_info.visibility {
      Visible => {
        visible_sheet_count += 1
        let sheet_xml = try
          @ox.read_part_text_transient(pkg, sheet_info.part_name) |> Ok
        catch {
          err => Err(err.to_string())
        }
        match sheet_xml {
          Ok(value) =>
            match xlsx_parse_dimension_ref(value) {
              Some(range_ref) =>
                match xlsx_parse_range_ref(range_ref) {
                  Some((r1, c1, r2, c2)) => {
                    let row_count = if r2 >= r1 { r2 - r1 + 1 } else { 0 }
                    let col_count = if c2 >= c1 { c2 - c1 + 1 } else { 0 }
                    if row_count > max_sheet_rows {
                      max_sheet_rows = row_count
                    }
                    if col_count > max_sheet_cols {
                      max_sheet_cols = col_count
                    }
                    estimated_cells += row_count * col_count
                  }
                  None => ()
                }
              None => ()
            }
          Err(_) => ()
        }
      }
      Hidden => hidden_sheet_count += 1
      VeryHidden => very_hidden_sheet_count += 1
    }
  }
  Ok({
    sheet_count: shared.sheet_infos.length(),
    visible_sheet_count,
    hidden_sheet_count,
    very_hidden_sheet_count,
    max_sheet_rows,
    max_sheet_cols,
    estimated_cells,
  })
}

///|
/// Route-probing variant of workbook preflight that respects explicit resource
/// ceilings.
pub fn xlsx_route_preflight_summary_with_package(
  pkg : @ox.OoxmlPackage,
  max_rows : Int,
  max_cols : Int,
  max_cells : Int,
) -> Result[XlsxPreflightSummary, String] {
  let shared = try xlsx_load_workbook_shared_state(pkg) |> Ok catch {
    err => Err(err.to_string())
  }
  let shared = match shared {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let inventory = @ox.inspect_ooxml_inventory(pkg)
  let sheet_probe_byte_limit = xlsx_preflight_sheet_probe_byte_limit(
    max_rows, max_cols, max_cells,
  )
  let mut visible_sheet_count = 0
  let mut hidden_sheet_count = 0
  let mut very_hidden_sheet_count = 0
  let mut max_sheet_rows = 0
  let mut max_sheet_cols = 0
  let mut estimated_cells = 0
  for sheet_info in shared.sheet_infos {
    match sheet_info.visibility {
      Visible => {
        visible_sheet_count += 1
        let part_size = xlsx_preflight_sheet_part_size(
          inventory.parts,
          sheet_info.part_name,
        )
        if part_size > sheet_probe_byte_limit {
          estimated_cells += xlsx_preflight_estimated_cells_from_sheet_xml_bytes(
            part_size,
          )
          continue
        }
        let sheet_xml = try
          @ox.read_part_text_transient(pkg, sheet_info.part_name) |> Ok
        catch {
          err => Err(err.to_string())
        }
        match sheet_xml {
          Ok(value) =>
            match xlsx_parse_dimension_ref(value) {
              Some(range_ref) =>
                match xlsx_parse_range_ref(range_ref) {
                  Some((r1, c1, r2, c2)) => {
                    let row_count = if r2 >= r1 { r2 - r1 + 1 } else { 0 }
                    let col_count = if c2 >= c1 { c2 - c1 + 1 } else { 0 }
                    if row_count > max_sheet_rows {
                      max_sheet_rows = row_count
                    }
                    if col_count > max_sheet_cols {
                      max_sheet_cols = col_count
                    }
                    estimated_cells += row_count * col_count
                  }
                  None => ()
                }
              None =>
                if part_size > 0 {
                  estimated_cells += xlsx_preflight_estimated_cells_from_sheet_xml_bytes(
                    part_size,
                  )
                }
            }
          Err(_) =>
            if part_size > 0 {
              estimated_cells += xlsx_preflight_estimated_cells_from_sheet_xml_bytes(
                part_size,
              )
            }
        }
      }
      Hidden => hidden_sheet_count += 1
      VeryHidden => very_hidden_sheet_count += 1
    }
  }
  Ok({
    sheet_count: shared.sheet_infos.length(),
    visible_sheet_count,
    hidden_sheet_count,
    very_hidden_sheet_count,
    max_sheet_rows,
    max_sheet_cols,
    estimated_cells,
  })
}

///|
fn xlsx_preflight_sheet_probe_byte_limit(
  max_rows : Int,
  max_cols : Int,
  max_cells : Int,
) -> Int {
  let row_col_budget = if max_rows > 0 && max_cols > 0 {
    max_rows * max_cols
  } else {
    max_cells
  }
  let effective_cells = if row_col_budget > max_cells {
    row_col_budget
  } else {
    max_cells
  }
  let byte_budget = effective_cells * 32
  if byte_budget > 1048576 {
    byte_budget
  } else {
    1048576
  }
}

///|
fn xlsx_preflight_sheet_part_size(
  parts : Array[@ox.OoxmlPartInfo],
  part_name : String,
) -> Int {
  for part in parts {
    if part.part_name == part_name {
      return part.size
    }
  }
  0
}

///|
fn xlsx_preflight_estimated_cells_from_sheet_xml_bytes(size : Int) -> Int {
  if size <= 0 {
    0
  } else if size % 32 == 0 {
    size / 32
  } else {
    size / 32 + 1
  }
}

///|
fn xlsx_parse_document_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
  capability : @parser.ParserCapability,
) -> Result[@parser.ParseResult, String] {
  let prepared = match @drxlsx.prepare_xlsx_package_from_source(source) {
    Ok(value) => value
    Err(err) =>
      return Ok(
        xlsx_open_package_failed_result(source, context, capability, err),
      )
  }
  Ok(
    xlsx_parse_document_result_from_package(
      prepared.prepared_source,
      context,
      capability,
      prepared.opened_package,
      probe_artifact_reused=false,
    ),
  )
}

///|
fn xlsx_parse_document_result_from_package(
  source : @input.InputSource,
  context : @parser.ParseContext,
  capability : @parser.ParserCapability,
  pkg : @ox.OoxmlPackage,
  probe_artifact_reused? : Bool = false,
) -> @parser.ParseResult {
  let diagnostics = @fshared.empty_parser_diagnostics(
    "xlsx_parser",
    PackageSinglePass,
    source,
    "xlsx",
  )
  xlsx_init_diagnostics(diagnostics, source, context)
  diagnostics.metrics.set(
    "probe_artifact_reused",
    if probe_artifact_reused {
      "true"
    } else {
      "false"
    },
  )

  xlsx_fill_package_metrics(diagnostics, pkg)
  diagnostics.metrics.set(
    "fidelity_mode",
    @product.fidelity_mode_name(context.fidelity_mode),
  )
  diagnostics.metrics.set(
    "output_mode",
    @product.output_mode_name(context.output_mode),
  )
  let requested_blocks = context.requested_mode == Some(BlockStreaming)
  if requested_blocks {
    let lowered = try
      xlsx_lower_block_stream_document(source, pkg, diagnostics, context) |> Ok
    catch {
      e => Err(e.to_string())
    }
    let lowered = match lowered {
      Ok(value) => value
      Err(err) => {
        diagnostics.errors.push("parse xlsx block stream failed: " + err)
        diagnostics.degraded_features.push("xlsx_block_stream_failure")
        diagnostics.metrics.set("parser_mode", "block_streaming")
        diagnostics.metrics.set("effective_mode", "block_streaming")
        diagnostics.metrics.set("ir_input_kind", "block_stream")
        diagnostics.metrics.set("event_granularity", "xlsx_row")
        diagnostics.metrics.set("event_semantics", "xlsx_row_block_stream")
        diagnostics.metrics.set("block_count", "0")
        diagnostics.metrics.set("asset_count", "0")
        diagnostics.metrics.set(
          "degraded_feature_count",
          diagnostics.degraded_features.length().to_string(),
        )
        diagnostics.metrics.set(
          "fallback_count",
          diagnostics.fallback_trace.length().to_string(),
        )
        diagnostics.metrics.set(
          "warning_count",
          diagnostics.warnings.length().to_string(),
        )
        diagnostics.metrics.set(
          "error_count",
          diagnostics.errors.length().to_string(),
        )
        diagnostics.metrics.set(
          "issue_count",
          (diagnostics.warnings.length() + diagnostics.errors.length()).to_string(),
        )
        diagnostics.pass_trace.push("parse:xlsx_parser:block_stream_route")
        diagnostics.pass_trace.push("parse:xlsx_parser:block_stream_failed")
        diagnostics.pass_trace.push("parse:xlsx_parser")
        return @parser.parse_result_with_blocks_capability(
          "xlsx_parser",
          BlockStreaming,
          [],
          diagnostics,
          capability,
          metadata=Map([]),
          assets=[],
        )
      }
    }
    let package_media = xlsx_collect_package_media_assets(
      source, pkg, diagnostics, context,
    )
    lowered.blocks.append(package_media.0[:])
    lowered.assets.append(package_media.1[:])
    diagnostics.metrics.set("parser_mode", "block_streaming")
    diagnostics.metrics.set("effective_mode", "block_streaming")
    diagnostics.metrics.set("ir_input_kind", "block_stream")
    diagnostics.metrics.set("event_granularity", "xlsx_row")
    diagnostics.metrics.set("event_semantics", "xlsx_row_block_stream")
    diagnostics.metrics.set("block_count", lowered.blocks.length().to_string())
    diagnostics.metrics.set("asset_count", lowered.assets.length().to_string())
    diagnostics.metrics.set(
      "degraded_feature_count",
      diagnostics.degraded_features.length().to_string(),
    )
    diagnostics.metrics.set(
      "fallback_count",
      diagnostics.fallback_trace.length().to_string(),
    )
    diagnostics.metrics.set(
      "warning_count",
      diagnostics.warnings.length().to_string(),
    )
    diagnostics.metrics.set(
      "error_count",
      diagnostics.errors.length().to_string(),
    )
    diagnostics.metrics.set(
      "issue_count",
      (diagnostics.warnings.length() + diagnostics.errors.length()).to_string(),
    )
    diagnostics.pass_trace.push("parse:xlsx_parser:block_stream_route")
    diagnostics.pass_trace.push("lower:xlsx_sheet_row_table_regions")
    diagnostics.pass_trace.push("parse:xlsx_parser")
    return @parser.parse_result_with_blocks_capability(
      "xlsx_parser",
      BlockStreaming,
      lowered.blocks,
      diagnostics,
      capability,
      metadata=lowered.metadata,
      assets=lowered.assets,
    )
  }

  let workbook = try
    xlsx_parse_workbook(pkg, diagnostics, context) |> Ok
  catch {
    e => Err(e.to_string())
  }
  let workbook = match workbook {
    Ok(value) => value
    Err(err) =>
      return xlsx_malformed_parse_result(
        source,
        diagnostics,
        "parse xlsx failed: " + err,
        capability,
      )
  }

  let lowered = xlsx_lower_workbook_document(source, workbook, diagnostics)
  let package_media = xlsx_collect_package_media_assets(
    source, pkg, diagnostics, context,
  )
  lowered.blocks.append(package_media.0[:])
  lowered.assets.append(package_media.1[:])
  diagnostics.metrics.set("block_count", lowered.blocks.length().to_string())
  diagnostics.metrics.set("asset_count", lowered.assets.length().to_string())
  diagnostics.metrics.set(
    "degraded_feature_count",
    diagnostics.degraded_features.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
  diagnostics.metrics.set(
    "warning_count",
    diagnostics.warnings.length().to_string(),
  )
  diagnostics.metrics.set(
    "error_count",
    diagnostics.errors.length().to_string(),
  )
  diagnostics.metrics.set(
    "issue_count",
    (diagnostics.warnings.length() + diagnostics.errors.length()).to_string(),
  )
  diagnostics.pass_trace.push("parse:xlsx_parser:package_single_pass")
  diagnostics.pass_trace.push("parse:xlsx_parser")
  let document = @core.document_with_assets(
    @core.document_with_metadata(
      @core.document_with_blocks(@core.empty_document_ir(), lowered.blocks),
      lowered.metadata,
    ),
    lowered.assets,
  )
  let final_document = @core.document_with_diagnostics(document, diagnostics)
  @parser.parse_result_with_document_capability(
    "xlsx_parser",
    PackageSinglePass,
    final_document,
    diagnostics,
    capability,
  )
}

///|
fn xlsx_open_package_failed_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
  capability : @parser.ParserCapability,
  err : String,
) -> @parser.ParseResult {
  let diagnostics = @fshared.empty_parser_diagnostics(
    "xlsx_parser",
    PackageSinglePass,
    source,
    "xlsx",
  )
  xlsx_init_diagnostics(diagnostics, source, context)
  xlsx_malformed_parse_result(
    source,
    diagnostics,
    "open package failed: " + err,
    capability,
  )
}
