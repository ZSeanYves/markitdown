///|
/// Renderer that emits a lossier but inspection-friendly debug JSON view.
pub fn debug_json_renderer() -> Renderer {
  {
    name: "DebugJsonRenderer",
    render: fn(
      document : @core.DocumentIR,
      context : RenderContext,
    ) -> RenderResult {
      document.diagnostics.metrics.set("renderer_name", "DebugJsonRenderer")
      document.diagnostics.metrics.set(
        "applied_render_profile",
        @product.render_profile_name(context.render_profile),
      )
      {
        content: render_debug_json_document(
          profiled_document(document, context),
        ),
        diagnostics: document.diagnostics,
        chunks: None,
      }
    },
    render_input: fn(
      input : RenderInput,
      context : RenderContext,
    ) -> RenderResult {
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
) -> RenderResult {
  let renderer = debug_json_renderer()
  match input {
    Document(document) => (renderer.render)(document, context)
    BlockStream(blocks) => {
      let profiled = profiled_blocks(blocks, context)
      let diagnostics = block_stream_input_diagnostics(context, profiled)
      diagnostics.metrics.set("renderer_name", "DebugJsonRenderer")
      diagnostics.metrics.set(
        "applied_render_profile",
        @product.render_profile_name(context.render_profile),
      )
      {
        content: render_debug_json_blocks(profiled, diagnostics, context),
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
        content: render_debug_json_events(
          profiled_events(events, context),
          diagnostics,
        ),
        diagnostics,
        chunks: None,
      }
    }
  }
}

///|
/// Render a fully-built document as debug JSON.
fn render_debug_json_document(document : @core.DocumentIR) -> String {
  let block_items : Array[String] = []
  for block in document.blocks {
    block_items.push(render_block_json(block))
  }
  let asset_items : Array[String] = []
  for asset in document.assets {
    asset_items.push(render_asset_json(asset))
  }
  let fields : Array[String] = []
  fields.push("\"block_count\": " + document.blocks.length().to_string())
  fields.push("\"blocks\": " + @core.array_json(block_items))
  fields.push("\"asset_count\": " + document.assets.length().to_string())
  fields.push("\"assets\": " + @core.array_json(asset_items))
  fields.push(
    "\"diagnostics\": " + render_diagnostics_json(document.diagnostics),
  )
  @core.object_json(fields)
}
