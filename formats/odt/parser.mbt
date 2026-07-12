///|
const ODT_PARSER_NAME : String = "odt_parser"

///|
pub fn odt_parser_capability() -> @parser.ParserCapability {
  @parser.package_with_block_route_parser_capability(
    @parser.StreamingGranularity::Block,
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
pub fn odt_parser() -> @parser.Parser {
  let capability = odt_parser_capability()
  @parser.make_parser(
    ODT_PARSER_NAME,
    @parser.ParserMode::PackageSinglePass,
    capability,
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      parse_odt_document_result(source, context, capability)
    },
  )
}

///|
pub fn odt_route_preflight_summary(
  source : @input.InputSource,
) -> Result[OdtPreflightSummary, String] {
  let prepared = match @dodf.prepare_odt_document_from_source(source) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  match prepared.document {
    value => Ok(odt_preflight_summary_from_document(value))
  }
}

///|
pub fn odt_parse_with_prepared_document(
  source : @input.InputSource,
  context : @parser.ParseContext,
  prepared : @dodf.PreparedOdtDocument,
) -> @parser.ParseResult {
  odt_parse_with_open_document(
    source,
    context,
    prepared.document,
    prepared.inspect,
  )
}

///|
fn parse_odt_with_prepared_result(
  prepared : @dodf.PreparedOdtDocument,
  context : @parser.ParseContext,
  capability : @parser.ParserCapability,
) -> @parser.ParseResult {
  let source = prepared.prepared_source
  let diagnostics = @fshared.empty_parser_diagnostics(
    ODT_PARSER_NAME,
    @parser.ParserMode::PackageSinglePass,
    source,
    "odt",
  )
  odt_init_diagnostics(diagnostics, source, context)
  odt_fill_metrics(
    diagnostics,
    prepared.document,
    prepared.inspect,
    source.bytes.unwrap_or(Bytes::from_array([])),
  )
  if context.requested_mode == Some(@parser.ParserMode::BlockStreaming) {
    let lowered = odt_lower_block_stream_document(
      source,
      prepared.document,
      context,
    )
    diagnostics.metrics.set("parser_mode", "block_streaming")
    diagnostics.metrics.set("effective_mode", "block_streaming")
    diagnostics.metrics.set("ir_input_kind", "block_stream")
    diagnostics.metrics.set("event_granularity", "block")
    diagnostics.metrics.set("event_semantics", "odt_block_stream")
    diagnostics.metrics.set("block_count", lowered.blocks.length().to_string())
    diagnostics.metrics.set("asset_count", lowered.assets.length().to_string())
    @fshared.refresh_parser_count_metrics(diagnostics, "block_stream")
    diagnostics.pass_trace.push("parse:odt_parser:block_stream_route")
    diagnostics.pass_trace.push("lower:odt_block_stream")
    diagnostics.pass_trace.push("parse:odt_parser")
    return @parser.parse_result_with_blocks_capability(
      ODT_PARSER_NAME,
      @parser.ParserMode::BlockStreaming,
      lowered.blocks,
      diagnostics,
      capability,
      metadata=lowered.metadata,
      assets=lowered.assets,
      source_map=lowered.source_map,
    )
  }
  let lowered = odt_lower_document_ir(source, prepared.document, context)
  diagnostics.metrics.set("parser_mode", "package_single_pass")
  diagnostics.metrics.set("effective_mode", "package_single_pass")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("event_granularity", "block")
  diagnostics.metrics.set("event_semantics", "package_single_pass")
  diagnostics.metrics.set("block_count", lowered.blocks.length().to_string())
  diagnostics.metrics.set("asset_count", lowered.assets.length().to_string())
  @fshared.refresh_parser_count_metrics(diagnostics, "document")
  diagnostics.pass_trace.push("parse:odt_parser:package_single_pass")
  diagnostics.pass_trace.push("parse:odt_parser")
  let final_document = @core.document_with_diagnostics(lowered, diagnostics)
  @parser.parse_result_with_document_capability(
    ODT_PARSER_NAME,
    @parser.ParserMode::PackageSinglePass,
    final_document,
    diagnostics,
    capability,
  )
}

///|
fn odt_prepare_failure_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
  capability : @parser.ParserCapability,
  err : String,
) -> @parser.ParseResult {
  let diagnostics = @fshared.empty_parser_diagnostics(
    ODT_PARSER_NAME,
    @parser.ParserMode::PackageSinglePass,
    source,
    "odt",
  )
  odt_init_diagnostics(diagnostics, source, context)
  odt_malformed_parse_result(
    source,
    diagnostics,
    "open odt failed: " + err,
    capability,
    source.bytes.unwrap_or(Bytes::from_array([])),
    context,
  )
}

///|
pub struct OdtPreflightSummary {
  block_count : Int
  heading_count : Int
  table_count : Int
  image_count : Int
  note_count : Int
  comment_count : Int
  max_heading_level : Int
}

///|
fn parse_odt_document_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
  capability : @parser.ParserCapability,
) -> Result[@parser.ParseResult, String] {
  let prepared = match @dodf.prepare_odt_document_from_source(source) {
    Ok(value) => value
    Err(err) =>
      return Ok(odt_prepare_failure_result(source, context, capability, err))
  }
  Ok(parse_odt_with_prepared_result(prepared, context, capability))
}

///|
pub fn odt_parse_with_open_document(
  source : @input.InputSource,
  context : @parser.ParseContext,
  document : @dodf.OdtDocument,
  inspect : @dodf.OdtInspectReport,
) -> @parser.ParseResult {
  let capability = odt_parser_capability()
  let diagnostics = @fshared.empty_parser_diagnostics(
    ODT_PARSER_NAME,
    @parser.ParserMode::PackageSinglePass,
    source,
    "odt",
  )
  odt_init_diagnostics(diagnostics, source, context)
  let bytes = source.bytes.unwrap_or(Bytes::from_array([]))
  odt_fill_metrics(diagnostics, document, inspect, bytes)
  if context.requested_mode == Some(@parser.ParserMode::BlockStreaming) {
    let lowered = odt_lower_block_stream_document(source, document, context)
    diagnostics.metrics.set("parser_mode", "block_streaming")
    diagnostics.metrics.set("effective_mode", "block_streaming")
    diagnostics.metrics.set("ir_input_kind", "block_stream")
    diagnostics.metrics.set("event_granularity", "block")
    diagnostics.metrics.set("event_semantics", "odt_block_stream")
    diagnostics.metrics.set("block_count", lowered.blocks.length().to_string())
    diagnostics.metrics.set("asset_count", lowered.assets.length().to_string())
    @fshared.refresh_parser_count_metrics(diagnostics, "block_stream")
    diagnostics.pass_trace.push("parse:odt_parser:block_stream_route")
    diagnostics.pass_trace.push("lower:odt_block_stream")
    diagnostics.pass_trace.push("parse:odt_parser")
    return @parser.parse_result_with_blocks_capability(
      ODT_PARSER_NAME,
      @parser.ParserMode::BlockStreaming,
      lowered.blocks,
      diagnostics,
      capability,
      metadata=lowered.metadata,
      assets=lowered.assets,
      source_map=lowered.source_map,
    )
  }
  let lowered = odt_lower_document_ir(source, document, context)
  diagnostics.metrics.set("parser_mode", "package_single_pass")
  diagnostics.metrics.set("effective_mode", "package_single_pass")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("event_granularity", "block")
  diagnostics.metrics.set("event_semantics", "package_single_pass")
  diagnostics.metrics.set("block_count", lowered.blocks.length().to_string())
  diagnostics.metrics.set("asset_count", lowered.assets.length().to_string())
  @fshared.refresh_parser_count_metrics(diagnostics, "document")
  diagnostics.pass_trace.push("parse:odt_parser:package_single_pass")
  diagnostics.pass_trace.push("parse:odt_parser")
  let final_document = @core.document_with_diagnostics(lowered, diagnostics)
  @parser.parse_result_with_document_capability(
    ODT_PARSER_NAME,
    @parser.ParserMode::PackageSinglePass,
    final_document,
    diagnostics,
    capability,
  )
}

///|
fn odt_init_diagnostics(
  diagnostics : @core.Diagnostics,
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Unit {
  @fshared.init_parser_route_metrics(
    diagnostics,
    source,
    context,
    "odt",
    ODT_PARSER_NAME,
    @parser.ParserMode::PackageSinglePass,
    @parser.ParserMode::PackageSinglePass,
    "document",
    "block",
    "package_single_pass",
  )
  @fshared.init_parser_product_mode_metrics(diagnostics, context)
  diagnostics.metrics.set("builder_input_kind", "document")
  diagnostics.metrics.set("office_document_kind", "odt")
  diagnostics.metrics.set("format_family", "package_document")
  diagnostics.metrics.set("product_path_enabled", "true")
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("syntax_error_count", "0")
  @fshared.init_parser_count_metrics(diagnostics)
  diagnostics.metrics.set("table_count", "0")
  diagnostics.metrics.set("image_count", "0")
  diagnostics.metrics.set("heading_count", "0")
  diagnostics.metrics.set("paragraph_count", "0")
  diagnostics.metrics.set("list_item_count", "0")
  diagnostics.metrics.set("code_block_count", "0")
  diagnostics.metrics.set("raw_block_count", "0")
  @fshared.apply_product_metrics(diagnostics, "odt")
}

///|
fn odt_fill_metrics(
  diagnostics : @core.Diagnostics,
  document : @dodf.OdtDocument,
  inspect : @dodf.OdtInspectReport,
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
  diagnostics.metrics.set("block_count", inspect.block_count.to_string())
  diagnostics.metrics.set("heading_count", inspect.heading_count.to_string())
  diagnostics.metrics.set(
    "paragraph_count",
    inspect.paragraph_count.to_string(),
  )
  diagnostics.metrics.set(
    "list_item_count",
    inspect.list_item_count.to_string(),
  )
  diagnostics.metrics.set(
    "code_block_count",
    inspect.code_block_count.to_string(),
  )
  diagnostics.metrics.set(
    "raw_block_count",
    inspect.raw_block_count.to_string(),
  )
  diagnostics.metrics.set("table_count", inspect.table_count.to_string())
  diagnostics.metrics.set("image_count", inspect.image_count.to_string())
  diagnostics.metrics.set("note_count", inspect.note_count.to_string())
  diagnostics.metrics.set("comment_count", inspect.comment_count.to_string())
  diagnostics.metrics.set(
    "max_heading_level",
    inspect.max_heading_level.to_string(),
  )
}

///|
fn odt_lower_document_ir(
  source : @input.InputSource,
  document : @dodf.OdtDocument,
  context : @parser.ParseContext,
) -> @core.DocumentIR {
  let metadata = odt_metadata(source, document)
  let lowered = odt_lower_common(source, document, context)
  @core.document_with_source_map(
    @core.document_with_assets(
      @core.document_with_metadata(
        @core.document_with_blocks(@core.empty_document_ir(), lowered.blocks),
        metadata,
      ),
      lowered.assets,
    ),
    Some(lowered.source_map),
  )
}

///|
fn odt_lower_block_stream_document(
  source : @input.InputSource,
  document : @dodf.OdtDocument,
  context : @parser.ParseContext,
) -> @core.DocumentIR {
  let metadata = odt_metadata(source, document)
  let lowered = odt_lower_common(source, document, context)
  @core.document_with_source_map(
    @core.document_with_assets(
      @core.document_with_metadata(
        @core.document_with_blocks(@core.empty_document_ir(), lowered.blocks),
        metadata,
      ),
      lowered.assets,
    ),
    Some(lowered.source_map),
  )
}

///|
priv struct OdtLoweredProduct {
  blocks : Array[@core.CoreBlock]
  assets : Array[@core.AssetRef]
  source_map : @core.SourceMap
}

///|
priv struct PendingOdtNote {
  id : String
  kind : String
  note_id : String
  marker : String
  body : String
}

///|
priv struct PendingOdtComment {
  comment_id : String
  marker : String
  body : String
}

///|
fn odt_lower_common(
  source : @input.InputSource,
  document : @dodf.OdtDocument,
  context : @parser.ParseContext,
) -> OdtLoweredProduct {
  let blocks : Array[@core.CoreBlock] = []
  let assets : Array[@core.AssetRef] = []
  let source_map = @core.empty_source_map()
  let appended_note_ids : Array[String] = []
  let pending_notes : Array[PendingOdtNote] = []
  let appended_comment_ids : Array[String] = []
  let pending_comments : Array[PendingOdtComment] = []
  for block in document.blocks {
    let lowered = odt_lower_block(source, block, assets, source_map, context)
    blocks.push(lowered)
    odt_collect_notes(block, appended_note_ids, pending_notes)
    odt_collect_comments(block, appended_comment_ids, pending_comments)
  }
  for note in pending_notes {
    let note_block = odt_note_definition_block(source, note, context)
    blocks.push(note_block)
    let note_ref = note_block.source_ref.unwrap_or(@core.empty_source_ref())
    source_map.block_entries.push(
      @core.make_source_map_entry(primary_ref=Some(note_ref), refs=[note_ref]),
    )
  }
  if pending_comments.length() > 0 {
    let heading_ref = @core.source_ref_with_lines(
      @core.empty_source_ref(),
      Some(source.source_name),
      Some("odt"),
      None,
      None,
    )
    let heading = @core.make_block(
      @core.BlockKind::Heading,
      "Comments",
      source_ref=heading_ref,
    )
    heading.attrs.set("level", "2")
    heading.attrs.set("appendix_kind", "comments")
    heading.attrs.set("appendix_ready", "true")
    if context.lowering_profile == @product.LoweringProfile::AccurateSemantic &&
      @product.accurate_feature_enabled(
        context.accurate_features,
        @product.AccurateFeature::OdtCommentsAppendix,
      ) {
      heading.attrs.set("render_appendix_group", "comments")
    }
    blocks.push(heading)
    source_map.block_entries.push(
      @core.make_source_map_entry(primary_ref=Some(heading_ref), refs=[
        heading_ref,
      ]),
    )
    for comment in pending_comments {
      let comment_block = odt_comment_definition_block(source, comment, context)
      blocks.push(comment_block)
      let comment_ref = comment_block.source_ref.unwrap_or(
        @core.empty_source_ref(),
      )
      source_map.block_entries.push(
        @core.make_source_map_entry(primary_ref=Some(comment_ref), refs=[
          comment_ref,
        ]),
      )
    }
  }
  { blocks, assets, source_map }
}

///|
fn odt_lower_block(
  source : @input.InputSource,
  block : @dodf.OdtBlock,
  assets : Array[@core.AssetRef],
  source_map : @core.SourceMap,
  context : @parser.ParseContext,
) -> @core.CoreBlock {
  let source_ref = odt_source_ref(source, block)
  let lowered = match block.kind {
    @dodf.OdtBlockKind::Heading =>
      odt_block_with_inlines(
        @core.make_block(@core.BlockKind::Heading, block.text, source_ref~),
        block,
        source_ref,
      )
    @dodf.OdtBlockKind::Paragraph =>
      odt_block_with_inlines(
        @core.make_block(@core.BlockKind::Paragraph, block.text, source_ref~),
        block,
        source_ref,
      )
    @dodf.OdtBlockKind::ListItem => {
      let item = odt_block_with_inlines(
        @core.make_block(@core.BlockKind::ListItem, block.text, source_ref~),
        block,
        source_ref,
      )
      match block.list_depth {
        Some(depth) => item.attrs.set("list_depth", depth.to_string())
        None => ()
      }
      item
    }
    @dodf.OdtBlockKind::Code => {
      let code = odt_block_with_inlines(
        @core.make_block(@core.BlockKind::Code, block.text, source_ref~),
        block,
        source_ref,
      )
      code.attrs.set("info", "text")
      code
    }
    @dodf.OdtBlockKind::Raw =>
      odt_block_with_inlines(
        @core.make_block(@core.BlockKind::Raw, block.text, source_ref~),
        block,
        source_ref,
      )
    @dodf.OdtBlockKind::NoteDefinition =>
      odt_note_definition_block(
        source,
        {
          id: "1",
          kind: "footnote",
          note_id: "note-1",
          marker: "[^1]",
          body: block.text,
        },
        context,
      )
    @dodf.OdtBlockKind::Table => odt_table_block(block, source_ref, context)
    @dodf.OdtBlockKind::Image =>
      odt_image_block(source, block, assets, source_ref)
  }
  source_map.block_entries.push(
    @core.make_source_map_entry(primary_ref=Some(source_ref), refs=[source_ref]),
  )
  lowered
}

///|
fn odt_block_with_inlines(
  block0 : @core.CoreBlock,
  odt_block : @dodf.OdtBlock,
  source_ref : @core.SourceRef,
) -> @core.CoreBlock {
  let rich = odt_rich_inlines(odt_block, source_ref)
  if rich.length() == 0 {
    block0
  } else {
    @core.block_with_rich_inlines(block0, Some(rich))
  }
}

///|
fn odt_rich_inlines(
  block : @dodf.OdtBlock,
  source_ref : @core.SourceRef,
) -> Array[@core.CoreInline] {
  let out : Array[@core.CoreInline] = []
  for inline in block.inlines {
    match inline.note_id {
      Some(note_id) => {
        let marker = inline.note_marker.unwrap_or(inline.text)
        let kind = inline.note_kind.unwrap_or("footnote")
        if kind == "comment" {
          let next = @core.make_inline_text(marker, source_ref~)
          let next = @core.inline_with_attr(next, "annotation_role", "note_ref")
          let next = @core.inline_with_attr(next, "annotation_kind", "comment")
          let next = @core.inline_with_attr(next, "annotation_id", note_id)
          let next = @core.inline_with_attr(
            next, "annotation_target_id", note_id,
          )
          out.push(@core.inline_with_attr(next, "annotation_marker", marker))
          continue
        }
        let next = @core.make_inline_text(marker, source_ref~)
        let next = @core.inline_with_attr(next, "annotation_role", "note_ref")
        let next = @core.inline_with_attr(next, "annotation_kind", kind)
        let next = @core.inline_with_attr(next, "annotation_id", note_id)
        let next = @core.inline_with_attr(next, "annotation_target_id", note_id)
        out.push(@core.inline_with_attr(next, "annotation_marker", marker))
      }
      None =>
        match inline.href {
          Some(href) =>
            out.push(@core.make_inline_link(inline.text, href, source_ref~))
          None =>
            out.push(
              if inline.text == "\n" {
                @core.make_inline_line_break(source_ref~)
              } else {
                @core.make_inline_text(inline.text, source_ref~)
              },
            )
        }
    }
  }
  out
}

///|
fn odt_collect_notes(
  block : @dodf.OdtBlock,
  appended_note_ids : Array[String],
  pending_notes : Array[PendingOdtNote],
) -> Unit {
  for inline in block.inlines {
    match inline.note_id {
      Some(note_id) =>
        if !appended_note_ids.contains(note_id) {
          match odt_note_from_inline(block, note_id) {
            Some(note) => {
              appended_note_ids.push(note_id)
              pending_notes.push(note)
            }
            None => ()
          }
        }
      None => ()
    }
  }
}

///|
fn odt_collect_comments(
  block : @dodf.OdtBlock,
  appended_comment_ids : Array[String],
  pending_comments : Array[PendingOdtComment],
) -> Unit {
  for inline in block.inlines {
    match inline.note_id {
      Some(note_id) =>
        if inline.note_kind == Some("comment") &&
          !appended_comment_ids.contains(note_id) {
          appended_comment_ids.push(note_id)
          pending_comments.push({
            comment_id: note_id,
            marker: inline.note_marker.unwrap_or("[comment 1]"),
            body: inline.note_body.unwrap_or(inline.text),
          })
        }
      None => ()
    }
  }
}

///|
fn odt_note_from_inline(
  block : @dodf.OdtBlock,
  note_id : String,
) -> PendingOdtNote? {
  for inline in block.inlines {
    if inline.note_id == Some(note_id) &&
      inline.note_kind != Some("comment") &&
      inline.note_marker is Some(_) &&
      inline.note_kind is Some(_) {
      let marker = inline.note_marker.unwrap_or("[^1]")
      let kind = inline.note_kind.unwrap_or("footnote")
      let body = inline.note_body.unwrap_or(marker)
      return Some({
        id: odt_note_definition_label(marker),
        kind,
        note_id,
        marker,
        body,
      })
    }
  }
  None
}

///|
fn odt_note_definition_label(marker : String) -> String {
  let trimmed = marker.trim().to_owned()
  if trimmed.has_prefix("[^") && trimmed.has_suffix("]") && trimmed.length() > 3 {
    trimmed[2:trimmed.length() - 1].to_owned()
  } else {
    trimmed
  }
}

///|
fn odt_note_definition_block(
  source : @input.InputSource,
  note : PendingOdtNote,
  context : @parser.ParseContext,
) -> @core.CoreBlock {
  let source_ref = @core.source_ref_with_lines(
    @core.empty_source_ref(),
    Some(source.source_name),
    Some("odt"),
    None,
    None,
  )
  let block = @core.make_block(
    @core.BlockKind::Paragraph,
    note.body,
    source_ref~,
  )
  let block = @core.block_with_attr(block, "note_definition_id", note.id)
  let block = @core.block_with_attr(
    block,
    "annotation_definition_id",
    note.note_id,
  )
  let block = @core.block_with_attr(block, "note_definition_kind", note.kind)
  let block = @core.block_with_attr(block, "annotation_marker", note.marker)
  let block = @core.block_with_attr(block, "appendix_ready", "true")
  if context.lowering_profile == @product.LoweringProfile::AccurateSemantic &&
    @product.accurate_feature_enabled(
      context.accurate_features,
      @product.AccurateFeature::OdtRichNotes,
    ) {
    block.attrs.set("render_appendix_group", "notes")
  }
  @core.block_with_rich_inlines(
    block,
    Some([@core.make_inline_text(note.body, source_ref~)]),
  )
}

///|
fn odt_comment_definition_block(
  source : @input.InputSource,
  comment : PendingOdtComment,
  context : @parser.ParseContext,
) -> @core.CoreBlock {
  let source_ref = @core.source_ref_with_lines(
    @core.empty_source_ref(),
    Some(source.source_name),
    Some("odt"),
    None,
    None,
  )
  let item = @core.make_block(
    @core.BlockKind::ListItem,
    comment.marker + " " + comment.body,
    source_ref~,
  )
  item.attrs.set("ordered", "true")
  item.attrs.set("level", "0")
  item.attrs.set("stable_ordered_marker", "true")
  item.attrs.set("appendix_kind", "comments")
  item.attrs.set("appendix_ready", "true")
  item.attrs.set("annotation_definition_id", comment.comment_id)
  item.attrs.set("annotation_kind", "comment")
  item.attrs.set("annotation_marker", comment.marker)
  if context.lowering_profile == @product.LoweringProfile::AccurateSemantic &&
    @product.accurate_feature_enabled(
      context.accurate_features,
      @product.AccurateFeature::OdtCommentsAppendix,
    ) {
    item.attrs.set("render_appendix_group", "comments")
  }
  @core.block_with_rich_inlines(
    item,
    Some([
      @core.make_inline_text(comment.marker + " ", source_ref~),
      @core.inline_with_attr(
        @core.make_inline_text(comment.body, source_ref~),
        "annotation_kind",
        "comment",
      ),
    ]),
  )
}

///|
fn odt_table_block(
  block : @dodf.OdtBlock,
  source_ref : @core.SourceRef,
  context : @parser.ParseContext,
) -> @core.CoreBlock {
  let table = @core.make_block(@core.BlockKind::Table, "table", source_ref~)
  if context.lowering_profile == @product.LoweringProfile::LargeAdaptive {
    table.attrs.set("render_table_mode", "sparse")
  }
  for row_value in block.rows {
    let row = @core.make_block(@core.BlockKind::TableRow, "", source_ref~)
    for cell_value in row_value.cells {
      row.children.push(
        @core.make_block(
          @core.BlockKind::TableCell,
          cell_value.text,
          source_ref~,
        ),
      )
    }
    table.children.push(row)
  }
  table
}

///|
fn odt_image_block(
  source : @input.InputSource,
  block : @dodf.OdtBlock,
  assets : Array[@core.AssetRef],
  source_ref : @core.SourceRef,
) -> @core.CoreBlock {
  match block.image {
    Some(image) => {
      if image.bytes is None {
        let unavailable = @core.make_block(
          @core.BlockKind::BlockQuote,
          "Asset unavailable: " + image.href,
          source_ref~,
        )
        unavailable.attrs.set("asset_missing", "true")
        unavailable.attrs.set("asset_source_path", image.href)
        return unavailable
      }
      let asset_id = odt_asset_output_path(image.href)
      let asset = @core.make_asset_ref(
        @core.AssetKind::Image,
        asset_id,
        source_ref~,
      )
      let next_asset = {
        ..asset,
        path: Some(asset_id),
        mime_type: image.media_type,
      }
      next_asset.attrs.set("zip_entry_path", image.href.trim().to_owned())
      match source.path {
        Some(path) => next_asset.attrs.set("zip_container_path", path)
        None => ()
      }
      odt_attach_inline_payload(next_asset, image)
      assets.push(next_asset)
      let out = @core.make_block(@core.BlockKind::Image, "", source_ref~)
      out.attrs.set("asset_id", asset_id)
      out.attrs.set("path", asset_id)
      out.attrs.set("alt", image.alt.unwrap_or("odt image"))
      out.attrs.set("source_name", source.source_name)
      out
    }
    None => @core.make_block(@core.BlockKind::Paragraph, "[image]", source_ref~)
  }
}

///|
fn odt_metadata(
  _source : @input.InputSource,
  document : @dodf.OdtDocument,
) -> @core.DocumentMetadata {
  let metadata : @core.DocumentMetadata = Map([])
  metadata.set("format", @core.JsonValue::String("odt"))
  metadata.set(
    "description",
    @core.JsonValue::String(
      "OpenDocument text document with " +
      document.blocks.length().to_string() +
      " blocks",
    ),
  )
  match document.metadata.title {
    Some(value) => metadata.set("title", @core.JsonValue::String(value))
    None => ()
  }
  match document.metadata.subject {
    Some(value) => metadata.set("subject", @core.JsonValue::String(value))
    None => ()
  }
  match document.metadata.language {
    Some(value) => metadata.set("language", @core.JsonValue::String(value))
    None => ()
  }
  metadata
}

///|
fn odt_source_ref(
  source : @input.InputSource,
  block : @dodf.OdtBlock,
) -> @core.SourceRef {
  let container_path = source.path.unwrap_or(source.source_name)
  let base = @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some(source.source_name),
    Some("odt"),
    Some(container_path),
    Some(block.content_path),
    None,
    Some("xml"),
    Some(block.content_path),
  )
  let office = @core.source_ref_with_office_fields(
    base,
    Some(source.source_name),
    Some("odt"),
    Some(block.content_path),
    None,
    None,
    None,
    None,
    None,
  )
  let with_lines = @core.source_ref_with_lines(
    office,
    Some(source.source_name),
    Some("odt"),
    block.line_start,
    block.line_end,
  )
  let with_inner = @core.source_ref_with_extra(
    with_lines,
    "part_name",
    block.content_path,
  )
  @core.source_ref_with_extra(with_inner, "odt_xml_path", block.xml_path)
}

///|
fn odt_asset_output_path(href : String) -> String {
  let clean = href.trim().to_owned().replace_all(old="Pictures/", new="")
  "assets/odt-" + odt_slug(clean)
}

///|
fn odt_slug(text : String) -> String {
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
fn odt_preflight_summary_from_document(
  document : @dodf.OdtDocument,
) -> OdtPreflightSummary {
  let inspect = @dodf.inspect_odt_document(document)
  {
    block_count: inspect.block_count,
    heading_count: inspect.heading_count,
    table_count: inspect.table_count,
    image_count: inspect.image_count,
    note_count: inspect.note_count,
    comment_count: inspect.comment_count,
    max_heading_level: inspect.max_heading_level,
  }
}

///|
fn odt_malformed_parse_result(
  source : @input.InputSource,
  diagnostics : @core.Diagnostics,
  err : String,
  capability : @parser.ParserCapability,
  bytes : Bytes,
  context : @parser.ParseContext,
) -> @parser.ParseResult {
  diagnostics.warnings.push("odt parse failed; returned raw fenced fallback")
  diagnostics.errors.push(err)
  diagnostics.degraded_features.push("odt_raw_fenced_fallback")
  diagnostics.fallback_trace.push("odt_raw_fenced_fallback")
  diagnostics.metrics.set("syntax_error_count", "1")
  @fshared.refresh_parser_count_metrics(
    diagnostics,
    if context.requested_mode == Some(@parser.ParserMode::BlockStreaming) {
      "block_stream"
    } else {
      "document"
    },
  )
  if context.requested_mode == Some(@parser.ParserMode::BlockStreaming) {
    diagnostics.metrics.set("parser_mode", "block_streaming")
    diagnostics.metrics.set("effective_mode", "block_streaming")
    diagnostics.metrics.set("ir_input_kind", "block_stream")
    diagnostics.metrics.set("event_semantics", "odt_block_stream")
    let raw = @core.make_block(
      @core.BlockKind::Code,
      "binary odt package (" + bytes.length().to_string() + " bytes)",
      source_ref=odt_fallback_source_ref(source),
    )
    raw.attrs.set("info", "odt")
    return @parser.parse_result_with_blocks_capability(
      ODT_PARSER_NAME,
      @parser.ParserMode::BlockStreaming,
      [raw],
      diagnostics,
      capability,
    )
  }
  let raw = @core.make_block(
    @core.BlockKind::Code,
    "binary odt package (" + bytes.length().to_string() + " bytes)",
    source_ref=odt_fallback_source_ref(source),
  )
  raw.attrs.set("info", "odt")
  let document = @core.document_with_diagnostics(
    @core.document_with_blocks(@core.empty_document_ir(), [raw]),
    diagnostics,
  )
  @parser.parse_result_with_document_capability(
    ODT_PARSER_NAME,
    @parser.ParserMode::PackageSinglePass,
    document,
    diagnostics,
    capability,
  )
}

///|
fn odt_attach_inline_payload(
  asset : @core.AssetRef,
  image : @dodf.OdtImageRef,
) -> Unit {
  match image.bytes {
    Some(bytes) =>
      if image.media_type == Some("image/svg+xml") {
        let text = @utf8.decode(bytes, ignore_bom=false) catch { _ => return }
        asset.attrs.set("inline_payload_kind", "utf8")
        asset.attrs.set("inline_payload", text)
      } else {
        asset.attrs.set("inline_payload_kind", "base64")
        asset.attrs.set("inline_payload", @base64.encode(bytes, url_safe=false))
      }
    None => ()
  }
}

///|
fn odt_fallback_source_ref(source : @input.InputSource) -> @core.SourceRef {
  @core.source_ref_with_lines(
    @core.empty_source_ref(),
    Some(source.source_name),
    Some("odt"),
    None,
    None,
  )
}
