///|
pub(all) struct PdfV2DocumentFeatureRow {
  page_count : Int
  has_text : Bool
  has_images : Bool
  has_annotations : Bool
  has_forms : Bool
  has_outlines : Bool
  has_metadata : Bool
  unsupported_capability_count : Int
  partial_fact_count : Int
  capped_object_count : Int
  metadata_only_count : Int
  warning_count : Int
  risk_count : Int
}

///|
pub(all) struct PdfV2PageFeatureRow {
  page_index : Int
  text_candidate_count : Int
  block_candidate_count : Int
  line_candidate_count : Int
  span_candidate_count : Int
  char_candidate_count : Int
  image_count : Int
  annotation_count : Int
  link_count : Int
  form_count : Int
  resource_count : Int
  geometry_coverage : PdfV2GeometryCoverage
  reading_order_status : PdfV2LayoutRecoveryStatus
  layout_region_status : PdfV2LayoutRecoveryStatus
  image_region_status : PdfV2LayoutRecoveryStatus
  annotation_region_status : PdfV2LayoutRecoveryStatus
  unsupported_capability_count : Int
  partial_fact_count : Int
  warning_count : Int
  risk_count : Int
  source_refs : Array[PdfV2SourceRef]
}

///|
pub(all) struct PdfV2ObjectPresenceFlags {
  has_images : Bool
  has_inline_images : Bool
  has_annotations : Bool
  has_links : Bool
  has_forms : Bool
  has_resources : Bool
}

///|
pub(all) struct PdfV2BlockFeatureRow {
  page_index : Int?
  block_index : Int
  text_length : Int
  line_count : Int
  span_count : Int
  char_count : Int
  avg_decode_confidence : Double
  geometry_confidence : PdfV2GeometryConfidence
  has_bbox : Bool
  source_ref_count : Int
  warning_count : Int
  risk_count : Int
  unsupported_nearby_or_page_count : Int
  partial_fact_nearby_or_page_count : Int
  object_presence_flags : PdfV2ObjectPresenceFlags
  low_signal_flag : Bool
  missing_geometry_flag : Bool
  capped_context_flag : Bool
  reason_tags : Array[String]
  source_refs : Array[PdfV2SourceRef]
}

///|
pub(all) struct PdfV2ObjectFeatureRow {
  page_index : Int?
  object_kind : String
  capability_status : PdfV2CapabilityStatus
  metadata_only : Bool
  partial : Bool
  unsupported : Bool
  capped : Bool
  has_bbox : Bool
  has_source_ref : Bool
  warning_count : Int
  risk_count : Int
  reason_tags : Array[String]
  source_refs : Array[PdfV2SourceRef]
}

///|
pub(all) struct PdfV2FeatureSummary {
  document_feature_count : Int
  page_feature_count : Int
  block_feature_count : Int
  object_feature_count : Int
  low_signal_block_count : Int
  missing_geometry_block_count : Int
  unsupported_object_count : Int
  partial_object_count : Int
  capped_object_count : Int
  warning_count : Int
  risk_count : Int
}

///|
pub(all) struct PdfV2FeatureSet {
  document_features : PdfV2DocumentFeatureRow
  page_features : Array[PdfV2PageFeatureRow]
  block_features : Array[PdfV2BlockFeatureRow]
  object_features : Array[PdfV2ObjectFeatureRow]
  summary : PdfV2FeatureSummary
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  source_refs : Array[PdfV2SourceRef]
  one_pass : Bool
  no_fallback : Bool
}

///|
pub(all) enum PdfV2FeatureResult {
  FeatureOk(PdfV2FeatureSet)
  FeatureErr(Array[PdfV2Warning], Array[PdfV2Risk], String)
}
