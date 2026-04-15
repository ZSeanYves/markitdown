///|
/// 规则层：专门放 line 边界、heading/body/noise 判定规则。
/// 不放管线编排与模型组装逻辑。

///|
fn explain_should_merge_lines(
  left : @model.PdfTextLine,
  right : @model.PdfTextLine,
) -> String {
  let lt = @model.line_text(left).trim().to_string()
  let rt = @model.line_text(right).trim().to_string()

  if lt == "" || rt == "" {
    return "split: empty line"
  }
  if is_page_number_candidate(lt) || is_page_number_candidate(rt) {
    return "split: page number candidate"
  }
  if right_is_explicit_break(right) {
    return "split: explicit break on right"
  }
  if ends_with_strong_sentence_punct(lt) {
    return "split: strong sentence end"
  }
  if looks_like_heading_line(lt) && !looks_like_heading_line(rt) {
    return "split: heading then non-heading"
  }
  if looks_like_heading_line(lt) && looks_like_heading_line(rt) {
    return "split: consecutive headings"
  }
  if looks_like_broken_english_word_pair(lt, rt) {
    return "join: broken english word pair"
  }
  if looks_like_cjk_continuation_pair(lt, rt) {
    return "join: cjk continuation pair"
  }
  if should_merge_short_fragment_pair(left, right) {
    return "join: short fragment"
  }
  if looks_like_body_line(lt) && looks_like_body_line(rt) {
    return "join: body-body continuation"
  }
  "split: fallback"
}

///|
fn should_merge_lines(
  left : @model.PdfTextLine,
  right : @model.PdfTextLine,
) -> Bool {
  let lt = @model.line_text(left).trim().to_string()
  let rt = @model.line_text(right).trim().to_string()

  if lt == "" || rt == "" {
    return false
  }

  if is_page_number_candidate(lt) || is_page_number_candidate(rt) {
    return false
  }

  if right_is_explicit_break(right) {
    return false
  }

  if looks_like_bullet_line_text(lt) || looks_like_bullet_line_text(rt) {
    return false
  }

  if looks_like_intro_phrase(lt) {
    return false
  }

  if looks_like_cross_column_pair(left, right) {
    return false
  }

  if looks_like_paragraph_intro_line(lt) &&
    lines_look_like_same_paragraph(left, right) {
    return true
  }

  if looks_like_body_line(lt) &&
    looks_like_body_line(rt) &&
    lines_look_like_same_paragraph(left, right) {
    return true
  }

  if ends_with_strong_sentence_punct(lt) {
    return false
  }

  if looks_like_heading_line(lt) || looks_like_heading_line(rt) {
    return false
  }

  if looks_like_figure_or_table_caption(lt) ||
    looks_like_figure_or_table_caption(rt) {
    return false
  }

  if looks_like_list_intro_line(lt) || looks_like_list_intro_line(rt) {
    return false
  }

  if lines_look_like_same_paragraph(left, right) {
    return true
  }

  if looks_like_broken_english_word_pair(lt, rt) {
    return true
  }

  if looks_like_cjk_continuation_pair(lt, rt) {
    return true
  }

  if should_merge_short_fragment_pair(left, right) {
    return true
  }

  if starts_with_body_continuation_prefix(rt) {
    return true
  }

  false
}

///|
fn looks_like_bullet_line_text(text : String) -> Bool {
  let t = text.trim()
  if t == "" {
    return false
  }

  t.has_prefix("•") || t.has_prefix("- ") || t.has_prefix("* ")
}

///|
fn looks_like_paragraph_intro_line(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  if !(t.has_suffix("：") || t.has_suffix(":")) {
    return false
  }

  let core = t[:t.length() - 1].trim().to_string()
  let lower = core.to_lower()

  if lower == "key points" || core == "要点" {
    return false
  }

  true
}

///|
fn line_vertical_distance_close(
  left : @model.PdfTextLine,
  right : @model.PdfTextLine,
) -> Bool {
  match (left.baseline_y, right.baseline_y, left.line_height) {
    (Some(a), Some(b), Some(h)) => abs_double_rule(a - b) <= h * 1.8
    _ => true
  }
}

///|
fn lines_look_like_same_paragraph(
  left : @model.PdfTextLine,
  right : @model.PdfTextLine,
) -> Bool {
  if !line_font_size_close(left, right) {
    return false
  }

  if !line_indent_close(left, right) {
    return false
  }

  if !line_gap_paragraph_like(left) {
    return false
  }

  if looks_like_heading_line(@model.line_text(left).trim().to_string()) ||
    looks_like_heading_line(@model.line_text(right).trim().to_string()) {
    return false
  }

  if !line_vertical_distance_close(left, right) {
    return false
  }

  true
}

///|
fn line_font_size_close(
  left : @model.PdfTextLine,
  right : @model.PdfTextLine,
) -> Bool {
  match (line_dominant_font_size(left), line_dominant_font_size(right)) {
    (Some(a), Some(b)) => abs_double_rule(a - b) <= 0.75
    _ => true
  }
}

///|
fn line_indent_close(
  left : @model.PdfTextLine,
  right : @model.PdfTextLine,
) -> Bool {
  match (left.indent_left, right.indent_left) {
    (Some(a), Some(b)) => abs_double_rule(a - b) <= 8.0
    _ => true
  }
}

///|
fn line_gap_paragraph_like(left : @model.PdfTextLine) -> Bool {
  match (left.line_gap_after, left.line_height) {
    (Some(g), Some(h)) => g <= h * 0.7
    _ => true
  }
}

///|
fn line_dominant_font_size(line : @model.PdfTextLine) -> Double? {
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
fn should_join_same_line(
  current_spans : Array[@model.PdfTextSpan],
  right : @model.PdfTextSpan,
) -> Bool {
  if current_spans.is_empty() {
    return true
  }

  let left = current_spans[current_spans.length() - 1]
  let left_src = primary_source_ref(left)
  let right_src = primary_source_ref(right)

  match (left_src, right_src) {
    (Some(a), Some(b)) => {
      if a.page_index != b.page_index ||
        a.source_stream_index != b.source_stream_index {
        return false
      }

      if right.break_before {
        return false
      }

      if span_is_empty(left) || span_is_empty(right) {
        return true
      }

      let current_text = normalize_text(spans_text(current_spans))
        .trim()
        .to_string()
      let right_text = normalize_text(right.text).trim().to_string()

      // source/op 太远时，只有少数高置信例外允许继续并
      if !source_op_is_close(a, b) && !content_order_is_close(a, b) {
        if !looks_like_broken_english_word_pair(current_text, right_text) &&
          !(looks_like_heading_prefix_text(current_text) &&
          looks_like_short_cjk_heading_completion(right_text)) {
          return false
        }
      }
      let current_text = normalize_text(spans_text(current_spans))
        .trim()
        .to_string()
      let right_text = normalize_text(right.text).trim().to_string()

      // 先看版面：不像同一视觉行，直接断开
      if looks_like_new_visual_chunk(current_spans, right) {
        if looks_like_broken_english_word_pair(current_text, right_text) {
          return true
        }

        if looks_like_heading_prefix_text(current_text) &&
          looks_like_short_cjk_heading_completion(right_text) {
          return true
        }

        return false
      }

      // 行内高置信补并
      if looks_like_broken_english_word_pair(current_text, right_text) {
        return true
      }

      if looks_like_heading_prefix_text(current_text) &&
        looks_like_short_cjk_heading_completion(right_text) {
        return true
      }
      if current_text.contains("LEFT-A") || right_text.contains("RIGHT-B") {
        println(
          "[same-line-join] cur=\"" +
          current_text +
          "\" right=\"" +
          right_text +
          "\"",
        )
      }

      true
    }
    _ => false
  }
}

///|
fn is_page_number_candidate(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  // 纯数字页码
  if t.length() <= 4 && all_ascii_digits(t) {
    return true
  }

  // Page 3 / page 12
  if looks_like_simple_english_page_label(t) {
    return true
  }

  // 第 2 页 / 第2页
  if looks_like_simple_cjk_page_label(t) {
    return true
  }

  // 2/10
  if looks_like_fraction_page_label(t) {
    return true
  }

  // -3- / 3-4 / 3 - 4
  if looks_like_dash_page_label(t) {
    return true
  }

  false
}

///|
fn looks_like_simple_english_page_label(text : String) -> Bool {
  let t = text.trim().to_string()

  if !(t.has_prefix("Page ") || t.has_prefix("page ")) {
    return false
  }

  let tail = t[5:].trim().to_string()
  tail != "" && tail.length() <= 4 && all_ascii_digits(tail)
}

///|
fn looks_like_simple_cjk_page_label(text : String) -> Bool {
  let t = text.trim().to_string()

  if !(t.has_prefix("第") && (t.has_suffix("页") || t.has_suffix("⻚"))) {
    return false
  }

  let mid = t
    .replace_all(old="第", new="")
    .replace_all(old="页", new="")
    .replace_all(old="⻚", new="")
    .trim()
    .to_string()

  mid != "" && mid.length() <= 4 && all_ascii_digits(mid)
}

///|
fn looks_like_fraction_page_label(text : String) -> Bool {
  let t = text.trim().to_string()

  let parts : Array[String] = Array::new()
  for part in t.split("/") {
    parts.push(part.to_string())
  }

  if parts.length() != 2 {
    return false
  }

  let left = parts[0].trim().to_string()
  let right = parts[1].trim().to_string()

  left != "" &&
  right != "" &&
  left.length() <= 4 &&
  right.length() <= 4 &&
  all_ascii_digits(left) &&
  all_ascii_digits(right)
}

///|
fn looks_like_page_prefixed_section_heading(text : String) -> Bool {
  let t = text.trim().to_string()
  let lt = t.to_lower()

  if !lt.has_prefix("page ") {
    return false
  }

  let words : Array[String] = Array::new()
  for sv in t.split(" ") {
    let w = sv.to_string().trim().to_string()
    if w != "" {
      words.push(w)
    }
  }

  if words.length() < 4 || words.length() > 6 {
    return false
  }

  if words[0].to_lower() != "page" {
    return false
  }

  if !all_ascii_digits(words[1]) {
    return false
  }

  // 至少还要有两个正文词，避免把 Page 2 当 heading
  true
}

///|
fn looks_like_dash_page_label(text : String) -> Bool {
  let t = text.trim().to_string()
  if t.length() > 12 {
    return false
  }

  let normalized = t.replace_all(old=" ", new="")
  if !normalized.contains("-") {
    return false
  }

  let parts = normalized.split("-")
  let mut non_empty = 0

  for p in parts {
    let s = p.to_string().trim().to_string()
    if s != "" {
      if !all_ascii_digits(s) {
        return false
      }
      non_empty += 1
    }
  }

  non_empty >= 1 && non_empty <= 2
}

///|
fn looks_like_heading_line(text : String) -> Bool {
  let t = text.trim()
  if t == "" {
    return false
  }

  if ends_with_strong_sentence_punct(t.to_string()) {
    return false
  }

  if looks_like_figure_or_table_caption(t.to_string()) {
    return false
  }

  if looks_like_list_intro_line(t.to_string()) {
    return false
  }

  if looks_like_intro_phrase(t.to_string()) {
    return false
  }
  if looks_like_page_prefixed_section_heading(t.to_string()) {
    return true
  }

  if looks_like_numbered_body_sentence(t.to_string()) {
    return false
  }

  if looks_like_all_caps_body_line(t.to_string()) {
    return false
  }

  if looks_like_short_cjk_heading(t.to_string()) {
    return true
  }

  if looks_like_titlecase_heading(t.to_string()) {
    return true
  }

  false
}

///|
fn looks_like_body_line(text : String) -> Bool {
  let t = text.trim()
  if t == "" {
    return false
  }

  if looks_like_heading_line(t.to_string()) {
    return false
  }

  if looks_like_section_or_page_prefix(t.to_string()) {
    return false
  }

  if is_page_noise_like(t.to_string()) {
    return false
  }

  if ends_with_strong_sentence_punct(t.to_string()) {
    return true
  }

  t.length() >= 16
}

///|
fn looks_like_section_or_page_prefix(text : String) -> Bool {
  let t = text.trim()
  if t == "" {
    return false
  }

  if t.has_prefix("第") &&
    (t.contains("章") || t.contains("节") || t.contains("页")) {
    return true
  }

  if t.has_prefix("page ") || t.has_prefix("Page ") {
    return true
  }

  if starts_with_numbered_heading_prefix(t.to_string()) {
    return true
  }

  false
}

///|
fn starts_with_numbered_heading_prefix(text : String) -> Bool {
  let t = text.trim()
  if t == "" {
    return false
  }

  let first = first_char_opt(t.to_string())
  match first {
    Some(ch) => if ch < '0' || ch > '9' { return false }
    _ => return false
  }

  t.contains(". ") ||
  t.contains(") ") ||
  t.has_prefix("1.") ||
  t.has_prefix("2.") ||
  t.has_prefix("3.") ||
  t.has_prefix("1.1") ||
  t.has_prefix("1.2") ||
  t.has_prefix("2.1")
}

///|
fn looks_like_heading_prefix_text(text : String) -> Bool {
  let t = text.trim()
  if t == "" {
    return false
  }

  if ends_with_strong_sentence_punct(t.to_string()) {
    return false
  }

  if looks_like_section_or_page_prefix(t.to_string()) {
    return true
  }

  if starts_with_numbered_heading_prefix(t.to_string()) {
    return true
  }

  false
}

///|
fn looks_like_short_cjk_heading_completion(text : String) -> Bool {
  let t = text.trim()
  if t == "" {
    return false
  }

  if t.length() < 2 || t.length() > 4 {
    return false
  }

  if !all_cjk_chars(t.to_string()) {
    return false
  }

  t == "概述" ||
  t == "目标" ||
  t == "背景" ||
  t == "方法" ||
  t == "结果" ||
  t == "讨论" ||
  t == "结论" ||
  t == "路线" ||
  t == "设计" ||
  t == "方案"
}

///|
fn looks_like_short_cjk_heading(text : String) -> Bool {
  let t = text.trim()

  if t == "" {
    return false
  }

  if t.length() < 4 || t.length() > 8 {
    return false
  }

  if t.contains(" ") {
    return false
  }

  if t.contains("：") || t.contains(":") {
    return false
  }

  if starts_with_body_like_prefix(t.to_string()) {
    return false
  }

  if ends_with_weak_body_suffix(t.to_string()) {
    return false
  }

  if ends_with_body_like_action_char(t.to_string()) {
    return false
  }

  // 新增：纯中文短标题必须命中一个更窄的标题词表，避免把正文碎片抬成 heading
  if !looks_like_known_short_cjk_heading_text(t.to_string()) {
    return false
  }

  true
}

///|
fn looks_like_known_short_cjk_heading_text(text : String) -> Bool {
  text == "概述" ||
  text == "目标" ||
  text == "背景" ||
  text == "方法" ||
  text == "结果" ||
  text == "讨论" ||
  text == "结论" ||
  text == "路线" ||
  text == "设计" ||
  text == "方案" ||
  text == "技术路线" ||
  text == "研究目标" ||
  text == "研究内容"
}

///|
fn looks_like_titlecase_heading(text : String) -> Bool {
  let t = text.trim()

  if t == "" || t.length() > 48 {
    return false
  }

  if ends_with_strong_sentence_punct(t.to_string()) {
    return false
  }

  if t.has_suffix("-") {
    return false
  }

  let wc = word_count(t.to_string())

  if wc == 1 && t.length() < 4 {
    return false
  }

  if wc > 5 {
    return false
  }

  if contains_many_sentence_words(t.to_string()) {
    return false
  }

  if !starts_with_upper_ascii(t.to_string()) {
    return false
  }

  wc >= 2 || t.length() >= 8
}

///|
fn looks_like_broken_english_word_pair(left : String, right : String) -> Bool {
  let l = left.trim()
  let r = right.trim()

  if l == "" || r == "" {
    return false
  }

  if ends_with_strong_sentence_punct(l.to_string()) {
    return false
  }

  let left_tail = last_ascii_word(l.to_string())
  let right_head = first_ascii_word(r.to_string())

  if left_tail == "" || right_head == "" {
    return false
  }

  let lc = last_char_opt(left_tail)
  let rc = first_char_opt(right_head)

  match (lc, rc) {
    (Some(a), Some(b)) => {
      if !is_ascii_letter(a) || !is_ascii_letter(b) {
        return false
      }

      if !(b >= 'a' && b <= 'z') {
        return false
      }

      left_tail.length() >= 2 &&
      left_tail.length() <= 8 &&
      right_head.length() >= 2 &&
      right_head.length() <= 24
    }
    _ => false
  }
}

///|
fn looks_like_cjk_continuation_pair(left : String, right : String) -> Bool {
  let l = left.trim()
  let r = right.trim()

  if l == "" || r == "" {
    return false
  }

  if !is_cjk_char_opt_boundary(l.to_string(), r.to_string()) {
    return false
  }

  if looks_like_heading_line(l.to_string()) ||
    looks_like_heading_line(r.to_string()) {
    return false
  }

  if looks_like_pure_heading_prefix(l.to_string()) {
    return false
  }

  if starts_with_body_like_prefix(r.to_string()) &&
    !looks_like_body_fragment_suffix(l.to_string()) {
    return false
  }

  if ends_with_strong_sentence_punct(l.to_string()) {
    return false
  }

  let lc = last_char_opt(l.to_string())
  let rc = first_char_opt(r.to_string())

  match (lc, rc) {
    (Some(a), Some(b)) =>
      (is_cjk_char(a) || is_ascii_letter(a)) &&
      (is_cjk_char(b) || is_ascii_letter(b))
    _ => false
  }
}

///|
fn should_merge_short_fragment_pair(
  left_line : @model.PdfTextLine,
  right_line : @model.PdfTextLine,
) -> Bool {
  let l = @model.line_text(left_line).trim().to_string()
  let r = @model.line_text(right_line).trim().to_string()

  if l == "" || r == "" {
    return false
  }

  if looks_like_heading_line(l) || looks_like_heading_line(r) {
    return false
  }

  if is_page_number_candidate(l) || is_page_number_candidate(r) {
    return false
  }

  if looks_like_bullet_like_fragment(l) || looks_like_bullet_like_fragment(r) {
    return false
  }

  // 必须先满足版面上像同段 continuation
  if !lines_look_like_same_paragraph(left_line, right_line) {
    return false
  }

  // 左边短，但不能是明显独立 token
  if is_short_fragment(l) &&
    !looks_like_standalone_short_line(l) &&
    !looks_like_complete_or_standalone_line(r) {
    return true
  }

  // 右边短续接到左边，也要满足不是独立 token
  if looks_like_body_line(l) &&
    is_short_fragment(r) &&
    !starts_with_upper_ascii(r) &&
    !looks_like_standalone_short_line(r) {
    return true
  }

  false
}

///|
fn looks_like_standalone_short_line(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  // 很短但像独立行，而不是词内碎片
  if t.length() > 4 {
    return false
  }

  if t.has_suffix("-") {
    return false
  }

  if contains_any_ascii_digit(t) {
    return true
  }

  if all_ascii_letters(t) {
    // 全大写短 token 更像独立标签/短行，不像词内断裂
    let lower = t.to_lower()
    if t == t.to_upper() {
      return true
    }

    // 太短的普通单词也默认按独立 token 处理
    if lower == "ok" || lower == "yes" || lower == "no" {
      return true
    }
  }

  false
}

///|
fn looks_like_cross_column_pair(
  left : @model.PdfTextLine,
  right : @model.PdfTextLine,
) -> Bool {
  if !line_vertical_distance_close(left, right) {
    return false
  }

  let lx0 = left.bbox.x0
  let lx1 = left.bbox.x1
  let rx0 = right.bbox.x0
  let rx1 = right.bbox.x1

  let gap_lr = rx0 - lx1
  let gap_rl = lx0 - rx1

  let horizontal_gap = if gap_lr > 0.0 {
    gap_lr
  } else if gap_rl > 0.0 {
    gap_rl
  } else {
    0.0
  }

  let ref_h = match (left.line_height, right.line_height) {
    (Some(a), Some(b)) => if a > b { a } else { b }
    (Some(a), None) => a
    (None, Some(b)) => b
    (None, None) => 12.0
  }

  let indent_far = match (left.indent_left, right.indent_left) {
    (Some(a), Some(b)) => abs_double_rule(a - b) >= ref_h * 3.0
    _ => false
  }

  horizontal_gap >= ref_h * 2.5 || indent_far
}

///|
fn looks_like_complete_or_standalone_line(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  if ends_with_strong_sentence_punct(t) {
    return true
  }

  if looks_like_body_line(t) && word_count(t) >= 4 {
    return true
  }

  false
}

///|
fn looks_like_bullet_like_fragment(text : String) -> Bool {
  let t = text.trim()
  t.has_prefix("•") || t.has_prefix("-") || t.has_prefix("*")
}

///|
fn starts_with_body_continuation_prefix(text : String) -> Bool {
  let t = text.trim()
  t.has_prefix("然后") ||
  t.has_prefix("并且") ||
  t.has_prefix("以及") ||
  t.has_prefix("同时") ||
  t.has_prefix("随后") ||
  t.has_prefix("接着")
}

///|
fn looks_like_body_fragment_suffix(text : String) -> Bool {
  let t = text.trim()
  if t == "" {
    return false
  }

  if ends_with_strong_sentence_punct(t.to_string()) {
    return false
  }

  if t.length() < 6 {
    return false
  }

  if looks_like_section_or_page_prefix(t.to_string()) && t.length() >= 10 {
    return true
  }

  true
}

///|
fn is_page_noise_like(text : String) -> Bool {
  let t = text.trim()
  if t == "" {
    return false
  }

  if t.has_prefix("第") && t.contains("页") {
    return true
  }

  if t.has_prefix("Page ") || t.has_prefix("page ") {
    return true
  }

  if t.contains("/") {
    return true
  }

  if t.contains("-") && contains_any_ascii_digit(t.to_string()) {
    return true
  }

  false
}

///|
fn starts_with_body_like_prefix(text : String) -> Bool {
  let t = text.trim()
  t.has_prefix("首先") ||
  t.has_prefix("其中") ||
  t.has_prefix("以及") ||
  t.has_prefix("并且") ||
  t.has_prefix("最后") ||
  t.has_prefix("为了") ||
  t.has_prefix("通过") ||
  t.has_prefix("使用") ||
  t.has_prefix("这是") ||
  t.has_prefix("这个") ||
  t.has_prefix("本") ||
  t.has_prefix("该") ||
  t.has_prefix("用于") ||
  t.has_prefix("对于") ||
  t.has_prefix("因为")
}

///|
fn contains_many_sentence_words(text : String) -> Bool {
  let t = text.to_lower()
  t.contains(" is ") ||
  t.contains(" are ") ||
  t.contains(" was ") ||
  t.contains(" were ") ||
  t.contains(" to ") ||
  t.contains(" of ") ||
  t.contains(" and ") ||
  t.contains(" for ") ||
  t.contains(" the ")
}

///|
fn ends_with_weak_body_suffix(text : String) -> Bool {
  let t = text.trim()
  t.has_suffix("的") ||
  t.has_suffix("了") ||
  t.has_suffix("是") ||
  t.has_suffix("为") ||
  t.has_suffix("中") ||
  t.has_suffix("上") ||
  t.has_suffix("下") ||
  t.has_suffix("：") ||
  t.has_suffix(":") ||
  t.has_suffix("，") ||
  t.has_suffix(",")
}

///|
fn ends_with_body_like_action_char(text : String) -> Bool {
  let t = text.trim()
  t.has_suffix("完") ||
  t.has_suffix("成") ||
  t.has_suffix("持") ||
  t.has_suffix("研") ||
  t.has_suffix("转") ||
  t.has_suffix("换")
}

///|
fn is_short_fragment(text : String) -> Bool {
  let t = text.trim()
  t != "" && t.length() <= 4
}

///|
fn ends_with_strong_sentence_punct(text : String) -> Bool {
  let t = text.trim()
  t.has_suffix(".") ||
  t.has_suffix("!") ||
  t.has_suffix("?") ||
  t.has_suffix("。") ||
  t.has_suffix("！") ||
  t.has_suffix("？")
}

///|
fn starts_with_upper_ascii(text : String) -> Bool {
  if text.length() == 0 {
    return false
  }
  let c = text[0]
  c >= 'A' && c <= 'Z'
}

///|
fn contains_any_ascii_digit(text : String) -> Bool {
  for ch in text {
    if ch >= '0' && ch <= '9' {
      return true
    }
  }
  false
}

///|
fn all_ascii_digits(text : String) -> Bool {
  if text.length() == 0 {
    return false
  }
  for ch in text {
    if ch < '0' || ch > '9' {
      return false
    }
  }
  true
}

///|
fn all_cjk_chars(text : String) -> Bool {
  if text.length() == 0 {
    return false
  }

  for ch in text {
    if !is_cjk_char(ch) {
      return false
    }
  }

  true
}

///|
fn span_is_empty(span : @model.PdfTextSpan) -> Bool {
  span.text.trim() == ""
}

///|
fn right_is_explicit_break(line : @model.PdfTextLine) -> Bool {
  for span in line.spans {
    if span.break_before {
      return true
    }
  }
  false
}

///|
fn spans_text(spans : Array[@model.PdfTextSpan]) -> String {
  let mut buf = ""
  for s in spans {
    buf = buf + s.text
  }
  buf
}

///|
fn primary_source_ref(span : @model.PdfTextSpan) -> @model.PdfSourceRef? {
  if span.source_refs.is_empty() {
    None
  } else {
    Some(span.source_refs[0])
  }
}

///|
fn source_op_is_close(
  left : @model.PdfSourceRef,
  right : @model.PdfSourceRef,
) -> Bool {
  let diff = right.source_op_index - left.source_op_index
  diff >= 0 && diff <= 12
}

///|
fn content_order_is_close(
  left : @model.PdfSourceRef,
  right : @model.PdfSourceRef,
) -> Bool {
  match (left.content_order_index, right.content_order_index) {
    (Some(a), Some(b)) => {
      let diff = b - a
      diff >= 0 && diff <= 12
    }
    _ => true
  }
}

///|
fn is_cjk_char(ch : Char) -> Bool {
  let code = ch.to_int()
  (code >= 0x4E00 && code <= 0x9FFF) ||
  (code >= 0x3400 && code <= 0x4DBF) ||
  (code >= 0xF900 && code <= 0xFAFF)
}

///|
fn is_cjk_char_opt_boundary(left : String, right : String) -> Bool {
  let lc = last_char_opt(left)
  let rc = first_char_opt(right)

  match (lc, rc) {
    (Some(a), Some(b)) => is_cjk_char(a) || is_cjk_char(b)
    _ => false
  }
}

///|
fn first_char_opt(text : String) -> Char? {
  for ch in text {
    return Some(ch)
  }
  None
}

///|
fn last_char_opt(text : String) -> Char? {
  let mut last : Char? = None
  for ch in text {
    last = Some(ch)
  }
  last
}

///|
fn first_ascii_word(text : String) -> String {
  let mut out = ""
  let mut started = false

  for ch in text {
    if is_ascii_letter(ch) {
      out = out + ch.to_string()
      started = true
    } else if started {
      break
    }
  }

  out
}

///|
fn last_ascii_word(text : String) -> String {
  let arr = text.to_array()
  if arr.is_empty() {
    return ""
  }

  let mut end = -1
  let mut start = -1
  let mut i = arr.length() - 1

  while i >= 0 {
    let ch = arr[i]
    if is_ascii_letter(ch) {
      if end < 0 {
        end = i
      }
      start = i
      if i == 0 {
        break
      }
      i = i - 1
    } else if end >= 0 {
      break
    } else {
      if i == 0 {
        break
      }
      i = i - 1
    }
  }

  if start < 0 || end < 0 {
    return ""
  }

  text[start:end + 1].to_string()
}

///|
pub fn word_count(text : String) -> Int {
  let t = text.trim()
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
pub fn looks_like_figure_or_table_caption(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  t.has_prefix("Figure ") ||
  t.has_prefix("Fig. ") ||
  t.has_prefix("Table ") ||
  t.has_prefix("图 ") ||
  t.has_prefix("表 ")
}

///|
fn looks_like_list_intro_line(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  if ends_with_strong_sentence_punct(t) {
    return false
  }

  t.has_suffix(":") ||
  t.has_suffix("：") ||
  t == "Key points" ||
  t == "Key points:" ||
  t == "要点" ||
  t == "要点："
}

///|
pub fn looks_like_intro_phrase(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  t.has_prefix("In conclusion,") ||
  t.has_prefix("For example,") ||
  t.has_prefix("For instance,") ||
  t.has_prefix("首先，") ||
  t.has_prefix("最后，")
}

///|
fn looks_like_numbered_body_sentence(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  let prefix_ok = t.has_prefix("1. ") ||
    t.has_prefix("2. ") ||
    t.has_prefix("3. ") ||
    t.has_prefix("1)") ||
    t.has_prefix("2)") ||
    t.has_prefix("3)")

  if !prefix_ok {
    return false
  }

  word_count(t) >= 4 || ends_with_strong_sentence_punct(t)
}

///|
fn looks_like_all_caps_body_line(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  if ends_with_strong_sentence_punct(t) {
    return true
  }

  false
}

///|
/// 左侧是否像“纯标题前缀”，而不是已经进入正文残片。
fn looks_like_pure_heading_prefix(text : String) -> Bool {
  let t = text.trim()
  if t == "" {
    return false
  }

  if !looks_like_section_or_page_prefix(t.to_string()) {
    return false
  }

  // 太长通常已经混入正文，不算纯标题前缀
  if t.length() > 14 {
    return false
  }

  // 明显正文式起头，不算纯标题
  if starts_with_body_like_prefix(t.to_string()) {
    return false
  }

  true
}

///|
/// 当前累计 spans 的右边界。
fn current_line_right_x(spans : Array[@model.PdfTextSpan]) -> Double {
  if spans.is_empty() {
    return 0.0
  }

  let mut x = spans[0].bbox.x1
  for span in spans {
    if span.bbox.x1 > x {
      x = span.bbox.x1
    }
  }
  x
}

///|
/// 当前累计 spans 的左边界。
fn current_line_left_x(spans : Array[@model.PdfTextSpan]) -> Double {
  if spans.is_empty() {
    return 0.0
  }

  let mut x = spans[0].bbox.x0
  for span in spans {
    if span.bbox.x0 < x {
      x = span.bbox.x0
    }
  }
  x
}

///|
/// 是否像“同一视觉行里的跨列切换”。
///
/// 典型场景：
/// - 左侧已经是一整句独立内容
/// - 右侧又在同一 y 上，从很靠右的位置重新开始另一句
/// - 单靠 current_line_right_x 可能检测不到 gap，因此补一个“相对起点的大横向跳跃”判断
fn looks_like_cross_column_same_row_chunk(
  current_spans : Array[@model.PdfTextSpan],
  right : @model.PdfTextSpan,
) -> Bool {
  if current_spans.is_empty() {
    return false
  }

  if !nearly_same_visual_line(current_spans, right) {
    return false
  }

  let current_text = normalize_text(spans_text(current_spans))
    .trim()
    .to_string()
  let right_text = normalize_text(right.text).trim().to_string()

  if current_text == "" || right_text == "" {
    return false
  }

  // 左边必须已经像一段独立内容，而不是词内碎片
  if !ends_with_strong_sentence_punct(current_text) {
    return false
  }

  if word_count(current_text) < 5 {
    return false
  }

  // 右边也要像另一段独立起点
  if !starts_with_upper_ascii(right_text) &&
    !looks_like_section_or_page_prefix(right_text) {
    return false
  }

  if word_count(right_text) < 4 {
    return false
  }

  let line_left = current_line_left_x(current_spans)
  let right_x = right.origin.x
  let fs = current_line_font_size(current_spans).unwrap_or(12.0)

  // 相对当前行起点出现很大的横向跳跃，更像右栏重新开始
  let x_jump = right_x - line_left
  x_jump >= fs * 14.0
}

///|
/// 当前累计 spans 的基线 y，先用 origin.y 平均值粗估。
fn current_line_baseline_y(spans : Array[@model.PdfTextSpan]) -> Double {
  if spans.is_empty() {
    return 0.0
  }

  let mut total = 0.0
  for span in spans {
    total = total + span.origin.y
  }
  total / spans.length().to_double()
}

///|
/// 当前累计 spans 的主字号，先取最大值。
fn current_line_font_size(spans : Array[@model.PdfTextSpan]) -> Double? {
  if spans.is_empty() {
    return None
  }

  let mut best = 0.0
  let mut seen = false
  for span in spans {
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
fn abs_double_rule(x : Double) -> Double {
  if x < 0.0 {
    -x
  } else {
    x
  }
}

///|
/// 是否近似同一视觉行。
fn nearly_same_visual_line(
  current_spans : Array[@model.PdfTextSpan],
  right : @model.PdfTextSpan,
) -> Bool {
  let cur_y = current_line_baseline_y(current_spans)
  let right_y = right.origin.y
  let cur_fs = current_line_font_size(current_spans).unwrap_or(12.0)
  let right_fs = right.font_size.unwrap_or(cur_fs)
  let tol = (if cur_fs > right_fs { cur_fs } else { right_fs }) * 0.35

  abs_double_rule(cur_y - right_y) <= tol
}

///|
/// 字号是否近似一致。
fn nearly_same_font_size_opt(a : Double?, b : Double?) -> Bool {
  match (a, b) {
    (Some(x), Some(y)) => abs_double_rule(x - y) <= 0.75
    _ => true
  }
}

///|
/// 当前累计 spans 和右侧 span 之间是否出现明显水平空隙。
fn has_large_horizontal_gap(
  current_spans : Array[@model.PdfTextSpan],
  right : @model.PdfTextSpan,
) -> Bool {
  if current_spans.is_empty() {
    return false
  }

  let cur_right = current_line_right_x(current_spans)
  let gap = right.origin.x - cur_right
  let fs = current_line_font_size(current_spans).unwrap_or(12.0)

  // gap 大于约 0.8em，通常就不该继续吸进同一行内片段
  gap > fs * 0.8
}

///|
/// 右侧 span 是否更像“新块起点”而不是同一行续写。
fn looks_like_new_visual_chunk(
  current_spans : Array[@model.PdfTextSpan],
  right : @model.PdfTextSpan,
) -> Bool {
  if !nearly_same_visual_line(current_spans, right) {
    return true
  }

  if !nearly_same_font_size_opt(
      current_line_font_size(current_spans),
      right.font_size,
    ) {
    return true
  }

  if has_large_horizontal_gap(current_spans, right) {
    return true
  }

  // 关键补充：同一 y 上从很靠右的位置重新开始另一句，视为新块
  if looks_like_cross_column_same_row_chunk(current_spans, right) {
    return true
  }

  false
}
