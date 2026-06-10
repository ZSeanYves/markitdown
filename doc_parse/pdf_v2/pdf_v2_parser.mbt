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
  bbox : PdfV2BBox
  source_ref : PdfV2SourceRef
  events : Array[PdfV2SourceEvent]
  text_blocks : Array[PdfV2TextBlock]
  layout_regions : Array[PdfV2LayoutRegion]
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
}

///|
pub(all) struct PdfV2DocumentModel {
  metadata : PdfV2DocumentMetadata
  pages : Array[PdfV2Page]
  source_events : Array[PdfV2SourceEvent]
  layout : PdfV2LayoutRecoveryResult
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  source_summary : PdfV2SourceSummary
}

///|
pub fn build_empty_pdf_v2_document() -> PdfV2DocumentModel {
  let source_ref = pdf_v2_document_source_ref()
  let layout = recover_pdf_v2_layout_noop([source_ref])
  {
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
  }
}
