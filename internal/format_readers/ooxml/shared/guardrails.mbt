///|
pub fn office_source_ref_extra_keys() -> Array[String] {
  [
    "ooxml_part_type", "part_name", "relationship_id", "relationship_type", "target_mode",
    "sheet_name", "sheet_id", "sheet_visibility", "cell_ref", "cell_range", "row_index",
    "column_index", "formula_ref", "shared_string_index", "style_id", "merge_range",
    "slide_index", "slide_id", "slide_part", "layout_part", "master_part", "theme_part",
    "shape_id", "shape_name", "shape_type", "placeholder_type", "placeholder_idx",
    "reading_order_index", "notes_part", "comment_id", "bbox", "paragraph_index",
    "run_index", "block_index",
  ]
}

///|
pub fn office_diagnostic_metric_keys() -> Array[String] {
  [
    "office_document_kind", "ooxml_part_count", "relationship_count", "external_relationship_count",
    "missing_relationship_target_count", "unsupported_relationship_count", "media_asset_count",
    "materialized_asset_count", "skipped_asset_count", "content_type_count", "total_uncompressed_bytes",
    "path_traversal_count", "duplicate_part_count", "encrypted_entry_count", "unsupported_compression_count",
    "resource_limit_hit", "xml_dtd_count", "xml_external_entity_count", "macro_part_count",
    "ole_object_count", "alt_chunk_count", "docx_paragraph_count", "docx_heading_count",
    "docx_table_count", "docx_list_count", "docx_image_count", "docx_hyperlink_count",
    "docx_header_footer_count", "docx_comment_count", "docx_tracked_change_count",
    "fallback_count", "warning_count", "error_count", "issue_count", "pptx_slide_count",
    "pptx_hidden_slide_count", "pptx_shape_count", "pptx_text_box_count", "pptx_placeholder_count",
    "pptx_table_count", "pptx_image_count", "pptx_notes_count", "pptx_layout_count",
    "pptx_master_count", "pptx_theme_count", "pptx_resolved_placeholder_count", "pptx_unresolved_placeholder_count",
    "pptx_comment_count", "pptx_external_media_count", "pptx_reading_order_strategy",
    "external_link_count", "xlsx_sheet_count", "xlsx_hidden_sheet_count", "xlsx_very_hidden_sheet_count",
    "xlsx_row_count", "xlsx_cell_count", "xlsx_non_empty_cell_count", "xlsx_merged_cell_count",
    "xlsx_formula_count", "xlsx_shared_formula_count", "xlsx_array_formula_count",
    "xlsx_shared_string_count", "xlsx_style_count", "xlsx_drawing_count", "xlsx_image_count",
    "fallback_trace", "pass_trace",
  ]
}

///|
pub fn office_resource_limit_keys() -> Array[String] {
  [
    "max_ooxml_parts", "max_total_uncompressed_bytes", "max_single_part_bytes", "max_relationships",
    "max_external_relationships", "max_media_assets", "max_xml_depth", "max_xml_nodes",
    "max_text_bytes", "max_docx_blocks", "max_pptx_slides", "max_pptx_shapes", "max_pptx_text_runs",
    "max_pptx_tables", "max_pptx_images", "max_pptx_notes", "max_pptx_comments",
    "max_xlsx_sheets", "max_xlsx_rows", "max_xlsx_columns", "max_xlsx_cells", "max_xlsx_non_empty_cells",
    "max_shared_strings", "max_formula_count", "max_merged_ranges", "max_materialized_assets",
  ]
}

///|
pub fn office_relationship_guardrails() -> Array[String] {
  [
    "relationship target resolution is package-local by default", "TargetMode=External is no-fetch",
    "relationship traversal outside package-safe normalized boundaries is forbidden",
    "missing targets are diagnosed", "unsupported relationship types are diagnosed",
  ]
}

///|
pub fn office_asset_write_guardrails() -> Array[String] {
  [
    "media asset plans are carried as root-pipeline contracts", "asset writes only happen at the CLI/output boundary",
    "no parser/orchestrator file writes", "no external fetch", "relative output paths only",
  ]
}

///|
pub fn office_asset_output_path_is_safe(path : String) -> Bool {
  let trimmed = path.trim()
  if trimmed == "" {
    return false
  }
  if trimmed.contains("\\") {
    return false
  }
  if trimmed.has_prefix("/") {
    return false
  }
  if trimmed == ".." || trimmed.has_prefix("../") || trimmed.contains("../") {
    return false
  }
  if trimmed.contains("/..") {
    return false
  }
  let chars = trimmed.to_array()
  if chars.length() >= 2 && chars[1] == ':' {
    return false
  }
  true
}

///|
pub fn office_asset_plan_is_safe(plan : @oshared.OfficeAssetPlan) -> Bool {
  office_asset_output_path_is_safe(plan.output_relative_path)
}

///|
pub fn office_relationship_is_no_fetch(
  rel : @oshared.OfficeRelationship,
) -> Bool {
  rel.is_external || rel.target_mode.trim().to_lower() == "external"
}
