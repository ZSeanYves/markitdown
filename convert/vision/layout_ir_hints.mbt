///|
pub enum OcrIrBlockHintKind {
  Paragraph
  Heading
  ListItem
  TableLike
  KeyValueLike
  CaptionLike
  Unknown
} derive(Eq)

///|
pub struct OcrIrBlockHint {
  page_index : Int
  ir_block_index : Int
  kind : OcrIrBlockHintKind
  source_line_indices : Array[Int]
  confidence : Double
  reasons : Array[String]
  text : String
}

///|
pub struct OcrIrDocumentHints {
  block_hints : Array[OcrIrBlockHint]
  warnings : Array[String]
}

///|
pub fn collect_ocr_layout_page_ir_hints(
  page : OcrLayoutPage,
) -> OcrIrDocumentHints {
  collect_ocr_layout_pages_ir_hints([page])
}

///|
pub fn collect_ocr_layout_pages_ir_hints(
  pages : Array[OcrLayoutPage],
) -> OcrIrDocumentHints {
  let block_hints : Array[OcrIrBlockHint] = []
  let warnings : Array[String] = []
  let mut ir_block_index = 0

  for page in pages {
    for warning in page.warnings {
      let text = warning.trim().to_owned()
      if text != "" {
        warnings.push(text)
      }
    }
    for block in page.blocks {
      match
        collect_ocr_layout_block_ir_hint(block, page.page_index, ir_block_index) {
        Some(hint) => {
          block_hints.push(hint)
          ir_block_index += 1
        }
        None => ()
      }
    }
  }

  { block_hints, warnings: dedupe_layout_warnings(warnings) }
}

///|
pub fn collect_ocr_layout_block_ir_hint(
  block : OcrLayoutBlock,
  page_index : Int,
  ir_block_index : Int,
) -> OcrIrBlockHint? {
  let text = block.text.trim().to_owned()
  if text == "" || block.kind == OcrLayoutBlockKind::Noise {
    return None
  }

  Some({
    page_index,
    ir_block_index,
    kind: ocr_ir_hint_kind(block),
    source_line_indices: block.line_indices,
    confidence: block.confidence,
    reasons: block.reasons,
    text,
  })
}

///|
fn ocr_ir_hint_kind(block : OcrLayoutBlock) -> OcrIrBlockHintKind {
  let text = block.text.trim().to_owned()
  match block.kind {
    OcrLayoutBlockKind::Paragraph =>
      if is_caption_like_hint_text(text) {
        OcrIrBlockHintKind::CaptionLike
      } else if is_key_value_like_hint_text(text) {
        OcrIrBlockHintKind::KeyValueLike
      } else {
        OcrIrBlockHintKind::Paragraph
      }
    OcrLayoutBlockKind::Heading => OcrIrBlockHintKind::Heading
    OcrLayoutBlockKind::ListItem => OcrIrBlockHintKind::ListItem
    OcrLayoutBlockKind::TableLike => OcrIrBlockHintKind::TableLike
    OcrLayoutBlockKind::Unknown => OcrIrBlockHintKind::Unknown
    OcrLayoutBlockKind::Noise => abort("noise blocks do not emit IR hints")
  }
}

///|
fn is_key_value_like_hint_text(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  if !trimmed.contains(":") {
    return false
  }
  if is_caption_like_hint_text(trimmed) || looks_url_like_text(trimmed) {
    return false
  }

  let colon_index = find_first_colon(trimmed)
  if colon_index <= 0 || colon_index >= trimmed.length() - 1 {
    return false
  }

  let key = trimmed[:colon_index].trim().to_owned()
  let value = trimmed[colon_index + 1:].trim().to_owned()
  if key == "" || value == "" {
    return false
  }
  if key.length() > 40 {
    return false
  }
  if !contains_letter_or_digit(key) {
    return false
  }
  if !contains_letter_or_digit(value) {
    return false
  }
  true
}

///|
fn is_caption_like_hint_text(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" || looks_url_like_text(trimmed) {
    return false
  }

  let colon_index = find_first_colon(trimmed)
  if colon_index <= 0 || colon_index >= trimmed.length() - 1 {
    return false
  }

  let label = trimmed[:colon_index].trim().to_owned().to_lower()
  let value = trimmed[colon_index + 1:].trim().to_owned()
  if value == "" {
    return false
  }

  caption_label_has_marker_and_number(label)
}

///|
fn caption_label_has_marker_and_number(label : String) -> Bool {
  if label == "" {
    return false
  }
  caption_suffix_has_number(label, "figure ") ||
  caption_suffix_has_number(label, "fig. ") ||
  caption_suffix_has_number(label, "fig ") ||
  caption_suffix_has_number(label, "table ") ||
  caption_suffix_has_number(label, "chart ")
}

///|
fn caption_suffix_has_number(label : String, prefix : String) -> Bool {
  if !label.has_prefix(prefix) {
    return false
  }
  let suffix = label[prefix.length():].trim().to_owned()
  suffix != "" && contains_ascii_digit(suffix)
}

///|
fn looks_url_like_text(text : String) -> Bool {
  let lower = text.to_lower()
  lower.contains("http://") ||
  lower.contains("https://") ||
  lower.contains("www.")
}

///|
fn find_first_colon(text : String) -> Int {
  let chars = text.to_array()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == ':' {
      return i
    }
    i = i + 1
  }
  -1
}

///|
fn contains_letter_or_digit(text : String) -> Bool {
  for ch in text.to_array() {
    if kv_is_ascii_letter_or_digit(ch) || kv_is_cjk_char(ch) {
      return true
    }
  }
  false
}

///|
fn contains_ascii_digit(text : String) -> Bool {
  for ch in text.to_array() {
    if ch >= '0' && ch <= '9' {
      return true
    }
  }
  false
}

///|
fn kv_is_ascii_letter_or_digit(ch : Char) -> Bool {
  (ch >= '0' && ch <= '9') ||
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= 'a' && ch <= 'z')
}

///|
fn kv_is_cjk_char(ch : Char) -> Bool {
  let code = ch.to_int()
  code >= 0x4E00 && code <= 0x9FFF
}
