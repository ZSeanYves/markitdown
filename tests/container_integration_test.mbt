///|
fn container_test_read_sample_bytes(path : String) -> Bytes raise {
  @fs.read_file_to_bytes(path) catch {
    e =>
      fail("failed to read container sample: " + path + " : " + e.to_string())
  }
}

///|
fn container_test_nested_office_zip_bytes() -> Bytes raise {
  @therm.build_store_zip_bytes([
    (
      "nested.docx",
      container_test_read_sample_bytes(
        "samples/fixtures/contracts/docx/docx_image_alt_title.docx",
      ),
    ),
    (
      "nested.xlsx",
      container_test_read_sample_bytes(
        "samples/fixtures/contracts/xlsx/sheet_simple.xlsx",
      ),
    ),
    (
      "nested.pptx",
      container_test_read_sample_bytes(
        "samples/fixtures/contracts/pptx/pptx_image_single.pptx",
      ),
    ),
  ])
}

///|
fn container_test_convert_nested_office_zip(
  zip_bytes : Bytes,
  mode? : @convert.ConvertMode = @convert.ConvertMode::Balanced,
) -> @convert.ConvertResult {
  let options = @convert.make_convert_options(
    mode,
    @convert.OutputFormat::Markdown,
    Some(@input.DetectedFormat::Zip),
    @parser.default_ocr_options(),
    @convert.default_resource_limits(),
    output_mode=@convert.output_mode_for_output_format(
      @convert.OutputFormat::Markdown,
    ),
    stream_requested=mode == @convert.ConvertMode::Stream,
  )
  match
    @convert.convert_input(
      @input.input_from_bytes_with_format(
        zip_bytes,
        "nested-office.zip",
        Some(@input.DetectedFormat::Zip),
      ),
      options,
    ) {
    Ok(value) => value
    Err(err) => abort("nested office zip convert failed: " + err.to_string())
  }
}

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
      "adoc", "asciidoc", "eml", "docx", "xlsx", "pptx", "odt", "ods", "odp",
    ],
  )
  let unsupported = @container.container_unsupported_inner_formats()
  assert_true(unsupported == ["pdf", "zip", "images", "ocr"])
  assert_true(
    @container.container_supports_inner_format(@input.DetectedFormat::Txt),
  )
  assert_true(
    @container.container_supports_inner_format(@input.DetectedFormat::Markdown),
  )
  assert_true(!unsupported.contains("html"))
  assert_true(
    @container.container_supports_inner_format(@input.DetectedFormat::Docx),
  )
  assert_true(
    @container.container_supports_inner_format(@input.DetectedFormat::Xlsx),
  )
  assert_true(
    @container.container_supports_inner_format(@input.DetectedFormat::Pptx),
  )
  assert_contains_all(@container.container_dispatch_guardrails().join("\n"), [
    "root ParserRegistry / root pipeline", "container parsing stays inside the canonical product path",
    "no format-specific side dispatcher",
  ])
}

///|
test "zip container parser expands nested office children on the root product path" {
  let zip_bytes = container_test_nested_office_zip_bytes()
  let parsed = default_registry_parse(
    @input.input_from_bytes_with_format(
      zip_bytes,
      "nested-office.zip",
      Some(@input.DetectedFormat::Zip),
    ),
    @input.DetectedFormat::Zip,
  )
  assert_parse_result_matches_contract_spec(
    parsed,
    @fmeta.zip_parser_contract_spec(),
  )
  assert_metric_eq(parsed.diagnostics, "selected_entry_count", "3")
  assert_metric_eq(parsed.diagnostics, "unsupported_entry_count", "0")
  assert_metric_eq(parsed.diagnostics, "nested_archive_count", "0")

  let converted = container_test_convert_nested_office_zip(zip_bytes)
  assert_contains_all(converted.content, [
    "# nested.docx", "![Figure alt text](assets/archive/nested.docx/image01.png)",
    "# nested.xlsx", "## Sheet1", "| Name | Value | 备注 |", "# nested.pptx", "![slide-1-image-1](assets/archive/nested.pptx/image01.png)",
  ])
  assert_contains_none(converted.content, [
    "Skipped: unsupported file type: docx", "Skipped: unsupported file type: xlsx",
    "Skipped: unsupported file type: pptx",
  ])
}

///|
test "zip container stream mode keeps nested office children on supported paths" {
  let converted = container_test_convert_nested_office_zip(
    container_test_nested_office_zip_bytes(),
    mode=@convert.ConvertMode::Stream,
  )
  assert_true(converted.convert_mode == @convert.ConvertMode::Stream)
  assert_true(converted.parser_mode == @parser.ParserMode::ContainerRecursive)
  assert_contains_all(converted.content, [
    "# nested.docx", "# nested.xlsx", "## Sheet1", "# nested.pptx",
  ])
  assert_contains_none(converted.content, [
    "Skipped: unsupported file type: docx", "Skipped: unsupported file type: xlsx",
    "Skipped: unsupported file type: pptx",
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
