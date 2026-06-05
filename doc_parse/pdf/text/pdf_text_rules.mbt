///|
/// 规则层：专门放 line 边界、heading/body/noise 判定规则。
/// 不放管线编排与模型组装逻辑。

///|
fn explain_should_merge_lines(
  left : @model.PdfTextLine,
  right : @model.PdfTextLine,
) -> String {
  let lt = @model.line_text(left).trim().to_owned()
  let rt = @model.line_text(right).trim().to_owned()

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
  if looks_like_broken_english_word_pair(lt, rt) &&
    lines_have_tight_fragment_continuation(left, right) {
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
  let lt = @model.line_text(left).trim().to_owned()
  let rt = @model.line_text(right).trim().to_owned()

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

  if looks_like_broken_english_word_pair(lt, rt) &&
    lines_have_tight_fragment_continuation(left, right) {
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
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  if !(t.has_suffix("：") || t.has_suffix(":")) {
    return false
  }

  let core = t[:t.length() - 1].trim().to_owned()
  let lower = core.to_lower()

  if lower == "key points" || core == "要点" {
    return false
  }

  true
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
        return !has_strong_vertical_separation(current_spans, right)
      }

      let current_text = normalize_text(spans_text(current_spans))
        .trim()
        .to_owned()
      let right_text = normalize_text(right.text).trim().to_owned()

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
        .to_owned()
      let right_text = normalize_text(right.text).trim().to_owned()
      let vertically_separated = has_strong_vertical_separation(
        current_spans, right,
      )

      // 先看版面：不像同一视觉行，直接断开
      if looks_like_new_visual_chunk(current_spans, right) {
        if !vertically_separated &&
          looks_like_broken_english_word_pair(current_text, right_text) {
          return true
        }

        if !vertically_separated &&
          looks_like_heading_prefix_text(current_text) &&
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
      true
    }
    _ => false
  }
}

///|
fn looks_like_heading_line(text : String) -> Bool {
  let t = text.trim().to_owned()
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
  let t = text.trim().to_owned()
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
  let t = text.trim().to_owned()
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
  let t = text.trim().to_owned()
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
  let t = text.trim().to_owned()
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
  let t = text.trim().to_owned()
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
  let t = text.trim().to_owned()

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
  let t = text.trim().to_owned()

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
  let l = left.trim().to_owned()
  let r = right.trim().to_owned()

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
  let l = left.trim().to_owned()
  let r = right.trim().to_owned()

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
  let l = @model.line_text(left_line).trim().to_owned()
  let r = @model.line_text(right_line).trim().to_owned()

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
  let t = text.trim().to_owned()
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
fn looks_like_complete_or_standalone_line(text : String) -> Bool {
  let t = text.trim().to_owned()
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
  let t = text.trim().to_owned()
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
/// 左侧是否像“纯标题前缀”，而不是已经进入正文残片。
fn looks_like_pure_heading_prefix(text : String) -> Bool {
  let t = text.trim().to_owned()
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
