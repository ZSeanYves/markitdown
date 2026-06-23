///|
pub struct RenderContext {
  debug : Bool
}

///|
pub struct RenderResult {
  content : String
  diagnostics : @core.Diagnostics
}

///|
pub struct Renderer {
  name : String
  render : (@core.DocumentIR, RenderContext) -> RenderResult
}

///|
pub fn make_render_context(debug : Bool) -> RenderContext {
  { debug, }
}

///|
pub fn markdown_renderer() -> Renderer {
  {
    name: "MarkdownRenderer",
    render: fn(
      document : @core.DocumentIR,
      _context : RenderContext,
    ) -> RenderResult {
      document.diagnostics.metrics.set("renderer_name", "MarkdownRenderer")
      {
        content: render_markdown_document(document),
        diagnostics: document.diagnostics,
      }
    },
  }
}

///|
pub fn debug_json_renderer() -> Renderer {
  {
    name: "DebugJsonRenderer",
    render: fn(
      document : @core.DocumentIR,
      _context : RenderContext,
    ) -> RenderResult {
      document.diagnostics.metrics.set("renderer_name", "DebugJsonRenderer")
      {
        content: render_debug_json_document(document),
        diagnostics: document.diagnostics,
      }
    },
  }
}

///|
pub fn render_markdown_document(document : @core.DocumentIR) -> String {
  let parts : Array[String] = []
  let mut prev_kind : @core.BlockKind? = None
  for block in document.blocks {
    let rendered = render_markdown_block(block)
    if rendered.trim() != "" {
      if parts.length() > 0 &&
        markdown_needs_blank_line_between(prev_kind, block.kind) {
        parts.push("")
      }
      parts.push(rendered)
      prev_kind = Some(block.kind)
    }
  }
  parts.join("\n")
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
pub fn render_debug_json_document(document : @core.DocumentIR) -> String {
  let block_items : Array[String] = []
  for block in document.blocks {
    block_items.push(render_block_json(block))
  }
  let asset_items : Array[String] = []
  for asset in document.assets {
    asset_items.push(render_asset_json(asset))
  }
  let fields : Array[String] = []
  fields.push("\"block_count\": " + document.blocks.length().to_string())
  fields.push("\"blocks\": " + @core.array_json(block_items))
  fields.push("\"asset_count\": " + document.assets.length().to_string())
  fields.push("\"assets\": " + @core.array_json(asset_items))
  fields.push(
    "\"diagnostics\": " + render_diagnostics_json(document.diagnostics),
  )
  @core.object_json(fields)
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
  Array::make(width, " ").join("")
}

///|
fn indent_rendered_block(text : String, depth : Int) -> String {
  let indent = list_item_indent_for_marker(depth, false, 2)
  text
  .split("\n")
  .to_array()
  .map(line => {
    let owned = line.to_owned()
    if owned.trim() == "" {
      owned
    } else {
      indent + owned
    }
  })
  .join("\n")
}

///|
fn render_markdown_table(block : @core.CoreBlock) -> String {
  if block.children.length() == 0 {
    return render_markdown_raw(
      @core.block_with_attr(block, "raw_kind", "empty_table_fallback"),
    )
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
    out.write_char('\n')
    write_markdown_table_row(out, table_row_cells(rows[i]), width)
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
  out.to_string().trim().to_owned()
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
  Array::make(width, "`").join("")
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
  Array::make(width, "`").join("")
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
fn escape_markdown_inline_text(text : String) -> String {
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
    if markdown_punctuation_needs_escape(ch) {
      out.write_char('\\')
    }
    out.write_char(ch)
  }
  out.to_string()
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
fn escape_markdown_inline_text_html(text : String) -> String {
  let out = StringBuilder::new()
  for ch in text.to_array() {
    if ch == '\\' || ch == '`' {
      out.write_char('\\')
    }
    out.write_char(ch)
  }
  out.to_string()
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
    "\"fallback_trace\": " + @core.string_array_json(diagnostics.fallback_trace),
  )
  fields.push(
    "\"pass_trace\": " + @core.string_array_json(diagnostics.pass_trace),
  )
  fields.push("\"metrics\": " + @core.object_json(metric_fields))
  @core.object_json(fields)
}
