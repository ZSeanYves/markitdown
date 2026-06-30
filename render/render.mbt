///|
fn render_markdown_blocks(blocks : Array[@core.CoreBlock]) -> String {
  let out = StringBuilder::new()
  ignore(write_markdown_blocks_to(out, blocks))
  out.to_string()
}

///|
fn markdown_needs_blank_line_between(
  prev_kind : @core.BlockKind?,
  next_kind : @core.BlockKind,
) -> Bool {
  match prev_kind {
    Some(@core.BlockKind::List) =>
      next_kind != @core.BlockKind::List &&
      next_kind != @core.BlockKind::ListItem
    Some(@core.BlockKind::ListItem) =>
      next_kind != @core.BlockKind::List &&
      next_kind != @core.BlockKind::ListItem
    Some(_) => true
    None => false
  }
}

///|
fn write_markdown_blocks_to(
  out : StringBuilder,
  blocks : Array[@core.CoreBlock],
) -> Bool {
  let mut prev_kind : @core.BlockKind? = None
  let mut wrote_any = false
  for block in blocks {
    let wrote_block = write_markdown_block_with_separator_to(
      out, block, prev_kind, wrote_any,
    )
    if wrote_block {
      prev_kind = Some(block.kind)
      wrote_any = true
    }
  }
  wrote_any
}

///|
fn write_markdown_block_with_separator_to(
  out : StringBuilder,
  block : @core.CoreBlock,
  prev_kind : @core.BlockKind?,
  wrote_any : Bool,
) -> Bool {
  match markdown_direct_block_visibility(block) {
    Some(false) => return false
    Some(true) => {
      if wrote_any {
        if markdown_needs_blank_line_between(prev_kind, block.kind) {
          out.write_char('\n')
          out.write_char('\n')
        } else {
          out.write_char('\n')
        }
      }
      write_markdown_block_direct_to(out, block)
      return true
    }
    None => ()
  }
  if !wrote_any {
    return write_markdown_block_to(out, block)
  }
  let rendered = render_markdown_block(block)
  if rendered.trim() == "" {
    return false
  }
  if markdown_needs_blank_line_between(prev_kind, block.kind) {
    out.write_char('\n')
    out.write_char('\n')
  } else {
    out.write_char('\n')
  }
  out.write_string(rendered)
  true
}

///|
priv struct RagRenderPayload {
  public_source_map : @core.SourceMap?
  chunks : Array[@rag.RagChunk]
}

///|
fn rag_payload(
  document : @core.DocumentIR,
  context : RenderContext,
  chunks : Array[@rag.RagChunk],
) -> RagRenderPayload {
  {
    public_source_map: if context.rag_options.preserve_source_ref {
      document.source_map
    } else {
      None
    },
    chunks,
  }
}

///|
fn rag_payload_for_direct_input(
  context : RenderContext,
  chunks : Array[@rag.RagChunk],
) -> RagRenderPayload {
  {
    public_source_map: if context.rag_options.preserve_source_ref {
      context.source_map
    } else {
      None
    },
    chunks,
  }
}

///|
fn render_markdown_block(block : @core.CoreBlock) -> String {
  match block.kind {
    @core.BlockKind::Heading => render_markdown_heading(block)
    @core.BlockKind::Paragraph => render_markdown_paragraph(block)
    @core.BlockKind::List => render_markdown_list(block)
    @core.BlockKind::ListItem => render_markdown_list_item(block, 1, false, 0)
    @core.BlockKind::Table => render_markdown_table(block)
    @core.BlockKind::Code => render_markdown_code(block)
    @core.BlockKind::Image => render_markdown_image(block)
    @core.BlockKind::BlockQuote => render_markdown_blockquote(block)
    @core.BlockKind::Raw => render_markdown_raw(block)
    _ =>
      if block.children.length() > 0 {
        block.children.map(child => render_markdown_block(child)).join("\n")
      } else {
        block.text
      }
  }
}

///|
fn write_markdown_block_to(
  out : StringBuilder,
  block : @core.CoreBlock,
) -> Bool {
  match markdown_direct_block_visibility(block) {
    Some(false) => false
    Some(true) => {
      write_markdown_block_direct_to(out, block)
      true
    }
    None => {
      let rendered = render_markdown_block(block)
      if rendered.trim() == "" {
        false
      } else {
        out.write_string(rendered)
        true
      }
    }
  }
}

///|
fn markdown_direct_block_visibility(block : @core.CoreBlock) -> Bool? {
  match block.kind {
    @core.BlockKind::Heading =>
      if !rich_inlines_present(block) {
        Some(true)
      } else {
        None
      }
    @core.BlockKind::Paragraph =>
      if block.attrs.get("note_definition_id") is None &&
        !rich_inlines_present(block) {
        Some(
          block.attrs.get("literal") == Some("true") ||
          literal_text_block(block) ||
          block.text.trim() != "",
        )
      } else {
        None
      }
    @core.BlockKind::Code => Some(true)
    @core.BlockKind::Image => Some(true)
    _ => None
  }
}

///|
fn write_markdown_block_direct_to(
  out : StringBuilder,
  block : @core.CoreBlock,
) -> Unit {
  match block.kind {
    @core.BlockKind::Heading => write_markdown_heading_to(out, block)
    @core.BlockKind::Paragraph => write_markdown_paragraph_to(out, block)
    @core.BlockKind::Code => write_markdown_code_to(out, block)
    @core.BlockKind::Image => write_markdown_image_to(out, block)
    _ => ignore(write_markdown_block_to(out, block))
  }
}

///|
fn write_markdown_heading_to(
  out : StringBuilder,
  block : @core.CoreBlock,
) -> Unit {
  let level = clamp_heading_level(block.attrs.get("level").unwrap_or("1"))
  out.write_string(repeat_char_string('#', level))
  out.write_char(' ')
  if block.attrs.get("literal") == Some("true") || literal_text_block(block) {
    out.write_string(block.text.trim().to_owned())
  } else {
    write_escaped_markdown_inline_text_to(out, block.text.trim().to_owned())
  }
}

///|
fn write_markdown_paragraph_to(
  out : StringBuilder,
  block : @core.CoreBlock,
) -> Unit {
  if literal_text_block(block) || block.attrs.get("literal") == Some("true") {
    out.write_string(block.text.trim().to_owned())
    return
  }
  write_render_literal_markdown_lines_to(out, block.text)
}

///|
fn write_render_literal_markdown_lines_to(
  out : StringBuilder,
  text : String,
) -> Unit {
  let lines = render_literal_markdown_lines(text)
  let mut wrote_any = false
  for line in lines {
    if wrote_any {
      out.write_char(' ')
    }
    out.write_string(line)
    wrote_any = true
  }
}

///|
fn write_markdown_code_to(out : StringBuilder, block : @core.CoreBlock) -> Unit {
  let info = block.attrs.get("info").unwrap_or("")
  let fence = safe_code_fence(block.text)
  out.write_string(fence)
  if info != "" {
    out.write_string(info)
  }
  out.write_char('\n')
  out.write_string(block.text)
  out.write_char('\n')
  out.write_string(fence)
}

///|
fn write_markdown_image_to(
  out : StringBuilder,
  block : @core.CoreBlock,
) -> Unit {
  let escape_mode = block.attrs.get("render_inline_escape_mode")
  let path = block.attrs.get("path").unwrap_or("#")
  out.write_string("![")
  write_escaped_markdown_inline_text_for_format_to(
    out,
    block.attrs.get("alt").unwrap_or("image"),
    escape_mode,
  )
  out.write_string("](")
  out.write_string(path)
  out.write_char(')')
  match block.attrs.get("title") {
    Some(title) =>
      if title.trim() != "" {
        out.write_char('\n')
        out.write_char('*')
        write_escaped_markdown_inline_text_for_format_to(
          out,
          title.trim().to_owned(),
          escape_mode,
        )
        out.write_char('*')
      }
    None => ()
  }
  match block.attrs.get("caption") {
    Some(caption) =>
      if caption.trim() != "" {
        out.write_char('\n')
        if literal_text_block(block) {
          out.write_string(caption.trim().to_owned())
        } else {
          out.write_string(
            escape_markdown_inline_text(caption.trim().to_owned()),
          )
        }
      }
    None => ()
  }
}

///|
fn escape_markdown_inline_text(text : String) -> String {
  let out = StringBuilder::new()
  write_escaped_markdown_inline_text_to(out, text)
  out.to_string()
}

///|
fn write_escaped_markdown_inline_text_to(
  out : StringBuilder,
  text : String,
) -> Unit {
  for ch in text.to_array() {
    let cp = ch.to_int()
    if cp > 0xFFFF {
      out.write_string("&")
      out.write_char('#')
      out.write_string(cp.to_string())
      out.write_char(';')
      continue
    }
    if markdown_punctuation_needs_escape(ch) {
      out.write_char('\\')
    }
    out.write_char(ch)
  }
}

///|
fn escape_markdown_inline_text_for_format(
  text : String,
  escape_mode : String?,
) -> String {
  if escape_mode == Some("minimal") {
    return escape_markdown_inline_text_html(text)
  }
  escape_markdown_inline_text(text)
}

///|
fn write_escaped_markdown_inline_text_for_format_to(
  out : StringBuilder,
  text : String,
  escape_mode : String?,
) -> Unit {
  if escape_mode == Some("minimal") {
    write_escaped_markdown_inline_text_html_to(out, text)
  } else {
    write_escaped_markdown_inline_text_to(out, text)
  }
}

///|
fn escape_markdown_inline_text_html(text : String) -> String {
  let out = StringBuilder::new()
  write_escaped_markdown_inline_text_html_to(out, text)
  out.to_string()
}

///|
fn write_escaped_markdown_inline_text_html_to(
  out : StringBuilder,
  text : String,
) -> Unit {
  for ch in text.to_array() {
    if ch == '\\' || ch == '`' {
      out.write_char('\\')
    }
    out.write_char(ch)
  }
}

///|
fn render_markdown_heading(block : @core.CoreBlock) -> String {
  let level = clamp_heading_level(block.attrs.get("level").unwrap_or("1"))
  let prefix = Array::make(level, "#").join("")
  let escaped = if rich_inlines_present(block) {
    render_markdown_inline_text(block).trim().to_owned()
  } else if block.attrs.get("literal") == Some("true") {
    block.text.trim().to_owned()
  } else if literal_text_block(block) {
    block.text.trim().to_owned()
  } else {
    escape_markdown_inline_text(block.text).trim().to_owned()
  }
  let text = if escaped == "" { " " } else { " " + escaped }
  prefix + text
}

///|
fn render_markdown_paragraph(block : @core.CoreBlock) -> String {
  match block.attrs.get("note_definition_id") {
    Some(note_id) => {
      let body = if rich_inlines_present(block) {
        render_markdown_inline_text(block)
      } else {
        render_literal_markdown_lines(block.text).join(" ")
      }
      return "[^" + note_id + "]: " + body.trim().to_owned()
    }
    None => ()
  }
  if rich_inlines_present(block) {
    return render_markdown_inline_text(block)
  }
  if literal_text_block(block) {
    return block.text.trim().to_owned()
  }
  render_literal_markdown_lines(block.text).join(" ")
}

///|
fn render_markdown_list(block : @core.CoreBlock) -> String {
  if block.children.length() == 0 {
    return render_markdown_list_item(block, 1, false, 0)
  }
  render_markdown_list_with_depth(block, 0)
}

///|
fn render_markdown_list_with_depth(
  block : @core.CoreBlock,
  depth : Int,
) -> String {
  if block.children.length() == 0 {
    return render_markdown_list_item(block, 1, false, depth)
  }
  let ordered = block.attrs.get("ordered").unwrap_or("false") == "true"
  let lines : Array[String] = []
  for i in 0..<block.children.length() {
    lines.push(
      render_markdown_list_item(block.children[i], i + 1, ordered, depth),
    )
  }
  lines.join("\n")
}

///|
fn render_markdown_list_item(
  block : @core.CoreBlock,
  index : Int,
  ordered : Bool,
  depth : Int,
) -> String {
  let is_ordered = ordered ||
    block.attrs.get("ordered").unwrap_or("false") == "true"
  let stable_ordered_marker = block.attrs
    .get("stable_ordered_marker")
    .unwrap_or("false") ==
    "true"
  let marker = if is_ordered {
    if stable_ordered_marker {
      "1. "
    } else {
      index.to_string() + ". "
    }
  } else {
    "- "
  }
  let text = if rich_inlines_present(block) {
    render_markdown_inline_text(block).trim().to_owned()
  } else if block.attrs.get("literal") == Some("true") {
    block.text.trim().to_owned()
  } else {
    escape_markdown_inline_text(block.text).trim().to_owned()
  }
  let ordered_indent_step = list_item_ordered_indent_step(
    block, stable_ordered_marker,
  )
  let line = list_item_indent_for_marker(depth, is_ordered, ordered_indent_step) +
    marker +
    text
  if block.children.length() == 0 {
    return line
  }
  let child_lines : Array[String] = []
  for i in 0..<block.children.length() {
    let child = block.children[i]
    match child.kind {
      @core.BlockKind::List =>
        child_lines.push(render_markdown_list_with_depth(child, depth + 1))
      @core.BlockKind::ListItem =>
        child_lines.push(
          render_markdown_list_item(child, i + 1, false, depth + 1),
        )
      _ =>
        child_lines.push(
          indent_rendered_block(render_markdown_block(child), depth + 1),
        )
    }
  }
  line + "\n" + child_lines.join("\n")
}

///|
fn list_item_ordered_indent_step(
  block : @core.CoreBlock,
  stable_ordered_marker : Bool,
) -> Int {
  let default_step = default_ordered_indent_step(stable_ordered_marker)
  match block.attrs.get("ordered_indent_step") {
    Some(raw) => {
      let parsed = @string.parse_int(raw) catch { _ => default_step }
      if parsed > 0 {
        parsed
      } else {
        default_step
      }
    }
    None => default_step
  }
}

///|
fn default_ordered_indent_step(stable_ordered_marker : Bool) -> Int {
  if stable_ordered_marker {
    2
  } else {
    3
  }
}

///|
fn list_item_indent_for_marker(
  depth : Int,
  ordered : Bool,
  ordered_indent_step : Int,
) -> String {
  let width = if ordered { depth * ordered_indent_step } else { depth * 2 }
  repeat_char_string(' ', width)
}

///|
fn indent_rendered_block(text : String, depth : Int) -> String {
  let indent = list_item_indent_for_marker(depth, false, 2)
  let out = StringBuilder::new()
  let chars = text.to_array()
  let line : Array[Char] = []
  let mut wrote_any = false
  fn flush_line(
    out : StringBuilder,
    line : Array[Char],
    indent : String,
    wrote_any : Bool,
  ) -> Bool {
    let value = String::from_array(line)
    if wrote_any {
      out.write_char('\n')
    }
    if value.trim() == "" {
      out.write_string(value)
    } else {
      out.write_string(indent)
      out.write_string(value)
    }
    line.clear()
    true
  }
  for ch in chars {
    if ch == '\n' {
      wrote_any = flush_line(out, line, indent, wrote_any)
    } else {
      line.push(ch)
    }
  }
  if line.length() > 0 || !text.has_suffix("\n") {
    ignore(flush_line(out, line, indent, wrote_any))
  }
  out.to_string()
}

///|
fn render_markdown_table(block : @core.CoreBlock) -> String {
  if block.children.length() == 0 {
    return render_markdown_raw(
      @core.block_with_attr(block, "raw_kind", "empty_table_fallback"),
    )
  }
  if block.attrs.get("render_html_table") == Some("true") &&
    markdown_table_has_spans(block.children) {
    return render_markdown_html_table(block)
  }
  let rows = block.children
  let width = table_render_width_from_children(block, rows)
  if width == 0 {
    return render_markdown_raw(
      @core.block_with_attr(block, "raw_kind", "empty_table_fallback"),
    )
  }
  let header_rows = @string.parse_int(
    block.attrs.get("header_rows").unwrap_or("1"),
  ) catch {
    _ => 1
  }
  let start = if header_rows == 0 { 0 } else { 1 }
  let out = StringBuilder::new()
  if header_rows == 0 {
    write_markdown_table_synthetic_header(out, width)
  } else {
    write_markdown_table_row(out, table_row_cells(rows[0]), width)
  }
  out.write_char('\n')
  write_markdown_table_separator(out, width)
  for i in start..<rows.length() {
    let row_cells = table_row_cells(rows[i])
    let row_width = if row_cells.length() > width {
      row_cells.length()
    } else {
      width
    }
    out.write_char('\n')
    write_markdown_table_row(out, row_cells, row_width)
  }
  out.to_string()
}

///|
fn markdown_table_has_spans(rows : Array[@core.CoreBlock]) -> Bool {
  for row in rows {
    for cell in row.children {
      if cell.attrs.get("rowspan") is Some(_) ||
        cell.attrs.get("colspan") is Some(_) {
        return true
      }
    }
  }
  false
}

///|
fn render_markdown_html_table(block : @core.CoreBlock) -> String {
  let rows = block.children
  let header_rows = @string.parse_int(
    block.attrs.get("header_rows").unwrap_or("1"),
  ) catch {
    _ => 1
  }
  let out = StringBuilder::new()
  out.write_string("<table>\n")
  for index in 0..<rows.length() {
    let row = rows[index]
    let tag = if header_rows > 0 && index < header_rows { "th" } else { "td" }
    out.write_string("<tr>")
    for cell in row.children {
      out.write_string("<")
      out.write_string(tag)
      markdown_write_html_table_cell_attrs(out, cell)
      out.write_string(">")
      out.write_string(
        markdown_escape_html_text(markdown_table_cell_text(cell)),
      )
      out.write_string("</")
      out.write_string(tag)
      out.write_string(">")
    }
    out.write_string("</tr>")
    if index + 1 < rows.length() {
      out.write_char('\n')
    }
  }
  out.write_string("\n</table>")
  out.to_string()
}

///|
fn markdown_write_html_table_cell_attrs(
  out : StringBuilder,
  cell : @core.CoreBlock,
) -> Unit {
  match cell.attrs.get("rowspan") {
    Some(value) =>
      if value.trim() != "" && value != "1" {
        out.write_string(" rowspan=\"")
        out.write_string(markdown_escape_html_attr(value))
        out.write_char('"')
      }
    None => ()
  }
  match cell.attrs.get("colspan") {
    Some(value) =>
      if value.trim() != "" && value != "1" {
        out.write_string(" colspan=\"")
        out.write_string(markdown_escape_html_attr(value))
        out.write_char('"')
      }
    None => ()
  }
}

///|
fn markdown_table_cell_text(cell : @core.CoreBlock) -> String {
  if rich_inlines_present(cell) {
    render_markdown_inline_text(cell)
  } else {
    cell.text
  }
}

///|
fn markdown_escape_html_text(text : String) -> String {
  let out = StringBuilder::new()
  for ch in text.to_array() {
    if ch == '&' {
      out.write_string("&amp;")
    } else if ch == '<' {
      out.write_string("&lt;")
    } else if ch == '>' {
      out.write_string("&gt;")
    } else {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn markdown_escape_html_attr(text : String) -> String {
  let out = StringBuilder::new()
  for ch in text.to_array() {
    if ch == '&' {
      out.write_string("&amp;")
    } else if ch == '<' {
      out.write_string("&lt;")
    } else if ch == '>' {
      out.write_string("&gt;")
    } else if ch == '"' {
      out.write_string("&quot;")
    } else {
      out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn table_render_width_from_children(
  block : @core.CoreBlock,
  rows : Array[@core.CoreBlock],
) -> Int {
  match block.attrs.get("table_column_count") {
    Some(raw) => {
      let parsed = @string.parse_int(raw.trim()) catch {
        _ => widest_table_row_width_from_children(rows)
      }
      if parsed <= 0 {
        return widest_table_row_width_from_children(rows)
      }
      if rows.length() == 0 {
        return parsed
      }
      let header_width = table_row_width(rows[0])
      if header_width > 0 && header_width < parsed {
        header_width
      } else {
        parsed
      }
    }
    None => widest_table_row_width_from_children(rows)
  }
}

///|
fn render_markdown_code(block : @core.CoreBlock) -> String {
  let info = block.attrs.get("info").unwrap_or("")
  let fence = safe_code_fence(block.text)
  let info_suffix = if info == "" { "" } else { info }
  fence + info_suffix + "\n" + block.text + "\n" + fence
}

///|
fn render_markdown_image(block : @core.CoreBlock) -> String {
  let alt = escape_markdown_inline_text_for_format(
    block.attrs.get("alt").unwrap_or("image"),
    block.attrs.get("render_inline_escape_mode"),
  )
  let path = block.attrs.get("path").unwrap_or("#")
  let lines : Array[String] = ["![" + alt + "](" + path + ")"]
  match block.attrs.get("title") {
    Some(title) =>
      if title.trim() != "" {
        lines.push(
          "*" +
          escape_markdown_inline_text_for_format(
            title.trim().to_owned(),
            block.attrs.get("render_inline_escape_mode"),
          ) +
          "*",
        )
      }
    None => ()
  }
  match block.attrs.get("caption") {
    Some(caption) =>
      if caption.trim() != "" {
        let rendered = if literal_text_block(block) {
          caption.trim().to_owned()
        } else {
          escape_markdown_inline_text(caption.trim().to_owned())
        }
        lines.push(rendered)
      }
    None => ()
  }
  lines.join("\n")
}

///|
fn safe_markdown_table_cell(text : String) -> String {
  let out = StringBuilder::new()
  write_safe_markdown_table_cell_to(out, text)
  out.to_string().trim().to_owned()
}

///|
fn write_safe_markdown_table_cell_to(
  out : StringBuilder,
  text : String,
) -> Unit {
  let mut pending_spaces = StringBuilder::new()
  let mut skip_leading_spaces_after_break = false
  for ch in text.to_array() {
    if ch == '|' {
      let pending = pending_spaces.to_string()
      if pending != "" {
        out.write_string(pending)
        pending_spaces = StringBuilder::new()
      }
      skip_leading_spaces_after_break = false
      out.write_string("\\|")
    } else if ch == '\n' {
      pending_spaces = StringBuilder::new()
      out.write_string("<br>")
      skip_leading_spaces_after_break = true
    } else if ch == ' ' || ch == '\t' {
      if skip_leading_spaces_after_break {
        continue
      }
      pending_spaces.write_char(ch)
    } else {
      let pending = pending_spaces.to_string()
      if pending != "" {
        out.write_string(pending)
        pending_spaces = StringBuilder::new()
      }
      skip_leading_spaces_after_break = false
      out.write_char(ch)
    }
  }
  let pending = pending_spaces.to_string()
  if pending != "" {
    out.write_string(pending)
  }
}

///|
fn render_markdown_blockquote(block : @core.CoreBlock) -> String {
  if block.children.length() > 0 {
    return render_markdown_blockquote_children(block.children)
  }
  if rich_inlines_present(block) {
    return render_inline_markdown_blockquote(block)
  }
  let literal = block.attrs.get("literal") == Some("true")
  block.text
  .split("\n")
  .to_array()
  .map(line => {
    let text = if literal || literal_text_block(block) {
      line.to_owned()
    } else {
      escape_markdown_inline_text(line.to_owned())
    }
    "> " + text
  })
  .join("\n")
}

///|
fn render_markdown_blockquote_children(
  children : Array[@core.CoreBlock],
) -> String {
  let lines : Array[String] = []
  for index in 0..<children.length() {
    let child = children[index]
    let rendered = render_markdown_block(child)
    if rendered.trim() != "" {
      let child_lines = rendered
        .split("\n")
        .to_array()
        .map(line => line.to_owned())
      if child.kind == @core.BlockKind::List {
        for line_index in 0..<child_lines.length() {
          lines.push(child_lines[line_index])
          if line_index + 1 < child_lines.length() {
            lines.push("")
          }
        }
      } else {
        lines.append(child_lines[:])
      }
      if index + 1 < children.length() {
        lines.push("")
      }
    }
  }
  while lines.length() > 0 && lines[lines.length() - 1] == "" {
    ignore(lines.pop())
  }
  if lines.length() == 0 {
    return ""
  }
  lines.map(line => if line == "" { "> " } else { "> " + line }).join("\n")
}

///|
fn render_inline_markdown_blockquote(block : @core.CoreBlock) -> String {
  "> " + render_markdown_inline_text(block)
}

///|
fn rich_inlines_present(block : @core.CoreBlock) -> Bool {
  match block.rich_inlines {
    Some(inlines) => inlines.length() > 0
    None => false
  }
}

///|
fn render_markdown_inline_text(block : @core.CoreBlock) -> String {
  let escape_mode = block.attrs.get("render_inline_escape_mode")
  let out = StringBuilder::new()
  match block.rich_inlines {
    Some(inlines) =>
      for i in 0..<inlines.length() {
        let inline = inlines[i]
        if annotation_gap_inline(inlines, i) {
          out.write_string("  ")
        } else {
          out.write_string(
            render_markdown_inline_with_format(inline, escape_mode),
          )
        }
      }
    None => ()
  }
  out.to_string()
}

///|
fn annotation_gap_inline(
  inlines : Array[@core.CoreInline],
  index : Int,
) -> Bool {
  if index == 0 || index + 1 >= inlines.length() {
    return false
  }
  let current = inlines[index]
  if current.kind != @core.InlineKind::Text || current.text != " " {
    return false
  }
  annotation_note_marker_inline(inlines[index - 1]) &&
  annotation_comment_marker_inline(inlines[index + 1])
}

///|
fn annotation_note_marker_inline(inline : @core.CoreInline) -> Bool {
  if inline.kind != @core.InlineKind::Text {
    return false
  }
  inline.attrs.get("annotation_role") == Some("note_ref") &&
  inline.attrs.get("annotation_kind") != Some("comment")
}

///|
fn annotation_comment_marker_inline(inline : @core.CoreInline) -> Bool {
  if inline.kind != @core.InlineKind::Text {
    return false
  }
  inline.attrs.get("annotation_role") == Some("note_ref") &&
  inline.attrs.get("annotation_kind") == Some("comment")
}

///|
fn render_markdown_inline_with_format(
  inline : @core.CoreInline,
  escape_mode : String?,
) -> String {
  if inline.attrs.get("render_literal") == Some("true") {
    return inline.text
  }
  if inline.attrs.get("annotation_role") == Some("note_ref") {
    return inline.attrs.get("annotation_marker").unwrap_or(inline.text)
  }
  match inline.kind {
    @core.InlineKind::Text =>
      escape_markdown_inline_text_for_format(inline.text, escape_mode)
    @core.InlineKind::LineBreak => "<br>"
    @core.InlineKind::Link => {
      let text = escape_markdown_inline_text_for_format(
        inline.text,
        escape_mode,
      )
      let display = text.trim().to_owned()
      let href = inline.href.unwrap_or("").trim().to_owned()
      if display == "" || href == "" {
        text
      } else {
        "[" + display + "](" + href + ")"
      }
    }
    @core.InlineKind::Image => {
      let alt = escape_markdown_inline_text_for_format(inline.text, escape_mode)
        .trim()
        .to_owned()
      let path = inline.href.unwrap_or("#").trim().to_owned()
      "![" + alt + "](" + path + ")"
    }
    @core.InlineKind::Code => {
      let text = inline.text
      let fence = safe_inline_code_fence(text)
      if text.contains("`") {
        fence + " " + text + " " + fence
      } else {
        fence + text + fence
      }
    }
  }
}

///|
fn render_markdown_raw(block : @core.CoreBlock) -> String {
  let raw_kind = block.attrs.get("raw_kind").unwrap_or("text")
  if raw_kind == "markdown_html_literal" ||
    raw_kind == "markdown_literal" ||
    raw_kind == "markdown_thematic_break" ||
    raw_kind == "markdown_table_literal" {
    return block.text
  }
  if raw_kind == "markdown_frontmatter" {
    let marker = block.attrs.get("frontmatter_marker").unwrap_or("---")
    let body = block.text
    if body.trim() == "" {
      return marker + "\n" + marker
    }
    return marker + "\n" + body + "\n" + marker
  }
  let info = block.attrs
    .get("info")
    .unwrap_or(if raw_kind.contains("frontmatter") { "yaml" } else { "text" })
  let fence = safe_code_fence(block.text)
  fence + info + "\n" + block.text + "\n" + fence
}

///|
fn widest_table_row_width_from_children(rows : Array[@core.CoreBlock]) -> Int {
  let mut width = 0
  for row in rows {
    let row_width = table_row_width(row)
    if row_width > width {
      width = row_width
    }
  }
  width
}

///|
fn table_row_width(row : @core.CoreBlock) -> Int {
  match row.attrs.get("sparse_cell_columns") {
    Some("true") => return sparse_table_row_width(row)
    _ => ()
  }
  if row.children.length() > 0 {
    return row.children.length()
  }
  if row.text.trim() == "" {
    return 0
  }
  row.text.split("|").length()
}

///|
fn table_row_cells(row : @core.CoreBlock) -> Array[String] {
  match row.attrs.get("sparse_cell_columns") {
    Some("true") => return sparse_table_row_cells(row)
    _ => ()
  }
  if row.children.length() > 0 {
    return row.children.map(cell => {
      if rich_inlines_present(cell) {
        render_markdown_inline_text(cell)
      } else {
        cell.text
      }
    })
  }
  if row.text.trim() == "" {
    return []
  }
  row.text.split("|").map(part => part.trim().to_owned()).to_array()
}

///|
fn sparse_table_row_width(row : @core.CoreBlock) -> Int {
  if row.children.length() == 0 {
    return sparse_table_declared_width(row)
  }
  let mut max_column = sparse_table_declared_width(row)
  for cell in row.children {
    let column = sparse_table_cell_column_index(cell)
    if column > max_column {
      max_column = column
    }
  }
  max_column
}

///|
fn sparse_table_row_cells(row : @core.CoreBlock) -> Array[String] {
  let width = sparse_table_row_width(row)
  if width <= 0 {
    return []
  }
  let cells = Array::make(width, "")
  if row.children.length() == 0 {
    sparse_table_row_payload_fill(cells, sparse_table_row_payload(row))
    return cells
  }
  for cell in row.children {
    let column = sparse_table_cell_column_index(cell)
    if column <= 0 || column > width {
      continue
    }
    cells[column - 1] = if rich_inlines_present(cell) {
      render_markdown_inline_text(cell)
    } else {
      cell.text
    }
  }
  cells
}

///|
fn sparse_table_row_payload(row : @core.CoreBlock) -> String {
  row.attrs.get("sparse_row_payload").unwrap_or("")
}

///|
fn sparse_table_declared_width(row : @core.CoreBlock) -> Int {
  match row.attrs.get("declared_column_count") {
    Some(raw) => @string.parse_int(raw.trim()) catch { _ => 0 }
    None => 0
  }
}

///|
fn sparse_table_row_payload_fill(
  cells : Array[String],
  payload : String,
) -> Unit {
  if payload.trim() == "" {
    return
  }
  for line in payload.split("\n").to_array() {
    let entry = line.to_owned()
    if entry == "" {
      continue
    }
    let parts = entry.split("\t").to_array()
    if parts.length() < 2 {
      continue
    }
    let column = @string.parse_int(parts[0].trim()) catch { _ => 0 }
    if column <= 0 || column > cells.length() {
      continue
    }
    cells[column - 1] = xlsx_decode_sparse_row_cell(parts[1].to_owned())
  }
}

///|
fn xlsx_decode_sparse_row_cell(text : String) -> String {
  let out : Array[Char] = []
  let chars = text.to_array()
  let mut i = 0
  while i < chars.length() {
    let ch = chars[i]
    if ch == '\\' && i + 1 < chars.length() {
      let next = chars[i + 1]
      if next == 'n' {
        out.push('\n')
        i += 2
        continue
      } else if next == 't' {
        out.push('\t')
        i += 2
        continue
      } else if next == '\\' {
        out.push('\\')
        i += 2
        continue
      }
    }
    out.push(ch)
    i += 1
  }
  String::from_array(out)
}

///|
fn sparse_table_cell_column_index(cell : @core.CoreBlock) -> Int {
  match cell.attrs.get("column_index") {
    Some(raw) => @string.parse_int(raw.trim()) catch { _ => 0 }
    None => 0
  }
}

///|
fn write_markdown_table_synthetic_header(
  out : StringBuilder,
  width : Int,
) -> Unit {
  out.write_string("| ")
  for index in 0..<width {
    if index > 0 {
      out.write_string(" | ")
    }
    out.write_string("Column ")
    out.write_string((index + 1).to_string())
  }
  out.write_string(" |")
}

///|
fn write_markdown_table_separator(out : StringBuilder, width : Int) -> Unit {
  out.write_string("| ")
  for index in 0..<width {
    if index > 0 {
      out.write_string(" | ")
    }
    out.write_string("---")
  }
  out.write_string(" |")
}

///|
fn write_markdown_table_row(
  out : StringBuilder,
  row : Array[String],
  width : Int,
) -> Unit {
  out.write_string("| ")
  for index in 0..<width {
    if index > 0 {
      out.write_string(" | ")
    }
    if index < row.length() {
      out.write_string(safe_markdown_table_cell(row[index]))
    }
  }
  out.write_string(" |")
}

///|
fn safe_code_fence(text : String) -> String {
  let mut max_run = 0
  let mut current_run = 0
  for ch in text {
    if ch == '`' {
      current_run += 1
      if current_run > max_run {
        max_run = current_run
      }
    } else {
      current_run = 0
    }
  }
  let width = if max_run + 1 < 3 { 3 } else { max_run + 1 }
  repeat_char_string('`', width)
}

///|
fn safe_inline_code_fence(text : String) -> String {
  let mut max_run = 0
  let mut current_run = 0
  for ch in text {
    if ch == '`' {
      current_run += 1
      if current_run > max_run {
        max_run = current_run
      }
    } else {
      current_run = 0
    }
  }
  let width = if max_run + 1 < 1 { 1 } else { max_run + 1 }
  repeat_char_string('`', width)
}

///|
fn repeat_char_string(ch : Char, width : Int) -> String {
  if width <= 0 {
    return ""
  }
  let out = StringBuilder::new()
  for _ in 0..<width {
    out.write_char(ch)
  }
  out.to_string()
}

///|
fn render_literal_markdown_lines(text : String) -> Array[String] {
  let lines = text.split("\n").to_array()
  lines.map(line => escape_markdown_line_prefix(line.to_owned()))
}

///|
fn escape_markdown_line_prefix(text : String) -> String {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return ""
  }

  match thematic_break_marker(trimmed) {
    Some(prefix) =>
      return "\\" +
        prefix +
        escape_markdown_inline_text(trimmed[prefix.length():].to_owned())
    None => ()
  }

  let chars = trimmed.to_array()
  let first = chars[0]

  if first == '#' || first == '>' {
    return "\\" +
      String::from_array([first]) +
      escape_markdown_literal_tail(String::from_array(chars[1:].to_owned()))
  }

  if (first == '-' || first == '+' || first == '*') &&
    chars.length() >= 2 &&
    chars[1] == ' ' {
    return "\\" +
      String::from_array([first]) +
      escape_markdown_literal_tail(String::from_array(chars[1:].to_owned()))
  }

  match ordered_list_marker_parts(trimmed) {
    Some((marker_index, suffix_index)) => {
      let out = StringBuilder::new()
      out.write_string(String::from_array(chars[:marker_index].to_owned()))
      out.write_string("\\")
      out.write_char(chars[marker_index])
      out.write_char(chars[suffix_index])
      out.write_string(
        escape_markdown_literal_tail(
          String::from_array(chars[suffix_index + 1:].to_owned()),
        ),
      )
      out.to_string()
    }
    None => escape_markdown_literal_tail(trimmed)
  }
}

///|
fn ordered_list_marker_parts(text : String) -> (Int, Int)? {
  let chars = text.to_array()
  let mut i = 0

  while i < chars.length() && is_ascii_digit(chars[i]) {
    i += 1
  }

  if i == 0 || i + 1 >= chars.length() {
    return None
  }

  if (chars[i] == '.' || chars[i] == ')') && chars[i + 1] == ' ' {
    Some((i, i + 1))
  } else {
    None
  }
}

///|
fn thematic_break_marker(text : String) -> String? {
  if text.length() < 3 {
    return None
  }

  let chars = text.to_array()
  let first = chars[0]
  if !(first == '-' || first == '*' || first == '_') {
    return None
  }

  for ch in chars {
    if ch != first {
      return None
    }
  }
  Some(String::from_array([first]))
}

///|
fn is_ascii_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn escape_markdown_literal_tail(text : String) -> String {
  let out = StringBuilder::new()
  for ch in text.to_array() {
    let cp = ch.to_int()
    if cp > 0xFFFF {
      out.write_string("&")
      out.write_char('#')
      out.write_string(cp.to_string())
      out.write_char(';')
      continue
    }
    if markdown_literal_tail_needs_escape(ch) {
      out.write_char('\\')
    }
    out.write_char(ch)
  }
  out.to_string()
}

///|
fn render_markdown_events(events : Array[@core.CoreEvent]) -> String {
  if events.length() == 0 {
    return ""
  }
  let out = StringBuilder::new()
  if generic_block_event_stream(events) {
    write_markdown_generic_block_events_direct_to(out, events)
    return out.to_string()
  }
  if events[0].kind == @core.EventKind::TextLine ||
    events[0].kind == @core.EventKind::BlankLine {
    write_markdown_line_events_to(out, events)
    return out.to_string()
  }
  if event_stream_contains_table_rows(events) {
    write_markdown_mixed_table_events_to(out, events)
    return out.to_string()
  }
  write_markdown_generic_events_to(out, events)
  out.to_string()
}

///|
fn write_markdown_line_events_to(
  out : StringBuilder,
  events : Array[@core.CoreEvent],
) -> Unit {
  let current_lines : Array[String] = []
  let mut wrote_paragraph = false
  for event in events {
    match event.kind {
      @core.EventKind::TextLine =>
        current_lines.push(event.text.trim().to_owned())
      @core.EventKind::BlankLine =>
        wrote_paragraph = write_markdown_line_paragraph_to(
          out, current_lines, wrote_paragraph,
        )
      @core.EventKind::StartBlock(_) | @core.EventKind::EndBlock(_) => {
        wrote_paragraph = write_markdown_line_paragraph_to(
          out, current_lines, wrote_paragraph,
        )
        if markdown_generic_event_visible(event) {
          if wrote_paragraph {
            out.write_char('\n')
            out.write_char('\n')
          }
          write_markdown_generic_event_to(out, event)
          wrote_paragraph = true
        }
      }
      _ => ()
    }
  }
  ignore(write_markdown_line_paragraph_to(out, current_lines, wrote_paragraph))
}

///|
fn write_markdown_line_paragraph_to(
  out : StringBuilder,
  current_lines : Array[String],
  wrote_paragraph : Bool,
) -> Bool {
  if current_lines.length() == 0 {
    return wrote_paragraph
  }
  if wrote_paragraph {
    out.write_char('\n')
    out.write_char('\n')
  }
  for index in 0..<current_lines.length() {
    if index > 0 {
      out.write_char(' ')
    }
    write_escaped_markdown_inline_text_to(out, current_lines[index])
  }
  current_lines.clear()
  true
}

///|
fn write_markdown_simple_table_events_to(
  out : StringBuilder,
  events : Array[@core.CoreEvent],
) -> Bool {
  let rows : Array[Array[String]] = []
  let current_row : Array[String] = []
  for event in events {
    match event.kind {
      @core.EventKind::Cell => current_row.push(event.text)
      @core.EventKind::RowBreak =>
        if current_row.length() > 0 {
          rows.push(current_row.copy())
          current_row.clear()
        }
      _ => ()
    }
  }
  if current_row.length() > 0 {
    rows.push(current_row.copy())
  }
  if rows.length() == 0 {
    return false
  }
  let width = widest_event_row_width(rows)
  if width == 0 {
    return false
  }
  write_markdown_table_row_from_values(out, rows[0], width)
  out.write_char('\n')
  write_markdown_table_separator(out, width)
  for i in 1..<rows.length() {
    out.write_char('\n')
    write_markdown_table_row_from_values(out, rows[i], width)
  }
  true
}

///|
fn write_markdown_mixed_table_events_to(
  out : StringBuilder,
  events : Array[@core.CoreEvent],
) -> Unit {
  let table_events : Array[@core.CoreEvent] = []
  let generic_events : Array[@core.CoreEvent] = []
  let mut in_generic_tail = false
  for event in events {
    if !in_generic_tail &&
      (
        event.kind == @core.EventKind::Cell ||
        event.kind == @core.EventKind::RowBreak
      ) {
      table_events.push(event)
    } else {
      in_generic_tail = true
      generic_events.push(event)
    }
  }
  let wrote_table = write_markdown_simple_table_events_to(out, table_events)
  let wrote_generic = markdown_generic_events_visible(generic_events)
  if wrote_table && wrote_generic {
    out.write_char('\n')
    out.write_char('\n')
  }
  if wrote_generic {
    write_markdown_generic_events_to(out, generic_events)
  }
}

///|
fn event_stream_contains_table_rows(events : Array[@core.CoreEvent]) -> Bool {
  for event in events {
    if event.kind == @core.EventKind::RowBreak {
      return true
    }
  }
  false
}

///|
fn generic_block_event_stream(events : Array[@core.CoreEvent]) -> Bool {
  if events.length() == 0 {
    return false
  }
  match events[0].source_ref {
    Some(source_ref) =>
      source_ref.extra.get("ir_event_encoding") == Some("generic_block")
    None => false
  }
}

///|
fn generic_blocks_from_events(
  events : Array[@core.CoreEvent],
) -> Array[@core.CoreBlock] {
  let cursor = { events, index: 0 }
  let blocks : Array[@core.CoreBlock] = []
  while cursor.index < cursor.events.length() {
    match parse_generic_block_event(cursor) {
      Some(block) => blocks.push(block)
      None => cursor.index += 1
    }
  }
  blocks
}

///|
fn write_markdown_generic_block_events_direct_to(
  out : StringBuilder,
  events : Array[@core.CoreEvent],
) -> Unit {
  let cursor = { events, index: 0 }
  let mut prev_kind : @core.BlockKind? = None
  let mut wrote_any = false
  while cursor.index < cursor.events.length() {
    match parse_generic_block_event(cursor) {
      Some(block) => {
        let wrote_block = write_markdown_block_with_separator_to(
          out, block, prev_kind, wrote_any,
        )
        if wrote_block {
          prev_kind = Some(block.kind)
          wrote_any = true
        }
      }
      None => cursor.index += 1
    }
  }
}

///|
priv struct GenericEventCursor {
  events : Array[@core.CoreEvent]
  mut index : Int
}

///|
fn parse_generic_block_event(cursor : GenericEventCursor) -> @core.CoreBlock? {
  if cursor.index >= cursor.events.length() {
    return None
  }
  let start = cursor.events[cursor.index]
  match start.kind {
    @core.EventKind::StartBlock(kind) => {
      let source_ref = start.source_ref.unwrap_or(@core.empty_source_ref())
      cursor.index += 1
      Some(
        collect_generic_block_event_body(cursor, kind, start.text, source_ref),
      )
    }
    _ => None
  }
}

///|
fn collect_generic_block_event_body(
  cursor : GenericEventCursor,
  kind : @core.BlockKind,
  text : String,
  source_ref : @core.SourceRef,
) -> @core.CoreBlock {
  let block = @core.make_block(
    kind,
    text,
    source_ref=strip_generic_event_ref(source_ref),
  )
  let attrs = Map([], capacity=8)
  for entry in source_ref.extra.to_array() {
    if entry.0.has_prefix("ir_block_attr_") {
      attrs.set(entry.0["ir_block_attr_".length():].to_owned(), entry.1)
    }
  }
  let inlines : Array[@core.CoreInline] = []
  let children : Array[@core.CoreBlock] = []
  let table_cells : Array[String] = []
  let table_cell_refs : Array[@core.SourceRef] = []
  while cursor.index < cursor.events.length() {
    let event = cursor.events[cursor.index]
    match event.kind {
      @core.EventKind::EndBlock(end_kind) => {
        cursor.index += 1
        if end_kind == kind {
          let rich_inlines = if inlines.length() > 0 {
            Some(inlines)
          } else {
            None
          }
          return { ..block, rich_inlines, children, attrs }
        }
      }
      @core.EventKind::StartBlock(_) =>
        match parse_generic_block_event(cursor) {
          Some(child) => children.push(child)
          None => cursor.index += 1
        }
      @core.EventKind::Text => {
        let raw_event_ref = event.source_ref.unwrap_or(source_ref)
        let event_ref = strip_generic_event_ref(raw_event_ref)
        let inline_kind = generic_inline_kind_name(
          raw_event_ref.extra.get("ir_inline_kind"),
        )
        let inline = match inline_kind {
          Some(@core.InlineKind::LineBreak) =>
            @core.make_inline_line_break(source_ref=event_ref)
          Some(@core.InlineKind::Link) =>
            @core.make_inline_link(
              event.text,
              raw_event_ref.extra.get("ir_inline_href").unwrap_or("#"),
              title=raw_event_ref.extra.get("ir_inline_title"),
              source_ref=event_ref,
            )
          Some(@core.InlineKind::Image) =>
            @core.make_inline_image(
              event.text,
              raw_event_ref.extra.get("ir_inline_href").unwrap_or("#"),
              title=raw_event_ref.extra.get("ir_inline_title"),
              source_ref=event_ref,
            )
          Some(@core.InlineKind::Code) =>
            @core.make_inline_code(event.text, source_ref=event_ref)
          _ => @core.make_inline_text(event.text, source_ref=event_ref)
        }
        for entry in raw_event_ref.extra.to_array() {
          if entry.0.has_prefix("ir_inline_attr_") {
            inline.attrs.set(
              entry.0["ir_inline_attr_".length():].to_owned(),
              entry.1,
            )
          }
        }
        inlines.push(inline)
        cursor.index += 1
      }
      @core.EventKind::Cell => {
        table_cells.push(event.text)
        table_cell_refs.push(
          strip_generic_event_ref(event.source_ref.unwrap_or(source_ref)),
        )
        cursor.index += 1
      }
      @core.EventKind::RowBreak => {
        let row_ref = strip_generic_event_ref(
          event.source_ref.unwrap_or(source_ref),
        )
        let row = @core.make_block(
          @core.BlockKind::TableRow,
          table_cells.join(" | "),
          source_ref=row_ref,
        )
        for index in 0..<table_cells.length() {
          row.children.push(
            @core.make_block(
              @core.BlockKind::TableCell,
              table_cells[index],
              source_ref=if index < table_cell_refs.length() {
                table_cell_refs[index]
              } else {
                row_ref
              },
            ),
          )
        }
        children.push(row)
        table_cells.clear()
        table_cell_refs.clear()
        cursor.index += 1
      }
      _ => cursor.index += 1
    }
  }
  block
}

///|
fn strip_generic_event_ref(source_ref : @core.SourceRef) -> @core.SourceRef {
  let next = {
    ..source_ref,
    extra: Map([], capacity=source_ref.extra.length()),
  }
  for entry in source_ref.extra.to_array() {
    if !entry.0.has_prefix("ir_") {
      next.extra.set(entry.0, entry.1)
    }
  }
  next
}

///|
fn generic_inline_kind_name(kind : String?) -> @core.InlineKind? {
  match kind {
    Some("text") => Some(@core.InlineKind::Text)
    Some("line_break") => Some(@core.InlineKind::LineBreak)
    Some("link") => Some(@core.InlineKind::Link)
    Some("image") => Some(@core.InlineKind::Image)
    Some("code") => Some(@core.InlineKind::Code)
    _ => None
  }
}

///|
fn widest_event_row_width(rows : Array[Array[String]]) -> Int {
  let mut width = 0
  for row in rows {
    if row.length() > width {
      width = row.length()
    }
  }
  width
}

///|
fn write_markdown_table_row_from_values(
  out : StringBuilder,
  row : Array[String],
  width : Int,
) -> Unit {
  out.write_string("|")
  for col in 0..<width {
    let value = if col < row.length() { row[col] } else { "" }
    out.write_char(' ')
    write_safe_markdown_table_cell_to(out, value)
    out.write_string(" |")
  }
}

///|
fn write_markdown_generic_events_to(
  out : StringBuilder,
  events : Array[@core.CoreEvent],
) -> Unit {
  let mut wrote_any = false
  for event in events {
    if !markdown_generic_event_visible(event) {
      continue
    }
    if wrote_any {
      out.write_char('\n')
      out.write_char('\n')
    }
    write_markdown_generic_event_to(out, event)
    wrote_any = true
  }
}

///|
fn markdown_generic_events_visible(events : Array[@core.CoreEvent]) -> Bool {
  for event in events {
    if markdown_generic_event_visible(event) {
      return true
    }
  }
  false
}

///|
fn markdown_generic_event_visible(event : @core.CoreEvent) -> Bool {
  match event.kind {
    @core.EventKind::StartBlock(@core.BlockKind::Code)
    | @core.EventKind::StartBlock(@core.BlockKind::Raw)
    | @core.EventKind::Text => event.text.trim() != ""
    _ => false
  }
}

///|
fn write_markdown_generic_event_to(
  out : StringBuilder,
  event : @core.CoreEvent,
) -> Unit {
  match event.kind {
    @core.EventKind::StartBlock(@core.BlockKind::Code) => {
      let code = @core.make_block(
        @core.BlockKind::Code,
        event.text,
        source_ref=event.source_ref.unwrap_or(@core.empty_source_ref()),
      )
      match event.source_ref {
        Some(source_ref) =>
          match source_ref.extra.get("ir_block_attr_info") {
            Some(info) => code.attrs.set("info", info)
            None => ()
          }
        None => ()
      }
      write_markdown_code_to(out, code)
    }
    @core.EventKind::StartBlock(@core.BlockKind::Raw) => {
      let raw = @core.make_block(
        @core.BlockKind::Raw,
        event.text,
        source_ref=event.source_ref.unwrap_or(@core.empty_source_ref()),
      )
      raw.attrs.set("raw_kind", "text")
      out.write_string(render_markdown_raw(raw))
    }
    @core.EventKind::Text =>
      write_escaped_markdown_inline_text_to(out, event.text)
    _ => ()
  }
}

///|
fn render_debug_json_events(
  events : Array[@core.CoreEvent],
  diagnostics : @core.Diagnostics,
) -> String {
  let items : Array[String] = []
  for event in events {
    items.push(render_event_json(event))
  }
  let fields : Array[String] = []
  fields.push("\"event_count\": " + events.length().to_string())
  fields.push("\"events\": " + @core.array_json(items))
  fields.push("\"diagnostics\": " + render_diagnostics_json(diagnostics))
  @core.object_json(fields)
}

///|
fn render_debug_json_blocks(
  blocks : Array[@core.CoreBlock],
  diagnostics : @core.Diagnostics,
  context : RenderContext,
) -> String {
  let block_items : Array[String] = []
  for block in blocks {
    block_items.push(render_block_json(block))
  }
  let asset_items : Array[String] = []
  let assets = context.assets.unwrap_or([])
  for asset in assets {
    asset_items.push(render_asset_json(asset))
  }
  let fields : Array[String] = []
  fields.push("\"block_count\": " + blocks.length().to_string())
  fields.push("\"blocks\": " + @core.array_json(block_items))
  fields.push("\"asset_count\": " + assets.length().to_string())
  fields.push("\"assets\": " + @core.array_json(asset_items))
  fields.push("\"diagnostics\": " + render_diagnostics_json(diagnostics))
  @core.object_json(fields)
}

///|
fn render_event_json(event : @core.CoreEvent) -> String {
  let fields : Array[String] = []
  fields.push("\"kind\": " + @core.json_string(event_kind_name(event.kind)))
  fields.push("\"text\": " + @core.json_string(event.text))
  fields.push("\"source_ref\": " + render_source_ref_json(event.source_ref))
  @core.object_json(fields)
}

///|
fn event_kind_name(kind : @core.EventKind) -> String {
  match kind {
    @core.EventKind::StartDocument => "start_document"
    @core.EventKind::EndDocument => "end_document"
    @core.EventKind::StartBlock(block_kind) =>
      "start_block:" + @core.block_kind_name(block_kind)
    @core.EventKind::EndBlock(block_kind) =>
      "end_block:" + @core.block_kind_name(block_kind)
    @core.EventKind::Text => "text"
    @core.EventKind::TextLine => "text_line"
    @core.EventKind::BlankLine => "blank_line"
    @core.EventKind::Cell => "cell"
    @core.EventKind::RowBreak => "row_break"
    @core.EventKind::StructureStart => "structure_start"
    @core.EventKind::StructureEnd => "structure_end"
    @core.EventKind::Key => "key"
    @core.EventKind::Scalar => "scalar"
  }
}

///|

///|
fn render_rag_json_events(
  metadata : @core.DocumentMetadata,
  payload : RagRenderPayload,
  diagnostics : @core.Diagnostics,
) -> String {
  let chunk_items : Array[String] = []
  for chunk in payload.chunks {
    chunk_items.push(render_rag_chunk_json(chunk))
  }
  let fields : Array[String] = []
  fields.push("\"output_format\": " + @core.json_string("rag_json"))
  fields.push(
    "\"detected_format\": " + @core.json_string_opt(diagnostics.detected_format),
  )
  fields.push(
    "\"parser_mode\": " + @core.json_string_opt(diagnostics.parser_mode),
  )
  fields.push(
    "\"convert_mode\": " + @core.json_string_opt(diagnostics.convert_mode),
  )
  fields.push(
    "\"fidelity_mode\": " + @core.json_string_opt(diagnostics.fidelity_mode),
  )
  fields.push(
    "\"output_mode\": " + @core.json_string_opt(diagnostics.output_mode),
  )
  fields.push("\"metadata\": " + render_document_metadata_json(metadata))
  fields.push("\"assets\": []")
  fields.push("\"diagnostics\": " + render_diagnostics_json(diagnostics))
  fields.push(
    "\"source_map\": " + render_source_map_json(payload.public_source_map),
  )
  fields.push("\"chunks\": " + @core.array_json(chunk_items))
  @core.object_json(fields)
}

///|
fn markdown_punctuation_needs_escape(ch : Char) -> Bool {
  ch == '\\' ||
  ch == '`' ||
  ch == '*' ||
  ch == '_' ||
  ch == '{' ||
  ch == '}' ||
  ch == '[' ||
  ch == ']' ||
  ch == '(' ||
  ch == ')' ||
  ch == '#' ||
  ch == '+' ||
  ch == '<' ||
  ch == '>' ||
  ch == '|'
}

///|
fn markdown_literal_tail_needs_escape(ch : Char) -> Bool {
  ch == '\\' ||
  ch == '`' ||
  ch == '*' ||
  ch == '_' ||
  ch == '{' ||
  ch == '}' ||
  ch == '[' ||
  ch == ']' ||
  ch == '(' ||
  ch == ')' ||
  ch == '#' ||
  ch == '<' ||
  ch == '>' ||
  ch == '|'
}

///|
fn literal_text_block(block : @core.CoreBlock) -> Bool {
  block.attrs.get("literal") == Some("true")
}

///|
fn clamp_heading_level(raw : String) -> Int {
  let parsed = @string.parse_int(raw.trim()) catch { _ => 1 }
  if parsed < 1 {
    1
  } else if parsed > 6 {
    6
  } else {
    parsed
  }
}

///|
fn render_block_json(block : @core.CoreBlock) -> String {
  let fields : Array[String] = []
  fields.push(
    "\"kind\": " + @core.json_string(@core.block_kind_name(block.kind)),
  )
  fields.push("\"text\": " + @core.json_string(block.text))
  fields.push(
    "\"rich_inlines\": " + render_rich_inlines_json(block.rich_inlines),
  )
  fields.push("\"source_ref\": " + render_source_ref_json(block.source_ref))
  let child_items : Array[String] = []
  for child in block.children {
    child_items.push(render_block_json(child))
  }
  fields.push("\"children\": " + @core.array_json(child_items))
  @core.object_json(fields)
}

///|
fn render_source_ref_json(source_ref : @core.SourceRef?) -> String {
  match source_ref {
    None => "null"
    Some(value) => {
      let fields : Array[String] = []
      fields.push("\"file_id\": " + @core.json_string_opt(value.file_id))
      fields.push("\"format\": " + @core.json_string_opt(value.format))
      fields.push(
        "\"line_start\": " +
        value.line_start.map(i => i.to_string()).unwrap_or("null"),
      )
      fields.push(
        "\"line_end\": " +
        value.line_end.map(i => i.to_string()).unwrap_or("null"),
      )
      fields.push(
        "\"json_pointer\": " + @core.json_string_opt(value.json_pointer),
      )
      fields.push("\"xpath\": " + @core.json_string_opt(value.xpath))
      fields.push("\"yaml_path\": " + @core.json_string_opt(value.yaml_path))
      fields.push("\"html_path\": " + @core.json_string_opt(value.html_path))
      fields.push(
        "\"markdown_path\": " + @core.json_string_opt(value.markdown_path),
      )
      fields.push(
        "\"container_path\": " + @core.json_string_opt(value.container_path),
      )
      fields.push("\"entry_path\": " + @core.json_string_opt(value.entry_path))
      fields.push(
        "\"entry_index\": " +
        value.entry_index.map(i => i.to_string()).unwrap_or("null"),
      )
      fields.push(
        "\"entry_format\": " + @core.json_string_opt(value.entry_format),
      )
      fields.push("\"inner_path\": " + @core.json_string_opt(value.inner_path))
      fields.push("\"sheet\": " + @core.json_string_opt(value.sheet))
      fields.push("\"cell_range\": " + @core.json_string_opt(value.cell_range))
      fields.push(
        "\"slide\": " + value.slide.map(i => i.to_string()).unwrap_or("null"),
      )
      fields.push("\"shape_id\": " + @core.json_string_opt(value.shape_id))
      fields.push(
        "\"relationship_id\": " + @core.json_string_opt(value.relationship_id),
      )
      fields.push(
        "\"chapter_href\": " + @core.json_string_opt(value.chapter_href),
      )
      let extra_fields : Array[String] = []
      let extra_entries = value.extra.to_array()
      extra_entries.sort_by(fn(a, b) { a.0[:].lexical_compare(b.0[:]) })
      for entry in extra_entries {
        extra_fields.push(
          @core.json_string(entry.0) + ": " + @core.json_string(entry.1),
        )
      }
      fields.push("\"extra\": " + @core.object_json(extra_fields))
      @core.object_json(fields)
    }
  }
}

///|
fn render_source_map_json(source_map : @core.SourceMap?) -> String {
  match source_map {
    None => "null"
    Some(value) => {
      let block_entries : Array[String] = []
      for entry in value.block_entries {
        block_entries.push(render_source_map_entry_json(entry))
      }
      let asset_entries : Array[String] = []
      for entry in value.asset_entries {
        asset_entries.push(render_source_map_entry_json(entry))
      }
      let fields : Array[String] = []
      fields.push(
        "\"document_ref\": " + render_source_ref_json(value.document_ref),
      )
      fields.push("\"block_entries\": " + @core.array_json(block_entries))
      fields.push("\"asset_entries\": " + @core.array_json(asset_entries))
      @core.object_json(fields)
    }
  }
}

///|
fn render_source_map_entry_json(entry : @core.SourceMapEntry) -> String {
  let refs : Array[String] = []
  for source_ref in entry.refs {
    refs.push(render_source_ref_json(Some(source_ref)))
  }
  let merged_from : Array[String] = []
  for source_ref in entry.merged_from {
    merged_from.push(render_source_ref_json(Some(source_ref)))
  }
  let fields : Array[String] = []
  fields.push("\"primary_ref\": " + render_source_ref_json(entry.primary_ref))
  fields.push("\"refs\": " + @core.array_json(refs))
  fields.push("\"merged_from\": " + @core.array_json(merged_from))
  fields.push(
    "\"confidence\": " +
    entry.confidence.map(value => value.to_string()).unwrap_or("null"),
  )
  fields.push("\"relation\": " + @core.json_string_opt(entry.relation))
  @core.object_json(fields)
}

///|
fn render_rich_inlines_json(rich_inlines : Array[@core.CoreInline]?) -> String {
  match rich_inlines {
    None => "null"
    Some(inlines) => {
      let items : Array[String] = []
      for inline in inlines {
        let fields : Array[String] = []
        fields.push(
          "\"kind\": " + @core.json_string(@core.inline_kind_name(inline.kind)),
        )
        fields.push("\"text\": " + @core.json_string(inline.text))
        fields.push("\"href\": " + @core.json_string_opt(inline.href))
        fields.push("\"title\": " + @core.json_string_opt(inline.title))
        fields.push(
          "\"source_ref\": " + render_source_ref_json(inline.source_ref),
        )
        items.push(@core.object_json(fields))
      }
      @core.array_json(items)
    }
  }
}

///|
fn render_asset_json(asset : @core.AssetRef) -> String {
  let fields : Array[String] = []
  fields.push(
    "\"asset_kind\": " +
    @core.json_string(@core.asset_kind_name(asset.asset_kind)),
  )
  fields.push("\"asset_id\": " + @core.json_string(asset.asset_id))
  fields.push("\"path\": " + @core.json_string_opt(asset.path))
  fields.push("\"mime_type\": " + @core.json_string_opt(asset.mime_type))
  fields.push("\"source_ref\": " + render_source_ref_json(asset.source_ref))
  let attr_fields : Array[String] = []
  let entries = asset.attrs.to_array()
  entries.sort_by(fn(a, b) { a.0[:].lexical_compare(b.0[:]) })
  for entry in entries {
    attr_fields.push(
      @core.json_string(entry.0) + ": " + @core.json_string(entry.1),
    )
  }
  fields.push("\"attrs\": " + @core.object_json(attr_fields))
  @core.object_json(fields)
}

///|
fn render_document_metadata_json(metadata : @core.DocumentMetadata) -> String {
  let fields : Array[String] = []
  let entries = metadata.to_array()
  entries.sort_by(fn(a, b) { a.0[:].lexical_compare(b.0[:]) })
  for entry in entries {
    fields.push(@core.json_string(entry.0) + ": " + render_json_value(entry.1))
  }
  @core.object_json(fields)
}

///|
fn render_json_value(value : @core.JsonValue) -> String {
  match value {
    @core.JsonValue::String(text) => @core.json_string(text)
    @core.JsonValue::Number(text) => text
    @core.JsonValue::Bool(flag) => if flag { "true" } else { "false" }
    @core.JsonValue::Null => "null"
    @core.JsonValue::Array(items) =>
      @core.array_json(items.map(item => render_json_value(item)))
    @core.JsonValue::Object(fields) => {
      let pairs : Array[String] = []
      let entries = fields.to_array()
      entries.sort_by(fn(a, b) { a.0[:].lexical_compare(b.0[:]) })
      for entry in entries {
        pairs.push(
          @core.json_string(entry.0) + ": " + render_json_value(entry.1),
        )
      }
      @core.object_json(pairs)
    }
  }
}

///|
fn render_rag_chunk_json(chunk : @rag.RagChunk) -> String {
  let fields : Array[String] = []
  fields.push("\"id\": " + @core.json_string(chunk.id))
  fields.push(
    "\"kind\": " + @core.json_string(@rag.chunk_kind_name(chunk.kind)),
  )
  fields.push("\"text\": " + @core.json_string(chunk.text))
  fields.push(
    "\"heading_path\": " + @core.string_array_json(chunk.heading_path),
  )
  let source_refs : Array[String] = []
  for source_ref in chunk.source_refs {
    source_refs.push(render_source_ref_json(Some(source_ref)))
  }
  fields.push("\"source_refs\": " + @core.array_json(source_refs))
  fields.push("\"asset_refs\": " + @core.string_array_json(chunk.asset_refs))
  fields.push("\"metadata\": " + render_document_metadata_json(chunk.metadata))
  @core.object_json(fields)
}

///|
fn chunk_kind_count(
  chunks : Array[@rag.RagChunk],
  kind : @rag.ChunkKind,
) -> Int {
  let mut count = 0
  for chunk in chunks {
    if chunk.kind == kind {
      count += 1
    }
  }
  count
}

///|
fn render_diagnostics_json(diagnostics : @core.Diagnostics) -> String {
  let metric_fields : Array[String] = []
  let entries = diagnostics.metrics.to_array()
  entries.sort_by(fn(a, b) { a.0[:].lexical_compare(b.0[:]) })
  for entry in entries {
    metric_fields.push(
      @core.json_string(entry.0) + ": " + @core.json_string(entry.1),
    )
  }
  let fields : Array[String] = []
  fields.push(
    "\"parser_name\": " + @core.json_string_opt(diagnostics.parser_name),
  )
  fields.push(
    "\"parser_mode\": " + @core.json_string_opt(diagnostics.parser_mode),
  )
  fields.push(
    "\"convert_mode\": " + @core.json_string_opt(diagnostics.convert_mode),
  )
  fields.push(
    "\"fidelity_mode\": " + @core.json_string_opt(diagnostics.fidelity_mode),
  )
  fields.push(
    "\"output_mode\": " + @core.json_string_opt(diagnostics.output_mode),
  )
  fields.push(
    "\"input_kind\": " + @core.json_string_opt(diagnostics.input_kind),
  )
  fields.push(
    "\"detected_format\": " + @core.json_string_opt(diagnostics.detected_format),
  )
  fields.push("\"warnings\": " + @core.string_array_json(diagnostics.warnings))
  fields.push("\"errors\": " + @core.string_array_json(diagnostics.errors))
  fields.push(
    "\"degraded_features\": " +
    @core.string_array_json(diagnostics.degraded_features),
  )
  fields.push(
    "\"same_mode_degradation\": " +
    @core.string_array_json(diagnostics.same_mode_degradation),
  )
  fields.push(
    "\"fallback_trace\": " + @core.string_array_json(diagnostics.fallback_trace),
  )
  fields.push(
    "\"pass_trace\": " + @core.string_array_json(diagnostics.pass_trace),
  )
  fields.push("\"metrics\": " + @core.object_json(metric_fields))
  @core.object_json(fields)
}
