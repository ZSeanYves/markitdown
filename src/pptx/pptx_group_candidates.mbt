///|
fn is_small_shape_for_grouping(
  sp : LayoutShape,
  slide_w : Int,
  slide_h : Int,
) -> Bool {
  if slide_w <= 0 || slide_h <= 0 {
    return false
  }

  let w = sp.shape.w
  let h = sp.shape.h

  let narrow = w <= slide_w / 3
  let low = h <= slide_h / 6
  let small_area = w * h <= slide_w * slide_h / 20

  (narrow && low) || small_area
}

///|
fn is_caption_like_shape(
  sp : LayoutShape,
  slide_w : Int,
  slide_h : Int,
) -> Bool {
  if sp.shape.is_title {
    return false
  }

  let text = normalize_shape_text_for_title(sp.shape.xml)
  if text == "" {
    return false
  }

  if is_bullet_like(text) {
    return false
  }

  if ends_like_sentence(text) {
    return false
  }

  let n = text.to_array().length()
  if n > 40 {
    return false
  }

  if slide_h > 0 && sp.shape.y <= slide_h / 5 {
    return false
  }

  if !is_small_shape_for_grouping(sp, slide_w, slide_h) {
    return false
  }

  true
}

///|
fn is_table_like_shape_candidate(
  sp : LayoutShape,
  slide_w : Int,
  slide_h : Int,
) -> Bool {
  let text = normalize_shape_text_for_title(sp.shape.xml)
  let small = is_small_shape_for_grouping(sp, slide_w, slide_h)
  let bullet = is_bullet_like(text)
  let sent = ends_like_sentence(text)
  let n = text.to_array().length()

  let ok = !sp.shape.is_title &&
    text != "" &&
    !bullet &&
    !sent &&
    n <= 30 &&
    small
  if PPTX_SLIDE_DEBUG {
    println(
      "[pptx-table-candidate-check] " +
      text +
      " | small=" +
      small.to_string() +
      " | bullet=" +
      bullet.to_string() +
      " | sent=" +
      sent.to_string() +
      " | len=" +
      n.to_string() +
      " | ok=" +
      ok.to_string(),
    )
  }
  ok
}

///|
fn approx_same_row(a : LayoutShape, b : LayoutShape) -> Bool {
  let cy_diff = abs_int(a.center_y - b.center_y)
  let maxh = max_int(a.shape.h, b.shape.h)
  cy_diff <= max_int(8, maxh / 2)
}

///|
fn approx_same_col(a : LayoutShape, b : LayoutShape) -> Bool {
  let cx_diff = abs_int(a.center_x - b.center_x)
  let maxw = max_int(a.shape.w, b.shape.w)
  cx_diff <= max_int(12, maxw / 2)
}

///|
fn is_near_row_neighbor(a : LayoutShape, b : LayoutShape) -> Bool {
  if !approx_same_row(a, b) {
    return false
  }

  let gap = horizontal_gap(a, b)
  let maxw = max_int(a.shape.w, b.shape.w)

  gap <= max_int(24, maxw)
}

///|
fn is_near_col_neighbor(a : LayoutShape, b : LayoutShape) -> Bool {
  if !approx_same_col(a, b) {
    return false
  }

  let gap = vertical_gap(a, b)
  let maxh = max_int(a.shape.h, b.shape.h)

  gap <= max_int(16, maxh)
}

///|
fn has_table_like_neighbor_support(
  sp : LayoutShape,
  shapes : Array[LayoutShape],
  slide_w : Int,
  slide_h : Int,
) -> Bool {
  let mut row_neighbors = 0
  let mut col_neighbors = 0

  for other in shapes {
    if same_layout_shape(sp, other) {
      continue
    }

    if !is_table_like_shape_candidate(other, slide_w, slide_h) {
      continue
    }

    if is_near_row_neighbor(sp, other) {
      row_neighbors += 1
    }

    if is_near_col_neighbor(sp, other) {
      col_neighbors += 1
    }
  }

  let total_neighbors = row_neighbors + col_neighbors
  let ok =
    (row_neighbors >= 1 && col_neighbors >= 1) ||
    total_neighbors >= 2

  if PPTX_SLIDE_DEBUG {
    println(
      "[pptx-table-neighbor-support] " +
      normalize_shape_text_for_title(sp.shape.xml) +
      " | row_neighbors=" +
      row_neighbors.to_string() +
      " | col_neighbors=" +
      col_neighbors.to_string() +
      " | total_neighbors=" +
      total_neighbors.to_string() +
      " | ok=" +
      ok.to_string(),
    )
  }

  ok
}

///|
fn filter_table_like_candidates(
  shapes : Array[LayoutShape],
) -> Array[LayoutShape] {
  let out : Array[LayoutShape] = []
  let (slide_w, slide_h) = estimate_layout_bounds(shapes)

  for sp in shapes {
    let text = normalize_shape_text_for_title(sp.shape.xml)
    let base_ok = is_table_like_shape_candidate(sp, slide_w, slide_h)
    let support_ok = if base_ok {
      has_table_like_neighbor_support(sp, shapes, slide_w, slide_h)
    } else {
      false
    }
    let ok = base_ok && support_ok

    if PPTX_SLIDE_DEBUG {
      println(
        "[pptx-table-candidate] " +
        text +
        " | base_ok=" +
        base_ok.to_string() +
        " | support_ok=" +
        support_ok.to_string() +
        " | ok=" +
        ok.to_string() +
        " | x=" +
        sp.shape.x.to_string() +
        " | y=" +
        sp.shape.y.to_string() +
        " | w=" +
        sp.shape.w.to_string() +
        " | h=" +
        sp.shape.h.to_string(),
      )
    }

    if ok {
      out.push(sp)
    }
  }

  out
}
