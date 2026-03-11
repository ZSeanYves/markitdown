///|
priv struct SlideShape {
  xml : Bytes
  x : Int
  y : Int
  _cx : Int
  _cy : Int
  is_title : Bool
  is_body : Bool
}

///|
priv struct SlideParagraph {
  text : String
  bullet_kind : BulletKind?
  level : Int
  from_title_shape : Bool
  from_body_shape : Bool
}

///|
priv enum BulletKind {
  Unordered
  Ordered
}

///|
/// scan slide xml by shape (<p:sp>), collect shapes first,
/// sort by lightweight reading order, then extract each <a:p>
fn extract_slide_paragraphs(xml : Bytes) -> Array[SlideParagraph] raise {
  let out : Array[SlideParagraph] = []
  let shapes = collect_slide_shapes(xml)
  let sorted = sort_slide_shapes(shapes)

  for sp in sorted {
    let paras = extract_shape_paragraphs(sp.xml, sp.is_title, sp.is_body)
    for para in paras {
      out.push(para)
    }
  }

  out
}

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
                let (x, y, cx, cy) = read_shape_bounds(sp_xml)

                out.push({
                  xml: sp_xml,
                  x,
                  y,
                  _cx: cx,
                  _cy: cy,
                  is_title,
                  is_body,
                })

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
/// returns (x, y, cx, cy), defaults to 0 when absent
fn read_shape_bounds(xml : Bytes) -> (Int, Int, Int, Int) raise {
  let xfrm_pat = pat("<a:xfrm")
  let off_pat = pat("<a:off")
  let ext_pat = pat("<a:ext")
  let gt_pat = pat(">")

  let mut x = 0
  let mut y = 0
  let mut cx = 0
  let mut cy = 0

  let xfrm0 = find_bytes(xml, xfrm_pat, 0)
  match xfrm0 {
    None => (x, y, cx, cy)
    Some(xfrm_i0) => {
      let xfrm_gt = find_bytes(xml, gt_pat, xfrm_i0)
      match xfrm_gt {
        None => (x, y, cx, cy)
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
                    Some(v) => cx = parse_nonneg_int(v)
                    None => ()
                  }
                  match read_attr_value_in_tag_bytes(tag, "cy") {
                    Some(v) => cy = parse_nonneg_int(v)
                    None => ()
                  }
                }
                None => ()
              }
            }
            None => ()
          }

          (x, y, cx, cy)
        }
      }
    }
  }
}

///|
/// sort shapes by lightweight reading order:
/// - title-like shapes first
/// - then top-to-bottom
/// - if roughly same row, left-to-right
fn sort_slide_shapes(shapes : Array[SlideShape]) -> Array[SlideShape] {
  let out : Array[SlideShape] = []

  for sp in shapes {
    let mut inserted = false
    let mut i = 0

    while i < out.length() {
      if shape_before(sp, out[i]) {
        out.insert(i, sp)
        inserted = true
        break
      }
      i = i + 1
    }

    if !inserted {
      out.push(sp)
    }
  }

  out
}

///|
fn shape_before(a : SlideShape, b : SlideShape) -> Bool {
  if a.is_title != b.is_title {
    return a.is_title
  }

  let row_threshold = 200000

  let dy = abs_int(a.y - b.y)
  if dy <= row_threshold {
    if a.x != b.x {
      return a.x < b.x
    }
    if a.y != b.y {
      return a.y < b.y
    }
    return false
  }

  if a.y != b.y {
    return a.y < b.y
  }

  if a.x != b.x {
    return a.x < b.x
  }

  false
}

///|
fn abs_int(n : Int) -> Int {
  if n < 0 {
    -n
  } else {
    n
  }
}

///|
/// read paragraph level from <a:pPr ... lvl="N">
/// default to 0 if absent / invalid
fn paragraph_level(xml : Bytes, start : Int, end_ : Int) -> Int raise {
  let ppr_pat = pat("<a:pPr")
  let gt_pat = pat(">")

  let ppr0 = find_bytes(xml, ppr_pat, start)
  match ppr0 {
    None => 0
    Some(i0) => {
      if i0 >= end_ {
        return 0
      }

      let gt = find_bytes(xml, gt_pat, i0)
      match gt {
        None => 0
        Some(gt0) => {
          if gt0 >= end_ {
            return 0
          }

          let tag = xml[i0:gt0 + 1].to_bytes()
          match read_attr_value_in_tag_bytes(tag, "lvl") {
            Some(v) => parse_nonneg_int(v)
            None => 0
          }
        }
      }
    }
  }
}

///|
fn paragraph_bullet_kind(xml : Bytes, start : Int, end_ : Int) -> BulletKind? {
  let bu_char = pat("<a:buChar")
  let bu_auto = pat("<a:buAutoNum")
  let bu_blip = pat("<a:buBlip")
  let bu_none = pat("<a:buNone")

  let has_bu_none = match find_bytes(xml, bu_none, start) {
    Some(i) => i < end_
    None => false
  }
  if has_bu_none {
    return None
  }

  let has_bu_auto = match find_bytes(xml, bu_auto, start) {
    Some(i) => i < end_
    None => false
  }
  if has_bu_auto {
    return Some(BulletKind::Ordered)
  }

  let has_bu_char = match find_bytes(xml, bu_char, start) {
    Some(i) => i < end_
    None => false
  }
  if has_bu_char {
    return Some(BulletKind::Unordered)
  }

  let has_bu_blip = match find_bytes(xml, bu_blip, start) {
    Some(i) => i < end_
    None => false
  }
  if has_bu_blip {
    return Some(BulletKind::Unordered)
  }

  None
}

///|
fn parse_nonneg_int(s : String) -> Int {
  let t = s.trim().to_string()
  if t == "" {
    return 0
  }

  let mut n = 0
  let mut ok = false
  for c in t.to_array() {
    if c >= '0' && c <= '9' {
      n = n * 10 + (c.to_int() - '0'.to_int())
      ok = true
    } else {
      return 0
    }
  }

  if ok {
    n
  } else {
    0
  }
}
