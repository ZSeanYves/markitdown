///|
priv enum PdfResolvedKind {
  Skip
  Heading(Int)
  Paragraph
}

///|
priv struct PdfResolvedBlock {
  block : PdfConvertBlock
  kind : PdfResolvedKind
  decision : String
}

///|
priv struct PdfPhaseB1FlowResult {
  blocks : Array[PdfConvertBlock]
  logs : Array[String]
}

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

  let phase_b1 = apply_phase_b1_block_flow(pages)
  let resolved = resolve_blocks_for_ir(phase_b1.blocks)

  if pipeline_debug {
    dump_pdf_debug_stage(
      input_path,
      out_dir,
      "native_blocks_phase_b1_flow",
      phase_b1.logs.join("\n"),
    )
    dump_pdf_debug_stage(
      input_path,
      out_dir,
      "native_blocks_phase_b1",
      render_resolved_blocks(resolved),
    )
  }

  for item in resolved {
    let t = item.block.text.trim().to_string()
    if t == "" {
      continue
    }
    match item.kind {
      PdfResolvedKind::Skip => ()
      PdfResolvedKind::Heading(level) =>
        @cor.push(doc, @cor.Block::Heading(level, t))
      PdfResolvedKind::Paragraph =>
        @cor.push(doc, @cor.Block::Paragraph(t))
    }
  }

  doc
}

///|
fn apply_phase_b1_block_flow(
  pages : Array[Array[PdfConvertBlock]],
) -> PdfPhaseB1FlowResult {
  let logs : Array[String] = []
  let filtered_pages : Array[Array[PdfConvertBlock]] = []
  for page_blocks in pages {
    let filtered : Array[PdfConvertBlock] = []
    for block in page_blocks {
      if !is_high_confidence_noise_block(block) {
        filtered.push(block)
      } else {
        logs.push(
          "noise_filtered page=" +
          block.page_index.to_string() +
          " range=" +
          block.line_start.to_string() +
          "-" +
          block.line_end.to_string() +
          " text=" +
          debug_line_preview(block.text),
        )
      }
    }
    filtered_pages.push(filtered)
  }

  let flat : Array[PdfConvertBlock] = []
  for page_blocks in filtered_pages {
    for block in page_blocks {
      if flat.length() == 0 {
        flat.push(block)
        continue
      }

      let prev = flat[flat.length() - 1]
      if prev.page_index != block.page_index &&
        should_merge_cross_page_blocks(prev, block) {
        logs.push(
          "cross_page_merged prev_page=" +
          prev.page_index.to_string() +
          " next_page=" +
          block.page_index.to_string() +
          " prev_text=" +
          debug_line_preview(prev.text) +
          " next_text=" +
          debug_line_preview(block.text),
        )
        flat[flat.length() - 1] = merge_cross_page_blocks(prev, block)
      } else {
        flat.push(block)
      }
    }
  }

  { blocks: flat, logs }
}

///|
fn is_high_confidence_noise_block(block : PdfConvertBlock) -> Bool {
  if !block.is_noise_candidate {
    return false
  }

  let t = block.text.trim().to_string()
  is_probable_page_number(t) || (block.char_count <= 3 && block.line_count == 1)
}

///|
fn should_merge_cross_page_blocks(
  prev : PdfConvertBlock,
  next : PdfConvertBlock,
) -> Bool {
  prev.is_cross_page_continuation_candidate &&
  !next.is_heading_candidate &&
  !next.is_list_candidate &&
  !next.is_noise_candidate &&
  !ends_like_sentence(prev.text.trim().to_string())
}

///|
fn merge_cross_page_blocks(
  prev : PdfConvertBlock,
  next : PdfConvertBlock,
) -> PdfConvertBlock {
  let merged_text = append_line(
    prev.text.trim().to_string(),
    next.text.trim().to_string(),
  )
  {
    kind: PdfConvertBlockKind::Paragraph,
    text: merged_text,
    page_index: prev.page_index,
    line_start: prev.line_start,
    line_end: prev.line_end,
    line_count: prev.line_count + next.line_count,
    char_count: text_len(merged_text),
    is_heading_candidate: false,
    is_list_candidate: false,
    is_noise_candidate: false,
    is_cross_page_continuation_candidate: false,
  }
}

///|
fn resolve_blocks_for_ir(blocks : Array[PdfConvertBlock]) -> Array[PdfResolvedBlock] {
  let out : Array[PdfResolvedBlock] = []
  for block in blocks {
    if is_high_confidence_heading_block(block) {
      out.push({
        block,
        kind: PdfResolvedKind::Heading(2),
        decision: "emit_heading",
      })
    } else {
      out.push({
        block,
        kind: PdfResolvedKind::Paragraph,
        decision: "emit_paragraph",
      })
    }
  }
  out
}

///|
fn is_high_confidence_heading_block(block : PdfConvertBlock) -> Bool {
  if !block.is_heading_candidate ||
    block.is_list_candidate ||
    block.is_noise_candidate {
    return false
  }

  let t = block.text.trim().to_string()
  block.char_count <= 60 &&
  block.line_count <= 2 &&
  !looks_like_sentence_line(t) &&
  (looks_like_section_marker_line(t) || is_strong_heading_candidate(t))
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
        debug_line_preview(block.text),
      )
    }
    out.push("")
  }
  out.join("\n")
}

///|
fn render_resolved_blocks(blocks : Array[PdfResolvedBlock]) -> String {
  let out : Array[String] = []
  let mut i = 0
  for item in blocks {
    i = i + 1
    let kind = match item.kind {
      PdfResolvedKind::Skip => "Skip"
      PdfResolvedKind::Heading(level) => "Heading(" + level.to_string() + ")"
      PdfResolvedKind::Paragraph => "Paragraph"
    }
    out.push(
      i.to_string() +
      ". page=" +
      item.block.page_index.to_string() +
      " kind=" +
      kind +
      " decision=" +
      item.decision +
      " flags[h=" +
      item.block.is_heading_candidate.to_string() +
      " list=" +
      item.block.is_list_candidate.to_string() +
      " noise=" +
      item.block.is_noise_candidate.to_string() +
      " xpage=" +
      item.block.is_cross_page_continuation_candidate.to_string() +
      "] text=" +
      debug_line_preview(item.block.text),
    )
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
