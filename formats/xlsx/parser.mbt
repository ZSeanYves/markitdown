///|
pub fn xlsx_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    @parser.ParserMode::WorkbookModel,
    false,
    @parser.StreamingGranularity::XlsxSheet,
    true,
    false,
    false,
    false,
    false,
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
pub fn xlsx_parser() -> @parser.Parser {
  let capability = xlsx_parser_capability()
  @parser.make_parser(
    "xlsx_parser",
    @parser.ParserMode::WorkbookModel,
    capability,
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      xlsx_parse_document_result(source, context, capability)
    },
  )
}

///|
/// Benchmark-oriented helper that parses workbook-level OOXML structures and
/// returns the included visible sheet count.
pub fn xlsx_workbook_metric(source : @input.InputSource) -> Result[Int, String] {
  let bytes = match @input.read_input_bytes(source) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let pkg = try @ox.open_ooxml_package(bytes) |> Ok catch {
    err => Err(err.to_string())
  }
  let pkg = match pkg {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let workbook = try
    xlsx_parse_workbook(
      pkg,
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
fn xlsx_parse_document_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
  capability : @parser.ParserCapability,
) -> Result[@parser.ParseResult, String] {
  let diagnostics = @light_common.empty_parser_diagnostics(
    "xlsx_parser",
    @parser.ParserMode::WorkbookModel,
    source,
    "xlsx",
  )
  xlsx_init_diagnostics(diagnostics, source, context)

  let bytes = match @input.read_input_bytes(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let pkg = try @ox.open_ooxml_package(bytes) |> Ok catch {
    e => Err(e.to_string())
  }
  let pkg = match pkg {
    Ok(value) => value
    Err(err) =>
      return Ok(
        xlsx_malformed_parse_result(
          source,
          diagnostics,
          "open package failed: " + err,
          capability,
        ),
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
      return Ok(
        xlsx_malformed_parse_result(
          source,
          diagnostics,
          "parse xlsx failed: " + err,
          capability,
        ),
      )
  }

  xlsx_fill_package_metrics(diagnostics, pkg)
  let document = xlsx_lower_workbook_document(source, workbook, diagnostics)
  diagnostics.metrics.set("block_count", document.blocks.length().to_string())
  diagnostics.metrics.set("asset_count", document.assets.length().to_string())
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
  diagnostics.pass_trace.push("parse:xlsx_parser")
  let final_document = @core.document_with_diagnostics(document, diagnostics)
  Ok(
    @parser.parse_result_with_document_capability(
      "xlsx_parser",
      @parser.ParserMode::WorkbookModel,
      final_document,
      diagnostics,
      capability,
    ),
  )
}

///|
fn xlsx_benchmark_parse_context() -> @parser.ParseContext {
  @parser.parse_context_with_limits(
    @parser.new_parse_context(@input.DetectedFormat::Xlsx),
    None,
    Some(2000),
    Some(50),
    Some(100000),
    Some(4000),
    false,
  )
}

///|
fn xlsx_workbook_from_source(
  source : @input.InputSource,
) -> Result[XlsxWorkbook, String] {
  let bytes = match @input.read_input_bytes(source) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let pkg = try @ox.open_ooxml_package(bytes) |> Ok catch {
    err => Err(err.to_string())
  }
  let pkg = match pkg {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  try
    xlsx_parse_workbook(
      pkg,
      @core.empty_diagnostics(),
      xlsx_benchmark_parse_context(),
    )
    |> Ok
  catch {
    err => Err(err.to_string())
  }
}

///|
fn xlsx_malformed_parse_result(
  source : @input.InputSource,
  diagnostics : @core.Diagnostics,
  err : String,
  capability : @parser.ParserCapability,
) -> @parser.ParseResult {
  diagnostics.errors.push(err)
  diagnostics.degraded_features.push("xlsx_parse_failure")
  diagnostics.fallback_trace.push("xlsx parse failed -> fail closed")
  diagnostics.metrics.set("block_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("ooxml_part_count", "0")
  diagnostics.metrics.set("relationship_count", "0")
  diagnostics.metrics.set("external_relationship_count", "0")
  diagnostics.metrics.set("missing_relationship_target_count", "0")
  diagnostics.metrics.set("unsupported_relationship_count", "0")
  diagnostics.metrics.set("content_type_count", "0")
  diagnostics.metrics.set("total_uncompressed_bytes", "0")
  diagnostics.metrics.set("external_link_count", "0")
  diagnostics.metrics.set("xlsx_sheet_count", "0")
  diagnostics.metrics.set("xlsx_visible_sheet_count", "0")
  diagnostics.metrics.set("xlsx_hidden_sheet_count", "0")
  diagnostics.metrics.set("xlsx_very_hidden_sheet_count", "0")
  diagnostics.metrics.set("xlsx_row_count", "0")
  diagnostics.metrics.set("xlsx_cell_count", "0")
  diagnostics.metrics.set("xlsx_non_empty_cell_count", "0")
  diagnostics.metrics.set("xlsx_merged_cell_count", "0")
  diagnostics.metrics.set("xlsx_formula_count", "0")
  diagnostics.metrics.set("xlsx_shared_formula_count", "0")
  diagnostics.metrics.set("xlsx_array_formula_count", "0")
  diagnostics.metrics.set("xlsx_shared_string_count", "0")
  diagnostics.metrics.set("xlsx_style_count", "0")
  diagnostics.metrics.set("xlsx_drawing_count", "0")
  diagnostics.metrics.set("xlsx_image_count", "0")
  diagnostics.metrics.set("xlsx_workbook_part", "unresolved")
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
  diagnostics.pass_trace.push("parse:xlsx_parser")
  ignore(source)
  let document = @core.document_with_diagnostics(
    @core.empty_document_ir(),
    diagnostics,
  )
  @parser.parse_result_with_document_capability(
    "xlsx_parser",
    @parser.ParserMode::WorkbookModel,
    document,
    diagnostics,
    capability,
  )
}

///|
priv struct XlsxStyles {
  xf_numfmts : Array[Int]
  custom_numfmts : Map[Int, String]
}

///|
priv struct XlsxSheetInfo {
  sheet_name : String
  sheet_id : String?
  relationship_id : String
  part_name : String
  visibility : @shared.XlsxSheetVisibility
}

///|
priv struct XlsxCell {
  row_index : Int
  column_index : Int
  display_text : String
  formula_text : String?
  is_shared_formula : Bool
  is_array_formula : Bool
  source_ref : @core.SourceRef
}

///|
priv struct XlsxComment {
  cell_ref : String
  author : String?
  text : String
}

///|
priv struct XlsxSheet {
  sheet_name : String
  sheet_id : String?
  relationship_id : String
  part_name : String
  visibility : @shared.XlsxSheetVisibility
  dimension_ref : String?
  min_row : Int
  min_col : Int
  max_row : Int
  max_col : Int
  cell_lookup : Map[String, XlsxCell]
  hidden_rows : Map[Int, Bool]
  merged_lookup : Map[String, String]
  merged_ranges : Array[String]
  row_count : Int
  cell_count : Int
  non_empty_cell_count : Int
  formula_count : Int
  shared_formula_count : Int
  array_formula_count : Int
  drawing_count : Int
  image_count : Int
  external_link_count : Int
  comments : Array[XlsxComment]
  is_empty : Bool
}

///|
priv struct XlsxWorkbook {
  workbook_part : String
  sheets : Array[XlsxSheet]
  shared_strings : Array[String]
  sheet_count : Int
  visible_sheet_count : Int
  hidden_sheet_count : Int
  very_hidden_sheet_count : Int
  row_count : Int
  cell_count : Int
  non_empty_cell_count : Int
  merged_cell_count : Int
  formula_count : Int
  shared_formula_count : Int
  array_formula_count : Int
  style_count : Int
  drawing_count : Int
  image_count : Int
  external_link_count : Int
}

///|
fn xlsx_init_diagnostics(
  diagnostics : @core.Diagnostics,
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Unit {
  diagnostics.metrics.set("parser_name", "xlsx_parser")
  diagnostics.metrics.set("parser_mode", "workbook_model")
  diagnostics.metrics.set(
    "input_kind",
    @light_common.input_kind_name(source.kind),
  )
  diagnostics.metrics.set("detected_format", "xlsx")
  diagnostics.metrics.set(
    "requested_mode",
    @light_common.requested_mode_name(context),
  )
  diagnostics.metrics.set("effective_mode", "workbook_model")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("event_granularity", "xlsx_sheet")
  diagnostics.metrics.set("event_semantics", "document_model")
  diagnostics.metrics.set("office_document_kind", "xlsx")
  diagnostics.metrics.set("runtime_exposed", "true")
  diagnostics.metrics.set("legacy_runtime_dependency", "none")
  diagnostics.metrics.set("legacy_convert_dependency", "none")
  diagnostics.metrics.set("legacy_fallback", "forbidden")
  diagnostics.metrics.set("format_family", "office")
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("media_asset_count", "0")
  diagnostics.metrics.set("materialized_asset_count", "0")
  diagnostics.metrics.set("skipped_asset_count", "0")
  diagnostics.metrics.set("path_traversal_count", "0")
  diagnostics.metrics.set("duplicate_part_count", "0")
  diagnostics.metrics.set("encrypted_entry_count", "0")
  diagnostics.metrics.set("unsupported_compression_count", "0")
  diagnostics.metrics.set("xml_dtd_count", "0")
  diagnostics.metrics.set("xml_external_entity_count", "0")
  diagnostics.metrics.set("macro_part_count", "0")
  diagnostics.metrics.set("ole_object_count", "0")
  diagnostics.metrics.set("external_link_count", "0")
  diagnostics.metrics.set("xlsx_sheet_count", "0")
  diagnostics.metrics.set("xlsx_visible_sheet_count", "0")
  diagnostics.metrics.set("xlsx_hidden_sheet_count", "0")
  diagnostics.metrics.set("xlsx_very_hidden_sheet_count", "0")
  diagnostics.metrics.set("xlsx_row_count", "0")
  diagnostics.metrics.set("xlsx_cell_count", "0")
  diagnostics.metrics.set("xlsx_non_empty_cell_count", "0")
  diagnostics.metrics.set("xlsx_merged_cell_count", "0")
  diagnostics.metrics.set("xlsx_formula_count", "0")
  diagnostics.metrics.set("xlsx_shared_formula_count", "0")
  diagnostics.metrics.set("xlsx_array_formula_count", "0")
  diagnostics.metrics.set("xlsx_shared_string_count", "0")
  diagnostics.metrics.set("xlsx_style_count", "0")
  diagnostics.metrics.set("xlsx_drawing_count", "0")
  diagnostics.metrics.set("xlsx_image_count", "0")
  diagnostics.metrics.set("xlsx_workbook_part", "unresolved")
  diagnostics.metrics.set("max_ooxml_parts", "2000")
  diagnostics.metrics.set("max_total_uncompressed_bytes", "104857600")
  diagnostics.metrics.set("max_single_part_bytes", "8388608")
  diagnostics.metrics.set("max_relationships", "10000")
  diagnostics.metrics.set("max_external_relationships", "1000")
  diagnostics.metrics.set("max_media_assets", "0")
  diagnostics.metrics.set("max_xml_depth", "256")
  diagnostics.metrics.set("max_xml_nodes", "200000")
  diagnostics.metrics.set("max_text_bytes", "4194304")
  diagnostics.metrics.set("max_docx_blocks", "0")
  diagnostics.metrics.set("max_pptx_slides", "0")
  diagnostics.metrics.set("max_xlsx_sheets", "200")
  diagnostics.metrics.set(
    "max_xlsx_rows",
    context.max_rows.unwrap_or(2000).to_string(),
  )
  diagnostics.metrics.set(
    "max_xlsx_columns",
    context.max_cols.unwrap_or(50).to_string(),
  )
  diagnostics.metrics.set(
    "max_xlsx_cells",
    context.max_cells.unwrap_or(100000).to_string(),
  )
  diagnostics.metrics.set(
    "max_xlsx_non_empty_cells",
    context.max_cells.unwrap_or(100000).to_string(),
  )
  diagnostics.metrics.set("max_shared_strings", "200000")
  diagnostics.metrics.set(
    "max_formula_count",
    context.max_cells.unwrap_or(100000).to_string(),
  )
  diagnostics.metrics.set(
    "max_merged_ranges",
    context.max_cells.unwrap_or(100000).to_string(),
  )
  diagnostics.metrics.set("max_materialized_assets", "0")
  @light_common.apply_readiness_metrics(diagnostics, "xlsx", "near_ready")
}

///|
fn xlsx_parse_workbook(
  pkg : @ox.OoxmlPackage,
  diagnostics : @core.Diagnostics,
  context : @parser.ParseContext,
) -> XlsxWorkbook raise @ox.OoxmlError {
  let workbook_part = xlsx_resolve_workbook_part(pkg)
  let workbook_xml = @ox.read_part_text(pkg, workbook_part)
  let shared_strings = if @ox.has_part(pkg, "xl/sharedStrings.xml") {
    xlsx_parse_shared_strings(@ox.read_part_text(pkg, "xl/sharedStrings.xml"))
  } else {
    []
  }
  let styles = if @ox.has_part(pkg, "xl/styles.xml") {
    xlsx_parse_styles(@ox.read_part_text(pkg, "xl/styles.xml"))
  } else {
    { xf_numfmts: [], custom_numfmts: Map([]) }
  }
  let uses_date_1904 = xlsx_workbook_uses_date_1904(workbook_xml)
  let sheet_infos = xlsx_parse_sheet_infos(pkg, workbook_part, workbook_xml)
  let max_rows = context.max_rows.unwrap_or(2000)
  let max_cols = context.max_cols.unwrap_or(50)
  let max_cells = context.max_cells.unwrap_or(100000)
  let max_sheets = 200

  let included_sheets : Array[XlsxSheet] = []
  let effective_sheet_infos = if sheet_infos.length() > max_sheets {
    diagnostics.warnings.push(
      "xlsx sheet count exceeded limit; remaining sheets were skipped",
    )
    diagnostics.degraded_features.push("xlsx_sheets_truncated")
    diagnostics.metrics.set("resource_limit_hit", "true")
    sheet_infos[:max_sheets]
  } else {
    sheet_infos[:]
  }

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
        let sheet = xlsx_parse_sheet(
          pkg, sheet_info, shared_strings, styles, uses_date_1904, max_rows, max_cols,
          max_cells, diagnostics,
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
        included_sheets.push(sheet)
      }
      @shared.XlsxSheetVisibility::Hidden => {
        hidden_sheet_count += 1
        diagnostics.warnings.push(
          "hidden xlsx sheet skipped: " + sheet_info.sheet_name,
        )
        diagnostics.degraded_features.push("xlsx_hidden_sheet_skipped")
      }
      @shared.XlsxSheetVisibility::VeryHidden => {
        very_hidden_sheet_count += 1
        diagnostics.warnings.push(
          "very hidden xlsx sheet skipped: " + sheet_info.sheet_name,
        )
        diagnostics.degraded_features.push("xlsx_very_hidden_sheet_skipped")
      }
    }
  }

  {
    workbook_part,
    sheets: included_sheets,
    shared_strings,
    sheet_count: effective_sheet_infos.length(),
    visible_sheet_count,
    hidden_sheet_count,
    very_hidden_sheet_count,
    row_count,
    cell_count,
    non_empty_cell_count,
    merged_cell_count,
    formula_count,
    shared_formula_count,
    array_formula_count,
    style_count: styles.xf_numfmts.length(),
    drawing_count,
    image_count,
    external_link_count,
  }
}

///|
fn xlsx_resolve_workbook_part(
  pkg : @ox.OoxmlPackage,
) -> String raise @ox.OoxmlError {
  if @ox.has_part(pkg, "xl/workbook.xml") {
    return "xl/workbook.xml"
  }
  let package_rels = @ox.read_package_relationships(pkg)
  for rel in package_rels {
    if rel.target_mode == @ox.OoxmlTargetMode::Internal &&
      rel.rel_type.has_suffix("/officeDocument") {
      return rel.resolved_target
    }
  }
  raise @ox.MissingPart("xl/workbook.xml")
}

///|
fn xlsx_parse_shared_strings(shared_xml : String) -> Array[String] {
  let out : Array[String] = []
  let mut pos = 0
  while true {
    let next = xlsx_find_sub(shared_xml, "<si", pos)
    match next {
      None => break
      Some(start0) => {
        let end0 = xlsx_find_sub(shared_xml, "</si>", start0)
        match end0 {
          None => break
          Some(end1) => {
            let chunk = shared_xml[start0:end1].to_owned()
            out.push(xlsx_concat_text_runs(chunk))
            pos = end1 + 5
          }
        }
      }
    }
  }
  out
}

///|
fn xlsx_parse_styles(styles_xml : String) -> XlsxStyles {
  let xf_numfmts : Array[Int] = []
  let custom_numfmts : Map[Int, String] = Map([])

  let numfmts_start = xlsx_find_sub(styles_xml, "<numFmts", 0)
  match numfmts_start {
    None => ()
    Some(start0) => {
      let gt0 = xlsx_find_sub(styles_xml, ">", start0)
      match gt0 {
        None => ()
        Some(start1) => {
          let end0 = xlsx_find_sub(styles_xml, "</numFmts>", start1 + 1)
          match end0 {
            None => ()
            Some(end1) => {
              let inner = styles_xml[start1 + 1:end1].to_owned()
              let mut pos = 0
              while true {
                let tag0 = xlsx_find_sub(inner, "<numFmt", pos)
                match tag0 {
                  None => break
                  Some(i0) => {
                    let tag1 = xlsx_find_sub(inner, ">", i0)
                    match tag1 {
                      None => break
                      Some(i1) => {
                        let tag = inner[i0:i1 + 1].to_owned()
                        let num_fmt_id = xlsx_parse_int(
                          xlsx_get_attr(tag, "numFmtId").unwrap_or(""),
                        )
                        let format_code = xlsx_get_attr(tag, "formatCode").unwrap_or(
                          "",
                        )
                        if num_fmt_id >= 0 && format_code != "" {
                          custom_numfmts.set(
                            num_fmt_id,
                            xlsx_xml_unescape(format_code),
                          )
                        }
                        pos = i1 + 1
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  let cellxfs_start = xlsx_find_sub(styles_xml, "<cellXfs", 0)
  match cellxfs_start {
    None => ()
    Some(start0) => {
      let gt0 = xlsx_find_sub(styles_xml, ">", start0)
      match gt0 {
        None => ()
        Some(start1) => {
          let end0 = xlsx_find_sub(styles_xml, "</cellXfs>", start1 + 1)
          match end0 {
            None => ()
            Some(end1) => {
              let inner = styles_xml[start1 + 1:end1].to_owned()
              let mut pos = 0
              while true {
                let tag0 = xlsx_find_sub(inner, "<xf", pos)
                match tag0 {
                  None => break
                  Some(i0) => {
                    let tag1 = xlsx_find_sub(inner, ">", i0)
                    match tag1 {
                      None => break
                      Some(i1) => {
                        let tag = inner[i0:i1 + 1].to_owned()
                        xf_numfmts.push(
                          xlsx_parse_int(
                            xlsx_get_attr(tag, "numFmtId").unwrap_or(""),
                          ),
                        )
                        pos = i1 + 1
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  { xf_numfmts, custom_numfmts }
}

///|
fn xlsx_workbook_uses_date_1904(workbook_xml : String) -> Bool {
  let tag0 = xlsx_find_sub(workbook_xml, "<workbookPr", 0)
  match tag0 {
    None => false
    Some(start0) => {
      let tag1 = xlsx_find_sub(workbook_xml, ">", start0)
      match tag1 {
        None => false
        Some(end1) => {
          let tag = workbook_xml[start0:end1 + 1].to_owned()
          let raw = xlsx_get_attr(tag, "date1904").unwrap_or("")
          raw == "1" || raw == "true" || raw == "TRUE"
        }
      }
    }
  }
}

///|
fn xlsx_parse_sheet_infos(
  pkg : @ox.OoxmlPackage,
  workbook_part : String,
  workbook_xml : String,
) -> Array[XlsxSheetInfo] raise @ox.OoxmlError {
  let rels = @ox.read_part_relationships(pkg, workbook_part)
  let out : Array[XlsxSheetInfo] = []
  let mut pos = 0
  while true {
    let next = xlsx_find_sub(workbook_xml, "<sheet", pos)
    match next {
      None => break
      Some(start0) => {
        let tag1 = xlsx_find_sub(workbook_xml, ">", start0)
        match tag1 {
          None => break
          Some(end1) => {
            let tag = workbook_xml[start0:end1 + 1].to_owned()
            let rel_id = xlsx_get_attr(tag, "r:id").unwrap_or("")
            if rel_id != "" {
              match xlsx_find_relationship_by_id(rels, rel_id) {
                Some(rel) =>
                  out.push({
                    sheet_name: xlsx_xml_unescape(
                      xlsx_get_attr(tag, "name").unwrap_or("Sheet"),
                    ),
                    sheet_id: xlsx_get_attr(tag, "sheetId"),
                    relationship_id: rel_id,
                    part_name: rel.resolved_target,
                    visibility: xlsx_parse_sheet_visibility(
                      xlsx_get_attr(tag, "state").unwrap_or(""),
                    ),
                  })
                None => ()
              }
            }
            pos = end1 + 1
          }
        }
      }
    }
  }
  out
}

///|
fn xlsx_parse_sheet_visibility(text : String) -> @shared.XlsxSheetVisibility {
  if text == "hidden" {
    @shared.XlsxSheetVisibility::Hidden
  } else if text == "veryHidden" {
    @shared.XlsxSheetVisibility::VeryHidden
  } else {
    @shared.XlsxSheetVisibility::Visible
  }
}

///|
fn xlsx_find_relationship_by_id(
  rels : Array[@ox.OoxmlRelationship],
  rel_id : String,
) -> @ox.OoxmlRelationship? {
  for rel in rels {
    if rel.id == rel_id {
      return Some(rel)
    }
  }
  None
}

///|
fn xlsx_parse_sheet(
  pkg : @ox.OoxmlPackage,
  sheet_info : XlsxSheetInfo,
  shared_strings : Array[String],
  styles : XlsxStyles,
  uses_date_1904 : Bool,
  max_rows : Int,
  max_cols : Int,
  max_cells : Int,
  diagnostics : @core.Diagnostics,
) -> XlsxSheet raise @ox.OoxmlError {
  let sheet_xml = @ox.read_part_text(pkg, sheet_info.part_name)
  let relationships = @ox.read_part_relationships(pkg, sheet_info.part_name)
  let mut drawing_count = 0
  let mut image_count = 0
  let mut external_link_count = 0
  let comments : Array[XlsxComment] = []
  for rel in relationships {
    if rel.target_mode == @ox.OoxmlTargetMode::External {
      external_link_count += 1
      diagnostics.warnings.push(
        "xlsx external relationship preserved as diagnostics only: " +
        sheet_info.sheet_name +
        " -> " +
        rel.id,
      )
      diagnostics.degraded_features.push("xlsx_external_link_deferred")
    } else if rel.rel_type.has_suffix("/drawing") ||
      rel.rel_type.contains("relationships/drawing") {
      drawing_count += 1
      diagnostics.warnings.push(
        "xlsx drawing relationship deferred: " +
        sheet_info.sheet_name +
        " -> " +
        rel.id,
      )
      diagnostics.degraded_features.push("xlsx_drawing_deferred")
    } else if rel.rel_type.has_suffix("/image") ||
      rel.rel_type.contains("relationships/image") {
      image_count += 1
      diagnostics.warnings.push(
        "xlsx image relationship deferred: " +
        sheet_info.sheet_name +
        " -> " +
        rel.id,
      )
      diagnostics.degraded_features.push("xlsx_image_deferred")
    } else if rel.rel_type.contains("/comments") {
      comments.append(xlsx_parse_comments_part(pkg, rel.resolved_target)[:])
    } else if rel.rel_type.contains("/chart") || rel.rel_type.contains("/pivot") {
      diagnostics.warnings.push(
        "xlsx unsupported relationship kept as diagnostics only: " +
        sheet_info.sheet_name +
        " -> " +
        rel.id,
      )
      diagnostics.degraded_features.push("xlsx_relationship_deferred")
    }
  }

  let dimension_ref = xlsx_parse_dimension_ref(sheet_xml)
  let merged_ranges = xlsx_parse_merged_ranges(sheet_xml)
  let hidden_rows = xlsx_parse_hidden_rows(sheet_xml)
  let parsed_cells = xlsx_parse_sheet_cells(
    sheet_info, sheet_xml, shared_strings, styles, uses_date_1904,
  )
  let bounds = xlsx_effective_bounds(
    dimension_ref, parsed_cells, hidden_rows, max_rows, max_cols, max_cells,
  )
  let (min_row, min_col, max_row, max_col, clipped, is_empty) = bounds
  if clipped {
    diagnostics.metrics.set("resource_limit_hit", "true")
    diagnostics.warnings.push(
      "xlsx sheet bounds exceeded next limits; content was truncated: " +
      sheet_info.sheet_name,
    )
    diagnostics.degraded_features.push("xlsx_sheet_truncated")
  }

  let kept_cells : Array[XlsxCell] = []
  let mut non_empty_cell_count = 0
  let mut formula_count = 0
  let mut shared_formula_count = 0
  let mut array_formula_count = 0
  for cell in parsed_cells {
    if is_empty ||
      xlsx_row_is_hidden(hidden_rows, cell.row_index) ||
      cell.row_index < min_row ||
      cell.row_index > max_row ||
      cell.column_index < min_col ||
      cell.column_index > max_col {
      continue
    }
    kept_cells.push(cell)
    if cell.display_text.trim() != "" {
      non_empty_cell_count += 1
    }
    match cell.formula_text {
      Some(_) => {
        formula_count += 1
        if cell.is_shared_formula {
          shared_formula_count += 1
        }
        if cell.is_array_formula {
          array_formula_count += 1
        }
      }
      None => ()
    }
  }

  let effective_is_empty = xlsx_sheet_is_effectively_empty(
    is_empty, non_empty_cell_count, formula_count,
  )
  let cell_lookup : Map[String, XlsxCell] = Map([])
  let merged_lookup : Map[String, String] = Map([])
  let filtered_ranges = xlsx_filter_merge_ranges(
    merged_ranges, min_row, min_col, max_row, max_col, effective_is_empty,
  )
  if !effective_is_empty {
    xlsx_fill_merge_lookup(merged_lookup, filtered_ranges)
    for cell in kept_cells {
      cell_lookup.set(xlsx_lookup_key(cell.row_index, cell.column_index), cell)
    }
  }

  {
    sheet_name: sheet_info.sheet_name,
    sheet_id: sheet_info.sheet_id,
    relationship_id: sheet_info.relationship_id,
    part_name: sheet_info.part_name,
    visibility: sheet_info.visibility,
    dimension_ref,
    min_row,
    min_col,
    max_row,
    max_col,
    cell_lookup,
    hidden_rows,
    merged_lookup,
    merged_ranges: filtered_ranges,
    row_count: if effective_is_empty {
      0
    } else {
      xlsx_visible_row_count(hidden_rows, min_row, max_row)
    },
    cell_count: if effective_is_empty {
      0
    } else {
      kept_cells.length()
    },
    non_empty_cell_count: if effective_is_empty {
      0
    } else {
      non_empty_cell_count
    },
    formula_count: if effective_is_empty {
      0
    } else {
      formula_count
    },
    shared_formula_count: if effective_is_empty {
      0
    } else {
      shared_formula_count
    },
    array_formula_count: if effective_is_empty {
      0
    } else {
      array_formula_count
    },
    drawing_count,
    image_count,
    external_link_count,
    comments,
    is_empty: effective_is_empty,
  }
}

///|
fn xlsx_parse_dimension_ref(sheet_xml : String) -> String? {
  let tag0 = xlsx_find_sub(sheet_xml, "<dimension", 0)
  match tag0 {
    None => None
    Some(start0) => {
      let tag1 = xlsx_find_sub(sheet_xml, ">", start0)
      match tag1 {
        None => None
        Some(end1) => {
          let tag = sheet_xml[start0:end1 + 1].to_owned()
          let value = xlsx_get_attr(tag, "ref").unwrap_or("")
          if value.trim() == "" {
            None
          } else {
            Some(value)
          }
        }
      }
    }
  }
}

///|
fn xlsx_parse_hidden_rows(sheet_xml : String) -> Map[Int, Bool] {
  let out : Map[Int, Bool] = Map([])
  let mut pos = 0
  while true {
    let next = xlsx_find_sub(sheet_xml, "<row", pos)
    match next {
      None => break
      Some(start0) => {
        let next_char = if start0 + 4 < sheet_xml.length() {
          Some(sheet_xml[start0 + 4])
        } else {
          None
        }
        match next_char {
          Some(ch) =>
            if ch != '>' && ch != ' ' && ch != '\n' && ch != '\r' && ch != '\t' {
              pos = start0 + 4
              continue
            }
          None => {
            pos = start0 + 4
            continue
          }
        }
        let tag1 = xlsx_find_sub(sheet_xml, ">", start0)
        match tag1 {
          None => break
          Some(end1) => {
            let tag = sheet_xml[start0:end1 + 1].to_owned()
            let row_index = xlsx_parse_int(
              xlsx_get_attr(tag, "r").unwrap_or(""),
            )
            if row_index > 0 &&
              xlsx_get_attr(tag, "hidden").unwrap_or("") == "1" {
              out.set(row_index, true)
            }
            pos = end1 + 1
          }
        }
      }
    }
  }
  out
}

///|
fn xlsx_parse_merged_ranges(sheet_xml : String) -> Array[String] {
  let out : Array[String] = []
  let block0 = xlsx_find_sub(sheet_xml, "<mergeCells", 0)
  match block0 {
    None => out
    Some(start0) => {
      let block1 = xlsx_find_sub(sheet_xml, ">", start0)
      match block1 {
        None => out
        Some(start1) => {
          let end0 = xlsx_find_sub(sheet_xml, "</mergeCells>", start1 + 1)
          match end0 {
            None => out
            Some(end1) => {
              let inner = sheet_xml[start1 + 1:end1].to_owned()
              let mut pos = 0
              while true {
                let tag0 = xlsx_find_sub(inner, "<mergeCell", pos)
                match tag0 {
                  None => break
                  Some(i0) => {
                    let tag1 = xlsx_find_sub(inner, ">", i0)
                    match tag1 {
                      None => break
                      Some(i1) => {
                        let tag = inner[i0:i1 + 1].to_owned()
                        let value = xlsx_get_attr(tag, "ref").unwrap_or("")
                        if value != "" && xlsx_parse_range_ref(value) is Some(_) {
                          out.push(value)
                        }
                        pos = i1 + 1
                      }
                    }
                  }
                }
              }
              out
            }
          }
        }
      }
    }
  }
}

///|
fn xlsx_parse_sheet_cells(
  sheet_info : XlsxSheetInfo,
  sheet_xml : String,
  shared_strings : Array[String],
  styles : XlsxStyles,
  uses_date_1904 : Bool,
) -> Array[XlsxCell] {
  let out : Array[XlsxCell] = []
  // Large worksheets may contain millions of characters; avoid rebuilding the
  // entire char array for every `<c...>` probe.
  let chars = sheet_xml.to_array()
  let mut pos = 0
  while true {
    let next = xlsx_find_sub(sheet_xml, "<c", pos)
    match next {
      None => break
      Some(start0) => {
        let tag1 = xlsx_find_sub(sheet_xml, ">", start0)
        match tag1 {
          None => break
          Some(end1) => {
            let ctag = sheet_xml[start0:end1 + 1].to_owned()
            let next_char = if start0 + 2 < chars.length() {
              Some(chars[start0 + 2])
            } else {
              None
            }
            match next_char {
              Some(ch) =>
                if ch != ' ' &&
                  ch != '\t' &&
                  ch != '\n' &&
                  ch != '\r' &&
                  ch != '>' &&
                  ch != '/' {
                  pos = start0 + 2
                  continue
                }
              None => ()
            }
            let cell_ref = xlsx_get_attr(ctag, "r").unwrap_or("")
            let (row_index, column_index) = xlsx_cell_ref_to_rc(cell_ref)
            let cell_type = xlsx_get_attr(ctag, "t").unwrap_or("")
            let style_id = xlsx_get_attr(ctag, "s")
            let style_index = xlsx_parse_int(style_id.unwrap_or(""))
            let (inner, next_pos) = if ctag.has_suffix("/>") {
              ("", end1 + 1)
            } else {
              match xlsx_find_sub(sheet_xml, "</c>", end1 + 1) {
                Some(end2) => (sheet_xml[end1 + 1:end2].to_owned(), end2 + 4)
                None => ("", end1 + 1)
              }
            }
            pos = next_pos
            if row_index <= 0 || column_index <= 0 {
              continue
            }

            let raw_value = if inner == "" {
              None
            } else {
              match xlsx_tag_text(inner, "v") {
                Some(v) => Some(v)
                None => None
              }
            }
            let formula_info = if inner == "" {
              None
            } else {
              xlsx_extract_tag(inner, "f")
            }
            let formula_text = match formula_info {
              Some((_, text)) => if text == "" { None } else { Some(text) }
              None => None
            }
            let inline_text = if inner == "" {
              None
            } else {
              xlsx_parse_inline_string(inner)
            }
            let (display_text, _, shared_string_index) = xlsx_resolve_cell_display(
              cell_type, raw_value, inline_text, formula_text, style_index, shared_strings,
              styles, uses_date_1904,
            )
            let formula_tag = match formula_info {
              Some((tag, _)) => Some(tag)
              None => None
            }
            let is_shared_formula = match formula_tag {
              Some(tag) => xlsx_get_attr(tag, "t").unwrap_or("") == "shared"
              None => false
            }
            let is_array_formula = match formula_tag {
              Some(tag) => xlsx_get_attr(tag, "t").unwrap_or("") == "array"
              None => false
            }
            let source_ref = xlsx_cell_source_ref(
              sheet_info,
              cell_ref,
              row_index,
              column_index,
              formula_text,
              style_id,
              shared_string_index,
              None,
            )
            out.push({
              row_index,
              column_index,
              display_text,
              formula_text,
              is_shared_formula,
              is_array_formula,
              source_ref,
            })
          }
        }
      }
    }
  }
  out
}

///|
fn xlsx_resolve_cell_display(
  cell_type : String,
  raw_value : String?,
  inline_text : String?,
  formula_text : String?,
  style_index : Int,
  shared_strings : Array[String],
  styles : XlsxStyles,
  uses_date_1904 : Bool,
) -> (String, String, Int?) {
  let raw = raw_value.unwrap_or("")
  match formula_text {
    Some(formula) =>
      if raw.trim() != "" {
        let (display_text, _, shared_string_index) = xlsx_resolve_base_cell_value(
          cell_type, raw_value, inline_text, style_index, shared_strings, styles,
          uses_date_1904,
        )
        (display_text, "formula_cached_value", shared_string_index)
      } else {
        ("=" + formula, "formula_missing_cache", None)
      }
    None =>
      xlsx_resolve_base_cell_value(
        cell_type, raw_value, inline_text, style_index, shared_strings, styles, uses_date_1904,
      )
  }
}

///|
fn xlsx_resolve_base_cell_value(
  cell_type : String,
  raw_value : String?,
  inline_text : String?,
  style_index : Int,
  shared_strings : Array[String],
  styles : XlsxStyles,
  uses_date_1904 : Bool,
) -> (String, String, Int?) {
  let raw = raw_value.unwrap_or("")
  if cell_type == "s" {
    let index = xlsx_parse_int(raw)
    if index >= 0 && index < shared_strings.length() {
      return (shared_strings[index], "string", Some(index))
    }
    return ("", "string", None)
  }
  if cell_type == "inlineStr" {
    return (inline_text.unwrap_or(""), "string", None)
  }
  if cell_type == "b" {
    return (if raw == "1" { "TRUE" } else { "FALSE" }, "boolean", None)
  }
  if cell_type == "e" {
    return (raw, "error", None)
  }
  if cell_type == "str" {
    return (xlsx_xml_unescape(raw), "string", None)
  }
  if raw.trim() == "" {
    return ("", "blank", None)
  }
  let formatted = xlsx_format_value(raw, style_index, styles, uses_date_1904)
  let semantic_type = xlsx_semantic_type_for_style(raw, style_index, styles)
  (formatted, semantic_type, None)
}

///|
fn xlsx_format_value(
  raw : String,
  style_index : Int,
  styles : XlsxStyles,
  uses_date_1904 : Bool,
) -> String {
  let num_fmt_id = xlsx_style_numfmt(styles, style_index)
  if num_fmt_id >= 0 && xlsx_numfmt_is_datetime_like(num_fmt_id, styles) {
    return xlsx_format_excel_datetime(
      raw,
      num_fmt_id,
      styles.custom_numfmts.get(num_fmt_id),
      uses_date_1904,
    )
  }
  raw
}

///|
fn xlsx_semantic_type_for_style(
  raw : String,
  style_index : Int,
  styles : XlsxStyles,
) -> String {
  let num_fmt_id = xlsx_style_numfmt(styles, style_index)
  if num_fmt_id < 0 {
    return "number"
  }
  if xlsx_numfmt_is_datetime_like(num_fmt_id, styles) {
    let lower = styles.custom_numfmts.get(num_fmt_id).unwrap_or("").to_lower()
    if lower.contains("h") ||
      num_fmt_id == 20 ||
      num_fmt_id == 21 ||
      num_fmt_id == 45 ||
      num_fmt_id == 46 ||
      num_fmt_id == 47 {
      if lower.contains("y") || lower.contains("d") || num_fmt_id == 22 {
        "datetime"
      } else {
        "time"
      }
    } else {
      "date"
    }
  } else if raw.trim() == "" {
    "blank"
  } else {
    "number"
  }
}

///|
fn xlsx_parse_inline_string(inner : String) -> String? {
  let start0 = xlsx_find_sub(inner, "<is", 0)
  match start0 {
    None => {
      let text = xlsx_concat_text_runs(inner)
      if text == "" {
        None
      } else {
        Some(text)
      }
    }
    Some(i0) => {
      let end0 = xlsx_find_sub(inner, "</is>", i0)
      match end0 {
        Some(i1) => {
          let text = xlsx_concat_text_runs(inner[i0:i1].to_owned())
          if text == "" {
            None
          } else {
            Some(text)
          }
        }
        None => {
          let text = xlsx_concat_text_runs(inner)
          if text == "" {
            None
          } else {
            Some(text)
          }
        }
      }
    }
  }
}

///|
fn xlsx_concat_text_runs(inner : String) -> String {
  let mut out = ""
  let mut pos = 0
  while true {
    let t0 = xlsx_find_sub(inner, "<t", pos)
    match t0 {
      None => break
      Some(start0) => {
        let next_char = if start0 + 2 < inner.length() {
          Some(inner[start0 + 2])
        } else {
          None
        }
        match next_char {
          Some(ch) =>
            if ch != '>' && ch != ' ' && ch != '\n' && ch != '\r' && ch != '\t' {
              pos = start0 + 2
              continue
            }
          None => {
            pos = start0 + 2
            continue
          }
        }
        let tag1 = xlsx_find_sub(inner, ">", start0)
        match tag1 {
          None => break
          Some(start1) => {
            let end0 = xlsx_find_sub(inner, "</t>", start1 + 1)
            match end0 {
              None => break
              Some(end1) => {
                out = out + xlsx_xml_unescape(inner[start1 + 1:end1].to_owned())
                pos = end1 + 4
              }
            }
          }
        }
      }
    }
  }
  out
}

///|
fn xlsx_parse_comments_part(
  pkg : @ox.OoxmlPackage,
  part_name : String,
) -> Array[XlsxComment] raise @ox.OoxmlError {
  let xml = @ox.read_part_text(pkg, part_name)
  let authors = xlsx_comment_authors(xml)
  let out : Array[XlsxComment] = []
  let mut pos = 0
  while true {
    let next = xlsx_find_sub(xml, "<comment", pos)
    match next {
      None => break
      Some(start0) => {
        let next_char = if start0 + 8 < xml.length() {
          Some(xml[start0 + 8])
        } else {
          None
        }
        match next_char {
          Some(ch) =>
            if ch != '>' && ch != ' ' && ch != '\n' && ch != '\r' && ch != '\t' {
              pos = start0 + 8
              continue
            }
          None => {
            pos = start0 + 8
            continue
          }
        }
        let tag1 = xlsx_find_sub(xml, ">", start0)
        match tag1 {
          None => break
          Some(start1) => {
            let tag = xml[start0:start1 + 1].to_owned()
            let end0 = xlsx_find_sub(xml, "</comment>", start1 + 1)
            match end0 {
              None => break
              Some(end1) => {
                let inner = xml[start1 + 1:end1].to_owned()
                let cell_ref = xlsx_get_attr(tag, "ref").unwrap_or("")
                let author_id = xlsx_parse_int(
                  xlsx_get_attr(tag, "authorId").unwrap_or(""),
                )
                let author = if author_id >= 0 && author_id < authors.length() {
                  let name = authors[author_id].trim().to_owned()
                  if name == "" {
                    None
                  } else {
                    Some(name)
                  }
                } else {
                  None
                }
                let text = xlsx_concat_text_runs(inner).trim().to_owned()
                let normalized = xlsx_comment_strip_author_prefix(author, text)
                if cell_ref != "" && normalized != "" {
                  out.push({ cell_ref, author, text: normalized })
                }
                pos = end1 + 10
              }
            }
          }
        }
      }
    }
  }
  out
}

///|
fn xlsx_comment_authors(xml : String) -> Array[String] {
  let out : Array[String] = []
  let mut pos = 0
  while true {
    let next = xlsx_find_sub(xml, "<author>", pos)
    match next {
      None => break
      Some(start0) => {
        let end0 = xlsx_find_sub(xml, "</author>", start0 + 8)
        match end0 {
          None => break
          Some(end1) => {
            out.push(xlsx_xml_unescape(xml[start0 + 8:end1].to_owned()))
            pos = end1 + 9
          }
        }
      }
    }
  }
  out
}

///|
fn xlsx_comment_strip_author_prefix(author : String?, text : String) -> String {
  let trimmed = text.trim().to_owned()
  match author {
    Some(name) =>
      if name.trim() != "" && trimmed.has_prefix(name + ":") {
        trimmed[name.length() + 1:].trim().to_owned()
      } else {
        trimmed
      }
    None => trimmed
  }
}

///|
fn xlsx_effective_bounds(
  dimension_ref : String?,
  cells : Array[XlsxCell],
  hidden_rows : Map[Int, Bool],
  max_rows : Int,
  max_cols : Int,
  max_cells : Int,
) -> (Int, Int, Int, Int, Bool, Bool) {
  let base_bounds = match
    xlsx_bounds_from_visible_cells(cells, hidden_rows, true) {
    Some(bounds) => Some(bounds)
    None =>
      match dimension_ref {
        Some(value) => xlsx_parse_range_ref(value)
        None => xlsx_bounds_from_visible_cells(cells, hidden_rows, false)
      }
  }
  match base_bounds {
    None => (0, 0, 0, 0, false, true)
    Some((min_row0, min_col0, max_row0, max_col0)) => {
      if cells.length() == 0 {
        return (0, 0, 0, 0, false, true)
      }
      let mut clipped = false
      let min_row = min_row0
      let min_col = min_col0
      let mut max_row = max_row0
      let mut max_col = max_col0
      if max_row - min_row + 1 > max_rows {
        max_row = min_row + max_rows - 1
        clipped = true
      }
      if max_col - min_col + 1 > max_cols {
        max_col = min_col + max_cols - 1
        clipped = true
      }
      let width = max_col - min_col + 1
      if width > 0 && max_cells > 0 {
        let max_rows_by_cells = if max_cells / width > 0 {
          max_cells / width
        } else {
          1
        }
        let effective_rows = max_row - min_row + 1
        if effective_rows > max_rows_by_cells {
          max_row = min_row + max_rows_by_cells - 1
          clipped = true
        }
      }
      (min_row, min_col, max_row, max_col, clipped, false)
    }
  }
}

///|
fn xlsx_sheet_is_effectively_empty(
  base_is_empty : Bool,
  non_empty_cell_count : Int,
  formula_count : Int,
) -> Bool {
  base_is_empty || (non_empty_cell_count == 0 && formula_count == 0)
}

///|
fn xlsx_bounds_from_visible_cells(
  cells : Array[XlsxCell],
  hidden_rows : Map[Int, Bool],
  semantic_only : Bool,
) -> (Int, Int, Int, Int)? {
  let mut found = false
  let mut min_row = 0
  let mut min_col = 0
  let mut max_row = 0
  let mut max_col = 0
  for cell in cells {
    if xlsx_row_is_hidden(hidden_rows, cell.row_index) {
      continue
    }
    if semantic_only && !xlsx_cell_has_semantic_content(cell) {
      continue
    }
    if !found {
      found = true
      min_row = cell.row_index
      min_col = cell.column_index
      max_row = cell.row_index
      max_col = cell.column_index
      continue
    }
    if cell.row_index < min_row {
      min_row = cell.row_index
    }
    if cell.column_index < min_col {
      min_col = cell.column_index
    }
    if cell.row_index > max_row {
      max_row = cell.row_index
    }
    if cell.column_index > max_col {
      max_col = cell.column_index
    }
  }
  if !found {
    None
  } else {
    Some((min_row, min_col, max_row, max_col))
  }
}

///|
fn xlsx_row_is_hidden(hidden_rows : Map[Int, Bool], row_index : Int) -> Bool {
  match hidden_rows.get(row_index) {
    Some(value) => value
    None => false
  }
}

///|
fn xlsx_cell_has_semantic_content(cell : XlsxCell) -> Bool {
  cell.display_text.trim() != "" || cell.formula_text is Some(_)
}

///|
fn xlsx_visible_row_count(
  hidden_rows : Map[Int, Bool],
  min_row : Int,
  max_row : Int,
) -> Int {
  if min_row > max_row {
    return 0
  }
  let mut count = 0
  let mut row = min_row
  while row <= max_row {
    if !xlsx_row_is_hidden(hidden_rows, row) {
      count += 1
    }
    row += 1
  }
  count
}

///|
fn xlsx_filter_merge_ranges(
  ranges : Array[String],
  min_row : Int,
  min_col : Int,
  max_row : Int,
  max_col : Int,
  is_empty : Bool,
) -> Array[String] {
  if is_empty {
    return []
  }
  let out : Array[String] = []
  for range_ref in ranges {
    match xlsx_parse_range_ref(range_ref) {
      Some((r1, c1, r2, c2)) =>
        if !(r2 < min_row || r1 > max_row || c2 < min_col || c1 > max_col) {
          out.push(range_ref)
        }
      None => ()
    }
  }
  out
}

///|
fn xlsx_fill_merge_lookup(
  lookup : Map[String, String],
  ranges : Array[String],
) -> Unit {
  for range_ref in ranges {
    match xlsx_parse_range_ref(range_ref) {
      Some((r1, c1, r2, c2)) => {
        let mut row = r1
        while row <= r2 {
          let mut col = c1
          while col <= c2 {
            lookup.set(xlsx_lookup_key(row, col), range_ref)
            col += 1
          }
          row += 1
        }
      }
      None => ()
    }
  }
}

///|
fn xlsx_lower_workbook_document(
  source : @input.InputSource,
  workbook : XlsxWorkbook,
  diagnostics : @core.Diagnostics,
) -> @core.DocumentIR {
  let document = @core.empty_document_ir()
  document.metadata.set(
    "source_name",
    @core.JsonValue::String(source.source_name),
  )
  document.metadata.set("format", @core.JsonValue::String("xlsx"))
  document.metadata.set(
    "workbook_part",
    @core.JsonValue::String(workbook.workbook_part),
  )
  document.metadata.set(
    "sheet_count",
    @core.JsonValue::Number(workbook.sheet_count.to_string()),
  )
  document.metadata.set(
    "visible_sheet_count",
    @core.JsonValue::Number(workbook.visible_sheet_count.to_string()),
  )
  document.metadata.set(
    "shared_string_count",
    @core.JsonValue::Number(workbook.shared_strings.length().to_string()),
  )

  let mut block_index = 0
  for sheet in workbook.sheets {
    let heading_ref = xlsx_sheet_heading_source_ref(source.source_name, sheet)
    let heading = @core.make_block(
      @core.BlockKind::Heading,
      sheet.sheet_name,
      source_ref=heading_ref,
    )
    heading.attrs.set("level", "2")
    document.blocks.push(heading)
    block_index += 1

    if sheet.is_empty {
      let raw = @core.make_block(
        @core.BlockKind::Raw,
        "(empty sheet)",
        source_ref=xlsx_sheet_table_source_ref(source.source_name, sheet),
      )
      raw.attrs.set("raw_kind", "xlsx_empty_sheet")
      document.blocks.push(raw)
      block_index += 1
      continue
    }

    let table = @core.make_block(
      @core.BlockKind::Table,
      "table",
      source_ref=xlsx_sheet_table_source_ref(source.source_name, sheet),
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
      let row_block = @core.make_block(
        @core.BlockKind::TableRow,
        "",
        source_ref=xlsx_row_source_ref(source.source_name, sheet, row),
      )
      let mut col = sheet.min_col
      while col <= sheet.max_col {
        let key = xlsx_lookup_key(row, col)
        let merge_range = sheet.merged_lookup.get(key)
        match sheet.cell_lookup.get(key) {
          Some(cell) => {
            let source_ref = match merge_range {
              Some(range_ref) =>
                @core.source_ref_with_extra(
                  cell.source_ref,
                  "merge_range",
                  range_ref,
                )
              None => cell.source_ref
            }
            row_block.children.push(
              @core.make_block(
                @core.BlockKind::TableCell,
                cell.display_text,
                source_ref~,
              ),
            )
          }
          None => {
            let cell_ref = xlsx_rc_to_cell_ref(row, col)
            let source_ref = xlsx_blank_cell_source_ref(
              source.source_name,
              sheet,
              cell_ref,
              row,
              col,
              merge_range,
            )
            row_block.children.push(
              @core.make_block(@core.BlockKind::TableCell, "", source_ref~),
            )
          }
        }
        col += 1
      }
      table.children.push(row_block)
      row += 1
    }
    document.blocks.push(table)
    block_index += 1
    xlsx_append_sheet_comments(document.blocks, source.source_name, sheet)
    ignore(block_index)
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
  document
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
fn xlsx_comment_item_text(comment : XlsxComment) -> String {
  match comment.author {
    Some(author) =>
      if author.trim() == "" {
        comment.cell_ref + ": " + comment.text
      } else {
        comment.cell_ref + " (" + author + "): " + comment.text
      }
    None => comment.cell_ref + ": " + comment.text
  }
}

///|
fn xlsx_row_source_ref(
  source_name : String,
  sheet : XlsxSheet,
  row_index : Int,
) -> @core.SourceRef {
  @core.source_ref_with_extra(
    xlsx_sheet_table_source_ref(source_name, sheet),
    "row_index",
    row_index.to_string(),
  )
}

///|
fn xlsx_cell_source_ref(
  sheet_info : XlsxSheetInfo,
  cell_ref : String,
  row_index : Int,
  column_index : Int,
  formula_text : String?,
  style_id : String?,
  shared_string_index : Int?,
  merge_range : String?,
) -> @core.SourceRef {
  let base = @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some(sheet_info.sheet_name),
    Some("xlsx"),
    Some(sheet_info.sheet_name),
    Some(sheet_info.part_name),
    None,
    Some("xlsx"),
    Some(
      "/worksheet/sheetData/row[" +
      row_index.to_string() +
      "]/c[" +
      cell_ref +
      "]",
    ),
  )
  let office = @core.source_ref_with_office_fields(
    base,
    Some(sheet_info.sheet_name),
    Some("xlsx"),
    Some(
      "/worksheet/sheetData/row[" +
      row_index.to_string() +
      "]/c[" +
      cell_ref +
      "]",
    ),
    Some(sheet_info.sheet_name),
    Some(cell_ref),
    None,
    None,
    Some(sheet_info.relationship_id),
  )
  let mut source_ref = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.source_ref_with_extra(
        @core.source_ref_with_extra(
          @core.source_ref_with_extra(
            @core.source_ref_with_extra(
              office,
              "part_name",
              sheet_info.part_name,
            ),
            "sheet_name",
            sheet_info.sheet_name,
          ),
          "sheet_visibility",
          @shared.xlsx_sheet_visibility_name(sheet_info.visibility),
        ),
        "cell_ref",
        cell_ref,
      ),
      "row_index",
      row_index.to_string(),
    ),
    "column_index",
    column_index.to_string(),
  )
  source_ref = @core.source_ref_with_extra(
    source_ref,
    "relationship_id",
    sheet_info.relationship_id,
  )
  match sheet_info.sheet_id {
    Some(value) =>
      source_ref = @core.source_ref_with_extra(source_ref, "sheet_id", value)
    None => ()
  }
  match formula_text {
    Some(_) =>
      source_ref = @core.source_ref_with_extra(
        source_ref, "formula_ref", cell_ref,
      )
    None => ()
  }
  match style_id {
    Some(value) =>
      if value.trim() != "" {
        source_ref = @core.source_ref_with_extra(source_ref, "style_id", value)
      }
    None => ()
  }
  match shared_string_index {
    Some(value) =>
      source_ref = @core.source_ref_with_extra(
        source_ref,
        "shared_string_index",
        value.to_string(),
      )
    None => ()
  }
  match merge_range {
    Some(value) =>
      source_ref = @core.source_ref_with_extra(source_ref, "merge_range", value)
    None => ()
  }
  source_ref
}

///|
fn xlsx_blank_cell_source_ref(
  source_name : String,
  sheet : XlsxSheet,
  cell_ref : String,
  row_index : Int,
  column_index : Int,
  merge_range : String?,
) -> @core.SourceRef {
  let info : XlsxSheetInfo = {
    sheet_name: sheet.sheet_name,
    sheet_id: sheet.sheet_id,
    relationship_id: sheet.relationship_id,
    part_name: sheet.part_name,
    visibility: sheet.visibility,
  }
  ignore(source_name)
  xlsx_cell_source_ref(
    info,
    cell_ref,
    row_index,
    column_index,
    None,
    None,
    None,
    merge_range,
  )
}

///|
fn xlsx_merged_cell_area(ranges : Array[String]) -> Int {
  let mut total = 0
  for range_ref in ranges {
    match xlsx_parse_range_ref(range_ref) {
      Some((r1, c1, r2, c2)) => total += (r2 - r1 + 1) * (c2 - c1 + 1)
      None => ()
    }
  }
  total
}

///|
fn xlsx_lookup_key(row_index : Int, column_index : Int) -> String {
  row_index.to_string() + "," + column_index.to_string()
}

///|
fn xlsx_parse_range_ref(range_ref : String) -> (Int, Int, Int, Int)? {
  let parts = range_ref.split(":").to_array()
  if parts.length() == 1 {
    let (row, col) = xlsx_cell_ref_to_rc(parts[0].to_owned())
    if row > 0 && col > 0 {
      Some((row, col, row, col))
    } else {
      None
    }
  } else if parts.length() == 2 {
    let (r1, c1) = xlsx_cell_ref_to_rc(parts[0].to_owned())
    let (r2, c2) = xlsx_cell_ref_to_rc(parts[1].to_owned())
    if r1 > 0 && c1 > 0 && r2 > 0 && c2 > 0 {
      Some((r1, c1, r2, c2))
    } else {
      None
    }
  } else {
    None
  }
}

///|
fn xlsx_cell_ref_to_rc(reference : String) -> (Int, Int) {
  let chars = reference.trim().to_array()
  let mut col = 0
  let mut i = 0
  while i < chars.length() {
    let ch = chars[i]
    if ch == '$' {
      i += 1
      continue
    }
    if (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') {
      let upper = if ch >= 'a' && ch <= 'z' {
        ch.to_int() - 'a'.to_int() + 'A'.to_int()
      } else {
        ch.to_int()
      }
      col = col * 26 + (upper - 'A'.to_int() + 1)
      i += 1
    } else {
      break
    }
  }
  let mut row = 0
  while i < chars.length() {
    let ch = chars[i]
    if ch == '$' {
      i += 1
      continue
    }
    if ch >= '0' && ch <= '9' {
      row = row * 10 + (ch.to_int() - '0'.to_int())
      i += 1
    } else {
      return (0, 0)
    }
  }
  (row, col)
}

///|
fn xlsx_rc_to_cell_ref(row : Int, col : Int) -> String {
  if row <= 0 || col <= 0 {
    return ""
  }
  let out : Array[String] = []
  let mut current = col
  while current > 0 {
    let rem = (current - 1) % 26
    out.push(String::from_array([Int::unsafe_to_char('A'.to_int() + rem)]))
    current = (current - 1) / 26
  }
  let rev : Array[String] = []
  let mut i = out.length() - 1
  while i >= 0 {
    rev.push(out[i])
    if i == 0 {
      break
    }
    i -= 1
  }
  rev.join("") + row.to_string()
}

///|
fn xlsx_parse_int(text : String) -> Int {
  @string.parse_int(text.trim().to_owned()) catch {
    _ => -1
  }
}

///|
fn xlsx_find_sub(text : String, pattern : String, start : Int) -> Int? {
  let n = text.length()
  let m = pattern.length()
  if m == 0 {
    return Some(start)
  }
  if start < 0 || start >= n || n < m {
    return None
  }
  let last = n - m
  let mut i = start
  while i <= last {
    if text[i:i + m] == pattern {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn xlsx_get_attr(tag : String, key : String) -> String? {
  let pattern = key + "=\""
  let start0 = xlsx_find_sub(tag, pattern, 0)
  match start0 {
    None => None
    Some(i0) => {
      let value_start = i0 + pattern.length()
      let end0 = xlsx_find_sub(tag, "\"", value_start)
      match end0 {
        None => None
        Some(i1) => Some(tag[value_start:i1].to_owned())
      }
    }
  }
}

///|
fn xlsx_extract_tag(xml : String, name : String) -> (String, String)? {
  let open = "<" + name
  let tag0 = xlsx_find_sub(xml, open, 0)
  match tag0 {
    None => None
    Some(start0) => {
      let tag1 = xlsx_find_sub(xml, ">", start0)
      match tag1 {
        None => None
        Some(start1) => {
          let tag = xml[start0:start1 + 1].to_owned()
          let end0 = xlsx_find_sub(xml, "</" + name + ">", start1 + 1)
          match end0 {
            Some(end1) =>
              Some((tag, xlsx_xml_unescape(xml[start1 + 1:end1].to_owned())))
            None => if tag.has_suffix("/>") { Some((tag, "")) } else { None }
          }
        }
      }
    }
  }
}

///|
fn xlsx_tag_text(xml : String, name : String) -> String? {
  match xlsx_extract_tag(xml, name) {
    Some((_, text)) => Some(text)
    None => None
  }
}

///|
fn xlsx_xml_unescape(text : String) -> String {
  let basic = text
    .replace(old="&lt;", new="<")
    .replace(old="&gt;", new=">")
    .replace(old="&amp;", new="&")
    .replace(old="&quot;", new="\"")
    .replace(old="&apos;", new="'")
  xlsx_decode_numeric_entities(basic)
}

///|
fn xlsx_decode_numeric_entities(text : String) -> String {
  let chars = text.to_array()
  let out : Array[Char] = []
  let mut i = 0
  while i < chars.length() {
    if i + 2 < chars.length() && chars[i] == '&' && chars[i + 1] == '#' {
      let mut j = i + 2
      while j < chars.length() && chars[j] != ';' {
        j += 1
      }
      if j < chars.length() && chars[j] == ';' {
        let body = String::from_array(chars[i + 2:j]).trim().to_owned()
        let codepoint = if body.has_prefix("x") || body.has_prefix("X") {
          xlsx_parse_hex_int(body[1:].to_owned())
        } else {
          xlsx_parse_dec_int(body)
        }
        match codepoint {
          Some(value) => {
            out.push(Int::unsafe_to_char(value))
            i = j + 1
            continue
          }
          None => ()
        }
      }
    }
    out.push(chars[i])
    i += 1
  }
  String::from_array(out)
}

///|
fn xlsx_parse_dec_int(text : String) -> Int? {
  if text == "" {
    return None
  }
  let chars = text.to_array()
  let mut value = 0
  let mut i = 0
  while i < chars.length() {
    let ch = chars[i]
    if ch < '0' || ch > '9' {
      return None
    }
    value = value * 10 + (ch.to_int() - '0'.to_int())
    i += 1
  }
  Some(value)
}

///|
fn xlsx_parse_hex_int(text : String) -> Int? {
  if text == "" {
    return None
  }
  let chars = text.to_array()
  let mut value = 0
  let mut i = 0
  while i < chars.length() {
    let ch = chars[i]
    let digit = if ch >= '0' && ch <= '9' {
      ch.to_int() - '0'.to_int()
    } else if ch >= 'a' && ch <= 'f' {
      ch.to_int() - 'a'.to_int() + 10
    } else if ch >= 'A' && ch <= 'F' {
      ch.to_int() - 'A'.to_int() + 10
    } else {
      return None
    }
    value = value * 16 + digit
    i += 1
  }
  Some(value)
}

///|
fn xlsx_style_numfmt(styles : XlsxStyles, style_index : Int) -> Int {
  if style_index < 0 || style_index >= styles.xf_numfmts.length() {
    -1
  } else {
    styles.xf_numfmts[style_index]
  }
}

///|
fn xlsx_numfmt_is_datetime_like(num_fmt_id : Int, styles : XlsxStyles) -> Bool {
  if xlsx_builtin_datetime_numfmt(num_fmt_id) {
    return true
  }
  match styles.custom_numfmts.get(num_fmt_id) {
    Some(code) => xlsx_datetime_code_like(code)
    None => false
  }
}

///|
fn xlsx_builtin_datetime_numfmt(num_fmt_id : Int) -> Bool {
  num_fmt_id == 14 ||
  num_fmt_id == 15 ||
  num_fmt_id == 16 ||
  num_fmt_id == 17 ||
  num_fmt_id == 18 ||
  num_fmt_id == 19 ||
  num_fmt_id == 20 ||
  num_fmt_id == 21 ||
  num_fmt_id == 22 ||
  num_fmt_id == 45 ||
  num_fmt_id == 46 ||
  num_fmt_id == 47
}

///|
fn xlsx_datetime_code_like(code : String) -> Bool {
  let lower = code.to_lower()
  if lower.contains("[h]") || lower.contains("h") || lower.contains("s") {
    return true
  }
  lower.contains("y") || lower.contains("d") || lower.contains("m")
}

///|
fn xlsx_format_excel_datetime(
  raw : String,
  num_fmt_id : Int,
  custom_code : String?,
  uses_date_1904 : Bool,
) -> String {
  match xlsx_parse_excel_serial(raw) {
    None => raw
    Some((days, frac_num, frac_den)) => {
      let (carry, hh, mm, ss) = xlsx_frac_to_hms(frac_num, frac_den)
      let serial_day = days + carry
      let lower = custom_code.unwrap_or("").to_lower()
      let is_date_only = if custom_code is Some(_) {
        (lower.contains("y") || lower.contains("d")) &&
        !lower.contains("h") &&
        !lower.contains("s")
      } else {
        num_fmt_id == 14 ||
        num_fmt_id == 15 ||
        num_fmt_id == 16 ||
        num_fmt_id == 17
      }
      let is_time_only = if custom_code is Some(_) {
        !lower.contains("y") &&
        !lower.contains("d") &&
        (lower.contains("h") || lower.contains("s"))
      } else {
        num_fmt_id == 18 ||
        num_fmt_id == 19 ||
        num_fmt_id == 20 ||
        num_fmt_id == 21 ||
        num_fmt_id == 45 ||
        num_fmt_id == 46 ||
        num_fmt_id == 47
      }
      let is_datetime = if custom_code is Some(_) {
        (lower.contains("y") || lower.contains("d")) &&
        (lower.contains("h") || lower.contains("s"))
      } else {
        num_fmt_id == 22
      }
      if is_time_only {
        return xlsx_pad2(hh) + ":" + xlsx_pad2(mm) + ":" + xlsx_pad2(ss)
      }
      let (year, month, day) = xlsx_excel_serial_to_ymd(
        serial_day, uses_date_1904,
      )
      if is_date_only && !is_datetime {
        return xlsx_pad4(year) + "-" + xlsx_pad2(month) + "-" + xlsx_pad2(day)
      }
      if is_datetime || frac_num != 0 {
        return xlsx_pad4(year) +
          "-" +
          xlsx_pad2(month) +
          "-" +
          xlsx_pad2(day) +
          " " +
          xlsx_pad2(hh) +
          ":" +
          xlsx_pad2(mm) +
          ":" +
          xlsx_pad2(ss)
      }
      xlsx_pad4(year) + "-" + xlsx_pad2(month) + "-" + xlsx_pad2(day)
    }
  }
}

///|
fn xlsx_parse_excel_serial(text : String) -> (Int, Int, Int)? {
  let trimmed = text.trim()
  if trimmed == "" {
    return None
  }
  let chars = trimmed.to_array()
  let mut i = 0
  let n = chars.length()
  if i < n && (chars[i] == '-' || chars[i] == '+') {
    return None
  }
  let mut days = 0
  let mut has_int = false
  while i < n {
    let ch = chars[i]
    if ch >= '0' && ch <= '9' {
      days = days * 10 + (ch.to_int() - '0'.to_int())
      has_int = true
      i += 1
    } else {
      break
    }
  }
  if i == n {
    if has_int {
      Some((days, 0, 1))
    } else {
      None
    }
  } else if chars[i] != '.' {
    None
  } else {
    i += 1
    let mut frac_num = 0
    let mut frac_den = 1
    let mut has_frac = false
    let mut digits = 0
    while i < n {
      let ch = chars[i]
      if ch >= '0' && ch <= '9' {
        if digits < 6 {
          frac_num = frac_num * 10 + (ch.to_int() - '0'.to_int())
          frac_den = frac_den * 10
          digits += 1
        }
        has_frac = true
        i += 1
      } else {
        return None
      }
    }
    if !has_int && !has_frac {
      None
    } else {
      Some((days, frac_num, frac_den))
    }
  }
}

///|
fn xlsx_frac_to_hms(frac_num : Int, frac_den : Int) -> (Int, Int, Int, Int) {
  if frac_den <= 0 || frac_num <= 0 {
    return (0, 0, 0, 0)
  }
  let hh = frac_num * 24 / frac_den
  let rem_h = frac_num * 24 % frac_den
  let mm = rem_h * 60 / frac_den
  let rem_m = rem_h * 60 % frac_den
  let mut ss = (rem_m * 60 + frac_den / 2) / frac_den
  let mut hh2 = hh
  let mut mm2 = mm
  let mut carry = 0
  if ss >= 60 {
    ss -= 60
    mm2 += 1
  }
  if mm2 >= 60 {
    mm2 -= 60
    hh2 += 1
  }
  if hh2 >= 24 {
    hh2 -= 24
    carry = 1
  }
  (carry, hh2, mm2, ss)
}

///|
fn xlsx_excel_serial_to_ymd(
  serial : Int,
  uses_date_1904 : Bool,
) -> (Int, Int, Int) {
  if uses_date_1904 {
    return xlsx_excel_serial_to_ymd_1904(serial)
  }
  if serial <= 0 {
    return (1899, 12, 30)
  }
  if serial == 60 {
    return (1900, 2, 29)
  }
  let mut year = 1900
  let mut month = 1
  let mut day = 1
  let mut days_left = if serial < 60 { serial - 1 } else { serial - 2 }
  while true {
    let days_in_year = if xlsx_is_leap_year(year) { 366 } else { 365 }
    if days_left >= days_in_year {
      days_left -= days_in_year
      year += 1
    } else {
      break
    }
  }
  while true {
    let dim = xlsx_days_in_month(year, month)
    if days_left >= dim {
      days_left -= dim
      month += 1
    } else {
      break
    }
  }
  day += days_left
  (year, month, day)
}

///|
fn xlsx_excel_serial_to_ymd_1904(serial : Int) -> (Int, Int, Int) {
  if serial < 0 {
    return (1903, 12, 31)
  }
  let mut year = 1904
  let mut month = 1
  let mut day = 1
  let mut days_left = serial
  while true {
    let days_in_year = if xlsx_is_leap_year(year) { 366 } else { 365 }
    if days_left >= days_in_year {
      days_left -= days_in_year
      year += 1
    } else {
      break
    }
  }
  while true {
    let dim = xlsx_days_in_month(year, month)
    if days_left >= dim {
      days_left -= dim
      month += 1
    } else {
      break
    }
  }
  day += days_left
  (year, month, day)
}

///|
fn xlsx_is_leap_year(year : Int) -> Bool {
  if year % 400 == 0 {
    true
  } else if year % 100 == 0 {
    false
  } else {
    year % 4 == 0
  }
}

///|
fn xlsx_days_in_month(year : Int, month : Int) -> Int {
  if month == 1 ||
    month == 3 ||
    month == 5 ||
    month == 7 ||
    month == 8 ||
    month == 10 ||
    month == 12 {
    31
  } else if month == 4 || month == 6 || month == 9 || month == 11 {
    30
  } else if xlsx_is_leap_year(year) {
    29
  } else {
    28
  }
}

///|
fn xlsx_pad2(value : Int) -> String {
  if value < 10 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn xlsx_pad4(value : Int) -> String {
  let text = value.to_string()
  if text.length() >= 4 {
    text
  } else if text.length() == 3 {
    "0" + text
  } else if text.length() == 2 {
    "00" + text
  } else {
    "000" + text
  }
}
