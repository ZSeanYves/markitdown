///|
fn classify_blocks(
  pages : Array[PdfConvertPage],
  page_blocks : Array[Array[PdfConvertBlock]],
) -> Array[Array[PdfConvertBlock]] {
  let (head_keys, tail_keys) = detect_repeated_edge_noise(page_blocks)
  let out : Array[Array[PdfConvertBlock]] = []

  let mut p = 0
  while p < page_blocks.length() {
    let page = pages[p]
    let blocks = page_blocks[p]
    let page_out : Array[PdfConvertBlock] = []

    let mut i = 0
    while i < blocks.length() {
      let b = blocks[i]
      let text = b.text.trim().to_string()

      let (kind, ordered, list_level, heading_level) = classify_kind(text, i)
      let noise_reason = classify_noise(text, i, blocks.length(), head_keys, tail_keys)
      let noise = match noise_reason {
        Some(_) => true
        None => false
      }

      let cross_page = !noise &&
        kind == PdfConvertBlockKind::Paragraph &&
        i == blocks.length() - 1 &&
        block_near_page_end(page, b) &&
        !ends_like_sentence(text)

      page_out.push({
        kind,
        text: b.text,
        page_index: b.page_index,
        line_start: b.line_start,
        line_end: b.line_end,
        is_noise: noise,
        noise_reason,
        is_cross_page_continuation_candidate: cross_page,
        list_ordered: ordered,
        list_level,
        heading_level,
      })
      i = i + 1
    }

    out.push(page_out)
    p = p + 1
  }

  out
}

///|
fn classify_kind(text : String, idx : Int) -> (PdfConvertBlockKind, Bool, Int, Int) {
  let t = text.trim().to_string()
  if t == "" {
    return (PdfConvertBlockKind::Paragraph, false, 0, 0)
  }

  if is_probable_page_number(t) {
    return (PdfConvertBlockKind::Paragraph, false, 0, 0)
  }

  if looks_like_numbered_sentence(t) {
    return (PdfConvertBlockKind::Paragraph, false, 0, 0)
  }

  match parse_list_marker(t) {
    Some((ordered, level)) => return (PdfConvertBlockKind::ListItem, ordered, level, 0)
    None => ()
  }

  let heading_level = detect_heading_level(t, idx)
  if heading_level > 0 {
    return (PdfConvertBlockKind::Heading, false, 0, heading_level)
  }

  (PdfConvertBlockKind::Paragraph, false, 0, 0)
}

///|
fn classify_noise(
  text : String,
  idx : Int,
  page_len : Int,
  head_keys : Array[String],
  tail_keys : Array[String],
) -> String? {
  let t = text.trim().to_string()
  if t == "" {
    return Some("empty")
  }

  if is_probable_page_number(t) {
    return Some("page_number")
  }

  if is_edge_repeated_noise(t, idx, page_len, head_keys, tail_keys) {
    return Some("repeated_edge")
  }

  None
}

///|
fn block_near_page_end(page : PdfConvertPage, block : PdfConvertBlock) -> Bool {
  let total = page.lines.length()
  total > 0 && block.line_end >= total - 2
}

///|
/// 这一轮核心：大幅收紧 heading 判定。
///
/// 规则：
/// 1. 太短的碎片不升标题
/// 2. 末尾像句子/软分隔符的不升标题
/// 3. 带明显正文形态的不升标题
/// 4. 通用短标题只允许出现在页前 2 个 block
/// 5. 中文短标题必须“无空格、长度短、几乎全 CJK”
/// 6. 英文短标题必须“Title-ish 且不能太碎”
fn detect_heading_level(t : String, idx : Int) -> Int {
  let s = t.trim().to_string()
  let n = s.to_array().length()

  if n < 4 || n > 60 {
    return 0
  }

  if is_probable_page_number(s) {
    return 0
  }

  if ends_like_sentence(s) || ends_with_soft_punct(s) {
    return 0
  }

  if looks_like_numbered_sentence(s) {
    return 0
  }

  if has_obvious_body_shape(s) {
    return 0
  }

  if s.has_prefix("#") {
    return count_heading_marks(s)
  }

  if looks_like_chapter_heading(s) {
    return 1
  }

  if looks_like_section_heading(s) {
    return 2
  }

  if idx > 1 {
    return 0
  }

  if looks_like_short_cjk_heading(s) {
    return if idx == 0 { 1 } else { 2 }
  }

  if looks_like_short_english_heading(s) {
    return if idx == 0 { 1 } else { 2 }
  }

  0
}

///|
fn looks_like_chapter_heading(s : String) -> Bool {
  if s.has_prefix("第") && (s.contains("章") || s.contains("部分")) {
    return true
  }

  if s.has_prefix("Chapter ") || s.has_prefix("CHAPTER ") {
    return true
  }

  false
}

///|
fn looks_like_section_heading(s : String) -> Bool {
  if s.has_prefix("第") && s.contains("节") {
    return true
  }

  if has_numeric_heading_prefix(s) {
    return true
  }

  false
}

///|
/// 只识别 `1.1 标题` / `2.3.4 title`，
/// 不把 `1. this is a sentence` 当标题。
fn has_numeric_heading_prefix(s : String) -> Bool {
  let cs = s.to_array()
  let mut i = 0
  let mut dot_count = 0

  while i < cs.length() {
    let c = cs[i]
    if c >= '0' && c <= '9' {
      i = i + 1
      continue
    }

    if c == '.' {
      dot_count = dot_count + 1
      i = i + 1
      continue
    }

    break
  }

  if dot_count <= 0 {
    return false
  }

  if i >= cs.length() || cs[i] != ' ' {
    return false
  }

  let rest = String::from_array(cs[i + 1:].to_array()).trim().to_string()
  if rest == "" {
    return false
  }

  !looks_like_numbered_sentence(s)
}

///|
/// 收紧中文短标题：
/// - 不允许有空格
/// - 长度 4..12
/// - 不允许正文标点
/// - CJK 占比很高
fn looks_like_short_cjk_heading(s : String) -> Bool {
  if s.contains(" ") {
    return false
  }

  let n = s.to_array().length()
  if n < 4 || n > 12 {
    return false
  }

  if s.contains("：") || s.contains("，") || s.contains("。") {
    return false
  }

  let mut cjk = 0
  for c in s.to_array() {
    if is_cjkish(c) {
      cjk = cjk + 1
    }
  }

  cjk * 4 >= n * 3
}

///|
/// 收紧英文短标题：
/// - 词数 1..4
/// - 至少一个词长度 >= 4
/// - 不能是纯碎片（Con / This / OK 这类不上）
fn looks_like_short_english_heading(s : String) -> Bool {
  let ws = split_words_simple(s)
  if ws.length() == 0 || ws.length() > 4 {
    return false
  }

  let mut titleish = 0
  let mut has_long_word = false

  for w in ws {
    let cs = w.to_array()
    let n = cs.length()
    if n == 0 {
      continue
    }

    if n >= 4 {
      has_long_word = true
    }

    let c = cs[0]
    if (c >= 'A' && c <= 'Z') || is_all_caps_word(w) {
      titleish = titleish + 1
    }
  }

  if !has_long_word {
    return false
  }

  titleish * 2 >= ws.length()
}

///|
/// 明显更像正文而不是标题的形态。
fn has_obvious_body_shape(s : String) -> Bool {
  if s.contains(" but ") || s.contains(" and ") || s.contains(" or ") {
    return true
  }

  let ws = split_words_simple(s)
  if ws.length() >= 6 {
    return true
  }

  false
}

///|
fn count_heading_marks(s : String) -> Int {
  let cs = s.to_array()
  let mut i = 0
  while i < cs.length() && cs[i] == '#' {
    i = i + 1
  }

  if i <= 0 {
    1
  } else if i > 6 {
    6
  } else {
    i
  }
}

///|
/// 恢复最小 list：
/// - bullet list 永远可以
/// - ordered list 只允许“短项”
/// - 长句型编号继续按 paragraph
fn parse_list_marker(text : String) -> (Bool, Int)? {
  let t = text.trim().to_string()
  if t == "" {
    return None
  }

  if t.has_prefix("- ") || t.has_prefix("* ") || t.has_prefix("• ") {
    return Some((false, 1))
  }

  let cs = t.to_array()
  let mut i = 0
  while i < cs.length() && cs[i] >= '0' && cs[i] <= '9' {
    i = i + 1
  }

  if i > 0 && i + 1 < cs.length() {
    let sep = cs[i]
    let sp = cs[i + 1]
    if (sep == '.' || sep == ')') && sp == ' ' {
      let rest = String::from_array(cs[i + 2:].to_array()).trim().to_string()
      if rest != "" && !looks_like_numbered_sentence(t) {
        return Some((true, 1))
      }
    }
  }

  None
}

///|
/// `1. this is a numbered sentence ...` 这种长句不算 list item。
fn looks_like_numbered_sentence(s : String) -> Bool {
  let t = s.trim().to_string()
  let cs = t.to_array()

  let mut i = 0
  while i < cs.length() && cs[i] >= '0' && cs[i] <= '9' {
    i = i + 1
  }

  if i <= 0 || i + 1 >= cs.length() {
    return false
  }

  let sep = cs[i]
  let sp = cs[i + 1]
  if !((sep == '.' || sep == ')') && sp == ' ') {
    return false
  }

  let rest = String::from_array(cs[i + 2:].to_array()).trim().to_string()
  if rest == "" {
    return false
  }

  let words = split_words_simple(rest)
  words.length() >= 5 || rest.to_array().length() >= 28
}


///|
fn ends_with_soft_punct(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  let cs = t.to_array()
  let c = cs[cs.length() - 1]
  c == '：' || c == ':' || c == '，' || c == ',' || c == '；' || c == ';'
}

///|
fn is_all_caps_word(w : String) -> Bool {
  let cs = w.to_array()
  if cs.length() == 0 {
    return false
  }

  let mut seen_alpha = false
  for c in cs {
    if c >= 'a' && c <= 'z' {
      return false
    }
    if c >= 'A' && c <= 'Z' {
      seen_alpha = true
    }
  }
  seen_alpha
}

