///|
priv struct PdfObjectStreamResultKey {
  object_id : Int32
  selected_object_id : Int32
  definition_offset : Int64
  generation : Int32
  dict_text : String
  payload_start : Int64
  primary_length : Int32
  endstream_length : Int32
  endstream_eol_suffix : Int32
  endstream_eol_length : Int32
  declared_length : Int32?
} derive(Eq, Hash)

///|
// One probe/document owns this map. It is shared only with that probe's full
// builder, never through a common parent budget or across a Loaded repair.
priv struct PdfObjectStreamResultCache {
  context : PdfStreamDecodeContext?
  entries : Map[
    PdfObjectStreamResultKey,
    Result[Array[PdfNativeObject], PdfNativeError],
  ]
}

///|
fn pdf_make_object_stream_result_cache(
  context : PdfStreamDecodeContext?,
) -> PdfObjectStreamResultCache {
  { context, entries: Map([]), }
}

///|
// Keep the structural fact's existing successful-stream count. An ordinary
// cached Err must not become an additional successfully parsed metadata stream.
fn PdfObjectStreamResultCache::length(
  self : PdfObjectStreamResultCache,
) -> Int32 {
  let mut count = 0
  for _, result in self.entries {
    if result is Ok(_) {
      count += 1
    }
  }
  count
}

///|
fn pdf_object_stream_result_key(
  object : PdfNativeObject,
) -> PdfObjectStreamResultKey? {
  match object.stream {
    Some(Ranged(range)) =>
      Some({
        object_id: object.object_id,
        selected_object_id: range.object_id,
        definition_offset: range.definition_offset,
        generation: range.generation,
        dict_text: object.dict_text,
        payload_start: range.payload_start,
        primary_length: range.primary_length,
        endstream_length: range.endstream_length,
        endstream_eol_suffix: range.endstream_eol_suffix,
        endstream_eol_length: range.endstream_eol_length,
        declared_length: range.declared_length,
      })
    _ => None
  }
}

///|
fn pdf_object_stream_result_is_cacheable(
  result : Result[Array[PdfNativeObject], PdfNativeError],
) -> Bool {
  match result {
    Ok(_) | Err(ParseFailed(_) | UnsupportedFeature(_)) => true
    _ => false
  }
}

///|
fn pdf_objstm_payload_add(
  context : PdfStreamDecodeContext,
  used : Int64,
  requested : Int64,
) -> Int64 raise PdfHardDecodeFailure {
  if requested > 9223372036854775807L - used {
    pdf_raise_budget_failure(
      Some(context),
      ArithmeticOverflow(Resident(CacheBytes), used~, requested~),
    )
  }
  used + requested
}

///|
// Additional postparse stored fields, not the old text4N+16 logical model.
// Native C verification is required before freezing these field units. Result
// arrays/objects/parser scratch remain under the old partial model, not claimed
// as a newly complete allocation/RSS bound. Strings count by occurrence.
fn pdf_object_stream_result_retained_payload(
  context : PdfStreamDecodeContext,
  cache : PdfObjectStreamResultCache,
  key : PdfObjectStreamResultKey,
  result : Result[Array[PdfNativeObject], PdfNativeError],
) -> Int64 raise PdfHardDecodeFailure {
  // Key numeric44 + dict ref8 + packed optional Length8;
  // selected Entry key/value refs16 + Result value ref8.
  let mut bytes = 84L
  if cache.entries.length() == 0 {
    // Cache wrapper context reference and map reference, first publication only.
    bytes = pdf_objstm_payload_add(context, bytes, 16L)
  }
  bytes = pdf_objstm_payload_add(
    context,
    bytes,
    key.dict_text.length().to_int64() * 2L,
  )
  match result {
    Ok(_) => ()
    Err(ParseFailed(message) | UnsupportedFeature(message)) => {
      bytes = pdf_objstm_payload_add(context, bytes, 8L)
      bytes = pdf_objstm_payload_add(
        context,
        bytes,
        message.length().to_int64() * 2L,
      )
    }
    // No other error variant may be published by the gateway.
    Err(error) => raise PdfHardDecodeFailure(error)
  }
  bytes
}
