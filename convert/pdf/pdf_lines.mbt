///|
fn native_document_events_to_convert_pages(
  native : @pdfc.PdfNativeDocumentResult,
) -> Array[PdfConvertPage] {
  let out : Array[PdfConvertPage] = []
  for page in native.pages {
    out.push({
      page_index: page.page_index,
      lines: native_page_events_to_lines(page.page_index, page.events),
    })
  }
  out
}

///|
fn native_page_events_to_lines(
  page_index : Int,
  events : Array[@pdfc.PdfTextEvent],
) -> Array[PdfConvertLine] {
  let lines : Array[PdfConvertLine] = []
  let mut cur_text = ""
  let mut cur_start = -1
  let mut cur_end = -1

  let mut i = 0
  while i < events.length() {
    let ev = events[i]
    let t = ev.text

    if t == "" {
      i = i + 1
      continue
    }

    if t == "\n" || t == "\n\n" {
      if cur_text != "" {
        lines.push({
          text: cur_text,
          page_index,
          line_index: lines.length(),
          source_event_start: cur_start,
          source_event_end: cur_end,
          is_explicit_break: false,
        })
        cur_text = ""
        cur_start = -1
        cur_end = -1
      }

      if t == "\n\n" {
        lines.push({
          text: "",
          page_index,
          line_index: lines.length(),
          source_event_start: i,
          source_event_end: i,
          is_explicit_break: true,
        })
      }
      i = i + 1
      continue
    }

    if cur_text == "" {
      cur_start = i
    }
    cur_text = cur_text + t
    cur_end = i
    i = i + 1
  }

  if cur_text != "" {
    lines.push({
      text: cur_text,
      page_index,
      line_index: lines.length(),
      source_event_start: cur_start,
      source_event_end: cur_end,
      is_explicit_break: false,
    })
  }

  lines
}
