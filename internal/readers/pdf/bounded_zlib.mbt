// RFC1950 framing/exact-body policy adapted from moonbit-community/flate@0.8.5,
// revision 3cbcb5c8bde0b34117fd7980b9f41719f2b8f3d7, flate/zlib/zlib.mbt.
// Apache-2.0; see UPSTREAM.md, NOTICE and ../../inflate/LICENSE.

///|
priv struct PdfStreamDecodeContext {
  source : @input.InputSource
  budget : @budget.BudgetContext
}

///|
// Compression integrity, resource and deferred source IO failures use this
// effect so optional font/image recovery cannot swallow the shared first error.
// Existing unsupported-filter and decoded-font syntax recovery stays Result.
priv suberror PdfHardDecodeFailure {
  PdfHardDecodeFailure(PdfNativeError)
}

///|
fn pdf_make_stream_decode_context(
  source : @input.InputSource,
) -> PdfStreamDecodeContext? {
  @input.input_source_budget_context(source).map(budget => { source, budget, })
}

///|
fn[T] pdf_raise_budget_failure(
  context : PdfStreamDecodeContext?,
  error : @budget.BudgetError,
) -> T raise PdfHardDecodeFailure {
  if context is Some(context) {
    @input.record_input_budget_failure(context.source, error)
  }
  raise PdfHardDecodeFailure(BudgetExceeded(error))
}

///|
fn pdf_charge_inflate(
  context : PdfStreamDecodeContext?,
  produced : Int32,
) -> Unit raise PdfHardDecodeFailure {
  if context is Some(context) {
    match context.budget.account.charge(InflateBytes, produced.to_int64()) {
      Ok(_) => ()
      Err(error) => pdf_raise_budget_failure(Some(context), error)
    }
  }
}

///|
fn pdf_reserve_decode_scratch(
  context : PdfStreamDecodeContext?,
  bytes : Int64,
) -> @budget.BudgetLease? raise PdfHardDecodeFailure {
  match context {
    None => None
    Some(context) =>
      match context.budget.account.reserve(WorkingBytes, bytes) {
        Ok(lease) => Some(lease)
        Err(error) => pdf_raise_budget_failure(Some(context), error)
      }
  }
}

///|
fn pdf_release_decode_scratch(lease : @budget.BudgetLease?) -> Unit {
  if lease is Some(lease) {
    lease.release()
  }
}

///|
fn pdf_retain_decoded_payload(
  context : PdfStreamDecodeContext?,
  bytes : Int64,
) -> Unit raise PdfHardDecodeFailure {
  if context is Some(context) {
    match (context.budget.retain_resident)(WorkingBytes, bytes) {
      Ok(_) => ()
      Err(error) => pdf_raise_budget_failure(Some(context), error)
    }
  }
}

///|
fn[T] pdf_raise_zlib_integrity(
  kind : @zlib.ZlibErrorKind,
  message : String,
) -> T raise PdfHardDecodeFailure {
  raise PdfHardDecodeFailure(StreamIntegrityFailed(kind, message))
}

///|
// Same RFC1950 admission and exact-body policy as pinned external zlib 0.8.5.
// No caller-visible bytes are published until the trailer is verified.
fn pdf_inflate_zlib_bounded(
  compressed : Bytes,
  context : PdfStreamDecodeContext?,
) -> Bytes raise PdfHardDecodeFailure {
  pdf_charge_inflate(context, 0)
  let length = compressed.length()
  guard length >= 6 else {
    pdf_raise_zlib_integrity(Truncated, "zlib: input too short")
  }
  let cmf = compressed[0].to_int()
  let flg = compressed[1].to_int()
  guard (cmf & 0x0F) == 8 else {
    pdf_raise_zlib_integrity(
      InvalidHeader,
      "zlib: unsupported compression method",
    )
  }
  guard cmf >> 4 <= 7 else {
    pdf_raise_zlib_integrity(InvalidHeader, "zlib: invalid window size")
  }
  guard (cmf * 256 + flg) % 31 == 0 else {
    pdf_raise_zlib_integrity(InvalidHeader, "zlib: bad header check")
  }
  guard (flg & 0x20) == 0 else {
    pdf_raise_zlib_integrity(
      DictionaryRequired,
      "zlib: preset dictionary required (use the streaming Decoder)",
    )
  }
  let owned = pdf_reserve_decode_scratch(
    context,
    @inflate.inflater_payload_upper_bound() + 32768L,
  )
  defer pdf_release_decode_scratch(owned)
  let inflater = @inflate.Inflater()
  let scratch = FixedArray::make(32768, b'\x00')
  let chunks : Array[Bytes] = []
  let chunk_leases : Array[@budget.BudgetLease] = []
  defer (for lease in chunk_leases {
    lease.release()
  })
  let checksum = @checksum.Adler32()
  let input = compressed.exact_view(start=2, end=length - 4)
  let mut position = 0
  let mut total = 0
  while true {
    let status = inflater.step_into(input[position:], scratch) catch {
      InflateError(_, message) => {
        // The patched engine retains physical output even on a throwing step.
        // Charge it before returning integrity error; no failed bytes escape.
        pdf_charge_inflate(context, inflater.last_produced())
        pdf_raise_zlib_integrity(
          InvalidDeflate,
          "zlib: invalid DEFLATE stream: " + message,
        )
      }
    }
    let produced = inflater.last_produced()
    pdf_charge_inflate(context, produced)
    position += inflater.last_consumed()
    guard produced <= 2147483647 - total else {
      raise PdfHardDecodeFailure(
        ParseFailed("PDF decoded stream exceeds addressable Bytes length"),
      )
    }
    if produced > 0 {
      if pdf_reserve_decode_scratch(context, produced.to_int64()) is Some(lease) {
        chunk_leases.push(lease)
      }
      let chunk = Bytes::makei(produced, i => scratch[i])
      checksum.update(chunk[:])
      chunks.push(chunk)
      total += produced
    }
    match status {
      Done => {
        guard position == input.length() else {
          pdf_raise_zlib_integrity(
            TrailingData,
            "zlib: data between DEFLATE stream and trailer",
          )
        }
        break
      }
      NeedMoreOutput => continue
      NeedMoreInput => {
        pdf_raise_zlib_integrity(Truncated, "zlib: truncated DEFLATE stream")
        break
      }
    }
  }
  let expected = (compressed[length - 4].to_uint() << 24) |
    (compressed[length - 3].to_uint() << 16) |
    (compressed[length - 2].to_uint() << 8) |
    compressed[length - 1].to_uint()
  guard checksum.finish() == expected else {
    pdf_raise_zlib_integrity(ChecksumMismatch, "zlib: Adler-32 mismatch")
  }
  // Returned bare Bytes can be retained by any downstream decoder/parser.
  // Keep its lease with the owning conversion; private chunks/Buffer release.
  pdf_retain_decoded_payload(context, total.to_int64())
  let aggregate_lease = pdf_reserve_decode_scratch(
    context,
    total.max(1).to_int64(),
  )
  defer pdf_release_decode_scratch(aggregate_lease)
  let output = Buffer(size_hint=total)
  for chunk in chunks {
    output.write_bytes(chunk)
  }
  output.to_bytes()
}
