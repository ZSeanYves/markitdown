///|
pub(all) enum PdfV2Severity {
  Info
  Warning
  Error
  Fatal
} derive(Eq)

///|
pub(all) enum PdfV2WarningKind {
  ScaffoldOnly
  UnsupportedFeature
  UnsupportedCapability
  PartialCapability
  MalformedSource
  MalformedObject
  DecodeFailure
  EncryptedDocument
  PermissionRestricted
  MissingResource
  UnknownFilter
  UnknownFontEncoding
  GlyphDecodeLowConfidence
  ImageDecodeSkipped
  VectorDecodeSkipped
  AnnotationUnsupported
  FormFieldUnsupported
  MetadataParseWarning
  LowSignal
  LowSignalDocument
  OnePassBoundaryViolation
  RuntimeClosureViolation
  FallbackForbiddenViolation
  ExternalModelUnavailable
} derive(Eq)

///|
pub(all) enum PdfV2RiskKind {
  LowSignal
  LowSignalDocument
  MalformedLayout
  MalformedObject
  DecodeFailure
  EncryptedDocument
  PermissionRestricted
  MissingResource
  UnknownFilter
  UnknownFontEncoding
  GlyphDecodeLowConfidence
  ImageDecodeSkipped
  VectorDecodeSkipped
  AnnotationUnsupported
  FormFieldUnsupported
  MetadataParseWarning
  UnsupportedCapability
  PartialCapability
  ModelUnavailable
  SourceOrderConflict
  OnePassBoundaryViolation
  RuntimeClosureViolation
  FallbackForbiddenViolation
  Unknown
} derive(Eq)

///|
pub(all) enum PdfV2RiskSeverity {
  Info
  Warning
  Error
  Fatal
} derive(Eq)

///|
pub(all) enum PdfV2DecisionSource {
  DeterministicConstraint
  ModelHint
  WeakRule
  MixedGate
  Abstain
  Scaffold
} derive(Eq)

///|
pub(all) enum PdfV2WritingDirection {
  LeftToRight
  RightToLeft
  TopToBottom
  BottomToTop
  Unknown
} derive(Eq)

///|
pub(all) enum PdfV2LayoutRegionKind {
  Text
  Title
  SectionHeader
  Table
  Figure
  Caption
  HeaderFooter
  Form
  Artifact
  Unknown
} derive(Eq)

///|
pub(all) enum PdfV2BoundaryHint {
  MergeCandidate
  NoMergeCandidate
  Unknown
} derive(Eq)

///|
pub(all) enum PdfV2FeatureUse {
  RuntimeHighConfidence
  DerivedFeature
  SoftHint
  Abstain
  ReportOnly
} derive(Eq)

///|
pub(all) enum PdfV2CoreCapabilityKind {
  ObjectGraph
  XrefTable
  XrefStream
  ObjectStream
  CompressedStream
  StreamFilter
  RareFilter
  EncryptionMetadata
  PermissionsMetadata
  PageTree
  PageBoxes
  PageRotation
  PageUserUnit
  ResourceDictionary
  ContentStream
  TextOperator
  GraphicsOperator
  GraphicsState
  TextState
  FontDictionary
  EmbeddedFont
  FontSubset
  Type0Font
  Type1Font
  TrueTypeFont
  CidFont
  Cmap
  ToUnicode
  GlyphDecode
  Ligature
  CompatibilityGlyph
  ImageXObject
  InlineImage
  ImageMask
  SoftMask
  VectorPath
  StrokeFill
  Annotation
  LinkAnnotation
  Destination
  Outline
  MetadataInfo
  XmpMetadata
  AcroForm
  FormField
  OptionalContentGroup
  MalformedObject
  LowSignalDocument
} derive(Eq)

///|
pub(all) enum PdfV2CapabilitySupportStatus {
  Required
  Planned
  Partial
  UnsupportedWithWarning
  DebugOnly
  TestOnly
} derive(Eq)

///|
pub(all) enum PdfV2RuntimeRequirement {
  RuntimeRequired
  RuntimeOptional
  DebugOnly
  TestOnly
  NeverRuntime
} derive(Eq)

///|
pub(all) enum PdfV2SourceLayerVisibility {
  SourceVisible
  DiagnosticOnly
  PolicyOnly
  HiddenFromSource
} derive(Eq)

///|
pub(all) enum PdfV2TrainingExportRelevance {
  RuntimeOnly
  ExportRelevant
  ReportOnly
  NotExported
} derive(Eq)

///|
pub(all) enum PdfV2Recoverability {
  Recoverable
  RecoverableWithLoss
  NotRecoverable
} derive(Eq)

///|
pub(all) enum PdfV2RuntimeClosureCategory {
  Read
  Objects
  Xref
  Streams
  Filters
  Pages
  Resources
  ContentOps
  Text
  Fonts
  Images
  Vectors
  Annotations
  Forms
  Outlines
  Metadata
  SecurityMetadata
  Diagnostics
  Writer
  DebugDump
  DebugExamples
  VendorSlowTests
  QualityLabBridge
  TrainingExport
  ModelTraining
  FeatureTsvLoader
  PickleModelLoader
  PythonRuntime
} derive(Eq)

///|
pub(all) struct PdfV2Point {
  x : Double
  y : Double
}

///|
pub(all) struct PdfV2Rect {
  x0 : Double
  y0 : Double
  x1 : Double
  y1 : Double
}

///|
pub(all) struct PdfV2Quad {
  p1 : PdfV2Point
  p2 : PdfV2Point
  p3 : PdfV2Point
  p4 : PdfV2Point
}

///|
pub(all) struct PdfV2Color {
  r : Int
  g : Int
  b : Int
}

///|
pub(all) struct PdfV2PageBoxes {
  media_box : PdfV2Rect
  crop_box : PdfV2Rect?
  bleed_box : PdfV2Rect?
  trim_box : PdfV2Rect?
  art_box : PdfV2Rect?
}

///|
pub(all) struct PdfV2SourceRef {
  page_index : Int
  object_ref : String?
  stream_index : Int?
  op_index : Int?
  content_order_index : Int?
  text_object_id : Int?
}

///|
pub(all) struct PdfV2Warning {
  kind : PdfV2WarningKind
  severity : PdfV2Severity
  capability : PdfV2CoreCapabilityKind?
  message : String
  source_ref : PdfV2SourceRef?
  source_refs : Array[PdfV2SourceRef]
  object_ref : String?
  page_index : Int?
  reason_tags : Array[String]
  recoverability : PdfV2Recoverability
}

///|
pub(all) struct PdfV2Risk {
  kind : PdfV2RiskKind
  severity : PdfV2RiskSeverity
  capability : PdfV2CoreCapabilityKind?
  reason : String
  affected_ids : Array[String]
  source_ref : PdfV2SourceRef?
  source_refs : Array[PdfV2SourceRef]
  object_ref : String?
  page_index : Int?
  reason_tags : Array[String]
  recoverability : PdfV2Recoverability
}

///|
pub(all) struct PdfV2ListMarker {
  marker_text : String
  marker_kind : String
  bbox : PdfV2Rect?
  hanging_indent_delta : Double?
}

///|
pub(all) struct PdfV2FeatureContractField {
  name : String
  level : String
  usage : PdfV2FeatureUse
  required_for_convert : Bool
  required_for_training : Bool
  notes : String
}

///|
pub fn pdf_v2_default_point() -> PdfV2Point {
  { x: 0.0, y: 0.0 }
}

///|
pub fn pdf_v2_default_rect() -> PdfV2Rect {
  { x0: 0.0, y0: 0.0, x1: 0.0, y1: 0.0 }
}

///|
pub fn pdf_v2_default_boxes() -> PdfV2PageBoxes {
  {
    media_box: { x0: 0.0, y0: 0.0, x1: 612.0, y1: 792.0 },
    crop_box: None,
    bleed_box: None,
    trim_box: None,
    art_box: None,
  }
}

///|
pub fn pdf_v2_source_ref_for_page(page_index : Int) -> PdfV2SourceRef {
  {
    page_index,
    object_ref: None,
    stream_index: None,
    op_index: None,
    content_order_index: None,
    text_object_id: None,
  }
}

///|
pub fn pdf_v2_scaffold_warning(message : String) -> PdfV2Warning {
  {
    kind: PdfV2WarningKind::ScaffoldOnly,
    severity: PdfV2Severity::Info,
    capability: None,
    message,
    source_ref: None,
    source_refs: [],
    object_ref: None,
    page_index: None,
    reason_tags: ["scaffold"],
    recoverability: PdfV2Recoverability::Recoverable,
  }
}

///|
pub fn pdf_v2_scaffold_risk(reason : String) -> PdfV2Risk {
  {
    kind: PdfV2RiskKind::ModelUnavailable,
    severity: PdfV2RiskSeverity::Info,
    capability: None,
    reason,
    affected_ids: [],
    source_ref: None,
    source_refs: [],
    object_ref: None,
    page_index: None,
    reason_tags: ["scaffold"],
    recoverability: PdfV2Recoverability::Recoverable,
  }
}

///|
pub fn pdf_v2_capability_warning(
  capability : PdfV2CoreCapabilityKind,
  message : String,
  source_ref : PdfV2SourceRef?,
) -> PdfV2Warning {
  {
    kind: PdfV2WarningKind::UnsupportedCapability,
    severity: PdfV2Severity::Warning,
    capability: Some(capability),
    message,
    source_ref,
    source_refs: match source_ref {
      Some(source_ref) => [source_ref]
      None => []
    },
    object_ref: match source_ref {
      Some(source_ref) => source_ref.object_ref
      None => None
    },
    page_index: match source_ref {
      Some(source_ref) => Some(source_ref.page_index)
      None => None
    },
    reason_tags: ["unsupported_capability", "no_fallback"],
    recoverability: PdfV2Recoverability::RecoverableWithLoss,
  }
}

///|
pub fn pdf_v2_capability_risk(
  capability : PdfV2CoreCapabilityKind,
  reason : String,
  source_ref : PdfV2SourceRef?,
) -> PdfV2Risk {
  {
    kind: PdfV2RiskKind::UnsupportedCapability,
    severity: PdfV2RiskSeverity::Warning,
    capability: Some(capability),
    reason,
    affected_ids: [],
    source_ref,
    source_refs: match source_ref {
      Some(source_ref) => [source_ref]
      None => []
    },
    object_ref: match source_ref {
      Some(source_ref) => source_ref.object_ref
      None => None
    },
    page_index: match source_ref {
      Some(source_ref) => Some(source_ref.page_index)
      None => None
    },
    reason_tags: ["unsupported_capability", "abstain_candidate"],
    recoverability: PdfV2Recoverability::RecoverableWithLoss,
  }
}
