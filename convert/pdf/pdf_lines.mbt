///|
pub fn build_convert_pages_from_pdf_core(
  doc : @pdfc.PdfDocumentModel,
) -> Array[PdfConvertPage] {
  let pages = Array::new()

  for page in doc.pages {
    let lines = Array::new()
    for tb in page.text_blocks {
      let text = @pdfc.block_text(tb).trim().to_string()
      if text != "" {
        lines.push({
          page_index: page.page_index,
          text,
          is_heading_candidate: tb.is_heading_candidate,
          is_page_number_candidate: tb.is_page_number_candidate,
        })
      }
    }

    pages.push({
      page_index: page.page_index,
      lines,
      blocks: [],
    })
  }

  pages
}
