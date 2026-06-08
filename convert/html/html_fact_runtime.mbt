///|
/// M11 normal runtime lowering path.
///
/// Source structure comes exclusively from doc_parse/html parser facts. Convert
/// still owns Markdown/IR, asset export, origin, note placement, and noise
/// product policy.
priv struct HtmlConvertContext {
  semantic : @dphtml.HtmlSemanticDocument
  max_h : Int
  source_name : String
  image_ctx : HtmlImageExportCtx
  blocks : Array[@cor.Block]
  origins : Array[@cor.Origin?]
  skipped_block_keys : Map[String, Bool]
  note_body_block_keys : Map[String, Bool]
  emitted_block_keys : Map[String, Bool]
  note_defs_by_body_key : Map[String, @cor.NoteDefinition]
  note_refs_by_inline_key : Map[String, @cor.NoteRef]
  note_definitions : Array[@cor.NoteDefinition]
  lowering_state : HtmlSemanticLoweringState
}

///|
fn html_semantic_document_to_blocks(
  semantic : @dphtml.HtmlSemanticDocument,
  max_h : Int,
  input_path : String,
  out_dir : String,
) -> HtmlBlocksResult raise {
  let lowering_state = build_html_semantic_lowering_state(semantic)
  let ctx : HtmlConvertContext = {
    semantic,
    max_h,
    source_name: @cor.basename(input_path),
    image_ctx: new_html_image_export_ctx(input_path, out_dir),
    blocks: [],
    origins: [],
    skipped_block_keys: Map([]),
    note_body_block_keys: Map([]),
    emitted_block_keys: Map([]),
    note_defs_by_body_key: Map([]),
    note_refs_by_inline_key: Map([]),
    note_definitions: [],
    lowering_state,
  }

  html_fact_prepare_note_defs(ctx)
  html_fact_prepare_skip_keys(ctx)

  match html_fact_selected_scope_root(ctx) {
    Some(root_key) => html_fact_emit_scope_children(ctx, root_key)
    None => html_fact_emit_root_blocks(ctx)
  }

  {
    blocks: ctx.blocks,
    asset_source_paths: ctx.image_ctx.src_by_asset_path,
    block_origins: ctx.origins,
    note_definitions: ctx.note_definitions,
    semantic_lowering_state: Some(ctx.lowering_state),
  }
}

///|
fn html_fact_prepare_note_defs(ctx : HtmlConvertContext) -> Unit {
  for note in ctx.semantic.notes {
    match note.body_source_key {
      Some(body_key) =>
        match html_fact_note_body_by_key(ctx.semantic, body_key) {
          Some(body) =>
            if body.note_id.unwrap_or("").trim() != "" {
              let note_def = html_fact_make_note_definition(ctx, body, note)
              ctx.note_defs_by_body_key.set(body_key, note_def)
              ctx.note_definitions.push(note_def)
            }
          None => ()
        }
      None => ()
    }
    match note.ref_source_key {
      Some(ref_key) =>
        match html_fact_note_ref_by_key(ctx.semantic, ref_key) {
          Some(note_ref) =>
            if note.body_source_key is Some(_) {
              ctx.note_refs_by_inline_key.set(
                note_ref.inline_source_key,
                html_fact_make_note_ref(note_ref, note),
              )
            }
          None => ()
        }
      None => ()
    }
  }
}

///|
fn html_fact_prepare_skip_keys(ctx : HtmlConvertContext) -> Unit {
  for body in ctx.semantic.note_bodies {
    ctx.note_body_block_keys.set(body.block_source_key, true)
    html_fact_mark_block_subtree(
      ctx.semantic,
      body.block_source_key,
      ctx.note_body_block_keys,
    )
  }

  for noise in ctx.semantic.noise_candidates {
    match noise.block_source_key {
      Some(key) =>
        if html_fact_noise_should_skip(ctx, noise) {
          ctx.skipped_block_keys.set(key, true)
          html_fact_mark_block_subtree(
            ctx.semantic,
            key,
            ctx.skipped_block_keys,
          )
        }
      None => ()
    }
  }
}

///|
fn html_fact_emit_scope_children(
  ctx : HtmlConvertContext,
  root_key : String,
) -> Unit {
  match html_fact_block_by_key(ctx.semantic, root_key) {
    Some(root) =>
      for key in root.children {
        html_fact_emit_block_key(ctx, key)
      }
    None => html_fact_emit_root_blocks(ctx)
  }
}

///|
fn html_fact_emit_root_blocks(ctx : HtmlConvertContext) -> Unit {
  for block in ctx.semantic.blocks {
    if block.parent_source_key is None {
      html_fact_emit_block(ctx, block)
    }
  }
}

///|
fn html_fact_emit_block_key(ctx : HtmlConvertContext, key : String) -> Unit {
  match html_fact_block_by_key(ctx.semantic, key) {
    Some(block) => html_fact_emit_block(ctx, block)
    None => ()
  }
}

///|
fn html_fact_emit_block(
  ctx : HtmlConvertContext,
  block : @dphtml.HtmlBlockFact,
) -> Unit {
  if ctx.emitted_block_keys.contains(block.source_key) ||
    html_fact_block_is_skipped(ctx, block.source_key) {
    return
  }
  ctx.emitted_block_keys.set(block.source_key, true)

  match block.kind {
    @dphtml.HtmlBlockKind::Heading(level) => {
      let inlines = html_fact_inline_keys_to_ir(
        ctx,
        html_semantic_top_level_inline_keys_for_block(
          ctx.semantic,
          block.source_key,
        ),
        true,
      )
      let before = ctx.blocks.length()
      html_fact_push_block(
        ctx,
        @cor.Block::RichHeading(clamp_heading(level, ctx.max_h), inlines),
        block,
      )
      if ctx.blocks.length() > before {
        ctx.lowering_state.heading_lowered_count.val += 1
        ctx.lowering_state.inline_lowered_count.val += inlines.length()
      } else {
        ctx.lowering_state.heading_existing_path_count.val += 1
        ctx.lowering_state.heading_empty_guard_count.val += 1
      }
    }
    @dphtml.HtmlBlockKind::Paragraph =>
      html_fact_emit_paragraph_block(ctx, block)
    @dphtml.HtmlBlockKind::List(_) =>
      html_fact_emit_container_children(ctx, block)
    @dphtml.HtmlBlockKind::ListItem => html_fact_emit_list_item(ctx, block)
    @dphtml.HtmlBlockKind::Table => html_fact_emit_table(ctx, block)
    @dphtml.HtmlBlockKind::TableRow | @dphtml.HtmlBlockKind::TableCell(_) => ()
    @dphtml.HtmlBlockKind::BlockQuote => html_fact_emit_blockquote(ctx, block)
    @dphtml.HtmlBlockKind::Pre | @dphtml.HtmlBlockKind::CodeBlock =>
      html_fact_emit_code_block(ctx, block)
    @dphtml.HtmlBlockKind::Figure => html_fact_emit_figure(ctx, block)
    @dphtml.HtmlBlockKind::FigCaption => ()
    @dphtml.HtmlBlockKind::HorizontalRule => ()
    @dphtml.HtmlBlockKind::UnsupportedBlock => ()
    @dphtml.HtmlBlockKind::UnknownBlock => {
      html_fact_emit_candidate_paragraph(ctx, block)
      html_fact_emit_container_children(ctx, block)
    }
  }
}

///|
fn html_fact_emit_container_children(
  ctx : HtmlConvertContext,
  block : @dphtml.HtmlBlockFact,
) -> Unit {
  for key in block.children {
    html_fact_emit_block_key(ctx, key)
  }
}

///|
fn html_fact_emit_paragraph_block(
  ctx : HtmlConvertContext,
  block : @dphtml.HtmlBlockFact,
) -> Unit {
  match html_fact_paragraph_for_block(ctx.semantic, block.source_key) {
    Some(paragraph) => {
      let inlines = html_fact_inline_keys_to_html_inlines(
        ctx,
        paragraph.inline_child_keys,
        true,
      )
      let blocks = paragraph_inlines_to_blocks(inlines, ctx.image_ctx)
      if blocks.length() == 0 {
        ctx.lowering_state.paragraph_empty_guard_count.val += 1
        ctx.lowering_state.paragraph_existing_path_count.val += 1
        if paragraph.has_links {
          ctx.lowering_state.link_paragraph_existing_path_count.val += 1
        }
      }
      for out_block in blocks {
        let before = ctx.blocks.length()
        html_fact_push_block(ctx, out_block, block)
        if ctx.blocks.length() > before {
          html_fact_count_paragraph_output(
            ctx,
            ctx.blocks[ctx.blocks.length() - 1],
            paragraph,
          )
          ctx.lowering_state.paragraph_lowered_count.val += 1
          if paragraph.has_links {
            ctx.lowering_state.link_paragraph_lowered_count.val += 1
          }
        }
      }
      ctx.lowering_state.inline_lowered_count.val += inlines.length()
    }
    None => ()
  }
}

///|
fn html_fact_emit_candidate_paragraph(
  ctx : HtmlConvertContext,
  block : @dphtml.HtmlBlockFact,
) -> Unit {
  match html_fact_paragraph_for_block(ctx.semantic, block.source_key) {
    Some(paragraph) =>
      if paragraph.inline_child_keys.length() != 0 {
        let inlines = html_fact_inline_keys_to_html_inlines(
          ctx,
          paragraph.inline_child_keys,
          true,
        )
        let blocks = paragraph_inlines_to_blocks(inlines, ctx.image_ctx)
        for out_block in blocks {
          let before = ctx.blocks.length()
          html_fact_push_block(ctx, out_block, block)
          if ctx.blocks.length() > before {
            html_fact_count_paragraph_output(
              ctx,
              ctx.blocks[ctx.blocks.length() - 1],
              paragraph,
            )
            ctx.lowering_state.paragraph_lowered_count.val += 1
            if paragraph.has_links {
              ctx.lowering_state.link_paragraph_lowered_count.val += 1
            }
          }
        }
        ctx.lowering_state.inline_lowered_count.val += inlines.length()
      }
    None => ()
  }
}

///|
fn html_fact_emit_list_item(
  ctx : HtmlConvertContext,
  block : @dphtml.HtmlBlockFact,
) -> Unit {
  match html_fact_list_item_for_block(ctx.semantic, block.source_key) {
    Some(item) => {
      let ordered = match html_fact_list_for_item(ctx.semantic, item) {
        Some(list) => list.kind == @dphtml.HtmlListKind::Ordered
        None => false
      }
      let level = if item.list_depth <= 0 { 0 } else { item.list_depth - 1 }
      match html_fact_list_item_primary_inline_keys(ctx, item) {
        Some(keys) => {
          let inlines = html_fact_inline_keys_to_ir(ctx, keys, true)
          if render_ir_inlines(inlines).trim() != "" {
            html_fact_push_block(
              ctx,
              @cor.Block::RichListItem(ordered, level, inlines),
              block,
            )
            ctx.lowering_state.list_lowered_count.val += 1
            ctx.lowering_state.list_item_lowered_count.val += 1
            ctx.lowering_state.inline_lowered_count.val += inlines.length()
          } else {
            html_fact_push_block(
              ctx,
              @cor.Block::ListItem(ordered, level, item.text_preview),
              block,
            )
            ctx.lowering_state.list_existing_path_count.val += 1
            ctx.lowering_state.list_item_existing_path_count.val += 1
          }
        }
        None => {
          html_fact_push_block(
            ctx,
            @cor.Block::ListItem(
              ordered,
              level,
              html_fact_block_tree_to_text(ctx, block.source_key),
            ),
            block,
          )
          ctx.lowering_state.list_existing_path_count.val += 1
          ctx.lowering_state.list_item_existing_path_count.val += 1
        }
      }
      for child_key in item.child_list_source_keys {
        match html_fact_list_by_key(ctx.semantic, child_key) {
          Some(child_list) =>
            html_fact_emit_block_key(ctx, child_list.block_source_key)
          None => ()
        }
      }
    }
    None => html_fact_emit_container_children(ctx, block)
  }
}

///|
fn html_fact_emit_blockquote(
  ctx : HtmlConvertContext,
  block : @dphtml.HtmlBlockFact,
) -> Unit {
  match html_fact_blockquote_for_block(ctx.semantic, block.source_key) {
    Some(quote) =>
      match html_fact_quote_inline_keys(ctx, quote) {
        Some(keys) => {
          let inlines = html_fact_inline_keys_to_ir(ctx, keys, true)
          let rendered = render_ir_inlines(inlines).trim()
          if rendered != "" {
            html_fact_push_block(
              ctx,
              @cor.Block::RichBlockQuote(inlines),
              block,
            )
            ctx.lowering_state.blockquote_lowered_count.val += 1
            ctx.lowering_state.inline_lowered_count.val += inlines.length()
          }
        }
        None => {
          let text = html_fact_block_tree_to_text(ctx, block.source_key)
          if text.trim() != "" {
            html_fact_push_block(ctx, @cor.Block::BlockQuote(text), block)
          }
          ctx.lowering_state.blockquote_existing_path_count.val += 1
        }
      }
    None => html_fact_emit_container_children(ctx, block)
  }
}

///|
fn html_fact_emit_code_block(
  ctx : HtmlConvertContext,
  block : @dphtml.HtmlBlockFact,
) -> Unit {
  match html_fact_code_for_block(ctx.semantic, block.source_key) {
    Some(code) =>
      if code.code_text.trim() != "" {
        html_fact_push_block(ctx, @cor.Block::CodeBlock(code.code_text), block)
        if code.code_text_complete {
          ctx.lowering_state.code_block_lowered_count.val += 1
          if code.language_hint is Some(_) {
            ctx.lowering_state.code_block_language_hint_count.val += 1
          }
        } else {
          ctx.lowering_state.code_block_existing_path_count.val += 1
          ctx.lowering_state.code_block_incomplete_guard_count.val += 1
        }
      } else {
        ctx.lowering_state.code_block_empty_guard_count.val += 1
        ctx.lowering_state.code_block_existing_path_count.val += 1
      }
    None =>
      if block.text_preview.trim() != "" {
        html_fact_push_block(
          ctx,
          @cor.Block::CodeBlock(block.text_preview),
          block,
        )
        ctx.lowering_state.code_block_existing_path_count.val += 1
      }
  }
}

///|
fn html_fact_emit_figure(
  ctx : HtmlConvertContext,
  block : @dphtml.HtmlBlockFact,
) -> Unit {
  match html_fact_figure_for_block(ctx.semantic, block.source_key) {
    Some(figure) =>
      if figure.image_source_keys.length() > 0 {
        match
          html_semantic_image_by_key(ctx.semantic, figure.image_source_keys[0]) {
          Some(image) => {
            let img_inline = HtmlInline::Image(
              image.alt.unwrap_or(""),
              image.title,
              image.src,
            )
            let caption = match figure.caption_block_source_key {
              Some(caption_key) =>
                html_fact_inline_keys_to_html_inlines(
                  ctx,
                  html_semantic_top_level_inline_keys_for_block(
                    ctx.semantic,
                    caption_key,
                  ),
                  true,
                )
              None => []
            }
            match figure_to_image_block(img_inline, caption, ctx.image_ctx) {
              Some(out_block) => {
                html_fact_push_block(ctx, out_block, block)
                ctx.lowering_state.figure_lowered_count.val += 1
              }
              None => ctx.lowering_state.figure_existing_path_count.val += 1
            }
          }
          None => ()
        }
      } else {
        html_fact_emit_container_children(ctx, block)
      }
    None => html_fact_emit_container_children(ctx, block)
  }
}

///|
fn html_fact_emit_table(
  ctx : HtmlConvertContext,
  block : @dphtml.HtmlBlockFact,
) -> Unit {
  match html_fact_table_for_block(ctx.semantic, block.source_key) {
    Some(table) =>
      match html_fact_table_to_rich_table(ctx, table) {
        Some(table_data) => {
          html_fact_push_block(ctx, @cor.Block::RichTable(table_data), block)
          ctx.lowering_state.table_lowered_count.val += 1
          html_semantic_mark_table_guard(ctx.lowering_state, table)
          html_fact_emit_nested_table_blocks(ctx, table)
        }
        None => {
          ctx.lowering_state.table_guard_count.val += 1
          html_semantic_mark_table_guard(ctx.lowering_state, table)
          let text = table.text_preview.trim().to_owned()
          if text != "" {
            html_fact_push_block(ctx, @cor.Block::Paragraph(text), block)
          }
        }
      }
    None => ()
  }
}

///|
fn html_fact_emit_nested_table_blocks(
  ctx : HtmlConvertContext,
  table : @dphtml.HtmlTableFact,
) -> Unit {
  for cell_key in table.cells {
    match html_semantic_table_cell_by_key(ctx.semantic, cell_key) {
      Some(cell) =>
        for child_key in cell.direct_child_block_keys {
          match html_fact_block_by_key(ctx.semantic, child_key) {
            Some(child) =>
              match child.kind {
                @dphtml.HtmlBlockKind::Table => html_fact_emit_block(ctx, child)
                _ => ()
              }
            None => ()
          }
        }
      None => ()
    }
  }
}

///|
fn html_fact_push_block(
  ctx : HtmlConvertContext,
  block : @cor.Block,
  fact : @dphtml.HtmlBlockFact,
) -> Unit {
  match block {
    @cor.Block::RichHeading(_, inlines) =>
      if render_ir_inlines(inlines).trim() == "" {
        return
      }
    @cor.Block::RichParagraph(inlines) =>
      if render_ir_inlines(inlines).trim() == "" {
        return
      }
    @cor.Block::RichListItem(_, _, inlines) =>
      if render_ir_inlines(inlines).trim() == "" {
        return
      }
    @cor.Block::RichBlockQuote(inlines) =>
      if render_ir_inlines(inlines).trim() == "" {
        return
      }
    @cor.Block::Paragraph(text)
    | @cor.Block::Heading(_, text)
    | @cor.Block::ListItem(_, _, text)
    | @cor.Block::BlockQuote(text)
    | @cor.Block::CodeBlock(text) => if text.trim() == "" { return }
    @cor.Block::RichTable(table) => if table.rows.length() == 0 { return }
    @cor.Block::Table(rows) => if rows.length() == 0 { return }
    _ => ()
  }
  ctx.blocks.push(block)
  ctx.origins.push(html_fact_origin(ctx, fact))
}

///|
fn html_fact_origin(
  ctx : HtmlConvertContext,
  fact : @dphtml.HtmlBlockFact,
) -> @cor.Origin? {
  Some({
    source_name: Some(ctx.source_name),
    page: None,
    slide: None,
    sheet: None,
    block_index: None,
    heading_path: None,
    line_start: Some(fact.span.line_start),
    line_end: Some(fact.span.line_end),
    row_index: None,
    column_index: None,
    object_ref: Some(
      "html:" +
      html_fact_origin_kind(fact) +
      ":" +
      fact.source_order.to_string(),
    ),
    relationship_id: None,
    key_path: Some(
      "$.html[" +
      fact.source_order.to_string() +
      "]." +
      html_fact_origin_kind(fact),
    ),
  })
}

///|
fn html_fact_origin_kind(fact : @dphtml.HtmlBlockFact) -> String {
  match fact.kind {
    @dphtml.HtmlBlockKind::Heading(_) => "heading"
    @dphtml.HtmlBlockKind::Paragraph => "paragraph"
    @dphtml.HtmlBlockKind::List(_) => "list"
    @dphtml.HtmlBlockKind::ListItem => "list-item"
    @dphtml.HtmlBlockKind::Table => "table"
    @dphtml.HtmlBlockKind::TableRow => "table-row"
    @dphtml.HtmlBlockKind::TableCell(_) => "table-cell"
    @dphtml.HtmlBlockKind::BlockQuote => "blockquote"
    @dphtml.HtmlBlockKind::Pre => "pre"
    @dphtml.HtmlBlockKind::CodeBlock => "code"
    @dphtml.HtmlBlockKind::Figure => "figure"
    @dphtml.HtmlBlockKind::FigCaption => "figcaption"
    @dphtml.HtmlBlockKind::HorizontalRule => "hr"
    @dphtml.HtmlBlockKind::UnknownBlock => fact.tag_name
    @dphtml.HtmlBlockKind::UnsupportedBlock => "unsupported"
  }
}

///|
fn html_fact_inline_keys_to_ir(
  ctx : HtmlConvertContext,
  inline_keys : Array[String],
  allow_links : Bool,
) -> Array[@cor.Inline] {
  let out : Array[@cor.Inline] = []
  for
    inline in html_fact_inline_keys_to_html_inlines(
      ctx, inline_keys, allow_links,
    ) {
    match inline {
      HtmlInline::Text(t) => out.push(@cor.Inline::Text(t))
      HtmlInline::Break => out.push(@cor.Inline::Break)
      HtmlInline::Link(text, href) => out.push(@cor.Inline::Link(text, href))
      HtmlInline::NoteRef(note) => out.push(@cor.Inline::NoteRef(note))
      HtmlInline::Image(alt, _title, _src) =>
        out.push(
          @cor.Inline::Text(
            if alt.trim() == "" {
              "image"
            } else {
              alt.trim().to_owned()
            },
          ),
        )
    }
  }
  out
}

///|
fn html_fact_inline_keys_to_html_inlines(
  ctx : HtmlConvertContext,
  inline_keys : Array[String],
  allow_links : Bool,
) -> Array[HtmlInline] {
  let out : Array[HtmlInline] = []
  for key in inline_keys {
    match html_semantic_inline_by_key(ctx.semantic, key) {
      Some(fact) =>
        match html_fact_inline_to_html_inlines(ctx, fact, allow_links) {
          Some(items) => append_inlines(out, items)
          None => ()
        }
      None => ()
    }
  }
  merge_adjacent_text_inlines(out)
}

///|
fn html_fact_count_paragraph_output(
  ctx : HtmlConvertContext,
  block : @cor.Block,
  paragraph : @dphtml.HtmlParagraphFact,
) -> Unit {
  match block {
    @cor.Block::ImageBlock(_) => ctx.lowering_state.image_lowered_count.val += 1
    @cor.Block::Paragraph(_) =>
      if paragraph.has_images {
        ctx.lowering_state.image_existing_path_count.val += 1
      }
    _ => ()
  }
}

///|
fn html_fact_inline_to_html_inlines(
  ctx : HtmlConvertContext,
  inline : @dphtml.HtmlInlineFact,
  allow_links : Bool,
) -> Array[HtmlInline]? {
  match inline.kind {
    @dphtml.HtmlInlineKind::Text =>
      Some([HtmlInline::Text(html_semantic_product_text(inline))])
    @dphtml.HtmlInlineKind::Break => Some([HtmlInline::Break])
    @dphtml.HtmlInlineKind::Image =>
      match html_semantic_image_for_inline(ctx.semantic, inline.source_key) {
        Some(image) =>
          Some([
            HtmlInline::Image(image.alt.unwrap_or(""), image.title, image.src),
          ])
        None => None
      }
    @dphtml.HtmlInlineKind::Link =>
      if allow_links {
        match ctx.note_refs_by_inline_key.get(inline.source_key) {
          Some(note_ref) => Some([HtmlInline::NoteRef(note_ref)])
          None =>
            match
              html_semantic_link_for_inline(ctx.semantic, inline.source_key) {
              Some(link) =>
                match html_fact_product_href(link) {
                  Some(href) => {
                    let text = if link.inline_child_keys.length() == 0 {
                      link.text_preview
                    } else {
                      render_inlines(
                        html_fact_inline_keys_to_html_inlines(
                          ctx,
                          link.inline_child_keys,
                          false,
                        ),
                      )
                    }
                    if text.trim() != "" {
                      Some([HtmlInline::Link(text.trim().to_owned(), href)])
                    } else {
                      None
                    }
                  }
                  None =>
                    if link.is_note_ref &&
                      link.href.trim() != "" &&
                      link.text_preview.trim() != "" {
                      Some([
                        HtmlInline::Link(
                          link.text_preview.trim().to_owned(),
                          link.href.trim().to_owned(),
                        ),
                      ])
                    } else if link.text_preview.trim() != "" {
                      Some([
                        HtmlInline::Text(link.text_preview.trim().to_owned()),
                      ])
                    } else {
                      None
                    }
                }
              None => None
            }
        }
      } else {
        let children = html_fact_inline_keys_to_html_inlines(
          ctx,
          inline.children,
          false,
        )
        if children.length() == 0 && inline.text_preview.trim() != "" {
          Some([HtmlInline::Text(inline.text_preview.trim().to_owned())])
        } else {
          Some(children)
        }
      }
    @dphtml.HtmlInlineKind::Emphasis
    | @dphtml.HtmlInlineKind::Strong
    | @dphtml.HtmlInlineKind::Code
    | @dphtml.HtmlInlineKind::Span
    | @dphtml.HtmlInlineKind::InlineContainer => {
      let children = html_fact_inline_keys_to_html_inlines(
        ctx,
        inline.children,
        allow_links,
      )
      if children.length() == 0 && inline.text_preview.trim() != "" {
        Some([HtmlInline::Text(html_semantic_product_text(inline))])
      } else {
        Some(children)
      }
    }
    @dphtml.HtmlInlineKind::UnsupportedInline => None
    @dphtml.HtmlInlineKind::UnknownInline =>
      if inline.text_preview.trim() != "" {
        Some([HtmlInline::Text(html_semantic_product_text(inline))])
      } else {
        None
      }
  }
}

///|
fn html_fact_product_href(link : @dphtml.HtmlLinkFact) -> String? {
  match link.kind {
    @dphtml.HtmlLinkKind::Internal
    | @dphtml.HtmlLinkKind::External
    | @dphtml.HtmlLinkKind::Mailto
    | @dphtml.HtmlLinkKind::Tel
    | @dphtml.HtmlLinkKind::Unknown => sanitize_html_href(link.href)
    _ => None
  }
}

///|
fn html_fact_table_to_rich_table(
  ctx : HtmlConvertContext,
  table : @dphtml.HtmlTableFact,
) -> @cor.TableData? {
  if table.row_count == 0 || table.cell_count == 0 {
    return None
  }
  let rows : Array[Array[String]] = []
  let span_cells : Array[@cor.TableSpanHint] = []
  for row_key in table.rows {
    match html_semantic_table_row_by_key(ctx.semantic, row_key) {
      Some(row) => {
        let out_row : Array[String] = []
        let mut visual_column = 0
        for cell_key in row.cell_source_keys {
          match html_semantic_table_cell_by_key(ctx.semantic, cell_key) {
            Some(cell) => {
              let text = html_fact_table_cell_text(ctx, cell)
              out_row.push(text)
              if cell.rowspan_value > 1 || cell.colspan_value > 1 {
                span_cells.push({
                  row_index: cell.row_index + 1,
                  column_index: visual_column + 1,
                  rowspan: cell.rowspan_value,
                  colspan: cell.colspan_value,
                  text: normalized_optional_text(text),
                })
              }
              let mut i = 1
              while i < cell.colspan_value {
                out_row.push("")
                i += 1
              }
              visual_column += cell.colspan_value
            }
            None => return None
          }
        }
        rows.push(out_row)
      }
      None => return None
    }
  }
  Some({
    rows,
    header_rows: html_semantic_table_header_rows(ctx.semantic, table),
    hints: Some({
      format: Some("html"),
      sheet_state: None,
      merged_ranges: None,
      formula_cells: None,
      semantic_types: None,
      span_cells: if span_cells.length() == 0 {
        None
      } else {
        Some(span_cells)
      },
    }),
  })
}

///|
fn html_fact_table_cell_text(
  ctx : HtmlConvertContext,
  cell : @dphtml.HtmlTableCellFact,
) -> String {
  let inline_text = render_inlines(
    html_fact_inline_keys_to_html_inlines(ctx, cell.inline_child_keys, true),
  )
  if inline_text.trim() != "" {
    inline_text
  } else {
    @cor.normalize_document_text_cleanup(cell.text_preview)
  }
}

///|
fn html_fact_list_item_primary_inline_keys(
  ctx : HtmlConvertContext,
  item : @dphtml.HtmlListItemFact,
) -> Array[String]? {
  match html_fact_paragraph_for_block(ctx.semantic, item.block_source_key) {
    Some(paragraph) =>
      if paragraph.inline_child_keys.length() != 0 {
        return Some(paragraph.inline_child_keys)
      }
    None => ()
  }
  for paragraph in ctx.semantic.paragraphs {
    if paragraph.parent_block_source_key == Some(item.block_source_key) &&
      paragraph.inline_child_keys.length() != 0 {
      return Some(paragraph.inline_child_keys)
    }
  }
  None
}

///|
fn html_fact_quote_inline_keys(
  ctx : HtmlConvertContext,
  quote : @dphtml.HtmlBlockQuoteFact,
) -> Array[String]? {
  if quote.child_block_source_keys.length() == 0 {
    let keys = html_semantic_top_level_inline_keys_for_block(
      ctx.semantic,
      quote.block_source_key,
    )
    if keys.length() != 0 {
      return Some(keys)
    }
  }
  if quote.child_block_source_keys.length() == 1 {
    let child_key = quote.child_block_source_keys[0]
    match html_fact_block_by_key(ctx.semantic, child_key) {
      Some(child) =>
        match child.kind {
          @dphtml.HtmlBlockKind::Paragraph => {
            let keys = html_semantic_top_level_inline_keys_for_block(
              ctx.semantic,
              child_key,
            )
            if keys.length() != 0 {
              return Some(keys)
            }
          }
          _ => ()
        }
      None => ()
    }
  }
  None
}

///|
fn html_fact_block_tree_to_text(
  ctx : HtmlConvertContext,
  block_key : String,
) -> String {
  match html_fact_block_by_key(ctx.semantic, block_key) {
    Some(block) => {
      let parts : Array[String] = []
      let direct = render_inlines(
          html_fact_inline_keys_to_html_inlines(
            ctx,
            html_semantic_top_level_inline_keys_for_block(
              ctx.semantic,
              block_key,
            ),
            true,
          ),
        )
        .trim()
        .to_owned()
      if direct != "" {
        parts.push(direct)
      }
      for child_key in block.children {
        if !html_fact_block_is_skipped(ctx, child_key) {
          let child_text = html_fact_block_tree_to_text(ctx, child_key)
          if child_text.trim() != "" {
            parts.push(child_text.trim().to_owned())
          }
        }
      }
      if parts.length() == 0 {
        block.text_preview.trim().to_owned()
      } else {
        parts.join("\n\n")
      }
    }
    None => ""
  }
}

///|
fn html_fact_selected_scope_root(ctx : HtmlConvertContext) -> String? {
  match html_fact_scope_candidate(ctx, html_fact_block_has_exact_root_token) {
    Some(key) => return Some(key)
    None => ()
  }
  match html_fact_scope_candidate(ctx, html_fact_block_has_exact_content_id) {
    Some(key) => return Some(key)
    None => ()
  }
  match html_fact_scope_candidate(ctx, html_fact_block_role_is_main) {
    Some(key) => return Some(key)
    None => ()
  }
  match
    html_fact_scope_candidate(ctx, html_fact_block_has_strong_content_attr) {
    Some(key) => return Some(key)
    None => ()
  }
  match html_fact_first_block_by_tag(ctx.semantic, "article") {
    Some(key) => return Some(key)
    None => ()
  }
  match html_fact_first_block_by_tag(ctx.semantic, "main") {
    Some(key) => return Some(key)
    None => ()
  }
  match ctx.semantic.scope {
    [scope] => scope.selected_content_root_key
    _ => None
  }
}

///|
fn html_fact_scope_candidate(
  ctx : HtmlConvertContext,
  matcher : (@dphtml.HtmlBlockFact) -> Bool,
) -> String? {
  for block in ctx.semantic.blocks {
    if html_fact_scope_is_candidate_tag(block.tag_name) &&
      !html_fact_block_is_skipped(ctx, block.source_key) &&
      matcher(block) {
      return Some(block.source_key)
    }
  }
  None
}

///|
fn html_fact_scope_is_candidate_tag(tag_name : String) -> Bool {
  tag_name == "div" ||
  tag_name == "section" ||
  tag_name == "article" ||
  tag_name == "main"
}

///|
fn html_fact_block_has_exact_root_token(block : @dphtml.HtmlBlockFact) -> Bool {
  html_fact_attr_any_contains(
    block.attributes,
    ["id", "class"],
    "mw-content-text",
  ) ||
  html_fact_attr_any_contains(block.attributes, ["id", "class"], "bodycontent")
}

///|
fn html_fact_block_has_exact_content_id(block : @dphtml.HtmlBlockFact) -> Bool {
  let id = html_fact_attr_value(block.attributes, "id")
    .unwrap_or("")
    .to_lower()
    .trim()
    .to_owned()
  id == "content" || id == "maincontent"
}

///|
fn html_fact_block_role_is_main(block : @dphtml.HtmlBlockFact) -> Bool {
  html_fact_attr_value(block.attributes, "role")
  .map(fn(value) { value.to_lower().trim().to_owned() })
  .unwrap_or("") ==
  "main"
}

///|
fn html_fact_block_has_strong_content_attr(
  block : @dphtml.HtmlBlockFact,
) -> Bool {
  if html_fact_attr_any_has_noise_token(block.attributes, ["id", "class"]) {
    return false
  }
  html_fact_attr_is_strong_content_root(block.attributes, "id") ||
  html_fact_attr_is_strong_content_root(block.attributes, "class")
}

///|
fn html_fact_attr_is_strong_content_root(
  attrs : Array[@dphtml.HtmlSemanticAttributeSummary],
  name : String,
) -> Bool {
  match html_fact_attr_value(attrs, name) {
    None => false
    Some(value) => {
      let words = html_scope_attr_words(value)
      let has_body = html_scope_words_contain(words, "body")
      let has_content = html_scope_words_contain(words, "content")
      (has_body && has_content) ||
      (html_scope_words_contain(words, "article") && (has_body || has_content)) ||
      (html_scope_words_contain(words, "post") && (has_body || has_content)) ||
      (html_scope_words_contain(words, "entry") && (has_body || has_content)) ||
      (html_scope_words_contain(words, "story") && (has_body || has_content)) ||
      (html_scope_words_contain(words, "chapter") && (has_body || has_content))
    }
  }
}

///|
fn html_fact_noise_should_skip(
  ctx : HtmlConvertContext,
  noise : @dphtml.HtmlNoiseCandidateFact,
) -> Bool {
  if html_fact_noise_has_reason(
      noise,
      @dphtml.HtmlNoiseCandidateReason::Hiddenish,
    ) ||
    html_fact_noise_has_reason(
      noise,
      @dphtml.HtmlNoiseCandidateReason::ScriptStyleTemplate,
    ) ||
    html_fact_noise_has_reason(
      noise,
      @dphtml.HtmlNoiseCandidateReason::FooterLike,
    ) ||
    html_fact_noise_has_reason(
      noise,
      @dphtml.HtmlNoiseCandidateReason::RepeatedBoilerplate,
    ) {
    return true
  }
  if html_fact_noise_has_reason(
      noise,
      @dphtml.HtmlNoiseCandidateReason::SidebarLike,
    ) {
    if html_fact_noise_has_navigation_like_attr(noise) {
      return !html_fact_noise_has_substantial_prose(ctx, noise)
    }
    return html_fact_noise_has_product_noise_attr(noise)
  }
  if html_fact_noise_has_reason(
      noise,
      @dphtml.HtmlNoiseCandidateReason::NavLike,
    ) {
    return !html_fact_noise_has_substantial_prose(ctx, noise)
  }
  false
}

///|
fn html_fact_noise_has_navigation_like_attr(
  noise : @dphtml.HtmlNoiseCandidateFact,
) -> Bool {
  noise.tag_name == "nav" ||
  html_fact_attr_value(noise.attributes, "role")
  .map(fn(value) {
    let role = value.to_lower().trim().to_owned()
    role == "navigation" || role == "menu"
  })
  .unwrap_or(false) ||
  html_fact_attr_any_has_navigation_like_noise_token(noise.attributes, [
    "id", "class",
  ])
}

///|
fn html_fact_noise_has_product_noise_attr(
  noise : @dphtml.HtmlNoiseCandidateFact,
) -> Bool {
  html_fact_attr_any_has_noise_token(noise.attributes, ["id", "class"]) ||
  html_fact_attr_value(noise.attributes, "role")
  .map(fn(value) { value.to_lower().contains("complementary") })
  .unwrap_or(false)
}

///|
fn html_fact_noise_has_substantial_prose(
  ctx : HtmlConvertContext,
  noise : @dphtml.HtmlNoiseCandidateFact,
) -> Bool {
  match noise.block_source_key {
    Some(key) => {
      let mut paragraph_count = 0
      let mut text_len = 0
      for paragraph in ctx.semantic.paragraphs {
        if paragraph.block_source_key == key ||
          html_fact_block_is_descendant_of(
            ctx.semantic,
            paragraph.block_source_key,
            key,
          ) {
          paragraph_count += 1
          text_len += paragraph.text_preview.length()
        }
      }
      paragraph_count > 0 && text_len >= 80
    }
    None => false
  }
}

///|
fn html_fact_noise_has_reason(
  noise : @dphtml.HtmlNoiseCandidateFact,
  reason : @dphtml.HtmlNoiseCandidateReason,
) -> Bool {
  for item in noise.reasons {
    if item == reason {
      return true
    }
  }
  false
}

///|
fn html_fact_block_is_skipped(ctx : HtmlConvertContext, key : String) -> Bool {
  ctx.skipped_block_keys.contains(key) || ctx.note_body_block_keys.contains(key)
}

///|
fn html_fact_mark_block_subtree(
  semantic : @dphtml.HtmlSemanticDocument,
  root_key : String,
  dst : Map[String, Bool],
) -> Unit {
  for block in semantic.blocks {
    if block.parent_source_key == Some(root_key) {
      dst.set(block.source_key, true)
      html_fact_mark_block_subtree(semantic, block.source_key, dst)
    }
  }
}

///|
fn html_fact_make_note_ref(
  note_ref : @dphtml.HtmlNoteRefFact,
  note : @dphtml.HtmlNoteFact,
) -> @cor.NoteRef {
  let note_id = note.note_id.unwrap_or("").trim().to_owned()
  let marker = if note_ref.ref_text_preview.trim() == "" {
    note_id
  } else {
    note_ref.ref_text_preview.trim().to_owned()
  }
  {
    note_id,
    marker,
    kind: html_fact_note_kind(note.kind),
    source_kind: @cor.NoteSourceKind::HtmlNoteRef,
    confidence: html_fact_note_confidence(note.relation_confidence),
    body_status: if note.body_source_key is Some(_) {
      @cor.NoteBodyStatus::Resolved
    } else {
      @cor.NoteBodyStatus::Missing
    },
  }
}

///|
fn html_fact_make_note_definition(
  ctx : HtmlConvertContext,
  body : @dphtml.HtmlNoteBodyFact,
  note : @dphtml.HtmlNoteFact,
) -> @cor.NoteDefinition {
  let body_blocks = match
    html_fact_block_by_key(ctx.semantic, body.block_source_key) {
    Some(block) =>
      if body.body_text_preview.trim() != "" {
        [@cor.Block::Paragraph(body.body_text_preview.trim().to_owned())]
      } else {
        [@cor.Block::Paragraph(block.text_preview.trim().to_owned())]
      }
    None => [@cor.Block::Paragraph(body.body_text_preview.trim().to_owned())]
  }
  let note_id = body.note_id
    .unwrap_or(note.note_id.unwrap_or(""))
    .trim()
    .to_owned()
  {
    note_id,
    marker: if note.ref_text_preview.trim() == "" {
      body.marker.unwrap_or("").trim().to_owned()
    } else {
      note.ref_text_preview.trim().to_owned()
    },
    kind: html_fact_note_kind(body.kind),
    blocks: body_blocks,
    placement: @cor.NotePlacement::DocumentEnd,
    source_kind: @cor.NoteSourceKind::HtmlFootnoteBody,
    body_status: @cor.NoteBodyStatus::Resolved,
    origin: Some({
      source_name: Some(ctx.source_name),
      page: None,
      slide: None,
      sheet: None,
      block_index: None,
      heading_path: None,
      line_start: Some(body.span.line_start),
      line_end: Some(body.span.line_end),
      row_index: None,
      column_index: None,
      object_ref: Some("html:note-body:" + note_id),
      relationship_id: None,
      key_path: Some("$.html.notes[" + note_id + "]"),
    }),
  }
}

///|
fn html_fact_note_kind(kind : @dphtml.HtmlNoteKind) -> @cor.NoteKind {
  match kind {
    @dphtml.HtmlNoteKind::Footnote => @cor.NoteKind::Footnote
    @dphtml.HtmlNoteKind::EndnoteLike => @cor.NoteKind::Endnote
    @dphtml.HtmlNoteKind::Reference => @cor.NoteKind::Citation
    _ => @cor.NoteKind::Unknown
  }
}

///|
fn html_fact_note_confidence(
  confidence : @dphtml.HtmlNoteRelationConfidence,
) -> @cor.NoteConfidence {
  match confidence {
    @dphtml.HtmlNoteRelationConfidence::High => @cor.NoteConfidence::High
    @dphtml.HtmlNoteRelationConfidence::Medium => @cor.NoteConfidence::Medium
    _ => @cor.NoteConfidence::Low
  }
}

///|
fn html_fact_attr_value(
  attrs : Array[@dphtml.HtmlSemanticAttributeSummary],
  name : String,
) -> String? {
  let needle = name.to_lower()
  for attr in attrs {
    if attr.name.to_lower() == needle {
      return Some(attr.value_preview)
    }
  }
  None
}

///|
fn html_fact_attr_any_contains(
  attrs : Array[@dphtml.HtmlSemanticAttributeSummary],
  names : Array[String],
  needle : String,
) -> Bool {
  let lower_needle = needle.to_lower()
  for name in names {
    match html_fact_attr_value(attrs, name) {
      Some(value) => if value.to_lower().contains(lower_needle) { return true }
      None => ()
    }
  }
  false
}

///|
fn html_fact_attr_any_has_noise_token(
  attrs : Array[@dphtml.HtmlSemanticAttributeSummary],
  names : Array[String],
) -> Bool {
  for name in names {
    match html_fact_attr_value(attrs, name) {
      Some(value) =>
        if html_contains_noise_token(value.to_lower()) {
          return true
        }
      None => ()
    }
  }
  false
}

///|
fn html_fact_attr_any_has_navigation_like_noise_token(
  attrs : Array[@dphtml.HtmlSemanticAttributeSummary],
  names : Array[String],
) -> Bool {
  for name in names {
    match html_fact_attr_value(attrs, name) {
      Some(value) =>
        if html_contains_navigation_like_noise_token(value.to_lower()) {
          return true
        }
      None => ()
    }
  }
  false
}

///|
fn html_fact_block_by_key(
  semantic : @dphtml.HtmlSemanticDocument,
  key : String,
) -> @dphtml.HtmlBlockFact? {
  for block in semantic.blocks {
    if block.source_key == key {
      return Some(block)
    }
  }
  None
}

///|
fn html_fact_first_block_by_tag(
  semantic : @dphtml.HtmlSemanticDocument,
  tag_name : String,
) -> String? {
  for block in semantic.blocks {
    if block.tag_name == tag_name {
      return Some(block.source_key)
    }
  }
  None
}

///|
fn html_fact_block_is_descendant_of(
  semantic : @dphtml.HtmlSemanticDocument,
  child_key : String,
  ancestor_key : String,
) -> Bool {
  let mut current = html_semantic_block_parent_key(semantic, child_key)
  while current is Some(key) {
    if key == ancestor_key {
      return true
    }
    current = html_semantic_block_parent_key(semantic, key)
  }
  false
}

///|
fn html_fact_paragraph_for_block(
  semantic : @dphtml.HtmlSemanticDocument,
  block_key : String,
) -> @dphtml.HtmlParagraphFact? {
  for paragraph in semantic.paragraphs {
    if paragraph.block_source_key == block_key {
      return Some(paragraph)
    }
  }
  None
}

///|
fn html_fact_list_item_for_block(
  semantic : @dphtml.HtmlSemanticDocument,
  block_key : String,
) -> @dphtml.HtmlListItemFact? {
  for item in semantic.list_items {
    if item.block_source_key == block_key {
      return Some(item)
    }
  }
  None
}

///|
fn html_fact_list_for_item(
  semantic : @dphtml.HtmlSemanticDocument,
  item : @dphtml.HtmlListItemFact,
) -> @dphtml.HtmlListFact? {
  match item.list_source_key {
    Some(key) => html_fact_list_by_key(semantic, key)
    None => None
  }
}

///|
fn html_fact_list_by_key(
  semantic : @dphtml.HtmlSemanticDocument,
  key : String,
) -> @dphtml.HtmlListFact? {
  for list in semantic.lists {
    if list.source_key == key {
      return Some(list)
    }
  }
  None
}

///|
fn html_fact_blockquote_for_block(
  semantic : @dphtml.HtmlSemanticDocument,
  block_key : String,
) -> @dphtml.HtmlBlockQuoteFact? {
  for quote in semantic.blockquotes {
    if quote.block_source_key == block_key {
      return Some(quote)
    }
  }
  None
}

///|
fn html_fact_code_for_block(
  semantic : @dphtml.HtmlSemanticDocument,
  block_key : String,
) -> @dphtml.HtmlCodeBlockFact? {
  for code in semantic.code_blocks {
    if code.block_source_key == block_key ||
      code.code_block_source_key == Some(block_key) {
      return Some(code)
    }
  }
  None
}

///|
fn html_fact_figure_for_block(
  semantic : @dphtml.HtmlSemanticDocument,
  block_key : String,
) -> @dphtml.HtmlFigureFact? {
  for figure in semantic.figures {
    if figure.block_source_key == block_key {
      return Some(figure)
    }
  }
  None
}

///|
fn html_fact_table_for_block(
  semantic : @dphtml.HtmlSemanticDocument,
  block_key : String,
) -> @dphtml.HtmlTableFact? {
  for table in semantic.tables {
    if table.block_source_key == block_key {
      return Some(table)
    }
  }
  None
}

///|
fn html_fact_note_ref_by_key(
  semantic : @dphtml.HtmlSemanticDocument,
  key : String,
) -> @dphtml.HtmlNoteRefFact? {
  for note_ref in semantic.note_refs {
    if note_ref.source_key == key {
      return Some(note_ref)
    }
  }
  None
}

///|
fn html_fact_note_body_by_key(
  semantic : @dphtml.HtmlSemanticDocument,
  key : String,
) -> @dphtml.HtmlNoteBodyFact? {
  for body in semantic.note_bodies {
    if body.source_key == key {
      return Some(body)
    }
  }
  None
}
