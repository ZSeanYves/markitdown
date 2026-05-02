///|
/// 第一阶段 noise 过滤：
/// 1. 先删已经标成 Noise 的 block
/// 2. 再删跨页重复出现的页首/页尾短块
///
/// Why at this stage (before merge/to_ir):
/// - repeated header/footer noise can distort paragraph/heading boundaries
/// - removing them early improves downstream block merge stability
/// - policy is conservative to reduce accidental deletion in multi-column/short pages
fn filter_noise_blocks(doc : PdfConvertDocument) -> PdfConvertDocument {
  if doc.pages.is_empty() {
    return doc
  }

  let repeated = build_repeated_edge_noise_index(doc)
  let pages = Array::new()

  for page in doc.pages {
    let kept = Array::new()
    let n = page.blocks.length()

    for i = 0; i < n; i = i + 1 {
      let block = page.blocks[i]
      let text = block.text.trim().to_owned()
      let decision = decide_noise_block(page, i, block, repeated)

      match decision.status {
        PdfNoiseDecisionStatus::Drop => ()
        PdfNoiseDecisionStatus::Keep => if text != "" { kept.push(block) }
      }
    }

    let rebuilt = rebuild_page_objects({
      _page_index: page._page_index,
      media_box: page.media_box,
      crop_box: page.crop_box,
      lines: page.lines,
      blocks: kept,
      images: page.images,
      annotations: page.annotations,
      objects: [],
    })

    pages.push(rebuilt)
  }

  { pages, }
}

///|
/// 取当前页中 trim 后非空的 block。
fn normalized_nonempty_blocks(page : PdfConvertPage) -> Array[PdfConvertBlock] {
  let out = Array::new()

  for block in page.blocks {
    let t = block.text.trim().to_owned()
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
  let t = block.text.trim().to_owned()
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
fn is_top_edge_block(page : PdfConvertPage, block : PdfConvertBlock) -> Bool {
  match effective_page_box(page) {
    None => true
    Some(box) => {
      let h = page_box_height(box)
      if h <= 0.0 {
        return true
      }

      block._bbox.y1 >= box.y1 - edge_zone_height(h)
    }
  }
}

///|
fn is_bottom_edge_block(page : PdfConvertPage, block : PdfConvertBlock) -> Bool {
  match effective_page_box(page) {
    None => true
    Some(box) => {
      let h = page_box_height(box)
      if h <= 0.0 {
        return true
      }

      block._bbox.y0 <= box.y0 + edge_zone_height(h) ||
      is_sparse_page_tail_fallback(page)
    }
  }
}

///|
fn is_sparse_page_tail_fallback(page : PdfConvertPage) -> Bool {
  normalized_nonempty_blocks(page).length() <= 3
}

///|
fn effective_page_box(page : PdfConvertPage) -> @model.PdfRect? {
  match page.crop_box {
    Some(box) => Some(box)
    None => page.media_box
  }
}

///|
fn page_box_height(box : @model.PdfRect) -> Double {
  box.y1 - box.y0
}

///|
fn edge_zone_height(page_height : Double) -> Double {
  let zone = page_height * 0.12
  if zone < 48.0 {
    return 48.0
  }
  if zone > 120.0 {
    return 120.0
  }
  zone
}

///|
/// repeated noise key 归一化：
/// - trim
/// - 压缩空白
/// - 英文转小写
/// - 数字统一替换成 '#'
fn normalize_noise_key(s : String) -> String {
  let t = s.trim().to_owned()
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

  out.trim().to_owned()
}

///|
fn count_words(s : String) -> Int {
  let mut n = 0
  for sv in s.split(" ") {
    let t = sv.trim().to_owned()
    if t != "" {
      n = n + 1
    }
  }
  n
}

///|
/// 非严格正文句判定：用于保护正文不被 repeated noise 误删。
fn ends_like_sentence(text : String) -> Bool {
  let t = text.trim().to_owned()
  t.has_suffix(".") ||
  t.has_suffix("!") ||
  t.has_suffix("?") ||
  t.has_suffix("。") ||
  t.has_suffix("！") ||
  t.has_suffix("？")
}

///|
fn is_probable_page_number_like(text : String) -> Bool {
  let t = text.trim().to_owned()
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
  let t = text.trim().to_owned()

  if !(t.has_prefix("Page ") || t.has_prefix("page ")) {
    return false
  }

  let tail = t[5:].trim().to_owned()
  tail != "" && tail.length() <= 4 && all_ascii_digits(tail)
}

///|
fn looks_like_simple_cjk_page_label(text : String) -> Bool {
  let t = text.trim().to_owned()

  if !(t.has_prefix("第") && (t.contains("页") || t.contains("⻚"))) {
    return false
  }

  let mid = t
    .replace_all(old="第", new="")
    .replace_all(old="页", new="")
    .replace_all(old="⻚", new="")
    .trim()
    .to_owned()

  mid != "" && mid.length() <= 4 && all_ascii_digits(mid)
}

///|
fn looks_like_fraction_page_label(text : String) -> Bool {
  let t = text.trim().to_owned()

  let parts : Array[String] = Array::new()
  for part in t.split("/") {
    parts.push(part.to_owned())
  }

  if parts.length() != 2 {
    return false
  }

  let left = parts[0].trim().to_owned()
  let right = parts[1].trim().to_owned()

  left != "" &&
  right != "" &&
  left.length() <= 4 &&
  right.length() <= 4 &&
  all_ascii_digits(left) &&
  all_ascii_digits(right)
}

///|
fn looks_like_dash_page_label(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t.length() > 12 {
    return false
  }

  let normalized = t.replace_all(old=" ", new="")
  if !normalized.contains("-") {
    return false
  }

  let parts : Array[String] = Array::new()
  for part in normalized.split("-") {
    parts.push(part.to_owned())
  }

  let mut non_empty = 0
  for p in parts {
    let s = p.trim().to_owned()
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
    let t = page.blocks[i].text.trim().to_owned()
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
    let t = page.blocks[i].text.trim().to_owned()
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
