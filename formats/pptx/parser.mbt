///|
pub fn pptx_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    @parser.ParserMode::PackageSinglePass,
    false,
    @parser.StreamingGranularity::PptxSlide,
    true,
    true,
    true,
    false,
    false,
    true,
    true,
    true,
    true,
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
pub fn pptx_parser() -> @parser.Parser {
  let capability = pptx_parser_capability()
  @parser.make_parser(
    "pptx_parser",
    @parser.ParserMode::PackageSinglePass,
    capability,
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      parse_pptx_document_result(source, context, capability)
    },
  )
}

///|
priv struct PptxState {
  source : @input.InputSource
  diagnostics : @core.Diagnostics
  presentation : @pptxdoc.PptxDocument
  assets : Array[@core.AssetRef]
  asset_ids : Map[String, String]
  image_ids : Map[String, String]
  slide_image_counts : Map[String, Int]
  chart_fallback_emitted : Ref[Bool]
}

///|
priv struct PptxListTree {
  ordered : Bool
  items : Array[@core.CoreBlock]
}

///|
fn parse_pptx_document_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
  capability : @parser.ParserCapability,
) -> Result[@parser.ParseResult, String] {
  let diagnostics = @parser_common.empty_parser_diagnostics(
    "pptx_parser",
    @parser.ParserMode::PackageSinglePass,
    source,
    "pptx",
  )
  pptx_init_diagnostics(diagnostics, source, context)

  let bytes = match @input.read_input_bytes(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let pkg = try @ox.open_ooxml_package(bytes) |> Ok catch {
    e => Err(e.to_string())
  }
  let pkg = match pkg {
    Ok(value) => value
    Err(err) =>
      return Ok(
        pptx_malformed_parse_result(
          source,
          diagnostics,
          "open package failed: " + err,
          capability,
        ),
      )
  }

  let presentation = try
    @pptxdoc.parse_pptx_document_from_package(pkg) |> Ok
  catch {
    e => Err(e.to_string())
  }
  let presentation = match presentation {
    Ok(value) => value
    Err(err) =>
      return Ok(
        pptx_malformed_parse_result(
          source,
          diagnostics,
          "parse pptx failed: " + err,
          capability,
        ),
      )
  }

  pptx_fill_package_metrics(diagnostics, pkg, presentation)
  let document = pptx_lower_document(source, presentation, diagnostics)
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
  diagnostics.pass_trace.push("parse:pptx_parser")
  let final_document = @core.document_with_diagnostics(document, diagnostics)
  Ok(
    @parser.parse_result_with_document_capability(
      "pptx_parser",
      @parser.ParserMode::PackageSinglePass,
      final_document,
      diagnostics,
      capability,
    ),
  )
}

///|
fn pptx_init_diagnostics(
  diagnostics : @core.Diagnostics,
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Unit {
  diagnostics.metrics.set("parser_name", "pptx_parser")
  diagnostics.metrics.set("parser_mode", "package_single_pass")
  diagnostics.metrics.set(
    "input_kind",
    @parser_common.input_kind_name(source.kind),
  )
  diagnostics.metrics.set("detected_format", "pptx")
  diagnostics.metrics.set(
    "requested_mode",
    @parser_common.requested_mode_name(context),
  )
  diagnostics.metrics.set("effective_mode", "package_single_pass")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("event_granularity", "pptx_slide")
  diagnostics.metrics.set("event_semantics", "package_single_pass")
  diagnostics.metrics.set("office_document_kind", "pptx")
  diagnostics.metrics.set("product_path_enabled", "true")
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
  diagnostics.metrics.set("pptx_slide_count", "0")
  diagnostics.metrics.set("pptx_visible_slide_count", "0")
  diagnostics.metrics.set("pptx_hidden_slide_count", "0")
  diagnostics.metrics.set("pptx_layout_count", "0")
  diagnostics.metrics.set("pptx_master_count", "0")
  diagnostics.metrics.set("pptx_theme_count", "0")
  diagnostics.metrics.set("pptx_shape_count", "0")
  diagnostics.metrics.set("pptx_text_box_count", "0")
  diagnostics.metrics.set("pptx_placeholder_count", "0")
  diagnostics.metrics.set("pptx_resolved_placeholder_count", "0")
  diagnostics.metrics.set("pptx_unresolved_placeholder_count", "0")
  diagnostics.metrics.set("pptx_table_count", "0")
  diagnostics.metrics.set("pptx_image_count", "0")
  diagnostics.metrics.set("pptx_notes_count", "0")
  diagnostics.metrics.set("pptx_comment_count", "0")
  diagnostics.metrics.set("pptx_external_media_count", "0")
  diagnostics.metrics.set(
    "pptx_reading_order_strategy",
    @shared.pptx_reading_order_strategy_name(
      @shared.PptxReadingOrderStrategy::PlaceholderThenGeometry,
    ),
  )
  diagnostics.metrics.set("native_impl_location", "formats/pptx")
  @parser_common.apply_product_metrics(diagnostics, "pptx")
  diagnostics.metrics.set("format_family", "office")
  diagnostics.metrics.set("max_pptx_slides", "2000")
  diagnostics.metrics.set("max_pptx_shapes", "20000")
  diagnostics.metrics.set("max_pptx_text_runs", "200000")
  diagnostics.metrics.set("max_pptx_tables", "5000")
  diagnostics.metrics.set("max_pptx_images", "5000")
  diagnostics.metrics.set("max_pptx_notes", "5000")
  diagnostics.metrics.set("max_pptx_comments", "5000")
}

///|
fn pptx_malformed_parse_result(
  source : @input.InputSource,
  diagnostics : @core.Diagnostics,
  err : String,
  capability : @parser.ParserCapability,
) -> @parser.ParseResult {
  diagnostics.errors.push(err)
  diagnostics.degraded_features.push("pptx_parse_failure")
  diagnostics.fallback_trace.push("pptx parse failed -> fail closed")
  diagnostics.metrics.set("block_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("ooxml_part_count", "0")
  diagnostics.metrics.set("relationship_count", "0")
  diagnostics.metrics.set("external_relationship_count", "0")
  diagnostics.metrics.set("missing_relationship_target_count", "0")
  diagnostics.metrics.set("unsupported_relationship_count", "0")
  diagnostics.metrics.set("content_type_count", "0")
  diagnostics.metrics.set("total_uncompressed_bytes", "0")
  diagnostics.metrics.set("pptx_slide_count", "0")
  diagnostics.metrics.set("pptx_visible_slide_count", "0")
  diagnostics.metrics.set("pptx_hidden_slide_count", "0")
  diagnostics.metrics.set("pptx_layout_count", "0")
  diagnostics.metrics.set("pptx_master_count", "0")
  diagnostics.metrics.set("pptx_theme_count", "0")
  diagnostics.metrics.set("pptx_shape_count", "0")
  diagnostics.metrics.set("pptx_text_box_count", "0")
  diagnostics.metrics.set("pptx_placeholder_count", "0")
  diagnostics.metrics.set("pptx_resolved_placeholder_count", "0")
  diagnostics.metrics.set("pptx_unresolved_placeholder_count", "0")
  diagnostics.metrics.set("pptx_table_count", "0")
  diagnostics.metrics.set("pptx_image_count", "0")
  diagnostics.metrics.set("pptx_notes_count", "0")
  diagnostics.metrics.set("pptx_comment_count", "0")
  diagnostics.metrics.set("pptx_external_media_count", "0")
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
  diagnostics.pass_trace.push("parse:pptx_parser")
  ignore(source)
  let document = @core.document_with_diagnostics(
    @core.empty_document_ir(),
    diagnostics,
  )
  @parser.parse_result_with_document_capability(
    "pptx_parser",
    @parser.ParserMode::PackageSinglePass,
    document,
    diagnostics,
    capability,
  )
}
