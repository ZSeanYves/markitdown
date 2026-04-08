fn extract_table_like_regions(
  shapes : Array[LayoutShape],
) -> (Array[Array[LayoutShape]], Array[LayoutShape]) {
  if PPTX_SLIDE_DEBUG {
    println("[pptx-extract-table] input n=" + shapes.length().to_string())
    for sp in shapes {
      println(
        "[pptx-extract-table] shape=" +
        normalize_shape_text_for_title(sp.shape.xml) +
        " | x=" +
        sp.shape.x.to_string() +
        " | y=" +
        sp.shape.y.to_string() +
        " | w=" +
        sp.shape.w.to_string() +
        " | h=" +
        sp.shape.h.to_string() +
        " | right=" +
        sp.right.to_string() +
        " | bottom=" +
        sp.bottom.to_string() +
        " | cx=" +
        sp.center_x.to_string() +
        " | cy=" +
        sp.center_y.to_string(),
      )
    }

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
    let ok = shapes_form_grid_like_region(sorted)

    if PPTX_SLIDE_DEBUG {
      let region_texts : Array[String] = []
      for sp in sorted {
        region_texts.push(normalize_shape_text_for_title(sp.shape.xml))
      }
      println(
        "[pptx-table-region-decision] size=" +
        sorted.length().to_string() +
        " | texts=" +
        region_texts.join("|") +
        " | ok=" +
        ok.to_string(),
      )
    }

    if ok {
      let expanded = expand_table_like_region_members(sorted, candidates)
      table_regions.push(expanded)
      for sp in expanded {
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
    println("[pptx-table-cluster] input n=" + shapes.length().to_string())
    for sp in shapes {
      println(
        "[pptx-table-cluster] shape=" +
        normalize_shape_text_for_title(sp.shape.xml),
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

  if PPTX_SLIDE_DEBUG {
    println("[pptx-table-cluster] groups n=" + groups.length().to_string())
    for i in 0..<groups.length() {
      let g = groups[i]
      println(
        "[pptx-table-cluster] group " +
        i.to_string() +
        " size=" +
        g.length().to_string(),
      )
      for sp in g {
        println(
          "[pptx-table-cluster] group " +
          i.to_string() +
          " member=" +
          normalize_shape_text_for_title(sp.shape.xml),
        )
      }
    }
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
fn int_in_array(xs : Array[Int], v : Int) -> Bool {
  for x in xs {
    if x == v {
      return true
    }
  }
  false
}

///|
fn collect_bucketed_center_x(
  shapes : Array[LayoutShape],
  step : Int,
) -> Array[Int] {
  let out : Array[Int] = []

  for sp in shapes {
    let q = quantize_coord(sp.center_x, step)
    if !int_in_array(out, q) {
      out.push(q)
    }
  }

  out
}

///|
fn collect_bucketed_center_y(
  shapes : Array[LayoutShape],
  step : Int,
) -> Array[Int] {
  let out : Array[Int] = []

  for sp in shapes {
    let q = quantize_coord(sp.center_y, step)
    if !int_in_array(out, q) {
      out.push(q)
    }
  }

  out
}

///|
/// after a table-like region is accepted, try to absorb extra candidate shapes
/// that align with both an existing row bucket and an existing column bucket.
/// this is mainly for edge/header cells that were missed by the initial cluster.
fn expand_table_like_region_members(
  region : Array[LayoutShape],
  candidates : Array[LayoutShape],
) -> Array[LayoutShape] {
  if region.length() == 0 {
    return region
  }

  let avgw = average_shape_w(region)
  let avgh = average_shape_h(region)

  let x_step = if avgw > 0 { max_int(1, avgw / 2) } else { 1 }
  let y_step = if avgh > 0 { max_int(1, avgh / 2) } else { 1 }

  let col_buckets = collect_bucketed_center_x(region, x_step)
  let row_buckets = collect_bucketed_center_y(region, y_step)

  let out : Array[LayoutShape] = []
  for sp in region {
    out.push(sp)
  }

  if PPTX_SLIDE_DEBUG {
    let region_texts_before : Array[String] = []
    for sp in region {
      region_texts_before.push(normalize_shape_text_for_title(sp.shape.xml))
    }
    println(
      "[pptx-table-expand] region before=" + region_texts_before.join("|"),
    )
  }

  for sp in candidates {
    if layout_shape_in_array(sp, out) {
      continue
    }

    let qx = quantize_coord(sp.center_x, x_step)
    let qy = quantize_coord(sp.center_y, y_step)

    if int_in_array(col_buckets, qx) && int_in_array(row_buckets, qy) {
      out.push(sp)
      if PPTX_SLIDE_DEBUG {
        println(
          "[pptx-table-expand] added=" +
          normalize_shape_text_for_title(sp.shape.xml),
        )
      }
    }
  }

  let sorted = sort_layout_shapes_simple(out)
  if PPTX_SLIDE_DEBUG {
    let region_texts_after : Array[String] = []
    for sp in sorted {
      region_texts_after.push(normalize_shape_text_for_title(sp.shape.xml))
    }
    println("[pptx-table-expand] region after=" + region_texts_after.join("|"))
  }
  sorted
}

///|
/// implied grid density as a rational pair:
/// actual cells = shapes.length()
/// implied cells = rows * cols
fn grid_density_numer_denom(
  shape_count : Int,
  rows : Int,
  cols : Int,
) -> (Int, Int) {
  let denom = rows * cols
  if denom <= 0 {
    (0, 1)
  } else {
    (shape_count, denom)
  }
}

///|
fn debug_print_grid_region_stats(
  shapes : Array[LayoutShape],
  rows : Int,
  cols : Int,
  rich_rows : Int,
  rich_cols : Int,
  max_row_pop : Int,
  max_col_pop : Int,
  density_num : Int,
  density_den : Int,
) -> Unit {
  if !PPTX_SLIDE_DEBUG {
    return
  }

  println(
    "[pptx-grid-region] n=" +
    shapes.length().to_string() +
    " rows=" +
    rows.to_string() +
    " cols=" +
    cols.to_string() +
    " rich_rows=" +
    rich_rows.to_string() +
    " rich_cols=" +
    rich_cols.to_string() +
    " max_row_pop=" +
    max_row_pop.to_string() +
    " max_col_pop=" +
    max_col_pop.to_string() +
    " density=" +
    density_num.to_string() +
    "/" +
    density_den.to_string(),
  )

  for sp in shapes {
    println(
      "[pptx-grid-region-shape] " +
      normalize_shape_text_for_title(sp.shape.xml) +
      " | x=" +
      sp.shape.x.to_string() +
      " y=" +
      sp.shape.y.to_string() +
      " w=" +
      sp.shape.w.to_string() +
      " h=" +
      sp.shape.h.to_string() +
      " cx=" +
      sp.center_x.to_string() +
      " cy=" +
      sp.center_y.to_string(),
    )
  }
}

///|
/// conservative grid/table-like region detection:
/// - at least 4 shapes
/// - input is already a candidate cluster from filter_table_like_candidates(...)
/// - at least 2 rows and 2 columns after rough bucketing
/// - not just sparse 2d points: need repeated occupancy on both axes
/// - need multiple non-trivial rows and multiple non-trivial cols
/// - need moderate fill density in the implied grid
fn shapes_form_grid_like_region(shapes : Array[LayoutShape]) -> Bool {
  if PPTX_SLIDE_DEBUG {
    let shape_texts : Array[String] = []
    for sp in shapes {
      shape_texts.push(normalize_shape_text_for_title(sp.shape.xml))
    }
    println("[pptx-table-grid] shapes=" + shape_texts.join("|"))
  }

  if shapes.length() < 4 {
    if PPTX_SLIDE_DEBUG {
      println("[pptx-table-grid] decision=false")
    }
    return false
  }

  let avgw = average_shape_w(shapes)
  let avgh = average_shape_h(shapes)

  let x_step = if avgw > 0 { max_int(1, avgw / 2) } else { 1 }
  let y_step = if avgh > 0 { max_int(1, avgh / 2) } else { 1 }

  if PPTX_SLIDE_DEBUG {
    println(
      "[pptx-table-grid] avgw=" +
      avgw.to_string() +
      " | avgh=" +
      avgh.to_string() +
      " | x_step=" +
      x_step.to_string() +
      " | y_step=" +
      y_step.to_string(),
    )
  }

  let cols = count_distinct_bucketed_center_x(shapes, x_step)
  let rows = count_distinct_bucketed_center_y(shapes, y_step)

  if PPTX_SLIDE_DEBUG {
    println(
      "[pptx-table-grid] rows=" +
      rows.to_string() +
      " | cols=" +
      cols.to_string(),
    )
  }

  if cols < 2 || rows < 2 {
    if PPTX_SLIDE_DEBUG {
      debug_print_grid_region_stats(shapes, rows, cols, 0, 0, 0, 0, 0, 1)
      println("[pptx-table-grid] decision=false")
    }
    return false
  }

  let max_col_pop = max_bucket_population_center_x(shapes, x_step)
  let max_row_pop = max_bucket_population_center_y(shapes, y_step)

  if PPTX_SLIDE_DEBUG {
    println(
      "[pptx-table-grid] max_row_pop=" +
      max_row_pop.to_string() +
      " | max_col_pop=" +
      max_col_pop.to_string(),
    )
  }

  // 至少要有一列里出现 2+，且一行里出现 2+
  if max_col_pop < 2 || max_row_pop < 2 {
    if PPTX_SLIDE_DEBUG {
      debug_print_grid_region_stats(
        shapes, rows, cols, 0, 0, max_row_pop, max_col_pop, 0, 1,
      )
      println("[pptx-table-grid] decision=false")
    }
    return false
  }

  let rich_cols = count_bucketed_center_x_with_min_population(shapes, x_step, 2)
  let rich_rows = count_bucketed_center_y_with_min_population(shapes, y_step, 2)

  let (density_num, density_den) = grid_density_numer_denom(
    shapes.length(),
    rows,
    cols,
  )

  if PPTX_SLIDE_DEBUG {
    println(
      "[pptx-table-grid] rich_rows=" +
      rich_rows.to_string() +
      " | rich_cols=" +
      rich_cols.to_string(),
    )
    println(
      "[pptx-table-grid] density=" +
      density_num.to_string() +
      "/" +
      density_den.to_string(),
    )
    for sp in shapes {
      println(
        "[pptx-table-grid] bucket=" +
        normalize_shape_text_for_title(sp.shape.xml) +
        " | qx=" +
        quantize_coord(sp.center_x, x_step).to_string() +
        " | qy=" +
        quantize_coord(sp.center_y, y_step).to_string(),
      )
    }
    debug_print_grid_region_stats(
      shapes, rows, cols, rich_rows, rich_cols, max_row_pop, max_col_pop, density_num,
      density_den,
    )
  }

  // 不能只有“某一行”或“某一列”碰巧重复；
  // 需要至少两行、两列都具备非平凡 occupancy
  if rich_cols < 2 || rich_rows < 2 {
    if PPTX_SLIDE_DEBUG {
      println("[pptx-table-grid] decision=false")
    }
    return false
  }

  // implied grid density: avoid very sparse pseudo-2d layouts
  if density_num * 2 < density_den {
    if PPTX_SLIDE_DEBUG {
      println("[pptx-table-grid] decision=false")
    }
    return false
  }

  if PPTX_SLIDE_DEBUG {
    println("[pptx-table-grid] decision=true")
  }
  true
}

///|
fn should_link_table_like_shapes(a : LayoutShape, b : LayoutShape) -> Bool {
  let hgap = horizontal_gap(a, b)
  let vgap = vertical_gap(a, b)
  let hoverlap = horizontal_overlap(a, b)
  let voverlap = vertical_overlap(a, b)

  let maxw = max_int(a.shape.w, b.shape.w)
  let maxh = max_int(a.shape.h, b.shape.h)

  let same_row = approx_same_row(a, b)
  let same_col = approx_same_col(a, b)

  let ta = normalize_shape_text_for_title(a.shape.xml)
  let tb = normalize_shape_text_for_title(b.shape.xml)

  if PPTX_SLIDE_DEBUG {
    println(
      "[pptx-link] " +
      ta +
      " <-> " +
      tb +
      " | same_row=" +
      same_row.to_string() +
      " | same_col=" +
      same_col.to_string() +
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

  // row-wise link:
  // must really look like the same visual row,
  // and the horizontal gap should still be locally reasonable.
  if same_row && voverlap > 0 && hgap <= max_int(24, maxw * 2) {
    return true
  }

  // col-wise link:
  // must really look like the same visual column,
  // and the vertical gap should still be locally reasonable.
  if same_col && hoverlap > 0 && vgap <= max_int(16, maxh * 2) {
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
fn count_distinct_bucketed_center_x(
  shapes : Array[LayoutShape],
  step : Int,
) -> Int {
  collect_bucketed_center_x(shapes, step).length()
}

///|
fn count_distinct_bucketed_center_y(
  shapes : Array[LayoutShape],
  step : Int,
) -> Int {
  collect_bucketed_center_y(shapes, step).length()
}

///|
fn max_bucket_population_center_x(
  shapes : Array[LayoutShape],
  step : Int,
) -> Int {
  let buckets : Array[(Int, Int)] = []

  for sp in shapes {
    let q = quantize_coord(sp.center_x, step)
    let mut found = false
    for i in 0..<buckets.length() {
      let (k, v) = buckets[i]
      if k == q {
        buckets[i] = (k, v + 1)
        found = true
        break
      }
    }
    if !found {
      buckets.push((q, 1))
    }
  }

  let mut best = 0
  for i in 0..<buckets.length() {
    let (_, v) = buckets[i]
    if v > best {
      best = v
    }
  }
  best
}

///|
fn max_bucket_population_center_y(
  shapes : Array[LayoutShape],
  step : Int,
) -> Int {
  let buckets : Array[(Int, Int)] = []

  for sp in shapes {
    let q = quantize_coord(sp.center_y, step)
    let mut found = false
    for i in 0..<buckets.length() {
      let (k, v) = buckets[i]
      if k == q {
        buckets[i] = (k, v + 1)
        found = true
        break
      }
    }
    if !found {
      buckets.push((q, 1))
    }
  }

  let mut best = 0
  for i in 0..<buckets.length() {
    let (_, v) = buckets[i]
    if v > best {
      best = v
    }
  }
  best
}

///|
fn count_bucketed_center_x_with_min_population(
  shapes : Array[LayoutShape],
  step : Int,
  min_pop : Int,
) -> Int {
  let buckets : Array[(Int, Int)] = []

  for sp in shapes {
    let q = quantize_coord(sp.center_x, step)
    let mut found = false
    for i in 0..<buckets.length() {
      let (k, v) = buckets[i]
      if k == q {
        buckets[i] = (k, v + 1)
        found = true
        break
      }
    }
    if !found {
      buckets.push((q, 1))
    }
  }

  let mut cnt = 0
  for i in 0..<buckets.length() {
    let (_, v) = buckets[i]
    if v >= min_pop {
      cnt += 1
    }
  }
  cnt
}

///|
fn count_bucketed_center_y_with_min_population(
  shapes : Array[LayoutShape],
  step : Int,
  min_pop : Int,
) -> Int {
  let buckets : Array[(Int, Int)] = []

  for sp in shapes {
    let q = quantize_coord(sp.center_y, step)
    let mut found = false
    for i in 0..<buckets.length() {
      let (k, v) = buckets[i]
      if k == q {
        buckets[i] = (k, v + 1)
        found = true
        break
      }
    }
    if !found {
      buckets.push((q, 1))
    }
  }

  let mut cnt = 0
  for i in 0..<buckets.length() {
    let (_, v) = buckets[i]
    if v >= min_pop {
      cnt += 1
    }
  }
  cnt
}
