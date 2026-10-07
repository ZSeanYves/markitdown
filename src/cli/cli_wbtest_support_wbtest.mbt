///|
fn run_cli_without_emitting_warnings(
  opts : CliOptions,
) -> Result[String, String] {
  cli_public_result(run_cli_impl(opts, false))
}

///|
fn test_tmp_root() -> String {
  ".tmp/tests/cli"
}

///|
fn recreate_clean_dir(path : String) -> Unit raise {
  @therm.recreate_clean_dir(path)
}

///|
fn cleanup_temp_dir(path : String) -> Unit {
  @therm.cleanup_temp_dir(path)
}

///|
fn write_utf8_text(path : String, text : String) -> Unit raise {
  @therm.write_utf8_text(path, text)
}

///|
fn read_utf8_text(path : String) -> String {
  @therm.read_utf8_text(path)
}

///|
fn cli_options(
  input : String,
  output : String?,
  explicit_format : @input.DetectedFormat?,
  output_format : @convert.OutputFormat,
  provenance_output? : String? = None,
) -> CliOptions {
  make_cli_options(
    input,
    output,
    provenance_output,
    explicit_format,
    Balanced,
    Balanced,
    @convert.output_mode_for_output_format(output_format),
    false,
    output_format,
    rag_options=@rag.default_rag_options(),
  )
}
