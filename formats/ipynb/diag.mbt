///|
fn ipynb_base_diagnostics(
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> @core.Diagnostics {
  let diagnostics = @fshared.empty_parser_diagnostics(
    "ipynb_parser",
    @parser.ParserMode::DomAstModel,
    source,
    "ipynb",
  )
  diagnostics.metrics.set("parser_name", "ipynb_parser")
  diagnostics.metrics.set("parser_mode", "dom_ast_model")
  diagnostics.metrics.set(
    "input_kind",
    @fshared.input_kind_name(@input.input_kind(source)),
  )
  diagnostics.metrics.set("detected_format", "ipynb")
  diagnostics.metrics.set(
    "requested_mode",
    @fshared.requested_mode_name(context),
  )
  diagnostics.metrics.set(
    "effective_mode",
    if context.requested_mode == Some(@parser.ParserMode::BlockStreaming) {
      "block_streaming"
    } else {
      "dom_ast_model"
    },
  )
  diagnostics.metrics.set(
    "ir_input_kind",
    if context.requested_mode == Some(@parser.ParserMode::BlockStreaming) {
      "block_stream"
    } else {
      "document"
    },
  )
  diagnostics.metrics.set(
    "event_granularity",
    if context.requested_mode == Some(@parser.ParserMode::BlockStreaming) {
      "notebook_cell_output_group"
    } else {
      "none"
    },
  )
  diagnostics.metrics.set(
    "event_semantics",
    if context.requested_mode == Some(@parser.ParserMode::BlockStreaming) {
      "ipynb_cell_output_block_stream"
    } else {
      "dom_ast_model"
    },
  )
  @fshared.apply_product_metrics(diagnostics, "ipynb")
  diagnostics.metrics.set("ipynb_output_selected_mime", "none")
  diagnostics
}

///|
fn ipynb_fill_metrics(
  diagnostics : @core.Diagnostics,
  inspect : @dipynb.IpynbInspectReport,
  text : String,
  document : @core.DocumentIR,
  block_streaming : Bool,
) -> Unit {
  diagnostics.metrics.set(
    "nbformat",
    inspect.nbformat.map(v => v.to_string()).unwrap_or("null"),
  )
  diagnostics.metrics.set(
    "nbformat_minor",
    inspect.nbformat_minor.map(v => v.to_string()).unwrap_or("null"),
  )
  diagnostics.metrics.set("cell_count", inspect.cell_count.to_string())
  diagnostics.metrics.set(
    "markdown_cell_count",
    inspect.markdown_cell_count.to_string(),
  )
  diagnostics.metrics.set(
    "code_cell_count",
    inspect.code_cell_count.to_string(),
  )
  diagnostics.metrics.set("raw_cell_count", inspect.raw_cell_count.to_string())
  diagnostics.metrics.set("output_count", inspect.output_count.to_string())
  diagnostics.metrics.set(
    "stream_output_count",
    inspect.stream_output_count.to_string(),
  )
  diagnostics.metrics.set(
    "display_data_count",
    inspect.display_data_count.to_string(),
  )
  diagnostics.metrics.set(
    "execute_result_count",
    inspect.execute_result_count.to_string(),
  )
  diagnostics.metrics.set(
    "error_output_count",
    inspect.error_output_count.to_string(),
  )
  diagnostics.metrics.set(
    "attachment_count",
    inspect.attachment_count.to_string(),
  )
  diagnostics.metrics.set("asset_count", document.assets.length().to_string())
  diagnostics.metrics.set("block_count", document.blocks.length().to_string())
  diagnostics.metrics.set(
    "max_cell_source_chars",
    inspect.max_cell_source_chars.to_string(),
  )
  diagnostics.metrics.set(
    "max_output_text_chars",
    inspect.max_output_text_chars.to_string(),
  )
  diagnostics.metrics.set(
    "line_count",
    @fshared.count_physical_lines(text).to_string(),
  )
  diagnostics.metrics.set("char_count", text.length().to_string())
  diagnostics.metrics.set("syntax_error_count", "0")
  diagnostics.metrics.set(
    "warning_count",
    diagnostics.warnings.length().to_string(),
  )
  diagnostics.metrics.set(
    "degraded_feature_count",
    diagnostics.degraded_features.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
  diagnostics.metrics.set(
    "builder_input_kind",
    if block_streaming {
      "block_stream"
    } else {
      "document"
    },
  )
}

///|
fn ipynb_malformed_parse_result(
  source : @input.InputSource,
  text : String,
  context : @parser.ParseContext,
  err : String,
) -> @parser.ParseResult {
  let diagnostics = ipynb_base_diagnostics(source, context)
  let block = @core.make_block(
    @core.BlockKind::Code,
    text,
    source_ref=@core.source_ref_with_lines(
      ipynb_source_ref(
        source,
        "/",
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
      ),
      Some(source.source_name),
      Some("ipynb"),
      Some(1),
      Some(@fshared.count_physical_lines(text)),
    ),
  )
  block.attrs.set("info", "json")
  diagnostics.warnings.push("ipynb parse warning: " + err)
  diagnostics.degraded_features.push("ipynb_raw_fenced_fallback")
  diagnostics.fallback_trace.push("ipynb parse failed -> raw fenced block")
  diagnostics.metrics.set("nbformat", "null")
  diagnostics.metrics.set("nbformat_minor", "null")
  diagnostics.metrics.set("cell_count", "0")
  diagnostics.metrics.set("markdown_cell_count", "0")
  diagnostics.metrics.set("code_cell_count", "0")
  diagnostics.metrics.set("raw_cell_count", "0")
  diagnostics.metrics.set("output_count", "0")
  diagnostics.metrics.set("stream_output_count", "0")
  diagnostics.metrics.set("display_data_count", "0")
  diagnostics.metrics.set("execute_result_count", "0")
  diagnostics.metrics.set("error_output_count", "0")
  diagnostics.metrics.set("attachment_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("block_count", "1")
  diagnostics.metrics.set("max_cell_source_chars", "0")
  diagnostics.metrics.set("max_output_text_chars", "0")
  diagnostics.metrics.set(
    "line_count",
    @fshared.count_physical_lines(text).to_string(),
  )
  diagnostics.metrics.set("char_count", text.length().to_string())
  diagnostics.metrics.set("syntax_error_count", "1")
  diagnostics.metrics.set(
    "warning_count",
    diagnostics.warnings.length().to_string(),
  )
  diagnostics.metrics.set(
    "degraded_feature_count",
    diagnostics.degraded_features.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
  diagnostics.metrics.set(
    "builder_input_kind",
    if context.requested_mode == Some(@parser.ParserMode::BlockStreaming) {
      "block_stream"
    } else {
      "document"
    },
  )
  diagnostics.pass_trace.push("parse:ipynb_parser")
  let document = @core.document_from_blocks([block])
  let final_document = @core.document_with_diagnostics(document, diagnostics)
  @parser.parse_result_with_document_capability(
    "ipynb_parser",
    @parser.ParserMode::DomAstModel,
    final_document,
    diagnostics,
    ipynb_parser_capability(),
  )
}
