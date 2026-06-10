///|
pub(all) struct PdfV2ObjectCapOptions {
  max_images : Int?
  max_inline_images : Int?
  max_annotations : Int?
  max_links : Int?
  max_forms : Int?
  max_outlines : Int?
  max_destinations : Int?
  max_resources : Int?
  max_metadata_entries : Int?
}

///|
priv struct PdfV2ObjectCapApplication {
  image_candidates : Array[PdfV2ImageCandidate]
  inline_image_candidates : Array[PdfV2InlineImageCandidate]
  annotation_candidates : Array[PdfV2AnnotationCandidate]
  link_candidates : Array[PdfV2LinkCandidate]
  form_candidates : Array[PdfV2FormCandidate]
  outline_candidates : Array[PdfV2OutlineCandidate]
  destination_candidates : Array[PdfV2DestinationCandidate]
  resource_candidates : Array[PdfV2ResourceCandidate]
  metadata_candidates : Array[PdfV2MetadataCandidate]
  unsupported_capabilities : Array[PdfV2UnsupportedCapabilityReport]
  partial_fact_reports : Array[PdfV2PartialFactReport]
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  summary : PdfV2ObjectSummary
}

///|
pub fn pdf_v2_default_object_cap_options() -> PdfV2ObjectCapOptions {
  {
    max_images: None,
    max_inline_images: None,
    max_annotations: None,
    max_links: None,
    max_forms: None,
    max_outlines: None,
    max_destinations: None,
    max_resources: None,
    max_metadata_entries: None,
  }
}

///|
fn pdf_v2_object_cap_limit(limit : Int?, current : Int) -> Int {
  match limit {
    Some(value) if value <= 0 => 0
    Some(value) if value < current => value
    _ => current
  }
}

///|
fn pdf_v2_object_cap_hit(limit : Int?, current : Int) -> Bool {
  match limit {
    Some(value) => value < current
    None => false
  }
}

///|
fn pdf_v2_object_cap_source_ref(source_ref : PdfV2SourceRef?) -> PdfV2SourceRef {
  match source_ref {
    Some(value) => value
    None => pdf_v2_document_source_ref()
  }
}

///|
fn pdf_v2_object_cap_warning(
  fact_kind : String,
  limit : Int,
  total : Int,
  source_ref : PdfV2SourceRef?,
) -> PdfV2Warning {
  let source = pdf_v2_object_cap_source_ref(source_ref)
  pdf_v2_warning(
    PdfV2WarningKind::PerformanceCap,
    PdfV2Severity::Warning,
    "PDF v2 object facts capped \{fact_kind} candidates at \{limit} of \{total}",
    [source],
    ["object_cap", "performance_cap", "capability_report", fact_kind],
  )
}

///|
fn pdf_v2_object_cap_risk(
  fact_kind : String,
  limit : Int,
  total : Int,
  source_ref : PdfV2SourceRef?,
) -> PdfV2Risk {
  let source = pdf_v2_object_cap_source_ref(source_ref)
  {
    kind: PdfV2RiskKind::PerformanceCapReached,
    severity: PdfV2Severity::Warning,
    message: "PDF v2 object facts capped \{fact_kind} candidates at \{limit} of \{total}",
    source_refs: [source],
    reason_tags: [
      "object_cap", "performance_cap", "capability_report", fact_kind,
    ],
  }
}

///|
fn pdf_v2_object_cap_report(
  fact_kind : String,
  limit : Int,
  total : Int,
  source_ref : PdfV2SourceRef?,
) -> PdfV2UnsupportedCapabilityReport {
  {
    capability: fact_kind + "_cap",
    status: PdfV2CapabilityStatus::Capped,
    page_index: source_ref.bind(fn(src) { src.page_index }),
    object_ref: source_ref.bind(fn(src) { src.object_id }),
    source_ref,
    message: "PDF v2 object facts capped \{fact_kind} candidates at \{limit} of \{total}",
    reason_tags: [
      "object_cap", "performance_cap", "capability_report", fact_kind,
    ],
    severity: PdfV2Severity::Warning,
  }
}

///|
fn pdf_v2_object_ref_for_cap(
  kind : String,
  images : Array[PdfV2ImageCandidate],
  inline_images : Array[PdfV2InlineImageCandidate],
  annotations : Array[PdfV2AnnotationCandidate],
  links : Array[PdfV2LinkCandidate],
  forms : Array[PdfV2FormCandidate],
  outlines : Array[PdfV2OutlineCandidate],
  destinations : Array[PdfV2DestinationCandidate],
  resources : Array[PdfV2ResourceCandidate],
  metadata : Array[PdfV2MetadataCandidate],
  limit : Int,
) -> PdfV2SourceRef? {
  if kind == "image" && images.length() > limit && limit >= 0 {
    Some(images[limit].source_ref)
  } else if kind == "inline_image" &&
    inline_images.length() > limit &&
    limit >= 0 {
    Some(inline_images[limit].source_ref)
  } else if kind == "annotation" && annotations.length() > limit && limit >= 0 {
    Some(annotations[limit].source_ref)
  } else if kind == "link" && links.length() > limit && limit >= 0 {
    Some(links[limit].source_ref)
  } else if kind == "form" && forms.length() > limit && limit >= 0 {
    Some(forms[limit].source_ref)
  } else if kind == "outline" && outlines.length() > limit && limit >= 0 {
    Some(outlines[limit].source_ref)
  } else if kind == "destination" && destinations.length() > limit && limit >= 0 {
    Some(destinations[limit].source_ref)
  } else if kind == "resource" && resources.length() > limit && limit >= 0 {
    Some(resources[limit].source_ref)
  } else if kind == "metadata" && metadata.length() > limit && limit >= 0 {
    Some(metadata[limit].source_ref)
  } else {
    None
  }
}

///|
fn pdf_v2_object_cap_maybe_record(
  fact_kind : String,
  limit_option : Int?,
  total : Int,
  source_ref : PdfV2SourceRef?,
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
  reports : Array[PdfV2UnsupportedCapabilityReport],
) -> Int {
  let limit = pdf_v2_object_cap_limit(limit_option, total)
  if pdf_v2_object_cap_hit(limit_option, total) {
    warnings.push(
      pdf_v2_object_cap_warning(fact_kind, limit, total, source_ref),
    )
    risks.push(pdf_v2_object_cap_risk(fact_kind, limit, total, source_ref))
    reports.push(pdf_v2_object_cap_report(fact_kind, limit, total, source_ref))
  }
  limit
}

///|
fn pdf_v2_object_image_heavy_filter(filters : Array[String]) -> String? {
  for filter in filters {
    if filter == "/JPXDecode" || filter == "/JBIG2Decode" {
      return Some(filter)
    }
  }
  None
}

///|
fn pdf_v2_object_decode_status_report(
  capability : String,
  page_index : Int?,
  object_ref : String?,
  source_ref : PdfV2SourceRef,
  status : PdfV2CapabilityStatus,
  message : String,
  reason_tags : Array[String],
  severity : PdfV2Severity,
) -> PdfV2UnsupportedCapabilityReport {
  {
    capability,
    status,
    page_index,
    object_ref,
    source_ref: Some(source_ref),
    message,
    reason_tags,
    severity,
  }
}

///|
fn pdf_v2_image_status_from_decode(
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
fn pdf_v2_add_image_capability_reports(
  image : PdfV2ImageCandidate,
  reports : Array[PdfV2UnsupportedCapabilityReport],
) -> Unit {
  let status = pdf_v2_image_status_from_decode(image.decode_status)
  if image.decode_status != PdfV2ImageDecodeStatus::DecodeAvailable {
    reports.push(
      pdf_v2_object_decode_status_report(
        "image_decode",
        image.page_index,
        image.object_ref,
        image.source_ref,
        status,
        "PDF v2 image candidate is metadata-only; image bytes were not decoded",
        [
          "object_capability", "image_decode", "metadata_only", "image_decode_not_attempted",
        ],
        PdfV2Severity::Info,
      ),
    )
  }
  match pdf_v2_object_image_heavy_filter(image.filters) {
    Some(filter) =>
      reports.push(
        pdf_v2_object_decode_status_report(
          "image_filter_" + filter,
          image.page_index,
          image.object_ref,
          image.source_ref,
          PdfV2CapabilityStatus::Unsupported,
          "PDF v2 image candidate uses unsupported/heavy filter " + filter,
          [
            "object_capability", "unsupported_filter", "image_decode_not_attempted",
            filter,
          ],
          PdfV2Severity::Warning,
        ),
      )
    None => ()
  }
}

///|
fn pdf_v2_add_inline_image_capability_reports(
  image : PdfV2InlineImageCandidate,
  reports : Array[PdfV2UnsupportedCapabilityReport],
) -> Unit {
  let status = pdf_v2_image_status_from_decode(image.decode_status)
  if image.decode_status != PdfV2ImageDecodeStatus::DecodeAvailable {
    reports.push(
      pdf_v2_object_decode_status_report(
        "inline_image_decode",
        image.page_index,
        None,
        image.source_ref,
        status,
        "PDF v2 inline image candidate is metadata-only; image bytes were not decoded",
        [
          "object_capability", "inline_image_decode", "metadata_only", "image_decode_not_attempted",
        ],
        PdfV2Severity::Info,
      ),
    )
  }
  match pdf_v2_object_image_heavy_filter(image.filters) {
    Some(filter) =>
      reports.push(
        pdf_v2_object_decode_status_report(
          "inline_image_filter_" + filter,
          image.page_index,
          None,
          image.source_ref,
          PdfV2CapabilityStatus::Unsupported,
          "PDF v2 inline image candidate uses unsupported/heavy filter " +
          filter,
          [
            "object_capability", "unsupported_filter", "image_decode_not_attempted",
            filter,
          ],
          PdfV2Severity::Warning,
        ),
      )
    None => ()
  }
}

///|
fn pdf_v2_object_unsupported_warning(
  capability : String,
  source_ref : PdfV2SourceRef,
  reason_tags : Array[String],
) -> PdfV2Warning {
  pdf_v2_warning(
    PdfV2WarningKind::UnsupportedCapability,
    PdfV2Severity::Warning,
    "PDF v2 object capability unsupported or intentionally not attempted: " +
    capability,
    [source_ref],
    reason_tags,
  )
}

///|
fn pdf_v2_object_unsupported_risk(
  capability : String,
  source_ref : PdfV2SourceRef,
  reason_tags : Array[String],
) -> PdfV2Risk {
  {
    kind: PdfV2RiskKind::UnsupportedFeature,
    severity: PdfV2Severity::Warning,
    message: "PDF v2 object capability unsupported or intentionally not attempted: " +
    capability,
    source_refs: [source_ref],
    reason_tags,
  }
}

///|
fn pdf_v2_available_missing_push(
  available : Array[String],
  missing : Array[String],
  field : String,
  present : Bool,
) -> Unit {
  if present {
    available.push(field)
  } else {
    missing.push(field)
  }
}

///|
fn pdf_v2_partial_report(
  fact_kind : String,
  page_index : Int?,
  object_ref : String?,
  source_ref : PdfV2SourceRef,
  available_fields : Array[String],
  missing_fields : Array[String],
  reason_tags : Array[String],
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> PdfV2PartialFactReport {
  {
    fact_kind,
    page_index,
    object_ref,
    source_ref: Some(source_ref),
    available_fields,
    missing_fields,
    status: if missing_fields.length() == 0 {
      PdfV2CapabilityStatus::Supported
    } else {
      PdfV2CapabilityStatus::Partial
    },
    reason_tags,
    warnings,
    risks,
  }
}

///|
fn pdf_v2_add_annotation_partial_report(
  annotation : PdfV2AnnotationCandidate,
  reports : Array[PdfV2PartialFactReport],
) -> Unit {
  let available : Array[String] = []
  let missing : Array[String] = []
  pdf_v2_available_missing_push(
    available,
    missing,
    "subtype",
    annotation.subtype is Some(_),
  )
  pdf_v2_available_missing_push(
    available,
    missing,
    "rect",
    annotation.rect is Some(_),
  )
  pdf_v2_available_missing_push(
    available,
    missing,
    "action_or_dest",
    annotation.uri is Some(_) || annotation.dest is Some(_),
  )
  if missing.length() > 0 ||
    annotation.reason_tags.contains("partial_object_fact") {
    reports.push(
      pdf_v2_partial_report(
        "annotation",
        annotation.page_index,
        annotation.object_ref,
        annotation.source_ref,
        available,
        missing,
        ["object_capability", "partial_fact", "annotation"],
        annotation.warnings,
        annotation.risks,
      ),
    )
  }
}

///|
fn pdf_v2_add_link_partial_report(
  link : PdfV2LinkCandidate,
  reports : Array[PdfV2PartialFactReport],
) -> Unit {
  let available : Array[String] = []
  let missing : Array[String] = []
  pdf_v2_available_missing_push(
    available,
    missing,
    "rect",
    link.rect is Some(_),
  )
  pdf_v2_available_missing_push(
    available,
    missing,
    "uri_or_dest",
    link.uri is Some(_) || link.dest is Some(_),
  )
  if missing.length() > 0 || link.reason_tags.contains("partial_object_fact") {
    reports.push(
      pdf_v2_partial_report(
        "link",
        link.page_index,
        link.object_ref,
        link.source_ref,
        available,
        missing,
        ["object_capability", "partial_fact", "link", "semantic_not_lowered"],
        link.warnings,
        link.risks,
      ),
    )
  }
}

///|
fn pdf_v2_add_form_partial_report(
  form : PdfV2FormCandidate,
  reports : Array[PdfV2PartialFactReport],
) -> Unit {
  let available : Array[String] = []
  let missing : Array[String] = []
  pdf_v2_available_missing_push(
    available,
    missing,
    "field_name",
    form.field_name is Some(_),
  )
  pdf_v2_available_missing_push(
    available,
    missing,
    "value",
    form.value is Some(_),
  )
  pdf_v2_available_missing_push(
    available,
    missing,
    "rect",
    form.rect is Some(_),
  )
  pdf_v2_available_missing_push(
    available,
    missing,
    "appearance_ref",
    form.appearance_ref is Some(_),
  )
  if missing.length() > 0 || form.reason_tags.contains("partial_object_fact") {
    reports.push(
      pdf_v2_partial_report(
        "form",
        form.page_index,
        form.object_ref,
        form.source_ref,
        available,
        missing,
        ["object_capability", "partial_fact", "form", "semantic_not_lowered"],
        form.warnings,
        form.risks,
      ),
    )
  }
}

///|
fn pdf_v2_add_outline_partial_report(
  outline : PdfV2OutlineCandidate,
  reports : Array[PdfV2PartialFactReport],
) -> Unit {
  let available : Array[String] = []
  let missing : Array[String] = []
  pdf_v2_available_missing_push(
    available,
    missing,
    "title",
    outline.title is Some(_),
  )
  pdf_v2_available_missing_push(
    available,
    missing,
    "dest_or_action",
    outline.dest is Some(_) || outline.action is Some(_),
  )
  if missing.length() > 0 || outline.reason_tags.contains("partial_object_fact") {
    reports.push(
      pdf_v2_partial_report(
        "outline",
        None,
        outline.source_ref.object_id,
        outline.source_ref,
        available,
        missing,
        ["object_capability", "partial_fact", "outline", "toc_not_lowered"],
        outline.warnings,
        outline.risks,
      ),
    )
  }
}

///|
fn pdf_v2_add_destination_partial_report(
  destination : PdfV2DestinationCandidate,
  reports : Array[PdfV2PartialFactReport],
) -> Unit {
  let available : Array[String] = []
  let missing : Array[String] = []
  pdf_v2_available_missing_push(
    available,
    missing,
    "dest_or_action",
    destination.dest is Some(_) || destination.action is Some(_),
  )
  pdf_v2_available_missing_push(
    available,
    missing,
    "target_page",
    destination.target_page is Some(_),
  )
  if missing.length() > 0 ||
    destination.reason_tags.contains("partial_object_fact") {
    reports.push(
      pdf_v2_partial_report(
        "destination",
        None,
        destination.source_ref.object_id,
        destination.source_ref,
        available,
        missing,
        ["object_capability", "partial_fact", "destination", "toc_not_lowered"],
        destination.warnings,
        destination.risks,
      ),
    )
  }
}

///|
fn pdf_v2_add_metadata_partial_report(
  metadata : PdfV2MetadataCandidate,
  reports : Array[PdfV2PartialFactReport],
) -> Unit {
  let available : Array[String] = []
  let missing : Array[String] = []
  pdf_v2_available_missing_push(
    available,
    missing,
    "key",
    metadata.key is Some(_),
  )
  pdf_v2_available_missing_push(
    available,
    missing,
    "value",
    metadata.value is Some(_),
  )
  if missing.length() > 0 ||
    metadata.reason_tags.contains("partial_object_fact") {
    reports.push(
      pdf_v2_partial_report(
        "metadata",
        metadata.source_ref.page_index,
        metadata.object_ref,
        metadata.source_ref,
        available,
        missing,
        ["object_capability", "partial_fact", "metadata"],
        metadata.warnings,
        metadata.risks,
      ),
    )
  }
}

///|
fn pdf_v2_object_summary_with_reports(
  images : Array[PdfV2ImageCandidate],
  inline_images : Array[PdfV2InlineImageCandidate],
  annotations : Array[PdfV2AnnotationCandidate],
  links : Array[PdfV2LinkCandidate],
  forms : Array[PdfV2FormCandidate],
  outlines : Array[PdfV2OutlineCandidate],
  destinations : Array[PdfV2DestinationCandidate],
  resources : Array[PdfV2ResourceCandidate],
  metadata : Array[PdfV2MetadataCandidate],
  unsupported_reports : Array[PdfV2UnsupportedCapabilityReport],
  partial_reports : Array[PdfV2PartialFactReport],
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
  capped_image_count : Int,
  capped_annotation_count : Int,
) -> PdfV2ObjectSummary {
  let mut unsupported_object_count = 0
  let mut metadata_only_count = 0
  let mut not_attempted_count = 0
  let mut failed_object_count = 0
  for report in unsupported_reports {
    if report.status == PdfV2CapabilityStatus::Unsupported {
      unsupported_object_count = unsupported_object_count + 1
    }
    if report.status == PdfV2CapabilityStatus::MetadataOnly {
      metadata_only_count = metadata_only_count + 1
    }
    if report.status == PdfV2CapabilityStatus::NotAttempted {
      not_attempted_count = not_attempted_count + 1
    }
    if report.status == PdfV2CapabilityStatus::Failed {
      failed_object_count = failed_object_count + 1
    }
  }
  {
    image_count: images.length(),
    inline_image_count: inline_images.length(),
    annotation_count: annotations.length(),
    link_count: links.length(),
    form_count: forms.length(),
    outline_count: outlines.length(),
    destination_count: destinations.length(),
    resource_count: resources.length(),
    metadata_count: metadata.length(),
    unsupported_object_count,
    warning_count: warnings.length(),
    risk_count: risks.length(),
    capped_image_count,
    capped_annotation_count,
    unsupported_capability_count: unsupported_reports.length(),
    partial_fact_count: partial_reports.length(),
    metadata_only_count,
    not_attempted_count,
    failed_object_count,
  }
}

///|
fn pdf_v2_append_candidate_diagnostics(
  images : Array[PdfV2ImageCandidate],
  inline_images : Array[PdfV2InlineImageCandidate],
  annotations : Array[PdfV2AnnotationCandidate],
  links : Array[PdfV2LinkCandidate],
  forms : Array[PdfV2FormCandidate],
  outlines : Array[PdfV2OutlineCandidate],
  destinations : Array[PdfV2DestinationCandidate],
  resources : Array[PdfV2ResourceCandidate],
  metadata : Array[PdfV2MetadataCandidate],
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> Unit {
  for image in images {
    warnings.append(image.warnings)
    risks.append(image.risks)
  }
  for image in inline_images {
    warnings.append(image.warnings)
    risks.append(image.risks)
  }
  for annotation in annotations {
    warnings.append(annotation.warnings)
    risks.append(annotation.risks)
  }
  for link in links {
    warnings.append(link.warnings)
    risks.append(link.risks)
  }
  for form in forms {
    warnings.append(form.warnings)
    risks.append(form.risks)
  }
  for outline in outlines {
    warnings.append(outline.warnings)
    risks.append(outline.risks)
  }
  for destination in destinations {
    warnings.append(destination.warnings)
    risks.append(destination.risks)
  }
  for resource in resources {
    warnings.append(resource.warnings)
    risks.append(resource.risks)
  }
  for item in metadata {
    warnings.append(item.warnings)
    risks.append(item.risks)
  }
}

///|
fn pdf_v2_append_unsupported_report_diagnostics(
  reports : Array[PdfV2UnsupportedCapabilityReport],
  warnings : Array[PdfV2Warning],
  risks : Array[PdfV2Risk],
) -> Unit {
  for report in reports {
    if report.status == PdfV2CapabilityStatus::Unsupported ||
      report.status == PdfV2CapabilityStatus::Failed {
      let source_ref = pdf_v2_object_cap_source_ref(report.source_ref)
      warnings.push(
        pdf_v2_object_unsupported_warning(
          report.capability,
          source_ref,
          report.reason_tags,
        ),
      )
      risks.push(
        pdf_v2_object_unsupported_risk(
          report.capability,
          source_ref,
          report.reason_tags,
        ),
      )
    }
  }
}

///|
fn pdf_v2_apply_object_caps_to_collections(
  images : Array[PdfV2ImageCandidate],
  inline_images : Array[PdfV2InlineImageCandidate],
  annotations : Array[PdfV2AnnotationCandidate],
  links : Array[PdfV2LinkCandidate],
  forms : Array[PdfV2FormCandidate],
  outlines : Array[PdfV2OutlineCandidate],
  destinations : Array[PdfV2DestinationCandidate],
  resources : Array[PdfV2ResourceCandidate],
  metadata : Array[PdfV2MetadataCandidate],
  caps : PdfV2ObjectCapOptions,
) -> PdfV2ObjectCapApplication {
  let unsupported_reports : Array[PdfV2UnsupportedCapabilityReport] = []
  let partial_reports : Array[PdfV2PartialFactReport] = []
  let warnings : Array[PdfV2Warning] = []
  let risks : Array[PdfV2Risk] = []
  let image_limit = pdf_v2_object_cap_maybe_record(
    "image",
    caps.max_images,
    images.length(),
    pdf_v2_object_ref_for_cap(
      "image",
      images,
      inline_images,
      annotations,
      links,
      forms,
      outlines,
      destinations,
      resources,
      metadata,
      pdf_v2_object_cap_limit(caps.max_images, images.length()),
    ),
    warnings,
    risks,
    unsupported_reports,
  )
  let inline_image_limit = pdf_v2_object_cap_maybe_record(
    "inline_image",
    caps.max_inline_images,
    inline_images.length(),
    pdf_v2_object_ref_for_cap(
      "inline_image",
      images,
      inline_images,
      annotations,
      links,
      forms,
      outlines,
      destinations,
      resources,
      metadata,
      pdf_v2_object_cap_limit(caps.max_inline_images, inline_images.length()),
    ),
    warnings,
    risks,
    unsupported_reports,
  )
  let annotation_limit = pdf_v2_object_cap_maybe_record(
    "annotation",
    caps.max_annotations,
    annotations.length(),
    pdf_v2_object_ref_for_cap(
      "annotation",
      images,
      inline_images,
      annotations,
      links,
      forms,
      outlines,
      destinations,
      resources,
      metadata,
      pdf_v2_object_cap_limit(caps.max_annotations, annotations.length()),
    ),
    warnings,
    risks,
    unsupported_reports,
  )
  let link_limit = pdf_v2_object_cap_maybe_record(
    "link",
    caps.max_links,
    links.length(),
    pdf_v2_object_ref_for_cap(
      "link",
      images,
      inline_images,
      annotations,
      links,
      forms,
      outlines,
      destinations,
      resources,
      metadata,
      pdf_v2_object_cap_limit(caps.max_links, links.length()),
    ),
    warnings,
    risks,
    unsupported_reports,
  )
  let form_limit = pdf_v2_object_cap_maybe_record(
    "form",
    caps.max_forms,
    forms.length(),
    pdf_v2_object_ref_for_cap(
      "form",
      images,
      inline_images,
      annotations,
      links,
      forms,
      outlines,
      destinations,
      resources,
      metadata,
      pdf_v2_object_cap_limit(caps.max_forms, forms.length()),
    ),
    warnings,
    risks,
    unsupported_reports,
  )
  let outline_limit = pdf_v2_object_cap_maybe_record(
    "outline",
    caps.max_outlines,
    outlines.length(),
    pdf_v2_object_ref_for_cap(
      "outline",
      images,
      inline_images,
      annotations,
      links,
      forms,
      outlines,
      destinations,
      resources,
      metadata,
      pdf_v2_object_cap_limit(caps.max_outlines, outlines.length()),
    ),
    warnings,
    risks,
    unsupported_reports,
  )
  let destination_limit = pdf_v2_object_cap_maybe_record(
    "destination",
    caps.max_destinations,
    destinations.length(),
    pdf_v2_object_ref_for_cap(
      "destination",
      images,
      inline_images,
      annotations,
      links,
      forms,
      outlines,
      destinations,
      resources,
      metadata,
      pdf_v2_object_cap_limit(caps.max_destinations, destinations.length()),
    ),
    warnings,
    risks,
    unsupported_reports,
  )
  let resource_limit = pdf_v2_object_cap_maybe_record(
    "resource",
    caps.max_resources,
    resources.length(),
    pdf_v2_object_ref_for_cap(
      "resource",
      images,
      inline_images,
      annotations,
      links,
      forms,
      outlines,
      destinations,
      resources,
      metadata,
      pdf_v2_object_cap_limit(caps.max_resources, resources.length()),
    ),
    warnings,
    risks,
    unsupported_reports,
  )
  let metadata_limit = pdf_v2_object_cap_maybe_record(
    "metadata",
    caps.max_metadata_entries,
    metadata.length(),
    pdf_v2_object_ref_for_cap(
      "metadata",
      images,
      inline_images,
      annotations,
      links,
      forms,
      outlines,
      destinations,
      resources,
      metadata,
      pdf_v2_object_cap_limit(caps.max_metadata_entries, metadata.length()),
    ),
    warnings,
    risks,
    unsupported_reports,
  )
  let capped_images : Array[PdfV2ImageCandidate] = []
  for i in 0..<image_limit {
    capped_images.push(images[i])
  }
  let capped_inline_images : Array[PdfV2InlineImageCandidate] = []
  for i in 0..<inline_image_limit {
    capped_inline_images.push(inline_images[i])
  }
  let capped_annotations : Array[PdfV2AnnotationCandidate] = []
  for i in 0..<annotation_limit {
    capped_annotations.push(annotations[i])
  }
  let capped_links : Array[PdfV2LinkCandidate] = []
  for i in 0..<link_limit {
    capped_links.push(links[i])
  }
  let capped_forms : Array[PdfV2FormCandidate] = []
  for i in 0..<form_limit {
    capped_forms.push(forms[i])
  }
  let capped_outlines : Array[PdfV2OutlineCandidate] = []
  for i in 0..<outline_limit {
    capped_outlines.push(outlines[i])
  }
  let capped_destinations : Array[PdfV2DestinationCandidate] = []
  for i in 0..<destination_limit {
    capped_destinations.push(destinations[i])
  }
  let capped_resources : Array[PdfV2ResourceCandidate] = []
  for i in 0..<resource_limit {
    capped_resources.push(resources[i])
  }
  let capped_metadata : Array[PdfV2MetadataCandidate] = []
  for i in 0..<metadata_limit {
    capped_metadata.push(metadata[i])
  }
  for image in capped_images {
    pdf_v2_add_image_capability_reports(image, unsupported_reports)
  }
  for image in capped_inline_images {
    pdf_v2_add_inline_image_capability_reports(image, unsupported_reports)
  }
  for annotation in capped_annotations {
    pdf_v2_add_annotation_partial_report(annotation, partial_reports)
  }
  for link in capped_links {
    pdf_v2_add_link_partial_report(link, partial_reports)
  }
  for form in capped_forms {
    pdf_v2_add_form_partial_report(form, partial_reports)
  }
  for outline in capped_outlines {
    pdf_v2_add_outline_partial_report(outline, partial_reports)
  }
  for destination in capped_destinations {
    pdf_v2_add_destination_partial_report(destination, partial_reports)
  }
  for item in capped_metadata {
    pdf_v2_add_metadata_partial_report(item, partial_reports)
  }
  pdf_v2_append_candidate_diagnostics(
    capped_images, capped_inline_images, capped_annotations, capped_links, capped_forms,
    capped_outlines, capped_destinations, capped_resources, capped_metadata, warnings,
    risks,
  )
  pdf_v2_append_unsupported_report_diagnostics(
    unsupported_reports, warnings, risks,
  )
  let summary = pdf_v2_object_summary_with_reports(
    capped_images,
    capped_inline_images,
    capped_annotations,
    capped_links,
    capped_forms,
    capped_outlines,
    capped_destinations,
    capped_resources,
    capped_metadata,
    unsupported_reports,
    partial_reports,
    warnings,
    risks,
    images.length() - capped_images.length(),
    annotations.length() - capped_annotations.length(),
  )
  {
    image_candidates: capped_images,
    inline_image_candidates: capped_inline_images,
    annotation_candidates: capped_annotations,
    link_candidates: capped_links,
    form_candidates: capped_forms,
    outline_candidates: capped_outlines,
    destination_candidates: capped_destinations,
    resource_candidates: capped_resources,
    metadata_candidates: capped_metadata,
    unsupported_capabilities: unsupported_reports,
    partial_fact_reports: partial_reports,
    warnings,
    risks,
    summary,
  }
}

///|
pub fn pdf_v2_apply_object_caps_to_source(
  source : PdfV2SourceDocument,
  caps : PdfV2ObjectCapOptions,
) -> PdfV2SourceDocument {
  let capped = pdf_v2_apply_object_caps_to_collections(
    source.image_candidates,
    source.inline_image_candidates,
    source.annotation_candidates,
    source.link_candidates,
    source.form_candidates,
    source.outline_candidates,
    source.destination_candidates,
    source.resource_candidates,
    source.metadata_candidates,
    caps,
  )
  let warnings : Array[PdfV2Warning] = []
  let risks : Array[PdfV2Risk] = []
  warnings.append(source.warnings)
  warnings.append(capped.warnings)
  risks.append(source.risks)
  risks.append(capped.risks)
  {
    source_events: source.source_events,
    pages: source.pages,
    font_cache: source.font_cache,
    char_candidates: source.char_candidates,
    span_candidates: source.span_candidates,
    line_candidates: source.line_candidates,
    block_candidates: source.block_candidates,
    image_candidates: capped.image_candidates,
    inline_image_candidates: capped.inline_image_candidates,
    annotation_candidates: capped.annotation_candidates,
    link_candidates: capped.link_candidates,
    form_candidates: capped.form_candidates,
    outline_candidates: capped.outline_candidates,
    destination_candidates: capped.destination_candidates,
    resource_candidates: capped.resource_candidates,
    metadata_candidates: capped.metadata_candidates,
    unsupported_capabilities: capped.unsupported_capabilities,
    partial_fact_reports: capped.partial_fact_reports,
    object_summary: capped.summary,
    reconstruction_summary: source.reconstruction_summary,
    summary: pdf_v2_source_summary(
      source.summary.event_count,
      source.summary.page_count,
      warnings.length(),
      risks.length(),
    ),
    warnings,
    risks,
  }
}

///|
pub fn pdf_v2_collect_unsupported_capabilities_from_model(
  model : PdfV2DocumentModel,
) -> Array[PdfV2UnsupportedCapabilityReport] {
  model.unsupported_capabilities
}

///|
pub fn pdf_v2_collect_partial_fact_reports_from_model(
  model : PdfV2DocumentModel,
) -> Array[PdfV2PartialFactReport] {
  model.partial_fact_reports
}
