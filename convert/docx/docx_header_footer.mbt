///|
fn parse_docx_header_footer_references(
  doc_xml : String,
  rel_ctx : DocxRelationshipContext,
) -> Array[DocxHeaderFooterReference] {
  let chars = doc_xml.to_array()
  let mut i = 0
  let refs : Array[DocxHeaderFooterReference] = []
  let seen_parts : Map[String, Bool] = {}

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
    let sect_inner = profiled_slice_to_string(chars, s2 + 1, s3)
    collect_docx_header_footer_refs_from_sectpr(
      sect_inner, rel_ctx, refs, seen_parts,
    )
    i = s3 + 11
  }

  refs
}

///|
fn collect_docx_header_footer_refs_from_sectpr(
  sect_xml : String,
  rel_ctx : DocxRelationshipContext,
  refs : Array[DocxHeaderFooterReference],
  seen_parts : Map[String, Bool],
) -> Unit {
  collect_docx_header_footer_refs_for_tag(
    sect_xml,
    rel_ctx,
    refs,
    seen_parts,
    "<w:headerReference",
    DocxHeaderFooterKind::Header,
  )
  collect_docx_header_footer_refs_for_tag(
    sect_xml,
    rel_ctx,
    refs,
    seen_parts,
    "<w:footerReference",
    DocxHeaderFooterKind::Footer,
  )
}

///|
fn collect_docx_header_footer_refs_for_tag(
  xml : String,
  rel_ctx : DocxRelationshipContext,
  refs : Array[DocxHeaderFooterReference],
  seen_parts : Map[String, Bool],
  open_prefix : String,
  kind : DocxHeaderFooterKind,
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
    let tag = profiled_slice_to_string(chars, start, end_ + 1)
    let rid = read_attr_value_in_tag(tag, "r:id").unwrap_or("")
    let ref_type = parse_docx_header_footer_ref_type(
      read_attr_value_in_tag(tag, "w:type").unwrap_or(""),
    )
    match lookup_doc_part_target_opt(rel_ctx, rid) {
      Some(part_name) => {
        let dedup_key = header_footer_dedup_key(kind, part_name)
        if !seen_parts.contains(dedup_key) {
          seen_parts[dedup_key] = true
          refs.push({ kind, ref_type, relationship_id: rid, part_name })
        }
      }
      None => ()
    }
    i = end_ + 1
  }
}

///|
fn header_footer_dedup_key(
  kind : DocxHeaderFooterKind,
  part_name : String,
) -> String {
  let prefix = match kind {
    DocxHeaderFooterKind::Header => "header:"
    DocxHeaderFooterKind::Footer => "footer:"
  }
  prefix + part_name
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
fn render_docx_part_text_for_header_footer(xml : String) -> String {
  let chars = strip_docx_deleted_revision_xml(xml).to_array()
  let mut i = 0
  let blocks : Array[String] = []

  while i < chars.length() {
    let p_tbl = find_exact_open_tag(chars, i, wtbl_open_tag_chars)
    let p_p = find_exact_open_tag(chars, i, wp_open_tag_chars)

    if p_tbl >= 0 && (p_p < 0 || p_tbl < p_p) {
      let t2 = find_sub(chars, p_tbl, ">")
      if t2 < 0 {
        break
      }
      let t3 = find_sub(chars, t2 + 1, "</w:tbl>")
      if t3 < 0 {
        break
      }
      let tbl_xml = profiled_slice_to_string(chars, t2 + 1, t3)
      let rows = scan_table_block(tbl_xml)
      if rows.length() > 0 {
        blocks.push(render_docx_header_footer_table_text(rows))
      }
      i = t3 + 8
      continue
    }

    if p_p >= 0 {
      let p2 = find_sub(chars, p_p, ">")
      if p2 < 0 {
        break
      }
      let p3 = find_sub(chars, p2 + 1, "</w:p>")
      if p3 < 0 {
        break
      }
      let p_xml = profiled_slice_to_string(chars, p2 + 1, p3)
      let text = render_docx_header_footer_paragraph_text(p_xml)
      if !@cor.is_blank(text) {
        blocks.push(text)
      }
      i = p3 + 6
      continue
    }

    break
  }

  blocks.join("\n\n")
}

///|
fn render_docx_header_footer_table_text(rows : Array[Array[String]]) -> String {
  let lines : Array[String] = []
  for row in rows {
    let cells = row.map(fn(cell) { cell.replace(old="\n", new="<br>") })
    if cells.length() > 0 {
      lines.push("| " + cells.join(" | ") + " |")
    }
  }
  lines.join("\n")
}

///|
fn render_docx_header_footer_paragraph_text(p_xml : String) -> String {
  let text = collect_wt_text(strip_docx_page_field_xml(p_xml))
  if text != "" {
    return text
  }
  collect_wt_text(p_xml)
}

///|
fn strip_docx_page_field_xml(xml : String) -> String {
  let chars = xml.to_array()
  let out = StringBuilder::new()
  let mut i = 0

  while i < chars.length() {
    let lt = find_char_in_range(chars, i, chars.length(), '<')
    if lt < 0 {
      out.write_string(profiled_slice_to_string(chars, i, chars.length()))
      break
    }
    out.write_string(profiled_slice_to_string(chars, i, lt))
    let gt = find_char_in_range(chars, lt + 1, chars.length(), '>')
    if gt < 0 {
      break
    }

    if chars[lt + 1] != '/' &&
      tag_prefix_matches(chars, lt, chars.length(), instr_text_open_tag_chars) {
      let close = find_pattern_in_range(
        chars,
        gt + 1,
        chars.length(),
        instr_text_close_tag_chars,
      )
      if close < 0 {
        i = gt + 1
        continue
      }
      let instr = ascii_lower(
        @cor.trim_string(profiled_slice_to_string(chars, gt + 1, close)),
      )
      if instr.contains("page") || instr.contains("numpages") {
        i = close + instr_text_close_tag_chars.length()
        continue
      }
    }

    let tag = profiled_slice_to_string(chars, lt, gt + 1)
    if tag.contains("<w:fldChar") || tag.contains("<w:fldSimple") {
      i = gt + 1
      continue
    }

    out.write_string(tag)
    i = gt + 1
  }

  out.to_string()
}

///|
fn docx_header_footer_is_page_number_only(xml : String) -> Bool {
  if !docx_contains_page_field_markup(xml) {
    return false
  }

  let raw = collect_wt_text(xml)
  if @cor.is_blank(raw) {
    return false
  }
  let stripped = collect_wt_text(strip_docx_page_field_xml(xml))
  let noise_remainder = strip_docx_page_number_noise_text(stripped)
  if noise_remainder != "" {
    return false
  }
  !@cor.is_blank(raw)
}

///|
fn docx_contains_page_field_markup(xml : String) -> Bool {
  let lowered = ascii_lower(xml)
  let has_field_markup = lowered.contains("<w:fldchar") ||
    lowered.contains("<w:fldsimple") ||
    lowered.contains("<w:instrtext")
  has_field_markup && (lowered.contains("page") || lowered.contains("numpages"))
}

///|
fn strip_docx_page_number_noise_text(text : String) -> String {
  let out : Array[Char] = []
  let chars = ascii_lower(text).to_array()
  for ch in chars {
    if ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t' {
      continue
    }
    if (ch >= '0' && ch <= '9') ||
      ch == '/' ||
      ch == '-' ||
      ch == '.' ||
      ch == ',' ||
      ch == '(' ||
      ch == ')' {
      continue
    }
    out.push(ch)
  }
  String::from_array(out)
  .replace(old="page", new="")
  .replace(old="numpages", new="")
  .replace(old="of", new="")
}
