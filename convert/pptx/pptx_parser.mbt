///|
/// PPTX parser
/// Strategy:
/// - resolve slide order from ppt/presentation.xml + rels
/// - read each slide xml
/// - extract text runs <a:t>...</a:t>
/// - classify slide paragraphs into heading / list item / paragraph
pub fn parse_pptx(
  input_path : String,
  out_dir : String,
  max_heading : Int,
) -> @cor.Document raise {
  let p = open_pptx(input_path) catch {
    e => raise @cor.AppError("pptx: open package failed: " + e.to_string())
  }

  let slides = list_slide_entries_in_presentation_order(p)
  let doc = @cor.new_document()

  if slides.length() == 0 {
    @cor.push(doc, @cor.Block::Paragraph("(no slides found)"))
    return doc
  }

  let image_idx : Ref[Int] = { val: 0 }
  let src = @cor.basename(input_path)
  let mut idx = 1
  for path in slides {
    @cor.push_with_origin(
      doc,
      @cor.Block::Heading(
        clamp_heading(2, max_heading),
        "Slide " + idx.to_string(),
      ),
      Some({
        source_name: Some(src),
        page: None,
        slide: Some(idx),
        sheet: None,
        block_index: Some(doc.blocks.val.length()),
        heading_path: None,
      }),
    )

    let xml = p.read_bytes_required(path)
    let _ = build_slide_rel_context(p, path)
    let images = export_slide_images(p, path, xml, out_dir, idx, image_idx)

    for img in images {
      @cor.push_with_origin(
        doc,
        @cor.Block::ImageBlock({
          path: img._path,
          alt_text: Some(img._alt),
          title: None,
          caption: None,
          origin: Some({
            source_name: Some(src),
            page: None,
            slide: Some(idx),
            sheet: None,
            block_index: None,
            heading_path: None,
          }),
        }),
        Some({
          source_name: Some(src),
          page: None,
          slide: Some(idx),
          sheet: None,
          block_index: Some(doc.blocks.val.length()),
          heading_path: None,
        }),
      )
      @cor.set_asset_origin(doc, img._path, {
        source_name: Some(src),
        page: None,
        slide: Some(idx),
        sheet: None,
        origin_id: None,
        nearby_caption: None,
      })
    }

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
              @cor.push_with_origin(doc, @cor.Block::BlankLine, None)
            }
            @cor.push_with_origin(
              doc,
              @cor.Block::Heading(clamp_heading(3, max_heading), text),
              Some({
                source_name: Some(src),
                page: None,
                slide: Some(idx),
                sheet: None,
                block_index: Some(doc.blocks.val.length()),
                heading_path: None,
              }),
            )
            prev_was_list = false
          }
          PptxBlock::Paragraph(text) => {
            if prev_was_list {
              @cor.push_with_origin(doc, @cor.Block::BlankLine, None)
            }
            @cor.push_with_origin(
              doc,
              @cor.Block::Paragraph(text),
              Some({
                source_name: Some(src),
                page: None,
                slide: Some(idx),
                sheet: None,
                block_index: Some(doc.blocks.val.length()),
                heading_path: None,
              }),
            )
            prev_was_list = false
          }
          PptxBlock::ListItem(ordered, level, text) => {
            @cor.push_with_origin(
              doc,
              @cor.Block::ListItem(ordered, level, text),
              Some({
                source_name: Some(src),
                page: None,
                slide: Some(idx),
                sheet: None,
                block_index: Some(doc.blocks.val.length()),
                heading_path: None,
              }),
            )
            prev_was_list = true
          }
        }
      }
    }

    @cor.push_with_origin(doc, @cor.Block::BlankLine, None)
    idx = idx + 1
  }

  doc
}
