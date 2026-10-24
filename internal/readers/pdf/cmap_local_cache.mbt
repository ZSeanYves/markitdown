///|
// One immutable selected definition and its exact PDF stream decode/framing plan.
// The dictionary deliberately participates: changing Filter/DecodeParms is not
// equivalent even if a test or repair caller reuses the same numeric range.
priv struct PdfLocalCMapKey {
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
// Private to one full-store extraction. Never shared through a parent account.
// Values are local-only and immutable after publication; recursive parent
// resolution and merging remain outside this cache on every collector call.
priv struct PdfLocalCMapCache {
  context : PdfStreamDecodeContext
  entries : Map[PdfLocalCMapKey, Result[PdfToUnicodeCMapInfo, String]]
}

///|
fn pdf_make_local_cmap_cache(source : @input.InputSource) -> PdfLocalCMapCache? {
  pdf_make_stream_decode_context(source).map(context => {
    context,
    entries: Map([]),
  })
}

///|
fn pdf_local_cmap_key(object : PdfNativeObject) -> PdfLocalCMapKey? {
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
fn pdf_cmap_payload_add(
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
// Post-parse retained payload, not a pre-parse/RSS bound. Native64 slots and
// UTF16 contents are counted by occurrence, conservatively including aliases.
// Map Entry linking/hash/PSL, cache-map buckets/growth, tags, headers and parser/merge
// scratch remain unmeasured; no new default cap is introduced here.
fn pdf_local_cmap_retained_payload(
  context : PdfStreamDecodeContext,
  key : PdfLocalCMapKey,
  result : Result[PdfToUnicodeCMapInfo, String],
) -> Int64 raise PdfHardDecodeFailure {
  // Key: numeric fields44 + dict ref8 + packed Option[Int] slot8, including None.
  // Selected cache Entry key/result refs16; Result's stored value ref8.
  let mut bytes = 84L
  bytes = pdf_cmap_payload_add(
    context,
    bytes,
    key.dict_text.length().to_int64() * 2L,
  )
  match result {
    Err(message) =>
      bytes = pdf_cmap_payload_add(
        context,
        bytes,
        message.length().to_int64() * 2L,
      )
    Ok(info) => {
      // Info has five stored refs, including the two optional String slots.
      bytes = pdf_cmap_payload_add(context, bytes, 40L)
      for capacity in [info.mapping.capacity(), info.invalid_keys.capacity()] {
        bytes = pdf_cmap_payload_add(context, bytes, capacity.to_int64() * 8L)
      }
      bytes = pdf_cmap_payload_add(
        context,
        bytes,
        info.widths.capacity().to_int64() * 4L,
      )
      for key, value in info.mapping {
        bytes = pdf_cmap_payload_add(context, bytes, 16L)
        bytes = pdf_cmap_payload_add(
          context,
          bytes,
          key.length().to_int64() * 2L,
        )
        bytes = pdf_cmap_payload_add(
          context,
          bytes,
          value.length().to_int64() * 2L,
        )
      }
      for key, _ in info.invalid_keys {
        bytes = pdf_cmap_payload_add(context, bytes, 12L)
        bytes = pdf_cmap_payload_add(
          context,
          bytes,
          key.length().to_int64() * 2L,
        )
      }
      for name in [info.usecmap_name, info.builtin_parent_name] {
        if name is Some(name) {
          bytes = pdf_cmap_payload_add(
            context,
            bytes,
            name.length().to_int64() * 2L,
          )
        }
      }
    }
  }
  bytes
}

///|
async fn pdf_read_local_tounicode_cmap_info(
  object : PdfNativeObject,
) -> Result[PdfToUnicodeCMapInfo, String] {
  let text = match pdf_decode_cmap_stream_text(object) {
    Ok(result) => {
      ignore(pdf_cmap_stream_decode_result_summary(result))
      result.text
    }
    Err(failure) => {
      ignore(pdf_cmap_stream_decode_failure_summary(failure))
      return Err(failure.message)
    }
  }
  Ok(
    if text == "" {
      pdf_empty_tounicode_cmap_info()
    } else {
      pdf_parse_tounicode_cmap_info(text)
    },
  )
}

///|
async fn pdf_local_tounicode_cmap_info(
  object : PdfNativeObject,
  cache : PdfLocalCMapCache?,
) -> Result[PdfToUnicodeCMapInfo, String] {
  let key = pdf_local_cmap_key(object)
  guard cache is Some(cache) && key is Some(key) else {
    return pdf_read_local_tounicode_cmap_info(object)
  }
  // Both successful and ordinary negative hits obey the original live owner.
  pdf_check_stream_live(Some(cache.context))
  if cache.entries.get(key) is Some(value) {
    return value
  }
  let result = pdf_read_local_tounicode_cmap_info(object) catch {
    PdfHardDecodeFailure(error) => {
      // Preserve the original typed result and any existing typed first error.
      // A caught CRC/IO failure must not permit another range read on retry.
      @input.record_input_failure(cache.context.source, error.to_string())
      raise PdfHardDecodeFailure(error)
    }
    error => raise error
  }
  let payload = pdf_local_cmap_retained_payload(cache.context, key, result)
  match (cache.context.budget.retain_resident)(CacheBytes, payload) {
    Ok(_) => cache.entries.set(key, result)
    Err(error) => pdf_raise_budget_failure(Some(cache.context), error)
  }
  result
}
