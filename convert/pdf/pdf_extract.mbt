///|
priv struct PdfExtractResult {
  _backend_name : String
  text : String
  _exit_status : Int
  _stderr : String
  _quality : PdfTextQuality
  quality_accepted : Bool
  _native_stats : @pdfc.PdfNativeDocumentResult?
}

///|
priv struct PdfConvertLine {
  text : String
  source_event_start : Int
  source_event_end : Int
  font_name : String?
  font_size : Double?
  is_explicit_break : Bool
}

///|
priv struct PdfConvertPage {
  page_index : Int
  lines : Array[PdfConvertLine]
}

///|
priv enum PdfConvertBlockKind {
  StandaloneLine
  Paragraph
}

///|
priv struct PdfConvertBlock {
  kind : PdfConvertBlockKind
  text : String
  page_index : Int
  line_start : Int
  line_end : Int
}

///|
fn extract_pdf_text_result(
  path : String,
  debug? : Bool = false,
) -> Result[PdfExtractResult, @cor.AppError] {
  extract_pdf_text_native(path, debug~)
}

///|
fn map_native_error(e : Error) -> @cor.AppError {
  match e {
    @pdfc.PdfNativeError::UnsupportedFeature(msg) =>
      @cor.AppError("pdf-native unsupported: " + msg)
    @pdfc.ExtractionFailed(msg) =>
      @cor.AppError("pdf-native unexpected_crash: " + msg)
    @pdfc.PdfParseError::InvalidHeader(msg) =>
      @cor.AppError("pdf-native parser_error: invalid header: " + msg)
    @pdfc.PdfParseError::InvalidStructure(msg) =>
      @cor.AppError("pdf-native parser_error: invalid structure: " + msg)
    @pdfc.PdfParseError::UnexpectedEOF(msg) =>
      @cor.AppError("pdf-native parser_error: unexpected eof: " + msg)
    @pdfc.PdfParseError::ObjectNotFound(obj, gen) =>
      @cor.AppError(
        "pdf-native parser_error: object not found: " +
        obj.to_string() +
        " " +
        gen.to_string() +
        " R",
      )
    @pdfc.PdfParseError::TypeMismatch(msg) =>
      @cor.AppError("pdf-native parser_error: type mismatch: " + msg)
    @pdfc.PdfParseError::UnsupportedFeature(msg) =>
      @cor.AppError("pdf-native unsupported: " + msg)
    _ => @cor.AppError("pdf-native error: " + e.to_string())
  }
}

///|
fn extract_pdf_text_native(
  path : String,
  debug? : Bool = false,
) -> Result[PdfExtractResult, @cor.AppError] {
  let bytes = @fs.read_file_to_bytes(path) catch {
    e => return Err(@cor.AppError("read pdf failed: " + e.to_string()))
  }

  let doc = @pdfc.open_pdf(bytes) catch { e => return Err(map_native_error(e)) }

  let native = @pdfc.extract_document_events_result(doc) catch {
    e => return Err(map_native_error(e))
  }
  let convert_pages = native_document_events_to_pages(native)
  let convert_blocks = native_document_events_to_blocks(native)
  let text = pdf_convert_blocks_to_text(convert_blocks)

  let cleaned = cleanup_pdf_text(text)
  let quality = analyze_pdf_text_quality(cleaned)
  if debug {
    println("[pdf-debug] selected backend=pdf-native")
    println(
      "[pdf-debug] native_stats pages=" +
      native.page_count.to_string() +
      " success_pages=" +
      native.success_pages.to_string() +
      " failed_pages=" +
      native.failed_pages.to_string() +
      " success_streams=" +
      native.success_streams.to_string() +
      " failed_streams=" +
      native.failed_streams.to_string() +
      " events=" +
      native.event_count.to_string() +
      " non_ws_chars=" +
      native.non_whitespace_chars.to_string() +
      " empty=" +
      native.is_empty.to_string() +
      " low_signal=" +
      native.is_low_signal.to_string() +
      " fatal=" +
      native.is_fatal.to_string(),
    )
    for p in native.pages {
      println(
        "[pdf-debug] page[" +
        p.page_index.to_string() +
        "] streams=" +
        p.stream_count.to_string() +
        " ok=" +
        p.success_streams.to_string() +
        " fail=" +
        p.failed_streams.to_string() +
        " events=" +
        p.events.length().to_string() +
        " text_len=" +
        p.text_length.to_string() +
        " failed=" +
        p.is_failed.to_string(),
      )
    }
    for cp in convert_pages {
      println(
        "[pdf-debug] convert_page[" +
        cp.page_index.to_string() +
        "] line_count=" +
        cp.lines.length().to_string(),
      )
      let mut shown = 0
      for ln in cp.lines {
        if shown >= 3 {
          break
        }
        println(
          "[pdf-debug]   line[" +
          shown.to_string() +
          "] range=" +
          ln.source_event_start.to_string() +
          "-" +
          ln.source_event_end.to_string() +
          " break=" +
          ln.is_explicit_break.to_string() +
          " text=\"" +
          debug_line_preview(ln.text) +
          "\"",
        )
        shown = shown + 1
      }
    }
    for page_blocks in convert_blocks {
      if page_blocks.length() == 0 {
        continue
      }
      let page_index = page_blocks[0].page_index
      println(
        "[pdf-debug] convert_page_blocks[" +
        page_index.to_string() +
        "] block_count=" +
        page_blocks.length().to_string(),
      )
    }
  }

  if native.is_fatal {
    return Err(
      @cor.AppError(
        "pdf-native fatal extraction: " +
        native.fatal_reason.unwrap_or("unknown_reason"),
      ),
    )
  }
  if native.is_low_signal {
    return Err(
      @cor.AppError(
        "pdf-native low-signal extraction: pages=" +
        native.page_count.to_string() +
        " failed_pages=" +
        native.failed_pages.to_string() +
        " events=" +
        native.event_count.to_string() +
        " non_ws_chars=" +
        native.non_whitespace_chars.to_string(),
      ),
    )
  }

  Ok({
    _backend_name: "pdf-native",
    text: cleaned,
    _exit_status: 0,
    _stderr: "",
    _quality: quality,
    quality_accepted: !is_quality_failure_for_normal_text(quality),
    _native_stats: Some(native),
  })
}

///|
fn native_document_events_to_pages(
  native : @pdfc.PdfNativeDocumentResult,
) -> Array[PdfConvertPage] {
  let out : Array[PdfConvertPage] = []
  for page in native.pages {
    out.push({
      page_index: page.page_index,
      lines: native_page_events_to_lines(page.events),
    })
  }
  out
}

///|
fn native_document_events_to_blocks(
  native : @pdfc.PdfNativeDocumentResult,
) -> Array[Array[PdfConvertBlock]] {
  let pages = native_document_events_to_pages(native)
  let out : Array[Array[PdfConvertBlock]] = []
  for page in pages {
    out.push(native_page_lines_to_blocks(page.page_index, page.lines))
  }
  out
}

///|
fn native_page_lines_to_blocks(
  page_index : Int,
  lines : Array[PdfConvertLine],
) -> Array[PdfConvertBlock] {
  let blocks : Array[PdfConvertBlock] = []
  let para_lines : Array[String] = []
  let mut para_start = -1
  let mut para_end = -1

  let mut i = 0
  while i < lines.length() {
    let line = lines[i]
    let text = line.text.trim().to_string()
    if line.is_explicit_break || text == "" {
      if para_lines.length() > 0 {
        let para_text = para_lines.join(" ").trim().to_string()
        if para_text != "" {
          blocks.push({
            kind: PdfConvertBlockKind::Paragraph,
            text: para_text,
            page_index: page_index,
            line_start: para_start,
            line_end: para_end,
          })
        }
        para_lines.clear()
        para_start = -1
        para_end = -1
      }
      i = i + 1
      continue
    }

    if should_be_standalone_line(lines, i) {
      if para_lines.length() > 0 {
        let para_text = para_lines.join(" ").trim().to_string()
        if para_text != "" {
          blocks.push({
            kind: PdfConvertBlockKind::Paragraph,
            text: para_text,
            page_index: page_index,
            line_start: para_start,
            line_end: para_end,
          })
        }
        para_lines.clear()
        para_start = -1
        para_end = -1
      }
      blocks.push({
        kind: PdfConvertBlockKind::StandaloneLine,
        text: text,
        page_index: page_index,
        line_start: i,
        line_end: i,
      })
      i = i + 1
      continue
    }

    if para_start < 0 {
      para_start = i
    }
    para_end = i
    para_lines.push(text)
    i = i + 1
  }

  if para_lines.length() > 0 {
    let para_text = para_lines.join(" ").trim().to_string()
    if para_text != "" {
      blocks.push({
        kind: PdfConvertBlockKind::Paragraph,
        text: para_text,
        page_index: page_index,
        line_start: para_start,
        line_end: para_end,
      })
    }
  }
  blocks
}

///|
fn should_be_standalone_line(lines : Array[PdfConvertLine], i : Int) -> Bool {
  if i < 0 || i >= lines.length() {
    return false
  }
  let text = lines[i].text.trim().to_string()
  if text == "" {
    return false
  }

  let cur_len = text_len(text)
  if cur_len == 0 {
    return false
  }

  if cur_len <= 36 && looks_like_section_marker_line(text) {
    return true
  }

  if cur_len <= 8 && !looks_like_sentence_line(text) {
    return true
  }

  if cur_len > 20 {
    return false
  }

  let prev_len = prev_non_break_line_len(lines, i)
  let next_len = next_non_break_line_len(lines, i)
  let long_neighbor = if prev_len > next_len { prev_len } else { next_len }
  long_neighbor >= 36 &&
  long_neighbor >= cur_len * 2 &&
  !looks_like_sentence_line(text)
}

///|
fn prev_non_break_line_len(lines : Array[PdfConvertLine], i : Int) -> Int {
  let mut j = i - 1
  while j >= 0 {
    let line = lines[j]
    let t = line.text.trim().to_string()
    if !line.is_explicit_break && t != "" {
      return text_len(t)
    }
    if j == 0 {
      break
    }
    j = j - 1
  }
  0
}

///|
fn next_non_break_line_len(lines : Array[PdfConvertLine], i : Int) -> Int {
  let mut j = i + 1
  while j < lines.length() {
    let line = lines[j]
    let t = line.text.trim().to_string()
    if !line.is_explicit_break && t != "" {
      return text_len(t)
    }
    j = j + 1
  }
  0
}

///|
fn looks_like_section_marker_line(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }
  t.contains("第") && (t.contains("章") || t.contains("节")) ||
  t.contains("Chapter") ||
  t.contains("CHAPTER") ||
  t.contains("Section") ||
  t.contains("SECTION") ||
  t.contains("、") ||
  t.contains(")")
}

///|
fn looks_like_sentence_line(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }
  t.contains("。") ||
  t.contains("！") ||
  t.contains("？") ||
  t.contains(".") ||
  t.contains("!") ||
  t.contains("?") ||
  t.contains("，") ||
  t.contains(",")
}

///|
fn text_len(s : String) -> Int {
  s.to_array().length()
}

///|
fn native_page_events_to_lines(
  events : Array[@pdfc.PdfTextEvent],
) -> Array[PdfConvertLine] {
  let lines : Array[PdfConvertLine] = []
  let mut cur_text = ""
  let mut cur_start = -1
  let mut cur_end = -1
  let mut cur_font_name : String? = None
  let mut cur_font_size : Double? = None

  let mut i = 0
  while i < events.length() {
    let ev = events[i]
    if ev.text == "" {
      i = i + 1
      continue
    }

    if ev.text == "\n" {
      if cur_text != "" {
        lines.push({
          text: cur_text,
          source_event_start: cur_start,
          source_event_end: cur_end,
          font_name: cur_font_name,
          font_size: cur_font_size,
          is_explicit_break: false,
        })
        cur_text = ""
        cur_start = -1
        cur_end = -1
        cur_font_name = None
        cur_font_size = None
      }
      i = i + 1
      continue
    }

    if ev.text == "\n\n" {
      if cur_text != "" {
        lines.push({
          text: cur_text,
          source_event_start: cur_start,
          source_event_end: cur_end,
          font_name: cur_font_name,
          font_size: cur_font_size,
          is_explicit_break: false,
        })
        cur_text = ""
        cur_start = -1
        cur_end = -1
        cur_font_name = None
        cur_font_size = None
      }
      lines.push({
        text: "",
        source_event_start: i,
        source_event_end: i,
        font_name: None,
        font_size: None,
        is_explicit_break: true,
      })
      i = i + 1
      continue
    }

    if cur_text == "" {
      cur_start = i
      cur_font_name = ev.font_name
      cur_font_size = ev.font_size
    }
    cur_text = cur_text + ev.text
    cur_end = i
    i = i + 1
  }

  if cur_text != "" {
    lines.push({
      text: cur_text,
      source_event_start: cur_start,
      source_event_end: cur_end,
      font_name: cur_font_name,
      font_size: cur_font_size,
      is_explicit_break: false,
    })
  }
  lines
}

///|
fn pdf_convert_blocks_to_text(pages : Array[Array[PdfConvertBlock]]) -> String {
  let page_texts : Array[String] = []
  for page_blocks in pages {
    let block_texts : Array[String] = []
    for block in page_blocks {
      if block.text.trim() != "" {
        block_texts.push(block.text)
      }
    }
    if block_texts.length() > 0 {
      page_texts.push(block_texts.join("\n\n"))
    }
  }
  page_texts.join("\f")
}

///|
fn debug_line_preview(s : String) -> String {
  let t = s.replace(old="\n", new="\\n").replace(old="\r", new="\\r")
  if t.to_array().length() <= 80 {
    t
  } else {
    t[:80].to_string() + "..."
  }
}
