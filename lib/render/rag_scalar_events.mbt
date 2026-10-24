///|
// Compact XML and JSON rows carry complete labels without EndBlock events.
// Keep their format-specific writers separate and share only scalar windows.
priv struct ScalarEventRagWindow {
  events : Array[@core.CoreEvent]
  metadata : @core.DocumentMetadata
  options : @rag.RagOptions
  record_batching : Bool
  encoding : String
  format : String
  event_prefix : String
  chars : Array[(Char, Int32)]
  chunks : Array[@rag.RagChunk]
  mut fresh_chars : Int32
  mut overlap_chars : Int32
  mut peak_chars : Int32
}

///|
// Keep a single scalar window plus its event indices. This does not create
// XML nodes, a full outline String, or a second complete block tree. Returned
// chunks still follow the existing materialized RAG result contract.
fn rag_xml_outline_chunks_from_events(
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
    encoding: "xml_outline_v1",
    format: "xml",
    event_prefix: "xml_outline",
    chars: [],
    chunks: [],
    fresh_chars: 0,
    overlap_chars: 0,
    peak_chars: 0,
  }
  let mut wrote_row = false
  for index in 0..<events.length() {
    let event = events[index]
    let is_row = match event.kind {
      StartBlock(Heading) | StartBlock(ListItem) => true
      _ => event.text != ""
    }
    if !is_row {
      continue
    }
    if wrote_row {
      rag_scalar_event_write_char(window, '\n', index)
    }
    wrote_row = true
    match event.kind {
      StartBlock(Heading) => rag_scalar_event_write(window, "# ", index)
      StartBlock(ListItem) => {
        let depth = rag_xml_outline_depth(event, index)
        // Stream indentation through the same bounded window. A deep outline
        // must not allocate an entire depth-sized prefix before admission.
        for _ in 0..<depth {
          rag_scalar_event_write_char(window, ' ', index)
          rag_scalar_event_write_char(window, ' ', index)
        }
        rag_scalar_event_write(window, "- ", index)
      }
      _ => ()
    }
    rag_scalar_event_write(window, event.text, index)
  }
  rag_scalar_event_flush(window)
  diagnostics.metrics.set("rag_xml_outline_contract", "scalar_windows_v1")
  diagnostics.metrics.set("rag_xml_outline_events", events.length().to_string())
  diagnostics.metrics.set(
    "rag_xml_outline_window_peak_chars",
    window.peak_chars.to_string(),
  )
  window.chunks
}

///|
fn rag_xml_outline_depth(event : @core.CoreEvent, index : Int32) -> Int32 {
  let depth = match event.source_ref {
    Some(source) =>
      @string.parse_int(source.extra.get("xml_outline_depth").unwrap_or("0")) catch {
        _ => 0
      }
    None => 0
  }
  // A valid preorder row cannot be deeper than the number of preceding rows.
  // Malformed hints recover to depth zero without inventing a product cap.
  if depth < 0 || depth > index {
    0
  } else {
    depth
  }
}

///|
fn rag_scalar_event_write(
  window : ScalarEventRagWindow,
  text : String,
  event_index : Int32,
) -> Unit {
  for ch in text {
    rag_scalar_event_write_char(window, ch, event_index)
  }
}

///|
fn rag_scalar_event_write_char(
  window : ScalarEventRagWindow,
  ch : Char,
  event_index : Int32,
) -> Unit {
  window.chars.push((ch, event_index))
  window.fresh_chars += 1
  window.peak_chars = window.peak_chars.max(window.chars.length())
  if window.chars.length() == window.options.chunk_size {
    rag_scalar_event_flush(window)
  }
}

///|
fn rag_scalar_event_flush(window : ScalarEventRagWindow) -> Unit {
  if window.fresh_chars == 0 {
    return
  }
  let out = StringBuilder()
  let refs : Array[@core.SourceRef] = []
  let ref_keys : Array[String] = []
  let seen : Map[String, Bool] = Map([])
  let kinds : Array[String] = []
  let mut heading : Array[String]? = None
  let mut previous_event = -1
  let mut first_event = 0
  let mut last_event = 0
  for (ch, event_index) in window.chars {
    out.write_char(ch)
    if event_index == previous_event {
      continue
    }
    if previous_event == -1 {
      first_event = event_index
    }
    previous_event = event_index
    last_event = event_index
    let event = window.events[event_index]
    if window.options.preserve_source_ref {
      match event.source_ref {
        Some(source) => {
          // Preserve the XML identity projection byte for byte. The new JSON
          // path needs all fields, including lexical byte ranges and basis.
          let key = if window.format == "xml" {
            legacy_source_ref_identity_json(Some(source))
          } else {
            rag_json_list_source_identity(source)
          }
          if !seen.contains(key) {
            seen.set(key, true)
            refs.push(source)
            ref_keys.push(key)
          }
        }
        None => ()
      }
    }
    match event.kind {
      StartBlock(kind) =>
        append_unique_string(kinds, @core.block_kind_name(kind))
      _ => append_unique_string(kinds, "text")
    }
    if window.options.preserve_heading_path {
      match event.source_ref {
        Some(source) =>
          match event_source_ref_heading_path(source, window.format) {
            Some(path) =>
              heading = rag_scalar_event_common_heading(heading, path)
            None => ()
          }
        None => ()
      }
    }
  }
  let text = out.to_string()
  let heading = heading.unwrap_or([])
  let ordinal = window.chunks.length()
  let metadata = input_chunk_metadata(
    ordinal,
    text,
    heading,
    window.format,
    json_value_string(window.metadata.get("title")),
    kinds,
    refs,
    [],
  )
  metadata.set("ir_event_encoding", String(window.encoding))
  metadata.set(
    window.event_prefix + "_event_start",
    Number(first_event.to_string()),
  )
  metadata.set(
    window.event_prefix + "_event_end",
    Number((last_event + 1).to_string()),
  )
  metadata.set("overlap_char_count", Number(window.overlap_chars.to_string()))
  let chunk = @rag.make_rag_chunk(
    "text-" +
    ordinal.to_string() +
    "-" +
    short_text_hash(
      window.encoding + heading.join("/") + text + ref_keys.join("|"),
    ),
    Text,
    text,
    heading,
    refs,
    [],
    metadata,
  )
  window.chunks.push(
    if window.record_batching {
      rag_chunk_with_batch_metadata(chunk, ordinal)
    } else {
      chunk
    },
  )
  let overlap = window.options.chunk_overlap
    .min(window.options.chunk_size - 1)
    .min(window.chars.length())
  let retained = window.chars[window.chars.length() - overlap:].to_owned()
  window.chars.clear()
  window.chars.append(retained[:])
  window.fresh_chars = 0
  window.overlap_chars = overlap
}

///|
fn rag_scalar_event_common_heading(
  current : Array[String]?,
  candidate : Array[String],
) -> Array[String]? {
  match current {
    None => Some(candidate)
    Some(current) => {
      let mut end = 0
      while end < current.length() &&
            end < candidate.length() &&
            current[end] == candidate[end] {
        end += 1
      }
      Some(current[:end].to_owned())
    }
  }
}
