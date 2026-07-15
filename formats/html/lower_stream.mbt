///|
priv struct HtmlTokenBlockState {
  blocks : Array[@core.CoreBlock]
  mut text : StringBuilder
  mut text_start_line : Int
  mut text_end_line : Int
  mut text_kind : @core.BlockKind
  mut heading_level : Int
  mut in_pre : Bool
  mut text_has_content : Bool
  mut skip_depth : Int
  mut list_depth : Int
  mut quote_depth : Int
}

///|
fn html_lower_block_stream_document(
  source : @input.InputSource,
  text : String,
  diagnostics : @core.Diagnostics,
) -> HtmlLoweringResult {
  let events = try @dhtml.tokenize_html_events(text) |> Ok catch {
    _ => Err(())
  }
  match events {
    Ok(stream) =>
      html_lower_block_stream_document_from_events(
        source, text, diagnostics, stream,
      )
    Err(_) => {
      diagnostics.metrics.set("html_block_stream_reparse", "false")
      diagnostics.metrics.set("html_block_stream_token_path", "unavailable")
      { blocks: [], metadata: Map([]), assets: [] }
    }
  }
}

///|
fn html_lower_block_stream_document_from_events(
  source : @input.InputSource,
  text : String,
  diagnostics : @core.Diagnostics,
  events : Array[@dhtml.HtmlTokenEvent],
) -> HtmlLoweringResult {
  let scope_plans = html_block_scope_plans_from_events(text, events)
  html_lower_block_stream_document_with_scope_plans(
    source, text, diagnostics, events, scope_plans,
  )
}

///|
fn html_lower_child_text_block_stream_document(
  source : @input.InputSource,
  text : String,
  diagnostics : @core.Diagnostics,
) -> HtmlLoweringResult {
  let events = try @dhtml.tokenize_html_events(text) |> Ok catch {
    _ => Err(())
  }
  match events {
    Ok(stream) =>
      if html_child_events_require_semantic_block_stream(stream) {
        html_lower_child_semantic_block_stream_document(
          source, text, diagnostics,
        )
      } else {
        html_lower_child_text_block_stream_document_from_events(
          source, text, diagnostics, stream,
        )
      }
    Err(_) => {
      diagnostics.metrics.set("html_block_stream_reparse", "false")
      diagnostics.metrics.set("html_block_stream_token_path", "true")
      diagnostics.metrics.set("scope_plan_count", "0")
      diagnostics.metrics.set("scope_plan_labels", "child_text_fast_failed")
      { blocks: [], metadata: Map([]), assets: [] }
    }
  }
}

///|
fn html_lower_child_text_block_stream_document_from_events(
  source : @input.InputSource,
  text : String,
  diagnostics : @core.Diagnostics,
  events : Array[@dhtml.HtmlTokenEvent],
) -> HtmlLoweringResult {
  diagnostics.metrics.set("html_block_stream_reparse", "false")
  diagnostics.metrics.set("html_block_stream_token_path", "true")
  diagnostics.metrics.set("scope_plan_count", "0")
  diagnostics.metrics.set("scope_plan_labels", "child_text_fast")
  let normalized = @dhtml.normalize_html_token_source(text)
  let lowered = html_lower_child_text_blocks(
    source,
    normalized.to_array(),
    diagnostics,
    events,
    has_table=html_child_events_contain_tag(events, "table"),
  )
  { blocks: lowered.0, metadata: Map([]), assets: lowered.1 }
}

///|
fn html_lower_child_text_block_stream_document_scanned(
  source : @input.InputSource,
  text : String,
  diagnostics : @core.Diagnostics,
) -> HtmlLoweringResult {
  diagnostics.metrics.set("html_block_stream_reparse", "true")
  diagnostics.metrics.set("html_block_stream_token_path", "stream_scan")
  diagnostics.metrics.set("scope_plan_count", "0")
  diagnostics.metrics.set("scope_plan_labels", "child_text_stream_scan")
  let normalized = @dhtml.normalize_html_token_source(text)
  let lowered = html_lower_child_text_blocks_scanned(
    source, normalized, diagnostics,
  )
  { blocks: lowered.0, metadata: Map([]), assets: lowered.1 }
}

///|
fn html_child_events_require_semantic_block_stream(
  events : Array[@dhtml.HtmlTokenEvent],
) -> Bool {
  html_child_events_contain_tag(events, "figure") ||
  html_child_events_contain_tag(events, "details") ||
  html_child_events_contain_tag(events, "summary")
}

///|
fn html_child_events_contain_tag(
  events : Array[@dhtml.HtmlTokenEvent],
  tag_name : String,
) -> Bool {
  for event in events {
    if event.kind == @dhtml.HtmlTokenEventKind::StartTag &&
      event.tag_name == tag_name {
      return true
    }
  }
  false
}

///|
fn html_lower_block_stream_document_with_scope_plans(
  source : @input.InputSource,
  text : String,
  diagnostics : @core.Diagnostics,
  events : Array[@dhtml.HtmlTokenEvent],
  scope_plans : Array[HtmlScopePlan],
) -> HtmlLoweringResult {
  let metadata : @core.DocumentMetadata = Map([])
  let blocks : Array[@core.CoreBlock] = []
  diagnostics.metrics.set("scope_plan_count", scope_plans.length().to_string())
  diagnostics.metrics.set("html_block_stream_reparse", "false")
  diagnostics.metrics.set("html_block_stream_token_path", "true")
  let scope_labels : Array[String] = []
  let text_chars = text.to_array()
  let mut event_index = 0

  for plan in scope_plans {
    scope_labels.push(plan.label)
    let result = html_lower_scope_events_to_blocks(
      source, text_chars, events, plan, event_index,
    )
    blocks.append(result.0[:])
    event_index = result.1
  }
  diagnostics.metrics.set("scope_plan_labels", scope_labels.join(","))

  { blocks, metadata, assets: [] }
}

///|
fn html_lower_scope_events_to_blocks(
  source : @input.InputSource,
  text_chars : Array[Char],
  events : Array[@dhtml.HtmlTokenEvent],
  plan : HtmlScopePlan,
  start_index : Int,
) -> (Array[@core.CoreBlock], Int) {
  let state = {
    blocks: [],
    text: StringBuilder::new(),
    text_start_line: 0,
    text_end_line: 0,
    text_kind: @core.BlockKind::Paragraph,
    heading_level: 0,
    in_pre: false,
    text_has_content: false,
    skip_depth: 0,
    list_depth: 0,
    quote_depth: 0,
  }
  let mut i = start_index
  while i < events.length() && events[i].source_end <= plan.source_start {
    i += 1
  }
  while i < events.length() {
    let event = events[i]
    if event.source_start >= plan.source_end {
      break
    }
    if event.source_end <= plan.source_start ||
      event.source_start >= plan.source_end {
      i += 1
      continue
    }
    html_token_lower_event(state, source, text_chars, event)
    i += 1
  }
  html_token_flush_text_block(state, source)
  (state.blocks, i)
}

///|
priv struct HtmlChildInlineState {
  inlines : Array[@core.CoreInline]
  mut text : StringBuilder
  compact_plain : StringBuilder
  compact_markdown : StringBuilder
  mut compact_has_markup : Bool
  mut text_line_start : Int
  mut text_line_end : Int
  mut pending_space : Bool
  mut has_content : Bool
}

///|
priv struct HtmlChildBlockAccumulator {
  kind : @core.BlockKind
  level : Int
  info : String
  html_path : String
  line_start : Int
  mut line_end : Int
  byte_start : Int
  mut byte_end : Int
  inline_state : HtmlChildInlineState
}

///|
priv struct HtmlChildTextState {
  lowering_state : HtmlLoweringState
  diagnostics : @core.Diagnostics
  blocks : Array[@core.CoreBlock]
  close_index : Map[Int, Int]
  mut current : HtmlChildBlockAccumulator?
  mut skip_depth : Int
  mut block_order : Int
  mut inline_order : Int
  mut link_depth : Int
  mut link_text : StringBuilder
  mut link_href : String?
  mut link_line_start : Int
  mut link_line_end : Int
  mut link_pending_space : Bool
  mut link_has_content : Bool
  list_stack : Array[HtmlChildListFrame]
  list_item_stack : Array[HtmlChildListItemFrame]
  compact_provenance : Bool
}

///|
priv struct HtmlChildListFrame {
  ordered : Bool
  start_line : Int
  start_byte : Int
  html_path : String
  items : Array[@core.CoreBlock]
}

///|
priv struct HtmlChildListItemFrame {
  ordered : Bool
  start_line : Int
  start_byte : Int
  html_path : String
  body_blocks : Array[@core.CoreBlock]
}

///|
fn html_child_inline_state() -> HtmlChildInlineState {
  {
    inlines: [],
    text: StringBuilder::new(),
    compact_plain: StringBuilder::new(),
    compact_markdown: StringBuilder::new(),
    compact_has_markup: false,
    text_line_start: 0,
    text_line_end: 0,
    pending_space: false,
    has_content: false,
  }
}

///|
fn html_child_inline_append_text(
  inline_state : HtmlChildInlineState,
  text : String,
  line_start : Int,
  line_end : Int,
) -> Unit {
  if text == "" {
    return
  }
  if inline_state.text_line_start == 0 {
    inline_state.text_line_start = line_start
  }
  inline_state.text_line_end = line_end
  inline_state.text.write_string(text)
  inline_state.has_content = true
  inline_state.pending_space = false
}

///|
fn html_child_inline_materialize_pending_text(
  state : HtmlChildTextState,
  source : @input.InputSource,
  current : HtmlChildBlockAccumulator,
) -> Unit {
  if current.inline_state.text_line_start == 0 {
    return
  }
  let text = current.inline_state.text.to_string()
  current.inline_state.text = StringBuilder::new()
  let line_start = current.inline_state.text_line_start
  let line_end = current.inline_state.text_line_end
  current.inline_state.text_line_start = 0
  current.inline_state.text_line_end = 0
  if text == "" {
    return
  }
  if state.compact_provenance {
    current.inline_state.compact_plain.write_string(text)
    html_child_write_minimal_markdown(
      current.inline_state.compact_markdown,
      text,
    )
    return
  }
  state.inline_order += 1
  current.inline_state.inlines.push(
    html_child_text_make_inline_text(
      state,
      source,
      text,
      line_start,
      line_end,
      "/inline/html:inline:text:" + state.inline_order.to_string(),
    ),
  )
}

///|
fn html_child_write_minimal_markdown(
  out : StringBuilder,
  text : String,
) -> Unit {
  for ch in text {
    if ch == '\\' || ch == '`' {
      out.write_char('\\')
    }
    out.write_char(ch)
  }
}

///|
fn html_lower_child_text_blocks(
  source : @input.InputSource,
  text_chars : Array[Char],
  diagnostics : @core.Diagnostics,
  events : Array[@dhtml.HtmlTokenEvent],
  has_table? : Bool = true,
) -> (Array[@core.CoreBlock], Array[@core.AssetRef]) {
  let state = html_child_text_state(
    diagnostics,
    if has_table {
      html_child_token_close_index(events)
    } else {
      Map([])
    },
  )
  let mut index = 0
  while index < events.length() {
    index = html_child_text_lower_event(
      state, source, text_chars, events, index,
    )
  }
  html_child_text_finish(state, source)
}

///|
fn html_lower_child_text_blocks_scanned(
  source : @input.InputSource,
  text : String,
  diagnostics : @core.Diagnostics,
) -> (Array[@core.CoreBlock], Array[@core.AssetRef]) {
  let close_index : Map[Int, Int] = Map([])
  let state = html_child_text_state(
    diagnostics,
    close_index,
    compact_provenance=true,
  )
  let mut table_depth = 0
  let mut table_source_start = 0
  let mut table_events : Array[@dhtml.HtmlTokenEvent] = []
  @dhtml.scan_normalized_html_string_event_fields(text, fn(
    kind,
    tag_name,
    attributes,
    self_closing,
    source_start,
    source_end,
    line_start,
    line_end,
    byte_start,
    byte_end,
  ) {
    if table_depth > 0 {
      let event = @dhtml.make_html_token_event(
        kind,
        tag_name,
        attributes,
        self_closing,
        source_start - table_source_start,
        source_end - table_source_start,
        line_start,
        line_end,
        byte_start~,
        byte_end~,
      )
      table_events.push(event)
      if event.kind == @dhtml.HtmlTokenEventKind::StartTag &&
        event.tag_name == "table" &&
        !event.self_closing {
        table_depth += 1
      } else if event.kind == @dhtml.HtmlTokenEventKind::EndTag &&
        event.tag_name == "table" {
        table_depth -= 1
        if table_depth == 0 {
          for entry in html_child_token_close_index(table_events) {
            close_index.set(entry.0, entry.1)
          }
          ignore(
            html_child_text_lower_event(
              state,
              source,
              text[table_source_start:source_end].to_owned().to_array(),
              table_events,
              0,
            ),
          )
          table_events = []
        }
      }
    } else if kind == @dhtml.HtmlTokenEventKind::StartTag &&
      tag_name == "table" &&
      !self_closing {
      table_depth = 1
      table_source_start = source_start
      table_events = [
        @dhtml.make_html_token_event(
          kind,
          tag_name,
          attributes,
          self_closing,
          0,
          source_end - source_start,
          line_start,
          line_end,
          byte_start~,
          byte_end~,
        ),
      ]
    } else {
      html_child_text_lower_string_fields(
        state, source, text, kind, tag_name, attributes, self_closing, source_start,
        source_end, line_start, line_end, byte_start, byte_end,
      )
    }
  }) catch {
    _ => diagnostics.degraded_features.push("html_event_scan_failed")
  }
  if table_events.length() > 0 {
    diagnostics.degraded_features.push("html_unclosed_table_dropped")
  }
  html_child_text_finish(state, source)
}

///|
fn html_child_text_state(
  diagnostics : @core.Diagnostics,
  close_index : Map[Int, Int],
  compact_provenance? : Bool = false,
) -> HtmlChildTextState {
  {
    lowering_state: { assets: [] },
    diagnostics,
    blocks: [],
    close_index,
    current: None,
    skip_depth: 0,
    block_order: 0,
    inline_order: 0,
    link_depth: 0,
    link_text: StringBuilder::new(),
    link_href: None,
    link_line_start: 0,
    link_line_end: 0,
    link_pending_space: false,
    link_has_content: false,
    list_stack: [],
    list_item_stack: [],
    compact_provenance,
  }
}

///|
fn html_child_text_make_block(
  state : HtmlChildTextState,
  source : @input.InputSource,
  kind : @core.BlockKind,
  text : String,
  line_start : Int,
  line_end : Int,
  html_path : String,
  byte_start? : Int = -1,
  byte_end? : Int = -1,
) -> @core.CoreBlock {
  if state.compact_provenance {
    @core.block_with_compact_source_ref(
      @core.make_block_without_source_ref(kind, text),
      @core.make_compact_source_ref(
        source.source_name,
        "html",
        if line_start <= 0 {
          1
        } else {
          line_start
        },
        if line_end <= 0 {
          line_start
        } else {
          line_end
        },
        byte_start.max(0),
        byte_end.max(byte_start.max(0)),
      ),
    )
  } else {
    @core.make_block(
      kind,
      text,
      source_ref=html_token_lines_source_ref(
        source,
        line_start,
        line_end,
        html_path,
        byte_start~,
        byte_end~,
      ),
    )
  }
}

///|
fn html_child_text_make_inline_text(
  state : HtmlChildTextState,
  source : @input.InputSource,
  text : String,
  line_start : Int,
  line_end : Int,
  html_path : String,
) -> @core.CoreInline {
  if state.compact_provenance {
    @core.make_inline_text_without_source_ref(text)
  } else {
    @core.make_inline_text(
      text,
      source_ref=html_token_lines_source_ref(
        source, line_start, line_end, html_path,
      ),
    )
  }
}

///|
fn html_child_text_make_inline_link(
  state : HtmlChildTextState,
  source : @input.InputSource,
  text : String,
  href : String,
  line_start : Int,
  line_end : Int,
  html_path : String,
) -> @core.CoreInline {
  if state.compact_provenance {
    @core.make_inline_link_without_source_ref(text, href)
  } else {
    @core.make_inline_link(
      text,
      href,
      source_ref=html_token_lines_source_ref(
        source, line_start, line_end, html_path,
      ),
    )
  }
}

///|
fn html_child_text_make_inline_line_break(
  state : HtmlChildTextState,
  source : @input.InputSource,
  line_start : Int,
  line_end : Int,
  html_path : String,
) -> @core.CoreInline {
  if state.compact_provenance {
    @core.make_inline_line_break_without_source_ref()
  } else {
    @core.make_inline_line_break(
      source_ref=html_token_lines_source_ref(
        source, line_start, line_end, html_path,
      ),
    )
  }
}

///|
fn html_child_text_finish(
  state : HtmlChildTextState,
  source : @input.InputSource,
) -> (Array[@core.CoreBlock], Array[@core.AssetRef]) {
  html_child_text_flush_link(state, source)
  html_child_text_flush_block(state, source)
  (state.blocks, state.lowering_state.assets)
}

///|
fn html_child_token_close_index(
  events : Array[@dhtml.HtmlTokenEvent],
) -> Map[Int, Int] {
  let out : Map[Int, Int] = Map([])
  let stacks : Map[String, Array[Int]] = Map([])
  for index in 0..<events.length() {
    let event = events[index]
    match event.kind {
      @dhtml.HtmlTokenEventKind::StartTag =>
        if !event.self_closing {
          match stacks.get(event.tag_name) {
            Some(existing) => existing.push(index)
            None => stacks.set(event.tag_name, [index])
          }
        }
      @dhtml.HtmlTokenEventKind::EndTag =>
        match stacks.get(event.tag_name) {
          Some(existing) =>
            if existing.length() > 0 {
              let open_index = existing.pop().unwrap()
              out.set(open_index, index)
            }
          None => ()
        }
      @dhtml.HtmlTokenEventKind::Text
      | @dhtml.HtmlTokenEventKind::Comment
      | @dhtml.HtmlTokenEventKind::Doctype => ()
    }
  }
  out
}

///|
fn html_child_text_lower_event(
  state : HtmlChildTextState,
  source : @input.InputSource,
  text_chars : Array[Char],
  events : Array[@dhtml.HtmlTokenEvent],
  index : Int,
) -> Int {
  let event = events[index]
  if state.skip_depth > 0 {
    if event.kind == @dhtml.HtmlTokenEventKind::StartTag && !event.self_closing {
      state.skip_depth += 1
    } else if event.kind == @dhtml.HtmlTokenEventKind::EndTag {
      state.skip_depth -= 1
    }
    return index + 1
  }
  match event.kind {
    @dhtml.HtmlTokenEventKind::Text =>
      html_child_text_append_text(state, source, text_chars, event)
    @dhtml.HtmlTokenEventKind::StartTag =>
      return html_child_text_start_tag(state, source, text_chars, events, index)
    @dhtml.HtmlTokenEventKind::EndTag =>
      html_child_text_end_tag(state, source, event)
    @dhtml.HtmlTokenEventKind::Comment | @dhtml.HtmlTokenEventKind::Doctype =>
      ()
  }
  index + 1
}

///|
fn html_child_text_lower_string_fields(
  state : HtmlChildTextState,
  source : @input.InputSource,
  text : String,
  kind : @dhtml.HtmlTokenEventKind,
  tag_name : String,
  attributes : Array[@dhtml.HtmlAttribute],
  self_closing : Bool,
  source_start : Int,
  source_end : Int,
  line_start : Int,
  line_end : Int,
  byte_start : Int,
  byte_end : Int,
) -> Unit {
  if state.skip_depth > 0 {
    if kind == @dhtml.HtmlTokenEventKind::StartTag && !self_closing {
      state.skip_depth += 1
    } else if kind == @dhtml.HtmlTokenEventKind::EndTag {
      state.skip_depth -= 1
    }
    return
  }
  match kind {
    @dhtml.HtmlTokenEventKind::Text =>
      html_child_text_append_text_value(
        state,
        text[source_start:source_end].to_owned(),
        line_start,
        line_end,
      )
    @dhtml.HtmlTokenEventKind::StartTag =>
      html_child_text_start_tag_fields(
        state, source, tag_name, attributes, self_closing, line_start, line_end,
        byte_start, byte_end,
      )
    @dhtml.HtmlTokenEventKind::EndTag =>
      html_child_text_end_tag_fields(
        state, source, tag_name, line_end, byte_end,
      )
    @dhtml.HtmlTokenEventKind::Comment | @dhtml.HtmlTokenEventKind::Doctype =>
      ()
  }
}

///|
fn html_child_text_start_tag(
  state : HtmlChildTextState,
  source : @input.InputSource,
  text_chars : Array[Char],
  events : Array[@dhtml.HtmlTokenEvent],
  index : Int,
) -> Int {
  let event = events[index]
  let tag = event.tag_name
  if html_scope_event_should_skip(event) || html_token_skip_tag(tag) {
    if !event.self_closing {
      state.skip_depth = 1
    }
    return index + 1
  }
  if html_dom_counts_as_block(tag, false) {
    state.block_order += 1
  }
  if tag == "html" ||
    tag == "body" ||
    tag == "main" ||
    tag == "article" ||
    tag == "section" ||
    tag == "div" ||
    tag == "header" ||
    tag == "footer" {
    return index + 1
  }
  if tag == "a" {
    html_child_text_open_link(state, event)
    return index + 1
  }
  if tag == "br" {
    html_child_text_append_line_break(state, source, event)
    return index + 1
  }
  let heading = html_heading_level(tag)
  if heading > 0 {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    state.current = Some({
      kind: @core.BlockKind::Heading,
      level: heading,
      info: "",
      html_path: "/block/html:block:" +
      tag +
      ":" +
      state.block_order.to_string(),
      line_start: event.span.line_start,
      line_end: event.span.line_end,
      byte_start: event.span.byte_start,
      byte_end: event.span.byte_end,
      inline_state: html_child_inline_state(),
    })
    return index + 1
  }
  if tag == "p" {
    match state.current {
      Some(current) =>
        if current.kind == @core.BlockKind::BlockQuote {
          return index + 1
        }
      None => ()
    }
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    state.current = Some({
      kind: @core.BlockKind::Paragraph,
      level: 0,
      info: "",
      html_path: "/block/html:block:p:" + state.block_order.to_string(),
      line_start: event.span.line_start,
      line_end: event.span.line_end,
      byte_start: event.span.byte_start,
      byte_end: event.span.byte_end,
      inline_state: html_child_inline_state(),
    })
    return index + 1
  }
  if tag == "blockquote" {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    state.current = Some({
      kind: @core.BlockKind::BlockQuote,
      level: 0,
      info: "",
      html_path: "/block/html:block:blockquote:" + state.block_order.to_string(),
      line_start: event.span.line_start,
      line_end: event.span.line_end,
      byte_start: event.span.byte_start,
      byte_end: event.span.byte_end,
      inline_state: html_child_inline_state(),
    })
    return index + 1
  }
  if tag == "ul" || tag == "ol" {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    state.list_stack.push({
      ordered: tag == "ol",
      start_line: event.span.line_start,
      start_byte: event.span.byte_start,
      html_path: "/block/html:block:" +
      tag +
      ":" +
      state.block_order.to_string(),
      items: [],
    })
    return index + 1
  }
  if tag == "li" {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    let ordered = match state.list_stack.last() {
      Some(frame) => frame.ordered
      None => false
    }
    state.list_item_stack.push({
      ordered,
      start_line: event.span.line_start,
      start_byte: event.span.byte_start,
      html_path: "/block/html:block:li:" + state.block_order.to_string(),
      body_blocks: [],
    })
    state.current = Some({
      kind: @core.BlockKind::Paragraph,
      level: 0,
      info: "",
      html_path: "/block/html:block:li:" + state.block_order.to_string(),
      line_start: event.span.line_start,
      line_end: event.span.line_end,
      byte_start: event.span.byte_start,
      byte_end: event.span.byte_end,
      inline_state: html_child_inline_state(),
    })
    return index + 1
  }
  if tag == "pre" {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    state.current = Some({
      kind: @core.BlockKind::Code,
      level: 0,
      info: "",
      html_path: "/block/html:block:pre:" + state.block_order.to_string(),
      line_start: event.span.line_start,
      line_end: event.span.line_end,
      byte_start: event.span.byte_start,
      byte_end: event.span.byte_end,
      inline_state: html_child_inline_state(),
    })
    return index + 1
  }
  if tag == "hr" {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    html_child_text_push_block(
      state,
      html_child_hr_block(state, source, event, state.block_order),
    )
    return index + 1
  }
  if tag == "img" {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    html_child_text_append_image(state, source, event)
    return index + 1
  }
  if tag == "table" {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    return html_child_text_append_table(
      state, source, text_chars, events, index,
    )
  }
  index + 1
}

///|
fn html_child_text_start_tag_fields(
  state : HtmlChildTextState,
  source : @input.InputSource,
  tag : String,
  attributes : Array[@dhtml.HtmlAttribute],
  self_closing : Bool,
  line_start : Int,
  line_end : Int,
  byte_start : Int,
  byte_end : Int,
) -> Unit {
  if html_scope_tag_should_skip(tag, attributes) || html_token_skip_tag(tag) {
    if !self_closing {
      state.skip_depth = 1
    }
    return
  }
  if html_dom_counts_as_block(tag, false) {
    state.block_order += 1
  }
  if tag == "html" ||
    tag == "body" ||
    tag == "main" ||
    tag == "article" ||
    tag == "section" ||
    tag == "div" ||
    tag == "header" ||
    tag == "footer" {
    return
  }
  if tag == "a" {
    html_child_text_open_link_fields(state, attributes, line_start, line_end)
    return
  }
  if tag == "br" {
    html_child_text_append_line_break_fields(
      state, source, line_start, line_end,
    )
    return
  }
  let heading = html_heading_level(tag)
  if heading > 0 {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    state.current = Some({
      kind: @core.BlockKind::Heading,
      level: heading,
      info: "",
      html_path: "/block/html:block:" +
      tag +
      ":" +
      state.block_order.to_string(),
      line_start,
      line_end,
      byte_start,
      byte_end,
      inline_state: html_child_inline_state(),
    })
    return
  }
  if tag == "p" {
    match state.current {
      Some(current) => if current.kind == @core.BlockKind::BlockQuote { return }
      None => ()
    }
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    state.current = Some({
      kind: @core.BlockKind::Paragraph,
      level: 0,
      info: "",
      html_path: "/block/html:block:p:" + state.block_order.to_string(),
      line_start,
      line_end,
      byte_start,
      byte_end,
      inline_state: html_child_inline_state(),
    })
    return
  }
  if tag == "blockquote" {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    state.current = Some({
      kind: @core.BlockKind::BlockQuote,
      level: 0,
      info: "",
      html_path: "/block/html:block:blockquote:" + state.block_order.to_string(),
      line_start,
      line_end,
      byte_start,
      byte_end,
      inline_state: html_child_inline_state(),
    })
    return
  }
  if tag == "ul" || tag == "ol" {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    state.list_stack.push({
      ordered: tag == "ol",
      start_line: line_start,
      start_byte: byte_start,
      html_path: "/block/html:block:" +
      tag +
      ":" +
      state.block_order.to_string(),
      items: [],
    })
    return
  }
  if tag == "li" {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    let ordered = match state.list_stack.last() {
      Some(frame) => frame.ordered
      None => false
    }
    state.list_item_stack.push({
      ordered,
      start_line: line_start,
      start_byte: byte_start,
      html_path: "/block/html:block:li:" + state.block_order.to_string(),
      body_blocks: [],
    })
    state.current = Some({
      kind: @core.BlockKind::Paragraph,
      level: 0,
      info: "",
      html_path: "/block/html:block:li:" + state.block_order.to_string(),
      line_start,
      line_end,
      byte_start,
      byte_end,
      inline_state: html_child_inline_state(),
    })
    return
  }
  if tag == "pre" {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    state.current = Some({
      kind: @core.BlockKind::Code,
      level: 0,
      info: "",
      html_path: "/block/html:block:pre:" + state.block_order.to_string(),
      line_start,
      line_end,
      byte_start,
      byte_end,
      inline_state: html_child_inline_state(),
    })
    return
  }
  if tag == "hr" {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    html_child_text_push_block(
      state,
      html_child_hr_block_fields(
        state,
        source,
        line_start,
        line_end,
        byte_start,
        byte_end,
        state.block_order,
      ),
    )
    return
  }
  if tag == "img" {
    html_child_text_flush_link(state, source)
    html_child_text_flush_block(state, source)
    html_child_text_append_image_fields(
      state, source, attributes, line_start, line_end, byte_start, byte_end,
    )
  }
}
