///|
fn chunks_from_document(
  document : @core.DocumentIR,
  options : @rag.RagOptions,
  record_batching? : Bool = false,
) -> Array[@rag.RagChunk] {
  if record_batching {
    return batched_chunks_from_blocks(
      document.blocks,
      document.metadata,
      document.diagnostics,
      document.assets,
      document.source_map,
      document.assembly,
      options,
    )
  }
  @rag.chunks_from_document(document, options)
}

///|
fn chunks_from_blocks(
  blocks : Array[@core.CoreBlock],
  metadata : @core.DocumentMetadata,
  diagnostics : @core.Diagnostics,
  assets : Array[@core.AssetRef],
  source_map : @core.SourceMap?,
  assembly : @core.DocumentAssembly?,
  options : @rag.RagOptions,
  record_batching? : Bool = false,
) -> Array[@rag.RagChunk] {
  if record_batching {
    return batched_chunks_from_blocks(
      blocks, metadata, diagnostics, assets, source_map, assembly, options,
    )
  }
  let document = {
    ..@core.empty_document_ir(),
    blocks,
    metadata,
    diagnostics,
    assets,
    source_map,
    assembly,
  }
  @rag.chunks_from_document(document, options)
}

///|
fn chunks_from_events(
  events : Array[@core.CoreEvent],
  metadata : @core.DocumentMetadata,
  diagnostics : @core.Diagnostics,
  assets : Array[@core.AssetRef],
  source_map : @core.SourceMap?,
  assembly : @core.DocumentAssembly?,
  options : @rag.RagOptions,
  record_batching? : Bool = false,
) -> Array[@rag.RagChunk] {
  if events.length() == 0 {
    return []
  }
  if events[0].kind == @core.EventKind::TextLine ||
    events[0].kind == @core.EventKind::BlankLine {
    return rag_text_chunks_from_events(
      events,
      metadata,
      diagnostics,
      options,
      record_batching~,
    )
  }
  if generic_block_event_stream(events) {
    let blocks = generic_blocks_from_events(events)
    let next_assembly = match assembly {
      Some(value) => value
      None => generic_event_document_assembly(blocks, metadata)
    }
    return chunks_from_blocks(
      blocks,
      metadata,
      diagnostics,
      assets,
      source_map,
      Some(next_assembly),
      options,
      record_batching~,
    )
  }
  if event_stream_contains_table_rows(events) {
    return rag_table_chunks_from_events(
      events,
      metadata,
      diagnostics,
      options,
      record_batching~,
    )
  }
  rag_text_chunks_from_generic_events(
    events,
    metadata,
    diagnostics,
    options,
    record_batching~,
  )
}

///|
fn event_stream_metadata(
  metadata : @core.DocumentMetadata,
  events : Array[@core.CoreEvent],
  diagnostics : @core.Diagnostics,
) -> @core.DocumentMetadata {
  match diagnostics.detected_format {
    Some(format) => metadata.set("format", @core.JsonValue::String(format))
    None => ()
  }
  for event in events {
    match event.source_ref {
      Some(source_ref) =>
        match source_ref.file_id {
          Some(file_id) => {
            metadata.set("source_name", @core.JsonValue::String(file_id))
            break
          }
          None => ()
        }
      None => ()
    }
  }
  metadata
}

///|
fn rag_text_chunks_from_events(
  events : Array[@core.CoreEvent],
  metadata : @core.DocumentMetadata,
  diagnostics : @core.Diagnostics,
  options : @rag.RagOptions,
  record_batching? : Bool = false,
) -> Array[@rag.RagChunk] {
  if record_batching {
    return batched_text_chunks_from_events(
      events, metadata, diagnostics, options,
    )
  }
  let refs : Array[@core.SourceRef] = []
  let parts : Array[String] = []
  let current_lines : Array[String] = []
  let current_refs : Array[@core.SourceRef] = []
  fn flush_paragraph(
    parts : Array[String],
    refs : Array[@core.SourceRef],
    current_lines : Array[String],
    current_refs : Array[@core.SourceRef],
    preserve_source_ref : Bool,
  ) -> Unit {
    if current_lines.length() == 0 {
      return
    }
    if parts.length() > 0 {
      parts.push("")
    }
    parts.push(current_lines.join(" "))
    if preserve_source_ref {
      for source_ref in current_refs {
        append_unique_source_ref(refs, Some(source_ref), true)
      }
    }
    current_lines.clear()
    current_refs.clear()
  }
  for event in events {
    match event.kind {
      @core.EventKind::TextLine => {
        current_lines.push(event.text.trim().to_owned())
        match event.source_ref {
          Some(source_ref) => current_refs.push(source_ref)
          None => ()
        }
      }
      @core.EventKind::BlankLine =>
        flush_paragraph(
          parts,
          refs,
          current_lines,
          current_refs,
          options.preserve_source_ref,
        )
      _ => ()
    }
  }
  flush_paragraph(
    parts,
    refs,
    current_lines,
    current_refs,
    options.preserve_source_ref,
  )
  if parts.length() == 0 {
    return []
  }
  let text = parts.join("\n")
  [
    make_event_rag_chunk(
      @rag.ChunkKind::Text,
      0,
      text,
      refs,
      [],
      metadata,
      diagnostics,
    ),
  ]
}

///|
fn rag_table_chunks_from_events(
  events : Array[@core.CoreEvent],
  metadata : @core.DocumentMetadata,
  diagnostics : @core.Diagnostics,
  options : @rag.RagOptions,
  record_batching? : Bool = false,
) -> Array[@rag.RagChunk] {
  if record_batching {
    return batched_table_chunks_from_events(
      events, metadata, diagnostics, options,
    )
  }
  let rows : Array[Array[String]] = []
  let refs : Array[@core.SourceRef] = []
  let current_row : Array[String] = []
  for event in events {
    match event.kind {
      @core.EventKind::Cell => {
        current_row.push(event.text)
        append_unique_source_ref(
          refs,
          event.source_ref,
          options.preserve_source_ref,
        )
      }
      @core.EventKind::RowBreak =>
        if current_row.length() > 0 {
          rows.push(current_row.copy())
          append_unique_source_ref(
            refs,
            event.source_ref,
            options.preserve_source_ref,
          )
          current_row.clear()
        }
      _ => ()
    }
  }
  if current_row.length() > 0 {
    rows.push(current_row.copy())
  }
  if rows.length() == 0 {
    return []
  }
  let width = widest_event_row_width(rows)
  let out = StringBuilder::new()
  write_markdown_table_row_from_values(out, rows[0], width)
  out.write_char('\n')
  write_markdown_table_separator(out, width)
  for i in 1..<rows.length() {
    out.write_char('\n')
    write_markdown_table_row_from_values(out, rows[i], width)
  }
  [
    make_event_rag_chunk(
      @rag.ChunkKind::Table,
      0,
      out.to_string(),
      refs,
      [],
      metadata,
      diagnostics,
    ),
  ]
}

///|
fn rag_text_chunks_from_generic_events(
  events : Array[@core.CoreEvent],
  metadata : @core.DocumentMetadata,
  diagnostics : @core.Diagnostics,
  options : @rag.RagOptions,
  record_batching? : Bool = false,
) -> Array[@rag.RagChunk] {
  if record_batching {
    return batched_generic_chunks_from_events(
      events, metadata, diagnostics, options,
    )
  }
  let refs : Array[@core.SourceRef] = []
  let texts : Array[String] = []
  let mut chunk_kind = @rag.ChunkKind::Raw
  for event in events {
    append_unique_source_ref(
      refs,
      event.source_ref,
      options.preserve_source_ref,
    )
    match event.kind {
      @core.EventKind::StartBlock(@core.BlockKind::Code) => {
        chunk_kind = @rag.ChunkKind::Code
        texts.push(event.text)
      }
      @core.EventKind::StartBlock(@core.BlockKind::Raw) => {
        chunk_kind = @rag.ChunkKind::Raw
        texts.push(event.text)
      }
      @core.EventKind::Text => texts.push(event.text)
      _ => ()
    }
  }
  if texts.length() == 0 {
    return []
  }
  [
    make_event_rag_chunk(
      chunk_kind,
      0,
      texts.join("\n"),
      refs,
      [],
      metadata,
      diagnostics,
    ),
  ]
}

///|
fn batched_chunks_from_blocks(
  blocks : Array[@core.CoreBlock],
  metadata : @core.DocumentMetadata,
  diagnostics : @core.Diagnostics,
  assets : Array[@core.AssetRef],
  source_map : @core.SourceMap?,
  assembly : @core.DocumentAssembly?,
  options : @rag.RagOptions,
) -> Array[@rag.RagChunk] {
  if blocks.length() == 0 {
    return []
  }
  let batched : Array[@rag.RagChunk] = []
  let mut ordinal = 0
  for batch in block_batches(blocks) {
    let document = {
      ..@core.empty_document_ir(),
      blocks: batch,
      metadata,
      diagnostics,
      assets,
      source_map,
      assembly,
    }
    let chunks = @rag.chunks_from_document(document, options)
    for chunk in chunks {
      batched.push(
        rag_chunk_with_batch_metadata(
          rag_chunk_with_ordinal(chunk, ordinal),
          ordinal,
        ),
      )
      ordinal += 1
    }
  }
  batched
}

///|
fn batched_text_chunks_from_events(
  events : Array[@core.CoreEvent],
  metadata : @core.DocumentMetadata,
  diagnostics : @core.Diagnostics,
  options : @rag.RagOptions,
) -> Array[@rag.RagChunk] {
  let batches = text_event_batches(events)
  if batches.length() <= 1 {
    let chunks = rag_text_chunks_from_events(
      events,
      metadata,
      diagnostics,
      options,
      record_batching=false,
    )
    if chunks.length() == 0 {
      return []
    }
    return [
      rag_chunk_with_batch_metadata(rag_chunk_with_ordinal(chunks[0], 0), 0),
    ]
  }
  let out : Array[@rag.RagChunk] = []
  let mut ordinal = 0
  for batch in batches {
    let refs : Array[@core.SourceRef] = []
    let parts : Array[String] = []
    let current_lines : Array[String] = []
    fn flush_paragraph(
      parts : Array[String],
      current_lines : Array[String],
    ) -> Unit {
      if current_lines.length() == 0 {
        return
      }
      if parts.length() > 0 {
        parts.push("")
      }
      parts.push(current_lines.join(" "))
      current_lines.clear()
    }
    for event in batch {
      match event.kind {
        @core.EventKind::TextLine =>
          current_lines.push(event.text.trim().to_owned())
        @core.EventKind::BlankLine => flush_paragraph(parts, current_lines)
        _ => ()
      }
    }
    flush_paragraph(parts, current_lines)
    let text = parts.join("\n")
    if text == "" {
      continue
    }
    for event in batch {
      append_unique_source_ref(
        refs,
        event.source_ref,
        options.preserve_source_ref,
      )
    }
    out.push(
      rag_chunk_with_batch_metadata(
        make_event_rag_chunk(
          @rag.ChunkKind::Text,
          ordinal,
          text,
          refs,
          [],
          metadata,
          diagnostics,
        ),
        ordinal,
      ),
    )
    ordinal += 1
  }
  out
}

///|
fn batched_table_chunks_from_events(
  events : Array[@core.CoreEvent],
  metadata : @core.DocumentMetadata,
  diagnostics : @core.Diagnostics,
  options : @rag.RagOptions,
) -> Array[@rag.RagChunk] {
  let rows : Array[(Array[String], Array[@core.SourceRef])] = []
  let current_row : Array[String] = []
  let current_refs : Array[@core.SourceRef] = []
  for event in events {
    match event.kind {
      @core.EventKind::Cell => {
        current_row.push(event.text)
        append_unique_source_ref(
          current_refs,
          event.source_ref,
          options.preserve_source_ref,
        )
      }
      @core.EventKind::RowBreak =>
        if current_row.length() > 0 {
          rows.push((current_row.copy(), current_refs.copy()))
          current_row.clear()
          current_refs.clear()
        }
      _ => ()
    }
  }
  if current_row.length() > 0 {
    rows.push((current_row.copy(), current_refs.copy()))
  }
  if rows.length() == 0 {
    return []
  }
  let batches = row_batches(rows)
  if batches.length() <= 1 {
    let chunks = rag_table_chunks_from_events(
      events,
      metadata,
      diagnostics,
      options,
      record_batching=false,
    )
    if chunks.length() == 0 {
      return []
    }
    return [
      rag_chunk_with_batch_metadata(rag_chunk_with_ordinal(chunks[0], 0), 0),
    ]
  }
  let width = widest_event_row_width(rows.map(entry => entry.0))
  let out : Array[@rag.RagChunk] = []
  let mut ordinal = 0
  for batch in batches {
    let buffer = StringBuilder::new()
    let refs : Array[@core.SourceRef] = []
    for index in 0..<batch.length() {
      if index > 0 {
        buffer.write_char('\n')
      }
      if index == 0 {
        write_markdown_table_row_from_values(buffer, batch[index].0, width)
        buffer.write_char('\n')
        write_markdown_table_separator(buffer, width)
      } else {
        write_markdown_table_row_from_values(buffer, batch[index].0, width)
      }
      append_unique_source_refs(refs, batch[index].1)
    }
    out.push(
      rag_chunk_with_batch_metadata(
        make_event_rag_chunk(
          @rag.ChunkKind::Table,
          ordinal,
          buffer.to_string(),
          refs,
          [],
          metadata,
          diagnostics,
        ),
        ordinal,
      ),
    )
    ordinal += 1
  }
  out
}

///|
fn batched_generic_chunks_from_events(
  events : Array[@core.CoreEvent],
  metadata : @core.DocumentMetadata,
  diagnostics : @core.Diagnostics,
  options : @rag.RagOptions,
) -> Array[@rag.RagChunk] {
  let out : Array[@rag.RagChunk] = []
  let mut ordinal = 0
  for batch in generic_event_batches(events) {
    let refs : Array[@core.SourceRef] = []
    let texts : Array[String] = []
    let mut chunk_kind = @rag.ChunkKind::Raw
    for event in batch {
      append_unique_source_ref(
        refs,
        event.source_ref,
        options.preserve_source_ref,
      )
      match event.kind {
        @core.EventKind::StartBlock(@core.BlockKind::Code) => {
          chunk_kind = @rag.ChunkKind::Code
          texts.push(event.text)
        }
        @core.EventKind::StartBlock(@core.BlockKind::Raw) => {
          chunk_kind = @rag.ChunkKind::Raw
          texts.push(event.text)
        }
        @core.EventKind::Text => texts.push(event.text)
        _ => ()
      }
    }
    if texts.length() == 0 {
      continue
    }
    out.push(
      rag_chunk_with_batch_metadata(
        make_event_rag_chunk(
          chunk_kind,
          ordinal,
          texts.join("\n"),
          refs,
          [],
          metadata,
          diagnostics,
        ),
        ordinal,
      ),
    )
    ordinal += 1
  }
  out
}

///|
fn block_batches(
  blocks : Array[@core.CoreBlock],
) -> Array[Array[@core.CoreBlock]] {
  let batches : Array[Array[@core.CoreBlock]] = []
  let current : Array[@core.CoreBlock] = []
  let mut current_group = ""
  for block in blocks {
    let group = block.attrs
      .get("render_window_group")
      .unwrap_or(block.attrs.get("render_boundary_key").unwrap_or(""))
    if current.length() > 0 && group != "" && group != current_group {
      batches.push(current.copy())
      current.clear()
    }
    current.push(block)
    if group != "" {
      current_group = group
    }
  }
  if current.length() > 0 {
    batches.push(current.copy())
  }
  if batches.length() == 0 {
    [blocks]
  } else {
    batches
  }
}

///|
fn text_event_batches(
  events : Array[@core.CoreEvent],
) -> Array[Array[@core.CoreEvent]] {
  ignore(events)
  [events]
}

///|
fn row_batches(
  rows : Array[(Array[String], Array[@core.SourceRef])],
) -> Array[Array[(Array[String], Array[@core.SourceRef])]] {
  let batches : Array[Array[(Array[String], Array[@core.SourceRef])]] = []
  let current : Array[(Array[String], Array[@core.SourceRef])] = []
  let mut current_size = 0
  for row in rows {
    let next_size = row.0.join(" ").length()
    if current.length() > 0 && current_size + next_size > 600 {
      batches.push(current.copy())
      current.clear()
      current_size = 0
    }
    current.push(row)
    current_size += next_size
  }
  if current.length() > 0 {
    batches.push(current.copy())
  }
  if batches.length() == 0 {
    [rows]
  } else {
    batches
  }
}

///|
fn generic_event_batches(
  events : Array[@core.CoreEvent],
) -> Array[Array[@core.CoreEvent]] {
  let batches : Array[Array[@core.CoreEvent]] = []
  let current : Array[@core.CoreEvent] = []
  let mut depth = 0
  for event in events {
    current.push(event)
    match event.kind {
      @core.EventKind::StartBlock(_) => depth += 1
      @core.EventKind::EndBlock(_) => {
        depth -= 1
        if depth <= 0 {
          batches.push(current.copy())
          current.clear()
          depth = 0
        }
      }
      _ => ()
    }
  }
  if current.length() > 0 {
    batches.push(current.copy())
  }
  if batches.length() == 0 {
    [events]
  } else {
    batches
  }
}

///|
fn append_unique_source_refs(
  target : Array[@core.SourceRef],
  refs : Array[@core.SourceRef],
) -> Unit {
  for source_ref in refs {
    if !target.any(existing => source_ref_eq(existing, source_ref)) {
      target.push(source_ref)
    }
  }
}

///|
fn rag_chunk_with_batch_metadata(
  chunk : @rag.RagChunk,
  batch_ordinal : Int,
) -> @rag.RagChunk {
  let metadata = chunk.metadata
  metadata.set(
    "batch_ordinal",
    @core.JsonValue::Number(batch_ordinal.to_string()),
  )
  metadata.set("record_batch_profile", @core.JsonValue::Bool(true))
  @rag.make_rag_chunk(
    chunk.id,
    chunk.kind,
    chunk.text,
    chunk.heading_path.copy(),
    chunk.source_refs.copy(),
    chunk.asset_refs.copy(),
    metadata,
  )
}

///|
fn rag_chunk_with_ordinal(
  chunk : @rag.RagChunk,
  ordinal : Int,
) -> @rag.RagChunk {
  let metadata = chunk.metadata
  metadata.set("ordinal", @core.JsonValue::Number(ordinal.to_string()))
  @rag.make_rag_chunk(
    rag_chunk_id_with_ordinal(chunk.id, ordinal),
    chunk.kind,
    chunk.text,
    chunk.heading_path.copy(),
    chunk.source_refs.copy(),
    chunk.asset_refs.copy(),
    metadata,
  )
}

///|
fn rag_chunk_id_with_ordinal(id : String, ordinal : Int) -> String {
  match id.split_once("-") {
    Some((prefix, suffix)) =>
      match suffix.split_once("-") {
        Some((_, tail)) =>
          prefix.to_owned() + "-" + ordinal.to_string() + "-" + tail.to_owned()
        None => id
      }
    None => id
  }
}

///|
fn generic_event_document_assembly(
  blocks : Array[@core.CoreBlock],
  metadata : @core.DocumentMetadata,
) -> @core.DocumentAssembly {
  let assembly = @core.empty_document_assembly()
  let document_format = metadata
    .get("format")
    .map(value => json_value_string(Some(value)).unwrap_or(""))
    .unwrap_or("")
  for block in blocks {
    ignore(
      generic_event_block_heading_paths(
        assembly.heading_paths,
        block,
        document_format,
      ),
    )
  }
  assembly
}

///|
fn generic_event_block_heading_paths(
  heading_paths : Map[String, Array[String]],
  block : @core.CoreBlock,
  document_format : String,
) -> Array[String]? {
  let mut best : Array[String]? = None
  for child in block.children {
    match
      generic_event_block_heading_paths(heading_paths, child, document_format) {
      Some(path) =>
        match best {
          Some(current) =>
            if path.length() > current.length() {
              best = Some(path)
            }
          None => best = Some(path)
        }
      None => ()
    }
  }
  match block.source_ref {
    Some(source_ref) =>
      match event_source_ref_heading_path(source_ref, document_format) {
        Some(path) if path.length() > 0 =>
          match best {
            Some(current) =>
              if path.length() >= current.length() {
                best = Some(path)
              }
            None => best = Some(path)
          }
        _ => ()
      }
    None => ()
  }
  match best {
    Some(path) => {
      heading_paths.set(block.block_id, path)
      Some(path)
    }
    None => None
  }
}

///|
fn make_event_rag_chunk(
  kind : @rag.ChunkKind,
  ordinal : Int,
  text : String,
  refs : Array[@core.SourceRef],
  asset_refs : Array[String],
  metadata : @core.DocumentMetadata,
  diagnostics : @core.Diagnostics,
) -> @rag.RagChunk {
  let document_format = metadata
    .get("format")
    .map(value => json_value_string(Some(value)).unwrap_or(""))
    .unwrap_or(diagnostics.detected_format.unwrap_or(""))
  let effective_refs = refs.copy()
  let heading_path = event_chunk_heading_path(effective_refs, document_format)
  let chunk_metadata = input_chunk_metadata(
    ordinal,
    text,
    heading_path,
    document_format,
    None,
    [@rag.chunk_kind_name(kind)],
    effective_refs,
    asset_refs,
  )
  @rag.make_rag_chunk(
    event_chunk_id(kind, ordinal, text, heading_path, effective_refs),
    kind,
    text,
    heading_path,
    effective_refs,
    asset_refs.copy(),
    chunk_metadata,
  )
}

///|
fn event_chunk_heading_path(
  refs : Array[@core.SourceRef],
  document_format : String,
) -> Array[String] {
  for source_ref in refs {
    match event_source_ref_heading_path(source_ref, document_format) {
      Some(path) => if path.length() > 0 { return path }
      None => ()
    }
  }
  []
}

///|
fn event_source_ref_heading_path(
  source_ref : @core.SourceRef,
  document_format : String,
) -> Array[String]? {
  match document_format {
    "json" =>
      match source_ref.json_pointer {
        Some(pointer) => Some(preferred_structural_heading_path(pointer, '/'))
        None => None
      }
    "yaml" =>
      match source_ref.yaml_path {
        Some(path) => Some(preferred_structural_heading_path(path, '/'))
        None => None
      }
    "xml" =>
      match source_ref.xpath {
        Some(path) => Some(preferred_structural_heading_path(path, '/'))
        None => None
      }
    _ => None
  }
}

///|
fn preferred_structural_heading_path(
  path : String,
  delimiter : Char,
) -> Array[String] {
  let parts = split_structural_path(path, delimiter)
  if parts.length() <= 1 {
    return parts
  }
  let parent = parts[:parts.length() - 1].to_owned()
  if parent.length() == 0 {
    parts
  } else {
    parent
  }
}

///|
fn split_structural_path(path : String, delimiter : Char) -> Array[String] {
  let out : Array[String] = []
  let current : Array[Char] = []

  fn flush_segment(
    out : Array[String],
    current : Array[Char],
    delimiter : Char,
  ) -> Unit {
    if current.length() == 0 {
      return
    }
    let segment = String::from_array(current)
    current.clear()
    if segment == "" || segment == "/" || segment == "." {
      return
    }
    if segment == "*" {
      return
    }
    if segment.has_prefix("[") && segment.has_suffix("]") {
      return
    }
    if delimiter == '.' && segment == "-" {
      return
    }
    let cleaned = structural_segment_label(segment)
    if cleaned != "" {
      out.push(cleaned)
    }
  }

  for ch in path.to_array() {
    if ch == delimiter {
      flush_segment(out, current, delimiter)
    } else {
      current.push(ch)
    }
  }
  flush_segment(out, current, delimiter)
  out
}

///|
fn structural_segment_label(segment : String) -> String {
  if segment.has_prefix("{") && segment.has_suffix("}") {
    return segment[1:segment.length() - 1].to_owned()
  }
  if segment.has_prefix("@") {
    return segment
  }
  if segment.has_prefix("[") && segment.has_suffix("]") {
    return ""
  }
  let trimmed = segment.trim().to_owned()
  if trimmed == "-" || trimmed == "/" || trimmed == "." {
    return ""
  }
  trimmed
}

///|
fn event_chunk_id(
  kind : @rag.ChunkKind,
  ordinal : Int,
  text : String,
  heading_path : Array[String],
  refs : Array[@core.SourceRef],
) -> String {
  @rag.chunk_kind_name(kind) +
  "-" +
  ordinal.to_string() +
  "-" +
  short_text_hash(
    @rag.chunk_kind_name(kind) +
    heading_path.join("/") +
    text +
    refs.map(source_ref => source_ref_signature(source_ref)).join("|"),
  )
}

///|
fn short_text_hash(text : String) -> String {
  let mut acc = 5381
  for ch in text.to_array() {
    acc = (acc * 33 + ch.to_int()) % 100000000
  }
  let raw = acc.to_string()
  if raw.length() >= 8 {
    raw
  } else {
    Array::make(8 - raw.length(), "0").join("") + raw
  }
}

///|
fn rag_chunk_text_total_chars(chunks : Array[@rag.RagChunk]) -> Int {
  let mut total = 0
  for chunk in chunks {
    total += unicode_char_count(chunk.text)
  }
  total
}

///|
fn append_unique_source_ref(
  refs : Array[@core.SourceRef],
  source_ref : @core.SourceRef?,
  enabled : Bool,
) -> Unit {
  if !enabled {
    return
  }
  match source_ref {
    Some(value) =>
      if !refs.any(existing => source_ref_eq(existing, value)) {
        refs.push(value)
      }
    None => ()
  }
}

///|
fn source_ref_eq(left : @core.SourceRef, right : @core.SourceRef) -> Bool {
  source_ref_signature(left) == source_ref_signature(right)
}

///|
fn input_chunk_location_metadata(
  source_refs : Array[@core.SourceRef],
) -> Map[String, @core.JsonValue] {
  let pages : Array[String] = []
  let slides : Array[String] = []
  let sheets : Array[String] = []
  let cell_ranges : Array[String] = []
  let entry_paths : Array[String] = []
  let container_paths : Array[String] = []
  let chapter_hrefs : Array[String] = []
  for source_ref in source_refs {
    append_unique_optional_string(
      pages,
      source_ref.page.map(i => i.to_string()),
    )
    append_unique_optional_string(
      slides,
      source_ref.slide.map(i => i.to_string()),
    )
    append_unique_optional_string(sheets, source_ref.sheet)
    append_unique_optional_string(cell_ranges, source_ref.cell_range)
    append_unique_optional_string(entry_paths, source_ref.entry_path)
    append_unique_optional_string(container_paths, source_ref.container_path)
    append_unique_optional_string(chapter_hrefs, source_ref.chapter_href)
  }
  let metadata : Map[String, @core.JsonValue] = Map([])
  if pages.length() > 0 {
    metadata.set("pages", string_json_array(pages))
  }
  if slides.length() > 0 {
    metadata.set("slides", string_json_array(slides))
  }
  if sheets.length() > 0 {
    metadata.set("sheets", string_json_array(sheets))
  }
  if cell_ranges.length() > 0 {
    metadata.set("cell_ranges", string_json_array(cell_ranges))
  }
  if entry_paths.length() > 0 {
    metadata.set("entry_paths", string_json_array(entry_paths))
  }
  if container_paths.length() > 0 {
    metadata.set("container_paths", string_json_array(container_paths))
  }
  if chapter_hrefs.length() > 0 {
    metadata.set("chapter_hrefs", string_json_array(chapter_hrefs))
  }
  metadata
}

///|
fn input_chunk_metadata(
  ordinal : Int,
  text : String,
  heading_path : Array[String],
  document_format : String,
  document_title : String?,
  block_kinds : Array[String],
  source_refs : Array[@core.SourceRef],
  asset_refs : Array[String],
) -> Map[String, @core.JsonValue] {
  let metadata : Map[String, @core.JsonValue] = Map([])
  metadata.set("ordinal", @core.JsonValue::Number(ordinal.to_string()))
  metadata.set(
    "char_count",
    @core.JsonValue::Number(unicode_char_count(text).to_string()),
  )
  metadata.set(
    "heading_depth",
    @core.JsonValue::Number(heading_path.length().to_string()),
  )
  metadata.set("document_format", @core.JsonValue::String(document_format))
  match document_title {
    Some(title) if title.trim() != "" =>
      metadata.set("document_title", @core.JsonValue::String(title))
    _ => ()
  }
  metadata.set("block_kinds", string_json_array(block_kinds))
  metadata.set(
    "source_count",
    @core.JsonValue::Number(source_refs.length().to_string()),
  )
  metadata.set(
    "asset_count",
    @core.JsonValue::Number(asset_refs.length().to_string()),
  )
  metadata.set(
    "location",
    @core.JsonValue::Object(input_chunk_location_metadata(source_refs)),
  )
  metadata
}

///|
fn append_unique_optional_string(
  values : Array[String],
  value : String?,
) -> Unit {
  match value {
    Some(text) if text.trim() != "" => append_unique_string(values, text)
    _ => ()
  }
}

///|
fn append_unique_string(values : Array[String], value : String) -> Unit {
  if !values.any(existing => existing == value) {
    values.push(value)
  }
}

///|
fn string_json_array(values : Array[String]) -> @core.JsonValue {
  @core.JsonValue::Array(values.map(value => @core.JsonValue::String(value)))
}

///|
fn json_value_string(value : @core.JsonValue?) -> String? {
  match value {
    Some(@core.JsonValue::String(text)) => Some(text)
    Some(@core.JsonValue::Number(text)) => Some(text)
    Some(@core.JsonValue::Bool(flag)) =>
      Some(if flag { "true" } else { "false" })
    _ => None
  }
}

///|
fn unicode_char_count(text : String) -> Int {
  text.to_array().length()
}

///|
fn source_ref_signature(source_ref : @core.SourceRef) -> String {
  [
    source_ref.file_id.unwrap_or(""),
    source_ref.format.unwrap_or(""),
    source_ref.page.map(i => i.to_string()).unwrap_or(""),
    source_ref.slide.map(i => i.to_string()).unwrap_or(""),
    source_ref.sheet.unwrap_or(""),
    source_ref.cell_range.unwrap_or(""),
    source_ref.entry_path.unwrap_or(""),
    source_ref.container_path.unwrap_or(""),
    source_ref.chapter_href.unwrap_or(""),
    source_ref.line_start.map(i => i.to_string()).unwrap_or(""),
    source_ref.line_end.map(i => i.to_string()).unwrap_or(""),
  ].join("|")
}
