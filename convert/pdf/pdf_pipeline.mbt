///|
fn native_document_events_to_blocks(
  native : @pdfc.PdfNativeDocumentResult,
) -> Array[Array[PdfConvertBlock]] {
  let pages = native_document_events_to_convert_pages(native)
  classify_convert_blocks(pages, convert_pages_to_blocks(pages))
}

///|
fn native_document_events_to_ir_document_with_debug(
  input_path : String,
  out_dir : String,
  native : @pdfc.PdfNativeDocumentResult,
  pipeline_debug : Bool,
) -> @cor.Document {
  let pages = native_document_events_to_convert_pages(native)
  let blocks = classify_convert_blocks(pages, convert_pages_to_blocks(pages))
  convert_blocks_to_ir_document_with_debug(input_path, out_dir, blocks, pipeline_debug)
}

///|
fn convert_blocks_to_ir_document_with_debug(
  input_path : String,
  out_dir : String,
  pages : Array[Array[PdfConvertBlock]],
  pipeline_debug : Bool,
) -> @cor.Document {
  let doc = @cor.new_document()

  if pipeline_debug {
    dump_pdf_debug_stage(
      input_path,
      out_dir,
      "native_blocks",
      render_native_convert_blocks(pages),
    )
  }

  for page_blocks in pages {
    for block in page_blocks {
      let t = block.text.trim().to_string()
      if t == "" {
        continue
      }
      match block.kind {
        PdfConvertBlockKind::Paragraph =>
          @cor.push(doc, @cor.Block::Paragraph(t))
        PdfConvertBlockKind::StandaloneLine =>
          @cor.push(doc, @cor.Block::Paragraph(t))
      }
    }
  }

  doc
}

///|
fn render_native_convert_blocks(pages : Array[Array[PdfConvertBlock]]) -> String {
  let out : Array[String] = []
  for page_blocks in pages {
    if page_blocks.length() == 0 {
      continue
    }
    let page_index = page_blocks[0].page_index
    out.push("## page " + page_index.to_string())
    let mut i = 0
    for block in page_blocks {
      i = i + 1
      let kind = match block.kind {
        PdfConvertBlockKind::Paragraph => "Paragraph"
        PdfConvertBlockKind::StandaloneLine => "StandaloneLine"
      }
      let flags = "h=" +
        block.is_heading_candidate.to_string() +
        " list=" +
        block.is_list_candidate.to_string() +
        " noise=" +
        block.is_noise_candidate.to_string() +
        " xpage=" +
        block.is_cross_page_continuation_candidate.to_string()
      out.push(
        i.to_string() +
        ". " +
        kind +
        " [" +
        block.line_start.to_string() +
        "-" +
        block.line_end.to_string() +
        "] " +
        flags +
        " " +
        block.text,
      )
    }
    out.push("")
  }
  out.join("\n")
}

///|
/// Compatibility fallback only: keep legacy text-first path available
/// for experimental modes and regressions.
fn pdf_convert_blocks_to_text_fallback(pages : Array[Array[PdfConvertBlock]]) -> String {
  let page_texts : Array[String] = []
  for page_blocks in pages {
    let block_texts : Array[String] = []
    for block in page_blocks {
      if block.text.trim() != "" {
        block_texts.push(block.text)
      }
    }
    if block_texts.length() > 0 {
      page_texts.push(block_texts.join("\n\n"))
    }
  }
  page_texts.join("\f")
}
