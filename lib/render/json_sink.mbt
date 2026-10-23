///|
/// JSON framing shared by the synchronous collector and asynchronous sink.
/// The cursor serializes one existing event, block, asset or chunk at a time.
priv struct JsonRenderPlan {
  next : () -> String? raise JsonEncodingError
  diagnostics : @core.Diagnostics
  chunks : Array[@rag.RagChunk]?
}

///|
fn collect_json_fragments(
  next : () -> String? raise JsonEncodingError,
) -> String raise JsonEncodingError {
  let out = StringBuilder()
  while true {
    match next() {
      Some(fragment) => out.write_string(fragment)
      None => break
    }
  }
  out.to_string()
}

///|
/// Emit JSON from the same fragment cursor used by collecting renderers.
/// Existing IR/chunks remain owned by this render call; no complete JSON
/// string or pending output queue is retained. Individual block trees,
/// metadata and source-map fields still use their existing serializers;
/// their allocation budgets belong to the remaining P2 resource work.
pub async fn render_json_input_to_sink(
  input : RenderInput,
  context : RenderContext,
  write : async (String) -> Result[Unit, String],
) -> Result[RenderResult, String] {
  let plan = match context.output_mode {
    Debug => prepare_debug_json_input(input, context)
    Rag => prepare_rag_json_input(input, context)
    Markdown => return Err("JSON sink requires Debug or Rag output mode")
  }
  while true {
    let fragment = (plan.next)() catch {
      NonFiniteSourceBBox(coordinate) =>
        return Err("SourceRef bbox " + coordinate + " must be finite")
    }
    match fragment {
      Some(fragment) =>
        match write(fragment) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      None => break
    }
  }
  Ok({ content: "", diagnostics: plan.diagnostics, chunks: plan.chunks, })
}
