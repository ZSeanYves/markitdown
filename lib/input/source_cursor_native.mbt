///|
priv type NativeSourceFile

///|
#borrow(path)
extern "c" fn native_source_file_open(path : Bytes) -> NativeSourceFile = "markitdown_source_file_open"

///|
#borrow(file)
extern "c" fn native_source_file_is_null(file : NativeSourceFile) -> Bool = "markitdown_source_file_is_null"

///|
#borrow(file)
extern "c" fn native_source_file_fd(file : NativeSourceFile) -> Int32 = "markitdown_source_file_fd"

///|
#borrow(file)
extern "c" fn native_source_file_close(file : NativeSourceFile) -> Unit = "markitdown_source_file_close"

///|
async fn open_path_source_cursor(
  path : String,
) -> Result[SourceCursor, String] noraise {
  if path.contains("\u{0}") {
    return Err("input path contains a NUL character")
  }
  if validated_text_utf8_size(path) is Err(_) {
    return Err("input path has invalid UTF16 encoding")
  }
  // Hold a nonblocking, fstat-checked regular descriptor across async open.
  // Reopening its descriptor path cannot race a rename/symlink/FIFO swap of
  // the caller's original path. Content IO belongs to async/fs's worker pool.
  let descriptor = native_source_file_open(@utf8.encode(path))
  if native_source_file_is_null(descriptor) {
    return Err("open input path failed: " + path)
  }
  defer native_source_file_close(descriptor)
  let descriptor_path = "/dev/fd/" +
    native_source_file_fd(descriptor).to_string()
  let file = @async_fs.open(descriptor_path, mode=ReadOnly) catch {
    error =>
      return Err("open input path failed: " + path + ": " + error.to_string())
  }
  let retained = Ref(false)
  defer (if !retained.val { file.close() })
  let size = file.size() catch {
    error =>
      return Err("read input size failed: " + path + ": " + error.to_string())
  }
  let closed = Ref(false)
  let mutex = @async.Mutex()
  let cursor : SourceCursor = {
    size: Some(size),
    read_at: async fn(offset, length) {
      mutex.acquire()
      defer mutex.release()
      if closed.val {
        return Err("input file is closed: " + path)
      }
      let bytes = FixedArray::make(length, b'\x00')
      let count = file.read_at(bytes, position=offset) catch {
        error =>
          return Err(
            "input file read failed: " + path + ": " + error.to_string(),
          )
      }
      Ok(Bytes::from_array(bytes[:count]))
    },
    view_at: fn(_, _) { None },
    close_file: fn() {
      if !closed.val {
        closed.val = true
        file.close()
      }
    },
    is_closed: fn() { closed.val },
    failure: Ref(None),
    max_bytes: 512L * 1024L * 1024L,
  }
  retained.val = true
  Ok(cursor)
}
