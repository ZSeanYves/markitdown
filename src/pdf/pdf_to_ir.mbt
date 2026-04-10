///|
/// Convert plain text into IR.
/// New strategy:
/// - Normalize line endings
/// - Split pages by formfeed \f
/// - Detect repeated header/footer noise across pages
/// - Strip page-level noise page by page
/// - Merge cleaned pages with an internal page-break marker
/// - Recover blocks once on the merged text
fn text_to_ir_document(text0 : String) -> @cor.Document {
  text_to_ir_document_with_debug("", "", text0, false)
}

///|
fn text_to_ir_document_with_debug(
  input_path : String,
  out_dir : String,
  text0 : String,
  pipeline_debug : Bool,
) -> @cor.Document {
  let text = @cor.normalize_text(text0)
  let doc = @cor.new_document()

  let pages : Array[String] = []
  for page_sv in text.split("\f") {
    let page = page_sv.to_string()
    if page.trim() != "" {
      pages.push(page)
    }
  }

  if pages.length() == 0 {
    return doc
  }

  if pipeline_debug {
    dump_pdf_debug_stage(
      input_path,
      out_dir,
      "01_page_split",
      render_debug_pages("page_split", pages),
    )
  }

  let (head_keys, tail_keys) = detect_repeated_page_noise(pages)

  if pipeline_debug {
    let repeated_clean_pages : Array[String] = []
    for page in pages {
      repeated_clean_pages.push(
        strip_page_repeated_noise_only(page, head_keys, tail_keys),
      )
    }
    dump_pdf_debug_stage(
      input_path,
      out_dir,
      "02_repeated_cleanup",
      render_debug_pages("repeated_cleanup", repeated_clean_pages),
    )
  }

  let clean_pages : Array[String] = []
  let mut _page_idx = 0
  for page in pages {
    let clean_page = strip_page_noise(page, head_keys, tail_keys)
    if clean_page.trim() != "" {
      clean_pages.push(clean_page)

      //println("[pdf-cross-debug] clean page " + page_idx.to_string())
      let mut shown = 0
      for sv in clean_page.split("\n") {
        let line = sv.to_string().trim().to_string()
        if line != "" {
          //println("[pdf-cross-debug]   " + line)
          shown += 1
          if shown >= 8 {
            break
          }
        }
      }
    }
    _page_idx += 1
  }

  if pipeline_debug {
    dump_pdf_debug_stage(
      input_path,
      out_dir,
      "03_page_noise_cleanup",
      render_debug_pages("page_noise_cleanup", clean_pages),
    )
  }

  let blocks_before_merge : Array[PdfBlock] = []
  for page in clean_pages {
    for b in split_blocks_smart(page) {
      blocks_before_merge.push(b)
    }
  }
  if pipeline_debug {
    dump_pdf_debug_stage(
      input_path,
      out_dir,
      "04_blocks_before_cross_page_merge",
      render_pdf_blocks(blocks_before_merge),
    )
  }

  let merged = merge_clean_pages_with_breaks(clean_pages)
  //println("[pdf-cross-debug] merged preview")
  let mut shown = 0
  for sv in merged.split("\n") {
    let line = sv.to_string().trim().to_string()
    if line != "" {
      //println("[pdf-cross-debug]   " + line)
      shown += 1
      if shown >= 15 {
        break
      }
    }
  }

  let blocks_after_merge = split_blocks_smart(merged)
  if pipeline_debug {
    dump_pdf_debug_stage(
      input_path,
      out_dir,
      "05_blocks_after_cross_page_merge",
      render_pdf_blocks(blocks_after_merge),
    )
  }

  let mut first_block = true
  for b in blocks_after_merge {
    if !first_block {
      @cor.push(doc, @cor.Block::BlankLine)
    } else {
      first_block = false
    }

    match b {
      PdfBlock::Heading(level, text) =>
        @cor.push(doc, @cor.Block::Heading(level, text))
      PdfBlock::Paragraph(text) => @cor.push(doc, @cor.Block::Paragraph(text))
      PdfBlock::ListItem(ordered, level, text) =>
        @cor.push(doc, @cor.Block::ListItem(ordered, level, text))
    }
  }

  doc
}

///|
fn render_debug_pages(title : String, pages : Array[String]) -> String {
  let out : Array[String] = []
  out.push("# " + title)
  let mut i = 0
  for page in pages {
    i += 1
    out.push("")
    out.push("## page " + i.to_string())
    out.push(page)
  }
  out.join("\n")
}

///|
fn render_pdf_blocks(blocks : Array[PdfBlock]) -> String {
  let out : Array[String] = []
  let mut i = 0
  for b in blocks {
    i += 1
    match b {
      PdfBlock::Heading(level, text) =>
        out.push(i.to_string() + ". Heading(" + level.to_string() + "): " + text)
      PdfBlock::Paragraph(text) => out.push(i.to_string() + ". Paragraph: " + text)
      PdfBlock::ListItem(ordered, level, text) =>
        out.push(
          i.to_string() +
          ". ListItem(" +
          (if ordered { "ordered" } else { "unordered" }) +
          ", level=" +
          level.to_string() +
          "): " +
          text,
        )
    }
  }
  out.join("\n")
}
