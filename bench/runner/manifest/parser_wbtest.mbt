///|
test "bench manifest select arguments cover filters output stats and validation" {
  let request = parse_select_request([
    "--tier", "release", "--tiers", "regular,stress", "--bench-id", "one,two", "--format",
    "pdf,html", "--limit", "0", "--output", "tsv", "--stats",
  ])
  assert_eq(request.tier, "release")
  assert_true(request.exact_tiers == ["regular", "stress"])
  assert_true(request.bench_ids == ["one", "two"])
  assert_true(request.format_filters == ["pdf", "html"])
  assert_true(request.limit == Some(0))
  assert_true(request.output == SelectOutput::Tsv)
  assert_true(request.stats_only)
  assert_true(parse_select_request([]).output == SelectOutput::Jsonl)
  assert_true(
    parse_tier_list(" Regular , RELEASE ", "--tiers") == ["regular", "release"],
  )
  validate_tier("smoke")
  validate_tier("regular")
  validate_tier("release")
  validate_tier("stress")
  validate_tiers(["smoke", "stress"])
}

///|
test "bench manifest select arguments reject incomplete and invalid values" {
  let invalid = [
    ["--tier"],
    ["--tiers", ""],
    ["--tiers", "unknown"],
    ["--bench-id", ",,"],
    ["--format", ""],
    ["--limit", "bad"],
    ["--limit", "-1"],
    ["--output", "xml"],
    ["--unknown"],
  ]
  for args in invalid {
    let failed = try {
      ignore(parse_select_request(args))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
}

///|
fn manifest_test_row(
  source_kind? : String = "fixture",
  enabled_tier? : String = "regular",
  review_status? : String = "accepted",
  input_bytes? : Int = 10,
  rel_path? : String = "missing/test.txt",
  format? : String = "txt",
  bench_id? : String = "row",
) -> BenchRow {
  make_bench_row(
    bench_id,
    format,
    "small",
    rel_path,
    source_kind,
    "source",
    input_bytes,
    "sha",
    enabled_tier,
    ["product"],
    ["contract"],
    review_status,
    "notes",
    if rel_path == "missing/test.txt" {
      rel_path
    } else {
      "moon.mod"
    },
  )
}

///|
fn synthetic_manifest() -> String {
  [
    MANIFEST_HEADER,
    "one\ttxt\tsmall\tmoon.mod\tfixture\tsynthetic\t10\tsha\tregular\tproduct\tcontract\taccepted\tnote\texternal_compare\tbaseline_supported\tnon_empty",
    "stress\tpdf\tsmall\tmoon.mod\tfixture\tsynthetic\t10\tsha\tstress\tproduct\tcontract\taccepted\tnote\texternal_compare\tbaseline_supported\tnon_empty",
    "missing\thtml\tsmall\tmissing/test.html\tfixture\tsynthetic\t10\tsha\tregular\tproduct\tcontract\taccepted\tnote\texternal_compare\tbaseline_supported\tnon_empty",
  ].join("\n")
}

///|
test "bench manifest selector reports exclusions and accepts synthetic payload" {
  let cumulative = make_select_request(
    "regular",
    [],
    [],
    [],
    None,
    SelectOutput::Jsonl,
    false,
  )
  assert_true(
    should_skip_row(
      manifest_test_row(source_kind="missing_candidate"),
      cumulative,
    ) ==
    Some("missing_candidate"),
  )
  assert_true(
    should_skip_row(
      manifest_test_row(review_status="missing_candidate"),
      cumulative,
    ) ==
    Some("review_status_missing_candidate"),
  )
  assert_true(
    should_skip_row(manifest_test_row(enabled_tier="disabled"), cumulative) ==
    Some("disabled"),
  )
  assert_true(
    should_skip_row(manifest_test_row(enabled_tier="mystery"), cumulative) ==
    Some("unknown_tier"),
  )
  assert_true(
    should_skip_row(manifest_test_row(enabled_tier="stress"), cumulative) ==
    Some("tier_excluded"),
  )
  let exact = make_select_request(
    "stress",
    ["release"],
    [],
    [],
    None,
    SelectOutput::Jsonl,
    false,
  )
  assert_true(
    should_skip_row(manifest_test_row(enabled_tier="regular"), exact) ==
    Some("tier_exact_excluded"),
  )
  let ids = make_select_request(
    "stress",
    [],
    ["wanted"],
    [],
    None,
    SelectOutput::Jsonl,
    false,
  )
  assert_true(
    should_skip_row(manifest_test_row(bench_id="other"), ids) ==
    Some("bench_id_filtered"),
  )
  assert_true(
    should_skip_row(manifest_test_row(input_bytes=0), cumulative) ==
    Some("zero_bytes"),
  )
  let formats = make_select_request(
    "stress",
    [],
    [],
    ["pdf"],
    None,
    SelectOutput::Jsonl,
    false,
  )
  assert_true(
    should_skip_row(manifest_test_row(format="html"), formats) ==
    Some("format_filtered"),
  )
  assert_true(
    should_skip_row(manifest_test_row(rel_path=""), cumulative) ==
    Some("missing_rel_path"),
  )
  assert_true(
    should_skip_row(manifest_test_row(), cumulative) == Some("missing_payload"),
  )
  let manifest = synthetic_manifest()
  let real = select_rows_from_manifest(
    manifest,
    "synthetic/MANIFEST.tsv",
    ".",
    make_select_request(
      "regular",
      [],
      [],
      [],
      Some(1),
      SelectOutput::Jsonl,
      false,
    ),
  )
  assert_eq(real.length(), 1)
  assert_true(should_skip_row(real[0], cumulative) is None)
  assert_true(ensure_bench_row_payload(real[0]))
  assert_eq(format_selector_rows_tsv(real).length(), 1)
  let stats = selector_stats_from_manifest(
    manifest,
    "synthetic/MANIFEST.tsv",
    ".",
    make_select_request(
      "regular",
      [],
      [],
      [],
      Some(1),
      SelectOutput::Jsonl,
      true,
    ),
  )
  assert_true(stats.stringify().contains("selected_rows"))
  assert_eq(empty_selector_stats().selected_rows, 0)
}

///|
test "bench manifest line parser maps comparison metadata" {
  let row = parse_manifest_line_with_root(
    "id\tpdf\tsmall\tpdf/sample.pdf\tfixture\tsource\t12\tsha\tregular\tmicro,product\tcontract,real\taccepted\tnote\texternal_compare\tbaseline_supported\tnon_empty,contains:Title",
    2, ".",
  )
  assert_eq(row.bench_id, "id")
  assert_eq(row.input_bytes, 12)
  assert_true(row.bench_layers == ["micro", "product"])
  assert_true(row.tags == ["contract", "real"])
  assert_eq(row.comparison_class, "external_compare")
  assert_true(row.comparison_signals == ["non_empty", "contains:Title"])
}
