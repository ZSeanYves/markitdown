///|
priv enum PptxBlock {
  Heading(String)
  Paragraph(String)
  ListItem(String)
}

///|
priv struct SlideParagraph {
  text : String
  is_bullet : Bool
  from_title_shape : Bool
  from_body_shape : Bool
}

///|

///|
/// scan slide xml by shape (<p:sp>), then extract each <a:p>
/// with simple shape context (title/body)
fn extract_slide_paragraphs(xml : Bytes) -> Array[SlideParagraph] raise {
  let out : Array[SlideParagraph] = []

  let open_sp = pat("<p:sp")
  let close_sp = pat("</p:sp>")
  let gt_pat = pat(">")

  let mut pos = 0
  while true {
    let s0 = find_bytes(xml, open_sp, pos)
    match s0 {
      None => break
      Some(i0) => {
        let gt = find_bytes(xml, gt_pat, i0)
        match gt {
          None => break
          Some(_gt0) => {
            let sp_end = find_bytes(xml, close_sp, i0)
            match sp_end {
              None => break
              Some(sp_end0) => {
                let sp_xml = xml[i0:sp_end0 + close_sp.length()].to_bytes()
                let is_title = shape_is_title_like(sp_xml)
                let is_body = shape_is_body_like(sp_xml)

                let paras = extract_shape_paragraphs(sp_xml, is_title, is_body)
                for para in paras {
                  out.push(para)
                }

                pos = sp_end0 + close_sp.length()
              }
            }
          }
        }
      }
    }
  }

  out
}

///|
/// scan one <p:sp> shape xml, extract each <a:p> as one paragraph
fn extract_shape_paragraphs(
  xml : Bytes,
  from_title_shape : Bool,
  from_body_shape : Bool,
) -> Array[SlideParagraph] raise {
  let out : Array[SlideParagraph] = []

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
                let text = extract_text_runs(xml, inner_start, p_end0)
                  .trim()
                  .to_string()

                let is_bullet = paragraph_has_bullet(xml, inner_start, p_end0)

                if text != "" {
                  out.push({
                    text,
                    is_bullet,
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

  out
}

///|
fn classify_slide_paragraphs(
  paras : Array[SlideParagraph],
) -> Array[PptxBlock] raise {
  let out : Array[PptxBlock] = []
  let mut seen_heading = false

  for para in paras {
    let p = para.text.trim().to_string()
    if p == "" {
      continue
    }

    if para.from_title_shape && !seen_heading {
      out.push(PptxBlock::Heading(p))
      seen_heading = true
      continue
    }

    if para.is_bullet || is_bullet_like(p) {
      out.push(PptxBlock::ListItem(strip_bullet_prefix(p)))
      continue
    }

    if !seen_heading && !para.from_body_shape && looks_like_slide_title(p) {
      out.push(PptxBlock::Heading(p))
      seen_heading = true
      continue
    }

    out.push(PptxBlock::Paragraph(p))
  }

  out
}

///|
fn paragraph_has_bullet(xml : Bytes, start : Int, end_ : Int) -> Bool {
  let bu_char = pat("<a:buChar")
  let bu_auto = pat("<a:buAutoNum")
  let bu_blip = pat("<a:buBlip")
  let bu_none = pat("<a:buNone")

  let has_bu_none = match find_bytes(xml, bu_none, start) {
    Some(i) => i < end_
    None => false
  }
  if has_bu_none {
    return false
  }

  let has_bu_char = match find_bytes(xml, bu_char, start) {
    Some(i) => i < end_
    None => false
  }
  if has_bu_char {
    return true
  }

  let has_bu_auto = match find_bytes(xml, bu_auto, start) {
    Some(i) => i < end_
    None => false
  }
  if has_bu_auto {
    return true
  }

  let has_bu_blip = match find_bytes(xml, bu_blip, start) {
    Some(i) => i < end_
    None => false
  }
  if has_bu_blip {
    return true
  }

  false
}

///|
fn parse_presentation_slide_rids(xml : String) -> Array[String] raise {
  let bs = @utf8.encode(xml)
  let out : Array[String] = []

  let open_pat = pat("<p:sldId")
  let gt_pat = pat(">")

  let mut pos = 0
  while true {
    let s0 = find_bytes(bs, open_pat, pos)
    match s0 {
      None => break
      Some(i0) => {
        let gt = find_bytes(bs, gt_pat, i0)
        match gt {
          None => break
          Some(gt0) => {
            let tag = bs[i0:gt0 + 1]
            match read_attr_value_in_tag_bytes(tag.to_bytes(), "r:id") {
              Some(rid) => out.push(rid)
              None => ()
            }
            pos = gt0 + 1
          }
        }
      }
    }
  }

  out
}

///|
fn parse_presentation_rels(xml : String) -> Map[String, String] raise {
  let bs = @utf8.encode(xml)
  let out : Map[String, String] = {}

  let rel_pat = pat("<Relationship")
  let gt_pat = pat(">")

  let mut pos = 0
  while true {
    let r0 = find_bytes(bs, rel_pat, pos)
    match r0 {
      None => break
      Some(i0) => {
        let gt = find_bytes(bs, gt_pat, i0)
        match gt {
          None => break
          Some(gt0) => {
            let tag = bs[i0:gt0 + 1]

            let id = match read_attr_value_in_tag_bytes(tag.to_bytes(), "Id") {
              Some(v) => v
              None => {
                pos = gt0 + 1
                continue
              }
            }

            let target = match
              read_attr_value_in_tag_bytes(tag.to_bytes(), "Target") {
              Some(v) => v
              None => {
                pos = gt0 + 1
                continue
              }
            }

            out[id] = target
            pos = gt0 + 1
          }
        }
      }
    }
  }

  out
}
