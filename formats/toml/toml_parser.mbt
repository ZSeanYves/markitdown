///|
/// Parse TOML text into a source-native document model.
pub fn parse_toml_document(text : String) -> TomlDocument raise {
  let parser = new_toml_parser(text)
  parser.parse_document()
}

///|
/// Classify a hard TOML parse failure into a stable error kind.
pub fn classify_toml_error(err : TomlError) -> TomlErrorInfo {
  let detail = err.to_string().to_lower()
  let kind = if detail.contains("unexpected end") {
    TomlErrorKind::UnexpectedEnd
  } else if detail.contains("trailing content") {
    TrailingContent
  } else if detail.contains("duplicate key") {
    DuplicateKey
  } else if detail.contains("invalid header") {
    InvalidHeader
  } else if detail.contains("invalid key") {
    InvalidKey
  } else if detail.contains("invalid escape") {
    InvalidEscape
  } else if detail.contains("unterminated") || detail.contains("invalid string") {
    InvalidString
  } else if detail.contains("invalid value") {
    InvalidValue
  } else if detail.contains("expected ") {
    ExpectedToken
  } else if detail.contains("unsupported") {
    UnsupportedFeature
  } else {
    Unknown
  }
  { kind, detail: err.to_string() }
}

///|
priv struct TomlParser {
  chars : Array[Char]
  mut pos : Int
  mut line : Int
  root_members : Array[TomlMember]
  root_member_keys : Map[String, Bool]
  tables : Array[TomlTable]
  table_index_by_path : Map[String, Int]
  table_member_keys : Map[String, Map[String, Bool]]
  array_item_count_by_base_path : Map[String, Int]
  mut current_table_path : String
  mut current_table_segments : Array[String]
  mut current_table_index : Int?
  mut current_member_keys : Map[String, Bool]
}

///|
fn new_toml_parser(text : String) -> TomlParser {
  {
    chars: normalize_toml_chars(text),
    pos: 0,
    line: 1,
    root_members: [],
    root_member_keys: Map([]),
    tables: [],
    table_index_by_path: Map([]),
    table_member_keys: Map([]),
    array_item_count_by_base_path: Map([]),
    current_table_path: "/",
    current_table_segments: [],
    current_table_index: None,
    current_member_keys: Map([]),
  }
}

///|
fn TomlParser::parse_document(self : TomlParser) -> TomlDocument raise {
  self.skip_ws_and_comments()
  while !self.is_eof() {
    if self.peek_char() == Some('[') {
      self.parse_table_header()
    } else {
      self.parse_key_value()
    }
    self.skip_ws_and_comments()
  }
  { root_members: self.root_members, tables: self.tables }
}

///|
fn TomlParser::parse_table_header(self : TomlParser) -> Unit raise {
  let start_line = self.line
  self.expect_char('[')
  let is_array = self.consume_char('[')
  let segments = self.parse_key_segments(false)
  if segments.length() == 0 {
    raise ParseError("invalid header at line " + start_line.to_string())
  }
  if is_array {
    self.expect_char(']')
  }
  self.expect_char(']')
  self.skip_inline_comment_then_line_end()
  let table_path = toml_segments_to_path(segments)
  if is_array {
    let item_index = self.array_item_count_by_base_path
      .get(table_path)
      .unwrap_or(0)
    let indexed_path = table_path + "[" + item_index.to_string() + "]"
    let indexed_segments = toml_append_array_item_segment(segments, item_index)
    let next_index = self.tables.length()
    self.tables.push({
      path: indexed_path,
      segments: indexed_segments,
      members: [],
      line_start: start_line,
      line_end: start_line,
      is_array_item: true,
    })
    self.table_index_by_path.set(indexed_path, next_index)
    let member_keys : Map[String, Bool] = Map([])
    self.table_member_keys.set(indexed_path, member_keys)
    self.array_item_count_by_base_path.set(table_path, item_index + 1)
    self.current_table_path = indexed_path
    self.current_table_segments = indexed_segments
    self.current_table_index = Some(next_index)
    self.current_member_keys = member_keys
    return
  }

  match self.table_index_by_path.get(table_path) {
    Some(index) =>
      if !self.tables[index].is_array_item {
        raise ParseError(
          "duplicate key table at line " +
          start_line.to_string() +
          ": " +
          table_path,
        )
      }
    None => ()
  }
  let next_index = self.tables.length()
  self.tables.push({
    path: table_path,
    segments,
    members: [],
    line_start: start_line,
    line_end: start_line,
    is_array_item: false,
  })
  self.table_index_by_path.set(table_path, next_index)
  let member_keys : Map[String, Bool] = Map([])
  self.table_member_keys.set(table_path, member_keys)
  self.current_table_path = table_path
  self.current_table_segments = segments
  self.current_table_index = Some(next_index)
  self.current_member_keys = member_keys
}

///|
fn TomlParser::parse_key_value(self : TomlParser) -> Unit raise {
  let line_start = self.line
  let key_segments = self.parse_key_segments(true)
  if key_segments.length() == 0 {
    raise ParseError("invalid key at line " + self.line.to_string())
  }
  self.skip_spaces()
  self.expect_char('=')
  self.skip_spaces()
  let value = self.parse_value()
  let line_end = value.1
  let (target_path, key_name, full_segments, member_path) = self.resolve_member_path(
    key_segments,
  )
  let entry = {
    key: key_name,
    segments: full_segments,
    path: member_path,
    value: value.0,
    line_start,
    line_end,
  }
  self.insert_member(target_path, entry) catch {
    e => raise e
  }
  self.skip_inline_comment_then_line_end()
}

///|
fn TomlParser::resolve_member_path(
  self : TomlParser,
  key_segments : Array[String],
) -> (String, String, Array[String], String) {
  let full_segments : Array[String] = []
  full_segments.append(self.current_table_segments[:])
  full_segments.append(key_segments[:])
  let key_name = key_segments[key_segments.length() - 1]
  let member_path = toml_segments_to_path(full_segments)
  if key_segments.length() == 1 {
    return (self.current_table_path, key_name, full_segments, member_path)
  }
  let target_segments : Array[String] = []
  target_segments.append(self.current_table_segments[:])
  for i in 0..<(key_segments.length() - 1) {
    target_segments.push(key_segments[i])
  }
  (toml_segments_to_path(target_segments), key_name, full_segments, member_path)
}

///|
fn TomlParser::insert_member(
  self : TomlParser,
  target_path : String,
  entry : TomlMember,
) -> Unit raise {
  if target_path == "/" {
    if self.root_member_keys.contains(entry.key) {
      raise ParseError(
        "duplicate key at line " +
        entry.line_start.to_string() +
        ": " +
        entry.path,
      )
    }
    self.root_members.push(entry)
    self.root_member_keys.set(entry.key, true)
    return
  }
  if target_path == self.current_table_path {
    match self.current_table_index {
      Some(target_index) => {
        if self.current_member_keys.contains(entry.key) {
          raise ParseError(
            "duplicate key at line " +
            entry.line_start.to_string() +
            ": " +
            entry.path,
          )
        }
        self.tables[target_index].members.push(entry)
        self.current_member_keys.set(entry.key, true)
        if entry.line_end > self.tables[target_index].line_end {
          self.tables[target_index].line_end = entry.line_end
        }
        return
      }
      None => ()
    }
  }
  let target_index = self.find_or_create_table(target_path)
  let table_keys = self.ensure_table_member_keys(target_path)
  if table_keys.contains(entry.key) {
    raise ParseError(
      "duplicate key at line " +
      entry.line_start.to_string() +
      ": " +
      entry.path,
    )
  }
  self.tables[target_index].members.push(entry)
  table_keys.set(entry.key, true)
  if entry.line_end > self.tables[target_index].line_end {
    self.tables[target_index].line_end = entry.line_end
  }
}

///|
fn TomlParser::find_or_create_table(
  self : TomlParser,
  target_path : String,
) -> Int {
  match self.table_index_by_path.get(target_path) {
    Some(index) => index
    None => {
      let segments = toml_path_to_segments(target_path)
      let next_index = self.tables.length()
      self.tables.push({
        path: target_path,
        segments,
        members: [],
        line_start: self.line,
        line_end: self.line,
        is_array_item: false,
      })
      self.table_index_by_path.set(target_path, next_index)
      self.table_member_keys.set(target_path, Map([]))
      next_index
    }
  }
}

///|
fn TomlParser::ensure_table_member_keys(
  self : TomlParser,
  target_path : String,
) -> Map[String, Bool] {
  match self.table_member_keys.get(target_path) {
    Some(keys) => keys
    None => {
      let keys : Map[String, Bool] = Map([])
      self.table_member_keys.set(target_path, keys)
      keys
    }
  }
}

///|
fn TomlParser::parse_key_segments(
  self : TomlParser,
  stop_on_dot : Bool,
) -> Array[String] raise {
  let out : Array[String] = []
  while true {
    self.skip_spaces()
    out.push(self.parse_single_key())
    self.skip_spaces()
    if stop_on_dot {
      if self.peek_char() == Some('.') {
        self.advance_char()
        continue
      }
      break
    }
    if self.peek_char() == Some('.') {
      self.advance_char()
      continue
    }
    break
  }
  out
}

///|
fn TomlParser::parse_single_key(self : TomlParser) -> String raise {
  match self.peek_char() {
    Some('"') => self.parse_basic_string_single_line()
    Some('\'') => self.parse_literal_string_single_line()
    Some(ch) =>
      if toml_is_bare_key_char(ch) {
        self.parse_bare_key()
      } else {
        raise ParseError("invalid key at line " + self.line.to_string())
      }
    None => raise ParseError("unexpected end of input while parsing key")
  }
}

///|
fn TomlParser::parse_bare_key(self : TomlParser) -> String {
  let out : Array[Char] = []
  while true {
    match self.peek_char() {
      Some(ch) if toml_is_bare_key_char(ch) => {
        out.push(ch)
        self.advance_char()
      }
      _ => break
    }
  }
  String::from_array(out)
}

///|
fn TomlParser::parse_value(self : TomlParser) -> (TomlValue, Int) raise {
  match self.peek_char() {
    Some('"') =>
      if self.starts_with("\"\"\"") {
        let value = self.parse_multiline_basic_string()
        (String(value.0), value.1)
      } else {
        let value = self.parse_basic_string_single_line()
        (String(value), self.line)
      }
    Some('\'') =>
      if self.starts_with("'''") {
        let value = self.parse_multiline_literal_string()
        (String(value.0), value.1)
      } else {
        let value = self.parse_literal_string_single_line()
        (String(value), self.line)
      }
    Some('[') => {
      let value = self.parse_array()
      (Array(value.0), value.1)
    }
    Some('{') => {
      let value = self.parse_inline_table()
      (InlineTable(value.0), value.1)
    }
    Some(_) => {
      let scalar = self.parse_scalar_token()
      (toml_scalar_value_from_token(scalar.0, self.line), scalar.1)
    }
    None => raise ParseError("unexpected end of input while parsing value")
  }
}

///|
fn TomlParser::parse_array(self : TomlParser) -> (Array[TomlValue], Int) raise {
  let values : Array[TomlValue] = []
  let start_line = self.line
  self.expect_char('[')
  self.skip_ws_and_comments_inside_array()
  if self.consume_char(']') {
    return (values, self.line)
  }
  while true {
    self.skip_ws_and_comments_inside_array()
    let value = self.parse_value()
    values.push(value.0)
    self.skip_ws_and_comments_inside_array()
    if self.consume_char(',') {
      self.skip_ws_and_comments_inside_array()
      if self.peek_char() == Some(']') {
        self.advance_char()
        return (values, self.line)
      }
      continue
    }
    self.expect_char(']')
    return (values, self.line)
  }
  (values, start_line)
}

///|
fn TomlParser::parse_inline_table(
  self : TomlParser,
) -> (Array[TomlMember], Int) raise {
  let members : Array[TomlMember] = []
  let member_keys : Map[String, Bool] = Map([])
  let start_line = self.line
  self.expect_char('{')
  self.skip_spaces()
  if self.consume_char('}') {
    return (members, self.line)
  }
  while true {
    let key_segments = self.parse_key_segments(true)
    self.skip_spaces()
    self.expect_char('=')
    self.skip_spaces()
    let value = self.parse_value()
    let member_path = toml_segments_to_path(key_segments)
    let member_key = key_segments[key_segments.length() - 1]
    if member_keys.contains(member_key) {
      raise ParseError(
        "duplicate key at line " + start_line.to_string() + ": " + member_path,
      )
    }
    members.push({
      key: member_key,
      segments: key_segments,
      path: member_path,
      value: value.0,
      line_start: start_line,
      line_end: value.1,
    })
    member_keys.set(member_key, true)
    self.skip_spaces()
    if self.consume_char(',') {
      self.skip_spaces()
      continue
    }
    self.expect_char('}')
    return (members, self.line)
  }
  (members, start_line)
}

///|
fn TomlParser::parse_scalar_token(self : TomlParser) -> (String, Int) raise {
  let out : Array[Char] = []
  let mut nesting = 0
  while true {
    match self.peek_char() {
      Some('\n') | Some('\r') => break
      Some('#') if nesting == 0 => break
      Some(',') if nesting == 0 => break
      Some(']') if nesting == 0 => break
      Some('}') if nesting == 0 => break
      Some(ch) => {
        if ch == '[' || ch == '{' {
          nesting += 1
        }
        if ch == ']' || ch == '}' {
          if nesting > 0 {
            nesting -= 1
          }
        }
        out.push(ch)
        self.advance_char()
      }
      None => break
    }
  }
  let token = String::from_array(out).trim().to_owned()
  if token == "" {
    raise ParseError("invalid value at line " + self.line.to_string())
  }
  (token, self.line)
}

///|
fn TomlParser::parse_basic_string_single_line(
  self : TomlParser,
) -> String raise {
  self.expect_char('"')
  let out : Array[Char] = []
  while true {
    match self.peek_char() {
      Some('"') => {
        self.advance_char()
        return String::from_array(out)
      }
      Some('\\') => {
        self.advance_char()
        out.push(self.parse_basic_escape())
      }
      Some('\n') | Some('\r') =>
        raise ParseError(
          "invalid string newline at line " + self.line.to_string(),
        )
      Some(ch) => {
        out.push(ch)
        self.advance_char()
      }
      None => raise ParseError("unterminated basic string")
    }
  }
  ""
}

///|
fn TomlParser::parse_literal_string_single_line(
  self : TomlParser,
) -> String raise {
  self.expect_char('\'')
  let out : Array[Char] = []
  while true {
    match self.peek_char() {
      Some('\'') => {
        self.advance_char()
        return String::from_array(out)
      }
      Some('\n') | Some('\r') =>
        raise ParseError(
          "invalid string newline at line " + self.line.to_string(),
        )
      Some(ch) => {
        out.push(ch)
        self.advance_char()
      }
      None => raise ParseError("unterminated literal string")
    }
  }
  ""
}

///|
fn TomlParser::parse_multiline_basic_string(
  self : TomlParser,
) -> (String, Int) raise {
  self.expect_literal("\"\"\"")
  if self.peek_char() == Some('\n') {
    self.advance_char()
  }
  let out : Array[Char] = []
  while true {
    if self.starts_with("\"\"\"") {
      self.expect_literal("\"\"\"")
      return (String::from_array(out), self.line)
    }
    match self.peek_char() {
      Some('\\') => {
        self.advance_char()
        match self.peek_char() {
          Some('\n') => {
            self.advance_char()
            self.skip_spaces()
          }
          Some('\r') => {
            self.advance_char()
            if self.peek_char() == Some('\n') {
              self.advance_char()
            }
            self.skip_spaces()
          }
          Some(' ') | Some('\t') => {
            self.skip_spaces()
            match self.peek_char() {
              Some('\n') => {
                self.advance_char()
                self.skip_spaces()
              }
              Some('\r') => {
                self.advance_char()
                if self.peek_char() == Some('\n') {
                  self.advance_char()
                }
                self.skip_spaces()
              }
              _ => out.push('\\')
            }
          }
          _ => out.push(self.parse_basic_escape())
        }
      }
      Some(ch) => {
        out.push(ch)
        self.advance_char()
      }
      None => raise ParseError("unterminated multiline basic string")
    }
  }
  (String::from_array(out), self.line)
}

///|
fn TomlParser::parse_multiline_literal_string(
  self : TomlParser,
) -> (String, Int) raise {
  self.expect_literal("'''")
  if self.peek_char() == Some('\n') {
    self.advance_char()
  }
  let out : Array[Char] = []
  while true {
    if self.starts_with("'''") {
      self.expect_literal("'''")
      return (String::from_array(out), self.line)
    }
    match self.peek_char() {
      Some(ch) => {
        out.push(ch)
        self.advance_char()
      }
      None => raise ParseError("unterminated multiline literal string")
    }
  }
  (String::from_array(out), self.line)
}

///|
fn TomlParser::parse_basic_escape(self : TomlParser) -> Char raise {
  match self.peek_char() {
    Some('"') => {
      self.advance_char()
      '"'
    }
    Some('\\') => {
      self.advance_char()
      '\\'
    }
    Some('b') => {
      self.advance_char()
      '\b'
    }
    Some('t') => {
      self.advance_char()
      '\t'
    }
    Some('n') => {
      self.advance_char()
      '\n'
    }
    Some('f') => {
      self.advance_char()
      '\u{000C}'
    }
    Some('r') => {
      self.advance_char()
      '\r'
    }
    Some('u') => {
      self.advance_char()
      toml_parse_unicode_escape(self, 4)
    }
    Some('U') => {
      self.advance_char()
      toml_parse_unicode_escape(self, 8)
    }
    _ => raise ParseError("invalid escape at line " + self.line.to_string())
  }
}

///|
fn TomlParser::skip_ws_and_comments(self : TomlParser) -> Unit {
  while true {
    self.skip_spaces_and_newlines()
    if self.peek_char() == Some('#') {
      self.skip_comment()
      continue
    }
    break
  }
}

///|
fn TomlParser::skip_ws_and_comments_inside_array(self : TomlParser) -> Unit {
  while true {
    self.skip_spaces_and_newlines()
    if self.peek_char() == Some('#') {
      self.skip_comment()
      continue
    }
    break
  }
}

///|
fn TomlParser::skip_inline_comment_then_line_end(
  self : TomlParser,
) -> Unit raise {
  self.skip_spaces()
  if self.peek_char() == Some('#') {
    self.skip_comment()
  }
  match self.peek_char() {
    Some('\n') => {
      self.advance_char()
      ()
    }
    Some('\r') => {
      self.advance_char()
      if self.peek_char() == Some('\n') {
        self.advance_char()
      }
    }
    None => ()
    Some(_) =>
      raise ParseError("trailing content at line " + self.line.to_string())
  }
}

///|
fn TomlParser::skip_comment(self : TomlParser) -> Unit {
  while true {
    match self.peek_char() {
      Some('\n') | Some('\r') | None => return
      Some(_) => self.advance_char()
    }
  }
}

///|
fn TomlParser::skip_spaces(self : TomlParser) -> Unit {
  while true {
    match self.peek_char() {
      Some(' ') | Some('\t') => self.advance_char()
      _ => break
    }
  }
}

///|
fn TomlParser::skip_spaces_and_newlines(self : TomlParser) -> Unit {
  while true {
    match self.peek_char() {
      Some(' ') | Some('\t') | Some('\n') | Some('\r') => self.advance_char()
      _ => break
    }
  }
}

///|
fn TomlParser::starts_with(self : TomlParser, prefix : String) -> Bool {
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
fn TomlParser::expect_literal(
  self : TomlParser,
  literal : String,
) -> Unit raise {
  if !self.starts_with(literal) {
    raise ParseError(
      "expected " + literal + " at line " + self.line.to_string(),
    )
  }
  for _ in literal.to_array() {
    self.advance_char()
  }
}

///|
fn TomlParser::expect_char(self : TomlParser, ch : Char) -> Unit raise {
  match self.peek_char() {
    Some(next) if next == ch => self.advance_char()
    _ =>
      raise ParseError(
        "expected '" +
        String::from_array([ch]) +
        "' at line " +
        self.line.to_string(),
      )
  }
}

///|
fn TomlParser::consume_char(self : TomlParser, ch : Char) -> Bool {
  match self.peek_char() {
    Some(next) if next == ch => {
      self.advance_char()
      true
    }
    _ => false
  }
}

///|
fn TomlParser::peek_char(self : TomlParser) -> Char? {
  if self.pos >= self.chars.length() {
    None
  } else {
    Some(self.chars[self.pos])
  }
}

///|
fn TomlParser::advance_char(self : TomlParser) -> Unit {
  if self.pos >= self.chars.length() {
    return
  }
  let ch = self.chars[self.pos]
  self.pos += 1
  if ch == '\n' {
    self.line += 1
  } else if ch == '\r' {
    self.line += 1
    if self.pos < self.chars.length() && self.chars[self.pos] == '\n' {
      self.pos += 1
    }
  }
}

///|
fn TomlParser::is_eof(self : TomlParser) -> Bool {
  self.pos >= self.chars.length()
}

///|
fn normalize_toml_chars(text : String) -> Array[Char] {
  let chars = text.to_array()
  if chars.length() > 0 && chars[0] == '\u{FEFF}' {
    chars[1:].to_owned()
  } else {
    chars
  }
}

///|
fn toml_parse_unicode_escape(parser : TomlParser, digits : Int) -> Char raise {
  let mut value = 0
  for _ in 0..<digits {
    let ch = match parser.peek_char() {
      Some(next) => next
      None =>
        raise ParseError("invalid escape at line " + parser.line.to_string())
    }
    value = value * 16 +
      (toml_hex_value(ch) catch {
        _ =>
          raise ParseError("invalid escape at line " + parser.line.to_string())
      })
    parser.advance_char()
  }
  Int::unsafe_to_char(value)
}

///|
fn toml_hex_value(ch : Char) -> Int raise {
  if ch >= '0' && ch <= '9' {
    return ch.to_int() - '0'.to_int()
  }
  if ch >= 'a' && ch <= 'f' {
    return 10 + ch.to_int() - 'a'.to_int()
  }
  if ch >= 'A' && ch <= 'F' {
    return 10 + ch.to_int() - 'A'.to_int()
  }
  raise ParseError("invalid hex digit")
}

///|
fn toml_scalar_value_from_token(token : String, line : Int) -> TomlValue raise {
  let lower = token.to_lower()
  if lower == "true" {
    return Bool(true)
  }
  if lower == "false" {
    return Bool(false)
  }
  if toml_token_is_datetime(token) {
    return Datetime(token)
  }
  if toml_token_is_float(token) {
    return Float(token)
  }
  if toml_token_is_integer(token) {
    return Integer(token)
  }
  raise ParseError("invalid value at line " + line.to_string())
}

///|
fn toml_token_is_datetime(token : String) -> Bool {
  toml_token_is_offset_datetime(token) ||
  toml_token_is_local_datetime(token) ||
  toml_token_is_local_date(token) ||
  toml_token_is_local_time(token)
}

///|
fn toml_token_is_float(token : String) -> Bool {
  let lower = token.to_lower()
  if lower == "inf" || lower == "+inf" || lower == "-inf" {
    return true
  }
  if lower == "nan" || lower == "+nan" || lower == "-nan" {
    return true
  }
  let chars = token.to_array()
  let mut exponent_index : Int? = None
  for index in 0..<chars.length() {
    if chars[index] == 'e' || chars[index] == 'E' {
      if exponent_index is Some(_) {
        return false
      }
      exponent_index = Some(index)
    }
  }
  let mantissa_end = exponent_index.unwrap_or(chars.length())
  if exponent_index is Some(index) {
    let mut exponent_start = index + 1
    if exponent_start < chars.length() &&
      (chars[exponent_start] == '+' || chars[exponent_start] == '-') {
      exponent_start += 1
    }
    if !toml_decimal_digits_with_underscores(
        chars,
        exponent_start,
        chars.length(),
      ) {
      return false
    }
  }
  let mut mantissa_start = 0
  if mantissa_start < mantissa_end &&
    (chars[mantissa_start] == '+' || chars[mantissa_start] == '-') {
    mantissa_start += 1
  }
  let mut dot_index : Int? = None
  for index in mantissa_start..<mantissa_end {
    if chars[index] == '.' {
      if dot_index is Some(_) {
        return false
      }
      dot_index = Some(index)
    }
  }
  match dot_index {
    Some(index) =>
      toml_decimal_integer_body(chars, mantissa_start, index) &&
      toml_decimal_digits_with_underscores(chars, index + 1, mantissa_end)
    None =>
      exponent_index is Some(_) &&
      toml_decimal_integer_body(chars, mantissa_start, mantissa_end)
  }
}

///|
fn toml_token_is_integer(token : String) -> Bool {
  if token == "" {
    return false
  }
  let chars = token.to_array()
  if chars.length() >= 2 && chars[0] == '0' {
    match chars[1] {
      'x' => return toml_based_digits_with_underscores(chars, 2, 16)
      'o' => return toml_based_digits_with_underscores(chars, 2, 8)
      'b' => return toml_based_digits_with_underscores(chars, 2, 2)
      _ => ()
    }
  }
  let start = if chars[0] == '+' || chars[0] == '-' { 1 } else { 0 }
  toml_decimal_integer_body(chars, start, chars.length())
}

///|
fn toml_decimal_integer_body(
  chars : Array[Char],
  start : Int,
  end_ : Int,
) -> Bool {
  if !toml_decimal_digits_with_underscores(chars, start, end_) {
    return false
  }
  let digits = chars[start:end_].filter(ch => ch != '_')
  digits.length() == 1 || digits[0] != '0'
}

///|
fn toml_decimal_digits_with_underscores(
  chars : Array[Char],
  start : Int,
  end_ : Int,
) -> Bool {
  toml_digits_with_underscores(chars, start, end_, 10)
}

///|
fn toml_based_digits_with_underscores(
  chars : Array[Char],
  start : Int,
  base : Int,
) -> Bool {
  toml_digits_with_underscores(chars, start, chars.length(), base)
}

///|
fn toml_digits_with_underscores(
  chars : Array[Char],
  start : Int,
  end_ : Int,
  base : Int,
) -> Bool {
  if start >= end_ || chars[start] == '_' || chars[end_ - 1] == '_' {
    return false
  }
  let mut previous_underscore = false
  for index in start..<end_ {
    let ch = chars[index]
    if ch == '_' {
      if previous_underscore {
        return false
      }
      previous_underscore = true
      continue
    }
    let valid = if ch >= '0' && ch <= '9' {
      ch.to_int() - '0'.to_int() < base
    } else if base == 16 && ch >= 'a' && ch <= 'f' {
      true
    } else {
      base == 16 && ch >= 'A' && ch <= 'F'
    }
    if !valid {
      return false
    }
    previous_underscore = false
  }
  true
}

///|
fn toml_token_is_offset_datetime(token : String) -> Bool {
  if token.has_suffix("Z") || token.has_suffix("z") {
    return toml_token_is_local_datetime(toml_without_suffix_char(token))
  }
  let split = toml_split_offset_suffix(token)
  match split {
    Some((head, offset)) =>
      toml_token_is_local_datetime(head) && toml_is_time_offset(offset)
    None => false
  }
}

///|
fn toml_token_is_local_datetime(token : String) -> Bool {
  match toml_split_datetime_separator(token) {
    Some((date_part, time_part)) =>
      toml_token_is_local_date(date_part) && toml_token_is_local_time(time_part)
    None => false
  }
}

///|
fn toml_token_is_local_date(token : String) -> Bool {
  let parts = token.split("-").to_array()
  if parts.length() != 3 {
    return false
  }
  let year = parts[0].to_owned()
  let month = parts[1].to_owned()
  let day = parts[2].to_owned()
  if year.length() != 4 || month.length() != 2 || day.length() != 2 {
    return false
  }
  if !toml_digits_only(year) ||
    !toml_digits_only(month) ||
    !toml_digits_only(day) {
    return false
  }
  let month_value = toml_parse_decimal(month)
  let day_value = toml_parse_decimal(day)
  if month_value < 1 || month_value > 12 || day_value < 1 {
    return false
  }
  let year_value = toml_parse_decimal(year)
  day_value <= toml_days_in_month(year_value, month_value)
}

///|
fn toml_days_in_month(year : Int, month : Int) -> Int {
  match month {
    2 =>
      if year % 400 == 0 || (year % 4 == 0 && year % 100 != 0) {
        29
      } else {
        28
      }
    4 | 6 | 9 | 11 => 30
    _ => 31
  }
}

///|
fn toml_token_is_local_time(token : String) -> Bool {
  let (body, fraction) = match token.split_once(".") {
    Some((head, tail)) => (head.to_owned(), Some(tail.to_owned()))
    None => (token, None)
  }
  let parts = body.split(":").to_array()
  if parts.length() != 2 && parts.length() != 3 {
    return false
  }
  let hour = parts[0].to_owned()
  let minute = parts[1].to_owned()
  if hour.length() != 2 || minute.length() != 2 {
    return false
  }
  if !toml_digits_only(hour) || !toml_digits_only(minute) {
    return false
  }
  let hour_value = toml_parse_decimal(hour)
  let minute_value = toml_parse_decimal(minute)
  if hour_value < 0 || hour_value > 23 || minute_value < 0 || minute_value > 59 {
    return false
  }
  if parts.length() == 3 {
    let second = parts[2].to_owned()
    if second.length() != 2 || !toml_digits_only(second) {
      return false
    }
    let second_value = toml_parse_decimal(second)
    if second_value < 0 || second_value > 59 {
      return false
    }
  }
  match fraction {
    Some(frac) => frac != "" && toml_digits_only(frac)
    None => true
  }
}

///|
fn toml_split_datetime_separator(token : String) -> (String, String)? {
  let chars = token.to_array()
  if chars.length() < 11 {
    return None
  }
  let separator = chars[10]
  if separator != 'T' && separator != 't' && separator != ' ' {
    return None
  }
  Some(
    (
      toml_slice_chars(chars, 0, 10),
      toml_slice_chars(chars, 11, chars.length()),
    ),
  )
}

///|
fn toml_split_offset_suffix(token : String) -> (String, String)? {
  let chars = token.to_array()
  if chars.length() < 6 {
    return None
  }
  for i in 1..<chars.length() {
    let ch = chars[i]
    if ch == '+' || ch == '-' {
      let suffix = toml_slice_chars(chars, i, chars.length())
      if toml_is_time_offset(suffix) {
        let prefix = toml_slice_chars(chars, 0, i)
        return Some((prefix, suffix))
      }
    }
  }
  None
}

///|
fn toml_is_time_offset(token : String) -> Bool {
  let chars = token.to_array()
  if chars.length() != 6 {
    return false
  }
  if chars[0] != '+' && chars[0] != '-' {
    return false
  }
  if chars[3] != ':' {
    return false
  }
  let hour = toml_slice_chars(chars, 1, 3)
  let minute = toml_slice_chars(chars, 4, 6)
  if !toml_digits_only(hour) || !toml_digits_only(minute) {
    return false
  }
  let hour_value = toml_parse_decimal(hour)
  let minute_value = toml_parse_decimal(minute)
  hour_value >= 0 && hour_value <= 23 && minute_value >= 0 && minute_value <= 59
}

///|
fn toml_digits_only(token : String) -> Bool {
  if token == "" {
    return false
  }
  for ch in token.to_array() {
    if ch < '0' || ch > '9' {
      return false
    }
  }
  true
}

///|
fn toml_parse_decimal(token : String) -> Int {
  let mut value = 0
  for ch in token.to_array() {
    value = value * 10 + (ch.to_int() - '0'.to_int())
  }
  value
}

///|
fn toml_without_suffix_char(token : String) -> String {
  let chars = token.to_array()
  toml_slice_chars(chars, 0, chars.length() - 1)
}

///|
fn toml_slice_chars(chars : Array[Char], start : Int, end_ : Int) -> String {
  let out : Array[Char] = []
  for i in start..<end_ {
    out.push(chars[i])
  }
  String::from_array(out)
}

///|
fn toml_segments_to_path(segments : Array[String]) -> String {
  if segments.length() == 0 {
    return "/"
  }
  "/" + segments.join("/")
}

///|
fn toml_path_to_segments(path : String) -> Array[String] {
  if path == "/" || path == "" {
    return []
  }
  let raw = path.split("/").to_array()
  let out : Array[String] = []
  for item in raw {
    if item != "" {
      out.push(item.to_owned())
    }
  }
  out
}

///|
fn toml_append_array_item_segment(
  segments : Array[String],
  item_index : Int,
) -> Array[String] {
  let out = segments.copy()
  if out.length() == 0 {
    return out
  }
  let last_index = out.length() - 1
  out[last_index] = out[last_index] + "[" + item_index.to_string() + "]"
  out
}

///|
fn toml_is_bare_key_char(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') ||
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= '0' && ch <= '9') ||
  ch == '_' ||
  ch == '-'
}
