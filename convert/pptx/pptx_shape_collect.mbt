///|
/// collect all <p:sp> shapes with lightweight geometry metadata
fn collect_slide_shapes(xml : Bytes) -> Array[SlideShape] raise {
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
                let sp_xml = xml[i0:sp_end0 + close_sp.length()].to_bytes()
                let is_title = shape_is_title_like(sp_xml)
                let is_body = shape_is_body_like(sp_xml)
                let (x, y, w, h) = read_shape_bounds(sp_xml)

                out.push({ xml: sp_xml, x, y, w, h, is_title, is_body })

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
/// read shape bounds from <a:xfrm>
/// returns (x, y, w, h), defaults to 0 when absent
fn read_shape_bounds(xml : Bytes) -> (Int, Int, Int, Int) raise {
  let xfrm_pat = pat("<a:xfrm")
  let off_pat = pat("<a:off")
  let ext_pat = pat("<a:ext")
  let gt_pat = pat(">")

  let mut x = 0
  let mut y = 0
  let mut w = 0
  let mut h = 0

  let xfrm0 = find_bytes(xml, xfrm_pat, 0)
  match xfrm0 {
    None => (x, y, w, h)
    Some(xfrm_i0) => {
      let xfrm_gt = find_bytes(xml, gt_pat, xfrm_i0)
      match xfrm_gt {
        None => (x, y, w, h)
        Some(_xfrm_gt0) => {
          match find_bytes(xml, off_pat, xfrm_i0) {
            Some(off_i0) => {
              let off_gt = find_bytes(xml, gt_pat, off_i0)
              match off_gt {
                Some(off_gt0) => {
                  let tag = xml[off_i0:off_gt0 + 1].to_bytes()
                  match read_attr_value_in_tag_bytes(tag, "x") {
                    Some(v) => x = parse_nonneg_int(v)
                    None => ()
                  }
                  match read_attr_value_in_tag_bytes(tag, "y") {
                    Some(v) => y = parse_nonneg_int(v)
                    None => ()
                  }
                }
                None => ()
              }
            }
            None => ()
          }

          match find_bytes(xml, ext_pat, xfrm_i0) {
            Some(ext_i0) => {
              let ext_gt = find_bytes(xml, gt_pat, ext_i0)
              match ext_gt {
                Some(ext_gt0) => {
                  let tag = xml[ext_i0:ext_gt0 + 1].to_bytes()
                  match read_attr_value_in_tag_bytes(tag, "cx") {
                    Some(v) => w = parse_nonneg_int(v)
                    None => ()
                  }
                  match read_attr_value_in_tag_bytes(tag, "cy") {
                    Some(v) => h = parse_nonneg_int(v)
                    None => ()
                  }
                }
                None => ()
              }
            }
            None => ()
          }

          (x, y, w, h)
        }
      }
    }
  }
}

///|
fn enrich_layout_shapes(shapes : Array[SlideShape]) -> Array[LayoutShape] {
  let out : Array[LayoutShape] = []

  for sp in shapes {
    out.push({
      shape: sp,
      right: sp.x + sp.w,
      bottom: sp.y + sp.h,
      center_x: sp.x + sp.w / 2,
      center_y: sp.y + sp.h / 2,
    })
  }

  out
}

///|
fn normalize_shape_text_for_title(xml : Bytes) -> String {
  normalize_slide_text(extract_text_runs(xml, 0, xml.length()))
}
