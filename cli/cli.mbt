///|
/// CLI package overview:
///
/// - `cli_types.mbt` owns option/result models and product version constants.
/// - `cli_help.mbt` contains user-facing help and fail-closed messaging.
/// - `cli_parse.mbt` normalizes argv into stable product-facing options.
/// - `cli_batch.mbt` handles directory traversal, manifests, and asset writes.
/// - `cli.mbt` keeps the top-level execution path thin.

///|
/// Run the CLI against the default OCR provider and return the rendered output
/// payload.
pub fn run_cli(opts : CliOptions) -> Result[String, String] {
  run_cli_with_image_ocr_provider(opts, @focr.run_ocr_provider)
}

///|
/// Async CLI entry that uses the async OCR provider wrapper.
pub async fn run_cli_async(opts : CliOptions) -> Result[String, String] {
  run_cli_with_async_image_ocr_provider(opts, @focr.run_ocr_provider_async)
}

///|
/// Run the CLI with an injected image OCR provider, mainly for tests and
/// wrapper boundaries.
pub fn run_cli_with_image_ocr_provider(
  opts : CliOptions,
  image_ocr_provider : (@focr.OcrProviderRequest) -> Result[
    @focr.OcrProviderResult,
    @focr.OcrProviderError,
  ],
) -> Result[String, String] {
  run_cli_with_image_ocr_provider_and_pdf_rasterizer(
    opts, image_ocr_provider, @fpdf.rasterize_pdf_with_pdftoppm_default,
  )
}

///|
fn run_cli_with_image_ocr_provider_and_pdf_rasterizer(
  opts : CliOptions,
  image_ocr_provider : (@focr.OcrProviderRequest) -> Result[
    @focr.OcrProviderResult,
    @focr.OcrProviderError,
  ],
  pdf_rasterizer : (@input.InputSource) -> Result[
    (@fpdf.PdfRasterResult, String),
    @fpdf.PdfRasterizerError,
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
    pdf_cleanup_mode=opts.pdf_cleanup_mode,
    pdf_table_mode=opts.pdf_table_mode,
    rag_options=opts.rag_options,
  )
  let execution = match
    @convert.convert_input_with_provenance_and_image_ocr_provider_and_pdf_rasterizer(
      @input.input_from_path(opts.input),
      convert_options,
      image_ocr_provider,
      pdf_rasterizer,
    ) {
    Ok(value) => value
    Err(err) => return Err(err.to_string())
  }
  persist_cli_provenance(opts, execution.provenance) catch {
    err => return Err("write provenance failed: " + err.to_string())
  }
  cli_emit_accurate_warning_if_needed(opts, requested_format, execution)
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
    pdf_cleanup_mode=opts.pdf_cleanup_mode,
    pdf_table_mode=opts.pdf_table_mode,
    rag_options=opts.rag_options,
  )
  let allow_image_ocr = @input.detected_format_is_image_candidate(
      requested_format,
    ) &&
    opts.ocr_options.intent == @parser.OcrIntent::Explicit
  let allow_pdf_accurate_layout = requested_format == @input.DetectedFormat::Pdf &&
    opts.fidelity_mode == @convert.FidelityMode::Accurate
  let execution = if allow_image_ocr || allow_pdf_accurate_layout {
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
  cli_emit_accurate_warning_if_needed(opts, requested_format, execution)
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
  if first == "convert" || first == "normal" {
    return exit_cli_error(removed_cli_subcommand_message(first), true)
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
  let parsed = if is_cli_mode_word(first) {
    let mode = cli_mode_from_name(first).unwrap_or(
      @convert.ConvertMode::Balanced,
    )
    parse_cli_options_from_index(cli_args, 1, mode~)
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
