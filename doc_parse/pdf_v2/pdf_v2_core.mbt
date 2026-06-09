///|
pub(all) enum PdfV2CoreFacade {
  PdfCoreRead
  PdfCoreObjects
  PdfCoreStreams
  PdfCoreFilters
  PdfCoreOps
  PdfCoreText
  PdfCoreFonts
  PdfCorePages
  PdfCoreImages
  PdfCoreVectors
  PdfCoreAnnotations
  PdfCoreForms
  PdfCoreOutlines
  PdfCoreMetadata
  PdfCoreSecurity
  PdfCoreDiagnostics
  PdfCoreDebug
  PdfCoreWriteTestOnly
} derive(Eq)

///|
pub(all) struct PdfV2CoreObjectRef {
  object_number : Int
  generation : Int
}

///|
pub(all) struct PdfV2CoreStreamRef {
  object_ref : PdfV2CoreObjectRef?
  stream_index : Int
}

///|
pub(all) struct PdfV2CoreCapability {
  name : String
  kind : PdfV2CoreCapabilityKind
  facade : PdfV2CoreFacade
  support_status : PdfV2CapabilitySupportStatus
  runtime_requirement : PdfV2RuntimeRequirement
  source_layer_visibility : PdfV2SourceLayerVisibility
  training_export_relevance : PdfV2TrainingExportRelevance
  warning_kind : PdfV2WarningKind?
  risk_kind : PdfV2RiskKind?
  reason_tags : Array[String]
  notes : String
}

///|
pub let pdf_v2_reader_backend_contract : String = "mbtpdf-backed"

///|
pub let pdf_v2_low_level_parser_owner : String = "vendor/mbtpdf"

///|
pub let pdf_v2_self_written_core_allowed : Bool = false

///|
pub let pdf_v2_default_reader_entry_contract : String = "scaffold-only"

///|
pub let pdf_v2_perf_reader_entry_contract : String = "authorized-mbtpdf-reader"

///|
pub(all) struct PdfV2CorePage {
  page_index : Int
  boxes : PdfV2PageBoxes
  rotation : Int
  user_unit : Double?
  object_ref : String?
  content_stream_refs : Array[String]
}

///|
pub(all) enum PdfV2CoreObjectKind {
  Catalog
  Pages
  Page
  Font
  Stream
  Other
  Malformed
} derive(Eq)

///|
pub(all) struct PdfV2CoreObject {
  object_ref : String
  object_number : Int
  generation : Int
  kind : PdfV2CoreObjectKind
  raw : String
  dictionary : String?
  stream_ref : String?
}

///|
pub(all) struct PdfV2CoreContentStream {
  stream_ref : String
  object_ref : String?
  page_index : Int
  stream_index : Int
  raw_bytes : Bytes?
  decoded_text : String?
  filter_names : Array[String]
  decode_supported : Bool
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  source_ref : PdfV2SourceRef
}

///|
pub(all) struct PdfV2CoreTextEvent {
  id : String
  page_index : Int
  content_order_index : Int
  object_ref : String?
  stream_ref : String?
  stream_index : Int?
  op_index : Int?
  text_object_id : Int?
  operator : String
  text : String
  raw_bytes : Bytes?
  font_name : String?
  font_size : Double?
  origin : PdfV2Point?
  text_matrix : Array[Double]
  decode_confidence : Double
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  source_ref : PdfV2SourceRef
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2ScanBoundary {
  one_pass_required : Bool
  parser_owns_raw_scan : Bool
  convert_raw_reparse_allowed : Bool
  model_export_raw_reparse_allowed : Bool
}

///|
pub(all) struct PdfV2FallbackPolicy {
  legacy_fallback_allowed : Bool
  external_tool_fallback_allowed : Bool
  silent_loss_allowed : Bool
}

///|
pub(all) struct PdfV2RuntimeClosureRule {
  category : PdfV2RuntimeClosureCategory
  allowed_in_normal_runtime : Bool
  runtime_requirement : PdfV2RuntimeRequirement
  notes : String
}

///|
pub(all) struct PdfV2RuntimeClosurePolicy {
  rules : Array[PdfV2RuntimeClosureRule]
  debug_tools_in_runtime_allowed : Bool
  external_model_file_allowed : Bool
  quality_lab_runtime_dependency_allowed : Bool
}

///|
pub(all) struct PdfV2CoreOpenOptions {
  scan_boundary : PdfV2ScanBoundary
  fallback_policy : PdfV2FallbackPolicy
  runtime_closure_policy : PdfV2RuntimeClosurePolicy
}

///|
pub(all) struct PdfV2CoreSourceSummary {
  bytes_len : Int
  page_count : Int
  scanned_once : Bool
  one_pass_required : Bool
  legacy_fallback_allowed : Bool
  convert_raw_reparse_allowed : Bool
  debug_tools_in_runtime_allowed : Bool
  external_model_file_allowed : Bool
  quality_lab_runtime_dependency_allowed : Bool
}

///|
pub(all) struct PdfV2CoreDocument {
  bytes_len : Int
  version : String?
  page_count : Int
  pages : Array[PdfV2CorePage]
  objects : Array[PdfV2CoreObject]
  content_streams : Array[PdfV2CoreContentStream]
  text_events : Array[PdfV2CoreTextEvent]
  capabilities : Array[PdfV2CoreCapability]
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  scanned_once : Bool
  scan_boundary : PdfV2ScanBoundary
  fallback_policy : PdfV2FallbackPolicy
  runtime_closure_policy : PdfV2RuntimeClosurePolicy
  source_summary : PdfV2CoreSourceSummary
}

///|
pub fn pdf_v2_default_scan_boundary() -> PdfV2ScanBoundary {
  {
    one_pass_required: true,
    parser_owns_raw_scan: true,
    convert_raw_reparse_allowed: false,
    model_export_raw_reparse_allowed: false,
  }
}

///|
pub fn pdf_v2_default_fallback_policy() -> PdfV2FallbackPolicy {
  {
    legacy_fallback_allowed: false,
    external_tool_fallback_allowed: false,
    silent_loss_allowed: false,
  }
}

///|
pub fn pdf_v2_runtime_allowed_categories() -> Array[PdfV2RuntimeClosureCategory] {
  [
    PdfV2RuntimeClosureCategory::Read,
    PdfV2RuntimeClosureCategory::Objects,
    PdfV2RuntimeClosureCategory::Xref,
    PdfV2RuntimeClosureCategory::Streams,
    PdfV2RuntimeClosureCategory::Filters,
    PdfV2RuntimeClosureCategory::Pages,
    PdfV2RuntimeClosureCategory::Resources,
    PdfV2RuntimeClosureCategory::ContentOps,
    PdfV2RuntimeClosureCategory::Text,
    PdfV2RuntimeClosureCategory::Fonts,
    PdfV2RuntimeClosureCategory::Images,
    PdfV2RuntimeClosureCategory::Vectors,
    PdfV2RuntimeClosureCategory::Annotations,
    PdfV2RuntimeClosureCategory::Forms,
    PdfV2RuntimeClosureCategory::Outlines,
    PdfV2RuntimeClosureCategory::Metadata,
    PdfV2RuntimeClosureCategory::SecurityMetadata,
    PdfV2RuntimeClosureCategory::Diagnostics,
  ]
}

///|
pub fn pdf_v2_runtime_forbidden_categories() -> Array[
  PdfV2RuntimeClosureCategory,
] {
  [
    PdfV2RuntimeClosureCategory::Writer,
    PdfV2RuntimeClosureCategory::DebugDump,
    PdfV2RuntimeClosureCategory::DebugExamples,
    PdfV2RuntimeClosureCategory::VendorSlowTests,
    PdfV2RuntimeClosureCategory::QualityLabBridge,
    PdfV2RuntimeClosureCategory::TrainingExport,
    PdfV2RuntimeClosureCategory::ModelTraining,
    PdfV2RuntimeClosureCategory::FeatureTsvLoader,
    PdfV2RuntimeClosureCategory::PickleModelLoader,
    PdfV2RuntimeClosureCategory::PythonRuntime,
  ]
}

///|
pub fn pdf_v2_default_runtime_closure_policy() -> PdfV2RuntimeClosurePolicy {
  let rules : Array[PdfV2RuntimeClosureRule] = []
  for category in pdf_v2_runtime_allowed_categories() {
    rules.push({
      category,
      allowed_in_normal_runtime: true,
      runtime_requirement: PdfV2RuntimeRequirement::RuntimeRequired,
      notes: "normal pdf_core_v2 runtime capability",
    })
  }
  for category in pdf_v2_runtime_forbidden_categories() {
    rules.push({
      category,
      allowed_in_normal_runtime: false,
      runtime_requirement: PdfV2RuntimeRequirement::NeverRuntime,
      notes: "forbidden from normal pdf_v2 runtime closure",
    })
  }
  {
    rules,
    debug_tools_in_runtime_allowed: false,
    external_model_file_allowed: false,
    quality_lab_runtime_dependency_allowed: false,
  }
}

///|
pub fn pdf_v2_default_core_open_options() -> PdfV2CoreOpenOptions {
  {
    scan_boundary: pdf_v2_default_scan_boundary(),
    fallback_policy: pdf_v2_default_fallback_policy(),
    runtime_closure_policy: pdf_v2_default_runtime_closure_policy(),
  }
}

///|
pub fn pdf_v2_core_capability_matrix() -> Array[PdfV2CoreCapability] {
  [
    core_cap(
      "object_graph",
      PdfV2CoreCapabilityKind::ObjectGraph,
      PdfV2CoreFacade::PdfCoreObjects,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::RuntimeOnly,
      None,
      None,
      ["object_graph"],
      "typed PDF object graph facade",
    ),
    core_cap(
      "xref_table",
      PdfV2CoreCapabilityKind::XrefTable,
      PdfV2CoreFacade::PdfCoreObjects,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::DiagnosticOnly,
      PdfV2TrainingExportRelevance::RuntimeOnly,
      None,
      None,
      ["xref"],
      "classic xref table support",
    ),
    core_cap(
      "xref_stream",
      PdfV2CoreCapabilityKind::XrefStream,
      PdfV2CoreFacade::PdfCoreObjects,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::DiagnosticOnly,
      PdfV2TrainingExportRelevance::RuntimeOnly,
      None,
      None,
      ["xref"],
      "xref stream support",
    ),
    core_cap(
      "object_stream",
      PdfV2CoreCapabilityKind::ObjectStream,
      PdfV2CoreFacade::PdfCoreObjects,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::DiagnosticOnly,
      PdfV2TrainingExportRelevance::RuntimeOnly,
      Some(PdfV2WarningKind::PartialCapability),
      Some(PdfV2RiskKind::PartialCapability),
      ["object_stream"],
      "object stream expansion with diagnostics",
    ),
    core_cap(
      "compressed_stream",
      PdfV2CoreCapabilityKind::CompressedStream,
      PdfV2CoreFacade::PdfCoreStreams,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::RuntimeOnly,
      Some(PdfV2WarningKind::DecodeFailure),
      Some(PdfV2RiskKind::DecodeFailure),
      ["stream_decode"],
      "compressed stream decode boundary",
    ),
    core_cap(
      "stream_filter",
      PdfV2CoreCapabilityKind::StreamFilter,
      PdfV2CoreFacade::PdfCoreFilters,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::RuntimeOnly,
      Some(PdfV2WarningKind::UnknownFilter),
      Some(PdfV2RiskKind::UnknownFilter),
      ["stream_filter"],
      "common filter support",
    ),
    core_cap(
      "rare_filter",
      PdfV2CoreCapabilityKind::RareFilter,
      PdfV2CoreFacade::PdfCoreFilters,
      PdfV2CapabilitySupportStatus::UnsupportedWithWarning,
      PdfV2RuntimeRequirement::RuntimeOptional,
      PdfV2SourceLayerVisibility::DiagnosticOnly,
      PdfV2TrainingExportRelevance::ReportOnly,
      Some(PdfV2WarningKind::UnknownFilter),
      Some(PdfV2RiskKind::UnknownFilter),
      ["rare_filter", "no_fallback"],
      "rare filters surface warnings rather than fallback",
    ),
    core_cap(
      "encryption_metadata",
      PdfV2CoreCapabilityKind::EncryptionMetadata,
      PdfV2CoreFacade::PdfCoreSecurity,
      PdfV2CapabilitySupportStatus::Planned,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::DiagnosticOnly,
      PdfV2TrainingExportRelevance::ReportOnly,
      Some(PdfV2WarningKind::EncryptedDocument),
      Some(PdfV2RiskKind::EncryptedDocument),
      ["security_metadata"],
      "read encryption state and emit restrictions",
    ),
    core_cap(
      "permissions_metadata",
      PdfV2CoreCapabilityKind::PermissionsMetadata,
      PdfV2CoreFacade::PdfCoreSecurity,
      PdfV2CapabilitySupportStatus::Planned,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::DiagnosticOnly,
      PdfV2TrainingExportRelevance::ReportOnly,
      Some(PdfV2WarningKind::PermissionRestricted),
      Some(PdfV2RiskKind::PermissionRestricted),
      ["permissions"],
      "permissions metadata for fail-closed decisions",
    ),
    core_cap(
      "page_tree",
      PdfV2CoreCapabilityKind::PageTree,
      PdfV2CoreFacade::PdfCorePages,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::RuntimeOnly,
      Some(PdfV2WarningKind::MalformedObject),
      Some(PdfV2RiskKind::MalformedObject),
      ["page_tree"],
      "page tree traversal",
    ),
    core_cap(
      "page_boxes",
      PdfV2CoreCapabilityKind::PageBoxes,
      PdfV2CoreFacade::PdfCorePages,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ExportRelevant,
      None,
      None,
      ["geometry"],
      "media/crop/trim/art boxes",
    ),
    core_cap(
      "page_rotation",
      PdfV2CoreCapabilityKind::PageRotation,
      PdfV2CoreFacade::PdfCorePages,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ExportRelevant,
      None,
      None,
      ["geometry"],
      "page rotation fact",
    ),
    core_cap(
      "page_user_unit",
      PdfV2CoreCapabilityKind::PageUserUnit,
      PdfV2CoreFacade::PdfCorePages,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ExportRelevant,
      None,
      None,
      ["geometry"],
      "user unit scaling fact",
    ),
    core_cap(
      "resource_dictionary",
      PdfV2CoreCapabilityKind::ResourceDictionary,
      PdfV2CoreFacade::PdfCorePages,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::RuntimeOnly,
      Some(PdfV2WarningKind::MissingResource),
      Some(PdfV2RiskKind::MissingResource),
      ["resources"],
      "page resource dictionaries",
    ),
    core_cap(
      "content_stream",
      PdfV2CoreCapabilityKind::ContentStream,
      PdfV2CoreFacade::PdfCoreStreams,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::RuntimeOnly,
      Some(PdfV2WarningKind::DecodeFailure),
      Some(PdfV2RiskKind::DecodeFailure),
      ["content_stream"],
      "page content streams",
    ),
    core_cap(
      "text_operator",
      PdfV2CoreCapabilityKind::TextOperator,
      PdfV2CoreFacade::PdfCoreOps,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ExportRelevant,
      Some(PdfV2WarningKind::DecodeFailure),
      Some(PdfV2RiskKind::DecodeFailure),
      ["text_operator"],
      "BT/ET/Tj/TJ and text showing ops",
    ),
    core_cap(
      "graphics_operator",
      PdfV2CoreCapabilityKind::GraphicsOperator,
      PdfV2CoreFacade::PdfCoreOps,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ExportRelevant,
      Some(PdfV2WarningKind::DecodeFailure),
      Some(PdfV2RiskKind::DecodeFailure),
      ["graphics_operator"],
      "graphics content operators",
    ),
    core_cap(
      "graphics_state",
      PdfV2CoreCapabilityKind::GraphicsState,
      PdfV2CoreFacade::PdfCoreVectors,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ExportRelevant,
      None,
      None,
      ["graphics_state"],
      "graphics state stack facts",
    ),
    core_cap(
      "text_state",
      PdfV2CoreCapabilityKind::TextState,
      PdfV2CoreFacade::PdfCoreText,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ExportRelevant,
      None,
      None,
      ["text_state"],
      "text matrix and font state facts",
    ),
    core_cap(
      "font_dictionary",
      PdfV2CoreCapabilityKind::FontDictionary,
      PdfV2CoreFacade::PdfCoreFonts,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ExportRelevant,
      Some(PdfV2WarningKind::UnknownFontEncoding),
      Some(PdfV2RiskKind::UnknownFontEncoding),
      ["font"],
      "font dictionary parsing",
    ),
    core_cap(
      "embedded_font",
      PdfV2CoreCapabilityKind::EmbeddedFont,
      PdfV2CoreFacade::PdfCoreFonts,
      PdfV2CapabilitySupportStatus::Planned,
      PdfV2RuntimeRequirement::RuntimeOptional,
      PdfV2SourceLayerVisibility::DiagnosticOnly,
      PdfV2TrainingExportRelevance::ReportOnly,
      Some(PdfV2WarningKind::PartialCapability),
      Some(PdfV2RiskKind::PartialCapability),
      ["font"],
      "embedded font metadata",
    ),
    core_cap(
      "font_subset",
      PdfV2CoreCapabilityKind::FontSubset,
      PdfV2CoreFacade::PdfCoreFonts,
      PdfV2CapabilitySupportStatus::Planned,
      PdfV2RuntimeRequirement::RuntimeOptional,
      PdfV2SourceLayerVisibility::DiagnosticOnly,
      PdfV2TrainingExportRelevance::ReportOnly,
      Some(PdfV2WarningKind::PartialCapability),
      Some(PdfV2RiskKind::PartialCapability),
      ["font"],
      "subset prefix and glyph map facts",
    ),
    core_cap(
      "type0_font",
      PdfV2CoreCapabilityKind::Type0Font,
      PdfV2CoreFacade::PdfCoreFonts,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ExportRelevant,
      Some(PdfV2WarningKind::UnknownFontEncoding),
      Some(PdfV2RiskKind::UnknownFontEncoding),
      ["font"],
      "Type0 composite font support",
    ),
    core_cap(
      "type1_font",
      PdfV2CoreCapabilityKind::Type1Font,
      PdfV2CoreFacade::PdfCoreFonts,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ExportRelevant,
      Some(PdfV2WarningKind::UnknownFontEncoding),
      Some(PdfV2RiskKind::UnknownFontEncoding),
      ["font"],
      "Type1 font support",
    ),
    core_cap(
      "truetype_font",
      PdfV2CoreCapabilityKind::TrueTypeFont,
      PdfV2CoreFacade::PdfCoreFonts,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ExportRelevant,
      Some(PdfV2WarningKind::UnknownFontEncoding),
      Some(PdfV2RiskKind::UnknownFontEncoding),
      ["font"],
      "TrueType font support",
    ),
    core_cap(
      "cid_font",
      PdfV2CoreCapabilityKind::CidFont,
      PdfV2CoreFacade::PdfCoreFonts,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ExportRelevant,
      Some(PdfV2WarningKind::UnknownFontEncoding),
      Some(PdfV2RiskKind::UnknownFontEncoding),
      ["font"],
      "CID font support",
    ),
    core_cap(
      "cmap",
      PdfV2CoreCapabilityKind::Cmap,
      PdfV2CoreFacade::PdfCoreFonts,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ExportRelevant,
      Some(PdfV2WarningKind::UnknownFontEncoding),
      Some(PdfV2RiskKind::UnknownFontEncoding),
      ["cmap"],
      "CMap decode support",
    ),
    core_cap(
      "to_unicode",
      PdfV2CoreCapabilityKind::ToUnicode,
      PdfV2CoreFacade::PdfCoreFonts,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ExportRelevant,
      Some(PdfV2WarningKind::GlyphDecodeLowConfidence),
      Some(PdfV2RiskKind::GlyphDecodeLowConfidence),
      ["to_unicode"],
      "ToUnicode map support",
    ),
    core_cap(
      "glyph_decode",
      PdfV2CoreCapabilityKind::GlyphDecode,
      PdfV2CoreFacade::PdfCoreText,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ExportRelevant,
      Some(PdfV2WarningKind::GlyphDecodeLowConfidence),
      Some(PdfV2RiskKind::GlyphDecodeLowConfidence),
      ["glyph_decode"],
      "glyph to unicode decode confidence",
    ),
    core_cap(
      "ligature",
      PdfV2CoreCapabilityKind::Ligature,
      PdfV2CoreFacade::PdfCoreText,
      PdfV2CapabilitySupportStatus::Partial,
      PdfV2RuntimeRequirement::RuntimeOptional,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ExportRelevant,
      Some(PdfV2WarningKind::GlyphDecodeLowConfidence),
      Some(PdfV2RiskKind::GlyphDecodeLowConfidence),
      ["ligature"],
      "ligature expansion facts",
    ),
    core_cap(
      "compatibility_glyph",
      PdfV2CoreCapabilityKind::CompatibilityGlyph,
      PdfV2CoreFacade::PdfCoreText,
      PdfV2CapabilitySupportStatus::Partial,
      PdfV2RuntimeRequirement::RuntimeOptional,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ExportRelevant,
      Some(PdfV2WarningKind::GlyphDecodeLowConfidence),
      Some(PdfV2RiskKind::GlyphDecodeLowConfidence),
      ["compatibility_glyph"],
      "compatibility glyph normalization facts",
    ),
    core_cap(
      "image_xobject",
      PdfV2CoreCapabilityKind::ImageXObject,
      PdfV2CoreFacade::PdfCoreImages,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ExportRelevant,
      Some(PdfV2WarningKind::ImageDecodeSkipped),
      Some(PdfV2RiskKind::ImageDecodeSkipped),
      ["image"],
      "image XObject facts",
    ),
    core_cap(
      "inline_image",
      PdfV2CoreCapabilityKind::InlineImage,
      PdfV2CoreFacade::PdfCoreImages,
      PdfV2CapabilitySupportStatus::Planned,
      PdfV2RuntimeRequirement::RuntimeOptional,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ReportOnly,
      Some(PdfV2WarningKind::ImageDecodeSkipped),
      Some(PdfV2RiskKind::ImageDecodeSkipped),
      ["image"],
      "inline image facts",
    ),
    core_cap(
      "image_mask",
      PdfV2CoreCapabilityKind::ImageMask,
      PdfV2CoreFacade::PdfCoreImages,
      PdfV2CapabilitySupportStatus::Planned,
      PdfV2RuntimeRequirement::RuntimeOptional,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ReportOnly,
      Some(PdfV2WarningKind::ImageDecodeSkipped),
      Some(PdfV2RiskKind::ImageDecodeSkipped),
      ["image_mask"],
      "image mask facts",
    ),
    core_cap(
      "soft_mask",
      PdfV2CoreCapabilityKind::SoftMask,
      PdfV2CoreFacade::PdfCoreImages,
      PdfV2CapabilitySupportStatus::Planned,
      PdfV2RuntimeRequirement::RuntimeOptional,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ReportOnly,
      Some(PdfV2WarningKind::ImageDecodeSkipped),
      Some(PdfV2RiskKind::ImageDecodeSkipped),
      ["soft_mask"],
      "soft mask facts",
    ),
    core_cap(
      "vector_path",
      PdfV2CoreCapabilityKind::VectorPath,
      PdfV2CoreFacade::PdfCoreVectors,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ExportRelevant,
      Some(PdfV2WarningKind::VectorDecodeSkipped),
      Some(PdfV2RiskKind::VectorDecodeSkipped),
      ["vector"],
      "vector path facts",
    ),
    core_cap(
      "stroke_fill",
      PdfV2CoreCapabilityKind::StrokeFill,
      PdfV2CoreFacade::PdfCoreVectors,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ExportRelevant,
      Some(PdfV2WarningKind::VectorDecodeSkipped),
      Some(PdfV2RiskKind::VectorDecodeSkipped),
      ["vector"],
      "stroke and fill facts",
    ),
    core_cap(
      "annotation",
      PdfV2CoreCapabilityKind::Annotation,
      PdfV2CoreFacade::PdfCoreAnnotations,
      PdfV2CapabilitySupportStatus::Planned,
      PdfV2RuntimeRequirement::RuntimeOptional,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ExportRelevant,
      Some(PdfV2WarningKind::AnnotationUnsupported),
      Some(PdfV2RiskKind::AnnotationUnsupported),
      ["annotation"],
      "annotation facts",
    ),
    core_cap(
      "link_annotation",
      PdfV2CoreCapabilityKind::LinkAnnotation,
      PdfV2CoreFacade::PdfCoreAnnotations,
      PdfV2CapabilitySupportStatus::Planned,
      PdfV2RuntimeRequirement::RuntimeOptional,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ExportRelevant,
      Some(PdfV2WarningKind::AnnotationUnsupported),
      Some(PdfV2RiskKind::AnnotationUnsupported),
      ["link_annotation"],
      "link annotation facts",
    ),
    core_cap(
      "destination",
      PdfV2CoreCapabilityKind::Destination,
      PdfV2CoreFacade::PdfCoreOutlines,
      PdfV2CapabilitySupportStatus::Planned,
      PdfV2RuntimeRequirement::RuntimeOptional,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ReportOnly,
      Some(PdfV2WarningKind::PartialCapability),
      Some(PdfV2RiskKind::PartialCapability),
      ["destination"],
      "named destination facts",
    ),
    core_cap(
      "outline",
      PdfV2CoreCapabilityKind::Outline,
      PdfV2CoreFacade::PdfCoreOutlines,
      PdfV2CapabilitySupportStatus::Planned,
      PdfV2RuntimeRequirement::RuntimeOptional,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ReportOnly,
      Some(PdfV2WarningKind::PartialCapability),
      Some(PdfV2RiskKind::PartialCapability),
      ["outline"],
      "outline/bookmark facts",
    ),
    core_cap(
      "metadata_info",
      PdfV2CoreCapabilityKind::MetadataInfo,
      PdfV2CoreFacade::PdfCoreMetadata,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeOptional,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ReportOnly,
      Some(PdfV2WarningKind::MetadataParseWarning),
      Some(PdfV2RiskKind::MetadataParseWarning),
      ["metadata"],
      "Info dictionary metadata",
    ),
    core_cap(
      "xmp_metadata",
      PdfV2CoreCapabilityKind::XmpMetadata,
      PdfV2CoreFacade::PdfCoreMetadata,
      PdfV2CapabilitySupportStatus::Planned,
      PdfV2RuntimeRequirement::RuntimeOptional,
      PdfV2SourceLayerVisibility::SourceVisible,
      PdfV2TrainingExportRelevance::ReportOnly,
      Some(PdfV2WarningKind::MetadataParseWarning),
      Some(PdfV2RiskKind::MetadataParseWarning),
      ["xmp_metadata"],
      "XMP metadata packet",
    ),
    core_cap(
      "acroform",
      PdfV2CoreCapabilityKind::AcroForm,
      PdfV2CoreFacade::PdfCoreForms,
      PdfV2CapabilitySupportStatus::UnsupportedWithWarning,
      PdfV2RuntimeRequirement::RuntimeOptional,
      PdfV2SourceLayerVisibility::DiagnosticOnly,
      PdfV2TrainingExportRelevance::ReportOnly,
      Some(PdfV2WarningKind::FormFieldUnsupported),
      Some(PdfV2RiskKind::FormFieldUnsupported),
      ["acroform", "no_fallback"],
      "AcroForm support must warn until implemented",
    ),
    core_cap(
      "form_field",
      PdfV2CoreCapabilityKind::FormField,
      PdfV2CoreFacade::PdfCoreForms,
      PdfV2CapabilitySupportStatus::UnsupportedWithWarning,
      PdfV2RuntimeRequirement::RuntimeOptional,
      PdfV2SourceLayerVisibility::DiagnosticOnly,
      PdfV2TrainingExportRelevance::ReportOnly,
      Some(PdfV2WarningKind::FormFieldUnsupported),
      Some(PdfV2RiskKind::FormFieldUnsupported),
      ["form_field", "no_fallback"],
      "form fields must warn until implemented",
    ),
    core_cap(
      "optional_content_group",
      PdfV2CoreCapabilityKind::OptionalContentGroup,
      PdfV2CoreFacade::PdfCoreObjects,
      PdfV2CapabilitySupportStatus::UnsupportedWithWarning,
      PdfV2RuntimeRequirement::RuntimeOptional,
      PdfV2SourceLayerVisibility::DiagnosticOnly,
      PdfV2TrainingExportRelevance::ReportOnly,
      Some(PdfV2WarningKind::UnsupportedCapability),
      Some(PdfV2RiskKind::UnsupportedCapability),
      ["optional_content_group", "no_fallback"],
      "OCG visibility must not be silently ignored",
    ),
    core_cap(
      "malformed_object",
      PdfV2CoreCapabilityKind::MalformedObject,
      PdfV2CoreFacade::PdfCoreDiagnostics,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::DiagnosticOnly,
      PdfV2TrainingExportRelevance::ReportOnly,
      Some(PdfV2WarningKind::MalformedObject),
      Some(PdfV2RiskKind::MalformedObject),
      ["malformed_object"],
      "malformed object diagnostics",
    ),
    core_cap(
      "low_signal_document",
      PdfV2CoreCapabilityKind::LowSignalDocument,
      PdfV2CoreFacade::PdfCoreDiagnostics,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2RuntimeRequirement::RuntimeRequired,
      PdfV2SourceLayerVisibility::DiagnosticOnly,
      PdfV2TrainingExportRelevance::ReportOnly,
      Some(PdfV2WarningKind::LowSignalDocument),
      Some(PdfV2RiskKind::LowSignalDocument),
      ["low_signal_document"],
      "low-signal extraction diagnostics",
    ),
  ]
}

///|
pub fn pdf_v2_core_facade_plan() -> Array[PdfV2CoreCapability] {
  pdf_v2_core_capability_matrix()
}

///|
pub fn pdf_v2_core_warning_contract_kinds() -> Array[PdfV2WarningKind] {
  [
    PdfV2WarningKind::UnsupportedCapability,
    PdfV2WarningKind::PartialCapability,
    PdfV2WarningKind::MalformedObject,
    PdfV2WarningKind::DecodeFailure,
    PdfV2WarningKind::EncryptedDocument,
    PdfV2WarningKind::PermissionRestricted,
    PdfV2WarningKind::MissingResource,
    PdfV2WarningKind::UnknownFilter,
    PdfV2WarningKind::UnknownFontEncoding,
    PdfV2WarningKind::GlyphDecodeLowConfidence,
    PdfV2WarningKind::ImageDecodeSkipped,
    PdfV2WarningKind::VectorDecodeSkipped,
    PdfV2WarningKind::AnnotationUnsupported,
    PdfV2WarningKind::FormFieldUnsupported,
    PdfV2WarningKind::MetadataParseWarning,
    PdfV2WarningKind::LowSignalDocument,
    PdfV2WarningKind::OnePassBoundaryViolation,
    PdfV2WarningKind::RuntimeClosureViolation,
    PdfV2WarningKind::FallbackForbiddenViolation,
  ]
}

///|
pub fn pdf_v2_core_risk_contract_kinds() -> Array[PdfV2RiskKind] {
  [
    PdfV2RiskKind::UnsupportedCapability,
    PdfV2RiskKind::PartialCapability,
    PdfV2RiskKind::MalformedObject,
    PdfV2RiskKind::DecodeFailure,
    PdfV2RiskKind::EncryptedDocument,
    PdfV2RiskKind::PermissionRestricted,
    PdfV2RiskKind::MissingResource,
    PdfV2RiskKind::UnknownFilter,
    PdfV2RiskKind::UnknownFontEncoding,
    PdfV2RiskKind::GlyphDecodeLowConfidence,
    PdfV2RiskKind::ImageDecodeSkipped,
    PdfV2RiskKind::VectorDecodeSkipped,
    PdfV2RiskKind::AnnotationUnsupported,
    PdfV2RiskKind::FormFieldUnsupported,
    PdfV2RiskKind::MetadataParseWarning,
    PdfV2RiskKind::LowSignalDocument,
    PdfV2RiskKind::OnePassBoundaryViolation,
    PdfV2RiskKind::RuntimeClosureViolation,
    PdfV2RiskKind::FallbackForbiddenViolation,
  ]
}

///|
fn core_cap(
  name : String,
  kind : PdfV2CoreCapabilityKind,
  facade : PdfV2CoreFacade,
  support_status : PdfV2CapabilitySupportStatus,
  runtime_requirement : PdfV2RuntimeRequirement,
  source_layer_visibility : PdfV2SourceLayerVisibility,
  training_export_relevance : PdfV2TrainingExportRelevance,
  warning_kind : PdfV2WarningKind?,
  risk_kind : PdfV2RiskKind?,
  reason_tags : Array[String],
  notes : String,
) -> PdfV2CoreCapability {
  {
    name,
    kind,
    facade,
    support_status,
    runtime_requirement,
    source_layer_visibility,
    training_export_relevance,
    warning_kind,
    risk_kind,
    reason_tags,
    notes,
  }
}

///|
fn pdf_v2_core_source_summary(
  bytes_len : Int,
  page_count : Int,
  scanned_once : Bool,
  options : PdfV2CoreOpenOptions,
) -> PdfV2CoreSourceSummary {
  {
    bytes_len,
    page_count,
    scanned_once,
    one_pass_required: options.scan_boundary.one_pass_required,
    legacy_fallback_allowed: options.fallback_policy.legacy_fallback_allowed,
    convert_raw_reparse_allowed: options.scan_boundary.convert_raw_reparse_allowed,
    debug_tools_in_runtime_allowed: options.runtime_closure_policy.debug_tools_in_runtime_allowed,
    external_model_file_allowed: options.runtime_closure_policy.external_model_file_allowed,
    quality_lab_runtime_dependency_allowed: options.runtime_closure_policy.quality_lab_runtime_dependency_allowed,
  }
}

///|
pub fn open_pdf_core_v2(bytes : Bytes) -> PdfV2CoreDocument {
  open_pdf_core_v2_scaffold_reader(bytes, pdf_v2_default_core_open_options())
}

///|
pub fn open_pdf_core_v2_perf(bytes : Bytes) -> PdfV2CoreDocument {
  open_pdf_core_v2_perf_reader(bytes, pdf_v2_default_core_open_options())
}
