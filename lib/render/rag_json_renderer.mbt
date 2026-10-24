///|
/// Renderer that emits chunked retrieval-oriented JSON plus optional chunk
/// metadata.
pub fn rag_json_renderer() -> Renderer {
  {
    name: "RagJsonRenderer",
    render: fn(
      document : @core.DocumentIR,
      context : RenderContext,
    ) -> RenderResult raise JsonEncodingError {
      render_rag_json_input(Document(document), context)
    },
    render_input: fn(
      input : RenderInput,
      context : RenderContext,
    ) -> RenderResult raise JsonEncodingError {
      render_rag_json_input(input, context)
    },
  }
}

///|
/// Render any public input shape as RAG JSON while keeping block/event direct
/// paths available.
fn render_rag_json_input(
  input : RenderInput,
  context : RenderContext,
) -> RenderResult raise JsonEncodingError {
  let plan = prepare_rag_json_input(input, context)
  {
    content: collect_json_fragments(plan.next),
    diagnostics: plan.diagnostics,
    chunks: plan.chunks,
  }
}

///|
fn prepare_rag_json_input(
  input : RenderInput,
  context : RenderContext,
) -> JsonRenderPlan {
  match input {
    Document(document) => {
      document.diagnostics.metrics.set("renderer_name", "RagJsonRenderer")
      document.diagnostics.metrics.set(
        "applied_render_profile",
        @product.render_profile_name(context.render_profile),
      )
      let profiled = profiled_document(document, context)
      let chunks = chunks_from_document(
        profiled,
        context.rag_options,
        record_batching=context.render_profile == RecordBatchMarkdown,
      )
      apply_rag_chunk_metrics(document.diagnostics, chunks, context)
      {
        next: rag_json_cursor(
          profiled.metadata,
          rag_payload(profiled, context, chunks),
          profiled.diagnostics,
        ),
        diagnostics: document.diagnostics,
        chunks: Some(chunks),
      }
    }
    BlockStream(blocks) => {
      let profiled = profiled_blocks(blocks, context)
      let diagnostics = block_stream_input_diagnostics(context, profiled)
      diagnostics.metrics.set("renderer_name", "RagJsonRenderer")
      diagnostics.metrics.set(
        "applied_render_profile",
        @product.render_profile_name(context.render_profile),
      )
      let metadata : @core.DocumentMetadata = match context.metadata {
        Some(value) => value
        None => Map([])
      }
      match diagnostics.detected_format {
        Some(format) =>
          if metadata.get("format") is None {
            metadata.set("format", String(format))
          }
        None => ()
      }
      let chunks = chunks_from_blocks(
        profiled,
        metadata,
        diagnostics,
        context.assets.unwrap_or([]),
        context.source_map,
        context.assembly,
        context.rag_options,
        record_batching=context.render_profile == RecordBatchMarkdown,
      )
      apply_rag_chunk_metrics(diagnostics, chunks, context)
      {
        next: rag_json_cursor(
          metadata,
          rag_payload_for_direct_input(context, chunks),
          diagnostics,
        ),
        diagnostics,
        chunks: Some(chunks),
      }
    }
    EventStream(events) => {
      let diagnostics = stream_input_diagnostics(
        context, events, "event_stream",
      )
      diagnostics.metrics.set("renderer_name", "RagJsonRenderer")
      diagnostics.metrics.set(
        "applied_render_profile",
        @product.render_profile_name(context.render_profile),
      )
      let metadata : @core.DocumentMetadata = match context.metadata {
        Some(value) => value
        None => Map([])
      }
      let normalized_metadata = event_stream_metadata(
        metadata, events, diagnostics,
      )
      let chunks = chunks_from_events(
        profiled_events(events, context),
        normalized_metadata,
        diagnostics,
        context.assets.unwrap_or([]),
        context.source_map,
        context.assembly,
        context.rag_options,
        record_batching=context.render_profile == RecordBatchMarkdown,
      )
      apply_rag_chunk_metrics(diagnostics, chunks, context)
      {
        next: rag_json_cursor(
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
/// Record chunk-oriented metrics after RAG chunking completes.
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
    if chunks.any(chunk => chunk.kind == Metadata) {
      "true"
    } else {
      "false"
    },
  )
  diagnostics.metrics.set(
    "table_chunk_split_count",
    chunk_kind_count(chunks, Table).to_string(),
  )
  diagnostics.metrics.set(
    "code_chunk_split_count",
    chunk_kind_count(chunks, Code).to_string(),
  )
  diagnostics.metrics.set(
    "rag_chunk_size",
    context.rag_options.chunk_size.to_string(),
  )
  diagnostics.metrics.set(
    "rag_chunk_overlap",
    context.rag_options.chunk_overlap.to_string(),
  )
  diagnostics.metrics.set(
    "record_batch_chunking",
    if context.render_profile == RecordBatchMarkdown {
      "true"
    } else {
      "false"
    },
  )
}
