///|
fn parse_pptx_table_from_frame(
  frame_xml : Bytes,
  ctx : PptxShapeParseContext,
  object_ref : String?,
) -> PptxTable? raise {
  if !contains_bytes(frame_xml, pat("<a:tbl")) {
    return None
  }

  let rows = parse_pptx_table_rows(frame_xml, ctx, object_ref)
  if rows.length() == 0 {
    return None
  }

  Some({ object_ref, rows })
}

///|
fn parse_pptx_table_rows(
  frame_xml : Bytes,
  ctx : PptxShapeParseContext,
  object_ref : String?,
) -> Array[PptxTableRow] raise {
  let open_tbl = pat("<a:tbl")
  let close_tbl = pat("</a:tbl>")
  let gt_pat = pat(">")
  let tbl0 = find_bytes(frame_xml, open_tbl, 0)
  match tbl0 {
    None => []
    Some(i0) =>
      match find_bytes(frame_xml, gt_pat, i0) {
        None => []
        Some(gt0) =>
          match find_bytes(frame_xml, close_tbl, gt0 + 1) {
            None => []
            Some(end) =>
              parse_pptx_table_rows_inner(
                frame_xml[gt0 + 1:end].to_owned(),
                ctx,
                object_ref,
              )
          }
      }
  }
}

///|
fn parse_pptx_table_rows_inner(
  inner : Bytes,
  ctx : PptxShapeParseContext,
  object_ref : String?,
) -> Array[PptxTableRow] raise {
  let out : Array[PptxTableRow] = []
  let open_tr = pat("<a:tr")
  let close_tr = pat("</a:tr>")
  let gt_pat = pat(">")

  let mut pos = 0
  let mut row_index = 0
  while true {
    let p0 = find_bytes(inner, open_tr, pos)
    match p0 {
      None => break
      Some(i0) =>
        match find_bytes(inner, gt_pat, i0) {
          None => break
          Some(gt0) =>
            match find_bytes(inner, close_tr, gt0 + 1) {
              None => break
              Some(end) => {
                out.push({
                  row_index,
                  cells: parse_pptx_table_cells(
                    inner[gt0 + 1:end].to_owned(),
                    ctx,
                    object_ref,
                    row_index,
                  ),
                })
                row_index += 1
                pos = end + close_tr.length()
              }
            }
        }
    }
  }

  out
}

///|
fn parse_pptx_table_cells(
  row_xml : Bytes,
  ctx : PptxShapeParseContext,
  object_ref : String?,
  row_index : Int,
) -> Array[PptxTableCell] raise {
  let out : Array[PptxTableCell] = []
  let open_tc = pat("<a:tc")
  let close_tc = pat("</a:tc>")
  let gt_pat = pat(">")

  let mut pos = 0
  let mut column_index = 0
  while true {
    let p0 = find_bytes(row_xml, open_tc, pos)
    match p0 {
      None => break
      Some(i0) =>
        match find_bytes(row_xml, gt_pat, i0) {
          None => break
          Some(gt0) =>
            match find_bytes(row_xml, close_tc, gt0 + 1) {
              None => break
              Some(end) => {
                out.push({
                  row_index,
                  column_index,
                  paragraphs: parse_pptx_text_paragraphs_from_a_body(
                    row_xml[gt0 + 1:end].to_owned(),
                    ctx,
                    object_ref,
                  ),
                })
                column_index += 1
                pos = end + close_tc.length()
              }
            }
        }
    }
  }

  out
}

///|
fn collect_hyperlinks_from_table(table : PptxTable) -> Array[PptxHyperlink] {
  let out : Array[PptxHyperlink] = []
  for row in table.rows {
    for cell in row.cells {
      for link in collect_hyperlinks_from_paragraphs(cell.paragraphs) {
        out.push(link)
      }
    }
  }
  out
}
