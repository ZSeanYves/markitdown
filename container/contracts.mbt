///|
pub enum ContainerAssetCopyPolicy {
  MaterializeAtOutputBoundary
  ReferenceOnly
  RejectUnsafePath
} derive(Eq)

///|
pub fn container_asset_copy_policy_name(
  policy : ContainerAssetCopyPolicy,
) -> String {
  match policy {
    ContainerAssetCopyPolicy::MaterializeAtOutputBoundary =>
      "materialize_at_output_boundary"
    ContainerAssetCopyPolicy::ReferenceOnly => "reference_only"
    ContainerAssetCopyPolicy::RejectUnsafePath => "reject_unsafe_path"
  }
}

///|
pub fn container_asset_copy_policy_materialize_at_output_boundary() -> ContainerAssetCopyPolicy {
  ContainerAssetCopyPolicy::MaterializeAtOutputBoundary
}

///|
pub fn container_asset_copy_policy_reference_only() -> ContainerAssetCopyPolicy {
  ContainerAssetCopyPolicy::ReferenceOnly
}

///|
pub fn container_asset_copy_policy_reject_unsafe_path() -> ContainerAssetCopyPolicy {
  ContainerAssetCopyPolicy::RejectUnsafePath
}

///|
pub fn container_supported_inner_formats() -> Array[String] {
  [
    "txt", "csv", "tsv", "json", "jsonl", "ndjson", "xml", "yaml", "yml", "html",
    "htm", "markdown", "md", "epub",
  ]
}

///|
pub fn container_unsupported_inner_formats() -> Array[String] {
  ["docx", "pptx", "xlsx", "pdf", "zip", "images", "ocr"]
}

///|
pub fn container_supports_inner_format(format : @input.DetectedFormat) -> Bool {
  match format {
    @input.DetectedFormat::Txt => true
    @input.DetectedFormat::Markdown => true
    @input.DetectedFormat::Csv => true
    @input.DetectedFormat::Tsv => true
    @input.DetectedFormat::Json => true
    @input.DetectedFormat::Jsonl => true
    @input.DetectedFormat::Ndjson => true
    @input.DetectedFormat::Xml => true
    @input.DetectedFormat::Yaml => true
    @input.DetectedFormat::Html => true
    @input.DetectedFormat::Epub => true
    _ => false
  }
}

///|
pub fn container_dispatch_guardrails() -> Array[String] {
  [
    "inner document dispatch must go through the root ParserRegistry / root pipeline",
    "container parsing stays inside the canonical product path", "no format-specific side dispatcher",
    "no nested archive recursion by default",
  ]
}

///|
pub fn container_asset_write_guardrails() -> Array[String] {
  [
    "asset references stay data-only inside parse and render stages", "actual file writes only happen at the CLI/output boundary",
    "no parser/orchestrator file writes", "no external fetch", "no path traversal",
  ]
}

///|
pub fn container_source_ref_keys() -> Array[String] {
  ["container_path", "entry_path", "entry_index", "entry_format", "inner_path"]
}

///|
pub fn container_diagnostic_metric_keys() -> Array[String] {
  [
    "container_entry_count", "selected_entry_count", "skipped_entry_count", "unsupported_entry_count",
    "asset_count", "total_uncompressed_bytes", "max_compression_ratio_observed",
    "path_traversal_count", "encrypted_entry_count", "unsupported_compression_count",
    "resource_limit_hit", "manifest_seen", "spine_item_count", "nav_seen", "ncx_seen",
    "cover_candidate_seen", "missing_manifest_item_count", "missing_spine_item_count",
    "external_resource_count", "fallback_trace", "pass_trace",
  ]
}

///|
pub fn container_resource_limit_keys() -> Array[String] {
  [
    "max_container_entries", "max_total_uncompressed_bytes", "max_single_entry_bytes",
    "max_compression_ratio", "max_nested_archive_depth", "max_filename_length", "max_directory_depth",
    "max_selected_inner_documents", "max_materialized_assets",
  ]
}

///|
pub fn container_asset_output_path_is_safe(path : String) -> Bool {
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
  if trimmed.contains("../") || trimmed == ".." || trimmed.has_prefix("../") {
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
pub fn container_asset_relative_path_is_safe(path : String) -> Bool {
  container_asset_output_path_is_safe(path)
}
