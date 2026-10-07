///|
let cli_console_enabled : Ref[Bool] = Ref(true)

///|
async fn cli_println(message : String) -> Unit {
  if cli_console_enabled.val {
    @host.write_stdout(message + "\n")
  }
}

///|
async fn print_cli_version() -> Unit {
  cli_println(cli_product_name() + " " + cli_product_version())
}

///|
async fn cli_write_stderr(_message : String) -> Unit {
  if !cli_console_enabled.val {
    return
  }
  @host.write_stderr(_message)
}

///|
async fn print_cli_help() -> Unit {
  cli_println(
    "Convert documents through one main CLI with capability-group routing.",
  )
}

///|
fn cli_usage_text() -> String {
  [
    "Usage:", "  markitdown [balance|accurate|stream] [--format <format>] [--debug|--rag] [--provenance-out <path>] <input> [output]",
    "  markitdown batch [balance|accurate|stream] [--format <format>] [--debug|--rag] <input> <output_dir>",
    "  markitdown help | --help | -h | version | --version | --capabilities", "",
    "Extract text, structure, sources and document image assets. Image and audio recognition are not supported.",
    "Omit the mode or use balance for the default strategy.", "accurate preserves additional Office/ODF semantics and refines PDF text geometry.",
    "stream uses a declared streaming route; unsupported mode requests fail closed.",
    "--debug emits debug JSON; --rag emits retrieval chunks.", "Use - with --format for stdin. ZIP supports balance mode only.",
    "PDF requires an extractable text layer; image-only pages are reported as unextracted.",
    "--provenance-out is available only for single-file runs; batch writes manifest.json.",
  ].join("\n")
}

///|
async fn print_cli_usage() -> Unit {
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
  fidelity_mode : @convert.FidelityMode,
) -> String {
  ignore(input_path)
  ignore(format)
  ignore(fidelity_mode)
  cli_unsupported_format_message(label)
}

///|
async fn exit_cli_error(failure : CliFailure) -> Int {
  cli_write_stderr("error: " + failure.message + "\n")
  if failure.kind == UsageFailure {
    cli_write_stderr(cli_usage_text() + "\n")
  }
  cli_failure_exit_code(failure)
}
