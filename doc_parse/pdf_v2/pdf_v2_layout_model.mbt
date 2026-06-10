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
pub(all) enum PdfV2GeometryCoverage {
  Full
  Partial
  Sparse
  Missing
  Unknown
} derive(Eq)

///|
pub(all) enum PdfV2LayoutRecoveryStatus {
  NotAttempted
  InsufficientGeometry
  SourceOrderOnly
  PartialFacts
  Unsupported
} derive(Eq)

///|
pub(all) struct PdfV2PageBoxFacts {
  media_box : PdfV2BBox
  crop_box : PdfV2BBox?
  rotate : Int
  user_unit : Double?
  resources_present : Bool
  source_ref : PdfV2SourceRef
}

///|
pub(all) struct PdfV2TextCandidateRefs {
  block_count : Int
  line_count : Int
  span_count : Int
  char_count : Int
  has_text_blocks : Bool
  has_block_candidates : Bool
  has_line_candidates : Bool
  has_span_candidates : Bool
  has_char_candidates : Bool
  source_refs : Array[PdfV2SourceRef]
}

///|
pub(all) struct PdfV2ObjectCandidateFacts {
  has_images : Bool
  has_inline_images : Bool
  has_links : Bool
  has_resources : Bool
  has_image_metadata : Bool
  has_annotations : Bool
  has_forms : Bool
  has_outlines : Bool
  has_destinations : Bool
  source_refs : Array[PdfV2SourceRef]
}

///|
pub(all) struct PdfV2PageLayoutFacts {
  page_index : Int
  page_box_facts : PdfV2PageBoxFacts
  text_candidate_refs : PdfV2TextCandidateRefs
  object_candidate_refs : PdfV2ObjectCandidateFacts
  geometry_coverage : PdfV2GeometryCoverage
  reading_order_status : PdfV2LayoutRecoveryStatus
  layout_region_status : PdfV2LayoutRecoveryStatus
  table_region_status : PdfV2LayoutRecoveryStatus
  image_region_status : PdfV2LayoutRecoveryStatus
  annotation_region_status : PdfV2LayoutRecoveryStatus
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  source_refs : Array[PdfV2SourceRef]
}

///|
pub(all) struct PdfV2LayoutFactSummary {
  page_count : Int
  pages_with_text_candidates : Int
  pages_with_block_candidates : Int
  pages_with_missing_geometry : Int
  pages_source_order_only : Int
  pages_with_layout_not_attempted : Int
  unsupported_capability_count : Int
  partial_fact_count : Int
  capped_object_count : Int
  metadata_only_count : Int
  warning_count : Int
  risk_count : Int
}

///|
pub(all) struct PdfV2LayoutFactSet {
  page_layouts : Array[PdfV2PageLayoutFacts]
  summary : PdfV2LayoutFactSummary
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  unsupported_capabilities : Array[PdfV2UnsupportedCapabilityReport]
  partial_fact_reports : Array[PdfV2PartialFactReport]
  source_refs : Array[PdfV2SourceRef]
  one_pass : Bool
  no_fallback : Bool
}

///|
pub(all) enum PdfV2LayoutFactResult {
  LayoutFactOk(PdfV2LayoutFactSet)
  LayoutFactErr(Array[PdfV2Warning], Array[PdfV2Risk], String)
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
