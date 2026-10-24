///|
// Owned by one full-store extraction, never by the shared account or a global.
// Programs are read-only after publication; no stream bytes are retained here.
priv struct PdfFontProgramCache {
  context : PdfStreamDecodeContext
  programs : Map[(Int32, Int64, Int32, Int32), PdfEmbeddedFontProgram]
}

///|
fn pdf_make_font_program_cache(
  source : @input.InputSource,
) -> PdfFontProgramCache? {
  pdf_make_stream_decode_context(source).map(context => {
    context,
    programs: Map([]),
  })
}

///|
fn pdf_font_program_cache_key(
  object : PdfNativeObject,
  kind : Int32,
) -> (Int32, Int64, Int32, Int32)? {
  match object.stream {
    Some(reference) =>
      pdf_stream_reference_key(reference).map(identity => {
        (identity.0, identity.1, identity.2, kind)
      })
    None => None
  }
}

///|
fn pdf_font_payload_add(
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
// Native64 payload model, after parsing and before cache publication. Capacity
// counts backing storage; strings use UTF16 units. Parser scratch and container,
// GC and allocator headers remain unmeasured. These are units, not new limits.
fn pdf_font_program_retained_payload(
  context : PdfStreamDecodeContext,
  program : PdfEmbeddedFontProgram,
) -> Int64 raise PdfHardDecodeFailure {
  let mut bytes = 20L // object id, absolute definition offset, generation, kind
  for
    capacity in [
      program.gid_unicode_gids.capacity(),
      program.gid_glyph_name_gids.capacity(),
      program.gid_advance_pairs.capacity(),
    ] {
    bytes = pdf_font_payload_add(context, bytes, capacity.to_int64() * 4L)
  }
  for values in [program.gid_unicode_values, program.gid_glyph_name_values] {
    bytes = pdf_font_payload_add(
      context,
      bytes,
      values.capacity().to_int64() * 8L,
    )
    for value in values {
      bytes = pdf_font_payload_add(
        context,
        bytes,
        value.length().to_int64() * 2L,
      )
    }
  }
  if program.default_advance_width is Some(_) {
    bytes = pdf_font_payload_add(context, bytes, 4L)
  }
  bytes
}

///|
async fn pdf_font_program_for_object(
  object : PdfNativeObject,
  label : String,
  kind : Int32?,
  cache : PdfFontProgramCache?,
) -> PdfEmbeddedFontProgram? {
  // A cache hit must not bypass sticky budget/IO failure or a closed owner.
  if cache is Some(cache) {
    pdf_check_stream_live(Some(cache.context))
  }
  let key = match kind {
    Some(kind) => pdf_font_program_cache_key(object, kind)
    None => None
  }
  if cache is Some(cache) && key is Some(key) {
    if cache.programs.get(key) is Some(program) {
      return Some(program)
    }
  }
  let decoded = pdf_decode_stream_bytes(object, label) catch {
    PdfHardDecodeFailure(error) => {
      // Keep the original typed error for this call; a caller cannot catch it
      // and re-enter the cache with an otherwise still-live source. Typed
      // budget first errors are already latched and are never overwritten.
      if cache is Some(cache) {
        @input.record_input_failure(cache.context.source, error.to_string())
      }
      raise PdfHardDecodeFailure(error)
    }
    error => raise error
  }
  let bytes = match decoded {
    Ok(value) => value
    Err(_) => return None
  }
  // Unknown FontFile3 subtypes still decode, preserving integrity validation.
  let program = match kind {
    Some(0) => pdf_parse_embedded_sfnt_font_program(bytes)
    Some(1) => pdf_parse_embedded_cff_font_program(bytes, false)
    Some(2) => pdf_parse_embedded_cff_font_program(bytes, true)
    _ => None
  }
  if cache is Some(cache) && key is Some(key) && program is Some(program) {
    let payload = pdf_font_program_retained_payload(cache.context, program)
    match (cache.context.budget.retain_resident)(CacheBytes, payload) {
      Ok(_) => cache.programs.set(key, program)
      Err(error) => pdf_raise_budget_failure(Some(cache.context), error)
    }
  }
  program
}
