///|
fn markdown_parser_capability() -> @parser.ParserCapability {
  @parser.dom_ast_parser_capability(
    @parser.StreamingGranularity::MarkdownBlock,
    true,
    false,
    true,
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
pub fn markdown_parser() -> @parser.Parser {
  @parser.make_parser(
    "markdown_parser",
    @parser.ParserMode::DomAstModel,
    markdown_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      let prepared = match @dmd.prepare_markdown_document_from_source(source) {
        Ok(payload) => payload
        Err(err) => return Err(err)
      }
      let source = prepared.prepared_source
      let scanned = prepared.document
      let inspect = prepared.inspect
      let validation = @dmd.validate_markdown_document(scanned)
      let diagnostics = @fshared.empty_parser_diagnostics(
        "markdown_parser",
        @parser.ParserMode::DomAstModel,
        source,
        "markdown",
      )
      diagnostics.metrics.set("parser_name", "markdown_parser")
      diagnostics.metrics.set("parser_mode", "dom_ast_model")
      diagnostics.metrics.set(
        "input_kind",
        @fshared.input_kind_name(@input.input_kind(source)),
      )
      diagnostics.metrics.set("detected_format", "markdown")
      diagnostics.metrics.set(
        "requested_mode",
        @fshared.requested_mode_name(context),
      )
      let requested_blocks = context.requested_mode ==
        Some(@parser.ParserMode::BlockStreaming)
      markdown_set_route_metrics(diagnostics, requested_blocks)
      diagnostics.metrics.set("event_granularity", "markdown_block")
      diagnostics.metrics.set(
        "event_semantics",
        if requested_blocks {
          "markdown_block_stream"
        } else {
          "dom_ast_model"
        },
      )
      diagnostics.metrics.set("resource_limit_hit", "false")
      diagnostics.metrics.set("block_limit_reached", "false")
      @fshared.apply_product_metrics(diagnostics, "markdown")
      diagnostics.metrics.set("line_count", inspect.line_count.to_string())
      diagnostics.metrics.set(
        "block_inventory_count",
        inspect.block_count.to_string(),
      )
      diagnostics.metrics.set(
        "blank_line_count",
        inspect.blank_line_count.to_string(),
      )
      diagnostics.metrics.set(
        "heading_count",
        inspect.heading_count.to_string(),
      )
      diagnostics.metrics.set(
        "fenced_code_count",
        inspect.fenced_code_count.to_string(),
      )
      diagnostics.metrics.set(
        "unclosed_fence_count",
        inspect.unclosed_fence_count.to_string(),
      )
      diagnostics.metrics.set(
        "list_item_count",
        inspect.list_item_count.to_string(),
      )
      diagnostics.metrics.set(
        "blockquote_count",
        inspect.blockquote_count.to_string(),
      )
      diagnostics.metrics.set(
        "table_like_row_count",
        inspect.table_like_row_count.to_string(),
      )
      diagnostics.metrics.set(
        "thematic_break_count",
        inspect.thematic_break_count.to_string(),
      )
      diagnostics.metrics.set(
        "html_block_candidate_count",
        inspect.html_block_candidate_count.to_string(),
      )
      diagnostics.metrics.set(
        "frontmatter_count",
        inspect.frontmatter_count.to_string(),
      )
      diagnostics.metrics.set(
        "frontmatter_seen",
        @fshared.bool_string(inspect.has_frontmatter),
      )
      diagnostics.metrics.set(
        "has_frontmatter",
        @fshared.bool_string(inspect.has_frontmatter),
      )
      diagnostics.metrics.set(
        "is_empty",
        @fshared.bool_string(inspect.is_empty),
      )
      diagnostics.metrics.set(
        "warning_count",
        validation.warning_count.to_string(),
      )
      diagnostics.metrics.set("error_count", validation.error_count.to_string())
      diagnostics.metrics.set("issue_count", validation.issue_count.to_string())
      for validation_issue in validation.issues {
        diagnostics.warnings.push(validation_issue.message)
        diagnostics.fallback_trace.push(
          markdown_validation_issue_trace(validation_issue),
        )
        diagnostics.degraded_features.push(
          markdown_validation_issue_feature(validation_issue),
        )
      }
      let blocks = markdown_lowered_blocks_for_mode(
        scanned, source, diagnostics, requested_blocks,
      )
      if requested_blocks {
        Ok(markdown_block_stream_parse_result(blocks, diagnostics))
      } else {
        Ok(markdown_document_parse_result(blocks, diagnostics))
      }
    },
  )
}

///|
pub fn markdown_parse_with_scanned_document(
  source : @input.InputSource,
  context : @parser.ParseContext,
  scanned : @dmd.MarkdownDocument,
  inspect : @dmd.MarkdownInspectReport,
) -> @parser.ParseResult {
  markdown_parse_result_from_scanned(source, context, scanned, inspect)
}

///|
pub fn markdown_parse_with_prepared_document(
  source : @input.InputSource,
  context : @parser.ParseContext,
  prepared : @dmd.PreparedMarkdownDocument,
) -> @parser.ParseResult {
  let parsed = markdown_parse_result_from_scanned(
    source,
    context,
    prepared.document,
    prepared.inspect,
  )
  parsed.diagnostics.metrics.set("probe_artifact_reused", "true")
  parsed
}

///|
pub fn markdown_blocks_from_scanned_document_light(
  source : @input.InputSource,
  scanned : @dmd.MarkdownDocument,
) -> Array[@core.CoreBlock] {
  markdown_blocks_from_scanned_document_light_with_source_ref(
    source,
    scanned,
    None,
  )
}

///|
pub fn markdown_parse_large_literal(
  source : @input.InputSource,
  context : @parser.ParseContext,
  text : String,
  line_count : Int,
) -> @parser.ParseResult {
  let diagnostics = @fshared.empty_parser_diagnostics(
    "markdown_parser",
    @parser.ParserMode::DomAstModel,
    source,
    "markdown",
  )
  diagnostics.metrics.set("parser_name", "markdown_parser")
  diagnostics.metrics.set("parser_mode", "dom_ast_model")
  diagnostics.metrics.set(
    "input_kind",
    @fshared.input_kind_name(@input.input_kind(source)),
  )
  diagnostics.metrics.set("detected_format", "markdown")
  diagnostics.metrics.set(
    "requested_mode",
    @fshared.requested_mode_name(context),
  )
  markdown_set_route_metrics(diagnostics, true)
  diagnostics.metrics.set("event_granularity", "markdown_block")
  diagnostics.metrics.set("event_semantics", "markdown_literal_block_stream")
  diagnostics.metrics.set("line_count", line_count.to_string())
  diagnostics.metrics.set("char_count", text.length().to_string())
  diagnostics.metrics.set("block_count", "1")
  diagnostics.metrics.set("block_inventory_count", "1")
  diagnostics.metrics.set("event_count", "0")
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("block_limit_reached", "false")
  diagnostics.metrics.set("markdown_lowering_mode", "large_literal")
  diagnostics.metrics.set("probe_artifact_reused", "true")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.same_mode_degradation.push(
    "markdown_large_literal_structure_deferred_for_markdown_output",
  )
  diagnostics.fallback_trace.push(
    "markdown large input -> literal block-stream lowering",
  )
  @fshared.apply_product_metrics(diagnostics, "markdown")
  let source_ref = @core.source_ref_with_lines(
    @core.empty_source_ref(),
    Some(source.source_name),
    Some("markdown"),
    Some(1),
    Some(line_count),
  )
  let block = @core.make_block(@core.BlockKind::Raw, text, source_ref~)
  block.attrs.set("raw_kind", "markdown_literal")
  block.attrs.set("literal", "true")
  markdown_block_stream_parse_result([block], diagnostics)
}

///|
pub fn markdown_blocks_from_scanned_document_light_with_source_ref(
  source : @input.InputSource,
  scanned : @dmd.MarkdownDocument,
  base_source_ref : @core.SourceRef?,
) -> Array[@core.CoreBlock] {
  let diagnostics = @fshared.empty_parser_diagnostics(
    "markdown_parser",
    @parser.ParserMode::DomAstModel,
    source,
    "markdown",
  )
  markdown_blocks_from_scanned_document(
    scanned,
    source,
    diagnostics,
    MarkdownLoweringMode::DomAstLight,
    base_source_ref~,
  )
}
