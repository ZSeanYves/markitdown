///|
fn json_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    @parser.ParserMode::DomAstModel,
    true,
    @parser.StreamingGranularity::JsonStructure,
    false,
    true,
    false,
    true,
    false,
    true,
    true,
    true,
    false,
    true,
    false,
    true,
    true,
    true,
    true,
    false,
  )
}

///|
fn jsonl_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    @parser.ParserMode::StreamingEvent,
    true,
    @parser.StreamingGranularity::Record,
    false,
    true,
    false,
    true,
    false,
    true,
    true,
    true,
    false,
    true,
    false,
    true,
    true,
    true,
    true,
    false,
  )
}

///|
fn ndjson_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    @parser.ParserMode::StreamingEvent,
    true,
    @parser.StreamingGranularity::Record,
    false,
    true,
    false,
    true,
    false,
    false,
    true,
    true,
    false,
    true,
    false,
    true,
    true,
    true,
    true,
    false,
  )
}

///|
fn line_delimited_code_event_source_ref(
  source : @input.InputSource,
  format_name : String,
  pointer : String,
  line_no : Int,
) -> @core.SourceRef {
  let source_ref = @core.source_ref_with_lines(
    json_pointer_source_ref(source, format_name, pointer),
    Some(source.source_name),
    Some(format_name),
    Some(line_no),
    Some(line_no),
  )
  @core.source_ref_with_extra(source_ref, "ir_block_attr_info", format_name)
}

///|
pub fn json_lite_parser() -> @parser.Parser {
  @parser.make_parser(
    "json_parser",
    @parser.ParserMode::DomAstModel,
    json_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      parse_json_document_result(source, context)
    },
  )
}

///|
pub fn jsonl_lite_parser() -> @parser.Parser {
  @parser.make_parser(
    "jsonl_parser",
    @parser.ParserMode::StreamingEvent,
    jsonl_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      parse_line_delimited_json_result("jsonl_parser", "jsonl", source, context)
    },
  )
}

///|
pub fn ndjson_lite_parser() -> @parser.Parser {
  @parser.make_parser(
    "ndjson_parser",
    @parser.ParserMode::StreamingEvent,
    ndjson_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      parse_line_delimited_json_result(
        "ndjson_parser", "ndjson", source, context,
      )
    },
  )
}

///|
fn parse_json_document_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Result[@parser.ParseResult, String] {
  let text = match @input.read_input_text(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let diagnostics = @light_common.empty_parser_diagnostics(
    "json_parser",
    @parser.ParserMode::DomAstModel,
    source,
    "json",
  )
  diagnostics.metrics.set("parser_name", "json_parser")
  diagnostics.metrics.set("parser_mode", "dom_ast_model")
  diagnostics.metrics.set(
    "input_kind",
    @light_common.input_kind_name(source.kind),
  )
  diagnostics.metrics.set("detected_format", "json")
  diagnostics.metrics.set(
    "requested_mode",
    @light_common.requested_mode_name(context),
  )
  diagnostics.metrics.set("ir_input_kind", "document")
  @light_common.apply_readiness_metrics(diagnostics, "json", "near_ready")
  let parsed = try @djson.parse_json_document(text) |> Ok catch {
    e => Err(e.to_string())
  }
  match parsed {
    Ok(doc) => {
      let inspect = @djson.inspect_json_document(doc)
      let dom_limit_reached = json_dom_limit_reached(context, inspect)
      if dom_limit_reached {
        let streamed = try @djson.parse_json_stream(text) |> Ok catch {
          e => Err(e.to_string())
        }
        match streamed {
          Ok(stream) => {
            let document = lower_json_document(doc, text, source, diagnostics)
            let events = @pipeline.blocks_to_event_stream(document.blocks)
            if events.length() > 0 {
              let first_ref = events[0].source_ref.unwrap_or(
                @core.empty_source_ref(),
              )
              let first_stream_ref = json_stream_source_ref(
                source,
                stream.events[0].pointer,
                stream.events[0].source.line,
                stream.events[0].source.byte_start,
                stream.events[0].source.byte_end,
              )
              events[0] = {
                ..events[0],
                source_ref: Some(
                  merge_stream_bytes_into_source_ref(
                    first_ref, first_stream_ref,
                  ),
                ),
              }
            }
            diagnostics.metrics.set("parser_mode", "streaming_event")
            diagnostics.metrics.set(
              "requested_mode",
              @light_common.requested_mode_name(context),
            )
            diagnostics.metrics.set("effective_mode", "streaming_event")
            diagnostics.metrics.set("ir_input_kind", "event_stream")
            diagnostics.metrics.set("dom_limit_reached", "true")
            diagnostics.metrics.set("streaming_fallback", "true")
            diagnostics.metrics.set("json_valid", "true")
            diagnostics.metrics.set("root_kind", stream.summary.root_kind)
            diagnostics.metrics.set("record_count", "1")
            diagnostics.metrics.set(
              "object_count",
              stream.summary.object_count.to_string(),
            )
            diagnostics.metrics.set(
              "array_count",
              stream.summary.array_count.to_string(),
            )
            diagnostics.metrics.set(
              "scalar_count",
              stream.summary.scalar_count.to_string(),
            )
            diagnostics.metrics.set(
              "max_depth_observed",
              stream.summary.max_depth.to_string(),
            )
            diagnostics.metrics.set("invalid_record_count", "0")
            diagnostics.metrics.set(
              "table_count",
              count_json_tables(document).to_string(),
            )
            diagnostics.metrics.set("image_count", "0")
            diagnostics.metrics.set("asset_count", "0")
            diagnostics.metrics.set(
              "block_count",
              document.blocks.length().to_string(),
            )
            diagnostics.metrics.set("event_count", events.length().to_string())
            diagnostics.metrics.set("event_granularity", "json_structure")
            diagnostics.metrics.set(
              "event_semantics", "json_structure_event_stream",
            )
            diagnostics.metrics.set(
              "json_token_count",
              stream.summary.token_count.to_string(),
            )
            diagnostics.metrics.set("syntax_error_count", "0")
            diagnostics.metrics.set(
              "degraded_feature_count",
              diagnostics.degraded_features.length().to_string(),
            )
            diagnostics.metrics.set(
              "fallback_count",
              diagnostics.fallback_trace.length().to_string(),
            )
            diagnostics.pass_trace.push("parse:json_parser")
            return Ok(
              @parser.parse_result_with_events_capability(
                "json_parser",
                @parser.ParserMode::StreamingEvent,
                events,
                diagnostics,
                json_parser_capability(),
              ),
            )
          }
          Err(err) => {
            let fallback = malformed_json_parse_result(
              "json_parser",
              "json",
              source,
              text,
              diagnostics,
              err,
              json_parser_capability(),
            )
            return Ok(fallback)
          }
        }
      }
      let document = lower_json_document(doc, text, source, diagnostics)
      diagnostics.metrics.set("effective_mode", "dom_ast_model")
      diagnostics.metrics.set("streaming_fallback", "false")
      diagnostics.metrics.set(
        "dom_limit_reached",
        @light_common.bool_string(dom_limit_reached),
      )
      diagnostics.metrics.set("json_valid", "true")
      diagnostics.metrics.set("root_kind", inspect.root_kind)
      diagnostics.metrics.set("record_count", "1")
      diagnostics.metrics.set("object_count", inspect.object_count.to_string())
      diagnostics.metrics.set("array_count", inspect.array_count.to_string())
      diagnostics.metrics.set("scalar_count", inspect.scalar_count.to_string())
      diagnostics.metrics.set(
        "max_depth_observed",
        inspect.max_depth.to_string(),
      )
      diagnostics.metrics.set("invalid_record_count", "0")
      diagnostics.metrics.set(
        "table_count",
        count_json_tables(document).to_string(),
      )
      diagnostics.metrics.set("image_count", "0")
      diagnostics.metrics.set("asset_count", "0")
      diagnostics.metrics.set(
        "block_count",
        document.blocks.length().to_string(),
      )
      diagnostics.metrics.set("event_count", "0")
      diagnostics.metrics.set("event_granularity", "none")
      diagnostics.metrics.set("event_semantics", "dom_ast_model")
      diagnostics.metrics.set("json_token_count", "0")
      diagnostics.metrics.set("syntax_error_count", "0")
      diagnostics.metrics.set(
        "degraded_feature_count",
        diagnostics.degraded_features.length().to_string(),
      )
      diagnostics.metrics.set(
        "fallback_count",
        diagnostics.fallback_trace.length().to_string(),
      )
      diagnostics.pass_trace.push("parse:json_parser")
      let final_document = @core.document_with_diagnostics(
        document, diagnostics,
      )
      Ok(
        @parser.parse_result_with_document_capability(
          "json_parser",
          @parser.ParserMode::DomAstModel,
          final_document,
          diagnostics,
          json_parser_capability(),
        ),
      )
    }
    Err(err) => {
      let fallback = malformed_json_parse_result(
        "json_parser",
        "json",
        source,
        text,
        diagnostics,
        err,
        json_parser_capability(),
      )
      Ok(fallback)
    }
  }
}

///|
fn parse_line_delimited_json_result(
  parser_name : String,
  format_name : String,
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Result[@parser.ParseResult, String] {
  let text = match @input.read_input_text(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let diagnostics = @light_common.empty_parser_diagnostics(
    parser_name,
    @parser.ParserMode::StreamingEvent,
    source,
    format_name,
  )
  diagnostics.metrics.set("parser_name", parser_name)
  diagnostics.metrics.set("parser_mode", "streaming_event")
  diagnostics.metrics.set(
    "input_kind",
    @light_common.input_kind_name(source.kind),
  )
  diagnostics.metrics.set("detected_format", format_name)
  diagnostics.metrics.set(
    "requested_mode",
    @light_common.requested_mode_name(context),
  )
  diagnostics.metrics.set("effective_mode", "streaming_event")
  diagnostics.metrics.set("ir_input_kind", "event_stream")
  diagnostics.metrics.set("event_granularity", "record")
  diagnostics.metrics.set("event_semantics", "record_event_stream")
  @light_common.apply_readiness_metrics(diagnostics, format_name, "near_ready")
  let result = lower_line_delimited_json_events(
    format_name, text, source, context,
  )
  match result {
    Ok((events, row_count, object_count, array_count, scalar_count, max_depth)) => {
      diagnostics.metrics.set("record_count", row_count.to_string())
      diagnostics.metrics.set("row_count", row_count.to_string())
      diagnostics.metrics.set("object_count", object_count.to_string())
      diagnostics.metrics.set("array_count", array_count.to_string())
      diagnostics.metrics.set("scalar_count", scalar_count.to_string())
      diagnostics.metrics.set("max_depth_observed", max_depth.to_string())
      diagnostics.metrics.set("invalid_record_count", "0")
      diagnostics.metrics.set(
        "table_count",
        infer_line_json_table_count(events).to_string(),
      )
      diagnostics.metrics.set("image_count", "0")
      diagnostics.metrics.set("asset_count", "0")
      diagnostics.metrics.set("block_count", row_count.to_string())
      diagnostics.metrics.set("event_count", events.length().to_string())
      diagnostics.metrics.set("record_count_emitted", row_count.to_string())
      diagnostics.metrics.set(
        "degraded_feature_count",
        diagnostics.degraded_features.length().to_string(),
      )
      diagnostics.metrics.set(
        "fallback_count",
        diagnostics.fallback_trace.length().to_string(),
      )
      diagnostics.pass_trace.push("parse:" + parser_name)
      Ok(
        @parser.parse_result_with_events_capability(
          parser_name,
          @parser.ParserMode::StreamingEvent,
          events,
          diagnostics,
          if format_name == "jsonl" {
            jsonl_parser_capability()
          } else {
            ndjson_parser_capability()
          },
        ),
      )
    }
    Err(err) => {
      let fallback = malformed_json_parse_result(
        parser_name,
        format_name,
        source,
        text,
        diagnostics,
        err,
        if format_name == "jsonl" {
          jsonl_parser_capability()
        } else {
          ndjson_parser_capability()
        },
      )
      Ok(fallback)
    }
  }
}

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
) -> Result[(Array[@core.CoreEvent], Int, Int, Int, Int, Int), String] {
  let lines = text.split("\n").to_array()
  let events : Array[@core.CoreEvent] = []
  let object_rows : Array[Array[String]] = []
  let mut object_count = 0
  let mut array_count = 0
  let mut scalar_count = 0
  let mut max_depth = 0
  let mut record_index = 0
  let max_rows = context.max_rows.unwrap_or(200)
  let mut header_keys : Array[String]? = None
  let record_line_numbers : Array[Int] = []
  let record_pointers : Array[String] = []
  for i in 0..<lines.length() {
    let raw_line = lines[i].trim().to_owned()
    if raw_line == "" {
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
          Some(existing) if !same_key_set(existing, keys) =>
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
        ),
      )
    }
    _ =>
      Ok(
        (
          events, record_index, object_count, array_count, scalar_count, max_depth,
        ),
      )
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
fn infer_line_json_table_count(events : Array[@core.CoreEvent]) -> Int {
  let mut cell_count = 0
  for event in events {
    if event.kind == @core.EventKind::Cell {
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
    Some(@light_common.count_physical_lines(text)),
  )
  let block = @core.make_block(@core.BlockKind::Code, text, source_ref~)
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
    @light_common.input_kind_name(source.kind),
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
  diagnostics.metrics.set("streaming_fallback", "false")
  diagnostics.metrics.set("dom_limit_reached", "false")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set(
    "event_granularity",
    if capability.parser_mode == @parser.ParserMode::StreamingEvent {
      "json_structure"
    } else {
      "none"
    },
  )
  diagnostics.metrics.set(
    "event_semantics",
    if capability.parser_mode == @parser.ParserMode::StreamingEvent {
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
  let table = @core.make_block(
    @core.BlockKind::Table,
    "table",
    source_ref=json_pointer_source_ref(source, format_name, pointer),
  )
  table.attrs.set("header_rows", "1")
  for row_index in 0..<rows.length() {
    let row_values = rows[row_index]
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
        "R" +
        (row_index + 1).to_string() +
        "C1:R" +
        (row_index + 1).to_string() +
        "C" +
        row_values.length().to_string(),
      ),
    )
    let row = @core.make_block(
      @core.BlockKind::TableRow,
      row_values.join(" | "),
      source_ref=row_ref,
    )
    for col_index in 0..<row_values.length() {
      row.children.push(
        @core.make_block(
          @core.BlockKind::TableCell,
          row_values[col_index],
          source_ref=@core.source_ref_with_cell_range(
            row_ref,
            Some(source.source_name),
            Some(format_name),
            Some(
              "R" +
              (row_index + 1).to_string() +
              "C" +
              (col_index + 1).to_string(),
            ),
          ),
        ),
      )
    }
    table.children.push(row)
  }
  table
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
        kind: @core.EventKind::Cell,
        text: row[col_index],
        source_ref: Some(cell_ref),
      })
    }
    if row.length() > 0 {
      events.push({
        kind: @core.EventKind::RowBreak,
        text: "",
        source_ref: Some(row_ref),
      })
    }
  }
  events
}

///|
fn count_json_tables(document : @core.DocumentIR) -> Int {
  @light_common.count_blocks_by_kind(document.blocks, @core.BlockKind::Table)
}

///|
fn json_array_object_rows(
  values : Array[@djson.JsonValue],
) -> Array[Array[String]]? {
  let mut keys : Array[String] = []
  let rows : Array[Array[String]] = []
  for i in 0..<values.length() {
    match values[i] {
      @djson.JsonValue::Object(members) => {
        let member_keys = members.map(fn(entry) { entry.key })
        if i == 0 {
          keys = member_keys
          rows.push(keys)
        } else if !same_key_set(keys, member_keys) {
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
  let row : Array[String] = []
  for key in keys {
    row.push(json_member_value_cell(members, key))
  }
  row
}

///|
fn json_member_value_cell(
  members : Array[@djson.JsonMember],
  key : String,
) -> String {
  for entry in members {
    if entry.key == key {
      return json_value_cell(entry.value)
    }
  }
  ""
}

///|
fn json_array_of_scalars(values : Array[@djson.JsonValue]) -> Bool {
  for value in values {
    match value {
      @djson.JsonValue::String(_)
      | @djson.JsonValue::Number(_)
      | @djson.JsonValue::Bool(_)
      | @djson.JsonValue::Null => ()
      _ => return false
    }
  }
  true
}

///|
fn json_value_cell(value : @djson.JsonValue) -> String {
  match value {
    @djson.JsonValue::String(text) => text
    @djson.JsonValue::Number(text) => text
    @djson.JsonValue::Bool(value) => if value { "true" } else { "false" }
    @djson.JsonValue::Null => "null"
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
    @core.BlockKind::Code,
    text,
    source_ref=json_pointer_source_ref(source, format_name, pointer),
  )
  if include_info {
    block.attrs.set("info", format_name)
  }
  block
}

///|
fn json_dom_limit_reached(
  context : @parser.ParseContext,
  inspect : @djson.JsonInspectReport,
) -> Bool {
  let row_limit = context.max_rows.unwrap_or(200)
  let cell_limit = context.max_cells.unwrap_or(10000)
  inspect.node_count > cell_limit || inspect.object_count > row_limit
}

///|
fn same_key_set(a : Array[String], b : Array[String]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for value in a {
    if !contains_string(b, value) {
      return false
    }
  }
  true
}

///|
fn contains_string(items : Array[String], target : String) -> Bool {
  for item in items {
    if item == target {
      return true
    }
  }
  false
}

///|
fn stringify_json_value(value : @djson.JsonValue) -> String {
  match value {
    @djson.JsonValue::Object(members) => {
      let parts : Array[String] = []
      for entry in members {
        parts.push(
          quote_json_string(entry.key) + ":" + stringify_json_value(entry.value),
        )
      }
      "{" + parts.join(",") + "}"
    }
    @djson.JsonValue::Array(values) => {
      let parts : Array[String] = []
      for entry in values {
        parts.push(stringify_json_value(entry))
      }
      "[" + parts.join(",") + "]"
    }
    @djson.JsonValue::String(text) => quote_json_string(text)
    @djson.JsonValue::Number(text) => text
    @djson.JsonValue::Bool(value) => if value { "true" } else { "false" }
    @djson.JsonValue::Null => "null"
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
