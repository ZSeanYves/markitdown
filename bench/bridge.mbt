///|
fn normalize_cli_args(args : Array[String]) -> Array[String] {
  @clisup.normalize_cli_args(args)
}

///|
fn new_cli_parser() -> @clap.Parser {
  @clisup.new_cli_parser()
}

///|
fn exit_error(msg : String) -> Unit {
  @clisup.exit_error(msg)
}

///|
async fn cmd_convert(
  input : String,
  output : String?,
  out_dir : String?,
  max_heading : Int,
  pdf_mode : String?,
  pdf_extract_debug : Bool,
  pdf_dump_selected_raw : Bool,
  pdf_pipeline_debug : Bool,
  with_metadata : Bool,
) -> Unit {
  @clisup.cmd_convert(
    input,
    output,
    out_dir,
    max_heading,
    pdf_mode,
    pdf_extract_debug,
    pdf_dump_selected_raw,
    pdf_pipeline_debug,
    with_metadata,
    @clisup.default_ocr_policy(),
    None,
  )
}

///|
async fn convert_once(
  input : String,
  output : String?,
  out_dir : String?,
  max_heading : Int,
  pdf_mode : String?,
  pdf_extract_debug : Bool,
  pdf_dump_selected_raw : Bool,
  pdf_pipeline_debug : Bool,
  with_metadata : Bool,
) -> Result[Unit, String] {
  @clisup.convert_once(
    input,
    output,
    out_dir,
    max_heading,
    pdf_mode,
    pdf_extract_debug,
    pdf_dump_selected_raw,
    pdf_pipeline_debug,
    with_metadata,
    @clisup.default_ocr_policy(),
    None,
  )
}

///|
fn detect_input_format(path : String) -> String {
  @clisup.detect_input_format(path)
}

///|
fn ensure_dir_tree(path : String) -> Unit raise @fs.IOError {
  @clisup.ensure_dir_tree(path)
}

///|
fn join_path(dir : String, file : String) -> String {
  @clisup.join_path(dir, file)
}

///|
fn dirname_of_path(path : String) -> String {
  @clisup.dirname_of_path(path)
}

///|
fn input_stem(path : String) -> String {
  @clisup.input_stem(path)
}

///|
fn metadata_output_path(markdown_path : String) -> String {
  @clisup.metadata_output_path(markdown_path)
}

///|
fn read_document_properties(
  input : String,
  format : String,
) -> @cor.MetadataDocumentProperties? {
  @clisup.read_document_properties(input, format)
}

///|
fn now_us() -> Int64 {
  @clisup.now_us()
}
