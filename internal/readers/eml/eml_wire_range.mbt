///|
// A single original-wire decoding choice applies to every range. An invalid
// byte anywhere used to select byte-preserving text for the whole message;
// per-part UTF8 guesses would silently change mixed-byte legacy messages.
priv enum EmlWireTextMode {
  Utf8
  BytePreserving
}

///|
priv struct EmlWireOwner {
  bytes : Bytes
  mode : EmlWireTextMode
}

///|
// Half-open byte offsets in this owner, never normalized/UTF16 positions.
// Nested decoded-message adapters own a distinct, unnormalized UTF8 buffer;
// their local offsets do not pretend to address the outer transfer wire.
priv struct EmlWireRange {
  owner : EmlWireOwner
  start : Int32
  end : Int32
}

///|
priv struct EmlWireLine {
  start : Int32
  end : Int32
  next : Int32
}

///|
priv struct EmlMultipartRangeCursor {
  body : EmlWireRange
  marker : Bytes?
  closing : Bytes?
  mut offset : Int32
  mut child_start : Int32?
  mut done : Bool
}

///|
fn eml_wire_from_text(text : String) -> EmlWireOwner raise EmlError {
  match @input.validated_text_utf8_size(text) {
    Ok(_) => ()
    Err(message) => raise InvalidEncoding(message)
  }
  { bytes: @utf8.encode(text), mode: Utf8, }
}

///|
// Choosing the global mode never constructs a complete decoded String. Reuse
// the shared UTF8 decoder with a bounded temporary and at most three carry
// bytes. The later whole text belongs to the existing PreparedEmlMessage DTO.
fn eml_wire_valid_utf8(bytes : Bytes) -> Bool {
  let mut offset = 0
  let mut carry = b""
  while offset < bytes.length() {
    let count = (bytes.length() - offset).min(65536)
    let pending = Bytes::makei(carry.length() + count, i => {
      if i < carry.length() {
        carry[i]
      } else {
        bytes[offset + i - carry.length()]
      }
    })
    offset += count
    match
      @sourceio.decode_utf8_source_chunk(pending, offset == bytes.length()) {
      Ok((_, tail)) => carry = tail
      Err(_) => return false
    }
  }
  true
}

///|
fn eml_wire_text_and_owner(bytes : Bytes) -> (String, EmlWireOwner) {
  if eml_wire_valid_utf8(bytes) {
    let decoded = try @utf8.decode(bytes, ignore_bom=false) |> Some catch {
      _ => None
    }
    if decoded is Some(text) {
      return (text, { bytes, mode: Utf8, })
    }
  }
  let text = String::from_array(
    Array::makei(bytes.length(), i => bytes[i].to_int().unsafe_to_char()),
  )
  (text, { bytes, mode: BytePreserving, })
}

///|
fn eml_wire_whole(owner : EmlWireOwner) -> EmlWireRange {
  { owner, start: 0, end: owner.bytes.length(), }
}

///|
fn eml_wire_text(range : EmlWireRange) -> String raise EmlError {
  let text = match range.owner.mode {
    Utf8 =>
      @utf8.decode(range.owner.bytes[range.start:range.end], ignore_bom=false) catch {
        _ =>
          raise InvalidEncoding("MIME range is not aligned with its UTF8 owner")
      }
    BytePreserving =>
      String::from_array(
        Array::makei(range.end - range.start, i => {
          range.owner.bytes[range.start + i].to_int().unsafe_to_char()
        }),
      )
  }
  eml_normalize_newlines(text)
}

///|
fn eml_wire_eol(bytes : Bytes, at : Int32, end : Int32) -> Int32? {
  if at >= end {
    return None
  }
  if bytes[at] == b'\r' {
    Some(if at + 1 < end && bytes[at + 1] == b'\n' { at + 2 } else { at + 1 })
  } else if bytes[at] == b'\n' {
    Some(at + 1)
  } else {
    None
  }
}

///|
fn eml_wire_line(range : EmlWireRange, start : Int32) -> EmlWireLine? {
  if start >= range.end {
    return None
  }
  let mut end = start
  while end < range.end {
    if eml_wire_eol(range.owner.bytes, end, range.end) is Some(next) {
      return Some({ start, end, next, })
    }
    end += 1
  }
  Some({ start, end, next: end, })
}

///|
fn eml_wire_headers_body(range : EmlWireRange) -> (EmlWireRange, EmlWireRange) {
  let mut at = range.start
  while at < range.end {
    if eml_wire_eol(range.owner.bytes, at, range.end) is Some(next) {
      if eml_wire_eol(range.owner.bytes, next, range.end) is Some(body_start) {
        return ({ ..range, end: at, }, { ..range, start: body_start, })
      }
      at = next
    } else {
      at += 1
    }
  }
  (range, { ..range, start: range.end, })
}

///|
fn eml_wire_space(byte : Byte) -> Bool {
  byte == b' ' || byte == b'\t' || byte == b'\r' || byte == b'\n'
}

///|
fn eml_wire_trim(range : EmlWireRange) -> EmlWireRange {
  let mut start = range.start
  let mut end = range.end
  while start < end && eml_wire_space(range.owner.bytes[start]) {
    start += 1
  }
  while end > start && eml_wire_space(range.owner.bytes[end - 1]) {
    end -= 1
  }
  { ..range, start, end, }
}

///|
fn eml_wire_marker(owner : EmlWireOwner, value : String) -> Bytes? {
  match owner.mode {
    Utf8 => Some(@utf8.encode(value))
    BytePreserving => {
      let bytes : Array[Byte] = []
      for ch in value {
        if ch.to_int() > 255 {
          return None
        }
        bytes.push(ch.to_int().to_byte())
      }
      Some(Bytes::from_array(bytes))
    }
  }
}

///|
fn eml_wire_matches(range : EmlWireRange, expected : Bytes?) -> Bool {
  guard expected is Some(expected) else { return false }
  if range.end - range.start != expected.length() {
    return false
  }
  for i in 0..<expected.length() {
    if range.owner.bytes[range.start + i] != expected[i] {
      return false
    }
  }
  true
}

///|
fn new_eml_multipart_cursor(
  body : EmlWireRange,
  boundary : String,
) -> EmlMultipartRangeCursor {
  {
    body,
    marker: eml_wire_marker(body.owner, "--" + boundary),
    closing: eml_wire_marker(body.owner, "--" + boundary + "--"),
    offset: body.start,
    child_start: None,
    done: false,
  }
}

///|
fn EmlMultipartRangeCursor::next(
  self : EmlMultipartRangeCursor,
) -> EmlWireRange? {
  if self.done {
    return None
  }
  while self.offset < self.body.end {
    let line = eml_wire_line(self.body, self.offset).unwrap()
    self.offset = line.next
    let marker = eml_wire_trim({
      ..self.body,
      start: line.start,
      end: line.end,
    })
    let opening = eml_wire_matches(marker, self.marker)
    let closing = eml_wire_matches(marker, self.closing)
    if opening || closing {
      let child = self.child_start.map(start => {
        eml_wire_trim({ ..self.body, start, end: line.start, })
      })
      if closing {
        self.done = true
        self.child_start = None
      } else {
        self.child_start = Some(line.next)
      }
      if child is Some(child) && child.start < child.end {
        return Some(child)
      }
      if self.done {
        return None
      }
    }
  }
  self.done = true
  if self.child_start is Some(start) {
    self.child_start = None
    let child = eml_wire_trim({ ..self.body, start, })
    if child.start < child.end {
      return Some(child)
    }
  }
  None
}

///|
fn eml_multipart_ranges(
  body : EmlWireRange,
  boundary : String,
) -> Array[EmlWireRange] raise EmlError {
  let cursor = new_eml_multipart_cursor(body, boundary)
  let ranges : Array[EmlWireRange] = []
  while cursor.next() is Some(range) {
    if ranges.length() == 1024 {
      raise LimitExceeded(MultipartParts, observed=1025L, limit=1024L)
    }
    ranges.push(range)
  }
  ranges
}
