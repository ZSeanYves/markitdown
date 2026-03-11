///|
priv enum PptxBlock {
  Heading(String)
  Paragraph(String)
  ListItem(Bool, Int, String) // ordered, level, text
}

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
/// scan one <p:sp> shape xml, extract each <a:p> as one paragraph
/// - for title-like shapes, merge consecutive non-empty paragraphs into one
fn extract_shape_paragraphs(
  xml : Bytes,
  from_title_shape : Bool,
  from_body_shape : Bool,
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
                let text = extract_text_runs(xml, inner_start, p_end0)
                  .trim()
                  .to_string()

                let bullet_kind = paragraph_bullet_kind(
                  xml, inner_start, p_end0,
                )
                let level = paragraph_level(xml, inner_start, p_end0)

                if text != "" {
                  paras.push({
                    text,
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

  [
    {
      text: merged_parts.join(" "),
      bullet_kind: None,
      level: 0,
      from_title_shape: true,
      from_body_shape,
    },
  ]
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
fn classify_slide_paragraphs(
  paras : Array[SlideParagraph],
) -> Array[PptxBlock] raise {
  let out : Array[PptxBlock] = []
  let mut seen_heading = false

  let compacted = compact_slide_paragraphs(paras)

  for i in 0..<compacted.length() {
  let para = compacted[i]
    let p = para.text.trim().to_string()
    if p == "" {
      continue
    }

    if para.from_title_shape && !seen_heading {
      out.push(PptxBlock::Heading(p))
      seen_heading = true
      continue
    }

    match para.bullet_kind {
      Some(kind) => {
        let level = if para.level >= 0 { para.level } else { 0 }
        let ordered = match kind {
          BulletKind::Unordered => false
          BulletKind::Ordered => true
        }
        out.push(PptxBlock::ListItem(ordered, level, strip_bullet_prefix(p)))
        continue
      }
      None => ()
    }

    if is_bullet_like(p) {
      let level = if para.level >= 0 { para.level } else { 0 }
      let ordered = starts_with_numbered_bullet(p)
      out.push(PptxBlock::ListItem(ordered, level, strip_bullet_prefix(p)))
      continue
    }

if !seen_heading &&
  !para.from_body_shape &&
  para.level == 0 &&
  looks_like_slide_title(p) {
  match para.bullet_kind {
    Some(_) => ()
    None => {
      let next_is_body = if i + 1 < compacted.length() {
        compacted[i + 1].from_body_shape
      } else {
        false
      }

      if compacted.length() == 1 || (i == 0 && next_is_body) {
        out.push(PptxBlock::Heading(p))
        seen_heading = true
        continue
      }
    }
  }
}

    out.push(PptxBlock::Paragraph(p))
  }

  out
}

///|
/// drop empty / shell-only paras, and dedupe adjacent duplicates
fn compact_slide_paragraphs(
  paras : Array[SlideParagraph],
) -> Array[SlideParagraph] raise {
  let out : Array[SlideParagraph] = []

  for para in paras {
    let text = normalize_slide_text(para.text)
    if text == "" {
      continue
    }

    if is_empty_bullet_shell(text) {
      continue
    }
    let cur : SlideParagraph = {
      text,
      bullet_kind: para.bullet_kind,
      level: para.level,
      from_title_shape: para.from_title_shape,
      from_body_shape: para.from_body_shape,
    }

    if out.length() == 0 {
      out.push(cur)
      continue
    }

    let last = out[out.length() - 1]
    if same_slide_para_text(last.text, cur.text) {
      if prefer_slide_para(cur, last) {
        out[out.length() - 1] = cur
      }
      continue
    }

    out.push(cur)
  }

  out
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

///|
fn is_empty_bullet_shell(s : String) -> Bool raise {
  let t = strip_bullet_prefix(normalize_slide_text(s))
  if t == "" {
    return true
  }

  let cs = t.to_array()
  if cs.length() == 0 {
    return true
  }

  let mut all_shell = true
  for c in cs {
    let is_space = c == ' '
    let is_sym = c == '-' ||
      c == '*' ||
      c == '•' ||
      c == '·' ||
      c == '.' ||
      c == ')' ||
      c == '）' ||
      c == '、'
    let is_digit = c >= '0' && c <= '9'

    if !(is_space || is_sym || is_digit) {
      all_shell = false
      break
    }
  }

  all_shell
}

///|
fn same_slide_para_text(a : String, b : String) -> Bool {
  normalize_slide_text(a) == normalize_slide_text(b)
}

///|
/// choose the more informative paragraph when duplicated
fn prefer_slide_para(a : SlideParagraph, b : SlideParagraph) -> Bool {
  let sa = slide_para_score(a)
  let sb = slide_para_score(b)
  sa > sb
}

///|
fn slide_para_score(p : SlideParagraph) -> Int {
  let mut sc = 0
  if p.from_title_shape {
    sc += 4
  }
  if p.from_body_shape {
    sc += 2
  }
  match p.bullet_kind {
    Some(_) => sc += 1
    None => ()
  }
  if p.level > 0 {
    sc += 1
  }
  sc
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
