///|
fn toml_parser_capability() -> @parser.ParserCapability {
  @parser.dom_ast_parser_capability(
    None,
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
  @parser.make_parser("toml_parser", DomAstModel, toml_parser_capability(), fn(
    source : @input.InputSource,
    context : @parser.ParseContext,
  ) -> Result[@parser.ParseResult, String] {
    parse_toml_document_result(source, context)
  })
}

///|
fn parse_toml_document_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Result[@parser.ParseResult, String] {
  let prepared = match @dtoml.prepare_toml_document_from_source(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let source = prepared.prepared_source
  let diagnostics = @fshared.empty_parser_diagnostics(
    "toml_parser",
    DomAstModel,
    source,
    "toml",
  )
  @fshared.init_parser_route_metrics_with_granularity(
    diagnostics,
    source,
    context,
    "toml",
    "toml_parser",
    DomAstModel,
    DomAstModel,
    "document",
    None,
    "dom_ast_model",
  )
  @fshared.apply_product_metrics(diagnostics, "toml")
  match prepared.document {
    Some(doc) =>
      Ok(
        toml_parse_with_preparsed_document(
          source,
          context,
          prepared.original_text,
          doc,
          prepared.inspect.unwrap_or(@dtoml.inspect_toml_document(doc)),
        ),
      )
    None =>
      Ok(
        toml_malformed_parse_result(
          source,
          prepared.original_text,
          diagnostics,
          prepared.parse_error.unwrap_or("unknown"),
          toml_parser_capability(),
        ),
      )
  }
}

///|
pub fn toml_parse_with_preparsed_document(
  source : @input.InputSource,
  context : @parser.ParseContext,
  text : String,
  doc : @dtoml.TomlDocument,
  inspect : @dtoml.TomlInspectReport,
  fast_array_table? : @dtoml.TomlFastArrayTable? = None,
) -> @parser.ParseResult {
  let diagnostics = @fshared.empty_parser_diagnostics(
    "toml_parser",
    DomAstModel,
    source,
    "toml",
  )
  @fshared.init_parser_route_metrics_with_granularity(
    diagnostics,
    source,
    context,
    "toml",
    "toml_parser",
    DomAstModel,
    DomAstModel,
    "document",
    None,
    "dom_ast_model",
  )
  @fshared.apply_product_metrics(diagnostics, "toml")
  let document = lower_toml_document(doc, source)
  match fast_array_table {
    Some(fast) =>
      append_toml_fast_array_table(
        document,
        fast,
        source,
        context.output_mode == Markdown,
      )
    None => ()
  }
  fill_toml_metrics(diagnostics, inspect, text, document)
  @fshared.mark_structured_document_profile(diagnostics)
  diagnostics.pass_trace.push("parse:toml_parser")
  let final_document = @core.document_with_diagnostics(document, diagnostics)
  @parser.parse_result_with_document_capability(
    "toml_parser",
    DomAstModel,
    final_document,
    diagnostics,
    toml_parser_capability(),
  )
}

///|
pub fn toml_parse_with_prepared_document(
  source : @input.InputSource,
  context : @parser.ParseContext,
  prepared : @dtoml.PreparedTomlDocument,
) -> @parser.ParseResult {
  match prepared.document {
    Some(doc) => {
      let parsed = toml_parse_with_preparsed_document(
        source,
        context,
        prepared.original_text,
        doc,
        prepared.inspect.unwrap_or(@dtoml.inspect_toml_document(doc)),
        fast_array_table=prepared.fast_array_table,
      )
      parsed.diagnostics.metrics.set("probe_artifact_reused", "true")
      parsed
    }
    None => {
      let diagnostics = @fshared.empty_parser_diagnostics(
        "toml_parser",
        DomAstModel,
        source,
        "toml",
      )
      @fshared.init_parser_route_metrics_with_granularity(
        diagnostics,
        source,
        context,
        "toml",
        "toml_parser",
        DomAstModel,
        DomAstModel,
        "document",
        None,
        "dom_ast_model",
      )
      @fshared.apply_product_metrics(diagnostics, "toml")
      toml_malformed_parse_result(
        source,
        prepared.original_text,
        diagnostics,
        prepared.parse_error.unwrap_or("unknown"),
        toml_parser_capability(),
      )
    }
  }
}
