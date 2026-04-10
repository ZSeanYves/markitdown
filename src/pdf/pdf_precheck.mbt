///|
fn precheck_pdf_native_candidate(path : String) -> PdfPrecheckDecision {
  let bytes = @fs.read_file_to_bytes(path) catch {
    _ =>
      return {
        accepted: false,
        reason_code: PdfDecisionReasonCode::UNSURE_PRECHECK_ERROR,
      }
  }

  if contains_ascii(bytes, "/Encrypt") {
    return {
      accepted: false,
      reason_code: PdfDecisionReasonCode::REJECT_ENCRYPTED,
    }
  }
  if contains_ascii(bytes, "/Type/XRef") || contains_ascii(bytes, "/Type /XRef") {
    return {
      accepted: false,
      reason_code: PdfDecisionReasonCode::REJECT_XREF_STREAM,
    }
  }
  if contains_ascii(bytes, "/Type/ObjStm") ||
    contains_ascii(bytes, "/Type /ObjStm") {
    return {
      accepted: false,
      reason_code: PdfDecisionReasonCode::REJECT_OBJECT_STREAM,
    }
  }

  let doc = @pdfc.open_pdf(bytes) catch {
    _ =>
      return {
        accepted: false,
        reason_code: PdfDecisionReasonCode::UNSURE_PRECHECK_ERROR,
      }
  }

  let pages = @pdfc.list_page_refs(doc) catch {
    _ =>
      return {
        accepted: false,
        reason_code: PdfDecisionReasonCode::UNSURE_PRECHECK_ERROR,
      }
  }

  for e in pages {
    let (page_obj, page_gen) = e

    let streams = @pdfc.get_page_content_stream_bytes(doc, page_obj, page_gen) catch {
      e => return classify_precheck_failure(e)
    }
    if streams.length() == 0 {
      return {
        accepted: false,
        reason_code: PdfDecisionReasonCode::REJECT_MISSING_CONTENTS,
      }
    }

    let fonts = @pdfc.resolve_page_fonts(doc, page_obj, page_gen) catch {
      e => return classify_precheck_failure(e)
    }
    if fonts.length() == 0 {
      return {
        accepted: false,
        reason_code: PdfDecisionReasonCode::REJECT_UNSUPPORTED_FONT_DECODE_PATH,
      }
    }

    let _ = @pdfc.extract_text_events_from_page(doc, page_obj, page_gen) catch {
      e => return classify_precheck_failure(e)
    }
  }

  {
    accepted: true,
    reason_code: PdfDecisionReasonCode::ACCEPT_NATIVE_PRECHECK_PASS,
  }
}

///|
fn classify_precheck_failure(e : Error) -> PdfPrecheckDecision {
  match e {
    @pdfc.PdfNativeError::UnsupportedFeature(_) =>
      {
        accepted: false,
        reason_code: PdfDecisionReasonCode::REJECT_UNSUPPORTED_FONT_DECODE_PATH,
      }
    @pdfc.PdfParseError::UnsupportedFeature(msg) =>
      if msg.contains("xref stream") {
        {
          accepted: false,
          reason_code: PdfDecisionReasonCode::REJECT_XREF_STREAM,
        }
      } else if msg.contains("ObjStm") || msg.contains("object stream") {
        {
          accepted: false,
          reason_code: PdfDecisionReasonCode::REJECT_OBJECT_STREAM,
        }
      } else {
        {
          accepted: false,
          reason_code: PdfDecisionReasonCode::REJECT_UNSUPPORTED_FONT_DECODE_PATH,
        }
      }
    @pdfc.PdfParseError::TypeMismatch(_) =>
      {
        accepted: false,
        reason_code: PdfDecisionReasonCode::REJECT_MISSING_KEY_RESOURCES,
      }
    @pdfc.PdfParseError::ObjectNotFound(_, _) =>
      {
        accepted: false,
        reason_code: PdfDecisionReasonCode::REJECT_MISSING_KEY_RESOURCES,
      }
    _ =>
      {
        accepted: false,
        reason_code: PdfDecisionReasonCode::UNSURE_PRECHECK_ERROR,
      }
  }
}

///|
fn contains_ascii(bs : Bytes, pat : String) -> Bool {
  let needle = @utf8.encode(pat)
  let n = needle.length()
  if n == 0 {
    return true
  }
  if bs.length() < n {
    return false
  }

  let mut i = 0
  while i <= bs.length() - n {
    let mut j = 0
    let mut ok = true
    while j < n {
      if bs[i + j] != needle[j] {
        ok = false
        break
      }
      j = j + 1
    }
    if ok {
      return true
    }
    i = i + 1
  }
  false
}
