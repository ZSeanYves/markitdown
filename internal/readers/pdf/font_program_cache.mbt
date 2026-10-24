///|
priv struct PdfFontDecodeParamsKey {
  predictor : Int32?
  colors : Int32?
  bits_per_component : Int32?
  columns : Int32?
  early_change : Int32?
} derive(Eq, Hash)

///|
// A typed snapshot of every parameter consumed by the existing decoder. An
// invalid specification keeps its exact dictionary rather than its message.
priv enum PdfFontDecodePlanKey {
  Resolved(Array[String], Array[PdfFontDecodeParamsKey?])
  Rejected(String)
} derive(Eq, Hash)

///|
priv struct PdfFontProgramKey {
  object_id : Int32
  selected_object_id : Int32
  definition_offset : Int64
  generation : Int32
  payload_start : Int64
  primary_length : Int32
  endstream_length : Int32
  endstream_eol_suffix : Int32
  endstream_eol_length : Int32
  declared_length : Int32?
  kind : Int32?
  plan : PdfFontDecodePlanKey
} derive(Eq, Hash)

///|
// Owned by one full-store extraction, never by the shared account or a global.
// Keys, plans and programs are private and immutable after publication. Local
// ordinary decode errors remain distinct from a validated unsupported kind.
priv struct PdfFontProgramCache {
  context : PdfStreamDecodeContext
  programs : Map[PdfFontProgramKey, Result[PdfEmbeddedFontProgram?, String]]
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
  kind : Int32?,
) -> PdfFontProgramKey? {
  match object.stream {
    Some(Ranged(range)) => {
      let plan = match pdf_extract_stream_filter_specs(object.dict_text) {
        Ok((filters, params)) => {
          let key_params : Array[PdfFontDecodeParamsKey?] = []
          for param in params {
            key_params.push(
              param.map(value => {
                predictor: value.predictor,
                colors: value.colors,
                bits_per_component: value.bits_per_component,
                columns: value.columns,
                early_change: value.early_change,
              }),
            )
          }
          PdfFontDecodePlanKey::Resolved(filters, key_params)
        }
        Err(_) => Rejected(object.dict_text)
      }
      Some({
        object_id: object.object_id,
        selected_object_id: range.object_id,
        definition_offset: range.definition_offset,
        generation: range.generation,
        payload_start: range.payload_start,
        primary_length: range.primary_length,
        endstream_length: range.endstream_length,
        endstream_eol_suffix: range.endstream_eol_suffix,
        endstream_eol_length: range.endstream_eol_length,
        declared_length: range.declared_length,
        kind,
        plan,
      })
    }
    _ => None
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
// Native64 post-parse program payload. The five array-reference fields and
// packed optional-width field are counted even for an empty program/None.
// Generated-C verification of this isolated model remains an acceptance gate.
fn pdf_font_program_retained_payload(
  context : PdfStreamDecodeContext,
  program : PdfEmbeddedFontProgram,
) -> Int64 raise PdfHardDecodeFailure {
  let mut bytes = 48L
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
  bytes
}

///|
// Only stored payload is modeled: not Map buckets/growth, Entry links/hash/PSL,
// tags, headers, padding, allocator overhead or parser/key-construction scratch.
fn pdf_font_result_retained_payload(
  context : PdfStreamDecodeContext,
  key : PdfFontProgramKey,
  result : Result[PdfEmbeddedFontProgram?, String],
) -> Int64 raise PdfHardDecodeFailure {
  // Key numeric fields44 + declared_length8 + kind8 + plan ref8;
  // selected outer Entry key/value refs16 + Result's value ref8.
  let mut bytes = 92L
  match key.plan {
    Resolved(filters, params) => {
      bytes = pdf_font_payload_add(context, bytes, 16L)
      bytes = pdf_font_payload_add(
        context,
        bytes,
        filters.capacity().to_int64() * 8L,
      )
      for filter in filters {
        bytes = pdf_font_payload_add(
          context,
          bytes,
          filter.length().to_int64() * 2L,
        )
      }
      bytes = pdf_font_payload_add(
        context,
        bytes,
        params.capacity().to_int64() * 8L,
      )
      for param in params {
        if param is Some(_) {
          // Five packed Option[Int] fields, including their None states.
          bytes = pdf_font_payload_add(context, bytes, 40L)
        }
      }
    }
    Rejected(dict_text) => {
      bytes = pdf_font_payload_add(context, bytes, 8L)
      bytes = pdf_font_payload_add(
        context,
        bytes,
        dict_text.length().to_int64() * 2L,
      )
    }
  }
  match result {
    Ok(Some(program)) =>
      bytes = pdf_font_payload_add(
        context,
        bytes,
        pdf_font_program_retained_payload(context, program),
      )
    Ok(None) => ()
    Err(message) =>
      bytes = pdf_font_payload_add(
        context,
        bytes,
        message.length().to_int64() * 2L,
      )
  }
  bytes
}

///|
fn pdf_font_program_result_value(
  result : Result[PdfEmbeddedFontProgram?, String],
) -> PdfEmbeddedFontProgram? {
  match result {
    Ok(program) => program
    Err(_) => None
  }
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
  let key = if cache is Some(_) {
    pdf_font_program_cache_key(object, kind)
  } else {
    None
  }
  if cache is Some(cache) && key is Some(key) {
    if cache.programs.get(key) is Some(result) {
      return pdf_font_program_result_value(result)
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
  let result = match decoded {
    Ok(bytes) => {
      // Unknown FontFile3 subtypes still decode before validated absence.
      let program = match kind {
        Some(0) => pdf_parse_embedded_sfnt_font_program(bytes)
        Some(1) => pdf_parse_embedded_cff_font_program(bytes, false)
        Some(2) => pdf_parse_embedded_cff_font_program(bytes, true)
        _ => None
      }
      Ok(program)
    }
    // This is the decoder's typed ordinary error, never message matching.
    Err(UnsupportedFeature(message)) => Err(message)
    // No Ranged identity exists for the current missing-stream ParseFailed.
    // Preserve other recovery behavior without publishing future hard variants.
    Err(_) => return None
  }
  if cache is Some(cache) && key is Some(key) {
    // Decode callbacks may latch a failure: it must beat a newly computed
    // ordinary result, not be hidden by publication of that negative result.
    pdf_check_stream_live(Some(cache.context))
    let payload = pdf_font_result_retained_payload(cache.context, key, result)
    match (cache.context.budget.retain_resident)(CacheBytes, payload) {
      Ok(_) => cache.programs.set(key, result)
      Err(error) => pdf_raise_budget_failure(Some(cache.context), error)
    }
  }
  pdf_font_program_result_value(result)
}
