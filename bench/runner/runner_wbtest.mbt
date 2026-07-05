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
  assert_true(
    options.explicit_format ==
    Some(@input.DetectedFormat::Image(@input.ImageFormat::Png)),
  )
  assert_true(options.ocr_options.intent == @parser.OcrIntent::Explicit)
}

///|
test "bench engine options fall back to detected image format for logical ocr rows" {
  let row = @manifest.make_bench_row(
    "ocr_large_commons_typewriter_photo_v1",
    "ocr",
    "regular",
    "ocr/large/ocr_large_commons_typewriter_photo_v1.jpg",
    "copied_from_external_quality",
    "local",
    1024,
    "sha",
    "regular",
    ["external_bench"],
    ["ocr"],
    "reviewed",
    "",
    "samples/fixtures/contracts/ocr/ocr_large_commons_typewriter_photo_v1.jpg",
  )
  let options = bench_convert_options_for_row(row)
  assert_true(
    options.explicit_format ==
    Some(@input.DetectedFormat::Image(@input.ImageFormat::Jpg)),
  )
  assert_true(options.ocr_options.intent == @parser.OcrIntent::Explicit)
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
    route_coverage_summary: Json::object({}),
    truth_summary: Json::object({}),
    diff_summary: None,
    scenarios: [],
    tools: [],
    by_format: [],
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
