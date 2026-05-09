///|
/// Extract text from PDFs using content stream operators.

///|
pub fn PdfText::extract_text(
  self : PdfText,
  page_break? : String = "\n\n",
) -> String raise {
  self.extract_text_by_page().join(page_break)
}

///|
fn PdfText::extract_text_by_page(self : PdfText) -> Array[String] raise {
  let pages = @pdfpage.PdfPageDoc::new(self.pdf).pages_of_pagetree()
  pages.map(page => self.extract_text_from_page(page))
}

///|
fn PdfText::extract_text_from_page(
  self : PdfText,
  page : @pdfpage.Page,
) -> String raise {
  let builder = StringBuilder::new()
  let visited : Map[Int, Bool] = Map::new()
  self.append_text_from_streams(builder, page.resources, page.content, visited)
  builder.to_string()
}

///|
fn PdfText::append_text_from_streams(
  self : PdfText,
  builder : StringBuilder,
  resources : @pdf.PdfObject,
  streams : Array[@pdf.PdfObject],
  visited : Map[Int, Bool],
) -> Unit raise {
  let ops = @pdfops.Op::parse_operators(self.pdf, resources, streams)
  let mut in_text = false
  let mut current_extractor : TextExtractor? = None
  let mut last_newline = false
  let extractor_cache : Map[String, TextExtractor] = Map::new()
  fn append_newline() -> Unit {
    if !builder.is_empty() && !last_newline {
      builder.write_char('\n')
      last_newline = true
    }
  }

  fn append_text_piece(value : String) -> Unit {
    if value.length() == 0 {
      return
    }
    builder.write_string(value)
    last_newline = false
  }

  fn decode_pdfdoc(value : String) -> String {
    PdfTextUtil::new().utf8_of_pdfdocstring(value) catch {
      _ => value
    }
  }

  fn decode_text(value : String) -> String {
    if PdfTextUtil::new().is_unicode(value) {
      return PdfTextUtil::new().utf8_of_pdfdocstring(value) catch { _ => value }
    }
    if current_extractor is Some(extractor) {
      PdfTextUtil::new().utf8_of_codepoints(extractor.codepoints_of_text(value)) catch {
        _ => decode_pdfdoc(value)
      }
    } else {
      decode_pdfdoc(value)
    }
  }

  fn append_text_value(value : String) -> Unit {
    append_text_piece(decode_text(value))
  }

  fn append_text_array(obj : @pdf.PdfObject) -> Unit {
    match obj {
      Array(values) =>
        for value in values {
          if value is String(text) {
            append_text_value(text)
          }
        }
      String(text) => append_text_value(text)
      _ => ()
    }
  }

  fn maybe_update_font(name : String) -> Unit {
    current_extractor = self.lookup_text_extractor(
      resources, name, extractor_cache,
    )
  }

  fn mark_visited(obj_num : Int?) -> Bool {
    match obj_num {
      Some(i) =>
        match visited.get(i) {
          Some(true) => false
          _ => {
            visited.set(i, true)
            true
          }
        }
      None => true
    }
  }

  fn append_text_from_xobject(name : String) -> Unit raise {
    match self.pdf.lookup_direct("/XObject", resources) {
      Some(Dictionary(entries)) =>
        if entries.search_by(pair => pair.0 == name) is Some(idx) {
          let obj_ref = entries[idx].1
          let obj_num : Int? = if obj_ref is Indirect(i) {
            Some(i)
          } else {
            None
          }
          if mark_visited(obj_num) {
            let xobj = self.pdf.direct(obj_ref)
            if self.pdf.lookup_direct("/Subtype", xobj) is Some(Name(n)) &&
              n.equal_string_bytes("/Form") {
              let xresources = self.pdf
                .lookup_direct("/Resources", xobj)
                .unwrap_or(resources)
              self.append_text_from_streams(
                builder,
                xresources,
                [xobj],
                visited,
              )
            }
          }
        }
      _ => ()
    }
  }

  for op in ops {
    match (op : @pdfops.Op) {
      OpBT => {
        in_text = true
        current_extractor = None
      }
      OpET => {
        in_text = false
        current_extractor = None
      }
      OpTf(name, _) => if in_text { maybe_update_font(name) }
      OpTj(text) => if in_text { append_text_value(text) }
      OpTJ(obj) => if in_text { append_text_array(obj) }
      OpSingleQuote(text) =>
        if in_text {
          append_newline()
          append_text_value(text)
        }
      OpDoubleQuote(_, _, text) =>
        if in_text {
          append_newline()
          append_text_value(text)
        }
      OpTStar => if in_text { append_newline() }
      OpTd(_, ty) => if in_text && ty != 0.0 { append_newline() }
      OpTD(_, ty) => if in_text && ty != 0.0 { append_newline() }
      OpDo(name) => append_text_from_xobject(name)
      _ => ()
    }
  }
}

///|
fn PdfText::lookup_text_extractor(
  self : PdfText,
  resources : @pdf.PdfObject,
  font_name : String,
  cache : Map[String, TextExtractor],
) -> TextExtractor? {
  if cache.get(font_name) is Some(extractor) {
    return Some(extractor)
  }
  match self.pdf.lookup_direct("/Font", resources) {
    Some(fonts) =>
      match self.pdf.lookup_direct(font_name, fonts) {
        Some(obj) =>
          try {
            let extractor = self.text_extractor_of_font(obj)
            cache.set(font_name, extractor)
            Some(extractor)
          } catch {
            _ => None
          }
        None => None
      }
    None => None
  }
}
