///|
test "test_warning_builder_preserves_context" {
  let source_ref = source_ref()
  let context = @pdfv2.pdf_v2_diagnostic_context(
    @pdfv2.PdfV2CoreCapabilityKind::MalformedObject,
    Some(source_ref),
    Some("7 0 R"),
    Some(4),
    ["7 0 R"],
  )
  let warning = @pdfv2.pdf_v2_warning_for_context(
    @pdfv2.PdfV2WarningKind::MalformedObject,
    @pdfv2.PdfV2Severity::Error,
    context,
    "malformed object",
    ["malformed_object", "no_fallback"],
    @pdfv2.PdfV2Recoverability::RecoverableWithLoss,
  )
  assert_true(
    warning.capability == Some(@pdfv2.PdfV2CoreCapabilityKind::MalformedObject),
  )
  assert_true(warning.object_ref == Some("7 0 R"))
  assert_true(warning.page_index == Some(4))
  assert_eq(warning.source_refs.length(), 1)
  assert_eq(warning.reason_tags[1], "no_fallback")
}

///|
test "test_unknown_filter_emits_structured_warning" {
  let diagnostic = @pdfv2.warn_unknown_filter(
    "WeirdDecode",
    Some(source_ref()),
    Some("9 0 R"),
  )
  assert_true(diagnostic.filter_name == @pdfv2.PdfV2FilterName::Unknown)
  match diagnostic.warning {
    Some(warning) => {
      assert_true(warning.kind == @pdfv2.PdfV2WarningKind::UnknownFilter)
      assert_true(warning.object_ref == Some("9 0 R"))
      assert_eq(warning.reason_tags[0], "unknown_filter")
      assert_eq(warning.reason_tags[1], "no_fallback")
    }
    None => fail("expected unknown filter warning")
  }
}

///|
test "test_decode_failure_emits_object_risk" {
  let diagnostic = @pdfv2.warn_compressed_stream_decode_failure(
    "FlateDecode",
    Some(source_ref()),
    Some("10 0 R"),
  )
  match diagnostic.risk {
    Some(risk) => {
      assert_true(risk.kind == @pdfv2.PdfV2RiskKind::DecodeFailure)
      assert_true(risk.severity == @pdfv2.PdfV2RiskSeverity::Error)
      assert_true(risk.object_ref == Some("10 0 R"))
      assert_eq(risk.reason_tags[0], "compressed_stream_decode_failure")
    }
    None => fail("expected decode failure risk")
  }
}

///|
test "test_rare_filter_unsupported_emits_warning_and_risk" {
  let diagnostic = @pdfv2.warn_rare_filter_unsupported(
    @pdfv2.PdfV2FilterName::JBIG2Decode,
    "JBIG2Decode",
    Some(source_ref()),
    Some("11 0 R"),
  )
  match diagnostic.warning {
    Some(warning) =>
      assert_eq(warning.reason_tags[0], "rare_filter_unsupported")
    None => fail("expected rare filter warning")
  }
  match diagnostic.risk {
    Some(risk) =>
      assert_true(
        risk.recoverability == @pdfv2.PdfV2Recoverability::RecoverableWithLoss,
      )
    None => fail("expected rare filter risk")
  }
}

///|
test "test_encrypted_document_emits_security_risk" {
  let state : @pdfv2.PdfV2EncryptionState = {
    is_encrypted: true,
    handler_name: Some("UnknownHandler"),
    requires_password: true,
    unsupported_handler: true,
    reason_tags: ["encrypted_document", "unsupported_handler"],
  }
  let diagnostic = @pdfv2.risk_encrypted_document(state, Some(source_ref()))
  match diagnostic.warning {
    Some(warning) =>
      assert_true(warning.kind == @pdfv2.PdfV2WarningKind::EncryptedDocument)
    None => fail("expected encrypted warning")
  }
  match diagnostic.risk {
    Some(risk) => {
      assert_true(risk.kind == @pdfv2.PdfV2RiskKind::EncryptedDocument)
      assert_true(
        risk.recoverability == @pdfv2.PdfV2Recoverability::NotRecoverable,
      )
      assert_eq(risk.reason_tags[1], "unsupported_handler")
    }
    None => fail("expected encrypted risk")
  }
}

///|
test "test_permission_restricted_extraction_emits_risk" {
  let permissions : @pdfv2.PdfV2PermissionState = {
    permissions_known: true,
    text_extraction_allowed: false,
    copy_allowed: false,
    reason_tags: ["permission_restricted", "text_extraction_forbidden"],
  }
  let diagnostic = @pdfv2.risk_permission_restricted_extraction(
    permissions,
    Some(source_ref()),
  )
  match diagnostic.risk {
    Some(risk) => {
      assert_true(risk.kind == @pdfv2.PdfV2RiskKind::PermissionRestricted)
      assert_true(risk.severity == @pdfv2.PdfV2RiskSeverity::Error)
      assert_eq(risk.reason_tags[0], "permission_restricted")
    }
    None => fail("expected permission risk")
  }
}

///|
test "test_unencrypted_default_has_no_fatal_risk" {
  let state = @pdfv2.pdf_v2_unencrypted_state()
  let permissions = @pdfv2.pdf_v2_default_permission_state()
  assert_eq(state.is_encrypted, false)
  assert_eq(state.unsupported_handler, false)
  assert_eq(permissions.text_extraction_allowed, true)
  assert_eq(permissions.copy_allowed, true)
}

///|
test "test_missing_font_resource_emits_page_context_warning" {
  let resource = @pdfv2.make_resource_ref(
    @pdfv2.PdfV2ResourceKind::Font,
    "F1",
    3,
    Some("14 0 R"),
    Some(source_ref()),
  )
  let diagnostic = @pdfv2.warn_missing_font_resource(resource)
  assert_true(
    diagnostic.warning.capability ==
    Some(@pdfv2.PdfV2CoreCapabilityKind::FontDictionary),
  )
  assert_true(diagnostic.warning.page_index == Some(3))
  assert_eq(diagnostic.warning.reason_tags[0], "missing_font_resource")
}

///|
test "test_missing_xobject_resource_emits_page_context_warning" {
  let resource = @pdfv2.make_resource_ref(
    @pdfv2.PdfV2ResourceKind::Image,
    "Im0",
    6,
    Some("18 0 R"),
    Some(source_ref()),
  )
  let diagnostic = @pdfv2.warn_missing_xobject_resource(resource)
  assert_true(
    diagnostic.warning.capability ==
    Some(@pdfv2.PdfV2CoreCapabilityKind::ImageXObject),
  )
  assert_true(diagnostic.warning.page_index == Some(6))
  assert_true(diagnostic.warning.object_ref == Some("18 0 R"))
}

///|
test "test_one_pass_violation_is_diagnostic_risk" {
  let risk = @pdfv2.risk_one_pass_boundary_violation(
    "convert attempted raw reparse",
  )
  assert_true(risk.kind == @pdfv2.PdfV2RiskKind::OnePassBoundaryViolation)
  assert_true(risk.severity == @pdfv2.PdfV2RiskSeverity::Fatal)
  assert_eq(risk.reason_tags[0], "one_pass_boundary_violation")
}

///|
test "test_fallback_forbidden_violation_is_fatal_or_error" {
  let risk = @pdfv2.risk_fallback_forbidden_violation(
    "legacy parser fallback attempted",
  )
  assert_true(risk.kind == @pdfv2.PdfV2RiskKind::FallbackForbiddenViolation)
  assert_true(risk.severity == @pdfv2.PdfV2RiskSeverity::Fatal)
  assert_eq(risk.reason_tags[1], "no_legacy_parser")
}

///|
test "test_runtime_closure_violation_is_diagnostic_risk" {
  let risk = @pdfv2.risk_runtime_closure_violation(
    @pdfv2.PdfV2RuntimeClosureCategory::TrainingExport,
  )
  assert_true(risk.kind == @pdfv2.PdfV2RiskKind::RuntimeClosureViolation)
  assert_true(risk.severity == @pdfv2.PdfV2RiskSeverity::Fatal)
  assert_eq(risk.reason_tags[0], "training_export")
}

///|
test "test_filter_support_table_links_crypt_to_security" {
  let filters = @pdfv2.pdf_v2_filter_support_table()
  assert_eq(filters.length(), 11)
  assert_true(has_filter(filters, @pdfv2.PdfV2FilterName::FlateDecode))
  assert_true(has_filter(filters, @pdfv2.PdfV2FilterName::Crypt))
  assert_true(crypt_requires_security(filters))
}

///|
test "test_resource_ref_carries_page_object_and_name" {
  let resource = @pdfv2.make_resource_ref(
    @pdfv2.PdfV2ResourceKind::ColorSpace,
    "CS0",
    8,
    Some("20 0 R"),
    Some(source_ref()),
  )
  assert_true(resource.kind == @pdfv2.PdfV2ResourceKind::ColorSpace)
  assert_eq(resource.name, "CS0")
  assert_eq(resource.page_index, 8)
  assert_true(resource.object_ref == Some("20 0 R"))
}

///|
fn source_ref() -> @pdfv2.PdfV2SourceRef {
  {
    page_index: 4,
    object_ref: Some("7 0 R"),
    stream_index: Some(0),
    op_index: Some(2),
    content_order_index: Some(5),
    text_object_id: None,
  }
}

///|
fn has_filter(
  filters : Array[@pdfv2.PdfV2FilterSupport],
  name : @pdfv2.PdfV2FilterName,
) -> Bool {
  for filter in filters {
    if filter.name == name {
      return true
    }
  }
  false
}

///|
fn crypt_requires_security(filters : Array[@pdfv2.PdfV2FilterSupport]) -> Bool {
  for filter in filters {
    if filter.name == @pdfv2.PdfV2FilterName::Crypt {
      return filter.crypt_filter_requires_security_diagnostic
    }
  }
  false
}
