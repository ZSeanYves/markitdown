///|
/// Tokenize XML source into raw safe XML tokens.
pub fn tokenize_xml_document(text : String) -> Array[XmlToken] raise {
  let normalized = normalize_xml_source(text)
  let tokenizer = XmlTokenizer::{
    chars: normalized.to_array(),
    pos: 0,
    line: 1,
    stack: [],
  }
  tokenizer.parse_tokens()
}

///|
priv struct XmlTokenizer {
  chars : Array[Char]
  mut pos : Int
  mut line : Int
  stack : Array[String]
}

///|
fn XmlTokenizer::parse_tokens(self : XmlTokenizer) -> Array[XmlToken] raise {
  let out : Array[XmlToken] = []

  while self.pos < self.chars.length() {
    let start_line = self.line
    if self.chars[self.pos] == '<' {
      if self.starts_with("<?xml ") ||
        self.starts_with("<?xml\n") ||
        self.starts_with("<?xml\r") ||
        self.starts_with("<?xml\t") ||
        self.starts_with("<?xml?>") {
        out.push(
          XmlToken::Declaration(self.read_declaration(), {
            line_start: start_line,
            line_end: self.line,
          }),
        )
      } else if self.starts_with("<?") {
        let (name, body) = self.read_processing_instruction()
        out.push(
          XmlToken::ProcessingInstruction(name, body, {
            line_start: start_line,
            line_end: self.line,
          }),
        )
      } else if self.starts_with("<!--") {
        out.push(
          XmlToken::Comment(self.read_comment(), {
            line_start: start_line,
            line_end: self.line,
          }),
        )
      } else if self.starts_with("<![CDATA[") {
        out.push(
          XmlToken::CData(self.read_cdata(), {
            line_start: start_line,
            line_end: self.line,
          }),
        )
      } else if self.starts_with("<!DOCTYPE") {
        out.push(
          XmlToken::Doctype(self.read_doctype(), {
            line_start: start_line,
            line_end: self.line,
          }),
        )
      } else if self.starts_with("</") {
        let name = self.read_end_tag()
        self.pop_expected_tag(name)
        out.push(
          XmlToken::EndTag(name, { line_start: start_line, line_end: self.line }),
        )
      } else if self.starts_with("<!") {
        raise ParseError("unsupported declaration-like syntax")
      } else {
        let (name, attrs, empty) = self.read_start_like_tag()
        if empty {
          out.push(
            XmlToken::StartTag(name, attrs, true, {
              line_start: start_line,
              line_end: self.line,
            }),
          )
        } else {
          self.stack.push(name)
          out.push(
            XmlToken::StartTag(name, attrs, false, {
              line_start: start_line,
              line_end: self.line,
            }),
          )
        }
      }
    } else {
      let text = self.read_text()
      if text != "" {
        out.push(
          XmlToken::Text(text, { line_start: start_line, line_end: self.line }),
        )
      }
    }
  }

  if self.stack.length() > 0 {
    raise ParseError("unclosed tag: " + self.stack[self.stack.length() - 1])
  }

  out
}

///|
fn XmlTokenizer::starts_with(self : XmlTokenizer, prefix : String) -> Bool {
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
fn XmlTokenizer::pop_expected_tag(
  self : XmlTokenizer,
  expected : String,
) -> Unit raise {
  match self.stack.pop() {
    Some(actual) =>
      if actual != expected {
        raise ParseError(
          "mismatched closing tag: expected </" +
          actual +
          "> but found </" +
          expected +
          ">",
        )
      }
    None => raise ParseError("unexpected closing tag: " + expected)
  }
}

///|
fn XmlTokenizer::read_declaration(self : XmlTokenizer) -> String raise {
  self.read_until("<?xml", "?>", "unterminated declaration")
}

///|
fn XmlTokenizer::read_processing_instruction(
  self : XmlTokenizer,
) -> (String, String) raise {
  self.advance_chars(2)
  self.skip_spaces()
  let name = self.read_name()
  self.skip_spaces()
  let body = self.read_until_after_prefix(
    "?>", "unterminated processing instruction",
  )
  (name, body.trim().to_owned())
}

///|
fn XmlTokenizer::read_comment(self : XmlTokenizer) -> String raise {
  self.read_until("<!--", "-->", "unterminated comment")
}

///|
fn XmlTokenizer::read_cdata(self : XmlTokenizer) -> String raise {
  self.read_until("<![CDATA[", "]]>", "unterminated cdata")
}

///|
fn XmlTokenizer::read_doctype(self : XmlTokenizer) -> String raise {
  self.advance_chars("<!DOCTYPE".length())
  let out : Array[Char] = []
  let mut bracket_depth = 0
  let mut in_single = false
  let mut in_double = false

  while self.pos < self.chars.length() {
    let ch = self.chars[self.pos]
    if ch == '\n' {
      self.line += 1
    }

    if in_single {
      out.push(ch)
      if ch == '\'' {
        in_single = false
      }
      self.pos += 1
      continue
    }
    if in_double {
      out.push(ch)
      if ch == '"' {
        in_double = false
      }
      self.pos += 1
      continue
    }

    match ch {
      '\'' => {
        in_single = true
        out.push(ch)
      }
      '"' => {
        in_double = true
        out.push(ch)
      }
      '[' => {
        bracket_depth += 1
        out.push(ch)
      }
      ']' => {
        if bracket_depth > 0 {
          bracket_depth -= 1
        }
        out.push(ch)
      }
      '>' =>
        if bracket_depth == 0 {
          self.pos += 1
          return String::from_array(out).trim().to_owned()
        } else {
          out.push(ch)
        }
      _ => out.push(ch)
    }
    self.pos += 1
  }

  raise ParseError("unterminated doctype")
}

///|
fn XmlTokenizer::read_end_tag(self : XmlTokenizer) -> String raise {
  self.advance_chars(2)
  self.skip_spaces()
  let name = self.read_name()
  self.skip_spaces()
  self.expect_char('>', "malformed end tag")
  name
}

///|
fn XmlTokenizer::read_start_like_tag(
  self : XmlTokenizer,
) -> (String, Array[XmlAttribute], Bool) raise {
  self.expect_char('<', "malformed start tag")
  let name = self.read_name()
  let attrs : Array[XmlAttribute] = []
  let seen_names : Array[String] = []

  while self.pos < self.chars.length() {
    self.skip_spaces()
    if self.pos >= self.chars.length() {
      raise ParseError("unterminated start tag")
    }
    if self.chars[self.pos] == '/' {
      self.pos += 1
      self.expect_char('>', "malformed empty element tag")
      return (name, attrs, true)
    }
    if self.chars[self.pos] == '>' {
      self.pos += 1
      return (name, attrs, false)
    }

    let attr_start = self.line
    let attr_name = self.read_name()
    for seen in seen_names {
      if seen == attr_name {
        raise ParseError("duplicate attribute: " + attr_name)
      }
    }
    self.skip_spaces()
    self.expect_char('=', "malformed attribute")
    self.skip_spaces()
    let (attr_value, quote_char, attr_end) = self.read_attribute_value()
    seen_names.push(attr_name)
    attrs.push({
      name: attr_name,
      value: attr_value,
      quote_char: Some(quote_char),
      span: { line_start: attr_start, line_end: attr_end },
    })
  }

  raise ParseError("unterminated start tag")
}

///|
fn XmlTokenizer::read_attribute_value(
  self : XmlTokenizer,
) -> (String, Char, Int) raise {
  if self.pos >= self.chars.length() {
    raise ParseError("missing attribute value")
  }
  let quote = self.chars[self.pos]
  if quote != '"' && quote != '\'' {
    raise ParseError("unquoted attribute value")
  }
  self.pos += 1
  let out : Array[Char] = []
  while self.pos < self.chars.length() {
    let ch = self.chars[self.pos]
    if ch == '\n' {
      self.line += 1
    }
    if ch == quote {
      self.pos += 1
      return (String::from_array(out), quote, self.line)
    }
    if ch == '&' {
      append_chars(out, self.read_decoded_entity())
      continue
    }
    out.push(ch)
    self.pos += 1
  }
  raise ParseError("unterminated attribute value")
}

///|
fn XmlTokenizer::read_decoded_entity(self : XmlTokenizer) -> String raise {
  self.expect_char('&', "malformed entity ref")
  let out : Array[Char] = []
  while self.pos < self.chars.length() {
    let ch = self.chars[self.pos]
    if ch == ';' {
      self.pos += 1
      let name = String::from_array(out)
      return decode_xml_entity(name)
    }
    if ch == '<' || ch == '\n' || ch == '\r' || ch == ' ' || ch == '\t' {
      raise ParseError("malformed entity ref")
    }
    out.push(ch)
    self.pos += 1
  }
  raise ParseError("unterminated entity ref")
}

///|
fn decode_xml_entity(name : String) -> String raise {
  match decode_predefined_entity(name) {
    Some(value) => value
    None =>
      match decode_numeric_xml_entity(name) {
        Some(value) => value
        None => raise ParseError("unsupported entity: &" + name + ";")
      }
  }
}

///|
fn decode_predefined_entity(name : String) -> String? {
  match name {
    "amp" => Some("&")
    "lt" => Some("<")
    "gt" => Some(">")
    "quot" => Some("\"")
    "apos" => Some("'")
    _ => None
  }
}

///|
fn decode_numeric_xml_entity(name : String) -> String? {
  if name.has_prefix("#x") || name.has_prefix("#X") {
    parse_xml_hex_int(name[2:].to_owned()).map(xml_codepoint_to_string)
  } else if name.has_prefix("#") {
    parse_xml_dec_int(name[1:].to_owned()).map(xml_codepoint_to_string)
  } else {
    None
  }
}

///|
fn parse_xml_dec_int(text : String) -> Int? {
  if text == "" {
    return None
  }
  let chars = text.to_array()
  let mut i = 0
  let mut value = 0
  while i < chars.length() {
    let ch = chars[i]
    if ch < '0' || ch > '9' {
      return None
    }
    value = value * 10 + (ch.to_int() - '0'.to_int())
    i += 1
  }
  if xml_is_valid_codepoint(value) {
    Some(value)
  } else {
    None
  }
}

///|
fn parse_xml_hex_int(text : String) -> Int? {
  if text == "" {
    return None
  }
  let chars = text.to_array()
  let mut i = 0
  let mut value = 0
  while i < chars.length() {
    match xml_hex_value(chars[i]) {
      Some(digit) => {
        value = (value << 4) + digit
        i += 1
      }
      None => return None
    }
  }
  if xml_is_valid_codepoint(value) {
    Some(value)
  } else {
    None
  }
}

///|
fn xml_hex_value(ch : Char) -> Int? {
  if ch >= '0' && ch <= '9' {
    Some(ch.to_int() - '0'.to_int())
  } else if ch >= 'a' && ch <= 'f' {
    Some(ch.to_int() - 'a'.to_int() + 10)
  } else if ch >= 'A' && ch <= 'F' {
    Some(ch.to_int() - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
fn xml_is_valid_codepoint(value : Int) -> Bool {
  value >= 0 && value <= 0x10FFFF && !(value >= 0xD800 && value <= 0xDFFF)
}

///|
fn xml_codepoint_to_string(value : Int) -> String {
  String::from_array([Int::unsafe_to_char(value)])
}

///|
fn XmlTokenizer::read_text(self : XmlTokenizer) -> String raise {
  let out : Array[Char] = []
  while self.pos < self.chars.length() && self.chars[self.pos] != '<' {
    let ch = self.chars[self.pos]
    if ch == '&' {
      append_chars(out, self.read_decoded_entity())
      continue
    }
    if ch == '\n' {
      self.line += 1
    }
    out.push(ch)
    self.pos += 1
  }
  String::from_array(out)
}

///|
fn XmlTokenizer::read_name(self : XmlTokenizer) -> String raise {
  if self.pos >= self.chars.length() || !is_name_start(self.chars[self.pos]) {
    raise ParseError("expected name")
  }
  let out : Array[Char] = []
  out.push(self.chars[self.pos])
  self.pos += 1
  while self.pos < self.chars.length() && is_name_char(self.chars[self.pos]) {
    out.push(self.chars[self.pos])
    self.pos += 1
  }
  String::from_array(out)
}

///|
fn XmlTokenizer::skip_spaces(self : XmlTokenizer) -> Unit {
  while self.pos < self.chars.length() {
    let ch = self.chars[self.pos]
    match ch {
      ' ' | '\t' => self.pos += 1
      '\n' => {
        self.line += 1
        self.pos += 1
      }
      _ => return
    }
  }
}

///|
fn XmlTokenizer::advance_chars(self : XmlTokenizer, count : Int) -> Unit {
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
fn XmlTokenizer::expect_char(
  self : XmlTokenizer,
  ch : Char,
  err : String,
) -> Unit raise {
  if self.pos >= self.chars.length() || self.chars[self.pos] != ch {
    raise ParseError(err)
  }
  self.pos += 1
}

///|
fn XmlTokenizer::read_until(
  self : XmlTokenizer,
  prefix : String,
  suffix : String,
  err : String,
) -> String raise {
  self.advance_chars(prefix.length())
  self.read_until_after_prefix(suffix, err)
}

///|
fn XmlTokenizer::read_until_after_prefix(
  self : XmlTokenizer,
  suffix : String,
  err : String,
) -> String raise {
  let suffix_chars = suffix.to_array()
  let out : Array[Char] = []
  while self.pos < self.chars.length() {
    if self.match_suffix(suffix_chars) {
      self.advance_chars(suffix_chars.length())
      return String::from_array(out)
    }
    let ch = self.chars[self.pos]
    if ch == '\n' {
      self.line += 1
    }
    out.push(ch)
    self.pos += 1
  }
  raise ParseError(err)
}

///|
fn XmlTokenizer::match_suffix(
  self : XmlTokenizer,
  suffix_chars : Array[Char],
) -> Bool {
  if self.pos + suffix_chars.length() > self.chars.length() {
    return false
  }
  for i in 0..<suffix_chars.length() {
    if self.chars[self.pos + i] != suffix_chars[i] {
      return false
    }
  }
  true
}

///|
fn normalize_xml_source(text : String) -> String {
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

///|
fn append_chars(out : Array[Char], text : String) -> Unit {
  for ch in text.to_array() {
    out.push(ch)
  }
}

///|
fn is_name_start(ch : Char) -> Bool {
  (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || ch == '_' || ch == ':'
}

///|
fn is_name_char(ch : Char) -> Bool {
  is_name_start(ch) || (ch >= '0' && ch <= '9') || ch == '-' || ch == '.'
}
