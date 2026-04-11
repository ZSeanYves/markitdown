///|
async fn cmd_convert(
  input : String,
  output : String?,
  out_dir : String?,
  max_heading : Int,
  pdf_mode : String?,
  pdf_extract_debug : Bool,
  pdf_dump_selected_raw : Bool,
  pdf_pipeline_debug : Bool,
) -> Unit {
  let out_root = match out_dir {
    Some(d) => d
    None => "out"
  }

  // 确保 out_root 存在
  if !@fs.path_exists(out_root) {
    @fs.create_dir(out_root) catch {
      e => {
        exit_error(e.to_string())
        return
      }
    }
  }

  let opts : @conv.ConvertOptions = {
    out_dir: Some(out_root),
    max_heading: Some(max_heading),
    pdf_enhance_mode: pdf_mode,
    pdf_extract_debug,
    pdf_dump_selected_raw,
    pdf_pipeline_debug,
  }

  let doc_res = @conv.parse_to_ir(input, opts)
  let doc = match doc_res {
    Ok(d) => d
    Err(e) => {
      exit_error("parse failed: " + e.to_string())
      return
    }
  }

  let md = @cor.emit_markdown(doc)

  match output {
    Some(p) =>
      @fs.write_string_to_file(p, md, encoding="utf8") catch {
        e => exit_error("write output failed: " + e.to_string())
      }
    None => println(md)
  }
}

///|
fn exit_error(msg : String) -> Unit {
  println("error: " + msg)
}

///|
fn cmd_debug_pdf_events(input : String) -> Unit raise {
  if !@fs.path_exists(input) {
    exit_error("PDF file not found: " + input)
    return
  }

  let bytes = @fs.read_file_to_bytes(input) catch {
    e => {
      exit_error("read pdf failed: " + e.to_string())
      return
    }
  }

  let doc = @pdfc.open_pdf(bytes) catch {
    e => {
      exit_error("open pdf failed: " + e.to_string())
      return
    }
  }

  let pages = @pdfc.list_page_refs(doc) catch {
    e => {
      exit_error("list pages failed: " + e.to_string())
      return
    }
  }

  println("== pdf debug ==")
  println("file: " + input)
  println("pages: " + pages.length().to_string())
  println("")

  pages.eachi((i, p) => {
    let (page_obj, page_gen) = p
    println(
      @pdfc.debug_dump_pdf_page_text_ops_events_pretty(
        doc, page_obj, page_gen, i,
      ),
    )
  })
}

///|
fn cmd_check_pdf_core(input : String) -> Unit raise {
  if !@fs.path_exists(input) {
    raise @cor.AppError("PDF file not found: " + input)
  }

  let bytes = @fs.read_file_to_bytes(input) catch {
    e => raise @cor.AppError("read pdf failed: " + e.to_string())
  }

  let doc = @pdfc.open_pdf(bytes) catch {
    e => raise @cor.AppError("open pdf failed: " + e.to_string())
  }

  let native = @pdfc.extract_document_events_result(doc) catch {
    e =>
      raise @cor.AppError(
        "extract_document_events_result failed: " + e.to_string(),
      )
  }

  println("== pdf-core check ==")
  println("file: " + input)
  print_pdf_core_doc_summary(native)

  for page in native.pages {
    print_pdf_core_page_summary(page)
  }

  let failures = validate_pdf_core_native_result(native)
  if failures.length() == 0 {
    println("result: PASS")
  } else {
    println("result: FAIL")
    for msg in failures {
      println("  - " + msg)
    }
    raise @cor.AppError("pdf-core check failed: " + input)
  }
}

///|
fn cmd_check_pdf_core_set(group : String) -> Unit raise {
  let g = group.trim().to_string().to_lower()
  let samples = get_pdf_core_check_samples(g)
  if samples.length() == 0 {
    raise @cor.AppError(
      "unknown check set: " + group + " (expected smoke|decode|signal)",
    )
  }

  println("== pdf-core check set ==")
  println("group: " + g)
  println("sample_count: " + samples.length().to_string())
  println("")

  let failed : Array[String] = []
  for sample in samples {
    println("-- sample: " + sample)
    let ok = run_pdf_core_sample_check(sample)
    if ok {
      println("sample_result: PASS")
    } else {
      println("sample_result: FAIL")
      failed.push(sample)
    }
    println("")
  }

  if failed.length() == 0 {
    println("set_result: PASS")
    return
  }

  println("set_result: FAIL")
  println("failed_samples:")
  for sample in failed {
    println("  - " + sample)
  }
  raise @cor.AppError("pdf-core check set failed: " + g)
}

///|
fn run_pdf_core_sample_check(path : String) -> Bool {
  if !@fs.path_exists(path) {
    println("  [error] missing sample file")
    return false
  }

  let bytes = @fs.read_file_to_bytes(path) catch {
    e => {
      println("  [error] read failed: " + e.to_string())
      return false
    }
  }
  let doc = @pdfc.open_pdf(bytes) catch {
    e => {
      println("  [error] open failed: " + e.to_string())
      return false
    }
  }
  let native = @pdfc.extract_document_events_result(doc) catch {
    e => {
      println("  [error] extract_document_events_result failed: " + e.to_string())
      return false
    }
  }

  print_pdf_core_doc_summary(native)
  for page in native.pages {
    print_pdf_core_page_summary(page)
  }

  let failures = validate_pdf_core_native_result(native)
  if failures.length() == 0 {
    return true
  }

  for msg in failures {
    println("  [check-fail] " + msg)
  }
  false
}

///|
fn get_pdf_core_check_samples(group : String) -> Array[String] {
  match group {
    "smoke" =>
      [
        "samples/pdf/text_simple.pdf",
        "samples/pdf/text_multipage.pdf",
        "samples/pdf/hardwrap_en.pdf",
        "samples/pdf/hardwrap_zh.pdf",
        "samples/pdf/heading_basic.pdf",
      ]
    "decode" =>
      [
        "samples/pdf/text_simple.pdf",
        "samples/pdf/hardwrap_en.pdf",
        "samples/pdf/hardwrap_zh.pdf",
        "samples/pdf/pdf_heading_false_positive_phase15.pdf",
        "samples/pdf/pdf_two_column_negative_phase15.pdf",
      ]
    "signal" =>
      [
        "samples/pdf/heading_basic.pdf",
        "samples/pdf/pdf_heading_vs_short_sentence.pdf",
        "samples/pdf/pdf_cross_page_paragraph.pdf",
        "samples/pdf/pdf_repeated_header_footer_variants.pdf",
      ]
    _ => []
  }
}

///|
fn print_pdf_core_doc_summary(native : @pdfc.PdfNativeDocumentResult) -> Unit {
  println("doc:")
  println("  page_count: " + native.page_count.to_string())
  println("  success_pages: " + native.success_pages.to_string())
  println("  failed_pages: " + native.failed_pages.to_string())
  println("  success_streams: " + native.success_streams.to_string())
  println("  failed_streams: " + native.failed_streams.to_string())
  println("  event_count: " + native.event_count.to_string())
  println("  non_whitespace_chars: " + native.non_whitespace_chars.to_string())
  println("  is_empty: " + native.is_empty.to_string())
  println("  is_low_signal: " + native.is_low_signal.to_string())
  println("  is_fatal: " + native.is_fatal.to_string())
  println("  fatal_reason: " + native.fatal_reason.unwrap_or(""))
}

///|
fn print_pdf_core_page_summary(page : @pdfc.PdfNativePageResult) -> Unit {
  println("page[" + page.page_index.to_string() + "]:")
  println(
    "  page_ref: " +
    page.page_obj.to_string() +
    " " +
    page.page_gen.to_string() +
    " R",
  )
  println("  events.length: " + page.events.length().to_string())
  println("  stream_count: " + page.stream_count.to_string())
  println("  success_streams: " + page.success_streams.to_string())
  println("  failed_streams: " + page.failed_streams.to_string())
  println("  text_length: " + page.text_length.to_string())
  println("  is_failed: " + page.is_failed.to_string())
  print_pdf_core_event_samples(page.events, 8)
  println(
    "  merged_preview: \"" + preview_text(join_event_text(page.events), 180) + "\"",
  )
}

///|
fn print_pdf_core_event_samples(events : Array[@pdfc.PdfTextEvent], limit : Int) -> Unit {
  println("  events_preview:")
  let mut i = 0
  while i < events.length() && i < limit {
    let ev = events[i]
    println(
      "    [" +
      i.to_string() +
      "] text=\"" +
      preview_text(ev.text, 48) +
      "\" page=" +
      ev.page_index.to_string() +
      " font=" +
      ev.font_name.unwrap_or("<none>") +
      " size=" +
      ev.font_size.map(fn(v) { v.to_string() }).unwrap_or("<none>") +
      " stream=" +
      ev.source_stream_index.to_string() +
      " op=" +
      ev.source_op_index.to_string() +
      " break=" +
      debug_break_kind(ev.break_kind) +
      " coalesced=" +
      ev.is_coalesced.to_string() +
      " coalesced_count=" +
      ev.coalesced_count.to_string(),
    )
    i = i + 1
  }
}

///|
fn debug_break_kind(kind : @pdfc.PdfTextBreakKind) -> String {
  match kind {
    @pdfc.PdfTextBreakKind::None => "none"
    @pdfc.PdfTextBreakKind::ExplicitLine => "explicit_line"
    @pdfc.PdfTextBreakKind::ExplicitParagraph => "explicit_para"
    @pdfc.PdfTextBreakKind::Inferred => "inferred"
  }
}

///|
fn join_event_text(events : Array[@pdfc.PdfTextEvent]) -> String {
  let out : Array[String] = []
  for ev in events {
    if ev.text != "" {
      out.push(ev.text)
    }
  }
  out.join("")
}

///|
fn preview_text(s : String, limit : Int) -> String {
  let t = s
    .replace(old="\n", new="\\n")
    .replace(old="\r", new="\\r")
    .replace(old="\t", new="\\t")
  if t.to_array().length() <= limit {
    t
  } else {
    t[:limit].to_string() + "..."
  }
}

///|
fn validate_pdf_core_native_result(
  native : @pdfc.PdfNativeDocumentResult,
) -> Array[String] {
  let failures : Array[String] = []

  if native.is_fatal {
    failures.push("is_fatal must be false")
  }
  if native.is_empty {
    failures.push("is_empty must be false")
  }
  if native.event_count <= 0 {
    failures.push("event_count must be > 0")
  }
  if native.non_whitespace_chars <= 0 {
    failures.push("non_whitespace_chars must be > 0")
  }
  if native.page_count < 1 {
    failures.push("page_count must be >= 1")
  }
  if native.success_pages + native.failed_pages != native.page_count {
    failures.push("success_pages + failed_pages must equal page_count")
  }
  if native.success_streams + native.failed_streams < native.success_pages {
    failures.push("success_streams + failed_streams must be >= success_pages")
  }

  for page in native.pages {
    if page.events.length() == 0 && page.text_length > 0 {
      failures.push(
        "page[" +
        page.page_index.to_string() +
        "] has text_length > 0 but events.length == 0",
      )
    }
  }

  failures
}
