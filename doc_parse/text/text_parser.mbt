///|
/// Decode UTF-8 bytes and parse them into a normalized text document.
pub fn open_text_document(bytes : Bytes) -> TextDocument raise {
  let decoded = @utf8.decode(bytes, ignore_bom=false) catch {
    _ => raise TextError::Utf8DecodeFailed("invalid utf8")
  }
  let doc = parse_text_document(decoded)
  {
    text: doc.text,
    byte_count: Some(bytes.length()),
    newline_style: doc.newline_style,
    lines: doc.lines,
    paragraphs: doc.paragraphs,
  }
}

///|
/// Parse plain text that is already available as a `String`.
pub fn parse_text_document(text : String) -> TextDocument {
  let newline_style = detect_newline_style(text)
  let normalized = normalize_text_source(text)
  let line_strings = split_lines_preserve_trailing(normalized)
  let lines : Array[TextLine] = []
  for i in 0..<line_strings.length() {
    lines.push({ text: line_strings[i], line_no: i + 1 })
  }

  {
    text: normalized,
    byte_count: None,
    newline_style,
    lines,
    paragraphs: paragraph_spans(normalized),
  }
}

///|
/// Classify a hard text decoding failure into a stable error kind.
pub fn classify_text_error(err : TextError) -> TextErrorInfo {
  match err {
    Utf8DecodeFailed(detail) =>
      { kind: TextErrorKind::Utf8DecodeFailed, detail }
  }
}

///|
fn detect_newline_style(text : String) -> TextNewlineStyle {
  let chars = text.to_array()
  let mut saw_lf = false
  let mut saw_crlf = false
  let mut saw_cr = false
  let mut i = 0

  while i < chars.length() {
    if chars[i] == '\r' {
      if i + 1 < chars.length() && chars[i + 1] == '\n' {
        saw_crlf = true
        i += 2
      } else {
        saw_cr = true
        i += 1
      }
      continue
    }

    if chars[i] == '\n' {
      saw_lf = true
    }
    i += 1
  }

  let count = bool_to_int(saw_lf) + bool_to_int(saw_crlf) + bool_to_int(saw_cr)
  if count == 0 {
    TextNewlineStyle::None
  } else if count > 1 {
    TextNewlineStyle::Mixed
  } else if saw_crlf {
    TextNewlineStyle::CRLF
  } else if saw_cr {
    TextNewlineStyle::CR
  } else {
    TextNewlineStyle::LF
  }
}

///|
fn normalize_text_source(text : String) -> String {
  let chars = text.to_array()
  let out : Array[Char] = []
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

  String::from_array(out)
}

///|
fn paragraph_spans(text : String) -> Array[TextParagraph] {
  if text == "" {
    return []
  }

  let lines = split_lines_preserve_trailing(text)
  let out : Array[TextParagraph] = []
  let current : Array[String] = []
  let mut line_start = 0
  let mut line_end = 0

  for i in 0..<lines.length() {
    let line_no = i + 1
    let trimmed = lines[i].trim().to_owned()
    if trimmed == "" {
      if current.length() > 0 {
        out.push({ text: current.join(" "), line_start, line_end })
        current.clear()
        line_start = 0
        line_end = 0
      }
      continue
    }

    if current.length() == 0 {
      line_start = line_no
    }
    current.push(trimmed)
    line_end = line_no
  }

  if current.length() > 0 {
    out.push({ text: current.join(" "), line_start, line_end })
  }

  out
}

///|
fn split_lines_preserve_trailing(text : String) -> Array[String] {
  if text == "" {
    return []
  }

  let out : Array[String] = []
  let line : Array[Char] = []

  for ch in text.to_array() {
    if ch == '\n' {
      out.push(String::from_array(line))
      line.clear()
    } else {
      line.push(ch)
    }
  }

  if line.length() > 0 || !text.has_suffix("\n") {
    out.push(String::from_array(line))
  }
  out
}

///|
fn bool_to_int(value : Bool) -> Int {
  if value {
    1
  } else {
    0
  }
}
