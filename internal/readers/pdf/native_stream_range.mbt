///|
priv struct PdfObjectRangeSource {
  cursor : @input.SourceCursor
  window_start : Int64
  definition_offset : Int64
  generation : Int32
  metadata_prepaid : Bool
}

///|
priv struct PdfNativeStreamRange {
  cursor : @input.SourceCursor
  definition_offset : Int64
  generation : Int32
  object_id : Int32
  payload_start : Int64
  primary_length : Int32
  endstream_length : Int32
  endstream_eol_suffix : Int32
  endstream_eol_length : Int32
  declared_length : Int32?
  decode_context : PdfStreamDecodeContext?
}

///|
priv struct PdfLoadedStreamRead {
  stream : PdfNativeStreamSlice
  private_payload : Ref[@budget.BudgetLease?]
  payload_bytes : Int64
}

///|
fn pdf_release_stream_read(read : PdfLoadedStreamRead) -> Unit {
  if read.private_payload.val is Some(lease) {
    lease.release()
    read.private_payload.val = None
  }
}

///|
fn pdf_publish_stream_read(
  read : PdfLoadedStreamRead,
) -> Unit raise PdfHardDecodeFailure {
  // Synchronous transfer: release the private reservation immediately before
  // the session retains the same amount. No await, read or published Bytes
  // occurs in between, so successful publication does not double-reserve.
  pdf_release_stream_read(read)
  pdf_retain_decoded_payload(read.stream.decode_context, read.payload_bytes)
}

///|
fn pdf_stream_context(
  reference : PdfNativeStreamRef,
) -> PdfStreamDecodeContext? {
  match reference {
    Loaded(stream) => stream.decode_context
    SelectedLoaded(_, definition) => Some(definition.snapshot.context)
    Ranged(range) => range.decode_context
  }
}

///|
fn pdf_retain_range_metadata(
  source : PdfObjectRangeSource?,
  context : PdfStreamDecodeContext?,
  dict_bytes : Int32,
  has_range : Bool,
) -> Unit raise PdfHardDecodeFailure {
  if source is Some(source) &&
    !source.metadata_prepaid &&
    context is Some(context) {
    // UTF16 dictionary payload plus the range's 44 bytes of numeric fields.
    // Map/capacity/enum tags/cursor and allocator overhead remain unmeasured.
    let payload = dict_bytes.to_int64() * 2L +
      (if has_range { 44L } else { 0L })
    match (context.budget.retain_resident)(CacheBytes, payload) {
      Ok(_) => ()
      Err(error) => pdf_raise_budget_failure(Some(context), error)
    }
  }
}

///|
async fn pdf_check_stream_live(context : PdfStreamDecodeContext?) -> Unit {
  if context is Some(context) {
    match @input.open_source_cursor(context.source) {
      Ok(_) => ()
      Err(message) => pdf_raise_stream_read_failure(context, message)
    }
  }
}

///|
fn[T] pdf_raise_stream_read_failure(
  context : PdfStreamDecodeContext,
  message : String,
) -> T raise PdfHardDecodeFailure {
  match @input.input_source_failure(context.source) {
    Some(BudgetFailure(error)) => pdf_raise_budget_failure(Some(context), error)
    Some(InputError(first)) => raise PdfHardDecodeFailure(ReadFailed(first))
    Some(ResourceLimit(_)) => raise PdfHardDecodeFailure(ReadFailed(message))
    None => ()
  }
  if context.budget.account.failure() is Some(error) {
    pdf_raise_budget_failure(Some(context), error)
  }
  @input.record_input_failure(context.source, message)
  raise PdfHardDecodeFailure(ReadFailed(message))
}

///|
async fn pdf_load_stream_reference(
  reference : PdfNativeStreamRef,
) -> PdfLoadedStreamRead {
  pdf_check_stream_live(pdf_stream_context(reference))
  match reference {
    Loaded(stream) | SelectedLoaded(stream, _) =>
      { stream, private_payload: Ref(None), payload_bytes: 0L, }
    Ranged(range) => {
      // Returned Bytes may escape through raw images or unfiltered content.
      // Retain their payload until the owning InputSession ends; the temporary
      // exact-read result has a private lease and is always copied below.
      let distinct = range.primary_length != range.endstream_length
      let retained = range.primary_length.to_int64() +
        (if distinct { range.endstream_length.to_int64() } else { 0L })
      let payload_lease = pdf_reserve_decode_scratch(
        range.decode_context,
        retained,
      )
      let returned = Ref(false)
      defer (if !returned.val { pdf_release_decode_scratch(payload_lease) })
      let read_length = range.primary_length.max(range.endstream_length)
      let lease = pdf_reserve_decode_scratch(
        range.decode_context,
        read_length.to_int64(),
      )
      defer pdf_release_decode_scratch(lease)
      let bytes = match
        @input.source_cursor_read_exact_at(
          range.cursor,
          range.payload_start,
          read_length,
        ) {
        Ok(value) => value
        Err(message) =>
          match range.decode_context {
            Some(context) => pdf_raise_stream_read_failure(context, message)
            None => raise PdfHardDecodeFailure(ReadFailed(message))
          }
      }
      let primary_bytes = Bytes::makei(range.primary_length, i => bytes[i])
      let endstream_bytes = if distinct {
        Bytes::makei(range.endstream_length, i => bytes[i])
      } else {
        primary_bytes
      }
      let stream = {
        primary_bytes,
        endstream_bytes,
        endstream_eol_suffix: range.endstream_eol_suffix,
        endstream_eol_length: range.endstream_eol_length,
        declared_length: range.declared_length,
        decode_context: range.decode_context,
      }
      returned.val = true
      { stream, private_payload: Ref(payload_lease), payload_bytes: retained, }
    }
  }
}
