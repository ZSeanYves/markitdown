///|
/// PPTX MVP parser
/// Strategy:
/// - list entries under ppt/slides/slide*.xml
/// - read each slide xml
/// - extract text runs <a:t>...</a:t>
/// - output as Heading + Paragraphs
pub async fn parse_pptx(
  input_path : String,
  _out_dir : String,
  max_heading : Int,
) -> @cor.Document {
  let z = @cor.open_zip(input_path) catch {
    e => raise @cor.AppError("pptx: open zip failed: " + e.to_string())
  }

  // find slides
  let slides = list_slide_entries(z)

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
    //println(".. pptx: reading " + path)
    let xml = read_zip_bytes(z, path)
    //println(".. pptx: read ok, len=" + xml.length().to_string())
    let paras = extract_slide_paragraphs(xml)
    if paras.length() == 0 {
      @cor.push(doc, @cor.Block::Paragraph("(empty)"))
    } else {
      for p in paras {
        if p.trim() != "" {
          @cor.push(doc, @cor.Block::Paragraph(p))
        }
      }
    }
    @cor.push(doc, @cor.Block::BlankLine)
    idx = idx + 1
  }

  doc
}
