///|
/// Rendering context shared by Markdown, debug JSON, and RAG JSON renderers.
///
/// The context mirrors the product-level execution choices plus optional
/// side-channel document state for direct block/event rendering.
/// `base_diagnostics`, `metadata`, `source_map`, `assets`, and `assembly`
/// allow renderers to keep outputs aligned with the document-level state even
/// when they start from blocks or events.
pub struct RenderContext {
  debug : Bool
  fidelity_mode : @product.FidelityMode
  output_mode : @product.OutputMode
  execution_profile : @product.ExecutionProfile
  render_profile : @product.RenderProfile
  accurate_features : @product.AccurateFeatureProfile
  rag_options : @rag.RagOptions
  base_diagnostics : @core.Diagnostics?
  metadata : @core.DocumentMetadata?
  source_map : @core.SourceMap?
  assets : Array[@core.AssetRef]?
  assembly : @core.DocumentAssembly?
}

///|
/// Public render input shapes accepted by renderer front doors.
pub(all) enum RenderInput {
  EventStream(Array[@core.CoreEvent])
  BlockStream(Array[@core.CoreBlock])
  Document(@core.DocumentIR)
}

///|
/// Final renderer output including diagnostics and optional RAG chunks.
///
/// `content` is the serialized user-facing payload, while `chunks` is only
/// populated for RAG-oriented views that emit a secondary retrieval structure.
pub struct RenderResult {
  content : String
  diagnostics : @core.Diagnostics
  chunks : Array[@rag.RagChunk]?
}

///|
/// Renderer interface used by the high-level convert path.
///
/// `render` consumes a full `DocumentIR`; `render_input` accepts the broader
/// public input union and is responsible for any necessary normalization.
pub struct Renderer {
  name : String
  render : (@core.DocumentIR, RenderContext) -> RenderResult
  render_input : (RenderInput, RenderContext) -> RenderResult
}

///|
/// Construct a render context with safe product defaults.
pub fn make_render_context(
  debug : Bool,
  fidelity_mode? : @product.FidelityMode = @product.FidelityMode::Balanced,
  output_mode? : @product.OutputMode = @product.OutputMode::Markdown,
  execution_profile? : @product.ExecutionProfile = @product.ExecutionProfile::Standard,
  render_profile? : @product.RenderProfile = @product.RenderProfile::DefaultMarkdown,
  accurate_features? : @product.AccurateFeatureProfile = @product.empty_accurate_feature_profile(),
  rag_options? : @rag.RagOptions = @rag.default_rag_options(),
  base_diagnostics? : @core.Diagnostics? = None,
  metadata? : @core.DocumentMetadata? = None,
  source_map? : @core.SourceMap? = None,
  assets? : Array[@core.AssetRef]? = None,
  assembly? : @core.DocumentAssembly? = None,
) -> RenderContext {
  {
    debug,
    fidelity_mode,
    output_mode,
    execution_profile,
    render_profile,
    accurate_features,
    rag_options,
    base_diagnostics,
    metadata,
    source_map,
    assets,
    assembly,
  }
}
