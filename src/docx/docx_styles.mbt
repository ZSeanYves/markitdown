///|
priv struct DocxStyles {
  heading_by_style : Map[String, Int]
  name_by_style : Map[String, String]
}

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
    Some(level) =>
      if level < 1 {
        0
      } else if level > max_heading {
        max_heading
      } else {
        level
      }
    None => 0
  }
}

///|
/// 读取某个 styleId 对应的样式名（若存在）
fn style_name_of(styles : DocxStyles, style_id : String) -> String? {
  styles.name_by_style.get(style_id)
}

///|
/// 解析 word/styles.xml，建立：
/// - styleId -> heading level
/// - styleId -> style name
fn parse_styles_xml(xml : String) -> DocxStyles {
  let heading_by_style : Map[String, Int] = {}
  let name_by_style : Map[String, String] = {}

  let chars = xml.to_array()
  let mut i = 0

  while true {
    let s1 = find_sub(chars, i, "<w:style")
    if s1 < 0 {
      break
    }

    let s2 = find_sub(chars, s1, ">")
    if s2 < 0 {
      break
    }

    let s3 = find_sub(chars, s2 + 1, "</w:style>")
    if s3 < 0 {
      break
    }

    let open_tag = @cor.slice_to_string(chars, s1, s2 + 1)
    let inner = @cor.slice_to_string(chars, s2 + 1, s3)

    let is_paragraph = open_tag.contains("w:type=\"paragraph\"") ||
      open_tag.contains("w:type='paragraph'")

    if is_paragraph {
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
