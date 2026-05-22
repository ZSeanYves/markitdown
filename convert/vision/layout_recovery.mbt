///|
pub fn recover_ocr_layout_page(page : OcrPageModel) -> OcrLayoutPage {
  let warnings : Array[String] = []
  for warning in page.warnings {
    warnings.push(warning)
  }

  let filtered = nonblank_ocr_lines(page.lines)
  if detect_two_column_line_groups(filtered) is Some(_) {
    warnings.push("two-column reading order applied")
  }

  let ordered = order_ocr_lines_for_reading(page)
  let ordered_geometry = lines_have_known_geometry(ordered)
  if ordered.length() > 0 && !ordered_geometry {
    warnings.push("missing geometry: reading order kept line_index order")
  }

  let grouped = group_ordered_lines_into_layout_blocks(ordered, page)
  if ordered.length() > 0 && !ordered_geometry {
    warnings.push("missing geometry: conservative paragraph split")
  }

  let classified = classify_ocr_layout_blocks(grouped, page)
  {
    page_index: page.page_index,
    blocks: classified,
    warnings: dedupe_layout_warnings(warnings),
  }
}

///|
pub fn order_ocr_lines_for_reading(page : OcrPageModel) -> Array[OcrSignalLine] {
  let filtered = nonblank_ocr_lines(page.lines)
  if filtered.length() == 0 {
    return filtered
  }
  if !lines_have_known_geometry(filtered) {
    filtered.sort_by(fn(a, b) { a.line_index - b.line_index })
    return filtered
  }
  match detect_two_column_line_groups(filtered) {
    Some(groups) => {
      let ordered : Array[OcrSignalLine] = []
      let left = groups.left
      let right = groups.right
      left.sort_by(compare_lines_by_column_then_y)
      right.sort_by(compare_lines_by_column_then_y)
      for line in left {
        ordered.push(line)
      }
      for line in right {
        ordered.push(line)
      }
      return ordered
    }
    None => ()
  }
  filtered.sort_by(compare_lines_by_geometry)
  filtered
}

///|
pub fn group_ordered_lines_into_paragraphs(
  lines : Array[OcrSignalLine],
) -> Array[OcrLayoutBlock] {
  let filtered = nonblank_ocr_lines(lines)
  let blocks : Array[OcrLayoutBlock] = []
  if filtered.length() == 0 {
    return blocks
  }

  let mut current = make_layout_block_from_line(filtered[0])
  let all_geometry = lines_have_known_geometry(filtered)
  if !all_geometry {
    current = block_with_reasons(current, [
      "unknown geometry: conservative split",
    ])
  }

  for i in 1..<filtered.length() {
    let line = filtered[i]
    if !all_geometry {
      blocks.push(current)
      current = make_layout_block_from_line(line)
      current = block_with_reasons(current, [
        "unknown geometry: conservative split",
      ])
      continue
    }

    let previous_line = filtered[i - 1]
    let gap = line.bbox.y - bbox_bottom(previous_line.bbox)
    let left_delta = double_abs(line.bbox.x - previous_line.bbox.x)
    if gap <= paragraph_max_vertical_gap() &&
      left_delta <= paragraph_max_left_delta() {
      current = append_line_to_layout_block(current, line)
    } else {
      blocks.push(finalize_layout_block(current))
      current = make_layout_block_from_line(line)
    }
  }

  blocks.push(finalize_layout_block(current))
  blocks
}

///|
fn group_ordered_lines_into_layout_blocks(
  lines : Array[OcrSignalLine],
  page : OcrPageModel,
) -> Array[OcrLayoutBlock] {
  let filtered = nonblank_ocr_lines(lines)
  if filtered.length() == 0 {
    return []
  }
  if !lines_have_known_geometry(filtered) {
    return group_ordered_lines_into_paragraphs(filtered)
  }

  let blocks : Array[OcrLayoutBlock] = []
  let mut index = 0
  while index < filtered.length() {
    match detect_table_like_run(filtered, index, page) {
      Some(run) => {
        blocks.push(make_table_like_layout_block(run))
        index = index + run.length()
      }
      None => {
        let paragraph_start = index
        index = index + 1
        while index < filtered.length() {
          if detect_table_like_run(filtered, index, page) is Some(_) {
            break
          }
          index = index + 1
        }
        let paragraph_lines : Array[OcrSignalLine] = []
        for i in paragraph_start..<index {
          paragraph_lines.push(filtered[i])
        }
        for block in group_ordered_lines_into_paragraphs(paragraph_lines) {
          blocks.push(block)
        }
      }
    }
  }
  blocks
}

///|
pub fn classify_ocr_layout_blocks(
  blocks : Array[OcrLayoutBlock],
  page : OcrPageModel,
) -> Array[OcrLayoutBlock] {
  let out : Array[OcrLayoutBlock] = []
  for block in blocks {
    out.push(classify_ocr_layout_block(block, page))
  }
  out
}

///|
pub fn classify_ocr_layout_block(
  block : OcrLayoutBlock,
  page : OcrPageModel,
) -> OcrLayoutBlock {
  let trimmed = block.text.trim().to_owned()
  if trimmed == "" {
    return block_with_kind_and_reasons(
      block,
      OcrLayoutBlockKind::Noise,
      block.reasons + ["empty block noise"],
    )
  }

  if block.kind == OcrLayoutBlockKind::TableLike {
    return block_with_kind_and_reasons(
      block,
      OcrLayoutBlockKind::TableLike,
      block.reasons,
    )
  }

  let noise_reasons = noise_candidate_reasons(trimmed)
  if noise_reasons.length() > 0 {
    return block_with_kind_and_reasons(
      block,
      OcrLayoutBlockKind::Noise,
      block.reasons + noise_reasons,
    )
  }

  let table_like_reasons = table_like_candidate_reasons(block, page)
  if table_like_reasons.length() > 0 {
    return block_with_kind_and_reasons(
      block,
      OcrLayoutBlockKind::TableLike,
      block.reasons + table_like_reasons,
    )
  }

  let heading_reasons = heading_candidate_reasons(block, page)
  if heading_reasons.length() > 0 {
    return block_with_kind_and_reasons(
      block,
      OcrLayoutBlockKind::Heading,
      block.reasons + heading_reasons,
    )
  }

  let list_reasons = list_item_candidate_reasons(trimmed)
  if list_reasons.length() > 0 {
    return block_with_kind_and_reasons(
      block,
      OcrLayoutBlockKind::ListItem,
      block.reasons + list_reasons,
    )
  }

  block_with_kind_and_reasons(
    block,
    OcrLayoutBlockKind::Paragraph,
    block.reasons,
  )
}

///|
fn make_layout_block_from_line(line : OcrSignalLine) -> OcrLayoutBlock {
  {
    kind: OcrLayoutBlockKind::Paragraph,
    text: line.text.trim().to_owned(),
    bbox: line.bbox,
    confidence: if line.confidence >= 0.0 {
      line.confidence
    } else {
      -1.0
    },
    line_indices: [line.line_index],
    reasons: ["single-line paragraph"],
  }
}

///|
fn append_line_to_layout_block(
  block : OcrLayoutBlock,
  line : OcrSignalLine,
) -> OcrLayoutBlock {
  let line_text = line.text.trim().to_owned()
  let next_text = if line_text == "" {
    block.text
  } else if block.text == "" {
    line_text
  } else {
    block.text + " " + line_text
  }
  let next_reasons = if block.reasons.contains(
      "unknown geometry: conservative split",
    ) {
    block.reasons
  } else {
    ["merged by vertical gap"]
  }
  {
    kind: block.kind,
    text: next_text,
    bbox: bbox_union(block.bbox, line.bbox),
    confidence: average_confidence_with_line(block, line),
    line_indices: block.line_indices + [line.line_index],
    reasons: next_reasons,
  }
}

///|
fn block_with_reasons(
  block : OcrLayoutBlock,
  reasons : Array[String],
) -> OcrLayoutBlock {
  {
    kind: block.kind,
    text: block.text,
    bbox: block.bbox,
    confidence: block.confidence,
    line_indices: block.line_indices,
    reasons,
  }
}

///|
fn block_with_kind_and_reasons(
  block : OcrLayoutBlock,
  kind : OcrLayoutBlockKind,
  reasons : Array[String],
) -> OcrLayoutBlock {
  {
    kind,
    text: block.text,
    bbox: block.bbox,
    confidence: block.confidence,
    line_indices: block.line_indices,
    reasons: dedupe_layout_warnings(reasons),
  }
}

///|
fn finalize_layout_block(block : OcrLayoutBlock) -> OcrLayoutBlock {
  if block.reasons.contains("unknown geometry: conservative split") {
    return block
  }
  if block.line_indices.length() > 1 {
    return block_with_reasons(block, ["merged by vertical gap"])
  }
  block_with_reasons(block, ["single-line paragraph"])
}

///|
fn average_confidence_with_line(
  block : OcrLayoutBlock,
  line : OcrSignalLine,
) -> Double {
  let known_values : Array[Double] = []
  if block.confidence >= 0.0 {
    known_values.push(block.confidence)
  }
  if line.confidence >= 0.0 {
    known_values.push(line.confidence)
  }
  if known_values.length() == 0 {
    -1.0
  } else {
    let mut total = 0.0
    for value in known_values {
      total = total + value
    }
    total / known_values.length().to_double()
  }
}

///|
fn average_confidence_for_lines(lines : Array[OcrSignalLine]) -> Double {
  let known_values : Array[Double] = []
  for line in lines {
    if line.confidence >= 0.0 {
      known_values.push(line.confidence)
    }
  }
  if known_values.length() == 0 {
    return -1.0
  }
  let mut total = 0.0
  for value in known_values {
    total = total + value
  }
  total / known_values.length().to_double()
}

///|
fn nonblank_ocr_lines(lines : Array[OcrSignalLine]) -> Array[OcrSignalLine] {
  let out : Array[OcrSignalLine] = []
  for line in lines {
    if line.text.trim() != "" {
      out.push(line)
    }
  }
  out
}

///|
fn lines_have_known_geometry(lines : Array[OcrSignalLine]) -> Bool {
  if lines.length() == 0 {
    return false
  }
  for line in lines {
    if !bbox_is_valid(line.bbox) {
      return false
    }
  }
  true
}

///|
fn compare_lines_by_geometry(a : OcrSignalLine, b : OcrSignalLine) -> Int {
  if a.bbox.y < b.bbox.y {
    return -1
  }
  if a.bbox.y > b.bbox.y {
    return 1
  }
  if a.bbox.x < b.bbox.x {
    return -1
  }
  if a.bbox.x > b.bbox.x {
    return 1
  }
  a.line_index - b.line_index
}

///|
priv struct TwoColumnLineGroups {
  left : Array[OcrSignalLine]
  right : Array[OcrSignalLine]
}

///|
fn detect_two_column_line_groups(
  lines : Array[OcrSignalLine],
) -> TwoColumnLineGroups? {
  detect_column_like_line_groups(lines, false)
}

///|
fn detect_column_like_line_groups(
  lines : Array[OcrSignalLine],
  ignore_table_like_guard : Bool,
) -> TwoColumnLineGroups? {
  if lines.length() < 4 {
    return None
  }
  if !lines_have_known_geometry(lines) {
    return None
  }
  if !ignore_table_like_guard && looks_like_table_candidate_line_group(lines) {
    return None
  }

  let sorted = lines.copy()
  sorted.sort_by(compare_lines_by_x_then_y)
  let split_index = best_two_column_split(sorted)
  if split_index < 2 || split_index > sorted.length() - 2 {
    return None
  }

  let left : Array[OcrSignalLine] = []
  let right : Array[OcrSignalLine] = []
  for i in 0..<sorted.length() {
    if i < split_index {
      left.push(sorted[i])
    } else {
      right.push(sorted[i])
    }
  }
  if left.length() < 2 || right.length() < 2 {
    return None
  }
  if !column_cluster_is_stable(left) || !column_cluster_is_stable(right) {
    return None
  }
  if !column_gap_is_large(left, right) {
    return None
  }
  if !column_y_ranges_overlap(left, right) {
    return None
  }
  Some({ left, right })
}

///|
fn compare_lines_by_x_then_y(a : OcrSignalLine, b : OcrSignalLine) -> Int {
  if a.bbox.x < b.bbox.x {
    return -1
  }
  if a.bbox.x > b.bbox.x {
    return 1
  }
  if a.bbox.y < b.bbox.y {
    return -1
  }
  if a.bbox.y > b.bbox.y {
    return 1
  }
  a.line_index - b.line_index
}

///|
fn compare_lines_by_column_then_y(a : OcrSignalLine, b : OcrSignalLine) -> Int {
  if a.bbox.y < b.bbox.y {
    return -1
  }
  if a.bbox.y > b.bbox.y {
    return 1
  }
  if a.bbox.x < b.bbox.x {
    return -1
  }
  if a.bbox.x > b.bbox.x {
    return 1
  }
  a.line_index - b.line_index
}

///|
fn heading_candidate_reasons(
  block : OcrLayoutBlock,
  page : OcrPageModel,
) -> Array[String] {
  let text = block.text.trim().to_owned()
  if text == "" {
    return []
  }
  if block.line_indices.length() != 1 {
    return []
  }
  if noise_candidate_reasons(text).length() > 0 {
    return []
  }
  let numbered_heading = looks_numbered_heading(text)
  if list_item_candidate_reasons(text).length() > 0 && !numbered_heading {
    return []
  }
  if text.length() > 80 || has_body_punctuation_tail(text) {
    return []
  }
  if looks_like_amount_line(text) || looks_like_date_line(text) {
    return []
  }
  if !looks_heading_like_text(text) {
    return []
  }
  if page_has_column_like_heading_guard_context(page) &&
    !numbered_heading &&
    looks_like_column_label_text(text) {
    return []
  }

  let reasons : Array[String] = []
  if numbered_heading {
    reasons.push("numbered heading pattern")
  } else if !bbox_is_valid(block.bbox) {
    return []
  } else if !page_has_known_geometry(page) {
    return []
  } else if is_upper_page_heading_candidate(block, page) {
    reasons.push("single-line heading candidate")
  } else {
    return []
  }
  reasons
}

///|
fn table_like_candidate_reasons(
  block : OcrLayoutBlock,
  page : OcrPageModel,
) -> Array[String] {
  if block.kind == OcrLayoutBlockKind::TableLike {
    return block.reasons
  }
  if block.line_indices.length() < 3 {
    return []
  }
  let lines = resolve_layout_block_lines(block, page)
  if lines.length() != block.line_indices.length() {
    return []
  }
  if !lines_have_known_geometry(lines) {
    return []
  }
  if !looks_like_table_candidate_line_group(lines) {
    return []
  }
  ["table-like rows", "aligned column candidate"]
}

///|
fn list_item_candidate_reasons(text : String) -> Array[String] {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return []
  }
  if looks_like_unordered_list_marker(trimmed) ||
    looks_like_ordered_list_marker(trimmed) {
    return ["list marker prefix"]
  }
  []
}

///|
fn noise_candidate_reasons(text : String) -> Array[String] {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return ["empty block noise"]
  }
  let lower = trimmed.to_lower()
  if is_page_number_noise(trimmed, lower) {
    return ["page number noise"]
  }
  if is_separator_noise(trimmed) {
    return ["separator noise"]
  }
  []
}

///|
fn page_has_known_geometry(page : OcrPageModel) -> Bool {
  page.width > 0.0 && page.height > 0.0
}

///|
fn page_has_column_like_heading_guard_context(page : OcrPageModel) -> Bool {
  detect_column_like_line_groups(nonblank_ocr_lines(page.lines), true)
  is Some(_)
}

///|
fn resolve_layout_block_lines(
  block : OcrLayoutBlock,
  page : OcrPageModel,
) -> Array[OcrSignalLine] {
  let out : Array[OcrSignalLine] = []
  for index in block.line_indices {
    let mut found = false
    for line in page.lines {
      if line.line_index == index {
        out.push(line)
        found = true
        break
      }
    }
    if !found {
      return []
    }
  }
  out
}

///|
fn is_upper_page_heading_candidate(
  block : OcrLayoutBlock,
  page : OcrPageModel,
) -> Bool {
  if !bbox_is_valid(block.bbox) {
    return false
  }
  if !page_has_known_geometry(page) {
    return false
  }
  let page_top_band = page.height * 0.35
  block.bbox.y <= page_top_band
}

///|
fn has_body_punctuation_tail(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  trimmed.has_suffix(".") ||
  trimmed.has_suffix(",") ||
  trimmed.has_suffix(";") ||
  trimmed.has_suffix(":") ||
  trimmed.has_suffix("!") ||
  trimmed.has_suffix("?") ||
  trimmed.has_suffix("。") ||
  trimmed.has_suffix("，") ||
  trimmed.has_suffix("；") ||
  trimmed.has_suffix("：") ||
  trimmed.has_suffix("！") ||
  trimmed.has_suffix("？")
}

///|
fn looks_heading_like_text(text : String) -> Bool {
  let chars = text.to_array()
  if chars.length() == 0 {
    return false
  }
  let mut letters_or_digits = 0
  let mut allowed = 0
  for ch in chars {
    if is_heading_candidate_char(ch) {
      allowed = allowed + 1
      if is_ascii_letter_or_digit(ch) || is_cjk_char(ch) {
        letters_or_digits = letters_or_digits + 1
      }
    }
  }
  allowed == chars.length() && letters_or_digits > 0
}

///|
fn looks_like_column_label_text(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  if !text_contains_ascii_digit(trimmed) {
    return false
  }
  heading_word_count(trimmed) <= 3 && trimmed.length() <= 24
}

///|
fn heading_word_count(text : String) -> Int {
  let mut count = 0
  for raw in text.split(" ") {
    if raw.trim() != "" {
      count = count + 1
    }
  }
  count
}

///|
fn text_contains_ascii_digit(text : String) -> Bool {
  for ch in text.to_array() {
    if is_ascii_digit(ch) {
      return true
    }
  }
  false
}

///|
fn looks_like_table_row_group(lines : Array[OcrSignalLine]) -> Bool {
  if lines.length() < 3 {
    return false
  }

  let first_word_count = count_valid_table_words(lines[0])
  if first_word_count < 2 || first_word_count > 3 {
    return false
  }

  for line in lines {
    let trimmed = line.text.trim().to_owned()
    if trimmed == "" || trimmed.contains(":") {
      return false
    }
    if has_body_punctuation_tail(trimmed) {
      return false
    }
    if looks_like_amount_line(trimmed) || looks_like_date_line(trimmed) {
      return false
    }
    let word_count = count_valid_table_words(line)
    if word_count != first_word_count || word_count < 2 || word_count > 3 {
      return false
    }
  }
  true
}

///|
fn looks_like_table_candidate_line_group(lines : Array[OcrSignalLine]) -> Bool {
  looks_like_table_row_group(lines) &&
  has_aligned_column_words(lines) &&
  !has_interleaved_same_band_rows(lines)
}

///|
fn detect_table_like_run(
  lines : Array[OcrSignalLine],
  start : Int,
  page : OcrPageModel,
) -> Array[OcrSignalLine]? {
  if start < 0 || start >= lines.length() {
    return None
  }
  let max_end = if lines.length() < start + 4 {
    lines.length()
  } else {
    start + 4
  }
  let mut best_run : Array[OcrSignalLine]? = None
  let mut end = start + 3
  while end <= max_end {
    let candidate : Array[OcrSignalLine] = []
    for i in start..<end {
      candidate.push(lines[i])
    }
    if !lines_have_known_geometry(candidate) {
      end = end + 1
      continue
    }
    if !looks_like_table_row_group(candidate) {
      end = end + 1
      continue
    }
    if !looks_like_table_candidate_line_group(candidate) {
      end = end + 1
      continue
    }
    if table_like_run_looks_like_columns(candidate, page) {
      best_run = Some(candidate)
    }
    end = end + 1
  }
  best_run
}

///|
fn table_like_run_looks_like_columns(
  lines : Array[OcrSignalLine],
  page : OcrPageModel,
) -> Bool {
  if lines.length() < 3 {
    return false
  }
  if has_interleaved_same_band_rows(lines) {
    return false
  }
  if lines.length() >= 4 &&
    detect_column_like_line_groups(lines, true) is Some(_) {
    return false
  }
  if page_has_known_geometry(page) && page.width > 0.0 {
    let block = union_line_bboxes(lines)
    if bbox_is_valid(block) && block.width > page.width * 0.8 {
      return false
    }
  }
  true
}

///|
fn has_interleaved_same_band_rows(lines : Array[OcrSignalLine]) -> Bool {
  if lines.length() < 4 {
    return false
  }
  let mut i = 1
  while i < lines.length() {
    let previous = lines[i - 1]
    let current = lines[i]
    let overlap = double_min(
        bbox_bottom(previous.bbox),
        bbox_bottom(current.bbox),
      ) -
      double_max(previous.bbox.y, current.bbox.y)
    let baseline = double_min(previous.bbox.height, current.bbox.height)
    if baseline > 0.0 && overlap >= baseline * 0.5 {
      let previous_words = valid_table_words(previous)
      let current_words = valid_table_words(current)
      if previous_words.length() >= 2 && current_words.length() >= 2 {
        let left_gap = current_words[0].bbox.x - previous_words[0].bbox.x
        if double_abs(left_gap) >= two_column_min_split_gap() {
          return true
        }
      }
    }
    i = i + 1
  }
  false
}

///|
fn make_table_like_layout_block(lines : Array[OcrSignalLine]) -> OcrLayoutBlock {
  let text_parts : Array[String] = []
  let line_indices : Array[Int] = []
  let mut bbox = unknown_bbox()
  let mut has_bbox = false
  for line in lines {
    let text = line.text.trim().to_owned()
    if text != "" {
      text_parts.push(text)
    }
    line_indices.push(line.line_index)
    if bbox_is_valid(line.bbox) {
      bbox = if has_bbox { bbox_union(bbox, line.bbox) } else { line.bbox }
      has_bbox = true
    }
  }
  {
    kind: OcrLayoutBlockKind::TableLike,
    text: text_parts.join(" "),
    bbox: if has_bbox {
      bbox
    } else {
      unknown_bbox()
    },
    confidence: average_confidence_for_lines(lines),
    line_indices,
    reasons: ["table-like rows", "aligned column candidate"],
  }
}

///|
fn union_line_bboxes(lines : Array[OcrSignalLine]) -> VisionBBox {
  let mut bbox = unknown_bbox()
  let mut has_bbox = false
  for line in lines {
    if bbox_is_valid(line.bbox) {
      bbox = if has_bbox { bbox_union(bbox, line.bbox) } else { line.bbox }
      has_bbox = true
    }
  }
  if has_bbox {
    bbox
  } else {
    unknown_bbox()
  }
}

///|
fn looks_numbered_heading(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  if trimmed.has_prefix("一、") ||
    trimmed.has_prefix("二、") ||
    trimmed.has_prefix("三、") ||
    trimmed.has_prefix("四、") ||
    trimmed.has_prefix("五、") ||
    trimmed.has_prefix("六、") ||
    trimmed.has_prefix("七、") ||
    trimmed.has_prefix("八、") ||
    trimmed.has_prefix("九、") ||
    trimmed.has_prefix("十、") {
    return trimmed.length() > 2
  }

  let chars = trimmed.to_array()
  let mut i = 0
  while i < chars.length() && is_ascii_digit(chars[i]) {
    i = i + 1
  }
  if i == 0 {
    return false
  }
  if i >= chars.length() {
    return false
  }
  let marker = chars[i]
  if marker != '.' {
    return false
  }
  i = i + 1
  if i < chars.length() && chars[i] == ' ' {
    i = i + 1
  }
  i < chars.length()
}

///|
fn looks_like_unordered_list_marker(text : String) -> Bool {
  text.has_prefix("- ") || text.has_prefix("* ") || text.has_prefix("• ")
}

///|
fn best_two_column_split(lines : Array[OcrSignalLine]) -> Int {
  if lines.length() < 4 {
    return -1
  }
  let mut best_index = -1
  let mut best_gap = -1.0
  for i in 2..<(lines.length() - 1) {
    let gap = lines[i].bbox.x - lines[i - 1].bbox.x
    if gap > best_gap {
      best_gap = gap
      best_index = i
    }
  }
  if best_gap < two_column_min_split_gap() {
    -1
  } else {
    best_index
  }
}

///|
fn column_cluster_is_stable(lines : Array[OcrSignalLine]) -> Bool {
  if lines.length() < 2 {
    return false
  }
  let min_x = cluster_min_x(lines)
  let max_x = cluster_max_x(lines)
  max_x - min_x <= two_column_cluster_x_spread()
}

///|
fn column_gap_is_large(
  left : Array[OcrSignalLine],
  right : Array[OcrSignalLine],
) -> Bool {
  let gap = cluster_min_x(right) - cluster_max_x(left)
  gap >= two_column_min_gap()
}

///|
fn column_y_ranges_overlap(
  left : Array[OcrSignalLine],
  right : Array[OcrSignalLine],
) -> Bool {
  let overlap = double_min(cluster_max_bottom(left), cluster_max_bottom(right)) -
    double_max(cluster_min_y(left), cluster_min_y(right))
  overlap >= two_column_min_overlap(min_cluster_line_height(left, right))
}

///|
fn cluster_min_x(lines : Array[OcrSignalLine]) -> Double {
  let mut current = lines[0].bbox.x
  for i in 1..<lines.length() {
    if lines[i].bbox.x < current {
      current = lines[i].bbox.x
    }
  }
  current
}

///|
fn cluster_max_x(lines : Array[OcrSignalLine]) -> Double {
  let mut current = lines[0].bbox.x
  for i in 1..<lines.length() {
    if lines[i].bbox.x > current {
      current = lines[i].bbox.x
    }
  }
  current
}

///|
fn cluster_min_y(lines : Array[OcrSignalLine]) -> Double {
  let mut current = lines[0].bbox.y
  for i in 1..<lines.length() {
    if lines[i].bbox.y < current {
      current = lines[i].bbox.y
    }
  }
  current
}

///|
fn cluster_max_bottom(lines : Array[OcrSignalLine]) -> Double {
  let mut current = bbox_bottom(lines[0].bbox)
  for i in 1..<lines.length() {
    let candidate = bbox_bottom(lines[i].bbox)
    if candidate > current {
      current = candidate
    }
  }
  current
}

///|
fn min_cluster_line_height(
  left : Array[OcrSignalLine],
  right : Array[OcrSignalLine],
) -> Double {
  let left_height = average_line_height(left)
  let right_height = average_line_height(right)
  double_min(left_height, right_height)
}

///|
fn average_line_height(lines : Array[OcrSignalLine]) -> Double {
  if lines.length() == 0 {
    return 0.0
  }
  let mut total = 0.0
  for line in lines {
    total = total + line.bbox.height
  }
  total / lines.length().to_double()
}

///|
fn has_aligned_column_words(lines : Array[OcrSignalLine]) -> Bool {
  if lines.length() < 3 {
    return false
  }
  let first_column_xs : Array[Double] = []
  let second_column_xs : Array[Double] = []
  let column_gaps : Array[Double] = []
  for line in lines {
    let words = valid_table_words(line)
    if words.length() < 2 {
      return false
    }
    let first_x = words[0].bbox.x
    let second_x = words[1].bbox.x
    if double_abs(second_x - first_x) < table_like_min_column_gap() {
      return false
    }
    first_column_xs.push(first_x)
    second_column_xs.push(second_x)
    column_gaps.push(second_x - bbox_right(words[0].bbox))
  }
  if spread_of_values(first_column_xs) > table_like_column_tolerance() {
    return false
  }
  if spread_of_values(second_column_xs) > table_like_second_column_spread() {
    return false
  }
  if min_value(column_gaps) < table_like_min_inter_word_gap() {
    return false
  }
  true
}

///|
fn looks_like_ordered_list_marker(text : String) -> Bool {
  let chars = text.to_array()
  if chars.length() < 4 {
    return false
  }
  if chars[0] == '(' || chars[0] == '（' {
    if chars.length() < 5 || !is_ascii_digit(chars[1]) {
      return false
    }
    let mut i = 1
    while i < chars.length() && is_ascii_digit(chars[i]) {
      i = i + 1
    }
    if i >= chars.length() || (chars[i] != ')' && chars[i] != '）') {
      return false
    }
    i = i + 1
    if i >= chars.length() || chars[i] != ' ' {
      return false
    }
    return i + 1 < chars.length()
  }

  let mut i = 0
  while i < chars.length() && is_ascii_digit(chars[i]) {
    i = i + 1
  }
  if i == 0 || i >= chars.length() {
    return false
  }
  let marker = chars[i]
  if marker != '.' && marker != ')' {
    return false
  }
  i = i + 1
  if i >= chars.length() || chars[i] != ' ' {
    return false
  }
  i + 1 < chars.length()
}

///|
fn is_page_number_noise(text : String, lower : String) -> Bool {
  let compact = collapse_inline_spaces(lower)
  if is_ascii_digits_only(text) {
    return true
  }
  if compact.has_prefix("page ") {
    return is_page_number_suffix(compact[5:].to_owned())
  }
  if compact.has_prefix("第 ") && compact.has_suffix(" 页") {
    return is_ascii_digits_only(
      compact[2:compact.length() - 2].trim().to_owned(),
    )
  }
  if compact.has_prefix("第") && compact.has_suffix("页") {
    return is_ascii_digits_only(
      compact[1:compact.length() - 1].trim().to_owned(),
    )
  }
  if text.has_prefix("- ") && text.has_suffix(" -") {
    return is_ascii_digits_only(text[2:text.length() - 2].trim().to_owned())
  }
  false
}

///|
fn is_page_number_suffix(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  if is_ascii_digits_only(trimmed) {
    return true
  }
  let marker = " of "
  if trimmed.contains(marker) {
    let marker_index = find_substring(trimmed, marker)
    if marker_index > 0 {
      let left = trimmed[:marker_index].trim().to_owned()
      let right = trimmed[marker_index + marker.length():].trim().to_owned()
      return is_ascii_digits_only(left) && is_ascii_digits_only(right)
    }
  }
  false
}

///|
fn is_separator_noise(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed.length() < 3 {
    return false
  }
  let chars = trimmed.to_array()
  let first = chars[0]
  if !(first == '-' || first == '_' || first == '*') {
    return false
  }
  for ch in chars {
    if ch != first {
      return false
    }
  }
  true
}

///|
fn find_substring(text : String, needle : String) -> Int {
  if needle == "" || text.length() < needle.length() {
    return -1
  }
  let chars = text.to_array()
  let pattern = needle.to_array()
  let limit = chars.length() - pattern.length()
  for start = 0; start <= limit; start = start + 1 {
    let mut matched = true
    for i = 0; i < pattern.length(); i = i + 1 {
      if chars[start + i] != pattern[i] {
        matched = false
        break
      }
    }
    if matched {
      return start
    }
  }
  -1
}

///|
fn looks_like_amount_line(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed.contains("$") || trimmed.contains("¥") || trimmed.contains("￥") {
    return true
  }
  let lower = trimmed.to_lower()
  lower.contains("total") || lower.contains("amount")
}

///|
fn looks_like_date_line(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  if lower.contains("-") || lower.contains("/") {
    let chars = trimmed.to_array()
    let mut digit_count = 0
    for ch in chars {
      if is_ascii_digit(ch) {
        digit_count = digit_count + 1
      }
    }
    return digit_count >= 6
  }
  false
}

///|
fn valid_table_words(line : OcrSignalLine) -> Array[OcrSignalWord] {
  let out : Array[OcrSignalWord] = []
  for word in line.words {
    let trimmed = word.text.trim().to_owned()
    if trimmed == "" || !bbox_is_valid(word.bbox) {
      continue
    }
    out.push(word)
  }
  out
}

///|
fn count_valid_table_words(line : OcrSignalLine) -> Int {
  valid_table_words(line).length()
}

///|
fn collapse_inline_spaces(text : String) -> String {
  let out : Array[Char] = []
  let mut prev_space = false
  for ch in text.to_array() {
    let is_space = ch == ' ' || ch == '\t'
    if is_space {
      if !prev_space {
        out.push(' ')
      }
    } else {
      out.push(ch)
    }
    prev_space = is_space
  }
  String::from_array(out).trim().to_owned()
}

///|
fn is_ascii_digits_only(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  for ch in trimmed.to_array() {
    if !is_ascii_digit(ch) {
      return false
    }
  }
  true
}

///|
fn is_ascii_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn is_ascii_letter_or_digit(ch : Char) -> Bool {
  (ch >= '0' && ch <= '9') ||
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= 'a' && ch <= 'z')
}

///|
fn is_heading_candidate_char(ch : Char) -> Bool {
  is_ascii_letter_or_digit(ch) ||
  is_cjk_char(ch) ||
  ch == ' ' ||
  ch == '.' ||
  ch == '-' ||
  ch == '_' ||
  ch == '(' ||
  ch == ')' ||
  ch == '（' ||
  ch == '）' ||
  ch == '、'
}

///|
fn is_cjk_char(ch : Char) -> Bool {
  let code = ch.to_int()
  code >= 0x4E00 && code <= 0x9FFF
}

///|
fn paragraph_max_vertical_gap() -> Double {
  12.0
}

///|
fn paragraph_max_left_delta() -> Double {
  20.0
}

///|
fn two_column_min_split_gap() -> Double {
  80.0
}

///|
fn two_column_min_gap() -> Double {
  80.0
}

///|
fn two_column_cluster_x_spread() -> Double {
  36.0
}

///|
fn two_column_min_overlap(line_height : Double) -> Double {
  let baseline = if line_height > 0.0 { line_height } else { 10.0 }
  baseline * 1.5
}

///|
fn table_like_column_tolerance() -> Double {
  18.0
}

///|
fn table_like_min_column_gap() -> Double {
  24.0
}

///|
fn table_like_second_column_spread() -> Double {
  64.0
}

///|
fn table_like_min_inter_word_gap() -> Double {
  8.0
}

///|
fn spread_of_values(values : Array[Double]) -> Double {
  if values.length() == 0 {
    return 0.0
  }
  max_value(values) - min_value(values)
}

///|
fn min_value(values : Array[Double]) -> Double {
  let mut current = values[0]
  for i in 1..<values.length() {
    if values[i] < current {
      current = values[i]
    }
  }
  current
}

///|
fn max_value(values : Array[Double]) -> Double {
  let mut current = values[0]
  for i in 1..<values.length() {
    if values[i] > current {
      current = values[i]
    }
  }
  current
}

///|
fn double_abs(value : Double) -> Double {
  if value < 0.0 {
    0.0 - value
  } else {
    value
  }
}

///|
fn double_min(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn double_max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn dedupe_layout_warnings(warnings : Array[String]) -> Array[String] {
  let seen : Map[String, Bool] = Map([])
  let out : Array[String] = []
  for warning in warnings {
    if warning.trim() == "" {
      continue
    }
    if seen.contains(warning) {
      continue
    }
    seen.set(warning, true)
    out.push(warning)
  }
  out
}
