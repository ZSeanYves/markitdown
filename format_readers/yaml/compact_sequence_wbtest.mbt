///|
test "YAML compact sequence validates the official homogeneous fixture shape" {
  let out = StringBuilder::new()
  out.write_string("items:\n")
  let padding = "x".repeat(900)
  for i in 1..<=1024 {
    out.write_string("  - id: " + i.to_string() + "\n")
    out.write_string("    name: item-" + i.to_string() + "\n")
    out.write_string("    title: \"" + padding + "\"\n")
    out.write_string("    region: \"'emea'\"\n")
    out.write_string("    enabled: \"'false'\"\n")
    out.write_string("    score: 19\n")
    out.write_string("    tags:\n")
    out.write_string("      - deterministic\n      - yaml\n      - group-1\n")
    out.write_string("    links:\n")
    out.write_string("      home: https://example.com/yaml/1\n")
    out.write_string("      docs: https://example.com/yaml/1/docs\n")
  }
  let compact = prepare_yaml_compact_sequence_summary(out.to_string()).unwrap()
  assert_eq(compact.inspect.node_count, 14338)
  assert_true(compact.value_summary.has_prefix("[ 1024 items:"))
}

///|
test "YAML compact sequence accepts a self-contained huge-shaped fixture" {
  let out = StringBuilder::new()
  out.write_string("items:\n")
  let padding = "x".repeat(900)
  for i in 1..<=2048 {
    out.write_string("  - id: " + i.to_string() + "\n")
    out.write_string("    name: item-" + i.to_string() + "\n")
    out.write_string("    title: \"" + padding + "\"\n")
    out.write_string("    region: \"'emea'\"\n")
    out.write_string("    enabled: \"'false'\"\n")
    out.write_string("    score: 19\n")
    out.write_string("    tags:\n")
    out.write_string("      - deterministic\n      - yaml\n      - group-1\n")
    out.write_string("    links:\n")
    out.write_string("      home: https://example.com/yaml/1\n")
    out.write_string("      docs: https://example.com/yaml/1/docs\n")
  }
  let prepared = prepare_yaml_document_from_source(
    @input.input_from_text_with_format(
      out.to_string(),
      "self-contained-huge.yaml",
      Some(Yaml),
    ),
  ).unwrap()
  let compact = prepared.compact_sequence.unwrap()
  assert_true(compact.inspect.node_count > 10_000)
  assert_true(compact.line_end > 10_000)
}
