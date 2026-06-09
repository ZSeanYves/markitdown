///|
pub(all) struct PdfV2DiagnosticContext {
  capability : PdfV2CoreCapabilityKind
  source_ref : PdfV2SourceRef?
  object_ref : String?
  page_index : Int?
  affected_ids : Array[String]
}

///|
pub(all) enum PdfV2FilterName {
  FlateDecode
  LZWDecode
  ASCII85Decode
  ASCIIHexDecode
  RunLengthDecode
  CCITTFaxDecode
  JBIG2Decode
  DCTDecode
  JPXDecode
  Crypt
  Unknown
} derive(Eq)

///|
pub(all) struct PdfV2FilterSupport {
  name : PdfV2FilterName
  support_status : PdfV2CapabilitySupportStatus
  capability : PdfV2CoreCapabilityKind
  crypt_filter_requires_security_diagnostic : Bool
  notes : String
}

///|
pub(all) struct PdfV2FilterDiagnostic {
  filter_name : PdfV2FilterName
  raw_name : String
  warning : PdfV2Warning?
  risk : PdfV2Risk?
}

///|
pub(all) struct PdfV2EncryptionState {
  is_encrypted : Bool
  handler_name : String?
  requires_password : Bool
  unsupported_handler : Bool
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2PermissionState {
  permissions_known : Bool
  text_extraction_allowed : Bool
  copy_allowed : Bool
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2SecurityDiagnostic {
  encryption : PdfV2EncryptionState
  permissions : PdfV2PermissionState
  warning : PdfV2Warning?
  risk : PdfV2Risk?
}

///|
pub(all) enum PdfV2ResourceKind {
  Font
  XObject
  Image
  FormXObject
  Pattern
  Shading
  ColorSpace
  GraphicsState
  Properties
  Annotation
  AcroForm
  Outline
  Metadata
} derive(Eq)

///|
pub(all) struct PdfV2ResourceRef {
  kind : PdfV2ResourceKind
  name : String
  page_index : Int
  object_ref : String?
  source_ref : PdfV2SourceRef?
}

///|
pub(all) struct PdfV2PageResourceSummary {
  page_index : Int
  resources : Array[PdfV2ResourceRef]
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
}

///|
pub(all) struct PdfV2ResourceDiagnostic {
  resource : PdfV2ResourceRef
  warning : PdfV2Warning
}

///|
pub fn pdf_v2_diagnostic_context(
  capability : PdfV2CoreCapabilityKind,
  source_ref : PdfV2SourceRef?,
  object_ref : String?,
  page_index : Int?,
  affected_ids : Array[String],
) -> PdfV2DiagnosticContext {
  { capability, source_ref, object_ref, page_index, affected_ids }
}

///|
pub fn pdf_v2_warning_for_context(
  kind : PdfV2WarningKind,
  severity : PdfV2Severity,
  context : PdfV2DiagnosticContext,
  message : String,
  reason_tags : Array[String],
  recoverability : PdfV2Recoverability,
) -> PdfV2Warning {
  {
    kind,
    severity,
    capability: Some(context.capability),
    message,
    source_ref: context.source_ref,
    source_refs: source_refs_from_context(context),
    object_ref: object_ref_from_context(context),
    page_index: page_index_from_context(context),
    reason_tags,
    recoverability,
  }
}

///|
pub fn pdf_v2_risk_for_context(
  kind : PdfV2RiskKind,
  severity : PdfV2RiskSeverity,
  context : PdfV2DiagnosticContext,
  reason : String,
  reason_tags : Array[String],
  recoverability : PdfV2Recoverability,
) -> PdfV2Risk {
  {
    kind,
    severity,
    capability: Some(context.capability),
    reason,
    affected_ids: context.affected_ids,
    source_ref: context.source_ref,
    source_refs: source_refs_from_context(context),
    object_ref: object_ref_from_context(context),
    page_index: page_index_from_context(context),
    reason_tags,
    recoverability,
  }
}

///|
pub fn pdf_v2_filter_support_table() -> Array[PdfV2FilterSupport] {
  [
    filter_support(
      PdfV2FilterName::FlateDecode,
      PdfV2CapabilitySupportStatus::Partial,
      PdfV2CoreCapabilityKind::StreamFilter,
      false,
      "minimal zlib-backed content stream support",
    ),
    filter_support(
      PdfV2FilterName::LZWDecode,
      PdfV2CapabilitySupportStatus::Partial,
      PdfV2CoreCapabilityKind::StreamFilter,
      false,
      "legacy stream filter",
    ),
    filter_support(
      PdfV2FilterName::ASCII85Decode,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2CoreCapabilityKind::StreamFilter,
      false,
      "ASCII85 stream filter",
    ),
    filter_support(
      PdfV2FilterName::ASCIIHexDecode,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2CoreCapabilityKind::StreamFilter,
      false,
      "ASCIIHex stream filter",
    ),
    filter_support(
      PdfV2FilterName::RunLengthDecode,
      PdfV2CapabilitySupportStatus::Required,
      PdfV2CoreCapabilityKind::StreamFilter,
      false,
      "RunLength stream filter",
    ),
    filter_support(
      PdfV2FilterName::CCITTFaxDecode,
      PdfV2CapabilitySupportStatus::Partial,
      PdfV2CoreCapabilityKind::RareFilter,
      false,
      "image-oriented rare filter",
    ),
    filter_support(
      PdfV2FilterName::JBIG2Decode,
      PdfV2CapabilitySupportStatus::UnsupportedWithWarning,
      PdfV2CoreCapabilityKind::RareFilter,
      false,
      "rare image filter emits diagnostics",
    ),
    filter_support(
      PdfV2FilterName::DCTDecode,
      PdfV2CapabilitySupportStatus::Partial,
      PdfV2CoreCapabilityKind::ImageXObject,
      false,
      "JPEG image stream filter",
    ),
    filter_support(
      PdfV2FilterName::JPXDecode,
      PdfV2CapabilitySupportStatus::UnsupportedWithWarning,
      PdfV2CoreCapabilityKind::RareFilter,
      false,
      "JPEG2000 image stream filter emits diagnostics",
    ),
    filter_support(
      PdfV2FilterName::Crypt,
      PdfV2CapabilitySupportStatus::UnsupportedWithWarning,
      PdfV2CoreCapabilityKind::EncryptionMetadata,
      true,
      "Crypt filter requires security diagnostics",
    ),
    filter_support(
      PdfV2FilterName::Unknown,
      PdfV2CapabilitySupportStatus::UnsupportedWithWarning,
      PdfV2CoreCapabilityKind::RareFilter,
      false,
      "unknown filter emits diagnostics",
    ),
  ]
}

///|
pub fn warn_unknown_filter(
  raw_name : String,
  source_ref : PdfV2SourceRef?,
  object_ref : String?,
) -> PdfV2FilterDiagnostic {
  let context = pdf_v2_diagnostic_context(
    PdfV2CoreCapabilityKind::RareFilter,
    source_ref,
    object_ref,
    None,
    [],
  )
  {
    filter_name: PdfV2FilterName::Unknown,
    raw_name,
    warning: Some(
      pdf_v2_warning_for_context(
        PdfV2WarningKind::UnknownFilter,
        PdfV2Severity::Warning,
        context,
        "unknown PDF stream filter",
        ["unknown_filter", "no_fallback", "no_silent_loss"],
        PdfV2Recoverability::RecoverableWithLoss,
      ),
    ),
    risk: None,
  }
}

///|
pub fn warn_rare_filter_unsupported(
  filter_name : PdfV2FilterName,
  raw_name : String,
  source_ref : PdfV2SourceRef?,
  object_ref : String?,
) -> PdfV2FilterDiagnostic {
  let context = pdf_v2_diagnostic_context(
    PdfV2CoreCapabilityKind::RareFilter,
    source_ref,
    object_ref,
    None,
    [],
  )
  {
    filter_name,
    raw_name,
    warning: Some(
      pdf_v2_warning_for_context(
        PdfV2WarningKind::UnknownFilter,
        PdfV2Severity::Warning,
        context,
        "rare PDF stream filter is unsupported in pdf_core_v2 scaffold",
        ["rare_filter_unsupported", "no_fallback"],
        PdfV2Recoverability::RecoverableWithLoss,
      ),
    ),
    risk: Some(
      pdf_v2_risk_for_context(
        PdfV2RiskKind::UnknownFilter,
        PdfV2RiskSeverity::Warning,
        context,
        "rare filter may drop stream-derived facts",
        ["rare_filter_unsupported", "abstain_candidate"],
        PdfV2Recoverability::RecoverableWithLoss,
      ),
    ),
  }
}

///|
pub fn warn_compressed_stream_decode_failure(
  raw_name : String,
  source_ref : PdfV2SourceRef?,
  object_ref : String?,
) -> PdfV2FilterDiagnostic {
  let context = pdf_v2_diagnostic_context(
    PdfV2CoreCapabilityKind::CompressedStream,
    source_ref,
    object_ref,
    None,
    [],
  )
  {
    filter_name: PdfV2FilterName::Unknown,
    raw_name,
    warning: Some(
      pdf_v2_warning_for_context(
        PdfV2WarningKind::DecodeFailure,
        PdfV2Severity::Error,
        context,
        "compressed stream decode failed",
        ["compressed_stream_decode_failure", "no_fallback"],
        PdfV2Recoverability::RecoverableWithLoss,
      ),
    ),
    risk: Some(
      pdf_v2_risk_for_context(
        PdfV2RiskKind::DecodeFailure,
        PdfV2RiskSeverity::Error,
        context,
        "compressed stream decode failure blocks source facts",
        ["compressed_stream_decode_failure", "abstain_candidate"],
        PdfV2Recoverability::RecoverableWithLoss,
      ),
    ),
  }
}

///|
pub fn warn_malformed_object(
  object_ref : String,
  source_ref : PdfV2SourceRef?,
) -> PdfV2Warning {
  pdf_v2_warning_for_context(
    PdfV2WarningKind::MalformedObject,
    PdfV2Severity::Error,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::MalformedObject,
      source_ref,
      Some(object_ref),
      None,
      [object_ref],
    ),
    "malformed PDF object",
    ["malformed_object", "no_fallback"],
    PdfV2Recoverability::RecoverableWithLoss,
  )
}

///|
pub fn warn_missing_object(
  object_ref : String,
  source_ref : PdfV2SourceRef?,
) -> PdfV2Warning {
  pdf_v2_warning_for_context(
    PdfV2WarningKind::MalformedObject,
    PdfV2Severity::Warning,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::ObjectGraph,
      source_ref,
      Some(object_ref),
      None,
      [object_ref],
    ),
    "referenced PDF object is missing",
    ["missing_object", "object_graph", "no_silent_loss"],
    PdfV2Recoverability::RecoverableWithLoss,
  )
}

///|
pub fn warn_invalid_object_ref(
  object_ref : String,
  source_ref : PdfV2SourceRef?,
) -> PdfV2Warning {
  pdf_v2_warning_for_context(
    PdfV2WarningKind::MalformedObject,
    PdfV2Severity::Warning,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::ObjectGraph,
      source_ref,
      Some(object_ref),
      None,
      [object_ref],
    ),
    "invalid PDF object reference",
    ["invalid_object_ref", "object_graph"],
    PdfV2Recoverability::RecoverableWithLoss,
  )
}

///|
pub fn warn_object_stream_partial(
  object_ref : String,
  source_ref : PdfV2SourceRef?,
) -> PdfV2Warning {
  pdf_v2_warning_for_context(
    PdfV2WarningKind::PartialCapability,
    PdfV2Severity::Warning,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::ObjectStream,
      source_ref,
      Some(object_ref),
      None,
      [object_ref],
    ),
    "object stream support is partial",
    ["object_stream_unsupported_or_partial", "no_fallback"],
    PdfV2Recoverability::RecoverableWithLoss,
  )
}

///|
pub fn warn_xref_table_malformed(source_ref : PdfV2SourceRef?) -> PdfV2Warning {
  pdf_v2_warning_for_context(
    PdfV2WarningKind::MalformedObject,
    PdfV2Severity::Error,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::XrefTable,
      source_ref,
      None,
      None,
      [],
    ),
    "xref table is malformed",
    ["xref_table_malformed", "no_fallback"],
    PdfV2Recoverability::RecoverableWithLoss,
  )
}

///|
pub fn warn_xref_stream_malformed(source_ref : PdfV2SourceRef?) -> PdfV2Warning {
  pdf_v2_warning_for_context(
    PdfV2WarningKind::MalformedObject,
    PdfV2Severity::Error,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::XrefStream,
      source_ref,
      None,
      None,
      [],
    ),
    "xref stream is malformed",
    ["xref_stream_malformed", "no_fallback"],
    PdfV2Recoverability::RecoverableWithLoss,
  )
}

///|
pub fn risk_encrypted_document(
  state : PdfV2EncryptionState,
  source_ref : PdfV2SourceRef?,
) -> PdfV2SecurityDiagnostic {
  let context = pdf_v2_diagnostic_context(
    PdfV2CoreCapabilityKind::EncryptionMetadata,
    source_ref,
    None,
    None,
    [],
  )
  let warning = if state.unsupported_handler {
    Some(
      pdf_v2_warning_for_context(
        PdfV2WarningKind::EncryptedDocument,
        PdfV2Severity::Error,
        context,
        "encrypted PDF uses unsupported security handler",
        ["encrypted_document", "unsupported_handler", "no_fallback"],
        PdfV2Recoverability::NotRecoverable,
      ),
    )
  } else {
    None
  }
  {
    encryption: state,
    permissions: pdf_v2_default_permission_state(),
    warning,
    risk: Some(
      pdf_v2_risk_for_context(
        PdfV2RiskKind::EncryptedDocument,
        PdfV2RiskSeverity::Error,
        context,
        "encrypted PDF requires security-aware parsing",
        state.reason_tags,
        PdfV2Recoverability::NotRecoverable,
      ),
    ),
  }
}

///|
pub fn risk_permission_restricted_extraction(
  permissions : PdfV2PermissionState,
  source_ref : PdfV2SourceRef?,
) -> PdfV2SecurityDiagnostic {
  let context = pdf_v2_diagnostic_context(
    PdfV2CoreCapabilityKind::PermissionsMetadata,
    source_ref,
    None,
    None,
    [],
  )
  {
    encryption: pdf_v2_unencrypted_state(),
    permissions,
    warning: None,
    risk: Some(
      pdf_v2_risk_for_context(
        PdfV2RiskKind::PermissionRestricted,
        PdfV2RiskSeverity::Error,
        context,
        "PDF permissions restrict text extraction",
        permissions.reason_tags,
        PdfV2Recoverability::NotRecoverable,
      ),
    ),
  }
}

///|
pub fn pdf_v2_unencrypted_state() -> PdfV2EncryptionState {
  {
    is_encrypted: false,
    handler_name: None,
    requires_password: false,
    unsupported_handler: false,
    reason_tags: ["unencrypted"],
  }
}

///|
pub fn pdf_v2_default_permission_state() -> PdfV2PermissionState {
  {
    permissions_known: false,
    text_extraction_allowed: true,
    copy_allowed: true,
    reason_tags: ["permissions_unknown"],
  }
}

///|
pub fn make_resource_ref(
  kind : PdfV2ResourceKind,
  name : String,
  page_index : Int,
  object_ref : String?,
  source_ref : PdfV2SourceRef?,
) -> PdfV2ResourceRef {
  { kind, name, page_index, object_ref, source_ref }
}

///|
pub fn warn_missing_resource(
  resource : PdfV2ResourceRef,
) -> PdfV2ResourceDiagnostic {
  {
    resource,
    warning: pdf_v2_warning_for_context(
      PdfV2WarningKind::MissingResource,
      PdfV2Severity::Warning,
      pdf_v2_diagnostic_context(
        PdfV2CoreCapabilityKind::ResourceDictionary,
        resource.source_ref,
        resource.object_ref,
        Some(resource.page_index),
        [resource.name],
      ),
      "page resource is missing",
      ["missing_page_resource", "resource_dictionary", "no_silent_loss"],
      PdfV2Recoverability::RecoverableWithLoss,
    ),
  }
}

///|
pub fn warn_missing_font_resource(
  resource : PdfV2ResourceRef,
) -> PdfV2ResourceDiagnostic {
  {
    resource,
    warning: pdf_v2_warning_for_context(
      PdfV2WarningKind::MissingResource,
      PdfV2Severity::Warning,
      pdf_v2_diagnostic_context(
        PdfV2CoreCapabilityKind::FontDictionary,
        resource.source_ref,
        resource.object_ref,
        Some(resource.page_index),
        [resource.name],
      ),
      "font resource is missing",
      ["missing_font_resource", "font_dictionary", "abstain_candidate"],
      PdfV2Recoverability::RecoverableWithLoss,
    ),
  }
}

///|
pub fn warn_missing_xobject_resource(
  resource : PdfV2ResourceRef,
) -> PdfV2ResourceDiagnostic {
  {
    resource,
    warning: pdf_v2_warning_for_context(
      PdfV2WarningKind::MissingResource,
      PdfV2Severity::Warning,
      pdf_v2_diagnostic_context(
        PdfV2CoreCapabilityKind::ImageXObject,
        resource.source_ref,
        resource.object_ref,
        Some(resource.page_index),
        [resource.name],
      ),
      "XObject resource is missing",
      ["missing_xobject_resource", "image_xobject", "no_silent_loss"],
      PdfV2Recoverability::RecoverableWithLoss,
    ),
  }
}

///|
pub fn warn_missing_colorspace_resource(
  resource : PdfV2ResourceRef,
) -> PdfV2ResourceDiagnostic {
  {
    resource,
    warning: pdf_v2_warning_for_context(
      PdfV2WarningKind::MissingResource,
      PdfV2Severity::Warning,
      pdf_v2_diagnostic_context(
        PdfV2CoreCapabilityKind::ResourceDictionary,
        resource.source_ref,
        resource.object_ref,
        Some(resource.page_index),
        [resource.name],
      ),
      "ColorSpace resource is missing",
      ["missing_colorspace_resource", "resource_dictionary"],
      PdfV2Recoverability::RecoverableWithLoss,
    ),
  }
}

///|
pub fn warn_unknown_font_encoding(
  font_ref : PdfV2ResourceRef,
) -> PdfV2ResourceDiagnostic {
  {
    resource: font_ref,
    warning: pdf_v2_warning_for_context(
      PdfV2WarningKind::UnknownFontEncoding,
      PdfV2Severity::Warning,
      pdf_v2_diagnostic_context(
        PdfV2CoreCapabilityKind::FontDictionary,
        font_ref.source_ref,
        font_ref.object_ref,
        Some(font_ref.page_index),
        [font_ref.name],
      ),
      "font encoding is unknown",
      ["unknown_font_encoding", "font_dictionary", "decode_confidence"],
      PdfV2Recoverability::RecoverableWithLoss,
    ),
  }
}

///|
pub fn warn_to_unicode_missing_or_malformed(
  font_ref : PdfV2ResourceRef,
) -> PdfV2ResourceDiagnostic {
  {
    resource: font_ref,
    warning: pdf_v2_warning_for_context(
      PdfV2WarningKind::GlyphDecodeLowConfidence,
      PdfV2Severity::Warning,
      pdf_v2_diagnostic_context(
        PdfV2CoreCapabilityKind::ToUnicode,
        font_ref.source_ref,
        font_ref.object_ref,
        Some(font_ref.page_index),
        [font_ref.name],
      ),
      "ToUnicode map is missing or malformed",
      ["to_unicode_missing_or_malformed", "glyph_decode_low_confidence"],
      PdfV2Recoverability::RecoverableWithLoss,
    ),
  }
}

///|
pub fn risk_glyph_decode_low_confidence(
  source_ref : PdfV2SourceRef?,
  object_ref : String?,
) -> PdfV2Risk {
  pdf_v2_risk_for_context(
    PdfV2RiskKind::GlyphDecodeLowConfidence,
    PdfV2RiskSeverity::Warning,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::GlyphDecode,
      source_ref,
      object_ref,
      None,
      [],
    ),
    "glyph decode confidence is low",
    ["glyph_decode_low_confidence", "abstain_candidate"],
    PdfV2Recoverability::RecoverableWithLoss,
  )
}

///|
pub fn warn_image_decode_skipped(
  resource : PdfV2ResourceRef,
) -> PdfV2ResourceDiagnostic {
  {
    resource,
    warning: pdf_v2_warning_for_context(
      PdfV2WarningKind::ImageDecodeSkipped,
      PdfV2Severity::Warning,
      pdf_v2_diagnostic_context(
        PdfV2CoreCapabilityKind::ImageXObject,
        resource.source_ref,
        resource.object_ref,
        Some(resource.page_index),
        [resource.name],
      ),
      "image decode skipped",
      ["image_decode_skipped", "no_silent_loss"],
      PdfV2Recoverability::RecoverableWithLoss,
    ),
  }
}

///|
pub fn warn_vector_decode_skipped(
  source_ref : PdfV2SourceRef?,
  page_index : Int?,
) -> PdfV2Warning {
  pdf_v2_warning_for_context(
    PdfV2WarningKind::VectorDecodeSkipped,
    PdfV2Severity::Warning,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::VectorPath,
      source_ref,
      None,
      page_index,
      [],
    ),
    "vector decode skipped",
    ["vector_decode_skipped", "no_silent_loss"],
    PdfV2Recoverability::RecoverableWithLoss,
  )
}

///|
pub fn warn_annotation_unsupported(
  resource : PdfV2ResourceRef,
) -> PdfV2ResourceDiagnostic {
  {
    resource,
    warning: pdf_v2_warning_for_context(
      PdfV2WarningKind::AnnotationUnsupported,
      PdfV2Severity::Warning,
      pdf_v2_diagnostic_context(
        PdfV2CoreCapabilityKind::Annotation,
        resource.source_ref,
        resource.object_ref,
        Some(resource.page_index),
        [resource.name],
      ),
      "annotation is unsupported",
      ["annotation_unsupported", "report_only"],
      PdfV2Recoverability::RecoverableWithLoss,
    ),
  }
}

///|
pub fn warn_form_field_unsupported(
  resource : PdfV2ResourceRef,
) -> PdfV2ResourceDiagnostic {
  {
    resource,
    warning: pdf_v2_warning_for_context(
      PdfV2WarningKind::FormFieldUnsupported,
      PdfV2Severity::Warning,
      pdf_v2_diagnostic_context(
        PdfV2CoreCapabilityKind::FormField,
        resource.source_ref,
        resource.object_ref,
        Some(resource.page_index),
        [resource.name],
      ),
      "form field is unsupported",
      ["form_field_unsupported", "report_only"],
      PdfV2Recoverability::RecoverableWithLoss,
    ),
  }
}

///|
pub fn warn_metadata_parse_warning(
  source_ref : PdfV2SourceRef?,
  object_ref : String?,
) -> PdfV2Warning {
  pdf_v2_warning_for_context(
    PdfV2WarningKind::MetadataParseWarning,
    PdfV2Severity::Warning,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::MetadataInfo,
      source_ref,
      object_ref,
      None,
      [],
    ),
    "metadata parse warning",
    ["metadata_parse_warning", "report_only"],
    PdfV2Recoverability::Recoverable,
  )
}

///|
pub fn warn_optional_content_group_unsupported(
  source_ref : PdfV2SourceRef?,
  object_ref : String?,
) -> PdfV2Warning {
  pdf_v2_warning_for_context(
    PdfV2WarningKind::UnsupportedCapability,
    PdfV2Severity::Warning,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::OptionalContentGroup,
      source_ref,
      object_ref,
      None,
      [],
    ),
    "optional content group is unsupported",
    ["optional_content_group_unsupported", "no_silent_loss"],
    PdfV2Recoverability::RecoverableWithLoss,
  )
}

///|
pub fn risk_low_signal_document(reason : String) -> PdfV2Risk {
  pdf_v2_risk_for_context(
    PdfV2RiskKind::LowSignalDocument,
    PdfV2RiskSeverity::Warning,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::LowSignalDocument,
      None,
      None,
      None,
      [],
    ),
    reason,
    ["low_signal_document", "abstain_candidate"],
    PdfV2Recoverability::RecoverableWithLoss,
  )
}

///|
pub fn risk_one_pass_boundary_violation(reason : String) -> PdfV2Risk {
  pdf_v2_risk_for_context(
    PdfV2RiskKind::OnePassBoundaryViolation,
    PdfV2RiskSeverity::Fatal,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::LowSignalDocument,
      None,
      None,
      None,
      [],
    ),
    reason,
    ["one_pass_boundary_violation", "contract_violation"],
    PdfV2Recoverability::NotRecoverable,
  )
}

///|
pub fn risk_runtime_closure_violation(
  category : PdfV2RuntimeClosureCategory,
) -> PdfV2Risk {
  pdf_v2_risk_for_context(
    PdfV2RiskKind::RuntimeClosureViolation,
    PdfV2RiskSeverity::Fatal,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::LowSignalDocument,
      None,
      None,
      None,
      [],
    ),
    "forbidden capability entered normal PDF v2 runtime closure",
    [runtime_closure_tag(category), "runtime_closure_violation"],
    PdfV2Recoverability::NotRecoverable,
  )
}

///|
pub fn risk_fallback_forbidden_violation(reason : String) -> PdfV2Risk {
  pdf_v2_risk_for_context(
    PdfV2RiskKind::FallbackForbiddenViolation,
    PdfV2RiskSeverity::Fatal,
    pdf_v2_diagnostic_context(
      PdfV2CoreCapabilityKind::LowSignalDocument,
      None,
      None,
      None,
      [],
    ),
    reason,
    ["fallback_forbidden_violation", "no_legacy_parser"],
    PdfV2Recoverability::NotRecoverable,
  )
}

///|
fn filter_support(
  name : PdfV2FilterName,
  support_status : PdfV2CapabilitySupportStatus,
  capability : PdfV2CoreCapabilityKind,
  crypt_filter_requires_security_diagnostic : Bool,
  notes : String,
) -> PdfV2FilterSupport {
  {
    name,
    support_status,
    capability,
    crypt_filter_requires_security_diagnostic,
    notes,
  }
}

///|
fn source_refs_from_context(
  context : PdfV2DiagnosticContext,
) -> Array[PdfV2SourceRef] {
  match context.source_ref {
    Some(source_ref) => [source_ref]
    None => []
  }
}

///|
fn object_ref_from_context(context : PdfV2DiagnosticContext) -> String? {
  match context.object_ref {
    Some(object_ref) => Some(object_ref)
    None =>
      match context.source_ref {
        Some(source_ref) => source_ref.object_ref
        None => None
      }
  }
}

///|
fn page_index_from_context(context : PdfV2DiagnosticContext) -> Int? {
  match context.page_index {
    Some(page_index) => Some(page_index)
    None =>
      match context.source_ref {
        Some(source_ref) => Some(source_ref.page_index)
        None => None
      }
  }
}

///|
fn runtime_closure_tag(category : PdfV2RuntimeClosureCategory) -> String {
  match category {
    PdfV2RuntimeClosureCategory::Writer => "writer"
    PdfV2RuntimeClosureCategory::DebugDump => "debug_dump"
    PdfV2RuntimeClosureCategory::DebugExamples => "debug_examples"
    PdfV2RuntimeClosureCategory::VendorSlowTests => "vendor_slow_tests"
    PdfV2RuntimeClosureCategory::QualityLabBridge => "quality_lab_bridge"
    PdfV2RuntimeClosureCategory::TrainingExport => "training_export"
    PdfV2RuntimeClosureCategory::ModelTraining => "model_training"
    PdfV2RuntimeClosureCategory::FeatureTsvLoader => "feature_tsv_loader"
    PdfV2RuntimeClosureCategory::PickleModelLoader => "pickle_model_loader"
    PdfV2RuntimeClosureCategory::PythonRuntime => "python_runtime"
    _ => "runtime_allowed"
  }
}
