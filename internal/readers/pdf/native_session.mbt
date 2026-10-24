///|
/// Structural facts are available before native text interpretation. A missing
/// count means the existing repair/materialization path is deferred to parse.
pub struct PdfStructuralFacts {
  page_count : Int32?
  deferred_repair : Bool
  reason : String
  metadata_object_count : Int32
  metadata_object_stream_count : Int32
}

///|
/// Single-consumption artifact borrowing one conversion's InputSession.
/// It never owns a Path handle or an independent budget account.
pub struct PdfNativeSession {
  priv source : @input.InputSource
  priv cursor : @input.SourceCursor
  priv decode_context : PdfStreamDecodeContext
  priv indexed : PdfIndexedProbe?
  priv facts : PdfStructuralFacts
  priv consumed : Ref[Bool]
}

///|
priv struct PdfIndexedProbe {
  source_size : Int32
  resolved : PdfResolvedXrefChain
  locations : (
    Array[PdfXrefDirectObjectLocation],
    Array[PdfXrefCompressedObjectRef],
  )
  objects : Map[Int32, PdfNativeObject]
  object_streams : PdfObjectStreamResultCache
  loading : Map[Int32, Bool]
}

///|
pub fn pdf_structural_facts(session : PdfNativeSession) -> PdfStructuralFacts {
  session.facts
}

///|
fn pdf_session_work(
  context : PdfStreamDecodeContext,
  units : Int64,
) -> Unit raise PdfHardDecodeFailure {
  match context.budget.account.charge(ParseWork, units) {
    Ok(_) => ()
    Err(error) => pdf_raise_budget_failure(Some(context), error)
  }
}

///|
fn pdf_session_retain(
  context : PdfStreamDecodeContext,
  bytes : Int64,
) -> Unit raise PdfHardDecodeFailure {
  match (context.budget.retain_resident)(CacheBytes, bytes) {
    Ok(_) => ()
    Err(error) => pdf_raise_budget_failure(Some(context), error)
  }
}

///|
/// An active caller-owned session is required: returned artifacts cannot own a
/// hidden session whose cleanup would occur before the parse stage.
pub async fn open_pdf_native_session(
  source : @input.InputSource,
) -> Result[PdfNativeSession, PdfNativeError] {
  pdf_open_native_session_impl(source) catch {
    PdfHardDecodeFailure(error) => {
      @input.record_input_failure(source, error.to_string())
      Err(error)
    }
    error => raise error
  }
}

///|
async fn pdf_open_native_session_impl(
  source : @input.InputSource,
) -> Result[PdfNativeSession, PdfNativeError] {
  let context = match pdf_make_stream_decode_context(source) {
    Some(value) => value
    None =>
      return Err(
        ReadFailed("reusable PDF session requires an active input session"),
      )
  }
  let cursor = match @input.open_source_cursor(source) {
    Ok(value) => value
    Err(message) => return Err(ReadFailed(message))
  }
  let mut indexed = None
  let mut page_count = None
  let mut reason = "source_size_or_index_deferred"
  match cursor.size {
    Some(size) if size >= 5L && size <= 512L * 1024L * 1024L => {
      let prefix = match pdf_cursor_read_exact(cursor, 0, 5) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      if pdf_byte_string(prefix) != "%PDF-" {
        return Err(
          ParseFailed(
            "input is not a PDF file: " + pdf_native_source_id(source),
          ),
        )
      }
      let source_size = size.to_int()
      let tail_length = source_size.min(64 * 1024)
      let tail = match
        pdf_cursor_read_exact(cursor, source_size - tail_length, tail_length) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      pdf_session_work(context, tail_length.to_int64())
      let startxref = pdf_find_startxref_offset(pdf_byte_string(tail))
      if startxref is Some(offset) && offset >= 0 && offset < source_size {
        match
          pdf_resolve_xref_chain_cursor(
            cursor,
            source_size,
            offset,
            decode_context=Some(context),
          ) {
          Err(ReadFailed(message)) => return Err(ReadFailed(message))
          Err(_) => reason = "xref_repair_deferred"
          Ok(resolved) => {
            if resolved.trailer_hints.any(hint => hint.contains("/Encrypt")) {
              return Err(
                EncryptedUnsupported(
                  "encrypted PDF is unsupported in native PDF reader backend: " +
                  pdf_native_source_id(source),
                ),
              )
            }
            // Logical scalar payload only: xref ID/two fields + sorted ID/offset.
            // Map/node/allocator overhead is explicitly outside this model.
            pdf_session_retain(
              context,
              resolved.entries.length().to_int64() * 20L,
            )
            pdf_session_work(context, resolved.entries.length().to_int64())
            let probe : PdfIndexedProbe = {
              source_size,
              resolved,
              locations: pdf_xref_object_locations(resolved, source_size),
              objects: Map([]),
              object_streams: pdf_make_object_stream_result_cache(Some(context)),
              loading: Map([]),
            }
            page_count = match pdf_probe_page_tree(probe, cursor, context) {
              Ok(value) => value
              Err(ReadFailed(message)) => return Err(ReadFailed(message))
              Err(_) => None
            }
            reason = if page_count is Some(_) {
              "indexed_page_tree"
            } else {
              "page_tree_repair_deferred"
            }
            indexed = Some(probe)
          }
        }
      }
    }
    _ => ()
  }
  let metadata_object_count = indexed
    .map(probe => probe.objects.length())
    .unwrap_or(0)
  let metadata_object_stream_count = indexed
    .map(probe => probe.object_streams.length())
    .unwrap_or(0)
  Ok({
    source,
    cursor,
    decode_context: context,
    indexed,
    facts: {
      page_count,
      deferred_repair: page_count is None,
      reason,
      metadata_object_count,
      metadata_object_stream_count,
    },
    consumed: Ref(false),
  })
}

///|
async fn pdf_probe_load_object(
  probe : PdfIndexedProbe,
  cursor : @input.SourceCursor,
  context : PdfStreamDecodeContext,
  object_id : Int32,
  depth : Int32,
) -> Result[PdfNativeObject?, PdfNativeError] {
  if probe.objects.get(object_id) is Some(object) {
    return Ok(Some(object))
  }
  pdf_session_work(context, 1L)
  if depth >= 256 || probe.loading.get(object_id).unwrap_or(false) {
    return Ok(None)
  }
  probe.loading.set(object_id, true)
  defer probe.loading.set(object_id, false)
  match probe.resolved.entries.get(object_id) {
    Some(InUse(offset, _generation)) if offset >= 0 &&
      offset < probe.source_size => {
      let locations = probe.locations.0
      let mut low = 0
      let mut high = locations.length()
      while low < high {
        pdf_session_work(context, 1L)
        let middle = low + (high - low) / 2
        if locations[middle].offset < offset {
          low = middle + 1
        } else {
          high = middle
        }
      }
      if low >= locations.length() || locations[low].object_id != object_id {
        return Ok(None)
      }
      // Multiple IDs pointing at the same bytes need the legacy full-store
      // recovery rules; don't guess a structural count or scan here.
      if low + 1 < locations.length() && locations[low + 1].offset == offset {
        return Ok(None)
      }
      let end = if low + 1 < locations.length() {
        locations[low + 1].offset
      } else {
        probe.source_size
      }
      let length = (end - offset).min(PDF_RANDOM_ACCESS_WINDOW_MAX)
      // Before fetch/parse, retain a source-size upper bound for the cached
      // dictionary UTF16 payload (2*n) and both stream candidates (2*n).
      // Existing parser scratch/maps and allocator overhead remain unmeasured.
      pdf_session_retain(context, length.to_int64() * 4L)
      pdf_session_work(context, length.to_int64())
      let lease = pdf_reserve_decode_scratch(Some(context), length.to_int64())
      defer pdf_release_decode_scratch(lease)
      let window = match pdf_cursor_read_exact(cursor, offset, length) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      match
        pdf_parse_indirect_object_at(
          window,
          0,
          decode_context=Some(context),
          range_source=Some({
            cursor,
            window_start: offset.to_int64(),
            definition_offset: offset.to_int64(),
            generation: _generation,
            metadata_prepaid: true,
          }),
        ) {
        Ok(object) if object.object_id == object_id => {
          probe.objects.set(object_id, object)
          Ok(Some(object))
        }
        _ => Ok(None)
      }
    }
    Some(Compressed(parent_id, _member_index)) => {
      let parent = match
        pdf_probe_load_object(probe, cursor, context, parent_id, depth + 1) {
        Ok(Some(value)) => value
        Ok(None) => return Ok(None)
        Err(error) => return Err(error)
      }
      let entries = match
        pdf_parse_object_stream_entries(parent, cache=probe.object_streams) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      // Preserve existing materializer's ID selection, including its current
      // tolerance of a mismatched xref member index; do not tighten semantics.
      for object in entries {
        if object.object_id == object_id {
          probe.objects.set(object_id, object)
          return Ok(Some(object))
        }
      }
      Ok(None)
    }
    _ => Ok(None)
  }
}

///|
async fn pdf_probe_page_tree(
  probe : PdfIndexedProbe,
  cursor : @input.SourceCursor,
  context : PdfStreamDecodeContext,
) -> Result[Int32?, PdfNativeError] {
  let root_id = match
    pdf_lookup_trailer_object_reference(probe.resolved.trailer_hints, "/Root") {
    Some(value) => value
    None => return Ok(None)
  }
  let root = match pdf_probe_load_object(probe, cursor, context, root_id, 0) {
    Ok(Some(value)) => value
    Ok(None) => return Ok(None)
    Err(error) => return Err(error)
  }
  let pages_id = match
    pdf_extract_object_reference_after(root.dict_text, "/Pages") {
    Some(value) => value
    None => return Ok(None)
  }
  match pdf_probe_load_page_tree(probe, cursor, context, pages_id, Map([]), 0) {
    Err(error) => Err(error)
    Ok(false) => Ok(None)
    Ok(true) => {
      let pages = pdf_collect_page_tree_ids(probe.objects, pages_id, Map([]), 0)
      // The full interpreter scans all Page objects when traversal is empty.
      // An empty metadata closure cannot prove that fallback's page count.
      Ok(if pages.length() > 0 { Some(pages.length()) } else { None })
    }
  }
}

///|
async fn pdf_probe_load_page_tree(
  probe : PdfIndexedProbe,
  cursor : @input.SourceCursor,
  context : PdfStreamDecodeContext,
  object_id : Int32,
  visited : Map[Int32, Bool],
  depth : Int32,
) -> Result[Bool, PdfNativeError] {
  pdf_session_work(context, 1L)
  if depth >= 256 || visited.get(object_id).unwrap_or(false) {
    return Ok(false)
  }
  visited.set(object_id, true)
  let object = match
    pdf_probe_load_object(probe, cursor, context, object_id, 0) {
    Ok(Some(value)) => value
    Ok(None) => return Ok(false)
    Err(error) => return Err(error)
  }
  if pdf_object_is_page(object) {
    return Ok(true)
  }
  if !pdf_object_is_pages_node(object) {
    return Ok(false)
  }
  if pdf_extract_dict_value(object.dict_text, "/Kids")
    is Some(Reference(array_id, _)) {
    match pdf_probe_load_object(probe, cursor, context, array_id, 0) {
      Ok(Some(_)) => ()
      Ok(None) => return Ok(false)
      Err(error) => return Err(error)
    }
  }
  let children = pdf_extract_resolved_object_references_after(
    object.dict_text,
    "/Kids",
    probe.objects,
  )
  if children.length() == 0 {
    return Ok(false)
  }
  for child in children {
    match
      pdf_probe_load_page_tree(
        probe,
        cursor,
        context,
        child,
        visited,
        depth + 1,
      ) {
      Ok(true) => ()
      Ok(false) => return Ok(false)
      Err(error) => return Err(error)
    }
  }
  Ok(true)
}

///|
/// Consume the artifact inside its original, still-live input owner. Recheck
/// first failure/closure even when all metadata is already cached.
pub async fn extract_pdf_native_document_from_session(
  session : PdfNativeSession,
) -> Result[PdfNativeDocument, PdfNativeError] {
  pdf_extract_native_session_impl(session) catch {
    PdfHardDecodeFailure(error) => {
      @input.record_input_failure(session.source, error.to_string())
      Err(error)
    }
    error => raise error
  }
}

///|
async fn pdf_extract_native_session_impl(
  session : PdfNativeSession,
) -> Result[PdfNativeDocument, PdfNativeError] {
  match @input.open_source_cursor(session.source) {
    Ok(_) => ()
    Err(message) => return Err(ReadFailed(message))
  }
  if session.consumed.val {
    return Err(ParseFailed("PDF session has already been consumed"))
  }
  session.consumed.val = true
  let parsed = match session.indexed {
    None => pdf_load_object_store(session.source, Some(session.decode_context))
    Some(probe) =>
      match
        pdf_build_store_from_resolved_xref(
          probe.resolved,
          probe.source_size,
          async fn(offset, length) {
            match pdf_cursor_read_exact(session.cursor, offset, length) {
              Ok(value) => Ok(value)
              Err(error) => Err(error.to_string())
            }
          },
          "cursor_xref",
          decode_context=Some(session.decode_context),
          prefetched=probe.objects,
          object_streams=probe.object_streams,
          locations=Some(probe.locations),
          range_cursor=Some(session.cursor),
        ) {
        Ok(Some(store)) => Ok(store)
        Err(ReadFailed(message)) => Err(ReadFailed(message))
        _ =>
          pdf_load_object_store_materialized(
            session.source,
            Some(session.decode_context),
          )
      }
  }
  match parsed {
    Ok(store) => pdf_extract_document_from_store(session.source, store)
    Err(error) => Err(error)
  }
}
