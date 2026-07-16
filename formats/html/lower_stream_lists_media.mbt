///|
fn html_child_text_end_tag(
  state : HtmlChildTextState,
  source : @input.InputSource,
  event : @dhtml.HtmlTokenEvent,
) -> Unit {
  let tag = event.tag_name
  if tag == "a" {
    state.link_line_end = event.span.line_end
    html_child_text_flush_link(state, source)
    return
  }
  if tag == "p" {
    match state.current {
      Some(current) =>
        if current.kind == BlockQuote {
          current.line_end = event.span.line_end
          current.byte_end = event.span.byte_end
          return
        }
      None => ()
    }
  }
  let heading = html_heading_level(tag)
  if heading > 0 || tag == "p" || tag == "pre" || tag == "blockquote" {
    match state.current {
      Some(current) => {
        current.line_end = event.span.line_end
        current.byte_end = event.span.byte_end
      }
      None => ()
    }
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    return
  }
  if tag == "li" {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    html_child_text_close_list_item(
      state,
      source,
      event.span.line_end,
      event.span.byte_end,
    )
    return
  }
  if tag == "ul" || tag == "ol" {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    html_child_text_close_list(
      state,
      source,
      event.span.line_end,
      event.span.byte_end,
    )
  }
}

///|
fn html_child_text_end_tag_fields(
  state : HtmlChildTextState,
  source : @input.InputSource,
  tag : String,
  line_end : Int,
  byte_end : Int,
) -> Unit {
  if tag == "a" {
    state.link_line_end = line_end
    html_child_text_flush_link(state, source)
    return
  }
  if tag == "p" {
    match state.current {
      Some(current) =>
        if current.kind == BlockQuote {
          current.line_end = line_end
          current.byte_end = byte_end
          return
        }
      None => ()
    }
  }
  let heading = html_heading_level(tag)
  if heading > 0 || tag == "p" || tag == "pre" || tag == "blockquote" {
    match state.current {
      Some(current) => {
        current.line_end = line_end
        current.byte_end = byte_end
      }
      None => ()
    }
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    return
  }
  if tag == "li" {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    html_child_text_close_list_item(state, source, line_end, byte_end)
    return
  }
  if tag == "ul" || tag == "ol" {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    html_child_text_close_list(state, source, line_end, byte_end)
  }
}

///|
fn html_child_text_open_link(
  state : HtmlChildTextState,
  event : @dhtml.HtmlTokenEvent,
) -> Unit {
  if state.link_depth == 0 {
    state.link_text = StringBuilder::new()
    state.link_href = html_child_text_event_href(event)
    state.link_line_start = event.span.line_start
    state.link_line_end = event.span.line_end
    state.link_pending_space = false
    state.link_has_content = false
  }
  state.link_depth += 1
}

///|
fn html_child_text_open_link_fields(
  state : HtmlChildTextState,
  attributes : Array[@dhtml.HtmlAttribute],
  line_start : Int,
  line_end : Int,
) -> Unit {
  if state.link_depth == 0 {
    state.link_text = StringBuilder::new()
    state.link_href = html_child_text_href_from_attributes(attributes)
    state.link_line_start = line_start
    state.link_line_end = line_end
    state.link_pending_space = false
    state.link_has_content = false
  }
  state.link_depth += 1
}

///|
fn html_child_text_flush_link(
  state : HtmlChildTextState,
  source : @input.InputSource,
) -> Unit {
  if state.link_depth == 0 {
    return
  }
  state.link_depth = 0
  let trailing_space = state.link_pending_space
  let text = state.link_text.to_string().trim().to_owned()
  state.link_text = StringBuilder::new()
  state.link_pending_space = false
  state.link_has_content = false
  if text == "" {
    state.link_href = None
    return
  }
  match state.current {
    Some(current) => {
      html_child_inline_materialize_pending_text(state, source, current)
      if current.inline_state.pending_space && current.inline_state.has_content {
        if state.compact_provenance {
          current.inline_state.compact_plain.write_char(' ')
          current.inline_state.compact_markdown.write_char(' ')
        } else {
          state.inline_order += 1
          current.inline_state.inlines.push(
            html_child_text_make_inline_text(
              state,
              source,
              " ",
              state.link_line_start,
              state.link_line_end,
              "/inline/html:inline:text:" + state.inline_order.to_string(),
            ),
          )
        }
      }
      if state.compact_provenance {
        current.inline_state.compact_plain.write_string(text)
        match state.link_href {
          Some(href) => {
            let target = href.trim().to_owned()
            if target == "" {
              html_child_write_minimal_markdown(
                current.inline_state.compact_markdown,
                text,
              )
            } else {
              current.inline_state.compact_markdown.write_char('[')
              html_child_write_minimal_markdown(
                current.inline_state.compact_markdown,
                text,
              )
              current.inline_state.compact_markdown.write_string("](")
              current.inline_state.compact_markdown.write_string(target)
              current.inline_state.compact_markdown.write_char(')')
              current.inline_state.compact_has_markup = true
            }
          }
          None =>
            html_child_write_minimal_markdown(
              current.inline_state.compact_markdown,
              text,
            )
        }
      } else {
        state.inline_order += 1
        match state.link_href {
          Some(href) =>
            current.inline_state.inlines.push(
              html_child_text_make_inline_link(
                state,
                source,
                text,
                href,
                state.link_line_start,
                state.link_line_end,
                "/inline/html:inline:a:" + state.inline_order.to_string(),
              ),
            )
          None =>
            current.inline_state.inlines.push(
              html_child_text_make_inline_text(
                state,
                source,
                text,
                state.link_line_start,
                state.link_line_end,
                "/inline/html:inline:a:" + state.inline_order.to_string(),
              ),
            )
        }
      }
      current.inline_state.has_content = true
      current.inline_state.pending_space = trailing_space
    }
    None => ()
  }
  state.link_href = None
}

///|
fn html_child_text_append_line_break(
  state : HtmlChildTextState,
  source : @input.InputSource,
  event : @dhtml.HtmlTokenEvent,
) -> Unit {
  match state.current {
    Some(current) => {
      html_child_text_flush_link(state, source)
      html_child_inline_materialize_pending_text(state, source, current)
      if state.compact_provenance {
        current.inline_state.compact_plain.write_string("<br>")
        current.inline_state.compact_markdown.write_string("<br>")
        current.inline_state.compact_has_markup = true
      } else {
        state.inline_order += 1
        current.inline_state.inlines.push(
          html_child_text_make_inline_line_break(
            state,
            source,
            event.span.line_start,
            event.span.line_end,
            "/inline/html:inline:br:" + state.inline_order.to_string(),
          ),
        )
      }
      current.inline_state.has_content = true
      current.inline_state.pending_space = false
      current.line_end = event.span.line_end
    }
    None => ()
  }
}

///|
fn html_child_text_append_line_break_fields(
  state : HtmlChildTextState,
  source : @input.InputSource,
  line_start : Int,
  line_end : Int,
) -> Unit {
  match state.current {
    Some(current) => {
      html_child_text_flush_link(state, source)
      html_child_inline_materialize_pending_text(state, source, current)
      if state.compact_provenance {
        current.inline_state.compact_plain.write_string("<br>")
        current.inline_state.compact_markdown.write_string("<br>")
        current.inline_state.compact_has_markup = true
      } else {
        state.inline_order += 1
        current.inline_state.inlines.push(
          html_child_text_make_inline_line_break(
            state,
            source,
            line_start,
            line_end,
            "/inline/html:inline:br:" + state.inline_order.to_string(),
          ),
        )
      }
      current.inline_state.has_content = true
      current.inline_state.pending_space = false
      current.line_end = line_end
    }
    None => ()
  }
}

///|
fn html_child_text_append_text(
  state : HtmlChildTextState,
  _source : @input.InputSource,
  text_chars : Array[Char],
  event : @dhtml.HtmlTokenEvent,
) -> Unit {
  let raw = html_scope_event_text(text_chars, event)
  match state.current {
    Some(current) => {
      let leading_space = current.kind != Code &&
        html_text_has_leading_space_like(raw)
      let text = if current.kind == Code {
        raw
      } else {
        html_compact_token_text(raw)
      }
      if text == "" {
        if current.kind != Code && current.inline_state.has_content {
          current.inline_state.pending_space = true
        }
        return
      }
      current.line_end = event.span.line_end
      if state.link_depth > 0 {
        let normalized = if current.kind != Code &&
          state.link_has_content &&
          (state.link_pending_space || leading_space) {
          " " + text
        } else {
          text
        }
        state.link_text.write_string(normalized)
        state.link_line_end = event.span.line_end
        state.link_pending_space = current.kind != Code &&
          html_text_has_trailing_space_like(raw)
        state.link_has_content = true
      } else {
        let normalized = if current.kind != Code &&
          current.inline_state.has_content &&
          (current.inline_state.pending_space || leading_space) {
          " " + text
        } else {
          text
        }
        html_child_inline_append_text(
          current.inline_state,
          normalized,
          event.span.line_start,
          event.span.line_end,
        )
        current.inline_state.pending_space = current.kind != Code &&
          html_text_has_trailing_space_like(raw)
      }
      current.inline_state.has_content = true
    }
    None => ()
  }
}

///|
fn html_child_text_append_text_value(
  state : HtmlChildTextState,
  raw : String,
  line_start : Int,
  line_end : Int,
) -> Unit {
  match state.current {
    Some(current) => {
      let leading_space = current.kind != Code &&
        html_text_has_leading_space_like(raw)
      let text = if current.kind == Code {
        raw
      } else {
        html_compact_token_text(raw)
      }
      if text == "" {
        if current.kind != Code && current.inline_state.has_content {
          current.inline_state.pending_space = true
        }
        return
      }
      current.line_end = line_end
      if state.link_depth > 0 {
        let normalized = if current.kind != Code &&
          state.link_has_content &&
          (state.link_pending_space || leading_space) {
          " " + text
        } else {
          text
        }
        state.link_text.write_string(normalized)
        state.link_line_end = line_end
        state.link_pending_space = current.kind != Code &&
          html_text_has_trailing_space_like(raw)
        state.link_has_content = true
      } else {
        let normalized = if current.kind != Code &&
          current.inline_state.has_content &&
          (current.inline_state.pending_space || leading_space) {
          " " + text
        } else {
          text
        }
        html_child_inline_append_text(
          current.inline_state,
          normalized,
          line_start,
          line_end,
        )
        current.inline_state.pending_space = current.kind != Code &&
          html_text_has_trailing_space_like(raw)
      }
      current.inline_state.has_content = true
    }
    None => ()
  }
}

///|
fn html_child_text_flush_block(
  state : HtmlChildTextState,
  source : @input.InputSource,
) -> Unit {
  match state.current {
    Some(current) => {
      let text = if state.compact_provenance {
        html_child_inline_materialize_pending_text(state, source, current)
        current.inline_state.compact_plain.to_string().trim().to_owned()
      } else if current.inline_state.inlines.length() == 0 {
        current.inline_state.text.to_string().trim().to_owned()
      } else {
        html_child_inline_materialize_pending_text(state, source, current)
        html_render_plain_inlines(
          html_trim_core_inlines_edges(current.inline_state.inlines),
        )
        .trim()
        .to_owned()
      }
      if text != "" {
        let block = html_child_text_make_block(
          state,
          source,
          current.kind,
          text,
          current.line_start,
          current.line_end,
          current.html_path,
          byte_start=current.byte_start,
          byte_end=current.byte_end,
        )
        if current.kind == Heading {
          block.attrs.set("level", current.level.to_string())
          let rendered_block = if state.compact_provenance {
            @core.block_with_literal_rendering(
              block,
              minimal_inline_escape=true,
            )
          } else {
            block.attrs.set("literal", "true")
            block.attrs.set("render_inline_escape_mode", "minimal")
            block
          }
          let rich = html_trim_core_inlines_edges(current.inline_state.inlines)
          if state.compact_provenance && current.inline_state.compact_has_markup {
            html_child_text_push_block(
              state,
              @core.block_with_rendered_markdown(
                rendered_block,
                current.inline_state.compact_markdown
                .to_string()
                .trim()
                .to_owned(),
              ),
            )
          } else if html_child_text_requires_rich_inlines(rich) {
            html_child_text_push_block(
              state,
              @core.block_with_rich_inlines(rendered_block, Some(rich)),
            )
          } else {
            html_child_text_push_block(state, rendered_block)
          }
        } else if current.kind == Code {
          block.attrs.set("info", current.info)
          html_child_text_push_block(state, block)
        } else {
          let rendered_block = if state.compact_provenance {
            @core.block_with_literal_rendering(
              block,
              minimal_inline_escape=true,
            )
          } else {
            block.attrs.set("literal", "true")
            block.attrs.set("render_inline_escape_mode", "minimal")
            block
          }
          let rich = html_trim_core_inlines_edges(current.inline_state.inlines)
          let final_block = if state.compact_provenance &&
            current.inline_state.compact_has_markup {
            @core.block_with_rendered_markdown(
              rendered_block,
              current.inline_state.compact_markdown
              .to_string()
              .trim()
              .to_owned(),
            )
          } else if html_child_text_requires_rich_inlines(rich) {
            @core.block_with_rich_inlines(rendered_block, Some(rich))
          } else {
            rendered_block
          }
          html_child_text_push_block(state, final_block)
        }
      }
      state.current = None
    }
    None => ()
  }
}

///|
fn html_child_text_requires_rich_inlines(
  inlines : Array[@core.CoreInline],
) -> Bool {
  for inline in inlines {
    match inline.kind {
      Link | LineBreak => return true
      _ => ()
    }
  }
  false
}

///|
fn html_child_text_push_block(
  state : HtmlChildTextState,
  block : @core.CoreBlock,
) -> Unit {
  match state.list_item_stack.last() {
    Some(frame) => frame.body_blocks.push(block)
    None => state.blocks.push(block)
  }
}

///|
fn html_child_text_close_list_item(
  state : HtmlChildTextState,
  source : @input.InputSource,
  end_line : Int,
  end_byte : Int,
) -> Unit {
  let frame = match state.list_item_stack.pop() {
    Some(value) => value
    None => return
  }
  let body = frame.body_blocks
  let item = html_child_text_list_item_block(
    state, frame, body, source, end_line, end_byte,
  )
  match state.list_stack.last() {
    Some(list) => list.items.push(item)
    None => state.blocks.push(item)
  }
}

///|
fn html_child_text_list_item_block(
  state : HtmlChildTextState,
  frame : HtmlChildListItemFrame,
  body_blocks : Array[@core.CoreBlock],
  source : @input.InputSource,
  end_line : Int,
  end_byte : Int,
) -> @core.CoreBlock {
  let (text, rendered_markdown, rich, nested_lists, extras) = html_child_text_list_item_body_parts(
    body_blocks,
  )
  let item = html_child_text_make_block(
    state,
    source,
    ListItem,
    text,
    frame.start_line,
    end_line,
    frame.html_path,
    byte_start=frame.start_byte,
    byte_end=end_byte,
  )
  item.attrs.set("ordered", @fshared.bool_string(frame.ordered))
  if frame.ordered {
    item.attrs.set("ordered_indent_step", "3")
  }
  item.attrs.set("stable_ordered_marker", "true")
  item.attrs.set("literal", "true")
  item.attrs.set("render_inline_escape_mode", "minimal")
  let mut root = match rich {
    Some(inlines) => @core.block_with_rich_inlines(item, Some(inlines))
    None => item
  }
  match rendered_markdown {
    Some(rendered) => root = @core.block_with_rendered_markdown(root, rendered)
    None => ()
  }
  let children : Array[@core.CoreBlock] = []
  children.append(nested_lists[:])
  children.append(extras[:])
  if children.length() > 0 {
    root = @core.block_with_children(root, children)
  }
  root
}

///|
fn html_child_text_list_item_body_parts(
  body_blocks : Array[@core.CoreBlock],
) -> (
  String,
  String?,
  Array[@core.CoreInline]?,
  Array[@core.CoreBlock],
  Array[@core.CoreBlock],
) {
  let nested_lists : Array[@core.CoreBlock] = []
  let extras : Array[@core.CoreBlock] = []
  let mut root_text = ""
  let mut rendered_markdown : String? = None
  let mut rich : Array[@core.CoreInline]? = None
  let mut root_taken = false
  for block in body_blocks {
    if block.kind == List {
      nested_lists.push(block)
      continue
    }
    if !root_taken &&
      (
        block.kind == Paragraph ||
        block.kind == Heading ||
        block.kind == BlockQuote ||
        block.kind == Code
      ) {
      root_text = block.text
      rendered_markdown = @core.block_rendered_markdown(block)
      rich = block.rich_inlines
      root_taken = true
      continue
    }
    extras.push(block)
  }
  (root_text, rendered_markdown, rich, nested_lists, extras)
}

///|
fn html_text_has_trailing_space_like(text : String) -> Bool {
  let chars = text.to_array()
  if chars.length() == 0 {
    return false
  }
  html_ascii_space_like(chars[chars.length() - 1])
}

///|
fn html_text_has_leading_space_like(text : String) -> Bool {
  let chars = text.to_array()
  if chars.length() == 0 {
    return false
  }
  html_ascii_space_like(chars[0])
}

///|
fn html_child_text_close_list(
  state : HtmlChildTextState,
  source : @input.InputSource,
  end_line : Int,
  end_byte : Int,
) -> Unit {
  let frame = match state.list_stack.pop() {
    Some(value) => value
    None => return
  }
  if frame.items.length() == 0 {
    return
  }
  let list = html_child_text_make_block(
    state,
    source,
    List,
    "",
    frame.start_line,
    end_line,
    frame.html_path,
    byte_start=frame.start_byte,
    byte_end=end_byte,
  )
  let lowered = match
    (if state.compact_provenance {
      html_child_compact_list_markdown(frame)
    } else {
      None
    }) {
    Some(rendered) => @core.block_with_rendered_markdown(list, rendered)
    None => {
      list.attrs.set("ordered", @fshared.bool_string(frame.ordered))
      @core.block_with_children(list, frame.items)
    }
  }
  match state.list_item_stack.last() {
    Some(item) => item.body_blocks.push(lowered)
    None => state.blocks.push(lowered)
  }
}

///|
fn html_child_compact_list_markdown(frame : HtmlChildListFrame) -> String? {
  let out = StringBuilder::new()
  for index in 0..<frame.items.length() {
    let item = frame.items[index]
    if item.children.length() > 0 {
      return None
    }
    let text = match @core.block_rendered_markdown(item) {
      Some(rendered) => rendered.trim().to_owned()
      None =>
        match item.rich_inlines {
          Some(_) => return None
          None => item.text.trim().to_owned()
        }
    }
    if index > 0 {
      out.write_char('\n')
    }
    out.write_string(if frame.ordered { "1. " } else { "- " })
    out.write_string(text)
  }
  Some(out.to_string())
}

///|
fn html_child_hr_block(
  state : HtmlChildTextState,
  source : @input.InputSource,
  event : @dhtml.HtmlTokenEvent,
  block_order : Int,
) -> @core.CoreBlock {
  let block = html_child_text_make_block(
    state,
    source,
    Raw,
    "---",
    event.span.line_start,
    event.span.line_end,
    "/block/html:block:hr:" + block_order.to_string(),
    byte_start=event.span.byte_start,
    byte_end=event.span.byte_end,
  )
  block.attrs.set("raw_kind", "thematic_break")
  block
}

///|
fn html_child_hr_block_fields(
  state : HtmlChildTextState,
  source : @input.InputSource,
  line_start : Int,
  line_end : Int,
  byte_start : Int,
  byte_end : Int,
  block_order : Int,
) -> @core.CoreBlock {
  let block = html_child_text_make_block(
    state,
    source,
    Raw,
    "---",
    line_start,
    line_end,
    "/block/html:block:hr:" + block_order.to_string(),
    byte_start~,
    byte_end~,
  )
  block.attrs.set("raw_kind", "thematic_break")
  block
}

///|
fn html_child_text_append_image(
  state : HtmlChildTextState,
  source : @input.InputSource,
  event : @dhtml.HtmlTokenEvent,
) -> Unit {
  let src = @dhtml.html_token_event_attr_value(event, "src")
    .unwrap_or("")
    .trim()
    .to_owned()
  let kind = html_child_image_kind(src)
  let alt = @dhtml.html_token_event_attr_value(event, "alt")
    .unwrap_or("image")
    .trim()
    .to_owned()
  let title = match @dhtml.html_token_event_attr_value(event, "title") {
    Some(value) => {
      let trimmed = value.trim().to_owned()
      if trimmed == "" {
        None
      } else {
        Some(trimmed)
      }
    }
    None => None
  }
  let source_ref = html_token_lines_source_ref(
    source,
    event.span.line_start,
    event.span.line_end,
    "/block/html:block:img:" + state.block_order.to_string(),
    byte_start=event.span.byte_start,
    byte_end=event.span.byte_end,
  )
  if kind == Remote {
    state.diagnostics.degraded_features.push("html_remote_image_reference_only")
    return
  }
  if kind == DataUri {
    state.diagnostics.degraded_features.push("html_data_image_reference_only")
    return
  }
  if kind == Local {
    match html_child_local_image_asset(state, source_ref, src, alt) {
      Some(asset) => {
        let image = @core.make_block(Image, "", source_ref~)
        image.attrs.set("alt", alt)
        image.attrs.set("path", asset.path.unwrap_or("#"))
        image.attrs.set("asset_id", asset.asset_id)
        match title {
          Some(value) => image.attrs.set("title", value)
          None => ()
        }
        html_child_text_push_block(state, image)
      }
      None => {
        let paragraph = @core.make_block(
          Paragraph,
          html_image_placeholder_text(kind, alt),
          source_ref~,
        )
        paragraph.attrs.set("literal", "true")
        paragraph.attrs.set("render_inline_escape_mode", "minimal")
        html_child_text_push_block(state, paragraph)
      }
    }
    return
  }
  let paragraph = @core.make_block(
    Paragraph,
    html_image_placeholder_text(kind, alt),
    source_ref~,
  )
  paragraph.attrs.set("literal", "true")
  paragraph.attrs.set("render_inline_escape_mode", "minimal")
  html_child_text_push_block(state, paragraph)
}

///|
fn html_child_text_append_image_fields(
  state : HtmlChildTextState,
  source : @input.InputSource,
  attributes : Array[@dhtml.HtmlAttribute],
  line_start : Int,
  line_end : Int,
  byte_start : Int,
  byte_end : Int,
) -> Unit {
  html_child_text_append_image(
    state,
    source,
    @dhtml.make_html_token_event(
      StartTag,
      "img",
      attributes,
      true,
      0,
      0,
      line_start,
      line_end,
      byte_start~,
      byte_end~,
    ),
  )
}

///|
fn html_child_image_kind(src : String) -> @dhtml.HtmlImageKind {
  let trimmed = src.trim().to_owned()
  if trimmed == "" {
    return Empty
  }
  let lower = trimmed.to_lower()
  if lower.has_prefix("javascript:") || lower.has_prefix("vbscript:") {
    return Unsafe
  }
  if lower.has_prefix("data:") {
    return DataUri
  }
  if lower.has_prefix("http://") ||
    lower.has_prefix("https://") ||
    lower.has_prefix("//") {
    return Remote
  }
  if lower.has_prefix("/") {
    return Unknown
  }
  Local
}

///|
fn html_child_local_image_asset(
  state : HtmlChildTextState,
  source_ref : @core.SourceRef,
  src : String,
  alt : String,
) -> @core.AssetRef? {
  let normalized_src = html_strip_query_and_hash(src.trim().to_owned())
  if !html_safe_local_image_src(normalized_src) {
    return None
  }
  for existing in state.lowering_state.assets {
    if existing.payload == Some(SourcePath(normalized_src)) {
      return Some(existing)
    }
  }
  let asset_index = state.lowering_state.assets.length() + 1
  let asset_id = "html-image-" + asset_index.to_string()
  let asset = @core.make_asset_ref(Image, asset_id, source_ref~)
  let next_asset = {
    ..asset,
    path: Some(
      "assets/image" +
      html_two_digit(asset_index) +
      "." +
      html_image_ext_from_src(normalized_src),
    ),
  }
  next_asset.payload = Some(SourcePath(normalized_src))
  next_asset.attrs.set("alt", alt)
  state.lowering_state.assets.push(next_asset)
  Some(next_asset)
}
