///|
fn yaml_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    @parser.ParserMode::DomAstModel,
    true,
    @parser.StreamingGranularity::YamlStructure,
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
  let diagnostics = @parser_common.empty_parser_diagnostics(
    "yaml_parser",
    @parser.ParserMode::DomAstModel,
    source,
    "yaml",
  )
  diagnostics.metrics.set("parser_name", "yaml_parser")
  diagnostics.metrics.set("parser_mode", "dom_ast_model")
  diagnostics.metrics.set(
    "input_kind",
    @parser_common.input_kind_name(source.kind),
  )
  diagnostics.metrics.set("detected_format", "yaml")
  diagnostics.metrics.set(
    "requested_mode",
    @parser_common.requested_mode_name(context),
  )
  diagnostics.metrics.set("effective_mode", "streaming_event")
  diagnostics.metrics.set("ir_input_kind", "event_stream")
  diagnostics.metrics.set("event_granularity", "yaml_structure")
  diagnostics.metrics.set("event_semantics", "yaml_structure_event_stream")
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("dom_limit_reached", "false")
  @parser_common.apply_product_metrics(diagnostics, "yaml")
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
  let diagnostics = @parser_common.empty_parser_diagnostics(
    "yaml_parser",
    @parser.ParserMode::DomAstModel,
    source,
    "yaml",
  )
  diagnostics.metrics.set("parser_name", "yaml_parser")
  diagnostics.metrics.set("parser_mode", "dom_ast_model")
  diagnostics.metrics.set(
    "input_kind",
    @parser_common.input_kind_name(source.kind),
  )
  diagnostics.metrics.set("detected_format", "yaml")
  diagnostics.metrics.set(
    "requested_mode",
    @parser_common.requested_mode_name(context),
  )
  let requested_streaming = context.requested_mode ==
    Some(@parser.ParserMode::StreamingEvent)
  diagnostics.metrics.set(
    "effective_mode",
    if requested_streaming {
      "streaming_event"
    } else {
      "dom_ast_model"
    },
  )
  diagnostics.metrics.set(
    "ir_input_kind",
    if requested_streaming {
      "event_stream"
    } else {
      "document"
    },
  )
  diagnostics.metrics.set(
    "event_granularity",
    if requested_streaming {
      "yaml_structure"
    } else {
      "none"
    },
  )
  diagnostics.metrics.set(
    "event_semantics",
    if requested_streaming {
      "yaml_structure_event_stream"
    } else {
      "dom_ast_model"
    },
  )
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("dom_limit_reached", "false")
  @parser_common.apply_product_metrics(diagnostics, "yaml")

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
        @parser_common.count_blocks_by_kind(
          document.blocks,
          @core.BlockKind::Table,
        ).to_string(),
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
