///|
pub fn parse_docx(
  path : String,
  out_root : String,
  max_heading : Int,
) -> @cor.Document raise {
  let profile = if docx_convert_profile_enabled() {
    Some(new_docx_convert_profile_report(path))
  } else {
    None
  }
  docx_convert_profile_set_active(profile)
  defer docx_convert_profile_set_active(None)

  let materialize_outputs = out_root.trim() != ""
  if materialize_outputs && !@fs.path_exists(out_root) {
    @fs.create_dir(out_root)
  }
  let assets_dir = if materialize_outputs { out_root + "/assets" } else { "" }
  if materialize_outputs && !@fs.path_exists(assets_dir) {
    @fs.create_dir(assets_dir)
  }

  let open_started = @env.now()
  let pkg = open_docx(path)
  docx_convert_profile_add_stage(
    profile,
    "docx_package_open",
    @env.now() - open_started,
    None,
  )

  let doc_xml_started = @env.now()
  let doc_xml = pkg.read_text_required("word/document.xml")
  docx_convert_profile_add_stage(
    profile,
    "docx_document_xml",
    @env.now() - doc_xml_started,
    Some("chars=" + doc_xml.length().to_string()),
  )
  let document_features = scan_docx_document_features(doc_xml)

  let rels_started = @env.now()
  let rel_ctx = pkg.read_document_relationship_context(None)
  docx_convert_profile_add_stage(
    profile,
    "docx_relationships",
    @env.now() - rels_started,
    Some("targets=" + rel_ctx.targets_by_rid.length().to_string()),
  )

  let asset_map_started = @env.now()
  let asset_by_target = if materialize_outputs {
    build_docx_asset_path_map(rel_ctx, out_root)
  } else {
    Map([])
  }
  docx_convert_profile_add_stage(
    profile,
    "docx_asset_map_build",
    @env.now() - asset_map_started,
    Some("asset_candidates=" + asset_by_target.length().to_string()),
  )

  let styles_started = @env.now()
  let styles = pkg.load_styles_for_document(document_features)
  docx_convert_profile_add_stage(
    profile,
    "docx_styles",
    @env.now() - styles_started,
    Some(
      "style_reads_gated_by_pstyle=" + document_features.has_pstyle.to_string(),
    ),
  )

  let numbering_started = @env.now()
  let numbering = pkg.load_numbering()
  docx_convert_profile_add_stage(
    profile,
    "docx_numbering",
    @env.now() - numbering_started,
    None,
  )

  let notes_started = @env.now()
  let notes = pkg.load_note_bundle()
  docx_convert_profile_add_stage(
    profile,
    "docx_notes",
    @env.now() - notes_started,
    None,
  )

  let header_footer_started = @env.now()
  let header_footers = pkg.load_header_footer_bundle(doc_xml, out_root)
  docx_convert_profile_add_stage(
    profile,
    "docx_headers_footers",
    @env.now() - header_footer_started,
    Some(
      "headers=" +
      header_footers.headers.length().to_string() +
      " footers=" +
      header_footers.footers.length().to_string(),
    ),
  )

  let text_boxes_started = @env.now()
  let text_boxes = pkg.load_text_box_bundle(
    doc_xml, out_root, styles, numbering, header_footers,
  )
  docx_convert_profile_add_stage(
    profile,
    "docx_text_boxes",
    @env.now() - text_boxes_started,
    Some("items=" + text_boxes.items.length().to_string()),
  )

  let media_export_started = @env.now()
  if materialize_outputs {
    pkg.extract_media_by_relationships(rel_ctx, asset_by_target, assets_dir)
  }
  docx_convert_profile_add_stage(
    profile,
    "docx_media_export",
    @env.now() - media_export_started,
    Some(
      "materialized=" +
      materialize_outputs.to_string() +
      " asset_count=" +
      asset_by_target.length().to_string(),
    ),
  )

  reset_docx_scan_profile_counters()
  let body_scan_started = @env.now()
  let doc = scan_document(
    doc_xml,
    rel_ctx,
    asset_by_target,
    styles,
    numbering,
    notes,
    header_footers,
    text_boxes,
    max_heading,
    @cor.basename(path),
  )
  docx_convert_profile_add_stage(
    profile,
    "docx_body_scan",
    @env.now() - body_scan_started,
    Some("blocks=" + doc.blocks.val.length().to_string()),
  )
  let src = @cor.basename(path)
  let mut asset_idx = 0
  let asset_origin_started = @env.now()
  if materialize_outputs {
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
  }
  docx_convert_profile_add_stage(
    profile,
    "docx_asset_origin_attach",
    @env.now() - asset_origin_started,
    Some("asset_count=" + asset_idx.to_string()),
  )
  maybe_write_docx_convert_profile_log(profile)
  doc
}
