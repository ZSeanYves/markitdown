///|
fn parse_docx_numbering_xml(xml : String) -> DocxNumbering {
  if xml.trim() == "" {
    return empty_docx_numbering()
  }

  let abstract_numbers = parse_docx_abstract_numbers(xml)
  let numbering_instances = parse_docx_numbering_instances(xml)
  { abstract_numbers, numbering_instances }
}

///|
fn parse_docx_abstract_numbers(xml : String) -> Array[DocxAbstractNumbering] {
  let out : Array[DocxAbstractNumbering] = []
  let chars = xml.to_array()
  let mut i = 0

  while true {
    let a1 = find_exact_open_tag(chars, i, "<w:abstractNum".to_array())
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
    let abstract_num_id = match
      read_attr_value_in_tag(open_tag, "w:abstractNumId") {
      Some(v) => parse_int_default(v, -1)
      None => -1
    }
    if abstract_num_id >= 0 {
      out.push({ abstract_num_id, levels: parse_docx_numbering_levels(inner) })
    }

    i = a3 + 16
  }

  out
}

///|
fn parse_docx_numbering_levels(xml : String) -> Array[DocxNumberingLevel] {
  let out : Array[DocxNumberingLevel] = []
  let chars = xml.to_array()
  let mut i = 0

  while true {
    let l1 = find_exact_open_tag(chars, i, "<w:lvl".to_array())
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
      out.push({
        ilvl,
        num_format: match read_attr_value(inner, "<w:numFmt w:val=\"") {
          Some(v) => Some(v)
          None => read_attr_value(inner, "<w:numFmt w:val='")
        },
      })
    }

    i = l3 + 8
  }

  out
}

///|
fn parse_docx_numbering_instances(xml : String) -> Array[DocxNumberingInstance] {
  let out : Array[DocxNumberingInstance] = []
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
    let abstract_num_id = match
      read_attr_value(inner, "<w:abstractNumId w:val=\"") {
      Some(v) => parse_int_default(v, -1)
      None =>
        parse_int_default(
          read_attr_value(inner, "<w:abstractNumId w:val='").unwrap_or(""),
          -1,
        )
    }
    if num_id >= 0 && abstract_num_id >= 0 {
      out.push({ num_id, abstract_num_id })
    }

    i = n3 + 8
  }

  out
}

///|
fn read_numbering_ref_from_xml(
  p_xml : String,
  numbering : DocxNumbering,
) -> DocxNumberingRef? {
  let ilvl = match read_attr_value(p_xml, "<w:ilvl w:val=\"") {
    Some(v) => parse_int_default(v, -1)
    None =>
      parse_int_default(
        read_attr_value(p_xml, "<w:ilvl w:val='").unwrap_or(""),
        -1,
      )
  }
  let num_id = match read_attr_value(p_xml, "<w:numId w:val=\"") {
    Some(v) => parse_int_default(v, -1)
    None =>
      parse_int_default(
        read_attr_value(p_xml, "<w:numId w:val='").unwrap_or(""),
        -1,
      )
  }

  if ilvl >= 0 && num_id >= 0 {
    Some({
      num_id,
      ilvl,
      num_format: resolve_docx_num_format(numbering, num_id, ilvl),
    })
  } else {
    None
  }
}

///|
fn resolve_docx_num_format(
  numbering : DocxNumbering,
  num_id : Int,
  ilvl : Int,
) -> String? {
  let mut abstract_num_id = -1
  for item in numbering.numbering_instances {
    if item.num_id == num_id {
      abstract_num_id = item.abstract_num_id
      break
    }
  }
  if abstract_num_id < 0 {
    return None
  }

  for abstract_num in numbering.abstract_numbers {
    if abstract_num.abstract_num_id != abstract_num_id {
      continue
    }
    for level in abstract_num.levels {
      if level.ilvl == ilvl {
        return level.num_format
      }
    }
  }
  None
}

///|
fn docx_numbering_instance_exists(
  numbering : DocxNumbering,
  num_id : Int,
) -> Bool {
  for item in numbering.numbering_instances {
    if item.num_id == num_id {
      return true
    }
  }
  false
}
