///|
/// Paragraph -> semantic block classification for PPTX text stream.
///
/// Design choice:
/// - caption-like snippets are intentionally not promoted to headings
/// - heading recovery is conservative (first high-confidence title wins)
/// - ambiguous text remains paragraph to protect main_process stability
fn classify_slide_paragraphs(paras : Array[SlideParagraph]) -> Array[PptxBlock] {
  let out : Array[PptxBlock] = []
  let mut seen_heading = false

  let compacted = compact_slide_paragraphs(paras)

  for i in 0..<compacted.length() {
    let para = compacted[i]
    let p = para.text.trim().to_owned()
    if p == "" {
      continue
    }

    // Caption-like text should stay as body text, not slide heading.
    if is_caption_like_text(p) {
      out.push(PptxBlock::Paragraph(p, para.inlines))
      continue
    }

    if para.from_title_shape && !seen_heading {
      out.push(PptxBlock::Heading(p, para.inlines))
      seen_heading = true
      continue
    }

    match para.bullet_kind {
      Some(kind) => {
        let level = if para.level >= 0 { para.level } else { 0 }
        let ordered = match kind {
          BulletKind::Unordered => false
          BulletKind::Ordered => true
        }
        out.push(
          PptxBlock::ListItem(
            ordered,
            level,
            strip_bullet_prefix(p),
            para.inlines,
          ),
        )
        continue
      }
      None => ()
    }

    if is_bullet_like(p) {
      let level = if para.level >= 0 { para.level } else { 0 }
      let ordered = starts_with_numbered_bullet(p)
      out.push(
        PptxBlock::ListItem(
          ordered,
          level,
          strip_bullet_prefix(p),
          para.inlines,
        ),
      )
      continue
    }

    if !seen_heading &&
      !para.from_body_shape &&
      para.level == 0 &&
      looks_like_slide_title(p) {
      match para.bullet_kind {
        Some(_) => ()
        None => {
          let next_is_body = if i + 1 < compacted.length() {
            compacted[i + 1].from_body_shape
          } else {
            false
          }

          if compacted.length() == 1 || (i == 0 && next_is_body) {
            out.push(PptxBlock::Heading(p, para.inlines))
            seen_heading = true
            continue
          }
        }
      }
    }

    out.push(PptxBlock::Paragraph(p, para.inlines))
  }

  out
}

///|
/// drop empty / shell-only paras, and dedupe adjacent duplicates
fn compact_slide_paragraphs(
  paras : Array[SlideParagraph],
) -> Array[SlideParagraph] {
  let out : Array[SlideParagraph] = []

  for para in paras {
    let text = normalize_slide_text(para.text)
    if text == "" {
      continue
    }

    if is_empty_bullet_shell(text) {
      continue
    }
    let cur : SlideParagraph = {
      source_para_id: para.source_para_id,
      text,
      inlines: para.inlines,
      bullet_kind: para.bullet_kind,
      level: para.level,
      from_title_shape: para.from_title_shape,
      from_body_shape: para.from_body_shape,
      associated_with_image_caption: para.associated_with_image_caption,
    }

    if out.length() == 0 {
      out.push(cur)
      continue
    }

    let last = out[out.length() - 1]
    if same_slide_para_text(last.text, cur.text) {
      if prefer_slide_para(cur, last) {
        out[out.length() - 1] = cur
      }
      continue
    }

    out.push(cur)
  }

  out
}

///|
fn is_empty_bullet_shell(s : String) -> Bool {
  let t = strip_bullet_prefix(normalize_slide_text(s))
  if t == "" {
    return true
  }

  let cs = t.to_array()
  if cs.length() == 0 {
    return true
  }

  let mut all_shell = true
  for c in cs {
    let is_space = c == ' '
    let is_sym = c == '-' ||
      c == '*' ||
      c == '•' ||
      c == '·' ||
      c == '.' ||
      c == ')' ||
      c == '）' ||
      c == '、'

    if !(is_space || is_sym) {
      all_shell = false
      break
    }
  }

  all_shell
}

///|
fn same_slide_para_text(a : String, b : String) -> Bool {
  normalize_slide_text(a) == normalize_slide_text(b)
}

///|
/// choose the more informative paragraph when duplicated
fn prefer_slide_para(a : SlideParagraph, b : SlideParagraph) -> Bool {
  let sa = slide_para_score(a)
  let sb = slide_para_score(b)
  sa > sb
}

///|
fn slide_para_score(p : SlideParagraph) -> Int {
  let mut sc = 0
  if p.from_title_shape {
    sc += 4
  }
  if p.from_body_shape {
    sc += 2
  }
  match p.bullet_kind {
    Some(_) => sc += 1
    None => ()
  }
  if p.level > 0 {
    sc += 1
  }
  sc
}

///|
fn looks_like_slide_title(s : String) -> Bool {
  let t = s.trim().to_owned()
  if t == "" {
    return false
  }

  let n = t.to_array().length()
  if n > 40 {
    return false
  }

  if is_bullet_like(t) {
    return false
  }

  if ends_like_sentence(t) {
    return false
  }

  if is_probable_slide_number(t) {
    return false
  }

  true
}

///|
fn is_bullet_like(s : String) -> Bool {
  let t = s.trim().to_owned()
  t.has_prefix("• ") ||
  t.has_prefix("· ") ||
  t.has_prefix("- ") ||
  t.has_prefix("* ") ||
  t.has_prefix("‣ ") ||
  t.has_prefix("▪ ") ||
  t.has_prefix("● ") ||
  t.has_prefix("○ ") ||
  t.has_prefix("（1）") ||
  t.has_prefix("（2）") ||
  t.has_prefix("（3）") ||
  starts_with_numbered_bullet(t)
}

///|
fn strip_bullet_prefix(s : String) -> String {
  let t = s.trim().to_owned()

  if t.has_prefix("• ") ||
    t.has_prefix("· ") ||
    t.has_prefix("- ") ||
    t.has_prefix("* ") ||
    t.has_prefix("‣ ") ||
    t.has_prefix("▪ ") ||
    t.has_prefix("● ") ||
    t.has_prefix("○ ") {
    return t[2:].trim().to_owned()
  }

  if t.has_prefix("（1）") ||
    t.has_prefix("（2）") ||
    t.has_prefix("（3）") {
    return t[3:].trim().to_owned()
  }

  let idx = find_numbered_bullet_end(t)
  if idx > 0 {
    return t[idx:].trim().to_owned()
  }

  t
}

///|
fn ends_like_sentence(s : String) -> Bool {
  let t = s.trim().to_owned()
  let arr = t.to_array()
  let n = arr.length()
  if n == 0 {
    return false
  }
  let c = arr[n - 1]
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
}

///|
fn is_probable_slide_number(s : String) -> Bool {
  let t = s.trim().to_owned()
  if t == "" {
    return false
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
fn starts_with_numbered_bullet(s : String) -> Bool {
  find_numbered_bullet_end(s) > 0
}

///|
/// 返回正文起始下标；不是编号 bullet 则返回 -1
fn find_numbered_bullet_end(s : String) -> Int {
  let cs = s.to_array()
  let n = cs.length()
  if n == 0 {
    return -1
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
    return -1
  }

  if cs[i] == '.' || cs[i] == '、' || cs[i] == ')' || cs[i] == '）' {
    i += 1
    while i < n && cs[i] == ' ' {
      i += 1
    }
    return i
  }

  -1
}
