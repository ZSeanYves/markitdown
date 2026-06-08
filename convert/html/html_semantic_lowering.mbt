///|
priv struct HtmlSemanticLoweringState {
  semantic : @dphtml.HtmlSemanticDocument
  mut next_heading_source_order : Int
  mut next_paragraph_source_order : Int
  mut next_image_paragraph_source_order : Int
  mut next_list_item_source_order : Int
  mut next_table_source_order : Int
  mut next_figure_source_order : Int
  mut next_blockquote_source_order : Int
  mut next_code_source_order : Int
  heading_candidate_count : Int
  paragraph_candidate_count : Int
  link_paragraph_candidate_count : Int
  image_candidate_count : Int
  figure_candidate_count : Int
  list_candidate_count : Int
  table_candidate_count : Int
  blockquote_candidate_count : Int
  code_block_candidate_count : Int
  heading_lowered_count : Ref[Int]
  heading_existing_path_count : Ref[Int]
  heading_empty_guard_count : Ref[Int]
  heading_render_mismatch_guard_count : Ref[Int]
  heading_unsupported_guard_count : Ref[Int]
  paragraph_lowered_count : Ref[Int]
  paragraph_existing_path_count : Ref[Int]
  paragraph_empty_guard_count : Ref[Int]
  paragraph_render_mismatch_guard_count : Ref[Int]
  paragraph_unsupported_guard_count : Ref[Int]
  link_paragraph_lowered_count : Ref[Int]
  link_paragraph_existing_path_count : Ref[Int]
  image_lowered_count : Ref[Int]
  image_existing_path_count : Ref[Int]
  image_empty_guard_count : Ref[Int]
  image_render_mismatch_guard_count : Ref[Int]
  image_identity_guard_count : Ref[Int]
  image_unsupported_guard_count : Ref[Int]
  figure_lowered_count : Ref[Int]
  figure_existing_path_count : Ref[Int]
  figure_empty_guard_count : Ref[Int]
  figure_render_mismatch_guard_count : Ref[Int]
  figure_identity_guard_count : Ref[Int]
  figure_unsupported_guard_count : Ref[Int]
  image_guard_count : Ref[Int]
  figure_guard_count : Ref[Int]
  list_lowered_count : Ref[Int]
  list_existing_path_count : Ref[Int]
  list_item_lowered_count : Ref[Int]
  list_item_existing_path_count : Ref[Int]
  list_nested_guard_count : Ref[Int]
  list_empty_guard_count : Ref[Int]
  list_render_mismatch_guard_count : Ref[Int]
  list_unsupported_guard_count : Ref[Int]
  table_lowered_count : Ref[Int]
  table_existing_path_count : Ref[Int]
  table_guard_count : Ref[Int]
  table_span_guard_count : Ref[Int]
  table_caption_guard_count : Ref[Int]
  table_nested_guard_count : Ref[Int]
  table_complex_cell_guard_count : Ref[Int]
  table_ragged_guard_count : Ref[Int]
  table_mismatch_guard_count : Ref[Int]
  inline_lowered_count : Ref[Int]
  blockquote_lowered_count : Ref[Int]
  blockquote_existing_path_count : Ref[Int]
  blockquote_unsupported_guard_count : Ref[Int]
  code_block_lowered_count : Ref[Int]
  code_block_existing_path_count : Ref[Int]
  code_block_empty_guard_count : Ref[Int]
  code_block_incomplete_guard_count : Ref[Int]
  code_block_language_hint_count : Ref[Int]
}

///|
priv struct HtmlSemanticFigureLowering {
  image : HtmlInline
  caption : Array[HtmlInline]
}

///|
fn build_html_semantic_lowering_state_from_bytes(
  bs : Bytes,
) -> HtmlSemanticLoweringState? {
  if bs.length() > HTML_PARSER_VALIDATION_MAX_BYTES {
    return None
  }
  let text = @utf8.decode(bs, ignore_bom=false) catch { _ => return None }
  build_html_semantic_lowering_state_from_text(text)
}

///|
fn build_html_semantic_lowering_state_from_text(
  text : String,
) -> HtmlSemanticLoweringState? {
  let parsed = try? @dphtml.parse_html_document(text)
  match parsed {
    Ok(doc) => {
      let semantic = @dphtml.collect_html_semantic_document(doc)
      Some({
        semantic,
        next_heading_source_order: 0,
        next_paragraph_source_order: 0,
        next_image_paragraph_source_order: 0,
        next_list_item_source_order: 0,
        next_table_source_order: 0,
        next_figure_source_order: 0,
        next_blockquote_source_order: 0,
        next_code_source_order: 0,
        heading_candidate_count: count_html_semantic_m7b_headings(semantic),
        paragraph_candidate_count: count_html_semantic_m7a_paragraphs(semantic),
        link_paragraph_candidate_count: count_html_semantic_m7b_link_paragraphs(
          semantic,
        ),
        image_candidate_count: count_html_semantic_m7d_images(semantic),
        figure_candidate_count: count_html_semantic_m7d_figures(semantic),
        list_candidate_count: count_html_semantic_m7c_list_items(semantic),
        table_candidate_count: count_html_semantic_m7e_tables(semantic),
        blockquote_candidate_count: count_html_semantic_top_level_blockquotes(
          semantic,
        ),
        code_block_candidate_count: count_html_semantic_top_level_pre_blocks(
          semantic,
        ),
        heading_lowered_count: { val: 0 },
        heading_existing_path_count: { val: 0 },
        heading_empty_guard_count: { val: 0 },
        heading_render_mismatch_guard_count: { val: 0 },
        heading_unsupported_guard_count: { val: 0 },
        paragraph_lowered_count: { val: 0 },
        paragraph_existing_path_count: { val: 0 },
        paragraph_empty_guard_count: { val: 0 },
        paragraph_render_mismatch_guard_count: { val: 0 },
        paragraph_unsupported_guard_count: { val: 0 },
        link_paragraph_lowered_count: { val: 0 },
        link_paragraph_existing_path_count: { val: 0 },
        image_lowered_count: { val: 0 },
        image_existing_path_count: { val: 0 },
        image_empty_guard_count: { val: 0 },
        image_render_mismatch_guard_count: { val: 0 },
        image_identity_guard_count: { val: 0 },
        image_unsupported_guard_count: { val: 0 },
        figure_lowered_count: { val: 0 },
        figure_existing_path_count: { val: 0 },
        figure_empty_guard_count: { val: 0 },
        figure_render_mismatch_guard_count: { val: 0 },
        figure_identity_guard_count: { val: 0 },
        figure_unsupported_guard_count: { val: 0 },
        image_guard_count: { val: 0 },
        figure_guard_count: { val: 0 },
        list_lowered_count: { val: 0 },
        list_existing_path_count: { val: 0 },
        list_item_lowered_count: { val: 0 },
        list_item_existing_path_count: { val: 0 },
        list_nested_guard_count: { val: 0 },
        list_empty_guard_count: { val: 0 },
        list_render_mismatch_guard_count: { val: 0 },
        list_unsupported_guard_count: { val: 0 },
        table_lowered_count: { val: 0 },
        table_existing_path_count: { val: 0 },
        table_guard_count: { val: 0 },
        table_span_guard_count: { val: 0 },
        table_caption_guard_count: { val: 0 },
        table_nested_guard_count: { val: 0 },
        table_complex_cell_guard_count: { val: 0 },
        table_ragged_guard_count: { val: 0 },
        table_mismatch_guard_count: { val: 0 },
        inline_lowered_count: { val: 0 },
        blockquote_lowered_count: { val: 0 },
        blockquote_existing_path_count: { val: 0 },
        blockquote_unsupported_guard_count: { val: 0 },
        code_block_lowered_count: { val: 0 },
        code_block_existing_path_count: { val: 0 },
        code_block_empty_guard_count: { val: 0 },
        code_block_incomplete_guard_count: { val: 0 },
        code_block_language_hint_count: { val: 0 },
      })
    }
    Err(_) => None
  }
}

///|
fn lower_next_html_semantic_heading(
  state : HtmlSemanticLoweringState?,
  max_h : Int,
  current_rendered : String,
) -> @cor.Block? {
  match state {
    Some(item) =>
      match next_html_semantic_m7b_heading(item) {
        Some(block) =>
          match html_semantic_heading_to_inlines(item.semantic, block) {
            Some((level, inlines)) => {
              let rendered = render_html_semantic_ir_for_product_guard(inlines)
              if rendered.trim() == "" {
                item.heading_existing_path_count.val += 1
                item.heading_empty_guard_count.val += 1
                None
              } else if rendered.trim() != current_rendered.trim() {
                item.heading_existing_path_count.val += 1
                item.heading_render_mismatch_guard_count.val += 1
                None
              } else {
                item.heading_lowered_count.val += 1
                item.inline_lowered_count.val += inlines.length()
                Some(
                  @cor.Block::RichHeading(
                    clamp_html_semantic_heading(level, max_h),
                    inlines,
                  ),
                )
              }
            }
            None => {
              item.heading_existing_path_count.val += 1
              item.heading_unsupported_guard_count.val += 1
              None
            }
          }
        None => None
      }
    None => None
  }
}

///|
fn lower_next_html_semantic_paragraph(
  state : HtmlSemanticLoweringState?,
  current_rendered : String,
) -> @cor.Block? {
  match state {
    Some(item) =>
      match next_html_semantic_m7a_paragraph(item) {
        Some(paragraph) =>
          match html_semantic_paragraph_to_inlines(item.semantic, paragraph) {
            Some(inlines) => {
              let rendered = render_html_semantic_ir_for_product_guard(inlines)
              if rendered.trim() == "" {
                item.paragraph_existing_path_count.val += 1
                item.paragraph_empty_guard_count.val += 1
                if paragraph.has_links {
                  item.link_paragraph_existing_path_count.val += 1
                }
                None
              } else if rendered.trim() != current_rendered.trim() {
                item.paragraph_existing_path_count.val += 1
                item.paragraph_render_mismatch_guard_count.val += 1
                if paragraph.has_links {
                  item.link_paragraph_existing_path_count.val += 1
                }
                None
              } else {
                item.paragraph_lowered_count.val += 1
                if paragraph.has_links {
                  item.link_paragraph_lowered_count.val += 1
                }
                item.inline_lowered_count.val += inlines.length()
                Some(@cor.Block::RichParagraph(inlines))
              }
            }
            None => {
              item.paragraph_existing_path_count.val += 1
              item.paragraph_unsupported_guard_count.val += 1
              if paragraph.has_links {
                item.link_paragraph_existing_path_count.val += 1
              }
              None
            }
          }
        None => None
      }
    None => None
  }
}

///|
fn lower_next_html_semantic_image_paragraph(
  state : HtmlSemanticLoweringState?,
  current_rendered : String,
  current_image_identity : String,
) -> Array[HtmlInline]? {
  match state {
    Some(item) =>
      match next_html_semantic_m7d_image_paragraph(item) {
        Some(paragraph) =>
          match
            html_semantic_image_paragraph_to_html_inlines(
              item.semantic,
              paragraph,
            ) {
            Some(inlines) => {
              let rendered = render_inlines(inlines)
              if rendered.trim() == "" {
                item.image_existing_path_count.val += 1
                item.image_guard_count.val += 1
                item.image_empty_guard_count.val += 1
                None
              } else if rendered.trim() != current_rendered.trim() {
                item.image_existing_path_count.val += 1
                item.image_guard_count.val += 1
                item.image_render_mismatch_guard_count.val += 1
                None
              } else if render_html_semantic_image_inlines_identity(inlines) !=
                current_image_identity {
                item.image_existing_path_count.val += 1
                item.image_guard_count.val += 1
                item.image_identity_guard_count.val += 1
                None
              } else {
                item.image_lowered_count.val += html_semantic_image_count_for_paragraph(
                  item.semantic,
                  paragraph,
                )
                Some(inlines)
              }
            }
            None => {
              item.image_existing_path_count.val += 1
              item.image_guard_count.val += 1
              item.image_unsupported_guard_count.val += 1
              None
            }
          }
        None => None
      }
    None => None
  }
}

///|
fn lower_next_html_semantic_figure(
  state : HtmlSemanticLoweringState?,
  current_rendered : String,
  current_image_identity : String,
) -> HtmlSemanticFigureLowering? {
  match state {
    Some(item) =>
      match next_html_semantic_m7d_figure(item) {
        Some(figure) =>
          match html_semantic_figure_to_html_lowering(item.semantic, figure) {
            Some(lowering) => {
              let rendered = render_inlines(lowering.caption)
              if rendered.trim() != current_rendered.trim() {
                item.figure_existing_path_count.val += 1
                item.figure_guard_count.val += 1
                if rendered.trim() == "" {
                  item.figure_empty_guard_count.val += 1
                } else {
                  item.figure_render_mismatch_guard_count.val += 1
                }
                None
              } else if render_html_semantic_image_inline_identity(
                  lowering.image,
                ) !=
                current_image_identity {
                item.figure_existing_path_count.val += 1
                item.figure_guard_count.val += 1
                item.figure_identity_guard_count.val += 1
                None
              } else {
                item.figure_lowered_count.val += 1
                Some(lowering)
              }
            }
            None => {
              item.figure_existing_path_count.val += 1
              item.figure_guard_count.val += 1
              item.figure_unsupported_guard_count.val += 1
              None
            }
          }
        None => None
      }
    None => None
  }
}

///|
fn lower_next_html_semantic_list_item(
  state : HtmlSemanticLoweringState?,
  current_rendered : String,
) -> @cor.Block? {
  match state {
    Some(item) =>
      match next_html_semantic_m7c_list_item(item) {
        Some(list_item) =>
          match html_semantic_list_item_to_block(item.semantic, list_item) {
            Some(block) => {
              let rendered = html_semantic_block_guard_text(block)
              if rendered.trim() == "" {
                item.list_item_existing_path_count.val += 1
                item.list_existing_path_count.val += 1
                item.list_empty_guard_count.val += 1
                None
              } else if rendered.trim() != current_rendered.trim() {
                item.list_item_existing_path_count.val += 1
                item.list_existing_path_count.val += 1
                item.list_render_mismatch_guard_count.val += 1
                None
              } else {
                item.list_item_lowered_count.val += 1
                item.list_lowered_count.val += 1
                match block {
                  @cor.Block::RichListItem(_, _, inlines) =>
                    item.inline_lowered_count.val += inlines.length()
                  _ => ()
                }
                Some(block)
              }
            }
            None => {
              item.list_item_existing_path_count.val += 1
              item.list_existing_path_count.val += 1
              if list_item.child_list_source_keys.length() > 0 {
                item.list_nested_guard_count.val += 1
              }
              item.list_unsupported_guard_count.val += 1
              None
            }
          }
        None => None
      }
    None => None
  }
}

///|
fn lower_next_html_semantic_table(
  state : HtmlSemanticLoweringState?,
  current_rows : Array[Array[String]],
  current_header_rows : Int,
) -> @cor.Block? {
  match state {
    Some(item) =>
      match next_html_semantic_m7e_table(item) {
        Some(table) =>
          match html_semantic_table_to_rich_table(item.semantic, table) {
            Some(table_data) =>
              if !html_semantic_table_rows_equal(table_data.rows, current_rows) ||
                table_data.header_rows != current_header_rows {
                item.table_existing_path_count.val += 1
                item.table_guard_count.val += 1
                item.table_mismatch_guard_count.val += 1
                None
              } else {
                item.table_lowered_count.val += 1
                Some(@cor.Block::RichTable(table_data))
              }
            None => {
              item.table_existing_path_count.val += 1
              item.table_guard_count.val += 1
              html_semantic_mark_table_guard(item, table)
              None
            }
          }
        None => None
      }
    None => None
  }
}

///|
fn html_semantic_mark_table_guard(
  state : HtmlSemanticLoweringState,
  table : @dphtml.HtmlTableFact,
) -> Unit {
  if table.has_span {
    state.table_span_guard_count.val += 1
  }
  if table.has_caption {
    state.table_caption_guard_count.val += 1
  }
  if table.has_nested_table {
    state.table_nested_guard_count.val += 1
  }
  if table.has_complex_cell {
    state.table_complex_cell_guard_count.val += 1
  }
  if table.has_ragged_rows {
    state.table_ragged_guard_count.val += 1
  }
}

///|
fn html_semantic_block_guard_text(block : @cor.Block) -> String {
  match block {
    @cor.Block::RichListItem(_, _, inlines) =>
      render_html_semantic_ir_for_product_guard(inlines)
    @cor.Block::ListItem(_, _, text) => text
    _ => ""
  }
}

///|
fn render_html_semantic_ir_for_product_guard(
  inlines : Array[@cor.Inline],
) -> String {
  let mut out = ""
  for inline in inlines {
    match inline {
      @cor.Inline::Text(text) => out = out + text
      @cor.Inline::Break => out = out + "<br>"
      @cor.Inline::Link(text, href) => {
        let t = text.trim().to_owned()
        let h = href.trim().to_owned()
        if t == "" || h == "" {
          out = out + t
        } else {
          out = out + "[" + t + "](" + h + ")"
        }
      }
      @cor.Inline::NoteRef(note) => {
        let marker = note.marker.trim().to_owned()
        if note.body_status == @cor.NoteBodyStatus::Resolved &&
          note.note_id.trim() != "" {
          out = out + "[^" + note.note_id.trim().to_owned() + "]"
        } else if marker != "" {
          out = out +
            (if marker.has_prefix("^") { marker } else { "^" + marker })
        }
      }
    }
  }
  out
}

///|
fn render_html_semantic_image_inlines_identity(
  inlines : Array[HtmlInline],
) -> String {
  let mut out = ""
  for inline in inlines {
    match inline {
      HtmlInline::Image(_, _, _) =>
        out = out + render_html_semantic_image_inline_identity(inline) + "\n"
      _ => ()
    }
  }
  out
}

///|
fn render_html_semantic_image_inline_identity(inline : HtmlInline) -> String {
  match inline {
    HtmlInline::Image(alt, title, src) =>
      "src=" +
      src.trim().to_owned() +
      "\nalt=" +
      alt.trim().to_owned() +
      "\ntitle=" +
      title.unwrap_or("").trim().to_owned()
    _ => ""
  }
}

///|
fn lower_next_html_semantic_blockquote(
  state : HtmlSemanticLoweringState?,
  max_h : Int,
) -> @cor.Block? {
  match state {
    Some(item) =>
      match next_html_semantic_top_level_blockquote(item) {
        Some(quote) =>
          match
            html_semantic_blockquote_to_inlines(item.semantic, quote, max_h) {
            Some(inlines) => {
              item.blockquote_lowered_count.val += 1
              Some(@cor.Block::RichBlockQuote(inlines))
            }
            None => {
              item.blockquote_existing_path_count.val += 1
              item.blockquote_unsupported_guard_count.val += 1
              None
            }
          }
        None => None
      }
    None => None
  }
}

///|
fn lower_next_html_semantic_code_block(
  state : HtmlSemanticLoweringState?,
) -> @cor.Block? {
  match state {
    Some(item) =>
      match next_html_semantic_top_level_pre_block(item) {
        Some(code) =>
          if !code.code_text_complete {
            item.code_block_existing_path_count.val += 1
            item.code_block_incomplete_guard_count.val += 1
            None
          } else if code.code_text.trim() == "" {
            item.code_block_existing_path_count.val += 1
            item.code_block_empty_guard_count.val += 1
            None
          } else {
            item.code_block_lowered_count.val += 1
            if code.language_hint is Some(_) {
              item.code_block_language_hint_count.val += 1
            }
            Some(@cor.Block::CodeBlock(code.code_text))
          }
        None => None
      }
    None => None
  }
}

///|
fn render_html_semantic_lowering_profile_detail(
  state : HtmlSemanticLoweringState?,
) -> String {
  match state {
    Some(item) =>
      " semantic_lowering_available=true" +
      " semantic_heading_candidate_count=" +
      item.heading_candidate_count.to_string() +
      " semantic_heading_lowered_count=" +
      item.heading_lowered_count.val.to_string() +
      " semantic_heading_existing_path_count=" +
      item.heading_existing_path_count.val.to_string() +
      " semantic_heading_empty_guard_count=" +
      item.heading_empty_guard_count.val.to_string() +
      " semantic_heading_render_mismatch_guard_count=" +
      item.heading_render_mismatch_guard_count.val.to_string() +
      " semantic_heading_unsupported_guard_count=" +
      item.heading_unsupported_guard_count.val.to_string() +
      " semantic_paragraph_candidate_count=" +
      item.paragraph_candidate_count.to_string() +
      " semantic_paragraph_lowered_count=" +
      item.paragraph_lowered_count.val.to_string() +
      " semantic_paragraph_existing_path_count=" +
      item.paragraph_existing_path_count.val.to_string() +
      " semantic_paragraph_empty_guard_count=" +
      item.paragraph_empty_guard_count.val.to_string() +
      " semantic_paragraph_render_mismatch_guard_count=" +
      item.paragraph_render_mismatch_guard_count.val.to_string() +
      " semantic_paragraph_unsupported_guard_count=" +
      item.paragraph_unsupported_guard_count.val.to_string() +
      " semantic_link_paragraph_candidate_count=" +
      item.link_paragraph_candidate_count.to_string() +
      " semantic_link_paragraph_lowered_count=" +
      item.link_paragraph_lowered_count.val.to_string() +
      " semantic_link_paragraph_existing_path_count=" +
      item.link_paragraph_existing_path_count.val.to_string() +
      " semantic_image_candidate_count=" +
      item.image_candidate_count.to_string() +
      " semantic_image_lowered_count=" +
      item.image_lowered_count.val.to_string() +
      " semantic_image_existing_path_count=" +
      item.image_existing_path_count.val.to_string() +
      " semantic_image_empty_guard_count=" +
      item.image_empty_guard_count.val.to_string() +
      " semantic_image_render_mismatch_guard_count=" +
      item.image_render_mismatch_guard_count.val.to_string() +
      " semantic_image_identity_guard_count=" +
      item.image_identity_guard_count.val.to_string() +
      " semantic_image_unsupported_guard_count=" +
      item.image_unsupported_guard_count.val.to_string() +
      " semantic_figure_candidate_count=" +
      item.figure_candidate_count.to_string() +
      " semantic_figure_lowered_count=" +
      item.figure_lowered_count.val.to_string() +
      " semantic_figure_existing_path_count=" +
      item.figure_existing_path_count.val.to_string() +
      " semantic_figure_empty_guard_count=" +
      item.figure_empty_guard_count.val.to_string() +
      " semantic_figure_render_mismatch_guard_count=" +
      item.figure_render_mismatch_guard_count.val.to_string() +
      " semantic_figure_identity_guard_count=" +
      item.figure_identity_guard_count.val.to_string() +
      " semantic_figure_unsupported_guard_count=" +
      item.figure_unsupported_guard_count.val.to_string() +
      " semantic_image_guard_count=" +
      item.image_guard_count.val.to_string() +
      " semantic_figure_guard_count=" +
      item.figure_guard_count.val.to_string() +
      " semantic_list_candidate_count=" +
      item.list_candidate_count.to_string() +
      " semantic_list_lowered_count=" +
      item.list_lowered_count.val.to_string() +
      " semantic_list_existing_path_count=" +
      item.list_existing_path_count.val.to_string() +
      " semantic_list_item_lowered_count=" +
      item.list_item_lowered_count.val.to_string() +
      " semantic_list_item_existing_path_count=" +
      item.list_item_existing_path_count.val.to_string() +
      " semantic_list_nested_guard_count=" +
      item.list_nested_guard_count.val.to_string() +
      " semantic_list_empty_guard_count=" +
      item.list_empty_guard_count.val.to_string() +
      " semantic_list_render_mismatch_guard_count=" +
      item.list_render_mismatch_guard_count.val.to_string() +
      " semantic_list_unsupported_guard_count=" +
      item.list_unsupported_guard_count.val.to_string() +
      " semantic_table_candidate_count=" +
      item.table_candidate_count.to_string() +
      " semantic_table_lowered_count=" +
      item.table_lowered_count.val.to_string() +
      " semantic_table_existing_path_count=" +
      item.table_existing_path_count.val.to_string() +
      " semantic_table_guard_count=" +
      item.table_guard_count.val.to_string() +
      " semantic_table_span_guard_count=" +
      item.table_span_guard_count.val.to_string() +
      " semantic_table_caption_guard_count=" +
      item.table_caption_guard_count.val.to_string() +
      " semantic_table_nested_guard_count=" +
      item.table_nested_guard_count.val.to_string() +
      " semantic_table_complex_cell_guard_count=" +
      item.table_complex_cell_guard_count.val.to_string() +
      " semantic_table_ragged_guard_count=" +
      item.table_ragged_guard_count.val.to_string() +
      " semantic_table_mismatch_guard_count=" +
      item.table_mismatch_guard_count.val.to_string() +
      " semantic_inline_lowered_count=" +
      item.inline_lowered_count.val.to_string() +
      " semantic_blockquote_candidate_count=" +
      item.blockquote_candidate_count.to_string() +
      " semantic_blockquote_lowered_count=" +
      item.blockquote_lowered_count.val.to_string() +
      " semantic_blockquote_existing_path_count=" +
      item.blockquote_existing_path_count.val.to_string() +
      " semantic_blockquote_unsupported_guard_count=" +
      item.blockquote_unsupported_guard_count.val.to_string() +
      " semantic_code_block_candidate_count=" +
      item.code_block_candidate_count.to_string() +
      " semantic_code_block_lowered_count=" +
      item.code_block_lowered_count.val.to_string() +
      " semantic_code_block_existing_path_count=" +
      item.code_block_existing_path_count.val.to_string() +
      " semantic_code_block_empty_guard_count=" +
      item.code_block_empty_guard_count.val.to_string() +
      " semantic_code_block_incomplete_guard_count=" +
      item.code_block_incomplete_guard_count.val.to_string() +
      " semantic_code_block_language_hint_lowered_count=" +
      item.code_block_language_hint_count.val.to_string()
    None =>
      " semantic_lowering_available=false" +
      " semantic_heading_candidate_count=0" +
      " semantic_heading_lowered_count=0" +
      " semantic_heading_existing_path_count=0" +
      " semantic_heading_empty_guard_count=0" +
      " semantic_heading_render_mismatch_guard_count=0" +
      " semantic_heading_unsupported_guard_count=0" +
      " semantic_paragraph_candidate_count=0" +
      " semantic_paragraph_lowered_count=0" +
      " semantic_paragraph_existing_path_count=0" +
      " semantic_paragraph_empty_guard_count=0" +
      " semantic_paragraph_render_mismatch_guard_count=0" +
      " semantic_paragraph_unsupported_guard_count=0" +
      " semantic_link_paragraph_candidate_count=0" +
      " semantic_link_paragraph_lowered_count=0" +
      " semantic_link_paragraph_existing_path_count=0" +
      " semantic_image_candidate_count=0" +
      " semantic_image_lowered_count=0" +
      " semantic_image_existing_path_count=0" +
      " semantic_image_empty_guard_count=0" +
      " semantic_image_render_mismatch_guard_count=0" +
      " semantic_image_identity_guard_count=0" +
      " semantic_image_unsupported_guard_count=0" +
      " semantic_figure_candidate_count=0" +
      " semantic_figure_lowered_count=0" +
      " semantic_figure_existing_path_count=0" +
      " semantic_figure_empty_guard_count=0" +
      " semantic_figure_render_mismatch_guard_count=0" +
      " semantic_figure_identity_guard_count=0" +
      " semantic_figure_unsupported_guard_count=0" +
      " semantic_image_guard_count=0" +
      " semantic_figure_guard_count=0" +
      " semantic_list_candidate_count=0" +
      " semantic_list_lowered_count=0" +
      " semantic_list_existing_path_count=0" +
      " semantic_list_item_lowered_count=0" +
      " semantic_list_item_existing_path_count=0" +
      " semantic_list_nested_guard_count=0" +
      " semantic_list_empty_guard_count=0" +
      " semantic_list_render_mismatch_guard_count=0" +
      " semantic_list_unsupported_guard_count=0" +
      " semantic_table_candidate_count=0" +
      " semantic_table_lowered_count=0" +
      " semantic_table_existing_path_count=0" +
      " semantic_table_guard_count=0" +
      " semantic_table_span_guard_count=0" +
      " semantic_table_caption_guard_count=0" +
      " semantic_table_nested_guard_count=0" +
      " semantic_table_complex_cell_guard_count=0" +
      " semantic_table_ragged_guard_count=0" +
      " semantic_table_mismatch_guard_count=0" +
      " semantic_inline_lowered_count=0" +
      " semantic_blockquote_candidate_count=0" +
      " semantic_blockquote_lowered_count=0" +
      " semantic_blockquote_existing_path_count=0" +
      " semantic_blockquote_unsupported_guard_count=0" +
      " semantic_code_block_candidate_count=0" +
      " semantic_code_block_lowered_count=0" +
      " semantic_code_block_existing_path_count=0" +
      " semantic_code_block_empty_guard_count=0" +
      " semantic_code_block_incomplete_guard_count=0" +
      " semantic_code_block_language_hint_lowered_count=0"
  }
}

///|
fn next_html_semantic_m7d_image_paragraph(
  state : HtmlSemanticLoweringState,
) -> @dphtml.HtmlParagraphFact? {
  let mut found : @dphtml.HtmlParagraphFact? = None
  let mut found_order = 0
  for paragraph in state.semantic.paragraphs {
    if paragraph.source_order > state.next_image_paragraph_source_order &&
      paragraph.has_images &&
      !html_semantic_block_has_m7d_image_container_ancestor(
        state.semantic,
        paragraph.block_source_key,
      ) {
      if found is None || paragraph.source_order < found_order {
        found = Some(paragraph)
        found_order = paragraph.source_order
      }
    }
  }
  match found {
    Some(paragraph) => {
      state.next_image_paragraph_source_order = paragraph.source_order
      Some(paragraph)
    }
    None => None
  }
}

///|
fn next_html_semantic_m7d_figure(
  state : HtmlSemanticLoweringState,
) -> @dphtml.HtmlFigureFact? {
  let mut found : @dphtml.HtmlFigureFact? = None
  let mut found_order = 0
  for figure in state.semantic.figures {
    if figure.source_order > state.next_figure_source_order &&
      !html_semantic_block_has_m7d_image_container_ancestor(
        state.semantic,
        figure.block_source_key,
      ) {
      if found is None || figure.source_order < found_order {
        found = Some(figure)
        found_order = figure.source_order
      }
    }
  }
  match found {
    Some(figure) => {
      state.next_figure_source_order = figure.source_order
      Some(figure)
    }
    None => None
  }
}

///|
fn next_html_semantic_m7c_list_item(
  state : HtmlSemanticLoweringState,
) -> @dphtml.HtmlListItemFact? {
  let mut found : @dphtml.HtmlListItemFact? = None
  let mut found_order = 0
  for item in state.semantic.list_items {
    if item.source_order > state.next_list_item_source_order {
      if found is None || item.source_order < found_order {
        found = Some(item)
        found_order = item.source_order
      }
    }
  }
  match found {
    Some(item) => {
      state.next_list_item_source_order = item.source_order
      Some(item)
    }
    None => None
  }
}

///|
fn next_html_semantic_m7e_table(
  state : HtmlSemanticLoweringState,
) -> @dphtml.HtmlTableFact? {
  let mut found : @dphtml.HtmlTableFact? = None
  let mut found_order = 0
  for table in state.semantic.tables {
    if table.source_order > state.next_table_source_order &&
      !html_semantic_block_has_m6_container_ancestor(
        state.semantic,
        table.block_source_key,
      ) {
      if found is None || table.source_order < found_order {
        found = Some(table)
        found_order = table.source_order
      }
    }
  }
  match found {
    Some(table) => {
      state.next_table_source_order = table.source_order
      Some(table)
    }
    None => None
  }
}

///|
fn next_html_semantic_m7b_heading(
  state : HtmlSemanticLoweringState,
) -> @dphtml.HtmlBlockFact? {
  let mut found : @dphtml.HtmlBlockFact? = None
  let mut found_order = 0
  for block in state.semantic.blocks {
    if block.source_order > state.next_heading_source_order &&
      html_semantic_heading_is_m7b_candidate(state.semantic, block) {
      if found is None || block.source_order < found_order {
        found = Some(block)
        found_order = block.source_order
      }
    }
  }
  match found {
    Some(block) => {
      state.next_heading_source_order = block.source_order
      Some(block)
    }
    None => None
  }
}

///|
fn next_html_semantic_m7a_paragraph(
  state : HtmlSemanticLoweringState,
) -> @dphtml.HtmlParagraphFact? {
  let mut found : @dphtml.HtmlParagraphFact? = None
  let mut found_order = 0
  for paragraph in state.semantic.paragraphs {
    if paragraph.source_order > state.next_paragraph_source_order &&
      !paragraph.is_candidate &&
      !html_semantic_block_has_m6_container_ancestor(
        state.semantic,
        paragraph.block_source_key,
      ) {
      if found is None || paragraph.source_order < found_order {
        found = Some(paragraph)
        found_order = paragraph.source_order
      }
    }
  }
  match found {
    Some(paragraph) => {
      state.next_paragraph_source_order = paragraph.source_order
      Some(paragraph)
    }
    None => None
  }
}

///|
fn next_html_semantic_top_level_blockquote(
  state : HtmlSemanticLoweringState,
) -> @dphtml.HtmlBlockQuoteFact? {
  let mut found : @dphtml.HtmlBlockQuoteFact? = None
  let mut found_order = 0
  for quote in state.semantic.blockquotes {
    if quote.source_order > state.next_blockquote_source_order &&
      html_semantic_blockquote_is_m6_candidate(state.semantic, quote) {
      if found is None || quote.source_order < found_order {
        found = Some(quote)
        found_order = quote.source_order
      }
    }
  }
  match found {
    Some(quote) => {
      state.next_blockquote_source_order = quote.source_order
      Some(quote)
    }
    None => None
  }
}

///|
fn next_html_semantic_top_level_pre_block(
  state : HtmlSemanticLoweringState,
) -> @dphtml.HtmlCodeBlockFact? {
  let mut found : @dphtml.HtmlCodeBlockFact? = None
  let mut found_order = 0
  for code in state.semantic.code_blocks {
    if code.source_order > state.next_code_source_order &&
      html_semantic_code_block_is_m6_candidate(state.semantic, code) {
      if found is None || code.source_order < found_order {
        found = Some(code)
        found_order = code.source_order
      }
    }
  }
  match found {
    Some(code) => {
      state.next_code_source_order = code.source_order
      Some(code)
    }
    None => None
  }
}

///|
fn count_html_semantic_m7b_headings(
  semantic : @dphtml.HtmlSemanticDocument,
) -> Int {
  let mut count = 0
  for block in semantic.blocks {
    if html_semantic_heading_is_m7b_ready(semantic, block) {
      count += 1
    }
  }
  count
}

///|
fn count_html_semantic_m7a_paragraphs(
  semantic : @dphtml.HtmlSemanticDocument,
) -> Int {
  let mut count = 0
  for paragraph in semantic.paragraphs {
    if !paragraph.is_candidate &&
      !html_semantic_block_has_m6_container_ancestor(
        semantic,
        paragraph.block_source_key,
      ) &&
      html_semantic_paragraph_is_m7a_ready(semantic, paragraph) {
      count += 1
    }
  }
  count
}

///|
fn count_html_semantic_m7b_link_paragraphs(
  semantic : @dphtml.HtmlSemanticDocument,
) -> Int {
  let mut count = 0
  for paragraph in semantic.paragraphs {
    if !paragraph.is_candidate &&
      paragraph.has_links &&
      !paragraph.has_images &&
      !html_semantic_block_has_m6_container_ancestor(
        semantic,
        paragraph.block_source_key,
      ) &&
      html_semantic_paragraph_is_m7b_ready(semantic, paragraph) {
      count += 1
    }
  }
  count
}

///|
fn count_html_semantic_m7d_images(
  semantic : @dphtml.HtmlSemanticDocument,
) -> Int {
  let mut count = 0
  for paragraph in semantic.paragraphs {
    if paragraph.has_images &&
      !html_semantic_block_has_m7d_image_container_ancestor(
        semantic,
        paragraph.block_source_key,
      ) &&
      html_semantic_image_paragraph_is_m7d_ready(semantic, paragraph) {
      count += html_semantic_image_count_for_paragraph(semantic, paragraph)
    }
  }
  count
}

///|
fn count_html_semantic_m7d_figures(
  semantic : @dphtml.HtmlSemanticDocument,
) -> Int {
  let mut count = 0
  for figure in semantic.figures {
    if !html_semantic_block_has_m7d_image_container_ancestor(
        semantic,
        figure.block_source_key,
      ) &&
      html_semantic_figure_is_m7d_ready(semantic, figure) {
      count += 1
    }
  }
  count
}

///|
fn count_html_semantic_m7c_list_items(
  semantic : @dphtml.HtmlSemanticDocument,
) -> Int {
  let mut count = 0
  for item in semantic.list_items {
    if html_semantic_list_item_is_m7c_ready(semantic, item) {
      count += 1
    }
  }
  count
}

///|
fn count_html_semantic_m7e_tables(
  semantic : @dphtml.HtmlSemanticDocument,
) -> Int {
  let mut count = 0
  for table in semantic.tables {
    if !html_semantic_block_has_m6_container_ancestor(
        semantic,
        table.block_source_key,
      ) &&
      html_semantic_table_is_m7e_ready(semantic, table) {
      count += 1
    }
  }
  count
}

///|
fn count_html_semantic_top_level_blockquotes(
  semantic : @dphtml.HtmlSemanticDocument,
) -> Int {
  let mut count = 0
  for quote in semantic.blockquotes {
    if html_semantic_blockquote_is_m6_candidate(semantic, quote) {
      count += 1
    }
  }
  count
}

///|
fn count_html_semantic_top_level_pre_blocks(
  semantic : @dphtml.HtmlSemanticDocument,
) -> Int {
  let mut count = 0
  for code in semantic.code_blocks {
    if html_semantic_code_block_is_m6_candidate(semantic, code) {
      count += 1
    }
  }
  count
}

///|
fn html_semantic_list_item_to_block(
  semantic : @dphtml.HtmlSemanticDocument,
  item : @dphtml.HtmlListItemFact,
) -> @cor.Block? {
  if !html_semantic_list_item_is_m7c_ready(semantic, item) {
    return None
  }
  match html_semantic_list_for_item(semantic, item) {
    Some(list) =>
      match html_semantic_list_item_primary_paragraph(semantic, item) {
        Some(paragraph) =>
          match html_semantic_paragraph_fact_to_inlines(semantic, paragraph) {
            Some(inlines) =>
              if render_html_semantic_ir_for_product_guard(inlines).trim() == "" {
                None
              } else {
                Some(
                  @cor.Block::RichListItem(
                    list.kind == @dphtml.HtmlListKind::Ordered,
                    item.list_depth - 1,
                    inlines,
                  ),
                )
              }
            None => None
          }
        None => None
      }
    None => None
  }
}

///|
fn html_semantic_image_paragraph_to_html_inlines(
  semantic : @dphtml.HtmlSemanticDocument,
  paragraph : @dphtml.HtmlParagraphFact,
) -> Array[HtmlInline]? {
  if !html_semantic_image_paragraph_is_m7d_ready(semantic, paragraph) {
    return None
  }
  let out : Array[HtmlInline] = []
  for key in paragraph.inline_child_keys {
    match html_semantic_inline_to_html_inline(semantic, key, false) {
      Some(inline) => out.push(inline)
      None => return None
    }
  }
  Some(out)
}

///|
fn html_semantic_image_paragraph_is_m7d_ready(
  semantic : @dphtml.HtmlSemanticDocument,
  paragraph : @dphtml.HtmlParagraphFact,
) -> Bool {
  paragraph.tag_name == "p" &&
  paragraph.has_images &&
  paragraph.warnings.length() == 0 &&
  html_semantic_block_children_are_m7a_leaf(
    semantic,
    paragraph.block_source_key,
  ) &&
  html_semantic_image_count_for_paragraph(semantic, paragraph) > 0 &&
  html_semantic_image_paragraph_inlines_are_m7d_ready(semantic, paragraph)
}

///|
fn html_semantic_image_paragraph_inlines_are_m7d_ready(
  semantic : @dphtml.HtmlSemanticDocument,
  paragraph : @dphtml.HtmlParagraphFact,
) -> Bool {
  for key in paragraph.inline_child_keys {
    match html_semantic_inline_by_key(semantic, key) {
      Some(inline) =>
        if !html_semantic_inline_is_m7d_image_ready(semantic, inline) {
          return false
        }
      None => return false
    }
  }
  true
}

///|
fn html_semantic_inline_is_m7d_image_ready(
  semantic : @dphtml.HtmlSemanticDocument,
  inline : @dphtml.HtmlInlineFact,
) -> Bool {
  if inline.warnings.length() != 0 {
    return false
  }
  match inline.kind {
    @dphtml.HtmlInlineKind::Text | @dphtml.HtmlInlineKind::Break => true
    @dphtml.HtmlInlineKind::Image =>
      match html_semantic_image_for_inline(semantic, inline.source_key) {
        Some(image) => html_semantic_image_is_m7d_safe(image)
        None => false
      }
    @dphtml.HtmlInlineKind::Emphasis
    | @dphtml.HtmlInlineKind::Strong
    | @dphtml.HtmlInlineKind::Code
    | @dphtml.HtmlInlineKind::Span
    | @dphtml.HtmlInlineKind::InlineContainer =>
      if inline.children.length() == 0 {
        html_semantic_product_text(inline).trim() != ""
      } else {
        html_semantic_image_inline_children_are_m7d_ready(semantic, inline)
      }
    _ => false
  }
}

///|
fn html_semantic_image_inline_children_are_m7d_ready(
  semantic : @dphtml.HtmlSemanticDocument,
  inline : @dphtml.HtmlInlineFact,
) -> Bool {
  for key in inline.children {
    match html_semantic_inline_by_key(semantic, key) {
      Some(child) =>
        if !html_semantic_inline_is_m7d_image_ready(semantic, child) {
          return false
        }
      None => return false
    }
  }
  true
}

///|
fn html_semantic_image_count_for_paragraph(
  semantic : @dphtml.HtmlSemanticDocument,
  paragraph : @dphtml.HtmlParagraphFact,
) -> Int {
  let mut count = 0
  for image in semantic.images {
    if image.parent_block_source_key == Some(paragraph.block_source_key) {
      count += 1
    }
  }
  count
}

///|
fn html_semantic_figure_to_html_lowering(
  semantic : @dphtml.HtmlSemanticDocument,
  figure : @dphtml.HtmlFigureFact,
) -> HtmlSemanticFigureLowering? {
  if !html_semantic_figure_is_m7d_ready(semantic, figure) {
    return None
  }
  match html_semantic_image_by_key(semantic, figure.image_source_keys[0]) {
    Some(image) =>
      Some({
        image: HtmlInline::Image(
          image.alt.unwrap_or(""),
          image.title,
          image.src,
        ),
        caption: html_semantic_figure_caption_to_html_inlines(semantic, figure),
      })
    None => None
  }
}

///|
fn html_semantic_figure_is_m7d_ready(
  semantic : @dphtml.HtmlSemanticDocument,
  figure : @dphtml.HtmlFigureFact,
) -> Bool {
  if figure.warnings.length() != 0 ||
    figure.image_source_keys.length() !=
    HTML_SEMANTIC_LOWERING_FIGURE_IMAGE_COUNT ||
    figure.link_source_keys.length() != HTML_SEMANTIC_LOWERING_FIGURE_LINK_COUNT {
    return false
  }
  match html_semantic_image_by_key(semantic, figure.image_source_keys[0]) {
    Some(image) =>
      if !html_semantic_image_is_m7d_safe(image) ||
        image.parent_block_source_key != Some(figure.block_source_key) {
        return false
      }
    None => return false
  }
  for child_key in figure.child_block_source_keys {
    match html_semantic_block_kind_by_key(semantic, child_key) {
      Some(@dphtml.HtmlBlockKind::FigCaption) => ()
      _ => return false
    }
  }
  match figure.caption_block_source_key {
    Some(caption_key) =>
      html_semantic_figure_caption_is_m7d_ready(semantic, caption_key)
    None => true
  }
}

///|
fn html_semantic_figure_caption_is_m7d_ready(
  semantic : @dphtml.HtmlSemanticDocument,
  caption_block_source_key : String,
) -> Bool {
  html_semantic_block_children_are_m7a_leaf(semantic, caption_block_source_key) &&
  html_semantic_inlines_are_m7b_ready(
    semantic,
    html_semantic_top_level_inline_keys_for_block(
      semantic, caption_block_source_key,
    ),
  )
}

///|
fn html_semantic_figure_caption_to_html_inlines(
  semantic : @dphtml.HtmlSemanticDocument,
  figure : @dphtml.HtmlFigureFact,
) -> Array[HtmlInline] {
  match figure.caption_block_source_key {
    Some(caption_key) => {
      let out : Array[HtmlInline] = []
      for
        key in html_semantic_top_level_inline_keys_for_block(
          semantic, caption_key,
        ) {
        match html_semantic_inline_to_html_inline(semantic, key, true) {
          Some(inline) => out.push(inline)
          None => return []
        }
      }
      out
    }
    None => []
  }
}

///|
fn html_semantic_image_is_m7d_safe(image : @dphtml.HtmlImageFact) -> Bool {
  image.src.trim() != "" &&
  image.warnings.length() == 0 &&
  image.kind == @dphtml.HtmlImageKind::Local
}

///|
fn html_semantic_table_to_rich_table(
  semantic : @dphtml.HtmlSemanticDocument,
  table : @dphtml.HtmlTableFact,
) -> @cor.TableData? {
  if !html_semantic_table_is_m7e_ready(semantic, table) {
    return None
  }
  let rows : Array[Array[String]] = []
  for row_key in table.rows {
    match html_semantic_table_row_by_key(semantic, row_key) {
      Some(row) => {
        let out_row : Array[String] = []
        for cell_key in row.cell_source_keys {
          match html_semantic_table_cell_by_key(semantic, cell_key) {
            Some(cell) =>
              match html_semantic_table_cell_to_text(semantic, cell) {
                Some(text) => out_row.push(text)
                None => return None
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
    header_rows: html_semantic_table_header_rows(semantic, table),
    hints: Some({
      format: Some("html"),
      sheet_state: None,
      merged_ranges: None,
      formula_cells: None,
      semantic_types: None,
      span_cells: None,
    }),
  })
}

///|
fn html_semantic_table_is_m7e_ready(
  semantic : @dphtml.HtmlSemanticDocument,
  table : @dphtml.HtmlTableFact,
) -> Bool {
  table.safe_simple_table_candidate &&
  table.warnings.length() == 0 &&
  table.row_count > 0 &&
  table.cell_count > 0 &&
  table.max_column_count > 0 &&
  html_semantic_table_header_rows(semantic, table) ==
  HTML_SEMANTIC_LOWERING_TABLE_HEADER_ROWS &&
  !table.has_span &&
  !table.has_caption &&
  !table.has_nested_table &&
  !table.has_complex_cell &&
  !table.has_ragged_rows &&
  html_semantic_table_rows_are_m7e_ready(semantic, table)
}

///|
fn html_semantic_table_rows_are_m7e_ready(
  semantic : @dphtml.HtmlSemanticDocument,
  table : @dphtml.HtmlTableFact,
) -> Bool {
  for row_key in table.rows {
    match html_semantic_table_row_by_key(semantic, row_key) {
      Some(row) => {
        if row.warnings.length() != 0 ||
          row.cell_count != table.max_column_count {
          return false
        }
        for cell_key in row.cell_source_keys {
          match html_semantic_table_cell_by_key(semantic, cell_key) {
            Some(cell) =>
              if !html_semantic_table_cell_is_m7e_ready(semantic, cell) {
                return false
              }
            None => return false
          }
        }
      }
      None => return false
    }
  }
  true
}

///|
fn html_semantic_table_cell_is_m7e_ready(
  semantic : @dphtml.HtmlSemanticDocument,
  cell : @dphtml.HtmlTableCellFact,
) -> Bool {
  cell.safe_simple_cell_candidate &&
  cell.warnings.length() == 0 &&
  cell.text_complete &&
  cell.colspan_value == 1 &&
  cell.rowspan_value == 1 &&
  !cell.has_complex_block &&
  !cell.has_nested_table &&
  !cell.has_image &&
  !cell.has_list &&
  !cell.has_blockquote &&
  !cell.has_pre &&
  !cell.has_figure &&
  !cell.has_unsupported_warning &&
  html_semantic_inlines_are_m7b_ready(semantic, cell.inline_child_keys)
}

///|
fn html_semantic_table_cell_to_text(
  semantic : @dphtml.HtmlSemanticDocument,
  cell : @dphtml.HtmlTableCellFact,
) -> String? {
  if !html_semantic_table_cell_is_m7e_ready(semantic, cell) {
    return None
  }
  match html_semantic_table_cell_to_inlines(semantic, cell) {
    Some(inlines) => Some(render_html_semantic_ir_for_product_guard(inlines))
    None => None
  }
}

///|
fn html_semantic_table_cell_to_inlines(
  semantic : @dphtml.HtmlSemanticDocument,
  cell : @dphtml.HtmlTableCellFact,
) -> Array[@cor.Inline]? {
  let out : Array[@cor.Inline] = []
  for key in cell.inline_child_keys {
    match html_semantic_inline_by_key(semantic, key) {
      Some(inline) =>
        match html_semantic_inline_to_ir(semantic, inline, true) {
          Some(item) => out.push(item)
          None => return None
        }
      None => return None
    }
  }
  Some(out)
}

///|
fn html_semantic_table_header_rows(
  semantic : @dphtml.HtmlSemanticDocument,
  table : @dphtml.HtmlTableFact,
) -> Int {
  for section_key in table.sections {
    match html_semantic_table_section_by_key(semantic, section_key) {
      Some(section) =>
        if section.kind == @dphtml.HtmlTableSectionKind::Head {
          return 1
        }
      None => ()
    }
  }
  if table.rows.length() == 0 {
    return 0
  }
  match html_semantic_table_row_by_key(semantic, table.rows[0]) {
    Some(row) => {
      for cell_key in row.cell_source_keys {
        match html_semantic_table_cell_by_key(semantic, cell_key) {
          Some(cell) =>
            if cell.kind == @dphtml.HtmlTableCellKind::Header {
              return 1
            }
          None => ()
        }
      }
      0
    }
    None => 0
  }
}

///|
fn html_semantic_list_item_is_m7c_ready(
  semantic : @dphtml.HtmlSemanticDocument,
  item : @dphtml.HtmlListItemFact,
) -> Bool {
  if item.warnings.length() != 0 ||
    item.list_depth < HTML_SEMANTIC_LOWERING_LIST_MIN_DEPTH ||
    item.list_depth > HTML_SEMANTIC_LOWERING_LIST_MAX_DEPTH ||
    item.child_list_source_keys.length() != 0 {
    return false
  }
  match html_semantic_list_for_item(semantic, item) {
    Some(list) => {
      if list.warnings.length() != 0 ||
        !(list.kind == @dphtml.HtmlListKind::Ordered ||
        list.kind == @dphtml.HtmlListKind::Unordered) {
        return false
      }
      match html_semantic_list_item_primary_paragraph(semantic, item) {
        Some(paragraph) =>
          html_semantic_list_item_has_only_primary_paragraph(
            semantic, item, paragraph,
          ) &&
          html_semantic_list_item_paragraph_is_m7c_ready(
            semantic, item, paragraph,
          )
        None => false
      }
    }
    None => false
  }
}

///|
fn html_semantic_list_item_paragraph_is_m7c_ready(
  semantic : @dphtml.HtmlSemanticDocument,
  item : @dphtml.HtmlListItemFact,
  paragraph : @dphtml.HtmlParagraphFact,
) -> Bool {
  let is_direct_item_text = paragraph.block_source_key == item.block_source_key &&
    paragraph.tag_name == "li" &&
    paragraph.is_candidate
  let is_child_paragraph = paragraph.parent_block_source_key ==
    Some(item.block_source_key) &&
    paragraph.tag_name == "p" &&
    !paragraph.is_candidate
  if !(is_direct_item_text || is_child_paragraph) ||
    !paragraph.has_meaningful_text ||
    paragraph.has_images ||
    paragraph.warnings.length() != 0 ||
    !html_semantic_block_children_are_m7a_leaf(
      semantic,
      paragraph.block_source_key,
    ) {
    return false
  }
  if paragraph.has_links {
    html_semantic_inlines_are_m7b_ready(semantic, paragraph.inline_child_keys)
  } else {
    html_semantic_inlines_are_m7a_ready(semantic, paragraph.inline_child_keys)
  }
}

///|
fn html_semantic_list_item_has_only_primary_paragraph(
  semantic : @dphtml.HtmlSemanticDocument,
  item : @dphtml.HtmlListItemFact,
  paragraph : @dphtml.HtmlParagraphFact,
) -> Bool {
  if paragraph.block_source_key == item.block_source_key {
    return true
  }
  for block in semantic.blocks {
    if block.parent_source_key.unwrap_or("") == item.block_source_key &&
      block.source_key != paragraph.block_source_key {
      return false
    }
  }
  true
}

///|
fn html_semantic_list_item_primary_paragraph(
  semantic : @dphtml.HtmlSemanticDocument,
  item : @dphtml.HtmlListItemFact,
) -> @dphtml.HtmlParagraphFact? {
  for paragraph in semantic.paragraphs {
    if paragraph.block_source_key == item.block_source_key &&
      paragraph.tag_name == "li" &&
      paragraph.is_candidate {
      return Some(paragraph)
    }
  }
  for paragraph in semantic.paragraphs {
    if paragraph.parent_block_source_key == Some(item.block_source_key) &&
      paragraph.tag_name == "p" &&
      !paragraph.is_candidate {
      return Some(paragraph)
    }
  }
  None
}

///|
fn html_semantic_list_for_item(
  semantic : @dphtml.HtmlSemanticDocument,
  item : @dphtml.HtmlListItemFact,
) -> @dphtml.HtmlListFact? {
  match item.list_source_key {
    Some(key) =>
      for list in semantic.lists {
        if list.source_key == key {
          return Some(list)
        }
      }
    None => ()
  }
  None
}

///|
fn html_semantic_paragraph_to_inlines(
  semantic : @dphtml.HtmlSemanticDocument,
  paragraph : @dphtml.HtmlParagraphFact,
) -> Array[@cor.Inline]? {
  if !html_semantic_paragraph_is_m7b_ready(semantic, paragraph) {
    return None
  }
  html_semantic_paragraph_fact_to_inlines(semantic, paragraph)
}

///|
fn html_semantic_paragraph_fact_to_inlines(
  semantic : @dphtml.HtmlSemanticDocument,
  paragraph : @dphtml.HtmlParagraphFact,
) -> Array[@cor.Inline]? {
  let out : Array[@cor.Inline] = []
  for key in paragraph.inline_child_keys {
    match html_semantic_inline_by_key(semantic, key) {
      Some(inline) =>
        match
          html_semantic_inline_to_ir(semantic, inline, paragraph.has_links) {
          Some(item) => out.push(item)
          None => return None
        }
      None => return None
    }
  }
  Some(out)
}

///|
fn html_semantic_paragraph_is_m7a_ready(
  semantic : @dphtml.HtmlSemanticDocument,
  paragraph : @dphtml.HtmlParagraphFact,
) -> Bool {
  html_semantic_paragraph_base_is_m7_ready(semantic, paragraph) &&
  !paragraph.has_links &&
  html_semantic_inlines_are_m7a_ready(semantic, paragraph.inline_child_keys)
}

///|
fn html_semantic_paragraph_is_m7b_ready(
  semantic : @dphtml.HtmlSemanticDocument,
  paragraph : @dphtml.HtmlParagraphFact,
) -> Bool {
  if !html_semantic_paragraph_base_is_m7_ready(semantic, paragraph) {
    return false
  }
  if paragraph.has_links {
    html_semantic_inlines_are_m7b_ready(semantic, paragraph.inline_child_keys)
  } else {
    html_semantic_inlines_are_m7a_ready(semantic, paragraph.inline_child_keys)
  }
}

///|
fn html_semantic_paragraph_base_is_m7_ready(
  semantic : @dphtml.HtmlSemanticDocument,
  paragraph : @dphtml.HtmlParagraphFact,
) -> Bool {
  paragraph.tag_name == "p" &&
  paragraph.has_meaningful_text &&
  !paragraph.has_images &&
  paragraph.warnings.length() == 0 &&
  html_semantic_block_children_are_m7a_leaf(
    semantic,
    paragraph.block_source_key,
  )
}

///|
fn html_semantic_heading_to_inlines(
  semantic : @dphtml.HtmlSemanticDocument,
  block : @dphtml.HtmlBlockFact,
) -> (Int, Array[@cor.Inline])? {
  let level = match block.kind {
    @dphtml.HtmlBlockKind::Heading(level) => level
    _ => return None
  }
  if !html_semantic_heading_is_m7b_ready(semantic, block) {
    return None
  }
  let inlines = html_semantic_block_top_level_inlines_to_ir(
    semantic,
    block.source_key,
    true,
  )
  match inlines {
    Some(items) => Some((level, items))
    None => None
  }
}

///|
fn html_semantic_heading_is_m7b_candidate(
  semantic : @dphtml.HtmlSemanticDocument,
  block : @dphtml.HtmlBlockFact,
) -> Bool {
  match block.kind {
    @dphtml.HtmlBlockKind::Heading(level) =>
      level >= 1 &&
      level <= 6 &&
      !html_semantic_block_has_m6_container_ancestor(semantic, block.source_key)
    _ => false
  }
}

///|
fn html_semantic_heading_is_m7b_ready(
  semantic : @dphtml.HtmlSemanticDocument,
  block : @dphtml.HtmlBlockFact,
) -> Bool {
  html_semantic_heading_is_m7b_candidate(semantic, block) &&
  block.text_preview.trim() != "" &&
  block.warnings.length() == 0 &&
  html_semantic_block_children_are_m7a_leaf(semantic, block.source_key) &&
  html_semantic_inlines_are_m7b_ready(
    semantic,
    html_semantic_top_level_inline_keys_for_block(semantic, block.source_key),
  )
}

///|
fn html_semantic_block_children_are_m7a_leaf(
  semantic : @dphtml.HtmlSemanticDocument,
  block_source_key : String,
) -> Bool {
  for block in semantic.blocks {
    if block.parent_source_key.unwrap_or("") == block_source_key {
      return false
    }
  }
  true
}

///|
fn html_semantic_inlines_are_m7a_ready(
  semantic : @dphtml.HtmlSemanticDocument,
  inline_keys : Array[String],
) -> Bool {
  for key in inline_keys {
    match html_semantic_inline_by_key(semantic, key) {
      Some(inline) =>
        if !html_semantic_inline_is_m7a_ready(semantic, inline) {
          return false
        }
      None => return false
    }
  }
  true
}

///|
fn html_semantic_inlines_are_m7b_ready(
  semantic : @dphtml.HtmlSemanticDocument,
  inline_keys : Array[String],
) -> Bool {
  for key in inline_keys {
    match html_semantic_inline_by_key(semantic, key) {
      Some(inline) =>
        if !html_semantic_inline_is_m7b_ready(semantic, inline) {
          return false
        }
      None => return false
    }
  }
  true
}

///|
fn html_semantic_inline_is_m7a_ready(
  semantic : @dphtml.HtmlSemanticDocument,
  inline : @dphtml.HtmlInlineFact,
) -> Bool {
  if inline.warnings.length() != 0 {
    return false
  }
  match inline.kind {
    @dphtml.HtmlInlineKind::Text | @dphtml.HtmlInlineKind::Break => true
    @dphtml.HtmlInlineKind::Emphasis
    | @dphtml.HtmlInlineKind::Strong
    | @dphtml.HtmlInlineKind::Code
    | @dphtml.HtmlInlineKind::Span
    | @dphtml.HtmlInlineKind::InlineContainer =>
      html_semantic_inlines_are_m7a_ready(semantic, inline.children)
    _ => false
  }
}

///|
fn html_semantic_inline_is_m7b_ready(
  semantic : @dphtml.HtmlSemanticDocument,
  inline : @dphtml.HtmlInlineFact,
) -> Bool {
  if inline.warnings.length() != 0 {
    return false
  }
  match inline.kind {
    @dphtml.HtmlInlineKind::Text | @dphtml.HtmlInlineKind::Break => true
    @dphtml.HtmlInlineKind::Link =>
      html_semantic_link_is_m7b_safe(semantic, inline)
    @dphtml.HtmlInlineKind::Emphasis
    | @dphtml.HtmlInlineKind::Strong
    | @dphtml.HtmlInlineKind::Code
    | @dphtml.HtmlInlineKind::Span
    | @dphtml.HtmlInlineKind::InlineContainer =>
      html_semantic_inlines_are_m7b_ready(semantic, inline.children)
    _ => false
  }
}

///|
fn html_semantic_link_is_m7b_safe(
  semantic : @dphtml.HtmlSemanticDocument,
  inline : @dphtml.HtmlInlineFact,
) -> Bool {
  match html_semantic_link_for_inline(semantic, inline.source_key) {
    Some(link) => {
      if link.warnings.length() != 0 ||
        link.href.trim() == "" ||
        link.text_preview.trim() == "" {
        return false
      }
      match link.kind {
        @dphtml.HtmlLinkKind::Internal
        | @dphtml.HtmlLinkKind::External
        | @dphtml.HtmlLinkKind::Mailto
        | @dphtml.HtmlLinkKind::Tel =>
          html_semantic_inlines_are_m7a_ready(semantic, inline.children)
        _ => false
      }
    }
    None => false
  }
}

///|
fn html_semantic_blockquote_is_m6_candidate(
  semantic : @dphtml.HtmlSemanticDocument,
  quote : @dphtml.HtmlBlockQuoteFact,
) -> Bool {
  quote.quote_depth == 1 &&
  !html_semantic_block_has_m6_container_ancestor(
    semantic,
    quote.block_source_key,
  )
}

///|
fn html_semantic_code_block_is_m6_candidate(
  semantic : @dphtml.HtmlSemanticDocument,
  code : @dphtml.HtmlCodeBlockFact,
) -> Bool {
  code.tag_name == "pre" &&
  !html_semantic_block_has_m6_container_ancestor(
    semantic,
    code.block_source_key,
  )
}

///|
fn html_semantic_block_has_m6_container_ancestor(
  semantic : @dphtml.HtmlSemanticDocument,
  block_source_key : String,
) -> Bool {
  let mut current = html_semantic_block_parent_key(semantic, block_source_key)
  while current is Some(key) {
    match html_semantic_block_kind_by_key(semantic, key) {
      Some(kind) =>
        match kind {
          @dphtml.HtmlBlockKind::List(_)
          | @dphtml.HtmlBlockKind::ListItem
          | @dphtml.HtmlBlockKind::BlockQuote
          | @dphtml.HtmlBlockKind::Table
          | @dphtml.HtmlBlockKind::TableRow
          | @dphtml.HtmlBlockKind::TableCell(_)
          | @dphtml.HtmlBlockKind::Figure
          | @dphtml.HtmlBlockKind::FigCaption => return true
          _ => current = html_semantic_block_parent_key(semantic, key)
        }
      None => current = None
    }
  }
  false
}

///|
fn html_semantic_block_has_m7d_image_container_ancestor(
  semantic : @dphtml.HtmlSemanticDocument,
  block_source_key : String,
) -> Bool {
  let mut current = html_semantic_block_parent_key(semantic, block_source_key)
  while current is Some(key) {
    match html_semantic_block_kind_by_key(semantic, key) {
      Some(kind) =>
        match kind {
          @dphtml.HtmlBlockKind::List(_)
          | @dphtml.HtmlBlockKind::ListItem
          | @dphtml.HtmlBlockKind::BlockQuote
          | @dphtml.HtmlBlockKind::Table
          | @dphtml.HtmlBlockKind::TableRow
          | @dphtml.HtmlBlockKind::TableCell(_)
          | @dphtml.HtmlBlockKind::Figure
          | @dphtml.HtmlBlockKind::Pre
          | @dphtml.HtmlBlockKind::CodeBlock
          | @dphtml.HtmlBlockKind::FigCaption => return true
          _ => current = html_semantic_block_parent_key(semantic, key)
        }
      None => current = None
    }
  }
  false
}

///|
fn html_semantic_blockquote_to_inlines(
  semantic : @dphtml.HtmlSemanticDocument,
  quote : @dphtml.HtmlBlockQuoteFact,
  max_h : Int,
) -> Array[@cor.Inline]? {
  let _ = max_h
  let source_key = if quote.child_block_source_keys.length() == 0 {
    quote.block_source_key
  } else if quote.child_block_source_keys.length() == 1 &&
    html_semantic_block_kind_by_key(semantic, quote.child_block_source_keys[0]) ==
    Some(@dphtml.HtmlBlockKind::Paragraph) {
    quote.child_block_source_keys[0]
  } else {
    return None
  }
  let inlines = html_semantic_block_top_level_inlines_to_ir(
    semantic, source_key, false,
  )
  match inlines {
    Some(items) =>
      if render_ir_inlines(items).trim() == "" {
        None
      } else {
        Some(items)
      }
    None => None
  }
}

///|
fn html_semantic_block_top_level_inlines_to_ir(
  semantic : @dphtml.HtmlSemanticDocument,
  block_source_key : String,
  allow_links : Bool,
) -> Array[@cor.Inline]? {
  let out : Array[@cor.Inline] = []
  for inline in semantic.inlines {
    if inline.parent_block_source_key.unwrap_or("") == block_source_key &&
      inline.parent_inline_source_key is None {
      match html_semantic_inline_to_ir(semantic, inline, allow_links) {
        Some(item) => out.push(item)
        None => return None
      }
    }
  }
  Some(out)
}

///|
fn html_semantic_top_level_inline_keys_for_block(
  semantic : @dphtml.HtmlSemanticDocument,
  block_source_key : String,
) -> Array[String] {
  let out : Array[String] = []
  for inline in semantic.inlines {
    if inline.parent_block_source_key.unwrap_or("") == block_source_key &&
      inline.parent_inline_source_key is None {
      out.push(inline.source_key)
    }
  }
  out
}

///|
fn html_semantic_inline_to_ir(
  semantic : @dphtml.HtmlSemanticDocument,
  inline : @dphtml.HtmlInlineFact,
  allow_links : Bool,
) -> @cor.Inline? {
  match inline.kind {
    @dphtml.HtmlInlineKind::Text =>
      Some(@cor.Inline::Text(html_semantic_product_text(inline)))
    @dphtml.HtmlInlineKind::Break => Some(@cor.Inline::Break)
    @dphtml.HtmlInlineKind::Link =>
      if allow_links {
        match html_semantic_link_for_inline(semantic, inline.source_key) {
          Some(link) => {
            let text = link.text_preview.trim().to_owned()
            let href = link.href.trim().to_owned()
            if text != "" && href != "" {
              Some(@cor.Inline::Link(text, href))
            } else if text != "" {
              Some(@cor.Inline::Text(text))
            } else {
              None
            }
          }
          None => None
        }
      } else {
        None
      }
    @dphtml.HtmlInlineKind::Emphasis
    | @dphtml.HtmlInlineKind::Strong
    | @dphtml.HtmlInlineKind::Code
    | @dphtml.HtmlInlineKind::Span
    | @dphtml.HtmlInlineKind::InlineContainer =>
      if html_semantic_inline_children_are_plain_text(semantic, inline) &&
        html_semantic_product_text(inline).trim() != "" {
        Some(@cor.Inline::Text(html_semantic_product_text(inline)))
      } else {
        None
      }
    _ => None
  }
}

///|
fn html_semantic_inline_to_html_inline(
  semantic : @dphtml.HtmlSemanticDocument,
  inline_key : String,
  allow_links : Bool,
) -> HtmlInline? {
  match html_semantic_inline_by_key(semantic, inline_key) {
    Some(inline) =>
      match inline.kind {
        @dphtml.HtmlInlineKind::Text =>
          Some(HtmlInline::Text(html_semantic_product_text(inline)))
        @dphtml.HtmlInlineKind::Break => Some(HtmlInline::Break)
        @dphtml.HtmlInlineKind::Image =>
          match html_semantic_image_for_inline(semantic, inline.source_key) {
            Some(image) =>
              if html_semantic_image_is_m7d_safe(image) {
                Some(
                  HtmlInline::Image(
                    image.alt.unwrap_or(""),
                    image.title,
                    image.src,
                  ),
                )
              } else {
                None
              }
            None => None
          }
        @dphtml.HtmlInlineKind::Link =>
          if allow_links {
            match html_semantic_link_for_inline(semantic, inline.source_key) {
              Some(link) =>
                if html_semantic_link_is_m7b_safe(semantic, inline) {
                  Some(HtmlInline::Link(link.text_preview, link.href))
                } else {
                  None
                }
              None => None
            }
          } else {
            None
          }
        @dphtml.HtmlInlineKind::Emphasis
        | @dphtml.HtmlInlineKind::Strong
        | @dphtml.HtmlInlineKind::Code
        | @dphtml.HtmlInlineKind::Span
        | @dphtml.HtmlInlineKind::InlineContainer =>
          if html_semantic_inline_children_are_plain_text(semantic, inline) &&
            html_semantic_product_text(inline).trim() != "" {
            Some(HtmlInline::Text(html_semantic_product_text(inline)))
          } else {
            None
          }
        _ => None
      }
    None => None
  }
}

///|
fn clamp_html_semantic_heading(level : Int, max_h : Int) -> Int {
  if level < 1 {
    1
  } else if level > max_h {
    max_h
  } else {
    level
  }
}

///|
fn html_semantic_product_text(inline : @dphtml.HtmlInlineFact) -> String {
  @cor.normalize_document_text_cleanup(inline.raw_text_preview)
}

///|
fn html_semantic_inline_children_are_plain_text(
  semantic : @dphtml.HtmlSemanticDocument,
  inline : @dphtml.HtmlInlineFact,
) -> Bool {
  for child_key in inline.children {
    match html_semantic_inline_by_key(semantic, child_key) {
      Some(child) =>
        match child.kind {
          @dphtml.HtmlInlineKind::Text => ()
          _ => return false
        }
      None => return false
    }
  }
  true
}

///|
fn html_semantic_link_for_inline(
  semantic : @dphtml.HtmlSemanticDocument,
  inline_source_key : String,
) -> @dphtml.HtmlLinkFact? {
  for link in semantic.links {
    if link.inline_source_key == inline_source_key {
      return Some(link)
    }
  }
  None
}

///|
fn html_semantic_image_for_inline(
  semantic : @dphtml.HtmlSemanticDocument,
  inline_source_key : String,
) -> @dphtml.HtmlImageFact? {
  for image in semantic.images {
    if image.inline_source_key == inline_source_key {
      return Some(image)
    }
  }
  None
}

///|
fn html_semantic_image_by_key(
  semantic : @dphtml.HtmlSemanticDocument,
  source_key : String,
) -> @dphtml.HtmlImageFact? {
  for image in semantic.images {
    if image.source_key == source_key {
      return Some(image)
    }
  }
  None
}

///|
fn html_semantic_table_section_by_key(
  semantic : @dphtml.HtmlSemanticDocument,
  source_key : String,
) -> @dphtml.HtmlTableSectionFact? {
  for section in semantic.table_sections {
    if section.source_key == source_key {
      return Some(section)
    }
  }
  None
}

///|
fn html_semantic_table_row_by_key(
  semantic : @dphtml.HtmlSemanticDocument,
  source_key : String,
) -> @dphtml.HtmlTableRowFact? {
  for row in semantic.table_rows {
    if row.source_key == source_key {
      return Some(row)
    }
  }
  None
}

///|
fn html_semantic_table_cell_by_key(
  semantic : @dphtml.HtmlSemanticDocument,
  source_key : String,
) -> @dphtml.HtmlTableCellFact? {
  for cell in semantic.table_cells {
    if cell.source_key == source_key {
      return Some(cell)
    }
  }
  None
}

///|
fn html_semantic_table_rows_equal(
  left : Array[Array[String]],
  right : Array[Array[String]],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for i in 0..<left.length() {
    if left[i].length() != right[i].length() {
      return false
    }
    for j in 0..<left[i].length() {
      if left[i][j] != right[i][j] {
        return false
      }
    }
  }
  true
}

///|
fn html_semantic_inline_by_key(
  semantic : @dphtml.HtmlSemanticDocument,
  source_key : String,
) -> @dphtml.HtmlInlineFact? {
  for inline in semantic.inlines {
    if inline.source_key == source_key {
      return Some(inline)
    }
  }
  None
}

///|
fn html_semantic_block_parent_key(
  semantic : @dphtml.HtmlSemanticDocument,
  source_key : String,
) -> String? {
  for block in semantic.blocks {
    if block.source_key == source_key {
      return block.parent_source_key
    }
  }
  None
}

///|
fn html_semantic_block_kind_by_key(
  semantic : @dphtml.HtmlSemanticDocument,
  source_key : String,
) -> @dphtml.HtmlBlockKind? {
  for block in semantic.blocks {
    if block.source_key == source_key {
      return Some(block.kind)
    }
  }
  None
}
