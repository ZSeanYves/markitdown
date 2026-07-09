///|
priv struct DocxMediaRelationshipRef {
  relationship_id : String?
  relationship_kind : DocxMediaRelationshipKind
}

///|
fn parse_docx_drawing_anchor(
  xml : String,
  start : Int,
  end_exclusive : Int,
  key : DocxSourceKey,
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> DocxSourceDrawing {
  let source_xml = xml[start:end_exclusive].to_owned()
  let media = if find_docx_media_relationship_ref(source_xml) is Some(_) {
    Some(
      parse_docx_media_ref(
        xml,
        start,
        end_exclusive,
        "w:drawing",
        DocxMediaContainerKind::Drawing,
        key,
        relationships,
        pkg,
        warnings,
      ),
    )
  } else {
    None
  }
  let alternate_media = parse_docx_alternate_drawing_media_refs(
    source_xml,
    "w:drawing",
    DocxMediaContainerKind::Drawing,
    key,
    relationships,
    pkg,
    warnings,
  )
  {
    anchor_id: key.part_name + "#" + key.node_key,
    owner_part: key.part_name,
    source_key: key,
    doc_pr_id: read_docx_non_empty_attr_in_first_tag(
      source_xml, "wp:docPr", "id",
    ),
    doc_pr_name: read_docx_non_empty_attr_in_first_tag(
      source_xml, "wp:docPr", "name",
    ),
    descr: read_docx_media_alt_text(source_xml),
    title: read_docx_media_title(source_xml),
    media,
    alternate_media,
    text_box_ref: docx_textbox_ref_in_anchor(source_xml, key),
    child_inlines: [],
  }
}

///|
fn parse_docx_shape_anchor(
  xml : String,
  start : Int,
  end_exclusive : Int,
  key : DocxSourceKey,
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> DocxSourceShape {
  let source_xml = xml[start:end_exclusive].to_owned()
  let media = if find_docx_media_relationship_ref(source_xml) is Some(_) {
    Some(
      parse_docx_media_ref(
        xml,
        start,
        end_exclusive,
        "w:pict",
        DocxMediaContainerKind::Pict,
        key,
        relationships,
        pkg,
        warnings,
      ),
    )
  } else {
    None
  }
  {
    anchor_id: key.part_name + "#" + key.node_key,
    owner_part: key.part_name,
    source_key: key,
    shape_id: docx_textbox_anchor_shape_id(source_xml),
    shape_type: read_docx_non_empty_attr_in_first_tag(
      source_xml, "v:shape", "type",
    ),
    style: read_docx_non_empty_attr_in_first_tag(source_xml, "v:shape", "style"),
    alt_text: read_docx_media_alt_text(source_xml),
    title: read_docx_media_title(source_xml),
    media,
    text_box_ref: docx_textbox_ref_in_anchor(source_xml, key),
    child_inlines: [],
  }
}

///|
fn docx_textbox_ref_in_anchor(
  source_xml : String,
  key : DocxSourceKey,
) -> DocxSourceTextBoxRef? {
  match find_docx_start_tag_from(source_xml, 0, "w:txbxContent") {
    Some(_) =>
      Some({
        anchor_id: None,
        doc_pr_id: read_docx_non_empty_attr_in_first_tag(
          source_xml, "wp:docPr", "id",
        ),
        shape_id: docx_textbox_anchor_shape_id(source_xml),
        owner_part: key.part_name,
        source_key: key,
      })
    None => None
  }
}

///|
fn parse_docx_media_ref(
  xml : String,
  start : Int,
  end_exclusive : Int,
  container_tag : String,
  container_kind : DocxMediaContainerKind,
  key : DocxSourceKey,
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> DocxSourceMediaRef {
  let source_xml = xml[start:end_exclusive].to_owned()
  docx_media_ref_from_relationship_ref(
    source_xml,
    find_docx_media_relationship_ref(source_xml),
    container_tag,
    container_kind,
    key,
    relationships,
    pkg,
    warnings,
  )
}

///|
fn docx_media_ref_from_relationship_ref(
  source_xml : String,
  media_ref : DocxMediaRelationshipRef?,
  container_tag : String,
  container_kind : DocxMediaContainerKind,
  key : DocxSourceKey,
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> DocxSourceMediaRef {
  let mut relationship_id : String? = None
  let mut relationship_kind = DocxMediaRelationshipKind::Unknown
  let mut target : String? = None
  let mut resolved_target : String? = None
  let mut target_mode : DocxTargetMode? = None
  let mut target_part : String? = None
  let mut target_exists : Bool? = None
  let mut content_type : String? = None

  match media_ref {
    Some(ref_info) => {
      relationship_id = ref_info.relationship_id
      relationship_kind = ref_info.relationship_kind
    }
    None =>
      warnings.push({
        kind: DocxSourceWarningKind::MissingMediaTarget,
        message: "media ref has no supported relationship tag: " + container_tag,
        source_key: Some(key),
      })
  }

  match relationship_id {
    Some(rid) =>
      match
        find_docx_relationship_by_id(relationships, key.part_name, rid, pkg) {
        Some(rel) => {
          target = Some(rel.target)
          resolved_target = Some(rel.resolved_target)
          if rel.target_mode == @ox.OoxmlTargetMode::External {
            target_mode = Some(DocxTargetMode::External)
          } else {
            target_mode = Some(DocxTargetMode::Internal)
            target_part = Some(rel.resolved_target)
            target_exists = docx_media_target_exists(pkg, rel.resolved_target)
            content_type = docx_media_content_type(pkg, rel.resolved_target)
            if target_exists == Some(false) {
              warnings.push({
                kind: DocxSourceWarningKind::MissingMediaPart,
                message: "media part is missing: " + rel.resolved_target,
                source_key: Some(key),
              })
            }
            match content_type {
              Some(ct) =>
                if !ct.has_prefix("image/") {
                  warnings.push({
                    kind: DocxSourceWarningKind::UnsupportedMedia,
                    message: "media target content type is not image: " + ct,
                    source_key: Some(key),
                  })
                }
              None => ()
            }
          }
        }
        None =>
          warnings.push({
            kind: DocxSourceWarningKind::MissingMediaTarget,
            message: "media relationship not found: " + rid,
            source_key: Some(key),
          })
      }
    None =>
      if media_ref is Some(_) {
        warnings.push({
          kind: DocxSourceWarningKind::MissingMediaTarget,
          message: "media relationship tag has no relationship id: " +
          container_tag,
          source_key: Some(key),
        })
      }
  }

  {
    relationship_id,
    relationship_kind,
    container_kind,
    target,
    resolved_target,
    target_mode,
    target_part,
    target_exists,
    content_type,
    alt_text: read_docx_media_alt_text(source_xml),
    title: read_docx_media_title(source_xml),
    source_key: key,
  }
}

///|
fn parse_docx_alternate_drawing_media_refs(
  source_xml : String,
  container_tag : String,
  container_kind : DocxMediaContainerKind,
  key : DocxSourceKey,
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> Array[DocxSourceMediaRef] {
  let out : Array[DocxSourceMediaRef] = []
  let refs = find_docx_svg_media_relationship_refs(source_xml)
  for media_ref in refs {
    out.push(
      docx_media_ref_from_relationship_ref(
        source_xml,
        Some(media_ref),
        container_tag,
        container_kind,
        key,
        relationships,
        pkg,
        warnings,
      ),
    )
  }
  out
}

///|
fn find_docx_svg_media_relationship_refs(
  source_xml : String,
) -> Array[DocxMediaRelationshipRef] {
  let out : Array[DocxMediaRelationshipRef] = []
  let mut offset = 0
  while offset < source_xml.length() {
    match find_docx_start_tag_from(source_xml, offset, "asvg:svgBlip") {
      Some(start) => {
        let tag = docx_open_tag_at(source_xml, start)
        out.push(read_docx_blip_relationship_ref(tag))
        offset = start + tag.length()
      }
      None => break
    }
  }
  out
}

///|
fn find_docx_media_relationship_ref(
  source_xml : String,
) -> DocxMediaRelationshipRef? {
  let blip_start = find_docx_start_tag_from(source_xml, 0, "a:blip")
  let image_start = find_docx_start_tag_from(source_xml, 0, "v:imagedata")
  match (blip_start, image_start) {
    (Some(a), Some(v)) =>
      if a <= v {
        Some(read_docx_blip_relationship_ref(docx_open_tag_at(source_xml, a)))
      } else {
        Some(
          read_docx_vml_image_relationship_ref(docx_open_tag_at(source_xml, v)),
        )
      }
    (Some(a), None) =>
      Some(read_docx_blip_relationship_ref(docx_open_tag_at(source_xml, a)))
    (None, Some(v)) =>
      Some(
        read_docx_vml_image_relationship_ref(docx_open_tag_at(source_xml, v)),
      )
    (None, None) => None
  }
}

///|
fn read_docx_blip_relationship_ref(tag : String) -> DocxMediaRelationshipRef {
  match read_docx_attr_value(tag, "r:embed") {
    Some(rid) => { relationship_id: Some(rid), relationship_kind: Embed }
    None =>
      match read_docx_attr_value(tag, "r:link") {
        Some(rid) => { relationship_id: Some(rid), relationship_kind: Link }
        None =>
          match read_docx_attr_value(tag, "r:id") {
            Some(rid) =>
              { relationship_id: Some(rid), relationship_kind: Unknown }
            None => { relationship_id: None, relationship_kind: Unknown }
          }
      }
  }
}

///|
fn read_docx_vml_image_relationship_ref(
  tag : String,
) -> DocxMediaRelationshipRef {
  match read_docx_attr_value(tag, "r:id") {
    Some(rid) => { relationship_id: Some(rid), relationship_kind: Embed }
    None =>
      match read_docx_attr_value(tag, "r:embed") {
        Some(rid) => { relationship_id: Some(rid), relationship_kind: Embed }
        None =>
          match read_docx_attr_value(tag, "r:link") {
            Some(rid) => { relationship_id: Some(rid), relationship_kind: Link }
            None => { relationship_id: None, relationship_kind: Unknown }
          }
      }
  }
}

///|
fn docx_media_target_exists(
  pkg : @ox.OoxmlPackage?,
  target_part : String,
) -> Bool? {
  match pkg {
    Some(p) => Some(@ox.has_part(p, target_part))
    None => None
  }
}

///|
fn docx_media_content_type(
  pkg : @ox.OoxmlPackage?,
  target_part : String,
) -> String? {
  match pkg {
    Some(p) => @ox.lookup_content_type(p, target_part) catch { _ => None }
    None => None
  }
}

///|
fn read_docx_media_alt_text(source_xml : String) -> String? {
  match read_docx_non_empty_attr_in_first_tag(source_xml, "wp:docPr", "descr") {
    Some(value) => Some(value)
    None =>
      match
        read_docx_non_empty_attr_in_first_tag(source_xml, "pic:cNvPr", "descr") {
        Some(value) => Some(value)
        None =>
          match
            read_docx_non_empty_attr_in_first_tag(source_xml, "v:shape", "alt") {
            Some(value) => Some(value)
            None =>
              read_docx_non_empty_attr_in_first_tag(
                source_xml, "v:imagedata", "alt",
              )
          }
      }
  }
}

///|
fn read_docx_media_title(source_xml : String) -> String? {
  match read_docx_non_empty_attr_in_first_tag(source_xml, "wp:docPr", "title") {
    Some(value) => Some(value)
    None =>
      match
        read_docx_non_empty_attr_in_first_tag(source_xml, "pic:cNvPr", "title") {
        Some(value) => Some(value)
        None =>
          match
            read_docx_non_empty_attr_in_first_tag(
              source_xml, "v:shape", "title",
            ) {
            Some(value) => Some(value)
            None =>
              match
                read_docx_non_empty_attr_in_first_tag(
                  source_xml, "v:imagedata", "title",
                ) {
                Some(value) => Some(value)
                None =>
                  read_docx_non_empty_attr_in_first_tag(
                    source_xml, "v:imagedata", "o:title",
                  )
              }
          }
      }
  }
}

///|
fn read_docx_non_empty_attr_in_first_tag(
  xml : String,
  tag : String,
  attr : String,
) -> String? {
  match read_docx_attr_in_first_tag(xml, tag, attr) {
    Some(value) => if value.trim() == "" { None } else { Some(value) }
    None => None
  }
}

///|
fn parse_docx_hyperlink(
  xml : String,
  start : Int,
  end_exclusive : Int,
  key : DocxSourceKey,
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> DocxSourceHyperlink {
  let open_tag = docx_open_tag_at(xml, start)
  let relationship_id = read_docx_attr_value(open_tag, "r:id")
  let anchor = read_docx_attr_value(open_tag, "w:anchor")
  let text = docx_visible_text_in_scope(
    docx_inner_xml_for_element(xml, start, end_exclusive, "w:hyperlink"),
  )
  let mut target : String? = None
  let mut target_mode : DocxTargetMode? = None
  match relationship_id {
    Some(rid) =>
      match
        find_docx_relationship_by_id(relationships, key.part_name, rid, pkg) {
        Some(rel) => {
          target = Some(
            docx_hyperlink_resolved_target(rel.resolved_target, anchor),
          )
          target_mode = Some(
            if rel.target_mode == @ox.OoxmlTargetMode::External {
              DocxTargetMode::External
            } else {
              DocxTargetMode::Internal
            },
          )
        }
        None =>
          warnings.push({
            kind: DocxSourceWarningKind::MissingHyperlinkTarget,
            message: "hyperlink relationship not found: " + rid,
            source_key: Some(key),
          })
      }
    None => ()
  }
  if target is None {
    match anchor {
      Some(value) => {
        target = Some("#" + value)
        target_mode = Some(DocxTargetMode::Internal)
      }
      None =>
        warnings.push({
          kind: DocxSourceWarningKind::MissingHyperlinkTarget,
          message: "hyperlink has no relationship id or anchor",
          source_key: Some(key),
        })
    }
  }
  { relationship_id, anchor, target, text, target_mode, source_key: key }
}

///|
fn docx_hyperlink_resolved_target(
  relationship_target : String,
  anchor : String?,
) -> String {
  match anchor {
    Some(value) => {
      let trimmed = value.trim()
      if trimmed == "" {
        relationship_target
      } else if relationship_target.has_suffix("#") {
        relationship_target + trimmed.to_owned()
      } else {
        relationship_target + "#" + trimmed.to_owned()
      }
    }
    None => relationship_target
  }
}

///|
fn find_docx_relationship_by_id(
  relationships : Array[@ox.OoxmlRelationship],
  source_part : String,
  relationship_id : String,
  pkg : @ox.OoxmlPackage?,
) -> @ox.OoxmlRelationship? {
  match pkg {
    Some(p) => {
      let indexed = @ox.find_relationship_by_id(p, source_part, relationship_id) catch {
        _ => None
      }
      match indexed {
        Some(rel) => return Some(rel)
        None => ()
      }
    }
    None => ()
  }
  for rel in relationships {
    if rel.id == relationship_id {
      return Some(rel)
    }
  }
  None
}

///|
fn parse_docx_break_inline(
  xml : String,
  start : Int,
  key : DocxSourceKey,
) -> DocxSourceInline {
  let open_tag = docx_open_tag_at(xml, start)
  let break_type = read_docx_attr_value(open_tag, "w:type")
  let kind = match break_type {
    Some(value) =>
      if value == "page" {
        DocxBreakKind::Page
      } else if value == "column" {
        DocxBreakKind::Column
      } else if value == "textWrapping" {
        DocxBreakKind::TextWrapping
      } else {
        DocxBreakKind::Unknown
      }
    None => DocxBreakKind::Line
  }
  DocxSourceInline::Break({ kind, break_type, source_key: key })
}

///|
fn is_docx_math_start(xml : String, start : Int) -> Bool {
  is_docx_start_tag_at(xml, start, "m:oMath") ||
  is_docx_start_tag_at(xml, start, "m:oMathPara")
}

///|
fn parse_docx_math_inline(
  xml : String,
  start : Int,
  end_exclusive : Int,
  tag : String,
  key : DocxSourceKey,
  warnings : Array[DocxSourceWarning],
) -> DocxSourceInline {
  warnings.push({
    kind: DocxSourceWarningKind::UnsupportedMath,
    message: "OMML math preserved without conversion: " + tag,
    source_key: Some(key),
  })
  DocxSourceInline::Math({
    kind: tag,
    text_signature: docx_math_text_signature(
      docx_inner_xml_for_element(xml, start, end_exclusive, tag),
    ),
    child_inlines: [],
    source_key: key,
  })
}

///|
fn parse_docx_symbol_inline(
  xml : String,
  start : Int,
  key : DocxSourceKey,
) -> DocxSourceInline {
  let open_tag = docx_open_tag_at(xml, start)
  DocxSourceInline::Symbol({
    font: read_docx_attr_value(open_tag, "w:font"),
    char_hex: read_docx_attr_value(open_tag, "w:char"),
    source_key: key,
  })
}

///|
fn parse_docx_fld_simple(
  xml : String,
  start : Int,
  end_exclusive : Int,
  key : DocxSourceKey,
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> DocxSourceInline {
  let open_tag = docx_open_tag_at(xml, start)
  let inner = docx_inner_xml_for_element(
    xml, start, end_exclusive, "w:fldSimple",
  )
  make_docx_field_inline(
    "fldSimple",
    read_docx_attr_value(open_tag, "w:instr"),
    None,
    docx_non_empty_text(docx_visible_text_in_scope(inner)),
    docx_source_run_inlines(
      parse_docx_paragraph_runs(inner, key, relationships, pkg, warnings),
    ),
    key,
    warnings,
  )
}

///|
fn parse_docx_fld_char(
  xml : String,
  start : Int,
  key : DocxSourceKey,
  warnings : Array[DocxSourceWarning],
) -> DocxSourceInline {
  let open_tag = docx_open_tag_at(xml, start)
  make_docx_field_inline(
    "fldChar",
    None,
    read_docx_attr_value(open_tag, "w:fldCharType"),
    None,
    [],
    key,
    warnings,
  )
}

///|
fn parse_docx_instr_text(
  xml : String,
  start : Int,
  key : DocxSourceKey,
  warnings : Array[DocxSourceWarning],
) -> (DocxSourceInline, Int)? {
  let open_end_rel = match xml[start:].find(">") {
    Some(rel) => rel
    None => return None
  }
  let text_start = start + open_end_rel + 1
  let close_rel = match xml[text_start:].find("</w:instrText>") {
    Some(rel) => rel
    None => return None
  }
  let instruction = decode_docx_text(
    xml[text_start:text_start + close_rel].to_owned(),
  )
  Some(
    (
      make_docx_field_inline(
        "instrText",
        Some(instruction),
        None,
        None,
        [],
        key,
        warnings,
      ),
      text_start + close_rel + "</w:instrText>".length(),
    ),
  )
}

///|
fn make_docx_field_inline(
  kind : String,
  instruction : String?,
  field_char_type : String?,
  result_text : String?,
  child_inlines : Array[DocxSourceInline],
  key : DocxSourceKey,
  warnings : Array[DocxSourceWarning],
) -> DocxSourceInline {
  warnings.push({
    kind: DocxSourceWarningKind::UnsupportedField,
    message: "unsupported field inline: " + kind,
    source_key: Some(key),
  })
  DocxSourceInline::FieldUnsupported({
    kind,
    instruction,
    field_char_type,
    result_text,
    child_inlines,
    source_key: key,
  })
}

///|
fn parse_docx_bookmark(
  xml : String,
  start : Int,
  key : DocxSourceKey,
  warnings : Array[DocxSourceWarning],
) -> DocxSourceInline {
  let open_tag = docx_open_tag_at(xml, start)
  let kind = if is_docx_start_tag_at(xml, start, "w:bookmarkStart") {
    DocxBookmarkKind::Start
  } else {
    DocxBookmarkKind::End
  }
  warnings.push({
    kind: DocxSourceWarningKind::UnsupportedBookmark,
    message: "bookmark inline preserved without conversion",
    source_key: Some(key),
  })
  DocxSourceInline::Bookmark({
    kind,
    bookmark_id: read_docx_attr_value(open_tag, "w:id"),
    name: read_docx_attr_value(open_tag, "w:name"),
    source_key: key,
  })
}

///|
fn is_docx_tracked_change_start(xml : String, start : Int) -> Bool {
  is_docx_start_tag_at(xml, start, "w:ins") ||
  is_docx_start_tag_at(xml, start, "w:del") ||
  is_docx_start_tag_at(xml, start, "w:moveFrom") ||
  is_docx_start_tag_at(xml, start, "w:moveTo")
}

///|
fn parse_docx_tracked_change(
  xml : String,
  start : Int,
  end_exclusive : Int,
  tag : String,
  key : DocxSourceKey,
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> DocxSourceInline {
  warnings.push({
    kind: DocxSourceWarningKind::TrackedChange,
    message: "tracked change inline preserved without review policy: " + tag,
    source_key: Some(key),
  })
  DocxSourceInline::TrackedChange({
    kind: tag,
    text: docx_visible_text_in_scope(
      docx_inner_xml_for_element(xml, start, end_exclusive, tag),
    ),
    child_inlines: docx_source_run_inlines(
      parse_docx_paragraph_runs(
        docx_inner_xml_for_element(xml, start, end_exclusive, tag),
        key,
        relationships,
        pkg,
        warnings,
      ),
    ),
    source_key: key,
  })
}

///|
fn docx_visible_text_in_scope(xml : String) -> String {
  let out = StringBuilder::new()
  let mut i = 0
  while i < xml.length() {
    let next_lt_rel = match xml[i:].find("<") {
      Some(rel) => rel
      None => break
    }
    let start = i + next_lt_rel
    if is_docx_start_tag_at(xml, start, "w:tab") {
      out.write_string("\t")
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:t") ||
      is_docx_start_tag_at(xml, start, "w:delText") ||
      is_docx_start_tag_at(xml, start, "m:t") {
      let tag = docx_tag_name_at(xml, start)
      let open_end_rel = match xml[start:].find(">") {
        Some(rel) => rel
        None => break
      }
      let text_start = start + open_end_rel + 1
      let close_tag = "</" + tag + ">"
      let close_rel = match xml[text_start:].find(close_tag) {
        Some(rel) => rel
        None => break
      }
      out.write_string(
        decode_docx_text(xml[text_start:text_start + close_rel].to_owned()),
      )
      i = text_start + close_rel + close_tag.length()
    } else if is_docx_start_tag_at(xml, start, "w:br") {
      out.write_string(
        docx_source_break_text_from_open_tag(docx_open_tag_at(xml, start)),
      )
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:cr") {
      out.write_string("\n")
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:sym") {
      out.write_string(
        docx_source_symbol_text_from_tag(docx_open_tag_at(xml, start)),
      )
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:softHyphen") {
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else if is_docx_start_tag_at(xml, start, "w:noBreakHyphen") {
      out.write_string("-")
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    } else {
      match find_docx_any_tag_end(xml, start) {
        Some(end_exclusive) => i = end_exclusive
        None => break
      }
    }
  }
  out.to_string()
}

///|
fn docx_math_text_signature(xml : String) -> String? {
  docx_non_empty_text(docx_visible_text_in_scope(xml))
}

///|
fn docx_non_empty_text(text : String) -> String? {
  if text.trim() == "" {
    None
  } else {
    Some(text)
  }
}

///|
fn docx_inner_xml_for_element(
  xml : String,
  start : Int,
  end_exclusive : Int,
  tag : String,
) -> String {
  let open_end = match find_docx_any_tag_end(xml, start) {
    Some(value) => value
    None => return ""
  }
  let close_len = ("</" + tag + ">").length()
  let inner_end = end_exclusive - close_len
  if is_docx_self_closing_tag(xml[start:open_end].to_owned()) ||
    inner_end <= open_end {
    ""
  } else {
    xml[open_end:inner_end].to_owned()
  }
}

///|
fn docx_child_source_key(
  parent : DocxSourceKey,
  kind : String,
  index : Int,
) -> DocxSourceKey {
  {
    part_name: parent.part_name,
    block_index: parent.block_index,
    node_key: parent.node_key + ":" + kind + ":" + index.to_string(),
  }
}

///|
fn docx_source_run_inlines(
  runs : Array[DocxSourceRun],
) -> Array[DocxSourceInline] {
  let out : Array[DocxSourceInline] = []
  for run in runs {
    for inline in run.inlines {
      out.push(inline)
    }
  }
  out
}

///|
fn docx_source_key(
  part_name : String,
  block_index : Int,
  kind : String,
) -> DocxSourceKey {
  {
    part_name,
    block_index,
    node_key: part_name + ":" + kind + ":" + block_index.to_string(),
  }
}

///|
fn docx_source_inline_text(inlines : Array[DocxSourceInline]) -> String {
  let out = StringBuilder::new()
  for inline in inlines {
    match inline {
      DocxSourceInline::Text(text) => out.write_string(text)
      DocxSourceInline::Tab => out.write_string("\t")
      DocxSourceInline::LineBreak => out.write_string("\n")
      DocxSourceInline::Break(value) =>
        out.write_string(docx_source_break_text(value))
      DocxSourceInline::Hyperlink(link) => out.write_string(link.text)
      DocxSourceInline::Media(media) =>
        out.write_string(docx_source_media_text(media))
      DocxSourceInline::TextBoxRef(_) => ()
      DocxSourceInline::Drawing(drawing) =>
        match drawing.media {
          Some(media) => out.write_string(docx_source_media_text(media))
          None => ()
        }
      DocxSourceInline::Shape(shape) =>
        match shape.media {
          Some(media) => out.write_string(docx_source_media_text(media))
          None => out.write_string(docx_source_inline_text(shape.child_inlines))
        }
      DocxSourceInline::ContentControl(control) =>
        out.write_string(control.text)
      DocxSourceInline::FieldUnsupported(field) =>
        out.write_string(docx_source_field_text(field))
      DocxSourceInline::Math(math) =>
        out.write_string(docx_source_math_text(math))
      DocxSourceInline::TrackedChange(change) => out.write_string(change.text)
      DocxSourceInline::SmartTag(smart_tag) =>
        out.write_string(docx_source_inline_text(smart_tag.child_inlines))
      DocxSourceInline::Symbol(symbol) =>
        out.write_string(docx_source_symbol_text(symbol))
      DocxSourceInline::Hyphen(hyphen) =>
        out.write_string(docx_source_hyphen_text(hyphen))
      DocxSourceInline::FootnoteRef(id) =>
        out.write_string("[footnote:" + id + "]")
      DocxSourceInline::EndnoteRef(id) =>
        out.write_string("[endnote:" + id + "]")
      DocxSourceInline::CommentRef(id) =>
        out.write_string("[comment:" + id + "]")
      DocxSourceInline::StructuralMarker(_) => ()
      DocxSourceInline::Bookmark(_) => ()
      DocxSourceInline::UnsupportedInline(_) =>
        out.write_string("[unsupported DOCX inline]")
      DocxSourceInline::Unsupported(_) => ()
    }
  }
  out.to_string()
}

///|
fn docx_source_field_text(field : DocxSourceField) -> String {
  match field.result_text {
    Some(value) => if value.trim() != "" { return value }
    None => ()
  }
  match field.instruction {
    Some(value) =>
      if value.trim() != "" {
        return "[field: " + value.trim().to_owned() + "]"
      }
    None => ()
  }
  match field.field_char_type {
    Some(value) =>
      if value.trim() != "" {
        return "[field: " + field.kind + ":" + value + "]"
      }
    None => ()
  }
  "[field: " + field.kind + "]"
}

///|
fn docx_source_math_text(math : DocxSourceMath) -> String {
  match math.text_signature {
    Some(value) => if value.trim() != "" { return "[math: " + value + "]" }
    None => ()
  }
  "[math]"
}

///|
fn docx_source_break_text(break_value : DocxSourceBreak) -> String {
  match break_value.kind {
    DocxBreakKind::Page => "[break: page]"
    DocxBreakKind::Column => "[break: column]"
    DocxBreakKind::Unknown =>
      match break_value.break_type {
        Some(value) => "[break: " + value + "]"
        None => "[break]"
      }
    DocxBreakKind::Line
    | DocxBreakKind::TextWrapping
    | DocxBreakKind::CarriageReturn => "\n"
  }
}

///|
fn docx_source_break_text_from_open_tag(open_tag : String) -> String {
  let break_type = read_docx_attr_value(open_tag, "w:type")
  let kind = match break_type {
    Some(value) =>
      if value == "page" {
        DocxBreakKind::Page
      } else if value == "column" {
        DocxBreakKind::Column
      } else if value == "textWrapping" {
        DocxBreakKind::TextWrapping
      } else {
        DocxBreakKind::Unknown
      }
    None => DocxBreakKind::Line
  }
  docx_source_break_text({
    kind,
    break_type,
    source_key: docx_source_key("", 0, "break"),
  })
}

///|
fn docx_source_symbol_text(symbol : DocxSourceSymbol) -> String {
  match symbol.char_hex {
    Some(value) => docx_source_symbol_text_from_hex(value)
    None => "[symbol]"
  }
}

///|
fn docx_source_symbol_text_from_tag(open_tag : String) -> String {
  match read_docx_attr_value(open_tag, "w:char") {
    Some(value) => docx_source_symbol_text_from_hex(value)
    None => "[symbol]"
  }
}

///|
fn docx_source_symbol_text_from_hex(value : String) -> String {
  match docx_parse_hex_codepoint(value) {
    Some(codepoint) =>
      if codepoint >= 0x20 && codepoint <= 0x7E {
        String::from_array([Int::unsafe_to_char(codepoint)])
      } else {
        "[symbol: " + value + "]"
      }
    None => "[symbol: " + value + "]"
  }
}

///|
fn docx_parse_hex_codepoint(value : String) -> Int? {
  let chars = value.trim().to_array()
  if chars.length() == 0 {
    return None
  }
  let mut out = 0
  for ch in chars {
    match docx_hex_value(ch) {
      Some(v) => out = (out << 4) + v
      None => return None
    }
  }
  Some(out)
}

///|
fn docx_hex_value(ch : Char) -> Int? {
  if ch >= '0' && ch <= '9' {
    Some(ch.to_int() - '0'.to_int())
  } else if ch >= 'A' && ch <= 'F' {
    Some(ch.to_int() - 'A'.to_int() + 10)
  } else if ch >= 'a' && ch <= 'f' {
    Some(ch.to_int() - 'a'.to_int() + 10)
  } else {
    None
  }
}

///|
fn docx_source_hyphen_text(hyphen : DocxSourceHyphen) -> String {
  match hyphen.kind {
    DocxHyphenKind::Soft => ""
    DocxHyphenKind::NoBreak => "-"
  }
}

///|
fn docx_source_media_text(media : DocxSourceMediaRef) -> String {
  match media.alt_text {
    Some(value) => if value.trim() != "" { return "[image: " + value + "]" }
    None => ()
  }
  match media.title {
    Some(value) => if value.trim() != "" { return "[image: " + value + "]" }
    None => ()
  }
  match media.target_part {
    Some(value) => if value.trim() != "" { return "[image: " + value + "]" }
    None => ()
  }
  match media.resolved_target {
    Some(value) => if value.trim() != "" { return "[image: " + value + "]" }
    None => ()
  }
  match media.relationship_id {
    Some(value) => if value.trim() != "" { return "[image: " + value + "]" }
    None => ()
  }
  "[image]"
}

///|
fn skip_docx_element_or_tag(xml : String, start : Int, tag : String) -> Int? {
  if tag != "" {
    match find_docx_element_end(xml, start, tag) {
      Some(end_exclusive) => return Some(end_exclusive)
      None => ()
    }
  }
  find_docx_any_tag_end(xml, start)
}

///|
fn find_docx_element_end(xml : String, start : Int, tag : String) -> Int? {
  match find_docx_any_tag_end(xml, start) {
    Some(open_end) =>
      if is_docx_start_tag_at(xml, start, tag) &&
        is_docx_self_closing_tag(xml[start:open_end].to_owned()) {
        return Some(open_end)
      }
    None => return None
  }
  let close_tag = "</" + tag + ">"
  let mut depth = 0
  let mut i = start
  while i < xml.length() {
    let pos = match find_docx_char_from(xml, i, 60) {
      Some(value) => value
      None => return None
    }
    if docx_string_has_prefix_at(xml, pos, close_tag) {
      depth -= 1
      let end_exclusive = pos + close_tag.length()
      if depth == 0 {
        return Some(end_exclusive)
      }
      i = end_exclusive
    } else if is_docx_start_tag_at(xml, pos, tag) {
      match find_docx_any_tag_end(xml, pos) {
        Some(end_exclusive) => {
          depth += 1
          if is_docx_self_closing_tag(xml[pos:end_exclusive].to_owned()) {
            depth -= 1
          }
          i = end_exclusive
        }
        None => return None
      }
    } else {
      match find_docx_any_tag_end(xml, pos) {
        Some(end_exclusive) => i = end_exclusive
        None => return None
      }
    }
  }
  None
}

///|
fn is_docx_start_tag_at(xml : String, start : Int, tag : String) -> Bool {
  if start < 0 || start + tag.length() + 1 > xml.length() {
    return false
  }
  if !docx_string_has_prefix_at(xml, start, "<" + tag) {
    return false
  }
  let boundary_index = start + tag.length() + 1
  if boundary_index >= xml.length() {
    return true
  }
  let ch = xml[boundary_index:boundary_index + 1]
  ch == " " || ch == "\t" || ch == "\n" || ch == "\r" || ch == "/" || ch == ">"
}

///|
fn find_docx_any_tag_end(xml : String, start : Int) -> Int? {
  match find_docx_char_from(xml, start, 62) {
    Some(pos) => Some(pos + 1)
    None => None
  }
}

///|
fn find_docx_char_from(xml : String, from : Int, ch : UInt16) -> Int? {
  let mut i = if from < 0 { 0 } else { from }
  while i < xml.length() {
    if xml.code_unit_at(i) == ch {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn docx_string_has_prefix_at(
  xml : String,
  start : Int,
  prefix : String,
) -> Bool {
  if start < 0 || start + prefix.length() > xml.length() {
    return false
  }
  let mut i = 0
  while i < prefix.length() {
    if xml.code_unit_at(start + i) != prefix.code_unit_at(i) {
      return false
    }
    i += 1
  }
  true
}

///|
fn find_docx_literal_from(xml : String, from : Int, value : String) -> Int? {
  let mut i = if from < 0 { 0 } else { from }
  while i + value.length() <= xml.length() {
    if docx_string_has_prefix_at(xml, i, value) {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn is_docx_self_closing_tag(tag : String) -> Bool {
  let trimmed = tag.trim()
  trimmed.has_suffix("/>")
}

///|
fn docx_tag_name_at(xml : String, start : Int) -> String {
  if start < 0 || start >= xml.length() || xml.code_unit_at(start) != 60 {
    return ""
  }
  let mut i = start + 1
  if i < xml.length() && xml.code_unit_at(i) == 47 {
    i += 1
  }
  let name_start = i
  while i < xml.length() {
    let ch = xml[i:i + 1]
    if ch == " " ||
      ch == "\t" ||
      ch == "\n" ||
      ch == "\r" ||
      ch == "/" ||
      ch == ">" {
      break
    }
    i += 1
  }
  xml[name_start:i].to_owned()
}

///|
fn decode_docx_text(text : String) -> String {
  text
  .replace(old="&lt;", new="<")
  .replace(old="&gt;", new=">")
  .replace(old="&amp;", new="&")
  .replace(old="&quot;", new="\"")
  .replace(old="&apos;", new="'")
}
