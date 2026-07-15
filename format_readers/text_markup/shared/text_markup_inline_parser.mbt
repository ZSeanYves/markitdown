///|
pub fn parse_text_markup_inlines(
  text : String,
  format : TextMarkupFormat,
) -> Array[TextMarkupInline] {
  match format {
    Rst => parse_rst_inlines(text)
    Asciidoc => parse_asciidoc_inlines(text)
    Tex => parse_tex_inlines(text)
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
        out.push({ kind: Code, text: body, href: None })
        i = next
        continue
      }
      None => ()
    }
    match rst_consume_note_reference(chars, i) {
      Some((label, next)) => {
        flush_inline_text_chars(out, buffer)
        out.push({
          kind: Link,
          text: "[" + label + "]",
          href: Some("#" + label),
        })
        i = next
        continue
      }
      None => ()
    }
    if chars[i] == '`' {
      match rst_consume_named_link(chars, i) {
        Some((label, href, next)) => {
          flush_inline_text_chars(out, buffer)
          out.push({ kind: Link, text: label, href: Some(href) })
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
          out.push({ kind: Code, text: body, href: None })
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
          out.push({ kind: Code, text: body, href: None })
          i = next
          continue
        }
        None => ()
      }
    }
    match asciidoc_consume_link(chars, i) {
      Some((label, href, next)) => {
        flush_inline_text_chars(out, buffer)
        out.push({ kind: Link, text: label, href: Some(href) })
        i = next
        continue
      }
      None => ()
    }
    match asciidoc_consume_xref(chars, i) {
      Some((label, href, next)) => {
        flush_inline_text_chars(out, buffer)
        out.push({ kind: Link, text: label, href: Some(href) })
        i = next
        continue
      }
      None => ()
    }
    match consume_command_argument(chars, i, "footnote:[", ']') {
      Some((body, next)) => {
        flush_inline_text_chars(out, buffer)
        out.push({ kind: Text, text: body, href: None })
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
        out.push({ kind: Link, text: label, href: Some(href) })
        i = next
        continue
      }
      None => ()
    }
    match tex_consume_inline_code(chars, i) {
      Some((body, next)) => {
        flush_inline_text_chars(out, buffer)
        out.push({ kind: Code, text: body, href: None })
        i = next
        continue
      }
      None => ()
    }
    match tex_consume_reference(chars, i) {
      Some((label, href, next)) => {
        flush_inline_text_chars(out, buffer)
        out.push({ kind: Link, text: label, href: Some(href) })
        i = next
        continue
      }
      None => ()
    }
    match consume_command_argument(chars, i, "\\footnote{", '}') {
      Some((body, next)) => {
        flush_inline_text_chars(out, buffer)
        out.push({ kind: Text, text: body, href: None })
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
  out.push({ kind: Text, text: String::from_array(chars[:]), href: None })
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
fn rst_consume_note_reference(
  chars : Array[Char],
  start : Int,
) -> (String, Int)? {
  if start >= chars.length() || chars[start] != '[' {
    return None
  }
  let label : Array[Char] = []
  let mut i = start + 1
  while i < chars.length() && chars[i] != ']' {
    label.push(chars[i])
    i += 1
  }
  if label.length() == 0 || i + 1 >= chars.length() || chars[i + 1] != '_' {
    return None
  }
  Some((String::from_array(label), i + 2))
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
fn asciidoc_consume_xref(
  chars : Array[Char],
  start : Int,
) -> (String, String, Int)? {
  let prefix = if chars_match_literal(chars, start, "xref:") {
    "xref:"
  } else if chars_match_literal(chars, start, "<<") {
    "<<"
  } else {
    return None
  }
  if prefix == "xref:" {
    let mut i = start + prefix.length()
    let target : Array[Char] = []
    while i < chars.length() && chars[i] != '[' {
      target.push(chars[i])
      i += 1
    }
    if i >= chars.length() || chars[i] != '[' {
      return None
    }
    let label : Array[Char] = []
    i += 1
    while i < chars.length() && chars[i] != ']' {
      label.push(chars[i])
      i += 1
    }
    if i >= chars.length() {
      return None
    }
    let target_text = String::from_array(target)
    let label_text = String::from_array(label)
    return Some(
      (
        if label_text == "" {
          target_text
        } else {
          label_text
        },
        "#" + target_text,
        i + 1,
      ),
    )
  }
  let mut i = start + 2
  let target : Array[Char] = []
  let label : Array[Char] = []
  let mut reading_label = false
  while i + 1 < chars.length() {
    if chars[i] == '>' && chars[i + 1] == '>' {
      let target_text = String::from_array(target).trim().to_owned()
      let label_text = String::from_array(label).trim().to_owned()
      if target_text == "" {
        return None
      }
      return Some(
        (
          if label_text == "" {
            target_text
          } else {
            label_text
          },
          "#" + target_text,
          i + 2,
        ),
      )
    }
    if chars[i] == ',' && !reading_label {
      reading_label = true
    } else if reading_label {
      label.push(chars[i])
    } else {
      target.push(chars[i])
    }
    i += 1
  }
  None
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
fn tex_consume_reference(
  chars : Array[Char],
  start : Int,
) -> (String, String, Int)? {
  for command in ["\\url{", "\\ref{", "\\pageref{", "\\cite{"] {
    match consume_command_argument(chars, start, command, '}') {
      Some((body, next)) => {
        let label = if command == "\\cite{" { "[" + body + "]" } else { body }
        let href = if command == "\\url{" { body } else { "#" + body }
        return Some((label, href, next))
      }
      None => ()
    }
  }
  None
}

///|
fn consume_command_argument(
  chars : Array[Char],
  start : Int,
  prefix : String,
  close : Char,
) -> (String, Int)? {
  if !chars_match_literal(chars, start, prefix) {
    return None
  }
  let mut i = start + prefix.length()
  let body : Array[Char] = []
  while i < chars.length() && chars[i] != close {
    body.push(chars[i])
    i += 1
  }
  if i >= chars.length() {
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
