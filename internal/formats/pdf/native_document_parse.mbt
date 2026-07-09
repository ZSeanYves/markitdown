///|
pub fn pdf_parse_with_native_document(
  source : @input.InputSource,
  context : @parser.ParseContext,
  native_document : @dpdfnative.PdfNativeDocument,
  probe_artifact_reused? : Bool = false,
) -> @parser.ParseResult {
  let document = @pdfroot.pdf_native_document_to_ir_with_policies(
    native_document,
    context.pdf_header_footer_filter_policy,
    context.pdf_table_reconstruction_policy,
  )
  let diagnostics = document.diagnostics
  @fshared.mark_structured_document_profile(diagnostics)
  let next = @core.diagnostics_with_input(
    @core.diagnostics_with_parser(
      diagnostics,
      Some(@pdfroot.pdf_native_parser_name()),
      Some(@parser.mode_name(@parser.ParserMode::PageSinglePass)),
    ),
    Some(pdf_native_input_kind_name(source.kind)),
    Some("pdf"),
  )
  next.pass_trace.push("parse:pdf_native_parser")
  next.pass_trace.push("pdf_native:parser_success_path")
  next.metrics.set("parser_name", @pdfroot.pdf_native_parser_name())
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
    if probe_artifact_reused {
      "true"
    } else {
      "false"
    },
  )
  next.metrics.set("process_cache_hit", "false")
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
  let final_document = @core.document_with_diagnostics(document, next)
  @parser.parse_result_with_document_capability(
    @pdfroot.pdf_native_parser_name(),
    @parser.ParserMode::PageSinglePass,
    final_document,
    next,
    @pdfroot.pdf_native_parser_capability(),
  )
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
