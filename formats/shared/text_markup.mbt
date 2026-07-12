///|
pub struct TextMarkupHooks {
  parser_name : String
  format_name : String
  format : @dmark.TextMarkupFormat
  parse_document : (String) -> @dmark.TextMarkupDocument
  quote_text : (@dmark.TextMarkupBlock, String) -> String
  semantic_block : (@dmark.TextMarkupBlock, @core.SourceRef, String) -> @core.CoreBlock?
  semantic_raw_block : (@dmark.TextMarkupBlock, @core.SourceRef, String) -> @core.CoreBlock?
}

///|
priv struct TextMarkupDiagnosticTemplates {
  quote_warning : String
  quote_fallback : String
  raw_warning : String
  raw_fallback : String
  semantic_raw_warning : String
  semantic_raw_fallback : String
}

///|
fn text_markup_diagnostic_templates(
  format_name : String,
) -> TextMarkupDiagnosticTemplates {
  {
    quote_warning: format_name +
    " degraded complex quote/admonition preserved as block quote",
    quote_fallback: format_name + " complex quote/admonition -> block quote",
    raw_warning: format_name +
    " degraded complex boundary preserved as raw block",
    raw_fallback: format_name + " complex boundary -> raw fenced block",
    semantic_raw_warning: format_name +
    " degraded complex boundary preserved as semantic text block",
    semantic_raw_fallback: format_name +
    " complex boundary -> semantic text block",
  }
}

///|
pub fn make_text_markup_hooks(
  parser_name : String,
  format_name : String,
  format : @dmark.TextMarkupFormat,
  parse_document : (String) -> @dmark.TextMarkupDocument,
  quote_text : (@dmark.TextMarkupBlock, String) -> String,
  semantic_block : (@dmark.TextMarkupBlock, @core.SourceRef, String) -> @core.CoreBlock?,
  semantic_raw_block : (@dmark.TextMarkupBlock, @core.SourceRef, String) -> @core.CoreBlock?,
) -> TextMarkupHooks {
  {
    parser_name,
    format_name,
    format,
    parse_document,
    quote_text,
    semantic_block,
    semantic_raw_block,
  }
}

///|
pub fn text_markup_parser_capability() -> @parser.ParserCapability {
  @parser.dom_ast_parser_capability(
    @parser.StreamingGranularity::None,
    false,
    false,
    false,
    true,
    false,
    true,
    true,
    false,
    true,
    false,
  )
}

///|
pub fn parse_text_markup_result(
  source : @input.InputSource,
  context : @parser.ParseContext,
  hooks : TextMarkupHooks,
) -> Result[@parser.ParseResult, String] {
  let prepared = match prepare_text_markup_document_for_hooks(source, hooks) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  Ok(parse_text_markup_result_with_prepared_document(prepared, context, hooks))
}

///|
pub fn parse_text_markup_result_with_prepared_document(
  prepared : @dmark.PreparedTextMarkupDocument,
  context : @parser.ParseContext,
  hooks : TextMarkupHooks,
) -> @parser.ParseResult {
  if prepared.original_text.length() >= 1_048_576 &&
    context.output_mode == @product.OutputMode::Markdown &&
    hooks.format == @dmark.TextMarkupFormat::Rst {
    return parse_large_text_markup_events(prepared, context, hooks)
  }
  parse_text_markup_result_with_preparsed_document(
    prepared.prepared_source,
    context,
    prepared.original_text,
    prepared.document,
    prepared.inspect,
    hooks,
  )
}

///|
fn parse_large_text_markup_events(
  prepared : @dmark.PreparedTextMarkupDocument,
  context : @parser.ParseContext,
  hooks : TextMarkupHooks,
) -> @parser.ParseResult {
  let source = prepared.prepared_source
  let diagnostics = empty_parser_diagnostics(
    hooks.parser_name,
    @parser.ParserMode::DomAstModel,
    source,
    hooks.format_name,
  )
  init_parser_route_metrics(
    diagnostics,
    source,
    context,
    hooks.format_name,
    hooks.parser_name,
    @parser.ParserMode::DomAstModel,
    @parser.ParserMode::DomAstModel,
    "event_stream",
    "record",
    "dom_ast_compact_events",
  )
  apply_product_metrics(diagnostics, hooks.format_name)
  let events = text_markup_compact_events(
    prepared.document,
    source,
    diagnostics,
    hooks,
  )
  let inspect = prepared.inspect
  diagnostics.metrics.set("block_count", inspect.block_count.to_string())
  diagnostics.metrics.set("heading_count", inspect.heading_count.to_string())
  diagnostics.metrics.set(
    "list_item_count",
    inspect.list_item_count.to_string(),
  )
  diagnostics.metrics.set("code_count", inspect.code_count.to_string())
  diagnostics.metrics.set("table_count", inspect.table_count.to_string())
  diagnostics.metrics.set(
    "blockquote_count",
    inspect.blockquote_count.to_string(),
  )
  diagnostics.metrics.set("raw_count", inspect.raw_count.to_string())
  diagnostics.metrics.set(
    "paragraph_count",
    inspect.paragraph_count.to_string(),
  )
  diagnostics.metrics.set("line_count", inspect.line_count.to_string())
  diagnostics.metrics.set("char_count", inspect.char_count.to_string())
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("event_count", events.length().to_string())
  diagnostics.metrics.set("text_markup_compact_events", "true")
  mark_structured_document_profile(diagnostics)
  diagnostics.metrics.set(
    "warning_count",
    diagnostics.warnings.length().to_string(),
  )
  diagnostics.metrics.set(
    "degraded_feature_count",
    diagnostics.degraded_features.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
  diagnostics.pass_trace.push("parse:" + hooks.parser_name + ":compact_events")
  diagnostics.pass_trace.push("parse:" + hooks.parser_name)
  @parser.parse_result_with_events_capability(
    hooks.parser_name,
    @parser.ParserMode::DomAstModel,
    events,
    diagnostics,
    text_markup_parser_capability(),
  )
}

///|
fn text_markup_compact_events(
  doc : @dmark.TextMarkupDocument,
  source : @input.InputSource,
  diagnostics : @core.Diagnostics,
  hooks : TextMarkupHooks,
) -> Array[@core.CoreEvent] {
  let events : Array[@core.CoreEvent] = Array::new(
    capacity=doc.blocks.length() + doc.blocks.length() / 4,
  )
  let pending : Array[@dmark.TextMarkupBlock] = []
  let inline_markdown_cache : Map[String, String] = Map([])
  fn flush_list_events(
    events : Array[@core.CoreEvent],
    pending : Array[@dmark.TextMarkupBlock],
    source : @input.InputSource,
    hooks : TextMarkupHooks,
  ) -> Unit {
    if pending.length() == 0 {
      return
    }
    let list_ref = text_markup_event_ref(
      text_markup_source_ref(
        source,
        hooks.format_name,
        pending[0].line_start,
        pending[pending.length() - 1].line_end,
      ),
      [("ordered", if pending[0].ordered { "true" } else { "false" })],
    )
    events.push({
      kind: @core.EventKind::StartBlock(@core.BlockKind::List),
      text: "",
      source_ref: Some(list_ref),
    })
    for item in pending {
      let item_ref = text_markup_event_ref(
        text_markup_source_ref(
          source,
          hooks.format_name,
          item.line_start,
          item.line_end,
        ),
        [
          ("ordered", if item.ordered { "true" } else { "false" }),
          ("literal", "true"),
        ],
      )
      events.push({
        kind: @core.EventKind::StartBlock(@core.BlockKind::ListItem),
        text: if text_markup_might_have_inline_markup(item.text, hooks.format) {
          text_markup_render_inline_markdown_cached(
            item.text,
            hooks.format,
            inline_markdown_cache,
          )
        } else {
          item.text
        },
        source_ref: Some(item_ref),
      })
      events.push({
        kind: @core.EventKind::EndBlock(@core.BlockKind::ListItem),
        text: "",
        source_ref: Some(item_ref),
      })
    }
    events.push({
      kind: @core.EventKind::EndBlock(@core.BlockKind::List),
      text: "",
      source_ref: Some(list_ref),
    })
    pending.clear()
  }
  for block in doc.blocks {
    if block.kind == @dmark.TextMarkupBlockKind::ListItem {
      pending.push(block)
      continue
    }
    flush_list_events(events, pending, source, hooks)
    text_markup_append_block_events(
      events, block, source, diagnostics, hooks, inline_markdown_cache,
    )
  }
  flush_list_events(events, pending, source, hooks)
  if events.length() == 0 {
    let empty_ref = text_markup_event_ref(
      text_markup_source_ref(source, hooks.format_name, 1, 1),
      [("literal", "true")],
    )
    events.push({
      kind: @core.EventKind::StartBlock(@core.BlockKind::Paragraph),
      text: "[empty document]",
      source_ref: Some(empty_ref),
    })
    events.push({
      kind: @core.EventKind::EndBlock(@core.BlockKind::Paragraph),
      text: "",
      source_ref: Some(empty_ref),
    })
  }
  events
}

///|
fn text_markup_append_block_events(
  events : Array[@core.CoreEvent],
  block : @dmark.TextMarkupBlock,
  source : @input.InputSource,
  diagnostics : @core.Diagnostics,
  hooks : TextMarkupHooks,
  inline_markdown_cache : Map[String, String],
) -> Unit {
  let source_ref = text_markup_source_ref(
    source,
    hooks.format_name,
    block.line_start,
    block.line_end,
  )
  match block.kind {
    @dmark.TextMarkupBlockKind::Heading =>
      text_markup_append_simple_event_block(
        events,
        @core.BlockKind::Heading,
        block.text,
        text_markup_event_ref(source_ref, [
          ("level", block.level.to_string()),
          ("literal", "true"),
        ]),
        hooks.format,
        false,
        inline_markdown_cache,
      )
    @dmark.TextMarkupBlockKind::Paragraph =>
      text_markup_append_simple_event_block(
        events,
        @core.BlockKind::Paragraph,
        block.text,
        text_markup_event_ref(source_ref, [("literal", "true")]),
        hooks.format,
        true,
        inline_markdown_cache,
      )
    @dmark.TextMarkupBlockKind::Code => {
      let attrs : Array[(String, String)] = [("info", hooks.format_name)]
      for entry in block.meta.to_array() {
        attrs.push(entry)
      }
      text_markup_append_simple_event_block(
        events,
        @core.BlockKind::Code,
        block.text,
        text_markup_event_ref(source_ref, attrs),
        hooks.format,
        false,
        inline_markdown_cache,
      )
    }
    @dmark.TextMarkupBlockKind::NoteDefinition => {
      let core = @core.make_block(
        @core.BlockKind::Paragraph,
        block.text,
        source_ref~,
      )
      for entry in block.meta.to_array() {
        core.attrs.set(entry.0, entry.1)
      }
      text_markup_append_core_block_events(
        events,
        text_markup_block_with_inlines(core, block.text, hooks.format),
      )
    }
    @dmark.TextMarkupBlockKind::Table =>
      match @dmark.parse_text_markup_table(block, hooks.format) {
        Some(table) =>
          text_markup_append_core_block_events(
            events,
            text_markup_table_block(
              table,
              source_ref,
              hooks.format_name,
              hooks.format,
            ),
          )
        None => {
          let core = @core.make_block(
            @core.BlockKind::Raw,
            block.text,
            source_ref~,
          )
          core.attrs.set("raw_kind", hooks.format_name + "_table_boundary")
          core.attrs.set("info", hooks.format_name)
          text_markup_append_core_block_events(events, core)
        }
      }
    @dmark.TextMarkupBlockKind::BlockQuote => {
      let text = (hooks.quote_text)(block, hooks.format_name)
      let core = @core.make_block(
        @core.BlockKind::BlockQuote,
        text,
        source_ref~,
      )
      core.attrs.set("literal", "true")
      for entry in block.meta.to_array() {
        core.attrs.set(entry.0, entry.1)
      }
      text_markup_append_core_block_events(
        events,
        text_markup_block_with_inlines(core, text, hooks.format),
      )
    }
    @dmark.TextMarkupBlockKind::Semantic => {
      let core = match
        (hooks.semantic_block)(block, source_ref, hooks.format_name) {
        Some(value) => value
        None => {
          let text = (hooks.quote_text)(block, hooks.format_name)
          let value = @core.make_block(
            @core.BlockKind::Paragraph,
            text,
            source_ref~,
          )
          value.attrs.set("literal", "true")
          text_markup_block_with_inlines(value, text, hooks.format)
        }
      }
      text_markup_apply_semantic_attrs(
        core,
        block,
        diagnostics,
        hooks.format_name,
      )
      text_markup_append_core_block_events(events, core)
    }
    @dmark.TextMarkupBlockKind::Raw => {
      let core = match
        (hooks.semantic_raw_block)(block, source_ref, hooks.format_name) {
        Some(value) => value
        None => {
          let value = @core.make_block(
            @core.BlockKind::Raw,
            block.text,
            source_ref~,
          )
          value.attrs.set("raw_kind", hooks.format_name + "_raw_boundary")
          value.attrs.set("info", hooks.format_name)
          value
        }
      }
      for entry in block.meta.to_array() {
        core.attrs.set(entry.0, entry.1)
      }
      text_markup_append_core_block_events(events, core)
    }
    @dmark.TextMarkupBlockKind::ListItem => ()
  }
}

///|
fn text_markup_append_simple_event_block(
  events : Array[@core.CoreEvent],
  kind : @core.BlockKind,
  text : String,
  source_ref : @core.SourceRef,
  format : @dmark.TextMarkupFormat,
  include_inlines : Bool,
  inline_markdown_cache : Map[String, String],
) -> Unit {
  if !include_inlines || !text_markup_might_have_inline_markup(text, format) {
    source_ref.extra.set("ir_text_markup_compact_leaf", "true")
    events.push({
      kind: @core.EventKind::StartBlock(kind),
      text,
      source_ref: Some(source_ref),
    })
    return
  }
  source_ref.extra.set("ir_text_markup_compact_leaf", "true")
  source_ref.extra.set("ir_text_markup_rendered_inline", "true")
  events.push({
    kind: @core.EventKind::StartBlock(kind),
    text: text_markup_render_inline_markdown_cached(
      text, format, inline_markdown_cache,
    ),
    source_ref: Some(source_ref),
  })
}

///|
fn text_markup_render_inline_markdown(
  text : String,
  format : @dmark.TextMarkupFormat,
) -> String {
  let out = StringBuilder::new()
  for inline in @dmark.parse_text_markup_inlines(text, format) {
    match inline.kind {
      @dmark.TextMarkupInlineKind::Text =>
        text_markup_write_escaped_inline(out, inline.text)
      @dmark.TextMarkupInlineKind::Link => {
        let label_out = StringBuilder::new()
        text_markup_write_escaped_inline(label_out, inline.text)
        let label = label_out.to_string().trim().to_owned()
        let href = inline.href.unwrap_or("").trim().to_owned()
        if label == "" || href == "" {
          out.write_string(label_out.to_string())
        } else {
          out.write_string("[")
          out.write_string(label)
          out.write_string("](")
          out.write_string(href)
          out.write_char(')')
        }
      }
      @dmark.TextMarkupInlineKind::Code => {
        let fence = text_markup_inline_code_fence(inline.text)
        out.write_string(fence)
        if inline.text.contains("`") {
          out.write_char(' ')
        }
        out.write_string(inline.text)
        if inline.text.contains("`") {
          out.write_char(' ')
        }
        out.write_string(fence)
      }
    }
  }
  out.to_string()
}

///|
fn text_markup_render_inline_markdown_cached(
  text : String,
  format : @dmark.TextMarkupFormat,
  cache : Map[String, String],
) -> String {
  match cache.get(text) {
    Some(value) => value
    None => {
      let value = text_markup_render_inline_markdown(text, format)
      cache.set(text, value)
      value
    }
  }
}

///|
fn text_markup_write_escaped_inline(out : StringBuilder, text : String) -> Unit {
  for ch in text {
    let cp = ch.to_int()
    if cp > 0xFFFF {
      out.write_string("&#")
      out.write_string(cp.to_string())
      out.write_char(';')
      continue
    }
    if ch == '\\' ||
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
      ch == '|' {
      out.write_char('\\')
    }
    out.write_char(ch)
  }
}

///|
fn text_markup_inline_code_fence(text : String) -> String {
  let mut max_run = 0
  let mut current = 0
  for ch in text {
    if ch == '`' {
      current += 1
      if current > max_run {
        max_run = current
      }
    } else {
      current = 0
    }
  }
  let width = if max_run + 1 < 1 { 1 } else { max_run + 1 }
  let out = StringBuilder::new()
  for _ in 0..<width {
    out.write_char('`')
  }
  out.to_string()
}

///|
fn text_markup_event_ref(
  source_ref : @core.SourceRef,
  attrs : Array[(String, String)],
) -> @core.SourceRef {
  let next = { ..source_ref, extra: Map([]) }
  next.extra.set("ir_event_encoding", "text_markup_compact_v1")
  for attr in attrs {
    next.extra.set("ir_block_attr_" + attr.0, attr.1)
  }
  next
}

///|
fn text_markup_append_core_block_events(
  events : Array[@core.CoreEvent],
  block : @core.CoreBlock,
) -> Unit {
  let source_ref = text_markup_event_ref(
    block.source_ref.unwrap_or(@core.empty_source_ref()),
    block.attrs.to_array(),
  )
  events.push({
    kind: @core.EventKind::StartBlock(block.kind),
    text: block.text,
    source_ref: Some(source_ref),
  })
  match block.rich_inlines {
    Some(inlines) =>
      for inline in inlines {
        let inline_ref = {
          ..inline.source_ref.unwrap_or(source_ref),
          extra: Map([]),
        }
        match inline.kind {
          @core.InlineKind::Link => {
            inline_ref.extra.set("ir_inline_kind", "link")
            inline_ref.extra.set("ir_inline_href", inline.href.unwrap_or("#"))
          }
          @core.InlineKind::Code =>
            inline_ref.extra.set("ir_inline_kind", "code")
          @core.InlineKind::Image => {
            inline_ref.extra.set("ir_inline_kind", "image")
            inline_ref.extra.set("ir_inline_href", inline.href.unwrap_or("#"))
          }
          @core.InlineKind::LineBreak =>
            inline_ref.extra.set("ir_inline_kind", "line_break")
          _ => inline_ref.extra.set("ir_inline_kind", "text")
        }
        events.push({
          kind: @core.EventKind::Text,
          text: inline.text,
          source_ref: Some(inline_ref),
        })
      }
    None => ()
  }
  for child in block.children {
    text_markup_append_core_block_events(events, child)
  }
  events.push({
    kind: @core.EventKind::EndBlock(block.kind),
    text: "",
    source_ref: Some(source_ref),
  })
}

///|
pub fn parse_text_markup_result_with_preparsed_document(
  source : @input.InputSource,
  context : @parser.ParseContext,
  _text : String,
  doc : @dmark.TextMarkupDocument,
  inspect : @dmark.TextMarkupInspectReport,
  hooks : TextMarkupHooks,
  diagnostics? : @core.Diagnostics = empty_parser_diagnostics(
    hooks.parser_name,
    @parser.ParserMode::DomAstModel,
    source,
    hooks.format_name,
  ),
) -> @parser.ParseResult {
  init_parser_route_metrics(
    diagnostics,
    source,
    context,
    hooks.format_name,
    hooks.parser_name,
    @parser.ParserMode::DomAstModel,
    @parser.ParserMode::DomAstModel,
    "document",
    "none",
    "dom_ast_model",
  )
  apply_product_metrics(diagnostics, hooks.format_name)
  let document = lower_text_markup_document(doc, source, diagnostics, hooks)
  diagnostics.metrics.set("block_count", inspect.block_count.to_string())
  diagnostics.metrics.set("heading_count", inspect.heading_count.to_string())
  diagnostics.metrics.set(
    "list_item_count",
    inspect.list_item_count.to_string(),
  )
  diagnostics.metrics.set("code_count", inspect.code_count.to_string())
  diagnostics.metrics.set("table_count", inspect.table_count.to_string())
  diagnostics.metrics.set(
    "blockquote_count",
    inspect.blockquote_count.to_string(),
  )
  diagnostics.metrics.set("raw_count", inspect.raw_count.to_string())
  diagnostics.metrics.set(
    "paragraph_count",
    inspect.paragraph_count.to_string(),
  )
  diagnostics.metrics.set("line_count", inspect.line_count.to_string())
  diagnostics.metrics.set("char_count", inspect.char_count.to_string())
  diagnostics.metrics.set("asset_count", "0")
  mark_structured_document_profile(diagnostics)
  diagnostics.metrics.set(
    "warning_count",
    diagnostics.warnings.length().to_string(),
  )
  diagnostics.metrics.set(
    "degraded_feature_count",
    diagnostics.degraded_features.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
  diagnostics.pass_trace.push("parse:" + hooks.parser_name)
  let final_document = @core.document_with_diagnostics(document, diagnostics)
  @parser.parse_result_with_document_capability(
    hooks.parser_name,
    @parser.ParserMode::DomAstModel,
    final_document,
    diagnostics,
    text_markup_parser_capability(),
  )
}

///|
pub fn lower_text_markup_document(
  doc : @dmark.TextMarkupDocument,
  source : @input.InputSource,
  diagnostics : @core.Diagnostics,
  hooks : TextMarkupHooks,
) -> @core.DocumentIR {
  let document = {
    ..@core.empty_document_ir(),
    blocks: Array::new(capacity=doc.blocks.length()),
  }
  let pending_list_items : Array[@dmark.TextMarkupBlock] = []
  let inline_cache : Map[String, Array[@core.CoreInline]] = Map([])
  let paragraph_cache : Map[String, CachedLoweredBlock] = Map([])
  let heading_cache : Map[String, CachedLoweredBlock] = Map([])
  let unordered_item_cache : Map[String, CachedLoweredBlock] = Map([])
  let ordered_item_cache : Map[String, CachedLoweredBlock] = Map([])
  let table_cache : Map[String, CachedLoweredTree] = Map([])
  let raw_cache : Map[String, Map[String, CachedRawTree]] = Map([])
  let diagnostic_templates = text_markup_diagnostic_templates(hooks.format_name)
  fn flush_list(
    document : @core.DocumentIR,
    pending_list_items : Array[@dmark.TextMarkupBlock],
    source : @input.InputSource,
    format_name : String,
    format : @dmark.TextMarkupFormat,
    inline_cache : Map[String, Array[@core.CoreInline]],
    unordered_item_cache : Map[String, CachedLoweredBlock],
    ordered_item_cache : Map[String, CachedLoweredBlock],
  ) -> Unit {
    if pending_list_items.length() == 0 {
      return
    }
    let list = @core.make_block(
      @core.BlockKind::List,
      "",
      source_ref=text_markup_source_ref(
        source,
        format_name,
        pending_list_items[0].line_start,
        pending_list_items[pending_list_items.length() - 1].line_end,
      ),
    )
    list.attrs.set(
      "ordered",
      if pending_list_items[0].ordered {
        "true"
      } else {
        "false"
      },
    )
    for item in pending_list_items {
      let item_ref = text_markup_source_ref(
        source,
        format_name,
        item.line_start,
        item.line_end,
      )
      let item_cache = if item.ordered {
        ordered_item_cache
      } else {
        unordered_item_cache
      }
      let item_block = match item_cache.get(item.text) {
        Some(cached) => text_markup_rebase_cached_block(cached, item_ref)
        None => {
          let value = @core.make_block(
            @core.BlockKind::ListItem,
            item.text,
            source_ref=item_ref,
          )
          value.attrs.set(
            "ordered",
            if item.ordered {
              "true"
            } else {
              "false"
            },
          )
          value.attrs.set("literal", "true")
          let value = text_markup_block_with_cached_inlines(
            value,
            item.text,
            format,
            inline_cache,
          )
          item_cache.set(item.text, cached_lowered_block(value))
          value
        }
      }
      list.children.push(item_block)
    }
    document.blocks.push(list)
    pending_list_items.clear()
  }
  for block in doc.blocks {
    if block.kind == @dmark.TextMarkupBlockKind::ListItem {
      pending_list_items.push(block)
      continue
    }
    flush_list(
      document,
      pending_list_items,
      source,
      hooks.format_name,
      hooks.format,
      inline_cache,
      unordered_item_cache,
      ordered_item_cache,
    )
    let source_ref = text_markup_source_ref(
      source,
      hooks.format_name,
      block.line_start,
      block.line_end,
    )
    match block.kind {
      @dmark.TextMarkupBlockKind::Heading => {
        let heading_key = block.level.to_string() + "\u{0000}" + block.text
        let heading = match heading_cache.get(heading_key) {
          Some(cached) => text_markup_rebase_cached_block(cached, source_ref)
          None => {
            let value = @core.make_block(
              @core.BlockKind::Heading,
              block.text,
              source_ref~,
            )
            value.attrs.set("level", block.level.to_string())
            value.attrs.set("literal", "true")
            heading_cache.set(heading_key, cached_lowered_block(value))
            value
          }
        }
        document.blocks.push(heading)
      }
      @dmark.TextMarkupBlockKind::Paragraph => {
        let paragraph = match paragraph_cache.get(block.text) {
          Some(cached) => text_markup_rebase_cached_block(cached, source_ref)
          None => {
            let value = @core.block_with_attr(
              text_markup_block_with_cached_inlines(
                @core.make_block(
                  @core.BlockKind::Paragraph,
                  block.text,
                  source_ref~,
                ),
                block.text,
                hooks.format,
                inline_cache,
              ),
              "literal",
              "true",
            )
            paragraph_cache.set(block.text, cached_lowered_block(value))
            value
          }
        }
        document.blocks.push(paragraph)
      }
      @dmark.TextMarkupBlockKind::Code => {
        let code = @core.make_block(
          @core.BlockKind::Code,
          block.text,
          source_ref~,
        )
        code.attrs.set("info", hooks.format_name)
        for entry in block.meta.to_array() {
          code.attrs.set(entry.0, entry.1)
          if entry.0 == "degraded_feature" {
            diagnostics.degraded_features.push(
              hooks.format_name + "_" + entry.1,
            )
          }
        }
        if block.meta.contains("directive_kind") {
          diagnostics.warnings.push(
            hooks.format_name +
            " degraded semantic environment preserved as typed code block",
          )
          diagnostics.fallback_trace.push(
            hooks.format_name + " semantic environment -> typed code block",
          )
        }
        document.blocks.push(code)
      }
      @dmark.TextMarkupBlockKind::NoteDefinition => {
        let note = @core.make_block(
          @core.BlockKind::Paragraph,
          block.text,
          source_ref~,
        )
        for entry in block.meta.to_array() {
          note.attrs.set(entry.0, entry.1)
        }
        document.blocks.push(
          text_markup_block_with_cached_inlines(
            note,
            block.text,
            hooks.format,
            inline_cache,
          ),
        )
      }
      @dmark.TextMarkupBlockKind::Table =>
        match table_cache.get(block.text) {
          Some(cached) =>
            document.blocks.push(
              text_markup_rebase_cached_tree(cached, source_ref),
            )
          None =>
            match @dmark.parse_text_markup_table(block, hooks.format) {
              Some(table_model) => {
                let table = text_markup_table_block(
                  table_model,
                  source_ref,
                  hooks.format_name,
                  hooks.format,
                )
                table_cache.set(block.text, cached_lowered_tree(table))
                document.blocks.push(table)
              }
              None => {
                let table = @core.make_block(
                  @core.BlockKind::Raw,
                  block.text,
                  source_ref~,
                )
                table.attrs.set(
                  "raw_kind",
                  hooks.format_name + "_table_boundary",
                )
                table.attrs.set("info", hooks.format_name)
                diagnostics.degraded_features.push(
                  hooks.format_name + "_table_boundary",
                )
                diagnostics.warnings.push(
                  hooks.format_name + " simple table preserved as raw block",
                )
                diagnostics.fallback_trace.push(
                  hooks.format_name + " simple table -> raw fenced block",
                )
                document.blocks.push(table)
              }
            }
        }
      @dmark.TextMarkupBlockKind::BlockQuote => {
        let quote_text = (hooks.quote_text)(block, hooks.format_name)
        let quote = @core.make_block(
          @core.BlockKind::BlockQuote,
          quote_text,
          source_ref~,
        )
        quote.attrs.set("literal", "true")
        for entry in block.meta.to_array() {
          quote.attrs.set(entry.0, entry.1)
          if entry.0 == "degraded_feature" {
            diagnostics.degraded_features.push(
              hooks.format_name + "_" + entry.1,
            )
          }
        }
        diagnostics.warnings.push(diagnostic_templates.quote_warning)
        diagnostics.fallback_trace.push(diagnostic_templates.quote_fallback)
        document.blocks.push(
          text_markup_block_with_cached_inlines(
            quote,
            quote_text,
            hooks.format,
            inline_cache,
          ),
        )
      }
      @dmark.TextMarkupBlockKind::Semantic =>
        match (hooks.semantic_block)(block, source_ref, hooks.format_name) {
          Some(semantic) => {
            text_markup_apply_semantic_attrs(
              semantic,
              block,
              diagnostics,
              hooks.format_name,
            )
            document.blocks.push(semantic)
          }
          None => {
            let text = (hooks.quote_text)(block, hooks.format_name)
            let semantic = @core.make_block(
              @core.BlockKind::Paragraph,
              text,
              source_ref~,
            )
            semantic.attrs.set("literal", "true")
            text_markup_apply_semantic_attrs(
              semantic,
              block,
              diagnostics,
              hooks.format_name,
            )
            document.blocks.push(
              text_markup_block_with_cached_inlines(
                semantic,
                text,
                hooks.format,
                inline_cache,
              ),
            )
          }
        }
      @dmark.TextMarkupBlockKind::Raw => {
        let signature = text_markup_meta_signature(block.meta)
        let cached = match raw_cache.get(block.text) {
          Some(entries) => entries.get(signature)
          None => None
        }
        let lowered = match cached {
          Some(value) => {
            text_markup_apply_raw_diagnostics(
              block,
              diagnostics,
              hooks.format_name,
              value.semantic,
              diagnostic_templates,
            )
            text_markup_rebase_cached_tree(value.tree, source_ref)
          }
          None => {
            let (value, semantic) = match
              (hooks.semantic_raw_block)(block, source_ref, hooks.format_name) {
              Some(value) => (value, true)
              None => {
                let value = @core.make_block(
                  @core.BlockKind::Raw,
                  block.text,
                  source_ref~,
                )
                value.attrs.set("raw_kind", hooks.format_name + "_raw_boundary")
                value.attrs.set("info", hooks.format_name)
                (value, false)
              }
            }
            for entry in block.meta.to_array() {
              value.attrs.set(entry.0, entry.1)
            }
            text_markup_apply_raw_diagnostics(
              block,
              diagnostics,
              hooks.format_name,
              semantic,
              diagnostic_templates,
            )
            let entries = raw_cache.get(block.text).unwrap_or(Map([]))
            entries.set(signature, {
              tree: cached_lowered_tree(value),
              semantic,
            })
            raw_cache.set(block.text, entries)
            value
          }
        }
        document.blocks.push(lowered)
      }
      @dmark.TextMarkupBlockKind::ListItem => ()
    }
  }
  flush_list(
    document,
    pending_list_items,
    source,
    hooks.format_name,
    hooks.format,
    inline_cache,
    unordered_item_cache,
    ordered_item_cache,
  )
  if document.blocks.length() == 0 {
    document.blocks.push(
      @core.block_with_attr(
        @core.make_block(
          @core.BlockKind::Paragraph,
          "[empty document]",
          source_ref=text_markup_source_ref(source, hooks.format_name, 1, 1),
        ),
        "literal",
        "true",
      ),
    )
  }
  document
}

///|
fn text_markup_block_with_cached_inlines(
  block : @core.CoreBlock,
  text : String,
  format : @dmark.TextMarkupFormat,
  cache : Map[String, Array[@core.CoreInline]],
) -> @core.CoreBlock {
  let inlines = match cache.get(text) {
    Some(value) => value
    None => {
      let value = text_markup_inlines(text, format)
      cache.set(text, value)
      value
    }
  }
  if inlines.length() == 0 {
    block
  } else {
    @core.block_with_rich_inlines(block, Some(inlines))
  }
}

///|
fn text_markup_rebase_cached_block(
  cached : CachedLoweredBlock,
  source_ref : @core.SourceRef,
) -> @core.CoreBlock {
  let block = cached.block
  {
    ..block,
    block_id: @core.finish_block_id(cached.content_crc, Some(source_ref)),
    source_ref: Some(source_ref),
  }
}

///|
priv struct CachedLoweredBlock {
  block : @core.CoreBlock
  content_crc : UInt
}

///|
fn cached_lowered_block(block : @core.CoreBlock) -> CachedLoweredBlock {
  { block, content_crc: @core.make_block_content_crc(block.kind, block.text) }
}

///|
priv struct CachedLoweredTree {
  block : @core.CoreBlock
  content_crc : UInt
  children : Array[CachedLoweredTree]
}

///|
priv struct CachedRawTree {
  tree : CachedLoweredTree
  semantic : Bool
}

///|
fn cached_lowered_tree(block : @core.CoreBlock) -> CachedLoweredTree {
  {
    block,
    content_crc: @core.make_block_content_crc(block.kind, block.text),
    children: block.children.map(cached_lowered_tree),
  }
}

///|
fn text_markup_rebase_cached_tree(
  cached : CachedLoweredTree,
  source_ref : @core.SourceRef,
) -> @core.CoreBlock {
  let block = cached.block
  {
    ..block,
    block_id: @core.finish_block_id(cached.content_crc, Some(source_ref)),
    source_ref: Some(source_ref),
    children: cached.children.map(child => {
      text_markup_rebase_cached_tree(child, source_ref)
    }),
  }
}

///|
fn text_markup_meta_signature(meta : Map[String, String]) -> String {
  if meta.length() == 0 {
    return ""
  }
  let entries = meta.to_array()
  entries.sort_by(fn(left, right) { left.0.compare(right.0) })
  entries.map(entry => entry.0 + "=" + entry.1).join("\u{0000}")
}

///|
fn text_markup_apply_raw_diagnostics(
  block : @dmark.TextMarkupBlock,
  diagnostics : @core.Diagnostics,
  format_name : String,
  semantic : Bool,
  templates : TextMarkupDiagnosticTemplates,
) -> Unit {
  for entry in block.meta.to_array() {
    if entry.0 == "degraded_feature" {
      diagnostics.degraded_features.push(format_name + "_" + entry.1)
    }
  }
  if semantic {
    diagnostics.warnings.push(templates.semantic_raw_warning)
    diagnostics.fallback_trace.push(templates.semantic_raw_fallback)
  } else {
    diagnostics.warnings.push(templates.raw_warning)
    diagnostics.fallback_trace.push(templates.raw_fallback)
  }
}

///|
fn prepare_text_markup_document_for_hooks(
  source : @input.InputSource,
  hooks : TextMarkupHooks,
) -> Result[@dmark.PreparedTextMarkupDocument, String] {
  match hooks.format {
    @dmark.TextMarkupFormat::Tex =>
      @dmark.prepare_tex_document_from_source(source)
    @dmark.TextMarkupFormat::Rst =>
      @dmark.prepare_rst_document_from_source(source)
    @dmark.TextMarkupFormat::Asciidoc =>
      @dmark.prepare_asciidoc_document_from_source(source)
  }
}

///|
fn text_markup_apply_semantic_attrs(
  semantic : @core.CoreBlock,
  block : @dmark.TextMarkupBlock,
  diagnostics : @core.Diagnostics,
  format_name : String,
) -> Unit {
  semantic.attrs.set("text_markup_semantic", "true")
  match block.meta.get("semantic_kind") {
    Some(kind) => semantic.attrs.set("semantic_kind", kind)
    None => ()
  }
  if block.meta.get("semantic_kind") == Some("include") {
    semantic.attrs.set("render_boundary", "semantic")
    semantic.attrs.set(
      "render_boundary_key",
      format_name + ":include:" + block.line_start.to_string(),
    )
  }
  for entry in block.meta.to_array() {
    semantic.attrs.set(entry.0, entry.1)
    if entry.0 == "degraded_feature" {
      diagnostics.degraded_features.push(format_name + "_" + entry.1)
    }
  }
  diagnostics.warnings.push(format_name + " canonical semantic block activated")
  diagnostics.fallback_trace.push(
    format_name + " semantic boundary -> canonical semantic block",
  )
}

///|
pub fn text_markup_source_ref(
  source : @input.InputSource,
  format_name : String,
  line_start : Int,
  line_end : Int,
) -> @core.SourceRef {
  @core.source_ref_with_lines(
    @core.empty_source_ref(),
    Some(source.source_name),
    Some(format_name),
    Some(line_start),
    Some(line_end),
  )
}

///|
pub fn text_markup_block_with_inlines(
  block : @core.CoreBlock,
  text : String,
  format : @dmark.TextMarkupFormat,
) -> @core.CoreBlock {
  let inlines = text_markup_inlines(text, format)
  if inlines.length() == 0 {
    block
  } else {
    @core.block_with_rich_inlines(block, Some(inlines))
  }
}

///|
pub fn text_markup_inlines(
  text : String,
  format : @dmark.TextMarkupFormat,
) -> Array[@core.CoreInline] {
  if !text_markup_might_have_inline_markup(text, format) {
    return []
  }
  let out : Array[@core.CoreInline] = []
  for inline in @dmark.parse_text_markup_inlines(text, format) {
    match inline.kind {
      @dmark.TextMarkupInlineKind::Text =>
        out.push(@core.make_inline_text(inline.text))
      @dmark.TextMarkupInlineKind::Link =>
        out.push(@core.make_inline_link(inline.text, inline.href.unwrap_or("")))
      @dmark.TextMarkupInlineKind::Code =>
        out.push(@core.make_inline_code(inline.text))
    }
  }
  out
}

///|
fn text_markup_might_have_inline_markup(
  text : String,
  format : @dmark.TextMarkupFormat,
) -> Bool {
  if text.contains("`") {
    return true
  }
  match format {
    @dmark.TextMarkupFormat::Rst =>
      text.contains("<") && text.contains(">") && text.contains("`")
    @dmark.TextMarkupFormat::Asciidoc => text.contains("link:")
    @dmark.TextMarkupFormat::Tex =>
      text.contains("\\href{") || text.contains("\\texttt{")
  }
}

///|
pub fn text_markup_table_block(
  table_model : @dmark.TextMarkupTable,
  source_ref : @core.SourceRef,
  format_name : String,
  format : @dmark.TextMarkupFormat,
) -> @core.CoreBlock {
  let table = @core.make_block(@core.BlockKind::Table, "table", source_ref~)
  table.attrs.set("info", format_name)
  table.children.push(
    text_markup_table_row(table_model.header, source_ref, format),
  )
  for row_values in table_model.rows {
    table.children.push(text_markup_table_row(row_values, source_ref, format))
  }
  table
}

///|
pub fn text_markup_table_row(
  values : Array[String],
  source_ref : @core.SourceRef,
  format : @dmark.TextMarkupFormat,
) -> @core.CoreBlock {
  let row = @core.make_block(@core.BlockKind::TableRow, "", source_ref~)
  for value in values {
    let cell = @core.make_block(@core.BlockKind::TableCell, value, source_ref~)
    let rich = text_markup_inlines(value, format)
    row.children.push(
      if rich.length() == 0 {
        cell
      } else {
        @core.block_with_rich_inlines(cell, Some(rich))
      },
    )
  }
  row
}
