///|
fn shape_group_bounds(shapes : Array[LayoutShape]) -> (Int, Int, Int, Int) {
  if shapes.length() == 0 {
    return (0, 0, 0, 0)
  }

  let mut top = shapes[0].shape.y
  let mut left = shapes[0].shape.x
  let mut right = shapes[0].right
  let mut bottom = shapes[0].bottom

  for i in 1..<shapes.length() {
    let sp = shapes[i]
    if sp.shape.y < top {
      top = sp.shape.y
    }
    if sp.shape.x < left {
      left = sp.shape.x
    }
    if sp.right > right {
      right = sp.right
    }
    if sp.bottom > bottom {
      bottom = sp.bottom
    }
  }

  (top, left, right, bottom)
}

///|
fn group_caption_like_flag(
  shapes : Array[LayoutShape],
  slide_w : Int,
  slide_h : Int,
) -> Bool {
  if shapes.length() == 0 {
    return false
  }

  let mut cnt = 0
  for sp in shapes {
    if is_caption_like_shape(sp, slide_w, slide_h) {
      cnt += 1
    }
  }

  cnt * 2 >= shapes.length()
}

///|
fn make_shape_group_with_kind(
  shapes : Array[LayoutShape],
  kind : ShapeGroupKind,
) -> ShapeGroup {
  let sorted = sort_layout_shapes_simple(shapes)
  let (top, left, _right, _bottom) = shape_group_bounds(sorted)
  { shapes: sorted, top, left, kind }
}

///|
fn should_group_nearby_shapes(
  a : LayoutShape,
  b : LayoutShape,
  slide_w : Int,
  slide_h : Int,
) -> Bool {
  let a_ok = is_caption_like_shape(a, slide_w, slide_h)
  let b_ok = is_caption_like_shape(b, slide_w, slide_h)

  if !(a_ok && b_ok) {
    return false
  }

  let hgap = horizontal_gap(a, b)
  let vgap = vertical_gap(a, b)
  let hoverlap = horizontal_overlap(a, b)
  let voverlap = vertical_overlap(a, b)

  if looks_like_callout_pair(a, b) {
    return true
  }

  if hoverlap > 0 && vgap <= max_int(a.shape.h, b.shape.h) {
    return true
  }

  if voverlap > 0 && hgap <= max_int(a.shape.w, b.shape.w) {
    return true
  }

  false
}

///|
fn callout_text_contains_digit(s : String) -> Bool {
  for ch in s.to_array() {
    if ch >= '0' && ch <= '9' {
      return true
    }
  }
  false
}

///|
fn callout_text_contains_space(s : String) -> Bool {
  for ch in s.to_array() {
    if ch == ' ' {
      return true
    }
  }
  false
}

///|
fn looks_like_desc_prefix_text(s : String) -> Bool {
  s.contains("Desc") || s.contains("desc")
}

///|
fn looks_like_callout_title_text(s : String) -> Bool {
  let t = s.trim()
  let n = t.to_array().length()

  if t == "" || n > 24 {
    return false
  }

  if callout_text_contains_digit(t.to_string()) {
    // allow compact digit-suffixed labels like "Title1" / "C1",
    // but keep desc-like short labels out of title slot.
    if callout_text_contains_space(t.to_string()) ||
      looks_like_desc_prefix_text(t.to_string()) {
      return false
    }
  }

  if t.contains(".") || t.contains("!") || t.contains("?") {
    return false
  }

  true
}

///|
fn looks_like_callout_desc_text(s : String) -> Bool {
  let t = s.trim()
  let n = t.to_array().length()

  if t == "" {
    return false
  }

  if callout_text_contains_digit(t.to_string()) {
    // allow compact desc labels like "Desc1" / "Desc C1".
    return callout_text_contains_space(t.to_string()) ||
    looks_like_desc_prefix_text(t.to_string())
  }

  if callout_text_contains_space(t.to_string()) {
    return true
  }

  n >= 16
}

///|
fn looks_like_callout_pair(a : LayoutShape, b : LayoutShape) -> Bool {
  let at = normalize_shape_text_for_title(a.shape.xml)
  let bt = normalize_shape_text_for_title(b.shape.xml)

  let a_title = looks_like_callout_title_text(at)
  let b_title = looks_like_callout_title_text(bt)
  let a_desc = looks_like_callout_desc_text(at)
  let b_desc = looks_like_callout_desc_text(bt)

  if !((a_title && b_desc) || (b_title && a_desc)) {
    return false
  }

  let hoverlap = horizontal_overlap(a, b)
  if hoverlap <= 0 {
    return false
  }

  let vgap = vertical_gap(a, b)
  let maxh = max_int(a.shape.h, b.shape.h)

  if vgap > max_int(maxh, 180000) {
    return false
  }

  true
}

///|
fn group_has_callout_core(shapes : Array[LayoutShape]) -> Bool {
  if shapes.length() < 2 {
    return false
  }

  for i in 0..<shapes.length() {
    for j in (i + 1)..<shapes.length() {
      if looks_like_callout_pair(shapes[i], shapes[j]) {
        return true
      }
    }
  }

  false
}

///|
fn is_strong_vertical_neighbor(a : LayoutShape, b : LayoutShape) -> Bool {
  let hoverlap = horizontal_overlap(a, b)
  let vgap = vertical_gap(a, b)
  let maxh = max_int(a.shape.h, b.shape.h)

  hoverlap > 0 && vgap <= max_int(maxh, 180000)
}

///|
fn group_accepts_shape(
  g : ShapeGroup,
  sp : LayoutShape,
  slide_w : Int,
  slide_h : Int,
) -> Bool {
  if g.kind == ShapeGroupKind::CaptionLike && g.shapes.length() >= 2 &&
    group_has_callout_core(g.shapes) {
    for item in g.shapes {
      if looks_like_callout_pair(item, sp) {
        return true
      }
    }

    let mut linked = 0
    for item in g.shapes {
      if is_strong_vertical_neighbor(item, sp) {
        linked += 1
      }
    }

    return linked >= 2
  }

  for item in g.shapes {
    if should_group_nearby_shapes(item, sp, slide_w, slide_h) {
      return true
    }
  }
  false
}

///|
fn shape_group_before(a : ShapeGroup, b : ShapeGroup) -> Bool {
  if a.top != b.top {
    return a.top < b.top
  }
  a.left < b.left
}

///|
fn is_grouping_debug_target(shapes : Array[LayoutShape]) -> Bool {
  if !PPTX_SLIDE_DEBUG {
    return false
  }

  for sp in shapes {
    let text = normalize_shape_text_for_title(sp.shape.xml)
    if text.contains("Title1") ||
      text.contains("Title2") ||
      text.contains("Title3") ||
      text.contains("Desc1") ||
      text.contains("Desc2") ||
      text.contains("Desc3") {
      return true
    }
    if text.contains("Narrow") ||
      text.contains("Wide") ||
      text.contains("Medium") ||
      text.contains("Compact summary") ||
      text.contains("Balanced note") {
      return true
    }
  }

  false
}

///|
fn shape_group_kind_name(kind : ShapeGroupKind) -> String {
  match kind {
    ShapeGroupKind::Normal => "Normal"
    ShapeGroupKind::CaptionLike => "CaptionLike"
    ShapeGroupKind::TableLike => "TableLike"
  }
}

///|
fn debug_print_shape_group(stage : String, g : ShapeGroup) -> Unit {
  println(
    "[group-debug] " +
    stage +
    " kind=" +
    shape_group_kind_name(g.kind) +
    " top=" +
    g.top.to_string() +
    " left=" +
    g.left.to_string() +
    " len=" +
    g.shapes.length().to_string(),
  )
  for sp in g.shapes {
    println("[group-debug]   - " + normalize_shape_text_for_title(sp.shape.xml))
  }
}

///|
fn sort_shape_groups(groups : Array[ShapeGroup]) -> Array[ShapeGroup] {
  let out : Array[ShapeGroup] = []

  for g in groups {
    let mut inserted = false
    let mut i = 0
    while i < out.length() {
      if shape_group_before(g, out[i]) {
        out.insert(i, g)
        inserted = true
        break
      }
      i += 1
    }
    if !inserted {
      out.push(g)
    }
  }

  out
}

///|
fn group_body_shapes_for_layout(
  shapes : Array[LayoutShape],
) -> Array[ShapeGroup] {
  let groups : Array[ShapeGroup] = []
  let debug_target = is_grouping_debug_target(shapes)
  if shapes.length() == 0 {
    return groups
  }

  let (table_regions, rest_shapes) = extract_table_like_regions(shapes)

  for region in table_regions {
    groups.push(make_shape_group_with_kind(region, ShapeGroupKind::TableLike))
    if PPTX_SLIDE_DEBUG {
      println("[pptx-table] region size=" + region.length().to_string())
      for sp in region {
        println(
          "[pptx-table] cell=" + normalize_shape_text_for_title(sp.shape.xml),
        )
      }
    }
  }

  if rest_shapes.length() == 0 {
    let out = sort_shape_groups(groups)
    if debug_target {
      for g in out {
        debug_print_shape_group("group_body_shapes_for_layout/final", g)
      }
    }
    return out
  }

  let (slide_w, slide_h) = estimate_layout_bounds(rest_shapes)
  let sorted = sort_layout_shapes_simple(rest_shapes)

  for sp in sorted {
    let mut placed = false
    let mut i = 0

    while i < groups.length() {
      match groups[i].kind {
        ShapeGroupKind::TableLike => {
          i += 1
          continue
        }
        ShapeGroupKind::Normal | ShapeGroupKind::CaptionLike =>
          if group_accepts_shape(groups[i], sp, slide_w, slide_h) {
            let merged : Array[LayoutShape] = []
            for old in groups[i].shapes {
              merged.push(old)
            }
            merged.push(sp)

            let kind = if group_caption_like_flag(merged, slide_w, slide_h) {
              ShapeGroupKind::CaptionLike
            } else {
              ShapeGroupKind::Normal
            }

            groups[i] = make_shape_group_with_kind(merged, kind)
            placed = true
            break
          }
      }

      i += 1
    }

    if !placed {
      let kind = if is_caption_like_shape(sp, slide_w, slide_h) {
        ShapeGroupKind::CaptionLike
      } else {
        ShapeGroupKind::Normal
      }
      groups.push(make_shape_group_with_kind([sp], kind))
    }
  }

  let out = sort_shape_groups(groups)
  if debug_target {
    for g in out {
      debug_print_shape_group("group_body_shapes_for_layout/final", g)
    }
  }
  out
}
