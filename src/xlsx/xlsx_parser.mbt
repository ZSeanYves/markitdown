///|
/// XLSX MVP parser (MoonBit)
/// - ZIP: reuse src/docx/zip_min.mbt
/// - XML parsing: lightweight string scanning (good enough for MVP)
/// - Output: Heading + Table per sheet
///
/// Limitations (MVP):
/// - no styles, no formula evaluation
/// - merged cells ignored
/// - inlineStr not handled yet (only sharedStrings "t=s" and numeric/default)
pub async fn parse_xlsx(
  input_path : String,
  _out_dir : String,
  max_heading : Int,
) -> @cor.Document {
  // 1) open zip
  let z = @cor.open_zip(input_path) catch {
    e => raise @cor.AppError("xlsx: open zip failed: " + e.to_string())
  }

  // 2) read workbook.xml + rels
  let wb_xml = read_zip_utf8(z, "xl/workbook.xml")
  let rels_xml = read_zip_utf8(z, "xl/_rels/workbook.xml.rels")

  // 3) sharedStrings.xml is optional
  let shared : Array[String] = if @cor.ZipReader::has_entry(
      z, "xl/sharedStrings.xml",
    ) {
    let ss_xml = read_zip_utf8(z, "xl/sharedStrings.xml")
    parse_shared_strings(ss_xml)
  } else {
    []
  }

  // 4) parse sheets
  let sheets = parse_workbook_sheets(wb_xml, rels_xml)

  // 5) build IR
  let doc = @cor.new_document()
  @cor.push(doc, @cor.Block::Heading(clamp_heading(1, max_heading), "XLSX"))

  if sheets.length() == 0 {
    @cor.push(doc, @cor.Block::Paragraph("(no sheets found)"))
    return doc
  }

  for i in 0..<sheets.length() {
    let sh = sheets[i]
    @cor.push(doc, @cor.Block::Heading(clamp_heading(2, max_heading), sh.name))

    let target0 = sh.target.trim().to_string()
    let target = if target0.has_prefix("/") { target0[1:] } else { target0 }
    let sheet_path = if target.has_prefix("xl/") {
      target.to_string()
    } else {
      "xl/" + target.to_string()
    }

    if !@cor.ZipReader::has_entry(z, sheet_path) {
      @cor.push(
        doc,
        @cor.Block::Paragraph("(missing sheet xml: " + sheet_path + ")"),
      )
      @cor.push(doc, @cor.Block::BlankLine)
      continue
    }

    let sh_xml = read_zip_utf8(z, sheet_path)
    let table = parse_sheet_table(sh_xml, shared)

    if table.length() == 0 {
      @cor.push(doc, @cor.Block::Paragraph("(empty sheet)"))
    } else {
      @cor.push(doc, @cor.Block::Table(table))
    }

    @cor.push(doc, @cor.Block::BlankLine)
  }

  doc
}
