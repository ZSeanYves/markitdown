///|
priv struct JsonStreamCursor {
  events : Array[@djson.JsonStreamEvent]
  mut index : Int
}

///|
fn json_append_value_events(
  out : Array[@core.CoreEvent],
  cursor : JsonStreamCursor,
  source : @input.InputSource,
  pointer : String,
) -> Unit {
  if cursor.index >= cursor.events.length() {
    return
  }
  let event = cursor.events[cursor.index]
  match event.kind {
    ObjectStart => {
      cursor.index += 1
      let rows : Array[Array[String]] = [["Key", "Value"]]
      let row_refs : Array[@core.SourceRef] = [
        json_stream_source_ref(
          source,
          pointer,
          event.source.line,
          event.source.byte_start,
          event.source.byte_end,
        ),
      ]
      while cursor.index < cursor.events.length() {
        let next = cursor.events[cursor.index]
        match next.kind {
          Key => {
            let key = next.text.unwrap_or("")
            let key_ref = json_stream_source_ref(
              source,
              next.pointer,
              next.source.line,
              next.source.byte_start,
              next.source.byte_end,
            )
            cursor.index += 1
            let value_text = json_stream_scalar_or_summary_text(
              cursor,
              source,
              pointer=next.pointer,
            )
            rows.push([key, value_text.0])
            row_refs.push(
              merge_stream_bytes_into_source_ref(key_ref, value_text.1),
            )
          }
          ObjectEnd => {
            cursor.index += 1
            json_append_table_block_events(
              out, rows, row_refs, source, "json", pointer,
            )
            return
          }
          _ => cursor.index += 1
        }
      }
    }
    ArrayStart => {
      let start = event
      cursor.index += 1
      let values : Array[(String, @core.SourceRef)] = []
      let mut item_index = 0
      while cursor.index < cursor.events.length() {
        let next = cursor.events[cursor.index]
        match next.kind {
          ArrayEnd => {
            cursor.index += 1
            if values.length() > 0 {
              json_append_scalar_list_events(out, values, source, pointer)
            } else {
              out.push(
                json_code_block_event(
                  "[]",
                  source,
                  pointer,
                  start.source.line,
                  start.source.byte_start,
                  start.source.byte_end,
                ),
              )
            }
            return
          }
          _ => {
            let item_pointer = json_append_pointer(
              pointer,
              item_index.to_string(),
            )
            let value = json_stream_scalar_or_summary_text(
              cursor,
              source,
              pointer=item_pointer,
            )
            values.push(value)
            item_index += 1
          }
        }
      }
    }
    StringValue | NumberValue | BoolValue | NullValue => {
      let source_ref = json_stream_source_ref(
        source,
        event.pointer,
        event.source.line,
        event.source.byte_start,
        event.source.byte_end,
      )
      out.push({
        kind: StartBlock(Paragraph),
        text: json_stream_scalar_text(event),
        source_ref: Some(
          generic_event_source_ref(source_ref, Paragraph, [("literal", "true")]),
        ),
      })
      out.push({
        kind: EndBlock(Paragraph),
        text: "",
        source_ref: Some(
          generic_event_source_ref(source_ref, Paragraph, [("literal", "true")]),
        ),
      })
      cursor.index += 1
    }
    _ => cursor.index += 1
  }
}

///|
fn json_stream_scalar_or_summary_text(
  cursor : JsonStreamCursor,
  source : @input.InputSource,
  pointer? : String = "/",
) -> (String, @core.SourceRef) {
  json_stream_value_preview_text(cursor, source, pointer, 2)
}

///|
fn json_stream_value_preview_text(
  cursor : JsonStreamCursor,
  source : @input.InputSource,
  pointer : String,
  preview_depth : Int,
) -> (String, @core.SourceRef) {
  let event = cursor.events[cursor.index]
  match event.kind {
    StringValue | NumberValue | BoolValue | NullValue => {
      cursor.index += 1
      (
        json_clip_preview_text(json_stream_scalar_text(event), 96),
        json_stream_source_ref(
          source,
          pointer,
          event.source.line,
          event.source.byte_start,
          event.source.byte_end,
        ),
      )
    }
    ObjectStart =>
      json_stream_object_preview_text(cursor, source, pointer, preview_depth)
    ArrayStart =>
      json_stream_array_preview_text(cursor, source, pointer, preview_depth)
    _ => {
      cursor.index += 1
      (
        "",
        json_stream_source_ref(
          source,
          pointer,
          event.source.line,
          event.source.byte_start,
          event.source.byte_end,
        ),
      )
    }
  }
}

///|
fn json_stream_object_preview_text(
  cursor : JsonStreamCursor,
  source : @input.InputSource,
  pointer : String,
  preview_depth : Int,
) -> (String, @core.SourceRef) {
  let start = cursor.events[cursor.index]
  let root_depth = start.depth
  let member_depth = root_depth + 1
  let start_ref = json_stream_source_ref(
    source,
    pointer,
    start.source.line,
    start.source.byte_start,
    start.source.byte_end,
  )
  let mut end_ref = start_ref
  let mut member_count = 0
  let samples : Array[String] = []
  cursor.index += 1
  while cursor.index < cursor.events.length() {
    let next = cursor.events[cursor.index]
    match next.kind {
      Key =>
        if next.depth == member_depth {
          member_count += 1
          let key = next.text.unwrap_or("")
          cursor.index += 1
          if samples.length() < json_preview_member_limit(preview_depth) &&
            cursor.index < cursor.events.length() {
            let value = json_stream_value_preview_text(
              cursor,
              source,
              next.pointer,
              preview_depth - 1,
            )
            samples.push(json_clip_preview_text(key, 48) + ": " + value.0)
            end_ref = value.1
          } else if cursor.index < cursor.events.length() {
            let value = json_stream_value_preview_text(
              cursor,
              source,
              next.pointer,
              0,
            )
            end_ref = value.1
          }
          continue
        }
      ObjectEnd =>
        if next.depth == root_depth {
          end_ref = json_stream_source_ref(
            source,
            pointer,
            next.source.line,
            next.source.byte_start,
            next.source.byte_end,
          )
          cursor.index += 1
          return (
            json_object_summary_text(member_count, samples),
            merge_stream_bytes_into_source_ref(start_ref, end_ref),
          )
        }
      _ => ()
    }
    cursor.index += 1
  }
  (
    json_object_summary_text(member_count, samples),
    merge_stream_bytes_into_source_ref(start_ref, end_ref),
  )
}

///|
fn json_stream_array_preview_text(
  cursor : JsonStreamCursor,
  source : @input.InputSource,
  pointer : String,
  preview_depth : Int,
) -> (String, @core.SourceRef) {
  let start = cursor.events[cursor.index]
  let root_depth = start.depth
  let item_depth = root_depth + 1
  let start_ref = json_stream_source_ref(
    source,
    pointer,
    start.source.line,
    start.source.byte_start,
    start.source.byte_end,
  )
  let mut end_ref = start_ref
  let mut item_count = 0
  let sample_values : Array[String] = []
  cursor.index += 1
  while cursor.index < cursor.events.length() {
    let next = cursor.events[cursor.index]
    match next.kind {
      ArrayEnd =>
        if next.depth == root_depth {
          end_ref = json_stream_source_ref(
            source,
            pointer,
            next.source.line,
            next.source.byte_start,
            next.source.byte_end,
          )
          cursor.index += 1
          return (
            json_array_summary_text(item_count, sample_values),
            merge_stream_bytes_into_source_ref(start_ref, end_ref),
          )
        }
      _ =>
        if next.depth == item_depth {
          item_count += 1
          let value = json_stream_value_preview_text(
            cursor,
            source,
            next.pointer,
            if sample_values.length() < json_preview_sample_limit(preview_depth) {
              preview_depth - 1
            } else {
              0
            },
          )
          if sample_values.length() < json_preview_sample_limit(preview_depth) {
            sample_values.push(value.0)
          }
          end_ref = value.1
          continue
        }
    }
    cursor.index += 1
  }
  (
    json_array_summary_text(item_count, sample_values),
    merge_stream_bytes_into_source_ref(start_ref, end_ref),
  )
}

///|
fn json_preview_member_limit(preview_depth : Int) -> Int {
  if preview_depth <= 0 {
    0
  } else {
    8
  }
}

///|
fn json_preview_sample_limit(preview_depth : Int) -> Int {
  if preview_depth <= 0 {
    0
  } else if preview_depth == 1 {
    16
  } else {
    96
  }
}

///|
fn json_clip_preview_text(text : String, max_chars : Int) -> String {
  if !text.contains("\n") && !text.contains("\r") {
    let trimmed = text.trim()
    if trimmed.length() == text.length() {
      if text.length() <= max_chars {
        return text
      }
      return text[:max_chars].to_owned() + "..."
    }
  }
  let normalized = text
    .replace(old="\n", new=" ")
    .replace(old="\r", new=" ")
    .trim()
    .to_owned()
  if normalized.length() <= max_chars {
    normalized
  } else {
    normalized[:max_chars].to_owned() + "..."
  }
}

///|
fn json_stream_scalar_text(event : @djson.JsonStreamEvent) -> String {
  match event.kind {
    StringValue | NumberValue => event.text.unwrap_or("")
    BoolValue => event.text.unwrap_or("false")
    NullValue => "null"
    _ => ""
  }
}

///|
fn json_object_summary_text(
  member_count : Int,
  sample_keys : Array[String],
) -> String {
  let out = StringBuilder::new()
  out.write_string("{ ")
  out.write_string(member_count.to_string())
  out.write_string(" keys")
  if sample_keys.length() > 0 {
    out.write_string(": ")
    for i in 0..<sample_keys.length() {
      if i > 0 {
        out.write_string(", ")
      }
      out.write_string(sample_keys[i])
    }
    if member_count > sample_keys.length() {
      out.write_string(", ...")
    }
  }
  out.write_string(" }")
  out.to_string()
}

///|
fn json_array_summary_text(
  item_count : Int,
  sample_values : Array[String],
) -> String {
  let out = StringBuilder::new()
  out.write_string("[ ")
  out.write_string(item_count.to_string())
  out.write_string(" items")
  if sample_values.length() > 0 {
    out.write_string(": ")
    for i in 0..<sample_values.length() {
      if i > 0 {
        out.write_string(", ")
      }
      out.write_string(sample_values[i])
    }
    if item_count > sample_values.length() {
      out.write_string(", ...")
    }
  }
  out.write_string(" ]")
  out.to_string()
}

///|
fn json_append_table_block_events(
  out : Array[@core.CoreEvent],
  rows : Array[Array[String]],
  row_refs : Array[@core.SourceRef],
  source : @input.InputSource,
  format_name : String,
  pointer : String,
) -> Unit {
  let base_ref = if row_refs.length() > 0 {
    let first = row_refs[0]
    let last = row_refs[row_refs.length() - 1]
    merge_stream_bytes_into_source_ref(first, last)
  } else {
    json_pointer_source_ref(source, format_name, pointer)
  }
  let block_ref = generic_event_source_ref(base_ref, Table, [
    ("header_rows", "1"),
    ("table_column_count", rows[0].length().to_string()),
  ])
  out.push({
    kind: StartBlock(Table),
    text: "table",
    source_ref: Some(block_ref),
  })
  for row_index in 0..<rows.length() {
    let row = rows[row_index]
    let row_ref = if row_index < row_refs.length() {
      row_refs[row_index]
    } else {
      json_pointer_source_ref(source, format_name, pointer)
    }
    for cell_index in 0..<row.length() {
      out.push({
        kind: Cell,
        text: row[cell_index],
        source_ref: Some(
          @core.source_ref_with_cell_range(
            row_ref,
            Some(source.source_name),
            Some(format_name),
            Some(
              "R" +
              (row_index + 1).to_string() +
              "C" +
              (cell_index + 1).to_string(),
            ),
          ),
        ),
      })
    }
    out.push({ kind: RowBreak, text: "", source_ref: Some(row_ref) })
  }
  out.push({ kind: EndBlock(Table), text: "", source_ref: Some(block_ref) })
}

///|
fn json_append_scalar_list_events(
  out : Array[@core.CoreEvent],
  values : Array[(String, @core.SourceRef)],
  source : @input.InputSource,
  pointer : String,
) -> Unit {
  let list_ref = generic_event_source_ref(
    json_pointer_source_ref(source, "json", pointer),
    List,
    [("ordered", "false")],
  )
  out.push({ kind: StartBlock(List), text: "", source_ref: Some(list_ref) })
  for value in values {
    let item_ref = generic_event_source_ref(value.1, ListItem, [
      ("ordered", "false"),
      ("literal", "true"),
    ])
    out.push({
      kind: StartBlock(ListItem),
      text: value.0,
      source_ref: Some(item_ref),
    })
    out.push({ kind: EndBlock(ListItem), text: "", source_ref: Some(item_ref) })
  }
  out.push({ kind: EndBlock(List), text: "", source_ref: Some(list_ref) })
}

///|
fn json_code_block_event(
  text : String,
  source : @input.InputSource,
  pointer : String,
  line : Int,
  byte_start : Int,
  byte_end : Int,
) -> @core.CoreEvent {
  {
    kind: StartBlock(Code),
    text,
    source_ref: Some(
      generic_event_source_ref(
        json_stream_source_ref(source, pointer, line, byte_start, byte_end),
        Code,
        [("info", "json")],
      ),
    ),
  }
}

///|
fn generic_event_source_ref(
  source_ref : @core.SourceRef,
  kind : @core.BlockKind,
  attrs : Array[(String, String)],
) -> @core.SourceRef {
  let next = source_ref
  next.extra.set("ir_event_encoding", "generic_block")
  next.extra.set("ir_block_kind", @core.block_kind_name(kind))
  for entry in attrs {
    next.extra.set("ir_block_attr_" + entry.0, entry.1)
  }
  next
}

///|
fn count_event_tables(events : Array[@core.CoreEvent]) -> Int {
  let mut count = 0
  for event in events {
    if event.kind == StartBlock(Table) {
      count += 1
    }
  }
  count
}

///|
fn count_event_blocks(events : Array[@core.CoreEvent]) -> Int {
  let mut count = 0
  for event in events {
    match event.kind {
      StartBlock(_) => count += 1
      _ => ()
    }
  }
  count
}

///|
fn infer_line_json_table_count(events : Array[@core.CoreEvent]) -> Int {
  let mut cell_count = 0
  for event in events {
    if event.kind == Cell {
      cell_count += 1
    }
  }
  if cell_count > 0 {
    1
  } else {
    0
  }
}

///|
fn malformed_json_parse_result(
  parser_name : String,
  format_name : String,
  source : @input.InputSource,
  text : String,
  diagnostics : @core.Diagnostics,
  err : String,
  capability : @parser.ParserCapability,
) -> @parser.ParseResult {
  let source_ref = @core.source_ref_with_lines(
    json_pointer_source_ref(source, format_name, "/"),
    Some(source.source_name),
    Some(format_name),
    Some(1),
    Some(@fshared.count_physical_lines(text)),
  )
  let block = @core.make_block(Code, text, source_ref~)
  block.attrs.set("info", format_name)
  diagnostics.warnings.push(format_name + " parse warning: " + err)
  diagnostics.degraded_features.push(format_name + "_raw_fenced_fallback")
  diagnostics.fallback_trace.push(
    format_name + " parse failed -> raw fenced block",
  )
  diagnostics.metrics.set("parser_name", parser_name)
  diagnostics.metrics.set(
    "parser_mode",
    @parser.mode_name(capability.parser_mode),
  )
  diagnostics.metrics.set(
    "input_kind",
    @fshared.input_kind_name(@input.input_kind(source)),
  )
  diagnostics.metrics.set("detected_format", format_name)
  diagnostics.metrics.set("json_valid", "false")
  diagnostics.metrics.set("record_count", "0")
  diagnostics.metrics.set("object_count", "0")
  diagnostics.metrics.set("array_count", "0")
  diagnostics.metrics.set("scalar_count", "0")
  diagnostics.metrics.set("max_depth_observed", "0")
  diagnostics.metrics.set("json_token_count", "0")
  diagnostics.metrics.set("syntax_error_count", "1")
  diagnostics.metrics.set("invalid_record_count", "1")
  diagnostics.metrics.set("table_count", "0")
  diagnostics.metrics.set("image_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("block_count", "1")
  diagnostics.metrics.set("event_count", "0")
  diagnostics.metrics.set("requested_mode", "default")
  diagnostics.metrics.set(
    "effective_mode",
    @parser.mode_name(capability.parser_mode),
  )
  diagnostics.metrics.set("dom_limit_reached", "false")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set(
    "event_granularity",
    if capability.parser_mode == StreamingEvent {
      "json_structure"
    } else {
      "none"
    },
  )
  diagnostics.metrics.set(
    "event_semantics",
    if capability.parser_mode == StreamingEvent {
      "json_structure_event_stream_failed_closed"
    } else {
      "dom_ast_model"
    },
  )
  diagnostics.metrics.set(
    "degraded_feature_count",
    diagnostics.degraded_features.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
  diagnostics.pass_trace.push("parse:" + parser_name)
  let document = @core.empty_document_ir()
  document.blocks.push(block)
  let final_document = @core.document_with_diagnostics(document, diagnostics)
  @parser.parse_result_with_document_capability(
    parser_name,
    capability.parser_mode,
    final_document,
    diagnostics,
    capability,
  )
}

///|
fn json_object_table_block(
  members : Array[@djson.JsonMember],
  source : @input.InputSource,
  pointer : String,
) -> @core.CoreBlock {
  let rows : Array[Array[String]] = [["Key", "Value"]]
  for entry in members {
    rows.push([entry.key, json_value_cell(entry.value)])
  }
  table_block_from_rows(rows, source, "json", pointer)
}

///|
fn table_block_from_rows(
  rows : Array[Array[String]],
  source : @input.InputSource,
  format_name : String,
  pointer : String,
) -> @core.CoreBlock {
  @fshared.make_indexed_table_block(
    rows,
    json_pointer_source_ref(source, format_name, pointer),
    fn(row_index, row_values) {
      @core.source_ref_with_cell_range(
        @core.source_ref_with_lines(
          json_pointer_source_ref(source, format_name, pointer),
          Some(source.source_name),
          Some(format_name),
          Some(row_index + 1),
          Some(row_index + 1),
        ),
        Some(source.source_name),
        Some(format_name),
        Some(
          @fshared.indexed_table_row_span(row_index + 1, row_values.length()),
        ),
      )
    },
    fn(row_index, col_index) {
      let row_ref = @core.source_ref_with_cell_range(
        @core.source_ref_with_lines(
          json_pointer_source_ref(source, format_name, pointer),
          Some(source.source_name),
          Some(format_name),
          Some(row_index + 1),
          Some(row_index + 1),
        ),
        Some(source.source_name),
        Some(format_name),
        Some(
          @fshared.indexed_table_row_span(
            row_index + 1,
            rows[row_index].length(),
          ),
        ),
      )
      @core.source_ref_with_cell_range(
        row_ref,
        Some(source.source_name),
        Some(format_name),
        Some(@fshared.indexed_table_cell_span(row_index + 1, col_index + 1)),
      )
    },
  )
}

///|
fn table_events_from_rows(
  rows : Array[Array[String]],
  source : @input.InputSource,
  format_name : String,
  record_line_numbers : Array[Int],
  record_pointers : Array[String],
) -> Array[@core.CoreEvent] {
  let events : Array[@core.CoreEvent] = []
  for row_index in 0..<rows.length() {
    let row = rows[row_index]
    let row_line = if row_index == 0 {
      1
    } else {
      record_line_numbers[row_index - 1]
    }
    let row_pointer = if row_index == 0 {
      "/header"
    } else {
      record_pointers[row_index - 1]
    }
    let row_ref = @core.source_ref_with_cell_range(
      @core.source_ref_with_lines(
        json_pointer_source_ref(source, format_name, row_pointer),
        Some(source.source_name),
        Some(format_name),
        Some(row_line),
        Some(row_line),
      ),
      Some(source.source_name),
      Some(format_name),
      Some(
        "R" +
        (row_index + 1).to_string() +
        "C1:R" +
        (row_index + 1).to_string() +
        "C" +
        row.length().to_string(),
      ),
    )
    if row_index == 0 {
      row_ref.extra.set("synthetic_header", "true")
    } else {
      row_ref.extra.set("record_index", (row_index - 1).to_string())
    }
    for col_index in 0..<row.length() {
      let cell_ref = @core.source_ref_with_cell_range(
        row_ref,
        Some(source.source_name),
        Some(format_name),
        Some(
          "R" + (row_index + 1).to_string() + "C" + (col_index + 1).to_string(),
        ),
      )
      if row_index == 0 {
        cell_ref.extra.set("synthetic_header", "true")
      } else {
        cell_ref.extra.set("record_index", (row_index - 1).to_string())
      }
      events.push({
        kind: Cell,
        text: row[col_index],
        source_ref: Some(cell_ref),
      })
    }
    if row.length() > 0 {
      events.push({ kind: RowBreak, text: "", source_ref: Some(row_ref) })
    }
  }
  events
}

///|
fn count_json_tables(document : @core.DocumentIR) -> Int {
  @fshared.count_blocks_by_kind(document.blocks, Table)
}

///|
fn json_array_object_rows(
  values : Array[@djson.JsonValue],
) -> Array[Array[String]]? {
  let mut keys : Array[String] = []
  let key_index : Map[String, Int] = Map([])
  let mut has_key_index = false
  let rows : Array[Array[String]] = []
  for i in 0..<values.length() {
    match values[i] {
      Object(members) => {
        let member_keys = members.map(fn(entry) { entry.key })
        if i == 0 {
          keys = member_keys
          for entry in @fshared.key_position_index(keys).to_array() {
            key_index.set(entry.0, entry.1)
          }
          has_key_index = true
          rows.push(keys)
        } else if !has_key_index ||
          !@fshared.keys_match_position_index(keys, key_index, member_keys) {
          return None
        }
        rows.push(json_members_to_row(members, keys))
      }
      _ => return None
    }
  }
  if rows.length() == 0 {
    None
  } else {
    Some(rows)
  }
}

///|
fn json_members_to_row(
  members : Array[@djson.JsonMember],
  keys : Array[String],
) -> Array[String] {
  let member_index : Map[String, Int] = Map([])
  for i in 0..<members.length() {
    member_index.set(members[i].key, i)
  }
  @fshared.projected_row_from_key_index(keys, member_index, fn(index) {
    json_value_cell(members[index].value)
  })
}

///|
fn json_array_of_scalars(values : Array[@djson.JsonValue]) -> Bool {
  for value in values {
    match value {
      String(_) | Number(_) | Bool(_) | Null => ()
      _ => return false
    }
  }
  true
}

///|
fn json_value_cell(value : @djson.JsonValue) -> String {
  match value {
    String(text) => text
    Number(text) => text
    Bool(value) => if value { "true" } else { "false" }
    Null => "null"
    _ => stringify_json_value(value)
  }
}

///|
fn json_scalar_text(value : @djson.JsonValue) -> String {
  json_value_cell(value)
}

///|
fn json_pointer_source_ref(
  source : @input.InputSource,
  format_name : String,
  pointer : String,
) -> @core.SourceRef {
  @core.source_ref_with_json_pointer(
    @core.empty_source_ref(),
    Some(source.source_name),
    Some(format_name),
    Some(pointer),
  )
}

///|
fn json_append_pointer(pointer : String, segment : String) -> String {
  if pointer == "/" {
    "/" + segment
  } else {
    pointer + "/" + segment
  }
}

///|
fn json_code_block(
  text : String,
  source : @input.InputSource,
  format_name : String,
  pointer : String,
  include_info : Bool,
) -> @core.CoreBlock {
  let block = @core.make_block(
    Code,
    text,
    source_ref=json_pointer_source_ref(source, format_name, pointer),
  )
  if include_info {
    block.attrs.set("info", format_name)
  }
  block
}

///|
fn stringify_json_value(value : @djson.JsonValue) -> String {
  match value {
    Object(members) => {
      let parts : Array[String] = []
      for entry in members {
        parts.push(
          quote_json_string(entry.key) + ":" + stringify_json_value(entry.value),
        )
      }
      "{" + parts.join(",") + "}"
    }
    Array(values) => {
      let parts : Array[String] = []
      for entry in values {
        parts.push(stringify_json_value(entry))
      }
      "[" + parts.join(",") + "]"
    }
    String(text) => quote_json_string(text)
    Number(text) => text
    Bool(value) => if value { "true" } else { "false" }
    Null => "null"
  }
}

///|
fn quote_json_string(text : String) -> String {
  let out : Array[Char] = ['"']
  for ch in text.to_array() {
    match ch {
      '"' => {
        out.push('\\')
        out.push('"')
      }
      '\\' => {
        out.push('\\')
        out.push('\\')
      }
      '\n' => {
        out.push('\\')
        out.push('n')
      }
      '\r' => {
        out.push('\\')
        out.push('r')
      }
      '\t' => {
        out.push('\\')
        out.push('t')
      }
      _ => out.push(ch)
    }
  }
  out.push('"')
  String::from_array(out)
}
