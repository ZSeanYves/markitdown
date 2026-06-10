///|
priv struct PdfV2ObjectCandidateCollections {
  image_candidates : Array[PdfV2ImageCandidate]
  inline_image_candidates : Array[PdfV2InlineImageCandidate]
  annotation_candidates : Array[PdfV2AnnotationCandidate]
  link_candidates : Array[PdfV2LinkCandidate]
  form_candidates : Array[PdfV2FormCandidate]
  outline_candidates : Array[PdfV2OutlineCandidate]
  destination_candidates : Array[PdfV2DestinationCandidate]
  resource_candidates : Array[PdfV2ResourceCandidate]
  metadata_candidates : Array[PdfV2MetadataCandidate]
  warnings : Array[PdfV2Warning]
  risks : Array[PdfV2Risk]
  summary : PdfV2ObjectSummary
}

///|
fn pdf_v2_object_append_warnings(
  warnings : Array[PdfV2Warning],
  more : Array[PdfV2Warning],
) -> Unit {
  warnings.append(more)
}

///|
fn pdf_v2_object_append_risks(
  risks : Array[PdfV2Risk],
  more : Array[PdfV2Risk],
) -> Unit {
  risks.append(more)
}

///|
fn pdf_v2_object_image_unsupported(image : PdfV2ImageCandidate) -> Bool {
  image.decode_status == PdfV2ImageDecodeStatus::Unsupported ||
  image.reason_tags.contains("unsupported_object")
}

///|
fn pdf_v2_object_inline_unsupported(image : PdfV2InlineImageCandidate) -> Bool {
  image.decode_status == PdfV2ImageDecodeStatus::Unsupported ||
  image.reason_tags.contains("unsupported_object")
}

///|
fn pdf_v2_object_summary_from_collections(
  events : Array[PdfV2SourceEvent],
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
) -> PdfV2ObjectSummary {
  let mut unsupported_object_count = 0
  for image in images {
    if pdf_v2_object_image_unsupported(image) {
      unsupported_object_count = unsupported_object_count + 1
    }
  }
  for image in inline_images {
    if pdf_v2_object_inline_unsupported(image) {
      unsupported_object_count = unsupported_object_count + 1
    }
  }
  for event in events {
    if event.kind == PdfV2SourceEventKind::Unsupported {
      unsupported_object_count = unsupported_object_count + 1
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
  }
}

///|
fn pdf_v2_object_candidates_from_source_events(
  events : Array[PdfV2SourceEvent],
) -> PdfV2ObjectCandidateCollections {
  let images : Array[PdfV2ImageCandidate] = []
  let inline_images : Array[PdfV2InlineImageCandidate] = []
  let annotations : Array[PdfV2AnnotationCandidate] = []
  let links : Array[PdfV2LinkCandidate] = []
  let forms : Array[PdfV2FormCandidate] = []
  let outlines : Array[PdfV2OutlineCandidate] = []
  let destinations : Array[PdfV2DestinationCandidate] = []
  let resources : Array[PdfV2ResourceCandidate] = []
  let metadata : Array[PdfV2MetadataCandidate] = []
  let warnings : Array[PdfV2Warning] = []
  let risks : Array[PdfV2Risk] = []
  for event in events {
    match event.object_fact {
      Some(ImageObjectFact(candidate)) => {
        images.push(candidate)
        pdf_v2_object_append_warnings(warnings, candidate.warnings)
        pdf_v2_object_append_risks(risks, candidate.risks)
      }
      Some(InlineImageObjectFact(candidate)) => {
        inline_images.push(candidate)
        pdf_v2_object_append_warnings(warnings, candidate.warnings)
        pdf_v2_object_append_risks(risks, candidate.risks)
      }
      Some(AnnotationObjectFact(candidate)) => {
        annotations.push(candidate)
        pdf_v2_object_append_warnings(warnings, candidate.warnings)
        pdf_v2_object_append_risks(risks, candidate.risks)
      }
      Some(LinkObjectFact(candidate)) => {
        links.push(candidate)
        pdf_v2_object_append_warnings(warnings, candidate.warnings)
        pdf_v2_object_append_risks(risks, candidate.risks)
      }
      Some(FormObjectFact(candidate)) => {
        forms.push(candidate)
        pdf_v2_object_append_warnings(warnings, candidate.warnings)
        pdf_v2_object_append_risks(risks, candidate.risks)
      }
      Some(OutlineObjectFact(candidate)) => {
        outlines.push(candidate)
        pdf_v2_object_append_warnings(warnings, candidate.warnings)
        pdf_v2_object_append_risks(risks, candidate.risks)
      }
      Some(DestinationObjectFact(candidate)) => {
        destinations.push(candidate)
        pdf_v2_object_append_warnings(warnings, candidate.warnings)
        pdf_v2_object_append_risks(risks, candidate.risks)
      }
      Some(ResourceObjectFact(candidate)) => {
        resources.push(candidate)
        pdf_v2_object_append_warnings(warnings, candidate.warnings)
        pdf_v2_object_append_risks(risks, candidate.risks)
      }
      Some(MetadataObjectFact(candidate)) => {
        metadata.push(candidate)
        pdf_v2_object_append_warnings(warnings, candidate.warnings)
        pdf_v2_object_append_risks(risks, candidate.risks)
      }
      None => ()
    }
  }
  let summary = pdf_v2_object_summary_from_collections(
    events, images, inline_images, annotations, links, forms, outlines, destinations,
    resources, metadata, warnings, risks,
  )
  {
    image_candidates: images,
    inline_image_candidates: inline_images,
    annotation_candidates: annotations,
    link_candidates: links,
    form_candidates: forms,
    outline_candidates: outlines,
    destination_candidates: destinations,
    resource_candidates: resources,
    metadata_candidates: metadata,
    warnings,
    risks,
    summary,
  }
}
