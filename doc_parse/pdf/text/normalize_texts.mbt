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

    match try_merge_english_word_fragment_span(prev_text, cur_text) {
      Some((merged_prev_text, remaining_cur_text)) => {
        out[out.length() - 1] = { ..prev, text: merged_prev_text }

        let remain = remaining_cur_text.trim().to_owned()
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

    let glue = glue_between_spans(prev_text, cur_text)
    if glue == " " {
      out[out.length() - 1] = {
        ..prev,
        text: prev_text.trim().to_owned() + " ",
      }
      out.push({ ..cur, text: cur_text.trim().to_owned() })
    } else {
      out.push({ ..cur, text: cur_text.trim().to_owned() })
    }
  }

  out
}

///|
fn try_merge_english_word_fragment_span(
  left_text : String,
  right_text : String,
) -> (String, String)? {
  let l = left_text
  let r = right_text.trim().to_owned()

  if l.trim().to_owned() == "" || r == "" {
    return None
  }

  let left_suffix = trailing_ascii_letters(l)
  let right_prefix = leading_ascii_letters(r)

  if left_suffix == "" || right_prefix == "" {
    return None
  }

  let left_suffix_lower = left_suffix.to_lower()
  let right_prefix_lower = right_prefix.to_lower()

  // 左右任一边如果本来就是正常独立词，不参与碎片并词
  if is_common_standalone_english_word(left_suffix_lower) {
    return None
  }

  if is_common_standalone_english_word(right_prefix_lower) {
    return None
  }

  // 至少一边必须是明显短碎片
  if !(left_suffix.length() <= 4 || right_prefix.length() <= 4) {
    return None
  }

  if left_suffix.length() > 12 || right_prefix.length() > 12 {
    return None
  }

  let joined = left_suffix + right_prefix
  let lowered = joined.to_lower()

  if !looks_like_joinable_english_fragment_word(
      lowered, left_suffix_lower, right_prefix_lower,
    ) {
    return None
  }

  let left_prefix = remove_trailing_ascii_letters(l)
  let remain = r[right_prefix.length():].to_owned()

  Some((left_prefix + joined, remain))
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
  word : String,
  left_suffix : String,
  right_prefix : String,
) -> Bool {
  if word.length() < 4 || word.length() > 24 {
    return false
  }

  if !all_ascii_letters(word) {
    return false
  }

  if is_known_split_english_word(word) {
    return true
  }

  // 通用规则只在“明显是短碎片拼接”时启用
  if !(left_suffix.length() <= 3 || right_prefix.length() <= 3) {
    return false
  }

  // 两边都不能是正常独立词
  if is_common_standalone_english_word(left_suffix) ||
    is_common_standalone_english_word(right_prefix) {
    return false
  }

  word.contains("fi") || word.contains("ff") || word.contains("fl")
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
/// 1. unicode_compat 负责兼容字符 / ligature / control / compatibility glyph
/// 2. 这里负责基础空白清洗
/// 3. 最后做低风险后处理
fn normalize_text(text : String) -> String {
  let stage1 = normalize_unicode_compat(text)
  let stage2 = normalize_basic_spaces(stage1)
  normalize_post_text(stage2)
}

///|
fn normalize_basic_spaces(text : String) -> String {
  let mut out = ""
  let mut prev_space = false

  for ch in text {
    if is_space_like(ch) {
      if !prev_space {
        out = out + " "
        prev_space = true
      }
    } else {
      out = out + ch.to_string()
      prev_space = false
    }
  }

  out.trim().to_owned()
}

///|
fn normalize_post_text(text : String) -> String {
  let t1 = fix_hyphenated_english_wrap(text)
  let t2 = fix_common_split_english_words(t1)
  let t3 = remove_spaces_between_cjk(t2)
  let t4 = remove_spaces_around_cjk_punct(t3)
  let t5 = normalize_ascii_punct_spacing(t4)
  let t6 = normalize_bullet_marker_spacing(t5)
  let t7 = normalize_numbered_marker_spacing(t6)
  let t8 = strip_trailing_slash_page_artifact(t7)

  if t7.contains("/") || t8.contains("/") {
    //println("[normalize_post_text] before=\"" + t7 + "\" after=\"" + t8 + "\"")
  }

  t8.trim().to_owned()
}

///|
fn strip_trailing_slash_page_artifact(text : String) -> String {
  let t = text.trim().to_owned()
  if t == "" {
    return t
  }

  // 单独的 slash artifact
  if t == "/" || t == "／" || t == "∕" || t == "⁄" {
    return ""
  }

  // 先处理最常见的单独 span：/1 /2 /3
  match first_char_opt(t) {
    Some(ch) =>
      if ch == '/' || ch == '／' || ch == '∕' || ch == '⁄' {
        let suffix = t[1:].trim().to_owned()
        if suffix != "" && suffix.length() <= 3 && all_ascii_digits(suffix) {
          return ""
        }
      }
    None => ()
  }

  let cs = t.to_array()
  let n = cs.length()
  if n < 2 {
    return t
  }

  let mut slash = -1
  let mut i = n - 1
  while i >= 0 {
    let ch = cs[i]
    if ch == '/' || ch == '／' || ch == '∕' || ch == '⁄' {
      slash = i
      break
    }
    if i == 0 {
      break
    }
    i = i - 1
  }

  if slash <= 0 || slash + 1 >= n {
    return t
  }

  let suffix = t[slash + 1:].trim().to_owned()
  if suffix != "" && suffix.length() <= 3 && all_ascii_digits(suffix) {
    return t[:slash].trim().to_owned()
  }

  t
}

///|
fn fix_hyphenated_english_wrap(text : String) -> String {
  text
  .replace_all(old="- ", new="")
  .replace_all(old="inter-national", new="international")
}

///|
fn glue_between_spans(left_text : String, right_text : String) -> String {
  let l = left_text.trim().to_owned()
  let r = right_text.trim().to_owned()

  if l == "" || r == "" {
    return ""
  }

  if should_merge_hyphenated_word_piece(l, r) {
    return ""
  }

  if should_insert_space_after_bullet_marker(l, r) {
    return " "
  }

  if should_insert_space_after_numbered_marker(l, r) {
    return " "
  }

  ""
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
fn should_insert_space_after_bullet_marker(
  left_text : String,
  right_text : String,
) -> Bool {
  let l = left_text.trim().to_owned()
  let r = right_text.trim().to_owned()
  if l == "" || r == "" {
    return false
  }

  let is_bullet = match first_char_opt(l) {
    Some(ch) => ch == '•' || ch == '*' || ch == '-'
    None => false
  }

  if !is_bullet {
    return false
  }

  match first_char_opt(r) {
    Some(c) => c != ' ' && c != '\t'
    None => false
  }
}

///|
fn should_insert_space_after_numbered_marker(
  left_text : String,
  right_text : String,
) -> Bool {
  let l = left_text.trim().to_owned()
  let r = right_text.trim().to_owned()
  if l == "" || r == "" {
    return false
  }

  if !ends_with_numbered_marker(l) {
    return false
  }

  match first_char_opt(r) {
    Some(c) => {
      // 保护 1. + 1...
      if c >= '0' && c <= '9' {
        return false
      }
      c != ' ' && c != '\t'
    }
    _ => false
  }
}

///|
fn normalize_bullet_marker_spacing(text : String) -> String {
  let t = text.trim().to_owned()
  if t == "" {
    return t
  }

  if (t.has_prefix("•") || t.has_prefix("*") || t.has_prefix("-")) &&
    t.length() >= 2 &&
    t[1] != ' ' {
    t[:1].to_owned() + " " + t[1:].to_owned()
  } else {
    t
  }
}

///|
fn normalize_numbered_marker_spacing(text : String) -> String {
  let chars = text.to_array()
  if chars.length() < 3 {
    return text
  }

  if !(chars[0] >= '0' && chars[0] <= '9') {
    return text
  }

  if chars[1] != ')' && chars[1] != '.' {
    return text
  }

  // 保护 1.1 / 1.2.3
  if chars[1] == '.' && chars[2] >= '0' && chars[2] <= '9' {
    return text
  }

  if chars[2] == ' ' {
    return text
  }

  chars[0].to_string() + chars[1].to_string() + " " + text[2:].to_owned()
}

///|
/// 弱规则 + 白名单
fn fix_common_split_english_words(text : String) -> String {
  let words : Array[String] = Array::new()
  for part in text.split(" ") {
    let s = part.to_owned()
    if s != "" {
      words.push(s)
    }
  }

  if words.length() <= 1 {
    return fix_known_broken_english_phrases(text)
  }

  let out = Array::new()
  let mut i = 0

  while i < words.length() {
    let cur = words[i]

    if i + 1 < words.length() {
      let nxt = words[i + 1]
      match try_join_split_english_word(cur, nxt) {
        Some(joined) => {
          out.push(joined)
          i = i + 2
          continue
        }
        None => ()
      }
    }

    out.push(cur)
    i = i + 1
  }

  fix_known_broken_english_phrases(out.join(" "))
}

///|
fn fix_known_broken_english_phrases(text : String) -> String {
  text
  .replace_all(old="diff erent", new="different")
  .replace_all(old="confi rms", new="confirms")
  .replace_all(old="fi nal", new="final")
  .replace_all(old="fi rst", new="first")
}

///|
fn try_join_split_english_word(left : String, right : String) -> String? {
  let l = left.trim().to_owned()
  let r = right.trim().to_owned()

  if !looks_like_split_english_word_pair(l, r) {
    return None
  }

  let joined = l + r
  let lowered = joined.to_lower()

  if is_known_split_english_word(lowered) {
    Some(joined)
  } else {
    None
  }
}

///|
fn looks_like_split_english_word_pair(left : String, right : String) -> Bool {
  let l = left.trim().to_owned()
  let r = right.trim().to_owned()

  if l == "" || r == "" {
    return false
  }

  if !all_ascii_letters(l) || !all_ascii_letters(r) {
    return false
  }

  if !starts_with_lower_ascii(r) {
    return false
  }

  if l.length() < 2 || l.length() > 6 {
    return false
  }

  if r.length() < 2 || r.length() > 12 {
    return false
  }

  if is_common_standalone_english_word(l.to_lower()) {
    return false
  }

  true
}

///|
fn is_known_split_english_word(word : String) -> Bool {
  word == "first" ||
  word == "final" ||
  word == "different" ||
  word == "confirms" ||
  word == "confirm" ||
  word == "flow" ||
  word == "unified" ||
  word == "international"
}

///|
fn is_common_standalone_english_word(word : String) -> Bool {
  word == "a" ||
  word == "an" ||
  word == "as" ||
  word == "at" ||
  word == "be" ||
  word == "by" ||
  word == "do" ||
  word == "for" ||
  word == "from" ||
  word == "he" ||
  word == "in" ||
  word == "is" ||
  word == "it" ||
  word == "of" ||
  word == "on" ||
  word == "or" ||
  word == "the" ||
  word == "to" ||
  word == "we" ||
  word == "this" ||
  word == "that" ||
  word == "these" ||
  word == "those" ||
  word == "you" ||
  word == "they" ||
  word == "i"
}

///|
fn remove_spaces_between_cjk(text : String) -> String {
  let chars = text.to_array()
  if chars.length() <= 2 {
    return text
  }

  let mut out = ""
  let mut i = 0

  while i < chars.length() {
    let ch = chars[i]

    if ch == ' ' &&
      i > 0 &&
      i + 1 < chars.length() &&
      is_cjk(chars[i - 1]) &&
      is_cjk(chars[i + 1]) &&
      should_remove_cjk_inner_space(chars[i - 1], chars[i + 1]) {
      i = i + 1
      continue
    }

    out = out + ch.to_string()
    i = i + 1
  }

  out
}

///|
fn remove_spaces_around_cjk_punct(text : String) -> String {
  let chars = text.to_array()
  if chars.length() <= 1 {
    return text
  }

  let mut out = ""
  let mut i = 0

  while i < chars.length() {
    let ch = chars[i]

    if ch == ' ' &&
      i > 0 &&
      i + 1 < chars.length() &&
      (is_cjk_punct(chars[i - 1]) || is_cjk_punct(chars[i + 1])) {
      i = i + 1
      continue
    }

    out = out + ch.to_string()
    i = i + 1
  }

  out
}

///|
fn normalize_ascii_punct_spacing(text : String) -> String {
  let chars = text.to_array()
  if chars.is_empty() {
    return text
  }

  let mut out = ""
  let mut i = 0

  while i < chars.length() {
    let ch = chars[i]
    out = out + ch.to_string()

    if is_ascii_sentence_punct(ch) {
      let mut j = i + 1
      while j < chars.length() && chars[j] == ' ' {
        j = j + 1
      }

      if j > i + 1 && j < chars.length() {
        out = out + " "
        i = j
        continue
      }
    }

    i = i + 1
  }

  out
}

///|
fn is_space_like(ch : Char) -> Bool {
  ch == ' ' ||
  ch == '\n' ||
  ch == '\t' ||
  ch == '\u{00A0}' ||
  ch == '\u{2002}' ||
  ch == '\u{2003}' ||
  ch == '\u{2009}' ||
  ch == '　'
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
fn is_ascii_sentence_punct(ch : Char) -> Bool {
  ch == '.' || ch == ',' || ch == ':' || ch == ';' || ch == '!' || ch == '?'
}

///|
fn is_cjk(ch : Char) -> Bool {
  let code = ch.to_int()
  (code >= 0x4E00 && code <= 0x9FFF) ||
  (code >= 0x3400 && code <= 0x4DBF) ||
  (code >= 0xF900 && code <= 0xFAFF)
}

///|
fn is_cjk_punct(ch : Char) -> Bool {
  ch == '，' ||
  ch == '。' ||
  ch == '：' ||
  ch == '；' ||
  ch == '！' ||
  ch == '？' ||
  ch == '（' ||
  ch == '）' ||
  ch == '《' ||
  ch == '》' ||
  ch == '、'
}

///|
fn should_remove_cjk_inner_space(left : Char, right : Char) -> Bool {
  is_cjk(left) && is_cjk(right)
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

///|
fn ends_with_numbered_marker(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t.length() < 2 {
    return false
  }

  let chars = t.to_array()
  let n = chars.length()
  let prev = chars[n - 2]
  let tail = chars[n - 1]

  (prev >= '0' && prev <= '9') && (tail == ')' || tail == '.')
}
