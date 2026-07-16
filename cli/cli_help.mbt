///|
let cli_console_enabled : Ref[Bool] = Ref(true)

///|
fn cli_println(message : String) -> Unit {
  if cli_console_enabled.val {
    println(message)
  }
}

///|
fn print_cli_version() -> Unit {
  cli_println(cli_product_name() + " " + cli_product_version())
}

///|
#cfg(not(target="native"))
fn cli_write_stderr(_message : String) -> Unit {
  cli_println(_message)
}

///|
#cfg(target="native")
#borrow(payload)
extern "C" fn cli_write_stderr_ffi(payload : Bytes, payload_len : Int) = "markitdown_cli_write_stderr"

///|
#cfg(target="native")
fn cli_write_stderr(message : String) -> Unit {
  if !cli_console_enabled.val {
    return
  }
  let payload = @utf8.encode(message)
  if payload.length() == 0 {
    return
  }
  cli_write_stderr_ffi(payload, payload.length())
}

///|
fn print_cli_help() -> Unit {
  cli_println(
    "Convert documents through one main CLI with capability-group routing.",
  )
}

///|
fn cli_usage_text() -> String {
  [
    "Usage:",
    "  " +
    cli_product_name() +
    " [balance|accurate|stream] [--format <format>] [--debug|--rag] [--ocr|--no-ocr] [--ocr-lang <LANG>] [--audio-lang <LANG>] [--provenance-out <path>] <input> [output]",
    "  " +
    cli_product_name() +
    " batch [balance|accurate|stream] [--format <format>] [--debug|--rag] [--ocr|--no-ocr] [--ocr-lang <LANG>] [--audio-lang <LANG>] <input> <output_dir>",
    "  " + cli_product_name() + " help | --help | -h",
    "  " + cli_product_name() + " version | --version",
    "",
    "Capability groups: Core, Office, Containers, Media, PdfOcr.",
    "Direct image OCR, audio, and PDF accurate are optional enhancements backed by local external runtimes; formal benchmarks measure balance mode only.",
    "All other formats fail closed in this build.",
    "Omit the mode or use `balance` for the default strategy mode.",
    "`accurate` selects Accurate only for formats with a declared accurate route; unsupported mode requests fail closed.",
    "`stream` selects a declared streaming or block-streaming route; unsupported mode requests fail closed.",
    "`--debug` switches the output view to debug JSON.",
    "`--rag` switches the output view to chunked retrieval JSON with the default internal chunking policy.",
    "Direct image input uses local OCR by default; `--no-ocr` disables it. PDF input no longer supports balanced OCR. Use `accurate` for the PdfOcr layout/OCR route; `--ocr` continues to apply only to direct image input.",
    "Direct image OCR applies to top-level pure-image input. Document-referenced images remain assets and never enter OCR; an unreferenced image member of a balance-mode ZIP is treated as an independent pure-image child, uses Tesseract, and also preserves the original asset. ZIP supports balance mode only. Direct accurate image OCR prefers the official Paddle-backed wrapper at `tools/env/wrappers/paddle_ocr_wrapper.py`. Separately, PDF accurate delegates complete-page rasterization to external `pdftoppm` and recognition to the external PaddleOCR wrapper; it is not the main product OCR path. Repo-root runs prefer the managed runtime under `./env/`; custom commands and PATH remain fallback resolution sources.",
    "Audio transcription uses an optional local backend. The official wrapper is `tools/env/wrappers/audio_transcribe_wrapper.py`, which drives local `Vosk`; repo-root runs prefer the repo-managed virtualenv under `./env/`, then `MARKITDOWN_AUDIO_CMD`, then `MARKITDOWN_RUNTIME_PYTHON` plus the checked-in wrapper, and otherwise fail closed. Use `--audio-lang <LANG>` to pass a language hint, set `MARKITDOWN_AUDIO_MODEL_PATH` to the extracted Vosk model directory, and resolve `ffmpeg` from repo-managed records, then `MARKITDOWN_FFMPEG_BIN`, then `PATH` when compressed audio needs normalization.",
    "`--provenance-out` is available only on single-file runs; batch mode always writes `manifest.json` to the output directory instead.",
  ].join("\n")
}

///|
fn print_cli_usage() -> Unit {
  cli_println(cli_usage_text())
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
  if format == Pdf {
    cli_unsupported_format_message(label) +
    "\n" +
    @fpdf.pdf_native_fail_closed_message()
  } else if @input.detected_format_is_image_candidate(format) {
    let detail = match ocr_options.intent {
      Explicit =>
        cli_image_explicit_ocr_message(
          input_path, format, ocr_options, fidelity_mode,
        )
      Disabled => @focr.image_ocr_disabled_message(format)
      Auto => @focr.image_requires_explicit_ocr_message(format)
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
    fidelity_mode == Accurate,
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
          EmptyResult(
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
fn exit_cli_error(msg : String, usage : Bool) -> Int {
  cli_write_stderr("error: " + msg + "\n")
  if usage {
    cli_write_stderr(cli_usage_text() + "\n")
  }
  1
}
