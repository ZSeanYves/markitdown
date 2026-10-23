///|
// This is PDF syntax framing, not a permissive RFC1950 decoder. Retain every
// marker-bounded source byte, including CR/LF removed by the legacy scanner.
fn pdf_stream_precise_payload(
  stream : PdfNativeStreamSlice,
  length : Int32,
) -> Bytes raise PdfHardDecodeFailure {
  if length == stream.endstream_bytes.length() {
    return stream.endstream_bytes
  }
  pdf_retain_decoded_payload(stream.decode_context, length.to_int64())
  Bytes::makei(length, fn(index) {
    if index < stream.endstream_bytes.length() {
      stream.endstream_bytes[index]
    } else {
      ((
        stream.endstream_eol_suffix >>
        ((index - stream.endstream_bytes.length()) * 8)
      ) &
      0xFF).to_byte()
    }
  })
}

///|
fn pdf_framing_eol(byte : Byte) -> Bool {
  byte == b'\r' || byte == b'\n'
}

///|
fn pdf_payload_differs_only_eol(left : Bytes, right : Bytes) -> Bool {
  let common = left.length().min(right.length())
  for i in 0..<common {
    if left[i] != right[i] {
      return false
    }
  }
  let longer = if left.length() > right.length() { left } else { right }
  for i in common..<longer.length() {
    if !pdf_framing_eol(longer[i]) {
      return false
    }
  }
  true
}

///|
fn pdf_decode_flate_stream_framing(
  payload : Bytes,
  context : PdfStreamDecodeContext?,
  framing : PdfNativeStreamSlice?,
) -> Bytes raise PdfHardDecodeFailure {
  pdf_inflate_zlib_bounded(payload, context) catch {
    PdfHardDecodeFailure(StreamIntegrityFailed(TrailingData, message)) =>
      pdf_try_flate_eol_framings(
        payload,
        context,
        framing,
        StreamIntegrityFailed(TrailingData, message),
      )
    PdfHardDecodeFailure(StreamIntegrityFailed(Truncated, message)) =>
      pdf_try_flate_eol_framings(
        payload,
        context,
        framing,
        StreamIntegrityFailed(Truncated, message),
      )
    // ChecksumMismatch is terminal, including a corrupt trailer ending CR/LF.
    // Budget and every non-integrity effect also bypass candidate recovery.
    error => raise error
  }
}

///|
fn pdf_try_flate_eol_framings(
  payload : Bytes,
  context : PdfStreamDecodeContext?,
  framing : PdfNativeStreamSlice?,
  original : PdfNativeError,
) -> Bytes raise PdfHardDecodeFailure {
  let stream = match framing {
    Some(value) => value
    None => raise PdfHardDecodeFailure(original)
  }
  let raw = pdf_stream_precise_payload(
    stream,
    stream.endstream_bytes.length() + stream.endstream_eol_length,
  )
  let attempted : Array[Bytes] = [payload]
  for source in [stream.primary_bytes, raw] {
    // The only uncertain syntax is one EOL (LF, CR, CRLF). Two trims also
    // cover a declared span that includes LF plus a separate marker LF.
    for trim in [0, 1, 2] {
      if trim > source.length() {
        continue
      }
      let length = source.length() - trim
      let mut only_eol = true
      for i in length..<source.length() {
        if !pdf_framing_eol(source[i]) {
          only_eol = false
        }
      }
      if !only_eol {
        continue
      }
      // No byte guess, non-EOL deletion, backwards trailer search or I/O.
      if !pdf_payload_differs_only_eol(payload, source) {
        continue
      }
      if attempted.any(bytes => {
          bytes.length() == length && bytes[:] == source[:length]
        }) {
        continue
      }
      let candidate = if trim == 0 {
        source
      } else {
        pdf_retain_decoded_payload(context, length.to_int64())
        source[:length].to_owned()
      }
      attempted.push(candidate)
      let result = try
        pdf_inflate_zlib_bounded(candidate, context) |> Some
      catch {
        PdfHardDecodeFailure(StreamIntegrityFailed(TrailingData, _)) => None
        PdfHardDecodeFailure(StreamIntegrityFailed(Truncated, _)) => None
        // Every candidate is strict. A real checksum/corrupt-deflate failure
        // is not an EOL-boundary ambiguity and cannot authorize another try.
        error => raise error
      }
      if result is Some(decoded) {
        return decoded
      }
    }
  }
  raise PdfHardDecodeFailure(original)
}
