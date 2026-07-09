///|
fn ipynb_parser_capability() -> @parser.ParserCapability {
  @parser.dom_ast_parser_capability(
    @parser.StreamingGranularity::NotebookCellOutputGroup,
    true,
    false,
    true,
    true,
    true,
    true,
    true,
    false,
    true,
    false,
  )
}

///|
pub fn ipynb_parser() -> @parser.Parser {
  @parser.make_parser(
    "ipynb_parser",
    @parser.ParserMode::DomAstModel,
    ipynb_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      let prepared = match @dipynb.prepare_ipynb_notebook_from_source(source) {
        Ok(payload) => payload
        Err(err) => return Err(err)
      }
      let source = prepared.prepared_source
      match prepared.notebook {
        Some(notebook) =>
          Ok(
            ipynb_parse_with_preparsed_notebook(
              source,
              context,
              prepared.original_text,
              notebook,
              prepared.inspect.unwrap_or(
                @dipynb.inspect_ipynb_notebook(notebook),
              ),
            ),
          )
        None =>
          Ok(
            ipynb_malformed_parse_result(
              source,
              prepared.original_text,
              context,
              prepared.parse_error.unwrap_or("unknown"),
            ),
          )
      }
    },
  )
}

///|
pub fn ipynb_parse_with_preparsed_notebook(
  source : @input.InputSource,
  context : @parser.ParseContext,
  text : String,
  notebook : @dipynb.IpynbNotebook,
  inspect : @dipynb.IpynbInspectReport,
) -> @parser.ParseResult {
  let requested_blocks = context.requested_mode ==
    Some(@parser.ParserMode::BlockStreaming)
  let diagnostics = ipynb_base_diagnostics(source, context)
  diagnostics.metrics.set("probe_artifact_reused", "true")
  let lowered = lower_ipynb_notebook(notebook, source, diagnostics)
  ipynb_fill_metrics(diagnostics, inspect, text, lowered, requested_blocks)
  diagnostics.pass_trace.push("parse:ipynb_parser")
  if requested_blocks {
    @parser.parse_result_with_blocks_capability(
      "ipynb_parser",
      @parser.ParserMode::BlockStreaming,
      lowered.blocks,
      diagnostics,
      ipynb_parser_capability(),
      metadata=lowered.metadata,
      assets=lowered.assets,
      source_map=lowered.source_map,
      assembly=lowered.assembly,
    )
  } else {
    let final_document = @core.document_with_diagnostics(lowered, diagnostics)
    @parser.parse_result_with_document_capability(
      "ipynb_parser",
      @parser.ParserMode::DomAstModel,
      final_document,
      diagnostics,
      ipynb_parser_capability(),
    )
  }
}

///|
pub fn ipynb_parse_with_prepared_notebook(
  source : @input.InputSource,
  context : @parser.ParseContext,
  prepared : @dipynb.PreparedIpynbNotebook,
) -> @parser.ParseResult {
  match prepared.notebook {
    Some(notebook) =>
      ipynb_parse_with_preparsed_notebook(
        source,
        context,
        prepared.original_text,
        notebook,
        prepared.inspect.unwrap_or(@dipynb.inspect_ipynb_notebook(notebook)),
      )
    None =>
      ipynb_malformed_parse_result(
        source,
        prepared.original_text,
        context,
        prepared.parse_error.unwrap_or("unknown"),
      )
  }
}
