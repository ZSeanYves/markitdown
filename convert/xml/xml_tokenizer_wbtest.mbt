///|
enum XmlEvent {
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
fn assert_event_kind_name(
  event : XmlEvent,
  expected_name : String,
) -> Unit raise {
  match event {
    XmlEvent::Declaration(text, line_start, line_end) => {
      ignore(text.length())
      ignore(line_start + line_end)
      assert_eq(expected_name, "Declaration")
    }
    XmlEvent::ProcessingInstruction(name, body, line_start, line_end) => {
      ignore(name.length() + body.length())
      ignore(line_start + line_end)
      assert_eq(expected_name, "ProcessingInstruction")
    }
    XmlEvent::StartTag(name, attrs, line_start, line_end) => {
      ignore(name.length() + attrs.length())
      ignore(line_start + line_end)
      assert_eq(expected_name, "StartTag")
    }
    XmlEvent::EndTag(name, line_start, line_end) => {
      ignore(name.length())
      ignore(line_start + line_end)
      assert_eq(expected_name, "EndTag")
    }
    XmlEvent::EmptyElementTag(name, attrs, line_start, line_end) => {
      ignore(name.length() + attrs.length())
      ignore(line_start + line_end)
      assert_eq(expected_name, "EmptyElementTag")
    }
    XmlEvent::Text(text, line_start, line_end) => {
      ignore(text.length())
      ignore(line_start + line_end)
      assert_eq(expected_name, "Text")
    }
    XmlEvent::Comment(text, line_start, line_end) => {
      ignore(text.length())
      ignore(line_start + line_end)
      assert_eq(expected_name, "Comment")
    }
    XmlEvent::CData(text, line_start, line_end) => {
      ignore(text.length())
      ignore(line_start + line_end)
      assert_eq(expected_name, "CData")
    }
    XmlEvent::Doctype(text, line_start, line_end) => {
      ignore(text.length())
      ignore(line_start + line_end)
      assert_eq(expected_name, "Doctype")
    }
    XmlEvent::EntityRef(text, line_start, line_end) => {
      ignore(text.length())
      ignore(line_start + line_end)
      assert_eq(expected_name, "EntityRef")
    }
  }
}

///|
fn write_utf8_text(path : String, text : String) -> Unit raise {
  @fs.write_string_to_file(path, text, encoding="utf8") catch {
    e => fail("write sample failed: " + e.to_string())
  }
}

///|
fn ensure_dir(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    @fs.create_dir(path)
  }
}

///|
fn ensure_dir_tree(path : String) -> Unit raise {
  let trimmed = path.trim()
  if trimmed == "" {
    return
  }

  let chars = trimmed.to_array()
  let mut current = if chars.length() > 0 && chars[0] == '/' { "/" } else { "" }
  let part : Array[Char] = []

  fn flush(part : Array[Char], current : String) -> String raise {
    if part.length() == 0 {
      return current
    }

    let segment = String::from_array(part)
    part.clear()
    let next = if current == "" || current == "/" {
      current + segment
    } else {
      current + "/" + segment
    }
    ensure_dir(next)
    next
  }

  for ch in chars {
    if ch == '/' {
      current = flush(part, current)
    } else {
      part.push(ch)
    }
  }

  ignore(flush(part, current))
}

///|
fn test_tmp_root() -> String {
  ".tmp"
}

///|
fn xml_test_root() -> String raise {
  ensure_dir_tree(test_tmp_root())
  let dir = test_tmp_root() + "/xml-test"
  ensure_dir(dir)
  dir
}

///|
fn remove_dir_recursive(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    return
  }

  for name in @fs.read_dir(path) {
    let child = path + "/" + name
    if @fs.is_dir(child) {
      remove_dir_recursive(child)
    } else if @fs.is_file(child) {
      @fs.remove_file(child)
    }
  }

  @fs.remove_dir(path)
}

///|
fn recreate_clean_dir(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    remove_dir_recursive(path)
  }
  @fs.create_dir(path)
}

///|
fn cleanup_temp_dir(path : String) -> Unit {
  ignore(try? remove_dir_recursive(path))
}

///|
struct XmlTokenizer {
  chars : Array[Char]
  mut pos : Int
  mut line : Int
  stack : Array[String]
}

///|
fn tokenize_xml_text(text : String) -> Array[XmlEvent] raise {
  let normalized = normalize_xml_text_for_test(text)
  let tokenizer = XmlTokenizer::{
    chars: normalized.to_array(),
    pos: 0,
    line: 1,
    stack: [],
  }
  tokenizer.parse_events()
}

///|
fn normalize_xml_text_for_test(text : String) -> String {
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

///|
test "xml tokenizer emits safe event surface for valid syntax" {
  let events = tokenize_xml_text(
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
    "<?xml-stylesheet type=\"text/xsl\" href=\"style.xsl\"?>\n" +
    "<!DOCTYPE note SYSTEM \"note.dtd\">\n" +
    "<x:root xmlns:x=\"urn:test\">\n" +
    "  <!-- comment -->\n" +
    "  <item id=\"1\" name='x'>Hello &amp; <![CDATA[<not-tag>]]><br/></item>\n" +
    "</x:root>\n",
  )

  assert_eq(events.length(), 20)
  assert_event_kind_name(events[0], "Declaration")
  assert_event_kind_name(events[1], "Text")
  assert_event_kind_name(events[2], "ProcessingInstruction")
  assert_event_kind_name(events[3], "Text")
  assert_event_kind_name(events[4], "Doctype")
  assert_event_kind_name(events[5], "Text")
  assert_event_kind_name(events[6], "StartTag")
  assert_event_kind_name(events[7], "Text")
  assert_event_kind_name(events[8], "Comment")
  assert_event_kind_name(events[9], "Text")
  assert_event_kind_name(events[10], "StartTag")
  assert_event_kind_name(events[11], "Text")
  assert_event_kind_name(events[12], "EntityRef")
  assert_event_kind_name(events[13], "Text")
  assert_event_kind_name(events[14], "CData")
  assert_event_kind_name(events[15], "EmptyElementTag")
  assert_event_kind_name(events[16], "EndTag")
  assert_event_kind_name(events[17], "Text")
  assert_event_kind_name(events[18], "EndTag")

  match events[2] {
    XmlEvent::ProcessingInstruction(name, body, line_start, line_end) => {
      assert_eq(name, "xml-stylesheet")
      assert_eq(body, "type=\"text/xsl\" href=\"style.xsl\"")
      assert_eq(line_start, 2)
      assert_eq(line_end, 2)
    }
    _ => fail("expected processing instruction event")
  }

  match events[6] {
    XmlEvent::StartTag(name, attrs, line_start, line_end) => {
      assert_eq(name, "x:root")
      assert_eq(attrs.length(), 1)
      assert_eq(attrs[0], ("xmlns:x", "urn:test"))
      assert_eq(line_start, 4)
      assert_eq(line_end, 4)
    }
    _ => fail("expected start-tag event")
  }

  match events[10] {
    XmlEvent::StartTag(name, attrs, _, _) => {
      assert_eq(name, "item")
      assert_eq(attrs.length(), 2)
      assert_eq(attrs[0], ("id", "1"))
      assert_eq(attrs[1], ("name", "x"))
    }
    _ => fail("expected item start-tag event")
  }

  match events[12] {
    XmlEvent::EntityRef(text, line_start, line_end) => {
      assert_eq(text, "&amp;")
      assert_eq(line_start, 6)
      assert_eq(line_end, 6)
    }
    _ => fail("expected entity-ref event")
  }

  match events[14] {
    XmlEvent::CData(text, line_start, line_end) => {
      assert_eq(text, "<not-tag>")
      assert_eq(line_start, 6)
      assert_eq(line_end, 6)
    }
    _ => fail("expected cdata event")
  }
}

///|
test "xml tokenizer handles line tracking and empty tags" {
  let events = tokenize_xml_text(
    "<root>\r\n  <br/>\r\n  <child>ok</child>\r\n</root>\r\n",
  )

  assert_eq(events.length(), 10)
  match events[2] {
    XmlEvent::EmptyElementTag(name, attrs, line_start, line_end) => {
      assert_eq(name, "br")
      assert_eq(attrs.length(), 0)
      assert_eq(line_start, 2)
      assert_eq(line_end, 2)
    }
    _ => fail("expected empty-element event")
  }

  match events[4] {
    XmlEvent::StartTag(name, _, line_start, line_end) => {
      assert_eq(name, "child")
      assert_eq(line_start, 3)
      assert_eq(line_end, 3)
    }
    _ => fail("expected child start-tag")
  }

  match events[5] {
    XmlEvent::Text(text, line_start, line_end) => {
      assert_eq(text, "ok")
      assert_eq(line_start, 3)
      assert_eq(line_end, 3)
    }
    _ => fail("expected text event")
  }
}

///|
test "xml tokenizer rejects malformed syntax and mismatched tags" {
  let root = xml_test_root()
  let out_dir = root + "/malformed"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let cases : Array[(String, String)] = [
    ("unclosed_tag.xml", "<root><child></root>\n"),
    ("mismatched_closing.xml", "<root><a></b></root>\n"),
    ("unclosed_comment.xml", "<root><!-- no end</root>\n"),
    ("unclosed_cdata.xml", "<root><![CDATA[broken</root>\n"),
    ("unquoted_attr.xml", "<root a=1></root>\n"),
    ("bad_attr.xml", "<root a \"1\"></root>\n"),
    ("bad_pi.xml", "<?broken\n"),
    ("bad_doctype.xml", "<!DOCTYPE note [ <!ENTITY a \"x\"> \n"),
  ]

  for i in 0..<cases.length() {
    let (name, text) = cases[i]
    let path = out_dir + "/" + name
    write_utf8_text(path, text)
    assert_true((try? tokenize_xml_text(text)) is Err(_))
  }
}
