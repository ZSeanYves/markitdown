///|
/// scan slide xml by shape (<p:sp>), collect shapes first,
/// recover a more stable reading order by:
/// - separating title shapes
/// - conservative title fallback promotion
/// - filtering obvious body noise
/// - grouping nearby small caption-like body shapes
/// - detecting simple two-column layout
/// then extract each shape's <a:p> in that order
fn extract_slide_paragraphs(xml : Bytes) -> Array[SlideParagraph] raise {
  let out : Array[SlideParagraph] = []

  let shapes = collect_slide_shapes(xml)
  if PPTX_SLIDE_DEBUG {
    for sp in shapes {
      let text = normalize_slide_text(
        extract_text_runs(sp.xml, 0, sp.xml.length()),
      )
      println(
        "[pptx-shape] text=" +
        text +
        " | is_title=" +
        sp.is_title.to_string() +
        " | is_body=" +
        sp.is_body.to_string() +
        " | x=" +
        sp.x.to_string() +
        " | y=" +
        sp.y.to_string() +
        " | w=" +
        sp.w.to_string() +
        " | h=" +
        sp.h.to_string(),
      )
    }
  }
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

  let whole_groups = group_body_shapes_for_layout(body_shapes)

  let mut has_table_like = false
  for g in whole_groups {
    match g.kind {
      ShapeGroupKind::TableLike => {
        has_table_like = true
        break
      }
      _ => ()
    }
  }

  if has_table_like {
    // allow card-like pair flatten even when the layout was grouped
    // as a single table-like region.
    if whole_groups.length() == 1 {
      let g = whole_groups[0]
      match g.kind {
        ShapeGroupKind::TableLike => {
          let rows = cluster_shapes_into_rows(g.shapes)
          if looks_like_card_pair_rows(rows) {
            append_card_pair_rows_by_columns(out, rows)
            return out
          }
        }
        _ => ()
      }
    }

    let flat = flatten_shape_groups(whole_groups)
    for sp in flat {
      out.push(sp)
    }
    return out
  }

  let body_rows = cluster_shapes_into_rows(body_shapes)
  if looks_like_card_pair_rows(body_rows) {
    append_card_pair_rows_by_columns(out, body_rows)
    return out
  }

  if is_two_columns(body_shapes) &&
    !looks_like_partial_callout_caption_scatter(body_shapes) {
    let (left, right) = split_two_columns(body_shapes)

    let left_groups = group_body_shapes_for_layout(left)
    let right_groups = group_body_shapes_for_layout(right)

    let left_flat = flatten_shape_groups(left_groups)
    let right_flat = flatten_shape_groups(right_groups)

    for sp in left_flat {
      out.push(sp)
    }
    for sp in right_flat {
      out.push(sp)
    }

    return out
  }

  let flat = flatten_shape_groups(whole_groups)
  for sp in flat {
    out.push(sp)
  }

  out
}

///|
fn looks_like_partial_callout_caption_scatter(
  shapes : Array[LayoutShape],
) -> Bool {
  if shapes.length() < 4 {
    return false
  }

  let (slide_w, slide_h) = estimate_layout_bounds(shapes)
  let mut caption_like_count = 0
  for sp in shapes {
    if is_caption_like_shape(sp, slide_w, slide_h) {
      caption_like_count += 1
    }
  }

  if caption_like_count * 2 < shapes.length() {
    return false
  }

  let (pairs, rest) = collect_full_callout_pairs(shapes)
  pairs.length() == 1 && rest.length() >= 2
}

///|
fn flatten_shape_groups(groups : Array[ShapeGroup]) -> Array[LayoutShape] {
  let out : Array[LayoutShape] = []

  for g in groups {
    match g.kind {
      ShapeGroupKind::TableLike => {
        let rows = cluster_shapes_into_rows(g.shapes)
        if looks_like_card_pair_rows(rows) {
          append_card_pair_rows_by_columns(out, rows)
        } else {
          append_rows(out, rows)
        }
      }
      ShapeGroupKind::Normal =>
        for sp in g.shapes {
          out.push(sp)
        }
      ShapeGroupKind::CaptionLike =>
        if !append_caption_group_as_full_callout_pairs(out, g.shapes) {
          for sp in g.shapes {
            out.push(sp)
          }
        }
    }
  }

  out
}

///|
fn layout_shape_eq(a : LayoutShape, b : LayoutShape) -> Bool {
  a.shape.x == b.shape.x &&
  a.shape.y == b.shape.y &&
  a.shape.w == b.shape.w &&
  a.shape.h == b.shape.h &&
  a.shape.xml == b.shape.xml
}

///|
fn layout_shape_in_array(sp : LayoutShape, arr : Array[LayoutShape]) -> Bool {
  for item in arr {
    if layout_shape_eq(sp, item) {
      return true
    }
  }
  false
}


///|
fn normalize_callout_pair_for_output(
  a : LayoutShape,
  b : LayoutShape,
) -> (LayoutShape, LayoutShape) {
  let at = normalize_shape_text_for_title(a.shape.xml)
  let bt = normalize_shape_text_for_title(b.shape.xml)

  let a_has_space = callout_text_contains_space(at)
  let b_has_space = callout_text_contains_space(bt)

  if !a_has_space && b_has_space {
    return (a, b)
  }

  if !b_has_space && a_has_space {
    return (b, a)
  }

  let a_title = looks_like_callout_title_text(at)
  let b_title = looks_like_callout_title_text(bt)
  let a_desc = looks_like_callout_desc_text(at)
  let b_desc = looks_like_callout_desc_text(bt)

  if a_title && b_desc {
    return (a, b)
  }

  if b_title && a_desc {
    return (b, a)
  }

  if a.shape.y <= b.shape.y {
    (a, b)
  } else {
    (b, a)
  }
}

///|
fn callout_pair_left(p : (LayoutShape, LayoutShape)) -> Int {
  let (a, b) = p
  min_int(a.shape.x, b.shape.x)
}

///|
fn callout_pair_top(p : (LayoutShape, LayoutShape)) -> Int {
  let (a, b) = p
  min_int(a.shape.y, b.shape.y)
}

///|
fn callout_pair_same_visual_row(
  a : (LayoutShape, LayoutShape),
  b : (LayoutShape, LayoutShape),
) -> Bool {
  let dy = abs_int(callout_pair_top(a) - callout_pair_top(b))
  dy <= 260000
}

///|
fn callout_pair_before(
  a : (LayoutShape, LayoutShape),
  b : (LayoutShape, LayoutShape),
) -> Bool {
  if callout_pair_same_visual_row(a, b) {
    let al = callout_pair_left(a)
    let bl = callout_pair_left(b)

    if al != bl {
      return al < bl
    }

    let at = callout_pair_top(a)
    let bt = callout_pair_top(b)
    return at < bt
  }

  let at = callout_pair_top(a)
  let bt = callout_pair_top(b)

  if at != bt {
    return at < bt
  }

  let al = callout_pair_left(a)
  let bl = callout_pair_left(b)
  al < bl
}

///|
fn sort_callout_pairs(
  pairs : Array[(LayoutShape, LayoutShape)],
) -> Array[(LayoutShape, LayoutShape)] {
  let out : Array[(LayoutShape, LayoutShape)] = []

  for p in pairs {
    let mut inserted = false
    let mut i = 0
    while i < out.length() {
      if callout_pair_before(p, out[i]) {
        out.insert(i, p)
        inserted = true
        break
      }
      i += 1
    }

    if !inserted {
      out.push(p)
    }
  }

  out
}

///|
fn collect_full_callout_pairs(
  shapes : Array[LayoutShape],
) -> (Array[(LayoutShape, LayoutShape)], Array[LayoutShape]) {
  let sorted = sort_layout_shapes_simple(shapes)
  let used : Array[LayoutShape] = []
  let pairs : Array[(LayoutShape, LayoutShape)] = []

  for i in 0..<sorted.length() {
    let a = sorted[i]
    if layout_shape_in_array(a, used) {
      continue
    }

    let mut best_j = -1
    let mut best_gap = 0

    for j in 0..<sorted.length() {
      if i == j {
        continue
      }

      let b = sorted[j]
      if layout_shape_in_array(b, used) {
        continue
      }

      if !looks_like_callout_pair(a, b) {
        continue
      }

      let vgap = vertical_gap(a, b)
      if best_j == -1 || vgap < best_gap {
        best_j = j
        best_gap = vgap
      }
    }

    if best_j != -1 {
      let b = sorted[best_j]
      used.push(a)
      used.push(b)
      pairs.push(normalize_callout_pair_for_output(a, b))
    }
  }

  let rest : Array[LayoutShape] = []
  for sp in sorted {
    if !layout_shape_in_array(sp, used) {
      rest.push(sp)
    }
  }

  (pairs, rest)
}

///|
fn append_caption_group_as_full_callout_pairs(
  out : Array[LayoutShape],
  shapes : Array[LayoutShape],
) -> Bool {
  let (pairs, rest) = collect_full_callout_pairs(shapes)
  if pairs.length() < 2 || rest.length() != 0 {
    return false
  }

  let sorted_pairs = sort_callout_pairs(pairs)
  for pair in sorted_pairs {
    let (first, second) = pair
    out.push(first)
    out.push(second)
  }

  true
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
fn cluster_shapes_into_rows(
  shapes : Array[LayoutShape],
) -> Array[Array[LayoutShape]] {
  let rows : Array[Array[LayoutShape]] = []
  let sorted = sort_layout_shapes_simple(shapes)

  for sp in sorted {
    if PPTX_SLIDE_DEBUG {
      println(
        "[row-cluster] try shape='" +
        normalize_shape_text_for_title(sp.shape.xml) +
        "' y=" + sp.shape.y.to_string() +
        " h=" + sp.shape.h.to_string() +
        " bottom=" + sp.bottom.to_string() +
        " cy=" + sp.center_y.to_string(),
      )
    }

    let mut placed = false
    let mut i = 0

    while i < rows.length() {
      if PPTX_SLIDE_DEBUG {
        println(
          "[row-cluster]   against row " +
          i.to_string() +
          " row_cy=" +
          row_center_y(rows[i]).to_string() +
          " row_top=" +
          row_top(rows[i]).to_string(),
        )
      }

      if row_accepts_shape(rows[i], sp) {
        rows[i].push(sp)
        placed = true
        if PPTX_SLIDE_DEBUG {
          println("[row-cluster]   => accepted by row " + i.to_string())
        }
        break
      }

      i = i + 1
    }

    if !placed {
      rows.push([sp])
      if PPTX_SLIDE_DEBUG {
        println("[row-cluster]   => create new row")
      }
    }
  }

  for i in 0..<rows.length() {
    let row = rows[i]
    rows[i] = sort_layout_shapes_by_x(row)
  }

  if PPTX_SLIDE_DEBUG {
    println("[pptx-table] row count=" + rows.length().to_string())
    for i in 0..<rows.length() {
      println(
        "[pptx-table] row " +
        i.to_string() +
        " center_y=" +
        row_center_y(rows[i]).to_string(),
      )
      for sp in rows[i] {
        println("  - " + normalize_shape_text_for_title(sp.shape.xml))
      }
    }
  }

  sort_rows_by_top(rows)
}

///|
fn row_center_y(row : Array[LayoutShape]) -> Int {
  if row.length() == 0 {
    return 0
  }

  let mut sum = 0
  for sp in row {
    sum += sp.center_y
  }

  sum / row.length()
}

///|
fn row_max_shape_h(row : Array[LayoutShape]) -> Int {
  if row.length() == 0 {
    return 1
  }

  let mut v = row[0].shape.h
  if v <= 0 {
    v = 1
  }

  for i in 1..<row.length() {
    let h = row[i].shape.h
    let hv = if h > 0 { h } else { 1 }
    if hv > v {
      v = hv
    }
  }

  v
}

///|
fn row_accepts_shape(row : Array[LayoutShape], sp : LayoutShape) -> Bool {
  if row.length() == 0 {
    return true
  }

  let use_strict = row_looks_like_staggered_callout_band(row)

  let mut overlap_count = 0
  for item in row {
    let ov = vertical_overlap(item, sp)
    if ov <= 0 {
      continue
    }

    if use_strict {
      let item_h = if item.shape.h > 0 { item.shape.h } else { 1 }
      let sp_h = if sp.shape.h > 0 { sp.shape.h } else { 1 }
      let maxh = max_int(item_h, sp_h)
      let cy_diff = abs_int(item.center_y - sp.center_y)
      if cy_diff > max_int(12, maxh / 2) {
        continue
      }
    }

    overlap_count += 1
  }

  if row.length() == 1 {
    if overlap_count >= 1 {
      return true
    }
  } else {
    if overlap_count >= 2 {
      return true
    }
  }

  let row_cy = row_center_y(row)
  let row_h = row_max_shape_h(row)
  let sp_h = if sp.shape.h > 0 { sp.shape.h } else { 1 }

  let maxh = max_int(row_h, sp_h)
  let threshold = if use_strict { max_int(12, maxh / 2) } else { max_int(12, maxh) }

  let dy = abs_int(row_cy - sp.center_y)
  if dy > threshold {
    return false
  }

  true
}

///|
fn row_looks_like_staggered_callout_band(row : Array[LayoutShape]) -> Bool {
  if row.length() < 2 {
    return false
  }

  let row_h = row_max_shape_h(row)
  let spread = row_center_y_spread(row)
  spread > max_int(12, row_h / 3)
}

///|
fn row_center_y_spread(row : Array[LayoutShape]) -> Int {
  if row.length() == 0 {
    return 0
  }

  let mut min_cy = row[0].center_y
  let mut max_cy = row[0].center_y

  for i in 1..<row.length() {
    let cy = row[i].center_y
    if cy < min_cy {
      min_cy = cy
    }
    if cy > max_cy {
      max_cy = cy
    }
  }

  max_cy - min_cy
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

fn text_contains_space(s : String) -> Bool {
  for ch in s.to_array() {
    if ch == ' ' {
      return true
    }
  }
  false
}

///|
fn text_digit_signature(s : String) -> String {
  let out : Array[Char] = []
  for ch in s.to_array() {
    if ch >= '0' && ch <= '9' {
      out.push(ch)
    }
  }
  return out.to_string()
}


///|
fn row_pair_looks_like_cards(
  top : Array[LayoutShape],
  bottom : Array[LayoutShape],
) -> Bool {
  if top.length() == 0 || top.length() != bottom.length() {
    return false
  }

  for i in 0..<top.length() {
    let top_text = normalize_shape_text_for_title(top[i].shape.xml)
    let bottom_text = normalize_shape_text_for_title(bottom[i].shape.xml)

    let top_n = top_text.to_array().length()
    let bottom_n = bottom_text.to_array().length()
    let top_digits = text_digit_signature(top_text)
    let bottom_digits = text_digit_signature(bottom_text)
    let top_has_digit = top_digits != ""
    let bottom_has_digit = bottom_digits != ""

    if top_text == "" || top_n > 24 {
      return false
    }

    if bottom_text == "" {
      return false
    }

    if !(text_contains_space(bottom_text) || bottom_n >= top_n + 4) {
      return false
    }

    if top_has_digit || bottom_has_digit {
      if !top_has_digit || !bottom_has_digit {
        return false
      }
      if top_digits != bottom_digits {
        return false
      }
    }
  }

  true
}

///|
fn looks_like_card_pair_rows(
  rows : Array[Array[LayoutShape]],
) -> Bool {
  if rows.length() < 2 {
    return false
  }

  // allow:
  // - pure card pairs: 2, 4, 6, ...
  // - card pairs + one trailing singleton note row: 3, 5, 7, ...
  let pair_row_count =
    if rows.length() % 2 == 0 {
      rows.length()
    } else {
      let tail = rows[rows.length() - 1]
      if tail.length() != 1 {
        return false
      }
      rows.length() - 1
    }

  if pair_row_count < 2 {
    return false
  }

  let mut i = 0
  while i < pair_row_count {
    if !row_pair_looks_like_cards(rows[i], rows[i + 1]) {
      return false
    }
    i += 2
  }

  true
}

///|
fn append_card_pair_rows_by_columns(
  out : Array[LayoutShape],
  rows : Array[Array[LayoutShape]],
) -> Unit {
  if rows_look_like_two_separated_card_groups(rows) {
    append_two_separated_card_groups(out, rows)
    return
  }

  let pair_row_count =
    if rows.length() % 2 == 0 {
      rows.length()
    } else {
      rows.length() - 1
    }

  let mut i = 0
  while i < pair_row_count {
    let top = rows[i]
    let bottom = rows[i + 1]

    let n = if top.length() < bottom.length() { top.length() } else { bottom.length() }

    for j in 0..<n {
      out.push(top[j])
      out.push(bottom[j])
    }

    if top.length() > n {
      for j in n..<top.length() {
        out.push(top[j])
      }
    }

    if bottom.length() > n {
      for j in n..<bottom.length() {
        out.push(bottom[j])
      }
    }

    i += 2
  }

  // trailing singleton note row
  if rows.length() % 2 != 0 {
    let tail = rows[rows.length() - 1]
    for sp in tail {
      out.push(sp)
    }
  }
}
///|
fn rows_look_like_two_separated_card_groups(
  rows : Array[Array[LayoutShape]],
) -> Bool {
  let pair_row_count =
    if rows.length() % 2 == 0 {
      rows.length()
    } else {
      rows.length() - 1
    }

  if pair_row_count < 4 {
    return false
  }

  let mut left_max_r = 0
  let mut right_min_l = 0
  let mut overall_left = 0
  let mut overall_right = 0
  let mut first = true

  let mut i = 0
  while i < pair_row_count {
    let top = rows[i]
    let bottom = rows[i + 1]

    if top.length() != 2 || bottom.length() != 2 {
      return false
    }

    let cur_left_max_r = max_int(top[0].right, bottom[0].right)
    let cur_right_min_l = min_int(top[1].shape.x, bottom[1].shape.x)

    let cur_left = min_int(
      min_int(top[0].shape.x, bottom[0].shape.x),
      min_int(top[1].shape.x, bottom[1].shape.x),
    )
    let cur_right = max_int(
      max_int(top[0].right, bottom[0].right),
      max_int(top[1].right, bottom[1].right),
    )

    if first {
      left_max_r = cur_left_max_r
      right_min_l = cur_right_min_l
      overall_left = cur_left
      overall_right = cur_right
      first = false
    } else {
      if cur_left_max_r > left_max_r {
        left_max_r = cur_left_max_r
      }
      if cur_right_min_l < right_min_l {
        right_min_l = cur_right_min_l
      }
      if cur_left < overall_left {
        overall_left = cur_left
      }
      if cur_right > overall_right {
        overall_right = cur_right
      }
    }

    i += 2
  }

  let gap = right_min_l - left_max_r
  let span = overall_right - overall_left

  // Use a relative threshold against the total horizontal span.
  // This is much more tolerant than the previous per-pair x-alignment checks.
  gap > max_int(120000, span / 5)
}
///|
fn append_two_separated_card_groups(
  out : Array[LayoutShape],
  rows : Array[Array[LayoutShape]],
) -> Unit {
  let pair_row_count =
    if rows.length() % 2 == 0 {
      rows.length()
    } else {
      rows.length() - 1
    }

  // first emit the left group across all card rows
  let mut i = 0
  while i < pair_row_count {
    let top = rows[i]
    let bottom = rows[i + 1]

    if top.length() > 0 {
      out.push(top[0])
    }
    if bottom.length() > 0 {
      out.push(bottom[0])
    }

    i += 2
  }

  // then emit the right group across all card rows
  i = 0
  while i < pair_row_count {
    let top = rows[i]
    let bottom = rows[i + 1]

    if top.length() > 1 {
      out.push(top[1])
    }
    if bottom.length() > 1 {
      out.push(bottom[1])
    }

    i += 2
  }

  // trailing singleton note row
  if rows.length() % 2 != 0 {
    let tail = rows[rows.length() - 1]
    for sp in tail {
      out.push(sp)
    }
  }
}
