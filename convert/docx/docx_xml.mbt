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
let omath_open_tag_chars : Array[Char] = "<m:oMath".to_array()

///|
let omath_close_tag_chars : Array[Char] = "</m:oMath>".to_array()

///|
let omathpara_open_tag_chars : Array[Char] = "<m:oMathPara".to_array()

///|
let omathpara_close_tag_chars : Array[Char] = "</m:oMathPara>".to_array()

///|
let math_text_open_tag_chars : Array[Char] = "<m:t".to_array()

///|
let math_text_close_tag_chars : Array[Char] = "</m:t>".to_array()

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
  let open_len = open_pat.length()
  let close_len = close_pat.length()

  while i < chars.length() {
    if chars[i] == '<' {
      if i + close_len <= chars.length() {
        let mut close_ok = true
        for k in 0..<close_len {
          if chars[i + k] != close_pat[k] {
            close_ok = false
            break
          }
        }
        if close_ok {
          depth -= 1
          if depth == 0 {
            return i
          }
          i = i + close_len
          continue
        }
      }

      if i + open_len < chars.length() {
        let mut open_ok = true
        for k in 0..<open_len {
          if chars[i + k] != open_pat[k] {
            open_ok = false
            break
          }
        }
        if open_ok && is_delim_for_tag(chars[i + open_len]) {
          let next_open_end = find_sub(chars, i, ">")
          if next_open_end < 0 {
            return -1
          }
          if !open_tag_is_self_closing(chars, i, next_open_end) {
            depth += 1
          }
          i = next_open_end + 1
          continue
        }
      }
    }

    i += 1
  }

  -1
}

///|
fn pattern_matches_at(
  chars : Array[Char],
  pos : Int,
  pat : Array[Char],
) -> Bool {
  let plen = pat.length()
  if pos + plen > chars.length() {
    return false
  }
  for i in 0..<plen {
    if chars[pos + i] != pat[i] {
      return false
    }
  }
  true
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
fn scan_docx_inline_text(
  block : String,
  rel_ctx : DocxRelationshipContext,
  notes : DocxNoteBundle?,
  ledger : DocxReferenceLedger?,
) -> DocxInlineScanResult {
  let started = @env.now()
  defer docx_convert_profile_add_active_stage(
    "docx_inline_scan",
    @env.now() - started,
    Some("split=true nested_in=docx_paragraph_scan,docx_table_scan"),
  )
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
      tag_prefix_matches(chars, lt, chars.length(), omathpara_open_tag_chars) {
      let close = find_pattern_in_range(
        chars,
        gt + 1,
        chars.length(),
        omathpara_close_tag_chars,
      )
      if close < 0 {
        i = gt + 1
        continue
      }

      let inner = profiled_slice_to_string(chars, gt + 1, close)
      let math_text = collect_docx_math_visible_text(inner)
      if math_text != "" {
        text_out.write_string(math_text)
        out.push(@cor.Inline::Text(math_text))
      }
      i = close + omathpara_close_tag_chars.length()
      continue
    }

    if chars[lt + 1] != '/' &&
      tag_prefix_matches(chars, lt, chars.length(), omath_open_tag_chars) {
      let close = find_pattern_in_range(
        chars,
        gt + 1,
        chars.length(),
        omath_close_tag_chars,
      )
      if close < 0 {
        i = gt + 1
        continue
      }

      let inner = profiled_slice_to_string(chars, gt + 1, close)
      let math_text = collect_docx_math_visible_text(inner)
      if math_text != "" {
        text_out.write_string(math_text)
        out.push(@cor.Inline::Text(math_text))
      }
      i = close + omath_close_tag_chars.length()
      continue
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
      let anchor = read_attr_value_in_tag(open_tag, "w:anchor")
      let url = combine_docx_hyperlink_target(
        lookup_doc_hyperlink_target(rel_ctx, rid),
        anchor,
      )
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
            out.push(
              @cor.Inline::NoteRef(
                make_docx_footnote_note_ref(index, id, notes),
              ),
            )
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
            out.push(
              @cor.Inline::NoteRef(make_docx_endnote_note_ref(index, id, notes)),
            )
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
            let marker = docx_comment_marker_text(
              index,
              last_inline_text_for_spacing(out),
            )
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
        let cleaned = @cor.normalize_document_text_cleanup(text)
        if cleaned != "" {
          let needs_comment_spacing = should_insert_space_after_comment_marker(
            out, cleaned,
          )
          if needs_comment_spacing {
            text_out.write_string(" ")
            out.push(@cor.Inline::Text(" "))
          }
          text_out.write_string(text)
          out.push(@cor.Inline::Text(cleaned))
        } else {
          text_out.write_string(text)
          if is_whitespace_only_docx_text(text) {
            out.push(@cor.Inline::Text(text))
          }
        }
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

  let normalized_inlines = normalize_docx_note_marker_spacing_inlines(out)
  let normalized_text = normalize_docx_note_marker_spacing_text(
    text_out.to_string(),
  )
  { inlines: normalized_inlines, text: @cor.trim_string(normalized_text) }
}

///|
fn combine_docx_hyperlink_target(target : String, anchor : String?) -> String {
  let base = target.trim().to_owned()
  let fragment = match anchor {
    Some(value) => {
      let trimmed = value.trim().to_owned()
      if trimmed == "" {
        ""
      } else if trimmed.has_prefix("#") {
        trimmed
      } else {
        "#" + trimmed
      }
    }
    None => ""
  }
  if fragment == "" {
    return base
  }
  if base == "" {
    return fragment
  }
  if base.contains("#") {
    return base
  }
  base + fragment
}

///|
fn collect_docx_math_visible_text(xml : String) -> String {
  let chars = xml.to_array()
  let mut i = 0
  let out = StringBuilder::new()
  while i < chars.length() {
    let lt = find_char_in_range(chars, i, chars.length(), '<')
    if lt < 0 {
      break
    }
    let gt = find_char_in_range(chars, lt + 1, chars.length(), '>')
    if gt < 0 {
      break
    }

    if chars[lt + 1] != '/' &&
      tag_prefix_matches(chars, lt, chars.length(), math_text_open_tag_chars) {
      let close = find_pattern_in_range(
        chars,
        gt + 1,
        chars.length(),
        math_text_close_tag_chars,
      )
      if close < 0 {
        i = gt + 1
        continue
      }
      let text = @cor.trim_string(
        xml_unescape(profiled_slice_to_string(chars, gt + 1, close)),
      )
      if text != "" {
        out.write_string(text)
      }
      i = close + math_text_close_tag_chars.length()
      continue
    }

    if chars[lt + 1] != '/' &&
      (
        tag_prefix_matches(chars, lt, chars.length(), omath_open_tag_chars) ||
        tag_prefix_matches(chars, lt, chars.length(), omathpara_open_tag_chars)
      ) {
      i = gt + 1
      continue
    }

    if chars[lt + 1] == '/' &&
      (
        tag_prefix_matches(chars, lt, chars.length(), omath_close_tag_chars) ||
        tag_prefix_matches(chars, lt, chars.length(), omathpara_close_tag_chars)
      ) {
      i = gt + 1
      continue
    }

    i = gt + 1
  }
  out.to_string()
}

///|
/// 从单元格内部提取文本：
/// - 按 <w:p> 分段
/// - 每个段落内部仍用 collect_wt_text
/// - 多段落之间用 '\n' 连接
fn collect_tc_text_with_relationships(
  tc_inner : String,
  rel_ctx : DocxRelationshipContext,
  asset_by_target : Map[String, String],
  notes : DocxNoteBundle?,
  ledger : DocxReferenceLedger?,
) -> String {
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

    let p_xml = profiled_slice_to_string(chars, p2 + 1, p3)
    let text = @cor.trim_string(
      collect_tc_paragraph_text(p_xml, rel_ctx, asset_by_target, notes, ledger),
    )
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
fn collect_tc_paragraph_text(
  p_xml : String,
  rel_ctx : DocxRelationshipContext,
  asset_by_target : Map[String, String],
  notes : DocxNoteBundle?,
  ledger : DocxReferenceLedger?,
) -> String {
  let scan = scan_docx_inline_text(p_xml, rel_ctx, notes, ledger)
  let inline_text = render_docx_inline_markdown(scan.inlines, scan.text)
  match read_docx_image_context(p_xml, rel_ctx, asset_by_target) {
    Some(img) =>
      match normalize_optional_docx_image_attr(img.alt_text) {
        Some(alt) =>
          if inline_text == "" {
            alt
          } else if inline_text.contains(alt) {
            inline_text
          } else {
            inline_text + " " + alt
          }
        None => inline_text
      }
    None => inline_text
  }
}

///|
fn render_docx_inline_markdown(
  inlines : Array[@cor.Inline],
  fallback_text : String,
) -> String {
  if inlines.length() == 0 {
    return @cor.trim_string(fallback_text)
  }

  let out = StringBuilder::new()
  for inline in inlines {
    match inline {
      @cor.Inline::Text(text) => out.write_string(text)
      @cor.Inline::Break => out.write_string("\n")
      @cor.Inline::Link(text, href) =>
        out.write_string("[" + text + "](" + href + ")")
      @cor.Inline::NoteRef(note) =>
        if note.body_status == @cor.NoteBodyStatus::Resolved &&
          note.note_id.trim() != "" {
          out.write_string("[^" + note.note_id.trim().to_owned() + "]")
        } else if note.marker.trim() != "" {
          if note.marker.has_prefix("^") {
            out.write_string(note.marker)
          } else {
            out.write_string("^" + note.marker)
          }
        }
    }
  }
  @cor.trim_string(out.to_string())
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
