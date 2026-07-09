///|
test "container parser mode naming stays explicit without exposing container irinput variants" {
  assert_true(
    @parser.mode_name(@parser.ParserMode::ContainerRecursive) ==
    "container_recursive",
  )
}

///|
test "container contracts keep inner dispatch on the root pipeline and bounded" {
  let supported = @container.container_supported_inner_formats()
  assert_true(
    supported ==
    [
      "txt", "csv", "tsv", "srt", "vtt", "json", "jsonl", "ndjson", "ipynb", "xml",
      "yaml", "yml", "toml", "html", "htm", "markdown", "md", "tex", "latex", "rst",
      "adoc", "asciidoc", "eml", "epub", "odt", "ods", "odp",
    ],
  )
  assert_true(
    @container.container_supports_inner_format(@input.DetectedFormat::Txt),
  )
  assert_true(
    @container.container_supports_inner_format(@input.DetectedFormat::Markdown),
  )
  assert_true(
    !@container.container_unsupported_inner_formats().contains("html"),
  )
  assert_contains_all(@container.container_dispatch_guardrails().join("\n"), [
    "root ParserRegistry / root pipeline", "container parsing stays inside the canonical product path",
    "no format-specific side dispatcher",
  ])
}

///|
test "container asset boundary contracts reject unsafe output paths" {
  assert_true(
    @container.container_asset_relative_path_is_safe("assets/cover.jpg"),
  )
  assert_true(!@container.container_asset_relative_path_is_safe("../cover.jpg"))
  assert_true(
    !@container.container_asset_relative_path_is_safe("/tmp/cover.jpg"),
  )
  assert_contains_all(
    @container.container_asset_write_guardrails().join("\n"),
    [
      "actual file writes only happen at the CLI/output boundary", "no parser/orchestrator file writes",
      "no external fetch", "no path traversal",
    ],
  )
}

///|
test "container model can represent unsafe and limited entries without runtime enablement" {
  let unsafe_src = @core.source_ref_with_container_entry(
    @core.empty_source_ref(),
    Some("sample.zip"),
    Some("zip"),
    Some("sample.zip"),
    Some("../evil.txt"),
    Some(9),
    Some("txt"),
    None,
  )
  let unsafe_entry = @core.make_container_entry(
    "../evil.txt",
    @core.ContainerEntryKind::Unsafe,
    normalized_path=None,
    entry_index=Some(9),
    detected_format=Some("txt"),
    is_encrypted=true,
    compression_method=Some("unsupported:deflate64"),
    source_ref=Some(unsafe_src),
    security_findings=[
      @core.ContainerSecurityFinding::PathTraversal,
      @core.ContainerSecurityFinding::EncryptedEntry,
      @core.ContainerSecurityFinding::UnsupportedCompression,
      @core.ContainerSecurityFinding::CompressionRatioLimit,
    ],
  )
  assert_true(
    @core.container_entry_kind_name(unsafe_entry.entry_kind) == "unsafe",
  )
  assert_true(unsafe_entry.is_encrypted)
  assert_contains_all(
    @container.container_diagnostic_metric_keys().join("\n"),
    [
      "container_entry_count", "selected_entry_count", "skipped_entry_count", "unsupported_entry_count",
      "asset_count", "path_traversal_count", "resource_limit_hit",
    ],
  )
  assert_contains_all(@container.container_resource_limit_keys().join("\n"), [
    "max_container_entries", "max_total_uncompressed_bytes", "max_single_entry_bytes",
    "max_compression_ratio", "max_nested_archive_depth", "max_selected_inner_documents",
  ])
}
