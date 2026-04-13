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

  let pkg = open_docx(path)

  // 1) 读正文 xml
  let doc_xml = pkg.read_text_required("word/document.xml")

  // 2) 读关系表（图片 rId -> media/xxx）
  let rels = pkg.read_document_relationships()
  let asset_by_target = build_docx_asset_path_map(rels, out_root)

  // 3) 读 styles.xml（标题样式映射）
  let styles = pkg.load_styles()

  // 4) 读 numbering.xml（列表类型映射）
  let numbering = pkg.load_numbering()

  // 5) 导出图片到 out_root/assets
  pkg.extract_media_by_relationships(rels, asset_by_target, assets_dir)

  // 6) 扫描 xml 生成 IR
  let doc = scan_document(
    doc_xml,
    rels,
    asset_by_target,
    styles,
    numbering,
    max_heading,
    @cor.basename(path),
  )
  let src = @cor.basename(path)
  let mut asset_idx = 0
  for entry in asset_by_target {
    let (_target, rel_path) = entry
    asset_idx += 1
    @cor.set_asset_origin(doc, rel_path, {
      source_name: Some(src),
      page: None,
      slide: None,
      sheet: None,
      origin_id: Some("docx-asset-" + asset_idx.to_string()),
      nearby_caption: None,
    })
  }
  doc
}
