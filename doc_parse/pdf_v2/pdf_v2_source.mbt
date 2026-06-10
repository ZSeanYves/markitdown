///|
pub(all) enum PdfV2SourceEventKind {
  PageBegin
  PageEnd
  TextOp
  Glyph
  ImageObject
  VectorPath
  AnnotationObject
  FormObject
  OutlineItem
  Metadata
  Unknown
} derive(Eq)

///|
pub(all) struct PdfV2SourceEvent {
  kind : PdfV2SourceEventKind
  text : String?
  bbox : PdfV2BBox?
  source_ref : PdfV2SourceRef
  warnings : Array[PdfV2Warning]
}

///|
pub fn pdf_v2_source_event(
  kind : PdfV2SourceEventKind,
  source_ref : PdfV2SourceRef,
) -> PdfV2SourceEvent {
  { kind, text: None, bbox: None, source_ref, warnings: [] }
}
