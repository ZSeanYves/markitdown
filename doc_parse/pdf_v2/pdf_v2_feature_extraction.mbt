///|
fn pdf_v2_feature_append_refs(
  refs : Array[PdfV2SourceRef],
  more : Array[PdfV2SourceRef],
) -> Unit {
  refs.append(more)
}

///|
fn pdf_v2_feature_capped_count(
  reports : Array[PdfV2UnsupportedCapabilityReport],
) -> Int {
  let mut count = 0
  for report in reports {
    if report.status == PdfV2CapabilityStatus::Capped {
      count = count + 1
    }
  }
  count
}

///|
fn pdf_v2_feature_page_layout(
  layout : PdfV2LayoutFactSet,
  page_index : Int,
) -> PdfV2PageLayoutFacts? {
  for page in layout.page_layouts {
    if page.page_index == page_index {
      return Some(page)
    }
  }
  None
}

///|
fn pdf_v2_feature_page_unsupported_count(
  reports : Array[PdfV2UnsupportedCapabilityReport],
  page_index : Int,
) -> Int {
  let mut count = 0
  for report in reports {
    if report.page_index == Some(page_index) {
      count = count + 1
    }
  }
  count
}

///|
fn pdf_v2_feature_page_partial_count(
  reports : Array[PdfV2PartialFactReport],
  page_index : Int,
) -> Int {
  let mut count = 0
  for report in reports {
    if report.page_index == Some(page_index) {
      count = count + 1
    }
  }
  count
}

///|
fn pdf_v2_feature_status_is_unsupported(status : PdfV2CapabilityStatus) -> Bool {
  status == PdfV2CapabilityStatus::Unsupported ||
  status == PdfV2CapabilityStatus::Failed
}

///|
fn pdf_v2_feature_status_is_partial(status : PdfV2CapabilityStatus) -> Bool {
  status == PdfV2CapabilityStatus::Partial ||
  status == PdfV2CapabilityStatus::Unknown
}

///|
fn pdf_v2_feature_decode_confidence_value(
  confidence : PdfV2TextDecodeConfidence,
) -> Double {
  match confidence {
    High => 1.0
    Medium => 0.75
    Low => 0.4
    Unknown => 0.2
    Failed => 0.0
  }
}

///|
fn pdf_v2_feature_block_span_count(block : PdfV2BlockCandidate) -> Int {
  let mut count = 0
  for line in block.lines {
    count = count + line.spans.length()
  }
  count
}

///|
fn pdf_v2_feature_block_char_count(block : PdfV2BlockCandidate) -> Int {
  let mut count = 0
  for line in block.lines {
    for span in line.spans {
      count = count + span.chars.length()
    }
  }
  count
}

///|
fn pdf_v2_feature_object_presence_flags(
  page : PdfV2PageModel,
) -> PdfV2ObjectPresenceFlags {
  {
    has_images: page.images.length() > 0,
    has_inline_images: page.inline_images.length() > 0,
    has_annotations: page.annotations.length() > 0,
    has_links: page.links.length() > 0,
    has_forms: page.forms.length() > 0,
    has_resources: page.resources.length() > 0,
  }
}

///|
fn pdf_v2_feature_block_low_signal(block : PdfV2BlockCandidate) -> Bool {
  block.block_kind_hint == PdfV2BlockKindHint::LowSignal ||
  block.decode_confidence == PdfV2TextDecodeConfidence::Unknown ||
  block.decode_confidence == PdfV2TextDecodeConfidence::Failed ||
  block.geometry_confidence == PdfV2GeometryConfidence::Unknown ||
  block.bbox is None ||
  block.text.length() == 0
}

///|
fn pdf_v2_feature_block_capped_context(
  layout : PdfV2LayoutFactSet,
  page_index : Int?,
) -> Bool {
  for report in layout.unsupported_capabilities {
    if report.status == PdfV2CapabilityStatus::Capped &&
      (page_index is None || report.page_index == page_index) {
      return true
    }
  }
  false
}

///|
fn pdf_v2_feature_page_row(
  page : PdfV2PageModel,
  layout_page : PdfV2PageLayoutFacts?,
  layout : PdfV2LayoutFactSet,
) -> PdfV2PageFeatureRow {
  let text_candidate_count = page.blocks.length() +
    page.lines.length() +
    page.spans.length() +
    page.chars.length()
  match layout_page {
    Some(facts) =>
      {
        page_index: page.page_index,
        text_candidate_count,
        block_candidate_count: page.blocks.length(),
        line_candidate_count: page.lines.length(),
        span_candidate_count: page.spans.length(),
        char_candidate_count: page.chars.length(),
        image_count: page.images.length() + page.inline_images.length(),
        annotation_count: page.annotations.length(),
        link_count: page.links.length(),
        form_count: page.forms.length(),
        resource_count: page.resources.length(),
        geometry_coverage: facts.geometry_coverage,
        reading_order_status: facts.reading_order_status,
        layout_region_status: facts.layout_region_status,
        image_region_status: facts.image_region_status,
        annotation_region_status: facts.annotation_region_status,
        unsupported_capability_count: pdf_v2_feature_page_unsupported_count(
          layout.unsupported_capabilities,
          page.page_index,
        ),
        partial_fact_count: pdf_v2_feature_page_partial_count(
          layout.partial_fact_reports,
          page.page_index,
        ),
        warning_count: facts.warnings.length(),
        risk_count: facts.risks.length(),
        source_refs: facts.source_refs,
      }
    None =>
      {
        page_index: page.page_index,
        text_candidate_count,
        block_candidate_count: page.blocks.length(),
        line_candidate_count: page.lines.length(),
        span_candidate_count: page.spans.length(),
        char_candidate_count: page.chars.length(),
        image_count: page.images.length() + page.inline_images.length(),
        annotation_count: page.annotations.length(),
        link_count: page.links.length(),
        form_count: page.forms.length(),
        resource_count: page.resources.length(),
        geometry_coverage: PdfV2GeometryCoverage::Unknown,
        reading_order_status: PdfV2LayoutRecoveryStatus::NotAttempted,
        layout_region_status: PdfV2LayoutRecoveryStatus::NotAttempted,
        image_region_status: PdfV2LayoutRecoveryStatus::NotAttempted,
        annotation_region_status: PdfV2LayoutRecoveryStatus::NotAttempted,
        unsupported_capability_count: pdf_v2_feature_page_unsupported_count(
          layout.unsupported_capabilities,
          page.page_index,
        ),
        partial_fact_count: pdf_v2_feature_page_partial_count(
          layout.partial_fact_reports,
          page.page_index,
        ),
        warning_count: page.page_warnings.length(),
        risk_count: page.page_risks.length(),
        source_refs: [page.source_ref],
      }
  }
}

///|
fn pdf_v2_feature_block_row(
  page : PdfV2PageModel,
  block : PdfV2BlockCandidate,
  layout : PdfV2LayoutFactSet,
) -> PdfV2BlockFeatureRow {
  let unsupported_count = match block.page_index {
    Some(index) =>
      pdf_v2_feature_page_unsupported_count(
        layout.unsupported_capabilities,
        index,
      )
    None => 0
  }
  let partial_count = match block.page_index {
    Some(index) =>
      pdf_v2_feature_page_partial_count(layout.partial_fact_reports, index)
    None => 0
  }
  let missing_geometry = block.bbox is None ||
    block.geometry_confidence == PdfV2GeometryConfidence::Unknown
  {
    page_index: block.page_index,
    block_index: block.block_index,
    text_length: block.text.length(),
    line_count: block.lines.length(),
    span_count: pdf_v2_feature_block_span_count(block),
    char_count: pdf_v2_feature_block_char_count(block),
    avg_decode_confidence: pdf_v2_feature_decode_confidence_value(
      block.decode_confidence,
    ),
    geometry_confidence: block.geometry_confidence,
    has_bbox: block.bbox is Some(_),
    source_ref_count: block.source_refs.length(),
    warning_count: block.warnings.length(),
    risk_count: if pdf_v2_feature_block_low_signal(block) {
      1
    } else {
      0
    },
    unsupported_nearby_or_page_count: unsupported_count,
    partial_fact_nearby_or_page_count: partial_count,
    object_presence_flags: pdf_v2_feature_object_presence_flags(page),
    low_signal_flag: pdf_v2_feature_block_low_signal(block),
    missing_geometry_flag: missing_geometry,
    capped_context_flag: pdf_v2_feature_block_capped_context(
      layout,
      block.page_index,
    ),
    reason_tags: block.reason_tags,
    source_refs: block.source_refs,
  }
}

///|
fn pdf_v2_feature_status_from_image(
  status : PdfV2ImageDecodeStatus,
) -> PdfV2CapabilityStatus {
  match status {
    MetadataOnly => MetadataOnly
    DecodeAvailable => Supported
    Unsupported => Unsupported
    NotAttempted => NotAttempted
  }
}

///|
fn pdf_v2_feature_object_row(
  page_index : Int?,
  object_kind : String,
  status : PdfV2CapabilityStatus,
  has_bbox : Bool,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
  reason_tags : Array[String],
  source_refs : Array[PdfV2SourceRef],
) -> PdfV2ObjectFeatureRow {
  {
    page_index,
    object_kind,
    capability_status: status,
    metadata_only: status == PdfV2CapabilityStatus::MetadataOnly,
    partial: pdf_v2_feature_status_is_partial(status),
    unsupported: pdf_v2_feature_status_is_unsupported(status),
    capped: status == PdfV2CapabilityStatus::Capped,
    has_bbox,
    has_source_ref: source_refs.length() > 0,
    warning_count: warnings.length(),
    risk_count: risks.length(),
    reason_tags,
    source_refs,
  }
}

///|
fn pdf_v2_feature_add_page_object_rows(
  page : PdfV2PageModel,
  object_rows : Array[PdfV2ObjectFeatureRow],
) -> Unit {
  for image in page.images {
    object_rows.push(
      pdf_v2_feature_object_row(
        image.page_index,
        "image",
        pdf_v2_feature_status_from_image(image.decode_status),
        image.bbox is Some(_),
        image.warnings,
        image.risks,
        image.reason_tags,
        [image.source_ref],
      ),
    )
  }
  for image in page.inline_images {
    object_rows.push(
      pdf_v2_feature_object_row(
        image.page_index,
        "inline_image",
        pdf_v2_feature_status_from_image(image.decode_status),
        image.bbox is Some(_),
        image.warnings,
        image.risks,
        image.reason_tags,
        [image.source_ref],
      ),
    )
  }
  for annotation in page.annotations {
    object_rows.push(
      pdf_v2_feature_object_row(
        annotation.page_index,
        "annotation",
        PdfV2CapabilityStatus::Partial,
        annotation.rect is Some(_),
        annotation.warnings,
        annotation.risks,
        annotation.reason_tags,
        [annotation.source_ref],
      ),
    )
  }
  for link in page.links {
    object_rows.push(
      pdf_v2_feature_object_row(
        link.page_index,
        "link",
        PdfV2CapabilityStatus::Partial,
        link.rect is Some(_),
        link.warnings,
        link.risks,
        link.reason_tags,
        [link.source_ref],
      ),
    )
  }
  for form in page.forms {
    object_rows.push(
      pdf_v2_feature_object_row(
        form.page_index,
        "form",
        PdfV2CapabilityStatus::Partial,
        form.rect is Some(_),
        form.warnings,
        form.risks,
        form.reason_tags,
        [form.source_ref],
      ),
    )
  }
  for resource in page.resources {
    object_rows.push(
      pdf_v2_feature_object_row(
        resource.page_index,
        "resource",
        PdfV2CapabilityStatus::Supported,
        false,
        resource.warnings,
        resource.risks,
        resource.reason_tags,
        [resource.source_ref],
      ),
    )
  }
}

///|
fn pdf_v2_feature_add_document_object_rows(
  model : PdfV2DocumentModel,
  object_rows : Array[PdfV2ObjectFeatureRow],
) -> Unit {
  for outline in model.outlines {
    object_rows.push(
      pdf_v2_feature_object_row(
        outline.source_ref.page_index,
        "outline",
        PdfV2CapabilityStatus::Partial,
        false,
        outline.warnings,
        outline.risks,
        outline.reason_tags,
        [outline.source_ref],
      ),
    )
  }
  for destination in model.destinations {
    object_rows.push(
      pdf_v2_feature_object_row(
        destination.source_ref.page_index,
        "destination",
        PdfV2CapabilityStatus::Partial,
        false,
        destination.warnings,
        destination.risks,
        destination.reason_tags,
        [destination.source_ref],
      ),
    )
  }
  for item in model.metadata_candidates {
    object_rows.push(
      pdf_v2_feature_object_row(
        item.source_ref.page_index,
        "metadata",
        if item.value is Some(_) {
          PdfV2CapabilityStatus::Supported
        } else {
          PdfV2CapabilityStatus::Partial
        },
        false,
        item.warnings,
        item.risks,
        item.reason_tags,
        [item.source_ref],
      ),
    )
  }
}

///|
fn pdf_v2_feature_add_report_object_rows(
  layout : PdfV2LayoutFactSet,
  object_rows : Array[PdfV2ObjectFeatureRow],
) -> Unit {
  for report in layout.unsupported_capabilities {
    let refs = match report.source_ref {
      Some(value) => [value]
      None => []
    }
    object_rows.push(
      pdf_v2_feature_object_row(
        report.page_index,
        "capability_report",
        report.status,
        false,
        [],
        [],
        report.reason_tags,
        refs,
      ),
    )
  }
  for report in layout.partial_fact_reports {
    let refs = match report.source_ref {
      Some(value) => [value]
      None => []
    }
    object_rows.push(
      pdf_v2_feature_object_row(
        report.page_index,
        "partial_" + report.fact_kind,
        report.status,
        false,
        report.warnings,
        report.risks,
        report.reason_tags,
        refs,
      ),
    )
  }
}

///|
fn pdf_v2_feature_document_row(
  model : PdfV2DocumentModel,
  layout : PdfV2LayoutFactSet,
) -> PdfV2DocumentFeatureRow {
  let mut has_text = false
  for page in model.pages {
    if page.blocks.length() > 0 ||
      page.lines.length() > 0 ||
      page.spans.length() > 0 ||
      page.chars.length() > 0 {
      has_text = true
    }
  }
  {
    page_count: model.page_count,
    has_text,
    has_images: model.object_summary.image_count > 0 ||
    model.object_summary.inline_image_count > 0,
    has_annotations: model.object_summary.annotation_count > 0 ||
    model.object_summary.link_count > 0,
    has_forms: model.object_summary.form_count > 0,
    has_outlines: model.object_summary.outline_count > 0,
    has_metadata: model.object_summary.metadata_count > 0,
    unsupported_capability_count: model.object_summary.unsupported_capability_count,
    partial_fact_count: model.object_summary.partial_fact_count,
    capped_object_count: pdf_v2_feature_capped_count(
      layout.unsupported_capabilities,
    ),
    metadata_only_count: model.object_summary.metadata_only_count,
    warning_count: layout.warnings.length(),
    risk_count: layout.risks.length(),
  }
}

///|
fn pdf_v2_feature_summary(
  page_features : Array[PdfV2PageFeatureRow],
  block_features : Array[PdfV2BlockFeatureRow],
  object_features : Array[PdfV2ObjectFeatureRow],
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> PdfV2FeatureSummary {
  let mut low_signal_block_count = 0
  let mut missing_geometry_block_count = 0
  for block in block_features {
    if block.low_signal_flag {
      low_signal_block_count = low_signal_block_count + 1
    }
    if block.missing_geometry_flag {
      missing_geometry_block_count = missing_geometry_block_count + 1
    }
  }
  let mut unsupported_object_count = 0
  let mut partial_object_count = 0
  let mut capped_object_count = 0
  for object in object_features {
    if object.unsupported {
      unsupported_object_count = unsupported_object_count + 1
    }
    if object.partial {
      partial_object_count = partial_object_count + 1
    }
    if object.capped {
      capped_object_count = capped_object_count + 1
    }
  }
  {
    document_feature_count: 1,
    page_feature_count: page_features.length(),
    block_feature_count: block_features.length(),
    object_feature_count: object_features.length(),
    low_signal_block_count,
    missing_geometry_block_count,
    unsupported_object_count,
    partial_object_count,
    capped_object_count,
    warning_count: warnings.length(),
    risk_count: risks.length(),
  }
}

///|
pub fn pdf_v2_features_from_model_and_layout(
  model : PdfV2DocumentModel,
  layout : PdfV2LayoutFactSet,
) -> PdfV2FeatureSet {
  let page_features : Array[PdfV2PageFeatureRow] = []
  let block_features : Array[PdfV2BlockFeatureRow] = []
  let object_features : Array[PdfV2ObjectFeatureRow] = []
  let source_refs : Array[PdfV2SourceRef] = []
  for page in model.pages {
    let layout_page = pdf_v2_feature_page_layout(layout, page.page_index)
    let page_row = pdf_v2_feature_page_row(page, layout_page, layout)
    pdf_v2_feature_append_refs(source_refs, page_row.source_refs)
    page_features.push(page_row)
    for block in page.blocks {
      let block_row = pdf_v2_feature_block_row(page, block, layout)
      pdf_v2_feature_append_refs(source_refs, block_row.source_refs)
      block_features.push(block_row)
    }
    pdf_v2_feature_add_page_object_rows(page, object_features)
  }
  pdf_v2_feature_add_document_object_rows(model, object_features)
  pdf_v2_feature_add_report_object_rows(layout, object_features)
  for object in object_features {
    pdf_v2_feature_append_refs(source_refs, object.source_refs)
  }
  let warnings : Array[PdfV2Warning] = []
  let risks : Array[PdfV2Risk] = []
  warnings.append(layout.warnings)
  risks.append(layout.risks)
  let document_features = pdf_v2_feature_document_row(model, layout)
  {
    document_features,
    page_features,
    block_features,
    object_features,
    summary: pdf_v2_feature_summary(
      page_features, block_features, object_features, warnings, risks,
    ),
    warnings,
    risks,
    source_refs,
    one_pass: model.one_pass && layout.one_pass,
    no_fallback: model.no_fallback && layout.no_fallback,
  }
}
