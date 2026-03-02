// src/xlsx/xlsx_parser.mbt
///|
pub fn parse_xlsx(
  input_path : String,
  out_dir : String,
  max_heading : Int,
) -> @cor.Document raise {
  // MVP: 先返回一个空文档，后续逐步填充
  let doc = @cor.new_document()
  @cor.push(doc, @cor.Block::Heading(1, "XLSX (MVP placeholder)"))
  @cor.push(doc, @cor.Block::Paragraph("input: " + input_path))
  doc
}
