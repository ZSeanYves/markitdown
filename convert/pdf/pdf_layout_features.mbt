///|
/// Legacy naming note:
/// - this file still uses the broad `layout` name for compatibility
/// - it exposes both block-semantic feature values and boundary feature values
/// - callers should keep block (`Task A`) and boundary (`Task B`) exports in
///   separate manifests, reports, and training routes

///|
pub fn build_pdf_layout_block_feature_values(
  page : PdfConvertPage,
  block : PdfConvertBlock,
  prev : PdfConvertBlock?,
  next : PdfConvertBlock?,
  repeated_text_score : Double,
  near_image_distance : Double?,
  page_median_font_size : Double?,
) -> Map[String, Double] {
  block_layout_feature_values(
    page, block, prev, next, repeated_text_score, near_image_distance, page_median_font_size,
  )
}

///|
pub fn build_pdf_layout_boundary_feature_values(
  prev_page : PdfConvertPage,
  cur_page : PdfConvertPage,
) -> Map[String, Double] {
  boundary_layout_feature_values(prev_page, cur_page)
}

///|
priv struct PdfBlockLinkFeatureSummary {
  overlap_ratio : Double
  text_coverage_ratio : Double
  has_partial_link : Bool
  is_link_only_candidate : Bool
  has_uri_target : Bool
  has_internal_target : Bool
  has_named_target : Bool
  has_mixed_target : Bool
}

///|
fn block_layout_feature_values(
  page : PdfConvertPage,
  block : PdfConvertBlock,
  prev : PdfConvertBlock?,
  next : PdfConvertBlock?,
  repeated_text_score : Double,
  near_image_distance : Double?,
  page_median_font_size : Double?,
) -> Map[String, Double] {
  let out : Map[String, Double] = Map([])
  let page_box = effective_page_box_for_convert_page(page)
  let page_width = @model.rect_width(page_box)
  let page_height = @model.rect_height(page_box)
  let normalized = normalize_pdf_comparison_text(block.text)
  let word_count = count_feature_words(normalized)
  let contains_url = contains_url_signal(block.text)
  let contains_email = contains_email_signal(block.text)
  let link_summary = summarize_block_link_features(page, block)
  let page_label_pattern = page_label_pattern_signal(block.text)
  let caption_marker_figure = caption_marker_figure_signal(block.text)
  let caption_marker_table = caption_marker_table_signal(block.text)
  let caption_marker_starts_line = caption_marker_starts_line_signal(block.text)
  let identifier_like = identifier_like_signal(block.text)
  let technical_literal = technical_literal_signal(block.text)
  let sentence_like = sentence_like_signal(block.text)
  let figure_reference_sentence = figure_reference_sentence_signal(block.text)
  let section_reference_sentence = section_reference_sentence_signal(block.text)
  let technical_sentence_guard = technical_sentence_guard_signal(block.text)
  let citation_reference = citation_reference_signal(block.text)
  let sku_like = sku_like_signal(block.text)
  let quantity_price = quantity_price_signal(block.text)
  let payment_card = payment_card_signal(block.text)

  set_feature(out, "text_len", block.text.length().to_double())
  set_feature(out, "normalized_text_len", normalized.length().to_double())
  set_feature(out, "word_count", word_count.to_double())
  set_feature(out, "digit_ratio", digit_ratio(block.text))
  set_feature(out, "punctuation_ratio", punctuation_ratio(block.text))
  set_feature(out, "uppercase_ratio", uppercase_ratio(block.text))
  set_feature(out, "cjk_ratio", cjk_ratio(block.text))
  set_feature(out, "latin_ratio", latin_ratio(block.text))
  set_feature(out, "symbol_ratio", symbol_ratio(block.text))
  set_feature(out, "x0", block._bbox.x0)
  set_feature(out, "y0", block._bbox.y0)
  set_feature(out, "x1", block._bbox.x1)
  set_feature(out, "y1", block._bbox.y1)
  set_feature(out, "width", @model.rect_width(block._bbox))
  set_feature(out, "height", @model.rect_height(block._bbox))
  set_feature(out, "text_density", text_density(block.text, block._bbox))
  set_feature(out, "page_width", page_width)
  set_feature(out, "page_height", page_height)
  set_feature(out, "page_line_count", page.lines.length().to_double())
  set_feature(out, "page_block_count", page.blocks.length().to_double())
  set_feature_opt(out, "page_median_font_size", page_median_font_size)
  set_feature_opt(
    out,
    "relative_font_size",
    relative_font_size(block.dominant_font_size, page_median_font_size),
  )
  set_feature(out, "x_center_ratio", rect_center_x_ratio(block._bbox, page_box))
  set_feature(out, "y_center_ratio", rect_center_y_ratio(block._bbox, page_box))
  set_feature(out, "top_ratio", top_ratio(block._bbox, page_box))
  set_feature(out, "bottom_ratio", bottom_ratio(block._bbox, page_box))
  set_feature_opt(out, "font_size_hint", block.dominant_font_size)
  set_feature(out, "bold_hint", bold_hint(block))
  set_feature_opt(out, "line_gap_before", block.first_line_gap_before)
  set_feature_opt(out, "line_gap_after", block.last_line_gap_after)
  set_feature_opt(out, "indent_left", block.first_indent_left)
  set_feature(
    out,
    "alignment_hint",
    alignment_hint_value(block.first_alignment_hint),
  )
  set_feature_opt(out, "near_image_distance", near_image_distance)
  set_feature_opt(
    out,
    "near_annotation_distance",
    nearest_annotation_distance(page.annotations, block._bbox),
  )
  set_feature_opt(
    out,
    "near_link_annotation_distance",
    nearest_link_annotation_distance(page.annotations, block._bbox),
  )
  set_feature_opt(
    out,
    "near_uri_annotation_distance",
    nearest_uri_annotation_distance(page.annotations, block._bbox),
  )
  set_feature_opt(
    out,
    "near_dest_annotation_distance",
    nearest_dest_annotation_distance(page.annotations, block._bbox),
  )
  set_feature(
    out,
    "page_edge_distance",
    page_edge_distance(block._bbox, page_box),
  )
  set_feature(out, "repeated_text_score", repeated_text_score)
  set_feature(
    out,
    "source_ref_count",
    block_source_ref_count(block).to_double(),
  )
  set_feature(
    out,
    "has_rich_inline_payload",
    bool_feature(has_rich_inline_payload(block)),
  )
  set_feature(out, "has_link_inline", bool_feature(has_link_inline(block)))
  set_feature(out, "link_inline_count", link_inline_count(block).to_double())
  set_feature(out, "link_overlap_ratio", link_summary.overlap_ratio)
  set_feature(out, "link_text_coverage_ratio", link_summary.text_coverage_ratio)
  set_feature(
    out,
    "has_partial_link",
    bool_feature(link_summary.has_partial_link),
  )
  set_feature(
    out,
    "is_link_only_candidate",
    bool_feature(link_summary.is_link_only_candidate),
  )
  set_feature(out, "link_target_uri", bool_feature(link_summary.has_uri_target))
  set_feature(
    out,
    "link_target_internal",
    bool_feature(link_summary.has_internal_target),
  )
  set_feature(
    out,
    "link_target_named",
    bool_feature(link_summary.has_named_target),
  )
  set_feature(
    out,
    "link_target_mixed",
    bool_feature(link_summary.has_mixed_target),
  )
  set_feature(
    out,
    "page_number_like_link",
    bool_feature(
      looks_like_page_number_signal(block.text) &&
      (link_summary.has_internal_target || link_summary.has_named_target) &&
      link_summary.overlap_ratio >= 0.35,
    ),
  )
  set_feature(
    out,
    "toc_like_anchor_signal",
    bool_feature(toc_like_anchor_signal(block.text)),
  )
  set_feature(
    out,
    "visible_url_without_annotation",
    bool_feature(
      visible_url_without_annotation_signal(
        contains_url, contains_email, link_summary,
      ),
    ),
  )
  set_feature(
    out,
    "page_label_pattern_signal",
    bool_feature(page_label_pattern),
  )
  set_feature(
    out,
    "cleanup_shell_signal",
    bool_feature(
      cleanup_shell_signal(
        block.text,
        block,
        page_box,
        repeated_text_score,
        page.blocks.length(),
        page_median_font_size,
      ),
    ),
  )
  set_feature(
    out,
    "is_heading_candidate",
    bool_feature(block.is_heading_candidate),
  )
  set_feature(
    out,
    "is_page_number_candidate",
    bool_feature(block.is_noise_candidate),
  )
  set_feature(
    out,
    "is_header_footer_candidate",
    bool_feature(block.is_header_footer_candidate),
  )
  set_feature(
    out,
    "is_artifact_candidate",
    bool_feature(block.is_artifact_candidate),
  )
  set_feature(
    out,
    "is_caption_candidate",
    bool_feature(block.is_caption_candidate),
  )
  set_feature(
    out,
    "is_table_cell_candidate",
    bool_feature(block.is_table_cell_candidate),
  )
  set_feature(
    out,
    "is_noise_kind",
    bool_feature(block.kind == PdfConvertBlockKind::Noise),
  )
  set_feature(
    out,
    "is_heading_kind",
    bool_feature(block.kind == PdfConvertBlockKind::Heading),
  )
  set_feature(out, "line_count", block.line_count.to_double())
  set_feature_opt(
    out,
    "prev_gap_before",
    match prev {
      Some(p) => p.first_line_gap_before
      None => None
    },
  )
  set_feature_opt(
    out,
    "next_gap_before",
    match next {
      Some(n) => n.first_line_gap_before
      None => None
    },
  )
  set_feature(
    out,
    "prev_font_size_delta",
    font_size_delta(
      block.dominant_font_size,
      match prev {
        Some(p) => p.dominant_font_size
        None => None
      },
    ),
  )
  set_feature(
    out,
    "next_font_size_delta",
    font_size_delta(
      block.dominant_font_size,
      match next {
        Some(n) => n.dominant_font_size
        None => None
      },
    ),
  )
  set_feature(
    out,
    "same_paragraph_candidate",
    bool_feature(
      block.first_is_same_paragraph_with_prev_candidate ||
      block.last_is_same_paragraph_with_prev_candidate,
    ),
  )
  set_feature(
    out,
    "wrapped_candidate",
    bool_feature(
      block.first_is_wrapped_candidate || block.last_is_wrapped_candidate,
    ),
  )
  set_feature(
    out,
    "contains_currency",
    bool_feature(contains_currency_signal(block.text)),
  )
  set_feature(
    out,
    "contains_time",
    bool_feature(contains_time_signal(block.text)),
  )
  set_feature(
    out,
    "contains_date",
    bool_feature(contains_date_signal(block.text)),
  )
  set_feature(
    out,
    "looks_like_address",
    bool_feature(looks_like_address_signal(block.text)),
  )
  set_feature(
    out,
    "looks_like_separator",
    bool_feature(looks_like_separator_signal(block.text)),
  )
  set_feature(
    out,
    "looks_like_page_number",
    bool_feature(looks_like_page_number_signal(block.text)),
  )
  set_feature(
    out,
    "looks_like_bullet",
    bool_feature(looks_like_bullet_signal(block.text)),
  )
  set_feature(
    out,
    "looks_like_list_marker_token",
    bool_feature(looks_like_list_marker_token_signal(block.text)),
  )
  set_feature(out, "contains_url", bool_feature(contains_url))
  set_feature(out, "contains_email", bool_feature(contains_email))
  set_feature(
    out,
    "contains_url_or_email",
    bool_feature(contains_url || contains_email),
  )
  set_feature(
    out,
    "contains_path_like",
    bool_feature(contains_path_like_signal(block.text)),
  )
  set_feature(out, "identifier_like_signal", bool_feature(identifier_like))
  set_feature(out, "technical_literal_signal", bool_feature(technical_literal))
  set_feature(out, "sentence_like_signal", bool_feature(sentence_like))
  set_feature(
    out,
    "figure_reference_sentence_signal",
    bool_feature(figure_reference_sentence),
  )
  set_feature(
    out,
    "section_reference_sentence_signal",
    bool_feature(section_reference_sentence),
  )
  set_feature(
    out,
    "technical_sentence_guard_signal",
    bool_feature(technical_sentence_guard),
  )
  set_feature(
    out,
    "citation_reference_signal",
    bool_feature(citation_reference),
  )
  set_feature(
    out,
    "caption_marker_signal",
    bool_feature(caption_marker_signal(block.text)),
  )
  set_feature(out, "caption_marker_figure", bool_feature(caption_marker_figure))
  set_feature(out, "caption_marker_table", bool_feature(caption_marker_table))
  set_feature(
    out,
    "caption_marker_starts_line",
    bool_feature(caption_marker_starts_line),
  )
  set_feature(
    out,
    "caption_reference_only_signal",
    bool_feature(caption_reference_only_signal(block.text)),
  )
  set_feature(
    out,
    "caption_lead_in_signal",
    bool_feature(caption_lead_in_signal(block.text)),
  )
  set_feature(
    out,
    "near_image_object_signal",
    bool_feature(near_image_object_signal(near_image_distance)),
  )
  set_feature_opt(
    out,
    "caption_object_distance_ratio",
    normalized_object_distance_ratio(near_image_distance, page_height),
  )
  set_feature(
    out,
    "caption_heading_conflict_signal",
    bool_feature(
      caption_heading_conflict_signal(
        caption_marker_starts_line, block, page_box, page_median_font_size,
      ),
    ),
  )
  set_feature(
    out,
    "asset_metadata_noise_signal",
    bool_feature(asset_metadata_noise_signal(block.text)),
  )
  set_feature(
    out,
    "has_raw_hyphen",
    bool_feature(has_raw_hyphen_signal(block.text)),
  )
  set_feature(
    out,
    "ends_with_colon",
    bool_feature(ends_with_colon_signal(block.text)),
  )
  set_feature(
    out,
    "has_terminal_period",
    bool_feature(has_terminal_period_signal(block.text)),
  )
  set_feature(
    out,
    "contains_clause_punctuation",
    bool_feature(contains_clause_punctuation_signal(block.text)),
  )
  set_feature(
    out,
    "has_markdown_escape_chars",
    bool_feature(has_markdown_escape_chars_signal(block.text)),
  )
  set_feature(
    out,
    "form_key_value_signal",
    bool_feature(form_key_value_signal(block.text)),
  )
  set_feature(
    out,
    "option_like_signal",
    bool_feature(option_like_signal(block.text)),
  )
  set_feature(
    out,
    "top_zone_candidate",
    bool_feature(top_zone_candidate(block._bbox, page_box)),
  )
  set_feature(
    out,
    "bottom_zone_candidate",
    bool_feature(bottom_zone_candidate(block._bbox, page_box)),
  )
  set_feature(
    out,
    "repeated_edge_candidate",
    bool_feature(repeated_edge_candidate(block, page_box, repeated_text_score)),
  )
  set_feature(
    out,
    "code_like_signal",
    bool_feature(code_like_signal(block.text)),
  )
  set_feature(out, "monospace_hint", bool_feature(monospace_hint(block)))
  set_feature(out, "sku_like_signal", bool_feature(sku_like))
  set_feature(out, "quantity_price_signal", bool_feature(quantity_price))
  set_feature(out, "payment_card_signal", bool_feature(payment_card))
  set_feature(
    out,
    "receipt_line_item_signal",
    bool_feature(sku_like && quantity_price),
  )
  zero_boundary_fields(out)
  out
}

///|
fn boundary_layout_feature_values(
  prev_page : PdfConvertPage,
  cur_page : PdfConvertPage,
) -> Map[String, Double] {
  let out : Map[String, Double] = Map([])
  let decision = collect_page_boundary_merge_evidence(prev_page, cur_page)
  set_feature(out, "text_len", 0.0)
  set_feature(out, "normalized_text_len", 0.0)
  set_feature(out, "word_count", 0.0)
  set_feature(out, "digit_ratio", 0.0)
  set_feature(out, "punctuation_ratio", 0.0)
  set_feature(out, "uppercase_ratio", 0.0)
  set_feature(out, "cjk_ratio", 0.0)
  set_feature(out, "latin_ratio", 0.0)
  set_feature(out, "symbol_ratio", 0.0)
  set_feature(out, "x0", 0.0)
  set_feature(out, "y0", 0.0)
  set_feature(out, "x1", 0.0)
  set_feature(out, "y1", 0.0)
  set_feature(out, "width", 0.0)
  set_feature(out, "height", 0.0)
  set_feature(out, "text_density", 0.0)
  set_feature(out, "page_width", 0.0)
  set_feature(out, "page_height", 0.0)
  set_feature(out, "page_line_count", 0.0)
  set_feature(out, "page_block_count", 0.0)
  set_feature(out, "page_median_font_size", 0.0)
  set_feature(out, "relative_font_size", 0.0)
  set_feature(out, "x_center_ratio", 0.0)
  set_feature(out, "y_center_ratio", 0.0)
  set_feature(out, "top_ratio", 0.0)
  set_feature(out, "bottom_ratio", 0.0)
  set_feature(out, "top_zone_candidate", 0.0)
  set_feature(out, "bottom_zone_candidate", 0.0)
  set_feature(out, "repeated_edge_candidate", 0.0)
  set_feature(out, "font_size_hint", 0.0)
  set_feature(out, "bold_hint", 0.0)
  set_feature(out, "line_gap_before", 0.0)
  set_feature(out, "line_gap_after", 0.0)
  set_feature(out, "indent_left", 0.0)
  set_feature(out, "alignment_hint", 0.0)
  set_feature(out, "near_image_distance", 0.0)
  set_feature(out, "near_annotation_distance", 0.0)
  set_feature(out, "near_link_annotation_distance", 0.0)
  set_feature(out, "near_uri_annotation_distance", 0.0)
  set_feature(out, "near_dest_annotation_distance", 0.0)
  set_feature(out, "page_edge_distance", 0.0)
  set_feature(out, "repeated_text_score", 0.0)
  set_feature(out, "source_ref_count", 0.0)
  set_feature(out, "has_rich_inline_payload", 0.0)
  set_feature(out, "has_link_inline", 0.0)
  set_feature(out, "link_inline_count", 0.0)
  set_feature(out, "link_overlap_ratio", 0.0)
  set_feature(out, "link_text_coverage_ratio", 0.0)
  set_feature(out, "has_partial_link", 0.0)
  set_feature(out, "is_link_only_candidate", 0.0)
  set_feature(out, "link_target_uri", 0.0)
  set_feature(out, "link_target_internal", 0.0)
  set_feature(out, "link_target_named", 0.0)
  set_feature(out, "link_target_mixed", 0.0)
  set_feature(out, "page_number_like_link", 0.0)
  set_feature(out, "toc_like_anchor_signal", 0.0)
  set_feature(out, "visible_url_without_annotation", 0.0)
  set_feature(out, "page_label_pattern_signal", 0.0)
  set_feature(out, "cleanup_shell_signal", 0.0)
  set_feature(out, "is_heading_candidate", 0.0)
  set_feature(out, "is_page_number_candidate", 0.0)
  set_feature(out, "is_header_footer_candidate", 0.0)
  set_feature(out, "is_artifact_candidate", 0.0)
  set_feature(out, "is_caption_candidate", 0.0)
  set_feature(out, "is_table_cell_candidate", 0.0)
  set_feature(out, "is_noise_kind", 0.0)
  set_feature(out, "is_heading_kind", 0.0)
  set_feature(out, "line_count", 0.0)
  set_feature(out, "prev_gap_before", 0.0)
  set_feature(out, "next_gap_before", 0.0)
  set_feature(out, "prev_font_size_delta", 0.0)
  set_feature(out, "next_font_size_delta", 0.0)
  set_feature(
    out,
    "same_paragraph_candidate",
    bool_feature(decision.same_paragraph_candidate),
  )
  set_feature(
    out,
    "wrapped_candidate",
    bool_feature(decision.wrapped_line_continuation),
  )
  set_feature(out, "contains_currency", 0.0)
  set_feature(out, "contains_time", 0.0)
  set_feature(out, "contains_date", 0.0)
  set_feature(out, "looks_like_address", 0.0)
  set_feature(out, "looks_like_separator", 0.0)
  set_feature(out, "looks_like_page_number", 0.0)
  set_feature(out, "looks_like_bullet", 0.0)
  set_feature(out, "looks_like_list_marker_token", 0.0)
  set_feature(out, "contains_url", 0.0)
  set_feature(out, "contains_email", 0.0)
  set_feature(out, "contains_url_or_email", 0.0)
  set_feature(out, "contains_path_like", 0.0)
  set_feature(out, "identifier_like_signal", 0.0)
  set_feature(out, "technical_literal_signal", 0.0)
  set_feature(out, "sentence_like_signal", 0.0)
  set_feature(out, "figure_reference_sentence_signal", 0.0)
  set_feature(out, "section_reference_sentence_signal", 0.0)
  set_feature(out, "technical_sentence_guard_signal", 0.0)
  set_feature(out, "citation_reference_signal", 0.0)
  set_feature(out, "caption_marker_signal", 0.0)
  set_feature(out, "caption_marker_figure", 0.0)
  set_feature(out, "caption_marker_table", 0.0)
  set_feature(out, "caption_marker_starts_line", 0.0)
  set_feature(out, "caption_reference_only_signal", 0.0)
  set_feature(out, "caption_lead_in_signal", 0.0)
  set_feature(out, "near_image_object_signal", 0.0)
  set_feature(out, "caption_object_distance_ratio", 0.0)
  set_feature(out, "caption_heading_conflict_signal", 0.0)
  set_feature(out, "asset_metadata_noise_signal", 0.0)
  set_feature(out, "has_raw_hyphen", 0.0)
  set_feature(out, "ends_with_colon", 0.0)
  set_feature(out, "has_terminal_period", 0.0)
  set_feature(out, "contains_clause_punctuation", 0.0)
  set_feature(out, "has_markdown_escape_chars", 0.0)
  set_feature(out, "form_key_value_signal", 0.0)
  set_feature(out, "option_like_signal", 0.0)
  set_feature(out, "code_like_signal", 0.0)
  set_feature(out, "monospace_hint", 0.0)
  set_feature(out, "sku_like_signal", 0.0)
  set_feature(out, "quantity_price_signal", 0.0)
  set_feature(out, "payment_card_signal", 0.0)
  set_feature(out, "receipt_line_item_signal", 0.0)
  set_feature(
    out,
    "boundary_prev_no_sentence_end",
    bool_feature(decision.previous_no_sentence_end),
  )
  set_feature(
    out,
    "boundary_next_starts_lowercase",
    bool_feature(decision.next_starts_lowercase),
  )
  set_feature(
    out,
    "boundary_next_continues_sentence",
    bool_feature(decision.next_continues_sentence),
  )
  set_feature(
    out,
    "boundary_similar_indent",
    bool_feature(decision.similar_indent),
  )
  set_feature(
    out,
    "boundary_same_column_band",
    bool_feature(decision.same_column_band),
  )
  set_feature(out, "boundary_table_guard", bool_feature(decision.table_guard))
  set_feature(
    out,
    "boundary_caption_guard",
    bool_feature(decision.caption_guard),
  )
  set_feature(out, "boundary_noise_guard", bool_feature(decision.noise_guard))
  set_feature(
    out,
    "boundary_heading_guard",
    bool_feature(decision.heading_guard),
  )
  set_feature(out, "boundary_list_guard", bool_feature(decision.list_guard))
  set_feature(
    out,
    "boundary_layout_compatible",
    bool_feature(decision.layout_compatible),
  )
  out
}

///|
fn set_feature(out : Map[String, Double], key : String, value : Double) -> Unit {
  out.set(key, value)
}

///|
fn set_feature_opt(
  out : Map[String, Double],
  key : String,
  value : Double?,
) -> Unit {
  match value {
    Some(v) => out.set(key, v)
    None => ()
  }
}

///|
fn zero_boundary_fields(out : Map[String, Double]) -> Unit {
  set_feature(out, "boundary_prev_no_sentence_end", 0.0)
  set_feature(out, "boundary_next_starts_lowercase", 0.0)
  set_feature(out, "boundary_next_continues_sentence", 0.0)
  set_feature(out, "boundary_similar_indent", 0.0)
  set_feature(out, "boundary_same_column_band", 0.0)
  set_feature(out, "boundary_table_guard", 0.0)
  set_feature(out, "boundary_caption_guard", 0.0)
  set_feature(out, "boundary_noise_guard", 0.0)
  set_feature(out, "boundary_heading_guard", 0.0)
  set_feature(out, "boundary_list_guard", 0.0)
  set_feature(out, "boundary_layout_compatible", 0.0)
}
