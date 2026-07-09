///|
fn lower_docx_inlines(
  state : DocxLoweringState,
  inlines : Array[@ddocx.DocxInline],
  source_key : @ddocx.DocxSourceKey,
) -> DocxInlineLowering {
  let rich_inlines : Array[@core.CoreInline] = []
  let plain = StringBuilder::new()
  let inline_source_ref = docx_source_ref_from_key(
    state,
    source_key,
    None,
    None,
  )
  let mut pending_space_before_comment = false

  fn append_plain_and_rich(
    plain : StringBuilder,
    rich_inlines : Array[@core.CoreInline],
    text : String,
    source_ref : @core.SourceRef,
  ) -> Unit {
    if text == "" {
      return
    }
    plain.write_string(text)
    rich_inlines.push(@core.make_inline_text(text, source_ref~))
  }

  fn append_nested_inline_lowering(
    plain : StringBuilder,
    rich_inlines : Array[@core.CoreInline],
    nested : DocxInlineLowering,
    has_link : Ref[Bool],
    image_count : Ref[Int],
    hyperlink_count : Ref[Int],
    tracked_change_count : Ref[Int],
  ) -> Unit {
    if nested.plain_text != "" {
      plain.write_string(nested.plain_text)
    }
    if nested.rich_inlines.length() > 0 {
      rich_inlines.append(nested.rich_inlines[:])
    }
    has_link.val = has_link.val || nested.has_link
    image_count.val += nested.image_count
    hyperlink_count.val += nested.hyperlink_count
    tracked_change_count.val += nested.tracked_change_count
  }

  fn append_textbox_inline_if_available(
    state : DocxLoweringState,
    anchor_id : String?,
    plain : StringBuilder,
    rich_inlines : Array[@core.CoreInline],
    has_link : Ref[Bool],
    image_count : Ref[Int],
    hyperlink_count : Ref[Int],
    tracked_change_count : Ref[Int],
  ) -> Bool {
    if !@product.accurate_feature_enabled(
        state.accurate_features,
        @product.AccurateFeature::DocxTextboxInline,
      ) {
      return false
    }
    let resolved_anchor_id = match anchor_id {
      Some(value) => value.trim().to_owned()
      None => return false
    }
    if resolved_anchor_id == "" {
      return false
    }
    if state.expanding_textbox_anchors.contains(resolved_anchor_id) {
      return false
    }
    let textbox = match docx_find_textbox_by_anchor(state, resolved_anchor_id) {
      Some(value) => value
      None => return false
    }
    let nested_blocks : Array[@core.CoreBlock] = []
    state.expanding_textbox_anchors.push(resolved_anchor_id)
    lower_docx_blocks(state, nested_blocks, textbox.blocks)
    ignore(state.expanding_textbox_anchors.pop())
    let flattened = match
      docx_flatten_blocks_to_paragraph_like(
        state,
        nested_blocks,
        textbox.source_key,
      ) {
      Some(value) => value
      None => return false
    }
    if flattened.text.trim() == "" {
      return false
    }
    let existing = plain.to_string()
    if existing.trim() != "" && !existing.has_suffix("\n") {
      plain.write_string("\n")
      rich_inlines.push(
        @core.make_inline_line_break(source_ref=inline_source_ref),
      )
    }
    let nested = lower_docx_inlines(
      state,
      [@ddocx.DocxInline::Text(flattened.text)],
      textbox.source_key,
    )
    let lowered = match flattened.rich_inlines {
      Some(_) =>
        {
          rich_inlines: flattened.rich_inlines.unwrap_or([]),
          plain_text: flattened.text,
          has_link: nested.has_link,
          image_count: nested.image_count,
          hyperlink_count: nested.hyperlink_count,
          tracked_change_count: nested.tracked_change_count,
        }
      None => nested
    }
    docx_mark_textbox_consumed(state, resolved_anchor_id)
    append_nested_inline_lowering(
      plain, rich_inlines, lowered, has_link, image_count, hyperlink_count, tracked_change_count,
    )
    true
  }

  let has_link_ref : Ref[Bool] = { val: false }
  let image_count_ref : Ref[Int] = { val: 0 }
  let hyperlink_count_ref : Ref[Int] = { val: 0 }
  let tracked_change_count_ref : Ref[Int] = { val: 0 }

  for inline in inlines {
    match inline {
      @ddocx.DocxInline::Text(text) =>
        append_plain_and_rich(plain, rich_inlines, text, inline_source_ref)
      @ddocx.DocxInline::Tab =>
        append_plain_and_rich(plain, rich_inlines, " ", inline_source_ref)
      @ddocx.DocxInline::LineBreak => {
        plain.write_string("\n")
        rich_inlines.push(
          @core.make_inline_line_break(source_ref=inline_source_ref),
        )
      }
      @ddocx.DocxInline::Break(value) =>
        match render_docx_break_text(value) {
          "\n" => {
            plain.write_string("\n")
            rich_inlines.push(
              @core.make_inline_line_break(source_ref=inline_source_ref),
            )
          }
          text =>
            append_plain_and_rich(plain, rich_inlines, text, inline_source_ref)
        }
      @ddocx.DocxInline::Hyperlink(link) => {
        let source_ref = docx_source_ref_from_key(
          state,
          link.source_key,
          link.relationship_id,
          None,
        )
        plain.write_string(link.text)
        match link.target {
          Some(target) =>
            if target.trim() != "" {
              rich_inlines.push(
                @core.make_inline_link(link.text, target, source_ref~),
              )
              has_link_ref.val = true
              hyperlink_count_ref.val += 1
            } else {
              rich_inlines.push(@core.make_inline_text(link.text, source_ref~))
            }
          None =>
            rich_inlines.push(@core.make_inline_text(link.text, source_ref~))
        }
      }
      @ddocx.DocxInline::Media(media) =>
        image_count_ref.val += lower_docx_media_inline(
          state,
          rich_inlines,
          plain,
          media,
          None,
          [],
        )
      @ddocx.DocxInline::Drawing(drawing) => {
        let media_count = match drawing.media {
          Some(media) =>
            lower_docx_media_inline(
              state,
              rich_inlines,
              plain,
              media,
              drawing.doc_pr_id,
              drawing.alternate_media,
            )
          None => 0
        }
        image_count_ref.val += media_count
        if media_count == 0 &&
          append_textbox_inline_if_available(
            state,
            match drawing.text_box_ref {
              Some(textbox_ref) => textbox_ref.anchor_id
              None => None
            },
            plain,
            rich_inlines,
            has_link_ref,
            image_count_ref,
            hyperlink_count_ref,
            tracked_change_count_ref,
          ) {
          continue
        }
        if media_count == 0 && drawing.child_inlines.length() > 0 {
          let child = lower_docx_inlines(
            state,
            drawing.child_inlines,
            drawing.source_key,
          )
          append_nested_inline_lowering(
            plain, rich_inlines, child, has_link_ref, image_count_ref, hyperlink_count_ref,
            tracked_change_count_ref,
          )
        }
      }
      @ddocx.DocxInline::Shape(shape) => {
        let media_count = match shape.media {
          Some(media) =>
            lower_docx_media_inline(
              state,
              rich_inlines,
              plain,
              media,
              shape.shape_id,
              [],
            )
          None => 0
        }
        image_count_ref.val += media_count
        if media_count == 0 &&
          append_textbox_inline_if_available(
            state,
            match shape.text_box_ref {
              Some(textbox_ref) => textbox_ref.anchor_id
              None => None
            },
            plain,
            rich_inlines,
            has_link_ref,
            image_count_ref,
            hyperlink_count_ref,
            tracked_change_count_ref,
          ) {
          continue
        }
        if media_count == 0 && shape.child_inlines.length() > 0 {
          let child = lower_docx_inlines(
            state,
            shape.child_inlines,
            shape.source_key,
          )
          append_nested_inline_lowering(
            plain, rich_inlines, child, has_link_ref, image_count_ref, hyperlink_count_ref,
            tracked_change_count_ref,
          )
        }
      }
      @ddocx.DocxInline::ContentControl(control) =>
        if control.inlines.length() > 0 {
          let child = lower_docx_inlines(
            state,
            control.inlines,
            control.source_key,
          )
          append_nested_inline_lowering(
            plain, rich_inlines, child, has_link_ref, image_count_ref, hyperlink_count_ref,
            tracked_change_count_ref,
          )
        } else if control.text.trim() != "" {
          append_plain_and_rich(
            plain,
            rich_inlines,
            control.text,
            docx_source_ref_from_key(state, control.source_key, None, None),
          )
        }
      @ddocx.DocxInline::FieldUnsupported(field) =>
        append_plain_and_rich(
          plain,
          rich_inlines,
          render_docx_field_text(field),
          docx_source_ref_from_key(state, field.source_key, None, None),
        )
      @ddocx.DocxInline::Math(math) =>
        append_plain_and_rich(
          plain,
          rich_inlines,
          render_docx_math_text(math),
          docx_source_ref_from_key(state, math.source_key, None, None),
        )
      @ddocx.DocxInline::Bookmark(_) => ()
      @ddocx.DocxInline::TrackedChange(change) => {
        tracked_change_count_ref.val += 1
        let text = render_docx_tracked_change_text(change)
        append_plain_and_rich(
          plain,
          rich_inlines,
          text,
          docx_source_ref_from_key(state, change.source_key, None, None),
        )
      }
      @ddocx.DocxInline::SmartTag(smart_tag) => {
        let child = lower_docx_inlines(
          state,
          smart_tag.child_inlines,
          smart_tag.source_key,
        )
        append_nested_inline_lowering(
          plain, rich_inlines, child, has_link_ref, image_count_ref, hyperlink_count_ref,
          tracked_change_count_ref,
        )
      }
      @ddocx.DocxInline::Symbol(symbol) =>
        append_plain_and_rich(
          plain,
          rich_inlines,
          render_docx_symbol_text(symbol),
          docx_source_ref_from_key(state, symbol.source_key, None, None),
        )
      @ddocx.DocxInline::Hyphen(hyphen) =>
        append_plain_and_rich(
          plain,
          rich_inlines,
          render_docx_hyphen_text(hyphen),
          docx_source_ref_from_key(state, hyphen.source_key, None, None),
        )
      @ddocx.DocxInline::FootnoteRef(id) => {
        let marker = docx_note_marker_label(
          state.footnote_labels.get(id).unwrap_or(id),
          "footnote",
        )
        let marker_inline = docx_reference_inline(
          state,
          source_key,
          note_kind="footnote",
          note_id=id,
          marker~,
        )
        plain.write_string(marker)
        rich_inlines.push(marker_inline)
      }
      @ddocx.DocxInline::EndnoteRef(id) => {
        let marker = docx_note_marker_label(
          state.endnote_labels.get(id).unwrap_or(id),
          "endnote",
        )
        let marker_inline = docx_reference_inline(
          state,
          source_key,
          note_kind="endnote",
          note_id=id,
          marker~,
        )
        plain.write_string(marker)
        rich_inlines.push(marker_inline)
      }
      @ddocx.DocxInline::CommentRef(id) => {
        let marker = docx_note_marker_label(
          state.comment_labels.get(id).unwrap_or(id),
          "comment",
        )
        let current = plain.to_string()
        let gap = if !current.has_suffix(" ") { " " } else { "" }
        if gap != "" {
          plain.write_string(gap)
          rich_inlines.push(
            @core.make_inline_text(gap, source_ref=inline_source_ref),
          )
        }
        let marker_inline = docx_reference_inline(
          state,
          source_key,
          note_kind="comment",
          note_id=id,
          marker~,
        )
        plain.write_string(marker)
        rich_inlines.push(marker_inline)
        pending_space_before_comment = false
      }
      @ddocx.DocxInline::StructuralMarker(_) => ()
      @ddocx.DocxInline::TextBoxRef(textbox_ref) =>
        ignore(
          append_textbox_inline_if_available(
            state,
            textbox_ref.anchor_id,
            plain,
            rich_inlines,
            has_link_ref,
            image_count_ref,
            hyperlink_count_ref,
            tracked_change_count_ref,
          ),
        )
      @ddocx.DocxInline::UnsupportedInline(_) =>
        append_plain_and_rich(
          plain, rich_inlines, "[unsupported DOCX inline]", inline_source_ref,
        )
      @ddocx.DocxInline::Unsupported(_) => ()
    }
  }
  ignore(pending_space_before_comment)
  let current_hyperlink_count = metric_int(
    state.diagnostics,
    "docx_hyperlink_count",
  )
  state.diagnostics.metrics.set(
    "docx_hyperlink_count",
    (current_hyperlink_count + hyperlink_count_ref.val).to_string(),
  )
  let normalized_rich_inlines = normalize_docx_marker_rich_inlines(rich_inlines)
  {
    rich_inlines: normalized_rich_inlines,
    plain_text: normalize_docx_ref_marker_spacing(plain.to_string()),
    has_link: has_link_ref.val,
    image_count: image_count_ref.val,
    hyperlink_count: hyperlink_count_ref.val,
    tracked_change_count: tracked_change_count_ref.val,
  }
}

///|
fn lower_docx_media_inline(
  state : DocxLoweringState,
  rich_inlines : Array[@core.CoreInline],
  plain : StringBuilder,
  media : @ddocx.DocxMediaRef,
  shape_id : String?,
  alternate_media : Array[@ddocx.DocxMediaRef],
) -> Int {
  match media.target_mode {
    Some(@ddocx.DocxTargetMode::External) => {
      state.diagnostics.warnings.push(
        "docx external media is no-fetch and not materialized",
      )
      state.diagnostics.degraded_features.push("docx_external_media_no_fetch")
      bump_metric(state.diagnostics, "skipped_asset_count")
      return 0
    }
    _ => ()
  }
  match media.target_exists {
    Some(false) => {
      state.diagnostics.warnings.push(
        "docx media target missing: " +
        media.target_part.unwrap_or(media.resolved_target.unwrap_or("unknown")),
      )
      bump_metric(state.diagnostics, "skipped_asset_count")
      return 0
    }
    _ => ()
  }
  let target_part = match media.target_part {
    Some(value) => value
    None =>
      match media.resolved_target {
        Some(value) => value
        None => {
          state.diagnostics.warnings.push("docx media target missing")
          bump_metric(state.diagnostics, "skipped_asset_count")
          return 0
        }
      }
  }
  let source_ref = docx_source_ref_from_key(
    state,
    media.source_key,
    media.relationship_id,
    shape_id,
  )
  let alt = docx_image_alt_text(media)
  let title = normalize_docx_optional_text(media.title)
  if !docx_media_should_render_as_image(media, target_part) {
    let placeholder = "[image: " + alt + "]"
    plain.write_string(placeholder)
    rich_inlines.push(
      @core.inline_with_attr(
        @core.make_inline_text(placeholder, source_ref~),
        "render_literal",
        "true",
      ),
    )
    return 0
  }
  let output_path = docx_asset_output_path(state, target_part, media)
  rich_inlines.push(
    @core.make_inline_image(alt, output_path, title~, source_ref~),
  )
  plain.write_string("[image: " + alt + "]")
  let asset = ensure_docx_asset_ref(state, media, output_path, source_ref)
  ignore(asset)
  docx_materialize_companion_assets(state, alternate_media, shape_id)
  bump_metric(state.diagnostics, "docx_image_count")
  1
}

///|
fn docx_paragraph_is_image_only(inline : DocxInlineLowering) -> Bool {
  inline.image_count == 1 &&
  inline.rich_inlines.length() == 1 &&
  inline.rich_inlines[0].kind == @core.InlineKind::Image
}

///|
fn lower_docx_image_only_paragraph(
  _state : DocxLoweringState,
  _p : @ddocx.DocxParagraph,
  inline : DocxInlineLowering,
  source_ref : @core.SourceRef,
) -> @core.CoreBlock {
  let image = inline.rich_inlines[0]
  let block = @core.make_block(@core.BlockKind::Image, "", source_ref~)
  block.attrs.set("path", image.href.unwrap_or("#"))
  block.attrs.set("alt", image.text)
  match image.title {
    Some(title) => block.attrs.set("title", title)
    None => ()
  }
  block
}

///|
fn ensure_docx_asset_ref(
  state : DocxLoweringState,
  media : @ddocx.DocxMediaRef,
  output_path : String,
  source_ref : @core.SourceRef,
) -> @core.AssetRef {
  let target_part = media.target_part.unwrap_or(
    media.resolved_target.unwrap_or(""),
  )
  match state.asset_ids.get(target_part) {
    Some(asset_id) =>
      for asset in state.assets {
        if asset.asset_id == asset_id {
          return asset
        }
      }
    None => ()
  }
  let asset_id = "docx:" + target_part
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
  next_asset.attrs.set("alt", docx_image_alt_text(media))
  next_asset.attrs.set("source_path", target_part)
  next_asset.attrs.set("zip_entry_path", target_part)
  next_asset.attrs.set("zip_container_format", "docx")
  match state.source.path {
    Some(path) => next_asset.attrs.set("zip_container_path", path)
    None => ()
  }
  state.assets.push(next_asset)
  state.asset_ids.set(target_part, asset_id)
  bump_metric(state.diagnostics, "materialized_asset_count")
  next_asset
}

///|
fn docx_asset_output_path(
  state : DocxLoweringState,
  target_part : String,
  media : @ddocx.DocxMediaRef,
) -> String {
  match state.asset_ids.get(target_part) {
    Some(asset_id) =>
      for asset in state.assets {
        if asset.asset_id == asset_id {
          return asset.path.unwrap_or("assets/image01.bin")
        }
      }
    None => ()
  }
  let index = state.assets.length() + 1
  "assets/image" +
  docx_two_digits(index) +
  "." +
  docx_media_output_ext(media, target_part)
}
