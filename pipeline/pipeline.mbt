///|
/// Builder abstraction that normalizes any public IR shape into `DocumentIR`
/// before pipeline passes run.
///
/// Keeping the builder injectable makes tests and specialized entry points able
/// to reuse the pass pipeline without duplicating shape-conversion logic.
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
/// assets, provenance, and assembly side channels. The `Ref` fields are
/// intentionally mutable so independent passes can collaborate without having
/// to thread large tuples through every transformation.
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
///
/// Stable pass names matter because pass traces are exported through
/// diagnostics and used in regression tests.
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
  )
  let context = make_product_pass_context(mode, options)
  context.diagnostics.val.metrics.set(
    "pdf_header_footer_filter_enabled",
    if pdf_cleanup_enabled {
      "true"
    } else {
      "false"
    },
  )
  context
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
/// Run the canonical pass pipeline for every IR shape.
pub fn run_default_pipeline(
  input : @core.IRInput,
  context : PassContext,
  trace_passes? : Bool = true,
) -> Result[@core.IRInput, PassError] {
  let selected_pipeline = default_pipeline_for_context(context)
  let output = run_pipeline_with_trace(
    selected_pipeline, input, context, trace_passes,
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
fn default_pipeline_for_context(context : PassContext) -> PassPipeline {
  if context.output_mode == @product.OutputMode::Markdown &&
    context.diagnostics.val.metrics.get("detected_format") == Some("yaml") {
    let char_count = @string.parse_int(
      context.diagnostics.val.metrics.get("char_count").unwrap_or("0"),
    ) catch {
      _ => 0
    }
    if char_count >= 1_048_576 {
      context.diagnostics.val.metrics.set(
        "pipeline_profile", "yaml_large_lowered",
      )
      return new_pass_pipeline([collect_asset_refs_pass()])
    }
  }
  if context.execution_profile == @product.ExecutionProfile::LargeAdaptive &&
    context.output_mode == @product.OutputMode::Markdown {
    match context.diagnostics.val.metrics.get("detected_format") {
      Some("markdown") => {
        context.diagnostics.val.metrics.set(
          "pipeline_profile", "markdown_large_lowered",
        )
        return new_pass_pipeline([collect_asset_refs_pass()])
      }
      Some("html") => {
        context.diagnostics.val.metrics.set(
          "pipeline_profile", "html_large_lowered",
        )
        return new_pass_pipeline([collect_asset_refs_pass()])
      }
      Some("xlsx") => {
        context.diagnostics.val.metrics.set(
          "pipeline_profile", "xlsx_large_lowered",
        )
        return new_pass_pipeline([collect_asset_refs_pass()])
      }
      Some("tex") => {
        context.diagnostics.val.metrics.set(
          "pipeline_profile", "tex_large_lowered",
        )
        return new_pass_pipeline([
          normalize_text_pass(),
          normalize_whitespace_pass(),
          collect_asset_refs_pass(),
        ])
      }
      Some(format) if ["toml", "rst", "asciidoc"].contains(format) => {
        context.diagnostics.val.metrics.set(
          "pipeline_profile",
          format + "_large_lowered",
        )
        return new_pass_pipeline([collect_asset_refs_pass()])
      }
      _ => ()
    }
  }
  context.diagnostics.val.metrics.set("pipeline_profile", "canonical")
  default_pass_pipeline()
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
