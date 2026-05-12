///|
fn read_pptx_comment_authors(
  pkg : @ox.OoxmlPackage,
) -> Array[PptxCommentAuthor] raise {
  let part_path = "ppt/commentAuthors.xml"
  if !@ox.has_part(pkg, part_path) {
    return []
  }
  let xml = @ox.read_part_bytes(pkg, part_path) catch { _ => return [] }
  parse_pptx_comment_authors_xml(xml)
}

///|
fn parse_pptx_comment_authors_xml(
  xml : Bytes,
) -> Array[PptxCommentAuthor] raise {
  let out : Array[PptxCommentAuthor] = []
  let mut pos = 0
  while pos < xml.length() {
    let start0 = find_bytes(xml, pat("<p:cmAuthor"), pos).unwrap_or(-1)
    if start0 < 0 {
      break
    }
    match read_open_tag_name(xml, start0) {
      Some(name) =>
        if name != "p:cmAuthor" {
          pos = start0 + 1
          continue
        }
      None => {
        pos = start0 + 1
        continue
      }
    }
    let gt0 = find_bytes(xml, pat(">"), start0).unwrap_or(-1)
    if gt0 < 0 {
      break
    }
    let tag = xml[start0:gt0 + 1].to_owned()
    let id = match read_attr_value_in_tag_bytes(tag, "id") {
      Some(value) => value.trim().to_owned()
      None => ""
    }
    let name = match read_attr_value_in_tag_bytes(tag, "name") {
      Some(value) => value.trim().to_owned()
      None => ""
    }
    if id != "" {
      out.push({
        id,
        name,
        initials: read_attr_value_in_tag_bytes(tag, "initials"),
      })
    }
    pos = gt0 + 1
  }
  out
}

///|
fn build_pptx_comment_author_map(
  authors : Array[PptxCommentAuthor],
) -> Map[String, PptxCommentAuthor] {
  let out : Map[String, PptxCommentAuthor] = Map::new()
  for author in authors {
    out.set(author.id, author)
  }
  out
}

///|
fn parse_pptx_slide_comments(
  pkg : @ox.OoxmlPackage,
  rels : PptxRelationshipIndex,
  author_map : Map[String, PptxCommentAuthor],
  issues : Array[PptxValidationIssue],
) -> Array[PptxComment] raise {
  let part_path = match rels.comments_part {
    Some(part) => part
    None => return []
  }

  if !@ox.has_part(pkg, part_path) {
    issues.push(
      pptx_issue(
        PptxValidationIssueKind::MissingRelationshipTarget,
        PptxValidationSeverity::Warning,
        Some(part_path),
        rels.comments_relationship_id,
        None,
        "missing comments part: " + part_path,
      ),
    )
    return []
  }

  let xml = @ox.read_part_bytes(pkg, part_path) catch { _ => return [] }
  parse_pptx_slide_comments_xml(xml, author_map)
}

///|
fn parse_pptx_slide_comments_xml(
  xml : Bytes,
  author_map : Map[String, PptxCommentAuthor],
) -> Array[PptxComment] raise {
  let out : Array[PptxComment] = []
  let mut pos = 0
  while pos < xml.length() {
    let start0 = find_bytes(xml, pat("<p:cm"), pos).unwrap_or(-1)
    if start0 < 0 {
      break
    }
    match read_open_tag_name(xml, start0) {
      Some(name) =>
        if name != "p:cm" {
          pos = start0 + 1
          continue
        }
      None => {
        pos = start0 + 1
        continue
      }
    }
    let end0 = find_matching_named_element_close(xml, start0, "p:cm").unwrap_or(
      -1,
    )
    if end0 < 0 {
      break
    }
    let block = xml[start0:end0].to_owned()
    let gt0 = find_bytes(block, pat(">"), 0).unwrap_or(-1)
    if gt0 >= 0 {
      let tag = block[0:gt0 + 1].to_owned()
      let author_id = match read_attr_value_in_tag_bytes(tag, "authorId") {
        Some(value) => value.trim().to_owned()
        None => ""
      }
      let text = match first_tag_text_value(block, "<p:text>", "</p:text>") {
        Some(value) => value.trim().to_owned()
        None => ""
      }
      if text != "" {
        let author_name = match author_map.get(author_id) {
          Some(author) =>
            if author.name.trim() == "" {
              None
            } else {
              Some(author.name)
            }
          None => None
        }
        out.push({
          author_id,
          author_name,
          text,
          idx: read_attr_value_in_tag_bytes(tag, "idx"),
          datetime: read_attr_value_in_tag_bytes(tag, "dt"),
        })
      }
    }
    pos = end0
  }
  out
}
