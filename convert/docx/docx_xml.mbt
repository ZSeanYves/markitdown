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
let tab_open_tag_chars : Array[Char] = "<w:tab".to_array()

///|
let br_open_tag_chars : Array[Char] = "<w:br".to_array()

///|
let hyperlink_open_tag_chars : Array[Char] = "<w:hyperlink".to_array()

///|
let hyperlink_close_tag_chars : Array[Char] = "</w:hyperlink>".to_array()

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
fn scan_docx_inline_text(
  block : String,
  rel_ctx : DocxRelationshipContext,
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
  let chars = tc_inner.to_array()
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
    collect_wt_text(tc_inner)
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
fn is_delim(c : Char) -> Bool {
  c == ' ' || c == '>' || c == '/' || c == '\n' || c == '\r' || c == '\t'
}

///|
fn find_tc_open(chars : Array[Char], from : Int) -> Int {
  // 只匹配真正的 "<w:tc ...>"，排除 "<w:tcW", "<w:tcPr", "<w:tcMar" ...
  let mut i = from
  while true {
    let p = find_sub(chars, i, "<w:tc")
    if p < 0 {
      return -1
    }

    // "<w:tc" 长度是 5，后面必须是分隔符才算 cell 开始
    if p + 5 < chars.length() && is_delim(chars[p + 5]) {
      return p
    }

    i = p + 5
  }
  -1
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
/// 从单个 tag 中读属性，兼容：
/// <w:style w:type="paragraph" w:styleId="Heading1">
fn read_attr_value_in_tag(tag : String, attr_name : String) -> String? {
  match read_attr_value(tag, attr_name + "=\"") {
    Some(v) => Some(v)
    None => read_attr_value(tag, attr_name + "='")
  }
}
