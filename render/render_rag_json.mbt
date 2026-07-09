///|
priv struct RagRenderPayload {
  public_source_map : @core.SourceMap?
  chunks : Array[@rag.RagChunk]
}

///|
fn rag_payload(
  document : @core.DocumentIR,
  context : RenderContext,
  chunks : Array[@rag.RagChunk],
) -> RagRenderPayload {
  {
    public_source_map: if context.rag_options.preserve_source_ref {
      document.source_map
    } else {
      None
    },
    chunks,
  }
}

///|
fn rag_payload_for_direct_input(
  context : RenderContext,
  chunks : Array[@rag.RagChunk],
) -> RagRenderPayload {
  {
    public_source_map: if context.rag_options.preserve_source_ref {
      context.source_map
    } else {
      None
    },
    chunks,
  }
}

///|
fn render_rag_json_events(
  metadata : @core.DocumentMetadata,
  payload : RagRenderPayload,
  diagnostics : @core.Diagnostics,
) -> String {
  let chunk_items : Array[String] = []
  for chunk in payload.chunks {
    chunk_items.push(render_rag_chunk_json(chunk))
  }
  let fields : Array[String] = []
  fields.push("\"output_format\": " + @core.json_string("rag_json"))
  fields.push(
    "\"detected_format\": " + @core.json_string_opt(diagnostics.detected_format),
  )
  fields.push(
    "\"parser_mode\": " + @core.json_string_opt(diagnostics.parser_mode),
  )
  fields.push(
    "\"convert_mode\": " + @core.json_string_opt(diagnostics.convert_mode),
  )
  fields.push(
    "\"fidelity_mode\": " + @core.json_string_opt(diagnostics.fidelity_mode),
  )
  fields.push(
    "\"output_mode\": " + @core.json_string_opt(diagnostics.output_mode),
  )
  fields.push("\"metadata\": " + render_document_metadata_json(metadata))
  fields.push("\"assets\": []")
  fields.push("\"diagnostics\": " + render_diagnostics_json(diagnostics))
  fields.push(
    "\"source_map\": " + render_source_map_json(payload.public_source_map),
  )
  fields.push("\"chunks\": " + @core.array_json(chunk_items))
  @core.object_json(fields)
}

///|
fn render_rag_chunk_json(chunk : @rag.RagChunk) -> String {
  let fields : Array[String] = []
  fields.push("\"id\": " + @core.json_string(chunk.id))
  fields.push(
    "\"kind\": " + @core.json_string(@rag.chunk_kind_name(chunk.kind)),
  )
  fields.push("\"text\": " + @core.json_string(chunk.text))
  fields.push(
    "\"heading_path\": " + @core.string_array_json(chunk.heading_path),
  )
  let source_refs : Array[String] = []
  for source_ref in chunk.source_refs {
    source_refs.push(render_source_ref_json(Some(source_ref)))
  }
  fields.push("\"source_refs\": " + @core.array_json(source_refs))
  fields.push("\"asset_refs\": " + @core.string_array_json(chunk.asset_refs))
  fields.push("\"metadata\": " + render_document_metadata_json(chunk.metadata))
  @core.object_json(fields)
}

///|
fn chunk_kind_count(
  chunks : Array[@rag.RagChunk],
  kind : @rag.ChunkKind,
) -> Int {
  let mut count = 0
  for chunk in chunks {
    if chunk.kind == kind {
      count += 1
    }
  }
  count
}
