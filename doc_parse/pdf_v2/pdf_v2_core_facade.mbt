///|
pub(all) struct PdfV2CoreDocument {
  page_count : Int
  warnings : Array[PdfV2Warning]
}

///|
pub(all) enum PdfV2CoreCapability {
  ObjectGraph
  XrefTable
  XrefStream
  ObjectStream
  Streams
  Filters
  EncryptionMetadata
  PageTree
  ContentStreams
  Fonts
  CMap
  ToUnicode
  Images
  Vectors
  Annotations
  Forms
  Outlines
  Metadata
} derive(Eq)

///|
pub fn pdf_v2_core_supported_capabilities() -> Array[PdfV2CoreCapability] {
  [
    PdfV2CoreCapability::ObjectGraph,
    PdfV2CoreCapability::XrefTable,
    PdfV2CoreCapability::XrefStream,
    PdfV2CoreCapability::ObjectStream,
    PdfV2CoreCapability::Streams,
    PdfV2CoreCapability::Filters,
    PdfV2CoreCapability::EncryptionMetadata,
    PdfV2CoreCapability::PageTree,
    PdfV2CoreCapability::ContentStreams,
    PdfV2CoreCapability::Fonts,
    PdfV2CoreCapability::CMap,
    PdfV2CoreCapability::ToUnicode,
    PdfV2CoreCapability::Images,
    PdfV2CoreCapability::Vectors,
    PdfV2CoreCapability::Annotations,
    PdfV2CoreCapability::Forms,
    PdfV2CoreCapability::Outlines,
    PdfV2CoreCapability::Metadata,
  ]
}

///|
pub fn build_empty_pdf_v2_core_document() -> PdfV2CoreDocument {
  { page_count: 0, warnings: [] }
}
