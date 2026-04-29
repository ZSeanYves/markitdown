///|
fn debug_convert_document_summary(doc : PdfConvertDocument) -> String {
  let mut page_count = 0
  let mut line_count = 0
  let mut block_count = 0

  for page in doc.pages {
    page_count = page_count + 1
    line_count = line_count + page.lines.length()
    block_count = block_count + page.blocks.length()
  }

  "PdfConvertDocument(" +
  "pages=" +
  page_count.to_string() +
  ", " +
  "lines=" +
  line_count.to_string() +
  ", " +
  "blocks=" +
  block_count.to_string() +
  ")"
}

///|
fn debug_print_convert_lines(page : PdfConvertPage) -> Unit {
  println(
    "pdf_lines/debug page=" +
    page._page_index.to_string() +
    " convert_lines=" +
    page.lines.length().to_string(),
  )

  for line in page.lines {
    println(
      "  [line " +
      line.line_index.to_string() +
      "] text=\"" +
      line.text +
      "\"" +
      " font_size=" +
      opt_f64(line.font_size) +
      " font_name=" +
      opt_str(line.font_name) +
      " indent_left=" +
      opt_f64(line.indent_left) +
      " gap_before=" +
      opt_f64(line.line_gap_before) +
      " _bbox=" +
      rect_str(line._bbox),
    )
  }
}

///|
fn debug_print_convert_blocks(page : PdfConvertPage) -> Unit {
  println(
    "pdf_blocks/debug page=" +
    page._page_index.to_string() +
    " convert_blocks=" +
    page.blocks.length().to_string(),
  )

  for block in page.blocks {
    println(
      "  [block " +
      block.block_index.to_string() +
      "] kind=" +
      block_kind_str(block.kind) +
      " text=\"" +
      block.text +
      "\"" +
      " font_size=" +
      opt_f64(block.dominant_font_size) +
      " font_name=" +
      opt_str(block.dominant_font_name) +
      " source_block_index=" +
      block.source_block_index.to_string() +
      " source_block_line_count=" +
      block.source_block_line_count.to_string() +
      " source_block_kind=" +
      core_block_kind_str(block.source_block_kind) +
      " source_block_bbox=" +
      rect_str(block.source_block_bbox) +
      " core_flags=" +
      core_flags_str(block) +
      " dominant_language=" +
      opt_str(block.dominant_language) +
      " writing_direction=" +
      writing_direction_str(block.writing_direction) +
      " top_y=" +
      block.top_y.to_string() +
      " left_x=" +
      block.left_x.to_string() +
      " _bbox=" +
      rect_str(block._bbox),
    )
  }
}

///|
fn opt_f64(v : Double?) -> String {
  match v {
    Some(x) => x.to_string()
    None => "None"
  }
}

///|
fn opt_str(v : String?) -> String {
  match v {
    Some(x) => x
    None => "None"
  }
}

///|
fn rect_str(r : @model.PdfRect) -> String {
  "(" +
  r.x0.to_string() +
  "," +
  r.y0.to_string() +
  "," +
  r.x1.to_string() +
  "," +
  r.y1.to_string() +
  ")"
}

///|
fn block_kind_str(kind : PdfConvertBlockKind) -> String {
  match kind {
    PdfConvertBlockKind::Heading => "Heading"
    PdfConvertBlockKind::Paragraph => "Paragraph"
    PdfConvertBlockKind::Noise => "Noise"
  }
}

///|
fn core_block_kind_str(kind : @model.PdfTextBlockKind) -> String {
  match kind {
    @model.PdfTextBlockKind::Text => "Text"
    @model.PdfTextBlockKind::HeadingCandidate => "HeadingCandidate"
    @model.PdfTextBlockKind::ListCandidate => "ListCandidate"
    @model.PdfTextBlockKind::CaptionCandidate => "CaptionCandidate"
    @model.PdfTextBlockKind::HeaderFooterCandidate => "HeaderFooterCandidate"
    @model.PdfTextBlockKind::TableCellCandidate => "TableCellCandidate"
    @model.PdfTextBlockKind::FormulaCandidate => "FormulaCandidate"
    @model.PdfTextBlockKind::Unknown => "Unknown"
  }
}

///|
fn writing_direction_str(dir : @model.PdfWritingDirection) -> String {
  match dir {
    @model.PdfWritingDirection::LeftToRight => "LeftToRight"
    @model.PdfWritingDirection::RightToLeft => "RightToLeft"
    @model.PdfWritingDirection::TopToBottom => "TopToBottom"
    @model.PdfWritingDirection::BottomToTop => "BottomToTop"
    @model.PdfWritingDirection::Unknown => "Unknown"
  }
}

///|
fn core_flags_str(block : PdfConvertBlock) -> String {
  "heading=" +
  block.is_heading_candidate.to_string() +
  ",page=" +
  block.is_noise_candidate.to_string() +
  ",header=" +
  block.is_header_footer_candidate.to_string() +
  ",artifact=" +
  block.is_artifact_candidate.to_string() +
  ",caption=" +
  block.is_caption_candidate.to_string() +
  ",table=" +
  block.is_table_cell_candidate.to_string()
}

///|
/// 调试：打印每页首块/尾块，观察 repeated header/footer 候选。
fn debug_print_page_edge_blocks(doc : PdfConvertDocument) -> Unit {
  println("pdf_edges/debug pages=" + doc.pages.length().to_string())

  for page in doc.pages {
    println("  [page " + page._page_index.to_string() + "]")

    if page.blocks.is_empty() {
      println("    first=<none>")
      println("    last=<none>")
      continue
    }

    let first = page.blocks[0]
    let last = page.blocks[page.blocks.length() - 1]

    println("    first=" + edge_block_debug_str(first))
    println("    last=" + edge_block_debug_str(last))
  }
}

///|
fn edge_block_debug_str(block : PdfConvertBlock) -> String {
  let text = block.text.trim().to_owned()
  let short = if text.length() > 100 {
    text[:100].to_owned() + "..."
  } else {
    text
  }

  "{" +
  "kind=" +
  block_kind_str(block.kind) +
  ", text=\"" +
  short +
  "\"" +
  ", font_size=" +
  opt_f64(block.dominant_font_size) +
  ", font_name=" +
  opt_str(block.dominant_font_name) +
  ", top_y=" +
  block.top_y.to_string() +
  ", left_x=" +
  block.left_x.to_string() +
  ", line_count=" +
  block.line_count.to_string() +
  ", _bbox=" +
  rect_str(block._bbox) +
  "}"
}

///|
/// 调试：统计跨页重复出现的首尾块完整文本。
fn debug_print_repeated_edge_texts(doc : PdfConvertDocument) -> Unit {
  let edge_texts = Array::new()

  for page in doc.pages {
    if page.blocks.is_empty() {
      continue
    }

    let first = page.blocks[0].text.trim().to_owned()
    let last = page.blocks[page.blocks.length() - 1].text.trim().to_owned()

    if first != "" {
      edge_texts.push(first)
    }
    if last != "" {
      edge_texts.push(last)
    }
  }

  println("pdf_edges/repeated_texts")

  let printed = Array::new()

  for i = 0; i < edge_texts.length(); i = i + 1 {
    let cur = edge_texts[i]
    if cur == "" || array_contains_string(printed, cur) {
      continue
    }

    let mut count = 0
    for j = 0; j < edge_texts.length(); j = j + 1 {
      if edge_texts[j] == cur {
        count = count + 1
      }
    }

    if count >= 2 {
      let short = if cur.length() > 120 {
        cur[:120].to_owned() + "..."
      } else {
        cur
      }

      println("  count=" + count.to_string() + " text=\"" + short + "\"")
      printed.push(cur)
    }
  }
}

///|
/// 调试：打印看起来像 header/footer 的块。
fn debug_print_header_footer_like_blocks(doc : PdfConvertDocument) -> Unit {
  println("pdf_header_footer/debug")

  for page in doc.pages {
    println("  [page " + page._page_index.to_string() + "]")

    for block in page.blocks {
      if looks_like_debug_edge_noise_candidate(block) {
        println("    " + edge_block_debug_str(block))
      }
    }
  }
}

///|
fn looks_like_debug_edge_noise_candidate(block : PdfConvertBlock) -> Bool {
  let text = block.text.trim().to_owned()

  if text == "" {
    return false
  }

  // 页首/页尾 + 短块 优先关注
  if block.line_count <= 2 && text.length() <= 120 {
    if text.contains("Page ") ||
      text.contains("page ") ||
      text.contains("Report") ||
      text.contains("Draft") ||
      text.contains("Confidential") ||
      text.contains("Footer") ||
      text.contains("Internal Use") {
      return true
    }
  }

  false
}

///|
fn array_contains_string(arr : Array[String], value : String) -> Bool {
  for item in arr {
    if item == value {
      return true
    }
  }
  false
}
