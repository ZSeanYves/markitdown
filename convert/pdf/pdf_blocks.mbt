///|
pub fn build_convert_blocks_for_pages(
  pages : Array[PdfConvertPage],
) -> Array[PdfConvertPage] {
  let out = Array::new()

  for page in pages {
    let blocks = Array::new()
    for line in page.lines {
      let kind = if line.is_page_number_candidate {
        PdfConvertBlockKind::Noise
      } else if line.is_heading_candidate {
        PdfConvertBlockKind::Heading
      } else {
        PdfConvertBlockKind::Paragraph
      }
      blocks.push({
        page_index: line.page_index,
        kind,
        text: line.text,
        heading_level: 1,
        line_count: 1,
      })
    }

    out.push({ page_index: page.page_index, lines: page.lines, blocks })
  }

  out
}
