///|
fn render_markdown_events(events : Array[@core.CoreEvent]) -> String {
  if events.length() == 0 {
    return ""
  }
  let out = StringBuilder::new()
  if generic_block_event_stream(events) {
    write_markdown_generic_block_events_direct_to(out, events)
    return out.to_string()
  }
  if events[0].kind == @core.EventKind::TextLine ||
    events[0].kind == @core.EventKind::BlankLine {
    write_markdown_line_events_to(out, events)
    return out.to_string()
  }
  if event_stream_contains_table_rows(events) {
    write_markdown_mixed_table_events_to(out, events)
    return out.to_string()
  }
  write_markdown_generic_events_to(out, events)
  out.to_string()
}

///|
fn write_markdown_line_events_to(
  out : StringBuilder,
  events : Array[@core.CoreEvent],
) -> Unit {
  let current_lines : Array[String] = []
  let mut wrote_paragraph = false
  for event in events {
    match event.kind {
      @core.EventKind::TextLine =>
        current_lines.push(event.text.trim().to_owned())
      @core.EventKind::BlankLine =>
        wrote_paragraph = write_markdown_line_paragraph_to(
          out, current_lines, wrote_paragraph,
        )
      @core.EventKind::StartBlock(_) | @core.EventKind::EndBlock(_) => {
        wrote_paragraph = write_markdown_line_paragraph_to(
          out, current_lines, wrote_paragraph,
        )
        if markdown_generic_event_visible(event) {
          if wrote_paragraph {
            out.write_char('\n')
            out.write_char('\n')
          }
          write_markdown_generic_event_to(out, event)
          wrote_paragraph = true
        }
      }
      _ => ()
    }
  }
  ignore(write_markdown_line_paragraph_to(out, current_lines, wrote_paragraph))
}

///|
fn write_markdown_line_paragraph_to(
  out : StringBuilder,
  current_lines : Array[String],
  wrote_paragraph : Bool,
) -> Bool {
  if current_lines.length() == 0 {
    return wrote_paragraph
  }
  if wrote_paragraph {
    out.write_char('\n')
    out.write_char('\n')
  }
  for index in 0..<current_lines.length() {
    if index > 0 {
      out.write_char(' ')
    }
    write_escaped_markdown_inline_text_to(out, current_lines[index])
  }
  current_lines.clear()
  true
}

///|
fn write_markdown_simple_table_events_to(
  out : StringBuilder,
  events : Array[@core.CoreEvent],
) -> Bool {
  let rows : Array[Array[String]] = []
  let current_row : Array[String] = []
  for event in events {
    match event.kind {
      @core.EventKind::Cell => current_row.push(event.text)
      @core.EventKind::RowBreak =>
        if current_row.length() > 0 {
          rows.push(current_row.copy())
          current_row.clear()
        }
      _ => ()
    }
  }
  if current_row.length() > 0 {
    rows.push(current_row.copy())
  }
  if rows.length() == 0 {
    return false
  }
  let width = widest_event_row_width(rows)
  if width == 0 {
    return false
  }
  write_markdown_table_row_from_values(out, rows[0], width)
  out.write_char('\n')
  write_markdown_table_separator(out, width)
  for i in 1..<rows.length() {
    out.write_char('\n')
    write_markdown_table_row_from_values(out, rows[i], width)
  }
  true
}

///|
fn write_markdown_mixed_table_events_to(
  out : StringBuilder,
  events : Array[@core.CoreEvent],
) -> Unit {
  let table_events : Array[@core.CoreEvent] = []
  let generic_events : Array[@core.CoreEvent] = []
  let mut in_generic_tail = false
  for event in events {
    if !in_generic_tail &&
      (
        event.kind == @core.EventKind::Cell ||
        event.kind == @core.EventKind::RowBreak
      ) {
      table_events.push(event)
    } else {
      in_generic_tail = true
      generic_events.push(event)
    }
  }
  let wrote_table = write_markdown_simple_table_events_to(out, table_events)
  let wrote_generic = markdown_generic_events_visible(generic_events)
  if wrote_table && wrote_generic {
    out.write_char('\n')
    out.write_char('\n')
  }
  if wrote_generic {
    write_markdown_generic_events_to(out, generic_events)
  }
}

///|
fn event_stream_contains_table_rows(events : Array[@core.CoreEvent]) -> Bool {
  for event in events {
    if event.kind == @core.EventKind::RowBreak {
      return true
    }
  }
  false
}

///|
fn generic_block_event_stream(events : Array[@core.CoreEvent]) -> Bool {
  if events.length() == 0 {
    return false
  }
  match events[0].source_ref {
    Some(source_ref) =>
      source_ref.extra.get("ir_event_encoding") == Some("generic_block")
    None => false
  }
}

///|
fn generic_blocks_from_events(
  events : Array[@core.CoreEvent],
) -> Array[@core.CoreBlock] {
  let cursor = { events, index: 0 }
  let blocks : Array[@core.CoreBlock] = []
  while cursor.index < cursor.events.length() {
    match parse_generic_block_event(cursor) {
      Some(block) => blocks.push(block)
      None => cursor.index += 1
    }
  }
  blocks
}

///|
fn write_markdown_generic_block_events_direct_to(
  out : StringBuilder,
  events : Array[@core.CoreEvent],
) -> Unit {
  let cursor = { events, index: 0 }
  let mut prev_kind : @core.BlockKind? = None
  let mut wrote_any = false
  while cursor.index < cursor.events.length() {
    match parse_generic_block_event(cursor) {
      Some(block) => {
        let wrote_block = write_markdown_block_with_separator_to(
          out, block, prev_kind, wrote_any,
        )
        if wrote_block {
          prev_kind = Some(block.kind)
          wrote_any = true
        }
      }
      None => cursor.index += 1
    }
  }
}

///|
priv struct GenericEventCursor {
  events : Array[@core.CoreEvent]
  mut index : Int
}

///|
fn parse_generic_block_event(cursor : GenericEventCursor) -> @core.CoreBlock? {
  if cursor.index >= cursor.events.length() {
    return None
  }
  let start = cursor.events[cursor.index]
  match start.kind {
    @core.EventKind::StartBlock(kind) => {
      let source_ref = start.source_ref.unwrap_or(@core.empty_source_ref())
      cursor.index += 1
      Some(
        collect_generic_block_event_body(cursor, kind, start.text, source_ref),
      )
    }
    _ => None
  }
}

///|
fn collect_generic_block_event_body(
  cursor : GenericEventCursor,
  kind : @core.BlockKind,
  text : String,
  source_ref : @core.SourceRef,
) -> @core.CoreBlock {
  let block = @core.make_block(
    kind,
    text,
    source_ref=strip_generic_event_ref(source_ref),
  )
  let attrs = Map([], capacity=8)
  for entry in source_ref.extra.to_array() {
    if entry.0.has_prefix("ir_block_attr_") {
      attrs.set(entry.0["ir_block_attr_".length():].to_owned(), entry.1)
    }
  }
  let inlines : Array[@core.CoreInline] = []
  let children : Array[@core.CoreBlock] = []
  let table_cells : Array[String] = []
  let table_cell_refs : Array[@core.SourceRef] = []
  while cursor.index < cursor.events.length() {
    let event = cursor.events[cursor.index]
    match event.kind {
      @core.EventKind::EndBlock(end_kind) => {
        cursor.index += 1
        if end_kind == kind {
          let rich_inlines = if inlines.length() > 0 {
            Some(inlines)
          } else {
            None
          }
          return { ..block, rich_inlines, children, attrs }
        }
      }
      @core.EventKind::StartBlock(_) =>
        match parse_generic_block_event(cursor) {
          Some(child) => children.push(child)
          None => cursor.index += 1
        }
      @core.EventKind::Text => {
        let raw_event_ref = event.source_ref.unwrap_or(source_ref)
        let event_ref = strip_generic_event_ref(raw_event_ref)
        let inline_kind = generic_inline_kind_name(
          raw_event_ref.extra.get("ir_inline_kind"),
        )
        let inline = match inline_kind {
          Some(@core.InlineKind::LineBreak) =>
            @core.make_inline_line_break(source_ref=event_ref)
          Some(@core.InlineKind::Link) =>
            @core.make_inline_link(
              event.text,
              raw_event_ref.extra.get("ir_inline_href").unwrap_or("#"),
              title=raw_event_ref.extra.get("ir_inline_title"),
              source_ref=event_ref,
            )
          Some(@core.InlineKind::Image) =>
            @core.make_inline_image(
              event.text,
              raw_event_ref.extra.get("ir_inline_href").unwrap_or("#"),
              title=raw_event_ref.extra.get("ir_inline_title"),
              source_ref=event_ref,
            )
          Some(@core.InlineKind::Code) =>
            @core.make_inline_code(event.text, source_ref=event_ref)
          _ => @core.make_inline_text(event.text, source_ref=event_ref)
        }
        for entry in raw_event_ref.extra.to_array() {
          if entry.0.has_prefix("ir_inline_attr_") {
            inline.attrs.set(
              entry.0["ir_inline_attr_".length():].to_owned(),
              entry.1,
            )
          }
        }
        inlines.push(inline)
        cursor.index += 1
      }
      @core.EventKind::Cell => {
        table_cells.push(event.text)
        table_cell_refs.push(
          strip_generic_event_ref(event.source_ref.unwrap_or(source_ref)),
        )
        cursor.index += 1
      }
      @core.EventKind::RowBreak => {
        let row_ref = strip_generic_event_ref(
          event.source_ref.unwrap_or(source_ref),
        )
        let row = @core.make_block(
          @core.BlockKind::TableRow,
          table_cells.join(" | "),
          source_ref=row_ref,
        )
        for index in 0..<table_cells.length() {
          row.children.push(
            @core.make_block(
              @core.BlockKind::TableCell,
              table_cells[index],
              source_ref=if index < table_cell_refs.length() {
                table_cell_refs[index]
              } else {
                row_ref
              },
            ),
          )
        }
        children.push(row)
        table_cells.clear()
        table_cell_refs.clear()
        cursor.index += 1
      }
      _ => cursor.index += 1
    }
  }
  block
}

///|
fn strip_generic_event_ref(source_ref : @core.SourceRef) -> @core.SourceRef {
  let next = {
    ..source_ref,
    extra: Map([], capacity=source_ref.extra.length()),
  }
  for entry in source_ref.extra.to_array() {
    if !entry.0.has_prefix("ir_") {
      next.extra.set(entry.0, entry.1)
    }
  }
  next
}

///|
fn generic_inline_kind_name(kind : String?) -> @core.InlineKind? {
  match kind {
    Some("text") => Some(@core.InlineKind::Text)
    Some("line_break") => Some(@core.InlineKind::LineBreak)
    Some("link") => Some(@core.InlineKind::Link)
    Some("image") => Some(@core.InlineKind::Image)
    Some("code") => Some(@core.InlineKind::Code)
    _ => None
  }
}

///|
fn widest_event_row_width(rows : Array[Array[String]]) -> Int {
  let mut width = 0
  for row in rows {
    if row.length() > width {
      width = row.length()
    }
  }
  width
}

///|
fn write_markdown_table_row_from_values(
  out : StringBuilder,
  row : Array[String],
  width : Int,
) -> Unit {
  out.write_string("|")
  for col in 0..<width {
    let value = if col < row.length() { row[col] } else { "" }
    out.write_char(' ')
    write_safe_markdown_table_cell_to(out, value)
    out.write_string(" |")
  }
}

///|
fn write_markdown_generic_events_to(
  out : StringBuilder,
  events : Array[@core.CoreEvent],
) -> Unit {
  let mut wrote_any = false
  for event in events {
    if !markdown_generic_event_visible(event) {
      continue
    }
    if wrote_any {
      out.write_char('\n')
      out.write_char('\n')
    }
    write_markdown_generic_event_to(out, event)
    wrote_any = true
  }
}

///|
fn markdown_generic_events_visible(events : Array[@core.CoreEvent]) -> Bool {
  for event in events {
    if markdown_generic_event_visible(event) {
      return true
    }
  }
  false
}

///|
fn markdown_generic_event_visible(event : @core.CoreEvent) -> Bool {
  match event.kind {
    @core.EventKind::StartBlock(@core.BlockKind::Code)
    | @core.EventKind::StartBlock(@core.BlockKind::Raw)
    | @core.EventKind::Text => event.text.trim() != ""
    _ => false
  }
}

///|
fn write_markdown_generic_event_to(
  out : StringBuilder,
  event : @core.CoreEvent,
) -> Unit {
  match event.kind {
    @core.EventKind::StartBlock(@core.BlockKind::Code) => {
      let code = @core.make_block(
        @core.BlockKind::Code,
        event.text,
        source_ref=event.source_ref.unwrap_or(@core.empty_source_ref()),
      )
      match event.source_ref {
        Some(source_ref) =>
          match source_ref.extra.get("ir_block_attr_info") {
            Some(info) => code.attrs.set("info", info)
            None => ()
          }
        None => ()
      }
      write_markdown_code_to(out, code)
    }
    @core.EventKind::StartBlock(@core.BlockKind::Raw) => {
      let raw = @core.make_block(
        @core.BlockKind::Raw,
        event.text,
        source_ref=event.source_ref.unwrap_or(@core.empty_source_ref()),
      )
      raw.attrs.set("raw_kind", "text")
      out.write_string(render_markdown_raw(raw))
    }
    @core.EventKind::Text =>
      write_escaped_markdown_inline_text_to(out, event.text)
    _ => ()
  }
}
