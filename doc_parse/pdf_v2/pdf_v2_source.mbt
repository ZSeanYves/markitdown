///|
pub(all) enum PdfV2SourceEventKind {
  PageBegin
  PageEnd
  ContentStreamBegin
  ContentStreamEnd
  TextOp
  TextShow
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
}

///|
pub(all) struct PdfV2SourceDocument {
  source_events : Array[PdfV2SourceEvent]
  pages : Array[PdfV2Page]
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
  }
}
