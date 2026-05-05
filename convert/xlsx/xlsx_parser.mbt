///|
/// XLSX lower-layer aware parser (MoonBit)
///
/// Product policy:
/// - no formula evaluation
/// - cached values are used when present
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

  let open_started = @env.now()
  let p = open_xlsx(input_path) catch {
    e => raise @cor.AppError("xlsx: open package failed: " + e.to_string())
  }
  xlsx_profile_push_stage(
    profile,
    "zip_package_open",
    @env.now() - open_started,
    None,
  )

  let workbook_started = @env.now()
  let wb_xml = p.read_text_required("xl/workbook.xml")
  xlsx_profile_push_stage(
    profile,
    "workbook_xml_read",
    @env.now() - workbook_started,
    Some("bytes=" + wb_xml.length().to_string()),
  )

  let shared_started = @env.now()
  let shared : Array[String] = if @ox.has_part(p.pkg, "xl/sharedStrings.xml") {
    parse_shared_strings(p.read_text_optional("xl/sharedStrings.xml"))
  } else {
    []
  }
  xlsx_profile_push_stage(
    profile,
    "shared_strings_parse",
    @env.now() - shared_started,
    Some("count=" + shared.length().to_string()),
  )

  let styles_started = @env.now()
  let styles = if @ox.has_part(p.pkg, "xl/styles.xml") {
    parse_styles_xml(p.read_text_optional("xl/styles.xml"))
  } else {
    empty_styles()
  }
  xlsx_profile_push_stage(
    profile,
    "styles_parse",
    @env.now() - styles_started,
    None,
  )

  let workbook_meta_started = @env.now()
  let uses_date_1904 = workbook_uses_date_1904(wb_xml)
  let sheet_infos = parse_workbook_sheets(p.pkg, wb_xml)
  xlsx_profile_push_stage(
    profile,
    "workbook_relationships",
    @env.now() - workbook_meta_started,
    Some("sheet_infos=" + sheet_infos.length().to_string()),
  )
  let sheets : Array[XlsxSheetModel] = []

  for info in sheet_infos {
    let normalized_target = match info.target {
      Some(target) => normalize_sheet_part_target(target)
      None => ""
    }
    if !info.is_supported_worksheet {
      sheets.push(
        empty_sheet_model(
          info.name,
          Some(info._rid),
          info.rel_type,
          if normalized_target == "" {
            None
          } else {
            Some(normalized_target)
          },
          info.state,
          false,
          false,
        ),
      )
      continue
    }

    if normalized_target == "" {
      sheets.push(
        empty_sheet_model(
          info.name,
          Some(info._rid),
          info.rel_type,
          if normalized_target == "" {
            None
          } else {
            Some(normalized_target)
          },
          info.state,
          true,
          false,
        ),
      )
      xlsx_profile_record_sheet(profile, sheets[sheets.length() - 1])
      continue
    }

    let sheet_xml_started = @env.now()
    let read_profiled = p.read_text_required_profiled(normalized_target) catch {
      _ => {
        sheets.push(
          empty_sheet_model(
            info.name,
            Some(info._rid),
            info.rel_type,
            Some(normalized_target),
            info.state,
            true,
            false,
          ),
        )
        xlsx_profile_record_sheet(profile, sheets[sheets.length() - 1])
        continue
      }
    }
    let sh_xml = read_profiled.0
    let read_stats = read_profiled.1
    xlsx_profile_push_stage(
      profile,
      "worksheet_entry_lookup:" + info.name,
      read_stats.entry_lookup_elapsed_ms,
      Some(
        "part=" +
        read_stats.normalized_part_name +
        " hit=" +
        read_stats.part_index_hit.to_string(),
      ),
    )
    xlsx_profile_push_stage(
      profile,
      "worksheet_entry_decompress:" + info.name,
      read_stats.read_entry_elapsed_ms,
      Some("bytes=" + read_stats.byte_len.to_string()),
    )
    xlsx_profile_push_stage(
      profile,
      "worksheet_bytes_to_string:" + info.name,
      read_stats.bytes_to_string_elapsed_ms,
      Some("text_bytes=" + read_stats.text_len.to_string()),
    )
    xlsx_profile_push_stage(
      profile,
      "worksheet_xml_read:" + info.name,
      @env.now() - sheet_xml_started,
      Some(
        "part=" +
        read_stats.normalized_part_name +
        " bytes=" +
        read_stats.text_len.to_string(),
      ),
    )

    let sheet_parse_started = @env.now()
    let sheet_model = parse_sheet_model(
      info.name,
      Some(info._rid),
      info.rel_type,
      Some(normalized_target),
      info.state,
      sh_xml,
      shared,
      styles,
      uses_date_1904,
      profile,
    )
    xlsx_profile_push_stage(
      profile,
      "worksheet_model_parse_total:" + info.name,
      @env.now() - sheet_parse_started,
      Some(
        "cells=" +
        sheet_model.cells.length().to_string() +
        " rows=" +
        sheet_model.table_rows.length().to_string(),
      ),
    )
    xlsx_profile_record_sheet(profile, sheet_model)
    sheets.push(sheet_model)
  }

  ({ source_name: @cor.basename(input_path), uses_date_1904, sheets }, profile)
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
