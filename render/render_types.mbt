///|
pub struct RenderContext {
  debug : Bool
  rag_options : @rag.RagOptions
  base_diagnostics : @core.Diagnostics?
  metadata : @core.DocumentMetadata?
  source_map : @core.SourceMap?
  assets : Array[@core.AssetRef]?
  assembly : @core.DocumentAssembly?
}

///|
pub(all) enum RenderInput {
  EventStream(Array[@core.CoreEvent])
  BlockStream(Array[@core.CoreBlock])
  Document(@core.DocumentIR)
}

///|
pub struct RenderResult {
  content : String
  diagnostics : @core.Diagnostics
  chunks : Array[@rag.RagChunk]?
}

///|
pub struct Renderer {
  name : String
  render : (@core.DocumentIR, RenderContext) -> RenderResult
  render_input : (RenderInput, RenderContext) -> RenderResult
}

///|
pub fn make_render_context(
  debug : Bool,
  rag_options? : @rag.RagOptions = @rag.default_rag_options(),
  base_diagnostics? : @core.Diagnostics? = None,
  metadata? : @core.DocumentMetadata? = None,
  source_map? : @core.SourceMap? = None,
  assets? : Array[@core.AssetRef]? = None,
  assembly? : @core.DocumentAssembly? = None,
) -> RenderContext {
  {
    debug,
    rag_options,
    base_diagnostics,
    metadata,
    source_map,
    assets,
    assembly,
  }
}
