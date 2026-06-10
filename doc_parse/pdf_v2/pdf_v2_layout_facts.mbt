///|
fn pdf_v2_layout_append_refs(
  refs : Array[PdfV2SourceRef],
  more : Array[PdfV2SourceRef],
) -> Unit {
  refs.append(more)
}

///|
fn pdf_v2_layout_text_source_refs(
  page : PdfV2PageModel,
) -> Array[PdfV2SourceRef] {
  let refs : Array[PdfV2SourceRef] = []
  for block in page.blocks {
    pdf_v2_layout_append_refs(refs, block.source_refs)
  }
  for line in page.lines {
    pdf_v2_layout_append_refs(refs, line.source_refs)
  }
  for span in page.spans {
    pdf_v2_layout_append_refs(refs, span.source_refs)
  }
  for ch in page.chars {
    refs.push(ch.source_ref)
  }
  for block in page.text_blocks {
    pdf_v2_layout_append_refs(refs, block.source_refs)
  }
  refs
}

///|
fn pdf_v2_layout_object_source_refs(
  page : PdfV2PageModel,
) -> Array[PdfV2SourceRef] {
  let refs : Array[PdfV2SourceRef] = []
  for image in page.images {
    refs.push(image.source_ref)
  }
  for image in page.inline_images {
    refs.push(image.source_ref)
  }
  for annotation in page.annotations {
    refs.push(annotation.source_ref)
  }
  for link in page.links {
    refs.push(link.source_ref)
  }
  for form in page.forms {
    refs.push(form.source_ref)
  }
  for resource in page.resources {
    refs.push(resource.source_ref)
  }
  refs
}

///|
fn pdf_v2_layout_text_refs(page : PdfV2PageModel) -> PdfV2TextCandidateRefs {
  let source_refs = pdf_v2_layout_text_source_refs(page)
  {
    block_count: page.blocks.length(),
    line_count: page.lines.length(),
    span_count: page.spans.length(),
    char_count: page.chars.length(),
    has_text_blocks: page.text_blocks.length() > 0,
    has_block_candidates: page.blocks.length() > 0,
    has_line_candidates: page.lines.length() > 0,
    has_span_candidates: page.spans.length() > 0,
    has_char_candidates: page.chars.length() > 0,
    source_refs,
  }
}

///|
fn pdf_v2_layout_object_facts(
  page : PdfV2PageModel,
) -> PdfV2ObjectCandidateFacts {
  {
    has_images: page.images.length() > 0,
    has_inline_images: page.inline_images.length() > 0,
    has_links: page.links.length() > 0,
    has_resources: page.resources.length() > 0,
    has_image_metadata: page.images.length() > 0 ||
    page.inline_images.length() > 0,
    has_annotations: page.annotations.length() > 0,
    has_forms: page.forms.length() > 0,
    has_outlines: false,
    has_destinations: false,
    source_refs: pdf_v2_layout_object_source_refs(page),
  }
}

///|
fn pdf_v2_layout_has_text(page : PdfV2PageModel) -> Bool {
  page.text_blocks.length() > 0 ||
  page.blocks.length() > 0 ||
  page.lines.length() > 0 ||
  page.spans.length() > 0 ||
  page.chars.length() > 0
}

///|
fn pdf_v2_layout_geometry_count(page : PdfV2PageModel) -> (Int, Int) {
  let mut total = 0
  let mut covered = 0
  for block in page.blocks {
    total = total + 1
    if block.bbox is Some(_) {
      covered = covered + 1
    }
  }
  for line in page.lines {
    total = total + 1
    if line.bbox is Some(_) && line.baseline is Some(_) {
      covered = covered + 1
    }
  }
  for span in page.spans {
    total = total + 1
    if span.bbox is Some(_) {
      covered = covered + 1
    }
  }
  for ch in page.chars {
    total = total + 1
    if ch.bbox is Some(_) {
      covered = covered + 1
    }
  }
  (total, covered)
}

///|
fn pdf_v2_layout_geometry_coverage(
  page : PdfV2PageModel,
) -> PdfV2GeometryCoverage {
  let (total, covered) = pdf_v2_layout_geometry_count(page)
  if total == 0 {
    PdfV2GeometryCoverage::Unknown
  } else if covered == 0 {
    PdfV2GeometryCoverage::Missing
  } else if covered == total {
    PdfV2GeometryCoverage::Full
  } else if covered * 2 >= total {
    PdfV2GeometryCoverage::Partial
  } else {
    PdfV2GeometryCoverage::Sparse
  }
}

///|
fn pdf_v2_layout_geometry_incomplete(coverage : PdfV2GeometryCoverage) -> Bool {
  match coverage {
    Full | Partial => false
    Sparse | Missing | Unknown => true
  }
}

///|
fn pdf_v2_layout_page_source_refs(
  page : PdfV2PageModel,
  text_refs : PdfV2TextCandidateRefs,
  object_refs : PdfV2ObjectCandidateFacts,
) -> Array[PdfV2SourceRef] {
  let refs : Array[PdfV2SourceRef] = [page.source_ref]
  pdf_v2_layout_append_refs(refs, text_refs.source_refs)
  pdf_v2_layout_append_refs(refs, object_refs.source_refs)
  refs
}

///|
fn pdf_v2_layout_geometry_warning(
  page_index : Int,
  source_refs : Array[PdfV2SourceRef],
) -> PdfV2Warning {
  pdf_v2_warning(
    PdfV2WarningKind::LowSignal,
    PdfV2Severity::Info,
    "PDF v2 layout facts for page \{page_index} have insufficient geometry",
    source_refs,
    [
      "layout_facts_scaffold", "layout_geometry_missing", "insufficient_geometry",
    ],
  )
}

///|
fn pdf_v2_layout_geometry_risk(
  page_index : Int,
  source_refs : Array[PdfV2SourceRef],
) -> PdfV2Risk {
  {
    kind: PdfV2RiskKind::LowSignal,
    severity: PdfV2Severity::Info,
    message: "PDF v2 layout facts for page \{page_index} are source-order only",
    source_refs,
    reason_tags: [
      "layout_facts_scaffold", "layout_geometry_missing", "source_order_only",
    ],
  }
}

///|
fn pdf_v2_layout_reading_status(has_text : Bool) -> PdfV2LayoutRecoveryStatus {
  if has_text {
    PdfV2LayoutRecoveryStatus::SourceOrderOnly
  } else {
    PdfV2LayoutRecoveryStatus::NotAttempted
  }
}

///|
fn pdf_v2_layout_region_status(
  has_text : Bool,
  coverage : PdfV2GeometryCoverage,
) -> PdfV2LayoutRecoveryStatus {
  if !has_text {
    PdfV2LayoutRecoveryStatus::NotAttempted
  } else {
    match coverage {
      Full | Partial => PdfV2LayoutRecoveryStatus::PartialFacts
      Sparse | Missing | Unknown =>
        PdfV2LayoutRecoveryStatus::InsufficientGeometry
    }
  }
}

///|
fn pdf_v2_layout_image_status(
  object_refs : PdfV2ObjectCandidateFacts,
) -> PdfV2LayoutRecoveryStatus {
  if object_refs.has_image_metadata {
    PdfV2LayoutRecoveryStatus::PartialFacts
  } else {
    PdfV2LayoutRecoveryStatus::NotAttempted
  }
}

///|
fn pdf_v2_layout_annotation_status(
  object_refs : PdfV2ObjectCandidateFacts,
) -> PdfV2LayoutRecoveryStatus {
  if object_refs.has_annotations ||
    object_refs.has_links ||
    object_refs.has_forms ||
    object_refs.has_destinations {
    PdfV2LayoutRecoveryStatus::PartialFacts
  } else {
    PdfV2LayoutRecoveryStatus::NotAttempted
  }
}

///|
fn pdf_v2_layout_page_facts(page : PdfV2PageModel) -> PdfV2PageLayoutFacts {
  let text_refs = pdf_v2_layout_text_refs(page)
  let object_refs = pdf_v2_layout_object_facts(page)
  let coverage = pdf_v2_layout_geometry_coverage(page)
  let has_text = pdf_v2_layout_has_text(page)
  let source_refs = pdf_v2_layout_page_source_refs(page, text_refs, object_refs)
  let warnings : Array[PdfV2Warning] = []
  let risks : Array[PdfV2Risk] = []
  warnings.append(page.page_warnings)
  risks.append(page.page_risks)
  if has_text && pdf_v2_layout_geometry_incomplete(coverage) {
    warnings.push(pdf_v2_layout_geometry_warning(page.page_index, source_refs))
    risks.push(pdf_v2_layout_geometry_risk(page.page_index, source_refs))
  }
  {
    page_index: page.page_index,
    page_box_facts: {
      media_box: page.media_box,
      crop_box: page.crop_box,
      rotate: page.rotate,
      user_unit: page.user_unit,
      resources_present: page.resources_present,
      source_ref: page.source_ref,
    },
    text_candidate_refs: text_refs,
    object_candidate_refs: object_refs,
    geometry_coverage: coverage,
    reading_order_status: pdf_v2_layout_reading_status(has_text),
    layout_region_status: pdf_v2_layout_region_status(has_text, coverage),
    table_region_status: PdfV2LayoutRecoveryStatus::NotAttempted,
    image_region_status: pdf_v2_layout_image_status(object_refs),
    annotation_region_status: pdf_v2_layout_annotation_status(object_refs),
    warnings,
    risks,
    source_refs,
  }
}

///|
fn pdf_v2_layout_summary(
  page_layouts : Array[PdfV2PageLayoutFacts],
  object_summary : PdfV2ObjectSummary,
  unsupported_capabilities : Array[PdfV2UnsupportedCapabilityReport],
  warning_count : Int,
  risk_count : Int,
) -> PdfV2LayoutFactSummary {
  let mut pages_with_text_candidates = 0
  let mut pages_with_block_candidates = 0
  let mut pages_with_missing_geometry = 0
  let mut pages_source_order_only = 0
  let mut pages_with_layout_not_attempted = 0
  for page in page_layouts {
    if page.text_candidate_refs.has_text_blocks ||
      page.text_candidate_refs.has_block_candidates ||
      page.text_candidate_refs.has_line_candidates ||
      page.text_candidate_refs.has_span_candidates ||
      page.text_candidate_refs.has_char_candidates {
      pages_with_text_candidates = pages_with_text_candidates + 1
    }
    if page.text_candidate_refs.has_block_candidates {
      pages_with_block_candidates = pages_with_block_candidates + 1
    }
    if page.text_candidate_refs.has_block_candidates ||
      page.text_candidate_refs.has_line_candidates ||
      page.text_candidate_refs.has_span_candidates ||
      page.text_candidate_refs.has_char_candidates {
      if pdf_v2_layout_geometry_incomplete(page.geometry_coverage) {
        pages_with_missing_geometry = pages_with_missing_geometry + 1
      }
    }
    if page.reading_order_status == PdfV2LayoutRecoveryStatus::SourceOrderOnly {
      pages_source_order_only = pages_source_order_only + 1
    }
    if page.layout_region_status == PdfV2LayoutRecoveryStatus::NotAttempted {
      pages_with_layout_not_attempted = pages_with_layout_not_attempted + 1
    }
  }
  {
    page_count: page_layouts.length(),
    pages_with_text_candidates,
    pages_with_block_candidates,
    pages_with_missing_geometry,
    pages_source_order_only,
    pages_with_layout_not_attempted,
    unsupported_capability_count: object_summary.unsupported_capability_count,
    partial_fact_count: object_summary.partial_fact_count,
    capped_object_count: pdf_v2_layout_capped_object_count(
      unsupported_capabilities,
    ),
    metadata_only_count: object_summary.metadata_only_count,
    warning_count,
    risk_count,
  }
}

///|
fn pdf_v2_layout_capped_object_count(
  unsupported_capabilities : Array[PdfV2UnsupportedCapabilityReport],
) -> Int {
  let mut count = 0
  for report in unsupported_capabilities {
    if report.status == PdfV2CapabilityStatus::Capped {
      count = count + 1
    }
  }
  count
}

///|
pub fn pdf_v2_layout_facts_from_model(
  model : PdfV2DocumentModel,
) -> PdfV2LayoutFactSet {
  let page_layouts : Array[PdfV2PageLayoutFacts] = []
  let warnings : Array[PdfV2Warning] = []
  let risks : Array[PdfV2Risk] = []
  let source_refs : Array[PdfV2SourceRef] = []
  warnings.append(model.warnings)
  risks.append(model.risks)
  for page in model.pages {
    let facts = pdf_v2_layout_page_facts(page)
    page_layouts.push(facts)
    source_refs.append(facts.source_refs)
    for warning in facts.warnings {
      if warning.reason_tags.contains("layout_facts_scaffold") {
        warnings.push(warning)
      }
    }
    for risk in facts.risks {
      if risk.reason_tags.contains("layout_facts_scaffold") {
        risks.push(risk)
      }
    }
  }
  let summary = pdf_v2_layout_summary(
    page_layouts,
    model.object_summary,
    model.unsupported_capabilities,
    warnings.length(),
    risks.length(),
  )
  {
    page_layouts,
    summary,
    warnings,
    risks,
    unsupported_capabilities: model.unsupported_capabilities,
    partial_fact_reports: model.partial_fact_reports,
    source_refs,
    one_pass: model.one_pass,
    no_fallback: model.no_fallback,
  }
}
