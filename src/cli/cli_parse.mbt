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
    Audio(_) => true
    _ => false
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
  if requested_format == Pdf && fidelity_mode == Accurate {
    return @parser.explicit_ocr_options(language=ocr_language)
  }
  match cli_default_ocr_options(input_path, explicit_format).intent {
    Explicit => @parser.explicit_ocr_options(language=ocr_language)
    Disabled => @parser.disabled_ocr_options()
    Auto => @parser.default_ocr_options()
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
      if parsed == Unknown {
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
fn cli_mode_from_name(name : String) -> @convert.ConvertMode? {
  match name {
    "balance" => Some(Balanced)
    "accurate" => Some(Accurate)
    "stream" => Some(Stream)
    _ => None
  }
}

///|
fn is_cli_mode_word(name : String) -> Bool {
  cli_mode_from_name(name) is Some(_)
}

///|
fn cli_mode_stream_requested(mode : @convert.ConvertMode) -> Bool {
  mode == Stream
}

///|
fn cli_mode_fidelity_mode(mode : @convert.ConvertMode) -> @convert.FidelityMode {
  match mode {
    Accurate => Accurate
    _ => Balanced
  }
}

///|
fn removed_cli_subcommand_message(name : String) -> String {
  "subcommand `" + name + "` was removed; use `balance` or omit the mode"
}

///|
fn removed_batch_mode_message(name : String) -> String {
  "mode `" +
  name +
  "` was removed after `batch`; use `batch balance` or omit the mode"
}

///|
fn removed_cli_flag_message(name : String) -> String {
  match name {
    "--accurate" => "`--accurate` was removed; use the `accurate` mode"
    "--stream" => "`--stream` was removed; use the `stream` mode"
    _ => "unsupported option: " + name
  }
}

///|
fn is_batch_subcommand(name : String) -> Bool {
  name == "batch"
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
  mode? : @convert.ConvertMode = Balanced,
  allow_batch_audio_language_without_explicit_format? : Bool = false,
) -> Result[CliOptions, String] {
  let positionals : Array[String] = []
  let mut explicit_format_raw : String? = None
  let mut provenance_output : String? = None
  let mut ocr_enabled = false
  let mut ocr_disabled = false
  let mut ocr_language : String? = None
  let mut audio_language : String? = None
  let fidelity_mode = cli_mode_fidelity_mode(mode)
  let convert_mode = mode
  let mut output_mode = @convert.OutputMode::Markdown
  let stream_requested = cli_mode_stream_requested(mode)
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
    if arg == "--accurate" || arg == "--stream" {
      return Err(removed_cli_flag_message(arg))
    }
    if is_cli_mode_word(arg.to_lower()) {
      return Err(
        "mode `" + arg + "` must appear before options and input paths",
      )
    }
    if arg == "convert" || arg == "normal" {
      return Err(removed_cli_subcommand_message(arg))
    }
    if arg == "--debug" {
      if output_mode == Rag {
        return Err("cannot combine --debug and --rag")
      }
      output_mode = Debug
      output_format = Debug
      i += 1
      continue
    }
    if arg == "--rag" {
      if output_format == Debug {
        return Err("cannot combine --debug and --rag")
      }
      output_mode = Rag
      output_format = Rag
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
      "usage: [balance|accurate|stream] [--format txt|csv|tsv|srt|vtt|json|jsonl|ndjson|ipynb|xml|yaml|yml|toml|html|htm|markdown|md|eml|msg|tex|latex|rst|adoc|asciidoc|zip|epub|odt|ods|odp|docx|xlsx|pptx|pdf|wav|mp3|m4a|png|jpg|jpeg|bmp|webp|tif|tiff] [--debug|--rag] [--ocr|--no-ocr] [--ocr-lang <LANG>] [--audio-lang <LANG>] [--provenance-out <path>] <input> [output]",
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
  if requested_format == Pdf && ocr_enabled && fidelity_mode != Accurate {
    return Err(
      "PDF OCR is only available through the `accurate` PDF layout route; `--ocr` continues to work for direct image input",
    )
  }
  if ocr_language is Some(_) && cli_requested_format_is_audio(requested_format) {
    return Err("--ocr-lang cannot be used with audio input; use --audio-lang")
  }
  if ocr_language is Some(_) &&
    !ocr_enabled &&
    !@input.detected_format_is_image_candidate(requested_format) &&
    !(requested_format == Pdf && fidelity_mode == Accurate) {
    return Err(
      "--ocr-lang requires --ocr, direct image input, or the `accurate` PDF layout route",
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
    fidelity_mode,
    ocr_enabled,
    ocr_disabled,
    ocr_language,
  )
  let audio_options = @parser.explicit_audio_options(language=audio_language)
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
      stream_requested,
      output_format,
      rag_options=@rag.default_rag_options(),
      audio_options~,
    ),
  )
}
