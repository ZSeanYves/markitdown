///|
fn extract_slide_comments(
  p : PptxPackage,
  rel_ctx : PptxSlideRelContext,
) -> Array[String] raise {
  let comments_part = match rel_ctx.comments_part {
    Some(part) => part
    None => return []
  }

  let comments_xml = p.read_text_optional(comments_part)
  if comments_xml.trim() == "" {
    return []
  }

  let author_names = parse_comment_author_names(
    p.read_text_optional("ppt/commentAuthors.xml"),
  )
  parse_comment_lines(comments_xml, author_names)
}

///|
fn parse_comment_author_names(xml : String) -> Map[String, String] raise {
  let out : Map[String, String] = Map([])
  if xml.trim() == "" {
    return out
  }
  let bs = @utf8.encode(xml)
  let mut pos = 0
  while pos < bs.length() {
    let start0 = find_bytes(bs, pat("<p:cmAuthor"), pos).unwrap_or(-1)
    if start0 < 0 {
      break
    }
    match read_open_tag_name(bs, start0) {
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
    let gt0 = find_bytes(bs, pat(">"), start0).unwrap_or(-1)
    if gt0 < 0 {
      break
    }
    let tag = bs[start0:gt0 + 1].to_owned()
    match read_attr_value_in_tag_bytes(tag, "id") {
      Some(id) =>
        match read_attr_value_in_tag_bytes(tag, "name") {
          Some(name) => {
            let key = id.trim().to_owned()
            let value = name.trim().to_owned()
            if key != "" && value != "" {
              out.set(key, value)
            }
          }
          None => ()
        }
      None => ()
    }
    pos = gt0 + 1
  }
  out
}

///|
fn parse_comment_lines(
  comments_xml : String,
  author_names : Map[String, String],
) -> Array[String] raise {
  let bs = @utf8.encode(comments_xml)
  let out : Array[String] = []
  let mut pos = 0
  while pos < bs.length() {
    let start0 = find_bytes(bs, pat("<p:cm"), pos).unwrap_or(-1)
    if start0 < 0 {
      break
    }
    match read_open_tag_name(bs, start0) {
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
    let end0 = find_matching_named_element_close(bs, start0, "p:cm").unwrap_or(
      -1,
    )
    if end0 < 0 {
      break
    }
    let block = bs[start0:end0].to_owned()
    let gt0 = find_bytes(block, pat(">"), 0).unwrap_or(-1)
    if gt0 >= 0 {
      let tag = block[0:gt0 + 1].to_owned()
      let author_id = match read_attr_value_in_tag_bytes(tag, "authorId") {
        Some(id) => id.trim().to_owned()
        None => ""
      }
      let text = match first_tag_text_value(block, "<p:text>", "</p:text>") {
        Some(value) => value.trim().to_owned()
        None => ""
      }
      if text != "" {
        let line = match author_names.get(author_id) {
          Some(author) => author + ": " + text
          None =>
            if author_id != "" {
              "Author " + author_id + ": " + text
            } else {
              text
            }
        }
        out.push(line)
      }
    }
    pos = end0
  }
  out
}

///|
fn first_tag_text_value(
  xml : Bytes,
  open_tag : String,
  close_tag : String,
) -> String? raise {
  let start0 = find_bytes(xml, pat(open_tag), 0).unwrap_or(-1)
  if start0 < 0 {
    return None
  }
  let content_start = start0 + pat(open_tag).length()
  let end0 = find_bytes(xml, pat(close_tag), content_start).unwrap_or(-1)
  if end0 < 0 {
    return None
  }
  let raw = bytes_slice_to_string(xml, content_start, end0)
  let value = xml_unescape(raw).trim().to_owned()
  if value == "" {
    None
  } else {
    Some(value)
  }
}
