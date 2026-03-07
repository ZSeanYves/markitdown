///|
pub(all) enum PptxBlock {
  Heading(String)
  Paragraph(String)
  ListItem(String)
}

///|
pub(all) struct SlideParagraph {
  text : String
  is_bullet : Bool
}

///|
/// scan slide xml, extract each <a:p> as one paragraph with simple bullet info
fn extract_slide_paragraphs(xml : Bytes) -> Array[SlideParagraph] raise {
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
                  out.push({ text, is_bullet })
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

    if para.is_bullet || is_bullet_like(p) {
      out.push(PptxBlock::ListItem(strip_bullet_prefix(p)))
      continue
    }

    if !seen_heading && looks_like_slide_title(p) {
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
