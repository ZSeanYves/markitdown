///|
/// Parse JSON text into a source-native document model.
pub fn parse_json_document(text : String) -> JsonDocument raise {
  parse_json_document_with_profile(text, None, None)
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
fn JsonParser::skip_ws(self : JsonParser) -> Unit {
  while self.pos < self.chars.length() {
    match self.chars[self.pos] {
      ' ' | '\n' | '\r' | '\t' => self.pos += 1
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
fn JsonParser::expect_char(self : JsonParser, ch : Char) -> Unit raise {
  if self.pos >= self.chars.length() || self.chars[self.pos] != ch {
    raise ParseError("expected character")
  }
  self.pos += 1
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
fn normalize_json_chars(text : String) -> Array[Char] {
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
