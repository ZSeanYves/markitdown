///|
/// Convert plain text into IR.
/// New strategy:
/// - Normalize line endings
/// - Split pages by formfeed \f
/// - Detect repeated header/footer noise across pages
/// - Strip page-level noise page by page
/// - Merge cleaned pages with an internal page-break marker
/// - Recover blocks once on the merged text
fn text_to_ir_document(text0 : String) -> @cor.Document {
  let text = @cor.normalize_text(text0)
  let doc = @cor.new_document()

  let pages : Array[String] = []
  for page_sv in text.split("\f") {
    let page = page_sv.to_string()
    if page.trim() != "" {
      pages.push(page)
    }
  }

  if pages.length() == 0 {
    return doc
  }

  let (head_keys, tail_keys) = detect_repeated_page_noise(pages)

  let clean_pages : Array[String] = []
  let mut page_idx = 0
  for page in pages {
    let clean_page = strip_page_noise(page, head_keys, tail_keys)
    if clean_page.trim() != "" {
      clean_pages.push(clean_page)

      println("[pdf-cross-debug] clean page " + page_idx.to_string())
      let mut shown = 0
      for sv in clean_page.split("\n") {
        let line = sv.to_string().trim().to_string()
        if line != "" {
          println("[pdf-cross-debug]   " + line)
          shown += 1
          if shown >= 8 {
            break
          }
        }
      }
    }
    page_idx += 1
  }

  let merged = merge_clean_pages_with_breaks(clean_pages)
  println("[pdf-cross-debug] merged preview")
  let mut shown = 0
  for sv in merged.split("\n") {
    let line = sv.to_string().trim().to_string()
    if line != "" {
      println("[pdf-cross-debug]   " + line)
      shown += 1
      if shown >= 15 {
        break
      }
    }
  }

  let mut first_block = true
  for b in split_blocks_smart(merged) {
    if !first_block {
      @cor.push(doc, @cor.Block::BlankLine)
    } else {
      first_block = false
    }

    match b {
      PdfBlock::Heading(level, text) =>
        @cor.push(doc, @cor.Block::Heading(level, text))
      PdfBlock::Paragraph(text) => @cor.push(doc, @cor.Block::Paragraph(text))
    }
  }

  doc
}

///|
/// Internal marker inserted between cleaned pages.
/// split_blocks_smart() should recognize this marker later.
const PDF_PAGE_BREAK_MARKER = "__PDF_PAGE_BREAK__"

fn merge_clean_pages_with_breaks(pages : Array[String]) -> String {
  if pages.length() == 0 {
    return ""
  }

  let out : Array[String] = []
  let n = pages.length()

  for i in 0..<n {
    let page = pages[i].trim().to_string()
    if page != "" {
      out.push(page)
    }

    if i + 1 < n {
      out.push(PDF_PAGE_BREAK_MARKER)
    }
  }

  out.join("\n")
}

///|
/// 检测跨页重复页眉/页脚
fn detect_repeated_page_noise(
  pages : Array[String],
) -> (Array[String], Array[String]) {
  let head_count = Map::new()
  let tail_count = Map::new()

  for page in pages {
    let lines = normalized_nonempty_lines(page)
    let n = lines.length()
    if n == 0 {
      continue
    }

    let head_take = if n >= 2 { 2 } else { 1 }
    let tail_take = if n >= 2 { 2 } else { 1 }

    for i in 0..<head_take {
      let key = normalize_noise_key(lines[i])
      if key != "" {
        let old = head_count.get(key) |> Option::unwrap_or(0)
        head_count.set(key, old + 1)
      }
    }

    for i in 0..<tail_take {
      let idx = n - tail_take + i
      let key = normalize_noise_key(lines[idx])
      if key != "" {
        let old = tail_count.get(key) |> Option::unwrap_or(0)
        tail_count.set(key, old + 1)
      }
    }
  }

  let page_n = pages.length()
  let threshold = if page_n <= 2 { 2 } else { (page_n + 1) / 2 }

  let heads : Array[String] = []
  let tails : Array[String] = []

  for entry in head_count {
    let (k, v) = entry
    if v >= threshold && k.to_array().length() <= 80 {
      heads.push(k)
    }
  }

  for entry in tail_count {
    let (k, v) = entry
    if v >= threshold && k.to_array().length() <= 80 {
      tails.push(k)
    }
  }

  (heads, tails)
}

///|
fn strip_page_noise(
  page : String,
  head_keys : Array[String],
  tail_keys : Array[String],
) -> String {
  let s = page
    .replace(old="\r\n", new="\n")
    .replace(old="\r", new="\n")
    .replace(old="\u00A0", new=" ")
    .replace(old="\t", new=" ")

  let raw_lines : Array[String] = []
  for sv in s.split("\n") {
    raw_lines.push(sv.to_string())
  }

  let n = raw_lines.length()
  if n == 0 {
    return ""
  }

  // 找到前两个非空行的位置
  let head_pos : Array[Int] = []
  let mut i = 0
  while i < n && head_pos.length() < 2 {
    let t = raw_lines[i].trim().to_string()
    if t != "" {
      head_pos.push(i)
    }
    i += 1
  }

  // 找到后两个非空行的位置
  let tail_pos : Array[Int] = []
  let mut j = n - 1
  while j >= 0 && tail_pos.length() < 2 {
    let t = raw_lines[j].trim().to_string()
    if t != "" {
      tail_pos.push(j)
    }
    if j == 0 {
      break
    }
    j -= 1
  }

  // 删页眉
  for idx in head_pos {
    let t = raw_lines[idx].trim().to_string()
    let key = normalize_noise_key(t)
    if key != "" && contains_string(head_keys, key) {
      raw_lines[idx] = ""
    }
  }

  // 删页脚
  for idx in tail_pos {
    let t = raw_lines[idx].trim().to_string()
    let key = normalize_noise_key(t)
    if key != "" && contains_string(tail_keys, key) {
      raw_lines[idx] = ""
    }
  }

  // 只清理噪声行，但保留原始空行结构
  let out : Array[String] = []
  let mut prev_blank = false

  for line in raw_lines {
    let t = line.trim().to_string()
    if t == "" {
      if !prev_blank {
        out.push("")
        prev_blank = true
      }
    } else if is_noise_line(t) {
      if !prev_blank {
        out.push("")
        prev_blank = true
      }
    } else {
      out.push(t)
      prev_blank = false
    }
  }

  out.join("\n")
}

///|
fn normalized_nonempty_lines(page : String) -> Array[String] {
  let s = page
    .replace(old="\r\n", new="\n")
    .replace(old="\r", new="\n")
    .replace(old="\u00A0", new=" ")
    .replace(old="\t", new=" ")

  let out : Array[String] = []
  for sv in s.split("\n") {
    let line = sv.to_string().trim().to_string()
    if line != "" {
      out.push(line)
    }
  }
  out
}

///|
/// 页眉页脚 key 归一化：
/// - trim
/// - 压缩空白
/// - 数字替换成 '#'
/// - 英文转小写
fn normalize_noise_key(s : String) -> String {
  let t = s.trim()
  if t == "" {
    return ""
  }

  let mut out = ""
  let mut prev_space = false
  for c in t.to_array() {
    let ch = if c >= 'A' && c <= 'Z' {
      Int::unsafe_to_char(c.to_int() + 32)
    } else if c >= '0' && c <= '9' {
      '#'
    } else if c == ' ' || c == '\t' {
      ' '
    } else {
      c
    }

    if ch == ' ' {
      if !prev_space {
        out = out + " "
        prev_space = true
      }
    } else {
      out = out + ch.to_string()
      prev_space = false
    }
  }

  out.trim().to_string()
}

///|
fn contains_string(xs : Array[String], x : String) -> Bool {
  for s in xs {
    if s == x {
      return true
    }
  }
  false
}
