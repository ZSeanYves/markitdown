///|
fn html_child_text_append_table(
  state : HtmlChildTextState,
  source : @input.InputSource,
  _text_chars : Array[Char],
  events : Array[@dhtml.HtmlTokenEvent],
  open_index : Int,
) -> Int {
  match state.close_index.get(open_index) {
    Some(close_index) => {
      let open_event = events[open_index]
      match
        html_child_table_block(
          state,
          source,
          _text_chars,
          events,
          open_index,
          close_index,
          state.block_order,
        ) {
        Some(table) => html_child_text_push_block(state, table)
        None => html_child_text_append_table_fallback(state, source, open_event)
      }
      close_index + 1
    }
    None => {
      html_child_text_append_table_fallback(state, source, events[open_index])
      open_index + 1
    }
  }
}

///|
fn html_child_text_append_table_fallback(
  state : HtmlChildTextState,
  source : @input.InputSource,
  event : @dhtml.HtmlTokenEvent,
) -> Unit {
  let paragraph = html_child_text_make_block(
    state,
    source,
    Paragraph,
    event.tag_name,
    event.span.line_start,
    event.span.line_end,
    "/block/html:block:" + event.tag_name + ":" + state.block_order.to_string(),
    byte_start=event.span.byte_start,
    byte_end=event.span.byte_end,
  )
  paragraph.attrs.set("literal", "true")
  paragraph.attrs.set("render_inline_escape_mode", "minimal")
  html_child_text_push_block(state, paragraph)
}

///|
fn html_child_table_block(
  state : HtmlChildTextState,
  source : @input.InputSource,
  text_chars : Array[Char],
  events : Array[@dhtml.HtmlTokenEvent],
  open_index : Int,
  close_index : Int,
  block_order : Int,
) -> @core.CoreBlock? {
  let open_event = events[open_index]
  let close_event = events[close_index]
  let rows : Array[@core.CoreBlock] = []
  let mut header_rows = 0
  let mut index = open_index + 1
  let mut row_order = 0
  while index < close_index {
    let event = events[index]
    if event.kind == StartTag && event.tag_name == "tr" {
      match state.close_index.get(index) {
        Some(row_close) =>
          if row_close <= close_index {
            row_order += 1
            match
              html_child_table_row_block(
                state, source, text_chars, events, index, row_close, row_order,
              ) {
              Some(row) => {
                rows.push(row.0)
                if row.1 {
                  header_rows += 1
                }
                index = row_close + 1
                continue
              }
              None => ()
            }
          }
        None => ()
      }
    }
    index += 1
  }
  if rows.length() == 0 {
    return None
  }
  let table = html_child_text_make_block(
    state,
    source,
    Table,
    "table",
    open_event.span.line_start,
    close_event.span.line_end,
    "/block/html:block:table:" + block_order.to_string(),
    byte_start=open_event.span.byte_start,
    byte_end=close_event.span.byte_end,
  )
  if state.compact_provenance {
    match html_child_compact_table_markdown(rows, header_rows) {
      Some(rendered) =>
        return Some(@core.block_with_rendered_markdown(table, rendered))
      None => ()
    }
  }
  table.attrs.set("header_rows", html_child_table_header_rows(rows).to_string())
  table.attrs.set(
    "table_column_count",
    html_child_table_column_count(rows).to_string(),
  )
  if header_rows > 0 {
    table.attrs.set("header_rows", header_rows.to_string())
  }
  Some(@core.block_with_children(table, rows))
}

///|
fn html_child_compact_table_markdown(
  rows : Array[@core.CoreBlock],
  header_rows : Int,
) -> String? {
  if rows.length() == 0 || header_rows <= 0 {
    return None
  }
  let width = rows[0].children.length()
  if width == 0 {
    return None
  }
  let out = StringBuilder::new()
  for row_index in 0..<rows.length() {
    let row = rows[row_index]
    if row.children.length() != width {
      return None
    }
    if row_index > 0 {
      out.write_char('\n')
    }
    out.write_string("| ")
    for cell_index in 0..<width {
      if cell_index > 0 {
        out.write_string(" | ")
      }
      match html_child_compact_table_cell_text(row.children[cell_index]) {
        Some(text) => out.write_string(text)
        None => return None
      }
    }
    out.write_string(" |")
    if row_index == 0 {
      out.write_char('\n')
      out.write_string("| ")
      for column in 0..<width {
        if column > 0 {
          out.write_string(" | ")
        }
        out.write_string("---")
      }
      out.write_string(" |")
    }
  }
  Some(out.to_string())
}

///|
fn html_child_compact_table_cell_text(cell : @core.CoreBlock) -> String? {
  match cell.rich_inlines {
    Some(inlines) =>
      if !inlines.all(inline => inline.kind == Text) {
        return None
      }
    None => ()
  }
  let text = cell.text.trim().to_owned()
  if text.contains("|") ||
    text.contains("\n") ||
    text.contains("\r") ||
    text.contains("\\") ||
    text.contains("`") {
    return None
  }
  Some(text)
}

///|
fn html_child_table_row_block(
  state : HtmlChildTextState,
  source : @input.InputSource,
  text_chars : Array[Char],
  events : Array[@dhtml.HtmlTokenEvent],
  open_index : Int,
  close_index : Int,
  row_order : Int,
) -> (@core.CoreBlock, Bool)? {
  let open_event = events[open_index]
  let close_event = events[close_index]
  let row = html_child_text_make_block(
    state,
    source,
    TableRow,
    "",
    open_event.span.line_start,
    close_event.span.line_end,
    "/table-row/html:table-row:" + row_order.to_string(),
    byte_start=open_event.span.byte_start,
    byte_end=close_event.span.byte_end,
  )
  row.attrs.set("literal", "true")
  let cells : Array[@core.CoreBlock] = []
  let mut header_cell_count = 0
  let mut index = open_index + 1
  while index < close_index {
    let event = events[index]
    let tag = event.tag_name
    if event.kind == StartTag && (tag == "td" || tag == "th") {
      match state.close_index.get(index) {
        Some(cell_close) =>
          if cell_close <= close_index {
            match
              html_child_table_cell_block(
                state,
                source,
                text_chars,
                events,
                index,
                cell_close,
                cells.length() + 1,
              ) {
              Some(cell) => {
                cells.push(cell)
                if tag == "th" {
                  header_cell_count += 1
                }
                index = cell_close + 1
                continue
              }
              None => ()
            }
          }
        None => ()
      }
    }
    index += 1
  }
  if cells.length() == 0 {
    return None
  }
  let row = { ..row, text: cells.map(cell => cell.text).join(" | ") }
  let row = @core.block_with_children(row, cells)
  Some((row, header_cell_count == cells.length()))
}

///|
fn html_child_table_cell_block(
  state : HtmlChildTextState,
  source : @input.InputSource,
  text_chars : Array[Char],
  events : Array[@dhtml.HtmlTokenEvent],
  open_index : Int,
  close_index : Int,
  cell_order : Int,
) -> @core.CoreBlock? {
  let open_event = events[open_index]
  let close_event = events[close_index]
  let inlines = html_child_table_collect_inlines(
    state,
    source,
    text_chars,
    events,
    open_index + 1,
    close_index,
  )
  let text = html_render_plain_inlines(inlines).trim().to_owned()
  if text == "" {
    return None
  }
  let cell = html_child_text_make_block(
    state,
    source,
    TableCell,
    text,
    open_event.span.line_start,
    close_event.span.line_end,
    "/table-cell/html:table-cell:" + cell_order.to_string(),
    byte_start=open_event.span.byte_start,
    byte_end=close_event.span.byte_end,
  )
  cell.attrs.set("literal", "true")
  cell.attrs.set("render_inline_escape_mode", "minimal")
  if inlines.length() > 0 {
    Some(@core.block_with_rich_inlines(cell, Some(inlines)))
  } else {
    Some(cell)
  }
}

///|
fn html_child_table_collect_inlines(
  state : HtmlChildTextState,
  source : @input.InputSource,
  text_chars : Array[Char],
  events : Array[@dhtml.HtmlTokenEvent],
  start_index : Int,
  end_index : Int,
) -> Array[@core.CoreInline] {
  let out : Array[@core.CoreInline] = []
  let mut index = start_index
  let mut pending_space = false
  while index < end_index {
    let event = events[index]
    let tag = event.tag_name
    if event.kind == StartTag {
      if tag == "br" {
        out.push(
          @core.make_inline_line_break(
            source_ref=html_token_lines_source_ref(
              source,
              event.span.line_start,
              event.span.line_end,
              "/inline/html:inline:br:" + out.length().to_string(),
            ),
          ),
        )
        pending_space = false
      } else if tag == "img" {
        if pending_space && out.length() > 0 {
          out.push(
            @core.make_inline_text(
              " ",
              source_ref=html_token_lines_source_ref(
                source,
                event.span.line_start,
                event.span.line_end,
                "/inline/html:inline:text:" + out.length().to_string(),
              ),
            ),
          )
        }
        html_child_table_append_image_inline(state, source, event, out)
        pending_space = false
      } else if tag == "a" {
        match state.close_index.get(index) {
          Some(link_close) if link_close <= end_index => {
            let text = html_render_plain_inlines(
                html_child_table_collect_inlines(
                  state,
                  source,
                  text_chars,
                  events,
                  index + 1,
                  link_close,
                ),
              )
              .trim()
              .to_owned()
            if text != "" {
              if pending_space && out.length() > 0 {
                out.push(
                  @core.make_inline_text(
                    " ",
                    source_ref=html_token_lines_source_ref(
                      source,
                      event.span.line_start,
                      events[link_close].span.line_end,
                      "/inline/html:inline:text:" + out.length().to_string(),
                    ),
                  ),
                )
              }
              match html_child_text_event_href(event) {
                Some(href) =>
                  out.push(
                    @core.make_inline_link(
                      text,
                      href,
                      source_ref=html_token_lines_source_ref(
                        source,
                        event.span.line_start,
                        events[link_close].span.line_end,
                        "/inline/html:inline:a:" + out.length().to_string(),
                      ),
                    ),
                  )
                None =>
                  out.push(
                    @core.make_inline_text(
                      text,
                      source_ref=html_token_lines_source_ref(
                        source,
                        event.span.line_start,
                        events[link_close].span.line_end,
                        "/inline/html:inline:text:" + out.length().to_string(),
                      ),
                    ),
                  )
              }
            }
            index = link_close
          }
          _ => ()
        }
        pending_space = false
      } else if html_child_table_spacing_tag(tag) && out.length() > 0 {
        pending_space = true
      }
    }
    if event.kind == EndTag &&
      html_child_table_spacing_tag(tag) &&
      out.length() > 0 {
      pending_space = true
    }
    if event.kind == Text {
      let raw = html_scope_event_text(text_chars, event)
      let compact = html_compact_token_text(raw)
      if compact == "" {
        if out.length() > 0 {
          pending_space = true
        }
      } else {
        let text = if pending_space && out.length() > 0 {
          " " + compact
        } else {
          compact
        }
        out.push(
          @core.make_inline_text(
            text,
            source_ref=html_token_lines_source_ref(
              source,
              event.span.line_start,
              event.span.line_end,
              "/inline/html:inline:text:" + out.length().to_string(),
            ),
          ),
        )
        pending_space = false
      }
    }
    index += 1
  }
  html_merge_adjacent_text_inlines(out)
}

///|
fn html_child_table_spacing_tag(tag : String) -> Bool {
  tag == "p" ||
  tag == "div" ||
  tag == "li" ||
  tag == "blockquote" ||
  tag == "pre" ||
  tag == "ul" ||
  tag == "ol"
}

///|
fn html_child_table_append_image_inline(
  state : HtmlChildTextState,
  source : @input.InputSource,
  event : @dhtml.HtmlTokenEvent,
  out : Array[@core.CoreInline],
) -> Unit {
  let src = @dhtml.html_token_event_attr_value(event, "src")
    .unwrap_or("")
    .trim()
    .to_owned()
  let alt = @dhtml.html_token_event_attr_value(event, "alt")
    .unwrap_or("image")
    .trim()
    .to_owned()
  let kind = html_child_image_kind(src)
  let source_ref = html_token_lines_source_ref(
    source,
    event.span.line_start,
    event.span.line_end,
    "/inline/html:inline:img:" + out.length().to_string(),
  )
  match kind {
    Local =>
      match html_child_local_image_asset(state, source_ref, src, alt) {
        Some(asset) =>
          out.push(
            @core.make_inline_image(alt, asset.path.unwrap_or("#"), source_ref~),
          )
        None => out.push(@core.make_inline_text("[image]", source_ref~))
      }
    Remote => {
      state.diagnostics.degraded_features.push(
        "html_remote_image_reference_only",
      )
      out.push(@core.make_inline_text("[remote]", source_ref~))
    }
    DataUri => {
      state.diagnostics.degraded_features.push("html_data_image_reference_only")
      out.push(@core.make_inline_text("[inline data]", source_ref~))
    }
    _ =>
      out.push(
        @core.make_inline_text(
          html_image_placeholder_text(kind, alt),
          source_ref~,
        ),
      )
  }
}

///|
fn html_child_table_header_rows(rows : Array[@core.CoreBlock]) -> Int {
  if rows.length() == 0 {
    return 0
  }
  0
}

///|
fn html_child_table_column_count(rows : Array[@core.CoreBlock]) -> Int {
  let mut best = 0
  for row in rows {
    if row.children.length() > best {
      best = row.children.length()
    }
  }
  best
}

///|
fn html_child_text_event_href(event : @dhtml.HtmlTokenEvent) -> String? {
  html_child_text_href_from_attributes(event.attributes)
}

///|
fn html_child_text_href_from_attributes(
  attributes : Array[@dhtml.HtmlAttribute],
) -> String? {
  let href = @dhtml.html_attributes_value(attributes, "href")
    .unwrap_or("")
    .trim()
    .to_owned()
  if href == "" {
    return None
  }
  let lower = href.to_lower()
  if lower.has_prefix("javascript:") ||
    lower.has_prefix("vbscript:") ||
    lower.has_prefix("data:") {
    return None
  }
  Some(href)
}

///|
fn html_token_lower_event(
  state : HtmlTokenBlockState,
  source : @input.InputSource,
  text_chars : Array[Char],
  event : @dhtml.HtmlTokenEvent,
) -> Unit {
  if state.skip_depth > 0 {
    if event.kind == StartTag && !event.self_closing {
      state.skip_depth += 1
    } else if event.kind == EndTag {
      state.skip_depth -= 1
    }
    return
  }
  match event.kind {
    Text => html_token_append_text(state, text_chars, event)
    StartTag => html_token_start_tag(state, source, event)
    EndTag => html_token_end_tag(state, source, event)
    Comment | Doctype => ()
  }
}

///|
fn html_token_start_tag(
  state : HtmlTokenBlockState,
  source : @input.InputSource,
  event : @dhtml.HtmlTokenEvent,
) -> Unit {
  let tag = event.tag_name
  if html_scope_event_should_skip(event) || html_token_skip_tag(tag) {
    if !event.self_closing {
      state.skip_depth = 1
    }
    return
  }
  let heading = html_heading_level(tag)
  if heading > 0 {
    html_token_flush_text_block(state, source)
    state.text_kind = Heading
    state.heading_level = heading
    state.text_start_line = event.span.line_start
    state.text_end_line = event.span.line_end
    return
  }
  if tag == "p" ||
    tag == "section" ||
    tag == "article" ||
    tag == "main" ||
    tag == "div" ||
    tag == "header" {
    html_token_flush_text_block(state, source)
    state.text_kind = Paragraph
    state.text_start_line = event.span.line_start
    state.text_end_line = event.span.line_end
  } else if tag == "br" {
    state.text.write_char('\n')
  } else if tag == "pre" {
    html_token_flush_text_block(state, source)
    state.in_pre = true
    state.text_kind = Code
    state.text_start_line = event.span.line_start
    state.text_end_line = event.span.line_end
  } else if tag == "li" {
    html_token_flush_text_block(state, source)
    state.text_kind = ListItem
    state.text_start_line = event.span.line_start
    state.text_end_line = event.span.line_end
  } else if tag == "ul" || tag == "ol" {
    state.list_depth += 1
  } else if tag == "blockquote" {
    html_token_flush_text_block(state, source)
    state.quote_depth += 1
    state.text_kind = BlockQuote
    state.text_start_line = event.span.line_start
    state.text_end_line = event.span.line_end
  } else if tag == "hr" {
    html_token_flush_text_block(state, source)
    let block = @core.make_block(
      Raw,
      "---",
      source_ref=html_token_source_ref(source, event, "/html_token/hr"),
    )
    block.attrs.set("raw_kind", "markdown")
    state.blocks.push(block)
  } else if tag == "img" {
    html_token_flush_text_block(state, source)
    let image = @core.make_block(
      Image,
      "",
      source_ref=html_token_source_ref(source, event, "/html_token/img"),
    )
    image.attrs.set(
      "alt",
      @dhtml.html_token_event_attr_value(event, "alt").unwrap_or("image"),
    )
    image.attrs.set(
      "path",
      @dhtml.html_token_event_attr_value(event, "src").unwrap_or("#"),
    )
    image.attrs.set("render_inline_escape_mode", "minimal")
    state.blocks.push(image)
  }
}

///|
fn html_token_end_tag(
  state : HtmlTokenBlockState,
  source : @input.InputSource,
  event : @dhtml.HtmlTokenEvent,
) -> Unit {
  let tag = event.tag_name
  if html_heading_level(tag) > 0 ||
    tag == "p" ||
    tag == "li" ||
    tag == "pre" ||
    tag == "blockquote" ||
    tag == "section" ||
    tag == "article" ||
    tag == "main" {
    state.text_end_line = event.span.line_end
    html_token_flush_text_block(state, source)
    state.text_kind = Paragraph
    state.heading_level = 0
    if tag == "pre" {
      state.in_pre = false
    }
    if tag == "blockquote" && state.quote_depth > 0 {
      state.quote_depth -= 1
    }
  } else if (tag == "ul" || tag == "ol") && state.list_depth > 0 {
    state.list_depth -= 1
  }
}

///|
fn html_token_append_text(
  state : HtmlTokenBlockState,
  text_chars : Array[Char],
  event : @dhtml.HtmlTokenEvent,
) -> Unit {
  let raw = html_scope_event_text(text_chars, event)
  let text = if state.in_pre { raw } else { html_compact_token_text(raw) }
  if text.trim() == "" {
    return
  }
  if state.text_start_line == 0 {
    state.text_start_line = event.span.line_start
  }
  state.text_end_line = event.span.line_end
  if state.text_has_content && !state.in_pre {
    state.text.write_char(' ')
  }
  state.text.write_string(text)
  state.text_has_content = true
}

///|
fn html_token_flush_text_block(
  state : HtmlTokenBlockState,
  source : @input.InputSource,
) -> Unit {
  let text = if state.in_pre {
    state.text.to_string()
  } else {
    state.text.to_string().trim().to_owned()
  }
  if text == "" {
    state.text = StringBuilder::new()
    state.text_has_content = false
    return
  }
  let source_ref = html_token_lines_source_ref(
    source,
    state.text_start_line,
    state.text_end_line,
    "/html_token/block[" + state.blocks.length().to_string() + "]",
  )
  let block = @core.make_block(state.text_kind, text, source_ref~)
  if state.text_kind == Heading {
    block.attrs.set(
      "level",
      if state.heading_level <= 0 {
        "1"
      } else {
        state.heading_level.to_string()
      },
    )
    block.attrs.set("render_inline_escape_mode", "minimal")
  } else if state.text_kind == ListItem {
    block.attrs.set("ordered", "false")
    block.attrs.set("render_inline_escape_mode", "minimal")
  } else if state.text_kind == Paragraph || state.text_kind == BlockQuote {
    block.attrs.set("render_inline_escape_mode", "minimal")
  } else if state.text_kind == Code {
    block.attrs.set("info", "")
  }
  state.blocks.push(block)
  state.text = StringBuilder::new()
  state.text_has_content = false
  state.text_start_line = 0
  state.text_end_line = 0
}

///|
fn html_scope_event_text(
  text_chars : Array[Char],
  event : @dhtml.HtmlTokenEvent,
) -> String {
  let start = if event.source_start < 0 { 0 } else { event.source_start }
  let end0 = if event.source_end > text_chars.length() {
    text_chars.length()
  } else {
    event.source_end
  }
  if end0 <= start {
    return ""
  }
  @dhtml.decode_html_entities(
    String::from_array(text_chars[start:end0].to_owned()),
  )
}

///|
fn html_compact_token_text(text : String) -> String {
  let out = StringBuilder::new()
  let mut pending_space = false
  let mut wrote_non_space = false
  for ch in text.to_array() {
    if html_ascii_space_like(ch) {
      pending_space = true
    } else {
      if pending_space && wrote_non_space {
        out.write_char(' ')
      }
      out.write_char(ch)
      wrote_non_space = true
      pending_space = false
    }
  }
  out.to_string().trim().to_owned()
}

///|
fn html_token_skip_tag(tag : String) -> Bool {
  tag == "script" ||
  tag == "style" ||
  tag == "template" ||
  tag == "noscript" ||
  tag == "svg" ||
  tag == "math"
}

///|
fn html_token_source_ref(
  source : @input.InputSource,
  event : @dhtml.HtmlTokenEvent,
  html_path : String,
) -> @core.SourceRef {
  html_token_lines_source_ref(
    source,
    event.span.line_start,
    event.span.line_end,
    html_path,
  )
}

///|
fn html_token_lines_source_ref(
  source : @input.InputSource,
  line_start : Int,
  line_end : Int,
  html_path : String,
  byte_start? : Int = -1,
  byte_end? : Int = -1,
) -> @core.SourceRef {
  let source_ref = @core.source_ref_with_html_path(
    @core.source_ref_with_lines(
      @core.empty_source_ref(),
      Some(source.source_name),
      Some("html"),
      Some(if line_start <= 0 { 1 } else { line_start }),
      Some(if line_end <= 0 { line_start } else { line_end }),
    ),
    Some(source.source_name),
    Some("html"),
    Some(html_path),
  )
  if byte_start >= 0 && byte_end >= byte_start {
    { ..source_ref, byte_start: Some(byte_start), byte_end: Some(byte_end) }
  } else {
    source_ref
  }
}
