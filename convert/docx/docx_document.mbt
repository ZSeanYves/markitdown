///|
fn scan_document(
  doc_xml : String,
  rel_ctx : DocxRelationshipContext,
  asset_by_target : Map[String, String],
  styles : DocxStyles,
  numbering : DocxNumbering,
  notes : DocxNoteBundle,
  header_footers : DocxHeaderFooterBundle,
  text_boxes : DocxTextBoxBundle,
  max_heading : Int,
  source_name : String,
) -> @cor.Document {
  let doc = @cor.new_document()
  let visible_doc_xml = strip_docx_text_box_content_xml(
    strip_docx_deleted_revision_xml(doc_xml),
  )
  let chars = visible_doc_xml.to_array()
  let mut i = 0
  let mut prev_was_list = false
  let ledger = new_docx_reference_ledger()
  let body_loop_started = @env.now()
  let mut paragraph_scan_elapsed_ms : UInt64 = 0
  let mut table_scan_elapsed_ms : UInt64 = 0
  let mut document_push_elapsed_ms : UInt64 = 0
  let mut paragraph_count = 0
  let mut table_count = 0
  let mut pushed_main_body_blocks = 0
  let mut inserted_list_blank_lines = 0

  while i < chars.length() {
    let p_tbl = find_exact_open_tag(chars, i, wtbl_open_tag_chars)
    let p_p = find_exact_open_tag(chars, i, wp_open_tag_chars)

    if p_tbl >= 0 && (p_p < 0 || p_tbl < p_p) {
      let t2 = find_sub(chars, p_tbl, ">")
      if t2 < 0 {
        break
      }
      let t3 = find_matching_docx_element_close(
        chars, p_tbl, wtbl_open_tag_chars, wtbl_close_tag_chars,
      )
      if t3 < 0 {
        break
      }

      let tbl_xml = profiled_slice_to_string(chars, t2 + 1, t3)
      let table_started = @env.now()
      let rows = scan_table_block_with_context_and_ledger(
        tbl_xml,
        rel_ctx,
        asset_by_target,
        Some(notes),
        Some(ledger),
      )
      table_scan_elapsed_ms = table_scan_elapsed_ms +
        (@env.now() - table_started)
      table_count += 1
      if rows.length() > 0 {
        let push_started = @env.now()
        if prev_was_list {
          @cor.push_with_origin(
            doc,
            @cor.Block::BlankLine,
            Some({
              source_name: Some(source_name),
              page: None,
              slide: None,
              sheet: None,
              block_index: Some(doc.blocks.val.length()),
              heading_path: None,
              line_start: None,
              line_end: None,
              row_index: None,
              column_index: None,
              object_ref: None,
              relationship_id: None,
              key_path: None,
            }),
          )
          inserted_list_blank_lines += 1
        }
        @cor.push_with_origin(
          doc,
          @cor.Block::RichTable({ rows, header_rows: 1, hints: None }),
          Some({
            source_name: Some(source_name),
            page: None,
            slide: None,
            sheet: None,
            block_index: Some(doc.blocks.val.length()),
            heading_path: None,
            line_start: None,
            line_end: None,
            row_index: None,
            column_index: None,
            object_ref: None,
            relationship_id: None,
            key_path: None,
          }),
        )
        document_push_elapsed_ms = document_push_elapsed_ms +
          (@env.now() - push_started)
        pushed_main_body_blocks += 1
        prev_was_list = false
      }

      i = t3 + 8
      continue
    }

    if p_p >= 0 {
      let p2 = find_sub(chars, p_p, ">")
      if p2 < 0 {
        break
      }
      if open_tag_is_self_closing(chars, p_p, p2) {
        i = p2 + 1
        continue
      }
      let p3 = find_matching_docx_element_close(
        chars, p_p, wp_open_tag_chars, wp_close_tag_chars,
      )
      if p3 < 0 {
        break
      }

      profile_paragraph_seen()
      paragraph_count += 1
      let p_xml = profiled_slice_to_string(chars, p2 + 1, p3)
      let paragraph_started = @env.now()
      let blocks = scan_paragraph(
        p_xml,
        rel_ctx,
        asset_by_target,
        styles,
        numbering,
        max_heading,
        Some(notes),
        Some(ledger),
      )
      paragraph_scan_elapsed_ms = paragraph_scan_elapsed_ms +
        (@env.now() - paragraph_started)

      let push_started = @env.now()
      for b in blocks {
        let cur_is_list = match b {
          @cor.Block::ListItem(_, _, _) => true
          _ => false
        }

        if prev_was_list && !cur_is_list {
          @cor.push_with_origin(
            doc,
            @cor.Block::BlankLine,
            Some({
              source_name: Some(source_name),
              page: None,
              slide: None,
              sheet: None,
              block_index: Some(doc.blocks.val.length()),
              heading_path: None,
              line_start: None,
              line_end: None,
              row_index: None,
              column_index: None,
              object_ref: None,
              relationship_id: None,
              key_path: None,
            }),
          )
          inserted_list_blank_lines += 1
        }

        @cor.push_with_origin(
          doc,
          b,
          Some({
            source_name: Some(source_name),
            page: None,
            slide: None,
            sheet: None,
            block_index: Some(doc.blocks.val.length()),
            heading_path: None,
            line_start: None,
            line_end: None,
            row_index: None,
            column_index: None,
            object_ref: None,
            relationship_id: None,
            key_path: None,
          }),
        )
        pushed_main_body_blocks += 1
        prev_was_list = cur_is_list
      }
      document_push_elapsed_ms = document_push_elapsed_ms +
        (@env.now() - push_started)

      i = p3 + 6
      continue
    }

    break
  }

  let body_loop_elapsed_ms = @env.now() - body_loop_started
  let body_xml_scan_elapsed_ms = if body_loop_elapsed_ms >
    paragraph_scan_elapsed_ms + table_scan_elapsed_ms + document_push_elapsed_ms {
    body_loop_elapsed_ms -
    paragraph_scan_elapsed_ms -
    table_scan_elapsed_ms -
    document_push_elapsed_ms
  } else {
    0
  }
  docx_convert_profile_add_active_stage(
    "docx_body_xml_scan",
    body_xml_scan_elapsed_ms,
    Some(
      "split=true paragraphs=" +
      paragraph_count.to_string() +
      " tables=" +
      table_count.to_string() +
      " residual_top_level_traversal=true",
    ),
  )
  docx_convert_profile_add_active_stage(
    "docx_final_block_build",
    document_push_elapsed_ms,
    Some(
      "split=true source=document_push main_body_blocks=" +
      pushed_main_body_blocks.to_string() +
      " list_blank_lines=" +
      inserted_list_blank_lines.to_string(),
    ),
  )

  let appended_started = @env.now()
  append_docx_notes_sections(doc, notes, ledger, source_name)
  let appended_notes_elapsed_ms = @env.now() - appended_started
  let appended_headers_started = @env.now()
  append_docx_header_footer_sections(doc, header_footers, source_name)
  let appended_headers_elapsed_ms = @env.now() - appended_headers_started
  let appended_text_boxes_started = @env.now()
  append_docx_text_box_sections(doc, text_boxes, source_name)
  let appended_text_boxes_elapsed_ms = @env.now() - appended_text_boxes_started
  docx_convert_profile_add_active_stage(
    "docx_appended_sections",
    appended_notes_elapsed_ms +
    appended_headers_elapsed_ms +
    appended_text_boxes_elapsed_ms,
    Some(
      "split=true notes_ms=" +
      appended_notes_elapsed_ms.to_string() +
      " headers_footers_ms=" +
      appended_headers_elapsed_ms.to_string() +
      " text_boxes_ms=" +
      appended_text_boxes_elapsed_ms.to_string(),
    ),
  )
  doc
}

///|
fn append_docx_text_box_sections(
  doc : @cor.Document,
  bundle : DocxTextBoxBundle,
  source_name : String,
) -> Unit {
  if bundle.items.length() == 0 {
    return
  }

  push_docx_append_heading(doc, "Text Boxes", source_name)
  for i in 0..<bundle.items.length() {
    let box = bundle.items[i]
    let label = render_docx_text_box_label(i + 1, box)
    push_docx_append_heading_with_origin(
      doc,
      3,
      label,
      source_name,
      Some(box.source_part + "#textbox-" + box.textbox_index.to_string()),
      box.relationship_id,
    )
    for block in box.blocks {
      push_docx_text_box_block(doc, block, source_name, box)
    }
  }
}

///|
fn render_docx_text_box_label(index : Int, box : DocxTextBox) -> String {
  let prefix = match box.context {
    DocxTextBoxContext::Body => "Text Box "
    DocxTextBoxContext::Header => "Header Text Box "
    DocxTextBoxContext::Footer => "Footer Text Box "
  }
  prefix + index.to_string()
}

///|
fn push_docx_text_box_block(
  doc : @cor.Document,
  block : @cor.Block,
  source_name : String,
  box : DocxTextBox,
) -> Unit {
  @cor.push_with_origin(
    doc,
    block,
    Some({
      source_name: Some(source_name),
      page: None,
      slide: None,
      sheet: None,
      block_index: Some(doc.blocks.val.length()),
      heading_path: None,
      line_start: None,
      line_end: None,
      row_index: None,
      column_index: None,
      object_ref: Some(
        box.source_part + "#textbox-" + box.textbox_index.to_string(),
      ),
      relationship_id: box.relationship_id,
      key_path: None,
    }),
  )
}

///|
fn append_docx_header_footer_sections(
  doc : @cor.Document,
  bundle : DocxHeaderFooterBundle,
  source_name : String,
) -> Unit {
  append_docx_header_footer_kind_sections(
    doc,
    bundle.headers,
    source_name,
    "Headers",
  )
  append_docx_header_footer_kind_sections(
    doc,
    bundle.footers,
    source_name,
    "Footers",
  )
}

///|
fn append_docx_header_footer_kind_sections(
  doc : @cor.Document,
  parts : Array[DocxHeaderFooterPart],
  source_name : String,
  title : String,
) -> Unit {
  let visible_parts = parts.filter(fn(part) {
    !part.is_page_number_only && !@cor.is_blank(part.text)
  })
  if visible_parts.length() == 0 {
    return
  }

  push_docx_append_heading(doc, title, source_name)
  for i in 0..<visible_parts.length() {
    let part = visible_parts[i]
    push_docx_append_part_heading(
      doc,
      render_docx_header_footer_label(i + 1, part),
      source_name,
      part,
    )
    push_docx_append_part_paragraph(doc, part.text, source_name, part)
  }
}

///|
fn render_docx_header_footer_label(
  index : Int,
  part : DocxHeaderFooterPart,
) -> String {
  let kind = match part.kind {
    DocxHeaderFooterKind::Header => "Header"
    DocxHeaderFooterKind::Footer => "Footer"
  }
  let type_suffix = match part.ref_type {
    DocxHeaderFooterRefType::Default => " Default"
    DocxHeaderFooterRefType::First => " First"
    DocxHeaderFooterRefType::Even => " Even"
    DocxHeaderFooterRefType::Unknown => ""
  }
  kind + " " + index.to_string() + type_suffix
}

///|
fn append_docx_notes_sections(
  doc : @cor.Document,
  notes : DocxNoteBundle,
  ledger : DocxReferenceLedger,
  source_name : String,
) -> Unit {
  append_docx_footnotes_section(doc, notes, ledger, source_name)
  append_docx_endnotes_section(doc, notes, ledger, source_name)
  append_docx_comments_section(doc, notes, ledger, source_name)
}

///|
fn append_docx_footnotes_section(
  doc : @cor.Document,
  notes : DocxNoteBundle,
  ledger : DocxReferenceLedger,
  source_name : String,
) -> Unit {
  for i in 0..<ledger.footnote_order.length() {
    let id = ledger.footnote_order[i]
    match notes.footnotes_by_id.get(id) {
      Some(note) => {
        let note_id = (i + 1).to_string()
        let blocks = docx_note_definition_blocks(note.markdown, note.text)
        if blocks.length() > 0 {
          @cor.push_note_definition(doc, {
            note_id,
            marker: note_id,
            kind: @cor.NoteKind::Footnote,
            blocks,
            placement: @cor.NotePlacement::DocumentEnd,
            source_kind: @cor.NoteSourceKind::DocxFootnoteBody,
            body_status: @cor.NoteBodyStatus::Resolved,
            origin: Some(docx_appended_origin(source_name)),
          })
        }
      }
      None => ()
    }
  }
}

///|
fn append_docx_endnotes_section(
  doc : @cor.Document,
  notes : DocxNoteBundle,
  ledger : DocxReferenceLedger,
  source_name : String,
) -> Unit {
  for i in 0..<ledger.endnote_order.length() {
    let id = ledger.endnote_order[i]
    match notes.endnotes_by_id.get(id) {
      Some(note) => {
        let note_id = "e" + (i + 1).to_string()
        let blocks = docx_note_definition_blocks(note.markdown, note.text)
        if blocks.length() > 0 {
          @cor.push_note_definition(doc, {
            note_id,
            marker: note_id,
            kind: @cor.NoteKind::Endnote,
            blocks,
            placement: @cor.NotePlacement::DocumentEnd,
            source_kind: @cor.NoteSourceKind::DocxEndnoteBody,
            body_status: @cor.NoteBodyStatus::Resolved,
            origin: Some(docx_appended_origin(source_name)),
          })
        }
      }
      None => ()
    }
  }
}

///|
fn append_docx_comments_section(
  doc : @cor.Document,
  notes : DocxNoteBundle,
  ledger : DocxReferenceLedger,
  source_name : String,
) -> Unit {
  if ledger.comment_order.length() == 0 {
    return
  }

  push_docx_append_heading(doc, "Comments", source_name)
  for i in 0..<ledger.comment_order.length() {
    let id = ledger.comment_order[i]
    let body = match notes.comments_by_id.get(id) {
      Some(comment) => render_docx_comment_entry(comment)
      None => "[missing comment " + id.to_string() + "]"
    }
    push_docx_append_list_item(doc, i + 1, body, source_name)
  }
}

///|
fn render_docx_comment_entry(comment : DocxComment) -> String {
  let prefix = match comment.author {
    Some(author) => {
      let trimmed = author.trim().to_owned()
      if trimmed == "" {
        ""
      } else {
        trimmed + ": "
      }
    }
    None => ""
  }
  let body = if comment.markdown != "" {
    comment.markdown
  } else {
    comment.text
  }
  prefix + body
}

///|
fn docx_appended_origin(source_name : String) -> @cor.Origin {
  {
    source_name: Some(source_name),
    page: None,
    slide: None,
    sheet: None,
    block_index: None,
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
fn docx_note_definition_blocks(
  markdown : String,
  text : String,
) -> Array[@cor.Block] {
  let body = if markdown.trim() != "" {
    markdown.trim().to_owned()
  } else {
    text.trim().to_owned()
  }
  if body == "" {
    return []
  }

  [@cor.Block::Paragraph(body)]
}

///|
fn push_docx_append_heading(
  doc : @cor.Document,
  text : String,
  source_name : String,
) -> Unit {
  push_docx_append_heading_with_origin(doc, 2, text, source_name, None, None)
}

///|
fn push_docx_append_part_heading(
  doc : @cor.Document,
  text : String,
  source_name : String,
  part : DocxHeaderFooterPart,
) -> Unit {
  push_docx_append_heading_with_origin(
    doc,
    3,
    text,
    source_name,
    Some(part.part_name),
    Some(part.relationship_id),
  )
}

///|
fn push_docx_append_heading_with_origin(
  doc : @cor.Document,
  level : Int,
  text : String,
  source_name : String,
  object_ref : String?,
  relationship_id : String?,
) -> Unit {
  @cor.push_with_origin(
    doc,
    @cor.Block::Heading(level, text),
    Some({
      source_name: Some(source_name),
      page: None,
      slide: None,
      sheet: None,
      block_index: Some(doc.blocks.val.length()),
      heading_path: None,
      line_start: None,
      line_end: None,
      row_index: None,
      column_index: None,
      object_ref,
      relationship_id,
      key_path: None,
    }),
  )
}

///|
fn push_docx_append_part_paragraph(
  doc : @cor.Document,
  text : String,
  source_name : String,
  part : DocxHeaderFooterPart,
) -> Unit {
  push_docx_append_paragraph_with_origin(
    doc,
    text,
    source_name,
    Some(part.part_name),
    Some(part.relationship_id),
  )
}

///|
fn push_docx_append_paragraph_with_origin(
  doc : @cor.Document,
  text : String,
  source_name : String,
  object_ref : String?,
  relationship_id : String?,
) -> Unit {
  @cor.push_with_origin(
    doc,
    @cor.Block::Paragraph(text),
    Some({
      source_name: Some(source_name),
      page: None,
      slide: None,
      sheet: None,
      block_index: Some(doc.blocks.val.length()),
      heading_path: None,
      line_start: None,
      line_end: None,
      row_index: None,
      column_index: None,
      object_ref,
      relationship_id,
      key_path: None,
    }),
  )
}

///|
fn push_docx_append_list_item(
  doc : @cor.Document,
  index : Int,
  text : String,
  source_name : String,
) -> Unit {
  ignore(index)
  @cor.push_with_origin(
    doc,
    @cor.Block::ListItem(true, 0, text),
    Some({
      source_name: Some(source_name),
      page: None,
      slide: None,
      sheet: None,
      block_index: Some(doc.blocks.val.length()),
      heading_path: None,
      line_start: None,
      line_end: None,
      row_index: None,
      column_index: None,
      object_ref: None,
      relationship_id: None,
      key_path: None,
    }),
  )
}
