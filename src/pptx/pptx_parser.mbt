///|
/// PPTX parser
/// Strategy:
/// - resolve slide order from ppt/presentation.xml + rels
/// - read each slide xml
/// - extract text runs <a:t>...</a:t>
/// - classify slide paragraphs into heading / list item / paragraph
pub async fn parse_pptx(
  input_path : String,
  _out_dir : String,
  max_heading : Int,
) -> @cor.Document {
  let z = @cor.open_zip(input_path) catch {
    e => raise @cor.AppError("pptx: open zip failed: " + e.to_string())
  }

  let slides = list_slide_entries_in_presentation_order(z)
  let doc = @cor.new_document()

  if slides.length() == 0 {
    @cor.push(doc, @cor.Block::Paragraph("(no slides found)"))
    return doc
  }

  let mut idx = 1
  for path in slides {
    @cor.push(
      doc,
      @cor.Block::Heading(
        clamp_heading(2, max_heading),
        "Slide " + idx.to_string(),
      ),
    )

    let xml = read_zip_bytes(z, path)
    let paras = extract_slide_paragraphs(xml)
    let blocks = classify_slide_paragraphs(paras)

    if blocks.length() == 0 {
      @cor.push(doc, @cor.Block::Paragraph("(empty)"))
    } else {
      let mut prev_was_list = false

      for b in blocks {
        match b {
          PptxBlock::Heading(text) => {
            if prev_was_list {
              @cor.push(doc, @cor.Block::BlankLine)
            }
            @cor.push(
              doc,
              @cor.Block::Heading(clamp_heading(3, max_heading), text),
            )
            prev_was_list = false
          }
          PptxBlock::Paragraph(text) => {
            if prev_was_list {
              @cor.push(doc, @cor.Block::BlankLine)
            }
            @cor.push(doc, @cor.Block::Paragraph(text))
            prev_was_list = false
          }
          PptxBlock::ListItem(ordered, level, text) => {
            @cor.push(doc, @cor.Block::ListItem(ordered, level, text))
            prev_was_list = true
          }
        }
      }
    }

    @cor.push(doc, @cor.Block::BlankLine)
    idx = idx + 1
  }

  doc
}
