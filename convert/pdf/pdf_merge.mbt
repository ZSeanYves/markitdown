///|
/// 第一阶段最小 cross-page merge：
/// - 只处理“上一页最后段 + 下一页第一段”的高置信续段
pub fn merge_convert_blocks(doc : PdfConvertDocument) -> PdfConvertDocument {
  if doc.pages.is_empty() {
    return doc
  }

  let pages = Array::new()

  // 先复制第一页
  pages.push(doc.pages[0])

  for i = 1; i < doc.pages.length(); i = i + 1 {
    let prev_page = pages[pages.length() - 1]
    let cur_page = doc.pages[i]

    let merged_prev = prev_page.blocks
    let merged_cur = Array::new()

    if should_merge_page_boundary(prev_page, cur_page) {
      let prev_last = merged_prev[merged_prev.length() - 1]
      let cur_first = cur_page.blocks[0]

      let merged_text = prev_last.text.trim().to_string() +
        " " +
        cur_first.text.trim().to_string()

      let merged_font_size = match prev_last.dominant_font_size {
        Some(v) => Some(v)
        None => cur_first.dominant_font_size
      }

      let merged_font_name = match prev_last.dominant_font_name {
        Some(v) => Some(v)
        None => cur_first.dominant_font_name
      }

      // 更新上一页最后一个 block
      merged_prev[merged_prev.length() - 1] = {
        page_index: prev_last.page_index,
        block_index: prev_last.block_index,
        kind: prev_last.kind,
        text: merged_text,
        line_start: prev_last.line_start,
        line_end: cur_first.line_end,
        is_heading_candidate: false,
        is_noise_candidate: false,

        // 跨页 block 第一阶段保留上一页末块的几何锚点
        bbox: prev_last.bbox,
        dominant_font_size: merged_font_size,
        dominant_font_name: merged_font_name,
        top_y: prev_last.top_y,
        left_x: prev_last.left_x,
        line_count: prev_last.line_count + cur_first.line_count,
      }

      // 当前页跳过第一个 block，其余保留
      for j = 1; j < cur_page.blocks.length(); j = j + 1 {
        merged_cur.push(cur_page.blocks[j])
      }
    } else {
      for block in cur_page.blocks {
        merged_cur.push(block)
      }
    }

    // 回写上一页
    pages[pages.length() - 1] = {
      page_index: prev_page.page_index,
      lines: prev_page.lines,
      blocks: merged_prev,
    }

    // 写入当前页
    pages.push({
      page_index: cur_page.page_index,
      lines: cur_page.lines,
      blocks: merged_cur,
    })
  }

  { pages, }
}

///|
fn should_merge_page_boundary(
  prev_page : PdfConvertPage,
  cur_page : PdfConvertPage,
) -> Bool {
  if prev_page.blocks.is_empty() || cur_page.blocks.is_empty() {
    return false
  }

  let left = prev_page.blocks[prev_page.blocks.length() - 1]
  let right = cur_page.blocks[0]

  if left.kind != PdfConvertBlockKind::Paragraph ||
    right.kind != PdfConvertBlockKind::Paragraph {
    return false
  }

  let lt = left.text.trim().to_string()
  let rt = right.text.trim().to_string()

  if lt == "" || rt == "" {
    return false
  }

  if ends_with_strong_sentence_punct(lt) {
    return false
  }

  if looks_like_new_section_after_page_break(rt) {
    return false
  }

  if looks_like_numbered_list_start(rt) {
    return false
  }

  if is_page_label_like(rt) {
    return false
  }

  looks_like_page_start_continuation(rt)
}

///|
fn looks_like_heading_start(text : String) -> Bool {
  let t = text.trim().to_string()

  if t == "" {
    return false
  }

  if t.has_prefix("第") && (t.contains("章") || t.contains("节")) {
    return true
  }

  if t.has_prefix("Chapter") ||
    t.has_prefix("Section") ||
    t.has_prefix("Introduction") ||
    t.has_prefix("Method") ||
    t.has_prefix("Conclusion") ||
    t.has_prefix("Next Section") {
    return true
  }

  false
}

///|
fn looks_like_numbered_list_start(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  let arr = t.to_array()
  if arr.is_empty() {
    return false
  }

  let first = arr[0]
  if !is_digit_char(first) {
    return false
  }

  t.contains(". ") || t.contains(") ")
}

///|
fn looks_like_page_start_continuation(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  if looks_like_heading_start(t) {
    return false
  }

  if looks_like_numbered_list_start(t) {
    return false
  }

  if is_page_label_like(t) {
    return false
  }

  let c = first_non_space_char(t)
  match c {
    Some(ch) => {
      if ch >= 'a' && ch <= 'z' {
        return true
      }
      if ch == '，' || ch == ',' || ch == '、' || ch == ')' {
        return true
      }
      true
    }
    _ => false
  }
}

///|
fn looks_like_new_section_after_page_break(text : String) -> Bool {
  let t = text.trim().to_string()
  if t == "" {
    return false
  }

  if looks_like_heading_start(t) {
    return true
  }

  if starts_with_numbered_section_heading(t) {
    return true
  }

  false
}

///|
fn starts_with_numbered_section_heading(text : String) -> Bool {
  let t = text.trim().to_string()
  let arr = t.to_array()
  if arr.length() < 3 {
    return false
  }

  (arr[0] >= '0' && arr[0] <= '9') &&
  (arr[1] == '.' || arr[1] == ')') &&
  arr[2] == ' '
}

///|
fn first_non_space_char(text : String) -> Char? {
  for ch in text {
    if ch != ' ' && ch != '\t' {
      return Some(ch)
    }
  }
  None
}
