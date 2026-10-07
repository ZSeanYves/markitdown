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
      Some(@parser.mode_name(PageSinglePass)),
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
  diagnostics.metrics.set("pdf_native_backend", "false")
  diagnostics.metrics.set("pdf_native_text_baseline", "false")
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
    if context.pdf_header_footer_filter_policy == Disabled {
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
    if context.pdf_table_reconstruction_policy == Disabled {
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
  diagnostics.metrics.set("native_impl_location", "internal/readers/pdf")
  diagnostics.metrics.set("pdf_reader_impl", "internal/readers/pdf")
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
    EnableTextRestore =>
      pdf_native_parser_enabled_result(source, context, capability)
    DisableTextRestore => {
      let diagnostics = pdf_native_fail_closed_diagnostics(source, context)
      Err(
        @parser.parse_result_with_document_capability(
          pdf_native_parser_name(),
          PageSinglePass,
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
  @parser.make_parser(pdf_native_parser_name(), PageSinglePass, capability, fn(
    source : @input.InputSource,
    context : @parser.ParseContext,
  ) -> Result[@parser.ParseResult, String] {
    match pdf_native_parser_result_with_gate(source, context) {
      Ok(result) => Ok(result)
      Err(result) =>
        match context.pdf_native_runtime_policy {
          EnableTextRestore =>
            Err(pdf_native_parser_error_message(result.diagnostics))
          DisableTextRestore => {
            ignore(result)
            Err(pdf_native_fail_closed_message())
          }
        }
    }
  })
}
