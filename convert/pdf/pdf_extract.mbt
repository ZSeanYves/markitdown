///|
fn extract_pdf_text_result(
  path : String,
  debug? : Bool = false,
) -> Result[PdfExtractResult, @cor.AppError] {
  let bytes = @fs.read_file_to_bytes(path) catch {
    e => return Err(@cor.AppError("read pdf failed: " + e.to_string()))
  }

  let doc = @pdfc.open_pdf(bytes) catch { e => return Err(map_native_error(e)) }

  let native = @pdfc.extract_document_events_result(doc) catch {
    e => return Err(map_native_error(e))
  }

  if debug {
    println("[pdf-debug] selected backend=pdf-native")
    println(
      "[pdf-debug] native_stats pages=" +
      native.page_count.to_string() +
      " success_pages=" +
      native.success_pages.to_string() +
      " failed_pages=" +
      native.failed_pages.to_string() +
      " events=" +
      native.event_count.to_string() +
      " non_ws_chars=" +
      native.non_whitespace_chars.to_string() +
      " empty=" +
      native.is_empty.to_string() +
      " low_signal=" +
      native.is_low_signal.to_string(),
    )
  }

  if native.is_fatal {
    return Err(
      @cor.AppError(
        "pdf-native fatal extraction: " + native.fatal_reason.unwrap_or("unknown_reason"),
      ),
    )
  }

  if native.is_low_signal {
    return Err(
      @cor.AppError(
        "pdf-native low-signal extraction: pages=" +
        native.page_count.to_string() +
        " failed_pages=" +
        native.failed_pages.to_string() +
        " events=" +
        native.event_count.to_string(),
      ),
    )
  }

  let fallback_text = native_document_to_debug_text(native)
  Ok({
    _backend_name: "pdf-native",
    text: fallback_text,
    quality_accepted: !native.is_empty && !native.is_low_signal,
    _native_stats: Some(native),
  })
}

///|
fn native_document_to_debug_text(native : @pdfc.PdfNativeDocumentResult) -> String {
  let pages = native_document_events_to_convert_pages(native)
  let out : Array[String] = []

  for page in pages {
    let lines : Array[String] = []
    for line in page.lines {
      let t = line.text.trim().to_string()
      if t != "" {
        lines.push(t)
      }
    }

    if lines.length() > 0 {
      out.push(lines.join("\n"))
    }
  }

  out.join("\n\n")
}

///|
fn map_native_error(e : Error) -> @cor.AppError {
  match e {
    @pdfc.PdfNativeError::UnsupportedFeature(msg) =>
      @cor.AppError("pdf-native unsupported: " + msg)
    @pdfc.ExtractionFailed(msg) =>
      @cor.AppError("pdf-native unexpected_crash: " + msg)
    @pdfc.PdfParseError::InvalidHeader(msg) =>
      @cor.AppError("pdf-native parser_error: invalid header: " + msg)
    @pdfc.PdfParseError::InvalidStructure(msg) =>
      @cor.AppError("pdf-native parser_error: invalid structure: " + msg)
    @pdfc.PdfParseError::UnexpectedEOF(msg) =>
      @cor.AppError("pdf-native parser_error: unexpected eof: " + msg)
    @pdfc.PdfParseError::ObjectNotFound(obj, gen) =>
      @cor.AppError(
        "pdf-native parser_error: object not found: " +
        obj.to_string() +
        " " +
        gen.to_string() +
        " R",
      )
    @pdfc.PdfParseError::TypeMismatch(msg) =>
      @cor.AppError("pdf-native parser_error: type mismatch: " + msg)
    @pdfc.PdfParseError::UnsupportedFeature(msg) =>
      @cor.AppError("pdf-native unsupported: " + msg)
    _ => @cor.AppError("pdf-native error: " + e.to_string())
  }
}

///|
fn debug_line_preview(s : String) -> String {
  let t = s.replace(old="\n", new="\\n").replace(old="\r", new="\\r")
  if t.to_array().length() <= 80 {
    t
  } else {
    t[:80].to_string() + "..."
  }
}
