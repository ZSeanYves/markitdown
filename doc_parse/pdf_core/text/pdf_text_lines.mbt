///|
const DEBUG_LINE_PIPELINE = false

///|
/// 页级 line 结果。
pub struct PdfPageLines {
  page_index : Int
  lines : Array[@model.PdfTextLine]
}

///|
/// 文档级 line 结果。
pub struct PdfDocumentLines {
  pages : Array[PdfPageLines]
}

///|
/// 从文档 spans 构建 lines。
pub fn build_document_lines(doc_spans : PdfDocumentSpans) -> PdfDocumentLines {
  let pages = Array::new()
  for page in doc_spans.pages {
    pages.push(build_page_lines(page))
  }
  { pages, }
}

///|
pub fn build_page_lines(page_spans : PdfPageSpans) -> PdfPageLines {
  let raw_lines0 = build_lines_from_spans(
    page_spans.page_index,
    page_spans.spans,
  )
  let raw_lines = enrich_page_line_layout(raw_lines0)

  if DEBUG_LINE_PIPELINE {
    debug_print_lines("raw_lines", page_spans.page_index, raw_lines)
  }

  let normalized = normalize_line_texts(raw_lines)
  if DEBUG_LINE_PIPELINE {
    debug_print_lines("normalized", page_spans.page_index, normalized)
    debug_print_merge_reasons(page_spans.page_index, normalized)
  }

  let merged0 = merge_adjacent_lines(page_spans.page_index, normalized)
  let merged = enrich_page_line_layout(merged0)

  if DEBUG_LINE_PIPELINE {
    debug_print_lines("merged", page_spans.page_index, merged)
  }

  let filtered = filter_noise_lines(merged)
  if DEBUG_LINE_PIPELINE {
    debug_print_lines("filtered", page_spans.page_index, filtered)
  }

  { page_index: page_spans.page_index, lines: filtered }
}

///|
fn debug_print_lines(
  stage : String,
  page_index : Int,
  lines : Array[@model.PdfTextLine],
) -> Unit {
  println(
    "== debug lines " +
    stage +
    " page=" +
    page_index.to_string() +
    " count=" +
    lines.length().to_string(),
  )

  for i = 0; i < lines.length(); i = i + 1 {
    let text = @model.line_text(lines[i]).trim().to_string()
    let short = if text.length() > 80 {
      text[:80].to_string() + "..."
    } else {
      text
    }

    println("  [" + i.to_string() + "] " + short)
  }
}

///|
fn debug_print_merge_reasons(
  page_index : Int,
  lines : Array[@model.PdfTextLine],
) -> Unit {
  println("== debug merge reasons page=" + page_index.to_string())

  if lines.length() <= 1 {
    return
  }

  for i = 0; i < lines.length() - 1; i = i + 1 {
    let left = lines[i]
    let right = lines[i + 1]
    let left_text = @model.line_text(left).trim().to_string()
    let right_text = @model.line_text(right).trim().to_string()

    let left_short = if left_text.length() > 40 {
      left_text[:40].to_string() + "..."
    } else {
      left_text
    }

    let right_short = if right_text.length() > 40 {
      right_text[:40].to_string() + "..."
    } else {
      right_text
    }

    println(
      "  [" +
      i.to_string() +
      " -> " +
      (i + 1).to_string() +
      "] " +
      explain_should_merge_lines(left, right) +
      " | left=\"" +
      left_short +
      "\"" +
      " | right=\"" +
      right_short +
      "\"",
    )
  }
}

///|
fn merge_adjacent_lines(
  page_index : Int,
  lines : Array[@model.PdfTextLine],
) -> Array[@model.PdfTextLine] {
  if lines.is_empty() {
    return []
  }

  let out = Array::new()
  let mut current = lines[0]
  let mut merged_index = 0

  for i = 1; i < lines.length(); i = i + 1 {
    let next = lines[i]
    if should_merge_lines(current, next) {
      current = merge_two_lines(page_index, merged_index, current, next)
    } else {
      out.push(current)
      merged_index = merged_index + 1
      current = next
    }
  }

  out.push(current)
  out
}

///|
/// 过滤明显噪声行。
fn filter_noise_lines(
  lines : Array[@model.PdfTextLine],
) -> Array[@model.PdfTextLine] {
  let out = Array::new()

  for line in lines {
    let text = @model.line_text(line).trim()

    if text == "" {
      continue
    }

    if is_page_number_candidate(text.to_string()) {
      //println("[drop-noise-line] " + text.to_string())
      continue
    }

    out.push(line)
  }

  out
}

///|
/// 从 span 数组构建 lines。
///
/// 当前 line 更接近“提取/操作级行”，
/// 后续再通过 merge 恢复正文连续体。
pub fn build_lines_from_spans(
  page_index : Int,
  spans : Array[@model.PdfTextSpan],
) -> Array[@model.PdfTextLine] {
  if spans.is_empty() {
    return []
  }

  let out = Array::new()

  let mut current_spans : Array[@model.PdfTextSpan] = [spans[0]]
  let mut line_index = 0

  for i = 1; i < spans.length(); i = i + 1 {
    let cur = spans[i]

    if should_join_same_line(current_spans, cur) {
      current_spans.push(cur)
    } else {
      out.push(make_line_from_spans(page_index, line_index, current_spans))
      line_index = line_index + 1
      current_spans = [cur]
    }
  }

  out.push(make_line_from_spans(page_index, line_index, current_spans))
  out
}

///|
/// 由 spans 构造一个最小 line。
pub fn make_line_from_spans(
  page_index : Int,
  line_index : Int,
  spans : Array[@model.PdfTextSpan],
) -> @model.PdfTextLine {
  let source_refs = collect_span_source_refs(spans)
  make_line_record(page_index, line_index, spans, false, source_refs)
}

///|
fn make_line_record(
  page_index : Int,
  line_index : Int,
  spans : Array[@model.PdfTextSpan],
  is_wrapped : Bool,
  source_refs : Array[@model.PdfSourceRef],
) -> @model.PdfTextLine {
  let bbox = estimate_line_bbox(spans)
  let baseline_y = estimate_line_baseline_y(spans)
  let line_height = estimate_line_height(spans)
  let indent_left = estimate_indent_left(spans)
  let indent_right = estimate_indent_right(spans)

  {
    id: make_line_id(page_index, line_index),
    bbox,
    baseline_y: Some(baseline_y),
    ascent: None,
    descent: None,
    line_height: Some(line_height),
    indent_left: Some(indent_left),
    indent_right: Some(indent_right),
    alignment_hint: None,
    line_gap_before: None,
    line_gap_after: None,
    spans,
    is_wrapped_candidate: is_wrapped,
    is_same_paragraph_with_prev_candidate: false,
    source_refs,
  }
}

///|
/// 用 spans 的 origin/font_size 粗估 line bbox。
fn estimate_line_bbox(spans : Array[@model.PdfTextSpan]) -> @model.PdfRect {
  let raw = @model.spans_bbox(spans)
  match raw {
    Some(r) =>
      if is_useful_rect(r) {
        r
      } else {
        estimate_line_bbox_from_origins(spans)
      }
    None => estimate_line_bbox_from_origins(spans)
  }
}

///|
fn estimate_line_bbox_from_origins(
  spans : Array[@model.PdfTextSpan],
) -> @model.PdfRect {
  if spans.is_empty() {
    return default_rect()
  }

  let mut x0 = spans[0].origin.x
  let mut x1 = spans[0].origin.x
  let mut y0 = spans[0].origin.y
  let mut y1 = spans[0].origin.y

  for span in spans {
    let sx0 = span.origin.x
    let sh = span.font_size.unwrap_or(12.0)
    let sw = estimate_span_text_width(span)
    let sy0 = span.origin.y - sh * 0.85
    let sy1 = span.origin.y + sh * 0.25
    let sx1 = span.origin.x + sw

    if sx0 < x0 {
      x0 = sx0
    }
    if sx1 > x1 {
      x1 = sx1
    }
    if sy0 < y0 {
      y0 = sy0
    }
    if sy1 > y1 {
      y1 = sy1
    }
  }

  { x0, y0, x1, y1 }
}

///|
fn estimate_span_text_width(span : @model.PdfTextSpan) -> Double {
  let fs = span.font_size.unwrap_or(12.0)
  let text = span.text
  let mut total = 0.0

  for ch in text {
    total = total + estimate_char_width(ch, fs)
  }

  if total <= 0.0 {
    fs
  } else {
    total
  }
}

///|
fn estimate_char_width(ch : Char, font_size : Double) -> Double {
  if is_cjk_char_local(ch) {
    font_size
  } else if ch == ' ' || ch == '\t' {
    font_size * 0.33
  } else if is_ascii_letter_local(ch) || is_ascii_digit_local(ch) {
    font_size * 0.6
  } else {
    font_size * 0.5
  }
}

///|
fn estimate_line_baseline_y(spans : Array[@model.PdfTextSpan]) -> Double {
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
fn estimate_line_height(spans : Array[@model.PdfTextSpan]) -> Double {
  if spans.is_empty() {
    return 0.0
  }

  let mut h = 0.0
  for span in spans {
    let fs = span.font_size.unwrap_or(12.0)
    if fs > h {
      h = fs
    }
  }
  h
}

///|
fn estimate_indent_left(spans : Array[@model.PdfTextSpan]) -> Double {
  if spans.is_empty() {
    return 0.0
  }

  let mut x = spans[0].origin.x
  for span in spans {
    if span.origin.x < x {
      x = span.origin.x
    }
  }
  x
}

///|
fn estimate_indent_right(spans : Array[@model.PdfTextSpan]) -> Double {
  let bbox = estimate_line_bbox(spans)
  bbox.x1
}

///|
/// 根据 baseline_y 近似回填相邻行间距。
fn enrich_page_line_layout(
  lines : Array[@model.PdfTextLine],
) -> Array[@model.PdfTextLine] {
  if lines.is_empty() {
    return []
  }

  let out : Array[@model.PdfTextLine] = Array::new()

  for i = 0; i < lines.length(); i = i + 1 {
    let line = lines[i]
    let before = if i == 0 {
      None
    } else {
      estimate_gap_between(lines[i - 1], line)
    }

    let after = if i + 1 >= lines.length() {
      None
    } else {
      estimate_gap_between(line, lines[i + 1])
    }

    let updated : @model.PdfTextLine = {
      id: line.id,
      bbox: line.bbox,
      baseline_y: line.baseline_y,
      ascent: line.ascent,
      descent: line.descent,
      line_height: line.line_height,
      indent_left: line.indent_left,
      indent_right: line.indent_right,
      alignment_hint: line.alignment_hint,
      line_gap_before: before,
      line_gap_after: after,
      spans: line.spans,
      is_wrapped_candidate: line.is_wrapped_candidate,
      is_same_paragraph_with_prev_candidate: line.is_same_paragraph_with_prev_candidate,
      source_refs: line.source_refs,
    }

    out.push(updated)
  }

  out
}

///|
fn estimate_gap_between(
  upper : @model.PdfTextLine,
  lower : @model.PdfTextLine,
) -> Double? {
  match (upper.baseline_y, lower.baseline_y) {
    (Some(a), Some(b)) => {
      let raw = abs_double(b - a)
      let h = upper.line_height.unwrap_or(0.0)
      let gap = raw - h
      if gap > 0.0 {
        Some(gap)
      } else {
        Some(0.0)
      }
    }
    _ => None
  }
}

///|
fn abs_double(x : Double) -> Double {
  if x < 0.0 {
    -x
  } else {
    x
  }
}

///|
/// 汇总 spans 的 source refs，并去重。
fn collect_span_source_refs(
  spans : Array[@model.PdfTextSpan],
) -> Array[@model.PdfSourceRef] {
  let out = Array::new()
  for span in spans {
    for src in span.source_refs {
      if !contains_source_ref(out, src) {
        out.push(src)
      }
    }
  }
  out
}

///|
fn contains_source_ref(
  refs : Array[@model.PdfSourceRef],
  target : @model.PdfSourceRef,
) -> Bool {
  for r in refs {
    if same_source_ref(r, target) {
      return true
    }
  }
  false
}

///|
fn make_line_id(page_index : Int, line_index : Int) -> String {
  "p" + page_index.to_string() + "_line_" + line_index.to_string()
}

///|
fn merge_two_lines(
  page_index : Int,
  line_index : Int,
  left : @model.PdfTextLine,
  right : @model.PdfTextLine,
) -> @model.PdfTextLine {
  let spans = Array::new()
  for s in left.spans {
    spans.push(s)
  }
  for s in right.spans {
    spans.push(s)
  }

  let source_refs = collect_span_source_refs(spans)
  make_line_record(page_index, line_index, spans, true, source_refs)
}
