///|
pub(all) struct PdfV2ProductBridgeOptions {
  emit_page_breaks : Bool
  emit_low_confidence_notes : Bool
  emit_unsupported_object_notes : Bool
  preserve_empty_pages : Bool
  normalize_plain_text : Bool
  enable_semantic_rules : Bool
  enable_heading_rules : Bool
  enable_list_rules : Bool
  enable_noise_guards : Bool
  suppress_page_number_like_noise : Bool
  suppress_repeated_page_artifact_noise : Bool
  max_output_chars : Int?
  source_name : String?
}

///|
pub fn default_pdf_v2_product_bridge_options() -> PdfV2ProductBridgeOptions {
  {
    emit_page_breaks: false,
    emit_low_confidence_notes: false,
    emit_unsupported_object_notes: false,
    preserve_empty_pages: false,
    normalize_plain_text: true,
    enable_semantic_rules: true,
    enable_heading_rules: true,
    enable_list_rules: true,
    enable_noise_guards: true,
    suppress_page_number_like_noise: true,
    suppress_repeated_page_artifact_noise: true,
    max_output_chars: None,
    source_name: Some("pdf_v2"),
  }
}

///|
pub fn pdf_v2_pipeline_result_to_document(
  result : PdfV2ConvertPipelineResult,
  options : PdfV2ProductBridgeOptions,
) -> Result[@cor.Document, @cor.AppError] {
  match result {
    ConvertPipelineOk(output) =>
      Ok(pdf_v2_pipeline_output_to_document(output, options))
    ConvertPipelineErr(failure) =>
      Err(
        @cor.AppError(
          "pdf-v2: pipeline failed at " + failure.stage + ": " + failure.message,
        ),
      )
  }
}

///|
fn pdf_v2_pipeline_output_to_document(
  output : PdfV2ConvertPipelineOutput,
  options : PdfV2ProductBridgeOptions,
) -> @cor.Document {
  let doc = @cor.new_document()
  let mut remaining_chars = options.max_output_chars
  let text_paragraphs = if options.normalize_plain_text &&
    !options.enable_semantic_rules {
    pdf_v2_product_bridge_text_paragraphs(output.fragments, options)
  } else {
    []
  }
  let semantic_blocks = if options.normalize_plain_text &&
    options.enable_semantic_rules {
    pdf_v2_product_bridge_semantic_blocks(output.fragments, options)
  } else {
    []
  }
  let mut shaped_index = 0
  let mut semantic_index = 0
  for fragment_index in 0..<output.fragments.length() {
    let fragment = output.fragments[fragment_index]
    match fragment.kind {
      PlainText =>
        if options.normalize_plain_text && options.enable_semantic_rules {
          while semantic_index < semantic_blocks.length() &&
                semantic_blocks[semantic_index].fragment_index == fragment_index {
            let semantic_block = semantic_blocks[semantic_index]
            let text = pdf_v2_product_bridge_take_text(
              semantic_block.text,
              remaining_chars,
            )
            remaining_chars = text.1
            pdf_v2_product_bridge_push_semantic_block(
              doc,
              semantic_block,
              text.0,
              options,
            )
            semantic_index = semantic_index + 1
          }
        } else if options.normalize_plain_text {
          while shaped_index < text_paragraphs.length() &&
                text_paragraphs[shaped_index].fragment_index == fragment_index {
            let paragraph = text_paragraphs[shaped_index]
            let text = pdf_v2_product_bridge_take_text(
              paragraph.text,
              remaining_chars,
            )
            remaining_chars = text.1
            pdf_v2_product_bridge_push_plain_text(
              doc,
              text.0,
              fragment,
              options,
            )
            shaped_index = shaped_index + 1
          }
        } else {
          let text = pdf_v2_product_bridge_take_text(
            fragment.text,
            remaining_chars,
          )
          remaining_chars = text.1
          pdf_v2_product_bridge_push_plain_text(doc, text.0, fragment, options)
        }
      PageBreak =>
        if options.emit_page_breaks || options.preserve_empty_pages {
          @cor.push_with_origin(
            doc,
            @cor.Block::BlankLine,
            Some(pdf_v2_product_bridge_origin(doc, fragment, options)),
          )
        }
      LowConfidenceNote =>
        if options.emit_low_confidence_notes {
          let text = pdf_v2_product_bridge_take_text(
            fragment.text,
            remaining_chars,
          )
          remaining_chars = text.1
          pdf_v2_product_bridge_push_plain_text(doc, text.0, fragment, options)
        }
      UnsupportedObjectNote =>
        if options.emit_unsupported_object_notes {
          let text = pdf_v2_product_bridge_take_text(
            fragment.text,
            remaining_chars,
          )
          remaining_chars = text.1
          pdf_v2_product_bridge_push_plain_text(doc, text.0, fragment, options)
        }
    }
  }
  doc
}

///|
fn pdf_v2_product_bridge_text_paragraphs(
  fragments : Array[PdfV2FactFragment],
  options : PdfV2ProductBridgeOptions,
) -> Array[PdfV2TextOutputParagraph] {
  pdf_v2_text_output_paragraphs(fragments, options)
}

///|
fn pdf_v2_product_bridge_semantic_blocks(
  fragments : Array[PdfV2FactFragment],
  options : PdfV2ProductBridgeOptions,
) -> Array[PdfV2SemanticBlock] {
  pdf_v2_semantic_blocks_from_fragments(fragments, options)
}

///|
fn pdf_v2_product_bridge_push_plain_text(
  doc : @cor.Document,
  text : String,
  fragment : PdfV2FactFragment,
  options : PdfV2ProductBridgeOptions,
) -> Unit {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return
  }
  @cor.push_with_origin(
    doc,
    @cor.Block::Paragraph(trimmed),
    Some(pdf_v2_product_bridge_origin(doc, fragment, options)),
  )
}

///|
fn pdf_v2_product_bridge_push_semantic_block(
  doc : @cor.Document,
  semantic_block : PdfV2SemanticBlock,
  text : String,
  options : PdfV2ProductBridgeOptions,
) -> Unit {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return
  }
  let block = pdf_v2_product_bridge_core_block(semantic_block, trimmed)
  @cor.push_with_origin(
    doc,
    block,
    Some(
      pdf_v2_product_bridge_origin_for_semantic(doc, semantic_block, options),
    ),
  )
}

///|
fn pdf_v2_product_bridge_core_block(
  semantic_block : PdfV2SemanticBlock,
  text : String,
) -> @cor.Block {
  match semantic_block.kind {
    PdfV2SemanticBlockKind::Heading =>
      @cor.Block::Heading(semantic_block.level.unwrap_or(1), text)
    PdfV2SemanticBlockKind::OrderedListItem =>
      @cor.Block::ListItem(true, semantic_block.list_level, text)
    PdfV2SemanticBlockKind::UnorderedListItem =>
      @cor.Block::ListItem(false, semantic_block.list_level, text)
    PdfV2SemanticBlockKind::Paragraph
    | PdfV2SemanticBlockKind::Continuation
    | PdfV2SemanticBlockKind::PlainText
    | PdfV2SemanticBlockKind::Unknown => @cor.Block::Paragraph(text)
  }
}

///|
fn pdf_v2_product_bridge_take_text(
  text : String,
  remaining_chars : Int?,
) -> (String, Int?) {
  match remaining_chars {
    None => (text, None)
    Some(remaining) =>
      if remaining <= 0 {
        ("", Some(0))
      } else if text.length() <= remaining {
        (text, Some(remaining - text.length()))
      } else {
        (text[:remaining].to_owned(), Some(0))
      }
  }
}

///|
fn pdf_v2_product_bridge_origin(
  doc : @cor.Document,
  fragment : PdfV2FactFragment,
  options : PdfV2ProductBridgeOptions,
) -> @cor.Origin {
  pdf_v2_product_bridge_origin_from_parts(
    doc,
    fragment.page_index,
    fragment.source_refs,
    options,
  )
}

///|
fn pdf_v2_product_bridge_origin_for_semantic(
  doc : @cor.Document,
  semantic_block : PdfV2SemanticBlock,
  options : PdfV2ProductBridgeOptions,
) -> @cor.Origin {
  pdf_v2_product_bridge_origin_from_parts(
    doc,
    semantic_block.page_index,
    semantic_block.source_refs,
    options,
  )
}

///|
fn pdf_v2_product_bridge_origin_from_parts(
  doc : @cor.Document,
  page_index : Int?,
  source_refs : Array[@pdfv2.PdfV2SourceRef],
  options : PdfV2ProductBridgeOptions,
) -> @cor.Origin {
  {
    source_name: options.source_name,
    page: match page_index {
      Some(index) => Some(index + 1)
      None => None
    },
    slide: None,
    sheet: None,
    block_index: Some(doc.blocks.val.length()),
    heading_path: None,
    line_start: None,
    line_end: None,
    row_index: None,
    column_index: None,
    object_ref: pdf_v2_product_bridge_object_ref(source_refs),
    relationship_id: None,
    key_path: None,
  }
}

///|
fn pdf_v2_product_bridge_object_ref(
  source_refs : Array[@pdfv2.PdfV2SourceRef],
) -> String? {
  for source_ref in source_refs {
    match source_ref.object_id {
      Some(object_id) => return Some(object_id)
      None => ()
    }
  }
  None
}
