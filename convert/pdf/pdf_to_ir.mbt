///|
fn pipeline_to_ir(
  input_path : String,
  out_dir : String,
  pages : Array[PdfConvertPage],
  blocks : Array[Array[PdfConvertBlock]],
  pipeline_debug : Bool,
) -> @cor.Document {
  if pipeline_debug {
    dump_pdf_debug_stage(input_path, out_dir, "lines", render_lines(pages))
    dump_pdf_debug_stage(input_path, out_dir, "blocks", render_blocks(blocks))
  }

  let doc = @cor.new_document()
  for page_blocks in blocks {
    for b in page_blocks {
      let t = b.text.trim().to_string()
      if t == "" {
        continue
      }

      if should_promote_to_heading(b) {
        let level = clamp_heading_level(b.heading_level)
        @cor.push(doc, @cor.Block::Heading(level, t))
      } else {
        @cor.push(doc, @cor.Block::Paragraph(t))
      }
    }
  }
  doc
}

///|
fn clamp_heading_level(level : Int) -> Int {
  if level <= 0 {
    1
  } else if level > 6 {
    6
  } else {
    level
  }
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
        PdfConvertBlockKind::Heading =>
          "heading(h" + b.heading_level.to_string() + ")"
        PdfConvertBlockKind::Paragraph => "paragraph"
      }
      out.push(
        "- " +
        kind +
        " [" +
        b.line_start.to_string() +
        "-" +
        b.line_end.to_string() +
        "] text=" +
        b.text,
      )
    }
    out.push("")
  }
  out.join("\n")
}

///|
fn should_promote_to_heading(b : PdfConvertBlock) -> Bool {
  if b.kind != PdfConvertBlockKind::Heading {
    return false
  }

  let t = b.text.trim().to_string()
  if t == "" {
    return false
  }

  // 第一阶段仅保留“非常高置信”的标题：
  // 1) markdown 标题标记
  // 2) 章节前缀（中英文）
  if t.has_prefix("#") {
    return true
  }
  if t.has_prefix("第") && (t.contains("章") || t.contains("节")) {
    return true
  }
  t.has_prefix("Chapter ") || t.has_prefix("CHAPTER ")
}
