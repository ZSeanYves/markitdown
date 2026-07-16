///|
fn yaml_parser_capability() -> @parser.ParserCapability {
  @parser.dom_ast_parser_capability(
    YamlStructure,
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
pub fn yaml_parser() -> @parser.Parser {
  @parser.make_parser("yaml_parser", DomAstModel, yaml_parser_capability(), fn(
    source : @input.InputSource,
    context : @parser.ParseContext,
  ) -> Result[@parser.ParseResult, String] {
    parse_yaml_document_result(source, context)
  })
}

///|
pub fn yaml_parse_with_structure_events(
  source : @input.InputSource,
  context : @parser.ParseContext,
  text : String,
  inspect : @dyaml.YamlInspectReport,
  events : Array[@dyaml.YamlStructureEvent],
) -> @parser.ParseResult {
  let diagnostics = @fshared.empty_parser_diagnostics(
    "yaml_parser",
    DomAstModel,
    source,
    "yaml",
  )
  @fshared.init_parser_route_metrics_with_granularity(
    diagnostics,
    source,
    context,
    "yaml",
    "yaml_parser",
    DomAstModel,
    StreamingEvent,
    "event_stream",
    YamlStructure,
    "yaml_structure_event_stream",
  )
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("dom_limit_reached", "false")
  @fshared.apply_product_metrics(diagnostics, "yaml")
  yaml_streaming_parse_result(source, text, diagnostics, inspect, events)
}

///|
pub fn yaml_parse_with_prepared_document(
  source : @input.InputSource,
  context : @parser.ParseContext,
  prepared : @dyaml.PreparedYamlDocument,
) -> @parser.ParseResult {
  if context.requested_mode == Some(StreamingEvent) {
    match prepared.compact_sequence {
      Some(compact) => {
        let parsed = yaml_parse_with_compact_sequence(
          source,
          context,
          prepared.original_text,
          compact,
        )
        parsed.diagnostics.metrics.set("probe_artifact_reused", "true")
        return parsed
      }
      None => ()
    }
    match prepared.events {
      Some(events) => {
        let parsed = yaml_parse_with_structure_events(
          source,
          context,
          prepared.original_text,
          prepared.inspect.unwrap_or(
            @dyaml.inspect_yaml_structure_events(events),
          ),
          events,
        )
        parsed.diagnostics.metrics.set("probe_artifact_reused", "true")
        parsed
      }
      None => {
        let diagnostics = @fshared.empty_parser_diagnostics(
          "yaml_parser",
          DomAstModel,
          source,
          "yaml",
        )
        @fshared.init_parser_route_metrics_with_granularity(
          diagnostics,
          source,
          context,
          "yaml",
          "yaml_parser",
          DomAstModel,
          StreamingEvent,
          "event_stream",
          YamlStructure,
          "yaml_structure_event_stream",
        )
        diagnostics.metrics.set("resource_limit_hit", "false")
        diagnostics.metrics.set("dom_limit_reached", "false")
        @fshared.apply_product_metrics(diagnostics, "yaml")
        yaml_malformed_parse_result(
          source,
          prepared.original_text,
          diagnostics,
          prepared.parse_error.unwrap_or("unknown"),
        )
      }
    }
  } else {
    match parse_yaml_document_result(source, context) {
      Ok(result) => result
      Err(err) => {
        let diagnostics = @fshared.empty_parser_diagnostics(
          "yaml_parser",
          DomAstModel,
          source,
          "yaml",
        )
        yaml_malformed_parse_result(
          source,
          prepared.original_text,
          diagnostics,
          err,
        )
      }
    }
  }
}

///|
fn parse_yaml_document_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Result[@parser.ParseResult, String] {
  let prepared = match @dyaml.prepare_yaml_document_from_source(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let source = prepared.prepared_source
  let text = prepared.original_text
  let diagnostics = @fshared.empty_parser_diagnostics(
    "yaml_parser",
    DomAstModel,
    source,
    "yaml",
  )
  let requested_streaming = context.requested_mode == Some(StreamingEvent)
  @fshared.init_parser_route_metrics_with_granularity(
    diagnostics,
    source,
    context,
    "yaml",
    "yaml_parser",
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
      YamlStructure
    } else {
      None
    },
    if requested_streaming {
      "yaml_structure_event_stream"
    } else {
      "dom_ast_model"
    },
  )
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("dom_limit_reached", "false")
  @fshared.apply_product_metrics(diagnostics, "yaml")

  if requested_streaming {
    match prepared.events {
      Some(events) => {
        let inspect = prepared.inspect.unwrap_or(
          @dyaml.inspect_yaml_structure_events(events),
        )
        return Ok(
          yaml_streaming_parse_result(
            source, text, diagnostics, inspect, events,
          ),
        )
      }
      None =>
        return Ok(
          yaml_malformed_parse_result(
            source,
            text,
            diagnostics,
            prepared.parse_error.unwrap_or("unknown"),
          ),
        )
    }
  }

  match prepared.document {
    Some(structured) => {
      let inspect = prepared.inspect.unwrap_or(
        @dyaml.inspect_yaml_document(structured.document),
      )
      let document = lower_yaml_document(structured.document, source)
      yaml_fill_common_metrics(diagnostics, inspect, text, 0)
      diagnostics.metrics.set(
        "table_count",
        @fshared.count_blocks_by_kind(document.blocks, Table).to_string(),
      )
      diagnostics.metrics.set(
        "block_count",
        document.blocks.length().to_string(),
      )
      @fshared.mark_structured_document_profile(diagnostics)
      diagnostics.pass_trace.push("parse:yaml_parser")
      let final_document = @core.document_with_diagnostics(
        document, diagnostics,
      )
      Ok(
        @parser.parse_result_with_document_capability(
          "yaml_parser",
          DomAstModel,
          final_document,
          diagnostics,
          yaml_parser_capability(),
        ),
      )
    }
    None =>
      Ok(
        yaml_malformed_parse_result(
          source,
          text,
          diagnostics,
          prepared.parse_error.unwrap_or("unknown"),
        ),
      )
  }
}
