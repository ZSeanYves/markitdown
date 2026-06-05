///|
pub fn convert_ocr_layout_page_to_ir(page : OcrLayoutPage) -> @cor.Document {
  convert_ocr_layout_pages_to_ir([page])
}

///|
pub fn convert_ocr_layout_pages_to_ir(
  pages : Array[OcrLayoutPage],
) -> @cor.Document {
  let doc = @cor.new_document()
  let mut emitted_blocks = 0

  for page in pages {
    let page_block_count_before = emitted_blocks
    for block in page.blocks {
      match
        convert_ocr_layout_block_to_ir(block, page.page_index, emitted_blocks) {
        Some((ir_block, origin)) => {
          @cor.push_with_origin(doc, ir_block, Some(origin))
          emitted_blocks += 1
        }
        None => ()
      }
    }

    let emitted_on_page = emitted_blocks - page_block_count_before
    if emitted_on_page == 0 && page.warnings.length() > 0 {
      let warning_text = render_ocr_layout_page_warnings(page.warnings)
      if warning_text != "" {
        let block_index = emitted_blocks
        @cor.push_with_origin(
          doc,
          @cor.Block::Paragraph(warning_text),
          Some(make_ocr_layout_origin(page.page_index, block_index, [])),
        )
        emitted_blocks += 1
      }
    }
  }

  doc
}

///|
pub fn convert_ocr_layout_block_to_ir(
  block : OcrLayoutBlock,
  page_index : Int,
  block_index : Int,
) -> (@cor.Block, @cor.Origin)? {
  let text = block.text.trim().to_owned()
  if text == "" {
    return None
  }

  match block.kind {
    OcrLayoutBlockKind::Noise => None
    _ => {
      let origin = make_ocr_layout_origin(
        page_index,
        block_index,
        block.line_indices,
      )
      let ir_block = match block.kind {
        OcrLayoutBlockKind::Paragraph => @cor.Block::Paragraph(text)
        OcrLayoutBlockKind::TableLike => @cor.Block::Paragraph(text)
        OcrLayoutBlockKind::Heading => @cor.Block::Heading(1, text)
        OcrLayoutBlockKind::ListItem => make_ocr_layout_list_ir_block(text)
        OcrLayoutBlockKind::Unknown => @cor.Block::Paragraph(text)
        OcrLayoutBlockKind::Noise => abort("noise already filtered")
      }
      Some((ir_block, origin))
    }
  }
}

///|
fn make_ocr_layout_origin(
  page_index : Int,
  block_index : Int,
  line_indices : Array[Int],
) -> @cor.Origin {
  let line_range = ocr_layout_line_range(line_indices)
  {
    source_name: None,
    page: Some(page_index + 1),
    slide: None,
    sheet: None,
    block_index: Some(block_index),
    heading_path: None,
    line_start: line_range.0,
    line_end: line_range.1,
    row_index: None,
    column_index: None,
    object_ref: None,
    relationship_id: None,
    key_path: None,
  }
}

///|
fn ocr_layout_line_range(line_indices : Array[Int]) -> (Int?, Int?) {
  if line_indices.length() == 0 {
    return (None, None)
  }

  let mut min_index = line_indices[0]
  let mut max_index = line_indices[0]
  for i in 1..<line_indices.length() {
    let index = line_indices[i]
    if index < min_index {
      min_index = index
    }
    if index > max_index {
      max_index = index
    }
  }
  (Some(min_index), Some(max_index))
}

///|
fn make_ocr_layout_list_ir_block(text : String) -> @cor.Block {
  if looks_numbered_list_marker_prefix(text) {
    @cor.Block::ListItem(true, 0, strip_list_marker_prefix(text))
  } else if looks_list_marker_prefix(text) {
    @cor.Block::ListItem(false, 0, strip_list_marker_prefix(text))
  } else {
    @cor.Block::ListItem(false, 0, text)
  }
}

///|
fn strip_list_marker_prefix(text : String) -> String {
  let trimmed = text.trim().to_owned()
  if trimmed.has_prefix("- ") ||
    trimmed.has_prefix("* ") ||
    trimmed.has_prefix("• ") {
    return trimmed[2:].trim().to_owned()
  }

  let chars = trimmed.to_array()
  if chars.length() >= 4 && (chars[0] == '(' || chars[0] == '（') {
    let mut i = 1
    while i < chars.length() && is_ascii_digit_for_list(chars[i]) {
      i = i + 1
    }
    if i < chars.length() && (chars[i] == ')' || chars[i] == '）') {
      i = i + 1
      if i < chars.length() && chars[i] == ' ' {
        return trimmed[i + 1:].trim().to_owned()
      }
    }
  }

  let mut i = 0
  while i < chars.length() && is_ascii_digit_for_list(chars[i]) {
    i = i + 1
  }
  if i > 0 && i < chars.length() && (chars[i] == '.' || chars[i] == ')') {
    i = i + 1
    if i < chars.length() && chars[i] == ' ' {
      return trimmed[i + 1:].trim().to_owned()
    }
  }

  trimmed
}

///|
fn render_ocr_layout_page_warnings(warnings : Array[String]) -> String {
  let nonblank : Array[String] = []
  for warning in warnings {
    let text = warning.trim().to_owned()
    if text != "" {
      nonblank.push(text)
    }
  }
  if nonblank.length() == 0 {
    ""
  } else {
    "(layout warnings omitted content: " + nonblank.join("; ") + ")"
  }
}
