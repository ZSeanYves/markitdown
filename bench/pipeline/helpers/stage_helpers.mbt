///|
pub fn stage_textlike_row(bench_id : String) -> @shared.BenchManifestRow {
  stage_row_from(@shared.pipeline_smoke_textlike_rows(), bench_id)
}

///|
pub fn stage_binary_row(bench_id : String) -> @shared.BenchManifestRow {
  stage_row_from(@shared.pipeline_smoke_binary_rows(), bench_id)
}

///|
fn stage_row_from(
  rows : Array[@shared.BenchManifestRow],
  bench_id : String,
) -> @shared.BenchManifestRow {
  for row in rows {
    if row.bench_id == bench_id {
      return row
    }
  }
  abort("missing pipeline smoke row: " + bench_id)
}

///|
pub fn default_stage_detector() -> @input.FormatDetector {
  @input.default_format_detector()
}

///|
pub fn default_stage_registry() -> @parser.ParserRegistry {
  @formats.builtin_registry()
}

///|
pub fn default_stage_render_context() -> @render.RenderContext {
  @render.make_render_context(false)
}

///|
pub fn default_stage_renderer() -> @render.Renderer {
  @render.markdown_renderer()
}

///|
pub fn default_stage_pass_context() -> @mdpipeline.PassContext {
  @mdpipeline.make_pass_context(false, "balanced")
}

///|
pub fn stage_parse_context(
  detected_format : @input.DetectedFormat,
) -> @parser.ParseContext {
  let options = @convert.default_convert_options()
  @parser.parse_context_with_limits(
    @parser.new_parse_context(detected_format),
    None,
    Some(options.limits.max_rows),
    Some(options.limits.max_cols),
    Some(options.limits.max_cells),
    Some(options.limits.max_line_chars),
    false,
  )
}

///|
pub fn stage_registry_parse_or_abort(
  registry : @parser.ParserRegistry,
  source : @input.InputSource,
  parse_context : @parser.ParseContext,
  bench_id : String,
  label : String,
) -> @parser.ParseResult {
  match @parser.registry_parse(registry, source, parse_context) {
    Ok(value) => value
    Err(err) =>
      abort(label + " registry parse failed: " + bench_id + " :: " + err)
  }
}

///|
pub fn stage_parse_to_ir_input(result : @parser.ParseResult) -> @core.IRInput {
  @runtime.parse_result_to_ir_input(result)
}

///|
pub fn stage_build_document(input : @core.IRInput) -> @core.DocumentIR {
  @mdpipeline.build_document_with_default_pipeline(
    input,
    default_stage_pass_context(),
    trace_builder=false,
    trace_passes=false,
  )
}

///|
pub fn stage_render_markdown(
  document : @core.DocumentIR,
  renderer : @render.Renderer,
  render_context : @render.RenderContext,
) -> @render.RenderResult {
  (renderer.render)(document, render_context)
}

///|
pub fn stage_output_bytes(result : @render.RenderResult) -> Bytes {
  @utf8.encode(result.content)
}

///|
pub fn stage_parse_result_metric(result : @parser.ParseResult) -> Int {
  match result.document {
    Some(document) => document.blocks.length()
    None =>
      match result.block_stream {
        Some(blocks) => blocks.length()
        None =>
          match result.event_stream {
            Some(events) => events.length()
            None =>
              match result.container_manifest {
                Some(manifest) => manifest.entries.length()
                None =>
                  match result.container_plan {
                    Some(plan) => plan.ordered_entries.length()
                    None => 0
                  }
              }
          }
      }
  }
}

///|
pub fn stage_ir_input_metric(input : @core.IRInput) -> Int {
  match input {
    @core.IRInput::Document(document) => document.blocks.length()
    @core.IRInput::BlockStream(blocks) => blocks.length()
    @core.IRInput::EventStream(events) => events.length()
    @core.IRInput::ContainerManifest(manifest) => manifest.entries.length()
    @core.IRInput::ContainerPlan(plan) => plan.ordered_entries.length()
  }
}
