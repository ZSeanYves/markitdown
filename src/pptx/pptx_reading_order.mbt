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

  if is_two_columns(body_shapes) {
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
      ShapeGroupKind::Normal | ShapeGroupKind::CaptionLike =>
        for sp in g.shapes {
          out.push(sp)
        }
    }
  }

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

  // first: if the new shape vertically overlaps with any existing item
  // in the row, it is very likely still the same visual row.
  for item in row {
    if vertical_overlap(item, sp) > 0 {
      return true
    }
  }

  // fallback: row-center band check
  let row_cy = row_center_y(row)
  let row_h = row_max_shape_h(row)
  let sp_h = if sp.shape.h > 0 { sp.shape.h } else { 1 }

  let maxh = max_int(row_h, sp_h)
  let threshold = max_int(12, maxh)

  let dy = abs_int(row_cy - sp.center_y)
  if dy > threshold {
    return false
  }

  true
} ///|

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

///|
fn text_contains_digit(s : String) -> Bool {
  for ch in s.to_array() {
    if ch >= '0' && ch <= '9' {
      return true
    }
  }
  false
}

///|
fn text_contains_space(s : String) -> Bool {
  for ch in s.to_array() {
    if ch == ' ' {
      return true
    }
  }
  false
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

    if top_text == "" || top_n > 24 || text_contains_digit(top_text) {
      return false
    }

    if bottom_text == "" || text_contains_digit(bottom_text) {
      return false
    }

    if !(text_contains_space(bottom_text) || bottom_n >= top_n + 4) {
      return false
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