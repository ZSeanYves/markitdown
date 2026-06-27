///|
pub struct CoreIRBuilder {
  build : (@core.IRInput) -> @core.DocumentIR
}

///|
pub struct PassError {
  message : String
}

///|
fn pass_error(message : String) -> PassError {
  { message, }
}

///|
pub struct PassContext {
  mode : @product.ConvertMode
  options : @product.ProductOptions
  diagnostics : Ref[@core.Diagnostics]
  assets : Ref[Array[@core.AssetRef]]
  metadata : Ref[@core.DocumentMetadata]
  source_map : Ref[@core.SourceMap?]
  assembly : Ref[@core.DocumentAssembly?]
}

///|
pub struct IRPass {
  name : String
  run : (PassContext, @core.IRInput) -> Result[@core.IRInput, PassError]
}

///|
pub struct PassPipeline {
  passes : Array[IRPass]
}

///|
fn make_product_pass_context(
  mode : @product.ConvertMode,
  options : @product.ProductOptions,
  diagnostics? : @core.Diagnostics = @core.empty_diagnostics(),
  assets? : Array[@core.AssetRef] = [],
  metadata? : @core.DocumentMetadata = Map([]),
  source_map? : @core.SourceMap? = None,
  assembly? : @core.DocumentAssembly? = None,
) -> PassContext {
  {
    mode,
    options,
    diagnostics: Ref(diagnostics),
    assets: Ref(assets),
    metadata: Ref(metadata),
    source_map: Ref(source_map),
    assembly: Ref(assembly),
  }
}

///|
pub fn make_pass_context(
  debug : Bool,
  mode_name : String,
  pdf_cleanup_enabled? : Bool = false,
) -> PassContext {
  let mode = match mode_name {
    "debug" => @product.ConvertMode::Debug
    "rag" => @product.ConvertMode::Rag
    "stream" => @product.ConvertMode::Stream
    "accurate" => @product.ConvertMode::Accurate
    "fast" => @product.ConvertMode::Fast
    _ =>
      if debug {
        @product.ConvertMode::Debug
      } else {
        @product.ConvertMode::Balanced
      }
  }
  let options = @product.make_product_options(
    mode,
    @product.default_resource_limits(),
    pdf_cleanup_mode=if pdf_cleanup_enabled {
      @product.PdfCleanupMode::Conservative
    } else {
      @product.PdfCleanupMode::Disabled
    },
  )
  make_product_pass_context(mode, options)
}

///|
pub fn make_pass_context_with_product_options(
  mode : @product.ConvertMode,
  options : @product.ProductOptions,
  diagnostics? : @core.Diagnostics = @core.empty_diagnostics(),
  assets? : Array[@core.AssetRef] = [],
  metadata? : @core.DocumentMetadata = Map([]),
  source_map? : @core.SourceMap? = None,
  assembly? : @core.DocumentAssembly? = None,
) -> PassContext {
  make_product_pass_context(
    mode,
    options,
    diagnostics~,
    assets~,
    metadata~,
    source_map~,
    assembly~,
  )
}

///|
pub fn default_ir_builder() -> CoreIRBuilder {
  {
    build: fn(input : @core.IRInput) -> @core.DocumentIR {
      ir_input_to_document(input)
    },
  }
}

///|
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
pub fn new_pass_pipeline(passes : Array[IRPass]) -> PassPipeline {
  { passes, }
}

///|
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
    debug_annotation_pass(),
  ])
}

///|
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
fn event_stream_fast_path_pass_names() -> Array[String] {
  [
    "NormalizeTextPass", "NormalizeWhitespacePass", "MergeTextLinePass", "ResolveReadingOrderPass",
    "RemoveHeaderFooterPass", "ResolveHeadingPass", "ResolveListPass", "CollectAssetRefsPass",
    "ResolveTablePass", "ResolveCaptionPass", "ResolveAssetPass", "AssembleSectionTreePass",
    "DebugAnnotationPass",
  ]
}

///|
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
