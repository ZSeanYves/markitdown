///|
/// Document-title shape signals used by final PDF IR heading rules.
fn looks_like_document_title_role_for_ir(
  text : String,
  block : PdfConvertBlock,
  prev : PdfConvertBlock?,
  next : PdfConvertBlock?,
) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  // 常见 section label 不当文档标题
  if looks_like_common_section_label_for_ir(t) {
    return false
  }

  // 显式 section depth 一律视为正文结构，不是 document title
  if infer_section_depth_for_ir(t) > 0 {
    return false
  }

  // 必须在首页前部
  if block._page_index != 0 || block.block_index > 2 {
    return false
  }

  if block.line_count > 2 {
    return false
  }

  if !looks_like_strong_document_title_for_ir(t) {
    return false
  }

  // 文档标题有两种典型来源：
  // 1) 词表型：report/pipeline/test/sample 等
  // 2) 压缩标题短语：Cross-page should merge / Heading vs Short Sentence
  // 3) 中英混合项目标题
  let title_shape = looks_like_document_title_phrase_for_ir(t) ||
    looks_like_mixed_document_title_for_ir(t) ||
    looks_like_compact_predicative_title_for_ir(t)

  // 版面/上下文辅助：更大字号 or 后续像正文
  let layout_support = is_visually_larger_than_neighbors(prev, block, next) ||
    next_block_looks_like_body_for_h1(next)

  title_shape || layout_support
}

///|
/// 英文标题形态。
fn looks_like_english_title_for_ir(s : String) -> Bool {
  let t = s.trim().to_owned()
  if t == "" {
    return false
  }

  if ends_like_sentence_for_heading(t) {
    return false
  }

  if looks_like_figure_or_table_caption_for_ir(t) {
    return false
  }

  if looks_like_intro_phrase_for_ir(t) {
    return false
  }

  if looks_like_list_intro_line_for_ir(t) {
    return false
  }

  let words : Array[String] = []
  for sv in t.split(" ") {
    let w = sv.trim().to_owned()
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
    if starts_with_latin_for_ir(w) {
      latin_words += 1
      match first_char_for_ir(w) {
        Some(c) => if c >= 'A' && c <= 'Z' { good_caps += 1 }
        None => ()
      }
    }
  }

  if words.length() == 1 {
    return latin_words == 1 && good_caps == 1
  }

  latin_words >= 2 && good_caps >= 2
}

///|
/// 更像“压缩命题标题短语”。
/// 例如：
/// - Cross-page should merge
/// - Cross-page should NOT merge
/// - Heading vs Short Sentence
fn looks_like_compact_predicative_title_for_ir(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  if ends_like_sentence_for_heading(t) ||
    looks_like_figure_or_table_caption_for_ir(t) ||
    looks_like_intro_phrase_for_ir(t) ||
    looks_like_list_intro_line_for_ir(t) ||
    looks_like_list_item_sentence_for_ir(t) ||
    is_probable_page_number_for_ir(t) ||
    looks_like_side_marker_label_line_for_ir(t) {
    return false
  }

  let words = split_non_empty_words_for_ir(t)
  if words.length() < 2 || words.length() > 6 {
    return false
  }

  let first = ascii_lower_for_ir(strip_edge_punct_for_ir(words[0]))
  if first == "this" || first == "the" || first == "a" || first == "an" {
    return false
  }

  let mut has_vs = false
  let mut has_modal = false
  let mut has_latin = false

  for w in words {
    let lw = ascii_lower_for_ir(strip_edge_punct_for_ir(w))
    if lw == "vs" {
      has_vs = true
    }
    if lw == "should" ||
      lw == "must" ||
      lw == "can" ||
      lw == "will" ||
      lw == "may" {
      has_modal = true
    }
    if starts_with_latin_for_ir(w) {
      has_latin = true
    }
  }

  if !has_latin {
    return false
  }

  if has_vs {
    return true
  }

  if has_modal &&
    words.length() <= 5 &&
    !looks_like_complete_statement_for_ir(t) {
    return true
  }

  false
}

///|
/// 更像完整正文句，而不是标题。
fn looks_like_complete_statement_for_ir(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  if ends_like_sentence_for_heading(t) {
    return true
  }

  if looks_like_figure_or_table_caption_for_ir(t) ||
    looks_like_intro_phrase_for_ir(t) ||
    looks_like_list_intro_line_for_ir(t) ||
    looks_like_list_item_sentence_for_ir(t) {
    return false
  }

  let words = split_non_empty_words_for_ir(t)
  if words.length() <= 3 {
    return false
  }

  let mut stop_hits = 0
  let mut verb_hits = 0
  let mut clause_hits = 0

  for w in words {
    let lw = ascii_lower_for_ir(strip_edge_punct_for_ir(w))
    if lw == "" {
      continue
    }

    if is_statement_stopword_for_ir(lw) {
      stop_hits += 1
    }
    if is_statement_verb_for_ir(lw) {
      verb_hits += 1
    }
    if is_statement_clause_marker_for_ir(lw) {
      clause_hits += 1
    }
  }

  if words.length() >= 8 && (stop_hits >= 2 || verb_hits >= 1) {
    return true
  }

  if clause_hits >= 1 && words.length() >= 6 {
    return true
  }

  let first = ascii_lower_for_ir(strip_edge_punct_for_ir(words[0]))
  if (first == "this" || first == "the" || first == "a" || first == "an") &&
    words.length() >= 5 &&
    verb_hits >= 1 {
    return true
  }

  false
}

///|
fn looks_like_compact_cjk_heading_for_ir(s : String) -> Bool {
  let t = s.trim().to_owned()
  if t == "" {
    return false
  }

  if ends_like_sentence_for_heading(t) {
    return false
  }

  if contains_sentence_punct_inside_for_ir(t) {
    return false
  }

  if looks_like_list_item_sentence_for_ir(t) {
    return false
  }

  if looks_like_figure_or_table_caption_for_ir(t) {
    return false
  }

  if looks_like_list_intro_line_for_ir(t) {
    return false
  }

  if starts_with_latin_for_ir(t) {
    return false
  }

  let n = t.to_array().length()
  if n < 2 || n > 12 {
    return false
  }

  if t.contains(" ") {
    return false
  }

  for c in t.to_array() {
    if !is_cjkish_for_ir(c) {
      return false
    }
  }

  true
}

///|
fn looks_like_strong_document_title_for_ir(s : String) -> Bool {
  let t = s.trim().to_owned()
  if t == "" {
    return false
  }

  if is_probable_page_number_for_ir(t) ||
    looks_like_side_marker_label_line_for_ir(t) ||
    ends_like_sentence_for_heading(t) ||
    looks_like_list_item_sentence_for_ir(t) ||
    looks_like_figure_or_table_caption_for_ir(t) ||
    looks_like_intro_phrase_for_ir(t) ||
    looks_like_list_intro_line_for_ir(t) {
    return false
  }

  // 文档主标题不接受显式 section 编号。
  if infer_section_depth_for_ir(t) > 0 {
    return false
  }

  let n = t.to_array().length()
  if n < 4 || n > 80 {
    return false
  }

  looks_like_english_title_for_ir(t) ||
  looks_like_compact_cjk_heading_for_ir(t) ||
  looks_like_mixed_document_title_for_ir(t) ||
  looks_like_compact_predicative_title_for_ir(t)
}

///|
fn looks_like_mixed_document_title_for_ir(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  if ends_like_sentence_for_heading(t) ||
    looks_like_list_item_sentence_for_ir(t) ||
    looks_like_figure_or_table_caption_for_ir(t) ||
    looks_like_intro_phrase_for_ir(t) ||
    looks_like_list_intro_line_for_ir(t) {
    return false
  }

  let n = t.to_array().length()
  if n < 6 || n > 50 {
    return false
  }

  let words : Array[String] = []
  for sv in t.split(" ") {
    let w = sv.trim().to_owned()
    if w != "" {
      words.push(w)
    }
  }

  if words.length() < 2 || words.length() > 10 {
    return false
  }

  let mut has_latin = false
  let mut has_non_latin = false
  let mut good_caps = 0
  for w in words {
    if starts_with_latin_for_ir(w) {
      has_latin = true
      match first_char_for_ir(w) {
        Some(c) => if c >= 'A' && c <= 'Z' { good_caps += 1 }
        None => ()
      }
    } else {
      has_non_latin = true
    }
  }

  has_latin && has_non_latin && good_caps >= 1
}

///|
fn looks_like_document_title_phrase_for_ir(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  if looks_like_common_section_label_for_ir(t) {
    return false
  }

  let words = split_non_empty_words_for_ir(t)
  if words.length() < 2 || words.length() > 10 {
    return false
  }

  let lt = ascii_lower_for_ir(t)
  lt.contains("report") ||
  lt.contains("pipeline") ||
  lt.contains("test") ||
  lt.contains("sample") ||
  lt.contains("mvp") ||
  lt.contains("markitdown") ||
  lt.contains("moonbit")
}

///|
/// 常见 section 标题词表。
fn looks_like_common_section_label_for_ir(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  let lt = ascii_lower_for_ir(t)
  if lt == "introduction" ||
    lt == "method" ||
    lt == "methods" ||
    lt == "background" ||
    lt == "summary" ||
    lt == "details" ||
    lt == "conclusion" ||
    lt == "next section" ||
    lt == "related work" ||
    lt == "discussion" ||
    lt == "results" {
    return true
  }

  if t == "技术路线" ||
    t == "研究内容" ||
    t == "研究方法" ||
    t == "研究目标" ||
    t == "研究背景" ||
    t == "项目概述" ||
    t == "总结" ||
    t == "结论" ||
    t == "下一节" {
    return true
  }

  false
}

///|
/// 后继 block 像正文：有助于文档主标题判定。
fn next_block_looks_like_body_for_h1(next : PdfConvertBlock?) -> Bool {
  match next {
    None => false
    Some(b) => {
      let t = b.text.trim().to_owned()
      if t == "" {
        return false
      }

      b.kind == PdfConvertBlockKind::Paragraph ||
      ends_like_sentence_for_heading(t) ||
      looks_like_list_item_sentence_for_ir(t)
    }
  }
}
