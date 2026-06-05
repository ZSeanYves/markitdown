///|
pub fn render_ocr_ir_document_hints_tsv(hints : OcrIrDocumentHints) -> String {
  let rows : Array[String] = [ocr_ir_hints_tsv_header()]
  for hint in hints.block_hints {
    rows.push(render_ocr_ir_block_hint_tsv_row(hint))
  }
  rows.join("\n") + "\n"
}

///|
pub fn render_ocr_ir_block_hint_tsv_row(hint : OcrIrBlockHint) -> String {
  let line_range = ocr_ir_hint_line_range(hint.source_line_indices)
  [
    hint.page_index.to_string(),
    hint.ir_block_index.to_string(),
    ocr_ir_hint_kind_to_string(hint.kind),
    render_ocr_ir_hint_confidence(hint.confidence),
    render_ocr_ir_hint_optional_int(line_range.0),
    render_ocr_ir_hint_optional_int(line_range.1),
    escape_ocr_ir_hint_field(hint.text),
    escape_ocr_ir_hint_field(hint.reasons.join(";")),
  ].join("\t")
}

///|
fn ocr_ir_hints_tsv_header() -> String {
  "page_index\tir_block_index\tkind\tconfidence\tline_start\tline_end\ttext\treasons"
}

///|
fn ocr_ir_hint_kind_to_string(kind : OcrIrBlockHintKind) -> String {
  match kind {
    OcrIrBlockHintKind::Paragraph => "Paragraph"
    OcrIrBlockHintKind::Heading => "Heading"
    OcrIrBlockHintKind::ListItem => "ListItem"
    OcrIrBlockHintKind::TableLike => "TableLike"
    OcrIrBlockHintKind::KeyValueLike => "KeyValueLike"
    OcrIrBlockHintKind::CaptionLike => "CaptionLike"
    OcrIrBlockHintKind::Unknown => "Unknown"
  }
}

///|
fn render_ocr_ir_hint_confidence(confidence : Double) -> String {
  if confidence < 0.0 {
    "-1.0"
  } else {
    confidence.to_string()
  }
}

///|
fn render_ocr_ir_hint_optional_int(value : Int?) -> String {
  match value {
    Some(v) => v.to_string()
    None => ""
  }
}

///|
fn ocr_ir_hint_line_range(line_indices : Array[Int]) -> (Int?, Int?) {
  if line_indices.length() == 0 {
    return (None, None)
  }
  let mut min_index = line_indices[0]
  let mut max_index = line_indices[0]
  for i in 1..<line_indices.length() {
    let value = line_indices[i]
    if value < min_index {
      min_index = value
    }
    if value > max_index {
      max_index = value
    }
  }
  (Some(min_index), Some(max_index))
}

///|
fn escape_ocr_ir_hint_field(text : String) -> String {
  text
  .replace(old="\r\n", new=" ")
  .replace(old="\n", new=" ")
  .replace(old="\r", new=" ")
  .replace(old="\t", new=" ")
  .trim()
  .to_owned()
}
