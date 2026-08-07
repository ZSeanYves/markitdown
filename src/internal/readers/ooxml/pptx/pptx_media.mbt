///|
fn read_picture_media_ref(
  ctx : PptxSourceParseContext,
  part_name : String,
  pic_xml : Bytes,
  source_key : PptxSourceKey,
) -> PptxMediaRef? raise {
  let rid = read_attr_value_in_first_tag_bytes(pic_xml, "<a:blip", "r:embed")
  let external_rid = read_attr_value_in_first_tag_bytes(
    pic_xml, "<a:blip", "r:link",
  )
  let rel_id = match rid {
    Some(v) => Some(v)
    None => external_rid
  }
  let alt_text = normalize_optional_attr(
    read_attr_value_in_first_tag_bytes(pic_xml, "<p:cNvPr", "descr"),
  )
  let title = normalize_optional_attr(
    read_attr_value_in_first_tag_bytes(pic_xml, "<p:cNvPr", "title"),
  )
  match rel_id {
    None => None
    Some(id) => {
      if !consume_media_ref_budget(ctx, part_name, source_key, id) {
        return Some({
          relationship_id: Some(id),
          source_part: part_name,
          target: None,
          resolved_target: None,
          target_mode: None,
          content_type: None,
          original_extension: None,
          resolved_extension: None,
          alt_text,
          title,
          kind: Image,
          is_external: false,
          unsupported: true,
          data: None,
          alternate_media: [],
          source_key,
        })
      }
      match find_source_relationship_by_id(ctx, part_name, id) {
        Some(rel) => {
          let is_external = rel.target_mode == External
          let content_type = if is_external {
            None
          } else {
            part_content_type(ctx, rel.resolved_target)
          }
          let ext = extension_from_target(rel.resolved_target)
          let kind = media_kind_from_type(rel.rel_type, content_type)
          let unsupported = media_unsupported(kind, ext, content_type)
          if is_external {
            ctx.warnings.push(
              pptx_warning(
                ExternalMedia,
                Warning,
                part_name,
                source_key.node_key,
                Some(id),
                None,
                "external media is represented but not fetched: " +
                rel.resolved_target,
              ),
            )
          } else if rel.resolved_target.trim() != "" &&
            !@ox.has_part(ctx.pkg, rel.resolved_target) {
            ctx.warnings.push(
              pptx_warning(
                MissingMediaPart,
                Warning,
                part_name,
                source_key.node_key,
                Some(id),
                None,
                "missing media part: " + rel.resolved_target,
              ),
            )
          }
          if unsupported {
            ctx.warnings.push(
              pptx_warning(
                UnsupportedMedia,
                Warning,
                part_name,
                source_key.node_key,
                Some(id),
                None,
                "unsupported media type: " + rel.resolved_target,
              ),
            )
          }
          let data = if !is_external &&
            !unsupported &&
            @ox.has_part(ctx.pkg, rel.resolved_target) {
            read_media_bytes_with_budget(
              ctx,
              part_name,
              source_key,
              id,
              rel.resolved_target,
            )
          } else {
            None
          }
          Some({
            relationship_id: Some(id),
            source_part: part_name,
            target: Some(rel.target),
            resolved_target: Some(rel.resolved_target),
            target_mode: Some(rel.target_mode),
            content_type,
            original_extension: ext,
            resolved_extension: ext,
            alt_text,
            title,
            kind,
            is_external,
            unsupported,
            data,
            alternate_media: [],
            source_key,
          })
        }
        None => {
          ctx.warnings.push(
            pptx_warning(
              MissingRelationshipTarget,
              Warning,
              part_name,
              source_key.node_key,
              Some(id),
              None,
              "missing media relationship target: " + id,
            ),
          )
          Some({
            relationship_id: Some(id),
            source_part: part_name,
            target: None,
            resolved_target: None,
            target_mode: None,
            content_type: None,
            original_extension: None,
            resolved_extension: None,
            alt_text,
            title,
            kind: Image,
            is_external: false,
            unsupported: true,
            data: None,
            alternate_media: [],
            source_key,
          })
        }
      }
    }
  }
}

///|
fn read_media_bytes_with_budget(
  ctx : PptxSourceParseContext,
  part_name : String,
  source_key : PptxSourceKey,
  rel_id : String,
  target_part : String,
) -> Bytes? {
  match @ox.part_declared_size(ctx.pkg, target_part) {
    Some(declared) if declared < 0 ||
      declared > ctx.budget.max_media_bytes_per_asset => {
      push_over_budget_warning(
        ctx,
        part_name,
        source_key.node_key,
        Some(rel_id),
        None,
        "pptx media asset byte budget exceeded: " + target_part,
      )
      return None
    }
    Some(declared) if ctx.media_bytes_loaded.val >
      ctx.budget.max_media_bytes_total - declared => {
      push_over_budget_warning(
        ctx,
        part_name,
        source_key.node_key,
        Some(rel_id),
        None,
        "pptx total media byte budget exceeded",
      )
      return None
    }
    _ => ()
  }
  let bytes = read_source_part_bytes(ctx, target_part)
  match bytes {
    None => None
    Some(data) => {
      if data.length() > ctx.budget.max_media_bytes_per_asset {
        push_over_budget_warning(
          ctx,
          part_name,
          source_key.node_key,
          Some(rel_id),
          None,
          "pptx media asset byte budget exceeded: " + target_part,
        )
        return None
      }
      if ctx.media_bytes_loaded.val >
        ctx.budget.max_media_bytes_total - data.length() {
        push_over_budget_warning(
          ctx,
          part_name,
          source_key.node_key,
          Some(rel_id),
          None,
          "pptx total media byte budget exceeded",
        )
        return None
      }
      ctx.media_bytes_loaded.val += data.length()
      Some(data)
    }
  }
}

///|
fn consume_media_ref_budget(
  ctx : PptxSourceParseContext,
  part_name : String,
  source_key : PptxSourceKey,
  rel_id : String,
) -> Bool {
  ctx.media_ref_count.val += 1
  if ctx.media_ref_count.val > ctx.budget.max_media_exports_per_deck {
    if ctx.media_ref_count.val == ctx.budget.max_media_exports_per_deck + 1 {
      push_over_budget_warning(
        ctx,
        part_name,
        source_key.node_key,
        Some(rel_id),
        None,
        "pptx media reference budget exceeded",
      )
    }
    false
  } else {
    true
  }
}

///|
fn extension_from_target(target : String) -> String? {
  let t = target.trim().to_lower()
  let chars = t.to_array()
  let mut dot = -1
  for i = 0; i < chars.length(); i = i + 1 {
    if chars[i] == '.' {
      dot = i
    }
  }
  if dot < 0 || dot + 1 >= chars.length() {
    None
  } else {
    let ext = String::from_array(chars[dot + 1:])
    if ext == "" {
      None
    } else {
      Some(ext)
    }
  }
}

///|
fn media_kind_from_type(
  rel_type : String,
  content_type : String?,
) -> PptxMediaKind {
  match content_type {
    Some(ct) =>
      if ct.has_prefix("image/") {
        return Image
      } else if ct.has_prefix("audio/") {
        return Audio
      } else if ct.has_prefix("video/") {
        return Video
      }
    None => ()
  }
  if rel_type.has_suffix("/image") {
    Image
  } else if rel_type.has_suffix("/audio") {
    Audio
  } else if rel_type.has_suffix("/video") {
    Video
  } else {
    Other
  }
}

///|
fn media_unsupported(
  kind : PptxMediaKind,
  ext : String?,
  content_type : String?,
) -> Bool {
  match kind {
    Image => {
      let e = ext.unwrap_or("").to_lower()
      let ct = content_type.unwrap_or("").to_lower()
      !(e == "png" ||
      e == "jpg" ||
      e == "jpeg" ||
      e == "gif" ||
      e == "bmp" ||
      e == "webp" ||
      e == "svg" ||
      ct.has_prefix("image/png") ||
      ct.has_prefix("image/jpeg") ||
      ct.has_prefix("image/gif") ||
      ct.has_prefix("image/bmp") ||
      ct.has_prefix("image/webp") ||
      ct.has_prefix("image/svg"))
    }
    _ => true
  }
}
