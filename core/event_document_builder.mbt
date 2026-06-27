///|
pub fn build_document_from_events(events : Array[CoreEvent]) -> DocumentIR {
  if generic_block_event_stream(events) {
    return build_document_from_generic_block_events(events)
  }
  build_document_from_simple_events(events)
}

///|
fn build_document_from_simple_events(events : Array[CoreEvent]) -> DocumentIR {
  let document = empty_document_ir()
  let text_lines : Array[CoreEvent] = []
  let current_row : Array[String] = []
  let current_row_refs : Array[SourceRef] = []
  let table_rows : Array[CoreBlock] = []
  for event in events {
    match event.kind {
      EventKind::StartBlock(kind) => {
        let block = make_block(
          kind,
          event.text,
          source_ref=event.source_ref.unwrap_or(empty_source_ref()),
        )
        if kind == BlockKind::Code {
          match event.source_ref {
            Some(source_ref) =>
              match source_ref.extra.get("ir_block_attr_info") {
                Some(info) => block.attrs.set("info", info)
                None => ()
              }
            None => ()
          }
        }
        document.blocks.push(block)
      }
      EventKind::TextLine | EventKind::BlankLine => text_lines.push(event)
      EventKind::Cell => {
        current_row.push(event.text)
        current_row_refs.push(event.source_ref.unwrap_or(empty_source_ref()))
      }
      EventKind::RowBreak =>
        if current_row.length() > 0 {
          let row_ref = event.source_ref.unwrap_or(
            if current_row_refs.length() > 0 {
              current_row_refs[0]
            } else {
              empty_source_ref()
            },
          )
          table_rows.push(
            simple_event_table_row(current_row, current_row_refs, row_ref),
          )
          current_row.clear()
          current_row_refs.clear()
        }
      _ => ()
    }
  }
  if text_lines.length() > 0 {
    for block in paragraph_blocks_from_line_events(text_lines) {
      document.blocks.push(block)
    }
  }
  if table_rows.length() > 0 {
    let first_row = table_rows[0]
    let last_row = table_rows[table_rows.length() - 1]
    let first_row_ref = first_row.source_ref.unwrap_or(empty_source_ref())
    let last_row_ref = last_row.source_ref.unwrap_or(empty_source_ref())
    let table_ref = source_ref_with_cell_range(
      source_ref_with_lines(
        empty_source_ref(),
        first_row_ref.file_id,
        first_row_ref.format,
        first_row_ref.line_start,
        last_row_ref.line_end,
      ),
      first_row_ref.file_id,
      first_row_ref.format,
      table_cell_span_range(
        table_rows.map(row => row.source_ref.unwrap_or(empty_source_ref())),
      ),
    )
    let table = make_block(BlockKind::Table, "table", source_ref=table_ref)
    table.attrs.set("header_rows", "1")
    table.attrs.set(
      "table_column_count",
      simple_event_table_width(table_rows).to_string(),
    )
    document.diagnostics.metrics.set("table_count", "1")
    table.children.append(table_rows[:])
    document.blocks.push(table)
  }
  document
}

///|
fn simple_event_table_row(
  current_row : Array[String],
  current_row_refs : Array[SourceRef],
  row_ref : SourceRef,
) -> CoreBlock {
  let row_block = make_block(
    BlockKind::TableRow,
    current_row.join(" | "),
    source_ref=row_ref,
  )
  for cell_index in 0..<current_row.length() {
    let cell_ref = if cell_index < current_row_refs.length() {
      current_row_refs[cell_index]
    } else {
      row_ref
    }
    row_block.children.push(
      make_block(
        BlockKind::TableCell,
        current_row[cell_index],
        source_ref=cell_ref,
      ),
    )
  }
  row_block
}

///|
fn simple_event_table_width(rows : Array[CoreBlock]) -> Int {
  let mut width = 0
  for row in rows {
    if row.children.length() > width {
      width = row.children.length()
    }
  }
  width
}

///|
fn paragraph_blocks_from_line_events(
  events : Array[CoreEvent],
) -> Array[CoreBlock] {
  let blocks : Array[CoreBlock] = []
  let current_lines : Array[String] = []
  let current_refs : Array[SourceRef] = []

  fn flush_paragraph(
    blocks : Array[CoreBlock],
    current_lines : Array[String],
    current_refs : Array[SourceRef],
  ) -> Unit {
    if current_lines.length() == 0 {
      return
    }
    let first_ref = current_refs[0]
    let last_ref = current_refs[current_refs.length() - 1]
    let source_ref = source_ref_with_bytes(
      source_ref_with_lines(
        empty_source_ref(),
        first_ref.file_id,
        first_ref.format,
        first_ref.line_start,
        last_ref.line_end,
      ),
      first_ref.file_id,
      first_ref.format,
      first_ref.byte_start,
      last_ref.byte_end,
    )
    blocks.push(
      make_block(BlockKind::Paragraph, current_lines.join(" "), source_ref~),
    )
    current_lines.clear()
    current_refs.clear()
  }

  for event in events {
    match event.kind {
      EventKind::TextLine => {
        current_lines.push(event.text.trim().to_owned())
        current_refs.push(event.source_ref.unwrap_or(empty_source_ref()))
      }
      EventKind::BlankLine =>
        flush_paragraph(blocks, current_lines, current_refs)
      _ => ()
    }
  }
  flush_paragraph(blocks, current_lines, current_refs)
  blocks
}

///|
fn generic_block_event_stream(events : Array[CoreEvent]) -> Bool {
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
fn build_document_from_generic_block_events(
  events : Array[CoreEvent],
) -> DocumentIR {
  let cursor = { events, index: 0 }
  let document = empty_document_ir()
  while cursor.index < cursor.events.length() {
    match parse_generic_block_event(cursor) {
      Some(block) => document.blocks.push(block)
      None => cursor.index += 1
    }
  }
  document
}

///|
priv struct GenericEventCursor {
  events : Array[CoreEvent]
  mut index : Int
}

///|
fn parse_generic_block_event(cursor : GenericEventCursor) -> CoreBlock? {
  if cursor.index >= cursor.events.length() {
    return None
  }
  let start = cursor.events[cursor.index]
  match start.kind {
    EventKind::StartBlock(kind) => {
      let source_ref = start.source_ref.unwrap_or(empty_source_ref())
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
  kind : BlockKind,
  text : String,
  source_ref : SourceRef,
) -> CoreBlock {
  let block = make_block(
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
  let inlines : Array[CoreInline] = []
  let children : Array[CoreBlock] = []
  let table_cells : Array[String] = []
  let table_cell_refs : Array[SourceRef] = []
  while cursor.index < cursor.events.length() {
    let event = cursor.events[cursor.index]
    match event.kind {
      EventKind::EndBlock(end_kind) => {
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
      EventKind::StartBlock(_) =>
        match parse_generic_block_event(cursor) {
          Some(child) => children.push(child)
          None => cursor.index += 1
        }
      EventKind::Text => {
        let raw_event_ref = event.source_ref.unwrap_or(source_ref)
        let event_ref = strip_generic_event_ref(raw_event_ref)
        let inline_kind = generic_inline_kind_name(
          raw_event_ref.extra.get("ir_inline_kind"),
        )
        let inline = match inline_kind {
          Some(InlineKind::LineBreak) =>
            make_inline_line_break(source_ref=event_ref)
          Some(InlineKind::Link) =>
            make_inline_link(
              event.text,
              raw_event_ref.extra.get("ir_inline_href").unwrap_or("#"),
              title=raw_event_ref.extra.get("ir_inline_title"),
              source_ref=event_ref,
            )
          Some(InlineKind::Image) =>
            make_inline_image(
              event.text,
              raw_event_ref.extra.get("ir_inline_href").unwrap_or("#"),
              title=raw_event_ref.extra.get("ir_inline_title"),
              source_ref=event_ref,
            )
          Some(InlineKind::Code) =>
            make_inline_code(event.text, source_ref=event_ref)
          _ => make_inline_text(event.text, source_ref=event_ref)
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
      EventKind::Cell => {
        table_cells.push(event.text)
        table_cell_refs.push(
          strip_generic_event_ref(event.source_ref.unwrap_or(source_ref)),
        )
        cursor.index += 1
      }
      EventKind::RowBreak => {
        let row_ref = strip_generic_event_ref(
          event.source_ref.unwrap_or(source_ref),
        )
        let row = make_block(
          BlockKind::TableRow,
          table_cells.join(" | "),
          source_ref=row_ref,
        )
        for index in 0..<table_cells.length() {
          row.children.push(
            make_block(
              BlockKind::TableCell,
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
fn strip_generic_event_ref(source_ref : SourceRef) -> SourceRef {
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
fn generic_inline_kind_name(kind : String?) -> InlineKind? {
  match kind {
    Some("text") => Some(InlineKind::Text)
    Some("line_break") => Some(InlineKind::LineBreak)
    Some("link") => Some(InlineKind::Link)
    Some("image") => Some(InlineKind::Image)
    Some("code") => Some(InlineKind::Code)
    _ => None
  }
}

///|
fn table_cell_span_range(row_refs : Array[SourceRef]) -> String? {
  if row_refs.length() == 0 {
    return None
  }
  let first = row_refs[0].cell_range.unwrap_or("")
  let last = row_refs[row_refs.length() - 1].cell_range.unwrap_or("")
  let first_start = cell_range_start(first)
  let last_end = cell_range_end(last)
  if first_start == "" || last_end == "" {
    None
  } else {
    Some(first_start + ":" + last_end)
  }
}

///|
fn cell_range_start(cell_range : String) -> String {
  let trimmed = cell_range.trim().to_owned()
  if trimmed == "" {
    return ""
  }
  match trimmed.split_once(":") {
    Some((head, _)) => head.trim().to_owned()
    None => trimmed
  }
}

///|
fn cell_range_end(cell_range : String) -> String {
  let trimmed = cell_range.trim().to_owned()
  if trimmed == "" {
    return ""
  }
  match trimmed.split_once(":") {
    Some((_, tail)) => tail.trim().to_owned()
    None => trimmed
  }
}
