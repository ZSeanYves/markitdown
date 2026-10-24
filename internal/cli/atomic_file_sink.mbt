///|
priv type AtomicFileWriter

///|
#borrow(path)
extern "C" fn atomic_writer_open_ffi(
  path : Bytes,
  path_length : Int32,
) -> AtomicFileWriter = "markitdown_atomic_writer_open"

///|
#borrow(writer)
extern "C" fn atomic_writer_status_ffi(writer : AtomicFileWriter) -> Int32 = "markitdown_atomic_writer_status"

///|
#borrow(writer, payload)
extern "C" fn atomic_writer_write_ffi(
  writer : AtomicFileWriter,
  payload : Bytes,
  payload_length : Int32,
) -> Int32 = "markitdown_atomic_writer_write"

///|
#borrow(writer)
extern "C" fn atomic_writer_commit_ffi(writer : AtomicFileWriter) -> Int32 = "markitdown_atomic_writer_commit"

///|
#borrow(writer)
extern "C" fn atomic_writer_abort_ffi(writer : AtomicFileWriter) -> Int32 = "markitdown_atomic_writer_abort"

///|
#borrow(writer)
extern "C" fn atomic_writer_error_stage_ffi(writer : AtomicFileWriter) -> Int32 = "markitdown_atomic_writer_error_stage"

///|
#borrow(writer)
extern "C" fn atomic_writer_operation_error_ffi(
  writer : AtomicFileWriter,
) -> Int32 = "markitdown_atomic_writer_operation_error"

///|
#borrow(writer)
extern "C" fn atomic_writer_close_error_ffi(writer : AtomicFileWriter) -> Int32 = "markitdown_atomic_writer_close_error"

///|
#borrow(writer)
extern "C" fn atomic_writer_remove_error_ffi(
  writer : AtomicFileWriter,
) -> Int32 = "markitdown_atomic_writer_remove_error"

///|
#borrow(writer)
extern "C" fn atomic_writer_cleanup_complete_ffi(
  writer : AtomicFileWriter,
) -> Bool = "markitdown_atomic_writer_cleanup_complete"

///|
#borrow(writer)
extern "C" fn atomic_writer_reclamation_certain_ffi(
  writer : AtomicFileWriter,
) -> Bool = "markitdown_atomic_writer_reclamation_certain"

///|
#borrow(writer)
extern "C" fn atomic_writer_last_write_count_ffi(
  writer : AtomicFileWriter,
) -> Int64 = "markitdown_atomic_writer_last_write_count"

///|
#borrow(writer)
extern "C" fn atomic_writer_invalid_encoding_ffi(
  writer : AtomicFileWriter,
) -> Int32 = "markitdown_atomic_writer_invalid_encoding"

///|
fn atomic_file_writer_cleanup_details(writer : AtomicFileWriter) -> String {
  let errors : Array[String] = []
  let close = atomic_writer_close_error_ffi(writer)
  let remove = atomic_writer_remove_error_ffi(writer)
  if close != 0 {
    errors.push("atomic cleanup close failed with errno " + close.to_string())
  }
  if remove != 0 {
    errors.push("atomic cleanup remove failed with errno " + remove.to_string())
  }
  errors.join("; ")
}

///|
fn atomic_file_writer_error_message(writer : AtomicFileWriter) -> String {
  let operation = atomic_writer_operation_error_ffi(writer)
  let cleanup = atomic_file_writer_cleanup_details(writer)
  let stage = match atomic_writer_error_stage_ffi(writer) {
    1 => "open"
    2 => "write"
    3 => "flush"
    4 => "sync"
    5 => "close"
    6 => "rename"
    8 => "encoding"
    _ => "state"
  }
  let original = if operation != 0 {
    "atomic output " +
    stage +
    " failed with errno " +
    operation.to_string() +
    (if stage == "write" {
      "; accepted UTF8 bytes=" +
      atomic_writer_last_write_count_ffi(writer).to_string()
    } else {
      ""
    })
  } else {
    ""
  }
  if original == "" {
    cleanup
  } else if cleanup == "" {
    original
  } else {
    original + "; " + cleanup
  }
}

///|
fn open_atomic_file_writer(path : String) -> Result[AtomicFileWriter, String] {
  let encoded = @utf8.encode(path)
  let writer = atomic_writer_open_ffi(encoded, encoded.length())
  let status = atomic_writer_status_ffi(writer)
  if status == 0 {
    Ok(writer)
  } else {
    // Constructor rollback is explicit and observable. The finalizer remains
    // a last attempt only; acquisition flags prevent deleting an unknown name.
    match atomic_file_writer_abort(writer) {
      Ok(_) => Err(atomic_file_writer_error_message(writer))
      Err(message) => Err(message)
    }
  }
}

///|
fn atomic_file_writer_write(
  writer : AtomicFileWriter,
  chunk : String,
) -> Result[Unit, String] {
  if @input.validated_text_utf8_size(chunk) is Err(_) {
    ignore(atomic_writer_invalid_encoding_ffi(writer))
    return Err(atomic_file_writer_error_message(writer))
  }
  let encoded = @utf8.encode(chunk)
  atomic_file_writer_write_encoded(writer, encoded)
}

///|
fn atomic_file_writer_write_encoded(
  writer : AtomicFileWriter,
  encoded : Bytes,
) -> Result[Unit, String] {
  let status = atomic_writer_write_ffi(writer, encoded, encoded.length())
  if status == 0 {
    Ok(())
  } else {
    Err(atomic_file_writer_error_message(writer))
  }
}

///|
fn atomic_file_writer_commit(writer : AtomicFileWriter) -> Result[Unit, String] {
  let status = atomic_writer_commit_ffi(writer)
  if status == 0 {
    Ok(())
  } else {
    Err(atomic_file_writer_error_message(writer))
  }
}

///|
/// Complete resource reclamation and operation success are separate facts.
/// Abort retains the first operation/cleanup error even after a retry removes
/// the file. It never retries a consumed FILE close or a retired filename.
fn atomic_file_writer_abort(writer : AtomicFileWriter) -> Result[Unit, String] {
  if atomic_writer_abort_ffi(writer) == 0 {
    Ok(())
  } else {
    Err(atomic_file_writer_error_message(writer))
  }
}
