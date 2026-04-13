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
                let inlines = extract_text_inlines(
                  xml,
                  inner_start,
                  p_end0,
                  hyperlinks,
                )
                let text = render_plain_text_inlines(inlines).trim().to_string()

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
