///|
priv struct DocxPackage {
  _path : String
  pkg : @ox.OoxmlPackage
}

///|
fn open_docx(path : String) -> DocxPackage raise @fs.IOError {
  let bytes = @fs.read_file_to_bytes(path) catch {
    e => raise @fs.IOError("read docx failed: " + path + " : " + e.to_string())
  }

  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => raise @fs.IOError("open_ooxml_package failed: " + e.to_string())
  }

  { _path: path, pkg }
}

///|
fn DocxPackage::read_text_optional(
  p : DocxPackage,
  part_name : String,
) -> String {
  let b = @ox.read_part_bytes(p.pkg, part_name) catch { _ => return "" }
  @cor.utf8_bytes_to_string(b) catch {
    _ => return ""
  }
}

///|
fn DocxPackage::read_text_required(
  p : DocxPackage,
  part_name : String,
) -> String raise {
  let b = @ox.read_part_bytes(p.pkg, part_name) catch {
    e => fail("read_part_bytes failed: " + part_name + " : " + e.to_string())
  }
  @cor.utf8_bytes_to_string(b) catch {
    e => fail("utf8 decode failed: " + part_name + " : " + e.to_string())
  }
}

///|
fn DocxPackage::read_document_relationship_context(
  p : DocxPackage,
  read_counter : Ref[Int]?,
) -> DocxRelationshipContext {
  match read_counter {
    Some(counter) => counter.val = counter.val + 1
    None => ()
  }
  profile_relationship_context_read()

  let rels = @ox.read_part_relationships(p.pkg, "word/document.xml") catch {
    _ => return empty_docx_relationship_context()
  }
  build_docx_relationship_context(rels)
}

///|
fn DocxPackage::extract_media_by_relationships(
  p : DocxPackage,
  ctx : DocxRelationshipContext,
  asset_by_target : Map[String, String],
  out_dir : String,
) -> Unit raise @fs.IOError {
  if !@fs.path_exists(out_dir) {
    @fs.create_dir(out_dir)
  }

  for entry in ctx.targets_by_rid {
    let (_, target) = entry
    let normalized = normalize_doc_part_target(target)
    if !normalized.has_prefix("word/media/") {
      continue
    }
    let rel_out = asset_by_target.get(normalized).unwrap_or("")
    if rel_out == "" || !rel_out.has_prefix("assets/") {
      continue
    }
    let name = rel_out["assets/".length():].to_owned()

    let data = @ox.read_part_bytes(p.pkg, normalized) catch { _ => continue }
    @fs.write_bytes_to_file(out_dir + "/" + name, data)
  }
}

///|
fn scan_docx_document_features(doc_xml : String) -> DocxDocumentFeatures {
  let features = {
    has_pstyle: doc_xml.contains("<w:pStyle"),
    has_numpr: doc_xml.contains("<w:numPr"),
  }
  profile_document_features(features.has_pstyle, features.has_numpr)
  features
}

///|
fn DocxPackage::load_styles_for_document(
  p : DocxPackage,
  features : DocxDocumentFeatures,
) -> DocxStyles {
  if !features.has_pstyle {
    return empty_styles()
  }

  let started = @env.now()
  let xml = p.read_text_optional("word/styles.xml")
  profile_styles_read(xml.length())
  if xml == "" {
    profile_styles_elapsed_ms(@env.now() - started)
    return empty_styles()
  }
  let styles = parse_styles_xml(xml)
  profile_styles_elapsed_ms(@env.now() - started)
  styles
}

///|
fn DocxPackage::load_numbering(p : DocxPackage) -> DocxNumbering {
  let xml = p.read_text_optional("word/numbering.xml")
  if xml == "" {
    return empty_numbering()
  }
  parse_numbering_xml(xml)
}

///|
fn DocxPackage::load_note_bundle(p : DocxPackage) -> DocxNoteBundle {
  ignore(empty_docx_note_bundle())
  {
    footnotes_by_id: parse_footnotes_xml(
      p.read_text_optional("word/footnotes.xml"),
    ),
    endnotes_by_id: parse_endnotes_xml(
      p.read_text_optional("word/endnotes.xml"),
    ),
    comments_by_id: parse_comments_xml(
      p.read_text_optional("word/comments.xml"),
    ),
  }
}

///|
fn DocxPackage::load_header_footer_bundle(
  p : DocxPackage,
  doc_xml : String,
  out_root : String,
) -> DocxHeaderFooterBundle {
  let doc_rels = p.read_document_relationship_context(None)
  let refs = parse_docx_header_footer_references(doc_xml, doc_rels)
  if refs.length() == 0 {
    return empty_docx_header_footer_bundle()
  }

  let headers : Array[DocxHeaderFooterPart] = []
  let footers : Array[DocxHeaderFooterPart] = []
  let next_idx : Ref[Int] = {
    val: build_docx_asset_path_map(doc_rels, out_root).length(),
  }

  for part_ref in refs {
    let xml = p.read_text_optional(part_ref.part_name)
    if xml.trim() == "" {
      continue
    }
    let rels : Array[@ox.OoxmlRelationship] = @ox.read_part_relationships(
      p.pkg,
      part_ref.part_name,
    ) catch {
      _ => []
    }
    let rel_ctx = build_docx_relationship_context(rels)
    let asset_by_target = build_docx_asset_path_map_with_seed(
      rel_ctx, out_root, next_idx,
    )
    p.extract_media_by_relationships(
      rel_ctx,
      asset_by_target,
      out_root + "/assets",
    ) catch {
      _ => ()
    }
    let rendered = render_docx_part_text_for_header_footer(xml)
    let is_page_number_only = docx_header_footer_is_page_number_only(xml)
    if @cor.is_blank(rendered) && !is_page_number_only {
      continue
    }
    let part = {
      kind: part_ref.kind,
      ref_type: part_ref.ref_type,
      relationship_id: part_ref.relationship_id,
      part_name: part_ref.part_name,
      text: rendered,
      is_page_number_only,
    }
    match part_ref.kind {
      DocxHeaderFooterKind::Header => headers.push(part)
      DocxHeaderFooterKind::Footer => footers.push(part)
    }
  }

  { headers, footers }
}

///|
fn DocxPackage::load_text_box_bundle(
  p : DocxPackage,
  doc_xml : String,
  out_root : String,
  styles : DocxStyles,
  numbering : DocxNumbering,
  header_footers : DocxHeaderFooterBundle,
) -> DocxTextBoxBundle {
  let doc_rels = p.read_document_relationship_context(None)
  let asset_by_target = build_docx_asset_path_map(doc_rels, out_root)
  let items : Array[DocxTextBox] = []

  items.append(
    collect_docx_text_boxes_from_xml(
      doc_xml,
      doc_rels,
      asset_by_target,
      styles,
      numbering,
      DocxTextBoxContext::Body,
      "word/document.xml",
      None,
    ),
  )

  for part in header_footers.headers {
    let xml = p.read_text_optional(part.part_name)
    if xml.trim() == "" {
      continue
    }
    let rels : Array[@ox.OoxmlRelationship] = @ox.read_part_relationships(
      p.pkg,
      part.part_name,
    ) catch {
      _ => []
    }
    let rel_ctx = build_docx_relationship_context(rels)
    let part_asset_by_target = build_docx_asset_path_map_with_seed(
      rel_ctx,
      out_root,
      { val: asset_by_target.length() + items.length() + 1000 },
    )
    items.append(
      collect_docx_text_boxes_from_xml(
        xml,
        rel_ctx,
        part_asset_by_target,
        styles,
        numbering,
        DocxTextBoxContext::Header,
        part.part_name,
        Some(part.relationship_id),
      ),
    )
  }

  for part in header_footers.footers {
    let xml = p.read_text_optional(part.part_name)
    if xml.trim() == "" {
      continue
    }
    let rels : Array[@ox.OoxmlRelationship] = @ox.read_part_relationships(
      p.pkg,
      part.part_name,
    ) catch {
      _ => []
    }
    let rel_ctx = build_docx_relationship_context(rels)
    let part_asset_by_target = build_docx_asset_path_map_with_seed(
      rel_ctx,
      out_root,
      { val: asset_by_target.length() + items.length() + 2000 },
    )
    items.append(
      collect_docx_text_boxes_from_xml(
        xml,
        rel_ctx,
        part_asset_by_target,
        styles,
        numbering,
        DocxTextBoxContext::Footer,
        part.part_name,
        Some(part.relationship_id),
      ),
    )
  }

  { items, }
}
