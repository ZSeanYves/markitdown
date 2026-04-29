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

// 只匹配真正的 "<w:t" 标签：后面必须是分隔符（空格 / > / /）

///|
fn find_wt_open(chars : Array[Char], from : Int) -> Int {
  let mut i = from
  while true {
    let p = find_sub(chars, i, "<w:t")
    if p < 0 {
      return -1
    }

    // "<w:t" 长度是 4
    if p + 4 < chars.length() && is_delim_for_tag(chars[p + 4]) {
      return p
    }

    i = p + 4
  }
  -1
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

    let p_xml = @cor.slice_to_string(chars, p2 + 1, p3)
    let text = collect_wt_text(p_xml)

    if !@cor.is_blank(text) {
      parts.push(text)
    }

    i = p3 + 6
  }

  if parts.length() == 0 {
    // 兜底：有些奇怪单元格里可能没有标准 <w:p>，仍退回旧逻辑
    collect_wt_text(tc_inner)
  } else {
    parts.join("\n")
  }
}

///|
fn collect_wt_text(block : String) -> String {
  let chars = block.to_array()
  let mut i = 0
  let mut out = ""

  while i < chars.length() {
    let p_t = find_wt_open(chars, i)
    let p_br = find_sub(chars, i, "<w:br")
    let p_tab = find_sub(chars, i, "<w:tab")

    let mut p = -1
    let mut kind = 0 // 1 = w:t, 2 = w:br, 3 = w:tab

    if p_t >= 0 {
      p = p_t
      kind = 1
    }
    if p_br >= 0 && (p < 0 || p_br < p) {
      p = p_br
      kind = 2
    }
    if p_tab >= 0 && (p < 0 || p_tab < p) {
      p = p_tab
      kind = 3
    }

    if p < 0 {
      break
    }

    if kind == 1 {
      let p2 = find_sub(chars, p, ">")
      if p2 < 0 {
        break
      }

      let p3 = find_sub(chars, p2 + 1, "</w:t>")
      if p3 < 0 {
        i = p2 + 1
        continue
      }

      out = out + @cor.slice_to_string(chars, p2 + 1, p3)
      i = p3 + 6
      continue
    }

    if kind == 2 {
      let p2 = find_sub(chars, p, ">")
      if p2 < 0 {
        break
      }
      out = out + "\n"
      i = p2 + 1
      continue
    }

    let p2 = find_sub(chars, p, ">")
    if p2 < 0 {
      break
    }
    out = out + "\t"
    i = p2 + 1
  }

  @cor.trim_string(out)
}

///|
fn collect_wt_inlines(
  block : String,
  rels : Map[String, String],
) -> Array[@cor.Inline] {
  let chars = block.to_array()
  let mut i = 0
  let out : Array[@cor.Inline] = []

  while i < chars.length() {
    let p_h = find_sub(chars, i, "<w:hyperlink")
    let p_t = find_wt_open(chars, i)
    let p_br = find_sub(chars, i, "<w:br")
    let p_tab = find_sub(chars, i, "<w:tab")

    let mut p = -1
    let mut kind = 0 // 1 = hyperlink, 2 = w:t, 3 = w:br, 4 = w:tab

    if p_h >= 0 {
      p = p_h
      kind = 1
    }
    if p_t >= 0 && (p < 0 || p_t < p) {
      p = p_t
      kind = 2
    }
    if p_br >= 0 && (p < 0 || p_br < p) {
      p = p_br
      kind = 3
    }
    if p_tab >= 0 && (p < 0 || p_tab < p) {
      p = p_tab
      kind = 4
    }

    if p < 0 {
      break
    }

    if kind == 1 {
      let p2 = find_sub(chars, p, ">")
      if p2 < 0 {
        break
      }
      let p3 = find_sub(chars, p2 + 1, "</w:hyperlink>")
      if p3 < 0 {
        i = p2 + 1
        continue
      }

      let open_tag = @cor.slice_to_string(chars, p, p2 + 1)
      let inner = @cor.slice_to_string(chars, p2 + 1, p3)
      let text = collect_wt_text(inner).trim().to_owned()
      let rid = read_attr_value_in_tag(open_tag, "r:id").unwrap_or("")
      let url = rels.get(rid).unwrap_or("")

      if text != "" {
        if url.trim() == "" {
          out.push(@cor.Inline::Text(text))
        } else {
          out.push(@cor.Inline::Link(text, url.trim().to_owned()))
        }
      }
      i = p3 + "</w:hyperlink>".length()
      continue
    }

    if kind == 2 {
      let p2 = find_sub(chars, p, ">")
      if p2 < 0 {
        break
      }

      let p3 = find_sub(chars, p2 + 1, "</w:t>")
      if p3 < 0 {
        i = p2 + 1
        continue
      }

      let text = @cor.slice_to_string(chars, p2 + 1, p3)
      if text != "" {
        out.push(@cor.Inline::Text(text))
      }
      i = p3 + 6
      continue
    }

    let p2 = find_sub(chars, p, ">")
    if p2 < 0 {
      break
    }
    if kind == 3 {
      out.push(@cor.Inline::Break)
    } else {
      out.push(@cor.Inline::Text("\t"))
    }
    i = p2 + 1
  }

  out
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
