///|
fn find_sub(chars : Array[Char], from : Int, pat : String) -> Int {
  let search_len = if from < chars.length() { chars.length() - from } else { 0 }
  profile_xml_tag_scan_call(search_len)
  let p = pat.to_array()
  let plen = p.length()
  let mut i = from
  while i + plen <= chars.length() {
    let mut ok = true
    for k in 0..<plen {
      if chars[i + k] != p[k] {
        ok = false
        break
      }
    }
    if ok {
      return i
    }
    i += 1
  }
  -1
}

///|
fn read_attr_value(block : String, attr_pat : String) -> String? {
  profile_xml_attr_lookup_call()
  // 在 block 字符串里找 attr_pat（比如 "<w:pStyle w:val=\"" 或 "r:embed=\"")
  // 找到则返回引号中的内容
  let chars = block.to_array()
  let pos = find_sub(chars, 0, attr_pat)
  if pos < 0 {
    return None
  }
  let start = pos + attr_pat.length()
  let mut j = start
  let buf : Ref[Array[Char]] = { val: [] }
  while j < chars.length() && chars[j] != '"' {
    buf.val.push(chars[j])
    j += 1
  }
  Some(String::from_array(buf.val))
}

///|
fn is_delim_for_tag(c : Char) -> Bool {
  c == ' ' || c == '>' || c == '/' || c == '\n' || c == '\r' || c == '\t'
}

///|
let wt_open_tag_chars : Array[Char] = "<w:t".to_array()

///|
let wt_close_tag_chars : Array[Char] = "</w:t>".to_array()

///|
let wp_open_tag_chars : Array[Char] = "<w:p".to_array()

///|
let wp_close_tag_chars : Array[Char] = "</w:p>".to_array()

///|
let wtbl_open_tag_chars : Array[Char] = "<w:tbl".to_array()

///|
let wtbl_close_tag_chars : Array[Char] = "</w:tbl>".to_array()

///|
let wtr_open_tag_chars : Array[Char] = "<w:tr".to_array()

///|
let wtr_close_tag_chars : Array[Char] = "</w:tr>".to_array()

///|
let wtc_open_tag_chars : Array[Char] = "<w:tc".to_array()

///|
let wtc_close_tag_chars : Array[Char] = "</w:tc>".to_array()

///|
let tab_open_tag_chars : Array[Char] = "<w:tab".to_array()

///|
let br_open_tag_chars : Array[Char] = "<w:br".to_array()

///|
let hyperlink_open_tag_chars : Array[Char] = "<w:hyperlink".to_array()

///|
let hyperlink_close_tag_chars : Array[Char] = "</w:hyperlink>".to_array()

///|
let footnote_ref_open_tag_chars : Array[Char] = "<w:footnoteReference".to_array()

///|
let endnote_ref_open_tag_chars : Array[Char] = "<w:endnoteReference".to_array()

///|
let comment_ref_open_tag_chars : Array[Char] = "<w:commentReference".to_array()

///|
let comment_range_start_open_tag_chars : Array[Char] = "<w:commentRangeStart".to_array()

///|
let comment_range_end_open_tag_chars : Array[Char] = "<w:commentRangeEnd".to_array()

///|
let instr_text_open_tag_chars : Array[Char] = "<w:instrText".to_array()

///|
let instr_text_close_tag_chars : Array[Char] = "</w:instrText>".to_array()

///|
let txbx_content_open_tag_chars : Array[Char] = "<w:txbxContent".to_array()

///|
let txbx_content_close_tag_chars : Array[Char] = "</w:txbxContent>".to_array()

///|
let del_open_tag_chars : Array[Char] = "<w:del".to_array()

///|
let del_close_tag_chars : Array[Char] = "</w:del>".to_array()

///|
let move_from_open_tag_chars : Array[Char] = "<w:moveFrom".to_array()

///|
let move_from_close_tag_chars : Array[Char] = "</w:moveFrom>".to_array()

///|
let del_text_open_tag_chars : Array[Char] = "<w:delText".to_array()

///|
let del_text_close_tag_chars : Array[Char] = "</w:delText>".to_array()

///|
let move_from_range_start_open_tag_chars : Array[Char] = "<w:moveFromRangeStart".to_array()

///|
let move_from_range_end_open_tag_chars : Array[Char] = "<w:moveFromRangeEnd".to_array()

///|
let move_to_range_start_open_tag_chars : Array[Char] = "<w:moveToRangeStart".to_array()

///|
let move_to_range_end_open_tag_chars : Array[Char] = "<w:moveToRangeEnd".to_array()

///|
fn xml_unescape(s : String) -> String {
  let t = s
    .replace(old="&lt;", new="<")
    .replace(old="&gt;", new=">")
    .replace(old="&amp;", new="&")
    .replace(old="&quot;", new="\"")
    .replace(old="&apos;", new="'")

  @cor.decode_numeric_entities(t)
}

///|
fn find_char_in_range(
  chars : Array[Char],
  from : Int,
  end_ : Int,
  target : Char,
) -> Int {
  let mut i = from
  while i < end_ {
    if chars[i] == target {
      profile_xml_tag_scan_call(i - from + 1)
      return i
    }
    i += 1
  }
  profile_xml_tag_scan_call(if end_ > from { end_ - from } else { 0 })
  -1
}

///|
fn find_pattern_in_range(
  chars : Array[Char],
  from : Int,
  end_ : Int,
  pat : Array[Char],
) -> Int {
  let plen = pat.length()
  let mut i = from
  while i + plen <= end_ {
    let mut ok = true
    for k in 0..<plen {
      if chars[i + k] != pat[k] {
        ok = false
        break
      }
    }
    if ok {
      profile_xml_tag_scan_call(i - from + plen)
      return i
    }
    i += 1
  }
  profile_xml_tag_scan_call(if end_ > from { end_ - from } else { 0 })
  -1
}

///|
fn find_matching_docx_element_close(
  chars : Array[Char],
  open_start : Int,
  open_pat : Array[Char],
  close_pat : Array[Char],
) -> Int {
  let open_end = find_sub(chars, open_start, ">")
  if open_end < 0 {
    return -1
  }

  let mut depth = 1
  let mut i = open_end + 1

  while i < chars.length() {
    let next_open = find_exact_open_tag(chars, i, open_pat)
    let next_close = find_pattern_in_range(chars, i, chars.length(), close_pat)
    if next_close < 0 {
      return -1
    }

    if next_open >= 0 && next_open < next_close {
      let next_open_end = find_sub(chars, next_open, ">")
      if next_open_end < 0 {
        return -1
      }
      depth += 1
      i = next_open_end + 1
      continue
    }

    depth -= 1
    if depth == 0 {
      return next_close
    }
    i = next_close + close_pat.length()
  }

  -1
}

///|
fn tag_prefix_matches(
  chars : Array[Char],
  pos : Int,
  end_ : Int,
  pat : Array[Char],
) -> Bool {
  let plen = pat.length()
  if pos + plen >= end_ {
    return false
  }
  for i in 0..<plen {
    if chars[pos + i] != pat[i] {
      return false
    }
  }
  is_delim_for_tag(chars[pos + plen])
}

///|
fn open_tag_is_self_closing(
  chars : Array[Char],
  open_start : Int,
  open_end : Int,
) -> Bool {
  let mut i = open_end - 1
  while i > open_start {
    let ch = chars[i]
    if ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t' {
      i -= 1
      continue
    }
    return ch == '/'
  }
  false
}

///|
fn text_from_docx_range(chars : Array[Char], start : Int, end_ : Int) -> String {
  let out = StringBuilder::new()
  let mut i = start

  while i < end_ {
    let lt = find_char_in_range(chars, i, end_, '<')
    if lt < 0 {
      break
    }
    if lt + 1 >= end_ {
      break
    }
    let gt = find_char_in_range(chars, lt + 1, end_, '>')
    if gt < 0 {
      break
    }

    if chars[lt + 1] != '/' {
      if tag_prefix_matches(chars, lt, end_, wt_open_tag_chars) {
        let close = find_pattern_in_range(
          chars,
          gt + 1,
          end_,
          wt_close_tag_chars,
        )
        if close < 0 {
          i = gt + 1
          continue
        }
        out.write_string(
          xml_unescape(profiled_slice_to_string(chars, gt + 1, close)),
        )
        i = close + wt_close_tag_chars.length()
        continue
      }

      if tag_prefix_matches(chars, lt, end_, br_open_tag_chars) {
        out.write_string("\n")
        i = gt + 1
        continue
      }

      if tag_prefix_matches(chars, lt, end_, tab_open_tag_chars) {
        out.write_string("\t")
        i = gt + 1
        continue
      }
    }

    i = gt + 1
  }

  out.to_string()
}

///|
fn parse_footnotes_xml(xml : String) -> Map[Int, DocxFootnote] {
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
    if text != "" {
      out[id] = { text, }
    }
  })
  out
}

///|
fn parse_endnotes_xml(xml : String) -> Map[Int, DocxEndnote] {
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
    if text != "" {
      out[id] = { text, }
    }
  })
  out
}

///|
fn parse_comments_xml(xml : String) -> Map[Int, DocxComment] {
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
    if text == "" {
      return
    }
    out[id] = {
      author: normalize_optional_note_attr(
        read_attr_value_in_tag(open_tag, "w:author"),
      ),
      text,
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
fn find_exact_open_tag(
  chars : Array[Char],
  from : Int,
  pat : Array[Char],
) -> Int {
  let mut i = from
  while true {
    let p = find_pattern_in_range(chars, i, chars.length(), pat)
    if p < 0 {
      return -1
    }
    if tag_prefix_matches(chars, p, chars.length(), pat) {
      return p
    }
    i = p + pat.length()
  }
  -1
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

///|
fn scan_docx_inline_text(
  block : String,
  rel_ctx : DocxRelationshipContext,
  ledger : DocxReferenceLedger?,
) -> DocxInlineScanResult {
  profile_collect_wt_inlines_call()
  let chars = block.to_array()
  let text_out = StringBuilder::new()
  let out : Array[@cor.Inline] = []
  let mut i = 0

  while i < chars.length() {
    let lt = find_char_in_range(chars, i, chars.length(), '<')
    if lt < 0 {
      break
    }
    if lt + 1 >= chars.length() {
      break
    }
    let gt = find_char_in_range(chars, lt + 1, chars.length(), '>')
    if gt < 0 {
      break
    }

    if chars[lt + 1] != '/' &&
      tag_prefix_matches(chars, lt, chars.length(), hyperlink_open_tag_chars) {
      profile_hyperlink_node_seen()
      let close = find_pattern_in_range(
        chars,
        gt + 1,
        chars.length(),
        hyperlink_close_tag_chars,
      )
      if close < 0 {
        i = gt + 1
        continue
      }

      let open_tag = profiled_slice_to_string(chars, lt, gt + 1)
      let raw_text = text_from_docx_range(chars, gt + 1, close)
      text_out.write_string(raw_text)

      let text = @cor.trim_string(raw_text)
      let rid = read_attr_value_in_tag(open_tag, "r:id").unwrap_or("")
      let url = lookup_doc_hyperlink_target(rel_ctx, rid)
      if text != "" {
        if url.trim() == "" {
          out.push(@cor.Inline::Text(text))
        } else {
          out.push(@cor.Inline::Link(text, url.trim().to_owned()))
        }
      }

      i = close + hyperlink_close_tag_chars.length()
      continue
    }

    if chars[lt + 1] != '/' &&
      tag_prefix_matches(chars, lt, chars.length(), footnote_ref_open_tag_chars) {
      let open_tag = profiled_slice_to_string(chars, lt, gt + 1)
      match read_attr_value_in_tag(open_tag, "w:id") {
        Some(v) => {
          let id = parse_signed_int_default(v, -1)
          if id >= 0 {
            let index = match ledger {
              Some(x) => record_docx_footnote_reference_and_get_index(x, id)
              None => 1
            }
            let marker = "[^" + index.to_string() + "]"
            text_out.write_string(marker)
            out.push(@cor.Inline::Text(marker))
          }
        }
        None => ()
      }
      i = gt + 1
      continue
    }

    if chars[lt + 1] != '/' &&
      tag_prefix_matches(chars, lt, chars.length(), endnote_ref_open_tag_chars) {
      let open_tag = profiled_slice_to_string(chars, lt, gt + 1)
      match read_attr_value_in_tag(open_tag, "w:id") {
        Some(v) => {
          let id = parse_signed_int_default(v, -1)
          if id >= 0 {
            let index = match ledger {
              Some(x) => record_docx_endnote_reference_and_get_index(x, id)
              None => 1
            }
            let marker = "[^e" + index.to_string() + "]"
            text_out.write_string(marker)
            out.push(@cor.Inline::Text(marker))
          }
        }
        None => ()
      }
      i = gt + 1
      continue
    }

    if chars[lt + 1] != '/' &&
      tag_prefix_matches(chars, lt, chars.length(), comment_ref_open_tag_chars) {
      let open_tag = profiled_slice_to_string(chars, lt, gt + 1)
      match read_attr_value_in_tag(open_tag, "w:id") {
        Some(v) => {
          let id = parse_signed_int_default(v, -1)
          if id >= 0 {
            let index = match ledger {
              Some(x) => record_docx_comment_reference_and_get_index(x, id)
              None => 1
            }
            let marker = " [comment " + index.to_string() + "]"
            text_out.write_string(marker)
            out.push(@cor.Inline::Text(marker))
          }
        }
        None => ()
      }
      i = gt + 1
      continue
    }

    if chars[lt + 1] != '/' &&
      (
        tag_prefix_matches(
          chars,
          lt,
          chars.length(),
          comment_range_start_open_tag_chars,
        ) ||
        tag_prefix_matches(
          chars,
          lt,
          chars.length(),
          comment_range_end_open_tag_chars,
        )
      ) {
      i = gt + 1
      continue
    }

    if chars[lt + 1] != '/' &&
      tag_prefix_matches(chars, lt, chars.length(), wt_open_tag_chars) {
      let close = find_pattern_in_range(
        chars,
        gt + 1,
        chars.length(),
        wt_close_tag_chars,
      )
      if close < 0 {
        i = gt + 1
        continue
      }

      let text = xml_unescape(profiled_slice_to_string(chars, gt + 1, close))
      if text != "" {
        text_out.write_string(text)
        out.push(@cor.Inline::Text(text))
      }

      i = close + wt_close_tag_chars.length()
      continue
    }

    if chars[lt + 1] != '/' &&
      tag_prefix_matches(chars, lt, chars.length(), br_open_tag_chars) {
      text_out.write_string("\n")
      out.push(@cor.Inline::Break)
      i = gt + 1
      continue
    }

    if chars[lt + 1] != '/' &&
      tag_prefix_matches(chars, lt, chars.length(), tab_open_tag_chars) {
      text_out.write_string("\t")
      out.push(@cor.Inline::Text("\t"))
      i = gt + 1
      continue
    }

    i = gt + 1
  }

  { inlines: out, text: @cor.trim_string(text_out.to_string()) }
}

///|
/// 从单元格内部提取文本：
/// - 按 <w:p> 分段
/// - 每个段落内部仍用 collect_wt_text
/// - 多段落之间用 '\n' 连接
fn collect_tc_text(tc_inner : String) -> String {
  let stripped_inner = strip_docx_text_box_content_xml(tc_inner)
  let chars = stripped_inner.to_array()
  let mut i = 0
  let parts : Array[String] = []

  while true {
    let p1 = find_sub(chars, i, "<w:p")
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
    if !@cor.is_blank(text) {
      parts.push(text)
    }

    i = p3 + 6
  }

  if parts.length() == 0 {
    collect_wt_text(stripped_inner)
  } else {
    parts.join("\n")
  }
}

///|
fn collect_wt_text(block : String) -> String {
  profile_collect_wt_text_call(block.length())
  @cor.trim_string(text_from_docx_range(block.to_array(), 0, block.length()))
}

///|
fn ascii_lower(s : String) -> String {
  let out = StringBuilder::new()
  for ch in s {
    if ch >= 'A' && ch <= 'Z' {
      out.write_char(Int::unsafe_to_char(ch.to_int() + 32))
    } else {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn parse_int_default(s : String, fallback : Int) -> Int {
  if s == "" {
    return fallback
  }

  let chars = s.to_array()
  let mut i = 0
  let mut n = 0

  while i < chars.length() {
    let c = chars[i]
    let k = c.to_int()
    if k < 48 || k > 57 {
      return fallback
    }
    n = n * 10 + (k - 48)
    i = i + 1
  }

  n
}

///|
fn parse_signed_int_default(s : String, fallback : Int) -> Int {
  if s == "" {
    return fallback
  }

  let chars = s.to_array()
  if chars.length() == 0 {
    return fallback
  }

  let mut i = 0
  let mut sign = 1
  if chars[0] == '-' {
    sign = -1
    i = 1
  }
  if i >= chars.length() {
    return fallback
  }

  let mut n = 0
  while i < chars.length() {
    let c = chars[i]
    let k = c.to_int()
    if k < 48 || k > 57 {
      return fallback
    }
    n = n * 10 + (k - 48)
    i += 1
  }

  sign * n
}

///|
/// 从单个 tag 中读属性，兼容：
/// <w:style w:type="paragraph" w:styleId="Heading1">
fn read_attr_value_in_tag(tag : String, attr_name : String) -> String? {
  match read_attr_value(tag, attr_name + "=\"") {
    Some(v) => Some(v)
    None => read_attr_value(tag, attr_name + "='")
  }
}
