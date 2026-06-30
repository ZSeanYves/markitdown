///|
pub fn debug_json_renderer() -> Renderer {
  {
    name: "DebugJsonRenderer",
    render: fn(
      document : @core.DocumentIR,
      _context : RenderContext,
    ) -> RenderResult {
      document.diagnostics.metrics.set("renderer_name", "DebugJsonRenderer")
      {
        content: render_debug_json_document(document),
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
fn render_debug_json_input(
  input : RenderInput,
  context : RenderContext,
) -> RenderResult {
  let renderer = debug_json_renderer()
  match input {
    RenderInput::Document(document) => (renderer.render)(document, context)
    RenderInput::BlockStream(blocks) => {
      let diagnostics = block_stream_input_diagnostics(context, blocks)
      diagnostics.metrics.set("renderer_name", "DebugJsonRenderer")
      {
        content: render_debug_json_blocks(blocks, diagnostics, context),
        diagnostics,
        chunks: None,
      }
    }
    RenderInput::EventStream(events) => {
      let diagnostics = stream_input_diagnostics(
        context, events, "event_stream",
      )
      diagnostics.metrics.set("renderer_name", "DebugJsonRenderer")
      {
        content: render_debug_json_events(events, diagnostics),
        diagnostics,
        chunks: None,
      }
    }
  }
}

///|
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
