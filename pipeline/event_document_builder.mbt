///|
pub fn build_document_from_events(
  events : Array[@core.CoreEvent],
) -> @core.DocumentIR {
  @core.build_document_from_events(events)
}
