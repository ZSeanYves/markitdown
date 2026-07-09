///|
fn escape_markdown_inline_text(text : String) -> String {
  let out = StringBuilder::new()
  write_escaped_markdown_inline_text_to(out, text)
  out.to_string()
}

///|
fn write_escaped_markdown_inline_text_to(
  out : StringBuilder,
  text : String,
) -> Unit {
  for ch in text.to_array() {
    let cp = ch.to_int()
    if cp > 0xFFFF {
      out.write_string("&")
      out.write_char('#')
      out.write_string(cp.to_string())
      out.write_char(';')
      continue
    }
    if markdown_punctuation_needs_escape(ch) {
      out.write_char('\\')
    }
    out.write_char(ch)
  }
}

///|
fn escape_markdown_inline_text_for_format(
  text : String,
  escape_mode : String?,
) -> String {
  if escape_mode == Some("minimal") {
    return escape_markdown_inline_text_html(text)
  }
  escape_markdown_inline_text(text)
}

///|
fn write_escaped_markdown_inline_text_for_format_to(
  out : StringBuilder,
  text : String,
  escape_mode : String?,
) -> Unit {
  if escape_mode == Some("minimal") {
    write_escaped_markdown_inline_text_html_to(out, text)
  } else {
    write_escaped_markdown_inline_text_to(out, text)
  }
}

///|
fn escape_markdown_inline_text_html(text : String) -> String {
  let out = StringBuilder::new()
  write_escaped_markdown_inline_text_html_to(out, text)
  out.to_string()
}

///|
fn write_escaped_markdown_inline_text_html_to(
  out : StringBuilder,
  text : String,
) -> Unit {
  for ch in text.to_array() {
    if ch == '\\' || ch == '`' {
      out.write_char('\\')
    }
    out.write_char(ch)
  }
}

///|
fn safe_code_fence(text : String) -> String {
  let mut max_run = 0
  let mut current_run = 0
  for ch in text {
    if ch == '`' {
      current_run += 1
      if current_run > max_run {
        max_run = current_run
      }
    } else {
      current_run = 0
    }
  }
  let width = if max_run + 1 < 3 { 3 } else { max_run + 1 }
  repeat_char_string('`', width)
}

///|
fn safe_inline_code_fence(text : String) -> String {
  let mut max_run = 0
  let mut current_run = 0
  for ch in text {
    if ch == '`' {
      current_run += 1
      if current_run > max_run {
        max_run = current_run
      }
    } else {
      current_run = 0
    }
  }
  let width = if max_run + 1 < 1 { 1 } else { max_run + 1 }
  repeat_char_string('`', width)
}

///|
fn repeat_char_string(ch : Char, width : Int) -> String {
  if width <= 0 {
    return ""
  }
  let out = StringBuilder::new()
  for _ in 0..<width {
    out.write_char(ch)
  }
  out.to_string()
}

///|
fn render_literal_markdown_lines(text : String) -> Array[String] {
  let lines = text.split("\n").to_array()
  lines.map(line => escape_markdown_line_prefix(line.to_owned()))
}

///|
fn escape_markdown_line_prefix(text : String) -> String {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return ""
  }

  match thematic_break_marker(trimmed) {
    Some(prefix) =>
      return "\\" +
        prefix +
        escape_markdown_inline_text(trimmed[prefix.length():].to_owned())
    None => ()
  }

  let chars = trimmed.to_array()
  let first = chars[0]

  if first == '#' || first == '>' {
    return "\\" +
      String::from_array([first]) +
      escape_markdown_literal_tail(String::from_array(chars[1:].to_owned()))
  }

  if (first == '-' || first == '+' || first == '*') &&
    chars.length() >= 2 &&
    chars[1] == ' ' {
    return "\\" +
      String::from_array([first]) +
      escape_markdown_literal_tail(String::from_array(chars[1:].to_owned()))
  }

  match ordered_list_marker_parts(trimmed) {
    Some((marker_index, suffix_index)) => {
      let out = StringBuilder::new()
      out.write_string(String::from_array(chars[:marker_index].to_owned()))
      out.write_string("\\")
      out.write_char(chars[marker_index])
      out.write_char(chars[suffix_index])
      out.write_string(
        escape_markdown_literal_tail(
          String::from_array(chars[suffix_index + 1:].to_owned()),
        ),
      )
      out.to_string()
    }
    None => escape_markdown_literal_tail(trimmed)
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
fn escape_markdown_literal_tail(text : String) -> String {
  let out = StringBuilder::new()
  for ch in text.to_array() {
    let cp = ch.to_int()
    if cp > 0xFFFF {
      out.write_string("&")
      out.write_char('#')
      out.write_string(cp.to_string())
      out.write_char(';')
      continue
    }
    if markdown_literal_tail_needs_escape(ch) {
      out.write_char('\\')
    }
    out.write_char(ch)
  }
  out.to_string()
}

///|
fn markdown_punctuation_needs_escape(ch : Char) -> Bool {
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
  ch == '#' ||
  ch == '+' ||
  ch == '<' ||
  ch == '>' ||
  ch == '|'
}

///|
fn markdown_literal_tail_needs_escape(ch : Char) -> Bool {
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
  ch == '#' ||
  ch == '+' ||
  ch == '<' ||
  ch == '>' ||
  ch == '|'
}

///|
fn literal_text_block(block : @core.CoreBlock) -> Bool {
  block.attrs.get("literal") == Some("true")
}

///|
fn clamp_heading_level(raw : String) -> Int {
  let parsed = @string.parse_int(raw.trim()) catch { _ => 1 }
  if parsed < 1 {
    1
  } else if parsed > 6 {
    6
  } else {
    parsed
  }
}
