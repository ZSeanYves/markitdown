///|
/// Create a parse context with safe product defaults for the detected format.
pub fn new_parse_context(
  detected_format : @input.DetectedFormat,
) -> ParseContext {
  {
    detected_format,
    requested_mode: None,
    fidelity_mode: Balanced,
    output_mode: Markdown,
    execution_profile: Standard,
    lowering_profile: Canonical,
    render_profile: DefaultMarkdown,
    accurate_features: @product.empty_accurate_feature_profile(),
    ocr_options: default_ocr_options(),
    audio_options: default_audio_options(),
    pdf_native_runtime_policy: default_pdf_native_runtime_policy(),
    pdf_header_footer_filter_policy: default_pdf_header_footer_filter_policy(),
    pdf_table_reconstruction_policy: default_pdf_table_reconstruction_policy(),
    max_rows: None,
    max_cols: None,
    max_cells: None,
    max_line_chars: None,
    debug: false,
  }
}

///|
/// Default OCR policy for normal product execution.
pub fn default_ocr_options() -> OcrOptions {
  { intent: Auto, language: None }
}

///|
/// Default audio-transcription hints for media inputs.
pub fn default_audio_options() -> AudioOptions {
  { language: None }
}

///|
/// Build explicit audio options, typically from CLI input.
pub fn explicit_audio_options(language? : String? = None) -> AudioOptions {
  { language, }
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
/// Return OCR options that hard-disable OCR while still preserving an optional
/// language hint.
pub fn disabled_ocr_options(language? : String? = None) -> OcrOptions {
  { intent: Disabled, language }
}

///|
/// Return OCR options that explicitly force OCR with an optional language hint.
pub fn explicit_ocr_options(language? : String? = None) -> OcrOptions {
  { intent: Explicit, language }
}

///|
/// Return a copy of `context` with updated OCR settings.
pub fn parse_context_with_ocr_options(
  context : ParseContext,
  ocr_options : OcrOptions,
) -> ParseContext {
  { ..context, ocr_options, }
}

///|
/// Return a copy of `context` with updated audio-transcription hints.
pub fn parse_context_with_audio_options(
  context : ParseContext,
  audio_options : AudioOptions,
) -> ParseContext {
  { ..context, audio_options, }
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
  max_rows : Int?,
  max_cols : Int?,
  max_cells : Int?,
  max_line_chars : Int?,
  debug : Bool,
) -> ParseContext {
  {
    ..context,
    requested_mode,
    max_rows,
    max_cols,
    max_cells,
    max_line_chars,
    debug,
  }
}

///|
pub fn ocr_intent_name(intent : OcrIntent) -> String {
  match intent {
    Disabled => "disabled"
    Auto => "auto"
    Explicit => "explicit"
  }
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
