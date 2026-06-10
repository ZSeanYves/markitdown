///|
pub(all) enum PdfV2LayoutRegionKind {
  Text
  Table
  Figure
  Image
  Caption
  Header
  Footer
  PageNumber
  Form
  Annotation
  Unknown
} derive(Eq)

///|
pub(all) struct PdfV2LayoutRegion {
  kind : PdfV2LayoutRegionKind
  bbox : PdfV2BBox
  source_refs : Array[PdfV2SourceRef]
  confidence : Double
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2ReadingOrder {
  region_indices : Array[Int]
  confidence : Double
  source_refs : Array[PdfV2SourceRef]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2CrossPageBoundary {
  from_page_index : Int
  to_page_index : Int
  confidence : Double
  source_refs : Array[PdfV2SourceRef]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2LayoutRecoveryHint {
  source_refs : Array[PdfV2SourceRef]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2LayoutRecoveryResult {
  regions : Array[PdfV2LayoutRegion]
  reading_order : PdfV2ReadingOrder
  cross_page_boundaries : Array[PdfV2CrossPageBoundary]
  hints : Array[PdfV2LayoutRecoveryHint]
  risks : Array[PdfV2Risk]
  warnings : Array[PdfV2Warning]
  confidence : Double
}

///|
pub fn recover_pdf_v2_layout_noop(
  source_refs : Array[PdfV2SourceRef],
) -> PdfV2LayoutRecoveryResult {
  {
    regions: [],
    reading_order: {
      region_indices: [],
      confidence: 0.0,
      source_refs,
      reason_tags: ["fail_closed", "layout_recovery_noop"],
    },
    cross_page_boundaries: [],
    hints: [],
    risks: [
      {
        kind: PdfV2RiskKind::LowSignal,
        severity: PdfV2Severity::Info,
        message: "PDF v2 layout recovery scaffold abstained",
        source_refs,
        reason_tags: ["fail_closed", "no_model_runtime"],
      },
    ],
    warnings: [],
    confidence: 0.0,
  }
}
