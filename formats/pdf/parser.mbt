///|
const PDF_NATIVE_PARSER_NAME : String = "pdf_native_parser"

///|
const PDF_NATIVE_FAIL_CLOSED_MESSAGE : String = "PDF native text restore is disabled by parser policy"

///|
const PDF_OCR_PARSER_NAME : String = "pdf_accurate_layout_parser"

///|
/// Stable parser name for the native-text PDF route.
pub fn pdf_native_parser_name() -> String {
  PDF_NATIVE_PARSER_NAME
}

///|
/// Fail-closed message emitted when native-text restore is intentionally gated
/// off.
pub fn pdf_native_fail_closed_message() -> String {
  PDF_NATIVE_FAIL_CLOSED_MESSAGE
}

///|
/// Stable parser name for the OCR-backed PDF route.
pub fn pdf_ocr_parser_name() -> String {
  PDF_OCR_PARSER_NAME
}

///|
/// Capability for the native-text PDF route.
pub fn pdf_native_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    @parser.ParserMode::PageSinglePass,
    false,
    @parser.StreamingGranularity::Page,
    true,
    true,
    false,
    false,
    false,
    true,
    false,
    true,
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
/// Capability for the OCR-backed PDF route.
pub fn pdf_ocr_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    @parser.ParserMode::LayoutTwoStage,
    false,
    @parser.StreamingGranularity::Page,
    true,
    false,
    false,
    false,
    false,
    true,
    false,
    true,
    true,
    false,
    true,
    true,
    true,
    false,
    true,
    false,
  )
}

///|
priv struct PdfOcrExecutionConfig {
  provider_target : @focr.OcrProviderSelectionTarget
  provider_kind : @focr.OcrProviderKind
}

///|
priv struct PdfOcrAccumulationState {
  blocks : Array[@core.CoreBlock]
  warnings : Array[String]
  fatal_dependency_errors : Array[String]
  fatal_dependency_diagnostics : Array[@core.DependencyDiagnostic]
  raster_failure_count : Ref[Int]
  ocr_failure_count : Ref[Int]
  ocr_success_count : Ref[Int]
  native_text_page_count : Ref[Int]
}

///|
fn pdf_ocr_execution_config(
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Result[PdfOcrExecutionConfig, String] {
  ignore(source)
  let provider_target = @focr.OcrProviderSelectionTarget::PdfAccurate
  let provider_kind = @focr.resolved_ocr_provider_kind_for_target(
    provider_target,
  )
  if context.fidelity_mode != @product.FidelityMode::Accurate {
    return Err(
      "PDF accurate layout parsing requires accurate fidelity mode on this runtime",
    )
  }
  Ok({ provider_target, provider_kind })
}

///|
fn pdf_ocr_accumulation_state() -> PdfOcrAccumulationState {
  {
    blocks: [],
    warnings: [],
    fatal_dependency_errors: [],
    fatal_dependency_diagnostics: [],
    raster_failure_count: { val: 0 },
    ocr_failure_count: { val: 0 },
    ocr_success_count: { val: 0 },
    native_text_page_count: { val: 0 },
  }
}

///|
fn pdf_ocr_record_raster_failure(
  state : PdfOcrAccumulationState,
  warning : String,
) -> Unit {
  state.raster_failure_count.val = state.raster_failure_count.val + 1
  state.warnings.push(warning)
}

///|
fn pdf_ocr_record_empty_provider_result(
  state : PdfOcrAccumulationState,
  page_index : Int,
) -> Unit {
  state.ocr_failure_count.val = state.ocr_failure_count.val + 1
  state.warnings.push("pdf_ocr_page_empty:index=" + page_index.to_string())
}

///|
fn pdf_ocr_record_provider_success(
  state : PdfOcrAccumulationState,
  source : @input.InputSource,
  page_index : Int,
  result : @focr.OcrProviderResult,
) -> Unit {
  if result.pages.length() == 0 {
    pdf_ocr_record_empty_provider_result(state, page_index)
    return
  }
  for model in result.pages {
    state.blocks.append(
      @focr.ocr_page_blocks_from_page(
        source,
        @input.DetectedFormat::Pdf,
        page_index,
        model,
      )[:],
    )
    state.ocr_success_count.val = state.ocr_success_count.val + 1
  }
}

///|
fn pdf_ocr_record_provider_error(
  state : PdfOcrAccumulationState,
  provider_target : @focr.OcrProviderSelectionTarget,
  page_index : Int,
  error : @focr.OcrProviderError,
  provider_kind? : @focr.OcrProviderKind? = None,
  fallback_attempted? : Bool = false,
) -> Unit {
  state.ocr_failure_count.val = state.ocr_failure_count.val + 1
  let provider_note = match provider_kind {
    Some(kind) => " provider=" + @focr.ocr_provider_kind_name(kind)
    None => ""
  }
  let fallback_note = if fallback_attempted {
    " fallback_attempted=true"
  } else {
    ""
  }
  match error {
    @focr.OcrProviderError::NotConfigured(message) => {
      state.fatal_dependency_errors.push(message)
      state.fatal_dependency_diagnostics.push(
        @focr.ocr_dependency_diagnostic_for_target(provider_target),
      )
    }
    @focr.OcrProviderError::CommandUnavailable(message) => {
      state.fatal_dependency_errors.push(message)
      state.fatal_dependency_diagnostics.push(
        @focr.ocr_dependency_diagnostic_for_target(provider_target),
      )
    }
    _ => ()
  }
  state.warnings.push(
    "pdf_ocr_page_failed:index=" +
    page_index.to_string() +
    provider_note +
    fallback_note +
    " reason=" +
    error.to_string(),
  )
}

///|
fn pdf_ocr_empty_result_error(state : PdfOcrAccumulationState) -> String {
  if state.fatal_dependency_errors.length() > 0 {
    state.fatal_dependency_errors[0]
  } else {
    "PDF OCR produced no successful pages on this runtime. " +
    pdf_raster_backend_install_hint()
  }
}

///|
fn pdf_ocr_provider_request(
  image_path : String,
  provider_kind : @focr.OcrProviderKind,
  language : String?,
) -> @focr.OcrProviderRequest {
  @focr.make_ocr_provider_request(image_path, provider_kind, language~)
}

///|
fn pdf_ocr_finalize_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
  config : PdfOcrExecutionConfig,
  raster_result : PdfRasterResult,
  state : PdfOcrAccumulationState,
) -> Result[@parser.ParseResult, String] {
  if state.blocks.length() == 0 {
    return Err(pdf_ocr_empty_result_error(state))
  }
  let ocr_success_count = state.ocr_success_count.val
  let ocr_failure_count = state.ocr_failure_count.val
  let raster_failure_count = state.raster_failure_count.val
  let native_text_page_count = state.native_text_page_count.val
  let diagnostics = @focr.ocr_base_diagnostics(
    pdf_ocr_parser_name(),
    source,
    @input.DetectedFormat::Pdf,
    context.ocr_options,
    Some(@parser.ParserMode::LayoutTwoStage),
    config.provider_target,
  )
  diagnostics.dependency_diagnostics.append(
    state.fatal_dependency_diagnostics[:],
  )
  diagnostics.metrics.set("input_kind", pdf_native_input_kind_name(source.kind))
  diagnostics.metrics.set("ocr_provider_wired", "true")
  diagnostics.metrics.set("provider_invoked", "true")
  diagnostics.metrics.set("ocr_provider_status", "success")
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
  diagnostics.metrics.set(
    "ocr_provider_kind",
    @focr.ocr_provider_kind_name(config.provider_kind),
  )
  diagnostics.metrics.set(
    "ocr_provider_name",
    @focr.ocr_provider_kind_name(config.provider_kind),
  )
  diagnostics.metrics.set("ocr_provider_version", "unknown")
  diagnostics.metrics.set("block_count", state.blocks.length().to_string())
  diagnostics.metrics.set("image_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("page_count", raster_result.page_count.to_string())
  diagnostics.metrics.set(
    "pdf_page_count",
    raster_result.page_count.to_string(),
  )
  diagnostics.metrics.set("ocr_page_count", ocr_success_count.to_string())
  diagnostics.metrics.set("ocr_used_pages", ocr_success_count.to_string())
  diagnostics.metrics.set(
    "scanned_page_ratio",
    if raster_result.page_count == 0 {
      "0"
    } else {
      (ocr_success_count.to_double() / raster_result.page_count.to_double()).to_string()
    },
  )
  diagnostics.metrics.set(
    "native_text_page_count",
    native_text_page_count.to_string(),
  )
  diagnostics.metrics.set(
    "pdf_native_backend",
    if native_text_page_count > 0 {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set(
    "pdf_native_text_baseline",
    if native_text_page_count > 0 {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set("pdf_ocr_used", "true")
  diagnostics.metrics.set("pdf_ocr_policy", "accurate_layout_only")
  diagnostics.metrics.set("pdf_ocr_trigger", "accurate_layout")
  diagnostics.metrics.set(
    "mixed_page_route",
    if native_text_page_count > 0 && ocr_success_count > 0 {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set("pdf_canonical_pipeline_used", "false")
  diagnostics.metrics.set(
    "pdf_empty_text_layer",
    if native_text_page_count == 0 && ocr_success_count > 0 {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set("product_path_enabled", "true")
  diagnostics.metrics.set("format_contract", "pdf")
  diagnostics.metrics.set("native_impl_location", "format_readers/pdf")
  diagnostics.metrics.set("pdf_reader_impl", "format_readers/pdf")
  diagnostics.metrics.set("pdf_raster_backend", raster_result.backend_name)
  diagnostics.metrics.set(
    "pdf_raster_page_success_count",
    ocr_success_count.to_string(),
  )
  diagnostics.metrics.set(
    "pdf_raster_page_failure_count",
    (raster_failure_count + ocr_failure_count).to_string(),
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
  diagnostics.pass_trace.push("pdf_ocr:accurate_full_document")

  let document = @core.document_from_blocks(state.blocks)
  document.metadata.set("pdf_ocr_used", @core.JsonValue::Bool(true))
  document.metadata.set(
    "pdf_native_text_baseline",
    @core.JsonValue::Bool(native_text_page_count > 0),
  )
  document.metadata.set(
    "pdf_canonical_pipeline_used",
    @core.JsonValue::Bool(false),
  )
  document.metadata.set(
    "pdf_raster_backend",
    @core.JsonValue::String(raster_result.backend_name),
  )
  document.metadata.set(
    "page_count",
    @core.JsonValue::Number(raster_result.page_count.to_string()),
  )
  document.metadata.set(
    "pdf_page_count",
    @core.JsonValue::Number(raster_result.page_count.to_string()),
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
    @core.JsonValue::Number(ocr_success_count.to_string()),
  )
  document.metadata.set(
    "pdf_raster_page_failure_count",
    @core.JsonValue::Number(
      (raster_failure_count + ocr_failure_count).to_string(),
    ),
  )
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
    Some(pdf_native_input_kind_name(source.kind)),
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
  diagnostics.metrics.set("input_kind", pdf_native_input_kind_name(source.kind))
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

///|
pub fn pdf_ocr_parser_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
  image_ocr_provider? : (@focr.OcrProviderRequest) -> Result[
    @focr.OcrProviderResult,
    @focr.OcrProviderError,
  ] = @focr.run_ocr_provider,
  rasterizer? : (@input.InputSource) -> Result[
    (PdfRasterResult, String),
    PdfRasterizerError,
  ] = rasterize_pdf_with_pdftoppm_default,
) -> Result[@parser.ParseResult, String] {
  let config = match pdf_ocr_execution_config(source, context) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let rasterized = match rasterizer(source) {
    Ok(value) => value
    Err(error) => return Err(pdf_raster_provider_error_message(error))
  }
  let raster_result = rasterized.0
  let temp_dir = rasterized.1
  defer cleanup_pdf_ocr_temp_dir(temp_dir)
  let state = pdf_ocr_accumulation_state()
  for page in raster_result.pages {
    let page_index = page.page_index + 1
    if !page.success {
      pdf_ocr_record_raster_failure(
        state,
        "pdf_raster_page_failed:index=" + page_index.to_string(),
      )
      continue
    }
    let image_path = match page.image_path {
      Some(path) => path
      None => {
        pdf_ocr_record_raster_failure(
          state,
          "pdf_raster_page_missing_image:index=" + page_index.to_string(),
        )
        continue
      }
    }
    let request = pdf_ocr_provider_request(
      image_path,
      config.provider_kind,
      context.ocr_options.language,
    )
    match image_ocr_provider(request) {
      Ok(result) =>
        pdf_ocr_record_provider_success(state, source, page_index, result)
      Err(error) =>
        pdf_ocr_record_provider_error(
          state,
          config.provider_target,
          page_index,
          error,
          provider_kind=Some(config.provider_kind),
        )
    }
  }
  pdf_ocr_finalize_result(source, context, config, raster_result, state)
}

///|
pub async fn pdf_ocr_parser_result_async(
  source : @input.InputSource,
  context : @parser.ParseContext,
  image_ocr_provider? : async (@focr.OcrProviderRequest) -> Result[
    @focr.OcrProviderResult,
    @focr.OcrProviderError,
  ] = @focr.run_ocr_provider_async,
  rasterizer? : async (@input.InputSource) -> Result[
    (PdfRasterResult, String),
    PdfRasterizerError,
  ] = rasterize_pdf_with_pdftoppm_default_async,
) -> Result[@parser.ParseResult, String] {
  let config = match pdf_ocr_execution_config(source, context) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let rasterized = match rasterizer(source) {
    Ok(value) => value
    Err(error) => return Err(pdf_raster_provider_error_message(error))
  }
  let raster_result = rasterized.0
  let temp_dir = rasterized.1
  defer cleanup_pdf_ocr_temp_dir(temp_dir)
  let state = pdf_ocr_accumulation_state()
  for page in raster_result.pages {
    let page_index = page.page_index + 1
    if !page.success {
      pdf_ocr_record_raster_failure(
        state,
        "pdf_raster_page_failed:index=" + page_index.to_string(),
      )
      continue
    }
    let image_path = match page.image_path {
      Some(path) => path
      None => {
        pdf_ocr_record_raster_failure(
          state,
          "pdf_raster_page_missing_image:index=" + page_index.to_string(),
        )
        continue
      }
    }
    let request = pdf_ocr_provider_request(
      image_path,
      config.provider_kind,
      context.ocr_options.language,
    )
    match image_ocr_provider(request) {
      Ok(result) =>
        pdf_ocr_record_provider_success(state, source, page_index, result)
      Err(error) =>
        pdf_ocr_record_provider_error(
          state,
          config.provider_target,
          page_index,
          error,
          provider_kind=Some(config.provider_kind),
        )
    }
  }
  pdf_ocr_finalize_result(source, context, config, raster_result, state)
}

///|
pub fn pdf_ocr_parser() -> @parser.Parser {
  @parser.make_parser(
    pdf_ocr_parser_name(),
    @parser.ParserMode::LayoutTwoStage,
    pdf_ocr_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      pdf_ocr_parser_result(source, context)
    },
  )
}

///|
fn pdf_native_parser_enabled_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
  capability : @parser.ParserCapability,
) -> Result[@parser.ParseResult, @parser.ParseResult] {
  match extract_pdf_native_document(source) {
    Ok(native_document) =>
      pdf_native_parser_enabled_result_from_document(
        source, context, capability, native_document,
      )
    Err(error) => {
      let diagnostics = pdf_native_enabled_error_diagnostics(
        source, context, error,
      )
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
fn pdf_native_parser_enabled_result_from_document(
  source : @input.InputSource,
  context : @parser.ParseContext,
  capability : @parser.ParserCapability,
  native_document : PdfNativeDocument,
) -> Result[@parser.ParseResult, @parser.ParseResult] {
  let document = pdf_native_document_to_ir_with_policies(
    native_document,
    context.pdf_header_footer_filter_policy,
    context.pdf_table_reconstruction_policy,
  )
  let diagnostics = document.diagnostics
  @fshared.mark_structured_document_profile(diagnostics)
  let diagnostics = pdf_native_enabled_success_diagnostics(
    source, context, diagnostics,
  )
  let final_document = @core.document_with_diagnostics(document, diagnostics)
  Ok(
    @parser.parse_result_with_document_capability(
      pdf_native_parser_name(),
      @parser.ParserMode::PageSinglePass,
      final_document,
      diagnostics,
      capability,
    ),
  )
}

///|
fn pdf_native_enabled_success_diagnostics(
  source : @input.InputSource,
  context : @parser.ParseContext,
  diagnostics : @core.Diagnostics,
) -> @core.Diagnostics {
  let next = @core.diagnostics_with_input(
    @core.diagnostics_with_parser(
      diagnostics,
      Some(pdf_native_parser_name()),
      Some(@parser.mode_name(@parser.ParserMode::PageSinglePass)),
    ),
    Some(pdf_native_input_kind_name(source.kind)),
    Some("pdf"),
  )
  next.pass_trace.push("parse:pdf_native_parser")
  next.pass_trace.push("pdf_native:parser_success_path")
  next.metrics.set("parser_name", pdf_native_parser_name())
  next.metrics.set("parser_mode", "page_single_pass")
  next.metrics.set("input_kind", pdf_native_input_kind_name(source.kind))
  next.metrics.set("detected_format", "pdf")
  next.metrics.set("requested_mode", pdf_native_requested_mode_name(context))
  next.metrics.set("effective_mode", "page_single_pass")
  next.metrics.set("ir_input_kind", "document")
  next.metrics.set("event_granularity", "page")
  next.metrics.set("event_semantics", "page_single_pass")
  next.metrics.set("product_path_enabled", "true")
  next.metrics.set("format_contract", "pdf")
  next.metrics.set("native_impl_location", "format_readers/pdf")
  next.metrics.set("pdf_reader_impl", "format_readers/pdf")
  next.metrics.set("pdf_native_backend", "true")
  next.metrics.set("pdf_native_text_baseline", "true")
  next.metrics.set("pdf_ocr_used", "false")
  next.metrics.set("pdf_canonical_pipeline_used", "false")
  next.metrics.set(
    "probe_artifact_reused",
    if diagnostics.metrics.get("probe_artifact_reused") == Some("true") {
      "true"
    } else {
      "false"
    },
  )
  next.metrics.set(
    "process_cache_hit",
    if diagnostics.metrics.get("process_cache_hit") == Some("true") {
      "true"
    } else {
      "false"
    },
  )
  next.metrics.set(
    "child_parse_fast_path_used",
    if diagnostics.metrics.get("structured_document_profile") ==
      Some("pipeline_ready") {
      "true"
    } else {
      "false"
    },
  )
  if next.metrics.get("pdf_empty_text_layer") == None {
    next.metrics.set("pdf_empty_text_layer", "false")
  }
  next.metrics.set(
    "pdf_header_footer_filter_policy",
    @parser.pdf_header_footer_filter_policy_name(
      context.pdf_header_footer_filter_policy,
    ),
  )
  next.metrics.set(
    "pdf_header_footer_filter_enabled",
    if context.pdf_header_footer_filter_policy ==
      @parser.PdfHeaderFooterFilterPolicy::Disabled {
      "false"
    } else {
      "true"
    },
  )
  if next.metrics.get("pdf_header_footer_removed_count") == None {
    next.metrics.set("pdf_header_footer_removed_count", "0")
  }
  next.metrics.set(
    "pdf_table_reconstruction_policy",
    @parser.pdf_table_reconstruction_policy_name(
      context.pdf_table_reconstruction_policy,
    ),
  )
  next.metrics.set(
    "pdf_table_reconstruction_enabled",
    if context.pdf_table_reconstruction_policy ==
      @parser.PdfTableReconstructionPolicy::Disabled {
      "false"
    } else {
      "true"
    },
  )
  if next.metrics.get("pdf_table_reconstruction_table_count") == None {
    next.metrics.set("pdf_table_reconstruction_table_count", "0")
  }
  next.metrics.set(
    "pdf_native_runtime_policy",
    @parser.pdf_native_runtime_policy_name(context.pdf_native_runtime_policy),
  )
  next.metrics.set("pdf_native_parser_gate", "enabled")
  next.metrics.set("fallback_reason", "none")
  next.metrics.set("fallback_reason_kind", "none")
  next.metrics.set("warning_count", next.warnings.length().to_string())
  next.metrics.set("error_count", next.errors.length().to_string())
  next.metrics.set("fallback_count", next.fallback_trace.length().to_string())
  next
}

///|
fn pdf_native_enabled_error_diagnostics(
  source : @input.InputSource,
  context : @parser.ParseContext,
  error : PdfNativeError,
) -> @core.Diagnostics {
  let taxonomy = pdf_native_error_taxonomy(error)
  let diagnostics = @core.diagnostics_with_input(
    @core.diagnostics_with_parser(
      @core.empty_diagnostics(),
      Some(pdf_native_parser_name()),
      Some(@parser.mode_name(@parser.ParserMode::PageSinglePass)),
    ),
    Some(pdf_native_input_kind_name(source.kind)),
    Some("pdf"),
  )
  diagnostics.errors.push(error.to_string())
  diagnostics.degraded_features.push("pdf_native_internal_gate_failed")
  diagnostics.fallback_trace.push(
    "pdf native parser native text baseline -> " + taxonomy.1,
  )
  diagnostics.pass_trace.push("parse:pdf_native_parser")
  diagnostics.pass_trace.push("pdf_native:parser_error_path")
  diagnostics.metrics.set("parser_name", pdf_native_parser_name())
  diagnostics.metrics.set("parser_mode", "page_single_pass")
  diagnostics.metrics.set("input_kind", pdf_native_input_kind_name(source.kind))
  diagnostics.metrics.set("detected_format", "pdf")
  diagnostics.metrics.set(
    "requested_mode",
    pdf_native_requested_mode_name(context),
  )
  diagnostics.metrics.set("effective_mode", "page_single_pass")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("event_granularity", "page")
  diagnostics.metrics.set("event_semantics", "page_single_pass")
  diagnostics.metrics.set("page_count", "0")
  diagnostics.metrics.set("table_count", "0")
  diagnostics.metrics.set("image_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("scanned_page_ratio", "0")
  diagnostics.metrics.set("ocr_used_pages", "0")
  diagnostics.metrics.set("model_used", "none")
  diagnostics.metrics.set("model_confidence", "0")
  diagnostics.metrics.set("product_path_enabled", "true")
  diagnostics.metrics.set("format_contract", "pdf")
  diagnostics.metrics.set("native_impl_location", "format_readers/pdf")
  diagnostics.metrics.set("pdf_reader_impl", "format_readers/pdf")
  diagnostics.metrics.set("pdf_native_backend", "true")
  diagnostics.metrics.set("pdf_native_text_baseline", "true")
  diagnostics.metrics.set("pdf_ocr_used", "false")
  diagnostics.metrics.set("pdf_canonical_pipeline_used", "false")
  diagnostics.metrics.set("probe_artifact_reused", "false")
  diagnostics.metrics.set("process_cache_hit", "false")
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
  diagnostics.metrics.set(
    "pdf_empty_text_layer",
    if taxonomy.0 == "empty_text_layer" {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set("pdf_native_parser_gate", "enabled")
  diagnostics.metrics.set("fallback_reason", taxonomy.1)
  diagnostics.metrics.set("fallback_reason_kind", taxonomy.0)
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
  diagnostics.metrics.set(
    "pdf_native_runtime_policy",
    @parser.pdf_native_runtime_policy_name(context.pdf_native_runtime_policy),
  )
  diagnostics
}

///|
fn pdf_native_error_taxonomy(error : PdfNativeError) -> (String, String) {
  match error {
    PdfNativeError::BackendUnavailable(_) =>
      ("backend_unavailable", "pdf_native_backend_unavailable")
    PdfNativeError::ReadFailed(_) => ("read_failed", "pdf_native_read_failed")
    PdfNativeError::ParseFailed(_) =>
      ("parse_failed", "pdf_native_parse_failed")
    PdfNativeError::EncryptedUnsupported(_) =>
      ("encrypted_unsupported", "pdf_native_encrypted_unsupported")
    PdfNativeError::EmptyTextLayer(_) =>
      ("empty_text_layer", "pdf_native_empty_text_layer")
    PdfNativeError::UnsupportedFeature(_) =>
      ("unsupported_feature", "pdf_native_unsupported_feature")
  }
}

///|
fn pdf_native_parser_error_message(diagnostics : @core.Diagnostics) -> String {
  if diagnostics.errors.length() > 0 {
    diagnostics.errors[0]
  } else {
    "pdf native parser failed under native text baseline"
  }
}

///|
fn pdf_native_input_kind_name(kind : @input.InputKind) -> String {
  match kind {
    @input.InputKind::Path => "path"
    @input.InputKind::Text => "text"
    @input.InputKind::Bytes => "bytes"
  }
}

///|
fn pdf_native_requested_mode_name(context : @parser.ParseContext) -> String {
  match context.requested_mode {
    Some(mode) => @parser.mode_name(mode)
    None => "default"
  }
}
