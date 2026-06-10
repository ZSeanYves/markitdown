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
pub fn pdf_v2_source_document_from_core(
  core : PdfV2CoreDocument,
  events : Array[PdfV2CoreEvent],
) -> PdfV2SourceDocument {
  let source_events = pdf_v2_source_events_from_core_events(events)
  let pages = pdf_v2_pages_from_core(core, source_events)
  let font_cache = pdf_v2_build_font_cache_from_text_events(events)
  let reconstruction = pdf_v2_reconstruct_char_candidates(
    events,
    font_cache,
    pdf_v2_default_max_char_candidates(),
  )
  let warnings = pdf_v2_append_warnings(
    pdf_v2_all_warnings(core, source_events),
    reconstruction.warnings,
  )
  let risks = pdf_v2_append_risks(core.risks, reconstruction.risks)
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
    reconstruction_summary: reconstruction.summary,
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
