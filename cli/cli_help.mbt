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
    " [balance|accurate|stream] [--format txt|csv|tsv|srt|vtt|json|jsonl|ndjson|ipynb|xml|yaml|yml|toml|html|htm|markdown|md|eml|msg|tex|latex|rst|adoc|asciidoc|zip|epub|odt|ods|odp|docx|xlsx|pptx|pdf|wav|mp3|m4a|png|jpg|jpeg|bmp|webp|tif|tiff] [--debug|--rag] [--ocr|--no-ocr] [--ocr-lang <LANG>] [--audio-lang <LANG>] [--provenance-out <path>] <input> [output]",
  )
  println(
    "  " +
    cli_product_name() +
    " batch [balance|accurate|stream] [--format txt|csv|tsv|srt|vtt|json|jsonl|ndjson|ipynb|xml|yaml|yml|toml|html|htm|markdown|md|eml|msg|tex|latex|rst|adoc|asciidoc|zip|epub|odt|ods|odp|docx|xlsx|pptx|pdf|wav|mp3|m4a|png|jpg|jpeg|bmp|webp|tif|tiff] [--debug|--rag] [--ocr|--no-ocr] [--ocr-lang <LANG>] [--audio-lang <LANG>] <input> <output_dir>",
  )
  println("  " + cli_product_name() + " help | --help | -h")
  println("  " + cli_product_name() + " version | --version")
  println("")
  println(
    "Supported product formats: txt, csv, tsv, srt, vtt, json, jsonl, ndjson, ipynb, xml, yaml, yml, toml, html, htm, markdown, md, eml, msg, tex, latex, rst, adoc, asciidoc, zip, epub, odt, ods, odp, docx, xlsx, pptx, pdf, wav, mp3, m4a, png, jpg, jpeg, bmp, webp, tif, tiff",
  )
  println("All other formats fail closed in this build.")
  println("Omit the mode or use `balance` for the default strategy mode.")
  println(
    "`accurate` selects the Accurate strategy mode while preserving the selected output view.",
  )
  println(
    "`stream` selects the Stream strategy mode and explicitly requests a format's streaming or block-streaming route when the active parser supports one.",
  )
  println("`--debug` switches the output view to debug JSON.")
  println(
    "`--rag` switches the output view to chunked retrieval JSON with the default internal chunking policy.",
  )
  println(
    "Direct image input uses local Tesseract OCR by default; `--no-ocr` disables it. PDF input no longer supports balanced OCR. Use `accurate` for the Paddle-backed PDF layout/OCR route; `--ocr` continues to apply only to direct image input.",
  )
  println(
    "Accurate OCR and Accurate PDF OCR use the official Paddle-backed wrapper at `samples/env/ocr/paddle_ocr_wrapper.py`. After `./samples/env/install_ocr_pdf_accurate_deps.sh`, repo-root runs auto-detect the repo-local virtualenv; `MARKITDOWN_PADDLE_OCR_CMD` remains the explicit override, and the wrapper command receives `<image_path> [--lang <LANG>]` and must print the JSON payload expected by the current OCR provider wrapper.",
  )
  println(
    "Audio transcription uses an optional local backend. The official wrapper is `samples/env/audio/audio_transcribe_wrapper.py`, which drives local `Vosk`; if `MARKITDOWN_AUDIO_CMD` is unset, the runtime prefers the repo-local virtualenv under `./env/` and otherwise falls back to `python3`. Use `--audio-lang <LANG>` to pass a language hint, set `MARKITDOWN_AUDIO_MODEL_PATH` to the extracted Vosk model directory, and install local `ffmpeg` when compressed audio needs normalization.",
  )
  println(
    "`--provenance-out` is available only on single-file runs; batch mode always writes `manifest.json` to the output directory instead.",
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
fn cli_explicit_stream_warning_message(
  requested_format : @input.DetectedFormat,
) -> String {
  "warning: explicit --stream is not productized for `" +
  @input.detected_format_name(requested_format) +
  "` yet; falling back to the canonical route"
}

///|
fn cli_accurate_fallback_warning_message(
  requested_format : @input.DetectedFormat,
) -> String {
  "warning: `--accurate` is not productized for `" +
  @input.detected_format_name(requested_format) +
  "` yet; falling back to balanced mode"
}

///|
fn cli_emit_accurate_warning_if_needed(
  opts : CliOptions,
  requested_format : @input.DetectedFormat,
  execution : @convert.ConvertExecution,
) -> Unit {
  ignore(requested_format)
  if opts.fidelity_mode != @convert.FidelityMode::Accurate {
    return
  }
  if execution.provenance.route_plan.route_reason !=
    "accurate_unsupported_fell_back" {
    return
  }
  cli_write_stderr(
    cli_accurate_fallback_warning_message(requested_format) + "\n",
  )
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
fn exit_cli_error(msg : String, usage : Bool) -> Int {
  println("error: " + msg)
  if usage {
    print_cli_usage()
  }
  1
}
