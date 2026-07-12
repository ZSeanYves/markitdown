///|
/// Parse JSON text into a source-native document model.
pub fn parse_json_document(text : String) -> JsonDocument raise {
  parse_json_document_with_profile(text, None, None)
}

///|
/// Parse through MoonBit's rolling native JSON implementation and convert the
/// result back into the source-native model used by format readers.
pub fn parse_json_document_native(
  text : String,
  preserve_number_lexemes? : Bool = true,
) -> JsonDocument raise {
  let parsed = @corejson.parse(text) catch {
    err => raise ParseError(err.to_string())
  }
  let number_lexemes = if preserve_number_lexemes {
    json_number_lexemes(text)
  } else {
    []
  }
  let number_index : Ref[Int] = { val: 0 }
  { root: json_value_from_native(parsed, number_lexemes, number_index) }
}

///|
fn json_value_from_native(
  value : Json,
  number_lexemes : Array[String],
  number_index : Ref[Int],
) -> JsonValue {
  match value {
    Json::Object(members) => {
      let out : Array[JsonMember] = []
      for entry in members {
        out.push({
          key: entry.0,
          value: json_value_from_native(entry.1, number_lexemes, number_index),
        })
      }
      JsonValue::Object(out)
    }
    Json::Array(items) =>
      JsonValue::Array(
        items.map(item => {
          json_value_from_native(item, number_lexemes, number_index)
        }),
      )
    Json::String(text) => JsonValue::String(text)
    Json::Number(number, repr~) => {
      let text = if number_index.val < number_lexemes.length() {
        let lexeme = number_lexemes[number_index.val]
        number_index.val += 1
        lexeme
      } else {
        repr.unwrap_or(number.to_string())
      }
      JsonValue::Number(text)
    }
    Json::True => JsonValue::Bool(true)
    Json::False => JsonValue::Bool(false)
    Json::Null => JsonValue::Null
  }
}

///|
fn json_number_lexemes(text : String) -> Array[String] {
  let out : Array[String] = []
  let mut index = 0
  let mut in_string = false
  let mut escaped = false
  while index < text.length() {
    let ch = text.code_unit_at(index).to_int()
    if in_string {
      if escaped {
        escaped = false
      } else if ch == 92 {
        escaped = true
      } else if ch == 34 {
        in_string = false
      }
      index += 1
      continue
    }
    if ch == 34 {
      in_string = true
      index += 1
      continue
    }
    if ch == 45 || (ch >= 48 && ch <= 57) {
      let start = index
      index += 1
      while index < text.length() {
        let next = text.code_unit_at(index).to_int()
        if (next >= 48 && next <= 57) ||
          next == 46 ||
          next == 101 ||
          next == 69 ||
          next == 43 ||
          next == 45 {
          index += 1
        } else {
          break
        }
      }
      out.push(text[start:index].to_owned())
      continue
    }
    index += 1
  }
  out
}

///|
/// Parse JSON text into a source-native structural event stream without
/// materializing the full DOM tree.
pub fn parse_json_stream(text : String) -> JsonStreamDocument raise {
  parse_json_stream_with_pointer_policy(text, true)
}

///|
/// Validate JSON and collect structural counts without retaining token events.
/// This is used before direct lowering of large root arrays.
pub fn parse_json_stream_summary(text : String) -> JsonStreamDocument raise {
  parse_json_stream_with_policy(text, false, false)
}

///|
fn parse_json_stream_with_pointer_policy(
  text : String,
  track_pointers : Bool,
) -> JsonStreamDocument raise {
  parse_json_stream_with_policy(text, track_pointers, true)
}

///|
fn parse_json_stream_with_policy(
  text : String,
  track_pointers : Bool,
  collect_events : Bool,
) -> JsonStreamDocument raise {
  let parser = new_json_stream_parser(text, track_pointers, collect_events)
  parser.skip_ws()
  let start_depth = 1
  let root_kind = parser.parse_stream_value("/", start_depth)
  parser.skip_ws()
  if !parser.is_eof() {
    raise ParseError("trailing content")
  }
  {
    events: parser.events,
    summary: {
      token_count: parser.token_count,
      object_count: parser.object_count,
      array_count: parser.array_count,
      scalar_count: parser.scalar_count,
      max_depth: parser.max_depth,
      root_kind,
    },
  }
}

///|
/// Benchmark-oriented profiled parse helper used for internal hotspot
/// attribution.
///
/// This does not change the source-native JSON model or converter behavior.
pub fn profile_json_document(text : String) -> JsonProfiledDocument raise {
  let report = new_json_parse_profile_report()
  let totals = new_json_parse_profile_totals()
  let document = parse_json_document_with_profile(
    text,
    Some(report),
    Some(totals),
  )
  json_parse_profile_finish_totals(Some(report), Some(totals))
  { document, report }
}

///|
/// Classify a hard JSON parse failure into a stable error kind.
pub fn classify_json_error(err : JsonError) -> JsonErrorInfo {
  let detail = err.to_string().to_lower()
  let kind = if detail.contains("trailing content") {
    JsonErrorKind::TrailingContent
  } else if detail.contains("unexpected end of input") {
    JsonErrorKind::UnexpectedEnd
  } else if detail.contains("unexpected character") {
    JsonErrorKind::UnexpectedCharacter
  } else if detail.contains("object key must be a string") {
    JsonErrorKind::ObjectKeyMustBeString
  } else if detail.contains("unterminated string") {
    JsonErrorKind::UnterminatedString
  } else if detail.contains("unterminated escape") ||
    detail.contains("invalid escape") {
    JsonErrorKind::InvalidEscape
  } else if detail.contains("invalid unicode escape") {
    JsonErrorKind::InvalidUnicodeEscape
  } else if detail.contains("invalid unicode surrogate pair") ||
    detail.contains("lone low surrogate") {
    JsonErrorKind::InvalidUnicodeSurrogate
  } else if detail.contains("invalid fraction") {
    JsonErrorKind::InvalidFraction
  } else if detail.contains("invalid exponent") {
    JsonErrorKind::InvalidExponent
  } else if detail.contains("invalid number") ||
    detail.contains("invalid leading zero") {
    JsonErrorKind::InvalidNumber
  } else if detail.contains("raw newline in string") {
    JsonErrorKind::RawNewlineInString
  } else if detail.contains("raw control character in string") {
    JsonErrorKind::RawControlCharacterInString
  } else if detail.contains("expected ") ||
    detail.contains("expected character") {
    JsonErrorKind::ExpectedToken
  } else {
    JsonErrorKind::Unknown
  }
  { kind, detail: err.to_string() }
}

///|
priv struct JsonParser {
  chars : Array[Char]
  mut pos : Int
  profile_totals : JsonParseProfileTotals?
}

///|
priv struct JsonStreamParser {
  chars : Array[Char]
  mut pos : Int
  mut line : Int
  mut column : Int
  mut byte_offset : Int
  events : Array[JsonStreamEvent]
  mut token_count : Int
  mut object_count : Int
  mut array_count : Int
  mut scalar_count : Int
  mut max_depth : Int
  track_pointers : Bool
  collect_events : Bool
}

///|
fn parse_json_document_with_profile(
  text : String,
  profile : JsonParseProfileReport?,
  profile_totals : JsonParseProfileTotals?,
) -> JsonDocument raise {
  let tokenize_started = json_parse_profile_stage_started(profile)
  let chars = normalize_json_chars(text)
  match profile {
    Some(_) =>
      json_parse_profile_stage_finished(
        profile,
        "tokenize",
        tokenize_started,
        Some("chars=" + chars.length().to_string()),
      )
    None => ()
  }

  let parser = JsonParser::{ chars, pos: 0, profile_totals }
  let parse_started = json_parse_profile_stage_started(profile)
  let root = parser.parse_value()
  parser.skip_ws()
  if parser.pos < parser.chars.length() {
    raise ParseError("trailing content")
  }
  match profile {
    Some(_) =>
      json_parse_profile_stage_finished(
        profile,
        "parse_value",
        parse_started,
        Some("root=" + json_value_kind(root)),
      )
    None => ()
  }

  let build_started = json_parse_profile_stage_started(profile)
  let doc = { root, }
  match profile {
    Some(_) =>
      json_parse_profile_stage_finished(
        profile,
        "build_document",
        build_started,
        Some("root=" + json_value_kind(doc.root)),
      )
    None => ()
  }
  doc
}

///|
fn new_json_stream_parser(
  text : String,
  track_pointers : Bool,
  collect_events : Bool,
) -> JsonStreamParser {
  {
    chars: normalize_json_chars(text),
    pos: 0,
    line: 1,
    column: 1,
    byte_offset: 0,
    events: if collect_events {
      Array::new(capacity=text.length() / 8)
    } else {
      []
    },
    token_count: 0,
    object_count: 0,
    array_count: 0,
    scalar_count: 0,
    max_depth: 0,
    track_pointers,
    collect_events,
  }
}

///|
fn JsonStreamParser::parse_stream_value(
  self : JsonStreamParser,
  pointer : String,
  depth : Int,
) -> String raise {
  self.skip_ws()
  self.observe_depth(depth)
  if self.pos >= self.chars.length() {
    raise ParseError("unexpected end of input")
  }
  match self.chars[self.pos] {
    '{' => {
      self.parse_stream_object(pointer, depth)
      "object"
    }
    '[' => {
      self.parse_stream_array(pointer, depth)
      "array"
    }
    '"' => {
      let value = self.parse_string()
      self.scalar_count += 1
      self.push_scalar_event(
        JsonStreamEventKind::StringValue,
        pointer,
        depth,
        value,
      )
      "string"
    }
    't' => {
      let start = self.current_source_start()
      self.expect_literal("true")
      self.scalar_count += 1
      self.push_event(
        JsonStreamEventKind::BoolValue,
        pointer,
        depth,
        Some("true"),
        start,
      )
      "bool"
    }
    'f' => {
      let start = self.current_source_start()
      self.expect_literal("false")
      self.scalar_count += 1
      self.push_event(
        JsonStreamEventKind::BoolValue,
        pointer,
        depth,
        Some("false"),
        start,
      )
      "bool"
    }
    'n' => {
      let start = self.current_source_start()
      self.expect_literal("null")
      self.scalar_count += 1
      self.push_event(
        JsonStreamEventKind::NullValue,
        pointer,
        depth,
        Some("null"),
        start,
      )
      "null"
    }
    '-' => {
      let number = self.parse_number()
      self.scalar_count += 1
      self.push_scalar_event(
        JsonStreamEventKind::NumberValue,
        pointer,
        depth,
        number,
      )
      "number"
    }
    ch =>
      if is_digit(ch) {
        let number = self.parse_number()
        self.scalar_count += 1
        self.push_scalar_event(
          JsonStreamEventKind::NumberValue,
          pointer,
          depth,
          number,
        )
        "number"
      } else {
        raise ParseError("unexpected character")
      }
  }
}

///|
fn JsonStreamParser::parse_stream_object(
  self : JsonStreamParser,
  pointer : String,
  depth : Int,
) -> Unit raise {
  self.object_count += 1
  let start = self.current_source_start()
  self.expect_char('{')
  self.push_event(JsonStreamEventKind::ObjectStart, pointer, depth, None, start)
  self.skip_ws()
  if self.consume_char('}') {
    self.push_event(JsonStreamEventKind::ObjectEnd, pointer, depth, None, start)
    return
  }
  while true {
    self.skip_ws()
    if self.pos >= self.chars.length() || self.chars[self.pos] != '"' {
      raise ParseError("object key must be a string")
    }
    let key_start = self.current_source_start()
    let key = self.parse_string()
    let child_pointer = if self.track_pointers {
      json_stream_append_pointer(pointer, key)
    } else {
      "/"
    }
    self.push_event(
      JsonStreamEventKind::Key,
      child_pointer,
      depth + 1,
      Some(key),
      key_start,
    )
    self.skip_ws()
    self.expect_char(':')
    ignore(self.parse_stream_value(child_pointer, depth + 1))
    self.skip_ws()
    if self.consume_char('}') {
      self.push_event(
        JsonStreamEventKind::ObjectEnd,
        pointer,
        depth,
        None,
        start,
      )
      break
    }
    self.expect_char(',')
  }
}

///|
fn JsonStreamParser::parse_stream_array(
  self : JsonStreamParser,
  pointer : String,
  depth : Int,
) -> Unit raise {
  self.array_count += 1
  let start = self.current_source_start()
  self.expect_char('[')
  self.push_event(JsonStreamEventKind::ArrayStart, pointer, depth, None, start)
  self.skip_ws()
  if self.consume_char(']') {
    self.push_event(JsonStreamEventKind::ArrayEnd, pointer, depth, None, start)
    return
  }
  let mut index = 0
  while true {
    let child_pointer = if self.track_pointers {
      json_stream_append_pointer(pointer, index.to_string())
    } else {
      "/"
    }
    ignore(self.parse_stream_value(child_pointer, depth + 1))
    index += 1
    self.skip_ws()
    if self.consume_char(']') {
      self.push_event(
        JsonStreamEventKind::ArrayEnd,
        pointer,
        depth,
        None,
        start,
      )
      break
    }
    self.expect_char(',')
  }
}

///|
fn JsonStreamParser::push_scalar_event(
  self : JsonStreamParser,
  kind : JsonStreamEventKind,
  pointer : String,
  depth : Int,
  text : String,
) -> Unit {
  let end = self.current_source_end()
  let length = text.length()
  let start = {
    line: end.line,
    column: max_int(end.column - length, 1),
    byte_start: max_int(end.byte_end - length, 0),
    byte_end: max_int(end.byte_end - length, 0),
  }
  self.push_event(kind, pointer, depth, Some(text), start)
}

///|
fn JsonStreamParser::push_event(
  self : JsonStreamParser,
  kind : JsonStreamEventKind,
  pointer : String,
  depth : Int,
  text : String?,
  start : JsonStreamSource,
) -> Unit {
  self.token_count += 1
  if !self.collect_events {
    return
  }
  let end = self.current_source_end()
  self.events.push({
    kind,
    pointer,
    depth,
    text,
    source: {
      line: start.line,
      column: start.column,
      byte_start: start.byte_start,
      byte_end: end.byte_end,
    },
  })
}

///|
fn JsonStreamParser::observe_depth(
  self : JsonStreamParser,
  depth : Int,
) -> Unit {
  if depth > self.max_depth {
    self.max_depth = depth
  }
}

///|
fn JsonStreamParser::current_source_start(
  self : JsonStreamParser,
) -> JsonStreamSource {
  {
    line: self.line,
    column: self.column,
    byte_start: self.byte_offset,
    byte_end: self.byte_offset,
  }
}

///|
fn JsonStreamParser::current_source_end(
  self : JsonStreamParser,
) -> JsonStreamSource {
  {
    line: self.line,
    column: self.column,
    byte_start: self.byte_offset,
    byte_end: self.byte_offset,
  }
}

///|
fn JsonStreamParser::is_eof(self : JsonStreamParser) -> Bool {
  self.pos >= self.chars.length()
}

///|
fn JsonStreamParser::advance_char(self : JsonStreamParser) -> Char {
  let ch = self.chars[self.pos]
  self.pos += 1
  self.byte_offset += 1
  if ch == '\n' {
    self.line += 1
    self.column = 1
  } else {
    self.column += 1
  }
  ch
}

///|
fn JsonParser::parse_value(self : JsonParser) -> JsonValue raise {
  self.skip_ws()
  if self.pos >= self.chars.length() {
    raise ParseError("unexpected end of input")
  }

  match self.chars[self.pos] {
    '{' => self.parse_object()
    '[' => self.parse_array()
    '"' => JsonValue::String(self.parse_string())
    't' => {
      self.expect_literal("true")
      JsonValue::Bool(true)
    }
    'f' => {
      self.expect_literal("false")
      JsonValue::Bool(false)
    }
    'n' => {
      self.expect_literal("null")
      JsonValue::Null
    }
    '-' => JsonValue::Number(self.parse_number())
    c =>
      if is_digit(c) {
        JsonValue::Number(self.parse_number())
      } else {
        raise ParseError("unexpected character")
      }
  }
}

///|
fn JsonParser::parse_object(self : JsonParser) -> JsonValue raise {
  let started = match self.profile_totals {
    Some(_) => @env.now()
    None => 0
  }
  let total = match self.profile_totals {
    Some(totals) => Some(totals.parse_object_elapsed_ms)
    None => None
  }
  self.expect_char('{')
  self.skip_ws()

  let members : Array[JsonMember] = []
  if self.consume_char('}') {
    let value = JsonValue::Object(members)
    json_parse_profile_add_elapsed(total, started)
    return value
  }

  while true {
    self.skip_ws()
    if self.pos >= self.chars.length() || self.chars[self.pos] != '"' {
      raise ParseError("object key must be a string")
    }
    let key = self.parse_string()

    self.skip_ws()
    self.expect_char(':')

    let value = self.parse_value()
    members.push({ key, value })

    self.skip_ws()
    if self.consume_char('}') {
      break
    }
    self.expect_char(',')
  }

  let value = JsonValue::Object(members)
  json_parse_profile_add_elapsed(total, started)
  value
}

///|
fn JsonParser::parse_array(self : JsonParser) -> JsonValue raise {
  let started = match self.profile_totals {
    Some(_) => @env.now()
    None => 0
  }
  let total = match self.profile_totals {
    Some(totals) => Some(totals.parse_array_elapsed_ms)
    None => None
  }
  self.expect_char('[')
  self.skip_ws()

  let values : Array[JsonValue] = []
  if self.consume_char(']') {
    let value = JsonValue::Array(values)
    json_parse_profile_add_elapsed(total, started)
    return value
  }

  while true {
    values.push(self.parse_value())
    self.skip_ws()
    if self.consume_char(']') {
      break
    }
    self.expect_char(',')
  }

  let value = JsonValue::Array(values)
  json_parse_profile_add_elapsed(total, started)
  value
}

///|
fn JsonParser::parse_string(self : JsonParser) -> String raise {
  let started = match self.profile_totals {
    Some(_) => @env.now()
    None => 0
  }
  let total = match self.profile_totals {
    Some(totals) => Some(totals.parse_string_elapsed_ms)
    None => None
  }
  self.expect_char('"')
  let plain_start = self.pos
  while self.pos < self.chars.length() {
    let ch = self.chars[self.pos]
    if ch == '"' {
      let value = slice_chars_to_string(self.chars, plain_start, self.pos)
      self.pos += 1
      json_parse_profile_add_elapsed(total, started)
      return value
    }
    if ch == '\\' || ch == '\n' || ch == '\r' || ch.to_int() < 0x20 {
      break
    }
    self.pos += 1
  }

  let out : Array[Char] = if self.pos > plain_start {
    self.chars[plain_start:self.pos].to_owned()
  } else {
    []
  }

  while self.pos < self.chars.length() {
    let ch = self.chars[self.pos]
    if ch == '"' {
      self.pos += 1
      let value = String::from_array(out)
      json_parse_profile_add_elapsed(total, started)
      return value
    }

    if ch == '\\' {
      self.pos += 1
      if self.pos >= self.chars.length() {
        raise ParseError("unterminated escape")
      }
      let esc = self.chars[self.pos]
      match esc {
        '"' => out.push('"')
        '\\' => out.push('\\')
        '/' => out.push('/')
        'b' => out.push('\b')
        'f' => out.push('\u{000C}')
        'n' => out.push('\n')
        'r' => out.push('\r')
        't' => out.push('\t')
        'u' => self.parse_unicode_escape(out)
        _ => raise ParseError("invalid escape")
      }
      self.pos += 1
      continue
    }

    if ch == '\n' || ch == '\r' {
      raise ParseError("raw newline in string")
    }

    if ch.to_int() < 0x20 {
      raise ParseError("raw control character in string")
    }

    out.push(ch)
    self.pos += 1
  }

  json_parse_profile_add_elapsed(total, started)
  raise ParseError("unterminated string")
}

///|
fn JsonStreamParser::parse_string(self : JsonStreamParser) -> String raise {
  self.expect_char('"')
  let out : Array[Char] = []
  while self.pos < self.chars.length() {
    let ch = self.chars[self.pos]
    if ch == '"' {
      ignore(self.advance_char())
      return String::from_array(out)
    }

    if ch == '\\' {
      ignore(self.advance_char())
      if self.pos >= self.chars.length() {
        raise ParseError("unterminated escape")
      }
      let esc = self.chars[self.pos]
      match esc {
        '"' => {
          out.push('"')
          ignore(self.advance_char())
        }
        '\\' => {
          out.push('\\')
          ignore(self.advance_char())
        }
        '/' => {
          out.push('/')
          ignore(self.advance_char())
        }
        'b' => {
          out.push('\b')
          ignore(self.advance_char())
        }
        'f' => {
          out.push('\u{000C}')
          ignore(self.advance_char())
        }
        'n' => {
          out.push('\n')
          ignore(self.advance_char())
        }
        'r' => {
          out.push('\r')
          ignore(self.advance_char())
        }
        't' => {
          out.push('\t')
          ignore(self.advance_char())
        }
        'u' => {
          ignore(self.advance_char())
          self.parse_unicode_escape(out)
        }
        _ => raise ParseError("invalid escape")
      }
      continue
    }

    if ch == '\n' || ch == '\r' {
      raise ParseError("raw newline in string")
    }
    if ch.to_int() < 0x20 {
      raise ParseError("raw control character in string")
    }
    out.push(ch)
    ignore(self.advance_char())
  }
  raise ParseError("unterminated string")
}

///|
fn JsonParser::parse_number(self : JsonParser) -> String raise {
  let started = match self.profile_totals {
    Some(_) => @env.now()
    None => 0
  }
  let total = match self.profile_totals {
    Some(totals) => Some(totals.parse_number_elapsed_ms)
    None => None
  }
  let start = self.pos

  if self.consume_char('-') && self.pos >= self.chars.length() {
    raise ParseError("invalid number")
  }

  if self.consume_char('0') {
    if self.pos < self.chars.length() && is_digit(self.chars[self.pos]) {
      raise ParseError("invalid leading zero")
    }
  } else if self.pos < self.chars.length() && is_digit_1_9(self.chars[self.pos]) {
    self.pos += 1
    while self.pos < self.chars.length() && is_digit(self.chars[self.pos]) {
      self.pos += 1
    }
  } else {
    raise ParseError("invalid number")
  }

  if self.consume_char('.') {
    if self.pos >= self.chars.length() || !is_digit(self.chars[self.pos]) {
      raise ParseError("invalid fraction")
    }
    while self.pos < self.chars.length() && is_digit(self.chars[self.pos]) {
      self.pos += 1
    }
  }

  if self.pos < self.chars.length() &&
    (self.chars[self.pos] == 'e' || self.chars[self.pos] == 'E') {
    self.pos += 1
    if self.pos < self.chars.length() &&
      (self.chars[self.pos] == '+' || self.chars[self.pos] == '-') {
      self.pos += 1
    }
    if self.pos >= self.chars.length() || !is_digit(self.chars[self.pos]) {
      raise ParseError("invalid exponent")
    }
    while self.pos < self.chars.length() && is_digit(self.chars[self.pos]) {
      self.pos += 1
    }
  }

  let value = slice_chars_to_string(self.chars, start, self.pos)
  json_parse_profile_add_elapsed(total, started)
  value
}

///|
fn JsonStreamParser::parse_number(self : JsonStreamParser) -> String raise {
  let start = self.pos

  if self.consume_char('-') && self.pos >= self.chars.length() {
    raise ParseError("invalid number")
  }

  if self.consume_char('0') {
    if self.pos < self.chars.length() && is_digit(self.chars[self.pos]) {
      raise ParseError("invalid leading zero")
    }
  } else if self.pos < self.chars.length() && is_digit_1_9(self.chars[self.pos]) {
    while self.pos < self.chars.length() && is_digit(self.chars[self.pos]) {
      ignore(self.advance_char())
    }
  } else {
    raise ParseError("invalid number")
  }

  if self.consume_char('.') {
    if self.pos >= self.chars.length() || !is_digit(self.chars[self.pos]) {
      raise ParseError("invalid fraction")
    }
    while self.pos < self.chars.length() && is_digit(self.chars[self.pos]) {
      ignore(self.advance_char())
    }
  }

  if self.pos < self.chars.length() &&
    (self.chars[self.pos] == 'e' || self.chars[self.pos] == 'E') {
    ignore(self.advance_char())
    if self.pos < self.chars.length() &&
      (self.chars[self.pos] == '+' || self.chars[self.pos] == '-') {
      ignore(self.advance_char())
    }
    if self.pos >= self.chars.length() || !is_digit(self.chars[self.pos]) {
      raise ParseError("invalid exponent")
    }
    while self.pos < self.chars.length() && is_digit(self.chars[self.pos]) {
      ignore(self.advance_char())
    }
  }

  slice_chars_to_string(self.chars, start, self.pos)
}

///|
fn JsonParser::skip_ws(self : JsonParser) -> Unit {
  while self.pos < self.chars.length() {
    match self.chars[self.pos] {
      ' ' | '\n' | '\r' | '\t' => self.pos += 1
      _ => return
    }
  }
}

///|
fn JsonStreamParser::skip_ws(self : JsonStreamParser) -> Unit {
  while self.pos < self.chars.length() {
    match self.chars[self.pos] {
      ' ' | '\t' => ignore(self.advance_char())
      '\n' | '\r' => ignore(self.advance_char())
      _ => return
    }
  }
}

///|
fn JsonParser::expect_literal(self : JsonParser, lit : String) -> Unit raise {
  let chars = lit.to_array()
  for i in 0..<chars.length() {
    if self.pos + i >= self.chars.length() ||
      self.chars[self.pos + i] != chars[i] {
      raise ParseError("expected " + lit)
    }
  }
  self.pos += chars.length()
}

///|
fn JsonStreamParser::expect_literal(
  self : JsonStreamParser,
  lit : String,
) -> Unit raise {
  let chars = lit.to_array()
  for i in 0..<chars.length() {
    if self.pos + i >= self.chars.length() ||
      self.chars[self.pos + i] != chars[i] {
      raise ParseError("expected " + lit)
    }
  }
  for _ in 0..<chars.length() {
    ignore(self.advance_char())
  }
}

///|
fn JsonParser::expect_char(self : JsonParser, ch : Char) -> Unit raise {
  if self.pos >= self.chars.length() || self.chars[self.pos] != ch {
    raise ParseError("expected character")
  }
  self.pos += 1
}

///|
fn JsonStreamParser::expect_char(
  self : JsonStreamParser,
  ch : Char,
) -> Unit raise {
  if self.pos >= self.chars.length() || self.chars[self.pos] != ch {
    raise ParseError("expected character")
  }
  ignore(self.advance_char())
}

///|
fn JsonParser::consume_char(self : JsonParser, ch : Char) -> Bool {
  if self.pos < self.chars.length() && self.chars[self.pos] == ch {
    self.pos += 1
    true
  } else {
    false
  }
}

///|
fn JsonStreamParser::consume_char(self : JsonStreamParser, ch : Char) -> Bool {
  if self.pos < self.chars.length() && self.chars[self.pos] == ch {
    ignore(self.advance_char())
    true
  } else {
    false
  }
}

///|
fn JsonParser::parse_unicode_escape(
  self : JsonParser,
  out : Array[Char],
) -> Unit raise {
  let code = self.read_hex_quad()

  if is_high_surrogate(code) {
    self.pos += 1
    if self.pos >= self.chars.length() || self.chars[self.pos] != '\\' {
      raise ParseError("invalid unicode surrogate pair")
    }
    self.pos += 1
    if self.pos >= self.chars.length() || self.chars[self.pos] != 'u' {
      raise ParseError("invalid unicode surrogate pair")
    }
    let low = self.read_hex_quad()
    if !is_low_surrogate(low) {
      raise ParseError("invalid unicode surrogate pair")
    }
    let cp = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00)
    out.push(Int::unsafe_to_char(cp))
    return
  }

  if is_low_surrogate(code) {
    raise ParseError("lone low surrogate")
  }

  out.push(Int::unsafe_to_char(code))
}

///|
fn JsonStreamParser::parse_unicode_escape(
  self : JsonStreamParser,
  out : Array[Char],
) -> Unit raise {
  let code = self.read_hex_quad()

  if is_high_surrogate(code) {
    if self.pos >= self.chars.length() || self.chars[self.pos] != '\\' {
      raise ParseError("invalid unicode surrogate pair")
    }
    ignore(self.advance_char())
    if self.pos >= self.chars.length() || self.chars[self.pos] != 'u' {
      raise ParseError("invalid unicode surrogate pair")
    }
    ignore(self.advance_char())
    let low = self.read_hex_quad()
    if !is_low_surrogate(low) {
      raise ParseError("invalid unicode surrogate pair")
    }
    let cp = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00)
    out.push(Int::unsafe_to_char(cp))
    return
  }

  if is_low_surrogate(code) {
    raise ParseError("lone low surrogate")
  }

  out.push(Int::unsafe_to_char(code))
}

///|
fn JsonParser::read_hex_quad(self : JsonParser) -> Int raise {
  let mut code = 0
  for _ in 0..<4 {
    self.pos += 1
    if self.pos >= self.chars.length() || !is_hex(self.chars[self.pos]) {
      raise ParseError("invalid unicode escape")
    }
    code = (code << 4) + hex_value(self.chars[self.pos])
  }
  code
}

///|
fn JsonStreamParser::read_hex_quad(self : JsonStreamParser) -> Int raise {
  let mut code = 0
  for _ in 0..<4 {
    if self.pos >= self.chars.length() || !is_hex(self.chars[self.pos]) {
      raise ParseError("invalid unicode escape")
    }
    code = (code << 4) + hex_value(self.chars[self.pos])
    ignore(self.advance_char())
  }
  code
}

///|
fn normalize_json_chars(text : String) -> Array[Char] {
  if !text.has_prefix("\u{FEFF}") && !text.contains("\r") {
    return text.to_array()
  }
  let out : Array[Char] = []
  let chars = text.to_array()
  let mut i = 0

  if chars.length() > 0 && chars[0] == '\u{FEFF}' {
    i = 1
  }

  while i < chars.length() {
    if chars[i] == '\r' {
      out.push('\n')
      if i + 1 < chars.length() && chars[i + 1] == '\n' {
        i += 2
      } else {
        i += 1
      }
    } else {
      out.push(chars[i])
      i += 1
    }
  }

  out
}

///|
fn slice_chars_to_string(
  chars : Array[Char],
  start : Int,
  end_ : Int,
) -> String {
  String::from_array(chars[start:end_].to_owned())
}

///|
fn is_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn is_digit_1_9(ch : Char) -> Bool {
  ch >= '1' && ch <= '9'
}

///|
fn is_hex(ch : Char) -> Bool {
  (ch >= '0' && ch <= '9') ||
  (ch >= 'a' && ch <= 'f') ||
  (ch >= 'A' && ch <= 'F')
}

///|
fn is_high_surrogate(code : Int) -> Bool {
  code >= 0xD800 && code <= 0xDBFF
}

///|
fn is_low_surrogate(code : Int) -> Bool {
  code >= 0xDC00 && code <= 0xDFFF
}

///|
fn hex_value(ch : Char) -> Int {
  if ch >= '0' && ch <= '9' {
    return ch.to_int() - '0'.to_int()
  }
  if ch >= 'a' && ch <= 'f' {
    return 10 + ch.to_int() - 'a'.to_int()
  }
  10 + ch.to_int() - 'A'.to_int()
}

///|
/// Return a stable human-readable kind label for a parsed JSON value.
pub fn json_value_kind(value : JsonValue) -> String {
  match value {
    JsonValue::Object(_) => "object"
    JsonValue::Array(_) => "array"
    JsonValue::String(_) => "string"
    JsonValue::Number(_) => "number"
    JsonValue::Bool(_) => "bool"
    JsonValue::Null => "null"
  }
}

///|
fn json_stream_append_pointer(pointer : String, segment : String) -> String {
  let escaped = segment.replace(old="~", new="~0").replace(old="/", new="~1")
  if pointer == "/" {
    "/" + escaped
  } else {
    pointer + "/" + escaped
  }
}

///|
fn max_int(left : Int, right : Int) -> Int {
  if left > right {
    left
  } else {
    right
  }
}
