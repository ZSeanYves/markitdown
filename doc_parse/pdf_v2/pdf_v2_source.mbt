///|
pub(all) enum PdfV2SourceEventKind {
  PageBegin
  PageEnd
  ContentStreamBegin
  ContentStreamEnd
  TextOp
  TextObjectBegin
  TextObjectEnd
  TextState
  FontUse
  TextShow
  GlyphCandidate
  Glyph
  ImageObject
  InlineImage
  VectorPath
  AnnotationObject
  FormObject
  OutlineItem
  Destination
  Metadata
  Resource
  Malformed
  Unsupported
  Unknown
} derive(Eq)

///|
pub(all) struct PdfV2SourceEvent {
  kind : PdfV2SourceEventKind
  page_index : Int?
  text : String?
  bbox : PdfV2BBox?
  object_ref : String?
  source_ref : PdfV2SourceRef
  reason_tags : Array[String]
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  text_state : PdfV2TextStateFact?
  text_show : PdfV2TextShowFact?
  glyph_candidate : PdfV2GlyphCandidateFact?
  object_fact : PdfV2ObjectCandidateFact?
}

///|
pub(all) struct PdfV2SourceDocument {
  source_events : Array[PdfV2SourceEvent]
  pages : Array[PdfV2Page]
  font_cache : PdfV2FontCache
  char_candidates : Array[PdfV2CharCandidate]
  span_candidates : Array[PdfV2SpanCandidate]
  line_candidates : Array[PdfV2LineCandidate]
  block_candidates : Array[PdfV2BlockCandidate]
  image_candidates : Array[PdfV2ImageCandidate]
  inline_image_candidates : Array[PdfV2InlineImageCandidate]
  annotation_candidates : Array[PdfV2AnnotationCandidate]
  link_candidates : Array[PdfV2LinkCandidate]
  form_candidates : Array[PdfV2FormCandidate]
  outline_candidates : Array[PdfV2OutlineCandidate]
  destination_candidates : Array[PdfV2DestinationCandidate]
  resource_candidates : Array[PdfV2ResourceCandidate]
  metadata_candidates : Array[PdfV2MetadataCandidate]
  unsupported_capabilities : Array[PdfV2UnsupportedCapabilityReport]
  partial_fact_reports : Array[PdfV2PartialFactReport]
  object_summary : PdfV2ObjectSummary
  reconstruction_summary : PdfV2CharReconstructionSummary
  summary : PdfV2SourceSummary
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
}

///|
pub fn pdf_v2_source_event(
  kind : PdfV2SourceEventKind,
  source_ref : PdfV2SourceRef,
) -> PdfV2SourceEvent {
  {
    kind,
    page_index: source_ref.page_index,
    text: None,
    bbox: None,
    object_ref: source_ref.object_id,
    source_ref,
    reason_tags: [],
    warnings: [],
    risks: [],
    text_state: None,
    text_show: None,
    glyph_candidate: None,
    object_fact: None,
  }
}
