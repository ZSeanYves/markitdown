///|
fn pdf_native_source_ref_from_json_object(
  payload : Map[String, @core.JsonValue],
) -> @core.SourceRef? {
  let file_id = match payload.get("file_id") {
    Some(@core.JsonValue::String(value)) => Some(value)
    _ => None
  }
  let format = match payload.get("format") {
    Some(@core.JsonValue::String(value)) => Some(value)
    _ => None
  }
  let page = match payload.get("page") {
    Some(@core.JsonValue::Number(value)) =>
      Some(@string.parse_int(value) catch { _ => return None })
    _ => None
  }
  let line_start = match payload.get("line_start") {
    Some(@core.JsonValue::Number(value)) =>
      Some(@string.parse_int(value) catch { _ => return None })
    _ => None
  }
  let line_end = match payload.get("line_end") {
    Some(@core.JsonValue::Number(value)) =>
      Some(@string.parse_int(value) catch { _ => return None })
    _ => None
  }
  let bbox = match payload.get("bbox") {
    Some(@core.JsonValue::Object(bbox_payload)) =>
      match pdf_native_bbox_from_core_json_object(bbox_payload) {
        Some(value) => Some(value)
        None => return None
      }
    _ => None
  }
  let source_ref = {
    ..@core.empty_source_ref(),
    file_id,
    format,
    page,
    bbox,
    line_start,
    line_end,
  }
  match payload.get("extra") {
    Some(@core.JsonValue::Object(extra_payload)) =>
      for entry in extra_payload.to_array() {
        match entry.1 {
          @core.JsonValue::String(value) => source_ref.extra.set(entry.0, value)
          @core.JsonValue::Number(value) => source_ref.extra.set(entry.0, value)
          @core.JsonValue::Bool(value) =>
            source_ref.extra.set(entry.0, value.to_string())
          _ => ()
        }
      }
    _ => ()
  }
  Some(source_ref)
}

///|
fn pdf_native_bbox_from_core_json_object(
  payload : Map[String, @core.JsonValue],
) -> @core.BBox? {
  let x0 = match payload.get("x0") {
    Some(@core.JsonValue::Number(value)) =>
      match pdf_native_parse_json_double(value) {
        Some(parsed) => parsed
        None => return None
      }
    _ => return None
  }
  let y0 = match payload.get("y0") {
    Some(@core.JsonValue::Number(value)) =>
      match pdf_native_parse_json_double(value) {
        Some(parsed) => parsed
        None => return None
      }
    _ => return None
  }
  let x1 = match payload.get("x1") {
    Some(@core.JsonValue::Number(value)) =>
      match pdf_native_parse_json_double(value) {
        Some(parsed) => parsed
        None => return None
      }
    _ => return None
  }
  let y1 = match payload.get("y1") {
    Some(@core.JsonValue::Number(value)) =>
      match pdf_native_parse_json_double(value) {
        Some(parsed) => parsed
        None => return None
      }
    _ => return None
  }
  Some({ x0, y0, x1, y1 })
}

///|
fn pdf_native_should_remove_text_block(
  page : PdfNativePage,
  text_block : PdfNativeTextBlock,
  text_block_index : Int,
  candidates : Array[PdfNativeHeaderFooterRemovalCandidate],
) -> Bool {
  if candidates.length() == 0 {
    return false
  }
  if text_block.lines.length() != 1 {
    return false
  }
  let paragraph = pdf_native_text_block_paragraph(
    page, text_block, text_block_index,
  )
  match paragraph {
    Some((text, source_ref)) => {
      let normalized_text = pdf_native_header_footer_normalized_text(text)
      for candidate in candidates {
        if candidate.normalized_text != normalized_text {
          continue
        }
        if !candidate.pages.contains(page.geometry.page_no) {
          continue
        }
        if pdf_native_line_band_kind(page.geometry, text_block.bbox) !=
          Some(candidate.kind) {
          continue
        }
        if !pdf_native_pdf_bboxes_overlap(candidate.bbox, text_block.bbox) {
          continue
        }
        if source_ref.page != Some(page.geometry.page_no) {
          continue
        }
        return true
      }
      false
    }
    None => false
  }
}

///|
fn pdf_native_pdf_bboxes_overlap(left : PdfBBox, right : PdfBBox) -> Bool {
  let left_x1 = pdf_bbox_right(left)
  let left_y1 = pdf_bbox_bottom(left)
  let right_x1 = pdf_bbox_right(right)
  let right_y1 = pdf_bbox_bottom(right)
  !(left_x1 < right.x ||
  right_x1 < left.x ||
  left_y1 < right.y ||
  right_y1 < left.y)
}

///|
fn pdf_native_matching_table_region(
  _page : PdfNativePage,
  text_block : PdfNativeTextBlock,
  block_index : Int,
  source_ref : @core.SourceRef,
  regions : Array[PdfNativeTableRegionCandidate],
) -> PdfNativeTableRegionCandidate? {
  for region in regions {
    if region.confidence != "high" && region.confidence != "medium" {
      continue
    }
    if region.row_count < 2 || region.column_alignment_count < 2 {
      continue
    }
    if !pdf_native_pdf_bboxes_overlap(region.bbox, text_block.bbox) {
      continue
    }
    if block_index != text_block_index_from_source_ref(source_ref, block_index) {
      ()
    }
    if region.line_start is Some(start) &&
      source_ref.line_start is Some(line_start) {
      if line_start < start {
        continue
      }
    }
    return Some(region)
  }
  None
}

///|
fn text_block_index_from_source_ref(
  source_ref : @core.SourceRef,
  fallback : Int,
) -> Int {
  match source_ref.extra.get("pdf_text_block_index") {
    Some(value) => @string.parse_int(value) catch { _ => fallback }
    None => fallback
  }
}

///|
fn pdf_native_table_block_from_region(
  page : PdfNativePage,
  region : PdfNativeTableRegionCandidate,
  text_blocks : Array[PdfNativeTextBlock],
) -> PdfNativeTableLoweringResult {
  let expected_width = if region.alignment_xs.length() >= 2 {
    region.alignment_xs.length()
  } else {
    region.column_alignment_count
  }
  if expected_width < 2 {
    return PdfNativeTableLoweringResult::Skipped("insufficient_columns")
  }
  let region_blocks : Array[(Int, PdfNativeTextBlock, @core.SourceRef, String)] = []
  for text_block_index in 0..<text_blocks.length() {
    let block_index = text_block_index + 1
    let text_block = text_blocks[text_block_index]
    let paragraph = pdf_native_text_block_paragraph(
      page, text_block, block_index,
    )
    match paragraph {
      Some((text, source_ref)) =>
        if pdf_native_pdf_bboxes_overlap(region.bbox, text_block.bbox) &&
          source_ref.page == Some(region.page_no) {
          region_blocks.push((block_index, text_block, source_ref, text))
        }
      None => ()
    }
  }
  if region_blocks.length() < 2 {
    return PdfNativeTableLoweringResult::Skipped("insufficient_rows")
  }
  region_blocks.sort_by(fn(left, right) {
    let left_index = left.2.extra
      .get("reading_order_index")
      .map(value => @string.parse_int(value) catch { _ => 1_000_000 })
      .unwrap_or(1_000_000)
    let right_index = right.2.extra
      .get("reading_order_index")
      .map(value => @string.parse_int(value) catch { _ => 1_000_000 })
      .unwrap_or(1_000_000)
    if left_index < right_index {
      -1
    } else if left_index > right_index {
      1
    } else {
      0
    }
  })
  let row_cells : Array[Array[PdfNativeTableCellLowering]] = []
  let block_indexes : Array[Int] = []
  let row_source_refs : Array[@core.SourceRef] = []
  for row_entry in region_blocks {
    let row_text = row_entry.3
    let cells = match
      pdf_native_table_row_cells_from_block(
        row_entry.1,
        row_text,
        region.alignment_xs,
        expected_width,
        row_entry.2,
      ) {
      Some(value) => value
      None => return PdfNativeTableLoweringResult::Skipped("row_split_failed")
    }
    if pdf_native_table_non_empty_cell_count(cells) < 2 {
      return PdfNativeTableLoweringResult::Skipped("row_split_failed")
    }
    row_cells.push(cells)
    block_indexes.push(row_entry.0)
    row_source_refs.push(row_entry.2)
  }
  let table_source_ref = pdf_native_table_source_ref_from_rows(row_source_refs)
  let table = @core.make_block(
    @core.BlockKind::Table,
    "table",
    source_ref=table_source_ref,
  )
  table.attrs.set("header_rows", "1")
  table.attrs.set("table_column_count", expected_width.to_string())
  for row_index in 0..<row_cells.length() {
    let row_ref = row_source_refs[row_index]
    let cells = row_cells[row_index]
    let row = @core.make_block(
      @core.BlockKind::TableRow,
      cells.map(cell => cell.text).join(" | "),
      source_ref=row_ref,
    )
    for cell in cells {
      let cell_block = @core.make_block(
        @core.BlockKind::TableCell,
        cell.text,
        source_ref=row_ref,
      )
      row.children.push(
        match cell.rich_inlines {
          Some(rich_inlines) =>
            @core.block_with_rich_inlines(cell_block, Some(rich_inlines))
          None => cell_block
        },
      )
    }
    table.children.push(row)
  }
  PdfNativeTableLoweringResult::Lowered(
    table,
    block_indexes,
    pdf_native_source_ref_metric_string(table_source_ref),
  )
}

///|
fn pdf_native_table_row_cells_from_text(text : String) -> Array[String] {
  let cells : Array[String] = []
  let normalized = text
    .split("  ")
    .to_array()
    .map(part => part.trim().to_owned())
    .filter(part => part != "")
  if normalized.length() >= 2 {
    cells.append(normalized[:])
    return cells
  }
  let tokens = pdf_native_table_text_tokens(text)
  if tokens.length() < 4 {
    return []
  }
  let header_like = tokens[0].length() <= 24 && tokens[1].length() <= 24
  if !header_like {
    return []
  }
  cells.push(tokens[0])
  cells.push(tokens[1])
  cells.push(tokens[2:].join(" "))
  cells
}

///|
fn pdf_native_table_row_cells_from_block(
  text_block : PdfNativeTextBlock,
  fallback_text : String,
  alignment_xs : Array[Double],
  expected_width : Int,
  source_ref : @core.SourceRef,
) -> Array[PdfNativeTableCellLowering]? {
  let merged = Array::make(expected_width, "")
  let meaningful_lines : Array[PdfNativeTextLine] = []
  for line in text_block.lines {
    if pdf_native_line_text(line) != "" {
      meaningful_lines.push(line)
    }
  }
  if meaningful_lines.length() == 0 {
    return None
  }
  let mut used_alignment = false
  for line in meaningful_lines {
    match
      pdf_native_table_line_cells_from_alignment(
        line, alignment_xs, expected_width,
      ) {
      Some(cells) => {
        used_alignment = true
        for index in 0..<expected_width {
          let value = cells[index].trim().to_owned()
          if value == "" {
            continue
          }
          if merged[index] == "" {
            merged[index] = value
          } else {
            merged[index] = merged[index] + "\n" + value
          }
        }
      }
      None =>
        if meaningful_lines.length() == 1 {
          let fallback_cells = pdf_native_table_row_cells_from_line(
            meaningful_lines[0],
            fallback_text,
          )
          if fallback_cells.length() < 2 ||
            fallback_cells.length() > expected_width {
            return None
          }
          for index in 0..<fallback_cells.length() {
            merged[index] = fallback_cells[index]
          }
        } else {
          return None
        }
    }
  }
  if !used_alignment && meaningful_lines.length() > 1 {
    return None
  }
  let non_empty_count = merged.filter(text => text.trim() != "").length()
  if non_empty_count < 2 {
    return None
  }
  Some(
    merged.map(text => {
      let normalized = text.trim().to_owned()
      {
        text: normalized,
        rich_inlines: pdf_native_table_cell_rich_inlines(normalized, source_ref),
      }
    }),
  )
}

///|
fn pdf_native_table_line_cells_from_alignment(
  line : PdfNativeTextLine,
  alignment_xs : Array[Double],
  expected_width : Int,
) -> Array[String]? {
  if alignment_xs.length() == 0 || expected_width <= 0 {
    return None
  }
  let ordered_spans : Array[PdfNativeTextSpan] = []
  for span in line.spans {
    if span.text.trim() != "" {
      ordered_spans.push(span)
    }
  }
  if ordered_spans.length() == 0 {
    return None
  }
  ordered_spans.sort_by(fn(left, right) {
    if left.bbox.x < right.bbox.x {
      -1
    } else if left.bbox.x > right.bbox.x {
      1
    } else {
      0
    }
  })
  let cells = Array::make(expected_width, "")
  let tolerance = pdf_native_table_alignment_tolerance(alignment_xs)
  for span in ordered_spans {
    let column_index = match
      pdf_native_table_alignment_index(
        span.bbox.x,
        alignment_xs,
        expected_width,
        tolerance,
      ) {
      Some(value) => value
      None => return None
    }
    let trimmed = span.text.trim().to_owned()
    if cells[column_index] == "" {
      cells[column_index] = trimmed
    } else {
      cells[column_index] = cells[column_index] + " " + trimmed
    }
  }
  Some(cells)
}

///|
fn pdf_native_table_alignment_tolerance(alignment_xs : Array[Double]) -> Double {
  if alignment_xs.length() < 2 {
    return 18.0
  }
  let mut min_gap = 1_000_000.0
  for index in 1..<alignment_xs.length() {
    let gap = pdf_abs_double(alignment_xs[index] - alignment_xs[index - 1])
    if gap > 0.0 && gap < min_gap {
      min_gap = gap
    }
  }
  if min_gap == 1_000_000.0 {
    18.0
  } else {
    let scaled = min_gap * 0.4
    if scaled < 12.0 {
      12.0
    } else if scaled > 24.0 {
      24.0
    } else {
      scaled
    }
  }
}

///|
fn pdf_native_table_alignment_index(
  x : Double,
  alignment_xs : Array[Double],
  expected_width : Int,
  tolerance : Double,
) -> Int? {
  let mut best_index = -1
  let mut best_distance = 1_000_000.0
  for index in 0..<alignment_xs.length() {
    let distance = pdf_abs_double(x - alignment_xs[index])
    if distance < best_distance {
      best_distance = distance
      best_index = index
    }
  }
  if best_index < 0 || best_distance > tolerance || best_index >= expected_width {
    None
  } else {
    Some(best_index)
  }
}

///|
fn pdf_native_table_row_cells_from_line(
  line : PdfNativeTextLine,
  fallback_text : String,
) -> Array[String] {
  let cells : Array[String] = []
  let spans : Array[PdfNativeTextSpan] = []
  for span in line.spans {
    if span.text.trim() != "" {
      spans.push(span)
    }
  }
  if spans.length() >= 2 {
    let ordered_spans : Array[PdfNativeTextSpan] = []
    ordered_spans.append(spans[:])
    ordered_spans.sort_by(fn(left, right) {
      if left.bbox.x < right.bbox.x {
        -1
      } else if left.bbox.x > right.bbox.x {
        1
      } else {
        0
      }
    })
    for span in ordered_spans {
      let trimmed = span.text.trim().to_owned()
      if trimmed != "" {
        cells.push(trimmed)
      }
    }
    if cells.length() >= 2 {
      return cells
    }
  }
  pdf_native_table_row_cells_from_text(fallback_text)
}

///|
fn pdf_native_table_non_empty_cell_count(
  cells : Array[PdfNativeTableCellLowering],
) -> Int {
  let mut count = 0
  for cell in cells {
    if cell.text.trim() != "" {
      count += 1
    }
  }
  count
}

///|
fn pdf_native_table_cell_rich_inlines(
  text : String,
  source_ref : @core.SourceRef,
) -> Array[@core.CoreInline]? {
  if !text.contains("\n") {
    return None
  }
  let inlines : Array[@core.CoreInline] = []
  let parts = text.split("\n").to_array()
  for index in 0..<parts.length() {
    if index > 0 {
      inlines.push(@core.make_inline_line_break(source_ref~))
    }
    let part = parts[index].trim().to_owned()
    if part != "" {
      inlines.push(@core.make_inline_text(part, source_ref~))
    }
  }
  if inlines.length() == 0 {
    None
  } else {
    Some(inlines)
  }
}

///|
fn pdf_native_table_source_ref_from_rows(
  refs : Array[@core.SourceRef],
) -> @core.SourceRef {
  if refs.length() == 0 {
    return @core.empty_source_ref()
  }
  let first = refs[0]
  let mut merged_bbox = match first.bbox {
    Some(value) => value
    None => { x0: 0.0, y0: 0.0, x1: 0.0, y1: 0.0 }
  }
  let mut line_start = first.line_start
  let mut line_end = first.line_end
  for index in 1..<refs.length() {
    let source_ref = refs[index]
    match source_ref.bbox {
      Some(value) =>
        merged_bbox = {
          x0: if value.x0 < merged_bbox.x0 {
            value.x0
          } else {
            merged_bbox.x0
          },
          y0: if value.y0 < merged_bbox.y0 {
            value.y0
          } else {
            merged_bbox.y0
          },
          x1: if value.x1 > merged_bbox.x1 {
            value.x1
          } else {
            merged_bbox.x1
          },
          y1: if value.y1 > merged_bbox.y1 {
            value.y1
          } else {
            merged_bbox.y1
          },
        }
      None => ()
    }
    line_start = match (line_start, source_ref.line_start) {
      (Some(left), Some(right)) => Some(if left < right { left } else { right })
      (None, Some(right)) => Some(right)
      (current, None) => current
    }
    line_end = match (line_end, source_ref.line_end) {
      (Some(left), Some(right)) => Some(if left > right { left } else { right })
      (None, Some(right)) => Some(right)
      (current, None) => current
    }
  }
  { ..first, bbox: Some(merged_bbox), line_start, line_end }
}

///|
fn pdf_native_source_ref_metric_string(source_ref : @core.SourceRef) -> String {
  let parts : Array[String] = []
  match source_ref.page {
    Some(page) => parts.push("page=" + page.to_string())
    None => ()
  }
  match source_ref.line_start {
    Some(line_start) => parts.push("line_start=" + line_start.to_string())
    None => ()
  }
  match source_ref.line_end {
    Some(line_end) => parts.push("line_end=" + line_end.to_string())
    None => ()
  }
  match source_ref.bbox {
    Some(bbox) =>
      parts.push(
        "bbox=" +
        bbox.x0.to_string() +
        "," +
        bbox.y0.to_string() +
        "," +
        bbox.x1.to_string() +
        "," +
        bbox.y1.to_string(),
      )
    None => ()
  }
  if parts.length() == 0 {
    "unknown"
  } else {
    parts.join(";")
  }
}
