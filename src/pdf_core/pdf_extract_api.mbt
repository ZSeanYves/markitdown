///|
pub struct PdfTextEvent {
  font_name : String?
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
fn text_from_operand_fallback(v : PdfContentOperand) -> String {
  match v {
    PdfContentOperand::String(s) => s
    PdfContentOperand::Array(items) => {
      let mut out = ""
      for item in items {
        match item {
          PdfContentOperand::String(s) => out = out + s
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
          PdfContentOperand::String(s) => {
            out = out + decode_with_font(doc, font_ref, PdfContentOperand::String(s))
          }
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
  let cmap : Map[Int, String] = match (font_ref.to_unicode_obj, font_ref.to_unicode_gen) {
    (Some(obj), Some(gen)) => {
      let o = get_indirect_object(doc, obj, gen)
      match o.stream {
        Some(bs) => parse_tounicode_cmap(bs)
        None => Map::new()
      }
    }
    _ => Map::new()
  }

  let decode_string = fn(s : String) -> String {
    let mut out = ""
    for b in @utf8.encode(s) {
      match cmap.get(b.to_int()) {
        Some(ch) => out = out + ch
        None => out = out + @utf8.decode([b])
      }
    }
    out
  }

  match operand {
    PdfContentOperand::String(s) => decode_string(s)
    PdfContentOperand::Array(items) => {
      let mut out = ""
      for item in items {
        match item {
          PdfContentOperand::String(s) => out = out + decode_string(s)
          _ => ()
        }
      }
      out
    }
    _ => ""
  }
}

///|
pub fn extract_text_events_from_page(
  doc : PdfDocument,
  page_obj : Int,
  page_gen : Int,
) -> Array[PdfTextEvent] raise {
  let fonts = resolve_page_fonts(doc, page_obj, page_gen) catch {
    e => raise map_parse_error(e)
  }
  let streams = get_page_content_stream_bytes(doc, page_obj, page_gen) catch {
    e => raise map_parse_error(e)
  }

  let events : Array[PdfTextEvent] = []
  let mut current_font : String? = None
  let mut in_text = false

  for stream in streams {
    let ops = extract_text_ops_from_page_stream(stream) catch {
      e => raise map_parse_error(e)
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
        if op.operands.length() >= 1 {
          match op.operands[0] {
            PdfContentOperand::Name(name) => current_font = Some(name)
            _ => ()
          }
        }
        continue
      }

      let font_ref = match current_font {
        Some(name) => fonts.get(name)
        None => None
      }

      if op.op == "Tj" && op.operands.length() >= 1 {
        let text = decode_with_font(doc, font_ref, op.operands[op.operands.length() - 1]) catch {
          _ => ""
        }
        if text != "" {
          events.push({ font_name: current_font, text })
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
          events.push({ font_name: current_font, text })
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
  out
}

///|
pub fn extract_text_from_document(doc : PdfDocument) -> String raise {
  let pages = list_page_refs(doc) catch {
    e => raise map_parse_error(e)
  }
  let mut out = ""
  for (obj, gen) in pages {
    let t = extract_text_from_page(doc, obj, gen) catch {
      e => raise e
    }
    if t != "" {
      if out != "" {
        out = out + "\n"
      }
      out = out + t
    }
  }
  out
}
