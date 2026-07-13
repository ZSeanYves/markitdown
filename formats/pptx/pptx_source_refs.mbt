///|
fn pptx_notes_paragraph_is_page_number(
  slide : @pptxdoc.PptxSlide,
  text : String,
  source_key : @pptxdoc.PptxSourceKey,
) -> Bool {
  let trimmed = text.trim()
  let page = @string.parse_int(trimmed) catch { _ => return false }
  source_key.node_key.contains("shape-4") ||
  source_key.node_key.contains("shape-2") ||
  page == slide.slide_index
}

///|
fn hidden_slide_note_text(slide : @pptxdoc.PptxSlide) -> String? {
  if !slide.hidden {
    return None
  }
  match slide.notes {
    Some(notes) =>
      for para in notes.paragraphs {
        let text = pptx_plain_text_from_paragraph(para).trim().to_owned()
        if text != "" {
          return Some(text)
        }
      }
    None => ()
  }
  None
}

///|
fn pptx_note_hidden_slide_skipped(
  diagnostics : @core.Diagnostics,
  slide_index : Int,
) -> Unit {
  let warning = "hidden pptx slide skipped: Slide " + slide_index.to_string()
  if !diagnostics.warnings.contains(warning) {
    diagnostics.warnings.push(warning)
  }
  if !diagnostics.degraded_features.contains("pptx_hidden_slide_skipped") {
    diagnostics.degraded_features.push("pptx_hidden_slide_skipped")
  }
}

///|
fn pptx_append_document_warnings(
  blocks : Array[@core.CoreBlock],
  state : PptxState,
) -> Unit {
  if state.chart_fallback_emitted.val &&
    !state.diagnostics.degraded_features.contains("pptx_chart_cache_fallback") {
    state.diagnostics.degraded_features.push("pptx_chart_cache_fallback")
  }
  if state.presentation.warnings.length() == 0 {
    return
  }
  let heading = @core.make_block(
    @core.BlockKind::Heading,
    "PPTX Warnings",
    source_ref=@core.empty_source_ref(),
  )
  heading.attrs.set("level", "2")
  let warning_blocks : Array[@core.CoreBlock] = []
  for warning in state.presentation.warnings {
    if pptx_warning_already_represented_in_markdown(state, warning) {
      continue
    }
    let source_ref = match warning.source_span {
      Some(span) =>
        @core.source_ref_with_extra(
          pptx_root_source_ref(state.source),
          "slide_part",
          span.part_name,
        )
      None => pptx_root_source_ref(state.source)
    }
    let block = @core.make_block(
      @core.BlockKind::ListItem,
      warning.message,
      source_ref~,
    )
    block.attrs.set("ordered", "false")
    block.attrs.set("level", "0")
    warning_blocks.push(block)
  }
  if warning_blocks.length() == 0 {
    return
  }
  blocks.push(heading)
  for block in warning_blocks {
    blocks.push(block)
  }
}

///|
fn pptx_warning_already_represented_in_markdown(
  state : PptxState,
  warning : @pptxdoc.PptxWarning,
) -> Bool {
  if !pptx_feature_enabled(state, @product.AccurateFeature::PptxGroupSummary) {
    return false
  }
  if warning.kind != @pptxdoc.PptxWarningKind::UnsupportedObject {
    return false
  }
  let message = warning.message
  message.has_prefix("unsupported graphic frame:") ||
  message.has_prefix("unsupported slide object:")
}

///|
fn pptx_root_source_ref(source : @input.InputSource) -> @core.SourceRef {
  @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some(source.source_name),
    Some("pptx"),
    @input.input_path(source),
    None,
    None,
    Some("pptx"),
    None,
  )
}

///|
fn pptx_slide_source_ref(
  source : @input.InputSource,
  slide : @pptxdoc.PptxSlide,
  source_key : @pptxdoc.PptxSourceKey?,
  shape_id : String?,
) -> @core.SourceRef {
  let inner_path = match source_key {
    Some(key) => Some(key.node_key)
    None => Some(slide.source_key.node_key)
  }
  let entry_path = match source_key {
    Some(key) => Some(key.part_name)
    None => Some(slide.part_name)
  }
  let source_ref = @core.source_ref_with_office_fields(
    @core.source_ref_with_container_entry(
      @core.empty_source_ref(),
      Some(source.source_name),
      Some("pptx"),
      @input.input_path(source),
      entry_path,
      None,
      Some("pptx"),
      inner_path,
    ),
    Some(source.source_name),
    Some("pptx"),
    inner_path,
    None,
    None,
    Some(slide.slide_index),
    shape_id,
    slide.relationship_id,
  )
  let source_ref = @core.source_ref_with_extra(
    source_ref,
    "slide_index",
    slide.slide_index.to_string(),
  )
  let source_ref = match slide.slide_id {
    Some(slide_id) =>
      @core.source_ref_with_extra(source_ref, "slide_id", slide_id)
    None => source_ref
  }
  let source_ref = @core.source_ref_with_extra(
    source_ref,
    "slide_part",
    slide.part_name,
  )
  let source_ref = match slide.layout_ref {
    Some(layout) =>
      @core.source_ref_with_extra(source_ref, "layout_part", layout.part_name)
    None => source_ref
  }
  match slide.master_ref {
    Some(master) =>
      @core.source_ref_with_extra(source_ref, "master_part", master.part_name)
    None => source_ref
  }
}

///|
fn pptx_shape_source_ref(
  source : @input.InputSource,
  slide : @pptxdoc.PptxSlide,
  shape : @pptxdoc.PptxShape,
  source_key : @pptxdoc.PptxSourceKey?,
  include_reading_order_hint : Bool,
) -> @core.SourceRef {
  let base = pptx_slide_source_ref(source, slide, source_key, shape.shape_id)
  let base = match shape.name {
    Some(name) => @core.source_ref_with_extra(base, "shape_name", name)
    None => base
  }
  let base = match shape.shape_type {
    Some(shape_type) =>
      @core.source_ref_with_extra(base, "shape_type", shape_type)
    None => base
  }
  let base = match pptx_placeholder_kind_name(shape) {
    Some(kind) => @core.source_ref_with_extra(base, "placeholder_type", kind)
    None => base
  }
  let base = match pptx_placeholder_index(shape) {
    Some(index) => @core.source_ref_with_extra(base, "placeholder_idx", index)
    None => base
  }
  if !include_reading_order_hint {
    return base
  }
  match shape.reading_order {
    Some(order) =>
      @core.source_ref_with_extra(base, "reading_order_key", order.order_key)
    None => base
  }
}

///|
fn pptx_next_shape_top(
  slide : @pptxdoc.PptxSlide,
  shape : @pptxdoc.PptxShape,
) -> Int? {
  let current_top = match shape_geometry_top(shape) {
    Some(value) => value
    None => return None
  }
  let mut next_top : Int? = None
  for obj in slide.objects {
    match obj {
      @pptxdoc.PptxObject::Shape(other) =>
        if other.shape_id != shape.shape_id {
          match shape_geometry_top(other) {
            Some(top) =>
              if top > current_top {
                match next_top {
                  Some(current) => if top < current { next_top = Some(top) }
                  None => next_top = Some(top)
                }
              }
            None => ()
          }
        }
      _ => ()
    }
  }
  next_top
}

///|
fn shape_geometry_top(shape : @pptxdoc.PptxShape) -> Int? {
  match shape.geometry {
    Some(geo) => geo.y
    None => None
  }
}

///|
fn pptx_picture_source_ref(
  source : @input.InputSource,
  slide : @pptxdoc.PptxSlide,
  pic : @pptxdoc.PptxPicture,
  include_reading_order_hint : Bool,
) -> @core.SourceRef {
  let base = pptx_slide_source_ref(
    source,
    slide,
    Some(pic.source_key),
    pic.shape_id,
  )
  let base = match pic.name {
    Some(name) => @core.source_ref_with_extra(base, "shape_name", name)
    None => base
  }
  let base = @core.source_ref_with_extra(base, "shape_type", "picture")
  if !include_reading_order_hint {
    return base
  }
  match pic.reading_order {
    Some(order) =>
      @core.source_ref_with_extra(base, "reading_order_key", order.order_key)
    None => base
  }
}

///|
fn pptx_group_source_ref(
  source : @input.InputSource,
  slide : @pptxdoc.PptxSlide,
  group : @pptxdoc.PptxGroupShape,
  include_reading_order_hint : Bool,
) -> @core.SourceRef {
  let base = pptx_slide_source_ref(
    source,
    slide,
    Some(group.source_key),
    group.shape_id,
  )
  let base = match group.name {
    Some(name) => @core.source_ref_with_extra(base, "shape_name", name)
    None => base
  }
  let base = @core.source_ref_with_extra(base, "shape_type", "group")
  let base = @core.source_ref_with_extra(
    base,
    "group_child_count",
    group.children.length().to_string(),
  )
  if !include_reading_order_hint {
    return base
  }
  match group.reading_order {
    Some(order) =>
      @core.source_ref_with_extra(base, "reading_order_key", order.order_key)
    None => base
  }
}

///|
fn pptx_table_source_ref(
  source : @input.InputSource,
  slide : @pptxdoc.PptxSlide,
  table : @pptxdoc.PptxTable,
  include_reading_order_hint : Bool,
) -> @core.SourceRef {
  let base = @core.source_ref_with_extra(
    pptx_slide_source_ref(source, slide, Some(table.source_key), None),
    "shape_type",
    "table",
  )
  if !include_reading_order_hint {
    return base
  }
  match pptx_slide_reading_order_key(slide, table.source_key) {
    Some(order_key) =>
      @core.source_ref_with_extra(base, "reading_order_key", order_key)
    None => base
  }
}

///|
fn pptx_placeholder_kind_name(shape : @pptxdoc.PptxShape) -> String? {
  match shape.placeholder {
    Some(ph) => Some(pptx_placeholder_kind_to_string(ph.kind))
    None =>
      match shape.direct_placeholder {
        Some(ph) => Some(pptx_placeholder_kind_to_string(ph.kind))
        None => None
      }
  }
}

///|
fn pptx_placeholder_index(shape : @pptxdoc.PptxShape) -> String? {
  match shape.placeholder {
    Some(ph) => ph.index
    None =>
      match shape.direct_placeholder {
        Some(ph) => ph.index
        None => None
      }
  }
}

///|
fn pptx_placeholder_kind_to_string(
  kind : @pptxdoc.PptxPlaceholderKind,
) -> String {
  match kind {
    @pptxdoc.PptxPlaceholderKind::Title => "title"
    @pptxdoc.PptxPlaceholderKind::CenterTitle => "center_title"
    @pptxdoc.PptxPlaceholderKind::Subtitle => "subtitle"
    @pptxdoc.PptxPlaceholderKind::Body => "body"
    @pptxdoc.PptxPlaceholderKind::Footer => "footer"
    @pptxdoc.PptxPlaceholderKind::Date => "date"
    @pptxdoc.PptxPlaceholderKind::SlideNumber => "slide_number"
    @pptxdoc.PptxPlaceholderKind::Picture => "picture"
    @pptxdoc.PptxPlaceholderKind::Table => "table"
    @pptxdoc.PptxPlaceholderKind::Unknown => "unknown"
  }
}

///|
fn pptx_raw_placeholder_block(
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  source_key : @pptxdoc.PptxSourceKey?,
  relationship_id : String?,
  text : String,
  raw_kind : String,
) -> @core.CoreBlock {
  let source_ref0 = pptx_slide_source_ref(state.source, slide, source_key, None)
  let source_ref0 = if pptx_include_block_reading_order_hint(state) {
    match source_key {
      Some(key) =>
        match pptx_slide_reading_order_key(slide, key) {
          Some(order_key) =>
            @core.source_ref_with_extra(
              source_ref0, "reading_order_key", order_key,
            )
          None => source_ref0
        }
      None => source_ref0
    }
  } else {
    source_ref0
  }
  let source_ref = match relationship_id {
    Some(rid) =>
      @core.source_ref_with_extra(source_ref0, "relationship_id", rid)
    None => source_ref0
  }
  let raw = @core.make_block(@core.BlockKind::Raw, text, source_ref~)
  raw.attrs.set("raw_kind", raw_kind)
  raw
}

///|
fn pptx_opt_suffix(value : String?) -> String {
  match value {
    Some(text) => ": " + text
    None => ""
  }
}

///|
fn pptx_include_block_reading_order_hint(state : PptxState) -> Bool {
  pptx_feature_enabled(state, @product.AccurateFeature::PptxReadingOrder)
}

///|
fn pptx_slide_reading_order_key(
  slide : @pptxdoc.PptxSlide,
  source_key : @pptxdoc.PptxSourceKey,
) -> String? {
  for obj in slide.objects {
    match pptx_object_reading_order_key(obj, source_key) {
      Some(order_key) => return Some(order_key)
      None => ()
    }
  }
  None
}

///|
fn pptx_object_reading_order_key(
  obj : @pptxdoc.PptxObject,
  source_key : @pptxdoc.PptxSourceKey,
) -> String? {
  match obj {
    @pptxdoc.PptxObject::Shape(shape) =>
      if pptx_source_keys_match(shape.source_key, source_key) {
        match shape.reading_order {
          Some(order) => Some(order.order_key)
          None => None
        }
      } else {
        None
      }
    @pptxdoc.PptxObject::Group(group) =>
      if pptx_source_keys_match(group.source_key, source_key) {
        match group.reading_order {
          Some(order) => Some(order.order_key)
          None => None
        }
      } else {
        for child in group.children {
          match pptx_object_reading_order_key(child, source_key) {
            Some(order_key) => return Some(order_key)
            None => ()
          }
        }
        None
      }
    @pptxdoc.PptxObject::Picture(pic) =>
      if pptx_source_keys_match(pic.source_key, source_key) {
        match pic.reading_order {
          Some(order) => Some(order.order_key)
          None => None
        }
      } else {
        None
      }
    @pptxdoc.PptxObject::Table(table) =>
      if pptx_source_keys_match(table.source_key, source_key) {
        Some("950:999999999:999999999:" + table.source_key.node_key)
      } else {
        None
      }
    @pptxdoc.PptxObject::Chart(chart) =>
      if pptx_source_keys_match(chart.source_key, source_key) {
        Some("950:999999999:999999999:" + chart.source_key.node_key)
      } else {
        None
      }
    @pptxdoc.PptxObject::SmartArt(smart) =>
      if pptx_source_keys_match(smart.source_key, source_key) {
        Some("950:999999999:999999999:" + smart.source_key.node_key)
      } else {
        None
      }
    @pptxdoc.PptxObject::Ole(ole) =>
      if pptx_source_keys_match(ole.source_key, source_key) {
        Some("950:999999999:999999999:" + ole.source_key.node_key)
      } else {
        None
      }
    @pptxdoc.PptxObject::Connector(conn) =>
      if pptx_source_keys_match(conn.source_key, source_key) {
        Some("950:999999999:999999999:" + conn.source_key.node_key)
      } else {
        None
      }
    @pptxdoc.PptxObject::Unsupported(unsupported) =>
      if pptx_source_keys_match(unsupported.source_key, source_key) {
        Some("950:999999999:999999999:" + unsupported.source_key.node_key)
      } else {
        None
      }
  }
}

///|
fn pptx_source_keys_match(
  left : @pptxdoc.PptxSourceKey,
  right : @pptxdoc.PptxSourceKey,
) -> Bool {
  left.part_name == right.part_name && left.node_key == right.node_key
}
