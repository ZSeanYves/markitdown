///|
fn pdf_ocr_finalize_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
  config : PdfOcrExecutionConfig,
  native_document_ir : @core.DocumentIR,
  raster_result : PdfRasterResult,
  state : PdfOcrAccumulationState,
  stats : PdfOcrExecutionStats,
) -> Result[@parser.ParseResult, String] {
  let final_blocks : Array[@core.CoreBlock] = []
  final_blocks.append(state.blocks[:])
  final_blocks.append(
    pdf_blocks_without_page_number(native_document_ir.blocks)[:],
  )
  if final_blocks.length() == 0 {
    return Err(pdf_ocr_empty_result_error(state))
  }
  let native_facts_present = pdf_document_has_native_facts(native_document_ir)
  let document = if native_facts_present {
    { ..native_document_ir, blocks: final_blocks }
  } else {
    @core.document_from_blocks(final_blocks)
  }
  let final_table_count = pdf_document_block_kind_count(
    document.blocks,
    @core.BlockKind::Table,
  )
  let final_image_count = pdf_document_block_kind_count(
    document.blocks,
    @core.BlockKind::Image,
  )
  let final_asset_count = document.assets.length()
  let ocr_success_count = state.ocr_success_count.val
  let ocr_failure_count = state.ocr_failure_count.val
  let raster_failure_count = state.raster_failure_count.val
  let native_text_page_count = stats.native_page_count
  let provider_invoked = stats.ocr_process_invocation_count > 0
  let diagnostics0 = @focr.ocr_base_diagnostics(
    pdf_ocr_parser_name(),
    source,
    @input.DetectedFormat::Pdf,
    context.ocr_options,
    Some(@parser.ParserMode::LayoutTwoStage),
    config.provider_target,
  )
  diagnostics0.dependency_diagnostics.append(
    state.fatal_dependency_diagnostics[:],
  )
  let diagnostics = pdf_ocr_merge_native_diagnostics(
    diagnostics0,
    native_document_ir.diagnostics,
  )
  pdf_ocr_inherit_native_projection_metrics(
    diagnostics,
    native_document_ir.diagnostics,
  )
  diagnostics.metrics.set(
    "input_kind",
    pdf_native_input_kind_name(@input.input_kind(source)),
  )
  diagnostics.metrics.set("ocr_provider_wired", "true")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("event_granularity", "page")
  diagnostics.metrics.set("event_semantics", "layout_two_stage")
  diagnostics.metrics.set(
    "provider_invoked",
    if provider_invoked {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set(
    "ocr_provider_status",
    if !provider_invoked {
      "skipped_native_text_only"
    } else if ocr_failure_count == 0 {
      "success"
    } else if ocr_success_count > 0 {
      "partial_success"
    } else {
      "execution_failed"
    },
  )
  diagnostics.metrics.set(
    "ocr_provider_selection_target",
    @focr.ocr_provider_selection_target_name(config.provider_target),
  )
  diagnostics.metrics.set(
    "ocr_provider_requested_kind",
    @focr.ocr_provider_kind_name(
      @focr.default_ocr_provider_kind_for_target(config.provider_target),
    ),
  )
  match stats.provider_name {
    Some(value) => diagnostics.metrics.set("ocr_provider_name", value)
    None => ()
  }
  match stats.provider_version {
    Some(value) => diagnostics.metrics.set("ocr_provider_version", value)
    None => ()
  }
  if provider_invoked {
    diagnostics.metrics.set(
      "ocr_provider_kind",
      @focr.ocr_provider_kind_name(config.provider_kind),
    )
  } else {
    diagnostics.metrics.set("ocr_provider_kind", "none")
  }
  diagnostics.metrics.set("block_count", document.blocks.length().to_string())
  diagnostics.metrics.set("table_count", final_table_count.to_string())
  diagnostics.metrics.set("image_count", final_image_count.to_string())
  diagnostics.metrics.set("asset_count", final_asset_count.to_string())
  diagnostics.metrics.set("page_count", stats.page_count.to_string())
  diagnostics.metrics.set("pdf_page_count", stats.page_count.to_string())
  diagnostics.metrics.set("ocr_page_count", ocr_success_count.to_string())
  diagnostics.metrics.set("ocr_used_pages", ocr_success_count.to_string())
  diagnostics.metrics.set(
    "scanned_page_ratio",
    if stats.page_count == 0 {
      "0"
    } else {
      (stats.ocr_page_count.to_double() / stats.page_count.to_double()).to_string()
    },
  )
  diagnostics.metrics.set(
    "native_text_page_count",
    native_text_page_count.to_string(),
  )
  diagnostics.metrics.set(
    "pdf_native_page_count",
    native_text_page_count.to_string(),
  )
  diagnostics.metrics.set(
    "pdf_ocr_page_count",
    stats.ocr_page_count.to_string(),
  )
  diagnostics.metrics.set(
    "pdf_region_hybrid_candidate_count",
    stats.region_hybrid_candidate_count.to_string(),
  )
  diagnostics.metrics.set(
    "pdf_region_hybrid_used",
    if stats.hybrid_region_page_count > 0 {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set(
    "pdf_native_low_confidence_text_count",
    stats.native_low_confidence_text_count.to_string(),
  )
  diagnostics.metrics.set("pdf_page_route_summary", stats.page_route_summary)
  diagnostics.metrics.set(
    "pdf_page_hybrid_used",
    if stats.page_route_hybrid_used {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set(
    "pdf_rasterized_page_count",
    stats.rasterized_page_count.to_string(),
  )
  diagnostics.metrics.set(
    "pdf_native_backend",
    if native_facts_present {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set(
    "pdf_native_text_baseline",
    if stats.native_detected_page_count > 0 {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set(
    "pdf_ocr_used",
    if provider_invoked {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set("pdf_ocr_route_contract", "accurate_layout_only")
  diagnostics.metrics.set("pdf_ocr_trigger", "accurate_layout")
  diagnostics.metrics.set(
    "mixed_page_route",
    if stats.page_route_hybrid_used {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set("pdf_canonical_pipeline_used", "false")
  diagnostics.metrics.set(
    "pdf_empty_text_layer",
    if !native_facts_present &&
      stats.native_detected_page_count == 0 &&
      ocr_success_count > 0 {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set("product_path_enabled", "true")
  diagnostics.metrics.set("format_contract", "pdf")
  diagnostics.metrics.set("native_impl_location", "format_readers/pdf")
  diagnostics.metrics.set("pdf_reader_impl", "format_readers/pdf")
  diagnostics.metrics.set(
    "pdf_raster_backend",
    if stats.raster_invoked {
      raster_result.backend_name
    } else {
      "none"
    },
  )
  diagnostics.metrics.set(
    "pdf_raster_page_success_count",
    stats.raster_page_success_count.to_string(),
  )
  diagnostics.metrics.set(
    "pdf_raster_page_failure_count",
    raster_failure_count.to_string(),
  )
  diagnostics.metrics.set(
    "pdf_ocr_page_failure_count",
    ocr_failure_count.to_string(),
  )
  diagnostics.metrics.set(
    "ocr_provider_batch_job_count",
    stats.ocr_batch_job_count.to_string(),
  )
  diagnostics.metrics.set(
    "ocr_provider_process_invocation_count",
    stats.ocr_process_invocation_count.to_string(),
  )
  diagnostics.metrics.set(
    "ocr_provider_batch_mode",
    if stats.ocr_batch_mode {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set(
    "external_process_invocation_count",
    stats.external_process_invocation_count.to_string(),
  )
  diagnostics.metrics.set("external_process_kind", stats.external_process_kind)
  diagnostics.metrics.set(
    "external_process_wall_ms",
    stats.external_process_wall_ms.to_string(),
  )
  diagnostics.metrics.set(
    "pdf_raster_wall_ms",
    stats.pdf_raster_wall_ms.to_string(),
  )
  diagnostics.metrics.set(
    "ocr_provider_wall_ms",
    stats.ocr_provider_wall_ms.to_string(),
  )
  diagnostics.metrics.set(
    "pdf_native_runtime_policy",
    @parser.pdf_native_runtime_policy_name(context.pdf_native_runtime_policy),
  )
  diagnostics.metrics.set(
    "pdf_header_footer_filter_policy",
    @parser.pdf_header_footer_filter_policy_name(
      context.pdf_header_footer_filter_policy,
    ),
  )
  diagnostics.metrics.set(
    "pdf_table_reconstruction_policy",
    @parser.pdf_table_reconstruction_policy_name(
      context.pdf_table_reconstruction_policy,
    ),
  )
  diagnostics.metrics.set(
    "pdf_header_footer_filter_enabled",
    if context.pdf_header_footer_filter_policy ==
      @parser.PdfHeaderFooterFilterPolicy::Disabled {
      "false"
    } else {
      "true"
    },
  )
  diagnostics.metrics.set(
    "pdf_table_reconstruction_enabled",
    if context.pdf_table_reconstruction_policy ==
      @parser.PdfTableReconstructionPolicy::Disabled {
      "false"
    } else {
      "true"
    },
  )
  if raster_failure_count > 0 {
    diagnostics.degraded_features.push("pdf_raster_partial_failure")
  }
  if ocr_failure_count > 0 {
    diagnostics.degraded_features.push("pdf_ocr_partial_page_failure")
  }
  for item in raster_result.diagnostics {
    diagnostics.warnings.push("pdf_raster_diagnostic: " + item)
  }
  for item in state.warnings {
    diagnostics.warnings.push(item)
  }
  diagnostics.pass_trace.push("parse:pdf_ocr_parser")
  diagnostics.pass_trace.push("pdf_ocr:layout_two_stage")
  diagnostics.pass_trace.push("pdf_ocr:hybrid_pages")
  if stats.hybrid_region_page_count > 0 {
    diagnostics.pass_trace.push("pdf_ocr:hybrid_regions")
  }
  diagnostics.metrics.set(
    "warning_count",
    diagnostics.warnings.length().to_string(),
  )
  diagnostics.metrics.set(
    "error_count",
    diagnostics.errors.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
  document.metadata.set("pdf_ocr_used", @core.JsonValue::Bool(provider_invoked))
  document.metadata.set(
    "pdf_native_backend",
    @core.JsonValue::Bool(native_facts_present),
  )
  document.metadata.set(
    "pdf_native_text_baseline",
    @core.JsonValue::Bool(stats.native_detected_page_count > 0),
  )
  document.metadata.set(
    "pdf_canonical_pipeline_used",
    @core.JsonValue::Bool(false),
  )
  document.metadata.set(
    "pdf_raster_backend",
    @core.JsonValue::String(
      if stats.raster_invoked {
        raster_result.backend_name
      } else {
        "none"
      },
    ),
  )
  document.metadata.set(
    "page_count",
    @core.JsonValue::Number(stats.page_count.to_string()),
  )
  document.metadata.set(
    "pdf_page_count",
    @core.JsonValue::Number(stats.page_count.to_string()),
  )
  document.metadata.set(
    "ocr_used_pages",
    @core.JsonValue::Number(ocr_success_count.to_string()),
  )
  document.metadata.set(
    "native_text_page_count",
    @core.JsonValue::Number(native_text_page_count.to_string()),
  )
  document.metadata.set(
    "pdf_raster_page_success_count",
    @core.JsonValue::Number(stats.raster_page_success_count.to_string()),
  )
  document.metadata.set(
    "pdf_raster_page_failure_count",
    @core.JsonValue::Number(raster_failure_count.to_string()),
  )
  document.metadata.set(
    "pdf_native_page_count",
    @core.JsonValue::Number(stats.native_page_count.to_string()),
  )
  document.metadata.set(
    "pdf_region_hybrid_candidate_count",
    @core.JsonValue::Number(stats.region_hybrid_candidate_count.to_string()),
  )
  document.metadata.set(
    "pdf_region_hybrid_used",
    @core.JsonValue::Bool(stats.hybrid_region_page_count > 0),
  )
  document.metadata.set(
    "pdf_native_low_confidence_text_count",
    @core.JsonValue::Number(stats.native_low_confidence_text_count.to_string()),
  )
  document.metadata.set(
    "pdf_ocr_page_count",
    @core.JsonValue::Number(stats.ocr_page_count.to_string()),
  )
  document.metadata.set(
    "pdf_rasterized_page_count",
    @core.JsonValue::Number(stats.rasterized_page_count.to_string()),
  )
  document.metadata.set(
    "pdf_page_route_summary",
    @core.JsonValue::String(stats.page_route_summary),
  )
  document.metadata.set(
    "image_count",
    @core.JsonValue::Number(final_image_count.to_string()),
  )
  document.metadata.set("format", @core.JsonValue::String("pdf"))
  let final_document = @core.document_with_diagnostics(document, diagnostics)
  Ok(
    @parser.parse_result_with_document_capability(
      pdf_ocr_parser_name(),
      @parser.ParserMode::LayoutTwoStage,
      final_document,
      diagnostics,
      pdf_ocr_parser_capability(),
    ),
  )
}

///|
/// Produce diagnostics for the native PDF route when policy intentionally
/// blocks text restore.
pub fn pdf_native_fail_closed_diagnostics(
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> @core.Diagnostics {
  let diagnostics = @core.diagnostics_with_input(
    @core.diagnostics_with_parser(
      @core.empty_diagnostics(),
      Some(pdf_native_parser_name()),
      Some(@parser.mode_name(@parser.ParserMode::PageSinglePass)),
    ),
    Some(pdf_native_input_kind_name(@input.input_kind(source))),
    Some("pdf"),
  )
  diagnostics.warnings.push(pdf_native_fail_closed_message())
  diagnostics.degraded_features.push("pdf_native_policy_gate")
  diagnostics.fallback_trace.push(
    "pdf native parser policy gate -> fail closed until text restore is enabled",
  )
  diagnostics.pass_trace.push("parse:pdf_native_parser")
  diagnostics.metrics.set("parser_name", pdf_native_parser_name())
  diagnostics.metrics.set("parser_mode", "page_single_pass")
  diagnostics.metrics.set(
    "input_kind",
    pdf_native_input_kind_name(@input.input_kind(source)),
  )
  diagnostics.metrics.set("detected_format", "pdf")
  diagnostics.metrics.set(
    "requested_mode",
    pdf_native_requested_mode_name(context),
  )
  diagnostics.metrics.set("effective_mode", "page_single_pass")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("event_granularity", "page")
  diagnostics.metrics.set("page_count", "0")
  diagnostics.metrics.set("table_count", "0")
  diagnostics.metrics.set("image_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("scanned_page_ratio", "0")
  diagnostics.metrics.set("ocr_used_pages", "0")
  diagnostics.metrics.set("model_used", "none")
  diagnostics.metrics.set("model_confidence", "0")
  diagnostics.metrics.set("pdf_native_backend", "false")
  diagnostics.metrics.set("pdf_native_text_baseline", "false")
  diagnostics.metrics.set("pdf_ocr_used", "false")
  diagnostics.metrics.set("pdf_canonical_pipeline_used", "false")
  diagnostics.metrics.set("pdf_empty_text_layer", "false")
  diagnostics.metrics.set(
    "pdf_header_footer_filter_policy",
    @parser.pdf_header_footer_filter_policy_name(
      context.pdf_header_footer_filter_policy,
    ),
  )
  diagnostics.metrics.set(
    "pdf_header_footer_filter_enabled",
    if context.pdf_header_footer_filter_policy ==
      @parser.PdfHeaderFooterFilterPolicy::Disabled {
      "false"
    } else {
      "true"
    },
  )
  diagnostics.metrics.set("pdf_header_footer_removed_count", "0")
  diagnostics.metrics.set(
    "pdf_table_reconstruction_policy",
    @parser.pdf_table_reconstruction_policy_name(
      context.pdf_table_reconstruction_policy,
    ),
  )
  diagnostics.metrics.set(
    "pdf_table_reconstruction_enabled",
    if context.pdf_table_reconstruction_policy ==
      @parser.PdfTableReconstructionPolicy::Disabled {
      "false"
    } else {
      "true"
    },
  )
  diagnostics.metrics.set("pdf_table_reconstruction_table_count", "0")
  diagnostics.metrics.set("fallback_reason", "pdf_native_restore_not_enabled")
  diagnostics.metrics.set("fallback_reason_kind", "parser_policy_gate")
  diagnostics.metrics.set("warning_count", "1")
  diagnostics.metrics.set("error_count", "0")
  diagnostics.metrics.set("fallback_count", "1")
  diagnostics.metrics.set("product_path_enabled", "false")
  diagnostics.metrics.set("format_contract", "pdf")
  diagnostics.metrics.set("native_impl_location", "format_readers/pdf")
  diagnostics.metrics.set("pdf_reader_impl", "format_readers/pdf")
  diagnostics.metrics.set("pdf_native_parser_gate", "disabled")
  diagnostics.metrics.set(
    "pdf_native_runtime_policy",
    @parser.pdf_native_runtime_policy_name(context.pdf_native_runtime_policy),
  )
  diagnostics
}

///|
/// Return the native PDF parser result, including fail-closed diagnostics when
/// the runtime gate is disabled.
pub fn pdf_native_parser_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> @parser.ParseResult {
  match pdf_native_parser_result_with_gate(source, context) {
    Ok(result) => result
    Err(result) => result
  }
}

///|
fn pdf_native_parser_result_with_gate(
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Result[@parser.ParseResult, @parser.ParseResult] {
  let capability = pdf_native_parser_capability()
  match context.pdf_native_runtime_policy {
    @parser.PdfNativeRuntimePolicy::EnableTextRestore =>
      pdf_native_parser_enabled_result(source, context, capability)
    @parser.PdfNativeRuntimePolicy::DisableTextRestore => {
      let diagnostics = pdf_native_fail_closed_diagnostics(source, context)
      Err(
        @parser.parse_result_with_document_capability(
          pdf_native_parser_name(),
          @parser.ParserMode::PageSinglePass,
          @core.document_with_diagnostics(
            @core.empty_document_ir(),
            diagnostics,
          ),
          diagnostics,
          capability,
        ),
      )
    }
  }
}

///|
/// Construct the native-text PDF parser entrypoint.
pub fn pdf_native_parser() -> @parser.Parser {
  let capability = pdf_native_parser_capability()
  @parser.make_parser(
    pdf_native_parser_name(),
    @parser.ParserMode::PageSinglePass,
    capability,
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      match pdf_native_parser_result_with_gate(source, context) {
        Ok(result) => Ok(result)
        Err(result) =>
          match context.pdf_native_runtime_policy {
            @parser.PdfNativeRuntimePolicy::EnableTextRestore =>
              Err(pdf_native_parser_error_message(result.diagnostics))
            @parser.PdfNativeRuntimePolicy::DisableTextRestore => {
              ignore(result)
              Err(pdf_native_fail_closed_message())
            }
          }
      }
    },
  )
}
