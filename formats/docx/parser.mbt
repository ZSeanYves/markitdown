///|
pub fn docx_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    @parser.ParserMode::PackageSinglePass,
    false,
    @parser.StreamingGranularity::DocxBlock,
    true,
    true,
    true,
    false,
    false,
    true,
    true,
    true,
    false,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
  )
}

///|
pub fn docx_parser() -> @parser.Parser {
  let capability = docx_parser_capability()
  @parser.make_parser(
    "docx_parser",
    @parser.ParserMode::PackageSinglePass,
    capability,
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      parse_docx_document_result(source, context, capability)
    },
  )
}

///|
fn parse_docx_document_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
  capability : @parser.ParserCapability,
) -> Result[@parser.ParseResult, String] {
  let diagnostics = @light_common.empty_parser_diagnostics(
    "docx_parser",
    @parser.ParserMode::PackageSinglePass,
    source,
    "docx",
  )
  diagnostics.metrics.set("parser_name", "docx_parser")
  diagnostics.metrics.set("parser_mode", "package_single_pass")
  diagnostics.metrics.set(
    "input_kind",
    @light_common.input_kind_name(source.kind),
  )
  diagnostics.metrics.set("detected_format", "docx")
  diagnostics.metrics.set(
    "requested_mode",
    @light_common.requested_mode_name(context),
  )
  diagnostics.metrics.set("effective_mode", "package_single_pass")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("event_granularity", "docx_block")
  diagnostics.metrics.set("event_semantics", "package_single_pass")
  diagnostics.metrics.set("streaming_fallback", "false")
  diagnostics.metrics.set("office_document_kind", "docx")
  diagnostics.metrics.set("runtime_exposed", "true")
  diagnostics.metrics.set("legacy_runtime_dependency", "none")
  diagnostics.metrics.set("legacy_convert_dependency", "none")
  diagnostics.metrics.set("legacy_fallback", "forbidden")
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("media_asset_count", "0")
  diagnostics.metrics.set("materialized_asset_count", "0")
  diagnostics.metrics.set("skipped_asset_count", "0")
  diagnostics.metrics.set("path_traversal_count", "0")
  diagnostics.metrics.set("duplicate_part_count", "0")
  diagnostics.metrics.set("encrypted_entry_count", "0")
  diagnostics.metrics.set("unsupported_compression_count", "0")
  diagnostics.metrics.set("xml_dtd_count", "0")
  diagnostics.metrics.set("xml_external_entity_count", "0")
  diagnostics.metrics.set("macro_part_count", "0")
  diagnostics.metrics.set("ole_object_count", "0")
  diagnostics.metrics.set("alt_chunk_count", "0")
  diagnostics.metrics.set("docx_paragraph_count", "0")
  diagnostics.metrics.set("docx_heading_count", "0")
  diagnostics.metrics.set("docx_table_count", "0")
  diagnostics.metrics.set("docx_list_count", "0")
  diagnostics.metrics.set("docx_image_count", "0")
  diagnostics.metrics.set("docx_hyperlink_count", "0")
  diagnostics.metrics.set("docx_header_footer_count", "0")
  diagnostics.metrics.set("docx_comment_count", "0")
  diagnostics.metrics.set("docx_tracked_change_count", "0")
  @light_common.apply_readiness_metrics(diagnostics, "docx", "near_ready")

  let bytes = match @input.read_input_bytes(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let pkg = try @ox.open_ooxml_package(bytes) |> Ok catch {
    e => Err(e.to_string())
  }
  let pkg = match pkg {
    Ok(value) => value
    Err(err) =>
      return Ok(
        malformed_docx_parse_result(
          source,
          diagnostics,
          "open package failed: " + err,
          capability,
        ),
      )
  }

  let docx = try @ddocx.parse_docx_document_from_package(pkg) |> Ok catch {
    e => Err(e.to_string())
  }
  let docx = match docx {
    Ok(value) => value
    Err(err) =>
      return Ok(
        malformed_docx_parse_result(
          source,
          diagnostics,
          "parse docx failed: " + err,
          capability,
        ),
      )
  }

  fill_docx_package_metrics(diagnostics, pkg)
  let document = lower_docx_document_ir(source, docx, pkg, diagnostics)
  diagnostics.metrics.set("block_count", document.blocks.length().to_string())
  diagnostics.metrics.set("asset_count", document.assets.length().to_string())
  diagnostics.metrics.set(
    "degraded_feature_count",
    diagnostics.degraded_features.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
  diagnostics.metrics.set(
    "warning_count",
    diagnostics.warnings.length().to_string(),
  )
  diagnostics.metrics.set(
    "error_count",
    diagnostics.errors.length().to_string(),
  )
  diagnostics.metrics.set(
    "issue_count",
    (diagnostics.warnings.length() + diagnostics.errors.length()).to_string(),
  )
  diagnostics.pass_trace.push("parse:docx_parser")
  let final_document = @core.document_with_diagnostics(document, diagnostics)
  Ok(
    @parser.parse_result_with_document_capability(
      "docx_parser",
      @parser.ParserMode::PackageSinglePass,
      final_document,
      diagnostics,
      capability,
    ),
  )
}

///|
fn malformed_docx_parse_result(
  source : @input.InputSource,
  diagnostics : @core.Diagnostics,
  err : String,
  capability : @parser.ParserCapability,
) -> @parser.ParseResult {
  diagnostics.errors.push(err)
  diagnostics.degraded_features.push("docx_parse_failure")
  diagnostics.fallback_trace.push("docx parse failed -> fail closed")
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("block_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("ooxml_part_count", "0")
  diagnostics.metrics.set("relationship_count", "0")
  diagnostics.metrics.set("external_relationship_count", "0")
  diagnostics.metrics.set("missing_relationship_target_count", "0")
  diagnostics.metrics.set("unsupported_relationship_count", "0")
  diagnostics.metrics.set("media_asset_count", "0")
  diagnostics.metrics.set("materialized_asset_count", "0")
  diagnostics.metrics.set("skipped_asset_count", "0")
  diagnostics.metrics.set("content_type_count", "0")
  diagnostics.metrics.set("total_uncompressed_bytes", "0")
  diagnostics.metrics.set("path_traversal_count", "0")
  diagnostics.metrics.set("duplicate_part_count", "0")
  diagnostics.metrics.set("encrypted_entry_count", "0")
  diagnostics.metrics.set("unsupported_compression_count", "0")
  diagnostics.metrics.set("xml_dtd_count", "0")
  diagnostics.metrics.set("xml_external_entity_count", "0")
  diagnostics.metrics.set("macro_part_count", "0")
  diagnostics.metrics.set("ole_object_count", "0")
  diagnostics.metrics.set("alt_chunk_count", "0")
  diagnostics.metrics.set("docx_paragraph_count", "0")
  diagnostics.metrics.set("docx_heading_count", "0")
  diagnostics.metrics.set("docx_table_count", "0")
  diagnostics.metrics.set("docx_list_count", "0")
  diagnostics.metrics.set("docx_image_count", "0")
  diagnostics.metrics.set("docx_hyperlink_count", "0")
  diagnostics.metrics.set("docx_header_footer_count", "0")
  diagnostics.metrics.set("docx_comment_count", "0")
  diagnostics.metrics.set("docx_tracked_change_count", "0")
  diagnostics.metrics.set(
    "degraded_feature_count",
    diagnostics.degraded_features.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
  diagnostics.metrics.set(
    "warning_count",
    diagnostics.warnings.length().to_string(),
  )
  diagnostics.metrics.set(
    "error_count",
    diagnostics.errors.length().to_string(),
  )
  diagnostics.metrics.set(
    "issue_count",
    (diagnostics.warnings.length() + diagnostics.errors.length()).to_string(),
  )
  diagnostics.pass_trace.push("parse:docx_parser")
  let document = @core.document_with_diagnostics(
    @core.empty_document_ir(),
    diagnostics,
  )
  ignore(source)
  @parser.parse_result_with_document_capability(
    "docx_parser",
    @parser.ParserMode::PackageSinglePass,
    document,
    diagnostics,
    capability,
  )
}

///|
fn lower_docx_document_ir(
  source : @input.InputSource,
  docx : @ddocx.DocxDocument,
  pkg : @ox.OoxmlPackage,
  diagnostics : @core.Diagnostics,
) -> @core.DocumentIR {
  let document = @core.empty_document_ir()
  fill_docx_metadata(document.metadata, docx)
  let state = new_docx_lowering_state(source, docx, pkg, document, diagnostics)
  lower_docx_blocks(state, document.blocks, docx.body)
  append_docx_comments_blocks(state, document.blocks)
  append_docx_part_body_blocks(
    state,
    document.blocks,
    docx.headers,
    "Headers",
    "Header",
  )
  append_docx_part_body_blocks(
    state,
    document.blocks,
    docx.footers,
    "Footers",
    "Footer",
  )
  append_docx_textboxes_blocks(state, document.blocks)
  append_docx_note_definitions_blocks(state, document.blocks)
  @core.document_with_assets(document, state.assets)
}

///|
priv struct DocxLoweringState {
  source : @input.InputSource
  docx : @ddocx.DocxDocument
  diagnostics : @core.Diagnostics
  assets : Array[@core.AssetRef]
  asset_ids : Map[String, String]
  footnote_labels : Map[String, String]
  endnote_labels : Map[String, String]
  comment_labels : Map[String, String]
  footnotes_by_id : Map[String, @ddocx.DocxNote]
  endnotes_by_id : Map[String, @ddocx.DocxNote]
  comments_by_id : Map[String, @ddocx.DocxComment]
}

///|
priv struct DocxListTree {
  ordered : Bool
  items : Array[@core.CoreBlock]
}

///|
priv struct DocxInlineLowering {
  rich_inlines : Array[@core.CoreInline]
  plain_text : String
  has_link : Bool
  image_count : Int
  hyperlink_count : Int
  tracked_change_count : Int
}

///|
fn metric_int(diagnostics : @core.Diagnostics, key : String) -> Int {
  @string.parse_int(diagnostics.metrics.get(key).unwrap_or("0")) catch {
    _ => 0
  }
}

///|
fn new_docx_lowering_state(
  source : @input.InputSource,
  docx : @ddocx.DocxDocument,
  _pkg : @ox.OoxmlPackage,
  _document : @core.DocumentIR,
  diagnostics : @core.Diagnostics,
) -> DocxLoweringState {
  let footnote_labels : Map[String, String] = Map([])
  let endnote_labels : Map[String, String] = Map([])
  let comment_labels : Map[String, String] = Map([])
  let assets : Array[@core.AssetRef] = []
  let asset_ids : Map[String, String] = Map([])
  let footnotes_by_id : Map[String, @ddocx.DocxNote] = Map([])
  let endnotes_by_id : Map[String, @ddocx.DocxNote] = Map([])
  let comments_by_id : Map[String, @ddocx.DocxComment] = Map([])

  for note in docx.footnotes {
    if !footnotes_by_id.contains(note.note_id) {
      footnotes_by_id.set(note.note_id, note)
    }
  }
  for note in docx.endnotes {
    if !endnotes_by_id.contains(note.note_id) {
      endnotes_by_id.set(note.note_id, note)
    }
  }
  for comment in docx.comments {
    if !comments_by_id.contains(comment.comment_id) {
      comments_by_id.set(comment.comment_id, comment)
    }
  }

  let footnote_ids : Array[String] = []
  let endnote_ids : Array[String] = []
  let comment_ids : Array[String] = []
  collect_docx_reference_ids(docx.body, footnote_ids, endnote_ids, comment_ids)
  let mut idx = 1
  for id in footnote_ids {
    if !footnote_labels.contains(id) && footnotes_by_id.contains(id) {
      footnote_labels.set(id, idx.to_string())
      idx += 1
    }
  }
  idx = 1
  for id in endnote_ids {
    if !endnote_labels.contains(id) && endnotes_by_id.contains(id) {
      endnote_labels.set(id, idx.to_string())
      idx += 1
    }
  }
  idx = 1
  for id in comment_ids {
    if !comment_labels.contains(id) && comments_by_id.contains(id) {
      comment_labels.set(id, idx.to_string())
      idx += 1
    }
  }
  {
    source,
    docx,
    diagnostics,
    assets,
    asset_ids,
    footnote_labels,
    endnote_labels,
    comment_labels,
    footnotes_by_id,
    endnotes_by_id,
    comments_by_id,
  }
}

///|
fn fill_docx_package_metrics(
  diagnostics : @core.Diagnostics,
  pkg : @ox.OoxmlPackage,
) -> Unit {
  let inventory = @ox.inspect_ooxml_inventory(pkg)
  let validation = @ox.validate_ooxml_package(pkg)
  let package_relationship_count = (@ox.read_package_relationships(pkg) catch {
    _ => []
  }).length()
  let part_relationship_count = inventory.relationship_source_parts.fold(
    init=0,
    fn(acc, source_part) {
      acc +
      (@ox.read_part_relationships(pkg, source_part) catch { _ => [] }).length()
    },
  )
  diagnostics.metrics.set("ooxml_part_count", inventory.part_count.to_string())
  diagnostics.metrics.set(
    "relationship_count",
    (package_relationship_count + part_relationship_count).to_string(),
  )
  let mut external_relationship_count = 0
  let mut missing_relationship_target_count = 0
  let mut unsupported_relationship_count = 0
  for issue in validation.issues {
    match issue.kind {
      @ox.OoxmlValidationIssueKind::ExternalRelationship =>
        external_relationship_count += 1
      @ox.OoxmlValidationIssueKind::MissingRelationshipTarget =>
        missing_relationship_target_count += 1
      @ox.OoxmlValidationIssueKind::UnsafeRelationshipTarget =>
        unsupported_relationship_count += 1
      _ => ()
    }
  }
  diagnostics.metrics.set(
    "external_relationship_count",
    external_relationship_count.to_string(),
  )
  diagnostics.metrics.set(
    "missing_relationship_target_count",
    missing_relationship_target_count.to_string(),
  )
  diagnostics.metrics.set(
    "unsupported_relationship_count",
    unsupported_relationship_count.to_string(),
  )
  diagnostics.metrics.set(
    "content_type_count",
    inventory.content_type_entry_count.to_string(),
  )
  let media_asset_count = count_docx_media_parts(inventory.parts)
  diagnostics.metrics.set("media_asset_count", media_asset_count.to_string())
  let mut total_uncompressed_bytes = 0
  let mut path_traversal_count = 0
  let mut duplicate_part_count = 0
  let encrypted_entry_count = 0
  let unsupported_compression_count = 0
  for part in inventory.parts {
    total_uncompressed_bytes += part.size
  }
  for issue in validation.issues {
    let message = issue.message.trim().to_owned()
    if message.contains("unsafe relationship target") ||
      message.contains("path traversal") {
      path_traversal_count += 1
    }
    if message.contains("duplicate") {
      duplicate_part_count += 1
    }
  }
  diagnostics.metrics.set(
    "total_uncompressed_bytes",
    total_uncompressed_bytes.to_string(),
  )
  diagnostics.metrics.set(
    "path_traversal_count",
    path_traversal_count.to_string(),
  )
  diagnostics.metrics.set(
    "duplicate_part_count",
    duplicate_part_count.to_string(),
  )
  diagnostics.metrics.set(
    "encrypted_entry_count",
    encrypted_entry_count.to_string(),
  )
  diagnostics.metrics.set(
    "unsupported_compression_count",
    unsupported_compression_count.to_string(),
  )
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("xml_dtd_count", "0")
  diagnostics.metrics.set("xml_external_entity_count", "0")
  diagnostics.metrics.set(
    "macro_part_count",
    count_docx_macro_parts(inventory.parts).to_string(),
  )
  diagnostics.metrics.set(
    "ole_object_count",
    count_docx_ole_object_parts(inventory.parts).to_string(),
  )
  diagnostics.metrics.set("alt_chunk_count", "0")
}

///|
fn count_docx_media_parts(parts : Array[@ox.OoxmlPartInfo]) -> Int {
  let mut count = 0
  for part in parts {
    if part.part_name.has_prefix("word/media/") &&
      !part.part_name.has_suffix("/") {
      count += 1
    }
  }
  count
}

///|
fn fill_docx_metadata(
  metadata : @core.DocumentMetadata,
  docx : @ddocx.DocxDocument,
) -> Unit {
  let core = docx.metadata.core
  let app = docx.metadata.app
  set_document_metadata_string(metadata, "title", core.title)
  set_document_metadata_string(metadata, "subject", core.subject)
  set_document_metadata_string(metadata, "creator", core.creator)
  set_document_metadata_string(
    metadata,
    "last_modified_by",
    core.last_modified_by,
  )
  set_document_metadata_string(metadata, "created", core.created)
  set_document_metadata_string(metadata, "modified", core.modified)
  set_document_metadata_string(metadata, "keywords", core.keywords)
  set_document_metadata_string(metadata, "description", core.description)
  set_document_metadata_string(metadata, "category", core.category)
  set_document_metadata_string(metadata, "company", app.company)
  set_document_metadata_string(metadata, "manager", app.manager)
  set_document_metadata_string(metadata, "application", app.application)
  set_document_metadata_string(metadata, "pages", app.pages)
  set_document_metadata_string(metadata, "words", app.words)
  set_document_metadata_string(metadata, "slides", app.slides)
  set_document_metadata_string(metadata, "sheets", app.sheets)
  if docx.metadata.custom_properties.length() > 0 {
    let entries : Map[String, @core.JsonValue] = Map([])
    for prop in docx.metadata.custom_properties {
      entries.set(prop.name, @core.JsonValue::String(prop.value))
    }
    metadata.set("custom_properties", @core.JsonValue::Object(entries))
  }
}

///|
fn set_document_metadata_string(
  metadata : @core.DocumentMetadata,
  key : String,
  value : String?,
) -> Unit {
  match value {
    Some(text) =>
      if text.trim() != "" {
        metadata.set(key, @core.JsonValue::String(text))
      }
    None => ()
  }
}

///|
fn lower_docx_blocks(
  state : DocxLoweringState,
  out : Array[@core.CoreBlock],
  blocks : Array[@ddocx.DocxBlock],
) -> Unit {
  let list_stack : Array[DocxListTree] = []

  fn flush_lists(
    out : Array[@core.CoreBlock],
    list_stack : Array[DocxListTree],
    min_depth : Int,
  ) -> Unit {
    while list_stack.length() > min_depth {
      let current = list_stack.pop().unwrap()
      let list_block = @core.make_block(
        @core.BlockKind::List,
        "",
        source_ref=current.items[0].source_ref.unwrap_or(
          @core.empty_source_ref(),
        ),
      )
      list_block.attrs.set(
        "ordered",
        @light_common.bool_string(current.ordered),
      )
      list_block.children.append(current.items[:])
      match list_stack.last() {
        Some(parent) =>
          parent.items[parent.items.length() - 1].children.push(list_block)
        None => out.push(list_block)
      }
    }
  }

  for block in blocks {
    match block {
      @ddocx.DocxBlock::Paragraph(p) =>
        match lower_docx_paragraph_block(state, p) {
          Some(lowered) =>
            if lowered.kind == @core.BlockKind::ListItem {
              let ordered = lowered.attrs.get("ordered").unwrap_or("false") ==
                "true"
              let level = @string.parse_int(
                lowered.attrs.get("level").unwrap_or("0"),
              ) catch {
                _ => 0
              }
              let target_depth = level + 1
              flush_lists(out, list_stack, target_depth)
              if list_stack.length() == target_depth &&
                target_depth > 0 &&
                list_stack[target_depth - 1].ordered != ordered {
                flush_lists(out, list_stack, target_depth - 1)
              }
              while list_stack.length() < target_depth {
                list_stack.push({ ordered, items: [] })
              }
              if list_stack.length() > 0 {
                list_stack[list_stack.length() - 1].items.push(lowered)
              }
            } else {
              flush_lists(out, list_stack, 0)
              out.push(lowered)
            }
          None => ()
        }
      @ddocx.DocxBlock::Table(table) => {
        flush_lists(out, list_stack, 0)
        let lowered = lower_docx_table_block(state, table)
        if docx_rendered_table_has_visible_cells(lowered) {
          out.push(lowered)
        }
      }
      @ddocx.DocxBlock::TablePlaceholder(placeholder) => {
        flush_lists(out, list_stack, 0)
        let placeholder_ref = docx_source_ref_from_key(
          state,
          placeholder.source_key,
          None,
          None,
        )
        let raw = @core.make_block(
          @core.BlockKind::Raw,
          "[Unsupported DOCX table omitted]",
          source_ref=placeholder_ref,
        )
        raw.attrs.set("raw_kind", "docx_table_placeholder")
        out.push(raw)
      }
      @ddocx.DocxBlock::ContentControl(control) => {
        flush_lists(out, list_stack, 0)
        if control.blocks.length() > 0 {
          lower_docx_blocks(state, out, control.blocks)
        } else {
          let inline = lower_docx_inlines(
            state,
            control.inlines,
            control.source_key,
          )
          if inline.rich_inlines.length() > 0 || inline.plain_text.trim() != "" {
            let paragraph0 = @core.make_block(
              @core.BlockKind::Paragraph,
              inline.plain_text,
              source_ref=docx_source_ref_from_key(
                state,
                control.source_key,
                None,
                None,
              ),
            )
            let paragraph = if inline.rich_inlines.length() > 0 {
              @core.block_with_rich_inlines(
                paragraph0,
                Some(inline.rich_inlines),
              )
            } else {
              paragraph0
            }
            out.push(paragraph)
          }
        }
      }
      @ddocx.DocxBlock::StructuralMarker(_) => ()
      @ddocx.DocxBlock::Unsupported(warning) => {
        flush_lists(out, list_stack, 0)
        let source_ref = match warning.source_key {
          Some(key) => Some(docx_source_ref_from_key(state, key, None, None))
          None => Some(@core.empty_source_ref())
        }
        let raw = @core.make_block(
          @core.BlockKind::Raw,
          "[Unsupported DOCX node: " + warning.message + "]",
          source_ref=source_ref.unwrap_or(@core.empty_source_ref()),
        )
        raw.attrs.set("raw_kind", "docx_unsupported")
        out.push(raw)
      }
    }
  }
  flush_lists(out, list_stack, 0)
}

///|
fn lower_docx_paragraph_block(
  state : DocxLoweringState,
  p : @ddocx.DocxParagraph,
) -> @core.CoreBlock? {
  if docx_paragraph_is_page_number_field_only(p) {
    return None
  }
  let inline = lower_docx_inlines(state, p.inlines, p.source_key)
  let source_ref = docx_source_ref_from_key(state, p.source_key, None, None)
  if inline.tracked_change_count > 0 {
    let current = metric_int(state.diagnostics, "docx_tracked_change_count")
    state.diagnostics.metrics.set(
      "docx_tracked_change_count",
      (current + inline.tracked_change_count).to_string(),
    )
  }
  if inline.rich_inlines.length() == 0 && inline.plain_text.trim() == "" {
    return None
  }
  if docx_paragraph_is_image_only(inline) {
    return Some(lower_docx_image_only_paragraph(state, p, inline, source_ref))
  }
  let resolved_style = @ddocx.docx_resolve_paragraph_style(state.docx, p)
  match docx_paragraph_heading_level(resolved_style, p) {
    Some(level) => {
      let heading0 = @core.make_block(
        @core.BlockKind::Heading,
        inline.plain_text.trim().to_owned(),
        source_ref~,
      )
      let heading = if inline.rich_inlines.length() > 0 {
        @core.block_with_rich_inlines(heading0, Some(inline.rich_inlines))
      } else {
        heading0
      }
      heading.attrs.set("level", level.to_string())
      bump_metric(state.diagnostics, "docx_heading_count")
      return Some(heading)
    }
    None => ()
  }
  match docx_paragraph_list_lowering(state.docx, p) {
    Some((ordered, level)) => {
      let item0 = @core.make_block(
        @core.BlockKind::ListItem,
        docx_list_item_text(inline.plain_text),
        source_ref~,
      )
      let item = if inline.rich_inlines.length() > 0 {
        @core.block_with_rich_inlines(item0, Some(inline.rich_inlines))
      } else {
        item0
      }
      item.attrs.set("ordered", @light_common.bool_string(ordered))
      if ordered {
        item.attrs.set("stable_ordered_marker", "true")
      }
      item.attrs.set("level", level.to_string())
      bump_metric(state.diagnostics, "docx_list_count")
      return Some(item)
    }
    None => ()
  }
  if docx_paragraph_is_code_style(resolved_style, p, inline.plain_text) {
    let code = @core.make_block(
      @core.BlockKind::Code,
      inline.plain_text,
      source_ref~,
    )
    return Some(code)
  }
  if docx_paragraph_is_quote_style(resolved_style, p) {
    let quote0 = @core.make_block(
      @core.BlockKind::BlockQuote,
      inline.plain_text,
      source_ref~,
    )
    let quote = if inline.rich_inlines.length() > 0 {
      @core.block_with_rich_inlines(quote0, Some(inline.rich_inlines))
    } else {
      quote0
    }
    return Some(quote)
  }
  let paragraph0 = @core.make_block(
    @core.BlockKind::Paragraph,
    inline.plain_text,
    source_ref~,
  )
  let paragraph = if inline.rich_inlines.length() > 0 {
    @core.block_with_rich_inlines(paragraph0, Some(inline.rich_inlines))
  } else {
    paragraph0
  }
  if inline.image_count > 0 {
    paragraph.attrs.set("contains_inline_image_placeholder", "true")
  }
  bump_metric(state.diagnostics, "docx_paragraph_count")
  Some(paragraph)
}

///|
fn lower_docx_table_block(
  state : DocxLoweringState,
  table : @ddocx.DocxTable,
) -> @core.CoreBlock {
  let source_ref = docx_source_ref_from_key(state, table.source_key, None, None)
  let block = @core.make_block(@core.BlockKind::Table, "table", source_ref~)
  block.attrs.set("header_rows", docx_table_header_rows(table).to_string())
  block.attrs.set(
    "table_column_count",
    docx_table_column_count(table).to_string(),
  )
  for row in table.rows {
    let row_ref = docx_source_ref_from_key(state, row.source_key, None, None)
    let row_block = @core.make_block(
      @core.BlockKind::TableRow,
      "",
      source_ref=row_ref,
    )
    for cell in row.cells {
      let cell_ref = docx_source_ref_from_key(
        state,
        cell.source_key,
        None,
        None,
      )
      let (cell_text, cell_rich) = docx_table_cell_content(state, cell)
      let cell_block0 = @core.make_block(
        @core.BlockKind::TableCell,
        cell_text,
        source_ref=cell_ref,
      )
      let cell_block = if cell_rich.length() > 0 {
        @core.block_with_rich_inlines(cell_block0, Some(cell_rich))
      } else {
        cell_block0
      }
      row_block.children.push(cell_block)
    }
    block.children.push(row_block)
  }
  bump_metric(state.diagnostics, "docx_table_count")
  block
}

///|
fn docx_table_cell_grid_span(cell : @ddocx.DocxTableCell) -> Int {
  match cell.grid_span {
    Some(raw) =>
      match docx_parse_nonnegative_int(raw) {
        Some(span) => if span < 1 { 1 } else { span }
        None => 1
      }
    None => 1
  }
}

///|
fn docx_table_column_count(table : @ddocx.DocxTable) -> Int {
  let mut width = 0
  for row in table.rows {
    let mut row_width = 0
    for cell in row.cells {
      row_width += docx_table_cell_grid_span(cell)
    }
    if row_width > width {
      width = row_width
    }
  }
  width
}

///|
fn docx_table_header_rows(table : @ddocx.DocxTable) -> Int {
  if table.rows.length() > 0 {
    1
  } else {
    0
  }
}

///|
fn docx_table_cell_content(
  state : DocxLoweringState,
  cell : @ddocx.DocxTableCell,
) -> (String, Array[@core.CoreInline]) {
  let parts : Array[String] = []
  let rich : Array[@core.CoreInline] = []
  let mut first = true

  fn append_text(
    rich : Array[@core.CoreInline],
    text : String,
    source_ref : @core.SourceRef,
  ) -> Unit {
    if text == "" {
      return
    }
    rich.push(@core.make_inline_text(text, source_ref~))
  }

  fn append_break(
    parts : Array[String],
    rich : Array[@core.CoreInline],
    source_ref : @core.SourceRef,
  ) -> Unit {
    parts.push("<br>")
    rich.push(@core.make_inline_line_break(source_ref~))
  }

  for block in cell.blocks {
    match block {
      @ddocx.DocxBlock::Paragraph(p) => {
        let lowered = lower_docx_inlines(state, p.inlines, p.source_key)
        let normalized = docx_table_cell_block_text(lowered.plain_text, p)
        if normalized == "" {
          continue
        }
        let source_ref = docx_source_ref_from_key(
          state,
          p.source_key,
          None,
          None,
        )
        if !first {
          append_break(parts, rich, source_ref)
        }
        parts.push(normalized)
        if lowered.rich_inlines.length() > 0 {
          let cell_inlines : Array[@core.CoreInline] = []
          for inline in lowered.rich_inlines {
            if inline.kind == @core.InlineKind::Image {
              cell_inlines.push(
                @core.make_inline_text(
                  inline.text,
                  source_ref=inline.source_ref.unwrap_or(source_ref),
                ),
              )
            } else {
              cell_inlines.push(inline)
            }
          }
          rich.append(cell_inlines[:])
        } else {
          append_text(rich, normalized, source_ref)
        }
        first = false
      }
      @ddocx.DocxBlock::Table(table) => {
        let nested = lower_docx_table_block(state, table)
        let rendered = nested.children
          .map(row => row.children.map(cell => cell.text).join(" | "))
          .join("\n")
        if rendered == "" {
          continue
        }
        let source_ref = nested.source_ref.unwrap_or(@core.empty_source_ref())
        if !first {
          append_break(parts, rich, source_ref)
        }
        parts.push(rendered)
        append_text(rich, rendered, source_ref)
        first = false
      }
      @ddocx.DocxBlock::ContentControl(control) => {
        let lowered = lower_docx_inlines(
          state,
          control.inlines,
          control.source_key,
        )
        let text = if lowered.plain_text.trim() != "" {
          normalize_docx_table_text(lowered.plain_text)
        } else {
          normalize_docx_table_text(control.text)
        }
        if text == "" {
          continue
        }
        let source_ref = docx_source_ref_from_key(
          state,
          control.source_key,
          None,
          None,
        )
        if !first {
          append_break(parts, rich, source_ref)
        }
        parts.push(text)
        if lowered.rich_inlines.length() > 0 {
          rich.append(lowered.rich_inlines[:])
        } else {
          append_text(rich, text, source_ref)
        }
        first = false
      }
      @ddocx.DocxBlock::TablePlaceholder(_) => {
        let text = "[Unsupported DOCX nested table depth limit]"
        if !first {
          append_break(parts, rich, @core.empty_source_ref())
        }
        parts.push(text)
        append_text(rich, text, @core.empty_source_ref())
        first = false
      }
      @ddocx.DocxBlock::Unsupported(_) => {
        let text = "[Unsupported DOCX inline]"
        if !first {
          append_break(parts, rich, @core.empty_source_ref())
        }
        parts.push(text)
        append_text(rich, text, @core.empty_source_ref())
        first = false
      }
      @ddocx.DocxBlock::StructuralMarker(_) => ()
    }
  }
  (parts.join(""), rich)
}

///|
fn docx_table_cell_block_text(
  text : String,
  p : @ddocx.DocxParagraph,
) -> String {
  match docx_paragraph_list_lowering_in_cell(p) {
    Some((ordered, _level)) =>
      if ordered {
        normalize_docx_table_text(text)
      } else {
        normalize_docx_table_text(text)
      }
    None => normalize_docx_table_text(text)
  }
}

///|
fn normalize_docx_table_text(text : String) -> String {
  text
  .replace(old="\r\n", new="\n")
  .replace(old="\r", new="\n")
  .split("\n")
  .map(fn(line) { line.trim().to_owned() })
  .filter(fn(line) { line != "" })
  .iter()
  .collect()
  .join("<br>")
}

///|
fn docx_paragraph_list_lowering_in_cell(
  p : @ddocx.DocxParagraph,
) -> (Bool, Int)? {
  match p.numbering_ref {
    Some(numbering_ref) =>
      match numbering_ref.ilvl {
        Some(ilvl) =>
          if ilvl.trim() == "" {
            Some((false, 0))
          } else {
            Some((false, @string.parse_int(ilvl.trim()) catch { _ => 0 }))
          }
        None => Some((false, 0))
      }
    None => None
  }
}

///|
fn lower_docx_inlines(
  state : DocxLoweringState,
  inlines : Array[@ddocx.DocxInline],
  source_key : @ddocx.DocxSourceKey,
) -> DocxInlineLowering {
  let rich_inlines : Array[@core.CoreInline] = []
  let plain = StringBuilder::new()
  let inline_source_ref = docx_source_ref_from_key(
    state,
    source_key,
    None,
    None,
  )
  let mut has_link = false
  let mut image_count = 0
  let mut hyperlink_count = 0
  let mut tracked_change_count = 0
  let mut pending_space_before_comment = false

  fn append_plain_and_rich(
    plain : StringBuilder,
    rich_inlines : Array[@core.CoreInline],
    text : String,
    source_ref : @core.SourceRef,
  ) -> Unit {
    if text == "" {
      return
    }
    plain.write_string(text)
    rich_inlines.push(@core.make_inline_text(text, source_ref~))
  }

  for inline in inlines {
    match inline {
      @ddocx.DocxInline::Text(text) =>
        append_plain_and_rich(plain, rich_inlines, text, inline_source_ref)
      @ddocx.DocxInline::Tab =>
        append_plain_and_rich(plain, rich_inlines, " ", inline_source_ref)
      @ddocx.DocxInline::LineBreak => {
        plain.write_string("\n")
        rich_inlines.push(
          @core.make_inline_line_break(source_ref=inline_source_ref),
        )
      }
      @ddocx.DocxInline::Break(value) =>
        match render_docx_break_text(value) {
          "\n" => {
            plain.write_string("\n")
            rich_inlines.push(
              @core.make_inline_line_break(source_ref=inline_source_ref),
            )
          }
          text =>
            append_plain_and_rich(plain, rich_inlines, text, inline_source_ref)
        }
      @ddocx.DocxInline::Hyperlink(link) => {
        let source_ref = docx_source_ref_from_key(
          state,
          link.source_key,
          link.relationship_id,
          None,
        )
        plain.write_string(link.text)
        match link.target {
          Some(target) =>
            if target.trim() != "" {
              rich_inlines.push(
                @core.make_inline_link(link.text, target, source_ref~),
              )
              has_link = true
              hyperlink_count += 1
            } else {
              rich_inlines.push(@core.make_inline_text(link.text, source_ref~))
            }
          None =>
            rich_inlines.push(@core.make_inline_text(link.text, source_ref~))
        }
      }
      @ddocx.DocxInline::Media(media) =>
        image_count += lower_docx_media_inline(
          state,
          rich_inlines,
          plain,
          media,
          None,
          [],
        )
      @ddocx.DocxInline::Drawing(drawing) => {
        let media_count = match drawing.media {
          Some(media) =>
            lower_docx_media_inline(
              state,
              rich_inlines,
              plain,
              media,
              drawing.doc_pr_id,
              drawing.alternate_media,
            )
          None => 0
        }
        image_count += media_count
        if media_count == 0 && drawing.child_inlines.length() > 0 {
          let child = lower_docx_inlines(
            state,
            drawing.child_inlines,
            drawing.source_key,
          )
          plain.write_string(child.plain_text)
          rich_inlines.append(child.rich_inlines[:])
          has_link = has_link || child.has_link
          hyperlink_count += child.hyperlink_count
          image_count += child.image_count
          tracked_change_count += child.tracked_change_count
        }
      }
      @ddocx.DocxInline::Shape(shape) => {
        let media_count = match shape.media {
          Some(media) =>
            lower_docx_media_inline(
              state,
              rich_inlines,
              plain,
              media,
              shape.shape_id,
              [],
            )
          None => 0
        }
        image_count += media_count
        if media_count == 0 && shape.child_inlines.length() > 0 {
          let child = lower_docx_inlines(
            state,
            shape.child_inlines,
            shape.source_key,
          )
          plain.write_string(child.plain_text)
          rich_inlines.append(child.rich_inlines[:])
          has_link = has_link || child.has_link
          hyperlink_count += child.hyperlink_count
          image_count += child.image_count
          tracked_change_count += child.tracked_change_count
        }
      }
      @ddocx.DocxInline::ContentControl(control) =>
        if control.inlines.length() > 0 {
          let child = lower_docx_inlines(
            state,
            control.inlines,
            control.source_key,
          )
          plain.write_string(child.plain_text)
          rich_inlines.append(child.rich_inlines[:])
          has_link = has_link || child.has_link
          hyperlink_count += child.hyperlink_count
          image_count += child.image_count
          tracked_change_count += child.tracked_change_count
        } else if control.text.trim() != "" {
          append_plain_and_rich(
            plain,
            rich_inlines,
            control.text,
            docx_source_ref_from_key(state, control.source_key, None, None),
          )
        }
      @ddocx.DocxInline::FieldUnsupported(field) =>
        append_plain_and_rich(
          plain,
          rich_inlines,
          render_docx_field_text(field),
          docx_source_ref_from_key(state, field.source_key, None, None),
        )
      @ddocx.DocxInline::Math(math) =>
        append_plain_and_rich(
          plain,
          rich_inlines,
          render_docx_math_text(math),
          docx_source_ref_from_key(state, math.source_key, None, None),
        )
      @ddocx.DocxInline::Bookmark(_) => ()
      @ddocx.DocxInline::TrackedChange(change) => {
        tracked_change_count += 1
        let text = render_docx_tracked_change_text(change)
        append_plain_and_rich(
          plain,
          rich_inlines,
          text,
          docx_source_ref_from_key(state, change.source_key, None, None),
        )
      }
      @ddocx.DocxInline::SmartTag(smart_tag) => {
        let child = lower_docx_inlines(
          state,
          smart_tag.child_inlines,
          smart_tag.source_key,
        )
        plain.write_string(child.plain_text)
        rich_inlines.append(child.rich_inlines[:])
        has_link = has_link || child.has_link
        hyperlink_count += child.hyperlink_count
        image_count += child.image_count
        tracked_change_count += child.tracked_change_count
      }
      @ddocx.DocxInline::Symbol(symbol) =>
        append_plain_and_rich(
          plain,
          rich_inlines,
          render_docx_symbol_text(symbol),
          docx_source_ref_from_key(state, symbol.source_key, None, None),
        )
      @ddocx.DocxInline::Hyphen(hyphen) =>
        append_plain_and_rich(
          plain,
          rich_inlines,
          render_docx_hyphen_text(hyphen),
          docx_source_ref_from_key(state, hyphen.source_key, None, None),
        )
      @ddocx.DocxInline::FootnoteRef(id) => {
        let marker = docx_note_marker_label(
          state.footnote_labels.get(id).unwrap_or(id),
          "footnote",
        )
        let marker_inline = docx_reference_inline(
          state,
          source_key,
          note_kind="footnote",
          note_id=id,
          marker~,
        )
        plain.write_string(marker)
        rich_inlines.push(marker_inline)
      }
      @ddocx.DocxInline::EndnoteRef(id) => {
        let marker = docx_note_marker_label(
          state.endnote_labels.get(id).unwrap_or(id),
          "endnote",
        )
        let marker_inline = docx_reference_inline(
          state,
          source_key,
          note_kind="endnote",
          note_id=id,
          marker~,
        )
        plain.write_string(marker)
        rich_inlines.push(marker_inline)
      }
      @ddocx.DocxInline::CommentRef(id) => {
        let marker = docx_note_marker_label(
          state.comment_labels.get(id).unwrap_or(id),
          "comment",
        )
        let current = plain.to_string()
        let gap = if !current.has_suffix(" ") { " " } else { "" }
        if gap != "" {
          plain.write_string(gap)
          rich_inlines.push(
            @core.make_inline_text(gap, source_ref=inline_source_ref),
          )
        }
        let marker_inline = docx_reference_inline(
          state,
          source_key,
          note_kind="comment",
          note_id=id,
          marker~,
        )
        plain.write_string(marker)
        rich_inlines.push(marker_inline)
        pending_space_before_comment = false
      }
      @ddocx.DocxInline::StructuralMarker(_) => ()
      @ddocx.DocxInline::TextBoxRef(_) => ()
      @ddocx.DocxInline::UnsupportedInline(_) =>
        append_plain_and_rich(
          plain, rich_inlines, "[unsupported DOCX inline]", inline_source_ref,
        )
      @ddocx.DocxInline::Unsupported(_) => ()
    }
  }
  ignore(pending_space_before_comment)
  let current_hyperlink_count = metric_int(
    state.diagnostics,
    "docx_hyperlink_count",
  )
  state.diagnostics.metrics.set(
    "docx_hyperlink_count",
    (current_hyperlink_count + hyperlink_count).to_string(),
  )
  let normalized_rich_inlines = normalize_docx_marker_rich_inlines(rich_inlines)
  {
    rich_inlines: normalized_rich_inlines,
    plain_text: normalize_docx_ref_marker_spacing(plain.to_string()),
    has_link,
    image_count,
    hyperlink_count,
    tracked_change_count,
  }
}

///|
fn lower_docx_media_inline(
  state : DocxLoweringState,
  rich_inlines : Array[@core.CoreInline],
  plain : StringBuilder,
  media : @ddocx.DocxMediaRef,
  shape_id : String?,
  alternate_media : Array[@ddocx.DocxMediaRef],
) -> Int {
  match media.target_mode {
    Some(@ddocx.DocxTargetMode::External) => {
      state.diagnostics.warnings.push(
        "docx external media is no-fetch and not materialized",
      )
      state.diagnostics.degraded_features.push("docx_external_media_no_fetch")
      bump_metric(state.diagnostics, "skipped_asset_count")
      return 0
    }
    _ => ()
  }
  match media.target_exists {
    Some(false) => {
      state.diagnostics.warnings.push(
        "docx media target missing: " +
        media.target_part.unwrap_or(media.resolved_target.unwrap_or("unknown")),
      )
      bump_metric(state.diagnostics, "skipped_asset_count")
      return 0
    }
    _ => ()
  }
  let target_part = match media.target_part {
    Some(value) => value
    None =>
      match media.resolved_target {
        Some(value) => value
        None => {
          state.diagnostics.warnings.push("docx media target missing")
          bump_metric(state.diagnostics, "skipped_asset_count")
          return 0
        }
      }
  }
  let source_ref = docx_source_ref_from_key(
    state,
    media.source_key,
    media.relationship_id,
    shape_id,
  )
  let alt = docx_image_alt_text(media)
  let title = normalize_docx_optional_text(media.title)
  if !docx_media_should_render_as_image(media, target_part) {
    let placeholder = "[image: " + alt + "]"
    plain.write_string(placeholder)
    rich_inlines.push(
      @core.inline_with_attr(
        @core.make_inline_text(placeholder, source_ref~),
        "render_literal",
        "true",
      ),
    )
    return 0
  }
  let output_path = docx_asset_output_path(state, target_part, media)
  rich_inlines.push(
    @core.make_inline_image(alt, output_path, title~, source_ref~),
  )
  plain.write_string("[image: " + alt + "]")
  let asset = ensure_docx_asset_ref(state, media, output_path, source_ref)
  ignore(asset)
  docx_materialize_companion_assets(state, alternate_media, shape_id)
  bump_metric(state.diagnostics, "docx_image_count")
  1
}

///|
fn docx_paragraph_is_image_only(inline : DocxInlineLowering) -> Bool {
  inline.image_count == 1 &&
  inline.rich_inlines.length() == 1 &&
  inline.rich_inlines[0].kind == @core.InlineKind::Image
}

///|
fn lower_docx_image_only_paragraph(
  _state : DocxLoweringState,
  _p : @ddocx.DocxParagraph,
  inline : DocxInlineLowering,
  source_ref : @core.SourceRef,
) -> @core.CoreBlock {
  let image = inline.rich_inlines[0]
  let block = @core.make_block(@core.BlockKind::Image, "", source_ref~)
  block.attrs.set("path", image.href.unwrap_or("#"))
  block.attrs.set("alt", image.text)
  match image.title {
    Some(title) => block.attrs.set("title", title)
    None => ()
  }
  block
}

///|
fn ensure_docx_asset_ref(
  state : DocxLoweringState,
  media : @ddocx.DocxMediaRef,
  output_path : String,
  source_ref : @core.SourceRef,
) -> @core.AssetRef {
  let target_part = media.target_part.unwrap_or(
    media.resolved_target.unwrap_or(""),
  )
  match state.asset_ids.get(target_part) {
    Some(asset_id) =>
      for asset in state.assets {
        if asset.asset_id == asset_id {
          return asset
        }
      }
    None => ()
  }
  let asset_id = "docx:" + target_part
  let asset = @core.make_asset_ref(
    @core.AssetKind::Image,
    asset_id,
    source_ref~,
  )
  let next_asset = {
    ..asset,
    path: Some(output_path),
    mime_type: media.content_type,
  }
  next_asset.attrs.set("alt", docx_image_alt_text(media))
  next_asset.attrs.set("source_path", target_part)
  next_asset.attrs.set("zip_entry_path", target_part)
  next_asset.attrs.set("zip_container_format", "docx")
  match state.source.path {
    Some(path) => next_asset.attrs.set("zip_container_path", path)
    None => ()
  }
  state.assets.push(next_asset)
  state.asset_ids.set(target_part, asset_id)
  bump_metric(state.diagnostics, "materialized_asset_count")
  next_asset
}

///|
fn docx_asset_output_path(
  state : DocxLoweringState,
  target_part : String,
  media : @ddocx.DocxMediaRef,
) -> String {
  match state.asset_ids.get(target_part) {
    Some(asset_id) =>
      for asset in state.assets {
        if asset.asset_id == asset_id {
          return asset.path.unwrap_or("assets/image01.bin")
        }
      }
    None => ()
  }
  let index = state.assets.length() + 1
  "assets/image" +
  docx_two_digits(index) +
  "." +
  docx_media_output_ext(media, target_part)
}

///|
fn append_docx_comments_blocks(
  state : DocxLoweringState,
  out : Array[@core.CoreBlock],
) -> Unit {
  if state.comment_labels.length() == 0 {
    return
  }
  let comment_ids = docx_note_ids_sorted_by_label(state.comment_labels)
  if comment_ids.length() == 0 {
    return
  }
  let heading = @core.make_block(
    @core.BlockKind::Heading,
    "Comments",
    source_ref=docx_part_source_ref(state, "word/comments.xml", None),
  )
  heading.attrs.set("level", "2")
  out.push(heading)
  for id in comment_ids {
    match docx_lookup_comment(state, id) {
      Some(comment) => {
        let prefix = docx_comment_author_prefix(comment.author)
        let blocks : Array[@core.CoreBlock] = []
        lower_docx_blocks(state, blocks, comment.blocks)
        if blocks.length() == 0 {
          continue
        }
        let inline_images = docx_collect_comment_inline_images(blocks)
        match
          docx_flatten_blocks_to_paragraph_like(
            state,
            blocks,
            comment.source_key,
            prefix~,
          ) {
          Some(item) => {
            let item = docx_comment_block_without_inline_images(item)
            let list_item0 = @core.make_block(
              @core.BlockKind::ListItem,
              item.text,
              source_ref=item.source_ref.unwrap_or(@core.empty_source_ref()),
            )
            let list_item = @core.block_with_rich_inlines(
              list_item0,
              item.rich_inlines,
            )
            list_item.attrs.set("ordered", "true")
            list_item.attrs.set("level", "0")
            list_item.attrs.set("stable_ordered_marker", "true")
            out.push(list_item)
            out.append(inline_images[:])
          }
          None => {
            let first = blocks[0]
            match first.kind {
              @core.BlockKind::Paragraph => {
                let first = docx_comment_block_without_inline_images(first)
                let item0 = @core.make_block(
                  @core.BlockKind::ListItem,
                  prefix + first.text,
                  source_ref=first.source_ref.unwrap_or(
                    @core.empty_source_ref(),
                  ),
                )
                let item = match first.rich_inlines {
                  Some(inlines) =>
                    @core.block_with_rich_inlines(
                      item0,
                      Some(docx_prefixed_rich_inlines(prefix, inlines)),
                    )
                  None => item0
                }
                item.attrs.set("ordered", "true")
                item.attrs.set("level", "0")
                item.attrs.set("stable_ordered_marker", "true")
                out.push(item)
                for i in 1..<blocks.length() {
                  out.push(docx_comment_block_without_inline_images(blocks[i]))
                }
                out.append(inline_images[:])
              }
              _ => {
                let item = @core.make_block(
                  @core.BlockKind::ListItem,
                  prefix.trim().to_owned(),
                  source_ref=docx_source_ref_from_key(
                    state,
                    comment.source_key,
                    None,
                    None,
                  ),
                )
                item.attrs.set("ordered", "true")
                item.attrs.set("level", "0")
                item.attrs.set("stable_ordered_marker", "true")
                out.push(item)
                for block in blocks {
                  out.push(docx_comment_block_without_inline_images(block))
                }
                out.append(inline_images[:])
              }
            }
          }
        }
      }
      None => ()
    }
  }
}

///|
fn docx_prefixed_rich_inlines(
  prefix : String,
  inlines : Array[@core.CoreInline],
) -> Array[@core.CoreInline] {
  if prefix == "" {
    return inlines
  }
  let out : Array[@core.CoreInline] = [@core.make_inline_text(prefix)]
  out.append(inlines[:])
  out
}

///|
fn docx_collect_comment_inline_images(
  blocks : Array[@core.CoreBlock],
) -> Array[@core.CoreBlock] {
  let out : Array[@core.CoreBlock] = []
  for block in blocks {
    match block.rich_inlines {
      Some(inlines) =>
        for inline in inlines {
          if inline.kind == @core.InlineKind::Image {
            let image = @core.make_block(
              @core.BlockKind::Image,
              "",
              source_ref=inline.source_ref.unwrap_or(@core.empty_source_ref()),
            )
            image.attrs.set("path", inline.href.unwrap_or("#"))
            image.attrs.set("alt", inline.text)
            match inline.title {
              Some(title) => image.attrs.set("title", title)
              None => ()
            }
            out.push(image)
          }
        }
      None => ()
    }
  }
  out
}

///|
fn docx_comment_block_without_inline_images(
  block : @core.CoreBlock,
) -> @core.CoreBlock {
  match block.rich_inlines {
    Some(inlines) => {
      let filtered : Array[@core.CoreInline] = []
      let text = StringBuilder::new()
      for inline in inlines {
        if inline.kind == @core.InlineKind::Image {
          continue
        }
        filtered.push(inline)
        text.write_string(docx_comment_inline_text_fragment(inline))
      }
      let normalized_text = docx_comment_cleanup_spacing(text.to_string())
      let next = { ..block, text: normalized_text }
      if filtered.length() == 0 {
        { ..next, rich_inlines: None }
      } else {
        { ..next, rich_inlines: Some(filtered) }
      }
    }
    None => block
  }
}

///|
fn docx_comment_inline_text_fragment(inline : @core.CoreInline) -> String {
  match inline.kind {
    @core.InlineKind::Text | @core.InlineKind::Link | @core.InlineKind::Code =>
      inline.text
    @core.InlineKind::LineBreak => "\n"
    @core.InlineKind::Image => ""
  }
}

///|
fn docx_comment_cleanup_spacing(text : String) -> String {
  let normalized = normalize_docx_ref_marker_spacing(text)
  normalized.replace(old=" \n", new="\n").replace(old="\n ", new="\n")
}

///|
fn append_docx_note_definitions_blocks(
  state : DocxLoweringState,
  out : Array[@core.CoreBlock],
) -> Unit {
  let footnote_ids = docx_note_ids_sorted_by_label(state.footnote_labels)
  for id in footnote_ids {
    match docx_lookup_footnote(state, id) {
      Some(note) =>
        append_docx_note_definition_blocks(
          state,
          out,
          note.blocks,
          state.footnote_labels.get(id).unwrap_or(id),
          note.source_key,
        )
      None => ()
    }
  }
  let endnote_ids = docx_note_ids_sorted_by_label(state.endnote_labels)
  for id in endnote_ids {
    match docx_lookup_endnote(state, id) {
      Some(note) =>
        append_docx_note_definition_blocks(
          state,
          out,
          note.blocks,
          "e" + state.endnote_labels.get(id).unwrap_or(id),
          note.source_key,
        )
      None => ()
    }
  }
}

///|
fn docx_note_ids_sorted_by_label(labels : Map[String, String]) -> Array[String] {
  let keyed = labels.to_array()
  keyed.sort_by(fn(a, b) {
    let a_order = docx_sortable_note_label(a.1)
    let b_order = docx_sortable_note_label(b.1)
    let primary = a_order.compare(b_order)
    if primary != 0 {
      primary
    } else {
      a.0.compare(b.0)
    }
  })
  keyed.map(fn(entry) { entry.0 })
}

///|
fn docx_sortable_note_label(label : String) -> String {
  let trimmed = label.trim().to_owned()
  let parsed = @string.parse_int(trimmed) catch { _ => return "1:" + trimmed }
  "0:" + docx_zero_pad_int(parsed, 12)
}

///|
fn docx_zero_pad_int(value : Int, width : Int) -> String {
  let raw = value.to_string()
  if raw.length() >= width {
    raw
  } else {
    "0".repeat(width - raw.length()) + raw
  }
}

///|
fn append_docx_note_definition_blocks(
  state : DocxLoweringState,
  out : Array[@core.CoreBlock],
  blocks : Array[@ddocx.DocxBlock],
  note_id : String,
  source_key : @ddocx.DocxSourceKey,
) -> Unit {
  let lowered : Array[@core.CoreBlock] = []
  lower_docx_blocks(state, lowered, blocks)
  if lowered.length() == 0 {
    return
  }
  let note = match
    docx_flatten_blocks_to_paragraph_like(state, lowered, source_key) {
    Some(block) => docx_note_block_with_inline_breaks(block)
    None => {
      let first = lowered[0]
      let note0 = @core.make_block(
        @core.BlockKind::Paragraph,
        first.text,
        source_ref=first.source_ref.unwrap_or(
          docx_source_ref_from_key(state, source_key, None, None),
        ),
      )
      @core.block_with_rich_inlines(note0, first.rich_inlines)
    }
  }
  note.attrs.set("note_definition_id", note_id)
  note.attrs.set("note_definition_kind", "docx")
  out.push(note)
}

///|
fn docx_note_block_with_inline_breaks(
  block : @core.CoreBlock,
) -> @core.CoreBlock {
  match block.rich_inlines {
    Some(inlines) => {
      let expanded : Array[@core.CoreInline] = []
      for inline in inlines {
        if inline.kind == @core.InlineKind::Text && inline.text.contains("\n") {
          let parts = inline.text
            .replace(old="\r\n", new="\n")
            .replace(old="\r", new="\n")
            .split("\n")
            .to_array()
          for i in 0..<parts.length() {
            if i > 0 {
              expanded.push(
                @core.make_inline_line_break(
                  source_ref=inline.source_ref.unwrap_or(
                    @core.empty_source_ref(),
                  ),
                ),
              )
            }
            let part = parts[i].to_owned()
            if part != "" {
              expanded.push(
                @core.make_inline_text(
                  part,
                  source_ref=inline.source_ref.unwrap_or(
                    @core.empty_source_ref(),
                  ),
                ),
              )
            }
          }
        } else {
          expanded.push(inline)
        }
      }
      @core.block_with_rich_inlines(block, Some(expanded))
    }
    None => block
  }
}

///|
fn append_docx_part_body_blocks(
  state : DocxLoweringState,
  out : Array[@core.CoreBlock],
  bodies : Array[@ddocx.DocxPartBody],
  section_title : String,
  item_title : String,
) -> Unit {
  let visible : Array[@ddocx.DocxPartBody] = []
  for body in bodies {
    if docx_blocks_have_visible_content(body.blocks) ||
      docx_part_body_has_visible_textboxes(state, body) {
      visible.push(body)
    }
  }
  if visible.length() == 0 {
    return
  }
  let heading = @core.make_block(
    @core.BlockKind::Heading,
    section_title,
    source_ref=docx_part_source_ref(
      state,
      visible[0].part_name,
      visible[0].relationship_id,
    ),
  )
  heading.attrs.set("level", "2")
  out.push(heading)
  let mut index = 1
  for body in visible {
    let title = item_title +
      " " +
      index.to_string() +
      " " +
      docx_part_body_slot_label(body)
    let body_heading = @core.make_block(
      @core.BlockKind::Heading,
      title,
      source_ref=docx_part_source_ref(
        state,
        body.part_name,
        body.relationship_id,
      ),
    )
    body_heading.attrs.set("level", "3")
    out.push(body_heading)
    append_docx_body_blocks_with_textboxes(state, out, body)
    index += 1
  }
  state.diagnostics.metrics.set(
    "docx_header_footer_count",
    visible.length().to_string(),
  )
}

///|
fn append_docx_body_blocks_with_textboxes(
  state : DocxLoweringState,
  out : Array[@core.CoreBlock],
  body : @ddocx.DocxPartBody,
) -> Unit {
  let blocks : Array[@core.CoreBlock] = []
  lower_docx_blocks(state, blocks, body.blocks)
  let textbox_blocks = docx_textbox_blocks_for_body(state, body)
  if blocks.length() == 0 && textbox_blocks.length() == 0 {
    return
  }
  let merged_blocks : Array[@core.CoreBlock] = []
  merged_blocks.append(blocks[:])
  merged_blocks.append(textbox_blocks[:])
  match
    docx_flatten_blocks_to_paragraph_like(state, merged_blocks, body.source_key) {
    Some(merged) => out.push(merged)
    None => out.append(blocks[:])
  }
}

///|
fn docx_part_body_has_visible_textboxes(
  state : DocxLoweringState,
  body : @ddocx.DocxPartBody,
) -> Bool {
  for textbox in state.docx.textboxes {
    if textbox.owner_part != body.part_name {
      continue
    }
    if body.relationship_id != textbox.relationship_id {
      continue
    }
    if docx_blocks_have_visible_content(textbox.blocks) {
      return true
    }
  }
  false
}

///|
fn docx_textbox_blocks_for_body(
  state : DocxLoweringState,
  body : @ddocx.DocxPartBody,
) -> Array[@core.CoreBlock] {
  let blocks : Array[@core.CoreBlock] = []
  for textbox in state.docx.textboxes {
    if textbox.owner_part != body.part_name {
      continue
    }
    if body.relationship_id != textbox.relationship_id {
      continue
    }
    if !docx_blocks_have_visible_content(textbox.blocks) {
      continue
    }
    lower_docx_blocks(state, blocks, textbox.blocks)
  }
  blocks
}

///|
fn append_docx_textboxes_blocks(
  state : DocxLoweringState,
  out : Array[@core.CoreBlock],
) -> Unit {
  let visible : Array[@ddocx.DocxTextBox] = []
  for textbox in state.docx.textboxes {
    if docx_blocks_have_visible_content(textbox.blocks) {
      visible.push(textbox)
    }
  }
  if visible.length() == 0 {
    return
  }
  let heading = @core.make_block(
    @core.BlockKind::Heading,
    "Text Boxes",
    source_ref=docx_part_source_ref(
      state,
      visible[0].part_name,
      visible[0].relationship_id,
    ),
  )
  heading.attrs.set("level", "2")
  out.push(heading)
  let mut index = 1
  for textbox in visible {
    let title = docx_textbox_appendix_title(textbox, index)
    let box_heading = @core.make_block(
      @core.BlockKind::Heading,
      title,
      source_ref=docx_source_ref_from_key(
        state,
        textbox.source_key,
        textbox.relationship_id,
        textbox.shape_id,
      ),
    )
    box_heading.attrs.set("level", "3")
    out.push(box_heading)
    let blocks : Array[@core.CoreBlock] = []
    lower_docx_blocks(state, blocks, textbox.blocks)
    out.append(blocks[:])
    index += 1
  }
}

///|
fn docx_flatten_blocks_to_paragraph_like(
  state : DocxLoweringState,
  blocks : Array[@core.CoreBlock],
  source_key : @ddocx.DocxSourceKey,
  prefix? : String = "",
) -> @core.CoreBlock? {
  let rich : Array[@core.CoreInline] = []
  let plain = StringBuilder::new()
  let source_ref = docx_source_ref_from_key(state, source_key, None, None)
  let mut saw_content = false
  let mut is_first = true

  fn append_text(
    plain : StringBuilder,
    rich : Array[@core.CoreInline],
    text : String,
    source_ref : @core.SourceRef,
  ) -> Unit {
    if text == "" {
      return
    }
    plain.write_string(text)
    rich.push(@core.make_inline_text(text, source_ref~))
  }

  fn append_break(
    plain : StringBuilder,
    rich : Array[@core.CoreInline],
    source_ref : @core.SourceRef,
  ) -> Unit {
    plain.write_string("\n")
    rich.push(@core.make_inline_line_break(source_ref~))
  }

  fn append_separator(
    plain : StringBuilder,
    rich : Array[@core.CoreInline],
    source_ref : @core.SourceRef,
  ) -> Unit {
    if rich.length() > 0 {
      append_break(plain, rich, source_ref)
    }
  }

  if prefix != "" {
    append_text(plain, rich, prefix, source_ref)
    saw_content = true
    is_first = true
  }

  for block in blocks {
    match block.kind {
      @core.BlockKind::Paragraph
      | @core.BlockKind::Heading
      | @core.BlockKind::ListItem => {
        if saw_content && !is_first {
          append_separator(plain, rich, block.source_ref.unwrap_or(source_ref))
        }
        let trimmed_text = block.text.trim().to_owned()
        if docx_block_has_rich_inlines(block) {
          let inlines = block.rich_inlines.unwrap_or([])
          if trimmed_text == "" &&
            inlines.length() > 0 &&
            docx_all_rich_inlines_are_breaks(inlines) {
            continue
          }
          if trimmed_text == "" && inlines.length() > 0 {
            let filtered = docx_trim_boundary_line_breaks(inlines)
            if filtered.length() == 0 {
              continue
            }
            rich.append(filtered[:])
          } else {
            let filtered = if prefix != "" && is_first {
              docx_trim_leading_line_breaks(inlines)
            } else {
              inlines
            }
            if filtered.length() == 0 {
              continue
            }
            rich.append(filtered[:])
          }
          plain.write_string(block.text)
        } else {
          if trimmed_text == "" {
            continue
          }
          append_text(
            plain,
            rich,
            block.text,
            block.source_ref.unwrap_or(source_ref),
          )
        }
        saw_content = true
        is_first = false
      }
      @core.BlockKind::List => {
        let flattened = docx_flatten_blocks_to_paragraph_like(
          state,
          block.children,
          source_key,
        )
        match flattened {
          Some(value) => {
            if saw_content && !is_first {
              append_separator(
                plain,
                rich,
                value.source_ref.unwrap_or(source_ref),
              )
            }
            if docx_block_has_rich_inlines(value) {
              rich.append(value.rich_inlines.unwrap_or([])[:])
              plain.write_string(value.text)
            } else {
              append_text(
                plain,
                rich,
                value.text,
                value.source_ref.unwrap_or(source_ref),
              )
            }
            saw_content = true
            is_first = false
          }
          None => ()
        }
      }
      _ => ()
    }
  }

  if !saw_content {
    return None
  }
  let text = normalize_docx_ref_marker_spacing(plain.to_string())
  let block0 = @core.make_block(@core.BlockKind::Paragraph, text, source_ref~)
  if rich.length() == 0 {
    Some(block0)
  } else {
    Some(@core.block_with_rich_inlines(block0, Some(rich)))
  }
}

///|
fn docx_block_has_rich_inlines(block : @core.CoreBlock) -> Bool {
  match block.rich_inlines {
    Some(inlines) => inlines.length() > 0
    None => false
  }
}

///|
fn docx_all_rich_inlines_are_breaks(inlines : Array[@core.CoreInline]) -> Bool {
  if inlines.length() == 0 {
    return false
  }
  for inline in inlines {
    if inline.kind != @core.InlineKind::LineBreak {
      return false
    }
  }
  true
}

///|
fn docx_trim_boundary_line_breaks(
  inlines : Array[@core.CoreInline],
) -> Array[@core.CoreInline] {
  let start = docx_first_non_break_inline_index(inlines)
  let end = docx_last_non_break_inline_index(inlines)
  let start_index = match start {
    Some(value) => value
    None => return []
  }
  let end_index = match end {
    Some(value) => value
    None => return []
  }
  if start_index > end_index {
    return []
  }
  let trimmed : Array[@core.CoreInline] = []
  let stop = end_index + 1
  for i in start_index..<stop {
    trimmed.push(inlines[i])
  }
  trimmed
}

///|
fn docx_trim_leading_line_breaks(
  inlines : Array[@core.CoreInline],
) -> Array[@core.CoreInline] {
  let start = docx_first_non_break_inline_index(inlines)
  let start_index = match start {
    Some(value) => value
    None => return []
  }
  let trimmed : Array[@core.CoreInline] = []
  for i in start_index..<inlines.length() {
    trimmed.push(inlines[i])
  }
  trimmed
}

///|
fn docx_first_non_break_inline_index(inlines : Array[@core.CoreInline]) -> Int? {
  for i in 0..<inlines.length() {
    if inlines[i].kind != @core.InlineKind::LineBreak {
      return Some(i)
    }
  }
  None
}

///|
fn docx_last_non_break_inline_index(inlines : Array[@core.CoreInline]) -> Int? {
  let mut i = inlines.length() - 1
  while i >= 0 {
    if inlines[i].kind != @core.InlineKind::LineBreak {
      return Some(i)
    }
    if i == 0 {
      break
    }
    i -= 1
  }
  None
}

///|
fn collect_docx_reference_ids(
  blocks : Array[@ddocx.DocxBlock],
  footnote_ids : Array[String],
  endnote_ids : Array[String],
  comment_ids : Array[String],
) -> Unit {
  for block in blocks {
    match block {
      @ddocx.DocxBlock::Paragraph(p) =>
        collect_docx_inline_reference_ids(
          p.inlines,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
      @ddocx.DocxBlock::Table(table) =>
        for row in table.rows {
          for cell in row.cells {
            collect_docx_reference_ids(
              cell.blocks,
              footnote_ids,
              endnote_ids,
              comment_ids,
            )
          }
        }
      @ddocx.DocxBlock::ContentControl(control) => {
        collect_docx_reference_ids(
          control.blocks,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
        collect_docx_inline_reference_ids(
          control.inlines,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
      }
      _ => ()
    }
  }
}

///|
fn collect_docx_inline_reference_ids(
  inlines : Array[@ddocx.DocxInline],
  footnote_ids : Array[String],
  endnote_ids : Array[String],
  comment_ids : Array[String],
) -> Unit {
  for inline in inlines {
    match inline {
      @ddocx.DocxInline::FootnoteRef(id) => push_unique_string(footnote_ids, id)
      @ddocx.DocxInline::EndnoteRef(id) => push_unique_string(endnote_ids, id)
      @ddocx.DocxInline::CommentRef(id) => push_unique_string(comment_ids, id)
      @ddocx.DocxInline::Drawing(drawing) =>
        collect_docx_inline_reference_ids(
          drawing.child_inlines,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
      @ddocx.DocxInline::Shape(shape) =>
        collect_docx_inline_reference_ids(
          shape.child_inlines,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
      @ddocx.DocxInline::ContentControl(control) => {
        collect_docx_reference_ids(
          control.blocks,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
        collect_docx_inline_reference_ids(
          control.inlines,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
      }
      @ddocx.DocxInline::FieldUnsupported(field) =>
        collect_docx_inline_reference_ids(
          field.child_inlines,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
      @ddocx.DocxInline::Math(math) =>
        collect_docx_inline_reference_ids(
          math.child_inlines,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
      @ddocx.DocxInline::TrackedChange(change) =>
        collect_docx_inline_reference_ids(
          change.child_inlines,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
      @ddocx.DocxInline::SmartTag(smart_tag) =>
        collect_docx_inline_reference_ids(
          smart_tag.child_inlines,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
      _ => ()
    }
  }
}

///|
fn push_unique_string(items : Array[String], value : String) -> Unit {
  for existing in items {
    if existing == value {
      return
    }
  }
  items.push(value)
}

///|
fn docx_source_ref_from_key(
  state : DocxLoweringState,
  key : @ddocx.DocxSourceKey,
  relationship_id : String?,
  shape_id : String?,
) -> @core.SourceRef {
  let container_path = state.source.path.unwrap_or(state.source.source_name)
  let base = @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some(state.source.source_name),
    Some("docx"),
    Some(container_path),
    Some(key.part_name),
    None,
    Some("xml"),
    Some(key.part_name),
  )
  let office = @core.source_ref_with_office_fields(
    base,
    Some(state.source.source_name),
    Some("docx"),
    Some(key.part_name),
    None,
    None,
    None,
    shape_id,
    relationship_id,
  )
  let with_block = @core.source_ref_with_extra(
    @core.source_ref_with_extra(
      @core.source_ref_with_extra(office, "part_name", key.part_name),
      "block_index",
      key.block_index.to_string(),
    ),
    "paragraph_index",
    key.block_index.to_string(),
  )
  @core.source_ref_with_extra(with_block, "node_key", key.node_key)
}

///|
fn docx_part_source_ref(
  state : DocxLoweringState,
  part_name : String,
  relationship_id : String?,
) -> @core.SourceRef {
  let container_path = state.source.path.unwrap_or(state.source.source_name)
  let base = @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some(state.source.source_name),
    Some("docx"),
    Some(container_path),
    Some(part_name),
    None,
    Some("xml"),
    Some(part_name),
  )
  let office = @core.source_ref_with_office_fields(
    base,
    Some(state.source.source_name),
    Some("docx"),
    Some(part_name),
    None,
    None,
    None,
    None,
    relationship_id,
  )
  @core.source_ref_with_extra(office, "part_name", part_name)
}

///|
fn bump_metric(diagnostics : @core.Diagnostics, key : String) -> Unit {
  let current = metric_int(diagnostics, key)
  diagnostics.metrics.set(key, (current + 1).to_string())
}

///|
fn count_docx_macro_parts(parts : Array[@ox.OoxmlPartInfo]) -> Int {
  let mut count = 0
  for part in parts {
    match part.content_type {
      Some(value) => if value.contains("macroEnabled") { count += 1 }
      None => ()
    }
  }
  count
}

///|
fn count_docx_ole_object_parts(parts : Array[@ox.OoxmlPartInfo]) -> Int {
  let mut count = 0
  for part in parts {
    if part.part_name.contains("/embeddings/") ||
      part.part_name.contains("oleObject") {
      count += 1
    }
  }
  count
}

///|
fn docx_media_path_ext(path : String) -> String {
  let trimmed = path.trim().to_lower()
  match trimmed.split(".").to_array().last() {
    Some(ext) =>
      if ext == "png" ||
        ext == "jpg" ||
        ext == "jpeg" ||
        ext == "gif" ||
        ext == "bmp" ||
        ext == "tif" ||
        ext == "tiff" ||
        ext == "webp" ||
        ext == "svg" {
        if ext == "jpeg" {
          "jpg"
        } else {
          ext.to_owned()
        }
      } else {
        "bin"
      }
    None => "bin"
  }
}

///|
fn docx_media_content_type_ext(content_type : String?) -> String? {
  match content_type {
    Some(value) => {
      let lower = value.trim().to_lower()
      if lower == "image/png" {
        Some("png")
      } else if lower == "image/jpeg" || lower == "image/jpg" {
        Some("jpg")
      } else if lower == "image/gif" {
        Some("gif")
      } else if lower == "image/bmp" {
        Some("bmp")
      } else if lower == "image/tif" || lower == "image/tiff" {
        Some("tiff")
      } else if lower == "image/webp" {
        Some("webp")
      } else if lower == "image/svg+xml" {
        Some("svg")
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn docx_media_output_ext(
  media : @ddocx.DocxMediaRef,
  target_part : String,
) -> String {
  match docx_media_content_type_ext(media.content_type) {
    Some(ext) => ext
    None => docx_media_path_ext(target_part)
  }
}

///|
fn docx_media_should_render_as_image(
  media : @ddocx.DocxMediaRef,
  target_part : String,
) -> Bool {
  let ext = docx_media_output_ext(media, target_part)
  ext == "png" ||
  ext == "jpg" ||
  ext == "gif" ||
  ext == "bmp" ||
  ext == "tiff" ||
  ext == "webp" ||
  ext == "svg"
}

///|
fn docx_media_should_export_asset(
  media : @ddocx.DocxMediaRef,
  target_part : String,
) -> Bool {
  docx_media_should_render_as_image(media, target_part)
}

///|
fn docx_materialize_companion_assets(
  state : DocxLoweringState,
  companions : Array[@ddocx.DocxMediaRef],
  shape_id : String?,
) -> Unit {
  for media in companions {
    match media.target_mode {
      Some(@ddocx.DocxTargetMode::External) => continue
      _ => ()
    }
    if media.target_exists == Some(false) {
      continue
    }
    let target_part = match media.target_part {
      Some(value) => value
      None => continue
    }
    if !docx_media_should_export_asset(media, target_part) {
      continue
    }
    let source_ref = docx_source_ref_from_key(
      state,
      media.source_key,
      media.relationship_id,
      shape_id,
    )
    let output_path = docx_asset_output_path(state, target_part, media)
    let asset = ensure_docx_asset_ref(state, media, output_path, source_ref)
    ignore(asset)
  }
}

///|
fn docx_two_digits(value : Int) -> String {
  if value < 10 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn docx_image_alt_text(media : @ddocx.DocxMediaRef) -> String {
  match media.alt_text {
    Some(value) => if value.trim() != "" { return value.trim().to_owned() }
    None => ()
  }
  match media.title {
    Some(value) => if value.trim() != "" { return value.trim().to_owned() }
    None => ()
  }
  "image"
}

///|
fn normalize_docx_optional_text(value : String?) -> String? {
  match value {
    Some(text) =>
      if text.trim() == "" {
        None
      } else {
        Some(text.trim().to_owned())
      }
    None => None
  }
}

///|
fn docx_note_marker_label(label : String, note_kind : String) -> String {
  match note_kind {
    "comment" => "[comment " + label + "]"
    "endnote" => "[^e" + label + "]"
    _ => "[^" + label + "]"
  }
}

///|
fn docx_reference_inline(
  state : DocxLoweringState,
  source_key : @ddocx.DocxSourceKey,
  note_kind~ : String,
  note_id~ : String,
  marker~ : String,
) -> @core.CoreInline {
  let source_ref = docx_source_ref_from_key(state, source_key, None, None)
  let inline = @core.make_inline_text(marker, source_ref~)
  let inline = @core.inline_with_attr(inline, "annotation_role", "note_ref")
  let inline = @core.inline_with_attr(inline, "annotation_kind", note_kind)
  let inline = @core.inline_with_attr(inline, "annotation_id", note_id)
  let inline = @core.inline_with_attr(inline, "annotation_marker", marker)
  @core.inline_with_attr(inline, "render_literal", "true")
}

///|
fn docx_inline_spacing_source_ref(
  source_ref : @core.SourceRef,
) -> @core.SourceRef {
  source_ref
}

///|
fn docx_paragraph_heading_level(
  style : @ddocx.DocxStyle?,
  p : @ddocx.DocxParagraph,
) -> Int? {
  ignore(p)
  match style {
    Some(value) => docx_style_heading_level(value)
    None => None
  }
}

///|
fn docx_style_heading_level(style : @ddocx.DocxStyle) -> Int? {
  match docx_heading_level_from_label(style.style_id) {
    Some(level) => Some(level)
    None =>
      match style.name {
        Some(name) => docx_heading_level_from_label(name)
        None => None
      }
  }
}

///|
fn docx_heading_level_from_label(label : String) -> Int? {
  let normalized = docx_normalize_style_label(label)
  if normalized == "heading1" {
    Some(1)
  } else if normalized == "heading2" {
    Some(2)
  } else if normalized == "heading3" {
    Some(3)
  } else if normalized == "heading4" {
    Some(4)
  } else if normalized == "heading5" {
    Some(5)
  } else if normalized == "heading6" {
    Some(6)
  } else {
    None
  }
}

///|
fn docx_paragraph_list_lowering(
  docx : @ddocx.DocxDocument,
  p : @ddocx.DocxParagraph,
) -> (Bool, Int)? {
  match docx_resolve_paragraph_list_level(docx, p) {
    Some(level) =>
      match level.num_fmt {
        Some(num_fmt) => {
          let normalized = docx_normalize_style_label(num_fmt)
          if normalized == "bullet" {
            Some((false, docx_numbering_level_index(level.ilvl)))
          } else if normalized == "decimal" {
            Some((true, docx_numbering_level_index(level.ilvl)))
          } else {
            None
          }
        }
        None => None
      }
    None => None
  }
}

///|
fn docx_resolve_paragraph_list_level(
  docx : @ddocx.DocxDocument,
  p : @ddocx.DocxParagraph,
) -> @ddocx.DocxNumberingLevel? {
  match @ddocx.docx_resolve_paragraph_numbering_level(docx, p) {
    Some(level) => return Some(level)
    None => ()
  }
  let style_id = match p.style_id {
    Some(value) => docx_normalize_style_label(value)
    None => return None
  }
  for level in docx.numbering.levels {
    if docx_numbering_level_style_matches(level, style_id) {
      return Some(level)
    }
  }
  None
}

///|
fn docx_numbering_level_style_matches(
  level : @ddocx.DocxNumberingLevel,
  normalized_style_id : String,
) -> Bool {
  match level.paragraph_style_id {
    Some(value) =>
      if docx_normalize_style_label(value) == normalized_style_id {
        return true
      }
    None => ()
  }
  match level.style_link {
    Some(value) =>
      if docx_normalize_style_label(value) == normalized_style_id {
        return true
      }
    None => ()
  }
  match level.num_style_link {
    Some(value) =>
      if docx_normalize_style_label(value) == normalized_style_id {
        return true
      }
    None => ()
  }
  false
}

///|
fn docx_numbering_level_index(ilvl : String) -> Int {
  match docx_parse_nonnegative_int(ilvl) {
    Some(value) => value
    None => 0
  }
}

///|
fn docx_paragraph_is_code_style(
  style : @ddocx.DocxStyle?,
  p : @ddocx.DocxParagraph,
  plain_text : String,
) -> Bool {
  match style {
    Some(value) =>
      docx_style_label_matches(value, [
        "code", "pre", "preformatted", "htmlpreformatted", "sourcecode",
      ]) ||
      docx_paragraph_has_code_shape(p, plain_text)
    None =>
      match p.style_id {
        Some(style_id) =>
          docx_style_labels_match(style_id, None, [
            "code", "pre", "preformatted", "htmlpreformatted", "sourcecode",
          ]) ||
          docx_paragraph_has_code_shape(p, plain_text)
        None => docx_paragraph_has_code_shape(p, plain_text)
      }
  }
}

///|
fn docx_paragraph_is_quote_style(
  style : @ddocx.DocxStyle?,
  p : @ddocx.DocxParagraph,
) -> Bool {
  match style {
    Some(value) =>
      docx_style_label_matches(value, [
        "quote", "intensequote", "blockquote", "blockquotetext",
      ])
    None =>
      match p.style_id {
        Some(style_id) =>
          docx_style_labels_match(style_id, None, [
            "quote", "intensequote", "blockquote", "blockquotetext",
          ])
        None => false
      }
  }
}

///|
fn docx_style_label_matches(
  style : @ddocx.DocxStyle,
  labels : Array[String],
) -> Bool {
  docx_style_labels_match(style.style_id, style.name, labels)
}

///|
fn docx_style_labels_match(
  style_id_raw : String,
  style_name_raw : String?,
  labels : Array[String],
) -> Bool {
  let style_id = docx_normalize_style_label(style_id_raw)
  for label in labels {
    if style_id == label {
      return true
    }
  }
  match style_name_raw {
    Some(name) => {
      let style_name = docx_normalize_style_label(name)
      for label in labels {
        if style_name == label {
          return true
        }
      }
      false
    }
    None => false
  }
}

///|
fn docx_lookup_footnote(
  state : DocxLoweringState,
  note_id : String,
) -> @ddocx.DocxNote? {
  state.footnotes_by_id.get(note_id)
}

///|
fn docx_lookup_endnote(
  state : DocxLoweringState,
  note_id : String,
) -> @ddocx.DocxNote? {
  state.endnotes_by_id.get(note_id)
}

///|
fn docx_lookup_comment(
  state : DocxLoweringState,
  comment_id : String,
) -> @ddocx.DocxComment? {
  state.comments_by_id.get(comment_id)
}

///|
fn docx_paragraph_has_code_shape(
  p : @ddocx.DocxParagraph,
  plain_text : String,
) -> Bool {
  let normalized = plain_text
    .replace(old="\r\n", new="\n")
    .replace(old="\r", new="\n")
  if !normalized.contains("\n") {
    return false
  }
  if docx_paragraph_alignment_is_center(p) {
    return false
  }
  let lines = normalized
    .split("\n")
    .map(fn(value) { value.to_owned() })
    .filter(fn(value) { value.trim() != "" })
    .iter()
    .collect()
  if lines.length() < 2 {
    return false
  }
  let mut text_like_line_count = 0
  let mut codeish = false
  for line in lines {
    let trimmed = line.trim()
    if trimmed != "" {
      text_like_line_count += 1
    }
    if trimmed.contains("=") ||
      trimmed.contains("(") ||
      trimmed.contains(")") ||
      trimmed.contains(";") ||
      trimmed.contains("{") ||
      trimmed.contains("}") {
      codeish = true
    }
  }
  if codeish {
    return true
  }
  ignore(text_like_line_count)
  false
}

///|
fn render_docx_plain_text_only(inlines : Array[@ddocx.DocxInline]) -> String {
  let out = StringBuilder::new()
  for inline in inlines {
    match inline {
      @ddocx.DocxInline::Text(text) => out.write_string(text)
      @ddocx.DocxInline::Tab => out.write_string("\t")
      @ddocx.DocxInline::LineBreak => out.write_string("\n")
      @ddocx.DocxInline::Break(value) =>
        out.write_string(render_docx_break_text(value))
      @ddocx.DocxInline::Hyperlink(link) => out.write_string(link.text)
      @ddocx.DocxInline::ContentControl(control) =>
        out.write_string(control.text)
      @ddocx.DocxInline::FieldUnsupported(field) =>
        out.write_string(render_docx_field_text(field))
      @ddocx.DocxInline::Math(math) =>
        out.write_string(render_docx_math_text(math))
      @ddocx.DocxInline::TrackedChange(change) =>
        out.write_string(render_docx_tracked_change_text(change))
      @ddocx.DocxInline::SmartTag(smart_tag) =>
        out.write_string(render_docx_plain_text_only(smart_tag.child_inlines))
      @ddocx.DocxInline::Symbol(symbol) =>
        out.write_string(render_docx_symbol_text(symbol))
      @ddocx.DocxInline::Hyphen(hyphen) =>
        out.write_string(render_docx_hyphen_text(hyphen))
      @ddocx.DocxInline::FootnoteRef(id) =>
        out.write_string(docx_note_marker_label(id, "footnote"))
      @ddocx.DocxInline::EndnoteRef(id) =>
        out.write_string(docx_note_marker_label(id, "endnote"))
      @ddocx.DocxInline::CommentRef(id) =>
        out.write_string(" " + docx_note_marker_label(id, "comment"))
      _ => ()
    }
  }
  normalize_docx_ref_marker_spacing(out.to_string())
}

///|
fn docx_paragraph_alignment_is_center(p : @ddocx.DocxParagraph) -> Bool {
  match p.alignment {
    Some(value) => docx_normalize_style_label(value) == "center"
    None => false
  }
}

///|
fn docx_paragraph_is_page_number_field_only(p : @ddocx.DocxParagraph) -> Bool {
  let text = render_docx_plain_text_only(p.inlines).trim().to_owned()
  if text == "" {
    return false
  }
  let mut saw_page_field = false
  for inline in p.inlines {
    match inline {
      @ddocx.DocxInline::FieldUnsupported(field) =>
        match field.instruction {
          Some(instruction) =>
            if docx_normalize_style_label(instruction).contains("page") {
              saw_page_field = true
            }
          None => ()
        }
      _ => ()
    }
  }
  if !saw_page_field {
    return false
  }
  let normalized = docx_normalize_style_label(text)
    .replace(old="[", new="")
    .replace(old="]", new="")
  let digits_only = normalized
    .replace(old="page", new="")
    .replace(old=" ", new="")
  if digits_only == "" {
    return false
  }
  for ch in digits_only {
    if ch < '0' || ch > '9' {
      return false
    }
  }
  true
}

///|
fn docx_list_item_text(text : String) -> String {
  text
  .replace(old="\r\n", new="\n")
  .replace(old="\r", new="\n")
  .split("\n")
  .map(fn(value) { value.trim().to_owned() })
  .filter(fn(value) { value != "" })
  .iter()
  .collect()
  .join("<br>")
}

///|
fn render_docx_break_text(value : @ddocx.DocxBreak) -> String {
  match value.kind {
    @ddocx.DocxBreakKind::Line => "\n"
    @ddocx.DocxBreakKind::CarriageReturn => "\n"
    @ddocx.DocxBreakKind::TextWrapping => "\n"
    @ddocx.DocxBreakKind::Page => "\n"
    @ddocx.DocxBreakKind::Column => "\n"
    @ddocx.DocxBreakKind::Unknown => ""
  }
}

///|
fn render_docx_field_text(field : @ddocx.DocxField) -> String {
  match field.result_text {
    Some(value) => value
    None =>
      match field.instruction {
        Some(value) => "[" + value + "]"
        None => ""
      }
  }
}

///|
fn render_docx_math_text(math : @ddocx.DocxMath) -> String {
  match math.text_signature {
    Some(value) => value
    None => "[math]"
  }
}

///|
fn render_docx_tracked_change_text(change : @ddocx.DocxTrackedChange) -> String {
  if change.text.trim() != "" {
    change.text
  } else {
    render_docx_plain_text_only(change.child_inlines)
  }
}

///|
fn render_docx_symbol_text(symbol : @ddocx.DocxSymbol) -> String {
  match parse_docx_hex_codepoint(symbol.char_hex) {
    Some(codepoint) =>
      if codepoint >= 0x20 && codepoint <= 0x7E {
        String::from_array([Int::unsafe_to_char(codepoint)])
      } else {
        ""
      }
    None => ""
  }
}

///|
fn render_docx_hyphen_text(hyphen : @ddocx.DocxHyphen) -> String {
  match hyphen.kind {
    @ddocx.DocxHyphenKind::Soft => ""
    @ddocx.DocxHyphenKind::NoBreak => "-"
  }
}

///|
fn parse_docx_hex_codepoint(value : String?) -> Int? {
  match value {
    Some(text) => {
      let trimmed = text.trim().to_owned()
      if trimmed == "" {
        return None
      }
      let chars = trimmed.to_array()
      let mut acc = 0
      for ch in chars {
        let digit = if ch >= '0' && ch <= '9' {
          ch.to_int() - '0'.to_int()
        } else if ch >= 'A' && ch <= 'F' {
          10 + ch.to_int() - 'A'.to_int()
        } else if ch >= 'a' && ch <= 'f' {
          10 + ch.to_int() - 'a'.to_int()
        } else {
          return None
        }
        acc = acc * 16 + digit
      }
      Some(acc)
    }
    None => None
  }
}

///|
fn docx_comment_author_prefix(author : String?) -> String {
  match author {
    Some(value) =>
      if value.trim() == "" {
        ""
      } else {
        value.trim().to_owned() + ": "
      }
    None => ""
  }
}

///|
fn docx_part_body_slot_label(body : @ddocx.DocxPartBody) -> String {
  match body.slot_type {
    Some(value) => docx_part_body_slot_label_from_text(value)
    None =>
      match body.relationship_id {
        Some(value) => docx_part_body_slot_label_from_text(value)
        None => "Default"
      }
  }
}

///|
fn docx_part_body_slot_label_from_text(value : String) -> String {
  let normalized = docx_normalize_style_label(value)
  if normalized.contains("even") {
    "Even"
  } else if normalized.contains("first") {
    "First"
  } else {
    "Default"
  }
}

///|
fn docx_textbox_appendix_title(
  textbox : @ddocx.DocxTextBox,
  display_index : Int,
) -> String {
  let prefix = if textbox.owner_part.has_prefix("word/header") {
    "Header Text Box "
  } else if textbox.owner_part.has_prefix("word/footer") {
    "Footer Text Box "
  } else {
    "Text Box "
  }
  prefix + display_index.to_string()
}

///|
fn docx_blocks_have_visible_content(blocks : Array[@ddocx.DocxBlock]) -> Bool {
  for block in blocks {
    match block {
      @ddocx.DocxBlock::Paragraph(p) =>
        if !docx_paragraph_is_page_number_field_only(p) &&
          docx_inlines_have_visible_content(p.inlines) {
          return true
        }
      @ddocx.DocxBlock::Table(table) =>
        if table.rows.length() > 0 {
          return true
        }
      @ddocx.DocxBlock::ContentControl(control) =>
        if control.text.trim() != "" ||
          docx_blocks_have_visible_content(control.blocks) {
          return true
        }
      @ddocx.DocxBlock::TablePlaceholder(_)
      | @ddocx.DocxBlock::Unsupported(_) => return true
      @ddocx.DocxBlock::StructuralMarker(_) => ()
    }
  }
  false
}

///|
fn docx_inlines_have_visible_content(
  inlines : Array[@ddocx.DocxInline],
) -> Bool {
  for inline in inlines {
    match inline {
      @ddocx.DocxInline::Text(text) => if text.trim() != "" { return true }
      @ddocx.DocxInline::Tab
      | @ddocx.DocxInline::LineBreak
      | @ddocx.DocxInline::Break(_) => ()
      @ddocx.DocxInline::Hyperlink(link) =>
        if link.text.trim() != "" {
          return true
        }
      @ddocx.DocxInline::Media(_) => return true
      @ddocx.DocxInline::Drawing(drawing) =>
        if drawing.media is Some(_) ||
          docx_inlines_have_visible_content(drawing.child_inlines) {
          return true
        }
      @ddocx.DocxInline::Shape(shape) =>
        if shape.media is Some(_) ||
          docx_inlines_have_visible_content(shape.child_inlines) {
          return true
        }
      @ddocx.DocxInline::ContentControl(control) =>
        if control.text.trim() != "" ||
          docx_inlines_have_visible_content(control.inlines) ||
          docx_blocks_have_visible_content(control.blocks) {
          return true
        }
      @ddocx.DocxInline::FieldUnsupported(field) =>
        if render_docx_field_text(field).trim() != "" ||
          docx_inlines_have_visible_content(field.child_inlines) {
          return true
        }
      @ddocx.DocxInline::Math(math) =>
        if render_docx_math_text(math).trim() != "" ||
          docx_inlines_have_visible_content(math.child_inlines) {
          return true
        }
      @ddocx.DocxInline::TrackedChange(change) =>
        if render_docx_tracked_change_text(change).trim() != "" ||
          docx_inlines_have_visible_content(change.child_inlines) {
          return true
        }
      @ddocx.DocxInline::SmartTag(smart_tag) =>
        if docx_inlines_have_visible_content(smart_tag.child_inlines) {
          return true
        }
      @ddocx.DocxInline::Symbol(symbol) =>
        if render_docx_symbol_text(symbol).trim() != "" {
          return true
        }
      @ddocx.DocxInline::Hyphen(hyphen) =>
        if render_docx_hyphen_text(hyphen).trim() != "" {
          return true
        }
      @ddocx.DocxInline::FootnoteRef(_)
      | @ddocx.DocxInline::EndnoteRef(_)
      | @ddocx.DocxInline::CommentRef(_)
      | @ddocx.DocxInline::UnsupportedInline(_) => return true
      @ddocx.DocxInline::Bookmark(_)
      | @ddocx.DocxInline::StructuralMarker(_)
      | @ddocx.DocxInline::TextBoxRef(_)
      | @ddocx.DocxInline::Unsupported(_) => ()
    }
  }
  false
}

///|
fn normalize_docx_ref_marker_spacing(text : String) -> String {
  let chars = text.to_array()
  let out : Array[Char] = []
  let mut i = 0
  let mut pending_spaces = 0
  while i < chars.length() {
    let ch = chars[i]
    if ch == '\n' || ch == '\r' {
      while pending_spaces > 0 {
        out.push(' ')
        pending_spaces -= 1
      }
      out.push(ch)
      i += 1
    } else if docx_marker_space_char(ch) {
      pending_spaces += 1
      i += 1
    } else if docx_chars_has_literal_at(chars, i, "[^") ||
      docx_chars_has_literal_at(chars, i, "[comment ") {
      let had_space = pending_spaces > 0
      pending_spaces = 0
      match docx_marker_end(chars, i) {
        Some(end_index) => {
          let after_index = end_index + 1
          let move_space = had_space &&
            after_index < chars.length() &&
            docx_marker_needs_following_space(chars[after_index])
          if had_space && !move_space {
            out.push(' ')
          }
          while i <= end_index {
            out.push(chars[i])
            i += 1
          }
          if move_space {
            out.push(' ')
          }
        }
        None => {
          while pending_spaces > 0 {
            out.push(' ')
            pending_spaces -= 1
          }
          out.push(ch)
          i += 1
        }
      }
    } else {
      while pending_spaces > 0 {
        out.push(' ')
        pending_spaces -= 1
      }
      out.push(ch)
      i += 1
    }
  }
  while pending_spaces > 0 {
    out.push(' ')
    pending_spaces -= 1
  }
  String::from_array(out)
}

///|
fn normalize_docx_marker_rich_inlines(
  inlines : Array[@core.CoreInline],
) -> Array[@core.CoreInline] {
  let out : Array[@core.CoreInline] = []
  for index in 0..<inlines.length() {
    let inline = inlines[index]
    if docx_note_marker_inline(inline) {
      let needs_leading_space = docx_next_inline_needs_leading_space(
        inlines,
        index + 1,
      )
      let moved_space = if needs_leading_space {
        docx_trim_trailing_space_inline(out)
      } else {
        false
      }
      out.push(inline)
      if moved_space && needs_leading_space {
        out.push(
          @core.make_inline_text(
            " ",
            source_ref=docx_inline_spacing_source_ref(
              inline.source_ref.unwrap_or(@core.empty_source_ref()),
            ),
          ),
        )
      }
      continue
    }
    if docx_comment_marker_inline(inline) {
      docx_ensure_space_before_comment_marker(out, inline)
      out.push(inline)
      if docx_next_inline_needs_leading_space(inlines, index + 1) {
        out.push(
          @core.make_inline_text(
            " ",
            source_ref=docx_inline_spacing_source_ref(
              inline.source_ref.unwrap_or(@core.empty_source_ref()),
            ),
          ),
        )
      }
      continue
    }
    out.push(inline)
  }
  out
}

///|
fn docx_trim_trailing_space_inline(out : Array[@core.CoreInline]) -> Bool {
  match out.last() {
    Some(last) =>
      if last.kind == @core.InlineKind::Text {
        let (trimmed, changed) = docx_trim_trailing_spaces(last.text)
        if changed {
          ignore(out.pop())
          if trimmed != "" {
            out.push({ ..last, text: trimmed })
          }
          return true
        }
      }
    None => ()
  }
  false
}

///|
fn docx_trim_trailing_spaces(text : String) -> (String, Bool) {
  let chars = text.to_array()
  let mut end = chars.length()
  while end > 0 {
    let ch = chars[end - 1]
    if ch == ' ' || ch == '\t' {
      end -= 1
    } else {
      break
    }
  }
  if end == chars.length() {
    (text, false)
  } else {
    (String::from_array(chars[:end]), true)
  }
}

///|
fn docx_ensure_space_before_comment_marker(
  out : Array[@core.CoreInline],
  marker : @core.CoreInline,
) -> Unit {
  match out.last() {
    Some(last) => if docx_note_marker_inline(last) { return }
    None => ()
  }
  match out.last() {
    Some(last) =>
      if last.kind == @core.InlineKind::Text &&
        docx_inline_text_ends_with_space(last.text) {
        return
      }
    None => ()
  }
  out.push(
    @core.make_inline_text(
      " ",
      source_ref=docx_inline_spacing_source_ref(
        marker.source_ref.unwrap_or(@core.empty_source_ref()),
      ),
    ),
  )
}

///|
fn docx_inline_text_ends_with_space(text : String) -> Bool {
  let chars = text.to_array()
  if chars.length() == 0 {
    return false
  }
  let ch = chars[chars.length() - 1]
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}

///|
fn docx_next_inline_needs_leading_space(
  inlines : Array[@core.CoreInline],
  start : Int,
) -> Bool {
  let mut index = start
  while index < inlines.length() {
    let inline = inlines[index]
    match inline.kind {
      @core.InlineKind::LineBreak => return false
      @core.InlineKind::Text
      | @core.InlineKind::Link
      | @core.InlineKind::Code
      | @core.InlineKind::Image =>
        return docx_text_requires_leading_space(inline.text)
    }
    index += 1
  }
  false
}

///|
fn docx_text_requires_leading_space(text : String) -> Bool {
  for ch in text.to_array() {
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      return false
    }
    return docx_marker_needs_following_space(ch)
  }
  false
}

///|
fn docx_rendered_table_has_visible_cells(block : @core.CoreBlock) -> Bool {
  for row in block.children {
    for cell in row.children {
      if cell.text.trim() != "" {
        return true
      }
    }
  }
  false
}

///|
fn docx_note_marker_inline(inline : @core.CoreInline) -> Bool {
  if inline.kind != @core.InlineKind::Text {
    return false
  }
  inline.attrs.get("annotation_role") == Some("note_ref") &&
  inline.attrs.get("annotation_kind") != Some("comment")
}

///|
fn docx_comment_marker_inline(inline : @core.CoreInline) -> Bool {
  if inline.kind != @core.InlineKind::Text {
    return false
  }
  inline.attrs.get("annotation_role") == Some("note_ref") &&
  inline.attrs.get("annotation_kind") == Some("comment")
}

///|
fn docx_marker_space_char(ch : Char) -> Bool {
  ch == ' ' || ch == '\n' || ch == '\t' || ch == '\r'
}

///|
fn docx_chars_has_literal_at(
  chars : Array[Char],
  index : Int,
  literal : String,
) -> Bool {
  let target = literal.to_array()
  if index + target.length() > chars.length() {
    return false
  }
  let mut offset = 0
  while offset < target.length() {
    if chars[index + offset] != target[offset] {
      return false
    }
    offset += 1
  }
  true
}

///|
fn docx_marker_end(chars : Array[Char], index : Int) -> Int? {
  let mut i = index
  while i < chars.length() {
    if chars[i] == ']' {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn docx_marker_needs_following_space(ch : Char) -> Bool {
  !(ch == '.' ||
  ch == ',' ||
  ch == ';' ||
  ch == ':' ||
  ch == ')' ||
  ch == ']' ||
  ch == '!' ||
  ch == '?')
}

///|
fn docx_normalize_style_label(label : String) -> String {
  let out = StringBuilder::new()
  for ch in label.trim().to_lower().to_array() {
    if (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn docx_parse_nonnegative_int(text : String) -> Int? {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return None
  }
  let parsed = @string.parse_int(trimmed) catch { _ => return None }
  if parsed < 0 {
    None
  } else {
    Some(parsed)
  }
}
