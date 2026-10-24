///|
/// Create a parse context with safe product defaults for the detected format.
pub fn new_parse_context(
  detected_format : @input.DetectedFormat,
) -> ParseContext {
  {
    detected_format,
    input_source: None,
    input_access_limit: None,
    report_resource_limit_failure: fn(_) {  },
    requested_mode: None,
    fidelity_mode: Balanced,
    output_mode: Markdown,
    execution_profile: Standard,
    lowering_profile: Canonical,
    render_profile: DefaultMarkdown,
    accurate_features: @product.empty_accurate_feature_profile(),
    pdf_native_runtime_policy: default_pdf_native_runtime_policy(),
    pdf_header_footer_filter_policy: default_pdf_header_footer_filter_policy(),
    pdf_table_reconstruction_policy: default_pdf_table_reconstruction_policy(),
    limits: @product.default_resource_limits(),
    max_rows: None,
    max_cols: None,
    max_cells: None,
    max_line_chars: None,
    debug: false,
  }
}

///|
/// Keep the same conversion session when lowering embedded documents. The
/// child's representation and byte extent remain its own InputSource fields.
pub fn parse_context_with_input_source(
  context : ParseContext,
  source : @input.InputSource,
) -> ParseContext {
  {
    ..context,
    input_source: Some(source),
    report_resource_limit_failure: fn(failure) {
      (context.report_resource_limit_failure)(failure)
      @input.record_input_resource_failure(source, failure)
    },
  }
}

///|
pub fn parse_context_inherit_session(
  context : ParseContext,
  parent : ParseContext,
) -> ParseContext {
  {
    ..context,
    input_source: parent.input_source,
    input_access_limit: parent.input_access_limit,
    report_resource_limit_failure: parent.report_resource_limit_failure,
  }
}

///|
pub fn default_pdf_native_runtime_policy() -> PdfNativeRuntimePolicy {
  EnableTextRestore
}

///|
pub fn default_pdf_header_footer_filter_policy() -> PdfHeaderFooterFilterPolicy {
  Disabled
}

///|
pub fn default_pdf_table_reconstruction_policy() -> PdfTableReconstructionPolicy {
  Disabled
}

///|
/// Merge product-level fidelity and output choices into an existing parse
/// context.
pub fn parse_context_with_product_modes(
  context : ParseContext,
  fidelity_mode : @product.FidelityMode,
  output_mode : @product.OutputMode,
) -> ParseContext {
  let accurate_features = if fidelity_mode == Accurate {
    @product.make_accurate_feature_profile(
      @product.accurate_features_for_detected_format(context.detected_format).copy(),
    )
  } else {
    @product.empty_accurate_feature_profile()
  }
  {
    ..context,
    fidelity_mode,
    output_mode,
    lowering_profile: if fidelity_mode == Accurate {
      AccurateSemantic
    } else {
      context.lowering_profile
    },
    accurate_features,
  }
}

///|
/// Attach execution, lowering, render, and accurate-feature profiles to a
/// parse context.
pub fn parse_context_with_execution_profiles(
  context : ParseContext,
  execution_profile : @product.ExecutionProfile,
  lowering_profile : @product.LoweringProfile,
  render_profile : @product.RenderProfile,
  accurate_features : @product.AccurateFeatureProfile,
) -> ParseContext {
  {
    ..context,
    execution_profile,
    lowering_profile,
    render_profile,
    accurate_features,
  }
}

///|
/// Return a copy of `context` with the resolved PDF native-runtime policy.
pub fn parse_context_with_pdf_native_runtime_policy(
  context : ParseContext,
  pdf_native_runtime_policy : PdfNativeRuntimePolicy,
) -> ParseContext {
  { ..context, pdf_native_runtime_policy, }
}

///|
/// Return a copy of `context` with the resolved header/footer filter policy.
pub fn parse_context_with_pdf_header_footer_filter_policy(
  context : ParseContext,
  pdf_header_footer_filter_policy : PdfHeaderFooterFilterPolicy,
) -> ParseContext {
  { ..context, pdf_header_footer_filter_policy, }
}

///|
/// Return a copy of `context` with the resolved table-reconstruction policy.
pub fn parse_context_with_pdf_table_reconstruction_policy(
  context : ParseContext,
  pdf_table_reconstruction_policy : PdfTableReconstructionPolicy,
) -> ParseContext {
  { ..context, pdf_table_reconstruction_policy, }
}

///|
/// Return a copy of `context` with route-selected size limits and debug mode.
pub fn parse_context_with_limits(
  context : ParseContext,
  requested_mode : ParserMode?,
  max_rows : Int32?,
  max_cols : Int32?,
  max_cells : Int32?,
  max_line_chars : Int32?,
  debug : Bool,
  limits~ : @product.ResourceLimits = context.limits,
) -> ParseContext {
  {
    ..context,
    requested_mode,
    max_rows,
    max_cols,
    max_cells,
    max_line_chars,
    limits,
    debug,
  }
}

///|
/// Bind the conversion owner's typed resource-failure reporter. Context
/// copies retain it, including nested lowering and prepared parse routes.
pub fn parse_context_with_resource_failure_reporter(
  context : ParseContext,
  report_resource_limit_failure : (@input.ResourceLimitFailure) -> Unit,
) -> ParseContext {
  { ..context, report_resource_limit_failure, }
}

///|
/// Check before creating an asset. A rejected payload records a hard failure
/// with the conversion owner; it must never become successful degraded output.
pub fn require_asset_payload_within_limits(
  context : ParseContext,
  declared_bytes : Int64,
  materialized_bytes : Int64,
) -> Bool {
  if declared_bytes < 0L || materialized_bytes < 0L {
    return false
  }
  if declared_bytes > context.limits.max_asset_bytes {
    (context.report_resource_limit_failure)(
      @input.make_resource_limit_failure(
        SingleAssetBytes,
        declared_bytes,
        context.limits.max_asset_bytes,
      ),
    )
    return false
  }
  let limit = context.limits.max_total_asset_bytes
  if materialized_bytes > limit || declared_bytes > limit - materialized_bytes {
    // The public error stores Int64 observations. Saturate an unrepresentable
    // total rather than wrapping it into an apparently permitted byte count.
    let total = if declared_bytes > 9223372036854775807L - materialized_bytes {
      9223372036854775807L
    } else {
      materialized_bytes + declared_bytes
    }
    (context.report_resource_limit_failure)(
      @input.make_resource_limit_failure(TotalAssetBytes, total, limit),
    )
    return false
  }
  true
}

///|
/// Return the configured input ceiling for streaming parsers.
pub fn max_input_bytes(context : ParseContext) -> Int64 {
  context.input_access_limit.unwrap_or(context.limits.max_input_bytes)
}

///|
/// A derived entry has its own access unit. Root raw input keeps ResourceLimits.
pub fn parse_context_with_input_access_limit(
  context : ParseContext,
  limit : Int64?,
) -> ParseContext {
  { ..context, input_access_limit: limit, }
}

///|
/// Return the configured line ceiling for streaming text parsers.
pub fn max_line_chars(context : ParseContext) -> Int32 {
  context.max_line_chars.unwrap_or(4000)
}

///|
/// Count payload bytes already materialized by a parser lowering pass.
pub fn materialized_asset_payload_bytes(
  assets : Array[@core.AssetRef],
) -> Int64 {
  let mut total = 0L
  for asset in assets {
    match asset.payload {
      Some(Bytes(bytes)) => total += bytes.length().to_int64()
      Some(Utf8(text)) => total += @utf8.encode(text).length().to_int64()
      _ => ()
    }
  }
  total
}

///|
/// Return a context with explicit per-asset and cumulative asset ceilings.
/// This helper keeps ResourceLimits construction owned by the product package.
pub fn parse_context_with_asset_limits(
  context : ParseContext,
  max_asset_bytes : Int64,
  max_total_asset_bytes : Int64,
) -> ParseContext {
  let current = context.limits
  let limits = @product.make_resource_limits(
    current.max_rows,
    current.max_cols,
    current.max_cells,
    max_line_chars=current.max_line_chars,
    max_input_bytes=current.max_input_bytes,
    max_asset_bytes~,
    max_total_asset_bytes~,
    max_temporary_bytes=current.max_temporary_bytes,
  )
  { ..context, limits, }
}

///|
pub fn pdf_native_runtime_policy_name(
  policy : PdfNativeRuntimePolicy,
) -> String {
  match policy {
    DisableTextRestore => "disable_text_restore"
    EnableTextRestore => "enable_text_restore"
  }
}

///|
pub fn pdf_header_footer_filter_policy_name(
  policy : PdfHeaderFooterFilterPolicy,
) -> String {
  match policy {
    Disabled => "disabled"
    InternalHighConfidenceOnly => "internal_high_confidence_only"
  }
}

///|
pub fn pdf_table_reconstruction_policy_name(
  policy : PdfTableReconstructionPolicy,
) -> String {
  match policy {
    Disabled => "disabled"
    InternalSimpleRowsOnly => "internal_simple_rows_only"
  }
}
