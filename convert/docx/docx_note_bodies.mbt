///|
fn parse_footnotes_xml(
  xml : String,
  rel_ctx : DocxRelationshipContext,
  asset_by_target : Map[String, String],
  styles : DocxStyles,
  numbering : DocxNumbering,
) -> Map[Int, DocxFootnote] {
  let out : Map[Int, DocxFootnote] = {}
  if xml.trim() == "" {
    return out
  }
  parse_docx_note_entries(xml, "<w:footnote", "</w:footnote>", fn(
    id,
    _open_tag,
    inner,
  ) {
    if is_special_docx_note_id(id) {
      return
    }
    let text = collect_docx_paragraph_texts(inner)
    let markdown = render_docx_note_entry_markdown(
      inner, rel_ctx, asset_by_target, styles, numbering,
    )
    if text != "" || markdown != "" {
      out[id] = { text, markdown }
    }
  })
  out
}

///|
fn parse_endnotes_xml(
  xml : String,
  rel_ctx : DocxRelationshipContext,
  asset_by_target : Map[String, String],
  styles : DocxStyles,
  numbering : DocxNumbering,
) -> Map[Int, DocxEndnote] {
  let out : Map[Int, DocxEndnote] = {}
  if xml.trim() == "" {
    return out
  }
  parse_docx_note_entries(xml, "<w:endnote", "</w:endnote>", fn(
    id,
    _open_tag,
    inner,
  ) {
    if is_special_docx_note_id(id) {
      return
    }
    let text = collect_docx_paragraph_texts(inner)
    let markdown = render_docx_note_entry_markdown(
      inner, rel_ctx, asset_by_target, styles, numbering,
    )
    if text != "" || markdown != "" {
      out[id] = { text, markdown }
    }
  })
  out
}

///|
fn parse_comments_xml(
  xml : String,
  rel_ctx : DocxRelationshipContext,
  asset_by_target : Map[String, String],
  styles : DocxStyles,
  numbering : DocxNumbering,
) -> Map[Int, DocxComment] {
  let out : Map[Int, DocxComment] = {}
  if xml.trim() == "" {
    return out
  }
  parse_docx_note_entries(xml, "<w:comment", "</w:comment>", fn(
    id,
    open_tag,
    inner,
  ) {
    let text = collect_docx_paragraph_texts(inner)
    let markdown = render_docx_note_entry_markdown(
      inner, rel_ctx, asset_by_target, styles, numbering,
    )
    if text == "" && markdown == "" {
      return
    }
    out[id] = {
      author: normalize_optional_note_attr(
        read_attr_value_in_tag(open_tag, "w:author"),
      ),
      text,
      markdown,
    }
  })
  out
}

///|
fn parse_docx_note_entries(
  xml : String,
  open_prefix : String,
  close_tag : String,
  on_entry : (Int, String, String) -> Unit,
) -> Unit {
  let chars = xml.to_array()
  let open_pat = open_prefix.to_array()
  let mut i = 0

  while true {
    let start = find_exact_open_tag(chars, i, open_pat)
    if start < 0 {
      break
    }

    let open_end = find_sub(chars, start, ">")
    if open_end < 0 {
      break
    }

    let close = find_sub(chars, open_end + 1, close_tag)
    if close < 0 {
      break
    }

    let open_tag = profiled_slice_to_string(chars, start, open_end + 1)
    let inner = profiled_slice_to_string(chars, open_end + 1, close)
    let id = match read_attr_value_in_tag(open_tag, "w:id") {
      Some(v) => parse_signed_int_default(v, -999999)
      None => -999999
    }
    if id != -999999 {
      on_entry(id, open_tag, inner)
    }

    i = close + close_tag.length()
  }
}

///|
fn is_special_docx_note_id(id : Int) -> Bool {
  id < 0
}

///|
fn normalize_optional_note_attr(value : String?) -> String? {
  match value {
    Some(raw) => {
      let trimmed = @cor.trim_string(xml_unescape(raw))
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
fn collect_docx_paragraph_texts(xml : String) -> String {
  let chars = strip_docx_deleted_revision_xml(xml).to_array()
  let mut i = 0
  let parts : Array[String] = []

  while true {
    let p1 = find_exact_open_tag(chars, i, wp_open_tag_chars)
    if p1 < 0 {
      break
    }
    let p2 = find_sub(chars, p1, ">")
    if p2 < 0 {
      break
    }
    let p3 = find_sub(chars, p2 + 1, "</w:p>")
    if p3 < 0 {
      break
    }
    let text = @cor.trim_string(text_from_docx_range(chars, p2 + 1, p3))
    if text != "" {
      parts.push(text)
    }
    i = p3 + 6
  }

  if parts.length() == 0 {
    collect_wt_text(xml)
  } else {
    parts.join("\n")
  }
}

///|
fn render_docx_note_entry_markdown(
  xml : String,
  rel_ctx : DocxRelationshipContext,
  asset_by_target : Map[String, String],
  styles : DocxStyles,
  numbering : DocxNumbering,
) -> String {
  let visible_xml = strip_docx_text_box_content_xml(
    strip_docx_deleted_revision_xml(xml),
  )
  let chars = visible_xml.to_array()
  let note_doc = @cor.new_document()
  let mut i = 0

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
      let rows = scan_table_block_with_context_and_ledger(
        tbl_xml,
        rel_ctx,
        asset_by_target,
        None,
        None,
      )
      if rows.length() > 0 {
        @cor.push(
          note_doc,
          @cor.Block::RichTable({ rows, header_rows: 1, hints: None }),
        )
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
      let p_xml = profiled_slice_to_string(chars, p2 + 1, p3)
      let blocks = scan_paragraph(
        p_xml,
        rel_ctx,
        asset_by_target,
        styles,
        numbering,
        0,
        None,
        None,
      )
      for block in blocks {
        @cor.push(note_doc, block)
      }
      i = p3 + 6
      continue
    }

    break
  }

  @cor.emit_markdown(note_doc).trim().to_owned()
}
