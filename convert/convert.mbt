///|
pub(all) enum ConvertMode {
  Fast
  Balanced
  Accurate
  Stream
  Rag
  Debug
} derive(Eq)

///|
pub(all) enum OutputFormat {
  Markdown
  Json
  RagJson
  DebugJson
} derive(Eq)

///|
pub struct ResourceLimits {
  max_rows : Int
  max_cols : Int
  max_cells : Int
  max_line_chars : Int
}

///|
pub(all) enum PdfCleanupMode {
  Disabled
  Conservative
} derive(Eq)

///|
pub(all) enum PdfTableMode {
  Disabled
  Simple
} derive(Eq)

///|
pub struct ConvertOptions {
  mode : ConvertMode
  output_format : OutputFormat
  explicit_format : @input.DetectedFormat?
  ocr_options : @parser.OcrOptions
  limits : ResourceLimits
  pdf_cleanup_mode : PdfCleanupMode
  pdf_table_mode : PdfTableMode
}

///|
pub(all) enum ConvertError {
  DetectFailed(String)
  ParseFailed(String)
  RenderFailed(String)
} derive(Eq)

///|
pub impl Show for ConvertError with fn to_string(self : ConvertError) -> String {
  match self {
    DetectFailed(msg) => "detect failed: " + msg
    ParseFailed(msg) => "parse failed: " + msg
    RenderFailed(msg) => "render failed: " + msg
  }
}

///|
pub impl Show for ConvertError with fn output(
  self : ConvertError,
  logger : &Logger,
) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub struct ConvertResult {
  content : String
  detected_format : @input.DetectedFormat
  parser_mode : @parser.ParserMode
  convert_mode : ConvertMode
  diagnostics : @core.Diagnostics
  assets : Array[@core.AssetRef]
}

///|
pub fn default_resource_limits() -> ResourceLimits {
  { max_rows: 2000, max_cols: 50, max_cells: 100000, max_line_chars: 4000 }
}

///|
pub fn make_resource_limits(
  max_rows : Int,
  max_cols : Int,
  max_cells : Int,
  max_line_chars? : Int = 4000,
) -> ResourceLimits {
  { max_rows, max_cols, max_cells, max_line_chars }
}

///|
pub fn default_convert_options() -> ConvertOptions {
  {
    mode: ConvertMode::Balanced,
    output_format: OutputFormat::Markdown,
    explicit_format: None,
    ocr_options: @parser.default_ocr_options(),
    limits: default_resource_limits(),
    pdf_cleanup_mode: default_pdf_cleanup_mode(),
    pdf_table_mode: default_pdf_table_mode(),
  }
}

///|
pub fn make_convert_options(
  mode : ConvertMode,
  output_format : OutputFormat,
  explicit_format : @input.DetectedFormat?,
  ocr_options : @parser.OcrOptions,
  limits : ResourceLimits,
  pdf_cleanup_mode? : PdfCleanupMode = default_pdf_cleanup_mode(),
  pdf_table_mode? : PdfTableMode = default_pdf_table_mode(),
) -> ConvertOptions {
  {
    mode,
    output_format,
    explicit_format,
    ocr_options,
    limits,
    pdf_cleanup_mode,
    pdf_table_mode,
  }
}

///|
pub fn convert_input(
  source : @input.InputSource,
  options : ConvertOptions,
) -> Result[ConvertResult, ConvertError] {
  convert_input_with_image_ocr_provider(
    source, options, @focr.run_tesseract_provider,
  )
}

///|
pub fn convert_input_with_image_ocr_provider(
  source : @input.InputSource,
  options : ConvertOptions,
  image_ocr_provider : (@focr.OcrProviderRequest) -> Result[
    @focr.OcrProviderResult,
    @focr.OcrProviderError,
  ],
) -> Result[ConvertResult, ConvertError] {
  let effective_source = match options.explicit_format {
    Some(format) => @input.with_explicit_format(source, Some(format))
    None => source
  }
  let detector = @input.default_format_detector()
  let detected = (detector.detect)(effective_source)
  if detected.format == @input.DetectedFormat::Unknown {
    return Err(ConvertError::DetectFailed("unknown format"))
  }
  if detected.format == @input.DetectedFormat::Pdf &&
    options.ocr_options.intent == @parser.OcrIntent::Explicit {
    return Err(
      ConvertError::ParseFailed(
        "PDF OCR is not supported on the current root runtime; native-text PDF restore is enabled, but scanned/image-only PDFs and PDF --ocr remain fail-closed.",
      ),
    )
  }
  if @input.detected_format_is_image_candidate(detected.format) {
    let requested_mode = match options.ocr_options.intent {
      @parser.OcrIntent::Explicit => Some(@parser.ParserMode::LayoutTwoStage)
      _ => None
    }
    let parsed = match
      @focr.image_ocr_parser_result_with_provider(
        effective_source,
        detected.format,
        options.ocr_options,
        image_ocr_provider,
        requested_mode~,
      ) {
      Ok(value) => value
      Err(err) => return Err(ConvertError::ParseFailed(err))
    }
    return Ok(
      finalize_image_convert_result(
        effective_source,
        detected.format,
        options,
        parsed,
      ),
    )
  }
  let detect_trace = format_detection_trace(detected)
  let preparse_diagnostics = @core.empty_diagnostics()
  preparse_diagnostics.pass_trace.push("detect:" + detect_trace)
  preparse_diagnostics.pass_trace.push("registry:lookup")
  let registry = @formats.builtin_registry()
  let parse_context = @parser.parse_context_with_limits(
    parse_context_with_product_pdf_modes(
      @parser.parse_context_with_ocr_options(
        @parser.new_parse_context(detected.format),
        options.ocr_options,
      ),
      detected.format,
      options,
    ),
    convert_mode_to_parser_mode(options.mode),
    Some(options.limits.max_rows),
    Some(options.limits.max_cols),
    Some(options.limits.max_cells),
    Some(options.limits.max_line_chars),
    options.mode == ConvertMode::Debug,
  )
  let parsed = match
    @parser.registry_parse(registry, effective_source, parse_context) {
    Ok(result) => result
    Err(err) => return Err(ConvertError::ParseFailed(err))
  }
  let parse_diagnostics = @runtime.merge_diagnostics_unique(
    preparse_diagnostics,
    parsed.diagnostics,
  )
  let input = @runtime.parse_result_to_ir_input(parsed)
  let mut document = @pipeline.build_document_with_default_pipeline(
    input,
    @pipeline.make_pass_context(
      options.mode == ConvertMode::Debug,
      convert_mode_name(options.mode),
    ),
  )
  let merged_diagnostics = @runtime.merge_diagnostics_unique(
    parse_diagnostics,
    document.diagnostics,
  )
  merged_diagnostics.metrics.set(
    "convert_mode",
    convert_mode_name(options.mode),
  )
  merged_diagnostics.metrics.set(
    "detected_format",
    @input.detected_format_name(detected.format),
  )
  merged_diagnostics.metrics.set(
    "input_kind",
    input_kind_name(effective_source.kind),
  )
  merged_diagnostics.metrics.set(
    "format_detector_notes",
    detected.notes.join("|"),
  )
  let final_diagnostics = @core.diagnostics_with_mode(
    @core.diagnostics_with_input(
      merged_diagnostics,
      Some(input_kind_name(effective_source.kind)),
      Some(@input.detected_format_name(detected.format)),
    ),
    Some(parsed.mode |> @parser.mode_name),
    Some(convert_mode_name(options.mode)),
  )
  apply_pdf_product_option_metrics(final_diagnostics, detected.format, options)
  document = @core.document_with_diagnostics(document, final_diagnostics)
  let renderer = renderer_for_output(options.output_format)
  document.diagnostics.pass_trace.push("render:" + renderer.name)
  let rendered = (renderer.render)(
    document,
    @render.make_render_context(options.mode == ConvertMode::Debug),
  )
  Ok({
    content: rendered.content,
    detected_format: detected.format,
    parser_mode: parsed.mode,
    convert_mode: options.mode,
    diagnostics: rendered.diagnostics,
    assets: document.assets,
  })
}

///|
pub async fn convert_input_with_image_ocr_provider_async(
  source : @input.InputSource,
  options : ConvertOptions,
  image_ocr_provider : async (@focr.OcrProviderRequest) -> Result[
    @focr.OcrProviderResult,
    @focr.OcrProviderError,
  ],
) -> Result[ConvertResult, ConvertError] {
  let effective_source = match options.explicit_format {
    Some(format) => @input.with_explicit_format(source, Some(format))
    None => source
  }
  let detector = @input.default_format_detector()
  let detected = (detector.detect)(effective_source)
  if detected.format == @input.DetectedFormat::Unknown {
    return Err(ConvertError::DetectFailed("unknown format"))
  }
  if detected.format == @input.DetectedFormat::Pdf &&
    options.ocr_options.intent == @parser.OcrIntent::Explicit {
    return Err(
      ConvertError::ParseFailed(
        "PDF OCR is not supported on the current root runtime; native-text PDF restore is enabled, but scanned/image-only PDFs and PDF --ocr remain fail-closed.",
      ),
    )
  }
  if @input.detected_format_is_image_candidate(detected.format) {
    let requested_mode = match options.ocr_options.intent {
      @parser.OcrIntent::Explicit => Some(@parser.ParserMode::LayoutTwoStage)
      _ => None
    }
    let parsed = match
      @focr.image_ocr_parser_result_with_async_provider(
        effective_source,
        detected.format,
        options.ocr_options,
        image_ocr_provider,
        requested_mode~,
      ) {
      Ok(value) => value
      Err(err) => return Err(ConvertError::ParseFailed(err))
    }
    return Ok(
      finalize_image_convert_result(
        effective_source,
        detected.format,
        options,
        parsed,
      ),
    )
  }
  convert_input(effective_source, { ..options, explicit_format: None })
}

///|
pub fn convert_mode_name(mode : ConvertMode) -> String {
  match mode {
    ConvertMode::Fast => "fast"
    ConvertMode::Balanced => "balanced"
    ConvertMode::Accurate => "accurate"
    ConvertMode::Stream => "stream"
    ConvertMode::Rag => "rag"
    ConvertMode::Debug => "debug"
  }
}

///|
pub fn default_pdf_cleanup_mode() -> PdfCleanupMode {
  PdfCleanupMode::Disabled
}

///|
pub fn default_pdf_table_mode() -> PdfTableMode {
  PdfTableMode::Disabled
}

///|
pub fn pdf_cleanup_promotion_target() -> PdfCleanupMode {
  PdfCleanupMode::Conservative
}

///|
pub fn pdf_table_promotion_target() -> PdfTableMode {
  PdfTableMode::Simple
}

///|
pub fn pdf_cleanup_mode_name(mode : PdfCleanupMode) -> String {
  match mode {
    PdfCleanupMode::Disabled => "none"
    PdfCleanupMode::Conservative => "conservative"
  }
}

///|
pub fn pdf_table_mode_name(mode : PdfTableMode) -> String {
  match mode {
    PdfTableMode::Disabled => "none"
    PdfTableMode::Simple => "simple"
  }
}

///|
fn convert_mode_to_parser_mode(mode : ConvertMode) -> @parser.ParserMode? {
  match mode {
    ConvertMode::Stream => Some(@parser.ParserMode::StreamingEvent)
    _ => None
  }
}

///|
fn parse_context_with_product_pdf_modes(
  context : @parser.ParseContext,
  detected_format : @input.DetectedFormat,
  options : ConvertOptions,
) -> @parser.ParseContext {
  if detected_format != @input.DetectedFormat::Pdf {
    return context
  }
  @parser.parse_context_with_pdf_table_reconstruction_policy(
    @parser.parse_context_with_pdf_header_footer_filter_policy(
      context,
      pdf_cleanup_mode_to_filter_policy(options.pdf_cleanup_mode),
    ),
    pdf_table_mode_to_reconstruction_policy(options.pdf_table_mode),
  )
}

///|
fn pdf_cleanup_mode_to_filter_policy(
  mode : PdfCleanupMode,
) -> @parser.PdfHeaderFooterFilterPolicy {
  match mode {
    PdfCleanupMode::Disabled => @parser.PdfHeaderFooterFilterPolicy::Disabled
    PdfCleanupMode::Conservative =>
      @parser.PdfHeaderFooterFilterPolicy::InternalHighConfidenceOnly
  }
}

///|
fn pdf_table_mode_to_reconstruction_policy(
  mode : PdfTableMode,
) -> @parser.PdfTableReconstructionPolicy {
  match mode {
    PdfTableMode::Disabled => @parser.PdfTableReconstructionPolicy::Disabled
    PdfTableMode::Simple =>
      @parser.PdfTableReconstructionPolicy::InternalSimpleRowsOnly
  }
}

///|
fn finalize_image_convert_result(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : ConvertOptions,
  parsed : @parser.ParseResult,
) -> ConvertResult {
  let input = @runtime.parse_result_to_ir_input(parsed)
  let mut document = @pipeline.build_document_with_default_pipeline(
    input,
    @pipeline.make_pass_context(
      options.mode == ConvertMode::Debug,
      convert_mode_name(options.mode),
    ),
  )
  let merged_diagnostics = @runtime.merge_diagnostics_unique(
    parsed.diagnostics,
    document.diagnostics,
  )
  merged_diagnostics.metrics.set(
    "convert_mode",
    convert_mode_name(options.mode),
  )
  merged_diagnostics.metrics.set(
    "detected_format",
    @input.detected_format_name(detected_format),
  )
  merged_diagnostics.metrics.set("input_kind", input_kind_name(source.kind))
  let final_diagnostics = @core.diagnostics_with_mode(
    @core.diagnostics_with_input(
      merged_diagnostics,
      Some(input_kind_name(source.kind)),
      Some(@input.detected_format_name(detected_format)),
    ),
    Some(parsed.mode |> @parser.mode_name),
    Some(convert_mode_name(options.mode)),
  )
  document = @core.document_with_diagnostics(document, final_diagnostics)
  let renderer = renderer_for_output(options.output_format)
  document.diagnostics.pass_trace.push("render:" + renderer.name)
  let rendered = (renderer.render)(
    document,
    @render.make_render_context(options.mode == ConvertMode::Debug),
  )
  {
    content: rendered.content,
    detected_format,
    parser_mode: parsed.mode,
    convert_mode: options.mode,
    diagnostics: rendered.diagnostics,
    assets: document.assets,
  }
}

///|
fn renderer_for_output(format : OutputFormat) -> @render.Renderer {
  match format {
    OutputFormat::Markdown => @render.markdown_renderer()
    OutputFormat::Json => @render.debug_json_renderer()
    OutputFormat::RagJson => @render.debug_json_renderer()
    OutputFormat::DebugJson => @render.debug_json_renderer()
  }
}

///|
fn apply_pdf_product_option_metrics(
  diagnostics : @core.Diagnostics,
  detected_format : @input.DetectedFormat,
  options : ConvertOptions,
) -> Unit {
  if detected_format != @input.DetectedFormat::Pdf {
    return
  }
  diagnostics.metrics.set(
    "pdf_cleanup_mode",
    pdf_cleanup_mode_name(options.pdf_cleanup_mode),
  )
  diagnostics.metrics.set(
    "pdf_cleanup_enabled",
    if options.pdf_cleanup_mode == PdfCleanupMode::Disabled {
      "false"
    } else {
      "true"
    },
  )
  diagnostics.metrics.set(
    "pdf_cleanup_default_mode",
    pdf_cleanup_mode_name(default_pdf_cleanup_mode()),
  )
  diagnostics.metrics.set(
    "pdf_cleanup_promotion_target",
    pdf_cleanup_mode_name(pdf_cleanup_promotion_target()),
  )
  diagnostics.metrics.set(
    "pdf_table_mode",
    pdf_table_mode_name(options.pdf_table_mode),
  )
  diagnostics.metrics.set(
    "pdf_table_enabled",
    if options.pdf_table_mode == PdfTableMode::Disabled {
      "false"
    } else {
      "true"
    },
  )
  diagnostics.metrics.set(
    "pdf_table_default_mode",
    pdf_table_mode_name(default_pdf_table_mode()),
  )
  diagnostics.metrics.set(
    "pdf_table_promotion_target",
    pdf_table_mode_name(pdf_table_promotion_target()),
  )
}

///|
fn format_detection_trace(result : @input.FormatDetectionResult) -> String {
  let parts : Array[String] = [@input.detected_format_name(result.format)]
  if result.used_explicit_format {
    parts.push("explicit")
  }
  if result.used_extension {
    parts.push("extension")
  }
  if result.notes.length() > 0 {
    parts.push(result.notes.join("+"))
  }
  parts.join(":")
}

///|
fn input_kind_name(kind : @input.InputKind) -> String {
  match kind {
    @input.InputKind::Path => "path"
    @input.InputKind::Text => "text"
    @input.InputKind::Bytes => "bytes"
  }
}
