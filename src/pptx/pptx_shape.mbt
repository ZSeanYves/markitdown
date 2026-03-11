///|
priv struct SlideShape {
  xml : Bytes
  x : Int
  y : Int
  w : Int
  h : Int
  is_title : Bool
  is_body : Bool
}

///|
priv struct LayoutShape {
  shape : SlideShape
  right : Int
  bottom : Int
  center_x : Int
  center_y : Int
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
/// recover a more stable reading order by:
/// - separating title shapes
/// - clustering body shapes into visual rows
/// - detecting simple two-column layout
/// then extract each shape's <a:p> in that order
fn extract_slide_paragraphs(xml : Bytes) -> Array[SlideParagraph] raise {
  let out : Array[SlideParagraph] = []

  let shapes = collect_slide_shapes(xml)
  let enriched = enrich_layout_shapes(shapes)
  let (title_shapes, body_shapes) = split_title_shapes(enriched)
  let filtered_bodies = filter_noise_shapes(body_shapes)
  let ordered = flatten_shapes_in_reading_order(title_shapes, filtered_bodies)

  for sp in ordered {
    let raw = sp.shape
    let paras = extract_shape_paragraphs(raw.xml, raw.is_title, raw.is_body)
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
/// split title shapes from other shapes;
/// titles are sorted with a simple top-to-bottom, left-to-right order
/// if no real title placeholder exists, conservatively promote one
/// top title-like shape from bodies.
fn split_title_shapes(
  shapes : Array[LayoutShape],
) -> (Array[LayoutShape], Array[LayoutShape]) {
  let titles : Array[LayoutShape] = []
  let bodies : Array[LayoutShape] = []

  for sp in shapes {
    if sp.shape.is_title {
      titles.push(sp)
    } else {
      bodies.push(sp)
    }
  }

  if titles.length() > 0 {
    return (sort_layout_shapes_simple(titles), bodies)
  }

  let promoted = find_promotable_title_candidate(bodies)
  match promoted {
    None => (titles, bodies)
    Some(idx) => {
      let out_titles : Array[LayoutShape] = []
      let out_bodies : Array[LayoutShape] = []

      for i in 0..<bodies.length() {
        if i == idx {
          let sp = bodies[i]
          let promoted_shape : SlideShape = {
            xml: sp.shape.xml,
            x: sp.shape.x,
            y: sp.shape.y,
            w: sp.shape.w,
            h: sp.shape.h,
            is_title: true,
            is_body: sp.shape.is_body,
          }
          let promoted_layout : LayoutShape = {
            shape: promoted_shape,
            right: sp.right,
            bottom: sp.bottom,
            center_x: sp.center_x,
            center_y: sp.center_y,
          }
          out_titles.push(promoted_layout)
        } else {
          out_bodies.push(bodies[i])
        }
      }

      (sort_layout_shapes_simple(out_titles), out_bodies)
    }
  }
}

///|
/// pick at most one conservative title candidate from body shapes
fn find_promotable_title_candidate(shapes : Array[LayoutShape]) -> Int? {
  if shapes.length() == 0 {
    return None
  }

  let (_, slide_h) = estimate_layout_bounds(shapes)

  let mut best_idx = -1
  let mut best_score = -1
  for i in 0..<shapes.length() {
    let sp = shapes[i]
    if is_promotable_title_candidate(sp, slide_h) {
      let sc = promotable_title_score(sp, slide_h)
      if sc > best_score {
        best_score = sc
        best_idx = i
      }
    }
  }

  if best_idx >= 0 {
    Some(best_idx)
  } else {
    None
  }
}

///|
fn is_promotable_title_candidate(sp : LayoutShape, slide_h : Int) -> Bool {
  let text = normalize_shape_text_for_title(sp.shape.xml)
  if text == "" {
    return false
  }

  // already handled by real title placeholders
  if sp.shape.is_title {
    return false
  }

  // body placeholder usually should stay as body
  if sp.shape.is_body {
    return false
  }

  // should appear near top area
  if slide_h > 0 && sp.shape.y > slide_h / 4 {
    return false
  }

  let n = text.to_array().length()
  if n > 40 {
    return false
  }

  if is_bullet_like(text) {
    return false
  }

  if ends_like_sentence(text) {
    return false
  }

  if is_probable_slide_number(text) {
    return false
  }

  // avoid very tiny corner labels or page marks
  if sp.shape.w <= 0 || sp.shape.h <= 0 {
    return false
  }

  // too small is suspicious
  if sp.shape.h < 100000 {
    return false
  }

  true
}

///|
/// higher score = more likely to be a fallback title
fn promotable_title_score(sp : LayoutShape, slide_h : Int) -> Int {
  let text = normalize_shape_text_for_title(sp.shape.xml)
  let n = text.to_array().length()

  let mut sc = 0

  // upper position preferred
  if slide_h > 0 {
    let top_bonus = slide_h - sp.shape.y
    if top_bonus > 0 {
      sc += top_bonus / 100000
    }
  }

  // shorter text preferred
  sc += 50 - n

  // larger width mildly preferred
  sc += sp.shape.w / 100000

  // smaller y strongly preferred
  sc += 1000000 / (sp.shape.y + 1)

  sc
}

///|
fn normalize_shape_text_for_title(xml : Bytes) -> String {
  normalize_slide_text(extract_text_runs(xml, 0, xml.length()))
}

///|
fn estimate_layout_bounds(shapes : Array[LayoutShape]) -> (Int, Int) {
  if shapes.length() == 0 {
    return (0, 0)
  }

  let mut max_right = 0
  let mut max_bottom = 0

  for sp in shapes {
    if sp.right > max_right {
      max_right = sp.right
    }
    if sp.bottom > max_bottom {
      max_bottom = sp.bottom
    }
  }

  (max_right, max_bottom)
}

///|
/// simple geometric sort:
/// - top-to-bottom
/// - if roughly same row, left-to-right
fn sort_layout_shapes_simple(shapes : Array[LayoutShape]) -> Array[LayoutShape] {
  let out : Array[LayoutShape] = []

  for sp in shapes {
    let mut inserted = false
    let mut i = 0

    while i < out.length() {
      if layout_shape_before_simple(sp, out[i]) {
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
fn layout_shape_before_simple(a : LayoutShape, b : LayoutShape) -> Bool {
  let row_threshold = row_threshold_for(a, b)

  let dy = abs_int(a.center_y - b.center_y)
  if dy <= row_threshold {
    if a.shape.x != b.shape.x {
      return a.shape.x < b.shape.x
    }
    if a.shape.y != b.shape.y {
      return a.shape.y < b.shape.y
    }
    return false
  }

  if a.shape.y != b.shape.y {
    return a.shape.y < b.shape.y
  }

  if a.shape.x != b.shape.x {
    return a.shape.x < b.shape.x
  }

  false
}

///|
fn row_threshold_for(a : LayoutShape, b : LayoutShape) -> Int {
  let ah = if a.shape.h > 0 { a.shape.h } else { 1 }
  let bh = if b.shape.h > 0 { b.shape.h } else { 1 }
  let hmin = if ah < bh { ah } else { bh }
  let t = hmin / 2
  if t < 1 {
    1
  } else {
    t
  }
}

///|
fn same_visual_row(a : LayoutShape, b : LayoutShape) -> Bool {
  let dy = abs_int(a.center_y - b.center_y)
  dy <= row_threshold_for(a, b)
}

///|
/// cluster shapes into visual rows; rows are ordered top-to-bottom,
/// and shapes inside each row are ordered left-to-right
fn cluster_shapes_into_rows(
  shapes : Array[LayoutShape],
) -> Array[Array[LayoutShape]] {
  let rows : Array[Array[LayoutShape]] = []
  let sorted = sort_layout_shapes_simple(shapes)

  for sp in sorted {
    let mut placed = false
    let mut i = 0

    while i < rows.length() {
      if row_accepts_shape(rows[i], sp) {
        rows[i].push(sp)
        placed = true
        break
      }
      i = i + 1
    }

    if !placed {
      rows.push([sp])
    }
  }

  for i in 0..<rows.length() {
    let row = rows[i]
    rows[i] = sort_layout_shapes_by_x(row)
  }

  sort_rows_by_top(rows)
}

///|
fn row_accepts_shape(row : Array[LayoutShape], sp : LayoutShape) -> Bool {
  if row.length() == 0 {
    return true
  }

  for item in row {
    if same_visual_row(item, sp) {
      return true
    }
  }

  false
}

///|
fn sort_layout_shapes_by_x(shapes : Array[LayoutShape]) -> Array[LayoutShape] {
  let out : Array[LayoutShape] = []

  for sp in shapes {
    let mut inserted = false
    let mut i = 0

    while i < out.length() {
      if layout_shape_before_x(sp, out[i]) {
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
fn layout_shape_before_x(a : LayoutShape, b : LayoutShape) -> Bool {
  if a.shape.x != b.shape.x {
    return a.shape.x < b.shape.x
  }
  if a.shape.y != b.shape.y {
    return a.shape.y < b.shape.y
  }
  false
}

///|
fn sort_rows_by_top(
  rows : Array[Array[LayoutShape]],
) -> Array[Array[LayoutShape]] {
  let out : Array[Array[LayoutShape]] = []

  for row in rows {
    let mut inserted = false
    let mut i = 0

    while i < out.length() {
      if row_before(row, out[i]) {
        out.insert(i, row)
        inserted = true
        break
      }
      i = i + 1
    }

    if !inserted {
      out.push(row)
    }
  }

  out
}

///|
fn row_before(a : Array[LayoutShape], b : Array[LayoutShape]) -> Bool {
  let ay = row_top(a)
  let by = row_top(b)
  if ay != by {
    return ay < by
  }

  let ax = row_left(a)
  let bx = row_left(b)
  ax < bx
}

///|
fn row_top(row : Array[LayoutShape]) -> Int {
  if row.length() == 0 {
    return 0
  }

  let mut v = row[0].shape.y
  for i in 1..<row.length() {
    if row[i].shape.y < v {
      v = row[i].shape.y
    }
  }
  v
}

///|
fn row_left(row : Array[LayoutShape]) -> Int {
  if row.length() == 0 {
    return 0
  }

  let mut v = row[0].shape.x
  for i in 1..<row.length() {
    if row[i].shape.x < v {
      v = row[i].shape.x
    }
  }
  v
}

///|
/// flatten title shapes and body shapes into final reading order:
/// - titles first
/// - body in two columns if detected
/// - otherwise body by visual rows
fn flatten_shapes_in_reading_order(
  title_shapes : Array[LayoutShape],
  body_shapes : Array[LayoutShape],
) -> Array[LayoutShape] {
  let out : Array[LayoutShape] = []

  for sp in title_shapes {
    out.push(sp)
  }

  if body_shapes.length() == 0 {
    return out
  }

  if is_two_columns(body_shapes) {
    let (left, right) = split_two_columns(body_shapes)

    let left_rows = cluster_shapes_into_rows(left)
    let right_rows = cluster_shapes_into_rows(right)

    append_rows(out, left_rows)
    append_rows(out, right_rows)
    return out
  }

  let rows = cluster_shapes_into_rows(body_shapes)
  append_rows(out, rows)
  out
}

///|
fn append_rows(
  out : Array[LayoutShape],
  rows : Array[Array[LayoutShape]],
) -> Unit {
  for row in rows {
    for sp in row {
      out.push(sp)
    }
  }
}

///|
fn find_body_mid_x(shapes : Array[LayoutShape]) -> Int {
  if shapes.length() == 0 {
    return 0
  }

  let mut minx = shapes[0].shape.x
  let mut maxr = shapes[0].right

  for i in 1..<shapes.length() {
    let sp = shapes[i]
    if sp.shape.x < minx {
      minx = sp.shape.x
    }
    if sp.right > maxr {
      maxr = sp.right
    }
  }

  (minx + maxr) / 2
}

///|
fn split_two_columns(
  shapes : Array[LayoutShape],
) -> (Array[LayoutShape], Array[LayoutShape]) {
  let midx = find_body_mid_x(shapes)
  let left : Array[LayoutShape] = []
  let right : Array[LayoutShape] = []

  for sp in shapes {
    if sp.center_x < midx {
      left.push(sp)
    } else {
      right.push(sp)
    }
  }

  (sort_layout_shapes_simple(left), sort_layout_shapes_simple(right))
}

///|
/// conservative two-column detection:
/// - need enough shapes
/// - both sides need at least 2 shapes
/// - left region should be clearly before right region
fn is_two_columns(shapes : Array[LayoutShape]) -> Bool {
  if shapes.length() < 4 {
    return false
  }

  let (left, right) = split_two_columns(shapes)
  if left.length() < 2 || right.length() < 2 {
    return false
  }

  let left_max_r = max_right(left)
  let right_min_l = min_x(right)

  left_max_r < right_min_l
}

///|
fn max_right(shapes : Array[LayoutShape]) -> Int {
  if shapes.length() == 0 {
    return 0
  }

  let mut v = shapes[0].right
  for i in 1..<shapes.length() {
    if shapes[i].right > v {
      v = shapes[i].right
    }
  }
  v
}

///|
fn min_x(shapes : Array[LayoutShape]) -> Int {
  if shapes.length() == 0 {
    return 0
  }

  let mut v = shapes[0].shape.x
  for i in 1..<shapes.length() {
    if shapes[i].shape.x < v {
      v = shapes[i].shape.x
    }
  }
  v
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
fn abs_int(n : Int) -> Int {
  if n < 0 {
    -n
  } else {
    n
  }
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
