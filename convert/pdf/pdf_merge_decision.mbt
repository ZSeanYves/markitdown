///|
priv enum PdfMergeDecisionStatus {
  Merge
  KeepSplit
}

///|
priv struct PdfMergeBoundaryEvidence {
  empty_boundary : Bool
  body_to_body : Bool
  kind_mismatch : Bool
  same_paragraph_candidate : Bool
  previous_no_sentence_end : Bool
  next_starts_lowercase : Bool
  next_continues_sentence : Bool
  similar_indent : Bool
  compatible_line_width : Bool
  small_page_boundary_gap : Bool
  wrapped_line_continuation : Bool
  same_column_band : Bool
  previous_sentence_end : Bool
  next_starts_heading_like : Bool
  next_starts_list_like : Bool
  heading_guard : Bool
  list_guard : Bool
  table_guard : Bool
  image_guard : Bool
  noise_guard : Bool
  page_number_guard : Bool
  large_indent_shift : Bool
  column_shift_guard : Bool
  two_column_guard : Bool
  short_fragment_guard : Bool
  caption_guard : Bool
  layout_compatible : Bool
  core_continuation_support : Bool
}

///|
priv struct PdfMergeDecision {
  status : PdfMergeDecisionStatus
  reason_tags : Array[String]
}

///|
fn decide_page_boundary_merge(
  prev_page : PdfConvertPage,
  cur_page : PdfConvertPage,
) -> PdfMergeDecision {
  let evidence = collect_page_boundary_merge_evidence(prev_page, cur_page)

  if evidence.empty_boundary {
    return {
      status: PdfMergeDecisionStatus::KeepSplit,
      reason_tags: ["empty_boundary"],
    }
  }

  if has_merge_hard_blocker_from_evidence(evidence) {
    return {
      status: PdfMergeDecisionStatus::KeepSplit,
      reason_tags: keep_split_reason_tags(evidence),
    }
  }

  if !has_strong_continuity_support(evidence) {
    return {
      status: PdfMergeDecisionStatus::KeepSplit,
      reason_tags: keep_split_reason_tags_with_fallback(
        evidence, "insufficient_continuity_signal",
      ),
    }
  }

  if should_merge_with_evidence(evidence) {
    return {
      status: PdfMergeDecisionStatus::Merge,
      reason_tags: merge_reason_tags(evidence),
    }
  }

  {
    status: PdfMergeDecisionStatus::KeepSplit,
    reason_tags: keep_split_reason_tags_with_fallback(
      evidence, "layout_incompatible",
    ),
  }
}

///|
fn collect_page_boundary_merge_evidence(
  prev_page : PdfConvertPage,
  cur_page : PdfConvertPage,
) -> PdfMergeBoundaryEvidence {
  if prev_page.blocks.is_empty() || cur_page.blocks.is_empty() {
    return {
      empty_boundary: true,
      body_to_body: false,
      kind_mismatch: true,
      same_paragraph_candidate: false,
      previous_no_sentence_end: false,
      next_starts_lowercase: false,
      next_continues_sentence: false,
      similar_indent: false,
      compatible_line_width: false,
      small_page_boundary_gap: false,
      wrapped_line_continuation: false,
      same_column_band: false,
      previous_sentence_end: false,
      next_starts_heading_like: false,
      next_starts_list_like: false,
      heading_guard: false,
      list_guard: false,
      table_guard: false,
      image_guard: false,
      noise_guard: false,
      page_number_guard: false,
      large_indent_shift: false,
      column_shift_guard: false,
      two_column_guard: false,
      short_fragment_guard: false,
      caption_guard: false,
      layout_compatible: false,
      core_continuation_support: false,
    }
  }

  let left = prev_page.blocks[prev_page.blocks.length() - 1]
  let right = cur_page.blocks[0]
  let lt = left.text.trim().to_owned()
  let rt = right.text.trim().to_owned()
  let previous_sentence_end = ends_with_strong_sentence_punct(lt)
  let next_starts_heading_like = looks_like_new_section_after_page_break(rt)
  let next_starts_list_like = looks_like_list_start(rt)
  let body_to_body = left.kind == PdfConvertBlockKind::Paragraph &&
    right.kind == PdfConvertBlockKind::Paragraph
  let kind_mismatch = !body_to_body
  let same_paragraph_candidate = right.first_is_same_paragraph_with_prev_candidate
  let next_first = first_non_space_char(rt)
  let next_starts_lowercase = match next_first {
    Some(ch) => ch >= 'a' && ch <= 'z'
    None => false
  }
  let next_continues_sentence = looks_like_page_start_continuation(rt)
  let similar_indent = indent_close(
    left.last_indent_left,
    right.first_indent_left,
  )
  let compatible_line_width = block_width_compatible(left, right)
  let small_page_boundary_gap = !gap_looks_like_new_paragraph(
    right.first_line_gap_before,
    right.first_line_height,
  )
  let wrapped_line_continuation = left.last_is_wrapped_candidate ||
    right.first_is_wrapped_candidate
  let same_column_band = column_band_compatible(left, right)
  let table_guard = left.is_table_cell_candidate ||
    right.is_table_cell_candidate
  let caption_guard = left.is_caption_candidate || right.is_caption_candidate
  let image_guard = boundary_has_nearby_image(prev_page, left) ||
    boundary_has_nearby_image(cur_page, right)
  let noise_guard = left.kind == PdfConvertBlockKind::Noise ||
    right.kind == PdfConvertBlockKind::Noise
  let page_number_guard = is_page_label_like(lt) ||
    is_page_label_like(rt) ||
    left.is_noise_candidate ||
    right.is_noise_candidate
  let heading_guard = next_starts_heading_like
  let list_guard = next_starts_list_like
  let large_indent_shift = indent_shift_large(
    left.last_indent_left,
    right.first_indent_left,
  )
  let column_shift_guard = left_edge_shift_large(left, right)
  let two_column_guard = looks_like_cross_page_two_column_shift(left, right)
  let short_fragment_guard = lt.length() <= 8 || rt.length() <= 8
  let layout_compatible = font_size_close(
      left.dominant_font_size,
      right.dominant_font_size,
    ) &&
    similar_indent &&
    alignment_compatible(left.last_alignment_hint, right.first_alignment_hint) &&
    small_page_boundary_gap
  let core_continuation_support = left.last_is_wrapped_candidate ||
    right.first_is_wrapped_candidate ||
    right.first_is_same_paragraph_with_prev_candidate

  {
    empty_boundary: lt == "" || rt == "",
    body_to_body,
    kind_mismatch,
    same_paragraph_candidate,
    previous_no_sentence_end: !previous_sentence_end,
    next_starts_lowercase,
    next_continues_sentence,
    similar_indent,
    compatible_line_width,
    small_page_boundary_gap,
    wrapped_line_continuation,
    same_column_band,
    previous_sentence_end,
    next_starts_heading_like,
    next_starts_list_like,
    heading_guard,
    list_guard,
    table_guard,
    image_guard,
    noise_guard,
    page_number_guard,
    large_indent_shift,
    column_shift_guard,
    two_column_guard,
    short_fragment_guard,
    caption_guard,
    layout_compatible,
    core_continuation_support,
  }
}

///|
fn has_merge_hard_blocker_from_evidence(
  evidence : PdfMergeBoundaryEvidence,
) -> Bool {
  evidence.kind_mismatch ||
  evidence.previous_sentence_end ||
  evidence.heading_guard ||
  evidence.list_guard ||
  evidence.table_guard ||
  evidence.image_guard ||
  evidence.caption_guard ||
  evidence.noise_guard ||
  evidence.page_number_guard ||
  evidence.large_indent_shift ||
  evidence.column_shift_guard ||
  evidence.two_column_guard
}

///|
fn has_strong_continuity_support(evidence : PdfMergeBoundaryEvidence) -> Bool {
  evidence.same_paragraph_candidate ||
  evidence.wrapped_line_continuation ||
  (evidence.previous_no_sentence_end && evidence.next_continues_sentence) ||
  (evidence.previous_no_sentence_end && evidence.next_starts_lowercase)
}

///|
fn should_merge_with_evidence(evidence : PdfMergeBoundaryEvidence) -> Bool {
  let strong_sentence_flow = evidence.body_to_body &&
    evidence.previous_no_sentence_end &&
    evidence.similar_indent &&
    (
      evidence.same_paragraph_candidate ||
      evidence.wrapped_line_continuation ||
      evidence.next_continues_sentence
    )

  let strong_layout_continuation = evidence.body_to_body &&
    evidence.wrapped_line_continuation &&
    evidence.similar_indent &&
    evidence.same_column_band

  let strong_core_continuation = evidence.same_paragraph_candidate &&
    evidence.similar_indent &&
    evidence.same_column_band &&
    evidence.body_to_body

  let strong_lowercase_continuation = evidence.previous_no_sentence_end &&
    evidence.next_starts_lowercase &&
    evidence.compatible_line_width &&
    evidence.similar_indent &&
    evidence.body_to_body

  let strong_boundary_continuity = evidence.small_page_boundary_gap &&
    evidence.same_column_band &&
    evidence.body_to_body &&
    (
      evidence.next_continues_sentence ||
      evidence.same_paragraph_candidate ||
      evidence.wrapped_line_continuation
    )

  (
    strong_sentence_flow ||
    strong_layout_continuation ||
    strong_core_continuation ||
    strong_lowercase_continuation ||
    strong_boundary_continuity
  ) &&
  (evidence.layout_compatible || evidence.core_continuation_support)
}

///|
fn merge_reason_tags(evidence : PdfMergeBoundaryEvidence) -> Array[String] {
  let out : Array[String] = []

  if evidence.body_to_body {
    out.push("body_to_body")
  }
  if evidence.same_paragraph_candidate {
    out.push("same_paragraph_candidate")
  }
  if evidence.previous_no_sentence_end {
    out.push("previous_no_sentence_end")
  }
  if evidence.next_starts_lowercase {
    out.push("next_starts_lowercase")
  }
  if evidence.next_continues_sentence {
    out.push("next_continues_sentence")
  }
  if evidence.similar_indent {
    out.push("similar_indent")
  }
  if evidence.compatible_line_width {
    out.push("compatible_line_width")
  }
  if evidence.small_page_boundary_gap {
    out.push("small_page_boundary_gap")
  }
  if evidence.wrapped_line_continuation {
    out.push("wrapped_line_continuation")
  }
  if evidence.same_column_band {
    out.push("same_column_band")
  }
  if evidence.layout_compatible {
    out.push("layout_compatible")
  }
  if evidence.core_continuation_support {
    out.push("core_continuation_support")
  }
  if out.is_empty() {
    out.push("merge_page_boundary")
  }

  out
}

///|
fn keep_split_reason_tags(evidence : PdfMergeBoundaryEvidence) -> Array[String] {
  let out : Array[String] = []

  if evidence.kind_mismatch {
    out.push("kind_mismatch")
  }
  if evidence.previous_sentence_end {
    out.push("previous_sentence_end")
  }
  if evidence.next_starts_heading_like {
    out.push("next_starts_heading_like")
  }
  if evidence.next_starts_list_like {
    out.push("next_starts_list_like")
  }
  if evidence.heading_guard {
    out.push("heading_guard")
  }
  if evidence.list_guard {
    out.push("list_guard")
  }
  if evidence.table_guard {
    out.push("table_guard")
  }
  if evidence.image_guard {
    out.push("image_guard")
  }
  if evidence.noise_guard {
    out.push("noise_guard")
  }
  if evidence.page_number_guard {
    out.push("page_number_guard")
  }
  if evidence.large_indent_shift {
    out.push("large_indent_shift")
  }
  if evidence.column_shift_guard {
    out.push("column_shift_guard")
  }
  if evidence.two_column_guard {
    out.push("two_column_guard")
  }
  if evidence.short_fragment_guard {
    out.push("short_fragment_guard")
  }
  if evidence.caption_guard {
    out.push("caption_guard")
  }
  out
}

///|
fn keep_split_reason_tags_with_fallback(
  evidence : PdfMergeBoundaryEvidence,
  fallback : String,
) -> Array[String] {
  let out = keep_split_reason_tags(evidence)
  if out.is_empty() {
    out.push(fallback)
  }
  out
}

///|
fn block_width_compatible(
  left : PdfConvertBlock,
  right : PdfConvertBlock,
) -> Bool {
  let lw = @model.rect_width(left._bbox)
  let rw = @model.rect_width(right._bbox)
  let max_w = max_merge_f64(lw, rw)
  if max_w <= 0.0 {
    return true
  }
  abs_merge_f64(lw - rw) <= max_w * 0.20
}

///|
fn column_band_compatible(
  left : PdfConvertBlock,
  right : PdfConvertBlock,
) -> Bool {
  abs_merge_f64(left.left_x - right.left_x) <= 36.0 &&
  abs_merge_f64(left._bbox.x1 - right._bbox.x1) <= 48.0
}

///|
fn indent_shift_large(left : Double?, right : Double?) -> Bool {
  match (left, right) {
    (Some(a), Some(b)) => abs_merge_f64(a - b) > 24.0
    _ => false
  }
}

///|
fn left_edge_shift_large(
  left : PdfConvertBlock,
  right : PdfConvertBlock,
) -> Bool {
  abs_merge_f64(left.left_x - right.left_x) > 48.0
}

///|
fn looks_like_cross_page_two_column_shift(
  left : PdfConvertBlock,
  right : PdfConvertBlock,
) -> Bool {
  let left_w = @model.rect_width(left._bbox)
  let right_w = @model.rect_width(right._bbox)
  let narrow = left_w <= 180.0 && right_w <= 180.0
  let left_shift = abs_merge_f64(left.left_x - right.left_x) > 96.0
  narrow && left_shift
}

///|
fn boundary_has_nearby_image(
  page : PdfConvertPage,
  block : PdfConvertBlock,
) -> Bool {
  for image in page.images {
    if rects_merge_overlap_or_near(block._bbox, image._bbox, 20.0) {
      return true
    }
  }
  false
}

///|
fn rects_merge_overlap_or_near(
  a : @model.PdfRect,
  b : @model.PdfRect,
  pad : Double,
) -> Bool {
  let x_overlap = a.x0 <= b.x1 + pad && a.x1 + pad >= b.x0
  let y_overlap = a.y0 <= b.y1 + pad && a.y1 + pad >= b.y0
  x_overlap && y_overlap
}

///|
fn render_pdf_merge_decision(
  prev_page_index : Int,
  prev_block_index : Int,
  next_page_index : Int,
  next_block_index : Int,
  decision : PdfMergeDecision,
  prev_text : String,
  next_text : String,
) -> String {
  "[pdf-merge] prev=page" +
  prev_page_index.to_string() +
  ":block" +
  prev_block_index.to_string() +
  " next=page" +
  next_page_index.to_string() +
  ":block" +
  next_block_index.to_string() +
  " status=" +
  render_pdf_merge_status(decision.status) +
  " reason=" +
  render_pdf_merge_reason_tags(decision.reason_tags) +
  " text_prev=\"" +
  prev_text +
  "\"" +
  " text_next=\"" +
  next_text +
  "\""
}

///|
fn render_pdf_merge_status(status : PdfMergeDecisionStatus) -> String {
  match status {
    PdfMergeDecisionStatus::Merge => "merge"
    PdfMergeDecisionStatus::KeepSplit => "keep_split"
  }
}

///|
fn render_pdf_merge_reason_tags(reason_tags : Array[String]) -> String {
  if reason_tags.is_empty() {
    "none"
  } else {
    reason_tags.join("+")
  }
}

///|
fn abs_merge_f64(v : Double) -> Double {
  if v < 0.0 {
    -v
  } else {
    v
  }
}

///|
fn max_merge_f64(a : Double, b : Double) -> Double {
  if a >= b {
    a
  } else {
    b
  }
}
