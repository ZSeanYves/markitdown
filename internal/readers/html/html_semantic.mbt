///|
/// Collect parser-owned semantic block facts from the tolerant DOM model.
///
/// This pass does not scan raw HTML bytes and does not perform Markdown or IR
/// policy. It exists as a stable typed-facts layer for future convert slices.
pub fn collect_html_semantic_document(
  doc : HtmlDocument,
) -> HtmlSemanticDocument {
  let ctx = HtmlSemanticCollectCtx::{
    blocks: [],
    block_by_source_key: Map([]),
    first_block_source_key_by_tag_name: Map([]),
    child_block_source_keys_by_parent_source_key: Map([]),
    descendant_block_source_keys_by_ancestor_source_key: Map([]),
    descendant_table_row_block_source_keys_by_table_source_key: Map([]),
    direct_table_cell_block_source_keys_by_row_source_key: Map([]),
    parent_source_key_by_block_source_key: Map([]),
    list_depth_by_block_source_key: Map([]),
    quote_depth_by_block_source_key: Map([]),
    nearest_list_source_key_by_block_source_key: Map([]),
    nearest_list_item_source_key_by_block_source_key: Map([]),
    nearest_quote_source_key_by_block_source_key: Map([]),
    nearest_table_ancestor_source_key_by_block_source_key: Map([]),
    paragraphs: [],
    inlines: [],
    inline_by_source_key: Map([]),
    top_level_inline_keys_by_block_source_key: Map([]),
    links: [],
    link_source_key_by_inline_source_key: Map([]),
    link_source_keys_by_block_source_key: Map([]),
    images: [],
    image_index_by_source_key: Map([]),
    image_source_key_by_inline_source_key: Map([]),
    image_source_keys_by_block_source_key: Map([]),
    image_source_keys_by_parent_inline_source_key: Map([]),
    tables: [],
    table_sections: [],
    table_rows: [],
    table_row_by_source_key: Map([]),
    table_cells: [],
    table_cell_by_source_key: Map([]),
    lists: [],
    list_source_key_by_block_source_key: Map([]),
    list_items: [],
    list_item_source_key_by_block_source_key: Map([]),
    blockquotes: [],
    code_blocks: [],
    figures: [],
    note_refs: [],
    note_bodies: [],
    note_body_by_id: Map([]),
    notes: [],
    scope: [],
    noise_candidates: [],
    unsupported: [],
    warnings: [],
    next_order: 0,
    next_inline_order: 0,
    next_link_order: 0,
    next_image_order: 0,
    next_table_order: 0,
    next_table_section_order: 0,
    next_table_row_order: 0,
    next_table_cell_order: 0,
    next_code_block_order: 0,
    next_figure_order: 0,
    next_note_ref_order: 0,
    next_note_body_order: 0,
    next_note_order: 0,
    next_noise_order: 0,
    next_unsupported_order: 0,
    max_depth: 0,
  }

  for node in doc.nodes {
    ignore(collect_html_semantic_node(node, ctx, 1, None))
  }
  collect_html_semantic_note_relations(ctx)
  collect_html_semantic_scope_fact(doc, ctx)

  {
    blocks: ctx.blocks,
    paragraphs: ctx.paragraphs,
    inlines: ctx.inlines,
    links: ctx.links,
    images: ctx.images,
    tables: ctx.tables,
    table_sections: ctx.table_sections,
    table_rows: ctx.table_rows,
    table_cells: ctx.table_cells,
    lists: ctx.lists,
    list_items: ctx.list_items,
    blockquotes: ctx.blockquotes,
    code_blocks: ctx.code_blocks,
    figures: ctx.figures,
    note_refs: ctx.note_refs,
    note_bodies: ctx.note_bodies,
    notes: ctx.notes,
    scope: ctx.scope,
    noise_candidates: ctx.noise_candidates,
    unsupported: ctx.unsupported,
    warnings: ctx.warnings,
    max_depth: ctx.max_depth,
  }
}

///|
/// Summarize semantic block facts for low-risk convert integration and tests.
pub fn inspect_html_semantic_document(
  semantic : HtmlSemanticDocument,
) -> HtmlSemanticInspectReport {
  let mut heading_count = 0
  let mut paragraph_count = 0
  let mut list_count = 0
  let mut list_item_count = 0
  let mut table_count = 0
  let mut table_row_count = 0
  let mut table_cell_count = 0
  let mut blockquote_count = 0
  let mut pre_count = 0
  let mut code_block_count = 0
  let mut figure_count = 0
  let mut figcaption_count = 0
  let mut horizontal_rule_count = 0
  let mut unknown_block_count = 0
  let mut unsupported_block_count = 0
  let mut paragraph_with_link_count = 0
  let mut paragraph_with_image_count = 0
  let mut paragraph_with_code_count = 0
  let mut paragraph_with_emphasis_count = 0
  let mut paragraph_with_strong_count = 0
  let mut paragraph_with_break_count = 0
  let mut paragraph_meaningful_text_count = 0
  let mut paragraph_candidate_count = 0
  let mut paragraph_repeated_whitespace_count = 0
  let mut paragraph_newline_count = 0
  let mut text_inline_count = 0
  let mut emphasis_inline_count = 0
  let mut strong_inline_count = 0
  let mut code_inline_count = 0
  let mut link_inline_count = 0
  let mut image_inline_count = 0
  let mut break_inline_count = 0
  let mut span_inline_count = 0
  let mut inline_container_count = 0
  let mut unsupported_inline_count = 0
  let mut unknown_inline_count = 0
  let mut whitespace_only_text_inline_count = 0
  let mut leading_whitespace_inline_count = 0
  let mut trailing_whitespace_inline_count = 0
  let mut repeated_whitespace_inline_count = 0
  let mut newline_inline_count = 0
  let mut whitespace_preserving_inline_count = 0
  let mut inline_with_surrounding_text_count = 0
  let mut internal_link_count = 0
  let mut external_link_count = 0
  let mut mailto_link_count = 0
  let mut tel_link_count = 0
  let mut data_link_count = 0
  let mut unsafe_link_count = 0
  let mut empty_link_count = 0
  let mut local_image_count = 0
  let mut remote_image_count = 0
  let mut data_uri_image_count = 0
  let mut empty_image_count = 0
  let mut unsafe_image_count = 0
  let mut linked_image_count = 0
  let mut image_in_link_count = 0
  let mut note_ref_inline_count = 0
  let mut srcset_image_count = 0
  let mut picture_source_count = 0
  let mut broken_note_ref_count = 0
  let mut duplicate_note_body_count = 0
  let mut backref_note_count = 0
  let mut table_head_section_count = 0
  let mut table_body_section_count = 0
  let mut table_foot_section_count = 0
  let mut table_unknown_section_count = 0
  let mut table_caption_count = 0
  let mut table_fact_row_count = 0
  let mut table_fact_cell_count = 0
  let mut table_header_cell_count = 0
  let mut table_data_cell_count = 0
  let mut table_unknown_cell_count = 0
  let mut max_table_row_count = 0
  let mut max_table_cell_count = 0
  let mut table_span_cell_count = 0
  let mut table_ragged_row_count = 0
  let mut table_nested_cell_count = 0
  let mut table_complex_cell_count = 0
  let mut table_image_cell_count = 0
  let mut table_block_child_cell_count = 0
  let mut table_malformed_warning_count = 0
  let mut table_warning_count = 0
  let mut scope_body_count = 0
  let mut scope_main_count = 0
  let mut scope_article_count = 0
  let mut scope_document_root_count = 0
  let mut scope_fragment_count = 0
  let mut scope_heuristic_count = 0
  let mut scope_missing_body_count = 0
  let mut scope_multiple_body_count = 0
  let mut scope_malformed_root_count = 0
  let mut noise_nav_like_count = 0
  let mut noise_footer_like_count = 0
  let mut noise_sidebar_like_count = 0
  let mut noise_hiddenish_count = 0
  let mut noise_script_style_template_count = 0
  let mut noise_repeated_boilerplate_count = 0
  let mut ordered_list_fact_count = 0
  let mut unordered_list_fact_count = 0
  let mut max_list_depth = 0
  let mut max_quote_depth = 0
  let mut code_block_language_hint_count = 0
  let mut figure_caption_count = 0
  let mut figure_image_count = 0
  let mut warning_info_count = 0
  let mut warning_warning_count = 0
  let mut warning_error_count = 0
  let mut unsupported_info_count = 0
  let mut unsupported_warning_count = 0
  let mut unsupported_error_count = 0
  let mut unsupported_script_count = 0
  let mut unsupported_style_count = 0
  let mut unsupported_iframe_count = 0
  let mut unsupported_embed_count = 0
  let mut unsupported_object_count = 0
  let mut unsupported_svg_count = 0
  let mut unsupported_math_count = 0
  let mut unsupported_template_count = 0
  let mut unsupported_form_count = 0
  let mut unsupported_input_count = 0
  let mut unsupported_select_count = 0
  let mut unsupported_textarea_count = 0
  let mut unsupported_button_count = 0
  let mut unsupported_video_count = 0
  let mut unsupported_audio_count = 0
  let mut unsupported_source_count = 0
  let mut unsupported_canvas_count = 0
  let mut unsupported_remote_image_count = 0
  let mut unsupported_data_image_count = 0
  let mut unsupported_unsafe_url_count = 0
  let mut unsupported_empty_url_count = 0
  let mut unsupported_broken_local_image_count = 0
  let mut unsupported_charset_count = 0
  let mut unsupported_huge_text_node_count = 0
  let mut unsupported_huge_attribute_value_count = 0
  let mut unsupported_deep_nesting_count = 0
  let mut unsupported_huge_table_count = 0
  let mut unsupported_malformed_tag_count = 0
  let mut unsupported_unknown_count = 0

  for block in semantic.blocks {
    match block.kind {
      Heading(_) => heading_count += 1
      Paragraph => paragraph_count += 1
      List(_) => list_count += 1
      ListItem => list_item_count += 1
      Table => table_count += 1
      TableRow => table_row_count += 1
      TableCell(_) => table_cell_count += 1
      BlockQuote => blockquote_count += 1
      Pre => pre_count += 1
      CodeBlock => code_block_count += 1
      Figure => figure_count += 1
      FigCaption => figcaption_count += 1
      HorizontalRule => horizontal_rule_count += 1
      UnknownBlock => unknown_block_count += 1
      UnsupportedBlock => unsupported_block_count += 1
    }
  }
  for inline in semantic.inlines {
    match inline.kind {
      Text => text_inline_count += 1
      Emphasis => emphasis_inline_count += 1
      Strong => strong_inline_count += 1
      Code => code_inline_count += 1
      Link => link_inline_count += 1
      Image => image_inline_count += 1
      Break => break_inline_count += 1
      Span => span_inline_count += 1
      InlineContainer => inline_container_count += 1
      UnsupportedInline => unsupported_inline_count += 1
      UnknownInline => unknown_inline_count += 1
    }
    if inline.is_whitespace_only {
      whitespace_only_text_inline_count += 1
    }
    if inline.has_leading_whitespace {
      leading_whitespace_inline_count += 1
    }
    if inline.has_trailing_whitespace {
      trailing_whitespace_inline_count += 1
    }
    if inline.contains_repeated_whitespace {
      repeated_whitespace_inline_count += 1
    }
    if inline.contains_newline {
      newline_inline_count += 1
    }
    if inline.preserves_whitespace {
      whitespace_preserving_inline_count += 1
    }
    if inline.has_surrounding_text {
      inline_with_surrounding_text_count += 1
    }
  }
  for paragraph in semantic.paragraphs {
    if paragraph.has_links {
      paragraph_with_link_count += 1
    }
    if paragraph.has_images {
      paragraph_with_image_count += 1
    }
    if paragraph.has_code {
      paragraph_with_code_count += 1
    }
    if paragraph.has_emphasis {
      paragraph_with_emphasis_count += 1
    }
    if paragraph.has_strong {
      paragraph_with_strong_count += 1
    }
    if paragraph.has_breaks {
      paragraph_with_break_count += 1
    }
    if paragraph.has_meaningful_text {
      paragraph_meaningful_text_count += 1
    }
    if paragraph.is_candidate {
      paragraph_candidate_count += 1
    }
    if paragraph.has_repeated_whitespace {
      paragraph_repeated_whitespace_count += 1
    }
    if paragraph.has_newline {
      paragraph_newline_count += 1
    }
  }
  for link in semantic.links {
    match link.kind {
      Internal => internal_link_count += 1
      External => external_link_count += 1
      Mailto => mailto_link_count += 1
      Tel => tel_link_count += 1
      Data => data_link_count += 1
      Unsafe => unsafe_link_count += 1
      Empty => empty_link_count += 1
      Unknown => ()
    }
    if link.has_image {
      linked_image_count += 1
    }
    if link.is_note_ref {
      note_ref_inline_count += 1
    }
    if link.is_back_reference {
      backref_note_count += 1
    }
  }
  for image in semantic.images {
    match image.kind {
      Local => local_image_count += 1
      Remote => remote_image_count += 1
      DataUri => data_uri_image_count += 1
      Empty => empty_image_count += 1
      Unsafe => unsafe_image_count += 1
      Unknown => ()
    }
    if image.parent_link_source_key is Some(_) {
      image_in_link_count += 1
    }
    if image.srcset is Some(_) {
      srcset_image_count += 1
    }
    picture_source_count += image.picture_source_keys.length()
  }
  for note_ref in semantic.note_refs {
    if note_ref.is_broken {
      broken_note_ref_count += 1
    }
    if note_ref.is_back_reference {
      backref_note_count += 1
    }
  }
  for note_body in semantic.note_bodies {
    if note_body.duplicate_target {
      duplicate_note_body_count += 1
    }
  }
  for table in semantic.tables {
    table_fact_row_count += table.row_count
    table_fact_cell_count += table.cell_count
    if table.caption_source_key is Some(_) {
      table_caption_count += 1
    }
    if table.row_count > max_table_row_count {
      max_table_row_count = table.row_count
    }
    if table.cell_count > max_table_cell_count {
      max_table_cell_count = table.cell_count
    }
    table_span_cell_count += table.span_cell_count
    table_ragged_row_count += table.ragged_row_count
    table_nested_cell_count += table.nested_table_cell_count
    table_complex_cell_count += table.complex_cell_count
    table_image_cell_count += table.image_cell_count
    table_block_child_cell_count += table.block_child_cell_count
    table_malformed_warning_count += table.malformed_warning_count
    table_warning_count += table.warnings.length()
  }
  for section in semantic.table_sections {
    match section.kind {
      Head => table_head_section_count += 1
      Body => table_body_section_count += 1
      Foot => table_foot_section_count += 1
      Unknown => table_unknown_section_count += 1
    }
    table_warning_count += section.warnings.length()
  }
  for row in semantic.table_rows {
    table_warning_count += row.warnings.length()
  }
  for cell in semantic.table_cells {
    match cell.kind {
      Header => table_header_cell_count += 1
      Data => table_data_cell_count += 1
      Unknown => table_unknown_cell_count += 1
    }
    table_warning_count += cell.warnings.length()
  }
  for scope in semantic.scope {
    match scope.scope_source {
      Body => scope_body_count += 1
      Main => scope_main_count += 1
      Article => scope_article_count += 1
      DocumentRoot => scope_document_root_count += 1
      Fragment => scope_fragment_count += 1
      Heuristic => scope_heuristic_count += 1
    }
    if scope.missing_body_warning {
      scope_missing_body_count += 1
    }
    if scope.multiple_body_warning {
      scope_multiple_body_count += 1
    }
    if scope.malformed_root_warning {
      scope_malformed_root_count += 1
    }
  }
  for noise in semantic.noise_candidates {
    for reason in noise.reasons {
      match reason {
        NavLike => noise_nav_like_count += 1
        FooterLike => noise_footer_like_count += 1
        SidebarLike => noise_sidebar_like_count += 1
        Hiddenish => noise_hiddenish_count += 1
        ScriptStyleTemplate => noise_script_style_template_count += 1
        RepeatedBoilerplate => noise_repeated_boilerplate_count += 1
        Unknown => ()
      }
    }
  }
  for list in semantic.lists {
    match list.kind {
      Ordered => ordered_list_fact_count += 1
      Unordered => unordered_list_fact_count += 1
      Unknown => ()
    }
    if list.list_depth > max_list_depth {
      max_list_depth = list.list_depth
    }
  }
  for item in semantic.list_items {
    if item.list_depth > max_list_depth {
      max_list_depth = item.list_depth
    }
  }
  for quote in semantic.blockquotes {
    if quote.quote_depth > max_quote_depth {
      max_quote_depth = quote.quote_depth
    }
  }
  for code in semantic.code_blocks {
    if code.language_hint is Some(_) {
      code_block_language_hint_count += 1
    }
  }
  for figure in semantic.figures {
    if figure.caption_block_source_key is Some(_) {
      figure_caption_count += 1
    }
    figure_image_count += figure.image_source_keys.length()
  }
  for warning in semantic.warnings {
    match warning.severity {
      Info => warning_info_count += 1
      Warning => warning_warning_count += 1
      Error => warning_error_count += 1
    }
  }
  for unsupported in semantic.unsupported {
    match unsupported.severity {
      Info => unsupported_info_count += 1
      Warning => unsupported_warning_count += 1
      Error => unsupported_error_count += 1
    }
    match unsupported.kind {
      Script => unsupported_script_count += 1
      Style => unsupported_style_count += 1
      Iframe => unsupported_iframe_count += 1
      Embed => unsupported_embed_count += 1
      Object => unsupported_object_count += 1
      Svg => unsupported_svg_count += 1
      Math => unsupported_math_count += 1
      Template => unsupported_template_count += 1
      Form => unsupported_form_count += 1
      Input => unsupported_input_count += 1
      Select => unsupported_select_count += 1
      TextArea => unsupported_textarea_count += 1
      Button => unsupported_button_count += 1
      Video => unsupported_video_count += 1
      Audio => unsupported_audio_count += 1
      Source => unsupported_source_count += 1
      Canvas => unsupported_canvas_count += 1
      RemoteImage => unsupported_remote_image_count += 1
      DataImage => unsupported_data_image_count += 1
      UnsafeUrl => unsupported_unsafe_url_count += 1
      EmptyUrl => unsupported_empty_url_count += 1
      BrokenLocalImage => unsupported_broken_local_image_count += 1
      UnsupportedCharset => unsupported_charset_count += 1
      HugeTextNode => unsupported_huge_text_node_count += 1
      HugeAttributeValue => unsupported_huge_attribute_value_count += 1
      DeepNesting => unsupported_deep_nesting_count += 1
      HugeTable => unsupported_huge_table_count += 1
      MalformedTag => unsupported_malformed_tag_count += 1
      UnknownUnsupported => unsupported_unknown_count += 1
    }
  }

  {
    block_count: semantic.blocks.length(),
    heading_count,
    paragraph_count,
    list_count,
    list_item_count,
    table_count,
    table_row_count,
    table_cell_count,
    blockquote_count,
    pre_count,
    code_block_count,
    figure_count,
    figcaption_count,
    horizontal_rule_count,
    unknown_block_count,
    unsupported_block_count,
    paragraph_fact_count: semantic.paragraphs.length(),
    paragraph_with_link_count,
    paragraph_with_image_count,
    paragraph_with_code_count,
    paragraph_with_emphasis_count,
    paragraph_with_strong_count,
    paragraph_with_break_count,
    paragraph_meaningful_text_count,
    paragraph_candidate_count,
    paragraph_repeated_whitespace_count,
    paragraph_newline_count,
    inline_count: semantic.inlines.length(),
    text_inline_count,
    emphasis_inline_count,
    strong_inline_count,
    code_inline_count,
    link_inline_count,
    image_inline_count,
    break_inline_count,
    span_inline_count,
    inline_container_count,
    unsupported_inline_count,
    unknown_inline_count,
    whitespace_only_text_inline_count,
    leading_whitespace_inline_count,
    trailing_whitespace_inline_count,
    repeated_whitespace_inline_count,
    newline_inline_count,
    whitespace_preserving_inline_count,
    inline_with_surrounding_text_count,
    link_count: semantic.links.length(),
    internal_link_count,
    external_link_count,
    mailto_link_count,
    tel_link_count,
    data_link_count,
    unsafe_link_count,
    empty_link_count,
    image_count: semantic.images.length(),
    local_image_count,
    remote_image_count,
    data_uri_image_count,
    empty_image_count,
    unsafe_image_count,
    linked_image_count,
    image_in_link_count,
    note_ref_inline_count,
    srcset_image_count,
    picture_source_count,
    note_fact_count: semantic.notes.length(),
    note_ref_fact_count: semantic.note_refs.length(),
    note_body_fact_count: semantic.note_bodies.length(),
    broken_note_ref_count,
    duplicate_note_body_count,
    backref_note_count,
    table_fact_count: semantic.tables.length(),
    table_section_count: semantic.table_sections.length(),
    table_head_section_count,
    table_body_section_count,
    table_foot_section_count,
    table_unknown_section_count,
    table_caption_count,
    table_fact_row_count,
    table_fact_cell_count,
    table_header_cell_count,
    table_data_cell_count,
    table_unknown_cell_count,
    max_table_row_count,
    max_table_cell_count,
    table_span_cell_count,
    table_ragged_row_count,
    table_nested_cell_count,
    table_complex_cell_count,
    table_image_cell_count,
    table_block_child_cell_count,
    table_malformed_warning_count,
    table_warning_count,
    scope_fact_count: semantic.scope.length(),
    scope_body_count,
    scope_main_count,
    scope_article_count,
    scope_document_root_count,
    scope_fragment_count,
    scope_heuristic_count,
    scope_missing_body_count,
    scope_multiple_body_count,
    scope_malformed_root_count,
    noise_candidate_count: semantic.noise_candidates.length(),
    noise_nav_like_count,
    noise_footer_like_count,
    noise_sidebar_like_count,
    noise_hiddenish_count,
    noise_script_style_template_count,
    noise_repeated_boilerplate_count,
    list_fact_count: semantic.lists.length(),
    ordered_list_fact_count,
    unordered_list_fact_count,
    list_item_fact_count: semantic.list_items.length(),
    max_list_depth,
    blockquote_fact_count: semantic.blockquotes.length(),
    max_quote_depth,
    code_block_fact_count: semantic.code_blocks.length(),
    code_block_language_hint_count,
    figure_fact_count: semantic.figures.length(),
    figure_caption_count,
    figure_image_count,
    max_depth: semantic.max_depth,
    warning_count: semantic.warnings.length(),
    warning_info_count,
    warning_warning_count,
    warning_error_count,
    unsupported_fact_count: semantic.unsupported.length(),
    unsupported_info_count,
    unsupported_warning_count,
    unsupported_error_count,
    unsupported_script_count,
    unsupported_style_count,
    unsupported_iframe_count,
    unsupported_embed_count,
    unsupported_object_count,
    unsupported_svg_count,
    unsupported_math_count,
    unsupported_template_count,
    unsupported_form_count,
    unsupported_input_count,
    unsupported_select_count,
    unsupported_textarea_count,
    unsupported_button_count,
    unsupported_video_count,
    unsupported_audio_count,
    unsupported_source_count,
    unsupported_canvas_count,
    unsupported_remote_image_count,
    unsupported_data_image_count,
    unsupported_unsafe_url_count,
    unsupported_empty_url_count,
    unsupported_broken_local_image_count,
    unsupported_charset_count,
    unsupported_huge_text_node_count,
    unsupported_huge_attribute_value_count,
    unsupported_deep_nesting_count,
    unsupported_huge_table_count,
    unsupported_malformed_tag_count,
    unsupported_unknown_count,
  }
}

///|
