///|
/// Filesystem/channel adapters for `@pdfio`.
///
/// This package exists to keep `core/pdfio` mostly pure (in-memory inputs and
/// outputs), while concentrating native-only `@fs.File` helpers under `io/`.
///
/// These helpers currently read the whole file/channel into memory.

///|
async fn read_data_to_bytes(
  load : async () -> &@io.Data,
) -> @pdfio.MutableBytes {
  let data = load()
  data.binary().to_array()
}

///|
async fn run_async_unit(load : async () -> Unit) -> Unit {
  load()
}

///|
pub async fn input_of_file(
  filename : String,
  source? : String = "file",
) -> @pdfio.Input {
  let bytes = read_data_to_bytes(() => @fs.read_file(filename))
  @pdfio.Input::of_bytes(bytes, source~)
}

///|
pub async fn input_of_channel(
  ch : @fs.File,
  source? : String = "channel",
) -> @pdfio.Input {
  let bytes = read_data_to_bytes(() => ch.read_all())
  @pdfio.Input::of_bytes(bytes, source~)
}

///|
pub fn output_of_channel(ch : @fs.File) -> @pdfio.Output {
  @pdfio.Output::of_write_at(async fn(bytes, pos) {
    ch.write_at(bytes, position=pos)
  })
}

///|
pub async fn bytes_of_input_channel(ch : @fs.File) -> @pdfio.MutableBytes {
  read_data_to_bytes(() => ch.read_all())
}

///|
pub async fn bytes_to_output_channel(
  ch : @fs.File,
  bytes : @pdfio.MutableBytes,
) -> Unit {
  let payload = Bytes::from_array(bytes)
  run_async_unit(() => ch.write(payload))
}
