///|
fn pptx_lower_document(
  source : @input.InputSource,
  presentation : @pptxdoc.PptxDocument,
  diagnostics : @core.Diagnostics,
  context : @parser.ParseContext,
) -> @core.DocumentIR {
  let document = @core.empty_document_ir()
  pptx_fill_metadata(document, source, presentation)
  let state = new_pptx_state(source, presentation, diagnostics, context)
  for slide in presentation.slides {
    if slide.hidden {
      pptx_note_hidden_slide_skipped(diagnostics, slide.slide_index)
      continue
    }
    pptx_lower_slide(document.blocks, state, slide)
  }
  pptx_append_document_warnings(document.blocks, state)
  @core.document_with_assets(document, state.assets)
}

///|
fn new_pptx_state(
  source : @input.InputSource,
  presentation : @pptxdoc.PptxDocument,
  diagnostics : @core.Diagnostics,
  context : @parser.ParseContext,
) -> PptxState {
  {
    source,
    context,
    diagnostics,
    presentation,
    lowering_profile: context.lowering_profile,
    accurate_features: context.accurate_features,
    assets: [],
    asset_ids: Map([]),
    image_ids: Map([]),
    slide_image_counts: Map([]),
    chart_fallback_emitted: { val: false },
  }
}

///|
fn pptx_feature_enabled(
  state : PptxState,
  feature : @product.AccurateFeature,
) -> Bool {
  if state.lowering_profile != AccurateSemantic {
    return false
  }
  @product.accurate_feature_enabled(state.accurate_features, feature)
}

///|
fn pptx_fill_metadata(
  document : @core.DocumentIR,
  source : @input.InputSource,
  presentation : @pptxdoc.PptxDocument,
) -> Unit {
  document.metadata.set("source_name", String(source.source_name))
  document.metadata.set("format", String("pptx"))
  document.metadata.set(
    "presentation_part",
    String(presentation.presentation.part_name),
  )
  document.metadata.set(
    "slide_count",
    Number(presentation.slides.length().to_string()),
  )
  document.metadata.set(
    "layout_count",
    Number(presentation.layouts.length().to_string()),
  )
  document.metadata.set(
    "master_count",
    Number(presentation.masters.length().to_string()),
  )
  match presentation.metadata.title {
    Some(title) => document.metadata.set("title", String(title))
    None => ()
  }
  match presentation.metadata.creator {
    Some(author) => document.metadata.set("creator", String(author))
    None => ()
  }
}

///|
fn pptx_lower_slide(
  blocks : Array[@core.CoreBlock],
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
) -> Unit {
  let slide_heading = @core.make_block(
    Heading,
    "Slide " + slide.slide_index.to_string(),
    source_ref=pptx_slide_source_ref(state.source, slide, None, None),
  )
  slide_heading.attrs.set("level", "2")
  blocks.push(slide_heading)

  let block_count_before = blocks.length()
  let visual_noise : Array[(String, String)] = []
  let unsupported_objects : Array[(String, String)] = []
  for obj in pptx_objects_for_slide(state, slide) {
    if !pptx_collect_visual_noise_for_slide(state, obj, visual_noise) &&
      !pptx_collect_unsupported_summary_for_slide(
        state, obj, unsupported_objects,
      ) {
      pptx_lower_object(blocks, state, slide, obj)
    }
  }
  pptx_flush_visual_noise_summary(blocks, state, slide, visual_noise)
  pptx_flush_unsupported_object_summary(
    blocks, state, slide, unsupported_objects,
  )
  pptx_lower_slide_comments(blocks, state, slide)
  pptx_lower_slide_notes(blocks, state, slide)
  if blocks.length() == block_count_before {
    blocks.push(
      @core.make_block(
        Paragraph,
        "(empty)",
        source_ref=pptx_slide_source_ref(state.source, slide, None, None),
      ),
    )
  }
}

///|
fn pptx_collect_unsupported_summary_for_slide(
  state : PptxState,
  obj : @pptxdoc.PptxObject,
  unsupported_objects : Array[(String, String)],
) -> Bool {
  if !pptx_feature_enabled(state, PptxGroupSummary) {
    return false
  }
  match obj {
    SmartArt(smart) => {
      unsupported_objects.push(("SmartArt", pptx_smartart_summary_label(smart)))
      true
    }
    Ole(ole) => {
      unsupported_objects.push(("OLE", pptx_ole_summary_label(ole)))
      true
    }
    Unsupported(unsupported) => {
      unsupported_objects.push(
        ("object", pptx_unsupported_summary_label(unsupported)),
      )
      true
    }
    _ => false
  }
}

///|
fn pptx_collect_visual_noise_for_slide(
  state : PptxState,
  obj : @pptxdoc.PptxObject,
  visual_noise : Array[(String, String)],
) -> Bool {
  if !pptx_feature_enabled(state, PptxGroupSummary) {
    return false
  }
  match obj {
    Shape(shape) =>
      if shape.text_body is None && pptx_is_decorative_shape(shape) {
        visual_noise.push(("decorative shape", pptx_shape_summary_label(shape)))
        true
      } else {
        false
      }
    Connector(conn) => {
      visual_noise.push(("connector", pptx_connector_summary_label(conn)))
      true
    }
    _ => false
  }
}

///|
fn pptx_flush_visual_noise_summary(
  blocks : Array[@core.CoreBlock],
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  visual_noise : Array[(String, String)],
) -> Unit {
  if visual_noise.length() == 0 {
    return
  }
  let source_ref = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      pptx_slide_source_ref(state.source, slide, None, None),
      "summary_kind",
      "pptx_visual_noise",
    ),
    "omitted_object_count",
    visual_noise.length().to_string(),
  )
  let raw = @core.make_block(
    Raw,
    pptx_visual_noise_summary_text(visual_noise),
    source_ref~,
  )
  raw.attrs.set("raw_kind", "pptx_visual_noise_summary")
  blocks.push(raw)
}

///|
fn pptx_flush_unsupported_object_summary(
  blocks : Array[@core.CoreBlock],
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  unsupported_objects : Array[(String, String)],
) -> Unit {
  if unsupported_objects.length() == 0 {
    return
  }
  let source_ref = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      pptx_slide_source_ref(state.source, slide, None, None),
      "summary_kind",
      "pptx_unsupported_objects",
    ),
    "unsupported_object_count",
    unsupported_objects.length().to_string(),
  )
  let raw = @core.make_block(
    Raw,
    pptx_unsupported_object_summary_text(unsupported_objects),
    source_ref~,
  )
  raw.attrs.set("raw_kind", "pptx_unsupported_object_summary")
  blocks.push(raw)
}

///|
fn pptx_visual_noise_summary_text(
  visual_noise : Array[(String, String)],
) -> String {
  let parts = StringBuilder::new()
  parts.write_string("[PPTX visual-only objects omitted: ")
  let mut i = 0
  while i < visual_noise.length() {
    if i > 0 {
      parts.write_string("; ")
    }
    let (kind, label) = visual_noise[i]
    parts.write_string(kind)
    parts.write_string(": ")
    parts.write_string(label)
    i += 1
  }
  parts.write_char(']')
  parts.to_string()
}

///|
fn pptx_unsupported_object_summary_text(
  unsupported_objects : Array[(String, String)],
) -> String {
  let parts = StringBuilder::new()
  parts.write_string("[PPTX unsupported objects summarized: ")
  let mut i = 0
  while i < unsupported_objects.length() {
    if i > 0 {
      parts.write_string("; ")
    }
    let (kind, label) = unsupported_objects[i]
    parts.write_string(kind)
    parts.write_string(": ")
    parts.write_string(label)
    i += 1
  }
  parts.write_char(']')
  parts.to_string()
}
