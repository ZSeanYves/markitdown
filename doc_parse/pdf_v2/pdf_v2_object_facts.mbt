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
  for event in events {
    match event.object_fact {
      Some(ImageObjectFact(candidate)) => images.push(candidate)
      Some(InlineImageObjectFact(candidate)) => inline_images.push(candidate)
      Some(AnnotationObjectFact(candidate)) => annotations.push(candidate)
      Some(LinkObjectFact(candidate)) => links.push(candidate)
      Some(FormObjectFact(candidate)) => forms.push(candidate)
      Some(OutlineObjectFact(candidate)) => outlines.push(candidate)
      Some(DestinationObjectFact(candidate)) => destinations.push(candidate)
      Some(ResourceObjectFact(candidate)) => resources.push(candidate)
      Some(MetadataObjectFact(candidate)) => metadata.push(candidate)
      None => ()
    }
  }
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
  }
}
