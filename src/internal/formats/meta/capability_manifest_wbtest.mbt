///|
test "capability manifest is generated from all registry entries and marks msg as alias" {
  let manifest = capability_manifest_json()
  let rendered = manifest.stringify()
  for entry in capability_registry_entries() {
    assert_true(
      rendered.contains(
        "\"format\":\"" + @input.detected_format_name(entry.format) + "\"",
      ),
    )
  }
  assert_true(rendered.contains("\"alias\":\"msg\""))
  assert_true(rendered.contains("\"target\":\"eml\""))
  assert_true(rendered.contains("\"native_binary_support\":false"))
}
