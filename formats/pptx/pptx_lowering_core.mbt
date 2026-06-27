///|
fn pptx_fill_package_metrics(
  diagnostics : @core.Diagnostics,
  pkg : @ox.OoxmlPackage,
  presentation : @pptxdoc.PptxDocument,
) -> Unit {
  let inventory = @ox.inspect_ooxml_inventory(pkg)
  let validation = @ox.validate_ooxml_package(pkg)
  let package_relationship_count = (@ox.read_package_relationships(pkg) catch {
    _ => []
  }).length()
  let part_relationship_count = inventory.relationship_source_parts.fold(
    init=0,
    fn(acc, source_part) {
      acc +
      (@ox.read_part_relationships(pkg, source_part) catch { _ => [] }).length()
    },
  )
  diagnostics.metrics.set("ooxml_part_count", inventory.part_count.to_string())
  diagnostics.metrics.set(
    "relationship_count",
    (package_relationship_count + part_relationship_count).to_string(),
  )
  let mut external_relationship_count = 0
  let mut missing_relationship_target_count = 0
  let mut unsupported_relationship_count = 0
  for issue in validation.issues {
    match issue.kind {
      @ox.OoxmlValidationIssueKind::ExternalRelationship =>
        external_relationship_count += 1
      @ox.OoxmlValidationIssueKind::MissingRelationshipTarget =>
        missing_relationship_target_count += 1
      @ox.OoxmlValidationIssueKind::UnsafeRelationshipTarget =>
        unsupported_relationship_count += 1
      _ => ()
    }
  }
  diagnostics.metrics.set(
    "external_relationship_count",
    external_relationship_count.to_string(),
  )
  diagnostics.metrics.set(
    "missing_relationship_target_count",
    missing_relationship_target_count.to_string(),
  )
  diagnostics.metrics.set(
    "unsupported_relationship_count",
    unsupported_relationship_count.to_string(),
  )
  diagnostics.metrics.set(
    "media_asset_count",
    count_pptx_media_parts(inventory.parts).to_string(),
  )
  diagnostics.metrics.set(
    "content_type_count",
    inventory.content_type_entry_count.to_string(),
  )
  let mut total_uncompressed_bytes = 0
  for part in inventory.parts {
    total_uncompressed_bytes += part.size
  }
  diagnostics.metrics.set(
    "total_uncompressed_bytes",
    total_uncompressed_bytes.to_string(),
  )

  let mut path_traversal_count = 0
  for issue in validation.issues {
    let message = issue.message.trim().to_owned().to_lower()
    if message.contains("path traversal") ||
      message.contains("unsafe relationship target") {
      path_traversal_count += 1
    }
  }
  diagnostics.metrics.set(
    "path_traversal_count",
    path_traversal_count.to_string(),
  )

  let mut duplicate_part_count = 0
  let mut prev_part = ""
  let sorted_part_names = inventory.parts.map(part => part.part_name)
  sorted_part_names.sort()
  for part_name in sorted_part_names {
    if part_name == prev_part {
      duplicate_part_count += 1
    }
    prev_part = part_name
  }
  diagnostics.metrics.set(
    "duplicate_part_count",
    duplicate_part_count.to_string(),
  )

  let mut macro_part_count = 0
  let mut ole_object_count = 0
  for part in inventory.parts {
    let content_type = part.content_type.unwrap_or("").to_lower()
    let part_name = part.part_name.to_lower()
    if content_type.contains("macroenabled") || part_name.has_suffix(".bin") {
      macro_part_count += 1
    }
    if content_type.contains("oleobject") || part_name.contains("/embeddings/") {
      ole_object_count += 1
    }
  }
  diagnostics.metrics.set("macro_part_count", macro_part_count.to_string())
  diagnostics.metrics.set("ole_object_count", ole_object_count.to_string())

  let inspect = @pptxdoc.inspect_pptx_document(presentation)
  diagnostics.metrics.set(
    "pptx_slide_count",
    presentation.slides.length().to_string(),
  )
  diagnostics.metrics.set(
    "pptx_layout_count",
    presentation.layouts.length().to_string(),
  )
  diagnostics.metrics.set(
    "pptx_master_count",
    presentation.masters.length().to_string(),
  )
  diagnostics.metrics.set(
    "pptx_theme_count",
    pptx_theme_count(presentation).to_string(),
  )
  diagnostics.metrics.set("pptx_shape_count", inspect.shape_count.to_string())
  diagnostics.metrics.set("pptx_table_count", inspect.table_count.to_string())
  diagnostics.metrics.set("pptx_notes_count", inspect.notes_count.to_string())
  diagnostics.metrics.set(
    "pptx_comment_count",
    inspect.comment_count.to_string(),
  )

  let placeholder_count : Ref[Int] = { val: 0 }
  let resolved_placeholder_count : Ref[Int] = { val: 0 }
  let unresolved_placeholder_count : Ref[Int] = { val: 0 }
  let text_box_count : Ref[Int] = { val: 0 }
  let image_count : Ref[Int] = { val: 0 }
  let external_media_count : Ref[Int] = { val: 0 }
  let mut visible_slide_count = 0
  let mut hidden_slide_count = 0
  for slide in presentation.slides {
    if slide.hidden {
      hidden_slide_count += 1
    } else {
      visible_slide_count += 1
    }
    for obj in slide.objects {
      pptx_accumulate_object_metrics(
        obj, diagnostics, placeholder_count, resolved_placeholder_count, unresolved_placeholder_count,
        text_box_count, image_count, external_media_count,
      )
    }
  }
  diagnostics.metrics.set(
    "pptx_visible_slide_count",
    visible_slide_count.to_string(),
  )
  diagnostics.metrics.set(
    "pptx_hidden_slide_count",
    hidden_slide_count.to_string(),
  )
  diagnostics.metrics.set(
    "pptx_placeholder_count",
    placeholder_count.val.to_string(),
  )
  diagnostics.metrics.set(
    "pptx_resolved_placeholder_count",
    resolved_placeholder_count.val.to_string(),
  )
  diagnostics.metrics.set(
    "pptx_unresolved_placeholder_count",
    unresolved_placeholder_count.val.to_string(),
  )
  diagnostics.metrics.set("pptx_text_box_count", text_box_count.val.to_string())
  diagnostics.metrics.set("pptx_image_count", image_count.val.to_string())
  diagnostics.metrics.set(
    "pptx_external_media_count",
    external_media_count.val.to_string(),
  )
}

///|
fn count_pptx_media_parts(parts : Array[@ox.OoxmlPartInfo]) -> Int {
  let mut count = 0
  for part in parts {
    if part.part_name.has_prefix("ppt/media/") &&
      !part.part_name.has_suffix("/") {
      count += 1
    }
  }
  count
}

///|
fn pptx_accumulate_object_metrics(
  obj : @pptxdoc.PptxObject,
  diagnostics : @core.Diagnostics,
  placeholder_count : Ref[Int],
  resolved_placeholder_count : Ref[Int],
  unresolved_placeholder_count : Ref[Int],
  text_box_count : Ref[Int],
  image_count : Ref[Int],
  external_media_count : Ref[Int],
) -> Unit {
  ignore(diagnostics)
  match obj {
    @pptxdoc.PptxObject::Shape(shape) => {
      match shape.direct_placeholder {
        Some(_) => placeholder_count.val += 1
        None => ()
      }
      match shape.placeholder {
        Some(_) => {
          resolved_placeholder_count.val += 1
          placeholder_count.val += 1
        }
        None =>
          if shape.text_body is Some(_) && shape.direct_placeholder is None {
            text_box_count.val += 1
          } else if shape.direct_placeholder is Some(_) {
            unresolved_placeholder_count.val += 1
          }
      }
    }
    @pptxdoc.PptxObject::Picture(pic) => {
      image_count.val += 1
      match pic.media {
        Some(media) => if media.is_external { external_media_count.val += 1 }
        None => ()
      }
    }
    @pptxdoc.PptxObject::Group(group) =>
      for child in group.children {
        pptx_accumulate_object_metrics(
          child, diagnostics, placeholder_count, resolved_placeholder_count, unresolved_placeholder_count,
          text_box_count, image_count, external_media_count,
        )
      }
    @pptxdoc.PptxObject::Ole(_) =>
      diagnostics.degraded_features.push("pptx_ole_unsupported")
    @pptxdoc.PptxObject::Chart(_) =>
      diagnostics.degraded_features.push("pptx_chart_unsupported")
    @pptxdoc.PptxObject::SmartArt(_) =>
      diagnostics.degraded_features.push("pptx_smartart_unsupported")
    _ => ()
  }
}

///|
fn pptx_theme_count(presentation : @pptxdoc.PptxDocument) -> Int {
  let themes : Array[String] = []
  for slide in presentation.slides {
    match slide.master_ref {
      Some(master) =>
        if !themes.contains(master.part_name) {
          themes.push(master.part_name)
        }
      None => ()
    }
  }
  themes.length()
}

///|
fn pptx_lower_document(
  source : @input.InputSource,
  presentation : @pptxdoc.PptxDocument,
  diagnostics : @core.Diagnostics,
) -> @core.DocumentIR {
  let document = @core.empty_document_ir()
  pptx_fill_metadata(document, source, presentation)
  let state = new_pptx_state(source, presentation, diagnostics)
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
) -> PptxState {
  {
    source,
    diagnostics,
    presentation,
    assets: [],
    asset_ids: Map([]),
    image_ids: Map([]),
    slide_image_counts: Map([]),
    chart_fallback_emitted: { val: false },
  }
}

///|
fn pptx_fill_metadata(
  document : @core.DocumentIR,
  source : @input.InputSource,
  presentation : @pptxdoc.PptxDocument,
) -> Unit {
  document.metadata.set(
    "source_name",
    @core.JsonValue::String(source.source_name),
  )
  document.metadata.set("format", @core.JsonValue::String("pptx"))
  document.metadata.set(
    "presentation_part",
    @core.JsonValue::String(presentation.presentation.part_name),
  )
  document.metadata.set(
    "slide_count",
    @core.JsonValue::Number(presentation.slides.length().to_string()),
  )
  document.metadata.set(
    "layout_count",
    @core.JsonValue::Number(presentation.layouts.length().to_string()),
  )
  document.metadata.set(
    "master_count",
    @core.JsonValue::Number(presentation.masters.length().to_string()),
  )
  match presentation.metadata.title {
    Some(title) =>
      document.metadata.set("title", @core.JsonValue::String(title))
    None => ()
  }
  match presentation.metadata.creator {
    Some(author) =>
      document.metadata.set("creator", @core.JsonValue::String(author))
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
    @core.BlockKind::Heading,
    "Slide " + slide.slide_index.to_string(),
    source_ref=pptx_slide_source_ref(state.source, slide, None, None),
  )
  slide_heading.attrs.set("level", "2")
  blocks.push(slide_heading)

  let block_count_before = blocks.length()
  for obj in slide.objects {
    pptx_lower_object(blocks, state, slide, obj)
  }
  pptx_lower_slide_comments(blocks, state, slide)
  pptx_lower_slide_notes(blocks, state, slide)
  if blocks.length() == block_count_before {
    blocks.push(
      @core.make_block(
        @core.BlockKind::Paragraph,
        "(empty)",
        source_ref=pptx_slide_source_ref(state.source, slide, None, None),
      ),
    )
  }
}

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
      for child in group.children {
        pptx_lower_object(blocks, state, slide, child)
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
        )
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
            if is_heading_shape && paragraph_index == 0 {
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
    list_block.attrs.set("ordered", @parser_common.bool_string(current.ordered))
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

///|
fn pptx_lower_picture(
  blocks : Array[@core.CoreBlock],
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  pic : @pptxdoc.PptxPicture,
) -> Unit {
  let media = match pic.media {
    Some(value) => value
    None => return
  }
  if media.is_external {
    state.diagnostics.warnings.push(
      "external pptx media skipped: " +
      media.resolved_target.unwrap_or("unknown target"),
    )
    state.diagnostics.degraded_features.push("pptx_external_media_no_fetch")
    blocks.push(
      pptx_raw_placeholder_block(
        state,
        slide,
        Some(media.source_key),
        media.relationship_id,
        "[Unsupported PPTX media" + pptx_opt_suffix(media.resolved_target) + "]",
        "pptx_external_media_no_fetch",
      ),
    )
    return
  }
  if media.unsupported || media.data is None {
    state.diagnostics.warnings.push(
      "unsupported pptx media skipped: " +
      media.resolved_target.unwrap_or("unknown target"),
    )
    state.diagnostics.degraded_features.push("pptx_media_unsupported")
    blocks.push(
      pptx_raw_placeholder_block(
        state,
        slide,
        Some(media.source_key),
        media.relationship_id,
        "[Unsupported PPTX media" + pptx_opt_suffix(media.resolved_target) + "]",
        "pptx_media_unsupported",
      ),
    )
    return
  }
  let image_block = pptx_image_block_from_media(state, slide, pic, media)
  blocks.push(image_block)
}

///|
fn pptx_image_block_from_media(
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  pic : @pptxdoc.PptxPicture,
  media : @pptxdoc.PptxMediaRef,
) -> @core.CoreBlock {
  let target_part = media.resolved_target.unwrap_or(
    media.target.unwrap_or("ppt/media/image.bin"),
  )
  let asset_key = pptx_picture_asset_key(slide, pic, media)
  let output_path = pptx_asset_output_path(state, asset_key, target_part)
  let source_ref = pptx_picture_source_ref(state.source, slide, pic)
  let asset = pptx_ensure_asset(
    state, media, asset_key, output_path, source_ref,
  )
  let alt = pptx_image_alt_text(state, pic, media, slide.slide_index)
  let block = @core.make_block(@core.BlockKind::Image, "", source_ref~)
  block.attrs.set("path", asset.path.unwrap_or(output_path))
  block.attrs.set("alt", alt)
  match media.title {
    Some(title) => if title.trim() != "" { block.attrs.set("title", title) }
    None => ()
  }
  match pptx_image_caption_for_picture(slide, pic.source_key) {
    Some(caption) =>
      if caption.trim() != "" {
        block.attrs.set("caption", caption)
      }
    None => ()
  }
  block
}

///|
fn pptx_ensure_asset(
  state : PptxState,
  media : @pptxdoc.PptxMediaRef,
  asset_key : String,
  output_path : String,
  source_ref : @core.SourceRef,
) -> @core.AssetRef {
  let target_part = media.resolved_target.unwrap_or(media.target.unwrap_or(""))
  match state.asset_ids.get(asset_key) {
    Some(asset_id) =>
      for asset in state.assets {
        if asset.asset_id == asset_id {
          return asset
        }
      }
    None => ()
  }
  let asset_id = "pptx:" + asset_key
  let asset = @core.make_asset_ref(
    @core.AssetKind::Image,
    asset_id,
    source_ref~,
  )
  let next_asset = {
    ..asset,
    path: Some(output_path),
    mime_type: media.content_type,
  }
  next_asset.attrs.set("alt", pptx_media_alt_text(media))
  next_asset.attrs.set("source_path", target_part)
  next_asset.attrs.set("zip_entry_path", target_part)
  next_asset.attrs.set("zip_container_format", "pptx")
  match state.source.path {
    Some(path) => next_asset.attrs.set("zip_container_path", path)
    None => ()
  }
  state.assets.push(next_asset)
  state.asset_ids.set(asset_key, asset_id)
  bump_metric(state.diagnostics, "materialized_asset_count")
  next_asset
}

///|
fn metric_int(diagnostics : @core.Diagnostics, key : String) -> Int {
  @string.parse_int(diagnostics.metrics.get(key).unwrap_or("0")) catch {
    _ => 0
  }
}

///|
fn bump_metric(diagnostics : @core.Diagnostics, key : String) -> Unit {
  let current = metric_int(diagnostics, key)
  diagnostics.metrics.set(key, (current + 1).to_string())
}

///|
fn pptx_asset_output_path(
  state : PptxState,
  asset_key : String,
  target_part : String,
) -> String {
  match state.asset_ids.get(asset_key) {
    Some(asset_id) =>
      for asset in state.assets {
        if asset.asset_id == asset_id {
          return asset.path.unwrap_or("assets/image01.bin")
        }
      }
    None => ()
  }
  let index = state.assets.length() + 1
  "assets/image" + pptx_two_digits(index) + "." + pptx_media_ext(target_part)
}

///|
fn pptx_picture_asset_key(
  slide : @pptxdoc.PptxSlide,
  pic : @pptxdoc.PptxPicture,
  media : @pptxdoc.PptxMediaRef,
) -> String {
  slide.slide_index.to_string() +
  ":" +
  pic.source_key.node_key +
  ":" +
  pic.shape_id.unwrap_or("") +
  ":" +
  media.resolved_target.unwrap_or(media.target.unwrap_or(""))
}

///|
fn pptx_media_ext(target_part : String) -> String {
  let lower = target_part.to_lower()
  let chars = lower.to_array()
  let mut last_dot : Int? = None
  for i in 0..<chars.length() {
    if chars[i] == '.' {
      last_dot = Some(i)
    }
  }
  match last_dot {
    Some(index) =>
      if index + 1 < lower.length() {
        lower[index + 1:].to_owned()
      } else {
        "bin"
      }
    None => "bin"
  }
}

///|
fn pptx_two_digits(index : Int) -> String {
  if index < 10 {
    "0" + index.to_string()
  } else {
    index.to_string()
  }
}

///|
fn pptx_image_alt_text(
  state : PptxState,
  pic : @pptxdoc.PptxPicture,
  media : @pptxdoc.PptxMediaRef,
  slide_index : Int,
) -> String {
  let fallback = pptx_picture_synthetic_id(state, media, slide_index)
  match media.alt_text {
    Some(text) =>
      if pptx_nonsemantic_picture_label(text) {
        fallback
      } else {
        text
      }
    None =>
      match pic.name {
        Some(name) =>
          if pptx_nonsemantic_picture_label(name) ||
            pptx_generic_picture_name(name) {
            fallback
          } else {
            name
          }
        None => fallback
      }
  }
}

///|
fn pptx_generic_picture_name(name : String) -> Bool {
  let trimmed = name.trim().to_owned()
  if trimmed == "" {
    return true
  }
  let lower = trimmed.to_lower()
  lower == "picture" ||
  lower.has_prefix("picture ") ||
  lower.has_prefix("content placeholder") ||
  lower.has_prefix("placeholder ")
}

///|
fn pptx_nonsemantic_picture_label(text : String) -> Bool {
  let lower = text.trim().to_owned().to_lower()
  if lower == "" {
    return true
  }
  if pptx_path_like_descr(lower) {
    return true
  }
  lower.has_suffix(".wav") ||
  lower.has_suffix(".mp3") ||
  lower.has_suffix(".m4a") ||
  lower.has_suffix(".aac") ||
  lower.has_suffix(".wma") ||
  lower.has_suffix(".mp4") ||
  lower.has_suffix(".m4v") ||
  lower.has_suffix(".mov") ||
  lower.has_suffix(".avi") ||
  lower.has_suffix(".wmv")
}

///|
fn pptx_picture_synthetic_id(
  state : PptxState,
  media : @pptxdoc.PptxMediaRef,
  slide_index : Int,
) -> String {
  let key = slide_index.to_string() +
    ":" +
    media.source_key.node_key +
    ":" +
    media.resolved_target.unwrap_or(media.target.unwrap_or(""))
  match state.image_ids.get(key) {
    Some(id) => id
    None => {
      let slide_key = slide_index.to_string()
      let next_index = state.slide_image_counts.get(slide_key).unwrap_or(0) + 1
      state.slide_image_counts.set(slide_key, next_index)
      let id = "slide-" +
        slide_index.to_string() +
        "-image-" +
        next_index.to_string()
      state.image_ids.set(key, id)
      id
    }
  }
}

///|
fn pptx_media_alt_text(media : @pptxdoc.PptxMediaRef) -> String {
  match media.alt_text {
    Some(text) => if pptx_path_like_descr(text) { "image" } else { text }
    None => "image"
  }
}

///|
fn pptx_path_like_descr(text : String) -> Bool {
  let value = text.trim().to_lower()
  if value == "" {
    return false
  }
  if value.contains("/") || value.contains("\\") {
    return true
  }
  value.has_suffix(".png") ||
  value.has_suffix(".jpg") ||
  value.has_suffix(".jpeg") ||
  value.has_suffix(".gif") ||
  value.has_suffix(".bmp") ||
  value.has_suffix(".tif") ||
  value.has_suffix(".tiff") ||
  value.has_suffix(".svg") ||
  value.has_suffix(".webp")
}

///|
fn pptx_image_caption_for_picture(
  slide : @pptxdoc.PptxSlide,
  key : @pptxdoc.PptxSourceKey,
) -> String? {
  for pair in slide.image_caption_pairs {
    if pair.picture_key.part_name == key.part_name &&
      pair.picture_key.node_key == key.node_key &&
      pptx_caption_pair_is_semantic(pair) {
      return Some(pair.caption_text)
    }
  }
  None
}

///|
fn pptx_caption_pair_is_semantic(pair : @pptxdoc.PptxImageCaptionPair) -> Bool {
  pptx_caption_text_has_prefix(pair.caption_text)
}
