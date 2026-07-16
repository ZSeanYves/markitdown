///|
fn bench_test_tmp_root() -> String {
  ".tmp/tests/bench-runner"
}

///|
fn bench_ensure_dir(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    @fs.create_dir(path)
  }
}

///|
fn bench_ensure_dir_tree(path : String) -> Unit raise {
  let trimmed = path.trim()
  if trimmed == "" {
    return
  }
  let chars = trimmed.to_array()
  let mut current = if chars.length() > 0 && chars[0] == '/' { "/" } else { "" }
  let part : Array[Char] = []

  fn flush(part : Array[Char], current : String) -> String raise {
    if part.length() == 0 {
      return current
    }
    let segment = String::from_array(part)
    part.clear()
    let next = if current == "" || current == "/" {
      current + segment
    } else {
      current + "/" + segment
    }
    bench_ensure_dir(next)
    next
  }

  for ch in chars {
    if ch == '/' {
      current = flush(part, current)
    } else {
      part.push(ch)
    }
  }
  ignore(flush(part, current))
}

///|
fn bench_remove_dir_recursive(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    return
  }
  for name in @fs.read_dir(path) {
    let child = path + "/" + name
    if @fs.is_dir(child) {
      bench_remove_dir_recursive(child)
    } else if @fs.is_file(child) {
      @fs.remove_file(child)
    }
  }
  @fs.remove_dir(path)
}

///|
fn bench_recreate_clean_dir(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    bench_remove_dir_recursive(path)
  }
  bench_ensure_dir_tree(path)
}

///|
fn bench_cleanup_temp_dir(path : String) -> Unit {
  ignore(
    try bench_remove_dir_recursive(path) |> Ok catch {
      _ => Err(())
    },
  )
}

///|
fn bench_read_utf8_text(path : String) -> String {
  @fs.read_file_to_string(path, encoding="utf8") catch {
    err => abort("read failed: " + err.to_string())
  }
}

///|
fn bench_write_utf8_text(path : String, content : String) -> Unit raise {
  @fs.write_string_to_file(path, content, encoding="utf8")
}

///|
fn with_env_var(
  name : String,
  value : String,
  body : () -> Unit raise,
) -> Unit raise {
  let previous = @env.get_env_var(name)
  @env.set_env_var(name, value)
  defer (match previous {
    Some(old) => @env.set_env_var(name, old)
    None => @env.unset_env_var(name)
  })
  body()
}

///|
test "bench runner context detects release and development invocations" {
  let release = @command.detect_runner_context([
    "/repo/_build/native/release/build/bench/runner/runner.exe", "doctor",
  ])
  assert_true(
    release ==
    @command.make_runner_context(
      "release",
      Some("/repo/_build/native/release/build/bench/runner/runner.exe"),
    ),
  )
  let debug = @command.detect_runner_context([
    "/repo/_build/native/debug/build/bench/runner/runner.exe", "doctor",
  ])
  assert_true(
    debug ==
    @command.make_runner_context(
      "dev_moon_run",
      Some("/repo/_build/native/debug/build/bench/runner/runner.exe"),
    ),
  )
  let moon_run = @command.detect_runner_context([
    "moon", "bench/runner", "doctor",
  ])
  assert_true(moon_run == @command.make_runner_context("dev_moon_run", None))
}

///|
test "bench runner context handles unknown argv and explicit override" {
  assert_true(
    @command.detect_runner_context([]) ==
    @command.make_runner_context("unknown", None),
  )
  assert_true(
    @command.detect_runner_context(["moon", "test"]) ==
    @command.make_runner_context("unknown", None),
  )
  with_env_var("MARKITDOWN_BENCH_RUNNER_MODE", " release ", () => {
    assert_true(
      @command.detect_runner_context(["runner", "doctor"]) ==
      @command.make_runner_context("release", Some("runner")),
    )
  })
  with_env_var("MARKITDOWN_BENCH_RUNNER_MODE", "invalid", () => {
    assert_true(
      @command.detect_runner_context(["runner.exe"]) ==
      @command.make_runner_context("unknown", Some("runner.exe")),
    )
  })
}

///|
fn bench_manifest_fixture_root() -> String {
  bench_test_tmp_root() + "/external-bench-fixture"
}

///|
fn bench_manifest_header() -> String {
  "bench_id\tformat\tsize_class\trel_path\tsource_kind\tsource_ref\tbytes\tsha256\tenabled_tier\tbench_layers\ttags\treview_status\tnotes\tcomparison_class\tcomparison_reason\tcomparison_signals"
}

///|
fn bench_manifest_fixture_manifest() -> String {
  bench_manifest_header() +
  "\n" +
  "markdown_large_commonmark_spec_v1\tmarkdown\tlarge\tmarkdown/large/markdown_large_commonmark_spec_v1.md\tcopied_from_external_bench\tlocal\t1024\tsha\tregular\texternal_bench\t\treviewed\tfixture-note\texternal_compare\tbaseline_supported\tnon_empty\n"
}

///|
fn setup_bench_manifest_fixture(root : String) -> Unit raise {
  bench_recreate_clean_dir(root)
  let sample_dir = root + "/markdown/large"
  bench_ensure_dir_tree(sample_dir)
  bench_write_utf8_text(
    root + "/MANIFEST.tsv",
    bench_manifest_fixture_manifest(),
  )
  bench_write_utf8_text(
    sample_dir + "/markdown_large_commonmark_spec_v1.md",
    "# Benchmark Fixture\n\nThis payload keeps bench runner whitebox tests repo-local.\n",
  )
}

///|
fn sample_route_provenance(
  route? : String = "block_streaming",
  fidelity? : String = "matched",
) -> Json {
  Json::object({
    "route_plan": Json::object({
      "selected_route": route.to_json(),
      "route_reason": "test_route".to_json(),
      "route_probe_summary": "route_probe:test".to_json(),
    }),
    "effective_parser_mode": "streaming".to_json(),
    "parse_result_kind": "block_stream".to_json(),
    "pipeline_output_kind": "block_stream".to_json(),
    "render_input_kind": "block_stream".to_json(),
    "route_fidelity_status": fidelity.to_json(),
  })
}

///|
fn sample_case_for_trust(
  tool : String,
  route_provenance : Json,
  expected_route? : String? = Some("block_streaming"),
  semantic_coverage? : String = "ok",
) -> CaseAggregate {
  let actual_route = actual_route_name(route_provenance)
  let coverage = route_coverage_status(
    tool, route_provenance, expected_route, actual_route,
  )
  let provenance_complete = route_provenance_complete(route_provenance)
  let fidelity = route_fidelity_status(route_provenance)
  {
    schema_version: 2,
    run_id: "run-test",
    scenario_id: "product.official_internal",
    tool,
    bench_id: "markdown_large_commonmark_spec_v1",
    format: "markdown",
    size_class: "large",
    input_bytes: 1024,
    sample_count: 3,
    success_count: 3,
    median_wall_us: Some(100L),
    min_wall_us: Some(90L),
    max_wall_us: Some(110L),
    median_output_bytes: Some(900L),
    output_density: Some(0.8),
    comparable_status: "comparable",
    route_coverage_status: coverage,
    semantic_coverage,
    render_path: render_path(route_provenance),
    trust_status: case_trust_status(
      tool, coverage, semantic_coverage, fidelity, provenance_complete,
    ),
    trust_failure_reason: case_trust_failure_reason(
      tool, coverage, semantic_coverage, fidelity, provenance_complete,
    ),
    expected_route,
    actual_route,
    route_fidelity_status: fidelity,
    provenance_complete,
    route_provenance,
  }
}

///|
fn sample_row(
  scenario_id : String,
  scenario_kind : String,
  official_membership : String,
  tool : String,
  bench_id : String,
  format : String,
  route_provenance : Json,
) -> SampleRow {
  {
    schema_version: 2,
    run_id: "run-fixture",
    scenario_id,
    scenario_kind,
    official_membership,
    tool,
    measurement_mode: if tool == "moonbit-engine" {
      "inprocess-engine"
    } else {
      "process-cli"
    },
    measurement_policy: "warmup=1;samples=3;order=row_major_interleaved",
    repeat_index: 0,
    repeat_count: 3,
    warmup_count: 1,
    bench_id,
    format,
    size_class: "large",
    enabled_tier: "regular",
    rel_path: format + "/large/" + bench_id,
    input_bytes: 1024,
    input_sha256: "sha",
    status: "ok",
    exit_code: 0,
    timed_out: false,
    wall_us: Some(100L),
    peak_rss_kb: None,
    output_bytes: 800L,
    output_sha256: Some("output-sha"),
    error: None,
    route_provenance,
    runner_artifact_identity: "_build/native/release/build/bench/runner/runner.exe",
    cli_artifact_path: if tool == "moonbit-cli" {
      Some("_build/native/release/build/cli/cli.exe")
    } else {
      None
    },
  }
}

///|
fn sample_run_options(
  limit? : Int? = None,
  repeat_count? : Int = 3,
  warmup_count? : Int = 1,
) -> RunOptions {
  {
    preset: Some("official-internal"),
    scenario_id: None,
    exact_tiers: ["regular"],
    bench_ids: [],
    format_filters: ["markdown"],
    limit,
    repeat_count,
    warmup_count,
    timeout_ms: 60000,
    markitdown_path: None,
    baseline_run_id: None,
    progress_mode: "off",
    keep_outputs: "failures",
    resume_run_id: None,
    max_disk_mb: 4096,
  }
}

///|
test "policy preset expands all configured scenario ids" {
  let policy = match load_policy() {
    Ok(value) => value
    Err(err) => fail("policy should decode: " + err.to_string())
  }
  let scenarios = resolve_scenarios(
    {
      preset: Some("official-internal"),
      scenario_id: None,
      exact_tiers: [],
      bench_ids: [],
      format_filters: [],
      limit: None,
      repeat_count: 3,
      warmup_count: 1,
      timeout_ms: 60000,
      markitdown_path: None,
      baseline_run_id: None,
      progress_mode: "off",
      keep_outputs: "failures",
      resume_run_id: None,
      max_disk_mb: 4096,
    },
    policy,
  )
  assert_true(scenarios.length() > 1)
  assert_eq(scenarios[0].scenario_id, "product.official_internal")
  assert_true(
    scenarios.any(fn(item) { item.scenario_id == "diagnostic.markdown" }),
  )
  assert_true(scenarios.any(fn(item) { item.scenario_id == "diagnostic.srt" }))
  assert_true(
    scenarios.any(fn(item) { item.scenario_id == "diagnostic.jsonl" }),
  )
  assert_true(
    scenarios.any(fn(item) { item.scenario_id == "diagnostic.asciidoc" }),
  )
}

///|
test "benchmark policy owns defaults RSS budgets and change-risk coverage" {
  let policy = load_policy().unwrap()
  assert_eq(policy.default_rss_limit_mb, 256)
  assert_eq(rss_limit_mb(policy, "html", "huge"), 256)
  assert_eq(rss_limit_mb(policy, "pdf", "large"), 256)
  assert_eq(rss_limit_mb(policy, "xlsx", "huge"), 384)
  assert_eq(rss_limit_mb(policy, "zip", "large"), 256)
  let defaults = apply_policy_defaults(parse_run_options([]), policy)
  assert_eq(defaults.repeat_count, 3)
  assert_eq(defaults.warmup_count, 1)
  assert_eq(defaults.timeout_ms, 60000)
  let explicit_three = apply_policy_defaults(
    parse_run_options(["--preset", "doctor", "--repeat", "3"]),
    policy,
  )
  assert_eq(explicit_three.repeat_count, 3)
  let change_risk_opts = apply_policy_defaults(
    parse_run_options(["--preset", "change-risk"]),
    policy,
  )
  let scenarios = resolve_scenarios(change_risk_opts, policy)
  assert_eq(scenarios.length(), 8)
  let formats : Array[String] = []
  for scenario in scenarios {
    formats.append(scenario.format_filters)
  }
  for
    format in ["html", "pdf", "xlsx", "zip", "docx", "pptx", "eml", "markdown"] {
    assert_true(formats.contains(format))
  }
}

///|
test "bench progress total counts process warmups and repeats plus engine repeats" {
  let policy = match load_policy() {
    Ok(value) => value
    Err(err) => fail("policy should decode: " + err.to_string())
  }
  let root = bench_manifest_fixture_root()
  setup_bench_manifest_fixture(root) catch {
    err => fail("setup bench manifest fixture failed: " + err.to_string())
  }
  defer bench_cleanup_temp_dir(root)

  with_env_var("MARKITDOWN_BENCH_ROOT", root, fn() raise {
    let scenario = resolve_scenarios(sample_run_options(limit=Some(1)), policy)[0]
    let total = bench_progress_total(
      [scenario],
      sample_run_options(limit=Some(1), repeat_count=2, warmup_count=1),
    )
    assert_eq(total, 5)
  }) catch {
    err => fail("bench progress total fixture run failed: " + err.to_string())
  }
}

///|
test "bench progress label includes scenario tool bench id and phase counter" {
  let row = @manifest.make_bench_row(
    "markdown_large_commonmark_spec_v1",
    "markdown",
    "regular",
    "markdown/large/markdown_large_commonmark_spec_v1.md",
    "copied_from_external_bench",
    "local",
    1024,
    "sha",
    "regular",
    ["external_bench"],
    [],
    "reviewed",
    "",
    "samples/fixtures/contracts/markdown/markdown_basic_heading_paragraph.md",
  )
  let label = bench_progress_label(
    {
      scenario_id: "compare.official_compare",
      scenario_kind: "compare",
      tool_names: ["moonbit-cli", "markitdown"],
      exact_tiers: ["regular"],
      format_filters: ["markdown"],
      comparison_classes: [],
      official_membership: "official-compare",
      route_expectation: "canonical",
    },
    "markitdown",
    row,
    "sample",
    1,
    3,
  )
  assert_eq(
    label, "compare.official_compare markitdown markdown_large_commonmark_spec_v1 sample 2/3",
  )
}

///|
test "bench run options parse productized progress retention resume and disk controls" {
  let opts = parse_run_options([
    "--progress=json", "--keep-outputs", "all", "--resume", "run-existing", "--max-disk-mb",
    "2048",
  ]) catch {
    err => fail("run controls should parse: " + err.to_string())
  }
  assert_eq(opts.progress_mode, "json")
  assert_eq(opts.keep_outputs, "all")
  assert_true(opts.resume_run_id == Some("run-existing"))
  assert_eq(opts.max_disk_mb, 2048)
}

///|
test "bench run options reject unsupported progress and retention modes" {
  let progress_failed = try {
    ignore(parse_run_options(["--progress=verbose"]))
    false
  } catch {
    _ => true
  }
  let retention_failed = try {
    ignore(parse_run_options(["--keep-outputs=unknown"]))
    false
  } catch {
    _ => true
  }
  assert_true(progress_failed)
  assert_true(retention_failed)
}

///|
test "bench JSON progress is structured and output retention keeps failures" {
  let rendered = bench_progress_json(2, 5, "ok", "case one")
  assert_true(rendered.contains("\"event\":\"bench_progress\""))
  assert_true(rendered.contains("\"completed\":2"))

  let root = bench_manifest_fixture_root() + "/retention"
  setup_bench_manifest_fixture(root) catch {
    err => fail("setup retention fixture failed: " + err.to_string())
  }
  defer bench_cleanup_temp_dir(root)
  let success_path = root + "/success.md"
  let failure_path = root + "/failure.md"
  let success_assets = root + "/assets/nested"
  bench_ensure_dir_tree(success_assets)
  @fs.write_string_to_file(success_path, "ok", encoding="utf8") catch {
    err => fail("write success fixture failed: " + err.to_string())
  }
  @fs.write_string_to_file(failure_path, "failed", encoding="utf8") catch {
    err => fail("write failure fixture failed: " + err.to_string())
  }
  @fs.write_string_to_file(
    success_assets + "/image.png",
    "asset",
    encoding="utf8",
  ) catch {
    err => fail("write success asset fixture failed: " + err.to_string())
  }
  cleanup_bench_output(success_path, "ok", "failures")
  cleanup_bench_output(failure_path, "failed", "failures")
  assert_true(!@fs.path_exists(success_path))
  assert_true(!@fs.path_exists(root + "/assets"))
  assert_true(@fs.path_exists(failure_path))

  let keep_all = root + "/keep-all.md"
  @fs.write_string_to_file(keep_all, "all", encoding="utf8") catch {
    err => fail("write keep-all fixture failed: " + err.to_string())
  }
  cleanup_bench_output(keep_all, "ok", "all")
  assert_true(@fs.path_exists(keep_all))
}

///|
test "bench resume identity matches one exact sample" {
  let sample = sample_row(
    "compare.official_compare",
    "compare",
    "official-compare",
    "moonbit-cli",
    "txt_small",
    "txt",
    Json::object({ "status": "ok".to_json() }),
  )
  assert_true(
    sample_completed(
      [sample],
      "compare.official_compare",
      "moonbit-cli",
      "txt_small",
      0,
      "sha",
      "warmup=1;samples=3;order=row_major_interleaved",
      "_build/native/release/build/bench/runner/runner.exe",
    ),
  )
  assert_true(
    !sample_completed(
      [sample],
      "compare.official_compare",
      "moonbit-cli",
      "txt_small",
      1,
      "sha",
      "warmup=1;samples=3;order=row_major_interleaved",
      "_build/native/release/build/bench/runner/runner.exe",
    ),
  )
}

///|
test "benchmark resource summary records peak rss timeout disk policy and retention" {
  let root = bench_manifest_fixture_root() + "/resource-summary"
  bench_recreate_clean_dir(root) catch {
    err => fail("setup resource summary fixture failed: " + err.to_string())
  }
  defer bench_cleanup_temp_dir(root)
  let sample = sample_row(
    "compare.official_compare",
    "compare",
    "official-compare",
    "moonbit-cli",
    "txt_small",
    "txt",
    sample_route_provenance(),
  )
  let timed_out = { ..sample, timed_out: true, peak_rss_kb: Some(4096L) }
  let summary = benchmark_resource_summary(
    "missing-resource-run",
    [sample, timed_out],
    sample_run_options(),
  ).stringify()
  assert_true(summary.contains("\"peak_rss_kb\":\"4096\""))
  assert_true(summary.contains("\"timed_out_samples\":1"))
  assert_true(summary.contains("\"max_disk_mb\":4096"))
  assert_true(summary.contains("\"keep_outputs\":\"failures\""))
}

///|
test "schema two benchmark summaries remain readable without resource fields" {
  let run_id = "compat-summary-fixture"
  bench_recreate_clean_dir(run_root(run_id)) catch {
    err =>
      fail("setup compatibility summary fixture failed: " + err.to_string())
  }
  defer bench_cleanup_temp_dir(run_root(run_id))
  bench_ensure_dir_tree(results_root(run_id))
  let legacy = [
    "{",
    "\"schema_version\":2,",
    "\"run_id\":\"" + run_id + "\",",
    "\"preset\":\"official-compare\",",
    "\"scenario_ids\":[],",
    "\"binary_only_contract\":{},",
    "\"trust_status\":\"trusted\",",
    "\"gate_summary\":{},",
    "\"route_coverage_summary\":{},",
    "\"truth_summary\":{},",
    "\"scenarios\":[],",
    "\"tools\":[],",
    "\"by_format\":[]",
    "}",
  ].join("")
  @fs.write_string_to_file(summary_json_path(run_id), legacy, encoding="utf8") catch {
    err => fail("write legacy summary failed: " + err.to_string())
  }
  match load_summary(run_id) {
    Ok(summary) => {
      assert_true(summary.resource_summary is None)
      assert_true(summary.resume_summary is None)
    }
    Err(err) =>
      fail("legacy summary should remain readable: " + err.to_string())
  }
}

///|
test "bench progress render line omits empty labels and truncates long labels" {
  assert_eq(
    bench_progress_render_line(2, 10, "running", ""),
    "progress: 2/10 running",
  )
  let long = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
  let rendered = bench_progress_render_line(1, 3, "running", long)
  assert_true(rendered.contains("progress: 1/3 running "))
  assert_true(rendered.has_suffix("..."))
}

///|
test "bench engine options enable product-default direct image OCR and explicit format binding" {
  let row = @manifest.make_bench_row(
    "ocr_medium_self_multi_column_v1",
    "png",
    "regular",
    "ocr/medium/ocr_medium_self_multi_column_v1.png",
    "copied_from_external_quality",
    "local",
    1024,
    "sha",
    "regular",
    ["external_bench"],
    ["ocr"],
    "reviewed",
    "",
    "samples/fixtures/contracts/ocr/ocr_medium_self_multi_column_v1.png",
  )
  let options = bench_convert_options_for_row(row)
  assert_true(options.explicit_format == Some(Image(Png)))
  assert_true(options.ocr_options.intent == Explicit)
}

///|
test "bench engine options detect the project synthetic OCR image format" {
  let row = @manifest.make_bench_row(
    "ocr_medium_self_multi_column_v1",
    "ocr",
    "regular",
    "ocr/medium/ocr_medium_self_multi_column_v1.png",
    "copied_from_external_quality",
    "local",
    1024,
    "sha",
    "regular",
    ["external_bench"],
    ["ocr"],
    "reviewed",
    "",
    "samples/fixtures/contracts/ocr/ocr_medium_self_multi_column_v1.png",
  )
  let options = bench_convert_options_for_row(row)
  assert_true(options.explicit_format == Some(Image(Png)))
  assert_true(options.ocr_options.intent == Explicit)
}

///|
test "route provenance completeness requires full convert provenance" {
  let incomplete = Json::object({
    "route_plan": Json::object({
      "selected_route": "block_streaming".to_json(),
      "route_reason": "test".to_json(),
      "route_probe_summary": "route_probe:test".to_json(),
    }),
    "render_input_kind": "block_stream".to_json(),
  })
  assert_true(!route_provenance_complete(incomplete))
  assert_true(route_provenance_complete(sample_route_provenance()))
}

///|
test "moonbit trust fails on missing provenance" {
  let case_ = sample_case_for_trust(
    "moonbit-cli",
    Json::object({ "missing": true.to_json() }),
  )
  assert_eq(case_.trust_status, "failed")
  assert_eq(case_.trust_failure_reason, "missing_provenance")
}

///|
test "moonbit trust fails on route fidelity mismatch" {
  let case_ = sample_case_for_trust(
    "moonbit-engine",
    sample_route_provenance(fidelity="parser_mode_mismatch"),
  )
  assert_eq(case_.trust_status, "failed")
  assert_eq(case_.trust_failure_reason, "fidelity_mismatch")
}

///|
test "moonbit trust fails on expected route mismatch" {
  let case_ = sample_case_for_trust(
    "moonbit-cli",
    sample_route_provenance(route="streaming_event"),
  )
  assert_eq(case_.route_coverage_status, "mismatch")
  assert_eq(case_.trust_status, "failed")
  assert_eq(case_.trust_failure_reason, "route_mismatch")
}

///|
test "moonbit trust keeps low density guard" {
  let case_ = sample_case_for_trust(
    "moonbit-cli",
    sample_route_provenance(),
    semantic_coverage="low_density_untrusted",
  )
  assert_eq(case_.trust_status, "failed")
  assert_eq(case_.trust_failure_reason, "low_density_untrusted")
}

///|
test "report regeneration recomputes current truth summary from samples" {
  let root = bench_test_tmp_root() + "/bench-report"
  bench_recreate_clean_dir(root)
  defer bench_cleanup_temp_dir(root)

  let run_id = "wbtest-report"
  ensure_bench_dirs(run_id) catch {
    err => fail("ensure bench dirs failed: " + err.to_string())
  }
  defer bench_cleanup_temp_dir(run_root(run_id))

  let samples = [
    sample_row(
      "product.official_internal",
      "product",
      "official-internal",
      "moonbit-cli",
      "markdown_large_commonmark_spec_v1",
      "markdown",
      sample_route_provenance(),
    ),
    sample_row(
      "diagnostic.markdown",
      "diagnostic",
      "none",
      "moonbit-engine",
      "markdown_large_commonmark_spec_v1",
      "markdown",
      sample_route_provenance(fidelity="ir_shape_mismatch"),
    ),
  ]
  write_jsonl(samples_jsonl_path(run_id), samples.map(item => item.to_json())) catch {
    err => fail("write samples failed: " + err.to_string())
  }
  let summary = RunSummary::{
    schema_version: 2,
    run_id,
    preset: Some("official-internal"),
    scenario_ids: ["product.official_internal", "diagnostic.markdown"],
    binary_only_contract: Json::object({
      "runner_path": "_build/native/release/build/bench/runner/runner.exe".to_json(),
      "cli_path": "_build/native/release/build/cli/cli.exe".to_json(),
      "runner_release_ok": true.to_json(),
      "cli_release_ok": true.to_json(),
      "used_moon_delegate": false.to_json(),
    }),
    trust_status: "trusted",
    gate_summary: Json::object({ "status": "ok".to_json() }),
    route_coverage_summary: Json::empty_object(),
    truth_summary: Json::empty_object(),
    diff_summary: None,
    scenarios: [],
    tools: [],
    by_format: [],
    resource_summary: None,
    resume_summary: None,
  }
  write_summary_and_report(run_id, summary) catch {
    err => fail("seed summary failed: " + err.to_string())
  }

  let regenerated = match regenerate_report(run_id, None) {
    Ok(value) => value
    Err(err) => fail("regenerate report failed: " + err.to_string())
  }
  assert_eq(regenerated.trust_status, "failed")
  assert_eq(
    json_int_field(regenerated.truth_summary, "fidelity_mismatch_cases"),
    1,
  )
  assert_true(
    bench_read_utf8_text(report_markdown_path(run_id)).contains(
      "fidelity_mismatch_cases=`1`",
    ),
  )
}

///|
test "run id fingerprint reflects argument content, not only length" {
  let left = run_id_fingerprint(["run", "--scenario", "diagnostic.html"])
  let right = run_id_fingerprint(["run", "--scenario", "diagnostic.xlsx"])
  assert_true(left != right)
}

///|
test "ensure dir tree tolerates already-created segments" {
  let root = bench_test_tmp_root() + "/dir-race/a/b"
  bench_recreate_clean_dir(bench_test_tmp_root() + "/dir-race")
  defer bench_cleanup_temp_dir(bench_test_tmp_root() + "/dir-race")

  ensure_dir_tree(root) catch {
    err => fail("initial ensure dir tree failed: " + err.to_string())
  }
  ensure_dir_tree(root) catch {
    err => fail("repeated ensure dir tree failed: " + err.to_string())
  }

  assert_true(@fs.path_exists(root))
}

///|
test "bench CLI entry dispatches help catalog and controlled argument failures" {
  let was_enabled = bench_console_enabled.val
  bench_console_enabled.val = false
  defer {
    bench_console_enabled.val = was_enabled
  }
  let dev = @command.make_runner_context("dev_moon_run", None)
  let root = bench_manifest_fixture_root()
  setup_bench_manifest_fixture(root) catch {
    err => fail("setup bench CLI manifest fixture failed: " + err.to_string())
  }
  defer bench_cleanup_temp_dir(root)
  assert_eq(run_bench_cli_entry([], dev), 0)
  assert_eq(run_bench_cli_entry(["--help"], dev), 0)
  assert_eq(run_bench_cli_entry(["unknown"], dev), 2)
  assert_eq(run_bench_cli_entry(["catalog"], dev), 2)
  assert_eq(run_bench_cli_entry(["catalog", "unknown"], dev), 2)
  assert_eq(run_bench_cli_entry(["catalog", "scenarios"], dev), 0)
  with_env_var("MARKITDOWN_BENCH_ROOT", root, fn() raise {
    assert_eq(
      run_bench_cli_entry(
        ["catalog", "rows", "--tiers", "regular", "--limit", "1"],
        dev,
      ),
      0,
    )
  })
  assert_eq(run_bench_cli_entry(["run", "--progress", "invalid"], dev), 2)
  assert_eq(run_bench_cli_entry(["report"], dev), 2)
  assert_eq(run_bench_cli_entry(["doctor"], dev), 1)
}

///|
test "bench CLI normalizes executable and moon runner prefixes" {
  let was_enabled = bench_console_enabled.val
  bench_console_enabled.val = false
  defer {
    bench_console_enabled.val = was_enabled
  }
  assert_true(
    normalize_bench_args(["/tmp/runner.exe", "catalog", "scenarios"]) ==
    ["catalog", "scenarios"],
  )
  assert_true(normalize_bench_args(["runner", "doctor"]) == ["doctor"])
  assert_true(
    normalize_bench_args(["tools/bench", "catalog", "rows"]) ==
    ["catalog", "rows"],
  )
  assert_true(
    normalize_bench_args(["bench/runner", "report", "--run", "abc"]) ==
    ["report", "--run", "abc"],
  )
  assert_true(normalize_bench_args(["catalog"]) == ["catalog"])
  assert_true(unwrap_or_report(Ok(7), "ok") == Some(7))
  let failed : Int? = unwrap_or_report(Err(InvalidArgument("bad")), "error")
  assert_true(failed is None)
}

///|
fn execution_test_scenario(tool_names : Array[String]) -> ScenarioSpec {
  {
    scenario_id: "diagnostic.markdown",
    scenario_kind: "diagnostic",
    tool_names,
    exact_tiers: ["regular"],
    format_filters: ["markdown"],
    comparison_classes: [],
    official_membership: "none",
    route_expectation: "product_default",
  }
}

///|
fn execution_test_contract() -> BinaryContract {
  {
    runner_path: "test-runner",
    cli_path: "test-cli",
    runner_release_ok: true,
    cli_release_ok: true,
    used_moon_delegate: false,
  }
}

///|
fn execution_test_row(path : String, id : String) -> @manifest.BenchRow {
  @manifest.make_bench_row(
    id,
    "markdown",
    "small",
    path,
    "fixture",
    "local",
    64,
    "sha-" + id,
    "regular",
    ["product"],
    ["contract"],
    "accepted",
    "",
    path,
  )
}

///|
test "benchmark engine samples cover success failure progress and resume" {
  let opts = sample_run_options(repeat_count=2, warmup_count=1)
  let scenario = execution_test_scenario(["moonbit-engine"])
  let contract = execution_test_contract()
  let progress = Ref(bench_progress_state(4, "off"))
  let row = execution_test_row(
    "samples/fixtures/contracts/markdown/markdown_basic_heading_paragraph.md", "engine-success",
  )
  let samples = run_engine_samples(
    "execution-engine",
    scenario,
    row,
    opts,
    contract,
    progress,
    [],
  )
  assert_eq(samples.length(), 2)
  assert_true(samples.all(sample => sample.status == "ok"))
  assert_true(
    samples.all(sample => {
      sample.measurement_mode == "inprocess-engine+process-rss"
    }),
  )
  assert_true(samples.all(sample => sample.output_bytes > 0L))
  assert_true(samples.all(sample => sample.output_sha256 is Some(_)))
  let resumed = run_engine_samples(
    "execution-engine", scenario, row, opts, contract, progress, samples,
  )
  assert_eq(resumed.length(), 0)
  let missing = run_engine_samples(
    "execution-engine",
    scenario,
    execution_test_row("/definitely/missing/input.md", "engine-failure"),
    sample_run_options(repeat_count=1, warmup_count=0),
    contract,
    progress,
    [],
  )
  assert_eq(missing.length(), 1)
  assert_eq(missing[0].status, "failed")
  assert_true(missing[0].error is Some(_))
}

///|
test "benchmark engine RSS worker validates arguments and writes output" {
  assert_eq(run_engine_worker([]), 2)
  assert_eq(run_engine_worker(["unknown", "input", "output"]), 2)
  let output = ".tmp/bench-test/engine-worker.md"
  ensure_parent_dir(output) catch {
    err => fail(err.to_string())
  }
  assert_eq(
    run_engine_worker([
      "markdown", "samples/fixtures/contracts/markdown/markdown_basic_heading_paragraph.md",
      output,
    ]),
    0,
  )
  assert_true(@fs.read_file_to_string(output, encoding="utf8").length() > 0)
  @fs.remove_file(output) catch {
    _ => ()
  }
  assert_eq(
    run_engine_worker(["markdown", "/definitely/missing/input.md", output]),
    1,
  )
  assert_eq(
    run_engine_worker([
      "markdown", "samples/fixtures/contracts/markdown/markdown_basic_heading_paragraph.md",
      ".tmp",
    ]),
    1,
  )
  let measured = measure_engine_worker_rss(
    { ..execution_test_contract(), runner_path: "/usr/bin/true" },
    execution_test_row(
      "samples/fixtures/contracts/markdown/markdown_basic_heading_paragraph.md",
      "engine-rss",
    ),
    ".tmp/bench-test/engine-rss.md",
    ".tmp/bench-test/engine-rss.stdout",
    ".tmp/bench-test/engine-rss.stderr",
    1000,
  )
  assert_true(measured is Some(result) && result.data.exit_code == 0)
}

///|
test "benchmark process samples record unavailable tool without execution" {
  let opts = sample_run_options(repeat_count=2, warmup_count=1)
  let scenario = execution_test_scenario(["markitdown"])
  let tool = @tools.markitdown_tool(
    explicit_path=Some("/definitely/missing/markitdown"),
  )
  assert_true(!tool.is_available())
  let progress = Ref(bench_progress_state(2, "off"))
  let row = execution_test_row(
    "samples/fixtures/contracts/markdown/markdown_basic_heading_paragraph.md", "process-unavailable",
  )
  let samples = run_process_samples(
    "execution-process",
    scenario,
    row,
    tool,
    opts,
    execution_test_contract(),
    progress,
    [],
  )
  assert_eq(samples.length(), 2)
  assert_true(samples.all(sample => sample.status == "unavailable"))
  assert_true(samples.all(sample => sample.measurement_mode == "process-cli"))
  assert_true(samples.all(sample => sample.error is Some(_)))
}

///|
test "benchmark progress and output hash helpers are deterministic" {
  let was_enabled = bench_console_enabled.val
  bench_console_enabled.val = false
  defer {
    bench_console_enabled.val = was_enabled
  }
  assert_eq(bench_progress_truncate("short", max=8), "short")
  assert_eq(bench_progress_truncate("abcdef", max=3), "abc")
  assert_eq(bench_progress_truncate("abcdefghij", max=6), "abc...")
  assert_true(
    bench_progress_render_line(1, 3, "running", "case").contains(
      "progress: 1/3 running case",
    ),
  )
  assert_eq(bench_progress_render_line(0, 0, "idle", ""), "progress: 0/0 idle")
  assert_true(
    bench_progress_json(2, 4, "done", "sample").contains("\"completed\":2"),
  )
  let off = bench_progress_state(2, "off")
  bench_progress_update(off, "running", "ignored")
  bench_progress_finish(off)
  assert_eq(bench_progress_advance(off, "sample").completed, 1)
  let enabled = bench_progress_state(1, "json")
  bench_progress_update(enabled, "running", "sample")
  let finished = bench_progress_advance(enabled, "sample")
  bench_progress_finish(finished)
  let tty = { enabled: true, mode: "auto", total: 1, completed: 0 }
  bench_progress_update(tty, "running", "sample")
  let tty_done = bench_progress_advance(tty, "sample")
  bench_progress_finish(tty_done)
  bench_write_stderr("")
  with_env_var("NO_PROGRESS", "true", fn() raise {
    assert_true(progress_disabled_by_env("NO_PROGRESS"))
    assert_true(!bench_progress_enabled())
  })
  assert_true(!progress_disabled_by_env("MARKITDOWN_TEST_MISSING_PROGRESS_ENV"))

  let invalid_contract = release_binary_contract(
    @command.make_runner_context("debug", Some("moon")),
  )
  assert_true(invalid_contract is Err(_))
  let doctor : ScenarioSpec = {
    scenario_id: "doctor.binary_contract",
    scenario_kind: "doctor",
    tool_names: ["moonbit-cli"],
    exact_tiers: [],
    format_filters: [],
    comparison_classes: [],
    official_membership: "none",
    route_expectation: "not_applicable",
  }
  let doctor_run = "coverage-doctor-contract"
  defer bench_cleanup_temp_dir(run_root(doctor_run))
  let policy = load_policy().unwrap()
  assert_true(
    execute_run(
      doctor_run,
      [doctor],
      sample_run_options(repeat_count=1, warmup_count=0),
      execution_test_contract(),
      policy,
    )
    is Ok(_),
  )

  let path = ".tmp/tests/bench-runner/output-hash.txt"
  ensure_parent_dir(path) catch {
    err => fail(err.to_string())
  }
  bench_write_utf8_text(path, "deterministic") catch {
    err => fail(err.to_string())
  }
  assert_true(
    file_sha256_or_none(path) ==
    Some("0badac3c6df445ad3aea62da1350683923aba37c685978afed96a515d12921a3"),
  )
  assert_true(file_sha256_or_none(path + ".missing") is None)
}

///|
test "benchmark run option parser covers every product flag and invalid boundary" {
  let opts = parse_run_options([
    "--preset", "official-internal", "--scenario", "diagnostic.pdf", "--tiers", "regular,release",
    "--bench-id", "a,b", "--format", "pdf,html", "--limit", "0", "--repeat", "2",
    "--warmup", "0", "--timeout-ms", "1234", "--markitdown-path", "/tmp/markitdown",
    "--baseline", "base", "--progress", "json", "--keep-outputs", "none", "--resume",
    "prior", "--max-disk-mb", "1",
  ])
  assert_true(opts.preset == Some("official-internal"))
  assert_true(opts.scenario_id == Some("diagnostic.pdf"))
  assert_true(opts.exact_tiers == ["regular", "release"])
  assert_true(opts.bench_ids == ["a", "b"])
  assert_true(opts.format_filters == ["pdf", "html"])
  assert_true(opts.limit == Some(0))
  assert_eq(opts.repeat_count, 2)
  assert_eq(opts.warmup_count, 0)
  assert_eq(opts.timeout_ms, 1234)
  assert_eq(opts.progress_mode, "json")
  assert_eq(opts.keep_outputs, "none")
  assert_eq(opts.max_disk_mb, 1)
  let invalid = [
    ["--preset"],
    ["--scenario"],
    ["--tiers", ""],
    ["--bench-id", ""],
    ["--format", ""],
    ["--limit", "bad"],
    ["--repeat", "-1"],
    ["--warmup", "bad"],
    ["--timeout-ms", "-1"],
    ["--markitdown-path"],
    ["--baseline"],
    ["--resume"],
    ["--max-disk-mb", "0"],
    ["--unknown"],
  ]
  for args in invalid {
    let failed = try {
      ignore(parse_run_options(args))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
}

///|
test "benchmark paths measure files directories JSON and provenance" {
  let root = bench_test_tmp_root() + "/paths-contract"
  bench_recreate_clean_dir(root) catch {
    err => fail("create path contract root: " + err.to_string())
  }
  defer bench_cleanup_temp_dir(root)
  let nested = root + "/a/b/file.txt"
  ensure_parent_dir(nested) catch {
    err => fail("ensure path contract parent: " + err.to_string())
  }
  bench_write_utf8_text(nested, "hello") catch {
    err => fail("write path contract file: " + err.to_string())
  }
  assert_eq(dirname(nested), root + "/a/b")
  assert_eq(dirname("file.txt"), ".")
  assert_eq(file_size_or_zero(nested), 5L)
  assert_eq(file_size_or_zero(root + "/missing"), 0L)
  assert_true((directory_size_bytes(root) catch { _ => 0L }) >= 5L)
  let fallback = Json::object({ "fallback": true.to_json() })
  assert_true(
    read_json_or_default(root + "/missing.json", fallback) == fallback,
  )
  let json_path = root + "/value.json"
  bench_write_utf8_text(json_path, "{\"value\":1}") catch {
    err => fail("write JSON contract: " + err.to_string())
  }
  assert_true(
    read_json_or_default(json_path, fallback).stringify().contains("value"),
  )
  assert_eq(scenario_path_token("compare.official/one"), "compare_official_one")
  assert_true(
    output_path("run", "scenario", "tool", "bench", 0, 1).contains("bench.md"),
  )
  assert_true(
    output_path("run", "scenario", "tool", "bench", 1, 2).contains(
      "repeat-2.md",
    ),
  )
  assert_true(
    !route_provenance_complete(Json::object({ "missing": true.to_json() })),
  )
}

///|
test "benchmark report argument parsers cover run baseline and errors" {
  assert_eq(parse_report_run_id(["--run", "run-1"]), "run-1")
  assert_eq(parse_report_run_id(["--run", "run-2"]), "run-2")
  assert_true(
    parse_report_baseline(["--run", "run", "--baseline", "base"]) ==
    Some("base"),
  )
  assert_true(
    parse_report_baseline(["--baseline", "base-two"]) == Some("base-two"),
  )
  assert_true(parse_report_baseline(["--run", "run"]) is None)
  for args in [[], ["--run"], ["--run", ""], ["--other", "value"]] {
    let failed = try {
      ignore(parse_report_run_id(args))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
  assert_eq(format_optional_speedup(None), "n/a")
  assert_true(format_optional_speedup(Some(1.25)).contains("1.25"))
}

///|
test "benchmark aggregation covers repeated partial failed groups and report rendering" {
  let policy = load_policy().unwrap()
  let scenario = execution_test_scenario(["moonbit-engine"])
  let provenance = sample_route_provenance(
    route="product_default",
    fidelity="matched",
  )
  let ok = sample_row(
    scenario.scenario_id,
    scenario.scenario_kind,
    scenario.official_membership,
    "moonbit-engine",
    "partial-case",
    "markdown",
    provenance,
  )
  let second_ok = {
    ..ok,
    repeat_index: 1,
    wall_us: Some(200L),
    output_bytes: 900L,
  }
  let failed = {
    ..ok,
    repeat_index: 2,
    status: "failed",
    exit_code: 1,
    wall_us: None,
    output_bytes: 0L,
  }
  let all_failed = {
    ..failed,
    bench_id: "failed-case",
    input_sha256: "failed-sha",
  }
  let baseline_timeout = {
    ..failed,
    tool: "markitdown",
    bench_id: "timeout-case",
    input_sha256: "timeout-sha",
    status: "timeout",
    timed_out: true,
    exit_code: 137,
    wall_us: Some(60000000L),
  }
  let cases = aggregate_cases(
    "aggregate-contract",
    [ok, second_ok, failed, all_failed, baseline_timeout],
    [scenario],
    policy,
  )
  assert_eq(cases.length(), 3)
  assert_true(cases.any(item => item.comparable_status == "partial"))
  assert_true(cases.any(item => item.comparable_status == "non_ok"))
  assert_true(cases.any(item => item.comparable_status == "censored_timeout"))
  let summary = summarize_run(
    "aggregate-contract",
    [scenario],
    [ok, second_ok, failed, all_failed, baseline_timeout],
    cases,
    execution_test_contract(),
    Some("contract"),
    None,
    policy,
  )
  let markdown = render_markdown_report(summary)
  assert_true(markdown.contains("# Bench Report"))
  assert_true(markdown.contains("## Scenarios"))
  assert_true(markdown.contains("## Tools"))
  assert_true(markdown.contains("## Route Coverage"))
  assert_true(markdown.contains("## Truth Guard"))
  assert_true(markdown.contains("## By Format"))
}

///|
test "benchmark performance gate enforces per-row 2x and per-format 3x" {
  let provenance = sample_route_provenance()
  let moon = sample_case_for_trust("moonbit-cli", provenance)
  let external_fast = {
    ..sample_case_for_trust("markitdown", provenance, expected_route=None),
    median_wall_us: Some(150L),
  }
  let failed = performance_gate_summary([moon, external_fast])
  match failed {
    Object(fields) => {
      let performance = fields.get("status").unwrap()
      assert_true(performance == "fail".to_json())
      assert_true(fields.get("row_violation_count").unwrap() == (1).to_json())
      assert_true(
        fields.get("format_violation_count").unwrap() == (1).to_json(),
      )
    }
    _ => fail("performance gate must be an object")
  }
  let external_slow = { ..external_fast, median_wall_us: Some(400L) }
  let passed = performance_gate_summary([moon, external_slow])
  match passed {
    Object(fields) => {
      assert_true(fields.get("status").unwrap() == "pass".to_json())
      assert_true(fields.get("row_violation_count").unwrap() == (0).to_json())
      assert_true(
        fields.get("format_violation_count").unwrap() == (0).to_json(),
      )
    }
    _ => fail("performance gate must be an object")
  }
}

///|
test "benchmark performance gate is not applicable without an external comparison" {
  match performance_gate_summary([]) {
    Object(fields) => {
      assert_true(fields.get("status").unwrap() == "not_applicable".to_json())
      assert_true(fields.get("evaluated_rows").unwrap() == (0).to_json())
      assert_true(fields.get("row_violation_count").unwrap() == (0).to_json())
      assert_true(
        fields.get("format_violation_count").unwrap() == (0).to_json(),
      )
    }
    _ => fail("performance gate must be an object")
  }
}

///|
test "benchmark run id allocation creates complete directory layout" {
  let run_id = allocate_run_id(["contract", "paths"]).unwrap()
  defer bench_cleanup_temp_dir(run_root(run_id))
  assert_true(@fs.path_exists(run_root(run_id)))
  assert_true(@fs.path_exists(results_root(run_id)))
  assert_true(@fs.path_exists(reports_root(run_id)))
  assert_true(@fs.path_exists(outputs_root(run_id)))
  assert_true(samples_jsonl_path(run_id).has_suffix("samples.jsonl"))
  assert_true(cases_jsonl_path(run_id).has_suffix("cases.jsonl"))
  assert_true(summary_json_path(run_id).has_suffix("summary.json"))
  assert_true(report_markdown_path(run_id).has_suffix("report.md"))
  assert_true(make_run_id(["contract"]).has_prefix("run-"))
  assert_eq(run_id_fingerprint(["a"]).length(), 10)
  assert_true(!route_provenance_complete(Json::string("not-an-object")))
}

///|
test "benchmark run reservation creates a missing parent tree" {
  let root = bench_test_tmp_root() + "/run-reservation"
  let reserved = root + "/nested/runs/run-clean"
  bench_cleanup_temp_dir(root)
  defer bench_cleanup_temp_dir(root)
  assert_true(try_reserve_dir(reserved) is Ok(_))
  assert_true(@fs.path_exists(reserved))
}

///|
test "benchmark policy direct scenario selection and report JSON helpers stay stable" {
  let policy = load_policy().unwrap()
  let direct = resolve_scenarios(
    {
      ..sample_run_options(),
      preset: None,
      scenario_id: Some("diagnostic.markdown"),
    },
    policy,
  )
  assert_eq(direct.length(), 1)
  assert_eq(direct[0].scenario_id, "diagnostic.markdown")
  let provenance = sample_route_provenance(
    route="product_default",
    fidelity="matched",
  )
  assert_true(route_provenance_complete(provenance))
  let sample = sample_row(
    "diagnostic.markdown", "diagnostic", "none", "moonbit-engine", "row", "markdown",
    provenance,
  )
  let scenarios = scenario_specs_for_run([sample, sample], policy)
  assert_eq(scenarios.length(), 1)
  let map : Map[String, Json] = {
    "name": "value".to_json(),
    "enabled": true.to_json(),
    "disabled": false.to_json(),
    "count": (7).to_json(),
    "object": Json::object({ "inner": "ok".to_json() }),
    "array": Json::array(["a".to_json(), "b".to_json()]),
  }
  assert_eq(json_string_required_from_json(map, "name", "contract"), "value")
  assert_true(json_bool_required_from_json(map, "enabled", "contract"))
  assert_true(!json_bool_required_from_json(map, "disabled", "contract"))
  assert_true(
    json_object_required(map, "object").get("inner") == Some("ok".to_json()),
  )
  assert_eq(json_array_required(map, "array").length(), 2)
  assert_eq(
    json_object_value_required(Json::object(map), "contract").length(),
    6,
  )
  assert_true(json_string_array(map, "array") == ["a", "b"])
  assert_true(json_string_array_value(map["array"]) == ["a", "b"])
  assert_eq(json_string_required_in(map, "name", "contract"), "value")
  assert_eq(json_int_required_in(map, "count", "contract"), 7)
  assert_true(
    json_optional_string_field(Json::object(map), "name") == Some("value"),
  )
  assert_true(json_optional_string_field(Json::string("x"), "name") is None)
  let root = bench_test_tmp_root() + "/jsonl-contract"
  bench_recreate_clean_dir(root) catch {
    err => fail("create JSONL contract root: " + err.to_string())
  }
  defer bench_cleanup_temp_dir(root)
  let path = root + "/rows.jsonl"
  write_jsonl(path, [
    Json::object({ "id": (1).to_json() }),
    Json::object({ "id": (2).to_json() }),
  ]) catch {
    err => fail("write JSONL contract: " + err.to_string())
  }
  assert_eq(
    bench_read_utf8_text(path)
    .split("\n")
    .to_array()
    .filter(line => line != "")
    .length(),
    2,
  )
}

///|
test "benchmark tool registry and native measurement encoders cover all entries" {
  let row = execution_test_row(
    "samples/fixtures/contracts/markdown/markdown_basic_heading_paragraph.md", "registry",
  )
  for name in ["moonbit-cli", "moonbit-engine", "markitdown"] {
    let tool = @tools.find_tool(
      name,
      config=@tools.make_tool_registry_config(
        if name == "markitdown" {
          Some("/definitely/missing/markitdown")
        } else {
          None
        },
      ),
    ).unwrap()
    assert_eq(tool.name, name)
    let command = tool.build_command(row, ".tmp/output.md", 123)
    assert_true(command.program != "" || name == "moonbit-engine")
    assert_eq(command.timeout_ms, 123)
  }
  assert_true(@tools.find_tool("unknown") is None)
  assert_true(@tools.default_tool_registry_config().markitdown_path is None)
  let argv = @measure.encode_c_string_blob(["/bin/sh", "-c", "exit 0"])
  let env = @measure.encode_c_string_blob(["A=B"])
  assert_true(argv.length() > 0)
  assert_true(env.length() > 0)
  assert_true(@measure.encode_c_path("/tmp/path").length() > 0)
  let started = @measure.monotonic_start()
  assert_true(@measure.monotonic_elapsed_us(started) >= 0.0)
}

///|
test "benchmark timeout reaps the measured process group" {
  let root = bench_test_tmp_root() + "/measure-process-group"
  bench_recreate_clean_dir(root) catch {
    err => fail("create process-group test root: " + err.to_string())
  }
  defer bench_cleanup_temp_dir(root)
  let marker = root + "/orphan-marker"
  let argv = [
    "/bin/sh",
    "-c",
    "(sleep 0.2; printf orphan > " + marker + ") & wait",
  ]
  let argv_blob = @measure.encode_c_string_blob(argv)
  let env_blob = @measure.encode_c_string_blob([])
  let measured = @measure.native_measure_command(
    @measure.make_native_measure_spec(
      argv_blob,
      argv_blob.length(),
      argv.length(),
      env_blob,
      env_blob.length(),
      0,
      root + "/stdout.log",
      root + "/stderr.log",
      None,
      50L,
    ),
  )
  assert_true(measured.data.timed_out)
  let wait_argv = ["/bin/sleep", "0.4"]
  let wait_blob = @measure.encode_c_string_blob(wait_argv)
  let waited = @measure.native_measure_command(
    @measure.make_native_measure_spec(
      wait_blob,
      wait_blob.length(),
      wait_argv.length(),
      env_blob,
      env_blob.length(),
      0,
      "/dev/null",
      "/dev/null",
      None,
      2_000L,
    ),
  )
  assert_eq(waited.data.exit_code, 0)
  assert_true(!@fs.path_exists(marker))
}
