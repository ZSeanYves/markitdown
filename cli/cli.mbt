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
  run_cli_with_image_ocr_provider_impl(opts, @focr.run_ocr_provider, false)
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
  run_cli_with_image_ocr_provider_impl(opts, image_ocr_provider, false)
}

///|
fn run_cli_with_image_ocr_provider_impl(
  opts : CliOptions,
  image_ocr_provider : (@focr.OcrProviderRequest) -> Result[
    @focr.OcrProviderResult,
    @focr.OcrProviderError,
  ],
  emit_warnings : Bool,
) -> Result[String, String] {
  run_cli_with_image_ocr_provider_and_pdf_rasterizer(
    opts,
    image_ocr_provider,
    @fpdf.rasterize_pdf_with_pdftoppm_default,
    emit_warnings~,
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
  emit_warnings? : Bool = false,
) -> Result[String, String] {
  let requested_format = cli_requested_format(opts)
  if !cli_is_supported_format(requested_format) {
    return Err(
      cli_fail_closed_format_message(
        opts.input,
        requested_format,
        cli_requested_format_label(opts),
        opts.ocr_options,
        @convert.fidelity_mode_for_convert_mode(opts.convert_mode),
      ),
    )
  }
  let convert_options = @convert.make_convert_options(
    opts.convert_mode,
    opts.output_mode,
    opts.explicit_format,
    opts.ocr_options,
    @convert.default_resource_limits(),
    audio_options=opts.audio_options,
    rag_options=opts.rag_options,
  )
  if cli_atomic_stream_output_supported(opts, requested_format) {
    return cli_convert_to_atomic_stream_file(
      opts, convert_options, emit_warnings,
    )
  }
  let execution = match
    @convert.convert_input_with_provenance_and_image_ocr_provider_and_pdf_rasterizer(
      @input.input_from_path(opts.input),
      convert_options,
      image_ocr_provider,
      pdf_rasterizer,
    ) {
    Ok(value) => value
    Err(err) => return Err(cli_convert_error_message(opts, err.to_string()))
  }
  persist_cli_provenance(opts, execution) catch {
    err => return Err("write provenance failed: " + err.to_string())
  }
  ignore(requested_format)
  if emit_warnings {
    cli_emit_conversion_warnings(execution.result)
  }
  cli_render_convert_result(opts, execution.result, emit_warnings~)
}

///|
fn cli_atomic_stream_output_supported(
  opts : CliOptions,
  format : @input.DetectedFormat,
) -> Bool {
  opts.output is Some(_) &&
  opts.provenance_output is None &&
  opts.output_mode == Markdown &&
  (match format {
    Txt | Csv | Tsv | Srt | Vtt | Json | Jsonl | Ndjson | Xml | Yaml | Toml =>
      true
    _ => false
  })
}

///|
fn atomic_sink_should_abort(wrote_any : Bool, error_count : Int) -> Bool {
  !wrote_any && error_count > 0
}

///|
fn cli_convert_to_atomic_stream_file(
  opts : CliOptions,
  convert_options : @convert.ConvertOptions,
  emit_warnings : Bool,
) -> Result[String, String] {
  let output_path = opts.output.unwrap_or("")
  ensure_dir_tree(dirname_of_path(output_path)) catch {
    error => return Err("create output dir failed: " + error.to_string())
  }
  let writer = match open_atomic_file_writer(output_path) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let wrote_any = Ref(false)
  let ends_with_newline = Ref(false)
  let sink = @convert.make_output_sink(
    fn(chunk) {
      match atomic_file_writer_write(writer, chunk) {
        Ok(_) => {
          wrote_any.val = wrote_any.val || chunk != ""
          ends_with_newline.val = chunk.has_suffix("\n")
          Ok(())
        }
        Err(message) => Err(message)
      }
    },
    fn() {
      if wrote_any.val && !ends_with_newline.val {
        atomic_file_writer_write(writer, "\n")
      } else {
        Ok(())
      }
    },
  )
  let result = match
    @convert.convert_input_to_sink_unbuffered(
      @input.input_from_path(opts.input),
      convert_options,
      sink,
    ) {
    Ok(value) => value
    Err(err) => {
      atomic_file_writer_abort(writer)
      return Err(cli_convert_error_message(opts, err.to_string()))
    }
  }
  if result.assets.length() > 0 {
    atomic_file_writer_abort(writer)
    return Err("streaming file output produced unexpected assets")
  }
  if atomic_sink_should_abort(wrote_any.val, result.diagnostics.errors.length()) {
    atomic_file_writer_abort(writer)
    return Err("conversion failed: " + result.diagnostics.errors.join("; "))
  }
  match atomic_file_writer_commit(writer) {
    Ok(_) => ()
    Err(message) => {
      atomic_file_writer_abort(writer)
      return Err(message)
    }
  }
  if emit_warnings {
    cli_emit_conversion_warnings(result)
    Ok("")
  } else {
    let persisted = @fs.read_file_to_string(output_path, encoding="utf8") catch {
      error => return Err("read streamed output failed: " + error.to_string())
    }
    Ok(persisted)
  }
}

///|
fn cli_convert_error_message(opts : CliOptions, message : String) -> String {
  match opts.explicit_format {
    Some(format) if message.contains(
        "route probe artifact missing or mismatched",
      ) =>
      "explicit format `" +
      @input.detected_format_name(format) +
      "` does not match the input structure or the input is malformed"
    _ => message
  }
}

///|
fn cli_emit_conversion_warnings(result : @convert.ConvertResult) -> Unit {
  for warning in result.diagnostics.warnings {
    cli_write_stderr("warning: " + warning + "\n")
  }
}

///|
fn cli_render_convert_result(
  opts : CliOptions,
  result : @convert.ConvertResult,
  emit_warnings? : Bool = false,
) -> Result[String, String] {
  if result.content.trim() == "" && result.diagnostics.errors.length() > 0 {
    return Err("conversion failed: " + result.diagnostics.errors.join("; "))
  }
  match opts.output {
    Some(path) => {
      match validate_cli_assets(opts.input, result.assets) {
        Err(message) => return Err("validate asset output failed: " + message)
        Ok(_) => ()
      }
      let resolved = resolve_cli_assets(
        opts.input,
        result.content,
        result.assets,
      )
      for warning in resolved.warnings {
        result.diagnostics.warnings.push(warning)
        if emit_warnings {
          cli_write_stderr("warning: " + warning + "\n")
        }
      }
      let persisted_content = normalized_written_content(resolved.content)
      let parent = dirname_of_path(path)
      ensure_dir_tree(parent) catch {
        e => return Err("create output dir failed: " + e.to_string())
      }
      @fs.write_string_to_file(path, persisted_content, encoding="utf8") catch {
        e => return Err("write output failed: " + e.to_string())
      }
      persist_cli_assets(opts.input, path, resolved.assets) catch {
        e => return Err("write asset output failed: " + e.to_string())
      }
      Ok(persisted_content)
    }
    None => {
      let resolved = resolve_cli_assets_for_stdout(
        result.content,
        result.assets,
      )
      for warning in resolved.warnings {
        result.diagnostics.warnings.push(warning)
        if emit_warnings {
          cli_write_stderr("warning: " + warning + "\n")
        }
      }
      Ok(resolved.content)
    }
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
    let mode = cli_mode_from_name(first).unwrap_or(Balanced)
    parse_cli_options_from_index(cli_args, 1, mode~)
  } else {
    parse_cli_options(cli_args)
  }
  let opts = match parsed {
    Ok(value) => value
    Err(msg) => return exit_cli_error(msg, true)
  }
  let rendered = match
    run_cli_with_image_ocr_provider_impl(opts, @focr.run_ocr_provider, true) {
    Ok(value) => value
    Err(msg) => return exit_cli_error(msg, false)
  }
  if opts.output is None {
    cli_println(rendered)
  }
  0
}
