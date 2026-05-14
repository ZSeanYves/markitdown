///|
fn normalize_cli_args(args : Array[String]) -> Array[String] {
  @clisup.normalize_cli_args(args)
}

///|
fn exit_error(msg : String) -> Unit {
  @clisup.exit_error(msg)
}

///|
fn detect_input_format(path : String) -> String {
  @clisup.detect_input_format(path)
}

///|
fn read_document_properties(
  input : String,
  format : String,
) -> @cor.MetadataDocumentProperties? {
  @clisup.read_document_properties(input, format)
}

///|
fn input_stem(path : String) -> String {
  @clisup.input_stem(path)
}
