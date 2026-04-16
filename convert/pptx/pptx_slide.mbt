///|
/// scan one <p:sp> shape xml, extract each <a:p> as one paragraph
/// - for title-like shapes, merge consecutive non-empty paragraphs into one
fn extract_shape_paragraphs(
  xml : Bytes,
  from_title_shape : Bool,
  from_body_shape : Bool,
  hyperlinks : Map[String, String],
  para_seq : Ref[Int],
) -> Array[SlideParagraph] raise {
  let paras : Array[SlideParagraph] = []
  let shape_link = shape_level_single_hyperlink(xml, hyperlinks)

  let open_p = pat("<a:p")
  let close_p = pat("</a:p>")
  let gt_pat = pat(">")

  let mut pos = 0
  while true {
    let p0 = find_bytes(xml, open_p, pos)
    match p0 {
      None => break
      Some(i0) => {
        let gt = find_bytes(xml, gt_pat, i0)
        match gt {
          None => break
          Some(gt0) => {
            let inner_start = gt0 + 1
            let p_end = find_bytes(xml, close_p, inner_start)
            match p_end {
              None => break
              Some(p_end0) => {
                let inlines0 = extract_text_inlines(
                  xml, inner_start, p_end0, hyperlinks,
                )
                let text = render_plain_text_inlines(inlines0)
                  .trim()
                  .to_string()
                let inlines = apply_shape_level_link_if_needed(
                  inlines0, text, shape_link,
                )

                let bullet_kind = paragraph_bullet_kind(
                  xml, inner_start, p_end0,
                )
                let level = paragraph_level(xml, inner_start, p_end0)

                if text != "" {
                  para_seq.val = para_seq.val + 1
                  paras.push({
                    source_para_id: para_seq.val,
                    text,
                    inlines,
                    bullet_kind,
                    level,
                    from_title_shape,
                    from_body_shape,
                  })
                }

                pos = p_end0 + close_p.length()
              }
            }
          }
        }
      }
    }
  }

  if !from_title_shape {
    return paras
  }

  if paras.length() <= 1 {
    return paras
  }

  let merged_parts : Array[String] = []
  for para in paras {
    let t = normalize_slide_text(para.text)
    if t != "" {
      merged_parts.push(t)
    }
  }

  if merged_parts.length() == 0 {
    return []
  }

  para_seq.val = para_seq.val + 1
  let merged_para_id = para_seq.val

  [
    {
      source_para_id: merged_para_id,
      text: merged_parts.join(" "),
      inlines: [@cor.Inline::Text(merged_parts.join(" "))],
      bullet_kind: None,
      level: 0,
      from_title_shape: true,
      from_body_shape,
    },
  ]
}

///|
fn apply_shape_level_link_if_needed(
  inlines : Array[@cor.Inline],
  text : String,
  shape_link : String?,
) -> Array[@cor.Inline] {
  if inlines_has_hyperlink(inlines) {
    return inlines
  }
  match shape_link {
    Some(url) =>
      if text.trim() == "" || url.trim() == "" {
        inlines
      } else {
        [@cor.Inline::Link(text, url.trim().to_string())]
      }
    None => inlines
  }
}

///|
fn inlines_has_hyperlink(xs : Array[@cor.Inline]) -> Bool {
  for x in xs {
    match x {
      @cor.Inline::Link(_, _) => return true
      _ => ()
    }
  }
  false
}

///|
fn shape_level_single_hyperlink(
  shape_xml : Bytes,
  hyperlinks : Map[String, String],
) -> String? raise {
  let open_h = pat("<a:hlinkClick")
  let gt_pat = pat(">")
  let urls : Map[String, Bool] = {}

  let mut pos = 0
  while true {
    let p0 = find_bytes(shape_xml, open_h, pos)
    match p0 {
      None => break
      Some(i0) => {
        let gt = find_bytes(shape_xml, gt_pat, i0).unwrap_or(-1)
        if gt < 0 {
          break
        }
        let tag = shape_xml[i0:gt + 1].to_bytes()
        match read_attr_value_in_tag_bytes(tag, "r:id") {
          Some(rid) =>
            match hyperlinks.get(rid) {
              Some(url) => {
                let u = url.trim().to_string()
                if u != "" {
                  urls.set(u, true)
                }
              }
              None => ()
            }
          None => ()
        }
        pos = gt + 1
      }
    }
  }

  if urls.length() != 1 {
    return None
  }
  for entry in urls {
    let (u, _) = entry
    return Some(u)
  }
  None
}
