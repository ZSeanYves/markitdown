///|
pub struct ToolBenchAggregate {
  bench_id : String
  format : String
  size_class : String
  enabled_tier : String
  tool : String
  tool_version : String?
  measurement_mode : String?
  output_write_mode : String?
  rel_path : String
  input_bytes : Int
  run_count : Int
  repeat_count : Int
  success_count : Int
  failed_count : Int
  timeout_count : Int
  unavailable_count : Int
  measurement_error_count : Int
  status : String
  median_wall_ms : Int64?
  min_wall_ms : Int64?
  max_wall_ms : Int64?
  median_wall_us : Int64?
  min_wall_us : Int64?
  max_wall_us : Int64?
  wall_precision : String
  median_peak_rss_kb : Int64?
  peak_rss_max_kb : Int64?
  median_output_bytes : Int64?
  max_output_bytes : Int64?
  total_output_bytes : Int64
  error : String?
} derive(ToJson, FromJson, Eq)

///|
pub struct ToolSummary {
  tool : String
  measurement_mode : String?
  output_write_mode : String?
  total_files : Int
  total_runs : Int
  repeat_count : Int?
  success_count : Int
  failure_count : Int
  timeout_count : Int
  unavailable_count : Int
  measurement_error_count : Int
  median_wall_ms : Int64?
  min_wall_ms : Int64?
  max_wall_ms : Int64?
  median_wall_us : Int64?
  min_wall_us : Int64?
  max_wall_us : Int64?
  wall_precision : String
  total_output_bytes : Int64
  median_peak_rss_kb : Int64?
  peak_rss_max_kb : Int64?
  rows : Array[ToolBenchAggregate]
  slowest : Array[ToolBenchAggregate]
  highest_rss : Array[ToolBenchAggregate]
  failures : Array[ToolBenchAggregate]
} derive(ToJson, FromJson, Eq)

///|
pub struct FormatComparison {
  format : String
  rows : Int
  compared_rows : Int
  engine_compared_rows : Int
  official_gate_rows : Int
  official_gate_comparable_rows : Int
  fixed_overhead_rows : Int
  moonbit_success_rows : Int
  moonbit_engine_success_rows : Int
  markitdown_success_rows : Int
  moonbit_median_wall_ms : Int64?
  moonbit_engine_median_wall_ms : Int64?
  markitdown_median_wall_ms : Int64?
  moonbit_median_wall_us : Int64?
  moonbit_engine_median_wall_us : Int64?
  markitdown_median_wall_us : Int64?
  median_speedup : Double?
  engine_median_speedup : Double?
  cli_geomean_speedup : Double?
  engine_geomean_speedup : Double?
  median_fixed_overhead_ms : Int64?
  median_fixed_overhead_us : Int64?
  median_fixed_overhead_share : Double?
  timing_precision : String
  status : String
} derive(ToJson, FromJson, Eq)

///|
pub struct BenchComparison {
  bench_id : String
  format : String
  size_class : String
  enabled_tier : String
  input_bytes : Int
  moonbit_run_count : Int
  moonbit_engine_run_count : Int
  markitdown_run_count : Int
  moonbit_success_count : Int
  moonbit_engine_success_count : Int
  markitdown_success_count : Int
  moonbit_status : String
  moonbit_engine_status : String
  markitdown_status : String
  moonbit_median_wall_ms : Int64?
  moonbit_engine_median_wall_ms : Int64?
  markitdown_median_wall_ms : Int64?
  moonbit_median_wall_us : Int64?
  moonbit_engine_median_wall_us : Int64?
  markitdown_median_wall_us : Int64?
  moonbit_median_peak_rss_kb : Int64?
  moonbit_engine_median_peak_rss_kb : Int64?
  markitdown_median_peak_rss_kb : Int64?
  moonbit_output_bytes : Int64?
  moonbit_engine_output_bytes : Int64?
  markitdown_output_bytes : Int64?
  speedup : Double?
  engine_speedup : Double?
  fixed_overhead_ms : Int64?
  fixed_overhead_us : Int64?
  fixed_overhead_share : Double?
  timing_precision : String
} derive(ToJson, FromJson, Eq)

///|
pub struct SummaryEnvironment {
  git_commit : String
  generated_at_epoch_ms : UInt64
  moonbit_version : String
  markitdown_info : String
  runner_mode : String
  canonical_performance : Bool
  runner_path : String?
  measurement_policy : String
  machine_os : String
  machine_arch : String
  hostname : String?
} derive(ToJson, FromJson, Eq)

///|
pub struct SummaryCorpus {
  tier : String
  exact_tiers : Array[String]
  tier_filter_mode : String
  bench_ids : Array[String]
  selected_rows : Int
  formats : Array[String]
  skipped_by_reason : Map[String, Int]
} derive(ToJson, FromJson, Eq)

///|
pub struct OfficialGateSummary {
  row_count : Int
  comparable_count : Int
  status : String
  excluded_rows_by_reason : Map[String, Int]
} derive(ToJson, FromJson, Eq)

///|
pub struct SummaryComparison {
  comparable_count : Int
  engine_comparable_count : Int
  cli_geomean_speedup_overall : Double?
  engine_geomean_speedup_overall : Double?
  fixed_overhead_count : Int
  moonbit_total_wall_ms : Int64?
  moonbit_engine_total_wall_ms : Int64?
  markitdown_total_wall_ms : Int64?
  moonbit_total_wall_us : Int64?
  moonbit_engine_total_wall_us : Int64?
  markitdown_total_wall_us : Int64?
  ratio_markitdown_over_moonbit : Double?
  ratio_markitdown_over_engine : Double?
  ratio_cli_over_engine : Double?
  median_speedup_overall : Double?
  engine_median_speedup_overall : Double?
  best_speedup : Double?
  best_engine_speedup : Double?
  worst_speedup : Double?
  worst_engine_speedup : Double?
  median_fixed_overhead_ms : Int64?
  median_fixed_overhead_us : Int64?
  median_fixed_overhead_share : Double?
  timing_precision : String
  official_gate : OfficialGateSummary
  rows : Array[BenchComparison]
  by_format : Array[FormatComparison]
} derive(ToJson, FromJson, Eq)

///|
pub struct SummaryDocument {
  schema_version : Int
  run_id : String
  environment : SummaryEnvironment
  corpus : SummaryCorpus
  tools : Map[String, ToolSummary]
  comparison : SummaryComparison
  warnings : Array[String]
} derive(ToJson, FromJson, Eq)

///|
pub struct SummaryRunMetadata {
  runner_mode : String
  canonical_performance : Bool
  runner_path : String?
} derive(ToJson, FromJson, Eq)

///|
priv struct WallStats {
  median_ms : Int64?
  min_ms : Int64?
  max_ms : Int64?
  median_us : Int64?
  min_us : Int64?
  max_us : Int64?
  precision : String
}

///|
priv struct LegacySelectorStats {
  requested_tier : String?
  selected_rows : Int
  formats : Array[String]
  skipped_by_reason : Map[String, Int]
} derive(FromJson)

///|
pub fn generate_report_from_request(request : ReportRequest) -> Json {
  let rows : Array[CliResult] = []
  for path in request.input_paths {
    rows.append(load_jsonl_results(path))
  }
  if rows.length() == 0 {
    abort("no result rows loaded")
  }
  let summary = summarize_rows(rows, request.selector_stats_path)
  let summary_json = summary.to_json().stringify(indent=2)
  let summary_path = @command.summary_json_path(summary.run_id)
  @fs.write_string_to_file(summary_path, summary_json + "\n", encoding="utf8") catch {
    err => abort("failed to write summary json: " + err.to_string())
  }
  let report_path = @command.report_markdown_path(summary.run_id)
  @fs.write_string_to_file(
    report_path,
    render_markdown_report(summary) + "\n",
    encoding="utf8",
  ) catch {
    err => abort("failed to write markdown report: " + err.to_string())
  }
  Json::object({
    "run_id": summary.run_id.to_json(),
    "summary_json": summary_path.to_json(),
    "report_md": report_path.to_json(),
    "selected_rows": summary.corpus.selected_rows.to_json(),
    "requested_formats": summary.corpus.formats.to_json(),
    "skipped_by_reason": summary.corpus.skipped_by_reason.to_json(),
    "cli_geomean_speedup_overall": summary.comparison.cli_geomean_speedup_overall.to_json(),
    "engine_geomean_speedup_overall": summary.comparison.engine_geomean_speedup_overall.to_json(),
    "official_gate_row_count": summary.comparison.official_gate.row_count.to_json(),
    "official_gate_comparable_count": summary.comparison.official_gate.comparable_count.to_json(),
    "official_gate_status": summary.comparison.official_gate.status.to_json(),
    "excluded_rows_by_reason": summary.comparison.official_gate.excluded_rows_by_reason.to_json(),
  })
}

///|
fn summarize_rows(
  rows : Array[CliResult],
  selector_stats_path : String?,
) -> SummaryDocument {
  let grouped : Map[String, Array[CliResult]] = {}
  for row in rows {
    grouped[row.tool] = match grouped.get(row.tool) {
      Some(existing) => {
        let next = existing.copy()
        next.push(row)
        next
      }
      None => [row]
    }
  }
  let tools : Map[String, ToolSummary] = {}
  let tool_rows : Map[String, Array[ToolBenchAggregate]] = {}
  for entry in grouped {
    let summary = summarize_tool_rows(entry.1)
    tools[entry.0] = summary
    tool_rows[entry.0] = summary.rows
  }
  let selector_stats = load_selector_stats(selector_stats_path)
  let requested_tier = summary_corpus_tier(rows, selector_stats)
  let comparison = summarize_comparison(tool_rows, selector_stats)
  {
    schema_version: 5,
    run_id: rows[0].run_id,
    environment: {
      git_commit: rows[0].repo_commit,
      generated_at_epoch_ms: @env.now(),
      moonbit_version: "moon " +
      @env.get_env_var("MOON_VERSION").unwrap_or("unknown"),
      markitdown_info: detect_markitdown_info(rows),
      runner_mode: summary_runner_mode(rows),
      canonical_performance: summary_canonical_performance(rows),
      runner_path: summary_runner_path(rows),
      measurement_policy: summarize_measurement_policy(rows),
      machine_os: @env.get_env_var("MARKITDOWN_BENCH_MACHINE_OS").unwrap_or(
        "unknown",
      ),
      machine_arch: @env.get_env_var("MARKITDOWN_BENCH_MACHINE_ARCH").unwrap_or(
        "unknown",
      ),
      hostname: @env.get_env_var("MARKITDOWN_BENCH_HOSTNAME"),
    },
    corpus: {
      tier: requested_tier,
      exact_tiers: selector_stats.requested_tiers,
      tier_filter_mode: selector_stats.tier_filter_mode,
      bench_ids: selector_stats.requested_bench_ids,
      selected_rows: selector_stats.selected_rows,
      formats: selector_stats.formats,
      skipped_by_reason: selector_stats.skipped_by_reason,
    },
    tools,
    comparison,
    warnings: summary_warnings(rows, comparison),
  }
}

///|
fn summary_corpus_tier(
  rows : Array[CliResult],
  selector_stats : @manifest.SelectorStats,
) -> String {
  if selector_stats.requested_tiers.length() > 0 {
    return selector_stats.requested_tiers.join(",")
  }
  match selector_stats.requested_tier {
    Some(tier) if tier.trim() != "" => tier
    _ => rows[0].enabled_tier
  }
}

///|
fn summarize_measurement_policy(rows : Array[CliResult]) -> String {
  let first = rows[0].measurement_policy.unwrap_or("unknown")
  for row in rows {
    if row.measurement_policy.unwrap_or("unknown") != first {
      return "mixed"
    }
  }
  first
}

///|
fn summarize_tool_rows(rows : Array[CliResult]) -> ToolSummary {
  let aggregates = summarize_tool_bench_rows(rows)
  let success_rows = rows.filter(row => row.status == "ok")
  let wall_stats = collect_wall_stats(success_rows)
  let rss_values = success_rows
    .filter(row => row.peak_rss_kb is Some(_))
    .map(row => row.peak_rss_kb.unwrap())
  rss_values.sort()
  let slowest = aggregates.copy()
  slowest.sort_by(compare_slowest_tool_row)
  let highest_rss = aggregates
    .filter(row => row.median_peak_rss_kb is Some(_))
    .copy()
  highest_rss.sort_by(compare_highest_rss_tool_row)
  let failures = aggregates.filter(row => row.status != "ok")
  failures.sort_by(compare_failure_tool_row)
  {
    tool: rows[0].tool,
    measurement_mode: rows[0].measurement_mode,
    output_write_mode: rows[0].output_write_mode,
    total_files: aggregates.length(),
    total_runs: rows.length(),
    repeat_count: repeat_count_or_none(rows),
    success_count: success_rows.length(),
    failure_count: rows.length() - success_rows.length(),
    timeout_count: rows.filter(row => row.status == "timeout").length(),
    unavailable_count: rows.filter(row => row.status == "unavailable").length(),
    measurement_error_count: rows
    .filter(row => row.status == "measurement_error")
    .length(),
    median_wall_ms: wall_stats.median_ms,
    min_wall_ms: wall_stats.min_ms,
    max_wall_ms: wall_stats.max_ms,
    median_wall_us: wall_stats.median_us,
    min_wall_us: wall_stats.min_us,
    max_wall_us: wall_stats.max_us,
    wall_precision: wall_stats.precision,
    total_output_bytes: rows.fold(init=0L, fn(acc, row) {
      acc + row.output_bytes
    }),
    median_peak_rss_kb: median_sorted_int64(rss_values),
    peak_rss_max_kb: rss_values.last(),
    rows: aggregates,
    slowest: take_first_tool_rows(slowest, 10),
    highest_rss: take_first_tool_rows(highest_rss, 10),
    failures: take_first_tool_rows(failures, 10),
  }
}

///|
fn summarize_tool_bench_rows(
  rows : Array[CliResult],
) -> Array[ToolBenchAggregate] {
  let grouped : Map[String, Array[CliResult]] = {}
  for row in rows {
    grouped[row.bench_id] = match grouped.get(row.bench_id) {
      Some(existing) => {
        let next = existing.copy()
        next.push(row)
        next
      }
      None => [row]
    }
  }
  let out : Array[ToolBenchAggregate] = []
  for entry in grouped {
    out.push(summarize_tool_bench_row(entry.1))
  }
  out.sort_by(compare_tool_bench_row)
  out
}

///|
fn summarize_tool_bench_row(rows : Array[CliResult]) -> ToolBenchAggregate {
  let ok_rows = rows.filter(row => row.status == "ok")
  let wall_stats = collect_wall_stats(ok_rows)
  let rss_values = ok_rows
    .filter(row => row.peak_rss_kb is Some(_))
    .map(row => row.peak_rss_kb.unwrap())
  rss_values.sort()
  let output_values = ok_rows.map(row => row.output_bytes)
  output_values.sort()
  {
    bench_id: rows[0].bench_id,
    format: rows[0].format,
    size_class: rows[0].size_class,
    enabled_tier: rows[0].enabled_tier,
    tool: rows[0].tool,
    tool_version: rows[0].tool_version,
    measurement_mode: rows[0].measurement_mode,
    output_write_mode: rows[0].output_write_mode,
    rel_path: rows[0].rel_path,
    input_bytes: rows[0].input_bytes,
    run_count: rows.length(),
    repeat_count: rows[0].repeat_count,
    success_count: ok_rows.length(),
    failed_count: rows.filter(row => row.status == "failed").length(),
    timeout_count: rows.filter(row => row.status == "timeout").length(),
    unavailable_count: rows.filter(row => row.status == "unavailable").length(),
    measurement_error_count: rows
    .filter(row => row.status == "measurement_error")
    .length(),
    status: aggregate_status(rows),
    median_wall_ms: wall_stats.median_ms,
    min_wall_ms: wall_stats.min_ms,
    max_wall_ms: wall_stats.max_ms,
    median_wall_us: wall_stats.median_us,
    min_wall_us: wall_stats.min_us,
    max_wall_us: wall_stats.max_us,
    wall_precision: wall_stats.precision,
    median_peak_rss_kb: median_sorted_int64(rss_values),
    peak_rss_max_kb: rss_values.last(),
    median_output_bytes: median_sorted_int64(output_values),
    max_output_bytes: output_values.last(),
    total_output_bytes: ok_rows.fold(init=0L, fn(acc, row) {
      acc + row.output_bytes
    }),
    error: aggregate_error(rows),
  }
}

///|
fn summarize_comparison(
  tool_rows : Map[String, Array[ToolBenchAggregate]],
  selector_stats : @manifest.SelectorStats,
) -> SummaryComparison {
  let moonbit_rows = tool_rows.get("moonbit-cli").unwrap_or([])
  let engine_rows = tool_rows.get("moonbit-engine").unwrap_or([])
  let markitdown_rows = tool_rows.get("markitdown").unwrap_or([])
  let moonbit_by_bench = to_tool_bench_map(moonbit_rows)
  let engine_by_bench = to_tool_bench_map(engine_rows)
  let markitdown_by_bench = to_tool_bench_map(markitdown_rows)
  let all_bench_ids = collect_sorted_bench_ids(
    moonbit_by_bench, engine_by_bench, markitdown_by_bench,
  )
  let rows : Array[BenchComparison] = []
  for bench_id in all_bench_ids {
    rows.push(
      summarize_bench_comparison(
        bench_id,
        moonbit_by_bench.get(bench_id),
        engine_by_bench.get(bench_id),
        markitdown_by_bench.get(bench_id),
      ),
    )
  }
  let by_format = summarize_format_comparisons(rows)
  let cli_comparable = rows.filter(row => row.speedup is Some(_))
  let engine_comparable = rows.filter(row => row.engine_speedup is Some(_))
  let fixed_rows = rows.filter(row => row.fixed_overhead_us is Some(_))
  let moon_total = cli_comparable
    .filter(row => row.moonbit_median_wall_ms is Some(_))
    .fold(init=0L, fn(acc, row) { acc + row.moonbit_median_wall_ms.unwrap() })
  let engine_total = engine_comparable
    .filter(row => row.moonbit_engine_median_wall_ms is Some(_))
    .fold(init=0L, fn(acc, row) {
      acc + row.moonbit_engine_median_wall_ms.unwrap()
    })
  let mark_total = cli_comparable
    .filter(row => row.markitdown_median_wall_ms is Some(_))
    .fold(init=0L, fn(acc, row) { acc + row.markitdown_median_wall_ms.unwrap() })
  let moon_total_us = cli_comparable
    .filter(row => row.moonbit_median_wall_us is Some(_))
    .fold(init=0L, fn(acc, row) { acc + row.moonbit_median_wall_us.unwrap() })
  let engine_total_us = engine_comparable
    .filter(row => row.moonbit_engine_median_wall_us is Some(_))
    .fold(init=0L, fn(acc, row) {
      acc + row.moonbit_engine_median_wall_us.unwrap()
    })
  let mark_total_us = cli_comparable
    .filter(row => row.markitdown_median_wall_us is Some(_))
    .fold(init=0L, fn(acc, row) { acc + row.markitdown_median_wall_us.unwrap() })
  let cli_speedup_values = cli_comparable.map(row => row.speedup.unwrap())
  cli_speedup_values.sort_by(compare_double_asc)
  let engine_speedup_values = engine_comparable.map(row => {
    row.engine_speedup.unwrap()
  })
  engine_speedup_values.sort_by(compare_double_asc)
  let fixed_overhead_us_values = fixed_rows.map(row => {
    row.fixed_overhead_us.unwrap()
  })
  fixed_overhead_us_values.sort()
  let fixed_share_values = fixed_rows
    .filter(row => row.fixed_overhead_share is Some(_))
    .map(row => row.fixed_overhead_share.unwrap())
  fixed_share_values.sort_by(compare_double_asc)
  let precision = comparison_precision(rows)
  let official_gate = summarize_official_gate(rows, selector_stats)
  {
    comparable_count: cli_comparable.length(),
    engine_comparable_count: engine_comparable.length(),
    cli_geomean_speedup_overall: geomean_speedup(cli_speedup_values),
    engine_geomean_speedup_overall: geomean_speedup(engine_speedup_values),
    fixed_overhead_count: fixed_rows.length(),
    moonbit_total_wall_ms: if cli_comparable.length() > 0 {
      Some(moon_total)
    } else {
      None
    },
    moonbit_engine_total_wall_ms: if engine_comparable.length() > 0 {
      Some(engine_total)
    } else {
      None
    },
    markitdown_total_wall_ms: if cli_comparable.length() > 0 {
      Some(mark_total)
    } else {
      None
    },
    moonbit_total_wall_us: if cli_comparable.length() > 0 {
      Some(moon_total_us)
    } else {
      None
    },
    moonbit_engine_total_wall_us: if engine_comparable.length() > 0 {
      Some(engine_total_us)
    } else {
      None
    },
    markitdown_total_wall_us: if cli_comparable.length() > 0 {
      Some(mark_total_us)
    } else {
      None
    },
    ratio_markitdown_over_moonbit: if cli_comparable.length() > 0 &&
      moon_total_us > 0L {
      Some(mark_total_us.to_double() / moon_total_us.to_double())
    } else {
      None
    },
    ratio_markitdown_over_engine: if engine_comparable.length() > 0 &&
      engine_total_us > 0L {
      Some(mark_total_us.to_double() / engine_total_us.to_double())
    } else {
      None
    },
    ratio_cli_over_engine: if fixed_rows.length() > 0 && engine_total_us > 0L {
      Some(moon_total_us.to_double() / engine_total_us.to_double())
    } else {
      None
    },
    median_speedup_overall: median_sorted_double(cli_speedup_values),
    engine_median_speedup_overall: median_sorted_double(engine_speedup_values),
    best_speedup: cli_speedup_values.last(),
    best_engine_speedup: engine_speedup_values.last(),
    worst_speedup: first_sorted_double(cli_speedup_values),
    worst_engine_speedup: first_sorted_double(engine_speedup_values),
    median_fixed_overhead_ms: median_sorted_int64(
      fixed_overhead_us_values.map(rounded_wall_us_to_ms),
    ),
    median_fixed_overhead_us: median_sorted_int64(fixed_overhead_us_values),
    median_fixed_overhead_share: median_sorted_double(fixed_share_values),
    timing_precision: precision,
    official_gate,
    rows,
    by_format,
  }
}

///|
fn summarize_bench_comparison(
  bench_id : String,
  moonbit : ToolBenchAggregate?,
  engine : ToolBenchAggregate?,
  markitdown : ToolBenchAggregate?,
) -> BenchComparison {
  let metadata = pick_tool_bench_metadata(moonbit, engine, markitdown, bench_id)
  let moonbit_status = moonbit.map(row => row.status).unwrap_or("missing")
  let engine_status = engine.map(row => row.status).unwrap_or("missing")
  let markitdown_status = markitdown.map(row => row.status).unwrap_or("missing")
  let moonbit_median = moonbit.map(row => row.median_wall_ms).unwrap_or(None)
  let moonbit_median_us = moonbit.map(row => row.median_wall_us).unwrap_or(None)
  let engine_median = engine.map(row => row.median_wall_ms).unwrap_or(None)
  let engine_median_us = engine.map(row => row.median_wall_us).unwrap_or(None)
  let markitdown_median = markitdown
    .map(row => row.median_wall_ms)
    .unwrap_or(None)
  let markitdown_median_us = markitdown
    .map(row => row.median_wall_us)
    .unwrap_or(None)
  let timing_precision = bench_comparison_precision(moonbit, engine, markitdown)
  {
    bench_id,
    format: metadata.format,
    size_class: metadata.size_class,
    enabled_tier: metadata.enabled_tier,
    input_bytes: metadata.input_bytes,
    moonbit_run_count: moonbit.map(row => row.run_count).unwrap_or(0),
    moonbit_engine_run_count: engine.map(row => row.run_count).unwrap_or(0),
    markitdown_run_count: markitdown.map(row => row.run_count).unwrap_or(0),
    moonbit_success_count: moonbit.map(row => row.success_count).unwrap_or(0),
    moonbit_engine_success_count: engine
    .map(row => row.success_count)
    .unwrap_or(0),
    markitdown_success_count: markitdown
    .map(row => row.success_count)
    .unwrap_or(0),
    moonbit_status,
    moonbit_engine_status: engine_status,
    markitdown_status,
    moonbit_median_wall_ms: moonbit_median,
    moonbit_engine_median_wall_ms: engine_median,
    markitdown_median_wall_ms: markitdown_median,
    moonbit_median_wall_us: moonbit_median_us,
    moonbit_engine_median_wall_us: engine_median_us,
    markitdown_median_wall_us: markitdown_median_us,
    moonbit_median_peak_rss_kb: moonbit
    .map(row => row.median_peak_rss_kb)
    .unwrap_or(None),
    moonbit_engine_median_peak_rss_kb: engine
    .map(row => row.median_peak_rss_kb)
    .unwrap_or(None),
    markitdown_median_peak_rss_kb: markitdown
    .map(row => row.median_peak_rss_kb)
    .unwrap_or(None),
    moonbit_output_bytes: moonbit
    .map(row => row.median_output_bytes)
    .unwrap_or(None),
    moonbit_engine_output_bytes: engine
    .map(row => row.median_output_bytes)
    .unwrap_or(None),
    markitdown_output_bytes: markitdown
    .map(row => row.median_output_bytes)
    .unwrap_or(None),
    speedup: compute_speedup(moonbit, markitdown),
    engine_speedup: compute_speedup(engine, markitdown),
    fixed_overhead_ms: compute_fixed_overhead_ms(moonbit, engine),
    fixed_overhead_us: compute_fixed_overhead_us(moonbit, engine),
    fixed_overhead_share: compute_fixed_overhead_share(moonbit, engine),
    timing_precision,
  }
}

///|
fn summarize_format_comparisons(
  rows : Array[BenchComparison],
) -> Array[FormatComparison] {
  let grouped : Map[String, Array[BenchComparison]] = {}
  for row in rows {
    grouped[row.format] = match grouped.get(row.format) {
      Some(existing) => {
        let next = existing.copy()
        next.push(row)
        next
      }
      None => [row]
    }
  }
  let out : Array[FormatComparison] = []
  for entry in grouped {
    let format_rows = entry.1
    let comparable = format_rows.filter(row => row.speedup is Some(_))
    let engine_comparable = format_rows.filter(row => {
      row.engine_speedup is Some(_)
    })
    let fixed_rows = format_rows.filter(row => row.fixed_overhead_us is Some(_))
    let moonbit_values = format_rows
      .filter(row => row.moonbit_median_wall_ms is Some(_))
      .map(row => row.moonbit_median_wall_ms.unwrap())
    moonbit_values.sort()
    let engine_values = format_rows
      .filter(row => row.moonbit_engine_median_wall_ms is Some(_))
      .map(row => row.moonbit_engine_median_wall_ms.unwrap())
    engine_values.sort()
    let markitdown_values = format_rows
      .filter(row => row.markitdown_median_wall_ms is Some(_))
      .map(row => row.markitdown_median_wall_ms.unwrap())
    markitdown_values.sort()
    let moonbit_values_us = format_rows
      .filter(row => row.moonbit_median_wall_us is Some(_))
      .map(row => row.moonbit_median_wall_us.unwrap())
    moonbit_values_us.sort()
    let engine_values_us = format_rows
      .filter(row => row.moonbit_engine_median_wall_us is Some(_))
      .map(row => row.moonbit_engine_median_wall_us.unwrap())
    engine_values_us.sort()
    let markitdown_values_us = format_rows
      .filter(row => row.markitdown_median_wall_us is Some(_))
      .map(row => row.markitdown_median_wall_us.unwrap())
    markitdown_values_us.sort()
    let speedups = comparable.map(row => row.speedup.unwrap())
    speedups.sort_by(compare_double_asc)
    let engine_speedups = engine_comparable.map(row => {
      row.engine_speedup.unwrap()
    })
    engine_speedups.sort_by(compare_double_asc)
    let fixed_overhead_us_values = fixed_rows.map(row => {
      row.fixed_overhead_us.unwrap()
    })
    fixed_overhead_us_values.sort()
    let fixed_share_values = fixed_rows
      .filter(row => row.fixed_overhead_share is Some(_))
      .map(row => row.fixed_overhead_share.unwrap())
    fixed_share_values.sort_by(compare_double_asc)
    let precision = format_comparison_precision(format_rows)
    let official_gate_rows = format_rows.filter(is_official_gate_row)
    let official_gate_comparable = official_gate_rows.filter(row => {
      row.speedup is Some(_)
    })
    out.push({
      format: entry.0,
      rows: format_rows.length(),
      compared_rows: comparable.length(),
      engine_compared_rows: engine_comparable.length(),
      official_gate_rows: official_gate_rows.length(),
      official_gate_comparable_rows: official_gate_comparable.length(),
      fixed_overhead_rows: fixed_rows.length(),
      moonbit_success_rows: format_rows
      .filter(row => row.moonbit_status == "ok")
      .length(),
      moonbit_engine_success_rows: format_rows
      .filter(row => row.moonbit_engine_status == "ok")
      .length(),
      markitdown_success_rows: format_rows
      .filter(row => row.markitdown_status == "ok")
      .length(),
      moonbit_median_wall_ms: median_sorted_int64(moonbit_values),
      moonbit_engine_median_wall_ms: median_sorted_int64(engine_values),
      markitdown_median_wall_ms: median_sorted_int64(markitdown_values),
      moonbit_median_wall_us: median_sorted_int64(moonbit_values_us),
      moonbit_engine_median_wall_us: median_sorted_int64(engine_values_us),
      markitdown_median_wall_us: median_sorted_int64(markitdown_values_us),
      median_speedup: median_sorted_double(speedups),
      engine_median_speedup: median_sorted_double(engine_speedups),
      cli_geomean_speedup: geomean_speedup(speedups),
      engine_geomean_speedup: geomean_speedup(engine_speedups),
      median_fixed_overhead_ms: median_sorted_int64(
        fixed_overhead_us_values.map(rounded_wall_us_to_ms),
      ),
      median_fixed_overhead_us: median_sorted_int64(fixed_overhead_us_values),
      median_fixed_overhead_share: median_sorted_double(fixed_share_values),
      timing_precision: precision,
      status: comparison_status(
        format_rows.length(),
        if comparable.length() > engine_comparable.length() {
          comparable.length()
        } else {
          engine_comparable.length()
        },
      ),
    })
  }
  out.sort_by(compare_format_comparison)
  out
}

///|
pub fn render_markdown_report(summary : SummaryDocument) -> String {
  let lines : Array[String] = ["# Benchmark Report", ""]
  lines.push("## Environment")
  lines.push("- git commit: `" + summary.environment.git_commit + "`")
  lines.push(
    "- generated at epoch ms: `" +
    summary.environment.generated_at_epoch_ms.to_string() +
    "`",
  )
  lines.push("- moon version: `" + summary.environment.moonbit_version + "`")
  lines.push("- markitdown: `" + summary.environment.markitdown_info + "`")
  lines.push("- runner mode: `" + summary.environment.runner_mode + "`")
  lines.push(
    "- canonical performance: `" +
    summary.environment.canonical_performance.to_string() +
    "`",
  )
  lines.push(
    "- runner path: `" +
    summary.environment.runner_path.unwrap_or("unknown") +
    "`",
  )
  lines.push(
    "- measurement policy: `" + summary.environment.measurement_policy + "`",
  )
  lines.push("- machine os: `" + summary.environment.machine_os + "`")
  lines.push("- machine arch: `" + summary.environment.machine_arch + "`")
  lines.push(
    "- hostname: `" + summary.environment.hostname.unwrap_or("unknown") + "`",
  )
  lines.push("")
  if summary.warnings.length() > 0 {
    lines.push("## Warnings")
    for warning in summary.warnings {
      lines.push("- " + warning)
    }
    lines.push("")
  }
  lines.push("## Corpus")
  lines.push("- tier: `" + summary.corpus.tier + "`")
  lines.push("- tier filter mode: `" + summary.corpus.tier_filter_mode + "`")
  lines.push("- exact tiers: `" + summary.corpus.exact_tiers.join(", ") + "`")
  lines.push("- bench ids: `" + summary.corpus.bench_ids.join(", ") + "`")
  lines.push(
    "- selected rows: `" + summary.corpus.selected_rows.to_string() + "`",
  )
  lines.push("- formats: `" + summary.corpus.formats.join(", ") + "`")
  lines.push(
    "- skipped rows by reason: `" +
    summary.corpus.skipped_by_reason.to_json().stringify() +
    "`",
  )
  lines.push("")
  lines.push("## Comparison Coverage")
  lines.push(
    "- compared bench rows: `" +
    summary.comparison.rows.length().to_string() +
    " / " +
    summary.corpus.selected_rows.to_string() +
    "`",
  )
  lines.push(
    "- CLI comparable rows: `" +
    summary.comparison.comparable_count.to_string() +
    "`",
  )
  lines.push(
    "- Engine comparable rows: `" +
    summary.comparison.engine_comparable_count.to_string() +
    "`",
  )
  lines.push(
    "- MoonBit CLI ok rows: `" +
    summary.comparison.rows
    .filter(row => row.moonbit_status == "ok")
    .length()
    .to_string() +
    "`",
  )
  lines.push(
    "- MoonBit engine ok rows: `" +
    summary.comparison.rows
    .filter(row => row.moonbit_engine_status == "ok")
    .length()
    .to_string() +
    "`",
  )
  lines.push(
    "- MarkItDown ok rows: `" +
    summary.comparison.rows
    .filter(row => row.markitdown_status == "ok")
    .length()
    .to_string() +
    "`",
  )
  lines.push(
    "- MarkItDown non-ok rows: `" +
    external_non_ok_rows(summary.comparison.rows).length().to_string() +
    "`",
  )
  lines.push(
    "- MoonBit-only success rows excluded by external baseline: `" +
    external_only_gap_rows(summary.comparison.rows).length().to_string() +
    "`",
  )
  lines.push(
    "- MoonBit non-ok rows: `" +
    moonbit_non_ok_rows(summary.comparison.rows).length().to_string() +
    "`",
  )
  lines.push(
    "- official gate rows: `" +
    summary.comparison.official_gate.row_count.to_string() +
    "`",
  )
  lines.push(
    "- official gate comparable rows: `" +
    summary.comparison.official_gate.comparable_count.to_string() +
    "`",
  )
  lines.push(
    "- official gate status: `" + summary.comparison.official_gate.status + "`",
  )
  lines.push(
    "- official gate excluded rows by reason: `" +
    summary.comparison.official_gate.excluded_rows_by_reason
    .to_json()
    .stringify() +
    "`",
  )
  lines.push("")
  lines.push("## Tool Summary")
  lines.push(
    "- timing precision: `" + summary.comparison.timing_precision + "`",
  )
  lines.push(
    markdown_table_row([
      "tool", "mode", "output", "files", "runs", "repeat", "ok", "non-ok", "timeout",
      "unavailable", "median wall", "precision", "median RSS kb",
    ]),
  )
  lines.push(markdown_table_separator(13))
  let tool_summaries = sorted_tool_summaries(summary.tools)
  for tool in tool_summaries {
    lines.push(
      markdown_table_row([
        tool.tool,
        tool.measurement_mode.unwrap_or("null"),
        tool.output_write_mode.unwrap_or("null"),
        tool.total_files.to_string(),
        tool.total_runs.to_string(),
        format_optional_int(tool.repeat_count),
        tool.success_count.to_string(),
        tool.failure_count.to_string(),
        tool.timeout_count.to_string(),
        tool.unavailable_count.to_string(),
        format_wall_pair(tool.median_wall_ms, tool.median_wall_us),
        tool.wall_precision,
        format_optional_int64(tool.median_peak_rss_kb),
      ]),
    )
  }
  lines.push("")
  lines.push("## Speedup Summary")
  lines.push(
    "- CLI rows compared: `" +
    summary.comparison.comparable_count.to_string() +
    "`",
  )
  lines.push(
    "- CLI median speedup overall: `" +
    format_optional_speedup(summary.comparison.median_speedup_overall) +
    "`",
  )
  lines.push(
    "- CLI geomean speedup overall: `" +
    format_optional_speedup(summary.comparison.cli_geomean_speedup_overall) +
    "`",
  )
  lines.push(
    "- CLI best speedup: `" +
    format_optional_speedup(summary.comparison.best_speedup) +
    "`",
  )
  lines.push(
    "- CLI worst speedup: `" +
    format_optional_speedup(summary.comparison.worst_speedup) +
    "`",
  )
  lines.push(
    "- Engine rows compared: `" +
    summary.comparison.engine_comparable_count.to_string() +
    "`",
  )
  lines.push(
    "- Engine median speedup overall: `" +
    format_optional_speedup(summary.comparison.engine_median_speedup_overall) +
    "`",
  )
  lines.push(
    "- Engine geomean speedup overall: `" +
    format_optional_speedup(summary.comparison.engine_geomean_speedup_overall) +
    "`",
  )
  lines.push(
    "- Engine best speedup: `" +
    format_optional_speedup(summary.comparison.best_engine_speedup) +
    "`",
  )
  lines.push(
    "- Engine worst speedup: `" +
    format_optional_speedup(summary.comparison.worst_engine_speedup) +
    "`",
  )
  lines.push(
    "- Fixed overhead rows: `" +
    summary.comparison.fixed_overhead_count.to_string() +
    "`",
  )
  lines.push(
    "- Median fixed overhead ms: `" +
    format_optional_int64(summary.comparison.median_fixed_overhead_ms) +
    "`",
  )
  lines.push(
    "- Median fixed overhead us: `" +
    format_optional_int64(summary.comparison.median_fixed_overhead_us) +
    "`",
  )
  lines.push(
    "- Median fixed overhead share: `" +
    format_optional_percent(summary.comparison.median_fixed_overhead_share) +
    "`",
  )
  lines.push(
    "- CLI summed comparable medians ms: `" +
    format_optional_int64(summary.comparison.moonbit_total_wall_ms) +
    "`",
  )
  lines.push(
    "- Engine summed comparable medians ms: `" +
    format_optional_int64(summary.comparison.moonbit_engine_total_wall_ms) +
    "`",
  )
  lines.push(
    "- MarkItDown summed comparable medians ms: `" +
    format_optional_int64(summary.comparison.markitdown_total_wall_ms) +
    "`",
  )
  lines.push(
    "- CLI summed comparable medians us: `" +
    format_optional_int64(summary.comparison.moonbit_total_wall_us) +
    "`",
  )
  lines.push(
    "- Engine summed comparable medians us: `" +
    format_optional_int64(summary.comparison.moonbit_engine_total_wall_us) +
    "`",
  )
  lines.push(
    "- MarkItDown summed comparable medians us: `" +
    format_optional_int64(summary.comparison.markitdown_total_wall_us) +
    "`",
  )
  lines.push(
    "- CLI overall ratio: `" +
    format_optional_speedup(summary.comparison.ratio_markitdown_over_moonbit) +
    "`",
  )
  lines.push(
    "- Engine overall ratio: `" +
    format_optional_speedup(summary.comparison.ratio_markitdown_over_engine) +
    "`",
  )
  lines.push(
    "- CLI/engine ratio: `" +
    format_optional_speedup(summary.comparison.ratio_cli_over_engine) +
    "`",
  )
  lines.push("")
  lines.push("## By Format")
  lines.push(
    markdown_table_row([
      "format", "rows", "cli compared", "engine compared", "cli ok", "engine ok",
      "external ok", "official rows", "official comparable", "cli median wall", "engine median wall",
      "markitdown median wall", "cli median speedup", "cli geomean speedup", "engine median speedup",
      "engine geomean speedup", "fixed overhead", "fixed share", "precision", "status",
    ]),
  )
  lines.push(markdown_table_separator(18))
  for row in summary.comparison.by_format {
    lines.push(
      markdown_table_row([
        row.format,
        row.rows.to_string(),
        row.compared_rows.to_string(),
        row.engine_compared_rows.to_string(),
        row.moonbit_success_rows.to_string(),
        row.moonbit_engine_success_rows.to_string(),
        row.markitdown_success_rows.to_string(),
        row.official_gate_rows.to_string(),
        row.official_gate_comparable_rows.to_string(),
        format_wall_pair(row.moonbit_median_wall_ms, row.moonbit_median_wall_us),
        format_wall_pair(
          row.moonbit_engine_median_wall_ms,
          row.moonbit_engine_median_wall_us,
        ),
        format_wall_pair(
          row.markitdown_median_wall_ms,
          row.markitdown_median_wall_us,
        ),
        format_optional_speedup(row.median_speedup),
        format_optional_speedup(row.cli_geomean_speedup),
        format_optional_speedup(row.engine_median_speedup),
        format_optional_speedup(row.engine_geomean_speedup),
        format_wall_pair(
          row.median_fixed_overhead_ms,
          row.median_fixed_overhead_us,
        ),
        format_optional_percent(row.median_fixed_overhead_share),
        row.timing_precision,
        row.status,
      ]),
    )
  }
  lines.push("")
  lines.push("## Fixed Overhead Summary")
  append_fixed_overhead_table(
    lines,
    take_first_bench_rows(
      lowest_fixed_overhead_share_rows(summary.comparison.rows),
      10,
    ),
  )
  lines.push("")
  lines.push("## Lowest CLI Speedup Rows")
  append_bench_comparison_table(
    lines,
    take_first_bench_rows(lowest_speedup_rows(summary.comparison.rows), 10),
  )
  lines.push("")
  lines.push("## Lowest Engine Speedup Rows")
  append_engine_bench_comparison_table(
    lines,
    take_first_bench_rows(
      lowest_engine_speedup_rows(summary.comparison.rows),
      10,
    ),
  )
  lines.push("")
  lines.push("## External Baseline Non-OK Rows")
  append_external_baseline_rows_table(
    lines,
    take_first_bench_rows(external_non_ok_rows(summary.comparison.rows), 10),
  )
  lines.push("")
  lines.push("## MoonBit Non-OK Rows")
  append_moonbit_non_ok_rows_table(
    lines,
    take_first_bench_rows(moonbit_non_ok_rows(summary.comparison.rows), 10),
  )
  lines.push("")
  lines.push("## Slowest MoonBit Rows")
  append_tool_bench_rows_table(
    lines,
    summary.tools.get("moonbit-cli").map(tool => tool.slowest).unwrap_or([]),
    false,
  )
  lines.push("")
  lines.push("## Highest RSS Rows")
  append_tool_bench_rows_table(lines, highest_rss_rows(summary.tools), true)
  lines.push("")
  lines.push("## First Optimization Candidates")
  for line in optimization_candidates(summary) {
    lines.push("- " + line)
  }
  lines.push("")
  lines.push("## Notes")
  lines.push(
    "- medians are computed per `bench_id + tool` from successful repeats only",
  )
  lines.push(
    "- `wall_ms` is a rounded compatibility/display field; `wall_us` is the preferred calculation basis",
  )
  lines.push(
    "- formal performance conclusions require `runner_mode=release`; dev moon run can distort in-process engine timing and fixed-overhead calculations",
  )
  lines.push(
    "- CLI speedup = `markitdown_median_wall_us / moonbit_cli_median_wall_us` when available, otherwise falls back to `wall_ms` and marks `timing_precision=ms_fallback`",
  )
  lines.push(
    "- Engine speedup = `markitdown_median_wall_us / moonbit_engine_median_wall_us` when available, otherwise falls back to `wall_ms`",
  )
  lines.push(
    "- Fixed overhead = `moonbit_cli_median_wall_us - moonbit_engine_median_wall_us` when available; negative values indicate measurement noise rather than clamped zero",
  )
  lines.push(
    "- Fixed share = `fixed_overhead_us / moonbit_cli_median_wall_us` when available, otherwise uses `wall_ms` fallback",
  )
  lines.push(
    "- CLI canonical rows include the selected real output behavior (`file` or `stdout_capture`); compare defaults keep `file` so product-like output cost remains included",
  )
  lines.push(
    "- Engine `memory` and `none` rows are diagnostic attribution modes only; they do not replace CLI canonical speedup conclusions",
  )
  lines.push(
    "- Engine `none` still renders Markdown and only skips the final sink write; it must not be interpreted as a user-visible product path",
  )
  lines.push(
    "- speedup and fixed-overhead metrics are omitted when required tool rows are not fully successful or the denominator wall time is `0`",
  )
  lines.push("- RSS units are normalized to `peak_rss_kb`")
  lines.push("- external tool failures do not imply product failure")
  lines.join("\n")
}

///|
fn append_bench_comparison_table(
  lines : Array[String],
  rows : Array[BenchComparison],
) -> Unit {
  lines.push(
    markdown_table_row([
      "bench_id", "format", "size_class", "cli median", "markitdown median", "cli speedup",
      "precision", "cli status", "markitdown status",
    ]),
  )
  lines.push(markdown_table_separator(9))
  if rows.length() == 0 {
    lines.push(
      markdown_table_row(["(none)", "-", "-", "-", "-", "-", "-", "-", "-"]),
    )
    return
  }
  for row in rows {
    lines.push(
      markdown_table_row([
        row.bench_id,
        row.format,
        row.size_class,
        format_wall_pair(row.moonbit_median_wall_ms, row.moonbit_median_wall_us),
        format_wall_pair(
          row.markitdown_median_wall_ms,
          row.markitdown_median_wall_us,
        ),
        format_optional_speedup(row.speedup),
        row.timing_precision,
        row.moonbit_status,
        row.markitdown_status,
      ]),
    )
  }
}

///|
fn append_engine_bench_comparison_table(
  lines : Array[String],
  rows : Array[BenchComparison],
) -> Unit {
  lines.push(
    markdown_table_row([
      "bench_id", "format", "size_class", "engine median", "markitdown median", "engine speedup",
      "precision", "engine status", "markitdown status",
    ]),
  )
  lines.push(markdown_table_separator(9))
  if rows.length() == 0 {
    lines.push(
      markdown_table_row(["(none)", "-", "-", "-", "-", "-", "-", "-", "-"]),
    )
    return
  }
  for row in rows {
    lines.push(
      markdown_table_row([
        row.bench_id,
        row.format,
        row.size_class,
        format_wall_pair(
          row.moonbit_engine_median_wall_ms,
          row.moonbit_engine_median_wall_us,
        ),
        format_wall_pair(
          row.markitdown_median_wall_ms,
          row.markitdown_median_wall_us,
        ),
        format_optional_speedup(row.engine_speedup),
        row.timing_precision,
        row.moonbit_engine_status,
        row.markitdown_status,
      ]),
    )
  }
}

///|
fn append_fixed_overhead_table(
  lines : Array[String],
  rows : Array[BenchComparison],
) -> Unit {
  lines.push(
    markdown_table_row([
      "bench_id", "format", "size_class", "cli median", "engine median", "fixed overhead",
      "fixed share", "markitdown median", "cli speedup", "engine speedup", "precision",
    ]),
  )
  lines.push(markdown_table_separator(11))
  if rows.length() == 0 {
    lines.push(
      markdown_table_row([
        "(none)", "-", "-", "-", "-", "-", "-", "-", "-", "-", "-",
      ]),
    )
    return
  }
  for row in rows {
    lines.push(
      markdown_table_row([
        row.bench_id,
        row.format,
        row.size_class,
        format_wall_pair(row.moonbit_median_wall_ms, row.moonbit_median_wall_us),
        format_wall_pair(
          row.moonbit_engine_median_wall_ms,
          row.moonbit_engine_median_wall_us,
        ),
        format_wall_pair(row.fixed_overhead_ms, row.fixed_overhead_us),
        format_optional_percent(row.fixed_overhead_share),
        format_wall_pair(
          row.markitdown_median_wall_ms,
          row.markitdown_median_wall_us,
        ),
        format_optional_speedup(row.speedup),
        format_optional_speedup(row.engine_speedup),
        row.timing_precision,
      ]),
    )
  }
}

///|
fn append_external_baseline_rows_table(
  lines : Array[String],
  rows : Array[BenchComparison],
) -> Unit {
  lines.push(
    markdown_table_row([
      "bench_id", "format", "size_class", "markitdown status", "cli status", "engine status",
      "precision",
    ]),
  )
  lines.push(markdown_table_separator(7))
  if rows.length() == 0 {
    lines.push(markdown_table_row(["(none)", "-", "-", "-", "-", "-", "-"]))
    return
  }
  for row in rows {
    lines.push(
      markdown_table_row([
        row.bench_id,
        row.format,
        row.size_class,
        row.markitdown_status,
        row.moonbit_status,
        row.moonbit_engine_status,
        row.timing_precision,
      ]),
    )
  }
}

///|
fn append_moonbit_non_ok_rows_table(
  lines : Array[String],
  rows : Array[BenchComparison],
) -> Unit {
  lines.push(
    markdown_table_row([
      "bench_id", "format", "size_class", "cli status", "engine status", "markitdown status",
      "precision",
    ]),
  )
  lines.push(markdown_table_separator(7))
  if rows.length() == 0 {
    lines.push(markdown_table_row(["(none)", "-", "-", "-", "-", "-", "-"]))
    return
  }
  for row in rows {
    lines.push(
      markdown_table_row([
        row.bench_id,
        row.format,
        row.size_class,
        row.moonbit_status,
        row.moonbit_engine_status,
        row.markitdown_status,
        row.timing_precision,
      ]),
    )
  }
}

///|
fn append_tool_bench_rows_table(
  lines : Array[String],
  rows : Array[ToolBenchAggregate],
  include_tool : Bool,
) -> Unit {
  let header = if include_tool {
    [
      "tool", "bench_id", "format", "size_class", "median wall", "input_bytes", "median output_bytes",
      "precision", "median RSS kb", "status",
    ]
  } else {
    [
      "bench_id", "format", "size_class", "median wall", "input_bytes", "median output_bytes",
      "precision", "median RSS kb", "status",
    ]
  }
  lines.push(markdown_table_row(header))
  lines.push(markdown_table_separator(header.length()))
  if rows.length() == 0 {
    if include_tool {
      lines.push(
        markdown_table_row([
          "(none)", "-", "-", "-", "-", "-", "-", "-", "-", "-",
        ]),
      )
    } else {
      lines.push(
        markdown_table_row(["(none)", "-", "-", "-", "-", "-", "-", "-", "-"]),
      )
    }
    return
  }
  for row in rows {
    let cells = if include_tool {
      [
        row.tool,
        row.bench_id,
        row.format,
        row.size_class,
        format_wall_pair(row.median_wall_ms, row.median_wall_us),
        row.input_bytes.to_string(),
        format_optional_int64(row.median_output_bytes),
        row.wall_precision,
        format_optional_int64(row.median_peak_rss_kb),
        row.status,
      ]
    } else {
      [
        row.bench_id,
        row.format,
        row.size_class,
        format_wall_pair(row.median_wall_ms, row.median_wall_us),
        row.input_bytes.to_string(),
        format_optional_int64(row.median_output_bytes),
        row.wall_precision,
        format_optional_int64(row.median_peak_rss_kb),
        row.status,
      ]
    }
    lines.push(markdown_table_row(cells))
  }
}

///|
fn optimization_candidates(summary : SummaryDocument) -> Array[String] {
  let out : Array[String] = []
  let external_only = external_only_gap_rows(summary.comparison.rows)
  if external_only.length() > 0 {
    out.push(
      "Cross-tool speedups are partial because MarkItDown is non-ok for `" +
      bench_id_excerpt(external_only) +
      "` while MoonBit CLI/engine remained ok.",
    )
  }
  let low_formats = summary.comparison.by_format
    .filter(row => {
      row.median_speedup is Some(_) && row.median_speedup.unwrap() < 35.0
    })
    .map(row => row.format)
  if low_formats.length() > 0 {
    out.push(
      "Prioritize format medians below `35x`: `" +
      low_formats.join("`, `") +
      "`.",
    )
  }
  let first_band = summary.comparison.by_format
    .filter(row => {
      row.engine_median_speedup is Some(_) &&
      row.engine_median_speedup.unwrap() >= 35.0 &&
      row.engine_median_speedup.unwrap() < 70.0
    })
    .map(row => row.format)
  if first_band.length() > 0 {
    out.push(
      "Formats whose engine medians are still in the first acceptable band (`35x` to `70x`) need follow-up: `" +
      first_band.join("`, `") +
      "`.",
    )
  }
  let weakest_rows = take_first_bench_rows(
    lowest_fixed_overhead_share_rows(summary.comparison.rows),
    3,
  )
  if weakest_rows.length() > 0 {
    out.push(
      "Inspect highest fixed-overhead-share rows first: `" +
      weakest_rows.map(row => row.bench_id).join("`, `") +
      "`.",
    )
  }
  let slowest_rows = summary.tools
    .get("moonbit-cli")
    .map(tool => tool.slowest)
    .unwrap_or([])
  if slowest_rows.length() > 0 {
    out.push(
      "MoonBit wall time is currently dominated by `" +
      slowest_rows[0].bench_id +
      "` (" +
      slowest_rows[0].format +
      "/" +
      slowest_rows[0].size_class +
      ").",
    )
  }
  let rss_rows = highest_rss_rows(summary.tools)
  if rss_rows.length() > 0 {
    out.push(
      "Memory hotspot candidate: `" +
      rss_rows[0].tool +
      ":" +
      rss_rows[0].bench_id +
      "` peaks at `" +
      format_optional_int64(rss_rows[0].median_peak_rss_kb) +
      "` KiB median RSS.",
    )
  }
  if out.length() == 0 {
    out.push(
      "No comparable speedup rows were produced; inspect tool availability and failure rows first.",
    )
  }
  if out.length() <= 3 {
    out
  } else {
    out[:3].to_owned()
  }
}

///|
fn lowest_speedup_rows(rows : Array[BenchComparison]) -> Array[BenchComparison] {
  let comparable = rows.filter(row => row.speedup is Some(_)).copy()
  comparable.sort_by(compare_lowest_speedup_row)
  comparable
}

///|
fn lowest_engine_speedup_rows(
  rows : Array[BenchComparison],
) -> Array[BenchComparison] {
  let comparable = rows.filter(row => row.engine_speedup is Some(_)).copy()
  comparable.sort_by(compare_lowest_engine_speedup_row)
  comparable
}

///|
fn lowest_fixed_overhead_share_rows(
  rows : Array[BenchComparison],
) -> Array[BenchComparison] {
  let comparable = rows
    .filter(row => row.fixed_overhead_share is Some(_))
    .copy()
  comparable.sort_by(compare_highest_fixed_overhead_share_row)
  comparable
}

///|
fn external_non_ok_rows(
  rows : Array[BenchComparison],
) -> Array[BenchComparison] {
  let out = rows.filter(row => row.markitdown_status != "ok").copy()
  out.sort_by(compare_bench_comparison_identity)
  out
}

///|
fn external_only_gap_rows(
  rows : Array[BenchComparison],
) -> Array[BenchComparison] {
  let out = rows
    .filter(row => {
      row.markitdown_status != "ok" &&
      row.moonbit_status == "ok" &&
      row.moonbit_engine_status == "ok"
    })
    .copy()
  out.sort_by(compare_bench_comparison_identity)
  out
}

///|
fn moonbit_non_ok_rows(rows : Array[BenchComparison]) -> Array[BenchComparison] {
  let out = rows
    .filter(row => {
      row.moonbit_status != "ok" || row.moonbit_engine_status != "ok"
    })
    .copy()
  out.sort_by(compare_bench_comparison_identity)
  out
}

///|
fn highest_rss_rows(
  tools : Map[String, ToolSummary],
) -> Array[ToolBenchAggregate] {
  let rows : Array[ToolBenchAggregate] = []
  for entry in tools {
    rows.append(entry.1.rows.filter(row => row.median_peak_rss_kb is Some(_)))
  }
  rows.sort_by(compare_highest_rss_tool_row)
  take_first_tool_rows(rows, 10)
}

///|
fn sorted_tool_summaries(
  tools : Map[String, ToolSummary],
) -> Array[ToolSummary] {
  let out : Array[ToolSummary] = []
  for entry in tools {
    out.push(entry.1)
  }
  out.sort_by(fn(a, b) { a.tool[:].lexical_compare(b.tool[:]) })
  out
}

///|
fn collect_sorted_bench_ids(
  moonbit_by_bench : Map[String, ToolBenchAggregate],
  engine_by_bench : Map[String, ToolBenchAggregate],
  markitdown_by_bench : Map[String, ToolBenchAggregate],
) -> Array[String] {
  let seen : Map[String, Bool] = {}
  for entry in moonbit_by_bench {
    seen[entry.0] = true
  }
  for entry in engine_by_bench {
    seen[entry.0] = true
  }
  for entry in markitdown_by_bench {
    seen[entry.0] = true
  }
  let out : Array[String] = []
  for entry in seen {
    out.push(entry.0)
  }
  out.sort()
  out
}

///|
fn to_tool_bench_map(
  rows : Array[ToolBenchAggregate],
) -> Map[String, ToolBenchAggregate] {
  let out : Map[String, ToolBenchAggregate] = {}
  for row in rows {
    out[row.bench_id] = row
  }
  out
}

///|
fn pick_tool_bench_metadata(
  moonbit : ToolBenchAggregate?,
  engine : ToolBenchAggregate?,
  markitdown : ToolBenchAggregate?,
  bench_id : String,
) -> ToolBenchAggregate {
  match moonbit {
    Some(row) => row
    None =>
      match engine {
        Some(row) => row
        None =>
          match markitdown {
            Some(row) => row
            None =>
              {
                bench_id,
                format: "unknown",
                size_class: "unknown",
                enabled_tier: "unknown",
                tool: "missing",
                tool_version: None,
                measurement_mode: None,
                output_write_mode: None,
                rel_path: "",
                input_bytes: 0,
                run_count: 0,
                repeat_count: 0,
                success_count: 0,
                failed_count: 0,
                timeout_count: 0,
                unavailable_count: 0,
                measurement_error_count: 0,
                status: "missing",
                median_wall_ms: None,
                min_wall_ms: None,
                max_wall_ms: None,
                median_wall_us: None,
                min_wall_us: None,
                max_wall_us: None,
                wall_precision: "missing",
                median_peak_rss_kb: None,
                peak_rss_max_kb: None,
                median_output_bytes: None,
                max_output_bytes: None,
                total_output_bytes: 0L,
                error: Some("missing comparison metadata"),
              }
          }
      }
  }
}

///|
fn repeat_count_or_none(rows : Array[CliResult]) -> Int? {
  if rows.length() == 0 {
    return None
  }
  let repeat_count = rows[0].repeat_count
  for row in rows {
    if row.repeat_count != repeat_count {
      return None
    }
  }
  Some(repeat_count)
}

///|
fn compute_speedup(
  moonbit : ToolBenchAggregate?,
  markitdown : ToolBenchAggregate?,
) -> Double? {
  match moonbit {
    Some(moonbit_row) =>
      match markitdown {
        Some(markitdown_row) => {
          if moonbit_row.status != "ok" || markitdown_row.status != "ok" {
            return None
          }
          match comparison_wall_value_us(moonbit_row, markitdown_row) {
            Some((moon_wall, mark_wall)) =>
              if moon_wall > 0L {
                Some(mark_wall.to_double() / moon_wall.to_double())
              } else {
                None
              }
            None => None
          }
        }
        None => None
      }
    None => None
  }
}

///|
fn compute_fixed_overhead_us(
  moonbit : ToolBenchAggregate?,
  engine : ToolBenchAggregate?,
) -> Int64? {
  match moonbit {
    Some(cli_row) =>
      match engine {
        Some(engine_row) => {
          if cli_row.status != "ok" || engine_row.status != "ok" {
            return None
          }
          match comparison_wall_value_us(cli_row, engine_row) {
            Some((cli_wall, engine_wall)) => Some(cli_wall - engine_wall)
            None => None
          }
        }
        None => None
      }
    None => None
  }
}

///|
fn compute_fixed_overhead_ms(
  moonbit : ToolBenchAggregate?,
  engine : ToolBenchAggregate?,
) -> Int64? {
  compute_fixed_overhead_us(moonbit, engine).map(rounded_wall_us_to_ms)
}

///|
fn compute_fixed_overhead_share(
  moonbit : ToolBenchAggregate?,
  engine : ToolBenchAggregate?,
) -> Double? {
  match compute_fixed_overhead_us(moonbit, engine) {
    Some(value) =>
      match moonbit {
        Some(cli_row) =>
          match comparison_wall_for_denominator_us(cli_row) {
            Some(cli_wall) =>
              if cli_wall > 0L {
                Some(value.to_double() / cli_wall.to_double())
              } else {
                None
              }
            None => None
          }
        None => None
      }
    None => None
  }
}

///|
fn aggregate_status(rows : Array[CliResult]) -> String {
  let run_count = rows.length()
  let success_count = rows.filter(row => row.status == "ok").length()
  if success_count == run_count {
    return "ok"
  }
  if success_count > 0 {
    return "partial_success"
  }
  let failed_count = rows.filter(row => row.status == "failed").length()
  let timeout_count = rows.filter(row => row.status == "timeout").length()
  let unavailable_count = rows
    .filter(row => row.status == "unavailable")
    .length()
  let measurement_error_count = rows
    .filter(row => row.status == "measurement_error")
    .length()
  if unavailable_count == run_count {
    "unavailable"
  } else if timeout_count == run_count {
    "timeout"
  } else if measurement_error_count == run_count {
    "measurement_error"
  } else if failed_count == run_count {
    "failed"
  } else {
    "mixed_failure"
  }
}

///|
fn aggregate_error(rows : Array[CliResult]) -> String? {
  for row in rows {
    match row.error {
      Some(message) if message.trim() != "" => return Some(message)
      _ => ()
    }
  }
  None
}

///|
fn comparison_status(total_rows : Int, compared_rows : Int) -> String {
  if total_rows == 0 {
    "empty"
  } else if compared_rows == total_rows {
    "ok"
  } else if compared_rows > 0 {
    "partial"
  } else {
    "no_comparable"
  }
}

///|
fn is_official_gate_format(format : String) -> Bool {
  let normalized = format.trim().to_lower().to_owned()
  [
    "txt", "csv", "tsv", "json", "yaml", "xml", "markdown", "html", "zip", "epub",
    "pdf", "docx", "pptx", "xlsx",
  ].contains(normalized)
}

///|
fn is_official_gate_tier(tier : String) -> Bool {
  let normalized = tier.trim().to_lower().to_owned()
  normalized == "regular" || normalized == "release" || normalized == "stress"
}

///|
fn is_official_gate_row(row : BenchComparison) -> Bool {
  is_official_gate_format(row.format) && is_official_gate_tier(row.enabled_tier)
}

///|
fn summarize_official_gate(
  rows : Array[BenchComparison],
  selector_stats : @manifest.SelectorStats,
) -> OfficialGateSummary {
  let official_rows = rows.filter(is_official_gate_row)
  let comparable = official_rows.filter(row => row.speedup is Some(_))
  let excluded : Map[String, Int] = {}
  for row in official_rows {
    match official_gate_exclusion_reason(row) {
      Some(reason) => increment_reason_count(excluded, reason)
      None => ()
    }
  }
  {
    row_count: official_rows.length(),
    comparable_count: comparable.length(),
    status: official_gate_status(
      selector_stats.selected_rows,
      official_rows.length(),
      comparable.length(),
    ),
    excluded_rows_by_reason: excluded,
  }
}

///|
fn official_gate_exclusion_reason(row : BenchComparison) -> String? {
  if row.speedup is Some(_) {
    return None
  }
  if row.markitdown_status != "ok" {
    return Some("markitdown_non_ok")
  }
  if row.moonbit_status != "ok" {
    return Some("moonbit_cli_non_ok")
  }
  if row.markitdown_median_wall_us is None || row.moonbit_median_wall_us is None {
    return Some("missing_wall_us")
  }
  if row.moonbit_median_wall_us == Some(0L) {
    return Some("zero_cli_wall_time")
  }
  Some("not_comparable")
}

///|
fn official_gate_status(
  selected_rows : Int,
  official_rows : Int,
  comparable_rows : Int,
) -> String {
  let scoped_rows = if selected_rows > 0 {
    selected_rows
  } else {
    official_rows
  }
  if official_rows == 0 {
    "empty"
  } else if scoped_rows != official_rows {
    "partial_scope"
  } else if comparable_rows == official_rows {
    "ok"
  } else if comparable_rows > 0 {
    "partial"
  } else {
    "no_comparable"
  }
}

///|
fn increment_reason_count(reasons : Map[String, Int], reason : String) -> Unit {
  let next = match reasons.get(reason) {
    Some(count) => count + 1
    None => 1
  }
  reasons[reason] = next
}

///|
fn markdown_table_row(cells : Array[String]) -> String {
  "| " + cells.join(" | ") + " |"
}

///|
fn markdown_table_separator(columns : Int) -> String {
  let cells : Array[String] = []
  for _ in 0..<columns {
    cells.push("---")
  }
  markdown_table_row(cells)
}

///|
fn take_first_tool_rows(
  rows : Array[ToolBenchAggregate],
  count : Int,
) -> Array[ToolBenchAggregate] {
  if rows.length() <= count {
    rows
  } else {
    rows[:count].to_owned()
  }
}

///|
fn take_first_bench_rows(
  rows : Array[BenchComparison],
  count : Int,
) -> Array[BenchComparison] {
  if rows.length() <= count {
    rows
  } else {
    rows[:count].to_owned()
  }
}

///|
fn compare_tool_bench_row(
  a : ToolBenchAggregate,
  b : ToolBenchAggregate,
) -> Int {
  let format_cmp = a.format[:].lexical_compare(b.format[:])
  if format_cmp != 0 {
    return format_cmp
  }
  let size_cmp = a.size_class[:].lexical_compare(b.size_class[:])
  if size_cmp != 0 {
    return size_cmp
  }
  a.bench_id[:].lexical_compare(b.bench_id[:])
}

///|
fn compare_slowest_tool_row(
  a : ToolBenchAggregate,
  b : ToolBenchAggregate,
) -> Int {
  let primary = compare_optional_int64_desc(a.median_wall_us, b.median_wall_us)
  if primary != 0 {
    return primary
  }
  let secondary = compare_optional_int64_desc(
    a.median_wall_ms,
    b.median_wall_ms,
  )
  if secondary != 0 {
    return secondary
  }
  compare_tool_bench_row(a, b)
}

///|
fn compare_highest_rss_tool_row(
  a : ToolBenchAggregate,
  b : ToolBenchAggregate,
) -> Int {
  let primary = compare_optional_int64_desc(
    a.median_peak_rss_kb,
    b.median_peak_rss_kb,
  )
  if primary != 0 {
    return primary
  }
  compare_slowest_tool_row(a, b)
}

///|
fn compare_failure_tool_row(
  a : ToolBenchAggregate,
  b : ToolBenchAggregate,
) -> Int {
  let status_cmp = a.status[:].lexical_compare(b.status[:])
  if status_cmp != 0 {
    return status_cmp
  }
  compare_tool_bench_row(a, b)
}

///|
fn compare_lowest_speedup_row(a : BenchComparison, b : BenchComparison) -> Int {
  let primary = compare_optional_double_asc(a.speedup, b.speedup)
  if primary != 0 {
    return primary
  }
  let moonbit_us_cmp = compare_optional_int64_desc(
    a.moonbit_median_wall_us,
    b.moonbit_median_wall_us,
  )
  if moonbit_us_cmp != 0 {
    return moonbit_us_cmp
  }
  let moonbit_cmp = compare_optional_int64_desc(
    a.moonbit_median_wall_ms,
    b.moonbit_median_wall_ms,
  )
  if moonbit_cmp != 0 {
    return moonbit_cmp
  }
  a.bench_id[:].lexical_compare(b.bench_id[:])
}

///|
fn compare_lowest_engine_speedup_row(
  a : BenchComparison,
  b : BenchComparison,
) -> Int {
  let primary = compare_optional_double_asc(a.engine_speedup, b.engine_speedup)
  if primary != 0 {
    return primary
  }
  let engine_us_cmp = compare_optional_int64_desc(
    a.moonbit_engine_median_wall_us,
    b.moonbit_engine_median_wall_us,
  )
  if engine_us_cmp != 0 {
    return engine_us_cmp
  }
  let engine_cmp = compare_optional_int64_desc(
    a.moonbit_engine_median_wall_ms,
    b.moonbit_engine_median_wall_ms,
  )
  if engine_cmp != 0 {
    return engine_cmp
  }
  a.bench_id[:].lexical_compare(b.bench_id[:])
}

///|
fn compare_highest_fixed_overhead_share_row(
  a : BenchComparison,
  b : BenchComparison,
) -> Int {
  let primary = compare_optional_double_desc(
    a.fixed_overhead_share,
    b.fixed_overhead_share,
  )
  if primary != 0 {
    return primary
  }
  let cli_us_cmp = compare_optional_int64_desc(
    a.fixed_overhead_us,
    b.fixed_overhead_us,
  )
  if cli_us_cmp != 0 {
    return cli_us_cmp
  }
  let cli_cmp = compare_optional_int64_desc(
    a.fixed_overhead_ms,
    b.fixed_overhead_ms,
  )
  if cli_cmp != 0 {
    return cli_cmp
  }
  a.bench_id[:].lexical_compare(b.bench_id[:])
}

///|
fn compare_format_comparison(a : FormatComparison, b : FormatComparison) -> Int {
  a.format[:].lexical_compare(b.format[:])
}

///|
fn compare_bench_comparison_identity(
  a : BenchComparison,
  b : BenchComparison,
) -> Int {
  let format_cmp = a.format[:].lexical_compare(b.format[:])
  if format_cmp != 0 {
    return format_cmp
  }
  let size_cmp = a.size_class[:].lexical_compare(b.size_class[:])
  if size_cmp != 0 {
    return size_cmp
  }
  a.bench_id[:].lexical_compare(b.bench_id[:])
}

///|
fn compare_optional_int64_desc(a : Int64?, b : Int64?) -> Int {
  match a {
    Some(left) =>
      match b {
        Some(right) => Int64::compare(right, left)
        None => -1
      }
    None =>
      match b {
        Some(_) => 1
        None => 0
      }
  }
}

///|
fn compare_optional_double_asc(a : Double?, b : Double?) -> Int {
  match a {
    Some(left) =>
      match b {
        Some(right) => compare_double_asc(left, right)
        None => -1
      }
    None =>
      match b {
        Some(_) => 1
        None => 0
      }
  }
}

///|
fn compare_optional_double_desc(a : Double?, b : Double?) -> Int {
  match a {
    Some(left) =>
      match b {
        Some(right) => compare_double_asc(right, left)
        None => -1
      }
    None =>
      match b {
        Some(_) => 1
        None => 0
      }
  }
}

///|
fn compare_double_asc(a : Double, b : Double) -> Int {
  if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|
fn load_selector_stats(path : String?) -> @manifest.SelectorStats {
  match path {
    Some(value) => {
      let content = @fs.read_file_to_string(value, encoding="utf8") catch {
        _ => return @manifest.empty_selector_stats()
      }
      let json = @json.parse(content.trim()) catch {
        _ => return @manifest.empty_selector_stats()
      }
      (@json.from_json(json) : @manifest.SelectorStats) catch {
        _ =>
          legacy_selector_stats_to_current(
            (@json.from_json(json) : LegacySelectorStats) catch {
              _ => return @manifest.empty_selector_stats()
            },
          )
      }
    }
    None => @manifest.empty_selector_stats()
  }
}

///|
fn legacy_selector_stats_to_current(
  legacy : LegacySelectorStats,
) -> @manifest.SelectorStats {
  @manifest.make_selector_stats(
    legacy.requested_tier,
    [],
    "cumulative",
    [],
    legacy.selected_rows,
    normalize_selector_formats(legacy.formats),
    legacy.skipped_by_reason,
  )
}

///|
fn normalize_selector_formats(formats : Array[String]) -> Array[String] {
  let normalized = formats
    .map(format => format.trim().to_lower().to_owned())
    .filter(format => format != "")
  normalized.sort()
  normalized.dedup()
  normalized
}

///|
fn median_sorted_int64(values : Array[Int64]) -> Int64? {
  if values.length() == 0 {
    return None
  }
  let middle = values.length() / 2
  if values.length() % 2 == 1 {
    Some(values[middle])
  } else {
    Some((values[middle - 1] + values[middle]) / 2L)
  }
}

///|
fn median_sorted_double(values : Array[Double]) -> Double? {
  if values.length() == 0 {
    return None
  }
  let middle = values.length() / 2
  if values.length() % 2 == 1 {
    Some(values[middle])
  } else {
    Some((values[middle - 1] + values[middle]) / 2.0)
  }
}

///|
fn geomean_speedup(values : Array[Double]) -> Double? {
  if values.length() == 0 {
    return None
  }
  let positive = values.filter(value => value > 0.0)
  if positive.length() == 0 {
    return None
  }
  let total_ln = positive.fold(init=0.0, fn(acc, value) {
    acc + @math.ln(value)
  })
  Some(@math.exp(total_ln / positive.length().to_double()))
}

///|
fn first_sorted_int64(values : Array[Int64]) -> Int64? {
  if values.length() == 0 {
    None
  } else {
    Some(values[0])
  }
}

///|
fn first_sorted_double(values : Array[Double]) -> Double? {
  if values.length() == 0 {
    None
  } else {
    Some(values[0])
  }
}

///|
fn detect_markitdown_info(rows : Array[CliResult]) -> String {
  for row in rows {
    if row.tool == "markitdown" {
      return row.tool_version.unwrap_or("unknown")
    }
  }
  "missing"
}

///|
fn summary_runner_mode(rows : Array[CliResult]) -> String {
  first_non_empty_runner_mode(rows).unwrap_or("unknown")
}

///|
fn summary_canonical_performance(rows : Array[CliResult]) -> Bool {
  if rows.length() == 0 {
    return false
  }
  if rows.any(fn(row) { row.canonical_performance == Some(false) }) {
    return false
  }
  rows.any(fn(row) { row.canonical_performance == Some(true) })
}

///|
fn summary_runner_path(rows : Array[CliResult]) -> String? {
  for row in rows {
    match row.runner_path {
      Some(path) if path != "" => return Some(path)
      _ => ()
    }
  }
  None
}

///|
fn summary_warnings(
  rows : Array[CliResult],
  comparison : SummaryComparison,
) -> Array[String] {
  let runner_mode = summary_runner_mode(rows)
  let canonical = summary_canonical_performance(rows)
  let warnings = canonical_runner_warnings(
    runner_mode,
    canonical,
    has_inprocess_engine=rows.any(fn(row) {
      row.measurement_mode == Some("inprocess-engine")
    }),
  )
  if rows.any(fn(row) {
      row.tool == "moonbit-engine" && row.output_write_mode == Some("none")
    }) {
    warnings.push(
      "Engine `none` output mode is diagnostic-only and should not be used as a CLI/product speedup conclusion.",
    )
  }
  if rows.any(fn(row) {
      row.tool == "moonbit-engine" && row.output_write_mode == Some("memory")
    }) {
    warnings.push(
      "Engine `memory` output mode is diagnostic-only and isolates sink write cost rather than end-user CLI behavior.",
    )
  }
  if rows.any(fn(row) {
      row.tool == "moonbit-cli" &&
      row.output_write_mode == Some("stdout_capture")
    }) {
    warnings.push(
      "CLI `stdout_capture` rows are attribution runs and should not replace the canonical CLI file-output benchmark conclusion by default.",
    )
  }
  let external_non_ok = external_non_ok_rows(comparison.rows)
  if external_non_ok.length() > 0 {
    warnings.push(
      "External MarkItDown baseline has " +
      external_non_ok.length().to_string() +
      " non-ok bench row(s); CLI/engine speedups are computed from comparable rows only.",
    )
  }
  let external_only = external_only_gap_rows(comparison.rows)
  if external_only.length() > 0 {
    warnings.push(
      "MoonBit CLI/engine remained ok for " +
      external_only.length().to_string() +
      " row(s) excluded only by external baseline status: " +
      bench_id_excerpt(external_only) +
      ".",
    )
  }
  warnings
}

///|
fn bench_id_excerpt(rows : Array[BenchComparison], limit? : Int = 3) -> String {
  let out : Array[String] = []
  let end = if rows.length() < limit { rows.length() } else { limit }
  for index in 0..<end {
    out.push("`" + rows[index].bench_id + "`")
  }
  if rows.length() > limit {
    out.push("...")
  }
  out.join(", ")
}

///|
fn first_non_empty_runner_mode(rows : Array[CliResult]) -> String? {
  for row in rows {
    match row.runner_mode {
      Some(mode) if mode != "" => return Some(mode)
      _ => ()
    }
  }
  None
}

///|
fn collect_wall_stats(rows : Array[CliResult]) -> WallStats {
  let wall_us_values = rows
    .filter(row => row.wall_us is Some(_))
    .map(row => row.wall_us.unwrap())
  wall_us_values.sort()
  if wall_us_values.length() > 0 {
    return {
      median_ms: median_sorted_int64(wall_us_values.map(rounded_wall_us_to_ms)),
      min_ms: first_sorted_int64(wall_us_values.map(rounded_wall_us_to_ms)),
      max_ms: last_sorted_int64(wall_us_values.map(rounded_wall_us_to_ms)),
      median_us: median_sorted_int64(wall_us_values),
      min_us: first_sorted_int64(wall_us_values),
      max_us: last_sorted_int64(wall_us_values),
      precision: "wall_us",
    }
  }
  let wall_ms_values = rows.map(row => row.wall_ms)
  wall_ms_values.sort()
  {
    median_ms: median_sorted_int64(wall_ms_values),
    min_ms: first_sorted_int64(wall_ms_values),
    max_ms: last_sorted_int64(wall_ms_values),
    median_us: None,
    min_us: None,
    max_us: None,
    precision: if wall_ms_values.length() > 0 {
      "ms_fallback"
    } else {
      "missing"
    },
  }
}

///|
fn comparison_wall_value_us(
  numerator : ToolBenchAggregate,
  denominator : ToolBenchAggregate,
) -> (Int64, Int64)? {
  match numerator.median_wall_us {
    Some(left) =>
      match denominator.median_wall_us {
        Some(right) => Some((left, right))
        None => comparison_wall_value_ms(numerator, denominator)
      }
    None => comparison_wall_value_ms(numerator, denominator)
  }
}

///|
fn comparison_wall_value_ms(
  numerator : ToolBenchAggregate,
  denominator : ToolBenchAggregate,
) -> (Int64, Int64)? {
  match numerator.median_wall_ms {
    Some(left) =>
      match denominator.median_wall_ms {
        Some(right) => Some((left * 1000L, right * 1000L))
        None => None
      }
    None => None
  }
}

///|
fn comparison_wall_for_denominator_us(row : ToolBenchAggregate) -> Int64? {
  match row.median_wall_us {
    Some(value) => Some(value)
    None => row.median_wall_ms.map(value => value * 1000L)
  }
}

///|
fn bench_comparison_precision(
  moonbit : ToolBenchAggregate?,
  engine : ToolBenchAggregate?,
  markitdown : ToolBenchAggregate?,
) -> String {
  let rows : Array[ToolBenchAggregate] = []
  match moonbit {
    Some(row) => rows.push(row)
    None => ()
  }
  match engine {
    Some(row) => rows.push(row)
    None => ()
  }
  match markitdown {
    Some(row) => rows.push(row)
    None => ()
  }
  wall_precision_from_aggregates(rows)
}

///|
fn format_comparison_precision(rows : Array[BenchComparison]) -> String {
  if rows.length() == 0 {
    return "missing"
  }
  for row in rows {
    if row.timing_precision != "wall_us" {
      return "ms_fallback"
    }
  }
  "wall_us"
}

///|
fn comparison_precision(rows : Array[BenchComparison]) -> String {
  format_comparison_precision(rows)
}

///|
fn wall_precision_from_aggregates(rows : Array[ToolBenchAggregate]) -> String {
  if rows.length() == 0 {
    return "missing"
  }
  for row in rows {
    if row.wall_precision != "wall_us" {
      return if row.wall_precision == "missing" {
        "missing"
      } else {
        "ms_fallback"
      }
    }
  }
  "wall_us"
}

///|
fn last_sorted_int64(values : Array[Int64]) -> Int64? {
  if values.length() == 0 {
    None
  } else {
    Some(values[values.length() - 1])
  }
}
