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

    let open_tag = @cor.slice_to_string(chars, start, open_end + 1)
    let inner = @cor.slice_to_string(chars, open_end + 1, close)
    let id = match read_attr_value_in_tag(open_tag, "w:id") {
      Some(v) => parse_signed_int_default(v, -999999)
      None => -999999
    }
    if id != -999999 && id >= 0 {
      on_entry(id, open_tag, inner)
    }

    i = close + close_tag.length()
  }
}

///|
fn parse_docx_footnotes_xml(
  xml : String,
  pkg : @ox.OoxmlPackage,
  styles : DocxStyles,
  numbering : DocxNumbering,
  issues : Array[DocxValidationIssue],
) -> Array[DocxFootnote] {
  let out : Array[DocxFootnote] = []
  if xml.trim() == "" {
    return out
  }

  let ctx : DocxPartParseContext = {
    pkg,
    rels: empty_docx_relationship_index(),
    source_part: "word/footnotes.xml",
    issues,
  }
  parse_docx_note_entries(xml, "<w:footnote", "</w:footnote>", fn(
    id,
    _tag,
    inner,
  ) {
    let blocks = parse_docx_body_blocks(
      strip_docx_deleted_revision_xml(inner),
      ctx,
      styles,
      numbering,
    )
    out.push({ id, body_blocks: blocks, text: docx_blocks_visible_text(blocks) })
  })
  out
}

///|
fn parse_docx_endnotes_xml(
  xml : String,
  pkg : @ox.OoxmlPackage,
  styles : DocxStyles,
  numbering : DocxNumbering,
  issues : Array[DocxValidationIssue],
) -> Array[DocxEndnote] {
  let out : Array[DocxEndnote] = []
  if xml.trim() == "" {
    return out
  }

  let ctx : DocxPartParseContext = {
    pkg,
    rels: empty_docx_relationship_index(),
    source_part: "word/endnotes.xml",
    issues,
  }
  parse_docx_note_entries(xml, "<w:endnote", "</w:endnote>", fn(
    id,
    _tag,
    inner,
  ) {
    let blocks = parse_docx_body_blocks(
      strip_docx_deleted_revision_xml(inner),
      ctx,
      styles,
      numbering,
    )
    out.push({ id, body_blocks: blocks, text: docx_blocks_visible_text(blocks) })
  })
  out
}

///|
fn parse_docx_comments_xml(
  xml : String,
  pkg : @ox.OoxmlPackage,
  styles : DocxStyles,
  numbering : DocxNumbering,
  issues : Array[DocxValidationIssue],
) -> Array[DocxComment] {
  let out : Array[DocxComment] = []
  if xml.trim() == "" {
    return out
  }

  let ctx : DocxPartParseContext = {
    pkg,
    rels: empty_docx_relationship_index(),
    source_part: "word/comments.xml",
    issues,
  }
  parse_docx_note_entries(xml, "<w:comment", "</w:comment>", fn(
    id,
    tag,
    inner,
  ) {
    let blocks = parse_docx_body_blocks(
      strip_docx_deleted_revision_xml(inner),
      ctx,
      styles,
      numbering,
    )
    out.push({
      id,
      author: normalize_optional_docx_attr(
        read_attr_value_in_tag(tag, "w:author"),
      ),
      body_blocks: blocks,
      text: docx_blocks_visible_text(blocks),
    })
  })
  out
}

///|
fn parse_docx_header_footer_ref_type(raw : String) -> DocxHeaderFooterRefType {
  match ascii_lower(raw.trim().to_owned()) {
    "default" => DocxHeaderFooterRefType::Default
    "first" => DocxHeaderFooterRefType::First
    "even" => DocxHeaderFooterRefType::Even
    _ => DocxHeaderFooterRefType::Unknown
  }
}

///|
fn parse_docx_header_footer_references(
  doc_xml : String,
  rels : DocxRelationshipIndex,
  issues : Array[DocxValidationIssue],
) -> Array[DocxHeaderFooterReference] {
  let refs : Array[DocxHeaderFooterReference] = []
  let seen : Map[String, Bool] = Map::new()
  let chars = doc_xml.to_array()
  let mut i = 0

  while true {
    let s1 = find_sub(chars, i, "<w:sectPr")
    if s1 < 0 {
      break
    }
    let s2 = find_sub(chars, s1, ">")
    if s2 < 0 {
      break
    }
    let s3 = find_sub(chars, s2 + 1, "</w:sectPr>")
    if s3 < 0 {
      break
    }
    let sect_xml = @cor.slice_to_string(chars, s2 + 1, s3)
    collect_docx_header_footer_refs_for_tag(
      sect_xml, rels, refs, seen, issues, "<w:headerReference", true,
    )
    collect_docx_header_footer_refs_for_tag(
      sect_xml, rels, refs, seen, issues, "<w:footerReference", false,
    )
    i = s3 + 11
  }

  refs
}

///|
fn collect_docx_header_footer_refs_for_tag(
  xml : String,
  rels : DocxRelationshipIndex,
  refs : Array[DocxHeaderFooterReference],
  seen : Map[String, Bool],
  issues : Array[DocxValidationIssue],
  open_prefix : String,
  is_header : Bool,
) -> Unit {
  let chars = xml.to_array()
  let open_pat = open_prefix.to_array()
  let mut i = 0

  while true {
    let start = find_exact_open_tag(chars, i, open_pat)
    if start < 0 {
      break
    }
    let end_ = find_sub(chars, start, ">")
    if end_ < 0 {
      break
    }
    let tag = @cor.slice_to_string(chars, start, end_ + 1)
    let rid = read_attr_value_in_tag(tag, "r:id").unwrap_or("")
    let ref_type = parse_docx_header_footer_ref_type(
      read_attr_value_in_tag(tag, "w:type").unwrap_or(""),
    )
    match lookup_docx_part_target_opt(rels, rid) {
      Some(part_name) => {
        let dedup_key = if is_header {
          "header:" + part_name
        } else {
          "footer:" + part_name
        }
        if !seen.contains(dedup_key) {
          seen.set(dedup_key, true)
          refs.push({ is_header, ref_type, relationship_id: rid, part_name })
        }
      }
      None =>
        issues.push(
          docx_issue(
            DocxValidationIssueKind::MissingRelationshipTarget,
            DocxValidationSeverity::Warning,
            Some("word/document.xml"),
            Some(rid),
            None,
            None,
            "header/footer relationship target is missing: " + rid,
          ),
        )
    }
    i = end_ + 1
  }
}

///|
fn collect_docx_text_boxes_from_xml(
  xml : String,
  ctx : DocxPartParseContext,
  styles : DocxStyles,
  numbering : DocxNumbering,
  context : DocxTextBoxContext,
  source_part : String,
  relationship_id : String?,
) -> Array[DocxTextBox] {
  let chars = strip_docx_deleted_revision_xml(xml).to_array()
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
    let close = find_pattern_in_range(
      chars,
      open_end + 1,
      chars.length(),
      txbx_content_close_tag_chars,
    )
    if close < 0 {
      break
    }

    let inner = @cor.slice_to_string(chars, open_end + 1, close)
    let blocks = parse_docx_body_blocks(inner, ctx, styles, numbering)
    if blocks.length() > 0 {
      textbox_index += 1
      out.push({
        context,
        source_part,
        relationship_id,
        textbox_index,
        body_blocks: blocks,
      })
    }

    i = close + txbx_content_close_tag_chars.length()
  }

  out
}
