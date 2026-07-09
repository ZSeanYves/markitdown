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
