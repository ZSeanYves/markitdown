///|
fn html_block_by_key(
  index : HtmlLoweringIndex,
  source_key : String,
) -> @dhtml.HtmlBlockFact? {
  index.block_by_key.get(source_key)
}

///|
fn html_paragraph_for_block(
  index : HtmlLoweringIndex,
  block_source_key : String,
) -> @dhtml.HtmlParagraphFact? {
  index.paragraph_by_block_key.get(block_source_key)
}

///|
fn html_list_for_block(
  index : HtmlLoweringIndex,
  block_source_key : String,
) -> @dhtml.HtmlListFact? {
  index.list_by_block_key.get(block_source_key)
}

///|
fn html_list_item_is_ordered(
  index : HtmlLoweringIndex,
  block_source_key : String,
) -> Bool {
  match index.list_item_by_block_key.get(block_source_key) {
    Some(item) =>
      match item.list_source_key {
        Some(list_key) =>
          match index.list_by_source_key.get(list_key) {
            Some(list) => return list.kind == @dhtml.HtmlListKind::Ordered
            None => ()
          }
        None => ()
      }
    None => ()
  }
  false
}

///|
fn html_blockquote_for_block(
  index : HtmlLoweringIndex,
  block_source_key : String,
) -> @dhtml.HtmlBlockQuoteFact? {
  index.blockquote_by_block_key.get(block_source_key)
}

///|
fn html_code_block_for_block(
  index : HtmlLoweringIndex,
  block_source_key : String,
) -> @dhtml.HtmlCodeBlockFact? {
  index.code_block_by_block_key.get(block_source_key)
}

///|
fn html_figure_for_block(
  index : HtmlLoweringIndex,
  block_source_key : String,
) -> @dhtml.HtmlFigureFact? {
  index.figure_by_block_key.get(block_source_key)
}

///|
fn html_table_for_block(
  index : HtmlLoweringIndex,
  block_source_key : String,
) -> @dhtml.HtmlTableFact? {
  index.table_by_block_key.get(block_source_key)
}

///|
fn html_table_row_by_key(
  index : HtmlLoweringIndex,
  source_key : String,
) -> @dhtml.HtmlTableRowFact? {
  index.table_row_by_key.get(source_key)
}

///|
fn html_table_cell_by_key(
  index : HtmlLoweringIndex,
  source_key : String,
) -> @dhtml.HtmlTableCellFact? {
  index.table_cell_by_key.get(source_key)
}

///|
fn html_table_section_by_key(
  index : HtmlLoweringIndex,
  source_key : String,
) -> @dhtml.HtmlTableSectionFact? {
  index.table_section_by_key.get(source_key)
}

///|
fn html_table_header_rows(
  index : HtmlLoweringIndex,
  table : @dhtml.HtmlTableFact,
) -> Int {
  let mut header_rows = 0
  for section_key in table.sections {
    match html_table_section_by_key(index, section_key) {
      Some(section) =>
        if section.kind == @dhtml.HtmlTableSectionKind::Head {
          header_rows += section.row_count
        }
      None => ()
    }
  }
  if header_rows > 0 {
    return header_rows
  }
  if table.rows.length() == 0 {
    return 0
  }
  match html_table_row_by_key(index, table.rows[0]) {
    Some(row) => {
      for cell_key in row.cell_source_keys {
        match html_table_cell_by_key(index, cell_key) {
          Some(cell) =>
            if cell.kind != @dhtml.HtmlTableCellKind::Header {
              return 0
            }
          None => ()
        }
      }
      1
    }
    None => 1
  }
}

///|
fn html_inline_by_key(
  index : HtmlLoweringIndex,
  source_key : String,
) -> @dhtml.HtmlInlineFact? {
  index.inline_by_key.get(source_key)
}

///|
fn html_link_for_inline(
  index : HtmlLoweringIndex,
  inline_source_key : String,
) -> @dhtml.HtmlLinkFact? {
  index.link_by_inline_key.get(inline_source_key)
}

///|
fn html_image_for_inline(
  index : HtmlLoweringIndex,
  inline_source_key : String,
) -> @dhtml.HtmlImageFact? {
  index.image_by_inline_key.get(inline_source_key)
}

///|
fn html_image_by_key(
  index : HtmlLoweringIndex,
  source_key : String,
) -> @dhtml.HtmlImageFact? {
  index.image_by_key.get(source_key)
}

///|
fn html_child_blocks_sorted(
  index : HtmlLoweringIndex,
  keys : Array[String],
) -> Array[@dhtml.HtmlBlockFact] {
  let out : Array[@dhtml.HtmlBlockFact] = Array::new(capacity=keys.length())
  for key in keys {
    match html_block_by_key(index, key) {
      Some(block) => out.push(block)
      None => ()
    }
  }
  out
}

///|
fn html_top_level_inline_segments_for_block(
  index : HtmlLoweringIndex,
  block_source_key : String,
  child_blocks : Array[@dhtml.HtmlBlockFact],
) -> Array[Array[@dhtml.HtmlInlineFact]] {
  let segments : Array[Array[@dhtml.HtmlInlineFact]] = Array::new(
    capacity=child_blocks.length() + 1,
  )
  let mut segment_count = child_blocks.length() + 1
  while segment_count > 0 {
    segments.push([])
    segment_count -= 1
  }
  let inlines = html_top_level_inline_facts_for_block(index, block_source_key)
  let mut region = 0
  for inline in inlines {
    while region < child_blocks.length() &&
          inline.source_order > child_blocks[region].source_order {
      region += 1
    }
    segments[region].push(inline)
  }
  segments
}

///|
fn html_core_inline_segments_for_block(
  state : HtmlLoweringState,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block_source_key : String,
  child_blocks : Array[@dhtml.HtmlBlockFact],
  index : HtmlLoweringIndex,
) -> Array[Array[@core.CoreInline]] {
  let fact_segments = html_top_level_inline_segments_for_block(
    index, block_source_key, child_blocks,
  )
  let segments : Array[Array[@core.CoreInline]] = Array::new(
    capacity=fact_segments.length(),
  )
  for facts in fact_segments {
    segments.push(
      html_inline_facts_to_core_inlines(
        state,
        semantic,
        source,
        facts,
        trim_edges=true,
        index,
      ),
    )
  }
  if child_blocks.length() == 1 && segments.length() >= 2 {
    let child = child_blocks[0]
    if segments[0].length() > 0 && segments[1].length() == 0 {
      match html_split_text_only_inline_segment(segments[0]) {
        Some((left, right)) => {
          segments[0] = left
          segments[1] = right
        }
        None => ()
      }
    } else if segments[1].length() > 0 {
      match html_split_text_only_inline_segment(segments[1]) {
        Some((left, right)) =>
          match child.kind {
            @dhtml.HtmlBlockKind::List(_) =>
              if segments[0].length() > 0 {
                segments[0] = html_concat_core_inlines(segments[0], left)
                segments[1] = right
              }
            _ => ()
          }
        None => ()
      }
    }
  }
  segments
}

///|
fn html_split_text_only_inline_segment(
  inlines : Array[@core.CoreInline],
) -> (Array[@core.CoreInline], Array[@core.CoreInline])? {
  if inlines.length() == 0 {
    return None
  }
  for inline in inlines {
    if inline.kind != @core.InlineKind::Text {
      return None
    }
  }
  let text = html_render_plain_inlines(inlines)
  match html_split_once_double_space(text) {
    Some((left_text, right_text)) =>
      if left_text.trim() == "" || right_text.trim() == "" {
        None
      } else {
        let source_ref = inlines[0].source_ref.unwrap_or(
          @core.empty_source_ref(),
        )
        let left = [@core.make_inline_text(left_text, source_ref~)]
        let right = [@core.make_inline_text(right_text, source_ref~)]
        Some((left, right))
      }
    None => None
  }
}

///|
fn html_split_once_double_space(text : String) -> (String, String)? {
  let chars = text.to_array()
  let mut index = 0
  while index + 1 < chars.length() {
    if chars[index] == ' ' && chars[index + 1] == ' ' {
      let mut end = index + 2
      while end < chars.length() && chars[end] == ' ' {
        end += 1
      }
      let left = String::from_array(chars[:index].to_owned()).trim().to_owned()
      let right = String::from_array(chars[end:].to_owned()).trim().to_owned()
      if left != "" && right != "" {
        return Some((left, right))
      }
    }
    index += 1
  }
  None
}

///|
fn html_concat_core_inlines(
  left : Array[@core.CoreInline],
  right : Array[@core.CoreInline],
) -> Array[@core.CoreInline] {
  let out : Array[@core.CoreInline] = []
  out.append(left[:])
  out.append(right[:])
  html_merge_adjacent_text_inlines(out)
}

///|
fn html_primary_title(semantic : @dhtml.HtmlSemanticDocument) -> String? {
  for scope in semantic.scope {
    match scope.title_text_preview {
      Some(title) =>
        if title.trim() != "" {
          return Some(title.trim().to_owned())
        }
      None => ()
    }
  }
  None
}

///|
fn html_quote_lines_from_blocks(
  blocks : Array[@core.CoreBlock],
) -> Array[String] {
  let lines : Array[String] = []

  fn append_quote_lines_with_blanks(
    lines : Array[String],
    rendered : Array[String],
  ) -> Unit {
    for index in 0..<rendered.length() {
      let line = rendered[index]
      lines.push(line)
      if index + 1 < rendered.length() {
        lines.push("")
      }
    }
  }

  for block in blocks {
    match block.kind {
      @core.BlockKind::Paragraph =>
        lines.append(render_quote_lines_from_text(block.text)[:])
      @core.BlockKind::List =>
        append_quote_lines_with_blanks(
          lines,
          render_quote_lines_from_text(render_list_plain(block, 0)),
        )
      @core.BlockKind::ListItem =>
        append_quote_lines_with_blanks(
          lines,
          render_quote_lines_from_text(render_list_item_plain(block, 0)),
        )
      @core.BlockKind::BlockQuote =>
        lines.append(render_quote_lines_from_text(block.text)[:])
      @core.BlockKind::Code =>
        lines.append(render_quote_lines_from_text(block.text)[:])
      _ =>
        if block.text.trim() != "" {
          lines.append(render_quote_lines_from_text(block.text)[:])
        }
    }
    if lines.length() > 0 &&
      block.kind != @core.BlockKind::List &&
      block.kind != @core.BlockKind::ListItem {
      lines.push("")
    }
  }
  while lines.length() > 0 && lines[lines.length() - 1] == "" {
    ignore(lines.pop())
  }
  lines
}

///|
fn render_quote_lines_from_text(text : String) -> Array[String] {
  text.split("\n").to_array().map(line => line.to_owned())
}

///|
fn html_top_level_inline_facts_for_block(
  index : HtmlLoweringIndex,
  block_source_key : String,
) -> Array[@dhtml.HtmlInlineFact] {
  match index.top_level_inline_facts_by_block_key.get(block_source_key) {
    Some(facts) => facts
    None => []
  }
}

///|
fn render_list_plain(block : @core.CoreBlock, depth : Int) -> String {
  let ordered = block.attrs.get("ordered").unwrap_or("false") == "true"
  let lines : Array[String] = []
  for index in 0..<block.children.length() {
    lines.push(
      render_list_item_plain(
        block.children[index],
        depth,
        ordered~,
        index=index + 1,
      ),
    )
  }
  lines.join("\n")
}

///|
fn render_list_item_plain(
  block : @core.CoreBlock,
  depth : Int,
  ordered? : Bool = false,
  index? : Int = 1,
) -> String {
  let marker = if ordered { index.to_string() + ". " } else { "- " }
  let indent = Array::make(depth * 2, " ").join("")
  let text = if rich_inlines_present_for_html(block) {
    html_render_plain_inlines(block.rich_inlines.unwrap_or([]))
  } else {
    block.text
  }
  let lines : Array[String] = [indent + marker + text.trim().to_owned()]
  for child in block.children {
    match child.kind {
      @core.BlockKind::List => lines.push(render_list_plain(child, depth + 1))
      _ =>
        if child.text.trim() != "" {
          lines.push(
            Array::make((depth + 1) * 2, " ").join("") +
            child.text.trim().to_owned(),
          )
        }
    }
  }
  lines.join("\n")
}

///|
fn rich_inlines_present_for_html(block : @core.CoreBlock) -> Bool {
  match block.rich_inlines {
    Some(inlines) => inlines.length() > 0
    None => false
  }
}

///|
fn html_trim_core_inlines_edges(
  inlines : Array[@core.CoreInline],
) -> Array[@core.CoreInline] {
  let left_trimmed : Array[@core.CoreInline] = []
  let mut seen_content = false
  for inline in inlines {
    if !seen_content {
      match inline.kind {
        @core.InlineKind::Text => {
          let next_text = html_trim_leading_spaces(inline.text)
          if next_text != "" {
            left_trimmed.push({ ..inline, text: next_text })
            seen_content = true
          }
        }
        _ => {
          left_trimmed.push(inline)
          seen_content = true
        }
      }
    } else {
      left_trimmed.push(inline)
    }
  }
  let out_rev : Array[@core.CoreInline] = []
  let mut trimmed_right = false
  let mut index = left_trimmed.length()
  while index > 0 {
    index -= 1
    let inline = left_trimmed[index]
    if !trimmed_right {
      match inline.kind {
        @core.InlineKind::Text => {
          let next_text = html_trim_trailing_spaces(inline.text)
          if next_text != "" {
            out_rev.push({ ..inline, text: next_text })
            trimmed_right = true
          }
        }
        _ => {
          out_rev.push(inline)
          trimmed_right = true
        }
      }
    } else {
      out_rev.push(inline)
    }
  }
  let out : Array[@core.CoreInline] = []
  let mut rev_index = out_rev.length()
  while rev_index > 0 {
    rev_index -= 1
    out.push(out_rev[rev_index])
  }
  html_merge_adjacent_text_inlines(out)
}

///|
fn html_trim_leading_spaces(text : String) -> String {
  let chars = text.to_array()
  let mut start = 0
  while start < chars.length() && html_ascii_space_like(chars[start]) {
    start += 1
  }
  String::from_array(chars[start:].to_owned())
}

///|
fn html_trim_trailing_spaces(text : String) -> String {
  let chars = text.to_array()
  let mut end = chars.length()
  while end > 0 && html_ascii_space_like(chars[end - 1]) {
    end -= 1
  }
  String::from_array(chars[:end].to_owned())
}

///|
fn html_ascii_space_like(ch : Char) -> Bool {
  ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t'
}

///|
fn html_block_source_ref(
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
) -> @core.SourceRef {
  let source_ref = @core.source_ref_with_html_path(
    @core.source_ref_with_lines(
      @core.empty_source_ref(),
      Some(source.source_name),
      Some("html"),
      Some(block.span.line_start),
      Some(block.span.line_end),
    ),
    Some(source.source_name),
    Some("html"),
    Some("/block/" + block.source_key),
  )
  {
    ..source_ref,
    byte_start: Some(block.span.byte_start),
    byte_end: Some(block.span.byte_end),
  }
}

///|
fn html_block_source_ref_by_key(
  source : @input.InputSource,
  _semantic : @dhtml.HtmlSemanticDocument,
  block_source_key : String,
  index : HtmlLoweringIndex,
) -> @core.SourceRef {
  match html_block_by_key(index, block_source_key) {
    Some(block) => html_block_source_ref(source, block)
    None =>
      @core.source_ref_with_html_path(
        @core.source_ref_with_lines(
          @core.empty_source_ref(),
          Some(source.source_name),
          Some("html"),
          Some(1),
          Some(1),
        ),
        Some(source.source_name),
        Some("html"),
        Some("/block/" + block_source_key),
      )
  }
}

///|
fn html_inline_source_ref(
  source : @input.InputSource,
  inline : @dhtml.HtmlInlineFact,
) -> @core.SourceRef {
  @core.source_ref_with_html_path(
    @core.source_ref_with_lines(
      @core.empty_source_ref(),
      Some(source.source_name),
      Some("html"),
      Some(inline.span.line_start),
      Some(inline.span.line_end),
    ),
    Some(source.source_name),
    Some("html"),
    Some("/inline/" + inline.source_key),
  )
}

///|
fn html_image_source_ref(
  source : @input.InputSource,
  image : @dhtml.HtmlImageFact,
) -> @core.SourceRef {
  @core.source_ref_with_html_path(
    @core.source_ref_with_lines(
      @core.empty_source_ref(),
      Some(source.source_name),
      Some("html"),
      Some(image.span.line_start),
      Some(image.span.line_end),
    ),
    Some(source.source_name),
    Some("html"),
    Some("/image/" + image.source_key),
  )
}

///|
fn html_table_row_source_ref(
  source : @input.InputSource,
  row : @dhtml.HtmlTableRowFact,
) -> @core.SourceRef {
  @core.source_ref_with_html_path(
    @core.source_ref_with_lines(
      @core.empty_source_ref(),
      Some(source.source_name),
      Some("html"),
      Some(row.span.line_start),
      Some(row.span.line_end),
    ),
    Some(source.source_name),
    Some("html"),
    Some("/table-row/" + row.source_key),
  )
}

///|
fn html_table_cell_source_ref(
  source : @input.InputSource,
  cell : @dhtml.HtmlTableCellFact,
) -> @core.SourceRef {
  @core.source_ref_with_html_path(
    @core.source_ref_with_lines(
      @core.empty_source_ref(),
      Some(source.source_name),
      Some("html"),
      Some(cell.span.line_start),
      Some(cell.span.line_end),
    ),
    Some(source.source_name),
    Some("html"),
    Some("/table-cell/" + cell.source_key),
  )
}

///|
fn html_safe_local_image_src(src : String) -> Bool {
  if src == "" {
    return false
  }
  let lower = src.to_lower()
  !lower.has_prefix("http://") &&
  !lower.has_prefix("https://") &&
  !lower.has_prefix("data:") &&
  !lower.has_prefix("//") &&
  !lower.has_prefix("/") &&
  !src.contains("..")
}

///|
fn html_strip_query_and_hash(src : String) -> String {
  let chars = src.to_array()
  let mut end = chars.length()
  for i in 0..<chars.length() {
    if chars[i] == '?' || chars[i] == '#' {
      end = i
      break
    }
  }
  src[:end].to_owned()
}

///|
fn html_image_ext_from_src(src : String) -> String {
  let lower = src.to_lower()
  if lower.has_suffix(".png") {
    return "png"
  }
  if lower.has_suffix(".jpg") {
    return "jpg"
  }
  if lower.has_suffix(".jpeg") {
    return "jpeg"
  }
  if lower.has_suffix(".gif") {
    return "gif"
  }
  if lower.has_suffix(".bmp") {
    return "bmp"
  }
  if lower.has_suffix(".webp") {
    return "webp"
  }
  if lower.has_suffix(".tif") || lower.has_suffix(".tiff") {
    return "tiff"
  }
  "img"
}

///|
fn html_two_digit(value : Int) -> String {
  if value < 10 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}
