///|
/// 第一阶段最小 cross-page merge：
/// - 先做页内最小 text-flow 修复
/// - 再处理“上一页最后段 + 下一页第一段”的高置信续段
///
/// 优先级说明：
/// 1. noise/page-number 先在 `filter_noise_blocks` 阶段清理，避免被误并回正文
/// 2. 这里先做 superscript marker 附着，只吃靠近前一段末尾的小号短数字
/// 3. enumerated heading 仍交给 heading / to_ir 规则单独处理，不在 soft-merge 中吞掉
/// 4. 最后才做 paragraph soft-merge，且只在同列、同版面、明显续写时成立
pub fn merge_convert_blocks(doc : PdfConvertDocument) -> PdfConvertDocument {
  if doc.pages.is_empty() {
    return doc
  }

  let page_local_repaired = Array::new()
  for page in doc.pages {
    page_local_repaired.push(repair_page_local_text_flow(page))
  }

  let pages = Array::new()

  // 先复制第一页
  pages.push(page_local_repaired[0])

  for i = 1; i < page_local_repaired.length(); i = i + 1 {
    let prev_page = pages[pages.length() - 1]
    let cur_page = page_local_repaired[i]

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
      forms: prev_page.forms,
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
        forms: cur_page.forms,
        objects: [],
      }),
    )
  }

  { pages, }
}

///|
fn repair_page_local_text_flow(page : PdfConvertPage) -> PdfConvertPage {
  if page.blocks.length() <= 1 {
    return page
  }

  let repaired : Array[PdfConvertBlock] = []

  for block in page.blocks {
    if repaired.is_empty() {
      repaired.push(block)
      continue
    }

    let prev = repaired[repaired.length() - 1]

    if should_attach_superscript_marker(prev, block) {
      repaired[repaired.length() - 1] = attach_superscript_marker_block(
        prev, block,
      )
      continue
    }

    if should_soft_merge_page_blocks(prev, block) {
      let merged_text = append_convert_line_text(
        prev.text.trim().to_owned(),
        block.text.trim().to_owned(),
      )
      repaired[repaired.length() - 1] = merge_adjacent_page_blocks(
        prev, block, merged_text,
      )
      continue
    }

    repaired.push(block)
  }

  rebuild_page_objects({ ..page, blocks: repaired, objects: [] })
}

///|
fn merge_adjacent_page_blocks(
  left : PdfConvertBlock,
  right : PdfConvertBlock,
  merged_text : String,
) -> PdfConvertBlock {
  let same_row_fragment = same_visual_row_block_fragment(left, right)
  let bbox = @model.union_rect(left._bbox, right._bbox)
  let dominant_font_size = match left.dominant_font_size {
    Some(v) => Some(v)
    None => right.dominant_font_size
  }
  let dominant_font_name = match left.dominant_font_name {
    Some(v) => Some(v)
    None => right.dominant_font_name
  }

  let rich_inlines = merge_adjacent_page_block_inlines(left, right)

  {
    _page_index: left._page_index,
    block_index: left.block_index,
    kind: left.kind,
    text: merged_text,
    rich_inlines,
    line_start: left.line_start,
    line_end: right.line_end,
    source_block_index: left.source_block_index,
    source_block_line_count: left.source_block_line_count +
    right.source_block_line_count,
    source_block_kind: left.source_block_kind,
    source_block_bbox: @model.union_rect(
      left.source_block_bbox,
      right.source_block_bbox,
    ),
    source_block_dominant_font_size: left.source_block_dominant_font_size,
    source_block_dominant_font_name: left.source_block_dominant_font_name,
    is_heading_candidate: false,
    is_noise_candidate: left.is_noise_candidate && right.is_noise_candidate,
    is_header_footer_candidate: left.is_header_footer_candidate &&
    right.is_header_footer_candidate,
    is_artifact_candidate: left.is_artifact_candidate ||
    right.is_artifact_candidate,
    is_caption_candidate: left.is_caption_candidate ||
    right.is_caption_candidate,
    is_table_cell_candidate: left.is_table_cell_candidate ||
    right.is_table_cell_candidate,
    dominant_language: left.dominant_language,
    writing_direction: left.writing_direction,
    _bbox: bbox,
    dominant_font_size,
    dominant_font_name,
    top_y: if left.top_y > right.top_y {
      left.top_y
    } else {
      right.top_y
    },
    left_x: if left.left_x < right.left_x {
      left.left_x
    } else {
      right.left_x
    },
    line_count: if same_row_fragment {
      left.line_count
    } else {
      left.line_count + right.line_count
    },
    first_indent_left: left.first_indent_left,
    last_indent_left: if same_row_fragment {
      left.last_indent_left
    } else {
      right.last_indent_left
    },
    first_indent_right: left.first_indent_right,
    last_indent_right: right.last_indent_right,
    first_alignment_hint: left.first_alignment_hint,
    last_alignment_hint: right.last_alignment_hint,
    first_line_gap_before: left.first_line_gap_before,
    last_line_gap_after: right.last_line_gap_after,
    first_line_height: left.first_line_height,
    last_line_height: if same_row_fragment {
      left.last_line_height
    } else {
      right.last_line_height
    },
    first_baseline_y: left.first_baseline_y,
    last_baseline_y: if same_row_fragment {
      left.last_baseline_y
    } else {
      right.last_baseline_y
    },
    first_is_wrapped_candidate: left.first_is_wrapped_candidate,
    last_is_wrapped_candidate: right.last_is_wrapped_candidate,
    first_is_same_paragraph_with_prev_candidate: left.first_is_same_paragraph_with_prev_candidate,
    last_is_same_paragraph_with_prev_candidate: right.last_is_same_paragraph_with_prev_candidate,
  }
}

///|
fn attach_superscript_marker_block(
  left : PdfConvertBlock,
  right : PdfConvertBlock,
) -> PdfConvertBlock {
  let marker = right.text.trim().to_owned()
  let merged = merge_adjacent_page_blocks(
    left,
    right,
    left.text.trim().to_owned() + "^" + marker,
  )
  let rich_inlines = merge_superscript_note_ref_inlines(left, marker)
  {
    ..merged,
    rich_inlines: Some(rich_inlines),
    line_count: left.line_count,
    last_indent_left: left.last_indent_left,
    last_indent_right: merged.last_indent_right,
    last_line_gap_after: left.last_line_gap_after,
    last_line_height: left.last_line_height,
    last_baseline_y: left.last_baseline_y,
    last_is_wrapped_candidate: left.last_is_wrapped_candidate,
    last_is_same_paragraph_with_prev_candidate: left.last_is_same_paragraph_with_prev_candidate,
  }
}

///|
fn merge_adjacent_page_block_inlines(
  left : PdfConvertBlock,
  right : PdfConvertBlock,
) -> Array[@cor.Inline]? {
  let left_inlines = block_text_flow_inlines(left)
  let right_inlines = block_text_flow_inlines(right)

  match (left_inlines, right_inlines) {
    (None, None) => None
    (Some(xs), None) => Some(xs)
    (None, Some(ys)) => Some(ys)
    (Some(xs), Some(ys)) => {
      let merged = xs.copy()
      ensure_space_before_appending_inlines(merged, ys)
      for inline in ys {
        merged.push(inline)
      }
      Some(merged)
    }
  }
}

///|
fn ensure_space_before_appending_inlines(
  dst : Array[@cor.Inline],
  src : Array[@cor.Inline],
) -> Unit {
  if dst.is_empty() || src.is_empty() {
    return
  }

  let needs_space = match dst[dst.length() - 1] {
    @cor.Inline::Text(text) => {
      let trimmed = text.trim().to_owned()
      trimmed != "" &&
      !trimmed.has_suffix(" ") &&
      !trimmed.has_suffix("(") &&
      !trimmed.has_suffix("[") &&
      !trimmed.has_suffix("{") &&
      !trimmed.has_suffix("-")
    }
    @cor.Inline::Link(text, _href) => {
      let trimmed = text.trim().to_owned()
      trimmed != "" && !trimmed.has_suffix(" ")
    }
    @cor.Inline::NoteRef(note) => note.marker.trim() != ""
    @cor.Inline::Break => false
  }

  if !needs_space {
    return
  }

  match src[0] {
    @cor.Inline::Text(text) =>
      if text == "" {
        src[0] = @cor.Inline::Text(" ")
      } else if !text.has_prefix(" ") &&
        !text.has_prefix(")") &&
        !text.has_prefix("]") &&
        !text.has_prefix(",") &&
        !text.has_prefix(".") &&
        !text.has_prefix(";") &&
        !text.has_prefix(":") &&
        !text.has_prefix("!") &&
        !text.has_prefix("?") {
        src[0] = @cor.Inline::Text(" " + text)
      }
    @cor.Inline::Break => ()
    _ => src.insert(0, @cor.Inline::Text(" "))
  }
}

///|
fn block_text_flow_inlines(block : PdfConvertBlock) -> Array[@cor.Inline]? {
  match block.rich_inlines {
    Some(inlines) => Some(inlines.copy())
    None =>
      if block.text.trim() == "" {
        None
      } else {
        Some([@cor.Inline::Text(block.text.trim().to_owned())])
      }
  }
}

///|
fn merge_superscript_note_ref_inlines(
  left : PdfConvertBlock,
  marker : String,
) -> Array[@cor.Inline] {
  let trimmed_marker = marker.trim().to_owned()
  let base = block_text_flow_inlines(left).unwrap_or([])
  if trimmed_marker == "" {
    return base
  }
  base.push(
    @cor.Inline::NoteRef({
      note_id: "",
      marker: trimmed_marker,
      kind: @cor.NoteKind::Footnote,
      source_kind: @cor.NoteSourceKind::PdfSuperscript,
      confidence: @cor.NoteConfidence::Medium,
      body_status: @cor.NoteBodyStatus::Missing,
    }),
  )
  base
}

///|
fn should_attach_superscript_marker(
  left : PdfConvertBlock,
  right : PdfConvertBlock,
) -> Bool {
  if !blocks_can_attach_superscript_marker(left, right) {
    return false
  }

  let marker = normalize_pdf_comparison_text(right.text)
  if !looks_like_superscript_marker_text(marker) {
    return false
  }

  if is_page_label_like(marker) || starts_like_enumerated_heading_block(marker) {
    return false
  }

  if !superscript_marker_font_smaller(left, right) {
    return false
  }

  if !superscript_marker_near_previous_end(left, right) {
    return false
  }

  superscript_marker_raised(left, right)
}

///|
fn should_soft_merge_page_blocks(
  left : PdfConvertBlock,
  right : PdfConvertBlock,
) -> Bool {
  if !blocks_can_repair_text_flow(left, right) {
    return false
  }

  let lt = normalize_pdf_comparison_text(left.text)
  let rt = normalize_pdf_comparison_text(right.text)
  if lt == "" || rt == "" {
    return false
  }

  if starts_like_enumerated_heading_block(rt) {
    return false
  }

  if starts_like_list_or_page_block(rt) {
    return false
  }

  if same_visual_row_soft_continuation(left, right, lt, rt) {
    return true
  }

  if !page_local_layout_compatible(left, right) {
    return false
  }

  if right_starts_soft_continuation(rt) {
    return true
  }

  if left_has_soft_continuation_tail(lt) {
    return true
  }

  left.last_is_wrapped_candidate ||
  right.first_is_wrapped_candidate ||
  right.first_is_same_paragraph_with_prev_candidate
}

///|
fn blocks_can_repair_text_flow(
  left : PdfConvertBlock,
  right : PdfConvertBlock,
) -> Bool {
  left.kind == PdfConvertBlockKind::Paragraph &&
  right.kind == PdfConvertBlockKind::Paragraph &&
  !left.is_header_footer_candidate &&
  !right.is_header_footer_candidate &&
  !left.is_artifact_candidate &&
  !right.is_artifact_candidate &&
  !left.is_caption_candidate &&
  !right.is_caption_candidate &&
  !left.is_table_cell_candidate &&
  !right.is_table_cell_candidate &&
  !left.is_noise_candidate &&
  !right.is_noise_candidate
}

///|
fn blocks_can_attach_superscript_marker(
  left : PdfConvertBlock,
  right : PdfConvertBlock,
) -> Bool {
  left.kind == PdfConvertBlockKind::Paragraph &&
  right.kind == PdfConvertBlockKind::Paragraph &&
  !left.is_header_footer_candidate &&
  !left.is_artifact_candidate &&
  !right.is_artifact_candidate &&
  !left.is_caption_candidate &&
  !right.is_caption_candidate &&
  !left.is_table_cell_candidate &&
  !right.is_table_cell_candidate &&
  !left.is_noise_candidate
}

///|
fn looks_like_superscript_marker_text(text : String) -> Bool {
  let t = text.trim().to_owned()
  if t == "" {
    return false
  }

  let chars = t.to_array()
  if chars.length() < 1 || chars.length() > 3 {
    return false
  }

  for ch in chars {
    if !is_digit_char(ch) {
      return false
    }
  }

  true
}

///|
fn superscript_marker_font_smaller(
  left : PdfConvertBlock,
  right : PdfConvertBlock,
) -> Bool {
  match (left.dominant_font_size, right.dominant_font_size) {
    (Some(a), Some(b)) => b + 0.5 <= a
    (Some(a), None) => a >= 11.0
    _ => false
  }
}

///|
fn superscript_marker_near_previous_end(
  left : PdfConvertBlock,
  right : PdfConvertBlock,
) -> Bool {
  let gap = right._bbox.x0 - left._bbox.x1
  let ref_h = page_local_reference_height(left, right)
  if gap >= -4.0 &&
    gap <= ref_h * 1.2 &&
    right._bbox.x0 >= left._bbox.x1 - ref_h * 0.5 {
    return true
  }

  same_visual_row_block_fragment(left, right) &&
  right.left_x >= left.left_x + ref_h * 8.0
}

///|
fn superscript_marker_raised(
  left : PdfConvertBlock,
  right : PdfConvertBlock,
) -> Bool {
  let ref_h = page_local_reference_height(left, right)
  match (left.last_baseline_y, right.first_baseline_y) {
    (Some(a), Some(b)) => b >= a + ref_h * 0.18 && b <= a + ref_h * 1.10
    _ => right._bbox.y0 >= left._bbox.y0 + ref_h * 0.12
  }
}

///|
fn page_local_layout_compatible(
  left : PdfConvertBlock,
  right : PdfConvertBlock,
) -> Bool {
  if !font_size_close(left.dominant_font_size, right.dominant_font_size) {
    return false
  }

  if !page_local_column_compatible(left, right) {
    return false
  }

  if !indent_close(left.last_indent_left, right.first_indent_left) {
    return false
  }

  if gap_looks_like_new_paragraph(
      right.first_line_gap_before,
      right.first_line_height,
    ) {
    return false
  }

  page_local_vertical_gap(left, right) <=
  page_local_reference_height(left, right) * 2.25
}

///|
fn same_visual_row_soft_continuation(
  left : PdfConvertBlock,
  right : PdfConvertBlock,
  left_text : String,
  right_text : String,
) -> Bool {
  if !same_visual_row_block_fragment(left, right) {
    return false
  }

  if !font_size_close(left.dominant_font_size, right.dominant_font_size) {
    return false
  }

  if right.left_x <=
    left.left_x + page_local_reference_height(left, right) * 4.0 {
    return false
  }

  let explicit_text_continuation = left_has_soft_continuation_tail(left_text) ||
    right_starts_soft_continuation(right_text)
  if explicit_text_continuation {
    return true
  }

  if !page_local_same_row_fragment_compatible(left, right) {
    return false
  }

  left.last_is_wrapped_candidate ||
  right.first_is_wrapped_candidate ||
  right.first_is_same_paragraph_with_prev_candidate
}

///|
fn same_visual_row_block_fragment(
  left : PdfConvertBlock,
  right : PdfConvertBlock,
) -> Bool {
  let left_base = match left.last_baseline_y {
    Some(v) => v
    None => (left._bbox.y0 + left._bbox.y1) / 2.0
  }
  let right_base = match right.first_baseline_y {
    Some(v) => v
    None => (right._bbox.y0 + right._bbox.y1) / 2.0
  }
  let ref_h = page_local_reference_height(left, right)
  abs_merge_f64(left_base - right_base) <= ref_h * 0.40
}

///|
fn page_local_column_compatible(
  left : PdfConvertBlock,
  right : PdfConvertBlock,
) -> Bool {
  abs_merge_f64(left.left_x - right.left_x) <= 18.0 &&
  !page_local_cross_column_shift(left, right)
}

///|
fn page_local_same_row_fragment_compatible(
  left : PdfConvertBlock,
  right : PdfConvertBlock,
) -> Bool {
  let ref_h = page_local_reference_height(left, right)
  let gap = right._bbox.x0 - left._bbox.x1
  gap >= 0.0 - ref_h * 0.5 && gap <= ref_h * 2.5
}

///|
fn page_local_cross_column_shift(
  left : PdfConvertBlock,
  right : PdfConvertBlock,
) -> Bool {
  let ref_h = page_local_reference_height(left, right)
  abs_merge_f64(left.left_x - right.left_x) > ref_h * 4.0
}

///|
fn page_local_vertical_gap(
  upper : PdfConvertBlock,
  lower : PdfConvertBlock,
) -> Double {
  let gap = upper._bbox.y0 - lower._bbox.y1
  if gap > 0.0 {
    gap
  } else {
    0.0
  }
}

///|
fn page_local_reference_height(
  left : PdfConvertBlock,
  right : PdfConvertBlock,
) -> Double {
  let mut ref_h = 12.0
  match left.last_line_height {
    Some(v) => if v > ref_h { ref_h = v }
    None => ()
  }
  match right.first_line_height {
    Some(v) => if v > ref_h { ref_h = v }
    None => ()
  }
  ref_h
}

///|
fn starts_like_list_or_page_block(text : String) -> Bool {
  let t = normalize_pdf_comparison_text(text)
  if t == "" {
    return false
  }

  if is_page_label_like(t) {
    return true
  }

  t.has_prefix("• ") ||
  t.has_prefix("- ") ||
  t.has_prefix("* ") ||
  t.has_prefix("•") ||
  t.has_prefix("-") ||
  t.has_prefix("*")
}

///|
fn starts_like_enumerated_heading_block(text : String) -> Bool {
  let t = normalize_pdf_comparison_text(text)
  let arr = t.to_array()
  if arr.length() < 3 {
    return false
  }

  let mut i = 0
  let mut has_digit = false
  while i < arr.length() {
    let ch = arr[i]
    if is_digit_char(ch) {
      has_digit = true
      i += 1
      continue
    }
    break
  }

  if !has_digit || i >= arr.length() {
    return false
  }

  let sep = arr[i]
  let next_index = if sep == '.' || sep == ')' || sep == '）' {
    i + 1
  } else if sep == ' ' {
    i
  } else {
    return false
  }

  let mut j = next_index
  while j < arr.length() && arr[j] == ' ' {
    j += 1
  }
  if j >= arr.length() {
    return false
  }

  let first = arr[j]
  (first >= 'A' && first <= 'Z') || is_cjk_top_level_heading_initial(first)
}

///|
fn is_cjk_top_level_heading_initial(ch : Char) -> Bool {
  ch == '第' ||
  ch == '一' ||
  ch == '二' ||
  ch == '三' ||
  ch == '四' ||
  ch == '五' ||
  ch == '六' ||
  ch == '七' ||
  ch == '八' ||
  ch == '九' ||
  ch == '十'
}

///|
fn right_starts_soft_continuation(text : String) -> Bool {
  let t = normalize_pdf_comparison_text(text)
  let arr = t.to_array()
  if arr.is_empty() {
    return false
  }

  let first = arr[0]
  if first == ',' ||
    first == ';' ||
    first == ':' ||
    first == ')' ||
    first == ']' {
    return true
  }

  (first >= 'a' && first <= 'z') ||
  t.has_prefix("and ") ||
  t.has_prefix("or ") ||
  t.has_prefix("but ") ||
  t.has_prefix("so ") ||
  t.has_prefix("to ") ||
  t.has_prefix("for ") ||
  t.has_prefix("with ") ||
  t.has_prefix("of ") ||
  t.has_prefix("in ") ||
  t.has_prefix("on ")
}

///|
fn left_has_soft_continuation_tail(text : String) -> Bool {
  let t = normalize_pdf_comparison_text(text).trim().to_owned()
  if t == "" {
    return false
  }

  if t.has_suffix(",") ||
    t.has_suffix(";") ||
    t.has_suffix(":") ||
    t.has_suffix("(") ||
    t.has_suffix("[") ||
    t.has_suffix("{") {
    return true
  }

  let last = last_pdf_merge_ascii_word(t)
  last == "a" ||
  last == "an" ||
  last == "the" ||
  last == "of" ||
  last == "and" ||
  last == "or" ||
  last == "to" ||
  last == "for" ||
  last == "with" ||
  last == "in" ||
  last == "on" ||
  last == "at" ||
  last == "by" ||
  last == "so"
}

///|
fn last_pdf_merge_ascii_word(text : String) -> String {
  let arr = text.to_array()
  if arr.is_empty() {
    return ""
  }

  let out_rev = Array::new()
  let mut seen = false
  let mut boundary_ok = false
  let mut i = arr.length()
  while i > 0 {
    let ch = arr[i - 1]
    if (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') {
      out_rev.push(ch)
      seen = true
      i -= 1
      continue
    }
    if seen {
      boundary_ok = ch == ' ' ||
        ch == '\t' ||
        ch == '\n' ||
        ch == '\r' ||
        ch == '(' ||
        ch == '[' ||
        ch == '{'
      break
    }
    i -= 1
  }

  if seen && i == 0 {
    boundary_ok = true
  }

  if !boundary_ok {
    return ""
  }

  if out_rev.is_empty() {
    return ""
  }

  let out = Array::new()
  let mut j = out_rev.length()
  while j > 0 {
    let ch = out_rev[j - 1]
    if ch >= 'A' && ch <= 'Z' {
      out.push(Int::unsafe_to_char(ch.to_int() + 32))
    } else {
      out.push(ch)
    }
    j -= 1
  }
  String::from_array(out)
}

///|
fn is_merge_decision(decision : PdfMergeDecision) -> Bool {
  match decision.status {
    PdfMergeDecisionStatus::Merge => true
    PdfMergeDecisionStatus::KeepSplit => false
  }
}
