///|
fn media_kind_from_relationship_or_content_type(
  rel_type : String?,
  content_type : String?,
) -> PptxMediaKind {
  match content_type {
    Some(ct) =>
      if ct.has_prefix("image/") {
        return PptxMediaKind::Image
      } else if ct.has_prefix("audio/") {
        return PptxMediaKind::Audio
      } else if ct.has_prefix("video/") {
        return PptxMediaKind::Video
      }
    None => ()
  }

  match rel_type {
    Some(rt) =>
      if rt.has_suffix("/image") {
        PptxMediaKind::Image
      } else if rt.has_suffix("/audio") {
        PptxMediaKind::Audio
      } else if rt.has_suffix("/video") {
        PptxMediaKind::Video
      } else {
        PptxMediaKind::Other
      }
    None => PptxMediaKind::Other
  }
}

///|
fn normalize_optional_pptx_attr(value : String?) -> String? {
  match value {
    Some(raw) => {
      let trimmed = xml_unescape(raw).trim().to_owned()
      if trimmed == "" {
        None
      } else {
        Some(trimmed)
      }
    }
    None => None
  }
}

///|
fn content_type_for_pptx_target(
  pkg : @ox.OoxmlPackage,
  part_name : String,
) -> String? {
  try @ox.lookup_content_type(pkg, part_name) catch {
    _ => None
  } noraise {
    value => value
  }
}

///|
fn read_picture_media_ref(
  pic_xml : Bytes,
  ctx : PptxShapeParseContext,
  object_ref : String?,
) -> PptxMediaRef? raise {
  let rid = read_attr_value_in_first_tag_bytes(pic_xml, "<a:blip", "r:embed")
  let descr = normalize_optional_pptx_attr(
    read_attr_value_in_first_tag_bytes(pic_xml, "<p:cNvPr", "descr"),
  )
  let title = normalize_optional_pptx_attr(
    read_attr_value_in_first_tag_bytes(pic_xml, "<p:cNvPr", "title"),
  )

  match rid {
    Some(rel_id) =>
      match find_pptx_relationship_by_id(ctx.rels, rel_id) {
        Some(rel) => {
          let content_type = content_type_for_pptx_target(
            ctx.pkg,
            rel.resolved_target,
          )
          if rel.resolved_target.trim() == "" {
            ctx.issues.push(
              pptx_issue(
                PptxValidationIssueKind::MissingRelationshipTarget,
                PptxValidationSeverity::Warning,
                Some(ctx.source_part),
                Some(rel_id),
                object_ref,
                "missing media relationship target: " + rel_id,
              ),
            )
          } else if !@ox.has_part(ctx.pkg, rel.resolved_target) {
            ctx.issues.push(
              pptx_issue(
                PptxValidationIssueKind::MissingMediaPart,
                PptxValidationSeverity::Warning,
                Some(ctx.source_part),
                Some(rel_id),
                object_ref,
                "missing media part: " + rel.resolved_target,
              ),
            )
          }

          Some({
            relationship_id: Some(rel.id),
            target_part: if rel.resolved_target.trim() == "" {
              None
            } else {
              Some(rel.resolved_target)
            },
            content_type,
            kind: media_kind_from_relationship_or_content_type(
              Some(rel.rel_type),
              content_type,
            ),
            alt_text: descr,
            title,
            source_shape_ref: object_ref,
            source_part: Some(ctx.source_part),
          })
        }
        None => {
          ctx.issues.push(
            pptx_issue(
              PptxValidationIssueKind::MissingRelationshipTarget,
              PptxValidationSeverity::Warning,
              Some(ctx.source_part),
              Some(rel_id),
              object_ref,
              "missing media relationship target: " + rel_id,
            ),
          )
          Some({
            relationship_id: Some(rel_id),
            target_part: None,
            content_type: None,
            kind: PptxMediaKind::Image,
            alt_text: descr,
            title,
            source_shape_ref: object_ref,
            source_part: Some(ctx.source_part),
          })
        }
      }
    None => None
  }
}
