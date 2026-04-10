///|
priv struct PdfExtractResult {
  backend_name : String
  text : String
  exit_status : Int
  stderr : String
  quality : PdfTextQuality
  quality_accepted : Bool
}

///|
priv enum PdfDecisionReasonCode {
  ACCEPT_POLICY_EXTERNAL
  ACCEPT_NATIVE_PRECHECK_PASS
  REJECT_ENCRYPTED
  REJECT_XREF_STREAM
  REJECT_OBJECT_STREAM
  REJECT_MISSING_CONTENTS
  REJECT_UNSUPPORTED_FONT_DECODE_PATH
  REJECT_MISSING_KEY_RESOURCES
  UNSURE_PRECHECK_ERROR
  UNSURE_POLICY_UNKNOWN
}

///|
priv struct PdfPrecheckDecision {
  accepted : Bool
  reason_code : PdfDecisionReasonCode
}

///|
async fn extract_pdf_text(path : String) -> Result[String, @cor.AppError] {
  match
    extract_pdf_text_result(path, backend=None, backend_policy=None, debug=false) {
    Ok(picked) => Ok(picked.text)
    Err(e) => Err(e)
  }
}

///|
async fn extract_pdf_text_result(
  path : String,
  backend? : String? = None,
  backend_policy? : String? = None,
  debug? : Bool = false,
) -> Result[PdfExtractResult, @cor.AppError] {
  let backend_mode = match backend {
    Some(s) => s.trim().to_string()
    None => ""
  }

  let policy_mode = match backend_policy {
    Some(s) => s.trim().to_string()
    None => ""
  }
  if policy_mode != "" {
    return select_pdf_backend_by_policy(path, policy_mode, debug~)
  }

  if backend_mode == "pdf-native" || backend_mode == "native" {
    return select_pdf_backend_by_policy(path, "native-strict", debug~)
  }

  if backend_mode == "external" || backend_mode == "" {
    return select_pdf_backend_by_policy(path, "external", debug~)
  }

  Err(@cor.AppError("unknown pdf backend: " + backend_mode))
}

///|
async fn extract_pdf_text_external(
  path : String,
  debug? : Bool = false,
) -> Result[PdfExtractResult, @cor.AppError] {
  let all_results = collect_pdf_backend_results(path)
  let decision = select_pdf_backend_result(all_results, debug~)

  match decision.selected {
    Some(sel) => {
      let quality = sel.quality.unwrap_or(analyze_pdf_text_quality(sel.text))
      Ok({
        backend_name: sel.backend_name,
        text: cleanup_pdf_text(sel.text),
        exit_status: sel.exit_status,
        stderr: sel.stderr,
        quality,
        quality_accepted: decision.accepted,
      })
    }
    None =>
      Err(
        @cor.AppError(
          "No PDF text extractor available. Please install `pdftotext` (poppler) or `mutool` (mupdf).",
        ),
      )
  }
}

///|
fn reason_code_to_string(code : PdfDecisionReasonCode) -> String {
  match code {
    PdfDecisionReasonCode::ACCEPT_POLICY_EXTERNAL => "ACCEPT_POLICY_EXTERNAL"
    PdfDecisionReasonCode::ACCEPT_NATIVE_PRECHECK_PASS =>
      "ACCEPT_NATIVE_PRECHECK_PASS"
    PdfDecisionReasonCode::REJECT_ENCRYPTED => "REJECT_ENCRYPTED"
    PdfDecisionReasonCode::REJECT_XREF_STREAM => "REJECT_XREF_STREAM"
    PdfDecisionReasonCode::REJECT_OBJECT_STREAM => "REJECT_OBJECT_STREAM"
    PdfDecisionReasonCode::REJECT_MISSING_CONTENTS => "REJECT_MISSING_CONTENTS"
    PdfDecisionReasonCode::REJECT_UNSUPPORTED_FONT_DECODE_PATH =>
      "REJECT_UNSUPPORTED_FONT_DECODE_PATH"
    PdfDecisionReasonCode::REJECT_MISSING_KEY_RESOURCES =>
      "REJECT_MISSING_KEY_RESOURCES"
    PdfDecisionReasonCode::UNSURE_PRECHECK_ERROR => "UNSURE_PRECHECK_ERROR"
    PdfDecisionReasonCode::UNSURE_POLICY_UNKNOWN => "UNSURE_POLICY_UNKNOWN"
  }
}

///|
fn debug_print_policy_decision(
  policy : String,
  selected_backend : String,
  reason : PdfDecisionReasonCode,
  debug? : Bool = false,
) -> Unit {
  if !debug {
    return
  }
  println(
    "[pdf-debug] policy=" +
    policy +
    " selected=" +
    selected_backend +
    " reason=" +
    reason_code_to_string(reason),
  )
}

///|
async fn select_pdf_backend_by_policy(
  path : String,
  policy_mode : String,
  debug? : Bool = false,
) -> Result[PdfExtractResult, @cor.AppError] {
  if policy_mode == "external" {
    let res = extract_pdf_text_external(path, debug~)
    debug_print_policy_decision(
      "external",
      "external",
      PdfDecisionReasonCode::ACCEPT_POLICY_EXTERNAL,
      debug~,
    )
    return res
  }

  if policy_mode == "native-strict" {
    let precheck = precheck_pdf_native_candidate(path)
    if !precheck.accepted {
      debug_print_policy_decision(
        "native-strict",
        "pdf-native",
        precheck.reason_code,
        debug~,
      )
      return Err(
        @cor.AppError(
          "pdf-native precheck blocked: " + reason_code_to_string(precheck.reason_code),
        ),
      )
    }
    debug_print_policy_decision(
      "native-strict",
      "pdf-native",
      precheck.reason_code,
      debug~,
    )
    return extract_pdf_text_native(path, debug=false)
  }

  if policy_mode == "native-gated" {
    let precheck = precheck_pdf_native_candidate(path)
    if precheck.accepted {
      debug_print_policy_decision(
        "native-gated",
        "pdf-native",
        precheck.reason_code,
        debug~,
      )
      return extract_pdf_text_native(path, debug=false)
    }
    debug_print_policy_decision(
      "native-gated",
      "external",
      precheck.reason_code,
      debug~,
    )
    return extract_pdf_text_external(path, debug=false)
  }

  debug_print_policy_decision(
    policy_mode,
    "external",
    PdfDecisionReasonCode::UNSURE_POLICY_UNKNOWN,
    debug~,
  )
  Err(@cor.AppError("unknown pdf backend policy: " + policy_mode))
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

  let text = @pdfc.extract_text_from_document(doc) catch {
    e => return Err(map_native_error(e))
  }

  let cleaned = cleanup_pdf_text(text)
  let quality = analyze_pdf_text_quality(cleaned)
  if debug {
    println("[pdf-debug] selected backend=pdf-native (forced)")
  }

  Ok({
    backend_name: "pdf-native",
    text: cleaned,
    exit_status: 0,
    stderr: "",
    quality,
    quality_accepted: true,
  })
}
