///|
fn native_document_to_pages(
  native : @pdfc.PdfNativeDocumentResult,
) -> Array[PdfConvertPage] {
  let out : Array[PdfConvertPage] = []
  for page in native.pages {
    out.push({
      page_index: page.page_index,
      lines: events_to_lines(page.page_index, page.events),
    })
  }
  out
}

///|
/// 设计目标：
/// - 只恢复“行”，不提前做 heading/list 结构判断
/// - 显式 break 优先
/// - 同 stream + 邻近 op 才考虑继续吸收
/// - 对短碎片 / coalesced / 非句末 continuation 更宽容
fn events_to_lines(
  page_index : Int,
  events : Array[@pdfc.PdfTextEvent],
) -> Array[PdfConvertLine] {
  let lines : Array[PdfConvertLine] = []

  let mut cur = ""
  let mut start = -1
  let mut end = -1

  let mut prev_stream = -1
  let mut prev_op = -1
  let mut prev_font_name = ""
  let mut prev_font_size = 0.0

  let mut i = 0
  while i < events.length() {
    let ev = events[i]
    let text = normalize_line_text(ev.text)
    let cur_font_name = option_string_or_empty(ev.font_name)
    let cur_font_size = option_f64_or_zero(ev.font_size)

    let line_break = has_explicit_line_break(ev.break_kind, ev.text)
    let para_break = has_explicit_paragraph_break(ev.break_kind, ev.text)
    debug_log_event(i, page_index, ev, text)

    if text != "" {
      if cur == "" {
        cur = text
        start = i
        end = i
      } else {
        let heading_like_cur = is_heading_like_short_line(cur)
        let cur_has_boundary_punct = has_boundary_punct_event(cur)
        let next_starts_like_body = starts_like_body_sentence(text)
        let next_is_heading_like = is_conservative_heading_like_next_event(text)
        let stream_changed = prev_stream != ev.source_stream_index
        let op_changed = ev.source_op_index > prev_op
        let should_flush_before_append = should_flush_line_before_appending(
          cur,
          text,
          prev_stream,
          prev_op,
          ev.source_stream_index,
          ev.source_op_index,
        )
        debug_log_append_decision(
          cur,
          text,
          should_flush_before_append,
          heading_like_cur,
          cur_has_boundary_punct,
          next_starts_like_body,
          next_is_heading_like,
          stream_changed,
          op_changed,
        )

        if should_flush_before_append {
          flush_line(
            lines,
            page_index,
            cur,
            start,
            end,
            false,
            "heading_like_before_body",
          )
          cur = text
          start = i
          end = i
        } else if should_attach_to_current_line(
          cur,
          text,
          prev_stream,
          prev_op,
          ev.source_stream_index,
          ev.source_op_index,
          prev_font_name,
          prev_font_size,
          cur_font_name,
          cur_font_size,
          line_break,
          para_break,
          ev.is_coalesced,
          ev.coalesced_count,
        ) {
          cur = append_event_text(cur, text)
          end = i
        } else {
          flush_line(
            lines,
            page_index,
            cur,
            start,
            end,
            false,
            infer_flush_reason_on_attach_reject(
              cur,
              text,
              prev_stream,
              prev_op,
              ev.source_stream_index,
              ev.source_op_index,
              line_break,
              para_break,
            ),
          )
          cur = text
          start = i
          end = i
        }
      }
    }

    if line_break || para_break {
      let reason = if para_break {
        "explicit_paragraph_break"
      } else {
        "explicit_line_break"
      }
      flush_line(lines, page_index, cur, start, end, para_break, reason)
      cur = ""
      start = -1
      end = -1
    }

    prev_stream = ev.source_stream_index
    prev_op = ev.source_op_index
    prev_font_name = cur_font_name
    prev_font_size = cur_font_size
    i = i + 1
  }

  flush_line(lines, page_index, cur, start, end, false, "page_end")
  filter_minimal_line_noise(lines)
}

///|
fn should_flush_line_before_appending(
  current_line : String,
  next_text : String,
  prev_stream : Int,
  prev_op : Int,
  cur_stream : Int,
  cur_op : Int,
) -> Bool {
  let cur = current_line.trim().to_string()
  let next = next_text.trim().to_string()
  if cur == "" || next == "" {
    return false
  }

  if !is_heading_like_short_line(cur) || has_boundary_punct_event(cur) {
    return false
  }
  if is_conservative_heading_like_next_event(next) || !starts_like_body_sentence(next) {
    return false
  }

  if prev_stream != cur_stream {
    return true
  }

  // 同 stream 但进入新 op：如果上一段像短标题，下一段像正文，先断行
  cur_op > prev_op
}

///|
/// 只决定“是不是同一视觉行”，不做标题判定。
fn should_attach_to_current_line(
  cur_line : String,
  next_text : String,
  prev_stream : Int,
  prev_op : Int,
  cur_stream : Int,
  cur_op : Int,
  prev_font_name : String,
  prev_font_size : Double,
  cur_font_name : String,
  cur_font_size : Double,
  line_break : Bool,
  para_break : Bool,
  is_coalesced : Bool,
  coalesced_count : Int,
) -> Bool {
  if para_break || line_break {
    return false
  }

  if cur_line == "" || next_text == "" {
    return false
  }

  // 明显硬边界：页码、列表起始
  if starts_like_hard_block_boundary(next_text) {
    return false
  }

  // 不同 stream 默认不断拼
  if prev_stream != cur_stream {
    return false
  }

  let op_gap = cur_op - prev_op
  if op_gap < 0 || op_gap > 1 {
    return false
  }

  if looks_like_heading_then_body(cur_line, next_text) {
    return false
  }

  // 很短的碎片通常应该被吸回当前行
  if is_short_fragment(next_text) {
    return true
  }

  // core 已 coalesce 过，优先继续
  if is_coalesced && coalesced_count > 1 {
    return true
  }

  // 中文碎片常见，且前面没句终时优先继续
  if is_mostly_cjkish(next_text) && !ends_like_sentence(cur_line) {
    return true
  }

  // 字体变化很大且当前是很短碎片时，倾向断开
  if font_changed_too_much(prev_font_name, prev_font_size, cur_font_name, cur_font_size) &&
    is_shortish_fragment(next_text) {
    return false
  }

  // 同 stream 且 op 很近，前面又没结束，继续
  if op_gap <= 1 && !ends_like_sentence(cur_line) {
    return true
  }

  // 看起来像词内 continuation
  if looks_like_word_continuation(cur_line, next_text) {
    return true
  }

  false
}

///|
fn starts_like_hard_block_boundary(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  is_probable_page_number(t)
}

///|
fn append_event_text(prev : String, cur : String) -> String {
  join_pdf_text_fragments(prev, cur)
}

///|
fn flush_line(
  lines : Array[PdfConvertLine],
  page_index : Int,
  text : String,
  start : Int,
  end : Int,
  paragraph_break : Bool,
  reason : String,
) -> Unit {
  let t = normalize_line_text(text)
  debug_log_flush(reason, t, start, end, paragraph_break)

  if t == "" {
    if paragraph_break {
      lines.push({
        text: "",
        page_index,
        line_index: lines.length(),
        source_event_start: start,
        source_event_end: end,
        is_paragraph_break: true,
        strong_break_after: false,
      })
    }
    return
  }

  lines.push({
    text: t,
    page_index,
    line_index: lines.length(),
    source_event_start: start,
    source_event_end: end,
    is_paragraph_break: paragraph_break,
    strong_break_after: strong_break_after_from_flush_reason(reason),
  })
}

///|
fn has_explicit_line_break(
  kind : @pdfc.PdfTextBreakKind,
  text : String,
) -> Bool {
  kind == @pdfc.PdfTextBreakKind::ExplicitLine || text == "\n"
}

///|
fn has_explicit_paragraph_break(
  kind : @pdfc.PdfTextBreakKind,
  text : String,
) -> Bool {
  kind == @pdfc.PdfTextBreakKind::ExplicitParagraph || text == "\n\n"
}

///|
fn normalize_line_text(text : String) -> String {
  normalize_pdf_text_fragment(text)
}

///|
fn filter_minimal_line_noise(lines : Array[PdfConvertLine]) -> Array[PdfConvertLine] {
  let out : Array[PdfConvertLine] = []
  for line in lines {
    let t = line.text.trim().to_string()
    let idx = line.line_index
    let is_edge = idx == 0 || idx + 1 == lines.length()
    if is_edge && is_isolated_numeric_noise(t) {
      continue
    }

    out.push({
      text: line.text,
      page_index: line.page_index,
      line_index: out.length(),
      source_event_start: line.source_event_start,
      source_event_end: line.source_event_end,
      is_paragraph_break: line.is_paragraph_break,
      strong_break_after: line.strong_break_after,
    })
  }
  out
}

///|
fn is_isolated_numeric_noise(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }
  if t.to_array().length() > 2 {
    return false
  }
  is_digits_only(t)
}

///|
fn looks_like_heading_then_body(cur_line : String, next_text : String) -> Bool {
  if !is_heading_like_short_line(cur_line) {
    return false
  }
  starts_like_body_sentence(next_text)
}

///|
fn is_heading_like_short_line(text : String) -> Bool {
  let t = text.trim().to_string()
  let n = t.to_array().length()
  if t == "" || n > 32 {
    return false
  }

  if t.has_prefix("#") {
    return true
  }
  if t.has_prefix("第") && (t.contains("章") || t.contains("节") || t.contains("路线")) {
    return true
  }
  if t.has_prefix("Chapter ") || t.has_prefix("CHAPTER ") {
    return true
  }

  if looks_like_compact_cjk_heading_line(t) {
    return true
  }

  if looks_like_full_mixed_script_heading_line(t) {
    return true
  }

  // 全标题式短句（Hard Wrap Test / Document Conversion Pipeline）
  let words = split_words_simple(t)
  if words.length() >= 2 && words.length() <= 6 && !ends_like_sentence(t) {
    let mut titleish = 0
    for w in words {
      match first_char_local(w) {
        Some(c) =>
          if (c >= 'A' && c <= 'Z') || is_all_caps_word_event(w) {
            titleish = titleish + 1
          }
        None => ()
      }
    }
    return titleish * 2 >= words.length()
  }

  false
}

///|
fn looks_like_compact_cjk_heading_line(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" || t.contains(" ") || ends_like_sentence(t) {
    return false
  }

  let n = t.to_array().length()
  if n < 4 || n > 8 {
    return false
  }

  if !is_mostly_cjkish(t) {
    return false
  }

  !starts_with_cjk_function_char_event(t)
}

///|
fn looks_like_full_mixed_script_heading_line(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" || ends_like_sentence(t) {
    return false
  }

  let n = t.to_array().length()
  if n < 14 || n > 48 {
    return false
  }

  if !contains_cjk_char_event(t) || !contains_ascii_letter_event(t) {
    return false
  }

  if starts_with_cjk_function_char_event(t) {
    return false
  }

  let words = split_words_simple(t)
  let mut ascii_words = 0
  let mut titleish_ascii = 0
  for w in words {
    if is_ascii_word_event(w) {
      ascii_words = ascii_words + 1
      match first_char_local(w) {
        Some(c) =>
          if (c >= 'A' && c <= 'Z') || is_all_caps_word_event(w) {
            titleish_ascii = titleish_ascii + 1
          }
        None => ()
      }
    }
  }

  ascii_words >= 2 &&
  titleish_ascii * 2 >= ascii_words &&
  (ascii_words >= 3 || t.contains("（") || t.contains("("))
}

///|
fn is_conservative_heading_like_next_event(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  if t.has_prefix("#") {
    return true
  }
  if t.has_prefix("第") && (t.contains("章") || t.contains("节")) {
    return true
  }
  if t.has_prefix("Chapter ") || t.has_prefix("CHAPTER ") {
    return true
  }

  // 对 next event 保守：只允许非常明确、且足够长的完整混合标题
  looks_like_full_mixed_script_heading_line(t)
}

///|
fn starts_with_cjk_function_char_event(text : String) -> Bool {
  match first_char_local(text) {
    Some(c) =>
      c == '于' || c == '在' || c == '对' || c == '将' || c == '并' ||
      c == '与' || c == '及' || c == '和' || c == '把' || c == '由' ||
      c == '为' || c == '以' || c == '从' || c == '向' || c == '按' ||
      c == '就' || c == '被'
    None => false
  }
}

///|
fn contains_ascii_letter_event(text : String) -> Bool {
  for c in text.to_array() {
    if is_ascii_letter_local(c) {
      return true
    }
  }
  false
}

///|
fn contains_cjk_char_event(text : String) -> Bool {
  for c in text.to_array() {
    if is_cjkish(c) {
      return true
    }
  }
  false
}

///|
fn starts_like_body_sentence(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  if starts_with_titlecase_word_event(t) || starts_with_cjk_event(t) {
    return true
  }

  starts_with_lowercase_word_event(t)
}

///|
fn starts_with_titlecase_word_event(s : String) -> Bool {
  match first_char_local(s) {
    Some(c) => c >= 'A' && c <= 'Z'
    None => false
  }
}

///|
fn starts_with_lowercase_word_event(s : String) -> Bool {
  match first_char_local(s) {
    Some(c) => c >= 'a' && c <= 'z'
    None => false
  }
}

///|
fn starts_with_cjk_event(s : String) -> Bool {
  match first_char_local(s) {
    Some(c) => is_cjkish(c)
    None => false
  }
}

///|
fn is_all_caps_word_event(s : String) -> Bool {
  let cs = s.to_array()
  if cs.length() == 0 {
    return false
  }

  let mut has_alpha = false
  for c in cs {
    if c >= 'A' && c <= 'Z' {
      has_alpha = true
      continue
    }
    if c >= '0' && c <= '9' {
      continue
    }
    return false
  }

  has_alpha
}

///|
fn font_changed_too_much(
  prev_name : String,
  prev_size : Double,
  cur_name : String,
  cur_size : Double,
) -> Bool {
  if prev_name != cur_name {
    return true
  }

  let diff = if prev_size >= cur_size {
    prev_size - cur_size
  } else {
    cur_size - prev_size
  }

  diff >= 1.5
}

///|
fn is_short_fragment(text : String) -> Bool {
  let n = text.trim().to_string().to_array().length()
  n > 0 && n <= 8
}

///|
fn is_shortish_fragment(text : String) -> Bool {
  let n = text.trim().to_string().to_array().length()
  n > 0 && n <= 12
}

///|
fn looks_like_word_continuation(left : String, right : String) -> Bool {
  if should_join_without_space_event(left, right) {
    return true
  }

  if !ends_like_sentence(left) && is_short_fragment(right) {
    return true
  }

  false
}

///|
fn should_join_without_space_event(left : String, right : String) -> Bool {
  match (last_char_local(left), first_char_local(right)) {
    (Some(l), Some(r)) => {
      if is_cjkish(l) && is_cjkish(r) {
        return true
      }

      if looks_like_broken_ascii_word_event(left, right) {
        return true
      }

      false
    }
    _ => false
  }
}

///|
/// 只允许非常短的英文碎词无空格拼接，
/// 避免 thefirst / documentconversion。
fn looks_like_broken_ascii_word_event(left : String, right : String) -> Bool {
  if has_boundary_punct_event(left) || has_boundary_punct_event(right) {
    return false
  }

  let lw = last_ascii_word_event(left)
  let rw = first_ascii_word_event(right)

  if lw == "" || rw == "" {
    return false
  }

  let ln = lw.to_array().length()
  let rn = rw.to_array().length()

  (ln <= 3 && rn <= 6) || (rn <= 3 && ln <= 6)
}

///|
fn has_boundary_punct_event(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  match last_char_local(t) {
    Some(c) =>
      c == '.' || c == '!' || c == '?' ||
      c == '。' || c == '！' || c == '？' ||
      c == ':' || c == '：' || c == ';' || c == '；' ||
      c == ',' || c == '，'
    None => false
  }
}

///|
fn first_ascii_word_event(s : String) -> String {
  let parts = split_words_simple(s)
  for w in parts {
    if is_ascii_word_event(w) {
      return w
    }
  }
  ""
}

///|
fn last_ascii_word_event(s : String) -> String {
  let parts = split_words_simple(s)
  let mut i = parts.length()
  while i > 0 {
    let w = parts[i - 1]
    if is_ascii_word_event(w) {
      return w
    }
    i = i - 1
  }
  ""
}

///|
fn is_ascii_word_event(s : String) -> Bool {
  let cs = s.to_array()
  if cs.length() == 0 {
    return false
  }

  for c in cs {
    if !is_ascii_letter_local(c) {
      return false
    }
  }
  true
}

///|
fn is_ascii_letter_local(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

///|
fn ends_like_sentence(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  match last_char_local(t) {
    Some(c) =>
      c == '。' || c == '！' || c == '？' || c == '.' || c == '!' || c == '?'
    None => false
  }
}

///|
fn is_mostly_cjkish(s : String) -> Bool {
  let cs = s.to_array()
  let n = cs.length()
  if n == 0 {
    return false
  }

  let mut cjk = 0
  for c in cs {
    if is_cjkish(c) {
      cjk = cjk + 1
    }
  }

  cjk * 2 >= n
}

///|
fn option_string_or_empty(v : String?) -> String {
  match v {
    Some(x) => x
    None => ""
  }
}

///|
fn option_f64_or_zero(v : Double?) -> Double {
  match v {
    Some(x) => x
    None => 0.0
  }
}

///|
fn first_char_local(s : String) -> Char? {
  let cs = s.to_array()
  if cs.length() == 0 {
    None
  } else {
    Some(cs[0])
  }
}

///|
fn last_char_local(s : String) -> Char? {
  let cs = s.to_array()
  let n = cs.length()
  if n == 0 {
    None
  } else {
    Some(cs[n - 1])
  }
}

///|
fn drop_last_char_local(s : String) -> String {
  let cs = s.to_array()
  let n = cs.length()
  if n == 0 {
    return s
  }
  String::from_array(cs[:n - 1].to_array())
}

///|
fn debug_log_event(
  event_index : Int,
  page_index : Int,
  ev : @pdfc.PdfTextEvent,
  normalized_text : String,
) -> Unit {
  println(
    "[pdf-lines][event] idx=" +
    event_index.to_string() +
    " page=" +
    page_index.to_string() +
    " stream=" +
    ev.source_stream_index.to_string() +
    " op=" +
    ev.source_op_index.to_string() +
    " break=" +
    debug_break_kind_local(ev.break_kind) +
    " normalized=\"" +
    debug_preview_text(normalized_text) +
    "\"",
  )
}

///|
fn debug_log_append_decision(
  current_line : String,
  next_text : String,
  should_flush_before_append : Bool,
  heading_like_cur : Bool,
  cur_has_boundary_punct : Bool,
  next_starts_like_body : Bool,
  next_is_heading_like : Bool,
  stream_changed : Bool,
  op_changed : Bool,
) -> Unit {
  println(
    "[pdf-lines][append-decision] cur=\"" +
    debug_preview_text(current_line) +
    "\" next=\"" +
    debug_preview_text(next_text) +
    "\" should_flush_before_append=" +
    should_flush_before_append.to_string(),
  )
  if !should_flush_before_append {
    println(
      "[pdf-lines][append-decision][sub] heading_like_cur=" +
      heading_like_cur.to_string() +
      " cur_has_boundary_punct=" +
      cur_has_boundary_punct.to_string() +
      " next_starts_like_body=" +
      next_starts_like_body.to_string() +
      " next_is_heading_like=" +
      next_is_heading_like.to_string() +
      " stream_changed=" +
      stream_changed.to_string() +
      " op_changed=" +
      op_changed.to_string(),
    )
  }
}

///|
fn debug_log_flush(
  reason : String,
  text : String,
  start : Int,
  end : Int,
  paragraph_break : Bool,
) -> Unit {
  println(
    "[pdf-lines][flush] reason=" +
    reason +
    " paragraph_break=" +
    paragraph_break.to_string() +
    " source_range=" +
    start.to_string() +
    "-" +
    end.to_string() +
    " line=\"" +
    debug_preview_text(text) +
    "\"",
  )
}

///|
fn infer_flush_reason_on_attach_reject(
  cur_line : String,
  next_text : String,
  prev_stream : Int,
  prev_op : Int,
  cur_stream : Int,
  cur_op : Int,
  line_break : Bool,
  para_break : Bool,
) -> String {
  if para_break {
    return "explicit_paragraph_break"
  }
  if line_break {
    return "explicit_line_break"
  }
  if prev_stream != cur_stream {
    return "source_boundary"
  }

  let op_gap = cur_op - prev_op
  if op_gap < 0 || op_gap > 1 {
    return "source_boundary"
  }
  if starts_like_hard_block_boundary(next_text) {
    return "hard_block_boundary"
  }
  if looks_like_heading_then_body(cur_line, next_text) {
    return "heading_like_before_body_attach_path"
  }

  "attach_rejected_other"
}

///|
fn debug_break_kind_local(kind : @pdfc.PdfTextBreakKind) -> String {
  match kind {
    @pdfc.PdfTextBreakKind::None => "none"
    @pdfc.PdfTextBreakKind::ExplicitLine => "explicit_line"
    @pdfc.PdfTextBreakKind::ExplicitParagraph => "explicit_paragraph"
    @pdfc.PdfTextBreakKind::Inferred => "inferred"
  }
}

///|
fn debug_preview_text(s : String) -> String {
  let t = s
    .replace(old="\n", new="\\n")
    .replace(old="\r", new="\\r")
    .replace(old="\t", new="\\t")
  if t.to_array().length() <= 80 {
    t
  } else {
    t[:80].to_string() + "..."
  }
}

///|
fn strong_break_after_from_flush_reason(reason : String) -> Bool {
  reason == "heading_like_before_body"
}
