///|
/// 页级 block 结果。
pub struct PdfPageBlocks {
  page_index : Int
  blocks : Array[@model.PdfTextBlock]
}

///|
/// 文档级 block 结果。
pub struct PdfDocumentBlocks {
  pages : Array[PdfPageBlocks]
}

///|
/// 从文档 lines 构建 blocks。
pub fn build_document_blocks(doc_lines : PdfDocumentLines) -> PdfDocumentBlocks {
  let pages = Array::new()
  for page in doc_lines.pages {
    pages.push(build_page_blocks(page))
  }
  { pages, }
}

///|
/// 从单页 lines 构建 blocks。
///
/// Phase-1 语义分块策略：
/// - heading 行单独成块
/// - page number 候选单独成块
/// - 连续正文行合并成 paragraph block
pub fn build_page_blocks(page_lines : PdfPageLines) -> PdfPageBlocks {
  let blocks = if page_lines.lines.is_empty() {
    []
  } else {
    build_blocks_from_lines(page_lines.page_index, page_lines.lines)
  }

  { page_index: page_lines.page_index, blocks }
}

///|
pub fn build_blocks_from_lines(
  page_index : Int,
  lines : Array[@model.PdfTextLine],
) -> Array[@model.PdfTextBlock] {
  if lines.is_empty() {
    return []
  }

  let out = Array::new()
  let mut block_index = 0

  for line in lines {
    let text = @model.line_text(line).trim().to_string()

    if text == "" {
      continue
    }

    if is_page_number_candidate_line(line) {
      out.push(make_page_number_block(page_index, block_index, [line]))
      block_index = block_index + 1
      continue
    }

    if is_heading_candidate_line(line) {
      out.push(make_heading_block(page_index, block_index, [line]))
      block_index = block_index + 1
      continue
    }

    out.push(make_paragraph_block(page_index, block_index, [line]))
    block_index = block_index + 1
  }

  out
}

///|
/// line 是否像标题候选。
fn is_heading_candidate_line(line : @model.PdfTextLine) -> Bool {
  let text = @model.line_text(line).trim().to_string()
  if text == "" {
    return false
  }
  looks_like_heading_line(text)
}

///|
/// line 是否像页码候选。
fn is_page_number_candidate_line(line : @model.PdfTextLine) -> Bool {
  let text = @model.line_text(line).trim().to_string()
  if text == "" {
    return false
  }
  is_page_number_candidate(text)
}

///|
/// 生成 paragraph block。
fn make_paragraph_block(
  page_index : Int,
  block_index : Int,
  lines : Array[@model.PdfTextLine],
) -> @model.PdfTextBlock {
  make_block(
    page_index,
    block_index,
    lines,
    @model.PdfTextBlockKind::Text,
    false,
    false,
  )
}

///|
/// 生成 heading block。
fn make_heading_block(
  page_index : Int,
  block_index : Int,
  lines : Array[@model.PdfTextLine],
) -> @model.PdfTextBlock {
  make_block(
    page_index,
    block_index,
    lines,
    @model.PdfTextBlockKind::HeadingCandidate,
    true,
    false,
  )
}

///|
/// 生成页码候选 block。
fn make_page_number_block(
  page_index : Int,
  block_index : Int,
  lines : Array[@model.PdfTextLine],
) -> @model.PdfTextBlock {
  make_block(
    page_index,
    block_index,
    lines,
    @model.PdfTextBlockKind::HeaderFooterCandidate,
    false,
    true,
  )
}

///|
/// 通用 block 构造。
fn make_block(
  page_index : Int,
  block_index : Int,
  lines : Array[@model.PdfTextLine],
  kind : @model.PdfTextBlockKind,
  is_heading_candidate : Bool,
  is_page_number_candidate : Bool,
) -> @model.PdfTextBlock {
  let bbox = @model.lines_bbox(lines).unwrap_or(default_rect())
  let source_refs = collect_line_source_refs(lines)

  {
    id: make_block_id(page_index, block_index),
    bbox,
    kind,
    rotation: None,
    dominant_font_name: dominant_font_name_of_lines(lines),
    dominant_font_size: dominant_font_size_of_lines(lines),
    dominant_language: None,
    writing_direction: infer_writing_direction2(lines),
    z_index: None,
    lines,
    is_heading_candidate,
    is_header_footer_candidate: is_page_number_candidate,
    is_page_number_candidate,
    is_table_cell_candidate: false,
    is_caption_candidate: false,
    is_artifact_candidate: false,
    source_refs,
  }
}

///|
/// 汇总 line 的 source refs，并去重。
fn collect_line_source_refs(
  lines : Array[@model.PdfTextLine],
) -> Array[@model.PdfSourceRef] {
  let out = Array::new()
  for line in lines {
    for src in line.source_refs {
      if !contains_source_ref(out, src) {
        out.push(src)
      }
    }
  }
  out
}

///|
/// 取第一条 line 的第一个 span 的 font_name 作为 dominant font。
fn dominant_font_name_of_lines(lines : Array[@model.PdfTextLine]) -> String? {
  if lines.is_empty() {
    return None
  }

  let first_line = lines[0]
  if first_line.spans.is_empty() {
    return None
  }

  first_line.spans[0].font_name
}

///|
/// 取第一条 line 的第一个 span 的 font_size 作为 dominant font size。
fn dominant_font_size_of_lines(lines : Array[@model.PdfTextLine]) -> Double? {
  if lines.is_empty() {
    return None
  }

  let first_line = lines[0]
  if first_line.spans.is_empty() {
    return None
  }

  first_line.spans[0].font_size
}

///|
fn infer_writing_direction2(
  _lines : Array[@model.PdfTextLine],
) -> @model.PdfWritingDirection {
  @model.PdfWritingDirection::LeftToRight
}

///|
fn make_block_id(page_index : Int, block_index : Int) -> String {
  "p" + page_index.to_string() + "_block_" + block_index.to_string()
}
