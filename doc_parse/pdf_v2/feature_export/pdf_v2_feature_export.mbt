///|
pub(all) enum PdfV2FeatureContractVersion {
  PdfV2FeatureContractReset7
} derive(Eq)

///|
pub(all) enum PdfV2FeatureGroup {
  Identity
  TextShape
  FontStyle
  Geometry
  PageRelativeGeometry
  LineSpacing
  Indentation
  NeighborContext
  VisualProximity
  LayoutRegion
  ReadingOrder
  CrossPage
  Diagnostics
  Risk
  CandidateFacts
  ModelGateInput
  TrainingExportMetadata
} derive(Eq)

///|
pub(all) enum PdfV2FeatureValueKind {
  Bool
  Int
  Float
  String
  StringList
  Bbox
  Enum
  Unknown
} derive(Eq)

///|
pub(all) enum PdfV2FeatureAvailability {
  Available
  DerivedAvailable
  MissingWithWarning
  MissingWithRisk
  Planned
  NotApplicable
} derive(Eq)

///|
pub(all) enum PdfV2FeatureSource {
  NormalizedModel
  TextReconstruction
  LayoutRecovery
  Diagnostics
  Derived
  FutureParserExport
  FutureModelHint
} derive(Eq)

///|
pub(all) struct PdfV2FeatureField {
  name : String
  group : PdfV2FeatureGroup
  value_kind : PdfV2FeatureValueKind
  availability : PdfV2FeatureAvailability
  source : PdfV2FeatureSource
  required_by_runtime_gate : Bool
  required_by_training : Bool
  missing_behavior : String
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2BlockFeatureSchema {
  version : PdfV2FeatureContractVersion
  fields : Array[PdfV2FeatureField]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2FeatureDiagnostic {
  field_name : String
  availability : PdfV2FeatureAvailability
  message : String
  warnings : Array[@pdfv2.PdfV2Warning]
  risks : Array[@pdfv2.PdfV2Risk]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2FeatureRisk {
  field_name : String
  risk : @pdfv2.PdfV2Risk
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2FeatureValue {
  field_name : String
  value_kind : PdfV2FeatureValueKind
  bool_value : Bool?
  int_value : Int?
  float_value : Double?
  string_value : String?
  string_list_value : Array[String]
  bbox_value : @pdfv2.PdfV2Rect?
  enum_value : String?
  availability : PdfV2FeatureAvailability
  source : PdfV2FeatureSource
  diagnostics : Array[PdfV2FeatureDiagnostic]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2BlockFeatureRecord {
  doc_id : String
  page_index : Int
  block_id : String
  line_ids : Array[String]
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  object_refs : Array[String]
  bbox : @pdfv2.PdfV2Rect
  page_relative_bbox : @pdfv2.PdfV2Rect
  text : String
  text_length : Int
  line_count : Int
  char_count : Int
  word_count : Int
  dominant_font_name : String?
  dominant_font_size : Double?
  decode_confidence : @text_reconstruction.PdfV2DecodeConfidence
  writing_direction : @pdfv2.PdfV2WritingDirection
  candidate_fact_tags : Array[String]
  layout_region_ids : Array[String]
  layout_region_kinds : Array[String]
  reading_order_index : Int?
  cross_page_boundary_kinds : Array[String]
  warnings : Array[@pdfv2.PdfV2Warning]
  risks : Array[@pdfv2.PdfV2Risk]
  diagnostics : Array[PdfV2FeatureDiagnostic]
  feature_risks : Array[PdfV2FeatureRisk]
  values : Array[PdfV2FeatureValue]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2FeatureExportOptions {
  doc_id : String
  include_text : Bool
  include_planned_fields : Bool
  emit_missing_feature_diagnostics : Bool
  fail_closed : Bool
}

///|
pub(all) struct PdfV2FeatureExportSummary {
  record_count : Int
  field_count : Int
  available_count : Int
  planned_count : Int
  missing_warning_count : Int
  missing_risk_count : Int
  warning_count : Int
  risk_count : Int
  diagnostic_count : Int
  one_pass_required : Bool
  legacy_fallback_allowed : Bool
  convert_raw_reparse_allowed : Bool
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2FeatureExportResult {
  schema : PdfV2BlockFeatureSchema
  records : Array[PdfV2BlockFeatureRecord]
  diagnostics : Array[PdfV2FeatureDiagnostic]
  feature_risks : Array[PdfV2FeatureRisk]
  warnings : Array[@pdfv2.PdfV2Warning]
  risks : Array[@pdfv2.PdfV2Risk]
  summary : PdfV2FeatureExportSummary
  reason_tags : Array[String]
}

///|
pub fn default_pdf_v2_feature_export_options() -> PdfV2FeatureExportOptions {
  {
    doc_id: "pdf_v2_document",
    include_text: true,
    include_planned_fields: true,
    emit_missing_feature_diagnostics: true,
    fail_closed: true,
  }
}

///|
pub fn default_pdf_v2_block_feature_schema() -> PdfV2BlockFeatureSchema {
  {
    version: PdfV2FeatureContractVersion::PdfV2FeatureContractReset7,
    fields: schema_fields(),
    reason_tags: [
      "pdf_v2_feature_export_schema", "parser_owned_feature_contract", "no_final_semantic_labels",
    ],
  }
}

///|
pub fn export_pdf_v2_block_features(
  doc : @normalized_model.PdfV2DocumentModel,
  layout : @layout_recovery.PdfV2LayoutRecoveryResult,
  options : PdfV2FeatureExportOptions,
) -> PdfV2FeatureExportResult {
  let schema = default_pdf_v2_block_feature_schema()
  let records : Array[PdfV2BlockFeatureRecord] = []
  let diagnostics : Array[PdfV2FeatureDiagnostic] = []
  let feature_risks : Array[PdfV2FeatureRisk] = []
  let warnings = copy_warnings(doc.warnings) + copy_warnings(layout.warnings)
  let risks = copy_risks(doc.risks) + copy_risks(layout.risks)
  for page in doc.pages {
    for block in page.text_blocks {
      let record = feature_record_for_block(
        doc, layout, page, block, schema, options,
      )
      for diagnostic in record.diagnostics {
        diagnostics.push(diagnostic)
      }
      for feature_risk in record.feature_risks {
        feature_risks.push(feature_risk)
      }
      records.push(record)
    }
  }
  let counts = value_counts(records)
  {
    schema,
    records,
    diagnostics,
    feature_risks,
    warnings,
    risks,
    summary: {
      record_count: records.length(),
      field_count: schema.fields.length(),
      available_count: counts.0,
      planned_count: counts.1,
      missing_warning_count: counts.2,
      missing_risk_count: counts.3,
      warning_count: warnings.length(),
      risk_count: risks.length() + feature_risks.length(),
      diagnostic_count: diagnostics.length(),
      one_pass_required: doc.source_summary.one_pass_required,
      legacy_fallback_allowed: doc.source_summary.legacy_fallback_allowed,
      convert_raw_reparse_allowed: doc.source_summary.convert_raw_reparse_allowed,
      reason_tags: [
        "feature_export_scaffold", "normalized_model_plus_layout_only", "no_tsv_writer",
        "no_final_semantic_labels",
      ],
    },
    reason_tags: [
      "feature_export_scaffold", "parser_owned_classifier_ready_features", "no_pdf_reparse",
      "no_convert_dependency", "no_tsv_writer",
    ],
  }
}

///|
pub fn pdf_v2_feature_schema_has_field(
  schema : PdfV2BlockFeatureSchema,
  name : String,
) -> Bool {
  for field in schema.fields {
    if field.name == name {
      return true
    }
  }
  false
}

///|
pub fn pdf_v2_block_feature_has_field(
  record : PdfV2BlockFeatureRecord,
  name : String,
) -> Bool {
  for value in record.values {
    if value.field_name == name {
      return true
    }
  }
  false
}

///|
fn schema_fields() -> Array[PdfV2FeatureField] {
  let fields : Array[PdfV2FeatureField] = []
  push_identity_fields(fields)
  push_text_shape_fields(fields)
  push_font_style_fields(fields)
  push_geometry_fields(fields)
  push_line_spacing_fields(fields)
  push_indentation_fields(fields)
  push_neighbor_context_fields(fields)
  push_visual_proximity_fields(fields)
  push_layout_region_fields(fields)
  push_reading_order_fields(fields)
  push_cross_page_fields(fields)
  push_diagnostics_fields(fields)
  push_risk_fields(fields)
  push_candidate_fact_fields(fields)
  push_model_gate_input_fields(fields)
  push_training_export_metadata_fields(fields)
  fields
}

///|
fn push_identity_fields(fields : Array[PdfV2FeatureField]) -> Unit {
  fields.push(
    available_field(
      "doc_id",
      PdfV2FeatureGroup::Identity,
      PdfV2FeatureValueKind::String,
      PdfV2FeatureSource::Derived,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "page_index",
      PdfV2FeatureGroup::Identity,
      PdfV2FeatureValueKind::Int,
      PdfV2FeatureSource::NormalizedModel,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "block_id",
      PdfV2FeatureGroup::Identity,
      PdfV2FeatureValueKind::String,
      PdfV2FeatureSource::NormalizedModel,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "line_ids",
      PdfV2FeatureGroup::Identity,
      PdfV2FeatureValueKind::StringList,
      PdfV2FeatureSource::NormalizedModel,
      false,
      true,
    ),
  )
  fields.push(
    available_field(
      "source_refs",
      PdfV2FeatureGroup::Identity,
      PdfV2FeatureValueKind::StringList,
      PdfV2FeatureSource::NormalizedModel,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "object_refs",
      PdfV2FeatureGroup::Identity,
      PdfV2FeatureValueKind::StringList,
      PdfV2FeatureSource::NormalizedModel,
      true,
      true,
    ),
  )
}

///|
fn push_text_shape_fields(fields : Array[PdfV2FeatureField]) -> Unit {
  fields.push(
    available_field(
      "text",
      PdfV2FeatureGroup::TextShape,
      PdfV2FeatureValueKind::String,
      PdfV2FeatureSource::NormalizedModel,
      false,
      true,
    ),
  )
  fields.push(
    available_field(
      "text_length",
      PdfV2FeatureGroup::TextShape,
      PdfV2FeatureValueKind::Int,
      PdfV2FeatureSource::Derived,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "line_count",
      PdfV2FeatureGroup::TextShape,
      PdfV2FeatureValueKind::Int,
      PdfV2FeatureSource::NormalizedModel,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "char_count",
      PdfV2FeatureGroup::TextShape,
      PdfV2FeatureValueKind::Int,
      PdfV2FeatureSource::Derived,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "word_count",
      PdfV2FeatureGroup::TextShape,
      PdfV2FeatureValueKind::Int,
      PdfV2FeatureSource::Derived,
      true,
      true,
    ),
  )
  fields.push(
    planned_field(
      "short_text_score",
      PdfV2FeatureGroup::TextShape,
      PdfV2FeatureValueKind::Float,
      PdfV2FeatureSource::FutureParserExport,
      true,
      true,
    ),
  )
  fields.push(
    planned_field(
      "titlecase_ratio",
      PdfV2FeatureGroup::TextShape,
      PdfV2FeatureValueKind::Float,
      PdfV2FeatureSource::FutureParserExport,
      false,
      true,
    ),
  )
  fields.push(
    planned_field(
      "uppercase_ratio",
      PdfV2FeatureGroup::TextShape,
      PdfV2FeatureValueKind::Float,
      PdfV2FeatureSource::FutureParserExport,
      false,
      true,
    ),
  )
  fields.push(
    derived_field(
      "ends_with_period",
      PdfV2FeatureGroup::TextShape,
      PdfV2FeatureValueKind::Bool,
      PdfV2FeatureSource::Derived,
      true,
      true,
    ),
  )
  fields.push(
    derived_field(
      "section_number_prefix",
      PdfV2FeatureGroup::TextShape,
      PdfV2FeatureValueKind::Bool,
      PdfV2FeatureSource::Derived,
      true,
      true,
    ),
  )
  fields.push(
    planned_field(
      "body_density_after",
      PdfV2FeatureGroup::TextShape,
      PdfV2FeatureValueKind::Float,
      PdfV2FeatureSource::FutureParserExport,
      true,
      true,
    ),
  )
  fields.push(
    planned_field(
      "neighbor_body_density",
      PdfV2FeatureGroup::NeighborContext,
      PdfV2FeatureValueKind::Float,
      PdfV2FeatureSource::FutureParserExport,
      true,
      true,
    ),
  )
}

///|
fn push_font_style_fields(fields : Array[PdfV2FeatureField]) -> Unit {
  fields.push(
    available_field(
      "dominant_font_name",
      PdfV2FeatureGroup::FontStyle,
      PdfV2FeatureValueKind::String,
      PdfV2FeatureSource::NormalizedModel,
      false,
      true,
    ),
  )
  fields.push(
    available_field(
      "dominant_font_size",
      PdfV2FeatureGroup::FontStyle,
      PdfV2FeatureValueKind::Float,
      PdfV2FeatureSource::NormalizedModel,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "decode_confidence",
      PdfV2FeatureGroup::FontStyle,
      PdfV2FeatureValueKind::Enum,
      PdfV2FeatureSource::TextReconstruction,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "writing_direction",
      PdfV2FeatureGroup::FontStyle,
      PdfV2FeatureValueKind::Enum,
      PdfV2FeatureSource::NormalizedModel,
      true,
      true,
    ),
  )
  fields.push(
    planned_field(
      "font_size_delta_to_page_body",
      PdfV2FeatureGroup::FontStyle,
      PdfV2FeatureValueKind::Float,
      PdfV2FeatureSource::FutureParserExport,
      true,
      true,
    ),
  )
  fields.push(
    planned_field(
      "font_size_rank_on_page",
      PdfV2FeatureGroup::FontStyle,
      PdfV2FeatureValueKind::Int,
      PdfV2FeatureSource::FutureParserExport,
      true,
      true,
    ),
  )
}

///|
fn push_geometry_fields(fields : Array[PdfV2FeatureField]) -> Unit {
  fields.push(
    available_field(
      "bbox",
      PdfV2FeatureGroup::Geometry,
      PdfV2FeatureValueKind::Bbox,
      PdfV2FeatureSource::NormalizedModel,
      true,
      true,
    ),
  )
  fields.push(
    derived_field(
      "page_relative_bbox",
      PdfV2FeatureGroup::PageRelativeGeometry,
      PdfV2FeatureValueKind::Bbox,
      PdfV2FeatureSource::Derived,
      true,
      true,
    ),
  )
}

///|
fn push_line_spacing_fields(fields : Array[PdfV2FeatureField]) -> Unit {
  fields.push(
    planned_field(
      "aligned_columns_score",
      PdfV2FeatureGroup::LineSpacing,
      PdfV2FeatureValueKind::Float,
      PdfV2FeatureSource::FutureParserExport,
      true,
      true,
    ),
  )
  fields.push(
    planned_field(
      "row_like_spacing_score",
      PdfV2FeatureGroup::LineSpacing,
      PdfV2FeatureValueKind::Float,
      PdfV2FeatureSource::FutureParserExport,
      true,
      true,
    ),
  )
}

///|
fn push_indentation_fields(fields : Array[PdfV2FeatureField]) -> Unit {
  fields.push(
    derived_field(
      "left_indent",
      PdfV2FeatureGroup::Indentation,
      PdfV2FeatureValueKind::Float,
      PdfV2FeatureSource::Derived,
      true,
      true,
    ),
  )
  fields.push(
    derived_field(
      "right_indent",
      PdfV2FeatureGroup::Indentation,
      PdfV2FeatureValueKind::Float,
      PdfV2FeatureSource::Derived,
      false,
      true,
    ),
  )
  fields.push(
    planned_field(
      "hanging_indent_delta",
      PdfV2FeatureGroup::Indentation,
      PdfV2FeatureValueKind::Float,
      PdfV2FeatureSource::FutureParserExport,
      true,
      true,
    ),
  )
  fields.push(
    planned_field(
      "continuation_line_count",
      PdfV2FeatureGroup::Indentation,
      PdfV2FeatureValueKind::Int,
      PdfV2FeatureSource::FutureParserExport,
      true,
      true,
    ),
  )
  fields.push(
    planned_field(
      "sibling_indent_similarity",
      PdfV2FeatureGroup::NeighborContext,
      PdfV2FeatureValueKind::Float,
      PdfV2FeatureSource::FutureParserExport,
      true,
      true,
    ),
  )
}

///|
fn push_neighbor_context_fields(fields : Array[PdfV2FeatureField]) -> Unit {
  fields.push(
    planned_field(
      "same_paragraph_prev_candidate",
      PdfV2FeatureGroup::NeighborContext,
      PdfV2FeatureValueKind::Bool,
      PdfV2FeatureSource::FutureParserExport,
      true,
      true,
    ),
  )
}

///|
fn push_visual_proximity_fields(fields : Array[PdfV2FeatureField]) -> Unit {
  fields.push(
    missing_warning_field(
      "near_image_distance",
      PdfV2FeatureGroup::VisualProximity,
      PdfV2FeatureValueKind::Float,
      PdfV2FeatureSource::FutureParserExport,
      true,
      true,
    ),
  )
  fields.push(
    missing_warning_field(
      "nearest_image_region_id",
      PdfV2FeatureGroup::VisualProximity,
      PdfV2FeatureValueKind::String,
      PdfV2FeatureSource::FutureParserExport,
      true,
      true,
    ),
  )
  fields.push(
    missing_warning_field(
      "near_figure_distance",
      PdfV2FeatureGroup::VisualProximity,
      PdfV2FeatureValueKind::Float,
      PdfV2FeatureSource::FutureParserExport,
      true,
      true,
    ),
  )
  fields.push(
    missing_warning_field(
      "nearest_figure_region_id",
      PdfV2FeatureGroup::VisualProximity,
      PdfV2FeatureValueKind::String,
      PdfV2FeatureSource::FutureParserExport,
      true,
      true,
    ),
  )
  fields.push(
    missing_warning_field(
      "near_table_distance",
      PdfV2FeatureGroup::VisualProximity,
      PdfV2FeatureValueKind::Float,
      PdfV2FeatureSource::FutureParserExport,
      true,
      true,
    ),
  )
  fields.push(
    missing_warning_field(
      "nearest_table_region_id",
      PdfV2FeatureGroup::VisualProximity,
      PdfV2FeatureValueKind::String,
      PdfV2FeatureSource::FutureParserExport,
      true,
      true,
    ),
  )
  fields.push(
    missing_warning_field(
      "visual_overlap_ratio",
      PdfV2FeatureGroup::VisualProximity,
      PdfV2FeatureValueKind::Float,
      PdfV2FeatureSource::FutureParserExport,
      true,
      true,
    ),
  )
  fields.push(
    missing_warning_field(
      "below_visual_region",
      PdfV2FeatureGroup::VisualProximity,
      PdfV2FeatureValueKind::Bool,
      PdfV2FeatureSource::FutureParserExport,
      true,
      true,
    ),
  )
  fields.push(
    missing_warning_field(
      "above_table_or_figure",
      PdfV2FeatureGroup::VisualProximity,
      PdfV2FeatureValueKind::Bool,
      PdfV2FeatureSource::FutureParserExport,
      true,
      true,
    ),
  )
  fields.push(
    planned_field(
      "same_page_visual_density",
      PdfV2FeatureGroup::VisualProximity,
      PdfV2FeatureValueKind::Float,
      PdfV2FeatureSource::FutureParserExport,
      false,
      true,
    ),
  )
  fields.push(
    planned_field(
      "near_vector_grid",
      PdfV2FeatureGroup::VisualProximity,
      PdfV2FeatureValueKind::Bool,
      PdfV2FeatureSource::FutureParserExport,
      true,
      true,
    ),
  )
}

///|
fn push_layout_region_fields(fields : Array[PdfV2FeatureField]) -> Unit {
  fields.push(
    available_field(
      "layout_region_kind",
      PdfV2FeatureGroup::LayoutRegion,
      PdfV2FeatureValueKind::Enum,
      PdfV2FeatureSource::LayoutRecovery,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "layout_region_confidence",
      PdfV2FeatureGroup::LayoutRegion,
      PdfV2FeatureValueKind::Float,
      PdfV2FeatureSource::LayoutRecovery,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "layout_region_ids",
      PdfV2FeatureGroup::LayoutRegion,
      PdfV2FeatureValueKind::StringList,
      PdfV2FeatureSource::LayoutRecovery,
      false,
      true,
    ),
  )
  fields.push(
    available_field(
      "caption_region_confidence",
      PdfV2FeatureGroup::LayoutRegion,
      PdfV2FeatureValueKind::Float,
      PdfV2FeatureSource::LayoutRecovery,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "table_region_confidence",
      PdfV2FeatureGroup::LayoutRegion,
      PdfV2FeatureValueKind::Float,
      PdfV2FeatureSource::LayoutRecovery,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "multi_column_risk",
      PdfV2FeatureGroup::LayoutRegion,
      PdfV2FeatureValueKind::Bool,
      PdfV2FeatureSource::LayoutRecovery,
      true,
      true,
    ),
  )
}

///|
fn push_reading_order_fields(fields : Array[PdfV2FeatureField]) -> Unit {
  fields.push(
    available_field(
      "reading_order_index",
      PdfV2FeatureGroup::ReadingOrder,
      PdfV2FeatureValueKind::Int,
      PdfV2FeatureSource::LayoutRecovery,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "reading_order_confidence",
      PdfV2FeatureGroup::ReadingOrder,
      PdfV2FeatureValueKind::Float,
      PdfV2FeatureSource::LayoutRecovery,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "layout_uncertain",
      PdfV2FeatureGroup::ReadingOrder,
      PdfV2FeatureValueKind::Bool,
      PdfV2FeatureSource::LayoutRecovery,
      true,
      true,
    ),
  )
}

///|
fn push_cross_page_fields(fields : Array[PdfV2FeatureField]) -> Unit {
  fields.push(
    available_field(
      "cross_page_boundary_kind",
      PdfV2FeatureGroup::CrossPage,
      PdfV2FeatureValueKind::StringList,
      PdfV2FeatureSource::LayoutRecovery,
      true,
      true,
    ),
  )
}

///|
fn push_diagnostics_fields(fields : Array[PdfV2FeatureField]) -> Unit {
  fields.push(
    available_field(
      "warning_count",
      PdfV2FeatureGroup::Diagnostics,
      PdfV2FeatureValueKind::Int,
      PdfV2FeatureSource::Diagnostics,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "risk_count",
      PdfV2FeatureGroup::Diagnostics,
      PdfV2FeatureValueKind::Int,
      PdfV2FeatureSource::Diagnostics,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "decode_low_confidence_count",
      PdfV2FeatureGroup::Diagnostics,
      PdfV2FeatureValueKind::Int,
      PdfV2FeatureSource::Diagnostics,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "failed_decode_count",
      PdfV2FeatureGroup::Diagnostics,
      PdfV2FeatureValueKind::Int,
      PdfV2FeatureSource::Diagnostics,
      true,
      true,
    ),
  )
}

///|
fn push_risk_fields(fields : Array[PdfV2FeatureField]) -> Unit {
  fields.push(
    available_field(
      "low_signal_document",
      PdfV2FeatureGroup::Risk,
      PdfV2FeatureValueKind::Bool,
      PdfV2FeatureSource::Diagnostics,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "low_signal_page",
      PdfV2FeatureGroup::Risk,
      PdfV2FeatureValueKind::Bool,
      PdfV2FeatureSource::Diagnostics,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "malformed_object_risk",
      PdfV2FeatureGroup::Risk,
      PdfV2FeatureValueKind::Bool,
      PdfV2FeatureSource::Diagnostics,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "source_order_inconsistent",
      PdfV2FeatureGroup::Risk,
      PdfV2FeatureValueKind::Bool,
      PdfV2FeatureSource::LayoutRecovery,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "geometry_inconsistent",
      PdfV2FeatureGroup::Risk,
      PdfV2FeatureValueKind::Bool,
      PdfV2FeatureSource::LayoutRecovery,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "ocr_recommended_but_not_fallback",
      PdfV2FeatureGroup::Risk,
      PdfV2FeatureValueKind::Bool,
      PdfV2FeatureSource::LayoutRecovery,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "model_hint_conflict",
      PdfV2FeatureGroup::Risk,
      PdfV2FeatureValueKind::Bool,
      PdfV2FeatureSource::LayoutRecovery,
      true,
      true,
    ),
  )
}

///|
fn push_candidate_fact_fields(fields : Array[PdfV2FeatureField]) -> Unit {
  fields.push(
    available_field(
      "caption_prefix_candidate",
      PdfV2FeatureGroup::CandidateFacts,
      PdfV2FeatureValueKind::Bool,
      PdfV2FeatureSource::TextReconstruction,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "caption_prefix_confidence",
      PdfV2FeatureGroup::CandidateFacts,
      PdfV2FeatureValueKind::Float,
      PdfV2FeatureSource::TextReconstruction,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "list_marker_candidate",
      PdfV2FeatureGroup::CandidateFacts,
      PdfV2FeatureValueKind::Bool,
      PdfV2FeatureSource::TextReconstruction,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "list_marker_kind",
      PdfV2FeatureGroup::CandidateFacts,
      PdfV2FeatureValueKind::String,
      PdfV2FeatureSource::TextReconstruction,
      false,
      true,
    ),
  )
  fields.push(
    available_field(
      "list_marker_text",
      PdfV2FeatureGroup::CandidateFacts,
      PdfV2FeatureValueKind::String,
      PdfV2FeatureSource::TextReconstruction,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "list_marker_confidence",
      PdfV2FeatureGroup::CandidateFacts,
      PdfV2FeatureValueKind::Float,
      PdfV2FeatureSource::TextReconstruction,
      true,
      true,
    ),
  )
  fields.push(
    derived_field(
      "starts_with_enumeration_pattern",
      PdfV2FeatureGroup::CandidateFacts,
      PdfV2FeatureValueKind::Bool,
      PdfV2FeatureSource::Derived,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "wrapped_line_candidate",
      PdfV2FeatureGroup::CandidateFacts,
      PdfV2FeatureValueKind::Bool,
      PdfV2FeatureSource::TextReconstruction,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "heading_shape_candidate",
      PdfV2FeatureGroup::CandidateFacts,
      PdfV2FeatureValueKind::Bool,
      PdfV2FeatureSource::TextReconstruction,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "heading_shape_confidence",
      PdfV2FeatureGroup::CandidateFacts,
      PdfV2FeatureValueKind::Float,
      PdfV2FeatureSource::TextReconstruction,
      true,
      true,
    ),
  )
  fields.push(
    available_field(
      "table_cell_candidate",
      PdfV2FeatureGroup::CandidateFacts,
      PdfV2FeatureValueKind::Bool,
      PdfV2FeatureSource::TextReconstruction,
      true,
      true,
    ),
  )
}

///|
fn push_model_gate_input_fields(fields : Array[PdfV2FeatureField]) -> Unit {
  fields.push(
    available_field(
      "classifier_input_feature",
      PdfV2FeatureGroup::ModelGateInput,
      PdfV2FeatureValueKind::Bool,
      PdfV2FeatureSource::Derived,
      true,
      true,
    ),
  )
}

///|
fn push_training_export_metadata_fields(
  fields : Array[PdfV2FeatureField],
) -> Unit {
  fields.push(
    available_field(
      "feature_contract_version",
      PdfV2FeatureGroup::TrainingExportMetadata,
      PdfV2FeatureValueKind::Enum,
      PdfV2FeatureSource::Derived,
      false,
      true,
    ),
  )
  fields.push(
    available_field(
      "feature_record_reason_tags",
      PdfV2FeatureGroup::TrainingExportMetadata,
      PdfV2FeatureValueKind::StringList,
      PdfV2FeatureSource::Derived,
      false,
      true,
    ),
  )
}

///|
fn available_field(
  name : String,
  group : PdfV2FeatureGroup,
  value_kind : PdfV2FeatureValueKind,
  source : PdfV2FeatureSource,
  required_by_runtime_gate : Bool,
  required_by_training : Bool,
) -> PdfV2FeatureField {
  field(
    name,
    group,
    value_kind,
    PdfV2FeatureAvailability::Available,
    source,
    required_by_runtime_gate,
    required_by_training,
    "use_parser_fact",
    ["available", "parser_owned"],
  )
}

///|
fn derived_field(
  name : String,
  group : PdfV2FeatureGroup,
  value_kind : PdfV2FeatureValueKind,
  source : PdfV2FeatureSource,
  required_by_runtime_gate : Bool,
  required_by_training : Bool,
) -> PdfV2FeatureField {
  field(
    name,
    group,
    value_kind,
    PdfV2FeatureAvailability::DerivedAvailable,
    source,
    required_by_runtime_gate,
    required_by_training,
    "derive_from_parser_fact",
    ["derived_available", "parser_owned"],
  )
}

///|
fn planned_field(
  name : String,
  group : PdfV2FeatureGroup,
  value_kind : PdfV2FeatureValueKind,
  source : PdfV2FeatureSource,
  required_by_runtime_gate : Bool,
  required_by_training : Bool,
) -> PdfV2FeatureField {
  field(
    name,
    group,
    value_kind,
    PdfV2FeatureAvailability::Planned,
    source,
    required_by_runtime_gate,
    required_by_training,
    "planned_parser_feature",
    ["planned", "no_silent_loss"],
  )
}

///|
fn missing_warning_field(
  name : String,
  group : PdfV2FeatureGroup,
  value_kind : PdfV2FeatureValueKind,
  source : PdfV2FeatureSource,
  required_by_runtime_gate : Bool,
  required_by_training : Bool,
) -> PdfV2FeatureField {
  field(
    name,
    group,
    value_kind,
    PdfV2FeatureAvailability::MissingWithWarning,
    source,
    required_by_runtime_gate,
    required_by_training,
    "emit_structured_warning",
    ["missing_with_warning", "no_convert_backfill"],
  )
}

///|
fn field(
  name : String,
  group : PdfV2FeatureGroup,
  value_kind : PdfV2FeatureValueKind,
  availability : PdfV2FeatureAvailability,
  source : PdfV2FeatureSource,
  required_by_runtime_gate : Bool,
  required_by_training : Bool,
  missing_behavior : String,
  reason_tags : Array[String],
) -> PdfV2FeatureField {
  {
    name,
    group,
    value_kind,
    availability,
    source,
    required_by_runtime_gate,
    required_by_training,
    missing_behavior,
    reason_tags,
  }
}

///|
fn feature_record_for_block(
  doc : @normalized_model.PdfV2DocumentModel,
  layout : @layout_recovery.PdfV2LayoutRecoveryResult,
  page : @normalized_model.PdfV2Page,
  block : @normalized_model.PdfV2TextBlock,
  schema : PdfV2BlockFeatureSchema,
  options : PdfV2FeatureExportOptions,
) -> PdfV2BlockFeatureRecord {
  let line_ids = line_ids_for_block(block)
  let char_count = char_count_for_block(block)
  let word_count = word_count(block.text)
  let page_relative_bbox = page_relative_bbox(block.bbox)
  let regions = regions_for_block(layout.regions, block.id)
  let reading_order = reading_order_for_block(
    layout.reading_orders,
    page.page_index,
    block.id,
  )
  let boundaries = cross_page_boundaries_for_block(
    layout.cross_page_boundaries,
    block.id,
  )
  let warnings = block.warnings + page.warnings
  let risks = block.risks +
    page.risks +
    risks_for_block(layout.layout_risks, block.id, page.page_index)
  let diagnostics : Array[PdfV2FeatureDiagnostic] = []
  let feature_risks : Array[PdfV2FeatureRisk] = []
  let values : Array[PdfV2FeatureValue] = []
  for field in schema.fields {
    let value = value_for_field(
      field, doc, layout, page, block, regions, reading_order, boundaries, options,
    )
    for diagnostic in value.diagnostics {
      diagnostics.push(diagnostic)
    }
    if value.availability == PdfV2FeatureAvailability::MissingWithRisk {
      for diagnostic in value.diagnostics {
        for risk in diagnostic.risks {
          feature_risks.push({
            field_name: field.name,
            risk,
            reason_tags: diagnostic.reason_tags,
          })
        }
      }
    }
    if options.include_planned_fields ||
      value.availability != PdfV2FeatureAvailability::Planned {
      values.push(value)
    }
  }
  {
    doc_id: options.doc_id,
    page_index: page.page_index,
    block_id: block.id,
    line_ids,
    source_refs: block.source_refs,
    object_refs: block.object_refs,
    bbox: block.bbox,
    page_relative_bbox,
    text: if options.include_text {
      block.text
    } else {
      ""
    },
    text_length: block.text.length(),
    line_count: block.lines.length(),
    char_count,
    word_count,
    dominant_font_name: block.dominant_font,
    dominant_font_size: block.dominant_font_size,
    decode_confidence: block.decode_confidence,
    writing_direction: block.writing_direction,
    candidate_fact_tags: candidate_fact_tags(block),
    layout_region_ids: layout_region_ids(regions),
    layout_region_kinds: layout_region_kinds(regions),
    reading_order_index: reading_order.0,
    cross_page_boundary_kinds: cross_page_boundary_kind_names(boundaries),
    warnings,
    risks,
    diagnostics,
    feature_risks,
    values,
    reason_tags: [
      "block_feature_record", "parser_owned", "classifier_ready", "no_final_semantic_labels",
    ],
  }
}

///|
fn value_for_field(
  field : PdfV2FeatureField,
  doc : @normalized_model.PdfV2DocumentModel,
  layout : @layout_recovery.PdfV2LayoutRecoveryResult,
  page : @normalized_model.PdfV2Page,
  block : @normalized_model.PdfV2TextBlock,
  regions : Array[@layout_recovery.PdfV2LayoutRegion],
  reading_order : (Int?, Double?),
  boundaries : Array[@layout_recovery.PdfV2CrossPageBoundary],
  options : PdfV2FeatureExportOptions,
) -> PdfV2FeatureValue {
  match field.name {
    "doc_id" => string_value(field, options.doc_id)
    "page_index" => int_value(field, page.page_index)
    "block_id" => string_value(field, block.id)
    "line_ids" => string_list_value(field, line_ids_for_block(block))
    "source_refs" =>
      string_list_value(field, source_ref_strings(block.source_refs))
    "object_refs" => string_list_value(field, block.object_refs)
    "text" =>
      string_value(field, if options.include_text { block.text } else { "" })
    "text_length" => int_value(field, block.text.length())
    "line_count" => int_value(field, block.lines.length())
    "char_count" => int_value(field, char_count_for_block(block))
    "word_count" => int_value(field, word_count(block.text))
    "dominant_font_name" => optional_string_value(field, block.dominant_font)
    "dominant_font_size" =>
      optional_float_value(field, block.dominant_font_size)
    "decode_confidence" =>
      enum_value(field, decode_confidence_name(block.decode_confidence))
    "writing_direction" =>
      enum_value(field, writing_direction_name(block.writing_direction))
    "font_size_delta_to_page_body" => planned_value(field, options)
    "font_size_rank_on_page" => planned_value(field, options)
    "bbox" => bbox_value(field, block.bbox)
    "page_relative_bbox" => bbox_value(field, page_relative_bbox(block.bbox))
    "aligned_columns_score" => planned_value(field, options)
    "row_like_spacing_score" => planned_value(field, options)
    "left_indent" => float_value(field, block.bbox.x0)
    "right_indent" => float_value(field, 612.0 - block.bbox.x1)
    "hanging_indent_delta" => planned_value(field, options)
    "continuation_line_count" => planned_value(field, options)
    "sibling_indent_similarity" => planned_value(field, options)
    "same_paragraph_prev_candidate" => planned_value(field, options)
    "short_text_score" => planned_value(field, options)
    "titlecase_ratio" => planned_value(field, options)
    "uppercase_ratio" => planned_value(field, options)
    "ends_with_period" => bool_value(field, text_ends_with_period(block.text))
    "section_number_prefix" =>
      bool_value(field, has_section_number_prefix(block.text))
    "body_density_after" => planned_value(field, options)
    "neighbor_body_density" => planned_value(field, options)
    "near_image_distance" => missing_warning_value(field, options)
    "nearest_image_region_id" => missing_warning_value(field, options)
    "near_figure_distance" => missing_warning_value(field, options)
    "nearest_figure_region_id" => missing_warning_value(field, options)
    "near_table_distance" => missing_warning_value(field, options)
    "nearest_table_region_id" => missing_warning_value(field, options)
    "visual_overlap_ratio" => missing_warning_value(field, options)
    "below_visual_region" => missing_warning_value(field, options)
    "above_table_or_figure" => missing_warning_value(field, options)
    "same_page_visual_density" => planned_value(field, options)
    "near_vector_grid" => planned_value(field, options)
    "layout_region_kind" =>
      enum_value(field, primary_layout_region_kind(regions))
    "layout_region_confidence" =>
      float_value(field, primary_layout_region_confidence(regions))
    "layout_region_ids" => string_list_value(field, layout_region_ids(regions))
    "caption_region_confidence" =>
      float_value(field, region_confidence_for_kind(regions, "caption"))
    "table_region_confidence" =>
      float_value(field, region_confidence_for_kind(regions, "table"))
    "multi_column_risk" =>
      bool_value(
        field,
        has_layout_risk_kind(
          layout.layout_risks,
          @layout_recovery.PdfV2LayoutRiskKind::MultiColumnRisk,
          page.page_index,
        ),
      )
    "reading_order_index" => optional_int_value(field, reading_order.0)
    "reading_order_confidence" => optional_float_value(field, reading_order.1)
    "layout_uncertain" =>
      bool_value(
        field,
        layout.summary.abstain ||
        has_uncertain_layout_risk(layout.layout_risks, page.page_index),
      )
    "cross_page_boundary_kind" =>
      string_list_value(field, cross_page_boundary_kind_names(boundaries))
    "warning_count" =>
      int_value(field, block.warnings.length() + page.warnings.length())
    "risk_count" => int_value(field, block.risks.length() + page.risks.length())
    "decode_low_confidence_count" =>
      int_value(
        field,
        if block.decode_confidence ==
          @text_reconstruction.PdfV2DecodeConfidence::Low {
          1
        } else {
          0
        },
      )
    "failed_decode_count" =>
      int_value(
        field,
        if block.decode_confidence ==
          @text_reconstruction.PdfV2DecodeConfidence::Failed {
          1
        } else {
          0
        },
      )
    "low_signal_document" =>
      bool_value(
        field,
        has_pdf_risk_kind(doc.risks, @pdfv2.PdfV2RiskKind::LowSignalDocument),
      )
    "low_signal_page" =>
      bool_value(
        field,
        has_pdf_risk_kind(page.risks, @pdfv2.PdfV2RiskKind::LowSignal) ||
        has_layout_risk_kind(
          layout.layout_risks,
          @layout_recovery.PdfV2LayoutRiskKind::LowSignalLayout,
          page.page_index,
        ),
      )
    "malformed_object_risk" =>
      bool_value(
        field,
        has_pdf_risk_kind(doc.risks, @pdfv2.PdfV2RiskKind::MalformedObject) ||
        has_pdf_risk_kind(page.risks, @pdfv2.PdfV2RiskKind::MalformedObject),
      )
    "source_order_inconsistent" =>
      bool_value(
        field,
        has_layout_risk_kind(
          layout.layout_risks,
          @layout_recovery.PdfV2LayoutRiskKind::SourceOrderInconsistent,
          page.page_index,
        ),
      )
    "geometry_inconsistent" =>
      bool_value(
        field,
        has_layout_risk_kind(
          layout.layout_risks,
          @layout_recovery.PdfV2LayoutRiskKind::GeometryInconsistent,
          page.page_index,
        ),
      )
    "ocr_recommended_but_not_fallback" =>
      bool_value(
        field,
        has_layout_risk_kind(
          layout.layout_risks,
          @layout_recovery.PdfV2LayoutRiskKind::OcrRecommendedButNotFallback,
          page.page_index,
        ),
      )
    "model_hint_conflict" =>
      bool_value(
        field,
        has_layout_risk_kind(
          layout.layout_risks,
          @layout_recovery.PdfV2LayoutRiskKind::ModelHintConflict,
          page.page_index,
        ),
      )
    "caption_prefix_candidate" =>
      bool_value(field, !block.caption_prefix_candidates.is_empty())
    "caption_prefix_confidence" =>
      float_value(field, first_caption_confidence(block))
    "list_marker_candidate" =>
      bool_value(field, !block.list_marker_candidates.is_empty())
    "list_marker_kind" => string_value(field, list_marker_kind(block))
    "list_marker_text" => string_value(field, list_marker_text(block))
    "list_marker_confidence" => float_value(field, first_list_confidence(block))
    "starts_with_enumeration_pattern" =>
      bool_value(
        field,
        has_section_number_prefix(block.text) || block.text == "1.",
      )
    "wrapped_line_candidate" =>
      bool_value(
        field,
        has_candidate_tag(block.candidate_facts, "wrapped_line_candidate"),
      )
    "heading_shape_candidate" =>
      bool_value(field, !block.heading_shape_candidates.is_empty())
    "heading_shape_confidence" =>
      float_value(field, first_heading_confidence(block))
    "table_cell_candidate" =>
      bool_value(
        field,
        has_candidate_kind(
          block.candidate_facts,
          @text_reconstruction.PdfV2TextCandidateFactKind::TableCellShapeCandidate,
        ),
      )
    "classifier_input_feature" => bool_value(field, true)
    "feature_contract_version" =>
      enum_value(field, "pdf_v2_feature_contract_reset_7")
    "feature_record_reason_tags" =>
      string_list_value(field, [
        "block_feature_record", "parser_owned", "classifier_ready",
      ])
    _ => unknown_value(field)
  }
}

///|
fn bool_value(field : PdfV2FeatureField, value : Bool) -> PdfV2FeatureValue {
  base_value(field, field.availability, [], bool_value=Some(value))
}

///|
fn int_value(field : PdfV2FeatureField, value : Int) -> PdfV2FeatureValue {
  base_value(field, field.availability, [], int_value=Some(value))
}

///|
fn optional_int_value(
  field : PdfV2FeatureField,
  value : Int?,
) -> PdfV2FeatureValue {
  match value {
    Some(value) => int_value(field, value)
    None =>
      missing_warning_value(field, default_pdf_v2_feature_export_options())
  }
}

///|
fn float_value(field : PdfV2FeatureField, value : Double) -> PdfV2FeatureValue {
  base_value(field, field.availability, [], float_value=Some(value))
}

///|
fn optional_float_value(
  field : PdfV2FeatureField,
  value : Double?,
) -> PdfV2FeatureValue {
  match value {
    Some(value) => float_value(field, value)
    None =>
      missing_warning_value(field, default_pdf_v2_feature_export_options())
  }
}

///|
fn string_value(field : PdfV2FeatureField, value : String) -> PdfV2FeatureValue {
  base_value(field, field.availability, [], string_value=Some(value))
}

///|
fn optional_string_value(
  field : PdfV2FeatureField,
  value : String?,
) -> PdfV2FeatureValue {
  match value {
    Some(value) => string_value(field, value)
    None =>
      missing_warning_value(field, default_pdf_v2_feature_export_options())
  }
}

///|
fn string_list_value(
  field : PdfV2FeatureField,
  value : Array[String],
) -> PdfV2FeatureValue {
  base_value(field, field.availability, [], string_list_value=value)
}

///|
fn bbox_value(
  field : PdfV2FeatureField,
  value : @pdfv2.PdfV2Rect,
) -> PdfV2FeatureValue {
  base_value(field, field.availability, [], bbox_value=Some(value))
}

///|
fn enum_value(field : PdfV2FeatureField, value : String) -> PdfV2FeatureValue {
  base_value(field, field.availability, [], enum_value=Some(value))
}

///|
fn planned_value(
  field : PdfV2FeatureField,
  options : PdfV2FeatureExportOptions,
) -> PdfV2FeatureValue {
  let diagnostics = if options.emit_missing_feature_diagnostics {
    [
      feature_diagnostic(
        field,
        PdfV2FeatureAvailability::Planned,
        "feature is fixed in schema but awaits parser implementation",
      ),
    ]
  } else {
    []
  }
  base_value(field, PdfV2FeatureAvailability::Planned, diagnostics)
}

///|
fn missing_warning_value(
  field : PdfV2FeatureField,
  options : PdfV2FeatureExportOptions,
) -> PdfV2FeatureValue {
  let diagnostics = if options.emit_missing_feature_diagnostics {
    [
      feature_diagnostic(
        field,
        PdfV2FeatureAvailability::MissingWithWarning,
        "feature is unavailable in current parser facts",
      ),
    ]
  } else {
    []
  }
  base_value(field, PdfV2FeatureAvailability::MissingWithWarning, diagnostics)
}

///|
fn unknown_value(field : PdfV2FeatureField) -> PdfV2FeatureValue {
  base_value(field, PdfV2FeatureAvailability::MissingWithRisk, [
    feature_diagnostic(
      field,
      PdfV2FeatureAvailability::MissingWithRisk,
      "unknown feature field",
    ),
  ])
}

///|
fn base_value(
  field : PdfV2FeatureField,
  availability : PdfV2FeatureAvailability,
  diagnostics : Array[PdfV2FeatureDiagnostic],
  bool_value? : Bool? = None,
  int_value? : Int? = None,
  float_value? : Double? = None,
  string_value? : String? = None,
  string_list_value? : Array[String] = [],
  bbox_value? : @pdfv2.PdfV2Rect? = None,
  enum_value? : String? = None,
) -> PdfV2FeatureValue {
  {
    field_name: field.name,
    value_kind: field.value_kind,
    bool_value,
    int_value,
    float_value,
    string_value,
    string_list_value,
    bbox_value,
    enum_value,
    availability,
    source: field.source,
    diagnostics,
    reason_tags: field.reason_tags,
  }
}

///|
fn feature_diagnostic(
  field : PdfV2FeatureField,
  availability : PdfV2FeatureAvailability,
  message : String,
) -> PdfV2FeatureDiagnostic {
  {
    field_name: field.name,
    availability,
    message,
    warnings: if availability == PdfV2FeatureAvailability::MissingWithWarning {
      [
        @pdfv2.pdf_v2_scaffold_warning(
          "pdf_v2 feature export missing feature: " + field.name,
        ),
      ]
    } else {
      []
    },
    risks: if availability == PdfV2FeatureAvailability::MissingWithRisk {
      [
        @pdfv2.pdf_v2_scaffold_risk(
          "pdf_v2 feature export missing risk feature: " + field.name,
        ),
      ]
    } else {
      []
    },
    reason_tags: field.reason_tags + ["feature_diagnostic", "no_silent_loss"],
  }
}

///|
fn line_ids_for_block(
  block : @normalized_model.PdfV2TextBlock,
) -> Array[String] {
  let ids : Array[String] = []
  for line in block.lines {
    ids.push(line.id)
  }
  ids
}

///|
fn char_count_for_block(block : @normalized_model.PdfV2TextBlock) -> Int {
  let mut count = 0
  for line in block.lines {
    for span in line.spans {
      count = count + span.chars.length()
    }
  }
  count
}

///|
fn word_count(text : String) -> Int {
  let mut count = 0
  for part in text.trim().split(" ") {
    if part.trim() != "" {
      count = count + 1
    }
  }
  count
}

///|
fn page_relative_bbox(bbox : @pdfv2.PdfV2Rect) -> @pdfv2.PdfV2Rect {
  {
    x0: bbox.x0 / 612.0,
    y0: bbox.y0 / 792.0,
    x1: bbox.x1 / 612.0,
    y1: bbox.y1 / 792.0,
  }
}

///|
fn regions_for_block(
  regions : Array[@layout_recovery.PdfV2LayoutRegion],
  block_id : String,
) -> Array[@layout_recovery.PdfV2LayoutRegion] {
  let out : Array[@layout_recovery.PdfV2LayoutRegion] = []
  for region in regions {
    for member_block_id in region.member_block_ids {
      if member_block_id == block_id {
        out.push(region)
      }
    }
  }
  out
}

///|
fn reading_order_for_block(
  reading_orders : Array[@layout_recovery.PdfV2ReadingOrder],
  page_index : Int,
  block_id : String,
) -> (Int?, Double?) {
  for reading_order in reading_orders {
    if reading_order.page_index == page_index {
      for candidate in reading_order.candidates {
        for i = 0; i < candidate.ordered_block_ids.length(); i = i + 1 {
          if candidate.ordered_block_ids[i] == block_id {
            return (Some(i), Some(candidate.confidence))
          }
        }
      }
    }
  }
  (None, None)
}

///|
fn cross_page_boundaries_for_block(
  boundaries : Array[@layout_recovery.PdfV2CrossPageBoundary],
  block_id : String,
) -> Array[@layout_recovery.PdfV2CrossPageBoundary] {
  let out : Array[@layout_recovery.PdfV2CrossPageBoundary] = []
  for boundary in boundaries {
    if boundary.from_block_id == Some(block_id) ||
      boundary.to_block_id == Some(block_id) {
      out.push(boundary)
    }
  }
  out
}

///|
fn risks_for_block(
  risks : Array[@layout_recovery.PdfV2LayoutRisk],
  block_id : String,
  page_index : Int,
) -> Array[@pdfv2.PdfV2Risk] {
  let out : Array[@pdfv2.PdfV2Risk] = []
  for layout_risk in risks {
    if layout_risk.risk.page_index == Some(page_index) ||
      layout_risk.risk.affected_ids.contains(block_id) {
      out.push(layout_risk.risk)
    }
  }
  out
}

///|
fn candidate_fact_tags(
  block : @normalized_model.PdfV2TextBlock,
) -> Array[String] {
  let tags : Array[String] = []
  for fact in block.candidate_facts {
    for reason_tag in fact.reason_tags {
      tags.push(reason_tag)
    }
  }
  for candidate in block.list_marker_candidates {
    for reason_tag in candidate.reason_tags {
      tags.push(reason_tag)
    }
  }
  for candidate in block.caption_prefix_candidates {
    for reason_tag in candidate.reason_tags {
      tags.push(reason_tag)
    }
  }
  for candidate in block.heading_shape_candidates {
    for reason_tag in candidate.reason_tags {
      tags.push(reason_tag)
    }
  }
  tags
}

///|
fn layout_region_ids(
  regions : Array[@layout_recovery.PdfV2LayoutRegion],
) -> Array[String] {
  let out : Array[String] = []
  for region in regions {
    out.push(region.id)
  }
  out
}

///|
fn layout_region_kinds(
  regions : Array[@layout_recovery.PdfV2LayoutRegion],
) -> Array[String] {
  let out : Array[String] = []
  for region in regions {
    out.push(layout_region_kind_name(region.kind))
  }
  out
}

///|
fn cross_page_boundary_kind_names(
  boundaries : Array[@layout_recovery.PdfV2CrossPageBoundary],
) -> Array[String] {
  let out : Array[String] = []
  for boundary in boundaries {
    out.push(cross_page_boundary_kind_name(boundary.kind))
  }
  out
}

///|
fn source_ref_strings(refs : Array[@pdfv2.PdfV2SourceRef]) -> Array[String] {
  let out : Array[String] = []
  for source_ref in refs {
    let content_order = match source_ref.content_order_index {
      Some(index) => index.to_string()
      None => "none"
    }
    out.push(
      "page=" +
      source_ref.page_index.to_string() +
      " content_order=" +
      content_order,
    )
  }
  out
}

///|
fn primary_layout_region_kind(
  regions : Array[@layout_recovery.PdfV2LayoutRegion],
) -> String {
  if regions.is_empty() {
    "unknown"
  } else {
    layout_region_kind_name(regions[0].kind)
  }
}

///|
fn primary_layout_region_confidence(
  regions : Array[@layout_recovery.PdfV2LayoutRegion],
) -> Double {
  if regions.is_empty() {
    0.0
  } else {
    regions[0].confidence_score
  }
}

///|
fn region_confidence_for_kind(
  regions : Array[@layout_recovery.PdfV2LayoutRegion],
  kind_name : String,
) -> Double {
  for region in regions {
    if layout_region_kind_name(region.kind) == kind_name {
      return region.confidence_score
    }
  }
  0.0
}

///|
fn has_layout_risk_kind(
  risks : Array[@layout_recovery.PdfV2LayoutRisk],
  kind : @layout_recovery.PdfV2LayoutRiskKind,
  page_index : Int,
) -> Bool {
  for risk in risks {
    if risk.kind == kind &&
      (risk.risk.page_index == None || risk.risk.page_index == Some(page_index)) {
      return true
    }
  }
  false
}

///|
fn has_uncertain_layout_risk(
  risks : Array[@layout_recovery.PdfV2LayoutRisk],
  page_index : Int,
) -> Bool {
  has_layout_risk_kind(
    risks,
    @layout_recovery.PdfV2LayoutRiskKind::ReadingOrderUncertain,
    page_index,
  ) ||
  has_layout_risk_kind(
    risks,
    @layout_recovery.PdfV2LayoutRiskKind::CrossPageBoundaryUncertain,
    page_index,
  ) ||
  has_layout_risk_kind(
    risks,
    @layout_recovery.PdfV2LayoutRiskKind::SourceOrderInconsistent,
    page_index,
  ) ||
  has_layout_risk_kind(
    risks,
    @layout_recovery.PdfV2LayoutRiskKind::GeometryInconsistent,
    page_index,
  ) ||
  has_layout_risk_kind(
    risks,
    @layout_recovery.PdfV2LayoutRiskKind::LowSignalLayout,
    page_index,
  )
}

///|
fn has_pdf_risk_kind(
  risks : Array[@pdfv2.PdfV2Risk],
  kind : @pdfv2.PdfV2RiskKind,
) -> Bool {
  for risk in risks {
    if risk.kind == kind {
      return true
    }
  }
  false
}

///|
fn has_candidate_kind(
  facts : Array[@text_reconstruction.PdfV2TextCandidateFact],
  kind : @text_reconstruction.PdfV2TextCandidateFactKind,
) -> Bool {
  for fact in facts {
    if fact.kind == kind {
      return true
    }
  }
  false
}

///|
fn has_candidate_tag(
  facts : Array[@text_reconstruction.PdfV2TextCandidateFact],
  tag : String,
) -> Bool {
  for fact in facts {
    for reason_tag in fact.reason_tags {
      if reason_tag == tag {
        return true
      }
    }
  }
  false
}

///|
fn first_caption_confidence(block : @normalized_model.PdfV2TextBlock) -> Double {
  if block.caption_prefix_candidates.is_empty() {
    0.0
  } else {
    block.caption_prefix_candidates[0].confidence
  }
}

///|
fn first_list_confidence(block : @normalized_model.PdfV2TextBlock) -> Double {
  if block.list_marker_candidates.is_empty() {
    0.0
  } else {
    block.list_marker_candidates[0].confidence
  }
}

///|
fn first_heading_confidence(block : @normalized_model.PdfV2TextBlock) -> Double {
  if block.heading_shape_candidates.is_empty() {
    0.0
  } else {
    block.heading_shape_candidates[0].confidence
  }
}

///|
fn list_marker_text(block : @normalized_model.PdfV2TextBlock) -> String {
  if block.list_marker_candidates.is_empty() {
    ""
  } else {
    block.list_marker_candidates[0].marker_text
  }
}

///|
fn list_marker_kind(block : @normalized_model.PdfV2TextBlock) -> String {
  if block.list_marker_candidates.is_empty() {
    "none"
  } else if block.list_marker_candidates[0].marker_text == "1." {
    "enumeration"
  } else {
    "bullet"
  }
}

///|
fn text_ends_with_period(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  trimmed.has_suffix(".") || trimmed.has_suffix("。")
}

///|
fn has_section_number_prefix(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  trimmed.has_prefix("1.") ||
  trimmed.has_prefix("2.") ||
  trimmed.has_prefix("3.") ||
  trimmed.has_prefix("1.1")
}

///|
fn decode_confidence_name(
  value : @text_reconstruction.PdfV2DecodeConfidence,
) -> String {
  match value {
    High => "high"
    Medium => "medium"
    Low => "low"
    Failed => "failed"
    Unknown => "unknown"
  }
}

///|
fn writing_direction_name(value : @pdfv2.PdfV2WritingDirection) -> String {
  match value {
    LeftToRight => "left_to_right"
    RightToLeft => "right_to_left"
    TopToBottom => "top_to_bottom"
    BottomToTop => "bottom_to_top"
    Unknown => "unknown"
  }
}

///|
fn layout_region_kind_name(
  value : @layout_recovery.PdfV2LayoutRegionKind,
) -> String {
  match value {
    Page => "page"
    Body => "body"
    Paragraph => "paragraph"
    Table => "table"
    Figure => "figure"
    Image => "image"
    Caption => "caption"
    Header => "header"
    Footer => "footer"
    PageNumber => "page_number"
    Annotation => "annotation"
    Form => "form"
    MultiColumn => "multi_column"
    Unknown => "unknown"
  }
}

///|
fn cross_page_boundary_kind_name(
  value : @layout_recovery.PdfV2CrossPageBoundaryKind,
) -> String {
  match value {
    MergeCandidate => "merge_candidate"
    NoMergeCandidate => "no_merge_candidate"
    Uncertain => "uncertain"
  }
}

///|
fn value_counts(
  records : Array[PdfV2BlockFeatureRecord],
) -> (Int, Int, Int, Int) {
  let mut available = 0
  let mut planned = 0
  let mut missing_warning = 0
  let mut missing_risk = 0
  for record in records {
    for value in record.values {
      match value.availability {
        Available | DerivedAvailable => available = available + 1
        Planned => planned = planned + 1
        MissingWithWarning => missing_warning = missing_warning + 1
        MissingWithRisk => missing_risk = missing_risk + 1
        NotApplicable => ()
      }
    }
  }
  (available, planned, missing_warning, missing_risk)
}

///|
fn copy_warnings(
  warnings : Array[@pdfv2.PdfV2Warning],
) -> Array[@pdfv2.PdfV2Warning] {
  let out : Array[@pdfv2.PdfV2Warning] = []
  for warning in warnings {
    out.push(warning)
  }
  out
}

///|
fn copy_risks(risks : Array[@pdfv2.PdfV2Risk]) -> Array[@pdfv2.PdfV2Risk] {
  let out : Array[@pdfv2.PdfV2Risk] = []
  for risk in risks {
    out.push(risk)
  }
  out
}
