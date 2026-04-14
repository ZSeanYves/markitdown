///|
const DEBUG_LINE_PIPELINE = false

///|
/// 页级 line 结果。
pub struct PdfPageLines {
  page_index : Int
  lines : Array[@model.PdfTextLine]
}

///|
/// 文档级 line 结果。
pub struct PdfDocumentLines {
  pages : Array[PdfPageLines]
}

///|
/// 从文档 spans 构建 lines。
pub fn build_document_lines(doc_spans : PdfDocumentSpans) -> PdfDocumentLines {
  let pages = Array::new()
  for page in doc_spans.pages {
    pages.push(build_page_lines(page))
  }
  { pages, }
}

///|
pub fn build_page_lines(page_spans : PdfPageSpans) -> PdfPageLines {
  let raw_lines = build_lines_from_spans(
    page_spans.page_index,
    page_spans.spans,
  )

  if DEBUG_LINE_PIPELINE {
    debug_print_lines("raw_lines", page_spans.page_index, raw_lines)
  }

  let normalized = normalize_line_texts(raw_lines)
  if DEBUG_LINE_PIPELINE {
    debug_print_lines("normalized", page_spans.page_index, normalized)
    debug_print_merge_reasons(page_spans.page_index, normalized)
  }

  let merged = merge_adjacent_lines(page_spans.page_index, normalized)
  if DEBUG_LINE_PIPELINE {
    debug_print_lines("merged", page_spans.page_index, merged)
  }

  let filtered = filter_noise_lines(merged)
  if DEBUG_LINE_PIPELINE {
    debug_print_lines("filtered", page_spans.page_index, filtered)
  }

  { page_index: page_spans.page_index, lines: filtered }
}

///|
fn debug_print_lines(
  stage : String,
  page_index : Int,
  lines : Array[@model.PdfTextLine],
) -> Unit {
  println(
    "== debug lines " +
    stage +
    " page=" +
    page_index.to_string() +
    " count=" +
    lines.length().to_string(),
  )

  for i = 0; i < lines.length(); i = i + 1 {
    let text = @model.line_text(lines[i]).trim().to_string()
    let short = if text.length() > 80 {
      text[:80].to_string() + "..."
    } else {
      text
    }

    println("  [" + i.to_string() + "] " + short)
  }
}

///|
fn debug_print_merge_reasons(
  page_index : Int,
  lines : Array[@model.PdfTextLine],
) -> Unit {
  println("== debug merge reasons page=" + page_index.to_string())

  if lines.length() <= 1 {
    return
  }

  for i = 0; i < lines.length() - 1; i = i + 1 {
    let left = lines[i]
    let right = lines[i + 1]
    let left_text = @model.line_text(left).trim().to_string()
    let right_text = @model.line_text(right).trim().to_string()

    let left_short = if left_text.length() > 40 {
      left_text[:40].to_string() + "..."
    } else {
      left_text
    }

    let right_short = if right_text.length() > 40 {
      right_text[:40].to_string() + "..."
    } else {
      right_text
    }

    println(
      "  [" +
      i.to_string() +
      " -> " +
      (i + 1).to_string() +
      "] " +
      explain_should_merge_lines(left, right) +
      " | left=\"" +
      left_short +
      "\"" +
      " | right=\"" +
      right_short +
      "\"",
    )
  }
}

///|
fn normalize_line_texts(
  lines : Array[@model.PdfTextLine],
) -> Array[@model.PdfTextLine] {
  let out = Array::new()
  for line in lines {
    out.push(normalize_single_line(line))
  }
  out
}

///|
fn normalize_single_line(line : @model.PdfTextLine) -> @model.PdfTextLine {
  let new_spans = Array::new()
  for span in line.spans {
    new_spans.push(normalize_single_span(span))
  }

  let bbox = @model.spans_bbox(new_spans).unwrap_or(default_rect())
  let source_refs = collect_span_source_refs(new_spans)

  {
    id: line.id,
    bbox,
    baseline_y: line.baseline_y,
    ascent: line.ascent,
    descent: line.descent,
    line_height: line.line_height,
    indent_left: line.indent_left,
    indent_right: line.indent_right,
    alignment_hint: line.alignment_hint,
    line_gap_before: line.line_gap_before,
    line_gap_after: line.line_gap_after,
    spans: new_spans,
    is_wrapped_candidate: line.is_wrapped_candidate,
    is_same_paragraph_with_prev_candidate: line.is_same_paragraph_with_prev_candidate,
    source_refs,
  }
}

///|
fn normalize_single_span(span : @model.PdfTextSpan) -> @model.PdfTextSpan {
  let new_text = normalize_text(span.text)

  {
    id: span.id,
    bbox: span.bbox,
    origin: span.origin,
    text: new_text,
    font_name: span.font_name,
    font_family: span.font_family,
    font_size: span.font_size,
    is_bold: span.is_bold,
    is_italic: span.is_italic,
    is_monospace: span.is_monospace,
    fill_color: span.fill_color,
    stroke_color: span.stroke_color,
    char_spacing: span.char_spacing,
    word_spacing: span.word_spacing,
    text_rise: span.text_rise,
    scale_x: span.scale_x,
    writing_direction: span.writing_direction,
    language_hint: span.language_hint,
    chars: span.chars,
    source_refs: span.source_refs,
    break_before: span.break_before,
    break_reason: span.break_reason,
  }
}

///|
fn normalize_text(text : String) -> String {
  let mut out = ""
  for ch in text {
    out = out + normalize_char_to_string(ch)
  }
  normalize_post_text(out)
}

///|
fn normalize_post_text(text : String) -> String {
  let t = text
  // 常见英文断词换行：inter- national -> international
  t.replace_all(old="- ", new="")
}

///|
fn normalize_char_to_string(ch : Char) -> String {
  match ch {
    '⼀' => "一"
    '⼆' => "二"
    '三' => "三"
    '⽂' => "文"
    '⽬' => "目"
    '⽤' => "用"
    '⾸' => "首"
    '⽀' => "支"
    'ﬁ' => "fi"
    'ﬂ' => "fl"
    '　' => " "
    _ => ch.to_string()
  }
}

///|
fn merge_adjacent_lines(
  page_index : Int,
  lines : Array[@model.PdfTextLine],
) -> Array[@model.PdfTextLine] {
  if lines.is_empty() {
    return []
  }

  let out = Array::new()
  let mut current = lines[0]
  let mut merged_index = 0

  for i = 1; i < lines.length(); i = i + 1 {
    let next = lines[i]
    if should_merge_lines(current, next) {
      current = merge_two_lines(page_index, merged_index, current, next)
    } else {
      out.push(current)
      merged_index = merged_index + 1
      current = next
    }
  }

  out.push(current)
  out
}

///|
/// 过滤明显噪声行。
///
/// 当前先做最保守版本：
/// - 去掉 trim 后为空的行
/// - 去掉非常短的纯数字页码候选（1~3 位数字）
///
/// 后续如果你接入了更稳定的位置/页边信息，再增强这里。
fn filter_noise_lines(
  lines : Array[@model.PdfTextLine],
) -> Array[@model.PdfTextLine] {
  let out = Array::new()

  for line in lines {
    let text = @model.line_text(line).trim()

    if text == "" {
      continue
    }

    if is_page_number_candidate(text.to_string()) {
      continue
    }

    out.push(line)
  }

  out
}

///|
fn should_merge_lines(
  left : @model.PdfTextLine,
  right : @model.PdfTextLine,
) -> Bool {
  let lt = @model.line_text(left).trim()
  let rt = @model.line_text(right).trim()

  if lt == "" || rt == "" {
    return false
  }

  if is_page_number_candidate(lt.to_string()) ||
    is_page_number_candidate(rt.to_string()) {
    return false
  }

  if right_is_explicit_break(right) {
    return false
  }

  if ends_with_strong_sentence_punct(lt.to_string()) {
    return false
  }

  // 关键：标题后接任何非标题内容，一律不并
  if looks_like_heading_line(lt.to_string()) &&
    !looks_like_heading_line(rt.to_string()) {
    return false
  }

  // 两个连续标题也不并
  if looks_like_heading_line(lt.to_string()) &&
    looks_like_heading_line(rt.to_string()) {
    return false
  }

  if looks_like_broken_english_word_pair(lt.to_string(), rt.to_string()) {
    return true
  }

  if looks_like_cjk_continuation_pair(lt.to_string(), rt.to_string()) {
    return true
  }

  if is_short_fragment(lt.to_string()) || is_short_fragment(rt.to_string()) {
    return true
  }

  if looks_like_body_line(lt.to_string()) &&
    looks_like_body_line(rt.to_string()) {
    return true
  }

  // 右侧是典型正文续写开头，也并
  if starts_with_body_continuation_prefix(rt.to_string()) &&
    !looks_like_heading_line(lt.to_string()) &&
    !looks_like_heading_line(rt.to_string()) {
    return true
  }

  if looks_like_body_or_fragment_line(lt.to_string()) &&
    looks_like_body_or_fragment_line(rt.to_string()) &&
    !looks_like_heading_line(lt.to_string()) &&
    !looks_like_heading_line(rt.to_string()) {
    return true
  }

  false
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
fn looks_like_body_or_fragment_line(text : String) -> Bool {
  let t = text.trim()
  if t == "" {
    return false
  }

  if looks_like_heading_line(t.to_string()) {
    return false
  }

  if is_page_number_candidate(t.to_string()) {
    return false
  }

  // 很短但明显是正文碎片，也允许
  if t.length() <= 8 {
    return true
  }

  true
}

///|
/// 从 span 数组构建 lines。
///
/// 第一版规则非常保守：
/// - 同 page
/// - 同 source_stream_index
/// - 同 source_op_index
/// - 同 text_object_id
///
/// 则继续归到同一 line。
///
/// 这意味着当前 line 更接近“提取/操作级行”，
/// 不是最终视觉布局意义上的 line。
pub fn build_lines_from_spans(
  page_index : Int,
  spans : Array[@model.PdfTextSpan],
) -> Array[@model.PdfTextLine] {
  if spans.is_empty() {
    return []
  }

  let out = Array::new()

  let mut current_spans : Array[@model.PdfTextSpan] = [spans[0]]
  let mut line_index = 0

  for i = 1; i < spans.length(); i = i + 1 {
    let prev = current_spans[current_spans.length() - 1]
    let cur = spans[i]

    if should_join_same_line(prev, cur) {
      current_spans.push(cur)
    } else {
      out.push(make_line_from_spans(page_index, line_index, current_spans))
      line_index = line_index + 1
      current_spans = [cur]
    }
  }

  out.push(make_line_from_spans(page_index, line_index, current_spans))
  out
}

///|
/// 判断两个 span 是否应归入同一最小 line。
fn should_join_same_line(
  left : @model.PdfTextSpan,
  right : @model.PdfTextSpan,
) -> Bool {
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

      // 关键新增：
      // 左边已经像标题，而右边不像标题，则不要继续并。
      if looks_like_heading_line(left.text) &&
        !looks_like_heading_line(right.text) {
        return false
      }

      if ends_with_strong_sentence_punct(left.text) {
        return false
      }

      true
    }
    _ => false
  }
}

///|
fn span_is_empty(span : @model.PdfTextSpan) -> Bool {
  span.text.trim() == ""
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
/// 取 span 的主 source ref。
fn primary_source_ref(span : @model.PdfTextSpan) -> @model.PdfSourceRef? {
  if span.source_refs.is_empty() {
    None
  } else {
    Some(span.source_refs[0])
  }
}

///|
/// 由 spans 构造一个最小 line。
pub fn make_line_from_spans(
  page_index : Int,
  line_index : Int,
  spans : Array[@model.PdfTextSpan],
) -> @model.PdfTextLine {
  let bbox = @model.spans_bbox(spans).unwrap_or(default_rect())
  let source_refs = collect_span_source_refs(spans)

  {
    id: make_line_id(page_index, line_index),
    bbox,
    baseline_y: None,
    ascent: None,
    descent: None,
    line_height: None,
    indent_left: None,
    indent_right: None,
    alignment_hint: None,
    line_gap_before: None,
    line_gap_after: None,
    spans,
    is_wrapped_candidate: false,
    is_same_paragraph_with_prev_candidate: false,
    source_refs,
  }
}

///|
/// 汇总 spans 的 source refs，并去重。
fn collect_span_source_refs(
  spans : Array[@model.PdfTextSpan],
) -> Array[@model.PdfSourceRef] {
  let out = Array::new()
  for span in spans {
    for src in span.source_refs {
      if !contains_source_ref(out, src) {
        out.push(src)
      }
    }
  }
  out
}

///|
fn contains_source_ref(
  refs : Array[@model.PdfSourceRef],
  target : @model.PdfSourceRef,
) -> Bool {
  for r in refs {
    if same_source_ref(r, target) {
      return true
    }
  }
  false
}

///|
fn make_line_id(page_index : Int, line_index : Int) -> String {
  "p" + page_index.to_string() + "_line_" + line_index.to_string()
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
fn merge_two_lines(
  page_index : Int,
  line_index : Int,
  left : @model.PdfTextLine,
  right : @model.PdfTextLine,
) -> @model.PdfTextLine {
  let spans = Array::new()
  for s in left.spans {
    spans.push(s)
  }
  for s in right.spans {
    spans.push(s)
  }

  let bbox = @model.spans_bbox(spans).unwrap_or(default_rect())
  let source_refs = collect_span_source_refs(spans)

  {
    id: make_line_id(page_index, line_index),
    bbox,
    baseline_y: None,
    ascent: None,
    descent: None,
    line_height: None,
    indent_left: None,
    indent_right: None,
    alignment_hint: None,
    line_gap_before: None,
    line_gap_after: None,
    spans,
    is_wrapped_candidate: true,
    is_same_paragraph_with_prev_candidate: false,
    source_refs,
  }
}

///|
fn is_page_number_candidate(text : String) -> Bool {
  let t = text.trim()
  if t == "" {
    return false
  }
  if t.length() > 3 {
    return false
  }
  all_ascii_digits(t.to_string())
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
fn looks_like_heading_line(text : String) -> Bool {
  let t = text.trim()
  if t == "" {
    return false
  }

  if ends_with_strong_sentence_punct(t.to_string()) {
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
fn looks_like_short_cjk_heading(text : String) -> Bool {
  let t = text.trim()

  if t == "" {
    return false
  }

  // 单字碎片不是标题
  if t.length() < 2 {
    return false
  }

  if t.length() > 8 {
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

  // 末字像正文动词/过程词，不当标题
  if ends_with_body_like_action_char(t.to_string()) {
    return false
  }

  true
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
fn looks_like_titlecase_heading(text : String) -> Bool {
  let t = text.trim()

  if t == "" || t.length() > 48 {
    return false
  }

  if ends_with_strong_sentence_punct(t.to_string()) {
    return false
  }

  // 连字符结尾通常是断词/正文，不是标题
  if t.has_suffix("-") {
    return false
  }

  // 词太多更像正文
  if word_count(t.to_string()) > 5 {
    return false
  }

  if contains_many_sentence_words(t.to_string()) {
    return false
  }

  starts_with_upper_ascii(t.to_string())
}

///|
fn word_count(text : String) -> Int {
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
fn looks_like_body_line(text : String) -> Bool {
  let t = text.trim()
  if t == "" {
    return false
  }

  t.length() >= 8
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
fn is_short_fragment(text : String) -> Bool {
  let t = text.trim()
  t != "" && t.length() <= 4
}

///|
fn looks_like_broken_english_word_pair(left : String, right : String) -> Bool {
  let l = left.trim()
  let r = right.trim()

  if l == "" || r == "" {
    return false
  }

  if looks_like_heading_line(l.to_string()) ||
    looks_like_heading_line(r.to_string()) {
    return false
  }

  let lc = last_char_opt(l.to_string())
  let rc = first_char_opt(r.to_string())

  match (lc, rc) {
    (Some(a), Some(b)) => {
      if !is_ascii_letter(a) || !is_ascii_letter(b) {
        return false
      }

      if ends_with_strong_sentence_punct(l.to_string()) {
        return false
      }

      let left_short = l.length() <= 12
      let right_short = r.length() <= 24

      left_short || right_short
    }
    _ => false
  }
}

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
  if is_short_fragment(lt) || is_short_fragment(rt) {
    return "join: short fragment"
  }
  if looks_like_body_line(lt) && looks_like_body_line(rt) {
    return "join: body-body continuation"
  }
  "split: fallback"
}

///|
fn looks_like_cjk_continuation_pair(left : String, right : String) -> Bool {
  let l = left.trim()
  let r = right.trim()

  if l == "" || r == "" {
    return false
  }

  if looks_like_heading_line(l.to_string()) ||
    looks_like_heading_line(r.to_string()) {
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
fn is_ascii_letter(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
}

///|
fn is_cjk_char(ch : Char) -> Bool {
  let code = ch.to_int()
  (code >= 0x4E00 && code <= 0x9FFF) ||
  (code >= 0x3400 && code <= 0x4DBF) ||
  (code >= 0xF900 && code <= 0xFAFF)
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
