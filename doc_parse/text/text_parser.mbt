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
  parse_text_document_with_profile(text, None, None)
}

///|
/// Parse plain text that is already normalized to LF-only line endings and has
/// already passed shared low-risk cleanup.
pub fn parse_text_document_from_normalized_text(text : String) -> TextDocument {
  parse_normalized_text_document_with_profile(text, None, None)
}

///|
/// Benchmark-oriented profiled parse helper used for internal hotspot
/// attribution.
///
/// This does not change the source-native text model or converter behavior.
pub fn profile_text_document(text : String) -> TextProfiledDocument {
  let report = new_text_parse_profile_report()
  let totals = new_text_parse_profile_totals()
  let document = parse_text_document_with_profile(
    text,
    Some(report),
    Some(totals),
  )
  text_parse_profile_finish_totals(Some(report), Some(totals))
  { document, report }
}

///|
/// Benchmark-oriented profiled parse helper for LF-normalized text that has
/// already gone through shared cleanup.
pub fn profile_text_document_from_normalized_text(
  text : String,
) -> TextProfiledDocument {
  let report = new_text_parse_profile_report()
  let totals = new_text_parse_profile_totals()
  let document = parse_normalized_text_document_with_profile(
    text,
    Some(report),
    Some(totals),
  )
  text_parse_profile_finish_totals(Some(report), Some(totals))
  { document, report }
}

///|
fn parse_text_document_with_profile(
  text : String,
  profile : TextParseProfileReport?,
  profile_totals : TextParseProfileTotals?,
) -> TextDocument {
  let chars = text.to_array()
  let normalized_chars : Array[Char] = []
  let lines : Array[TextLine] = []
  let paragraphs : Array[TextParagraph] = []
  let current_paragraph : Array[String] = []
  let line_chars : Array[Char] = []
  let line_start : Ref[Int] = { val: 0 }
  let line_end : Ref[Int] = { val: 0 }
  let mut line_no = 1
  let mut saw_lf = false
  let mut saw_crlf = false
  let mut saw_cr = false
  let mut i = 0

  if chars.length() > 0 && chars[0] == '\u{FEFF}' {
    i = 1
  }

  let newline_started = text_parse_profile_stage_started(profile)
  while i < chars.length() {
    let ch = chars[i]
    if ch == '\r' {
      if i + 1 < chars.length() && chars[i + 1] == '\n' {
        saw_crlf = true
        i += 2
      } else {
        saw_cr = true
        i += 1
      }
      normalized_chars.push('\n')
      finish_text_line(
        line_chars, line_no, lines, current_paragraph, paragraphs, line_start, line_end,
        profile_totals,
      )
      line_chars.clear()
      line_no += 1
      continue
    }

    if ch == '\n' {
      saw_lf = true
      i += 1
      normalized_chars.push('\n')
      finish_text_line(
        line_chars, line_no, lines, current_paragraph, paragraphs, line_start, line_end,
        profile_totals,
      )
      line_chars.clear()
      line_no += 1
      continue
    }

    normalized_chars.push(ch)
    line_chars.push(ch)
    i += 1
  }
  let newline_style = summarize_text_newline_style(saw_lf, saw_crlf, saw_cr)
  text_parse_profile_stage_finished(
    profile,
    "newline_scan",
    newline_started,
    Some("style=" + text_newline_style_name(newline_style)),
  )

  if line_chars.length() > 0 ||
    (
      normalized_chars.length() > 0 &&
      normalized_chars[normalized_chars.length() - 1] != '\n'
    ) {
    finish_text_line(
      line_chars, line_no, lines, current_paragraph, paragraphs, line_start, line_end,
      profile_totals,
    )
  }
  flush_text_paragraph(
    current_paragraph, paragraphs, line_start, line_end, profile_totals,
  )

  build_text_document_from_chars(
    text, normalized_chars, newline_style, lines, paragraphs, profile,
  )
}

///|
fn parse_normalized_text_document_with_profile(
  text : String,
  profile : TextParseProfileReport?,
  profile_totals : TextParseProfileTotals?,
) -> TextDocument {
  let chars = text.to_array()
  let lines : Array[TextLine] = []
  let paragraphs : Array[TextParagraph] = []
  let current_paragraph : Array[String] = []
  let line_chars : Array[Char] = []
  let line_start : Ref[Int] = { val: 0 }
  let line_end : Ref[Int] = { val: 0 }
  let mut line_no = 1

  let newline_started = text_parse_profile_stage_started(profile)
  for ch in chars {
    if ch == '\n' {
      finish_text_line(
        line_chars, line_no, lines, current_paragraph, paragraphs, line_start, line_end,
        profile_totals,
      )
      line_chars.clear()
      line_no += 1
    } else {
      line_chars.push(ch)
    }
  }
  text_parse_profile_stage_finished(
    profile,
    "newline_scan",
    newline_started,
    Some("style=lf_normalized"),
  )

  if line_chars.length() > 0 ||
    (chars.length() > 0 && chars[chars.length() - 1] != '\n') {
    finish_text_line(
      line_chars, line_no, lines, current_paragraph, paragraphs, line_start, line_end,
      profile_totals,
    )
  }
  flush_text_paragraph(
    current_paragraph, paragraphs, line_start, line_end, profile_totals,
  )

  build_text_document_from_chars(
    text,
    chars,
    TextNewlineStyle::LF,
    lines,
    paragraphs,
    profile,
  )
}

///|
fn build_text_document_from_chars(
  original_text : String,
  normalized_chars : Array[Char],
  newline_style : TextNewlineStyle,
  lines : Array[TextLine],
  paragraphs : Array[TextParagraph],
  profile : TextParseProfileReport?,
) -> TextDocument {
  let build_started = text_parse_profile_stage_started(profile)
  let normalized = if text_chars_equal_string(normalized_chars, original_text) {
    original_text
  } else {
    String::from_array(normalized_chars)
  }
  let doc = {
    text: normalized,
    byte_count: None,
    newline_style,
    lines,
    paragraphs,
  }
  text_parse_profile_stage_finished(
    profile,
    "build_document",
    build_started,
    Some("chars=" + doc.text.length().to_string()),
  )
  doc
}

///|
fn text_chars_equal_string(chars : Array[Char], text : String) -> Bool {
  let original = text.to_array()
  if chars.length() != original.length() {
    return false
  }
  for i in 0..<chars.length() {
    if chars[i] != original[i] {
      return false
    }
  }
  true
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
fn text_newline_style_name(style : TextNewlineStyle) -> String {
  match style {
    TextNewlineStyle::None => "none"
    TextNewlineStyle::LF => "lf"
    TextNewlineStyle::CRLF => "crlf"
    TextNewlineStyle::CR => "cr"
    TextNewlineStyle::Mixed => "mixed"
  }
}

///|
fn summarize_text_newline_style(
  saw_lf : Bool,
  saw_crlf : Bool,
  saw_cr : Bool,
) -> TextNewlineStyle {
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
fn finish_text_line(
  line_chars : Array[Char],
  line_no : Int,
  lines : Array[TextLine],
  current_paragraph : Array[String],
  paragraphs : Array[TextParagraph],
  line_start : Ref[Int],
  line_end : Ref[Int],
  profile_totals : TextParseProfileTotals?,
) -> Unit {
  let line_started = match profile_totals {
    Some(_) => @env.now()
    None => 0
  }
  let line_total = match profile_totals {
    Some(totals) => Some(totals.line_build_elapsed_ms)
    None => None
  }
  let line_text = String::from_array(line_chars)
  lines.push({ text: line_text, line_no })
  text_parse_profile_add_elapsed(line_total, line_started)

  let paragraph_started = match profile_totals {
    Some(_) => @env.now()
    None => 0
  }
  let paragraph_total = match profile_totals {
    Some(totals) => Some(totals.paragraph_build_elapsed_ms)
    None => None
  }
  let trimmed = line_text.trim().to_owned()
  if trimmed == "" {
    flush_text_paragraph(
      current_paragraph,
      paragraphs,
      line_start,
      line_end,
      None,
    )
  } else {
    if current_paragraph.length() == 0 {
      line_start.val = line_no
    }
    current_paragraph.push(trimmed)
    line_end.val = line_no
  }
  text_parse_profile_add_elapsed(paragraph_total, paragraph_started)
}

///|
fn flush_text_paragraph(
  current_paragraph : Array[String],
  paragraphs : Array[TextParagraph],
  line_start : Ref[Int],
  line_end : Ref[Int],
  profile_totals : TextParseProfileTotals?,
) -> Unit {
  if current_paragraph.length() == 0 {
    return
  }
  let paragraph_started = match profile_totals {
    Some(_) => @env.now()
    None => 0
  }
  let paragraph_total = match profile_totals {
    Some(totals) => Some(totals.paragraph_build_elapsed_ms)
    None => None
  }
  paragraphs.push({
    text: current_paragraph.join(" "),
    line_start: line_start.val,
    line_end: line_end.val,
  })
  current_paragraph.clear()
  line_start.val = 0
  line_end.val = 0
  text_parse_profile_add_elapsed(paragraph_total, paragraph_started)
}

///|
fn bool_to_int(value : Bool) -> Int {
  if value {
    1
  } else {
    0
  }
}
