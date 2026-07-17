///|
priv type AtomicFileWriter

///|
#borrow(path)
extern "C" fn atomic_writer_open_ffi(
  path : Bytes,
  path_length : Int,
) -> AtomicFileWriter = "markitdown_atomic_writer_open"

///|
#borrow(writer)
extern "C" fn atomic_writer_status_ffi(writer : AtomicFileWriter) -> Int = "markitdown_atomic_writer_status"

///|
#borrow(writer, payload)
extern "C" fn atomic_writer_write_ffi(
  writer : AtomicFileWriter,
  payload : Bytes,
  payload_length : Int,
) -> Int = "markitdown_atomic_writer_write"

///|
#borrow(writer)
extern "C" fn atomic_writer_commit_ffi(writer : AtomicFileWriter) -> Int = "markitdown_atomic_writer_commit"

///|
#borrow(writer)
extern "C" fn atomic_writer_abort_ffi(writer : AtomicFileWriter) = "markitdown_atomic_writer_abort"

///|
fn open_atomic_file_writer(path : String) -> Result[AtomicFileWriter, String] {
  let encoded = @utf8.encode(path)
  let writer = atomic_writer_open_ffi(encoded, encoded.length())
  let status = atomic_writer_status_ffi(writer)
  if status == 0 {
    Ok(writer)
  } else {
    Err("open atomic output failed with errno " + status.to_string())
  }
}

///|
fn atomic_file_writer_write(
  writer : AtomicFileWriter,
  chunk : String,
) -> Result[Unit, String] {
  let encoded = @utf8.encode(chunk)
  let status = atomic_writer_write_ffi(writer, encoded, encoded.length())
  if status == 0 {
    Ok(())
  } else {
    Err("atomic output write failed with errno " + status.to_string())
  }
}

///|
fn atomic_file_writer_commit(writer : AtomicFileWriter) -> Result[Unit, String] {
  let status = atomic_writer_commit_ffi(writer)
  if status == 0 {
    Ok(())
  } else {
    Err("atomic output commit failed with errno " + status.to_string())
  }
}

///|
fn atomic_file_writer_abort(writer : AtomicFileWriter) -> Unit {
  atomic_writer_abort_ffi(writer)
}
