///|
pub(all) enum PdfV2ModelAssemblyResult {
  ModelAssemblyOk(PdfV2DocumentModel)
  ModelAssemblyErr(Array[PdfV2Warning], Array[PdfV2Risk], String)
}

///|
fn pdf_v2_model_empty_layout(
  source_refs : Array[PdfV2SourceRef],
) -> PdfV2LayoutRecoveryResult {
  {
    regions: [],
    reading_order: {
      region_indices: [],
      confidence: 0.0,
      source_refs,
      reason_tags: ["layout_recovery_not_run", "parser_model_assembly"],
    },
    cross_page_boundaries: [],
    hints: [],
    risks: [],
    warnings: [],
    confidence: 0.0,
  }
}

///|
fn pdf_v2_model_source_refs_or_document(
  source_refs : Array[PdfV2SourceRef],
) -> Array[PdfV2SourceRef] {
  if source_refs.length() == 0 {
    [pdf_v2_document_source_ref()]
  } else {
    source_refs
  }
}

///|
fn pdf_v2_model_page_index_valid(page_index : Int?, page_count : Int) -> Bool {
  match page_index {
    Some(index) => index >= 0 && index < page_count
    None => false
  }
}

///|
fn pdf_v2_model_invalid_page_warning(
  candidate_kind : String,
  source_refs : Array[PdfV2SourceRef],
) -> PdfV2Warning {
  pdf_v2_warning(
    PdfV2WarningKind::InternalInvariant,
    PdfV2Severity::Error,
    "PDF v2 model assembly found \{candidate_kind} candidate with invalid page_index",
    pdf_v2_model_source_refs_or_document(source_refs),
    ["model_assembly", "invalid_candidate_page_index", candidate_kind],
  )
}

///|
fn pdf_v2_model_invalid_page_risk(
  candidate_kind : String,
  source_refs : Array[PdfV2SourceRef],
) -> PdfV2Risk {
  {
    kind: PdfV2RiskKind::ObjectGraphIssue,
    severity: PdfV2Severity::Error,
    message: "PDF v2 model assembly found \{candidate_kind} candidate with invalid page_index",
    source_refs: pdf_v2_model_source_refs_or_document(source_refs),
    reason_tags: [
      "model_assembly", "invalid_candidate_page_index", candidate_kind,
    ],
  }
}

///|
fn pdf_v2_model_append_invalid_page(
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
  candidate_kind : String,
  source_refs : Array[PdfV2SourceRef],
) -> Unit {
  warnings.push(pdf_v2_model_invalid_page_warning(candidate_kind, source_refs))
  risks.push(pdf_v2_model_invalid_page_risk(candidate_kind, source_refs))
}

///|
fn pdf_v2_model_validate_char_pages(
  chars : Array[PdfV2CharCandidate],
  page_count : Int,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> Bool {
  let mut ok = true
  for ch in chars {
    if !pdf_v2_model_page_index_valid(ch.page_index, page_count) {
      pdf_v2_model_append_invalid_page(warnings, risks, "char", [ch.source_ref])
      ok = false
    }
  }
  ok
}

///|
fn pdf_v2_model_validate_span_pages(
  spans : Array[PdfV2SpanCandidate],
  page_count : Int,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> Bool {
  let mut ok = true
  for span in spans {
    if !pdf_v2_model_page_index_valid(span.page_index, page_count) {
      pdf_v2_model_append_invalid_page(
        warnings,
        risks,
        "span",
        span.source_refs,
      )
      ok = false
    }
  }
  ok
}

///|
fn pdf_v2_model_validate_line_pages(
  lines : Array[PdfV2LineCandidate],
  page_count : Int,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> Bool {
  let mut ok = true
  for line in lines {
    if !pdf_v2_model_page_index_valid(line.page_index, page_count) {
      pdf_v2_model_append_invalid_page(
        warnings,
        risks,
        "line",
        line.source_refs,
      )
      ok = false
    }
  }
  ok
}

///|
fn pdf_v2_model_validate_block_pages(
  blocks : Array[PdfV2BlockCandidate],
  page_count : Int,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> Bool {
  let mut ok = true
  for block in blocks {
    if !pdf_v2_model_page_index_valid(block.page_index, page_count) {
      pdf_v2_model_append_invalid_page(
        warnings,
        risks,
        "block",
        block.source_refs,
      )
      ok = false
    }
  }
  ok
}

///|
fn pdf_v2_model_validate_page_facts(
  pages : Array[PdfV2Page],
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> Bool {
  let mut ok = true
  let page_count = pages.length()
  for page in pages {
    if page.page_index < 0 || page.page_index >= page_count {
      pdf_v2_model_append_invalid_page(warnings, risks, "page", [
        page.source_ref,
      ])
      ok = false
    }
  }
  ok
}

///|
fn pdf_v2_model_page_count_warning() -> PdfV2Warning {
  pdf_v2_warning(
    PdfV2WarningKind::InternalInvariant,
    PdfV2Severity::Warning,
    "PDF v2 source summary page_count differs from page facts",
    [pdf_v2_document_source_ref()],
    ["model_assembly", "page_count_mismatch"],
  )
}

///|
fn pdf_v2_model_page_count_risk() -> PdfV2Risk {
  {
    kind: PdfV2RiskKind::ObjectGraphIssue,
    severity: PdfV2Severity::Warning,
    message: "PDF v2 source summary page_count differs from page facts",
    source_refs: [pdf_v2_document_source_ref()],
    reason_tags: ["model_assembly", "page_count_mismatch"],
  }
}

///|
fn pdf_v2_model_chars_for_page(
  chars : Array[PdfV2CharCandidate],
  page_index : Int,
) -> Array[PdfV2CharCandidate] {
  let out : Array[PdfV2CharCandidate] = []
  for ch in chars {
    if ch.page_index == Some(page_index) {
      out.push(ch)
    }
  }
  out
}

///|
fn pdf_v2_model_spans_for_page(
  spans : Array[PdfV2SpanCandidate],
  page_index : Int,
) -> Array[PdfV2SpanCandidate] {
  let out : Array[PdfV2SpanCandidate] = []
  for span in spans {
    if span.page_index == Some(page_index) {
      out.push(span)
    }
  }
  out
}

///|
fn pdf_v2_model_lines_for_page(
  lines : Array[PdfV2LineCandidate],
  page_index : Int,
) -> Array[PdfV2LineCandidate] {
  let out : Array[PdfV2LineCandidate] = []
  for line in lines {
    if line.page_index == Some(page_index) {
      out.push(line)
    }
  }
  out
}

///|
fn pdf_v2_model_blocks_for_page(
  blocks : Array[PdfV2BlockCandidate],
  page_index : Int,
) -> Array[PdfV2BlockCandidate] {
  let out : Array[PdfV2BlockCandidate] = []
  for block in blocks {
    if block.page_index == Some(page_index) {
      out.push(block)
    }
  }
  out
}

///|
fn pdf_v2_model_page_from_source(
  page : PdfV2Page,
  source : PdfV2SourceDocument,
) -> PdfV2PageModel {
  {
    page_index: page.page_index,
    page_label: page.page_label,
    media_box: page.media_box,
    crop_box: page.crop_box,
    rotate: page.rotate,
    user_unit: page.user_unit,
    resources_present: page.resources_present,
    source_ref: page.source_ref,
    blocks: pdf_v2_model_blocks_for_page(
      source.block_candidates,
      page.page_index,
    ),
    lines: pdf_v2_model_lines_for_page(source.line_candidates, page.page_index),
    spans: pdf_v2_model_spans_for_page(source.span_candidates, page.page_index),
    chars: pdf_v2_model_chars_for_page(source.char_candidates, page.page_index),
    page_warnings: page.warnings,
    page_risks: page.risks,
    text_blocks: [],
    layout_regions: [],
  }
}

///|
fn pdf_v2_model_pages_from_source(
  source : PdfV2SourceDocument,
) -> Array[PdfV2PageModel] {
  source.pages.map(fn(page) { pdf_v2_model_page_from_source(page, source) })
}

///|
fn pdf_v2_model_source_refs(
  source : PdfV2SourceDocument,
) -> Array[PdfV2SourceRef] {
  let refs : Array[PdfV2SourceRef] = []
  for page in source.pages {
    refs.push(page.source_ref)
  }
  if refs.length() == 0 {
    refs.push(pdf_v2_document_source_ref())
  }
  refs
}

///|
fn pdf_v2_model_metadata(source : PdfV2SourceDocument) -> PdfV2DocumentMetadata {
  {
    title: None,
    author: None,
    subject: None,
    creator: None,
    producer: None,
    source_refs: pdf_v2_model_source_refs(source),
  }
}

///|
pub fn pdf_v2_document_model_from_source(
  source : PdfV2SourceDocument,
) -> PdfV2ModelAssemblyResult {
  let warnings : Array[PdfV2Warning] = []
  let risks : Array[PdfV2Risk] = []
  warnings.append(source.warnings)
  risks.append(source.risks)
  let page_count = source.pages.length()

  let mut valid = pdf_v2_model_validate_page_facts(
    source.pages,
    warnings,
    risks,
  )
  valid = pdf_v2_model_validate_char_pages(
      source.char_candidates,
      page_count,
      warnings,
      risks,
    ) &&
    valid
  valid = pdf_v2_model_validate_span_pages(
      source.span_candidates,
      page_count,
      warnings,
      risks,
    ) &&
    valid
  valid = pdf_v2_model_validate_line_pages(
      source.line_candidates,
      page_count,
      warnings,
      risks,
    ) &&
    valid
  valid = pdf_v2_model_validate_block_pages(
      source.block_candidates,
      page_count,
      warnings,
      risks,
    ) &&
    valid

  if source.summary.page_count != page_count {
    warnings.push(pdf_v2_model_page_count_warning())
    risks.push(pdf_v2_model_page_count_risk())
  }

  if !valid {
    return PdfV2ModelAssemblyResult::ModelAssemblyErr(
      warnings, risks, "PDF v2 model assembly failed: invalid candidate page_index",
    )
  }

  let layout = pdf_v2_model_empty_layout(pdf_v2_model_source_refs(source))
  let pages = pdf_v2_model_pages_from_source(source)
  PdfV2ModelAssemblyResult::ModelAssemblyOk({
    document_id: None,
    page_count,
    metadata: pdf_v2_model_metadata(source),
    pages,
    source_events: source.source_events,
    layout,
    warnings,
    risks,
    source_summary: source.summary,
    reconstruction_summary: source.reconstruction_summary,
    capabilities: pdf_v2_core_supported_capabilities(),
    one_pass: source.summary.one_pass_scan,
    no_fallback: !source.summary.fallback_used,
    model_version: "pdf-v2-phase9",
  })
}

///|
pub fn pdf_v2_open_document_model_from_path(
  path : String,
  options : PdfV2CoreOpenOptions,
) -> PdfV2ModelAssemblyResult {
  match pdf_v2_open_source_document_from_path(path, options) {
    SourceOpenOk(source) => pdf_v2_document_model_from_source(source)
    SourceOpenErr(warnings, risks, message) =>
      PdfV2ModelAssemblyResult::ModelAssemblyErr(warnings, risks, message)
  }
}
