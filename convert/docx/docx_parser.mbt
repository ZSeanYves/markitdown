///|
pub fn parse_docx(
  path : String,
  out_root : String,
  max_heading : Int,
) -> @cor.Document raise {
  parse_docx_impl(path, out_root, max_heading, None)
}

///|
fn parse_docx_impl(
  path : String,
  out_root : String,
  max_heading : Int,
  rel_read_counter : Ref[Int]?,
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
  let document_features = scan_docx_document_features(doc_xml)

  // 2) 读一次 document.xml.rels，并构建 hyperlink/image 查找缓存
  let rel_ctx = pkg.read_document_relationship_context(rel_read_counter)
  let asset_by_target = build_docx_asset_path_map(rel_ctx, out_root)

  // 3) 仅当正文使用段落样式时才读 styles.xml（标题/引用/code 样式映射）
  let styles = pkg.load_styles_for_document(document_features)

  // 4) 读 numbering.xml（列表类型映射）
  let numbering = pkg.load_numbering()

  // 5) 导出图片到 out_root/assets
  pkg.extract_media_by_relationships(rel_ctx, asset_by_target, assets_dir)

  // 6) 扫描 xml 生成 IR
  reset_docx_scan_profile_counters()
  let doc = scan_document(
    doc_xml,
    rel_ctx,
    asset_by_target,
    styles,
    numbering,
    max_heading,
    @cor.basename(path),
  )
  let src = @cor.basename(path)
  let mut asset_idx = 0
  for entry in asset_by_target {
    let (target, rel_path) = entry
    asset_idx += 1
    @cor.set_asset_origin(doc, rel_path, {
      source_name: Some(src),
      page: None,
      slide: None,
      sheet: None,
      origin_id: Some("docx-asset-" + asset_idx.to_string()),
      nearby_caption: None,
      object_ref: None,
      relationship_id: lookup_doc_relationship_id_for_target(rel_ctx, target),
      source_path: Some(normalize_doc_part_target(target)),
      row_index: None,
      column_index: None,
      key_path: None,
    })
  }
  doc
}
