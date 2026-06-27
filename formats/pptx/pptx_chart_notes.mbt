///|
fn pptx_caption_text_has_prefix(text : String) -> Bool {
  let lower = text.trim().to_lower()
  lower.has_prefix("figure") ||
  lower.has_prefix("fig.") ||
  lower.has_prefix("caption")
}

///|
fn pptx_table_block(
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  table : @pptxdoc.PptxTable,
) -> @core.CoreBlock? {
  if !pptx_table_has_visible_cells(table) {
    return None
  }
  let source_ref = pptx_table_source_ref(state.source, slide, table)
  let block = @core.make_block(@core.BlockKind::Table, "table", source_ref~)
  block.attrs.set("header_rows", "1")
  block.attrs.set(
    "table_column_count",
    pptx_table_column_count(table).to_string(),
  )
  for row in table.rows {
    let row_ref = @core.source_ref_with_extra(
      pptx_table_source_ref(state.source, slide, table),
      "row_index",
      row.row_index.to_string(),
    )
    let row_block = @core.make_block(
      @core.BlockKind::TableRow,
      "",
      source_ref=row_ref,
    )
    for cell in row.cells {
      let cell_ref = @core.source_ref_with_extra(
        @core.source_ref_with_extra(
          pptx_table_source_ref(state.source, slide, table),
          "row_index",
          cell.row_index.to_string(),
        ),
        "column_index",
        cell.column_index.to_string(),
      )
      let cell_block = @core.make_block(
        @core.BlockKind::TableCell,
        pptx_table_cell_text(cell),
        source_ref=cell_ref,
      )
      row_block.children.push(cell_block)
      let grid_span = cell.grid_span.unwrap_or(1)
      if grid_span > 1 {
        for _ in 1..<grid_span {
          row_block.children.push(
            @core.make_block(
              @core.BlockKind::TableCell,
              "",
              source_ref=cell_ref,
            ),
          )
        }
      }
    }
    block.children.push(row_block)
  }
  Some(block)
}

///|
fn pptx_table_has_visible_cells(table : @pptxdoc.PptxTable) -> Bool {
  for row in table.rows {
    for cell in row.cells {
      if pptx_table_cell_text(cell).trim() != "" {
        return true
      }
    }
  }
  false
}

///|
fn pptx_table_column_count(table : @pptxdoc.PptxTable) -> Int {
  let mut width = 0
  for row in table.rows {
    let mut row_width = 0
    for cell in row.cells {
      row_width += cell.grid_span.unwrap_or(1)
    }
    if row_width > width {
      width = row_width
    }
  }
  width
}

///|
fn pptx_table_cell_text(cell : @pptxdoc.PptxTableCell) -> String {
  let parts : Array[String] = []
  for para in cell.paragraphs {
    let text = pptx_plain_text_from_paragraph(para).trim().to_owned()
    if text != "" {
      parts.push(text)
    }
  }
  parts.join("<br>")
}

///|
fn pptx_lower_chart(
  blocks : Array[@core.CoreBlock],
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  chart : @pptxdoc.PptxChartRef,
) -> Unit {
  let chart_blocks = pptx_chart_blocks(state, slide, chart)
  if chart_blocks.length() == 0 {
    blocks.push(
      pptx_raw_placeholder_block(
        state,
        slide,
        Some(chart.source_key),
        chart.relationship_id,
        "[Unsupported PPTX chart" + pptx_opt_suffix(chart.target_part) + "]",
        "pptx_chart_unsupported",
      ),
    )
    return
  }
  blocks.append(chart_blocks[:])
}

///|
fn pptx_chart_blocks(
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  chart : @pptxdoc.PptxChartRef,
) -> Array[@core.CoreBlock] {
  let out : Array[@core.CoreBlock] = []
  match pptx_chart_title_block(state, slide, chart) {
    Some(block) => out.push(block)
    None => ()
  }
  let cache_blocks = pptx_chart_cache_blocks(state, slide, chart)
  if cache_blocks.length() > 0 {
    out.append(cache_blocks[:])
  } else {
    match pptx_chart_missing_cache_block(state, slide, chart) {
      Some(block) => out.push(block)
      None => ()
    }
  }
  out
}

///|
fn pptx_chart_title_block(
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  chart : @pptxdoc.PptxChartRef,
) -> @core.CoreBlock? {
  match chart.title {
    Some(title) =>
      if title.trim() == "" {
        None
      } else {
        let block = @core.make_block(
          @core.BlockKind::Heading,
          title,
          source_ref=pptx_chart_source_ref(state.source, slide, chart),
        )
        block.attrs.set("level", "3")
        Some(block)
      }
    None => None
  }
}

///|
fn pptx_chart_cache_blocks(
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  chart : @pptxdoc.PptxChartRef,
) -> Array[@core.CoreBlock] {
  if pptx_chart_is_effectively_empty(chart) {
    return []
  }
  match pptx_chart_series_table_block(state, slide, chart) {
    Some(table) => return [table]
    None => ()
  }
  let list_blocks = pptx_chart_series_list_blocks(state, slide, chart)
  if list_blocks.length() > 0 {
    return list_blocks
  }
  match pptx_chart_category_value_table_block(state, slide, chart) {
    Some(table) => [table]
    None => []
  }
}

///|
fn pptx_chart_is_effectively_empty(chart : @pptxdoc.PptxChartRef) -> Bool {
  if chart.cached_series.length() > 0 {
    for series in chart.cached_series {
      if series.categories.length() > 0 ||
        series.values.length() > 0 ||
        series.text.length() > 0 {
        return false
      }
    }
    return true
  }
  chart.cached_categories.length() == 0 &&
  chart.cached_values.length() == 0 &&
  chart.cached_text.length() == 0
}

///|
fn pptx_chart_series_table_block(
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  chart : @pptxdoc.PptxChartRef,
) -> @core.CoreBlock? {
  if chart.cached_series.length() == 0 {
    return None
  }
  if !pptx_chart_can_render_series_table(chart) {
    return None
  }
  let categories = pptx_chart_table_categories(chart.cached_series)
  if categories.length() == 0 {
    return None
  }
  let source_ref = pptx_chart_source_ref(state.source, slide, chart)
  let block = @core.make_block(@core.BlockKind::Table, "table", source_ref~)
  block.attrs.set("header_rows", "1")
  block.attrs.set(
    "table_column_count",
    (chart.cached_series.length() + 1).to_string(),
  )
  let header = @core.make_block(
    @core.BlockKind::TableRow,
    "",
    source_ref=@core.source_ref_with_extra(source_ref, "row_index", "0"),
  )
  header.children.push(
    @core.make_block(
      @core.BlockKind::TableCell,
      "Category",
      source_ref=@core.source_ref_with_extra(
        @core.source_ref_with_extra(source_ref, "row_index", "0"),
        "column_index",
        "0",
      ),
    ),
  )
  for index in 0..<chart.cached_series.length() {
    let series = chart.cached_series[index]
    header.children.push(
      @core.make_block(
        @core.BlockKind::TableCell,
        series.name.unwrap_or("Series " + (index + 1).to_string()),
        source_ref=@core.source_ref_with_extra(
          @core.source_ref_with_extra(source_ref, "row_index", "0"),
          "column_index",
          (index + 1).to_string(),
        ),
      ),
    )
  }
  block.children.push(header)
  for row_index in 0..<categories.length() {
    let row = @core.make_block(
      @core.BlockKind::TableRow,
      "",
      source_ref=@core.source_ref_with_extra(
        source_ref,
        "row_index",
        (row_index + 1).to_string(),
      ),
    )
    row.children.push(
      @core.make_block(
        @core.BlockKind::TableCell,
        pptx_chart_display_value(categories[row_index]),
        source_ref=@core.source_ref_with_extra(
          @core.source_ref_with_extra(
            source_ref,
            "row_index",
            (row_index + 1).to_string(),
          ),
          "column_index",
          "0",
        ),
      ),
    )
    for series_index in 0..<chart.cached_series.length() {
      let series = chart.cached_series[series_index]
      let value = if row_index < series.values.length() {
        pptx_chart_display_value(series.values[row_index])
      } else {
        ""
      }
      row.children.push(
        @core.make_block(
          @core.BlockKind::TableCell,
          value,
          source_ref=@core.source_ref_with_extra(
            @core.source_ref_with_extra(
              source_ref,
              "row_index",
              (row_index + 1).to_string(),
            ),
            "column_index",
            (series_index + 1).to_string(),
          ),
        ),
      )
    }
    block.children.push(row)
  }
  Some(block)
}

///|
fn pptx_chart_table_categories(
  series_list : Array[@pptxdoc.PptxChartSeries],
) -> Array[String] {
  let mut best : Array[String] = []
  for series in series_list {
    let categories = pptx_chart_series_categories(series)
    if categories.length() > best.length() {
      best = categories
    }
  }
  best
}

///|
fn pptx_chart_can_render_series_table(chart : @pptxdoc.PptxChartRef) -> Bool {
  if chart.cached_series.length() == 0 {
    return false
  }
  let categories = pptx_chart_table_categories(chart.cached_series)
  if categories.length() == 0 {
    return false
  }
  for series in chart.cached_series {
    let series_categories = pptx_chart_series_categories(series)
    if series_categories.length() != categories.length() ||
      series.values.length() != categories.length() {
      return false
    }
  }
  true
}

///|
fn pptx_chart_series_list_blocks(
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  chart : @pptxdoc.PptxChartRef,
) -> Array[@core.CoreBlock] {
  let out : Array[@core.CoreBlock] = []
  for series_index in 0..<chart.cached_series.length() {
    let series = chart.cached_series[series_index]
    let categories = pptx_chart_series_categories(series)
    let pair_count = if categories.length() < series.values.length() {
      categories.length()
    } else {
      series.values.length()
    }
    if pair_count == 0 {
      continue
    }
    let heading = @core.make_block(
      @core.BlockKind::Heading,
      series.name.unwrap_or("Series " + (series_index + 1).to_string()),
      source_ref=pptx_chart_source_ref(state.source, slide, chart),
    )
    heading.attrs.set("level", "3")
    out.push(heading)
    for item_index in 0..<pair_count {
      let item = @core.make_block(
        @core.BlockKind::ListItem,
        pptx_chart_display_value(categories[item_index]) +
        ": " +
        pptx_chart_display_value(series.values[item_index]),
        source_ref=@core.source_ref_with_extra(
          @core.source_ref_with_extra(
            pptx_chart_source_ref(state.source, slide, chart),
            "series_index",
            series_index.to_string(),
          ),
          "item_index",
          item_index.to_string(),
        ),
      )
      item.attrs.set("ordered", "false")
      item.attrs.set("level", "0")
      out.push(item)
    }
  }
  out
}

///|
fn pptx_chart_series_categories(
  series : @pptxdoc.PptxChartSeries,
) -> Array[String] {
  if series.preferred_categories.length() > 0 {
    series.preferred_categories
  } else {
    series.categories
  }
}

///|
fn pptx_chart_category_value_table_block(
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  chart : @pptxdoc.PptxChartRef,
) -> @core.CoreBlock? {
  if chart.cached_categories.length() == 0 || chart.cached_values.length() == 0 {
    return None
  }
  let row_count = if chart.cached_categories.length() <
    chart.cached_values.length() {
    chart.cached_categories.length()
  } else {
    chart.cached_values.length()
  }
  if row_count == 0 {
    return None
  }
  let source_ref = pptx_chart_source_ref(state.source, slide, chart)
  let block = @core.make_block(@core.BlockKind::Table, "table", source_ref~)
  block.attrs.set("header_rows", "1")
  block.attrs.set("table_column_count", "2")
  let header = @core.make_block(
    @core.BlockKind::TableRow,
    "",
    source_ref=@core.source_ref_with_extra(source_ref, "row_index", "0"),
  )
  header.children.push(
    @core.make_block(
      @core.BlockKind::TableCell,
      "Category",
      source_ref=@core.source_ref_with_extra(
        @core.source_ref_with_extra(source_ref, "row_index", "0"),
        "column_index",
        "0",
      ),
    ),
  )
  header.children.push(
    @core.make_block(
      @core.BlockKind::TableCell,
      pptx_chart_category_value_header(chart),
      source_ref=@core.source_ref_with_extra(
        @core.source_ref_with_extra(source_ref, "row_index", "0"),
        "column_index",
        "1",
      ),
    ),
  )
  block.children.push(header)
  for row_index in 0..<row_count {
    let row = @core.make_block(
      @core.BlockKind::TableRow,
      "",
      source_ref=@core.source_ref_with_extra(
        source_ref,
        "row_index",
        (row_index + 1).to_string(),
      ),
    )
    row.children.push(
      @core.make_block(
        @core.BlockKind::TableCell,
        pptx_chart_display_value(chart.cached_categories[row_index]),
        source_ref=@core.source_ref_with_extra(
          @core.source_ref_with_extra(
            source_ref,
            "row_index",
            (row_index + 1).to_string(),
          ),
          "column_index",
          "0",
        ),
      ),
    )
    row.children.push(
      @core.make_block(
        @core.BlockKind::TableCell,
        pptx_chart_display_value(chart.cached_values[row_index]),
        source_ref=@core.source_ref_with_extra(
          @core.source_ref_with_extra(
            source_ref,
            "row_index",
            (row_index + 1).to_string(),
          ),
          "column_index",
          "1",
        ),
      ),
    )
    block.children.push(row)
  }
  Some(block)
}

///|
fn pptx_chart_category_value_header(chart : @pptxdoc.PptxChartRef) -> String {
  for series in chart.cached_series {
    match series.name {
      Some(name) => if name.trim() != "" { return name }
      None => ()
    }
  }
  if chart.cached_text.length() > 0 {
    let candidate = chart.cached_text[0].trim().to_owned()
    if candidate != "" {
      return candidate
    }
  }
  "Value"
}

///|
fn pptx_chart_missing_cache_block(
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
  chart : @pptxdoc.PptxChartRef,
) -> @core.CoreBlock? {
  if !pptx_chart_should_emit_cache_fallback(chart) {
    return None
  }
  state.chart_fallback_emitted.val = true
  let raw = @core.make_block(
    @core.BlockKind::Raw,
    "[Chart data not embedded in chart cache]",
    source_ref=pptx_chart_source_ref(state.source, slide, chart),
  )
  raw.attrs.set("raw_kind", "pptx_chart_cache_missing")
  Some(raw)
}

///|
fn pptx_chart_should_emit_cache_fallback(chart : @pptxdoc.PptxChartRef) -> Bool {
  if chart.cached_series.length() == 0 &&
    chart.cached_categories.length() == 0 &&
    chart.cached_values.length() == 0 {
    return true
  }
  let mut saw_value = false
  let mut saw_renderable_pair = false
  for series in chart.cached_series {
    if series.values.length() > 0 {
      saw_value = true
    }
    let pair_count = if series.categories.length() < series.values.length() {
      series.categories.length()
    } else {
      series.values.length()
    }
    if pair_count > 0 {
      saw_renderable_pair = true
    }
  }
  if saw_renderable_pair {
    return false
  }
  if chart.cached_categories.length() > 0 && chart.cached_values.length() > 0 {
    return false
  }
  saw_value || chart.cached_values.length() > 0
}

///|
fn pptx_chart_source_ref(
  source : @input.InputSource,
  slide : @pptxdoc.PptxSlide,
  chart : @pptxdoc.PptxChartRef,
) -> @core.SourceRef {
  let base = pptx_slide_source_ref(
    source,
    slide,
    Some(chart.source_key),
    chart.relationship_id,
  )
  let base = match chart.target_part {
    Some(part) => @core.source_ref_with_extra(base, "part_name", part)
    None => base
  }
  match pptx_slide_reading_order_key(slide, chart.source_key) {
    Some(order_key) =>
      @core.source_ref_with_extra(base, "reading_order_key", order_key)
    None => base
  }
}

///|
fn pptx_chart_display_value(value : String) -> String {
  let trimmed = value.trim().to_owned()
  match pptx_chart_excel_serial_date(trimmed) {
    Some(date) => date
    None => trimmed
  }
}

///|
fn pptx_chart_excel_serial_date(value : String) -> String? {
  let rounded = match pptx_parse_chart_serial_int(value) {
    Some(serial) => serial
    None => return None
  }
  if rounded < 20000 || rounded > 50000 {
    return None
  }
  let (year, month, day) = pptx_excel_date_components(rounded)
  if year <= 0 || month <= 0 || day <= 0 {
    return None
  }
  Some(
    year.to_string() + "-" + pptx_two_digits(month) + "-" + pptx_two_digits(day),
  )
}

///|
fn pptx_parse_chart_serial_int(value : String) -> Int? {
  let trimmed = value.trim().to_owned()
  if trimmed == "" {
    return None
  }
  if trimmed.contains("e") || trimmed.contains("E") || trimmed.contains("-") {
    return None
  }
  let chars = trimmed.to_array()
  let mut dot_index = -1
  for index in 0..<chars.length() {
    if chars[index] == '.' {
      if dot_index >= 0 {
        return None
      }
      dot_index = index
    }
  }
  if dot_index < 0 {
    return Some(@string.parse_int(trimmed) catch { _ => return None })
  }
  let whole = String::from_array(chars[:dot_index])
  let frac = String::from_array(chars[dot_index + 1:])
  if whole == "" || frac == "" {
    return None
  }
  for ch in frac {
    if ch != '0' {
      return None
    }
  }
  Some(@string.parse_int(whole) catch { _ => return None })
}

///|
fn pptx_excel_date_components(serial : Int) -> (Int, Int, Int) {
  let mut days = serial
  if days > 59 {
    days -= 1
  }
  days -= 1
  if days < 0 {
    return (0, 0, 0)
  }
  let mut year = 1900
  while true {
    let year_days = if pptx_is_leap_year(year) { 366 } else { 365 }
    if days >= year_days {
      days -= year_days
      year += 1
    } else {
      break
    }
  }
  let month_days = pptx_month_day_table(year)
  let mut month = 1
  for day_count in month_days {
    if days >= day_count {
      days -= day_count
      month += 1
    } else {
      break
    }
  }
  (year, month, days + 1)
}

///|
fn pptx_is_leap_year(year : Int) -> Bool {
  if year % 400 == 0 {
    return true
  }
  if year % 100 == 0 {
    return false
  }
  year % 4 == 0
}

///|
fn pptx_month_day_table(year : Int) -> Array[Int] {
  if pptx_is_leap_year(year) {
    [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  } else {
    [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  }
}

///|
fn pptx_plain_text_from_paragraph(para : @pptxdoc.PptxParagraph) -> String {
  let synthetic : Array[@core.CoreInline] = []
  for run in para.runs {
    for inline in run.inlines {
      match inline {
        @pptxdoc.PptxInline::Text(text) =>
          synthetic.push(
            @core.make_inline_text(pptx_normalize_text_fragment(text)),
          )
        @pptxdoc.PptxInline::Break =>
          synthetic.push(@core.make_inline_line_break())
        @pptxdoc.PptxInline::Field(text) =>
          synthetic.push(
            @core.make_inline_text(pptx_normalize_text_fragment(text)),
          )
        @pptxdoc.PptxInline::Hyperlink(_, text) =>
          synthetic.push(
            @core.make_inline_text(pptx_normalize_text_fragment(text)),
          )
        @pptxdoc.PptxInline::Unsupported(_) => ()
      }
    }
  }
  pptx_plain_text(pptx_compact_text_inlines(synthetic))
}

///|
fn pptx_lower_slide_comments(
  blocks : Array[@core.CoreBlock],
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
) -> Unit {
  if slide.comments.length() == 0 {
    return
  }
  let heading = @core.make_block(
    @core.BlockKind::Heading,
    "Comments",
    source_ref=pptx_slide_source_ref(state.source, slide, None, None),
  )
  heading.attrs.set("level", "3")
  blocks.push(heading)
  for comment in slide.comments {
    let prefix = match comment.author_name {
      Some(name) => name + ": "
      None =>
        if comment.author_id.trim() == "" {
          ""
        } else {
          "Author " + comment.author_id + ": "
        }
    }
    let block = @core.make_block(
      @core.BlockKind::ListItem,
      prefix + comment.text,
      source_ref=@core.source_ref_with_extra(
        pptx_slide_source_ref(
          state.source,
          slide,
          Some(comment.source_key),
          None,
        ),
        "comment_id",
        comment.idx.unwrap_or(""),
      ),
    )
    block.attrs.set("ordered", "false")
    block.attrs.set("level", "0")
    blocks.push(block)
  }
}

///|
fn pptx_lower_slide_notes(
  blocks : Array[@core.CoreBlock],
  state : PptxState,
  slide : @pptxdoc.PptxSlide,
) -> Unit {
  let notes = match slide.notes {
    Some(value) => value
    None => return
  }
  let note_blocks : Array[@core.CoreBlock] = []
  let hidden_note_text = hidden_slide_note_text(slide)
  let heading = @core.make_block(
    @core.BlockKind::Heading,
    "Speaker Notes",
    source_ref=@core.source_ref_with_extra(
      pptx_slide_source_ref(state.source, slide, Some(notes.source_key), None),
      "notes_part",
      notes.part_name,
    ),
  )
  heading.attrs.set("level", "3")
  for para in notes.paragraphs {
    let text = pptx_plain_text_from_paragraph(para).trim().to_owned()
    if text == "" ||
      pptx_notes_paragraph_is_page_number(slide, text, para.source_key) ||
      hidden_note_text == Some(text) {
      continue
    }
    let block = @core.make_block(
      @core.BlockKind::Paragraph,
      text,
      source_ref=@core.source_ref_with_extra(
        pptx_slide_source_ref(state.source, slide, Some(para.source_key), None),
        "notes_part",
        notes.part_name,
      ),
    )
    note_blocks.push(block)
  }
  if note_blocks.length() == 0 {
    return
  }
  blocks.push(heading)
  blocks.append(note_blocks[:])
}
