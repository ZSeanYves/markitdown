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

    if text != "" {
      if cur == "" {
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
        flush_line(lines, page_index, cur, start, end, false)
        cur = text
        start = i
        end = i
      }
    }

    if line_break || para_break {
      flush_line(lines, page_index, cur, start, end, para_break)
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

  flush_line(lines, page_index, cur, start, end, false)
  lines
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
  if op_gap < 0 || op_gap > 2 {
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
  let left = prev.trim().to_string()
  let right = cur.trim().to_string()

  if left == "" {
    return right
  }
  if right == "" {
    return left
  }

  if left.has_suffix("-") && starts_with_ascii_letter(right) {
    return drop_last_char_local(left) + right
  }

  if should_join_without_space_event(left, right) {
    return left + right
  }

  left + " " + right
}

///|
fn flush_line(
  lines : Array[PdfConvertLine],
  page_index : Int,
  text : String,
  start : Int,
  end : Int,
  paragraph_break : Bool,
) -> Unit {
  let t = normalize_line_text(text)

  if t == "" {
    if paragraph_break {
      lines.push({
        text: "",
        page_index,
        line_index: lines.length(),
        source_event_start: start,
        source_event_end: end,
        is_paragraph_break: true,
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

  (ln <= 3 && rn <= 5) || (ln <= 4 && rn <= 3)
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
