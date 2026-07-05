///|
/// Builder abstraction that normalizes any public IR shape into `DocumentIR`
/// before pipeline passes run.
pub struct CoreIRBuilder {
  build : (@core.IRInput) -> @core.DocumentIR
}

///|
/// Lightweight pass failure returned by pipeline stages.
pub struct PassError {
  message : String
}

///|
fn pass_error(message : String) -> PassError {
  { message, }
}

///|
/// Mutable shared context passed through all IR passes.
///
/// Besides product options, it holds the evolving diagnostics, metadata,
/// assets, provenance, and assembly side channels.
pub struct PassContext {
  mode : @product.ConvertMode
  fidelity_mode : @product.FidelityMode
  output_mode : @product.OutputMode
  execution_profile : @product.ExecutionProfile
  lowering_profile : @product.LoweringProfile
  render_profile : @product.RenderProfile
  accurate_features : @product.AccurateFeatureProfile
  options : @product.ProductOptions
  diagnostics : Ref[@core.Diagnostics]
  assets : Ref[Array[@core.AssetRef]]
  metadata : Ref[@core.DocumentMetadata]
  source_map : Ref[@core.SourceMap?]
  assembly : Ref[@core.DocumentAssembly?]
}

///|
/// One named IR transformation step in the unified pipeline.
pub struct IRPass {
  name : String
  run : (PassContext, @core.IRInput) -> Result[@core.IRInput, PassError]
}

///|
/// Ordered list of IR passes to run.
pub struct PassPipeline {
  passes : Array[IRPass]
}

///|
fn make_product_pass_context(
  mode : @product.ConvertMode,
  options : @product.ProductOptions,
  execution_profile? : @product.ExecutionProfile = @product.ExecutionProfile::Standard,
  lowering_profile? : @product.LoweringProfile = @product.LoweringProfile::Canonical,
  render_profile? : @product.RenderProfile = @product.RenderProfile::DefaultMarkdown,
  accurate_features? : @product.AccurateFeatureProfile = @product.empty_accurate_feature_profile(),
  diagnostics? : @core.Diagnostics = @core.empty_diagnostics(),
  assets? : Array[@core.AssetRef] = [],
  metadata? : @core.DocumentMetadata = Map([]),
  source_map? : @core.SourceMap? = None,
  assembly? : @core.DocumentAssembly? = None,
) -> PassContext {
  {
    mode,
    fidelity_mode: options.fidelity_mode,
    output_mode: options.output_mode,
    execution_profile,
    lowering_profile,
    render_profile,
    accurate_features,
    options,
    diagnostics: Ref(diagnostics),
    assets: Ref(assets),
    metadata: Ref(metadata),
    source_map: Ref(source_map),
    assembly: Ref(assembly),
  }
}

///|
/// Construct a small pass context for tests and focused helpers.
pub fn make_pass_context(
  debug : Bool,
  mode_name : String,
  pdf_cleanup_enabled? : Bool = false,
) -> PassContext {
  let mode = match mode_name {
    "stream" => @product.ConvertMode::Stream
    "accurate" => @product.ConvertMode::Accurate
    _ => @product.ConvertMode::Balanced
  }
  let options = @product.make_product_options(
    mode,
    @product.default_resource_limits(),
    output_mode=if debug {
      @product.OutputMode::Debug
    } else {
      @product.OutputMode::Markdown
    },
    pdf_cleanup_mode=if pdf_cleanup_enabled {
      @product.PdfCleanupMode::Conservative
    } else {
      @product.PdfCleanupMode::Disabled
    },
  )
  make_product_pass_context(mode, options)
}

///|
/// Construct a fully-specified pass context from product options and existing
/// side-channel state.
pub fn make_pass_context_with_product_options(
  mode : @product.ConvertMode,
  options : @product.ProductOptions,
  execution_profile? : @product.ExecutionProfile = @product.ExecutionProfile::Standard,
  lowering_profile? : @product.LoweringProfile = @product.LoweringProfile::Canonical,
  render_profile? : @product.RenderProfile = @product.RenderProfile::DefaultMarkdown,
  accurate_features? : @product.AccurateFeatureProfile = @product.empty_accurate_feature_profile(),
  diagnostics? : @core.Diagnostics = @core.empty_diagnostics(),
  assets? : Array[@core.AssetRef] = [],
  metadata? : @core.DocumentMetadata = Map([]),
  source_map? : @core.SourceMap? = None,
  assembly? : @core.DocumentAssembly? = None,
) -> PassContext {
  make_product_pass_context(
    mode,
    options,
    execution_profile~,
    lowering_profile~,
    render_profile~,
    accurate_features~,
    diagnostics~,
    assets~,
    metadata~,
    source_map~,
    assembly~,
  )
}

///|
/// Return the default builder that turns any public IR shape into
/// `DocumentIR`.
pub fn default_ir_builder() -> CoreIRBuilder {
  {
    build: fn(input : @core.IRInput) -> @core.DocumentIR {
      ir_input_to_document(input)
    },
  }
}

///|
/// Normalize any public IR shape into `DocumentIR` and record the source shape
/// in diagnostics.
pub fn ir_input_to_document(input : @core.IRInput) -> @core.DocumentIR {
  match input {
    @core.IRInput::Document(document) => {
      let next = document
      next.diagnostics.metrics.set("builder_input_kind", "document")
      next
    }
    @core.IRInput::BlockStream(blocks) => {
      let document = @core.document_from_blocks(blocks)
      document.diagnostics.metrics.set("builder_input_kind", "block_stream")
      document
    }
    @core.IRInput::EventStream(events) => {
      let document = build_document_from_events(events)
      document.diagnostics.metrics.set("builder_input_kind", "event_stream")
      document
    }
  }
}

///|
/// Wrap a pass list into a runnable pipeline.
pub fn new_pass_pipeline(passes : Array[IRPass]) -> PassPipeline {
  { passes, }
}

///|
/// Run a pipeline and record pass trace entries by default.
pub fn run_pipeline(
  pipeline : PassPipeline,
  input : @core.IRInput,
  context : PassContext,
) -> Result[@core.IRInput, PassError] {
  run_pipeline_with_trace(pipeline, input, context, true)
}

///|
fn run_pipeline_with_trace(
  pipeline : PassPipeline,
  input : @core.IRInput,
  context : PassContext,
  trace_passes : Bool,
) -> Result[@core.IRInput, PassError] {
  let mut current = input
  for pass in pipeline.passes {
    if pass.name.trim() == "" {
      return Err(pass_error("pipeline pass must have a stable name"))
    }
    current = match (pass.run)(context, current) {
      Ok(value) => value
      Err(err) => return Err(err)
    }
    current = sync_input_to_context(context, current)
    if trace_passes {
      current = append_pass_trace(current, context, pass.name)
    }
  }
  Ok(current)
}

///|
/// Return the canonical product pass sequence.
pub fn default_pass_pipeline() -> PassPipeline {
  new_pass_pipeline([
    normalize_text_pass(),
    normalize_whitespace_pass(),
    merge_text_line_pass(),
    resolve_reading_order_pass(),
    remove_header_footer_pass(),
    resolve_heading_pass(),
    resolve_list_pass(),
    collect_asset_refs_pass(),
    resolve_table_pass(),
    resolve_caption_pass(),
    resolve_asset_pass(),
    assemble_section_tree_pass(),
    resolve_render_hints_pass(),
    debug_annotation_pass(),
  ])
}

///|
/// Run the canonical pass pipeline, including fast paths for already-structured
/// inputs.
pub fn run_default_pipeline(
  input : @core.IRInput,
  context : PassContext,
  trace_passes? : Bool = true,
) -> Result[@core.IRInput, PassError] {
  if event_stream_fast_path(input, context, trace_passes) is Some(result) {
    return Ok(result)
  }
  if block_stream_fast_path(input, context, trace_passes) is Some(result) {
    return Ok(result)
  }
  if document_fast_path(input, context, trace_passes) is Some(result) {
    return Ok(result)
  }
  let output = run_pipeline_with_trace(
    default_pass_pipeline(),
    input,
    context,
    trace_passes,
  )
  match output {
    Ok(@core.IRInput::Document(document)) => {
      context.diagnostics.val.metrics.set("builder_input_kind", "document")
      Ok(
        @core.IRInput::Document(document_from_input_context(document, context)),
      )
    }
    Ok(@core.IRInput::BlockStream(blocks)) => {
      context.diagnostics.val.metrics.set("builder_input_kind", "block_stream")
      Ok(@core.IRInput::BlockStream(blocks))
    }
    Ok(@core.IRInput::EventStream(events)) => {
      context.diagnostics.val.metrics.set("builder_input_kind", "event_stream")
      Ok(@core.IRInput::EventStream(events))
    }
    Err(err) => Err(err)
  }
}

///|
fn event_stream_fast_path(
  input : @core.IRInput,
  context : PassContext,
  trace_passes : Bool,
) -> @core.IRInput? {
  match input {
    @core.IRInput::EventStream(events) => {
      context.diagnostics.val.metrics.set("builder_input_kind", "event_stream")
      if trace_passes {
        append_event_stream_fast_path_trace(context.diagnostics.val)
      }
      Some(@core.IRInput::EventStream(events))
    }
    _ => None
  }
}

///|
fn block_stream_fast_path(
  input : @core.IRInput,
  context : PassContext,
  trace_passes : Bool,
) -> @core.IRInput? {
  match input {
    @core.IRInput::BlockStream(blocks) => {
      if !block_stream_can_skip_pipeline(context.diagnostics.val) {
        return None
      }
      context.diagnostics.val.metrics.set("builder_input_kind", "block_stream")
      if trace_passes {
        append_block_stream_fast_path_trace(context.diagnostics.val)
      }
      Some(@core.IRInput::BlockStream(blocks))
    }
    _ => None
  }
}

///|
fn document_fast_path(
  input : @core.IRInput,
  context : PassContext,
  trace_passes : Bool,
) -> @core.IRInput? {
  match input {
    @core.IRInput::Document(document) => {
      if !document_can_use_structured_profile(document.diagnostics) {
        return None
      }
      let pipeline = structured_document_pass_pipeline(document)
      let output = match
        run_pipeline_with_trace(pipeline, input, context, trace_passes) {
        Ok(value) => value
        Err(err) => abort(pass_error_message(err))
      }
      match output {
        @core.IRInput::Document(next_document) => {
          context.diagnostics.val.metrics.set("builder_input_kind", "document")
          context.diagnostics.val.metrics.set(
            "pipeline_profile", "structured_document",
          )
          if trace_passes {
            append_document_fast_path_trace(context.diagnostics.val)
          }
          Some(
            @core.IRInput::Document(
              document_from_input_context(next_document, context),
            ),
          )
        }
        _ => None
      }
    }
    _ => None
  }
}

///|
fn block_stream_can_skip_pipeline(diagnostics : @core.Diagnostics) -> Bool {
  match diagnostics.metrics.get("event_semantics") {
    Some("markdown_block_stream") => true
    Some("html_block_stream") => true
    Some("xlsx_row_block_stream") => true
    Some("archive_entry_block_stream") => true
    Some("epub_spine_block_stream") => true
    _ => false
  }
}

///|
fn document_can_use_structured_profile(diagnostics : @core.Diagnostics) -> Bool {
  diagnostics.metrics.get("structured_document_profile") ==
  Some("pipeline_ready")
}

///|
fn append_event_stream_fast_path_trace(diagnostics : @core.Diagnostics) -> Unit {
  for name in event_stream_fast_path_pass_names() {
    diagnostics.pass_trace.push(name)
  }
}

///|
fn append_block_stream_fast_path_trace(diagnostics : @core.Diagnostics) -> Unit {
  diagnostics.pass_trace.push("pipeline:block_stream_fast_path")
}

///|
fn append_document_fast_path_trace(diagnostics : @core.Diagnostics) -> Unit {
  diagnostics.pass_trace.push("pipeline:structured_document_fast_path")
}

///|
fn event_stream_fast_path_pass_names() -> Array[String] {
  [
    "NormalizeTextPass", "NormalizeWhitespacePass", "MergeTextLinePass", "ResolveReadingOrderPass",
    "RemoveHeaderFooterPass", "ResolveHeadingPass", "ResolveListPass", "CollectAssetRefsPass",
    "ResolveTablePass", "ResolveCaptionPass", "ResolveAssetPass", "AssembleSectionTreePass",
    "ResolveRenderHintsPass", "DebugAnnotationPass",
  ]
}

///|
fn structured_document_pass_pipeline(
  document : @core.DocumentIR,
) -> PassPipeline {
  let probe = inspect_structured_document(document)
  let passes : Array[IRPass] = [
    normalize_text_pass(),
    normalize_whitespace_pass(),
  ]
  if probe.needs_asset_ref_collection {
    passes.push(collect_asset_refs_pass())
  }
  if probe.has_tables {
    passes.push(resolve_table_pass())
  } else {
    document.diagnostics.metrics.set("resolved_table_continuation_count", "0")
  }
  if probe.needs_caption_resolution {
    passes.push(resolve_caption_pass())
  } else {
    document.diagnostics.metrics.set("resolved_caption_binding_count", "0")
  }
  if probe.needs_asset_resolution {
    passes.push(resolve_asset_pass())
  } else {
    document.diagnostics.metrics.set("resolved_asset_binding_count", "0")
  }
  passes.push(assemble_section_tree_pass())
  passes.push(resolve_render_hints_pass())
  passes.push(debug_annotation_pass())
  new_pass_pipeline(passes)
}

///|
priv struct StructuredDocumentProbe {
  has_tables : Bool
  has_images : Bool
  has_inline_images : Bool
  has_caption_candidates : Bool
  needs_asset_ref_collection : Bool
  needs_caption_resolution : Bool
  needs_asset_resolution : Bool
}

///|
fn inspect_structured_document(
  document : @core.DocumentIR,
) -> StructuredDocumentProbe {
  let state : Ref[StructuredDocumentProbe] = Ref({
    has_tables: false,
    has_images: false,
    has_inline_images: false,
    has_caption_candidates: false,
    needs_asset_ref_collection: false,
    needs_caption_resolution: false,
    needs_asset_resolution: false,
  })
  inspect_structured_document_blocks(document.blocks, state)
  let has_assets = document.assets.length() > 0
  let probe = state.val
  {
    ..probe,
    needs_asset_ref_collection: probe.has_images || probe.has_inline_images,
    needs_caption_resolution: probe.has_images ||
    (probe.has_tables && probe.has_caption_candidates),
    needs_asset_resolution: has_assets ||
    probe.has_images ||
    probe.has_inline_images,
  }
}

///|
fn inspect_structured_document_blocks(
  blocks : Array[@core.CoreBlock],
  state : Ref[StructuredDocumentProbe],
) -> Unit {
  let mut i = 0
  while i < blocks.length() {
    let block = blocks[i]
    if block.kind == @core.BlockKind::Table {
      state.val = { ..state.val, has_tables: true }
      if i + 1 < blocks.length() &&
        structured_document_caption_candidate(blocks[i + 1]) {
        state.val = { ..state.val, has_caption_candidates: true }
      }
    }
    if block.kind == @core.BlockKind::Image {
      state.val = { ..state.val, has_images: true }
    }
    if structured_document_block_has_inline_image(block) {
      state.val = { ..state.val, has_inline_images: true }
    }
    if block.children.length() > 0 {
      inspect_structured_document_blocks(block.children, state)
    }
    i += 1
  }
}

///|
fn structured_document_block_has_inline_image(block : @core.CoreBlock) -> Bool {
  match block.rich_inlines {
    Some(inlines) =>
      inlines.any(fn(inline) { inline.kind == @core.InlineKind::Image })
    None => false
  }
}

///|
fn structured_document_caption_candidate(block : @core.CoreBlock) -> Bool {
  if block.kind != @core.BlockKind::Paragraph {
    return false
  }
  let text = block.text.trim().to_lower()
  text.has_prefix("figure") ||
  text.has_prefix("fig.") ||
  text.has_prefix("caption") ||
  text.has_prefix("table")
}

///|
/// Convert any public IR shape into a fully synchronized `DocumentIR` by using
/// the default builder plus default pass pipeline.
pub fn build_document_with_default_pipeline(
  input : @core.IRInput,
  context : PassContext,
  trace_builder? : Bool = true,
  trace_passes? : Bool = true,
) -> @core.DocumentIR {
  let initial = if trace_builder {
    append_pass_trace(input, context, "builder:default_ir_builder")
  } else {
    input
  }
  let output = match run_default_pipeline(initial, context, trace_passes~) {
    Ok(value) => value
    Err(err) => abort(pass_error_message(err))
  }
  let document = ir_input_to_document(output)
  document_from_input_context(document, context)
}

///|
fn pass_error_message(err : PassError) -> String {
  err.message
}

///|
fn sync_document_to_context(
  context : PassContext,
  document : @core.DocumentIR,
) -> @core.DocumentIR {
  context.metadata.val = document.metadata
  context.assets.val = document.assets
  context.source_map.val = document.source_map
  context.assembly.val = document.assembly
  context.diagnostics.val = document.diagnostics
  document
}

///|
fn sync_input_to_context(
  context : PassContext,
  input : @core.IRInput,
) -> @core.IRInput {
  match input {
    @core.IRInput::Document(document) =>
      @core.IRInput::Document(sync_document_to_context(context, document))
    @core.IRInput::BlockStream(blocks) => @core.IRInput::BlockStream(blocks)
    @core.IRInput::EventStream(events) => @core.IRInput::EventStream(events)
  }
}

///|
fn append_pass_trace(
  input : @core.IRInput,
  context : PassContext,
  name : String,
) -> @core.IRInput {
  context.diagnostics.val = @core.diagnostics_add_pass_trace(
    context.diagnostics.val,
    name,
  )
  match input {
    @core.IRInput::Document(document) =>
      @core.IRInput::Document(
        @core.document_with_diagnostics(document, context.diagnostics.val),
      )
    @core.IRInput::EventStream(events) => @core.IRInput::EventStream(events)
    @core.IRInput::BlockStream(blocks) => @core.IRInput::BlockStream(blocks)
  }
}

///|
fn document_from_input_context(
  document : @core.DocumentIR,
  context : PassContext,
) -> @core.DocumentIR {
  let next = @core.document_with_metadata(document, context.metadata.val)
  let next = @core.document_with_assets(next, context.assets.val)
  let next = @core.document_with_source_map(next, context.source_map.val)
  let next = @core.document_with_assembly(next, context.assembly.val)
  @core.document_with_diagnostics(next, context.diagnostics.val)
}
