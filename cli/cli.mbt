///|
const PRODUCT_NAME : String = "markitdown-mb"

///|
const PRODUCT_VERSION : String = "0.4.2"

///|
pub struct CliOptions {
  input : String
  output : String?
  provenance_output : String?
  explicit_format : @input.DetectedFormat?
  ocr_options : @parser.OcrOptions
  fidelity_mode : @convert.FidelityMode
  convert_mode : @convert.ConvertMode
  output_mode : @convert.OutputMode
  output_format : @convert.OutputFormat
  pdf_cleanup_mode : @convert.PdfCleanupMode
  pdf_table_mode : @convert.PdfTableMode
  rag_options : @rag.RagOptions
}

///|
fn cli_is_supported_format(format : @input.DetectedFormat) -> Bool {
  match format {
    @input.DetectedFormat::Txt => true
    @input.DetectedFormat::Markdown => true
    @input.DetectedFormat::Csv => true
    @input.DetectedFormat::Tsv => true
    @input.DetectedFormat::Json => true
    @input.DetectedFormat::Jsonl => true
    @input.DetectedFormat::Ndjson => true
    @input.DetectedFormat::Ipynb => true
    @input.DetectedFormat::Xml => true
    @input.DetectedFormat::Yaml => true
    @input.DetectedFormat::Toml => true
    @input.DetectedFormat::Html => true
    @input.DetectedFormat::Zip => true
    @input.DetectedFormat::Epub => true
    @input.DetectedFormat::Pdf => true
    @input.DetectedFormat::Docx => true
    @input.DetectedFormat::Pptx => true
    @input.DetectedFormat::Xlsx => true
    @input.DetectedFormat::Image(_) => true
    _ => false
  }
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
fn print_cli_help() -> Unit {
  println("Convert documents to Markdown through the main CLI.")
}

///|
fn print_cli_usage() -> Unit {
  println("Usage:")
  println(
    "  " +
    cli_product_name() +
    " [convert|normal] [--format txt|csv|tsv|json|jsonl|ndjson|ipynb|xml|yaml|yml|toml|html|htm|markdown|md|zip|epub|docx|xlsx|pptx|pdf|png|jpg|jpeg|bmp|webp|tif|tiff] [--accurate] [--debug|--rag] [--ocr|--no-ocr] [--ocr-lang <LANG>] [--pdf-cleanup none|conservative] [--pdf-tables none|simple] [--provenance-out <path>] <input> [output]",
  )
  println("  " + cli_product_name() + " help | --help | -h")
  println("  " + cli_product_name() + " version | --version")
  println("")
  println(
    "Supported product formats: txt, csv, tsv, json, jsonl, ndjson, ipynb, xml, yaml, yml, toml, html, htm, markdown, md, zip, epub, docx, xlsx, pptx, pdf, png, jpg, jpeg, bmp, webp, tif, tiff",
  )
  println("All other formats fail closed in this build.")
  println(
    "`--accurate` upgrades fidelity while preserving the selected output mode.",
  )
  println("`--debug` emits diagnostics through the debug JSON renderer.")
  println(
    "`--rag` emits chunked retrieval JSON with the default internal chunking policy.",
  )
  println(
    "Direct image input uses local Tesseract OCR by default; `--no-ocr` disables it. `pdf --accurate` automatically enters the current OCR-only PDF path, while explicit `pdf --ocr` remains supported; both use local `pdftoppm` + Tesseract and require local installation.",
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
) -> String {
  if format == @input.DetectedFormat::Pdf {
    cli_unsupported_format_message(label) +
    "\n" +
    @fpdf.pdf_native_fail_closed_message()
  } else if @input.detected_format_is_image_candidate(format) {
    let detail = match ocr_options.intent {
      @parser.OcrIntent::Explicit =>
        cli_image_explicit_ocr_message(input_path, format, ocr_options)
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
) -> String {
  let request = @focr.make_ocr_provider_request(
    input_path,
    @focr.OcrProviderKind::Tesseract,
    language=ocr_options.language,
  )
  match @focr.run_tesseract_provider(request) {
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
    fidelity_mode == @convert.FidelityMode::Accurate {
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
pub fn make_cli_options(
  input : String,
  output : String?,
  provenance_output : String?,
  explicit_format : @input.DetectedFormat?,
  ocr_options : @parser.OcrOptions,
  fidelity_mode : @convert.FidelityMode,
  convert_mode : @convert.ConvertMode,
  output_mode : @convert.OutputMode,
  output_format : @convert.OutputFormat,
  pdf_cleanup_mode? : @convert.PdfCleanupMode = @convert.default_pdf_cleanup_mode(),
  pdf_table_mode? : @convert.PdfTableMode = @convert.default_pdf_table_mode(),
  rag_options? : @rag.RagOptions = @rag.default_rag_options(),
) -> CliOptions {
  {
    input,
    output,
    provenance_output,
    explicit_format,
    ocr_options,
    fidelity_mode,
    convert_mode,
    output_mode,
    output_format,
    pdf_cleanup_mode,
    pdf_table_mode,
    rag_options,
  }
}

///|
pub fn run_cli(opts : CliOptions) -> Result[String, String] {
  run_cli_with_image_ocr_provider(opts, @focr.run_tesseract_provider)
}

///|
pub async fn run_cli_async(opts : CliOptions) -> Result[String, String] {
  run_cli_with_async_image_ocr_provider(
    opts, @focr.run_tesseract_provider_async,
  )
}

///|
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
      ),
    )
  }
  let convert_options = @convert.make_convert_options(
    opts.convert_mode,
    opts.output_format,
    opts.explicit_format,
    opts.ocr_options,
    @convert.default_resource_limits(),
    fidelity_mode=opts.fidelity_mode,
    output_mode=opts.output_mode,
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
  cli_render_convert_result(opts, execution.result)
}

///|
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
      ),
    )
  }
  let convert_options = @convert.make_convert_options(
    opts.convert_mode,
    opts.output_format,
    opts.explicit_format,
    opts.ocr_options,
    @convert.default_resource_limits(),
    fidelity_mode=opts.fidelity_mode,
    output_mode=opts.output_mode,
    pdf_cleanup_mode=opts.pdf_cleanup_mode,
    pdf_table_mode=opts.pdf_table_mode,
    rag_options=opts.rag_options,
  )
  let allow_image_ocr = @input.detected_format_is_image_candidate(
      requested_format,
    ) &&
    opts.ocr_options.intent == @parser.OcrIntent::Explicit
  let execution = if allow_image_ocr {
    match
      @convert.convert_input_with_image_ocr_provider_async(
        @input.input_from_path(opts.input),
        convert_options,
        image_ocr_provider,
      ) {
      Ok(value) => {
        let route_plan = @convert.make_route_plan(
          cli_requested_format(opts),
          "async_unavailable",
          "async_path_does_not_serialize_provenance",
          "route_probe:async_unavailable",
          None,
        )
        let provenance = @convert.make_convert_provenance(
          route_plan,
          value.fidelity_mode,
          value.output_mode,
          value.parser_mode,
          value.diagnostics.metrics.get("ir_input_kind").unwrap_or("unknown"),
          value.diagnostics.metrics
          .get("builder_input_kind")
          .unwrap_or("unknown"),
          value.diagnostics.metrics
          .get("render_input_kind")
          .unwrap_or("unknown"),
          "async_unavailable",
        )
        @convert.make_convert_execution(value, provenance)
      }
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
  if first == "batch" {
    return exit_cli_error("unsupported subcommand in this build: batch", true)
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
) -> Result[CliOptions, String] {
  let positionals : Array[String] = []
  let mut explicit_format_raw : String? = None
  let mut provenance_output : String? = None
  let mut ocr_enabled = false
  let mut ocr_disabled = false
  let mut ocr_language : String? = None
  let mut pdf_cleanup_raw : String? = None
  let mut pdf_tables_raw : String? = None
  let mut fidelity_mode = @convert.FidelityMode::Balanced
  let mut convert_mode = @convert.ConvertMode::Balanced
  let mut output_mode = @convert.OutputMode::Markdown
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
      fidelity_mode = @convert.FidelityMode::Accurate
      convert_mode = @convert.derived_convert_mode(fidelity_mode, output_mode)
      i += 1
      continue
    }
    if arg == "--debug" {
      if output_mode == @convert.OutputMode::Rag {
        return Err("cannot combine --debug and --rag")
      }
      output_mode = @convert.OutputMode::Debug
      convert_mode = @convert.derived_convert_mode(fidelity_mode, output_mode)
      output_format = @convert.OutputFormat::DebugJson
      i += 1
      continue
    }
    if arg == "--rag" {
      if output_format == @convert.OutputFormat::DebugJson {
        return Err("cannot combine --debug and --rag")
      }
      output_mode = @convert.OutputMode::Rag
      convert_mode = @convert.derived_convert_mode(fidelity_mode, output_mode)
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
  if positionals.length() < 1 || positionals.length() > 2 {
    return Err(
      "usage: [convert|normal] [--format txt|csv|tsv|json|jsonl|ndjson|xml|yaml|yml|html|htm|markdown|md|zip|epub|docx|xlsx|pptx|pdf|png|jpg|jpeg|bmp|webp|tif|tiff] [--accurate] [--debug|--rag] [--ocr|--no-ocr] [--ocr-lang <LANG>] [--pdf-cleanup none|conservative] [--pdf-tables none|simple] [--provenance-out <path>] <input> [output]",
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
  if ocr_language is Some(_) &&
    !ocr_enabled &&
    !@input.detected_format_is_image_candidate(requested_format) &&
    !(requested_format == @input.DetectedFormat::Pdf &&
    fidelity_mode == @convert.FidelityMode::Accurate) {
    return Err(
      "--ocr-lang requires --ocr, Accurate-mode PDF input, or direct image input",
    )
  }
  let ocr_options = cli_effective_ocr_options(
    effective_positionals[0],
    explicit_format,
    fidelity_mode,
    ocr_enabled,
    ocr_disabled,
    ocr_language,
  )
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
      fidelity_mode,
      convert_mode,
      output_mode,
      output_format,
      pdf_cleanup_mode~,
      pdf_table_mode~,
      rag_options=@rag.default_rag_options(),
    ),
  )
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
