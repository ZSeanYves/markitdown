///|
priv enum JsonValue {
  Object(Array[JsonMember])
  Array(Array[JsonValue])
  String(String)
  Number(String)
  Bool(Bool)
  Null
}

///|
priv struct JsonMember {
  key : String
  value : JsonValue
}

///|
fn parse_json_text(text : String) -> JsonValue raise {
  let parser = JsonParser::{ chars: text.to_array(), pos: 0 }
  let value = parser.parse_value()
  parser.skip_ws()
  if parser.pos < parser.chars.length() {
    raise @cor.AppError("json: trailing content")
  }
  value
}

///|
priv struct JsonParser {
  chars : Array[Char]
  mut pos : Int
}

///|
fn JsonParser::parse_value(self : JsonParser) -> JsonValue raise {
  self.skip_ws()
  if self.pos >= self.chars.length() {
    raise @cor.AppError("json: unexpected end of input")
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
        raise @cor.AppError("json: unexpected character")
      }
  }
}

///|
fn JsonParser::parse_object(self : JsonParser) -> JsonValue raise {
  self.expect_char('{')
  self.skip_ws()

  let members : Array[JsonMember] = []
  if self.consume_char('}') {
    return JsonValue::Object(members)
  }

  while true {
    self.skip_ws()
    if self.pos >= self.chars.length() || self.chars[self.pos] != '"' {
      raise @cor.AppError("json: object key must be a string")
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

  JsonValue::Object(members)
}

///|
fn JsonParser::parse_array(self : JsonParser) -> JsonValue raise {
  self.expect_char('[')
  self.skip_ws()

  let values : Array[JsonValue] = []
  if self.consume_char(']') {
    return JsonValue::Array(values)
  }

  while true {
    values.push(self.parse_value())
    self.skip_ws()
    if self.consume_char(']') {
      break
    }
    self.expect_char(',')
  }

  JsonValue::Array(values)
}

///|
fn JsonParser::parse_string(self : JsonParser) -> String raise {
  self.expect_char('"')
  let out : Array[Char] = []

  while self.pos < self.chars.length() {
    let ch = self.chars[self.pos]
    if ch == '"' {
      self.pos = self.pos + 1
      return String::from_array(out)
    }

    if ch == '\\' {
      self.pos = self.pos + 1
      if self.pos >= self.chars.length() {
        raise @cor.AppError("json: unterminated escape")
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
        _ => raise @cor.AppError("json: invalid escape")
      }
      self.pos = self.pos + 1
      continue
    }

    if ch == '\n' || ch == '\r' {
      raise @cor.AppError("json: raw newline in string")
    }

    if ch.to_int() < 0x20 {
      raise @cor.AppError("json: raw control character in string")
    }

    out.push(ch)
    self.pos = self.pos + 1
  }

  raise @cor.AppError("json: unterminated string")
}

///|
fn JsonParser::parse_number(self : JsonParser) -> String raise {
  let start = self.pos

  if self.consume_char('-') {
    if self.pos >= self.chars.length() {
      raise @cor.AppError("json: invalid number")
    }
  }

  if self.consume_char('0') {
    if self.pos < self.chars.length() && is_digit(self.chars[self.pos]) {
      raise @cor.AppError("json: invalid leading zero")
    }
  } else if self.pos < self.chars.length() && is_digit_1_9(self.chars[self.pos]) {
    self.pos = self.pos + 1
    while self.pos < self.chars.length() && is_digit(self.chars[self.pos]) {
      self.pos = self.pos + 1
    }
  } else {
    raise @cor.AppError("json: invalid number")
  }

  if self.consume_char('.') {
    if self.pos >= self.chars.length() || !is_digit(self.chars[self.pos]) {
      raise @cor.AppError("json: invalid fraction")
    }
    while self.pos < self.chars.length() && is_digit(self.chars[self.pos]) {
      self.pos = self.pos + 1
    }
  }

  if self.pos < self.chars.length() &&
    (self.chars[self.pos] == 'e' || self.chars[self.pos] == 'E') {
    self.pos = self.pos + 1
    if self.pos < self.chars.length() &&
      (self.chars[self.pos] == '+' || self.chars[self.pos] == '-') {
      self.pos = self.pos + 1
    }
    if self.pos >= self.chars.length() || !is_digit(self.chars[self.pos]) {
      raise @cor.AppError("json: invalid exponent")
    }
    while self.pos < self.chars.length() && is_digit(self.chars[self.pos]) {
      self.pos = self.pos + 1
    }
  }

  @cor.slice_to_string(self.chars, start, self.pos)
}

///|
fn JsonParser::skip_ws(self : JsonParser) -> Unit {
  while self.pos < self.chars.length() {
    match self.chars[self.pos] {
      ' ' | '\n' | '\r' | '\t' => self.pos = self.pos + 1
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
      raise @cor.AppError("json: expected " + lit)
    }
  }
  self.pos = self.pos + chars.length()
}

///|
fn JsonParser::expect_char(self : JsonParser, ch : Char) -> Unit raise {
  if self.pos >= self.chars.length() || self.chars[self.pos] != ch {
    raise @cor.AppError("json: expected character")
  }
  self.pos = self.pos + 1
}

///|
fn JsonParser::consume_char(self : JsonParser, ch : Char) -> Bool {
  if self.pos < self.chars.length() && self.chars[self.pos] == ch {
    self.pos = self.pos + 1
    true
  } else {
    false
  }
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
fn JsonParser::parse_unicode_escape(
  self : JsonParser,
  out : Array[Char],
) -> Unit raise {
  let code = self.read_hex_quad()

  if is_high_surrogate(code) {
    self.pos = self.pos + 1
    if self.pos >= self.chars.length() || self.chars[self.pos] != '\\' {
      raise @cor.AppError("json: invalid unicode surrogate pair")
    }
    self.pos = self.pos + 1
    if self.pos >= self.chars.length() || self.chars[self.pos] != 'u' {
      raise @cor.AppError("json: invalid unicode surrogate pair")
    }
    let low = self.read_hex_quad()
    if !is_low_surrogate(low) {
      raise @cor.AppError("json: invalid unicode surrogate pair")
    }
    let cp = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00)
    append_codepoint(out, cp)
    return
  }

  if is_low_surrogate(code) {
    raise @cor.AppError("json: lone low surrogate")
  }

  append_codepoint(out, code)
}

///|
fn JsonParser::read_hex_quad(self : JsonParser) -> Int raise {
  let mut code = 0
  for _ in 0..<4 {
    self.pos = self.pos + 1
    if self.pos >= self.chars.length() || !is_hex(self.chars[self.pos]) {
      raise @cor.AppError("json: invalid unicode escape")
    }
    code = (code << 4) + hex_value(self.chars[self.pos])
  }
  code
}

///|
fn append_codepoint(out : Array[Char], cp : Int) -> Unit {
  if cp <= 0xFFFF {
    out.push(Int::unsafe_to_char(cp))
    return
  }

  let entity = "&#" + cp.to_string() + ";"
  for ch in @cor.decode_numeric_entities(entity).to_array() {
    out.push(ch)
  }
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
