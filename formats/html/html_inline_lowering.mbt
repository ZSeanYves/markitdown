///|
fn html_horizontal_rule_block(
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
) -> @core.CoreBlock {
  let raw = @core.make_block(
    @core.BlockKind::Raw,
    "---",
    source_ref=html_block_source_ref(source, block),
  )
  raw.attrs.set("raw_kind", "thematic_break")
  raw
}

///|
fn html_unknown_container_blocks(
  state : HtmlLoweringState,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
  dom_blocks : Map[String, @dhtml.HtmlElement],
  index : HtmlLoweringIndex,
) -> Array[@core.CoreBlock] {
  if block.tag_name == "summary" {
    let summary = html_top_level_inline_facts_for_block(index, block.source_key)
    if summary.length() > 0 {
      return html_inline_segment_to_blocks(
        state,
        semantic,
        source,
        summary,
        html_inline_source_ref(source, summary[0]),
        index,
      )
    }
    if block.text_preview.trim() != "" {
      return [
        @core.make_block(
          @core.BlockKind::Paragraph,
          block.text_preview.trim().to_owned(),
          source_ref=html_block_source_ref(source, block),
        ),
      ]
    }
  }
  html_blocks_for_child_keys(
    state,
    semantic,
    source,
    block.children,
    dom_blocks,
    index,
  )
}

///|
fn html_blocks_for_child_keys(
  state : HtmlLoweringState,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  keys : Array[String],
  dom_blocks : Map[String, @dhtml.HtmlElement],
  index : HtmlLoweringIndex,
) -> Array[@core.CoreBlock] {
  let out : Array[@core.CoreBlock] = []
  for key in keys {
    match html_block_by_key(index, key) {
      Some(child) =>
        if !html_block_should_skip_descendant(index, child) {
          html_append_flattened_blocks(
            out,
            html_blocks_for_block(
              state, semantic, source, child, dom_blocks, index,
            ),
          )
        }
      None => ()
    }
  }
  out
}

///|
fn html_block_should_skip_descendant(
  index : HtmlLoweringIndex,
  block : @dhtml.HtmlBlockFact,
) -> Bool {
  index.skipped_block_keys.contains(block.source_key)
}

///|
fn html_append_flattened_blocks(
  out : Array[@core.CoreBlock],
  blocks : Array[@core.CoreBlock],
) -> Unit {
  for block in blocks {
    out.push(block)
  }
}

///|
fn html_inlines_for_block(
  state : HtmlLoweringState,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block_source_key : String,
  index : HtmlLoweringIndex,
) -> Array[@core.CoreInline] {
  html_inline_keys_to_core_inlines(
    state,
    semantic,
    source,
    html_top_level_inline_keys_for_block(index, block_source_key),
    true,
    index,
  )
}

///|
fn html_inlines_for_paragraph(
  state : HtmlLoweringState,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block_source_key : String,
  index : HtmlLoweringIndex,
) -> Array[@core.CoreInline] {
  match html_paragraph_for_block(index, block_source_key) {
    Some(paragraph) =>
      html_inline_keys_to_core_inlines(
        state,
        semantic,
        source,
        paragraph.inline_child_keys,
        true,
        index,
      )
    None =>
      html_inlines_for_block(state, semantic, source, block_source_key, index)
  }
}

///|
fn html_paragraph_inlines_to_blocks(
  inlines : Array[@core.CoreInline],
  source_ref : @core.SourceRef,
) -> Array[@core.CoreBlock] {
  let blocks : Array[@core.CoreBlock] = []
  let current : Array[@core.CoreInline] = []

  fn flush_paragraph(
    blocks : Array[@core.CoreBlock],
    current : Array[@core.CoreInline],
    source_ref : @core.SourceRef,
  ) -> Unit {
    let snapshot = html_trim_core_inlines_edges(current)
    let text = html_render_plain_inlines(snapshot).trim().to_owned()
    if text == "" {
      current.clear()
      return
    }
    let block = @core.make_block(@core.BlockKind::Paragraph, text, source_ref~)
    block.attrs.set("literal", "true")
    block.attrs.set("render_inline_escape_mode", "minimal")
    blocks.push(@core.block_with_rich_inlines(block, Some(snapshot)))
    current.clear()
  }

  for inline in inlines {
    match inline.kind {
      @core.InlineKind::Image => {
        flush_paragraph(blocks, current, source_ref)
        let image = @core.make_block(
          @core.BlockKind::Image,
          "",
          source_ref=inline.source_ref.unwrap_or(source_ref),
        )
        image.attrs.set("literal", "true")
        image.attrs.set("render_inline_escape_mode", "minimal")
        image.attrs.set("alt", inline.text.trim().to_owned())
        image.attrs.set("path", inline.href.unwrap_or("#"))
        match inline.title {
          Some(title) if title.trim() != "" =>
            image.attrs.set("title", title.trim().to_owned())
          None => ()
          _ => ()
        }
        blocks.push(image)
      }
      _ => current.push(inline)
    }
  }
  flush_paragraph(blocks, current, source_ref)
  blocks
}

///|
fn html_inline_segment_to_blocks(
  state : HtmlLoweringState,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  segment : Array[@dhtml.HtmlInlineFact],
  fallback_source_ref : @core.SourceRef,
  index : HtmlLoweringIndex,
) -> Array[@core.CoreBlock] {
  let inlines = html_inline_facts_to_core_inlines(
    state,
    semantic,
    source,
    segment,
    trim_edges=true,
    index,
  )
  let source_ref = if segment.length() > 0 {
    html_inline_source_ref(source, segment[0])
  } else {
    fallback_source_ref
  }
  html_paragraph_inlines_to_blocks(inlines, source_ref)
}

///|
fn html_core_inline_segment_to_blocks(
  inlines : Array[@core.CoreInline],
  fallback_source_ref : @core.SourceRef,
) -> Array[@core.CoreBlock] {
  let source_ref = if inlines.length() > 0 {
    inlines[0].source_ref.unwrap_or(fallback_source_ref)
  } else {
    fallback_source_ref
  }
  html_paragraph_inlines_to_blocks(inlines, source_ref)
}

///|
fn html_inline_facts_to_core_inlines(
  state : HtmlLoweringState,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  facts : Array[@dhtml.HtmlInlineFact],
  trim_edges? : Bool = false,
  index : HtmlLoweringIndex,
) -> Array[@core.CoreInline] {
  let keys = facts.map(inline => inline.source_key)
  let inlines = html_inline_keys_to_core_inlines(
    state, semantic, source, keys, true, index,
  )
  if trim_edges {
    html_trim_core_inlines_edges(inlines)
  } else {
    inlines
  }
}

///|
fn html_inline_keys_to_core_inlines(
  state : HtmlLoweringState,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  inline_keys : Array[String],
  allow_links : Bool,
  index : HtmlLoweringIndex,
) -> Array[@core.CoreInline] {
  let out : Array[@core.CoreInline] = []
  for key in inline_keys {
    match html_inline_by_key(index, key) {
      Some(inline) =>
        html_append_inline(
          state, out, semantic, source, inline, allow_links, index,
        )
      None => ()
    }
  }
  html_merge_adjacent_text_inlines(out)
}

///|
fn html_append_inline(
  state : HtmlLoweringState,
  out : Array[@core.CoreInline],
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  inline : @dhtml.HtmlInlineFact,
  allow_links : Bool,
  index : HtmlLoweringIndex,
) -> Unit {
  let source_ref = html_inline_source_ref(source, inline)
  match inline.kind {
    @dhtml.HtmlInlineKind::Text =>
      html_push_text_if_non_empty(out, html_inline_text(inline), source_ref)
    @dhtml.HtmlInlineKind::Break =>
      out.push(@core.make_inline_line_break(source_ref~))
    @dhtml.HtmlInlineKind::Image =>
      match html_image_for_inline(index, inline.source_key) {
        Some(image) =>
          match html_image_to_asset(state, source, image) {
            Some(asset) =>
              out.push(
                @core.make_inline_image(
                  image.alt.unwrap_or("image").trim().to_owned(),
                  asset.1.path.unwrap_or("#"),
                  title=image.title.map(v => v.trim().to_owned()),
                  source_ref~,
                ),
              )
            None => {
              let placeholder = html_image_placeholder_text(
                image.kind,
                image.alt.unwrap_or("image").trim().to_owned(),
              )
              html_push_text_if_non_empty(out, placeholder, source_ref)
            }
          }
        None => ()
      }
    @dhtml.HtmlInlineKind::Link => {
      if !allow_links {
        let children = html_inline_keys_to_core_inlines(
          state,
          semantic,
          source,
          inline.children,
          false,
          index,
        )
        if children.length() == 0 {
          html_push_text_if_non_empty(out, html_inline_text(inline), source_ref)
        } else {
          out.append(children[:])
        }
        return
      }
      match html_link_for_inline(index, inline.source_key) {
        Some(link) =>
          match html_product_href(link) {
            Some(href) => {
              let text = html_link_text(state, semantic, source, link, index)
                .trim()
                .to_owned()
              if text != "" {
                out.push(@core.make_inline_link(text, href, source_ref~))
              }
            }
            None =>
              html_push_text_if_non_empty(
                out,
                link.text_preview.trim().to_owned(),
                source_ref,
              )
          }
        None =>
          html_push_text_if_non_empty(out, html_inline_text(inline), source_ref)
      }
    }
    @dhtml.HtmlInlineKind::Emphasis
    | @dhtml.HtmlInlineKind::Strong
    | @dhtml.HtmlInlineKind::Code
    | @dhtml.HtmlInlineKind::Span
    | @dhtml.HtmlInlineKind::InlineContainer
    | @dhtml.HtmlInlineKind::UnknownInline => {
      let children = html_inline_keys_to_core_inlines(
        state,
        semantic,
        source,
        inline.children,
        allow_links,
        index,
      )
      if children.length() == 0 {
        html_push_text_if_non_empty(out, html_inline_text(inline), source_ref)
      } else {
        out.append(children[:])
      }
    }
    @dhtml.HtmlInlineKind::UnsupportedInline => ()
  }
}

///|
fn html_push_text_if_non_empty(
  out : Array[@core.CoreInline],
  text : String,
  source_ref : @core.SourceRef,
) -> Unit {
  if text != "" {
    out.push(@core.make_inline_text(text, source_ref~))
  }
}

///|
fn html_link_text(
  state : HtmlLoweringState,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  link : @dhtml.HtmlLinkFact,
  index : HtmlLoweringIndex,
) -> String {
  if link.inline_child_keys.length() == 0 {
    return link.text_preview
  }
  html_render_plain_inlines(
    html_inline_keys_to_core_inlines(
      state,
      semantic,
      source,
      link.inline_child_keys,
      false,
      index,
    ),
  )
}

///|
fn html_image_to_asset(
  state : HtmlLoweringState,
  source : @input.InputSource,
  image : @dhtml.HtmlImageFact,
) -> (String, @core.AssetRef)? {
  if image.kind != @dhtml.HtmlImageKind::Local {
    return None
  }
  let src = html_strip_query_and_hash(image.src.trim().to_owned())
  if !html_safe_local_image_src(src) {
    return None
  }
  for existing in state.assets {
    if existing.attrs.get("source_path") == Some(src) {
      return Some((existing.asset_id, existing))
    }
  }
  let asset_index = state.assets.length() + 1
  let asset_id = "html-image-" + asset_index.to_string()
  let rel_path = "assets/image" +
    html_two_digit(asset_index) +
    "." +
    html_image_ext_from_src(src)
  let asset = @core.make_asset_ref(
    @core.AssetKind::Image,
    asset_id,
    source_ref=html_image_source_ref(source, image),
  )
  let next_asset = {
    ..asset,
    path: Some(rel_path),
    attrs: Map([
      ("source_path", src),
      ("alt", image.alt.unwrap_or("image").trim().to_owned()),
    ]),
  }
  state.assets.push(next_asset)
  Some((asset_id, next_asset))
}

///|
fn html_image_block_from_asset(
  asset_id : String,
  asset : @core.AssetRef,
  alt : String,
  title : String?,
  caption : String?,
) -> @core.CoreBlock {
  let image = @core.make_block(
    @core.BlockKind::Image,
    "",
    source_ref=asset.source_ref.unwrap_or(@core.empty_source_ref()),
  )
  image.attrs.set("alt", alt)
  image.attrs.set("path", asset.path.unwrap_or("#"))
  image.attrs.set("asset_id", asset_id)
  match title {
    Some(value) if value.trim() != "" =>
      image.attrs.set("title", value.trim().to_owned())
    None => ()
    _ => ()
  }
  match caption {
    Some(value) if value.trim() != "" =>
      image.attrs.set("caption", value.trim().to_owned())
    None => ()
    _ => ()
  }
  image
}

///|
fn with_html_image_attrs(
  block : @core.CoreBlock,
  template : @core.CoreBlock,
) -> @core.CoreBlock {
  { ..block, attrs: template.attrs, source_ref: template.source_ref }
}

///|
fn html_image_placeholder_text(
  kind : @dhtml.HtmlImageKind,
  alt : String,
) -> String {
  let label = if alt == "" { "image" } else { alt }
  match kind {
    @dhtml.HtmlImageKind::Remote => "[remote]"
    @dhtml.HtmlImageKind::DataUri => "[inline data]"
    @dhtml.HtmlImageKind::Unsafe => "[" + label + "]"
    _ => "[" + label + "]"
  }
}

///|
fn html_table_to_block(
  state : HtmlLoweringState,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block_source_key : String,
  index : HtmlLoweringIndex,
) -> @core.CoreBlock? {
  match html_table_for_block(index, block_source_key) {
    Some(table) => {
      if table.row_count == 0 || table.cell_count == 0 {
        return None
      }
      let out = @core.make_block(
        @core.BlockKind::Table,
        "table",
        source_ref=html_block_source_ref_by_key(
          source, semantic, block_source_key, index,
        ),
      )
      out.attrs.set(
        "header_rows",
        html_table_header_rows(index, table).to_string(),
      )
      for row_key in table.rows {
        match html_table_row_by_key(index, row_key) {
          Some(row) => {
            let row_values : Array[String] = []
            for cell_key in row.cell_source_keys {
              match html_table_cell_by_key(index, cell_key) {
                Some(cell) => {
                  let value = html_table_cell_text(
                    state, semantic, source, cell, index,
                  )
                  row_values.push(value)
                }
                None => ()
              }
            }
            let row_block = @core.make_block(
              @core.BlockKind::TableRow,
              row_values.join(" | "),
              source_ref=html_table_row_source_ref(source, row),
            )
            row_block.attrs.set("literal", "true")
            for value_index in 0..<row_values.length() {
              let cell_ref = if value_index < row.cell_source_keys.length() {
                match
                  html_table_cell_by_key(
                    index,
                    row.cell_source_keys[value_index],
                  ) {
                  Some(cell) => html_table_cell_source_ref(source, cell)
                  None => html_table_row_source_ref(source, row)
                }
              } else {
                html_table_row_source_ref(source, row)
              }
              let mut cell_block = @core.make_block(
                @core.BlockKind::TableCell,
                row_values[value_index],
                source_ref=cell_ref,
              )
              cell_block.attrs.set("literal", "true")
              cell_block.attrs.set("render_inline_escape_mode", "minimal")
              if value_index < row.cell_source_keys.length() {
                match
                  html_table_cell_by_key(
                    index,
                    row.cell_source_keys[value_index],
                  ) {
                  Some(cell) => {
                    let inlines = html_table_cell_inlines(
                      state, semantic, source, cell, index,
                    )
                    if inlines.length() > 0 {
                      cell_block = @core.block_with_rich_inlines(
                        cell_block,
                        Some(inlines),
                      )
                    }
                  }
                  None => ()
                }
              }
              row_block.children.push(cell_block)
            }
            out.children.push(row_block)
          }
          None => ()
        }
      }
      Some(out)
    }
    None => None
  }
}

///|
fn html_table_cell_text(
  state : HtmlLoweringState,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  cell : @dhtml.HtmlTableCellFact,
  index : HtmlLoweringIndex,
) -> String {
  let inlines = html_inline_keys_to_core_inlines(
    state,
    semantic,
    source,
    cell.inline_child_keys,
    true,
    index,
  )
  let text = html_render_plain_inlines(inlines).trim().to_owned()
  if text == "" {
    cell.text_preview.trim().to_owned()
  } else {
    text
  }
}

///|
fn html_table_cell_inlines(
  state : HtmlLoweringState,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  cell : @dhtml.HtmlTableCellFact,
  index : HtmlLoweringIndex,
) -> Array[@core.CoreInline] {
  html_inline_keys_to_core_inlines(
    state,
    semantic,
    source,
    cell.inline_child_keys,
    true,
    index,
  )
}

///|
fn malformed_html_parse_result(
  source : @input.InputSource,
  text : String,
  diagnostics : @core.Diagnostics,
  err : String,
) -> @parser.ParseResult {
  diagnostics.warnings.push("html parse warning: " + err)
  diagnostics.errors.push("html fail closed: malformed input is not converted")
  diagnostics.degraded_features.push("html_fail_closed")
  diagnostics.fallback_trace.push("html fail closed: " + err)
  diagnostics.metrics.set("parser_name", "html_parser")
  diagnostics.metrics.set("parser_mode", "dom_ast_model")
  diagnostics.metrics.set("input_kind", @fshared.input_kind_name(source.kind))
  diagnostics.metrics.set("detected_format", "html")
  diagnostics.metrics.set("requested_mode", "default")
  diagnostics.metrics.set("effective_mode", "dom_ast_model")
  diagnostics.metrics.set("ir_input_kind", "document")
  diagnostics.metrics.set("event_granularity", "none")
  diagnostics.metrics.set("event_semantics", "html_dom_ast_model_failed_closed")
  diagnostics.metrics.set("node_count", "0")
  diagnostics.metrics.set("element_count", "0")
  diagnostics.metrics.set("text_node_count", "0")
  diagnostics.metrics.set("script_count", "0")
  diagnostics.metrics.set("style_count", "0")
  diagnostics.metrics.set("link_count", "0")
  diagnostics.metrics.set("image_count", "0")
  diagnostics.metrics.set("table_count", "0")
  diagnostics.metrics.set("asset_count", "0")
  diagnostics.metrics.set("block_count", "0")
  diagnostics.metrics.set("event_count", "0")
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("dom_limit_reached", "false")
  diagnostics.metrics.set("unsafe_node_count", "0")
  diagnostics.metrics.set("dropped_node_count", "0")
  diagnostics.metrics.set("unsupported_feature_count", "0")
  diagnostics.metrics.set(
    "line_count",
    @fshared.count_physical_lines(text).to_string(),
  )
  diagnostics.metrics.set("char_count", text.length().to_string())
  diagnostics.metrics.set("degraded_feature_count", "1")
  diagnostics.metrics.set("fallback_count", "1")
  diagnostics.pass_trace.push("parse:html_parser")
  let document = @core.empty_document_ir()
  let final_document = @core.document_with_diagnostics(document, diagnostics)
  @parser.parse_result_with_document_capability(
    "html_parser",
    @parser.ParserMode::DomAstModel,
    final_document,
    diagnostics,
    html_parser_capability(),
  )
}

///|
fn html_top_level_inline_keys_for_block(
  index : HtmlLoweringIndex,
  block_source_key : String,
) -> Array[String] {
  html_top_level_inline_facts_for_block(index, block_source_key).map(inline => {
    inline.source_key
  })
}

///|
fn html_inline_text(inline : @dhtml.HtmlInlineFact) -> String {
  html_normalize_inline_text(inline.raw_text_preview)
}

///|
fn html_normalize_inline_text(text : String) -> String {
  let chars = text.to_array()
  let mut has_layout_whitespace = false
  for ch in chars {
    if ch == '\n' || ch == '\r' || ch == '\t' {
      has_layout_whitespace = true
      break
    }
  }
  if !has_layout_whitespace {
    return text
  }
  let out = StringBuilder::new()
  let mut prev_space = false
  for ch in chars {
    if ch == '\n' || ch == '\r' || ch == '\t' || ch == ' ' {
      if !prev_space {
        out.write_char(' ')
      }
      prev_space = true
    } else {
      out.write_char(ch)
      prev_space = false
    }
  }
  out.to_string()
}

///|
fn html_product_href(link : @dhtml.HtmlLinkFact) -> String? {
  let href = link.href.trim().to_owned()
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
fn html_render_plain_inlines(inlines : Array[@core.CoreInline]) -> String {
  let out = StringBuilder::new()
  for inline in inlines {
    match inline.kind {
      @core.InlineKind::Text => out.write_string(inline.text)
      @core.InlineKind::LineBreak => out.write_string("<br>")
      @core.InlineKind::Link =>
        if inline.text.trim() != "" {
          out.write_string(inline.text)
        }
      @core.InlineKind::Image =>
        if inline.text.trim() != "" {
          out.write_string("[" + inline.text.trim().to_owned() + "]")
        } else {
          out.write_string("[image]")
        }
      @core.InlineKind::Code => out.write_string(inline.text)
    }
  }
  out.to_string()
}

///|
fn html_merge_adjacent_text_inlines(
  inlines : Array[@core.CoreInline],
) -> Array[@core.CoreInline] {
  let out : Array[@core.CoreInline] = []
  for inline in inlines {
    match inline.kind {
      @core.InlineKind::Text =>
        if inline.text != "" {
          match out.pop() {
            Some(prev) if prev.kind == @core.InlineKind::Text =>
              out.push(
                @core.make_inline_text(
                  prev.text + inline.text,
                  source_ref=prev.source_ref.unwrap_or(@core.empty_source_ref()),
                ),
              )
            Some(prev) => {
              out.push(prev)
              out.push(inline)
            }
            None => out.push(inline)
          }
        }
      _ => out.push(inline)
    }
  }
  out
}
