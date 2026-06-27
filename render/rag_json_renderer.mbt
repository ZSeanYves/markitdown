///|
pub fn rag_json_renderer() -> Renderer {
  {
    name: "RagJsonRenderer",
    render: fn(
      document : @core.DocumentIR,
      context : RenderContext,
    ) -> RenderResult {
      document.diagnostics.metrics.set("renderer_name", "RagJsonRenderer")
      let chunks = @rag.chunks_from_document(document, context.rag_options)
      apply_rag_chunk_metrics(document.diagnostics, chunks, context)
      {
        content: render_rag_json_document(
          document,
          rag_payload(document, context, chunks),
        ),
        diagnostics: document.diagnostics,
        chunks: Some(chunks),
      }
    },
    render_input: fn(
      input : RenderInput,
      context : RenderContext,
    ) -> RenderResult {
      render_rag_json_input(input, context)
    },
  }
}

///|
fn render_rag_json_input(
  input : RenderInput,
  context : RenderContext,
) -> RenderResult {
  let renderer = rag_json_renderer()
  match input {
    RenderInput::Document(document) => (renderer.render)(document, context)
    RenderInput::BlockStream(blocks) => {
      let diagnostics = block_stream_input_diagnostics(context, blocks)
      diagnostics.metrics.set("renderer_name", "RagJsonRenderer")
      let metadata : @core.DocumentMetadata = match context.metadata {
        Some(value) => value
        None => Map([])
      }
      match diagnostics.detected_format {
        Some(format) =>
          if metadata.get("format") is None {
            metadata.set("format", @core.JsonValue::String(format))
          }
        None => ()
      }
      let chunks = chunks_from_blocks(
        blocks,
        metadata,
        diagnostics,
        context.assets.unwrap_or([]),
        context.source_map,
        context.assembly,
        context.rag_options,
      )
      apply_rag_chunk_metrics(diagnostics, chunks, context)
      {
        content: render_rag_json_events(
          metadata,
          rag_payload_for_direct_input(context, chunks),
          diagnostics,
        ),
        diagnostics,
        chunks: Some(chunks),
      }
    }
    RenderInput::EventStream(events) => {
      let diagnostics = stream_input_diagnostics(
        context, events, "event_stream",
      )
      diagnostics.metrics.set("renderer_name", "RagJsonRenderer")
      let metadata : @core.DocumentMetadata = match context.metadata {
        Some(value) => value
        None => Map([])
      }
      let normalized_metadata = event_stream_metadata(
        metadata, events, diagnostics,
      )
      let chunks = chunks_from_events(
        events,
        normalized_metadata,
        diagnostics,
        context.assets.unwrap_or([]),
        context.source_map,
        context.assembly,
        context.rag_options,
      )
      apply_rag_chunk_metrics(diagnostics, chunks, context)
      {
        content: render_rag_json_events(
          normalized_metadata,
          rag_payload_for_direct_input(context, chunks),
          diagnostics,
        ),
        diagnostics,
        chunks: Some(chunks),
      }
    }
  }
}

///|
fn apply_rag_chunk_metrics(
  diagnostics : @core.Diagnostics,
  chunks : Array[@rag.RagChunk],
  context : RenderContext,
) -> Unit {
  diagnostics.metrics.set("chunk_count", chunks.length().to_string())
  diagnostics.metrics.set(
    "chunk_text_total_chars",
    rag_chunk_text_total_chars(chunks).to_string(),
  )
  diagnostics.metrics.set(
    "metadata_chunk_emitted",
    if chunks.any(chunk => chunk.kind == @rag.ChunkKind::Metadata) {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set(
    "table_chunk_split_count",
    chunk_kind_count(chunks, @rag.ChunkKind::Table).to_string(),
  )
  diagnostics.metrics.set(
    "code_chunk_split_count",
    chunk_kind_count(chunks, @rag.ChunkKind::Code).to_string(),
  )
  diagnostics.metrics.set(
    "rag_chunk_size",
    context.rag_options.chunk_size.to_string(),
  )
  diagnostics.metrics.set(
    "rag_chunk_overlap",
    context.rag_options.chunk_overlap.to_string(),
  )
}

///|
fn render_rag_json_document(
  document : @core.DocumentIR,
  payload : RagRenderPayload,
) -> String {
  let asset_items : Array[String] = []
  for asset in document.assets {
    asset_items.push(render_asset_json(asset))
  }
  let chunk_items : Array[String] = []
  for chunk in payload.chunks {
    chunk_items.push(render_rag_chunk_json(chunk))
  }
  let fields : Array[String] = []
  fields.push("\"output_format\": " + @core.json_string("rag_json"))
  fields.push(
    "\"detected_format\": " +
    @core.json_string_opt(document.diagnostics.detected_format),
  )
  fields.push(
    "\"parser_mode\": " +
    @core.json_string_opt(document.diagnostics.parser_mode),
  )
  fields.push(
    "\"convert_mode\": " +
    @core.json_string_opt(document.diagnostics.convert_mode),
  )
  fields.push(
    "\"metadata\": " + render_document_metadata_json(document.metadata),
  )
  fields.push("\"assets\": " + @core.array_json(asset_items))
  fields.push(
    "\"diagnostics\": " + render_diagnostics_json(document.diagnostics),
  )
  fields.push(
    "\"source_map\": " + render_source_map_json(payload.public_source_map),
  )
  fields.push("\"chunks\": " + @core.array_json(chunk_items))
  @core.object_json(fields)
}
