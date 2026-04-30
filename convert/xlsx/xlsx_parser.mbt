///|
/// XLSX MVP parser (MoonBit)
/// - package access: reuse OOXML package layer
/// - XML parsing: lightweight string scanning (good enough for MVP)
/// - Output: Heading + Table per sheet
///
/// Limitations:
/// - no formula evaluation
/// - merged cells ignored
/// - lightweight date/time formatting support for common built-in/custom Excel numFmt
/// - current cell type support focuses on shared strings / inline strings / numbers / booleans / string results / errors
pub fn parse_xlsx(
  input_path : String,
  _out_dir : String,
  max_heading : Int,
) -> @cor.Document raise {
  // 1) open package
  let p = open_xlsx(input_path) catch {
    e => raise @cor.AppError("xlsx: open package failed: " + e.to_string())
  }

  // 2) read workbook.xml + rels
  let wb_xml = p.read_text_required("xl/workbook.xml")

  // 3) sharedStrings.xml is optional
  let shared : Array[String] = if @ox.has_part(p.pkg, "xl/sharedStrings.xml") {
    let ss_xml = p.read_text_optional("xl/sharedStrings.xml")
    parse_shared_strings(ss_xml)
  } else {
    []
  }

  // 4) styles.xml is optional
  let styles = if @ox.has_part(p.pkg, "xl/styles.xml") {
    let styles_xml = p.read_text_optional("xl/styles.xml")
    parse_styles_xml(styles_xml)
  } else {
    empty_styles()
  }

  // 5) parse sheets
  let sheets = parse_workbook_sheets(p.pkg, wb_xml)

  // 6) build IR
  let doc = @cor.new_document()
  let src = @cor.basename(input_path)

  if sheets.length() == 0 {
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

  for i in 0..<sheets.length() {
    let sh = sheets[i]
    let sheet_name = sh.name
    @cor.push_with_origin(
      doc,
      @cor.Block::Heading(clamp_heading(2, max_heading), sheet_name),
      Some({
        source_name: Some(src),
        page: None,
        slide: None,
        sheet: Some(sheet_name),
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

    let sheet_path = normalize_sheet_part_target(sh.target)

    if sheet_path == "" || !@ox.has_part(p.pkg, sheet_path) {
      @cor.push_with_origin(
        doc,
        @cor.Block::Paragraph("(missing sheet xml: " + sheet_path + ")"),
        Some({
          source_name: Some(src),
          page: None,
          slide: None,
          sheet: Some(sheet_name),
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
      @cor.push_with_origin(
        doc,
        @cor.Block::BlankLine,
        Some({
          source_name: Some(src),
          page: None,
          slide: None,
          sheet: Some(sheet_name),
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
      continue
    }

    let sh_xml = p.read_text_required(sheet_path)
    let table_extract = parse_sheet_table(sh_xml, shared, styles)
    let table = table_extract.rows

    if table.length() == 0 {
      @cor.push_with_origin(
        doc,
        @cor.Block::Paragraph("(empty sheet)"),
        Some({
          source_name: Some(src),
          page: None,
          slide: None,
          sheet: Some(sheet_name),
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
    } else {
      @cor.push_with_origin(
        doc,
        @cor.Block::Table(table),
        Some({
          source_name: Some(src),
          page: None,
          slide: None,
          sheet: Some(sheet_name),
          block_index: Some(doc.blocks.val.length()),
          heading_path: None,
          line_start: Some(table_extract.min_row),
          line_end: Some(table_extract.max_row),
          row_index: Some(table_extract.min_row),
          column_index: Some(table_extract.min_col),
          object_ref: None,
          relationship_id: Some(sh._rid),
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
        sheet: Some(sheet_name),
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
  }

  doc
}
