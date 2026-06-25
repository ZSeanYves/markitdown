///|
const PDF_NATIVE_PARSER_NAME : String = "pdf_native_parser"

///|
const PDF_NATIVE_FAIL_CLOSED_MESSAGE : String = "PDF native text restore is disabled by parser policy"

///|
pub fn pdf_native_parser_name() -> String {
  PDF_NATIVE_PARSER_NAME
}

///|
pub fn pdf_native_fail_closed_message() -> String {
  PDF_NATIVE_FAIL_CLOSED_MESSAGE
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
  diagnostics.degraded_features.push("pdf_native_scaffold_only")
  diagnostics.fallback_trace.push(
    "pdf native parser scaffolded -> fail closed until text PDF restore lands",
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
  diagnostics.metrics.set("fallback_reason_kind", "scaffold_only")
  diagnostics.metrics.set("warning_count", "1")
  diagnostics.metrics.set("error_count", "0")
  diagnostics.metrics.set("fallback_count", "1")
  diagnostics.metrics.set("runtime_exposed", "false")
  diagnostics.metrics.set("product_path_enabled", "false")
  diagnostics.metrics.set("legacy_runtime_dependency", "none")
  diagnostics.metrics.set("legacy_convert_dependency", "none")
  diagnostics.metrics.set("legacy_fallback", "forbidden")
  diagnostics.metrics.set("readiness_status", "scaffold_only")
  diagnostics.metrics.set("format_contract", "pdf")
  diagnostics.metrics.set("migration_stage", "stage_c_pdf_policy_disabled")
  diagnostics.metrics.set("native_impl_location", "formats")
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
  next.metrics.set("runtime_exposed", "true")
  next.metrics.set("product_path_enabled", "true")
  next.metrics.set("readiness_status", "native_text_baseline")
  next.metrics.set("migration_stage", "stage_c_pdf_native_text_baseline")
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
  diagnostics.metrics.set("page_count", "0")
  diagnostics.metrics.set("table_count", "0")
  diagnostics.metrics.set("image_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("scanned_page_ratio", "0")
  diagnostics.metrics.set("ocr_used_pages", "0")
  diagnostics.metrics.set("model_used", "none")
  diagnostics.metrics.set("model_confidence", "0")
  diagnostics.metrics.set("runtime_exposed", "true")
  diagnostics.metrics.set("product_path_enabled", "true")
  diagnostics.metrics.set("readiness_status", "native_text_baseline")
  diagnostics.metrics.set("format_contract", "pdf")
  diagnostics.metrics.set("migration_stage", "stage_c_pdf_native_text_baseline")
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
