///|
fn docx_footnote_note_id(index : Int) -> String {
  index.to_string()
}

///|
fn docx_endnote_note_id(index : Int) -> String {
  "e" + index.to_string()
}

///|
fn make_docx_footnote_note_ref(
  index : Int,
  source_id : Int,
  notes : DocxNoteBundle?,
) -> @cor.NoteRef {
  let resolved = match notes {
    Some(bundle) => bundle.footnotes_by_id.contains(source_id)
    None => false
  }
  {
    note_id: docx_footnote_note_id(index),
    marker: index.to_string(),
    kind: @cor.NoteKind::Footnote,
    source_kind: @cor.NoteSourceKind::DocxFootnoteRef,
    confidence: @cor.NoteConfidence::High,
    body_status: if resolved {
      @cor.NoteBodyStatus::Resolved
    } else {
      @cor.NoteBodyStatus::Missing
    },
  }
}

///|
fn make_docx_endnote_note_ref(
  index : Int,
  source_id : Int,
  notes : DocxNoteBundle?,
) -> @cor.NoteRef {
  let resolved = match notes {
    Some(bundle) => bundle.endnotes_by_id.contains(source_id)
    None => false
  }
  {
    note_id: docx_endnote_note_id(index),
    marker: "e" + index.to_string(),
    kind: @cor.NoteKind::Endnote,
    source_kind: @cor.NoteSourceKind::DocxEndnoteRef,
    confidence: @cor.NoteConfidence::High,
    body_status: if resolved {
      @cor.NoteBodyStatus::Resolved
    } else {
      @cor.NoteBodyStatus::Missing
    },
  }
}

///|
fn normalize_docx_note_marker_spacing_text(text : String) -> String {
  let chars = text.to_array()
  let out : Array[Char] = []
  let mut i = 0

  while i < chars.length() {
    let marker_end = docx_note_marker_end(chars, i)
    if marker_end > i {
      let moved_space = trim_trailing_ascii_whitespace_before_note_marker(out)
      if moved_space &&
        has_only_ascii_whitespace_after_docx_note_marker(chars, marker_end) {
        out.push(' ')
      }
      for j in i..<marker_end {
        out.push(chars[j])
      }
      if marker_end < chars.length() &&
        should_insert_space_after_docx_note_marker_char(chars[marker_end]) {
        out.push(' ')
      }
      i = marker_end
      continue
    }

    out.push(chars[i])
    i = i + 1
  }

  String::from_array(out)
}

///|
fn docx_note_marker_end(chars : Array[Char], start : Int) -> Int {
  if start + 3 >= chars.length() ||
    chars[start] != '[' ||
    chars[start + 1] != '^' {
    return -1
  }

  let mut i = start + 2
  if chars[i] == 'e' {
    i = i + 1
    if i >= chars.length() {
      return -1
    }
  }

  let digits_start = i
  while i < chars.length() {
    let ch = chars[i]
    if ch < '0' || ch > '9' {
      break
    }
    i = i + 1
  }
  if i == digits_start || i >= chars.length() || chars[i] != ']' {
    return -1
  }

  i + 1
}

///|
fn trim_trailing_ascii_whitespace_before_note_marker(out : Array[Char]) -> Bool {
  if out.length() == 0 {
    return false
  }

  let mut trim_idx = out.length()
  while trim_idx > 0 {
    let ch = out[trim_idx - 1]
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      trim_idx = trim_idx - 1
    } else {
      break
    }
  }

  if trim_idx == out.length() || trim_idx == 0 {
    return false
  }

  let prev = out[trim_idx - 1]
  if prev == ' ' || prev == '\t' || prev == '\n' || prev == '\r' {
    return false
  }

  out.truncate(trim_idx)
  true
}

///|
fn has_only_ascii_whitespace_after_docx_note_marker(
  chars : Array[Char],
  start : Int,
) -> Bool {
  let mut i = start
  while i < chars.length() {
    let ch = chars[i]
    if !(ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r') {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn should_insert_space_after_docx_note_marker_char(ch : Char) -> Bool {
  !(ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' || ch == '[') &&
  !is_docx_inline_follow_punctuation(ch)
}

///|
fn normalize_docx_note_marker_spacing_inlines(
  inlines : Array[@cor.Inline],
) -> Array[@cor.Inline] {
  let out : Array[@cor.Inline] = []
  let mut pending_space_after_note = false
  let mut i = 0

  while i < inlines.length() {
    let inline = inlines[i]
    match inline {
      @cor.Inline::Text(text) if is_docx_note_marker_text(text) => {
        let moved_space = trim_trailing_docx_whitespace_from_last_text_inline(
          out,
        )
        if moved_space &&
          remaining_docx_inlines_are_whitespace_only(inlines, i + 1) {
          out.push(@cor.Inline::Text(" "))
          pending_space_after_note = false
        }
        out.push(inline)
        if !(moved_space &&
          remaining_docx_inlines_are_whitespace_only(inlines, i + 1)) {
          pending_space_after_note = moved_space
        }
      }
      @cor.Inline::NoteRef(_note) => {
        let moved_space = trim_trailing_docx_whitespace_from_last_text_inline(
          out,
        )
        if moved_space &&
          remaining_docx_inlines_are_whitespace_only(inlines, i + 1) {
          out.push(@cor.Inline::Text(" "))
          pending_space_after_note = false
        }
        out.push(inline)
        if !(moved_space &&
          remaining_docx_inlines_are_whitespace_only(inlines, i + 1)) {
          pending_space_after_note = moved_space
        }
      }
      @cor.Inline::Text(text) => {
        let mut emitted = text
        if pending_space_after_note {
          if is_whitespace_only_docx_text(text) {
            pending_space_after_note = false
          } else if should_insert_space_after_docx_note_marker(text) {
            emitted = " " + text
            pending_space_after_note = false
          } else {
            pending_space_after_note = false
          }
        }
        out.push(@cor.Inline::Text(emitted))
      }
      @cor.Inline::Link(text, href) => {
        if pending_space_after_note &&
          should_insert_space_after_docx_note_marker(text) {
          out.push(@cor.Inline::Text(" "))
        }
        pending_space_after_note = false
        out.push(@cor.Inline::Link(text, href))
      }
      _ => {
        pending_space_after_note = false
        out.push(inline)
      }
    }
    i = i + 1
  }

  out
}

///|
fn trim_trailing_docx_whitespace_from_last_text_inline(
  out : Array[@cor.Inline],
) -> Bool {
  if out.length() == 0 {
    return false
  }

  let last = out.length() - 1
  match out[last] {
    @cor.Inline::Text(text) => {
      let trimmed = trim_trailing_docx_inline_whitespace(text)
      if trimmed == text {
        false
      } else {
        out[last] = @cor.Inline::Text(trimmed)
        true
      }
    }
    _ => false
  }
}

///|
fn trim_trailing_docx_inline_whitespace(text : String) -> String {
  let chars = text.to_array()
  let mut end = chars.length()
  while end > 0 {
    let ch = chars[end - 1]
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      end = end - 1
    } else {
      break
    }
  }
  if end == chars.length() {
    text
  } else {
    String::from_array(chars[:end])
  }
}

///|
fn remaining_docx_inlines_are_whitespace_only(
  inlines : Array[@cor.Inline],
  start : Int,
) -> Bool {
  let mut i = start
  while i < inlines.length() {
    match inlines[i] {
      @cor.Inline::Text(text) =>
        if is_whitespace_only_docx_text(text) {
          i = i + 1
          continue
        } else {
          return false
        }
      _ => return false
    }
  }
  true
}

///|
fn should_insert_space_after_docx_note_marker(next_text : String) -> Bool {
  if next_text == "" {
    return false
  }

  let chars = next_text.to_array()
  if chars.length() == 0 {
    return false
  }

  let first = chars[0]
  if first == ' ' ||
    first == '\t' ||
    first == '\n' ||
    first == '\r' ||
    first == '[' {
    return false
  }

  !is_docx_inline_follow_punctuation(first)
}

///|
fn should_insert_space_after_comment_marker(
  out : Array[@cor.Inline],
  next_text : String,
) -> Bool {
  if next_text == "" || out.length() == 0 {
    return false
  }

  let last_text = match out[out.length() - 1] {
    @cor.Inline::Text(text) => text
    _ => return false
  }
  if !is_docx_comment_marker_text(last_text) {
    return false
  }

  let chars = next_text.to_array()
  if chars.length() == 0 {
    return false
  }
  let first = chars[0]
  if first == ' ' || first == '\t' || first == '\n' || first == '\r' {
    return false
  }

  !is_docx_inline_follow_punctuation(first)
}

///|
fn docx_comment_marker_text(index : Int, prev_text : String?) -> String {
  let prefix = if docx_inline_needs_space_before_comment_marker(prev_text) {
    " "
  } else {
    ""
  }
  prefix + "[comment " + index.to_string() + "]"
}

///|
fn docx_inline_needs_space_before_comment_marker(prev_text : String?) -> Bool {
  match prev_text {
    Some(text) =>
      match last_non_empty_char(text) {
        Some(ch) => !(ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r')
        None => false
      }
    None => false
  }
}

///|
fn last_inline_text_for_spacing(out : Array[@cor.Inline]) -> String? {
  if out.length() == 0 {
    return None
  }

  let mut i = out.length()
  while i > 0 {
    i = i - 1
    match out[i] {
      @cor.Inline::Text(text) =>
        if is_whitespace_only_docx_text(text) {
          continue
        } else {
          return Some(text)
        }
      @cor.Inline::NoteRef(note) =>
        return Some(docx_note_ref_display_text(note))
      _ => return None
    }
  }

  None
}

///|
fn docx_note_ref_display_text(note : @cor.NoteRef) -> String {
  if note.body_status == @cor.NoteBodyStatus::Resolved &&
    note.note_id.trim() != "" {
    return "[^" + note.note_id.trim().to_owned() + "]"
  }

  if note.marker.trim() == "" {
    return ""
  }

  if note.marker.has_prefix("^") {
    note.marker
  } else {
    "^" + note.marker
  }
}

///|
fn last_non_empty_char(text : String) -> Char? {
  let chars = text.to_array()
  if chars.length() == 0 {
    return None
  }
  Some(chars[chars.length() - 1])
}

///|
fn is_whitespace_only_docx_text(text : String) -> Bool {
  if text == "" {
    return false
  }

  for ch in text {
    if !(ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r') {
      return false
    }
  }

  true
}

///|
fn is_docx_comment_marker_text(text : String) -> Bool {
  text.contains("[comment ") && text.has_suffix("]")
}

///|
fn is_docx_note_marker_text(text : String) -> Bool {
  if !text.has_prefix("[^") || !text.has_suffix("]") {
    return false
  }

  let inner = text[2:text.length() - 1]
  if inner == "" {
    return false
  }

  let chars = inner.to_array()
  let mut i = 0
  if chars[0] == 'e' {
    if chars.length() == 1 {
      return false
    }
    i = 1
  }
  while i < chars.length() {
    let ch = chars[i]
    if ch < '0' || ch > '9' {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn is_docx_inline_follow_punctuation(ch : Char) -> Bool {
  ch == '.' ||
  ch == ',' ||
  ch == ';' ||
  ch == ':' ||
  ch == '!' ||
  ch == '?' ||
  ch == ')' ||
  ch == ']' ||
  ch == '}' ||
  ch == '，' ||
  ch == '。' ||
  ch == '；' ||
  ch == '：' ||
  ch == '！' ||
  ch == '？' ||
  ch == '）' ||
  ch == '】' ||
  ch == '》'
}
