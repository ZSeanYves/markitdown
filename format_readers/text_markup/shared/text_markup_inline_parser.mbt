///|
pub fn parse_text_markup_inlines(
  text : String,
  format : TextMarkupFormat,
) -> Array[TextMarkupInline] {
  match format {
    TextMarkupFormat::Rst => parse_rst_inlines(text)
    TextMarkupFormat::Asciidoc => parse_asciidoc_inlines(text)
    TextMarkupFormat::Tex => parse_tex_inlines(text)
  }
}

///|
fn parse_rst_inlines(text : String) -> Array[TextMarkupInline] {
  let out : Array[TextMarkupInline] = []
  let chars = text.to_array()
  let mut i = 0
  let buffer : Array[Char] = []
  while i < chars.length() {
    match rst_consume_literal(chars, i) {
      Some((body, next)) => {
        flush_inline_text_chars(out, buffer)
        out.push({ kind: TextMarkupInlineKind::Code, text: body, href: None })
        i = next
        continue
      }
      None => ()
    }
    if chars[i] == '`' {
      match rst_consume_named_link(chars, i) {
        Some((label, href, next)) => {
          flush_inline_text_chars(out, buffer)
          out.push({
            kind: TextMarkupInlineKind::Link,
            text: label,
            href: Some(href),
          })
          i = next
          continue
        }
        None => ()
      }
    }
    if chars[i] == '`' {
      match consume_delimited(chars, i, '`', '`') {
        Some((body, next)) => {
          flush_inline_text_chars(out, buffer)
          out.push({ kind: TextMarkupInlineKind::Code, text: body, href: None })
          i = next
          continue
        }
        None => ()
      }
    }
    buffer.push(chars[i])
    i += 1
  }
  flush_inline_text_chars(out, buffer)
  out
}

///|
fn parse_asciidoc_inlines(text : String) -> Array[TextMarkupInline] {
  let out : Array[TextMarkupInline] = []
  let chars = text.to_array()
  let mut i = 0
  let buffer : Array[Char] = []
  while i < chars.length() {
    if chars[i] == '`' {
      match consume_delimited(chars, i, '`', '`') {
        Some((body, next)) => {
          flush_inline_text_chars(out, buffer)
          out.push({ kind: TextMarkupInlineKind::Code, text: body, href: None })
          i = next
          continue
        }
        None => ()
      }
    }
    match asciidoc_consume_link(chars, i) {
      Some((label, href, next)) => {
        flush_inline_text_chars(out, buffer)
        out.push({
          kind: TextMarkupInlineKind::Link,
          text: label,
          href: Some(href),
        })
        i = next
        continue
      }
      None => ()
    }
    buffer.push(chars[i])
    i += 1
  }
  flush_inline_text_chars(out, buffer)
  out
}

///|
fn parse_tex_inlines(text : String) -> Array[TextMarkupInline] {
  let out : Array[TextMarkupInline] = []
  let chars = text.to_array()
  let mut i = 0
  let buffer : Array[Char] = []
  while i < chars.length() {
    match tex_consume_link(chars, i) {
      Some((label, href, next)) => {
        flush_inline_text_chars(out, buffer)
        out.push({
          kind: TextMarkupInlineKind::Link,
          text: label,
          href: Some(href),
        })
        i = next
        continue
      }
      None => ()
    }
    match tex_consume_inline_code(chars, i) {
      Some((body, next)) => {
        flush_inline_text_chars(out, buffer)
        out.push({ kind: TextMarkupInlineKind::Code, text: body, href: None })
        i = next
        continue
      }
      None => ()
    }
    buffer.push(chars[i])
    i += 1
  }
  flush_inline_text_chars(out, buffer)
  out
}

///|
fn flush_inline_text_chars(
  out : Array[TextMarkupInline],
  chars : Array[Char],
) -> Unit {
  if chars.length() == 0 {
    return
  }
  out.push({
    kind: TextMarkupInlineKind::Text,
    text: String::from_array(chars[:]),
    href: None,
  })
  chars.clear()
}

///|
fn consume_delimited(
  chars : Array[Char],
  start : Int,
  open : Char,
  close : Char,
) -> (String, Int)? {
  if start >= chars.length() || chars[start] != open {
    return None
  }
  let mut i = start + 1
  let body : Array[Char] = []
  while i < chars.length() {
    if chars[i] == close {
      return Some((String::from_array(body), i + 1))
    }
    body.push(chars[i])
    i += 1
  }
  None
}

///|
fn rst_consume_named_link(
  chars : Array[Char],
  start : Int,
) -> (String, String, Int)? {
  if start >= chars.length() || chars[start] != '`' {
    return None
  }
  let mut i = start + 1
  let label : Array[Char] = []
  while i < chars.length() {
    if chars[i] == '<' {
      break
    }
    label.push(chars[i])
    i += 1
  }
  if i >= chars.length() || chars[i] != '<' {
    return None
  }
  i += 1
  let href : Array[Char] = []
  while i < chars.length() {
    if chars[i] == '>' {
      break
    }
    href.push(chars[i])
    i += 1
  }
  if i + 2 >= chars.length() ||
    chars[i] != '>' ||
    chars[i + 1] != '`' ||
    chars[i + 2] != '_' {
    return None
  }
  Some(
    (
      String::from_array(label).trim().to_owned(),
      String::from_array(href).trim().to_owned(),
      i + 3,
    ),
  )
}

///|
fn rst_consume_literal(chars : Array[Char], start : Int) -> (String, Int)? {
  if start + 1 >= chars.length() ||
    chars[start] != '`' ||
    chars[start + 1] != '`' {
    return None
  }
  let mut i = start + 2
  let body : Array[Char] = []
  while i + 1 < chars.length() {
    if chars[i] == '`' && chars[i + 1] == '`' {
      return Some((String::from_array(body), i + 2))
    }
    body.push(chars[i])
    i += 1
  }
  None
}

///|
fn asciidoc_consume_link(
  chars : Array[Char],
  start : Int,
) -> (String, String, Int)? {
  if !chars_match_literal(chars, start, "link:") {
    return None
  }
  let mut i = start + 5
  let href : Array[Char] = []
  while i < chars.length() && chars[i] != '[' {
    href.push(chars[i])
    i += 1
  }
  if i >= chars.length() || chars[i] != '[' {
    return None
  }
  i += 1
  let label : Array[Char] = []
  while i < chars.length() && chars[i] != ']' {
    label.push(chars[i])
    i += 1
  }
  if i >= chars.length() || chars[i] != ']' {
    return None
  }
  Some((String::from_array(label), String::from_array(href), i + 1))
}

///|
fn tex_consume_link(chars : Array[Char], start : Int) -> (String, String, Int)? {
  if !chars_match_literal(chars, start, "\\href{") {
    return None
  }
  let mut i = start + 6
  let href : Array[Char] = []
  while i < chars.length() && chars[i] != '}' {
    href.push(chars[i])
    i += 1
  }
  if i + 1 >= chars.length() || chars[i] != '}' || chars[i + 1] != '{' {
    return None
  }
  i += 2
  let label : Array[Char] = []
  while i < chars.length() && chars[i] != '}' {
    label.push(chars[i])
    i += 1
  }
  if i >= chars.length() || chars[i] != '}' {
    return None
  }
  Some((String::from_array(label), String::from_array(href), i + 1))
}

///|
fn tex_consume_inline_code(chars : Array[Char], start : Int) -> (String, Int)? {
  if !chars_match_literal(chars, start, "\\texttt{") {
    return None
  }
  let mut i = start + 8
  let body : Array[Char] = []
  while i < chars.length() && chars[i] != '}' {
    body.push(chars[i])
    i += 1
  }
  if i >= chars.length() || chars[i] != '}' {
    return None
  }
  Some((String::from_array(body), i + 1))
}

///|
fn chars_match_literal(
  chars : Array[Char],
  start : Int,
  literal : String,
) -> Bool {
  let needle = literal.to_array()
  if start + needle.length() > chars.length() {
    return false
  }
  for i in 0..<needle.length() {
    if chars[start + i] != needle[i] {
      return false
    }
  }
  true
}
