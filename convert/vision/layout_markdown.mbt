///|
pub fn render_ocr_layout_page_markdown(page : OcrLayoutPage) -> String {
  render_ocr_layout_blocks_markdown(page.blocks)
}

///|
pub fn render_ocr_layout_blocks_markdown(
  blocks : Array[OcrLayoutBlock],
) -> String {
  let rendered : Array[String] = []
  for block in blocks {
    let text = render_ocr_layout_block_markdown(block)
    if text != "" {
      rendered.push(text)
    }
  }
  if rendered.length() == 0 {
    ""
  } else {
    rendered.join("\n\n") + "\n"
  }
}

///|
pub fn render_ocr_layout_block_markdown(block : OcrLayoutBlock) -> String {
  let text = block.text.trim().to_owned()
  if text == "" {
    return ""
  }
  match block.kind {
    OcrLayoutBlockKind::Paragraph => text
    OcrLayoutBlockKind::TableLike => text
    OcrLayoutBlockKind::Heading => render_heading_block(text)
    OcrLayoutBlockKind::ListItem => render_list_item_block(text)
    OcrLayoutBlockKind::Noise => ""
    OcrLayoutBlockKind::Unknown => text
  }
}

///|
fn render_heading_block(text : String) -> String {
  if text.has_prefix("#") {
    text
  } else {
    "# " + text
  }
}

///|
fn render_list_item_block(text : String) -> String {
  if looks_list_marker_prefix(text) {
    text
  } else {
    "- " + text
  }
}

///|
fn looks_list_marker_prefix(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  trimmed.has_prefix("- ") ||
  trimmed.has_prefix("* ") ||
  trimmed.has_prefix("• ") ||
  looks_numbered_list_marker_prefix(trimmed)
}

///|
fn looks_numbered_list_marker_prefix(text : String) -> Bool {
  let chars = text.to_array()
  if chars.length() < 4 {
    return false
  }
  if chars[0] == '(' || chars[0] == '（' {
    if chars.length() < 5 || !is_ascii_digit_for_list(chars[1]) {
      return false
    }
    let mut i = 1
    while i < chars.length() && is_ascii_digit_for_list(chars[i]) {
      i = i + 1
    }
    if i >= chars.length() || (chars[i] != ')' && chars[i] != '）') {
      return false
    }
    i = i + 1
    if i >= chars.length() || chars[i] != ' ' {
      return false
    }
    return i + 1 < chars.length()
  }

  let mut i = 0
  while i < chars.length() && is_ascii_digit_for_list(chars[i]) {
    i = i + 1
  }
  if i == 0 || i >= chars.length() {
    return false
  }
  let marker = chars[i]
  if marker != '.' && marker != ')' {
    return false
  }
  i = i + 1
  if i >= chars.length() || chars[i] != ' ' {
    return false
  }
  i + 1 < chars.length()
}

///|
fn is_ascii_digit_for_list(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}
