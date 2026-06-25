///|
pub fn pptx_parser_capability() -> @parser.ParserCapability {
  @parser.make_parser_capability(
    @parser.ParserMode::PackageSinglePass,
    false,
    @parser.StreamingGranularity::PptxSlide,
    true,
    true,
    true,
    false,
    false,
    true,
    true,
    true,
    true,
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
pub fn pptx_parser() -> @parser.Parser {
  let capability = pptx_parser_capability()
  @parser.make_parser(
    "pptx_parser",
    @parser.ParserMode::PackageSinglePass,
    capability,
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      parse_pptx_document_result(source, context, capability)
    },
  )
}

///|
priv struct PptxState {
  source : @input.InputSource
  diagnostics : @core.Diagnostics
  presentation : @pptxdoc.PptxDocument
  assets : Array[@core.AssetRef]
  asset_ids : Map[String, String]
  image_ids : Map[String, String]
  slide_image_counts : Map[String, Int]
  chart_fallback_emitted : Ref[Bool]
}

///|
priv struct PptxListTree {
  ordered : Bool
  items : Array[@core.CoreBlock]
}

///|
fn parse_pptx_document_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
  capability : @parser.ParserCapability,
) -> Result[@parser.ParseResult, String] {
  let diagnostics = @light_common.empty_parser_diagnostics(
    "pptx_parser",
    @parser.ParserMode::PackageSinglePass,
    source,
    "pptx",
  )
  pptx_init_diagnostics(diagnostics, source, context)

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
        pptx_malformed_parse_result(
          source,
          diagnostics,
          "open package failed: " + err,
          capability,
        ),
      )
  }

  let presentation = try
    @pptxdoc.parse_pptx_document_from_package(pkg) |> Ok
  catch {
    e => Err(e.to_string())
  }
  let presentation = match presentation {
    Ok(value) => value
    Err(err) =>
      return Ok(
        pptx_malformed_parse_result(
          source,
          diagnostics,
          "parse pptx failed: " + err,
          capability,
        ),
      )
  }

  pptx_fill_package_metrics(diagnostics, pkg, presentation)
  let document = pptx_lower_document(source, presentation, diagnostics)
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
  diagnostics.pass_trace.push("parse:pptx_parser")
  let final_document = @core.document_with_diagnostics(document, diagnostics)
  Ok(
    @parser.parse_result_with_document_capability(
      "pptx_parser",
      @parser.ParserMode::PackageSinglePass,
      final_document,
      diagnostics,
      capability,
    ),
  )
}

///|
fn pptx_init_diagnostics(
  diagnostics : @core.Diagnostics,
  source : @input.InputSource,
  context : @parser.ParseContext,
) -> Unit {
  diagnostics.metrics.set("parser_name", "pptx_parser")
  diagnostics.metrics.set("parser_mode", "package_single_pass")
  diagnostics.metrics.set(
    "input_kind",
    @light_common.input_kind_name(source.kind),
  )
  diagnostics.metrics.set("detected_format", "pptx")
  diagnostics.metrics.set(
    "requested_mode",
    @light_common.requested_mode_name(context),
  )
  diagnostics.metrics.set("effective_mode", "package_single_pass")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("event_granularity", "pptx_slide")
  diagnostics.metrics.set("event_semantics", "package_single_pass")
  diagnostics.metrics.set("streaming_fallback", "false")
  diagnostics.metrics.set("office_document_kind", "pptx")
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
  diagnostics.metrics.set("pptx_slide_count", "0")
  diagnostics.metrics.set("pptx_visible_slide_count", "0")
  diagnostics.metrics.set("pptx_hidden_slide_count", "0")
  diagnostics.metrics.set("pptx_layout_count", "0")
  diagnostics.metrics.set("pptx_master_count", "0")
  diagnostics.metrics.set("pptx_theme_count", "0")
  diagnostics.metrics.set("pptx_shape_count", "0")
  diagnostics.metrics.set("pptx_text_box_count", "0")
  diagnostics.metrics.set("pptx_placeholder_count", "0")
  diagnostics.metrics.set("pptx_resolved_placeholder_count", "0")
  diagnostics.metrics.set("pptx_unresolved_placeholder_count", "0")
  diagnostics.metrics.set("pptx_table_count", "0")
  diagnostics.metrics.set("pptx_image_count", "0")
  diagnostics.metrics.set("pptx_notes_count", "0")
  diagnostics.metrics.set("pptx_comment_count", "0")
  diagnostics.metrics.set("pptx_external_media_count", "0")
  diagnostics.metrics.set(
    "pptx_reading_order_strategy",
    @shared.pptx_reading_order_strategy_name(
      @shared.PptxReadingOrderStrategy::PlaceholderThenGeometry,
    ),
  )
  @light_common.apply_readiness_metrics(diagnostics, "pptx", "near_ready")
  diagnostics.metrics.set("format_family", "office")
  diagnostics.metrics.set("default_route", "main_cli_exposed")
  diagnostics.metrics.set("native_impl_location", "formats/pptx_parser")
  diagnostics.metrics.set("max_pptx_slides", "2000")
  diagnostics.metrics.set("max_pptx_shapes", "20000")
  diagnostics.metrics.set("max_pptx_text_runs", "200000")
  diagnostics.metrics.set("max_pptx_tables", "5000")
  diagnostics.metrics.set("max_pptx_images", "5000")
  diagnostics.metrics.set("max_pptx_notes", "5000")
  diagnostics.metrics.set("max_pptx_comments", "5000")
}

///|
fn pptx_malformed_parse_result(
  source : @input.InputSource,
  diagnostics : @core.Diagnostics,
  err : String,
  capability : @parser.ParserCapability,
) -> @parser.ParseResult {
  diagnostics.errors.push(err)
  diagnostics.degraded_features.push("pptx_parse_failure")
  diagnostics.fallback_trace.push("pptx parse failed -> fail closed")
  diagnostics.metrics.set("block_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("ooxml_part_count", "0")
  diagnostics.metrics.set("relationship_count", "0")
  diagnostics.metrics.set("external_relationship_count", "0")
  diagnostics.metrics.set("missing_relationship_target_count", "0")
  diagnostics.metrics.set("unsupported_relationship_count", "0")
  diagnostics.metrics.set("content_type_count", "0")
  diagnostics.metrics.set("total_uncompressed_bytes", "0")
  diagnostics.metrics.set("pptx_slide_count", "0")
  diagnostics.metrics.set("pptx_visible_slide_count", "0")
  diagnostics.metrics.set("pptx_hidden_slide_count", "0")
  diagnostics.metrics.set("pptx_layout_count", "0")
  diagnostics.metrics.set("pptx_master_count", "0")
  diagnostics.metrics.set("pptx_theme_count", "0")
  diagnostics.metrics.set("pptx_shape_count", "0")
  diagnostics.metrics.set("pptx_text_box_count", "0")
  diagnostics.metrics.set("pptx_placeholder_count", "0")
  diagnostics.metrics.set("pptx_resolved_placeholder_count", "0")
  diagnostics.metrics.set("pptx_unresolved_placeholder_count", "0")
  diagnostics.metrics.set("pptx_table_count", "0")
  diagnostics.metrics.set("pptx_image_count", "0")
  diagnostics.metrics.set("pptx_notes_count", "0")
  diagnostics.metrics.set("pptx_comment_count", "0")
  diagnostics.metrics.set("pptx_external_media_count", "0")
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
  diagnostics.pass_trace.push("parse:pptx_parser")
  ignore(source)
  let document = @core.document_with_diagnostics(
    @core.empty_document_ir(),
    diagnostics,
  )
  @parser.parse_result_with_document_capability(
    "pptx_parser",
    @parser.ParserMode::PackageSinglePass,
    document,
    diagnostics,
    capability,
  )
}

///|
fn pptx_fill_package_metrics(
  diagnostics : @core.Diagnostics,
  pkg : @ox.OoxmlPackage,
  presentation : @pptxdoc.PptxDocument,
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
    "media_asset_count",
    count_pptx_media_parts(inventory.parts).to_string(),
  )
  diagnostics.metrics.set(
    "content_type_count",
    inventory.content_type_entry_count.to_string(),
  )
  let mut total_uncompressed_bytes = 0
  for part in inventory.parts {
    total_uncompressed_bytes += part.size
  }
  diagnostics.metrics.set(
    "total_uncompressed_bytes",
    total_uncompressed_bytes.to_string(),
  )

  let mut path_traversal_count = 0
  for issue in validation.issues {
    let message = issue.message.trim().to_owned().to_lower()
    if message.contains("path traversal") ||
      message.contains("unsafe relationship target") {
      path_traversal_count += 1
    }
  }
  diagnostics.metrics.set(
    "path_traversal_count",
    path_traversal_count.to_string(),
  )

  let mut duplicate_part_count = 0
  let mut prev_part = ""
  let sorted_part_names = inventory.parts.map(part => part.part_name)
  sorted_part_names.sort()
  for part_name in sorted_part_names {
    if part_name == prev_part {
      duplicate_part_count += 1
    }
    prev_part = part_name
  }
  diagnostics.metrics.set(
    "duplicate_part_count",
    duplicate_part_count.to_string(),
  )

  let mut macro_part_count = 0
  let mut ole_object_count = 0
  for part in inventory.parts {
    let content_type = part.content_type.unwrap_or("").to_lower()
    let part_name = part.part_name.to_lower()
    if content_type.contains("macroenabled") || part_name.has_suffix(".bin") {
      macro_part_count += 1
    }
    if content_type.contains("oleobject") || part_name.contains("/embeddings/") {
      ole_object_count += 1
    }
  }
  diagnostics.metrics.set("macro_part_count", macro_part_count.to_string())
  diagnostics.metrics.set("ole_object_count", ole_object_count.to_string())

  let inspect = @pptxdoc.inspect_pptx_document(presentation)
  diagnostics.metrics.set(
    "pptx_slide_count",
    presentation.slides.length().to_string(),
  )
  diagnostics.metrics.set(
    "pptx_layout_count",
    presentation.layouts.length().to_string(),
  )
  diagnostics.metrics.set(
    "pptx_master_count",
    presentation.masters.length().to_string(),
  )
  diagnostics.metrics.set(
    "pptx_theme_count",
    pptx_theme_count(presentation).to_string(),
  )
  diagnostics.metrics.set("pptx_shape_count", inspect.shape_count.to_string())
  diagnostics.metrics.set("pptx_table_count", inspect.table_count.to_string())
  diagnostics.metrics.set("pptx_notes_count", inspect.notes_count.to_string())
  diagnostics.metrics.set(
    "pptx_comment_count",
    inspect.comment_count.to_string(),
  )

  let placeholder_count : Ref[Int] = { val: 0 }
  let resolved_placeholder_count : Ref[Int] = { val: 0 }
  let unresolved_placeholder_count : Ref[Int] = { val: 0 }
  let text_box_count : Ref[Int] = { val: 0 }
  let image_count : Ref[Int] = { val: 0 }
  let external_media_count : Ref[Int] = { val: 0 }
  let mut visible_slide_count = 0
  let mut hidden_slide_count = 0
  for slide in presentation.slides {
    if slide.hidden {
      hidden_slide_count += 1
    } else {
      visible_slide_count += 1
    }
    for obj in slide.objects {
      pptx_accumulate_object_metrics(
        obj, diagnostics, placeholder_count, resolved_placeholder_count, unresolved_placeholder_count,
        text_box_count, image_count, external_media_count,
      )
    }
  }
  diagnostics.metrics.set(
    "pptx_visible_slide_count",
    visible_slide_count.to_string(),
  )
  diagnostics.metrics.set(
    "pptx_hidden_slide_count",
    hidden_slide_count.to_string(),
  )
  diagnostics.metrics.set(
    "pptx_placeholder_count",
    placeholder_count.val.to_string(),
  )
  diagnostics.metrics.set(
    "pptx_resolved_placeholder_count",
    resolved_placeholder_count.val.to_string(),
  )
  diagnostics.metrics.set(
    "pptx_unresolved_placeholder_count",
    unresolved_placeholder_count.val.to_string(),
  )
  diagnostics.metrics.set("pptx_text_box_count", text_box_count.val.to_string())
  diagnostics.metrics.set("pptx_image_count", image_count.val.to_string())
  diagnostics.metrics.set(
    "pptx_external_media_count",
    external_media_count.val.to_string(),
  )
}

///|
fn count_pptx_media_parts(parts : Array[@ox.OoxmlPartInfo]) -> Int {
  let mut count = 0
  for part in parts {
    if part.part_name.has_prefix("ppt/media/") &&
      !part.part_name.has_suffix("/") {
      count += 1
    }
  }
  count
}

///|
fn pptx_accumulate_object_metrics(
  obj : @pptxdoc.PptxObject,
  diagnostics : @core.Diagnostics,
  placeholder_count : Ref[Int],
  resolved_placeholder_count : Ref[Int],
  unresolved_placeholder_count : Ref[Int],
  text_box_count : Ref[Int],
  image_count : Ref[Int],
  external_media_count : Ref[Int],
) -> Unit {
  ignore(diagnostics)
  match obj {
    @pptxdoc.PptxObject::Shape(shape) => {
      match shape.direct_placeholder {
        Some(_) => placeholder_count.val += 1
        None => ()
      }
      match shape.placeholder {
        Some(_) => {
          resolved_placeholder_count.val += 1
          placeholder_count.val += 1
        }
        None =>
          if shape.text_body is Some(_) && shape.direct_placeholder is None {
            text_box_count.val += 1
          } else if shape.direct_placeholder is Some(_) {
            unresolved_placeholder_count.val += 1
          }
      }
    }
    @pptxdoc.PptxObject::Picture(pic) => {
      image_count.val += 1
      match pic.media {
        Some(media) => if media.is_external { external_media_count.val += 1 }
        None => ()
      }
    }
    @pptxdoc.PptxObject::Group(group) =>
      for child in group.children {
        pptx_accumulate_object_metrics(
          child, diagnostics, placeholder_count, resolved_placeholder_count, unresolved_placeholder_count,
          text_box_count, image_count, external_media_count,
        )
      }
    @pptxdoc.PptxObject::Ole(_) =>
      diagnostics.degraded_features.push("pptx_ole_unsupported")
    @pptxdoc.PptxObject::Chart(_) =>
      diagnostics.degraded_features.push("pptx_chart_unsupported")
    @pptxdoc.PptxObject::SmartArt(_) =>
      diagnostics.degraded_features.push("pptx_smartart_unsupported")
    _ => ()
  }
}

///|
fn pptx_theme_count(presentation : @pptxdoc.PptxDocument) -> Int {
  let themes : Array[String] = []
  for slide in presentation.slides {
    match slide.master_ref {
      Some(master) =>
        if !themes.contains(master.part_name) {
          themes.push(master.part_name)
        }
      None => ()
    }
  }
  themes.length()
}

///|
fn pptx_lower_document(
  source : @input.InputSource,
  presentation : @pptxdoc.PptxDocument,
  diagnostics : @core.Diagnostics,
) -> @core.DocumentIR {
  let document = @core.empty_document_ir()
  pptx_fill_metadata(document, source, presentation)
  let state = new_pptx_state(source, presentation, diagnostics)
  for slide in presentation.slides {
    if slide.hidden {
      pptx_note_hidden_slide_skipped(diagnostics, slide.slide_index)
      continue
    }
    pptx_lower_slide(document.blocks, state, slide)
  }
  pptx_append_document_warnings(document.blocks, state)
  @core.document_with_assets(document, state.assets)
}

///|
fn new_pptx_state(
  source : @input.InputSource,
  presentation : @pptxdoc.PptxDocument,
  diagnostics : @core.Diagnostics,
) -> PptxState {
  {
    source,
    diagnostics,
    presentation,
    assets: [],
    asset_ids: Map([]),
    image_ids: Map([]),
    slide_image_counts: Map([]),
    chart_fallback_emitted: { val: false },
  }
}

///|
fn pptx_fill_metadata(
  document : @core.DocumentIR,
  source : @input.InputSource,
  presentation : @pptxdoc.PptxDocument,
) -> Unit {
  document.metadata.set(
    "source_name",
    @core.JsonValue::String(source.source_name),
  )
  document.metadata.set("format", @core.JsonValue::String("pptx"))
  document.metadata.set(
    "presentation_part",
    @core.JsonValue::String(presentation.presentation.part_name),
  )
  document.metadata.set(
    "slide_count",
    @core.JsonValue::Number(presentation.slides.length().to_string()),
  )
  document.metadata.set(
    "layout_count",
    @core.JsonValue::Number(presentation.layouts.length().to_string()),
  )
  document.metadata.set(
    "master_count",
    @core.JsonValue::Number(presentation.masters.length().to_string()),
  )
  match presentation.metadata.title {
    Some(title) =>
      document.metadata.set("title", @core.JsonValue::String(title))
    None => ()
  }
  match presentation.metadata.creator {
    Some(author) =>
      document.metadata.set("creator", @core.JsonValue::String(author))
    None => ()
  }
}

///|
fn pptx_lower_slide(
  blocks : Array[@core.CoreBlock],
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
) -> Unit {
  let slide_heading = @core.make_block(
    @core.BlockKind::Heading,
    "Slide " + slide.slide_index.to_string(),
    source_ref=pptx_slide_source_ref(state.source, slide, None, None),
  )
  slide_heading.attrs.set("level", "2")
  blocks.push(slide_heading)

  let block_count_before = blocks.length()
  for obj in slide.objects {
    pptx_lower_object(blocks, state, slide, obj)
  }
  pptx_lower_slide_comments(blocks, state, slide)
  pptx_lower_slide_notes(blocks, state, slide)
  if blocks.length() == block_count_before {
    blocks.push(
      @core.make_block(
        @core.BlockKind::Paragraph,
        "(empty)",
        source_ref=pptx_slide_source_ref(state.source, slide, None, None),
      ),
    )
  }
}

///|
fn pptx_lower_object(
  blocks : Array[@core.CoreBlock],
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  obj : @pptxdoc.PptxObject,
) -> Unit {
  match obj {
    @pptxdoc.PptxObject::Shape(shape) =>
      pptx_lower_shape(blocks, state, slide, shape)
    @pptxdoc.PptxObject::Group(group) =>
      for child in group.children {
        pptx_lower_object(blocks, state, slide, child)
      }
    @pptxdoc.PptxObject::Picture(pic) =>
      pptx_lower_picture(blocks, state, slide, pic)
    @pptxdoc.PptxObject::Table(table) =>
      match pptx_table_block(state, slide, table) {
        Some(block) => blocks.push(block)
        None => ()
      }
    @pptxdoc.PptxObject::Chart(chart) =>
      pptx_lower_chart(blocks, state, slide, chart)
    @pptxdoc.PptxObject::SmartArt(smart) =>
      blocks.push(
        pptx_raw_placeholder_block(
          state,
          slide,
          Some(smart.source_key),
          smart.relationship_id,
          "[Unsupported PPTX SmartArt" +
          pptx_opt_suffix(smart.target_part) +
          "]",
          "pptx_smartart_unsupported",
        ),
      )
    @pptxdoc.PptxObject::Ole(ole) =>
      blocks.push(
        pptx_raw_placeholder_block(
          state,
          slide,
          Some(ole.source_key),
          ole.relationship_id,
          "[Unsupported PPTX OLE object" +
          pptx_opt_suffix(ole.target_part) +
          "]",
          "pptx_ole_unsupported",
        ),
      )
    @pptxdoc.PptxObject::Connector(conn) =>
      blocks.push(
        pptx_raw_placeholder_block(
          state,
          slide,
          Some(conn.source_key),
          None,
          "[PPTX connector omitted" + pptx_opt_suffix(conn.name) + "]",
          "pptx_connector_omitted",
        ),
      )
    @pptxdoc.PptxObject::Unsupported(unsupported) =>
      blocks.push(
        pptx_raw_placeholder_block(
          state,
          slide,
          Some(unsupported.source_key),
          None,
          "[Unsupported PPTX object: " + unsupported.kind + "]",
          "pptx_object_unsupported",
        ),
      )
  }
}

///|
fn pptx_lower_shape(
  blocks : Array[@core.CoreBlock],
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  shape : @pptxdoc.PptxShape,
) -> Unit {
  match shape.text_body {
    Some(body) => {
      let mut paragraph_index = 0
      let list_stack : Array[PptxListTree] = []
      let is_heading_shape = pptx_shape_is_heading(slide, shape)
      for para in body.paragraphs {
        let rich = pptx_paragraph_inlines(state, slide, shape, para)
        let text = pptx_plain_text(rich)
        if text.trim() == "" {
          paragraph_index += 1
          continue
        }
        let source_ref = pptx_shape_source_ref(
          state.source,
          slide,
          shape,
          Some(para.source_key),
        )
        let block = match para.list_hint {
          Some(list_hint) => {
            let item0 = @core.make_block(
              @core.BlockKind::ListItem,
              pptx_list_item_text(text),
              source_ref~,
            )
            let item = if rich.length() > 0 {
              @core.block_with_rich_inlines(item0, Some(rich))
            } else {
              item0
            }
            match list_hint.bullet {
              Some(@pptxdoc.PptxBulletKind::Ordered) => {
                item.attrs.set("ordered", "true")
                item.attrs.set("stable_ordered_marker", "true")
              }
              _ => item.attrs.set("ordered", "false")
            }
            item.attrs.set("level", list_hint.level.to_string())
            item
          }
          None =>
            if is_heading_shape && paragraph_index == 0 {
              let heading0 = @core.make_block(
                @core.BlockKind::Heading,
                text.trim().to_owned(),
                source_ref~,
              )
              let heading = if rich.length() > 0 {
                @core.block_with_rich_inlines(heading0, Some(rich))
              } else {
                heading0
              }
              heading.attrs.set("level", "3")
              heading
            } else {
              let paragraph0 = @core.make_block(
                @core.BlockKind::Paragraph,
                text,
                source_ref~,
              )
              if rich.length() > 0 {
                @core.block_with_rich_inlines(paragraph0, Some(rich))
              } else {
                paragraph0
              }
            }
        }
        if block.kind == @core.BlockKind::ListItem {
          pptx_push_list_item(blocks, list_stack, block)
        } else {
          pptx_flush_lists(blocks, list_stack, 0)
          blocks.push(block)
        }
        paragraph_index += 1
      }
      pptx_flush_lists(blocks, list_stack, 0)
    }
    None =>
      if pptx_is_decorative_shape(shape) {
        let raw = pptx_raw_placeholder_block(
          state,
          slide,
          Some(shape.source_key),
          None,
          "[PPTX decorative shape omitted" + pptx_opt_suffix(shape.name) + "]",
          "pptx_decorative_shape_omitted",
        )
        blocks.push(raw)
      }
  }
}

///|
fn pptx_shape_is_heading(
  slide : @pptxdoc.PptxSlide,
  shape : @pptxdoc.PptxShape,
) -> Bool {
  match shape.placeholder {
    Some(ph) =>
      ph.kind == @pptxdoc.PptxPlaceholderKind::Title ||
      ph.kind == @pptxdoc.PptxPlaceholderKind::CenterTitle ||
      ph.kind == @pptxdoc.PptxPlaceholderKind::Subtitle
    None =>
      match shape.direct_placeholder {
        Some(ph) =>
          ph.kind == @pptxdoc.PptxPlaceholderKind::Title ||
          ph.kind == @pptxdoc.PptxPlaceholderKind::CenterTitle ||
          ph.kind == @pptxdoc.PptxPlaceholderKind::Subtitle
        None => pptx_shape_is_heading_fallback(slide, shape)
      }
  }
}

///|
fn pptx_shape_is_heading_fallback(
  slide : @pptxdoc.PptxSlide,
  shape : @pptxdoc.PptxShape,
) -> Bool {
  match shape.reading_order {
    Some(order) =>
      if order.bucket != @pptxdoc.PptxReadingBucket::Title &&
        order.bucket != @pptxdoc.PptxReadingBucket::Subtitle {
        return false
      }
    None => return false
  }
  let text_body = match shape.text_body {
    Some(body) => body
    None => return false
  }
  if text_body.paragraphs.length() == 0 {
    return false
  }
  if pptx_slide_has_single_text_shape(slide, shape) {
    return true
  }
  let first = shape_geometry_top(shape).unwrap_or(0)
  let second = pptx_next_shape_top(slide, shape)
  match second {
    Some(next_top) => first < next_top
    None => true
  }
}

///|
fn pptx_slide_has_single_text_shape(
  slide : @pptxdoc.PptxSlide,
  target : @pptxdoc.PptxShape,
) -> Bool {
  let mut count = 0
  for obj in slide.objects {
    match obj {
      @pptxdoc.PptxObject::Shape(shape) =>
        match shape.text_body {
          Some(body) =>
            if body.paragraphs.length() > 0 {
              count += 1
              if shape.source_key.part_name == target.source_key.part_name &&
                shape.source_key.node_key == target.source_key.node_key {
                ()
              }
            }
          None => ()
        }
      _ => ()
    }
  }
  count == 1
}

///|
fn pptx_is_decorative_shape(shape : @pptxdoc.PptxShape) -> Bool {
  match shape.reading_order {
    Some(hint) => hint.bucket == @pptxdoc.PptxReadingBucket::Decorative
    None => shape.text_body is None
  }
}

///|
fn pptx_paragraph_inlines(
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  shape : @pptxdoc.PptxShape,
  para : @pptxdoc.PptxParagraph,
) -> Array[@core.CoreInline] {
  let out : Array[@core.CoreInline] = []
  for run in para.runs {
    let run_ref = pptx_shape_source_ref(
      state.source,
      slide,
      shape,
      Some(run.source_key),
    )
    for inline in run.inlines {
      match inline {
        @pptxdoc.PptxInline::Text(text) =>
          out.push(
            @core.make_inline_text(
              pptx_normalize_text_fragment(text),
              source_ref=run_ref,
            ),
          )
        @pptxdoc.PptxInline::Break =>
          out.push(@core.make_inline_line_break(source_ref=run_ref))
        @pptxdoc.PptxInline::Field(text) =>
          out.push(
            @core.make_inline_text(
              pptx_normalize_text_fragment(text),
              source_ref=run_ref,
            ),
          )
        @pptxdoc.PptxInline::Hyperlink(link, text) =>
          match link.target {
            Some(target) =>
              out.push(
                @core.make_inline_link(
                  pptx_normalize_text_fragment(text),
                  target,
                  source_ref=@core.source_ref_with_extra(
                    run_ref,
                    "hyperlink_target_mode",
                    if link.is_external {
                      "external"
                    } else {
                      "internal"
                    },
                  ),
                ),
              )
            None =>
              out.push(
                @core.make_inline_text(
                  pptx_normalize_text_fragment(text),
                  source_ref=run_ref,
                ),
              )
          }
        @pptxdoc.PptxInline::Unsupported(unsupported) =>
          out.push(
            @core.make_inline_text(
              "[Unsupported PPTX inline: " + unsupported.kind + "]",
              source_ref=run_ref,
            ),
          )
      }
    }
  }
  pptx_compact_text_inlines(out)
}

///|
fn pptx_plain_text(inlines : Array[@core.CoreInline]) -> String {
  let mut out = ""
  for inline in inlines {
    match inline.kind {
      @core.InlineKind::Text => out = out + inline.text
      @core.InlineKind::LineBreak => out = out + "\n"
      @core.InlineKind::Link => out = out + inline.text
      _ => ()
    }
  }
  out
}

///|
fn pptx_normalize_text_fragment(text : String) -> String {
  let out = StringBuilder::new()
  let mut leading_space = false
  let mut pending_space = false
  let mut wrote_text = false
  for ch in text.to_array() {
    if ch == '\t' || ch == ' ' {
      if wrote_text {
        pending_space = true
      } else {
        leading_space = true
      }
    } else {
      if leading_space {
        out.write_char(' ')
        leading_space = false
      }
      if pending_space && wrote_text {
        out.write_char(' ')
      }
      out.write_char(ch)
      wrote_text = true
      pending_space = false
    }
  }
  if pending_space && wrote_text {
    out.write_char(' ')
  }
  out.to_string()
}

///|
fn pptx_compact_text_inlines(
  inlines : Array[@core.CoreInline],
) -> Array[@core.CoreInline] {
  let out : Array[@core.CoreInline] = []
  for inline in inlines {
    if inline.kind != @core.InlineKind::Text {
      out.push(inline)
      continue
    }
    let text = inline.text
    if text == "" {
      continue
    }
    match out.last() {
      Some(prev) =>
        if prev.kind == @core.InlineKind::Text {
          let merged = pptx_merge_text_fragments(prev.text, text)
          ignore(out.pop())
          out.push({
            kind: @core.InlineKind::Text,
            text: merged,
            href: None,
            title: None,
            attrs: prev.attrs,
            source_ref: prev.source_ref,
          })
        } else {
          out.push(inline)
        }
      None => out.push(inline)
    }
  }
  out
}

///|
fn pptx_merge_text_fragments(left : String, right : String) -> String {
  if left == "" {
    return right
  }
  if right == "" {
    return left
  }
  if pptx_leading_space(right) {
    return left.trim_end().to_owned() + " " + right.trim_start().to_owned()
  }
  left + right
}

///|
fn pptx_leading_space(text : String) -> Bool {
  let chars = text.to_array()
  if chars.length() == 0 {
    return false
  }
  let ch = chars[0]
  ch == ' ' || ch == '\t'
}

///|
fn pptx_list_item_text(text : String) -> String {
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
fn pptx_flush_lists(
  out : Array[@core.CoreBlock],
  list_stack : Array[PptxListTree],
  min_depth : Int,
) -> Unit {
  while list_stack.length() > min_depth {
    let current = list_stack.pop().unwrap()
    let list_block = @core.make_block(
      @core.BlockKind::List,
      "",
      source_ref=current.items[0].source_ref.unwrap_or(@core.empty_source_ref()),
    )
    list_block.attrs.set("ordered", @light_common.bool_string(current.ordered))
    list_block.children.append(current.items[:])
    match list_stack.last() {
      Some(parent) =>
        parent.items[parent.items.length() - 1].children.push(list_block)
      None => out.push(list_block)
    }
  }
}

///|
fn pptx_push_list_item(
  out : Array[@core.CoreBlock],
  list_stack : Array[PptxListTree],
  item : @core.CoreBlock,
) -> Unit {
  let ordered = item.attrs.get("ordered").unwrap_or("false") == "true"
  let level = @string.parse_int(item.attrs.get("level").unwrap_or("0")) catch {
    _ => 0
  }
  let target_depth = level + 1
  pptx_flush_lists(out, list_stack, target_depth)
  if list_stack.length() == target_depth &&
    target_depth > 0 &&
    list_stack[target_depth - 1].ordered != ordered {
    pptx_flush_lists(out, list_stack, target_depth - 1)
  }
  while list_stack.length() < target_depth {
    list_stack.push({ ordered, items: [] })
  }
  if list_stack.length() > 0 {
    list_stack[list_stack.length() - 1].items.push(item)
  }
}

///|
fn pptx_lower_picture(
  blocks : Array[@core.CoreBlock],
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  pic : @pptxdoc.PptxPicture,
) -> Unit {
  let media = match pic.media {
    Some(value) => value
    None => return
  }
  if media.is_external {
    state.diagnostics.warnings.push(
      "external pptx media skipped: " +
      media.resolved_target.unwrap_or("unknown target"),
    )
    state.diagnostics.degraded_features.push("pptx_external_media_no_fetch")
    blocks.push(
      pptx_raw_placeholder_block(
        state,
        slide,
        Some(media.source_key),
        media.relationship_id,
        "[Unsupported PPTX media" + pptx_opt_suffix(media.resolved_target) + "]",
        "pptx_external_media_no_fetch",
      ),
    )
    return
  }
  if media.unsupported || media.data is None {
    state.diagnostics.warnings.push(
      "unsupported pptx media skipped: " +
      media.resolved_target.unwrap_or("unknown target"),
    )
    state.diagnostics.degraded_features.push("pptx_media_unsupported")
    blocks.push(
      pptx_raw_placeholder_block(
        state,
        slide,
        Some(media.source_key),
        media.relationship_id,
        "[Unsupported PPTX media" + pptx_opt_suffix(media.resolved_target) + "]",
        "pptx_media_unsupported",
      ),
    )
    return
  }
  let image_block = pptx_image_block_from_media(state, slide, pic, media)
  blocks.push(image_block)
}

///|
fn pptx_image_block_from_media(
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  pic : @pptxdoc.PptxPicture,
  media : @pptxdoc.PptxMediaRef,
) -> @core.CoreBlock {
  let target_part = media.resolved_target.unwrap_or(
    media.target.unwrap_or("ppt/media/image.bin"),
  )
  let asset_key = pptx_picture_asset_key(slide, pic, media)
  let output_path = pptx_asset_output_path(state, asset_key, target_part)
  let source_ref = pptx_picture_source_ref(state.source, slide, pic)
  let asset = pptx_ensure_asset(
    state, media, asset_key, output_path, source_ref,
  )
  let alt = pptx_image_alt_text(state, pic, media, slide.slide_index)
  let block = @core.make_block(@core.BlockKind::Image, "", source_ref~)
  block.attrs.set("path", asset.path.unwrap_or(output_path))
  block.attrs.set("alt", alt)
  match media.title {
    Some(title) => if title.trim() != "" { block.attrs.set("title", title) }
    None => ()
  }
  match pptx_image_caption_for_picture(slide, pic.source_key) {
    Some(caption) =>
      if caption.trim() != "" {
        block.attrs.set("caption", caption)
      }
    None => ()
  }
  block
}

///|
fn pptx_ensure_asset(
  state : PptxState,
  media : @pptxdoc.PptxMediaRef,
  asset_key : String,
  output_path : String,
  source_ref : @core.SourceRef,
) -> @core.AssetRef {
  let target_part = media.resolved_target.unwrap_or(media.target.unwrap_or(""))
  match state.asset_ids.get(asset_key) {
    Some(asset_id) =>
      for asset in state.assets {
        if asset.asset_id == asset_id {
          return asset
        }
      }
    None => ()
  }
  let asset_id = "pptx:" + asset_key
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
  next_asset.attrs.set("alt", pptx_media_alt_text(media))
  next_asset.attrs.set("source_path", target_part)
  next_asset.attrs.set("zip_entry_path", target_part)
  next_asset.attrs.set("zip_container_format", "pptx")
  match state.source.path {
    Some(path) => next_asset.attrs.set("zip_container_path", path)
    None => ()
  }
  state.assets.push(next_asset)
  state.asset_ids.set(asset_key, asset_id)
  bump_metric(state.diagnostics, "materialized_asset_count")
  next_asset
}

///|
fn metric_int(diagnostics : @core.Diagnostics, key : String) -> Int {
  @string.parse_int(diagnostics.metrics.get(key).unwrap_or("0")) catch {
    _ => 0
  }
}

///|
fn bump_metric(diagnostics : @core.Diagnostics, key : String) -> Unit {
  let current = metric_int(diagnostics, key)
  diagnostics.metrics.set(key, (current + 1).to_string())
}

///|
fn pptx_asset_output_path(
  state : PptxState,
  asset_key : String,
  target_part : String,
) -> String {
  match state.asset_ids.get(asset_key) {
    Some(asset_id) =>
      for asset in state.assets {
        if asset.asset_id == asset_id {
          return asset.path.unwrap_or("assets/image01.bin")
        }
      }
    None => ()
  }
  let index = state.assets.length() + 1
  "assets/image" + pptx_two_digits(index) + "." + pptx_media_ext(target_part)
}

///|
fn pptx_picture_asset_key(
  slide : @pptxdoc.PptxSlide,
  pic : @pptxdoc.PptxPicture,
  media : @pptxdoc.PptxMediaRef,
) -> String {
  slide.slide_index.to_string() +
  ":" +
  pic.source_key.node_key +
  ":" +
  pic.shape_id.unwrap_or("") +
  ":" +
  media.resolved_target.unwrap_or(media.target.unwrap_or(""))
}

///|
fn pptx_media_ext(target_part : String) -> String {
  let lower = target_part.to_lower()
  let chars = lower.to_array()
  let mut last_dot : Int? = None
  for i in 0..<chars.length() {
    if chars[i] == '.' {
      last_dot = Some(i)
    }
  }
  match last_dot {
    Some(index) =>
      if index + 1 < lower.length() {
        lower[index + 1:].to_owned()
      } else {
        "bin"
      }
    None => "bin"
  }
}

///|
fn pptx_two_digits(index : Int) -> String {
  if index < 10 {
    "0" + index.to_string()
  } else {
    index.to_string()
  }
}

///|
fn pptx_image_alt_text(
  state : PptxState,
  pic : @pptxdoc.PptxPicture,
  media : @pptxdoc.PptxMediaRef,
  slide_index : Int,
) -> String {
  let fallback = pptx_picture_synthetic_id(state, media, slide_index)
  match media.alt_text {
    Some(text) =>
      if pptx_nonsemantic_picture_label(text) {
        fallback
      } else {
        text
      }
    None =>
      match pic.name {
        Some(name) =>
          if pptx_nonsemantic_picture_label(name) ||
            pptx_generic_picture_name(name) {
            fallback
          } else {
            name
          }
        None => fallback
      }
  }
}

///|
fn pptx_generic_picture_name(name : String) -> Bool {
  let trimmed = name.trim().to_owned()
  if trimmed == "" {
    return true
  }
  let lower = trimmed.to_lower()
  lower == "picture" ||
  lower.has_prefix("picture ") ||
  lower.has_prefix("content placeholder") ||
  lower.has_prefix("placeholder ")
}

///|
fn pptx_nonsemantic_picture_label(text : String) -> Bool {
  let lower = text.trim().to_owned().to_lower()
  if lower == "" {
    return true
  }
  if pptx_path_like_descr(lower) {
    return true
  }
  lower.has_suffix(".wav") ||
  lower.has_suffix(".mp3") ||
  lower.has_suffix(".m4a") ||
  lower.has_suffix(".aac") ||
  lower.has_suffix(".wma") ||
  lower.has_suffix(".mp4") ||
  lower.has_suffix(".m4v") ||
  lower.has_suffix(".mov") ||
  lower.has_suffix(".avi") ||
  lower.has_suffix(".wmv")
}

///|
fn pptx_picture_synthetic_id(
  state : PptxState,
  media : @pptxdoc.PptxMediaRef,
  slide_index : Int,
) -> String {
  let key = slide_index.to_string() +
    ":" +
    media.source_key.node_key +
    ":" +
    media.resolved_target.unwrap_or(media.target.unwrap_or(""))
  match state.image_ids.get(key) {
    Some(id) => id
    None => {
      let slide_key = slide_index.to_string()
      let next_index = state.slide_image_counts.get(slide_key).unwrap_or(0) + 1
      state.slide_image_counts.set(slide_key, next_index)
      let id = "slide-" +
        slide_index.to_string() +
        "-image-" +
        next_index.to_string()
      state.image_ids.set(key, id)
      id
    }
  }
}

///|
fn pptx_media_alt_text(media : @pptxdoc.PptxMediaRef) -> String {
  match media.alt_text {
    Some(text) => if pptx_path_like_descr(text) { "image" } else { text }
    None => "image"
  }
}

///|
fn pptx_path_like_descr(text : String) -> Bool {
  let value = text.trim().to_lower()
  if value == "" {
    return false
  }
  if value.contains("/") || value.contains("\\") {
    return true
  }
  value.has_suffix(".png") ||
  value.has_suffix(".jpg") ||
  value.has_suffix(".jpeg") ||
  value.has_suffix(".gif") ||
  value.has_suffix(".bmp") ||
  value.has_suffix(".tif") ||
  value.has_suffix(".tiff") ||
  value.has_suffix(".svg") ||
  value.has_suffix(".webp")
}

///|
fn pptx_image_caption_for_picture(
  slide : @pptxdoc.PptxSlide,
  key : @pptxdoc.PptxSourceKey,
) -> String? {
  for pair in slide.image_caption_pairs {
    if pair.picture_key.part_name == key.part_name &&
      pair.picture_key.node_key == key.node_key &&
      pptx_caption_pair_is_semantic(pair) {
      return Some(pair.caption_text)
    }
  }
  None
}

///|
fn pptx_caption_pair_is_semantic(pair : @pptxdoc.PptxImageCaptionPair) -> Bool {
  pptx_caption_text_has_prefix(pair.caption_text)
}

///|
fn pptx_caption_text_has_prefix(text : String) -> Bool {
  let lower = text.trim().to_lower()
  lower.has_prefix("figure") ||
  lower.has_prefix("fig.") ||
  lower.has_prefix("caption")
}

///|
fn pptx_table_block(
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  table : @pptxdoc.PptxTable,
) -> @core.CoreBlock? {
  if !pptx_table_has_visible_cells(table) {
    return None
  }
  let source_ref = pptx_table_source_ref(state.source, slide, table)
  let block = @core.make_block(@core.BlockKind::Table, "table", source_ref~)
  block.attrs.set("header_rows", "1")
  block.attrs.set(
    "table_column_count",
    pptx_table_column_count(table).to_string(),
  )
  for row in table.rows {
    let row_ref = @core.source_ref_with_extra(
      pptx_table_source_ref(state.source, slide, table),
      "row_index",
      row.row_index.to_string(),
    )
    let row_block = @core.make_block(
      @core.BlockKind::TableRow,
      "",
      source_ref=row_ref,
    )
    for cell in row.cells {
      let cell_ref = @core.source_ref_with_extra(
        @core.source_ref_with_extra(
          pptx_table_source_ref(state.source, slide, table),
          "row_index",
          cell.row_index.to_string(),
        ),
        "column_index",
        cell.column_index.to_string(),
      )
      let cell_block = @core.make_block(
        @core.BlockKind::TableCell,
        pptx_table_cell_text(cell),
        source_ref=cell_ref,
      )
      row_block.children.push(cell_block)
      let grid_span = cell.grid_span.unwrap_or(1)
      if grid_span > 1 {
        for _ in 1..<grid_span {
          row_block.children.push(
            @core.make_block(
              @core.BlockKind::TableCell,
              "",
              source_ref=cell_ref,
            ),
          )
        }
      }
    }
    block.children.push(row_block)
  }
  Some(block)
}

///|
fn pptx_table_has_visible_cells(table : @pptxdoc.PptxTable) -> Bool {
  for row in table.rows {
    for cell in row.cells {
      if pptx_table_cell_text(cell).trim() != "" {
        return true
      }
    }
  }
  false
}

///|
fn pptx_table_column_count(table : @pptxdoc.PptxTable) -> Int {
  let mut width = 0
  for row in table.rows {
    let mut row_width = 0
    for cell in row.cells {
      row_width += cell.grid_span.unwrap_or(1)
    }
    if row_width > width {
      width = row_width
    }
  }
  width
}

///|
fn pptx_table_cell_text(cell : @pptxdoc.PptxTableCell) -> String {
  let parts : Array[String] = []
  for para in cell.paragraphs {
    let text = pptx_plain_text_from_paragraph(para).trim().to_owned()
    if text != "" {
      parts.push(text)
    }
  }
  parts.join("<br>")
}

///|
fn pptx_lower_chart(
  blocks : Array[@core.CoreBlock],
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  chart : @pptxdoc.PptxChartRef,
) -> Unit {
  let chart_blocks = pptx_chart_blocks(state, slide, chart)
  if chart_blocks.length() == 0 {
    blocks.push(
      pptx_raw_placeholder_block(
        state,
        slide,
        Some(chart.source_key),
        chart.relationship_id,
        "[Unsupported PPTX chart" + pptx_opt_suffix(chart.target_part) + "]",
        "pptx_chart_unsupported",
      ),
    )
    return
  }
  blocks.append(chart_blocks[:])
}

///|
fn pptx_chart_blocks(
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  chart : @pptxdoc.PptxChartRef,
) -> Array[@core.CoreBlock] {
  let out : Array[@core.CoreBlock] = []
  match pptx_chart_title_block(state, slide, chart) {
    Some(block) => out.push(block)
    None => ()
  }
  let cache_blocks = pptx_chart_cache_blocks(state, slide, chart)
  if cache_blocks.length() > 0 {
    out.append(cache_blocks[:])
  } else {
    match pptx_chart_missing_cache_block(state, slide, chart) {
      Some(block) => out.push(block)
      None => ()
    }
  }
  out
}

///|
fn pptx_chart_title_block(
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  chart : @pptxdoc.PptxChartRef,
) -> @core.CoreBlock? {
  match chart.title {
    Some(title) =>
      if title.trim() == "" {
        None
      } else {
        let block = @core.make_block(
          @core.BlockKind::Heading,
          title,
          source_ref=pptx_chart_source_ref(state.source, slide, chart),
        )
        block.attrs.set("level", "3")
        Some(block)
      }
    None => None
  }
}

///|
fn pptx_chart_cache_blocks(
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  chart : @pptxdoc.PptxChartRef,
) -> Array[@core.CoreBlock] {
  if pptx_chart_is_effectively_empty(chart) {
    return []
  }
  match pptx_chart_series_table_block(state, slide, chart) {
    Some(table) => return [table]
    None => ()
  }
  let list_blocks = pptx_chart_series_list_blocks(state, slide, chart)
  if list_blocks.length() > 0 {
    return list_blocks
  }
  match pptx_chart_category_value_table_block(state, slide, chart) {
    Some(table) => [table]
    None => []
  }
}

///|
fn pptx_chart_is_effectively_empty(chart : @pptxdoc.PptxChartRef) -> Bool {
  if chart.cached_series.length() > 0 {
    for series in chart.cached_series {
      if series.categories.length() > 0 ||
        series.values.length() > 0 ||
        series.text.length() > 0 {
        return false
      }
    }
    return true
  }
  chart.cached_categories.length() == 0 &&
  chart.cached_values.length() == 0 &&
  chart.cached_text.length() == 0
}

///|
fn pptx_chart_series_table_block(
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  chart : @pptxdoc.PptxChartRef,
) -> @core.CoreBlock? {
  if chart.cached_series.length() == 0 {
    return None
  }
  if !pptx_chart_can_render_series_table(chart) {
    return None
  }
  let categories = pptx_chart_table_categories(chart.cached_series)
  if categories.length() == 0 {
    return None
  }
  let source_ref = pptx_chart_source_ref(state.source, slide, chart)
  let block = @core.make_block(@core.BlockKind::Table, "table", source_ref~)
  block.attrs.set("header_rows", "1")
  block.attrs.set(
    "table_column_count",
    (chart.cached_series.length() + 1).to_string(),
  )
  let header = @core.make_block(
    @core.BlockKind::TableRow,
    "",
    source_ref=@core.source_ref_with_extra(source_ref, "row_index", "0"),
  )
  header.children.push(
    @core.make_block(
      @core.BlockKind::TableCell,
      "Category",
      source_ref=@core.source_ref_with_extra(
        @core.source_ref_with_extra(source_ref, "row_index", "0"),
        "column_index",
        "0",
      ),
    ),
  )
  for index in 0..<chart.cached_series.length() {
    let series = chart.cached_series[index]
    header.children.push(
      @core.make_block(
        @core.BlockKind::TableCell,
        series.name.unwrap_or("Series " + (index + 1).to_string()),
        source_ref=@core.source_ref_with_extra(
          @core.source_ref_with_extra(source_ref, "row_index", "0"),
          "column_index",
          (index + 1).to_string(),
        ),
      ),
    )
  }
  block.children.push(header)
  for row_index in 0..<categories.length() {
    let row = @core.make_block(
      @core.BlockKind::TableRow,
      "",
      source_ref=@core.source_ref_with_extra(
        source_ref,
        "row_index",
        (row_index + 1).to_string(),
      ),
    )
    row.children.push(
      @core.make_block(
        @core.BlockKind::TableCell,
        pptx_chart_display_value(categories[row_index]),
        source_ref=@core.source_ref_with_extra(
          @core.source_ref_with_extra(
            source_ref,
            "row_index",
            (row_index + 1).to_string(),
          ),
          "column_index",
          "0",
        ),
      ),
    )
    for series_index in 0..<chart.cached_series.length() {
      let series = chart.cached_series[series_index]
      let value = if row_index < series.values.length() {
        pptx_chart_display_value(series.values[row_index])
      } else {
        ""
      }
      row.children.push(
        @core.make_block(
          @core.BlockKind::TableCell,
          value,
          source_ref=@core.source_ref_with_extra(
            @core.source_ref_with_extra(
              source_ref,
              "row_index",
              (row_index + 1).to_string(),
            ),
            "column_index",
            (series_index + 1).to_string(),
          ),
        ),
      )
    }
    block.children.push(row)
  }
  Some(block)
}

///|
fn pptx_chart_table_categories(
  series_list : Array[@pptxdoc.PptxChartSeries],
) -> Array[String] {
  let mut best : Array[String] = []
  for series in series_list {
    let categories = pptx_chart_series_categories(series)
    if categories.length() > best.length() {
      best = categories
    }
  }
  best
}

///|
fn pptx_chart_can_render_series_table(chart : @pptxdoc.PptxChartRef) -> Bool {
  if chart.cached_series.length() == 0 {
    return false
  }
  let categories = pptx_chart_table_categories(chart.cached_series)
  if categories.length() == 0 {
    return false
  }
  for series in chart.cached_series {
    let series_categories = pptx_chart_series_categories(series)
    if series_categories.length() != categories.length() ||
      series.values.length() != categories.length() {
      return false
    }
  }
  true
}

///|
fn pptx_chart_series_list_blocks(
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  chart : @pptxdoc.PptxChartRef,
) -> Array[@core.CoreBlock] {
  let out : Array[@core.CoreBlock] = []
  for series_index in 0..<chart.cached_series.length() {
    let series = chart.cached_series[series_index]
    let categories = pptx_chart_series_categories(series)
    let pair_count = if categories.length() < series.values.length() {
      categories.length()
    } else {
      series.values.length()
    }
    if pair_count == 0 {
      continue
    }
    let heading = @core.make_block(
      @core.BlockKind::Heading,
      series.name.unwrap_or("Series " + (series_index + 1).to_string()),
      source_ref=pptx_chart_source_ref(state.source, slide, chart),
    )
    heading.attrs.set("level", "3")
    out.push(heading)
    for item_index in 0..<pair_count {
      let item = @core.make_block(
        @core.BlockKind::ListItem,
        pptx_chart_display_value(categories[item_index]) +
        ": " +
        pptx_chart_display_value(series.values[item_index]),
        source_ref=@core.source_ref_with_extra(
          @core.source_ref_with_extra(
            pptx_chart_source_ref(state.source, slide, chart),
            "series_index",
            series_index.to_string(),
          ),
          "item_index",
          item_index.to_string(),
        ),
      )
      item.attrs.set("ordered", "false")
      item.attrs.set("level", "0")
      out.push(item)
    }
  }
  out
}

///|
fn pptx_chart_series_categories(
  series : @pptxdoc.PptxChartSeries,
) -> Array[String] {
  if series.preferred_categories.length() > 0 {
    series.preferred_categories
  } else {
    series.categories
  }
}

///|
fn pptx_chart_category_value_table_block(
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  chart : @pptxdoc.PptxChartRef,
) -> @core.CoreBlock? {
  if chart.cached_categories.length() == 0 || chart.cached_values.length() == 0 {
    return None
  }
  let row_count = if chart.cached_categories.length() <
    chart.cached_values.length() {
    chart.cached_categories.length()
  } else {
    chart.cached_values.length()
  }
  if row_count == 0 {
    return None
  }
  let source_ref = pptx_chart_source_ref(state.source, slide, chart)
  let block = @core.make_block(@core.BlockKind::Table, "table", source_ref~)
  block.attrs.set("header_rows", "1")
  block.attrs.set("table_column_count", "2")
  let header = @core.make_block(
    @core.BlockKind::TableRow,
    "",
    source_ref=@core.source_ref_with_extra(source_ref, "row_index", "0"),
  )
  header.children.push(
    @core.make_block(
      @core.BlockKind::TableCell,
      "Category",
      source_ref=@core.source_ref_with_extra(
        @core.source_ref_with_extra(source_ref, "row_index", "0"),
        "column_index",
        "0",
      ),
    ),
  )
  header.children.push(
    @core.make_block(
      @core.BlockKind::TableCell,
      pptx_chart_category_value_header(chart),
      source_ref=@core.source_ref_with_extra(
        @core.source_ref_with_extra(source_ref, "row_index", "0"),
        "column_index",
        "1",
      ),
    ),
  )
  block.children.push(header)
  for row_index in 0..<row_count {
    let row = @core.make_block(
      @core.BlockKind::TableRow,
      "",
      source_ref=@core.source_ref_with_extra(
        source_ref,
        "row_index",
        (row_index + 1).to_string(),
      ),
    )
    row.children.push(
      @core.make_block(
        @core.BlockKind::TableCell,
        pptx_chart_display_value(chart.cached_categories[row_index]),
        source_ref=@core.source_ref_with_extra(
          @core.source_ref_with_extra(
            source_ref,
            "row_index",
            (row_index + 1).to_string(),
          ),
          "column_index",
          "0",
        ),
      ),
    )
    row.children.push(
      @core.make_block(
        @core.BlockKind::TableCell,
        pptx_chart_display_value(chart.cached_values[row_index]),
        source_ref=@core.source_ref_with_extra(
          @core.source_ref_with_extra(
            source_ref,
            "row_index",
            (row_index + 1).to_string(),
          ),
          "column_index",
          "1",
        ),
      ),
    )
    block.children.push(row)
  }
  Some(block)
}

///|
fn pptx_chart_category_value_header(chart : @pptxdoc.PptxChartRef) -> String {
  for series in chart.cached_series {
    match series.name {
      Some(name) => if name.trim() != "" { return name }
      None => ()
    }
  }
  if chart.cached_text.length() > 0 {
    let candidate = chart.cached_text[0].trim().to_owned()
    if candidate != "" {
      return candidate
    }
  }
  "Value"
}

///|
fn pptx_chart_missing_cache_block(
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  chart : @pptxdoc.PptxChartRef,
) -> @core.CoreBlock? {
  if !pptx_chart_should_emit_cache_fallback(chart) {
    return None
  }
  state.chart_fallback_emitted.val = true
  let raw = @core.make_block(
    @core.BlockKind::Raw,
    "[Chart data not embedded in chart cache]",
    source_ref=pptx_chart_source_ref(state.source, slide, chart),
  )
  raw.attrs.set("raw_kind", "pptx_chart_cache_missing")
  Some(raw)
}

///|
fn pptx_chart_should_emit_cache_fallback(chart : @pptxdoc.PptxChartRef) -> Bool {
  if chart.cached_series.length() == 0 &&
    chart.cached_categories.length() == 0 &&
    chart.cached_values.length() == 0 {
    return true
  }
  let mut saw_value = false
  let mut saw_renderable_pair = false
  for series in chart.cached_series {
    if series.values.length() > 0 {
      saw_value = true
    }
    let pair_count = if series.categories.length() < series.values.length() {
      series.categories.length()
    } else {
      series.values.length()
    }
    if pair_count > 0 {
      saw_renderable_pair = true
    }
  }
  if saw_renderable_pair {
    return false
  }
  if chart.cached_categories.length() > 0 && chart.cached_values.length() > 0 {
    return false
  }
  saw_value || chart.cached_values.length() > 0
}

///|
fn pptx_chart_source_ref(
  source : @input.InputSource,
  slide : @pptxdoc.PptxSlide,
  chart : @pptxdoc.PptxChartRef,
) -> @core.SourceRef {
  let base = pptx_slide_source_ref(
    source,
    slide,
    Some(chart.source_key),
    chart.relationship_id,
  )
  let base = match chart.target_part {
    Some(part) => @core.source_ref_with_extra(base, "part_name", part)
    None => base
  }
  match pptx_slide_reading_order_key(slide, chart.source_key) {
    Some(order_key) =>
      @core.source_ref_with_extra(base, "reading_order_key", order_key)
    None => base
  }
}

///|
fn pptx_chart_display_value(value : String) -> String {
  let trimmed = value.trim().to_owned()
  match pptx_chart_excel_serial_date(trimmed) {
    Some(date) => date
    None => trimmed
  }
}

///|
fn pptx_chart_excel_serial_date(value : String) -> String? {
  let rounded = match pptx_parse_chart_serial_int(value) {
    Some(serial) => serial
    None => return None
  }
  if rounded < 20000 || rounded > 50000 {
    return None
  }
  let (year, month, day) = pptx_excel_date_components(rounded)
  if year <= 0 || month <= 0 || day <= 0 {
    return None
  }
  Some(
    year.to_string() + "-" + pptx_two_digits(month) + "-" + pptx_two_digits(day),
  )
}

///|
fn pptx_parse_chart_serial_int(value : String) -> Int? {
  let trimmed = value.trim().to_owned()
  if trimmed == "" {
    return None
  }
  if trimmed.contains("e") || trimmed.contains("E") || trimmed.contains("-") {
    return None
  }
  let chars = trimmed.to_array()
  let mut dot_index = -1
  for index in 0..<chars.length() {
    if chars[index] == '.' {
      if dot_index >= 0 {
        return None
      }
      dot_index = index
    }
  }
  if dot_index < 0 {
    return Some(@string.parse_int(trimmed) catch { _ => return None })
  }
  let whole = String::from_array(chars[:dot_index])
  let frac = String::from_array(chars[dot_index + 1:])
  if whole == "" || frac == "" {
    return None
  }
  for ch in frac {
    if ch != '0' {
      return None
    }
  }
  Some(@string.parse_int(whole) catch { _ => return None })
}

///|
fn pptx_excel_date_components(serial : Int) -> (Int, Int, Int) {
  let mut days = serial
  if days > 59 {
    days -= 1
  }
  days -= 1
  if days < 0 {
    return (0, 0, 0)
  }
  let mut year = 1900
  while true {
    let year_days = if pptx_is_leap_year(year) { 366 } else { 365 }
    if days >= year_days {
      days -= year_days
      year += 1
    } else {
      break
    }
  }
  let month_days = pptx_month_day_table(year)
  let mut month = 1
  for day_count in month_days {
    if days >= day_count {
      days -= day_count
      month += 1
    } else {
      break
    }
  }
  (year, month, days + 1)
}

///|
fn pptx_is_leap_year(year : Int) -> Bool {
  if year % 400 == 0 {
    return true
  }
  if year % 100 == 0 {
    return false
  }
  year % 4 == 0
}

///|
fn pptx_month_day_table(year : Int) -> Array[Int] {
  if pptx_is_leap_year(year) {
    [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  } else {
    [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  }
}

///|
fn pptx_plain_text_from_paragraph(para : @pptxdoc.PptxParagraph) -> String {
  let synthetic : Array[@core.CoreInline] = []
  for run in para.runs {
    for inline in run.inlines {
      match inline {
        @pptxdoc.PptxInline::Text(text) =>
          synthetic.push(
            @core.make_inline_text(pptx_normalize_text_fragment(text)),
          )
        @pptxdoc.PptxInline::Break =>
          synthetic.push(@core.make_inline_line_break())
        @pptxdoc.PptxInline::Field(text) =>
          synthetic.push(
            @core.make_inline_text(pptx_normalize_text_fragment(text)),
          )
        @pptxdoc.PptxInline::Hyperlink(_, text) =>
          synthetic.push(
            @core.make_inline_text(pptx_normalize_text_fragment(text)),
          )
        @pptxdoc.PptxInline::Unsupported(_) => ()
      }
    }
  }
  pptx_plain_text(pptx_compact_text_inlines(synthetic))
}

///|
fn pptx_lower_slide_comments(
  blocks : Array[@core.CoreBlock],
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
) -> Unit {
  if slide.comments.length() == 0 {
    return
  }
  let heading = @core.make_block(
    @core.BlockKind::Heading,
    "Comments",
    source_ref=pptx_slide_source_ref(state.source, slide, None, None),
  )
  heading.attrs.set("level", "3")
  blocks.push(heading)
  for comment in slide.comments {
    let prefix = match comment.author_name {
      Some(name) => name + ": "
      None =>
        if comment.author_id.trim() == "" {
          ""
        } else {
          "Author " + comment.author_id + ": "
        }
    }
    let block = @core.make_block(
      @core.BlockKind::ListItem,
      prefix + comment.text,
      source_ref=@core.source_ref_with_extra(
        pptx_slide_source_ref(
          state.source,
          slide,
          Some(comment.source_key),
          None,
        ),
        "comment_id",
        comment.idx.unwrap_or(""),
      ),
    )
    block.attrs.set("ordered", "false")
    block.attrs.set("level", "0")
    blocks.push(block)
  }
}

///|
fn pptx_lower_slide_notes(
  blocks : Array[@core.CoreBlock],
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
) -> Unit {
  let notes = match slide.notes {
    Some(value) => value
    None => return
  }
  let note_blocks : Array[@core.CoreBlock] = []
  let hidden_note_text = hidden_slide_note_text(slide)
  let heading = @core.make_block(
    @core.BlockKind::Heading,
    "Speaker Notes",
    source_ref=@core.source_ref_with_extra(
      pptx_slide_source_ref(state.source, slide, Some(notes.source_key), None),
      "notes_part",
      notes.part_name,
    ),
  )
  heading.attrs.set("level", "3")
  for para in notes.paragraphs {
    let text = pptx_plain_text_from_paragraph(para).trim().to_owned()
    if text == "" ||
      pptx_notes_paragraph_is_page_number(slide, text, para.source_key) ||
      hidden_note_text == Some(text) {
      continue
    }
    let block = @core.make_block(
      @core.BlockKind::Paragraph,
      text,
      source_ref=@core.source_ref_with_extra(
        pptx_slide_source_ref(state.source, slide, Some(para.source_key), None),
        "notes_part",
        notes.part_name,
      ),
    )
    note_blocks.push(block)
  }
  if note_blocks.length() == 0 {
    return
  }
  blocks.push(heading)
  blocks.append(note_blocks[:])
}

///|
fn pptx_notes_paragraph_is_page_number(
  slide : @pptxdoc.PptxSlide,
  text : String,
  source_key : @pptxdoc.PptxSourceKey,
) -> Bool {
  let trimmed = text.trim()
  let page = @string.parse_int(trimmed) catch { _ => return false }
  source_key.node_key.contains("shape-4") ||
  source_key.node_key.contains("shape-2") ||
  page == slide.slide_index
}

///|
fn hidden_slide_note_text(slide : @pptxdoc.PptxSlide) -> String? {
  if !slide.hidden {
    return None
  }
  match slide.notes {
    Some(notes) =>
      for para in notes.paragraphs {
        let text = pptx_plain_text_from_paragraph(para).trim().to_owned()
        if text != "" {
          return Some(text)
        }
      }
    None => ()
  }
  None
}

///|
fn pptx_note_hidden_slide_skipped(
  diagnostics : @core.Diagnostics,
  slide_index : Int,
) -> Unit {
  let warning = "hidden pptx slide skipped: Slide " + slide_index.to_string()
  if !diagnostics.warnings.contains(warning) {
    diagnostics.warnings.push(warning)
  }
  if !diagnostics.degraded_features.contains("pptx_hidden_slide_skipped") {
    diagnostics.degraded_features.push("pptx_hidden_slide_skipped")
  }
}

///|
fn pptx_append_document_warnings(
  blocks : Array[@core.CoreBlock],
  state : PptxState,
) -> Unit {
  if state.chart_fallback_emitted.val &&
    !state.diagnostics.degraded_features.contains("pptx_chart_cache_fallback") {
    state.diagnostics.degraded_features.push("pptx_chart_cache_fallback")
  }
  if state.presentation.warnings.length() == 0 {
    return
  }
  let heading = @core.make_block(
    @core.BlockKind::Heading,
    "PPTX Warnings",
    source_ref=@core.empty_source_ref(),
  )
  heading.attrs.set("level", "2")
  blocks.push(heading)
  for warning in state.presentation.warnings {
    let source_ref = match warning.source_span {
      Some(span) =>
        @core.source_ref_with_extra(
          pptx_root_source_ref(state.source),
          "slide_part",
          span.part_name,
        )
      None => pptx_root_source_ref(state.source)
    }
    let block = @core.make_block(
      @core.BlockKind::ListItem,
      warning.message,
      source_ref~,
    )
    block.attrs.set("ordered", "false")
    block.attrs.set("level", "0")
    blocks.push(block)
  }
}

///|
fn pptx_root_source_ref(source : @input.InputSource) -> @core.SourceRef {
  @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some(source.source_name),
    Some("pptx"),
    source.path,
    None,
    None,
    Some("pptx"),
    None,
  )
}

///|
fn pptx_slide_source_ref(
  source : @input.InputSource,
  slide : @pptxdoc.PptxSlide,
  source_key : @pptxdoc.PptxSourceKey?,
  shape_id : String?,
) -> @core.SourceRef {
  let inner_path = match source_key {
    Some(key) => Some(key.node_key)
    None => Some(slide.source_key.node_key)
  }
  let entry_path = match source_key {
    Some(key) => Some(key.part_name)
    None => Some(slide.part_name)
  }
  let source_ref = @core.source_ref_with_office_fields(
    @core.source_ref_with_container_entry(
      @core.empty_source_ref(),
      Some(source.source_name),
      Some("pptx"),
      source.path,
      entry_path,
      None,
      Some("pptx"),
      inner_path,
    ),
    Some(source.source_name),
    Some("pptx"),
    inner_path,
    None,
    None,
    Some(slide.slide_index),
    shape_id,
    slide.relationship_id,
  )
  let source_ref = @core.source_ref_with_extra(
    source_ref,
    "slide_index",
    slide.slide_index.to_string(),
  )
  let source_ref = match slide.slide_id {
    Some(slide_id) =>
      @core.source_ref_with_extra(source_ref, "slide_id", slide_id)
    None => source_ref
  }
  let source_ref = @core.source_ref_with_extra(
    source_ref,
    "slide_part",
    slide.part_name,
  )
  let source_ref = match slide.layout_ref {
    Some(layout) =>
      @core.source_ref_with_extra(source_ref, "layout_part", layout.part_name)
    None => source_ref
  }
  match slide.master_ref {
    Some(master) =>
      @core.source_ref_with_extra(source_ref, "master_part", master.part_name)
    None => source_ref
  }
}

///|
fn pptx_shape_source_ref(
  source : @input.InputSource,
  slide : @pptxdoc.PptxSlide,
  shape : @pptxdoc.PptxShape,
  source_key : @pptxdoc.PptxSourceKey?,
) -> @core.SourceRef {
  let base = pptx_slide_source_ref(source, slide, source_key, shape.shape_id)
  let base = match shape.name {
    Some(name) => @core.source_ref_with_extra(base, "shape_name", name)
    None => base
  }
  let base = match shape.shape_type {
    Some(shape_type) =>
      @core.source_ref_with_extra(base, "shape_type", shape_type)
    None => base
  }
  let base = match pptx_placeholder_kind_name(shape) {
    Some(kind) => @core.source_ref_with_extra(base, "placeholder_type", kind)
    None => base
  }
  let base = match pptx_placeholder_index(shape) {
    Some(index) => @core.source_ref_with_extra(base, "placeholder_idx", index)
    None => base
  }
  match shape.reading_order {
    Some(order) =>
      @core.source_ref_with_extra(base, "reading_order_key", order.order_key)
    None => base
  }
}

///|
fn pptx_next_shape_top(
  slide : @pptxdoc.PptxSlide,
  shape : @pptxdoc.PptxShape,
) -> Int? {
  let current_top = match shape_geometry_top(shape) {
    Some(value) => value
    None => return None
  }
  let mut next_top : Int? = None
  for obj in slide.objects {
    match obj {
      @pptxdoc.PptxObject::Shape(other) =>
        if other.shape_id != shape.shape_id {
          match shape_geometry_top(other) {
            Some(top) =>
              if top > current_top {
                match next_top {
                  Some(current) => if top < current { next_top = Some(top) }
                  None => next_top = Some(top)
                }
              }
            None => ()
          }
        }
      _ => ()
    }
  }
  next_top
}

///|
fn shape_geometry_top(shape : @pptxdoc.PptxShape) -> Int? {
  match shape.geometry {
    Some(geo) => geo.y
    None => None
  }
}

///|
fn pptx_picture_source_ref(
  source : @input.InputSource,
  slide : @pptxdoc.PptxSlide,
  pic : @pptxdoc.PptxPicture,
) -> @core.SourceRef {
  let base = pptx_slide_source_ref(
    source,
    slide,
    Some(pic.source_key),
    pic.shape_id,
  )
  let base = match pic.name {
    Some(name) => @core.source_ref_with_extra(base, "shape_name", name)
    None => base
  }
  let base = @core.source_ref_with_extra(base, "shape_type", "picture")
  match pic.reading_order {
    Some(order) =>
      @core.source_ref_with_extra(base, "reading_order_key", order.order_key)
    None => base
  }
}

///|
fn pptx_table_source_ref(
  source : @input.InputSource,
  slide : @pptxdoc.PptxSlide,
  table : @pptxdoc.PptxTable,
) -> @core.SourceRef {
  let base = @core.source_ref_with_extra(
    pptx_slide_source_ref(source, slide, Some(table.source_key), None),
    "shape_type",
    "table",
  )
  match pptx_slide_reading_order_key(slide, table.source_key) {
    Some(order_key) =>
      @core.source_ref_with_extra(base, "reading_order_key", order_key)
    None => base
  }
}

///|
fn pptx_placeholder_kind_name(shape : @pptxdoc.PptxShape) -> String? {
  match shape.placeholder {
    Some(ph) => Some(pptx_placeholder_kind_to_string(ph.kind))
    None =>
      match shape.direct_placeholder {
        Some(ph) => Some(pptx_placeholder_kind_to_string(ph.kind))
        None => None
      }
  }
}

///|
fn pptx_placeholder_index(shape : @pptxdoc.PptxShape) -> String? {
  match shape.placeholder {
    Some(ph) => ph.index
    None =>
      match shape.direct_placeholder {
        Some(ph) => ph.index
        None => None
      }
  }
}

///|
fn pptx_placeholder_kind_to_string(
  kind : @pptxdoc.PptxPlaceholderKind,
) -> String {
  match kind {
    @pptxdoc.PptxPlaceholderKind::Title => "title"
    @pptxdoc.PptxPlaceholderKind::CenterTitle => "center_title"
    @pptxdoc.PptxPlaceholderKind::Subtitle => "subtitle"
    @pptxdoc.PptxPlaceholderKind::Body => "body"
    @pptxdoc.PptxPlaceholderKind::Footer => "footer"
    @pptxdoc.PptxPlaceholderKind::Date => "date"
    @pptxdoc.PptxPlaceholderKind::SlideNumber => "slide_number"
    @pptxdoc.PptxPlaceholderKind::Picture => "picture"
    @pptxdoc.PptxPlaceholderKind::Table => "table"
    @pptxdoc.PptxPlaceholderKind::Unknown => "unknown"
  }
}

///|
fn pptx_raw_placeholder_block(
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  source_key : @pptxdoc.PptxSourceKey?,
  relationship_id : String?,
  text : String,
  raw_kind : String,
) -> @core.CoreBlock {
  let source_ref0 = pptx_slide_source_ref(state.source, slide, source_key, None)
  let source_ref0 = match source_key {
    Some(key) =>
      match pptx_slide_reading_order_key(slide, key) {
        Some(order_key) =>
          @core.source_ref_with_extra(
            source_ref0, "reading_order_key", order_key,
          )
        None => source_ref0
      }
    None => source_ref0
  }
  let source_ref = match relationship_id {
    Some(rid) =>
      @core.source_ref_with_extra(source_ref0, "relationship_id", rid)
    None => source_ref0
  }
  let raw = @core.make_block(@core.BlockKind::Raw, text, source_ref~)
  raw.attrs.set("raw_kind", raw_kind)
  raw
}

///|
fn pptx_opt_suffix(value : String?) -> String {
  match value {
    Some(text) => ": " + text
    None => ""
  }
}

///|
fn pptx_slide_reading_order_key(
  slide : @pptxdoc.PptxSlide,
  source_key : @pptxdoc.PptxSourceKey,
) -> String? {
  for obj in slide.objects {
    match pptx_object_reading_order_key(obj, source_key) {
      Some(order_key) => return Some(order_key)
      None => ()
    }
  }
  None
}

///|
fn pptx_object_reading_order_key(
  obj : @pptxdoc.PptxObject,
  source_key : @pptxdoc.PptxSourceKey,
) -> String? {
  match obj {
    @pptxdoc.PptxObject::Shape(shape) =>
      if pptx_source_keys_match(shape.source_key, source_key) {
        match shape.reading_order {
          Some(order) => Some(order.order_key)
          None => None
        }
      } else {
        None
      }
    @pptxdoc.PptxObject::Group(group) =>
      if pptx_source_keys_match(group.source_key, source_key) {
        match group.reading_order {
          Some(order) => Some(order.order_key)
          None => None
        }
      } else {
        for child in group.children {
          match pptx_object_reading_order_key(child, source_key) {
            Some(order_key) => return Some(order_key)
            None => ()
          }
        }
        None
      }
    @pptxdoc.PptxObject::Picture(pic) =>
      if pptx_source_keys_match(pic.source_key, source_key) {
        match pic.reading_order {
          Some(order) => Some(order.order_key)
          None => None
        }
      } else {
        None
      }
    @pptxdoc.PptxObject::Table(table) =>
      if pptx_source_keys_match(table.source_key, source_key) {
        Some("950:999999999:999999999:" + table.source_key.node_key)
      } else {
        None
      }
    @pptxdoc.PptxObject::Chart(chart) =>
      if pptx_source_keys_match(chart.source_key, source_key) {
        Some("950:999999999:999999999:" + chart.source_key.node_key)
      } else {
        None
      }
    @pptxdoc.PptxObject::SmartArt(smart) =>
      if pptx_source_keys_match(smart.source_key, source_key) {
        Some("950:999999999:999999999:" + smart.source_key.node_key)
      } else {
        None
      }
    @pptxdoc.PptxObject::Ole(ole) =>
      if pptx_source_keys_match(ole.source_key, source_key) {
        Some("950:999999999:999999999:" + ole.source_key.node_key)
      } else {
        None
      }
    @pptxdoc.PptxObject::Connector(conn) =>
      if pptx_source_keys_match(conn.source_key, source_key) {
        Some("950:999999999:999999999:" + conn.source_key.node_key)
      } else {
        None
      }
    @pptxdoc.PptxObject::Unsupported(unsupported) =>
      if pptx_source_keys_match(unsupported.source_key, source_key) {
        Some("950:999999999:999999999:" + unsupported.source_key.node_key)
      } else {
        None
      }
  }
}

///|
fn pptx_source_keys_match(
  left : @pptxdoc.PptxSourceKey,
  right : @pptxdoc.PptxSourceKey,
) -> Bool {
  left.part_name == right.part_name && left.node_key == right.node_key
}
