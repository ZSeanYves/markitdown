///|
/// 第一阶段 noise 过滤：
/// 1. 先删已经标成 Noise 的 block
/// 2. 再删跨页重复出现的页首/页尾短块

///|
/// 第一阶段 noise 过滤：
/// 1. 先删已经标成 Noise 的 block
/// 2. 再删跨页重复出现的页首/页尾短块
fn filter_noise_blocks(doc : PdfConvertDocument) -> PdfConvertDocument {
  if doc.pages.is_empty() {
    return doc
  }

  let (repeated_heads, repeated_tails) = detect_repeated_edge_noise(doc)
  let pages = Array::new()

  for page in doc.pages {
    let kept = Array::new()
    let n = page.blocks.length()

    for i = 0; i < n; i = i + 1 {
      let block = page.blocks[i]
      let text = block.text.trim().to_string()

      match block.kind {
        PdfConvertBlockKind::Noise => ()
        _ =>
          if should_drop_repeated_edge_block(
              page, i, block, repeated_heads, repeated_tails,
            ) {
            ()
          } else if text == "" {
            ()
          } else {
            kept.push(block)
          }
      }
    }

    let rebuilt = rebuild_page_objects({
      _page_index: page._page_index,
      lines: page.lines,
      blocks: kept,
      images: page.images,
      objects: [],
    })

    pages.push(rebuilt)
  }

  { pages, }
}

///|
/// 检测跨页重复页眉/页脚块。
///
/// 当前策略非常保守：
/// - 只看每页前 1~2 个块、后 1~2 个块
/// - 只统计短块
/// - 文本归一化后跨页出现达到阈值才判 repeated noise
fn detect_repeated_edge_noise(
  doc : PdfConvertDocument,
) -> (Array[String], Array[String]) {
  let head_count = Map::new()
  let tail_count = Map::new()

  for page in doc.pages {
    let blocks = normalized_nonempty_blocks(page)
    let n = blocks.length()
    if n == 0 {
      continue
    }

    let head = blocks[0]
    let head_key = normalize_noise_key(head.text)
    if head_key != "" && is_repeated_noise_candidate_block(head) {
      let old = head_count.get(head_key) |> Option::unwrap_or(0)
      head_count.set(head_key, old + 1)
    }

    let tail = blocks[n - 1]
    let tail_key = normalize_noise_key(tail.text)
    if tail_key != "" && is_repeated_noise_candidate_block(tail) {
      let old = tail_count.get(tail_key) |> Option::unwrap_or(0)
      tail_count.set(tail_key, old + 1)
    }
  }

  let page_n = doc.pages.length()
  let threshold = if page_n <= 2 { 2 } else { (page_n + 1) / 2 }

  let heads = Array::new()
  let tails = Array::new()

  for entry in head_count {
    let (k, v) = entry
    if v >= threshold && k.length() <= 80 {
      heads.push(k)
    }
  }

  for entry in tail_count {
    let (k, v) = entry
    if v >= threshold && k.length() <= 80 {
      tails.push(k)
    }
  }

  (heads, tails)
}

///|
/// 取当前页中 trim 后非空的 block。
fn normalized_nonempty_blocks(page : PdfConvertPage) -> Array[PdfConvertBlock] {
  let out = Array::new()

  for block in page.blocks {
    let t = block.text.trim().to_string()
    if t != "" {
      out.push(block)
    }
  }

  out
}

///|
/// 当前 block 是否像可被 repeated-cleanup 删除的页边噪声。
///
/// 保守原则：
/// - 纯页码/页标签可以删
/// - 较短、非完整正文句、非长正文段才进入 repeated 候选
fn is_repeated_noise_candidate_block(block : PdfConvertBlock) -> Bool {
  let t = block.text.trim().to_string()
  if t == "" {
    return false
  }

  if is_probable_page_number_like(t) {
    return true
  }

  let n = t.length()
  let words = count_words(t)

  if n > 60 {
    return false
  }

  if words >= 8 {
    return false
  }

  if block.line_count >= 2 {
    return false
  }

  if ends_like_sentence(t) && words >= 5 {
    return false
  }

  true
}

///|
/// 是否删除当前 block：
/// - 必须位于页首前两块或页尾后两块
/// - 并且 key 命中 repeated head/tail
fn should_drop_repeated_edge_block(
  page : PdfConvertPage,
  block_index : Int,
  block : PdfConvertBlock,
  repeated_heads : Array[String],
  repeated_tails : Array[String],
) -> Bool {
  let key = normalize_noise_key(block.text)
  if key == "" {
    return false
  }

  let first_idx = first_nonempty_block_index(page)
  let last_idx = last_nonempty_block_index(page)

  if block_index == first_idx && contains_string(repeated_heads, key) {
    return true
  }

  if block_index == last_idx && contains_string(repeated_tails, key) {
    return true
  }

  false
}

///|
/// repeated noise key 归一化：
/// - trim
/// - 压缩空白
/// - 英文转小写
/// - 数字统一替换成 '#'
fn normalize_noise_key(s : String) -> String {
  let t = s.trim().to_string()
  if t == "" {
    return ""
  }

  let mut out = ""
  let mut prev_space = false

  for c in t {
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
fn count_words(s : String) -> Int {
  let mut n = 0
  for sv in s.split(" ") {
    let t = sv.to_string().trim().to_string()
    if t != "" {
      n = n + 1
    }
  }
  n
}

///|
/// 非严格正文句判定：用于保护正文不被 repeated noise 误删。
fn ends_like_sentence(text : String) -> Bool {
  let t = text.trim().to_string()
  t.has_suffix(".") ||
  t.has_suffix("!") ||
  t.has_suffix("?") ||
  t.has_suffix("。") ||
  t.has_suffix("！") ||
  t.has_suffix("？")
}

///|
fn is_probable_page_number_like(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  if t.length() <= 4 && all_ascii_digits(t) {
    return true
  }

  if looks_like_simple_english_page_label(t) {
    return true
  }

  if looks_like_simple_cjk_page_label(t) {
    return true
  }

  if looks_like_fraction_page_label(t) {
    return true
  }

  if looks_like_dash_page_label(t) {
    return true
  }

  false
}

///|
fn looks_like_simple_english_page_label(text : String) -> Bool {
  let t = text.trim().to_string()

  if !(t.has_prefix("Page ") || t.has_prefix("page ")) {
    return false
  }

  let tail = t[5:].trim().to_string()
  tail != "" && tail.length() <= 4 && all_ascii_digits(tail)
}

///|
fn looks_like_simple_cjk_page_label(text : String) -> Bool {
  let t = text.trim().to_string()

  if !(t.has_prefix("第") && (t.contains("页") || t.contains("⻚"))) {
    return false
  }

  let mid = t
    .replace_all(old="第", new="")
    .replace_all(old="页", new="")
    .replace_all(old="⻚", new="")
    .trim()
    .to_string()

  mid != "" && mid.length() <= 4 && all_ascii_digits(mid)
}

///|
fn looks_like_fraction_page_label(text : String) -> Bool {
  let t = text.trim().to_string()

  let parts : Array[String] = Array::new()
  for part in t.split("/") {
    parts.push(part.to_string())
  }

  if parts.length() != 2 {
    return false
  }

  let left = parts[0].trim().to_string()
  let right = parts[1].trim().to_string()

  left != "" &&
  right != "" &&
  left.length() <= 4 &&
  right.length() <= 4 &&
  all_ascii_digits(left) &&
  all_ascii_digits(right)
}

///|
fn looks_like_dash_page_label(text : String) -> Bool {
  let t = text.trim().to_string()
  if t.length() > 12 {
    return false
  }

  let normalized = t.replace_all(old=" ", new="")
  if !normalized.contains("-") {
    return false
  }

  let parts : Array[String] = Array::new()
  for part in normalized.split("-") {
    parts.push(part.to_string())
  }

  let mut non_empty = 0
  for p in parts {
    let s = p.trim().to_string()
    if s != "" {
      if !all_ascii_digits(s) {
        return false
      }
      non_empty += 1
    }
  }

  non_empty >= 1 && non_empty <= 2
}

///|
fn all_ascii_digits(text : String) -> Bool {
  if text == "" {
    return false
  }

  for ch in text {
    if ch < '0' || ch > '9' {
      return false
    }
  }

  true
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

///|
fn first_nonempty_block_index(page : PdfConvertPage) -> Int {
  for i = 0; i < page.blocks.length(); i = i + 1 {
    let t = page.blocks[i].text.trim().to_string()
    if t != "" {
      return i
    }
  }
  -1
}

///|
fn last_nonempty_block_index(page : PdfConvertPage) -> Int {
  let mut i = page.blocks.length() - 1
  while i >= 0 {
    let t = page.blocks[i].text.trim().to_string()
    if t != "" {
      return i
    }
    if i == 0 {
      break
    }
    i = i - 1
  }
  -1
}
