///|
pub(all) struct PdfV2LoweredBlockFragment {
  text : String
  decision : PdfV2BlockDecision
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2LoweringScaffoldResult {
  fragments : Array[PdfV2LoweredBlockFragment]
  warnings : Array[@pdfv2.PdfV2Warning]
  risks : Array[@pdfv2.PdfV2Risk]
  fallback_used : Bool
  raw_pdf_scanned_by_convert : Bool
}

///|
pub fn lower_pdf_v2_document_scaffold(
  model : @pdfv2.PdfV2DocumentModel,
) -> PdfV2LoweringScaffoldResult {
  let fragments : Array[PdfV2LoweredBlockFragment] = []
  for page in model.pages {
    for block in page.text_blocks {
      let decision = decide_pdf_v2_block_role(None, {
        deterministic_constraint_score: 0.0,
        model_confidence: 0.0,
        feature_support_score: block.classifier_features.geometry.relative_width,
        risk_penalty: 1.0 - block.decode_confidence,
      })
      fragments.push({
        text: block.text,
        decision,
        source_refs: block.source_refs,
        reason_tags: decision.reason_tags,
      })
    }
  }
  {
    fragments,
    warnings: model.warnings,
    risks: model.risks,
    fallback_used: false,
    raw_pdf_scanned_by_convert: false,
  }
}
