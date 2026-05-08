///|
test "pdf error classifier maps detail kinds" {
  let encrypted = classify_pdf_error(
    PdfError::AdapterFailed("open failed: encrypted document"),
  )
  match encrypted.kind {
    PdfErrorKind::Encrypted => ()
    _ => fail("expected encrypted classifier kind")
  }
  assert_eq(encrypted.message, "AdapterFailed: open failed: encrypted document")

  let partial = classify_pdf_error(
    PdfError::BuildFailed("raw pages length != block pages length"),
  )
  match partial.kind {
    PdfErrorKind::PartialPageFailure => ()
    _ => fail("expected partial page failure classifier kind")
  }

  let object_stream = classify_pdf_error(
    PdfError::Unsupported("object stream not supported"),
  )
  match object_stream.kind {
    PdfErrorKind::UnsupportedObjectStream => ()
    _ => fail("expected unsupported object stream classifier kind")
  }

  let filter = classify_pdf_error(
    PdfError::Unsupported("unsupported filter /LZWDecode"),
  )
  match filter.kind {
    PdfErrorKind::UnsupportedFilter => ()
    _ => fail("expected unsupported filter classifier kind")
  }

  let malformed = classify_pdf_error(
    PdfError::AdapterFailed("malformed content stream"),
  )
  match malformed.kind {
    PdfErrorKind::MalformedContentStream => ()
    _ => fail("expected malformed content stream classifier kind")
  }

  let font_encoding = classify_pdf_error(
    PdfError::Unsupported("missing font encoding"),
  )
  match font_encoding.kind {
    PdfErrorKind::MissingFontEncoding => ()
    _ => fail("expected missing font encoding classifier kind")
  }

  let to_unicode = classify_pdf_error(
    PdfError::Unsupported("bad ToUnicode map"),
  )
  match to_unicode.kind {
    PdfErrorKind::BadToUnicode => ()
    _ => fail("expected bad ToUnicode classifier kind")
  }

  let low_signal = classify_pdf_error(
    PdfError::Unsupported("low signal extraction"),
  )
  match low_signal.kind {
    PdfErrorKind::LowSignalExtraction => ()
    _ => fail("expected low signal classifier kind")
  }

  let adapter = classify_pdf_error(
    PdfError::AdapterFailed("open failed: missing file"),
  )
  match adapter.kind {
    PdfErrorKind::AdapterFailed => ()
    _ => fail("expected adapter failed classifier kind")
  }

  let unsupported = classify_pdf_error(
    PdfError::Unsupported("some unsupported detail"),
  )
  match unsupported.kind {
    PdfErrorKind::Unsupported => ()
    _ => fail("expected unsupported classifier kind")
  }
}
