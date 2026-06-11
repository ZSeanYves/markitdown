///|
pub(all) enum PdfV2PipelineDiagnosticStatus {
  Ok
  Err
} derive(Eq)

///|
pub(all) struct PdfV2DiagnosticRow {
  section : String
  key : String
  value : String
  severity : String?
  source_ref_count : Int
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2PipelineDiagnostics {
  status : PdfV2PipelineDiagnosticStatus
  one_pass : Bool
  no_fallback : Bool
  stage_rows : Array[PdfV2DiagnosticRow]
  summary_rows : Array[PdfV2DiagnosticRow]
  fragment_rows : Array[PdfV2DiagnosticRow]
  warning_rows : Array[PdfV2DiagnosticRow]
  risk_rows : Array[PdfV2DiagnosticRow]
  cap_rows : Array[PdfV2DiagnosticRow]
  gate_rows : Array[PdfV2DiagnosticRow]
  lowering_rows : Array[PdfV2DiagnosticRow]
}

///|
fn pdf_v2_diag_row(
  section : String,
  key : String,
  value : String,
  severity : String?,
  source_ref_count : Int,
  reason_tags : Array[String],
) -> PdfV2DiagnosticRow {
  { section, key, value, severity, source_ref_count, reason_tags }
}

///|
fn pdf_v2_diag_plain_row(
  section : String,
  key : String,
  value : String,
) -> PdfV2DiagnosticRow {
  pdf_v2_diag_row(section, key, value, None, 0, [])
}

///|
fn pdf_v2_diag_bool(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
}

///|
fn pdf_v2_diag_status_text(status : PdfV2PipelineDiagnosticStatus) -> String {
  match status {
    Ok => "ok"
    Err => "err"
  }
}

///|
fn pdf_v2_diag_fragment_kind(kind : PdfV2FactFragmentKind) -> String {
  match kind {
    PlainText => "PlainText"
    PageBreak => "PageBreak"
    LowConfidenceNote => "LowConfidenceNote"
    UnsupportedObjectNote => "UnsupportedObjectNote"
  }
}

///|
fn pdf_v2_diag_severity_text(severity : @pdfv2.PdfV2Severity) -> String {
  match severity {
    Info => "info"
    Warning => "warning"
    Error => "error"
  }
}

///|
fn pdf_v2_diag_warning_kind_text(kind : @pdfv2.PdfV2WarningKind) -> String {
  match kind {
    UnsupportedCapability => "UnsupportedCapability"
    MalformedObject => "MalformedObject"
    DecodeIssue => "DecodeIssue"
    EncryptedOrRestricted => "EncryptedOrRestricted"
    PerformanceCap => "PerformanceCap"
    LowSignal => "LowSignal"
    ModelUnavailable => "ModelUnavailable"
    InternalInvariant => "InternalInvariant"
  }
}

///|
fn pdf_v2_diag_risk_kind_text(kind : @pdfv2.PdfV2RiskKind) -> String {
  match kind {
    LowSignal => "LowSignal"
    Malformed => "Malformed"
    UnsupportedFeature => "UnsupportedFeature"
    DecodeLowConfidence => "DecodeLowConfidence"
    MultiColumn => "MultiColumn"
    ReadingOrderAmbiguous => "ReadingOrderAmbiguous"
    CrossPageAmbiguous => "CrossPageAmbiguous"
    EncryptedOrRestricted => "EncryptedOrRestricted"
    ObjectGraphIssue => "ObjectGraphIssue"
    PerformanceCapReached => "PerformanceCapReached"
  }
}

///|
fn pdf_v2_diag_page_text(page_index : Int?) -> String {
  match page_index {
    Some(value) => value.to_string()
    None => "none"
  }
}

///|
fn pdf_v2_diag_stable_message(message : String) -> String {
  if message.contains("Failure(") || message.contains("@") {
    "PDF v2 parser failed closed before model assembly"
  } else {
    message.replace(old="\r\n", new="\n").replace(old="\r", new="\n")
  }
}

///|
fn pdf_v2_diag_stable_reason_tags(tags : Array[String]) -> Array[String] {
  let stable : Array[String] = []
  for tag in tags {
    let normalized = if tag.contains("reader") { "parser_reader" } else { tag }
    if !stable.contains(normalized) {
      stable.push(normalized)
    }
  }
  stable
}

///|
fn pdf_v2_diag_add_source_rows(
  rows : Array[PdfV2DiagnosticRow],
  summary : @pdfv2.PdfV2SourceSummary,
) -> Unit {
  rows.push(
    pdf_v2_diag_plain_row(
      "source",
      "source.pages",
      summary.page_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "source",
      "source.events",
      summary.event_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "source",
      "source.warnings",
      summary.warning_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "source",
      "source.risks",
      summary.risk_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "source",
      "source.one_pass_scan",
      pdf_v2_diag_bool(summary.one_pass_scan),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "source",
      "source.fallback_used",
      pdf_v2_diag_bool(summary.fallback_used),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "source",
      "source.external_model_files_read",
      pdf_v2_diag_bool(summary.external_model_files_read),
    ),
  )
}

///|
fn pdf_v2_diag_add_model_rows(
  rows : Array[PdfV2DiagnosticRow],
  summary : PdfV2ConvertModelSummary,
) -> Unit {
  rows.push(
    pdf_v2_diag_plain_row(
      "model",
      "model.pages",
      summary.page_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "model",
      "model.source_events",
      summary.source_event_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "model",
      "model.blocks",
      summary.block_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "model",
      "model.lines",
      summary.line_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "model",
      "model.spans",
      summary.span_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "model",
      "model.chars",
      summary.char_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "model",
      "model.unsupported_capabilities",
      summary.unsupported_capability_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "model",
      "model.partial_facts",
      summary.partial_fact_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "model",
      "model.warnings",
      summary.warning_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "model",
      "model.risks",
      summary.risk_count.to_string(),
    ),
  )
}

///|
fn pdf_v2_diag_add_layout_rows(
  rows : Array[PdfV2DiagnosticRow],
  summary : @pdfv2.PdfV2LayoutFactSummary,
) -> Unit {
  rows.push(
    pdf_v2_diag_plain_row(
      "layout",
      "layout.pages",
      summary.page_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "layout",
      "layout.pages_with_text_candidates",
      summary.pages_with_text_candidates.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "layout",
      "layout.pages_with_block_candidates",
      summary.pages_with_block_candidates.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "layout",
      "layout.pages_with_missing_geometry",
      summary.pages_with_missing_geometry.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "layout",
      "layout.pages_source_order_only",
      summary.pages_source_order_only.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "layout",
      "layout.unsupported_capabilities",
      summary.unsupported_capability_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "layout",
      "layout.partial_facts",
      summary.partial_fact_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "layout",
      "layout.capped_objects",
      summary.capped_object_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "layout",
      "layout.metadata_only",
      summary.metadata_only_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "layout",
      "layout.warnings",
      summary.warning_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "layout",
      "layout.risks",
      summary.risk_count.to_string(),
    ),
  )
}

///|
fn pdf_v2_diag_add_feature_rows(
  rows : Array[PdfV2DiagnosticRow],
  summary : @pdfv2.PdfV2FeatureSummary,
) -> Unit {
  rows.push(
    pdf_v2_diag_plain_row(
      "features",
      "features.documents",
      summary.document_feature_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "features",
      "features.pages",
      summary.page_feature_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "features",
      "features.blocks",
      summary.block_feature_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "features",
      "features.objects",
      summary.object_feature_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "features",
      "features.low_signal_blocks",
      summary.low_signal_block_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "features",
      "features.missing_geometry_blocks",
      summary.missing_geometry_block_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "features",
      "features.unsupported_objects",
      summary.unsupported_object_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "features",
      "features.partial_objects",
      summary.partial_object_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "features",
      "features.capped_objects",
      summary.capped_object_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "features",
      "features.warnings",
      summary.warning_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "features",
      "features.risks",
      summary.risk_count.to_string(),
    ),
  )
}

///|
fn pdf_v2_diag_add_gate_rows(
  rows : Array[PdfV2DiagnosticRow],
  gate_summary : PdfV2GateSummary?,
) -> Unit {
  match gate_summary {
    Some(summary) => {
      rows.push(pdf_v2_diag_plain_row("gate", "gate.enabled", "true"))
      rows.push(
        pdf_v2_diag_plain_row(
          "gate",
          "gate.blocks",
          summary.block_count.to_string(),
        ),
      )
      rows.push(
        pdf_v2_diag_plain_row(
          "gate",
          "gate.plain_text_candidates",
          summary.plain_text_candidate_count.to_string(),
        ),
      )
      rows.push(
        pdf_v2_diag_plain_row(
          "gate",
          "gate.abstain",
          summary.abstain_count.to_string(),
        ),
      )
      rows.push(
        pdf_v2_diag_plain_row(
          "gate",
          "gate.unknown",
          summary.unknown_count.to_string(),
        ),
      )
      rows.push(
        pdf_v2_diag_plain_row(
          "gate",
          "gate.risk_guard",
          summary.risk_guard_count.to_string(),
        ),
      )
      rows.push(
        pdf_v2_diag_plain_row(
          "gate",
          "gate.cap_guard",
          summary.cap_guard_count.to_string(),
        ),
      )
      rows.push(
        pdf_v2_diag_plain_row(
          "gate",
          "gate.unsupported_guard",
          summary.unsupported_guard_count.to_string(),
        ),
      )
      rows.push(
        pdf_v2_diag_plain_row(
          "gate",
          "gate.missing_geometry_guard",
          summary.missing_geometry_guard_count.to_string(),
        ),
      )
      rows.push(
        pdf_v2_diag_plain_row(
          "gate",
          "gate.warnings",
          summary.warning_count.to_string(),
        ),
      )
      rows.push(
        pdf_v2_diag_plain_row(
          "gate",
          "gate.risks",
          summary.risk_count.to_string(),
        ),
      )
    }
    None => rows.push(pdf_v2_diag_plain_row("gate", "gate.enabled", "false"))
  }
}

///|
fn pdf_v2_diag_add_lowering_rows(
  rows : Array[PdfV2DiagnosticRow],
  summary : PdfV2FactLoweringSummary,
) -> Unit {
  rows.push(
    pdf_v2_diag_plain_row(
      "lowering",
      "lowering.pages",
      summary.page_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "lowering",
      "lowering.blocks",
      summary.block_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "lowering",
      "lowering.lines",
      summary.line_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "lowering",
      "lowering.plain_text_fragments",
      summary.plain_text_fragment_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "lowering",
      "lowering.object_placeholders",
      summary.object_placeholder_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "lowering",
      "lowering.low_confidence_notes",
      summary.low_confidence_note_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "lowering",
      "lowering.gate_notes",
      summary.gate_note_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "lowering",
      "lowering.gate_plain_text_candidates",
      summary.gate_plain_text_candidate_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "lowering",
      "lowering.gate_abstain",
      summary.gate_abstain_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "lowering",
      "lowering.gate_unknown",
      summary.gate_unknown_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "lowering",
      "lowering.gate_missing_decisions",
      summary.gate_missing_decision_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "lowering",
      "lowering.gate_skipped_plain_text",
      summary.gate_skipped_plain_text_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "lowering",
      "lowering.warnings",
      summary.warning_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "lowering",
      "lowering.risks",
      summary.risk_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row(
      "lowering",
      "lowering.capped_output",
      pdf_v2_diag_bool(summary.capped_output),
    ),
  )
}

///|
fn pdf_v2_diag_fragment_value(
  index : Int,
  fragment : PdfV2FactFragment,
) -> String {
  "\{index} " +
  pdf_v2_diag_fragment_kind(fragment.kind) +
  " page=" +
  pdf_v2_diag_page_text(fragment.page_index) +
  " chars=" +
  fragment.text.length().to_string() +
  " refs=" +
  fragment.source_refs.length().to_string()
}

///|
fn pdf_v2_diag_add_fragment_rows(
  rows : Array[PdfV2DiagnosticRow],
  fragments : Array[PdfV2FactFragment],
) -> Unit {
  for index in 0..<fragments.length() {
    let fragment = fragments[index]
    rows.push(
      pdf_v2_diag_row(
        "fragments",
        "fragment." + index.to_string(),
        pdf_v2_diag_fragment_value(index, fragment),
        None,
        fragment.source_refs.length(),
        fragment.reason_tags,
      ),
    )
  }
}

///|
fn pdf_v2_diag_add_warning_rows(
  rows : Array[PdfV2DiagnosticRow],
  warnings : Array[@pdfv2.PdfV2Warning],
) -> Unit {
  for index in 0..<warnings.length() {
    let warning = warnings[index]
    rows.push(
      pdf_v2_diag_row(
        "warnings",
        "warning." + index.to_string(),
        pdf_v2_diag_warning_kind_text(warning.kind) +
        ": " +
        pdf_v2_diag_stable_message(warning.message),
        Some(pdf_v2_diag_severity_text(warning.severity)),
        warning.source_refs.length(),
        pdf_v2_diag_stable_reason_tags(warning.reason_tags),
      ),
    )
  }
}

///|
fn pdf_v2_diag_add_risk_rows(
  rows : Array[PdfV2DiagnosticRow],
  risks : Array[@pdfv2.PdfV2Risk],
) -> Unit {
  for index in 0..<risks.length() {
    let risk = risks[index]
    rows.push(
      pdf_v2_diag_row(
        "risks",
        "risk." + index.to_string(),
        pdf_v2_diag_risk_kind_text(risk.kind) +
        ": " +
        pdf_v2_diag_stable_message(risk.message),
        Some(pdf_v2_diag_severity_text(risk.severity)),
        risk.source_refs.length(),
        pdf_v2_diag_stable_reason_tags(risk.reason_tags),
      ),
    )
  }
}

///|
fn pdf_v2_diag_add_cap_rows(
  rows : Array[PdfV2DiagnosticRow],
  lowering_summary : PdfV2FactLoweringSummary?,
  warnings : Array[@pdfv2.PdfV2Warning],
  risks : Array[@pdfv2.PdfV2Risk],
) -> Unit {
  match lowering_summary {
    Some(summary) =>
      rows.push(
        pdf_v2_diag_plain_row(
          "caps",
          "caps.lowering_capped_output",
          pdf_v2_diag_bool(summary.capped_output),
        ),
      )
    None =>
      rows.push(
        pdf_v2_diag_plain_row("caps", "caps.lowering_capped_output", "false"),
      )
  }
  let mut warning_count = 0
  for warning in warnings {
    if warning.kind == @pdfv2.PdfV2WarningKind::PerformanceCap {
      warning_count = warning_count + 1
    }
  }
  let mut risk_count = 0
  for risk in risks {
    if risk.kind == @pdfv2.PdfV2RiskKind::PerformanceCapReached {
      risk_count = risk_count + 1
    }
  }
  rows.push(
    pdf_v2_diag_plain_row(
      "caps",
      "caps.warning_count",
      warning_count.to_string(),
    ),
  )
  rows.push(
    pdf_v2_diag_plain_row("caps", "caps.risk_count", risk_count.to_string()),
  )
}

///|
fn pdf_v2_diag_ok_rows(
  output : PdfV2ConvertPipelineOutput,
) -> PdfV2PipelineDiagnostics {
  let stage_rows : Array[PdfV2DiagnosticRow] = [
    pdf_v2_diag_plain_row("pipeline", "pipeline.stage", "ok"),
  ]
  let summary_rows : Array[PdfV2DiagnosticRow] = []
  let gate_rows : Array[PdfV2DiagnosticRow] = []
  let lowering_rows : Array[PdfV2DiagnosticRow] = []
  let fragment_rows : Array[PdfV2DiagnosticRow] = []
  let warning_rows : Array[PdfV2DiagnosticRow] = []
  let risk_rows : Array[PdfV2DiagnosticRow] = []
  let cap_rows : Array[PdfV2DiagnosticRow] = []
  pdf_v2_diag_add_source_rows(summary_rows, output.source_summary)
  pdf_v2_diag_add_model_rows(summary_rows, output.model_summary)
  pdf_v2_diag_add_layout_rows(summary_rows, output.layout_summary)
  pdf_v2_diag_add_feature_rows(summary_rows, output.feature_summary)
  pdf_v2_diag_add_gate_rows(gate_rows, output.gate_summary)
  pdf_v2_diag_add_lowering_rows(lowering_rows, output.lowering_summary)
  pdf_v2_diag_add_fragment_rows(fragment_rows, output.fragments)
  pdf_v2_diag_add_warning_rows(warning_rows, output.warnings)
  pdf_v2_diag_add_risk_rows(risk_rows, output.risks)
  pdf_v2_diag_add_cap_rows(
    cap_rows,
    Some(output.lowering_summary),
    output.warnings,
    output.risks,
  )
  {
    status: PdfV2PipelineDiagnosticStatus::Ok,
    one_pass: output.one_pass,
    no_fallback: output.no_fallback,
    stage_rows,
    summary_rows,
    fragment_rows,
    warning_rows,
    risk_rows,
    cap_rows,
    gate_rows,
    lowering_rows,
  }
}

///|
fn pdf_v2_diag_err_rows(
  failure : PdfV2ConvertPipelineFailure,
) -> PdfV2PipelineDiagnostics {
  let stage_rows : Array[PdfV2DiagnosticRow] = [
    pdf_v2_diag_plain_row("pipeline", "pipeline.stage", failure.stage),
    pdf_v2_diag_plain_row(
      "pipeline",
      "pipeline.error",
      pdf_v2_diag_stable_message(failure.message),
    ),
  ]
  let summary_rows : Array[PdfV2DiagnosticRow] = [
    pdf_v2_diag_plain_row("pipeline", "pipeline.fragments", "0"),
  ]
  let fragment_rows : Array[PdfV2DiagnosticRow] = []
  let warning_rows : Array[PdfV2DiagnosticRow] = []
  let risk_rows : Array[PdfV2DiagnosticRow] = []
  let cap_rows : Array[PdfV2DiagnosticRow] = []
  let gate_rows : Array[PdfV2DiagnosticRow] = [
    pdf_v2_diag_plain_row("gate", "gate.enabled", "false"),
  ]
  let lowering_rows : Array[PdfV2DiagnosticRow] = []
  pdf_v2_diag_add_fragment_rows(fragment_rows, failure.fragments)
  pdf_v2_diag_add_warning_rows(warning_rows, failure.warnings)
  pdf_v2_diag_add_risk_rows(risk_rows, failure.risks)
  pdf_v2_diag_add_cap_rows(cap_rows, None, failure.warnings, failure.risks)
  {
    status: PdfV2PipelineDiagnosticStatus::Err,
    one_pass: failure.one_pass,
    no_fallback: failure.no_fallback,
    stage_rows,
    summary_rows,
    fragment_rows,
    warning_rows,
    risk_rows,
    cap_rows,
    gate_rows,
    lowering_rows,
  }
}

///|
pub fn pdf_v2_pipeline_diagnostics_from_result(
  result : PdfV2ConvertPipelineResult,
) -> PdfV2PipelineDiagnostics {
  match result {
    ConvertPipelineOk(output) => pdf_v2_diag_ok_rows(output)
    ConvertPipelineErr(failure) => pdf_v2_diag_err_rows(failure)
  }
}

///|
fn pdf_v2_diag_render_row(row : PdfV2DiagnosticRow) -> String {
  let severity = match row.severity {
    Some(value) => " severity=" + value
    None => ""
  }
  row.key +
  ": " +
  row.value +
  severity +
  " refs=" +
  row.source_ref_count.to_string() +
  " tags=" +
  row.reason_tags.join(",")
}

///|
fn pdf_v2_diag_render_section(
  lines : Array[String],
  title : String,
  rows : Array[PdfV2DiagnosticRow],
) -> Unit {
  lines.push("")
  lines.push("[" + title + "]")
  for row in rows {
    lines.push(pdf_v2_diag_render_row(row))
  }
}

///|
pub fn pdf_v2_render_pipeline_diagnostics_text(
  diagnostics : PdfV2PipelineDiagnostics,
) -> String {
  let lines : Array[String] = [
    "PDF_V2_PIPELINE_DIAGNOSTICS",
    "status: " + pdf_v2_diag_status_text(diagnostics.status),
    "one_pass: " + pdf_v2_diag_bool(diagnostics.one_pass),
    "no_fallback: " + pdf_v2_diag_bool(diagnostics.no_fallback),
  ]
  pdf_v2_diag_render_section(lines, "stages", diagnostics.stage_rows)
  pdf_v2_diag_render_section(lines, "summary", diagnostics.summary_rows)
  pdf_v2_diag_render_section(lines, "gate", diagnostics.gate_rows)
  pdf_v2_diag_render_section(lines, "lowering", diagnostics.lowering_rows)
  pdf_v2_diag_render_section(lines, "caps", diagnostics.cap_rows)
  pdf_v2_diag_render_section(lines, "fragments", diagnostics.fragment_rows)
  pdf_v2_diag_render_section(lines, "warnings", diagnostics.warning_rows)
  pdf_v2_diag_render_section(lines, "risks", diagnostics.risk_rows)
  lines.join("\n") + "\n"
}
