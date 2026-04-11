///|
fn native_document_to_ir_document_with_debug(
  input_path : String,
  out_dir : String,
  native : @pdfc.PdfNativeDocumentResult,
  pipeline_debug : Bool,
) -> @cor.Document {
  let pages = native_document_events_to_convert_pages(native)
  let blocks = convert_pages_to_blocks(pages)
  let classified = classify_convert_blocks(pages, blocks)
  let merged = merge_classified_blocks(classified)

  if pipeline_debug {
    dump_pdf_debug_stage(
      input_path,
      out_dir,
      "native_blocks",
      render_pdf_convert_blocks(classified),
    )
    dump_pdf_debug_stage(
      input_path,
      out_dir,
      "native_blocks_merged",
      render_pdf_convert_blocks([merged]),
    )
  }

  convert_blocks_to_ir_document(merged)
}

///|
fn convert_blocks_to_ir_document(blocks : Array[PdfConvertBlock]) -> @cor.Document {
  let doc = @cor.new_document()

  for block in blocks {
    let t = block.text.trim().to_string()
    if t == "" {
      continue
    }

    if block.kind == PdfConvertBlockKind::Heading {
      @cor.push(doc, @cor.Block::Heading(2, t))
    } else {
      @cor.push(doc, @cor.Block::Paragraph(t))
    }
  }

  doc
}

///|
fn render_pdf_convert_blocks(pages : Array[Array[PdfConvertBlock]]) -> String {
  let out : Array[String] = []
  for page_blocks in pages {
    if page_blocks.length() == 0 {
      continue
    }

    out.push("## page " + page_blocks[0].page_index.to_string())
    let mut i = 0
    for block in page_blocks {
      i = i + 1
      let kind = match block.kind {
        PdfConvertBlockKind::Heading => "Heading"
        PdfConvertBlockKind::Paragraph => "Paragraph"
      }

      out.push(
        i.to_string() +
        ". " +
        kind +
        " [" +
        block.line_start.to_string() +
        "-" +
        block.line_end.to_string() +
        "] noise=" +
        block.is_noise.to_string() +
        " xpage=" +
        block.is_cross_page_continuation_candidate.to_string() +
        " text=" +
        debug_line_preview(block.text),
      )
    }
    out.push("")
  }

  out.join("\n")
}
