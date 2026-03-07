///|
pub(all) enum PptxBlock {
  Heading(String)
  Paragraph(String)
  ListItem(String)
}

///|
/// scan slide xml, extract each <a:p> as one paragraph
fn extract_slide_paragraphs(xml : Bytes) -> Array[String] raise {
  let out : Array[String] = []

  let open_p = pat("<a:p")
  let close_p = pat("</a:p>")
  let gt_pat = pat(">")

  let mut pos = 0
  while true {
    let p0 = find_bytes(xml, open_p, pos)
    match p0 {
      None => break
      Some(i0) => {
        // find '>' end of <a:p ...>
        let gt = find_bytes(xml, gt_pat, i0)
        match gt {
          None => break
          Some(gt0) => {
            let inner_start = gt0 + 1
            let p_end = find_bytes(xml, close_p, inner_start)
            match p_end {
              None => break
              Some(p_end0) => {
                let line = extract_text_runs(xml, inner_start, p_end0)
                  .trim()
                  .to_string()

                if line != "" {
                  out.push(line)
                }

                pos = p_end0 + close_p.length()
              }
            }
          }
        }
      }
    }
  }

  out
}
///|
fn classify_slide_paragraphs(paras : Array[String]) -> Array[PptxBlock] raise{
  let out : Array[PptxBlock] = []
  let mut seen_heading = false

  for p0 in paras {
    let p = p0.trim().to_string()
    if p == "" {
      continue
    }

    if is_bullet_like(p) {
      out.push(PptxBlock::ListItem(strip_bullet_prefix(p)))
      continue
    }

    if !seen_heading && looks_like_slide_title(p) {
      out.push(PptxBlock::Heading(p))
      seen_heading = true
      continue
    }

    out.push(PptxBlock::Paragraph(p))
  }

  out
}

///|
fn looks_like_slide_title(s : String) -> Bool {
  let t = s.trim().to_string()
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
  let t = s.trim().to_string()
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
fn strip_bullet_prefix(s : String) -> String raise{
  let t = s.trim().to_string()

  if t.has_prefix("• ") || t.has_prefix("· ") || t.has_prefix("- ") ||
    t.has_prefix("* ") || t.has_prefix("‣ ") || t.has_prefix("▪ ") ||
    t.has_prefix("● ") || t.has_prefix("○ ") {
    return t[2:].to_string().trim().to_string()
  }

  if t.has_prefix("（1）") || t.has_prefix("（2）") || t.has_prefix("（3）") {
    return t[3:].to_string().trim().to_string()
  }

  let idx = find_numbered_bullet_end(t)
  if idx > 0 {
    return t[idx:].to_string().trim().to_string()
  }

  t
}

///|
fn ends_like_sentence(s : String) -> Bool {
  let t = s.trim().to_string()
  let arr = t.to_array()
  let n = arr.length()
  if n == 0 {
    return false
  }
  let c = arr[n - 1]
  c == '。' || c == '！' || c == '？' ||
  c == '.' || c == '!' || c == '?' ||
  c == '；' || c == ';' || c == '：' || c == ':'
}

///|
fn is_probable_slide_number(s : String) -> Bool {
  let t = s.trim().to_string()
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

