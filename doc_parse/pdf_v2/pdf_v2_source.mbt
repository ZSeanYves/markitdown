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
}

///|
pub(all) struct PdfV2SourceDocument {
  source_events : Array[PdfV2SourceEvent]
  pages : Array[PdfV2Page]
  font_cache : PdfV2FontCache
  char_candidates : Array[PdfV2CharCandidate]
  span_candidates : Array[PdfV2SpanCandidate]
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
  }
}
