///|
fn lower_docx_document_ir(
  source : @input.InputSource,
  docx : @ddocx.DocxDocument,
  pkg : @ox.OoxmlPackage,
  diagnostics : @core.Diagnostics,
  context : @parser.ParseContext,
) -> @core.DocumentIR {
  let document = @core.empty_document_ir()
  fill_docx_metadata(document.metadata, docx)
  let state = new_docx_lowering_state(
    source, docx, pkg, document, diagnostics, context,
  )
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
  lowering_profile : @product.LoweringProfile
  accurate_features : @product.AccurateFeatureProfile
  assets : Array[@core.AssetRef]
  asset_ids : Map[String, String]
  footnote_labels : Map[String, String]
  endnote_labels : Map[String, String]
  comment_labels : Map[String, String]
  footnotes_by_id : Map[String, @ddocx.DocxNote]
  endnotes_by_id : Map[String, @ddocx.DocxNote]
  comments_by_id : Map[String, @ddocx.DocxComment]
  consumed_textbox_anchors : Map[String, Bool]
  expanding_textbox_anchors : Array[String]
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
  context : @parser.ParseContext,
) -> DocxLoweringState {
  let footnote_labels : Map[String, String] = Map([])
  let endnote_labels : Map[String, String] = Map([])
  let comment_labels : Map[String, String] = Map([])
  let assets : Array[@core.AssetRef] = []
  let asset_ids : Map[String, String] = Map([])
  let footnotes_by_id : Map[String, @ddocx.DocxNote] = Map([])
  let endnotes_by_id : Map[String, @ddocx.DocxNote] = Map([])
  let comments_by_id : Map[String, @ddocx.DocxComment] = Map([])
  let consumed_textbox_anchors : Map[String, Bool] = Map([])
  let expanding_textbox_anchors : Array[String] = []

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
    lowering_profile: context.lowering_profile,
    accurate_features: context.accurate_features,
    assets,
    asset_ids,
    footnote_labels,
    endnote_labels,
    comment_labels,
    footnotes_by_id,
    endnotes_by_id,
    comments_by_id,
    consumed_textbox_anchors,
    expanding_textbox_anchors,
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
      ExternalRelationship => external_relationship_count += 1
      MissingRelationshipTarget => missing_relationship_target_count += 1
      UnsafeRelationshipTarget => unsupported_relationship_count += 1
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
      entries.set(prop.name, String(prop.value))
    }
    metadata.set("custom_properties", Object(entries))
  }
}

///|
fn set_document_metadata_string(
  metadata : @core.DocumentMetadata,
  key : String,
  value : String?,
) -> Unit {
  match value {
    Some(text) => if text.trim() != "" { metadata.set(key, String(text)) }
    None => ()
  }
}
