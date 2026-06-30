///|
pub fn parse_docx_document_from_package(
  pkg : @ox.OoxmlPackage,
) -> DocxDocument raise DocxError {
  normalize_docx_source(parse_docx_source_from_package(pkg))
}

///|
pub fn normalize_docx_source(source : DocxSourceDocument) -> DocxDocument {
  let body : Array[DocxBlock] = []
  let warnings : Array[DocxWarning] = []
  let styles = docx_model_styles(source.styles)
  let numbering = docx_model_numbering(source.numbering)
  let textboxes = docx_model_textboxes(source.textboxes, warnings)
  for warning in source.warnings {
    warnings.push(docx_warning_from_source(warning))
  }

  for part in source.parts {
    for warning in part.warnings {
      let converted = docx_warning_from_source(warning)
      if !docx_warning_exists(warnings, converted) {
        warnings.push(converted)
      }
    }
    if part.part_name == source.main_part {
      for block in part.blocks {
        body.push(docx_model_block(block, warnings, textboxes))
      }
    }
  }
  docx_add_unresolved_numbering_warnings(body, numbering, warnings)
  docx_add_unresolved_container_ref_warnings(
    body,
    source.footnotes,
    source.endnotes,
    source.comments,
    warnings,
  )

  {
    main_part: source.main_part,
    metadata: source.metadata,
    part_graph: source.part_graph,
    body,
    styles,
    numbering,
    footnotes: docx_model_notes(source.footnotes, warnings),
    endnotes: docx_model_notes(source.endnotes, warnings),
    comments: docx_model_comments(source.comments, warnings),
    headers: docx_model_part_bodies(source.headers, warnings),
    footers: docx_model_part_bodies(source.footers, warnings),
    textboxes,
    warnings,
  }
}

///|
fn docx_model_styles(source : DocxSourceStyles) -> DocxStyles {
  let styles : Array[DocxStyle] = []
  for style in source.styles {
    styles.push({
      style_id: style.style_id,
      style_type: style.style_type,
      name: style.name,
      based_on: style.based_on,
      paragraph_properties: style.paragraph_properties,
      source_key: style.source_key,
    })
  }
  { part_name: source.part_name, styles }
}

///|
fn docx_model_numbering(source : DocxSourceNumbering) -> DocxNumbering {
  let nums : Array[DocxNumberingNum] = []
  let levels : Array[DocxNumberingLevel] = []
  for num in source.nums {
    nums.push({
      num_id: num.num_id,
      abstract_num_id: num.abstract_num_id,
      start_overrides: num.start_overrides,
      source_key: num.source_key,
    })
  }
  for level in source.levels {
    levels.push({
      abstract_num_id: level.abstract_num_id,
      ilvl: level.ilvl,
      num_fmt: level.num_fmt,
      start: level.start,
      lvl_text: level.lvl_text,
      paragraph_style_id: level.paragraph_style_id,
      style_link: level.style_link,
      num_style_link: level.num_style_link,
      source_key: level.source_key,
    })
  }
  { part_name: source.part_name, nums, levels }
}

///|
fn docx_model_notes(
  source : Array[DocxSourceNote],
  warnings : Array[DocxWarning],
) -> Array[DocxNote] {
  let out : Array[DocxNote] = []
  for note in source {
    out.push({
      kind: note.kind,
      note_id: note.note_id,
      part_name: note.part_name,
      blocks: docx_model_blocks(note.blocks, warnings, []),
      source_key: note.source_key,
    })
  }
  out
}

///|
fn docx_model_comments(
  source : Array[DocxSourceComment],
  warnings : Array[DocxWarning],
) -> Array[DocxComment] {
  let out : Array[DocxComment] = []
  for comment in source {
    out.push({
      comment_id: comment.comment_id,
      author: comment.author,
      date: comment.date,
      part_name: comment.part_name,
      blocks: docx_model_blocks(comment.blocks, warnings, []),
      source_key: comment.source_key,
    })
  }
  out
}

///|
fn docx_model_part_bodies(
  source : Array[DocxSourcePartBody],
  warnings : Array[DocxWarning],
) -> Array[DocxPartBody] {
  let out : Array[DocxPartBody] = []
  for body in source {
    out.push({
      kind: body.kind,
      relationship_id: body.relationship_id,
      slot_type: body.slot_type,
      part_name: body.part_name,
      blocks: docx_model_blocks(body.blocks, warnings, []),
      source_key: body.source_key,
    })
  }
  out
}

///|
fn docx_model_textboxes(
  source : Array[DocxSourceTextBox],
  warnings : Array[DocxWarning],
) -> Array[DocxTextBox] {
  let out : Array[DocxTextBox] = []
  for textbox in source {
    let candidate : DocxTextBox = {
      anchor_id: textbox.anchor_id,
      owner_part: textbox.owner_part,
      relationship_id: textbox.relationship_id,
      part_name: textbox.part_name,
      blocks: docx_model_blocks(textbox.blocks, warnings, []),
      source_key: textbox.source_key,
      shape_id: textbox.shape_id,
      doc_pr_id: textbox.doc_pr_id,
      doc_pr_name: textbox.doc_pr_name,
      descr: textbox.descr,
      title: textbox.title,
    }
    let mut merged = false
    for i in 0..<out.length() {
      if docx_textboxes_are_equivalent(out[i], candidate) {
        out[i] = docx_merge_textboxes(out[i], candidate)
        merged = true
        break
      }
    }
    if !merged {
      out.push(candidate)
    }
  }
  out
}

///|
fn docx_textboxes_are_equivalent(
  left : DocxTextBox,
  right : DocxTextBox,
) -> Bool {
  if left.owner_part != right.owner_part {
    return false
  }
  if left.doc_pr_id is Some(_) &&
    left.doc_pr_id == right.doc_pr_id &&
    docx_textbox_blocks_text_signature(left.blocks) ==
    docx_textbox_blocks_text_signature(right.blocks) {
    return true
  }
  if left.shape_id is Some(_) &&
    left.shape_id == right.shape_id &&
    docx_textbox_blocks_text_signature(left.blocks) ==
    docx_textbox_blocks_text_signature(right.blocks) {
    return true
  }
  if docx_textbox_doc_pr_name_matches_shape_id(left, right) &&
    docx_textbox_blocks_text_signature(left.blocks) ==
    docx_textbox_blocks_text_signature(right.blocks) {
    return true
  }
  if docx_textbox_doc_pr_name_matches_shape_id(right, left) &&
    docx_textbox_blocks_text_signature(left.blocks) ==
    docx_textbox_blocks_text_signature(right.blocks) {
    return true
  }
  if left.source_key.block_index == right.source_key.block_index &&
    docx_textbox_blocks_text_signature(left.blocks) ==
    docx_textbox_blocks_text_signature(right.blocks) {
    let left_has_doc_pr = left.doc_pr_id is Some(_)
    let right_has_doc_pr = right.doc_pr_id is Some(_)
    let left_has_shape = left.shape_id is Some(_)
    let right_has_shape = right.shape_id is Some(_)
    if (left_has_doc_pr && right_has_shape) ||
      (left_has_shape && right_has_doc_pr) {
      return true
    }
  }
  false
}

///|
fn docx_textbox_doc_pr_name_matches_shape_id(
  doc_pr_side : DocxTextBox,
  shape_side : DocxTextBox,
) -> Bool {
  match doc_pr_side.doc_pr_name {
    Some(name) => shape_side.shape_id == Some(name)
    None => false
  }
}

///|
fn docx_merge_textboxes(left : DocxTextBox, right : DocxTextBox) -> DocxTextBox {
  {
    ..left,
    relationship_id: docx_prefer_some_string(
      left.relationship_id,
      right.relationship_id,
    ),
    part_name: if left.part_name.length() <= right.part_name.length() {
      left.part_name
    } else {
      right.part_name
    },
    blocks: if docx_textbox_blocks_text_signature(left.blocks) != "" {
      left.blocks
    } else {
      right.blocks
    },
    source_key: if left.source_key.block_index <= right.source_key.block_index {
      left.source_key
    } else {
      right.source_key
    },
    shape_id: docx_prefer_some_string(left.shape_id, right.shape_id),
    doc_pr_id: docx_prefer_some_string(left.doc_pr_id, right.doc_pr_id),
    doc_pr_name: docx_prefer_some_string(left.doc_pr_name, right.doc_pr_name),
    descr: docx_prefer_some_string(left.descr, right.descr),
    title: docx_prefer_some_string(left.title, right.title),
  }
}

///|
fn docx_prefer_some_string(primary : String?, secondary : String?) -> String? {
  match primary {
    Some(value) => if value.trim() != "" { Some(value) } else { secondary }
    None => secondary
  }
}

///|
fn docx_textbox_blocks_text_signature(blocks : Array[DocxBlock]) -> String {
  let parts : Array[String] = []
  for block in blocks {
    match block {
      DocxBlock::Paragraph(p) => {
        let text = p.text.trim().to_owned()
        if text != "" {
          parts.push(text)
        }
      }
      DocxBlock::ContentControl(control) => {
        let text = control.text.trim().to_owned()
        if text != "" {
          parts.push(text)
        } else {
          let nested = docx_textbox_blocks_text_signature(control.blocks)
          if nested != "" {
            parts.push(nested)
          }
        }
      }
      DocxBlock::Table(table) => {
        let nested = docx_textbox_table_text_signature(table)
        if nested != "" {
          parts.push(nested)
        }
      }
      DocxBlock::TablePlaceholder(_)
      | DocxBlock::StructuralMarker(_)
      | DocxBlock::Unsupported(_) => ()
    }
  }
  parts.join("\n")
}

///|
fn docx_textbox_table_text_signature(table : DocxTable) -> String {
  let parts : Array[String] = []
  for row in table.rows {
    for cell in row.cells {
      let nested = docx_textbox_blocks_text_signature(cell.blocks)
      if nested != "" {
        parts.push(nested)
      }
    }
  }
  parts.join("\n")
}

///|
fn docx_model_blocks(
  source : Array[DocxSourceBlock],
  warnings : Array[DocxWarning],
  textboxes : Array[DocxTextBox],
) -> Array[DocxBlock] {
  let out : Array[DocxBlock] = []
  for block in source {
    out.push(docx_model_block(block, warnings, textboxes))
  }
  out
}

///|
fn docx_model_block(
  block : DocxSourceBlock,
  warnings : Array[DocxWarning],
  textboxes : Array[DocxTextBox],
) -> DocxBlock {
  match block.kind {
    DocxSourceBlockKind::Paragraph =>
      DocxBlock::Paragraph({
        style_id: block.paragraph_style_id,
        alignment: block.paragraph_alignment,
        numbering_ref: block.numbering_ref,
        runs: docx_model_runs(block.runs, warnings, textboxes),
        inlines: docx_model_inlines(
          block.inlines,
          warnings,
          block.source_key,
          textboxes,
        ),
        text: block.text,
        source_key: block.source_key,
      })
    DocxSourceBlockKind::Table =>
      match block.table {
        Some(table) => DocxBlock::Table(docx_model_table(table, warnings))
        None => {
          let warning = {
            kind: DocxWarningKind::UnsupportedTable,
            severity: DocxWarningSeverity::Warning,
            message: "table preserved as placeholder",
            source_key: Some(block.source_key),
          }
          if !docx_warning_at_source_exists(warnings, warning) {
            warnings.push(warning)
          }
          DocxBlock::TablePlaceholder({ source_key: block.source_key })
        }
      }
    DocxSourceBlockKind::ContentControl =>
      match block.content_control {
        Some(control) =>
          DocxBlock::ContentControl(
            docx_model_content_control(control, warnings, textboxes),
          )
        None => {
          let warning = {
            kind: DocxWarningKind::UnknownBodyNode,
            severity: DocxWarningSeverity::Warning,
            message: "content control node missing preserved children",
            source_key: Some(block.source_key),
          }
          if !docx_warning_kind_at_source_exists(warnings, warning) {
            warnings.push(warning)
          }
          DocxBlock::Unsupported(warning)
        }
      }
    DocxSourceBlockKind::Structural =>
      DocxBlock::StructuralMarker({
        kind: block.structural_kind.unwrap_or(
          DocxStructuralKind::UnknownNonVisible,
        ),
        tag: block.raw_tag.unwrap_or(""),
        source_key: block.source_key,
      })
    DocxSourceBlockKind::Unknown => {
      let warning = {
        kind: DocxWarningKind::UnknownBodyNode,
        severity: DocxWarningSeverity::Warning,
        message: "unsupported body node preserved",
        source_key: Some(block.source_key),
      }
      if !docx_warning_kind_at_source_exists(warnings, warning) {
        warnings.push(warning)
      }
      DocxBlock::Unsupported(warning)
    }
  }
}

///|
fn docx_model_table(
  source : DocxSourceTable,
  warnings : Array[DocxWarning],
) -> DocxTable {
  let rows : Array[DocxTableRow] = []
  for row in source.rows {
    let cells : Array[DocxTableCell] = []
    for cell in row.cells {
      let blocks : Array[DocxBlock] = []
      for block in cell.blocks {
        blocks.push(docx_model_block(block, warnings, []))
      }
      cells.push({
        row_index: cell.row_index,
        cell_index: cell.cell_index,
        blocks,
        text: cell.text,
        grid_span: cell.grid_span,
        vertical_merge: cell.vertical_merge,
        has_nested_table: cell.has_nested_table,
        nesting_depth: cell.nesting_depth,
        max_nested_depth: cell.max_nested_depth,
        deep_table_guard_triggered: cell.deep_table_guard_triggered,
        source_key: cell.source_key,
      })
    }
    rows.push({
      row_index: row.row_index,
      is_header: row.is_header,
      cells,
      source_key: row.source_key,
    })
  }
  {
    rows,
    nesting_depth: source.nesting_depth,
    max_nested_depth: source.max_nested_depth,
    deep_table_guard_triggered: source.deep_table_guard_triggered,
    source_key: source.source_key,
  }
}

///|
fn docx_model_content_control(
  source : DocxSourceContentControl,
  warnings : Array[DocxWarning],
  textboxes : Array[DocxTextBox],
) -> DocxContentControl {
  {
    tag: source.tag,
    blocks: docx_model_blocks(source.blocks, warnings, textboxes),
    inlines: docx_model_inlines(
      source.inlines,
      warnings,
      source.source_key,
      textboxes,
    ),
    text: source.text,
    source_key: source.source_key,
  }
}

///|
fn docx_model_runs(
  source : Array[DocxSourceRun],
  warnings : Array[DocxWarning],
  textboxes : Array[DocxTextBox],
) -> Array[DocxRun] {
  let out : Array[DocxRun] = []
  for run in source {
    out.push({
      style_id: run.style_id,
      bold: run.bold,
      inlines: docx_model_inlines(
        run.inlines,
        warnings,
        run.source_key,
        textboxes,
      ),
      source_key: run.source_key,
    })
  }
  out
}

///|
fn docx_model_inlines(
  source : Array[DocxSourceInline],
  warnings : Array[DocxWarning],
  source_key : DocxSourceKey,
  textboxes : Array[DocxTextBox],
) -> Array[DocxInline] {
  let out : Array[DocxInline] = []
  for inline in source {
    match inline {
      DocxSourceInline::Text(text) => out.push(DocxInline::Text(text))
      DocxSourceInline::Tab => out.push(DocxInline::Tab)
      DocxSourceInline::LineBreak => out.push(DocxInline::LineBreak)
      DocxSourceInline::Break(value) =>
        out.push(
          DocxInline::Break({
            kind: value.kind,
            break_type: value.break_type,
            source_key: value.source_key,
          }),
        )
      DocxSourceInline::Hyperlink(link) =>
        out.push(
          DocxInline::Hyperlink({
            relationship_id: link.relationship_id,
            anchor: link.anchor,
            target: link.target,
            text: link.text,
            target_mode: link.target_mode,
            source_key: link.source_key,
          }),
        )
      DocxSourceInline::Media(media) =>
        out.push(DocxInline::Media(docx_model_media_inline(media, warnings)))
      DocxSourceInline::TextBoxRef(textbox_ref) =>
        out.push(
          DocxInline::TextBoxRef({
            anchor_id: docx_resolve_textbox_ref(textbox_ref, textboxes),
            doc_pr_id: textbox_ref.doc_pr_id,
            shape_id: textbox_ref.shape_id,
            owner_part: textbox_ref.owner_part,
            source_key: textbox_ref.source_key,
          }),
        )
      DocxSourceInline::Drawing(drawing) =>
        out.push(
          DocxInline::Drawing({
            anchor_id: drawing.anchor_id,
            owner_part: drawing.owner_part,
            source_key: drawing.source_key,
            doc_pr_id: drawing.doc_pr_id,
            doc_pr_name: drawing.doc_pr_name,
            descr: drawing.descr,
            title: drawing.title,
            media: match drawing.media {
              Some(media) => Some(docx_model_media_inline(media, warnings))
              None => None
            },
            alternate_media: docx_model_media_refs(
              drawing.alternate_media,
              warnings,
            ),
            text_box_ref: match drawing.text_box_ref {
              Some(textbox_ref) =>
                Some({
                  anchor_id: docx_resolve_textbox_ref(textbox_ref, textboxes),
                  doc_pr_id: textbox_ref.doc_pr_id,
                  shape_id: textbox_ref.shape_id,
                  owner_part: textbox_ref.owner_part,
                  source_key: textbox_ref.source_key,
                })
              None => None
            },
            child_inlines: docx_model_inlines(
              drawing.child_inlines,
              warnings,
              drawing.source_key,
              textboxes,
            ),
          }),
        )
      DocxSourceInline::Shape(shape) =>
        out.push(
          DocxInline::Shape({
            anchor_id: shape.anchor_id,
            owner_part: shape.owner_part,
            source_key: shape.source_key,
            shape_id: shape.shape_id,
            shape_type: shape.shape_type,
            style: shape.style,
            alt_text: shape.alt_text,
            title: shape.title,
            media: match shape.media {
              Some(media) => Some(docx_model_media_inline(media, warnings))
              None => None
            },
            text_box_ref: match shape.text_box_ref {
              Some(textbox_ref) =>
                Some({
                  anchor_id: docx_resolve_textbox_ref(textbox_ref, textboxes),
                  doc_pr_id: textbox_ref.doc_pr_id,
                  shape_id: textbox_ref.shape_id,
                  owner_part: textbox_ref.owner_part,
                  source_key: textbox_ref.source_key,
                })
              None => None
            },
            child_inlines: docx_model_inlines(
              shape.child_inlines,
              warnings,
              shape.source_key,
              textboxes,
            ),
          }),
        )
      DocxSourceInline::ContentControl(control) =>
        out.push(
          DocxInline::ContentControl(
            docx_model_content_control(control, warnings, textboxes),
          ),
        )
      DocxSourceInline::FieldUnsupported(field) => {
        let warning = {
          kind: DocxWarningKind::UnsupportedField,
          severity: DocxWarningSeverity::Warning,
          message: "unsupported field inline preserved: " + field.kind,
          source_key: Some(field.source_key),
        }
        if !docx_warning_kind_at_source_exists(warnings, warning) {
          warnings.push(warning)
        }
        out.push(
          DocxInline::FieldUnsupported({
            kind: field.kind,
            instruction: field.instruction,
            field_char_type: field.field_char_type,
            result_text: field.result_text,
            child_inlines: docx_model_inlines(
              field.child_inlines,
              warnings,
              field.source_key,
              textboxes,
            ),
            source_key: field.source_key,
          }),
        )
      }
      DocxSourceInline::Math(math) => {
        let warning = {
          kind: DocxWarningKind::UnsupportedMath,
          severity: DocxWarningSeverity::Warning,
          message: "OMML math preserved without conversion: " + math.kind,
          source_key: Some(math.source_key),
        }
        if !docx_warning_kind_at_source_exists(warnings, warning) {
          warnings.push(warning)
        }
        out.push(
          DocxInline::Math({
            kind: math.kind,
            text_signature: math.text_signature,
            child_inlines: docx_model_inlines(
              math.child_inlines,
              warnings,
              math.source_key,
              textboxes,
            ),
            source_key: math.source_key,
          }),
        )
      }
      DocxSourceInline::Bookmark(bookmark) => {
        let warning = {
          kind: DocxWarningKind::UnsupportedBookmark,
          severity: DocxWarningSeverity::Warning,
          message: "bookmark inline preserved without conversion",
          source_key: Some(bookmark.source_key),
        }
        if !docx_warning_kind_at_source_exists(warnings, warning) {
          warnings.push(warning)
        }
        out.push(
          DocxInline::Bookmark({
            kind: bookmark.kind,
            bookmark_id: bookmark.bookmark_id,
            name: bookmark.name,
            source_key: bookmark.source_key,
          }),
        )
      }
      DocxSourceInline::TrackedChange(change) => {
        let warning = {
          kind: DocxWarningKind::TrackedChange,
          severity: DocxWarningSeverity::Warning,
          message: "tracked change inline preserved without review policy: " +
          change.kind,
          source_key: Some(change.source_key),
        }
        if !docx_warning_kind_at_source_exists(warnings, warning) {
          warnings.push(warning)
        }
        out.push(
          DocxInline::TrackedChange({
            kind: change.kind,
            text: change.text,
            child_inlines: docx_model_inlines(
              change.child_inlines,
              warnings,
              change.source_key,
              textboxes,
            ),
            source_key: change.source_key,
          }),
        )
      }
      DocxSourceInline::SmartTag(smart_tag) =>
        out.push(
          DocxInline::SmartTag({
            tag: smart_tag.tag,
            child_inlines: docx_model_inlines(
              smart_tag.child_inlines,
              warnings,
              smart_tag.source_key,
              textboxes,
            ),
            source_key: smart_tag.source_key,
          }),
        )
      DocxSourceInline::Symbol(symbol) =>
        out.push(
          DocxInline::Symbol({
            font: symbol.font,
            char_hex: symbol.char_hex,
            source_key: symbol.source_key,
          }),
        )
      DocxSourceInline::Hyphen(hyphen) =>
        out.push(
          DocxInline::Hyphen({
            kind: hyphen.kind,
            source_key: hyphen.source_key,
          }),
        )
      DocxSourceInline::FootnoteRef(id) => out.push(DocxInline::FootnoteRef(id))
      DocxSourceInline::EndnoteRef(id) => out.push(DocxInline::EndnoteRef(id))
      DocxSourceInline::CommentRef(id) => out.push(DocxInline::CommentRef(id))
      DocxSourceInline::StructuralMarker(marker) =>
        out.push(
          DocxInline::StructuralMarker({
            kind: marker.kind,
            tag: marker.tag,
            source_key: marker.source_key,
          }),
        )
      DocxSourceInline::UnsupportedInline(inline) => {
        let warning = {
          kind: DocxWarningKind::UnsupportedInline,
          severity: DocxWarningSeverity::Warning,
          message: inline.reason + ": " + inline.tag,
          source_key: Some(inline.source_key),
        }
        if !docx_warning_kind_at_source_exists(warnings, warning) {
          warnings.push(warning)
        }
        out.push(
          DocxInline::UnsupportedInline({
            tag: inline.tag,
            reason: inline.reason,
            source_key: inline.source_key,
          }),
        )
      }
      DocxSourceInline::Unsupported(tag) => {
        let warning = {
          kind: DocxWarningKind::UnsupportedInline,
          severity: DocxWarningSeverity::Warning,
          message: "unsupported inline node preserved: " + tag,
          source_key: Some(source_key),
        }
        if !docx_warning_kind_at_source_exists(warnings, warning) {
          warnings.push(warning)
        }
        out.push(DocxInline::Unsupported(tag))
      }
    }
  }
  out
}

///|
fn docx_model_media_refs(
  media_refs : Array[DocxSourceMediaRef],
  warnings : Array[DocxWarning],
) -> Array[DocxMediaRef] {
  let out : Array[DocxMediaRef] = []
  for media in media_refs {
    out.push(docx_model_media_inline(media, warnings))
  }
  out
}

///|
fn docx_model_media_inline(
  media : DocxSourceMediaRef,
  warnings : Array[DocxWarning],
) -> DocxMediaRef {
  match media.relationship_id {
    Some(_) => ()
    None => {
      let warning = {
        kind: DocxWarningKind::MissingMediaTarget,
        severity: DocxWarningSeverity::Warning,
        message: "media inline has no relationship target",
        source_key: Some(media.source_key),
      }
      if !docx_warning_kind_at_source_exists(warnings, warning) {
        warnings.push(warning)
      }
    }
  }
  if media.target_mode == Some(DocxTargetMode::External) ||
    media.relationship_kind == DocxMediaRelationshipKind::Link {
    let target = media.resolved_target.unwrap_or(media.target.unwrap_or(""))
    let warning = {
      kind: DocxWarningKind::UnsupportedMedia,
      severity: DocxWarningSeverity::Warning,
      message: if target.trim() == "" {
        "external linked media not exported"
      } else {
        "external linked media not exported: " + target
      },
      source_key: Some(media.source_key),
    }
    if !docx_warning_kind_at_source_exists(warnings, warning) {
      warnings.push(warning)
    }
  }
  {
    relationship_id: media.relationship_id,
    relationship_kind: media.relationship_kind,
    container_kind: media.container_kind,
    target: media.target,
    resolved_target: media.resolved_target,
    target_mode: media.target_mode,
    target_part: media.target_part,
    target_exists: media.target_exists,
    content_type: media.content_type,
    alt_text: media.alt_text,
    title: media.title,
    source_key: media.source_key,
  }
}

///|
fn docx_resolve_textbox_ref(
  textbox_ref : DocxSourceTextBoxRef,
  textboxes : Array[DocxTextBox],
) -> String? {
  match textbox_ref.anchor_id {
    Some(value) => return Some(value)
    None => ()
  }
  match textbox_ref.doc_pr_id {
    Some(doc_pr_id) =>
      match
        docx_resolve_textbox_ref_by_doc_pr_id(
          textbox_ref.owner_part,
          doc_pr_id,
          textboxes,
        ) {
        Some(anchor_id) => return Some(anchor_id)
        None => ()
      }
    None => ()
  }
  match textbox_ref.shape_id {
    Some(shape_id) =>
      match
        docx_resolve_textbox_ref_by_shape_id(
          textbox_ref.owner_part,
          shape_id,
          textboxes,
        ) {
        Some(anchor_id) => return Some(anchor_id)
        None => ()
      }
    None => ()
  }
  let mut candidate : String? = None
  for textbox in textboxes {
    if textbox.owner_part != textbox_ref.owner_part {
      continue
    }
    if textbox.source_key.block_index == textbox_ref.source_key.block_index {
      match candidate {
        Some(_) => return None
        None => candidate = Some(textbox.anchor_id)
      }
    }
  }
  candidate
}

///|
fn docx_resolve_textbox_ref_by_doc_pr_id(
  owner_part : String,
  doc_pr_id : String,
  textboxes : Array[DocxTextBox],
) -> String? {
  let mut candidate : String? = None
  for textbox in textboxes {
    if textbox.owner_part != owner_part {
      continue
    }
    if textbox.doc_pr_id != Some(doc_pr_id) {
      continue
    }
    match candidate {
      Some(_) => return None
      None => candidate = Some(textbox.anchor_id)
    }
  }
  candidate
}

///|
fn docx_resolve_textbox_ref_by_shape_id(
  owner_part : String,
  shape_id : String,
  textboxes : Array[DocxTextBox],
) -> String? {
  let mut candidate : String? = None
  for textbox in textboxes {
    if textbox.owner_part != owner_part {
      continue
    }
    if textbox.shape_id != Some(shape_id) {
      continue
    }
    match candidate {
      Some(_) => return None
      None => candidate = Some(textbox.anchor_id)
    }
  }
  candidate
}

///|
fn docx_warning_from_source(warning : DocxSourceWarning) -> DocxWarning {
  {
    kind: match warning.kind {
      DocxSourceWarningKind::MissingMainDocument =>
        DocxWarningKind::MissingMainDocument
      DocxSourceWarningKind::MalformedDocumentXml =>
        DocxWarningKind::MalformedDocumentXml
      DocxSourceWarningKind::MissingHyperlinkTarget =>
        DocxWarningKind::MissingHyperlinkTarget
      DocxSourceWarningKind::MissingMediaTarget =>
        DocxWarningKind::MissingMediaTarget
      DocxSourceWarningKind::MissingMediaPart =>
        DocxWarningKind::MissingMediaPart
      DocxSourceWarningKind::UnsupportedMedia =>
        DocxWarningKind::UnsupportedMedia
      DocxSourceWarningKind::UnsupportedMath => DocxWarningKind::UnsupportedMath
      DocxSourceWarningKind::MissingStylesPart =>
        DocxWarningKind::MissingStylesPart
      DocxSourceWarningKind::MissingNumberingPart =>
        DocxWarningKind::MissingNumberingPart
      DocxSourceWarningKind::MissingContainerPart =>
        DocxWarningKind::MissingContainerPart
      DocxSourceWarningKind::NestedTable => DocxWarningKind::NestedTable
      DocxSourceWarningKind::UnsupportedTextbox =>
        DocxWarningKind::UnsupportedTextbox
      DocxSourceWarningKind::UnknownBodyNode => DocxWarningKind::UnknownBodyNode
      DocxSourceWarningKind::UnsupportedTable =>
        DocxWarningKind::UnsupportedTable
      DocxSourceWarningKind::UnsupportedField =>
        DocxWarningKind::UnsupportedField
      DocxSourceWarningKind::UnsupportedBookmark =>
        DocxWarningKind::UnsupportedBookmark
      DocxSourceWarningKind::TrackedChange => DocxWarningKind::TrackedChange
      DocxSourceWarningKind::UnsupportedInline =>
        DocxWarningKind::UnsupportedInline
      DocxSourceWarningKind::UnresolvedFootnoteRef =>
        DocxWarningKind::UnresolvedFootnoteRef
      DocxSourceWarningKind::UnresolvedEndnoteRef =>
        DocxWarningKind::UnresolvedEndnoteRef
      DocxSourceWarningKind::UnresolvedCommentRef =>
        DocxWarningKind::UnresolvedCommentRef
    },
    severity: DocxWarningSeverity::Warning,
    message: warning.message,
    source_key: warning.source_key,
  }
}

///|
fn docx_add_unresolved_container_ref_warnings(
  blocks : Array[DocxBlock],
  footnotes : Array[DocxSourceNote],
  endnotes : Array[DocxSourceNote],
  comments : Array[DocxSourceComment],
  warnings : Array[DocxWarning],
) -> Unit {
  for block in blocks {
    match block {
      DocxBlock::Paragraph(p) =>
        docx_add_unresolved_inline_ref_warnings(
          p.inlines,
          p.source_key,
          footnotes,
          endnotes,
          comments,
          warnings,
        )
      DocxBlock::Table(table) =>
        for row in table.rows {
          for cell in row.cells {
            docx_add_unresolved_container_ref_warnings(
              cell.blocks,
              footnotes,
              endnotes,
              comments,
              warnings,
            )
          }
        }
      DocxBlock::ContentControl(control) => {
        docx_add_unresolved_container_ref_warnings(
          control.blocks,
          footnotes,
          endnotes,
          comments,
          warnings,
        )
        docx_add_unresolved_inline_ref_warnings(
          control.inlines,
          control.source_key,
          footnotes,
          endnotes,
          comments,
          warnings,
        )
      }
      DocxBlock::TablePlaceholder(_)
      | DocxBlock::StructuralMarker(_)
      | DocxBlock::Unsupported(_) => ()
    }
  }
}

///|
fn docx_add_unresolved_inline_ref_warnings(
  inlines : Array[DocxInline],
  source_key : DocxSourceKey,
  footnotes : Array[DocxSourceNote],
  endnotes : Array[DocxSourceNote],
  comments : Array[DocxSourceComment],
  warnings : Array[DocxWarning],
) -> Unit {
  for inline in inlines {
    match inline {
      DocxInline::FootnoteRef(id) =>
        if !docx_source_note_id_exists(footnotes, id) {
          docx_push_unresolved_ref_warning(
            warnings,
            DocxWarningKind::UnresolvedFootnoteRef,
            "unresolved footnote ref: " + id,
            source_key,
          )
        }
      DocxInline::EndnoteRef(id) =>
        if !docx_source_note_id_exists(endnotes, id) {
          docx_push_unresolved_ref_warning(
            warnings,
            DocxWarningKind::UnresolvedEndnoteRef,
            "unresolved endnote ref: " + id,
            source_key,
          )
        }
      DocxInline::CommentRef(id) =>
        if !docx_source_comment_id_exists(comments, id) {
          docx_push_unresolved_ref_warning(
            warnings,
            DocxWarningKind::UnresolvedCommentRef,
            "unresolved comment ref: " + id,
            source_key,
          )
        }
      DocxInline::ContentControl(control) => {
        docx_add_unresolved_container_ref_warnings(
          control.blocks,
          footnotes,
          endnotes,
          comments,
          warnings,
        )
        docx_add_unresolved_inline_ref_warnings(
          control.inlines,
          control.source_key,
          footnotes,
          endnotes,
          comments,
          warnings,
        )
      }
      DocxInline::SmartTag(smart_tag) =>
        docx_add_unresolved_inline_ref_warnings(
          smart_tag.child_inlines,
          smart_tag.source_key,
          footnotes,
          endnotes,
          comments,
          warnings,
        )
      DocxInline::StructuralMarker(_) => ()
      _ => ()
    }
  }
}

///|
fn docx_push_unresolved_ref_warning(
  warnings : Array[DocxWarning],
  kind : DocxWarningKind,
  message : String,
  source_key : DocxSourceKey,
) -> Unit {
  let warning = {
    kind,
    severity: DocxWarningSeverity::Warning,
    message,
    source_key: Some(source_key),
  }
  if !docx_warning_exists(warnings, warning) {
    warnings.push(warning)
  }
}

///|
fn docx_source_note_id_exists(
  notes : Array[DocxSourceNote],
  note_id : String,
) -> Bool {
  for note in notes {
    if note.note_id == note_id {
      return true
    }
  }
  false
}

///|
fn docx_source_comment_id_exists(
  comments : Array[DocxSourceComment],
  comment_id : String,
) -> Bool {
  for comment in comments {
    if comment.comment_id == comment_id {
      return true
    }
  }
  false
}

///|
fn docx_add_unresolved_numbering_warnings(
  blocks : Array[DocxBlock],
  numbering : DocxNumbering,
  warnings : Array[DocxWarning],
) -> Unit {
  if numbering.part_name is None {
    return
  }
  for block in blocks {
    match block {
      DocxBlock::Paragraph(p) =>
        match p.numbering_ref {
          Some(numbering_ref) =>
            match docx_resolve_numbering_level(numbering, numbering_ref) {
              Some(_) => ()
              None => {
                let ilvl = numbering_ref.ilvl.unwrap_or("0")
                let warning = {
                  kind: DocxWarningKind::MissingNumberingPart,
                  severity: DocxWarningSeverity::Warning,
                  message: "numbering level not resolved: numId=" +
                  numbering_ref.num_id +
                  " ilvl=" +
                  ilvl,
                  source_key: Some(p.source_key),
                }
                if !docx_warning_kind_at_source_exists(warnings, warning) {
                  warnings.push(warning)
                }
              }
            }
          None => ()
        }
      DocxBlock::Table(table) =>
        for row in table.rows {
          for cell in row.cells {
            docx_add_unresolved_numbering_warnings(
              cell.blocks,
              numbering,
              warnings,
            )
          }
        }
      DocxBlock::ContentControl(control) =>
        docx_add_unresolved_numbering_warnings(
          control.blocks,
          numbering,
          warnings,
        )
      DocxBlock::TablePlaceholder(_)
      | DocxBlock::StructuralMarker(_)
      | DocxBlock::Unsupported(_) => ()
    }
  }
}

///|
pub fn docx_find_style(styles : DocxStyles, style_id : String) -> DocxStyle? {
  for style in styles.styles {
    if style.style_id == style_id {
      return Some(style)
    }
  }
  None
}

///|
pub fn docx_resolve_paragraph_style(
  doc : DocxDocument,
  paragraph : DocxParagraph,
) -> DocxStyle? {
  match paragraph.style_id {
    Some(style_id) => docx_find_style(doc.styles, style_id)
    None => None
  }
}

///|
pub fn docx_find_numbering_num(
  numbering : DocxNumbering,
  num_id : String,
) -> DocxNumberingNum? {
  for num in numbering.nums {
    if num.num_id == num_id {
      return Some(num)
    }
  }
  None
}

///|
pub fn docx_resolve_numbering_level(
  numbering : DocxNumbering,
  numbering_ref : DocxNumberingRef,
) -> DocxNumberingLevel? {
  let abstract_num_id = match
    docx_find_numbering_num(numbering, numbering_ref.num_id) {
    Some(num) =>
      match num.abstract_num_id {
        Some(value) => value
        None => return None
      }
    None => return None
  }
  let ilvl = numbering_ref.ilvl.unwrap_or("0")
  for level in numbering.levels {
    if level.abstract_num_id == abstract_num_id && level.ilvl == ilvl {
      return Some(level)
    }
  }
  None
}

///|
pub fn docx_resolve_numbering_level_by_id(
  numbering : DocxNumbering,
  num_id : String,
  ilvl : String?,
) -> DocxNumberingLevel? {
  docx_resolve_numbering_level(numbering, { num_id, ilvl })
}

///|
pub fn docx_resolve_paragraph_numbering_level(
  doc : DocxDocument,
  paragraph : DocxParagraph,
) -> DocxNumberingLevel? {
  match paragraph.numbering_ref {
    Some(numbering_ref) =>
      docx_resolve_numbering_level(doc.numbering, numbering_ref)
    None => None
  }
}

///|
pub fn docx_find_footnote(doc : DocxDocument, note_id : String) -> DocxNote? {
  for note in doc.footnotes {
    if note.note_id == note_id {
      return Some(note)
    }
  }
  None
}

///|
pub fn docx_find_endnote(doc : DocxDocument, note_id : String) -> DocxNote? {
  for note in doc.endnotes {
    if note.note_id == note_id {
      return Some(note)
    }
  }
  None
}

///|
pub fn docx_find_comment(
  doc : DocxDocument,
  comment_id : String,
) -> DocxComment? {
  for comment in doc.comments {
    if comment.comment_id == comment_id {
      return Some(comment)
    }
  }
  None
}

///|
fn docx_warning_exists(
  warnings : Array[DocxWarning],
  candidate : DocxWarning,
) -> Bool {
  for warning in warnings {
    if warning.kind == candidate.kind && warning.message == candidate.message {
      match (warning.source_key, candidate.source_key) {
        (Some(a), Some(b)) => if a.node_key == b.node_key { return true }
        (None, None) => return true
        _ => ()
      }
    }
  }
  false
}

///|
fn docx_warning_kind_at_source_exists(
  warnings : Array[DocxWarning],
  candidate : DocxWarning,
) -> Bool {
  for warning in warnings {
    if warning.kind == candidate.kind {
      match (warning.source_key, candidate.source_key) {
        (Some(a), Some(b)) => if a.node_key == b.node_key { return true }
        (None, None) => return true
        _ => ()
      }
    }
  }
  false
}

///|
fn docx_warning_at_source_exists(
  warnings : Array[DocxWarning],
  candidate : DocxWarning,
) -> Bool {
  for warning in warnings {
    match (warning.source_key, candidate.source_key) {
      (Some(a), Some(b)) => if a.node_key == b.node_key { return true }
      (None, None) => return true
      _ => ()
    }
  }
  false
}
