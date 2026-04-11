///|
fn empty_numbering() -> DocxNumbering {
  { num_to_abs: {}, fmt_by_abs_ilvl: {} }
}

///|
fn parse_numbering_xml(xml : String) -> DocxNumbering {
  let num_to_abs : Map[Int, Int] = {}
  let fmt_by_abs_ilvl : Map[String, String] = {}

  parse_abstract_nums(xml, fmt_by_abs_ilvl)
  parse_nums(xml, num_to_abs)

  { num_to_abs, fmt_by_abs_ilvl }
}

///|
fn read_paragraph_list_info(p_xml : String) -> ParagraphListInfo? {
  let ilvl = match read_attr_value(p_xml, "<w:ilvl w:val=\"") {
    Some(v) => parse_int_default(v, -1)
    None => -1
  }

  let num_id = match read_attr_value(p_xml, "<w:numId w:val=\"") {
    Some(v) => parse_int_default(v, -1)
    None => -1
  }

  if ilvl >= 0 && num_id >= 0 {
    Some({ num_id, ilvl })
  } else {
    None
  }
}

///|
fn resolve_list_kind(
  numbering : DocxNumbering,
  info : ParagraphListInfo,
) -> ListKind? {
  match numbering.num_to_abs.get(info.num_id) {
    Some(abs_id) =>
      match numbering.fmt_by_abs_ilvl.get(abs_ilvl_key(abs_id, info.ilvl)) {
        Some(fmt) => {
          let t = ascii_lower(fmt)
          if t == "bullet" {
            Some(ListKind::Bullet)
          } else {
            Some(ListKind::Ordered)
          }
        }
        None => None
      }
    None => None
  }
}

///|
fn abs_ilvl_key(abs_id : Int, ilvl : Int) -> String {
  abs_id.to_string() + "#" + ilvl.to_string()
}

///|
fn parse_abstract_nums(
  xml : String,
  fmt_by_abs_ilvl : Map[String, String],
) -> Unit {
  let chars = xml.to_array()
  let mut i = 0

  while true {
    let a1 = find_sub(chars, i, "<w:abstractNum")
    if a1 < 0 {
      break
    }

    let a2 = find_sub(chars, a1, ">")
    if a2 < 0 {
      break
    }

    let a3 = find_sub(chars, a2 + 1, "</w:abstractNum>")
    if a3 < 0 {
      break
    }

    let open_tag = @cor.slice_to_string(chars, a1, a2 + 1)
    let inner = @cor.slice_to_string(chars, a2 + 1, a3)

    let abs_id = match read_attr_value_in_tag(open_tag, "w:abstractNumId") {
      Some(v) => parse_int_default(v, -1)
      None => -1
    }

    if abs_id >= 0 {
      parse_lvls_for_abstract_num(abs_id, inner, fmt_by_abs_ilvl)
    }

    i = a3 + 16
  }
}

///|
fn parse_lvls_for_abstract_num(
  abs_id : Int,
  xml : String,
  fmt_by_abs_ilvl : Map[String, String],
) -> Unit {
  let chars = xml.to_array()
  let mut i = 0

  while true {
    let l1 = find_sub(chars, i, "<w:lvl")
    if l1 < 0 {
      break
    }

    let l2 = find_sub(chars, l1, ">")
    if l2 < 0 {
      break
    }

    let l3 = find_sub(chars, l2 + 1, "</w:lvl>")
    if l3 < 0 {
      break
    }

    let open_tag = @cor.slice_to_string(chars, l1, l2 + 1)
    let inner = @cor.slice_to_string(chars, l2 + 1, l3)

    let ilvl = match read_attr_value_in_tag(open_tag, "w:ilvl") {
      Some(v) => parse_int_default(v, -1)
      None => -1
    }

    if ilvl >= 0 {
      match read_attr_value(inner, "<w:numFmt w:val=\"") {
        Some(fmt) => fmt_by_abs_ilvl[abs_ilvl_key(abs_id, ilvl)] = fmt
        None => ()
      }
    }

    i = l3 + 8
  }
}

///|
fn parse_nums(xml : String, num_to_abs : Map[Int, Int]) -> Unit {
  let chars = xml.to_array()
  let mut i = 0

  while true {
    let n1 = find_sub(chars, i, "<w:num ")
    let n1b = find_sub(chars, i, "<w:num>")
    let n = if n1 >= 0 && n1b >= 0 {
      if n1 < n1b {
        n1
      } else {
        n1b
      }
    } else if n1 >= 0 {
      n1
    } else {
      n1b
    }

    if n < 0 {
      break
    }

    let n2 = find_sub(chars, n, ">")
    if n2 < 0 {
      break
    }

    let n3 = find_sub(chars, n2 + 1, "</w:num>")
    if n3 < 0 {
      break
    }

    let open_tag = @cor.slice_to_string(chars, n, n2 + 1)
    let inner = @cor.slice_to_string(chars, n2 + 1, n3)

    let num_id = match read_attr_value_in_tag(open_tag, "w:numId") {
      Some(v) => parse_int_default(v, -1)
      None => -1
    }

    let abs_id = match read_attr_value(inner, "<w:abstractNumId w:val=\"") {
      Some(v) => parse_int_default(v, -1)
      None => -1
    }

    if num_id >= 0 && abs_id >= 0 {
      num_to_abs[num_id] = abs_id
    }

    i = n3 + 8
  }
}
