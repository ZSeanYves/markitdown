///|
pub fn parse_xlsx(
  input_path : String,
  _out_dir : String,
  _max_heading : Int,
) -> @cor.Document {
  let doc = @cor.new_document()
  @cor.push(doc, @cor.Block::Heading(1, "XLSX"))
  @cor.push(doc, @cor.Block::Paragraph("MVP: parser stub"))
  @cor.push(doc, @cor.Block::Paragraph("input: " + input_path))

  // 给 Table 一个占位，方便你检查 emitter 输出格式
  let rows : Array[Array[String]] = [["A", "B"], ["1", "2"]]
  @cor.push(doc, @cor.Block::Table(rows))
  doc
}
