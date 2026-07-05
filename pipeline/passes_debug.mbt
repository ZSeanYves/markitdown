///|
pub fn debug_annotation_pass() -> IRPass {
  {
    name: "DebugAnnotationPass",
    run: fn(
      context : PassContext,
      input : @core.IRInput,
    ) -> Result[@core.IRInput, PassError] {
      Ok(debug_annotation_input(context, input))
    },
  }
}

///|
fn debug_annotation_input(
  context : PassContext,
  input : @core.IRInput,
) -> @core.IRInput {
  if !@product.debug_output_mode(context.output_mode) {
    return input
  }
  context.diagnostics.val.metrics.set("debug_annotation", "enabled")
  match input {
    @core.IRInput::Document(document) =>
      @core.IRInput::Document(
        @core.document_with_diagnostics(document, context.diagnostics.val),
      )
    @core.IRInput::BlockStream(blocks) => @core.IRInput::BlockStream(blocks)
    @core.IRInput::EventStream(events) => @core.IRInput::EventStream(events)
  }
}
