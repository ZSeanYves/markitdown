///|
pub struct PdfTextEvent {
  font_name : String?
  font_size : Double?
  text : String
}

///|
fn map_parse_error(_e : PdfParseError) -> PdfNativeError {
  PdfNativeError::ExtractionFailed("native extraction failed")
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
fn text_from_operand_fallback(v : PdfContentOperand) -> String raise {
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
  let (cmap, code_widths) = match
    (font_ref.to_unicode_obj, font_ref.to_unicode_gen) {
    (Some(obj), Some(gen)) => {
      let o = get_indirect_object(doc, obj, gen)
      match o.stream {
        Some(bs) => (parse_tounicode_cmap(bs), infer_cmap_code_widths(bs))
        None => (Map::new(), [1])
      }
    }
    _ => (Map::new(), [1])
  }

  let decode_bytes = fn(bs : Bytes) -> String raise {
    let mut out = ""
    let mut i = 0
    let n = bs.length()
    while i < n {
      let mut matched = false
      for w in code_widths {
        if matched {
          continue
        }
        if w <= 0 || i + w > n {
          continue
        }
        let mut code = 0
        let mut j = 0
        while j < w {
          code = code * 256 + bs[i + j].to_int()
          j = j + 1
        }
        match cmap.get(code) {
          Some(ch) => {
            out = out + ch
            i = i + w
            matched = true
          }
          None => ()
        }
      }
      if !matched {
        out = out + @utf8.decode([bs[i]])
        i = i + 1
      }
    }
    out
  }

  match operand {
    PdfContentOperand::String(s) => decode_bytes(@utf8.encode(s))
    PdfContentOperand::HexString(bs) => decode_bytes(bs)
    PdfContentOperand::Array(items) => {
      let mut out = ""
      for item in items {
        match item {
          PdfContentOperand::String(s) =>
            out = out + decode_bytes(@utf8.encode(s))
          PdfContentOperand::HexString(bs) => out = out + decode_bytes(bs)
          _ => ()
        }
      }
      out
    }
    _ => ""
  }
}

///|
fn all_hex_between_angles_local(line : String) -> Array[String] {
  let out : Array[String] = []
  let mut i = 0
  while i < line.length() {
    let mut l = i
    while l < line.length() && line[l] != '<' {
      l = l + 1
    }
    if l >= line.length() {
      break
    }
    let mut r = l + 1
    while r < line.length() && line[r] != '>' {
      r = r + 1
    }
    if r >= line.length() {
      break
    }
    out.push(line[l + 1:r].to_string())
    i = r + 1
  }
  out
}

///|
fn infer_cmap_code_widths(stream : Bytes) -> Array[Int] raise {
  let text = @utf8.decode(stream)
  let has_width : Map[Int, Bool] = Map::new()
  for sv in text.split("\n") {
    let line = sv.to_string().trim().to_string()
    let hs = all_hex_between_angles_local(line)
    if hs.length() == 0 {
      continue
    }
    let src = hs[0]
    if src.length() % 2 == 0 {
      let w = src.length() / 2
      if w >= 1 && w <= 4 {
        has_width.set(w, true)
      }
    }
  }

  let out : Array[Int] = []
  let mut w = 4
  while w >= 1 {
    match has_width.get(w) {
      Some(true) => out.push(w)
      _ => ()
    }
    w = w - 1
  }
  if out.length() == 0 {
    [1]
  } else {
    out
  }
}

///|
pub fn extract_text_events_from_page(
  doc : PdfDocument,
  page_obj : Int,
  page_gen : Int,
) -> Array[PdfTextEvent] raise {
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
  let mut current_font : String? = None
  let mut current_font_size : Double? = None
  let mut in_text = false
  let mut has_emitted_text = false

  for stream in streams {
    let ops = extract_text_ops_from_page_stream(stream) catch {
      e =>
        raise InvalidStructure(
          "failed to extract text ops from page stream: " + e.to_string(),
        )
    }

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
        let text = decode_with_font(
          doc,
          font_ref,
          op.operands[op.operands.length() - 1],
        ) catch {
          _ => ""
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

  events
}

///|
pub fn extract_text_from_page(
  doc : PdfDocument,
  page_obj : Int,
  page_gen : Int,
) -> String raise {
  let events = extract_text_events_from_page(doc, page_obj, page_gen) catch {
    e => raise e
  }
  let mut out = ""
  for ev in events {
    out = out + ev.text
  }
  normalize_native_page_text(out)
}

///|
pub fn extract_text_from_document(doc : PdfDocument) -> String raise {
  let pages = list_page_refs(doc) catch {
    e => raise InvalidStructure("list_page_refs failed: " + e.to_string())
  }
  let mut out = ""
  for e in pages {
    let (obj, gen) = e
    let t = extract_text_from_page(doc, obj, gen) catch { e => raise e }
    if t != "" {
      if out != "" {
        out = out + "\f"
      }
      out = out + t
    }
  }
  out
}

///|
fn bytes_to_text_fallback(bs : Bytes) -> String raise {
  let mut out = ""
  for b in bs {
    out = out + @utf8.decode([b])
  }
  out
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
