///|
/// Build diagnostics for direct event-stream rendering without a full document
/// assembly step.
fn stream_input_diagnostics(
  context : RenderContext,
  events : Array[@core.CoreEvent],
  input_kind : String,
) -> @core.Diagnostics {
  let diagnostics = match context.base_diagnostics {
    Some(value) => value
    None => @core.empty_diagnostics()
  }
  diagnostics.metrics.set("render_input_kind", input_kind)
  diagnostics.metrics.set("ir_input_kind", input_kind)
  diagnostics.metrics.set("builder_input_kind", input_kind)
  diagnostics.metrics.set("stream_render_path", "true")
  diagnostics.metrics.set("event_count", events.length().to_string())
  diagnostics
}

///|
/// Build diagnostics for direct block-stream rendering without a full document
/// assembly step.
fn block_stream_input_diagnostics(
  context : RenderContext,
  blocks : Array[@core.CoreBlock],
) -> @core.Diagnostics {
  let diagnostics = match context.base_diagnostics {
    Some(value) => value
    None => @core.empty_diagnostics()
  }
  diagnostics.metrics.set("render_input_kind", "block_stream")
  diagnostics.metrics.set("ir_input_kind", "block_stream")
  diagnostics.metrics.set("builder_input_kind", "block_stream")
  diagnostics.metrics.set("stream_render_path", "true")
  diagnostics.metrics.set("block_count", blocks.length().to_string())
  diagnostics
}
