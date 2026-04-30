///|
fn empty_styles() -> DocxStyles {
  { heading_by_style: {}, name_by_style: {} }
}

///|
fn heading_level_of(
  styles : DocxStyles,
  style_id : String,
  max_heading : Int,
) -> Int {
  match styles.heading_by_style.get(style_id) {
    Some(level) => {
      profile_style_lookup(true)
      if level < 1 {
        0
      } else if level > max_heading {
        max_heading
      } else {
        level
      }
    }
    None => {
      profile_style_lookup(false)
      0
    }
  }
}

///|
/// 读取某个 styleId 对应的样式名（若存在）
fn style_name_of(styles : DocxStyles, style_id : String) -> String? {
  let name = styles.name_by_style.get(style_id)
  profile_style_lookup(name is Some(_))
  name
}

///|
/// 解析 word/styles.xml，建立：
/// - styleId -> heading level
/// - styleId -> style name
fn parse_styles_xml(xml : String) -> DocxStyles {
  profile_styles_parse_call()
  let heading_by_style : Map[String, Int] = {}
  let name_by_style : Map[String, String] = {}

  let chars = xml.to_array()
  let mut i = 0

  while true {
    let s1 = find_style_open(chars, i)
    if s1 < 0 {
      break
    }
    profile_style_node_seen()

    let s2 = find_sub_for_styles(chars, s1, ">")
    if s2 < 0 {
      break
    }

    let s3 = find_sub_for_styles(chars, s2 + 1, "</w:style>")
    if s3 < 0 {
      break
    }

    let open_tag = profiled_slice_to_string(chars, s1, s2 + 1)

    let is_paragraph = open_tag.contains("w:type=\"paragraph\"") ||
      open_tag.contains("w:type='paragraph'")

    if is_paragraph {
      let inner = profiled_slice_to_string(chars, s2 + 1, s3)
      match read_attr_value_in_tag(open_tag, "w:styleId") {
        Some(style_id) => {
          match read_style_name(inner) {
            Some(name) => name_by_style[style_id] = name
            None => ()
          }

          let level = detect_heading_level(style_id, inner)
          if level > 0 {
            heading_by_style[style_id] = level
          }
        }
        None => ()
      }
    }

    // "</w:style>" 长度 10
    i = s3 + 10
  }

  { heading_by_style, name_by_style }
}

///|
fn find_style_open(chars : Array[Char], from : Int) -> Int {
  let mut i = from
  while true {
    let p = find_sub_for_styles(chars, i, "<w:style")
    if p < 0 {
      return -1
    }

    if p + 8 < chars.length() && is_delim_for_tag(chars[p + 8]) {
      return p
    }

    i = p + 8
  }
  -1
}

///|
fn find_sub_for_styles(chars : Array[Char], from : Int, pat : String) -> Int {
  let search_len = if from < chars.length() { chars.length() - from } else { 0 }
  profile_styles_tag_scan_call(search_len)
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
fn detect_heading_level(style_id : String, inner : String) -> Int {
  // 先兼容 styleId
  let by_id = heading_level_from_name(style_id)
  if by_id > 0 {
    return by_id
  }

  // 再看样式名
  match read_style_name(inner) {
    Some(name) => {
      let by_name = heading_level_from_name(name)
      if by_name > 0 {
        return by_name
      }
    }
    None => ()
  }

  // 最后再兜底 outlineLvl（0-based）
  match read_attr_value(inner, "<w:outlineLvl w:val=\"") {
    Some(v) => {
      let n = parse_int_default(v, -1)
      if n >= 0 && n <= 8 {
        return n + 1
      }
    }
    None => ()
  }

  0
}

///|
/// 读取样式名，兼容双引号 / 单引号属性
fn read_style_name(inner : String) -> String? {
  match read_attr_value(inner, "<w:name w:val=\"") {
    Some(name) => Some(name)
    None => read_attr_value(inner, "<w:name w:val='")
  }
}

///|
fn heading_level_from_name(s : String) -> Int {
  let t = ascii_lower(s)

  if t == "heading1" || t == "heading 1" || t == "1" || t == "2" {
    1
  } else if t == "heading2" || t == "heading 2" || t == "3" {
    2
  } else if t == "heading3" || t == "heading 3" || t == "4" {
    3
  } else if t == "heading4" || t == "heading 4" || t == "5" {
    4
  } else if t == "heading5" || t == "heading 5" || t == "6" {
    5
  } else if t == "heading6" || t == "heading 6" || t == "7" {
    6
  } else {
    0
  }
}
