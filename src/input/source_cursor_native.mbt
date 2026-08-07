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
extern "c" fn native_source_file_size(file : NativeSourceFile) -> Int64 = "markitdown_source_file_size"

///|
#borrow(file)
extern "c" fn native_source_file_read_at(
  file : NativeSourceFile,
  offset : Int64,
  length : Int,
) -> Bytes = "markitdown_source_file_read_at"

///|
fn open_path_source_cursor(path : String) -> Result[SourceCursor, String] {
  let file = native_source_file_open(@utf8.encode(path))
  if native_source_file_is_null(file) {
    return Err("open input path failed: " + path)
  }
  let size = native_source_file_size(file)
  if size < 0L {
    return Err("read input size failed: " + path)
  }
  Ok({
    size: Some(size),
    read_at: fn(offset, length) {
      if offset < 0L || length < 0 {
        return Err("cursor offset and length must be non-negative")
      }
      Ok(native_source_file_read_at(file, offset, length))
    },
    view_at: fn(_offset, _length) { None },
  })
}
