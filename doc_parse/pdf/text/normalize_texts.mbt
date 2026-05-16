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
  let new_spans = normalize_line_spans_with_glue(line.spans)

  let bbox = @model.spans_bbox(new_spans).unwrap_or(default_rect())
  let source_refs = collect_span_source_refs(new_spans)
  if line.spans.length() >= 2 {
    let joined = Array::new()
    for sp in new_spans {
      joined.push("\"" + sp.text + "\"")
    }

    let text_preview = joined.join(" | ")
    if text_preview.contains("noise removal") || text_preview.contains("confi") {
      //println("[line-spans] " + text_preview)
    }
  }

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
fn normalize_line_spans_with_glue(
  spans : Array[@model.PdfTextSpan],
) -> Array[@model.PdfTextSpan] {
  if spans.is_empty() {
    return []
  }

  let out = Array::new()

  for i = 0; i < spans.length(); i = i + 1 {
    let cur0 = normalize_single_span(spans[i])
    let cur_trim = cur0.text.trim().to_owned()

    // 归一化后空 span 直接丢掉
    if cur_trim == "" {
      continue
    }

    let cur = { ..cur0, text: cur_trim }

    if out.is_empty() {
      out.push(cur)
      continue
    }

    let prev = out[out.length() - 1]
    let prev_text = prev.text
    let cur_text = cur.text

    if should_drop_trailing_page_number_slash_span(prev, cur, spans, i) {
      continue
    }

    // 关键：先在这里拦尾部孤立数字 span
    if should_drop_trailing_page_number_digit_span(prev, cur) {
      //println(
      //  "[drop-tail-digit-span] prev=\"" +
      //  prev_text +
      //  "\" cur=\"" +
      // cur_text +
      //  "\"",
      //)
      continue
    }

    match try_merge_english_word_fragment_span(prev, cur) {
      Some((merged_prev_text, remaining_cur_text)) => {
        let remain = remaining_cur_text.trim().to_owned()
        out[out.length() - 1] = if remain == "" {
          merge_fully_consumed_fragment_span(prev, cur, merged_prev_text)
        } else {
          { ..prev, text: merged_prev_text }
        }

        if remain != "" {
          out.push({ ..cur, text: remain })
        }
        continue
      }
      None => ()
    }

    match try_merge_domain_fragment_span(prev, cur) {
      Some((merged_prev_text, remaining_cur_text)) => {
        let remain = remaining_cur_text.trim().to_owned()
        out[out.length() - 1] = if remain == "" {
          merge_fully_consumed_fragment_span(prev, cur, merged_prev_text)
        } else {
          { ..prev, text: merged_prev_text }
        }

        if remain != "" {
          out.push({ ..cur, text: remain })
        }
        continue
      }
      None => ()
    }

    if should_merge_hyphenated_word_piece(prev_text, cur_text) {
      let merged_prev_text = trim_hyphen_suffix(prev_text)
      out[out.length() - 1] = { ..prev, text: merged_prev_text }
      out.push(cur)
      continue
    }

    out.push({ ..cur, text: cur_text.trim().to_owned() })
  }

  out
}

///|
fn merge_fully_consumed_fragment_span(
  left : @model.PdfTextSpan,
  right : @model.PdfTextSpan,
  merged_text : String,
) -> @model.PdfTextSpan {
  let chars = Array::new()
  for ch in left.chars {
    chars.push(ch)
  }
  for ch in right.chars {
    chars.push(ch)
  }

  let source_refs = Array::new()
  for src in left.source_refs {
    source_refs.push(src)
  }
  for src in right.source_refs {
    source_refs.push(src)
  }

  {
    ..left,
    text: merged_text,
    bbox: @model.union_rect(left.bbox, right.bbox),
    chars,
    source_refs,
  }
}

///|
fn try_merge_english_word_fragment_span(
  left_span : @model.PdfTextSpan,
  right_span : @model.PdfTextSpan,
) -> (String, String)? {
  let l = left_span.text
  let r = right_span.text.trim().to_owned()

  if l.trim().to_owned() == "" || r == "" {
    return None
  }

  let left_suffix = trailing_ascii_letters(l)
  let right_prefix = leading_ascii_letters(r)

  if left_suffix == "" || right_prefix == "" {
    return None
  }

  if left_suffix.length() > 12 || right_prefix.length() > 12 {
    return None
  }

  if !starts_with_lower_ascii(right_prefix) {
    return None
  }

  if has_explicit_space_boundary_for_word_merge(left_span, right_span) {
    return None
  }

  if !looks_like_tight_english_fragment_context(left_span, right_span) {
    return None
  }

  if starts_with_ligature_fragment_span(right_span) &&
    left_suffix.length() >= 3 &&
    right_prefix.length() <= 3 {
    let left_prefix = remove_trailing_ascii_letters(l)
    let remain = r[right_prefix.length():].to_owned()
    return Some((left_prefix + left_suffix + right_prefix, remain))
  }

  if !looks_like_joinable_english_fragment_word(left_suffix, right_prefix) &&
    !looks_like_single_letter_prefix_fragment(left_suffix, right_prefix) &&
    !looks_like_tight_short_ascii_fragment_pair(
      left_span, right_span, left_suffix, right_prefix,
    ) {
    return None
  }

  let left_prefix = remove_trailing_ascii_letters(l)
  let remain0 = r[right_prefix.length():].to_owned()
  let merged_word = left_prefix + left_suffix + right_prefix

  if is_tight_terminal_punct_text(remain0) {
    return Some((merged_word + remain0, ""))
  }

  Some((merged_word, remain0))
}

///|
fn try_merge_domain_fragment_span(
  left_span : @model.PdfTextSpan,
  right_span : @model.PdfTextSpan,
) -> (String, String)? {
  let l = left_span.text
  let r = right_span.text.trim().to_owned()

  if l.trim().to_owned() == "" || r == "" {
    return None
  }

  if !l.has_suffix(".") {
    return None
  }

  let left_body = trailing_ascii_letters(l[:l.length() - 1].to_owned())
  let right_prefix = leading_ascii_letters(r)

  if left_body.length() < 2 || right_prefix.length() < 2 || right_prefix.length() > 12 {
    return None
  }

  if !all_ascii_letters(left_body + right_prefix) {
    return None
  }

  if !starts_with_lower_ascii(right_prefix) {
    return None
  }

  if has_explicit_space_boundary_for_word_merge(left_span, right_span) {
    return None
  }

  if !looks_like_tight_english_fragment_context(left_span, right_span) {
    return None
  }

  let remain = r[right_prefix.length():].to_owned()
  Some((l + right_prefix, remain))
}

///|
fn trailing_ascii_letters(text : String) -> String {
  let chars = text.to_array()
  if chars.is_empty() {
    return ""
  }

  let mut out_rev = ""
  let mut i = chars.length() - 1

  while true {
    let ch = chars[i]
    if is_ascii_letter(ch) {
      out_rev = out_rev + ch.to_string()
    } else {
      break
    }

    if i == 0 {
      break
    }
    i = i - 1
  }

  reverse_string(out_rev)
}

///|
fn reverse_string(text : String) -> String {
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
fn remove_trailing_ascii_letters(text : String) -> String {
  let chars = text.to_array()
  if chars.is_empty() {
    return text
  }

  let mut end = chars.length()

  while end > 0 {
    let ch = chars[end - 1]
    if is_ascii_letter(ch) {
      end = end - 1
    } else {
      break
    }
  }

  text[:end].to_owned()
}

///|
fn leading_ascii_letters(text : String) -> String {
  let chars = text.to_array()
  if chars.is_empty() {
    return ""
  }

  let mut out = ""
  let mut i = 0
  while i < chars.length() {
    let ch = chars[i]
    if is_ascii_letter(ch) {
      out = out + ch.to_string()
      i = i + 1
    } else {
      break
    }
  }

  out
}

///|
fn looks_like_joinable_english_fragment_word(
  left_suffix : String,
  right_prefix : String,
) -> Bool {
  let word = left_suffix + right_prefix
  if word.length() < 4 || word.length() > 24 {
    return false
  }

  if !all_ascii_letters(word) {
    return false
  }

  let left = left_suffix.to_lower()
  let right = right_prefix.to_lower()

  if has_ligature_fragment_hint(left) {
    return right.length() <= 3
  }

  if looks_like_english_suffix_piece(right) && left.length() >= 3 {
    return true
  }

  if looks_like_bound_english_prefix(left) && right.length() >= 4 {
    return true
  }

  false
}

///|
fn is_tight_terminal_punct_text(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t.length() != 1 {
    return false
  }

  t == "." || t == "," || t == ":" || t == ";" || t == "!" || t == "?"
}

///|
fn looks_like_single_letter_prefix_fragment(
  left_suffix : String,
  right_prefix : String,
) -> Bool {
  if left_suffix.length() != 1 || right_prefix.length() < 4 || right_prefix.length() > 24 {
    return false
  }

  if !all_ascii_letters(left_suffix + right_prefix) {
    return false
  }

  let left = left_suffix.to_lower()
  left != "a" && left != "i"
}

///|
fn looks_like_tight_short_ascii_fragment_pair(
  left_span : @model.PdfTextSpan,
  right_span : @model.PdfTextSpan,
  left_suffix : String,
  right_prefix : String,
) -> Bool {
  let left_len = left_suffix.length()
  let right_len = right_prefix.length()
  let word = left_suffix + right_prefix
  if word.length() < 3 || word.length() > 24 {
    return false
  }

  if !all_ascii_letters(word) {
    return false
  }

  let gap_ok = if left_len <= 2 || right_len <= 2 {
    span_gap_short_fragment_fallback_for_word_merge(left_span, right_span)
  } else {
    span_gap_very_tight_for_word_merge(left_span, right_span)
  }

  if !gap_ok {
    return false
  }

  (left_len >= 3 && right_len <= 3) ||
  (left_len <= 2 && right_len <= 2)
}

///|
fn looks_like_tight_english_fragment_context(
  left : @model.PdfTextSpan,
  right : @model.PdfTextSpan,
) -> Bool {
  span_font_compatible_for_word_merge(left, right) &&
  span_gap_tight_for_word_merge(left, right) &&
  span_source_refs_adjacent_for_word_merge(left, right)
}

///|
fn span_font_compatible_for_word_merge(
  left : @model.PdfTextSpan,
  right : @model.PdfTextSpan,
) -> Bool {
  let font_name_ok = match (left.font_name, right.font_name) {
    (Some(a), Some(b)) => a == b
    _ => true
  }

  let font_size_ok = match (left.font_size, right.font_size) {
    (Some(a), Some(b)) => abs_double_word_merge(a - b) <= 0.75
    _ => true
  }

  font_name_ok && font_size_ok
}

///|
fn has_explicit_space_boundary_for_word_merge(
  left : @model.PdfTextSpan,
  right : @model.PdfTextSpan,
) -> Bool {
  span_has_trailing_space_char(left) || span_has_leading_space_char(right)
}

///|
fn span_has_trailing_space_char(span : @model.PdfTextSpan) -> Bool {
  match last_span_char_opt(span) {
    Some(ch) => is_space_like_char_word_merge(ch)
    None => false
  }
}

///|
fn span_has_leading_space_char(span : @model.PdfTextSpan) -> Bool {
  match first_span_char_opt(span) {
    Some(ch) => is_space_like_char_word_merge(ch)
    None => false
  }
}

///|
fn starts_with_ligature_fragment_span(span : @model.PdfTextSpan) -> Bool {
  if span.chars.is_empty() {
    return false
  }

  let first = span.chars[0]
  first.is_ligature ||
  first.decoded_text == "\u{FB00}" ||
  first.decoded_text == "\u{FB01}" ||
  first.decoded_text == "\u{FB02}" ||
  first.decoded_text == "\u{FB03}" ||
  first.decoded_text == "\u{FB04}"
}

///|
fn first_span_char_opt(span : @model.PdfTextSpan) -> Char? {
  for pdf_char in span.chars {
    for ch in pdf_char.decoded_text {
      return Some(ch)
    }
  }
  None
}

///|
fn last_span_char_opt(span : @model.PdfTextSpan) -> Char? {
  let mut last : Char? = None
  for pdf_char in span.chars {
    for ch in pdf_char.decoded_text {
      last = Some(ch)
    }
  }
  last
}

///|
fn is_space_like_char_word_merge(ch : Char) -> Bool {
  ch == ' ' ||
  ch == '\t' ||
  ch == '\n' ||
  ch == '\r' ||
  ch == '\u{00A0}' ||
  ch == '\u{2002}' ||
  ch == '\u{2003}' ||
  ch == '\u{2009}' ||
  ch == '　'
}

///|
fn span_gap_tight_for_word_merge(
  left : @model.PdfTextSpan,
  right : @model.PdfTextSpan,
) -> Bool {
  let gap = right.bbox.x0 - left.bbox.x1
  if gap <= 0.0 {
    return true
  }

  let ref_size = match (left.font_size, right.font_size) {
    (Some(a), Some(b)) => if a > b { a } else { b }
    (Some(a), None) => a
    (None, Some(b)) => b
    (None, None) => 12.0
  }

  gap <= ref_size * 0.22 + 1.5
}

///|
fn span_gap_very_tight_for_word_merge(
  left : @model.PdfTextSpan,
  right : @model.PdfTextSpan,
) -> Bool {
  let gap = right.bbox.x0 - left.bbox.x1
  if gap <= 0.0 {
    return true
  }

  let ref_size = match (left.font_size, right.font_size) {
    (Some(a), Some(b)) => if a > b { a } else { b }
    (Some(a), None) => a
    (None, Some(b)) => b
    (None, None) => 12.0
  }

  gap <= ref_size * 0.08 + 0.6
}

///|
fn span_gap_short_fragment_fallback_for_word_merge(
  left : @model.PdfTextSpan,
  right : @model.PdfTextSpan,
) -> Bool {
  let gap = right.bbox.x0 - left.bbox.x1
  if gap <= 0.0 {
    return true
  }

  let ref_size = match (left.font_size, right.font_size) {
    (Some(a), Some(b)) => if a > b { a } else { b }
    (Some(a), None) => a
    (None, Some(b)) => b
    (None, None) => 12.0
  }

  gap <= ref_size * 0.16 + 1.0
}

///|
fn span_source_refs_adjacent_for_word_merge(
  left : @model.PdfTextSpan,
  right : @model.PdfTextSpan,
) -> Bool {
  match
    (
      last_source_ref_opt(left.source_refs),
      first_source_ref_opt(right.source_refs),
    ) {
    (Some(a), Some(b)) => {
      if a.page_index != b.page_index ||
        a.source_stream_index != b.source_stream_index {
        return false
      }

      match (a.content_order_index, b.content_order_index) {
        (Some(x), Some(y)) => if y < x { false } else { y - x <= 2 }
        _ =>
          if b.source_op_index < a.source_op_index {
            false
          } else {
            b.source_op_index - a.source_op_index <= 2
          }
      }
    }
    _ => true
  }
}

///|
fn last_source_ref_opt(
  refs : Array[@model.PdfSourceRef],
) -> @model.PdfSourceRef? {
  if refs.is_empty() {
    None
  } else {
    Some(refs[refs.length() - 1])
  }
}

///|
fn first_source_ref_opt(
  refs : Array[@model.PdfSourceRef],
) -> @model.PdfSourceRef? {
  if refs.is_empty() {
    None
  } else {
    Some(refs[0])
  }
}

///|
fn looks_like_bound_english_prefix(text : String) -> Bool {
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
fn looks_like_english_suffix_piece(text : String) -> Bool {
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
  text == "ible"
}

///|
fn has_ligature_fragment_hint(text : String) -> Bool {
  text.has_suffix("fi") ||
  text.has_suffix("ff") ||
  text.has_suffix("fl") ||
  text.has_suffix("ffi") ||
  text.has_suffix("ffl")
}

///|
fn abs_double_word_merge(x : Double) -> Double {
  if x < 0.0 {
    -x
  } else {
    x
  }
}

///|
fn should_drop_trailing_page_number_digit_span(
  prev : @model.PdfTextSpan,
  cur : @model.PdfTextSpan,
) -> Bool {
  let left = prev.text.trim().to_owned()
  let right = cur.text.trim().to_owned()
  //println(
  //  "[tail-digit-check] left=\"" +
  //  left +
  //  "\" right=\"" +
  //  right +
  //  "\" digits=" +
  //  all_ascii_digits(right).to_string() +
  //  " len=" +
  //  right.length().to_string() +
  //  " ends=" +
  //  ends_like_sentence_for_artifact(left).to_string() +
  //  " words=" +
  //  count_words_for_artifact(left).to_string(),
  //)

  if left == "" || right == "" {
    return false
  }

  if !is_single_page_number_digit_span(right) {
    return false
  }

  if !ends_like_sentence_for_artifact(left) {
    return false
  }

  if count_words_for_artifact(left) < 4 {
    return false
  }

  true
}

///|
fn should_drop_trailing_page_number_slash_span(
  prev : @model.PdfTextSpan,
  cur : @model.PdfTextSpan,
  spans : Array[@model.PdfTextSpan],
  cur_index : Int,
) -> Bool {
  let left = prev.text.trim().to_owned()
  let current = cur.text.trim().to_owned()

  if left == "" || current != "/" {
    return false
  }

  if !ends_like_sentence_for_artifact(left) {
    return false
  }

  if count_words_for_artifact(left) < 4 {
    return false
  }

  let next = next_nonempty_normalized_span_text(spans, cur_index + 1)
  match next {
    Some(text) => is_single_page_number_digit_span(text)
    None => false
  }
}

///|
fn next_nonempty_normalized_span_text(
  spans : Array[@model.PdfTextSpan],
  start : Int,
) -> String? {
  let mut i = start
  while i < spans.length() {
    let text = normalize_single_span(spans[i]).text.trim().to_owned()
    if text != "" {
      return Some(text)
    }
    i = i + 1
  }
  None
}

///|
fn is_single_page_number_digit_span(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t.length() != 1 {
    return false
  }

  match first_char_opt(t) {
    Some(ch) =>
      (ch >= '0' && ch <= '9') ||
      ch == '０' ||
      ch == '１' ||
      ch == '２' ||
      ch == '３' ||
      ch == '４' ||
      ch == '５' ||
      ch == '６' ||
      ch == '７' ||
      ch == '８' ||
      ch == '９'
    None => false
  }
}

///|
fn ends_like_sentence_for_artifact(text : String) -> Bool {
  let t = text.trim().to_owned()
  t.has_suffix(".") ||
  t.has_suffix("!") ||
  t.has_suffix("?") ||
  t.has_suffix("。") ||
  t.has_suffix("！") ||
  t.has_suffix("？")
}

///|
fn count_words_for_artifact(text : String) -> Int {
  let mut n = 0
  for sv in text.split(" ") {
    let t = sv.trim().to_owned()
    if t != "" {
      n = n + 1
    }
  }
  n
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
/// 文本归一化：
/// 1. unicode_compat 先走 shared substrate 的低风险字符归一化，并保留 PDF
///    专属 compatibility glyph fallback。
/// 2. 纯字符串 cleanup 统一交给 core rule engine 的 PDF policy。
/// 3. 依赖 span/line/source_ref 的修复继续留在当前 lower-layer。
fn normalize_text(text : String) -> String {
  @cor.normalize_pdf_text_cleanup(text)
}

///|
fn should_merge_hyphenated_word_piece(
  left_text : String,
  right_text : String,
) -> Bool {
  let l = left_text.trim().to_owned()
  let r = right_text.trim().to_owned()
  if l == "" || r == "" {
    return false
  }

  let tail = last_ascii_letter_before_hyphen(l)
  let head = first_char_opt(r)

  match (tail, head) {
    (Some(a), Some(b)) => is_ascii_letter(a) && b >= 'a' && b <= 'z'
    _ => false
  }
}

///|
fn all_ascii_letters(text : String) -> Bool {
  if text == "" {
    return false
  }

  for ch in text {
    if !is_ascii_letter(ch) {
      return false
    }
  }

  true
}

///|
fn is_ascii_letter(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
}

///|
fn starts_with_lower_ascii(text : String) -> Bool {
  for ch in text {
    return ch >= 'a' && ch <= 'z'
  }
  false
}

///|
fn trim_hyphen_suffix(text : String) -> String {
  let t = text.trim().to_owned()
  if t.has_suffix("-") {
    t[:t.length() - 1].to_owned()
  } else {
    t
  }
}

///|
fn last_ascii_letter_before_hyphen(text : String) -> Char? {
  let t = text.trim().to_owned()
  if !t.has_suffix("-") || t.length() < 2 {
    return None
  }

  let prefix = t[:t.length() - 1].to_owned()
  last_char_opt(prefix)
}
