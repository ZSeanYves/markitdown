///|
pub fn inspect_text_document(doc : TextDocument) -> TextInspectReport {
  let char_count = doc.text.to_array().length()
  let mut empty_line_count = 0
  let mut non_blank_char_count = 0

  for line in doc.lines {
    if line.text.trim() == "" {
      empty_line_count += 1
    } else {
      non_blank_char_count += line.text.trim().to_array().length()
    }
  }

  {
    byte_count: doc.byte_count,
    char_count,
    line_count: doc.lines.length(),
    paragraph_count: doc.paragraphs.length(),
    empty_line_count,
    newline_style: doc.newline_style,
    is_empty: doc.text.trim() == "",
    is_low_signal: doc.text.trim() != "" && non_blank_char_count <= 16,
  }
}
