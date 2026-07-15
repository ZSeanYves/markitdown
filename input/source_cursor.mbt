///|
/// Bounded random-access input used by streaming and seekable format readers.
pub struct SourceCursor {
  size : Int64?
  read_at : (Int64, Int) -> Result[Bytes, String]
  view_at : (Int, Int) -> BytesView?
}

///|
/// Open a cursor while rejecting known payloads above `max_bytes` before any
/// content read on native path inputs.
pub fn open_source_cursor(
  source : InputSource,
  max_bytes? : Int64 = 512L * 1024L * 1024L,
) -> Result[SourceCursor, String] {
  let cursor = open_source_cursor_unchecked(source)
  match cursor {
    Ok(value) =>
      match value.size {
        Some(size) if size > max_bytes =>
          Err(
            "input byte limit exceeded: observed=" +
            size.to_string() +
            "; limit=" +
            max_bytes.to_string(),
          )
        _ => Ok(value)
      }
    Err(message) => Err(message)
  }
}

///|
/// Inspect the size used by conversion resource checks without reading native
/// path content.
pub fn input_source_size(source : InputSource) -> Result[Int64?, String] {
  match input_size(source) {
    Some(size) => Ok(Some(size))
    None =>
      match open_source_cursor_unchecked(source) {
        Ok(cursor) => Ok(cursor.size)
        Err(message) => Err(message)
      }
  }
}

///|
fn open_source_cursor_unchecked(
  source : InputSource,
) -> Result[SourceCursor, String] {
  match source.payload {
    Path(path) => open_path_source_cursor(path)
    Text(text) => Ok(source_cursor_from_bytes(@utf8.encode(text)))
    Bytes(bytes) => Ok(source_cursor_from_bytes(bytes))
    Reader(reader) =>
      Ok({
        size: reader.size,
        read_at: reader.read_at,
        view_at: fn(_offset, _length) { None },
      })
  }
}

///|
/// Read a bounded chunk from a cursor.
pub fn source_cursor_read_at(
  cursor : SourceCursor,
  offset : Int64,
  length? : Int = 64 * 1024,
) -> Result[Bytes, String] {
  if offset < 0L || length < 0 {
    return Err("cursor offset and length must be non-negative")
  }
  match cursor.size {
    Some(size) if offset >= size => Ok(Bytes::new(0))
    _ => (cursor.read_at)(offset, length)
  }
}

///|
/// Borrow an in-memory payload view without copying when available.
pub fn source_cursor_view_at(
  cursor : SourceCursor,
  offset : Int,
  length : Int,
) -> BytesView? {
  if offset < 0 || length < 0 {
    return None
  }
  (cursor.view_at)(offset, length)
}

///|
fn source_cursor_from_bytes(bytes : Bytes) -> SourceCursor {
  {
    size: Some(bytes.length().to_int64()),
    read_at: fn(offset, length) {
      if offset < 0L || length < 0 || offset > bytes.length().to_int64() {
        return Err("cursor read is outside the payload")
      }
      let start = offset.to_int()
      let end = (start + length).min(bytes.length())
      Ok(bytes.view(start~, end~).to_owned())
    },
    view_at: fn(offset, length) {
      if offset < 0 || length < 0 || offset > bytes.length() {
        return None
      }
      Some(bytes.view(start=offset, end=(offset + length).min(bytes.length())))
    },
  }
}
