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
  let text = match @input.read_input_text(source) {
    Ok(payload) => payload
    Err(err) => return Err(err)
  }
  let diagnostics = empty_parser_diagnostics(
    hooks.parser_name,
    @parser.ParserMode::DomAstModel,
    source,
    hooks.format_name,
  )
  let doc = (hooks.parse_document)(text)
  let inspect = @dmark.inspect_text_markup_document(doc, text)
  Ok(
    parse_text_markup_result_with_preparsed_document(
      source,
      context,
      text,
      doc,
      inspect,
      hooks,
      diagnostics~,
    ),
  )
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
  let document = @core.empty_document_ir()
  let pending_list_items : Array[@dmark.TextMarkupBlock] = []
  fn flush_list(
    document : @core.DocumentIR,
    pending_list_items : Array[@dmark.TextMarkupBlock],
    source : @input.InputSource,
    format_name : String,
    format : @dmark.TextMarkupFormat,
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
      let block = @core.make_block(
        @core.BlockKind::ListItem,
        item.text,
        source_ref=text_markup_source_ref(
          source,
          format_name,
          item.line_start,
          item.line_end,
        ),
      )
      block.attrs.set("ordered", if item.ordered { "true" } else { "false" })
      block.attrs.set("literal", "true")
      list.children.push(
        text_markup_block_with_inlines(block, item.text, format),
      )
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
    )
    let source_ref = text_markup_source_ref(
      source,
      hooks.format_name,
      block.line_start,
      block.line_end,
    )
    match block.kind {
      @dmark.TextMarkupBlockKind::Heading => {
        let heading = @core.make_block(
          @core.BlockKind::Heading,
          block.text,
          source_ref~,
        )
        heading.attrs.set("level", block.level.to_string())
        heading.attrs.set("literal", "true")
        document.blocks.push(heading)
      }
      @dmark.TextMarkupBlockKind::Paragraph =>
        document.blocks.push(
          @core.block_with_attr(
            text_markup_block_with_inlines(
              @core.make_block(
                @core.BlockKind::Paragraph,
                block.text,
                source_ref~,
              ),
              block.text,
              hooks.format,
            ),
            "literal",
            "true",
          ),
        )
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
          text_markup_block_with_inlines(note, block.text, hooks.format),
        )
      }
      @dmark.TextMarkupBlockKind::Table =>
        match @dmark.parse_text_markup_table(block, hooks.format) {
          Some(table_model) =>
            document.blocks.push(
              text_markup_table_block(
                table_model,
                source_ref,
                hooks.format_name,
                hooks.format,
              ),
            )
          None => {
            let table = @core.make_block(
              @core.BlockKind::Raw,
              block.text,
              source_ref~,
            )
            table.attrs.set("raw_kind", hooks.format_name + "_table_boundary")
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
        diagnostics.warnings.push(
          hooks.format_name +
          " degraded complex quote/admonition preserved as block quote",
        )
        diagnostics.fallback_trace.push(
          hooks.format_name + " complex quote/admonition -> block quote",
        )
        document.blocks.push(
          text_markup_block_with_inlines(quote, quote_text, hooks.format),
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
              text_markup_block_with_inlines(semantic, text, hooks.format),
            )
          }
        }
      @dmark.TextMarkupBlockKind::Raw => {
        match (hooks.semantic_raw_block)(block, source_ref, hooks.format_name) {
          Some(semantic) => {
            for entry in block.meta.to_array() {
              semantic.attrs.set(entry.0, entry.1)
              if entry.0 == "degraded_feature" {
                diagnostics.degraded_features.push(
                  hooks.format_name + "_" + entry.1,
                )
              }
            }
            diagnostics.warnings.push(
              hooks.format_name +
              " degraded complex boundary preserved as semantic text block",
            )
            diagnostics.fallback_trace.push(
              hooks.format_name + " complex boundary -> semantic text block",
            )
            document.blocks.push(semantic)
            continue
          }
          None => ()
        }
        let raw = @core.make_block(
          @core.BlockKind::Raw,
          block.text,
          source_ref~,
        )
        raw.attrs.set("raw_kind", hooks.format_name + "_raw_boundary")
        raw.attrs.set("info", hooks.format_name)
        for entry in block.meta.to_array() {
          raw.attrs.set(entry.0, entry.1)
          if entry.0 == "degraded_feature" {
            diagnostics.degraded_features.push(
              hooks.format_name + "_" + entry.1,
            )
          }
        }
        diagnostics.warnings.push(
          hooks.format_name +
          " degraded complex boundary preserved as raw block",
        )
        diagnostics.fallback_trace.push(
          hooks.format_name + " complex boundary -> raw fenced block",
        )
        document.blocks.push(raw)
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
