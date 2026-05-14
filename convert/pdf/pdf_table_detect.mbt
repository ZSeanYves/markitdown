///|
pub struct PdfTableCandidate {
  line_start : Int
  line_end : Int
  block_indices : Array[Int]
  rows : Array[Array[String]]
  header_rows : Int
  reason_tags : Array[String]
}

///|
priv struct PdfTableCellBlock {
  block_index : Int
  line_index : Int
  text : String
  bbox : @model.PdfRect
  center_y : Double
  left_x : Double
}

///|
pub fn detect_pdf_tables(
  page : PdfConvertPage,
  pipeline_debug : Bool,
) -> Array[PdfTableCandidate] {
  let cells = collect_pdf_table_cell_blocks(page)
  let rows = cluster_pdf_table_rows(cells)
  let candidates = finalize_pdf_table_rows(page, rows)

  if pipeline_debug {
    for candidate in candidates {
      println(
        "[pdf-table] page=" +
        (page._page_index + 1).to_string() +
        " lines=" +
        (candidate.line_start + 1).to_string() +
        "-" +
        (candidate.line_end + 1).to_string() +
        " status=matched rows=" +
        candidate.rows.length().to_string() +
        " cols=" +
        candidate.rows[0].length().to_string() +
        " reasons=" +
        candidate.reason_tags.join(","),
      )
    }
  }

  candidates
}

///|
fn collect_pdf_table_cell_blocks(
  page : PdfConvertPage,
) -> Array[PdfTableCellBlock] {
  let out : Array[PdfTableCellBlock] = []
  for block in page.blocks {
    let text = normalize_pdf_comparison_text(block.text)
    if text == "" {
      continue
    }
    if block.kind != PdfConvertBlockKind::Paragraph &&
      block.kind != PdfConvertBlockKind::Heading {
      continue
    }
    if block.is_artifact_candidate ||
      block.is_caption_candidate ||
      block.first_is_wrapped_candidate ||
      block.last_is_wrapped_candidate ||
      block.first_is_same_paragraph_with_prev_candidate ||
      block.last_is_same_paragraph_with_prev_candidate {
      continue
    }
    if (block.is_noise_candidate || block.is_header_footer_candidate) &&
      !allow_numeric_table_candidate_block(page, block, text) {
      continue
    }
    if looks_like_paragraph_table_reject_block(text) ||
      looks_like_list_like_table_reject_block(text) ||
      looks_like_toc_like_table_reject_block(text) ||
      looks_like_caption_like_table_reject_block(text) {
      continue
    }
    out.push({
      block_index: block.block_index,
      line_index: block.line_start,
      text,
      bbox: block._bbox,
      center_y: pdf_table_block_row_y(block),
      left_x: block.left_x,
    })
  }

  let sorted : Array[PdfTableCellBlock] = []
  for cell in out {
    insert_pdf_table_cell_sorted(sorted, cell)
  }
  sorted
}

///|
fn pdf_table_block_row_y(block : PdfConvertBlock) -> Double {
  match block.first_baseline_y {
    Some(y) => y
    None => (block._bbox.y0 + block._bbox.y1) / 2.0
  }
}

///|
fn allow_numeric_table_candidate_block(
  page : PdfConvertPage,
  block : PdfConvertBlock,
  text : String,
) -> Bool {
  if !looks_like_numeric_table_cell(text) {
    return false
  }

  if normalize_pdf_comparison_text(block.text).length() > 8 {
    return false
  }

  match page.media_box {
    Some(box) => {
      let page_height = @model.rect_height(box)
      if page_height <= 0.0 {
        return false
      }

      let top_margin = box.y1 - edge_zone_height_for_pdf_table(page_height)
      let bottom_margin = box.y0 + edge_zone_height_for_pdf_table(page_height)
      if block._bbox.y1 >= top_margin || block._bbox.y0 <= bottom_margin {
        return false
      }
    }
    None => return false
  }

  true
}

///|
fn edge_zone_height_for_pdf_table(page_height : Double) -> Double {
  let zone = page_height * 0.12
  if zone < 48.0 {
    return 48.0
  }
  if zone > 120.0 {
    return 120.0
  }
  zone
}

///|
fn insert_pdf_table_cell_sorted(
  out : Array[PdfTableCellBlock],
  cell : PdfTableCellBlock,
) -> Unit {
  let tmp : Array[PdfTableCellBlock] = []
  let mut placed = false
  for existing in out {
    if !placed && compare_pdf_table_cells(cell, existing) < 0 {
      tmp.push(cell)
      placed = true
    }
    tmp.push(existing)
  }
  if !placed {
    tmp.push(cell)
  }
  out.clear()
  for x in tmp {
    out.push(x)
  }
}

///|
fn compare_pdf_table_cells(a : PdfTableCellBlock, b : PdfTableCellBlock) -> Int {
  if !same_pdf_table_row(a, b) {
    if a.center_y > b.center_y {
      return -1
    } else {
      return 1
    }
  }

  if a.left_x < b.left_x {
    -1
  } else if a.left_x > b.left_x {
    1
  } else {
    0
  }
}

///|
fn same_pdf_table_row(a : PdfTableCellBlock, b : PdfTableCellBlock) -> Bool {
  let dy = abs_table_f64(a.center_y - b.center_y)
  if dy <= 4.0 {
    return true
  }

  let overlap = pdf_table_vertical_overlap(a.bbox, b.bbox)
  let min_height = min_table_f64(
    @model.rect_height(a.bbox),
    @model.rect_height(b.bbox),
  )
  min_height > 0.0 && overlap / min_height >= 0.55
}

///|
fn pdf_table_vertical_overlap(a : @model.PdfRect, b : @model.PdfRect) -> Double {
  let top = min_table_f64(a.y1, b.y1)
  let bottom = max_table_f64(a.y0, b.y0)
  if top > bottom {
    top - bottom
  } else {
    0.0
  }
}

///|
fn cluster_pdf_table_rows(
  cells : Array[PdfTableCellBlock],
) -> Array[Array[PdfTableCellBlock]] {
  let rows : Array[Array[PdfTableCellBlock]] = []
  for cell in cells {
    if rows.is_empty() {
      rows.push([cell])
      continue
    }

    let last = rows[rows.length() - 1]
    let ref_cell = last[0]
    if same_pdf_table_row(ref_cell, cell) {
      last.push(cell)
    } else {
      rows.push([cell])
    }
  }

  let out : Array[Array[PdfTableCellBlock]] = []
  for row in rows {
    if row.length() >= 2 {
      out.push(sort_pdf_table_row(row))
    }
  }
  out
}

///|
fn sort_pdf_table_row(
  row : Array[PdfTableCellBlock],
) -> Array[PdfTableCellBlock] {
  let out : Array[PdfTableCellBlock] = []
  for cell in row {
    let tmp : Array[PdfTableCellBlock] = []
    let mut placed = false
    for existing in out {
      if !placed && cell.left_x < existing.left_x {
        tmp.push(cell)
        placed = true
      }
      tmp.push(existing)
    }
    if !placed {
      tmp.push(cell)
    }
    out.clear()
    for x in tmp {
      out.push(x)
    }
  }
  out
}

///|
fn finalize_pdf_table_rows(
  page : PdfConvertPage,
  rows : Array[Array[PdfTableCellBlock]],
) -> Array[PdfTableCandidate] {
  let out : Array[PdfTableCandidate] = []
  let mut i = 0

  while i < rows.length() {
    let first = rows[i]
    if first.length() < 2 {
      i = i + 1
      continue
    }

    let run : Array[Array[PdfTableCellBlock]] = [first]
    let anchor_positions = row_pdf_table_anchor_positions(first)
    if anchor_positions.length() < 2 {
      i = i + 1
      continue
    }
    let anchor_ref : Ref[Array[Double]] = { val: anchor_positions }
    let mut j = i + 1
    while j < rows.length() {
      let next = rows[j]
      match
        next_pdf_table_anchor_positions(
          anchor_ref.val,
          run[run.length() - 1],
          next,
        ) {
        Some(merged) => {
          anchor_ref.val = merged
          run.push(next)
          j = j + 1
        }
        None => break
      }
    }

    match build_pdf_table_candidate(page, run, anchor_ref.val) {
      Some(table) => {
        out.push(table)
        i = j
      }
      None => i = i + 1
    }
  }

  out
}

///|
fn next_pdf_table_anchor_positions(
  anchor_positions : Array[Double],
  left : Array[PdfTableCellBlock],
  right : Array[PdfTableCellBlock],
) -> Array[Double]? {
  if anchor_positions.length() < 2 || left.length() < 2 || right.length() < 2 {
    return None
  }

  let merged = match merge_pdf_table_anchor_positions(anchor_positions, right) {
    Some(value) => value
    None => return None
  }

  let left_y = left[0].center_y
  let right_y = right[0].center_y
  let dy = abs_table_f64(left_y - right_y)
  if dy > 32.0 {
    return None
  }

  let left_height = pdf_table_row_height(left)
  let right_height = pdf_table_row_height(right)
  let height_gap = abs_table_f64(left_height - right_height)
  if height_gap > max_table_f64(10.0, max_table_f64(left_height, right_height)) {
    return None
  }

  Some(merged)
}

///|
fn row_pdf_table_anchor_positions(
  row : Array[PdfTableCellBlock],
) -> Array[Double] {
  let out : Array[Double] = []
  for cell in row {
    match merge_single_pdf_table_anchor_position(out, cell.left_x) {
      Some(merged) => {
        out.clear()
        for x in merged {
          out.push(x)
        }
      }
      None => return []
    }
  }
  out
}

///|
fn merge_pdf_table_anchor_positions(
  anchor_positions : Array[Double],
  row : Array[PdfTableCellBlock],
) -> Array[Double]? {
  let merged : Array[Double] = []
  for x in anchor_positions {
    merged.push(x)
  }
  for cell in row {
    match merge_single_pdf_table_anchor_position(merged, cell.left_x) {
      Some(next) => {
        merged.clear()
        for x in next {
          merged.push(x)
        }
      }
      None => return None
    }
  }

  if pdf_table_row_anchor_indices_for_positions(merged, row) is None {
    None
  } else {
    Some(merged)
  }
}

///|
fn merge_single_pdf_table_anchor_position(
  anchor_positions : Array[Double],
  x : Double,
) -> Array[Double]? {
  let out : Array[Double] = []
  let mut inserted = false
  let mut merged_existing = false

  for anchor in anchor_positions {
    let dx = abs_table_f64(anchor - x)
    if dx <= 32.0 {
      if merged_existing {
        return None
      }
      out.push((anchor + x) / 2.0)
      inserted = true
      merged_existing = true
      continue
    }

    if !inserted && x < anchor {
      out.push(x)
      inserted = true
    }
    out.push(anchor)
  }

  if !inserted {
    out.push(x)
  }

  if out.length() > 6 {
    None
  } else {
    Some(out)
  }
}

///|
fn build_pdf_table_candidate(
  page : PdfConvertPage,
  run : Array[Array[PdfTableCellBlock]],
  anchor_positions : Array[Double],
) -> PdfTableCandidate? {
  if run.length() < 2 {
    return None
  }

  let col_count = anchor_positions.length()
  if col_count < 2 {
    return None
  }

  let mut bbox = run[0][0].bbox
  let rows : Array[Array[String]] = []
  let block_indices : Array[Int] = []
  let mut line_start = run[0][0].line_index
  let mut line_end = run[0][0].line_index
  for row in run {
    let texts = match normalize_pdf_table_row(anchor_positions, row) {
      Some(value) => value
      None => return None
    }
    for cell in row {
      block_indices.push(cell.block_index)
      bbox = @model.union_rect(bbox, cell.bbox)
      if cell.line_index < line_start {
        line_start = cell.line_index
      }
      if cell.line_index > line_end {
        line_end = cell.line_index
      }
    }
    rows.push(texts)
  }

  if table_region_overlaps_images(page.images, bbox) {
    return None
  }

  if looks_like_two_column_table_false_positive(page, run, bbox) {
    return None
  }

  if looks_like_paragraphish_table_region(run) {
    return None
  }

  if looks_like_list_like_table_region(run) {
    return None
  }

  if looks_like_toc_like_table_region(run) {
    return None
  }

  if looks_like_caption_like_table_region(run) {
    return None
  }

  Some({
    line_start,
    line_end,
    block_indices,
    rows,
    header_rows: infer_pdf_table_header_rows(rows),
    reason_tags: ["stable_columns", "aligned_rows", "min_rows", "min_cols"],
  })
}

///|
fn pdf_table_row_anchor_indices_for_positions(
  anchor_positions : Array[Double],
  row : Array[PdfTableCellBlock],
) -> Array[Int]? {
  if row.length() > anchor_positions.length() {
    return None
  }

  let out : Array[Int] = []
  let mut anchor_start = 0
  for cell in row {
    let matched = match
      find_pdf_table_anchor_position_index(
        anchor_positions,
        cell.left_x,
        anchor_start,
      ) {
      Some(value) => value
      None => return None
    }
    out.push(matched)
    anchor_start = matched + 1
  }
  Some(out)
}

///|
fn find_pdf_table_anchor_position_index(
  anchor_positions : Array[Double],
  cell_left_x : Double,
  anchor_start : Int,
) -> Int? {
  let mut best_idx = -1
  let mut best_dx = 0.0
  for i in anchor_start..<anchor_positions.length() {
    let dx = abs_table_f64(anchor_positions[i] - cell_left_x)
    if dx <= 32.0 && (best_idx < 0 || dx < best_dx) {
      best_idx = i
      best_dx = dx
    }
  }
  if best_idx < 0 {
    None
  } else {
    Some(best_idx)
  }
}

///|
fn normalize_pdf_table_row(
  anchor_positions : Array[Double],
  row : Array[PdfTableCellBlock],
) -> Array[String]? {
  let anchor_indices = match
    pdf_table_row_anchor_indices_for_positions(anchor_positions, row) {
    Some(value) => value
    None => return None
  }
  let out : Array[String] = []
  for _ in 0..<anchor_positions.length() {
    out.push("")
  }
  for i in 0..<row.length() {
    out[anchor_indices[i]] = normalize_pdf_table_cell_text(row[i].text)
  }
  Some(out)
}

///|
fn infer_pdf_table_header_rows(rows : Array[Array[String]]) -> Int {
  if rows.length() < 2 {
    return 0
  }

  let first = rows[0]
  let second = rows[1]
  let first_numeric = count_numeric_like_cells(first)
  let second_numeric = count_numeric_like_cells(second)
  if first_numeric == 0 && second_numeric > 0 {
    return 1
  }
  if count_short_label_cells(first) * 2 >= first.length() {
    return 1
  }
  0
}

///|
fn count_numeric_like_cells(row : Array[String]) -> Int {
  let mut out = 0
  for cell in row {
    if looks_like_numeric_table_cell(cell) {
      out = out + 1
    }
  }
  out
}

///|
fn looks_like_numeric_table_cell(text : String) -> Bool {
  let t = normalize_pdf_comparison_text(text)
  if t == "" {
    return false
  }
  let mut digit = 0
  let mut other = 0
  for ch in t.to_array() {
    if ch >= '0' && ch <= '9' {
      digit = digit + 1
    } else if ch == '.' ||
      ch == ',' ||
      ch == '%' ||
      ch == '-' ||
      ch == '+' ||
      ch == ' ' {
      ()
    } else {
      other = other + 1
    }
  }
  digit > 0 && other == 0
}

///|
fn normalize_pdf_table_cell_text(text : String) -> String {
  if !looks_like_numeric_table_cell(text) {
    return text
  }

  let chars = text.to_array()
  if chars.length() < 3 {
    return text
  }

  let sign = chars[0]
  if sign != '+' && sign != '-' {
    return text
  }

  let mut index = 1
  let mut saw_space = false
  while index < chars.length() && chars[index] == ' ' {
    saw_space = true
    index = index + 1
  }

  if !saw_space || index >= chars.length() {
    return text
  }

  let next = chars[index]
  if !(next >= '0' && next <= '9') && next != '.' {
    return text
  }

  sign.to_string() + text[index:].to_owned()
}

///|
fn count_short_label_cells(row : Array[String]) -> Int {
  let mut out = 0
  for cell in row {
    let t = normalize_pdf_comparison_text(cell)
    if t != "" &&
      t.length() <= 24 &&
      !ends_like_sentence_for_pdf_table(t) &&
      !looks_like_numeric_table_cell(t) {
      out = out + 1
    }
  }
  out
}

///|
fn looks_like_paragraph_table_reject_block(text : String) -> Bool {
  let t = normalize_pdf_comparison_text(text)
  if t == "" {
    return true
  }
  if @text.looks_like_intro_phrase(t) {
    return true
  }
  let words = pdf_table_word_count(t)
  if words >= 14 {
    return true
  }
  if ends_like_sentence_for_pdf_table(t) && words >= 6 {
    return true
  }
  false
}

///|
fn looks_like_list_like_table_reject_block(text : String) -> Bool {
  let t = normalize_pdf_comparison_text(text)
  if t == "" {
    return false
  }
  if looks_like_numeric_table_cell(t) {
    return false
  }

  t.has_prefix("- ") ||
  t.has_prefix("* ") ||
  t.has_prefix("\u{2022} ") ||
  starts_with_numbered_table_bullet(t)
}

///|
fn starts_with_numbered_table_bullet(text : String) -> Bool {
  let chars = text.to_array()
  if chars.length() < 4 {
    return false
  }

  let mut i = 0
  let mut saw_digit = false
  while i < chars.length() {
    let ch = chars[i]
    if ch >= '0' && ch <= '9' {
      saw_digit = true
      i += 1
      continue
    }
    break
  }

  if !saw_digit || i >= chars.length() {
    return false
  }

  if !(chars[i] == '.' || chars[i] == ')' || chars[i] == '\u{3001}') ||
    i + 1 >= chars.length() {
    return false
  }

  let next = chars[i + 1]
  is_space_like_table_char(next)
}

///|
fn is_space_like_table_char(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}

///|
fn looks_like_toc_like_table_reject_block(text : String) -> Bool {
  let t = normalize_pdf_comparison_text(text)
  t.contains("....") || t.contains(". . . .") || t.contains("\u{2026}")
}

///|
fn looks_like_caption_like_table_reject_block(text : String) -> Bool {
  let t = normalize_pdf_comparison_text(text)
  let lower = t.to_lower()
  lower.has_prefix("figure ") ||
  lower.has_prefix("fig. ") ||
  lower.has_prefix("table ") ||
  t.has_prefix("图 ") ||
  t.has_prefix("图") ||
  t.has_prefix("表 ")
}

///|
fn ends_like_sentence_for_pdf_table(text : String) -> Bool {
  let t = normalize_pdf_comparison_text(text)
  t.has_suffix(".") ||
  t.has_suffix("!") ||
  t.has_suffix("?") ||
  t.has_suffix("。") ||
  t.has_suffix("！") ||
  t.has_suffix("？")
}

///|
fn pdf_table_word_count(text : String) -> Int {
  let mut count = 0
  let mut in_word = false
  for ch in normalize_pdf_comparison_text(text).to_array() {
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      if in_word {
        in_word = false
      }
    } else if !in_word {
      count = count + 1
      in_word = true
    }
  }
  count
}

///|
fn table_region_overlaps_images(
  images : Array[PdfConvertImage],
  bbox : @model.PdfRect,
) -> Bool {
  for image in images {
    if rects_overlap_or_near_table(bbox, image._bbox, 8.0) {
      return true
    }
  }
  false
}

///|
fn looks_like_two_column_table_false_positive(
  page : PdfConvertPage,
  run : Array[Array[PdfTableCellBlock]],
  bbox : @model.PdfRect,
) -> Bool {
  if run.is_empty() || run[0].length() != 2 {
    return false
  }
  let page_box = match page.media_box {
    Some(box) => box
    None => return false
  }
  let page_width = @model.rect_width(page_box)
  let region_width = @model.rect_width(bbox)
  if page_width <= 0.0 || region_width < page_width * 0.75 {
    return false
  }
  let mut longish_cells = 0
  for row in run {
    for cell in row {
      if pdf_table_word_count(cell.text) >= 5 {
        longish_cells = longish_cells + 1
      }
    }
  }
  longish_cells >= run.length() * 2
}

///|
fn looks_like_paragraphish_table_region(
  run : Array[Array[PdfTableCellBlock]],
) -> Bool {
  let mut longish = 0
  let mut sentence_like = 0
  let mut total = 0
  for row in run {
    for cell in row {
      total += 1
      let words = pdf_table_word_count(cell.text)
      if words >= 6 {
        longish += 1
      }
      if ends_like_sentence_for_pdf_table(cell.text) {
        sentence_like += 1
      }
    }
  }

  if total == 0 {
    return false
  }

  longish * 2 >= total || sentence_like * 2 >= total
}

///|
fn looks_like_list_like_table_region(
  run : Array[Array[PdfTableCellBlock]],
) -> Bool {
  let mut list_like = 0
  let mut total = 0
  for row in run {
    for cell in row {
      total += 1
      if looks_like_list_like_table_reject_block(cell.text) {
        list_like += 1
      }
    }
  }
  total > 0 && list_like * 2 >= total
}

///|
fn looks_like_toc_like_table_region(
  run : Array[Array[PdfTableCellBlock]],
) -> Bool {
  let mut toc_like = 0
  let mut total = 0
  for row in run {
    for cell in row {
      total += 1
      if looks_like_toc_like_table_reject_block(cell.text) {
        toc_like += 1
      }
    }
  }
  total > 0 && toc_like * 2 >= total
}

///|
fn looks_like_caption_like_table_region(
  run : Array[Array[PdfTableCellBlock]],
) -> Bool {
  let mut caption_like = 0
  let mut total = 0
  for row in run {
    for cell in row {
      total += 1
      if looks_like_caption_like_table_reject_block(cell.text) {
        caption_like += 1
      }
    }
  }
  total > 0 && caption_like * 2 >= total
}

///|
fn pdf_table_row_height(row : Array[PdfTableCellBlock]) -> Double {
  if row.is_empty() {
    return 0.0
  }

  let mut top = row[0].bbox.y0
  let mut bottom = row[0].bbox.y1
  for cell in row {
    if cell.bbox.y0 < top {
      top = cell.bbox.y0
    }
    if cell.bbox.y1 > bottom {
      bottom = cell.bbox.y1
    }
  }
  bottom - top
}

///|
fn rects_overlap_or_near_table(
  a : @model.PdfRect,
  b : @model.PdfRect,
  gap : Double,
) -> Bool {
  !(a.x1 + gap < b.x0 ||
  b.x1 + gap < a.x0 ||
  a.y1 + gap < b.y0 ||
  b.y1 + gap < a.y0)
}

///|
fn abs_table_f64(v : Double) -> Double {
  if v < 0.0 {
    -v
  } else {
    v
  }
}

///|
fn min_table_f64(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn max_table_f64(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}
