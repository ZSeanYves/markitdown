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
  let workbook = inspect_xlsx(input_path)
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
pub fn inspect_xlsx(input_path : String) -> XlsxWorkbookModel raise {
  let p = open_xlsx(input_path) catch {
    e => raise @cor.AppError("xlsx: open package failed: " + e.to_string())
  }

  let wb_xml = p.read_text_required("xl/workbook.xml")
  let shared : Array[String] = if @ox.has_part(p.pkg, "xl/sharedStrings.xml") {
    parse_shared_strings(p.read_text_optional("xl/sharedStrings.xml"))
  } else {
    []
  }
  let styles = if @ox.has_part(p.pkg, "xl/styles.xml") {
    parse_styles_xml(p.read_text_optional("xl/styles.xml"))
  } else {
    empty_styles()
  }
  let uses_date_1904 = workbook_uses_date_1904(wb_xml)
  let sheet_infos = parse_workbook_sheets(p.pkg, wb_xml)
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

    if normalized_target == "" || !@ox.has_part(p.pkg, normalized_target) {
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
      continue
    }

    let sh_xml = p.read_text_required(normalized_target)
    sheets.push(
      parse_sheet_model(
        info.name,
        Some(info._rid),
        info.rel_type,
        Some(normalized_target),
        info.state,
        sh_xml,
        shared,
        styles,
        uses_date_1904,
      ),
    )
  }

  { source_name: @cor.basename(input_path), uses_date_1904, sheets }
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
