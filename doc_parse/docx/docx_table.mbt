///|
fn parse_docx_grid_span(tc_xml : String) -> Int? {
  match read_attr_value(tc_xml, "<w:gridSpan w:val=\"") {
    Some(v) => {
      let n = parse_int_default(v, -1)
      if n > 0 {
        Some(n)
      } else {
        None
      }
    }
    None => {
      let n = parse_int_default(
        read_attr_value(tc_xml, "<w:gridSpan w:val='").unwrap_or(""),
        -1,
      )
      if n > 0 {
        Some(n)
      } else {
        None
      }
    }
  }
}

///|
fn parse_docx_vertical_merge(tc_xml : String) -> String? {
  match read_attr_value(tc_xml, "<w:vMerge w:val=\"") {
    Some(v) => Some(v)
    None =>
      match read_attr_value(tc_xml, "<w:vMerge w:val='") {
        Some(v) => Some(v)
        None =>
          if tc_xml.contains("<w:vMerge") {
            Some("continue")
          } else {
            None
          }
      }
  }
}

///|
fn parse_docx_table_cell(
  tc_inner : String,
  ctx : DocxPartParseContext,
  styles : DocxStyles,
  numbering : DocxNumbering,
) -> DocxTableCell {
  {
    body_blocks: parse_docx_body_blocks(tc_inner, ctx, styles, numbering),
    grid_span: parse_docx_grid_span(tc_inner),
    vertical_merge: parse_docx_vertical_merge(tc_inner),
  }
}

///|
fn parse_docx_table(
  tbl_xml : String,
  ctx : DocxPartParseContext,
  styles : DocxStyles,
  numbering : DocxNumbering,
) -> DocxTable {
  let chars = strip_docx_deleted_revision_xml(tbl_xml).to_array()
  let rows : Array[DocxTableRow] = []
  let mut i = 0

  while true {
    let tr1 = find_exact_open_tag(chars, i, wtr_open_tag_chars)
    if tr1 < 0 {
      break
    }
    let tr2 = find_sub(chars, tr1, ">")
    if tr2 < 0 {
      break
    }
    let tr3 = find_matching_docx_element_close(
      chars, tr1, wtr_open_tag_chars, wtr_close_tag_chars,
    )
    if tr3 < 0 {
      break
    }

    let tr_inner = @cor.slice_to_string(chars, tr2 + 1, tr3)
    let tr_chars = tr_inner.to_array()
    let cells : Array[DocxTableCell] = []
    let mut j = 0

    while true {
      let tc1 = find_exact_open_tag(tr_chars, j, wtc_open_tag_chars)
      if tc1 < 0 {
        break
      }
      let tc2 = find_sub(tr_chars, tc1, ">")
      if tc2 < 0 {
        break
      }
      let tc3 = find_matching_docx_element_close(
        tr_chars, tc1, wtc_open_tag_chars, wtc_close_tag_chars,
      )
      if tc3 < 0 {
        break
      }

      let tc_inner = @cor.slice_to_string(tr_chars, tc2 + 1, tc3)
      cells.push(parse_docx_table_cell(tc_inner, ctx, styles, numbering))
      j = tc3 + wtc_close_tag_chars.length()
    }

    if cells.length() > 0 {
      rows.push({ cells, })
    }
    i = tr3 + wtr_close_tag_chars.length()
  }

  { rows, }
}
