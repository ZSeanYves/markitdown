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
  native_document : @dpdfnative.PdfNativeDocument,
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
    Some(pdf_native_input_kind_name(@input.input_kind(source))),
    Some("pdf"),
  )
  next.pass_trace.push("parse:pdf_native_parser")
  next.pass_trace.push("pdf_native:parser_success_path")
  next.metrics.set("parser_name", pdf_native_parser_name())
  next.metrics.set("parser_mode", "page_single_pass")
  next.metrics.set(
    "input_kind",
    pdf_native_input_kind_name(@input.input_kind(source)),
  )
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
    Some(pdf_native_input_kind_name(@input.input_kind(source))),
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
    @input.InputKind::Reader => "reader"
  }
}

///|
fn pdf_native_requested_mode_name(context : @parser.ParseContext) -> String {
  match context.requested_mode {
    Some(mode) => @parser.mode_name(mode)
    None => "default"
  }
}
