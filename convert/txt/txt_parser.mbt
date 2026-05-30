///|
pub fn parse_txt(
  input_path : String,
  _out_dir : String,
  _max_heading : Int,
) -> @cor.Document raise {
  parse_txt_with_profile(input_path, _out_dir, _max_heading).0
}

///|
pub fn parse_txt_with_profile(
  input_path : String,
  _out_dir : String,
  _max_heading : Int,
) -> (@cor.Document, TxtProfileReport?) raise {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("txt: file not found: " + input_path)
  }

  let profile = if txt_profile_enabled() {
    Some(new_txt_profile_report(input_path))
  } else {
    None
  }

  let read_started = @env.now()
  let bytes = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("txt: read failed: " + e.to_string())
  }
  txt_profile_add_stage(
    profile,
    "txt_file_read",
    @env.now() - read_started,
    match profile {
      Some(_) => Some("bytes=" + bytes.length().to_string())
      None => None
    },
  )

  let decode_started = @env.now()
  let raw = decode_txt_utf8_text(bytes, input_path)
  txt_profile_add_stage(
    profile,
    "txt_bytes_to_string",
    @env.now() - decode_started,
    match profile {
      Some(_) => Some("chars=" + raw.length().to_string())
      None => None
    },
  )

  let normalize_started = @env.now()
  let text = normalize_txt_text(raw)
  txt_profile_add_stage(
    profile,
    "txt_normalize_newlines",
    @env.now() - normalize_started,
    match profile {
      Some(_) => Some("chars=" + text.length().to_string())
      None => None
    },
  )

  let doc = @cor.new_document()
  let src = @cor.basename(input_path)
  let split_started = @env.now()
  let parsed = @dptext.parse_text_document_from_normalized_text(text)
  let paragraphs = parsed.paragraphs
  txt_profile_add_stage(
    profile,
    "txt_split_paragraphs",
    @env.now() - split_started,
    match profile {
      Some(_) => Some("paragraphs=" + paragraphs.length().to_string())
      None => None
    },
  )

  let build_ir_started = @env.now()
  if paragraphs.length() > 0 {
    let literal_started = @env.now()
    @cor.set_passthrough_markdown(doc, txt_literal_markdown(paragraphs))
    txt_profile_add_stage(
      profile,
      "txt_literal_wrap",
      @env.now() - literal_started,
      match profile {
        Some(_) => Some("paragraphs=" + paragraphs.length().to_string())
        None => None
      },
    )
  } else {
    txt_profile_add_stage(
      profile,
      "txt_literal_wrap",
      0,
      match profile {
        Some(_) => Some("paragraphs=0")
        None => None
      },
    )
  }

  let origin_started = @env.now()
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
  txt_profile_add_stage(
    profile,
    "txt_origin_blocks",
    @env.now() - origin_started,
    match profile {
      Some(_) => Some("blocks=" + doc.blocks.val.length().to_string())
      None => None
    },
  )

  txt_profile_add_stage(
    profile,
    "txt_build_ir",
    @env.now() - build_ir_started,
    match profile {
      Some(_) => Some("blocks=" + doc.blocks.val.length().to_string())
      None => None
    },
  )

  (doc, profile)
}

///|
fn decode_txt_utf8_text(bytes : Bytes, _input_path : String) -> String raise {
  let decoded = @utf8.decode(bytes, ignore_bom=false) catch {
    _ => raise @cor.AppError("txt: utf8 decode failed")
  }

  if !contains_non_bmp_char(decoded) {
    return decoded
  }

  let out = StringBuilder::new()
  for ch in decoded.to_array() {
    let cp = ch.to_int()
    if cp > 0xFFFF {
      out.write_string("&#" + cp.to_string() + ";")
    } else {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn contains_non_bmp_char(text : String) -> Bool {
  for ch in text.to_array() {
    if ch.to_int() > 0xFFFF {
      return true
    }
  }
  false
}

///|
fn normalize_txt_text(text : String) -> String {
  if !txt_text_needs_shared_cleanup(text) {
    return text
  }
  @cor.normalize_document_text_cleanup(text)
}

///|
fn txt_text_needs_shared_cleanup(text : String) -> Bool {
  for ch in text {
    if ch == '\r' ||
      ch == '\u{00A0}' ||
      ch == '\u{00AD}' ||
      ch == '\u{2007}' ||
      ch == '\u{2008}' ||
      ch == '\u{2009}' ||
      ch == '\u{200A}' ||
      ch == '\u{202F}' ||
      ch == '\u{205F}' ||
      ch == '\u{3000}' ||
      ch == '\u{200B}' ||
      ch == '\u{FEFF}' ||
      ch == 'ﬀ' ||
      ch == 'ﬁ' ||
      ch == 'ﬂ' ||
      ch == 'ﬃ' ||
      ch == 'ﬄ' ||
      ch == 'ﬅ' ||
      ch == 'ﬆ' {
      return true
    }
  }
  false
}

///|
fn txt_literal_markdown(paragraphs : Array[@dptext.TextParagraph]) -> String {
  if paragraphs.length() == 0 {
    return ""
  }
  let out = StringBuilder::new()

  for i in 0..<paragraphs.length() {
    let body = escape_txt_paragraph(paragraphs[i].text)
    out.write_string(body)
    if i + 1 < paragraphs.length() {
      out.write_string("\n\n")
    }
  }
  out.write_char('\n')
  out.to_string()
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
