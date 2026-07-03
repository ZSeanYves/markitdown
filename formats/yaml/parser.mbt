///|
fn yaml_parser_capability() -> @parser.ParserCapability {
  @parser.dom_ast_parser_capability(
    @parser.StreamingGranularity::YamlStructure,
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
  @parser.make_parser(
    "yaml_parser",
    @parser.ParserMode::DomAstModel,
    yaml_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      parse_yaml_document_result(source, context)
    },
  )
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
    @parser.ParserMode::DomAstModel,
    source,
    "yaml",
  )
  @fshared.init_parser_route_metrics_with_granularity(
    diagnostics,
    source,
    context,
    "yaml",
    "yaml_parser",
    @parser.ParserMode::DomAstModel,
    @parser.ParserMode::StreamingEvent,
    "event_stream",
    @parser.StreamingGranularity::YamlStructure,
    "yaml_structure_event_stream",
  )
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("dom_limit_reached", "false")
  @fshared.apply_product_metrics(diagnostics, "yaml")
  yaml_streaming_parse_result(source, text, diagnostics, inspect, events)
}

///|
fn parse_yaml_document_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Result[@parser.ParseResult, String] {
  let text = match @input.read_input_text(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let diagnostics = @fshared.empty_parser_diagnostics(
    "yaml_parser",
    @parser.ParserMode::DomAstModel,
    source,
    "yaml",
  )
  let requested_streaming = context.requested_mode ==
    Some(@parser.ParserMode::StreamingEvent)
  @fshared.init_parser_route_metrics_with_granularity(
    diagnostics,
    source,
    context,
    "yaml",
    "yaml_parser",
    @parser.ParserMode::DomAstModel,
    if requested_streaming {
      @parser.ParserMode::StreamingEvent
    } else {
      @parser.ParserMode::DomAstModel
    },
    if requested_streaming {
      "event_stream"
    } else {
      "document"
    },
    if requested_streaming {
      @parser.StreamingGranularity::YamlStructure
    } else {
      @parser.StreamingGranularity::None
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
    let yaml_events = try @dyaml.parse_yaml_structure_events(text) |> Ok catch {
      e => Err(e.to_string())
    }
    match yaml_events {
      Ok(events) => {
        let inspect = @dyaml.inspect_yaml_structure_events(events)
        return Ok(
          yaml_streaming_parse_result(
            source, text, diagnostics, inspect, events,
          ),
        )
      }
      Err(err) =>
        return Ok(yaml_malformed_parse_result(source, text, diagnostics, err))
    }
  }

  let parsed = try @dyaml.parse_yaml_structure_document(text) |> Ok catch {
    e => Err(e.to_string())
  }
  match parsed {
    Ok(structured) => {
      let inspect = @dyaml.inspect_yaml_document(structured.document)
      let document = lower_yaml_document(structured.document, source)
      yaml_fill_common_metrics(diagnostics, inspect, text, 0)
      diagnostics.metrics.set(
        "table_count",
        @fshared.count_blocks_by_kind(document.blocks, @core.BlockKind::Table).to_string(),
      )
      diagnostics.metrics.set(
        "block_count",
        document.blocks.length().to_string(),
      )
      diagnostics.pass_trace.push("parse:yaml_parser")
      let final_document = @core.document_with_diagnostics(
        document, diagnostics,
      )
      Ok(
        @parser.parse_result_with_document_capability(
          "yaml_parser",
          @parser.ParserMode::DomAstModel,
          final_document,
          diagnostics,
          yaml_parser_capability(),
        ),
      )
    }
    Err(err) => Ok(yaml_malformed_parse_result(source, text, diagnostics, err))
  }
}
