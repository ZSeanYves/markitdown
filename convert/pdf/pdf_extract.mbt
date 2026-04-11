///|
priv struct PdfExtractResult {
  _backend_name : String
  text : String
  _exit_status : Int
  _stderr : String
  _quality : PdfTextQuality
  quality_accepted : Bool
  _native_stats : @pdfc.PdfNativeDocumentResult?
}

///|
fn extract_pdf_text_result(
  path : String,
  debug? : Bool = false,
) -> Result[PdfExtractResult, @cor.AppError] {
  extract_pdf_text_native(path, debug~)
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
fn extract_pdf_text_native(
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
  let text = flatten_native_document_events_to_text(native)

  let cleaned = cleanup_pdf_text(text)
  let quality = analyze_pdf_text_quality(cleaned)
  if debug {
    println("[pdf-debug] selected backend=pdf-native")
    println(
      "[pdf-debug] native_stats pages=" +
      native.page_count.to_string() +
      " success_pages=" +
      native.success_pages.to_string() +
      " failed_pages=" +
      native.failed_pages.to_string() +
      " success_streams=" +
      native.success_streams.to_string() +
      " failed_streams=" +
      native.failed_streams.to_string() +
      " events=" +
      native.event_count.to_string() +
      " non_ws_chars=" +
      native.non_whitespace_chars.to_string() +
      " empty=" +
      native.is_empty.to_string() +
      " low_signal=" +
      native.is_low_signal.to_string() +
      " fatal=" +
      native.is_fatal.to_string(),
    )
    for p in native.pages {
      println(
        "[pdf-debug] page[" +
        p.page_index.to_string() +
        "] streams=" +
        p.stream_count.to_string() +
        " ok=" +
        p.success_streams.to_string() +
        " fail=" +
        p.failed_streams.to_string() +
        " events=" +
        p.events.length().to_string() +
        " text_len=" +
        p.text_length.to_string() +
        " failed=" +
        p.is_failed.to_string(),
      )
    }
  }

  if native.is_fatal {
    return Err(
      @cor.AppError(
        "pdf-native fatal extraction: " +
        native.fatal_reason.unwrap_or("unknown_reason"),
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
        native.event_count.to_string() +
        " non_ws_chars=" +
        native.non_whitespace_chars.to_string(),
      ),
    )
  }

  Ok({
    _backend_name: "pdf-native",
    text: cleaned,
    _exit_status: 0,
    _stderr: "",
    _quality: quality,
    quality_accepted: !is_quality_failure_for_normal_text(quality),
    _native_stats: Some(native),
  })
}

///|
fn flatten_native_document_events_to_text(
  native : @pdfc.PdfNativeDocumentResult,
) -> String {
  let pages : Array[String] = []
  for page in native.pages {
    let mut page_text = ""
    for ev in page.events {
      if ev.text != "" {
        page_text = page_text + ev.text
      }
    }
    if page_text != "" {
      pages.push(page_text)
    }
  }
  pages.join("\f")
}
