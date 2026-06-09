///|
pub fn build_pdf_v2_document_model(
  source_doc : @source_event.PdfV2SourceDocument,
  text_model : @text_reconstruction.PdfV2TextModel,
) -> PdfV2DocumentModel {
  let pages : Array[PdfV2Page] = []
  for text_page in text_model.pages {
    pages.push(page_from_text_and_source(text_page, source_doc))
  }
  if pages.is_empty() {
    for source_page in source_doc.pages {
      pages.push(empty_page_from_source(source_page))
    }
  }
  let warnings = source_doc.warnings + text_model.warnings
  let risks = source_doc.risks + text_model.risks
  {
    source_summary: {
      bytes_len: source_doc.summary.bytes_len,
      page_count: pages.length(),
      source_event_count: source_doc.summary.event_count,
      text_block_count: count_blocks(pages),
      warning_count: warnings.length(),
      risk_count: risks.length(),
      scanned_once: source_doc.summary.scanned_once,
      one_pass_required: source_doc.summary.one_pass_required,
      legacy_fallback_allowed: source_doc.summary.legacy_fallback_allowed,
      convert_raw_reparse_allowed: source_doc.summary.convert_raw_reparse_allowed,
    },
    pages,
    outlines: [],
    destinations: [],
    cross_page_boundaries: [],
    warnings,
    risks,
    classifier_ready_features: document_features(pages),
    reason_tags: [
      "normalized_model_scaffold", "parser_owned", "no_final_labels",
    ],
  }
}

///|
fn page_from_text_and_source(
  text_page : @text_reconstruction.PdfV2TextPage,
  source_doc : @source_event.PdfV2SourceDocument,
) -> PdfV2Page {
  let source_page = find_source_page(source_doc.pages, text_page.page_index)
  let text_blocks : Array[PdfV2TextBlock] = []
  for block in text_page.blocks {
    text_blocks.push(block_from_text(block))
  }
  {
    page_index: text_page.page_index,
    text_blocks,
    images: [],
    vectors: [],
    annotations: [],
    forms: [],
    layout_regions: [],
    reading_order: reading_order_for_blocks(text_page.page_index, text_blocks),
    source_refs: match source_page {
      Some(page) => [page.page_source_ref]
      None => []
    },
    object_refs: match source_page {
      Some(page) => page.object_refs
      None => []
    },
    warnings: match source_page {
      Some(page) => page.warnings + text_page.warnings
      None => text_page.warnings
    },
    risks: match source_page {
      Some(page) => page.risks + text_page.risks
      None => text_page.risks
    },
  }
}

///|
fn empty_page_from_source(
  source_page : @source_event.PdfV2SourcePage,
) -> PdfV2Page {
  {
    page_index: source_page.page_index,
    text_blocks: [],
    images: [],
    vectors: [],
    annotations: [],
    forms: [],
    layout_regions: [],
    reading_order: reading_order_for_blocks(source_page.page_index, []),
    source_refs: [source_page.page_source_ref],
    object_refs: source_page.object_refs,
    warnings: source_page.warnings,
    risks: source_page.risks,
  }
}

///|
fn block_from_text(
  block : @text_reconstruction.PdfV2TextBlock,
) -> PdfV2TextBlock {
  let lines : Array[PdfV2Line] = []
  for line in block.lines {
    lines.push(line_from_text(line))
  }
  {
    id: block.id,
    text: block.text,
    bbox: block.bbox,
    lines,
    dominant_font: block.dominant_font,
    dominant_font_size: block.dominant_font_size,
    writing_direction: block.writing_direction,
    page_index: block.page_index,
    source_refs: block.source_refs,
    object_refs: block.object_refs,
    content_order_start: block.content_order_start,
    content_order_end: block.content_order_end,
    decode_confidence: block.decode_confidence,
    candidate_facts: block.candidate_facts,
    list_marker_candidates: block.list_marker_candidates,
    caption_prefix_candidates: block.caption_prefix_candidates,
    heading_shape_candidates: block.heading_shape_candidates,
    classifier_ready_features: block_features(block),
    warnings: block.warnings,
    risks: block.risks,
    reason_tags: block.reason_tags,
  }
}

///|
fn line_from_text(line : @text_reconstruction.PdfV2Line) -> PdfV2Line {
  let spans : Array[PdfV2Span] = []
  for span in line.spans {
    spans.push(span_from_text(span))
  }
  {
    id: line.id,
    text: line.text,
    bbox: line.bbox,
    spans,
    baseline_y: line.baseline_y,
    line_height: line.line_height,
    writing_direction: line.writing_direction,
    source_refs: line.source_refs,
    object_refs: line.object_refs,
    page_index: line.page_index,
    content_order_start: line.content_order_start,
    content_order_end: line.content_order_end,
    decode_confidence: line.decode_confidence,
    warnings: line.warnings,
    risks: line.risks,
  }
}

///|
fn span_from_text(span : @text_reconstruction.PdfV2Span) -> PdfV2Span {
  let chars : Array[PdfV2Char] = []
  for char in span.chars {
    chars.push(char_from_text(char))
  }
  {
    id: span.id,
    text: span.text,
    bbox: span.bbox,
    chars,
    source_refs: span.source_refs,
    object_refs: span.object_refs,
    page_index: span.page_index,
    content_order_start: span.content_order_start,
    content_order_end: span.content_order_end,
    decode_confidence: span.decode_confidence,
  }
}

///|
fn char_from_text(char : @text_reconstruction.PdfV2Char) -> PdfV2Char {
  {
    text: char.text,
    bbox: char.bbox,
    source_refs: char.source_refs,
    object_ref: char.object_ref,
    page_index: char.page_index,
    content_order_index: char.content_order_index,
    decode_confidence: char.decode_confidence,
    warnings: char.warnings,
    risks: char.risks,
  }
}

///|
fn reading_order_for_blocks(
  page_index : Int,
  blocks : Array[PdfV2TextBlock],
) -> PdfV2ReadingOrder {
  let ids : Array[String] = []
  for block in blocks {
    ids.push(block.id)
  }
  {
    page_index,
    ordered_block_ids: ids,
    confidence: if blocks.is_empty() {
      0.0
    } else {
      1.0
    },
    reason_tags: ["source_order_placeholder", "parser_owned"],
  }
}

///|
fn block_features(
  block : @text_reconstruction.PdfV2TextBlock,
) -> PdfV2ClassifierReadyFeatures {
  {
    fields: Map([
      ("text_len", block.text.length().to_double()),
      ("candidate_fact_count", block.candidate_facts.length().to_double()),
      ("warning_count", block.warnings.length().to_double()),
      ("risk_count", block.risks.length().to_double()),
    ]),
    reason_tags: ["classifier_ready_placeholder", "parser_fact"],
  }
}

///|
fn document_features(pages : Array[PdfV2Page]) -> PdfV2ClassifierReadyFeatures {
  {
    fields: Map([
      ("page_count", pages.length().to_double()),
      ("text_block_count", count_blocks(pages).to_double()),
    ]),
    reason_tags: ["document_feature_placeholder", "parser_fact"],
  }
}

///|
fn count_blocks(pages : Array[PdfV2Page]) -> Int {
  let mut count = 0
  for page in pages {
    count = count + page.text_blocks.length()
  }
  count
}

///|
fn find_source_page(
  pages : Array[@source_event.PdfV2SourcePage],
  page_index : Int,
) -> @source_event.PdfV2SourcePage? {
  for page in pages {
    if page.page_index == page_index {
      return Some(page)
    }
  }
  None
}
