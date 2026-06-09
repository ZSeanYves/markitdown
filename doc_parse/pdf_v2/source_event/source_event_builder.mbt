///|
pub fn build_pdf_v2_source_event_document(
  core : @pdfv2.PdfV2CoreDocument,
  extra_events : Array[PdfV2SourceEvent],
) -> PdfV2SourceDocument {
  let events : Array[PdfV2SourceEvent] = [pdf_v2_document_start_event(core)]
  for page in core.pages {
    events.push(pdf_v2_page_start_event(page.page_index, page.object_ref))
  }
  for event in extra_events {
    events.push(event)
  }
  let warnings = collect_event_warnings(events) + core.warnings
  let risks = collect_event_risks(events) + core.risks
  let pages = build_source_pages(core, events)
  {
    summary: {
      bytes_len: core.bytes_len,
      page_count: pages.length(),
      event_count: events.length(),
      warning_count: warnings.length(),
      risk_count: risks.length(),
      diagnostic_event_count: count_diagnostic_events(events),
      capability_coverage: build_capability_coverage(core.capabilities, events),
      scanned_once: core.scanned_once,
      one_pass_required: core.scan_boundary.one_pass_required,
      legacy_fallback_allowed: core.fallback_policy.legacy_fallback_allowed,
      convert_raw_reparse_allowed: core.scan_boundary.convert_raw_reparse_allowed,
    },
    pages,
    events,
    warnings,
    risks,
  }
}

///|
pub fn pdf_v2_document_start_event(
  core : @pdfv2.PdfV2CoreDocument,
) -> PdfV2SourceEvent {
  {
    id: "doc_start",
    kind: PdfV2SourceEventKind::DocumentStart,
    capability: @pdfv2.PdfV2CoreCapabilityKind::ObjectGraph,
    source_ref: None,
    object_ref: None,
    page_index: None,
    resource_ref: None,
    reason_tags: ["source_event_document_start", "one_pass"],
    severity: @pdfv2.PdfV2Severity::Info,
    recoverability: @pdfv2.PdfV2Recoverability::Recoverable,
    diagnostics: { warnings: core.warnings, risks: core.risks },
  }
}

///|
pub fn pdf_v2_page_start_event(
  page_index : Int,
  object_ref : String?,
) -> PdfV2SourceEvent {
  let source_ref = @pdfv2.pdf_v2_source_ref_for_page(page_index)
  {
    id: "page_start",
    kind: PdfV2SourceEventKind::PageStart,
    capability: @pdfv2.PdfV2CoreCapabilityKind::PageTree,
    source_ref: Some(source_ref),
    object_ref,
    page_index: Some(page_index),
    resource_ref: None,
    reason_tags: ["source_event_page_start"],
    severity: @pdfv2.PdfV2Severity::Info,
    recoverability: @pdfv2.PdfV2Recoverability::Recoverable,
    diagnostics: { warnings: [], risks: [] },
  }
}

///|
pub fn pdf_v2_event_for_warning(
  id : String,
  kind : PdfV2SourceEventKind,
  warning : @pdfv2.PdfV2Warning,
) -> PdfV2SourceEvent {
  {
    id,
    kind,
    capability: match warning.capability {
      Some(capability) => capability
      None => @pdfv2.PdfV2CoreCapabilityKind::LowSignalDocument
    },
    source_ref: warning.source_ref,
    object_ref: warning.object_ref,
    page_index: warning.page_index,
    resource_ref: None,
    reason_tags: warning.reason_tags,
    severity: warning.severity,
    recoverability: warning.recoverability,
    diagnostics: { warnings: [warning], risks: [] },
  }
}

///|
pub fn pdf_v2_event_for_risk(
  id : String,
  kind : PdfV2SourceEventKind,
  risk : @pdfv2.PdfV2Risk,
) -> PdfV2SourceEvent {
  {
    id,
    kind,
    capability: match risk.capability {
      Some(capability) => capability
      None => @pdfv2.PdfV2CoreCapabilityKind::LowSignalDocument
    },
    source_ref: risk.source_ref,
    object_ref: risk.object_ref,
    page_index: risk.page_index,
    resource_ref: None,
    reason_tags: risk.reason_tags,
    severity: risk_severity_to_warning_severity(risk.severity),
    recoverability: risk.recoverability,
    diagnostics: { warnings: [], risks: [risk] },
  }
}

///|
pub fn pdf_v2_event_for_resource_warning(
  id : String,
  diagnostic : @pdfv2.PdfV2ResourceDiagnostic,
) -> PdfV2SourceEvent {
  {
    id,
    kind: PdfV2SourceEventKind::ResourceRef,
    capability: match diagnostic.warning.capability {
      Some(capability) => capability
      None => @pdfv2.PdfV2CoreCapabilityKind::ResourceDictionary
    },
    source_ref: diagnostic.resource.source_ref,
    object_ref: diagnostic.resource.object_ref,
    page_index: Some(diagnostic.resource.page_index),
    resource_ref: Some(diagnostic.resource),
    reason_tags: diagnostic.warning.reason_tags,
    severity: diagnostic.warning.severity,
    recoverability: diagnostic.warning.recoverability,
    diagnostics: { warnings: [diagnostic.warning], risks: [] },
  }
}

///|
pub fn pdf_v2_events_for_filter_diagnostic(
  id_prefix : String,
  diagnostic : @pdfv2.PdfV2FilterDiagnostic,
) -> Array[PdfV2SourceEvent] {
  let events : Array[PdfV2SourceEvent] = []
  match diagnostic.warning {
    Some(warning) =>
      events.push(
        pdf_v2_event_for_warning(
          id_prefix + "_warning",
          PdfV2SourceEventKind::Diagnostic,
          warning,
        ),
      )
    None => ()
  }
  match diagnostic.risk {
    Some(risk) =>
      events.push(
        pdf_v2_event_for_risk(
          id_prefix + "_risk",
          PdfV2SourceEventKind::Diagnostic,
          risk,
        ),
      )
    None => ()
  }
  events
}

///|
pub fn pdf_v2_events_for_security_diagnostic(
  id_prefix : String,
  diagnostic : @pdfv2.PdfV2SecurityDiagnostic,
) -> Array[PdfV2SourceEvent] {
  let events : Array[PdfV2SourceEvent] = []
  match diagnostic.warning {
    Some(warning) =>
      events.push(
        pdf_v2_event_for_warning(
          id_prefix + "_warning",
          PdfV2SourceEventKind::Diagnostic,
          warning,
        ),
      )
    None => ()
  }
  match diagnostic.risk {
    Some(risk) =>
      events.push(
        pdf_v2_event_for_risk(
          id_prefix + "_risk",
          PdfV2SourceEventKind::Diagnostic,
          risk,
        ),
      )
    None => ()
  }
  events
}

///|
pub fn pdf_v2_event_for_fallback_forbidden(reason : String) -> PdfV2SourceEvent {
  pdf_v2_event_for_risk(
    "fallback_forbidden",
    PdfV2SourceEventKind::Diagnostic,
    @pdfv2.risk_fallback_forbidden_violation(reason),
  )
}

///|
pub fn pdf_v2_event_for_one_pass_violation(reason : String) -> PdfV2SourceEvent {
  pdf_v2_event_for_risk(
    "one_pass_violation",
    PdfV2SourceEventKind::Diagnostic,
    @pdfv2.risk_one_pass_boundary_violation(reason),
  )
}

///|
fn build_source_pages(
  core : @pdfv2.PdfV2CoreDocument,
  events : Array[PdfV2SourceEvent],
) -> Array[PdfV2SourcePage] {
  let pages : Array[PdfV2SourcePage] = []
  for page in core.pages {
    pages.push(source_page_from_events(page.page_index, events))
  }
  if pages.is_empty() {
    pages.push(source_page_from_events(0, events))
  }
  pages
}

///|
fn source_page_from_events(
  page_index : Int,
  events : Array[PdfV2SourceEvent],
) -> PdfV2SourcePage {
  let page_events : Array[PdfV2SourceEvent] = []
  let object_refs : Array[String] = []
  let resource_refs : Array[@pdfv2.PdfV2ResourceRef] = []
  let warnings : Array[@pdfv2.PdfV2Warning] = []
  let risks : Array[@pdfv2.PdfV2Risk] = []
  for event in events {
    if event.page_index == Some(page_index) {
      page_events.push(event)
      match event.object_ref {
        Some(object_ref) => object_refs.push(object_ref)
        None => ()
      }
      match event.resource_ref {
        Some(resource_ref) => resource_refs.push(resource_ref)
        None => ()
      }
      for warning in event.diagnostics.warnings {
        warnings.push(warning)
      }
      for risk in event.diagnostics.risks {
        risks.push(risk)
      }
    }
  }
  {
    page_index,
    page_source_ref: @pdfv2.pdf_v2_source_ref_for_page(page_index),
    object_refs,
    resource_refs,
    events: page_events,
    warnings,
    risks,
  }
}

///|
fn collect_event_warnings(
  events : Array[PdfV2SourceEvent],
) -> Array[@pdfv2.PdfV2Warning] {
  let warnings : Array[@pdfv2.PdfV2Warning] = []
  for event in events {
    for warning in event.diagnostics.warnings {
      warnings.push(warning)
    }
  }
  warnings
}

///|
fn collect_event_risks(
  events : Array[PdfV2SourceEvent],
) -> Array[@pdfv2.PdfV2Risk] {
  let risks : Array[@pdfv2.PdfV2Risk] = []
  for event in events {
    for risk in event.diagnostics.risks {
      risks.push(risk)
    }
  }
  risks
}

///|
fn count_diagnostic_events(events : Array[PdfV2SourceEvent]) -> Int {
  let mut count = 0
  for event in events {
    if event.kind == PdfV2SourceEventKind::Diagnostic ||
      !event.diagnostics.warnings.is_empty() ||
      !event.diagnostics.risks.is_empty() {
      count = count + 1
    }
  }
  count
}

///|
fn build_capability_coverage(
  capabilities : Array[@pdfv2.PdfV2CoreCapability],
  events : Array[PdfV2SourceEvent],
) -> Array[PdfV2SourceCapabilityCoverage] {
  let coverage : Array[PdfV2SourceCapabilityCoverage] = []
  for capability in capabilities {
    coverage.push({
      capability: capability.kind,
      required: capability.runtime_requirement ==
      @pdfv2.PdfV2RuntimeRequirement::RuntimeRequired,
      observed: capability_observed(capability.kind, events),
      warning_count: count_warnings_for_capability(capability.kind, events),
      risk_count: count_risks_for_capability(capability.kind, events),
    })
  }
  coverage
}

///|
fn capability_observed(
  capability : @pdfv2.PdfV2CoreCapabilityKind,
  events : Array[PdfV2SourceEvent],
) -> Bool {
  for event in events {
    if event.capability == capability {
      return true
    }
  }
  false
}

///|
fn count_warnings_for_capability(
  capability : @pdfv2.PdfV2CoreCapabilityKind,
  events : Array[PdfV2SourceEvent],
) -> Int {
  let mut count = 0
  for event in events {
    for warning in event.diagnostics.warnings {
      if warning.capability == Some(capability) {
        count = count + 1
      }
    }
  }
  count
}

///|
fn count_risks_for_capability(
  capability : @pdfv2.PdfV2CoreCapabilityKind,
  events : Array[PdfV2SourceEvent],
) -> Int {
  let mut count = 0
  for event in events {
    for risk in event.diagnostics.risks {
      if risk.capability == Some(capability) {
        count = count + 1
      }
    }
  }
  count
}

///|
fn risk_severity_to_warning_severity(
  severity : @pdfv2.PdfV2RiskSeverity,
) -> @pdfv2.PdfV2Severity {
  match severity {
    @pdfv2.PdfV2RiskSeverity::Info => @pdfv2.PdfV2Severity::Info
    @pdfv2.PdfV2RiskSeverity::Warning => @pdfv2.PdfV2Severity::Warning
    @pdfv2.PdfV2RiskSeverity::Error => @pdfv2.PdfV2Severity::Error
    @pdfv2.PdfV2RiskSeverity::Fatal => @pdfv2.PdfV2Severity::Fatal
  }
}
