///|
pub(all) enum PdfV2FactFragmentKind {
  PlainText
  PageBreak
  LowConfidenceNote
  UnsupportedObjectNote
} derive(Eq)

///|
pub(all) struct PdfV2FactLoweringOptions {
  emit_plain_text : Bool
  emit_page_breaks : Bool
  emit_low_confidence_notes : Bool
  emit_object_placeholders : Bool
  respect_gate_decisions : Bool
  emit_abstain_notes : Bool
  emit_unknown_notes : Bool
  allow_abstain_plain_text : Bool
  allow_unknown_plain_text : Bool
  max_blocks : Int
  max_lines : Int
  max_chars : Int
}

///|
pub(all) struct PdfV2FactLoweringInput {
  model : @pdfv2.PdfV2DocumentModel
  features : @pdfv2.PdfV2FeatureSet?
  gate_result : PdfV2GateResult?
  options : PdfV2FactLoweringOptions
}

///|
pub(all) struct PdfV2FactFragment {
  kind : PdfV2FactFragmentKind
  text : String
  page_index : Int?
  source_refs : Array[@pdfv2.PdfV2SourceRef]
  reason_tags : Array[String]
}

///|
pub(all) struct PdfV2FactLoweringSummary {
  page_count : Int
  block_count : Int
  line_count : Int
  plain_text_fragment_count : Int
  object_placeholder_count : Int
  low_confidence_note_count : Int
  gate_note_count : Int
  gate_plain_text_candidate_count : Int
  gate_abstain_count : Int
  gate_unknown_count : Int
  gate_missing_decision_count : Int
  gate_skipped_plain_text_count : Int
  warning_count : Int
  risk_count : Int
  capped_output : Bool
}

///|
pub(all) struct PdfV2FactLoweringResult {
  fragments : Array[PdfV2FactFragment]
  warnings : Array[@pdfv2.PdfV2Warning]
  risks : Array[@pdfv2.PdfV2Risk]
  summary : PdfV2FactLoweringSummary
  one_pass : Bool
  no_fallback : Bool
}

///|
pub fn default_pdf_v2_fact_lowering_options() -> PdfV2FactLoweringOptions {
  {
    emit_plain_text: true,
    emit_page_breaks: false,
    emit_low_confidence_notes: false,
    emit_object_placeholders: false,
    respect_gate_decisions: true,
    emit_abstain_notes: false,
    emit_unknown_notes: false,
    allow_abstain_plain_text: false,
    allow_unknown_plain_text: true,
    max_blocks: 100000,
    max_lines: 100000,
    max_chars: 1000000,
  }
}

///|
pub fn pdf_v2_fact_lowering_input(
  model : @pdfv2.PdfV2DocumentModel,
  features : @pdfv2.PdfV2FeatureSet?,
  options : PdfV2FactLoweringOptions,
) -> PdfV2FactLoweringInput {
  { model, features, gate_result: None, options }
}

///|
pub fn pdf_v2_fact_lowering_input_with_gate(
  model : @pdfv2.PdfV2DocumentModel,
  features : @pdfv2.PdfV2FeatureSet?,
  gate_result : PdfV2GateResult?,
  options : PdfV2FactLoweringOptions,
) -> PdfV2FactLoweringInput {
  { model, features, gate_result, options }
}

///|
fn pdf_v2_fact_effective_cap(value : Int) -> Int {
  if value < 0 {
    0
  } else {
    value
  }
}

///|
fn pdf_v2_fact_source_refs_or_page(
  page : @pdfv2.PdfV2PageModel,
  refs : Array[@pdfv2.PdfV2SourceRef],
) -> Array[@pdfv2.PdfV2SourceRef] {
  if refs.length() == 0 {
    [page.source_ref]
  } else {
    refs
  }
}

///|
fn pdf_v2_fact_append_unique_tag(
  tags : Array[String],
  tag : String,
) -> Array[String] {
  if tags.contains(tag) {
    tags
  } else {
    let out : Array[String] = []
    out.append(tags)
    out.push(tag)
    out
  }
}

///|
fn pdf_v2_fact_append_unique_tags(
  tags : Array[String],
  extra_tags : Array[String],
) -> Array[String] {
  let out : Array[String] = []
  out.append(tags)
  for tag in extra_tags {
    if !out.contains(tag) {
      out.push(tag)
    }
  }
  out
}

///|
fn pdf_v2_fact_line_text(lines : Array[@pdfv2.PdfV2LineCandidate]) -> String {
  let parts : Array[String] = []
  for line in lines {
    parts.push(line.text)
  }
  parts.join("\n")
}

///|
fn pdf_v2_fact_line_source_refs(
  lines : Array[@pdfv2.PdfV2LineCandidate],
) -> Array[@pdfv2.PdfV2SourceRef] {
  let refs : Array[@pdfv2.PdfV2SourceRef] = []
  for line in lines {
    refs.append(line.source_refs)
  }
  refs
}

///|
fn pdf_v2_fact_ordered_lines(
  lines : Array[@pdfv2.PdfV2LineCandidate],
) -> Array[@pdfv2.PdfV2LineCandidate] {
  let ordered : Array[@pdfv2.PdfV2LineCandidate] = []
  ordered.append(lines)
  ordered.sort_by(fn(a, b) { a.line_index - b.line_index })
  ordered
}

///|
fn pdf_v2_fact_ordered_blocks(
  blocks : Array[@pdfv2.PdfV2BlockCandidate],
) -> Array[@pdfv2.PdfV2BlockCandidate] {
  let ordered : Array[@pdfv2.PdfV2BlockCandidate] = []
  ordered.append(blocks)
  ordered.sort_by(fn(a, b) { a.block_index - b.block_index })
  ordered
}

///|
fn pdf_v2_fact_block_text(
  block : @pdfv2.PdfV2BlockCandidate,
) -> (String, Array[String], Array[@pdfv2.PdfV2SourceRef]) {
  if block.text.length() > 0 {
    (block.text, block.reason_tags, block.source_refs)
  } else {
    let lines = pdf_v2_fact_ordered_lines(block.lines)
    (
      pdf_v2_fact_line_text(lines),
      pdf_v2_fact_append_unique_tag(
        block.reason_tags,
        "fact_lowering_block_text_from_lines",
      ),
      pdf_v2_fact_line_source_refs(lines),
    )
  }
}

///|
fn pdf_v2_fact_cap_warning(
  tag : String,
  message : String,
  source_refs : Array[@pdfv2.PdfV2SourceRef],
) -> @pdfv2.PdfV2Warning {
  @pdfv2.pdf_v2_warning(
    @pdfv2.PdfV2WarningKind::PerformanceCap,
    @pdfv2.PdfV2Severity::Warning,
    message,
    source_refs,
    ["pdf_v2_fact_lowering", tag],
  )
}

///|
fn pdf_v2_fact_cap_risk(
  tag : String,
  message : String,
  source_refs : Array[@pdfv2.PdfV2SourceRef],
) -> @pdfv2.PdfV2Risk {
  {
    kind: @pdfv2.PdfV2RiskKind::PerformanceCapReached,
    severity: @pdfv2.PdfV2Severity::Warning,
    message,
    source_refs,
    reason_tags: ["pdf_v2_fact_lowering", tag],
  }
}

///|
fn pdf_v2_fact_gate_plain_text_risk(
  source_refs : Array[@pdfv2.PdfV2SourceRef],
  reason_tags : Array[String],
) -> @pdfv2.PdfV2Risk {
  {
    kind: @pdfv2.PdfV2RiskKind::LowSignal,
    severity: @pdfv2.PdfV2Severity::Warning,
    message: "PDF v2 fact lowering emitted plain text after gate abstain by explicit option",
    source_refs,
    reason_tags: pdf_v2_fact_append_unique_tag(
      reason_tags, "allow_abstain_plain_text",
    ),
  }
}

///|
fn pdf_v2_fact_respects_gate(input : PdfV2FactLoweringInput) -> Bool {
  if !input.options.respect_gate_decisions {
    false
  } else {
    match input.gate_result {
      Some(_) => true
      None => false
    }
  }
}

///|
fn pdf_v2_fact_gate_decision_for_block(
  gate_result : PdfV2GateResult?,
  page_index : Int?,
  block_index : Int,
) -> PdfV2BlockGateDecision? {
  match gate_result {
    Some(gate) =>
      for decision in gate.decisions {
        if decision.page_index == page_index &&
          decision.block_index == block_index {
          return Some(decision)
        }
      }
    None => ()
  }
  None
}

///|
fn pdf_v2_fact_effective_gate_kind(
  gate_active : Bool,
  decision : PdfV2BlockGateDecision?,
) -> PdfV2BlockDecisionKind {
  if !gate_active {
    PdfV2BlockDecisionKind::PlainTextCandidate
  } else {
    match decision {
      Some(value) => value.decision_kind
      None => PdfV2BlockDecisionKind::Unknown
    }
  }
}

///|
fn pdf_v2_fact_missing_gate_decision(
  gate_active : Bool,
  decision : PdfV2BlockGateDecision?,
) -> Bool {
  if !gate_active {
    false
  } else {
    match decision {
      Some(_) => false
      None => true
    }
  }
}

///|
fn pdf_v2_fact_gate_tags(
  gate_active : Bool,
  kind : PdfV2BlockDecisionKind,
  decision : PdfV2BlockGateDecision?,
  missing_decision : Bool,
) -> Array[String] {
  let tags : Array[String] = []
  if gate_active {
    tags.push("pdf_v2_fact_lowering")
    match kind {
      PlainTextCandidate => tags.push("gate_plain_text_candidate")
      Abstain => tags.push("gate_abstain")
      Unknown => tags.push("gate_unknown")
    }
    match decision {
      Some(value) => tags.append(value.abstain_reason_tags)
      None => ()
    }
    if missing_decision {
      tags.push("missing_gate_decision")
    }
  }
  tags
}

///|
fn pdf_v2_fact_gate_note_refs(
  decision : PdfV2BlockGateDecision?,
  fallback_refs : Array[@pdfv2.PdfV2SourceRef],
) -> Array[@pdfv2.PdfV2SourceRef] {
  match decision {
    Some(value) =>
      if value.source_refs.length() > 0 {
        value.source_refs
      } else {
        fallback_refs
      }
    None => fallback_refs
  }
}

///|
fn pdf_v2_fact_gate_note_text(kind : PdfV2BlockDecisionKind) -> String {
  match kind {
    Abstain => "PDF v2 gate abstained from text fact lowering"
    Unknown => "PDF v2 gate could not verify text fact lowering"
    PlainTextCandidate => "PDF v2 gate allowed plain text fact lowering"
  }
}

///|
fn pdf_v2_fact_push_gate_note(
  fragments : Array[PdfV2FactFragment],
  kind : PdfV2BlockDecisionKind,
  page_index : Int?,
  source_refs : Array[@pdfv2.PdfV2SourceRef],
  reason_tags : Array[String],
) -> Unit {
  fragments.push({
    kind: PdfV2FactFragmentKind::LowConfidenceNote,
    text: pdf_v2_fact_gate_note_text(kind),
    page_index,
    source_refs,
    reason_tags,
  })
}

///|
fn pdf_v2_fact_low_confidence_block(block : @pdfv2.PdfV2BlockCandidate) -> Bool {
  block.decode_confidence == @pdfv2.PdfV2TextDecodeConfidence::Unknown ||
  block.decode_confidence == @pdfv2.PdfV2TextDecodeConfidence::Failed ||
  block.geometry_confidence == @pdfv2.PdfV2GeometryConfidence::Unknown ||
  block.bbox is None ||
  block.block_kind_hint == @pdfv2.PdfV2BlockKindHint::LowSignal
}

///|
fn pdf_v2_fact_block_feature_row(
  features : @pdfv2.PdfV2FeatureSet?,
  page_index : Int?,
  block_index : Int,
) -> @pdfv2.PdfV2BlockFeatureRow? {
  match features {
    Some(rows) =>
      for row in rows.block_features {
        if row.page_index == page_index && row.block_index == block_index {
          return Some(row)
        }
      }
    None => ()
  }
  None
}

///|
fn pdf_v2_fact_low_confidence_from_features(
  row : @pdfv2.PdfV2BlockFeatureRow?,
) -> Bool {
  match row {
    Some(value) =>
      value.low_signal_flag ||
      value.missing_geometry_flag ||
      value.avg_decode_confidence <= 0.4
    None => false
  }
}

///|
fn pdf_v2_fact_low_confidence_tags(
  block : @pdfv2.PdfV2BlockCandidate,
  row : @pdfv2.PdfV2BlockFeatureRow?,
) -> Array[String] {
  let tags : Array[String] = ["pdf_v2_fact_lowering", "low_confidence_fact"]
  if block.decode_confidence == @pdfv2.PdfV2TextDecodeConfidence::Unknown {
    tags.push("decode_confidence_unknown")
  }
  if block.decode_confidence == @pdfv2.PdfV2TextDecodeConfidence::Failed {
    tags.push("decode_confidence_failed")
  }
  if block.geometry_confidence == @pdfv2.PdfV2GeometryConfidence::Unknown ||
    block.bbox is None {
    tags.push("missing_geometry")
  }
  if block.block_kind_hint == @pdfv2.PdfV2BlockKindHint::LowSignal {
    tags.push("low_signal_block")
  }
  match row {
    Some(value) => {
      if value.low_signal_flag {
        tags.push("feature_low_signal")
      }
      if value.missing_geometry_flag {
        tags.push("feature_missing_geometry")
      }
    }
    None => ()
  }
  tags
}

///|
fn pdf_v2_fact_object_note(
  object_kind : String,
  status : @pdfv2.PdfV2CapabilityStatus,
) -> String {
  "PDF v2 unsupported or partial object fact: " +
  object_kind +
  " (" +
  pdf_v2_fact_capability_status_name(status) +
  ")"
}

///|
fn pdf_v2_fact_capability_status_name(
  status : @pdfv2.PdfV2CapabilityStatus,
) -> String {
  match status {
    Supported => "supported"
    Partial => "partial"
    Unsupported => "unsupported"
    MetadataOnly => "metadata-only"
    NotAttempted => "not-attempted"
    Capped => "capped"
    Failed => "failed"
    Unknown => "unknown"
  }
}

///|
fn pdf_v2_fact_object_needs_placeholder(
  row : @pdfv2.PdfV2ObjectFeatureRow,
) -> Bool {
  row.metadata_only ||
  row.partial ||
  row.unsupported ||
  row.capped ||
  row.capability_status == @pdfv2.PdfV2CapabilityStatus::NotAttempted ||
  row.capability_status == @pdfv2.PdfV2CapabilityStatus::Failed ||
  row.capability_status == @pdfv2.PdfV2CapabilityStatus::Unknown
}

///|
fn pdf_v2_fact_append_object_placeholders(
  features : @pdfv2.PdfV2FeatureSet?,
  model : @pdfv2.PdfV2DocumentModel,
  fragments : Array[PdfV2FactFragment],
) -> Int {
  match features {
    Some(rows) => {
      let mut count = 0
      for row in rows.object_features {
        if pdf_v2_fact_object_needs_placeholder(row) {
          fragments.push({
            kind: PdfV2FactFragmentKind::UnsupportedObjectNote,
            text: pdf_v2_fact_object_note(
              row.object_kind,
              row.capability_status,
            ),
            page_index: row.page_index,
            source_refs: row.source_refs,
            reason_tags: pdf_v2_fact_append_unique_tag(
              row.reason_tags,
              "object_placeholder",
            ),
          })
          count = count + 1
        }
      }
      count
    }
    None => pdf_v2_fact_append_model_object_placeholders(model, fragments)
  }
}

///|
fn pdf_v2_fact_append_model_object_placeholders(
  model : @pdfv2.PdfV2DocumentModel,
  fragments : Array[PdfV2FactFragment],
) -> Int {
  let mut count = 0
  for report in model.unsupported_capabilities {
    let refs = match report.source_ref {
      Some(value) => [value]
      None => [@pdfv2.pdf_v2_document_source_ref()]
    }
    fragments.push({
      kind: PdfV2FactFragmentKind::UnsupportedObjectNote,
      text: pdf_v2_fact_object_note(report.capability, report.status),
      page_index: report.page_index,
      source_refs: refs,
      reason_tags: pdf_v2_fact_append_unique_tag(
        report.reason_tags,
        "object_placeholder",
      ),
    })
    count = count + 1
  }
  for report in model.partial_fact_reports {
    let refs = match report.source_ref {
      Some(value) => [value]
      None => [@pdfv2.pdf_v2_document_source_ref()]
    }
    fragments.push({
      kind: PdfV2FactFragmentKind::UnsupportedObjectNote,
      text: pdf_v2_fact_object_note(
        "partial_" + report.fact_kind,
        report.status,
      ),
      page_index: report.page_index,
      source_refs: refs,
      reason_tags: pdf_v2_fact_append_unique_tag(
        report.reason_tags,
        "object_placeholder",
      ),
    })
    count = count + 1
  }
  count
}

///|
fn pdf_v2_fact_summary_gate_plain_text_count(
  input : PdfV2FactLoweringInput,
) -> Int {
  if pdf_v2_fact_respects_gate(input) {
    match input.gate_result {
      Some(gate) => gate.summary.plain_text_candidate_count
      None => 0
    }
  } else {
    0
  }
}

///|
fn pdf_v2_fact_summary_gate_abstain_count(
  input : PdfV2FactLoweringInput,
) -> Int {
  if pdf_v2_fact_respects_gate(input) {
    match input.gate_result {
      Some(gate) => gate.summary.abstain_count
      None => 0
    }
  } else {
    0
  }
}

///|
fn pdf_v2_fact_summary_gate_unknown_count(
  input : PdfV2FactLoweringInput,
) -> Int {
  if pdf_v2_fact_respects_gate(input) {
    match input.gate_result {
      Some(gate) => gate.summary.unknown_count
      None => 0
    }
  } else {
    0
  }
}

///|
fn pdf_v2_fact_one_pass(input : PdfV2FactLoweringInput) -> Bool {
  let mut one_pass = input.model.one_pass
  match input.features {
    Some(features) => one_pass = one_pass && features.one_pass
    None => ()
  }
  match input.gate_result {
    Some(gate) => one_pass = one_pass && gate.one_pass
    None => ()
  }
  one_pass
}

///|
fn pdf_v2_fact_no_fallback(input : PdfV2FactLoweringInput) -> Bool {
  let mut no_fallback = input.model.no_fallback
  match input.features {
    Some(features) => no_fallback = no_fallback && features.no_fallback
    None => ()
  }
  match input.gate_result {
    Some(gate) => no_fallback = no_fallback && gate.no_fallback
    None => ()
  }
  no_fallback
}

///|
pub fn pdf_v2_lower_fact_model(
  input : PdfV2FactLoweringInput,
) -> PdfV2FactLoweringResult {
  let model = input.model
  let options = input.options
  let max_blocks = pdf_v2_fact_effective_cap(options.max_blocks)
  let max_lines = pdf_v2_fact_effective_cap(options.max_lines)
  let max_chars = pdf_v2_fact_effective_cap(options.max_chars)
  let fragments : Array[PdfV2FactFragment] = []
  let warnings : Array[@pdfv2.PdfV2Warning] = []
  let risks : Array[@pdfv2.PdfV2Risk] = []
  warnings.append(model.warnings)
  risks.append(model.risks)
  match input.features {
    Some(features) => {
      warnings.append(features.warnings)
      risks.append(features.risks)
    }
    None => ()
  }
  match input.gate_result {
    Some(gate) => {
      warnings.append(gate.warnings)
      risks.append(gate.risks)
    }
    None => ()
  }

  let mut lowered_blocks = 0
  let mut lowered_lines = 0
  let mut lowered_chars = 0
  let mut plain_text_count = 0
  let mut low_confidence_note_count = 0
  let mut gate_note_count = 0
  let gate_active = pdf_v2_fact_respects_gate(input)
  let gate_plain_text_candidate_count = pdf_v2_fact_summary_gate_plain_text_count(
    input,
  )
  let gate_abstain_count = pdf_v2_fact_summary_gate_abstain_count(input)
  let mut gate_unknown_count = pdf_v2_fact_summary_gate_unknown_count(input)
  let mut gate_missing_decision_count = 0
  let mut gate_skipped_plain_text_count = 0
  let mut capped_output = false
  let mut stop = false
  for page_index in 0..<model.pages.length() {
    let page = model.pages[page_index]
    if page_index > 0 && options.emit_page_breaks && !stop {
      fragments.push({
        kind: PdfV2FactFragmentKind::PageBreak,
        text: "",
        page_index: Some(page.page_index),
        source_refs: [page.source_ref],
        reason_tags: ["pdf_v2_fact_lowering", "page_break"],
      })
    }
    let ordered_blocks = pdf_v2_fact_ordered_blocks(page.blocks)
    for block in ordered_blocks {
      if stop {
        continue
      }
      let refs = pdf_v2_fact_source_refs_or_page(page, block.source_refs)
      if lowered_blocks >= max_blocks {
        warnings.push(
          pdf_v2_fact_cap_warning(
            "max_blocks_cap", "PDF v2 fact lowering stopped at max_blocks", refs,
          ),
        )
        risks.push(
          pdf_v2_fact_cap_risk(
            "max_blocks_cap", "PDF v2 fact lowering output is capped at max_blocks",
            refs,
          ),
        )
        capped_output = true
        stop = true
        continue
      }
      if lowered_lines + block.lines.length() > max_lines {
        warnings.push(
          pdf_v2_fact_cap_warning(
            "max_lines_cap", "PDF v2 fact lowering stopped before exceeding max_lines",
            refs,
          ),
        )
        risks.push(
          pdf_v2_fact_cap_risk(
            "max_lines_cap", "PDF v2 fact lowering output is capped at max_lines",
            refs,
          ),
        )
        capped_output = true
        stop = true
        continue
      }
      let (text, reason_tags, text_refs) = pdf_v2_fact_block_text(block)
      let effective_refs = pdf_v2_fact_source_refs_or_page(page, text_refs)
      let gate_decision = if gate_active {
        pdf_v2_fact_gate_decision_for_block(
          input.gate_result,
          block.page_index,
          block.block_index,
        )
      } else {
        None
      }
      let gate_kind = pdf_v2_fact_effective_gate_kind(
        gate_active, gate_decision,
      )
      let missing_gate_decision = pdf_v2_fact_missing_gate_decision(
        gate_active, gate_decision,
      )
      if missing_gate_decision {
        gate_missing_decision_count = gate_missing_decision_count + 1
        gate_unknown_count = gate_unknown_count + 1
      }
      let gate_tags = pdf_v2_fact_gate_tags(
        gate_active, gate_kind, gate_decision, missing_gate_decision,
      )
      let gate_note_refs = pdf_v2_fact_gate_note_refs(
        gate_decision, effective_refs,
      )
      if gate_active &&
        gate_kind == PdfV2BlockDecisionKind::Abstain &&
        !options.allow_abstain_plain_text {
        if options.emit_abstain_notes {
          pdf_v2_fact_push_gate_note(
            fragments,
            gate_kind,
            block.page_index,
            gate_note_refs,
            gate_tags,
          )
          gate_note_count = gate_note_count + 1
        }
        gate_skipped_plain_text_count = gate_skipped_plain_text_count + 1
        continue
      }
      if gate_active &&
        gate_kind == PdfV2BlockDecisionKind::Unknown &&
        !options.allow_unknown_plain_text {
        if options.emit_unknown_notes {
          pdf_v2_fact_push_gate_note(
            fragments,
            gate_kind,
            block.page_index,
            gate_note_refs,
            gate_tags,
          )
          gate_note_count = gate_note_count + 1
        }
        gate_skipped_plain_text_count = gate_skipped_plain_text_count + 1
        continue
      }
      if lowered_chars + text.length() > max_chars {
        warnings.push(
          pdf_v2_fact_cap_warning(
            "max_chars_cap", "PDF v2 fact lowering stopped before exceeding max_chars",
            effective_refs,
          ),
        )
        risks.push(
          pdf_v2_fact_cap_risk(
            "max_chars_cap", "PDF v2 fact lowering output is capped at max_chars",
            effective_refs,
          ),
        )
        capped_output = true
        stop = true
        continue
      }
      if gate_active &&
        gate_kind == PdfV2BlockDecisionKind::Abstain &&
        options.allow_abstain_plain_text {
        let abstain_tags = pdf_v2_fact_append_unique_tag(
          gate_tags, "allow_abstain_plain_text",
        )
        pdf_v2_fact_push_gate_note(
          fragments,
          gate_kind,
          block.page_index,
          gate_note_refs,
          abstain_tags,
        )
        risks.push(
          pdf_v2_fact_gate_plain_text_risk(gate_note_refs, abstain_tags),
        )
        gate_note_count = gate_note_count + 1
      } else if gate_active &&
        gate_kind == PdfV2BlockDecisionKind::Unknown &&
        options.emit_unknown_notes {
        pdf_v2_fact_push_gate_note(
          fragments,
          gate_kind,
          block.page_index,
          gate_note_refs,
          gate_tags,
        )
        gate_note_count = gate_note_count + 1
      }
      let feature_row = pdf_v2_fact_block_feature_row(
        input.features,
        block.page_index,
        block.block_index,
      )
      if options.emit_low_confidence_notes &&
        (
          pdf_v2_fact_low_confidence_block(block) ||
          pdf_v2_fact_low_confidence_from_features(feature_row)
        ) {
        fragments.push({
          kind: PdfV2FactFragmentKind::LowConfidenceNote,
          text: "PDF v2 low-confidence text fact kept as plain text",
          page_index: block.page_index,
          source_refs: effective_refs,
          reason_tags: pdf_v2_fact_low_confidence_tags(block, feature_row),
        })
        low_confidence_note_count = low_confidence_note_count + 1
      }
      if options.emit_plain_text && text.length() > 0 {
        fragments.push({
          kind: PdfV2FactFragmentKind::PlainText,
          text,
          page_index: block.page_index,
          source_refs: effective_refs,
          reason_tags: pdf_v2_fact_append_unique_tags(reason_tags, gate_tags),
        })
        plain_text_count = plain_text_count + 1
      }
      lowered_blocks = lowered_blocks + 1
      lowered_lines = lowered_lines + block.lines.length()
      lowered_chars = lowered_chars + text.length()
    }
  }
  let object_placeholder_count = if options.emit_object_placeholders {
    pdf_v2_fact_append_object_placeholders(input.features, model, fragments)
  } else {
    0
  }
  {
    fragments,
    warnings,
    risks,
    summary: {
      page_count: model.page_count,
      block_count: lowered_blocks,
      line_count: lowered_lines,
      plain_text_fragment_count: plain_text_count,
      object_placeholder_count,
      low_confidence_note_count,
      gate_note_count,
      gate_plain_text_candidate_count,
      gate_abstain_count,
      gate_unknown_count,
      gate_missing_decision_count,
      gate_skipped_plain_text_count,
      warning_count: warnings.length(),
      risk_count: risks.length(),
      capped_output,
    },
    one_pass: pdf_v2_fact_one_pass(input),
    no_fallback: pdf_v2_fact_no_fallback(input),
  }
}
