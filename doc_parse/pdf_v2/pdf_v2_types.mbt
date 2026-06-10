///|
pub(all) struct PdfV2BBox {
  x0 : Double
  y0 : Double
  x1 : Double
  y1 : Double
}

///|
pub(all) enum PdfV2Severity {
  Info
  Warning
  Error
} derive(Eq)

///|
pub(all) enum PdfV2SourceKind {
  Document
  Page
  ContentStream
  Object
  TextOp
  Glyph
  Image
  InlineImage
  Vector
  Annotation
  Form
  Outline
  Destination
  Metadata
  Resource
  Malformed
  Unsupported
  Unknown
} derive(Eq)

///|
pub(all) struct PdfV2SourceRef {
  page_index : Int?
  object_id : String?
  stream_index : Int?
  op_index : Int?
  content_order_index : Int?
  kind : PdfV2SourceKind
}

///|
pub(all) enum PdfV2RiskKind {
  LowSignal
  Malformed
  UnsupportedFeature
  DecodeLowConfidence
  MultiColumn
  ReadingOrderAmbiguous
  CrossPageAmbiguous
  EncryptedOrRestricted
  ObjectGraphIssue
  PerformanceCapReached
} derive(Eq)

///|
pub(all) struct PdfV2Risk {
  kind : PdfV2RiskKind
  severity : PdfV2Severity
  message : String
  source_refs : Array[PdfV2SourceRef]
  reason_tags : Array[String]
}

///|
pub fn pdf_v2_document_source_ref() -> PdfV2SourceRef {
  {
    page_index: None,
    object_id: None,
    stream_index: None,
    op_index: None,
    content_order_index: None,
    kind: PdfV2SourceKind::Document,
  }
}

///|
pub fn pdf_v2_empty_bbox() -> PdfV2BBox {
  { x0: 0.0, y0: 0.0, x1: 0.0, y1: 0.0 }
}
