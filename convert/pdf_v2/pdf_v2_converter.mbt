///|
fn pdf_v2_dispatcher_pipeline_options() -> PdfV2ConvertPipelineOptions {
  {
    ..default_pdf_v2_convert_pipeline_options(),
    run_gate: false,
    lowering_options: {
      ..default_pdf_v2_fact_lowering_options(),
      respect_gate_decisions: false,
    },
  }
}

///|
pub(all) struct PdfV2ParsedDocument {
  document : @cor.Document
  document_properties : @cor.MetadataDocumentProperties?
}

///|
fn pdf_v2_metadata_visible_value(value : String?) -> String? {
  match value {
    None => None
    Some(raw) => {
      let trimmed = raw.trim().to_owned()
      if trimmed == "" {
        return None
      }
      let lower = trimmed.to_lower()
      if lower == "untitled" || lower == "anonymous" || lower == "unspecified" {
        None
      } else {
        Some(trimmed)
      }
    }
  }
}

///|
pub fn pdf_v2_metadata_document_properties(
  model : @pdfv2.PdfV2DocumentModel,
) -> @cor.MetadataDocumentProperties? {
  let meta = model.metadata
  let creator = match pdf_v2_metadata_visible_value(meta.creator) {
    Some(value) => Some(value)
    None => pdf_v2_metadata_visible_value(meta.author)
  }
  Some(
    @cor.metadata_document_properties(
      pdf_v2_metadata_visible_value(meta.title),
      pdf_v2_metadata_visible_value(meta.subject),
      creator,
      None,
      pdf_v2_metadata_visible_value(meta.keywords),
      pdf_v2_metadata_visible_value(meta.created),
      pdf_v2_metadata_visible_value(meta.modified),
      pdf_v2_metadata_visible_value(meta.producer),
      Some(model.page_count.to_string()),
      None,
      None,
      None,
    ),
  )
}

///|
pub fn parse_pdf_v2_with_metadata(
  input_path : String,
  out_dir : String,
  _max_heading : Int,
) -> Result[PdfV2ParsedDocument, @cor.AppError] {
  let asset_output_dir = if out_dir.trim().to_owned() == "" {
    None
  } else {
    Some(out_dir)
  }
  let pipeline_result = convert_pdf_v2_experimental_from_path(input_path, {
    ..pdf_v2_dispatcher_pipeline_options(),
    asset_output_dir,
  })
  match pipeline_result {
    ConvertPipelineOk(output) => {
      let document_properties = output.document_properties
      let document = pdf_v2_pipeline_output_to_document(output, {
        ..default_pdf_v2_product_bridge_options(),
        source_name: Some(@cor.basename(input_path)),
      })
      Ok({ document, document_properties })
    }
    ConvertPipelineErr(failure) =>
      Err(
        @cor.AppError(
          "pdf-v2: pipeline failed at " + failure.stage + ": " + failure.message,
        ),
      )
  }
}

///|
pub fn parse_pdf_v2(
  input_path : String,
  out_dir : String,
  max_heading : Int,
) -> Result[@cor.Document, @cor.AppError] {
  match parse_pdf_v2_with_metadata(input_path, out_dir, max_heading) {
    Ok(parsed) => Ok(parsed.document)
    Err(err) => Err(err)
  }
}
