///|
/// Capability for the canonical DOCX package parser.
pub fn docx_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    PackageSinglePass,
    false,
    DocxBlock,
    true,
    true,
    true,
    false,
    false,
    true,
    true,
    true,
    false,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
  )
}

///|
/// Construct the canonical DOCX parser entrypoint.
pub fn docx_parser() -> @parser.Parser {
  let capability = docx_parser_capability()
  @parser.make_parser("docx_parser", PackageSinglePass, capability, fn(
    source : @input.InputSource,
    context : @parser.ParseContext,
  ) -> Result[@parser.ParseResult, String] {
    parse_docx_document_result(source, context, capability)
  })
}

///|
fn parse_docx_document_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
  capability : @parser.ParserCapability,
) -> Result[@parser.ParseResult, String] {
  let prepared = match @ddocx.prepare_docx_document_from_source(source) {
    Ok(value) => value
    Err(err) => {
      let diagnostics = @fshared.empty_parser_diagnostics(
        "docx_parser",
        PackageSinglePass,
        source,
        "docx",
      )
      diagnostics.metrics.set("parser_name", "docx_parser")
      diagnostics.metrics.set("parser_mode", "package_single_pass")
      diagnostics.metrics.set(
        "input_kind",
        @fshared.input_kind_name(@input.input_kind(source)),
      )
      diagnostics.metrics.set("detected_format", "docx")
      diagnostics.metrics.set(
        "requested_mode",
        @fshared.requested_mode_name(context),
      )
      diagnostics.metrics.set(
        "fidelity_mode",
        @product.fidelity_mode_name(context.fidelity_mode),
      )
      diagnostics.metrics.set(
        "output_mode",
        @product.output_mode_name(context.output_mode),
      )
      diagnostics.metrics.set("effective_mode", "package_single_pass")
      diagnostics.metrics.set("ir_input_kind", "document")
      diagnostics.metrics.set("event_granularity", "docx_block")
      diagnostics.metrics.set("event_semantics", "package_single_pass")
      diagnostics.metrics.set("office_document_kind", "docx")
      diagnostics.metrics.set("product_path_enabled", "true")
      diagnostics.metrics.set("resource_limit_hit", "false")
      diagnostics.metrics.set("format_family", "office")
      diagnostics.metrics.set("native_impl_location", "formats/docx")
      @fshared.apply_product_metrics(diagnostics, "docx")
      return Ok(
        malformed_docx_parse_result(
          source,
          diagnostics,
          "prepare docx failed: " + err,
          capability,
        ),
      )
    }
  }
  Ok(
    docx_parse_with_prepared_document(
      prepared.prepared_source,
      context,
      prepared,
      probe_artifact_reused=false,
    ),
  )
}

///|
pub fn docx_parse_with_prepared_document(
  source : @input.InputSource,
  context : @parser.ParseContext,
  prepared : @ddocx.PreparedDocxDocument,
  probe_artifact_reused? : Bool = true,
) -> @parser.ParseResult {
  let capability = docx_parser_capability()
  let diagnostics = @fshared.empty_parser_diagnostics(
    "docx_parser",
    PackageSinglePass,
    source,
    "docx",
  )
  diagnostics.metrics.set("parser_name", "docx_parser")
  diagnostics.metrics.set("parser_mode", "package_single_pass")
  diagnostics.metrics.set(
    "input_kind",
    @fshared.input_kind_name(@input.input_kind(source)),
  )
  diagnostics.metrics.set("detected_format", "docx")
  diagnostics.metrics.set(
    "requested_mode",
    @fshared.requested_mode_name(context),
  )
  diagnostics.metrics.set(
    "fidelity_mode",
    @product.fidelity_mode_name(context.fidelity_mode),
  )
  diagnostics.metrics.set(
    "output_mode",
    @product.output_mode_name(context.output_mode),
  )
  diagnostics.metrics.set("effective_mode", "package_single_pass")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("event_granularity", "docx_block")
  diagnostics.metrics.set("event_semantics", "package_single_pass")
  diagnostics.metrics.set("office_document_kind", "docx")
  diagnostics.metrics.set("product_path_enabled", "true")
  diagnostics.metrics.set(
    "probe_artifact_reused",
    if probe_artifact_reused {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("media_asset_count", "0")
  diagnostics.metrics.set("materialized_asset_count", "0")
  diagnostics.metrics.set("skipped_asset_count", "0")
  diagnostics.metrics.set("path_traversal_count", "0")
  diagnostics.metrics.set("duplicate_part_count", "0")
  diagnostics.metrics.set("encrypted_entry_count", "0")
  diagnostics.metrics.set("unsupported_compression_count", "0")
  diagnostics.metrics.set("xml_dtd_count", "0")
  diagnostics.metrics.set("xml_external_entity_count", "0")
  diagnostics.metrics.set("macro_part_count", "0")
  diagnostics.metrics.set("ole_object_count", "0")
  diagnostics.metrics.set("alt_chunk_count", "0")
  diagnostics.metrics.set("docx_paragraph_count", "0")
  diagnostics.metrics.set("docx_heading_count", "0")
  diagnostics.metrics.set("docx_table_count", "0")
  diagnostics.metrics.set("docx_list_count", "0")
  diagnostics.metrics.set("docx_image_count", "0")
  diagnostics.metrics.set("docx_hyperlink_count", "0")
  diagnostics.metrics.set("docx_header_footer_count", "0")
  diagnostics.metrics.set("docx_comment_count", "0")
  diagnostics.metrics.set("docx_tracked_change_count", "0")
  diagnostics.metrics.set("format_family", "office")
  diagnostics.metrics.set("native_impl_location", "formats/docx")
  @fshared.apply_product_metrics(diagnostics, "docx")
  let pkg = prepared.opened_package
  let docx = prepared.document
  fill_docx_package_metrics(diagnostics, pkg)
  let document = lower_docx_document_ir(source, docx, pkg, diagnostics, context)
  diagnostics.metrics.set("block_count", document.blocks.length().to_string())
  diagnostics.metrics.set("asset_count", document.assets.length().to_string())
  diagnostics.metrics.set(
    "degraded_feature_count",
    diagnostics.degraded_features.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
  diagnostics.metrics.set(
    "warning_count",
    diagnostics.warnings.length().to_string(),
  )
  diagnostics.metrics.set(
    "error_count",
    diagnostics.errors.length().to_string(),
  )
  diagnostics.metrics.set(
    "issue_count",
    (diagnostics.warnings.length() + diagnostics.errors.length()).to_string(),
  )
  @fshared.mark_structured_document_profile(diagnostics)
  diagnostics.pass_trace.push("parse:docx_parser")
  let final_document = @core.document_with_diagnostics(document, diagnostics)
  @parser.parse_result_with_document_capability(
    "docx_parser",
    PackageSinglePass,
    final_document,
    diagnostics,
    capability,
  )
}

///|
fn malformed_docx_parse_result(
  source : @input.InputSource,
  diagnostics : @core.Diagnostics,
  err : String,
  capability : @parser.ParserCapability,
) -> @parser.ParseResult {
  diagnostics.errors.push(err)
  diagnostics.degraded_features.push("docx_parse_failure")
  diagnostics.fallback_trace.push("docx parse failed -> fail closed")
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("block_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("ooxml_part_count", "0")
  diagnostics.metrics.set("relationship_count", "0")
  diagnostics.metrics.set("external_relationship_count", "0")
  diagnostics.metrics.set("missing_relationship_target_count", "0")
  diagnostics.metrics.set("unsupported_relationship_count", "0")
  diagnostics.metrics.set("media_asset_count", "0")
  diagnostics.metrics.set("materialized_asset_count", "0")
  diagnostics.metrics.set("skipped_asset_count", "0")
  diagnostics.metrics.set("content_type_count", "0")
  diagnostics.metrics.set("total_uncompressed_bytes", "0")
  diagnostics.metrics.set("path_traversal_count", "0")
  diagnostics.metrics.set("duplicate_part_count", "0")
  diagnostics.metrics.set("encrypted_entry_count", "0")
  diagnostics.metrics.set("unsupported_compression_count", "0")
  diagnostics.metrics.set("xml_dtd_count", "0")
  diagnostics.metrics.set("xml_external_entity_count", "0")
  diagnostics.metrics.set("macro_part_count", "0")
  diagnostics.metrics.set("ole_object_count", "0")
  diagnostics.metrics.set("alt_chunk_count", "0")
  diagnostics.metrics.set("docx_paragraph_count", "0")
  diagnostics.metrics.set("docx_heading_count", "0")
  diagnostics.metrics.set("docx_table_count", "0")
  diagnostics.metrics.set("docx_list_count", "0")
  diagnostics.metrics.set("docx_image_count", "0")
  diagnostics.metrics.set("docx_hyperlink_count", "0")
  diagnostics.metrics.set("docx_header_footer_count", "0")
  diagnostics.metrics.set("docx_comment_count", "0")
  diagnostics.metrics.set("docx_tracked_change_count", "0")
  diagnostics.metrics.set(
    "degraded_feature_count",
    diagnostics.degraded_features.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
  diagnostics.metrics.set(
    "warning_count",
    diagnostics.warnings.length().to_string(),
  )
  diagnostics.metrics.set(
    "error_count",
    diagnostics.errors.length().to_string(),
  )
  diagnostics.metrics.set(
    "issue_count",
    (diagnostics.warnings.length() + diagnostics.errors.length()).to_string(),
  )
  diagnostics.pass_trace.push("parse:docx_parser")
  let document = @core.document_with_diagnostics(
    @core.empty_document_ir(),
    diagnostics,
  )
  ignore(source)
  @parser.parse_result_with_document_capability(
    "docx_parser",
    PackageSinglePass,
    document,
    diagnostics,
    capability,
  )
}
