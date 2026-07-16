///|
fn xlsx_append_sparse_sheet_view_blocks(
  blocks : Array[@core.CoreBlock],
  source_name : String,
  sheet : XlsxParsedSheetView,
) -> Unit {
  let heading_ref = xlsx_sheet_heading_source_ref_view(source_name, sheet)
  let heading = xlsx_trim_lowered_block_text(
    @core.make_block(Heading, sheet.sheet_name, source_ref=heading_ref),
  )
  heading.attrs.set("level", "2")
  blocks.push(heading)

  if sheet.is_empty {
    let raw = @core.make_block(
      Raw,
      "(empty sheet)",
      source_ref=xlsx_sheet_table_source_ref_view(source_name, sheet),
    )
    raw.attrs.set("raw_kind", "xlsx_empty_sheet")
    blocks.push(raw)
    return
  }

  let table = @core.make_block(
    Table,
    "table",
    source_ref=xlsx_sheet_table_source_ref_view(source_name, sheet),
  )
  table.attrs.set("header_rows", "1")
  table.attrs.set(
    "table_column_count",
    (sheet.max_col - sheet.min_col + 1).to_string(),
  )
  let table_ref = xlsx_sheet_table_source_ref_view(source_name, sheet)
  let mut cell_index = sheet.first_cell_index
  let cell_count = sheet.last_cell_index_exclusive
  let mut row = sheet.min_row
  while row <= sheet.max_row {
    if xlsx_should_skip_hidden_row(
        sheet.include_hidden_rows,
        sheet.hidden_rows,
        row,
      ) {
      row += 1
      continue
    }
    let row_block = @core.make_block(
      TableRow,
      "",
      source_ref=@core.source_ref_with_extra(
        table_ref,
        "row_index",
        row.to_string(),
      ),
    )
    row_block.attrs.set("sparse_cell_columns", "true")
    row_block.attrs.set(
      "declared_column_count",
      (sheet.max_col - sheet.min_col + 1).to_string(),
    )
    while cell_index < cell_count && sheet.cells[cell_index].row_index < row {
      cell_index += 1
    }
    let mut scan_index = cell_index
    while scan_index < cell_count && sheet.cells[scan_index].row_index == row {
      let cell = sheet.cells[scan_index]
      let source_ref = cell.source_ref
      let cell_block0 = match source_ref {
        Some(value) =>
          @core.make_block(TableCell, cell.display_text, source_ref=value)
        None =>
          @core.make_block_without_source_ref(TableCell, cell.display_text)
      }
      let cell_block = xlsx_apply_cell_rich_content(
        xlsx_trim_lowered_block_text(cell_block0),
        cell,
        source_ref,
      )
      row_block.children.push(
        @core.block_with_column_index(
          cell_block,
          cell.column_index - sheet.min_col + 1,
        ),
      )
      scan_index += 1
    }
    cell_index = scan_index
    table.children.push(row_block)
    row += 1
  }
  blocks.push(table)
  xlsx_append_sheet_comments_view(blocks, source_name, sheet)
}

///|
fn xlsx_trim_lowered_block_text(block : @core.CoreBlock) -> @core.CoreBlock {
  { ..block, text: block.text.trim().to_owned() }
}

///|
fn xlsx_append_region_spacer(
  blocks : Array[@core.CoreBlock],
  emitted : Bool,
  table : @core.CoreBlock,
) -> Unit {
  if !emitted {
    return
  }
  let spacer = @core.make_block(
    Raw,
    "",
    source_ref=table.source_ref.unwrap_or(@core.empty_source_ref()),
  )
  spacer.attrs.set("raw_kind", "markdown_literal")
  blocks.push(spacer)
}

///|
fn xlsx_sheet_table_region_source_ref(
  source_name : String,
  sheet : XlsxSheet,
  range_ref : String,
  relationship_id? : String? = None,
  table_part_name? : String? = None,
  table_name? : String? = None,
  display_name? : String? = None,
  column_names? : Array[String] = [],
) -> @core.SourceRef {
  let mut source_ref = @core.source_ref_with_extra(
    xlsx_sheet_table_source_ref(source_name, sheet),
    "cell_range",
    range_ref,
  )
  match relationship_id {
    Some(value) =>
      source_ref = @core.source_ref_with_extra(
        source_ref, "relationship_id", value,
      )
    None => ()
  }
  match table_part_name {
    Some(value) =>
      source_ref = @core.source_ref_with_extra(source_ref, "table_part", value)
    None => ()
  }
  match table_name {
    Some(value) =>
      source_ref = @core.source_ref_with_extra(source_ref, "table_name", value)
    None => ()
  }
  match display_name {
    Some(value) =>
      if value.trim() != "" {
        source_ref = @core.source_ref_with_extra(
          source_ref, "table_display_name", value,
        )
      }
    None => ()
  }
  if column_names.length() > 0 {
    source_ref = @core.source_ref_with_extra(
      source_ref,
      "table_columns",
      column_names.join("|"),
    )
  }
  source_ref
}

///|
fn xlsx_collect_residual_sheet_ranges(
  sheet : XlsxSheet,
  covered : Map[String, Bool],
) -> Array[(Int, Int, Int, Int)] {
  let buckets : Array[(Int, Int)] = []
  let mut row = sheet.min_row
  while row <= sheet.max_row {
    if xlsx_should_skip_hidden_row(
        sheet.include_hidden_rows,
        sheet.hidden_rows,
        row,
      ) {
      row += 1
      continue
    }
    let mut col = sheet.min_col
    let mut active_start = -1
    let mut active_end = -1
    while col <= sheet.max_col {
      if xlsx_residual_cell_exists(sheet, covered, row, col) {
        if active_start < 0 {
          active_start = col
        }
        active_end = col
      } else if active_start >= 0 {
        xlsx_push_residual_range_bucket(buckets, active_start, active_end)
        active_start = -1
        active_end = -1
      }
      col += 1
    }
    if active_start >= 0 {
      xlsx_push_residual_range_bucket(buckets, active_start, active_end)
    }
    row += 1
  }
  xlsx_residual_bucket_map_to_ranges(sheet, covered, buckets)
}

///|
fn xlsx_push_residual_range_bucket(
  buckets : Array[(Int, Int)],
  start_col : Int,
  end_col : Int,
) -> Unit {
  for bucket in buckets {
    if bucket.0 == start_col && bucket.1 == end_col {
      return
    }
  }
  buckets.push((start_col, end_col))
}

///|
fn xlsx_residual_bucket_map_to_ranges(
  sheet : XlsxSheet,
  covered : Map[String, Bool],
  buckets : Array[(Int, Int)],
) -> Array[(Int, Int, Int, Int)] {
  let keyed : Array[(Int, Int)] = []
  keyed.append(buckets[:])
  keyed.sort_by(fn(a, b) {
    let primary = a.0.compare(b.0)
    if primary != 0 {
      primary
    } else {
      a.1.compare(b.1)
    }
  })
  let ranges : Array[(Int, Int, Int, Int)] = []
  let mut i = 0
  while i < keyed.length() {
    let start_col = keyed[i].0
    let end_col = keyed[i].1
    let mut min_row = -1
    let mut max_row = -1
    let mut row = sheet.min_row
    while row <= sheet.max_row {
      if xlsx_should_skip_hidden_row(
          sheet.include_hidden_rows,
          sheet.hidden_rows,
          row,
        ) {
        row += 1
        continue
      }
      if xlsx_residual_range_row_has_content(
          sheet, covered, row, start_col, end_col,
        ) {
        if min_row < 0 {
          min_row = row
        }
        max_row = row
      }
      row += 1
    }
    if min_row > 0 && max_row >= min_row {
      ranges.push((min_row, start_col, max_row, end_col))
    }
    i += 1
  }
  ranges
}

///|
fn xlsx_residual_cell_exists(
  sheet : XlsxSheet,
  covered : Map[String, Bool],
  row : Int,
  col : Int,
) -> Bool {
  let key = xlsx_lookup_key(row, col)
  if covered.get(key) == Some(true) {
    return false
  }
  match sheet.cell_lookup.get(key) {
    Some(cell) =>
      !xlsx_is_blank_text(cell.display_text) || cell.formula_text is Some(_)
    None => false
  }
}

///|
fn xlsx_residual_range_row_has_content(
  sheet : XlsxSheet,
  covered : Map[String, Bool],
  row : Int,
  start_col : Int,
  end_col : Int,
) -> Bool {
  let mut col = start_col
  while col <= end_col {
    if xlsx_residual_cell_exists(sheet, covered, row, col) {
      return true
    }
    col += 1
  }
  false
}

///|
fn xlsx_residual_region_display_name(
  sheet : XlsxSheet,
  residual_index : Int,
  residual_count : Int,
) -> String {
  if residual_count <= 1 {
    sheet.sheet_name
  } else {
    sheet.sheet_name + " Region " + (residual_index + 1).to_string()
  }
}

///|
fn xlsx_range_ref_from_bounds(
  min_row : Int,
  min_col : Int,
  max_row : Int,
  max_col : Int,
) -> String {
  xlsx_rc_to_cell_ref(min_row, min_col) +
  ":" +
  xlsx_rc_to_cell_ref(max_row, max_col)
}

///|
fn xlsx_should_skip_hidden_row(
  include_hidden_rows : Bool,
  hidden_rows : Map[Int, Bool],
  row_index : Int,
) -> Bool {
  !include_hidden_rows && xlsx_row_is_hidden(hidden_rows, row_index)
}

///|
fn xlsx_should_skip_merged_placeholder_cell(
  merge_range : String?,
  row_index : Int,
  column_index : Int,
) -> Bool {
  match merge_range {
    Some(range_ref) =>
      match xlsx_parse_range_ref(range_ref) {
        Some((r1, c1, _, _)) => row_index != r1 || column_index != c1
        None => false
      }
    None => false
  }
}

///|
fn xlsx_apply_merge_attrs(
  cell_block : @core.CoreBlock,
  merge_range : String?,
  row_index : Int,
  column_index : Int,
) -> Unit {
  match merge_range {
    Some(range_ref) =>
      match xlsx_parse_range_ref(range_ref) {
        Some((r1, c1, r2, c2)) =>
          if row_index == r1 && column_index == c1 {
            let rowspan = r2 - r1 + 1
            let colspan = c2 - c1 + 1
            if rowspan > 1 {
              cell_block.attrs.set("rowspan", rowspan.to_string())
            }
            if colspan > 1 {
              cell_block.attrs.set("colspan", colspan.to_string())
            }
            cell_block.attrs.set("merge_range", range_ref)
          }
        None => ()
      }
    None => ()
  }
}

///|
fn xlsx_apply_cell_rich_content(
  cell_block : @core.CoreBlock,
  cell : XlsxCell,
  source_ref : @core.SourceRef?,
) -> @core.CoreBlock {
  match cell.hyperlink_target {
    Some(target) =>
      if cell.display_text.trim() != "" && target.trim() != "" {
        let link_ref = source_ref.map(value => {
          match cell.hyperlink_relationship_id {
            Some(rel_id) =>
              @core.source_ref_with_extra(value, "relationship_id", rel_id)
            None => value
          }
        })
        return @core.block_with_rich_inlines(
          cell_block,
          Some([
            match link_ref {
              Some(value) =>
                @core.make_inline_link(
                  cell.display_text,
                  target,
                  source_ref=value,
                )
              None =>
                @core.make_inline_link_without_source_ref(
                  cell.display_text,
                  target,
                )
            },
          ]),
        )
      }
    None => ()
  }
  cell_block
}
