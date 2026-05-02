///|
/// 第一阶段最小 cross-page merge：
/// - 只处理“上一页最后段 + 下一页第一段”的高置信续段
fn merge_convert_blocks(doc : PdfConvertDocument) -> PdfConvertDocument {
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
    let decision = decide_page_boundary_merge(prev_page, cur_page)

    if is_merge_decision(decision) {
      let prev_last = merged_prev[merged_prev.length() - 1]
      let cur_first = cur_page.blocks[0]

      let merged_text = prev_last.text.trim().to_owned() +
        " " +
        cur_first.text.trim().to_owned()

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
        _page_index: prev_last._page_index,
        block_index: prev_last.block_index,
        kind: prev_last.kind,
        text: merged_text,
        rich_inlines: None,
        line_start: prev_last.line_start,
        line_end: cur_first.line_end,
        source_block_index: prev_last.source_block_index,
        source_block_line_count: prev_last.source_block_line_count,
        source_block_kind: prev_last.source_block_kind,
        source_block_bbox: prev_last.source_block_bbox,
        source_block_dominant_font_size: prev_last.source_block_dominant_font_size,
        source_block_dominant_font_name: prev_last.source_block_dominant_font_name,
        is_heading_candidate: false,
        is_noise_candidate: false,
        is_header_footer_candidate: prev_last.is_header_footer_candidate &&
        cur_first.is_header_footer_candidate,
        is_artifact_candidate: prev_last.is_artifact_candidate ||
        cur_first.is_artifact_candidate,
        is_caption_candidate: prev_last.is_caption_candidate ||
        cur_first.is_caption_candidate,
        is_table_cell_candidate: prev_last.is_table_cell_candidate ||
        cur_first.is_table_cell_candidate,
        dominant_language: prev_last.dominant_language,
        writing_direction: prev_last.writing_direction,

        // 跨页 block 第一阶段保留上一页末块的几何锚点
        _bbox: prev_last._bbox,
        dominant_font_size: merged_font_size,
        dominant_font_name: merged_font_name,
        top_y: prev_last.top_y,
        left_x: prev_last.left_x,
        line_count: prev_last.line_count + cur_first.line_count,
        first_indent_left: prev_last.first_indent_left,
        last_indent_left: cur_first.last_indent_left,
        first_indent_right: prev_last.first_indent_right,
        last_indent_right: cur_first.last_indent_right,
        first_alignment_hint: prev_last.first_alignment_hint,
        last_alignment_hint: cur_first.last_alignment_hint,
        first_line_gap_before: prev_last.first_line_gap_before,
        last_line_gap_after: cur_first.last_line_gap_after,
        first_line_height: prev_last.first_line_height,
        last_line_height: cur_first.last_line_height,
        first_baseline_y: prev_last.first_baseline_y,
        last_baseline_y: cur_first.last_baseline_y,
        first_is_wrapped_candidate: prev_last.first_is_wrapped_candidate,
        last_is_wrapped_candidate: cur_first.last_is_wrapped_candidate,
        first_is_same_paragraph_with_prev_candidate: prev_last.first_is_same_paragraph_with_prev_candidate,
        last_is_same_paragraph_with_prev_candidate: cur_first.last_is_same_paragraph_with_prev_candidate,
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
    pages[pages.length() - 1] = rebuild_page_objects({
      _page_index: prev_page._page_index,
      media_box: prev_page.media_box,
      crop_box: prev_page.crop_box,
      lines: prev_page.lines,
      blocks: merged_prev,
      images: prev_page.images,
      annotations: prev_page.annotations,
      objects: [],
    })

    // 写入当前页
    pages.push(
      rebuild_page_objects({
        _page_index: cur_page._page_index,
        media_box: cur_page.media_box,
        crop_box: cur_page.crop_box,
        lines: cur_page.lines,
        blocks: merged_cur,
        images: cur_page.images,
        annotations: cur_page.annotations,
        objects: [],
      }),
    )
  }

  { pages, }
}

///|
fn is_merge_decision(decision : PdfMergeDecision) -> Bool {
  match decision.status {
    PdfMergeDecisionStatus::Merge => true
    PdfMergeDecisionStatus::KeepSplit => false
  }
}

///|
fn looks_like_heading_start(text : String) -> Bool {
  let t = text.trim().to_owned()

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
  let t = text.trim().to_owned()
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
fn looks_like_list_start(text : String) -> Bool {
  let t = text.trim().to_owned()
  t.has_prefix("•") ||
  t.has_prefix("- ") ||
  t.has_prefix("* ") ||
  looks_like_numbered_list_start(t)
}

///|
fn looks_like_page_start_continuation(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  if looks_like_heading_start(t) {
    return false
  }

  if looks_like_list_start(t) {
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
      if ch == '，' ||
        ch == ',' ||
        ch == '、' ||
        ch == ')' ||
        ch == '）' ||
        ch == ';' ||
        ch == '；' {
        return true
      }
      starts_with_continuation_phrase(t)
    }
    _ => false
  }
}

///|
fn starts_with_continuation_phrase(text : String) -> Bool {
  let t = text.trim().to_owned()
  t.has_prefix("and ") ||
  t.has_prefix("or ") ||
  t.has_prefix("but ") ||
  t.has_prefix("because ") ||
  t.has_prefix("which ") ||
  t.has_prefix("that ") ||
  t.has_prefix("then ") ||
  t.has_prefix("therefore ") ||
  t.has_prefix("so ") ||
  t.has_prefix("to ") ||
  t.has_prefix("without ") ||
  t.has_prefix("with ")
}

///|
fn looks_like_new_section_after_page_break(text : String) -> Bool {
  let t = text.trim().to_owned()
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
  let t = text.trim().to_owned()
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

///|
fn font_size_close(left : Double?, right : Double?) -> Bool {
  match (left, right) {
    (Some(a), Some(b)) => abs_f64(a - b) <= 0.75
    _ => true
  }
}

///|
fn indent_close(left : Double?, right : Double?) -> Bool {
  match (left, right) {
    (Some(a), Some(b)) => abs_f64(a - b) <= 12.0
    _ => true
  }
}

///|
fn alignment_compatible(left : String?, right : String?) -> Bool {
  match (left, right) {
    (Some(a), Some(b)) => a == b
    _ => true
  }
}

///|
fn gap_looks_like_new_paragraph(
  gap_before : Double?,
  line_height : Double?,
) -> Bool {
  match (gap_before, line_height) {
    (Some(g), Some(h)) => h > 0.0 && g > h * 1.5
    _ => false
  }
}
