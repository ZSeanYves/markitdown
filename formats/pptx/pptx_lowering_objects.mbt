///|
fn pptx_lower_object(
  blocks : Array[@core.CoreBlock],
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  obj : @pptxdoc.PptxObject,
) -> Unit {
  match obj {
    @pptxdoc.PptxObject::Shape(shape) =>
      pptx_lower_shape(blocks, state, slide, shape)
    @pptxdoc.PptxObject::Group(group) =>
      if pptx_should_emit_group_summary(state, group) {
        pptx_lower_group_summary(blocks, state, slide, group)
      } else {
        for child in pptx_group_children_for_lowering(state, group) {
          pptx_lower_object(blocks, state, slide, child)
        }
      }
    @pptxdoc.PptxObject::Picture(pic) =>
      pptx_lower_picture(blocks, state, slide, pic)
    @pptxdoc.PptxObject::Table(table) =>
      match pptx_table_block(state, slide, table) {
        Some(block) => blocks.push(block)
        None => ()
      }
    @pptxdoc.PptxObject::Chart(chart) =>
      pptx_lower_chart(blocks, state, slide, chart)
    @pptxdoc.PptxObject::SmartArt(smart) =>
      blocks.push(
        pptx_raw_placeholder_block(
          state,
          slide,
          Some(smart.source_key),
          smart.relationship_id,
          "[Unsupported PPTX SmartArt" +
          pptx_opt_suffix(smart.target_part) +
          "]",
          "pptx_smartart_unsupported",
        ),
      )
    @pptxdoc.PptxObject::Ole(ole) =>
      blocks.push(
        pptx_raw_placeholder_block(
          state,
          slide,
          Some(ole.source_key),
          ole.relationship_id,
          "[Unsupported PPTX OLE object" +
          pptx_opt_suffix(ole.target_part) +
          "]",
          "pptx_ole_unsupported",
        ),
      )
    @pptxdoc.PptxObject::Connector(conn) =>
      blocks.push(
        pptx_raw_placeholder_block(
          state,
          slide,
          Some(conn.source_key),
          None,
          "[PPTX connector omitted" + pptx_opt_suffix(conn.name) + "]",
          "pptx_connector_omitted",
        ),
      )
    @pptxdoc.PptxObject::Unsupported(unsupported) =>
      blocks.push(
        pptx_raw_placeholder_block(
          state,
          slide,
          Some(unsupported.source_key),
          None,
          "[Unsupported PPTX object: " + unsupported.kind + "]",
          "pptx_object_unsupported",
        ),
      )
  }
}

///|
fn pptx_objects_for_slide(
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
) -> Array[@pptxdoc.PptxObject] {
  if !pptx_feature_enabled(state, @product.AccurateFeature::PptxReadingOrder) {
    return slide.objects
  }
  let ordered : Array[@pptxdoc.PptxObject] = []
  let used : Array[Int] = []
  for key in slide.reading_order {
    match pptx_find_object_index_by_source_key(slide.objects, key) {
      Some(index) =>
        if !used.contains(index) {
          ordered.push(slide.objects[index])
          used.push(index)
        }
      None => ()
    }
  }
  if ordered.length() == 0 {
    return slide.objects
  }
  for i in 0..<slide.objects.length() {
    if !used.contains(i) {
      ordered.push(slide.objects[i])
    }
  }
  ordered
}

///|
fn pptx_group_children_for_lowering(
  state : PptxState,
  group : @pptxdoc.PptxGroupShape,
) -> Array[@pptxdoc.PptxObject] {
  if !pptx_feature_enabled(state, @product.AccurateFeature::PptxReadingOrder) {
    return group.children
  }
  let keyed : Array[(String, @pptxdoc.PptxObject)] = []
  let mut fallback_order = 0
  for child in group.children {
    let order_key = match pptx_object_lowering_order_key(child) {
      Some(value) => value
      None => {
        fallback_order += 1
        "999:999999999:999999999:" +
        fallback_order.to_string() +
        ":" +
        pptx_object_source_key(child).node_key
      }
    }
    keyed.push((order_key, child))
  }
  keyed.sort_by(fn(a, b) { a.0.compare(b.0) })
  let ordered : Array[@pptxdoc.PptxObject] = []
  for item in keyed {
    ordered.push(item.1)
  }
  ordered
}

///|
fn pptx_should_emit_group_summary(
  state : PptxState,
  group : @pptxdoc.PptxGroupShape,
) -> Bool {
  if !pptx_feature_enabled(state, @product.AccurateFeature::PptxGroupSummary) {
    return false
  }
  if group.children.length() == 0 {
    return false
  }
  for child in group.children {
    if !pptx_group_child_is_summary_safe(child) {
      return false
    }
  }
  true
}

///|
fn pptx_group_child_is_summary_safe(obj : @pptxdoc.PptxObject) -> Bool {
  match obj {
    @pptxdoc.PptxObject::Shape(shape) =>
      shape.text_body is None && pptx_is_decorative_shape(shape)
    @pptxdoc.PptxObject::Group(group) => pptx_group_is_summary_safe(group)
    _ => false
  }
}

///|
fn pptx_group_is_summary_safe(group : @pptxdoc.PptxGroupShape) -> Bool {
  if group.children.length() == 0 {
    return false
  }
  for child in group.children {
    if !pptx_group_child_is_summary_safe(child) {
      return false
    }
  }
  true
}

///|
fn pptx_lower_group_summary(
  blocks : Array[@core.CoreBlock],
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  group : @pptxdoc.PptxGroupShape,
) -> Unit {
  let source_ref = pptx_group_source_ref(
    state.source,
    slide,
    group,
    pptx_include_block_reading_order_hint(state),
  )
  let summary_text = pptx_group_summary_text(group)
  let raw = @core.make_block(@core.BlockKind::Raw, summary_text, source_ref~)
  raw.attrs.set("raw_kind", "pptx_group_shape_summary")
  blocks.push(raw)
}

///|
fn pptx_group_summary_text(group : @pptxdoc.PptxGroupShape) -> String {
  let parts = StringBuilder::new()
  parts.write_string("[PPTX grouped decorative shapes")
  match group.name {
    Some(name) =>
      if name.trim() != "" {
        parts.write_string(": ")
        parts.write_string(name)
      }
    None => ()
  }
  parts.write_string(" | children=")
  parts.write_string(group.children.length().to_string())
  parts.write_string(" | ")
  let labels = pptx_group_summary_labels(group)
  let mut i = 0
  while i < labels.length() {
    if i > 0 {
      parts.write_string("; ")
    }
    parts.write_string(labels[i])
    i += 1
  }
  parts.write_char(']')
  parts.to_string()
}

///|
fn pptx_group_summary_labels(group : @pptxdoc.PptxGroupShape) -> Array[String] {
  let out : Array[String] = []
  for child in pptx_group_children_for_summary(group) {
    match child {
      @pptxdoc.PptxObject::Shape(shape) =>
        out.push(pptx_shape_summary_label(shape))
      @pptxdoc.PptxObject::Group(inner) =>
        out.push(
          "group(" +
          inner.children.length().to_string() +
          "): " +
          pptx_group_summary_text(inner),
        )
      _ => ()
    }
  }
  out
}

///|
fn pptx_group_children_for_summary(
  group : @pptxdoc.PptxGroupShape,
) -> Array[@pptxdoc.PptxObject] {
  let keyed : Array[(String, @pptxdoc.PptxObject)] = []
  let mut fallback_order = 0
  for child in group.children {
    let order_key = match pptx_object_lowering_order_key(child) {
      Some(value) => value
      None => {
        fallback_order += 1
        "999:999999999:999999999:" +
        fallback_order.to_string() +
        ":" +
        pptx_object_source_key(child).node_key
      }
    }
    keyed.push((order_key, child))
  }
  keyed.sort_by(fn(a, b) { a.0.compare(b.0) })
  let ordered : Array[@pptxdoc.PptxObject] = []
  for item in keyed {
    ordered.push(item.1)
  }
  ordered
}

///|
fn pptx_shape_summary_label(shape : @pptxdoc.PptxShape) -> String {
  let shape_type = shape.shape_type.unwrap_or("shape")
  match shape.name {
    Some(name) =>
      if name.trim() != "" {
        shape_type + ": " + name
      } else {
        shape_type
      }
    None => shape_type
  }
}

///|
fn pptx_connector_summary_label(conn : @pptxdoc.PptxConnector) -> String {
  match conn.name {
    Some(name) => if name.trim() != "" { name } else { "connector" }
    None => "connector"
  }
}

///|
fn pptx_smartart_summary_label(smart : @pptxdoc.PptxSmartArtRef) -> String {
  smart.target_part.unwrap_or("smartart")
}

///|
fn pptx_ole_summary_label(ole : @pptxdoc.PptxOleRef) -> String {
  ole.target_part.unwrap_or("ole")
}

///|
fn pptx_unsupported_summary_label(
  unsupported : @pptxdoc.PptxUnsupported,
) -> String {
  if unsupported.message.trim() != "" {
    unsupported.kind + " (" + unsupported.message + ")"
  } else {
    unsupported.kind
  }
}

///|
fn pptx_find_object_index_by_source_key(
  objects : Array[@pptxdoc.PptxObject],
  key : @pptxdoc.PptxSourceKey,
) -> Int? {
  for i in 0..<objects.length() {
    if pptx_source_keys_match_local(pptx_object_source_key(objects[i]), key) {
      return Some(i)
    }
  }
  None
}

///|
fn pptx_object_source_key(obj : @pptxdoc.PptxObject) -> @pptxdoc.PptxSourceKey {
  match obj {
    @pptxdoc.PptxObject::Shape(shape) => shape.source_key
    @pptxdoc.PptxObject::Group(group) => group.source_key
    @pptxdoc.PptxObject::Picture(pic) => pic.source_key
    @pptxdoc.PptxObject::Table(table) => table.source_key
    @pptxdoc.PptxObject::Chart(chart) => chart.source_key
    @pptxdoc.PptxObject::SmartArt(smart) => smart.source_key
    @pptxdoc.PptxObject::Ole(ole) => ole.source_key
    @pptxdoc.PptxObject::Connector(conn) => conn.source_key
    @pptxdoc.PptxObject::Unsupported(unsupported) => unsupported.source_key
  }
}

///|
fn pptx_object_lowering_order_key(obj : @pptxdoc.PptxObject) -> String? {
  match obj {
    @pptxdoc.PptxObject::Shape(shape) =>
      match shape.reading_order {
        Some(order) => Some(order.order_key)
        None => None
      }
    @pptxdoc.PptxObject::Group(group) =>
      match group.reading_order {
        Some(order) => Some(order.order_key)
        None => None
      }
    @pptxdoc.PptxObject::Picture(pic) =>
      match pic.reading_order {
        Some(order) => Some(order.order_key)
        None => None
      }
    @pptxdoc.PptxObject::Table(table) =>
      Some("950:999999999:999999999:" + table.source_key.node_key)
    @pptxdoc.PptxObject::Chart(chart) =>
      Some("950:999999999:999999999:" + chart.source_key.node_key)
    @pptxdoc.PptxObject::SmartArt(smart) =>
      Some("950:999999999:999999999:" + smart.source_key.node_key)
    @pptxdoc.PptxObject::Ole(ole) =>
      Some("950:999999999:999999999:" + ole.source_key.node_key)
    @pptxdoc.PptxObject::Connector(conn) =>
      Some("950:999999999:999999999:" + conn.source_key.node_key)
    @pptxdoc.PptxObject::Unsupported(unsupported) =>
      Some("950:999999999:999999999:" + unsupported.source_key.node_key)
  }
}

///|
fn pptx_source_keys_match_local(
  left : @pptxdoc.PptxSourceKey,
  right : @pptxdoc.PptxSourceKey,
) -> Bool {
  left.part_name == right.part_name && left.node_key == right.node_key
}

///|
fn pptx_lower_shape(
  blocks : Array[@core.CoreBlock],
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  shape : @pptxdoc.PptxShape,
) -> Unit {
  match shape.text_body {
    Some(body) => {
      let mut paragraph_index = 0
      let list_stack : Array[PptxListTree] = []
      let is_heading_shape = pptx_shape_is_heading(slide, shape)
      for para in body.paragraphs {
        let rich = pptx_paragraph_inlines(state, slide, shape, para)
        let text = pptx_plain_text(rich)
        if text.trim() == "" {
          paragraph_index += 1
          continue
        }
        let source_ref = pptx_shape_source_ref(
          state.source,
          slide,
          shape,
          Some(para.source_key),
          pptx_include_block_reading_order_hint(state),
        )
        let trust_placeholder_heading = pptx_shape_has_explicit_heading_placeholder(
          shape,
        )
        let use_heading_block = is_heading_shape &&
          (trust_placeholder_heading || !pptx_nonsemantic_heading_text(text)) &&
          pptx_shape_should_emit_heading_paragraph(shape, paragraph_index)
        let block = match para.list_hint {
          Some(list_hint) => {
            let item0 = @core.make_block(
              @core.BlockKind::ListItem,
              pptx_list_item_text(text),
              source_ref~,
            )
            let item = if rich.length() > 0 {
              @core.block_with_rich_inlines(item0, Some(rich))
            } else {
              item0
            }
            match list_hint.bullet {
              Some(@pptxdoc.PptxBulletKind::Ordered) => {
                item.attrs.set("ordered", "true")
                item.attrs.set("stable_ordered_marker", "true")
              }
              _ => item.attrs.set("ordered", "false")
            }
            item.attrs.set("level", list_hint.level.to_string())
            item
          }
          None =>
            if use_heading_block {
              let heading0 = @core.make_block(
                @core.BlockKind::Heading,
                text.trim().to_owned(),
                source_ref~,
              )
              let heading = if rich.length() > 0 {
                @core.block_with_rich_inlines(heading0, Some(rich))
              } else {
                heading0
              }
              heading.attrs.set("level", "3")
              heading
            } else {
              let paragraph0 = @core.make_block(
                @core.BlockKind::Paragraph,
                text,
                source_ref~,
              )
              if rich.length() > 0 {
                @core.block_with_rich_inlines(paragraph0, Some(rich))
              } else {
                paragraph0
              }
            }
        }
        if block.kind == @core.BlockKind::ListItem {
          pptx_push_list_item(blocks, list_stack, block)
        } else {
          pptx_flush_lists(blocks, list_stack, 0)
          blocks.push(block)
        }
        paragraph_index += 1
      }
      pptx_flush_lists(blocks, list_stack, 0)
    }
    None =>
      if pptx_is_decorative_shape(shape) {
        let raw = pptx_raw_placeholder_block(
          state,
          slide,
          Some(shape.source_key),
          None,
          "[PPTX decorative shape omitted" + pptx_opt_suffix(shape.name) + "]",
          "pptx_decorative_shape_omitted",
        )
        blocks.push(raw)
      }
  }
}

///|
fn pptx_shape_is_heading(
  slide : @pptxdoc.PptxSlide,
  shape : @pptxdoc.PptxShape,
) -> Bool {
  match shape.placeholder {
    Some(ph) =>
      ph.kind == @pptxdoc.PptxPlaceholderKind::Title ||
      ph.kind == @pptxdoc.PptxPlaceholderKind::CenterTitle ||
      ph.kind == @pptxdoc.PptxPlaceholderKind::Subtitle
    None =>
      match shape.direct_placeholder {
        Some(ph) =>
          ph.kind == @pptxdoc.PptxPlaceholderKind::Title ||
          ph.kind == @pptxdoc.PptxPlaceholderKind::CenterTitle ||
          ph.kind == @pptxdoc.PptxPlaceholderKind::Subtitle
        None => pptx_shape_is_heading_fallback(slide, shape)
      }
  }
}

///|
fn pptx_shape_should_emit_heading_paragraph(
  shape : @pptxdoc.PptxShape,
  paragraph_index : Int,
) -> Bool {
  match shape.placeholder {
    Some(ph) =>
      ph.kind == @pptxdoc.PptxPlaceholderKind::CenterTitle ||
      paragraph_index == 0
    None =>
      match shape.direct_placeholder {
        Some(ph) =>
          ph.kind == @pptxdoc.PptxPlaceholderKind::CenterTitle ||
          paragraph_index == 0
        None => paragraph_index == 0
      }
  }
}

///|
fn pptx_shape_has_explicit_heading_placeholder(
  shape : @pptxdoc.PptxShape,
) -> Bool {
  match shape.direct_placeholder {
    Some(ph) =>
      ph.kind == @pptxdoc.PptxPlaceholderKind::Title ||
      ph.kind == @pptxdoc.PptxPlaceholderKind::CenterTitle ||
      ph.kind == @pptxdoc.PptxPlaceholderKind::Subtitle
    None => false
  }
}

///|
fn pptx_shape_is_heading_fallback(
  slide : @pptxdoc.PptxSlide,
  shape : @pptxdoc.PptxShape,
) -> Bool {
  match shape.reading_order {
    Some(order) =>
      if order.bucket != @pptxdoc.PptxReadingBucket::Title &&
        order.bucket != @pptxdoc.PptxReadingBucket::Subtitle {
        return false
      }
    None => return false
  }
  let text_body = match shape.text_body {
    Some(body) => body
    None => return false
  }
  if text_body.paragraphs.length() == 0 {
    return false
  }
  if pptx_slide_has_single_text_shape(slide, shape) {
    return true
  }
  let first = shape_geometry_top(shape).unwrap_or(0)
  let second = pptx_next_shape_top(slide, shape)
  match second {
    Some(next_top) => first < next_top
    None => true
  }
}

///|
fn pptx_nonsemantic_heading_text(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return true
  }
  let lower = trimmed.to_lower()
  if pptx_generic_shape_sample_label(lower) {
    return true
  }
  lower == "title" ||
  lower == "subtitle" ||
  lower == "heading" ||
  lower.has_prefix("title ") ||
  lower.has_prefix("subtitle ") ||
  lower.has_prefix("heading ")
}

///|
fn pptx_generic_shape_sample_label(lower : String) -> Bool {
  pptx_bracketed_shape_sample_label(lower) ||
  lower.has_prefix("shape ") ||
  lower.has_prefix("shapes ") ||
  lower.has_prefix("textbox ")
}

///|
fn pptx_bracketed_shape_sample_label(lower : String) -> Bool {
  if lower.length() < 8 {
    return false
  }
  if !(lower.has_prefix("shape[") || lower.has_prefix("shapes[")) {
    return false
  }
  lower.has_suffix("]")
}

///|
fn pptx_slide_has_single_text_shape(
  slide : @pptxdoc.PptxSlide,
  target : @pptxdoc.PptxShape,
) -> Bool {
  let mut count = 0
  for obj in slide.objects {
    match obj {
      @pptxdoc.PptxObject::Shape(shape) =>
        match shape.text_body {
          Some(body) =>
            if body.paragraphs.length() > 0 {
              count += 1
              if shape.source_key.part_name == target.source_key.part_name &&
                shape.source_key.node_key == target.source_key.node_key {
                ()
              }
            }
          None => ()
        }
      _ => ()
    }
  }
  count == 1
}

///|
fn pptx_is_decorative_shape(shape : @pptxdoc.PptxShape) -> Bool {
  match shape.reading_order {
    Some(hint) => hint.bucket == @pptxdoc.PptxReadingBucket::Decorative
    None => shape.text_body is None
  }
}

///|
fn pptx_paragraph_inlines(
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  shape : @pptxdoc.PptxShape,
  para : @pptxdoc.PptxParagraph,
) -> Array[@core.CoreInline] {
  let out : Array[@core.CoreInline] = []
  for run in para.runs {
    let run_ref = pptx_shape_source_ref(
      state.source,
      slide,
      shape,
      Some(run.source_key),
      pptx_include_block_reading_order_hint(state),
    )
    for inline in run.inlines {
      match inline {
        @pptxdoc.PptxInline::Text(text) =>
          out.push(
            @core.make_inline_text(
              pptx_normalize_text_fragment(text),
              source_ref=run_ref,
            ),
          )
        @pptxdoc.PptxInline::Break =>
          out.push(@core.make_inline_line_break(source_ref=run_ref))
        @pptxdoc.PptxInline::Field(text) =>
          out.push(
            @core.make_inline_text(
              pptx_normalize_text_fragment(text),
              source_ref=run_ref,
            ),
          )
        @pptxdoc.PptxInline::Hyperlink(link, text) =>
          match link.target {
            Some(target) =>
              out.push(
                @core.make_inline_link(
                  pptx_normalize_text_fragment(text),
                  target,
                  source_ref=@core.source_ref_with_extra(
                    run_ref,
                    "hyperlink_target_mode",
                    if link.is_external {
                      "external"
                    } else {
                      "internal"
                    },
                  ),
                ),
              )
            None =>
              out.push(
                @core.make_inline_text(
                  pptx_normalize_text_fragment(text),
                  source_ref=run_ref,
                ),
              )
          }
        @pptxdoc.PptxInline::Unsupported(unsupported) =>
          out.push(
            @core.make_inline_text(
              "[Unsupported PPTX inline: " + unsupported.kind + "]",
              source_ref=run_ref,
            ),
          )
      }
    }
  }
  pptx_compact_text_inlines(out)
}

///|
fn pptx_plain_text(inlines : Array[@core.CoreInline]) -> String {
  let mut out = ""
  for inline in inlines {
    match inline.kind {
      @core.InlineKind::Text => out = out + inline.text
      @core.InlineKind::LineBreak => out = out + "\n"
      @core.InlineKind::Link => out = out + inline.text
      _ => ()
    }
  }
  out
}

///|
fn pptx_normalize_text_fragment(text : String) -> String {
  let out = StringBuilder::new()
  let mut leading_space = false
  let mut pending_space = false
  let mut wrote_text = false
  for ch in text.to_array() {
    if ch == '\t' || ch == ' ' {
      if wrote_text {
        pending_space = true
      } else {
        leading_space = true
      }
    } else {
      if leading_space {
        out.write_char(' ')
        leading_space = false
      }
      if pending_space && wrote_text {
        out.write_char(' ')
      }
      out.write_char(ch)
      wrote_text = true
      pending_space = false
    }
  }
  if pending_space && wrote_text {
    out.write_char(' ')
  }
  out.to_string()
}

///|
fn pptx_compact_text_inlines(
  inlines : Array[@core.CoreInline],
) -> Array[@core.CoreInline] {
  let out : Array[@core.CoreInline] = []
  for inline in inlines {
    if inline.kind != @core.InlineKind::Text {
      out.push(inline)
      continue
    }
    let text = inline.text
    if text == "" {
      continue
    }
    match out.last() {
      Some(prev) =>
        if prev.kind == @core.InlineKind::Text {
          let merged = pptx_merge_text_fragments(prev.text, text)
          ignore(out.pop())
          out.push({
            kind: @core.InlineKind::Text,
            text: merged,
            href: None,
            title: None,
            attrs: prev.attrs,
            source_ref: prev.source_ref,
          })
        } else {
          out.push(inline)
        }
      None => out.push(inline)
    }
  }
  out
}

///|
fn pptx_merge_text_fragments(left : String, right : String) -> String {
  if left == "" {
    return right
  }
  if right == "" {
    return left
  }
  if pptx_leading_space(right) {
    return left.trim_end().to_owned() + " " + right.trim_start().to_owned()
  }
  left + right
}

///|
fn pptx_leading_space(text : String) -> Bool {
  let chars = text.to_array()
  if chars.length() == 0 {
    return false
  }
  let ch = chars[0]
  ch == ' ' || ch == '\t'
}

///|
fn pptx_list_item_text(text : String) -> String {
  text
  .replace(old="\r\n", new="\n")
  .replace(old="\r", new="\n")
  .split("\n")
  .map(fn(value) { value.trim().to_owned() })
  .filter(fn(value) { value != "" })
  .iter()
  .collect()
  .join("<br>")
}

///|
fn pptx_flush_lists(
  out : Array[@core.CoreBlock],
  list_stack : Array[PptxListTree],
  min_depth : Int,
) -> Unit {
  while list_stack.length() > min_depth {
    let current = list_stack.pop().unwrap()
    let list_block = @core.make_block(
      @core.BlockKind::List,
      "",
      source_ref=current.items[0].source_ref.unwrap_or(@core.empty_source_ref()),
    )
    list_block.attrs.set("ordered", @fshared.bool_string(current.ordered))
    list_block.children.append(current.items[:])
    match list_stack.last() {
      Some(parent) =>
        parent.items[parent.items.length() - 1].children.push(list_block)
      None => out.push(list_block)
    }
  }
}

///|
fn pptx_push_list_item(
  out : Array[@core.CoreBlock],
  list_stack : Array[PptxListTree],
  item : @core.CoreBlock,
) -> Unit {
  let ordered = item.attrs.get("ordered").unwrap_or("false") == "true"
  let level = @string.parse_int(item.attrs.get("level").unwrap_or("0")) catch {
    _ => 0
  }
  let target_depth = level + 1
  pptx_flush_lists(out, list_stack, target_depth)
  if list_stack.length() == target_depth &&
    target_depth > 0 &&
    list_stack[target_depth - 1].ordered != ordered {
    pptx_flush_lists(out, list_stack, target_depth - 1)
  }
  while list_stack.length() < target_depth {
    list_stack.push({ ordered, items: [] })
  }
  if list_stack.length() > 0 {
    list_stack[list_stack.length() - 1].items.push(item)
  }
}
