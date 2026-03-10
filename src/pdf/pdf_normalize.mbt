priv enum PdfBlock {
  Heading(Int, String)
  Paragraph(String)
  ListItem(Bool, Int, String) // ordered, level, text
}
///|
priv enum PdfLine {
  Blank
  PageBreak
  Text(String)
}

///|
fn split_blocks_smart(page : String) -> Array[PdfBlock] raise{
  let s = page
    .replace(old="\r\n", new="\n")
    .replace(old="\r", new="\n")
    .replace(old="\u00A0", new=" ")
    .replace(old="\t", new=" ")

  let lines : Array[PdfLine] = []
  for sv in s.split("\n") {
    let raw = sv.to_string()
    let line = raw.trim().to_string()

    if line == PDF_PAGE_BREAK_MARKER {
      lines.push(PdfLine::PageBreak)
    } else if line == "" {
      lines.push(PdfLine::Blank)
    } else if !is_noise_line(line) {
      lines.push(PdfLine::Text(line))
    }
  }

  let out : Array[PdfBlock] = []
  let mut buf = ""
  let mut prev_was_page_break = false

  let n = lines.length()
  let mut i = 0
  while i < n {
    match lines[i] {
      PdfLine::Blank => {
        if buf != "" {
          flush_pdf_block(out, buf)
          buf = ""
        }
        prev_was_page_break = false
      }
      PdfLine::PageBreak =>
        // 先记住跨页，不立即 flush；
        // 是否续段交给下一条正文判断
        prev_was_page_break = true
      PdfLine::Text(cur) =>
        if buf == "" {
          buf = cur
          prev_was_page_break = false
        } else if should_start_new_block(buf, cur, prev_was_page_break) {
          flush_pdf_block(out, buf)
          buf = cur
          prev_was_page_break = false
        } else if should_flush_buf_before_appending(buf, cur) {
          flush_pdf_block(out, buf)
          buf = cur
          prev_was_page_break = false
        } else {
          buf = append_line(buf, cur)
          prev_was_page_break = false
        }
    }

    i = i + 1
  }

  if buf != "" {
    flush_pdf_block(out, buf)
  }

  out
}

///|
fn flush_pdf_block(out : Array[PdfBlock], buf : String) -> Unit raise{
  let raw = buf.trim().to_string()
  if raw == "" {
    return
  }

  match parse_pdf_list_item(raw) {
    Some((ordered, level, text)) => {
      let t = trim_string_for_pdf_block(text)
      if t != "" {
        out.push(PdfBlock::ListItem(ordered, level, t))
      }
      return
    }
    None => ()
  }

  let level = guess_heading_level(raw)
  if level > 0 {
    let text = finalize_heading(raw)
    if text != "" {
      out.push(PdfBlock::Heading(level, text))
    }
  } else {
    let text = finalize_paragraph(raw)
    if text != "" {
      out.push(PdfBlock::Paragraph(text))
    }
  }
}
///|
fn trim_string_for_pdf_block(s : String) -> String {
  let t = s.trim()
  if t == "" {
    return ""
  }

  let mut out = ""
  let mut prev_space = false
  for c in t.to_array() {
    if c == ' ' {
      if !prev_space {
        out = out + " "
        prev_space = true
      }
    } else {
      out = out + c.to_string()
      prev_space = false
    }
  }

  out.trim().to_string()
}
///|
fn should_start_new_block(
  buf : String,
  cur : String,
  prev_was_page_break : Bool,
) -> Bool {
  let t = cur.trim().to_string()
  if t == "" {
    return true
  }

  // 列表项一定开新块
  if looks_like_list_item_sentence(t) {
    return true
  }

  // 强标题候选通常开新块
  if is_strong_heading_candidate(t) {
    return true
  }

  // 跨页：优先判断是否应续段
  if prev_was_page_break {
    if should_merge_across_page_break(buf, t) {
      return false
    } else {
      return true
    }
  }

  // 同页：当前行像新块起点，而前文又不像完整句时，开新块
  if starts_like_new_block(t) && !ends_like_sentence(buf) {
    return true
  }

  false
}

///|
fn should_merge_across_page_break(left : String, right : String) -> Bool {
  let l = left.trim().to_string()
  let r = right.trim().to_string()

  if l == "" || r == "" {
    return false
  }

  if is_strong_heading_candidate(r) {
    return false
  }

  if looks_like_list_item_sentence(r) {
    return false
  }

  if looks_like_figure_or_table_caption(r) {
    return false
  }

  // if right starts with lowercase latin, it is very likely a continuation
  match first_char(r) {
    Some(c) => if c >= 'a' && c <= 'z' { return true }
    None => ()
  }

  // if the previous page ends with a sentence terminator,
  // usually do not merge across page break
  if ends_like_sentence(l) {
    return false
  }

  true
}

///|
/// Conservative block boundary detection.
/// Only split early for strong structural signals.
/// Do NOT use short plain title heuristics here,
/// otherwise hard-wrapped Chinese lines will be over-split.
fn starts_like_new_block(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  if looks_like_list_item_sentence(t) {
    return true
  }

  if guess_numbered_heading_level(t) > 0 {
    return true
  }

  if looks_like_heading_marker(t) && !ends_like_sentence(t) {
    return true
  }

  // English title-like lines can start a new block,
  // but exclude common false positives first.
  if looks_like_english_title(t) &&
    !looks_like_figure_or_table_caption(t) &&
    !looks_like_intro_phrase(t) &&
    !looks_like_list_intro_line(t) {
    return true
  }

  false
}

///|
/// Strong heading candidate for block decisions.
/// This must stay conservative.
fn is_strong_heading_candidate(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  if is_probable_page_number(t) {
    return false
  }

  if ends_like_sentence(t) {
    return false
  }

  if looks_like_list_item_sentence(t) {
    return false
  }

  if looks_like_figure_or_table_caption(t) {
    return false
  }

  if looks_like_intro_phrase(t) {
    return false
  }

  if looks_like_list_intro_line(t) {
    return false
  }

  if guess_numbered_heading_level(t) > 0 {
    return true
  }

  if looks_like_heading_marker(t) {
    return true
  }

  if looks_like_english_title(t) {
    return true
  }

  false
}

///|
fn looks_like_figure_or_table_caption(s : String) -> Bool {
  let t = s.trim().to_string()
  t.has_prefix("Figure ") ||
  t.has_prefix("FIGURE ") ||
  t.has_prefix("Table ") ||
  t.has_prefix("TABLE ") ||
  t.has_prefix("图 ") ||
  t.has_prefix("图") ||
  t.has_prefix("表 ")
}

///|
fn looks_like_intro_phrase(s : String) -> Bool {
  let t = s.trim().to_string()
  t == "In conclusion," ||
  t == "In summary," ||
  t == "For example," ||
  t == "For instance," ||
  t == "However," ||
  t == "Therefore," ||
  t == "Moreover," ||
  t == "Nevertheless,"
}

///|
fn looks_like_list_intro_line(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  if !t.has_suffix(":") && !t.has_suffix("：") {
    return false
  }

  let n = t.to_array().length()

  // 典型短引导句
  if n <= 30 {
    return true
  }

  false
}

///|
fn append_line(buf : String, cur : String) -> String {
  if buf == "" {
    return cur
  }

  if ends_with_hyphen(buf) && starts_with_latin(cur) {
    return drop_last_char(buf) + cur
  }

  buf + glue_between(buf, cur) + cur
}

///|
fn guess_heading_level(text : String) -> Int {
  let t = text.trim().to_string()
  if t == "" {
    return 0
  }

  let n = t.to_array().length()

  if is_probable_page_number(t) {
    return 0
  }

  if ends_like_sentence(t) {
    return 0
  }

  let numbered = guess_numbered_heading_level(t)
  if numbered > 0 {
    return numbered
  }

  // explicit numbered / marker-based headings first
  if looks_like_heading_marker(t) {
    return if n <= 14 { 1 } else { 2 }
  }

  // short title-like lines: prefer H1 for document-title feel
  if looks_like_document_title(t) {
    return 1
  }

  // section-like headings fallback to H2
  if looks_like_section_title(t) {
    return 2
  }

  let sc = heading_score(t)
  if sc >= 7 {
    return 1
  }
  if sc >= 5 {
    return 2
  }
  0
}

///|
fn heading_score(s : String) -> Int {
  let t = s.trim().to_string()
  if t == "" {
    return 0
  }

  let n = t.to_array().length()
  let mut sc = 0

  if n <= 30 {
    sc += 2
  } else if n <= 50 {
    sc += 1
  } else if n > 80 {
    sc -= 2
  }

  if looks_like_heading_marker(t) {
    sc += 2
  }

  if looks_like_english_title(t) {
    sc += 2
  }

  if contains_sentence_punct_inside(t) {
    sc -= 2
  }

  if looks_like_list_item_sentence(t) {
    sc -= 2
  }

  // short compact non-latin lines are often hard-wrapped body lines,
  // not true headings
  if !t.contains(" ") && !starts_with_latin(t) && n >= 4 && n <= 12 {
    sc -= 2
  }

  sc
}

///|
/// very conservative compact CJK heading fallback
fn looks_like_compact_cjk_heading(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  if ends_like_sentence(t) {
    return false
  }

  if contains_sentence_punct_inside(t) {
    return false
  }

  if looks_like_list_item_sentence(t) {
    return false
  }

  if looks_like_figure_or_table_caption(t) {
    return false
  }

  if looks_like_list_intro_line(t) {
    return false
  }

  if starts_with_latin(t) {
    return false
  }

  let n = t.to_array().length()

  // only compact Chinese-ish titles, not too short, not too long
  if n < 4 || n > 8 {
    return false
  }

  if t.contains(" ") {
    return false
  }

  // require all chars to be cjk-ish
  for c in t.to_array() {
    if !is_cjkish(c) {
      return false
    }
  }

  true
}

///|
fn guess_numbered_heading_level(s : String) -> Int {
  let t = s.trim().to_string()

  if t.has_prefix("第一章") ||
    t.has_prefix("第二章") ||
    t.has_prefix("第三章") ||
    t.has_prefix("第四章") ||
    t.has_prefix("第五章") ||
    t.has_prefix("Chapter ") ||
    t.has_prefix("CHAPTER ") {
    return 1
  }

  let dots = count_prefix_dots_in_heading_number(t)
  if dots >= 2 {
    return 3
  }
  if dots == 1 {
    return 2
  }

  if starts_with_top_level_number(t) {
    return 1
  }

  if t.has_prefix("一、") ||
    t.has_prefix("二、") ||
    t.has_prefix("三、") ||
    t.has_prefix("四、") ||
    t.has_prefix("五、") {
    return 1
  }

  if t.has_prefix("（一）") ||
    t.has_prefix("（二）") ||
    t.has_prefix("（三）") {
    return 2
  }

  0
}

///|
/// 例如 "1.1 研究目标" 返回 1
/// 例如 "1.2.3 标题" 返回 2
fn count_prefix_dots_in_heading_number(s : String) -> Int {
  let cs = s.to_array()
  let n = cs.length()
  let mut i = 0
  let mut saw_digit = false
  let mut dots = 0

  while i < n {
    let c = cs[i]
    if c >= '0' && c <= '9' {
      saw_digit = true
      i += 1
      continue
    }
    if c == '.' {
      dots += 1
      i += 1
      continue
    }
    break
  }

  if saw_digit {
    dots
  } else {
    0
  }
}

///|
fn starts_with_top_level_number(s : String) -> Bool {
  let cs = s.to_array()
  let n = cs.length()
  if n == 0 {
    return false
  }

  let mut i = 0
  let mut has_digit = false
  while i < n {
    let c = cs[i]
    if c >= '0' && c <= '9' {
      has_digit = true
      i += 1
      continue
    }
    break
  }

  if !has_digit || i >= n {
    return false
  }

  let c = cs[i]
  c == ' ' || c == '、' || c == ')' || c == '）' || c == '.'
}

///|
fn ends_like_sentence(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }
  match last_char(t) {
    Some(c) =>
      c == '。' ||
      c == '！' ||
      c == '？' ||
      c == '.' ||
      c == '!' ||
      c == '?' ||
      c == '；' ||
      c == ';' ||
      c == '：' ||
      c == ':'
    None => false
  }
}

///|
fn looks_like_heading_marker(s : String) -> Bool {
  let t = s.trim().to_string()
  t.has_prefix("第") ||
  t.has_prefix("Chapter") ||
  t.has_prefix("CHAPTER") ||
  t.has_prefix("Section") ||
  t.has_prefix("SECTION") ||
  t.has_prefix("一、") ||
  t.has_prefix("二、") ||
  t.has_prefix("三、") ||
  t.has_prefix("四、") ||
  t.has_prefix("五、") ||
  t.has_prefix("（一）") ||
  t.has_prefix("（二）") ||
  t.has_prefix("（三）") ||
  starts_with_numbered_heading(t)
}

///|
fn looks_like_english_title(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  if ends_like_sentence(t) {
    return false
  }

  if looks_like_figure_or_table_caption(t) {
    return false
  }

  if looks_like_intro_phrase(t) {
    return false
  }

  if looks_like_list_intro_line(t) {
    return false
  }

  let words : Array[String] = []
  for sv in t.split(" ") {
    let w = sv.to_string().trim().to_string()
    if w != "" {
      words.push(w)
    }
  }

  if words.length() == 0 || words.length() > 8 {
    return false
  }

  let mut latin_words = 0
  let mut good_caps = 0

  for w in words {
    if starts_with_latin(w) {
      latin_words += 1
      match first_char(w) {
        Some(c) => if c >= 'A' && c <= 'Z' { good_caps += 1 }
        None => ()
      }
    }
  }

  // allow single-word titles like Summary / Method / Introduction
  if words.length() == 1 {
    return latin_words == 1 && good_caps == 1
  }

  latin_words >= 2 && good_caps >= 2
}

///|
fn starts_with_numbered_heading(s : String) -> Bool {
  let t = s.trim().to_string()
  let cs = t.to_array()
  let n = cs.length()
  if n == 0 {
    return false
  }

  let mut i = 0
  let mut has_digit = false

  while i < n {
    let c = cs[i]
    if c >= '0' && c <= '9' {
      has_digit = true
      i += 1
      continue
    }
    if c == '.' {
      i += 1
      continue
    }
    break
  }

  if !has_digit || i >= n {
    return false
  }

  let c = cs[i]
  if c == ' ' || c == '、' || c == ')' || c == '）' {
    return true
  }

  if c == '.' && i + 1 < n && cs[i + 1] == ' ' {
    return true
  }

  false
}

///|
fn is_probable_page_number(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  if t.has_prefix("Page ") ||
    t.has_prefix("page ") ||
    (t.contains("第") && t.contains("页")) {
    return true
  }

  if looks_like_fraction_page_number(t) {
    return true
  }

  let cs = t.to_array()
  let mut all_digit = true
  for c in cs {
    if !(c >= '0' && c <= '9') {
      all_digit = false
      break
    }
  }
  all_digit
}

///|
fn looks_like_fraction_page_number(s : String) -> Bool {
  let t = s.trim().to_string()
  let cs = t.to_array()
  let n = cs.length()

  if n < 3 {
    return false
  }

  let mut slash_pos = -1
  let mut i = 0
  while i < n {
    if cs[i] == '/' {
      slash_pos = i
      break
    }
    i += 1
  }

  if slash_pos <= 0 || slash_pos >= n - 1 {
    return false
  }

  let mut left_ok = true
  for j in 0..<slash_pos {
    let c = cs[j]
    if !(c >= '0' && c <= '9') && c != ' ' {
      left_ok = false
      break
    }
  }

  let mut right_ok = true
  for j in (slash_pos + 1)..<n {
    let c = cs[j]
    if !(c >= '0' && c <= '9') && c != ' ' {
      right_ok = false
      break
    }
  }

  left_ok && right_ok
}

///|
fn is_noise_line(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  if is_probable_page_number(t) {
    return true
  }

  let cs = t.to_array()
  if cs.length() <= 3 {
    let mut ok = true
    for c in cs {
      let is_digit = c >= '0' && c <= '9'
      let is_sym = c == '-' || c == '_' || c == '.' || c == '·'
      if !(is_digit || is_sym) {
        ok = false
        break
      }
    }
    if ok {
      return true
    }
  }

  false
}

///|
fn ends_with_hyphen(s : String) -> Bool {
  match last_char(s) {
    Some(c) => c == '-'
    None => false
  }
}

///|
fn starts_with_latin(s : String) -> Bool {
  match first_char(s) {
    Some(c) => (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
    None => false
  }
}

///|
fn drop_last_char(s : String) -> String {
  let cs = s.to_array()
  let n = cs.length()
  if n == 0 {
    return s
  }
  String::from_array(cs[:n - 1].to_array())
}

///|
/// 段落最后做一次清理：多空格折叠 + trim（字符级，不走 bytes）
fn finalize_paragraph(s : String) -> String {
  let t = s.trim()
  if t == "" {
    return ""
  }

  let mut out = ""
  let mut prev_space = false
  for c in t.to_array() {
    if c == ' ' {
      if !prev_space {
        out = out + " "
        prev_space = true
      }
    } else {
      out = out + c.to_string()
      prev_space = false
    }
  }

  remove_cjk_inner_spaces(out.trim().to_string())
}

///|
fn finalize_heading(s : String) -> String {
  let t = s.trim()
  if t == "" {
    return ""
  }

  let mut out = ""
  let mut prev_space = false
  for c in t.to_array() {
    if c == ' ' {
      if !prev_space {
        out = out + " "
        prev_space = true
      }
    } else {
      out = out + c.to_string()
      prev_space = false
    }
  }

  out.trim().to_string()
}

///|
/// 去掉中文/全角符号之间的“字间空格”
fn remove_cjk_inner_spaces(s : String) -> String {
  let cs = s.to_array()
  let n = cs.length()
  if n == 0 {
    return s
  }

  let mut out = ""
  let mut i = 0
  while i < n {
    let c = cs[i]

    if c == ' ' {
      if i > 0 && i + 1 < n {
        let prev = cs[i - 1]
        let next = cs[i + 1]
        if is_cjkish(prev) && is_cjkish(next) {
          i = i + 1
          continue
        }
      }
      out = out + " "
      i = i + 1
      continue
    }

    out = out + c.to_string()
    i = i + 1
  }

  out
}

///|
/// 粗略判断“中文相关字符”：CJK 汉字,全角区（含中文标点）,常见中文标点
fn is_cjkish(c : Char) -> Bool {
  let x = c.to_int()
  (x >= 0x4E00 && x <= 0x9FFF) || // CJK Unified
  (x >= 0x3400 && x <= 0x4DBF) || // Extension A
  (x >= 0xF900 && x <= 0xFAFF) || // Compatibility
  (x >= 0xFF00 && x <= 0xFFEF) || // Half/Full width
  c == '，' ||
  c == '。' ||
  c == '；' ||
  c == '：' ||
  c == '！' ||
  c == '？'
}

///|
/// 决定拼接时加不加空格：
/// - CJK + CJK：不加空格（中文不应该被强行加空格）
/// - 其他情况：加一个空格
fn glue_between(left : String, right : String) -> String {
  let lc = last_char(left)
  let rc = first_char(right)
  match (lc, rc) {
    (Some(a), Some(b)) => if is_cjk(a) && is_cjk(b) { "" } else { " " }
    _ => " "
  }
}

///|
fn first_char(s : String) -> Char? {
  let arr = s.trim().to_array()
  if arr.length() == 0 {
    None
  } else {
    Some(arr[0])
  }
}

///|
fn last_char(s : String) -> Char? {
  let arr = s.trim().to_array()
  let n = arr.length()
  if n == 0 {
    None
  } else {
    Some(arr[n - 1])
  }
}

///|
/// 粗略 CJK 判定（足够 MVP）
/// 覆盖：CJK Unified / Extensions / 常用全角符号区
fn is_cjk(c : Char) -> Bool {
  let x = c.to_int()
  (x >= 0x4E00 && x <= 0x9FFF) ||
  (x >= 0x3400 && x <= 0x4DBF) ||
  (x >= 0xF900 && x <= 0xFAFF) ||
  (x >= 0xFF00 && x <= 0xFFEF)
}

///|
fn contains_sentence_punct_inside(s : String) -> Bool {
  for c in s.to_array() {
    if c == '，' ||
      c == '。' ||
      c == '；' ||
      c == '：' ||
      c == ',' ||
      c == ';' ||
      c == ':' {
      return true
    }
  }
  false
}

///|
fn looks_like_list_item_sentence(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  if t.has_prefix("- ") || t.has_prefix("* ") || t.has_prefix("• ") {
    return true
  }

  let cs = t.to_array()
  let n = cs.length()
  if n == 0 {
    return false
  }

  let mut i = 0
  let mut has_digit = false
  while i < n {
    let c = cs[i]
    if c >= '0' && c <= '9' {
      has_digit = true
      i += 1
      continue
    }
    break
  }

  if has_digit && i + 1 < n {
    let c = cs[i]
    if (c == '.' || c == '、' || c == ')' || c == '）') && cs[i + 1] == ' ' {
      return true
    }
  }

  false
}

///|
/// Heuristic for document-level title.
/// Used to restore old PDF samples where the first main title should be H1.
fn looks_like_document_title(s : String) -> Bool {
  let t = s.trim().to_string()
  let words : Array[String] = []
  for sv in t.split(" ") {
    let w = sv.to_string().trim().to_string()
    if w != "" {
      words.push(w)
    }
  }
  if t.has_suffix(" Section") {
    return false
  }
  // single-word English title is more likely a section title than document title
  if words.length() == 1 && starts_with_latin(words[0]) {
    return false
  }
  if t == "" {
    return false
  }

  if ends_like_sentence(t) {
    return false
  }

  if looks_like_figure_or_table_caption(t) {
    return false
  }

  if looks_like_intro_phrase(t) {
    return false
  }

  if looks_like_list_intro_line(t) {
    return false
  }

  if looks_like_list_item_sentence(t) {
    return false
  }

  let n = t.to_array().length()

  // short / medium title-like line
  if n < 4 || n > 40 {
    return false
  }

  // English title
  if looks_like_english_title(t) {
    return true
  }

  // Compact CJK title
  if looks_like_compact_cjk_heading(t) {
    return true
  }

  false
}

///|
/// Heuristic for section-like heading.
/// Usually maps to H2 unless numbering rules say otherwise.
fn looks_like_section_title(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  if ends_like_sentence(t) {
    return false
  }

  if looks_like_figure_or_table_caption(t) {
    return false
  }

  if looks_like_intro_phrase(t) {
    return false
  }

  if looks_like_list_intro_line(t) {
    return false
  }

  if looks_like_list_item_sentence(t) {
    return false
  }

  if looks_like_english_title(t) {
    return true
  }

  if looks_like_compact_cjk_heading(t) {
    return true
  }

  if looks_like_heading_marker(t) {
    return true
  }

  false
}

///|
/// If the current buffer already looks like a complete standalone block,
/// do not keep appending normal body text to it.
fn should_flush_buf_before_appending(buf : String, cur : String) -> Bool {
  let b = buf.trim().to_string()
  let t = cur.trim().to_string()

  if b == "" || t == "" {
    return false
  }

  // a heading candidate should usually stand alone
  if is_strong_heading_candidate(b) &&
    !is_strong_heading_candidate(t) &&
    !looks_like_list_item_sentence(t) {
    return true
  }

  // a single list item should not absorb following prose
  if looks_like_list_item_sentence(b) && !looks_like_list_item_sentence(t) {
    return true
  }
  if ends_like_sentence(b) && looks_like_figure_or_table_caption(t) {
    return true
  }

  if ends_like_sentence(b) && looks_like_intro_phrase(t) {
    return true
  }

  false
}


///|
fn is_pdf_list_item(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  if t.has_prefix("• ") || t.has_prefix("- ") || t.has_prefix("* ") {
    return true
  }

  let cs = t.to_array()
  let n = cs.length()
  if n == 0 {
    return false
  }

  let mut i = 0
  let mut has_digit = false
  while i < n {
    let c = cs[i]
    if c >= '0' && c <= '9' {
      has_digit = true
      i += 1
      continue
    }
    break
  }

  if has_digit && i + 1 < n {
    let c = cs[i]
    if (c == '.' || c == ')' || c == '）' || c == '、') && cs[i + 1] == ' ' {
      return true
    }
  }

  false
}

///|
fn parse_pdf_list_item(s : String) -> (Bool, Int, String)? raise{
  let t = s.trim().to_string()
  if t == "" {
    return None
  }

  if t.has_prefix("• ") || t.has_prefix("- ") || t.has_prefix("* ") {
    return Some((false, 0, t[2:].trim().to_string()))
  }

  let cs = t.to_array()
  let n = cs.length()
  if n == 0 {
    return None
  }

  let mut i = 0
  let mut has_digit = false
  while i < n {
    let c = cs[i]
    if c >= '0' && c <= '9' {
      has_digit = true
      i += 1
      continue
    }
    break
  }

  if has_digit && i + 1 < n {
    let c = cs[i]
    if (c == '.' || c == ')' || c == '）' || c == '、') && cs[i + 1] == ' ' {
      let text = String::from_array(cs[i + 2:].to_array()).trim().to_string()
      return Some((true, 0, text))
    }
  }

  None
}