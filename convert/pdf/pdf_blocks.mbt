///|
/// Line -> block staging.
///
/// This stage groups one-line seeds into block objects and interleaves images
/// into a shared page object stream. We do this before semantic recovery so
/// heading/caption heuristics can use unified local neighborhood context.
fn build_convert_blocks(doc : PdfConvertDocument) -> PdfConvertDocument {
  let pages = Array::new()

  for page in doc.pages {
    pages.push(build_convert_page_blocks(page))
  }

  { pages, }
}

///|
/// 从单页 convert lines 构建 convert blocks，并与图片按 _bbox 混排。
fn build_convert_page_blocks(page : PdfConvertPage) -> PdfConvertPage {
  let blocks = Array::new()

  for i = 0; i < page.lines.length(); i = i + 1 {
    blocks.push(make_block_from_line(page._page_index, i, page.lines[i]))
  }

  let objects = build_page_objects(blocks, page.images)

  {
    _page_index: page._page_index,
    media_box: page.media_box,
    crop_box: page.crop_box,
    lines: page.lines,
    blocks,
    images: page.images,
    annotations: page.annotations,
    objects,
  }
}

///|
fn make_block_from_line(
  _page_index : Int,
  block_index : Int,
  line : PdfConvertLine,
) -> PdfConvertBlock {
  let kind = if line.is_page_number_candidate {
    PdfConvertBlockKind::Noise
  } else if line.is_heading_candidate {
    PdfConvertBlockKind::Heading
  } else {
    PdfConvertBlockKind::Paragraph
  }

  {
    _page_index,
    block_index,
    kind,
    text: line.text,
    rich_inlines: None,
    line_start: line.line_index,
    line_end: line.line_index,
    source_block_index: line._source_block_index,
    source_block_line_count: line.source_block_line_count,
    source_block_kind: line.source_block_kind,
    source_block_bbox: line.source_block_bbox,
    source_block_dominant_font_size: line.source_block_dominant_font_size,
    source_block_dominant_font_name: line.source_block_dominant_font_name,
    is_heading_candidate: line.is_heading_candidate,
    is_noise_candidate: line.is_page_number_candidate,
    is_header_footer_candidate: line.is_header_footer_candidate,
    is_artifact_candidate: line.is_artifact_candidate,
    is_caption_candidate: line.is_caption_candidate,
    is_table_cell_candidate: line.is_table_cell_candidate,
    dominant_language: line.dominant_language,
    writing_direction: line.writing_direction,
    _bbox: line._bbox,
    dominant_font_size: line.font_size,
    dominant_font_name: line.font_name,
    top_y: line._bbox.y1,
    left_x: line._bbox.x0,
    line_count: 1,
    first_indent_left: line.indent_left,
    last_indent_left: line.indent_left,
    first_indent_right: line.indent_right,
    last_indent_right: line.indent_right,
    first_alignment_hint: line.alignment_hint,
    last_alignment_hint: line.alignment_hint,
    first_line_gap_before: line.line_gap_before,
    last_line_gap_after: line._line_gap_after,
    first_line_height: line.line_height,
    last_line_height: line.line_height,
    first_baseline_y: line.baseline_y,
    last_baseline_y: line.baseline_y,
    first_is_wrapped_candidate: line.is_wrapped_candidate,
    last_is_wrapped_candidate: line.is_wrapped_candidate,
    first_is_same_paragraph_with_prev_candidate: line.is_same_paragraph_with_prev_candidate,
    last_is_same_paragraph_with_prev_candidate: line.is_same_paragraph_with_prev_candidate,
  }
}

///|
fn build_page_objects(
  blocks : Array[PdfConvertBlock],
  images : Array[PdfConvertImage],
) -> Array[PdfConvertPageObject] {
  let out : Array[PdfConvertPageObject] = []

  for block in blocks {
    insert_page_object_sorted(out, PdfConvertPageObject::TextBlock(block))
  }

  for image in images {
    insert_page_object_sorted(out, PdfConvertPageObject::Image(image))
  }

  out
}

///|
fn insert_page_object_sorted(
  out : Array[PdfConvertPageObject],
  obj : PdfConvertPageObject,
) -> Unit {
  let inserted = Array::new()
  let mut placed = false

  for existing in out {
    if !placed && compare_page_object_layout(obj, existing) < 0 {
      inserted.push(obj)
      placed = true
    }
    inserted.push(existing)
  }

  if !placed {
    inserted.push(obj)
  }

  out.clear()
  for x in inserted {
    out.push(x)
  }
}

///|
/// 返回：
/// -1 => a 在前
///  0 => 相近
///  1 => b 在前
///
/// 规则：
/// - 先按 top_y 从大到小（PDF 坐标系里越大越靠上）
/// - 若 vertical 距离很小，按 left_x 从小到大
fn compare_page_object_layout(
  a : PdfConvertPageObject,
  b : PdfConvertPageObject,
) -> Int {
  let ay = page_object_top_y(a)
  let by = page_object_top_y(b)

  let dy = abs_f64(ay - by)
  if dy > 8.0 {
    if ay > by {
      return -1
    } else {
      return 1
    }
  }

  let ax = page_object_left_x(a)
  let bx = page_object_left_x(b)
  if ax < bx {
    return -1
  }
  if ax > bx {
    return 1
  }

  0
}

///|
fn page_object_top_y(obj : PdfConvertPageObject) -> Double {
  match obj {
    PdfConvertPageObject::TextBlock(block) => block.top_y
    PdfConvertPageObject::Image(image) => image.top_y
  }
}

///|
fn page_object_left_x(obj : PdfConvertPageObject) -> Double {
  match obj {
    PdfConvertPageObject::TextBlock(block) => block.left_x
    PdfConvertPageObject::Image(image) => image.left_x
  }
}

///|
fn abs_f64(v : Double) -> Double {
  if v < 0.0 {
    -v
  } else {
    v
  }
}
