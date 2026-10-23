///|
/// Renderer that emits a lossier but inspection-friendly debug JSON view.
pub fn debug_json_renderer() -> Renderer {
  {
    name: "DebugJsonRenderer",
    render: fn(
      document : @core.DocumentIR,
      context : RenderContext,
    ) -> RenderResult raise JsonEncodingError {
      render_debug_json_input(Document(document), context)
    },
    render_input: fn(
      input : RenderInput,
      context : RenderContext,
    ) -> RenderResult raise JsonEncodingError {
      render_debug_json_input(input, context)
    },
  }
}

///|
/// Render any public input shape as debug JSON while preserving direct
/// event/block fast paths.
fn render_debug_json_input(
  input : RenderInput,
  context : RenderContext,
) -> RenderResult raise JsonEncodingError {
  let plan = prepare_debug_json_input(input, context)
  {
    content: collect_json_fragments(plan.next),
    diagnostics: plan.diagnostics,
    chunks: plan.chunks,
  }
}

///|
fn prepare_debug_json_input(
  input : RenderInput,
  context : RenderContext,
) -> JsonRenderPlan {
  match input {
    Document(document) => {
      document.diagnostics.metrics.set("renderer_name", "DebugJsonRenderer")
      document.diagnostics.metrics.set(
        "applied_render_profile",
        @product.render_profile_name(context.render_profile),
      )
      let profiled = profiled_document(document, context)
      {
        next: debug_block_json_cursor(
          profiled.blocks,
          profiled.assets,
          profiled.diagnostics,
        ),
        diagnostics: document.diagnostics,
        chunks: None,
      }
    }
    BlockStream(blocks) => {
      let profiled = profiled_blocks(blocks, context)
      let diagnostics = block_stream_input_diagnostics(context, profiled)
      diagnostics.metrics.set("renderer_name", "DebugJsonRenderer")
      diagnostics.metrics.set(
        "applied_render_profile",
        @product.render_profile_name(context.render_profile),
      )
      {
        next: debug_block_json_cursor(
          profiled,
          context.assets.unwrap_or([]),
          diagnostics,
        ),
        diagnostics,
        chunks: None,
      }
    }
    EventStream(events) => {
      let diagnostics = stream_input_diagnostics(
        context, events, "event_stream",
      )
      diagnostics.metrics.set("renderer_name", "DebugJsonRenderer")
      diagnostics.metrics.set(
        "applied_render_profile",
        @product.render_profile_name(context.render_profile),
      )
      {
        next: debug_event_json_cursor(
          profiled_events(events, context),
          diagnostics,
        ),
        diagnostics,
        chunks: None,
      }
    }
  }
}
