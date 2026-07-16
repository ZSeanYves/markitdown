///|
fn json_parser_capability() -> @parser.ParserCapability {
  @parser.dom_ast_parser_capability(
    JsonStructure,
    true,
    true,
    false,
    true,
    true,
    true,
    true,
    true,
    true,
    false,
  )
}

///|
fn jsonl_parser_capability() -> @parser.ParserCapability {
  @parser.streaming_event_parser_capability(
    Record,
    true,
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
  @parser.streaming_event_parser_capability(
    Record,
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
  @parser.make_parser("json_parser", DomAstModel, json_parser_capability(), fn(
    source : @input.InputSource,
    context : @parser.ParseContext,
  ) -> Result[@parser.ParseResult, String] {
    parse_json_document_result(source, context)
  })
}

///|
pub fn jsonl_parser() -> @parser.Parser {
  @parser.make_parser(
    "jsonl_parser",
    StreamingEvent,
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
    StreamingEvent,
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
  let diagnostics = @fshared.empty_parser_diagnostics(
    "json_parser",
    DomAstModel,
    source,
    "json",
  )
  @fshared.init_parser_route_metrics_with_granularity(
    diagnostics,
    source,
    context,
    "json",
    "json_parser",
    DomAstModel,
    StreamingEvent,
    "event_stream",
    JsonStructure,
    "json_structure_event_stream",
  )
  @fshared.apply_product_metrics(diagnostics, "json")
  let events = if stream.events.length() == 0 &&
    stream.summary.root_kind == "array" {
    match json_compact_root_array_events_direct(text, source) {
      Ok(value) => value
      Err(_) => json_generic_block_events_from_stream(stream, source)
    }
  } else {
    json_generic_block_events_from_stream(stream, source)
  }
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
  diagnostics.metrics.set(
    "json_token_count",
    stream.summary.token_count.to_string(),
  )
  diagnostics.metrics.set("syntax_error_count", "0")
  diagnostics.metrics.set("char_count", text.length().to_string())
  @fshared.refresh_parser_count_metrics(diagnostics, "event_stream")
  diagnostics.pass_trace.push("parse:json_parser")
  @parser.parse_result_with_events_capability(
    "json_parser",
    StreamingEvent,
    events,
    diagnostics,
    json_parser_capability(),
  )
}

///|
pub fn json_parse_with_prepared_document(
  source : @input.InputSource,
  context : @parser.ParseContext,
  prepared : @djson.PreparedJsonText,
) -> @parser.ParseResult {
  let requested_streaming = context.requested_mode == Some(StreamingEvent)
  if requested_streaming {
    match prepared.stream {
      Some(stream) => {
        let parsed = json_parse_with_stream_document(
          source,
          context,
          prepared.original_text,
          stream,
        )
        parsed.diagnostics.metrics.set("probe_artifact_reused", "true")
        parsed
      }
      None => {
        let diagnostics = @fshared.empty_parser_diagnostics(
          "json_parser",
          DomAstModel,
          source,
          "json",
        )
        @fshared.init_parser_route_metrics_with_granularity(
          diagnostics,
          source,
          context,
          "json",
          "json_parser",
          DomAstModel,
          StreamingEvent,
          "event_stream",
          JsonStructure,
          "json_structure_event_stream",
        )
        @fshared.apply_product_metrics(diagnostics, "json")
        malformed_json_parse_result(
          "json_parser",
          "json",
          source,
          prepared.original_text,
          diagnostics,
          prepared.parse_error.unwrap_or("unknown"),
          json_parser_capability(),
        )
      }
    }
  } else {
    match parse_json_document_result(source, context) {
      Ok(result) => result
      Err(err) => {
        let diagnostics = @fshared.empty_parser_diagnostics(
          "json_parser",
          DomAstModel,
          source,
          "json",
        )
        malformed_json_parse_result(
          "json_parser",
          "json",
          source,
          prepared.original_text,
          diagnostics,
          err,
          json_parser_capability(),
        )
      }
    }
  }
}

///|
fn parse_json_document_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Result[@parser.ParseResult, String] {
  let prepared = match @djson.prepare_json_document_from_source(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let source = prepared.prepared_source
  let text = prepared.original_text
  let diagnostics = @fshared.empty_parser_diagnostics(
    "json_parser",
    DomAstModel,
    source,
    "json",
  )
  let requested_streaming = context.requested_mode == Some(StreamingEvent)
  @fshared.init_parser_route_metrics_with_granularity(
    diagnostics,
    source,
    context,
    "json",
    "json_parser",
    DomAstModel,
    if requested_streaming {
      StreamingEvent
    } else {
      DomAstModel
    },
    if requested_streaming {
      "event_stream"
    } else {
      "document"
    },
    if requested_streaming {
      JsonStructure
    } else {
      None
    },
    if requested_streaming {
      "json_structure_event_stream"
    } else {
      "dom_ast_model"
    },
  )
  @fshared.apply_product_metrics(diagnostics, "json")
  if requested_streaming {
    match prepared.stream {
      Some(stream) => {
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
        diagnostics.metrics.set(
          "json_token_count",
          stream.summary.token_count.to_string(),
        )
        diagnostics.metrics.set("syntax_error_count", "0")
        @fshared.refresh_parser_count_metrics(diagnostics, "event_stream")
        diagnostics.pass_trace.push("parse:json_parser")
        return Ok(
          @parser.parse_result_with_events_capability(
            "json_parser",
            StreamingEvent,
            events,
            diagnostics,
            json_parser_capability(),
          ),
        )
      }
      None =>
        return Ok(
          malformed_json_parse_result(
            "json_parser",
            "json",
            source,
            text,
            diagnostics,
            prepared.parse_error.unwrap_or("unknown"),
            json_parser_capability(),
          ),
        )
    }
  }
  match prepared.document {
    Some(doc) => {
      let inspect = prepared.inspect.unwrap_or(
        @djson.inspect_json_document(doc),
      )
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
      diagnostics.metrics.set("json_token_count", "0")
      diagnostics.metrics.set("syntax_error_count", "0")
      @fshared.mark_structured_document_profile(diagnostics)
      @fshared.refresh_parser_count_metrics(diagnostics, "document")
      diagnostics.pass_trace.push("parse:json_parser")
      let final_document = @core.document_with_diagnostics(
        document, diagnostics,
      )
      Ok(
        @parser.parse_result_with_document_capability(
          "json_parser",
          DomAstModel,
          final_document,
          diagnostics,
          json_parser_capability(),
        ),
      )
    }
    None => {
      let fallback = malformed_json_parse_result(
        "json_parser",
        "json",
        source,
        text,
        diagnostics,
        prepared.parse_error.unwrap_or("unknown"),
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
  let prepared = match @djson.prepare_json_document_from_source(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let source = prepared.prepared_source
  let text = prepared.original_text
  let diagnostics = @fshared.empty_parser_diagnostics(
    parser_name,
    StreamingEvent,
    source,
    format_name,
  )
  @fshared.init_parser_route_metrics_with_granularity(
    diagnostics,
    source,
    context,
    format_name,
    parser_name,
    StreamingEvent,
    StreamingEvent,
    "event_stream",
    Record,
    "record_event_stream",
  )
  @fshared.apply_product_metrics(diagnostics, format_name)
  let result = lower_line_delimited_json_events(
    format_name, text, source, context,
  )
  match result {
    Ok(
      (
        events,
        row_count,
        object_count,
        array_count,
        scalar_count,
        max_depth,
        blank_line_count,
      )
    ) => {
      diagnostics.metrics.set("record_count", row_count.to_string())
      diagnostics.metrics.set("row_count", row_count.to_string())
      diagnostics.metrics.set("object_count", object_count.to_string())
      diagnostics.metrics.set("array_count", array_count.to_string())
      diagnostics.metrics.set("scalar_count", scalar_count.to_string())
      diagnostics.metrics.set("max_depth_observed", max_depth.to_string())
      diagnostics.metrics.set("blank_line_count", blank_line_count.to_string())
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
      if blank_line_count > 0 {
        diagnostics.warnings.push(
          "blank " +
          format_name +
          " line(s) skipped: " +
          blank_line_count.to_string(),
        )
        diagnostics.degraded_features.push(format_name + "_blank_line_skipped")
        diagnostics.fallback_trace.push(
          format_name + " blank line -> skip empty record",
        )
      }
      @fshared.refresh_parser_count_metrics(diagnostics, "event_stream")
      diagnostics.pass_trace.push("parse:" + parser_name)
      Ok(
        @parser.parse_result_with_events_capability(
          parser_name,
          StreamingEvent,
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
