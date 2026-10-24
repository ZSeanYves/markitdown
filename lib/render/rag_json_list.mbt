///|
// Match Markdown's json_list_v1 contract exactly: one literal "- " row per
// supplied event, separated by LF. Do not infer children absent from the IR.
fn rag_json_list_chunks_from_events(
  events : Array[@core.CoreEvent],
  metadata : @core.DocumentMetadata,
  diagnostics : @core.Diagnostics,
  options : @rag.RagOptions,
  record_batching~ : Bool,
) -> Array[@rag.RagChunk] {
  let window : ScalarEventRagWindow = {
    events,
    metadata,
    options: @rag.normalize_rag_options(options),
    record_batching,
    encoding: "json_list_v1",
    format: "json",
    event_prefix: "json_list",
    chars: [],
    chunks: [],
    fresh_chars: 0,
    overlap_chars: 0,
    peak_chars: 0,
  }
  for index in 0..<events.length() {
    if index > 0 {
      rag_scalar_event_write_char(window, '\n', index)
    }
    rag_scalar_event_write(window, "- ", index)
    rag_scalar_event_write(window, events[index].text, index)
  }
  rag_scalar_event_flush(window)
  diagnostics.metrics.set("rag_json_list_contract", "scalar_windows_v1")
  diagnostics.metrics.set("rag_json_list_events", events.length().to_string())
  diagnostics.metrics.set(
    "rag_json_list_window_peak_chars",
    window.peak_chars.to_string(),
  )
  window.chunks
}

///|
// The existing legacy projection includes sorted extra keys, pointer and all
// older fields. Complete it with the six added SourceRef fields. This is a
// private identity tuple, not user-facing JSON: quote Double spellings so even
// a nonfinite input reaches the existing typed serialization error boundary.
fn rag_json_list_source_identity(source : @core.SourceRef) -> String {
  let fields : Array[String] = [legacy_source_ref_identity_json(Some(source))]
  fields.push(source.page.map(value => value.to_string()).unwrap_or("null"))
  fields.push(
    match source.bbox {
      None => "null"
      Some(box) =>
        @core.array_json([
          @core.json_string(box.x0.to_string()),
          @core.json_string(box.y0.to_string()),
          @core.json_string(box.x1.to_string()),
          @core.json_string(box.y1.to_string()),
        ])
    },
  )
  fields.push(
    source.byte_start.map(value => value.to_string()).unwrap_or("null"),
  )
  fields.push(source.byte_end.map(value => value.to_string()).unwrap_or("null"))
  fields.push(@core.json_string_opt(source.time_start))
  fields.push(@core.json_string_opt(source.time_end))
  @core.array_json(fields)
}
