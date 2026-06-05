///|
pub struct DocxExportedAsset {
  path : String
  source_part : String
  content_type : String?
  relationship_id : String?
  alt_text : String?
  title : String?
  origin_id : String
}

///|
pub struct DocxLoweredDocument {
  document : @cor.Document
  assets : Array[DocxExportedAsset]
}

///|
priv struct DocxAssetExportCtx {
  pkg : @ox.OoxmlPackage
  out_dir : String
  next_idx : Ref[Int]
  by_source_part : Map[String, String]
  assets : Array[DocxExportedAsset]
}

///|
pub fn open_docx_model(path : String) -> @docmodel.DocxDocument raise {
  let bytes = @fs.read_file_to_bytes(path) catch {
    e => raise @cor.AppError("docx: read failed: " + e.to_string())
  }
  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => raise @cor.AppError("docx: open package failed: " + e.to_string())
  }
  @docmodel.parse_docx_document_from_package(pkg) catch {
    e => raise @cor.AppError("docx: parse failed: " + e.to_string())
  }
}

///|
pub fn open_docx_document_with_assets(
  path : String,
  out_dir : String,
) -> DocxLoweredDocument raise {
  let bytes = @fs.read_file_to_bytes(path) catch {
    e => raise @cor.AppError("docx: read failed: " + e.to_string())
  }
  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => raise @cor.AppError("docx: open package failed: " + e.to_string())
  }
  let model = @docmodel.parse_docx_document_from_package(pkg) catch {
    e => raise @cor.AppError("docx: parse failed: " + e.to_string())
  }
  lower_docx_document_with_assets(model, pkg, out_dir)
}

///|
pub fn open_docx_document(path : String) -> @cor.Document raise {
  lower_docx_document(open_docx_model(path))
}

///|
pub fn parse_docx(
  path : String,
  out_root : String,
  _max_heading : Int,
) -> @cor.Document raise {
  normalize_docx_product_origins(
    open_docx_document_with_assets(path, out_root).document,
    @cor.basename(path),
  )
}

///|
pub fn render_docx_markdown_file(path : String) -> String raise {
  @cor.emit_markdown(open_docx_document(path))
}

///|
pub fn render_docx_warning_summary(docx : @docmodel.DocxDocument) -> String {
  let lines : Array[String] = []
  for warning in docx.warnings {
    let location = match warning.source_key {
      Some(key) =>
        key.part_name + "#" + key.block_index.to_string() + ":" + key.node_key
      None => "unknown"
    }
    lines.push(
      docx_warning_kind_name(warning.kind) +
      "\t" +
      docx_warning_severity_name(warning.severity) +
      "\t" +
      location +
      "\t" +
      warning.message,
    )
  }
  lines.join("\n")
}

///|
fn docx_warning_kind_name(kind : @docmodel.DocxWarningKind) -> String {
  match kind {
    @docmodel.DocxWarningKind::MissingMainDocument => "MissingMainDocument"
    @docmodel.DocxWarningKind::MalformedDocumentXml => "MalformedDocumentXml"
    @docmodel.DocxWarningKind::MissingHyperlinkTarget =>
      "MissingHyperlinkTarget"
    @docmodel.DocxWarningKind::MissingMediaTarget => "MissingMediaTarget"
    @docmodel.DocxWarningKind::MissingMediaPart => "MissingMediaPart"
    @docmodel.DocxWarningKind::UnsupportedMedia => "UnsupportedMedia"
    @docmodel.DocxWarningKind::UnsupportedMath => "UnsupportedMath"
    @docmodel.DocxWarningKind::MissingStylesPart => "MissingStylesPart"
    @docmodel.DocxWarningKind::MissingNumberingPart => "MissingNumberingPart"
    @docmodel.DocxWarningKind::MissingContainerPart => "MissingContainerPart"
    @docmodel.DocxWarningKind::NestedTable => "NestedTable"
    @docmodel.DocxWarningKind::UnsupportedTextbox => "UnsupportedTextbox"
    @docmodel.DocxWarningKind::UnknownBodyNode => "UnknownBodyNode"
    @docmodel.DocxWarningKind::UnsupportedTable => "UnsupportedTable"
    @docmodel.DocxWarningKind::UnsupportedField => "UnsupportedField"
    @docmodel.DocxWarningKind::UnsupportedBookmark => "UnsupportedBookmark"
    @docmodel.DocxWarningKind::TrackedChange => "TrackedChange"
    @docmodel.DocxWarningKind::UnsupportedInline => "UnsupportedInline"
    @docmodel.DocxWarningKind::UnresolvedFootnoteRef => "UnresolvedFootnoteRef"
    @docmodel.DocxWarningKind::UnresolvedEndnoteRef => "UnresolvedEndnoteRef"
    @docmodel.DocxWarningKind::UnresolvedCommentRef => "UnresolvedCommentRef"
  }
}

///|
fn docx_warning_severity_name(
  severity : @docmodel.DocxWarningSeverity,
) -> String {
  match severity {
    @docmodel.DocxWarningSeverity::Warning => "Warning"
    @docmodel.DocxWarningSeverity::Error => "Error"
  }
}

///|
pub fn lower_docx_document(docx : @docmodel.DocxDocument) -> @cor.Document {
  let doc = @cor.new_document()
  let comment_labels = docx_body_comment_labels(docx)
  for block in docx.body {
    push_docx_block_with_comment_labels(
      doc,
      docx,
      block,
      None,
      Some(comment_labels),
    )
  }
  append_docx_resolved_appendices(doc, docx)
  doc
}

///|
pub fn lower_docx_document_with_assets(
  docx : @docmodel.DocxDocument,
  pkg : @ox.OoxmlPackage,
  out_dir : String,
) -> DocxLoweredDocument {
  let doc = @cor.new_document()
  let ctx = new_docx_asset_export_ctx(pkg, out_dir)
  let ctx_opt = if out_dir.trim() == "" { None } else { Some(ctx) }
  let comment_labels = docx_body_comment_labels(docx)
  for block in docx.body {
    push_docx_block_with_comment_labels(
      doc,
      docx,
      block,
      ctx_opt,
      Some(comment_labels),
    )
  }
  append_docx_resolved_appendices_with_ctx(doc, docx, ctx_opt)
  {
    document: doc,
    assets: match ctx_opt {
      Some(value) => value.assets
      None => []
    },
  }
}

///|
fn new_docx_asset_export_ctx(
  pkg : @ox.OoxmlPackage,
  out_dir : String,
) -> DocxAssetExportCtx {
  if out_dir.trim() != "" {
    let assets_dir = out_dir + "/assets"
    if !@fs.path_exists(assets_dir) {
      ignore(@fs.create_dir(assets_dir) catch { _ => () })
    }
  }
  { pkg, out_dir, next_idx: { val: 0 }, by_source_part: Map([]), assets: [] }
}

///|
fn push_docx_block(
  doc : @cor.Document,
  docx : @docmodel.DocxDocument,
  block : @docmodel.DocxBlock,
  asset_ctx : DocxAssetExportCtx?,
) -> Unit {
  push_docx_block_with_comment_labels(doc, docx, block, asset_ctx, None)
}

///|
fn push_docx_block_with_comment_labels(
  doc : @cor.Document,
  docx : @docmodel.DocxDocument,
  block : @docmodel.DocxBlock,
  asset_ctx : DocxAssetExportCtx?,
  comment_labels : Map[String, String]?,
) -> Unit {
  match block {
    @docmodel.DocxBlock::Paragraph(p) =>
      push_docx_paragraph_block(doc, docx, p, asset_ctx, comment_labels)
    @docmodel.DocxBlock::Table(table) => {
      let rows = docx_table_rows(table, asset_ctx)
      if rows.length() > 0 {
        push_docx_block_with_origin(
          doc,
          @cor.Block::RichTable({
            rows,
            header_rows: docx_table_header_rows(table),
            hints: None,
          }),
          Some(table.source_key),
        )
      }
    }
    @docmodel.DocxBlock::TablePlaceholder(placeholder) =>
      push_docx_block_with_origin(
        doc,
        @cor.Block::Paragraph("[Unsupported DOCX table omitted by v2 skeleton]"),
        Some(placeholder.source_key),
      )
    @docmodel.DocxBlock::ContentControl(control) =>
      push_docx_content_control_block(
        doc, docx, control, asset_ctx, comment_labels,
      )
    @docmodel.DocxBlock::StructuralMarker(_) => ()
    @docmodel.DocxBlock::Unsupported(warning) =>
      push_docx_block_with_origin(
        doc,
        @cor.Block::Paragraph(
          "[Unsupported DOCX node: " + warning.message + "]",
        ),
        warning.source_key,
      )
  }
}

///|
fn push_docx_content_control_block(
  doc : @cor.Document,
  docx : @docmodel.DocxDocument,
  control : @docmodel.DocxContentControl,
  asset_ctx : DocxAssetExportCtx?,
  comment_labels : Map[String, String]?,
) -> Unit {
  if control.blocks.length() > 0 {
    push_docx_blocks_with_comment_labels(
      doc,
      docx,
      control.blocks,
      asset_ctx,
      comment_labels,
    )
  } else if control.inlines.length() > 0 {
    push_docx_inline_chunk_with_comment_labels(
      doc,
      control.inlines,
      Some(control.source_key),
      comment_labels,
    )
  } else if control.text.trim() != "" {
    push_docx_block_with_origin(
      doc,
      @cor.Block::Paragraph(control.text),
      Some(control.source_key),
    )
  }
}

///|
fn append_docx_resolved_appendices(
  doc : @cor.Document,
  docx : @docmodel.DocxDocument,
) -> Unit {
  append_docx_resolved_appendices_with_ctx(doc, docx, None)
}

///|
fn append_docx_resolved_appendices_with_ctx(
  doc : @cor.Document,
  docx : @docmodel.DocxDocument,
  asset_ctx : DocxAssetExportCtx?,
) -> Unit {
  let footnote_ids : Array[String] = []
  let endnote_ids : Array[String] = []
  let comment_ids : Array[String] = []
  collect_docx_refs(docx.body, footnote_ids, endnote_ids, comment_ids)
  append_docx_note_definitions(doc, docx, footnote_ids, endnote_ids, asset_ctx)
  append_docx_comments(doc, docx, comment_ids, asset_ctx)
  append_docx_part_bodies(
    doc,
    docx,
    docx.headers,
    "Headers",
    "Header",
    asset_ctx,
  )
  append_docx_part_bodies(
    doc,
    docx,
    docx.footers,
    "Footers",
    "Footer",
    asset_ctx,
  )
  append_docx_textboxes(doc, docx, asset_ctx)
}

///|
fn collect_docx_refs(
  blocks : Array[@docmodel.DocxBlock],
  footnote_ids : Array[String],
  endnote_ids : Array[String],
  comment_ids : Array[String],
) -> Unit {
  for block in blocks {
    match block {
      @docmodel.DocxBlock::Paragraph(p) =>
        collect_docx_inline_refs(
          p.inlines,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
      @docmodel.DocxBlock::Table(table) =>
        for row in table.rows {
          for cell in row.cells {
            collect_docx_refs(
              cell.blocks,
              footnote_ids,
              endnote_ids,
              comment_ids,
            )
          }
        }
      @docmodel.DocxBlock::ContentControl(control) => {
        collect_docx_refs(
          control.blocks,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
        collect_docx_inline_refs(
          control.inlines,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
      }
      @docmodel.DocxBlock::TablePlaceholder(_)
      | @docmodel.DocxBlock::StructuralMarker(_)
      | @docmodel.DocxBlock::Unsupported(_) => ()
    }
  }
}

///|
fn collect_docx_inline_refs(
  inlines : Array[@docmodel.DocxInline],
  footnote_ids : Array[String],
  endnote_ids : Array[String],
  comment_ids : Array[String],
) -> Unit {
  for inline in inlines {
    match inline {
      @docmodel.DocxInline::FootnoteRef(id) =>
        push_docx_unique_id(footnote_ids, id)
      @docmodel.DocxInline::EndnoteRef(id) =>
        push_docx_unique_id(endnote_ids, id)
      @docmodel.DocxInline::CommentRef(id) =>
        push_docx_unique_id(comment_ids, id)
      @docmodel.DocxInline::Drawing(drawing) =>
        collect_docx_inline_refs(
          drawing.child_inlines,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
      @docmodel.DocxInline::Shape(shape) =>
        collect_docx_inline_refs(
          shape.child_inlines,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
      @docmodel.DocxInline::ContentControl(control) => {
        collect_docx_refs(
          control.blocks,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
        collect_docx_inline_refs(
          control.inlines,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
      }
      @docmodel.DocxInline::FieldUnsupported(field) =>
        collect_docx_inline_refs(
          field.child_inlines,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
      @docmodel.DocxInline::Math(math) =>
        collect_docx_inline_refs(
          math.child_inlines,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
      @docmodel.DocxInline::TrackedChange(change) =>
        collect_docx_inline_refs(
          change.child_inlines,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
      @docmodel.DocxInline::SmartTag(smart_tag) =>
        collect_docx_inline_refs(
          smart_tag.child_inlines,
          footnote_ids,
          endnote_ids,
          comment_ids,
        )
      @docmodel.DocxInline::StructuralMarker(_) => ()
      _ => ()
    }
  }
}

///|
fn push_docx_unique_id(ids : Array[String], id : String) -> Unit {
  for existing in ids {
    if existing == id {
      return
    }
  }
  ids.push(id)
}

///|
fn docx_body_comment_labels(
  docx : @docmodel.DocxDocument,
) -> Map[String, String] {
  let footnote_ids : Array[String] = []
  let endnote_ids : Array[String] = []
  let comment_ids : Array[String] = []
  collect_docx_refs(docx.body, footnote_ids, endnote_ids, comment_ids)
  let labels : Map[String, String] = Map([])
  let mut display_index = 1
  for id in comment_ids {
    match @docmodel.docx_find_comment(docx, id) {
      Some(_) => {
        labels.set(id, display_index.to_string())
        display_index += 1
      }
      None => ()
    }
  }
  labels
}

///|
fn append_docx_note_definitions(
  doc : @cor.Document,
  docx : @docmodel.DocxDocument,
  footnote_ids : Array[String],
  endnote_ids : Array[String],
  asset_ctx : DocxAssetExportCtx?,
) -> Unit {
  for id in footnote_ids {
    match @docmodel.docx_find_footnote(docx, id) {
      Some(note) =>
        append_docx_note_definition(
          doc,
          docx,
          note.source_key,
          note.blocks,
          id,
          id,
          @cor.NoteKind::Footnote,
          @cor.NoteSourceKind::DocxFootnoteBody,
          asset_ctx,
        )
      None => ()
    }
  }
  for id in endnote_ids {
    match @docmodel.docx_find_endnote(docx, id) {
      Some(note) =>
        append_docx_note_definition(
          doc,
          docx,
          note.source_key,
          note.blocks,
          "e" + id,
          "e" + id,
          @cor.NoteKind::Endnote,
          @cor.NoteSourceKind::DocxEndnoteBody,
          asset_ctx,
        )
      None => ()
    }
  }
}

///|
fn append_docx_note_definition(
  doc : @cor.Document,
  docx : @docmodel.DocxDocument,
  source_key : @docmodel.DocxSourceKey,
  blocks : Array[@docmodel.DocxBlock],
  note_id : String,
  marker : String,
  kind : @cor.NoteKind,
  source_kind : @cor.NoteSourceKind,
  asset_ctx : DocxAssetExportCtx?,
) -> Unit {
  let body_doc = @cor.new_document()
  push_docx_blocks(body_doc, docx, blocks, asset_ctx)
  copy_docx_asset_origins(doc, body_doc)
  @cor.push_note_definition(doc, {
    note_id,
    marker,
    kind,
    blocks: body_doc.blocks.val,
    placement: @cor.NotePlacement::DocumentEnd,
    source_kind,
    body_status: @cor.NoteBodyStatus::Resolved,
    origin: Some(
      docx_source_origin_for_index(
        source_key,
        doc.note_definitions.val.length(),
      ),
    ),
  })
}

///|
fn copy_docx_asset_origins(
  target : @cor.Document,
  source : @cor.Document,
) -> Unit {
  for entry in source.asset_origins.val {
    let (path, origin) = entry
    @cor.set_asset_origin(target, path, origin)
  }
}

///|
fn append_docx_comments(
  doc : @cor.Document,
  docx : @docmodel.DocxDocument,
  ids : Array[String],
  asset_ctx : DocxAssetExportCtx?,
) -> Unit {
  let mut section_started = false
  for id in ids {
    match @docmodel.docx_find_comment(docx, id) {
      Some(comment) => {
        if !section_started {
          push_docx_block_with_origin(
            doc,
            @cor.Block::Heading(2, "Comments"),
            Some(comment.source_key),
          )
          section_started = true
        }
        push_docx_comment_blocks(
          doc,
          docx,
          comment.blocks,
          docx_comment_author_prefix(comment.author),
          asset_ctx,
        )
      }
      None => ()
    }
  }
}

///|
fn append_docx_part_bodies(
  doc : @cor.Document,
  docx : @docmodel.DocxDocument,
  bodies : Array[@docmodel.DocxPartBody],
  section_title : String,
  item_title : String,
  asset_ctx : DocxAssetExportCtx?,
) -> Unit {
  let mut section_started = false
  let mut display_index = 1
  for body in bodies {
    if !docx_part_body_has_visible_content(docx, body) {
      continue
    }
    if !section_started {
      push_docx_block_with_origin(
        doc,
        @cor.Block::Heading(2, section_title),
        None,
      )
      section_started = true
    }
    let origin = docx_part_body_origin_for_index(body, doc.blocks.val.length())
    @cor.push_with_origin(
      doc,
      @cor.Block::Heading(
        3,
        item_title +
        " " +
        display_index.to_string() +
        " " +
        docx_part_body_slot_label(body.relationship_id),
      ),
      Some(origin),
    )
    push_docx_part_body_blocks(doc, docx, body, asset_ctx)
    display_index += 1
  }
}

///|
fn docx_part_body_has_visible_content(
  docx : @docmodel.DocxDocument,
  body : @docmodel.DocxPartBody,
) -> Bool {
  if docx_blocks_have_visible_content(body.blocks) {
    return true
  }
  for textbox in docx.textboxes {
    if textbox.owner_part == body.part_name &&
      docx_blocks_have_visible_content(textbox.blocks) {
      return true
    }
  }
  false
}

///|
fn push_docx_part_body_blocks(
  doc : @cor.Document,
  docx : @docmodel.DocxDocument,
  body : @docmodel.DocxPartBody,
  asset_ctx : DocxAssetExportCtx?,
) -> Unit {
  let body_doc = @cor.new_document()
  push_docx_blocks(body_doc, docx, body.blocks, asset_ctx)
  push_docx_owner_textboxes(body_doc, docx, body.part_name, asset_ctx)
  copy_docx_asset_origins(doc, body_doc)
  for block in body_doc.blocks.val {
    let origin = docx_part_body_origin_for_index(body, doc.blocks.val.length())
    @cor.push_with_origin(doc, block, Some(origin))
  }
}

///|
fn push_docx_owner_textboxes(
  doc : @cor.Document,
  docx : @docmodel.DocxDocument,
  owner_part : String,
  asset_ctx : DocxAssetExportCtx?,
) -> Unit {
  for textbox in docx.textboxes {
    if textbox.owner_part == owner_part &&
      docx_blocks_have_visible_content(textbox.blocks) {
      push_docx_blocks(doc, docx, textbox.blocks, asset_ctx)
    }
  }
}

///|
fn docx_part_body_origin_for_index(
  body : @docmodel.DocxPartBody,
  block_index : Int,
) -> @cor.Origin {
  let origin = docx_source_origin_for_index(body.source_key, block_index)
  {
    ..origin,
    object_ref: Some(body.part_name),
    relationship_id: body.relationship_id,
  }
}

///|
fn docx_part_body_slot_label(rel_id : String?) -> String {
  match rel_id {
    Some(value) => {
      let normalized = docx_normalize_style_label(value)
      if normalized.contains("even") {
        "Even"
      } else if normalized.contains("first") {
        "First"
      } else {
        "Default"
      }
    }
    None => "Default"
  }
}

///|
fn push_docx_comment_blocks(
  doc : @cor.Document,
  docx : @docmodel.DocxDocument,
  blocks : Array[@docmodel.DocxBlock],
  prefix : String,
  asset_ctx : DocxAssetExportCtx?,
) -> Unit {
  if blocks.length() == 0 {
    if prefix.trim() != "" {
      push_docx_block_with_origin(
        doc,
        @cor.Block::ListItem(true, 0, prefix.trim().to_owned()),
        None,
      )
    }
    return
  }
  let mut first_visible_done = false
  for block in blocks {
    if first_visible_done {
      push_docx_block(doc, docx, block, asset_ctx)
      continue
    }
    match block {
      @docmodel.DocxBlock::Paragraph(p) => {
        let text = render_docx_paragraph_text(p.inlines)
        if text.trim() == "" {
          continue
        }
        push_docx_block_with_origin(
          doc,
          @cor.Block::ListItem(true, 0, prefix + text),
          Some(p.source_key),
        )
        first_visible_done = true
      }
      @docmodel.DocxBlock::StructuralMarker(_) => ()
      _ => {
        if prefix.trim() != "" {
          push_docx_block_with_origin(
            doc,
            @cor.Block::ListItem(true, 0, prefix.trim().to_owned()),
            docx_block_source_key(block),
          )
        }
        push_docx_block(doc, docx, block, asset_ctx)
        first_visible_done = true
      }
    }
  }
  if !first_visible_done && prefix.trim() != "" {
    push_docx_block_with_origin(
      doc,
      @cor.Block::ListItem(true, 0, prefix.trim().to_owned()),
      None,
    )
  }
}

///|
fn append_docx_textboxes(
  doc : @cor.Document,
  docx : @docmodel.DocxDocument,
  asset_ctx : DocxAssetExportCtx?,
) -> Unit {
  let mut display_index = 1
  let mut section_started = false
  for textbox in docx.textboxes {
    if !docx_blocks_have_visible_content(textbox.blocks) {
      continue
    }
    if !section_started {
      push_docx_block_with_origin(
        doc,
        @cor.Block::Heading(2, "Text Boxes"),
        None,
      )
      section_started = true
    }
    let origin = docx_textbox_origin_for_index(textbox, doc.blocks.val.length())
    @cor.push_with_origin(
      doc,
      @cor.Block::Heading(
        3,
        docx_textbox_appendix_title(textbox, display_index),
      ),
      Some(origin),
    )
    push_docx_textbox_blocks(doc, docx, textbox, asset_ctx)
    display_index += 1
  }
}

///|
fn push_docx_textbox_blocks(
  doc : @cor.Document,
  docx : @docmodel.DocxDocument,
  textbox : @docmodel.DocxTextBox,
  asset_ctx : DocxAssetExportCtx?,
) -> Unit {
  let body_doc = @cor.new_document()
  push_docx_blocks(body_doc, docx, textbox.blocks, asset_ctx)
  copy_docx_asset_origins(doc, body_doc)
  for block in body_doc.blocks.val {
    let origin = docx_textbox_origin_for_index(textbox, doc.blocks.val.length())
    @cor.push_with_origin(doc, block, Some(origin))
  }
}

///|
fn docx_textbox_origin_for_index(
  textbox : @docmodel.DocxTextBox,
  block_index : Int,
) -> @cor.Origin {
  let origin = docx_source_origin_for_index(textbox.source_key, block_index)
  {
    ..origin,
    object_ref: Some(docx_textbox_object_ref(textbox)),
    relationship_id: textbox.relationship_id,
  }
}

///|
fn docx_textbox_object_ref(textbox : @docmodel.DocxTextBox) -> String {
  let suffix = docx_textbox_index_suffix(textbox.anchor_id)
  match suffix {
    Some(value) => textbox.owner_part + "#textbox-" + (value + 1).to_string()
    None => textbox.anchor_id
  }
}

///|
fn docx_textbox_index_suffix(anchor_id : String) -> Int? {
  let parts = anchor_id.split("#textbox:").to_array()
  if parts.length() < 2 {
    return None
  }
  docx_parse_nonnegative_int(parts[parts.length() - 1].to_owned())
}

///|
fn docx_textbox_appendix_title(
  textbox : @docmodel.DocxTextBox,
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
fn docx_blocks_have_visible_content(
  blocks : Array[@docmodel.DocxBlock],
) -> Bool {
  for block in blocks {
    match block {
      @docmodel.DocxBlock::Paragraph(p) =>
        if render_docx_paragraph_text(p.inlines).trim() != "" {
          return true
        }
      @docmodel.DocxBlock::Table(table) =>
        if docx_table_rows(table, None).length() > 0 {
          return true
        }
      @docmodel.DocxBlock::ContentControl(control) =>
        if docx_content_control_has_visible_content(control) {
          return true
        }
      @docmodel.DocxBlock::TablePlaceholder(_)
      | @docmodel.DocxBlock::Unsupported(_) => return true
      @docmodel.DocxBlock::StructuralMarker(_) => ()
    }
  }
  false
}

///|
fn docx_content_control_has_visible_content(
  control : @docmodel.DocxContentControl,
) -> Bool {
  if control.text.trim() != "" {
    return true
  }
  if control.blocks.length() > 0 {
    return docx_blocks_have_visible_content(control.blocks)
  }
  render_docx_paragraph_text(control.inlines).trim() != ""
}

///|
fn docx_comment_author_prefix(author : String?) -> String {
  match author {
    Some(value) => {
      let trimmed = value.trim().to_owned()
      if trimmed == "" {
        ""
      } else {
        trimmed + ": "
      }
    }
    None => ""
  }
}

///|
fn push_docx_blocks(
  doc : @cor.Document,
  docx : @docmodel.DocxDocument,
  blocks : Array[@docmodel.DocxBlock],
  asset_ctx : DocxAssetExportCtx?,
) -> Unit {
  push_docx_blocks_with_comment_labels(doc, docx, blocks, asset_ctx, None)
}

///|
fn push_docx_blocks_with_comment_labels(
  doc : @cor.Document,
  docx : @docmodel.DocxDocument,
  blocks : Array[@docmodel.DocxBlock],
  asset_ctx : DocxAssetExportCtx?,
  comment_labels : Map[String, String]?,
) -> Unit {
  for block in blocks {
    push_docx_block_with_comment_labels(
      doc, docx, block, asset_ctx, comment_labels,
    )
  }
}

///|
fn push_docx_paragraph_block(
  doc : @cor.Document,
  docx : @docmodel.DocxDocument,
  p : @docmodel.DocxParagraph,
  asset_ctx : DocxAssetExportCtx?,
  comment_labels : Map[String, String]?,
) -> Unit {
  match lower_docx_mixed_paragraph_images(doc, p, asset_ctx) {
    true => return
    false => ()
  }
  let text = render_docx_paragraph_text_with_comment_labels(
    p.inlines,
    comment_labels,
  )
  let rich = docx_paragraph_has_rich_inline(p.inlines)
  let rich_inlines = if rich {
    docx_core_inlines_with_comment_labels(p.inlines, comment_labels)
  } else {
    []
  }
  if text.trim() == "" && rich_inlines.length() == 0 {
    return
  }

  match docx_paragraph_heading_level(docx, p) {
    Some(level) => {
      if rich_inlines.length() > 0 {
        push_docx_paragraph_origin(
          doc,
          p,
          @cor.Block::RichHeading(level, rich_inlines),
        )
      } else {
        push_docx_paragraph_origin(doc, p, @cor.Block::Heading(level, text))
      }
      return
    }
    None => ()
  }

  match docx_paragraph_list_lowering(docx, p) {
    Some((ordered, level)) => {
      if rich_inlines.length() > 0 {
        push_docx_paragraph_origin(
          doc,
          p,
          @cor.Block::RichListItem(ordered, level, rich_inlines),
        )
      } else {
        push_docx_paragraph_origin(
          doc,
          p,
          @cor.Block::ListItem(ordered, level, text),
        )
      }
      return
    }
    None => ()
  }

  if docx_paragraph_is_code_style(docx, p) {
    if text.trim() != "" {
      push_docx_paragraph_origin(doc, p, @cor.Block::CodeBlock(text))
    }
    return
  }

  if docx_paragraph_is_quote_style(docx, p) {
    if rich_inlines.length() > 0 {
      push_docx_paragraph_origin(
        doc,
        p,
        @cor.Block::RichBlockQuote(rich_inlines),
      )
    } else if text.trim() != "" {
      push_docx_paragraph_origin(doc, p, @cor.Block::BlockQuote(text))
    }
    return
  }

  if rich_inlines.length() > 0 {
    push_docx_paragraph_origin(doc, p, @cor.Block::RichParagraph(rich_inlines))
  } else if text.trim() != "" {
    push_docx_paragraph_origin(doc, p, @cor.Block::Paragraph(text))
  }
}

///|
fn lower_docx_mixed_paragraph_images(
  doc : @cor.Document,
  p : @docmodel.DocxParagraph,
  asset_ctx : DocxAssetExportCtx?,
) -> Bool {
  if asset_ctx is None {
    return false
  }
  let buf : Array[@docmodel.DocxInline] = []
  let mut emitted_image = false
  for inline in p.inlines {
    match inline {
      @docmodel.DocxInline::Media(media) =>
        match export_docx_media(asset_ctx, media) {
          Some(asset) => {
            push_docx_inline_chunk(doc, buf, Some(p.source_key))
            buf.clear()
            push_docx_image_block(doc, media, asset)
            emitted_image = true
          }
          None => buf.push(inline)
        }
      @docmodel.DocxInline::Drawing(drawing) =>
        match docx_drawing_media(drawing) {
          Some(media) =>
            match export_docx_media(asset_ctx, media) {
              Some(asset) => {
                push_docx_inline_chunk(doc, buf, Some(p.source_key))
                buf.clear()
                push_docx_image_block(doc, media, asset)
                emitted_image = true
              }
              None => buf.push(inline)
            }
          None => buf.push(inline)
        }
      @docmodel.DocxInline::Shape(shape) =>
        match docx_shape_media(shape) {
          Some(media) =>
            match export_docx_media(asset_ctx, media) {
              Some(asset) => {
                push_docx_inline_chunk(doc, buf, Some(p.source_key))
                buf.clear()
                push_docx_image_block(doc, media, asset)
                emitted_image = true
              }
              None => buf.push(inline)
            }
          None => buf.push(inline)
        }
      _ => buf.push(inline)
    }
  }
  if emitted_image {
    push_docx_inline_chunk(doc, buf, Some(p.source_key))
  }
  emitted_image
}

///|
fn push_docx_inline_chunk(
  doc : @cor.Document,
  inlines : Array[@docmodel.DocxInline],
  source_key : @docmodel.DocxSourceKey?,
) -> Unit {
  push_docx_inline_chunk_with_comment_labels(doc, inlines, source_key, None)
}

///|
fn push_docx_inline_chunk_with_comment_labels(
  doc : @cor.Document,
  inlines : Array[@docmodel.DocxInline],
  source_key : @docmodel.DocxSourceKey?,
  comment_labels : Map[String, String]?,
) -> Unit {
  let text = render_docx_paragraph_text_with_comment_labels(
    inlines, comment_labels,
  )
  let rich = docx_paragraph_has_rich_inline(inlines)
  let rich_inlines = if rich {
    docx_core_inlines_with_comment_labels(inlines, comment_labels)
  } else {
    []
  }
  if rich_inlines.length() > 0 {
    push_docx_block_with_origin(
      doc,
      @cor.Block::RichParagraph(rich_inlines),
      source_key,
    )
  } else if text.trim() != "" {
    push_docx_block_with_origin(doc, @cor.Block::Paragraph(text), source_key)
  }
}

///|
fn push_docx_image_block(
  doc : @cor.Document,
  media : @docmodel.DocxMediaRef,
  asset : DocxExportedAsset,
) -> Unit {
  let origin = docx_media_origin(media)
  @cor.push_with_origin(
    doc,
    @cor.Block::ImageBlock({
      path: asset.path,
      alt_text: docx_image_alt_text(media),
      title: normalize_docx_optional_text(media.title),
      caption: None,
      origin: Some(origin),
    }),
    Some(origin),
  )
  @cor.set_asset_origin(doc, asset.path, {
    source_name: Some(media.source_key.part_name),
    page: None,
    slide: None,
    sheet: None,
    origin_id: Some(asset.origin_id),
    nearby_caption: None,
    object_ref: Some(media.source_key.node_key),
    relationship_id: media.relationship_id,
    source_path: media.target_part,
    row_index: None,
    column_index: None,
    key_path: Some(
      "$.docx.part[" +
      media.source_key.part_name +
      "].block[" +
      media.source_key.block_index.to_string() +
      "].media[" +
      asset.source_part +
      "]",
    ),
  })
}

///|
fn push_docx_paragraph_origin(
  doc : @cor.Document,
  p : @docmodel.DocxParagraph,
  block : @cor.Block,
) -> Unit {
  push_docx_block_with_origin(doc, block, Some(p.source_key))
}

///|
fn push_docx_block_with_origin(
  doc : @cor.Document,
  block : @cor.Block,
  source_key : @docmodel.DocxSourceKey?,
) -> Unit {
  @cor.push_with_origin(
    doc,
    block,
    source_key.map(fn(key) {
      docx_source_origin_for_index(key, doc.blocks.val.length())
    }),
  )
}

///|
fn docx_block_source_key(
  block : @docmodel.DocxBlock,
) -> @docmodel.DocxSourceKey? {
  match block {
    @docmodel.DocxBlock::Paragraph(p) => Some(p.source_key)
    @docmodel.DocxBlock::Table(table) => Some(table.source_key)
    @docmodel.DocxBlock::TablePlaceholder(placeholder) =>
      Some(placeholder.source_key)
    @docmodel.DocxBlock::ContentControl(control) => Some(control.source_key)
    @docmodel.DocxBlock::StructuralMarker(marker) => Some(marker.source_key)
    @docmodel.DocxBlock::Unsupported(warning) => warning.source_key
  }
}

///|
fn docx_source_origin_for_index(
  key : @docmodel.DocxSourceKey,
  block_index : Int,
) -> @cor.Origin {
  {
    source_name: Some(key.part_name),
    page: None,
    slide: None,
    sheet: None,
    block_index: Some(block_index),
    heading_path: None,
    line_start: None,
    line_end: None,
    row_index: None,
    column_index: None,
    object_ref: Some(key.node_key),
    relationship_id: None,
    key_path: Some(
      "$.docx.part[" +
      key.part_name +
      "].block[" +
      key.block_index.to_string() +
      "].node[" +
      key.node_key +
      "]",
    ),
  }
}

///|
fn normalize_docx_product_origins(
  doc : @cor.Document,
  source_name : String,
) -> @cor.Document {
  let normalized = @cor.new_document()
  for i in 0..<doc.blocks.val.length() {
    let origin = match doc.block_origins.val[i] {
      Some(existing) => docx_product_block_origin(existing, source_name, i)
      None => docx_default_product_origin(source_name, i)
    }
    @cor.push_with_origin(
      normalized,
      docx_product_block_origin_payload(doc.blocks.val[i], origin),
      Some(origin),
    )
  }
  for entry in doc.asset_origins.val {
    let (path, origin) = entry
    @cor.set_asset_origin(normalized, path, {
      ..origin,
      source_name: Some(source_name),
      object_ref: None,
      key_path: None,
    })
  }
  for note in doc.note_definitions.val {
    @cor.push_note_definition(normalized, note)
  }
  normalized
}

///|
fn docx_product_block_origin(
  origin : @cor.Origin,
  source_name : String,
  block_index : Int,
) -> @cor.Origin {
  {
    source_name: Some(source_name),
    page: origin.page,
    slide: origin.slide,
    sheet: origin.sheet,
    block_index: Some(block_index),
    heading_path: origin.heading_path,
    line_start: origin.line_start,
    line_end: origin.line_end,
    row_index: origin.row_index,
    column_index: origin.column_index,
    object_ref: docx_product_object_ref(origin.object_ref),
    relationship_id: if docx_product_object_ref(origin.object_ref) is Some(_) {
      origin.relationship_id
    } else {
      None
    },
    key_path: None,
  }
}

///|
fn docx_product_object_ref(object_ref : String?) -> String? {
  match object_ref {
    Some(value) =>
      if value.has_prefix("word/header") || value.has_prefix("word/footer") {
        object_ref
      } else {
        None
      }
    None => None
  }
}

///|
fn docx_default_product_origin(
  source_name : String,
  block_index : Int,
) -> @cor.Origin {
  {
    source_name: Some(source_name),
    page: None,
    slide: None,
    sheet: None,
    block_index: Some(block_index),
    heading_path: None,
    line_start: None,
    line_end: None,
    row_index: None,
    column_index: None,
    object_ref: None,
    relationship_id: None,
    key_path: None,
  }
}

///|
fn docx_product_block_origin_payload(
  block : @cor.Block,
  origin : @cor.Origin,
) -> @cor.Block {
  match block {
    @cor.Block::ImageBlock(img) =>
      @cor.Block::ImageBlock({ ..img, origin: Some(origin) })
    _ => block
  }
}

///|
fn docx_asset_exists(ctx : DocxAssetExportCtx, path : String) -> Bool {
  for asset in ctx.assets {
    if asset.path == path {
      return true
    }
  }
  false
}

///|
fn export_docx_media(
  asset_ctx : DocxAssetExportCtx?,
  media : @docmodel.DocxMediaRef,
) -> DocxExportedAsset? {
  let ctx = match asset_ctx {
    Some(value) => value
    None => return None
  }
  if ctx.out_dir.trim() == "" {
    return None
  }
  if media.relationship_kind == @docmodel.DocxMediaRelationshipKind::Link ||
    media.target_mode == Some(@docmodel.DocxTargetMode::External) {
    return None
  }
  if media.target_exists != Some(true) {
    return None
  }
  let source_part = match media.target_part {
    Some(value) => if value.trim() == "" { return None } else { value }
    None => return None
  }
  match ctx.by_source_part.get(source_part) {
    Some(existing_path) =>
      return Some({
        path: existing_path,
        source_part,
        content_type: media.content_type,
        relationship_id: media.relationship_id,
        alt_text: docx_image_alt_text(media),
        title: media.title,
        origin_id: docx_asset_origin_id(existing_path),
      })
    None => ()
  }
  let ext = docx_media_asset_ext(media)
  if ext == "" {
    return None
  }
  let data = @ox.read_part_bytes(ctx.pkg, source_part) catch {
    _ => return None
  }
  let rel_path = @cor.next_image_asset_rel_path_unique(
    ctx.next_idx,
    ext,
    ctx.out_dir,
  )
  @fs.write_bytes_to_file(ctx.out_dir + "/" + rel_path, data) catch {
    _ => return None
  }
  let asset = {
    path: rel_path,
    source_part,
    content_type: media.content_type,
    relationship_id: media.relationship_id,
    alt_text: docx_image_alt_text(media),
    title: media.title,
    origin_id: docx_asset_origin_id(rel_path),
  }
  ctx.by_source_part.set(source_part, rel_path)
  if !docx_asset_exists(ctx, rel_path) {
    ctx.assets.push(asset)
  }
  Some(asset)
}

///|
fn docx_media_asset_ext(media : @docmodel.DocxMediaRef) -> String {
  match media.content_type {
    Some(content_type) => {
      let ct = content_type.trim().to_lower()
      if ct == "image/png" {
        return "png"
      } else if ct == "image/jpeg" || ct == "image/jpg" {
        return "jpg"
      } else if ct == "image/gif" {
        return "gif"
      } else if ct == "image/bmp" {
        return "bmp"
      } else if ct == "image/tiff" || ct == "image/tif" {
        return "tiff"
      } else if ct == "image/webp" {
        return "webp"
      }
    }
    None => ()
  }
  match media.target_part {
    Some(value) => docx_image_ext_from_path(value)
    None =>
      match media.resolved_target {
        Some(value) => docx_image_ext_from_path(value)
        None => ""
      }
  }
}

///|
fn docx_image_ext_from_path(path : String) -> String {
  let p = path.trim().to_lower()
  if p.has_suffix(".png") {
    "png"
  } else if p.has_suffix(".jpg") || p.has_suffix(".jpeg") {
    "jpg"
  } else if p.has_suffix(".gif") {
    "gif"
  } else if p.has_suffix(".bmp") {
    "bmp"
  } else if p.has_suffix(".tif") || p.has_suffix(".tiff") {
    "tiff"
  } else if p.has_suffix(".webp") {
    "webp"
  } else {
    ""
  }
}

///|
fn normalize_docx_optional_text(value : String?) -> String? {
  match value {
    Some(text) => {
      let trimmed = text.trim().to_owned()
      if trimmed == "" {
        None
      } else {
        Some(trimmed)
      }
    }
    None => None
  }
}

///|
fn docx_image_alt_text(media : @docmodel.DocxMediaRef) -> String? {
  match normalize_docx_optional_text(media.alt_text) {
    Some(value) => Some(value)
    None => Some("image")
  }
}

///|
fn docx_asset_origin_id(path : String) -> String {
  let base = @cor.basename(path)
  if base.has_prefix("image") {
    let chars = base.to_array()
    let digits : Array[Char] = []
    let mut i = 5
    while i < chars.length() {
      let ch = chars[i]
      if ch >= '0' && ch <= '9' {
        digits.push(ch)
        i += 1
      } else {
        break
      }
    }
    match docx_parse_nonnegative_int(String::from_array(digits)) {
      Some(value) => if value > 0 { return "docx-asset-" + value.to_string() }
      None => ()
    }
  }
  "docx-asset-" + path
}

///|
fn docx_media_origin(media : @docmodel.DocxMediaRef) -> @cor.Origin {
  {
    source_name: Some(media.source_key.part_name),
    page: None,
    slide: None,
    sheet: None,
    block_index: Some(media.source_key.block_index),
    heading_path: None,
    line_start: None,
    line_end: None,
    row_index: None,
    column_index: None,
    object_ref: Some(media.source_key.node_key),
    relationship_id: media.relationship_id,
    key_path: Some(
      "$.docx.part[" +
      media.source_key.part_name +
      "].block[" +
      media.source_key.block_index.to_string() +
      "].media[" +
      media.source_key.node_key +
      "]",
    ),
  }
}

///|
fn docx_paragraph_heading_level(
  docx : @docmodel.DocxDocument,
  p : @docmodel.DocxParagraph,
) -> Int? {
  match @docmodel.docx_resolve_paragraph_style(docx, p) {
    Some(style) => docx_style_heading_level(style)
    None => None
  }
}

///|
fn docx_style_heading_level(style : @docmodel.DocxStyle) -> Int? {
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
  docx : @docmodel.DocxDocument,
  p : @docmodel.DocxParagraph,
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
  docx : @docmodel.DocxDocument,
  p : @docmodel.DocxParagraph,
) -> @docmodel.DocxNumberingLevel? {
  match @docmodel.docx_resolve_paragraph_numbering_level(docx, p) {
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
  level : @docmodel.DocxNumberingLevel,
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
  docx : @docmodel.DocxDocument,
  p : @docmodel.DocxParagraph,
) -> Bool {
  match @docmodel.docx_resolve_paragraph_style(docx, p) {
    Some(style) =>
      docx_style_label_matches(style, [
        "code", "pre", "preformatted", "htmlpreformatted", "sourcecode",
      ])
    None => false
  }
}

///|
fn docx_paragraph_is_quote_style(
  docx : @docmodel.DocxDocument,
  p : @docmodel.DocxParagraph,
) -> Bool {
  match @docmodel.docx_resolve_paragraph_style(docx, p) {
    Some(style) =>
      docx_style_label_matches(style, [
        "quote", "intensequote", "blockquote", "blockquotetext",
      ])
    None => false
  }
}

///|
fn docx_style_label_matches(
  style : @docmodel.DocxStyle,
  labels : Array[String],
) -> Bool {
  let style_id = docx_normalize_style_label(style.style_id)
  for label in labels {
    if style_id == label {
      return true
    }
  }
  match style.name {
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
fn docx_normalize_style_label(label : String) -> String {
  let out : Array[Char] = []
  for ch in label.trim().to_array() {
    if ch >= 'A' && ch <= 'Z' {
      out.push(Int::unsafe_to_char(ch.to_int() + ('a'.to_int() - 'A'.to_int())))
    } else if (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') {
      out.push(ch)
    }
  }
  String::from_array(out)
}

///|
fn docx_parse_nonnegative_int(value : String) -> Int? {
  let chars = value.trim().to_array()
  if chars.length() == 0 {
    return None
  }
  let mut out = 0
  for ch in chars {
    if ch < '0' || ch > '9' {
      return None
    }
    out = out * 10 + (ch.to_int() - '0'.to_int())
  }
  Some(out)
}

///|
pub fn render_docx_plain_text(docx : @docmodel.DocxDocument) -> String {
  let parts : Array[String] = []
  for block in docx.body {
    match block {
      @docmodel.DocxBlock::Paragraph(p) => {
        let text = render_docx_paragraph_text(p.inlines)
        if text.trim() != "" {
          parts.push(text)
        }
      }
      @docmodel.DocxBlock::Table(table) => {
        let rows = docx_table_rows(table, None)
        if rows.length() > 0 {
          let rendered_rows : Array[String] = []
          for row in rows {
            rendered_rows.push(row.join("\t"))
          }
          parts.push(rendered_rows.join("\n"))
        }
      }
      @docmodel.DocxBlock::TablePlaceholder(_) =>
        parts.push("[Unsupported DOCX table omitted by v2 skeleton]")
      @docmodel.DocxBlock::ContentControl(control) => {
        let text = render_docx_content_control_text(control, None)
        if text.trim() != "" {
          parts.push(text)
        }
      }
      @docmodel.DocxBlock::StructuralMarker(_) => ()
      @docmodel.DocxBlock::Unsupported(warning) =>
        parts.push("[Unsupported DOCX node: " + warning.message + "]")
    }
  }
  parts.join("\n\n")
}

///|
fn docx_table_rows(
  table : @docmodel.DocxTable,
  asset_ctx : DocxAssetExportCtx?,
) -> Array[Array[String]] {
  let rows : Array[Array[String]] = []
  for row in table.rows {
    let cells : Array[String] = []
    for cell in row.cells {
      cells.push(docx_table_cell_text(cell, asset_ctx))
    }
    rows.push(cells)
  }
  rows
}

///|
fn docx_table_header_rows(table : @docmodel.DocxTable) -> Int {
  if table.rows.length() > 0 &&
    (table.rows[0].is_header || docx_table_first_row_inferred_header(table)) {
    1
  } else {
    0
  }
}

///|
fn docx_table_first_row_inferred_header(table : @docmodel.DocxTable) -> Bool {
  if table.rows.length() < 2 {
    return false
  }
  let row = table.rows[0]
  if row.cells.length() == 0 {
    return false
  }
  let mut has_text = false
  for cell in row.cells {
    let text = cell.text.trim()
    if text == "" ||
      text.contains("\n") ||
      text.contains("\t") ||
      text.to_array().length() > 80 {
      return false
    }
    if !docx_table_cell_has_header_style_hint(cell) {
      return false
    }
    has_text = true
  }
  has_text
}

///|
fn docx_table_cell_has_header_style_hint(
  cell : @docmodel.DocxTableCell,
) -> Bool {
  for block in cell.blocks {
    match block {
      @docmodel.DocxBlock::Paragraph(p) =>
        if p.text.trim() != "" &&
          docx_paragraph_alignment_is_center(p) &&
          docx_paragraph_visible_runs_are_bold(p) {
          return true
        }
      @docmodel.DocxBlock::ContentControl(control) =>
        if docx_content_control_header_style_hint(control) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn docx_content_control_header_style_hint(
  control : @docmodel.DocxContentControl,
) -> Bool {
  for block in control.blocks {
    match block {
      @docmodel.DocxBlock::Paragraph(p) =>
        if p.text.trim() != "" &&
          docx_paragraph_alignment_is_center(p) &&
          docx_paragraph_visible_runs_are_bold(p) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn docx_paragraph_alignment_is_center(p : @docmodel.DocxParagraph) -> Bool {
  match p.alignment {
    Some(value) => docx_normalize_style_label(value) == "center"
    None => false
  }
}

///|
fn docx_paragraph_visible_runs_are_bold(p : @docmodel.DocxParagraph) -> Bool {
  let mut saw_visible_run = false
  for run in p.runs {
    if render_docx_paragraph_text(run.inlines).trim() != "" {
      if !run.bold {
        return false
      }
      saw_visible_run = true
    }
  }
  saw_visible_run
}

///|
fn render_docx_table_text(
  table : @docmodel.DocxTable,
  asset_ctx : DocxAssetExportCtx?,
) -> String {
  let rows = docx_table_rows(table, asset_ctx)
  let rendered_rows : Array[String] = []
  for row in rows {
    rendered_rows.push(row.join("\t"))
  }
  rendered_rows.join("\n")
}

///|
fn render_docx_content_control_text(
  control : @docmodel.DocxContentControl,
  asset_ctx : DocxAssetExportCtx?,
) -> String {
  if control.blocks.length() > 0 {
    let parts : Array[String] = []
    for block in control.blocks {
      match block {
        @docmodel.DocxBlock::Paragraph(p) => {
          let text = render_docx_table_paragraph_text(p.inlines, asset_ctx)
          if text.trim() != "" {
            parts.push(text)
          }
        }
        @docmodel.DocxBlock::Table(table) => {
          let text = render_docx_table_text(table, asset_ctx)
          if text.trim() != "" {
            parts.push(text)
          }
        }
        @docmodel.DocxBlock::TablePlaceholder(_) =>
          parts.push("[Unsupported DOCX nested table depth limit]")
        @docmodel.DocxBlock::ContentControl(child) => {
          let text = render_docx_content_control_text(child, asset_ctx)
          if text.trim() != "" {
            parts.push(text)
          }
        }
        @docmodel.DocxBlock::StructuralMarker(_) => ()
        @docmodel.DocxBlock::Unsupported(warning) =>
          parts.push("[Unsupported DOCX node: " + warning.message + "]")
      }
    }
    return parts.join("\n")
  }
  if control.inlines.length() > 0 {
    render_docx_table_paragraph_text(control.inlines, asset_ctx)
  } else {
    control.text
  }
}

///|
fn docx_table_cell_text(
  cell : @docmodel.DocxTableCell,
  asset_ctx : DocxAssetExportCtx?,
) -> String {
  let parts : Array[String] = []
  for block in cell.blocks {
    match block {
      @docmodel.DocxBlock::Paragraph(p) => {
        let text = render_docx_table_paragraph_text(p.inlines, asset_ctx)
        if text.trim() != "" {
          parts.push(text)
        }
      }
      @docmodel.DocxBlock::Table(table) => {
        let text = render_docx_table_text(table, asset_ctx)
        if text.trim() != "" {
          parts.push(text)
        }
      }
      @docmodel.DocxBlock::TablePlaceholder(_) =>
        parts.push("[Unsupported DOCX nested table depth limit]")
      @docmodel.DocxBlock::ContentControl(control) => {
        let text = render_docx_content_control_text(control, asset_ctx)
        if text.trim() != "" {
          parts.push(text)
        }
      }
      @docmodel.DocxBlock::StructuralMarker(_) => ()
      @docmodel.DocxBlock::Unsupported(warning) =>
        parts.push("[Unsupported DOCX node: " + warning.message + "]")
    }
  }
  if parts.length() == 0 {
    cell.text
  } else {
    parts.join("\n")
  }
}

///|
fn render_docx_table_paragraph_text(
  inlines : Array[@docmodel.DocxInline],
  asset_ctx : DocxAssetExportCtx?,
) -> String {
  let out = StringBuilder::new()
  for inline in inlines {
    match inline {
      @docmodel.DocxInline::Text(text) => out.write_string(text)
      @docmodel.DocxInline::Tab => out.write_string("\t")
      @docmodel.DocxInline::LineBreak => out.write_string("\n")
      @docmodel.DocxInline::Break(value) =>
        out.write_string(render_docx_break_text(value))
      @docmodel.DocxInline::Hyperlink(link) =>
        match link.target {
          Some(target) =>
            if target.trim() != "" {
              out.write_string(
                "[" + escape_docx_link_text(link.text) + "](" + target + ")",
              )
            } else {
              out.write_string(link.text)
            }
          None => out.write_string(link.text)
        }
      @docmodel.DocxInline::Media(media) =>
        out.write_string(render_docx_media_text(media, asset_ctx))
      @docmodel.DocxInline::TextBoxRef(_) => ()
      @docmodel.DocxInline::Drawing(drawing) =>
        out.write_string(render_docx_drawing_text(drawing, asset_ctx))
      @docmodel.DocxInline::Shape(shape) =>
        out.write_string(render_docx_shape_text(shape, asset_ctx))
      @docmodel.DocxInline::ContentControl(control) =>
        out.write_string(render_docx_content_control_text(control, asset_ctx))
      @docmodel.DocxInline::FieldUnsupported(field) =>
        out.write_string(render_docx_field_text(field))
      @docmodel.DocxInline::Math(math) =>
        out.write_string(render_docx_math_text(math))
      @docmodel.DocxInline::TrackedChange(change) =>
        out.write_string(render_docx_tracked_change_text(change))
      @docmodel.DocxInline::SmartTag(smart_tag) =>
        out.write_string(
          render_docx_table_paragraph_text(smart_tag.child_inlines, asset_ctx),
        )
      @docmodel.DocxInline::Symbol(symbol) =>
        out.write_string(render_docx_symbol_text(symbol))
      @docmodel.DocxInline::Hyphen(hyphen) =>
        out.write_string(render_docx_hyphen_text(hyphen))
      @docmodel.DocxInline::FootnoteRef(id) =>
        out.write_string(docx_footnote_marker(id))
      @docmodel.DocxInline::EndnoteRef(id) =>
        out.write_string(docx_endnote_marker(id))
      @docmodel.DocxInline::CommentRef(id) =>
        out.write_string(" " + docx_comment_marker(id))
      @docmodel.DocxInline::StructuralMarker(_) => ()
      @docmodel.DocxInline::Bookmark(_) => ()
      @docmodel.DocxInline::UnsupportedInline(_) =>
        out.write_string("[unsupported DOCX inline]")
      @docmodel.DocxInline::Unsupported(_) => ()
    }
  }
  out.to_string()
}

///|
fn escape_docx_link_text(text : String) -> String {
  text
  .replace(old="[", new="\\[")
  .replace(old="]", new="\\]")
  .replace(old="(", new="\\(")
  .replace(old=")", new="\\)")
}

///|
fn docx_footnote_marker(id : String) -> String {
  "[^" + id + "]"
}

///|
fn docx_endnote_marker(id : String) -> String {
  "[^e" + id + "]"
}

///|
fn docx_comment_marker(id : String) -> String {
  "[comment " + id + "]"
}

///|
fn docx_comment_marker_with_labels(
  id : String,
  comment_labels : Map[String, String]?,
) -> String {
  match comment_labels {
    Some(labels) =>
      match labels.get(id) {
        Some(label) => docx_comment_marker(label)
        None => docx_comment_marker(id)
      }
    None => docx_comment_marker(id)
  }
}

///|
fn docx_paragraph_has_rich_inline(
  inlines : Array[@docmodel.DocxInline],
) -> Bool {
  for inline in inlines {
    match inline {
      @docmodel.DocxInline::Hyperlink(link) =>
        match link.target {
          Some(target) => if target.trim() != "" { return true }
          None => ()
        }
      @docmodel.DocxInline::ContentControl(control) =>
        if docx_blocks_have_rich_inline(control.blocks) ||
          docx_paragraph_has_rich_inline(control.inlines) {
          return true
        }
      @docmodel.DocxInline::SmartTag(smart_tag) =>
        if docx_paragraph_has_rich_inline(smart_tag.child_inlines) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn docx_blocks_have_rich_inline(blocks : Array[@docmodel.DocxBlock]) -> Bool {
  for block in blocks {
    match block {
      @docmodel.DocxBlock::Paragraph(p) =>
        if docx_paragraph_has_rich_inline(p.inlines) {
          return true
        }
      @docmodel.DocxBlock::Table(table) =>
        for row in table.rows {
          for cell in row.cells {
            if docx_blocks_have_rich_inline(cell.blocks) {
              return true
            }
          }
        }
      @docmodel.DocxBlock::ContentControl(control) =>
        if docx_blocks_have_rich_inline(control.blocks) ||
          docx_paragraph_has_rich_inline(control.inlines) {
          return true
        }
      @docmodel.DocxBlock::TablePlaceholder(_)
      | @docmodel.DocxBlock::StructuralMarker(_)
      | @docmodel.DocxBlock::Unsupported(_) => ()
    }
  }
  false
}

///|
fn docx_core_inlines_with_comment_labels(
  inlines : Array[@docmodel.DocxInline],
  comment_labels : Map[String, String]?,
) -> Array[@cor.Inline] {
  let out : Array[@cor.Inline] = []
  for inline in inlines {
    match inline {
      @docmodel.DocxInline::Text(text) => out.push(@cor.Inline::Text(text))
      @docmodel.DocxInline::Tab => out.push(@cor.Inline::Text("\t"))
      @docmodel.DocxInline::LineBreak => out.push(@cor.Inline::Break)
      @docmodel.DocxInline::Break(value) => {
        let text = render_docx_break_text(value)
        if text == "\n" {
          out.push(@cor.Inline::Break)
        } else if text != "" {
          out.push(@cor.Inline::Text(text))
        }
      }
      @docmodel.DocxInline::Hyperlink(link) =>
        match link.target {
          Some(target) =>
            if target.trim() != "" {
              out.push(@cor.Inline::Link(link.text, target))
            } else if link.text != "" {
              out.push(@cor.Inline::Text(link.text))
            }
          None => if link.text != "" { out.push(@cor.Inline::Text(link.text)) }
        }
      @docmodel.DocxInline::TrackedChange(change) => {
        let text = render_docx_tracked_change_text(change)
        if text != "" {
          out.push(@cor.Inline::Text(text))
        }
      }
      @docmodel.DocxInline::Media(media) =>
        out.push(@cor.Inline::Text(render_docx_media_placeholder(media)))
      @docmodel.DocxInline::TextBoxRef(_) => ()
      @docmodel.DocxInline::Drawing(drawing) =>
        match docx_drawing_media(drawing) {
          Some(media) =>
            out.push(@cor.Inline::Text(render_docx_media_placeholder(media)))
          None => ()
        }
      @docmodel.DocxInline::Shape(shape) =>
        match docx_shape_media(shape) {
          Some(media) =>
            out.push(@cor.Inline::Text(render_docx_media_placeholder(media)))
          None =>
            docx_push_inline_text_as_core(
              out,
              render_docx_child_inline_text(shape.child_inlines),
            )
        }
      @docmodel.DocxInline::ContentControl(control) =>
        docx_push_inline_text_as_core(
          out,
          render_docx_content_control_text(control, None),
        )
      @docmodel.DocxInline::FieldUnsupported(field) => {
        let text = render_docx_field_text(field)
        if text != "" {
          out.push(@cor.Inline::Text(text))
        }
      }
      @docmodel.DocxInline::Math(math) =>
        out.push(@cor.Inline::Text(render_docx_math_text(math)))
      @docmodel.DocxInline::Symbol(symbol) =>
        out.push(@cor.Inline::Text(render_docx_symbol_text(symbol)))
      @docmodel.DocxInline::Hyphen(hyphen) => {
        let text = render_docx_hyphen_text(hyphen)
        if text != "" {
          out.push(@cor.Inline::Text(text))
        }
      }
      @docmodel.DocxInline::FootnoteRef(id) =>
        out.push(@cor.Inline::Text(docx_footnote_marker(id)))
      @docmodel.DocxInline::EndnoteRef(id) =>
        out.push(@cor.Inline::Text(docx_endnote_marker(id)))
      @docmodel.DocxInline::CommentRef(id) =>
        out.push(
          @cor.Inline::Text(
            " " + docx_comment_marker_with_labels(id, comment_labels),
          ),
        )
      @docmodel.DocxInline::SmartTag(smart_tag) =>
        docx_push_inline_text_as_core(
          out,
          render_docx_child_inline_text(smart_tag.child_inlines),
        )
      @docmodel.DocxInline::StructuralMarker(_) => ()
      @docmodel.DocxInline::Bookmark(_) => ()
      @docmodel.DocxInline::UnsupportedInline(_) =>
        out.push(@cor.Inline::Text("[unsupported DOCX inline]"))
      @docmodel.DocxInline::Unsupported(_) => ()
    }
  }
  out
}

///|
fn docx_push_inline_text_as_core(
  out : Array[@cor.Inline],
  text : String,
) -> Unit {
  if text != "" {
    out.push(@cor.Inline::Text(text))
  }
}

///|
fn render_docx_paragraph_text(inlines : Array[@docmodel.DocxInline]) -> String {
  render_docx_paragraph_text_with_comment_labels(inlines, None)
}

///|
fn render_docx_paragraph_text_with_comment_labels(
  inlines : Array[@docmodel.DocxInline],
  comment_labels : Map[String, String]?,
) -> String {
  let out = StringBuilder::new()
  for inline in inlines {
    match inline {
      @docmodel.DocxInline::Text(text) => out.write_string(text)
      @docmodel.DocxInline::Tab => out.write_string("\t")
      @docmodel.DocxInline::LineBreak => out.write_string("\n")
      @docmodel.DocxInline::Break(value) =>
        out.write_string(render_docx_break_text(value))
      @docmodel.DocxInline::Hyperlink(link) => out.write_string(link.text)
      @docmodel.DocxInline::Media(media) =>
        out.write_string(render_docx_media_placeholder(media))
      @docmodel.DocxInline::TextBoxRef(_) => ()
      @docmodel.DocxInline::Drawing(drawing) =>
        out.write_string(render_docx_drawing_placeholder(drawing))
      @docmodel.DocxInline::Shape(shape) =>
        out.write_string(render_docx_shape_placeholder(shape))
      @docmodel.DocxInline::ContentControl(control) =>
        out.write_string(render_docx_content_control_text(control, None))
      @docmodel.DocxInline::FieldUnsupported(field) =>
        out.write_string(render_docx_field_text(field))
      @docmodel.DocxInline::Math(math) =>
        out.write_string(render_docx_math_text(math))
      @docmodel.DocxInline::TrackedChange(change) =>
        out.write_string(render_docx_tracked_change_text(change))
      @docmodel.DocxInline::SmartTag(smart_tag) =>
        out.write_string(render_docx_child_inline_text(smart_tag.child_inlines))
      @docmodel.DocxInline::Symbol(symbol) =>
        out.write_string(render_docx_symbol_text(symbol))
      @docmodel.DocxInline::Hyphen(hyphen) =>
        out.write_string(render_docx_hyphen_text(hyphen))
      @docmodel.DocxInline::FootnoteRef(id) =>
        out.write_string(docx_footnote_marker(id))
      @docmodel.DocxInline::EndnoteRef(id) =>
        out.write_string(docx_endnote_marker(id))
      @docmodel.DocxInline::CommentRef(id) =>
        out.write_string(
          " " + docx_comment_marker_with_labels(id, comment_labels),
        )
      @docmodel.DocxInline::StructuralMarker(_) => ()
      @docmodel.DocxInline::Bookmark(_) => ()
      @docmodel.DocxInline::UnsupportedInline(_) =>
        out.write_string("[unsupported DOCX inline]")
      @docmodel.DocxInline::Unsupported(_) => ()
    }
  }
  out.to_string()
}

///|
fn render_docx_field_text(field : @docmodel.DocxField) -> String {
  match field.result_text {
    Some(value) => if value.trim() != "" { return value }
    None => ()
  }
  if field.child_inlines.length() > 0 {
    let child_text = render_docx_child_inline_text(field.child_inlines)
    if child_text.trim() != "" {
      return child_text
    }
  }
  match field.instruction {
    Some(value) =>
      if value.trim() != "" {
        return "[field: " + value.trim().to_owned() + "]"
      }
    None => ()
  }
  match field.field_char_type {
    Some(value) =>
      if value.trim() != "" {
        return "[field: " + field.kind + ":" + value + "]"
      }
    None => ()
  }
  "[field: " + field.kind + "]"
}

///|
fn render_docx_math_text(math : @docmodel.DocxMath) -> String {
  if math.child_inlines.length() > 0 {
    let child_text = render_docx_child_inline_text(math.child_inlines)
    if child_text.trim() != "" {
      return "[math: " + child_text + "]"
    }
  }
  match math.text_signature {
    Some(value) => if value.trim() != "" { return "[math: " + value + "]" }
    None => ()
  }
  "[math]"
}

///|
fn render_docx_break_text(value : @docmodel.DocxBreak) -> String {
  match value.kind {
    @docmodel.DocxBreakKind::Page => "[break: page]"
    @docmodel.DocxBreakKind::Column => "[break: column]"
    @docmodel.DocxBreakKind::Unknown =>
      match value.break_type {
        Some(kind) => "[break: " + kind + "]"
        None => "[break]"
      }
    @docmodel.DocxBreakKind::Line
    | @docmodel.DocxBreakKind::TextWrapping
    | @docmodel.DocxBreakKind::CarriageReturn => "\n"
  }
}

///|
fn render_docx_tracked_change_text(
  change : @docmodel.DocxTrackedChange,
) -> String {
  if change.kind == "w:ins" || change.kind == "w:moveTo" {
    if change.child_inlines.length() > 0 {
      let child_text = render_docx_child_inline_text(change.child_inlines)
      if child_text.trim() != "" {
        return child_text
      }
    }
    change.text
  } else if change.kind == "w:del" || change.kind == "w:moveFrom" {
    ""
  } else {
    change.text
  }
}

///|
fn render_docx_symbol_text(symbol : @docmodel.DocxSymbol) -> String {
  match symbol.char_hex {
    Some(value) => render_docx_symbol_hex(value)
    None => "[symbol]"
  }
}

///|
fn render_docx_symbol_hex(value : String) -> String {
  match parse_docx_hex_codepoint(value) {
    Some(codepoint) =>
      if codepoint >= 0x20 && codepoint <= 0x7E {
        String::from_array([Int::unsafe_to_char(codepoint)])
      } else {
        "[symbol: " + value + "]"
      }
    None => "[symbol: " + value + "]"
  }
}

///|
fn parse_docx_hex_codepoint(value : String) -> Int? {
  let chars = value.trim().to_array()
  if chars.length() == 0 {
    return None
  }
  let mut out = 0
  for ch in chars {
    match docx_hex_value(ch) {
      Some(v) => out = (out << 4) + v
      None => return None
    }
  }
  Some(out)
}

///|
fn docx_hex_value(ch : Char) -> Int? {
  if ch >= '0' && ch <= '9' {
    Some(ch.to_int() - '0'.to_int())
  } else if ch >= 'A' && ch <= 'F' {
    Some(ch.to_int() - 'A'.to_int() + 10)
  } else if ch >= 'a' && ch <= 'f' {
    Some(ch.to_int() - 'a'.to_int() + 10)
  } else {
    None
  }
}

///|
fn render_docx_hyphen_text(hyphen : @docmodel.DocxHyphen) -> String {
  match hyphen.kind {
    @docmodel.DocxHyphenKind::Soft => ""
    @docmodel.DocxHyphenKind::NoBreak => "-"
  }
}

///|
fn render_docx_media_placeholder(media : @docmodel.DocxMediaRef) -> String {
  match media.alt_text {
    Some(value) => if value.trim() != "" { return "[image: " + value + "]" }
    None => ()
  }
  match media.title {
    Some(value) => if value.trim() != "" { return "[image: " + value + "]" }
    None => ()
  }
  match media.target_part {
    Some(value) => if value.trim() != "" { return "[image: " + value + "]" }
    None => ()
  }
  match media.resolved_target {
    Some(value) => if value.trim() != "" { return "[image: " + value + "]" }
    None => ()
  }
  match media.relationship_id {
    Some(value) => if value.trim() != "" { return "[image: " + value + "]" }
    None => ()
  }
  "[image]"
}

///|
fn docx_drawing_media(
  drawing : @docmodel.DocxDrawing,
) -> @docmodel.DocxMediaRef? {
  drawing.media
}

///|
fn docx_shape_media(shape : @docmodel.DocxShape) -> @docmodel.DocxMediaRef? {
  shape.media
}

///|
fn render_docx_drawing_placeholder(drawing : @docmodel.DocxDrawing) -> String {
  match docx_drawing_media(drawing) {
    Some(media) => render_docx_media_placeholder(media)
    None => render_docx_child_inline_text(drawing.child_inlines)
  }
}

///|
fn render_docx_shape_placeholder(shape : @docmodel.DocxShape) -> String {
  match docx_shape_media(shape) {
    Some(media) => render_docx_media_placeholder(media)
    None => render_docx_child_inline_text(shape.child_inlines)
  }
}

///|
fn render_docx_child_inline_text(
  inlines : Array[@docmodel.DocxInline],
) -> String {
  let text = render_docx_paragraph_text(inlines)
  if text.trim() == "" {
    ""
  } else {
    text
  }
}

///|
fn render_docx_drawing_text(
  drawing : @docmodel.DocxDrawing,
  asset_ctx : DocxAssetExportCtx?,
) -> String {
  match docx_drawing_media(drawing) {
    Some(media) => render_docx_media_text(media, asset_ctx)
    None => render_docx_child_inline_text(drawing.child_inlines)
  }
}

///|
fn render_docx_shape_text(
  shape : @docmodel.DocxShape,
  asset_ctx : DocxAssetExportCtx?,
) -> String {
  match docx_shape_media(shape) {
    Some(media) => render_docx_media_text(media, asset_ctx)
    None => render_docx_child_inline_text(shape.child_inlines)
  }
}

///|
fn render_docx_media_text(
  media : @docmodel.DocxMediaRef,
  asset_ctx : DocxAssetExportCtx?,
) -> String {
  ignore(export_docx_media(asset_ctx, media))
  render_docx_media_placeholder(media)
}
