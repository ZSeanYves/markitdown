///|
async fn cli_requested_format(opts : CliOptions) -> @input.DetectedFormat {
  match opts.explicit_format {
    Some(format) => format
    None =>
      match path_extension_label(opts.input) {
        Some(label) => @input.parse_detected_format(label)
        None => {
          let detector = @input.default_format_detector()
          let detected = (detector.detect)(cli_input_source(opts))
          detected.format
        }
      }
  }
}

///|
async fn cli_requested_format_label(opts : CliOptions) -> String {
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
          let detected = (detector.detect)(
            if input_path == "-" {
              @input.input_from_bytes(Bytes::new(0), source_name="stdin.bin")
            } else {
              @input.input_from_path(input_path)
            },
          )
          detected.format
        }
      }
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
) -> Result[CliOptions, String] {
  let positionals : Array[String] = []
  let mut explicit_format_raw : String? = None
  let mut provenance_output : String? = None
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
    if ["--ocr", "--no-ocr", "--ocr-lang", "--audio-lang"].contains(arg) {
      return Err(
        "removed option: " +
        arg +
        "; OCR and audio transcription are no longer supported",
      )
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
    if arg.has_prefix("-") && arg != "-" {
      return Err("unsupported option: " + arg)
    }
    positionals.push(arg)
    i += 1
  }

  if positionals.length() < 1 || positionals.length() > 2 {
    return Err(
      "usage: [balance|accurate|stream] [--format txt|csv|tsv|srt|vtt|json|jsonl|ndjson|ipynb|xml|yaml|yml|toml|html|htm|markdown|md|eml|msg|tex|latex|rst|adoc|asciidoc|zip|epub|odt|ods|odp|docx|xlsx|pptx|pdf] [--debug|--rag] [--provenance-out <path>] <input> [output]",
    )
  }
  let effective_positionals = positionals
  let explicit_format = match parse_explicit_format(explicit_format_raw) {
    Ok(value) => value
    Err(msg) => return Err(msg)
  }
  if effective_positionals[0] == "-" && explicit_format is None {
    return Err("stdin input requires an explicit --format")
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
      fidelity_mode,
      convert_mode,
      output_mode,
      stream_requested,
      output_format,
      rag_options=@rag.default_rag_options(),
    ),
  )
}
