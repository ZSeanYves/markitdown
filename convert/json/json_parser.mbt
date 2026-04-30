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
        'u' => {
          out.push('\\')
          out.push('u')
          for _ in 0..<4 {
            self.pos = self.pos + 1
            if self.pos >= self.chars.length() || !is_hex(self.chars[self.pos]) {
              raise @cor.AppError("json: invalid unicode escape")
            }
            out.push(self.chars[self.pos])
          }
        }
        _ => raise @cor.AppError("json: invalid escape")
      }
      self.pos = self.pos + 1
      continue
    }

    if ch == '\n' || ch == '\r' {
      raise @cor.AppError("json: raw newline in string")
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
    ()
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
