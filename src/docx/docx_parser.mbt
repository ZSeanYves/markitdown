///|
pub fn parse_docx(
  path : String,
  out_root : String,
  max_heading : Int,
) -> @cor.Document raise {
  if !@fs.path_exists(out_root) {
    @fs.create_dir(out_root)
  }
  let assets_dir = out_root + "/assets"
  if !@fs.path_exists(assets_dir) {
    @fs.create_dir(assets_dir)
  }

  let zip = open_docx(path)

  // 1) 读正文 xml
  let doc_xml = zip.read_text_required("word/document.xml")

  // 2) 读关系表（图片 rId -> media/xxx）
  let rels_xml = zip.read_text_optional("word/_rels/document.xml.rels")
  //println("document.xml chars = " + doc_xml.length().to_string())

  let rels = parse_rels(rels_xml)

  // 3) 导出图片到 out_root/assets
  zip.extract_prefix("word/media/", assets_dir)

  // 4) 扫描 xml 生成 IR
  scan_document_xml(doc_xml, rels, max_heading)
}
