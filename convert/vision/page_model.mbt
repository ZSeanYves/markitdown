///|
pub struct VisionBBox {
  x : Double
  y : Double
  width : Double
  height : Double
}

///|
pub struct OcrSignalWord {
  text : String
  bbox : VisionBBox
  confidence : Double
  word_index : Int
}

///|
pub struct OcrSignalLine {
  text : String
  bbox : VisionBBox
  confidence : Double
  words : Array[OcrSignalWord]
  line_index : Int
}

///|
pub struct OcrPageModel {
  page_index : Int
  width : Double
  height : Double
  lines : Array[OcrSignalLine]
  words : Array[OcrSignalWord]
  provider : String
  source_kind : String
  warnings : Array[String]
}

///|
pub struct OcrDocumentModel {
  pages : Array[OcrPageModel]
  provider : String
  warnings : Array[String]
}

///|
pub fn make_ocr_document_model(
  pages : Array[OcrPageModel],
  provider : String,
  warnings : Array[String],
) -> OcrDocumentModel {
  { pages, provider, warnings }
}

///|
pub fn unknown_bbox() -> VisionBBox {
  { x: -1.0, y: -1.0, width: -1.0, height: -1.0 }
}

///|
pub fn is_unknown_bbox(bbox : VisionBBox) -> Bool {
  bbox.x < 0.0 && bbox.y < 0.0 && bbox.width < 0.0 && bbox.height < 0.0
}

///|
pub fn bbox_is_valid(bbox : VisionBBox) -> Bool {
  !is_unknown_bbox(bbox) &&
  bbox.x >= 0.0 &&
  bbox.y >= 0.0 &&
  bbox.width >= 0.0 &&
  bbox.height >= 0.0
}

///|
pub fn bbox_right(bbox : VisionBBox) -> Double {
  if bbox_is_valid(bbox) {
    bbox.x + bbox.width
  } else {
    -1.0
  }
}

///|
pub fn bbox_bottom(bbox : VisionBBox) -> Double {
  if bbox_is_valid(bbox) {
    bbox.y + bbox.height
  } else {
    -1.0
  }
}

///|
pub fn bbox_area(bbox : VisionBBox) -> Double {
  if bbox_is_valid(bbox) {
    bbox.width * bbox.height
  } else {
    -1.0
  }
}

///|
pub fn bbox_union(a : VisionBBox, b : VisionBBox) -> VisionBBox {
  let a_valid = bbox_is_valid(a)
  let b_valid = bbox_is_valid(b)
  if !a_valid && !b_valid {
    return unknown_bbox()
  }
  if !a_valid {
    return b
  }
  if !b_valid {
    return a
  }

  let left = if a.x < b.x { a.x } else { b.x }
  let top = if a.y < b.y { a.y } else { b.y }
  let right = if bbox_right(a) > bbox_right(b) {
    bbox_right(a)
  } else {
    bbox_right(b)
  }
  let bottom = if bbox_bottom(a) > bbox_bottom(b) {
    bbox_bottom(a)
  } else {
    bbox_bottom(b)
  }
  { x: left, y: top, width: right - left, height: bottom - top }
}

///|
pub fn make_empty_ocr_page_model(
  page_index : Int,
  provider : String,
  source_kind : String,
) -> OcrPageModel {
  {
    page_index,
    width: -1.0,
    height: -1.0,
    lines: [],
    words: [],
    provider,
    source_kind,
    warnings: [],
  }
}

///|
pub fn make_text_only_ocr_page_model(
  text : String,
  provider : String,
) -> OcrPageModel {
  let page = make_empty_ocr_page_model(0, provider, "text-only")
  let normalized = normalize_text_only_ocr_text(text)
  if normalized == "" {
    return page
  }

  let words : Array[OcrSignalWord] = []
  let lines : Array[OcrSignalLine] = []
  let raw_lines = normalized.split("\n")
  let mut global_word_index = 0
  let mut line_index = 0
  for raw_line in raw_lines {
    let line_text = raw_line.to_owned()
    let line_words = split_text_only_words(line_text)
    let word_models : Array[OcrSignalWord] = []
    for word_text in line_words {
      let word : OcrSignalWord = {
        text: word_text,
        bbox: unknown_bbox(),
        confidence: -1.0,
        word_index: global_word_index,
      }
      global_word_index += 1
      word_models.push(word)
      words.push(word)
    }
    let line : OcrSignalLine = {
      text: line_text,
      bbox: unknown_bbox(),
      confidence: -1.0,
      words: word_models,
      line_index,
    }
    line_index += 1
    lines.push(line)
  }

  {
    page_index: page.page_index,
    width: page.width,
    height: page.height,
    lines,
    words,
    provider: page.provider,
    source_kind: page.source_kind,
    warnings: page.warnings,
  }
}

///|
pub fn ocr_page_text(page : OcrPageModel) -> String {
  let lines : Array[String] = []
  for line in page.lines {
    lines.push(line.text)
  }
  lines.join("\n")
}

///|
pub fn ocr_line_word_count(line : OcrSignalLine) -> Int {
  line.words.length()
}

///|
pub fn ocr_line_text_from_words(line : OcrSignalLine) -> String {
  if line.words.length() == 0 {
    return line.text
  }
  let out : Array[String] = []
  for word in line.words {
    let text = word.text.trim().to_owned()
    if text != "" {
      out.push(text)
    }
  }
  if out.length() == 0 {
    line.text
  } else {
    out.join(" ")
  }
}

///|
pub fn ocr_page_line_count(page : OcrPageModel) -> Int {
  page.lines.length()
}

///|
pub fn ocr_page_word_count(page : OcrPageModel) -> Int {
  page.words.length()
}

///|
pub fn ocr_page_has_geometry(page : OcrPageModel) -> Bool {
  if page.width > 0.0 && page.height > 0.0 {
    return true
  }
  for line in page.lines {
    if bbox_is_valid(line.bbox) {
      return true
    }
  }
  for word in page.words {
    if bbox_is_valid(word.bbox) {
      return true
    }
  }
  false
}

///|
pub fn ocr_page_has_confidence(page : OcrPageModel) -> Bool {
  ocr_page_average_confidence(page) >= 0.0
}

///|
pub fn ocr_page_average_confidence(page : OcrPageModel) -> Double {
  let word_average = average_known_word_confidence(page.words)
  if word_average >= 0.0 {
    return word_average
  }
  average_known_line_confidence(page.lines)
}

///|
pub fn ocr_page_warning_count(page : OcrPageModel) -> Int {
  page.warnings.length()
}

///|
pub fn ocr_document_page_count(doc : OcrDocumentModel) -> Int {
  doc.pages.length()
}

///|
pub fn ocr_document_text(doc : OcrDocumentModel) -> String {
  let pages : Array[String] = []
  for page in doc.pages {
    pages.push(ocr_page_text(page))
  }
  pages.join("\n\n")
}

///|
pub fn ocr_document_warning_count(doc : OcrDocumentModel) -> Int {
  let mut total = doc.warnings.length()
  for page in doc.pages {
    total = total + ocr_page_warning_count(page)
  }
  total
}

///|
fn normalize_text_only_ocr_text(text : String) -> String {
  let replaced = text.replace(old="\r\n", new="\n").replace(old="\r", new="\n")
  let trimmed = if replaced.has_suffix("\n") {
    trim_trailing_newlines(replaced)
  } else {
    replaced
  }
  if trimmed.trim() == "" {
    ""
  } else {
    trimmed
  }
}

///|
fn trim_trailing_newlines(text : String) -> String {
  let chars = text.to_array()
  let kept : Array[Char] = []
  let mut end = chars.length()
  while end > 0 && chars[end - 1] == '\n' {
    end = end - 1
  }
  for i = 0; i < end; i = i + 1 {
    kept.push(chars[i])
  }
  String::from_array(kept)
}

///|
fn split_text_only_words(text : String) -> Array[String] {
  let out : Array[String] = []
  for raw in text.split(" ") {
    let trimmed = raw.trim().to_owned()
    if trimmed != "" {
      out.push(trimmed)
    }
  }
  out
}

///|
fn is_known_confidence(confidence : Double) -> Bool {
  confidence >= 0.0
}

///|
fn average_known_word_confidence(words : Array[OcrSignalWord]) -> Double {
  let mut total = 0.0
  let mut count = 0
  for word in words {
    if is_known_confidence(word.confidence) {
      total = total + word.confidence
      count = count + 1
    }
  }
  if count == 0 {
    -1.0
  } else {
    total / count.to_double()
  }
}

///|
fn average_known_line_confidence(lines : Array[OcrSignalLine]) -> Double {
  let mut total = 0.0
  let mut count = 0
  for line in lines {
    if is_known_confidence(line.confidence) {
      total = total + line.confidence
      count = count + 1
    }
  }
  if count == 0 {
    -1.0
  } else {
    total / count.to_double()
  }
}
