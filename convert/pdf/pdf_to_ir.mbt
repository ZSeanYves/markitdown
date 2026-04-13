///|
fn pipeline_to_ir(
  input_path : String,
  out_dir : String,
  pages : Array[PdfConvertPage],
  blocks : Array[Array[PdfConvertBlock]],
  pipeline_debug : Bool,
) -> @cor.Document {
  if pipeline_debug {
    dump_pdf_debug_stage(input_path, out_dir, "lines", render_lines(pages))
    dump_pdf_debug_stage(input_path, out_dir, "blocks", render_blocks(blocks))
  }

  let doc = @cor.new_document()
  for page_blocks in blocks {
    let mut i = 0
    while i < page_blocks.length() {
      let b = page_blocks[i]
      let t = b.text.trim().to_string()
      if t == "" {
        i = i + 1
        continue
      }

      if should_promote_to_heading(page_blocks, i) {
        let level = if b.kind == PdfConvertBlockKind::Heading {
          clamp_heading_level(b.heading_level)
        } else {
          1
        }
        @cor.push(doc, @cor.Block::Heading(level, t))
      } else {
        @cor.push(doc, @cor.Block::Paragraph(t))
      }
      i = i + 1
    }
  }
  doc
}

///|
fn clamp_heading_level(level : Int) -> Int {
  if level <= 0 {
    1
  } else if level > 6 {
    6
  } else {
    level
  }
}

///|
fn render_lines(pages : Array[PdfConvertPage]) -> String {
  let out : Array[String] = []
  for p in pages {
    out.push("## page " + p.page_index.to_string())
    for line in p.lines {
      out.push(
        "- [" +
        line.line_index.to_string() +
        "] br=" +
        line.is_paragraph_break.to_string() +
        " strong_break_after=" +
        line.strong_break_after.to_string() +
        " text=" +
        line.text,
      )
    }
    out.push("")
  }
  out.join("\n")
}

///|
fn render_blocks(pages : Array[Array[PdfConvertBlock]]) -> String {
  let out : Array[String] = []
  for page_blocks in pages {
    if page_blocks.length() == 0 {
      continue
    }

    out.push("## page " + page_blocks[0].page_index.to_string())
    for b in page_blocks {
      let kind = match b.kind {
        PdfConvertBlockKind::Heading =>
          "heading(h" + b.heading_level.to_string() + ")"
        PdfConvertBlockKind::Paragraph => "paragraph"
      }
      out.push(
        "- " +
        kind +
        " [" +
        b.line_start.to_string() +
        "-" +
        b.line_end.to_string() +
        "] text=" +
        b.text,
      )
    }
    out.push("")
  }
  out.join("\n")
}

///|
fn should_promote_to_heading(
  page_blocks : Array[PdfConvertBlock],
  index : Int,
) -> Bool {
  let b = page_blocks[index]
  let t = b.text.trim().to_string()
  if t == "" {
    return false
  }

  // 原有高置信标题判定（显式前缀）
  if is_explicit_heading_marker(t) {
    return true
  }

  // 新增：针对已独立成块的短标题行，且后续紧跟正文时，做最小提升
  if !is_high_conf_short_heading_candidate(b, t) {
    return false
  }

  has_body_like_next_block(page_blocks, index)
}

///|
fn is_explicit_heading_marker(t : String) -> Bool {
  if t.has_prefix("#") {
    return true
  }
  if t.has_prefix("第") && (t.contains("章") || t.contains("节")) {
    return true
  }
  t.has_prefix("Chapter ") || t.has_prefix("CHAPTER ")
}

///|
fn is_high_conf_short_heading_candidate(
  b : PdfConvertBlock,
  t : String,
) -> Bool {
  if b.line_start != b.line_end {
    return false
  }

  let n = t.to_array().length()
  if n < 2 || n > 36 {
    return false
  }
  if ends_with_sentence_punct(t) {
    return false
  }

  looks_like_titlecase_english_line(t) || looks_like_short_cjk_heading_line(t)
}

///|
fn has_body_like_next_block(
  page_blocks : Array[PdfConvertBlock],
  index : Int,
) -> Bool {
  if index + 1 >= page_blocks.length() {
    return false
  }
  let next = page_blocks[index + 1].text.trim().to_string()
  if next == "" {
    return false
  }
  is_body_like_line(next)
}

///|
fn is_body_like_line(text : String) -> Bool {
  if ends_with_sentence_punct(text) {
    return true
  }
  let ws = split_words_simple(text)
  if ws.length() >= 6 {
    return true
  }
  let n = text.to_array().length()
  if n >= 24 && ws.length() >= 4 {
    return true
  }
  n >= 16 && is_mostly_cjk_text(text)
}

///|
fn looks_like_titlecase_english_line(text : String) -> Bool {
  let ws = split_words_simple(text)
  if ws.length() < 2 || ws.length() > 6 {
    return false
  }

  let mut titleish = 0
  for w in ws {
    let token = trim_heading_token_punct(w)
    match first_char_heading(token) {
      Some(c) =>
        if (c >= 'A' && c <= 'Z') || is_all_caps_heading_word(token) {
          titleish = titleish + 1
        }
      None => ()
    }
  }
  titleish * 2 >= ws.length()
}

///|
fn looks_like_short_cjk_heading_line(text : String) -> Bool {
  if text.contains(" ") {
    return false
  }
  let n = text.to_array().length()
  if n < 2 || n > 10 {
    return false
  }
  is_mostly_cjk_text(text)
}

///|
fn ends_with_sentence_punct(text : String) -> Bool {
  match last_char_heading(text.trim().to_string()) {
    Some(c) =>
      c == '。' || c == '！' || c == '？' ||
      c == '.' || c == '!' || c == '?'
    None => false
  }
}

///|
fn is_mostly_cjk_text(text : String) -> Bool {
  let cs = text.to_array()
  if cs.length() == 0 {
    return false
  }
  let mut cjk = 0
  for c in cs {
    if is_cjkish(c) {
      cjk = cjk + 1
    }
  }
  cjk * 3 >= cs.length() * 2
}

///|
fn trim_heading_token_punct(s : String) -> String {
  let mut t = s.trim().to_string()
  while t != "" {
    match first_char_heading(t) {
      Some(c) =>
        if c == '"' || c == '\'' || c == '(' || c == '[' {
          t = String::from_array(t.to_array()[1:].to_array()).trim().to_string()
          continue
        }
      None => ()
    }
    break
  }
  while t != "" {
    match last_char_heading(t) {
      Some(c) =>
        if c == '"' || c == '\'' || c == ')' || c == ']' || c == ',' || c == '.' || c == ':' || c == ';' {
          let cs = t.to_array()
          t = String::from_array(cs[:cs.length() - 1].to_array()).trim().to_string()
          continue
        }
      None => ()
    }
    break
  }
  t
}

///|
fn is_all_caps_heading_word(s : String) -> Bool {
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
fn first_char_heading(s : String) -> Char? {
  let cs = s.to_array()
  if cs.length() == 0 {
    None
  } else {
    Some(cs[0])
  }
}

///|
fn last_char_heading(s : String) -> Char? {
  let cs = s.to_array()
  let n = cs.length()
  if n == 0 {
    None
  } else {
    Some(cs[n - 1])
  }
}
