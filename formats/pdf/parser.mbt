///|
const PDF_NATIVE_PARSER_NAME : String = "pdf_native_parser"

///|
const PDF_NATIVE_FAIL_CLOSED_MESSAGE : String = "PDF native text restore is disabled by parser policy"

///|
const PDF_OCR_PARSER_NAME : String = "pdf_ocr_parser"

///|
pub fn pdf_native_parser_name() -> String {
  PDF_NATIVE_PARSER_NAME
}

///|
pub fn pdf_native_fail_closed_message() -> String {
  PDF_NATIVE_FAIL_CLOSED_MESSAGE
}

///|
pub fn pdf_ocr_parser_name() -> String {
  PDF_OCR_PARSER_NAME
}

///|
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
  diagnostics.metrics.set("pdf_v2_used", "false")
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
  diagnostics.metrics.set("native_impl_location", "formats")
  diagnostics.metrics.set("pdf_native_parser_gate", "disabled")
  diagnostics.metrics.set(
    "pdf_native_runtime_policy",
    @parser.pdf_native_runtime_policy_name(context.pdf_native_runtime_policy),
  )
  diagnostics
}

///|
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
  let options = context.ocr_options
  let provider_target = match context.fidelity_mode {
    @product.FidelityMode::Accurate =>
      @focr.OcrProviderSelectionTarget::PdfAccurate
    _ => @focr.OcrProviderSelectionTarget::PdfBalanced
  }
  let provider_kind = @focr.resolved_ocr_provider_kind_for_target(
    provider_target,
  )
  if context.pdf_ocr_policy == @parser.PdfOcrPolicy::Disabled {
    return Err(
      "pdf OCR requires --ocr or --pdf-ocr on this runtime; requested_policy=" +
      @parser.pdf_ocr_policy_name(context.pdf_ocr_policy),
    )
  }
  let native_document = if context.pdf_ocr_policy ==
    @parser.PdfOcrPolicy::AutoScanned {
    match extract_pdf_native_document(source) {
      Ok(document) => Some(document)
      Err(_) => None
    }
  } else {
    None
  }
  let rasterized = match rasterizer(source) {
    Ok(value) => value
    Err(error) => return Err(pdf_raster_provider_error_message(error))
  }
  let raster_result = rasterized.0
  let temp_dir = rasterized.1
  defer cleanup_pdf_ocr_temp_dir(temp_dir)

  let blocks : Array[@core.CoreBlock] = []
  let warnings : Array[String] = []
  let mut raster_failure_count = 0
  let mut ocr_failure_count = 0
  let mut ocr_success_count = 0
  let mut native_text_page_count = 0
  let fatal_dependency_errors : Array[String] = []
  let fatal_dependency_diagnostics : Array[@core.DependencyDiagnostic] = []
  for page in raster_result.pages {
    let page_index = page.page_index + 1
    if native_document is Some(document) &&
      context.pdf_ocr_policy == @parser.PdfOcrPolicy::AutoScanned &&
      page_index <= document.pages.length() &&
      pdf_native_page_has_text(document.pages[page.page_index]) {
      native_text_page_count += 1
      blocks.append(
        pdf_native_page_to_paragraph_blocks(document.pages[page.page_index])[:],
      )
      continue
    }
    if !page.success {
      raster_failure_count += 1
      warnings.push("pdf_raster_page_failed:index=" + page_index.to_string())
      continue
    }
    let image_path = match page.image_path {
      Some(path) => path
      None => {
        raster_failure_count += 1
        warnings.push(
          "pdf_raster_page_missing_image:index=" + page_index.to_string(),
        )
        continue
      }
    }
    let request = @focr.make_ocr_provider_request(
      image_path,
      provider_kind,
      language=options.language,
    )
    match image_ocr_provider(request) {
      Ok(result) =>
        if result.pages.length() == 0 {
          ocr_failure_count += 1
          warnings.push("pdf_ocr_page_empty:index=" + page_index.to_string())
        } else {
          for model in result.pages {
            blocks.append(
              @focr.ocr_page_blocks_from_page(
                source,
                @input.DetectedFormat::Pdf,
                page_index,
                model,
              )[:],
            )
            ocr_success_count += 1
          }
        }
      Err(error) => {
        ocr_failure_count += 1
        match error {
          @focr.OcrProviderError::NotConfigured(message) => {
            fatal_dependency_errors.push(message)
            fatal_dependency_diagnostics.push(
              @focr.ocr_dependency_diagnostic_for_target(provider_target),
            )
          }
          @focr.OcrProviderError::CommandUnavailable(message) => {
            fatal_dependency_errors.push(message)
            fatal_dependency_diagnostics.push(
              @focr.ocr_dependency_diagnostic_for_target(provider_target),
            )
          }
          _ => ()
        }
        warnings.push(
          "pdf_ocr_page_failed:index=" +
          page_index.to_string() +
          " reason=" +
          error.to_string(),
        )
      }
    }
  }

  if blocks.length() == 0 {
    if fatal_dependency_errors.length() > 0 {
      return Err(fatal_dependency_errors[0])
    }
    return Err(
      "PDF OCR produced no successful pages on this runtime. " +
      pdf_raster_backend_install_hint(),
    )
  }
  let diagnostics = @focr.ocr_base_diagnostics(
    pdf_ocr_parser_name(),
    source,
    @input.DetectedFormat::Pdf,
    options,
    Some(@parser.ParserMode::LayoutTwoStage),
    provider_target,
  )
  diagnostics.dependency_diagnostics.append(fatal_dependency_diagnostics[:])
  diagnostics.metrics.set("input_kind", pdf_native_input_kind_name(source.kind))
  diagnostics.metrics.set("ocr_provider_wired", "true")
  diagnostics.metrics.set("provider_invoked", "true")
  diagnostics.metrics.set("ocr_provider_status", "success")
  diagnostics.metrics.set(
    "ocr_provider_selection_target",
    @focr.ocr_provider_selection_target_name(provider_target),
  )
  diagnostics.metrics.set(
    "ocr_provider_requested_kind",
    @focr.ocr_provider_kind_name(
      @focr.default_ocr_provider_kind_for_target(provider_target),
    ),
  )
  diagnostics.metrics.set(
    "ocr_provider_kind",
    @focr.ocr_provider_kind_name(provider_kind),
  )
  diagnostics.metrics.set(
    "ocr_provider_name",
    @focr.ocr_provider_kind_name(provider_kind),
  )
  diagnostics.metrics.set("ocr_provider_version", "unknown")
  diagnostics.metrics.set("block_count", blocks.length().to_string())
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
  diagnostics.metrics.set(
    "pdf_ocr_policy",
    @parser.pdf_ocr_policy_name(context.pdf_ocr_policy),
  )
  diagnostics.metrics.set(
    "pdf_ocr_trigger",
    if context.pdf_ocr_policy == @parser.PdfOcrPolicy::AutoScanned {
      "auto_scanned"
    } else {
      "explicit"
    },
  )
  diagnostics.metrics.set(
    "mixed_page_route",
    if native_text_page_count > 0 && ocr_success_count > 0 {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set("pdf_v2_used", "false")
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
  diagnostics.metrics.set("native_impl_location", "formats")
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
  for item in warnings {
    diagnostics.warnings.push(item)
  }
  diagnostics.pass_trace.push("parse:pdf_ocr_parser")
  diagnostics.pass_trace.push("pdf_ocr:layout_two_stage")
  if context.pdf_ocr_policy == @parser.PdfOcrPolicy::AutoScanned {
    diagnostics.pass_trace.push("pdf_ocr:auto_scanned_hybrid")
  } else {
    diagnostics.pass_trace.push("pdf_ocr:explicit_full_document")
  }

  let document = @core.document_from_blocks(blocks)
  document.metadata.set("pdf_ocr_used", @core.JsonValue::Bool(true))
  document.metadata.set(
    "pdf_native_text_baseline",
    @core.JsonValue::Bool(native_text_page_count > 0),
  )
  document.metadata.set("pdf_v2_used", @core.JsonValue::Bool(false))
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
fn pdf_native_page_has_text(page : PdfNativePage) -> Bool {
  for block in page.text_blocks {
    for line in block.lines {
      if line.spans.length() > 0 {
        return true
      }
    }
  }
  false
}

///|
fn pdf_native_parser_enabled_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
  capability : @parser.ParserCapability,
) -> Result[@parser.ParseResult, @parser.ParseResult] {
  match extract_pdf_native_document(source) {
    Ok(native_document) => {
      let lowered = pdf_native_document_to_blocks_with_policies(
        native_document,
        context.pdf_header_footer_filter_policy,
      )
      let metadata = lowered.0
      let blocks = lowered.1
      let stream_diagnostics = lowered.2
      let document = @core.document_from_blocks(blocks)
      for entry in metadata.to_array() {
        document.metadata.set(entry.0, entry.1)
      }
      document.blocks.append(pdf_native_appendix_blocks(document.metadata)[:])
      let diagnostics = pdf_native_enabled_success_diagnostics(
        source, context, stream_diagnostics,
      )
      let final_document = @core.document_with_diagnostics(
        document, diagnostics,
      )
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
  next.metrics.set("native_impl_location", "formats")
  next.metrics.set("pdf_native_backend", "true")
  next.metrics.set("pdf_native_text_baseline", "true")
  next.metrics.set("pdf_ocr_used", "false")
  next.metrics.set("pdf_v2_used", "false")
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
  diagnostics.metrics.set("native_impl_location", "formats")
  diagnostics.metrics.set("pdf_native_backend", "true")
  diagnostics.metrics.set("pdf_native_text_baseline", "true")
  diagnostics.metrics.set("pdf_ocr_used", "false")
  diagnostics.metrics.set("pdf_v2_used", "false")
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
