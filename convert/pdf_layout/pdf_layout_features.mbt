///|
pub enum PdfLayoutRecordKind {
  Line
  Block
  Boundary
} derive(Eq)

///|
pub struct PdfLayoutFeature {
  sample_id : String
  source_path : String
  record_kind : PdfLayoutRecordKind
  label : String?
  page_index : Int
  block_index : Int
  line_index : Int
  next_page_index : Int?
  next_block_index : Int?
  next_line_index : Int?
  text : String
  notes : String?
  feature_values : Map[String, Double]
}

///|
pub fn default_pdf_layout_feature_names() -> Array[String] {
  [
    "text_len", "normalized_text_len", "word_count", "digit_ratio", "punctuation_ratio",
    "uppercase_ratio", "cjk_ratio", "x0", "y0", "x1", "y1", "width", "height", "page_width",
    "page_height", "x_center_ratio", "y_center_ratio", "top_ratio", "bottom_ratio",
    "font_size_hint", "bold_hint", "line_gap_before", "line_gap_after", "indent_left",
    "alignment_hint", "near_image_distance", "page_edge_distance", "repeated_text_score",
    "source_ref_count", "has_rich_inline_payload", "has_link_inline", "link_inline_count",
    "link_overlap_ratio", "link_text_coverage_ratio", "has_partial_link", "is_link_only_candidate",
    "link_target_uri", "link_target_internal", "link_target_named", "link_target_mixed",
    "page_number_like_link", "toc_like_anchor_signal", "visible_url_without_annotation",
    "page_label_pattern_signal", "cleanup_shell_signal", "is_heading_candidate",
    "is_page_number_candidate", "is_header_footer_candidate", "is_artifact_candidate",
    "is_caption_candidate", "is_table_cell_candidate", "is_noise_kind", "is_heading_kind",
    "line_count", "prev_gap_before", "next_gap_before", "prev_font_size_delta", "next_font_size_delta",
    "same_paragraph_candidate", "wrapped_candidate", "latin_ratio", "symbol_ratio",
    "text_density", "page_line_count", "page_block_count", "page_median_font_size",
    "relative_font_size", "near_annotation_distance", "near_link_annotation_distance",
    "near_uri_annotation_distance", "near_dest_annotation_distance", "top_zone_candidate",
    "bottom_zone_candidate", "repeated_edge_candidate", "contains_currency", "contains_time",
    "contains_date", "looks_like_address", "looks_like_separator", "looks_like_page_number",
    "looks_like_bullet", "looks_like_list_marker_token", "contains_url", "contains_email",
    "contains_url_or_email", "contains_path_like", "identifier_like_signal", "technical_literal_signal",
    "sentence_like_signal", "figure_reference_sentence_signal", "section_reference_sentence_signal",
    "technical_sentence_guard_signal", "citation_reference_signal", "caption_marker_signal",
    "caption_marker_figure", "caption_marker_table", "caption_marker_starts_line",
    "caption_reference_only_signal", "caption_lead_in_signal", "near_image_object_signal",
    "caption_object_distance_ratio", "caption_heading_conflict_signal", "asset_metadata_noise_signal",
    "has_raw_hyphen", "ends_with_colon", "has_terminal_period", "contains_clause_punctuation",
    "has_markdown_escape_chars", "form_key_value_signal", "option_like_signal", "code_like_signal",
    "monospace_hint", "sku_like_signal", "quantity_price_signal", "payment_card_signal",
    "receipt_line_item_signal", "boundary_prev_no_sentence_end", "boundary_next_starts_lowercase",
    "boundary_next_continues_sentence", "boundary_similar_indent", "boundary_same_column_band",
    "boundary_table_guard", "boundary_caption_guard", "boundary_noise_guard", "boundary_heading_guard",
    "boundary_list_guard", "boundary_layout_compatible",
  ]
}

///|
pub fn default_pdf_layout_feature_tsv_columns() -> Array[String] {
  let out : Array[String] = [
    "sample_id", "source_path", "record_kind", "page_index", "block_index", "line_index",
    "next_page_index", "next_block_index", "next_line_index", "text", "label",
  ]
  for name in default_pdf_layout_feature_names() {
    out.push(name)
  }
  out.push("notes")
  out
}

///|
pub fn render_pdf_layout_feature_tsv(
  features : Array[PdfLayoutFeature],
  feature_names : Array[String],
) -> String {
  let columns = feature_tsv_columns(feature_names)
  let lines : Array[String] = [columns.join("\t")]
  for feature in features {
    lines.push(render_pdf_layout_feature_row(feature, feature_names).join("\t"))
  }
  lines.join("\n") + "\n"
}

///|
pub fn render_pdf_layout_feature_row(
  feature : PdfLayoutFeature,
  feature_names : Array[String],
) -> Array[String] {
  let row : Array[String] = [
    tsv_escape(feature.sample_id),
    tsv_escape(feature.source_path),
    tsv_escape(pdf_layout_record_kind_name(feature.record_kind)),
    (feature.page_index + 1).to_string(),
    feature.block_index.to_string(),
    feature.line_index.to_string(),
    int_opt_tsv(feature.next_page_index, true),
    int_opt_tsv(feature.next_block_index, false),
    int_opt_tsv(feature.next_line_index, false),
    tsv_escape(feature.text),
    tsv_escape(
      match feature.label {
        Some(label) => label
        None => ""
      },
    ),
  ]

  for name in feature_names {
    row.push(tsv_escape(double_opt_tsv(feature.feature_values.get(name))))
  }

  row.push(
    tsv_escape(
      match feature.notes {
        Some(notes) => notes
        None => ""
      },
    ),
  )
  row
}

///|
pub fn make_pdf_layout_feature(
  sample_id : String,
  source_path : String,
  record_kind : PdfLayoutRecordKind,
  page_index : Int,
  block_index : Int,
  line_index : Int,
  next_page_index : Int?,
  next_block_index : Int?,
  next_line_index : Int?,
  text : String,
  label : String?,
  notes : String?,
  feature_values : Map[String, Double],
) -> PdfLayoutFeature {
  {
    sample_id,
    source_path,
    record_kind,
    label,
    page_index,
    block_index,
    line_index,
    next_page_index,
    next_block_index,
    next_line_index,
    text,
    notes,
    feature_values,
  }
}

///|
fn feature_tsv_columns(feature_names : Array[String]) -> Array[String] {
  let out : Array[String] = [
    "sample_id", "source_path", "record_kind", "page_index", "block_index", "line_index",
    "next_page_index", "next_block_index", "next_line_index", "text", "label",
  ]
  for name in feature_names {
    out.push(name)
  }
  out.push("notes")
  out
}

///|
fn pdf_layout_record_kind_name(kind : PdfLayoutRecordKind) -> String {
  match kind {
    PdfLayoutRecordKind::Line => "line"
    PdfLayoutRecordKind::Block => "block"
    PdfLayoutRecordKind::Boundary => "boundary"
  }
}

///|
fn int_opt_tsv(value : Int?, one_based_page : Bool) -> String {
  match value {
    Some(v) => if one_based_page { (v + 1).to_string() } else { v.to_string() }
    None => ""
  }
}

///|
fn double_opt_tsv(value : Double?) -> String {
  match value {
    Some(v) => v.to_string()
    None => ""
  }
}

///|
fn tsv_escape(text : String) -> String {
  text
  .replace_all(old="\t", new=" ")
  .replace_all(old="\r", new=" ")
  .replace_all(old="\n", new=" ")
}
