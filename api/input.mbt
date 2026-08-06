///|
/// Create a filesystem-path input.
pub fn Input::from_path(path : String) -> Input {
  { source: @input.input_from_path(path), kind: Path }
}

///|
/// Create an in-memory UTF-8 text input.
pub fn Input::from_text(
  text : String,
  source_name? : String = "input.txt",
) -> Input {
  { source: @input.input_from_text(text, source_name~), kind: Text }
}

///|
/// Create an in-memory byte input.
pub fn Input::from_bytes(
  bytes : Bytes,
  source_name? : String = "input.bin",
) -> Input {
  { source: @input.input_from_bytes(bytes, source_name~), kind: Bytes }
}

///|
/// Create a random-access reader input.
pub fn Input::from_reader(
  read_at : (Int64, Int) -> Result[Bytes, String],
  size? : Int64,
  source_name? : String = "input.bin",
) -> Input {
  let reader = match size {
    Some(value) => @input.make_input_reader(read_at, size=value)
    None => @input.make_input_reader(read_at)
  }
  { source: @input.input_from_reader(reader, source_name~), kind: Reader }
}

///|
/// Return the stable storage kind without exposing the internal source model.
pub fn Input::kind(self : Input) -> InputKind {
  self.kind
}

///|
/// Return the logical source name used for format detection and diagnostics.
pub fn Input::source_name(self : Input) -> String {
  self.source.source_name
}
