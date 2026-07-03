///|
fn lower_docx_document_ir(
  source : @input.InputSource,
  docx : @ddocx.DocxDocument,
  pkg : @ox.OoxmlPackage,
  diagnostics : @core.Diagnostics,
  fidelity_mode : @product.FidelityMode,
) -> @core.DocumentIR {
  let document = @core.empty_document_ir()
  fill_docx_metadata(document.metadata, docx)
  let state = new_docx_lowering_state(
    source, docx, pkg, document, diagnostics, fidelity_mode,
  )
  lower_docx_blocks(state, document.blocks, docx.body)
  append_docx_comments_blocks(state, document.blocks)
  append_docx_part_body_blocks(
    state,
    document.blocks,
    docx.headers,
    "Headers",
    "Header",
  )
  append_docx_part_body_blocks(
    state,
    document.blocks,
    docx.footers,
    "Footers",
    "Footer",
  )
  append_docx_textboxes_blocks(state, document.blocks)
  append_docx_note_definitions_blocks(state, document.blocks)
  @core.document_with_assets(document, state.assets)
}

///|
priv struct DocxLoweringState {
  source : @input.InputSource
  docx : @ddocx.DocxDocument
  diagnostics : @core.Diagnostics
  fidelity_mode : @product.FidelityMode
  assets : Array[@core.AssetRef]
  asset_ids : Map[String, String]
  footnote_labels : Map[String, String]
  endnote_labels : Map[String, String]
  comment_labels : Map[String, String]
  footnotes_by_id : Map[String, @ddocx.DocxNote]
  endnotes_by_id : Map[String, @ddocx.DocxNote]
  comments_by_id : Map[String, @ddocx.DocxComment]
  consumed_textbox_anchors : Map[String, Bool]
  expanding_textbox_anchors : Array[String]
}

///|
priv struct DocxListTree {
  ordered : Bool
  items : Array[@core.CoreBlock]
}

///|
priv struct DocxInlineLowering {
  rich_inlines : Array[@core.CoreInline]
  plain_text : String
  has_link : Bool
  image_count : Int
  hyperlink_count : Int
  tracked_change_count : Int
}

///|
fn metric_int(diagnostics : @core.Diagnostics, key : String) -> Int {
  @string.parse_int(diagnostics.metrics.get(key).unwrap_or("0")) catch {
    _ => 0
  }
}

///|
fn new_docx_lowering_state(
  source : @input.InputSource,
  docx : @ddocx.DocxDocument,
  _pkg : @ox.OoxmlPackage,
  _document : @core.DocumentIR,
  diagnostics : @core.Diagnostics,
  fidelity_mode : @product.FidelityMode,
) -> DocxLoweringState {
  let footnote_labels : Map[String, String] = Map([])
  let endnote_labels : Map[String, String] = Map([])
  let comment_labels : Map[String, String] = Map([])
  let assets : Array[@core.AssetRef] = []
  let asset_ids : Map[String, String] = Map([])
  let footnotes_by_id : Map[String, @ddocx.DocxNote] = Map([])
  let endnotes_by_id : Map[String, @ddocx.DocxNote] = Map([])
  let comments_by_id : Map[String, @ddocx.DocxComment] = Map([])
  let consumed_textbox_anchors : Map[String, Bool] = Map([])
  let expanding_textbox_anchors : Array[String] = []

  for note in docx.footnotes {
    if !footnotes_by_id.contains(note.note_id) {
      footnotes_by_id.set(note.note_id, note)
    }
  }
  for note in docx.endnotes {
    if !endnotes_by_id.contains(note.note_id) {
      endnotes_by_id.set(note.note_id, note)
    }
  }
  for comment in docx.comments {
    if !comments_by_id.contains(comment.comment_id) {
      comments_by_id.set(comment.comment_id, comment)
    }
  }

  let footnote_ids : Array[String] = []
  let endnote_ids : Array[String] = []
  let comment_ids : Array[String] = []
  collect_docx_reference_ids(docx.body, footnote_ids, endnote_ids, comment_ids)
  let mut idx = 1
  for id in footnote_ids {
    if !footnote_labels.contains(id) && footnotes_by_id.contains(id) {
      footnote_labels.set(id, idx.to_string())
      idx += 1
    }
  }
  idx = 1
  for id in endnote_ids {
    if !endnote_labels.contains(id) && endnotes_by_id.contains(id) {
      endnote_labels.set(id, idx.to_string())
      idx += 1
    }
  }
  idx = 1
  for id in comment_ids {
    if !comment_labels.contains(id) && comments_by_id.contains(id) {
      comment_labels.set(id, idx.to_string())
      idx += 1
    }
  }
  {
    source,
    docx,
    diagnostics,
    fidelity_mode,
    assets,
    asset_ids,
    footnote_labels,
    endnote_labels,
    comment_labels,
    footnotes_by_id,
    endnotes_by_id,
    comments_by_id,
    consumed_textbox_anchors,
    expanding_textbox_anchors,
  }
}

///|
fn fill_docx_package_metrics(
  diagnostics : @core.Diagnostics,
  pkg : @ox.OoxmlPackage,
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
    "content_type_count",
    inventory.content_type_entry_count.to_string(),
  )
  let media_asset_count = count_docx_media_parts(inventory.parts)
  diagnostics.metrics.set("media_asset_count", media_asset_count.to_string())
  let mut total_uncompressed_bytes = 0
  let mut path_traversal_count = 0
  let mut duplicate_part_count = 0
  let encrypted_entry_count = 0
  let unsupported_compression_count = 0
  for part in inventory.parts {
    total_uncompressed_bytes += part.size
  }
  for issue in validation.issues {
    let message = issue.message.trim().to_owned()
    if message.contains("unsafe relationship target") ||
      message.contains("path traversal") {
      path_traversal_count += 1
    }
    if message.contains("duplicate") {
      duplicate_part_count += 1
    }
  }
  diagnostics.metrics.set(
    "total_uncompressed_bytes",
    total_uncompressed_bytes.to_string(),
  )
  diagnostics.metrics.set(
    "path_traversal_count",
    path_traversal_count.to_string(),
  )
  diagnostics.metrics.set(
    "duplicate_part_count",
    duplicate_part_count.to_string(),
  )
  diagnostics.metrics.set(
    "encrypted_entry_count",
    encrypted_entry_count.to_string(),
  )
  diagnostics.metrics.set(
    "unsupported_compression_count",
    unsupported_compression_count.to_string(),
  )
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("xml_dtd_count", "0")
  diagnostics.metrics.set("xml_external_entity_count", "0")
  diagnostics.metrics.set(
    "macro_part_count",
    count_docx_macro_parts(inventory.parts).to_string(),
  )
  diagnostics.metrics.set(
    "ole_object_count",
    count_docx_ole_object_parts(inventory.parts).to_string(),
  )
  diagnostics.metrics.set("alt_chunk_count", "0")
}

///|
fn count_docx_media_parts(parts : Array[@ox.OoxmlPartInfo]) -> Int {
  let mut count = 0
  for part in parts {
    if part.part_name.has_prefix("word/media/") &&
      !part.part_name.has_suffix("/") {
      count += 1
    }
  }
  count
}

///|
fn fill_docx_metadata(
  metadata : @core.DocumentMetadata,
  docx : @ddocx.DocxDocument,
) -> Unit {
  let core = docx.metadata.core
  let app = docx.metadata.app
  set_document_metadata_string(metadata, "title", core.title)
  set_document_metadata_string(metadata, "subject", core.subject)
  set_document_metadata_string(metadata, "creator", core.creator)
  set_document_metadata_string(
    metadata,
    "last_modified_by",
    core.last_modified_by,
  )
  set_document_metadata_string(metadata, "created", core.created)
  set_document_metadata_string(metadata, "modified", core.modified)
  set_document_metadata_string(metadata, "keywords", core.keywords)
  set_document_metadata_string(metadata, "description", core.description)
  set_document_metadata_string(metadata, "category", core.category)
  set_document_metadata_string(metadata, "company", app.company)
  set_document_metadata_string(metadata, "manager", app.manager)
  set_document_metadata_string(metadata, "application", app.application)
  set_document_metadata_string(metadata, "pages", app.pages)
  set_document_metadata_string(metadata, "words", app.words)
  set_document_metadata_string(metadata, "slides", app.slides)
  set_document_metadata_string(metadata, "sheets", app.sheets)
  if docx.metadata.custom_properties.length() > 0 {
    let entries : Map[String, @core.JsonValue] = Map([])
    for prop in docx.metadata.custom_properties {
      entries.set(prop.name, @core.JsonValue::String(prop.value))
    }
    metadata.set("custom_properties", @core.JsonValue::Object(entries))
  }
}

///|
fn set_document_metadata_string(
  metadata : @core.DocumentMetadata,
  key : String,
  value : String?,
) -> Unit {
  match value {
    Some(text) =>
      if text.trim() != "" {
        metadata.set(key, @core.JsonValue::String(text))
      }
    None => ()
  }
}

///|
fn lower_docx_blocks(
  state : DocxLoweringState,
  out : Array[@core.CoreBlock],
  blocks : Array[@ddocx.DocxBlock],
) -> Unit {
  let list_stack : Array[DocxListTree] = []

  fn flush_lists(
    out : Array[@core.CoreBlock],
    list_stack : Array[DocxListTree],
    min_depth : Int,
  ) -> Unit {
    while list_stack.length() > min_depth {
      let current = list_stack.pop().unwrap()
      let list_block = @core.make_block(
        @core.BlockKind::List,
        "",
        source_ref=current.items[0].source_ref.unwrap_or(
          @core.empty_source_ref(),
        ),
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

  for block in blocks {
    match block {
      @ddocx.DocxBlock::Paragraph(p) =>
        match lower_docx_paragraph_block(state, p) {
          Some(lowered) =>
            if lowered.kind == @core.BlockKind::ListItem {
              let ordered = lowered.attrs.get("ordered").unwrap_or("false") ==
                "true"
              let level = @string.parse_int(
                lowered.attrs.get("level").unwrap_or("0"),
              ) catch {
                _ => 0
              }
              let target_depth = level + 1
              flush_lists(out, list_stack, target_depth)
              if list_stack.length() == target_depth &&
                target_depth > 0 &&
                list_stack[target_depth - 1].ordered != ordered {
                flush_lists(out, list_stack, target_depth - 1)
              }
              while list_stack.length() < target_depth {
                list_stack.push({ ordered, items: [] })
              }
              if list_stack.length() > 0 {
                list_stack[list_stack.length() - 1].items.push(lowered)
              }
            } else {
              flush_lists(out, list_stack, 0)
              out.push(lowered)
            }
          None => ()
        }
      @ddocx.DocxBlock::Table(table) => {
        flush_lists(out, list_stack, 0)
        let lowered = lower_docx_table_block(state, table)
        if docx_rendered_table_has_visible_cells(lowered) {
          out.push(lowered)
        }
      }
      @ddocx.DocxBlock::TablePlaceholder(placeholder) => {
        flush_lists(out, list_stack, 0)
        let placeholder_ref = docx_source_ref_from_key(
          state,
          placeholder.source_key,
          None,
          None,
        )
        let raw = @core.make_block(
          @core.BlockKind::Raw,
          "[Unsupported DOCX table omitted]",
          source_ref=placeholder_ref,
        )
        raw.attrs.set("raw_kind", "docx_table_placeholder")
        out.push(raw)
      }
      @ddocx.DocxBlock::ContentControl(control) => {
        flush_lists(out, list_stack, 0)
        if control.blocks.length() > 0 {
          lower_docx_blocks(state, out, control.blocks)
        } else {
          let inline = lower_docx_inlines(
            state,
            control.inlines,
            control.source_key,
          )
          if inline.rich_inlines.length() > 0 || inline.plain_text.trim() != "" {
            let paragraph0 = @core.make_block(
              @core.BlockKind::Paragraph,
              inline.plain_text,
              source_ref=docx_source_ref_from_key(
                state,
                control.source_key,
                None,
                None,
              ),
            )
            let paragraph = if inline.rich_inlines.length() > 0 {
              @core.block_with_rich_inlines(
                paragraph0,
                Some(inline.rich_inlines),
              )
            } else {
              paragraph0
            }
            out.push(paragraph)
          }
        }
      }
      @ddocx.DocxBlock::StructuralMarker(_) => ()
      @ddocx.DocxBlock::Unsupported(warning) => {
        flush_lists(out, list_stack, 0)
        let source_ref = match warning.source_key {
          Some(key) => Some(docx_source_ref_from_key(state, key, None, None))
          None => Some(@core.empty_source_ref())
        }
        let raw = @core.make_block(
          @core.BlockKind::Raw,
          "[Unsupported DOCX node: " + warning.message + "]",
          source_ref=source_ref.unwrap_or(@core.empty_source_ref()),
        )
        raw.attrs.set("raw_kind", "docx_unsupported")
        out.push(raw)
      }
    }
  }
  flush_lists(out, list_stack, 0)
}

///|
fn lower_docx_paragraph_block(
  state : DocxLoweringState,
  p : @ddocx.DocxParagraph,
) -> @core.CoreBlock? {
  if docx_paragraph_is_page_number_field_only(p) {
    return None
  }
  let inline = lower_docx_inlines(state, p.inlines, p.source_key)
  let source_ref = docx_source_ref_from_key(state, p.source_key, None, None)
  if inline.tracked_change_count > 0 {
    let current = metric_int(state.diagnostics, "docx_tracked_change_count")
    state.diagnostics.metrics.set(
      "docx_tracked_change_count",
      (current + inline.tracked_change_count).to_string(),
    )
  }
  if inline.rich_inlines.length() == 0 && inline.plain_text.trim() == "" {
    return None
  }
  if docx_paragraph_is_image_only(inline) {
    return Some(lower_docx_image_only_paragraph(state, p, inline, source_ref))
  }
  let resolved_style = @ddocx.docx_resolve_paragraph_style(state.docx, p)
  match docx_paragraph_heading_level(resolved_style, p) {
    Some(level) => {
      let heading0 = @core.make_block(
        @core.BlockKind::Heading,
        inline.plain_text.trim().to_owned(),
        source_ref~,
      )
      let heading = if inline.rich_inlines.length() > 0 {
        @core.block_with_rich_inlines(heading0, Some(inline.rich_inlines))
      } else {
        heading0
      }
      heading.attrs.set("level", level.to_string())
      bump_metric(state.diagnostics, "docx_heading_count")
      return Some(heading)
    }
    None => ()
  }
  match docx_paragraph_list_lowering(state.docx, p) {
    Some((ordered, level)) => {
      let item0 = @core.make_block(
        @core.BlockKind::ListItem,
        docx_list_item_text(inline.plain_text),
        source_ref~,
      )
      let item = if inline.rich_inlines.length() > 0 {
        @core.block_with_rich_inlines(item0, Some(inline.rich_inlines))
      } else {
        item0
      }
      item.attrs.set("ordered", @fshared.bool_string(ordered))
      if ordered {
        item.attrs.set("stable_ordered_marker", "true")
      }
      item.attrs.set("level", level.to_string())
      bump_metric(state.diagnostics, "docx_list_count")
      return Some(item)
    }
    None => ()
  }
  if docx_paragraph_is_code_style(resolved_style, p, inline.plain_text) {
    let code = @core.make_block(
      @core.BlockKind::Code,
      inline.plain_text,
      source_ref~,
    )
    return Some(code)
  }
  if docx_paragraph_is_quote_style(resolved_style, p) {
    let quote0 = @core.make_block(
      @core.BlockKind::BlockQuote,
      inline.plain_text,
      source_ref~,
    )
    let quote = if inline.rich_inlines.length() > 0 {
      @core.block_with_rich_inlines(quote0, Some(inline.rich_inlines))
    } else {
      quote0
    }
    return Some(quote)
  }
  let paragraph0 = @core.make_block(
    @core.BlockKind::Paragraph,
    inline.plain_text,
    source_ref~,
  )
  let paragraph = if inline.rich_inlines.length() > 0 {
    @core.block_with_rich_inlines(paragraph0, Some(inline.rich_inlines))
  } else {
    paragraph0
  }
  if inline.image_count > 0 {
    paragraph.attrs.set("contains_inline_image_placeholder", "true")
  }
  bump_metric(state.diagnostics, "docx_paragraph_count")
  Some(paragraph)
}

///|
fn lower_docx_table_block(
  state : DocxLoweringState,
  table : @ddocx.DocxTable,
) -> @core.CoreBlock {
  let source_ref = docx_source_ref_from_key(state, table.source_key, None, None)
  let block = @core.make_block(@core.BlockKind::Table, "table", source_ref~)
  block.attrs.set("header_rows", docx_table_header_rows(table).to_string())
  block.attrs.set(
    "table_column_count",
    docx_table_column_count(table).to_string(),
  )
  for row in table.rows {
    let row_ref = docx_source_ref_from_key(state, row.source_key, None, None)
    let row_block = @core.make_block(
      @core.BlockKind::TableRow,
      "",
      source_ref=row_ref,
    )
    for cell in row.cells {
      let cell_ref = docx_source_ref_from_key(
        state,
        cell.source_key,
        None,
        None,
      )
      let (cell_text, cell_rich) = docx_table_cell_content(state, cell)
      let cell_block0 = @core.make_block(
        @core.BlockKind::TableCell,
        cell_text,
        source_ref=cell_ref,
      )
      let cell_block = if cell_rich.length() > 0 {
        @core.block_with_rich_inlines(cell_block0, Some(cell_rich))
      } else {
        cell_block0
      }
      row_block.children.push(cell_block)
    }
    block.children.push(row_block)
  }
  bump_metric(state.diagnostics, "docx_table_count")
  block
}

///|
fn docx_table_cell_grid_span(cell : @ddocx.DocxTableCell) -> Int {
  match cell.grid_span {
    Some(raw) =>
      match docx_parse_nonnegative_int(raw) {
        Some(span) => if span < 1 { 1 } else { span }
        None => 1
      }
    None => 1
  }
}

///|
fn docx_table_column_count(table : @ddocx.DocxTable) -> Int {
  let mut width = 0
  for row in table.rows {
    let mut row_width = 0
    for cell in row.cells {
      row_width += docx_table_cell_grid_span(cell)
    }
    if row_width > width {
      width = row_width
    }
  }
  width
}

///|
fn docx_table_header_rows(table : @ddocx.DocxTable) -> Int {
  if table.rows.length() > 0 {
    1
  } else {
    0
  }
}

///|
fn docx_table_cell_content(
  state : DocxLoweringState,
  cell : @ddocx.DocxTableCell,
) -> (String, Array[@core.CoreInline]) {
  let parts : Array[String] = []
  let rich : Array[@core.CoreInline] = []
  let mut first = true

  fn append_text(
    rich : Array[@core.CoreInline],
    text : String,
    source_ref : @core.SourceRef,
  ) -> Unit {
    if text == "" {
      return
    }
    rich.push(@core.make_inline_text(text, source_ref~))
  }

  fn append_break(
    parts : Array[String],
    rich : Array[@core.CoreInline],
    source_ref : @core.SourceRef,
  ) -> Unit {
    parts.push("<br>")
    rich.push(@core.make_inline_line_break(source_ref~))
  }

  for block in cell.blocks {
    match block {
      @ddocx.DocxBlock::Paragraph(p) => {
        let lowered = lower_docx_inlines(state, p.inlines, p.source_key)
        let normalized = docx_table_cell_block_text(lowered.plain_text, p)
        if normalized == "" {
          continue
        }
        let source_ref = docx_source_ref_from_key(
          state,
          p.source_key,
          None,
          None,
        )
        if !first {
          append_break(parts, rich, source_ref)
        }
        parts.push(normalized)
        if lowered.rich_inlines.length() > 0 {
          let cell_inlines : Array[@core.CoreInline] = []
          for inline in lowered.rich_inlines {
            if inline.kind == @core.InlineKind::Image {
              cell_inlines.push(
                @core.make_inline_text(
                  inline.text,
                  source_ref=inline.source_ref.unwrap_or(source_ref),
                ),
              )
            } else {
              cell_inlines.push(inline)
            }
          }
          rich.append(cell_inlines[:])
        } else {
          append_text(rich, normalized, source_ref)
        }
        first = false
      }
      @ddocx.DocxBlock::Table(table) => {
        let nested = lower_docx_table_block(state, table)
        let rendered = nested.children
          .map(row => row.children.map(cell => cell.text).join(" | "))
          .join("\n")
        if rendered == "" {
          continue
        }
        let source_ref = nested.source_ref.unwrap_or(@core.empty_source_ref())
        if !first {
          append_break(parts, rich, source_ref)
        }
        parts.push(rendered)
        append_text(rich, rendered, source_ref)
        first = false
      }
      @ddocx.DocxBlock::ContentControl(control) => {
        let lowered = lower_docx_inlines(
          state,
          control.inlines,
          control.source_key,
        )
        let text = if lowered.plain_text.trim() != "" {
          normalize_docx_table_text(lowered.plain_text)
        } else {
          normalize_docx_table_text(control.text)
        }
        if text == "" {
          continue
        }
        let source_ref = docx_source_ref_from_key(
          state,
          control.source_key,
          None,
          None,
        )
        if !first {
          append_break(parts, rich, source_ref)
        }
        parts.push(text)
        if lowered.rich_inlines.length() > 0 {
          rich.append(lowered.rich_inlines[:])
        } else {
          append_text(rich, text, source_ref)
        }
        first = false
      }
      @ddocx.DocxBlock::TablePlaceholder(_) => {
        let text = "[Unsupported DOCX nested table depth limit]"
        if !first {
          append_break(parts, rich, @core.empty_source_ref())
        }
        parts.push(text)
        append_text(rich, text, @core.empty_source_ref())
        first = false
      }
      @ddocx.DocxBlock::Unsupported(_) => {
        let text = "[Unsupported DOCX inline]"
        if !first {
          append_break(parts, rich, @core.empty_source_ref())
        }
        parts.push(text)
        append_text(rich, text, @core.empty_source_ref())
        first = false
      }
      @ddocx.DocxBlock::StructuralMarker(_) => ()
    }
  }
  (parts.join(""), rich)
}

///|
fn docx_table_cell_block_text(
  text : String,
  p : @ddocx.DocxParagraph,
) -> String {
  match docx_paragraph_list_lowering_in_cell(p) {
    Some((ordered, _level)) =>
      if ordered {
        normalize_docx_table_text(text)
      } else {
        normalize_docx_table_text(text)
      }
    None => normalize_docx_table_text(text)
  }
}

///|
fn normalize_docx_table_text(text : String) -> String {
  text
  .replace(old="\r\n", new="\n")
  .replace(old="\r", new="\n")
  .split("\n")
  .map(fn(line) { line.trim().to_owned() })
  .filter(fn(line) { line != "" })
  .iter()
  .collect()
  .join("<br>")
}

///|
fn docx_paragraph_list_lowering_in_cell(
  p : @ddocx.DocxParagraph,
) -> (Bool, Int)? {
  match p.numbering_ref {
    Some(numbering_ref) =>
      match numbering_ref.ilvl {
        Some(ilvl) =>
          if ilvl.trim() == "" {
            Some((false, 0))
          } else {
            Some((false, @string.parse_int(ilvl.trim()) catch { _ => 0 }))
          }
        None => Some((false, 0))
      }
    None => None
  }
}

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
    if state.fidelity_mode != @product.FidelityMode::Accurate {
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

///|
fn append_docx_comments_blocks(
  state : DocxLoweringState,
  out : Array[@core.CoreBlock],
) -> Unit {
  if state.comment_labels.length() == 0 {
    return
  }
  let comment_ids = docx_note_ids_sorted_by_label(state.comment_labels)
  if comment_ids.length() == 0 {
    return
  }
  let heading = @core.make_block(
    @core.BlockKind::Heading,
    "Comments",
    source_ref=docx_part_source_ref(state, "word/comments.xml", None),
  )
  heading.attrs.set("level", "2")
  out.push(heading)
  for id in comment_ids {
    match docx_lookup_comment(state, id) {
      Some(comment) => {
        let prefix = docx_comment_author_prefix(comment.author)
        let blocks : Array[@core.CoreBlock] = []
        lower_docx_blocks(state, blocks, comment.blocks)
        if blocks.length() == 0 {
          continue
        }
        let inline_images = docx_collect_comment_inline_images(blocks)
        match
          docx_flatten_blocks_to_paragraph_like(
            state,
            blocks,
            comment.source_key,
            prefix~,
          ) {
          Some(item) => {
            let item = docx_comment_block_without_inline_images(item)
            let list_item0 = @core.make_block(
              @core.BlockKind::ListItem,
              item.text,
              source_ref=item.source_ref.unwrap_or(@core.empty_source_ref()),
            )
            let list_item = @core.block_with_rich_inlines(
              list_item0,
              item.rich_inlines,
            )
            list_item.attrs.set("ordered", "true")
            list_item.attrs.set("level", "0")
            list_item.attrs.set("stable_ordered_marker", "true")
            out.push(list_item)
            out.append(inline_images[:])
          }
          None => {
            let first = blocks[0]
            match first.kind {
              @core.BlockKind::Paragraph => {
                let first = docx_comment_block_without_inline_images(first)
                let item0 = @core.make_block(
                  @core.BlockKind::ListItem,
                  prefix + first.text,
                  source_ref=first.source_ref.unwrap_or(
                    @core.empty_source_ref(),
                  ),
                )
                let item = match first.rich_inlines {
                  Some(inlines) =>
                    @core.block_with_rich_inlines(
                      item0,
                      Some(docx_prefixed_rich_inlines(prefix, inlines)),
                    )
                  None => item0
                }
                item.attrs.set("ordered", "true")
                item.attrs.set("level", "0")
                item.attrs.set("stable_ordered_marker", "true")
                out.push(item)
                for i in 1..<blocks.length() {
                  out.push(docx_comment_block_without_inline_images(blocks[i]))
                }
                out.append(inline_images[:])
              }
              _ => {
                let item = @core.make_block(
                  @core.BlockKind::ListItem,
                  prefix.trim().to_owned(),
                  source_ref=docx_source_ref_from_key(
                    state,
                    comment.source_key,
                    None,
                    None,
                  ),
                )
                item.attrs.set("ordered", "true")
                item.attrs.set("level", "0")
                item.attrs.set("stable_ordered_marker", "true")
                out.push(item)
                for block in blocks {
                  out.push(docx_comment_block_without_inline_images(block))
                }
                out.append(inline_images[:])
              }
            }
          }
        }
      }
      None => ()
    }
  }
}
