///|
pub fn markdown_renderer() -> Renderer {
  {
    name: "MarkdownRenderer",
    render: fn(
      document : @core.DocumentIR,
      _context : RenderContext,
    ) -> RenderResult {
      document.diagnostics.metrics.set("renderer_name", "MarkdownRenderer")
      {
        content: render_markdown_document(document),
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
fn render_markdown_input(
  input : RenderInput,
  context : RenderContext,
) -> RenderResult {
  let renderer = markdown_renderer()
  match input {
    RenderInput::Document(document) => (renderer.render)(document, context)
    RenderInput::BlockStream(blocks) => {
      let diagnostics = block_stream_input_diagnostics(context, blocks)
      diagnostics.metrics.set("renderer_name", "MarkdownRenderer")
      { content: render_markdown_blocks(blocks), diagnostics, chunks: None }
    }
    RenderInput::EventStream(events) => {
      let diagnostics = stream_input_diagnostics(
        context, events, "event_stream",
      )
      diagnostics.metrics.set("renderer_name", "MarkdownRenderer")
      { content: render_markdown_events(events), diagnostics, chunks: None }
    }
  }
}

///|
fn render_markdown_document(document : @core.DocumentIR) -> String {
  render_markdown_blocks(document.blocks)
}
