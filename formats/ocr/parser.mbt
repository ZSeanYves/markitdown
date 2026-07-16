///|
pub fn ocr_image_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    LayoutTwoStage,
    false,
    Page,
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
  " inputs on this runtime; future support requires an explicit OCR path"
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
  " inputs on this runtime." +
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
fn image_provider_not_configured_error_for_target(
  target : OcrProviderSelectionTarget,
) -> OcrProviderError {
  match resolved_ocr_provider_kind_for_target(target) {
    Tesseract =>
      NotConfigured(
        "Tesseract OCR provider is not configured on this runtime.\n\n" +
        tesseract_ocr_install_hint(),
      )
    PaddleOcr => NotConfigured(paddle_ocr_not_configured_message())
  }
}

///|
fn image_ocr_provider_should_fallback(error : OcrProviderError) -> Bool {
  match ocr_provider_error_status(error) {
    NotConfigured => true
    CommandUnavailable => true
    _ => false
  }
}

///|
fn image_ocr_provider_fallback_note(
  from_kind : OcrProviderKind,
  to_kind : OcrProviderKind,
) -> String {
  "image_ocr_provider_fallback from=" +
  ocr_provider_kind_name(from_kind) +
  " to=" +
  ocr_provider_kind_name(to_kind)
}

///|
fn image_ocr_result_with_fallback_note(
  result : OcrProviderResult,
  from_kind : OcrProviderKind,
  to_kind : OcrProviderKind,
) -> OcrProviderResult {
  let diagnostics = result.diagnostics.copy()
  diagnostics.push(image_ocr_provider_fallback_note(from_kind, to_kind))
  { ..result, diagnostics, }
}

///|
fn image_ocr_parse_success_result(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : @parser.OcrOptions,
  result : OcrProviderResult,
  target : OcrProviderSelectionTarget,
) -> Result[@parser.ParseResult, String] {
  if result.pages.length() == 0 {
    Err(
      image_ocr_provider_error_message(
        detected_format,
        EmptyResult("OCR provider produced an empty OCR model on this runtime."),
      ),
    )
  } else {
    Ok(
      image_ocr_parse_result_from_provider_result(
        source,
        detected_format,
        options,
        result,
        target~,
      ),
    )
  }
}

///|
pub fn image_ocr_disabled_message(format : @input.DetectedFormat) -> String {
  "image input conversion is not enabled for " +
  @input.detected_format_name(format) +
  " inputs on this runtime; OCR is disabled"
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
    LayoutTwoStage,
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
        image_ocr_selection_target_for_accuracy(
          context.accurate_features.features.length() > 0,
        ),
        run_ocr_provider,
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
    source,
    detected_format,
    options,
    requested_mode,
    DirectImageBalanced,
    run_ocr_provider,
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
    source,
    detected_format,
    options,
    requested_mode,
    DirectImageBalanced,
    provider,
  )
}

///|
pub fn image_ocr_parser_result_with_provider_target(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : @parser.OcrOptions,
  target : OcrProviderSelectionTarget,
  provider : (OcrProviderRequest) -> Result[OcrProviderResult, OcrProviderError],
  requested_mode? : @parser.ParserMode? = None,
) -> Result[@parser.ParseResult, String] {
  image_ocr_parser_parse(
    source, detected_format, options, requested_mode, target, provider,
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
    source,
    detected_format,
    options,
    requested_mode,
    DirectImageBalanced,
    provider,
  )
}

///|
pub async fn image_ocr_parser_result_with_async_provider_target(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : @parser.OcrOptions,
  target : OcrProviderSelectionTarget,
  provider : async (OcrProviderRequest) -> Result[
    OcrProviderResult,
    OcrProviderError,
  ],
  requested_mode? : @parser.ParserMode? = None,
) -> Result[@parser.ParseResult, String] {
  image_ocr_parser_parse_async(
    source, detected_format, options, requested_mode, target, provider,
  )
}

///|
pub fn image_ocr_fail_closed_diagnostics(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : @parser.OcrOptions,
  requested_mode? : @parser.ParserMode? = None,
) -> @core.Diagnostics {
  image_ocr_fail_closed_diagnostics_for_target(
    source,
    detected_format,
    options,
    DirectImageBalanced,
    requested_mode~,
  )
}

///|
pub fn image_ocr_fail_closed_diagnostics_for_target(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : @parser.OcrOptions,
  target : OcrProviderSelectionTarget,
  requested_mode? : @parser.ParserMode? = None,
) -> @core.Diagnostics {
  image_ocr_parser_diagnostics(
    source,
    detected_format,
    options,
    requested_mode,
    target,
    fn(_request) { Err(image_provider_not_configured_error_for_target(target)) },
  )
}

///|
fn image_ocr_parser_parse(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : @parser.OcrOptions,
  _requested_mode : @parser.ParserMode?,
  target : OcrProviderSelectionTarget,
  provider : (OcrProviderRequest) -> Result[OcrProviderResult, OcrProviderError],
) -> Result[@parser.ParseResult, String] {
  if !@input.detected_format_is_image_candidate(detected_format) {
    return Err(
      "image_ocr_parser only accepts detected image formats; got " +
      @input.detected_format_name(detected_format),
    )
  }
  match options.intent {
    Explicit => {
      let provider_input = match
        ocr_prepare_provider_input(source, detected_format) {
        Ok(value) => value
        Err(err) => return Err(err)
      }
      defer ocr_cleanup_provider_input(provider_input)
      let provider_kind = resolved_ocr_provider_kind_for_target(target)
      let request = make_ocr_provider_request(
        provider_input.path,
        provider_kind,
        language=options.language,
      )
      match provider(request) {
        Ok(result) =>
          image_ocr_parse_success_result(
            source, detected_format, options, result, target,
          )
        Err(error) =>
          match ocr_provider_fallback_for_target(target) {
            Some(fallback) if image_ocr_provider_should_fallback(error) => {
              let fallback_request = make_ocr_provider_request(
                provider_input.path,
                fallback.1,
                language=options.language,
              )
              match provider(fallback_request) {
                Ok(result) =>
                  image_ocr_parse_success_result(
                    source,
                    detected_format,
                    options,
                    image_ocr_result_with_fallback_note(
                      result,
                      fallback.0,
                      fallback.1,
                    ),
                    target,
                  )
                Err(fallback_error) =>
                  Err(
                    image_ocr_provider_error_message(
                      detected_format, fallback_error,
                    ),
                  )
              }
            }
            _ => Err(image_ocr_provider_error_message(detected_format, error))
          }
      }
    }
    Disabled => Err(image_ocr_disabled_message(detected_format))
    Auto => Err(image_requires_explicit_ocr_message(detected_format))
  }
}

///|
async fn image_ocr_parser_parse_async(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : @parser.OcrOptions,
  _requested_mode : @parser.ParserMode?,
  target : OcrProviderSelectionTarget,
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
    Explicit => {
      let provider_input = match
        ocr_prepare_provider_input(source, detected_format) {
        Ok(value) => value
        Err(err) => return Err(err)
      }
      defer ocr_cleanup_provider_input(provider_input)
      let provider_kind = resolved_ocr_provider_kind_for_target(target)
      let request = make_ocr_provider_request(
        provider_input.path,
        provider_kind,
        language=options.language,
      )
      match provider(request) {
        Ok(result) =>
          image_ocr_parse_success_result(
            source, detected_format, options, result, target,
          )
        Err(error) =>
          match ocr_provider_fallback_for_target(target) {
            Some(fallback) if image_ocr_provider_should_fallback(error) => {
              let fallback_request = make_ocr_provider_request(
                provider_input.path,
                fallback.1,
                language=options.language,
              )
              match provider(fallback_request) {
                Ok(result) =>
                  image_ocr_parse_success_result(
                    source,
                    detected_format,
                    options,
                    image_ocr_result_with_fallback_note(
                      result,
                      fallback.0,
                      fallback.1,
                    ),
                    target,
                  )
                Err(fallback_error) =>
                  Err(
                    image_ocr_provider_error_message(
                      detected_format, fallback_error,
                    ),
                  )
              }
            }
            _ => Err(image_ocr_provider_error_message(detected_format, error))
          }
      }
    }
    Disabled => Err(image_ocr_disabled_message(detected_format))
    Auto => Err(image_requires_explicit_ocr_message(detected_format))
  }
}

///|
fn image_ocr_parser_diagnostics(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : @parser.OcrOptions,
  requested_mode : @parser.ParserMode?,
  target : OcrProviderSelectionTarget,
  provider : (OcrProviderRequest) -> Result[OcrProviderResult, OcrProviderError],
) -> @core.Diagnostics {
  let diagnostics = image_ocr_base_diagnostics(
    source, detected_format, options, requested_mode, target,
  )
  match options.intent {
    Explicit => {
      let provider_kind = resolved_ocr_provider_kind_for_target(target)
      let request = make_ocr_provider_request(
        image_source_path(source),
        provider_kind,
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
      image_ocr_record_provider_resolution(diagnostics, target)
      match provider(request) {
        Ok(result) =>
          if result.pages.length() == 0 {
            let error = OcrProviderError::EmptyResult(
              "OCR provider produced an empty OCR model on this runtime.",
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
          match error {
            NotConfigured(_) =>
              diagnostics.dependency_diagnostics.push(
                ocr_dependency_diagnostic_for_target(target),
              )
            CommandUnavailable(_) =>
              diagnostics.dependency_diagnostics.push(
                ocr_dependency_diagnostic_for_target(target),
              )
            _ => ()
          }
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
    Disabled => {
      diagnostics.metrics.set("ocr_provider_status", "skipped_disabled")
      diagnostics.warnings.push(image_ocr_disabled_message(detected_format))
      diagnostics.degraded_features.push("image_ocr_disabled")
      diagnostics.fallback_trace.push(
        "image input detected -> OCR explicitly disabled -> fail closed scaffold",
      )
      diagnostics.pass_trace.push("parse:image_ocr_parser:disabled_fail_closed")
    }
    Auto => {
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
    Path => "path"
    Text => "text"
    Bytes => "bytes"
    Reader => "reader"
  }
}

///|
fn image_source_path(source : @input.InputSource) -> String {
  match @input.input_path(source) {
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
