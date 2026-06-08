///|
pub(all) struct HtmlParserIssueSummary {
  issue_count : Int
  warning_count : Int
  error_count : Int
  script_count : Int
  style_count : Int
  unsafe_url_count : Int
  duplicate_attribute_count : Int
  unexpected_closing_count : Int
  unclosed_element_count : Int
}

///|
pub(all) struct HtmlSemanticBlockSummary {
  block_count : Int
  heading_count : Int
  paragraph_count : Int
  list_count : Int
  list_item_count : Int
  table_count : Int
  table_row_count : Int
  table_cell_count : Int
  blockquote_count : Int
  pre_count : Int
  code_block_count : Int
  figure_count : Int
  figcaption_count : Int
  horizontal_rule_count : Int
  unknown_block_count : Int
  unsupported_block_count : Int
  inline_count : Int
  text_inline_count : Int
  emphasis_inline_count : Int
  strong_inline_count : Int
  code_inline_count : Int
  link_inline_count : Int
  image_inline_count : Int
  break_inline_count : Int
  span_inline_count : Int
  inline_container_count : Int
  unsupported_inline_count : Int
  unknown_inline_count : Int
  semantic_link_count : Int
  internal_link_count : Int
  external_link_count : Int
  mailto_link_count : Int
  tel_link_count : Int
  data_link_count : Int
  unsafe_link_count : Int
  empty_link_count : Int
  semantic_image_count : Int
  local_image_count : Int
  remote_image_count : Int
  data_uri_image_count : Int
  empty_image_count : Int
  unsafe_image_count : Int
  semantic_linked_image_count : Int
  semantic_image_in_link_count : Int
  semantic_note_ref_inline_count : Int
  semantic_srcset_image_count : Int
  semantic_picture_source_count : Int
  semantic_note_fact_count : Int
  semantic_note_ref_fact_count : Int
  semantic_note_body_fact_count : Int
  semantic_broken_note_ref_count : Int
  semantic_duplicate_note_body_count : Int
  semantic_backref_note_count : Int
  semantic_table_fact_count : Int
  semantic_table_section_count : Int
  semantic_table_head_section_count : Int
  semantic_table_body_section_count : Int
  semantic_table_foot_section_count : Int
  semantic_table_unknown_section_count : Int
  semantic_table_caption_count : Int
  semantic_table_fact_row_count : Int
  semantic_table_fact_cell_count : Int
  semantic_table_header_cell_count : Int
  semantic_table_data_cell_count : Int
  semantic_table_unknown_cell_count : Int
  semantic_max_table_row_count : Int
  semantic_max_table_cell_count : Int
  semantic_table_span_cell_count : Int
  semantic_table_ragged_row_count : Int
  semantic_table_nested_cell_count : Int
  semantic_table_complex_cell_count : Int
  semantic_table_image_cell_count : Int
  semantic_table_block_child_cell_count : Int
  semantic_table_malformed_warning_count : Int
  semantic_table_warning_count : Int
  semantic_scope_fact_count : Int
  semantic_scope_body_count : Int
  semantic_scope_main_count : Int
  semantic_scope_article_count : Int
  semantic_scope_document_root_count : Int
  semantic_scope_fragment_count : Int
  semantic_scope_heuristic_count : Int
  semantic_scope_missing_body_count : Int
  semantic_scope_multiple_body_count : Int
  semantic_scope_malformed_root_count : Int
  semantic_noise_candidate_count : Int
  semantic_noise_nav_like_count : Int
  semantic_noise_footer_like_count : Int
  semantic_noise_sidebar_like_count : Int
  semantic_noise_hiddenish_count : Int
  semantic_noise_script_style_template_count : Int
  semantic_noise_repeated_boilerplate_count : Int
  semantic_list_fact_count : Int
  semantic_ordered_list_fact_count : Int
  semantic_unordered_list_fact_count : Int
  semantic_list_item_fact_count : Int
  semantic_max_list_depth : Int
  semantic_blockquote_fact_count : Int
  semantic_max_quote_depth : Int
  semantic_code_block_fact_count : Int
  semantic_code_block_language_hint_count : Int
  semantic_figure_fact_count : Int
  semantic_figure_caption_count : Int
  semantic_figure_image_count : Int
  semantic_paragraph_fact_count : Int
  semantic_paragraph_with_link_count : Int
  semantic_paragraph_with_image_count : Int
  semantic_paragraph_with_code_count : Int
  semantic_paragraph_with_emphasis_count : Int
  semantic_paragraph_with_strong_count : Int
  semantic_paragraph_with_break_count : Int
  semantic_paragraph_meaningful_text_count : Int
  semantic_paragraph_candidate_count : Int
  semantic_paragraph_repeated_whitespace_count : Int
  semantic_paragraph_newline_count : Int
  semantic_whitespace_only_text_inline_count : Int
  semantic_leading_whitespace_inline_count : Int
  semantic_trailing_whitespace_inline_count : Int
  semantic_repeated_whitespace_inline_count : Int
  semantic_newline_inline_count : Int
  semantic_whitespace_preserving_inline_count : Int
  semantic_inline_with_surrounding_text_count : Int
  max_depth : Int
  warning_count : Int
  warning_info_count : Int
  warning_warning_count : Int
  warning_error_count : Int
  unsupported_fact_count : Int
  unsupported_info_count : Int
  unsupported_warning_count : Int
  unsupported_error_count : Int
  unsupported_script_count : Int
  unsupported_style_count : Int
  unsupported_iframe_count : Int
  unsupported_embed_count : Int
  unsupported_object_count : Int
  unsupported_svg_count : Int
  unsupported_math_count : Int
  unsupported_template_count : Int
  unsupported_form_count : Int
  unsupported_input_count : Int
  unsupported_select_count : Int
  unsupported_textarea_count : Int
  unsupported_button_count : Int
  unsupported_video_count : Int
  unsupported_audio_count : Int
  unsupported_source_count : Int
  unsupported_canvas_count : Int
  unsupported_remote_image_count : Int
  unsupported_data_image_count : Int
  unsupported_unsafe_url_count : Int
  unsupported_empty_url_count : Int
  unsupported_broken_local_image_count : Int
  unsupported_charset_count : Int
  unsupported_huge_text_node_count : Int
  unsupported_huge_attribute_value_count : Int
  unsupported_deep_nesting_count : Int
  unsupported_huge_table_count : Int
  unsupported_malformed_tag_count : Int
  unsupported_unknown_count : Int
}

///|
priv struct HtmlParserSourceAnalysis {
  text : String
  events : Array[@dphtml.HtmlTokenEvent]
  summary : HtmlParserIssueSummary?
  semantic_summary : HtmlSemanticBlockSummary?
}

///|
priv struct HtmlSourceRange {
  start : Int
  end_ : Int
}

///|
priv struct HtmlByteRange {
  start : Int
  end_ : Int
}

///|
priv struct HtmlScopedContent {
  bytes : Bytes
  skip_ranges : Array[HtmlByteRange]
  scope_from_events : Bool
  scope_fallback_reason : String
}

///|
priv struct HtmlProfileBlockCounts {
  table_count : Int
  image_count : Int
  link_count : Int
  note_ref_count : Int
}

///|
/// HTML converter entrypoint.
///
/// Model boundary:
/// - uses a lightweight DOM-like semantic scan (not browser layout engine)
/// - focuses on robust structural blocks for markdown + metadata sidecar
/// - keeps provenance lightweight at block/asset level
pub fn parse_html(
  input_path : String,
  out_dir : String,
  max_heading : Int,
) -> @cor.Document raise {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("html: file not found: " + input_path)
  }

  let profile = if html_profile_enabled() {
    Some(new_html_profile_report(input_path))
  } else {
    None
  }

  let read_started = html_profile_start_tick(profile)
  let raw_bs = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("html: read failed: " + e.to_string())
  }
  html_profile_add_stage(
    profile,
    "html_file_read",
    html_profile_elapsed_since(read_started),
    match profile {
      Some(_) => Some("bytes=" + raw_bs.length().to_string())
      None => None
    },
  )

  let normalize_started = html_profile_start_tick(profile)
  let bs = normalize_html_input_bytes(raw_bs)
  let parser_analysis = maybe_analyze_html_source(bs, profile)
  let scoped_content = narrow_html_content_scope(bs, parser_analysis)
  let scoped_bs = scoped_content.bytes
  html_profile_set_scope_observability(
    profile,
    scoped_content.scope_from_events,
    scoped_content.skip_ranges.length(),
    scoped_content.scope_fallback_reason,
  )
  html_profile_add_stage(
    profile,
    "html_normalize_bytes",
    html_profile_elapsed_since(normalize_started),
    match profile {
      Some(_) =>
        Some(
          "bytes=" +
          bs.length().to_string() +
          " scoped_bytes=" +
          scoped_bs.length().to_string(),
        )
      None => None
    },
  )

  let doc = @cor.new_document()
  let note_definitions = scan_html_notes(scoped_bs)

  html_profile_set_active(profile)
  defer html_profile_set_active(None)

  let scan_started = html_profile_start_tick(profile)
  let nodes = scan_html_nodes_with_skip_ranges(
    scoped_bs,
    scoped_content.skip_ranges,
  )
  html_profile_add_stage(
    profile,
    "html_dom_scan",
    html_profile_elapsed_since(scan_started),
    match profile {
      Some(_) => Some("nodes=" + nodes.length().to_string())
      None => None
    },
  )
  html_profile_add_stage(
    profile,
    "html_parser_validation",
    0,
    match profile {
      Some(_) =>
        match parser_analysis {
          Some(analysis) =>
            analysis.summary.map(fn(summary) {
              render_html_parser_issue_summary_detail(summary) +
              render_html_semantic_block_summary_detail(
                analysis.semantic_summary,
              )
            })
          None => render_html_parser_analysis_fallback_detail(bs)
        }
      None => None
    },
  )

  let lowering_started = html_profile_start_tick(profile)
  let semantic_lowering_state = build_html_semantic_lowering_state_from_bytes(
    scoped_bs,
  )
  let html_blocks = nodes_to_blocks(
    nodes, max_heading, input_path, out_dir, semantic_lowering_state,
  )
  html_profile_add_stage(
    profile,
    "html_block_lowering",
    html_profile_elapsed_since(lowering_started),
    match profile {
      Some(rep) =>
        Some(
          render_html_block_lowering_profile_detail(
            html_blocks.blocks,
            note_definitions.length(),
            rep,
            semantic_lowering_state,
          ),
        )
      None => None
    },
  )
  let blocks = html_blocks.blocks
  let src = @cor.basename(input_path)
  let mut asset_idx = 0

  for i in 0..<blocks.length() {
    match blocks[i] {
      @cor.Block::Image(_alt, path) => {
        asset_idx = asset_idx + 1
        @cor.set_asset_origin(doc, path, {
          source_name: Some(src),
          page: None,
          slide: None,
          sheet: None,
          origin_id: Some("html-asset-" + asset_idx.to_string()),
          nearby_caption: None,
          object_ref: None,
          relationship_id: None,
          source_path: html_blocks.asset_source_paths.get(path),
          row_index: None,
          column_index: None,
          key_path: html_blocks.block_origins[i].map(fn(origin) {
            origin.key_path.unwrap_or("")
          }),
        })
      }
      @cor.Block::ImageBlock(img) => {
        asset_idx = asset_idx + 1
        @cor.set_asset_origin(doc, img.path, {
          source_name: Some(src),
          page: None,
          slide: None,
          sheet: None,
          origin_id: Some("html-asset-" + asset_idx.to_string()),
          nearby_caption: img.caption,
          object_ref: None,
          relationship_id: None,
          source_path: html_blocks.asset_source_paths.get(img.path),
          row_index: None,
          column_index: None,
          key_path: html_blocks.block_origins[i].map(fn(origin) {
            origin.key_path.unwrap_or("")
          }),
        })
      }
      _ => ()
    }

    @cor.push_with_origin(
      doc,
      blocks[i],
      html_block_origin_with_index(
        html_blocks.block_origins[i],
        src,
        doc.blocks.val.length(),
      ),
    )
  }

  for note in note_definitions {
    @cor.push_note_definition(doc, note)
  }

  html_profile_add_stage(
    profile,
    "html_asset_discovery",
    match profile {
      Some(rep) => rep.asset_discovery_elapsed_ms.val
      None => 0
    },
    match profile {
      Some(rep) =>
        Some(
          "local_asset_count=" +
          rep.local_asset_count.val.to_string() +
          " remote_asset_count=" +
          rep.remote_asset_count.val.to_string() +
          " unresolved_local_asset_count=" +
          rep.unresolved_local_asset_count.val.to_string(),
        )
      None => None
    },
  )
  html_profile_add_stage(
    profile,
    "html_asset_export",
    match profile {
      Some(rep) => rep.asset_export_elapsed_ms.val
      None => 0
    },
    match profile {
      Some(rep) =>
        Some(
          "local_asset_count=" +
          rep.local_asset_count.val.to_string() +
          " cached_asset_count=" +
          rep.cached_asset_count.val.to_string(),
        )
      None => None
    },
  )
  html_profile_add_stage(
    profile,
    "html_document_build",
    0,
    match profile {
      Some(_) => Some("blocks=" + doc.blocks.val.length().to_string())
      None => None
    },
  )

  maybe_write_html_profile_log(profile)
  doc
}

///|
fn maybe_analyze_html_source(
  bs : Bytes,
  profile : HtmlProfileReport?,
) -> HtmlParserSourceAnalysis? {
  html_profile_mark_parser_analysis_attempted(profile)
  if bs.length() > HTML_PARSER_VALIDATION_MAX_BYTES {
    html_profile_mark_parser_skipped_large_input(profile)
    return None
  }

  let text = @utf8.decode(bs, ignore_bom=false) catch {
    _ => {
      html_profile_mark_parser_fallback(profile)
      return None
    }
  }

  let analyzed = try? @dphtml.analyze_html_source(text)
  match analyzed {
    Ok(analysis) => {
      let summary = match profile {
        Some(_) => {
          let validation = @dphtml.validate_html_document(analysis.document)
          let summary = summarize_html_parser_validation(validation)
          html_profile_set_parser_issue_summary(profile, summary)
          Some(summary)
        }
        None => None
      }
      let semantic_summary = match profile {
        Some(_) =>
          Some(
            summarize_html_semantic_blocks(
              @dphtml.inspect_html_semantic_document(
                @dphtml.collect_html_semantic_document(analysis.document),
              ),
            ),
          )
        None => None
      }
      html_profile_mark_parser_analysis_used(profile)
      Some({ text, events: analysis.events, summary, semantic_summary })
    }
    Err(_) => {
      html_profile_mark_parser_fallback(profile)
      None
    }
  }
}

///|
fn render_html_parser_analysis_fallback_detail(bs : Bytes) -> String? {
  if bs.length() > HTML_PARSER_VALIDATION_MAX_BYTES {
    Some("status=skipped_large_input bytes=" + bs.length().to_string())
  } else {
    Some("status=fallback_parse_error")
  }
}

///|
pub fn summarize_html_parser_validation(
  validation : @dphtml.HtmlValidationReport,
) -> HtmlParserIssueSummary {
  let mut script_count = 0
  let mut style_count = 0
  let mut unsafe_url_count = 0
  let mut duplicate_attribute_count = 0
  let mut unexpected_closing_count = 0
  let mut unclosed_element_count = 0

  for issue in validation.issues {
    match issue.kind {
      @dphtml.HtmlValidationIssueKind::ScriptElement => script_count += 1
      @dphtml.HtmlValidationIssueKind::StyleElement => style_count += 1
      @dphtml.HtmlValidationIssueKind::UnsafeUrl => unsafe_url_count += 1
      @dphtml.HtmlValidationIssueKind::DuplicateAttribute =>
        duplicate_attribute_count += 1
      @dphtml.HtmlValidationIssueKind::UnexpectedClosingTag =>
        unexpected_closing_count += 1
      @dphtml.HtmlValidationIssueKind::UnclosedElement =>
        unclosed_element_count += 1
      _ => ()
    }
  }

  {
    issue_count: validation.issue_count,
    warning_count: validation.warning_count,
    error_count: validation.error_count,
    script_count,
    style_count,
    unsafe_url_count,
    duplicate_attribute_count,
    unexpected_closing_count,
    unclosed_element_count,
  }
}

///|
pub fn collect_html_parser_issue_summary_from_text(
  text : String,
) -> HtmlParserIssueSummary? {
  let parsed = try? @dphtml.parse_html_document(text)
  match parsed {
    Ok(doc) =>
      Some(
        summarize_html_parser_validation(@dphtml.validate_html_document(doc)),
      )
    Err(_) => None
  }
}

///|
pub fn collect_html_semantic_block_summary_from_text(
  text : String,
) -> HtmlSemanticBlockSummary? {
  let parsed = try? @dphtml.parse_html_document(text)
  match parsed {
    Ok(doc) =>
      Some(
        summarize_html_semantic_blocks(
          @dphtml.inspect_html_semantic_document(
            @dphtml.collect_html_semantic_document(doc),
          ),
        ),
      )
    Err(_) => None
  }
}

///|
pub fn collect_html_semantic_inline_summary_from_text(
  text : String,
) -> HtmlSemanticBlockSummary? {
  collect_html_semantic_block_summary_from_text(text)
}

///|
pub fn collect_html_semantic_paragraph_summary_from_text(
  text : String,
) -> HtmlSemanticBlockSummary? {
  collect_html_semantic_block_summary_from_text(text)
}

///|
pub fn collect_html_semantic_table_summary_from_text(
  text : String,
) -> HtmlSemanticBlockSummary? {
  collect_html_semantic_block_summary_from_text(text)
}

///|
pub fn collect_html_semantic_polished_summary_from_text(
  text : String,
) -> HtmlSemanticBlockSummary? {
  collect_html_semantic_block_summary_from_text(text)
}

///|
pub fn collect_html_semantic_warning_summary_from_text(
  text : String,
) -> HtmlSemanticBlockSummary? {
  collect_html_semantic_block_summary_from_text(text)
}

///|
pub fn collect_html_semantic_note_summary_from_text(
  text : String,
) -> HtmlSemanticBlockSummary? {
  collect_html_semantic_block_summary_from_text(text)
}

///|
pub fn collect_html_semantic_scope_summary_from_text(
  text : String,
) -> HtmlSemanticBlockSummary? {
  collect_html_semantic_block_summary_from_text(text)
}

///|
pub fn collect_html_semantic_noise_summary_from_text(
  text : String,
) -> HtmlSemanticBlockSummary? {
  collect_html_semantic_block_summary_from_text(text)
}

///|
pub fn collect_html_semantic_complex_inline_summary_from_text(
  text : String,
) -> HtmlSemanticBlockSummary? {
  collect_html_semantic_block_summary_from_text(text)
}

///|
pub fn summarize_html_semantic_blocks(
  report : @dphtml.HtmlSemanticInspectReport,
) -> HtmlSemanticBlockSummary {
  {
    block_count: report.block_count,
    heading_count: report.heading_count,
    paragraph_count: report.paragraph_count,
    list_count: report.list_count,
    list_item_count: report.list_item_count,
    table_count: report.table_count,
    table_row_count: report.table_row_count,
    table_cell_count: report.table_cell_count,
    blockquote_count: report.blockquote_count,
    pre_count: report.pre_count,
    code_block_count: report.code_block_count,
    figure_count: report.figure_count,
    figcaption_count: report.figcaption_count,
    horizontal_rule_count: report.horizontal_rule_count,
    unknown_block_count: report.unknown_block_count,
    unsupported_block_count: report.unsupported_block_count,
    inline_count: report.inline_count,
    text_inline_count: report.text_inline_count,
    emphasis_inline_count: report.emphasis_inline_count,
    strong_inline_count: report.strong_inline_count,
    code_inline_count: report.code_inline_count,
    link_inline_count: report.link_inline_count,
    image_inline_count: report.image_inline_count,
    break_inline_count: report.break_inline_count,
    span_inline_count: report.span_inline_count,
    inline_container_count: report.inline_container_count,
    unsupported_inline_count: report.unsupported_inline_count,
    unknown_inline_count: report.unknown_inline_count,
    semantic_link_count: report.link_count,
    internal_link_count: report.internal_link_count,
    external_link_count: report.external_link_count,
    mailto_link_count: report.mailto_link_count,
    tel_link_count: report.tel_link_count,
    data_link_count: report.data_link_count,
    unsafe_link_count: report.unsafe_link_count,
    empty_link_count: report.empty_link_count,
    semantic_image_count: report.image_count,
    local_image_count: report.local_image_count,
    remote_image_count: report.remote_image_count,
    data_uri_image_count: report.data_uri_image_count,
    empty_image_count: report.empty_image_count,
    unsafe_image_count: report.unsafe_image_count,
    semantic_linked_image_count: report.linked_image_count,
    semantic_image_in_link_count: report.image_in_link_count,
    semantic_note_ref_inline_count: report.note_ref_inline_count,
    semantic_srcset_image_count: report.srcset_image_count,
    semantic_picture_source_count: report.picture_source_count,
    semantic_note_fact_count: report.note_fact_count,
    semantic_note_ref_fact_count: report.note_ref_fact_count,
    semantic_note_body_fact_count: report.note_body_fact_count,
    semantic_broken_note_ref_count: report.broken_note_ref_count,
    semantic_duplicate_note_body_count: report.duplicate_note_body_count,
    semantic_backref_note_count: report.backref_note_count,
    semantic_table_fact_count: report.table_fact_count,
    semantic_table_section_count: report.table_section_count,
    semantic_table_head_section_count: report.table_head_section_count,
    semantic_table_body_section_count: report.table_body_section_count,
    semantic_table_foot_section_count: report.table_foot_section_count,
    semantic_table_unknown_section_count: report.table_unknown_section_count,
    semantic_table_caption_count: report.table_caption_count,
    semantic_table_fact_row_count: report.table_fact_row_count,
    semantic_table_fact_cell_count: report.table_fact_cell_count,
    semantic_table_header_cell_count: report.table_header_cell_count,
    semantic_table_data_cell_count: report.table_data_cell_count,
    semantic_table_unknown_cell_count: report.table_unknown_cell_count,
    semantic_max_table_row_count: report.max_table_row_count,
    semantic_max_table_cell_count: report.max_table_cell_count,
    semantic_table_span_cell_count: report.table_span_cell_count,
    semantic_table_ragged_row_count: report.table_ragged_row_count,
    semantic_table_nested_cell_count: report.table_nested_cell_count,
    semantic_table_complex_cell_count: report.table_complex_cell_count,
    semantic_table_image_cell_count: report.table_image_cell_count,
    semantic_table_block_child_cell_count: report.table_block_child_cell_count,
    semantic_table_malformed_warning_count: report.table_malformed_warning_count,
    semantic_table_warning_count: report.table_warning_count,
    semantic_scope_fact_count: report.scope_fact_count,
    semantic_scope_body_count: report.scope_body_count,
    semantic_scope_main_count: report.scope_main_count,
    semantic_scope_article_count: report.scope_article_count,
    semantic_scope_document_root_count: report.scope_document_root_count,
    semantic_scope_fragment_count: report.scope_fragment_count,
    semantic_scope_heuristic_count: report.scope_heuristic_count,
    semantic_scope_missing_body_count: report.scope_missing_body_count,
    semantic_scope_multiple_body_count: report.scope_multiple_body_count,
    semantic_scope_malformed_root_count: report.scope_malformed_root_count,
    semantic_noise_candidate_count: report.noise_candidate_count,
    semantic_noise_nav_like_count: report.noise_nav_like_count,
    semantic_noise_footer_like_count: report.noise_footer_like_count,
    semantic_noise_sidebar_like_count: report.noise_sidebar_like_count,
    semantic_noise_hiddenish_count: report.noise_hiddenish_count,
    semantic_noise_script_style_template_count: report.noise_script_style_template_count,
    semantic_noise_repeated_boilerplate_count: report.noise_repeated_boilerplate_count,
    semantic_list_fact_count: report.list_fact_count,
    semantic_ordered_list_fact_count: report.ordered_list_fact_count,
    semantic_unordered_list_fact_count: report.unordered_list_fact_count,
    semantic_list_item_fact_count: report.list_item_fact_count,
    semantic_max_list_depth: report.max_list_depth,
    semantic_blockquote_fact_count: report.blockquote_fact_count,
    semantic_max_quote_depth: report.max_quote_depth,
    semantic_code_block_fact_count: report.code_block_fact_count,
    semantic_code_block_language_hint_count: report.code_block_language_hint_count,
    semantic_figure_fact_count: report.figure_fact_count,
    semantic_figure_caption_count: report.figure_caption_count,
    semantic_figure_image_count: report.figure_image_count,
    semantic_paragraph_fact_count: report.paragraph_fact_count,
    semantic_paragraph_with_link_count: report.paragraph_with_link_count,
    semantic_paragraph_with_image_count: report.paragraph_with_image_count,
    semantic_paragraph_with_code_count: report.paragraph_with_code_count,
    semantic_paragraph_with_emphasis_count: report.paragraph_with_emphasis_count,
    semantic_paragraph_with_strong_count: report.paragraph_with_strong_count,
    semantic_paragraph_with_break_count: report.paragraph_with_break_count,
    semantic_paragraph_meaningful_text_count: report.paragraph_meaningful_text_count,
    semantic_paragraph_candidate_count: report.paragraph_candidate_count,
    semantic_paragraph_repeated_whitespace_count: report.paragraph_repeated_whitespace_count,
    semantic_paragraph_newline_count: report.paragraph_newline_count,
    semantic_whitespace_only_text_inline_count: report.whitespace_only_text_inline_count,
    semantic_leading_whitespace_inline_count: report.leading_whitespace_inline_count,
    semantic_trailing_whitespace_inline_count: report.trailing_whitespace_inline_count,
    semantic_repeated_whitespace_inline_count: report.repeated_whitespace_inline_count,
    semantic_newline_inline_count: report.newline_inline_count,
    semantic_whitespace_preserving_inline_count: report.whitespace_preserving_inline_count,
    semantic_inline_with_surrounding_text_count: report.inline_with_surrounding_text_count,
    max_depth: report.max_depth,
    warning_count: report.warning_count,
    warning_info_count: report.warning_info_count,
    warning_warning_count: report.warning_warning_count,
    warning_error_count: report.warning_error_count,
    unsupported_fact_count: report.unsupported_fact_count,
    unsupported_info_count: report.unsupported_info_count,
    unsupported_warning_count: report.unsupported_warning_count,
    unsupported_error_count: report.unsupported_error_count,
    unsupported_script_count: report.unsupported_script_count,
    unsupported_style_count: report.unsupported_style_count,
    unsupported_iframe_count: report.unsupported_iframe_count,
    unsupported_embed_count: report.unsupported_embed_count,
    unsupported_object_count: report.unsupported_object_count,
    unsupported_svg_count: report.unsupported_svg_count,
    unsupported_math_count: report.unsupported_math_count,
    unsupported_template_count: report.unsupported_template_count,
    unsupported_form_count: report.unsupported_form_count,
    unsupported_input_count: report.unsupported_input_count,
    unsupported_select_count: report.unsupported_select_count,
    unsupported_textarea_count: report.unsupported_textarea_count,
    unsupported_button_count: report.unsupported_button_count,
    unsupported_video_count: report.unsupported_video_count,
    unsupported_audio_count: report.unsupported_audio_count,
    unsupported_source_count: report.unsupported_source_count,
    unsupported_canvas_count: report.unsupported_canvas_count,
    unsupported_remote_image_count: report.unsupported_remote_image_count,
    unsupported_data_image_count: report.unsupported_data_image_count,
    unsupported_unsafe_url_count: report.unsupported_unsafe_url_count,
    unsupported_empty_url_count: report.unsupported_empty_url_count,
    unsupported_broken_local_image_count: report.unsupported_broken_local_image_count,
    unsupported_charset_count: report.unsupported_charset_count,
    unsupported_huge_text_node_count: report.unsupported_huge_text_node_count,
    unsupported_huge_attribute_value_count: report.unsupported_huge_attribute_value_count,
    unsupported_deep_nesting_count: report.unsupported_deep_nesting_count,
    unsupported_huge_table_count: report.unsupported_huge_table_count,
    unsupported_malformed_tag_count: report.unsupported_malformed_tag_count,
    unsupported_unknown_count: report.unsupported_unknown_count,
  }
}

///|
fn render_html_block_lowering_profile_detail(
  blocks : Array[@cor.Block],
  note_definition_count : Int,
  report : HtmlProfileReport,
  semantic_lowering_state : HtmlSemanticLoweringState?,
) -> String {
  let counts = count_html_profile_blocks(blocks)
  let detail = "blocks=" +
    blocks.length().to_string() +
    " table_count=" +
    counts.table_count.to_string() +
    " image_count=" +
    counts.image_count.to_string() +
    " link_count=" +
    counts.link_count.to_string() +
    " note_definition_count=" +
    note_definition_count.to_string() +
    " note_ref_count=" +
    counts.note_ref_count.to_string() +
    " local_asset_count=" +
    report.local_asset_count.val.to_string() +
    " remote_asset_count=" +
    report.remote_asset_count.val.to_string() +
    " unresolved_local_asset_count=" +
    report.unresolved_local_asset_count.val.to_string() +
    " cached_asset_count=" +
    report.cached_asset_count.val.to_string()
  detail + render_html_semantic_lowering_profile_detail(semantic_lowering_state)
}

///|
fn count_html_profile_blocks(
  blocks : Array[@cor.Block],
) -> HtmlProfileBlockCounts {
  let mut table_count = 0
  let mut image_count = 0
  let mut link_count = 0
  let mut note_ref_count = 0

  for block in blocks {
    match block {
      @cor.Block::RichHeading(_, inlines) => {
        let (links, note_refs) = count_html_profile_inlines(inlines)
        link_count += links
        note_ref_count += note_refs
      }
      @cor.Block::RichParagraph(inlines) => {
        let (links, note_refs) = count_html_profile_inlines(inlines)
        link_count += links
        note_ref_count += note_refs
      }
      @cor.Block::RichListItem(_, _, inlines) => {
        let (links, note_refs) = count_html_profile_inlines(inlines)
        link_count += links
        note_ref_count += note_refs
      }
      @cor.Block::RichBlockQuote(inlines) => {
        let (links, note_refs) = count_html_profile_inlines(inlines)
        link_count += links
        note_ref_count += note_refs
      }
      @cor.Block::Table(_) | @cor.Block::RichTable(_) => table_count += 1
      @cor.Block::Image(_, _) | @cor.Block::ImageBlock(_) => image_count += 1
      _ => ()
    }
  }

  { table_count, image_count, link_count, note_ref_count }
}

///|
fn count_html_profile_inlines(inlines : Array[@cor.Inline]) -> (Int, Int) {
  let mut link_count = 0
  let mut note_ref_count = 0
  for inline in inlines {
    match inline {
      @cor.Inline::Link(_, _) => link_count += 1
      @cor.Inline::NoteRef(_) => note_ref_count += 1
      _ => ()
    }
  }
  (link_count, note_ref_count)
}

///|
fn render_html_parser_issue_summary_detail(
  summary : HtmlParserIssueSummary,
) -> String {
  "issue_count=" +
  summary.issue_count.to_string() +
  " warning_count=" +
  summary.warning_count.to_string() +
  " error_count=" +
  summary.error_count.to_string() +
  " script_count=" +
  summary.script_count.to_string() +
  " style_count=" +
  summary.style_count.to_string() +
  " unsafe_url_count=" +
  summary.unsafe_url_count.to_string() +
  " duplicate_attribute_count=" +
  summary.duplicate_attribute_count.to_string() +
  " unexpected_closing_count=" +
  summary.unexpected_closing_count.to_string() +
  " unclosed_element_count=" +
  summary.unclosed_element_count.to_string()
}

///|
fn render_html_semantic_block_summary_detail(
  summary : HtmlSemanticBlockSummary?,
) -> String {
  match summary {
    Some(item) =>
      " semantic_block_count=" +
      item.block_count.to_string() +
      " semantic_heading_count=" +
      item.heading_count.to_string() +
      " semantic_paragraph_count=" +
      item.paragraph_count.to_string() +
      " semantic_list_count=" +
      item.list_count.to_string() +
      " semantic_list_fact_count=" +
      item.semantic_list_fact_count.to_string() +
      " semantic_list_item_fact_count=" +
      item.semantic_list_item_fact_count.to_string() +
      " semantic_max_list_depth=" +
      item.semantic_max_list_depth.to_string() +
      " semantic_blockquote_fact_count=" +
      item.semantic_blockquote_fact_count.to_string() +
      " semantic_max_quote_depth=" +
      item.semantic_max_quote_depth.to_string() +
      " semantic_code_block_fact_count=" +
      item.semantic_code_block_fact_count.to_string() +
      " semantic_code_block_language_hint_count=" +
      item.semantic_code_block_language_hint_count.to_string() +
      " semantic_figure_fact_count=" +
      item.semantic_figure_fact_count.to_string() +
      " semantic_figure_caption_count=" +
      item.semantic_figure_caption_count.to_string() +
      " semantic_figure_image_count=" +
      item.semantic_figure_image_count.to_string() +
      " semantic_paragraph_fact_count=" +
      item.semantic_paragraph_fact_count.to_string() +
      " semantic_paragraph_with_link_count=" +
      item.semantic_paragraph_with_link_count.to_string() +
      " semantic_paragraph_with_image_count=" +
      item.semantic_paragraph_with_image_count.to_string() +
      " semantic_paragraph_with_code_count=" +
      item.semantic_paragraph_with_code_count.to_string() +
      " semantic_paragraph_with_emphasis_count=" +
      item.semantic_paragraph_with_emphasis_count.to_string() +
      " semantic_paragraph_with_strong_count=" +
      item.semantic_paragraph_with_strong_count.to_string() +
      " semantic_paragraph_with_break_count=" +
      item.semantic_paragraph_with_break_count.to_string() +
      " semantic_paragraph_meaningful_text_count=" +
      item.semantic_paragraph_meaningful_text_count.to_string() +
      " semantic_paragraph_candidate_count=" +
      item.semantic_paragraph_candidate_count.to_string() +
      " semantic_paragraph_repeated_whitespace_count=" +
      item.semantic_paragraph_repeated_whitespace_count.to_string() +
      " semantic_paragraph_newline_count=" +
      item.semantic_paragraph_newline_count.to_string() +
      " semantic_table_count=" +
      item.table_count.to_string() +
      " semantic_table_fact_count=" +
      item.semantic_table_fact_count.to_string() +
      " semantic_table_fact_row_count=" +
      item.semantic_table_fact_row_count.to_string() +
      " semantic_table_fact_cell_count=" +
      item.semantic_table_fact_cell_count.to_string() +
      " semantic_table_caption_count=" +
      item.semantic_table_caption_count.to_string() +
      " semantic_table_warning_count=" +
      item.semantic_table_warning_count.to_string() +
      " semantic_table_span_cell_count=" +
      item.semantic_table_span_cell_count.to_string() +
      " semantic_table_ragged_row_count=" +
      item.semantic_table_ragged_row_count.to_string() +
      " semantic_table_nested_cell_count=" +
      item.semantic_table_nested_cell_count.to_string() +
      " semantic_table_complex_cell_count=" +
      item.semantic_table_complex_cell_count.to_string() +
      " semantic_table_image_cell_count=" +
      item.semantic_table_image_cell_count.to_string() +
      " semantic_table_block_child_cell_count=" +
      item.semantic_table_block_child_cell_count.to_string() +
      " semantic_table_malformed_warning_count=" +
      item.semantic_table_malformed_warning_count.to_string() +
      " semantic_unsupported_block_count=" +
      item.unsupported_block_count.to_string() +
      " semantic_inline_count=" +
      item.inline_count.to_string() +
      " semantic_whitespace_only_text_inline_count=" +
      item.semantic_whitespace_only_text_inline_count.to_string() +
      " semantic_leading_whitespace_inline_count=" +
      item.semantic_leading_whitespace_inline_count.to_string() +
      " semantic_trailing_whitespace_inline_count=" +
      item.semantic_trailing_whitespace_inline_count.to_string() +
      " semantic_repeated_whitespace_inline_count=" +
      item.semantic_repeated_whitespace_inline_count.to_string() +
      " semantic_newline_inline_count=" +
      item.semantic_newline_inline_count.to_string() +
      " semantic_whitespace_preserving_inline_count=" +
      item.semantic_whitespace_preserving_inline_count.to_string() +
      " semantic_inline_with_surrounding_text_count=" +
      item.semantic_inline_with_surrounding_text_count.to_string() +
      " semantic_link_fact_count=" +
      item.semantic_link_count.to_string() +
      " semantic_image_fact_count=" +
      item.semantic_image_count.to_string() +
      " semantic_linked_image_count=" +
      item.semantic_linked_image_count.to_string() +
      " semantic_image_in_link_count=" +
      item.semantic_image_in_link_count.to_string() +
      " semantic_note_ref_inline_count=" +
      item.semantic_note_ref_inline_count.to_string() +
      " semantic_srcset_image_count=" +
      item.semantic_srcset_image_count.to_string() +
      " semantic_picture_source_count=" +
      item.semantic_picture_source_count.to_string() +
      " semantic_unsafe_link_count=" +
      item.unsafe_link_count.to_string() +
      " semantic_remote_image_count=" +
      item.remote_image_count.to_string() +
      " semantic_data_uri_image_count=" +
      item.data_uri_image_count.to_string() +
      " semantic_note_fact_count=" +
      item.semantic_note_fact_count.to_string() +
      " semantic_note_ref_fact_count=" +
      item.semantic_note_ref_fact_count.to_string() +
      " semantic_note_body_fact_count=" +
      item.semantic_note_body_fact_count.to_string() +
      " semantic_broken_note_ref_count=" +
      item.semantic_broken_note_ref_count.to_string() +
      " semantic_duplicate_note_body_count=" +
      item.semantic_duplicate_note_body_count.to_string() +
      " semantic_backref_note_count=" +
      item.semantic_backref_note_count.to_string() +
      " semantic_scope_fact_count=" +
      item.semantic_scope_fact_count.to_string() +
      " semantic_scope_body_count=" +
      item.semantic_scope_body_count.to_string() +
      " semantic_scope_main_count=" +
      item.semantic_scope_main_count.to_string() +
      " semantic_scope_article_count=" +
      item.semantic_scope_article_count.to_string() +
      " semantic_scope_document_root_count=" +
      item.semantic_scope_document_root_count.to_string() +
      " semantic_scope_fragment_count=" +
      item.semantic_scope_fragment_count.to_string() +
      " semantic_scope_heuristic_count=" +
      item.semantic_scope_heuristic_count.to_string() +
      " semantic_scope_missing_body_count=" +
      item.semantic_scope_missing_body_count.to_string() +
      " semantic_scope_multiple_body_count=" +
      item.semantic_scope_multiple_body_count.to_string() +
      " semantic_scope_malformed_root_count=" +
      item.semantic_scope_malformed_root_count.to_string() +
      " semantic_noise_candidate_count=" +
      item.semantic_noise_candidate_count.to_string() +
      " semantic_noise_nav_like_count=" +
      item.semantic_noise_nav_like_count.to_string() +
      " semantic_noise_footer_like_count=" +
      item.semantic_noise_footer_like_count.to_string() +
      " semantic_noise_sidebar_like_count=" +
      item.semantic_noise_sidebar_like_count.to_string() +
      " semantic_noise_hiddenish_count=" +
      item.semantic_noise_hiddenish_count.to_string() +
      " semantic_noise_script_style_template_count=" +
      item.semantic_noise_script_style_template_count.to_string() +
      " semantic_noise_repeated_boilerplate_count=" +
      item.semantic_noise_repeated_boilerplate_count.to_string() +
      " semantic_warning_count=" +
      item.warning_count.to_string() +
      " semantic_warning_info_count=" +
      item.warning_info_count.to_string() +
      " semantic_warning_warning_count=" +
      item.warning_warning_count.to_string() +
      " semantic_warning_error_count=" +
      item.warning_error_count.to_string() +
      " semantic_unsupported_fact_count=" +
      item.unsupported_fact_count.to_string() +
      " semantic_unsupported_info_count=" +
      item.unsupported_info_count.to_string() +
      " semantic_unsupported_warning_count=" +
      item.unsupported_warning_count.to_string() +
      " semantic_unsupported_error_count=" +
      item.unsupported_error_count.to_string() +
      " semantic_unsupported_script_count=" +
      item.unsupported_script_count.to_string() +
      " semantic_unsupported_style_count=" +
      item.unsupported_style_count.to_string() +
      " semantic_unsupported_iframe_count=" +
      item.unsupported_iframe_count.to_string() +
      " semantic_unsupported_embed_count=" +
      item.unsupported_embed_count.to_string() +
      " semantic_unsupported_object_count=" +
      item.unsupported_object_count.to_string() +
      " semantic_unsupported_svg_count=" +
      item.unsupported_svg_count.to_string() +
      " semantic_unsupported_math_count=" +
      item.unsupported_math_count.to_string() +
      " semantic_unsupported_template_count=" +
      item.unsupported_template_count.to_string() +
      " semantic_unsupported_form_count=" +
      item.unsupported_form_count.to_string() +
      " semantic_unsupported_input_count=" +
      item.unsupported_input_count.to_string() +
      " semantic_unsupported_select_count=" +
      item.unsupported_select_count.to_string() +
      " semantic_unsupported_textarea_count=" +
      item.unsupported_textarea_count.to_string() +
      " semantic_unsupported_button_count=" +
      item.unsupported_button_count.to_string() +
      " semantic_unsupported_video_count=" +
      item.unsupported_video_count.to_string() +
      " semantic_unsupported_audio_count=" +
      item.unsupported_audio_count.to_string() +
      " semantic_unsupported_source_count=" +
      item.unsupported_source_count.to_string() +
      " semantic_unsupported_canvas_count=" +
      item.unsupported_canvas_count.to_string() +
      " semantic_unsupported_remote_image_count=" +
      item.unsupported_remote_image_count.to_string() +
      " semantic_unsupported_data_image_count=" +
      item.unsupported_data_image_count.to_string() +
      " semantic_unsupported_unsafe_url_count=" +
      item.unsupported_unsafe_url_count.to_string() +
      " semantic_unsupported_empty_url_count=" +
      item.unsupported_empty_url_count.to_string() +
      " semantic_unsupported_huge_table_count=" +
      item.unsupported_huge_table_count.to_string()
    None => ""
  }
}

///|
fn normalize_html_input_bytes(bs : Bytes) -> Bytes {
  let n = bs.length()
  let mut start = 0
  if n >= 3 && bs[0] == 0xEF && bs[1] == 0xBB && bs[2] == 0xBF {
    start = 3
  }

  let out : Array[Byte] = []
  let mut i = start
  while i < n {
    let b = bs[i]
    if b == '\r'.to_int().to_byte() {
      out.push('\n'.to_int().to_byte())
      if i + 1 < n && bs[i + 1] == '\n'.to_int().to_byte() {
        i = i + 2
      } else {
        i = i + 1
      }
    } else {
      out.push(b)
      i = i + 1
    }
  }

  Bytes::from_array(out)
}

///|
fn narrow_html_content_scope(
  bs : Bytes,
  parser_analysis : HtmlParserSourceAnalysis?,
) -> HtmlScopedContent {
  match parser_analysis {
    Some(analysis) => {
      let mut scope_from_events = true
      let mut fallback_reason = ""
      let range = match
        find_html_content_scope_range_from_events(analysis.events) {
        Some(range) => range
        None =>
          match find_html_tag_block_range_from_events(analysis.events, "body") {
            Some(range) => range
            None => {
              scope_from_events = false
              fallback_reason = "no_event_scope"
              { start: 0, end_: analysis.text.length() }
            }
          }
      }
      {
        bytes: html_source_range_to_bytes(analysis.text, range),
        skip_ranges: html_skip_ranges_for_content(
          analysis.text,
          analysis.events,
          range,
        ),
        scope_from_events,
        scope_fallback_reason: fallback_reason,
      }
    }
    None =>
      {
        bytes: narrow_html_content_scope_fallback(bs),
        skip_ranges: [],
        scope_from_events: false,
        scope_fallback_reason: "no_parser_analysis",
      }
  }
}

///|
fn html_source_range_to_bytes(text : String, range : HtmlSourceRange) -> Bytes {
  if range.start < 0 || range.end_ < range.start || range.end_ > text.length() {
    return @utf8.encode("")
  }
  @utf8.encode(text[range.start:range.end_].to_owned())
}

///|
fn html_skip_ranges_for_content(
  text : String,
  events : Array[@dphtml.HtmlTokenEvent],
  content_range : HtmlSourceRange,
) -> Array[HtmlByteRange] {
  let ranges = @dphtml.html_tokens_collect_element_ranges(events, [
    "script", "style", "head", "noscript",
  ])
  let out : Array[HtmlByteRange] = []
  for range in ranges {
    let start = max_int(range.source_start, content_range.start)
    let end_ = min_int(range.source_end, content_range.end_)
    if end_ > start {
      out.push({
        start: html_source_offset_to_relative_byte(
          text,
          content_range.start,
          start,
        ),
        end_: html_source_offset_to_relative_byte(
          text,
          content_range.start,
          end_,
        ),
      })
    }
  }
  out
}

///|
fn html_source_offset_to_relative_byte(
  text : String,
  base : Int,
  offset : Int,
) -> Int {
  if offset <= base {
    0
  } else {
    @utf8.encode(text[base:offset].to_owned()).length()
  }
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn find_html_content_scope_range_from_events(
  events : Array[@dphtml.HtmlTokenEvent],
) -> HtmlSourceRange? {
  match find_html_scope_range_with_exact_root_token(events) {
    Some(range) => Some(range)
    None =>
      match find_html_scope_range_with_exact_content_id(events) {
        Some(range) => Some(range)
        None =>
          match find_html_scope_range_with_role_main(events) {
            Some(range) => Some(range)
            None =>
              match find_html_scope_range_with_strong_content_attr(events) {
                Some(range) => Some(range)
                None =>
                  match
                    find_html_tag_block_range_from_events(events, "article") {
                    Some(range) => Some(range)
                    None =>
                      find_html_tag_block_range_from_events(events, "main")
                  }
              }
          }
      }
  }
}

///|
fn find_html_scope_range_with_exact_root_token(
  events : Array[@dphtml.HtmlTokenEvent],
) -> HtmlSourceRange? {
  find_html_container_range_matching_events(events, fn(event) {
    html_scope_is_candidate_tag(event.tag_name) &&
    (
      html_scope_event_attr_contains_exact_root_token(event, "id") ||
      html_scope_event_attr_contains_exact_root_token(event, "class")
    )
  })
}

///|
fn find_html_scope_range_with_strong_content_attr(
  events : Array[@dphtml.HtmlTokenEvent],
) -> HtmlSourceRange? {
  find_html_container_range_matching_events(events, fn(event) {
    html_scope_is_candidate_tag(event.tag_name) &&
    !html_scope_event_attr_value_has_noise_token(event, "id") &&
    !html_scope_event_attr_value_has_noise_token(event, "class") &&
    (
      html_scope_event_attr_is_strong_content_root(event, "id") ||
      html_scope_event_attr_is_strong_content_root(event, "class")
    )
  })
}

///|
fn find_html_scope_range_with_exact_content_id(
  events : Array[@dphtml.HtmlTokenEvent],
) -> HtmlSourceRange? {
  find_html_container_range_matching_events(events, fn(event) {
    html_scope_is_candidate_tag(event.tag_name) &&
    html_scope_event_attr_is_exact_content_id(event, "id")
  })
}

///|
fn find_html_scope_range_with_role_main(
  events : Array[@dphtml.HtmlTokenEvent],
) -> HtmlSourceRange? {
  find_html_container_range_matching_events(events, fn(event) {
    html_scope_is_candidate_tag(event.tag_name) &&
    html_scope_event_role_is_main(event)
  })
}

///|
fn find_html_tag_block_range_from_events(
  events : Array[@dphtml.HtmlTokenEvent],
  tag_name : String,
) -> HtmlSourceRange? {
  find_html_container_range_matching_events(events, fn(event) {
    event.tag_name == tag_name
  })
}

///|
fn find_html_container_range_matching_events(
  events : Array[@dphtml.HtmlTokenEvent],
  matcher : (@dphtml.HtmlTokenEvent) -> Bool,
) -> HtmlSourceRange? {
  for i in 0..<events.length() {
    let event = events[i]
    if event.kind == @dphtml.HtmlTokenEventKind::StartTag && matcher(event) {
      match @dphtml.html_tokens_find_matching_close(events, i) {
        Some(close_i) =>
          return Some({
            start: event.source_end,
            end_: events[close_i].source_start,
          })
        None => ()
      }
    }
  }
  None
}

///|
fn html_scope_event_attr_contains_exact_root_token(
  event : @dphtml.HtmlTokenEvent,
  attr_name : String,
) -> Bool {
  match @dphtml.html_token_event_attr_value(event, attr_name) {
    None => false
    Some(value) => {
      let lower = value.to_lower()
      lower.contains("mw-content-text") || lower.contains("bodycontent")
    }
  }
}

///|
fn html_scope_event_attr_is_strong_content_root(
  event : @dphtml.HtmlTokenEvent,
  attr_name : String,
) -> Bool {
  match @dphtml.html_token_event_attr_value(event, attr_name) {
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
fn html_scope_event_attr_is_exact_content_id(
  event : @dphtml.HtmlTokenEvent,
  attr_name : String,
) -> Bool {
  match @dphtml.html_token_event_attr_value(event, attr_name) {
    None => false
    Some(value) => {
      let lower = value.to_lower().trim().to_owned()
      lower == "content" || lower == "maincontent"
    }
  }
}

///|
fn html_scope_event_role_is_main(event : @dphtml.HtmlTokenEvent) -> Bool {
  @dphtml.html_token_event_attr_value(event, "role")
  .map(fn(value) { value.to_lower().trim().to_owned() })
  .unwrap_or("") ==
  "main"
}

///|
fn html_scope_event_attr_value_has_noise_token(
  event : @dphtml.HtmlTokenEvent,
  attr_name : String,
) -> Bool {
  match @dphtml.html_token_event_attr_value(event, attr_name) {
    None => false
    Some(value) => html_contains_noise_token(value.to_lower())
  }
}

///|
fn narrow_html_content_scope_fallback(bs : Bytes) -> Bytes {
  match find_html_content_scope_inner(bs) {
    Some(inner) => inner
    None =>
      match find_tag_block_inner(bs, "body") {
        Some(inner) => inner
        None => bs
      }
  }
}

///|
fn find_html_content_scope_inner(bs : Bytes) -> Bytes? {
  match find_html_scope_inner_with_exact_root_token(bs) {
    Some(inner) => Some(inner)
    None =>
      match find_html_scope_inner_with_exact_content_id(bs) {
        Some(inner) => Some(inner)
        None =>
          match find_html_scope_inner_with_role_main(bs) {
            Some(inner) => Some(inner)
            None =>
              match find_html_scope_inner_with_strong_content_attr(bs) {
                Some(inner) => Some(inner)
                None =>
                  match find_tag_block_inner(bs, "article") {
                    Some(inner) => Some(inner)
                    None => find_tag_block_inner(bs, "main")
                  }
              }
          }
      }
  }
}

///|
fn find_html_scope_inner_with_exact_root_token(bs : Bytes) -> Bytes? {
  find_html_container_block_inner_matching(bs, fn(tag_name, tag) {
    html_scope_is_candidate_tag(tag_name) &&
    (
      html_scope_attr_contains_exact_root_token(tag, "id") ||
      html_scope_attr_contains_exact_root_token(tag, "class")
    )
  })
}

///|
fn find_html_scope_inner_with_strong_content_attr(bs : Bytes) -> Bytes? {
  find_html_container_block_inner_matching(bs, fn(tag_name, tag) {
    html_scope_is_candidate_tag(tag_name) &&
    !html_attr_value_has_noise_token(tag, "id") &&
    !html_attr_value_has_noise_token(tag, "class") &&
    (
      html_scope_attr_is_strong_content_root(tag, "id") ||
      html_scope_attr_is_strong_content_root(tag, "class")
    )
  })
}

///|
fn find_html_scope_inner_with_exact_content_id(bs : Bytes) -> Bytes? {
  find_html_container_block_inner_matching(bs, fn(tag_name, tag) {
    html_scope_is_candidate_tag(tag_name) &&
    html_scope_attr_is_exact_content_id(tag, "id")
  })
}

///|
fn find_html_scope_inner_with_role_main(bs : Bytes) -> Bytes? {
  find_html_container_block_inner_matching(bs, fn(tag_name, tag) {
    html_scope_is_candidate_tag(tag_name) && html_scope_role_is_main(tag)
  })
}

///|
fn find_html_container_block_inner_matching(
  bs : Bytes,
  matcher : (String, String) -> Bool,
) -> Bytes? {
  let lt = pat("<")
  let gt = pat(">")
  let mut pos = 0
  let n = bs.length()

  while pos < n {
    let open0 = find_bytes(bs, lt, pos)
    match open0 {
      None => return None
      Some(open_idx) =>
        match find_bytes(bs, gt, open_idx) {
          None => return None
          Some(gt_idx) => {
            let tag_bs = bs[open_idx:gt_idx + 1].to_owned()
            let tag = (@utf8.decode(tag_bs, ignore_bom=false) catch { _ => "" }).to_lower()
            match html_scope_open_tag_name(tag) {
              Some(tag_name) =>
                if matcher(tag_name, tag) {
                  let inner_start = gt_idx + 1
                  match find_matching_tag_end(bs, open_idx, tag_name) {
                    Some(close_idx) =>
                      return Some(bs[inner_start:close_idx].to_owned())
                    None => ()
                  }
                }
              None => ()
            }
            pos = gt_idx + 1
          }
        }
    }
  }

  None
}

///|
fn html_scope_open_tag_name(tag : String) -> String? {
  let lower = tag.to_lower()
  if !lower.has_prefix("<") ||
    lower.has_prefix("</") ||
    lower.has_prefix("<!") ||
    lower.has_prefix("<?") {
    return None
  }

  let n = lower.length()
  let mut i = 1
  while i < n && (lower[i] == ' ' || lower[i] == '\n' || lower[i] == '\t') {
    i += 1
  }
  let start = i
  while i < n {
    let ch = lower[i]
    if ch == ' ' || ch == '\n' || ch == '\t' || ch == '>' || ch == '/' {
      break
    }
    i += 1
  }

  if i > start {
    Some(lower[start:i].to_owned())
  } else {
    None
  }
}

///|
fn html_scope_is_candidate_tag(tag_name : String) -> Bool {
  tag_name == "div" ||
  tag_name == "section" ||
  tag_name == "article" ||
  tag_name == "main"
}

///|
fn html_scope_attr_contains_exact_root_token(
  tag : String,
  attr_name : String,
) -> Bool {
  match read_html_attr_value(tag, attr_name) {
    None => false
    Some(value) => {
      let lower = value.to_lower()
      lower.contains("mw-content-text") || lower.contains("bodycontent")
    }
  }
}

///|
fn html_scope_attr_is_strong_content_root(
  tag : String,
  attr_name : String,
) -> Bool {
  match read_html_attr_value(tag, attr_name) {
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
fn html_scope_attr_is_exact_content_id(
  tag : String,
  attr_name : String,
) -> Bool {
  match read_html_attr_value(tag, attr_name) {
    None => false
    Some(value) => {
      let lower = value.to_lower().trim().to_owned()
      lower == "content" || lower == "maincontent"
    }
  }
}

///|
fn html_scope_role_is_main(tag : String) -> Bool {
  read_html_attr_value(tag, "role")
  .map(fn(value) { value.to_lower().trim().to_owned() })
  .unwrap_or("") ==
  "main"
}

///|
fn html_scope_attr_words(value : String) -> Array[String] {
  let out : Array[String] = []
  let part : Array[Char] = []

  fn flush(out : Array[String], part : Array[Char]) -> Unit {
    if part.length() == 0 {
      return
    }
    out.push(String::from_array(part))
    part.clear()
  }

  for ch in value.to_lower() {
    if (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') {
      part.push(ch)
    } else {
      flush(out, part)
    }
  }
  flush(out, part)
  out
}

///|
fn html_scope_words_contain(words : Array[String], needle : String) -> Bool {
  for word in words {
    if word == needle {
      return true
    }
  }
  false
}

///|
fn html_block_origin_with_index(
  origin : @cor.Origin?,
  source_name : String,
  block_index : Int,
) -> @cor.Origin? {
  match origin {
    Some(v) =>
      Some({
        source_name: Some(source_name),
        page: v.page,
        slide: v.slide,
        sheet: v.sheet,
        block_index: Some(block_index),
        heading_path: v.heading_path,
        line_start: v.line_start,
        line_end: v.line_end,
        row_index: v.row_index,
        column_index: v.column_index,
        object_ref: v.object_ref,
        relationship_id: v.relationship_id,
        key_path: v.key_path,
      })
    None =>
      Some({
        source_name: Some(source_name),
        page: None,
        slide: None,
        sheet: None,
        block_index: Some(block_index),
        heading_path: None,
        line_start: None,
        line_end: None,
        row_index: None,
        column_index: None,
        object_ref: None,
        relationship_id: None,
        key_path: None,
      })
  }
}
