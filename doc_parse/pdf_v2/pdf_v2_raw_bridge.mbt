///|
fn pdf_v2_source_event_kind_from_core(
  kind : PdfV2CoreEventKind,
) -> PdfV2SourceEventKind {
  match kind {
    PageBegin => PageBegin
    PageEnd => PageEnd
    ContentStreamBegin => ContentStreamBegin
    ContentStreamEnd => ContentStreamEnd
    TextObjectBegin => TextObjectBegin
    TextObjectEnd => TextObjectEnd
    TextState => TextState
    FontUse => FontUse
    TextShow => TextShow
    GlyphCandidate => GlyphCandidate
    Glyph => Glyph
    Image => ImageObject
    InlineImage => InlineImage
    VectorPath => VectorPath
    Annotation => AnnotationObject
    Form => FormObject
    Outline => OutlineItem
    Destination => Destination
    Metadata => Metadata
    Resource => Resource
    Malformed => Malformed
    Unsupported => Unsupported
    Unknown => Unknown
  }
}

///|
fn pdf_v2_source_event_from_core_event(
  event : PdfV2CoreEvent,
) -> PdfV2SourceEvent {
  {
    kind: pdf_v2_source_event_kind_from_core(event.kind),
    page_index: event.page_index,
    text: event.text,
    bbox: event.bbox,
    object_ref: event.object_ref,
    source_ref: event.source_ref,
    reason_tags: event.reason_tags,
    warnings: event.warnings,
    risks: [],
    text_state: event.text_state,
    text_show: event.text_show,
    glyph_candidate: event.glyph_candidate,
    object_fact: event.object_fact,
  }
}

///|
pub fn pdf_v2_source_events_from_core_events(
  events : Array[PdfV2CoreEvent],
) -> Array[PdfV2SourceEvent] {
  events.map(pdf_v2_source_event_from_core_event)
}

///|
fn pdf_v2_collect_event_warnings(
  events : Array[PdfV2SourceEvent],
) -> Array[PdfV2Warning] {
  let warnings : Array[PdfV2Warning] = []
  for event in events {
    for warning in event.warnings {
      warnings.push(warning)
    }
  }
  warnings
}

///|
fn pdf_v2_events_for_page(
  events : Array[PdfV2SourceEvent],
  page_index : Int,
) -> Array[PdfV2SourceEvent] {
  let page_events : Array[PdfV2SourceEvent] = []
  for event in events {
    if event.page_index == Some(page_index) {
      page_events.push(event)
    }
  }
  page_events
}

///|
fn pdf_v2_page_warnings(
  events : Array[PdfV2SourceEvent],
) -> Array[PdfV2Warning] {
  pdf_v2_collect_event_warnings(events)
}

///|
fn pdf_v2_page_from_core_fact(
  fact : PdfV2CorePageFact,
  source_events : Array[PdfV2SourceEvent],
) -> PdfV2Page {
  let page_events = pdf_v2_events_for_page(source_events, fact.page_index)
  let bbox = match fact.crop_box {
    Some(crop_box) => crop_box
    None => fact.media_box
  }
  {
    page_index: fact.page_index,
    page_label: fact.page_label,
    media_box: fact.media_box,
    crop_box: fact.crop_box,
    rotate: fact.rotate,
    user_unit: fact.user_unit,
    resources_present: fact.resources_present,
    bbox,
    source_ref: fact.source_ref,
    events: page_events,
    text_blocks: [],
    layout_regions: [],
    warnings: pdf_v2_page_warnings(page_events),
    risks: [],
  }
}

///|
fn pdf_v2_pages_from_core(
  core : PdfV2CoreDocument,
  source_events : Array[PdfV2SourceEvent],
) -> Array[PdfV2Page] {
  core.page_facts.map(fn(fact) {
    pdf_v2_page_from_core_fact(fact, source_events)
  })
}

///|
fn pdf_v2_all_warnings(
  core : PdfV2CoreDocument,
  source_events : Array[PdfV2SourceEvent],
) -> Array[PdfV2Warning] {
  let warnings : Array[PdfV2Warning] = []
  for warning in core.warnings {
    warnings.push(warning)
  }
  for warning in pdf_v2_collect_event_warnings(source_events) {
    warnings.push(warning)
  }
  warnings
}

///|
fn pdf_v2_append_warnings(
  first : Array[PdfV2Warning],
  second : Array[PdfV2Warning],
) -> Array[PdfV2Warning] {
  let warnings : Array[PdfV2Warning] = []
  warnings.append(first)
  warnings.append(second)
  warnings
}

///|
fn pdf_v2_append_risks(
  first : Array[PdfV2Risk],
  second : Array[PdfV2Risk],
) -> Array[PdfV2Risk] {
  let risks : Array[PdfV2Risk] = []
  risks.append(first)
  risks.append(second)
  risks
}

///|
pub fn pdf_v2_source_document_from_core_with_options(
  core : PdfV2CoreDocument,
  events : Array[PdfV2CoreEvent],
  options : PdfV2CoreOpenOptions,
) -> PdfV2SourceDocument {
  let source_events = pdf_v2_source_events_from_core_events(events)
  let object_candidates = pdf_v2_object_candidates_from_source_events(
    source_events,
  )
  let capped_object_candidates = pdf_v2_apply_object_caps_to_collections(
    object_candidates.image_candidates,
    object_candidates.inline_image_candidates,
    object_candidates.annotation_candidates,
    object_candidates.link_candidates,
    object_candidates.form_candidates,
    object_candidates.outline_candidates,
    object_candidates.destination_candidates,
    object_candidates.resource_candidates,
    object_candidates.metadata_candidates,
    options.object_caps,
  )
  let pages = pdf_v2_pages_from_core(core, source_events)
  let font_cache = pdf_v2_build_font_cache_from_text_events(events)
  let reconstruction = pdf_v2_reconstruct_char_candidates(
    events,
    font_cache,
    pdf_v2_default_max_char_candidates(),
  )
  let span_reconstruction = pdf_v2_reconstruct_span_candidates(
    reconstruction.char_candidates,
    pdf_v2_default_span_reconstruction_options(),
  )
  let line_reconstruction = pdf_v2_reconstruct_line_candidates(
    span_reconstruction.spans,
    pdf_v2_default_line_reconstruction_options(),
  )
  let block_reconstruction = pdf_v2_reconstruct_block_candidates(
    line_reconstruction.lines,
    pdf_v2_default_block_reconstruction_options(),
  )
  let table_candidates = pdf_v2_build_table_candidates(
    source_events,
    block_reconstruction.blocks,
  )
  let warnings = pdf_v2_append_warnings(
    pdf_v2_append_warnings(
      pdf_v2_append_warnings(
        pdf_v2_append_warnings(
          pdf_v2_append_warnings(
            pdf_v2_all_warnings(core, source_events),
            reconstruction.warnings,
          ),
          capped_object_candidates.warnings,
        ),
        span_reconstruction.warnings,
      ),
      line_reconstruction.warnings,
    ),
    block_reconstruction.warnings,
  )
  let risks = pdf_v2_append_risks(
    pdf_v2_append_risks(
      pdf_v2_append_risks(
        pdf_v2_append_risks(core.risks, reconstruction.risks),
        span_reconstruction.risks,
      ),
      line_reconstruction.risks,
    ),
    pdf_v2_append_risks(
      block_reconstruction.risks,
      capped_object_candidates.risks,
    ),
  )
  let page_count = if core.page_count > 0 {
    core.page_count
  } else {
    pages.length()
  }
  {
    source_events,
    pages,
    font_cache,
    char_candidates: reconstruction.char_candidates,
    span_candidates: span_reconstruction.spans,
    line_candidates: line_reconstruction.lines,
    block_candidates: block_reconstruction.blocks,
    table_candidates,
    image_candidates: capped_object_candidates.image_candidates,
    inline_image_candidates: capped_object_candidates.inline_image_candidates,
    annotation_candidates: capped_object_candidates.annotation_candidates,
    link_candidates: capped_object_candidates.link_candidates,
    form_candidates: capped_object_candidates.form_candidates,
    outline_candidates: capped_object_candidates.outline_candidates,
    destination_candidates: capped_object_candidates.destination_candidates,
    resource_candidates: capped_object_candidates.resource_candidates,
    metadata_candidates: capped_object_candidates.metadata_candidates,
    unsupported_capabilities: capped_object_candidates.unsupported_capabilities,
    partial_fact_reports: capped_object_candidates.partial_fact_reports,
    object_summary: capped_object_candidates.summary,
    reconstruction_summary: pdf_v2_merge_block_reconstruction_summary(
      pdf_v2_merge_line_reconstruction_summary(
        pdf_v2_merge_reconstruction_summaries(
          reconstruction.summary,
          span_reconstruction.summary,
        ),
        line_reconstruction.summary,
      ),
      block_reconstruction.summary,
    ),
    summary: pdf_v2_source_summary(
      source_events.length(),
      page_count,
      warnings.length(),
      risks.length(),
    ),
    warnings,
    risks,
  }
}

///|
pub fn pdf_v2_source_document_from_core(
  core : PdfV2CoreDocument,
  events : Array[PdfV2CoreEvent],
) -> PdfV2SourceDocument {
  pdf_v2_source_document_from_core_with_options(
    core,
    events,
    default_pdf_v2_core_open_options(),
  )
}
