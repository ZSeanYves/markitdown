///|
fn docx_prefixed_rich_inlines(
  prefix : String,
  inlines : Array[@core.CoreInline],
) -> Array[@core.CoreInline] {
  if prefix == "" {
    return inlines
  }
  let out : Array[@core.CoreInline] = [@core.make_inline_text(prefix)]
  out.append(inlines[:])
  out
}

///|
fn docx_should_inline_textboxes_in_place(state : DocxLoweringState) -> Bool {
  if state.lowering_profile != @product.LoweringProfile::AccurateSemantic {
    return false
  }
  @product.accurate_feature_enabled(
    state.accurate_features,
    @product.AccurateFeature::DocxTextboxInline,
  )
}

///|
fn docx_find_textbox_by_anchor(
  state : DocxLoweringState,
  anchor_id : String,
) -> @ddocx.DocxTextBox? {
  for textbox in state.docx.textboxes {
    if textbox.anchor_id == anchor_id {
      return Some(textbox)
    }
  }
  None
}

///|
fn docx_mark_textbox_consumed(
  state : DocxLoweringState,
  anchor_id : String,
) -> Unit {
  if anchor_id.trim() != "" {
    state.consumed_textbox_anchors.set(anchor_id, true)
  }
}

///|
fn docx_textbox_is_consumed(
  state : DocxLoweringState,
  anchor_id : String,
) -> Bool {
  state.consumed_textbox_anchors.get(anchor_id) == Some(true)
}

///|
fn docx_collect_comment_inline_images(
  blocks : Array[@core.CoreBlock],
) -> Array[@core.CoreBlock] {
  let out : Array[@core.CoreBlock] = []
  for block in blocks {
    match block.rich_inlines {
      Some(inlines) =>
        for inline in inlines {
          if inline.kind == @core.InlineKind::Image {
            let image = @core.make_block(
              @core.BlockKind::Image,
              "",
              source_ref=inline.source_ref.unwrap_or(@core.empty_source_ref()),
            )
            image.attrs.set("path", inline.href.unwrap_or("#"))
            image.attrs.set("alt", inline.text)
            match inline.title {
              Some(title) => image.attrs.set("title", title)
              None => ()
            }
            out.push(image)
          }
        }
      None => ()
    }
  }
  out
}

///|
fn docx_comment_block_without_inline_images(
  block : @core.CoreBlock,
) -> @core.CoreBlock {
  match block.rich_inlines {
    Some(inlines) => {
      let filtered : Array[@core.CoreInline] = []
      let text = StringBuilder::new()
      for inline in inlines {
        if inline.kind == @core.InlineKind::Image {
          continue
        }
        filtered.push(inline)
        text.write_string(docx_comment_inline_text_fragment(inline))
      }
      let normalized_text = docx_comment_cleanup_spacing(text.to_string())
      let next = { ..block, text: normalized_text }
      if filtered.length() == 0 {
        { ..next, rich_inlines: None }
      } else {
        { ..next, rich_inlines: Some(filtered) }
      }
    }
    None => block
  }
}

///|
fn docx_comment_inline_text_fragment(inline : @core.CoreInline) -> String {
  match inline.kind {
    @core.InlineKind::Text | @core.InlineKind::Link | @core.InlineKind::Code =>
      inline.text
    @core.InlineKind::LineBreak => "\n"
    @core.InlineKind::Image => ""
  }
}

///|
fn docx_comment_cleanup_spacing(text : String) -> String {
  let normalized = normalize_docx_ref_marker_spacing(text)
  normalized.replace(old=" \n", new="\n").replace(old="\n ", new="\n")
}

///|
fn append_docx_note_definitions_blocks(
  state : DocxLoweringState,
  out : Array[@core.CoreBlock],
) -> Unit {
  let footnote_ids = docx_note_ids_sorted_by_label(state.footnote_labels)
  for id in footnote_ids {
    match docx_lookup_footnote(state, id) {
      Some(note) =>
        append_docx_note_definition_blocks(
          state,
          out,
          note.blocks,
          state.footnote_labels.get(id).unwrap_or(id),
          note.source_key,
        )
      None => ()
    }
  }
  let endnote_ids = docx_note_ids_sorted_by_label(state.endnote_labels)
  for id in endnote_ids {
    match docx_lookup_endnote(state, id) {
      Some(note) =>
        append_docx_note_definition_blocks(
          state,
          out,
          note.blocks,
          "e" + state.endnote_labels.get(id).unwrap_or(id),
          note.source_key,
        )
      None => ()
    }
  }
}

///|
fn docx_note_ids_sorted_by_label(labels : Map[String, String]) -> Array[String] {
  let keyed = labels.to_array()
  keyed.sort_by(fn(a, b) {
    let a_order = docx_sortable_note_label(a.1)
    let b_order = docx_sortable_note_label(b.1)
    let primary = a_order.compare(b_order)
    if primary != 0 {
      primary
    } else {
      a.0.compare(b.0)
    }
  })
  keyed.map(fn(entry) { entry.0 })
}

///|
fn docx_sortable_note_label(label : String) -> String {
  let trimmed = label.trim().to_owned()
  let parsed = @string.parse_int(trimmed) catch { _ => return "1:" + trimmed }
  "0:" + docx_zero_pad_int(parsed, 12)
}

///|
fn docx_zero_pad_int(value : Int, width : Int) -> String {
  let raw = value.to_string()
  if raw.length() >= width {
    raw
  } else {
    "0".repeat(width - raw.length()) + raw
  }
}

///|
fn append_docx_note_definition_blocks(
  state : DocxLoweringState,
  out : Array[@core.CoreBlock],
  blocks : Array[@ddocx.DocxBlock],
  note_id : String,
  source_key : @ddocx.DocxSourceKey,
) -> Unit {
  let lowered : Array[@core.CoreBlock] = []
  lower_docx_blocks(state, lowered, blocks)
  if lowered.length() == 0 {
    return
  }
  let note = match
    docx_flatten_blocks_to_paragraph_like(state, lowered, source_key) {
    Some(block) => docx_note_block_with_inline_breaks(block)
    None => {
      let first = lowered[0]
      let note0 = @core.make_block(
        @core.BlockKind::Paragraph,
        first.text,
        source_ref=first.source_ref.unwrap_or(
          docx_source_ref_from_key(state, source_key, None, None),
        ),
      )
      @core.block_with_rich_inlines(note0, first.rich_inlines)
    }
  }
  note.attrs.set("note_definition_id", note_id)
  note.attrs.set("note_definition_kind", "docx")
  out.push(note)
}

///|
fn docx_note_block_with_inline_breaks(
  block : @core.CoreBlock,
) -> @core.CoreBlock {
  match block.rich_inlines {
    Some(inlines) => {
      let expanded : Array[@core.CoreInline] = []
      for inline in inlines {
        if inline.kind == @core.InlineKind::Text && inline.text.contains("\n") {
          let parts = inline.text
            .replace(old="\r\n", new="\n")
            .replace(old="\r", new="\n")
            .split("\n")
            .to_array()
          for i in 0..<parts.length() {
            if i > 0 {
              expanded.push(
                @core.make_inline_line_break(
                  source_ref=inline.source_ref.unwrap_or(
                    @core.empty_source_ref(),
                  ),
                ),
              )
            }
            let part = parts[i].to_owned()
            if part != "" {
              expanded.push(
                @core.make_inline_text(
                  part,
                  source_ref=inline.source_ref.unwrap_or(
                    @core.empty_source_ref(),
                  ),
                ),
              )
            }
          }
        } else {
          expanded.push(inline)
        }
      }
      @core.block_with_rich_inlines(block, Some(expanded))
    }
    None => block
  }
}

///|
fn append_docx_part_body_blocks(
  state : DocxLoweringState,
  out : Array[@core.CoreBlock],
  bodies : Array[@ddocx.DocxPartBody],
  section_title : String,
  item_title : String,
) -> Unit {
  let visible : Array[@ddocx.DocxPartBody] = []
  for body in bodies {
    if docx_blocks_have_visible_content(body.blocks) ||
      docx_part_body_has_visible_textboxes(state, body) {
      visible.push(body)
    }
  }
  if visible.length() == 0 {
    return
  }
  let heading = @core.make_block(
    @core.BlockKind::Heading,
    section_title,
    source_ref=docx_part_source_ref(
      state,
      visible[0].part_name,
      visible[0].relationship_id,
    ),
  )
  heading.attrs.set("level", "2")
  out.push(heading)
  let mut index = 1
  for body in visible {
    let title = item_title +
      " " +
      index.to_string() +
      " " +
      docx_part_body_slot_label(body)
    let body_heading = @core.make_block(
      @core.BlockKind::Heading,
      title,
      source_ref=docx_part_source_ref(
        state,
        body.part_name,
        body.relationship_id,
      ),
    )
    body_heading.attrs.set("level", "3")
    out.push(body_heading)
    append_docx_body_blocks_with_textboxes(state, out, body)
    index += 1
  }
  state.diagnostics.metrics.set(
    "docx_header_footer_count",
    visible.length().to_string(),
  )
}

///|
fn append_docx_body_blocks_with_textboxes(
  state : DocxLoweringState,
  out : Array[@core.CoreBlock],
  body : @ddocx.DocxPartBody,
) -> Unit {
  let blocks : Array[@core.CoreBlock] = []
  lower_docx_blocks(state, blocks, body.blocks)
  let textbox_blocks = docx_textbox_blocks_for_body(state, body)
  if blocks.length() == 0 && textbox_blocks.length() == 0 {
    return
  }
  let merged_blocks : Array[@core.CoreBlock] = []
  merged_blocks.append(blocks[:])
  merged_blocks.append(textbox_blocks[:])
  match
    docx_flatten_blocks_to_paragraph_like(state, merged_blocks, body.source_key) {
    Some(merged) => out.push(merged)
    None => out.append(blocks[:])
  }
}

///|
fn docx_part_body_has_visible_textboxes(
  state : DocxLoweringState,
  body : @ddocx.DocxPartBody,
) -> Bool {
  for textbox in state.docx.textboxes {
    if docx_should_inline_textboxes_in_place(state) &&
      docx_textbox_is_consumed(state, textbox.anchor_id) {
      continue
    }
    if textbox.owner_part != body.part_name {
      continue
    }
    if body.relationship_id != textbox.relationship_id {
      continue
    }
    if docx_blocks_have_visible_content(textbox.blocks) {
      return true
    }
  }
  false
}

///|
fn docx_textbox_blocks_for_body(
  state : DocxLoweringState,
  body : @ddocx.DocxPartBody,
) -> Array[@core.CoreBlock] {
  let blocks : Array[@core.CoreBlock] = []
  for textbox in state.docx.textboxes {
    if docx_should_inline_textboxes_in_place(state) &&
      docx_textbox_is_consumed(state, textbox.anchor_id) {
      continue
    }
    if textbox.owner_part != body.part_name {
      continue
    }
    if body.relationship_id != textbox.relationship_id {
      continue
    }
    if !docx_blocks_have_visible_content(textbox.blocks) {
      continue
    }
    if docx_should_inline_textboxes_in_place(state) {
      docx_mark_textbox_consumed(state, textbox.anchor_id)
    }
    lower_docx_blocks(state, blocks, textbox.blocks)
  }
  blocks
}

///|
fn append_docx_textboxes_blocks(
  state : DocxLoweringState,
  out : Array[@core.CoreBlock],
) -> Unit {
  let visible : Array[@ddocx.DocxTextBox] = []
  for textbox in state.docx.textboxes {
    if docx_should_inline_textboxes_in_place(state) &&
      docx_textbox_is_consumed(state, textbox.anchor_id) {
      continue
    }
    if docx_blocks_have_visible_content(textbox.blocks) {
      visible.push(textbox)
    }
  }
  if visible.length() == 0 {
    return
  }
  let heading = @core.make_block(
    @core.BlockKind::Heading,
    "Text Boxes",
    source_ref=docx_part_source_ref(
      state,
      visible[0].part_name,
      visible[0].relationship_id,
    ),
  )
  heading.attrs.set("level", "2")
  out.push(heading)
  let mut index = 1
  for textbox in visible {
    let title = docx_textbox_appendix_title(textbox, index)
    let box_heading = @core.make_block(
      @core.BlockKind::Heading,
      title,
      source_ref=docx_source_ref_from_key(
        state,
        textbox.source_key,
        textbox.relationship_id,
        textbox.shape_id,
      ),
    )
    box_heading.attrs.set("level", "3")
    out.push(box_heading)
    let blocks : Array[@core.CoreBlock] = []
    lower_docx_blocks(state, blocks, textbox.blocks)
    out.append(blocks[:])
    index += 1
  }
}

///|
fn docx_flatten_blocks_to_paragraph_like(
  state : DocxLoweringState,
  blocks : Array[@core.CoreBlock],
  source_key : @ddocx.DocxSourceKey,
  prefix? : String = "",
) -> @core.CoreBlock? {
  let rich : Array[@core.CoreInline] = []
  let plain = StringBuilder::new()
  let source_ref = docx_source_ref_from_key(state, source_key, None, None)
  let mut saw_content = false
  let mut is_first = true

  fn append_text(
    plain : StringBuilder,
    rich : Array[@core.CoreInline],
    text : String,
    source_ref : @core.SourceRef,
  ) -> Unit {
    if text == "" {
      return
    }
    plain.write_string(text)
    rich.push(@core.make_inline_text(text, source_ref~))
  }

  fn append_break(
    plain : StringBuilder,
    rich : Array[@core.CoreInline],
    source_ref : @core.SourceRef,
  ) -> Unit {
    plain.write_string("\n")
    rich.push(@core.make_inline_line_break(source_ref~))
  }

  fn append_separator(
    plain : StringBuilder,
    rich : Array[@core.CoreInline],
    source_ref : @core.SourceRef,
  ) -> Unit {
    if rich.length() > 0 {
      append_break(plain, rich, source_ref)
    }
  }

  if prefix != "" {
    append_text(plain, rich, prefix, source_ref)
    saw_content = true
    is_first = true
  }

  for block in blocks {
    match block.kind {
      @core.BlockKind::Paragraph
      | @core.BlockKind::Heading
      | @core.BlockKind::ListItem => {
        if saw_content && !is_first {
          append_separator(plain, rich, block.source_ref.unwrap_or(source_ref))
        }
        let trimmed_text = block.text.trim().to_owned()
        if docx_block_has_rich_inlines(block) {
          let inlines = block.rich_inlines.unwrap_or([])
          if trimmed_text == "" &&
            inlines.length() > 0 &&
            docx_all_rich_inlines_are_breaks(inlines) {
            continue
          }
          if trimmed_text == "" && inlines.length() > 0 {
            let filtered = docx_trim_boundary_line_breaks(inlines)
            if filtered.length() == 0 {
              continue
            }
            rich.append(filtered[:])
          } else {
            let filtered = if prefix != "" && is_first {
              docx_trim_leading_line_breaks(inlines)
            } else {
              inlines
            }
            if filtered.length() == 0 {
              continue
            }
            rich.append(filtered[:])
          }
          plain.write_string(block.text)
        } else {
          if trimmed_text == "" {
            continue
          }
          append_text(
            plain,
            rich,
            block.text,
            block.source_ref.unwrap_or(source_ref),
          )
        }
        saw_content = true
        is_first = false
      }
      @core.BlockKind::List => {
        let flattened = docx_flatten_blocks_to_paragraph_like(
          state,
          block.children,
          source_key,
        )
        match flattened {
          Some(value) => {
            if saw_content && !is_first {
              append_separator(
                plain,
                rich,
                value.source_ref.unwrap_or(source_ref),
              )
            }
            if docx_block_has_rich_inlines(value) {
              rich.append(value.rich_inlines.unwrap_or([])[:])
              plain.write_string(value.text)
            } else {
              append_text(
                plain,
                rich,
                value.text,
                value.source_ref.unwrap_or(source_ref),
              )
            }
            saw_content = true
            is_first = false
          }
          None => ()
        }
      }
      _ => ()
    }
  }

  if !saw_content {
    return None
  }
  let text = normalize_docx_ref_marker_spacing(plain.to_string())
  let block0 = @core.make_block(@core.BlockKind::Paragraph, text, source_ref~)
  if rich.length() == 0 {
    Some(block0)
  } else {
    Some(@core.block_with_rich_inlines(block0, Some(rich)))
  }
}

///|
fn docx_block_has_rich_inlines(block : @core.CoreBlock) -> Bool {
  match block.rich_inlines {
    Some(inlines) => inlines.length() > 0
    None => false
  }
}

///|
fn docx_all_rich_inlines_are_breaks(inlines : Array[@core.CoreInline]) -> Bool {
  if inlines.length() == 0 {
    return false
  }
  for inline in inlines {
    if inline.kind != @core.InlineKind::LineBreak {
      return false
    }
  }
  true
}

///|
fn docx_trim_boundary_line_breaks(
  inlines : Array[@core.CoreInline],
) -> Array[@core.CoreInline] {
  let start = docx_first_non_break_inline_index(inlines)
  let end = docx_last_non_break_inline_index(inlines)
  let start_index = match start {
    Some(value) => value
    None => return []
  }
  let end_index = match end {
    Some(value) => value
    None => return []
  }
  if start_index > end_index {
    return []
  }
  let trimmed : Array[@core.CoreInline] = []
  let stop = end_index + 1
  for i in start_index..<stop {
    trimmed.push(inlines[i])
  }
  trimmed
}

///|
fn docx_trim_leading_line_breaks(
  inlines : Array[@core.CoreInline],
) -> Array[@core.CoreInline] {
  let start = docx_first_non_break_inline_index(inlines)
  let start_index = match start {
    Some(value) => value
    None => return []
  }
  let trimmed : Array[@core.CoreInline] = []
  for i in start_index..<inlines.length() {
    trimmed.push(inlines[i])
  }
  trimmed
}

///|
fn docx_first_non_break_inline_index(inlines : Array[@core.CoreInline]) -> Int? {
  for i in 0..<inlines.length() {
    if inlines[i].kind != @core.InlineKind::LineBreak {
      return Some(i)
    }
  }
  None
}

///|
fn docx_last_non_break_inline_index(inlines : Array[@core.CoreInline]) -> Int? {
  let mut i = inlines.length() - 1
  while i >= 0 {
    if inlines[i].kind != @core.InlineKind::LineBreak {
      return Some(i)
    }
    if i == 0 {
      break
    }
    i -= 1
  }
  None
}

///|
fn collect_docx_reference_ids(
  blocks : Array[@ddocx.DocxBlock],
  footnote_ids : Array[String],
  endnote_ids : Array[String],
  comment_ids : Array[String],
) -> Unit {
  for block in blocks {
    match block {
      @ddocx.DocxBlock::Paragraph(p) =>
        collect_docx_inline_reference_ids(
          p.inlines,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
      @ddocx.DocxBlock::Table(table) =>
        for row in table.rows {
          for cell in row.cells {
            collect_docx_reference_ids(
              cell.blocks,
              footnote_ids,
              endnote_ids,
              comment_ids,
            )
          }
        }
      @ddocx.DocxBlock::ContentControl(control) => {
        collect_docx_reference_ids(
          control.blocks,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
        collect_docx_inline_reference_ids(
          control.inlines,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
      }
      _ => ()
    }
  }
}

///|
fn collect_docx_inline_reference_ids(
  inlines : Array[@ddocx.DocxInline],
  footnote_ids : Array[String],
  endnote_ids : Array[String],
  comment_ids : Array[String],
) -> Unit {
  for inline in inlines {
    match inline {
      @ddocx.DocxInline::FootnoteRef(id) => push_unique_string(footnote_ids, id)
      @ddocx.DocxInline::EndnoteRef(id) => push_unique_string(endnote_ids, id)
      @ddocx.DocxInline::CommentRef(id) => push_unique_string(comment_ids, id)
      @ddocx.DocxInline::Drawing(drawing) =>
        collect_docx_inline_reference_ids(
          drawing.child_inlines,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
      @ddocx.DocxInline::Shape(shape) =>
        collect_docx_inline_reference_ids(
          shape.child_inlines,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
      @ddocx.DocxInline::ContentControl(control) => {
        collect_docx_reference_ids(
          control.blocks,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
        collect_docx_inline_reference_ids(
          control.inlines,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
      }
      @ddocx.DocxInline::FieldUnsupported(field) =>
        collect_docx_inline_reference_ids(
          field.child_inlines,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
      @ddocx.DocxInline::Math(math) =>
        collect_docx_inline_reference_ids(
          math.child_inlines,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
      @ddocx.DocxInline::TrackedChange(change) =>
        collect_docx_inline_reference_ids(
          change.child_inlines,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
      @ddocx.DocxInline::SmartTag(smart_tag) =>
        collect_docx_inline_reference_ids(
          smart_tag.child_inlines,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
      _ => ()
    }
  }
}
