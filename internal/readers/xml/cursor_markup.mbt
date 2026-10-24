///|
fn cursor_prefix(chars : Array[Char], marker : String) -> Bool {
  let expected = marker.to_array()
  if chars.length() > expected.length() {
    return false
  }
  for i in 0..<chars.length() {
    if chars[i] != expected[i] {
      return false
    }
  }
  true
}

///|
fn cursor_suffix(chars : Array[Char], marker : String) -> Bool {
  let expected = marker.to_array()
  if chars.length() < expected.length() {
    return false
  }
  let start = chars.length() - expected.length()
  for i in 0..<expected.length() {
    if chars[start + i] != expected[i] {
      return false
    }
  }
  true
}

///|
fn XmlCursor::normalized_string(
  self : XmlCursor,
  chars : ArrayView[Char],
) -> String raise XmlCursorAbort {
  let buffer = cursor_buffer(self.budget)
  defer buffer.clear()
  let mut pending_cr = false
  for ch in chars {
    self.charge(cursor_utf8_width(ch).to_int64())
    if ch == '\n' && pending_cr {
      pending_cr = false
      continue
    }
    buffer.push(if ch == '\r' { '\n' } else { ch })
    pending_cr = ch == '\r'
  }
  self.own_string(buffer.chars[:])
}

///|
fn XmlCursor::read_markup_char(
  self : XmlCursor,
  raw : Char,
) -> XmlCursorToken? raise XmlCursorAbort {
  let bytes = self.position.utf8_byte - self.markup_start.utf8_byte
  cursor_cap(TokenBytes, bytes, self.limits.max_token_bytes)
  self.max_markup_bytes = self.max_markup_bytes.max(bytes)
  self.markup.push(raw)
  let chars = self.markup.chars
  let length = chars.length()
  let span : XmlCursorSpan = { start: self.markup_start, end: self.position, }
  match self.mode {
    CommentBody => {
      if !cursor_suffix(chars, "-->") {
        return None
      }
      self.count_token()
      let value = self.normalized_string(chars[4:length - 3])
      self.markup.clear()
      self.mode = Data
      return Some(Comment(value, span))
    }
    InstructionBody => {
      if !cursor_suffix(chars, "?>") {
        return None
      }
      self.count_token()
      let reader = cursor_tag_reader(self, chars, self.markup_start, 2)
      let target = reader.name()
      reader.spaces()
      let body = self
        .normalized_string(chars[reader.index:length - 2])
        .trim()
        .to_owned()
      self.markup.clear()
      self.mode = Data
      return Some(
        if target == "xml" {
          Declaration(body, span)
        } else {
          ProcessingInstruction(target, body, span)
        },
      )
    }
    DoctypeBody => {
      match self.quote {
        Some(quote) => if raw == quote { self.quote = None }
        None =>
          if raw == '\'' || raw == '"' {
            self.quote = Some(raw)
          } else if raw == '[' {
            self.bracket_depth += 1
          } else if raw == ']' && self.bracket_depth > 0 {
            self.bracket_depth -= 1
          } else if raw == '>' && self.bracket_depth == 0 {
            self.count_token()
            let value = self
              .normalized_string(chars[9:length - 1])
              .trim()
              .to_owned()
            self.markup.clear()
            self.mode = Data
            return Some(Doctype(value, span))
          }
      }
      return None
    }
    _ => ()
  }
  if length == 2 {
    if raw == '?' {
      self.mode = InstructionBody
      return None
    }
    if raw == '!' || raw == '/' {
      return None
    }
    if !is_name_start(raw) {
      self.syntax(InvalidName, "expected XML element name")
    }
  }
  if length >= 2 && chars[1] == '!' {
    if cursor_prefix(chars, "<!--") {
      if length == 4 {
        self.mode = CommentBody
      }
    } else if cursor_prefix(chars, "<![CDATA[") {
      if length == 9 {
        if self.stack.is_empty() {
          self.syntax(InvalidToken, "CDATA outside document element")
        }
        self.markup.clear()
        self.mode = CDataBody
        self.begin_text(self.markup_start)
      }
    } else if cursor_prefix(chars, "<!DOCTYPE") {
      if length == 9 {
        if !self.stack.is_empty() || self.root_seen {
          self.syntax(InvalidToken, "DOCTYPE after document element")
        }
        self.mode = DoctypeBody
        self.quote = None
        self.bracket_depth = 0
      }
    } else {
      self.syntax(InvalidToken, "unsupported XML declaration")
    }
    return None
  }
  match self.quote {
    Some(quote) => if raw == quote { self.quote = None }
    None =>
      if raw == '\'' || raw == '"' {
        self.quote = Some(raw)
      } else if raw == '>' {
        let token = if chars.length() > 1 && chars[1] == '/' {
          self.parse_end_markup(chars, span)
        } else {
          self.parse_start_markup(chars, span)
        }
        self.markup.clear()
        self.mode = Data
        return Some(token)
      }
  }
  None
}

///|
priv struct XmlCursorTagReader {
  cursor : XmlCursor
  chars : Array[Char]
  mut index : Int32
  mut position : XmlCursorPosition
  mut pending_cr : Bool
}

///|
fn cursor_tag_reader(
  cursor : XmlCursor,
  chars : Array[Char],
  start : XmlCursorPosition,
  skip : Int32,
) -> XmlCursorTagReader raise XmlCursorAbort {
  let reader = { cursor, chars, index: 0, position: start, pending_cr: false, }
  for _ in 0..<skip {
    ignore(reader.take())
  }
  reader
}

///|
fn XmlCursorTagReader::take(
  self : XmlCursorTagReader,
) -> Char raise XmlCursorAbort {
  if self.index >= self.chars.length() {
    self.cursor.syntax(UnexpectedEOF, "unterminated XML tag")
  }
  let ch = self.chars[self.index]
  self.cursor.charge(cursor_utf8_width(ch).to_int64())
  let (position, pending_cr) = cursor_advance_position(
    self.position,
    ch,
    self.pending_cr,
  )
  self.position = position
  self.pending_cr = pending_cr
  self.index += 1
  ch
}

///|
fn XmlCursorTagReader::peek(self : XmlCursorTagReader) -> Char? {
  self.chars.get(self.index)
}

///|
fn XmlCursorTagReader::spaces(
  self : XmlCursorTagReader,
) -> Unit raise XmlCursorAbort {
  while self.peek() is Some(ch) && cursor_space(ch) {
    ignore(self.take())
  }
}

///|
fn XmlCursorTagReader::expect(
  self : XmlCursorTagReader,
  expected : Char,
) -> Unit raise XmlCursorAbort {
  if self.take() != expected {
    self.cursor.syntax(InvalidToken, "malformed XML tag")
  }
}

///|
fn XmlCursorTagReader::name(
  self : XmlCursorTagReader,
) -> String raise XmlCursorAbort {
  let start = self.index
  match self.peek() {
    Some(ch) if is_name_start(ch) => ignore(self.take())
    _ => self.cursor.syntax(InvalidName, "expected XML name")
  }
  while self.peek() is Some(ch) && is_name_char(ch) {
    ignore(self.take())
  }
  self.cursor.own_string(self.chars[start:self.index])
}

///|
fn XmlCursorTagReader::value(
  self : XmlCursorTagReader,
) -> (String, Char) raise XmlCursorAbort {
  let quote = self.take()
  if quote != '\'' && quote != '"' {
    self.cursor.syntax(InvalidToken, "unquoted XML attribute")
  }
  let value = cursor_buffer(self.cursor.budget)
  defer value.clear()
  while self.peek() is Some(raw) {
    let skip_lf = raw == '\n' && self.pending_cr
    ignore(self.take())
    if raw == quote {
      return (self.cursor.own_string(value.chars[:]), quote)
    }
    if raw == '<' {
      self.cursor.syntax(InvalidToken, "unescaped < in XML attribute")
    }
    if raw == '&' {
      let start = self.index
      while self.peek() is Some(ch) && ch != ';' {
        if cursor_space(ch) || ch == '<' || ch == '&' || ch == quote {
          self.cursor.syntax(MalformedEntity, "malformed XML attribute entity")
        }
        ignore(self.take())
      }
      let end = self.index
      self.expect(';')
      value.push(self.cursor.decode_entity(self.chars[start:end]))
    } else if !skip_lf {
      value.push(if raw == '\r' { '\n' } else { raw })
    }
  }
  self.cursor.syntax(UnexpectedEOF, "unterminated XML attribute")
}

///|
fn XmlCursor::parse_start_markup(
  self : XmlCursor,
  chars : Array[Char],
  span : XmlCursorSpan,
) -> XmlCursorToken raise XmlCursorAbort {
  let reader = cursor_tag_reader(self, chars, span.start, 1)
  let raw = reader.name()
  let attributes : Array[XmlCursorAttribute] = []
  let seen : Map[String, Bool] = Map([])
  let mut self_closing = false
  while true {
    let before_spaces = reader.index
    reader.spaces()
    match reader.peek() {
      Some('>') => {
        reader.expect('>')
        break
      }
      Some('/') => {
        reader.expect('/')
        reader.expect('>')
        self_closing = true
        break
      }
      _ => ()
    }
    if before_spaces == reader.index {
      self.syntax(InvalidToken, "XML attributes require whitespace")
    }
    let observed = attributes.length().to_int64() + 1L
    cursor_cap(Attributes, observed, self.limits.max_attributes)
    self.max_attributes = self.max_attributes.max(observed)
    let start = reader.position
    let name = reader.name()
    self.charge(name.length().to_int64())
    if seen.contains(name) {
      self.syntax(DuplicateAttribute, "duplicate XML attribute")
    }
    seen.set(name, true)
    reader.spaces()
    reader.expect('=')
    reader.spaces()
    let (value, quote) = reader.value()
    attributes.push({
      name: { raw: name, local_name: name, namespace_uri: None, },
      value,
      quote,
      span: { start, end: reader.position, },
      namespace_declaration: name == "xmlns" || name.has_prefix("xmlns:"),
    })
  }
  if reader.index != chars.length() {
    self.syntax(InvalidToken, "data after XML start tag")
  }
  if self.stack.is_empty() && self.root_seen {
    self.syntax(MultipleRootElements, "multiple XML document elements")
  }
  let depth = self.stack.length().to_int64() + 1L
  cursor_cap(Depth, depth, self.limits.max_depth)
  self.max_depth = self.max_depth.max(depth)
  let prefixes = self.install_namespaces(attributes)
  let name = self.resolve_name(raw, false)
  let expanded_seen : Map[(String?, String), Bool] = Map([])
  for i in 0..<attributes.length() {
    let attribute = attributes[i]
    let expanded = if attribute.namespace_declaration {
      let local_name = if attribute.name.raw == "xmlns" {
        "xmlns"
      } else {
        self.own_substring(attribute.name.raw, 6, attribute.name.raw.length())
      }
      {
        raw: attribute.name.raw,
        local_name,
        namespace_uri: Some("http://www.w3.org/2000/xmlns/"),
      }
    } else {
      self.resolve_name(attribute.name.raw, true)
    }
    if !attribute.namespace_declaration {
      // Undeclared prefixes have no expanded URI in explicit compatibility
      // mode. Their raw QNames remain distinct; real namespace aliases must
      // still obey duplicate-expanded-attribute validation.
      let key = (
        expanded.namespace_uri,
        if self.allow_unbound_prefixes &&
          expanded.namespace_uri is None &&
          expanded.raw.contains(":") {
          expanded.raw
        } else {
          expanded.local_name
        },
      )
      if expanded_seen.contains(key) {
        self.syntax(DuplicateAttribute, "duplicate expanded XML attribute")
      }
      expanded_seen.set(key, true)
    }
    attributes[i] = { ..attribute, name: expanded, }
  }
  self.count_token()
  self.root_seen = true
  if self_closing {
    self.restore_namespaces(prefixes)
  } else {
    // Frame capacity is a conservative retained UTF16 payload reservation;
    // emitted attributes remain consumer-owned after the next pull.
    let mut units = name.raw.length().to_int64() +
      name.local_name.length().to_int64()
    for prefix in prefixes {
      units += prefix.length().to_int64()
      if self.namespace_uri(prefix) is Some(uri) {
        units += uri.length().to_int64()
      }
    }
    let lease = cursor_reserve(self.budget, units * 2L)
    self.stack.push({ name, prefixes, lease, })
  }
  StartElement(name, attributes, self_closing, span)
}

///|
fn XmlCursor::parse_end_markup(
  self : XmlCursor,
  chars : Array[Char],
  span : XmlCursorSpan,
) -> XmlCursorToken raise XmlCursorAbort {
  let reader = cursor_tag_reader(self, chars, span.start, 2)
  let raw = reader.name()
  reader.spaces()
  reader.expect('>')
  if reader.index != chars.length() {
    self.syntax(InvalidToken, "data after XML end tag")
  }
  let frame = match self.stack.last() {
    Some(frame) => frame
    None => self.syntax(UnexpectedClosingTag, "unexpected XML closing tag")
  }
  if raw != frame.name.raw {
    self.syntax(MismatchedTag, "mismatched XML closing tag")
  }
  let name = self.resolve_name(raw, false)
  self.count_token()
  ignore(self.stack.pop())
  self.restore_namespaces(frame.prefixes)
  if frame.lease is Some(lease) {
    self.returned_leases.push(lease)
  }
  EndElement(name, span)
}
