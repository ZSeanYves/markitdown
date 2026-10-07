///|
/// The Wasm CLI has no durable filesystem rename contract yet. Keep the
/// streaming sink explicit and fail closed instead of buffering or pretending
/// that output was committed.
priv type AtomicFileWriter

///|
fn open_atomic_file_writer(_path : String) -> Result[AtomicFileWriter, String] {
  Err("atomic file output is unsupported on wasm")
}

///|
fn atomic_file_writer_write(
  _writer : AtomicFileWriter,
  _chunk : String,
) -> Result[Unit, String] {
  Err("atomic file output is unsupported on wasm")
}

///|
fn atomic_file_writer_commit(
  _writer : AtomicFileWriter,
) -> Result[Unit, String] {
  Err("atomic file output is unsupported on wasm")
}

///|
fn atomic_file_writer_abort(_writer : AtomicFileWriter) -> Unit {

}
