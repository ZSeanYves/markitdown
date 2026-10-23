///|
// The ledger measures reserved scalar-buffer capacity and UTF16 payload
// capacity, not allocator/container overhead. Geometric growth reserves the
// replacement before copying, so its transient peak includes both buffers.
priv struct XmlCursorBuffer {
  mut chars : Array[Char]
  mut capacity : Int32
  mut utf8_bytes : Int32
  mut utf16_units : Int32
  mut lease : @budget.BudgetLease?
  budget : @budget.BudgetContext?
}

///|
fn cursor_buffer(budget : @budget.BudgetContext?) -> XmlCursorBuffer {
  {
    chars: [],
    capacity: 0,
    utf8_bytes: 0,
    utf16_units: 0,
    lease: None,
    budget,
  }
}

///|
fn cursor_reserve(
  budget : @budget.BudgetContext?,
  amount : Int64,
) -> @budget.BudgetLease? raise XmlCursorAbort {
  match budget {
    None => None
    Some(context) =>
      match context.account.reserve(@budget.WorkingBytes, amount) {
        Ok(lease) => Some(lease)
        Err(error) => raise Stop(Budget(error))
      }
  }
}

///|
fn cursor_release(lease : @budget.BudgetLease?) -> Unit {
  if lease is Some(value) {
    value.release()
  }
}

///|
fn cursor_utf8_width(ch : Char) -> Int32 {
  let value = ch.to_int()
  if value <= 0x7f {
    1
  } else if value <= 0x7ff {
    2
  } else if value <= 0xffff {
    3
  } else {
    4
  }
}

///|
fn XmlCursorBuffer::push(
  self : XmlCursorBuffer,
  ch : Char,
) -> Unit raise XmlCursorAbort {
  let width = cursor_utf8_width(ch)
  let units = if ch.to_int() > 0xffff { 2 } else { 1 }
  if self.utf8_bytes > 2147483647 - width ||
    self.utf16_units > 2147483647 - units {
    raise Stop(InvalidState("XML scalar buffer length overflow"))
  }
  if self.chars.length() == self.capacity {
    if self.capacity > 1073741823 {
      raise Stop(InvalidState("XML scalar buffer capacity overflow"))
    }
    let capacity = if self.capacity == 0 { 1 } else { self.capacity * 2 }
    let lease = cursor_reserve(self.budget, capacity.to_int64() * 4L)
    let replacement : Array[Char] = Array(capacity~)
    replacement.append(self.chars[:])
    self.chars = replacement
    self.capacity = capacity
    cursor_release(self.lease)
    self.lease = lease
  }
  self.chars.push(ch)
  self.utf8_bytes += width
  self.utf16_units += units
}

///|
fn XmlCursorBuffer::clear(self : XmlCursorBuffer) -> Unit {
  self.chars = []
  self.capacity = 0
  self.utf8_bytes = 0
  self.utf16_units = 0
  cursor_release(self.lease)
  self.lease = None
}

///|
fn XmlCursor::own_string(
  self : XmlCursor,
  chars : ArrayView[Char],
) -> String raise XmlCursorAbort {
  let mut units = 0L
  for ch in chars {
    units += if ch.to_int() > 0xffff { 2L } else { 1L }
  }
  let lease = cursor_reserve(self.budget, units * 2L)
  if lease is Some(value) {
    self.returned_leases.push(value)
  }
  String::from_array(chars)
}

///|
fn XmlCursor::release_returned(self : XmlCursor) -> Unit {
  for lease in self.returned_leases {
    lease.release()
  }
  self.returned_leases.clear()
}

///|
fn cursor_string_bytes(value : String) -> Int64 {
  let mut bytes = 0L
  for ch in value {
    bytes += cursor_utf8_width(ch).to_int64()
  }
  bytes
}

///|
fn XmlCursor::own_substring(
  self : XmlCursor,
  value : String,
  start : Int32,
  end : Int32,
) -> String raise XmlCursorAbort {
  let lease = cursor_reserve(self.budget, (end - start).to_int64() * 2L)
  if lease is Some(value) {
    self.returned_leases.push(value)
  }
  value[start:end].to_owned()
}

///|
// Reuse the existing safe entity decoder without leaving per-entity String
// leases alive for an entire large attribute. Its successful result is exactly
// one scalar. Reserve its name/substring/scalar-array scratch before calling it.
fn XmlCursor::decode_entity(
  self : XmlCursor,
  chars : ArrayView[Char],
) -> Char raise XmlCursorAbort {
  let mut units = 0L
  let mut bytes = 0L
  for ch in chars {
    units += if ch.to_int() > 0xffff { 2L } else { 1L }
    bytes += cursor_utf8_width(ch).to_int64()
  }
  self.charge(bytes)
  let scratch = cursor_reserve(
    self.budget,
    units * 4L + chars.length().to_int64() * 4L + 8L,
  )
  defer cursor_release(scratch)
  let decoded = decode_xml_entity(String::from_array(chars)) catch {
    _ => self.syntax(MalformedEntity, "unsupported or invalid XML entity")
  }
  decoded.to_array()[0]
}

///|
fn XmlCursor::charge(
  self : XmlCursor,
  amount : Int64,
) -> Unit raise XmlCursorAbort {
  if self.budget is Some(context) {
    match context.account.charge(@budget.ParseWork, amount) {
      Ok(_) => ()
      Err(error) => raise Stop(Budget(error))
    }
  }
}

///|
fn cursor_cap(
  kind : XmlCursorLimit,
  observed : Int64,
  cap : Int64?,
) -> Unit raise XmlCursorAbort {
  if cap is Some(limit) && observed > limit {
    raise Stop(Limit(kind, observed~, limit~))
  }
}

///|
fn cursor_position() -> XmlCursorPosition {
  { utf8_byte: 0L, scalar: 0L, utf16: 0L, line: 1L, column: 1L, }
}

///|
fn cursor_advance_position(
  position : XmlCursorPosition,
  ch : Char,
  pending_cr : Bool,
) -> (XmlCursorPosition, Bool) raise XmlCursorAbort {
  let width = cursor_utf8_width(ch).to_int64()
  let units = if ch.to_int() > 0xffff { 2L } else { 1L }
  if position.utf8_byte > 9223372036854775807L - width ||
    position.scalar == 9223372036854775807L ||
    position.utf16 > 9223372036854775807L - units ||
    position.line == 9223372036854775807L ||
    position.column == 9223372036854775807L {
    raise Stop(InvalidState("XML source position overflow"))
  }
  let line = if ch == '\r' || (ch == '\n' && !pending_cr) {
    position.line + 1L
  } else {
    position.line
  }
  let column = if ch == '\r' || ch == '\n' {
    1L
  } else if ch == '\u{FEFF}' && position.scalar == 0L {
    position.column
  } else {
    position.column + 1L
  }
  (
    {
      utf8_byte: position.utf8_byte + cursor_utf8_width(ch).to_int64(),
      scalar: position.scalar + 1L,
      utf16: position.utf16 + units,
      line,
      column,
    },
    ch == '\r',
  )
}

///|
fn[T] XmlCursor::syntax(
  self : XmlCursor,
  kind : XmlErrorKind,
  detail : String,
) -> T raise XmlCursorAbort {
  let start = match self.entity_start {
    Some(position) => position
    None =>
      if self.mode is Data {
        self.fragment_start
      } else {
        self.markup_start
      }
  }
  raise Stop(Syntax(kind, detail, { start, end: self.position, }))
}
