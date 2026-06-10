///|
pub(all) struct PdfV2DocumentMetadata {
  title : String?
  author : String?
  subject : String?
  creator : String?
  producer : String?
  source_refs : Array[PdfV2SourceRef]
}

///|
pub(all) struct PdfV2SourceSummary {
  event_count : Int
  page_count : Int
  warning_count : Int
  risk_count : Int
  one_pass_scan : Bool
  fallback_used : Bool
  external_model_files_read : Bool
}

///|
pub fn pdf_v2_source_summary(
  event_count : Int,
  page_count : Int,
  warning_count : Int,
  risk_count : Int,
) -> PdfV2SourceSummary {
  {
    event_count,
    page_count,
    warning_count,
    risk_count,
    one_pass_scan: true,
    fallback_used: false,
    external_model_files_read: false,
  }
}

///|
pub fn pdf_v2_empty_source_summary() -> PdfV2SourceSummary {
  pdf_v2_source_summary(0, 0, 0, 0)
}

///|
pub(all) struct PdfV2Page {
  page_index : Int
  page_label : String?
  media_box : PdfV2BBox
  crop_box : PdfV2BBox?
  rotate : Int
  user_unit : Double?
  resources_present : Bool
  bbox : PdfV2BBox
  source_ref : PdfV2SourceRef
  events : Array[PdfV2SourceEvent]
  text_blocks : Array[PdfV2TextBlock]
  layout_regions : Array[PdfV2LayoutRegion]
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
}

///|
pub(all) struct PdfV2PageModel {
  page_index : Int
  page_label : String?
  media_box : PdfV2BBox
  crop_box : PdfV2BBox?
  rotate : Int
  user_unit : Double?
  resources_present : Bool
  source_ref : PdfV2SourceRef
  blocks : Array[PdfV2BlockCandidate]
  lines : Array[PdfV2LineCandidate]
  spans : Array[PdfV2SpanCandidate]
  chars : Array[PdfV2CharCandidate]
  page_warnings : Array[PdfV2Warning]
  page_risks : Array[PdfV2Risk]
  text_blocks : Array[PdfV2TextBlock]
  layout_regions : Array[PdfV2LayoutRegion]
}

///|
pub(all) struct PdfV2DocumentModel {
  document_id : String?
  page_count : Int
  metadata : PdfV2DocumentMetadata
  pages : Array[PdfV2PageModel]
  source_events : Array[PdfV2SourceEvent]
  layout : PdfV2LayoutRecoveryResult
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  source_summary : PdfV2SourceSummary
  reconstruction_summary : PdfV2CharReconstructionSummary
  capabilities : Array[PdfV2CoreCapability]
  one_pass : Bool
  no_fallback : Bool
  model_version : String
}

///|
pub fn build_empty_pdf_v2_document() -> PdfV2DocumentModel {
  let source_ref = pdf_v2_document_source_ref()
  let layout = recover_pdf_v2_layout_noop([source_ref])
  {
    document_id: None,
    page_count: 0,
    metadata: {
      title: None,
      author: None,
      subject: None,
      creator: None,
      producer: None,
      source_refs: [source_ref],
    },
    pages: [],
    source_events: [],
    layout,
    warnings: [],
    risks: layout.risks,
    source_summary: pdf_v2_source_summary(0, 0, 0, layout.risks.length()),
    reconstruction_summary: pdf_v2_empty_reconstruction_summary(),
    capabilities: pdf_v2_core_supported_capabilities(),
    one_pass: true,
    no_fallback: true,
    model_version: "pdf-v2-phase9",
  }
}

///|
pub fn parse_pdf_v2_source_from_path(
  path : String,
  options : PdfV2CoreOpenOptions,
) -> PdfV2SourceOpenResult {
  pdf_v2_open_source_document_from_path(path, options)
}

///|
pub fn parse_pdf_v2_model_from_path(
  path : String,
  options : PdfV2CoreOpenOptions,
) -> PdfV2ModelAssemblyResult {
  pdf_v2_open_document_model_from_path(path, options)
}
