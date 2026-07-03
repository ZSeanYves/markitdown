///|
fn toml_parser_capability() -> @parser.ParserCapability {
  @parser.dom_ast_parser_capability(
    @parser.StreamingGranularity::None,
    false,
    false,
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
  let diagnostics = @fshared.empty_parser_diagnostics(
    "toml_parser",
    @parser.ParserMode::DomAstModel,
    source,
    "toml",
  )
  @fshared.init_parser_route_metrics_with_granularity(
    diagnostics,
    source,
    context,
    "toml",
    "toml_parser",
    @parser.ParserMode::DomAstModel,
    @parser.ParserMode::DomAstModel,
    "document",
    @parser.StreamingGranularity::None,
    "dom_ast_model",
  )
  @fshared.apply_product_metrics(diagnostics, "toml")
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
