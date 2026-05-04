///|
fn extract_speaker_notes(
  p : PptxPackage,
  rel_ctx : PptxSlideRelContext,
) -> Array[SlideParagraph] raise {
  let notes_part = match rel_ctx.notes_part {
    Some(part) => part
    None => return []
  }
  let xml = p.read_text_optional(notes_part)
  if xml.trim() == "" {
    return []
  }

  let bs = @utf8.encode(xml)
  let shapes = collect_notes_shapes(bs)
  if shapes.length() == 0 {
    return []
  }

  let para_seq : Ref[Int] = { val: 0 }
  let out : Array[SlideParagraph] = []
  for shape in sort_layout_shapes_simple(enrich_layout_shapes(shapes)) {
    let paras = extract_shape_paragraphs(
      shape.shape.xml,
      false,
      true,
      Map::new(),
      para_seq,
    )
    for para in paras {
      if !is_notes_placeholder_noise(para.text) {
        out.push(para)
      }
    }
  }
  out
}

///|
fn collect_notes_shapes(xml : Bytes) -> Array[SlideShape] raise {
  let out : Array[SlideShape] = []
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
                let sp_xml = xml[i0:sp_end0 + close_sp.length()].to_owned()
                if !is_notes_shape_placeholder_noise(sp_xml) {
                  let (x, y, w, h) = read_shape_bounds(sp_xml)
                  out.push({
                    xml: sp_xml,
                    x,
                    y,
                    w,
                    h,
                    is_title: false,
                    is_body: true,
                    object_ref: None,
                  })
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
fn is_notes_shape_placeholder_noise(sp_xml : Bytes) -> Bool {
  contains_bytes(sp_xml, pat("type=\"sldImg\"")) ||
  contains_bytes(sp_xml, pat("type=\"sldNum\"")) ||
  contains_bytes(sp_xml, pat("type=\"dt\"")) ||
  contains_bytes(sp_xml, pat("type=\"ftr\"")) ||
  contains_bytes(sp_xml, pat("type=\"hdr\""))
}

///|
fn is_notes_placeholder_noise(text : String) -> Bool {
  let t = normalize_slide_text(text)
  if t == "" {
    return true
  }
  if is_all_digits(t) {
    return true
  }
  let lower = ascii_lower(t)
  lower == "header" || lower == "footer" || lower == "date"
}
