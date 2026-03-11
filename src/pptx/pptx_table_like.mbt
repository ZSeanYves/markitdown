///|
fn extract_table_like_regions(
  shapes : Array[LayoutShape],
) -> (Array[Array[LayoutShape]], Array[LayoutShape]) {
  if PPTX_SLIDE_DEBUG {
    println("[pptx-extract-table] input n=" + shapes.length().to_string())

    let candidates = filter_table_like_candidates(shapes)
    println(
      "[pptx-extract-table] candidates n=" + candidates.length().to_string(),
    )
    for sp in candidates {
      println(
        "[pptx-extract-table] candidate=" +
        normalize_shape_text_for_title(sp.shape.xml),
      )
    }
    if shapes.length() == 0 {
      return ([], [])
    }
  }
  let candidates = filter_table_like_candidates(shapes)
  if candidates.length() < 4 {
    return ([], shapes)
  }

  let candidate_groups = cluster_table_like_candidate_shapes(candidates)

  let table_regions : Array[Array[LayoutShape]] = []
  let used : Array[LayoutShape] = []

  for g in candidate_groups {
    let sorted = sort_layout_shapes_simple(g)
    if shapes_form_grid_like_region(sorted) {
      table_regions.push(sorted)
      for sp in sorted {
        used.push(sp)
      }
    }
  }

  let rest : Array[LayoutShape] = []
  for sp in shapes {
    if !layout_shape_in_array(sp, used) {
      rest.push(sp)
    }
  }

  (table_regions, rest)
}

///|
fn cluster_table_like_candidate_shapes(
  shapes : Array[LayoutShape],
) -> Array[Array[LayoutShape]] {
  if PPTX_SLIDE_DEBUG {
    println("[pptx-cluster-enter] n=" + shapes.length().to_string())
    for sp in shapes {
      println(
        "[pptx-cluster-shape] " + normalize_shape_text_for_title(sp.shape.xml),
      )
    }
  }
  let groups : Array[Array[LayoutShape]] = []

  if shapes.length() == 0 {
    return groups
  }

  let sorted = sort_layout_shapes_simple(shapes)
  let visited : Array[Bool] = []
  for _ in 0..<sorted.length() {
    visited.push(false)
  }

  for i in 0..<sorted.length() {
    if visited[i] {
      continue
    }

    let comp : Array[LayoutShape] = []
    let stack : Array[Int] = [i]
    visited[i] = true

    while stack.length() > 0 {
      let last = stack.length() - 1
      let cur = stack[last]
      ignore(stack.pop())
      comp.push(sorted[cur])

      for j in 0..<sorted.length() {
        if visited[j] {
          continue
        }
        if should_link_table_like_shapes(sorted[cur], sorted[j]) {
          visited[j] = true
          stack.push(j)
        }
      }
    }

    groups.push(sort_layout_shapes_simple(comp))
  }

  groups
}

///|
fn average_shape_w(shapes : Array[LayoutShape]) -> Int {
  if shapes.length() == 0 {
    return 0
  }

  let mut sum = 0
  for sp in shapes {
    sum += sp.shape.w
  }
  sum / shapes.length()
}

///|
fn average_shape_h(shapes : Array[LayoutShape]) -> Int {
  if shapes.length() == 0 {
    return 0
  }

  let mut sum = 0
  for sp in shapes {
    sum += sp.shape.h
  }
  sum / shapes.length()
}

///|
fn quantize_coord(v : Int, step : Int) -> Int {
  if step <= 0 {
    v
  } else {
    v / step * step
  }
}

///|
fn count_distinct_bucketed_x(shapes : Array[LayoutShape], step : Int) -> Int {
  let seen : Array[Int] = []

  for sp in shapes {
    let q = quantize_coord(sp.shape.x, step)
    let mut exists = false
    for v in seen {
      if v == q {
        exists = true
        break
      }
    }
    if !exists {
      seen.push(q)
    }
  }

  seen.length()
}

///|
fn count_distinct_bucketed_y(shapes : Array[LayoutShape], step : Int) -> Int {
  let seen : Array[Int] = []

  for sp in shapes {
    let q = quantize_coord(sp.shape.y, step)
    let mut exists = false
    for v in seen {
      if v == q {
        exists = true
        break
      }
    }
    if !exists {
      seen.push(q)
    }
  }

  seen.length()
}

///|
/// conservative grid/table-like region detection:
/// - at least 4 shapes
/// - most shapes are short/small candidates
/// - at least 2 rows and 2 columns after rough bucketing
fn shapes_form_grid_like_region(shapes : Array[LayoutShape]) -> Bool {
  if shapes.length() < 4 {
    return false
  }

  let (slide_w, slide_h) = estimate_layout_bounds(shapes)

  let mut candidate_cnt = 0
  for sp in shapes {
    if is_table_like_shape_candidate(sp, slide_w, slide_h) {
      candidate_cnt += 1
    }
  }

  if candidate_cnt * 2 < shapes.length() {
    return false
  }

  let avgw = average_shape_w(shapes)
  let avgh = average_shape_h(shapes)

  let x_step = if avgw > 0 { avgw / 2 } else { 1 }
  let y_step = if avgh > 0 { avgh / 2 } else { 1 }

  let cols = count_distinct_bucketed_x(shapes, x_step)
  let rows = count_distinct_bucketed_y(shapes, y_step)

  if cols < 2 || rows < 2 {
    return false
  }

  true
}

///|
fn should_link_table_like_shapes(a : LayoutShape, b : LayoutShape) -> Bool {
  //println("[pptx-link-enter]")
  let hgap = horizontal_gap(a, b)
  let vgap = vertical_gap(a, b)
  let hoverlap = horizontal_overlap(a, b)
  let voverlap = vertical_overlap(a, b)

  let maxw = max_int(a.shape.w, b.shape.w)
  let maxh = max_int(a.shape.h, b.shape.h)

  let ta = normalize_shape_text_for_title(a.shape.xml)
  let tb = normalize_shape_text_for_title(b.shape.xml)

  if (
      (ta == "Revenue" && tb == "Cost") ||
      (ta == "Cost" && tb == "Revenue") ||
      (ta == "Revenue" && tb == "120") ||
      (ta == "120" && tb == "Revenue")
    ) &&
    PPTX_SLIDE_DEBUG {
    println(
      "[pptx-link] " +
      ta +
      " <-> " +
      tb +
      " | hgap=" +
      hgap.to_string() +
      " | vgap=" +
      vgap.to_string() +
      " | hoverlap=" +
      hoverlap.to_string() +
      " | voverlap=" +
      voverlap.to_string() +
      " | maxw=" +
      maxw.to_string() +
      " | maxh=" +
      maxh.to_string(),
    )
  }

  if hoverlap > 0 && vgap <= maxh * 2 {
    return true
  }

  if voverlap > 0 && hgap <= maxw * 2 {
    return true
  }

  false
}

///|
fn same_layout_shape(a : LayoutShape, b : LayoutShape) -> Bool {
  a.shape.x == b.shape.x &&
  a.shape.y == b.shape.y &&
  a.shape.w == b.shape.w &&
  a.shape.h == b.shape.h &&
  a.shape.xml == b.shape.xml
}

///|
fn layout_shape_in_array(sp : LayoutShape, arr : Array[LayoutShape]) -> Bool {
  for item in arr {
    if same_layout_shape(sp, item) {
      return true
    }
  }
  false
}
