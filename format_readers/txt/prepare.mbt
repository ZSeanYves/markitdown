///|
pub struct PreparedTextSourceDocument {
  prepared_source : @input.InputSource
  original_text : String?
  document : TextDocument?
  inspect : TextInspectReport?
  parse_error : String?
}

///|
pub fn prepare_text_document_from_source(
  source : @input.InputSource,
) -> Result[PreparedTextSourceDocument, String] {
  let text_payload = match @sourceio.read_source_text_with_utf16_bom(source) {
    Ok(payload) => payload
    Err(err) =>
      return Ok({
        prepared_source: source,
        original_text: None,
        document: None,
        inspect: None,
        parse_error: Some(err),
      })
  }
  let document = parse_text_document_from_normalized_text(
    normalize_text_source(text_payload.text),
  )
  Ok({
    prepared_source: text_payload.prepared_source,
    original_text: Some(text_payload.text),
    document: Some(document),
    inspect: Some(inspect_text_document(document)),
    parse_error: None,
  })
}

///|
fn normalize_text_source(text : String) -> String {
  if !text_text_needs_shared_cleanup(text) {
    return text
  }
  let normalized = normalize_text_line_endings(text)
  normalize_text_low_risk_chars(normalized)
}

///|
fn text_text_needs_shared_cleanup(text : String) -> Bool {
  for ch in text {
    if ch == '\t' ||
      ch == '\r' ||
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
fn normalize_text_line_endings(text : String) -> String {
  let chars = text.to_array()
  let out = StringBuilder::new()
  let mut i = 0
  while i < chars.length() {
    let ch = chars[i]
    if ch == '\r' {
      if i + 1 < chars.length() && chars[i + 1] == '\n' {
        i += 1
      }
      out.write_char('\n')
    } else {
      out.write_char(ch)
    }
    i += 1
  }
  out.to_string()
}

///|
fn normalize_text_low_risk_chars(text : String) -> String {
  let out : Array[Char] = []
  let chars = text.to_array()
  let mut i = 0
  while i < chars.length() {
    let ch = chars[i]
    match ch {
      '\t' => out.push(' ')
      '\u{00A0}' => out.push(' ')
      '\u{00AD}' => ()
      '\u{2007}' => out.push(' ')
      '\u{2008}' => out.push(' ')
      '\u{2009}' => out.push(' ')
      '\u{200A}' => out.push(' ')
      '\u{202F}' => out.push(' ')
      '\u{205F}' => out.push(' ')
      '\u{3000}' => out.push(' ')
      '\u{200B}' => ()
      '\u{FEFF}' => ()
      'ﬀ' => {
        out.push('f')
        out.push('f')
      }
      'ﬁ' => {
        out.push('f')
        out.push('i')
      }
      'ﬂ' => {
        out.push('f')
        out.push('l')
      }
      'ﬃ' => {
        out.push('f')
        out.push('f')
        out.push('i')
      }
      'ﬄ' => {
        out.push('f')
        out.push('f')
        out.push('l')
      }
      'ﬅ' => {
        out.push('s')
        out.push('t')
      }
      'ﬆ' => {
        out.push('s')
        out.push('t')
      }
      _ => out.push(ch)
    }
    i += 1
  }
  String::from_array(out)
}
