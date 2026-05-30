///|
fn strip_docx_exact_tag_block(
  xml : String,
  open_tag_chars : Array[Char],
  close_tag_chars : Array[Char],
) -> String {
  let chars = xml.to_array()
  let out = StringBuilder::new()
  let mut i = 0

  while i < chars.length() {
    let start = find_exact_open_tag(chars, i, open_tag_chars)
    if start < 0 {
      out.write_string(profiled_slice_to_string(chars, i, chars.length()))
      break
    }

    out.write_string(profiled_slice_to_string(chars, i, start))
    let close = find_matching_docx_element_close(
      chars, start, open_tag_chars, close_tag_chars,
    )
    if close < 0 {
      break
    }
    i = close + close_tag_chars.length()
  }

  out.to_string()
}

///|
fn strip_docx_exact_single_tag(
  xml : String,
  open_tag_chars : Array[Char],
) -> String {
  let chars = xml.to_array()
  let out = StringBuilder::new()
  let mut i = 0

  while i < chars.length() {
    let start = find_exact_open_tag(chars, i, open_tag_chars)
    if start < 0 {
      out.write_string(profiled_slice_to_string(chars, i, chars.length()))
      break
    }

    out.write_string(profiled_slice_to_string(chars, i, start))
    let close = find_sub(chars, start, ">")
    if close < 0 {
      break
    }
    i = close + 1
  }

  out.to_string()
}

///|
fn strip_docx_deleted_revision_xml(xml : String) -> String {
  let without_deleted = strip_docx_exact_tag_block(
    xml, del_open_tag_chars, del_close_tag_chars,
  )
  let without_move_from = strip_docx_exact_tag_block(
    without_deleted, move_from_open_tag_chars, move_from_close_tag_chars,
  )
  let without_del_text = strip_docx_exact_tag_block(
    without_move_from, del_text_open_tag_chars, del_text_close_tag_chars,
  )
  let without_move_from_start = strip_docx_exact_single_tag(
    without_del_text, move_from_range_start_open_tag_chars,
  )
  let without_move_from_end = strip_docx_exact_single_tag(
    without_move_from_start, move_from_range_end_open_tag_chars,
  )
  let without_move_to_start = strip_docx_exact_single_tag(
    without_move_from_end, move_to_range_start_open_tag_chars,
  )
  strip_docx_exact_single_tag(
    without_move_to_start, move_to_range_end_open_tag_chars,
  )
}

///|
fn strip_docx_text_box_content_xml(xml : String) -> String {
  let chars = xml.to_array()
  let out = StringBuilder::new()
  let mut i = 0

  while i < chars.length() {
    let start = find_exact_open_tag(chars, i, txbx_content_open_tag_chars)
    if start < 0 {
      out.write_string(profiled_slice_to_string(chars, i, chars.length()))
      break
    }

    out.write_string(profiled_slice_to_string(chars, i, start))
    let open_end = find_sub(chars, start, ">")
    if open_end < 0 {
      break
    }
    let close = find_sub(chars, open_end + 1, "</w:txbxContent>")
    if close < 0 {
      i = open_end + 1
      continue
    }
    i = close + txbx_content_close_tag_chars.length()
  }

  out.to_string()
}

///|
fn collect_docx_text_boxes_from_xml(
  xml : String,
  rel_ctx : DocxRelationshipContext,
  asset_by_target : Map[String, String],
  styles : DocxStyles,
  numbering : DocxNumbering,
  context : DocxTextBoxContext,
  source_part : String,
  relationship_id : String?,
) -> Array[DocxTextBox] {
  let chars = xml.to_array()
  let out : Array[DocxTextBox] = []
  let mut i = 0
  let mut textbox_index = 0

  while true {
    let start = find_exact_open_tag(chars, i, txbx_content_open_tag_chars)
    if start < 0 {
      break
    }
    let open_end = find_sub(chars, start, ">")
    if open_end < 0 {
      break
    }
    let close = find_sub(chars, open_end + 1, "</w:txbxContent>")
    if close < 0 {
      break
    }

    let inner = profiled_slice_to_string(chars, open_end + 1, close)
    let blocks = scan_docx_text_box_blocks(
      inner, rel_ctx, asset_by_target, styles, numbering,
    )
    if blocks.length() > 0 {
      textbox_index += 1
      out.push({ context, source_part, relationship_id, textbox_index, blocks })
    }

    i = close + txbx_content_close_tag_chars.length()
  }

  out
}

///|
fn scan_docx_text_box_blocks(
  xml : String,
  rel_ctx : DocxRelationshipContext,
  asset_by_target : Map[String, String],
  styles : DocxStyles,
  numbering : DocxNumbering,
) -> Array[@cor.Block] {
  let doc = scan_document(
    "<w:body>" + xml + "</w:body>",
    rel_ctx,
    asset_by_target,
    styles,
    numbering,
    empty_docx_note_bundle(),
    empty_docx_header_footer_bundle(),
    empty_docx_text_box_bundle(),
    6,
    "",
  )
  doc.blocks.val.filter(fn(block) {
    match block {
      @cor.Block::Heading(_, text) =>
        text != "Footnotes" &&
        text != "Endnotes" &&
        text != "Comments" &&
        text != "Headers" &&
        text != "Footers" &&
        text != "Text Boxes"
      @cor.Block::RichHeading(_, _) => true
      @cor.Block::Paragraph(text) => !@cor.is_blank(text)
      @cor.Block::RichParagraph(inlines) => inlines.length() > 0
      @cor.Block::ListItem(_, _, text) => !@cor.is_blank(text)
      @cor.Block::RichListItem(_, _, inlines) => inlines.length() > 0
      @cor.Block::BlockQuote(text) => !@cor.is_blank(text)
      @cor.Block::CodeBlock(text) => !@cor.is_blank(text)
      @cor.Block::RichTable(table) => table.rows.length() > 0
      @cor.Block::ImageBlock(_) => true
      _ => false
    }
  })
}
