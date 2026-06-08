///|
/// Collect parser-owned semantic block facts from the tolerant DOM model.
///
/// This pass does not scan raw HTML bytes and does not perform Markdown or IR
/// policy. It exists as a stable typed-facts bridge for future convert slices.
pub fn collect_html_semantic_document(
  doc : HtmlDocument,
) -> HtmlSemanticDocument {
  let ctx = HtmlSemanticCollectCtx::{
    blocks: [],
    paragraphs: [],
    inlines: [],
    links: [],
    images: [],
    tables: [],
    table_sections: [],
    table_rows: [],
    table_cells: [],
    lists: [],
    list_items: [],
    blockquotes: [],
    code_blocks: [],
    figures: [],
    note_refs: [],
    note_bodies: [],
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
      HtmlBlockKind::Heading(_) => heading_count += 1
      HtmlBlockKind::Paragraph => paragraph_count += 1
      HtmlBlockKind::List(_) => list_count += 1
      HtmlBlockKind::ListItem => list_item_count += 1
      HtmlBlockKind::Table => table_count += 1
      HtmlBlockKind::TableRow => table_row_count += 1
      HtmlBlockKind::TableCell(_) => table_cell_count += 1
      HtmlBlockKind::BlockQuote => blockquote_count += 1
      HtmlBlockKind::Pre => pre_count += 1
      HtmlBlockKind::CodeBlock => code_block_count += 1
      HtmlBlockKind::Figure => figure_count += 1
      HtmlBlockKind::FigCaption => figcaption_count += 1
      HtmlBlockKind::HorizontalRule => horizontal_rule_count += 1
      HtmlBlockKind::UnknownBlock => unknown_block_count += 1
      HtmlBlockKind::UnsupportedBlock => unsupported_block_count += 1
    }
  }
  for inline in semantic.inlines {
    match inline.kind {
      HtmlInlineKind::Text => text_inline_count += 1
      HtmlInlineKind::Emphasis => emphasis_inline_count += 1
      HtmlInlineKind::Strong => strong_inline_count += 1
      HtmlInlineKind::Code => code_inline_count += 1
      HtmlInlineKind::Link => link_inline_count += 1
      HtmlInlineKind::Image => image_inline_count += 1
      HtmlInlineKind::Break => break_inline_count += 1
      HtmlInlineKind::Span => span_inline_count += 1
      HtmlInlineKind::InlineContainer => inline_container_count += 1
      HtmlInlineKind::UnsupportedInline => unsupported_inline_count += 1
      HtmlInlineKind::UnknownInline => unknown_inline_count += 1
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
      HtmlLinkKind::Internal => internal_link_count += 1
      HtmlLinkKind::External => external_link_count += 1
      HtmlLinkKind::Mailto => mailto_link_count += 1
      HtmlLinkKind::Tel => tel_link_count += 1
      HtmlLinkKind::Data => data_link_count += 1
      HtmlLinkKind::Unsafe => unsafe_link_count += 1
      HtmlLinkKind::Empty => empty_link_count += 1
      HtmlLinkKind::Unknown => ()
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
      HtmlImageKind::Local => local_image_count += 1
      HtmlImageKind::Remote => remote_image_count += 1
      HtmlImageKind::DataUri => data_uri_image_count += 1
      HtmlImageKind::Empty => empty_image_count += 1
      HtmlImageKind::Unsafe => unsafe_image_count += 1
      HtmlImageKind::Unknown => ()
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
      HtmlTableSectionKind::Head => table_head_section_count += 1
      HtmlTableSectionKind::Body => table_body_section_count += 1
      HtmlTableSectionKind::Foot => table_foot_section_count += 1
      HtmlTableSectionKind::Unknown => table_unknown_section_count += 1
    }
    table_warning_count += section.warnings.length()
  }
  for row in semantic.table_rows {
    table_warning_count += row.warnings.length()
  }
  for cell in semantic.table_cells {
    match cell.kind {
      HtmlTableCellKind::Header => table_header_cell_count += 1
      HtmlTableCellKind::Data => table_data_cell_count += 1
      HtmlTableCellKind::Unknown => table_unknown_cell_count += 1
    }
    table_warning_count += cell.warnings.length()
  }
  for scope in semantic.scope {
    match scope.scope_source {
      HtmlDocumentScopeSource::Body => scope_body_count += 1
      HtmlDocumentScopeSource::Main => scope_main_count += 1
      HtmlDocumentScopeSource::Article => scope_article_count += 1
      HtmlDocumentScopeSource::DocumentRoot => scope_document_root_count += 1
      HtmlDocumentScopeSource::Fragment => scope_fragment_count += 1
      HtmlDocumentScopeSource::Heuristic => scope_heuristic_count += 1
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
        HtmlNoiseCandidateReason::NavLike => noise_nav_like_count += 1
        HtmlNoiseCandidateReason::FooterLike => noise_footer_like_count += 1
        HtmlNoiseCandidateReason::SidebarLike => noise_sidebar_like_count += 1
        HtmlNoiseCandidateReason::Hiddenish => noise_hiddenish_count += 1
        HtmlNoiseCandidateReason::ScriptStyleTemplate =>
          noise_script_style_template_count += 1
        HtmlNoiseCandidateReason::RepeatedBoilerplate =>
          noise_repeated_boilerplate_count += 1
        HtmlNoiseCandidateReason::Unknown => ()
      }
    }
  }
  for list in semantic.lists {
    match list.kind {
      HtmlListKind::Ordered => ordered_list_fact_count += 1
      HtmlListKind::Unordered => unordered_list_fact_count += 1
      HtmlListKind::Unknown => ()
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
      HtmlWarningSeverity::Info => warning_info_count += 1
      HtmlWarningSeverity::Warning => warning_warning_count += 1
      HtmlWarningSeverity::Error => warning_error_count += 1
    }
  }
  for unsupported in semantic.unsupported {
    match unsupported.severity {
      HtmlWarningSeverity::Info => unsupported_info_count += 1
      HtmlWarningSeverity::Warning => unsupported_warning_count += 1
      HtmlWarningSeverity::Error => unsupported_error_count += 1
    }
    match unsupported.kind {
      HtmlUnsupportedKind::Script => unsupported_script_count += 1
      HtmlUnsupportedKind::Style => unsupported_style_count += 1
      HtmlUnsupportedKind::Iframe => unsupported_iframe_count += 1
      HtmlUnsupportedKind::Embed => unsupported_embed_count += 1
      HtmlUnsupportedKind::Object => unsupported_object_count += 1
      HtmlUnsupportedKind::Svg => unsupported_svg_count += 1
      HtmlUnsupportedKind::Math => unsupported_math_count += 1
      HtmlUnsupportedKind::Template => unsupported_template_count += 1
      HtmlUnsupportedKind::Form => unsupported_form_count += 1
      HtmlUnsupportedKind::Input => unsupported_input_count += 1
      HtmlUnsupportedKind::Select => unsupported_select_count += 1
      HtmlUnsupportedKind::TextArea => unsupported_textarea_count += 1
      HtmlUnsupportedKind::Button => unsupported_button_count += 1
      HtmlUnsupportedKind::Video => unsupported_video_count += 1
      HtmlUnsupportedKind::Audio => unsupported_audio_count += 1
      HtmlUnsupportedKind::Source => unsupported_source_count += 1
      HtmlUnsupportedKind::Canvas => unsupported_canvas_count += 1
      HtmlUnsupportedKind::RemoteImage => unsupported_remote_image_count += 1
      HtmlUnsupportedKind::DataImage => unsupported_data_image_count += 1
      HtmlUnsupportedKind::UnsafeUrl => unsupported_unsafe_url_count += 1
      HtmlUnsupportedKind::EmptyUrl => unsupported_empty_url_count += 1
      HtmlUnsupportedKind::BrokenLocalImage =>
        unsupported_broken_local_image_count += 1
      HtmlUnsupportedKind::UnsupportedCharset => unsupported_charset_count += 1
      HtmlUnsupportedKind::HugeTextNode => unsupported_huge_text_node_count += 1
      HtmlUnsupportedKind::HugeAttributeValue =>
        unsupported_huge_attribute_value_count += 1
      HtmlUnsupportedKind::DeepNesting => unsupported_deep_nesting_count += 1
      HtmlUnsupportedKind::HugeTable => unsupported_huge_table_count += 1
      HtmlUnsupportedKind::MalformedTag => unsupported_malformed_tag_count += 1
      HtmlUnsupportedKind::UnknownUnsupported => unsupported_unknown_count += 1
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
priv struct HtmlSemanticCollectCtx {
  blocks : Array[HtmlBlockFact]
  paragraphs : Array[HtmlParagraphFact]
  inlines : Array[HtmlInlineFact]
  links : Array[HtmlLinkFact]
  images : Array[HtmlImageFact]
  tables : Array[HtmlTableFact]
  table_sections : Array[HtmlTableSectionFact]
  table_rows : Array[HtmlTableRowFact]
  table_cells : Array[HtmlTableCellFact]
  lists : Array[HtmlListFact]
  list_items : Array[HtmlListItemFact]
  blockquotes : Array[HtmlBlockQuoteFact]
  code_blocks : Array[HtmlCodeBlockFact]
  figures : Array[HtmlFigureFact]
  note_refs : Array[HtmlNoteRefFact]
  note_bodies : Array[HtmlNoteBodyFact]
  notes : Array[HtmlNoteFact]
  scope : Array[HtmlDocumentScopeFact]
  noise_candidates : Array[HtmlNoiseCandidateFact]
  unsupported : Array[HtmlUnsupportedFact]
  warnings : Array[HtmlSemanticWarning]
  mut next_order : Int
  mut next_inline_order : Int
  mut next_link_order : Int
  mut next_image_order : Int
  mut next_table_order : Int
  mut next_table_section_order : Int
  mut next_table_row_order : Int
  mut next_table_cell_order : Int
  mut next_code_block_order : Int
  mut next_figure_order : Int
  mut next_note_ref_order : Int
  mut next_note_body_order : Int
  mut next_note_order : Int
  mut next_noise_order : Int
  mut next_unsupported_order : Int
  mut max_depth : Int
}

///|
fn collect_html_semantic_node(
  node : HtmlNode,
  ctx : HtmlSemanticCollectCtx,
  depth : Int,
  parent_source_key : String?,
) -> String? {
  match node {
    HtmlNode::Element(element) =>
      collect_html_semantic_element(element, ctx, depth, parent_source_key)
    _ => None
  }
}

///|
fn collect_html_semantic_element(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  depth : Int,
  parent_source_key : String?,
) -> String? {
  let kind = if element.tag_name == "code" &&
    !html_semantic_parent_block_is_tag(ctx.blocks, parent_source_key, "pre") {
    None
  } else {
    html_semantic_block_kind(element.tag_name)
  }
  let mut effective_depth = depth
  let local_warnings : Array[HtmlSemanticWarning] = []

  if depth > HTML_SEMANTIC_MAX_DEPTH {
    effective_depth = HTML_SEMANTIC_MAX_DEPTH
  }
  if effective_depth > ctx.max_depth {
    ctx.max_depth = effective_depth
  }

  match kind {
    None => {
      for child in element.children {
        ignore(
          collect_html_semantic_node(
            child,
            ctx,
            effective_depth + 1,
            parent_source_key,
          ),
        )
      }
      None
    }
    Some(block_kind) => {
      ctx.next_order += 1
      let source_order = ctx.next_order
      let source_key = html_semantic_source_key(element.tag_name, source_order)

      if depth > HTML_SEMANTIC_MAX_DEPTH {
        let warning = new_html_semantic_warning(
          HtmlSemanticWarningKind::DepthLimitExceeded,
          source_key,
          element.tag_name,
          "html semantic depth limit exceeded at <" + element.tag_name + ">",
        )
        local_warnings.push(warning)
      }

      if is_html_semantic_unsupported_tag(element.tag_name) {
        let warning = new_html_semantic_warning(
          HtmlSemanticWarningKind::UnsupportedElement,
          source_key,
          element.tag_name,
          "unsupported html block element: <" + element.tag_name + ">",
        )
        local_warnings.push(warning)
      }

      let (attrs, attr_warnings) = html_semantic_attribute_summary(
        element, source_key,
      )
      for warning in attr_warnings {
        local_warnings.push(warning)
      }

      let (text_preview, text_truncated) = html_semantic_text_preview(
        element.children,
      )
      if text_truncated {
        let warning = new_html_semantic_warning(
          HtmlSemanticWarningKind::TextPreviewTruncated,
          source_key,
          element.tag_name,
          "html semantic text preview truncated for <" + element.tag_name + ">",
        )
        local_warnings.push(warning)
      }

      for warning in local_warnings {
        ctx.warnings.push(warning)
      }

      match html_semantic_unsupported_kind_for_tag(element.tag_name) {
        Some(unsupported_kind) =>
          ignore(
            push_html_semantic_unsupported_fact(
              ctx,
              unsupported_kind,
              HtmlWarningSeverity::Warning,
              Some(source_key),
              element.tag_name,
              source_order,
              effective_depth,
              parent_source_key,
              text_preview,
              attrs,
              None,
              element.span,
              "unsupported html element: <" + element.tag_name + ">",
            ),
          )
        None => ()
      }
      push_html_semantic_guard_unsupported_facts(
        ctx,
        local_warnings,
        source_key,
        element.tag_name,
        source_order,
        effective_depth,
        parent_source_key,
        text_preview,
        attrs,
        element.span,
      )
      collect_html_semantic_noise_candidate_fact(
        element,
        ctx,
        Some(source_key),
        parent_source_key,
        source_order,
        effective_depth,
        attrs,
        text_preview,
      )

      let children : Array[String] = []
      ctx.blocks.push({
        kind: block_kind,
        source_key,
        tag_name: element.tag_name,
        source_order,
        depth: effective_depth,
        parent_source_key,
        text_preview,
        attributes: attrs,
        span: element.span,
        children,
        warnings: local_warnings,
      })
      ignore(
        collect_html_semantic_inlines_from_children(
          element.children,
          ctx,
          effective_depth + 1,
          Some(source_key),
          None,
        ),
      )
      for child in element.children {
        match
          collect_html_semantic_node(
            child,
            ctx,
            effective_depth + 1,
            Some(source_key),
          ) {
          Some(child_key) => children.push(child_key)
          None => ()
        }
      }
      if block_kind == HtmlBlockKind::Table {
        collect_html_semantic_table_fact(
          element, ctx, source_key, source_order, effective_depth, parent_source_key,
          attrs, text_preview, local_warnings,
        )
      } else {
        collect_html_semantic_note_body_fact(
          element, ctx, source_key, source_order, effective_depth, parent_source_key,
          attrs, text_preview, local_warnings,
        )
        collect_html_semantic_polished_block_fact(
          element, ctx, block_kind, source_key, source_order, effective_depth, parent_source_key,
          children, attrs, text_preview, local_warnings,
        )
      }
      Some(source_key)
    }
  }
}

///|
fn collect_html_semantic_inlines_from_children(
  children : Array[HtmlNode],
  ctx : HtmlSemanticCollectCtx,
  depth : Int,
  parent_block_source_key : String?,
  parent_inline_source_key : String?,
) -> Array[String] {
  let out : Array[String] = []
  for i in 0..<children.length() {
    let child = children[i]
    match
      collect_html_semantic_inline_node(
        child,
        ctx,
        depth,
        parent_block_source_key,
        parent_inline_source_key,
        html_semantic_child_has_adjacent_text(children, i),
      ) {
      Some(source_key) => out.push(source_key)
      None => ()
    }
  }
  out
}

///|
fn collect_html_semantic_inline_node(
  node : HtmlNode,
  ctx : HtmlSemanticCollectCtx,
  depth : Int,
  parent_block_source_key : String?,
  parent_inline_source_key : String?,
  has_surrounding_text : Bool,
) -> String? {
  match node {
    HtmlNode::Text(text) =>
      collect_html_semantic_text_inline(
        text, ctx, depth, parent_block_source_key, parent_inline_source_key,
      )
    HtmlNode::Element(element) =>
      collect_html_semantic_inline_element(
        element, ctx, depth, parent_block_source_key, parent_inline_source_key, has_surrounding_text,
      )
    _ => None
  }
}

///|
fn collect_html_semantic_text_inline(
  text : HtmlText,
  ctx : HtmlSemanticCollectCtx,
  depth : Int,
  parent_block_source_key : String?,
  parent_inline_source_key : String?,
) -> String? {
  let is_whitespace_only = text.text.trim() == ""
  let normalized = if is_whitespace_only {
    " "
  } else {
    normalize_html_semantic_preview(text.text)
  }
  if normalized == "" {
    return None
  }
  let (raw_text_preview, raw_truncated) = bounded_html_semantic_preview(
    text.text,
    HTML_SEMANTIC_TEXT_PREVIEW_MAX_CHARS,
  )
  let (text_preview, normalized_truncated) = bounded_html_semantic_preview(
    normalized,
    HTML_SEMANTIC_TEXT_PREVIEW_MAX_CHARS,
  )
  let truncated = raw_truncated || normalized_truncated
  ctx.next_inline_order += 1
  let source_order = ctx.next_inline_order
  let source_key = html_semantic_inline_source_key("text", source_order)
  let warnings : Array[HtmlSemanticWarning] = []
  if truncated {
    warnings.push(
      new_html_semantic_warning(
        HtmlSemanticWarningKind::TextPreviewTruncated,
        source_key,
        "",
        "html semantic text inline preview truncated",
      ),
    )
  }
  push_html_semantic_warnings(ctx, warnings)
  push_html_semantic_guard_unsupported_facts(
    ctx,
    warnings,
    source_key,
    "",
    source_order,
    clamp_html_semantic_depth(depth),
    html_semantic_first_source_key(
      parent_inline_source_key, parent_block_source_key,
    ),
    text_preview,
    [],
    text.span,
  )
  ctx.inlines.push({
    kind: HtmlInlineKind::Text,
    source_key,
    tag_name: "",
    source_order,
    depth: clamp_html_semantic_depth(depth),
    parent_block_source_key,
    parent_inline_source_key,
    raw_text_preview,
    normalized_text_preview: text_preview,
    text_preview,
    has_leading_whitespace: html_semantic_has_leading_whitespace(text.text),
    has_trailing_whitespace: html_semantic_has_trailing_whitespace(text.text),
    contains_newline: html_semantic_contains_newline(text.text),
    contains_repeated_whitespace: html_semantic_contains_repeated_whitespace(
      text.text,
    ),
    is_whitespace_only,
    preserves_whitespace: false,
    has_surrounding_text: false,
    attributes: [],
    span: text.span,
    children: [],
    warnings,
  })
  Some(source_key)
}

///|
fn collect_html_semantic_inline_element(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  depth : Int,
  parent_block_source_key : String?,
  parent_inline_source_key : String?,
  has_surrounding_text : Bool,
) -> String? {
  match html_semantic_inline_kind(element.tag_name) {
    None => {
      if html_semantic_block_kind(element.tag_name) is Some(_) {
        return None
      }
      ignore(
        collect_html_semantic_inlines_from_children(
          element.children,
          ctx,
          depth + 1,
          parent_block_source_key,
          parent_inline_source_key,
        ),
      )
      None
    }
    Some(kind) => {
      ctx.next_inline_order += 1
      let source_order = ctx.next_inline_order
      let source_key = html_semantic_inline_source_key(
        element.tag_name,
        source_order,
      )
      let local_warnings : Array[HtmlSemanticWarning] = []
      if depth > HTML_SEMANTIC_MAX_DEPTH {
        local_warnings.push(
          new_html_semantic_warning(
            HtmlSemanticWarningKind::DepthLimitExceeded,
            source_key,
            element.tag_name,
            "html semantic inline depth limit exceeded at <" +
            element.tag_name +
            ">",
          ),
        )
      }
      if kind == HtmlInlineKind::UnsupportedInline {
        local_warnings.push(
          new_html_semantic_warning(
            HtmlSemanticWarningKind::UnsupportedElement,
            source_key,
            element.tag_name,
            "unsupported html inline element: <" + element.tag_name + ">",
          ),
        )
      }
      let (attrs, attr_warnings) = html_semantic_attribute_summary(
        element, source_key,
      )
      for warning in attr_warnings {
        local_warnings.push(warning)
      }
      let raw_text_result = html_semantic_raw_text_preview(element.children)
      let (text_preview, text_truncated) = html_semantic_text_preview(
        element.children,
      )
      if text_truncated {
        local_warnings.push(
          new_html_semantic_warning(
            HtmlSemanticWarningKind::TextPreviewTruncated,
            source_key,
            element.tag_name,
            "html semantic inline text preview truncated for <" +
            element.tag_name +
            ">",
          ),
        )
      }
      push_html_semantic_warnings(ctx, local_warnings)
      push_html_semantic_guard_unsupported_facts(
        ctx,
        local_warnings,
        source_key,
        element.tag_name,
        source_order,
        clamp_html_semantic_depth(depth),
        html_semantic_first_source_key(
          parent_inline_source_key, parent_block_source_key,
        ),
        text_preview,
        attrs,
        element.span,
      )

      let children : Array[String] = []
      ctx.inlines.push({
        kind,
        source_key,
        tag_name: element.tag_name,
        source_order,
        depth: clamp_html_semantic_depth(depth),
        parent_block_source_key,
        parent_inline_source_key,
        raw_text_preview: raw_text_result.0,
        normalized_text_preview: text_preview,
        text_preview,
        has_leading_whitespace: html_semantic_has_leading_whitespace(
          raw_text_result.0,
        ),
        has_trailing_whitespace: html_semantic_has_trailing_whitespace(
          raw_text_result.0,
        ),
        contains_newline: html_semantic_contains_newline(raw_text_result.0),
        contains_repeated_whitespace: html_semantic_contains_repeated_whitespace(
          raw_text_result.0,
        ),
        is_whitespace_only: raw_text_result.0.trim() == "",
        preserves_whitespace: kind == HtmlInlineKind::Code,
        has_surrounding_text,
        attributes: attrs,
        span: element.span,
        children,
        warnings: local_warnings,
      })
      let child_keys = collect_html_semantic_inlines_from_children(
        element.children,
        ctx,
        depth + 1,
        parent_block_source_key,
        Some(source_key),
      )
      for child_key in child_keys {
        children.push(child_key)
      }
      if kind == HtmlInlineKind::Link {
        collect_html_semantic_link_fact(
          element, ctx, source_key, parent_block_source_key, depth, text_preview,
          child_keys, local_warnings,
        )
      } else if kind == HtmlInlineKind::Image {
        collect_html_semantic_image_fact(
          element, ctx, source_key, parent_block_source_key, parent_inline_source_key,
          depth, local_warnings,
        )
      }
      Some(source_key)
    }
  }
}

///|
fn html_semantic_inline_kind(tag_name : String) -> HtmlInlineKind? {
  match tag_name {
    "a" => Some(HtmlInlineKind::Link)
    "img" => Some(HtmlInlineKind::Image)
    "em" | "i" => Some(HtmlInlineKind::Emphasis)
    "strong" | "b" => Some(HtmlInlineKind::Strong)
    "code" => Some(HtmlInlineKind::Code)
    "br" => Some(HtmlInlineKind::Break)
    "span" => Some(HtmlInlineKind::Span)
    "small" | "mark" | "sub" | "sup" => Some(HtmlInlineKind::InlineContainer)
    _ =>
      if is_html_semantic_unsupported_tag(tag_name) {
        Some(HtmlInlineKind::UnsupportedInline)
      } else {
        None
      }
  }
}

///|
fn collect_html_semantic_link_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  inline_source_key : String,
  parent_block_source_key : String?,
  depth : Int,
  text_preview : String,
  inline_child_keys : Array[String],
  inline_warnings : Array[HtmlSemanticWarning],
) -> Unit {
  ctx.next_link_order += 1
  let source_key = "html:link:" + ctx.next_link_order.to_string()
  let href = html_semantic_attr_value(element.attributes, "href")
    .unwrap_or("")
    .trim()
    .to_owned()
  let kind = classify_html_semantic_link_kind(href)
  let is_note_ref = html_semantic_anchor_is_note_ref(element)
  let is_back_reference = html_semantic_anchor_is_backref(element)
  let image_source_keys = html_semantic_image_keys_for_parent_inline(
    ctx.images,
    inline_source_key,
  )
  set_html_semantic_parent_link_source_key(
    ctx.images,
    inline_source_key,
    source_key,
  )
  let warnings : Array[HtmlSemanticWarning] = []
  for warning in inline_warnings {
    warnings.push(warning)
  }
  let fact_warnings : Array[HtmlSemanticWarning] = []
  match kind {
    HtmlLinkKind::Unsafe | HtmlLinkKind::Data =>
      fact_warnings.push(
        new_html_semantic_warning(
          HtmlSemanticWarningKind::UnsafeUrl,
          source_key,
          element.tag_name,
          "html semantic link has unsafe href",
        ),
      )
    HtmlLinkKind::Empty =>
      fact_warnings.push(
        new_html_semantic_warning(
          HtmlSemanticWarningKind::EmptyUrl,
          source_key,
          element.tag_name,
          "html semantic link has empty href",
        ),
      )
    _ => ()
  }
  for warning in fact_warnings {
    warnings.push(warning)
  }
  push_html_semantic_warnings(ctx, fact_warnings)
  match html_semantic_unsupported_kind_for_link(kind) {
    Some(unsupported_kind) => {
      let (attrs, _) = html_semantic_attribute_summary(element, source_key)
      ignore(
        push_html_semantic_unsupported_fact(
          ctx,
          unsupported_kind,
          html_semantic_unsupported_url_severity(unsupported_kind),
          Some(inline_source_key),
          element.tag_name,
          ctx.next_link_order,
          clamp_html_semantic_depth(depth),
          parent_block_source_key,
          text_preview,
          attrs,
          Some(bounded_html_semantic_url(href)),
          element.span,
          html_semantic_unsupported_url_message(unsupported_kind, "link"),
        ),
      )
    }
    None => ()
  }
  ctx.links.push({
    source_key,
    inline_source_key,
    parent_block_source_key,
    href: bounded_html_semantic_url(href),
    title: html_semantic_optional_bounded_attr(element.attributes, "title"),
    target: html_semantic_optional_bounded_attr(element.attributes, "target"),
    rel: html_semantic_optional_bounded_attr(element.attributes, "rel"),
    text_preview,
    inline_child_keys,
    image_source_keys,
    has_nested_inline: inline_child_keys.length() > 0,
    has_image: image_source_keys.length() > 0,
    is_note_ref,
    is_back_reference,
    kind,
    span: element.span,
    warnings,
  })
  if is_note_ref || is_back_reference {
    collect_html_semantic_note_ref_fact(
      element, ctx, source_key, inline_source_key, parent_block_source_key, href,
      text_preview, inline_child_keys, is_back_reference, warnings,
    )
  }
}

///|
fn collect_html_semantic_image_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  inline_source_key : String,
  parent_block_source_key : String?,
  parent_inline_source_key : String?,
  depth : Int,
  inline_warnings : Array[HtmlSemanticWarning],
) -> Unit {
  ctx.next_image_order += 1
  let source_key = "html:image:" + ctx.next_image_order.to_string()
  let src = html_semantic_attr_value(element.attributes, "src")
    .unwrap_or("")
    .trim()
    .to_owned()
  let kind = classify_html_semantic_image_kind(src)
  let parent_link_source_key = html_semantic_link_key_for_inline(
    ctx.links,
    parent_inline_source_key,
  )
  let warnings : Array[HtmlSemanticWarning] = []
  for warning in inline_warnings {
    warnings.push(warning)
  }
  let fact_warnings : Array[HtmlSemanticWarning] = []
  match kind {
    HtmlImageKind::Remote =>
      fact_warnings.push(
        new_html_semantic_warning(
          HtmlSemanticWarningKind::RemoteImage,
          source_key,
          element.tag_name,
          "html semantic image references remote source",
        ),
      )
    HtmlImageKind::DataUri =>
      fact_warnings.push(
        new_html_semantic_warning(
          HtmlSemanticWarningKind::DataUriImage,
          source_key,
          element.tag_name,
          "html semantic image uses data uri source",
        ),
      )
    HtmlImageKind::Unsafe =>
      fact_warnings.push(
        new_html_semantic_warning(
          HtmlSemanticWarningKind::UnsafeUrl,
          source_key,
          element.tag_name,
          "html semantic image has unsafe source",
        ),
      )
    HtmlImageKind::Empty =>
      fact_warnings.push(
        new_html_semantic_warning(
          HtmlSemanticWarningKind::EmptyImageSource,
          source_key,
          element.tag_name,
          "html semantic image has empty source",
        ),
      )
    _ => ()
  }
  for warning in fact_warnings {
    warnings.push(warning)
  }
  push_html_semantic_warnings(ctx, fact_warnings)
  match html_semantic_unsupported_kind_for_image(kind) {
    Some(unsupported_kind) => {
      let (attrs, _) = html_semantic_attribute_summary(element, source_key)
      ignore(
        push_html_semantic_unsupported_fact(
          ctx,
          unsupported_kind,
          html_semantic_unsupported_url_severity(unsupported_kind),
          Some(inline_source_key),
          element.tag_name,
          ctx.next_image_order,
          clamp_html_semantic_depth(depth),
          parent_block_source_key,
          "",
          attrs,
          Some(bounded_html_semantic_url(src)),
          element.span,
          html_semantic_unsupported_url_message(unsupported_kind, "image"),
        ),
      )
    }
    None => ()
  }
  ctx.images.push({
    source_key,
    inline_source_key,
    parent_block_source_key,
    parent_inline_source_key,
    parent_link_source_key,
    src: bounded_html_semantic_url(src),
    srcset: html_semantic_optional_bounded_attr(element.attributes, "srcset"),
    alt: html_semantic_optional_bounded_attr(element.attributes, "alt"),
    title: html_semantic_optional_bounded_attr(element.attributes, "title"),
    width: html_semantic_optional_bounded_attr(element.attributes, "width"),
    height: html_semantic_optional_bounded_attr(element.attributes, "height"),
    loading: html_semantic_optional_bounded_attr(element.attributes, "loading"),
    decoding: html_semantic_optional_bounded_attr(
      element.attributes,
      "decoding",
    ),
    picture_source_keys: [],
    alt_complete: html_semantic_attr_preview_complete(element.attributes, "alt"),
    title_complete: html_semantic_attr_preview_complete(
      element.attributes,
      "title",
    ),
    kind,
    span: element.span,
    warnings,
  })
}

///|
fn collect_html_semantic_polished_block_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  block_kind : HtmlBlockKind,
  block_source_key : String,
  source_order : Int,
  depth : Int,
  parent_block_source_key : String?,
  child_block_source_keys : Array[String],
  attributes : Array[HtmlSemanticAttributeSummary],
  text_preview : String,
  block_warnings : Array[HtmlSemanticWarning],
) -> Unit {
  if block_kind == HtmlBlockKind::Paragraph ||
    html_semantic_container_has_direct_text(element.children) {
    collect_html_semantic_paragraph_fact(
      element, ctx, block_kind, block_source_key, source_order, depth, parent_block_source_key,
      attributes, text_preview, block_warnings,
    )
  }
  match block_kind {
    HtmlBlockKind::List(ordered) =>
      collect_html_semantic_list_fact(
        element, ctx, block_source_key, source_order, depth, parent_block_source_key,
        ordered, child_block_source_keys, attributes, text_preview, block_warnings,
      )
    HtmlBlockKind::ListItem =>
      collect_html_semantic_list_item_fact(
        element, ctx, block_source_key, source_order, depth, parent_block_source_key,
        child_block_source_keys, attributes, text_preview, block_warnings,
      )
    HtmlBlockKind::BlockQuote =>
      collect_html_semantic_blockquote_fact(
        element, ctx, block_source_key, source_order, depth, parent_block_source_key,
        child_block_source_keys, attributes, text_preview, block_warnings,
      )
    HtmlBlockKind::Pre | HtmlBlockKind::CodeBlock =>
      collect_html_semantic_code_block_fact(
        element, ctx, block_source_key, source_order, depth, attributes, text_preview,
        block_warnings,
      )
    HtmlBlockKind::Figure =>
      collect_html_semantic_figure_fact(
        element, ctx, block_source_key, source_order, depth, child_block_source_keys,
        attributes, text_preview, block_warnings,
      )
    _ => ()
  }
}

///|
fn collect_html_semantic_paragraph_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  block_kind : HtmlBlockKind,
  block_source_key : String,
  source_order : Int,
  depth : Int,
  parent_block_source_key : String?,
  attributes : Array[HtmlSemanticAttributeSummary],
  text_preview : String,
  block_warnings : Array[HtmlSemanticWarning],
) -> Unit {
  let inline_child_keys = html_semantic_inline_keys_for_block(
    ctx.inlines,
    block_source_key,
  )
  let inline_summary = html_semantic_paragraph_inline_summary(
    ctx.inlines,
    inline_child_keys,
  )
  let raw_text = html_semantic_raw_text_preview(element.children).0
  let normalized_text = normalize_html_semantic_preview(raw_text)
  let warnings : Array[HtmlSemanticWarning] = []
  for warning in block_warnings {
    warnings.push(warning)
  }
  ctx.paragraphs.push({
    source_key: "html:paragraph:" + source_order.to_string(),
    block_source_key,
    tag_name: element.tag_name,
    source_order,
    depth: clamp_html_semantic_depth(depth),
    parent_block_source_key,
    inline_child_keys,
    raw_text_preview: bounded_html_semantic_preview(
      raw_text,
      HTML_SEMANTIC_TEXT_PREVIEW_MAX_CHARS,
    ).0,
    normalized_text_preview: bounded_html_semantic_preview(
      normalized_text,
      HTML_SEMANTIC_TEXT_PREVIEW_MAX_CHARS,
    ).0,
    has_meaningful_text: text_preview.trim() != "",
    has_links: inline_summary.has_links,
    has_images: inline_summary.has_images,
    has_code: inline_summary.has_code,
    has_emphasis: inline_summary.has_emphasis,
    has_strong: inline_summary.has_strong,
    has_breaks: inline_summary.has_breaks,
    has_repeated_whitespace: inline_summary.has_repeated_whitespace ||
    html_semantic_contains_repeated_whitespace(raw_text),
    has_newline: inline_summary.has_newline ||
    html_semantic_contains_newline(raw_text),
    is_candidate: block_kind != HtmlBlockKind::Paragraph,
    text_preview,
    attributes,
    span: element.span,
    warnings,
  })
}

///|
priv struct HtmlSemanticParagraphInlineSummary {
  has_links : Bool
  has_images : Bool
  has_code : Bool
  has_emphasis : Bool
  has_strong : Bool
  has_breaks : Bool
  has_repeated_whitespace : Bool
  has_newline : Bool
}

///|
fn html_semantic_paragraph_inline_summary(
  inlines : Array[HtmlInlineFact],
  inline_child_keys : Array[String],
) -> HtmlSemanticParagraphInlineSummary {
  let mut has_links = false
  let mut has_images = false
  let mut has_code = false
  let mut has_emphasis = false
  let mut has_strong = false
  let mut has_breaks = false
  let mut has_repeated_whitespace = false
  let mut has_newline = false
  for key in inline_child_keys {
    match html_semantic_inline_for_key(inlines, key) {
      Some(inline) => {
        match inline.kind {
          HtmlInlineKind::Link => has_links = true
          HtmlInlineKind::Image => has_images = true
          HtmlInlineKind::Code => has_code = true
          HtmlInlineKind::Emphasis => has_emphasis = true
          HtmlInlineKind::Strong => has_strong = true
          HtmlInlineKind::Break => has_breaks = true
          _ => ()
        }
        if inline.contains_repeated_whitespace {
          has_repeated_whitespace = true
        }
        if inline.contains_newline {
          has_newline = true
        }
      }
      None => ()
    }
  }
  {
    has_links,
    has_images,
    has_code,
    has_emphasis,
    has_strong,
    has_breaks,
    has_repeated_whitespace,
    has_newline,
  }
}

///|
fn html_semantic_inline_for_key(
  inlines : Array[HtmlInlineFact],
  source_key : String,
) -> HtmlInlineFact? {
  for inline in inlines {
    if inline.source_key == source_key {
      return Some(inline)
    }
  }
  None
}

///|
fn collect_html_semantic_list_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  block_source_key : String,
  source_order : Int,
  depth : Int,
  parent_block_source_key : String?,
  ordered : Bool,
  child_block_source_keys : Array[String],
  attributes : Array[HtmlSemanticAttributeSummary],
  text_preview : String,
  block_warnings : Array[HtmlSemanticWarning],
) -> Unit {
  let source_key = html_semantic_list_source_key(source_order)
  let item_keys : Array[String] = []
  for child_key in child_block_source_keys {
    if html_semantic_block_kind_for_key(ctx.blocks, child_key) ==
      Some(HtmlBlockKind::ListItem) {
      item_keys.push(child_key)
    }
  }
  let warnings : Array[HtmlSemanticWarning] = []
  for warning in block_warnings {
    warnings.push(warning)
  }
  let kind = if ordered {
    HtmlListKind::Ordered
  } else {
    HtmlListKind::Unordered
  }
  ctx.lists.push({
    source_key,
    block_source_key,
    kind,
    tag_name: element.tag_name,
    source_order,
    depth: clamp_html_semantic_depth(depth),
    list_depth: html_semantic_list_depth(ctx.blocks, block_source_key),
    parent_list_source_key: html_semantic_parent_list_key(
      ctx.blocks,
      parent_block_source_key,
    ),
    parent_item_source_key: html_semantic_parent_item_key(
      ctx.blocks,
      ctx.list_items,
      parent_block_source_key,
    ),
    item_source_keys: item_keys,
    item_count: item_keys.length(),
    start: html_semantic_optional_bounded_attr(element.attributes, "start"),
    type_attr: html_semantic_optional_bounded_attr(element.attributes, "type"),
    reversed: html_semantic_has_attr(element.attributes, "reversed"),
    text_preview,
    attributes,
    span: element.span,
    warnings,
  })
}

///|
fn collect_html_semantic_list_item_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  block_source_key : String,
  source_order : Int,
  depth : Int,
  parent_block_source_key : String?,
  child_block_source_keys : Array[String],
  attributes : Array[HtmlSemanticAttributeSummary],
  text_preview : String,
  block_warnings : Array[HtmlSemanticWarning],
) -> Unit {
  let source_key = html_semantic_list_item_source_key(source_order)
  let child_list_source_keys : Array[String] = []
  for child_key in child_block_source_keys {
    match html_semantic_block_for_key(ctx.blocks, child_key) {
      Some(block) =>
        match block.kind {
          HtmlBlockKind::List(_) =>
            child_list_source_keys.push(
              html_semantic_list_source_key(block.source_order),
            )
          _ => ()
        }
      None => ()
    }
  }
  let warnings : Array[HtmlSemanticWarning] = []
  for warning in block_warnings {
    warnings.push(warning)
  }
  let parent_list_source_key = html_semantic_parent_list_key(
    ctx.blocks,
    parent_block_source_key,
  )
  ctx.list_items.push({
    source_key,
    block_source_key,
    list_source_key: parent_list_source_key,
    parent_item_source_key: html_semantic_parent_item_key(
      ctx.blocks,
      ctx.list_items,
      parent_block_source_key,
    ),
    source_order,
    depth: clamp_html_semantic_depth(depth),
    list_depth: html_semantic_list_depth(ctx.blocks, block_source_key),
    item_order: html_semantic_item_order_in_list(
      ctx.list_items,
      parent_list_source_key,
    ),
    child_list_source_keys,
    text_preview,
    attributes,
    span: element.span,
    warnings,
  })
}

///|
fn collect_html_semantic_blockquote_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  block_source_key : String,
  source_order : Int,
  depth : Int,
  parent_block_source_key : String?,
  child_block_source_keys : Array[String],
  attributes : Array[HtmlSemanticAttributeSummary],
  text_preview : String,
  block_warnings : Array[HtmlSemanticWarning],
) -> Unit {
  let source_key = html_semantic_blockquote_source_key(source_order)
  let warnings : Array[HtmlSemanticWarning] = []
  for warning in block_warnings {
    warnings.push(warning)
  }
  ctx.blockquotes.push({
    source_key,
    block_source_key,
    source_order,
    depth: clamp_html_semantic_depth(depth),
    quote_depth: html_semantic_quote_depth(ctx.blocks, block_source_key),
    parent_quote_source_key: html_semantic_parent_quote_key(
      ctx.blocks,
      parent_block_source_key,
    ),
    child_block_source_keys,
    cite: html_semantic_optional_bounded_attr(element.attributes, "cite"),
    text_preview,
    attributes,
    span: element.span,
    warnings,
  })
}

///|
fn collect_html_semantic_code_block_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  block_source_key : String,
  source_order : Int,
  depth : Int,
  attributes : Array[HtmlSemanticAttributeSummary],
  text_preview : String,
  block_warnings : Array[HtmlSemanticWarning],
) -> Unit {
  ctx.next_code_block_order += 1
  let source_key = "html:code-block:" + ctx.next_code_block_order.to_string()
  let warnings : Array[HtmlSemanticWarning] = []
  for warning in block_warnings {
    warnings.push(warning)
  }
  let own_class_hint = html_semantic_optional_bounded_attr(
    element.attributes,
    "class",
  )
  let child_code_class_hint = if element.tag_name == "pre" {
    match find_html_semantic_direct_child_element(element, "code") {
      Some(code_element) =>
        html_semantic_optional_bounded_attr(code_element.attributes, "class")
      None => None
    }
  } else {
    None
  }
  let class_hint = match own_class_hint {
    Some(value) => Some(value)
    None => child_code_class_hint
  }
  let language_hint = match class_hint {
    Some(value) => html_semantic_language_hint_from_class(value)
    None => None
  }
  let code_child_key = if element.tag_name == "pre" {
    find_html_semantic_child_block_key_by_tag(
      ctx.blocks,
      block_source_key,
      "code",
    )
  } else {
    None
  }
  let code_text_result = html_semantic_code_text(element.children)
  ctx.code_blocks.push({
    source_key,
    block_source_key,
    code_block_source_key: code_child_key,
    tag_name: element.tag_name,
    source_order,
    depth: clamp_html_semantic_depth(depth),
    language_hint,
    class_hint,
    code_text: code_text_result.0,
    code_text_complete: !code_text_result.1,
    whitespace_preview: html_semantic_whitespace_text_preview(element.children).0,
    text_preview,
    attributes,
    span: element.span,
    warnings,
  })
}

///|
fn collect_html_semantic_figure_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  block_source_key : String,
  source_order : Int,
  depth : Int,
  child_block_source_keys : Array[String],
  attributes : Array[HtmlSemanticAttributeSummary],
  text_preview : String,
  block_warnings : Array[HtmlSemanticWarning],
) -> Unit {
  ctx.next_figure_order += 1
  let source_key = "html:figure:" + ctx.next_figure_order.to_string()
  let warnings : Array[HtmlSemanticWarning] = []
  for warning in block_warnings {
    warnings.push(warning)
  }
  let caption_block_source_key = find_html_semantic_child_block_key_by_tag(
    ctx.blocks,
    block_source_key,
    "figcaption",
  )
  let caption_text_preview = match caption_block_source_key {
    Some(key) => html_semantic_block_text_preview_for_key(ctx.blocks, key)
    None => None
  }
  ctx.figures.push({
    source_key,
    block_source_key,
    source_order,
    depth: clamp_html_semantic_depth(depth),
    child_block_source_keys,
    caption_block_source_key,
    caption_text_preview,
    image_source_keys: html_semantic_image_keys_for_block(
      ctx.images,
      block_source_key,
    ),
    link_source_keys: html_semantic_link_keys_for_block(
      ctx.links,
      block_source_key,
    ),
    inline_child_keys: html_semantic_inline_keys_for_block(
      ctx.inlines,
      block_source_key,
    ),
    text_preview,
    attributes,
    span: element.span,
    warnings,
  })
}

///|
fn collect_html_semantic_note_body_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  block_source_key : String,
  source_order : Int,
  _depth : Int,
  parent_block_source_key : String?,
  _attributes : Array[HtmlSemanticAttributeSummary],
  text_preview : String,
  block_warnings : Array[HtmlSemanticWarning],
) -> Unit {
  let kind = html_semantic_note_body_kind(element)
  if kind == HtmlNoteKind::Unknown {
    return
  }
  let note_id = html_semantic_note_body_id(element)
  let duplicate_target = match note_id {
    Some(id) => html_semantic_note_body_id_seen(ctx.note_bodies, id)
    None => false
  }
  ctx.next_note_body_order += 1
  let source_key = "html:note-body:" + ctx.next_note_body_order.to_string()
  let warnings : Array[HtmlSemanticWarning] = []
  for warning in block_warnings {
    warnings.push(warning)
  }
  if duplicate_target {
    let warning = new_html_semantic_warning(
      HtmlSemanticWarningKind::DuplicateNoteTarget,
      source_key,
      element.tag_name,
      "html semantic note body has duplicate target id",
    )
    warnings.push(warning)
    ctx.warnings.push(warning)
  }
  ctx.note_bodies.push({
    source_key,
    block_source_key,
    source_order,
    kind,
    note_id,
    marker: html_semantic_note_marker(element.children),
    body_text_preview: text_preview,
    inline_child_keys: html_semantic_inline_keys_for_block(
      ctx.inlines,
      block_source_key,
    ),
    owning_block_source_key: parent_block_source_key,
    ref_source_keys: [],
    duplicate_target,
    span: element.span,
    warnings,
  })
}

///|
fn collect_html_semantic_note_ref_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  link_source_key : String,
  inline_source_key : String,
  parent_block_source_key : String?,
  href : String,
  text_preview : String,
  inline_child_keys : Array[String],
  is_back_reference : Bool,
  link_warnings : Array[HtmlSemanticWarning],
) -> Unit {
  ctx.next_note_ref_order += 1
  let source_key = "html:note-ref:" + ctx.next_note_ref_order.to_string()
  let target_id = html_semantic_fragment_id_from_href(href)
  let warnings : Array[HtmlSemanticWarning] = []
  for warning in link_warnings {
    warnings.push(warning)
  }
  let kind = if is_back_reference {
    HtmlNoteKind::BackReference
  } else if html_semantic_attr_token_contains(
      element.attributes,
      "epub:type",
      "endnote",
    ) {
    HtmlNoteKind::EndnoteLike
  } else {
    HtmlNoteKind::Reference
  }
  let is_broken = target_id is None
  if is_broken {
    let warning = new_html_semantic_warning(
      HtmlSemanticWarningKind::BrokenNoteTarget,
      source_key,
      element.tag_name,
      "html semantic note reference has no same-document target",
    )
    warnings.push(warning)
    ctx.warnings.push(warning)
  }
  ctx.note_refs.push({
    source_key,
    inline_source_key,
    parent_block_source_key,
    href: bounded_html_semantic_url(href),
    target_id,
    ref_text_preview: text_preview,
    inline_child_keys,
    kind,
    source_order: ctx.next_note_ref_order,
    relation_confidence: if is_broken {
      HtmlNoteRelationConfidence::Broken
    } else {
      HtmlNoteRelationConfidence::Medium
    },
    is_broken,
    is_back_reference,
    span: element.span,
    warnings,
  })
  ignore(link_source_key)
}

///|
fn collect_html_semantic_note_relations(ctx : HtmlSemanticCollectCtx) -> Unit {
  for note_ref in ctx.note_refs {
    if note_ref.is_back_reference {
      ctx.next_note_order += 1
      ctx.notes.push({
        source_key: "html:note:" + ctx.next_note_order.to_string(),
        note_id: note_ref.target_id,
        kind: HtmlNoteKind::BackReference,
        ref_source_key: Some(note_ref.source_key),
        body_source_key: None,
        href: Some(note_ref.href),
        ref_text_preview: note_ref.ref_text_preview,
        body_text_preview: "",
        source_order: ctx.next_note_order,
        relation_confidence: note_ref.relation_confidence,
        warnings: note_ref.warnings,
      })
      continue
    }
    match note_ref.target_id {
      Some(target_id) =>
        match html_semantic_note_body_for_id(ctx.note_bodies, target_id) {
          Some(body) => {
            ctx.next_note_order += 1
            let warnings : Array[HtmlSemanticWarning] = []
            for warning in note_ref.warnings {
              warnings.push(warning)
            }
            for warning in body.warnings {
              warnings.push(warning)
            }
            ctx.notes.push({
              source_key: "html:note:" + ctx.next_note_order.to_string(),
              note_id: Some(target_id),
              kind: body.kind,
              ref_source_key: Some(note_ref.source_key),
              body_source_key: Some(body.source_key),
              href: Some(note_ref.href),
              ref_text_preview: note_ref.ref_text_preview,
              body_text_preview: body.body_text_preview,
              source_order: ctx.next_note_order,
              relation_confidence: if body.duplicate_target {
                HtmlNoteRelationConfidence::Low
              } else {
                HtmlNoteRelationConfidence::High
              },
              warnings,
            })
          }
          None => {
            let warning = new_html_semantic_warning(
              HtmlSemanticWarningKind::MissingNoteTarget,
              note_ref.source_key,
              "a",
              "html semantic note reference target is missing",
            )
            ctx.warnings.push(warning)
            ctx.next_note_order += 1
            let warnings : Array[HtmlSemanticWarning] = []
            for item in note_ref.warnings {
              warnings.push(item)
            }
            warnings.push(warning)
            ctx.notes.push({
              source_key: "html:note:" + ctx.next_note_order.to_string(),
              note_id: Some(target_id),
              kind: note_ref.kind,
              ref_source_key: Some(note_ref.source_key),
              body_source_key: None,
              href: Some(note_ref.href),
              ref_text_preview: note_ref.ref_text_preview,
              body_text_preview: "",
              source_order: ctx.next_note_order,
              relation_confidence: HtmlNoteRelationConfidence::Broken,
              warnings,
            })
          }
        }
      None => {
        ctx.next_note_order += 1
        ctx.notes.push({
          source_key: "html:note:" + ctx.next_note_order.to_string(),
          note_id: None,
          kind: note_ref.kind,
          ref_source_key: Some(note_ref.source_key),
          body_source_key: None,
          href: Some(note_ref.href),
          ref_text_preview: note_ref.ref_text_preview,
          body_text_preview: "",
          source_order: ctx.next_note_order,
          relation_confidence: HtmlNoteRelationConfidence::Broken,
          warnings: note_ref.warnings,
        })
      }
    }
  }
  for body in ctx.note_bodies {
    if body.duplicate_target {
      ctx.next_note_order += 1
      ctx.notes.push({
        source_key: "html:note:" + ctx.next_note_order.to_string(),
        note_id: body.note_id,
        kind: body.kind,
        ref_source_key: None,
        body_source_key: Some(body.source_key),
        href: None,
        ref_text_preview: "",
        body_text_preview: body.body_text_preview,
        source_order: ctx.next_note_order,
        relation_confidence: HtmlNoteRelationConfidence::Low,
        warnings: body.warnings,
      })
    }
  }
}

///|
fn collect_html_semantic_table_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  block_source_key : String,
  source_order : Int,
  depth : Int,
  parent_block_source_key : String?,
  attributes : Array[HtmlSemanticAttributeSummary],
  text_preview : String,
  block_warnings : Array[HtmlSemanticWarning],
) -> Unit {
  ctx.next_table_order += 1
  let source_key = "html:table:" + ctx.next_table_order.to_string()
  let sections : Array[String] = []
  let rows : Array[String] = []
  let cells : Array[String] = []
  let table_warnings : Array[HtmlSemanticWarning] = []
  for warning in block_warnings {
    table_warnings.push(warning)
  }

  let caption = find_html_semantic_direct_child_element(element, "caption")
  let caption_source_key = caption.map(fn(caption_element) {
    html_semantic_caption_source_key(source_key, caption_element)
  })
  let caption_text_preview = caption.map(fn(caption_element) {
    html_semantic_text_preview(caption_element.children).0
  })

  let row_count : Ref[Int] = { val: 0 }
  let cell_count : Ref[Int] = { val: 0 }
  for child in element.children {
    match child {
      HtmlNode::Element(child_element) =>
        if html_semantic_table_section_kind(child_element.tag_name)
          is Some(kind) {
          collect_html_semantic_table_section_fact(
            child_element,
            ctx,
            source_key,
            block_source_key,
            kind,
            depth + 1,
            sections,
            rows,
            cells,
            row_count,
            cell_count,
          )
        } else if child_element.tag_name == "tr" {
          ignore(
            collect_html_semantic_table_row_fact(
              child_element,
              ctx,
              source_key,
              None,
              block_source_key,
              depth + 1,
              rows,
              cells,
              row_count,
              cell_count,
            ),
          )
        } else {
          collect_html_semantic_table_nested_rows(
            child_element,
            ctx,
            source_key,
            None,
            block_source_key,
            depth + 1,
            rows,
            cells,
            row_count,
            cell_count,
          )
        }
      _ => ()
    }
  }

  if row_count.val > HTML_SEMANTIC_TABLE_MAX_ROWS ||
    cell_count.val > HTML_SEMANTIC_TABLE_MAX_CELLS {
    table_warnings.push(
      new_html_semantic_warning(
        HtmlSemanticWarningKind::TableSizeLimitExceeded,
        source_key,
        element.tag_name,
        "html semantic table size limit exceeded",
      ),
    )
    ignore(
      push_html_semantic_unsupported_fact(
        ctx,
        HtmlUnsupportedKind::HugeTable,
        HtmlWarningSeverity::Warning,
        Some(source_key),
        element.tag_name,
        ctx.next_table_order,
        depth,
        parent_block_source_key,
        text_preview,
        attributes,
        None,
        element.span,
        "html semantic table size limit exceeded",
      ),
    )
  }
  if row_count.val == 0 || cell_count.val == 0 {
    table_warnings.push(
      new_html_semantic_warning(
        HtmlSemanticWarningKind::MalformedTableStructure,
        source_key,
        element.tag_name,
        "html semantic table has no rows or cells",
      ),
    )
  }
  push_html_semantic_warnings(ctx, table_warnings)

  let max_column_count = html_semantic_table_max_column_count(
    ctx.table_rows,
    rows,
  )
  let has_ragged_rows = html_semantic_table_has_ragged_rows(
    ctx.table_rows,
    rows,
    max_column_count,
  )
  let has_span = html_semantic_table_has_span(ctx.table_cells, cells)
  let has_caption = caption_source_key is Some(_)
  let has_nested_table = html_semantic_table_has_nested_table(
    ctx.blocks,
    block_source_key,
  )
  let has_complex_cell = html_semantic_table_has_complex_cell(
    ctx.table_cells,
    cells,
  )
  let span_cell_count = html_semantic_table_span_cell_count(
    ctx.table_cells,
    cells,
  )
  let ragged_row_count = html_semantic_table_ragged_row_count(
    ctx.table_rows,
    rows,
    max_column_count,
  )
  let nested_table_cell_count = html_semantic_table_nested_cell_count(
    ctx.table_cells,
    cells,
  )
  let complex_cell_count = html_semantic_table_complex_cell_count(
    ctx.table_cells,
    cells,
  )
  let image_cell_count = html_semantic_table_image_cell_count(
    ctx.table_cells,
    cells,
  )
  let block_child_cell_count = html_semantic_table_block_child_cell_count(
    ctx.table_cells,
    cells,
  )
  let malformed_warning_count = html_semantic_warning_kind_count(
    table_warnings,
    HtmlSemanticWarningKind::MalformedTableStructure,
  )
  let safe_simple_table_candidate = table_warnings.length() == 0 &&
    row_count.val > 0 &&
    cell_count.val > 0 &&
    !has_ragged_rows &&
    !has_span &&
    !has_caption &&
    !has_nested_table &&
    !has_complex_cell

  ctx.tables.push({
    source_key,
    block_source_key,
    tag_name: element.tag_name,
    source_order,
    depth,
    parent_block_source_key,
    caption_source_key,
    caption_text_preview,
    sections,
    rows,
    cells,
    row_count: row_count.val,
    cell_count: cell_count.val,
    max_column_count,
    has_ragged_rows,
    has_span,
    has_caption,
    has_nested_table,
    has_complex_cell,
    span_cell_count,
    ragged_row_count,
    nested_table_cell_count,
    complex_cell_count,
    image_cell_count,
    block_child_cell_count,
    malformed_warning_count,
    safe_simple_table_candidate,
    text_preview,
    attributes,
    span: element.span,
    warnings: table_warnings,
  })
}

///|
fn collect_html_semantic_table_section_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  table_source_key : String,
  block_source_key : String,
  kind : HtmlTableSectionKind,
  depth : Int,
  table_sections : Array[String],
  table_rows : Array[String],
  table_cells : Array[String],
  row_count : Ref[Int],
  cell_count : Ref[Int],
) -> Unit {
  ctx.next_table_section_order += 1
  let source_order = ctx.next_table_section_order
  let source_key = "html:table-section:" + source_order.to_string()
  let local_warnings : Array[HtmlSemanticWarning] = []
  let (attrs, attr_warnings) = html_semantic_attribute_summary(
    element, source_key,
  )
  for warning in attr_warnings {
    local_warnings.push(warning)
  }
  let (text_preview, text_truncated) = html_semantic_text_preview(
    element.children,
  )
  if text_truncated {
    local_warnings.push(
      new_html_semantic_warning(
        HtmlSemanticWarningKind::TextPreviewTruncated,
        source_key,
        element.tag_name,
        "html semantic table section text preview truncated for <" +
        element.tag_name +
        ">",
      ),
    )
  }

  let row_source_keys : Array[String] = []
  let start_row_count = row_count.val
  for child in element.children {
    match child {
      HtmlNode::Element(child_element) =>
        if child_element.tag_name == "tr" {
          match
            collect_html_semantic_table_row_fact(
              child_element,
              ctx,
              table_source_key,
              Some(source_key),
              block_source_key,
              depth + 1,
              table_rows,
              table_cells,
              row_count,
              cell_count,
            ) {
            Some(row_key) => row_source_keys.push(row_key)
            None => ()
          }
        } else {
          collect_html_semantic_table_nested_rows(
            child_element,
            ctx,
            table_source_key,
            Some(source_key),
            block_source_key,
            depth + 1,
            table_rows,
            table_cells,
            row_count,
            cell_count,
          )
        }
      _ => ()
    }
  }
  if row_source_keys.length() == 0 {
    local_warnings.push(
      new_html_semantic_warning(
        HtmlSemanticWarningKind::MalformedTableStructure,
        source_key,
        element.tag_name,
        "html semantic table section has no rows",
      ),
    )
  }
  push_html_semantic_warnings(ctx, local_warnings)

  table_sections.push(source_key)
  ctx.table_sections.push({
    source_key,
    table_source_key,
    block_source_key,
    kind,
    tag_name: element.tag_name,
    source_order,
    depth: clamp_html_semantic_depth(depth),
    row_source_keys,
    row_count: row_count.val - start_row_count,
    text_preview,
    attributes: attrs,
    span: element.span,
    warnings: local_warnings,
  })
}

///|
fn collect_html_semantic_table_nested_rows(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  table_source_key : String,
  section_source_key : String?,
  table_block_source_key : String,
  depth : Int,
  table_rows : Array[String],
  table_cells : Array[String],
  row_count : Ref[Int],
  cell_count : Ref[Int],
) -> Unit {
  if element.tag_name == "table" {
    return
  }
  for child in element.children {
    match child {
      HtmlNode::Element(child_element) =>
        if child_element.tag_name == "tr" {
          ignore(
            collect_html_semantic_table_row_fact(
              child_element,
              ctx,
              table_source_key,
              section_source_key,
              table_block_source_key,
              depth + 1,
              table_rows,
              table_cells,
              row_count,
              cell_count,
            ),
          )
        } else {
          collect_html_semantic_table_nested_rows(
            child_element,
            ctx,
            table_source_key,
            section_source_key,
            table_block_source_key,
            depth + 1,
            table_rows,
            table_cells,
            row_count,
            cell_count,
          )
        }
      _ => ()
    }
  }
}

///|
fn collect_html_semantic_table_row_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  table_source_key : String,
  section_source_key : String?,
  table_block_source_key : String,
  depth : Int,
  table_rows : Array[String],
  table_cells : Array[String],
  row_count : Ref[Int],
  cell_count : Ref[Int],
) -> String? {
  row_count.val += 1
  let row_index = row_count.val - 1
  ctx.next_table_row_order += 1
  let source_order = ctx.next_table_row_order
  let source_key = "html:table-row:" + source_order.to_string()
  let row_block_source_key = html_semantic_descendant_block_key_by_tag_index(
    ctx.blocks,
    table_block_source_key,
    "tr",
    row_index,
  ).unwrap_or(table_block_source_key)
  let local_warnings : Array[HtmlSemanticWarning] = []
  let (attrs, attr_warnings) = html_semantic_attribute_summary(
    element, source_key,
  )
  for warning in attr_warnings {
    local_warnings.push(warning)
  }
  let (text_preview, text_truncated) = html_semantic_text_preview(
    element.children,
  )
  if text_truncated {
    local_warnings.push(
      new_html_semantic_warning(
        HtmlSemanticWarningKind::TextPreviewTruncated,
        source_key,
        element.tag_name,
        "html semantic table row text preview truncated",
      ),
    )
  }

  let cell_source_keys : Array[String] = []
  let mut row_cell_count = 0
  for child in element.children {
    match child {
      HtmlNode::Element(child_element) =>
        match html_semantic_table_cell_kind(child_element.tag_name) {
          Some(kind) => {
            cell_count.val += 1
            let cell_index = row_cell_count
            row_cell_count += 1
            match
              collect_html_semantic_table_cell_fact(
                child_element,
                ctx,
                table_source_key,
                section_source_key,
                source_key,
                row_block_source_key,
                depth + 1,
                row_index,
                cell_index,
                kind,
              ) {
              Some(cell_key) => {
                cell_source_keys.push(cell_key)
                table_cells.push(cell_key)
              }
              None => ()
            }
          }
          None => ()
        }
      _ => ()
    }
  }
  if row_cell_count == 0 {
    local_warnings.push(
      new_html_semantic_warning(
        HtmlSemanticWarningKind::MalformedTableStructure,
        source_key,
        element.tag_name,
        "html semantic table row has no cells",
      ),
    )
  }
  push_html_semantic_warnings(ctx, local_warnings)

  table_rows.push(source_key)
  ctx.table_rows.push({
    source_key,
    table_source_key,
    section_source_key,
    block_source_key: row_block_source_key,
    source_order,
    depth: clamp_html_semantic_depth(depth),
    row_index,
    cell_source_keys,
    cell_count: row_cell_count,
    text_preview,
    attributes: attrs,
    span: element.span,
    warnings: local_warnings,
  })
  Some(source_key)
}

///|
fn collect_html_semantic_table_cell_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  table_source_key : String,
  section_source_key : String?,
  row_source_key : String,
  block_source_key : String,
  depth : Int,
  row_index : Int,
  cell_index : Int,
  kind : HtmlTableCellKind,
) -> String? {
  ctx.next_table_cell_order += 1
  let source_order = ctx.next_table_cell_order
  let source_key = "html:table-cell:" + source_order.to_string()
  let cell_block_source_key = html_semantic_table_cell_block_key_by_index(
    ctx.blocks,
    block_source_key,
    cell_index,
  ).unwrap_or(block_source_key)
  let local_warnings : Array[HtmlSemanticWarning] = []
  let (attrs, attr_warnings) = html_semantic_attribute_summary(
    element, source_key,
  )
  for warning in attr_warnings {
    local_warnings.push(warning)
  }
  let (text_preview, text_truncated) = html_semantic_text_preview(
    element.children,
  )
  if text_truncated {
    local_warnings.push(
      new_html_semantic_warning(
        HtmlSemanticWarningKind::TextPreviewTruncated,
        source_key,
        element.tag_name,
        "html semantic table cell text preview truncated",
      ),
    )
  }
  push_html_semantic_warnings(ctx, local_warnings)

  let inline_child_keys = html_semantic_inline_keys_for_block(
    ctx.inlines,
    cell_block_source_key,
  )
  let direct_child_block_keys = html_semantic_direct_child_block_keys(
    ctx.blocks,
    cell_block_source_key,
  )
  let colspan = html_semantic_optional_bounded_attr(
    element.attributes,
    "colspan",
  )
  let rowspan = html_semantic_optional_bounded_attr(
    element.attributes,
    "rowspan",
  )
  let colspan_value = parse_html_semantic_positive_int_attr(colspan)
  let rowspan_value = parse_html_semantic_positive_int_attr(rowspan)
  let has_nested_table = html_semantic_block_descendants_contain_kind(
    ctx.blocks,
    cell_block_source_key,
    HtmlBlockKind::Table,
  )
  let has_image = html_semantic_block_has_image(
    ctx.images,
    cell_block_source_key,
  )
  let has_list = html_semantic_block_descendants_contain_list(
    ctx.blocks,
    cell_block_source_key,
  )
  let has_blockquote = html_semantic_block_descendants_contain_kind(
    ctx.blocks,
    cell_block_source_key,
    HtmlBlockKind::BlockQuote,
  )
  let has_pre = html_semantic_block_descendants_contain_pre(
    ctx.blocks,
    cell_block_source_key,
  )
  let has_figure = html_semantic_block_descendants_contain_kind(
    ctx.blocks,
    cell_block_source_key,
    HtmlBlockKind::Figure,
  )
  let has_unsupported_warning = html_semantic_warnings_have_unsupported(
    local_warnings,
  )
  let has_complex_block = direct_child_block_keys.length() != 0 ||
    has_nested_table ||
    has_list ||
    has_blockquote ||
    has_pre ||
    has_figure
  let text_complete = !text_truncated
  let safe_simple_cell_candidate = local_warnings.length() == 0 &&
    text_complete &&
    colspan_value == 1 &&
    rowspan_value == 1 &&
    !has_complex_block &&
    !has_image &&
    !has_unsupported_warning
  ctx.table_cells.push({
    source_key,
    table_source_key,
    section_source_key,
    row_source_key,
    block_source_key: cell_block_source_key,
    source_order,
    depth: clamp_html_semantic_depth(depth),
    row_index,
    cell_index,
    kind,
    tag_name: element.tag_name,
    colspan,
    rowspan,
    colspan_value,
    rowspan_value,
    headers: html_semantic_optional_bounded_attr(element.attributes, "headers"),
    scope: html_semantic_optional_bounded_attr(element.attributes, "scope"),
    inline_child_keys,
    direct_child_block_keys,
    text_complete,
    has_complex_block,
    has_nested_table,
    has_image,
    has_list,
    has_blockquote,
    has_pre,
    has_figure,
    has_unsupported_warning,
    safe_simple_cell_candidate,
    text_preview,
    attributes: attrs,
    span: element.span,
    warnings: local_warnings,
  })
  Some(source_key)
}

///|
fn collect_html_semantic_scope_fact(
  doc : HtmlDocument,
  ctx : HtmlSemanticCollectCtx,
) -> Unit {
  let body_count = html_semantic_count_elements_by_tag(doc.nodes, "body")
  let html_count = html_semantic_count_elements_by_tag(doc.nodes, "html")
  let html_node_key = html_semantic_first_dom_key_for_tag(doc.nodes, "html")
  let head_node_key = html_semantic_first_dom_key_for_tag(doc.nodes, "head")
  let body_node_key = html_semantic_first_block_key_by_tag(ctx.blocks, "body")
  let main_node_key = html_semantic_first_block_key_by_tag(ctx.blocks, "main")
  let article_node_key = html_semantic_first_block_key_by_tag(
    ctx.blocks,
    "article",
  )
  let selected_content_root_key = match body_node_key {
    Some(key) => Some(key)
    None =>
      match main_node_key {
        Some(key) => Some(key)
        None => article_node_key
      }
  }
  let scope_source = match body_node_key {
    Some(_) => HtmlDocumentScopeSource::Body
    None =>
      if html_count > 0 {
        HtmlDocumentScopeSource::DocumentRoot
      } else if doc.nodes.length() > 0 {
        HtmlDocumentScopeSource::Fragment
      } else {
        HtmlDocumentScopeSource::Heuristic
      }
  }
  let selected_scope_reason = match scope_source {
    HtmlDocumentScopeSource::Body => "body"
    HtmlDocumentScopeSource::Main => "main"
    HtmlDocumentScopeSource::Article => "article"
    HtmlDocumentScopeSource::DocumentRoot => "document_root"
    HtmlDocumentScopeSource::Fragment => "fragment"
    HtmlDocumentScopeSource::Heuristic => "heuristic"
  }
  let missing_body_warning = html_count > 0 && body_count == 0
  let multiple_body_warning = body_count > 1 || html_count > 1
  let malformed_root_warning = multiple_body_warning ||
    html_semantic_validation_has_malformed_root(doc.issues)
  let warnings : Array[HtmlSemanticWarning] = []
  if missing_body_warning {
    warnings.push(
      new_html_semantic_warning(
        HtmlSemanticWarningKind::MalformedDocumentScope,
        "html:scope:1",
        "body",
        "html semantic document scope is missing body",
      ),
    )
  }
  if multiple_body_warning {
    warnings.push(
      new_html_semantic_warning(
        HtmlSemanticWarningKind::MalformedDocumentScope,
        "html:scope:1",
        "body",
        "html semantic document scope has multiple body/html roots",
      ),
    )
  }
  if malformed_root_warning && warnings.length() == 0 {
    warnings.push(
      new_html_semantic_warning(
        HtmlSemanticWarningKind::MalformedDocumentScope,
        "html:scope:1",
        "",
        "html semantic document scope saw malformed root recovery",
      ),
    )
  }
  push_html_semantic_warnings(ctx, warnings)
  ctx.scope.push({
    source_key: "html:scope:1",
    html_node_key,
    head_node_key,
    body_node_key,
    selected_content_root_key,
    scope_source,
    title_text_preview: html_semantic_first_text_preview_for_tag(
      doc.nodes,
      "title",
    ),
    meta_charset: html_semantic_first_meta_charset(doc.nodes),
    meta_viewport: html_semantic_first_meta_named_content(doc.nodes, "viewport"),
    meta_description: html_semantic_first_meta_named_content(
      doc.nodes,
      "description",
    ),
    malformed_root_warning,
    multiple_body_warning,
    missing_body_warning,
    selected_scope_reason,
    noise_candidate_source_keys: html_semantic_noise_candidate_keys(
      ctx.noise_candidates,
    ),
    warnings,
  })
}

///|
fn collect_html_semantic_noise_candidate_fact(
  element : HtmlElement,
  ctx : HtmlSemanticCollectCtx,
  block_source_key : String?,
  parent_source_key : String?,
  source_order : Int,
  depth : Int,
  attributes : Array[HtmlSemanticAttributeSummary],
  text_preview : String,
) -> Unit {
  let reasons = html_semantic_noise_candidate_reasons(element)
  if reasons.length() == 0 {
    return
  }
  ctx.next_noise_order += 1
  let confidence = html_semantic_noise_confidence(element, reasons)
  ctx.noise_candidates.push({
    source_key: "html:noise:" + ctx.next_noise_order.to_string(),
    block_source_key,
    parent_source_key,
    tag_name: element.tag_name,
    source_order,
    depth: clamp_html_semantic_depth(depth),
    text_preview,
    attributes,
    reasons,
    confidence,
    span: element.span,
  })
}

///|
fn html_semantic_table_section_kind(tag_name : String) -> HtmlTableSectionKind? {
  match tag_name {
    "thead" => Some(HtmlTableSectionKind::Head)
    "tbody" => Some(HtmlTableSectionKind::Body)
    "tfoot" => Some(HtmlTableSectionKind::Foot)
    _ => None
  }
}

///|
fn html_semantic_table_cell_kind(tag_name : String) -> HtmlTableCellKind? {
  match tag_name {
    "th" => Some(HtmlTableCellKind::Header)
    "td" => Some(HtmlTableCellKind::Data)
    _ => None
  }
}

///|
fn find_html_semantic_direct_child_element(
  element : HtmlElement,
  tag_name : String,
) -> HtmlElement? {
  for child in element.children {
    match child {
      HtmlNode::Element(child_element) =>
        if child_element.tag_name == tag_name {
          return Some(child_element)
        }
      _ => ()
    }
  }
  None
}

///|
fn html_semantic_caption_source_key(
  table_source_key : String,
  caption : HtmlElement,
) -> String {
  table_source_key + ":caption:" + caption.span.line_start.to_string()
}

///|
fn html_semantic_inline_keys_for_block(
  inlines : Array[HtmlInlineFact],
  block_source_key : String,
) -> Array[String] {
  let out : Array[String] = []
  for inline in inlines {
    if inline.parent_block_source_key.unwrap_or("") == block_source_key &&
      inline.parent_inline_source_key is None {
      out.push(inline.source_key)
    }
  }
  out
}

///|
fn html_semantic_link_keys_for_block(
  links : Array[HtmlLinkFact],
  block_source_key : String,
) -> Array[String] {
  let out : Array[String] = []
  for link in links {
    if link.parent_block_source_key.unwrap_or("") == block_source_key {
      out.push(link.source_key)
    }
  }
  out
}

///|
fn html_semantic_image_keys_for_block(
  images : Array[HtmlImageFact],
  block_source_key : String,
) -> Array[String] {
  let out : Array[String] = []
  for image in images {
    if image.parent_block_source_key.unwrap_or("") == block_source_key {
      out.push(image.source_key)
    }
  }
  out
}

///|
fn html_semantic_image_keys_for_parent_inline(
  images : Array[HtmlImageFact],
  parent_inline_source_key : String,
) -> Array[String] {
  let out : Array[String] = []
  for image in images {
    if image.parent_inline_source_key == Some(parent_inline_source_key) {
      out.push(image.source_key)
    }
  }
  out
}

///|
fn html_semantic_link_key_for_inline(
  links : Array[HtmlLinkFact],
  inline_source_key : String?,
) -> String? {
  match inline_source_key {
    Some(key) => {
      for link in links {
        if link.inline_source_key == key {
          return Some(link.source_key)
        }
      }
      None
    }
    None => None
  }
}

///|
fn set_html_semantic_parent_link_source_key(
  images : Array[HtmlImageFact],
  parent_inline_source_key : String,
  link_source_key : String,
) -> Unit {
  for i in 0..<images.length() {
    let image = images[i]
    if image.parent_inline_source_key == Some(parent_inline_source_key) &&
      image.parent_link_source_key is None {
      images[i] = {
        source_key: image.source_key,
        inline_source_key: image.inline_source_key,
        parent_block_source_key: image.parent_block_source_key,
        parent_inline_source_key: image.parent_inline_source_key,
        parent_link_source_key: Some(link_source_key),
        src: image.src,
        srcset: image.srcset,
        alt: image.alt,
        title: image.title,
        width: image.width,
        height: image.height,
        loading: image.loading,
        decoding: image.decoding,
        picture_source_keys: image.picture_source_keys,
        alt_complete: image.alt_complete,
        title_complete: image.title_complete,
        kind: image.kind,
        span: image.span,
        warnings: image.warnings,
      }
    }
  }
}

///|
fn html_semantic_block_kind_for_key(
  blocks : Array[HtmlBlockFact],
  block_source_key : String,
) -> HtmlBlockKind? {
  for block in blocks {
    if block.source_key == block_source_key {
      return Some(block.kind)
    }
  }
  None
}

///|
fn html_semantic_parent_list_key(
  blocks : Array[HtmlBlockFact],
  parent_block_source_key : String?,
) -> String? {
  let mut current = parent_block_source_key
  while current is Some(key) {
    match html_semantic_block_for_key(blocks, key) {
      Some(block) =>
        match block.kind {
          HtmlBlockKind::List(_) =>
            return Some(html_semantic_list_source_key(block.source_order))
          _ => current = block.parent_source_key
        }
      None => current = None
    }
  }
  None
}

///|
fn html_semantic_parent_item_key(
  blocks : Array[HtmlBlockFact],
  items : Array[HtmlListItemFact],
  parent_block_source_key : String?,
) -> String? {
  let mut current = parent_block_source_key
  while current is Some(parent_key) {
    match html_semantic_block_for_key(blocks, parent_key) {
      Some(block) => {
        for item in items {
          if item.block_source_key == parent_key {
            return Some(item.source_key)
          }
        }
        if block.kind == HtmlBlockKind::ListItem {
          return Some(html_semantic_list_item_source_key(block.source_order))
        }
        current = block.parent_source_key
      }
      None => current = None
    }
  }
  None
}

///|
fn html_semantic_item_order_in_list(
  items : Array[HtmlListItemFact],
  list_source_key : String?,
) -> Int {
  let mut count = 0
  for item in items {
    if item.list_source_key == list_source_key {
      count += 1
    }
  }
  count
}

///|
fn html_semantic_list_depth(
  blocks : Array[HtmlBlockFact],
  block_source_key : String,
) -> Int {
  let mut depth = 0
  let mut current = Some(block_source_key)
  while current is Some(key) {
    match html_semantic_block_for_key(blocks, key) {
      Some(block) => {
        match block.kind {
          HtmlBlockKind::List(_) => depth += 1
          HtmlBlockKind::ListItem => ()
          _ => ()
        }
        current = block.parent_source_key
      }
      None => current = None
    }
  }
  depth
}

///|
fn html_semantic_quote_depth(
  blocks : Array[HtmlBlockFact],
  block_source_key : String,
) -> Int {
  let mut depth = 0
  let mut current = Some(block_source_key)
  while current is Some(key) {
    match html_semantic_block_for_key(blocks, key) {
      Some(block) => {
        if block.kind == HtmlBlockKind::BlockQuote {
          depth += 1
        }
        current = block.parent_source_key
      }
      None => current = None
    }
  }
  depth
}

///|
fn html_semantic_parent_quote_key(
  blocks : Array[HtmlBlockFact],
  parent_block_source_key : String?,
) -> String? {
  match parent_block_source_key {
    Some(parent_key) =>
      match html_semantic_block_for_key(blocks, parent_key) {
        Some(block) =>
          if block.kind == HtmlBlockKind::BlockQuote {
            Some(html_semantic_blockquote_source_key(block.source_order))
          } else {
            None
          }
        None => None
      }
    None => None
  }
}

///|
fn find_html_semantic_child_block_key_by_tag(
  blocks : Array[HtmlBlockFact],
  parent_block_source_key : String,
  tag_name : String,
) -> String? {
  for block in blocks {
    if block.parent_source_key.unwrap_or("") == parent_block_source_key &&
      block.tag_name == tag_name {
      return Some(block.source_key)
    }
  }
  None
}

///|
fn html_semantic_block_text_preview_for_key(
  blocks : Array[HtmlBlockFact],
  block_source_key : String,
) -> String? {
  match html_semantic_block_for_key(blocks, block_source_key) {
    Some(block) => Some(block.text_preview)
    None => None
  }
}

///|
fn html_semantic_block_for_key(
  blocks : Array[HtmlBlockFact],
  block_source_key : String,
) -> HtmlBlockFact? {
  for block in blocks {
    if block.source_key == block_source_key {
      return Some(block)
    }
  }
  None
}

///|
fn html_semantic_descendant_block_key_by_tag_index(
  blocks : Array[HtmlBlockFact],
  ancestor_block_source_key : String,
  tag_name : String,
  descendant_index : Int,
) -> String? {
  let mut seen = 0
  for block in blocks {
    if block.source_key != ancestor_block_source_key &&
      block.tag_name == tag_name {
      if html_semantic_nearest_table_ancestor_key(blocks, block.source_key) ==
        Some(ancestor_block_source_key) {
        if seen == descendant_index {
          return Some(block.source_key)
        }
        seen += 1
      }
    }
  }
  None
}

///|
fn html_semantic_nearest_table_ancestor_key(
  blocks : Array[HtmlBlockFact],
  source_key : String,
) -> String? {
  let mut current = html_semantic_parent_source_key_for_block(
    blocks, source_key,
  )
  while current is Some(key) {
    match html_semantic_block_for_key(blocks, key) {
      Some(block) =>
        if block.kind == HtmlBlockKind::Table {
          return Some(block.source_key)
        } else {
          current = block.parent_source_key
        }
      None => current = None
    }
  }
  None
}

///|
fn html_semantic_table_cell_block_key_by_index(
  blocks : Array[HtmlBlockFact],
  row_block_source_key : String,
  cell_index : Int,
) -> String? {
  let mut seen = 0
  for block in blocks {
    if block.parent_source_key.unwrap_or("") == row_block_source_key {
      match block.kind {
        HtmlBlockKind::TableCell(_) => {
          if seen == cell_index {
            return Some(block.source_key)
          }
          seen += 1
        }
        _ => ()
      }
    }
  }
  None
}

///|
fn html_semantic_direct_child_block_keys(
  blocks : Array[HtmlBlockFact],
  parent_block_source_key : String,
) -> Array[String] {
  let out : Array[String] = []
  for block in blocks {
    if block.parent_source_key.unwrap_or("") == parent_block_source_key {
      out.push(block.source_key)
    }
  }
  out
}

///|
fn parse_html_semantic_positive_int_attr(raw : String?) -> Int {
  match raw {
    Some(value) => {
      let trimmed = value.trim().to_owned()
      if trimmed == "" {
        return 1
      }
      let chars = trimmed.to_array()
      let mut i = 0
      let mut n = 0
      while i < chars.length() {
        let c = chars[i]
        let k = c.to_int()
        if k < 48 || k > 57 {
          return 1
        }
        n = n * 10 + (k - 48)
        i += 1
      }
      if n <= 0 {
        1
      } else {
        n
      }
    }
    None => 1
  }
}

///|
fn html_semantic_table_max_column_count(
  rows : Array[HtmlTableRowFact],
  row_source_keys : Array[String],
) -> Int {
  let mut max_count = 0
  for key in row_source_keys {
    for row in rows {
      if row.source_key == key && row.cell_count > max_count {
        max_count = row.cell_count
      }
    }
  }
  max_count
}

///|
fn html_semantic_table_has_ragged_rows(
  rows : Array[HtmlTableRowFact],
  row_source_keys : Array[String],
  max_column_count : Int,
) -> Bool {
  if max_column_count == 0 {
    return false
  }
  for key in row_source_keys {
    for row in rows {
      if row.source_key == key && row.cell_count != max_column_count {
        return true
      }
    }
  }
  false
}

///|
fn html_semantic_table_has_span(
  cells : Array[HtmlTableCellFact],
  cell_source_keys : Array[String],
) -> Bool {
  for key in cell_source_keys {
    for cell in cells {
      if cell.source_key == key &&
        (cell.colspan_value > 1 || cell.rowspan_value > 1) {
        return true
      }
    }
  }
  false
}

///|
fn html_semantic_table_has_complex_cell(
  cells : Array[HtmlTableCellFact],
  cell_source_keys : Array[String],
) -> Bool {
  for key in cell_source_keys {
    for cell in cells {
      if cell.source_key == key && !cell.safe_simple_cell_candidate {
        return true
      }
    }
  }
  false
}

///|
fn html_semantic_table_has_nested_table(
  blocks : Array[HtmlBlockFact],
  table_block_source_key : String,
) -> Bool {
  for block in blocks {
    if block.source_key != table_block_source_key &&
      block.kind == HtmlBlockKind::Table &&
      html_semantic_block_has_ancestor(
        blocks,
        block.source_key,
        table_block_source_key,
      ) {
      return true
    }
  }
  false
}

///|
fn html_semantic_table_span_cell_count(
  cells : Array[HtmlTableCellFact],
  cell_source_keys : Array[String],
) -> Int {
  let mut count = 0
  for key in cell_source_keys {
    for cell in cells {
      if cell.source_key == key &&
        (cell.colspan_value > 1 || cell.rowspan_value > 1) {
        count += 1
      }
    }
  }
  count
}

///|
fn html_semantic_table_ragged_row_count(
  rows : Array[HtmlTableRowFact],
  row_source_keys : Array[String],
  max_column_count : Int,
) -> Int {
  if max_column_count == 0 {
    return 0
  }
  let mut count = 0
  for key in row_source_keys {
    for row in rows {
      if row.source_key == key && row.cell_count != max_column_count {
        count += 1
      }
    }
  }
  count
}

///|
fn html_semantic_table_nested_cell_count(
  cells : Array[HtmlTableCellFact],
  cell_source_keys : Array[String],
) -> Int {
  let mut count = 0
  for key in cell_source_keys {
    for cell in cells {
      if cell.source_key == key && cell.has_nested_table {
        count += 1
      }
    }
  }
  count
}

///|
fn html_semantic_table_complex_cell_count(
  cells : Array[HtmlTableCellFact],
  cell_source_keys : Array[String],
) -> Int {
  let mut count = 0
  for key in cell_source_keys {
    for cell in cells {
      if cell.source_key == key && !cell.safe_simple_cell_candidate {
        count += 1
      }
    }
  }
  count
}

///|
fn html_semantic_table_image_cell_count(
  cells : Array[HtmlTableCellFact],
  cell_source_keys : Array[String],
) -> Int {
  let mut count = 0
  for key in cell_source_keys {
    for cell in cells {
      if cell.source_key == key && cell.has_image {
        count += 1
      }
    }
  }
  count
}

///|
fn html_semantic_table_block_child_cell_count(
  cells : Array[HtmlTableCellFact],
  cell_source_keys : Array[String],
) -> Int {
  let mut count = 0
  for key in cell_source_keys {
    for cell in cells {
      if cell.source_key == key && cell.direct_child_block_keys.length() > 0 {
        count += 1
      }
    }
  }
  count
}

///|
fn html_semantic_warning_kind_count(
  warnings : Array[HtmlSemanticWarning],
  kind : HtmlSemanticWarningKind,
) -> Int {
  let mut count = 0
  for warning in warnings {
    if warning.kind == kind {
      count += 1
    }
  }
  count
}

///|
fn html_semantic_block_has_image(
  images : Array[HtmlImageFact],
  block_source_key : String,
) -> Bool {
  for image in images {
    if image.parent_block_source_key == Some(block_source_key) {
      return true
    }
  }
  false
}

///|
fn html_semantic_block_descendants_contain_kind(
  blocks : Array[HtmlBlockFact],
  root_source_key : String,
  kind : HtmlBlockKind,
) -> Bool {
  for block in blocks {
    if block.kind == kind &&
      html_semantic_block_has_ancestor(
        blocks,
        block.source_key,
        root_source_key,
      ) {
      return true
    }
  }
  false
}

///|
fn html_semantic_block_descendants_contain_list(
  blocks : Array[HtmlBlockFact],
  root_source_key : String,
) -> Bool {
  for block in blocks {
    match block.kind {
      HtmlBlockKind::List(_) | HtmlBlockKind::ListItem =>
        if html_semantic_block_has_ancestor(
            blocks,
            block.source_key,
            root_source_key,
          ) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn html_semantic_block_descendants_contain_pre(
  blocks : Array[HtmlBlockFact],
  root_source_key : String,
) -> Bool {
  for block in blocks {
    match block.kind {
      HtmlBlockKind::Pre | HtmlBlockKind::CodeBlock =>
        if html_semantic_block_has_ancestor(
            blocks,
            block.source_key,
            root_source_key,
          ) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn html_semantic_block_has_ancestor(
  blocks : Array[HtmlBlockFact],
  source_key : String,
  ancestor_source_key : String,
) -> Bool {
  let mut current = html_semantic_parent_source_key_for_block(
    blocks, source_key,
  )
  while current is Some(key) {
    if key == ancestor_source_key {
      return true
    }
    current = html_semantic_parent_source_key_for_block(blocks, key)
  }
  false
}

///|
fn html_semantic_parent_source_key_for_block(
  blocks : Array[HtmlBlockFact],
  source_key : String,
) -> String? {
  for block in blocks {
    if block.source_key == source_key {
      return block.parent_source_key
    }
  }
  None
}

///|
fn html_semantic_warnings_have_unsupported(
  warnings : Array[HtmlSemanticWarning],
) -> Bool {
  for warning in warnings {
    match warning.kind {
      HtmlSemanticWarningKind::UnsupportedElement
      | HtmlSemanticWarningKind::UnsafeUrl
      | HtmlSemanticWarningKind::DataUriImage
      | HtmlSemanticWarningKind::RemoteImage
      | HtmlSemanticWarningKind::EmptyImageSource => return true
      _ => ()
    }
  }
  false
}

///|
fn html_semantic_parent_block_is_tag(
  blocks : Array[HtmlBlockFact],
  parent_block_source_key : String?,
  tag_name : String,
) -> Bool {
  match parent_block_source_key {
    Some(key) =>
      match html_semantic_block_for_key(blocks, key) {
        Some(block) => block.tag_name == tag_name
        None => false
      }
    None => false
  }
}

///|
fn html_semantic_language_hint_from_class(class_value : String) -> String? {
  for token in class_value.split(" ") {
    let trimmed = token.trim().to_owned()
    if trimmed.has_prefix("language-") && trimmed.length() > 9 {
      return Some(trimmed[9:].to_owned())
    }
    if trimmed.has_prefix("lang-") && trimmed.length() > 5 {
      return Some(trimmed[5:].to_owned())
    }
  }
  None
}

///|
fn html_semantic_block_kind(tag_name : String) -> HtmlBlockKind? {
  match tag_name {
    "h1" => Some(HtmlBlockKind::Heading(1))
    "h2" => Some(HtmlBlockKind::Heading(2))
    "h3" => Some(HtmlBlockKind::Heading(3))
    "h4" => Some(HtmlBlockKind::Heading(4))
    "h5" => Some(HtmlBlockKind::Heading(5))
    "h6" => Some(HtmlBlockKind::Heading(6))
    "p" => Some(HtmlBlockKind::Paragraph)
    "ul" => Some(HtmlBlockKind::List(false))
    "ol" => Some(HtmlBlockKind::List(true))
    "li" => Some(HtmlBlockKind::ListItem)
    "table" => Some(HtmlBlockKind::Table)
    "tr" => Some(HtmlBlockKind::TableRow)
    "th" => Some(HtmlBlockKind::TableCell(true))
    "td" => Some(HtmlBlockKind::TableCell(false))
    "blockquote" => Some(HtmlBlockKind::BlockQuote)
    "pre" => Some(HtmlBlockKind::Pre)
    "code" => Some(HtmlBlockKind::CodeBlock)
    "figure" => Some(HtmlBlockKind::Figure)
    "figcaption" => Some(HtmlBlockKind::FigCaption)
    "hr" => Some(HtmlBlockKind::HorizontalRule)
    _ =>
      if is_html_semantic_unsupported_tag(tag_name) {
        Some(HtmlBlockKind::UnsupportedBlock)
      } else if is_html_semantic_container_tag(tag_name) {
        Some(HtmlBlockKind::UnknownBlock)
      } else {
        None
      }
  }
}

///|
fn is_html_semantic_container_tag(tag_name : String) -> Bool {
  tag_name == "body" ||
  tag_name == "main" ||
  tag_name == "article" ||
  tag_name == "section" ||
  tag_name == "div" ||
  tag_name == "details" ||
  tag_name == "summary" ||
  tag_name == "header" ||
  tag_name == "footer" ||
  tag_name == "nav" ||
  tag_name == "aside" ||
  tag_name == "thead" ||
  tag_name == "tbody" ||
  tag_name == "tfoot"
}

///|
fn is_html_semantic_unsupported_tag(tag_name : String) -> Bool {
  html_semantic_unsupported_kind_for_tag(tag_name) is Some(_)
}

///|
fn html_semantic_unsupported_kind_for_tag(
  tag_name : String,
) -> HtmlUnsupportedKind? {
  match tag_name {
    "script" | "noscript" => Some(HtmlUnsupportedKind::Script)
    "style" => Some(HtmlUnsupportedKind::Style)
    "iframe" => Some(HtmlUnsupportedKind::Iframe)
    "embed" => Some(HtmlUnsupportedKind::Embed)
    "object" => Some(HtmlUnsupportedKind::Object)
    "svg" => Some(HtmlUnsupportedKind::Svg)
    "math" => Some(HtmlUnsupportedKind::Math)
    "template" => Some(HtmlUnsupportedKind::Template)
    "form" => Some(HtmlUnsupportedKind::Form)
    "input" => Some(HtmlUnsupportedKind::Input)
    "select" => Some(HtmlUnsupportedKind::Select)
    "textarea" => Some(HtmlUnsupportedKind::TextArea)
    "button" => Some(HtmlUnsupportedKind::Button)
    "video" => Some(HtmlUnsupportedKind::Video)
    "audio" => Some(HtmlUnsupportedKind::Audio)
    "source" => Some(HtmlUnsupportedKind::Source)
    "canvas" => Some(HtmlUnsupportedKind::Canvas)
    _ => None
  }
}

///|
fn html_semantic_unsupported_kind_for_link(
  kind : HtmlLinkKind,
) -> HtmlUnsupportedKind? {
  match kind {
    HtmlLinkKind::Data | HtmlLinkKind::Unsafe =>
      Some(HtmlUnsupportedKind::UnsafeUrl)
    HtmlLinkKind::Empty => Some(HtmlUnsupportedKind::EmptyUrl)
    _ => None
  }
}

///|
fn html_semantic_unsupported_kind_for_image(
  kind : HtmlImageKind,
) -> HtmlUnsupportedKind? {
  match kind {
    HtmlImageKind::Remote => Some(HtmlUnsupportedKind::RemoteImage)
    HtmlImageKind::DataUri => Some(HtmlUnsupportedKind::DataImage)
    HtmlImageKind::Unsafe => Some(HtmlUnsupportedKind::UnsafeUrl)
    HtmlImageKind::Empty => Some(HtmlUnsupportedKind::EmptyUrl)
    _ => None
  }
}

///|
fn html_semantic_unsupported_url_severity(
  kind : HtmlUnsupportedKind,
) -> HtmlWarningSeverity {
  match kind {
    HtmlUnsupportedKind::RemoteImage => HtmlWarningSeverity::Info
    HtmlUnsupportedKind::EmptyUrl => HtmlWarningSeverity::Info
    HtmlUnsupportedKind::DataImage => HtmlWarningSeverity::Warning
    HtmlUnsupportedKind::UnsafeUrl => HtmlWarningSeverity::Warning
    _ => HtmlWarningSeverity::Warning
  }
}

///|
fn html_semantic_unsupported_url_message(
  kind : HtmlUnsupportedKind,
  subject : String,
) -> String {
  match kind {
    HtmlUnsupportedKind::RemoteImage =>
      "html semantic " + subject + " references remote source"
    HtmlUnsupportedKind::DataImage =>
      "html semantic " + subject + " uses data uri source"
    HtmlUnsupportedKind::UnsafeUrl =>
      "html semantic " + subject + " has unsafe url"
    HtmlUnsupportedKind::EmptyUrl =>
      "html semantic " + subject + " has empty url"
    _ => "html semantic " + subject + " has unsupported url"
  }
}

///|
fn html_semantic_anchor_is_note_ref(element : HtmlElement) -> Bool {
  if html_semantic_attr_token_contains(
      element.attributes,
      "epub:type",
      "noteref",
    ) {
    return true
  }
  if html_semantic_attr_token_contains(
      element.attributes,
      "role",
      "doc-noteref",
    ) {
    return true
  }
  if html_semantic_attr_any_contains(
      element.attributes,
      ["class", "id"],
      "noteref",
    ) {
    return true
  }
  match html_semantic_attr_value(element.attributes, "href") {
    Some(href) => {
      let lower = href.to_lower()
      lower.has_prefix("#fn") ||
      lower.has_prefix("#footnote") ||
      lower.has_prefix("#endnote")
    }
    None => false
  }
}

///|
fn html_semantic_anchor_is_backref(element : HtmlElement) -> Bool {
  html_semantic_attr_token_contains(element.attributes, "epub:type", "backlink") ||
  html_semantic_attr_token_contains(element.attributes, "role", "doc-backlink") ||
  html_semantic_attr_any_contains(
    element.attributes,
    ["class", "id", "href"],
    "backref",
  )
}

///|
fn html_semantic_fragment_id_from_href(href : String) -> String? {
  let trimmed = href.trim().to_owned()
  if !trimmed.has_prefix("#") || trimmed.length() <= 1 {
    return None
  }
  let value = trimmed[1:].to_owned()
  if value == "" {
    None
  } else {
    Some(value)
  }
}

///|
fn html_semantic_note_body_kind(element : HtmlElement) -> HtmlNoteKind {
  if html_semantic_attr_token_contains(
      element.attributes,
      "epub:type",
      "footnote",
    ) ||
    html_semantic_attr_token_contains(
      element.attributes,
      "role",
      "doc-footnote",
    ) {
    return HtmlNoteKind::Footnote
  }
  if html_semantic_attr_token_contains(
      element.attributes,
      "epub:type",
      "endnote",
    ) ||
    html_semantic_attr_token_contains(element.attributes, "role", "doc-endnote") {
    return HtmlNoteKind::EndnoteLike
  }
  if html_semantic_attr_any_contains(
      element.attributes,
      ["class", "id"],
      "footnote",
    ) ||
    html_semantic_attr_any_contains(element.attributes, ["class", "id"], "fn") {
    return HtmlNoteKind::Footnote
  }
  if html_semantic_attr_any_contains(
      element.attributes,
      ["class", "id"],
      "endnote",
    ) {
    return HtmlNoteKind::EndnoteLike
  }
  HtmlNoteKind::Unknown
}

///|
fn html_semantic_note_body_id(element : HtmlElement) -> String? {
  match html_semantic_attr_value(element.attributes, "id") {
    Some(value) =>
      if value.trim() == "" {
        None
      } else {
        Some(value.trim().to_owned())
      }
    None =>
      match html_semantic_attr_value(element.attributes, "name") {
        Some(value) =>
          if value.trim() == "" {
            None
          } else {
            Some(value.trim().to_owned())
          }
        None => None
      }
  }
}

///|
fn html_semantic_note_body_id_seen(
  bodies : Array[HtmlNoteBodyFact],
  note_id : String,
) -> Bool {
  for body in bodies {
    if body.note_id == Some(note_id) {
      return true
    }
  }
  false
}

///|
fn html_semantic_note_body_for_id(
  bodies : Array[HtmlNoteBodyFact],
  note_id : String,
) -> HtmlNoteBodyFact? {
  for body in bodies {
    if body.note_id == Some(note_id) {
      return Some(body)
    }
  }
  None
}

///|
fn html_semantic_note_marker(children : Array[HtmlNode]) -> String? {
  let preview = html_semantic_text_preview(children).0
  let trimmed = preview.trim().to_owned()
  if trimmed == "" {
    None
  } else if trimmed.length() <= 12 {
    Some(trimmed)
  } else {
    Some(trimmed[0:12].to_owned())
  }
}

///|
fn html_semantic_noise_candidate_reasons(
  element : HtmlElement,
) -> Array[HtmlNoiseCandidateReason] {
  let reasons : Array[HtmlNoiseCandidateReason] = []
  if element.tag_name == "nav" ||
    html_semantic_attr_token_contains(element.attributes, "role", "navigation") ||
    html_semantic_attr_any_contains(element.attributes, ["class", "id"], "nav") ||
    html_semantic_attr_any_contains(element.attributes, ["class", "id"], "menu") {
    reasons.push(HtmlNoiseCandidateReason::NavLike)
  }
  if element.tag_name == "footer" ||
    html_semantic_attr_any_contains(
      element.attributes,
      ["class", "id"],
      "footer",
    ) ||
    html_semantic_attr_any_contains(
      element.attributes,
      ["class", "id"],
      "copyright",
    ) {
    reasons.push(HtmlNoiseCandidateReason::FooterLike)
  }
  if element.tag_name == "aside" ||
    html_semantic_attr_token_contains(
      element.attributes,
      "role",
      "complementary",
    ) ||
    html_semantic_attr_any_contains(
      element.attributes,
      ["class", "id"],
      "sidebar",
    ) ||
    html_semantic_attr_any_contains(element.attributes, ["class", "id"], "toc") ||
    html_semantic_attr_any_contains(
      element.attributes,
      ["class", "id"],
      "infobox",
    ) {
    reasons.push(HtmlNoiseCandidateReason::SidebarLike)
  }
  if html_semantic_has_attr(element.attributes, "hidden") ||
    html_semantic_attr_token_contains(element.attributes, "aria-hidden", "true") ||
    html_semantic_attr_any_contains(
      element.attributes,
      ["style"],
      "display:none",
    ) ||
    html_semantic_attr_any_contains(
      element.attributes,
      ["style"],
      "visibility:hidden",
    ) {
    reasons.push(HtmlNoiseCandidateReason::Hiddenish)
  }
  if element.tag_name == "script" ||
    element.tag_name == "style" ||
    element.tag_name == "template" {
    reasons.push(HtmlNoiseCandidateReason::ScriptStyleTemplate)
  }
  if html_semantic_attr_any_contains(
      element.attributes,
      ["class", "id"],
      "boilerplate",
    ) {
    reasons.push(HtmlNoiseCandidateReason::RepeatedBoilerplate)
  }
  reasons
}

///|
fn html_semantic_noise_confidence(
  element : HtmlElement,
  reasons : Array[HtmlNoiseCandidateReason],
) -> HtmlNoiseCandidateConfidence {
  if element.tag_name == "nav" ||
    element.tag_name == "footer" ||
    element.tag_name == "script" ||
    element.tag_name == "style" ||
    element.tag_name == "template" {
    return HtmlNoiseCandidateConfidence::High
  }
  if reasons.length() > 1 {
    HtmlNoiseCandidateConfidence::High
  } else {
    HtmlNoiseCandidateConfidence::Medium
  }
}

///|
fn html_semantic_noise_candidate_keys(
  facts : Array[HtmlNoiseCandidateFact],
) -> Array[String] {
  let out : Array[String] = []
  for fact in facts {
    out.push(fact.source_key)
  }
  out
}

///|
fn html_semantic_first_source_key(first : String?, second : String?) -> String? {
  match first {
    Some(value) => Some(value)
    None => second
  }
}

///|
fn html_semantic_source_key(tag_name : String, source_order : Int) -> String {
  "html:block:" + tag_name + ":" + source_order.to_string()
}

///|
fn html_semantic_inline_source_key(
  tag_name : String,
  source_order : Int,
) -> String {
  "html:inline:" + tag_name + ":" + source_order.to_string()
}

///|
fn html_semantic_list_source_key(source_order : Int) -> String {
  "html:list:" + source_order.to_string()
}

///|
fn html_semantic_list_item_source_key(source_order : Int) -> String {
  "html:list-item:" + source_order.to_string()
}

///|
fn html_semantic_blockquote_source_key(source_order : Int) -> String {
  "html:blockquote:" + source_order.to_string()
}

///|
fn html_semantic_attribute_summary(
  element : HtmlElement,
  source_key : String,
) -> (Array[HtmlSemanticAttributeSummary], Array[HtmlSemanticWarning]) {
  let out : Array[HtmlSemanticAttributeSummary] = []
  let warnings : Array[HtmlSemanticWarning] = []
  let mut i = 0
  for attr in element.attributes {
    if i >= HTML_SEMANTIC_ATTR_MAX_COUNT {
      warnings.push(
        new_html_semantic_warning(
          HtmlSemanticWarningKind::AttributeSummaryTruncated,
          source_key,
          element.tag_name,
          "html semantic attribute summary truncated for <" +
          element.tag_name +
          ">",
        ),
      )
      break
    }
    let (value_preview, truncated) = bounded_html_semantic_preview(
      attr.value,
      HTML_SEMANTIC_ATTR_VALUE_PREVIEW_MAX_CHARS,
    )
    if truncated {
      warnings.push(
        new_html_semantic_warning(
          HtmlSemanticWarningKind::AttributeValuePreviewTruncated,
          source_key,
          element.tag_name,
          "html semantic attribute value preview truncated for <" +
          element.tag_name +
          ">",
        ),
      )
    }
    out.push({
      name: attr.name,
      value_preview,
      quote_style: attr.quote_style,
      span: attr.span,
    })
    i += 1
  }
  (out, warnings)
}

///|
fn html_semantic_attr_value(
  attrs : Array[HtmlAttribute],
  name : String,
) -> String? {
  for attr in attrs {
    if attr.name == name {
      return Some(attr.value)
    }
  }
  None
}

///|
fn html_semantic_has_attr(attrs : Array[HtmlAttribute], name : String) -> Bool {
  for attr in attrs {
    if attr.name == name {
      return true
    }
  }
  false
}

///|
fn html_semantic_attr_preview_complete(
  attrs : Array[HtmlAttribute],
  name : String,
) -> Bool {
  match html_semantic_attr_value(attrs, name) {
    Some(value) =>
      value.trim().length() <= HTML_SEMANTIC_ATTR_VALUE_PREVIEW_MAX_CHARS
    None => true
  }
}

///|
fn html_semantic_attr_token_contains(
  attrs : Array[HtmlAttribute],
  name : String,
  token : String,
) -> Bool {
  match html_semantic_attr_value(attrs, name) {
    Some(value) => html_semantic_text_has_token(value, token)
    None => false
  }
}

///|
fn html_semantic_attr_any_contains(
  attrs : Array[HtmlAttribute],
  names : Array[String],
  needle : String,
) -> Bool {
  for name in names {
    match html_semantic_attr_value(attrs, name) {
      Some(value) => if value.to_lower().contains(needle) { return true }
      None => ()
    }
  }
  false
}

///|
fn html_semantic_text_has_token(value : String, token : String) -> Bool {
  let lower_token = token.to_lower()
  for raw in value.to_lower().split(" ") {
    let trimmed = raw.trim().to_owned()
    if trimmed == lower_token || trimmed.contains(lower_token) {
      return true
    }
  }
  false
}

///|
fn html_semantic_optional_bounded_attr(
  attrs : Array[HtmlAttribute],
  name : String,
) -> String? {
  match html_semantic_attr_value(attrs, name) {
    Some(value) => {
      let trimmed = value.trim().to_owned()
      if trimmed == "" {
        None
      } else {
        Some(
          bounded_html_semantic_preview(
            trimmed,
            HTML_SEMANTIC_ATTR_VALUE_PREVIEW_MAX_CHARS,
          ).0,
        )
      }
    }
    None => None
  }
}

///|
fn classify_html_semantic_link_kind(href : String) -> HtmlLinkKind {
  let trimmed = href.trim().to_owned()
  if trimmed == "" {
    return HtmlLinkKind::Empty
  }
  let lower = trimmed.to_lower()
  if lower.has_prefix("javascript:") || lower.has_prefix("vbscript:") {
    return HtmlLinkKind::Unsafe
  }
  if lower.has_prefix("data:") {
    return HtmlLinkKind::Data
  }
  if lower.has_prefix("#") || lower.has_prefix("/") {
    return HtmlLinkKind::Internal
  }
  if lower.has_prefix("mailto:") {
    return HtmlLinkKind::Mailto
  }
  if lower.has_prefix("tel:") {
    return HtmlLinkKind::Tel
  }
  if lower.has_prefix("http://") ||
    lower.has_prefix("https://") ||
    lower.has_prefix("//") {
    return HtmlLinkKind::External
  }
  HtmlLinkKind::Unknown
}

///|
fn classify_html_semantic_image_kind(src : String) -> HtmlImageKind {
  let trimmed = src.trim().to_owned()
  if trimmed == "" {
    return HtmlImageKind::Empty
  }
  let lower = trimmed.to_lower()
  if lower.has_prefix("javascript:") || lower.has_prefix("vbscript:") {
    return HtmlImageKind::Unsafe
  }
  if lower.has_prefix("data:") {
    return HtmlImageKind::DataUri
  }
  if lower.has_prefix("http://") ||
    lower.has_prefix("https://") ||
    lower.has_prefix("//") {
    return HtmlImageKind::Remote
  }
  if lower.has_prefix("/") {
    return HtmlImageKind::Unknown
  }
  HtmlImageKind::Local
}

///|
fn bounded_html_semantic_url(value : String) -> String {
  bounded_html_semantic_preview(
    value.trim().to_owned(),
    HTML_SEMANTIC_ATTR_VALUE_PREVIEW_MAX_CHARS,
  ).0
}

///|
fn push_html_semantic_warnings(
  ctx : HtmlSemanticCollectCtx,
  warnings : Array[HtmlSemanticWarning],
) -> Unit {
  for warning in warnings {
    ctx.warnings.push(warning)
  }
}

///|
fn new_html_semantic_warning(
  kind : HtmlSemanticWarningKind,
  source_key : String,
  tag_name : String,
  message : String,
) -> HtmlSemanticWarning {
  {
    kind,
    severity: html_semantic_warning_kind_severity(kind),
    source_key,
    tag_name,
    message,
  }
}

///|
fn html_semantic_warning_kind_severity(
  kind : HtmlSemanticWarningKind,
) -> HtmlWarningSeverity {
  match kind {
    HtmlSemanticWarningKind::TextPreviewTruncated => HtmlWarningSeverity::Info
    HtmlSemanticWarningKind::EmptyUrl => HtmlWarningSeverity::Info
    HtmlSemanticWarningKind::EmptyImageSource => HtmlWarningSeverity::Info
    HtmlSemanticWarningKind::RemoteImage => HtmlWarningSeverity::Info
    HtmlSemanticWarningKind::AttributeSummaryTruncated =>
      HtmlWarningSeverity::Warning
    HtmlSemanticWarningKind::AttributeValuePreviewTruncated =>
      HtmlWarningSeverity::Warning
    HtmlSemanticWarningKind::UnsupportedElement => HtmlWarningSeverity::Warning
    HtmlSemanticWarningKind::DepthLimitExceeded => HtmlWarningSeverity::Warning
    HtmlSemanticWarningKind::UnsafeUrl => HtmlWarningSeverity::Warning
    HtmlSemanticWarningKind::DataUriImage => HtmlWarningSeverity::Warning
    HtmlSemanticWarningKind::TableSizeLimitExceeded =>
      HtmlWarningSeverity::Warning
    HtmlSemanticWarningKind::MalformedTableStructure =>
      HtmlWarningSeverity::Warning
    HtmlSemanticWarningKind::BrokenNoteTarget => HtmlWarningSeverity::Warning
    HtmlSemanticWarningKind::MissingNoteTarget => HtmlWarningSeverity::Warning
    HtmlSemanticWarningKind::DuplicateNoteTarget => HtmlWarningSeverity::Warning
    HtmlSemanticWarningKind::MalformedDocumentScope =>
      HtmlWarningSeverity::Warning
  }
}

///|
fn push_html_semantic_unsupported_fact(
  ctx : HtmlSemanticCollectCtx,
  kind : HtmlUnsupportedKind,
  severity : HtmlWarningSeverity,
  related_source_key : String?,
  tag_name : String,
  source_order : Int,
  depth : Int,
  parent_source_key : String?,
  text_preview : String,
  attributes : Array[HtmlSemanticAttributeSummary],
  url : String?,
  span : HtmlSourceSpan,
  message : String,
) -> String {
  ctx.next_unsupported_order += 1
  let source_key = "html:unsupported:" + ctx.next_unsupported_order.to_string()
  ctx.unsupported.push({
    kind,
    severity,
    source_key,
    related_source_key,
    tag_name,
    source_order,
    depth: clamp_html_semantic_depth(depth),
    parent_source_key,
    text_preview: bounded_html_semantic_preview(
      text_preview,
      HTML_SEMANTIC_TEXT_PREVIEW_MAX_CHARS,
    ).0,
    attributes,
    url,
    span,
    message,
  })
  source_key
}

///|
fn push_html_semantic_guard_unsupported_facts(
  ctx : HtmlSemanticCollectCtx,
  warnings : Array[HtmlSemanticWarning],
  related_source_key : String,
  tag_name : String,
  source_order : Int,
  depth : Int,
  parent_source_key : String?,
  text_preview : String,
  attributes : Array[HtmlSemanticAttributeSummary],
  span : HtmlSourceSpan,
) -> Unit {
  for warning in warnings {
    match html_semantic_guard_unsupported_kind(warning.kind) {
      Some(kind) =>
        ignore(
          push_html_semantic_unsupported_fact(
            ctx,
            kind,
            warning.severity,
            Some(related_source_key),
            tag_name,
            source_order,
            depth,
            parent_source_key,
            text_preview,
            attributes,
            None,
            span,
            warning.message,
          ),
        )
      None => ()
    }
  }
}

///|
fn html_semantic_guard_unsupported_kind(
  kind : HtmlSemanticWarningKind,
) -> HtmlUnsupportedKind? {
  match kind {
    HtmlSemanticWarningKind::TextPreviewTruncated =>
      Some(HtmlUnsupportedKind::HugeTextNode)
    HtmlSemanticWarningKind::AttributeSummaryTruncated
    | HtmlSemanticWarningKind::AttributeValuePreviewTruncated =>
      Some(HtmlUnsupportedKind::HugeAttributeValue)
    HtmlSemanticWarningKind::DepthLimitExceeded =>
      Some(HtmlUnsupportedKind::DeepNesting)
    _ => None
  }
}

///|
fn clamp_html_semantic_depth(depth : Int) -> Int {
  if depth > HTML_SEMANTIC_MAX_DEPTH {
    HTML_SEMANTIC_MAX_DEPTH
  } else {
    depth
  }
}

///|
fn html_semantic_text_preview(children : Array[HtmlNode]) -> (String, Bool) {
  let out : Array[Char] = []
  let mut truncated = false
  for child in children {
    if append_html_semantic_text_preview(
        child,
        out,
        HTML_SEMANTIC_TEXT_PREVIEW_MAX_CHARS,
      ) {
      truncated = true
      break
    }
  }
  (normalize_html_semantic_preview(String::from_array(out)), truncated)
}

///|
fn html_semantic_whitespace_text_preview(
  children : Array[HtmlNode],
) -> (String, Bool) {
  let out : Array[Char] = []
  let mut truncated = false
  for child in children {
    if append_html_semantic_text_preview(
        child,
        out,
        HTML_SEMANTIC_TEXT_PREVIEW_MAX_CHARS,
      ) {
      truncated = true
      break
    }
  }
  (String::from_array(out), truncated)
}

///|
fn html_semantic_raw_text_preview(children : Array[HtmlNode]) -> (String, Bool) {
  let out : Array[Char] = []
  let mut truncated = false
  for child in children {
    if append_html_semantic_text_preview(
        child,
        out,
        HTML_SEMANTIC_TEXT_PREVIEW_MAX_CHARS,
      ) {
      truncated = true
      break
    }
  }
  (String::from_array(out), truncated)
}

///|
fn html_semantic_container_has_direct_text(children : Array[HtmlNode]) -> Bool {
  for child in children {
    match child {
      HtmlNode::Text(text) => if text.text.trim() != "" { return true }
      _ => ()
    }
  }
  false
}

///|
fn html_semantic_code_text(children : Array[HtmlNode]) -> (String, Bool) {
  let out : Array[Char] = []
  let mut truncated = false
  for child in children {
    if append_html_semantic_code_text(
        child,
        out,
        HTML_SEMANTIC_CODE_TEXT_MAX_CHARS,
      ) {
      truncated = true
      break
    }
  }
  (
    String::from_array(out)
    .replace(old="\r\n", new="\n")
    .replace(old="\r", new="\n")
    .trim()
    .to_owned(),
    truncated,
  )
}

///|
fn append_html_semantic_code_text(
  node : HtmlNode,
  out : Array[Char],
  max_chars : Int,
) -> Bool {
  if out.length() >= max_chars {
    return true
  }
  match node {
    HtmlNode::Text(text) =>
      append_html_semantic_preview_chars(out, text.text, max_chars)
    HtmlNode::Comment(comment) =>
      append_html_semantic_preview_chars(out, comment.text, max_chars)
    HtmlNode::Element(element) => {
      for child in element.children {
        if append_html_semantic_code_text(child, out, max_chars) {
          return true
        }
      }
      false
    }
    HtmlNode::Doctype(_) => false
  }
}

///|
fn append_html_semantic_text_preview(
  node : HtmlNode,
  out : Array[Char],
  max_chars : Int,
) -> Bool {
  if out.length() >= max_chars {
    return true
  }
  match node {
    HtmlNode::Text(text) =>
      append_html_semantic_preview_chars(out, text.text, max_chars)
    HtmlNode::Element(element) => {
      for child in element.children {
        if append_html_semantic_text_preview(child, out, max_chars) {
          return true
        }
      }
      false
    }
    _ => false
  }
}

///|
fn append_html_semantic_preview_chars(
  out : Array[Char],
  text : String,
  max_chars : Int,
) -> Bool {
  for ch in text {
    if out.length() >= max_chars {
      return true
    }
    out.push(ch)
  }
  false
}

///|
fn html_semantic_child_has_adjacent_text(
  children : Array[HtmlNode],
  index : Int,
) -> Bool {
  let before = if index > 0 {
    html_semantic_node_has_meaningful_text(children[index - 1])
  } else {
    false
  }
  let after = if index + 1 < children.length() {
    html_semantic_node_has_meaningful_text(children[index + 1])
  } else {
    false
  }
  before || after
}

///|
fn html_semantic_node_has_meaningful_text(node : HtmlNode) -> Bool {
  match node {
    HtmlNode::Text(text) => text.text.trim() != ""
    _ => false
  }
}

///|
fn html_semantic_count_elements_by_tag(
  nodes : Array[HtmlNode],
  tag_name : String,
) -> Int {
  let mut count = 0
  for node in nodes {
    match node {
      HtmlNode::Element(element) => {
        if element.tag_name == tag_name {
          count += 1
        }
        count += html_semantic_count_elements_by_tag(element.children, tag_name)
      }
      _ => ()
    }
  }
  count
}

///|
fn html_semantic_first_dom_key_for_tag(
  nodes : Array[HtmlNode],
  tag_name : String,
) -> String? {
  for node in nodes {
    match node {
      HtmlNode::Element(element) => {
        if element.tag_name == tag_name {
          return Some(
            "html:dom:" + tag_name + ":" + element.span.line_start.to_string(),
          )
        }
        match html_semantic_first_dom_key_for_tag(element.children, tag_name) {
          Some(key) => return Some(key)
          None => ()
        }
      }
      _ => ()
    }
  }
  None
}

///|
fn html_semantic_first_block_key_by_tag(
  blocks : Array[HtmlBlockFact],
  tag_name : String,
) -> String? {
  for block in blocks {
    if block.tag_name == tag_name {
      return Some(block.source_key)
    }
  }
  None
}

///|
fn html_semantic_first_text_preview_for_tag(
  nodes : Array[HtmlNode],
  tag_name : String,
) -> String? {
  for node in nodes {
    match node {
      HtmlNode::Element(element) => {
        if element.tag_name == tag_name {
          return Some(html_semantic_text_preview(element.children).0)
        }
        match
          html_semantic_first_text_preview_for_tag(element.children, tag_name) {
          Some(value) => return Some(value)
          None => ()
        }
      }
      _ => ()
    }
  }
  None
}

///|
fn html_semantic_first_meta_charset(nodes : Array[HtmlNode]) -> String? {
  match html_semantic_first_meta_attr(nodes, "charset", "") {
    Some(value) => Some(value)
    None => html_semantic_first_meta_named_content(nodes, "charset")
  }
}

///|
fn html_semantic_first_meta_named_content(
  nodes : Array[HtmlNode],
  name : String,
) -> String? {
  match html_semantic_first_meta_attr(nodes, "name", name) {
    Some(value) => Some(value)
    None => html_semantic_first_meta_attr(nodes, "property", name)
  }
}

///|
fn html_semantic_first_meta_attr(
  nodes : Array[HtmlNode],
  attr_name : String,
  attr_value : String,
) -> String? {
  for node in nodes {
    match node {
      HtmlNode::Element(element) => {
        if element.tag_name == "meta" {
          if attr_name == "charset" {
            match
              html_semantic_optional_bounded_attr(element.attributes, "charset") {
              Some(value) => return Some(value)
              None => ()
            }
          } else {
            let matches = match
              html_semantic_attr_value(element.attributes, attr_name) {
              Some(value) => value.to_lower() == attr_value.to_lower()
              None => false
            }
            if matches {
              match
                html_semantic_optional_bounded_attr(
                  element.attributes,
                  "content",
                ) {
                Some(value) => return Some(value)
                None => ()
              }
            }
          }
        }
        match
          html_semantic_first_meta_attr(element.children, attr_name, attr_value) {
          Some(value) => return Some(value)
          None => ()
        }
      }
      _ => ()
    }
  }
  None
}

///|
fn html_semantic_validation_has_malformed_root(
  issues : Array[HtmlValidationIssue],
) -> Bool {
  for issue in issues {
    match issue.kind {
      HtmlValidationIssueKind::UnclosedElement
      | HtmlValidationIssueKind::UnexpectedClosingTag
      | HtmlValidationIssueKind::MalformedTag => return true
      _ => ()
    }
  }
  false
}

///|
fn html_semantic_has_leading_whitespace(text : String) -> Bool {
  let chars = text.to_array()
  chars.length() > 0 && html_semantic_char_is_space(chars[0])
}

///|
fn html_semantic_has_trailing_whitespace(text : String) -> Bool {
  let chars = text.to_array()
  chars.length() > 0 && html_semantic_char_is_space(chars[chars.length() - 1])
}

///|
fn html_semantic_contains_newline(text : String) -> Bool {
  text.contains("\n") || text.contains("\r")
}

///|
fn html_semantic_contains_repeated_whitespace(text : String) -> Bool {
  let mut last_space = false
  for ch in text {
    let is_space = html_semantic_char_is_space(ch)
    if is_space && last_space {
      return true
    }
    last_space = is_space
  }
  false
}

///|
fn html_semantic_char_is_space(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}

///|
fn bounded_html_semantic_preview(
  text : String,
  max_chars : Int,
) -> (String, Bool) {
  let out : Array[Char] = []
  for ch in text {
    if out.length() >= max_chars {
      return (String::from_array(out), true)
    }
    out.push(ch)
  }
  (String::from_array(out), false)
}

///|
fn normalize_html_semantic_preview(text : String) -> String {
  let out : Array[Char] = []
  let mut last_space = false
  for ch in text {
    let is_space = ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
    if is_space {
      if !last_space && out.length() > 0 {
        out.push(' ')
        last_space = true
      }
    } else {
      out.push(ch)
      last_space = false
    }
  }
  let normalized = String::from_array(out).trim().to_owned()
  normalized
}
