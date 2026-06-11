///|
priv struct PdfV2TextSanitizeResult {
  text : String
  dropped_count : Int
  reason_tags : Array[String]
  warnings : Array[PdfV2Warning]
}

///|
fn pdf_v2_sanitize_tags(
  first : Array[String],
  second : Array[String],
) -> Array[String] {
  let out : Array[String] = []
  out.append(first)
  for tag in second {
    if !out.contains(tag) {
      out.push(tag)
    }
  }
  out
}

///|
fn pdf_v2_sanitize_add_tag(tags : Array[String], tag : String) -> Array[String] {
  if tags.contains(tag) {
    tags
  } else {
    pdf_v2_sanitize_tags(tags, [tag])
  }
}

///|
fn pdf_v2_control_warning(
  source_ref : PdfV2SourceRef,
  reason_tags : Array[String],
) -> PdfV2Warning {
  pdf_v2_warning(
    PdfV2WarningKind::DecodeIssue,
    PdfV2Severity::Warning,
    "PDF v2 decoded text contained non-product control bytes; unsafe text was suppressed",
    [source_ref],
    reason_tags,
  )
}

///|
fn pdf_v2_char_is_allowed_whitespace(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}

///|
fn pdf_v2_char_is_control(ch : Char) -> Bool {
  let code = ch.to_int()
  (code >= 0 && code < 0x20) || (code >= 0x7f && code < 0xa0)
}

///|
fn pdf_v2_normalize_whitespace_char(ch : Char) -> Char {
  if ch == '\t' || ch == '\n' || ch == '\r' {
    ' '
  } else {
    ch
  }
}

///|
fn pdf_v2_sanitize_decoded_text_for_candidate(
  text : String,
  source_ref : PdfV2SourceRef,
) -> PdfV2TextSanitizeResult {
  let out : Array[Char] = []
  let mut dropped = 0
  let mut tags : Array[String] = []
  for ch in text {
    if ch == '\u{FFFD}' {
      dropped = dropped + 1
      tags = pdf_v2_sanitize_add_tag(tags, "invalid_unicode_suppressed")
    } else if ch == '\u{0000}' {
      dropped = dropped + 1
      tags = pdf_v2_sanitize_add_tag(tags, "nul_byte_dropped")
      tags = pdf_v2_sanitize_add_tag(tags, "control_byte_dropped")
    } else if pdf_v2_char_is_control(ch) {
      if pdf_v2_char_is_allowed_whitespace(ch) {
        let normalized = pdf_v2_normalize_whitespace_char(ch)
        if normalized != ch {
          tags = pdf_v2_sanitize_add_tag(tags, "text_whitespace_normalized")
        }
        out.push(normalized)
      } else {
        dropped = dropped + 1
        tags = pdf_v2_sanitize_add_tag(tags, "control_byte_dropped")
      }
    } else {
      out.push(ch)
    }
  }
  let warnings = if tags.length() > 0 {
    [pdf_v2_control_warning(source_ref, tags)]
  } else {
    []
  }
  {
    text: String::from_array(out),
    dropped_count: dropped,
    reason_tags: tags,
    warnings,
  }
}

///|
fn pdf_v2_sanitize_candidate_char_text(
  text : String?,
  source_ref : PdfV2SourceRef,
) -> (String?, Array[String], Array[PdfV2Warning]) {
  match text {
    Some(value) => {
      let sanitized = pdf_v2_sanitize_decoded_text_for_candidate(
        value, source_ref,
      )
      if sanitized.text.length() == 0 {
        (None, sanitized.reason_tags, sanitized.warnings)
      } else {
        (Some(sanitized.text), sanitized.reason_tags, sanitized.warnings)
      }
    }
    None => (None, [], [])
  }
}

///|
fn pdf_v2_bytes_view_from_pdf_string(raw : String) -> BytesView {
  Bytes::from_array(@pdfio.bytes_of_string(raw)[:])[:]
}

///|
fn pdf_v2_sanitize_decode_known_encoding(
  raw : String,
  encoding_kind : @encoding.Encoding,
) -> String? {
  (@encoding.decode(
    pdf_v2_bytes_view_from_pdf_string(raw),
    encoding=encoding_kind,
  )
  |> Some) catch {
    _ => None
  }
}

///|
fn pdf_v2_decode_pdf_string_with_bom(
  raw : String,
  source_ref : PdfV2SourceRef,
) -> (String?, Array[String], Array[PdfV2Warning]) {
  let bytes = @pdfio.int_array_of_string(raw)
  if bytes.length() >= 2 && bytes[0] == 0xfe && bytes[1] == 0xff {
    let body = @pdfio.string_of_int_array(bytes[2:].to_owned())
    match
      pdf_v2_sanitize_decode_known_encoding(body, @encoding.Encoding::UTF16BE) {
      Some(decoded) => {
        let sanitized = pdf_v2_sanitize_decoded_text_for_candidate(
          decoded, source_ref,
        )
        (
          Some(sanitized.text),
          pdf_v2_sanitize_tags(["utf16be_bom"], sanitized.reason_tags),
          sanitized.warnings,
        )
      }
      None =>
        (
          None,
          ["utf16be_bom", "invalid_utf16_suppressed"],
          [
            pdf_v2_control_warning(source_ref, [
              "utf16be_bom", "invalid_utf16_suppressed",
            ]),
          ],
        )
    }
  } else if bytes.length() >= 2 && bytes[0] == 0xff && bytes[1] == 0xfe {
    let body = @pdfio.string_of_int_array(bytes[2:].to_owned())
    match
      pdf_v2_sanitize_decode_known_encoding(body, @encoding.Encoding::UTF16LE) {
      Some(decoded) => {
        let sanitized = pdf_v2_sanitize_decoded_text_for_candidate(
          decoded, source_ref,
        )
        (
          Some(sanitized.text),
          pdf_v2_sanitize_tags(["utf16le_bom"], sanitized.reason_tags),
          sanitized.warnings,
        )
      }
      None =>
        (
          None,
          ["utf16le_bom", "invalid_utf16_suppressed"],
          [
            pdf_v2_control_warning(source_ref, [
              "utf16le_bom", "invalid_utf16_suppressed",
            ]),
          ],
        )
    }
  } else {
    (None, [], [])
  }
}

///|
fn pdf_v2_pdfdoc_string_has_binary_controls(raw : String) -> Bool {
  let bytes = @pdfio.int_array_of_string(raw)
  for byte in bytes {
    if byte == 0 || byte < 0x09 || (byte > 0x0d && byte < 0x20) || byte == 0x7f {
      return true
    }
  }
  false
}

///|
fn pdf_v2_decode_pdfdoc_string_text(
  raw : String,
  source_ref : PdfV2SourceRef,
) -> (String?, Array[String], Array[PdfV2Warning]) {
  match pdf_v2_decode_pdf_string_with_bom(raw, source_ref) {
    (Some(text), tags, warnings) =>
      return (
        Some(text),
        pdf_v2_sanitize_tags(["pdfdoc_string"], tags),
        warnings,
      )
    (None, tags, warnings) if tags.length() > 0 =>
      return (None, pdf_v2_sanitize_tags(["pdfdoc_string"], tags), warnings)
    _ => ()
  }
  if pdf_v2_pdfdoc_string_has_binary_controls(raw) {
    return (
      None,
      ["pdfdoc_string", "raw_bytes_suppressed", "control_byte_dropped"],
      [
        pdf_v2_control_warning(source_ref, [
          "pdfdoc_string", "raw_bytes_suppressed", "control_byte_dropped",
        ]),
      ],
    )
  }
  let decoded = @pdftext.PdfTextUtil::new().utf8_of_pdfdocstring(raw) catch {
    _ =>
      return (
        None,
        ["pdfdoc_string", "pdfdoc_string_decode_failed"],
        [
          pdf_v2_control_warning(source_ref, [
            "pdfdoc_string", "pdfdoc_string_decode_failed",
          ]),
        ],
      )
  }
  let sanitized = pdf_v2_sanitize_decoded_text_for_candidate(
    decoded, source_ref,
  )
  if sanitized.text.length() == 0 {
    (
      None,
      pdf_v2_sanitize_tags(["pdfdoc_string"], sanitized.reason_tags),
      sanitized.warnings,
    )
  } else {
    (
      Some(sanitized.text),
      pdf_v2_sanitize_tags(["pdfdoc_string"], sanitized.reason_tags),
      sanitized.warnings,
    )
  }
}
