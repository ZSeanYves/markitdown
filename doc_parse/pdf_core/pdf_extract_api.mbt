///|
pub struct PdfTextEvent {
  font_name : String?
  font_size : Double?
  text : String
}

///|
pub struct PdfPageExtractStats {
  page_index : Int
  page_obj : Int
  page_gen : Int
  stream_count : Int
  success_streams : Int
  failed_streams : Int
  event_count : Int
  text_length : Int
  is_failed : Bool
}

///|
pub struct PdfDocumentExtractResult {
  text : String
  page_count : Int
  success_pages : Int
  failed_pages : Int
  success_streams : Int
  failed_streams : Int
  event_count : Int
  non_whitespace_chars : Int
  is_empty : Bool
  is_low_signal : Bool
  is_fatal : Bool
  fatal_reason : String?
  page_stats : Array[PdfPageExtractStats]
}

///|
const PDF_NATIVE_TRACE_C1 = true

///|
fn debug_operand_kind(v : PdfContentOperand) -> String {
  match v {
    PdfContentOperand::String(_) => "String"
    PdfContentOperand::HexString(_) => "HexString"
    PdfContentOperand::Array(_) => "Array"
    PdfContentOperand::Name(_) => "Name"
    PdfContentOperand::Number(_) => "Number"
  }
}

///|
fn debug_font_keys(fonts : Map[String, PdfFontRef]) -> String {
  let ks : Array[String] = []
  for entry in fonts {
    let (k, _) = entry
    ks.push(k)
  }
  ks.join(",")
}

///|
priv struct PdfPageExtractResult {
  events : Array[PdfTextEvent]
  stream_count : Int
  success_streams : Int
  failed_streams : Int
  text : String
  text_length : Int
  is_failed : Bool
}

///|
fn decode_with_font(
  doc : PdfDocument,
  font_ref : PdfFontRef?,
  operand : PdfContentOperand,
) -> String raise {
  match font_ref {
    Some(f) => decode_text_operand(doc, f, operand)
    None => text_from_operand_fallback(operand)
  }
}

///|
fn text_from_operand_fallback(v : PdfContentOperand) -> String {
  match v {
    PdfContentOperand::String(s) => s
    PdfContentOperand::HexString(bs) => bytes_to_text_fallback(bs)
    PdfContentOperand::Array(items) => {
      let mut out = ""
      for item in items {
        match item {
          PdfContentOperand::String(s) => out = out + s
          PdfContentOperand::HexString(bs) =>
            out = out + bytes_to_text_fallback(bs)
          _ => ()
        }
      }
      out
    }
    _ => ""
  }
}

///|
fn parse_tj_with_hook(
  doc : PdfDocument,
  font_ref : PdfFontRef?,
  operand : PdfContentOperand,
) -> (String, Array[Double]) raise {
  match operand {
    PdfContentOperand::Array(items) => {
      let mut out = ""
      let spacing : Array[Double] = []
      for item in items {
        match item {
          PdfContentOperand::String(s) =>
            out = out +
              decode_with_font(doc, font_ref, PdfContentOperand::String(s))
          PdfContentOperand::HexString(bs) =>
            out = out +
              decode_with_font(doc, font_ref, PdfContentOperand::HexString(bs))
          PdfContentOperand::Number(v) => spacing.push(v)
          _ => ()
        }
      }
      (out, spacing)
    }
    _ => (decode_with_font(doc, font_ref, operand), [])
  }
}

///|
pub fn decode_text_operand(
  doc : PdfDocument,
  font_ref : PdfFontRef,
  operand : PdfContentOperand,
) -> String raise {
  decode_text_operand_with_font(doc, font_ref, operand)
}

///|
pub fn extract_text_events_from_page(
  doc : PdfDocument,
  page_obj : Int,
  page_gen : Int,
) -> Array[PdfTextEvent] raise {
  let page = extract_page_text_with_stats(doc, page_obj, page_gen)
  page.events
}

///|
fn extract_page_text_with_stats(
  doc : PdfDocument,
  page_obj : Int,
  page_gen : Int,
) -> PdfPageExtractResult raise {
  let fonts = resolve_page_fonts(doc, page_obj, page_gen) catch {
    e =>
      raise InvalidStructure(
        "failed to resolve page fonts for page " +
        page_obj.to_string() +
        " " +
        page_gen.to_string() +
        ": " +
        e.to_string(),
      )
  }

  let streams = get_page_content_stream_bytes(doc, page_obj, page_gen) catch {
    e =>
      raise InvalidStructure(
        "failed to get page content streams for page " +
        page_obj.to_string() +
        " " +
        page_gen.to_string() +
        ": " +
        e.to_string(),
      )
  }
  let events : Array[PdfTextEvent] = []
  let stream_count = streams.length()
  let mut success_streams = 0
  let mut failed_streams = 0
  let mut current_font : String? = None
  let mut current_font_size : Double? = None
  let mut in_text = false
  let mut has_emitted_text = false

  let trace_this_page = PDF_NATIVE_TRACE_C1 &&
    match fonts.get("C1") {
      Some(_) => true
      None => false
    }
  if trace_this_page {
    println(
      "[pdf-native-trace] page=" +
      page_obj.to_string() +
      " fonts={" +
      debug_font_keys(fonts) +
      "}",
    )
  }

  for stream in streams {
    let ops = extract_text_ops_from_page_stream(stream) catch {
      e => {
        if trace_this_page {
          println(
            "[pdf-native-trace] stream_parse_failed err=" + e.to_string(),
          )
        }
        failed_streams = failed_streams + 1
        continue
      }
    }
    success_streams = success_streams + 1

    for op in ops {
      if op.op == "BT" {
        in_text = true
        continue
      }
      if op.op == "ET" {
        in_text = false
        continue
      }
      if !in_text {
        continue
      }

      if op.op == "Tf" {
        if op.operands.length() >= 2 {
          match (op.operands[0], op.operands[1]) {
            (PdfContentOperand::Name(name), PdfContentOperand::Number(size)) => {
              if name.has_prefix("/") {
                current_font = Some(name[1:].to_string())
              } else {
                current_font = Some(name)
              }
              current_font_size = Some(size)
              if trace_this_page {
                println(
                  "[pdf-native-trace] Tf current_font=" +
                  current_font.unwrap_or(""),
                )
              }
            }
            _ => ()
          }
        }
        continue
      }

      if op.op == "Td" || op.op == "TD" || op.op == "Tm" || op.op == "T*" {
        if has_emitted_text {
          events.push({
            font_name: current_font,
            font_size: current_font_size,
            text: "\n\n",
          })
        }
        continue
      }

      let font_ref = match current_font {
        Some(name) => fonts.get(name)
        None => None
      }

      if op.op == "Tj" && op.operands.length() >= 1 {
        let operand = op.operands[op.operands.length() - 1]
        let operand_kind = debug_operand_kind(operand)
        let font_hit = match font_ref {
          Some(_) => true
          None => false
        }
        let text = decode_with_font(
          doc,
          font_ref,
          operand,
        ) catch {
          _ => ""
        }
        if trace_this_page {
          println(
            "[pdf-native-trace] Tj font=" +
            current_font.unwrap_or("") +
            " hit=" +
            font_hit.to_string() +
            " operand=" +
            operand_kind +
            " decode_len=" +
            text.to_array().length().to_string(),
          )
        }
        if text != "" {
          events.push({
            font_name: current_font,
            font_size: current_font_size,
            text,
          })
          has_emitted_text = true
        }
      }

      if op.op == "TJ" && op.operands.length() >= 1 {
        let (text, _spacing) = parse_tj_with_hook(
          doc,
          font_ref,
          op.operands[op.operands.length() - 1],
        ) catch {
          _ => ("", [])
        }
        if text != "" {
          events.push({
            font_name: current_font,
            font_size: current_font_size,
            text,
          })
          has_emitted_text = true
        }
      }
    }
  }

  let text = normalize_native_page_text(merge_native_page_events(events))
  let text_length = text.to_array().length()
  let is_failed = stream_count > 0 && success_streams == 0
  PdfPageExtractResult::{
    events,
    stream_count,
    success_streams,
    failed_streams,
    text,
    text_length,
    is_failed,
  }
}

///|
pub fn extract_text_from_page(
  doc : PdfDocument,
  page_obj : Int,
  page_gen : Int,
) -> String raise {
  let page = extract_page_text_with_stats(doc, page_obj, page_gen)
  page.text
}

///|
pub fn extract_text_from_document(doc : PdfDocument) -> String raise {
  let result = extract_text_from_document_result(doc)
  if result.is_fatal {
    raise InvalidStructure(
      "native text extraction marked fatal: " +
      result.fatal_reason.unwrap_or("unknown reason"),
    )
  }
  result.text
}

///|
pub fn extract_text_from_document_result(
  doc : PdfDocument,
) -> PdfDocumentExtractResult raise {
  let pages = list_page_refs(doc) catch {
    e => raise InvalidStructure("list_page_refs failed: " + e.to_string())
  }
  let mut out = ""
  let page_count = pages.length()
  let mut success_pages = 0
  let mut failed_pages = 0
  let mut success_streams = 0
  let mut failed_streams = 0
  let mut event_count = 0
  let page_stats : Array[PdfPageExtractStats] = []
  pages.eachi(fn(i, e) raise {
    let (obj, gen) = e
    let page = extract_page_text_with_stats(doc, obj, gen) catch {
      e => raise e
    }
    let page_event_count = page.events.length()
    event_count = event_count + page_event_count
    success_streams = success_streams + page.success_streams
    failed_streams = failed_streams + page.failed_streams
    if page.is_failed {
      failed_pages = failed_pages + 1
    } else {
      success_pages = success_pages + 1
    }
    page_stats.push({
      page_index: i,
      page_obj: obj,
      page_gen: gen,
      stream_count: page.stream_count,
      success_streams: page.success_streams,
      failed_streams: page.failed_streams,
      event_count: page_event_count,
      text_length: page.text_length,
      is_failed: page.is_failed,
    })
    let t = page.text
    if t != "" {
      if out != "" {
        out = out + "\f"
      }
      out = out + t
    }
  })
  let non_whitespace_chars = count_non_whitespace_chars(out)
  let is_empty = non_whitespace_chars == 0
  let too_low_events = event_count <= 1
  let too_low_text = non_whitespace_chars < 8
  let severe_page_failure = page_count > 1 && failed_pages * 2 >= page_count
  let is_low_signal = page_count > 0 &&
    (
      (too_low_events && too_low_text) ||
      (non_whitespace_chars < 16 && failed_pages > 0) ||
      (severe_page_failure && non_whitespace_chars < 32)
    )
  let all_pages_failed = page_count > 0 && failed_pages == page_count
  let is_fatal = (page_count > 0 && is_empty) ||
    all_pages_failed ||
    (severe_page_failure && non_whitespace_chars < 8)
  let fatal_reason = if page_count > 0 && is_empty {
    Some("empty_text_with_pages")
  } else if all_pages_failed {
    Some("all_pages_failed")
  } else if severe_page_failure && non_whitespace_chars < 8 {
    Some("severe_page_failure_low_text")
  } else {
    None
  }
  {
    text: out,
    page_count,
    success_pages,
    failed_pages,
    success_streams,
    failed_streams,
    event_count,
    non_whitespace_chars,
    is_empty,
    is_low_signal,
    is_fatal,
    fatal_reason,
    page_stats,
  }
}

///|
fn bytes_to_text_fallback(bs : Bytes) -> String {
  let mut out = ""
  for b in bs {
    out = out + Int::unsafe_to_char(b.to_int()).to_string()
  }
  out
}

///|
fn merge_native_page_events(events : Array[PdfTextEvent]) -> String {
  let mut out = ""
  let mut prev_text = ""
  let mut prev_was_text = false
  for ev in events {
    let cur = ev.text
    if cur == "" {
      continue
    }
    if cur == "\n\n" {
      out = out + cur
      prev_was_text = false
      prev_text = ""
      continue
    }

    if prev_was_text &&
      !out.has_suffix("\n") &&
      should_insert_event_paragraph_gap(prev_text, cur) {
      out = out + "\n\n"
    }

    out = out + cur
    prev_text = cur
    prev_was_text = true
  }
  out
}

///|
fn should_insert_event_paragraph_gap(prev : String, cur : String) -> Bool {
  let p = prev.trim().to_string()
  let c = cur.trim().to_string()
  if p == "" || c == "" {
    return false
  }
  if p.to_array().length() < 24 || c.to_array().length() < 12 {
    return false
  }
  ends_with_sentence_punct(p)
}

///|
fn ends_with_sentence_punct(s : String) -> Bool {
  if s == "" {
    return false
  }
  s.has_suffix(".") ||
  s.has_suffix("!") ||
  s.has_suffix("?") ||
  s.has_suffix("。") ||
  s.has_suffix("！") ||
  s.has_suffix("？")
}

///|
fn normalize_native_page_text(s : String) -> String {
  let lines : Array[String] = []
  for sv in s.split("\n") {
    lines.push(strip_markdown_heading_marker(sv.to_string()))
  }
  lines.join("\n")
}

///|
fn strip_markdown_heading_marker(s : String) -> String {
  let chars = s.to_array()
  let n = chars.length()
  let mut i = 0
  while i < n && chars[i] == '#' {
    i = i + 1
  }
  if i == 0 || i > 6 {
    return s
  }
  if i < n && (chars[i] == ' ' || chars[i] == '\t') {
    let mut j = i
    while j < n && (chars[j] == ' ' || chars[j] == '\t') {
      j = j + 1
    }
    return s[j:n].to_string()
  }
  s
}

///|
fn count_non_whitespace_chars(s : String) -> Int {
  let mut out = 0
  for c in s.to_array() {
    if c != ' ' && c != '\t' && c != '\n' && c != '\r' && c != '\f' {
      out = out + 1
    }
  }
  out
}
