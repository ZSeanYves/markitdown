///|
test "container parser mode naming stays explicit without exposing container irinput variants" {
  assert_true(
    @parser.mode_name(@parser.ParserMode::ContainerRecursive) ==
    "container_recursive",
  )
}

///|
test "container asset copy policy naming stays explicit" {
  assert_true(
    @container.container_asset_copy_policy_name(
      @container.container_asset_copy_policy_materialize_at_output_boundary(),
    ) ==
    "materialize_at_output_boundary",
  )
}

///|
test "container contracts keep inner dispatch on the root pipeline and bounded" {
  let supported = @container.container_supported_inner_formats()
  assert_true(
    supported ==
    [
      "txt", "csv", "tsv", "json", "jsonl", "ndjson", "xml", "yaml", "yml", "html",
      "htm", "markdown", "md", "epub",
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
test "office shared models and guardrails stay root-pipeline only" {
  let rel_src = @core.source_ref_with_office_fields(
    @core.empty_source_ref(),
    Some("sample.docx"),
    Some("docx"),
    Some("/w:document/w:body/w:p[1]"),
    None,
    None,
    None,
    None,
    Some("rIdMain"),
  )
  let rel = @shared.make_office_relationship(
    "word/document.xml",
    "rIdExt",
    "image",
    "https://example.com/image.png",
    target_mode="External",
    is_external=true,
    source_ref=Some(rel_src),
    security_findings=[@shared.OfficeSecurityFinding::ExternalRelationship],
  )
  let part = @shared.make_office_part(
    "word/document.xml",
    normalized_part_name=Some("word/document.xml"),
    content_type=Some(
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
    ),
    source_ref=Some(rel_src),
  )
  let content_type = @shared.make_office_content_type(
    "application/xml",
    extension=Some("xml"),
  )
  let media = @shared.make_office_media_asset(
    "word/media/image1.png",
    content_type=Some("image/png"),
    relationship_id=Some("rIdImg"),
    source_part=Some("word/document.xml"),
    size=Some(128),
    source_ref=Some(rel_src),
  )
  let diagnostics = @core.empty_diagnostics()
  diagnostics.metrics.set("office_document_kind", "docx")
  diagnostics.metrics.set("relationship_count", "1")
  let pkg = @shared.make_office_package(
    @shared.OfficeDocumentKind::Docx,
    [part],
    [rel],
    [content_type],
    [media],
    container_path=Some("sample.docx"),
    source_id=Some("sample.docx"),
    diagnostics~,
    source_ref=Some(rel_src),
  )
  let asset_plan = @shared.make_office_asset_plan(
    "word/media/image1.png",
    "assets/docx/image01.png",
    source_ref=Some(rel_src),
  )
  let plan = @shared.make_office_semantic_plan(
    @shared.OfficeDocumentKind::Docx,
    pkg,
    "package_single_pass",
    ["paragraph:0", "table:1"],
    [asset_plan],
    diagnostics~,
  )
  assert_true(@shared.office_document_kind_name(plan.document_kind) == "docx")
  assert_true(@shared.office_relationship_is_no_fetch(rel))
  assert_true(@shared.office_asset_plan_is_safe(asset_plan))
  assert_true(!@shared.office_asset_output_path_is_safe("../unsafe/image.png"))
  assert_true(
    @shared.office_relationship_guardrails().contains(
      "TargetMode=External is no-fetch",
    ),
  )
  assert_true(
    @shared.office_asset_write_guardrails().contains(
      "asset writes only happen at the CLI/output boundary",
    ),
  )
  assert_true(
    @shared.office_source_ref_extra_keys().contains("relationship_id"),
  )
  assert_true(
    @shared.office_source_ref_extra_keys().contains("paragraph_index"),
  )
  assert_true(
    @shared.office_diagnostic_metric_keys().contains("office_document_kind"),
  )
  assert_true(
    @shared.office_diagnostic_metric_keys().contains("alt_chunk_count"),
  )
  assert_true(
    @shared.office_diagnostic_metric_keys().contains("docx_hyperlink_count"),
  )
  assert_true(
    @shared.office_diagnostic_metric_keys().contains("fallback_count"),
  )
  assert_true(@shared.office_resource_limit_keys().contains("max_ooxml_parts"))
  assert_true(plan.office_package.parts.length() == 1)
  assert_true(plan.office_package.relationships.length() == 1)
  assert_true(plan.asset_plans.length() == 1)
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
  assert_true(
    unsafe_entry.security_findings.map(f => {
      @core.container_security_finding_name(f)
    }) ==
    [
      "path_traversal", "encrypted_entry", "unsupported_compression", "compression_ratio_limit",
    ],
  )
  assert_contains_all(
    @container.container_diagnostic_metric_keys().join("\n"),
    [
      "container_entry_count", "selected_entry_count", "skipped_entry_count", "unsupported_entry_count",
      "asset_count", "total_uncompressed_bytes", "max_compression_ratio_observed",
      "path_traversal_count", "encrypted_entry_count", "unsupported_compression_count",
      "resource_limit_hit", "manifest_seen", "spine_item_count", "nav_seen",
    ],
  )
  assert_contains_all(@container.container_resource_limit_keys().join("\n"), [
    "max_container_entries", "max_total_uncompressed_bytes", "max_single_entry_bytes",
    "max_compression_ratio", "max_nested_archive_depth", "max_selected_inner_documents",
    "max_materialized_assets",
  ])
}
