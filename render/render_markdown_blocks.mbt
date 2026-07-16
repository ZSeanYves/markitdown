///|
fn render_markdown_blocks(blocks : Array[@core.CoreBlock]) -> String {
  let out = StringBuilder::new()
  let leaf_cache : Map[String, String] = Map([])
  ignore(write_markdown_blocks_to(out, blocks, leaf_cache~))
  out.to_string()
}

///|
fn markdown_needs_blank_line_between(
  prev_kind : @core.BlockKind?,
  next_kind : @core.BlockKind,
) -> Bool {
  match prev_kind {
    Some(List) => next_kind != List && next_kind != ListItem
    Some(ListItem) => next_kind != List && next_kind != ListItem
    Some(_) => true
    None => false
  }
}

///|
fn write_markdown_blocks_to(
  out : StringBuilder,
  blocks : Array[@core.CoreBlock],
  leaf_cache? : Map[String, String] = Map([]),
) -> Bool {
  let mut prev_kind : @core.BlockKind? = None
  let mut wrote_any = false
  for block in blocks {
    let wrote_block = match markdown_leaf_cache_key(block, blocks.length()) {
      Some(key) => {
        let rendered = match leaf_cache.get(key) {
          Some(value) => value
          None => {
            let value = render_markdown_block(block)
            leaf_cache.set(key, value)
            value
          }
        }
        if rendered.trim() == "" {
          false
        } else {
          if wrote_any {
            if markdown_needs_blank_line_between(prev_kind, block.kind) {
              out.write_string("\n\n")
            } else {
              out.write_char('\n')
            }
          }
          out.write_string(rendered)
          true
        }
      }
      None =>
        write_markdown_block_with_separator_to(out, block, prev_kind, wrote_any)
    }
    if wrote_block {
      prev_kind = Some(block.kind)
      wrote_any = true
    }
  }
  wrote_any
}

///|
fn markdown_leaf_cache_key(
  block : @core.CoreBlock,
  sibling_count : Int,
) -> String? {
  if sibling_count < 1024 ||
    block.children.length() > 0 ||
    block.text.length() < 24 {
    return None
  }
  let kind = match block.kind {
    Heading => "h"
    Paragraph => "p"
    Code => "c"
    BlockQuote => "q"
    Raw => "r"
    Image => "i"
    _ => return None
  }
  let attrs = block.attrs.to_array()
  attrs.sort_by(fn(left, right) { left.0.compare(right.0) })
  let out = StringBuilder::new(
    size_hint=block.text.length() + attrs.length() * 20,
  )
  out.write_string(kind)
  for entry in attrs {
    out.write_char('\u{0000}')
    out.write_string(entry.0)
    out.write_char('=')
    out.write_string(entry.1)
  }
  out.write_char('\u{0001}')
  out.write_string(block.text)
  Some(out.to_string())
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
fn render_markdown_block(block : @core.CoreBlock) -> String {
  match @core.block_rendered_markdown(block) {
    Some(rendered) => return rendered
    None => ()
  }
  match block.kind {
    Heading => render_markdown_heading(block)
    Paragraph => render_markdown_paragraph(block)
    List => render_markdown_list(block)
    ListItem => render_markdown_list_item(block, 1, false, 0)
    Table => render_markdown_table(block)
    Code => render_markdown_code(block)
    Image => render_markdown_image(block)
    BlockQuote => render_markdown_blockquote(block)
    Raw => render_markdown_raw(block)
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
    Heading => if !rich_inlines_present(block) { Some(true) } else { None }
    Paragraph =>
      if block.attrs.get("note_definition_id") is None &&
        !rich_inlines_present(block) {
        Some(
          @core.block_is_literal(block) ||
          literal_text_block(block) ||
          block.text.trim() != "",
        )
      } else {
        None
      }
    Code => Some(true)
    Image => Some(true)
    _ => None
  }
}

///|
fn write_markdown_block_direct_to(
  out : StringBuilder,
  block : @core.CoreBlock,
) -> Unit {
  match block.kind {
    Heading => write_markdown_heading_to(out, block)
    Paragraph => write_markdown_paragraph_to(out, block)
    Code => write_markdown_code_to(out, block)
    Image => write_markdown_image_to(out, block)
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
  if @core.block_is_literal(block) || literal_text_block(block) {
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
  if literal_text_block(block) || @core.block_is_literal(block) {
    if block.attrs.get("markdown_literal_raw") == Some("true") {
      out.write_string(block.text.trim().to_owned())
      return
    }
    let lines = render_literal_markdown_lines(block.text)
    let mut wrote_any = false
    for line in lines {
      if wrote_any {
        out.write_char('\n')
      }
      out.write_string(line)
      wrote_any = true
    }
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
  let escape_mode = @core.block_inline_escape_mode(block)
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
fn render_markdown_heading(block : @core.CoreBlock) -> String {
  let level = clamp_heading_level(block.attrs.get("level").unwrap_or("1"))
  let prefix = Array::make(level, "#").join("")
  let escaped = if rich_inlines_present(block) {
    render_markdown_inline_text(block).trim().to_owned()
  } else if @core.block_is_literal(block) {
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
    if block.attrs.get("markdown_literal_raw") == Some("true") {
      return block.text.trim().to_owned()
    }
    return render_literal_markdown_lines(block.text).join("\n")
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
  } else if @core.block_is_literal(block) {
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
      List =>
        child_lines.push(render_markdown_list_with_depth(child, depth + 1))
      ListItem =>
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
  if block.attrs.get("toml_compact_table_v1") == Some("true") {
    return render_markdown_compact_toml_table(block)
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
fn render_markdown_compact_toml_table(block : @core.CoreBlock) -> String {
  let rows = block.children
  let header = rows[0].attrs.get("toml_compact_cells_v1").unwrap_or("")
  let width = header.split("\u{0000}").count()
  let out = StringBuilder::new(size_hint=rows.length() * (width * 16 + 4))
  write_markdown_compact_cells(out, header, width)
  out.write_char('\n')
  write_markdown_table_separator(out, width)
  for i in 1..<rows.length() {
    out.write_char('\n')
    write_markdown_compact_cells(
      out,
      rows[i].attrs.get("toml_compact_cells_v1").unwrap_or(""),
      width,
    )
  }
  out.to_string()
}

///|
fn write_markdown_compact_cells(
  out : StringBuilder,
  payload : String,
  width : Int,
) -> Unit {
  out.write_string("| ")
  let mut index = 0
  for ch in payload {
    if ch == '\u{0000}' {
      out.write_string(" | ")
      index += 1
    } else if ch == '|' {
      out.write_string("\\|")
    } else {
      out.write_char(ch)
    }
  }
  index += 1
  while index < width {
    if index > 0 {
      out.write_string(" | ")
    }
    index += 1
  }
  out.write_string(" |")
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
    @core.block_inline_escape_mode(block),
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
            @core.block_inline_escape_mode(block),
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
  let literal = @core.block_is_literal(block)
  let lines = block.text.split("\n").to_array().map(line => line.to_owned())
  if text_markup_semantic_blockquote_markdown(block, lines) is Some(rendered) {
    return rendered
  }
  lines
  .map(line => {
    let text = if literal || literal_text_block(block) {
      line
    } else {
      escape_markdown_inline_text(line)
    }
    "> " + text
  })
  .join("\n")
}

///|
fn text_markup_semantic_blockquote_markdown(
  block : @core.CoreBlock,
  lines : Array[String],
) -> String? {
  if !@core.block_is_literal(block) || lines.length() == 0 {
    return None
  }
  if block.attrs.get("semantic_family") is None &&
    block.attrs.get("quote_kind") is None {
    return None
  }
  let rendered : Array[String] = []
  rendered.push("> " + lines[0])
  for i in 1..<lines.length() {
    rendered.push(lines[i])
  }
  Some(rendered.join("\n"))
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
      if child.kind == List {
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
  match @core.block_rendered_markdown(block) {
    Some(rendered) => if rendered != "" { return true }
    None => ()
  }
  match block.rich_inlines {
    Some(inlines) => inlines.length() > 0
    None => false
  }
}

///|
fn render_markdown_inline_text(block : @core.CoreBlock) -> String {
  match @core.block_rendered_markdown(block) {
    Some(rendered) => return rendered
    None => ()
  }
  let escape_mode = @core.block_inline_escape_mode(block)
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
  if current.kind != Text || current.text != " " {
    return false
  }
  annotation_note_marker_inline(inlines[index - 1]) &&
  annotation_comment_marker_inline(inlines[index + 1])
}

///|
fn annotation_note_marker_inline(inline : @core.CoreInline) -> Bool {
  if inline.kind != Text {
    return false
  }
  inline.attrs.get("annotation_role") == Some("note_ref") &&
  inline.attrs.get("annotation_kind") != Some("comment")
}

///|
fn annotation_comment_marker_inline(inline : @core.CoreInline) -> Bool {
  if inline.kind != Text {
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
    Text => escape_markdown_inline_text_for_format(inline.text, escape_mode)
    LineBreak => "<br>"
    Link => {
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
    Image => {
      let alt = escape_markdown_inline_text_for_format(inline.text, escape_mode)
        .trim()
        .to_owned()
      let path = inline.href.unwrap_or("#").trim().to_owned()
      "![" + alt + "](" + path + ")"
    }
    Code => {
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
    raw_kind == "markdown_footnote_definition" ||
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
fn sparse_table_declared_width(row : @core.CoreBlock) -> Int {
  match row.attrs.get("declared_column_count") {
    Some(raw) => @string.parse_int(raw.trim()) catch { _ => 0 }
    None => 0
  }
}

///|
fn sparse_table_cell_column_index(cell : @core.CoreBlock) -> Int {
  match cell.column_index {
    Some(value) => value
    None =>
      match cell.attrs.get("column_index") {
        Some(raw) => @string.parse_int(raw.trim()) catch { _ => 0 }
        None => 0
      }
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
