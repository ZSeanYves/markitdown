///|
/// 从 pdf_core 的 PdfDocumentModel 构建 convert line 文档。
pub fn build_convert_lines(doc : @model.PdfDocumentModel) -> PdfConvertDocument {
  let pages = Array::new()

  for page in doc.pages {
    pages.push(build_convert_page_lines(page))
  }

  { pages, }
}

///|
pub fn build_convert_page_lines(page : @model.PdfPageModel) -> PdfConvertPage {
  let lines = Array::new()
  let mut line_index = 0

  for block_index = 0
      block_index < page.text_blocks.length()
      block_index = block_index + 1 {
    let block = page.text_blocks[block_index]

    for line in block.lines {
      let text = @model.line_text(line).trim().to_string()
      if text == "" {
        continue
      }

      lines.push(
        core_line_to_convert_line(
          page.page_index,
          line_index,
          block_index,
          block,
          line,
        ),
      )
      line_index = line_index + 1
    }
  }

  { page_index: page.page_index, lines, blocks: [] }
}

///|
fn core_line_to_convert_line(
  page_index : Int,
  line_index : Int,
  source_block_index : Int,
  block : @model.PdfTextBlock,
  line : @model.PdfTextLine,
) -> PdfConvertLine {
  let raw_text = @model.line_text(line)
  let text = raw_text.trim().to_string()

  {
    page_index,
    line_index,
    text,
    source_block_index,
    is_heading_candidate: block.is_heading_candidate,
    is_page_number_candidate: block.is_page_number_candidate,
    bbox: line.bbox,
    font_size: pick_line_font_size(line),
    font_name: pick_line_font_name(line),
    indent_left: line.indent_left,
    line_gap_before: line.line_gap_before,
    line_gap_after: line.line_gap_after,
  }
}

///|
fn pick_line_font_size(line : @model.PdfTextLine) -> Double? {
  let mut best : Double? = None
  for span in line.spans {
    match span.font_size {
      Some(sz) =>
        match best {
          Some(cur) => if sz > cur { best = Some(sz) }
          None => best = Some(sz)
        }
      None => ()
    }
  }
  best
}

///|
fn pick_line_font_name(line : @model.PdfTextLine) -> String? {
  for span in line.spans {
    match span.font_name {
      Some(name) => return Some(name)
      None => ()
    }
  }
  None
}
