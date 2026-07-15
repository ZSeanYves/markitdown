///|
fn lower_json_document(
  doc : @djson.JsonDocument,
  original_text : String,
  source : @input.InputSource,
  diagnostics : @core.Diagnostics,
) -> @core.DocumentIR {
  let document = @core.empty_document_ir()
  let root = doc.root
  match root {
    @djson.JsonValue::Object(members) => {
      let table = json_object_table_block(members, source, "/")
      document.blocks.push(table)
    }
    @djson.JsonValue::Array(values) =>
      match json_array_to_blocks(values, source, "/", "json") {
        Some(blocks) =>
          for block in blocks {
            document.blocks.push(block)
          }
        None =>
          document.blocks.push(
            json_code_block(
              stringify_json_value(root),
              source,
              "json",
              "/",
              false,
            ),
          )
      }
    @djson.JsonValue::String(value) =>
      document.blocks.push(
        @core.make_block(
          @core.BlockKind::Paragraph,
          value,
          source_ref=json_pointer_source_ref(source, "json", "/"),
        ),
      )
    @djson.JsonValue::Number(value) =>
      document.blocks.push(
        @core.make_block(
          @core.BlockKind::Paragraph,
          value,
          source_ref=json_pointer_source_ref(source, "json", "/"),
        ),
      )
    @djson.JsonValue::Bool(value) =>
      document.blocks.push(
        @core.make_block(
          @core.BlockKind::Paragraph,
          if value {
            "true"
          } else {
            "false"
          },
          source_ref=json_pointer_source_ref(source, "json", "/"),
        ),
      )
    @djson.JsonValue::Null =>
      document.blocks.push(
        @core.make_block(
          @core.BlockKind::Paragraph,
          "null",
          source_ref=json_pointer_source_ref(source, "json", "/"),
        ),
      )
  }
  if document.blocks.length() == 0 {
    document.blocks.push(
      json_code_block(original_text, source, "json", "/", false),
    )
    diagnostics.degraded_features.push("json_empty_block_fallback")
    diagnostics.fallback_trace.push("json empty lowering -> code block")
  }
  document
}

///|
fn json_array_to_blocks(
  values : Array[@djson.JsonValue],
  source : @input.InputSource,
  pointer : String,
  format_name : String,
) -> Array[@core.CoreBlock]? {
  if values.length() == 0 {
    return Some([json_code_block("[]", source, format_name, pointer, false)])
  }
  if json_array_of_scalars(values) {
    let list = @core.make_block(
      @core.BlockKind::List,
      "",
      source_ref=json_pointer_source_ref(source, format_name, pointer),
    )
    for i in 0..<values.length() {
      list.children.push(
        @core.block_with_attr(
          @core.make_block(
            @core.BlockKind::ListItem,
            json_scalar_text(values[i]),
            source_ref=json_pointer_source_ref(
              source,
              format_name,
              json_append_pointer(pointer, i.to_string()),
            ),
          ),
          "ordered",
          "false",
        ),
      )
    }
    return Some([list])
  }
  match json_array_object_rows(values) {
    Some(rows) => {
      let table = table_block_from_rows(rows, source, format_name, pointer)
      Some([table])
    }
    None => None
  }
}

///|
fn lower_line_delimited_json_events(
  format_name : String,
  text : String,
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Result[(Array[@core.CoreEvent], Int, Int, Int, Int, Int, Int), String] {
  let lines = text.split("\n").to_array()
  let events : Array[@core.CoreEvent] = []
  let object_rows : Array[Array[String]] = []
  let mut object_count = 0
  let mut array_count = 0
  let mut scalar_count = 0
  let mut max_depth = 0
  let mut record_index = 0
  let mut blank_line_count = 0
  let max_rows = context.max_rows.unwrap_or(200)
  let mut header_keys : Array[String]? = None
  let record_line_numbers : Array[Int] = []
  let record_pointers : Array[String] = []
  for i in 0..<lines.length() {
    let raw_line = normalize_line_delimited_json_record(lines[i].to_owned())
      .trim()
      .to_owned()
    if raw_line == "" {
      blank_line_count += 1
      continue
    }
    if record_index >= max_rows {
      break
    }
    let parsed = try @djson.parse_json_document(raw_line) |> Ok catch {
      e =>
        Err(
          "invalid " +
          format_name +
          " record at line " +
          (i + 1).to_string() +
          ": " +
          e.to_string(),
        )
    }
    let doc = match parsed {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    let inspect = @djson.inspect_json_document(doc)
    object_count += inspect.object_count
    array_count += inspect.array_count
    scalar_count += inspect.scalar_count
    if inspect.max_depth > max_depth {
      max_depth = inspect.max_depth
    }
    let pointer = "/" + record_index.to_string()
    record_line_numbers.push(i + 1)
    record_pointers.push(pointer)
    match doc.root {
      @djson.JsonValue::Object(members) => {
        let keys = members.map(fn(m) { m.key })
        match header_keys {
          Some(existing) if !@fshared.keys_match_position_index(
              existing,
              @fshared.key_position_index(existing),
              keys,
            ) =>
            events.push({
              kind: @core.EventKind::StartBlock(@core.BlockKind::Code),
              text: raw_line,
              source_ref: Some(
                line_delimited_code_event_source_ref(
                  source,
                  format_name,
                  pointer,
                  i + 1,
                ),
              ),
            })
          _ => {
            if header_keys is None {
              header_keys = Some(keys)
            }
            let row = json_members_to_row(members, header_keys.unwrap_or([]))
            object_rows.push(row)
          }
        }
      }
      _ =>
        events.push({
          kind: @core.EventKind::StartBlock(@core.BlockKind::Code),
          text: raw_line,
          source_ref: Some(
            line_delimited_code_event_source_ref(
              source,
              format_name,
              pointer,
              i + 1,
            ),
          ),
        })
    }
    record_index += 1
  }
  match header_keys {
    Some(keys) if object_rows.length() > 0 => {
      let all_rows : Array[Array[String]] = [keys]
      for row in object_rows {
        all_rows.push(row)
      }
      let table_events = table_events_from_rows(
        all_rows, source, format_name, record_line_numbers, record_pointers,
      )
      table_events.append(events[:])
      Ok(
        (
          table_events, record_index, object_count, array_count, scalar_count, max_depth,
          blank_line_count,
        ),
      )
    }
    _ =>
      Ok(
        (
          events, record_index, object_count, array_count, scalar_count, max_depth,
          blank_line_count,
        ),
      )
  }
}

///|
fn normalize_line_delimited_json_record(line : String) -> String {
  let chars = line.to_array()
  if chars.length() == 0 {
    return line
  }
  let mut start = 0
  if chars[start] == '\u{001E}' {
    start += 1
  }
  if start < chars.length() && chars[start] == '\u{FEFF}' {
    start += 1
  }
  if start == 0 {
    line
  } else {
    String::from_array(chars[start:])
  }
}

///|
fn json_stream_source_ref(
  source : @input.InputSource,
  pointer : String,
  line : Int,
  byte_start : Int,
  byte_end : Int,
) -> @core.SourceRef {
  let source_ref = @core.source_ref_with_bytes(
    @core.source_ref_with_lines(
      json_pointer_source_ref(source, "json", pointer),
      Some(source.source_name),
      Some("json"),
      Some(line),
      Some(line),
    ),
    Some(source.source_name),
    Some("json"),
    Some(byte_start),
    Some(byte_end),
  )
  source_ref
}

///|
fn merge_stream_bytes_into_source_ref(
  original : @core.SourceRef,
  streamed : @core.SourceRef,
) -> @core.SourceRef {
  {
    ..original,
    line_start: streamed.line_start,
    line_end: streamed.line_end,
    byte_start: streamed.byte_start,
    byte_end: streamed.byte_end,
  }
}

///|
fn json_generic_block_events_from_stream(
  stream : @djson.JsonStreamDocument,
  source : @input.InputSource,
) -> Array[@core.CoreEvent] {
  if stream.summary.root_kind == "array" && stream.events.length() >= 100_000 {
    return json_compact_root_array_events_from_stream(stream, source)
  }
  let events : Array[@core.CoreEvent] = []
  let cursor = { events: stream.events, index: 0 }
  json_append_value_events(events, cursor, source, "/")
  events
}

///|
/// Lower a validated large root array one item at a time. Structural scanning
/// uses UTF-8 code units only for JSON delimiters, so element slices preserve
/// the original payload bytes and source offsets.
fn json_compact_root_array_events_direct(
  text : String,
  source : @input.InputSource,
) -> Result[Array[@core.CoreEvent], String] {
  let events : Array[@core.CoreEvent] = []
  let mut index = 0
  let mut line = 1
  let length = text.length()
  while index < length &&
        json_direct_is_space(text.code_unit_at(index).to_int()) {
    if text.code_unit_at(index).to_int() == 10 {
      line += 1
    }
    index += 1
  }
  if index >= length || text.code_unit_at(index).to_int() != 91 {
    return Err("large JSON direct lowering requires a root array")
  }
  index += 1
  let mut item_index = 0
  while index < length {
    while index < length {
      let ch = text.code_unit_at(index).to_int()
      if !json_direct_is_space(ch) {
        break
      }
      if ch == 10 {
        line += 1
      }
      index += 1
    }
    if index < length && text.code_unit_at(index).to_int() == 93 {
      return Ok(events)
    }
    let item_start = index
    let item_line = line
    let preview_cursor = JsonDirectPreviewCursor::{
      text,
      pos: item_start,
      line_breaks: 0,
    }
    let preview = preview_cursor.value_preview(2)
    let item_end = preview_cursor.pos
    if item_end <= item_start {
      return Err("empty JSON root-array item")
    }
    line += preview_cursor.line_breaks
    index = item_end
    let pointer = json_append_pointer("/", item_index.to_string())
    let source_ref = json_stream_source_ref(
      source, pointer, item_line, item_start, item_end,
    )
    source_ref.extra.set("ir_event_encoding", "json_list_v1")
    source_ref.extra.set("ir_block_kind", "list_item")
    source_ref.extra.set("ir_block_attr_literal", "true")
    source_ref.extra.set("ir_block_attr_ordered", "false")
    events.push({
      kind: @core.EventKind::StartBlock(@core.BlockKind::ListItem),
      text: preview,
      source_ref: Some(source_ref),
    })
    item_index += 1
    if index < length && text.code_unit_at(index).to_int() == 44 {
      index += 1
    }
  }
  Err("unterminated JSON root array")
}

///|
fn json_direct_is_space(ch : Int) -> Bool {
  ch == 32 || ch == 9 || ch == 10 || ch == 13
}

///|
priv struct JsonDirectPreviewCursor {
  text : String
  mut pos : Int
  mut line_breaks : Int
}

///|
fn JsonDirectPreviewCursor::skip_ws(self : JsonDirectPreviewCursor) -> Unit {
  while self.pos < self.text.length() &&
        json_direct_is_space(self.text.code_unit_at(self.pos).to_int()) {
    if self.text.code_unit_at(self.pos).to_int() == 10 {
      self.line_breaks += 1
    }
    self.pos += 1
  }
}

///|
fn JsonDirectPreviewCursor::value_preview(
  self : JsonDirectPreviewCursor,
  preview_depth : Int,
) -> String {
  self.skip_ws()
  if self.pos >= self.text.length() {
    return ""
  }
  match self.text.code_unit_at(self.pos).to_int() {
    123 => self.object_preview(preview_depth)
    91 => self.array_preview(preview_depth)
    34 => json_clip_preview_text(self.string_value(), 96)
    116 => {
      self.pos += 4
      "true"
    }
    102 => {
      self.pos += 5
      "false"
    }
    110 => {
      self.pos += 4
      "null"
    }
    _ => self.number_value()
  }
}

///|
fn JsonDirectPreviewCursor::object_preview(
  self : JsonDirectPreviewCursor,
  preview_depth : Int,
) -> String {
  self.pos += 1
  self.skip_ws()
  let samples : Array[String] = []
  let limit = json_preview_member_limit(preview_depth)
  let mut count = 0
  if self.pos < self.text.length() &&
    self.text.code_unit_at(self.pos).to_int() == 125 {
    self.pos += 1
    return json_object_summary_text(0, samples)
  }
  while self.pos < self.text.length() {
    self.skip_ws()
    let key = self.string_value()
    self.skip_ws()
    self.pos += 1
    count += 1
    if samples.length() < limit {
      samples.push(
        json_clip_preview_text(key, 48) +
        ": " +
        self.value_preview(preview_depth - 1),
      )
    } else {
      self.skip_value()
    }
    self.skip_ws()
    if self.pos >= self.text.length() {
      break
    }
    let delimiter = self.text.code_unit_at(self.pos).to_int()
    self.pos += 1
    if delimiter == 125 {
      break
    }
  }
  json_object_summary_text(count, samples)
}

///|
fn JsonDirectPreviewCursor::array_preview(
  self : JsonDirectPreviewCursor,
  preview_depth : Int,
) -> String {
  self.pos += 1
  self.skip_ws()
  let samples : Array[String] = []
  let limit = json_preview_sample_limit(preview_depth)
  let mut count = 0
  if self.pos < self.text.length() &&
    self.text.code_unit_at(self.pos).to_int() == 93 {
    self.pos += 1
    return json_array_summary_text(0, samples)
  }
  while self.pos < self.text.length() {
    count += 1
    if samples.length() < limit {
      samples.push(self.value_preview(preview_depth - 1))
    } else {
      self.skip_value()
    }
    self.skip_ws()
    if self.pos >= self.text.length() {
      break
    }
    let delimiter = self.text.code_unit_at(self.pos).to_int()
    self.pos += 1
    if delimiter == 93 {
      break
    }
  }
  json_array_summary_text(count, samples)
}

///|
fn JsonDirectPreviewCursor::string_value(
  self : JsonDirectPreviewCursor,
) -> String {
  let quoted_start = self.pos
  self.pos += 1
  let content_start = self.pos
  let mut escaped = false
  let mut has_escape = false
  while self.pos < self.text.length() {
    let ch = self.text.code_unit_at(self.pos).to_int()
    if escaped {
      escaped = false
    } else if ch == 92 {
      escaped = true
      has_escape = true
    } else if ch == 34 {
      let content_end = self.pos
      self.pos += 1
      if !has_escape {
        return self.text[content_start:content_end].to_owned()
      }
      let decoded = @djson.parse_json_document_native(
        self.text[quoted_start:self.pos].to_owned(),
        preserve_number_lexemes=false,
      ) catch {
        _ => return self.text[content_start:content_end].to_owned()
      }
      return match decoded.root {
        @djson.JsonValue::String(value) => value
        _ => self.text[content_start:content_end].to_owned()
      }
    }
    self.pos += 1
  }
  self.text[content_start:].to_owned()
}

///|
fn JsonDirectPreviewCursor::number_value(
  self : JsonDirectPreviewCursor,
) -> String {
  let start = self.pos
  while self.pos < self.text.length() {
    let ch = self.text.code_unit_at(self.pos).to_int()
    if ch == 44 || ch == 93 || ch == 125 || json_direct_is_space(ch) {
      break
    }
    self.pos += 1
  }
  self.text[start:self.pos].to_owned()
}

///|
fn JsonDirectPreviewCursor::skip_value(self : JsonDirectPreviewCursor) -> Unit {
  self.skip_ws()
  if self.pos >= self.text.length() {
    return
  }
  let first = self.text.code_unit_at(self.pos).to_int()
  if first == 34 {
    ignore(self.string_value())
    return
  }
  if first != 123 && first != 91 {
    ignore(self.number_value())
    return
  }
  let mut depth = 0
  let mut in_string = false
  let mut escaped = false
  while self.pos < self.text.length() {
    let ch = self.text.code_unit_at(self.pos).to_int()
    if in_string {
      if escaped {
        escaped = false
      } else if ch == 92 {
        escaped = true
      } else if ch == 34 {
        in_string = false
      }
    } else if ch == 34 {
      in_string = true
    } else if ch == 123 || ch == 91 {
      depth += 1
    } else if ch == 125 || ch == 93 {
      depth -= 1
      if depth == 0 {
        self.pos += 1
        return
      }
    }
    self.pos += 1
  }
}

///|
fn json_compact_root_array_events_from_stream(
  stream : @djson.JsonStreamDocument,
  source : @input.InputSource,
) -> Array[@core.CoreEvent] {
  let events : Array[@core.CoreEvent] = Array::new(
    capacity=stream.summary.scalar_count / 4,
  )
  let cursor = { events: stream.events, index: 1 }
  let mut item_index = 0
  while cursor.index < cursor.events.length() {
    if cursor.events[cursor.index].kind == @djson.JsonStreamEventKind::ArrayEnd {
      break
    }
    let pointer = json_append_pointer("/", item_index.to_string())
    let start = cursor.events[cursor.index]
    let text = json_compact_preview_text(cursor, 2)
    let end = cursor.events[cursor.index - 1]
    let source_ref = json_stream_source_ref(
      source,
      pointer,
      start.source.line,
      start.source.byte_start,
      end.source.byte_end,
    )
    source_ref.extra.set("ir_event_encoding", "json_list_v1")
    source_ref.extra.set("ir_block_kind", "list_item")
    source_ref.extra.set("ir_block_attr_literal", "true")
    source_ref.extra.set("ir_block_attr_ordered", "false")
    events.push({
      kind: @core.EventKind::StartBlock(@core.BlockKind::ListItem),
      text,
      source_ref: Some(source_ref),
    })
    item_index += 1
  }
  events
}

///|
fn json_compact_preview_text(
  cursor : JsonStreamCursor,
  preview_depth : Int,
) -> String {
  let event = cursor.events[cursor.index]
  match event.kind {
    @djson.JsonStreamEventKind::StringValue => {
      cursor.index += 1
      json_clip_preview_text(json_stream_scalar_text(event), 96)
    }
    @djson.JsonStreamEventKind::NumberValue
    | @djson.JsonStreamEventKind::BoolValue
    | @djson.JsonStreamEventKind::NullValue => {
      cursor.index += 1
      json_stream_scalar_text(event)
    }
    @djson.JsonStreamEventKind::ObjectStart =>
      json_compact_object_preview_text(cursor, preview_depth)
    @djson.JsonStreamEventKind::ArrayStart =>
      json_compact_array_preview_text(cursor, preview_depth)
    _ => {
      cursor.index += 1
      ""
    }
  }
}

///|
fn json_compact_object_preview_text(
  cursor : JsonStreamCursor,
  preview_depth : Int,
) -> String {
  let root_depth = cursor.events[cursor.index].depth
  let member_depth = root_depth + 1
  let mut member_count = 0
  let samples : Array[String] = []
  cursor.index += 1
  while cursor.index < cursor.events.length() {
    let next = cursor.events[cursor.index]
    match next.kind {
      @djson.JsonStreamEventKind::Key if next.depth == member_depth => {
        member_count += 1
        let key = next.text.unwrap_or("")
        cursor.index += 1
        let sample = samples.length() < json_preview_member_limit(preview_depth)
        let value = json_compact_preview_text(
          cursor,
          if sample {
            preview_depth - 1
          } else {
            0
          },
        )
        if sample {
          samples.push(json_clip_preview_text(key, 48) + ": " + value)
        }
        continue
      }
      @djson.JsonStreamEventKind::ObjectEnd if next.depth == root_depth => {
        cursor.index += 1
        return json_object_summary_text(member_count, samples)
      }
      _ => cursor.index += 1
    }
  }
  json_object_summary_text(member_count, samples)
}

///|
fn json_compact_array_preview_text(
  cursor : JsonStreamCursor,
  preview_depth : Int,
) -> String {
  let root_depth = cursor.events[cursor.index].depth
  let item_depth = root_depth + 1
  let mut item_count = 0
  let samples : Array[String] = []
  cursor.index += 1
  while cursor.index < cursor.events.length() {
    let next = cursor.events[cursor.index]
    if next.kind == @djson.JsonStreamEventKind::ArrayEnd &&
      next.depth == root_depth {
      cursor.index += 1
      return json_array_summary_text(item_count, samples)
    }
    if next.depth == item_depth {
      item_count += 1
      let sample = samples.length() < json_preview_sample_limit(preview_depth)
      let value = json_compact_preview_text(
        cursor,
        if sample {
          preview_depth - 1
        } else {
          0
        },
      )
      if sample {
        samples.push(value)
      }
      continue
    }
    cursor.index += 1
  }
  json_array_summary_text(item_count, samples)
}
