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
  max_blocks : Int
  max_lines : Int
  max_chars : Int
}

///|
pub(all) struct PdfV2FactLoweringInput {
  model : @pdfv2.PdfV2DocumentModel
  features : @pdfv2.PdfV2FeatureSet?
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
  { model, features, options }
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
fn pdf_v2_fact_block_text(
  block : @pdfv2.PdfV2BlockCandidate,
) -> (String, Array[String], Array[@pdfv2.PdfV2SourceRef]) {
  if block.text.length() > 0 {
    (block.text, block.reason_tags, block.source_refs)
  } else {
    (
      pdf_v2_fact_line_text(block.lines),
      pdf_v2_fact_append_unique_tag(
        block.reason_tags,
        "fact_lowering_block_text_from_lines",
      ),
      pdf_v2_fact_line_source_refs(block.lines),
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

  let mut lowered_blocks = 0
  let mut lowered_lines = 0
  let mut lowered_chars = 0
  let mut plain_text_count = 0
  let mut low_confidence_note_count = 0
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
    for block in page.blocks {
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
          reason_tags,
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
      warning_count: warnings.length(),
      risk_count: risks.length(),
      capped_output,
    },
    one_pass: match input.features {
      Some(features) => model.one_pass && features.one_pass
      None => model.one_pass
    },
    no_fallback: match input.features {
      Some(features) => model.no_fallback && features.no_fallback
      None => model.no_fallback
    },
  }
}
