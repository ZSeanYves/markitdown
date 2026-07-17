///|
/// Render Markdown directly into a sink while retaining only the current
/// block/row fragment. Debug and RAG renderers deliberately do not use this
/// entry point because their JSON framing is not independently chunk-safe.
pub fn render_markdown_input_to_sink(
  input : RenderInput,
  context : RenderContext,
  write : (String) -> Result[Unit, String],
) -> Result[RenderResult, String] {
  match input {
    Document(document) => {
      let profiled = profiled_document(document, context)
      let diagnostics = context.base_diagnostics.unwrap_or(profiled.diagnostics)
      diagnostics.metrics.set("renderer_name", "MarkdownRenderer")
      diagnostics.metrics.set(
        "applied_render_profile",
        @product.render_profile_name(context.render_profile),
      )
      diagnostics.metrics.set("renderer_stream_mode", "block")
      diagnostics.metrics.set("sink_renderer_fallback", "false")
      match write_markdown_blocks_to_sink(profiled.blocks, write) {
        Ok(_) => Ok({ content: "", diagnostics, chunks: None })
        Err(message) => Err(message)
      }
    }
    BlockStream(blocks) => {
      let profiled = profiled_blocks(blocks, context)
      let diagnostics = block_stream_input_diagnostics(context, profiled)
      diagnostics.metrics.set("renderer_name", "MarkdownRenderer")
      diagnostics.metrics.set(
        "applied_render_profile",
        @product.render_profile_name(context.render_profile),
      )
      diagnostics.metrics.set("renderer_stream_mode", "block")
      diagnostics.metrics.set("sink_renderer_fallback", "false")
      match write_markdown_blocks_to_sink(profiled, write) {
        Ok(_) => Ok({ content: "", diagnostics, chunks: None })
        Err(message) => Err(message)
      }
    }
    EventStream(events) => {
      let profiled = profiled_events(events, context)
      let diagnostics = stream_input_diagnostics(
        context, profiled, "event_stream",
      )
      diagnostics.metrics.set("renderer_name", "MarkdownRenderer")
      diagnostics.metrics.set(
        "applied_render_profile",
        @product.render_profile_name(context.render_profile),
      )
      diagnostics.metrics.set("renderer_stream_mode", "event")
      if markdown_text_markup_compact_event_stream(profiled) {
        write_markdown_text_markup_compact_to_sink(profiled, write, diagnostics)
      } else if markdown_xml_outline_event_stream(profiled) {
        write_markdown_xml_outline_to_sink(profiled, write, diagnostics)
      } else if markdown_xml_generic_outline_event_stream(profiled) {
        write_markdown_xml_generic_outline_to_sink(profiled, write, diagnostics)
      } else if markdown_json_list_event_stream(profiled) {
        write_markdown_json_list_to_sink(profiled, write, diagnostics)
      } else if markdown_subtitle_event_stream(profiled) {
        let sink = open_markdown_subtitle_event_sink(write)
        write_events_to_sink(profiled, sink, diagnostics)
      } else if event_stream_contains_table_rows(profiled) {
        let sink = open_markdown_table_event_sink(write)
        write_events_to_sink(profiled, sink, diagnostics)
      } else if profiled.length() > 0 && profiled[0].kind == TextLine {
        let sink = open_markdown_line_event_sink(write)
        write_events_to_sink(profiled, sink, diagnostics)
      } else if generic_block_event_stream(profiled) {
        let blocks = generic_blocks_from_events(profiled)
        diagnostics.metrics.set("renderer_stream_mode", "generic_block")
        match write_markdown_blocks_to_sink(blocks, write) {
          Ok(_) => Ok({ content: "", diagnostics, chunks: None })
          Err(message) => Err(message)
        }
      } else {
        write_markdown_generic_events_to_sink(profiled, write, diagnostics)
      }
    }
  }
}

///|
fn sink_render_result(diagnostics : @core.Diagnostics) -> RenderResult {
  { content: "", diagnostics, chunks: None }
}

///|
fn write_markdown_json_list_to_sink(
  events : Array[@core.CoreEvent],
  write : (String) -> Result[Unit, String],
  diagnostics : @core.Diagnostics,
) -> Result[RenderResult, String] {
  let mut wrote_any = false
  for event in events {
    let fragment = (if wrote_any { "\n" } else { "" }) + "- " + event.text
    match write(fragment) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    wrote_any = true
  }
  Ok(sink_render_result(diagnostics))
}

///|
fn write_markdown_xml_outline_to_sink(
  events : Array[@core.CoreEvent],
  write : (String) -> Result[Unit, String],
  diagnostics : @core.Diagnostics,
) -> Result[RenderResult, String] {
  let mut wrote_any = false
  let mut needs_heading_gap = false
  for event in events {
    let out = StringBuilder::new()
    match event.kind {
      StartBlock(Heading) => {
        if wrote_any {
          out.write_string("\n\n")
        }
        out.write_string("# ")
        out.write_string(event.text.trim().to_owned())
        wrote_any = true
        needs_heading_gap = true
      }
      StartBlock(ListItem) => {
        if wrote_any {
          out.write_char('\n')
          if needs_heading_gap {
            out.write_char('\n')
          }
        }
        needs_heading_gap = false
        let depth = match event.source_ref {
          Some(source_ref) =>
            @string.parse_int(
              source_ref.extra.get("xml_outline_depth").unwrap_or("0"),
            ) catch {
              _ => 0
            }
          None => 0
        }
        out.write_string(repeat_char_string(' ', depth * 2))
        out.write_string("- ")
        out.write_string(event.text.trim().to_owned())
        wrote_any = true
      }
      _ => continue
    }
    match write(out.to_string()) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok(sink_render_result(diagnostics))
}

///|
fn write_markdown_xml_generic_outline_to_sink(
  events : Array[@core.CoreEvent],
  write : (String) -> Result[Unit, String],
  diagnostics : @core.Diagnostics,
) -> Result[RenderResult, String] {
  let stack : Array[(@core.BlockKind, Int)] = []
  let mut wrote_any = false
  let mut needs_heading_gap = false
  for event in events {
    let out = StringBuilder::new()
    let mut visible = false
    match event.kind {
      StartBlock(Heading) => {
        if wrote_any {
          out.write_string("\n\n")
        }
        out.write_string("# ")
        out.write_string(event.text.trim().to_owned())
        wrote_any = true
        needs_heading_gap = true
        visible = true
        stack.push((Heading, 0))
      }
      StartBlock(List) => {
        let child_depth = if stack.length() == 0 {
          0
        } else {
          let parent = stack[stack.length() - 1]
          match parent.0 {
            List => {
              if wrote_any {
                out.write_char('\n')
                if needs_heading_gap {
                  out.write_char('\n')
                }
              }
              needs_heading_gap = false
              out.write_string(repeat_char_string(' ', parent.1 * 2))
              out.write_string("- ")
              wrote_any = true
              visible = true
              parent.1 + 1
            }
            ListItem => parent.1 + 1
            _ => 0
          }
        }
        stack.push((List, child_depth))
      }
      StartBlock(ListItem) => {
        let depth = if stack.length() > 0 {
          let parent = stack[stack.length() - 1]
          if parent.0 == ListItem {
            parent.1 + 1
          } else {
            parent.1
          }
        } else {
          0
        }
        if wrote_any {
          out.write_char('\n')
          if needs_heading_gap {
            out.write_char('\n')
          }
        }
        needs_heading_gap = false
        out.write_string(repeat_char_string(' ', depth * 2))
        out.write_string("- ")
        out.write_string(event.text.trim().to_owned())
        wrote_any = true
        visible = true
        stack.push((ListItem, depth))
      }
      EndBlock(_) => if stack.length() > 0 { ignore(stack.pop()) }
      _ => ()
    }
    if visible {
      match write(out.to_string()) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    }
  }
  Ok(sink_render_result(diagnostics))
}

///|
fn write_markdown_text_markup_compact_to_sink(
  events : Array[@core.CoreEvent],
  write : (String) -> Result[Unit, String],
  diagnostics : @core.Diagnostics,
) -> Result[RenderResult, String] {
  let cursor = { events, index: 0 }
  let mut previous : @core.BlockKind? = None
  let mut wrote_any = false
  while cursor.index < events.length() {
    let event = events[cursor.index]
    match event.kind {
      StartBlock(kind) => {
        let compact_leaf = event.source_ref
          .map(source_ref => {
            source_ref.extra.get("ir_text_markup_compact_leaf") == Some("true")
          })
          .unwrap_or(false)
        let paired_leaf = cursor.index + 1 < events.length() &&
          events[cursor.index + 1].kind == EndBlock(kind)
        let simple = (compact_leaf || paired_leaf) &&
          (kind == Heading || kind == Paragraph || kind == Code)
        let out = StringBuilder::new()
        let mut visible = false
        if simple {
          let text = event.text
          if text.trim() != "" || kind == Code {
            if wrote_any {
              if markdown_needs_blank_line_between(previous, kind) {
                out.write_string("\n\n")
              } else {
                out.write_char('\n')
              }
            }
            match kind {
              Heading => {
                let level = event.source_ref
                  .map(source_ref => {
                    clamp_heading_level(
                      source_ref.extra.get("ir_block_attr_level").unwrap_or("1"),
                    )
                  })
                  .unwrap_or(1)
                out.write_string(repeat_char_string('#', level))
                out.write_char(' ')
                out.write_string(text.trim().to_owned())
              }
              Paragraph =>
                if event.source_ref
                  .map(source_ref => {
                    source_ref.extra.get("ir_text_markup_rendered_inline") ==
                    Some("true")
                  })
                  .unwrap_or(false) {
                  out.write_string(text)
                } else if !text.contains("\n") {
                  out.write_string(escape_markdown_line_prefix(text))
                } else {
                  let lines = render_literal_markdown_lines(text)
                  for index in 0..<lines.length() {
                    if index > 0 {
                      out.write_char('\n')
                    }
                    out.write_string(lines[index])
                  }
                }
              Code => {
                let info = event.source_ref
                  .map(source_ref => {
                    source_ref.extra.get("ir_block_attr_info").unwrap_or("")
                  })
                  .unwrap_or("")
                let fence = safe_code_fence(text)
                out.write_string(fence)
                out.write_string(info)
                out.write_char('\n')
                out.write_string(text)
                out.write_char('\n')
                out.write_string(fence)
              }
              _ => ()
            }
            previous = Some(kind)
            wrote_any = true
            visible = true
          }
          cursor.index += if compact_leaf { 1 } else { 2 }
        } else {
          match parse_generic_block_event(cursor) {
            Some(block) => {
              visible = write_markdown_block_with_separator_to(
                out, block, previous, wrote_any,
              )
              if visible {
                previous = Some(block.kind)
                wrote_any = true
              }
            }
            None => cursor.index += 1
          }
        }
        if visible {
          match write(out.to_string()) {
            Ok(_) => ()
            Err(message) => return Err(message)
          }
        }
      }
      _ => cursor.index += 1
    }
  }
  Ok(sink_render_result(diagnostics))
}

///|
fn write_markdown_generic_events_to_sink(
  events : Array[@core.CoreEvent],
  write : (String) -> Result[Unit, String],
  diagnostics : @core.Diagnostics,
) -> Result[RenderResult, String] {
  let mut wrote_any = false
  for event in events {
    if !markdown_generic_event_visible(event) {
      continue
    }
    let out = StringBuilder::new()
    if wrote_any {
      out.write_string("\n\n")
    }
    write_markdown_generic_event_to(out, event)
    match write(out.to_string()) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    wrote_any = true
  }
  Ok(sink_render_result(diagnostics))
}

///|
fn write_events_to_sink(
  events : Array[@core.CoreEvent],
  sink : MarkdownEventSink,
  diagnostics : @core.Diagnostics,
) -> Result[RenderResult, String] {
  for event in events {
    match (sink.push)(event) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  match (sink.finish)() {
    Ok(_) => Ok({ content: "", diagnostics, chunks: None })
    Err(message) => Err(message)
  }
}

///|
fn write_markdown_blocks_to_sink(
  blocks : Array[@core.CoreBlock],
  write : (String) -> Result[Unit, String],
) -> Result[Unit, String] {
  let leaf_cache : Map[String, String] = Map([])
  let mut previous : @core.BlockKind? = None
  let mut wrote_any = false
  for block in blocks {
    let fragment = StringBuilder::new()
    let wrote = match markdown_leaf_cache_key(block, blocks.length()) {
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
            if markdown_needs_blank_line_between(previous, block.kind) {
              fragment.write_string("\n\n")
            } else {
              fragment.write_char('\n')
            }
          }
          fragment.write_string(rendered)
          true
        }
      }
      None =>
        write_markdown_block_with_separator_to(
          fragment, block, previous, wrote_any,
        )
    }
    if wrote {
      previous = Some(block.kind)
      wrote_any = true
      match write(fragment.to_string()) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    }
  }
  Ok(())
}
