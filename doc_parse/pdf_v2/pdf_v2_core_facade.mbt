///|
pub(all) struct PdfV2CoreOpenOptions {
  collect_text : Bool
  collect_images : Bool
  collect_vectors : Bool
  collect_annotations : Bool
  collect_forms : Bool
  collect_outlines : Bool
  collect_metadata : Bool
  max_pages : Int?
  max_objects : Int?
  max_stream_bytes : Int?
  max_events : Int?
  fail_on_encrypted : Bool
}

///|
pub(all) struct PdfV2CoreDocument {
  page_count : Int
  capabilities : Array[PdfV2CoreCapability]
  page_facts : Array[PdfV2CorePageFact]
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  source_summary : PdfV2SourceSummary
}

///|
pub(all) enum PdfV2CoreOpenResult {
  CoreOpenOk(PdfV2CoreDocument, Array[PdfV2CoreEvent])
  CoreOpenErr(Array[PdfV2Warning], Array[PdfV2Risk], String)
}

///|
pub(all) enum PdfV2SourceOpenResult {
  SourceOpenOk(PdfV2SourceDocument)
  SourceOpenErr(Array[PdfV2Warning], Array[PdfV2Risk], String)
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
pub(all) struct PdfV2CorePageFact {
  page_index : Int
  page_label : String?
  media_box : PdfV2BBox
  crop_box : PdfV2BBox?
  rotate : Int
  user_unit : Double?
  resources_present : Bool
  source_ref : PdfV2SourceRef
}

///|
pub(all) enum PdfV2CoreEventKind {
  PageBegin
  PageEnd
  ContentStreamBegin
  ContentStreamEnd
  TextObjectBegin
  TextObjectEnd
  TextState
  FontUse
  TextShow
  GlyphCandidate
  Glyph
  Image
  InlineImage
  VectorPath
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
pub(all) struct PdfV2CoreEvent {
  kind : PdfV2CoreEventKind
  page_index : Int?
  text : String?
  bbox : PdfV2BBox?
  object_ref : String?
  source_ref : PdfV2SourceRef
  reason_tags : Array[String]
  warnings : Array[PdfV2Warning]
  text_state : PdfV2TextStateFact?
  text_show : PdfV2TextShowFact?
  glyph_candidate : PdfV2GlyphCandidateFact?
  object_fact : PdfV2ObjectCandidateFact?
}

///|
pub fn default_pdf_v2_core_open_options() -> PdfV2CoreOpenOptions {
  {
    collect_text: true,
    collect_images: true,
    collect_vectors: true,
    collect_annotations: true,
    collect_forms: true,
    collect_outlines: true,
    collect_metadata: true,
    max_pages: None,
    max_objects: None,
    max_stream_bytes: None,
    max_events: None,
    fail_on_encrypted: true,
  }
}

///|
pub fn pdf_v2_core_page_fact(
  page_index : Int,
  media_box : PdfV2BBox,
  source_ref : PdfV2SourceRef,
) -> PdfV2CorePageFact {
  {
    page_index,
    page_label: None,
    media_box,
    crop_box: None,
    rotate: 0,
    user_unit: None,
    resources_present: false,
    source_ref,
  }
}

///|
pub fn pdf_v2_core_event(
  kind : PdfV2CoreEventKind,
  source_ref : PdfV2SourceRef,
) -> PdfV2CoreEvent {
  {
    kind,
    page_index: source_ref.page_index,
    text: None,
    bbox: None,
    object_ref: source_ref.object_id,
    source_ref,
    reason_tags: [],
    warnings: [],
    text_state: None,
    text_show: None,
    glyph_candidate: None,
    object_fact: None,
  }
}

///|
pub fn build_empty_pdf_v2_core_document() -> PdfV2CoreDocument {
  {
    page_count: 0,
    capabilities: pdf_v2_core_supported_capabilities(),
    page_facts: [],
    warnings: [],
    risks: [],
    source_summary: pdf_v2_empty_source_summary(),
  }
}
