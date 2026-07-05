///|
const PRODUCT_NAME : String = "markitdown-mb"

///|
const PRODUCT_VERSION : String = "0.4.2"

///|
/// Parsed CLI options normalized into the convert-layer request model.
pub struct CliOptions {
  input : String
  output : String?
  provenance_output : String?
  explicit_format : @input.DetectedFormat?
  ocr_options : @parser.OcrOptions
  audio_options : @parser.AudioOptions
  pdf_ocr_policy : @convert.PdfOcrPolicy
  fidelity_mode : @convert.FidelityMode
  convert_mode : @convert.ConvertMode
  output_mode : @convert.OutputMode
  stream_requested : Bool
  output_format : @convert.OutputFormat
  pdf_cleanup_mode : @convert.PdfCleanupMode
  pdf_table_mode : @convert.PdfTableMode
  rag_options : @rag.RagOptions
}

///|
pub(all) enum BatchTaskStatus {
  Success
  Failed
  Skipped
} derive(Eq)

///|
struct BatchTaskResult {
  input_path : String
  relative_path : String
  status : BatchTaskStatus
  detected_format : String
  convert_mode : String
  fidelity_mode : String
  output_mode : String
  output_path : String?
  selected_route : String?
  parser_mode : String?
  route_reason : String?
  warning_count : Int
  degraded_features : Array[String]
  error : String?
}

///|
fn batch_task_status_name(status : BatchTaskStatus) -> String {
  match status {
    BatchTaskStatus::Success => "success"
    BatchTaskStatus::Failed => "failed"
    BatchTaskStatus::Skipped => "skipped"
  }
}

///|
fn batch_task_result_to_json(entry : BatchTaskResult) -> Json {
  Json::object({
    "input_path": entry.input_path.to_json(),
    "relative_path": entry.relative_path.to_json(),
    "status": batch_task_status_name(entry.status).to_json(),
    "detected_format": entry.detected_format.to_json(),
    "convert_mode": entry.convert_mode.to_json(),
    "fidelity_mode": entry.fidelity_mode.to_json(),
    "output_mode": entry.output_mode.to_json(),
    "output_path": entry.output_path.to_json(),
    "selected_route": entry.selected_route.to_json(),
    "parser_mode": entry.parser_mode.to_json(),
    "route_reason": entry.route_reason.to_json(),
    "warning_count": entry.warning_count.to_json(),
    "degraded_features": entry.degraded_features.to_json(),
    "error": entry.error.to_json(),
  })
}

///|
fn cli_is_supported_format(format : @input.DetectedFormat) -> Bool {
  @formats.cli_supported_for_format(format)
}

///|
fn cli_product_name() -> String {
  PRODUCT_NAME
}

///|
fn cli_product_version() -> String {
  PRODUCT_VERSION
}

///|
fn print_cli_version() -> Unit {
  println(cli_product_name() + " " + cli_product_version())
}

///|
#cfg(not(target="native"))
fn cli_write_stderr(_message : String) -> Unit {
  println(_message)
}

///|
#cfg(target="native")
#borrow(payload)
extern "C" fn cli_write_stderr_ffi(payload : Bytes, payload_len : Int) = "markitdown_cli_write_stderr"

///|
#cfg(target="native")
fn cli_write_stderr(message : String) -> Unit {
  let payload = @utf8.encode(message)
  if payload.length() == 0 {
    return
  }
  cli_write_stderr_ffi(payload, payload.length())
}

///|
fn print_cli_help() -> Unit {
  println("Convert documents to Markdown through the main CLI.")
}

///|
fn print_cli_usage() -> Unit {
  println("Usage:")
  println(
    "  " +
    cli_product_name() +
    " [convert|normal] [--format txt|csv|tsv|srt|vtt|json|jsonl|ndjson|ipynb|xml|yaml|yml|toml|html|htm|markdown|md|eml|tex|latex|rst|adoc|asciidoc|zip|epub|odt|ods|odp|docx|xlsx|pptx|pdf|wav|mp3|m4a|png|jpg|jpeg|bmp|webp|tif|tiff] [--accurate] [--stream] [--debug|--rag] [--ocr|--no-ocr] [--ocr-lang <LANG>] [--audio-lang <LANG>] [--pdf-ocr explicit|auto-scanned] [--pdf-cleanup none|conservative] [--pdf-tables none|simple] [--provenance-out <path>] <input> [output]",
  )
  println(
    "  " +
    cli_product_name() +
    " batch [--format txt|csv|tsv|srt|vtt|json|jsonl|ndjson|ipynb|xml|yaml|yml|toml|html|htm|markdown|md|eml|tex|latex|rst|adoc|asciidoc|zip|epub|odt|ods|odp|docx|xlsx|pptx|pdf|wav|mp3|m4a|png|jpg|jpeg|bmp|webp|tif|tiff] [--accurate] [--debug|--rag] [--ocr|--no-ocr] [--ocr-lang <LANG>] [--audio-lang <LANG>] [--pdf-ocr explicit|auto-scanned] [--pdf-cleanup none|conservative] [--pdf-tables none|simple] <input> <output_dir>",
  )
  println("  " + cli_product_name() + " help | --help | -h")
  println("  " + cli_product_name() + " version | --version")
  println("")
  println(
    "Supported product formats: txt, csv, tsv, srt, vtt, json, jsonl, ndjson, ipynb, xml, yaml, yml, toml, html, htm, markdown, md, eml, tex, latex, rst, adoc, asciidoc, zip, epub, odt, ods, odp, docx, xlsx, pptx, pdf, wav, mp3, m4a, png, jpg, jpeg, bmp, webp, tif, tiff",
  )
  println("All other formats fail closed in this build.")
  println(
    "`--accurate` selects the Accurate strategy mode while preserving the selected output view.",
  )
  println(
    "`--stream` selects the Stream strategy mode and explicitly requests a format's streaming or block-streaming route when the active parser supports one.",
  )
  println("`--debug` switches the output view to debug JSON.")
  println(
    "`--rag` switches the output view to chunked retrieval JSON with the default internal chunking policy.",
  )
  println(
    "Direct image input uses local Tesseract OCR by default; `--no-ocr` disables it. PDF OCR is controlled by `--pdf-ocr explicit|auto-scanned`; `--ocr` remains a compatibility alias for `pdf --pdf-ocr explicit`. `pdf --accurate` defaults to `auto-scanned` and enters the Paddle-backed OCR route only when scanned-like probe evidence upgrades the PDF.",
  )
  println(
    "Accurate OCR and Accurate PDF OCR are still experimental. Optional Paddle runtime bridging is configured through `MARKITDOWN_PADDLE_OCR_CMD`; the official wrapper is `samples/helpers/paddle_ocr_wrapper.py`, and the adapter command receives `<image_path> [--lang <LANG>]` and must print the JSON payload expected by the current OCR provider bridge.",
  )
  println(
    "Audio transcription uses local `whisper.cpp` (`whisper-cli`, with `main` as compatibility fallback) plus local `ffmpeg` for `m4a` normalization. Use `--audio-lang <LANG>` to pass an audio language hint, and optionally set `MARKITDOWN_AUDIO_MODEL_PATH` to override the default model path.",
  )
  println(
    "PDF cleanup and simple table reconstruction are explicit opt-in product options for native-text PDFs; current defaults stay conservative and disabled.",
  )
}

///|
fn cli_unsupported_format_message(label : String) -> String {
  "unsupported format in this build: " + label
}

///|
fn cli_fail_closed_format_message(
  input_path : String,
  format : @input.DetectedFormat,
  label : String,
  ocr_options : @parser.OcrOptions,
  fidelity_mode : @convert.FidelityMode,
) -> String {
  if format == @input.DetectedFormat::Pdf {
    cli_unsupported_format_message(label) +
    "\n" +
    @fpdf.pdf_native_fail_closed_message()
  } else if @input.detected_format_is_image_candidate(format) {
    let detail = match ocr_options.intent {
      @parser.OcrIntent::Explicit =>
        cli_image_explicit_ocr_message(
          input_path, format, ocr_options, fidelity_mode,
        )
      @parser.OcrIntent::Disabled => @focr.image_ocr_disabled_message(format)
      @parser.OcrIntent::Auto =>
        @focr.image_requires_explicit_ocr_message(format)
    }
    detail
  } else {
    cli_unsupported_format_message(label)
  }
}

///|
fn cli_image_explicit_ocr_message(
  input_path : String,
  format : @input.DetectedFormat,
  ocr_options : @parser.OcrOptions,
  fidelity_mode : @convert.FidelityMode,
) -> String {
  let target = @focr.image_ocr_selection_target_for_accuracy(
    fidelity_mode == @convert.FidelityMode::Accurate,
  )
  let request = @focr.make_ocr_provider_request(
    input_path,
    @focr.resolved_ocr_provider_kind_for_target(target),
    language=ocr_options.language,
  )
  match @focr.run_ocr_provider(request) {
    Ok(result) =>
      if result.pages.length() == 0 {
        @focr.image_ocr_provider_error_message(
          format,
          @focr.OcrProviderError::EmptyResult(
            "OCR provider produced an empty OCR model on the active runtime.",
          ),
        )
      } else {
        "image OCR provider returned a non-empty OCR model"
      }
    Err(error) => @focr.image_ocr_provider_error_message(format, error)
  }
}

///|
fn cli_requested_format(opts : CliOptions) -> @input.DetectedFormat {
  match opts.explicit_format {
    Some(format) => format
    None =>
      match path_extension_label(opts.input) {
        Some(label) => @input.parse_detected_format(label)
        None => {
          let detector = @input.default_format_detector()
          let detected = (detector.detect)(@input.input_from_path(opts.input))
          detected.format
        }
      }
  }
}

///|
fn cli_requested_format_label(opts : CliOptions) -> String {
  match opts.explicit_format {
    Some(format) => @input.detected_format_name(format)
    None =>
      match path_extension_label(opts.input) {
        Some(label) => normalize_format_label(label)
        None => @input.detected_format_name(cli_requested_format(opts))
      }
  }
}

///|
fn cli_requested_format_from_input(
  input_path : String,
  explicit_format : @input.DetectedFormat?,
) -> @input.DetectedFormat {
  match explicit_format {
    Some(format) => format
    None =>
      match path_extension_label(input_path) {
        Some(label) => @input.parse_detected_format(label)
        None => {
          let detector = @input.default_format_detector()
          let detected = (detector.detect)(@input.input_from_path(input_path))
          detected.format
        }
      }
  }
}

///|
fn cli_requested_format_is_audio(format : @input.DetectedFormat) -> Bool {
  match format {
    @input.DetectedFormat::Audio(_) => true
    _ => false
  }
}

///|
fn cli_explicit_stream_warning_message(
  requested_format : @input.DetectedFormat,
) -> String {
  "warning: explicit --stream is not productized for `" +
  @input.detected_format_name(requested_format) +
  "` yet; falling back to the canonical route"
}

///|
fn cli_emit_stream_warning_if_needed(
  opts : CliOptions,
  requested_format : @input.DetectedFormat,
  execution : @convert.ConvertExecution,
) -> Unit {
  if !opts.stream_requested {
    return
  }
  if execution.provenance.route_plan.route_reason !=
    "explicit_stream_unsupported_fell_back" {
    return
  }
  cli_write_stderr(cli_explicit_stream_warning_message(requested_format) + "\n")
}

///|
fn cli_default_ocr_options(
  input_path : String,
  explicit_format : @input.DetectedFormat?,
) -> @parser.OcrOptions {
  let requested_format = cli_requested_format_from_input(
    input_path, explicit_format,
  )
  if @input.detected_format_is_image_candidate(requested_format) {
    @parser.explicit_ocr_options()
  } else {
    @parser.default_ocr_options()
  }
}

///|
fn cli_effective_ocr_options(
  input_path : String,
  explicit_format : @input.DetectedFormat?,
  pdf_ocr_policy : @convert.PdfOcrPolicy,
  fidelity_mode : @convert.FidelityMode,
  ocr_enabled : Bool,
  ocr_disabled : Bool,
  ocr_language : String?,
) -> @parser.OcrOptions {
  let requested_format = cli_requested_format_from_input(
    input_path, explicit_format,
  )
  if ocr_enabled {
    return @parser.explicit_ocr_options(language=ocr_language)
  }
  if ocr_disabled {
    return @parser.disabled_ocr_options()
  }
  if @input.detected_format_is_image_candidate(requested_format) {
    return @parser.explicit_ocr_options(language=ocr_language)
  }
  if requested_format == @input.DetectedFormat::Pdf &&
    (
      pdf_ocr_policy != @convert.PdfOcrPolicy::Disabled ||
      fidelity_mode == @convert.FidelityMode::Accurate
    ) {
    return @parser.explicit_ocr_options(language=ocr_language)
  }
  match cli_default_ocr_options(input_path, explicit_format).intent {
    @parser.OcrIntent::Explicit =>
      @parser.explicit_ocr_options(language=ocr_language)
    @parser.OcrIntent::Disabled => @parser.disabled_ocr_options()
    @parser.OcrIntent::Auto => @parser.default_ocr_options()
  }
}

///|
fn cli_effective_pdf_ocr_policy(
  input_path : String,
  explicit_format : @input.DetectedFormat?,
  ocr_enabled : Bool,
  ocr_disabled : Bool,
  fidelity_mode : @convert.FidelityMode,
  pdf_ocr_policy : @convert.PdfOcrPolicy,
) -> @convert.PdfOcrPolicy {
  let requested_format = cli_requested_format_from_input(
    input_path, explicit_format,
  )
  if requested_format != @input.DetectedFormat::Pdf {
    return @convert.default_pdf_ocr_policy()
  }
  if ocr_disabled {
    return @convert.PdfOcrPolicy::Disabled
  }
  if pdf_ocr_policy != @convert.PdfOcrPolicy::Disabled {
    return pdf_ocr_policy
  }
  if fidelity_mode == @convert.FidelityMode::Accurate {
    return @convert.PdfOcrPolicy::AutoScanned
  }
  if ocr_enabled {
    return @convert.PdfOcrPolicy::Explicit
  }
  @convert.PdfOcrPolicy::Disabled
}

///|
/// Build a normalized CLI options record after argument parsing.
pub fn make_cli_options(
  input : String,
  output : String?,
  provenance_output : String?,
  explicit_format : @input.DetectedFormat?,
  ocr_options : @parser.OcrOptions,
  pdf_ocr_policy : @convert.PdfOcrPolicy,
  fidelity_mode : @convert.FidelityMode,
  convert_mode : @convert.ConvertMode,
  output_mode : @convert.OutputMode,
  stream_requested : Bool,
  output_format : @convert.OutputFormat,
  pdf_cleanup_mode? : @convert.PdfCleanupMode = @convert.default_pdf_cleanup_mode(),
  pdf_table_mode? : @convert.PdfTableMode = @convert.default_pdf_table_mode(),
  rag_options? : @rag.RagOptions = @rag.default_rag_options(),
  audio_options? : @parser.AudioOptions = @parser.default_audio_options(),
) -> CliOptions {
  {
    input,
    output,
    provenance_output,
    explicit_format,
    ocr_options,
    audio_options,
    pdf_ocr_policy,
    fidelity_mode,
    convert_mode,
    output_mode,
    stream_requested,
    output_format,
    pdf_cleanup_mode,
    pdf_table_mode,
    rag_options,
  }
}

///|
/// Run the CLI against the default OCR provider and return the rendered output
/// payload.
pub fn run_cli(opts : CliOptions) -> Result[String, String] {
  run_cli_with_image_ocr_provider(opts, @focr.run_ocr_provider)
}

///|
/// Async CLI entry that uses the async OCR provider bridge.
pub async fn run_cli_async(opts : CliOptions) -> Result[String, String] {
  run_cli_with_async_image_ocr_provider(opts, @focr.run_ocr_provider_async)
}

///|
/// Run the CLI with an injected image OCR provider, mainly for tests and
/// adapter boundaries.
pub fn run_cli_with_image_ocr_provider(
  opts : CliOptions,
  image_ocr_provider : (@focr.OcrProviderRequest) -> Result[
    @focr.OcrProviderResult,
    @focr.OcrProviderError,
  ],
) -> Result[String, String] {
  let requested_format = cli_requested_format(opts)
  if !cli_is_supported_format(requested_format) {
    return Err(
      cli_fail_closed_format_message(
        opts.input,
        requested_format,
        cli_requested_format_label(opts),
        opts.ocr_options,
        opts.fidelity_mode,
      ),
    )
  }
  let convert_options = @convert.make_convert_options(
    opts.convert_mode,
    opts.output_format,
    opts.explicit_format,
    opts.ocr_options,
    @convert.default_resource_limits(),
    audio_options=opts.audio_options,
    fidelity_mode=opts.fidelity_mode,
    output_mode=opts.output_mode,
    stream_requested=opts.stream_requested,
    pdf_ocr_policy=opts.pdf_ocr_policy,
    pdf_cleanup_mode=opts.pdf_cleanup_mode,
    pdf_table_mode=opts.pdf_table_mode,
    rag_options=opts.rag_options,
  )
  let execution = match
    @convert.convert_input_with_provenance_and_image_ocr_provider(
      @input.input_from_path(opts.input),
      convert_options,
      image_ocr_provider,
    ) {
    Ok(value) => value
    Err(err) => return Err(err.to_string())
  }
  persist_cli_provenance(opts, execution.provenance) catch {
    err => return Err("write provenance failed: " + err.to_string())
  }
  cli_emit_stream_warning_if_needed(opts, requested_format, execution)
  cli_render_convert_result(opts, execution.result)
}

///|
/// Async CLI execution with an injected async image OCR provider.
pub async fn run_cli_with_async_image_ocr_provider(
  opts : CliOptions,
  image_ocr_provider : async (@focr.OcrProviderRequest) -> Result[
    @focr.OcrProviderResult,
    @focr.OcrProviderError,
  ],
) -> Result[String, String] {
  let requested_format = cli_requested_format(opts)
  if !cli_is_supported_format(requested_format) {
    return Err(
      cli_fail_closed_format_message(
        opts.input,
        requested_format,
        cli_requested_format_label(opts),
        opts.ocr_options,
        opts.fidelity_mode,
      ),
    )
  }
  let convert_options = @convert.make_convert_options(
    opts.convert_mode,
    opts.output_format,
    opts.explicit_format,
    opts.ocr_options,
    @convert.default_resource_limits(),
    audio_options=opts.audio_options,
    fidelity_mode=opts.fidelity_mode,
    output_mode=opts.output_mode,
    stream_requested=opts.stream_requested,
    pdf_ocr_policy=opts.pdf_ocr_policy,
    pdf_cleanup_mode=opts.pdf_cleanup_mode,
    pdf_table_mode=opts.pdf_table_mode,
    rag_options=opts.rag_options,
  )
  let allow_image_ocr = @input.detected_format_is_image_candidate(
      requested_format,
    ) &&
    opts.ocr_options.intent == @parser.OcrIntent::Explicit
  let execution = if allow_image_ocr ||
    (
      requested_format == @input.DetectedFormat::Pdf &&
      opts.pdf_ocr_policy != @convert.PdfOcrPolicy::Disabled
    ) {
    let async_result = @convert.convert_input_with_provenance_and_image_ocr_provider_async(
      @input.input_from_path(opts.input),
      convert_options,
      image_ocr_provider,
    )
    match async_result {
      Ok(value) => value
      Err(err) => return Err(err.to_string())
    }
  } else {
    let sync_result = @convert.convert_input_with_provenance(
      @input.input_from_path(opts.input),
      convert_options,
    )
    match sync_result {
      Ok(value) => value
      Err(err) => return Err(err.to_string())
    }
  }
  persist_cli_provenance(opts, execution.provenance) catch {
    err => return Err("write provenance failed: " + err.to_string())
  }
  cli_emit_stream_warning_if_needed(opts, requested_format, execution)
  cli_render_convert_result(opts, execution.result)
}

///|
fn cli_render_convert_result(
  opts : CliOptions,
  result : @convert.ConvertResult,
) -> Result[String, String] {
  let persisted_content = normalized_written_content(result.content)
  match opts.output {
    Some(path) => {
      let parent = dirname_of_path(path)
      ensure_dir_tree(parent) catch {
        e => return Err("create output dir failed: " + e.to_string())
      }
      @fs.write_string_to_file(path, persisted_content, encoding="utf8") catch {
        e => return Err("write output failed: " + e.to_string())
      }
      persist_cli_assets(opts.input, path, result.assets) catch {
        e => return Err("write asset output failed: " + e.to_string())
      }
      Ok(persisted_content)
    }
    None => Ok(result.content)
  }
}

///|
fn parse_explicit_format(
  raw : String?,
) -> Result[@input.DetectedFormat?, String] {
  match raw {
    None => Ok(None)
    Some(value) => {
      let parsed = @input.parse_detected_format(value)
      if parsed == @input.DetectedFormat::Unknown {
        Err("unsupported --format value: " + value)
      } else if !cli_is_supported_format(parsed) {
        Err(
          "unsupported --format value in this build: " +
          @input.detected_format_name(parsed),
        )
      } else {
        Ok(Some(parsed))
      }
    }
  }
}

///|
fn first_user_cli_arg(raw_cli_args : Array[String]) -> String? {
  if raw_cli_args.length() <= 1 {
    None
  } else {
    Some(raw_cli_args[1].trim().to_owned())
  }
}

///|
fn is_convert_subcommand(name : String) -> Bool {
  name == "convert" || name == "normal"
}

///|
fn is_batch_subcommand(name : String) -> Bool {
  name == "batch"
}

///|
/// Top-level CLI app entry that parses raw argv and exits with a process-style
/// status code.
pub fn run_cli_app(raw_cli_args : Array[String]) -> Int {
  let first = match first_user_cli_arg(raw_cli_args) {
    Some(value) => value.to_lower()
    None => {
      print_cli_help()
      print_cli_usage()
      return 0
    }
  }
  if first == "help" || first == "--help" || first == "-h" {
    print_cli_help()
    print_cli_usage()
    return 0
  }
  if first == "version" || first == "--version" {
    print_cli_version()
    return 0
  }
  if first == "debug" {
    return exit_cli_error(
      "unsupported subcommand in this build: debug moved to the dedicated debug package and is not exposed through the main product CLI",
      true,
    )
  }
  if first == "ocr" {
    return exit_cli_error("unsupported subcommand in this build: ocr", true)
  }
  if first == "bench" {
    return exit_cli_error(
      "unsupported subcommand: bench moved to the dedicated bench package", true,
    )
  }

  let cli_args = normalize_cli_args(raw_cli_args)
  if cli_args.length() == 0 {
    print_cli_help()
    print_cli_usage()
    return 0
  }
  if is_batch_subcommand(first) {
    return run_batch_cli_app(cli_args)
  }
  let parsed = if is_convert_subcommand(first) {
    parse_cli_options_from_index(cli_args, 1)
  } else {
    parse_cli_options(cli_args)
  }
  let opts = match parsed {
    Ok(value) => value
    Err(msg) => return exit_cli_error(msg, true)
  }
  let rendered = match run_cli(opts) {
    Ok(value) => value
    Err(msg) => return exit_cli_error(msg, false)
  }
  if opts.output is None {
    println(rendered)
  }
  0
}

///|
fn normalize_cli_args(args : Array[String]) -> Array[String] {
  let out : Array[String] = []
  if args.length() <= 1 {
    return out
  }

  for i in 1..<args.length() {
    let a = args[i].trim().to_owned()
    if a.has_prefix("--") {
      match find_first_eq(a) {
        Some(pos) => {
          out.push(a[:pos].to_owned())
          out.push(a[pos + 1:].to_owned())
          continue
        }
        None => ()
      }
    }
    out.push(a)
  }
  out
}

///|
fn dirname_of_path(path : String) -> String {
  let chars = path.to_array()
  let mut last = -1
  for i in 0..<chars.length() {
    if chars[i] == '/' || chars[i] == '\\' {
      last = i
    }
  }
  if last <= 0 {
    "."
  } else {
    path[:last].to_owned()
  }
}

///|
fn ensure_dir_tree(path : String) -> Unit raise @fs.IOError {
  let normalized = path.trim().to_owned()
  if normalized == "" || normalized == "." {
    return
  }
  if @fs.path_exists(normalized) {
    return
  }
  let parts = normalized.split("/")
  let mut current = if normalized.has_prefix("/") { "/" } else { "" }
  for raw in parts {
    let part = raw.trim().to_owned()
    if part == "" || part == "." {
      continue
    }
    if current == "" || current == "/" {
      current = if current == "/" { "/" + part } else { part }
    } else {
      current = current + "/" + part
    }
    if !@fs.path_exists(current) {
      @fs.create_dir(current)
    }
  }
}

///|
fn find_first_eq(s : String) -> Int? {
  let chars = s.to_array()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '=' {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn parse_cli_options(args : Array[String]) -> Result[CliOptions, String] {
  parse_cli_options_from_index(args, 0)
}

///|
fn parse_cli_options_from_index(
  args : Array[String],
  start_index : Int,
  allow_batch_audio_language_without_explicit_format? : Bool = false,
) -> Result[CliOptions, String] {
  let positionals : Array[String] = []
  let mut explicit_format_raw : String? = None
  let mut provenance_output : String? = None
  let mut ocr_enabled = false
  let mut ocr_disabled = false
  let mut ocr_language : String? = None
  let mut audio_language : String? = None
  let mut pdf_ocr_raw : String? = None
  let mut pdf_cleanup_raw : String? = None
  let mut pdf_tables_raw : String? = None
  let mut fidelity_mode = @convert.FidelityMode::Balanced
  let mut convert_mode = @convert.ConvertMode::Balanced
  let mut output_mode = @convert.OutputMode::Markdown
  let mut stream_requested = false
  let mut output_format = @convert.OutputFormat::Markdown
  let mut i = start_index

  while i < args.length() {
    let arg = args[i].trim().to_owned()
    if arg == "" {
      i += 1
      continue
    }
    if arg == "--format" {
      if i + 1 >= args.length() {
        return Err("missing value for --format")
      }
      let value = args[i + 1].trim().to_owned()
      if value == "" || value.has_prefix("-") {
        return Err("missing value for --format")
      }
      explicit_format_raw = Some(value)
      i += 2
      continue
    }
    if arg == "--accurate" {
      if stream_requested {
        return Err("cannot combine --stream and --accurate")
      }
      fidelity_mode = @convert.FidelityMode::Accurate
      convert_mode = @convert.derived_convert_mode(
        fidelity_mode, stream_requested,
      )
      i += 1
      continue
    }
    if arg == "--stream" {
      if fidelity_mode == @convert.FidelityMode::Accurate {
        return Err("cannot combine --stream and --accurate")
      }
      stream_requested = true
      convert_mode = @convert.derived_convert_mode(
        fidelity_mode, stream_requested,
      )
      i += 1
      continue
    }
    if arg == "--debug" {
      if output_mode == @convert.OutputMode::Rag {
        return Err("cannot combine --debug and --rag")
      }
      output_mode = @convert.OutputMode::Debug
      convert_mode = @convert.derived_convert_mode(
        fidelity_mode, stream_requested,
      )
      output_format = @convert.OutputFormat::DebugJson
      i += 1
      continue
    }
    if arg == "--rag" {
      if output_format == @convert.OutputFormat::DebugJson {
        return Err("cannot combine --debug and --rag")
      }
      output_mode = @convert.OutputMode::Rag
      convert_mode = @convert.derived_convert_mode(
        fidelity_mode, stream_requested,
      )
      output_format = @convert.OutputFormat::RagJson
      i += 1
      continue
    }
    if arg == "--ocr" {
      ocr_enabled = true
      i += 1
      continue
    }
    if arg == "--no-ocr" {
      ocr_disabled = true
      i += 1
      continue
    }
    if arg == "--ocr-lang" {
      if i + 1 >= args.length() {
        return Err("missing value for --ocr-lang")
      }
      let value = args[i + 1].trim().to_owned()
      if value == "" || value.has_prefix("-") {
        return Err("missing value for --ocr-lang")
      }
      ocr_language = Some(value)
      i += 2
      continue
    }
    if arg == "--audio-lang" {
      if i + 1 >= args.length() {
        return Err("missing value for --audio-lang")
      }
      let value = args[i + 1].trim().to_owned()
      if value == "" || value.has_prefix("-") {
        return Err("missing value for --audio-lang")
      }
      audio_language = Some(value)
      i += 2
      continue
    }
    if arg == "--pdf-ocr" {
      if i + 1 >= args.length() {
        return Err("missing value for --pdf-ocr")
      }
      let value = args[i + 1].trim().to_owned().to_lower()
      if value == "" || value.has_prefix("-") {
        return Err("missing value for --pdf-ocr")
      }
      pdf_ocr_raw = Some(value)
      i += 2
      continue
    }
    if arg == "--pdf-cleanup" {
      if i + 1 >= args.length() {
        return Err("missing value for --pdf-cleanup")
      }
      let value = args[i + 1].trim().to_owned().to_lower()
      if value == "" || value.has_prefix("-") {
        return Err("missing value for --pdf-cleanup")
      }
      pdf_cleanup_raw = Some(value)
      i += 2
      continue
    }
    if arg == "--pdf-tables" {
      if i + 1 >= args.length() {
        return Err("missing value for --pdf-tables")
      }
      let value = args[i + 1].trim().to_owned().to_lower()
      if value == "" || value.has_prefix("-") {
        return Err("missing value for --pdf-tables")
      }
      pdf_tables_raw = Some(value)
      i += 2
      continue
    }
    if arg == "--provenance-out" {
      if i + 1 >= args.length() {
        return Err("missing value for --provenance-out")
      }
      let value = args[i + 1].trim().to_owned()
      if value == "" || value.has_prefix("-") {
        return Err("missing value for --provenance-out")
      }
      provenance_output = Some(value)
      i += 2
      continue
    }
    if arg.has_prefix("-") {
      return Err("unsupported option: " + arg)
    }
    positionals.push(arg)
    i += 1
  }

  if ocr_enabled && ocr_disabled {
    return Err("cannot combine --ocr and --no-ocr")
  }
  if ocr_language is Some(_) && audio_language is Some(_) {
    return Err("cannot combine --ocr-lang and --audio-lang")
  }
  if positionals.length() < 1 || positionals.length() > 2 {
    return Err(
      "usage: [convert|normal] [--format txt|csv|tsv|srt|vtt|json|jsonl|ndjson|ipynb|xml|yaml|yml|toml|html|htm|markdown|md|eml|tex|latex|rst|adoc|asciidoc|zip|epub|odt|ods|odp|docx|xlsx|pptx|pdf|wav|mp3|m4a|png|jpg|jpeg|bmp|webp|tif|tiff] [--accurate] [--stream] [--debug|--rag] [--ocr|--no-ocr] [--ocr-lang <LANG>] [--audio-lang <LANG>] [--pdf-ocr explicit|auto-scanned] [--pdf-cleanup none|conservative] [--pdf-tables none|simple] [--provenance-out <path>] <input> [output]",
    )
  }
  let effective_positionals = positionals
  let explicit_format = match parse_explicit_format(explicit_format_raw) {
    Ok(value) => value
    Err(msg) => return Err(msg)
  }
  let requested_format = cli_requested_format_from_input(
    effective_positionals[0],
    explicit_format,
  )
  let parsed_pdf_ocr_policy = match parse_pdf_ocr_policy(pdf_ocr_raw) {
    Ok(value) => value
    Err(msg) => return Err(msg)
  }
  let effective_pdf_ocr_policy = cli_effective_pdf_ocr_policy(
    effective_positionals[0],
    explicit_format,
    ocr_enabled,
    ocr_disabled,
    fidelity_mode,
    parsed_pdf_ocr_policy,
  )
  if ocr_language is Some(_) && cli_requested_format_is_audio(requested_format) {
    return Err("--ocr-lang cannot be used with audio input; use --audio-lang")
  }
  if ocr_language is Some(_) &&
    !ocr_enabled &&
    !@input.detected_format_is_image_candidate(requested_format) &&
    !(requested_format == @input.DetectedFormat::Pdf &&
    effective_pdf_ocr_policy != @convert.PdfOcrPolicy::Disabled) {
    return Err(
      "--ocr-lang requires --ocr, direct image input, or PDF OCR via `--ocr` / `--pdf-ocr`",
    )
  }
  if audio_language is Some(_) &&
    !cli_requested_format_is_audio(requested_format) &&
    !(allow_batch_audio_language_without_explicit_format &&
    explicit_format is None) {
    return Err("--audio-lang requires audio input (`wav`, `mp3`, or `m4a`)")
  }
  let ocr_options = cli_effective_ocr_options(
    effective_positionals[0],
    explicit_format,
    effective_pdf_ocr_policy,
    fidelity_mode,
    ocr_enabled,
    ocr_disabled,
    ocr_language,
  )
  let audio_options = @parser.explicit_audio_options(language=audio_language)
  let pdf_cleanup_mode = match parse_pdf_cleanup_mode(pdf_cleanup_raw) {
    Ok(value) => value
    Err(msg) => return Err(msg)
  }
  let pdf_table_mode = match parse_pdf_table_mode(pdf_tables_raw) {
    Ok(value) => value
    Err(msg) => return Err(msg)
  }
  let output = if effective_positionals.length() >= 2 {
    Some(effective_positionals[1])
  } else {
    None
  }
  Ok(
    make_cli_options(
      effective_positionals[0],
      output,
      provenance_output,
      explicit_format,
      ocr_options,
      effective_pdf_ocr_policy,
      fidelity_mode,
      convert_mode,
      output_mode,
      stream_requested,
      output_format,
      pdf_cleanup_mode~,
      pdf_table_mode~,
      rag_options=@rag.default_rag_options(),
      audio_options~,
    ),
  )
}

///|
fn parse_pdf_ocr_policy(raw : String?) -> Result[@convert.PdfOcrPolicy, String] {
  match raw {
    None => Ok(@convert.default_pdf_ocr_policy())
    Some(value) =>
      if value == "explicit" {
        Ok(@convert.PdfOcrPolicy::Explicit)
      } else if value == "auto-scanned" {
        Ok(@convert.PdfOcrPolicy::AutoScanned)
      } else {
        Err(
          "unsupported --pdf-ocr value: " +
          value +
          " (expected explicit|auto-scanned)",
        )
      }
  }
}

///|
fn parse_pdf_cleanup_mode(
  raw : String?,
) -> Result[@convert.PdfCleanupMode, String] {
  match raw {
    None => Ok(@convert.default_pdf_cleanup_mode())
    Some(value) =>
      if value == "none" {
        Ok(@convert.PdfCleanupMode::Disabled)
      } else if value == "conservative" {
        Ok(@convert.PdfCleanupMode::Conservative)
      } else {
        Err(
          "unsupported --pdf-cleanup value: " +
          value +
          " (expected none|conservative)",
        )
      }
  }
}

///|
fn parse_pdf_table_mode(raw : String?) -> Result[@convert.PdfTableMode, String] {
  match raw {
    None => Ok(@convert.default_pdf_table_mode())
    Some(value) =>
      if value == "none" {
        Ok(@convert.PdfTableMode::Disabled)
      } else if value == "simple" {
        Ok(@convert.PdfTableMode::Simple)
      } else {
        Err(
          "unsupported --pdf-tables value: " + value + " (expected none|simple)",
        )
      }
  }
}

///|
fn exit_cli_error(msg : String, usage : Bool) -> Int {
  println("error: " + msg)
  if usage {
    print_cli_usage()
  }
  1
}

///|
fn persist_cli_provenance(
  opts : CliOptions,
  provenance : @convert.ConvertProvenance,
) -> Unit raise @fs.IOError {
  match opts.provenance_output {
    Some(path) => {
      let parent = dirname_of_path(path)
      ensure_dir_tree(parent)
      @fs.write_string_to_file(
        path,
        @convert.convert_provenance_to_json(provenance).stringify(indent=2) +
        "\n",
        encoding="utf8",
      )
    }
    None => ()
  }
}

///|
fn run_batch_cli_app(cli_args : Array[String]) -> Int {
  let parsed = parse_batch_cli_options(cli_args, 1)
  let (opts, output_dir) = match parsed {
    Ok(value) => value
    Err(msg) => return exit_cli_error(msg, true)
  }
  let input_path = opts.input
  let tasks = if fs_is_dir(input_path) {
    collect_batch_input_paths(input_path, input_path)
  } else if @fs.path_exists(input_path) {
    [input_path]
  } else {
    return exit_cli_error("batch input path not found: " + input_path, false)
  }
  ensure_dir_tree(output_dir) catch {
    err =>
      return exit_cli_error(
        "create batch output dir failed: " + err.to_string(),
        false,
      )
  }
  let results : Array[BatchTaskResult] = []
  for task_input in tasks {
    let relative_path = batch_relative_path(input_path, task_input)
    let result = run_single_batch_task(
      opts, output_dir, task_input, relative_path,
    )
    results.push(result)
  }
  let manifest_path = output_dir + "/manifest.json"
  let manifest = Json::object({
    "task_count": results.length().to_json(),
    "results": results.map(batch_task_result_to_json).to_json(),
  })
  @fs.write_string_to_file(
    manifest_path,
    manifest.stringify(indent=2) + "\n",
    encoding="utf8",
  ) catch {
    err =>
      return exit_cli_error(
        "write batch manifest failed: " + err.to_string(),
        false,
      )
  }
  0
}

///|
fn parse_batch_cli_options(
  args : Array[String],
  start_index : Int,
) -> Result[(CliOptions, String), String] {
  let parsed = parse_cli_options_from_index(
    args,
    start_index,
    allow_batch_audio_language_without_explicit_format=true,
  )
  let opts = match parsed {
    Ok(value) => value
    Err(msg) => return Err(msg)
  }
  if opts.audio_options.language is Some(_) &&
    !(match opts.explicit_format {
      Some(
        @input.DetectedFormat::Audio(
          @input.AudioFormat::Wav
          | @input.AudioFormat::Mp3
          | @input.AudioFormat::M4a
        )
      ) => true
      _ => false
    }) {
    return Err("batch --audio-lang requires explicit --format wav|mp3|m4a")
  }
  if opts.output is None {
    return Err("batch requires <input> <output_dir>")
  }
  match opts.output {
    Some(output_dir) => Ok(({ ..opts, output: None }, output_dir))
    None => Err("batch requires <input> <output_dir>")
  }
}

///|
fn collect_batch_input_paths(root : String, path : String) -> Array[String] {
  ignore(root)
  if fs_is_file(path) {
    return [path]
  }
  let collected : Array[String] = []
  for name in fs_read_dir(path) {
    let child = join_dir_path(path, name)
    if fs_is_dir(child) {
      collected.append(collect_batch_input_paths(root, child)[:])
    } else if fs_is_file(child) {
      collected.push(child)
    }
  }
  collected
}

///|
fn batch_relative_path(root_input : String, path : String) -> String {
  if root_input == path {
    return basename_of_path(path)
  }
  if !fs_is_dir(root_input) {
    return basename_of_path(path)
  }
  let prefix = if root_input.has_suffix("/") {
    root_input
  } else {
    root_input + "/"
  }
  if path.has_prefix(prefix) {
    path[prefix.length():].to_owned()
  } else {
    basename_of_path(path)
  }
}

///|
fn fs_is_dir(path : String) -> Bool {
  @fs.is_dir(path) catch {
    _ => false
  }
}

///|
fn fs_is_file(path : String) -> Bool {
  @fs.is_file(path) catch {
    _ => false
  }
}

///|
fn fs_read_dir(path : String) -> Array[String] {
  @fs.read_dir(path) catch {
    _ => []
  }
}

///|
fn basename_of_path(path : String) -> String {
  let normalized = path.trim().to_owned()
  let chars = normalized.to_array()
  let mut last = -1
  for i in 0..<chars.length() {
    if chars[i] == '/' || chars[i] == '\\' {
      last = i
    }
  }
  if last < 0 {
    normalized
  } else {
    normalized[last + 1:].to_owned()
  }
}

///|
fn batch_output_suffix(output_format : @convert.OutputFormat) -> String {
  match output_format {
    @convert.OutputFormat::Markdown => ".md"
    @convert.OutputFormat::DebugJson => ".debug.json"
    @convert.OutputFormat::RagJson => ".rag.json"
  }
}

///|
fn batch_output_path(
  output_dir : String,
  relative_path : String,
  output_format : @convert.OutputFormat,
) -> String {
  join_dir_path(output_dir, relative_path) + batch_output_suffix(output_format)
}

///|
fn run_single_batch_task(
  base_opts : CliOptions,
  output_dir : String,
  task_input : String,
  relative_path : String,
) -> BatchTaskResult {
  let requested_format = cli_requested_format_from_input(
    task_input,
    base_opts.explicit_format,
  )
  let output_path = batch_output_path(
    output_dir,
    relative_path,
    base_opts.output_format,
  )
  let opts = { ..base_opts, input: task_input, output: Some(output_path) }
  let convert_options = @convert.make_convert_options(
    opts.convert_mode,
    opts.output_format,
    opts.explicit_format,
    opts.ocr_options,
    @convert.default_resource_limits(),
    audio_options=opts.audio_options,
    fidelity_mode=opts.fidelity_mode,
    output_mode=opts.output_mode,
    stream_requested=opts.stream_requested,
    pdf_ocr_policy=opts.pdf_ocr_policy,
    pdf_cleanup_mode=opts.pdf_cleanup_mode,
    pdf_table_mode=opts.pdf_table_mode,
    rag_options=opts.rag_options,
  )
  match
    @convert.convert_input_with_provenance_and_image_ocr_provider(
      @input.input_from_path(task_input),
      convert_options,
      @focr.run_ocr_provider,
    ) {
    Ok(execution) =>
      match cli_render_convert_result(opts, execution.result) {
        Ok(_) =>
          {
            input_path: task_input,
            relative_path,
            status: BatchTaskStatus::Success,
            detected_format: @input.detected_format_name(requested_format),
            convert_mode: @convert.convert_mode_name(
              execution.result.convert_mode,
            ),
            fidelity_mode: @convert.fidelity_mode_name(
              execution.result.fidelity_mode,
            ),
            output_mode: @convert.output_mode_name(execution.result.output_mode),
            output_path: Some(output_path),
            selected_route: Some(execution.provenance.route_plan.selected_route),
            parser_mode: Some(@parser.mode_name(execution.result.parser_mode)),
            route_reason: Some(execution.provenance.route_plan.route_reason),
            warning_count: execution.result.diagnostics.warnings.length(),
            degraded_features: execution.result.diagnostics.degraded_features.copy(),
            error: None,
          }
        Err(msg) =>
          {
            input_path: task_input,
            relative_path,
            status: BatchTaskStatus::Failed,
            detected_format: @input.detected_format_name(requested_format),
            convert_mode: @convert.convert_mode_name(opts.convert_mode),
            fidelity_mode: @convert.fidelity_mode_name(opts.fidelity_mode),
            output_mode: @convert.output_mode_name(opts.output_mode),
            output_path: Some(output_path),
            selected_route: Some(execution.provenance.route_plan.selected_route),
            parser_mode: Some(@parser.mode_name(execution.result.parser_mode)),
            route_reason: Some(execution.provenance.route_plan.route_reason),
            warning_count: execution.result.diagnostics.warnings.length(),
            degraded_features: execution.result.diagnostics.degraded_features.copy(),
            error: Some(msg),
          }
      }
    Err(err) =>
      {
        input_path: task_input,
        relative_path,
        status: BatchTaskStatus::Failed,
        detected_format: @input.detected_format_name(requested_format),
        convert_mode: @convert.convert_mode_name(opts.convert_mode),
        fidelity_mode: @convert.fidelity_mode_name(opts.fidelity_mode),
        output_mode: @convert.output_mode_name(opts.output_mode),
        output_path: None,
        selected_route: None,
        parser_mode: None,
        route_reason: None,
        warning_count: 0,
        degraded_features: [],
        error: Some(err.to_string()),
      }
  }
}

///|
fn path_extension_label(path : String) -> String? {
  let trimmed = path.trim().to_owned().to_lower()
  let chars = trimmed.to_array()
  let mut last_dot : Int? = None
  for i in 0..<chars.length() {
    if chars[i] == '.' {
      last_dot = Some(i)
    }
  }
  match last_dot {
    Some(index) if index + 1 < trimmed.length() => {
      let label = trimmed[index + 1:].to_owned()
      if label == "" {
        None
      } else {
        Some(label)
      }
    }
    _ => None
  }
}

///|
fn normalize_format_label(label : String) -> String {
  let parsed = @input.parse_detected_format(label)
  if parsed == @input.DetectedFormat::Unknown {
    label
  } else {
    @input.detected_format_name(parsed)
  }
}

///|
fn normalized_written_content(text : String) -> String {
  if text == "" || text.has_suffix("\n") {
    text
  } else {
    text + "\n"
  }
}

///|
fn persist_cli_assets(
  input_path : String,
  output_path : String,
  assets : Array[@core.AssetRef],
) -> Unit raise @fs.IOError {
  if assets.length() == 0 {
    return
  }
  let output_dir = dirname_of_path(output_path)
  let input_dir = dirname_of_path(input_path)
  let zip_archive = load_zip_archive_for_assets(input_path, assets)
  for asset in assets {
    let rel_path = asset.path.unwrap_or("").trim().to_owned()
    if rel_path == "" {
      continue
    }
    if persist_zip_backed_asset(zip_archive, output_dir, rel_path, asset) {
      continue
    }
    if persist_inline_asset(output_dir, rel_path, asset) {
      continue
    }
    match asset.attrs.get("source_path") {
      Some(source_rel) => {
        let src = join_dir_path(input_dir, source_rel)
        if !@fs.path_exists(src) {
          continue
        }
        let dst = join_dir_path(output_dir, rel_path)
        ensure_dir_tree(dirname_of_path(dst))
        let data = @fs.read_file_to_bytes(src) catch { _ => continue }
        @fs.write_bytes_to_file(dst, data)
      }
      None => ()
    }
  }
}

///|
fn persist_inline_asset(
  output_dir : String,
  rel_path : String,
  asset : @core.AssetRef,
) -> Bool raise @fs.IOError {
  let inline_kind = match asset.attrs.get("inline_payload_kind") {
    Some(value) => value
    None => return false
  }
  let data = match inline_kind {
    "base64" =>
      match asset.attrs.get("inline_payload") {
        Some(payload) =>
          try @base64.decode(payload, url_safe=false) |> Some catch {
            _ => None
          }
        None => None
      }
    "utf8" =>
      match asset.attrs.get("inline_payload") {
        Some(payload) => Some(@utf8.encode(payload))
        None => None
      }
    _ => None
  }
  let bytes = match data {
    Some(value) => value
    None => return false
  }
  let dst = join_dir_path(output_dir, rel_path)
  ensure_dir_tree(dirname_of_path(dst))
  @fs.write_bytes_to_file(dst, bytes)
  true
}

///|
fn load_zip_archive_for_assets(
  input_path : String,
  assets : Array[@core.AssetRef],
) -> @dzip.ZipArchive? {
  let mut needs_zip = false
  for asset in assets {
    if asset.attrs.get("zip_entry_path") is Some(_) {
      needs_zip = true
      break
    }
  }
  if !needs_zip {
    return None
  }
  let bytes = try @fs.read_file_to_bytes(input_path) |> Ok catch {
    _ => Err(())
  }
  let bytes = match bytes {
    Ok(value) => value
    Err(_) => return None
  }
  try @dzip.open_zip(bytes) |> Some catch {
    _ => None
  }
}

///|
fn persist_zip_backed_asset(
  archive : @dzip.ZipArchive?,
  output_dir : String,
  rel_path : String,
  asset : @core.AssetRef,
) -> Bool raise @fs.IOError {
  let entry_path = match asset.attrs.get("zip_entry_path") {
    Some(value) => value
    None => return false
  }
  let archive = match archive {
    Some(value) => value
    None => return false
  }
  let data = try @dzip.read_entry(archive, entry_path) |> Ok catch {
    _ => Err(())
  }
  let data = match data {
    Ok(value) => value
    Err(_) => return true
  }
  let dst = join_dir_path(output_dir, rel_path)
  ensure_dir_tree(dirname_of_path(dst))
  @fs.write_bytes_to_file(dst, data)
  true
}

///|
fn join_dir_path(dir : String, rel : String) -> String {
  if dir == "" || dir == "." {
    rel
  } else if dir.has_suffix("/") {
    dir + rel
  } else {
    dir + "/" + rel
  }
}
