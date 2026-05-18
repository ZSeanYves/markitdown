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

///|
fn summarize_block_link_features(
  page : PdfConvertPage,
  block : PdfConvertBlock,
) -> PdfBlockLinkFeatureSummary {
  let lines = block_feature_lines(page, block)
  let line_overlap_ratios : Array[Double] = []
  for _line in lines {
    line_overlap_ratios.push(0.0)
  }

  let mut has_uri_target = false
  let mut has_internal_target = false
  let mut has_named_target = false

  for annotation in page.annotations {
    if !is_link_annotation_feature(annotation) {
      continue
    }

    let mut relevant = rect_distance(block._bbox, annotation._bbox) <= 8.0
    for i = 0; i < lines.length(); i = i + 1 {
      let ratio = annotation_line_overlap_ratio(annotation, lines[i])
      if ratio > 0.0 {
        relevant = true
      }
      if ratio > line_overlap_ratios[i] {
        line_overlap_ratios[i] = ratio
      }
    }
    if !relevant {
      continue
    }
    if has_uri_annotation_feature(annotation) {
      has_uri_target = true
    }
    if has_internal_annotation_feature(annotation) {
      has_internal_target = true
    }
    if has_named_annotation_feature(annotation) {
      has_named_target = true
    }
  }

  let mut max_overlap = 0.0
  let mut covered_chars = 0.0
  let mut total_chars = 0.0
  for i = 0; i < lines.length(); i = i + 1 {
    let line_text_len = max_feature_f64(lines[i].text.length().to_double(), 1.0)
    total_chars += line_text_len
    covered_chars += line_text_len * line_overlap_ratios[i]
    if line_overlap_ratios[i] > max_overlap {
      max_overlap = line_overlap_ratios[i]
    }
  }
  if total_chars <= 0.0 {
    total_chars = max_feature_f64(block.text.length().to_double(), 1.0)
  }
  let coverage_ratio = min_feature_f64(covered_chars / total_chars, 1.0)
  let toc_like_anchor = toc_like_anchor_signal(block.text)
  let page_number_like = looks_like_page_number_signal(block.text)
  let paragraph_url_context = (
      contains_url_signal(block.text) || contains_email_signal(block.text)
    ) &&
    (
      count_feature_words(block.text) >= 8 ||
      has_terminal_period_signal(block.text) ||
      contains_clause_punctuation_signal(block.text) ||
      ends_with_colon_signal(block.text)
    )
  let target_kind_count = (if has_uri_target { 1 } else { 0 }) +
    (if has_internal_target { 1 } else { 0 }) +
    (if has_named_target { 1 } else { 0 })

  {
    overlap_ratio: max_overlap,
    text_coverage_ratio: coverage_ratio,
    has_partial_link: coverage_ratio >= 0.10 && coverage_ratio < 0.80,
    is_link_only_candidate: coverage_ratio >= 0.80 &&
    (
      toc_like_anchor ||
      page_number_like ||
      (!paragraph_url_context && count_feature_words(block.text) <= 4)
    ),
    has_uri_target,
    has_internal_target,
    has_named_target,
    has_mixed_target: target_kind_count >= 2,
  }
}

///|
fn block_feature_lines(
  page : PdfConvertPage,
  block : PdfConvertBlock,
) -> Array[PdfConvertLine] {
  let out : Array[PdfConvertLine] = []
  for line in page.lines {
    if line.line_index >= block.line_start && line.line_index <= block.line_end {
      out.push(line)
    }
  }
  out
}

///|
fn count_feature_words(text : String) -> Int {
  if text.trim() == "" {
    return 0
  }

  let mut count = 0
  for part in text.split(" ") {
    if part.trim() != "" {
      count += 1
    }
  }
  count
}

///|
fn digit_ratio(text : String) -> Double {
  char_ratio(text, fn(ch) { ch >= '0' && ch <= '9' })
}

///|
fn punctuation_ratio(text : String) -> Double {
  char_ratio(text, is_feature_punctuation)
}

///|
fn uppercase_ratio(text : String) -> Double {
  char_ratio(text, fn(ch) { ch >= 'A' && ch <= 'Z' })
}

///|
fn cjk_ratio(text : String) -> Double {
  char_ratio(text, is_feature_cjk)
}

///|
fn latin_ratio(text : String) -> Double {
  char_ratio(text, is_feature_latin)
}

///|
fn symbol_ratio(text : String) -> Double {
  char_ratio(text, is_feature_symbol)
}

///|
fn char_ratio(text : String, pred : (Char) -> Bool) -> Double {
  let chars = text.to_array()
  if chars.length() == 0 {
    return 0.0
  }

  let mut hits = 0
  for ch in chars {
    if pred(ch) {
      hits += 1
    }
  }
  hits.to_double() / chars.length().to_double()
}

///|
fn text_density(text : String, rect : @model.PdfRect) -> Double {
  let area = @model.rect_width(rect) * @model.rect_height(rect)
  if area <= 0.0 {
    return 0.0
  }
  text.length().to_double() / area
}

///|
fn is_feature_punctuation(ch : Char) -> Bool {
  ch == '.' ||
  ch == ',' ||
  ch == ':' ||
  ch == ';' ||
  ch == '!' ||
  ch == '?' ||
  ch == '-' ||
  ch == '(' ||
  ch == ')' ||
  ch == '[' ||
  ch == ']' ||
  ch == '{' ||
  ch == '}' ||
  ch == '"' ||
  ch == '\'' ||
  ch == '。' ||
  ch == '，' ||
  ch == '：' ||
  ch == '；' ||
  ch == '！' ||
  ch == '？'
}

///|
fn is_feature_latin(ch : Char) -> Bool {
  (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')
}

///|
fn is_feature_symbol(ch : Char) -> Bool {
  !(is_feature_latin(ch) ||
  is_feature_cjk(ch) ||
  (ch >= '0' && ch <= '9') ||
  is_feature_whitespace(ch) ||
  is_feature_punctuation(ch))
}

///|
fn is_feature_whitespace(ch : Char) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}

///|
fn is_feature_cjk(ch : Char) -> Bool {
  let v = ch.to_int()
  (v >= 0x4E00 && v <= 0x9FFF) ||
  (v >= 0x3400 && v <= 0x4DBF) ||
  (v >= 0x3040 && v <= 0x30FF) ||
  (v >= 0xAC00 && v <= 0xD7AF)
}

///|
fn rect_center_x_ratio(
  rect : @model.PdfRect,
  page_box : @model.PdfRect,
) -> Double {
  let width = @model.rect_width(page_box)
  if width <= 0.0 {
    return 0.0
  }
  ((rect.x0 + rect.x1) / 2.0 - page_box.x0) / width
}

///|
fn rect_center_y_ratio(
  rect : @model.PdfRect,
  page_box : @model.PdfRect,
) -> Double {
  let height = @model.rect_height(page_box)
  if height <= 0.0 {
    return 0.0
  }
  ((rect.y0 + rect.y1) / 2.0 - page_box.y0) / height
}

///|
fn top_ratio(rect : @model.PdfRect, page_box : @model.PdfRect) -> Double {
  let height = @model.rect_height(page_box)
  if height <= 0.0 {
    return 0.0
  }
  (page_box.y1 - rect.y1) / height
}

///|
fn bottom_ratio(rect : @model.PdfRect, page_box : @model.PdfRect) -> Double {
  let height = @model.rect_height(page_box)
  if height <= 0.0 {
    return 0.0
  }
  (rect.y0 - page_box.y0) / height
}

///|
fn page_edge_distance(
  rect : @model.PdfRect,
  page_box : @model.PdfRect,
) -> Double {
  let top = abs_feature_f64(page_box.y1 - rect.y1)
  let bottom = abs_feature_f64(rect.y0 - page_box.y0)
  let left = abs_feature_f64(rect.x0 - page_box.x0)
  let right = abs_feature_f64(page_box.x1 - rect.x1)
  min_feature_f64(min_feature_f64(top, bottom), min_feature_f64(left, right))
}

///|
fn nearest_annotation_distance(
  annotations : Array[PdfConvertAnnotation],
  rect : @model.PdfRect,
) -> Double? {
  nearest_filtered_annotation_distance(annotations, rect, fn(_annotation) {
    true
  })
}

///|
fn nearest_link_annotation_distance(
  annotations : Array[PdfConvertAnnotation],
  rect : @model.PdfRect,
) -> Double? {
  nearest_filtered_annotation_distance(
    annotations, rect, is_link_annotation_feature,
  )
}

///|
fn nearest_uri_annotation_distance(
  annotations : Array[PdfConvertAnnotation],
  rect : @model.PdfRect,
) -> Double? {
  nearest_filtered_annotation_distance(
    annotations, rect, has_uri_annotation_feature,
  )
}

///|
fn nearest_dest_annotation_distance(
  annotations : Array[PdfConvertAnnotation],
  rect : @model.PdfRect,
) -> Double? {
  nearest_filtered_annotation_distance(
    annotations, rect, has_dest_annotation_feature,
  )
}

///|
fn nearest_filtered_annotation_distance(
  annotations : Array[PdfConvertAnnotation],
  rect : @model.PdfRect,
  pred : (PdfConvertAnnotation) -> Bool,
) -> Double? {
  let mut best : Double? = None
  for annotation in annotations {
    if !pred(annotation) {
      continue
    }
    let distance = rect_distance(rect, annotation._bbox)
    match best {
      Some(prev) => if distance < prev { best = Some(distance) }
      None => best = Some(distance)
    }
  }
  best
}

///|
fn rect_distance(a : @model.PdfRect, b : @model.PdfRect) -> Double {
  let horizontal_gap = if a.x1 < b.x0 {
    b.x0 - a.x1
  } else if b.x1 < a.x0 {
    a.x0 - b.x1
  } else {
    0.0
  }
  let vertical_gap = if a.y1 < b.y0 {
    b.y0 - a.y1
  } else if b.y1 < a.y0 {
    a.y0 - b.y1
  } else {
    0.0
  }
  horizontal_gap + vertical_gap
}

///|
fn is_link_annotation_feature(annotation : PdfConvertAnnotation) -> Bool {
  let subtype = annotation.subtype.to_lower()
  subtype == "link" ||
  subtype == "/link" ||
  has_uri_annotation_feature(annotation) ||
  has_dest_annotation_feature(annotation)
}

///|
fn has_uri_annotation_feature(annotation : PdfConvertAnnotation) -> Bool {
  match annotation.uri {
    Some(uri) => uri.trim() != ""
    None => false
  }
}

///|
fn has_dest_annotation_feature(annotation : PdfConvertAnnotation) -> Bool {
  match annotation.dest {
    Some(dest) => dest.trim() != ""
    None => annotation.target_page is Some(_)
  }
}

///|
fn has_internal_annotation_feature(annotation : PdfConvertAnnotation) -> Bool {
  annotation.target_page is Some(_)
}

///|
fn has_named_annotation_feature(annotation : PdfConvertAnnotation) -> Bool {
  match annotation.dest {
    Some(dest) => dest.trim() != "" && annotation.target_page is None
    None => false
  }
}

///|
fn block_source_ref_count(block : PdfConvertBlock) -> Int {
  block.source_block_line_count
}

///|
fn page_median_font_size(page : PdfConvertPage) -> Double? {
  let values : Array[Double] = []
  for block in page.blocks {
    match block.dominant_font_size {
      Some(v) => if v > 0.0 { values.push(v) }
      None => ()
    }
  }
  if values.is_empty() {
    return None
  }
  values.sort()
  let mid = values.length() / 2
  if values.length() % 2 == 1 {
    Some(values[mid])
  } else {
    Some((values[mid - 1] + values[mid]) / 2.0)
  }
}

///|
fn relative_font_size(current : Double?, baseline : Double?) -> Double? {
  match (current, baseline) {
    (Some(value), Some(base)) =>
      if base > 0.0 {
        Some(value / base)
      } else {
        None
      }
    _ => None
  }
}

///|
fn bold_hint(block : PdfConvertBlock) -> Double {
  match block.dominant_font_name {
    Some(name) => if name.to_lower().contains("bold") { 1.0 } else { 0.0 }
    None => 0.0
  }
}

///|
fn has_rich_inline_payload(block : PdfConvertBlock) -> Bool {
  match block.rich_inlines {
    Some(inlines) => {
      if inlines.length() > 1 {
        return true
      }
      for inline in inlines {
        match inline {
          @cor.Inline::Text(_) => ()
          _ => return true
        }
      }
      false
    }
    None => false
  }
}

///|
fn has_link_inline(block : PdfConvertBlock) -> Bool {
  match block.rich_inlines {
    Some(inlines) => {
      for inline in inlines {
        match inline {
          @cor.Inline::Link(_, _) => return true
          _ => ()
        }
      }
      false
    }
    None => false
  }
}

///|
fn link_inline_count(block : PdfConvertBlock) -> Int {
  match block.rich_inlines {
    Some(inlines) => {
      let mut count = 0
      for inline in inlines {
        match inline {
          @cor.Inline::Link(_, _) => count += 1
          _ => ()
        }
      }
      count
    }
    None => 0
  }
}

///|
fn contains_currency_signal(text : String) -> Bool {
  let lower = text.to_lower()
  text.contains("$") ||
  text.contains("¥") ||
  text.contains("￥") ||
  text.contains("€") ||
  text.contains("£") ||
  lower.contains("usd") ||
  lower.contains("eur") ||
  lower.contains("cny") ||
  lower.contains("rmb")
}

///|
fn contains_time_signal(text : String) -> Bool {
  let chars = text.to_array()
  for i = 1; i + 1 < chars.length(); i = i + 1 {
    if chars[i] == ':' &&
      is_ascii_digit(chars[i - 1]) &&
      is_ascii_digit(chars[i + 1]) {
      return true
    }
  }
  false
}

///|
fn contains_date_signal(text : String) -> Bool {
  let lower = text.to_lower()
  let chars = text.to_array()
  for i = 1; i + 1 < chars.length(); i = i + 1 {
    let ch = chars[i]
    if (ch == '/' || ch == '-') &&
      is_ascii_digit(chars[i - 1]) &&
      is_ascii_digit(chars[i + 1]) {
      return true
    }
  }
  lower.contains("jan ") ||
  lower.contains("feb ") ||
  lower.contains("mar ") ||
  lower.contains("apr ") ||
  lower.contains("may ") ||
  lower.contains("jun ") ||
  lower.contains("jul ") ||
  lower.contains("aug ") ||
  lower.contains("sep ") ||
  lower.contains("oct ") ||
  lower.contains("nov ") ||
  lower.contains("dec ")
}

///|
fn looks_like_address_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  if trimmed == "" {
    return false
  }
  if trimmed.contains(", ") && looks_like_us_state_zip_suffix(trimmed) {
    return true
  }
  begins_with_digit(trimmed) &&
  (
    lower.contains(" street") ||
    lower.contains(" st ") ||
    lower.contains(" avenue") ||
    lower.contains(" ave ") ||
    lower.contains(" road") ||
    lower.contains(" rd ") ||
    lower.contains(" boulevard") ||
    lower.contains(" blvd") ||
    lower.contains(" suite ") ||
    lower.contains(" ste ")
  )
}

///|
fn looks_like_separator_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  let chars = trimmed.to_array()
  let mut symbol_count = 0
  let symbols : Array[Char] = []
  for ch in chars {
    if is_feature_whitespace(ch) {
      continue
    }
    if !is_feature_latin(ch) && !is_feature_cjk(ch) && !is_ascii_digit(ch) {
      symbol_count += 1
      symbols.push(ch)
    } else {
      return false
    }
  }
  symbol_count >= 4 ||
  (symbol_count >= 2 && repeated_separator_symbol_run(symbols))
}

///|
fn looks_like_page_number_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  if all_ascii_digits_feature(trimmed) && trimmed.length() <= 4 {
    return true
  }
  if looks_like_cjk_page_number(trimmed) {
    return true
  }
  let lower = trimmed.to_lower()
  if !lower.has_prefix("page ") {
    return false
  }
  let chars = lower.to_array()
  let suffix : Array[Char] = []
  for i = 5; i < chars.length(); i = i + 1 {
    suffix.push(chars[i])
  }
  all_ascii_digits_feature(String::from_array(suffix))
}

///|
fn looks_like_bullet_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  trimmed.has_prefix("- ") ||
  trimmed.has_prefix("* ") ||
  trimmed.has_prefix("+ ") ||
  trimmed.has_prefix("• ") ||
  trimmed.has_prefix("•") ||
  trimmed.has_prefix(" ") ||
  trimmed.has_prefix("") ||
  trimmed.has_prefix("1. ") ||
  trimmed.has_prefix("a) ")
}

///|
fn contains_url_signal(text : String) -> Bool {
  let lower = text.to_lower()
  lower.contains("http://") ||
  lower.contains("https://") ||
  lower.contains("www.") ||
  lower.contains("mailto:")
}

///|
fn contains_email_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let chars = trimmed.to_array()
  let mut at = -1
  for i = 0; i < chars.length(); i = i + 1 {
    if chars[i] == '@' {
      at = i
      break
    }
  }
  if at <= 0 || at + 1 >= chars.length() {
    return false
  }
  if is_feature_whitespace(chars[at - 1]) ||
    is_feature_whitespace(chars[at + 1]) {
    return false
  }
  let mut local_start = at
  for i = at - 1; i >= 0; i = i - 1 {
    if is_feature_whitespace(chars[i]) {
      break
    }
    local_start = i
  }
  let mut domain_end = at
  for i = at + 1; i < chars.length(); i = i + 1 {
    if is_feature_whitespace(chars[i]) {
      break
    }
    domain_end = i
  }
  if local_start >= at || domain_end <= at {
    return false
  }
  let local_part = String::from_array(chars[local_start:at].to_owned())
  let domain = String::from_array(chars[at + 1:domain_end + 1].to_owned())
  valid_email_local_part(local_part) && valid_email_domain_part(domain)
}

///|
fn valid_email_local_part(local_part : String) -> Bool {
  let trimmed = local_part.trim().to_owned()
  let chars = trimmed.to_array()
  if chars.length() == 0 {
    return false
  }
  let mut has_alnum = false
  for ch in chars {
    if !email_local_char(ch) {
      return false
    }
    if is_ascii_alpha(ch) || is_ascii_digit(ch) {
      has_alnum = true
    }
  }
  has_alnum &&
  chars[0] != '.' &&
  chars[0] != '-' &&
  chars[chars.length() - 1] != '.' &&
  chars[chars.length() - 1] != '-'
}

///|
fn email_local_char(ch : Char) -> Bool {
  is_ascii_alpha(ch) ||
  is_ascii_digit(ch) ||
  ch == '.' ||
  ch == '_' ||
  ch == '-' ||
  ch == '+'
}

///|
fn valid_email_domain_part(domain : String) -> Bool {
  let trimmed = domain.trim().to_owned()
  let chars = trimmed.to_array()
  if chars.length() < 4 {
    return false
  }
  if chars[0] == '.' ||
    chars[0] == '-' ||
    chars[chars.length() - 1] == '.' ||
    chars[chars.length() - 1] == '-' {
    return false
  }
  let mut has_dot = false
  let mut last_dot = -1
  let mut has_alpha = false
  for i = 0; i < chars.length(); i = i + 1 {
    let ch = chars[i]
    if !email_domain_char(ch) {
      return false
    }
    if is_ascii_alpha(ch) {
      has_alpha = true
    }
    if ch == '.' {
      if i == 0 ||
        i + 1 >= chars.length() ||
        chars[i - 1] == '.' ||
        chars[i + 1] == '.' ||
        chars[i - 1] == '-' ||
        chars[i + 1] == '-' {
        return false
      }
      has_dot = true
      last_dot = i
    }
  }
  if !has_dot || !has_alpha || last_dot <= 0 || last_dot + 1 >= chars.length() {
    return false
  }
  let suffix = String::from_array(chars[last_dot + 1:].to_owned())
  suffix.length() >= 2 && contains_ascii_alpha_text(suffix)
}

///|
fn email_domain_char(ch : Char) -> Bool {
  is_ascii_alpha(ch) || is_ascii_digit(ch) || ch == '.' || ch == '-'
}

///|
fn has_raw_hyphen_signal(text : String) -> Bool {
  text.contains("-") ||
  text.contains("‐") ||
  text.contains("‑") ||
  text.contains("–")
}

///|
fn ends_with_colon_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  trimmed.has_suffix(":") || trimmed.has_suffix("：")
}

///|
fn has_terminal_period_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  trimmed.has_suffix(".") ||
  trimmed.has_suffix("!") ||
  trimmed.has_suffix("?") ||
  trimmed.has_suffix("。") ||
  trimmed.has_suffix("！") ||
  trimmed.has_suffix("？")
}

///|
fn sentence_end_evidence_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  has_terminal_period_signal(trimmed) ||
  contains_clause_punctuation_signal(trimmed) ||
  trimmed.contains(". (") ||
  trimmed.contains(".(") ||
  trimmed.contains("。(") ||
  trimmed.contains("。 (")
}

///|
fn contains_clause_punctuation_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  for ch in trimmed.to_array() {
    if ch == ',' ||
      ch == ';' ||
      ch == ':' ||
      ch == '，' ||
      ch == '、' ||
      ch == '；' ||
      ch == '：' {
      return true
    }
  }
  false
}

///|
fn has_markdown_escape_chars_signal(text : String) -> Bool {
  text.contains("#") ||
  text.contains("*") ||
  text.contains("[") ||
  text.contains("]") ||
  text.contains("`") ||
  text.contains(">") ||
  text.contains("|")
}

///|
fn form_key_value_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  (trimmed.contains(":") || trimmed.contains("：")) &&
  count_feature_words(trimmed) <= 4 &&
  !has_terminal_period_signal(trimmed)
}

///|
fn option_like_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  if trimmed == "" {
    return false
  }
  if lower.contains("usage:") ||
    lower.contains("command line") ||
    lower.contains(" switch") ||
    lower.contains(" option") {
    return true
  }
  if trimmed.contains("<") && trimmed.contains(">") {
    return true
  }
  if has_raw_hyphen_signal(trimmed) &&
    ((trimmed.contains("[") && trimmed.contains("]")) || trimmed.contains("=")) {
    return true
  }
  if !(trimmed.has_prefix("--") ||
    trimmed.has_prefix("- - ") ||
    starts_with_short_option_cluster_signal(trimmed)) {
    return false
  }
  lower.contains("timeout") ||
  lower.contains("help") ||
  lower.contains("fatal") ||
  lower.contains("warn") ||
  lower.contains("usage") ||
  lower.contains("python") ||
  lower.contains("listcheck") ||
  lower.contains("listmessage") ||
  lower.contains("custommessage") ||
  lower.contains("logdir") ||
  lower.contains("logfile") ||
  lower.contains("jsondir") ||
  lower.contains(".json") ||
  lower.contains(".jar") ||
  lower.contains(".py") ||
  trimmed.contains("<") ||
  trimmed.contains(">") ||
  trimmed.contains("=")
}

///|
fn starts_with_short_option_cluster_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let chars = trimmed.to_array()
  if chars.length() >= 3 &&
    chars[0] == '-' &&
    is_ascii_alpha(chars[1]) &&
    (chars[2] == ',' || is_feature_whitespace(chars[2])) {
    return true
  }
  chars.length() >= 4 &&
  is_ascii_alpha(chars[0]) &&
  chars[1] == ',' &&
  is_feature_whitespace(chars[2]) &&
  chars[3] == '-'
}

///|
fn top_zone_candidate(rect : @model.PdfRect, page_box : @model.PdfRect) -> Bool {
  top_ratio(rect, page_box) <= 0.12
}

///|
fn bottom_zone_candidate(
  rect : @model.PdfRect,
  page_box : @model.PdfRect,
) -> Bool {
  bottom_ratio(rect, page_box) <= 0.12
}

///|
fn repeated_edge_candidate(
  block : PdfConvertBlock,
  page_box : @model.PdfRect,
  repeated_text_score : Double,
) -> Bool {
  repeated_text_score >= 0.34 &&
  block.line_count <= 2 &&
  (
    top_zone_candidate(block._bbox, page_box) ||
    bottom_zone_candidate(block._bbox, page_box)
  )
}

///|
fn looks_like_list_marker_token_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  if trimmed == "-" ||
    trimmed == "*" ||
    trimmed == "+" ||
    trimmed == "•" ||
    trimmed == "" {
    return true
  }
  let chars = trimmed.to_array()
  if chars.length() == 2 &&
    is_ascii_alpha(chars[0]) &&
    (chars[1] == '.' || chars[1] == ')') {
    return true
  }
  if chars.length() >= 2 &&
    chars[0] == '.' &&
    all_ascii_digits_feature(String::from_array(chars[1:].to_owned())) {
    return true
  }
  let last = chars[chars.length() - 1]
  if (last == '.' || last == ')') &&
    all_ascii_digits_feature(
      String::from_array(chars[:chars.length() - 1].to_owned()),
    ) {
    return true
  }
  false
}

///|
fn contains_path_like_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  if trimmed == "" {
    return false
  }
  if lower.contains("://") || contains_email_signal(trimmed) {
    return false
  }
  if trimmed.has_prefix("./") ||
    trimmed.has_prefix("../") ||
    trimmed.has_prefix("~/") ||
    trimmed.contains("\\") ||
    looks_like_windows_drive_path(trimmed) {
    return true
  }
  if looks_like_dotted_identifier_signal(trimmed) {
    return true
  }
  if lower.contains(".pdf") ||
    lower.contains(".epub") ||
    lower.contains(".xhtml") ||
    lower.contains(".html") ||
    lower.contains(".xml") ||
    lower.contains(".json") ||
    lower.contains(".txt") ||
    lower.contains(".py") ||
    lower.contains(".js") ||
    lower.contains(".css") ||
    lower.contains(".md") {
    return true
  }
  let slash_count = count_char_feature(trimmed, '/')
  slash_count >= 2 &&
  !trimmed.contains(" ") &&
  contains_ascii_alpha_text(trimmed)
}

///|
fn identifier_like_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  if contains_url_signal(trimmed) || contains_email_signal(trimmed) {
    return false
  }
  if looks_like_dotted_identifier_signal(trimmed) ||
    looks_like_windows_drive_path(trimmed) ||
    trimmed.contains("::") {
    return true
  }
  if trimmed.contains("=") && contains_camel_case_token_signal(trimmed) {
    return true
  }
  contains_camel_case_token_signal(trimmed) && count_feature_words(trimmed) <= 3
}

///|
fn technical_literal_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  if contains_url_signal(trimmed) || contains_email_signal(trimmed) {
    return false
  }
  if contains_date_signal(trimmed) ||
    contains_time_signal(trimmed) ||
    contains_currency_signal(trimmed) {
    return false
  }
  if quantity_price_signal(trimmed) || payment_card_signal(trimmed) {
    return false
  }
  if technical_sentence_guard_signal(trimmed) {
    return false
  }
  if looks_like_bullet_signal(trimmed) &&
    !option_like_signal(trimmed) &&
    count_feature_words(trimmed) >= 4 {
    return false
  }
  if option_like_signal(trimmed) ||
    contains_path_like_signal(trimmed) ||
    assignment_like_signal(trimmed) {
    return true
  }
  let separator_count = technical_separator_count(trimmed)
  (identifier_like_signal(trimmed) && count_feature_words(trimmed) <= 4) ||
  (
    separator_count >= 3 &&
    count_feature_words(trimmed) <= 12 &&
    !has_terminal_period_signal(trimmed)
  ) ||
  (
    contains_camel_case_token_signal(trimmed) &&
    separator_count >= 2 &&
    count_feature_words(trimmed) <= 6
  )
}

///|
fn sentence_like_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let word_count = count_feature_words(trimmed)
  if trimmed == "" || word_count < 5 {
    return false
  }
  if technical_sentence_guard_signal(trimmed) {
    return true
  }
  if technical_literal_signal(trimmed) || !sentence_end_evidence_signal(trimmed) {
    return false
  }
  latin_ratio(trimmed) >= 0.35 ||
  cjk_ratio(trimmed) >= 0.35 ||
  contains_url_signal(trimmed) ||
  contains_email_signal(trimmed)
}

///|
fn figure_reference_sentence_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  let word_count = count_feature_words(trimmed)
  if trimmed == "" || word_count < 6 {
    return false
  }
  if !sentence_end_evidence_signal(trimmed) {
    return false
  }
  if caption_marker_starts_line_signal(trimmed) &&
    !caption_lead_in_signal(trimmed) {
    return false
  }
  let has_reference = contains_enumerated_reference_signal(lower, "figure ") ||
    contains_enumerated_reference_signal(lower, "fig. ") ||
    contains_enumerated_reference_signal(lower, "fig ") ||
    contains_enumerated_reference_signal(lower, "table ") ||
    contains_enumerated_reference_signal(lower, "chart ") ||
    contains_enumerated_reference_signal(lower, "图 ") ||
    contains_enumerated_reference_signal(lower, "表 ")
  has_reference &&
  (
    caption_reference_only_signal(trimmed) ||
    caption_lead_in_signal(trimmed) ||
    lower.contains(" below ") ||
    lower.contains(" above ") ||
    lower.contains(" illustrates ") ||
    lower.contains(" illustrate ") ||
    lower.contains(" shows ") ||
    lower.contains(" show ") ||
    lower.contains(" is given in ")
  )
}

///|
fn section_reference_sentence_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  let word_count = count_feature_words(trimmed)
  if trimmed == "" || word_count < 6 {
    return false
  }
  if !sentence_end_evidence_signal(trimmed) {
    return false
  }
  contains_enumerated_reference_signal(lower, "section ") ||
  contains_enumerated_reference_signal(lower, "sec. ") ||
  contains_enumerated_reference_signal(lower, "sec ")
}

///|
fn technical_sentence_guard_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let word_count = count_feature_words(trimmed)
  if trimmed == "" || word_count < 6 {
    return false
  }
  if !sentence_end_evidence_signal(trimmed) {
    return false
  }
  if contains_path_like_signal(trimmed) ||
    option_like_signal(trimmed) ||
    quantity_price_signal(trimmed) ||
    payment_card_signal(trimmed) {
    return false
  }
  if figure_reference_sentence_signal(trimmed) ||
    section_reference_sentence_signal(trimmed) {
    return true
  }
  word_count >= 9 &&
  (
    contains_camel_case_token_signal(trimmed) ||
    (trimmed.contains("(") && trimmed.contains(")")) ||
    trimmed.contains("=")
  ) &&
  (latin_ratio(trimmed) >= 0.35 || cjk_ratio(trimmed) >= 0.35)
}

///|
fn citation_reference_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let chars = trimmed.to_array()
  if chars.length() < 4 {
    return false
  }
  if chars[0] == '[' {
    let mut close = -1
    for i = 1; i < chars.length(); i = i + 1 {
      if chars[i] == ']' {
        close = i
        break
      }
      if !is_ascii_digit(chars[i]) {
        return false
      }
    }
    return close >= 2 &&
      close + 1 < chars.length() &&
      is_feature_whitespace(chars[close + 1])
  }
  if chars[0] == '(' {
    let mut close = -1
    for i = 1; i < chars.length(); i = i + 1 {
      if chars[i] == ')' {
        close = i
        break
      }
      if !is_ascii_digit(chars[i]) {
        return false
      }
    }
    return close >= 2 &&
      close + 1 < chars.length() &&
      is_feature_whitespace(chars[close + 1])
  }
  false
}

///|
fn page_label_pattern_signal(text : String) -> Bool {
  let parts = text.trim().split(" ")
  let mut saw_page = false
  let mut saw_page_number = false
  for part in parts {
    let token = part.trim().to_owned().to_lower()
    if token == "" {
      continue
    }
    if saw_page {
      if !saw_page_number {
        if !all_ascii_digits_feature(token) {
          return false
        }
        saw_page_number = true
        continue
      }
      return false
    }
    if token == "page" {
      saw_page = true
    }
  }
  saw_page && saw_page_number
}

///|
fn contains_enumerated_reference_signal(
  lower : String,
  prefix : String,
) -> Bool {
  let chars = lower.to_array()
  let prefix_chars = prefix.to_array()
  if prefix_chars.is_empty() || chars.length() <= prefix_chars.length() {
    return false
  }
  for i = 0; i + prefix_chars.length() < chars.length(); i = i + 1 {
    let mut matched = true
    for j = 0; j < prefix_chars.length(); j = j + 1 {
      if chars[i + j] != prefix_chars[j] {
        matched = false
        break
      }
    }
    if matched && is_ascii_digit(chars[i + prefix_chars.length()]) {
      return true
    }
  }
  false
}

///|
fn cleanup_shell_signal(
  text : String,
  block : PdfConvertBlock,
  page_box : @model.PdfRect,
  repeated_text_score : Double,
  page_block_count : Int,
  page_median_font_size : Double?,
) -> Bool {
  let relative = relative_font_size(
    block.dominant_font_size,
    page_median_font_size,
  )
  let relative_ok = match relative {
    Some(value) => value >= 0.9 && value <= 1.15
    None => true
  }
  repeated_edge_candidate(block, page_box, repeated_text_score) &&
  top_zone_candidate(block._bbox, page_box) &&
  page_label_pattern_signal(text) &&
  block.line_count == 1 &&
  count_feature_words(text) >= 3 &&
  count_feature_words(text) <= 6 &&
  !has_terminal_period_signal(text) &&
  !contains_clause_punctuation_signal(text) &&
  page_block_count <= 6 &&
  relative_ok
}

///|
fn sku_like_signal(text : String) -> Bool {
  for part in text.trim().split(" ") {
    if looks_like_sku_token(part.trim().to_owned()) {
      return true
    }
  }
  false
}

///|
fn quantity_price_signal(text : String) -> Bool {
  contains_currency_signal(text) &&
  text.contains("@") &&
  count_numeric_runs(text) >= 2
}

///|
fn payment_card_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  if trimmed == "" {
    return false
  }
  (
    lower.contains("card") ||
    lower.contains("payment") ||
    lower.contains("credit") ||
    lower.contains("debit")
  ) &&
  (
    lower.contains("ending in ") ||
    lower.contains("ending ") ||
    lower.contains("last4") ||
    lower.contains("last 4")
  ) &&
  has_four_digit_run(trimmed)
}

///|
fn caption_marker_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  if trimmed == "" {
    return false
  }
  count_feature_words(trimmed) <= 12 &&
  (
    starts_with_enumerated_caption_prefix(lower, "figure ") ||
    starts_with_enumerated_caption_prefix(lower, "fig. ") ||
    starts_with_enumerated_caption_prefix(lower, "fig ") ||
    starts_with_enumerated_caption_prefix(lower, "table ") ||
    starts_with_enumerated_caption_prefix(lower, "chart ")
  )
}

///|
fn caption_marker_figure_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  if trimmed == "" {
    return false
  }
  starts_with_enumerated_caption_prefix(lower, "figure ") ||
  starts_with_enumerated_caption_prefix(lower, "fig. ") ||
  starts_with_enumerated_caption_prefix(lower, "fig ") ||
  lower.has_prefix("图 ") ||
  lower == "图"
}

///|
fn caption_marker_table_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  if trimmed == "" {
    return false
  }
  starts_with_enumerated_caption_prefix(lower, "table ") ||
  starts_with_enumerated_caption_prefix(lower, "chart ") ||
  lower.has_prefix("表 ") ||
  lower == "表"
}

///|
fn caption_marker_starts_line_signal(text : String) -> Bool {
  caption_marker_figure_signal(text) || caption_marker_table_signal(text)
}

///|
fn caption_reference_only_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  if trimmed == "" || caption_marker_starts_line_signal(trimmed) {
    return false
  }
  lower.contains("figure ") ||
  lower.contains("fig. ") ||
  lower.contains("fig ") ||
  lower.contains("table ") ||
  lower.contains("chart ") ||
  lower.contains("图 ") ||
  lower.contains("表 ")
}

///|
fn caption_lead_in_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  if trimmed == "" {
    return false
  }
  if caption_reference_only_signal(trimmed) {
    return true
  }
  if !caption_marker_starts_line_signal(trimmed) {
    return false
  }
  let word_count = count_feature_words(trimmed)
  if ends_with_colon_signal(trimmed) && word_count >= 6 {
    return true
  }
  if has_terminal_period_signal(trimmed) && word_count >= 10 {
    return true
  }
  lower.contains(" illustrates ") ||
  lower.contains(" illustrate ") ||
  lower.contains(" shows ") ||
  lower.contains(" show ") ||
  lower.contains(" below ") ||
  lower.contains(" above ") ||
  lower.contains(" depicts ") ||
  lower.contains(" presents ") ||
  lower.contains(" describes ") ||
  lower.contains(" following ")
}

///|
fn starts_with_enumerated_caption_prefix(
  lower : String,
  prefix : String,
) -> Bool {
  if !lower.has_prefix(prefix) {
    return false
  }
  let chars = lower.to_array()
  let prefix_len = prefix.length()
  if prefix_len >= chars.length() {
    return false
  }
  let next = chars[prefix_len]
  is_ascii_digit(next) || (next >= 'a' && next <= 'z')
}

///|
fn near_image_object_signal(near_image_distance : Double?) -> Bool {
  match near_image_distance {
    Some(distance) => distance >= 0.0 && distance <= 36.0
    None => false
  }
}

///|
fn normalized_object_distance_ratio(
  near_image_distance : Double?,
  page_height : Double,
) -> Double? {
  match near_image_distance {
    Some(distance) =>
      if page_height > 0.0 {
        Some(distance / page_height)
      } else {
        None
      }
    None => None
  }
}

///|
fn caption_heading_conflict_signal(
  caption_marker_starts_line : Bool,
  block : PdfConvertBlock,
  page_box : @model.PdfRect,
  page_median_font_size : Double?,
) -> Bool {
  if !caption_marker_starts_line {
    return false
  }
  if block.is_caption_candidate {
    return false
  }
  let relative = relative_font_size(
    block.dominant_font_size,
    page_median_font_size,
  )
  let font_conflict = match relative {
    Some(value) => value >= 1.18 && block.line_count <= 2
    None => false
  }
  (top_zone_candidate(block._bbox, page_box) && font_conflict) || font_conflict
}

///|
fn asset_metadata_noise_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  if trimmed == "" {
    return false
  }
  if lower.contains(".png") ||
    lower.contains(".jpg") ||
    lower.contains(".jpeg") ||
    lower.contains(".gif") ||
    lower.contains(".svg") ||
    lower.contains(".tif") ||
    lower.contains(".bmp") {
    return true
  }
  if looks_like_uuidish_signal(trimmed) {
    return true
  }
  count_feature_words(trimmed) <= 2 &&
  contains_path_like_signal(trimmed) &&
  (
    lower.contains("/images/") ||
    lower.contains("\\images\\") ||
    lower.contains("/assets/") ||
    lower.contains("\\assets\\") ||
    lower.contains("/media/") ||
    lower.contains("\\media\\")
  )
}

///|
fn toc_like_anchor_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" || count_feature_words(trimmed) < 3 {
    return false
  }
  has_dotted_leader_page_token_signal(trimmed)
}

///|
fn visible_url_without_annotation_signal(
  contains_url : Bool,
  contains_email : Bool,
  link_summary : PdfBlockLinkFeatureSummary,
) -> Bool {
  (contains_url || contains_email) &&
  !link_summary.has_uri_target &&
  !link_summary.has_internal_target &&
  !link_summary.has_named_target &&
  link_summary.text_coverage_ratio < 0.05
}

///|
fn code_like_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let lower = trimmed.to_lower()
  if trimmed == "" {
    return false
  }
  option_like_signal(trimmed) ||
  contains_path_like_signal(trimmed) ||
  trimmed.has_prefix("--") ||
  trimmed.has_prefix("$ ") ||
  trimmed.contains("::") ||
  trimmed.contains("->") ||
  trimmed.contains("=>") ||
  trimmed.contains("{}") ||
  trimmed.contains("[]") ||
  trimmed.contains("()") ||
  lower.contains("usage:") ||
  lower.contains("command line") ||
  lower.contains(".json") ||
  lower.contains(".xml") ||
  lower.contains(".xhtml") ||
  lower.contains(".epub")
}

///|
fn monospace_hint(block : PdfConvertBlock) -> Bool {
  match block.dominant_font_name {
    Some(name) => {
      let lower = name.to_lower()
      lower.contains("courier") ||
      lower.contains("mono") ||
      lower.contains("monaco") ||
      lower.contains("consola") ||
      lower.contains("menlo") ||
      lower.contains("inconsolata") ||
      lower.contains("sourcecode") ||
      lower.contains("liberationmono") ||
      lower.contains("dejavusansmono")
    }
    None => false
  }
}

///|
fn looks_like_us_state_zip_suffix(text : String) -> Bool {
  let chars = text.to_array()
  for i = 0; i + 7 < chars.length(); i = i + 1 {
    if chars[i] == ',' &&
      chars[i + 1] == ' ' &&
      is_ascii_upper(chars[i + 2]) &&
      is_ascii_upper(chars[i + 3]) &&
      chars[i + 4] == ' ' &&
      is_ascii_digit(chars[i + 5]) &&
      is_ascii_digit(chars[i + 6]) &&
      is_ascii_digit(chars[i + 7]) {
      return true
    }
  }
  false
}

///|
fn has_dotted_leader_page_token_signal(text : String) -> Bool {
  let chars = text.to_array()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '.' || chars[i] == '…' {
      let mut j = i
      while j < chars.length() && (chars[j] == '.' || chars[j] == '…') {
        j += 1
      }
      if j - i >= 4 {
        let mut k = j
        while k < chars.length() && is_feature_whitespace(chars[k]) {
          k += 1
        }
        let mut page_token_len = 0
        while k + page_token_len < chars.length() &&
              !is_feature_whitespace(chars[k + page_token_len]) &&
              page_token_len < 8 {
          page_token_len += 1
        }
        if page_token_len > 0 &&
          looks_like_page_token_chars(chars[k:k + page_token_len].to_owned()) {
          return true
        }
      }
      i = j
    } else {
      i += 1
    }
  }
  false
}

///|
fn looks_like_page_token_chars(chars : Array[Char]) -> Bool {
  if chars.is_empty() {
    return false
  }
  let token = String::from_array(chars)
  if all_ascii_digits_feature(token) {
    return true
  }
  let lower = token.to_lower()
  for ch in lower.to_array() {
    if !(ch == 'i' ||
      ch == 'v' ||
      ch == 'x' ||
      ch == 'l' ||
      ch == 'c' ||
      ch == 'd' ||
      ch == 'm') {
      return false
    }
  }
  true
}

///|
fn count_char_feature(text : String, target : Char) -> Int {
  let mut count = 0
  for ch in text.to_array() {
    if ch == target {
      count += 1
    }
  }
  count
}

///|
fn repeated_separator_symbol_run(symbols : Array[Char]) -> Bool {
  if symbols.is_empty() {
    return false
  }
  let first = symbols[0]
  if !short_separator_char(first) {
    return false
  }
  for ch in symbols {
    if ch != first {
      return false
    }
  }
  true
}

///|
fn short_separator_char(ch : Char) -> Bool {
  ch == '-' || ch == '_' || ch == '=' || ch == '~' || ch == '*' || ch == '.'
}

///|
fn looks_like_dotted_identifier_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" ||
    trimmed.contains(" ") ||
    trimmed.contains("\t") ||
    trimmed.contains("/") ||
    trimmed.contains("\\") ||
    trimmed.contains("://") ||
    contains_email_signal(trimmed) {
    return false
  }
  let mut alpha_parts = 0
  let mut long_parts = 0
  let mut dot_count = 0
  let mut part_len = 0
  let mut has_alpha = false
  for ch in trimmed.to_array() {
    if ch == '.' {
      if part_len == 0 {
        return false
      }
      if part_len >= 2 {
        long_parts += 1
      }
      if has_alpha {
        alpha_parts += 1
      }
      dot_count += 1
      part_len = 0
      has_alpha = false
      continue
    }
    if !dotted_identifier_char(ch) {
      return false
    }
    part_len += 1
    if is_ascii_alpha(ch) {
      has_alpha = true
    }
  }
  if part_len == 0 {
    return false
  }
  if part_len >= 2 {
    long_parts += 1
  }
  if has_alpha {
    alpha_parts += 1
  }
  dot_count >= 1 && alpha_parts >= 2 && long_parts >= 2
}

///|
fn contains_camel_case_token_signal(text : String) -> Bool {
  for part in text.trim().split(" ") {
    if camel_case_token_signal(part.trim().to_owned()) {
      return true
    }
  }
  false
}

///|
fn camel_case_token_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let chars = trimmed.to_array()
  if chars.length() < 6 {
    return false
  }
  let mut has_upper = false
  let mut has_lower = false
  let mut has_boundary = false
  let mut prev_alpha = false
  let mut prev_lower = false
  for ch in chars {
    if !(is_ascii_alpha(ch) ||
      is_ascii_digit(ch) ||
      ch == '.' ||
      ch == '_' ||
      ch == '-' ||
      ch == '=' ||
      ch == '\\' ||
      ch == '/') {
      return false
    }
    if is_ascii_alpha(ch) {
      if ch >= 'A' && ch <= 'Z' {
        has_upper = true
        if prev_alpha && prev_lower {
          has_boundary = true
        }
        prev_lower = false
      } else {
        has_lower = true
        prev_lower = true
      }
      prev_alpha = true
    } else {
      prev_alpha = false
      prev_lower = false
    }
  }
  has_upper && has_lower && has_boundary
}

///|
fn dotted_identifier_char(ch : Char) -> Bool {
  is_ascii_alpha(ch) || is_ascii_digit(ch) || ch == '_' || ch == '-'
}

///|
fn assignment_like_signal(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let chars = trimmed.to_array()
  for i = 1; i + 1 < chars.length(); i = i + 1 {
    if chars[i] != '=' {
      continue
    }
    if is_feature_whitespace(chars[i - 1]) ||
      is_feature_whitespace(chars[i + 1]) {
      continue
    }
    if !contains_ascii_alpha_text(String::from_array(chars[:i].to_owned())) ||
      !contains_ascii_alpha_text(String::from_array(chars[i + 1:].to_owned())) {
      continue
    }
    return true
  }
  false
}

///|
fn technical_separator_count(text : String) -> Int {
  let mut count = 0
  for ch in text.to_array() {
    if ch == '.' || ch == '_' || ch == '\\' || ch == '/' || ch == '=' {
      count += 1
    }
  }
  count
}

///|
fn contains_ascii_alpha_text(text : String) -> Bool {
  for ch in text.to_array() {
    if is_ascii_alpha(ch) {
      return true
    }
  }
  false
}

///|
fn looks_like_windows_drive_path(text : String) -> Bool {
  let chars = text.to_array()
  chars.length() >= 3 &&
  is_ascii_alpha(chars[0]) &&
  chars[1] == ':' &&
  (chars[2] == '\\' || chars[2] == '/')
}

///|
fn looks_like_sku_token(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let chars = trimmed.to_array()
  if chars.length() < 6 || !trimmed.contains("-") {
    return false
  }
  let mut upper = 0
  let mut lower = 0
  let mut digits = 0
  for ch in chars {
    if ch == '-' {
      continue
    }
    if ch >= 'A' && ch <= 'Z' {
      upper += 1
      continue
    }
    if ch >= 'a' && ch <= 'z' {
      lower += 1
      continue
    }
    if is_ascii_digit(ch) {
      digits += 1
      continue
    }
    return false
  }
  upper >= 2 && lower == 0 && digits >= 2
}

///|
fn count_numeric_runs(text : String) -> Int {
  let mut count = 0
  let mut in_run = false
  for ch in text.to_array() {
    if is_ascii_digit(ch) {
      if !in_run {
        count += 1
        in_run = true
      }
    } else {
      in_run = false
    }
  }
  count
}

///|
fn has_four_digit_run(text : String) -> Bool {
  let mut run = 0
  for ch in text.to_array() {
    if is_ascii_digit(ch) {
      run += 1
      if run >= 4 {
        return true
      }
    } else {
      run = 0
    }
  }
  false
}

///|
fn looks_like_cjk_page_number(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if !trimmed.has_prefix("第") {
    return false
  }
  let chars = trimmed.to_array()
  if chars.length() < 3 {
    return false
  }
  let last = chars[chars.length() - 1]
  if last != '页' && last != '⻚' {
    return false
  }
  let body = String::from_array(chars[1:chars.length() - 1].to_owned())
    .trim()
    .to_owned()
  if body == "" {
    return false
  }
  let digits = body.replace_all(old=" ", new="").replace_all(old="\t", new="")
  all_ascii_digits_feature(digits)
}

///|
fn begins_with_digit(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  is_ascii_digit(trimmed.to_array()[0])
}

///|
fn all_ascii_digits_feature(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return false
  }
  for ch in trimmed.to_array() {
    if !is_ascii_digit(ch) {
      return false
    }
  }
  true
}

///|
fn is_ascii_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn is_ascii_upper(ch : Char) -> Bool {
  ch >= 'A' && ch <= 'Z'
}

///|
fn is_ascii_alpha(ch : Char) -> Bool {
  (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')
}

///|
fn alignment_hint_value(value : String?) -> Double {
  match value {
    Some(raw) => {
      let v = raw.to_lower()
      if v == "left" {
        0.0
      } else if v == "center" {
        1.0
      } else if v == "right" {
        2.0
      } else if v == "justify" {
        3.0
      } else {
        -1.0
      }
    }
    None => -1.0
  }
}

///|
fn font_size_delta(current : Double?, neighbor : Double?) -> Double {
  match (current, neighbor) {
    (Some(a), Some(b)) => a - b
    _ => 0.0
  }
}

///|
fn effective_page_box_for_convert_page(page : PdfConvertPage) -> @model.PdfRect {
  match page.crop_box {
    Some(box) => box
    None =>
      match page.media_box {
        Some(box) => box
        None => { x0: 0.0, y0: 0.0, x1: 1.0, y1: 1.0 }
      }
  }
}

///|
fn bool_feature(v : Bool) -> Double {
  if v {
    1.0
  } else {
    0.0
  }
}

///|
fn abs_feature_f64(v : Double) -> Double {
  if v < 0.0 {
    -v
  } else {
    v
  }
}

///|
fn min_feature_f64(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn max_feature_f64(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn looks_like_uuidish_signal(text : String) -> Bool {
  let lower = text.to_lower()
  let chars = lower.to_array()
  if chars.length() < 24 || count_char_feature(lower, '-') < 3 {
    return false
  }
  let mut hexish = 0
  for ch in chars {
    if (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f') {
      hexish += 1
    }
  }
  hexish * 2 >= chars.length()
}
