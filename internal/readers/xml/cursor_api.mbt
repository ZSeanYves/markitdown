///|
/// Construct a repository-internal lexer. It has no I/O; resource caps are
/// explicit. Namespaces are strict by default. Only known legacy consumers
/// may opt into unbound prefixes: retain raw/local names with no namespace
/// URI, while declared bindings, reserved names and duplicate checks remain.
/// ParseWork units are UTF8 bytes admitted for decoding, plus UTF8 bytes
/// revisited by the atomic markup/name/entity parsers. This deterministic
/// counter is not a claim to count machine instructions or allocator costs.
pub fn new_xml_cursor(
  limits : XmlCursorLimits,
  budget_context? : @budget.BudgetContext,
  allow_unbound_prefixes~ : Bool = false,
) -> Result[XmlCursor, XmlCursorError] {
  let position = cursor_position()
  let carry_lease = try cursor_reserve(budget_context, 3L) |> Ok catch {
    Stop(error) => Err(error)
  }
  match carry_lease {
    Err(error) => Err(error)
    Ok(carry_lease) =>
      Ok({
        limits,
        budget: budget_context,
        allow_unbound_prefixes,
        input: [],
        input_index: 0,
        carry: Bytes::new(0),
        input_lease: None,
        carry_lease,
        need_input: true,
        final_input: false,
        ended: false,
        closed: false,
        failure: None,
        mode: Data,
        position,
        pending_cr: false,
        markup_start: position,
        markup: cursor_buffer(budget_context),
        text: cursor_buffer(budget_context),
        entity: cursor_buffer(budget_context),
        entity_start: None,
        fragment_start: position,
        text_end: position,
        run_started: false,
        fragment_first: true,
        quote: None,
        bracket_depth: 0,
        cdata_brackets: 0,
        stack: [],
        namespaces: Map([]),
        returned_leases: [],
        root_seen: false,
        bindings: 0L,
        input_bytes: 0L,
        tokens: 0L,
        max_depth: 0L,
        max_attributes: 0L,
        max_markup_bytes: 0L,
        max_fragment_bytes: 0L,
        max_bindings: 0L,
      })
  }
}

///|
fn XmlCursor::cleanup(self : XmlCursor) -> Unit {
  self.input = []
  self.carry = Bytes::new(0)
  cursor_release(self.input_lease)
  cursor_release(self.carry_lease)
  self.input_lease = None
  self.carry_lease = None
  self.markup.clear()
  self.text.clear()
  self.entity.clear()
  for frame in self.stack {
    cursor_release(frame.lease)
  }
  self.stack.clear()
  self.namespaces.clear()
  self.release_returned()
}

///|
pub fn XmlCursor::close(self : XmlCursor) -> Unit {
  if !self.closed {
    self.cleanup()
    self.closed = true
  }
}

///|
fn XmlCursor::latch(self : XmlCursor, error : XmlCursorError) -> XmlCursorError {
  match self.failure {
    Some(first) => first
    None => {
      self.failure = Some(error)
      self.cleanup()
      error
    }
  }
}

///|
/// Feed only after NeedInput. The cursor borrows no caller buffer after this
/// call: decoding retains one chunk and at most three incomplete UTF8 bytes.
/// Its workspace reservation is an upper bound of 7 bytes per admitted byte:
/// combined UTF8 bytes + UTF16 String (<=2N) + scalar array (<=4N).
pub fn XmlCursor::feed(
  self : XmlCursor,
  bytes : Bytes,
  eof~ : Bool,
) -> Result[Unit, XmlCursorError] {
  if self.failure is Some(error) {
    return Err(error)
  }
  if self.budget is Some(context) && context.account.failure() is Some(error) {
    return Err(self.latch(Budget(error)))
  }
  if self.closed || self.ended || self.final_input || !self.need_input {
    return Err(
      self.latch(InvalidState("XML feed requires NeedInput before final input")),
    )
  }
  self.release_returned()
  try {
    self.charge(bytes.length().to_int64())
    if bytes.length().to_int64() > 9223372036854775807L - self.input_bytes {
      raise Stop(InvalidState("XML input byte counter overflow"))
    }
    self.input_bytes += bytes.length().to_int64()
    let size = self.carry.length().to_int64() + bytes.length().to_int64()
    let lease = cursor_reserve(self.budget, size * 7L)
    self.input_lease = lease
    let combined = self.carry + bytes
    let decoded = match @sourceio.decode_utf8_source_chunk(combined, eof) {
      Ok(value) => value
      Err(message) => raise Stop(InvalidEncoding(message, self.position))
    }
    self.input = decoded.0.to_array()
    self.carry = decoded.1
    self.input_index = 0
    self.final_input = eof
    self.need_input = false
    Ok(())
  } catch {
    Stop(error) => Err(self.latch(error))
  }
}

///|
pub fn XmlCursor::stats(self : XmlCursor) -> XmlCursorStats {
  {
    input_bytes: self.input_bytes,
    logical_tokens: self.tokens,
    max_depth: self.max_depth,
    max_attributes: self.max_attributes,
    max_markup_bytes: self.max_markup_bytes,
    max_fragment_bytes: self.max_fragment_bytes,
    max_namespace_bindings: self.max_bindings,
  }
}

///|
/// Pull at most one token. Fragment payload lifetime belongs to the consumer;
/// retaining it requires the consumer's own resident reservation.
pub fn XmlCursor::next(
  self : XmlCursor,
) -> Result[XmlCursorStep, XmlCursorError] {
  if self.failure is Some(error) {
    return Err(error)
  }
  if self.budget is Some(context) && context.account.failure() is Some(error) {
    return Err(self.latch(Budget(error)))
  }
  if self.closed {
    return Err(InvalidState("XML cursor is closed"))
  }
  if self.ended {
    return Ok(End)
  }
  if self.need_input {
    return Ok(NeedInput)
  }
  self.release_returned()
  try self.pull() |> Ok catch {
    Stop(error) => Err(self.latch(error))
  }
}

///|
fn XmlCursor::count_token(self : XmlCursor) -> Unit raise XmlCursorAbort {
  if self.tokens == 9223372036854775807L {
    raise Stop(InvalidState("XML token counter overflow"))
  }
  cursor_cap(Tokens, self.tokens + 1L, self.limits.max_tokens)
  self.tokens += 1L
}

///|
fn XmlCursor::begin_text(
  self : XmlCursor,
  start : XmlCursorPosition,
) -> Unit raise XmlCursorAbort {
  if !self.run_started {
    self.count_token()
    self.run_started = true
    self.fragment_first = true
    self.fragment_start = start
    self.text_end = start
  }
}

///|
fn XmlCursor::emit_text(
  self : XmlCursor,
  cdata : Bool,
  last : Bool,
) -> XmlCursorStep raise XmlCursorAbort {
  self.max_fragment_bytes = self.max_fragment_bytes.max(
    self.text.utf8_bytes.to_int64(),
  )
  let end = if last { self.position } else { self.text_end }
  let fragment : XmlCursorText = {
    text: self.own_string(self.text.chars[:]),
    first: self.fragment_first,
    last,
    span: { start: self.fragment_start, end, },
  }
  self.text.clear()
  self.fragment_start = end
  self.fragment_first = false
  if last {
    self.run_started = false
  }
  Token(if cdata { CDataFragment(fragment) } else { TextFragment(fragment) })
}

///|
fn cursor_space(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n'
}

///|
fn XmlCursor::append_text(
  self : XmlCursor,
  ch : Char,
) -> Unit raise XmlCursorAbort {
  if self.stack.is_empty() && !cursor_space(ch) {
    self.syntax(
      InvalidToken,
      "non-whitespace text outside the document element",
    )
  }
  self.text.push(ch)
  self.text_end = self.position
}

///|
fn XmlCursor::read_data_char(
  self : XmlCursor,
  raw : Char,
  before : XmlCursorPosition,
  skip_lf : Bool,
) -> Unit raise XmlCursorAbort {
  if self.entity_start is Some(start) {
    cursor_cap(
      TokenBytes,
      self.position.utf8_byte - start.utf8_byte,
      self.limits.max_token_bytes,
    )
    if raw == ';' {
      let value = self.decode_entity(self.entity.chars[:])
      self.append_text(value)
      self.entity.clear()
      self.entity_start = None
    } else if raw == '<' || cursor_space(raw) || raw == '&' {
      self.syntax(MalformedEntity, "malformed XML entity")
    } else {
      self.entity.push(raw)
    }
    return
  }
  if raw == '<' {
    self.mode = Markup
    self.markup_start = before
    cursor_cap(TokenBytes, 1L, self.limits.max_token_bytes)
    self.max_markup_bytes = self.max_markup_bytes.max(1L)
    self.markup.push(raw)
    self.quote = None
    return
  }
  self.begin_text(before)
  if raw == '&' {
    self.entity_start = Some(before)
    return
  }
  if !skip_lf {
    self.append_text(if raw == '\r' { '\n' } else { raw })
  }
}

///|
fn XmlCursor::pull(self : XmlCursor) -> XmlCursorStep raise XmlCursorAbort {
  while true {
    if self.input_index == self.input.length() {
      if self.run_started &&
        self.text.chars.length() > 0 &&
        self.entity_start is None {
        return self.emit_text(
          self.mode is CDataBody,
          self.final_input && self.mode is Data,
        )
      }
      if self.final_input {
        if self.entity_start is Some(_) {
          self.syntax(UnexpectedEOF, "unterminated XML entity")
        }
        if !(self.mode is Data) {
          self.syntax(UnexpectedEOF, "unterminated XML markup")
        }
        if self.run_started {
          return self.emit_text(false, true)
        }
        if !self.stack.is_empty() {
          self.syntax(UnclosedTag, "unclosed XML element")
        }
        if !self.root_seen {
          self.syntax(EmptyDocument, "XML document has no element")
        }
        self.cleanup()
        self.ended = true
        return End
      }
      self.input = []
      cursor_release(self.input_lease)
      self.input_lease = None
      self.need_input = true
      return NeedInput
    }
    let raw = self.input[self.input_index]
    let before = self.position
    if self.mode is Data && self.entity_start is None && self.run_started {
      if raw == '<' {
        return self.emit_text(false, true)
      }
      let needed = if raw == '&' { 4 } else { cursor_utf8_width(raw) }
      if self.text.utf8_bytes > 0 &&
        self.text.utf8_bytes > self.limits.text_fragment_bytes - needed {
        return self.emit_text(false, false)
      }
    }
    if self.mode is CDataBody {
      let terminator = raw == '>' && self.cdata_brackets == 2
      if raw != ']' && !terminator && self.cdata_brackets > 0 {
        if self.text.utf8_bytes >
          self.limits.text_fragment_bytes - self.cdata_brackets {
          return self.emit_text(true, false)
        }
        for _ in 0..<self.cdata_brackets {
          self.text.push(']')
        }
        self.text_end = before
        self.cdata_brackets = 0
      }
      let needed = if terminator {
        0
      } else if raw == ']' {
        if self.cdata_brackets == 2 {
          1
        } else {
          0
        }
      } else {
        cursor_utf8_width(raw)
      }
      if self.text.utf8_bytes > 0 &&
        self.text.utf8_bytes > self.limits.text_fragment_bytes - needed {
        return self.emit_text(true, false)
      }
    }
    let skip_lf = raw == '\n' && self.pending_cr
    let (position, pending_cr) = cursor_advance_position(
      before,
      raw,
      self.pending_cr,
    )
    self.position = position
    self.pending_cr = pending_cr
    self.input_index += 1
    if before.scalar == 0L && raw == '\u{FEFF}' {
      continue
    }
    match self.mode {
      Data => self.read_data_char(raw, before, skip_lf)
      CDataBody =>
        if raw == ']' {
          if self.cdata_brackets == 2 {
            self.text.push(']')
            self.text_end = {
              ..self.position,
              utf8_byte: self.position.utf8_byte - 2L,
              scalar: self.position.scalar - 2L,
              utf16: self.position.utf16 - 2L,
              column: self.position.column - 2L,
            }
          } else {
            self.cdata_brackets += 1
          }
        } else if raw == '>' && self.cdata_brackets == 2 {
          self.cdata_brackets = 0
          self.mode = Data
          return self.emit_text(true, true)
        } else if !skip_lf {
          self.text.push(if raw == '\r' { '\n' } else { raw })
          self.text_end = self.position
        }
      _ =>
        match self.read_markup_char(raw) {
          Some(token) => return Token(token)
          None => ()
        }
    }
  }
  End
}
