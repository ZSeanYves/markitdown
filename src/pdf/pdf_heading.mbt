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
