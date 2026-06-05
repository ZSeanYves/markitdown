///|
pub enum TesseractTsvParseErrorKind {
  MissingHeader
  MissingRequiredColumn
} derive(Eq)

///|
pub struct TesseractTsvParseError {
  kind : TesseractTsvParseErrorKind
  line : Int
  message : String
}

///|
pub fn parse_tesseract_tsv_page_with_provider(
  tsv : String,
  provider : String,
) -> Result[OcrPageModel, TesseractTsvParseError] {
  let normalized = normalize_tesseract_tsv_text(tsv)
  if normalized == "" {
    return Ok(make_empty_ocr_page_model(0, provider, "tesseract-tsv"))
  }

  let rows = split_lines_to_array(normalized)
  let header_line = match find_first_nonempty_row(rows) {
    Some(row) => row
    None => return Ok(make_empty_ocr_page_model(0, provider, "tesseract-tsv"))
  }
  let header_cols = split_tsv_columns(header_line)
  let header_index = match parse_tesseract_tsv_header(header_cols) {
    Ok(v) => v
    Err(err) => return Err(err)
  }

  let grouped_lines : Array[TesseractTsvLineGroup] = []
  let warnings : Array[String] = []
  let first_page_num : Ref[Int?] = { val: None }
  let next_line_index : Ref[Int] = { val: 0 }
  let mut word_index = 0
  let mut page_extent = unknown_bbox()
  let mut saw_geometry = false
  let mut row_line_no = 0
  let mut saw_data_row = false
  let mut skipped_header = false
  for row in rows {
    row_line_no += 1
    if !skipped_header && row == header_line {
      skipped_header = true
      continue
    }
    let trimmed = row.trim().to_owned()
    if trimmed == "" {
      continue
    }
    saw_data_row = true
    let cols = split_tsv_columns(row)
    match
      parse_tesseract_tsv_word_row(
        cols,
        header_index,
        row_line_no,
        word_index,
        first_page_num.val,
      ) {
      ParsedWordRow::Skip => ()
      ParsedWordRow::Warn(msg) => warnings.push(msg)
      ParsedWordRow::Word(entry) => {
        match first_page_num.val {
          Some(first_page) =>
            if entry.page_num != first_page {
              warnings.push(
                "line " +
                row_line_no.to_string() +
                ": multiple pages detected; keeping first page " +
                first_page.to_string(),
              )
              continue
            }
          None => first_page_num.val = Some(entry.page_num)
        }
        if bbox_is_valid(entry.word.bbox) {
          page_extent = bbox_union(page_extent, entry.word.bbox)
          saw_geometry = true
        }
        append_word_to_group(grouped_lines, entry, next_line_index)
        word_index += 1
      }
    }
  }

  if !saw_data_row {
    return Ok(make_empty_ocr_page_model(0, provider, "tesseract-tsv"))
  }

  Ok(
    build_page_model_from_groups(
      grouped_lines,
      warnings,
      provider,
      first_page_num.val.unwrap_or(1),
      page_extent,
      saw_geometry,
    ),
  )
}

///|
pub fn parse_tesseract_tsv_page(
  tsv : String,
) -> Result[OcrPageModel, TesseractTsvParseError] {
  parse_tesseract_tsv_page_with_provider(tsv, "tesseract-tsv")
}

///|
pub impl Show for TesseractTsvParseError with fn to_string(
  self : TesseractTsvParseError,
) -> String {
  "tesseract tsv parse error at line " +
  self.line.to_string() +
  ": " +
  self.message
}

///|
pub impl Show for TesseractTsvParseError with fn output(
  self : TesseractTsvParseError,
  logger : &Logger,
) -> Unit {
  logger.write_string(self.to_string())
}

///|
priv struct ParsedTesseractTsvHeader {
  level : Int
  page_num : Int
  block_num : Int?
  par_num : Int?
  line_num : Int
  word_num : Int
  left : Int
  top : Int
  width : Int
  height : Int
  conf : Int
  text : Int
}

///|
priv struct TesseractTsvWordEntry {
  page_num : Int
  block_num : Int
  par_num : Int
  line_num : Int
  word_num : Int
  word : OcrSignalWord
}

///|
priv struct TesseractTsvLineGroup {
  page_num : Int
  block_num : Int
  par_num : Int
  line_num : Int
  line_index : Int
  words : Array[TesseractTsvWordEntry]
}

///|
priv enum ParsedWordRow {
  Skip
  Warn(String)
  Word(TesseractTsvWordEntry)
}

///|
fn build_page_model_from_groups(
  groups : Array[TesseractTsvLineGroup],
  warnings : Array[String],
  provider : String,
  first_page_num : Int,
  page_extent : VisionBBox,
  saw_geometry : Bool,
) -> OcrPageModel {
  let lines : Array[OcrSignalLine] = []
  let words : Array[OcrSignalWord] = []
  groups.sort_by(compare_tesseract_line_groups)
  for group in groups {
    group.words.sort_by(compare_tesseract_word_entries)
    let line_words : Array[OcrSignalWord] = []
    let mut line_bbox = unknown_bbox()
    let mut confidence_total = 0.0
    let mut confidence_count = 0
    for entry in group.words {
      let word = entry.word
      words.push(word)
      line_words.push(word)
      line_bbox = bbox_union(line_bbox, word.bbox)
      if word.confidence >= 0.0 {
        confidence_total = confidence_total + word.confidence
        confidence_count = confidence_count + 1
      }
    }
    let line_confidence = if confidence_count == 0 {
      -1.0
    } else {
      confidence_total / confidence_count.to_double()
    }
    lines.push({
      text: line_words.map(fn(word) { word.text }).join(" "),
      bbox: line_bbox,
      confidence: line_confidence,
      words: line_words,
      line_index: group.line_index,
    })
  }

  let page_warnings : Array[String] = []
  for warning in warnings {
    page_warnings.push(warning)
  }
  let width = if saw_geometry { bbox_right(page_extent) } else { 0.0 }
  let height = if saw_geometry { bbox_bottom(page_extent) } else { 0.0 }
  if saw_geometry {
    page_warnings.push("page geometry approximated from word boxes")
  }
  {
    page_index: if first_page_num > 0 {
      first_page_num - 1
    } else {
      0
    },
    width,
    height,
    lines,
    words,
    provider,
    source_kind: "tesseract-tsv",
    warnings: dedupe_warnings(page_warnings),
  }
}

///|
fn append_word_to_group(
  groups : Array[TesseractTsvLineGroup],
  entry : TesseractTsvWordEntry,
  next_line_index : Ref[Int],
) -> Unit {
  for i in 0..<groups.length() {
    let current = groups[i]
    if current.page_num == entry.page_num &&
      current.block_num == entry.block_num &&
      current.par_num == entry.par_num &&
      current.line_num == entry.line_num {
      current.words.push(entry)
      return
    }
  }
  groups.push({
    page_num: entry.page_num,
    block_num: entry.block_num,
    par_num: entry.par_num,
    line_num: entry.line_num,
    line_index: next_line_index.val,
    words: [entry],
  })
  next_line_index.val = next_line_index.val + 1
}

///|
fn parse_tesseract_tsv_word_row(
  cols : Array[String],
  index : ParsedTesseractTsvHeader,
  row_line_no : Int,
  word_index : Int,
  _first_page_num : Int?,
) -> ParsedWordRow {
  let level = match tsv_int_column(cols, index.level) {
    Some(v) => v
    None =>
      return ParsedWordRow::Warn(
        "line " + row_line_no.to_string() + ": invalid level",
      )
  }
  if level != 5 {
    return ParsedWordRow::Skip
  }

  let text = tsv_string_column(cols, index.text).trim().to_owned()
  if text == "" {
    return ParsedWordRow::Skip
  }

  let page_num = match tsv_int_column(cols, index.page_num) {
    Some(v) => v
    None =>
      return ParsedWordRow::Warn(
        "line " + row_line_no.to_string() + ": invalid page_num",
      )
  }
  let block_num = tsv_optional_int_column(cols, index.block_num).unwrap_or(0)
  let par_num = tsv_optional_int_column(cols, index.par_num).unwrap_or(0)
  let line_num = match tsv_int_column(cols, index.line_num) {
    Some(v) => v
    None =>
      return ParsedWordRow::Warn(
        "line " + row_line_no.to_string() + ": invalid line_num",
      )
  }
  let word_num = match tsv_int_column(cols, index.word_num) {
    Some(v) => v
    None =>
      return ParsedWordRow::Warn(
        "line " + row_line_no.to_string() + ": invalid word_num",
      )
  }

  let bbox = match
    make_tesseract_bbox(
      tsv_double_column(cols, index.left),
      tsv_double_column(cols, index.top),
      tsv_double_column(cols, index.width),
      tsv_double_column(cols, index.height),
    ) {
    Some(v) => v
    None =>
      return ParsedWordRow::Warn(
        "line " + row_line_no.to_string() + ": invalid bbox; row skipped",
      )
  }
  let confidence = parse_tesseract_confidence(
    tsv_string_column(cols, index.conf),
  )
  ParsedWordRow::Word({
    page_num,
    block_num,
    par_num,
    line_num,
    word_num,
    word: { text, bbox, confidence, word_index },
  })
}

///|
fn parse_tesseract_tsv_header(
  header : Array[String],
) -> Result[ParsedTesseractTsvHeader, TesseractTsvParseError] {
  if header.length() == 0 {
    return Err(tsv_parse_error(MissingHeader, 1, "missing TSV header"))
  }
  let index : Map[String, Int] = Map([])
  for i in 0..<header.length() {
    index.set(header[i].trim().to_owned(), i)
  }

  let level = match required_tsv_header_index(index, "level") {
    Ok(v) => v
    Err(err) => return Err(err)
  }
  let page_num = match required_tsv_header_index(index, "page_num") {
    Ok(v) => v
    Err(err) => return Err(err)
  }
  let line_num = match required_tsv_header_index(index, "line_num") {
    Ok(v) => v
    Err(err) => return Err(err)
  }
  let word_num = match required_tsv_header_index(index, "word_num") {
    Ok(v) => v
    Err(err) => return Err(err)
  }
  let left = match required_tsv_header_index(index, "left") {
    Ok(v) => v
    Err(err) => return Err(err)
  }
  let top = match required_tsv_header_index(index, "top") {
    Ok(v) => v
    Err(err) => return Err(err)
  }
  let width = match required_tsv_header_index(index, "width") {
    Ok(v) => v
    Err(err) => return Err(err)
  }
  let height = match required_tsv_header_index(index, "height") {
    Ok(v) => v
    Err(err) => return Err(err)
  }
  let conf = match required_tsv_header_index(index, "conf") {
    Ok(v) => v
    Err(err) => return Err(err)
  }
  let text = match required_tsv_header_index(index, "text") {
    Ok(v) => v
    Err(err) => return Err(err)
  }
  Ok({
    level,
    page_num,
    block_num: index.get("block_num"),
    par_num: index.get("par_num"),
    line_num,
    word_num,
    left,
    top,
    width,
    height,
    conf,
    text,
  })
}

///|
fn required_tsv_header_index(
  index : Map[String, Int],
  key : String,
) -> Result[Int, TesseractTsvParseError] {
  match index.get(key) {
    Some(v) => Ok(v)
    None =>
      Err(
        tsv_parse_error(
          MissingRequiredColumn,
          1,
          "missing required TSV column: " + key,
        ),
      )
  }
}

///|
fn tsv_parse_error(
  kind : TesseractTsvParseErrorKind,
  line : Int,
  message : String,
) -> TesseractTsvParseError {
  { kind, line, message }
}

///|
fn normalize_tesseract_tsv_text(tsv : String) -> String {
  let replaced = tsv.replace(old="\r\n", new="\n").replace(old="\r", new="\n")
  trim_trailing_tesseract_newlines(replaced)
}

///|
fn trim_trailing_tesseract_newlines(text : String) -> String {
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
fn split_lines_to_array(text : String) -> Array[String] {
  let out : Array[String] = []
  for line in text.split("\n") {
    out.push(line.to_owned())
  }
  out
}

///|
fn split_tsv_columns(text : String) -> Array[String] {
  let out : Array[String] = []
  for col in text.split("\t") {
    out.push(col.to_owned())
  }
  out
}

///|
fn find_first_nonempty_row(rows : Array[String]) -> String? {
  for row in rows {
    if row.trim() != "" {
      return Some(row)
    }
  }
  None
}

///|
fn tsv_string_column(cols : Array[String], index : Int) -> String {
  if index < 0 || index >= cols.length() {
    ""
  } else {
    cols[index]
  }
}

///|
fn tsv_optional_int_column(cols : Array[String], index : Int?) -> Int? {
  match index {
    Some(v) => tsv_int_column(cols, v)
    None => None
  }
}

///|
fn tsv_int_column(cols : Array[String], index : Int) -> Int? {
  if index < 0 || index >= cols.length() {
    return None
  }
  try @string.parse_int(cols[index].trim().to_owned()) catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
fn tsv_double_column(cols : Array[String], index : Int) -> Double? {
  if index < 0 || index >= cols.length() {
    return None
  }
  try @string.parse_double(cols[index].trim().to_owned()) catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
fn make_tesseract_bbox(
  left : Double?,
  top : Double?,
  width : Double?,
  height : Double?,
) -> VisionBBox? {
  match (left, top, width, height) {
    (Some(x), Some(y), Some(w), Some(h)) =>
      if x < 0.0 || y < 0.0 || w < 0.0 || h < 0.0 {
        None
      } else {
        Some({ x, y, width: w, height: h })
      }
    _ => None
  }
}

///|
fn parse_tesseract_confidence(raw : String) -> Double {
  try @string.parse_double(raw.trim().to_owned()) catch {
    _ => -1.0
  } noraise {
    v => if v < 0.0 { -1.0 } else { v }
  }
}

///|
fn compare_tesseract_line_groups(
  a : TesseractTsvLineGroup,
  b : TesseractTsvLineGroup,
) -> Int {
  if a.page_num != b.page_num {
    a.page_num - b.page_num
  } else if a.block_num != b.block_num {
    a.block_num - b.block_num
  } else if a.par_num != b.par_num {
    a.par_num - b.par_num
  } else if a.line_num != b.line_num {
    a.line_num - b.line_num
  } else {
    a.line_index - b.line_index
  }
}

///|
fn compare_tesseract_word_entries(
  a : TesseractTsvWordEntry,
  b : TesseractTsvWordEntry,
) -> Int {
  if a.word_num != b.word_num {
    a.word_num - b.word_num
  } else {
    a.word.word_index - b.word.word_index
  }
}

///|
fn dedupe_warnings(warnings : Array[String]) -> Array[String] {
  let seen : Map[String, Bool] = Map([])
  let out : Array[String] = []
  for warning in warnings {
    if warning == "" {
      continue
    }
    if seen.get(warning).unwrap_or(false) {
      continue
    }
    seen.set(warning, true)
    out.push(warning)
  }
  out
}
