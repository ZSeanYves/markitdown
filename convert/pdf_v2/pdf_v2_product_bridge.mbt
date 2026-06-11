///|
pub(all) struct PdfV2ProductBridgeOptions {
  emit_page_breaks : Bool
  emit_low_confidence_notes : Bool
  emit_unsupported_object_notes : Bool
  preserve_empty_pages : Bool
  normalize_plain_text : Bool
  emit_minimal_headings : Bool
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
    emit_minimal_headings: true,
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
  let text_paragraphs = if options.normalize_plain_text {
    pdf_v2_product_bridge_text_paragraphs(output.fragments, options)
  } else {
    []
  }
  let mut shaped_index = 0
  for fragment_index in 0..<output.fragments.length() {
    let fragment = output.fragments[fragment_index]
    match fragment.kind {
      PlainText =>
        if options.normalize_plain_text {
          while shaped_index < text_paragraphs.length() &&
                text_paragraphs[shaped_index].fragment_index == fragment_index {
            let paragraph = text_paragraphs[shaped_index]
            let next_text = if shaped_index + 1 < text_paragraphs.length() {
              Some(text_paragraphs[shaped_index + 1].text)
            } else {
              None
            }
            let text = pdf_v2_product_bridge_take_text(
              paragraph.text,
              remaining_chars,
            )
            remaining_chars = text.1
            pdf_v2_product_bridge_push_text(
              doc,
              text.0,
              paragraph.text,
              paragraph.line_count,
              fragment,
              next_text,
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
          pdf_v2_product_bridge_push_text(
            doc,
            text.0,
            fragment.text,
            1,
            fragment,
            None,
            options,
          )
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
          pdf_v2_product_bridge_push_text(
            doc,
            text.0,
            fragment.text,
            1,
            fragment,
            None,
            options,
          )
        }
      UnsupportedObjectNote =>
        if options.emit_unsupported_object_notes {
          let text = pdf_v2_product_bridge_take_text(
            fragment.text,
            remaining_chars,
          )
          remaining_chars = text.1
          pdf_v2_product_bridge_push_text(
            doc,
            text.0,
            fragment.text,
            1,
            fragment,
            None,
            options,
          )
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
fn pdf_v2_product_bridge_push_text(
  doc : @cor.Document,
  text : String,
  heading_source_text : String,
  paragraph_line_count : Int,
  fragment : PdfV2FactFragment,
  next_text : String?,
  options : PdfV2ProductBridgeOptions,
) -> Unit {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return
  }
  let block = if pdf_v2_should_emit_minimal_heading(
      heading_source_text, fragment, paragraph_line_count, next_text, options,
    ) {
    @cor.Block::Heading(1, trimmed)
  } else {
    @cor.Block::Paragraph(trimmed)
  }
  @cor.push_with_origin(
    doc,
    block,
    Some(pdf_v2_product_bridge_origin(doc, fragment, options)),
  )
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
  {
    source_name: options.source_name,
    page: match fragment.page_index {
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
    object_ref: pdf_v2_product_bridge_object_ref(fragment.source_refs),
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
