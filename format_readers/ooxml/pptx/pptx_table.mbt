///|
fn parse_table(
  ctx : PptxSourceParseContext,
  part_name : String,
  frame_xml : Bytes,
  geometry : PptxGeometry?,
  source_key : PptxSourceKey,
) -> PptxTable raise {
  let rows : Array[PptxTableRow] = []
  match find_element_inner(frame_xml, "<a:tbl", "</a:tbl>") {
    Some(tbl) => {
      let mut pos = 0
      let mut row_index = 0
      let cell_count : Ref[Int] = { val: 0 }
      let text_run_count : Ref[Int] = { val: 0 }
      let output_cell_count : Ref[Int] = { val: 0 }
      while true {
        let r0 = find_bytes(tbl, pat("<a:tr"), pos)
        match r0 {
          None => break
          Some(start) =>
            match slice_full_element(tbl, start, "a:tr") {
              Some((row_xml, next_pos)) => {
                rows.push(
                  parse_table_row(
                    ctx,
                    part_name,
                    row_xml,
                    row_index,
                    source_key.node_key,
                    cell_count,
                    text_run_count,
                    output_cell_count,
                  ),
                )
                row_index += 1
                pos = next_pos
              }
              None => break
            }
        }
      }
    }
    None => ()
  }
  { rows, geometry, source_key }
}

///|
fn parse_table_row(
  ctx : PptxSourceParseContext,
  part_name : String,
  row_xml : Bytes,
  row_index : Int,
  parent_key : String,
  cell_count : Ref[Int],
  text_run_count : Ref[Int],
  output_cell_count : Ref[Int],
) -> PptxTableRow raise {
  let cells : Array[PptxTableCell] = []
  let mut pos = 0
  let mut col_index = 0
  while true {
    let c0 = find_bytes(row_xml, pat("<a:tc"), pos)
    match c0 {
      None => break
      Some(start) =>
        match slice_full_element(row_xml, start, "a:tc") {
          Some((cell_xml, next_pos)) => {
            cell_count.val += 1
            if cell_count.val > ctx.budget.max_table_cells {
              if cell_count.val == ctx.budget.max_table_cells + 1 {
                ctx.warnings.push(
                  pptx_warning(
                    PptxWarningKind::OverBudget,
                    PptxWarningSeverity::Warning,
                    part_name,
                    parent_key,
                    None,
                    None,
                    "pptx table cell budget exceeded",
                  ),
                )
              }
              pos = next_pos
              continue
            }
            let key = parent_key +
              "/row-" +
              row_index.to_string() +
              "/cell-" +
              col_index.to_string()
            let tag_end = find_bytes(cell_xml, pat(">"), 0).unwrap_or(-1)
            let tag = if tag_end >= 0 {
              cell_xml[0:tag_end + 1].to_owned()
            } else {
              Bytes::from_array([])
            }
            let grid_span = match
              read_attr_value_in_tag_bytes(tag, "gridSpan") {
              Some(v) =>
                Some(
                  bounded_table_grid_span(
                    ctx,
                    part_name,
                    key,
                    parse_int_or_zero(Some(v)),
                  ),
                )
              None => None
            }
            let row_span = match read_attr_value_in_tag_bytes(tag, "rowSpan") {
              Some(v) =>
                Some(
                  bounded_table_row_span(
                    ctx,
                    part_name,
                    key,
                    parse_int_or_zero(Some(v)),
                  ),
                )
              None => None
            }
            let span = grid_span.unwrap_or(1)
            if col_index > ctx.budget.max_table_row_output_cells - span ||
              output_cell_count.val > ctx.budget.max_table_output_cells - span {
              push_over_budget_warning(
                ctx,
                part_name,
                key,
                None,
                None,
                "pptx table span expansion budget exceeded",
              )
              pos = next_pos
              continue
            }
            let merge_hint = if read_bool_attr(tag, "hMerge") {
              Some("hMerge")
            } else if read_bool_attr(tag, "vMerge") {
              Some("vMerge")
            } else {
              None
            }
            let estimated_runs = count_table_text_runs(cell_xml)
            let paragraphs = if text_run_count.val + estimated_runs >
              ctx.budget.max_table_text_runs {
              if text_run_count.val <= ctx.budget.max_table_text_runs {
                push_over_budget_warning(
                  ctx,
                  part_name,
                  key,
                  None,
                  None,
                  "pptx table text-run budget exceeded",
                )
              }
              text_run_count.val = ctx.budget.max_table_text_runs + 1
              []
            } else {
              text_run_count.val += estimated_runs
              match find_element_inner(cell_xml, "<a:txBody", "</a:txBody>") {
                Some(body) => parse_paragraphs(ctx, part_name, body, key)
                None => []
              }
            }
            cells.push({
              row_index,
              column_index: col_index,
              paragraphs,
              grid_span,
              row_span,
              merge_hint,
              source_key: pptx_source_key(part_name, key),
            })
            col_index += span
            output_cell_count.val += span
            pos = next_pos
          }
          None => break
        }
    }
  }
  {
    row_index,
    cells,
    source_key: pptx_source_key(
      part_name,
      parent_key + "/row-" + row_index.to_string(),
    ),
  }
}

///|
fn bounded_table_grid_span(
  ctx : PptxSourceParseContext,
  part_name : String,
  node_key : String,
  raw_span : Int,
) -> Int {
  let span = if raw_span < 1 { 1 } else { raw_span }
  if span > ctx.budget.max_table_grid_span {
    push_over_budget_warning(
      ctx,
      part_name,
      node_key,
      None,
      None,
      "pptx table gridSpan truncated at hard cap: " +
      ctx.budget.max_table_grid_span.to_string(),
    )
    ctx.budget.max_table_grid_span
  } else {
    span
  }
}

///|
fn bounded_table_row_span(
  ctx : PptxSourceParseContext,
  part_name : String,
  node_key : String,
  raw_span : Int,
) -> Int {
  let span = if raw_span < 1 { 1 } else { raw_span }
  if span > ctx.budget.max_table_grid_span {
    push_over_budget_warning(
      ctx,
      part_name,
      node_key,
      None,
      None,
      "pptx table rowSpan truncated at hard cap: " +
      ctx.budget.max_table_grid_span.to_string(),
    )
    ctx.budget.max_table_grid_span
  } else {
    span
  }
}

///|
fn count_table_text_runs(cell_xml : Bytes) -> Int {
  count_bytes_occurrences(cell_xml, pat("<a:r")) +
  count_bytes_occurrences(cell_xml, pat("<a:br")) +
  count_bytes_occurrences(cell_xml, pat("<a:fld"))
}

///|
fn count_bytes_occurrences(xml : Bytes, pattern : Bytes) -> Int {
  let mut count = 0
  let mut pos = 0
  while true {
    match find_bytes(xml, pattern, pos) {
      Some(i) => {
        count += 1
        pos = i + pattern.length()
      }
      None => break
    }
  }
  count
}

///|
fn read_bool_attr(tag : Bytes, attr : String) -> Bool raise {
  match read_attr_value_in_tag_bytes(tag, attr) {
    Some(v) => {
      let l = v.to_lower()
      l == "1" || l == "true"
    }
    None => false
  }
}
