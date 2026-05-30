///|
/// Span/source-order and visual-boundary helpers for PDF text line assembly.
///
/// These rules support `should_join_same_line` and line/block cleanup without
/// mixing low-level span geometry into the higher-level text-flow rules.
fn span_is_empty(span : @model.PdfTextSpan) -> Bool {
  span.text.trim() == ""
}

///|
fn right_is_explicit_break(line : @model.PdfTextLine) -> Bool {
  for span in line.spans {
    if span.break_before {
      return true
    }
  }
  false
}

///|
fn spans_text(spans : Array[@model.PdfTextSpan]) -> String {
  let mut buf = ""
  for s in spans {
    buf = buf + s.text
  }
  buf
}

///|
fn primary_source_ref(span : @model.PdfTextSpan) -> @model.PdfSourceRef? {
  if span.source_refs.is_empty() {
    None
  } else {
    Some(span.source_refs[0])
  }
}

///|
fn source_op_is_close(
  left : @model.PdfSourceRef,
  right : @model.PdfSourceRef,
) -> Bool {
  let diff = right.source_op_index - left.source_op_index
  diff >= 0 && diff <= 12
}

///|
fn content_order_is_close(
  left : @model.PdfSourceRef,
  right : @model.PdfSourceRef,
) -> Bool {
  match (left.content_order_index, right.content_order_index) {
    (Some(a), Some(b)) => {
      let diff = b - a
      diff >= 0 && diff <= 12
    }
    _ => true
  }
}

///|
/// 当前累计 spans 的右边界。
fn current_line_right_x(spans : Array[@model.PdfTextSpan]) -> Double {
  if spans.is_empty() {
    return 0.0
  }

  let mut x = spans[0].bbox.x1
  for span in spans {
    if span.bbox.x1 > x {
      x = span.bbox.x1
    }
  }
  x
}

///|
/// 当前累计 spans 的左边界。
fn current_line_left_x(spans : Array[@model.PdfTextSpan]) -> Double {
  if spans.is_empty() {
    return 0.0
  }

  let mut x = spans[0].bbox.x0
  for span in spans {
    if span.bbox.x0 < x {
      x = span.bbox.x0
    }
  }
  x
}

///|
fn current_line_top_y(spans : Array[@model.PdfTextSpan]) -> Double {
  if spans.is_empty() {
    return 0.0
  }

  let mut y = spans[0].bbox.y1
  for span in spans {
    if span.bbox.y1 > y {
      y = span.bbox.y1
    }
  }
  y
}

///|
fn current_line_bottom_y(spans : Array[@model.PdfTextSpan]) -> Double {
  if spans.is_empty() {
    return 0.0
  }

  let mut y = spans[0].bbox.y0
  for span in spans {
    if span.bbox.y0 < y {
      y = span.bbox.y0
    }
  }
  y
}

///|
fn current_line_vertical_gap(
  current_spans : Array[@model.PdfTextSpan],
  right : @model.PdfTextSpan,
) -> Double {
  let cur_top = current_line_top_y(current_spans)
  let cur_bottom = current_line_bottom_y(current_spans)
  let overlap_top = if cur_top < right.bbox.y1 {
    cur_top
  } else {
    right.bbox.y1
  }
  let overlap_bottom = if cur_bottom > right.bbox.y0 {
    cur_bottom
  } else {
    right.bbox.y0
  }
  let overlap = overlap_top - overlap_bottom
  if overlap > 0.0 {
    0.0
  } else if right.bbox.y0 > cur_top {
    right.bbox.y0 - cur_top
  } else if cur_bottom > right.bbox.y1 {
    cur_bottom - right.bbox.y1
  } else {
    0.0
  }
}

///|
fn has_strong_vertical_separation(
  current_spans : Array[@model.PdfTextSpan],
  right : @model.PdfTextSpan,
) -> Bool {
  let cur_fs = current_line_font_size(current_spans).unwrap_or(12.0)
  let right_fs = right.font_size.unwrap_or(cur_fs)
  let ref_h = if cur_fs > right_fs { cur_fs } else { right_fs }
  current_line_vertical_gap(current_spans, right) > ref_h * 0.25
}

///|
/// 是否像“同一视觉行里的跨列切换”。
///
/// 典型场景：
/// - 左侧已经是一整句独立内容
/// - 右侧又在同一 y 上，从很靠右的位置重新开始另一句
/// - 单靠 current_line_right_x 可能检测不到 gap，因此补一个“相对起点的大横向跳跃”判断
fn looks_like_cross_column_same_row_chunk(
  current_spans : Array[@model.PdfTextSpan],
  right : @model.PdfTextSpan,
) -> Bool {
  if current_spans.is_empty() {
    return false
  }

  if !nearly_same_visual_line(current_spans, right) {
    return false
  }

  let current_text = normalize_text(spans_text(current_spans)).trim().to_owned()
  let right_text = normalize_text(right.text).trim().to_owned()

  if current_text == "" || right_text == "" {
    return false
  }

  // 左边必须已经像一段独立内容，而不是词内碎片
  if !ends_with_strong_sentence_punct(current_text) {
    return false
  }

  if word_count(current_text) < 5 {
    return false
  }

  // 右边也要像另一段独立起点
  if !starts_with_upper_ascii(right_text) &&
    !looks_like_section_or_page_prefix(right_text) {
    return false
  }

  if word_count(right_text) < 4 {
    return false
  }

  let line_left = current_line_left_x(current_spans)
  let right_x = right.origin.x
  let fs = current_line_font_size(current_spans).unwrap_or(12.0)

  // 相对当前行起点出现很大的横向跳跃，更像右栏重新开始
  let x_jump = right_x - line_left
  x_jump >= fs * 14.0
}

///|
/// 当前累计 spans 的基线 y，先用 origin.y 平均值粗估。
fn current_line_baseline_y(spans : Array[@model.PdfTextSpan]) -> Double {
  if spans.is_empty() {
    return 0.0
  }

  let mut total = 0.0
  for span in spans {
    total = total + span.origin.y
  }
  total / spans.length().to_double()
}

///|
/// 当前累计 spans 的主字号，先取最大值。
fn current_line_font_size(spans : Array[@model.PdfTextSpan]) -> Double? {
  if spans.is_empty() {
    return None
  }

  let mut best = 0.0
  let mut seen = false
  for span in spans {
    match span.font_size {
      Some(fs) =>
        if !seen || fs > best {
          best = fs
          seen = true
        }
      None => ()
    }
  }

  if seen {
    Some(best)
  } else {
    None
  }
}

///|
fn abs_double_rule(x : Double) -> Double {
  if x < 0.0 {
    -x
  } else {
    x
  }
}

///|
/// 是否近似同一视觉行。
fn nearly_same_visual_line(
  current_spans : Array[@model.PdfTextSpan],
  right : @model.PdfTextSpan,
) -> Bool {
  let cur_y = current_line_baseline_y(current_spans)
  let right_y = right.origin.y
  let cur_fs = current_line_font_size(current_spans).unwrap_or(12.0)
  let right_fs = right.font_size.unwrap_or(cur_fs)
  let ref_h = if cur_fs > right_fs { cur_fs } else { right_fs }

  if has_strong_vertical_separation(current_spans, right) {
    return false
  }

  let tol = ref_h * 0.35

  abs_double_rule(cur_y - right_y) <= tol
}

///|
/// 字号是否近似一致。
fn nearly_same_font_size_opt(a : Double?, b : Double?) -> Bool {
  match (a, b) {
    (Some(x), Some(y)) => abs_double_rule(x - y) <= 0.75
    _ => true
  }
}

///|
/// 当前累计 spans 和右侧 span 之间是否出现明显水平空隙。
fn has_large_horizontal_gap(
  current_spans : Array[@model.PdfTextSpan],
  right : @model.PdfTextSpan,
) -> Bool {
  if current_spans.is_empty() {
    return false
  }

  let cur_right = current_line_right_x(current_spans)
  let gap = right.origin.x - cur_right
  let fs = current_line_font_size(current_spans).unwrap_or(12.0)

  // gap 大于约 0.8em，通常就不该继续吸进同一行内片段
  gap > fs * 0.8
}

///|
/// 右侧 span 是否更像“新块起点”而不是同一行续写。
fn looks_like_new_visual_chunk(
  current_spans : Array[@model.PdfTextSpan],
  right : @model.PdfTextSpan,
) -> Bool {
  if !nearly_same_visual_line(current_spans, right) {
    return true
  }

  if !nearly_same_font_size_opt(
      current_line_font_size(current_spans),
      right.font_size,
    ) {
    return true
  }

  if has_large_horizontal_gap(current_spans, right) {
    return true
  }

  // 关键补充：同一 y 上从很靠右的位置重新开始另一句，视为新块
  if looks_like_cross_column_same_row_chunk(current_spans, right) {
    return true
  }

  false
}
