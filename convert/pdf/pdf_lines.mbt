///|
fn native_document_to_pages(native : @pdfc.PdfNativeDocumentResult) -> Array[PdfConvertPage] {
  let out : Array[PdfConvertPage] = []
  for page in native.pages {
    out.push({
      page_index: page.page_index,
      lines: events_to_lines(page.page_index, page.events),
    })
  }
  out
}

///|
fn events_to_lines(
  page_index : Int,
  events : Array[@pdfc.PdfTextEvent],
) -> Array[PdfConvertLine] {
  let lines : Array[PdfConvertLine] = []

  let mut cur = ""
  let mut start = -1
  let mut end = -1

  let mut i = 0
  while i < events.length() {
    let ev = events[i]
    let text = ev.text

    if text != "" {
      if cur == "" {
        start = i
      }
      cur = cur + text
      end = i
    }

    let has_line_break = has_explicit_line_break(ev.break_kind, text)
    let has_paragraph_break = has_explicit_paragraph_break(ev.break_kind, text)

    if has_line_break || has_paragraph_break {
      flush_line(lines, page_index, cur, start, end, has_paragraph_break)
      cur = ""
      start = -1
      end = -1
    }

    i = i + 1
  }

  flush_line(lines, page_index, cur, start, end, false)
  lines
}

///|
fn flush_line(
  lines : Array[PdfConvertLine],
  page_index : Int,
  text : String,
  start : Int,
  end : Int,
  paragraph_break : Bool,
) -> Unit {
  let t = normalize_line_text(text)

  if t == "" {
    if paragraph_break {
      lines.push({
        text: "",
        page_index,
        line_index: lines.length(),
        source_event_start: start,
        source_event_end: end,
        is_paragraph_break: true,
      })
    }
    return
  }

  lines.push({
    text: t,
    page_index,
    line_index: lines.length(),
    source_event_start: start,
    source_event_end: end,
    is_paragraph_break: paragraph_break,
  })
}

///|
fn has_explicit_line_break(kind : @pdfc.PdfTextBreakKind, text : String) -> Bool {
  kind == @pdfc.PdfTextBreakKind::ExplicitLine || text == "\n"
}

///|
fn has_explicit_paragraph_break(kind : @pdfc.PdfTextBreakKind, text : String) -> Bool {
  kind == @pdfc.PdfTextBreakKind::ExplicitParagraph || text == "\n\n"
}

///|
fn normalize_line_text(text : String) -> String {
  text
  .replace(old="\u00A0", new=" ")
  .replace(old="\t", new=" ")
  .replace(old="\n", new=" ")
  .trim()
  .to_string()
}
