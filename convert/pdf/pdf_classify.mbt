///|
/// 第一版最小 classify：
/// - 保住高置信 heading
/// - 把明显误判 heading 降回 paragraph
/// - 使用页内前后文提升 precision
///
/// 这是启发式恢复层，不追求“全召回”：
/// - 歧义场景优先保守降级到 paragraph，避免错误结构污染主链路
/// - heading 误判的代价通常高于漏判（会影响章节结构与后续消费）
fn classify_convert_blocks(
  doc : PdfConvertDocument,
  max_heading : Int,
) -> PdfConvertDocument {
  let pages = Array::new()

  for page in doc.pages {
    pages.push(classify_convert_page_blocks(page, max_heading))
  }

  { pages, }
}

///|
fn classify_convert_page_blocks(
  page : PdfConvertPage,
  max_heading : Int,
) -> PdfConvertPage {
  let blocks = Array::new()

  for i = 0; i < page.blocks.length(); i = i + 1 {
    let prev = if i > 0 { Some(page.blocks[i - 1]) } else { None }

    let next = if i + 1 < page.blocks.length() {
      Some(page.blocks[i + 1])
    } else {
      None
    }

    blocks.push(
      classify_single_block_with_context(
        prev,
        page.blocks[i],
        next,
        max_heading,
      ),
    )
  }

  rebuild_page_objects({
    _page_index: page._page_index,
    media_box: page.media_box,
    crop_box: page.crop_box,
    lines: page.lines,
    blocks,
    images: page.images,
    objects: page.objects,
  })
}

///|
fn classify_single_block_with_context(
  prev : PdfConvertBlock?,
  block : PdfConvertBlock,
  next : PdfConvertBlock?,
  max_heading : Int,
) -> PdfConvertBlock {
  let text = block.text.trim().to_owned()

  if should_never_be_heading(text) {
    return match block.kind {
      PdfConvertBlockKind::Noise => block
      _ =>
        if should_be_noise(text) {
          copy_block_with_kind(block, PdfConvertBlockKind::Noise)
        } else {
          copy_block_with_kind(block, PdfConvertBlockKind::Paragraph)
        }
    }
  }

  return match block.kind {
    PdfConvertBlockKind::Noise => block
    PdfConvertBlockKind::Paragraph =>
      if should_be_noise(text) {
        copy_block_with_kind(block, PdfConvertBlockKind::Noise)
      } else if should_promote_paragraph_to_heading(
          prev, block, next, text, max_heading,
        ) {
        copy_block_with_kind(block, PdfConvertBlockKind::Heading)
      } else {
        block
      }
    PdfConvertBlockKind::Heading =>
      if should_be_noise(text) {
        copy_block_with_kind(block, PdfConvertBlockKind::Noise)
      } else if should_demote_heading(prev, block, text, next) {
        copy_block_with_kind(block, PdfConvertBlockKind::Paragraph)
      } else if should_keep_heading(prev, block, text, next, max_heading) {
        block
      } else {
        copy_block_with_kind(block, PdfConvertBlockKind::Paragraph)
      }
  }
}

///|
fn should_never_be_heading(text : String) -> Bool {
  let t = text.trim().to_owned()

  if t == "" {
    return true
  }

  if should_be_noise(t) {
    return true
  }

  if looks_like_bullet_item(t) {
    return true
  }

  if looks_like_list_item_sentence(t) {
    return true
  }

  if looks_like_colon_label(t) {
    return true
  }

  if looks_like_side_marker_label_line(t) {
    return true
  }

  if @text.looks_like_intro_phrase(t) {
    return true
  }

  if @text.looks_like_figure_or_table_caption(t) {
    return true
  }

  if looks_like_numbered_body_sentence(t) {
    return true
  }

  false
}

///|
fn should_promote_paragraph_to_heading(
  prev : PdfConvertBlock?,
  block : PdfConvertBlock,
  next : PdfConvertBlock?,
  text : String,
  max_heading : Int,
) -> Bool {
  let t = text.trim().to_owned()

  if t == "" {
    return false
  }
  if @text.word_count(t) <= 1 &&
    t.length() <= 3 &&
    !is_visually_larger_than_neighbors(prev, block, next) {
    return false
  }
  if should_be_noise(t) {
    return false
  }

  if looks_like_bullet_item(t) {
    return false
  }

  if looks_like_list_item_sentence(t) {
    return false
  }

  if looks_like_colon_label(t) {
    return false
  }

  if looks_like_side_marker_label_line(t) {
    return false
  }

  if ends_with_noise_tail(t) {
    return false
  }

  if looks_like_numbered_body_sentence(t) {
    return false
  }

  if is_obvious_body_sentence(t) {
    return false
  }

  if is_too_long_for_heading(t) {
    return false
  }

  if block.is_heading_candidate &&
    should_keep_heading(prev, block, t, next, max_heading) {
    return true
  }

  if looks_like_layout_heading_candidate(prev, block, next, t) {
    return true
  }

  // 即使上游没打 candidate，也允许高置信文本提升
  should_keep_heading(prev, block, t, next, max_heading)
}

///|
fn should_be_noise(text : String) -> Bool {
  let t = text.trim().to_owned()
  is_page_label_like(t)
}

///|
fn copy_block_with_kind(
  block : PdfConvertBlock,
  kind : PdfConvertBlockKind,
) -> PdfConvertBlock {
  {
    _page_index: block._page_index,
    block_index: block.block_index,
    kind,
    text: block.text,
    line_start: block.line_start,
    line_end: block.line_end,
    source_block_index: block.source_block_index,
    source_block_line_count: block.source_block_line_count,
    source_block_kind: block.source_block_kind,
    source_block_bbox: block.source_block_bbox,
    source_block_dominant_font_size: block.source_block_dominant_font_size,
    source_block_dominant_font_name: block.source_block_dominant_font_name,
    is_heading_candidate: block.is_heading_candidate,
    is_noise_candidate: block.is_noise_candidate,
    is_header_footer_candidate: block.is_header_footer_candidate,
    is_artifact_candidate: block.is_artifact_candidate,
    is_caption_candidate: block.is_caption_candidate,
    is_table_cell_candidate: block.is_table_cell_candidate,
    dominant_language: block.dominant_language,
    writing_direction: block.writing_direction,
    _bbox: block._bbox,
    dominant_font_size: block.dominant_font_size,
    dominant_font_name: block.dominant_font_name,
    top_y: block.top_y,
    left_x: block.left_x,
    line_count: block.line_count,
    first_indent_left: block.first_indent_left,
    last_indent_left: block.last_indent_left,
    first_indent_right: block.first_indent_right,
    last_indent_right: block.last_indent_right,
    first_alignment_hint: block.first_alignment_hint,
    last_alignment_hint: block.last_alignment_hint,
    first_line_gap_before: block.first_line_gap_before,
    last_line_gap_after: block.last_line_gap_after,
    first_line_height: block.first_line_height,
    last_line_height: block.last_line_height,
    first_baseline_y: block.first_baseline_y,
    last_baseline_y: block.last_baseline_y,
    first_is_wrapped_candidate: block.first_is_wrapped_candidate,
    last_is_wrapped_candidate: block.last_is_wrapped_candidate,
    first_is_same_paragraph_with_prev_candidate: block.first_is_same_paragraph_with_prev_candidate,
    last_is_same_paragraph_with_prev_candidate: block.last_is_same_paragraph_with_prev_candidate,
  }
}

///|
/// 是否应该保留为 heading。
fn should_keep_heading(
  prev : PdfConvertBlock?,
  block : PdfConvertBlock,
  text : String,
  next : PdfConvertBlock?,
  max_heading : Int,
) -> Bool {
  let t = text.trim().to_owned()

  if t == "" {
    return false
  }

  if max_heading <= 0 {
    return false
  }

  if is_page_label_like(t) {
    return false
  }

  if looks_like_bullet_item(t) {
    return false
  }

  if looks_like_list_item_sentence(t) {
    return false
  }

  if looks_like_colon_label(t) {
    return false
  }

  if looks_like_side_marker_label_line(t) {
    return false
  }

  if ends_with_noise_tail(t) {
    return false
  }

  if looks_like_numbered_body_sentence(t) {
    return false
  }

  if is_obvious_body_sentence(t) {
    return false
  }

  if is_too_long_for_heading(t) {
    return false
  }

  // 页内上下文：后面跟明显正文时，更像真正标题
  if next_block_looks_like_body(next) &&
    looks_like_short_heading_text(t, max_heading) &&
    !@text.looks_like_intro_phrase(t) &&
    !looks_like_colon_label(t) &&
    !@text.looks_like_figure_or_table_caption(t) {
    return true
  }

  // 英文/章节式标题本身仍允许高置信保留
  if looks_like_short_heading_text(t, max_heading) &&
    !@text.looks_like_intro_phrase(t) &&
    !looks_like_colon_label(t) &&
    !@text.looks_like_figure_or_table_caption(t) {
    return true
  }

  // 某些标题后面直接跟列表项，也允许保留
  if next_block_looks_like_list_item(next) &&
    (looks_like_section_heading(t) || looks_like_short_english_heading(t)) {
    return true
  }

  // 前一个已经是 heading，当前是冒号标签/列表项时不要继续误判
  match prev {
    Some(p) =>
      if p.kind == PdfConvertBlockKind::Heading &&
        (looks_like_colon_label(t) || looks_like_bullet_item(t)) {
        return false
      }
    None => ()
  }
  if looks_like_layout_heading_candidate(prev, block, next, t) {
    return true
  }

  false
}

///|
/// 是否应该把 heading 降级成 paragraph。
fn should_demote_heading(
  prev : PdfConvertBlock?,
  block : PdfConvertBlock,
  text : String,
  next : PdfConvertBlock?,
) -> Bool {
  let t = text.trim().to_owned()

  if t == "" {
    return true
  }
  if block.is_heading_candidate &&
    block.line_count == 1 &&
    next_block_looks_like_body(next) &&
    !is_page_label_like(t) &&
    !looks_like_bullet_item(t) &&
    !looks_like_colon_label(t) &&
    !looks_like_numbered_body_sentence(t) &&
    !ends_with_noise_tail(t) &&
    !ends_with_strong_sentence_punct(t) &&
    t.length() <= 40 {
    return false
  }

  if is_page_label_like(t) {
    return true
  }

  if is_single_token_noise_like(t) {
    return true
  }

  if looks_like_bullet_item(t) {
    return true
  }

  if looks_like_list_item_sentence(t) {
    return true
  }

  if looks_like_colon_label(t) {
    return true
  }

  if looks_like_side_marker_label_line(t) {
    return true
  }

  if ends_with_noise_tail(t) {
    return true
  }

  if looks_like_numbered_body_sentence(t) {
    return true
  }

  if is_obvious_body_sentence(t) {
    return true
  }

  if is_too_long_for_heading(t) {
    return true
  }

  // 前一个块已经是 heading，当前块又只是短标签/项目符号时，降级
  match prev {
    Some(p) =>
      if p.kind == PdfConvertBlockKind::Heading &&
        (looks_like_colon_label(t) || looks_like_bullet_item(t)) {
        return true
      }
    None => ()
  }

  // 后面是明显正文但当前块本身并不像高置信标题，也降级
  if next_block_looks_like_body(next) &&
    !looks_like_section_heading(t) &&
    !looks_like_short_english_heading(t) &&
    !looks_like_short_cjk_heading(t) {
    return true
  }
  if looks_like_layout_heading_candidate(prev, block, next, t) {
    return false
  }

  false
}

///|
fn is_too_long_for_heading(text : String) -> Bool {
  text.length() > 80
}

///|
/// 明显像正文句子。
fn is_obvious_body_sentence(text : String) -> Bool {
  let t = text.trim().to_owned()

  if ends_with_strong_sentence_punct(t) {
    return true
  }

  if contains_body_like_phrase(t) {
    return true
  }

  false
}

///|
/// 第一版高置信标题文本。
fn looks_like_short_heading_text(text : String, max_heading : Int) -> Bool {
  let t = text.trim().to_owned()

  if t == "" {
    return false
  }

  if t.length() > 40 {
    return false
  }

  if max_heading <= 0 {
    return false
  }

  if looks_like_section_heading(t) {
    return true
  }

  if looks_like_short_english_heading(t) {
    return true
  }

  if looks_like_short_cjk_heading(t) {
    return true
  }

  false
}

///|
fn looks_like_page_section_heading(text : String) -> Bool {
  let t = text.trim().to_owned()

  if t == "" {
    return false
  }

  if is_page_label_like(t) {
    return false
  }

  if !(t.has_prefix("page ") || t.has_prefix("Page ")) {
    return false
  }

  if !contains_any_ascii_digit(t) {
    return false
  }

  // 至少得像 “page 2 new section” 这种，而不是纯 “Page 2”
  english_word_count(t) >= 3
}

///|
/// 章节/小节样式标题。
fn looks_like_section_heading(text : String) -> Bool {
  let t = text.trim().to_owned()

  t.has_prefix("第") ||
  starts_with_digit_section(t) ||
  starts_with_english_section_word(t) ||
  looks_like_page_section_heading(t)
}

///|
fn block_font_size(block : PdfConvertBlock?) -> Double? {
  match block {
    Some(b) => b.dominant_font_size
    None => None
  }
}

///|
fn is_visually_larger_than_neighbors(
  prev : PdfConvertBlock?,
  block : PdfConvertBlock,
  next : PdfConvertBlock?,
) -> Bool {
  match block.dominant_font_size {
    Some(cur) => {
      let prev_ok = match block_font_size(prev) {
        Some(v) => cur >= v + 0.5
        None => true
      }

      let next_ok = match block_font_size(next) {
        Some(v) => cur >= v + 0.5
        None => true
      }

      prev_ok && next_ok
    }
    None => false
  }
}

///|
fn looks_like_layout_heading_candidate(
  prev : PdfConvertBlock?,
  block : PdfConvertBlock,
  next : PdfConvertBlock?,
  text : String,
) -> Bool {
  let t = text.trim().to_owned()

  if t == "" {
    return false
  }

  if block.line_count != 1 {
    return false
  }

  if t.length() > 40 {
    return false
  }

  if @text.looks_like_intro_phrase(t) {
    return false
  }

  if @text.looks_like_figure_or_table_caption(t) {
    return false
  }

  if is_obvious_body_sentence(t) {
    return false
  }

  if looks_like_bullet_item(t) ||
    looks_like_list_item_sentence(t) ||
    looks_like_colon_label(t) ||
    looks_like_side_marker_label_line(t) {
    return false
  }

  if looks_like_numbered_body_sentence(t) {
    return false
  }

  // 太短的单 token（如 OK）不要靠 layout 抬成标题
  if english_word_count(t) <= 1 && t.length() <= 3 {
    return false
  }

  // 必须后面接正文或列表，说明自己像“段前标题”
  if !next_block_looks_like_body(next) && !next_block_looks_like_list_item(next) {
    return false
  }

  // 版面上要比邻居更大
  if !is_visually_larger_than_neighbors(prev, block, next) {
    return false
  }

  // 要么本身是短标题文本，要么前后文像段间标题
  if looks_like_short_heading_text(t, 6) {
    return true
  }

  false
}

///|
fn starts_with_digit_section(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  let arr = t.to_array()
  if arr.is_empty() {
    return false
  }

  let first = arr[0]
  if !is_digit_char(first) {
    return false
  }

  t.contains(".") || t.contains(")")
}

///|
fn starts_with_english_section_word(text : String) -> Bool {
  let t = text.trim().to_owned()
  t.has_prefix("Chapter ") ||
  t.has_prefix("Section ") ||
  t.has_prefix("Part ") ||
  t == "Introduction" ||
  t == "Method" ||
  t == "Conclusion" ||
  t == "Next Section"
}

///|
fn looks_like_short_english_heading(text : String) -> Bool {
  let t = text.trim().to_owned()

  if t == "" || t.length() > 40 {
    return false
  }

  if ends_with_strong_sentence_punct(t) {
    return false
  }

  if looks_like_colon_label(t) {
    return false
  }

  if ends_with_noise_tail(t) {
    return false
  }

  if looks_like_numbered_body_sentence(t) {
    return false
  }

  if contains_body_like_phrase(t) {
    return false
  }

  if !starts_with_upper_ascii(t) {
    return false
  }

  if english_word_count(t) > 4 {
    return false
  }

  true
}

///|
fn english_word_count(text : String) -> Int {
  let t = text.trim().to_owned()
  if t == "" {
    return 0
  }

  let mut count = 0
  let mut in_word = false

  for ch in t {
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
fn looks_like_short_cjk_heading(text : String) -> Bool {
  let t = text.trim().to_owned()

  if t == "" {
    return false
  }

  if t.length() < 2 || t.length() > 20 {
    return false
  }

  if ends_with_strong_sentence_punct(t) {
    return false
  }

  if looks_like_colon_label(t) {
    return false
  }

  if ends_with_noise_tail(t) {
    return false
  }

  if looks_like_numbered_body_sentence(t) {
    return false
  }

  if contains_body_like_phrase(t) {
    return false
  }

  true
}

///|
/// 页标签样式，当前都不保留成标题。
fn is_page_label_like(text : String) -> Bool {
  let t = text.trim().to_owned()

  t == "Page 1" ||
  t == "Page 2" ||
  t == "Page 3" ||
  t == "第 1 页" ||
  t == "第 2 页" ||
  t == "第 3 页" ||
  t.has_prefix("Page ") ||
  (t.has_prefix("第 ") && t.has_suffix(" 页")) ||
  (t.has_prefix("第") && t.has_suffix("页"))
}

///|
/// 单个短噪声样式。
fn is_single_token_noise_like(text : String) -> Bool {
  let t = text.trim().to_owned()

  t == "OK" || t == "ok" || t == "OK." || t == "OK!"
}

///|
/// 标题尾巴带短噪声。
fn ends_with_noise_tail(text : String) -> Bool {
  let t = text.trim().to_owned()
  t.has_suffix(" OK") || t.has_suffix(" ok")
}

///|
fn looks_like_bullet_item(text : String) -> Bool {
  let t = text.trim().to_owned()
  t == "•" || t.has_prefix("•") || t.has_prefix("- ") || t.has_prefix("* ")
}

///|
fn looks_like_list_item_sentence(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  if looks_like_bullet_item(t) {
    return true
  }

  let arr = t.to_array()
  let mut i = 0
  let mut has_digit = false

  while i < arr.length() {
    let c = arr[i]
    if is_digit_char(c) {
      has_digit = true
      i += 1
      continue
    }
    break
  }

  if has_digit && i + 1 < arr.length() {
    let c = arr[i]
    if (c == '.' || c == '、' || c == ')' || c == '）') && arr[i + 1] == ' ' {
      return true
    }
  }

  false
}

///|
/// 看起来像“Key points:”这类 label，而不是标题。
fn looks_like_colon_label(text : String) -> Bool {
  let t = text.trim().to_owned()
  t.has_suffix(":") || t.has_suffix("：")
}

///|
fn looks_like_side_marker_label_line(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" || !t.contains(" ") || !t.contains("-") {
    return false
  }

  let mut first = ""
  for sv in t.split(" ") {
    let w = sv.trim().to_owned()
    if w != "" {
      first = w
      break
    }
  }

  if first == "" {
    return false
  }

  if first.has_prefix("LEFT-") || first.has_prefix("RIGHT-") {
    return true
  }

  let mut has_upper = false
  for c in first.to_array() {
    let ok = (c >= 'A' && c <= 'Z') || is_digit_char(c) || c == '-'
    if !ok {
      return false
    }
    if c >= 'A' && c <= 'Z' {
      has_upper = true
    }
  }

  has_upper && first.contains("-")
}

///|
fn looks_like_numbered_body_sentence(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  let arr = t.to_array()
  if arr.is_empty() {
    return false
  }

  let first = arr[0]
  if !is_digit_char(first) {
    return false
  }

  let numbered = t.contains(". ") ||
    t.contains(") ") ||
    starts_with_tight_numbered_body_prefix(t)

  if !numbered {
    return false
  }

  if t.length() > 20 {
    return true
  }

  if contains_body_like_phrase(t) {
    return true
  }

  false
}

///|
fn starts_with_tight_numbered_body_prefix(text : String) -> Bool {
  let t = text.trim().to_owned()
  let arr = t.to_array()

  if arr.length() < 3 {
    return false
  }

  if !is_digit_char(arr[0]) {
    return false
  }

  let sep = arr[1]
  let next = arr[2]

  if sep != ')' && sep != '.' {
    return false
  }

  (next >= 'a' && next <= 'z') || is_cjk_char(next)
}

///|
fn contains_body_like_phrase(text : String) -> Bool {
  text.contains("remain") ||
  text.contains("because") ||
  text.contains("项目旨在") ||
  text.contains("应该") ||
  text.contains("这是") ||
  text.contains("This is") ||
  text.contains("It is ") ||
  text.contains("It should ")
}

///|
fn ends_with_strong_sentence_punct(text : String) -> Bool {
  let t = text.trim().to_owned()
  t.has_suffix(".") ||
  t.has_suffix("。") ||
  t.has_suffix("!") ||
  t.has_suffix("！") ||
  t.has_suffix("?") ||
  t.has_suffix("？")
}

///|
fn starts_with_upper_ascii(text : String) -> Bool {
  let t = text.trim().to_owned()
  let arr = t.to_array()
  if arr.is_empty() {
    return false
  }

  let code = arr[0].to_int()
  code >= 0x41 && code <= 0x5A
}

///|
fn next_block_looks_like_body(next : PdfConvertBlock?) -> Bool {
  match next {
    Some(b) => {
      let t = b.text.trim().to_owned()
      if t == "" {
        return false
      }

      if b.kind == PdfConvertBlockKind::Noise {
        return false
      }

      if is_page_label_like(t) {
        return false
      }

      if looks_like_bullet_item(t) {
        return false
      }

      is_obvious_body_sentence(t) || t.length() > 30
    }
    None => false
  }
}

///|
fn next_block_looks_like_list_item(next : PdfConvertBlock?) -> Bool {
  match next {
    Some(b) =>
      looks_like_bullet_item(b.text) ||
      looks_like_numbered_body_sentence(b.text)
    None => false
  }
}

///|
fn contains_any_ascii_digit(text : String) -> Bool {
  for ch in text {
    if is_digit_char(ch) {
      return true
    }
  }
  false
}
