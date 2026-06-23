///|
pub fn ocr_image_parser_capability() -> @parser.ParserCapability {
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
pub fn image_requires_explicit_ocr_message(
  format : @input.DetectedFormat,
) -> String {
  "image OCR is not enabled for " +
  @input.detected_format_name(format) +
  " inputs on the current root runtime; future support requires an explicit OCR path"
}

///|
pub fn image_ocr_provider_not_wired_message(
  format : @input.DetectedFormat,
  options : @parser.OcrOptions,
) -> String {
  let language_note = match options.language {
    Some(lang) => {
      let trimmed = lang.trim().to_owned()
      if trimmed == "" {
        ""
      } else {
        " language=" + trimmed
      }
    }
    None => ""
  }
  "OCR provider is not wired yet for " +
  @input.detected_format_name(format) +
  " inputs on the current root runtime." +
  language_note
}

///|
pub fn image_ocr_provider_error_message(
  format : @input.DetectedFormat,
  error : OcrProviderError,
) -> String {
  error.to_string() + " image_format=" + @input.detected_format_name(format)
}

///|
pub fn image_ocr_disabled_message(format : @input.DetectedFormat) -> String {
  "image input conversion is not enabled for " +
  @input.detected_format_name(format) +
  " inputs on the current root runtime; OCR is disabled"
}

///|
pub fn ocr_options_from_parse_context(
  context : @parser.ParseContext,
) -> @parser.OcrOptions {
  context.ocr_options
}

///|
pub fn image_ocr_parser() -> @parser.Parser {
  @parser.make_parser(
    "image_ocr_parser",
    @parser.ParserMode::LayoutTwoStage,
    ocr_image_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      let options = ocr_options_from_parse_context(context)
      image_ocr_parser_parse(
        source,
        context.detected_format,
        options,
        context.requested_mode,
        run_tesseract_provider,
      )
    },
  )
}

///|
pub fn image_ocr_parser_result(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : @parser.OcrOptions,
  requested_mode? : @parser.ParserMode? = None,
) -> Result[@parser.ParseResult, String] {
  image_ocr_parser_parse(
    source, detected_format, options, requested_mode, run_tesseract_provider,
  )
}

///|
pub fn image_ocr_parser_result_with_provider(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : @parser.OcrOptions,
  provider : (OcrProviderRequest) -> Result[OcrProviderResult, OcrProviderError],
  requested_mode? : @parser.ParserMode? = None,
) -> Result[@parser.ParseResult, String] {
  image_ocr_parser_parse(
    source, detected_format, options, requested_mode, provider,
  )
}

///|
pub async fn image_ocr_parser_result_with_async_provider(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : @parser.OcrOptions,
  provider : async (OcrProviderRequest) -> Result[
    OcrProviderResult,
    OcrProviderError,
  ],
  requested_mode? : @parser.ParserMode? = None,
) -> Result[@parser.ParseResult, String] {
  image_ocr_parser_parse_async(
    source, detected_format, options, requested_mode, provider,
  )
}

///|
pub fn image_ocr_fail_closed_diagnostics(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : @parser.OcrOptions,
  requested_mode? : @parser.ParserMode? = None,
) -> @core.Diagnostics {
  image_ocr_parser_diagnostics(
    source,
    detected_format,
    options,
    requested_mode,
    fn(_request) {
      Err(
        OcrProviderError::NotConfigured(
          "Tesseract OCR provider is not configured on the current root runtime.",
        ),
      )
    },
  )
}

///|
fn image_ocr_parser_parse(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : @parser.OcrOptions,
  _requested_mode : @parser.ParserMode?,
  provider : (OcrProviderRequest) -> Result[OcrProviderResult, OcrProviderError],
) -> Result[@parser.ParseResult, String] {
  if !@input.detected_format_is_image_candidate(detected_format) {
    return Err(
      "image_ocr_parser only accepts detected image formats; got " +
      @input.detected_format_name(detected_format),
    )
  }
  match options.intent {
    @parser.OcrIntent::Explicit => {
      let request = make_ocr_provider_request(
        image_source_path(source),
        OcrProviderKind::Tesseract,
        language=options.language,
      )
      match provider(request) {
        Ok(result) =>
          if result.pages.length() == 0 {
            Err(
              image_ocr_provider_error_message(
                detected_format,
                OcrProviderError::EmptyResult(
                  "OCR provider produced an empty OCR model on the current root runtime.",
                ),
              ),
            )
          } else {
            Ok(
              image_ocr_parse_result_from_provider_result(
                source, detected_format, options, result,
              ),
            )
          }
        Err(error) =>
          Err(image_ocr_provider_error_message(detected_format, error))
      }
    }
    @parser.OcrIntent::Disabled =>
      Err(image_ocr_disabled_message(detected_format))
    @parser.OcrIntent::Auto =>
      Err(image_requires_explicit_ocr_message(detected_format))
  }
}

///|
async fn image_ocr_parser_parse_async(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : @parser.OcrOptions,
  _requested_mode : @parser.ParserMode?,
  provider : async (OcrProviderRequest) -> Result[
    OcrProviderResult,
    OcrProviderError,
  ],
) -> Result[@parser.ParseResult, String] {
  if !@input.detected_format_is_image_candidate(detected_format) {
    return Err(
      "image_ocr_parser only accepts detected image formats; got " +
      @input.detected_format_name(detected_format),
    )
  }
  match options.intent {
    @parser.OcrIntent::Explicit => {
      let request = make_ocr_provider_request(
        image_source_path(source),
        OcrProviderKind::Tesseract,
        language=options.language,
      )
      match provider(request) {
        Ok(result) =>
          if result.pages.length() == 0 {
            Err(
              image_ocr_provider_error_message(
                detected_format,
                OcrProviderError::EmptyResult(
                  "OCR provider produced an empty OCR model on the current root runtime.",
                ),
              ),
            )
          } else {
            Ok(
              image_ocr_parse_result_from_provider_result(
                source, detected_format, options, result,
              ),
            )
          }
        Err(error) =>
          Err(image_ocr_provider_error_message(detected_format, error))
      }
    }
    @parser.OcrIntent::Disabled =>
      Err(image_ocr_disabled_message(detected_format))
    @parser.OcrIntent::Auto =>
      Err(image_requires_explicit_ocr_message(detected_format))
  }
}

///|
fn image_ocr_parser_diagnostics(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : @parser.OcrOptions,
  requested_mode : @parser.ParserMode?,
  provider : (OcrProviderRequest) -> Result[OcrProviderResult, OcrProviderError],
) -> @core.Diagnostics {
  let diagnostics = image_ocr_base_diagnostics(
    source, detected_format, options, requested_mode,
  )
  match options.intent {
    @parser.OcrIntent::Explicit => {
      let request = make_ocr_provider_request(
        image_source_path(source),
        OcrProviderKind::Tesseract,
        language=options.language,
      )
      diagnostics.metrics.set(
        "ocr_provider_request_kind",
        ocr_provider_kind_name(request.provider_kind),
      )
      diagnostics.metrics.set(
        "ocr_provider_request_language",
        ocr_provider_language_label(request.language),
      )
      match provider(request) {
        Ok(result) =>
          if result.pages.length() == 0 {
            let error = OcrProviderError::EmptyResult(
              "OCR provider produced an empty OCR model on the current root runtime.",
            )
            diagnostics.metrics.set(
              "ocr_provider_status",
              ocr_provider_status_name(ocr_provider_error_status(error)),
            )
            diagnostics.warnings.push(
              image_ocr_provider_error_message(detected_format, error),
            )
            diagnostics.degraded_features.push(
              "image_ocr_provider_empty_result",
            )
            diagnostics.fallback_trace.push(
              "image explicit OCR requested -> provider boundary returned empty result",
            )
            diagnostics.pass_trace.push(
              "parse:image_ocr_parser:explicit_provider_empty_result",
            )
          } else {
            diagnostics.metrics.set("ocr_provider_status", "success")
            diagnostics.metrics.set("ocr_provider_wired", "true")
            diagnostics.metrics.set("provider_invoked", "true")
            diagnostics.metrics.set(
              "ocr_page_count",
              result.pages.length().to_string(),
            )
            diagnostics.metrics.set("ocr_provider_name", result.provider_name)
            diagnostics.metrics.set("block_count", "0")
            diagnostics.metrics.set("image_count", "0")
            diagnostics.metrics.set("asset_count", "0")
            diagnostics.pass_trace.push(
              "parse:image_ocr_parser:explicit_provider_success",
            )
          }
        Err(error) => {
          diagnostics.metrics.set("provider_invoked", "true")
          diagnostics.metrics.set(
            "ocr_provider_status",
            ocr_provider_status_name(ocr_provider_error_status(error)),
          )
          diagnostics.warnings.push(
            image_ocr_provider_error_message(detected_format, error),
          )
          diagnostics.degraded_features.push(
            "image_ocr_provider_not_configured",
          )
          diagnostics.fallback_trace.push(
            "image explicit OCR requested -> provider boundary returned fail-closed taxonomy",
          )
          diagnostics.pass_trace.push(
            "parse:image_ocr_parser:explicit_provider_boundary_fail_closed",
          )
        }
      }
    }
    @parser.OcrIntent::Disabled => {
      diagnostics.metrics.set("ocr_provider_status", "skipped_disabled")
      diagnostics.warnings.push(image_ocr_disabled_message(detected_format))
      diagnostics.degraded_features.push("image_ocr_disabled")
      diagnostics.fallback_trace.push(
        "image input detected -> OCR explicitly disabled -> fail closed scaffold",
      )
      diagnostics.pass_trace.push("parse:image_ocr_parser:disabled_fail_closed")
    }
    @parser.OcrIntent::Auto => {
      diagnostics.metrics.set("ocr_provider_status", "skipped_auto")
      diagnostics.warnings.push(
        image_requires_explicit_ocr_message(detected_format),
      )
      diagnostics.degraded_features.push("image_ocr_fail_closed")
      diagnostics.fallback_trace.push(
        "image input detected -> OCR not enabled -> fail closed scaffold",
      )
      diagnostics.pass_trace.push("parse:image_ocr_parser:fail_closed")
    }
  }
  diagnostics
}

///|
fn image_requested_mode_name(mode : @parser.ParserMode?) -> String {
  match mode {
    Some(value) => @parser.mode_name(value)
    None => "default"
  }
}

///|
fn image_input_kind_name(kind : @input.InputKind) -> String {
  match kind {
    @input.InputKind::Path => "path"
    @input.InputKind::Text => "text"
    @input.InputKind::Bytes => "bytes"
  }
}

///|
fn image_source_path(source : @input.InputSource) -> String {
  match source.path {
    Some(path) => path
    None => source.source_name
  }
}

///|
fn image_bool_string(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
}

///|
fn image_ocr_parse_result_from_provider_result(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : @parser.OcrOptions,
  result : OcrProviderResult,
) -> @parser.ParseResult {
  let blocks = image_ocr_blocks_from_pages(
    source,
    detected_format,
    result.pages,
  )
  let document = @core.document_from_blocks(blocks)
  let diagnostics = image_ocr_success_diagnostics(
    source,
    detected_format,
    options,
    result,
    blocks.length(),
  )
  let final_document = @core.document_with_diagnostics(document, diagnostics)
  @parser.parse_result_with_document_capability(
    "image_ocr_parser",
    @parser.ParserMode::LayoutTwoStage,
    final_document,
    diagnostics,
    ocr_image_parser_capability(),
  )
}

///|
fn image_ocr_blocks_from_pages(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  pages : Array[OcrPageModel],
) -> Array[@core.CoreBlock] {
  let blocks : Array[@core.CoreBlock] = []
  for page in pages {
    let page_number = page.page_index + 1
    for block in page.blocks {
      for line in block.lines {
        let text = line.text.trim().to_owned()
        if text == "" {
          continue
        }
        let source_ref = image_ocr_source_ref(
          source,
          detected_format,
          page_number,
          line.line_index,
          line.bbox,
        )
        blocks.push(
          @core.make_block(@core.BlockKind::Paragraph, text, source_ref~),
        )
      }
    }
  }
  blocks
}

///|
fn image_ocr_success_diagnostics(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : @parser.OcrOptions,
  result : OcrProviderResult,
  block_count : Int,
) -> @core.Diagnostics {
  let diagnostics = image_ocr_base_diagnostics(
    source,
    detected_format,
    options,
    Some(@parser.ParserMode::LayoutTwoStage),
  )
  diagnostics.metrics.set("ocr_provider_wired", "true")
  diagnostics.metrics.set("provider_invoked", "true")
  diagnostics.metrics.set("ocr_provider_status", "success")
  diagnostics.metrics.set("ocr_provider_name", result.provider_name)
  diagnostics.metrics.set(
    "ocr_provider_version",
    match result.provider_version {
      Some(version) => version
      None => "unknown"
    },
  )
  diagnostics.metrics.set("ocr_page_count", result.pages.length().to_string())
  diagnostics.metrics.set("block_count", block_count.to_string())
  diagnostics.metrics.set("image_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  for item in result.diagnostics {
    diagnostics.warnings.push("ocr_provider_diagnostic: " + item)
  }
  diagnostics.pass_trace.push(
    "parse:image_ocr_parser:explicit_provider_success",
  )
  diagnostics
}

///|
fn image_ocr_base_diagnostics(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : @parser.OcrOptions,
  requested_mode : @parser.ParserMode?,
) -> @core.Diagnostics {
  let diagnostics = @core.diagnostics_with_input(
    @core.diagnostics_with_parser(
      @core.empty_diagnostics(),
      Some("image_ocr_parser"),
      Some(@parser.mode_name(@parser.ParserMode::LayoutTwoStage)),
    ),
    Some(image_input_kind_name(source.kind)),
    Some(@input.detected_format_name(detected_format)),
  )
  diagnostics.metrics.set("parser_name", "image_ocr_parser")
  diagnostics.metrics.set("parser_mode", "layout_two_stage")
  diagnostics.metrics.set(
    "detected_format",
    @input.detected_format_name(detected_format),
  )
  diagnostics.metrics.set("ocr_candidate", "true")
  diagnostics.metrics.set("ocr_provider_wired", "false")
  diagnostics.metrics.set("ocr_provider_kind", "tesseract")
  diagnostics.metrics.set("ocr_intent", @parser.ocr_intent_name(options.intent))
  diagnostics.metrics.set(
    "ocr_explicit_requested",
    image_bool_string(options.intent == @parser.OcrIntent::Explicit),
  )
  diagnostics.metrics.set("provider_invoked", "false")
  diagnostics.metrics.set(
    "image_format",
    @input.detected_format_name(detected_format),
  )
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("block_count", "0")
  diagnostics.metrics.set("image_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set(
    "ocr_language",
    match options.language {
      Some(lang) => {
        let trimmed = lang.trim().to_owned()
        if trimmed == "" {
          "none"
        } else {
          trimmed
        }
      }
      None => "none"
    },
  )
  diagnostics.metrics.set(
    "requested_mode",
    image_requested_mode_name(requested_mode),
  )
  diagnostics.metrics.set(
    "effective_mode",
    match options.intent {
      @parser.OcrIntent::Explicit => "layout_two_stage"
      @parser.OcrIntent::Disabled => "fail_closed_disabled"
      @parser.OcrIntent::Auto => "fail_closed"
    },
  )
  diagnostics
}

///|
fn image_ocr_source_ref(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  page_number : Int,
  line_index : Int,
  bbox : @core.BBox?,
) -> @core.SourceRef {
  let base = @core.source_ref_with_lines(
    @core.empty_source_ref(),
    Some(image_source_path(source)),
    Some(@input.detected_format_name(detected_format)),
    Some(line_index),
    Some(line_index),
  )
  { ..base, page: Some(page_number), bbox }
}
