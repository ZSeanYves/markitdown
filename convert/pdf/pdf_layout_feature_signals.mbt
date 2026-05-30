///|
/// Internal non-text helpers for PDF layout feature extraction.
///
/// Feature key assembly stays in `pdf_layout_features.mbt`; text/content
/// signals live in `pdf_layout_text_signals.mbt`.
fn summarize_block_link_features(
  page : PdfConvertPage,
  block : PdfConvertBlock,
) -> PdfBlockLinkFeatureSummary {
  let lines = block_feature_lines(page, block)
  let line_overlap_ratios : Array[Double] = []
  for _line in lines {
    line_overlap_ratios.push(0.0)
  }

  let mut has_uri_target = false
  let mut has_internal_target = false
  let mut has_named_target = false

  for annotation in page.annotations {
    if !is_link_annotation_feature(annotation) {
      continue
    }

    let mut relevant = rect_distance(block._bbox, annotation._bbox) <= 8.0
    for i = 0; i < lines.length(); i = i + 1 {
      let ratio = annotation_line_overlap_ratio(annotation, lines[i])
      if ratio > 0.0 {
        relevant = true
      }
      if ratio > line_overlap_ratios[i] {
        line_overlap_ratios[i] = ratio
      }
    }
    if !relevant {
      continue
    }
    if has_uri_annotation_feature(annotation) {
      has_uri_target = true
    }
    if has_internal_annotation_feature(annotation) {
      has_internal_target = true
    }
    if has_named_annotation_feature(annotation) {
      has_named_target = true
    }
  }

  let mut max_overlap = 0.0
  let mut covered_chars = 0.0
  let mut total_chars = 0.0
  for i = 0; i < lines.length(); i = i + 1 {
    let line_text_len = max_feature_f64(lines[i].text.length().to_double(), 1.0)
    total_chars += line_text_len
    covered_chars += line_text_len * line_overlap_ratios[i]
    if line_overlap_ratios[i] > max_overlap {
      max_overlap = line_overlap_ratios[i]
    }
  }
  if total_chars <= 0.0 {
    total_chars = max_feature_f64(block.text.length().to_double(), 1.0)
  }
  let coverage_ratio = min_feature_f64(covered_chars / total_chars, 1.0)
  let toc_like_anchor = toc_like_anchor_signal(block.text)
  let page_number_like = looks_like_page_number_signal(block.text)
  let paragraph_url_context = (
      contains_url_signal(block.text) || contains_email_signal(block.text)
    ) &&
    (
      count_feature_words(block.text) >= 8 ||
      has_terminal_period_signal(block.text) ||
      contains_clause_punctuation_signal(block.text) ||
      ends_with_colon_signal(block.text)
    )
  let target_kind_count = (if has_uri_target { 1 } else { 0 }) +
    (if has_internal_target { 1 } else { 0 }) +
    (if has_named_target { 1 } else { 0 })

  {
    overlap_ratio: max_overlap,
    text_coverage_ratio: coverage_ratio,
    has_partial_link: coverage_ratio >= 0.10 && coverage_ratio < 0.80,
    is_link_only_candidate: coverage_ratio >= 0.80 &&
    (
      toc_like_anchor ||
      page_number_like ||
      (!paragraph_url_context && count_feature_words(block.text) <= 4)
    ),
    has_uri_target,
    has_internal_target,
    has_named_target,
    has_mixed_target: target_kind_count >= 2,
  }
}

///|
fn block_feature_lines(
  page : PdfConvertPage,
  block : PdfConvertBlock,
) -> Array[PdfConvertLine] {
  let out : Array[PdfConvertLine] = []
  for line in page.lines {
    if line.line_index >= block.line_start && line.line_index <= block.line_end {
      out.push(line)
    }
  }
  out
}

///|
fn count_feature_words(text : String) -> Int {
  if text.trim() == "" {
    return 0
  }

  let mut count = 0
  for part in text.split(" ") {
    if part.trim() != "" {
      count += 1
    }
  }
  count
}

///|
fn digit_ratio(text : String) -> Double {
  char_ratio(text, fn(ch) { ch >= '0' && ch <= '9' })
}

///|
fn punctuation_ratio(text : String) -> Double {
  char_ratio(text, is_feature_punctuation)
}

///|
fn uppercase_ratio(text : String) -> Double {
  char_ratio(text, fn(ch) { ch >= 'A' && ch <= 'Z' })
}

///|
fn cjk_ratio(text : String) -> Double {
  char_ratio(text, is_feature_cjk)
}

///|
fn latin_ratio(text : String) -> Double {
  char_ratio(text, is_feature_latin)
}

///|
fn symbol_ratio(text : String) -> Double {
  char_ratio(text, is_feature_symbol)
}

///|
fn char_ratio(text : String, pred : (Char) -> Bool) -> Double {
  let chars = text.to_array()
  if chars.length() == 0 {
    return 0.0
  }

  let mut hits = 0
  for ch in chars {
    if pred(ch) {
      hits += 1
    }
  }
  hits.to_double() / chars.length().to_double()
}

///|
fn text_density(text : String, rect : @model.PdfRect) -> Double {
  let area = @model.rect_width(rect) * @model.rect_height(rect)
  if area <= 0.0 {
    return 0.0
  }
  text.length().to_double() / area
}

///|
fn is_feature_punctuation(ch : Char) -> Bool {
  ch == '.' ||
  ch == ',' ||
  ch == ':' ||
  ch == ';' ||
  ch == '!' ||
  ch == '?' ||
  ch == '-' ||
  ch == '(' ||
  ch == ')' ||
  ch == '[' ||
  ch == ']' ||
  ch == '{' ||
  ch == '}' ||
  ch == '"' ||
  ch == '\'' ||
  ch == '。' ||
  ch == '，' ||
  ch == '：' ||
  ch == '；' ||
  ch == '！' ||
  ch == '？'
}

///|
fn is_feature_latin(ch : Char) -> Bool {
  (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')
}

///|
fn is_feature_symbol(ch : Char) -> Bool {
  !(is_feature_latin(ch) ||
  is_feature_cjk(ch) ||
  (ch >= '0' && ch <= '9') ||
  is_feature_whitespace(ch) ||
  is_feature_punctuation(ch))
}

///|
fn is_feature_whitespace(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}

///|
fn is_feature_cjk(ch : Char) -> Bool {
  let v = ch.to_int()
  (v >= 0x4E00 && v <= 0x9FFF) ||
  (v >= 0x3400 && v <= 0x4DBF) ||
  (v >= 0x3040 && v <= 0x30FF) ||
  (v >= 0xAC00 && v <= 0xD7AF)
}

///|
fn rect_center_x_ratio(
  rect : @model.PdfRect,
  page_box : @model.PdfRect,
) -> Double {
  let width = @model.rect_width(page_box)
  if width <= 0.0 {
    return 0.0
  }
  ((rect.x0 + rect.x1) / 2.0 - page_box.x0) / width
}

///|
fn rect_center_y_ratio(
  rect : @model.PdfRect,
  page_box : @model.PdfRect,
) -> Double {
  let height = @model.rect_height(page_box)
  if height <= 0.0 {
    return 0.0
  }
  ((rect.y0 + rect.y1) / 2.0 - page_box.y0) / height
}

///|
fn top_ratio(rect : @model.PdfRect, page_box : @model.PdfRect) -> Double {
  let height = @model.rect_height(page_box)
  if height <= 0.0 {
    return 0.0
  }
  (page_box.y1 - rect.y1) / height
}

///|
fn bottom_ratio(rect : @model.PdfRect, page_box : @model.PdfRect) -> Double {
  let height = @model.rect_height(page_box)
  if height <= 0.0 {
    return 0.0
  }
  (rect.y0 - page_box.y0) / height
}

///|
fn page_edge_distance(
  rect : @model.PdfRect,
  page_box : @model.PdfRect,
) -> Double {
  let top = abs_feature_f64(page_box.y1 - rect.y1)
  let bottom = abs_feature_f64(rect.y0 - page_box.y0)
  let left = abs_feature_f64(rect.x0 - page_box.x0)
  let right = abs_feature_f64(page_box.x1 - rect.x1)
  min_feature_f64(min_feature_f64(top, bottom), min_feature_f64(left, right))
}

///|
fn nearest_annotation_distance(
  annotations : Array[PdfConvertAnnotation],
  rect : @model.PdfRect,
) -> Double? {
  nearest_filtered_annotation_distance(annotations, rect, fn(_annotation) {
    true
  })
}

///|
fn nearest_link_annotation_distance(
  annotations : Array[PdfConvertAnnotation],
  rect : @model.PdfRect,
) -> Double? {
  nearest_filtered_annotation_distance(
    annotations, rect, is_link_annotation_feature,
  )
}

///|
fn nearest_uri_annotation_distance(
  annotations : Array[PdfConvertAnnotation],
  rect : @model.PdfRect,
) -> Double? {
  nearest_filtered_annotation_distance(
    annotations, rect, has_uri_annotation_feature,
  )
}

///|
fn nearest_dest_annotation_distance(
  annotations : Array[PdfConvertAnnotation],
  rect : @model.PdfRect,
) -> Double? {
  nearest_filtered_annotation_distance(
    annotations, rect, has_dest_annotation_feature,
  )
}

///|
fn nearest_filtered_annotation_distance(
  annotations : Array[PdfConvertAnnotation],
  rect : @model.PdfRect,
  pred : (PdfConvertAnnotation) -> Bool,
) -> Double? {
  let mut best : Double? = None
  for annotation in annotations {
    if !pred(annotation) {
      continue
    }
    let distance = rect_distance(rect, annotation._bbox)
    match best {
      Some(prev) => if distance < prev { best = Some(distance) }
      None => best = Some(distance)
    }
  }
  best
}

///|
fn rect_distance(a : @model.PdfRect, b : @model.PdfRect) -> Double {
  let horizontal_gap = if a.x1 < b.x0 {
    b.x0 - a.x1
  } else if b.x1 < a.x0 {
    a.x0 - b.x1
  } else {
    0.0
  }
  let vertical_gap = if a.y1 < b.y0 {
    b.y0 - a.y1
  } else if b.y1 < a.y0 {
    a.y0 - b.y1
  } else {
    0.0
  }
  horizontal_gap + vertical_gap
}

///|
fn is_link_annotation_feature(annotation : PdfConvertAnnotation) -> Bool {
  let subtype = annotation.subtype.to_lower()
  subtype == "link" ||
  subtype == "/link" ||
  has_uri_annotation_feature(annotation) ||
  has_dest_annotation_feature(annotation)
}

///|
fn has_uri_annotation_feature(annotation : PdfConvertAnnotation) -> Bool {
  match annotation.uri {
    Some(uri) => uri.trim() != ""
    None => false
  }
}

///|
fn has_dest_annotation_feature(annotation : PdfConvertAnnotation) -> Bool {
  match annotation.dest {
    Some(dest) => dest.trim() != ""
    None => annotation.target_page is Some(_)
  }
}

///|
fn has_internal_annotation_feature(annotation : PdfConvertAnnotation) -> Bool {
  annotation.target_page is Some(_)
}

///|
fn has_named_annotation_feature(annotation : PdfConvertAnnotation) -> Bool {
  match annotation.dest {
    Some(dest) => dest.trim() != "" && annotation.target_page is None
    None => false
  }
}

///|
fn block_source_ref_count(block : PdfConvertBlock) -> Int {
  block.source_block_line_count
}

///|
fn page_median_font_size(page : PdfConvertPage) -> Double? {
  let values : Array[Double] = []
  for block in page.blocks {
    match block.dominant_font_size {
      Some(v) => if v > 0.0 { values.push(v) }
      None => ()
    }
  }
  if values.is_empty() {
    return None
  }
  values.sort()
  let mid = values.length() / 2
  if values.length() % 2 == 1 {
    Some(values[mid])
  } else {
    Some((values[mid - 1] + values[mid]) / 2.0)
  }
}

///|
fn relative_font_size(current : Double?, baseline : Double?) -> Double? {
  match (current, baseline) {
    (Some(value), Some(base)) =>
      if base > 0.0 {
        Some(value / base)
      } else {
        None
      }
    _ => None
  }
}

///|
fn bold_hint(block : PdfConvertBlock) -> Double {
  match block.dominant_font_name {
    Some(name) => if name.to_lower().contains("bold") { 1.0 } else { 0.0 }
    None => 0.0
  }
}

///|
fn has_rich_inline_payload(block : PdfConvertBlock) -> Bool {
  match block.rich_inlines {
    Some(inlines) => {
      if inlines.length() > 1 {
        return true
      }
      for inline in inlines {
        match inline {
          @cor.Inline::Text(_) => ()
          @cor.Inline::NoteRef(_) => return true
          _ => return true
        }
      }
      false
    }
    None => false
  }
}

///|
fn has_link_inline(block : PdfConvertBlock) -> Bool {
  match block.rich_inlines {
    Some(inlines) => {
      for inline in inlines {
        match inline {
          @cor.Inline::Link(_, _) => return true
          @cor.Inline::NoteRef(_) => ()
          _ => ()
        }
      }
      false
    }
    None => false
  }
}

///|
fn link_inline_count(block : PdfConvertBlock) -> Int {
  match block.rich_inlines {
    Some(inlines) => {
      let mut count = 0
      for inline in inlines {
        match inline {
          @cor.Inline::Link(_, _) => count += 1
          @cor.Inline::NoteRef(_) => ()
          _ => ()
        }
      }
      count
    }
    None => 0
  }
}

///|

///|
fn alignment_hint_value(value : String?) -> Double {
  match value {
    Some(raw) => {
      let v = raw.to_lower()
      if v == "left" {
        0.0
      } else if v == "center" {
        1.0
      } else if v == "right" {
        2.0
      } else if v == "justify" {
        3.0
      } else {
        -1.0
      }
    }
    None => -1.0
  }
}

///|
fn font_size_delta(current : Double?, neighbor : Double?) -> Double {
  match (current, neighbor) {
    (Some(a), Some(b)) => a - b
    _ => 0.0
  }
}

///|
fn effective_page_box_for_convert_page(page : PdfConvertPage) -> @model.PdfRect {
  match page.crop_box {
    Some(box) => box
    None =>
      match page.media_box {
        Some(box) => box
        None => { x0: 0.0, y0: 0.0, x1: 1.0, y1: 1.0 }
      }
  }
}

///|
fn bool_feature(v : Bool) -> Double {
  if v {
    1.0
  } else {
    0.0
  }
}

///|
fn abs_feature_f64(v : Double) -> Double {
  if v < 0.0 {
    -v
  } else {
    v
  }
}

///|
fn min_feature_f64(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn max_feature_f64(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}
