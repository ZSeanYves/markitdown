///|
fn find_sub(chars : Array[Char], from : Int, pat : String) -> Int {
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
  let chars = block.to_array()
  let pos = find_sub(chars, 0, attr_pat)
  if pos < 0 {
    return None
  }
  let start = pos + attr_pat.length()
  let terminator = if attr_pat.length() > 0 {
    let last = attr_pat.to_array()[attr_pat.length() - 1]
    if last == '"' || last == '\'' {
      last
    } else {
      '"'
    }
  } else {
    '"'
  }
  let buf : Array[Char] = []
  let mut j = start
  while j < chars.length() && chars[j] != terminator {
    buf.push(chars[j])
    j += 1
  }
  Some(String::from_array(buf))
}

///|
fn read_attr_value_in_tag(tag : String, attr_name : String) -> String? {
  match read_attr_value(tag, attr_name + "=\"") {
    Some(v) => Some(v)
    None => read_attr_value(tag, attr_name + "='")
  }
}

///|
fn is_delim_for_tag(c : Char) -> Bool {
  c == ' ' || c == '>' || c == '/' || c == '\n' || c == '\r' || c == '\t'
}

///|
let wbody_open_tag_chars : Array[Char] = "<w:body".to_array()

///|
let wbody_close_tag_chars : Array[Char] = "</w:body>".to_array()

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
let wr_open_tag_chars : Array[Char] = "<w:r".to_array()

///|
let wr_close_tag_chars : Array[Char] = "</w:r>".to_array()

///|
let wt_open_tag_chars : Array[Char] = "<w:t".to_array()

///|
let wt_close_tag_chars : Array[Char] = "</w:t>".to_array()

///|
let tab_open_tag_chars : Array[Char] = "<w:tab".to_array()

///|
let br_open_tag_chars : Array[Char] = "<w:br".to_array()

///|
let cr_open_tag_chars : Array[Char] = "<w:cr".to_array()

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
let ablip_open_tag_chars : Array[Char] = "<a:blip".to_array()

///|
let vimagedata_open_tag_chars : Array[Char] = "<v:imagedata".to_array()

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
      return i
    }
    i += 1
  }
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
      return i
    }
    i += 1
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
          xml_unescape(@cor.slice_to_string(chars, gt + 1, close)),
        )
        i = close + wt_close_tag_chars.length()
        continue
      }

      if tag_prefix_matches(chars, lt, end_, br_open_tag_chars) ||
        tag_prefix_matches(chars, lt, end_, cr_open_tag_chars) {
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
      out.write_string(@cor.slice_to_string(chars, i, chars.length()))
      break
    }

    out.write_string(@cor.slice_to_string(chars, i, start))
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
      out.write_string(@cor.slice_to_string(chars, i, chars.length()))
      break
    }

    out.write_string(@cor.slice_to_string(chars, i, start))
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
      out.write_string(@cor.slice_to_string(chars, i, chars.length()))
      break
    }

    out.write_string(@cor.slice_to_string(chars, i, start))
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
      i = open_end + 1
      continue
    }
    i = close + txbx_content_close_tag_chars.length()
  }

  out.to_string()
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
    i += 1
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
