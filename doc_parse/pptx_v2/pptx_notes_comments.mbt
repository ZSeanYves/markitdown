///|
fn parse_notes_for_slide(
  ctx : PptxSourceParseContext,
  slide_part : String,
) -> PptxNotesSlide? raise {
  let mut notes_part : String? = None
  for rel in read_source_relationships(ctx, slide_part) {
    if rel.rel_type.has_suffix("/notesSlide") &&
      rel.resolved_target.has_prefix("ppt/notesSlides/") &&
      rel.resolved_target.has_suffix(".xml") {
      notes_part = Some(rel.resolved_target)
    }
  }
  let part = match notes_part {
    Some(p) => p
    None => return None
  }
  if !@ox.has_part(ctx.pkg, part) {
    ctx.warnings.push(
      pptx_warning(
        PptxWarningKind::MissingRelationshipTarget,
        PptxWarningSeverity::Warning,
        slide_part,
        "notes",
        None,
        None,
        "missing notes part: " + part,
      ),
    )
    return None
  }
  let xml = read_source_part_bytes(ctx, part).unwrap_or(Bytes::from_array([]))
  let paragraphs : Array[PptxParagraph] = []
  match find_sp_tree_inner(xml) {
    Some(inner) => {
      let objects = parse_shape_container(
        ctx,
        inner,
        default_shape_container_context(part),
      )
      collect_paragraphs_from_objects(paragraphs, objects)
    }
    None => ()
  }
  let limited_paragraphs = limit_notes_paragraphs(ctx, part, paragraphs)
  Some({
    part_name: part,
    owning_slide_part: slide_part,
    paragraphs: limited_paragraphs,
    source_key: pptx_source_key(part, "notes"),
  })
}

///|
fn limit_notes_paragraphs(
  ctx : PptxSourceParseContext,
  part : String,
  paragraphs : Array[PptxParagraph],
) -> Array[PptxParagraph] {
  if paragraphs.length() <= ctx.budget.max_notes_comments_per_slide {
    return paragraphs
  }
  push_over_budget_warning(
    ctx,
    part,
    "notes",
    None,
    None,
    "pptx v2 notes paragraph budget exceeded",
  )
  let out : Array[PptxParagraph] = []
  for i in 0..<ctx.budget.max_notes_comments_per_slide {
    out.push(paragraphs[i])
  }
  out
}

///|
fn collect_paragraphs_from_objects(
  out : Array[PptxParagraph],
  objects : Array[PptxObject],
) -> Unit {
  for obj in objects {
    match obj {
      PptxObject::Shape(shape) =>
        match shape.text_body {
          Some(body) =>
            for p in body.paragraphs {
              out.push(p)
            }
          None => ()
        }
      PptxObject::Group(group) =>
        collect_paragraphs_from_objects(out, group.children)
      _ => ()
    }
  }
}

///|
fn parse_comment_authors(
  ctx : PptxSourceParseContext,
) -> Array[PptxCommentAuthor] raise {
  let xml = match read_source_part_bytes(ctx, "ppt/commentAuthors.xml") {
    Some(bytes) => bytes
    None => return []
  }
  let out : Array[PptxCommentAuthor] = []
  let mut pos = 0
  while true {
    let p0 = find_bytes(xml, pat("<p:cmAuthor"), pos)
    match p0 {
      None => break
      Some(start) => {
        let gt = find_bytes(xml, pat(">"), start).unwrap_or(-1)
        if gt < 0 {
          break
        }
        let tag = xml[start:gt + 1].to_owned()
        let id = read_attr_value_in_tag_bytes(tag, "id").unwrap_or("")
        let name = read_attr_value_in_tag_bytes(tag, "name").unwrap_or("")
        if id.trim() != "" && name.trim() != "" {
          out.push({
            id: id.trim().to_owned(),
            name: name.trim().to_owned(),
            initials: normalize_optional_attr(
              read_attr_value_in_tag_bytes(tag, "initials"),
            ),
          })
        }
        pos = gt + 1
      }
    }
  }
  out
}

///|
fn parse_comments_for_slide(
  ctx : PptxSourceParseContext,
  slide_part : String,
  authors : Array[PptxCommentAuthor],
) -> Array[PptxComment] raise {
  let mut comments_part : String? = None
  for rel in read_source_relationships(ctx, slide_part) {
    if rel.rel_type.has_suffix("/comments") ||
      rel.rel_type.contains("relationships/comments") {
      comments_part = Some(rel.resolved_target)
    }
  }
  let part = match comments_part {
    Some(p) => p
    None => return []
  }
  let xml = match read_source_part_bytes(ctx, part) {
    Some(bytes) => bytes
    None => return []
  }
  let out : Array[PptxComment] = []
  let mut pos = 0
  let mut idx = 0
  while true {
    let p0 = find_bytes(xml, pat("<p:cm"), pos)
    match p0 {
      None => break
      Some(start) => {
        match read_open_tag_name(xml, start) {
          Some(name) =>
            if name != "p:cm" {
              pos = start + 1
              continue
            }
          None => {
            pos = start + 1
            continue
          }
        }
        match slice_full_element(xml, start, "p:cm") {
          Some((block, next_pos)) => {
            let gt = find_bytes(block, pat(">"), 0).unwrap_or(-1)
            if gt >= 0 {
              let tag = block[0:gt + 1].to_owned()
              let author_id = read_attr_value_in_tag_bytes(tag, "authorId").unwrap_or(
                "",
              )
              let text = first_text_value(block, "<p:text>", "</p:text>").unwrap_or(
                "",
              )
              if text.trim() != "" {
                if idx >= ctx.budget.max_notes_comments_per_slide {
                  push_over_budget_warning(
                    ctx,
                    part,
                    "comments",
                    None,
                    None,
                    "pptx v2 comment budget exceeded",
                  )
                  break
                }
                idx += 1
                let author_name = find_author_name(authors, author_id)
                if author_id.trim() != "" && author_name is None {
                  ctx.warnings.push(
                    pptx_warning(
                      PptxWarningKind::MissingCommentAuthor,
                      PptxWarningSeverity::Warning,
                      part,
                      "comment-" + idx.to_string(),
                      None,
                      None,
                      "missing comment author: " + author_id,
                    ),
                  )
                }
                out.push({
                  author_id,
                  author_name,
                  text: text.trim().to_owned(),
                  idx: read_attr_value_in_tag_bytes(tag, "idx"),
                  datetime: read_attr_value_in_tag_bytes(tag, "dt"),
                  source_key: pptx_source_key(
                    part,
                    "comment-" + idx.to_string(),
                  ),
                })
              }
            }
            pos = next_pos
          }
          None => break
        }
      }
    }
  }
  out
}

///|
fn find_author_name(authors : Array[PptxCommentAuthor], id : String) -> String? {
  for author in authors {
    if author.id == id {
      return Some(author.name)
    }
  }
  None
}

///|
fn first_text_value(
  xml : Bytes,
  open_tag : String,
  close_tag : String,
) -> String? raise {
  let start = find_bytes(xml, pat(open_tag), 0).unwrap_or(-1)
  if start < 0 {
    return None
  }
  let content_start = start + pat(open_tag).length()
  let end_ = find_bytes(xml, pat(close_tag), content_start).unwrap_or(-1)
  if end_ < 0 {
    return None
  }
  Some(xml_unescape(bytes_slice_to_string(xml, content_start, end_)))
}
