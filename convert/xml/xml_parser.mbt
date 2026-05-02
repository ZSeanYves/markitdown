///|
pub enum XmlEvent {
  Declaration(String, Int, Int)
  ProcessingInstruction(String, String, Int, Int)
  StartTag(String, Array[(String, String)], Int, Int)
  EndTag(String, Int, Int)
  EmptyElementTag(String, Array[(String, String)], Int, Int)
  Text(String, Int, Int)
  Comment(String, Int, Int)
  CData(String, Int, Int)
  Doctype(String, Int, Int)
  EntityRef(String, Int, Int)
}

///|
pub fn parse_xml(
  input_path : String,
  _out_dir : String,
  _max_heading : Int,
) -> @cor.Document raise {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("xml: file not found: " + input_path)
  }

  let bytes = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("xml: read failed: " + e.to_string())
  }

  let raw = @cor.utf8_bytes_to_string(bytes) catch {
    e => raise @cor.AppError("xml: utf8 decode failed: " + e.to_string())
  }

  let text = normalize_xml_text(raw)
  let doc = @cor.new_document()
  let src = @cor.basename(input_path)

  if text.trim() != "" {
    @cor.set_passthrough_markdown(doc, xml_fenced_markdown(text))
    @cor.push_with_origin(
      doc,
      @cor.Block::CodeBlock(text),
      Some({
        source_name: Some(src),
        page: None,
        slide: None,
        sheet: None,
        block_index: Some(doc.blocks.val.length()),
        heading_path: None,
        line_start: Some(1),
        line_end: Some(physical_line_count(text)),
        row_index: None,
        column_index: None,
        object_ref: None,
        relationship_id: None,
        key_path: None,
      }),
    )
  }

  doc
}

///|
pub fn tokenize_xml_text(text : String) -> Array[XmlEvent] raise {
  let normalized = normalize_xml_text(text)
  let tokenizer = XmlTokenizer::{
    chars: normalized.to_array(),
    pos: 0,
    line: 1,
    stack: [],
  }
  tokenizer.parse_events()
}

///|
fn normalize_xml_text(text : String) -> String {
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
        i = i + 2
      } else {
        i = i + 1
      }
    } else {
      out.push(ch)
      i = i + 1
    }
  }

  String::from_array(out)
}

///|
fn xml_fenced_markdown(text : String) -> String {
  let fence = "`".repeat(required_fence_width(text))
  if text.has_suffix("\n") {
    fence + "xml\n" + text + fence + "\n"
  } else {
    fence + "xml\n" + text + "\n" + fence + "\n"
  }
}

///|
fn required_fence_width(text : String) -> Int {
  let chars = text.to_array()
  let mut longest = 0
  let mut current = 0

  for ch in chars {
    if ch == '`' {
      current = current + 1
      if current > longest {
        longest = current
      }
    } else {
      current = 0
    }
  }

  if longest + 1 < 3 {
    3
  } else {
    longest + 1
  }
}

///|
fn physical_line_count(text : String) -> Int {
  if text == "" {
    return 0
  }

  let mut count = 1
  let chars = text.to_array()
  for i in 0..<chars.length() {
    if chars[i] == '\n' && i + 1 < chars.length() {
      count = count + 1
    }
  }
  count
}

///|
priv struct XmlTokenizer {
  chars : Array[Char]
  mut pos : Int
  mut line : Int
  stack : Array[String]
}

///|
fn XmlTokenizer::parse_events(self : XmlTokenizer) -> Array[XmlEvent] raise {
  let out : Array[XmlEvent] = []

  while self.pos < self.chars.length() {
    let start_line = self.line
    if self.chars[self.pos] == '<' {
      if self.starts_with("<?xml ") ||
        self.starts_with("<?xml\n") ||
        self.starts_with("<?xml\r") ||
        self.starts_with("<?xml\t") ||
        self.starts_with("<?xml?>") {
        out.push(
          XmlEvent::Declaration(self.read_declaration(), start_line, self.line),
        )
      } else if self.starts_with("<?") {
        let (name, body) = self.read_processing_instruction()
        out.push(
          XmlEvent::ProcessingInstruction(name, body, start_line, self.line),
        )
      } else if self.starts_with("<!--") {
        out.push(XmlEvent::Comment(self.read_comment(), start_line, self.line))
      } else if self.starts_with("<![CDATA[") {
        out.push(XmlEvent::CData(self.read_cdata(), start_line, self.line))
      } else if self.starts_with("<!DOCTYPE") {
        out.push(XmlEvent::Doctype(self.read_doctype(), start_line, self.line))
      } else if self.starts_with("</") {
        let name = self.read_end_tag()
        self.pop_expected_tag(name)
        out.push(XmlEvent::EndTag(name, start_line, self.line))
      } else if self.starts_with("<!") {
        raise @cor.AppError("xml: unsupported declaration-like syntax")
      } else {
        let (name, attrs, empty) = self.read_start_like_tag()
        if empty {
          out.push(
            XmlEvent::EmptyElementTag(name, attrs, start_line, self.line),
          )
        } else {
          self.stack.push(name)
          out.push(XmlEvent::StartTag(name, attrs, start_line, self.line))
        }
      }
    } else if self.chars[self.pos] == '&' {
      out.push(
        XmlEvent::EntityRef(self.read_entity_ref(), start_line, self.line),
      )
    } else {
      let text = self.read_text()
      if text != "" {
        out.push(XmlEvent::Text(text, start_line, self.line))
      }
    }
  }

  if self.stack.length() > 0 {
    raise @cor.AppError(
      "xml: unclosed tag: " + self.stack[self.stack.length() - 1],
    )
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
        raise @cor.AppError(
          "xml: mismatched closing tag: expected </" +
          actual +
          "> but found </" +
          expected +
          ">",
        )
      }
    None => raise @cor.AppError("xml: unexpected closing tag: " + expected)
  }
}

///|
fn XmlTokenizer::read_declaration(self : XmlTokenizer) -> String raise {
  self.read_until("<?xml", "?>", "xml: unterminated declaration")
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
    "?>", "xml: unterminated processing instruction",
  )
  (name, body.trim().to_owned())
}

///|
fn XmlTokenizer::read_comment(self : XmlTokenizer) -> String raise {
  self.read_until("<!--", "-->", "xml: unterminated comment")
}

///|
fn XmlTokenizer::read_cdata(self : XmlTokenizer) -> String raise {
  self.read_until("<![CDATA[", "]]>", "xml: unterminated cdata")
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
          return out_to_trimmed_string(out)
        } else {
          out.push(ch)
        }
      _ => out.push(ch)
    }
    self.pos += 1
  }

  raise @cor.AppError("xml: unterminated doctype")
}

///|
fn XmlTokenizer::read_end_tag(self : XmlTokenizer) -> String raise {
  self.advance_chars(2)
  self.skip_spaces()
  let name = self.read_name()
  self.skip_spaces()
  self.expect_char('>', "xml: malformed end tag")
  name
}

///|
fn XmlTokenizer::read_start_like_tag(
  self : XmlTokenizer,
) -> (String, Array[(String, String)], Bool) raise {
  self.expect_char('<', "xml: malformed start tag")
  let name = self.read_name()
  let attrs : Array[(String, String)] = []

  while self.pos < self.chars.length() {
    self.skip_spaces()
    if self.pos >= self.chars.length() {
      raise @cor.AppError("xml: unterminated start tag")
    }
    if self.chars[self.pos] == '/' {
      self.pos += 1
      self.expect_char('>', "xml: malformed empty element tag")
      return (name, attrs, true)
    }
    if self.chars[self.pos] == '>' {
      self.pos += 1
      return (name, attrs, false)
    }

    let attr_name = self.read_name()
    self.skip_spaces()
    self.expect_char('=', "xml: malformed attribute")
    self.skip_spaces()
    let attr_value = self.read_attribute_value()
    attrs.push((attr_name, attr_value))
  }

  raise @cor.AppError("xml: unterminated start tag")
}

///|
fn XmlTokenizer::read_attribute_value(self : XmlTokenizer) -> String raise {
  if self.pos >= self.chars.length() {
    raise @cor.AppError("xml: missing attribute value")
  }
  let quote = self.chars[self.pos]
  if quote != '"' && quote != '\'' {
    raise @cor.AppError("xml: unquoted attribute value")
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
      return String::from_array(out)
    }
    out.push(ch)
    self.pos += 1
  }
  raise @cor.AppError("xml: unterminated attribute value")
}

///|
fn XmlTokenizer::read_entity_ref(self : XmlTokenizer) -> String raise {
  self.expect_char('&', "xml: malformed entity ref")
  let out : Array[Char] = ['&']
  while self.pos < self.chars.length() {
    let ch = self.chars[self.pos]
    out.push(ch)
    self.pos += 1
    if ch == ';' {
      return String::from_array(out)
    }
    if ch == '<' || ch == '\n' || ch == '\r' || ch == ' ' || ch == '\t' {
      raise @cor.AppError("xml: malformed entity ref")
    }
  }
  raise @cor.AppError("xml: unterminated entity ref")
}

///|
fn XmlTokenizer::read_text(self : XmlTokenizer) -> String {
  let out : Array[Char] = []
  while self.pos < self.chars.length() &&
        self.chars[self.pos] != '<' &&
        self.chars[self.pos] != '&' {
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
fn XmlTokenizer::read_name(self : XmlTokenizer) -> String raise {
  if self.pos >= self.chars.length() || !is_name_start(self.chars[self.pos]) {
    raise @cor.AppError("xml: expected name")
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
    raise @cor.AppError(err)
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
  raise @cor.AppError(err)
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
fn out_to_trimmed_string(out : Array[Char]) -> String {
  String::from_array(out).trim().to_owned()
}

///|
fn is_name_start(ch : Char) -> Bool {
  (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || ch == '_' || ch == ':'
}

///|
fn is_name_char(ch : Char) -> Bool {
  is_name_start(ch) || (ch >= '0' && ch <= '9') || ch == '-' || ch == '.'
}
