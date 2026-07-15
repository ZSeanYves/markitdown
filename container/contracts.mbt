///|
/// Policy for how container-derived asset references may cross the output
/// boundary.
///
/// The policy only describes data-flow intent; actual filesystem writes still
/// happen at the CLI/output boundary.
pub enum ContainerAssetCopyPolicy {
  MaterializeAtOutputBoundary
  ReferenceOnly
  RejectUnsafePath
} derive(Eq)

///|
/// Return the stable name for one container asset copy policy.
pub fn container_asset_copy_policy_name(
  policy : ContainerAssetCopyPolicy,
) -> String {
  match policy {
    MaterializeAtOutputBoundary => "materialize_at_output_boundary"
    ReferenceOnly => "reference_only"
    RejectUnsafePath => "reject_unsafe_path"
  }
}

///|
/// Convenience constructor for the default materialization policy.
pub fn container_asset_copy_policy_materialize_at_output_boundary() -> ContainerAssetCopyPolicy {
  MaterializeAtOutputBoundary
}

///|
/// Convenience constructor for a reference-only policy.
pub fn container_asset_copy_policy_reference_only() -> ContainerAssetCopyPolicy {
  ReferenceOnly
}

///|
/// Convenience constructor for the strict unsafe-path rejection policy.
pub fn container_asset_copy_policy_reject_unsafe_path() -> ContainerAssetCopyPolicy {
  RejectUnsafePath
}

///|
/// Inner formats currently allowed for root-container child dispatch.
pub fn container_supported_inner_formats() -> Array[String] {
  [
    "txt", "csv", "tsv", "srt", "vtt", "json", "jsonl", "ndjson", "ipynb", "xml",
    "yaml", "yml", "toml", "html", "htm", "markdown", "md", "tex", "latex", "rst",
    "adoc", "asciidoc", "eml", "docx", "xlsx", "pptx", "odt", "ods", "odp", "pdf",
    "wav", "mp3", "m4a",
  ]
}

///|
/// Inner formats that intentionally fail closed inside root containers today.
pub fn container_unsupported_inner_formats() -> Array[String] {
  ["zip", "png", "jpg", "jpeg", "bmp", "webp", "tif", "tiff", "ocr"]
}

///|
/// Return whether a detected format is currently allowed as a container child
/// document.
pub fn container_supports_inner_format(format : @input.DetectedFormat) -> Bool {
  match format {
    Txt => true
    Markdown => true
    Csv => true
    Tsv => true
    Srt => true
    Vtt => true
    Json => true
    Jsonl => true
    Ndjson => true
    Ipynb => true
    Xml => true
    Yaml => true
    Toml => true
    Html => true
    Tex => true
    Rst => true
    Asciidoc => true
    Eml => true
    Docx => true
    Xlsx => true
    Pptx => true
    Odt => true
    Ods => true
    Odp => true
    Pdf => true
    Audio(_) => true
    // OCR is a top-level pure-image capability. Images embedded in containers
    // remain assets and must not be promoted to child documents.
    Image(_) => false
    _ => false
  }
}

///|
/// Human-readable guardrails for container child dispatch.
pub fn container_dispatch_guardrails() -> Array[String] {
  [
    "inner document dispatch must go through the root ParserRegistry / root pipeline",
    "container parsing stays inside the canonical product path", "no format-specific side dispatcher",
    "no nested archive recursion by default", "embedded images remain assets and never enter OCR child dispatch",
  ]
}

///|
/// Human-readable guardrails for container asset writes.
pub fn container_asset_write_guardrails() -> Array[String] {
  [
    "asset references stay data-only inside parse and render stages", "actual file writes only happen at the CLI/output boundary",
    "no parser/orchestrator file writes", "no external fetch", "no path traversal",
  ]
}

///|
/// Source-ref keys reserved for container provenance.
pub fn container_source_ref_keys() -> Array[String] {
  ["container_path", "entry_path", "entry_index", "entry_format", "inner_path"]
}

///|
/// Diagnostics metric keys reserved for container parsers.
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
/// Resource-limit keys reserved for container planning and parsing.
pub fn container_resource_limit_keys() -> Array[String] {
  [
    "max_container_entries", "max_total_uncompressed_bytes", "max_single_entry_bytes",
    "max_compression_ratio", "max_nested_archive_depth", "max_filename_length", "max_directory_depth",
    "max_selected_inner_documents", "max_materialized_assets",
  ]
}

///|
/// Return whether an asset output path is relative and free from obvious
/// traversal/absolute-path issues.
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
/// Alias of `container_asset_output_path_is_safe` for relative-path checks.
pub fn container_asset_relative_path_is_safe(path : String) -> Bool {
  container_asset_output_path_is_safe(path)
}
