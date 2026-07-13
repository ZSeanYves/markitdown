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
    OcrProviderKind::Tesseract =>
      OcrProviderError::NotConfigured(
        "Tesseract OCR provider is not configured on this runtime.\n\n" +
        tesseract_ocr_install_hint(),
      )
    OcrProviderKind::PaddleOcr =>
      OcrProviderError::NotConfigured(paddle_ocr_not_configured_message())
  }
}

///|
fn image_ocr_provider_should_fallback(error : OcrProviderError) -> Bool {
  match ocr_provider_error_status(error) {
    OcrProviderStatus::NotConfigured => true
    OcrProviderStatus::CommandUnavailable => true
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
        OcrProviderError::EmptyResult(
          "OCR provider produced an empty OCR model on this runtime.",
        ),
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
    OcrProviderSelectionTarget::DirectImageBalanced,
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
    OcrProviderSelectionTarget::DirectImageBalanced,
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
    OcrProviderSelectionTarget::DirectImageBalanced,
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
    OcrProviderSelectionTarget::DirectImageBalanced,
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
    @parser.OcrIntent::Explicit => {
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
    @parser.OcrIntent::Explicit => {
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
  target : OcrProviderSelectionTarget,
  provider : (OcrProviderRequest) -> Result[OcrProviderResult, OcrProviderError],
) -> @core.Diagnostics {
  let diagnostics = image_ocr_base_diagnostics(
    source, detected_format, options, requested_mode, target,
  )
  match options.intent {
    @parser.OcrIntent::Explicit => {
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
            OcrProviderError::NotConfigured(_) =>
              diagnostics.dependency_diagnostics.push(
                ocr_dependency_diagnostic_for_target(target),
              )
            OcrProviderError::CommandUnavailable(_) =>
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
    @input.InputKind::Reader => "reader"
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

///|
priv struct ImageOcrSegment {
  text : String
  bbox : @core.BBox?
  line_start : Int
  line_end : Int
  confidence : Double?
  source_order : Int
  column_index : Int?
}

///|
priv struct ImageOcrBlockDraft {
  block : @core.CoreBlock
  source_order : Int
}

///|
fn image_ocr_parse_result_from_provider_result(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : @parser.OcrOptions,
  result : OcrProviderResult,
  target? : OcrProviderSelectionTarget = OcrProviderSelectionTarget::DirectImageBalanced,
) -> @parser.ParseResult {
  ocr_parse_result_from_provider_result(
    "image_ocr_parser",
    ocr_image_parser_capability(),
    source,
    detected_format,
    options,
    result,
    (source, detected_format, options, result, block_count) => {
      image_ocr_success_diagnostics(
        source,
        detected_format,
        options,
        result,
        block_count,
        target~,
      )
    },
  )
}

///|
pub fn ocr_parse_result_from_provider_result(
  parser_name : String,
  capability : @parser.ParserCapability,
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : @parser.OcrOptions,
  result : OcrProviderResult,
  diagnostics_builder : (
    @input.InputSource,
    @input.DetectedFormat,
    @parser.OcrOptions,
    OcrProviderResult,
    Int,
  ) -> @core.Diagnostics,
) -> @parser.ParseResult {
  let blocks = image_ocr_blocks_from_pages(
    source,
    detected_format,
    result.pages,
  )
  let document = @core.document_from_blocks(blocks)
  let diagnostics = diagnostics_builder(
    source,
    detected_format,
    options,
    result,
    blocks.length(),
  )
  let final_document = @core.document_with_diagnostics(document, diagnostics)
  @parser.parse_result_with_document_capability(
    parser_name,
    @parser.ParserMode::LayoutTwoStage,
    final_document,
    diagnostics,
    capability,
  )
}

///|
pub fn ocr_blocks_from_pages(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  pages : Array[OcrPageModel],
) -> Array[@core.CoreBlock] {
  let blocks : Array[@core.CoreBlock] = []
  for page in pages {
    let page_number = page.page_index + 1
    blocks.append(
      image_ocr_page_blocks_from_page(
        source, detected_format, page_number, page,
      )[:],
    )
  }
  blocks
}

///|
fn image_ocr_blocks_from_pages(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  pages : Array[OcrPageModel],
) -> Array[@core.CoreBlock] {
  ocr_blocks_from_pages(source, detected_format, pages)
}

///|
fn image_ocr_page_blocks_from_page(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  page_number : Int,
  page : OcrPageModel,
) -> Array[@core.CoreBlock] {
  ocr_page_blocks_from_page(source, detected_format, page_number, page)
}

///|
pub fn ocr_page_blocks_from_page(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  page_number : Int,
  page : OcrPageModel,
) -> Array[@core.CoreBlock] {
  let page_width = image_ocr_page_width(page)
  let segments = image_ocr_segments_with_columns(
    image_ocr_page_segments(page),
    page_width,
  )
  if segments.length() == 0 {
    return []
  }

  let unassigned : Array[ImageOcrSegment] = []
  let left_column : Array[ImageOcrSegment] = []
  let right_column : Array[ImageOcrSegment] = []
  for segment in segments {
    match segment.column_index {
      Some(0) => left_column.push(segment)
      Some(1) => right_column.push(segment)
      _ => unassigned.push(segment)
    }
  }

  let drafts : Array[ImageOcrBlockDraft] = []
  drafts.append(
    image_ocr_block_drafts_from_segment_group(
      source,
      detected_format,
      page_number,
      page_width,
      image_ocr_segments_sorted_by_source(unassigned),
    )[:],
  )
  drafts.append(
    image_ocr_block_drafts_from_segment_group(
      source,
      detected_format,
      page_number,
      page_width,
      image_ocr_segments_sorted_by_vertical_order(left_column),
    )[:],
  )
  drafts.append(
    image_ocr_block_drafts_from_segment_group(
      source,
      detected_format,
      page_number,
      page_width,
      image_ocr_segments_sorted_by_vertical_order(right_column),
    )[:],
  )
  drafts.sort_by(fn(left, right) {
    left.source_order.compare(right.source_order)
  })
  let page_blocks = drafts.map(fn(draft) { draft.block })
  image_ocr_mark_heading_candidates(page_blocks, page_width)
}

///|
fn image_ocr_page_width(page : OcrPageModel) -> Double? {
  match page.width {
    Some(width) if width > 0.0 => Some(width)
    _ => {
      let mut merged : @core.BBox? = None
      for block in page.blocks {
        merged = image_ocr_merge_bbox_pair(merged, block.bbox)
      }
      match merged {
        Some(box) => Some(box.x1)
        None => None
      }
    }
  }
}

///|
fn image_ocr_page_segments(page : OcrPageModel) -> Array[ImageOcrSegment] {
  let segments : Array[ImageOcrSegment] = []
  let page_width = image_ocr_page_width(page)
  let mut source_order = 0
  for block in page.blocks {
    for line in block.lines {
      for segment in image_ocr_split_line_segments(line, page_width) {
        segments.push({ ..segment, source_order, })
        source_order += 1
      }
    }
  }
  segments
}

///|
fn image_ocr_split_line_segments(
  line : OcrLine,
  page_width : Double?,
) -> Array[ImageOcrSegment] {
  let trimmed = line.text.trim().to_owned()
  if trimmed == "" {
    return []
  }
  if line.words.length() == 0 || !image_ocr_words_have_bboxes(line.words) {
    return [
      image_ocr_segment(trimmed, line.bbox, line.line_index, line.confidence),
    ]
  }
  let gap_threshold = image_ocr_large_gap_threshold(
    line.words,
    page_width,
    line.bbox,
  )
  let current_words : Array[OcrWord] = []
  let out : Array[ImageOcrSegment] = []
  for word in line.words {
    let next_text = word.text.trim().to_owned()
    if next_text == "" {
      continue
    }
    if current_words.length() == 0 {
      current_words.push(word)
      continue
    }
    let previous = current_words[current_words.length() - 1]
    if image_ocr_word_gap(previous, word) >= gap_threshold {
      out.push(
        image_ocr_segment_from_words(
          current_words,
          line.line_index,
          line.confidence,
        ),
      )
      current_words.clear()
    }
    current_words.push(word)
  }
  if current_words.length() > 0 {
    out.push(
      image_ocr_segment_from_words(
        current_words,
        line.line_index,
        line.confidence,
      ),
    )
  }
  if out.length() == 0 {
    [image_ocr_segment(trimmed, line.bbox, line.line_index, line.confidence)]
  } else {
    out
  }
}

///|
fn image_ocr_words_have_bboxes(words : Array[OcrWord]) -> Bool {
  words.all(fn(word) { word.bbox is Some(_) })
}

///|
fn image_ocr_segment(
  text : String,
  bbox : @core.BBox?,
  line_index : Int,
  confidence : Double?,
) -> ImageOcrSegment {
  {
    text,
    bbox,
    line_start: line_index,
    line_end: line_index,
    confidence,
    source_order: 0,
    column_index: None,
  }
}

///|
fn image_ocr_segment_from_words(
  words : Array[OcrWord],
  line_index : Int,
  fallback_confidence : Double?,
) -> ImageOcrSegment {
  let bbox = image_ocr_merge_word_bboxes(words)
  let confidence = image_ocr_average_word_confidence(words, fallback_confidence)
  image_ocr_segment(
    words.map(fn(word) { word.text.trim().to_owned() }).join(" "),
    bbox,
    line_index,
    confidence,
  )
}

///|
fn image_ocr_merge_word_bboxes(words : Array[OcrWord]) -> @core.BBox? {
  let mut merged : @core.BBox? = None
  for word in words {
    merged = image_ocr_merge_bbox_pair(merged, word.bbox)
  }
  merged
}

///|
fn image_ocr_average_word_confidence(
  words : Array[OcrWord],
  fallback : Double?,
) -> Double? {
  let mut count = 0
  let mut total = 0.0
  for word in words {
    match word.confidence {
      Some(value) => {
        count += 1
        total = total + value
      }
      None => ()
    }
  }
  if count == 0 {
    fallback
  } else {
    Some(total / count.to_double())
  }
}

///|
fn image_ocr_large_gap_threshold(
  words : Array[OcrWord],
  page_width : Double?,
  line_bbox : @core.BBox?,
) -> Double {
  let avg_gap = image_ocr_average_positive_word_gap(words)
  let line_height = image_ocr_bbox_height(line_bbox)
  let page_scaled = match page_width {
    Some(width) if width > 0.0 => width * 0.03
    _ => 0.0
  }
  let base = image_ocr_double_max(
    image_ocr_double_max(avg_gap * 3.0, line_height * 1.8),
    page_scaled,
  )
  image_ocr_double_max(base, 28.0)
}

///|
fn image_ocr_average_positive_word_gap(words : Array[OcrWord]) -> Double {
  if words.length() <= 1 {
    return 0.0
  }
  let mut count = 0
  let mut total = 0.0
  for i in 1..<words.length() {
    let gap = image_ocr_word_gap(words[i - 1], words[i])
    if gap > 0.0 {
      count += 1
      total = total + gap
    }
  }
  if count == 0 {
    0.0
  } else {
    total / count.to_double()
  }
}

///|
fn image_ocr_word_gap(left : OcrWord, right : OcrWord) -> Double {
  match (left.bbox, right.bbox) {
    (Some(lhs), Some(rhs)) =>
      if rhs.x0 > lhs.x1 {
        rhs.x0 - lhs.x1
      } else {
        0.0
      }
    _ => 0.0
  }
}

///|
fn image_ocr_segments_with_columns(
  segments : Array[ImageOcrSegment],
  page_width : Double?,
) -> Array[ImageOcrSegment] {
  let centers = image_ocr_detect_column_centers(segments, page_width)
  if centers.length() != 2 {
    return segments
  }
  let width = match page_width {
    Some(value) if value > 0.0 => value
    _ => return segments
  }
  let tolerance = image_ocr_double_max(60.0, width * 0.06)
  segments.map(fn(segment) {
    match segment.bbox {
      Some(box) => {
        let box_width = box.x1 - box.x0
        if box_width > width * 0.7 {
          return segment
        }
        let left_distance = image_ocr_abs_double(box.x0 - centers[0])
        let right_distance = image_ocr_abs_double(box.x0 - centers[1])
        if left_distance > tolerance && right_distance > tolerance {
          segment
        } else if left_distance <= right_distance {
          { ..segment, column_index: Some(0) }
        } else {
          { ..segment, column_index: Some(1) }
        }
      }
      None => segment
    }
  })
}

///|
fn image_ocr_detect_column_centers(
  segments : Array[ImageOcrSegment],
  page_width : Double?,
) -> Array[Double] {
  let width = match page_width {
    Some(value) if value > 0.0 => value
    _ => return []
  }
  let positions : Array[Double] = []
  for segment in segments {
    match segment.bbox {
      Some(box) => if box.x1 - box.x0 <= width * 0.7 { positions.push(box.x0) }
      None => ()
    }
  }
  if positions.length() < 4 {
    return []
  }
  positions.sort_by(fn(left, right) {
    if left < right {
      -1
    } else if left > right {
      1
    } else {
      0
    }
  })
  let tolerance = image_ocr_double_max(40.0, width * 0.04)
  let centers : Array[Double] = []
  let counts : Array[Int] = []
  let mut current_sum = positions[0]
  let mut current_count = 1
  let mut current_start = positions[0]
  for i in 1..<positions.length() {
    let value = positions[i]
    if value - current_start <= tolerance {
      current_sum = current_sum + value
      current_count += 1
    } else {
      centers.push(current_sum / current_count.to_double())
      counts.push(current_count)
      current_sum = value
      current_count = 1
      current_start = value
    }
  }
  centers.push(current_sum / current_count.to_double())
  counts.push(current_count)
  if centers.length() != 2 {
    return []
  }
  if counts[0] < 2 || counts[1] < 2 {
    return []
  }
  if centers[1] - centers[0] < width * 0.2 {
    return []
  }
  centers
}

///|
fn image_ocr_segments_sorted_by_source(
  segments : Array[ImageOcrSegment],
) -> Array[ImageOcrSegment] {
  let out = segments.copy()
  out.sort_by(fn(left, right) { left.source_order.compare(right.source_order) })
  out
}

///|
fn image_ocr_segments_sorted_by_vertical_order(
  segments : Array[ImageOcrSegment],
) -> Array[ImageOcrSegment] {
  let out = segments.copy()
  out.sort_by(fn(left, right) {
    let compared = image_ocr_segment_vertical_order(left, right)
    if compared != 0 {
      compared
    } else {
      left.source_order.compare(right.source_order)
    }
  })
  out
}

///|
fn image_ocr_segment_vertical_order(
  left : ImageOcrSegment,
  right : ImageOcrSegment,
) -> Int {
  let left_box = left.bbox
  let right_box = right.bbox
  match (left_box, right_box) {
    (Some(lhs), Some(rhs)) =>
      if lhs.y0 < rhs.y0 {
        -1
      } else if lhs.y0 > rhs.y0 {
        1
      } else if lhs.x0 < rhs.x0 {
        -1
      } else if lhs.x0 > rhs.x0 {
        1
      } else {
        0
      }
    (Some(_), None) => -1
    (None, Some(_)) => 1
    (None, None) => 0
  }
}

///|
fn image_ocr_block_drafts_from_segment_group(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  page_number : Int,
  page_width : Double?,
  segments : Array[ImageOcrSegment],
) -> Array[ImageOcrBlockDraft] {
  if segments.length() == 0 {
    return []
  }
  let merged : Array[ImageOcrSegment] = []
  let mut current = segments[0]
  for i in 1..<segments.length() {
    let next = segments[i]
    if image_ocr_segments_should_merge(current, next, page_width) {
      current = image_ocr_merge_segments(current, next)
    } else {
      merged.push(current)
      current = next
    }
  }
  merged.push(current)
  merged.map(fn(segment) {
    {
      block: image_ocr_block_from_segment(
        source, detected_format, page_number, segment,
      ),
      source_order: segment.source_order,
    }
  })
}

///|
fn image_ocr_segments_should_merge(
  left : ImageOcrSegment,
  right : ImageOcrSegment,
  page_width : Double?,
) -> Bool {
  if image_ocr_text_starts_new_item(right.text) {
    return false
  }
  if image_ocr_segment_is_short_display_line(left, page_width) {
    return false
  }
  match (left.bbox, right.bbox) {
    (Some(lhs), Some(rhs)) => {
      let line_height = image_ocr_double_max(rhs.y1 - rhs.y0, lhs.y1 - lhs.y0)
      let gap_limit = image_ocr_double_max(36.0, line_height * 2.0)
      let vertical_gap = if rhs.y0 > lhs.y1 { rhs.y0 - lhs.y1 } else { 0.0 }
      if vertical_gap > gap_limit {
        return false
      }
      let align_limit = image_ocr_double_max(24.0, line_height * 1.5)
      if image_ocr_abs_double(lhs.x0 - rhs.x0) > align_limit {
        return false
      }
    }
    _ => ()
  }
  if image_ocr_text_starts_continuation(right.text) {
    return true
  }
  image_ocr_text_is_body_like(left.text, left.bbox, page_width) &&
  !image_ocr_text_ends_sentence_terminal(left.text)
}

///|
fn image_ocr_merge_segments(
  left : ImageOcrSegment,
  right : ImageOcrSegment,
) -> ImageOcrSegment {
  {
    ..left,
    text: image_ocr_merge_text_segments(left.text, right.text),
    bbox: image_ocr_merge_bbox_pair(left.bbox, right.bbox),
    line_end: right.line_end,
    confidence: image_ocr_average_confidence_pair(
      left.confidence,
      right.confidence,
    ),
  }
}

///|
fn image_ocr_block_from_segment(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  page_number : Int,
  segment : ImageOcrSegment,
) -> @core.CoreBlock {
  let source_ref = image_ocr_source_ref(
    source,
    detected_format,
    page_number,
    segment.line_start,
    segment.line_end,
    segment.bbox,
  )
  match segment.column_index {
    Some(column_index) =>
      source_ref.extra.set(
        "reading_order_key",
        image_ocr_reading_order_key(column_index, segment),
      )
    None => ()
  }
  let block = @core.make_block(
    @core.BlockKind::Paragraph,
    segment.text,
    source_ref~,
  )
  @core.block_with_signals(block, image_ocr_block_signals(segment))
}

///|
fn image_ocr_block_signals(
  segment : ImageOcrSegment,
) -> Array[@core.CoreSignal] {
  let signals : Array[@core.CoreSignal] = []
  match segment.confidence {
    Some(confidence) => {
      let payload : Map[String, @core.JsonValue] = Map([])
      payload.set(
        "confidence",
        @core.JsonValue::Number(image_ocr_confidence_string(confidence)),
      )
      payload.set(
        "line_start",
        @core.JsonValue::Number(segment.line_start.to_string()),
      )
      payload.set(
        "line_end",
        @core.JsonValue::Number(segment.line_end.to_string()),
      )
      signals.push(
        @core.make_signal(
          @core.SignalType::OcrSignal,
          image_ocr_confidence_score(confidence),
          payload~,
        ),
      )
    }
    None => ()
  }
  signals
}

///|
fn image_ocr_mark_heading_candidates(
  blocks : Array[@core.CoreBlock],
  page_width : Double?,
) -> Array[@core.CoreBlock] {
  if blocks.length() < 2 {
    return blocks
  }
  let out = blocks.copy()
  let first = out[0]
  let second = out[1]
  if !image_ocr_should_mark_heading_candidate(first, second, page_width) {
    return out
  }
  let signals = first.signals.copy()
  let payload : Map[String, @core.JsonValue] = Map([])
  payload.set("level", @core.JsonValue::Number("1"))
  signals.push(
    @core.make_signal(@core.SignalType::HeadingCandidate, 90, payload~),
  )
  let promoted = @core.block_with_signals(
    @core.block_with_attr(
      @core.block_with_attr(first, "heading_candidate", "true"),
      "level",
      "1",
    ),
    signals,
  )
  out[0] = promoted
  out
}

///|
fn image_ocr_should_mark_heading_candidate(
  first : @core.CoreBlock,
  second : @core.CoreBlock,
  page_width : Double?,
) -> Bool {
  if first.kind != @core.BlockKind::Paragraph {
    return false
  }
  let text = first.text.trim().to_owned()
  if text == "" {
    return false
  }
  let word_count = image_ocr_text_word_count(text)
  if word_count == 0 || word_count > 10 || text.length() > 96 {
    return false
  }
  let next_text = second.text.trim().to_owned()
  if image_ocr_text_word_count(next_text) < 4 && next_text.length() < 24 {
    return false
  }
  if image_ocr_text_starts_continuation(next_text) {
    return false
  }
  match (page_width, first.source_ref) {
    (Some(width), Some(source_ref)) =>
      match source_ref.bbox {
        Some(box) => if box.x1 - box.x0 > width * 0.72 { false } else { true }
        None => true
      }
    _ => true
  }
}

///|
fn image_ocr_reading_order_key(
  column_index : Int,
  segment : ImageOcrSegment,
) -> String {
  let y = match segment.bbox {
    Some(box) => box.y0.to_int()
    None => segment.source_order
  }
  let x = match segment.bbox {
    Some(box) => box.x0.to_int()
    None => 0
  }
  image_ocr_left_pad_int(column_index, 2) +
  ":" +
  image_ocr_left_pad_int(y, 8) +
  ":" +
  image_ocr_left_pad_int(x, 8)
}

///|
fn image_ocr_left_pad_int(value : Int, width : Int) -> String {
  let mut out = value.to_string()
  while out.length() < width {
    out = "0" + out
  }
  out
}

///|
fn image_ocr_confidence_score(confidence : Double) -> Int {
  let score = confidence.to_int()
  if score < 0 {
    0
  } else if score > 100 {
    100
  } else {
    score
  }
}

///|
fn image_ocr_confidence_string(confidence : Double) -> String {
  image_ocr_confidence_score(confidence).to_string()
}

///|
fn image_ocr_text_word_count(text : String) -> Int {
  text.split(" ").to_array().filter(fn(part) { part.trim() != "" }).length()
}

///|
fn image_ocr_text_starts_new_item(text : String) -> Bool {
  let trimmed = text.trim_start().to_owned()
  let chars = trimmed.to_array()
  if chars.length() >= 2 &&
    image_ocr_char_is_digit(chars[0]) &&
    (chars[1] == '.' || chars[1] == ',' || chars[1] == ')') {
    return true
  }
  trimmed.has_prefix("- ") || trimmed.has_prefix("* ")
}

///|
fn image_ocr_text_starts_continuation(text : String) -> Bool {
  for ch in text.trim_start().to_owned().to_array() {
    if image_ocr_char_is_lower_ascii(ch) {
      return true
    }
    if image_ocr_char_is_upper_ascii(ch) {
      return false
    }
  }
  false
}

///|
fn image_ocr_text_ends_sentence_terminal(text : String) -> Bool {
  let chars = text.trim_end().to_owned().to_array()
  if chars.length() == 0 {
    return false
  }
  let last = chars[chars.length() - 1]
  last == '.' || last == '!' || last == '?' || last == ':' || last == ';'
}

///|
fn image_ocr_text_is_body_like(
  text : String,
  bbox : @core.BBox?,
  page_width : Double?,
) -> Bool {
  if text.length() >= 48 || image_ocr_text_word_count(text) >= 8 {
    return true
  }
  match (bbox, page_width) {
    (Some(box), Some(width)) => width > 0.0 && box.x1 - box.x0 >= width * 0.45
    _ => false
  }
}

///|
fn image_ocr_segment_is_short_display_line(
  segment : ImageOcrSegment,
  _page_width : Double?,
) -> Bool {
  let text = segment.text.trim().to_owned()
  image_ocr_text_word_count(text) <= 4 && text.length() <= 32
}

///|
fn image_ocr_char_is_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn image_ocr_char_is_lower_ascii(ch : Char) -> Bool {
  ch >= 'a' && ch <= 'z'
}

///|
fn image_ocr_char_is_upper_ascii(ch : Char) -> Bool {
  ch >= 'A' && ch <= 'Z'
}

///|
fn image_ocr_merge_text_segments(left : String, right : String) -> String {
  let lhs = left.trim_end().to_owned()
  let rhs = right.trim_start().to_owned()
  if lhs == "" {
    return rhs
  }
  if rhs == "" {
    return lhs
  }
  if lhs.has_suffix("-") {
    lhs[:lhs.length() - 1].to_owned() + rhs
  } else {
    lhs + " " + rhs
  }
}

///|
fn image_ocr_average_confidence_pair(
  left : Double?,
  right : Double?,
) -> Double? {
  match (left, right) {
    (Some(lhs), Some(rhs)) => Some((lhs + rhs) / 2.0)
    (Some(lhs), None) => Some(lhs)
    (None, Some(rhs)) => Some(rhs)
    (None, None) => None
  }
}

///|
fn image_ocr_merge_bbox_pair(
  left : @core.BBox?,
  right : @core.BBox?,
) -> @core.BBox? {
  match (left, right) {
    (Some(lhs), Some(rhs)) =>
      Some({
        x0: image_ocr_double_min(lhs.x0, rhs.x0),
        y0: image_ocr_double_min(lhs.y0, rhs.y0),
        x1: image_ocr_double_max(lhs.x1, rhs.x1),
        y1: image_ocr_double_max(lhs.y1, rhs.y1),
      })
    (Some(lhs), None) => Some(lhs)
    (None, Some(rhs)) => Some(rhs)
    (None, None) => None
  }
}

///|
fn image_ocr_bbox_height(bbox : @core.BBox?) -> Double {
  match bbox {
    Some(box) => box.y1 - box.y0
    None => 0.0
  }
}

///|
fn image_ocr_double_min(left : Double, right : Double) -> Double {
  if left < right {
    left
  } else {
    right
  }
}

///|
fn image_ocr_double_max(left : Double, right : Double) -> Double {
  if left > right {
    left
  } else {
    right
  }
}

///|
fn image_ocr_abs_double(value : Double) -> Double {
  if value < 0.0 {
    0.0 - value
  } else {
    value
  }
}

///|
fn image_ocr_success_diagnostics(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : @parser.OcrOptions,
  result : OcrProviderResult,
  block_count : Int,
  target? : OcrProviderSelectionTarget = OcrProviderSelectionTarget::DirectImageBalanced,
) -> @core.Diagnostics {
  let diagnostics = image_ocr_base_diagnostics(
    source,
    detected_format,
    options,
    Some(@parser.ParserMode::LayoutTwoStage),
    target,
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
  target : OcrProviderSelectionTarget,
) -> @core.Diagnostics {
  ocr_base_diagnostics(
    "image_ocr_parser", source, detected_format, options, requested_mode, target,
  )
}

///|
pub fn ocr_base_diagnostics(
  parser_name : String,
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  options : @parser.OcrOptions,
  requested_mode : @parser.ParserMode?,
  target : OcrProviderSelectionTarget,
) -> @core.Diagnostics {
  let diagnostics = @core.diagnostics_with_input(
    @core.diagnostics_with_parser(
      @core.empty_diagnostics(),
      Some(parser_name),
      Some(@parser.mode_name(@parser.ParserMode::LayoutTwoStage)),
    ),
    Some(image_input_kind_name(@input.input_kind(source))),
    Some(@input.detected_format_name(detected_format)),
  )
  diagnostics.metrics.set("parser_name", parser_name)
  diagnostics.metrics.set("parser_mode", "layout_two_stage")
  diagnostics.metrics.set(
    "detected_format",
    @input.detected_format_name(detected_format),
  )
  diagnostics.metrics.set("ocr_candidate", "true")
  diagnostics.metrics.set("ocr_provider_wired", "false")
  diagnostics.metrics.set(
    "ocr_provider_requested_kind",
    ocr_provider_kind_name(default_ocr_provider_kind_for_target(target)),
  )
  diagnostics.metrics.set(
    "ocr_provider_kind",
    ocr_provider_kind_name(resolved_ocr_provider_kind_for_target(target)),
  )
  diagnostics.metrics.set(
    "ocr_provider_selection_target",
    ocr_provider_selection_target_name(target),
  )
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
  image_ocr_record_provider_resolution(diagnostics, target)
  diagnostics
}

///|
pub fn image_ocr_selection_target_for_accuracy(
  accurate_enabled : Bool,
) -> OcrProviderSelectionTarget {
  if accurate_enabled {
    OcrProviderSelectionTarget::DirectImageAccurate
  } else {
    OcrProviderSelectionTarget::DirectImageBalanced
  }
}

///|
fn image_ocr_record_provider_resolution(
  diagnostics : @core.Diagnostics,
  target : OcrProviderSelectionTarget,
) -> Unit {
  ignore(diagnostics)
  ignore(target)
}

///|
pub fn ocr_source_ref(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  page_number : Int,
  line_start : Int,
  line_end : Int,
  bbox : @core.BBox?,
) -> @core.SourceRef {
  let base = @core.source_ref_with_lines(
    @core.empty_source_ref(),
    Some(image_source_path(source)),
    Some(@input.detected_format_name(detected_format)),
    Some(line_start),
    Some(line_end),
  )
  { ..base, page: Some(page_number), bbox }
}

///|
fn image_ocr_source_ref(
  source : @input.InputSource,
  detected_format : @input.DetectedFormat,
  page_number : Int,
  line_start : Int,
  line_end : Int,
  bbox : @core.BBox?,
) -> @core.SourceRef {
  ocr_source_ref(
    source, detected_format, page_number, line_start, line_end, bbox,
  )
}
