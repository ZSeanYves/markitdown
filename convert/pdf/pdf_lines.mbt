///|
fn native_document_events_to_convert_pages(
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
