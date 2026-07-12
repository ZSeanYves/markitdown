///|
pub fn lower_subtitle_inline_markup(text : String) -> (String, Bool) {
  if !text.contains("<") && !text.contains("&") {
    return (text, false)
  }
  let chars = text.to_array()
  let out = StringBuilder::new()
  let mut changed = false
  let mut i = 0
  while i < chars.length() {
    if chars[i] != '<' {
      out.write_char(chars[i])
      i += 1
      continue
    }
    let mut end = i + 1
    while end < chars.length() && chars[end] != '>' {
      end += 1
    }
    if end >= chars.length() {
      out.write_char(chars[i])
      i += 1
      continue
    }
    let tag_chars : Array[Char] = []
    for index in (i + 1)..<end {
      tag_chars.push(chars[index])
    }
    let tag = String::from_array(tag_chars).trim().to_owned()
    match subtitle_inline_tag_replacement(tag) {
      Some(replacement) => {
        out.write_string(replacement)
        changed = true
      }
      None =>
        for index in i..<=end {
          out.write_char(chars[index])
        }
    }
    i = end + 1
  }
  let lowered = out
    .to_string()
    .replace_all(old="&amp;", new="&")
    .replace_all(old="&lt;", new="<")
    .replace_all(old="&gt;", new=">")
    .replace_all(old="&quot;", new="\"")
    .replace_all(old="&#39;", new="'")
  (lowered, changed || lowered != text)
}

///|
fn subtitle_inline_tag_replacement(tag : String) -> String? {
  let lowered = tag.to_lower()
  match lowered {
    "b" | "/b" => Some("**")
    "i" | "/i" => Some("*")
    "u" => Some("<u>")
    "/u" => Some("</u>")
    "ruby" | "/ruby" => Some("")
    "rt" => Some(" (")
    "/rt" => Some(")")
    "/v" | "/c" | "/lang" | "/font" => Some("")
    _ => {
      if lowered.has_prefix("v ") {
        let voice = tag[2:].trim().to_owned()
        return Some(if voice == "" { "" } else { voice + ": " })
      }
      if lowered == "c" ||
        lowered.has_prefix("c.") ||
        lowered.has_prefix("lang ") ||
        lowered.has_prefix("font ") {
        return Some("")
      }
      if subtitle_inline_timestamp_tag(lowered) {
        return Some("")
      }
      None
    }
  }
}

///|
fn subtitle_inline_timestamp_tag(tag : String) -> Bool {
  if tag == "" || !tag.contains(":") {
    return false
  }
  for ch in tag {
    if (ch < '0' || ch > '9') && ch != ':' && ch != '.' && ch != ',' {
      return false
    }
  }
  true
}
