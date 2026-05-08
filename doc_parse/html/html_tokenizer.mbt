///|
/// Tokenize HTML source into raw tolerant HTML tokens.
pub fn tokenize_html_document(text : String) -> Array[HtmlToken] raise {
  let normalized = normalize_html_source(text)
  let tokenizer = HtmlTokenizer::{
    chars: normalized.to_array(),
    pos: 0,
    line: 1,
  }
  tokenizer.parse_tokens()
}

///|
priv struct HtmlTokenizer {
  chars : Array[Char]
  mut pos : Int
  mut line : Int
}

///|
fn HtmlTokenizer::parse_tokens(self : HtmlTokenizer) -> Array[HtmlToken] raise {
  let out : Array[HtmlToken] = []

  while self.pos < self.chars.length() {
    let start_line = self.line
    if self.chars[self.pos] == '<' {
      if self.starts_with("<!--") {
        out.push(
          HtmlToken::Comment(self.read_comment(), {
            line_start: start_line,
            line_end: self.line,
          }),
        )
      } else if self.starts_with("</") && self.has_end_tag_name() {
        out.push(
          HtmlToken::EndTag(self.read_end_tag(), {
            line_start: start_line,
            line_end: self.line,
          }),
        )
      } else if self.starts_with_case_insensitive("<!doctype") {
        out.push(
          HtmlToken::Doctype(self.read_doctype_like(), {
            line_start: start_line,
            line_end: self.line,
          }),
        )
      } else if self.pos + 1 < self.chars.length() &&
        is_html_name_start(self.chars[self.pos + 1]) {
        let (name, attrs, self_closing) = self.read_start_tag()
        out.push(
          HtmlToken::StartTag(name, attrs, self_closing, {
            line_start: start_line,
            line_end: self.line,
          }),
        )
        if is_html_raw_text_tag(name) {
          let raw_start = self.line
          let raw_text = self.read_raw_text_body(name)
          if raw_text != "" {
            out.push(
              HtmlToken::Text(raw_text, {
                line_start: raw_start,
                line_end: self.line,
              }),
            )
          }
          let close_start = self.line
          if self.consume_case_insensitive("</" + name) {
            self.skip_spaces()
            self.expect_char('>', "unterminated raw-text closing tag")
            out.push(
              HtmlToken::EndTag(name, {
                line_start: close_start,
                line_end: self.line,
              }),
            )
          }
        }
      } else {
        out.push(
          HtmlToken::Text("<", { line_start: start_line, line_end: start_line }),
        )
        self.pos += 1
      }
    } else {
      let text_node = self.read_text()
      if text_node != "" {
        out.push(
          HtmlToken::Text(text_node, {
            line_start: start_line,
            line_end: self.line,
          }),
        )
      }
    }
  }

  out
}

///|
fn HtmlTokenizer::has_end_tag_name(self : HtmlTokenizer) -> Bool {
  if self.pos + 2 >= self.chars.length() {
    return false
  }
  let mut i = self.pos + 2
  while i < self.chars.length() {
    match self.chars[i] {
      ' ' | '\t' | '\n' | '\r' => i += 1
      ch => return is_html_name_start(ch)
    }
  }
  false
}

///|
fn HtmlTokenizer::starts_with(self : HtmlTokenizer, prefix : String) -> Bool {
  let chars = prefix.to_array()
  if self.pos + chars.length() > self.chars.length() {
    return false
  }
  for i in 0..<chars.length() {
    if self.chars[self.pos + i] != chars[i] {
      return false
    }
  }
  true
}

///|
fn HtmlTokenizer::starts_with_case_insensitive(
  self : HtmlTokenizer,
  prefix : String,
) -> Bool {
  let chars = prefix.to_lower().to_array()
  if self.pos + chars.length() > self.chars.length() {
    return false
  }
  for i in 0..<chars.length() {
    if lower_ascii_html_char(self.chars[self.pos + i]) != chars[i] {
      return false
    }
  }
  true
}

///|
fn HtmlTokenizer::consume_case_insensitive(
  self : HtmlTokenizer,
  prefix : String,
) -> Bool {
  if !self.starts_with_case_insensitive(prefix) {
    return false
  }
  self.advance_chars(prefix.length())
  true
}

///|
fn HtmlTokenizer::read_comment(self : HtmlTokenizer) -> String raise {
  self.advance_chars("<!--".length())
  let out : Array[Char] = []
  while self.pos < self.chars.length() {
    if self.starts_with("-->") {
      self.advance_chars(3)
      return String::from_array(out)
    }
    let ch = self.chars[self.pos]
    if ch == '\n' {
      self.line += 1
    }
    out.push(ch)
    self.pos += 1
  }
  raise ParseError("unterminated comment")
}

///|
fn HtmlTokenizer::read_doctype_like(self : HtmlTokenizer) -> String raise {
  self.expect_char('<', "malformed doctype")
  self.expect_char('!', "malformed doctype")
  let out : Array[Char] = []
  while self.pos < self.chars.length() {
    let ch = self.chars[self.pos]
    if ch == '>' {
      self.pos += 1
      return String::from_array(out).trim().to_owned()
    }
    if ch == '\n' {
      self.line += 1
    }
    out.push(ch)
    self.pos += 1
  }
  raise ParseError("unterminated doctype or declaration")
}

///|
fn HtmlTokenizer::read_end_tag(self : HtmlTokenizer) -> String raise {
  self.expect_char('<', "malformed end tag")
  self.expect_char('/', "malformed end tag")
  self.skip_spaces()
  let name = self.read_name()
  self.skip_spaces()
  self.expect_char('>', "unterminated end tag")
  name
}

///|
fn HtmlTokenizer::read_start_tag(
  self : HtmlTokenizer,
) -> (String, Array[HtmlAttribute], Bool) raise {
  self.expect_char('<', "malformed start tag")
  let name = self.read_name()
  let attrs : Array[HtmlAttribute] = []

  while self.pos < self.chars.length() {
    self.skip_spaces()
    if self.pos >= self.chars.length() {
      raise ParseError("unterminated start tag")
    }

    if self.chars[self.pos] == '>' {
      self.pos += 1
      return (name, attrs, false)
    }

    if self.chars[self.pos] == '/' {
      self.pos += 1
      self.expect_char('>', "unterminated self-closing tag")
      return (name, attrs, true)
    }

    let attr_start = self.line
    let attr_name = self.read_name()
    self.skip_spaces()
    let mut value = ""
    let mut quote_style = HtmlAttributeQuoteStyle::Unquoted

    if self.pos < self.chars.length() && self.chars[self.pos] == '=' {
      self.pos += 1
      self.skip_spaces()
      let parsed = self.read_attribute_value()
      value = parsed.0
      quote_style = parsed.1
    }

    attrs.push({
      name: attr_name,
      value,
      quote_style,
      span: { line_start: attr_start, line_end: self.line },
    })
  }

  raise ParseError("unterminated start tag")
}

///|
fn HtmlTokenizer::read_attribute_value(
  self : HtmlTokenizer,
) -> (String, HtmlAttributeQuoteStyle) raise {
  if self.pos >= self.chars.length() {
    raise ParseError("missing attribute value")
  }

  let quote = self.chars[self.pos]
  if quote == '"' || quote == '\'' {
    self.pos += 1
    let out : Array[Char] = []
    while self.pos < self.chars.length() {
      let ch = self.chars[self.pos]
      if ch == '\n' {
        self.line += 1
      }
      if ch == quote {
        self.pos += 1
        return (
          decode_html_entities(String::from_array(out)),
          if quote == '"' {
            HtmlAttributeQuoteStyle::DoubleQuoted
          } else {
            HtmlAttributeQuoteStyle::SingleQuoted
          },
        )
      }
      out.push(ch)
      self.pos += 1
    }
    raise ParseError("unterminated attribute value")
  }

  let out : Array[Char] = []
  while self.pos < self.chars.length() {
    let ch = self.chars[self.pos]
    if ch == ' ' ||
      ch == '\t' ||
      ch == '\n' ||
      ch == '\r' ||
      ch == '>' ||
      ch == '/' {
      break
    }
    out.push(ch)
    self.pos += 1
  }

  if out.length() == 0 {
    raise ParseError("malformed attribute")
  }

  (
    decode_html_entities(String::from_array(out)),
    HtmlAttributeQuoteStyle::Unquoted,
  )
}

///|
fn HtmlTokenizer::read_text(self : HtmlTokenizer) -> String {
  let out : Array[Char] = []
  while self.pos < self.chars.length() && self.chars[self.pos] != '<' {
    let ch = self.chars[self.pos]
    if ch == '\n' {
      self.line += 1
    }
    out.push(ch)
    self.pos += 1
  }
  decode_html_entities(String::from_array(out))
}

///|
fn HtmlTokenizer::read_raw_text_body(
  self : HtmlTokenizer,
  tag_name : String,
) -> String {
  let out : Array[Char] = []
  while self.pos < self.chars.length() {
    if self.starts_with_case_insensitive("</" + tag_name) {
      break
    }
    let ch = self.chars[self.pos]
    if ch == '\n' {
      self.line += 1
    }
    out.push(ch)
    self.pos += 1
  }
  String::from_array(out)
}

///|
fn HtmlTokenizer::read_name(self : HtmlTokenizer) -> String raise {
  if self.pos >= self.chars.length() ||
    !is_html_name_start(self.chars[self.pos]) {
    raise ParseError("expected name")
  }
  let out : Array[Char] = []
  out.push(lower_ascii_html_char(self.chars[self.pos]))
  self.pos += 1
  while self.pos < self.chars.length() &&
        is_html_name_char(self.chars[self.pos]) {
    out.push(lower_ascii_html_char(self.chars[self.pos]))
    self.pos += 1
  }
  String::from_array(out)
}

///|
fn HtmlTokenizer::skip_spaces(self : HtmlTokenizer) -> Unit {
  while self.pos < self.chars.length() {
    let ch = self.chars[self.pos]
    match ch {
      ' ' | '\t' => self.pos += 1
      '\r' => self.pos += 1
      '\n' => {
        self.line += 1
        self.pos += 1
      }
      _ => return
    }
  }
}

///|
fn HtmlTokenizer::advance_chars(self : HtmlTokenizer, count : Int) -> Unit {
  for _ in 0..<count {
    if self.pos >= self.chars.length() {
      return
    }
    if self.chars[self.pos] == '\n' {
      self.line += 1
    }
    self.pos += 1
  }
}

///|
fn HtmlTokenizer::expect_char(
  self : HtmlTokenizer,
  ch : Char,
  err : String,
) -> Unit raise {
  if self.pos >= self.chars.length() || self.chars[self.pos] != ch {
    raise ParseError(err)
  }
  self.pos += 1
}

///|
fn normalize_html_source(text : String) -> String {
  let chars = text.to_array()
  let out : Array[Char] = []
  let mut i = 0

  if chars.length() > 0 && chars[0] == '\u{FEFF}' {
    i = 1
  }

  while i < chars.length() {
    let ch = chars[i]
    if ch == '\r' {
      out.push('\n')
      if i + 1 < chars.length() && chars[i + 1] == '\n' {
        i += 2
      } else {
        i += 1
      }
    } else {
      out.push(ch)
      i += 1
    }
  }

  String::from_array(out)
}

///|
fn decode_html_entities(text : String) -> String {
  let chars = text.to_array()
  let out : Array[Char] = []
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '&' {
      let mut j = i + 1
      while j < chars.length() && chars[j] != ';' && j - i <= 32 {
        j += 1
      }
      if j < chars.length() && chars[j] == ';' {
        let body = slice_chars(chars, i + 1, j)
        match decode_html_entity_body(body) {
          Some(decoded) => {
            append_chars(out, decoded)
            i = j + 1
            continue
          }
          None => ()
        }
      }
    }
    out.push(chars[i])
    i += 1
  }
  String::from_array(out)
}

///|
fn decode_html_entity_body(body : String) -> String? {
  match body {
    "amp" => Some("&")
    "lt" => Some("<")
    "gt" => Some(">")
    "quot" => Some("\"")
    "apos" => Some("'")
    "nbsp" => Some(" ")
    _ =>
      if body.has_prefix("#x") || body.has_prefix("#X") {
        parse_html_hex_int(body[2:].to_owned()).map(fn(cp) {
          String::from_array([Int::unsafe_to_char(cp)])
        })
      } else if body.has_prefix("#") {
        parse_html_dec_int(body[1:].to_owned()).map(fn(cp) {
          String::from_array([Int::unsafe_to_char(cp)])
        })
      } else {
        None
      }
  }
}

///|
fn parse_html_dec_int(s : String) -> Int? {
  if s == "" {
    return None
  }
  let chars = s.to_array()
  let mut i = 0
  let mut acc = 0
  while i < chars.length() {
    let c = chars[i]
    if c >= '0' && c <= '9' {
      acc = acc * 10 + (c.to_int() - '0'.to_int())
      i += 1
    } else {
      return None
    }
  }
  Some(acc)
}

///|
fn parse_html_hex_int(s : String) -> Int? {
  if s == "" {
    return None
  }
  let chars = s.to_array()
  let mut i = 0
  let mut acc = 0
  while i < chars.length() {
    match html_hex_val(chars[i]) {
      Some(v) => {
        acc = (acc << 4) | v
        i += 1
      }
      None => return None
    }
  }
  Some(acc)
}

///|
fn html_hex_val(c : Char) -> Int? {
  if c >= '0' && c <= '9' {
    Some(c.to_int() - '0'.to_int())
  } else if c >= 'a' && c <= 'f' {
    Some(c.to_int() - 'a'.to_int() + 10)
  } else if c >= 'A' && c <= 'F' {
    Some(c.to_int() - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
fn slice_chars(chars : Array[Char], start : Int, end_ : Int) -> String {
  let out : Array[Char] = []
  let mut i = start
  while i < end_ {
    out.push(chars[i])
    i += 1
  }
  String::from_array(out)
}

///|
fn append_chars(out : Array[Char], text : String) -> Unit {
  for ch in text.to_array() {
    out.push(ch)
  }
}

///|
fn is_html_name_start(ch : Char) -> Bool {
  (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')
}

///|
fn is_html_name_char(ch : Char) -> Bool {
  is_html_name_start(ch) ||
  (ch >= '0' && ch <= '9') ||
  ch == '-' ||
  ch == ':' ||
  ch == '_'
}

///|
fn lower_ascii_html_char(ch : Char) -> Char {
  if ch >= 'A' && ch <= 'Z' {
    Int::unsafe_to_char(ch.to_int() + ('a'.to_int() - 'A'.to_int()))
  } else {
    ch
  }
}

///|
fn is_html_raw_text_tag(tag_name : String) -> Bool {
  tag_name == "script" ||
  tag_name == "style" ||
  tag_name == "textarea" ||
  tag_name == "title"
}
