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
pub fn json_parser() -> @parser.Parser {
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
pub fn jsonl_parser() -> @parser.Parser {
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
pub fn ndjson_parser() -> @parser.Parser {
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
pub fn json_parse_with_stream_document(
  source : @input.InputSource,
  context : @parser.ParseContext,
  text : String,
  stream : @djson.JsonStreamDocument,
) -> @parser.ParseResult {
  let diagnostics = @parser_common.empty_parser_diagnostics(
    "json_parser",
    @parser.ParserMode::DomAstModel,
    source,
    "json",
  )
  diagnostics.metrics.set("parser_name", "json_parser")
  diagnostics.metrics.set("parser_mode", "dom_ast_model")
  diagnostics.metrics.set(
    "input_kind",
    @parser_common.input_kind_name(source.kind),
  )
  diagnostics.metrics.set("detected_format", "json")
  diagnostics.metrics.set(
    "requested_mode",
    @parser_common.requested_mode_name(context),
  )
  diagnostics.metrics.set("ir_input_kind", "event_stream")
  @parser_common.apply_product_metrics(diagnostics, "json")
  let events = json_generic_block_events_from_stream(stream, source)
  diagnostics.metrics.set("parser_mode", "streaming_event")
  diagnostics.metrics.set("effective_mode", "streaming_event")
  diagnostics.metrics.set("dom_limit_reached", "false")
  diagnostics.metrics.set("json_valid", "true")
  diagnostics.metrics.set("root_kind", stream.summary.root_kind)
  diagnostics.metrics.set("record_count", "1")
  diagnostics.metrics.set(
    "object_count",
    stream.summary.object_count.to_string(),
  )
  diagnostics.metrics.set("array_count", stream.summary.array_count.to_string())
  diagnostics.metrics.set(
    "scalar_count",
    stream.summary.scalar_count.to_string(),
  )
  diagnostics.metrics.set(
    "max_depth_observed",
    stream.summary.max_depth.to_string(),
  )
  diagnostics.metrics.set("invalid_record_count", "0")
  diagnostics.metrics.set("table_count", count_event_tables(events).to_string())
  diagnostics.metrics.set("image_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("block_count", count_event_blocks(events).to_string())
  diagnostics.metrics.set("event_count", events.length().to_string())
  diagnostics.metrics.set("event_granularity", "json_structure")
  diagnostics.metrics.set("event_semantics", "json_structure_event_stream")
  diagnostics.metrics.set(
    "json_token_count",
    stream.summary.token_count.to_string(),
  )
  diagnostics.metrics.set("syntax_error_count", "0")
  diagnostics.metrics.set("char_count", text.length().to_string())
  diagnostics.metrics.set(
    "degraded_feature_count",
    diagnostics.degraded_features.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
  diagnostics.pass_trace.push("parse:json_parser")
  @parser.parse_result_with_events_capability(
    "json_parser",
    @parser.ParserMode::StreamingEvent,
    events,
    diagnostics,
    json_parser_capability(),
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
  let diagnostics = @parser_common.empty_parser_diagnostics(
    "json_parser",
    @parser.ParserMode::DomAstModel,
    source,
    "json",
  )
  diagnostics.metrics.set("parser_name", "json_parser")
  diagnostics.metrics.set("parser_mode", "dom_ast_model")
  diagnostics.metrics.set(
    "input_kind",
    @parser_common.input_kind_name(source.kind),
  )
  diagnostics.metrics.set("detected_format", "json")
  diagnostics.metrics.set(
    "requested_mode",
    @parser_common.requested_mode_name(context),
  )
  let requested_streaming = context.requested_mode ==
    Some(@parser.ParserMode::StreamingEvent)
  diagnostics.metrics.set(
    "ir_input_kind",
    if requested_streaming {
      "event_stream"
    } else {
      "document"
    },
  )
  @parser_common.apply_product_metrics(diagnostics, "json")
  if requested_streaming {
    let streamed = try @djson.parse_json_stream(text) |> Ok catch {
      e => Err(e.to_string())
    }
    match streamed {
      Ok(stream) => {
        let events = json_generic_block_events_from_stream(stream, source)
        diagnostics.metrics.set("parser_mode", "streaming_event")
        diagnostics.metrics.set("effective_mode", "streaming_event")
        diagnostics.metrics.set("dom_limit_reached", "false")
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
          count_event_tables(events).to_string(),
        )
        diagnostics.metrics.set("image_count", "0")
        diagnostics.metrics.set("asset_count", "0")
        diagnostics.metrics.set(
          "block_count",
          count_event_blocks(events).to_string(),
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
      Err(err) =>
        return Ok(
          malformed_json_parse_result(
            "json_parser",
            "json",
            source,
            text,
            diagnostics,
            err,
            json_parser_capability(),
          ),
        )
    }
  }
  let parsed = try @djson.parse_json_document(text) |> Ok catch {
    e => Err(e.to_string())
  }
  match parsed {
    Ok(doc) => {
      let inspect = @djson.inspect_json_document(doc)
      let document = lower_json_document(doc, text, source, diagnostics)
      diagnostics.metrics.set("effective_mode", "dom_ast_model")
      diagnostics.metrics.set("dom_limit_reached", "false")
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
  let diagnostics = @parser_common.empty_parser_diagnostics(
    parser_name,
    @parser.ParserMode::StreamingEvent,
    source,
    format_name,
  )
  diagnostics.metrics.set("parser_name", parser_name)
  diagnostics.metrics.set("parser_mode", "streaming_event")
  diagnostics.metrics.set(
    "input_kind",
    @parser_common.input_kind_name(source.kind),
  )
  diagnostics.metrics.set("detected_format", format_name)
  diagnostics.metrics.set(
    "requested_mode",
    @parser_common.requested_mode_name(context),
  )
  diagnostics.metrics.set("effective_mode", "streaming_event")
  diagnostics.metrics.set("ir_input_kind", "event_stream")
  diagnostics.metrics.set("event_granularity", "record")
  diagnostics.metrics.set("event_semantics", "record_event_stream")
  @parser_common.apply_product_metrics(diagnostics, format_name)
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
