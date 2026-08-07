///|
fn legacy_convert_mode(mode : ConvertMode) -> @product.ConvertMode {
  match mode {
    Balanced => Balanced
    Accurate => Accurate
    Stream => Stream
  }
}

///|
fn legacy_output_mode(mode : OutputMode) -> @product.OutputMode {
  match mode {
    Markdown => Markdown
    Debug => Debug
    Rag => Rag
  }
}

///|
fn legacy_ocr_options(mode : OcrMode, language : String?) -> @parser.OcrOptions {
  match mode {
    Auto => @parser.default_ocr_options()
    Enabled => @parser.explicit_ocr_options(language~)
    Disabled => @parser.disabled_ocr_options(language~)
  }
}

///|
fn validate_options(options : ConvertOptions) -> Result[Unit, ConvertError] {
  if options.limits.max_rows <= 0 ||
    options.limits.max_cols <= 0 ||
    options.limits.max_cells <= 0 ||
    options.limits.max_line_chars <= 0 {
    return Err(InvalidOption("resource limits must be positive"))
  }
  if options.limits.max_input_bytes <= 0L ||
    options.limits.max_asset_bytes <= 0L ||
    options.limits.max_total_asset_bytes <= 0L ||
    options.limits.external_command_timeout_ms <= 0 ||
    options.limits.max_external_output_bytes <= 0L {
    return Err(InvalidOption("byte and timeout limits must be positive"))
  }
  if options.rag.chunk_size <= 0 ||
    options.rag.chunk_overlap < 0 ||
    options.rag.chunk_overlap >= options.rag.chunk_size {
    return Err(
      InvalidOption(
        "RAG overlap must be non-negative and smaller than chunk size",
      ),
    )
  }
  match options.format_hint {
    Some(value) if @input.parse_detected_format(value) == Unknown =>
      Err(InvalidOption("unsupported format hint: " + value))
    _ => Ok(())
  }
}

///|
fn legacy_options(
  options : ConvertOptions,
) -> Result[@convert.ConvertOptions, ConvertError] {
  match validate_options(options) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let format = options.format_hint.map(value => {
    @input.parse_detected_format(value)
  })
  let limits = @product.make_resource_limits(
    options.limits.max_rows,
    options.limits.max_cols,
    options.limits.max_cells,
    max_line_chars=options.limits.max_line_chars,
    max_input_bytes=options.limits.max_input_bytes,
    max_asset_bytes=options.limits.max_asset_bytes,
    max_total_asset_bytes=options.limits.max_total_asset_bytes,
    external_command_timeout_ms=options.limits.external_command_timeout_ms,
    max_external_output_bytes=options.limits.max_external_output_bytes,
  )
  let rag = @rag.make_rag_options(
    options.rag.chunk_size,
    options.rag.chunk_overlap,
    options.rag.preserve_heading_path,
    options.rag.preserve_source_ref,
    options.rag.split_tables,
    options.rag.split_code_blocks,
  )
  Ok(
    @convert.make_convert_options(
      legacy_convert_mode(options.mode),
      legacy_output_mode(options.output_mode),
      format,
      legacy_ocr_options(options.ocr_mode, options.ocr_language),
      limits,
      audio_options=@parser.explicit_audio_options(
        language=options.audio_language,
      ),
      rag_options=rag,
    ),
  )
}

///|
fn stable_convert_mode(mode : @product.ConvertMode) -> ConvertMode {
  match mode {
    Balanced => Balanced
    Accurate => Accurate
    Stream => Stream
  }
}

///|
fn stable_output_mode(mode : @product.OutputMode) -> OutputMode {
  match mode {
    Markdown => Markdown
    Debug => Debug
    Rag => Rag
  }
}

///|
fn json_value_string(value : @core.JsonValue) -> String {
  match value {
    String(text) => @core.json_string(text)
    Number(text) => text
    Bool(flag) => if flag { "true" } else { "false" }
    Null => "null"
    Array(items) => @core.array_json(items.map(item => json_value_string(item)))
    Object(fields) => metadata_json(fields)
  }
}

///|
fn metadata_json(metadata : Map[String, @core.JsonValue]) -> String {
  let fields : Array[String] = []
  let entries = metadata.to_array()
  entries.sort_by(fn(a, b) { a.0[:].lexical_compare(b.0[:]) })
  for entry in entries {
    fields.push(@core.json_string(entry.0) + ": " + json_value_string(entry.1))
  }
  @core.object_json(fields)
}

///|
fn stable_diagnostics(diagnostics : @core.Diagnostics) -> Array[Diagnostic] {
  let output : Array[Diagnostic] = []
  for message in diagnostics.warnings {
    output.push({ code: "MID-WARNING", severity: Warning, message })
  }
  for message in diagnostics.errors {
    output.push({ code: "MID-ERROR", severity: Error, message })
  }
  for message in diagnostics.degraded_features {
    output.push({ code: "MID-DEGRADED", severity: Warning, message })
  }
  for message in diagnostics.same_mode_degradation {
    output.push({ code: "MID-MODE-DEGRADED", severity: Warning, message })
  }
  for dependency in diagnostics.dependency_diagnostics {
    output.push({
      code: "MID-DEPENDENCY",
      severity: match dependency.status {
        Missing => Error
        Available | Degraded => Warning
      },
      message: dependency.summary,
    })
  }
  output
}

///|
fn stable_provenance(provenance : @convert.ConvertProvenance) -> Provenance {
  {
    detected_format: @input.detected_format_name(
      provenance.route_plan.detected_format,
    ),
    selected_route: provenance.route_plan.selected_route,
    route_reason: provenance.route_plan.route_reason,
    parser_mode: @parser.mode_name(provenance.effective_parser_mode),
    fidelity_mode: @product.fidelity_mode_name(provenance.fidelity_mode),
    output_mode: @product.output_mode_name(provenance.output_mode),
    execution_profile: @product.execution_profile_name(
      provenance.execution_profile,
    ),
    lowering_profile: @product.lowering_profile_name(
      provenance.lowering_profile,
    ),
    render_profile: @product.render_profile_name(provenance.render_profile),
    route_fidelity_status: provenance.route_fidelity_status,
    applied_accurate_features: provenance.applied_accurate_features.copy(),
    strategy_switches: provenance.same_mode_strategy_switches.copy(),
  }
}

///|
fn stable_bbox(bbox : @core.BBox?) -> BoundingBox? {
  bbox.map(value => { x0: value.x0, y0: value.y0, x1: value.x1, y1: value.y1 })
}

///|
fn stable_source_ref(source_ref : @core.SourceRef) -> SourceRef {
  {
    file_id: source_ref.file_id,
    format: source_ref.format,
    page: source_ref.page,
    bbox: stable_bbox(source_ref.bbox),
    line_start: source_ref.line_start,
    line_end: source_ref.line_end,
    byte_start: source_ref.byte_start,
    byte_end: source_ref.byte_end,
    time_start: source_ref.time_start,
    time_end: source_ref.time_end,
    xpath: source_ref.xpath,
    json_pointer: source_ref.json_pointer,
    yaml_path: source_ref.yaml_path,
    html_path: source_ref.html_path,
    markdown_path: source_ref.markdown_path,
    container_path: source_ref.container_path,
    entry_path: source_ref.entry_path,
    entry_index: source_ref.entry_index,
    entry_format: source_ref.entry_format,
    inner_path: source_ref.inner_path,
    sheet: source_ref.sheet,
    cell_range: source_ref.cell_range,
    slide: source_ref.slide,
    shape_id: source_ref.shape_id,
    relationship_id: source_ref.relationship_id,
    chapter_href: source_ref.chapter_href,
    extra: source_ref.extra.copy(),
  }
}

///|
fn stable_source_ref_option(source_ref : @core.SourceRef?) -> SourceRef? {
  source_ref.map(value => stable_source_ref(value))
}

///|
fn stable_source_map_entry(entry : @core.SourceMapEntry) -> SourceMapEntry {
  {
    primary_ref: stable_source_ref_option(entry.primary_ref),
    refs: entry.refs.map(value => stable_source_ref(value)),
    merged_from: entry.merged_from.map(value => stable_source_ref(value)),
    confidence: entry.confidence,
    relation: entry.relation,
  }
}

///|
fn stable_source_map(source_map : @core.SourceMap?) -> SourceMap? {
  source_map.map(value => {
    document_ref: stable_source_ref_option(value.document_ref),
    block_entries: value.block_entries.map(entry => {
      stable_source_map_entry(entry)
    }),
    asset_entries: value.asset_entries.map(entry => {
      stable_source_map_entry(entry)
    }),
  })
}

///|
fn stable_asset_kind(kind : @core.AssetKind) -> AssetKind {
  match kind {
    Image => Image
    Attachment => Attachment
    Link => Link
    Embedded => Embedded
    Unknown => Unknown
  }
}

///|
fn stable_asset_payload(payload : @core.AssetPayload?) -> AssetPayload? {
  payload.map(value => {
    match value {
      Bytes(bytes) => Bytes(bytes)
      Utf8(text) => Utf8(text)
      SourcePath(path) => SourcePath(path)
    }
  })
}

///|
fn stable_assets(assets : Array[@core.AssetRef]) -> Array[Asset] {
  assets.map(asset => {
    kind: stable_asset_kind(asset.asset_kind),
    id: asset.asset_id,
    path: asset.path,
    mime_type: asset.mime_type,
    source_ref: stable_source_ref_option(asset.source_ref),
    payload: stable_asset_payload(asset.payload),
    attrs: asset.attrs.copy(),
  })
}

///|
fn stable_chunks(chunks : Array[@rag.RagChunk]?) -> Array[Chunk] {
  match chunks {
    None => []
    Some(values) =>
      values.map(chunk => {
        id: chunk.id,
        kind: @rag.chunk_kind_name(chunk.kind),
        text: chunk.text,
        heading_path: chunk.heading_path.copy(),
        source_refs: chunk.source_refs.map(value => stable_source_ref(value)),
        asset_refs: chunk.asset_refs.copy(),
        metadata_json: metadata_json(chunk.metadata),
      })
  }
}

///|
fn stable_output(execution : @convert.ConvertExecution) -> Output {
  let result = execution.result
  {
    content: result.content,
    detected_format: @input.detected_format_name(result.detected_format),
    convert_mode: stable_convert_mode(result.convert_mode),
    output_mode: stable_output_mode(result.output_mode),
    metadata_json: metadata_json(result.metadata),
    diagnostics: stable_diagnostics(result.diagnostics),
    provenance: stable_provenance(execution.provenance),
    assets: stable_assets(result.assets),
    source_map: stable_source_map(result.source_map),
    chunks: stable_chunks(result.chunks),
  }
}
