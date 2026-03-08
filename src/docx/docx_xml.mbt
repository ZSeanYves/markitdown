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
fn collect_wt_text(block : String) -> String {
  let chars = block.to_array()
  let mut i = 0
  let mut out = ""

  while true {
    let p1 = find_wt_open(chars, i)
    if p1 < 0 {
      break
    }

    let p2 = find_sub(chars, p1, ">")
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
  }

  @cor.trim_string(out)
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
