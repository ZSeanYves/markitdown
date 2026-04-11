///|
pub struct PdfTextEvent {
  font_name : String?
  font_size : Double?
  text : String
}

///|
priv enum PdfFragmentBoundaryKind {
  EventText
  SyntheticInlineGap
}derive(Eq)

///|
priv struct PdfPageFragment {
  text : String
  _source_event_index : Int
  _font_name : String?
  _font_size : Double?
  _gap_from_prev : Double
  boundary_kind : PdfFragmentBoundaryKind
}

///|
priv struct PdfPageLine {
  _line_index : Int
  _baseline_y : Double?
  fragments : Array[PdfPageFragment]
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

const PDF_NATIVE_TRACE_C1 = false

fn debug_operand_kind(v : PdfContentOperand) -> String {
  match v {
    PdfContentOperand::String(_) => "String"
    PdfContentOperand::HexString(_) => "HexString"
    PdfContentOperand::Array(_) => "Array"
    PdfContentOperand::Name(_) => "Name"
    PdfContentOperand::Number(_) => "Number"
  }
}

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
  pretty_text : String
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
  let mut _in_text = false
  let mut _has_emitted_text = false

  let trace_this_page = PDF_NATIVE_TRACE_C1
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
        _in_text = true
        continue
      }
      if op.op == "ET" {
        _in_text = false
        continue
      }

      if op.op == "Tf" {
        if op.operands.length() >= 2 {
          let font_operand = op.operands[op.operands.length() - 2]
          let size_operand = op.operands[op.operands.length() - 1]
          match font_operand {
            PdfContentOperand::Name(name) => current_font = Some(name)
            _ => ()
          }
          match size_operand {
            PdfContentOperand::Number(size) => current_font_size = Some(size)
            _ => ()
          }
        }
        if trace_this_page {
          println(
            "[pdf-native-trace] Tf current_font=" +
            current_font.unwrap_or(""),
          )
        }
      }

      let font_ref = match current_font {
        Some(name) => fonts.get(name)
        None => None
      }

      if _in_text && (op.op == "Td" || op.op == "TD" || op.op == "Tm" || op.op == "T*") {
        let line_break_text = if is_large_text_step(op, current_font_size) {
          "\n\n"
        } else {
          "\n"
        }
        if _has_emitted_text {
          let should_emit = if events.length() == 0 {
            true
          } else {
            let last_ev = events[events.length() - 1]
            last_ev.text != "\n" && last_ev.text != "\n\n"
          }
          if should_emit {
            events.push({
              font_name: current_font,
              font_size: current_font_size,
              text: line_break_text,
            })
          }
        }
        continue
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
          _has_emitted_text = true
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
          _has_emitted_text = true
        }
      }
    }
  }

  let text = merge_page_events_low_level(events)
  let pretty_text = normalize_native_page_text(merge_page_events_pretty(events))
  let text_length = text.to_array().length()
  let is_failed = stream_count > 0 && success_streams == 0
  PdfPageExtractResult::{
    events,
    stream_count,
    success_streams,
    failed_streams,
    text,
    pretty_text,
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
pub fn extract_pretty_text_from_page(
  doc : PdfDocument,
  page_obj : Int,
  page_gen : Int,
) -> String raise {
  let page = extract_page_text_with_stats(doc, page_obj, page_gen)
  page.pretty_text
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
pub fn extract_pretty_text_from_document(doc : PdfDocument) -> String raise {
  let pages = list_page_refs(doc) catch {
    e => raise InvalidStructure("list_page_refs failed: " + e.to_string())
  }
  let mut out = ""
  pages.each(fn(e) raise {
    let (obj, gen) = e
    let page = extract_page_text_with_stats(doc, obj, gen)
    if page.text != "" {
      if out != "" {
        out = out + "\f"
      }
      out = out + page.pretty_text
    }
  })
  out
}

///|
pub fn debug_dump_pdf_page_text_ops_events_pretty(
  doc : PdfDocument,
  page_obj : Int,
  page_gen : Int,
  page_index : Int,
) -> String raise {
  let fonts = resolve_page_fonts(doc, page_obj, page_gen)
  let streams = get_page_content_stream_bytes(doc, page_obj, page_gen)
  let page = extract_page_text_with_stats(doc, page_obj, page_gen)

  let lines : Array[String] = []
  lines.push(
    "== page " +
    page_index.to_string() +
    " (obj=" +
    page_obj.to_string() +
    " gen=" +
    page_gen.to_string() +
    ") ==",
  )
  lines.push("[text ops]")

  let mut op_index = 0
  let mut stream_index = 0
  for stream in streams {
    let ops = extract_text_ops_from_page_stream(stream) catch {
      e => {
        lines.push(
          "[stream " +
          stream_index.to_string() +
          "] parse_error=" +
          e.to_string(),
        )
        stream_index = stream_index + 1
        continue
      }
    }
    let mut current_font : String? = None
    let mut current_font_size : Double? = None
    for op in ops {
      if op.op == "Tf" && op.operands.length() >= 2 {
        let font_operand = op.operands[op.operands.length() - 2]
        let size_operand = op.operands[op.operands.length() - 1]
        match font_operand {
          PdfContentOperand::Name(name) => current_font = Some(name)
          _ => ()
        }
        match size_operand {
          PdfContentOperand::Number(size) => current_font_size = Some(size)
          _ => ()
        }
      }

      if op.op == "Tj" && op.operands.length() >= 1 {
        let operand = op.operands[op.operands.length() - 1]
        let font_ref = match current_font {
          Some(name) => fonts.get(name)
          None => None
        }
        let decoded = decode_with_font(doc, font_ref, operand) catch {
          _ => ""
        }
        lines.push(
          "[" +
          op_index.to_string() +
          "] page=" +
          page_index.to_string() +
          " kind=Tj stream=" +
          stream_index.to_string() +
          " font=" +
          current_font.unwrap_or("") +
          " size=" +
          debug_opt_double(current_font_size) +
          " raw=" +
          debug_operand_compact(operand) +
          " decoded=\"" +
          debug_string_compact(decoded) +
          "\"",
        )
        op_index = op_index + 1
        continue
      }

      if op.op == "TJ" && op.operands.length() >= 1 {
        let operand = op.operands[op.operands.length() - 1]
        let font_ref = match current_font {
          Some(name) => fonts.get(name)
          None => None
        }
        let (decoded, spacing) = parse_tj_with_hook(doc, font_ref, operand) catch {
          _ => ("", [])
        }
        lines.push(
          "[" +
          op_index.to_string() +
          "] page=" +
          page_index.to_string() +
          " kind=TJ stream=" +
          stream_index.to_string() +
          " font=" +
          current_font.unwrap_or("") +
          " size=" +
          debug_opt_double(current_font_size) +
          " raw=" +
          debug_operand_compact(operand) +
          " spacing=" +
          debug_spacing_compact(spacing) +
          " decoded=\"" +
          debug_string_compact(decoded) +
          "\"",
        )
        op_index = op_index + 1
      }
    }
    stream_index = stream_index + 1
  }

  lines.push("")
  lines.push("[events]")
  page.events.eachi(fn(i, ev) {
    lines.push(
      "[" +
      i.to_string() +
      "] font=" +
      ev.font_name.unwrap_or("") +
      " size=" +
      debug_opt_double(ev.font_size) +
      " text=\"" +
      debug_string_compact(ev.text) +
      "\"",
    )
  })

  lines.push("")
  lines.push("[pretty]")
  lines.push("\"" + debug_string_compact(page.pretty_text) + "\"")
  lines.push("")
  lines.join("\n")
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
fn merge_page_events_low_level(events : Array[PdfTextEvent]) -> String {
  let mut out = ""
  for ev in events {
    if ev.text != "" {
      out = out + ev.text
    }
  }
  out
}

///|
fn debug_opt_double(v : Double?) -> String {
  match v {
    Some(x) => x.to_string()
    None => "none"
  }
}

///|
fn debug_string_compact(s : String) -> String {
  let mut out = ""
  for c in s.to_array() {
    out = out + (
      match c {
        '\\' => "\\\\"
        '\n' => "\\n"
        '\r' => "\\r"
        '\t' => "\\t"
        '"' => "\\\""
        _ => c.to_string()
      }
    )
  }
  out
}

///|
fn debug_operand_compact(op : PdfContentOperand) -> String {
  match op {
    PdfContentOperand::Number(v) => v.to_string()
    PdfContentOperand::Name(v) => "/" + v
    PdfContentOperand::String(v) => "(" + debug_string_compact(v) + ")"
    PdfContentOperand::HexString(bs) => "<" + debug_hex_bytes(bs) + ">"
    PdfContentOperand::Array(items) => {
      let parts : Array[String] = []
      for item in items {
        parts.push(debug_operand_compact(item))
      }
      "[" + parts.join(" ") + "]"
    }
  }
}

///|
fn debug_spacing_compact(xs : Array[Double]) -> String {
  if xs.length() == 0 {
    return "[]"
  }
  let parts : Array[String] = []
  for v in xs {
    parts.push(v.to_string())
  }
  "[" + parts.join(", ") + "]"
}

///|
fn debug_hex_bytes(bs : Bytes) -> String {
  let mut out = ""
  for b in bs {
    out = out + debug_hex_nibble((b.to_int() >> 4) & 0xF)
    out = out + debug_hex_nibble(b.to_int() & 0xF)
  }
  out
}

///|
fn debug_hex_nibble(v : Int) -> String {
  if v < 10 {
    Int::unsafe_to_char('0'.to_int() + v).to_string()
  } else {
    Int::unsafe_to_char('A'.to_int() + (v - 10)).to_string()
  }
}

fn merge_page_events_pretty(events : Array[PdfTextEvent]) -> String {
  let lines = build_page_lines_from_events(events)
  let joined = join_page_line_fragments(lines)
  render_pretty_page_text(joined)
}

///|
fn build_page_lines_from_events(events : Array[PdfTextEvent]) -> Array[PdfPageLine] {
  let lines : Array[PdfPageLine] = [{ _line_index: 0, _baseline_y: None, fragments: [] }]
  let mut current_line = 0
  let mut prev_text = ""
  let mut prev_was_text = false
  let mut event_index = 0
  while event_index < events.length() {
    let event = events[event_index]
    let cur = event.text
    if cur == "" {
      event_index = event_index + 1
      continue
    }
    if cur == "\n\n" {
      current_line = ensure_next_line(lines, current_line)
      current_line = ensure_next_line(lines, current_line)
      prev_text = ""
      prev_was_text = false
      event_index = event_index + 1
      continue
    }
    if cur == "\n" {
      current_line = ensure_next_line(lines, current_line)
      prev_text = ""
      prev_was_text = false
      event_index = event_index + 1
      continue
    }
    if prev_was_text && should_insert_event_paragraph_gap(prev_text, cur) {
      current_line = ensure_next_line(lines, current_line)
      current_line = ensure_next_line(lines, current_line)
      prev_text = ""
      prev_was_text = false
    }
    if prev_was_text && should_insert_event_inline_space(prev_text, cur) {
      lines[current_line].fragments.push({
        text: " ",
        _source_event_index: event_index,
        _font_name: event.font_name,
        _font_size: event.font_size,
        _gap_from_prev: 1.0,
        boundary_kind: PdfFragmentBoundaryKind::SyntheticInlineGap,
      })
    }
    lines[current_line].fragments.push({
      text: cur,
      _source_event_index: event_index,
      _font_name: event.font_name,
      _font_size: event.font_size,
      _gap_from_prev: 0.0,
      boundary_kind: PdfFragmentBoundaryKind::EventText,
    })
    prev_text = cur
    prev_was_text = true
    event_index = event_index + 1
  }
  lines
}

///|
fn ensure_next_line(lines : Array[PdfPageLine], current_line : Int) -> Int {
  let next_index = current_line + 1
  if next_index >= lines.length() {
    lines.push({ _line_index: next_index, _baseline_y: None, fragments: [] })
  }
  next_index
}

///|
fn join_page_line_fragments(lines : Array[PdfPageLine]) -> Array[PdfPageLine] {
  let out : Array[PdfPageLine] = []
  for line in lines {
    let joined : Array[PdfPageFragment] = []
    let n = line.fragments.length()
    let mut i = 0
    while i < n {
      let frag = line.fragments[i]
      if frag.boundary_kind == PdfFragmentBoundaryKind::SyntheticInlineGap &&
        frag.text == " " &&
        i > 0 &&
        joined.length() > 0 &&
        i + 1 < n {
        let left = joined[joined.length() - 1]
        let right = line.fragments[i + 1]
        if should_join_fragments_within_line(left.text, right.text) {
          i = i + 1
          continue
        }
      }
      joined.push(frag)
      i = i + 1
    }
    out.push({ ..line, fragments: joined })
  }
  out
}

///|
fn render_pretty_page_text(lines : Array[PdfPageLine]) -> String {
  let texts : Array[String] = []
  for line in lines {
    let mut line_text = ""
    for frag in line.fragments {
      line_text = line_text + frag.text
    }
    texts.push(trim_right_inline_space(line_text))
  }
  texts.join("\n")
}

///|
fn is_large_text_step(op : PdfTextOp, font_size : Double?) -> Bool {
  if op.op == "TD" && op.operands.length() >= 1 {
    let last = op.operands[op.operands.length() - 1]
    let abs_ty = match last {
      PdfContentOperand::Number(v) => if v < 0 { -v } else { v }
      _ => 0.0
    }
    let threshold = match font_size {
      Some(fs) => if fs > 0.0 { fs * 1.6 } else { 18.0 }
      None => 18.0
    }
    return abs_ty >= threshold
  }
  false
}

fn should_insert_event_inline_space(prev : String, cur : String) -> Bool {
  let p = prev.trim().to_string()
  let c = cur.trim().to_string()
  if p == "" || c == "" {
    return false
  }
  if p.has_suffix("-") || p.has_suffix("—") || p.has_suffix("–") {
    return false
  }
  let pa = p.to_array()
  let ca = c.to_array()
  if pa.length() == 0 || ca.length() == 0 {
    return false
  }
  let l = pa[pa.length() - 1]
  let r = ca[0]
  is_ascii_word_like(l) && is_ascii_word_like(r)
}

///|
fn should_join_fragments_within_line(left : String, right : String) -> Bool {
  let left_norm = normalize_fragment_text_for_join(left)
  let right_norm = normalize_fragment_text_for_join(right)
  let p = trim_right_inline_space(left_norm).trim().to_string()
  let c = trim_left_inline_space(right_norm).trim().to_string()
  if p == "" || c == "" {
    return false
  }
  let pa = p.to_array()
  let ca = c.to_array()
  if pa.length() == 0 || ca.length() == 0 {
    return false
  }
  let l = pa[pa.length() - 1]
  let r = ca[0]
  if is_cjk_join_char(l) && is_cjk_join_char(r) {
    return true
  }
  if !is_ascii_letter(l) || !is_ascii_letter(r) {
    return false
  }
  let left = trailing_ascii_letters(p)
  let right = leading_ascii_letters(c)
  should_join_ascii_fragments(left, right)
}

///|
fn normalize_fragment_text_for_join(s : String) -> String {
  let mut out = ""
  for c in s.to_array() {
    out = out + (
      match c {
        'ﬀ' => "ff"
        'ﬁ' => "fi"
        'ﬂ' => "fl"
        'ﬃ' => "ffi"
        'ﬄ' => "ffl"
        '⼀' => "一"
        '⼆' => "二"
        '⾸' => "首"
        '⽂' => "文"
        '⽬' => "目"
        '⽤' => "用"
        '⽀' => "支"
        '⽅' => "方"
        '⽣' => "生"
        '⾏' => "行"
        _ => c.to_string()
      }
    )
  }
  out
}

///|
fn should_join_ascii_fragments(left : String, right : String) -> Bool {
  if !is_ascii_lower_word(left) || !is_ascii_lower_word(right) {
    return false
  }
  if left.length() > 10 || right.length() > 10 {
    return false
  }
  if is_ligature_chunk(left) || is_ligature_chunk(right) {
    return true
  }
  ends_with_ligature_chunk(left) && right.length() <= 5
}

///|
fn trailing_ascii_letters(s : String) -> String {
  let chars = s.to_array()
  let n = chars.length()
  let mut i = n - 1
  while i >= 0 && is_ascii_letter(chars[i]) {
    i = i - 1
  }
  s[i + 1:n].to_string()
}

///|
fn leading_ascii_letters(s : String) -> String {
  let chars = s.to_array()
  let n = chars.length()
  let mut i = 0
  while i < n && is_ascii_letter(chars[i]) {
    i = i + 1
  }
  s[0:i].to_string()
}

///|
fn is_ligature_chunk(s : String) -> Bool {
  s == "fi" || s == "fl" || s == "ff" || s == "ffi" || s == "ffl"
}

///|
fn ends_with_ligature_chunk(s : String) -> Bool {
  s.has_suffix("fi") ||
  s.has_suffix("fl") ||
  s.has_suffix("ff") ||
  s.has_suffix("ffi") ||
  s.has_suffix("ffl")
}

///|
fn is_ascii_lower_word(s : String) -> Bool {
  if s == "" {
    return false
  }
  for c in s.to_array() {
    if !is_ascii_lower(c) {
      return false
    }
  }
  true
}

///|
fn is_ascii_letter(c : Char) -> Bool {
  is_ascii_lower(c) || is_ascii_upper(c)
}

///|
fn is_ascii_lower(c : Char) -> Bool {
  let v = c.to_int()
  v >= 'a'.to_int() && v <= 'z'.to_int()
}

///|
fn is_ascii_upper(c : Char) -> Bool {
  let v = c.to_int()
  v >= 'A'.to_int() && v <= 'Z'.to_int()
}

///|
fn is_cjk_join_char(c : Char) -> Bool {
  is_cjk_ideograph(c) || is_cjk_compat_kangxi_radical(c)
}

///|
fn is_cjk_compat_kangxi_radical(c : Char) -> Bool {
  let v = c.to_int()
  v >= 0x2F00 && v <= 0x2FDF
}

///|
fn is_cjk_ideograph(c : Char) -> Bool {
  let v = c.to_int()
  (v >= 0x3400 && v <= 0x4DBF) ||
  (v >= 0x4E00 && v <= 0x9FFF) ||
  (v >= 0xF900 && v <= 0xFAFF) ||
  (v >= 0x20000 && v <= 0x2A6DF) ||
  (v >= 0x2A700 && v <= 0x2B73F) ||
  (v >= 0x2B740 && v <= 0x2B81F) ||
  (v >= 0x2B820 && v <= 0x2CEAF) ||
  (v >= 0x2CEB0 && v <= 0x2EBEF) ||
  (v >= 0x30000 && v <= 0x3134F)
}

///|
fn trim_left_inline_space(s : String) -> String {
  let chars = s.to_array()
  let n = chars.length()
  let mut i = 0
  while i < n && (chars[i] == ' ' || chars[i] == '\t') {
    i = i + 1
  }
  s[i:n].to_string()
}

///|
fn trim_right_inline_space(s : String) -> String {
  let chars = s.to_array()
  let n = chars.length()
  if n == 0 {
    return s
  }
  let mut i = n - 1
  while i >= 0 && (chars[i] == ' ' || chars[i] == '\t') {
    i = i - 1
  }
  s[0:i + 1].to_string()
}

///|
fn is_ascii_word_like(c : Char) -> Bool {
  let v = c.to_int()
  (v >= '0'.to_int() && v <= '9'.to_int()) ||
  (v >= 'A'.to_int() && v <= 'Z'.to_int()) ||
  (v >= 'a'.to_int() && v <= 'z'.to_int())
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
