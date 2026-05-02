///|
/// 页级 block 结果。
pub struct PdfPageBlocks {
  page_index : Int
  blocks : Array[@model.PdfTextBlock]
}

///|
/// 文档级 block 结果。
pub struct PdfDocumentBlocks {
  pages : Array[PdfPageBlocks]
}

///|
/// 从文档 lines 构建 blocks。
pub fn build_document_blocks(doc_lines : PdfDocumentLines) -> PdfDocumentBlocks {
  let pages = Array::new()
  for page in doc_lines.pages {
    pages.push(build_page_blocks(page))
  }
  { pages, }
}

///|
/// 从单页 lines 构建 blocks。
///
/// Phase-1 语义分块策略：
/// - heading 行单独成块
/// - page number 候选单独成块
/// - 连续正文行合并成 paragraph block
pub fn build_page_blocks(page_lines : PdfPageLines) -> PdfPageBlocks {
  let blocks = if page_lines.lines.is_empty() {
    []
  } else {
    build_blocks_from_lines(page_lines.page_index, page_lines.lines)
  }

  { page_index: page_lines.page_index, blocks }
}

///|
pub fn build_blocks_from_lines(
  page_index : Int,
  lines : Array[@model.PdfTextLine],
) -> Array[@model.PdfTextBlock] {
  if lines.is_empty() {
    return []
  }

  let out = Array::new()
  let mut block_index = 0
  let mut buf : Array[@model.PdfTextLine] = []

  fn flush_paragraph_buf(
    out : Array[@model.PdfTextBlock],
    page_index : Int,
    block_index : Int,
    buf : Array[@model.PdfTextLine],
  ) -> Int {
    if !buf.is_empty() {
      out.push(make_paragraph_block(page_index, block_index, buf))
      return block_index + 1
    }
    block_index
  }

  for i = 0; i < lines.length(); i = i + 1 {
    let line = lines[i]
    let text = @model.line_text(line).trim().to_owned()

    if text == "" {
      block_index = flush_paragraph_buf(out, page_index, block_index, buf)
      buf = []
      continue
    }

    if is_page_number_candidate_line(line) {
      block_index = flush_paragraph_buf(out, page_index, block_index, buf)
      buf = []
      out.push(make_page_number_block(page_index, block_index, [line]))
      block_index = block_index + 1
      continue
    }

    if is_heading_candidate_line(line, lines, i) {
      block_index = flush_paragraph_buf(out, page_index, block_index, buf)
      buf = []
      out.push(make_heading_block(page_index, block_index, [line]))
      block_index = block_index + 1
      continue
    }

    if !buf.is_empty() {
      let prev = buf[buf.length() - 1]
      if should_force_break_before_line(prev, line, lines, i) ||
        !should_merge_lines_in_block(prev, line) {
        block_index = flush_paragraph_buf(out, page_index, block_index, buf)
        buf = []
      }
    }

    buf.push(line)
  }

  block_index = flush_paragraph_buf(out, page_index, block_index, buf)
  out
}

///|
fn should_merge_lines_in_block(
  left : @model.PdfTextLine,
  right : @model.PdfTextLine,
) -> Bool {
  let lt = @model.line_text(left).trim().to_owned()
  let rt = @model.line_text(right).trim().to_owned()
  if lt == "" || rt == "" {
    return false
  }

  if ends_with_strong_sentence_punct(lt) && !looks_like_continuation_line(right) {
    return false
  }

  if looks_like_paragraph_intro_line(lt) {
    return true
  }

  if lines_look_like_same_paragraph_block(left, right) {
    return true
  }

  looks_like_continuation_line(right)
}

///|
fn lines_look_like_same_paragraph_block(
  left : @model.PdfTextLine,
  right : @model.PdfTextLine,
) -> Bool {
  if !line_font_size_close(left, right) {
    return false
  }

  if !line_indent_close(left, right) {
    return false
  }

  if !line_vertical_distance_close(left, right) {
    return false
  }

  true
}

///|
fn should_force_break_before_line(
  prev : @model.PdfTextLine,
  cur : @model.PdfTextLine,
  page_lines : Array[@model.PdfTextLine],
  cur_index : Int,
) -> Bool {
  let prev_text = @model.line_text(prev).trim().to_owned()
  let cur_text = @model.line_text(cur).trim().to_owned()
  if cur_text == "" {
    return true
  }

  if is_page_number_candidate(cur_text) {
    return true
  }

  if looks_like_heading_line(cur_text) &&
    is_heading_candidate_line(cur, page_lines, cur_index) {
    return true
  }

  if looks_like_bullet_line_text(cur_text) {
    return true
  }

  if starts_with_numbered_heading_prefix(cur_text) {
    return true
  }

  // two-column negative：出现明显横向跳列时断块，避免跨列 stitch。
  if looks_like_cross_column_jump(prev, cur) {
    return true
  }

  // 短确认词（如 OK）不要和后句误并。
  if looks_like_standalone_ack_line(prev_text) &&
    looks_like_sentence_start(cur_text) {
    return true
  }

  false
}

///|
fn looks_like_continuation_line(line : @model.PdfTextLine) -> Bool {
  let t = @model.line_text(line).trim().to_owned()
  if t == "" {
    return false
  }

  if t.has_prefix("，") || t.has_prefix("。") || t.has_prefix(",") {
    return true
  }

  if starts_with_body_continuation_prefix(t) {
    return true
  }

  let c = first_char_opt(t)
  match c {
    Some(ch) => ch >= 'a' && ch <= 'z'
    _ => false
  }
}

///|
fn looks_like_cross_column_jump(
  left : @model.PdfTextLine,
  right : @model.PdfTextLine,
) -> Bool {
  let dx = abs_double_rule(left.bbox.x0 - right.bbox.x0)
  let mid_y_left = (left.bbox.y0 + left.bbox.y1) / 2.0
  let mid_y_right = (right.bbox.y0 + right.bbox.y1) / 2.0
  let dy = abs_double_rule(mid_y_left - mid_y_right)
  dx >= 120.0 && dy <= 24.0
}

///|
fn looks_like_standalone_ack_line(text : String) -> Bool {
  let t = text.trim().to_owned()
  t == "OK" || t == "Ok" || t == "ok"
}

///|
fn looks_like_sentence_start(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }
  if looks_like_heading_line(t) || looks_like_bullet_line_text(t) {
    return false
  }
  true
}

///|
fn is_heading_candidate_line(
  line : @model.PdfTextLine,
  page_lines : Array[@model.PdfTextLine],
  line_index : Int,
) -> Bool {
  let text = @model.line_text(line).trim().to_owned()
  if text == "" {
    return false
  }

  if !looks_like_heading_text_candidate(text) {
    return false
  }

  let score = heading_layout_score(line, page_lines, line_index)
  if score >= 2 {
    return true
  }

  // 放宽：页首短标题，哪怕只有 1 个强版面证据，也允许成立
  if is_short_single_line_heading_like(line) &&
    is_near_page_top(line, page_lines) &&
    score >= 1 {
    return true
  }

  // 放宽：夹在两段正文之间的短标题，也允许成立
  if is_short_single_line_heading_like(line) &&
    is_between_body_lines(page_lines, line_index) &&
    score >= 1 {
    return true
  }

  false
}

///|
fn looks_like_heading_text_candidate(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  if looks_like_intro_phrase(t) {
    return false
  }

  if looks_like_list_intro_line(t) {
    return false
  }

  if looks_like_numbered_body_sentence(t) {
    return false
  }

  if looks_like_figure_or_table_caption(t) {
    return false
  }

  looks_like_heading_line(t)
}

///|
fn heading_layout_score(
  line : @model.PdfTextLine,
  page_lines : Array[@model.PdfTextLine],
  line_index : Int,
) -> Int {
  let mut score = 0

  if has_larger_font_than_page_body(line, page_lines) {
    score = score + 1
  }

  if has_large_gap_before(line) {
    score = score + 1
  }

  if has_large_gap_after(line) {
    score = score + 1
  }

  if is_near_page_top(line, page_lines) {
    score = score + 1
  }

  if is_short_single_line_heading_like(line) {
    score = score + 1
  }

  // 两段正文之间的短行，更像标题
  if is_between_body_lines(page_lines, line_index) {
    score = score + 1
  }

  score
}

///|
fn has_larger_font_than_page_body(
  line : @model.PdfTextLine,
  page_lines : Array[@model.PdfTextLine],
) -> Bool {
  let body = page_body_font_size(page_lines)
  let cur = line_font_size(line)

  match (cur, body) {
    (Some(a), Some(b)) => a >= b + 0.5
    _ => false
  }
}

///|
fn page_body_font_size(lines : Array[@model.PdfTextLine]) -> Double? {
  let sizes = Array::new()

  for line in lines {
    match line_font_size(line) {
      Some(fs) => sizes.push(fs)
      None => ()
    }
  }

  if sizes.is_empty() {
    return None
  }

  let mut best_size = sizes[0]
  let mut best_count = 0

  for i = 0; i < sizes.length(); i = i + 1 {
    let cur = sizes[i]
    let mut count = 0

    for j = 0; j < sizes.length(); j = j + 1 {
      if nearly_same_font_size(cur, sizes[j]) {
        count = count + 1
      }
    }

    if count > best_count {
      best_count = count
      best_size = cur
    }
  }

  Some(best_size)
}

///|
fn nearly_same_font_size(a : Double, b : Double) -> Bool {
  abs_double(a - b) <= 0.5
}

///|
fn line_font_size(line : @model.PdfTextLine) -> Double? {
  if line.spans.is_empty() {
    return None
  }

  let mut best = 0.0
  let mut seen = false

  for span in line.spans {
    match span.font_size {
      Some(fs) =>
        if !seen || fs > best {
          best = fs
          seen = true
        }
      None => ()
    }
  }

  if seen {
    Some(best)
  } else {
    None
  }
}

///|
fn has_large_gap_before(line : @model.PdfTextLine) -> Bool {
  match (line.line_gap_before, line.line_height) {
    (Some(g), Some(h)) => g >= h * 0.8
    _ => false
  }
}

///|
fn has_large_gap_after(line : @model.PdfTextLine) -> Bool {
  match (line.line_gap_after, line.line_height) {
    (Some(g), Some(h)) => g >= h * 0.8
    _ => false
  }
}

///|
fn is_near_page_top(
  line : @model.PdfTextLine,
  page_lines : Array[@model.PdfTextLine],
) -> Bool {
  if page_lines.is_empty() {
    return false
  }

  let mut top = page_lines[0].bbox.y0
  for ln in page_lines {
    if ln.bbox.y0 > top {
      top = ln.bbox.y0
    }
  }

  line.bbox.y0 >= top - 40.0
}

///|
fn is_short_single_line_heading_like(line : @model.PdfTextLine) -> Bool {
  let text = @model.line_text(line).trim().to_owned()
  if text == "" {
    return false
  }

  if text.length() > 40 {
    return false
  }

  if ends_with_strong_sentence_punct(text) {
    return false
  }

  true
}

///|
fn is_between_body_lines(
  page_lines : Array[@model.PdfTextLine],
  line_index : Int,
) -> Bool {
  if line_index <= 0 || line_index + 1 >= page_lines.length() {
    return false
  }

  let prev = @model.line_text(page_lines[line_index - 1]).trim().to_owned()
  let next = @model.line_text(page_lines[line_index + 1]).trim().to_owned()

  looks_like_body_line(prev) && looks_like_body_line(next)
}

///|
/// line 是否像页码候选。
fn is_page_number_candidate_line(line : @model.PdfTextLine) -> Bool {
  let text = @model.line_text(line).trim().to_owned()
  if text == "" {
    return false
  }
  is_page_number_candidate(text)
}

///|
/// 生成 paragraph block。
fn make_paragraph_block(
  page_index : Int,
  block_index : Int,
  lines : Array[@model.PdfTextLine],
) -> @model.PdfTextBlock {
  make_block(
    page_index,
    block_index,
    lines,
    @model.PdfTextBlockKind::Text,
    false,
    false,
  )
}

///|
/// 生成 heading block。
fn make_heading_block(
  page_index : Int,
  block_index : Int,
  lines : Array[@model.PdfTextLine],
) -> @model.PdfTextBlock {
  make_block(
    page_index,
    block_index,
    lines,
    @model.PdfTextBlockKind::HeadingCandidate,
    true,
    false,
  )
}

///|
/// 生成页码候选 block。
fn make_page_number_block(
  page_index : Int,
  block_index : Int,
  lines : Array[@model.PdfTextLine],
) -> @model.PdfTextBlock {
  make_block(
    page_index,
    block_index,
    lines,
    @model.PdfTextBlockKind::HeaderFooterCandidate,
    false,
    true,
  )
}

///|
/// 通用 block 构造。
fn make_block(
  page_index : Int,
  block_index : Int,
  lines : Array[@model.PdfTextLine],
  kind : @model.PdfTextBlockKind,
  is_heading_candidate : Bool,
  is_page_number_candidate : Bool,
) -> @model.PdfTextBlock {
  let bbox = @model.lines_bbox(lines).unwrap_or(default_rect())
  let source_refs = collect_line_source_refs(lines)

  {
    id: make_block_id(page_index, block_index),
    bbox,
    kind,
    rotation: None,
    dominant_font_name: dominant_font_name_of_lines(lines),
    dominant_font_size: dominant_font_size_of_lines(lines),
    dominant_language: None,
    writing_direction: infer_writing_direction2(lines),
    z_index: None,
    lines,
    is_heading_candidate,
    is_header_footer_candidate: is_page_number_candidate,
    is_page_number_candidate,
    is_table_cell_candidate: false,
    is_caption_candidate: false,
    is_artifact_candidate: false,
    source_refs,
  }
}

///|
/// 汇总 line 的 source refs，并去重。
fn collect_line_source_refs(
  lines : Array[@model.PdfTextLine],
) -> Array[@model.PdfSourceRef] {
  let out = Array::new()
  for line in lines {
    for src in line.source_refs {
      if !contains_source_ref(out, src) {
        out.push(src)
      }
    }
  }
  out
}

///|
/// 取第一条 line 的第一个 span 的 font_name 作为 dominant font。
fn dominant_font_name_of_lines(lines : Array[@model.PdfTextLine]) -> String? {
  if lines.is_empty() {
    return None
  }

  let first_line = lines[0]
  if first_line.spans.is_empty() {
    return None
  }

  first_line.spans[0].font_name
}

///|
/// 取第一条 line 的第一个 span 的 font_size 作为 dominant font size。
fn dominant_font_size_of_lines(lines : Array[@model.PdfTextLine]) -> Double? {
  if lines.is_empty() {
    return None
  }

  let first_line = lines[0]
  if first_line.spans.is_empty() {
    return None
  }

  first_line.spans[0].font_size
}

///|
fn infer_writing_direction2(
  _lines : Array[@model.PdfTextLine],
) -> @model.PdfWritingDirection {
  @model.PdfWritingDirection::LeftToRight
}

///|
fn make_block_id(page_index : Int, block_index : Int) -> String {
  "p" + page_index.to_string() + "_block_" + block_index.to_string()
}
