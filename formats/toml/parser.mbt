///|
fn toml_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    @parser.ParserMode::DomAstModel,
    false,
    @parser.StreamingGranularity::None,
    false,
    true,
    false,
    false,
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
pub fn toml_parser() -> @parser.Parser {
  @parser.make_parser(
    "toml_parser",
    @parser.ParserMode::DomAstModel,
    toml_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      parse_toml_document_result(source, context)
    },
  )
}

///|
fn parse_toml_document_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Result[@parser.ParseResult, String] {
  let text = match @input.read_input_text(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let diagnostics = @parser_common.empty_parser_diagnostics(
    "toml_parser",
    @parser.ParserMode::DomAstModel,
    source,
    "toml",
  )
  diagnostics.metrics.set("parser_name", "toml_parser")
  diagnostics.metrics.set("parser_mode", "dom_ast_model")
  diagnostics.metrics.set(
    "input_kind",
    @parser_common.input_kind_name(source.kind),
  )
  diagnostics.metrics.set("detected_format", "toml")
  diagnostics.metrics.set(
    "requested_mode",
    @parser_common.requested_mode_name(context),
  )
  diagnostics.metrics.set("effective_mode", "dom_ast_model")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("event_granularity", "none")
  diagnostics.metrics.set("event_semantics", "dom_ast_model")
  @parser_common.apply_product_metrics(diagnostics, "toml")
  let parsed = try @dtoml.parse_toml_document(text) |> Ok catch {
    e => Err(e.to_string())
  }
  match parsed {
    Ok(doc) => {
      let inspect = @dtoml.inspect_toml_document(doc)
      let document = lower_toml_document(doc, source)
      fill_toml_metrics(diagnostics, inspect, text, document)
      diagnostics.pass_trace.push("parse:toml_parser")
      let final_document = @core.document_with_diagnostics(
        document, diagnostics,
      )
      Ok(
        @parser.parse_result_with_document_capability(
          "toml_parser",
          @parser.ParserMode::DomAstModel,
          final_document,
          diagnostics,
          toml_parser_capability(),
        ),
      )
    }
    Err(err) =>
      Ok(
        toml_malformed_parse_result(
          source,
          text,
          diagnostics,
          err,
          toml_parser_capability(),
        ),
      )
  }
}
