///|
const ODP_PARSER_NAME : String = "odp_parser"

///|
pub fn odp_parser_capability() -> @parser.ParserCapability {
  @parser.package_with_block_route_parser_capability(
    Slide,
    true,
    true,
    false,
    true,
    true,
    true,
    true,
    false,
    true,
    false,
  )
}

///|
pub fn odp_parser() -> @parser.Parser {
  let capability = odp_parser_capability()
  @parser.make_parser(ODP_PARSER_NAME, PackageSinglePass, capability, fn(
    source : @input.InputSource,
    context : @parser.ParseContext,
  ) -> Result[@parser.ParseResult, String] {
    parse_odp_document_result(source, context, capability)
  })
}

///|
fn parse_odp_document_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
  capability : @parser.ParserCapability,
) -> Result[@parser.ParseResult, String] {
  let prepared = match @dodf.prepare_odp_document_from_source(source) {
    Ok(value) => value
    Err(err) => {
      let diagnostics = @fshared.empty_parser_diagnostics(
        ODP_PARSER_NAME,
        PackageSinglePass,
        source,
        "odp",
      )
      odp_init_diagnostics(diagnostics, source, context)
      return Ok(
        odp_malformed_parse_result(
          source,
          diagnostics,
          "open odp failed: " + err,
          capability,
          @input.input_bytes(source).unwrap_or(Bytes::from_array([])),
          context,
        ),
      )
    }
  }
  Ok(
    odp_parse_with_open_document(
      prepared.prepared_source,
      context,
      prepared.document,
      prepared.inspect,
    ),
  )
}

///|
pub fn odp_parse_with_prepared_document(
  source : @input.InputSource,
  context : @parser.ParseContext,
  prepared : @dodf.PreparedOdpDocument,
) -> @parser.ParseResult {
  odp_parse_with_open_document(
    source,
    context,
    prepared.document,
    prepared.inspect,
  )
}

///|
pub fn odp_parse_with_open_document(
  source : @input.InputSource,
  context : @parser.ParseContext,
  document : @dodf.OdpDocument,
  inspect : @dodf.OdpInspectReport,
) -> @parser.ParseResult {
  let capability = odp_parser_capability()
  let diagnostics = @fshared.empty_parser_diagnostics(
    ODP_PARSER_NAME,
    PackageSinglePass,
    source,
    "odp",
  )
  odp_init_diagnostics(diagnostics, source, context)
  let bytes = @input.input_bytes(source).unwrap_or(Bytes::from_array([]))
  odp_fill_metrics(diagnostics, document, inspect, bytes)
  if context.requested_mode == Some(BlockStreaming) {
    let lowered = odp_lower_block_stream_document(source, document, context)
    diagnostics.metrics.set("parser_mode", "block_streaming")
    diagnostics.metrics.set("effective_mode", "block_streaming")
    diagnostics.metrics.set("ir_input_kind", "block_stream")
    diagnostics.metrics.set("event_granularity", "slide")
    diagnostics.metrics.set("event_semantics", "odp_slide_block_stream")
    diagnostics.metrics.set("block_count", lowered.blocks.length().to_string())
    diagnostics.metrics.set("asset_count", lowered.assets.length().to_string())
    @fshared.refresh_parser_count_metrics(diagnostics, "block_stream")
    diagnostics.pass_trace.push("parse:odp_parser:block_stream_route")
    diagnostics.pass_trace.push("lower:odp_block_stream")
    diagnostics.pass_trace.push("parse:odp_parser")
    return @parser.parse_result_with_blocks_capability(
      ODP_PARSER_NAME,
      BlockStreaming,
      lowered.blocks,
      diagnostics,
      capability,
      metadata=lowered.metadata,
      assets=lowered.assets,
      source_map=Some(lowered.source_map),
    )
  }
  let lowered = odp_lower_document_ir(source, document, context)
  diagnostics.metrics.set("parser_mode", "package_single_pass")
  diagnostics.metrics.set("effective_mode", "package_single_pass")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("event_granularity", "slide")
  diagnostics.metrics.set("event_semantics", "package_single_pass")
  diagnostics.metrics.set("block_count", lowered.blocks.length().to_string())
  diagnostics.metrics.set("asset_count", lowered.assets.length().to_string())
  @fshared.refresh_parser_count_metrics(diagnostics, "document")
  diagnostics.pass_trace.push("parse:odp_parser:package_single_pass")
  diagnostics.pass_trace.push("parse:odp_parser")
  let final_document = @core.document_with_diagnostics(lowered, diagnostics)
  @parser.parse_result_with_document_capability(
    ODP_PARSER_NAME,
    PackageSinglePass,
    final_document,
    diagnostics,
    capability,
  )
}

///|
fn odp_init_diagnostics(
  diagnostics : @core.Diagnostics,
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Unit {
  @fshared.init_parser_route_metrics(
    diagnostics,
    source,
    context,
    "odp",
    ODP_PARSER_NAME,
    PackageSinglePass,
    PackageSinglePass,
    "document",
    "slide",
    "package_single_pass",
  )
  @fshared.init_parser_product_mode_metrics(diagnostics, context)
  diagnostics.metrics.set("builder_input_kind", "document")
  diagnostics.metrics.set("office_document_kind", "odp")
  diagnostics.metrics.set("format_family", "package_document")
  diagnostics.metrics.set("product_path_enabled", "true")
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("syntax_error_count", "0")
  @fshared.init_parser_count_metrics(diagnostics)
  diagnostics.metrics.set("slide_count", "0")
  diagnostics.metrics.set("heading_count", "0")
  diagnostics.metrics.set("paragraph_count", "0")
  diagnostics.metrics.set("list_item_count", "0")
  diagnostics.metrics.set("table_count", "0")
  diagnostics.metrics.set("image_count", "0")
  diagnostics.metrics.set("notes_count", "0")
  diagnostics.metrics.set("raw_block_count", "0")
  @fshared.apply_product_metrics(diagnostics, "odp")
}

///|
fn odp_fill_metrics(
  diagnostics : @core.Diagnostics,
  document : @dodf.OdpDocument,
  inspect : @dodf.OdpInspectReport,
  bytes : Bytes,
) -> Unit {
  diagnostics.metrics.set("package_mimetype", document.package_info.mimetype)
  diagnostics.metrics.set(
    "manifest_seen",
    @fshared.bool_string(document.package_info.manifest_seen),
  )
  diagnostics.metrics.set("content_path", document.package_info.content_path)
  diagnostics.metrics.set(
    "meta_seen",
    @fshared.bool_string(document.package_info.meta_path is Some(_)),
  )
  diagnostics.metrics.set(
    "styles_seen",
    @fshared.bool_string(document.package_info.styles_path is Some(_)),
  )
  diagnostics.metrics.set("archive_bytes", bytes.length().to_string())
  diagnostics.metrics.set("slide_count", inspect.slide_count.to_string())
  diagnostics.metrics.set("heading_count", inspect.heading_count.to_string())
  diagnostics.metrics.set(
    "paragraph_count",
    inspect.paragraph_count.to_string(),
  )
  diagnostics.metrics.set(
    "list_item_count",
    inspect.list_item_count.to_string(),
  )
  diagnostics.metrics.set("table_count", inspect.table_count.to_string())
  diagnostics.metrics.set("image_count", inspect.image_count.to_string())
  diagnostics.metrics.set("notes_count", inspect.notes_count.to_string())
  diagnostics.metrics.set(
    "raw_block_count",
    inspect.raw_block_count.to_string(),
  )
}

///|
priv struct OdpLoweredProduct {
  blocks : Array[@core.CoreBlock]
  metadata : @core.DocumentMetadata
  assets : Array[@core.AssetRef]
  source_map : @core.SourceMap
}

///|
fn odp_lower_document_ir(
  source : @input.InputSource,
  document : @dodf.OdpDocument,
  context : @parser.ParseContext,
) -> @core.DocumentIR {
  let lowered = odp_lower_common(source, document, context)
  @core.document_with_source_map(
    @core.document_with_assets(
      @core.document_with_metadata(
        @core.document_with_blocks(@core.empty_document_ir(), lowered.blocks),
        lowered.metadata,
      ),
      lowered.assets,
    ),
    Some(lowered.source_map),
  )
}

///|
fn odp_lower_block_stream_document(
  source : @input.InputSource,
  document : @dodf.OdpDocument,
  context : @parser.ParseContext,
) -> OdpLoweredProduct {
  odp_lower_common(source, document, context)
}

///|
fn odp_lower_common(
  source : @input.InputSource,
  document : @dodf.OdpDocument,
  context : @parser.ParseContext,
) -> OdpLoweredProduct {
  let blocks : Array[@core.CoreBlock] = []
  let assets : Array[@core.AssetRef] = []
  let metadata = odp_metadata(document)
  let source_map = @core.empty_source_map()
  for slide in document.slides {
    let label_ref = odp_slide_source_ref(source, document, slide, None)
    let label = @core.make_block(
      Paragraph,
      "[Slide " + (slide.index + 1).to_string() + "]",
      source_ref=label_ref,
    )
    label.attrs.set("literal", "true")
    label.attrs.set("markdown_literal_raw", "true")
    label.attrs.set("slide_local", "true")
    if context.lowering_profile == AccurateSemantic &&
      @product.accurate_feature_enabled(
        context.accurate_features,
        OdpSlideSummary,
      ) {
      label.attrs.set(
        "render_window_group",
        "slide:" + (slide.index + 1).to_string(),
      )
    }
    source_map.block_entries.push(
      @core.make_source_map_entry(primary_ref=Some(label_ref), refs=[label_ref]),
    )
    blocks.push(label)
    for block in slide.blocks {
      let lowered = odp_lower_block(
        source, document, slide, block, assets, source_map, context,
      )
      blocks.push(lowered)
    }
  }
  { blocks, metadata, assets, source_map }
}

///|
fn odp_lower_block(
  source : @input.InputSource,
  document : @dodf.OdpDocument,
  slide : @dodf.OdpSlide,
  block : @dodf.OdpSlideBlock,
  assets : Array[@core.AssetRef],
  source_map : @core.SourceMap,
  context : @parser.ParseContext,
) -> @core.CoreBlock {
  let source_ref = odp_block_source_ref(source, document, slide, block)
  let lowered = match block.kind {
    Heading => @core.make_block(Heading, block.text, source_ref~)
    Paragraph => @core.make_block(Paragraph, block.text, source_ref~)
    ListItem => @core.make_block(ListItem, block.text, source_ref~)
    Notes => {
      let note = @core.make_block(Code, block.text, source_ref~)
      note.attrs.set("info", "notes")
      for entry in block.attrs.to_array() {
        note.attrs.set(entry.0, entry.1)
      }
      if context.lowering_profile == AccurateSemantic &&
        @product.accurate_feature_enabled(
          context.accurate_features,
          OdpNotesAppendix,
        ) {
        note.attrs.set("render_appendix_group", "notes")
      }
      note
    }
    Raw => {
      let raw = @core.make_block(Raw, block.text, source_ref~)
      for entry in block.attrs.to_array() {
        raw.attrs.set(entry.0, entry.1)
      }
      raw
    }
    Table => odp_table_block(block, source_ref)
    Image => odp_image_block(source, slide, block, assets, source_ref)
  }
  for entry in block.attrs.to_array() {
    lowered.attrs.set(entry.0, entry.1)
  }
  if context.lowering_profile == AccurateSemantic &&
    @product.accurate_feature_enabled(
      context.accurate_features,
      OdpSlideSummary,
    ) &&
    lowered.attrs.get("slide_local") == Some("true") {
    lowered.attrs.set(
      "render_window_group",
      "slide:" + (slide.index + 1).to_string(),
    )
  }
  source_map.block_entries.push(
    @core.make_source_map_entry(primary_ref=Some(source_ref), refs=[source_ref]),
  )
  lowered
}

///|
fn odp_table_block(
  block : @dodf.OdpSlideBlock,
  source_ref : @core.SourceRef,
) -> @core.CoreBlock {
  let table = @core.make_block(Table, "table", source_ref~)
  for row_value in block.rows {
    let row = @core.make_block(TableRow, "", source_ref~)
    for cell_value in row_value.cells {
      row.children.push(
        @core.make_block(TableCell, cell_value.text, source_ref~),
      )
    }
    table.children.push(row)
  }
  table
}

///|
fn odp_image_block(
  source : @input.InputSource,
  slide : @dodf.OdpSlide,
  block : @dodf.OdpSlideBlock,
  assets : Array[@core.AssetRef],
  source_ref : @core.SourceRef,
) -> @core.CoreBlock {
  match block.image {
    Some(image) => {
      if image.bytes is None {
        let unavailable = @core.make_block(
          BlockQuote,
          "Asset unavailable: " + image.href,
          source_ref~,
        )
        unavailable.attrs.set("asset_missing", "true")
        unavailable.attrs.set("asset_source_path", image.href)
        return unavailable
      }
      let asset_id = odp_asset_output_path(slide.index, image.href)
      let asset = @core.make_asset_ref(Image, asset_id, source_ref~)
      let next_asset = {
        ..asset,
        path: Some(asset_id),
        mime_type: image.media_type,
      }
      next_asset.attrs.set("zip_entry_path", image.href.trim().to_owned())
      match @input.input_path(source) {
        Some(path) => next_asset.attrs.set("zip_container_path", path)
        None => ()
      }
      odp_attach_asset_payload(next_asset, image)
      assets.push(next_asset)
      let out = @core.make_block(Image, "", source_ref~)
      out.attrs.set("asset_id", asset_id)
      out.attrs.set("path", asset_id)
      out.attrs.set("alt", image.alt.unwrap_or("odp image"))
      out
    }
    None => @core.make_block(Paragraph, "[image]", source_ref~)
  }
}

///|
fn odp_metadata(document : @dodf.OdpDocument) -> @core.DocumentMetadata {
  let metadata : @core.DocumentMetadata = Map([])
  metadata.set("format", String("odp"))
  metadata.set(
    "description",
    String(
      "OpenDocument presentation with " +
      document.slides.length().to_string() +
      " slides",
    ),
  )
  match document.metadata.title {
    Some(value) => metadata.set("title", String(value))
    None => ()
  }
  match document.metadata.subject {
    Some(value) => metadata.set("subject", String(value))
    None => ()
  }
  match document.metadata.language {
    Some(value) => metadata.set("language", String(value))
    None => ()
  }
  metadata
}

///|
fn odp_slide_source_ref(
  source : @input.InputSource,
  document : @dodf.OdpDocument,
  slide : @dodf.OdpSlide,
  line_start : Int?,
) -> @core.SourceRef {
  let container_path = @input.input_path(source).unwrap_or(source.source_name)
  let base = @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some(source.source_name),
    Some("odp"),
    Some(container_path),
    Some(document.package_info.content_path),
    None,
    Some("xml"),
    Some(document.package_info.content_path),
  )
  let office = @core.source_ref_with_office_fields(
    base,
    Some(source.source_name),
    Some("odp"),
    Some(document.package_info.content_path),
    None,
    None,
    Some(slide.index + 1),
    None,
    None,
  )
  let with_lines = @core.source_ref_with_lines(
    office,
    Some(source.source_name),
    Some("odp"),
    line_start,
    None,
  )
  @core.source_ref_with_extra(
    with_lines,
    "odp_slide_index",
    (slide.index + 1).to_string(),
  )
}

///|
fn odp_block_source_ref(
  source : @input.InputSource,
  document : @dodf.OdpDocument,
  slide : @dodf.OdpSlide,
  block : @dodf.OdpSlideBlock,
) -> @core.SourceRef {
  let base = odp_slide_source_ref(source, document, slide, block.line_start)
  let with_lines = @core.source_ref_with_lines(
    base,
    Some(source.source_name),
    Some("odp"),
    block.line_start,
    block.line_end,
  )
  @core.source_ref_with_extra(with_lines, "odp_xml_path", block.xml_path)
}

///|
fn odp_asset_output_path(slide_index : Int, href : String) -> String {
  let clean = href.trim().to_owned().replace_all(old="Pictures/", new="")
  "assets/odp-slide" + (slide_index + 1).to_string() + "-" + odp_slug(clean)
}

///|
fn odp_slug(text : String) -> String {
  let out : Array[Char] = []
  for ch in text.to_lower().to_array() {
    if (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') || ch == '.' {
      out.push(ch)
    } else if out.length() == 0 || out.last().unwrap_or('-') != '-' {
      out.push('-')
    }
  }
  let normalized = String::from_array(out).trim().to_owned()
  if normalized == "" {
    "asset.bin"
  } else {
    normalized
  }
}

///|
fn odp_attach_asset_payload(
  asset : @core.AssetRef,
  image : @dodf.OdpImageRef,
) -> Unit {
  match image.bytes {
    Some(bytes) =>
      if image.media_type == Some("image/svg+xml") {
        let text = @utf8.decode(bytes, ignore_bom=false) catch { _ => return }
        asset.payload = Some(Utf8(text))
      } else {
        asset.payload = Some(Bytes(bytes))
      }
    None => ()
  }
}

///|
fn odp_malformed_parse_result(
  source : @input.InputSource,
  diagnostics : @core.Diagnostics,
  err : String,
  capability : @parser.ParserCapability,
  bytes : Bytes,
  context : @parser.ParseContext,
) -> @parser.ParseResult {
  diagnostics.warnings.push("odp parse failed; returned raw fenced fallback")
  diagnostics.errors.push(err)
  diagnostics.degraded_features.push("odp_raw_fenced_fallback")
  diagnostics.fallback_trace.push("odp_raw_fenced_fallback")
  diagnostics.metrics.set("syntax_error_count", "1")
  @fshared.refresh_parser_count_metrics(
    diagnostics,
    if context.requested_mode == Some(BlockStreaming) {
      "block_stream"
    } else {
      "document"
    },
  )
  if context.requested_mode == Some(BlockStreaming) {
    diagnostics.metrics.set("parser_mode", "block_streaming")
    diagnostics.metrics.set("effective_mode", "block_streaming")
    diagnostics.metrics.set("ir_input_kind", "block_stream")
    diagnostics.metrics.set("event_semantics", "odp_slide_block_stream")
    let raw = @core.make_block(
      Code,
      "binary odp package (" + bytes.length().to_string() + " bytes)",
      source_ref=odp_fallback_source_ref(source),
    )
    raw.attrs.set("info", "odp")
    return @parser.parse_result_with_blocks_capability(
      ODP_PARSER_NAME,
      BlockStreaming,
      [raw],
      diagnostics,
      capability,
    )
  }
  let raw = @core.make_block(
    Code,
    "binary odp package (" + bytes.length().to_string() + " bytes)",
    source_ref=odp_fallback_source_ref(source),
  )
  raw.attrs.set("info", "odp")
  let document = @core.document_with_diagnostics(
    @core.document_with_blocks(@core.empty_document_ir(), [raw]),
    diagnostics,
  )
  @parser.parse_result_with_document_capability(
    ODP_PARSER_NAME,
    PackageSinglePass,
    document,
    diagnostics,
    capability,
  )
}

///|
fn odp_fallback_source_ref(source : @input.InputSource) -> @core.SourceRef {
  @core.source_ref_with_lines(
    @core.empty_source_ref(),
    Some(source.source_name),
    Some("odp"),
    None,
    None,
  )
}
