///|
/// 从 convert line 文档构建 convert block 文档。
pub fn build_convert_blocks(doc : PdfConvertDocument) -> PdfConvertDocument {
  let pages = Array::new()

  for page in doc.pages {
    pages.push(build_convert_page_blocks(page))
  }

  { pages, }
}

///|
/// 从单页 convert lines 构建 convert blocks。
///
/// 第一阶段非常保守：
/// - 一条 line 先映成一个 block
/// - heading candidate -> Heading
/// - page number candidate -> Noise
/// - 其他 -> Paragraph
pub fn build_convert_page_blocks(page : PdfConvertPage) -> PdfConvertPage {
  let blocks = Array::new()

  for i = 0; i < page.lines.length(); i = i + 1 {
    blocks.push(make_block_from_line(page.page_index, i, page.lines[i]))
  }

  { page_index: page.page_index, lines: page.lines, blocks }
}

///|
fn make_block_from_line(
  page_index : Int,
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
    page_index,
    block_index,
    kind,
    text: line.text,
    line_start: line.line_index,
    line_end: line.line_index,
    is_heading_candidate: line.is_heading_candidate,
    is_noise_candidate: line.is_page_number_candidate,
    bbox: line.bbox,
    dominant_font_size: line.font_size,
    dominant_font_name: line.font_name,
    top_y: line.bbox.y0,
    left_x: line.bbox.x0,
    line_count: 1,
  }
}
