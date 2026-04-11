///|
fn native_document_to_ir_document_with_debug(
  input_path : String,
  out_dir : String,
  native : @pdfc.PdfNativeDocumentResult,
  pipeline_debug : Bool,
) -> @cor.Document {
  let pages = native_document_events_to_convert_pages(native)
  let raw_blocks = convert_pages_to_blocks(pages)
  let classified = classify_convert_blocks(pages, raw_blocks)
  let merged = merge_classified_blocks(classified)

  if pipeline_debug {
    dump_pdf_debug_stage(
      input_path,
      out_dir,
      "native_blocks_raw",
      render_pdf_convert_blocks(raw_blocks),
    )
    dump_pdf_debug_stage(
      input_path,
      out_dir,
      "native_blocks_classified",
      render_pdf_convert_blocks(classified),
    )
    dump_pdf_debug_stage(
      input_path,
      out_dir,
      "native_blocks_merged",
      render_pdf_convert_blocks([merged]),
    )
    dump_pdf_debug_stage(
      input_path,
      out_dir,
      "native_pipeline_summary",
      render_pipeline_summary(raw_blocks, classified, merged),
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
        " reason=" +
        block.noise_reason.unwrap_or("-") +
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

///|
fn render_pipeline_summary(
  raw_pages : Array[Array[PdfConvertBlock]],
  classified_pages : Array[Array[PdfConvertBlock]],
  merged_blocks : Array[PdfConvertBlock],
) -> String {
  let out : Array[String] = []
  out.push("== page stats ==")

  let mut i = 0
  while i < raw_pages.length() && i < classified_pages.length() {
    let raw = raw_pages[i]
    let cls = classified_pages[i]

    let mut noise_n = 0
    for b in cls {
      if b.is_noise {
        noise_n = noise_n + 1
      }
    }

    out.push(
      "page " +
      i.to_string() +
      ": raw=" +
      raw.length().to_string() +
      " classified=" +
      cls.length().to_string() +
      " noise_marked=" +
      noise_n.to_string() +
      " kept=" +
      (cls.length() - noise_n).to_string(),
    )
    i = i + 1
  }

  out.push("")
  out.push("== merged result ==")
  out.push("merged_total=" + merged_blocks.length().to_string())
  let mut j = 0
  for b in merged_blocks {
    j = j + 1
    out.push(
      j.to_string() +
      ". page=" +
      b.page_index.to_string() +
      " range=" +
      b.line_start.to_string() +
      "-" +
      b.line_end.to_string() +
      " text=" +
      debug_line_preview(b.text),
    )
  }
  out.join("\n")
}
