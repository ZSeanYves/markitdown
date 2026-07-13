///|
/// Tokenize HTML source into raw tolerant HTML tokens.
pub fn tokenize_html_document(text : String) -> Array[HtmlToken] raise {
  let normalized = normalize_html_source(text)
  tokenize_normalized_html_document(normalized)
}

///|
pub fn tokenize_html_events(text : String) -> Array[HtmlTokenEvent] raise {
  let normalized = normalize_html_source(text)
  tokenize_normalized_html_event_scan(normalized).events
}

///|
pub fn scan_normalized_html_string_event_fields(
  text : String,
  visit : (
    HtmlTokenEventKind,
    String,
    Array[HtmlAttribute],
    Bool,
    Int,
    Int,
    Int,
    Int,
    Int,
    Int,
  ) -> Unit,
) -> Unit raise {
  let tokenizer = HtmlTokenizer::{
    chars: [],
    pos: 0,
    byte_pos: 0,
    line: 1,
    collect_events: false,
    emit_tokens: false,
    events: [],
    field_visitor: Some(visit),
    text_source: Some(text),
  }
  ignore(tokenizer.parse_tokens())
}

///|
fn scan_html_event_summary(text : String) -> HtmlTokenEventSummary raise {
  let mut node_count = 0
  let mut depth = 0
  let mut max_depth = 0
  let mut block_scope_count = 0
  let mut structural_scope_count = 0
  let normalized = normalize_html_source(text)
  scan_normalized_html_string_event_fields(normalized, fn(
    kind,
    tag_name,
    attributes,
    self_closing,
    source_start,
    source_end,
    _line_start,
    _line_end,
    _byte_start,
    _byte_end,
  ) {
    match kind {
      HtmlTokenEventKind::Doctype | HtmlTokenEventKind::Comment =>
        node_count += 1
      HtmlTokenEventKind::Text =>
        if source_end > source_start {
          node_count += 1
        }
      HtmlTokenEventKind::StartTag => {
        node_count += 1 + attributes.length()
        if tag_name == "main" || tag_name == "article" || tag_name == "section" {
          block_scope_count += 1
        }
        if tag_name == "main" ||
          tag_name == "article" ||
          tag_name == "section" ||
          tag_name == "nav" ||
          tag_name == "aside" ||
          tag_name == "table" ||
          tag_name == "ul" ||
          tag_name == "ol" {
          structural_scope_count += 1
        }
        if !self_closing {
          depth += 1
          if depth > max_depth {
            max_depth = depth
          }
        }
      }
      HtmlTokenEventKind::EndTag => if depth > 0 { depth -= 1 }
    }
  })
  {
    node_count,
    block_scope_count,
    structural_scope_count,
    max_depth,
    char_count: text.length(),
  }
}

///|
/// Return the source string used for token event offsets.
pub fn normalize_html_token_source(text : String) -> String {
  normalize_html_source(text)
}

///|
fn tokenize_normalized_html_document(
  normalized : String,
) -> Array[HtmlToken] raise {
  let tokenizer = HtmlTokenizer::{
    chars: normalized.to_array(),
    pos: 0,
    byte_pos: 0,
    line: 1,
    collect_events: false,
    emit_tokens: true,
    events: [],
    field_visitor: None,
    text_source: None,
  }
  tokenizer.parse_tokens()
}

///|
fn tokenize_normalized_html_event_scan(
  normalized : String,
) -> HtmlTokenEventScan raise {
  let tokenizer = HtmlTokenizer::{
    chars: [],
    pos: 0,
    byte_pos: 0,
    line: 1,
    collect_events: true,
    emit_tokens: false,
    events: [],
    field_visitor: None,
    text_source: Some(normalized),
  }
  let tokens = tokenizer.parse_tokens()
  { tokens, events: tokenizer.events }
}

///|
priv struct HtmlTokenEventScan {
  tokens : Array[HtmlToken]
  events : Array[HtmlTokenEvent]
}

///|
priv struct HtmlTokenizer {
  chars : Array[Char]
  mut pos : Int
  mut byte_pos : Int
  mut line : Int
  collect_events : Bool
  emit_tokens : Bool
  events : Array[HtmlTokenEvent]
  field_visitor : ((
    HtmlTokenEventKind,
    String,
    Array[HtmlAttribute],
    Bool,
    Int,
    Int,
    Int,
    Int,
    Int,
    Int,
  ) -> Unit)?
  text_source : String?
}

///|
fn HtmlTokenizer::source_length(self : HtmlTokenizer) -> Int {
  match self.text_source {
    Some(text) => text.length()
    None => self.chars.length()
  }
}

///|
fn HtmlTokenizer::source_char_at(self : HtmlTokenizer, index : Int) -> Char {
  match self.text_source {
    Some(text) => {
      let first = text[index].to_int()
      if first >= 0xD800 && first <= 0xDBFF && index + 1 < text.length() {
        let second = text[index + 1].to_int()
        if second >= 0xDC00 && second <= 0xDFFF {
          return Int::unsafe_to_char(
            0x10000 + ((first - 0xD800) << 10) + (second - 0xDC00),
          )
        }
      }
      Int::unsafe_to_char(first)
    }
    None => self.chars[index]
  }
}

///|
fn HtmlTokenizer::source_char_width_at(
  self : HtmlTokenizer,
  index : Int,
) -> Int {
  match self.text_source {
    Some(text) => {
      let first = text[index].to_int()
      if first >= 0xD800 && first <= 0xDBFF && index + 1 < text.length() {
        let second = text[index + 1].to_int()
        if second >= 0xDC00 && second <= 0xDFFF {
          return 2
        }
      }
      1
    }
    None => 1
  }
}

///|
fn HtmlTokenizer::advance_source_char(self : HtmlTokenizer) -> Unit {
  let ch = self.source_char_at(self.pos).to_int()
  self.byte_pos += if ch <= 0x7F {
    1
  } else if ch <= 0x7FF {
    2
  } else if ch <= 0xFFFF {
    3
  } else {
    4
  }
  self.pos += self.source_char_width_at(self.pos)
}

///|
fn HtmlTokenizer::parse_tokens(self : HtmlTokenizer) -> Array[HtmlToken] raise {
  let out : Array[HtmlToken] = []

  while self.pos < self.source_length() {
    let start_line = self.line
    let start_pos = self.pos
    let start_byte = self.byte_pos
    if self.source_char_at(self.pos) == '<' {
      if self.starts_with("<!--") {
        let comment = if self.emit_tokens {
          self.read_comment()
        } else {
          self.skip_comment()
          ""
        }
        let span = {
          line_start: start_line,
          line_end: self.line,
          byte_start: start_byte,
          byte_end: self.byte_pos,
        }
        if self.emit_tokens {
          out.push(HtmlToken::Comment(comment, span))
        }
        self.push_event(
          HtmlTokenEventKind::Comment,
          "",
          [],
          false,
          start_pos,
          self.pos,
          span,
        )
      } else if self.starts_with("</") && self.has_end_tag_name() {
        let tag_name = self.read_end_tag()
        let span = {
          line_start: start_line,
          line_end: self.line,
          byte_start: start_byte,
          byte_end: self.byte_pos,
        }
        if self.emit_tokens {
          out.push(HtmlToken::EndTag(tag_name, span))
        }
        self.push_event(
          HtmlTokenEventKind::EndTag,
          tag_name,
          [],
          false,
          start_pos,
          self.pos,
          span,
        )
      } else if self.starts_with_case_insensitive("<!doctype") {
        let text = if self.emit_tokens {
          self.read_doctype_like()
        } else {
          self.skip_doctype_like()
          ""
        }
        let span = {
          line_start: start_line,
          line_end: self.line,
          byte_start: start_byte,
          byte_end: self.byte_pos,
        }
        if self.emit_tokens {
          out.push(HtmlToken::Doctype(text, span))
        }
        self.push_event(
          HtmlTokenEventKind::Doctype,
          "",
          [],
          false,
          start_pos,
          self.pos,
          span,
        )
      } else if self.pos + 1 < self.source_length() &&
        is_html_name_start(self.source_char_at(self.pos + 1)) {
        let (name, attrs, self_closing) = self.read_start_tag()
        let span = {
          line_start: start_line,
          line_end: self.line,
          byte_start: start_byte,
          byte_end: self.byte_pos,
        }
        if self.emit_tokens {
          out.push(HtmlToken::StartTag(name, attrs, self_closing, span))
        }
        self.push_event(
          HtmlTokenEventKind::StartTag,
          name,
          attrs,
          self_closing,
          start_pos,
          self.pos,
          span,
        )
        if is_html_raw_text_tag(name) {
          let raw_start = self.line
          let raw_start_pos = self.pos
          let raw_start_byte = self.byte_pos
          let raw_text = if self.emit_tokens {
            self.read_raw_text_body(name)
          } else {
            self.skip_raw_text_body(name)
            ""
          }
          if self.pos > raw_start_pos {
            let raw_span = {
              line_start: raw_start,
              line_end: self.line,
              byte_start: raw_start_byte,
              byte_end: self.byte_pos,
            }
            if self.emit_tokens {
              out.push(HtmlToken::Text(raw_text, raw_span))
            }
            self.push_event(
              HtmlTokenEventKind::Text,
              "",
              [],
              false,
              raw_start_pos,
              self.pos,
              raw_span,
            )
          }
          let close_start = self.line
          let close_start_pos = self.pos
          let close_start_byte = self.byte_pos
          if self.consume_case_insensitive("</" + name) {
            self.skip_spaces()
            self.expect_char('>', "unterminated raw-text closing tag")
            let close_span = {
              line_start: close_start,
              line_end: self.line,
              byte_start: close_start_byte,
              byte_end: self.byte_pos,
            }
            if self.emit_tokens {
              out.push(HtmlToken::EndTag(name, close_span))
            }
            self.push_event(
              HtmlTokenEventKind::EndTag,
              name,
              [],
              false,
              close_start_pos,
              self.pos,
              close_span,
            )
          }
        }
      } else {
        let span = {
          line_start: start_line,
          line_end: start_line,
          byte_start: start_byte,
          byte_end: start_byte + 1,
        }
        if self.emit_tokens {
          out.push(HtmlToken::Text("<", span))
        }
        self.push_event(
          HtmlTokenEventKind::Text,
          "",
          [],
          false,
          start_pos,
          start_pos + 1,
          span,
        )
        self.advance_source_char()
      }
    } else {
      let text_node = if self.emit_tokens {
        self.read_text()
      } else {
        self.skip_text()
        ""
      }
      if self.pos > start_pos {
        let span = {
          line_start: start_line,
          line_end: self.line,
          byte_start: start_byte,
          byte_end: self.byte_pos,
        }
        if self.emit_tokens {
          out.push(HtmlToken::Text(text_node, span))
        }
        self.push_event(
          HtmlTokenEventKind::Text,
          "",
          [],
          false,
          start_pos,
          self.pos,
          span,
        )
      }
    }
  }

  out
}

///|
fn HtmlTokenizer::push_event(
  self : HtmlTokenizer,
  kind : HtmlTokenEventKind,
  tag_name : String,
  attributes : Array[HtmlAttribute],
  self_closing : Bool,
  source_start : Int,
  source_end : Int,
  span : HtmlSourceSpan,
) -> Unit {
  if self.collect_events {
    self.events.push({
      kind,
      tag_name,
      attributes,
      self_closing,
      source_start,
      source_end,
      span,
    })
  } else {
    match self.field_visitor {
      Some(visit) =>
        visit(
          kind,
          tag_name,
          attributes,
          self_closing,
          source_start,
          source_end,
          span.line_start,
          span.line_end,
          span.byte_start,
          span.byte_end,
        )
      None => ()
    }
  }
}

///|
fn HtmlTokenizer::has_end_tag_name(self : HtmlTokenizer) -> Bool {
  if self.pos + 2 >= self.source_length() {
    return false
  }
  let mut i = self.pos + 2
  while i < self.source_length() {
    match self.source_char_at(i) {
      ' ' | '\t' | '\n' | '\r' => i += 1
      ch => return is_html_name_start(ch)
    }
  }
  false
}

///|
fn HtmlTokenizer::starts_with(self : HtmlTokenizer, prefix : String) -> Bool {
  let chars = prefix.to_array()
  if self.pos + chars.length() > self.source_length() {
    return false
  }
  for i in 0..<chars.length() {
    if self.source_char_at(self.pos + i) != chars[i] {
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
  if self.pos + chars.length() > self.source_length() {
    return false
  }
  for i in 0..<chars.length() {
    if lower_ascii_html_char(self.source_char_at(self.pos + i)) != chars[i] {
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
  while self.pos < self.source_length() {
    if self.starts_with("-->") {
      self.advance_chars(3)
      return String::from_array(out)
    }
    let ch = self.source_char_at(self.pos)
    if ch == '\n' {
      self.line += 1
    }
    out.push(ch)
    self.advance_source_char()
  }
  raise ParseError("unterminated comment")
}

///|
fn HtmlTokenizer::skip_comment(self : HtmlTokenizer) -> Unit raise {
  self.advance_chars("<!--".length())
  while self.pos < self.source_length() {
    if self.starts_with("-->") {
      self.advance_chars(3)
      return
    }
    if self.source_char_at(self.pos) == '\n' {
      self.line += 1
    }
    self.advance_source_char()
  }
  raise ParseError("unterminated comment")
}

///|
fn HtmlTokenizer::read_doctype_like(self : HtmlTokenizer) -> String raise {
  self.expect_char('<', "malformed doctype")
  self.expect_char('!', "malformed doctype")
  let out : Array[Char] = []
  while self.pos < self.source_length() {
    let ch = self.source_char_at(self.pos)
    if ch == '>' {
      self.advance_source_char()
      return String::from_array(out).trim().to_owned()
    }
    if ch == '\n' {
      self.line += 1
    }
    out.push(ch)
    self.advance_source_char()
  }
  raise ParseError("unterminated doctype or declaration")
}

///|
fn HtmlTokenizer::skip_doctype_like(self : HtmlTokenizer) -> Unit raise {
  self.expect_char('<', "malformed doctype")
  self.expect_char('!', "malformed doctype")
  while self.pos < self.source_length() {
    let ch = self.source_char_at(self.pos)
    self.advance_source_char()
    if ch == '>' {
      return
    }
    if ch == '\n' {
      self.line += 1
    }
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

  while self.pos < self.source_length() {
    self.skip_spaces()
    if self.pos >= self.source_length() {
      raise ParseError("unterminated start tag")
    }

    if self.source_char_at(self.pos) == '>' {
      self.advance_source_char()
      return (name, attrs, false)
    }

    if self.source_char_at(self.pos) == '/' {
      self.advance_source_char()
      self.expect_char('>', "unterminated self-closing tag")
      return (name, attrs, true)
    }

    let attr_start = self.line
    let attr_start_byte = self.byte_pos
    let attr_name = self.read_name()
    self.skip_spaces()
    let mut value = ""
    let mut quote_style = HtmlAttributeQuoteStyle::Unquoted

    if self.pos < self.source_length() && self.source_char_at(self.pos) == '=' {
      self.advance_source_char()
      self.skip_spaces()
      let parsed = self.read_attribute_value()
      value = parsed.0
      quote_style = parsed.1
    }

    attrs.push({
      name: attr_name,
      value,
      quote_style,
      span: {
        line_start: attr_start,
        line_end: self.line,
        byte_start: attr_start_byte,
        byte_end: self.byte_pos,
      },
    })
  }

  raise ParseError("unterminated start tag")
}

///|
fn HtmlTokenizer::read_attribute_value(
  self : HtmlTokenizer,
) -> (String, HtmlAttributeQuoteStyle) raise {
  if self.pos >= self.source_length() {
    raise ParseError("missing attribute value")
  }

  let quote = self.source_char_at(self.pos)
  if quote == '"' || quote == '\'' {
    self.advance_source_char()
    let out : Array[Char] = []
    while self.pos < self.source_length() {
      let ch = self.source_char_at(self.pos)
      if ch == '\n' {
        self.line += 1
      }
      if ch == quote {
        self.advance_source_char()
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
      self.advance_source_char()
    }
    raise ParseError("unterminated attribute value")
  }

  let out : Array[Char] = []
  while self.pos < self.source_length() {
    let ch = self.source_char_at(self.pos)
    if ch == ' ' ||
      ch == '\t' ||
      ch == '\n' ||
      ch == '\r' ||
      ch == '>' ||
      ch == '/' {
      break
    }
    out.push(ch)
    self.advance_source_char()
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
  while self.pos < self.source_length() && self.source_char_at(self.pos) != '<' {
    let ch = self.source_char_at(self.pos)
    if ch == '\n' {
      self.line += 1
    }
    out.push(ch)
    self.advance_source_char()
  }
  decode_html_entities(String::from_array(out))
}

///|
fn HtmlTokenizer::skip_text(self : HtmlTokenizer) -> Unit {
  while self.pos < self.source_length() && self.source_char_at(self.pos) != '<' {
    if self.source_char_at(self.pos) == '\n' {
      self.line += 1
    }
    self.advance_source_char()
  }
}

///|
fn HtmlTokenizer::read_raw_text_body(
  self : HtmlTokenizer,
  tag_name : String,
) -> String {
  let out : Array[Char] = []
  while self.pos < self.source_length() {
    if self.starts_with_case_insensitive("</" + tag_name) {
      break
    }
    let ch = self.source_char_at(self.pos)
    if ch == '\n' {
      self.line += 1
    }
    out.push(ch)
    self.advance_source_char()
  }
  String::from_array(out)
}

///|
fn HtmlTokenizer::skip_raw_text_body(
  self : HtmlTokenizer,
  tag_name : String,
) -> Unit {
  while self.pos < self.source_length() {
    if self.starts_with_case_insensitive("</" + tag_name) {
      return
    }
    if self.source_char_at(self.pos) == '\n' {
      self.line += 1
    }
    self.advance_source_char()
  }
}

///|
fn HtmlTokenizer::read_name(self : HtmlTokenizer) -> String raise {
  if self.pos >= self.source_length() ||
    !is_html_name_start(self.source_char_at(self.pos)) {
    raise ParseError("expected name")
  }
  let out : Array[Char] = []
  out.push(lower_ascii_html_char(self.source_char_at(self.pos)))
  self.advance_source_char()
  while self.pos < self.source_length() &&
        is_html_name_char(self.source_char_at(self.pos)) {
    out.push(lower_ascii_html_char(self.source_char_at(self.pos)))
    self.advance_source_char()
  }
  html_intern_token_name(String::from_array(out))
}

///|
fn html_intern_token_name(name : String) -> String {
  match name {
    "html" => "html"
    "head" => "head"
    "body" => "body"
    "title" => "title"
    "meta" => "meta"
    "main" => "main"
    "article" => "article"
    "section" => "section"
    "div" => "div"
    "header" => "header"
    "footer" => "footer"
    "nav" => "nav"
    "aside" => "aside"
    "h1" => "h1"
    "h2" => "h2"
    "h3" => "h3"
    "h4" => "h4"
    "h5" => "h5"
    "h6" => "h6"
    "p" => "p"
    "a" => "a"
    "img" => "img"
    "br" => "br"
    "hr" => "hr"
    "ul" => "ul"
    "ol" => "ol"
    "li" => "li"
    "blockquote" => "blockquote"
    "pre" => "pre"
    "code" => "code"
    "table" => "table"
    "thead" => "thead"
    "tbody" => "tbody"
    "tfoot" => "tfoot"
    "tr" => "tr"
    "th" => "th"
    "td" => "td"
    "figure" => "figure"
    "figcaption" => "figcaption"
    "details" => "details"
    "summary" => "summary"
    "script" => "script"
    "style" => "style"
    "id" => "id"
    "class" => "class"
    "href" => "href"
    "src" => "src"
    "alt" => "alt"
    "role" => "role"
    "charset" => "charset"
    "colspan" => "colspan"
    "rowspan" => "rowspan"
    _ => name
  }
}

///|
fn HtmlTokenizer::skip_spaces(self : HtmlTokenizer) -> Unit {
  while self.pos < self.source_length() {
    let ch = self.source_char_at(self.pos)
    match ch {
      ' ' | '\t' => self.advance_source_char()
      '\r' => self.advance_source_char()
      '\n' => {
        self.line += 1
        self.advance_source_char()
      }
      _ => return
    }
  }
}

///|
fn HtmlTokenizer::advance_chars(self : HtmlTokenizer, count : Int) -> Unit {
  for _ in 0..<count {
    if self.pos >= self.source_length() {
      return
    }
    if self.source_char_at(self.pos) == '\n' {
      self.line += 1
    }
    self.advance_source_char()
  }
}

///|
fn HtmlTokenizer::expect_char(
  self : HtmlTokenizer,
  ch : Char,
  err : String,
) -> Unit raise {
  if self.pos >= self.source_length() || self.source_char_at(self.pos) != ch {
    raise ParseError(err)
  }
  self.advance_source_char()
}

///|
fn normalize_html_source(text : String) -> String {
  if !text.has_prefix("\u{FEFF}") && !text.contains("\r") {
    return text
  }
  let chars = text.to_array()
  let mut i = 0
  let mut needs_normalization = false

  if chars.length() > 0 && chars[0] == '\u{FEFF}' {
    i = 1
    needs_normalization = true
  } else {
    for ch in chars {
      if ch == '\r' {
        needs_normalization = true
        break
      }
    }
  }

  if !needs_normalization {
    return text
  }

  let out : Array[Char] = []
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
pub fn decode_html_entities(text : String) -> String {
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
/// Return the lowercase tag name from a raw `<...>` tag fragment.
pub fn html_tag_name(tag : String) -> String? {
  let chars = tag.to_array()
  let n = chars.length()
  let mut i = 0
  while i < n && chars[i] != '<' {
    i += 1
  }
  if i >= n {
    return None
  }
  i += 1
  while i < n && is_html_space(chars[i]) {
    i += 1
  }
  if i < n && chars[i] == '/' {
    i += 1
    while i < n && is_html_space(chars[i]) {
      i += 1
    }
  }
  if i >= n || !is_html_name_start(chars[i]) {
    return None
  }
  let start = i
  while i < n && is_html_name_char(chars[i]) {
    i += 1
  }
  Some(lower_ascii_html_string(slice_chars(chars, start, i)))
}

///|
/// Read an attribute value from a raw tag fragment without entity decoding.
pub fn html_raw_attr_value(tag : String, attr_name : String) -> String? {
  let wanted = attr_name.to_lower().trim().to_owned()
  if wanted == "" {
    return None
  }
  let chars = tag.to_array()
  let lower = tag.to_lower().to_array()
  let n = chars.length()
  let mut i = html_attr_scan_start(chars)
  while i < n {
    while i < n && is_html_space(chars[i]) {
      i += 1
    }
    if i >= n || chars[i] == '>' {
      return None
    }
    if chars[i] == '/' {
      i += 1
      continue
    }
    if !is_html_name_start(chars[i]) {
      i += 1
      continue
    }

    let name_start = i
    while i < n && is_html_name_char(chars[i]) {
      i += 1
    }
    let name = slice_chars(lower, name_start, i)
    while i < n && is_html_space(chars[i]) {
      i += 1
    }
    if i >= n || chars[i] != '=' {
      continue
    }
    i += 1
    while i < n && is_html_space(chars[i]) {
      i += 1
    }
    if i >= n {
      return None
    }

    let (value_start, value_end, next_i) = if chars[i] == '"' ||
      chars[i] == '\'' {
      let quote = chars[i]
      i += 1
      let start = i
      while i < n && chars[i] != quote {
        i += 1
      }
      if i >= n {
        return None
      }
      (start, i, i + 1)
    } else {
      let start = i
      while i < n && !is_html_space(chars[i]) && chars[i] != '>' {
        i += 1
      }
      (start, i, i)
    }
    i = next_i

    if name == wanted {
      return Some(slice_chars(chars, value_start, value_end))
    }
  }
  None
}

///|
/// Read an attribute value from a raw tag fragment with parser entity decoding.
pub fn html_attr_value(tag : String, attr_name : String) -> String? {
  html_raw_attr_value(tag, attr_name).map(decode_html_entities)
}

///|
pub fn html_token_event_is_open_tag(
  event : HtmlTokenEvent,
  tag_name : String,
) -> Bool {
  event.kind == HtmlTokenEventKind::StartTag &&
  event.tag_name == tag_name.to_lower()
}

///|
pub fn html_token_event_is_close_tag(
  event : HtmlTokenEvent,
  tag_name : String,
) -> Bool {
  event.kind == HtmlTokenEventKind::EndTag &&
  event.tag_name == tag_name.to_lower()
}

///|
pub fn html_token_event_attr_value(
  event : HtmlTokenEvent,
  attr_name : String,
) -> String? {
  html_attributes_value(event.attributes, attr_name)
}

///|
pub fn html_attributes_value(
  attributes : Array[HtmlAttribute],
  attr_name : String,
) -> String? {
  let wanted = attr_name.to_lower().trim().to_owned()
  if wanted == "" {
    return None
  }
  for attr in attributes {
    if attr.name == wanted {
      return Some(attr.value)
    }
  }
  None
}

///|
pub fn html_tokens_find_matching_close(
  events : Array[HtmlTokenEvent],
  open_index : Int,
) -> Int? {
  if open_index < 0 || open_index >= events.length() {
    return None
  }
  let open_event = events[open_index]
  if open_event.kind != HtmlTokenEventKind::StartTag || open_event.self_closing {
    return None
  }
  let tag_name = open_event.tag_name
  let mut depth = 0
  for i in open_index..<events.length() {
    let event = events[i]
    if event.kind == HtmlTokenEventKind::StartTag &&
      event.tag_name == tag_name &&
      !event.self_closing {
      depth += 1
    } else if event.kind == HtmlTokenEventKind::EndTag &&
      event.tag_name == tag_name {
      depth -= 1
      if depth == 0 {
        return Some(i)
      }
    }
  }
  None
}

///|
pub fn html_tokens_collect_element_ranges(
  events : Array[HtmlTokenEvent],
  tag_names : Array[String],
) -> Array[HtmlTokenSourceRange] {
  let wanted : Array[String] = []
  for name in tag_names {
    let normalized = name.to_lower().trim().to_owned()
    if normalized != "" {
      wanted.push(normalized)
    }
  }

  let ranges : Array[HtmlTokenSourceRange] = []
  for i in 0..<events.length() {
    let event = events[i]
    if event.kind == HtmlTokenEventKind::StartTag &&
      html_tag_name_is_in(event.tag_name, wanted) {
      match html_tokens_find_matching_close(events, i) {
        Some(close_i) =>
          ranges.push({
            source_start: event.source_start,
            source_end: events[close_i].source_end,
          })
        None => ()
      }
    }
  }
  ranges
}

///|
fn html_tag_name_is_in(tag_name : String, names : Array[String]) -> Bool {
  for name in names {
    if tag_name == name {
      return true
    }
  }
  false
}

///|
fn html_attr_scan_start(chars : Array[Char]) -> Int {
  let n = chars.length()
  let mut i = 0
  while i < n && chars[i] != '<' {
    i += 1
  }
  if i >= n {
    return 0
  }
  i += 1
  while i < n && is_html_space(chars[i]) {
    i += 1
  }
  if i < n && chars[i] == '/' {
    i += 1
  }
  while i < n && is_html_space(chars[i]) {
    i += 1
  }
  if i < n && is_html_name_start(chars[i]) {
    while i < n && is_html_name_char(chars[i]) {
      i += 1
    }
  }
  i
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
fn lower_ascii_html_string(text : String) -> String {
  let out : Array[Char] = []
  for ch in text {
    out.push(lower_ascii_html_char(ch))
  }
  String::from_array(out)
}

///|
fn is_html_space(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
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
