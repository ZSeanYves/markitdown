///|
priv struct TesseractTsvHeader {
  level : Int
  page_num : Int
  block_num : Int
  par_num : Int
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
priv struct TesseractTsvWordRow {
  is_word : Bool
  page_num : Int
  block_num : Int
  par_num : Int
  line_num : Int
  word_num : Int
  left : Int
  top : Int
  width : Int
  height : Int
  conf : Double
  text : String
}

///|
priv struct TesseractIndexedWord {
  page_index : Int
  block_index : Int
  par_index : Int
  line_index : Int
  word_index : Int
  source_order : Int
  text : String
  bbox : @core.BBox
  confidence : Double?
}

///|
priv struct TesseractIndexedLine {
  page_index : Int
  block_index : Int
  par_index : Int
  line_index : Int
  words : Array[TesseractIndexedWord]
}

///|
priv struct TesseractIndexedBlock {
  page_index : Int
  block_index : Int
  lines : Array[TesseractIndexedLine]
}

///|
priv struct TesseractIndexedPage {
  page_index : Int
  blocks : Array[TesseractIndexedBlock]
}

///|
pub fn parse_tesseract_tsv(
  tsv : String,
  language? : String? = None,
) -> Result[OcrProviderResult, OcrProviderError] {
  let normalized = tesseract_tsv_normalize_newlines(tsv)
  if normalized.trim() == "" {
    return Err(
      OcrProviderError::EmptyResult(
        "Tesseract TSV output is empty on the current root runtime.",
      ),
    )
  }
  let lines = normalized
    .split("\n")
    .to_array()
    .map(fn(line) { line.to_owned() })
  if lines.length() == 0 {
    return Err(
      OcrProviderError::EmptyResult(
        "Tesseract TSV output is empty on the current root runtime.",
      ),
    )
  }
  let header = match tesseract_tsv_parse_header(lines[0]) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let provider = make_ocr_provider_info("tesseract", language~, diagnostics=[])
  let parsed = tesseract_tsv_parse_rows(lines, header, provider)
  if parsed.0.length() == 0 {
    let reason = if parsed.2 {
      "Tesseract TSV output did not produce any OCR words on the current root runtime."
    } else {
      "Tesseract TSV output only contained a header on the current root runtime."
    }
    return Err(OcrProviderError::EmptyResult(reason))
  }
  Ok(make_ocr_provider_result(parsed.0, "tesseract", diagnostics=parsed.1))
}

///|
pub fn parse_tesseract_tsv_pages(
  tsv : String,
  language? : String? = None,
) -> Result[Array[OcrPageModel], OcrProviderError] {
  match parse_tesseract_tsv(tsv, language~) {
    Ok(result) => Ok(result.pages)
    Err(error) => Err(error)
  }
}

///|
fn tesseract_tsv_parse_header(
  line : String,
) -> Result[TesseractTsvHeader, OcrProviderError] {
  let parts = line
    .split("\t")
    .to_array()
    .map(fn(part) { part.trim().to_owned() })
  let required = [
    "level", "page_num", "block_num", "par_num", "line_num", "word_num", "left",
    "top", "width", "height", "conf", "text",
  ]
  if parts.length() < required.length() {
    return Err(
      OcrProviderError::OutputParseFailed(
        "Tesseract TSV header is malformed on the current root runtime.",
      ),
    )
  }
  let indexes : Map[String, Int] = Map([])
  for i in 0..<parts.length() {
    indexes.set(parts[i], i)
  }
  for key in required {
    if indexes.get(key) is None {
      return Err(
        OcrProviderError::OutputParseFailed(
          "Tesseract TSV header is missing required column: " + key,
        ),
      )
    }
  }
  Ok({
    level: indexes.get("level").unwrap_or(0),
    page_num: indexes.get("page_num").unwrap_or(0),
    block_num: indexes.get("block_num").unwrap_or(0),
    par_num: indexes.get("par_num").unwrap_or(0),
    line_num: indexes.get("line_num").unwrap_or(0),
    word_num: indexes.get("word_num").unwrap_or(0),
    left: indexes.get("left").unwrap_or(0),
    top: indexes.get("top").unwrap_or(0),
    width: indexes.get("width").unwrap_or(0),
    height: indexes.get("height").unwrap_or(0),
    conf: indexes.get("conf").unwrap_or(0),
    text: indexes.get("text").unwrap_or(0),
  })
}

///|
fn tesseract_tsv_parse_rows(
  lines : Array[String],
  header : TesseractTsvHeader,
  provider : OcrProviderInfo,
) -> (Array[OcrPageModel], Array[String], Bool) {
  let words : Array[TesseractIndexedWord] = []
  let diagnostics : Array[String] = []
  let mut ragged_count = 0
  let mut invalid_numeric_count = 0
  let mut empty_text_count = 0
  let mut saw_data_row = false
  for i in 1..<lines.length() {
    let raw = lines[i]
    if raw.trim() == "" {
      continue
    }
    saw_data_row = true
    let parts = raw.split("\t").to_array().map(fn(part) { part.to_owned() })
    if parts.length() <= header.text {
      ragged_count += 1
      continue
    }
    match tesseract_tsv_parse_word_row(parts, header) {
      Some(word_row) => {
        if !word_row.is_word {
          continue
        }
        let trimmed = word_row.text.trim().to_owned()
        if trimmed == "" {
          empty_text_count += 1
          continue
        }
        words.push({
          page_index: tesseract_tsv_page_index(word_row.page_num),
          block_index: word_row.block_num,
          par_index: word_row.par_num,
          line_index: word_row.line_num,
          word_index: word_row.word_num,
          source_order: i,
          text: trimmed,
          bbox: tesseract_tsv_bbox(word_row),
          confidence: tesseract_tsv_confidence(word_row.conf),
        })
      }
      None => invalid_numeric_count += 1
    }
  }
  if ragged_count > 0 {
    diagnostics.push(
      "tesseract_tsv_skipped_ragged_rows=" + ragged_count.to_string(),
    )
  }
  if invalid_numeric_count > 0 {
    diagnostics.push(
      "tesseract_tsv_skipped_invalid_numeric_rows=" +
      invalid_numeric_count.to_string(),
    )
  }
  if empty_text_count > 0 {
    diagnostics.push(
      "tesseract_tsv_skipped_empty_text_rows=" + empty_text_count.to_string(),
    )
  }
  words.sort_by(fn(a, b) {
    let page_cmp = a.page_index.compare(b.page_index)
    if page_cmp != 0 {
      return page_cmp
    }
    let block_cmp = a.block_index.compare(b.block_index)
    if block_cmp != 0 {
      return block_cmp
    }
    let par_cmp = a.par_index.compare(b.par_index)
    if par_cmp != 0 {
      return par_cmp
    }
    let line_cmp = a.line_index.compare(b.line_index)
    if line_cmp != 0 {
      return line_cmp
    }
    let word_cmp = a.word_index.compare(b.word_index)
    if word_cmp != 0 {
      return word_cmp
    }
    a.source_order.compare(b.source_order)
  })
  (
    tesseract_tsv_build_pages(words, provider, diagnostics),
    diagnostics,
    saw_data_row,
  )
}

///|
fn tesseract_tsv_parse_word_row(
  parts : Array[String],
  header : TesseractTsvHeader,
) -> TesseractTsvWordRow? {
  let level = match tesseract_tsv_parse_int(parts[header.level]) {
    Some(value) => value
    None => return None
  }
  if level != 5 {
    return Some({
      is_word: false,
      page_num: 0,
      block_num: 0,
      par_num: 0,
      line_num: 0,
      word_num: 0,
      left: 0,
      top: 0,
      width: 0,
      height: 0,
      conf: -1.0,
      text: "",
    })
  }
  let page_num = match tesseract_tsv_parse_int(parts[header.page_num]) {
    Some(value) => value
    None => return None
  }
  let block_num = match tesseract_tsv_parse_int(parts[header.block_num]) {
    Some(value) => value
    None => return None
  }
  let par_num = match tesseract_tsv_parse_int(parts[header.par_num]) {
    Some(value) => value
    None => return None
  }
  let line_num = match tesseract_tsv_parse_int(parts[header.line_num]) {
    Some(value) => value
    None => return None
  }
  let word_num = match tesseract_tsv_parse_int(parts[header.word_num]) {
    Some(value) => value
    None => return None
  }
  let left = match tesseract_tsv_parse_int(parts[header.left]) {
    Some(value) => value
    None => return None
  }
  let top = match tesseract_tsv_parse_int(parts[header.top]) {
    Some(value) => value
    None => return None
  }
  let width = match tesseract_tsv_parse_int(parts[header.width]) {
    Some(value) => value
    None => return None
  }
  let height = match tesseract_tsv_parse_int(parts[header.height]) {
    Some(value) => value
    None => return None
  }
  let conf = match tesseract_tsv_parse_confidence(parts[header.conf]) {
    Some(value) => value
    None => return None
  }
  Some({
    is_word: true,
    page_num,
    block_num,
    par_num,
    line_num,
    word_num,
    left,
    top,
    width,
    height,
    conf,
    text: parts[header.text],
  })
}

///|
fn tesseract_tsv_build_pages(
  words : Array[TesseractIndexedWord],
  provider : OcrProviderInfo,
  diagnostics : Array[String],
) -> Array[OcrPageModel] {
  let lines = tesseract_tsv_group_lines(words)
  let blocks = tesseract_tsv_group_blocks(lines)
  let indexed_pages = tesseract_tsv_group_pages(blocks)
  indexed_pages.map(fn(page) {
    let blocks_out = page.blocks.map(fn(block) {
      let lines_out = block.lines.map(fn(line) {
        let line_bbox = tesseract_tsv_merge_word_bbox(line.words)
        {
          line_index: line.line_index,
          text: line.words.map(fn(word) { word.text }).join(" "),
          words: line.words.map(fn(word) {
            make_ocr_word(
              word.word_index,
              word.text,
              bbox=Some(word.bbox),
              confidence=word.confidence,
            )
          }),
          bbox: line_bbox,
          confidence: tesseract_tsv_average_word_confidence(line.words),
        }
      })
      {
        block_index: block.block_index,
        lines: lines_out,
        bbox: tesseract_tsv_merge_ocr_line_bbox(lines_out),
        confidence: tesseract_tsv_average_ocr_line_confidence(lines_out),
      }
    })
    let page_bbox = tesseract_tsv_merge_ocr_block_bbox(blocks_out)
    {
      page_index: page.page_index,
      width: match page_bbox {
        Some(box) => Some(box.x1)
        None => None
      },
      height: match page_bbox {
        Some(box) => Some(box.y1)
        None => None
      },
      blocks: blocks_out,
      provider: Some({ ..provider, diagnostics, }),
      diagnostics,
    }
  })
}

///|
fn tesseract_tsv_group_lines(
  words : Array[TesseractIndexedWord],
) -> Array[TesseractIndexedLine] {
  if words.length() == 0 {
    return []
  }
  let lines : Array[TesseractIndexedLine] = []
  let mut current = {
    page_index: words[0].page_index,
    block_index: words[0].block_index,
    par_index: words[0].par_index,
    line_index: words[0].line_index,
    words: [words[0]],
  }
  for i in 1..<words.length() {
    let word = words[i]
    if current.page_index == word.page_index &&
      current.block_index == word.block_index &&
      current.par_index == word.par_index &&
      current.line_index == word.line_index {
      current.words.push(word)
    } else {
      lines.push(current)
      current = {
        page_index: word.page_index,
        block_index: word.block_index,
        par_index: word.par_index,
        line_index: word.line_index,
        words: [word],
      }
    }
  }
  lines.push(current)
  lines
}

///|
fn tesseract_tsv_group_blocks(
  lines : Array[TesseractIndexedLine],
) -> Array[TesseractIndexedBlock] {
  if lines.length() == 0 {
    return []
  }
  let blocks : Array[TesseractIndexedBlock] = []
  let mut current = {
    page_index: lines[0].page_index,
    block_index: lines[0].block_index,
    lines: [lines[0]],
  }
  for i in 1..<lines.length() {
    let line = lines[i]
    if current.page_index == line.page_index &&
      current.block_index == line.block_index {
      current.lines.push(line)
    } else {
      blocks.push(current)
      current = {
        page_index: line.page_index,
        block_index: line.block_index,
        lines: [line],
      }
    }
  }
  blocks.push(current)
  blocks
}

///|
fn tesseract_tsv_group_pages(
  blocks : Array[TesseractIndexedBlock],
) -> Array[TesseractIndexedPage] {
  if blocks.length() == 0 {
    return []
  }
  let pages : Array[TesseractIndexedPage] = []
  let mut current = { page_index: blocks[0].page_index, blocks: [blocks[0]] }
  for i in 1..<blocks.length() {
    let block = blocks[i]
    if current.page_index == block.page_index {
      current.blocks.push(block)
    } else {
      pages.push(current)
      current = { page_index: block.page_index, blocks: [block] }
    }
  }
  pages.push(current)
  pages
}

///|
fn tesseract_tsv_merge_word_bbox(
  words : Array[TesseractIndexedWord],
) -> @core.BBox? {
  if words.length() == 0 {
    return None
  }
  let mut x0 = words[0].bbox.x0
  let mut y0 = words[0].bbox.y0
  let mut x1 = words[0].bbox.x1
  let mut y1 = words[0].bbox.y1
  for i in 1..<words.length() {
    let box = words[i].bbox
    if box.x0 < x0 {
      x0 = box.x0
    }
    if box.y0 < y0 {
      y0 = box.y0
    }
    if box.x1 > x1 {
      x1 = box.x1
    }
    if box.y1 > y1 {
      y1 = box.y1
    }
  }
  Some({ x0, y0, x1, y1 })
}

///|
fn tesseract_tsv_merge_ocr_line_bbox(lines : Array[OcrLine]) -> @core.BBox? {
  let mut merged : @core.BBox? = None
  for line in lines {
    merged = tesseract_tsv_merge_bbox_pair(merged, line.bbox)
  }
  merged
}

///|
fn tesseract_tsv_merge_ocr_block_bbox(blocks : Array[OcrBlock]) -> @core.BBox? {
  let mut merged : @core.BBox? = None
  for block in blocks {
    merged = tesseract_tsv_merge_bbox_pair(merged, block.bbox)
  }
  merged
}

///|
fn tesseract_tsv_merge_bbox_pair(
  left : @core.BBox?,
  right : @core.BBox?,
) -> @core.BBox? {
  match left {
    Some(a) =>
      match right {
        Some(b) =>
          Some({
            x0: if a.x0 < b.x0 {
              a.x0
            } else {
              b.x0
            },
            y0: if a.y0 < b.y0 {
              a.y0
            } else {
              b.y0
            },
            x1: if a.x1 > b.x1 {
              a.x1
            } else {
              b.x1
            },
            y1: if a.y1 > b.y1 {
              a.y1
            } else {
              b.y1
            },
          })
        None => Some(a)
      }
    None => right
  }
}

///|
fn tesseract_tsv_average_word_confidence(
  words : Array[TesseractIndexedWord],
) -> Double? {
  let mut count = 0
  let mut total = 0.0
  for word in words {
    match word.confidence {
      Some(value) => {
        count += 1
        total = total + value
      }
      None => ()
    }
  }
  if count == 0 {
    None
  } else {
    Some(total / count.to_double())
  }
}

///|
fn tesseract_tsv_average_ocr_line_confidence(lines : Array[OcrLine]) -> Double? {
  let mut count = 0
  let mut total = 0.0
  for line in lines {
    match line.confidence {
      Some(value) => {
        count += 1
        total = total + value
      }
      None => ()
    }
  }
  if count == 0 {
    None
  } else {
    Some(total / count.to_double())
  }
}

///|
fn tesseract_tsv_parse_int(text : String) -> Int? {
  let trimmed = text.trim().to_owned()
  Some(@string.parse_int(trimmed) catch { _ => return None })
}

///|
fn tesseract_tsv_parse_confidence(text : String) -> Double? {
  let trimmed = text.trim().to_owned()
  try @string.parse_double(trimmed) catch {
    _ =>
      try @string.parse_int(trimmed) catch {
        _ => None
      } noraise {
        value => Some(value.to_double())
      }
  } noraise {
    value => Some(value)
  }
}

///|
fn tesseract_tsv_page_index(page_num : Int) -> Int {
  if page_num <= 0 {
    0
  } else {
    page_num - 1
  }
}

///|
fn tesseract_tsv_confidence(conf : Double) -> Double? {
  if conf < 0.0 {
    None
  } else {
    Some(conf)
  }
}

///|
fn tesseract_tsv_bbox(row : TesseractTsvWordRow) -> @core.BBox {
  {
    x0: row.left.to_double(),
    y0: row.top.to_double(),
    x1: (row.left + row.width).to_double(),
    y1: (row.top + row.height).to_double(),
  }
}

///|
fn tesseract_tsv_normalize_newlines(text : String) -> String {
  text.replace(old="\r\n", new="\n").replace(old="\r", new="\n")
}
