///|
fn extract_pdf_native_document(
  path : String,
  debug? : Bool = false,
) -> Result[@pdfc.PdfNativeDocumentResult, @cor.AppError] {
  let bytes = @fs.read_file_to_bytes(path) catch {
    e => return Err(@cor.AppError("read pdf failed: " + e.to_string()))
  }

  let doc = @pdfc.open_pdf(bytes) catch { e => return Err(map_native_error(e)) }

  let native = @pdfc.extract_document_events_result(doc) catch {
    e => return Err(map_native_error(e))
  }

  if debug {
    println(
      "[pdf-debug] pages=" +
      native.page_count.to_string() +
      " success_pages=" +
      native.success_pages.to_string() +
      " failed_pages=" +
      native.failed_pages.to_string() +
      " events=" +
      native.event_count.to_string() +
      " non_ws_chars=" +
      native.non_whitespace_chars.to_string() +
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

  Ok(native)
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
