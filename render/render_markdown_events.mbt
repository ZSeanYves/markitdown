///|
fn render_markdown_events(events : Array[@core.CoreEvent]) -> String {
  if events.length() == 0 {
    return ""
  }
  if markdown_text_markup_compact_event_stream(events) {
    let out = StringBuilder::new(size_hint=events.length() * 128)
    write_markdown_text_markup_compact_events_to(out, events)
    return out.to_string()
  }
  let out = StringBuilder::new()
  if markdown_xml_outline_event_stream(events) {
    write_markdown_xml_outline_events_to(out, events)
    return out.to_string()
  }
  if markdown_xml_generic_outline_event_stream(events) {
    write_markdown_xml_generic_outline_events_to(out, events)
    return out.to_string()
  }
  if markdown_json_list_event_stream(events) {
    write_markdown_json_list_events_to(out, events)
    return out.to_string()
  }
  if markdown_subtitle_event_stream(events) {
    write_markdown_subtitle_events_to(out, events)
    return out.to_string()
  }
  if generic_block_event_stream(events) {
    write_markdown_generic_block_events_direct_to(out, events)
    return out.to_string()
  }
  if events[0].kind == TextLine || events[0].kind == BlankLine {
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
fn markdown_text_markup_compact_event_stream(
  events : Array[@core.CoreEvent],
) -> Bool {
  match events[0].source_ref {
    Some(source_ref) =>
      source_ref.extra.get("ir_event_encoding") ==
      Some("text_markup_compact_v1")
    None => false
  }
}

///|
fn write_markdown_text_markup_compact_events_to(
  out : StringBuilder,
  events : Array[@core.CoreEvent],
) -> Unit {
  let cursor = { events, index: 0 }
  let mut previous : @core.BlockKind? = None
  let mut wrote_any = false
  while cursor.index < events.length() {
    let event = events[cursor.index]
    match event.kind {
      StartBlock(kind) => {
        let compact_leaf = match event.source_ref {
          Some(source_ref) =>
            source_ref.extra.get("ir_text_markup_compact_leaf") == Some("true")
          None => false
        }
        let paired_leaf = cursor.index + 1 < events.length() &&
          events[cursor.index + 1].kind == EndBlock(kind)
        let simple = (compact_leaf || paired_leaf) &&
          (kind == Heading || kind == Paragraph || kind == Code)
        if simple {
          let text = event.text
          if text.trim() != "" || kind == Code {
            if wrote_any {
              if markdown_needs_blank_line_between(previous, kind) {
                out.write_string("\n\n")
              } else {
                out.write_char('\n')
              }
            }
            match kind {
              Heading => {
                let level = match event.source_ref {
                  Some(source_ref) =>
                    clamp_heading_level(
                      source_ref.extra.get("ir_block_attr_level").unwrap_or("1"),
                    )
                  None => 1
                }
                out.write_string(repeat_char_string('#', level))
                out.write_char(' ')
                out.write_string(text.trim().to_owned())
              }
              Paragraph =>
                if event.source_ref
                  .map(source_ref => {
                    source_ref.extra.get("ir_text_markup_rendered_inline") ==
                    Some("true")
                  })
                  .unwrap_or(false) {
                  out.write_string(text)
                } else if !text.contains("\n") {
                  out.write_string(escape_markdown_line_prefix(text))
                } else {
                  let lines = render_literal_markdown_lines(text)
                  for index in 0..<lines.length() {
                    if index > 0 {
                      out.write_char('\n')
                    }
                    out.write_string(lines[index])
                  }
                }
              Code => {
                let info = match event.source_ref {
                  Some(source_ref) =>
                    source_ref.extra.get("ir_block_attr_info").unwrap_or("")
                  None => ""
                }
                let fence = safe_code_fence(text)
                out.write_string(fence)
                out.write_string(info)
                out.write_char('\n')
                out.write_string(text)
                out.write_char('\n')
                out.write_string(fence)
              }
              _ => ()
            }
            previous = Some(kind)
            wrote_any = true
          }
          cursor.index += if compact_leaf { 1 } else { 2 }
          continue
        }
        match parse_generic_block_event(cursor) {
          Some(block) => {
            let emitted = write_markdown_block_with_separator_to(
              out, block, previous, wrote_any,
            )
            if emitted {
              previous = Some(block.kind)
              wrote_any = true
            }
          }
          None => cursor.index += 1
        }
      }
      _ => cursor.index += 1
    }
  }
}

///|
fn markdown_json_list_event_stream(events : Array[@core.CoreEvent]) -> Bool {
  match events[0].source_ref {
    Some(source_ref) =>
      source_ref.extra.get("ir_event_encoding") == Some("json_list_v1")
    None => false
  }
}

///|
fn write_markdown_json_list_events_to(
  out : StringBuilder,
  events : Array[@core.CoreEvent],
) -> Unit {
  let mut wrote_any = false
  for event in events {
    if wrote_any {
      out.write_char('\n')
    }
    out.write_string("- ")
    out.write_string(event.text)
    wrote_any = true
  }
}

///|
fn markdown_xml_generic_outline_event_stream(
  events : Array[@core.CoreEvent],
) -> Bool {
  match events[0].source_ref {
    Some(source_ref) =>
      source_ref.format == Some("xml") &&
      source_ref.extra.get("ir_event_encoding") == Some("generic_block")
    None => false
  }
}

///|
fn write_markdown_xml_generic_outline_events_to(
  out : StringBuilder,
  events : Array[@core.CoreEvent],
) -> Unit {
  let stack : Array[(@core.BlockKind, Int)] = []
  let mut wrote_any = false
  let mut needs_heading_gap = false
  for event in events {
    match event.kind {
      StartBlock(Heading) => {
        if wrote_any {
          out.write_string("\n\n")
        }
        out.write_string("# ")
        out.write_string(event.text.trim().to_owned())
        wrote_any = true
        needs_heading_gap = true
        stack.push((Heading, 0))
      }
      StartBlock(List) => {
        let child_depth = if stack.length() == 0 {
          0
        } else {
          let parent = stack[stack.length() - 1]
          match parent.0 {
            List => {
              if wrote_any {
                out.write_char('\n')
                if needs_heading_gap {
                  out.write_char('\n')
                }
              }
              needs_heading_gap = false
              out.write_string(repeat_char_string(' ', parent.1 * 2))
              out.write_string("- ")
              wrote_any = true
              parent.1 + 1
            }
            ListItem => parent.1 + 1
            _ => 0
          }
        }
        stack.push((List, child_depth))
      }
      StartBlock(ListItem) => {
        let depth = if stack.length() > 0 {
          let parent = stack[stack.length() - 1]
          if parent.0 == ListItem {
            parent.1 + 1
          } else {
            parent.1
          }
        } else {
          0
        }
        if wrote_any {
          out.write_char('\n')
          if needs_heading_gap {
            out.write_char('\n')
          }
        }
        needs_heading_gap = false
        out.write_string(repeat_char_string(' ', depth * 2))
        out.write_string("- ")
        out.write_string(event.text.trim().to_owned())
        wrote_any = true
        stack.push((ListItem, depth))
      }
      EndBlock(_) => if stack.length() > 0 { ignore(stack.pop()) }
      _ => ()
    }
  }
}

///|
fn markdown_xml_outline_event_stream(events : Array[@core.CoreEvent]) -> Bool {
  match events[0].source_ref {
    Some(source_ref) =>
      source_ref.extra.get("ir_event_encoding") == Some("xml_outline_v1")
    None => false
  }
}

///|
fn write_markdown_xml_outline_events_to(
  out : StringBuilder,
  events : Array[@core.CoreEvent],
) -> Unit {
  let mut wrote_any = false
  let mut needs_heading_gap = false
  for event in events {
    match event.kind {
      StartBlock(Heading) => {
        if wrote_any {
          out.write_string("\n\n")
        }
        out.write_string("# ")
        out.write_string(event.text.trim().to_owned())
        wrote_any = true
        needs_heading_gap = true
      }
      StartBlock(ListItem) => {
        if wrote_any {
          out.write_char('\n')
          if needs_heading_gap {
            out.write_char('\n')
          }
        }
        needs_heading_gap = false
        let depth = match event.source_ref {
          Some(source_ref) =>
            @string.parse_int(
              source_ref.extra.get("xml_outline_depth").unwrap_or("0"),
            ) catch {
              _ => 0
            }
          None => 0
        }
        out.write_string(repeat_char_string(' ', depth * 2))
        out.write_string("- ")
        out.write_string(event.text.trim().to_owned())
        wrote_any = true
      }
      _ => ()
    }
  }
}

///|
fn markdown_subtitle_event_stream(events : Array[@core.CoreEvent]) -> Bool {
  match events[0].source_ref {
    Some(source_ref) => {
      let format = source_ref.format.unwrap_or("")
      source_ref.extra.get("ir_event_family") == Some("subtitle") ||
      format == "srt" ||
      format == "vtt"
    }
    None => false
  }
}

///|
fn write_markdown_subtitle_events_to(
  out : StringBuilder,
  events : Array[@core.CoreEvent],
) -> Unit {
  let mut index = 0
  let mut wrote_any = false
  while index < events.length() {
    let event = events[index]
    match event.kind {
      StartBlock(Raw) => {
        if wrote_any {
          out.write_string("\n\n")
        }
        let info = match event.source_ref {
          Some(source_ref) =>
            source_ref.extra
            .get("ir_block_attr_info")
            .unwrap_or(source_ref.format.unwrap_or("text"))
          None => "text"
        }
        let fence = safe_code_fence(event.text)
        out.write_string(fence)
        out.write_string(info)
        out.write_char('\n')
        out.write_string(event.text)
        out.write_char('\n')
        out.write_string(fence)
        wrote_any = true
        index += 1
      }
      StartBlock(BlockQuote) => {
        let compact_layout = match event.source_ref {
          Some(source_ref) => {
            let explicit = source_ref.extra
              .get("subtitle_event_layout")
              .unwrap_or("")
            if explicit == "" &&
              source_ref.format == Some("srt") &&
              source_ref.extra.get("ir_event_encoding") is None {
              "record_v2"
            } else {
              explicit
            }
          }
          None => ""
        }
        if compact_layout == "record_v1" || compact_layout == "record_v2" {
          if wrote_any {
            out.write_string("\n\n")
          }
          let (heading, body) = if compact_layout == "record_v2" {
            ("", "")
          } else {
            (
              match event.source_ref {
                Some(source_ref) =>
                  source_ref.extra.get("ir_block_attr_time_range").unwrap_or("")
                None => ""
              },
              event.text,
            )
          }
          if compact_layout == "record_v2" {
            write_markdown_subtitle_record_v2_to(
              out,
              event.text,
              event.source_ref,
            )
          } else {
            write_markdown_subtitle_cue_to(out, heading, body)
          }
          wrote_any = true
          index += 1
          continue
        }
        let mut depth = 1
        let mut cursor = index + 1
        let mut heading = ""
        let mut paragraph = ""
        while cursor < events.length() && depth > 0 {
          match events[cursor].kind {
            StartBlock(BlockQuote) => depth += 1
            EndBlock(BlockQuote) => depth -= 1
            StartBlock(Heading) =>
              if depth == 1 {
                heading = events[cursor].text
              }
            StartBlock(Paragraph) =>
              if depth == 1 {
                paragraph = events[cursor].text
              }
            _ => ()
          }
          cursor += 1
        }
        if wrote_any {
          out.write_string("\n\n")
        }
        write_markdown_subtitle_cue_to(out, heading, paragraph)
        wrote_any = true
        index = cursor
      }
      _ => index += 1
    }
  }
}

///|
fn write_markdown_subtitle_record_v2_to(
  out : StringBuilder,
  text : String,
  source_ref : @core.SourceRef?,
) -> Unit {
  let mut first = true
  for line in text.split("\n") {
    if first {
      out.write_string("> ######")
      let heading = line.trim().to_owned()
      if heading != "" {
        out.write_char(' ')
        match source_ref {
          Some(value) =>
            match value.extra.get("subtitle_identifier") {
              Some(identifier) => {
                out.write_char('[')
                out.write_string(identifier)
                out.write_string("] ")
              }
              None => ()
            }
          None => ()
        }
        out.write_string(heading)
      } else {
        out.write_char(' ')
      }
      out.write_string("\n> ")
      first = false
    } else {
      out.write_char('\n')
      out.write_string("> ")
      out.write_string(escape_markdown_line_prefix(line.to_owned()))
    }
  }
}

///|
fn markdown_subtitle_record_v2_parts(text : String) -> (String, String) {
  let mut heading = ""
  let body = StringBuilder::new()
  let mut first = true
  let mut wrote_body = false
  for line in text.split("\n") {
    if first {
      heading = line.to_owned()
      first = false
    } else {
      if wrote_body {
        body.write_char('\n')
      }
      body.write_string(line.to_owned())
      wrote_body = true
    }
  }
  (heading, body.to_string())
}

///|
fn write_markdown_subtitle_cue_to(
  out : StringBuilder,
  heading : String,
  paragraph : String,
) -> Unit {
  out.write_string("> ######")
  let trimmed_heading = heading.trim().to_owned()
  if trimmed_heading != "" {
    out.write_char(' ')
    out.write_string(trimmed_heading)
  } else {
    out.write_char(' ')
  }
  out.write_string("\n> ")
  for line_view in paragraph.split("\n") {
    out.write_char('\n')
    out.write_string("> ")
    out.write_string(escape_markdown_line_prefix(line_view.to_owned()))
  }
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
      TextLine => current_lines.push(event.text.trim().to_owned())
      BlankLine =>
        wrote_paragraph = write_markdown_line_paragraph_to(
          out, current_lines, wrote_paragraph,
        )
      StartBlock(_) | EndBlock(_) => {
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
      Cell => current_row.push(event.text)
      RowBreak =>
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
    if !in_generic_tail && (event.kind == Cell || event.kind == RowBreak) {
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
    if event.kind == RowBreak {
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
    StartBlock(kind) => {
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
      EndBlock(end_kind) => {
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
      StartBlock(_) =>
        match parse_generic_block_event(cursor) {
          Some(child) => children.push(child)
          None => cursor.index += 1
        }
      Text => {
        let raw_event_ref = event.source_ref.unwrap_or(source_ref)
        let event_ref = strip_generic_event_ref(raw_event_ref)
        let inline_kind = generic_inline_kind_name(
          raw_event_ref.extra.get("ir_inline_kind"),
        )
        let inline = match inline_kind {
          Some(LineBreak) => @core.make_inline_line_break(source_ref=event_ref)
          Some(Link) =>
            @core.make_inline_link(
              event.text,
              raw_event_ref.extra.get("ir_inline_href").unwrap_or("#"),
              title=raw_event_ref.extra.get("ir_inline_title"),
              source_ref=event_ref,
            )
          Some(Image) =>
            @core.make_inline_image(
              event.text,
              raw_event_ref.extra.get("ir_inline_href").unwrap_or("#"),
              title=raw_event_ref.extra.get("ir_inline_title"),
              source_ref=event_ref,
            )
          Some(Code) => @core.make_inline_code(event.text, source_ref=event_ref)
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
      Cell => {
        table_cells.push(event.text)
        table_cell_refs.push(
          strip_generic_event_ref(event.source_ref.unwrap_or(source_ref)),
        )
        cursor.index += 1
      }
      RowBreak => {
        let row_ref = strip_generic_event_ref(
          event.source_ref.unwrap_or(source_ref),
        )
        let row = @core.make_block(
          TableRow,
          table_cells.join(" | "),
          source_ref=row_ref,
        )
        for index in 0..<table_cells.length() {
          row.children.push(
            @core.make_block(
              TableCell,
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
    Some("text") => Some(Text)
    Some("line_break") => Some(LineBreak)
    Some("link") => Some(Link)
    Some("image") => Some(Image)
    Some("code") => Some(Code)
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
    StartBlock(Code) | StartBlock(Raw) | Text => event.text.trim() != ""
    _ => false
  }
}

///|
fn write_markdown_generic_event_to(
  out : StringBuilder,
  event : @core.CoreEvent,
) -> Unit {
  match event.kind {
    StartBlock(Code) => {
      let code = @core.make_block(
        Code,
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
    StartBlock(Raw) => {
      let raw = @core.make_block(
        Raw,
        event.text,
        source_ref=event.source_ref.unwrap_or(@core.empty_source_ref()),
      )
      raw.attrs.set("raw_kind", "text")
      out.write_string(render_markdown_raw(raw))
    }
    Text => write_escaped_markdown_inline_text_to(out, event.text)
    _ => ()
  }
}
