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

  let (slide_w, slide_h) = estimate_layout_bounds(shapes)

  let mut best_idx = -1
  let mut best_score = -1
  for i in 0..<shapes.length() {
    let sp = shapes[i]
    if is_promotable_title_candidate(sp, slide_h, slide_w) {
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
fn is_promotable_title_candidate(
  sp : LayoutShape,
  slide_h : Int,
  slide_w : Int,
) -> Bool {
  let text = normalize_shape_text_for_title(sp.shape.xml)
  if text == "" {
    return false
  }

  if sp.shape.is_title {
    return false
  }

  // must appear near top area
  if slide_h > 0 && sp.shape.y > slide_h / 5 {
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

  if sp.shape.w <= 0 || sp.shape.h <= 0 {
    return false
  }

  // too small is suspicious
  if sp.shape.h < 100000 {
    return false
  }

  // width should not be too narrow
  if slide_w > 0 && sp.shape.w < slide_w / 4 {
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

  if slide_h > 0 {
    let top_bonus = slide_h - sp.shape.y
    if top_bonus > 0 {
      sc += top_bonus / 100000
    }
  }

  sc += 50 - n
  sc += sp.shape.w / 100000
  sc += 1000000 / (sp.shape.y + 1)

  sc
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
