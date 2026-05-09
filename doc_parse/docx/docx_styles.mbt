///|
fn parse_docx_style_type(raw : String?) -> DocxStyleType {
  match raw {
    Some(value) =>
      match ascii_lower(value.trim().to_owned()) {
        "paragraph" => DocxStyleType::Paragraph
        "character" => DocxStyleType::Character
        "table" => DocxStyleType::Table
        "numbering" => DocxStyleType::Numbering
        _ => DocxStyleType::Unknown
      }
    None => DocxStyleType::Unknown
  }
}

///|
fn read_docx_style_based_on(inner : String) -> String? {
  match read_attr_value(inner, "<w:basedOn w:val=\"") {
    Some(v) => Some(v)
    None => read_attr_value(inner, "<w:basedOn w:val='")
  }
}

///|
fn docx_heading_level_from_name(s : String) -> Int {
  let raw = s.trim().to_owned()
  let t = ascii_lower(raw)

  if t == "heading1" || t == "heading 1" {
    1
  } else if t == "heading2" || t == "heading 2" {
    2
  } else if t == "heading3" || t == "heading 3" {
    3
  } else if t == "heading4" || t == "heading 4" {
    4
  } else if t == "heading5" || t == "heading 5" {
    5
  } else if t == "heading6" || t == "heading 6" {
    6
  } else {
    0
  }
}

///|
fn detect_docx_style_heading_level(style_id : String, inner : String) -> Int? {
  let by_id = docx_heading_level_from_name(style_id)
  if by_id > 0 {
    return Some(by_id)
  }

  match read_docx_style_display_name(inner) {
    Some(name) => {
      let by_name = docx_heading_level_from_name(name)
      if by_name > 0 {
        return Some(by_name)
      }
    }
    None => ()
  }

  match read_attr_value(inner, "<w:outlineLvl w:val=\"") {
    Some(v) => {
      let n = parse_int_default(v, -1)
      if n >= 0 && n <= 8 {
        return Some(n + 1)
      }
    }
    None => ()
  }

  None
}

///|
fn read_docx_style_display_name(inner : String) -> String? {
  match read_attr_value(inner, "<w:name w:val=\"") {
    Some(name) => Some(name)
    None => read_attr_value(inner, "<w:name w:val='")
  }
}

///|
fn parse_style_linked_numbering(inner : String) -> DocxNumberingRef? {
  let chars = inner.to_array()
  let ppr_open = find_sub(chars, 0, "<w:pPr")
  if ppr_open < 0 {
    return None
  }
  let ppr_open_end = find_sub(chars, ppr_open, ">")
  if ppr_open_end < 0 {
    return None
  }
  let ppr_close = find_sub(chars, ppr_open_end + 1, "</w:pPr>")
  if ppr_close < 0 || ppr_close <= ppr_open_end {
    return None
  }
  let ppr = @cor.slice_to_string(chars, ppr_open_end + 1, ppr_close)
  read_numbering_ref_from_xml(ppr, empty_docx_numbering())
}

///|
fn parse_docx_styles_xml(xml : String) -> DocxStyles {
  if xml.trim() == "" {
    return empty_docx_styles()
  }

  let styles : Array[DocxStyle] = []
  let chars = xml.to_array()
  let mut i = 0

  while true {
    let s1 = find_exact_open_tag(chars, i, "<w:style".to_array())
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
    match read_attr_value_in_tag(open_tag, "w:styleId") {
      Some(style_id) =>
        styles.push({
          style_id,
          name: read_docx_style_display_name(inner),
          style_type: parse_docx_style_type(
            read_attr_value_in_tag(open_tag, "w:type"),
          ),
          based_on: read_docx_style_based_on(inner),
          raw_heading_level: detect_docx_style_heading_level(style_id, inner),
          linked_numbering: parse_style_linked_numbering(inner),
        })
      None => ()
    }

    i = s3 + 10
  }

  { styles, }
}

///|
fn docx_style_exists(styles : DocxStyles, style_id : String) -> Bool {
  for style in styles.styles {
    if style.style_id == style_id {
      return true
    }
  }
  false
}
