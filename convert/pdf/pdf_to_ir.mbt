///|
fn pipeline_to_ir(
  input_path : String,
  out_dir : String,
  pages : Array[PdfConvertPage],
  raw_blocks : Array[Array[PdfConvertBlock]],
  classified_blocks : Array[Array[PdfConvertBlock]],
  merged_blocks : Array[PdfConvertBlock],
  pipeline_debug : Bool,
) -> @cor.Document {
  if pipeline_debug {
    dump_pdf_debug_stage(input_path, out_dir, "lines", render_lines(pages))
    dump_pdf_debug_stage(input_path, out_dir, "blocks_raw", render_blocks(raw_blocks))
    dump_pdf_debug_stage(input_path, out_dir, "blocks_classified", render_blocks(classified_blocks))
    dump_pdf_debug_stage(input_path, out_dir, "blocks_merged", render_blocks([merged_blocks]))
  }

  let doc = @cor.new_document()
  for b in merged_blocks {
    let t = b.text.trim().to_string()
    if t == "" {
      continue
    }

    match b.kind {
      PdfConvertBlockKind::Heading => @cor.push(doc, @cor.Block::Heading(2, t))
      PdfConvertBlockKind::ListItem => @cor.push(doc, @cor.Block::ListItem(b.list_ordered, b.list_level, t))
      PdfConvertBlockKind::Paragraph => @cor.push(doc, @cor.Block::Paragraph(t))
    }
  }
  doc
}

///|
fn render_lines(pages : Array[PdfConvertPage]) -> String {
  let out : Array[String] = []
  for p in pages {
    out.push("## page " + p.page_index.to_string())
    for line in p.lines {
      out.push(
        "- [" +
        line.line_index.to_string() +
        "] br=" +
        line.is_paragraph_break.to_string() +
        " text=" +
        line.text,
      )
    }
    out.push("")
  }
  out.join("\n")
}

///|
fn render_blocks(pages : Array[Array[PdfConvertBlock]]) -> String {
  let out : Array[String] = []
  for page_blocks in pages {
    if page_blocks.length() == 0 {
      continue
    }

    out.push("## page " + page_blocks[0].page_index.to_string())
    for b in page_blocks {
      let kind = match b.kind {
        PdfConvertBlockKind::Heading => "heading"
        PdfConvertBlockKind::ListItem => "list"
        PdfConvertBlockKind::Paragraph => "paragraph"
      }
      out.push(
        "- " +
        kind +
        " [" +
        b.line_start.to_string() +
        "-" +
        b.line_end.to_string() +
        "] noise=" +
        b.is_noise.to_string() +
        " xpage=" +
        b.is_cross_page_continuation_candidate.to_string() +
        " text=" +
        b.text,
      )
    }
    out.push("")
  }
  out.join("\n")
}
