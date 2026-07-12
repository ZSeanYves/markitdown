///|
test "Office guardrail registries expose stable provenance limits and policies" {
  let source_keys = office_source_ref_extra_keys()
  assert_true(source_keys.contains("part_name"))
  assert_true(source_keys.contains("relationship_id"))
  assert_true(source_keys.contains("cell_ref"))
  assert_true(source_keys.contains("slide_index"))
  assert_true(source_keys.contains("run_index"))
  let metric_keys = office_diagnostic_metric_keys()
  assert_true(metric_keys.contains("path_traversal_count"))
  assert_true(metric_keys.contains("encrypted_entry_count"))
  assert_true(metric_keys.contains("xlsx_cell_count"))
  assert_true(metric_keys.contains("pptx_slide_count"))
  assert_true(metric_keys.contains("fallback_trace"))
  let limits = office_resource_limit_keys()
  assert_true(limits.contains("max_ooxml_parts"))
  assert_true(limits.contains("max_total_uncompressed_bytes"))
  assert_true(limits.contains("max_xml_depth"))
  assert_true(limits.contains("max_xlsx_cells"))
  assert_true(office_relationship_guardrails().length() >= 5)
  assert_true(office_asset_write_guardrails().length() >= 5)
}

///|
test "Office asset output paths fail closed for traversal absolute and drive paths" {
  for
    path in [
      "assets/image.png", "word/media/image.png", "a..b/file", "relative.txt",
    ] {
    assert_true(office_asset_output_path_is_safe(path))
  }
  for
    path in [
      "", " ", "../escape", "a/../escape", "a/..", "/absolute", "C:/drive", "C:\\drive",
      "dir\\file",
    ] {
    assert_true(!office_asset_output_path_is_safe(path))
  }
  let safe_plan = @oshared.make_office_asset_plan("media/a.png", "assets/a.png")
  let unsafe_plan = @oshared.make_office_asset_plan("media/a.png", "../a.png")
  assert_true(office_asset_plan_is_safe(safe_plan))
  assert_true(!office_asset_plan_is_safe(unsafe_plan))
}

///|
test "Office external relationships remain no-fetch regardless of case" {
  let internal = @oshared.make_office_relationship(
    "word/document.xml", "rId1", "image", "media/a.png",
  )
  let external_flag = @oshared.make_office_relationship(
    "word/document.xml",
    "rId2",
    "hyperlink",
    "https://example.test",
    is_external=true,
  )
  let external_mode = @oshared.make_office_relationship(
    "word/document.xml",
    "rId3",
    "hyperlink",
    "https://example.test",
    target_mode=" ExTeRnAl ",
  )
  assert_true(!office_relationship_is_no_fetch(internal))
  assert_true(office_relationship_is_no_fetch(external_flag))
  assert_true(office_relationship_is_no_fetch(external_mode))
}
