///|
test "pdf v2 core scaffold records one-pass boundary and no fallback policy" {
  let core = @pdfv2.open_pdf_core_v2(Bytes::from_array([37, 80, 68, 70]))
  assert_eq(core.scanned_once, true)
  assert_eq(core.page_count, 0)
  assert_eq(core.warnings.length(), 1)
  assert_eq(core.capabilities.length(), 48)
  assert_eq(core.scan_boundary.one_pass_required, true)
  assert_eq(core.fallback_policy.legacy_fallback_allowed, false)
}

///|
test "pdf v2 parser scaffold builds normalized model without scanning twice" {
  let doc = @pdfv2.parse_pdf_v2_document_from_bytes(
    Bytes::from_array([37, 80, 68, 70]),
  )
  assert_eq(doc.source_summary.scanned_once, true)
  assert_eq(doc.source_summary.page_count, 0)
  assert_eq(doc.warnings.length() > 0, true)
}

///|
test "pdf v2 fail closed gate prioritizes hard constraints" {
  let decision = @pdfv2.pdf_v2_fail_closed_gate(
    ["malformed_bbox"],
    0.99,
    0.30,
    0.0,
  )
  assert_eq(decision.accepted, false)
  assert_eq(decision.abstain, true)
  match decision.blocked_reason {
    Some(reason) => assert_eq(reason, "hard_constraints")
    None => fail("expected blocked reason")
  }
}

///|
test "capability matrix contains required categories" {
  let matrix = @pdfv2.pdf_v2_core_capability_matrix()
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::ObjectGraph), true)
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::XrefTable), true)
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::XrefStream), true)
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::ObjectStream), true)
  assert_eq(
    has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::CompressedStream),
    true,
  )
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::StreamFilter), true)
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::RareFilter), true)
  assert_eq(
    has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::EncryptionMetadata),
    true,
  )
  assert_eq(
    has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::PermissionsMetadata),
    true,
  )
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::PageTree), true)
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::PageBoxes), true)
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::PageRotation), true)
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::PageUserUnit), true)
  assert_eq(
    has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::ResourceDictionary),
    true,
  )
  assert_eq(
    has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::ContentStream),
    true,
  )
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::TextOperator), true)
  assert_eq(
    has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::GraphicsOperator),
    true,
  )
  assert_eq(
    has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::GraphicsState),
    true,
  )
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::TextState), true)
  assert_eq(
    has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::FontDictionary),
    true,
  )
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::EmbeddedFont), true)
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::FontSubset), true)
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::Type0Font), true)
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::Type1Font), true)
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::TrueTypeFont), true)
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::CidFont), true)
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::Cmap), true)
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::ToUnicode), true)
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::GlyphDecode), true)
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::Ligature), true)
  assert_eq(
    has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::CompatibilityGlyph),
    true,
  )
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::ImageXObject), true)
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::InlineImage), true)
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::ImageMask), true)
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::SoftMask), true)
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::VectorPath), true)
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::StrokeFill), true)
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::Annotation), true)
  assert_eq(
    has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::LinkAnnotation),
    true,
  )
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::Destination), true)
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::Outline), true)
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::MetadataInfo), true)
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::XmpMetadata), true)
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::AcroForm), true)
  assert_eq(has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::FormField), true)
  assert_eq(
    has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::OptionalContentGroup),
    true,
  )
  assert_eq(
    has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::MalformedObject),
    true,
  )
  assert_eq(
    has_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::LowSignalDocument),
    true,
  )
}

///|
test "unsupported capability has warning policy" {
  let matrix = @pdfv2.pdf_v2_core_capability_matrix()
  match find_cap(matrix, @pdfv2.PdfV2CoreCapabilityKind::RareFilter) {
    Some(cap) => {
      assert_true(
        cap.support_status ==
        @pdfv2.PdfV2CapabilitySupportStatus::UnsupportedWithWarning,
      )
      assert_true(
        cap.warning_kind == Some(@pdfv2.PdfV2WarningKind::UnknownFilter),
      )
      assert_true(cap.risk_kind == Some(@pdfv2.PdfV2RiskKind::UnknownFilter))
    }
    None => fail("missing rare filter capability")
  }
}

///|
test "warning risk records include source context" {
  let source_ref : @pdfv2.PdfV2SourceRef = {
    page_index: 2,
    object_ref: Some("12 0 R"),
    stream_index: Some(0),
    op_index: Some(7),
    content_order_index: Some(9),
    text_object_id: None,
  }
  let warning = @pdfv2.pdf_v2_capability_warning(
    @pdfv2.PdfV2CoreCapabilityKind::RareFilter,
    "unsupported rare filter",
    Some(source_ref),
  )
  let risk = @pdfv2.pdf_v2_capability_risk(
    @pdfv2.PdfV2CoreCapabilityKind::RareFilter,
    "rare filter skipped",
    Some(source_ref),
  )
  assert_true(
    warning.capability == Some(@pdfv2.PdfV2CoreCapabilityKind::RareFilter),
  )
  assert_true(warning.page_index == Some(2))
  assert_true(warning.object_ref == Some("12 0 R"))
  assert_eq(warning.source_refs.length(), 1)
  assert_true(
    risk.recoverability == @pdfv2.PdfV2Recoverability::RecoverableWithLoss,
  )
  assert_eq(risk.reason_tags[0], "unsupported_capability")
}

///|
test "warning and risk contracts include boundary and decode diagnostics" {
  let warning_kinds = @pdfv2.pdf_v2_core_warning_contract_kinds()
  let risk_kinds = @pdfv2.pdf_v2_core_risk_contract_kinds()
  assert_eq(warning_kinds.length(), 19)
  assert_eq(risk_kinds.length(), 19)
  assert_true(
    has_warning_kind(
      warning_kinds,
      @pdfv2.PdfV2WarningKind::FallbackForbiddenViolation,
    ),
  )
  assert_true(
    has_warning_kind(warning_kinds, @pdfv2.PdfV2WarningKind::DecodeFailure),
  )
  assert_true(
    has_risk_kind(risk_kinds, @pdfv2.PdfV2RiskKind::RuntimeClosureViolation),
  )
  assert_true(has_risk_kind(risk_kinds, @pdfv2.PdfV2RiskKind::UnknownFilter))
}

///|
test "default scan and fallback policy forbids reparse and legacy parser" {
  let options = @pdfv2.pdf_v2_default_core_open_options()
  assert_eq(options.scan_boundary.one_pass_required, true)
  assert_eq(options.scan_boundary.convert_raw_reparse_allowed, false)
  assert_eq(options.scan_boundary.model_export_raw_reparse_allowed, false)
  assert_eq(options.fallback_policy.legacy_fallback_allowed, false)
  assert_eq(options.fallback_policy.external_tool_fallback_allowed, false)
  assert_eq(options.fallback_policy.silent_loss_allowed, false)
}

///|
test "runtime closure forbids debug training writer categories" {
  let policy = @pdfv2.pdf_v2_default_runtime_closure_policy()
  assert_eq(
    runtime_allowed(policy, @pdfv2.PdfV2RuntimeClosureCategory::Read),
    true,
  )
  assert_eq(
    runtime_allowed(policy, @pdfv2.PdfV2RuntimeClosureCategory::Writer),
    false,
  )
  assert_eq(
    runtime_allowed(policy, @pdfv2.PdfV2RuntimeClosureCategory::DebugDump),
    false,
  )
  assert_eq(
    runtime_allowed(policy, @pdfv2.PdfV2RuntimeClosureCategory::TrainingExport),
    false,
  )
  assert_eq(
    runtime_allowed(policy, @pdfv2.PdfV2RuntimeClosureCategory::PythonRuntime),
    false,
  )
  assert_eq(policy.debug_tools_in_runtime_allowed, false)
  assert_eq(policy.external_model_file_allowed, false)
  assert_eq(policy.quality_lab_runtime_dependency_allowed, false)
}

///|
test "core capabilities distinguish runtime debug test requirements" {
  match
    find_cap(
      @pdfv2.pdf_v2_core_capability_matrix(),
      @pdfv2.PdfV2CoreCapabilityKind::TextOperator,
    ) {
    Some(required) =>
      assert_true(
        required.runtime_requirement ==
        @pdfv2.PdfV2RuntimeRequirement::RuntimeRequired,
      )
    None => fail("missing text operator capability")
  }
  let policy = @pdfv2.pdf_v2_default_runtime_closure_policy()
  assert_true(
    runtime_requirement_is(
      policy,
      @pdfv2.PdfV2RuntimeClosureCategory::DebugExamples,
      @pdfv2.PdfV2RuntimeRequirement::NeverRuntime,
    ),
  )
}

///|
fn has_cap(
  matrix : Array[@pdfv2.PdfV2CoreCapability],
  kind : @pdfv2.PdfV2CoreCapabilityKind,
) -> Bool {
  for cap in matrix {
    if cap.kind == kind {
      return true
    }
  }
  false
}

///|
fn find_cap(
  matrix : Array[@pdfv2.PdfV2CoreCapability],
  kind : @pdfv2.PdfV2CoreCapabilityKind,
) -> @pdfv2.PdfV2CoreCapability? {
  for cap in matrix {
    if cap.kind == kind {
      return Some(cap)
    }
  }
  None
}

///|
fn runtime_allowed(
  policy : @pdfv2.PdfV2RuntimeClosurePolicy,
  category : @pdfv2.PdfV2RuntimeClosureCategory,
) -> Bool {
  for rule in policy.rules {
    if rule.category == category {
      return rule.allowed_in_normal_runtime
    }
  }
  false
}

///|
fn runtime_requirement_is(
  policy : @pdfv2.PdfV2RuntimeClosurePolicy,
  category : @pdfv2.PdfV2RuntimeClosureCategory,
  requirement : @pdfv2.PdfV2RuntimeRequirement,
) -> Bool {
  for rule in policy.rules {
    if rule.category == category {
      return rule.runtime_requirement == requirement
    }
  }
  false
}

///|
fn has_warning_kind(
  kinds : Array[@pdfv2.PdfV2WarningKind],
  kind : @pdfv2.PdfV2WarningKind,
) -> Bool {
  for item in kinds {
    if item == kind {
      return true
    }
  }
  false
}

///|
fn has_risk_kind(
  kinds : Array[@pdfv2.PdfV2RiskKind],
  kind : @pdfv2.PdfV2RiskKind,
) -> Bool {
  for item in kinds {
    if item == kind {
      return true
    }
  }
  false
}
