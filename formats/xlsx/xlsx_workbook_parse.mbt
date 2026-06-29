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
    @parser.ParserMode::PackageSinglePass,
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
  source_ref : @core.SourceRef?
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
priv struct XlsxParsedSheetView {
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
  hidden_rows : Map[Int, Bool]
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
  cells : Array[XlsxCell]
  first_cell_index : Int
  last_cell_index_exclusive : Int
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
priv struct XlsxWorkbookSharedState {
  workbook_part : String
  sheet_infos : Array[XlsxSheetInfo]
  shared_strings : Array[String]
  styles : XlsxStyles
  uses_date_1904 : Bool
}

///|
fn xlsx_init_diagnostics(
  diagnostics : @core.Diagnostics,
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Unit {
  diagnostics.metrics.set("parser_name", "xlsx_parser")
  diagnostics.metrics.set("parser_mode", "package_single_pass")
  diagnostics.metrics.set(
    "input_kind",
    @parser_common.input_kind_name(source.kind),
  )
  diagnostics.metrics.set("detected_format", "xlsx")
  diagnostics.metrics.set(
    "requested_mode",
    @parser_common.requested_mode_name(context),
  )
  diagnostics.metrics.set("effective_mode", "package_single_pass")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("event_granularity", "xlsx_sheet")
  diagnostics.metrics.set("event_semantics", "package_single_pass")
  diagnostics.metrics.set("office_document_kind", "xlsx")
  diagnostics.metrics.set("product_path_enabled", "true")
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
  diagnostics.metrics.set("native_impl_location", "formats/xlsx")
  @parser_common.apply_product_metrics(diagnostics, "xlsx")
}

///|
fn xlsx_parse_workbook(
  pkg : @ox.OoxmlPackage,
  diagnostics : @core.Diagnostics,
  context : @parser.ParseContext,
) -> XlsxWorkbook raise @ox.OoxmlError {
  let shared = xlsx_load_workbook_shared_state(pkg)
  let max_rows = context.max_rows.unwrap_or(2000)
  let max_cols = context.max_cols.unwrap_or(50)
  let max_cells = context.max_cells.unwrap_or(100000)
  let max_sheets = 200

  let included_sheets : Array[XlsxSheet] = []
  let effective_sheet_infos = if shared.sheet_infos.length() > max_sheets {
    diagnostics.warnings.push(
      "xlsx sheet count exceeded limit; remaining sheets were skipped",
    )
    diagnostics.degraded_features.push("xlsx_sheets_truncated")
    diagnostics.metrics.set("resource_limit_hit", "true")
    shared.sheet_infos[:max_sheets]
  } else {
    shared.sheet_infos[:]
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
          pkg,
          sheet_info,
          shared.shared_strings,
          shared.styles,
          shared.uses_date_1904,
          max_rows,
          max_cols,
          max_cells,
          diagnostics,
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
    workbook_part: shared.workbook_part,
    sheets: included_sheets,
    shared_strings: shared.shared_strings,
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
    style_count: shared.styles.xf_numfmts.length(),
    drawing_count,
    image_count,
    external_link_count,
  }
}

///|
fn xlsx_load_workbook_shared_state(
  pkg : @ox.OoxmlPackage,
) -> XlsxWorkbookSharedState raise @ox.OoxmlError {
  let workbook_part = xlsx_resolve_workbook_part(pkg)
  let workbook_payload = @ox.read_xml_part_payload(pkg, workbook_part)
  let shared_strings = if @ox.has_part(pkg, "xl/sharedStrings.xml") {
    let shared_payload = @ox.read_xml_part_payload(pkg, "xl/sharedStrings.xml")
    xlsx_parse_shared_strings(shared_payload.text)
  } else {
    []
  }
  let styles = if @ox.has_part(pkg, "xl/styles.xml") {
    let styles_payload = @ox.read_xml_part_payload(pkg, "xl/styles.xml")
    xlsx_parse_styles(styles_payload.text)
  } else {
    { xf_numfmts: [], custom_numfmts: Map([]) }
  }
  let uses_date_1904 = xlsx_workbook_uses_date_1904(workbook_payload.text)
  let sheet_infos = xlsx_parse_sheet_infos(
    pkg,
    workbook_part,
    workbook_payload.text,
  )
  { workbook_part, sheet_infos, shared_strings, styles, uses_date_1904 }
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
  build_cell_source_refs? : Bool = true,
) -> XlsxSheet raise @ox.OoxmlError {
  let view = xlsx_parse_sheet_view(
    pkg,
    sheet_info,
    shared_strings,
    styles,
    uses_date_1904,
    max_rows,
    max_cols,
    max_cells,
    diagnostics,
    build_cell_source_refs~,
  )
  let cell_lookup : Map[String, XlsxCell] = Map([])
  let merged_lookup : Map[String, String] = Map([])
  if !view.is_empty {
    xlsx_fill_merge_lookup(merged_lookup, view.merged_ranges)
    for cell in view.cells {
      cell_lookup.set(xlsx_lookup_key(cell.row_index, cell.column_index), cell)
    }
  }

  {
    sheet_name: view.sheet_name,
    sheet_id: view.sheet_id,
    relationship_id: view.relationship_id,
    part_name: view.part_name,
    visibility: view.visibility,
    dimension_ref: view.dimension_ref,
    min_row: view.min_row,
    min_col: view.min_col,
    max_row: view.max_row,
    max_col: view.max_col,
    cell_lookup,
    hidden_rows: view.hidden_rows,
    merged_lookup,
    merged_ranges: view.merged_ranges,
    row_count: view.row_count,
    cell_count: view.cell_count,
    non_empty_cell_count: view.non_empty_cell_count,
    formula_count: view.formula_count,
    shared_formula_count: view.shared_formula_count,
    array_formula_count: view.array_formula_count,
    drawing_count: view.drawing_count,
    image_count: view.image_count,
    external_link_count: view.external_link_count,
    comments: view.comments,
    is_empty: view.is_empty,
  }
}

///|
fn xlsx_parse_sheet_view(
  pkg : @ox.OoxmlPackage,
  sheet_info : XlsxSheetInfo,
  shared_strings : Array[String],
  styles : XlsxStyles,
  uses_date_1904 : Bool,
  max_rows : Int,
  max_cols : Int,
  max_cells : Int,
  diagnostics : @core.Diagnostics,
  build_cell_source_refs? : Bool = true,
  prefer_streaming_scan? : Bool = false,
) -> XlsxParsedSheetView raise @ox.OoxmlError {
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

  let parsed_sheet_xml = if prefer_streaming_scan {
    match
      xlsx_parse_sheet_xml_bytes_streaming(
        pkg,
        sheet_info,
        shared_strings,
        styles,
        uses_date_1904,
        max_rows,
        max_cols,
        max_cells,
        build_cell_source_refs~,
      ) {
      Ok(value) => value
      Err(_) => {
        let sheet_xml_bytes = @ox.read_part_bytes_transient(
          pkg,
          sheet_info.part_name,
        )
        xlsx_parse_sheet_xml_bytes(
          sheet_info,
          sheet_xml_bytes,
          shared_strings,
          styles,
          uses_date_1904,
          build_cell_source_refs~,
          cell_window_bounds=None,
        )
      }
    }
  } else {
    let sheet_xml_bytes = @ox.read_part_bytes_transient(
      pkg,
      sheet_info.part_name,
    )
    xlsx_parse_sheet_xml_bytes(
      sheet_info,
      sheet_xml_bytes,
      shared_strings,
      styles,
      uses_date_1904,
      build_cell_source_refs~,
      cell_window_bounds=None,
    )
  }
  let dimension_ref = parsed_sheet_xml.dimension_ref
  let merged_ranges = parsed_sheet_xml.merged_ranges
  let hidden_rows = parsed_sheet_xml.hidden_rows
  let parsed_cells = parsed_sheet_xml.cells
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
    diagnostics.same_mode_degradation.push(
      "xlsx_table_region_clip:" + sheet_info.sheet_name,
    )
  }

  let mut non_empty_cell_count = 0
  let mut formula_count = 0
  let mut shared_formula_count = 0
  let mut array_formula_count = 0
  let mut first_cell_index = -1
  let mut last_cell_index_exclusive = 0
  let parsed_cell_count = parsed_cells.length()
  let mut cell_index = 0
  for cell in parsed_cells {
    if is_empty ||
      xlsx_row_is_hidden(hidden_rows, cell.row_index) ||
      cell.row_index < min_row ||
      cell.row_index > max_row ||
      cell.column_index < min_col ||
      cell.column_index > max_col {
      cell_index += 1
      continue
    }
    if first_cell_index < 0 {
      first_cell_index = cell_index
    }
    last_cell_index_exclusive = cell_index + 1
    if !xlsx_is_blank_text(cell.display_text) {
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
    cell_index += 1
  }

  let effective_is_empty = xlsx_sheet_is_effectively_empty(
    is_empty, non_empty_cell_count, formula_count,
  )
  let filtered_ranges = xlsx_filter_merge_ranges(
    merged_ranges, min_row, min_col, max_row, max_col, effective_is_empty,
  )

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
    hidden_rows,
    merged_ranges: filtered_ranges,
    row_count: if effective_is_empty {
      0
    } else {
      xlsx_visible_row_count(hidden_rows, min_row, max_row)
    },
    cell_count: if effective_is_empty {
      0
    } else {
      parsed_cell_count
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
    cells: parsed_cells,
    first_cell_index: if effective_is_empty || first_cell_index < 0 {
      parsed_cell_count
    } else {
      first_cell_index
    },
    last_cell_index_exclusive: if effective_is_empty {
      parsed_cell_count
    } else {
      last_cell_index_exclusive
    },
  }
}

///|
fn xlsx_parse_sheet_xml_bytes_streaming(
  pkg : @ox.OoxmlPackage,
  sheet_info : XlsxSheetInfo,
  shared_strings : Array[String],
  styles : XlsxStyles,
  uses_date_1904 : Bool,
  _max_rows : Int,
  _max_cols : Int,
  _max_cells : Int,
  build_cell_source_refs? : Bool = true,
) -> Result[XlsxParsedSheetXml, String] {
  let sheet_xml_bytes = try
    @ox.read_part_bytes_transient(pkg, sheet_info.part_name) |> Ok
  catch {
    err => Err(err.to_string())
  }
  let sheet_xml_bytes = match sheet_xml_bytes {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  Ok(
    xlsx_parse_sheet_xml_bytes(
      sheet_info,
      sheet_xml_bytes,
      shared_strings,
      styles,
      uses_date_1904,
      build_cell_source_refs~,
      cell_window_bounds=None,
    ),
  )
}

///|
