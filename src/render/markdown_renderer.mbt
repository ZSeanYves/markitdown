///|
/// Canonical Markdown renderer used by the main product path.
pub fn markdown_renderer() -> Renderer {
  {
    name: "MarkdownRenderer",
    render: fn(
      document : @core.DocumentIR,
      context : RenderContext,
    ) -> RenderResult {
      document.diagnostics.metrics.set("renderer_name", "MarkdownRenderer")
      document.diagnostics.metrics.set(
        "applied_render_profile",
        @product.render_profile_name(context.render_profile),
      )
      {
        content: render_markdown_document(profiled_document(document, context)),
        diagnostics: document.diagnostics,
        chunks: None,
      }
    },
    render_input: fn(
      input : RenderInput,
      context : RenderContext,
    ) -> RenderResult {
      render_markdown_input(input, context)
    },
  }
}

///|
/// Render any public input shape as Markdown while preserving direct
/// event/block fast paths.
fn render_markdown_input(
  input : RenderInput,
  context : RenderContext,
) -> RenderResult {
  let renderer = markdown_renderer()
  match input {
    Document(document) => (renderer.render)(document, context)
    BlockStream(blocks) => {
      let profiled = profiled_blocks(blocks, context)
      let diagnostics = block_stream_input_diagnostics(context, profiled)
      diagnostics.metrics.set("renderer_name", "MarkdownRenderer")
      diagnostics.metrics.set(
        "applied_render_profile",
        @product.render_profile_name(context.render_profile),
      )
      { content: render_markdown_blocks(profiled), diagnostics, chunks: None }
    }
    EventStream(events) => {
      let diagnostics = stream_input_diagnostics(
        context, events, "event_stream",
      )
      diagnostics.metrics.set("renderer_name", "MarkdownRenderer")
      diagnostics.metrics.set(
        "applied_render_profile",
        @product.render_profile_name(context.render_profile),
      )
      {
        content: render_markdown_events(profiled_events(events, context)),
        diagnostics,
        chunks: None,
      }
    }
  }
}

///|
/// Render a fully-built document as Markdown.
fn render_markdown_document(document : @core.DocumentIR) -> String {
  render_markdown_blocks(document.blocks)
}
