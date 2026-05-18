///|
/// Line -> block staging.
///
/// This stage groups one-line seeds into block objects and interleaves images
/// into a shared page object stream. We do this before semantic recovery so
/// heading/caption heuristics can use unified local neighborhood context.
pub fn build_convert_blocks(doc : PdfConvertDocument) -> PdfConvertDocument {
  let pages = Array::new()

  for page in doc.pages {
    pages.push(build_convert_page_blocks(page))
  }

  { pages, }
}

///|
/// 从单页 convert lines 构建 convert blocks，并与图片按 _bbox 混排。
fn build_convert_page_blocks(page : PdfConvertPage) -> PdfConvertPage {
  let blocks = Array::new()
  let mut i = 0
  let mut block_index = 0

  while i < page.lines.length() {
    let grouped : Array[PdfConvertLine] = [page.lines[i]]
    let source_block_index = page.lines[i]._source_block_index
    i = i + 1

    while i < page.lines.length() &&
          page.lines[i]._source_block_index == source_block_index &&
          !should_break_same_source_convert_block(grouped, page.lines[i]) {
      grouped.push(page.lines[i])
      i = i + 1
    }

    blocks.push(make_block_from_lines(page._page_index, block_index, grouped))
    block_index = block_index + 1
  }

  let objects = build_page_objects(blocks, page.images)

  {
    _page_index: page._page_index,
    media_box: page.media_box,
    crop_box: page.crop_box,
    lines: page.lines,
    blocks,
    images: page.images,
    annotations: page.annotations,
    forms: page.forms,
    objects,
  }
}

///|
fn should_break_same_source_convert_block(
  grouped : Array[PdfConvertLine],
  next : PdfConvertLine,
) -> Bool {
  if grouped.is_empty() {
    return false
  }

  let prev = grouped[grouped.length() - 1]
  if !same_visual_row_convert_line(prev, next) {
    return !should_group_same_source_paragraph_lines(prev, next)
  }

  abs_convert_block_f64(prev._bbox.x0 - next._bbox.x0) > 4.0
}

///|
fn should_group_same_source_paragraph_lines(
  prev : PdfConvertLine,
  next : PdfConvertLine,
) -> Bool {
  prev.is_wrapped_candidate ||
  next.is_wrapped_candidate ||
  prev.is_same_paragraph_with_prev_candidate ||
  next.is_same_paragraph_with_prev_candidate ||
  looks_like_unflagged_convert_line_continuation(prev, next)
}

///|
fn looks_like_unflagged_convert_line_continuation(
  prev : PdfConvertLine,
  next : PdfConvertLine,
) -> Bool {
  let prev_text = prev.text.trim().to_owned()
  let next_text = next.text.trim().to_owned()
  if prev_text == "" || next_text == "" {
    return false
  }

  if looks_like_convert_separator_line(prev_text) ||
    looks_like_convert_separator_line(next_text) {
    return false
  }

  if looks_like_convert_domain_or_url_line(next_text) {
    return false
  }

  if abs_convert_block_f64(prev._bbox.x0 - next._bbox.x0) > 4.0 {
    return false
  }

  let next_first = match first_convert_char(next_text) {
    Some(ch) => ch
    None => return false
  }
  if !((next_first >= 'a' && next_first <= 'z') ||
    next_first == '(' ||
    next_first == '[' ||
    next_first == '"' ||
    next_first == '\'') {
    return false
  }

  match last_convert_char(prev_text) {
    Some(last) =>
      !is_convert_right_tight_punct(last) &&
      last != ':' &&
      last != ';' &&
      last != '!' &&
      last != '?' &&
      last != ')' &&
      last != ']'
    None => false
  }
}

///|
fn looks_like_convert_separator_line(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t.length() < 3 {
    return false
  }

  for ch in t {
    if ch != '-' && ch != '=' && ch != '_' && ch != '*' {
      return false
    }
  }
  true
}

///|
fn looks_like_convert_domain_or_url_line(text : String) -> Bool {
  let t = text.trim().to_lower()
  t.has_prefix("www.") || t.has_prefix("http://") || t.has_prefix("https://")
}

///|
fn same_visual_row_convert_line(
  left : PdfConvertLine,
  right : PdfConvertLine,
) -> Bool {
  let left_base = match left.baseline_y {
    Some(v) => v
    None => (left._bbox.y0 + left._bbox.y1) / 2.0
  }
  let right_base = match right.baseline_y {
    Some(v) => v
    None => (right._bbox.y0 + right._bbox.y1) / 2.0
  }
  let left_h = match left.line_height {
    Some(v) => v
    None =>
      match left.font_size {
        Some(v) => v
        None => 12.0
      }
  }
  let right_h = match right.line_height {
    Some(v) => v
    None =>
      match right.font_size {
        Some(v) => v
        None => 12.0
      }
  }
  let ref_h = if left_h > right_h { left_h } else { right_h }
  abs_convert_block_f64(left_base - right_base) <= ref_h * 0.35
}

///|
fn abs_convert_block_f64(v : Double) -> Double {
  if v < 0.0 {
    -v
  } else {
    v
  }
}

///|
fn make_block_from_lines(
  _page_index : Int,
  block_index : Int,
  lines : Array[PdfConvertLine],
) -> PdfConvertBlock {
  let first = lines[0]
  let last = lines[lines.length() - 1]
  let kind = if first.is_heading_candidate {
    PdfConvertBlockKind::Heading
  } else {
    PdfConvertBlockKind::Paragraph
  }
  let bbox = convert_block_bbox(lines)

  {
    _page_index,
    block_index,
    kind,
    text: join_convert_source_block_text(lines),
    rich_inlines: None,
    line_start: first.line_index,
    line_end: last.line_index,
    source_block_index: first._source_block_index,
    source_block_line_count: first.source_block_line_count,
    source_block_kind: first.source_block_kind,
    source_block_bbox: first.source_block_bbox,
    source_block_dominant_font_size: first.source_block_dominant_font_size,
    source_block_dominant_font_name: first.source_block_dominant_font_name,
    is_heading_candidate: first.is_heading_candidate,
    is_noise_candidate: first.is_page_number_candidate,
    is_header_footer_candidate: first.is_header_footer_candidate,
    is_artifact_candidate: first.is_artifact_candidate,
    is_caption_candidate: first.is_caption_candidate,
    is_table_cell_candidate: first.is_table_cell_candidate,
    dominant_language: first.dominant_language,
    writing_direction: first.writing_direction,
    _bbox: bbox,
    dominant_font_size: match first.source_block_dominant_font_size {
      Some(size) => Some(size)
      None => first.font_size
    },
    dominant_font_name: match first.source_block_dominant_font_name {
      Some(name) => Some(name)
      None => first.font_name
    },
    top_y: bbox.y1,
    left_x: bbox.x0,
    line_count: lines.length(),
    first_indent_left: first.indent_left,
    last_indent_left: last.indent_left,
    first_indent_right: first.indent_right,
    last_indent_right: last.indent_right,
    first_alignment_hint: first.alignment_hint,
    last_alignment_hint: last.alignment_hint,
    first_line_gap_before: first.line_gap_before,
    last_line_gap_after: last._line_gap_after,
    first_line_height: first.line_height,
    last_line_height: last.line_height,
    first_baseline_y: first.baseline_y,
    last_baseline_y: last.baseline_y,
    first_is_wrapped_candidate: first.is_wrapped_candidate,
    last_is_wrapped_candidate: last.is_wrapped_candidate,
    first_is_same_paragraph_with_prev_candidate: first.is_same_paragraph_with_prev_candidate,
    last_is_same_paragraph_with_prev_candidate: last.is_same_paragraph_with_prev_candidate,
  }
}

///|
fn convert_block_bbox(lines : Array[PdfConvertLine]) -> @model.PdfRect {
  let mut bbox = lines[0]._bbox
  for i = 1; i < lines.length(); i = i + 1 {
    bbox = @model.union_rect(bbox, lines[i]._bbox)
  }
  bbox
}

///|
fn join_convert_source_block_text(lines : Array[PdfConvertLine]) -> String {
  if lines.is_empty() {
    return ""
  }

  let mut out = ""
  for line in lines {
    let text = line.text.trim().to_owned()
    if text == "" {
      continue
    }

    if out == "" {
      out = text
      continue
    }

    out = append_convert_line_text(out, text)
  }

  out
}

///|
fn append_convert_line_text(left : String, right : String) -> String {
  let l = left.trim().to_owned()
  let r = right.trim().to_owned()

  if l == "" {
    return r
  }
  if r == "" {
    return l
  }

  if should_repair_convert_line_wrap_hyphen(l, r) {
    return trim_convert_line_wrap_hyphen(l) + r
  }

  if should_keep_convert_line_hyphen_without_space(l, r) {
    return l + r
  }

  if should_join_convert_line_text_without_space(l, r) {
    return l + r
  }

  l + " " + r
}

///|
fn should_repair_convert_line_wrap_hyphen(
  left : String,
  right : String,
) -> Bool {
  if !left.has_suffix("-") &&
    !left.has_suffix("\u{2010}") &&
    !left.has_suffix("\u{2011}") {
    return false
  }

  let left_fragment = trailing_convert_ascii_letters_before_hyphen(left)
  let right_fragment = leading_convert_ascii_letters(right)
  if left_fragment == "" || right_fragment == "" {
    return false
  }

  looks_like_convert_wrapped_hyphen_word_continuation(
    left_fragment, right_fragment,
  )
}

///|
fn is_ascii_letter_convert(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
}

///|
fn trim_convert_line_wrap_hyphen(text : String) -> String {
  if text.has_suffix("-") ||
    text.has_suffix("\u{2010}") ||
    text.has_suffix("\u{2011}") {
    text[:text.length() - 1].to_owned()
  } else {
    text
  }
}

///|
fn should_keep_convert_line_hyphen_without_space(
  left : String,
  right : String,
) -> Bool {
  if !left.has_suffix("-") &&
    !left.has_suffix("\u{2010}") &&
    !left.has_suffix("\u{2011}") {
    return false
  }

  let right_fragment = leading_convert_ascii_letters(right)
  if right_fragment == "" {
    return false
  }

  !looks_like_convert_hyphen_connector_follow_word(right_fragment)
}

///|
fn should_join_convert_line_text_without_space(
  left : String,
  right : String,
) -> Bool {
  match (last_convert_char(left), first_convert_char(right)) {
    (Some(lc), Some(rc)) =>
      (is_convert_cjk_char(lc) && is_convert_cjk_char(rc)) ||
      should_tighten_convert_numeric_separator(left, rc) ||
      should_join_after_left_convert_punct(lc, rc) ||
      is_convert_right_tight_punct(rc)
    _ => false
  }
}

///|
fn first_convert_char(text : String) -> Char? {
  for ch in text {
    return Some(ch)
  }
  None
}

///|
fn last_convert_char(text : String) -> Char? {
  let mut last : Char? = None
  for ch in text {
    last = Some(ch)
  }
  last
}

///|
fn trailing_convert_ascii_letters_before_hyphen(text : String) -> String {
  let trimmed = trim_convert_line_wrap_hyphen(text.trim().to_owned())
  if trimmed == text.trim().to_owned() {
    return ""
  }

  let chars = trimmed.to_array()
  if chars.is_empty() {
    return ""
  }

  let mut out_rev = ""
  let mut i = chars.length() - 1
  while true {
    let ch = chars[i]
    if is_ascii_letter_convert(ch) {
      out_rev = out_rev + ch.to_string()
    } else {
      break
    }

    if i == 0 {
      break
    }
    i = i - 1
  }

  reverse_convert_string(out_rev)
}

///|
fn reverse_convert_string(text : String) -> String {
  let chars = text.to_array()
  let mut out = ""
  let mut i = chars.length()
  while i > 0 {
    out = out + chars[i - 1].to_string()
    i = i - 1
  }
  out
}

///|
fn leading_convert_ascii_letters(text : String) -> String {
  let chars = text.trim().to_owned().to_array()
  let mut out = ""
  let mut i = 0
  while i < chars.length() {
    let ch = chars[i]
    if is_ascii_letter_convert(ch) {
      out = out + ch.to_string()
      i = i + 1
    } else {
      break
    }
  }
  out
}

///|
fn looks_like_convert_wrapped_hyphen_word_continuation(
  left_fragment : String,
  right_fragment : String,
) -> Bool {
  let word = left_fragment + right_fragment
  if word.length() < 4 || word.length() > 28 {
    return false
  }

  if !all_ascii_letters_convert(word) {
    return false
  }

  let left = left_fragment.to_lower()
  let right = right_fragment.to_lower()

  if looks_like_convert_wrapped_hyphen_suffix_piece(right) && left.length() >= 3 {
    return true
  }

  if looks_like_convert_bound_prefix(left) && right.length() >= 4 {
    return true
  }

  if left.length() == 3 &&
    right.length() >= 4 &&
    !looks_like_preserved_convert_short_semantic_hyphen_prefix(left) {
    return true
  }

  has_convert_ligature_fragment_hint(left) && right.length() <= 5
}

///|
fn looks_like_convert_wrapped_hyphen_suffix_piece(text : String) -> Bool {
  text == "ed" ||
  text == "er" ||
  text == "es" ||
  text == "ly" ||
  text == "ing" ||
  text == "tion" ||
  text == "sion" ||
  text == "ment" ||
  text == "ness" ||
  text == "able" ||
  text == "ible" ||
  text == "ity" ||
  text == "ities" ||
  text == "ation" ||
  text == "ations" ||
  text == "ative" ||
  text == "ality" ||
  text == "ility" ||
  text == "ally" ||
  text == "ially" ||
  text == "ically" ||
  text == "ming" ||
  text == "tially"
}

///|
fn looks_like_convert_bound_prefix(text : String) -> Bool {
  text == "inter" ||
  text == "multi" ||
  text == "semi" ||
  text == "trans" ||
  text == "micro" ||
  text == "macro" ||
  text == "hyper" ||
  text == "meta" ||
  text == "auto" ||
  text == "uni"
}

///|
fn looks_like_preserved_convert_short_semantic_hyphen_prefix(
  text : String,
) -> Bool {
  text == "non" || text == "pre" || text == "sub" || text == "mid"
}

///|
fn has_convert_ligature_fragment_hint(text : String) -> Bool {
  text.has_suffix("fi") ||
  text.has_suffix("ff") ||
  text.has_suffix("fl") ||
  text.has_suffix("ffi") ||
  text.has_suffix("ffl")
}

///|
fn looks_like_convert_hyphen_connector_follow_word(text : String) -> Bool {
  let word = text.trim().to_lower()
  word == "or" || word == "and" || word == "to"
}

///|
fn all_ascii_letters_convert(text : String) -> Bool {
  if text == "" {
    return false
  }

  for ch in text {
    if !is_ascii_letter_convert(ch) {
      return false
    }
  }

  true
}

///|
fn is_convert_cjk_char(ch : Char) -> Bool {
  let code = ch.to_int()
  (code >= 0x4E00 && code <= 0x9FFF) ||
  (code >= 0x3400 && code <= 0x4DBF) ||
  (code >= 0xF900 && code <= 0xFAFF)
}

///|
fn should_join_after_left_convert_punct(left : Char, _right : Char) -> Bool {
  is_convert_open_punct(left) || is_convert_cjk_tight_punct(left)
}

///|
fn should_tighten_convert_numeric_separator(
  left : String,
  right : Char,
) -> Bool {
  if !is_ascii_digit_convert(right) {
    return false
  }

  let chars = left.to_array()
  if chars.length() < 2 {
    return false
  }

  let last = chars[chars.length() - 1]
  let prev = chars[chars.length() - 2]
  (last == ',' || last == ':' || last == '.' || last == '/') &&
  is_ascii_digit_convert(prev)
}

///|
fn is_ascii_digit_convert(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn is_convert_open_punct(ch : Char) -> Bool {
  ch == '（' ||
  ch == '《' ||
  ch == '“' ||
  ch == '‘' ||
  ch == '(' ||
  ch == '['
}

///|
fn is_convert_cjk_tight_punct(ch : Char) -> Bool {
  ch == '、' ||
  ch == '，' ||
  ch == '。' ||
  ch == '；' ||
  ch == '：' ||
  ch == '！' ||
  ch == '？'
}

///|
fn is_convert_right_tight_punct(ch : Char) -> Bool {
  ch == '、' ||
  ch == '，' ||
  ch == '。' ||
  ch == '；' ||
  ch == '：' ||
  ch == '！' ||
  ch == '？' ||
  ch == '）' ||
  ch == '》' ||
  ch == '”' ||
  ch == '’' ||
  ch == ')' ||
  ch == ']' ||
  ch == ',' ||
  ch == '.' ||
  ch == '!' ||
  ch == '?'
}

///|
fn build_page_objects(
  blocks : Array[PdfConvertBlock],
  images : Array[PdfConvertImage],
) -> Array[PdfConvertPageObject] {
  let out : Array[PdfConvertPageObject] = []

  for block in blocks {
    insert_page_object_sorted(out, PdfConvertPageObject::TextBlock(block))
  }

  for image in images {
    insert_page_object_sorted(out, PdfConvertPageObject::Image(image))
  }

  out
}

///|
fn insert_page_object_sorted(
  out : Array[PdfConvertPageObject],
  obj : PdfConvertPageObject,
) -> Unit {
  let inserted = Array::new()
  let mut placed = false

  for existing in out {
    if !placed && compare_page_object_layout(obj, existing) < 0 {
      inserted.push(obj)
      placed = true
    }
    inserted.push(existing)
  }

  if !placed {
    inserted.push(obj)
  }

  out.clear()
  for x in inserted {
    out.push(x)
  }
}

///|
/// 返回：
/// -1 => a 在前
///  0 => 相近
///  1 => b 在前
///
/// 规则：
/// - 先按 top_y 从大到小（PDF 坐标系里越大越靠上）
/// - 若 vertical 距离很小，按 left_x 从小到大
fn compare_page_object_layout(
  a : PdfConvertPageObject,
  b : PdfConvertPageObject,
) -> Int {
  let ay = page_object_top_y(a)
  let by = page_object_top_y(b)

  let dy = abs_f64(ay - by)
  if dy > 8.0 {
    if ay > by {
      return -1
    } else {
      return 1
    }
  }

  let ax = page_object_left_x(a)
  let bx = page_object_left_x(b)
  if ax < bx {
    return -1
  }
  if ax > bx {
    return 1
  }

  0
}

///|
fn page_object_top_y(obj : PdfConvertPageObject) -> Double {
  match obj {
    PdfConvertPageObject::TextBlock(block) => block.top_y
    PdfConvertPageObject::Image(image) => image.top_y
  }
}

///|
fn page_object_left_x(obj : PdfConvertPageObject) -> Double {
  match obj {
    PdfConvertPageObject::TextBlock(block) => block.left_x
    PdfConvertPageObject::Image(image) => image.left_x
  }
}

///|
fn abs_f64(v : Double) -> Double {
  if v < 0.0 {
    -v
  } else {
    v
  }
}
