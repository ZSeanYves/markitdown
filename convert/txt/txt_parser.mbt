///|
pub fn parse_txt(
  input_path : String,
  _out_dir : String,
  _max_heading : Int,
) -> @cor.Document raise {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("txt: file not found: " + input_path)
  }

  let bytes = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("txt: read failed: " + e.to_string())
  }

  let raw = @cor.utf8_bytes_to_string(bytes) catch {
    e => raise @cor.AppError("txt: utf8 decode failed: " + e.to_string())
  }

  let text = normalize_txt_text(raw)
  let doc = @cor.new_document()
  let src = @cor.basename(input_path)
  let paragraphs = paragraph_spans(text)

  if paragraphs.length() > 0 {
    @cor.set_passthrough_markdown(doc, txt_literal_markdown(paragraphs))
  }

  for para in paragraphs {
    @cor.push_with_origin(
      doc,
      @cor.Block::Paragraph(para.text),
      Some({
        source_name: Some(src),
        page: None,
        slide: None,
        sheet: None,
        block_index: Some(doc.blocks.val.length()),
        heading_path: None,
        line_start: Some(para.line_start),
        line_end: Some(para.line_end),
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
priv struct ParagraphSpan {
  text : String
  line_start : Int
  line_end : Int
}

///|
fn normalize_txt_text(text : String) -> String {
  let without_bom = if text.length() > 0 && text[0] == '\u{FEFF}' {
    text[1:].to_owned()
  } else {
    text
  }

  let out : Array[Char] = []
  let chars = without_bom.to_array()
  let mut i = 0

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
fn paragraph_spans(text : String) -> Array[ParagraphSpan] {
  if text == "" {
    return []
  }

  let lines = split_lines_preserve_trailing(text)
  let out : Array[ParagraphSpan] = []
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

  out.push(String::from_array(line))
  out
}

///|
fn txt_literal_markdown(paragraphs : Array[ParagraphSpan]) -> String {
  let out = StringBuilder::new()

  for i in 0..<paragraphs.length() {
    let body = escape_txt_paragraph(paragraphs[i].text)
    out.write_string(body)
    if i + 1 < paragraphs.length() {
      out.write_string("\n\n")
    }
  }

  let built = out.to_string()
  if built == "" {
    ""
  } else {
    built + "\n"
  }
}

///|
fn escape_txt_paragraph(text : String) -> String {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return ""
  }

  match thematic_break_marker(trimmed) {
    Some(prefix) =>
      return "\\" +
        prefix +
        escape_markdown_punctuation(trimmed[prefix.length():].to_owned())
    None => ()
  }

  let chars = trimmed.to_array()
  let first = chars[0]

  if first == '#' || first == '>' {
    return "\\" +
      String::from_array([first]) +
      escape_markdown_punctuation(String::from_array(chars[1:].to_owned()))
  }

  if (first == '-' || first == '+' || first == '*') &&
    chars.length() >= 2 &&
    chars[1] == ' ' {
    return "\\" +
      String::from_array([first]) +
      escape_markdown_punctuation(String::from_array(chars[1:].to_owned()))
  }

  match ordered_list_marker_parts(trimmed) {
    Some((marker_index, suffix_index)) => {
      let out = StringBuilder::new()
      out.write_string(String::from_array(chars[:marker_index].to_owned()))
      out.write_string("\\")
      out.write_char(chars[marker_index])
      out.write_char(chars[suffix_index])
      out.write_string(
        escape_markdown_punctuation(
          String::from_array(chars[suffix_index + 1:].to_owned()),
        ),
      )
      out.to_string()
    }
    None => escape_markdown_punctuation(trimmed)
  }
}

///|
fn ordered_list_marker_parts(text : String) -> (Int, Int)? {
  let chars = text.to_array()
  let mut i = 0

  while i < chars.length() && is_ascii_digit(chars[i]) {
    i += 1
  }

  if i == 0 || i + 1 >= chars.length() {
    return None
  }

  if (chars[i] == '.' || chars[i] == ')') && chars[i + 1] == ' ' {
    Some((i, i + 1))
  } else {
    None
  }
}

///|
fn thematic_break_marker(text : String) -> String? {
  if text.length() < 3 {
    return None
  }

  let chars = text.to_array()
  let first = chars[0]
  if !(first == '-' || first == '*' || first == '_') {
    return None
  }

  for ch in chars {
    if ch != first {
      return None
    }
  }

  Some(String::from_array([first]))
}

///|
fn is_ascii_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn escape_markdown_punctuation(text : String) -> String {
  let out : Array[Char] = []

  for ch in text.to_array() {
    if should_escape_markdown_char(ch) {
      out.push('\\')
    }
    out.push(ch)
  }

  String::from_array(out)
}

///|
fn should_escape_markdown_char(ch : Char) -> Bool {
  ch == '\\' ||
  ch == '`' ||
  ch == '*' ||
  ch == '_' ||
  ch == '{' ||
  ch == '}' ||
  ch == '[' ||
  ch == ']' ||
  ch == '(' ||
  ch == ')' ||
  ch == '<' ||
  ch == '>' ||
  ch == '#'
}
