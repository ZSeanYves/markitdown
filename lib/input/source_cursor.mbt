///|
/// One bounded asynchronous random-access protocol for every input kind.
pub struct SourceCursor {
  size : Int64?
  read_at : async (Int64, Int32) -> Result[Bytes, String]
  view_at : (Int32, Int32) -> BytesView?
  priv close_file : () -> Unit
  priv is_closed : () -> Bool
  priv failure : Ref[InputFailure?]
  priv max_bytes : Int64
}

///|
pub async fn open_source_cursor(
  source : InputSource,
  max_bytes? : Int64,
) -> Result[SourceCursor, String] noraise {
  if source.session is Some(state) && state.closed.val {
    return Err("input session is closed")
  }
  if input_source_error(source) is Some(message) {
    return Err(message)
  }
  match charge_source_read_traffic(source, 0L) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let max_bytes = effective_input_byte_limit(source, max_bytes)
  match validate_memory_input(source, max_bytes~) {
    Err(message) => return Err(message)
    Ok(_) => ()
  }
  if max_bytes < 0L {
    return record_input_result(
      source,
      Err("input byte limit must be non-negative"),
    )
  }
  let cursor = match open_source_cursor_unchecked(source) {
    Ok(value) => value
    Err(message) => return record_input_result(source, Err(message))
  }
  let bounded = {
    ..cursor,
    read_at: async fn(offset, length) {
      if (cursor.is_closed)() ||
        (source.session is Some(state) && state.closed.val) {
        return Err("input file is closed")
      }
      if input_source_error(source) is Some(message) {
        return record_input_result(source, Err(message))
      }
      match charge_source_read_traffic(source, 0L) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
      let result = (cursor.read_at)(offset, length) catch {
        error => Err(error.to_string())
      }
      match result {
        Ok(bytes) =>
          match charge_source_read_traffic(source, bytes.length().to_int64()) {
            Ok(_) => Ok(bytes)
            Err(message) => Err(message)
          }
        Err(message) => record_input_result(source, Err(message))
      }
    },
    view_at: fn(offset, length) {
      if (cursor.is_closed)() ||
        (source.session is Some(state) && state.closed.val) {
        return None
      }
      if input_source_error(source) is Some(_) {
        return None
      }
      match charge_source_read_traffic(source, 0L) {
        Ok(_) => ()
        Err(_) => return None
      }
      match (cursor.view_at)(offset, length) {
        Some(view) =>
          match charge_source_read_traffic(source, view.length().to_int64()) {
            Ok(_) => Some(view)
            Err(_) => None
          }
        None => None
      }
    },
    max_bytes: match source.physical_bytes {
      Some(_) => cursor.size.unwrap_or(max_bytes)
      None => max_bytes
    },
    failure: match source.session {
      Some(state) => state.failure
      None => cursor.failure
    },
    is_closed: fn() {
      (cursor.is_closed)() ||
      (match source.session {
        Some(state) => state.closed.val
        None => false
      })
    },
  }
  match bounded.size {
    Some(size) if size < 0L => {
      close_cursor_if_unowned(source, bounded)
      record_input_result(source, Err("reader declared a negative size"))
    }
    Some(size) if size > max_bytes && source.physical_bytes is None => {
      close_cursor_if_unowned(source, bounded)
      record_input_result(source, Err(input_limit_message(size, max_bytes)))
    }
    _ => Ok(bounded)
  }
}

///|
/// Query metadata only. Conversion preflight reports its domain-specific limit
/// error before opening a bounded cursor for content.
pub async fn input_source_size(
  source : InputSource,
) -> Result[Int64?, String] noraise {
  if source.session is Some(state) && state.closed.val {
    return Err("input session is closed")
  }
  if input_source_error(source) is Some(message) {
    return Err(message)
  }
  if source.payload is Text(text) {
    let size = match validated_text_utf8_size(text) {
      Ok(value) => source.physical_bytes.unwrap_or(value)
      Err(message) => return record_input_result(source, Err(message))
    }
    if size < 0L {
      return record_input_result(
        source,
        Err("prepared input declared a negative physical size"),
      )
    }
    return Ok(Some(size))
  }
  match input_size(source) {
    Some(size) if size < 0L =>
      record_input_result(source, Err("reader declared a negative size"))
    Some(size) => Ok(Some(size))
    None =>
      match open_source_cursor_unchecked(source) {
        Ok(cursor) => {
          defer close_cursor_if_unowned(source, cursor)
          Ok(cursor.size)
        }
        Err(message) => record_input_result(source, Err(message))
      }
  }
}

///|
async fn open_source_cursor_unchecked(
  source : InputSource,
) -> Result[SourceCursor, String] noraise {
  match source.payload {
    Path(path) =>
      match source.session {
        None => open_path_source_cursor(path)
        Some(session) => {
          session.open_mutex.acquire()
          defer session.open_mutex.release()
          if session.closed.val {
            return Err("input session is closed")
          }
          match session.cursors.get(path) {
            Some(cursor) => Ok(cursor)
            None => {
              let cursor = match open_path_source_cursor(path) {
                Ok(value) => value
                Err(message) => return Err(message)
              }
              if session.closed.val {
                source_cursor_close(cursor)
                return Err("input session is closed")
              }
              session.cursors[path] = cursor
              Ok(cursor)
            }
          }
        }
      }
    Text(text) => Ok(source_cursor_from_bytes(@utf8.encode(text)))
    Bytes(bytes) => Ok(source_cursor_from_bytes(bytes))
    Reader(reader) =>
      Ok({
        size: reader.size,
        read_at: reader.read_at,
        view_at: fn(_, _) { None },
        close_file: fn() {  },
        is_closed: fn() { false },
        failure: Ref(None),
        max_bytes: 512L * 1024L * 1024L,
      })
  }
}

///|
pub async fn source_cursor_read_at(
  cursor : SourceCursor,
  offset : Int64,
  length~ : Int32 = 64 * 1024,
) -> Result[Bytes, String] noraise {
  record_cursor_result(
    cursor,
    source_cursor_read_at_inner(cursor, offset, length~),
  )
}

///|
async fn source_cursor_read_at_inner(
  cursor : SourceCursor,
  offset : Int64,
  length~ : Int32,
) -> Result[Bytes, String] noraise {
  if (cursor.is_closed)() {
    return Err("input file is closed")
  }
  if source_cursor_error(cursor) is Some(message) {
    return Err(message)
  }
  if offset < 0L || length < 0 {
    return Err("cursor offset and length must be non-negative")
  }
  if offset > cursor.max_bytes {
    return Err(input_limit_message(offset, cursor.max_bytes))
  }
  if length == 0 {
    return Ok(b"")
  }
  match cursor.size {
    Some(size) if offset >= size => return Ok(b"")
    _ => ()
  }
  // An unknown-size reader may be asked for one sentinel byte at the ceiling,
  // so exact-limit input succeeds and a larger input cannot look truncated.
  let remaining = cursor.max_bytes - offset
  let requested = if remaining < length.to_int64() {
    (remaining + 1L).to_int()
  } else {
    length
  }
  let requested = match cursor.size {
    Some(size) => requested.to_int64().min(size - offset).to_int()
    None => requested
  }
  let result = (cursor.read_at)(offset, requested) catch {
    error => Err(error.to_string())
  }
  let bytes = match result {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match cursor.size {
    Some(size) if bytes.length().to_int64() > size - offset =>
      return Err("reader returned bytes beyond declared size")
    _ => ()
  }
  if bytes.length() > requested {
    return Err("reader returned more bytes than requested")
  }
  if bytes.length().to_int64() > remaining {
    return Err(
      input_limit_message(offset + bytes.length().to_int64(), cursor.max_bytes),
    )
  }
  match cursor.size {
    Some(size) if bytes.is_empty() && offset < size =>
      Err("reader ended before declared size")
    Some(size) if bytes.length().to_int64() > size - offset =>
      Err("reader returned bytes beyond declared size")
    _ => Ok(bytes)
  }
}

///|
/// Fill a requested fixed range across legal short reads. A premature EOF is
/// an error even for an initially unknown-size Reader.
pub async fn source_cursor_read_exact_at(
  cursor : SourceCursor,
  offset : Int64,
  length : Int32,
) -> Result[Bytes, String] noraise {
  if (cursor.is_closed)() {
    return Err("input file is closed")
  }
  if source_cursor_error(cursor) is Some(message) {
    return Err(message)
  }
  if offset < 0L ||
    length < 0 ||
    offset > 9223372036854775807L - length.to_int64() {
    return record_cursor_result(
      cursor,
      Err("cursor offset and length must be non-negative and bounded"),
    )
  }
  let out = @buffer.Buffer(size_hint=length.min(64 * 1024))
  let mut consumed = 0
  while consumed < length {
    let bytes = match
      source_cursor_read_at(
        cursor,
        offset + consumed.to_int64(),
        length=(length - consumed).min(64 * 1024),
      ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    if bytes.is_empty() {
      return record_cursor_result(
        cursor,
        Err("reader ended before requested range"),
      )
    }
    out.write_bytes(bytes[:])
    consumed += bytes.length()
  }
  Ok(out.to_bytes())
}

///|
/// Locate EOF without retaining the payload. Reader contracts describe a
/// stable contiguous file: an empty read means EOF, not a sparse missing byte.
/// At most logarithmically many one-byte requests are needed within the same
/// effective ceiling used by ordinary reads.
pub async fn discover_source_size(
  cursor : SourceCursor,
) -> Result[Int64, String] noraise {
  if (cursor.is_closed)() {
    return Err("input file is closed")
  }
  if source_cursor_error(cursor) is Some(message) {
    return Err(message)
  }
  match cursor.size {
    Some(size) => return Ok(size)
    None => ()
  }
  let first = match source_cursor_read_at(cursor, 0L, length=1) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if first.is_empty() {
    return Ok(0L)
  }
  let mut present = 0L
  let mut absent = 1L.min(cursor.max_bytes)
  while true {
    let bytes = match source_cursor_read_at(cursor, absent, length=1) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    if bytes.is_empty() {
      break
    }
    present = absent
    absent = if absent > cursor.max_bytes / 2L {
      cursor.max_bytes
    } else {
      (absent * 2L).min(cursor.max_bytes)
    }
  }
  while absent - present > 1L {
    let middle = present + (absent - present) / 2L
    let bytes = match source_cursor_read_at(cursor, middle, length=1) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    if bytes.is_empty() {
      absent = middle
    } else {
      present = middle
    }
  }
  Ok(absent)
}

///|
pub fn source_cursor_view_at(
  cursor : SourceCursor,
  offset : Int32,
  length : Int32,
) -> BytesView? {
  if (cursor.is_closed)() ||
    offset < 0 ||
    length < 0 ||
    offset.to_int64() > cursor.max_bytes {
    return None
  }
  let bounded = length
    .to_int64()
    .min(cursor.max_bytes - offset.to_int64())
    .to_int()
  (cursor.view_at)(offset, bounded)
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
      Ok(
        bytes
        .exact_view(start~, end=start + length.min(bytes.length() - start))
        .to_owned(),
      )
    },
    view_at: fn(offset, length) {
      if offset < 0 || length < 0 || offset > bytes.length() {
        return None
      }
      Some(
        bytes.exact_view(
          start=offset,
          end=offset + length.min(bytes.length() - offset),
        ),
      )
    },
    close_file: fn() {  },
    is_closed: fn() { false },
    failure: Ref(None),
    max_bytes: 512L * 1024L * 1024L,
  }
}

///|
pub fn source_cursor_close(cursor : SourceCursor) -> Unit {
  (cursor.close_file)()
}

///|
pub fn source_cursor_error(cursor : SourceCursor) -> String? {
  cursor.failure.val.map(input_failure_message)
}

///|
fn input_limit_message(observed : Int64, limit : Int64) -> String {
  "input byte limit exceeded: observed=" +
  observed.to_string() +
  "; limit=" +
  limit.to_string()
}

///|
fn record_cursor_result(
  cursor : SourceCursor,
  result : Result[Bytes, String],
) -> Result[Bytes, String] {
  match result {
    Err(message) if cursor.failure.val is None =>
      cursor.failure.val = Some(InputError(message))
    _ => ()
  }
  result
}
