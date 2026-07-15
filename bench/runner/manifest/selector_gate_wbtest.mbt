///|
fn selector_gate_manifest() -> String {
  [
    MANIFEST_HEADER,
    "regular-one\ttxt\tsmall\tmoon.mod\tfixture\tsynthetic\t10\tsha\tregular\tproduct\tcontract\taccepted\tnote\texternal_compare\tbaseline_supported\tnon_empty",
    "release-one\ttxt\tsmall\tmoon.mod\tfixture\tsynthetic\t10\tsha\trelease\tproduct\tcontract\taccepted\tnote\texternal_compare\tbaseline_supported\tnon_empty",
    "",
  ].join("\n")
}

///|
test "selector exact tiers account for limits without an external corpus" {
  let request = make_select_request(
    "stress",
    [" regular ", "RELEASE"],
    [],
    [],
    Some(1),
    SelectOutput::Jsonl,
    true,
  )
  let manifest = selector_gate_manifest()
  let rows = select_rows_from_manifest(
    manifest, "memory/MANIFEST.tsv", ".", request,
  )
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].bench_id, "regular-one")
  let stats = selector_stats_from_manifest(
    manifest, "memory/MANIFEST.tsv", ".", request,
  ).stringify()
  assert_true(stats.contains("\"requested_tiers\":[\"regular\",\"release\"]"))
  assert_true(stats.contains("\"tier_filter_mode\":\"exact\""))
  assert_true(stats.contains("\"limit_excluded\":1"))
}

///|
test "selector helper boundaries remain deterministic and repository local" {
  assert_eq(tier_rank("smoke"), 0)
  assert_eq(tier_rank("release"), 2)
  assert_eq(tier_rank("unsupported"), 100)
  let skipped : Map[String, Int] = Map([])
  increment_skip_reason(skipped, "filtered")
  increment_skip_reason(skipped, "filtered")
  assert_true(skipped.get("filtered") == Some(2))
  assert_true(
    missing_external_bench_message().contains("MARKITDOWN_BENCH_ROOT"),
  )

  let name = "MARKITDOWN_SELECTOR_GATE_TEST"
  let previous = @env.get_env_var(name)
  @env.unset_env_var(name)
  defer (match previous {
    Some(value) => @env.set_env_var(name, value)
    None => @env.unset_env_var(name)
  })
  assert_true(normalized_env_var(name) is None)
  @env.set_env_var(name, "   ")
  assert_true(normalized_env_var(name) is None)
  @env.set_env_var(name, " /tmp/local-corpus ")
  assert_true(normalized_env_var(name) == Some("/tmp/local-corpus"))
}
