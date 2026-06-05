///|
/// Line-level geometry and paragraph-continuation rules for PDF text cleanup.
///
/// These helpers are shared by line merge and block grouping while the main
/// `pdf_text_rules.mbt` file keeps the higher-level text-flow decisions.
fn line_vertical_distance_close(
  left : @model.PdfTextLine,
  right : @model.PdfTextLine,
) -> Bool {
  match line_bbox_vertical_gap(left, right) {
    Some(gap) => gap <= line_vertical_gap_threshold(left, right)
    None =>
      match (left.baseline_y, right.baseline_y) {
        (Some(a), Some(b)) =>
          abs_double_rule(a - b) <=
          line_vertical_baseline_threshold(left, right)
        _ => true
      }
  }
}

///|
fn line_bbox_vertical_gap(
  left : @model.PdfTextLine,
  right : @model.PdfTextLine,
) -> Double? {
  if !@model.is_rect_valid(left.bbox) || !@model.is_rect_valid(right.bbox) {
    return None
  }

  let overlap_top = if left.bbox.y1 < right.bbox.y1 {
    left.bbox.y1
  } else {
    right.bbox.y1
  }
  let overlap_bottom = if left.bbox.y0 > right.bbox.y0 {
    left.bbox.y0
  } else {
    right.bbox.y0
  }

  if overlap_top > overlap_bottom {
    return Some(0.0)
  }

  if left.bbox.y0 > right.bbox.y1 {
    return Some(left.bbox.y0 - right.bbox.y1)
  }

  if right.bbox.y0 > left.bbox.y1 {
    return Some(right.bbox.y0 - left.bbox.y1)
  }

  Some(0.0)
}

///|
fn line_vertical_gap_threshold(
  left : @model.PdfTextLine,
  right : @model.PdfTextLine,
) -> Double {
  line_vertical_reference_height(left, right) * 0.8
}

///|
fn line_vertical_baseline_threshold(
  left : @model.PdfTextLine,
  right : @model.PdfTextLine,
) -> Double {
  line_vertical_reference_height(left, right) * 1.8
}

///|
fn line_vertical_reference_height(
  left : @model.PdfTextLine,
  right : @model.PdfTextLine,
) -> Double {
  match (left.line_height, right.line_height) {
    (Some(a), Some(b)) => if a > b { a } else { b }
    (Some(a), None) => a
    (None, Some(b)) => b
    (None, None) => 12.0
  }
}

///|
fn lines_look_like_same_paragraph(
  left : @model.PdfTextLine,
  right : @model.PdfTextLine,
) -> Bool {
  if !line_font_size_close(left, right) {
    return false
  }

  if !line_indent_close(left, right) {
    return false
  }

  if !line_gap_paragraph_like(left) {
    return false
  }

  if looks_like_heading_line(@model.line_text(left).trim().to_owned()) ||
    looks_like_heading_line(@model.line_text(right).trim().to_owned()) {
    return false
  }

  if !line_vertical_distance_close(left, right) {
    return false
  }

  true
}

///|
fn line_font_size_close(
  left : @model.PdfTextLine,
  right : @model.PdfTextLine,
) -> Bool {
  match (line_dominant_font_size(left), line_dominant_font_size(right)) {
    (Some(a), Some(b)) => abs_double_rule(a - b) <= 0.75
    _ => true
  }
}

///|
fn line_indent_close(
  left : @model.PdfTextLine,
  right : @model.PdfTextLine,
) -> Bool {
  match (left.indent_left, right.indent_left) {
    (Some(a), Some(b)) => abs_double_rule(a - b) <= 8.0
    _ => true
  }
}

///|
fn line_gap_paragraph_like(left : @model.PdfTextLine) -> Bool {
  match (left.line_gap_after, left.line_height) {
    (Some(g), Some(h)) => g <= h * 0.7
    _ => true
  }
}

///|
fn lines_have_tight_fragment_continuation(
  left : @model.PdfTextLine,
  right : @model.PdfTextLine,
) -> Bool {
  line_font_size_close(left, right) &&
  line_indent_close(left, right) &&
  line_vertical_distance_close(left, right) &&
  line_gap_paragraph_like(left)
}

///|
fn line_dominant_font_size(line : @model.PdfTextLine) -> Double? {
  if line.spans.is_empty() {
    return None
  }

  let mut best = 0.0
  let mut seen = false
  for span in line.spans {
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
fn looks_like_cross_column_pair(
  left : @model.PdfTextLine,
  right : @model.PdfTextLine,
) -> Bool {
  if !line_vertical_distance_close(left, right) {
    return false
  }

  let lx0 = left.bbox.x0
  let lx1 = left.bbox.x1
  let rx0 = right.bbox.x0
  let rx1 = right.bbox.x1

  let gap_lr = rx0 - lx1
  let gap_rl = lx0 - rx1

  let horizontal_gap = if gap_lr > 0.0 {
    gap_lr
  } else if gap_rl > 0.0 {
    gap_rl
  } else {
    0.0
  }

  let ref_h = match (left.line_height, right.line_height) {
    (Some(a), Some(b)) => if a > b { a } else { b }
    (Some(a), None) => a
    (None, Some(b)) => b
    (None, None) => 12.0
  }

  let indent_far = match (left.indent_left, right.indent_left) {
    (Some(a), Some(b)) => abs_double_rule(a - b) >= ref_h * 3.0
    _ => false
  }

  horizontal_gap >= ref_h * 2.5 || indent_far
}
