///|
fn native_document_to_pages(
  native : @pdfc.PdfNativeDocumentResult,
) -> Array[PdfConvertPage] {
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
/// 这一版先走最保守策略：
/// - 不跨 event 聚合
/// - 每个非空 event 先作为一条 line
/// - 只把 explicit paragraph break 映射成 paragraph_break
///
/// 目的：
/// 先把“结构边界”重新放出来，避免再次整页 blob。
fn events_to_lines(
  page_index : Int,
  events : Array[@pdfc.PdfTextEvent],
) -> Array[PdfConvertLine] {
  let lines : Array[PdfConvertLine] = []

  let mut i = 0
  while i < events.length() {
    let ev = events[i]
    let text = normalize_line_text(ev.text)

    if text != "" {
      lines.push({
        text,
        page_index,
        line_index: lines.length(),
        source_event_start: i,
        source_event_end: i,
        is_paragraph_break: false,
      })
    }

    if has_explicit_paragraph_break(ev.break_kind, ev.text) {
      lines.push({
        text: "",
        page_index,
        line_index: lines.length(),
        source_event_start: i,
        source_event_end: i,
        is_paragraph_break: true,
      })
    }

    i = i + 1
  }

  lines
}

///|
fn has_explicit_line_break(
  kind : @pdfc.PdfTextBreakKind,
  text : String,
) -> Bool {
  kind == @pdfc.PdfTextBreakKind::ExplicitLine || text == "\n"
}

///|
fn has_explicit_paragraph_break(
  kind : @pdfc.PdfTextBreakKind,
  text : String,
) -> Bool {
  kind == @pdfc.PdfTextBreakKind::ExplicitParagraph || text == "\n\n"
}

///|
fn normalize_line_text(text : String) -> String {
  normalize_pdf_text_fragment(text)
}