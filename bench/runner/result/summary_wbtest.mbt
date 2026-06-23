///|
fn summary_test_result(
  tool : String,
  bench_id : String,
  format : String,
  size_class : String,
  wall_ms : Int64,
  wall_us? : Int64? = Some(wall_ms * 1000L),
  status? : String = "ok",
  repeat_index? : Int = 0,
  repeat_count? : Int = 3,
  peak_rss_kb? : Int64 = 100L,
  output_bytes? : Int64 = 10L,
) -> CliResult {
  {
    schema_version: 1,
    run_id: "run-summary-test",
    repo_commit: "deadbeef",
    runner_mode: Some("release"),
    canonical_performance: Some(true),
    runner_path: Some("_build/native/release/build/bench/runner/runner.exe"),
    tool,
    tool_version: Some(tool + "-v"),
    measurement_mode: Some(
      if tool == "moonbit-engine" {
        "inprocess-engine"
      } else {
        "process-cli"
      },
    ),
    output_write_mode: Some("file"),
    bench_id,
    format,
    size_class,
    enabled_tier: "smoke",
    bench_layers: "product,external",
    tags: "",
    rel_path: "samples/bench/" + format + "/" + bench_id,
    input_bytes: 123,
    input_sha256: "sha",
    command_kind: "cli-baseline",
    command_display: tool + " <input> -o <output>",
    repeat_index,
    repeat_count,
    exit_code: if status == "ok" {
      0
    } else {
      1
    },
    status,
    timed_out: status == "timeout",
    wall_ms,
    wall_us,
    user_time_us: wall_us,
    sys_time_us: Some(0L),
    peak_rss_kb: if status == "ok" {
      Some(peak_rss_kb)
    } else {
      None
    },
    stdout_bytes: 0L,
    stderr_bytes: if status == "ok" {
      0L
    } else {
      20L
    },
    output_bytes: if status == "ok" {
      output_bytes
    } else {
      0L
    },
    stdout_excerpt: "",
    stderr_excerpt: if status == "ok" {
      ""
    } else {
      status + " stderr"
    },
    error: if status == "ok" {
      None
    } else {
      Some(status + " error")
    },
  }
}

///|
fn summary_test_rows() -> Array[CliResult] {
  [
    summary_test_result(
      "moonbit-cli",
      "txt_small_alpha_v1",
      "txt",
      "small",
      10L,
      repeat_index=0,
    ),
    summary_test_result(
      "moonbit-cli",
      "txt_small_alpha_v1",
      "txt",
      "small",
      20L,
      repeat_index=1,
    ),
    summary_test_result(
      "moonbit-cli",
      "txt_small_alpha_v1",
      "txt",
      "small",
      30L,
      repeat_index=2,
    ),
    summary_test_result(
      "markitdown",
      "txt_small_alpha_v1",
      "txt",
      "small",
      100L,
      repeat_index=0,
      peak_rss_kb=300L,
    ),
    summary_test_result(
      "markitdown",
      "txt_small_alpha_v1",
      "txt",
      "small",
      110L,
      repeat_index=1,
      peak_rss_kb=320L,
    ),
    summary_test_result(
      "markitdown",
      "txt_small_alpha_v1",
      "txt",
      "small",
      120L,
      repeat_index=2,
      peak_rss_kb=340L,
    ),
    summary_test_result(
      "moonbit-engine",
      "txt_small_alpha_v1",
      "txt",
      "small",
      12L,
      repeat_index=0,
    ),
    summary_test_result(
      "moonbit-engine",
      "txt_small_alpha_v1",
      "txt",
      "small",
      14L,
      repeat_index=1,
    ),
    summary_test_result(
      "moonbit-engine",
      "txt_small_alpha_v1",
      "txt",
      "small",
      16L,
      repeat_index=2,
    ),
    summary_test_result(
      "moonbit-cli",
      "html_medium_beta_v1",
      "html",
      "medium",
      50L,
      repeat_index=0,
      peak_rss_kb=600L,
    ),
    summary_test_result(
      "moonbit-cli",
      "html_medium_beta_v1",
      "html",
      "medium",
      60L,
      status="timeout",
      repeat_index=1,
      peak_rss_kb=600L,
    ),
    summary_test_result(
      "moonbit-cli",
      "html_medium_beta_v1",
      "html",
      "medium",
      70L,
      repeat_index=2,
      peak_rss_kb=650L,
    ),
    summary_test_result(
      "markitdown",
      "html_medium_beta_v1",
      "html",
      "medium",
      500L,
      repeat_index=0,
      peak_rss_kb=900L,
    ),
    summary_test_result(
      "markitdown",
      "html_medium_beta_v1",
      "html",
      "medium",
      510L,
      repeat_index=1,
      peak_rss_kb=920L,
    ),
    summary_test_result(
      "markitdown",
      "html_medium_beta_v1",
      "html",
      "medium",
      520L,
      repeat_index=2,
      peak_rss_kb=940L,
    ),
    summary_test_result(
      "moonbit-engine",
      "html_medium_beta_v1",
      "html",
      "medium",
      45L,
      repeat_index=0,
      peak_rss_kb=580L,
    ),
    summary_test_result(
      "moonbit-engine",
      "html_medium_beta_v1",
      "html",
      "medium",
      47L,
      repeat_index=1,
      peak_rss_kb=590L,
    ),
    summary_test_result(
      "moonbit-engine",
      "html_medium_beta_v1",
      "html",
      "medium",
      49L,
      repeat_index=2,
      peak_rss_kb=600L,
    ),
  ]
}

///|
fn find_bench_comparison(
  rows : Array[BenchComparison],
  bench_id : String,
) -> BenchComparison {
  for row in rows {
    if row.bench_id == bench_id {
      return row
    }
  }
  abort("missing bench comparison: " + bench_id)
}

///|
fn find_format_comparison(
  rows : Array[FormatComparison],
  format : String,
) -> FormatComparison {
  for row in rows {
    if row.format == format {
      return row
    }
  }
  abort("missing format comparison: " + format)
}

///|
fn assert_optional_double_close(
  actual : Double?,
  expected : Double,
  epsilon? : Double = 0.000000000001,
) -> Unit raise {
  match actual {
    Some(value) => assert_true((value - expected).abs() <= epsilon)
    None => assert_true(false)
  }
}

///|
fn summary_test_tmp_root() -> String {
  ".tmp/markitdown-bench-test/summary"
}

///|
fn ensure_summary_test_dir(path : String) -> Unit {
  if @fs.path_exists(path) {
    return
  }
  @fs.create_dir(path) catch {
    _ => ()
  }
}

///|
fn write_summary_test_jsonl(path : String, rows : Array[String]) -> Unit {
  ensure_summary_test_dir(summary_test_tmp_root())
  @fs.write_string_to_file(path, rows.join("\n") + "\n", encoding="utf8") catch {
    err => abort("failed to write summary test jsonl: " + err.to_string())
  }
}

///|
test "summary groups repeats into per-bench medians and speedups" {
  let summary = summarize_rows(summary_test_rows(), None)
  assert_eq(summary.schema_version, 4)
  assert_eq(summary.environment.runner_mode, "release")
  assert_true(summary.environment.canonical_performance)
  assert_eq(summary.corpus.tier, "smoke")
  assert_true(summary.warnings.length() == 0)
  assert_eq(summary.comparison.comparable_count, 1)
  assert_eq(summary.comparison.engine_comparable_count, 2)
  assert_eq(summary.comparison.fixed_overhead_count, 1)
  assert_true(summary.comparison.median_speedup_overall == Some(5.5))
  assert_true(
    summary.comparison.engine_median_speedup_overall == Some(9.354103343465045),
  )
  assert_true(summary.comparison.best_speedup == Some(5.5))
  assert_true(summary.comparison.worst_speedup == Some(5.5))
  assert_true(summary.comparison.median_fixed_overhead_ms == Some(6L))
  assert_true(summary.comparison.median_fixed_overhead_us == Some(6000L))
  assert_eq(summary.comparison.timing_precision, "wall_us")

  let moonbit = summary.tools.get("moonbit-cli").unwrap()
  assert_eq(moonbit.total_files, 2)
  assert_eq(moonbit.total_runs, 6)
  assert_true(moonbit.repeat_count == Some(3))
  assert_eq(moonbit.success_count, 5)
  assert_eq(moonbit.timeout_count, 1)
  assert_true(moonbit.median_wall_ms == Some(30L))
  assert_true(moonbit.median_wall_us == Some(30000L))
  assert_eq(moonbit.wall_precision, "wall_us")
  assert_true(moonbit.rows[0].bench_id == "html_medium_beta_v1")
  assert_true(moonbit.rows[0].status == "partial_success")
  assert_true(moonbit.rows[1].bench_id == "txt_small_alpha_v1")
  assert_true(moonbit.rows[1].median_wall_ms == Some(20L))
  assert_true(moonbit.rows[1].median_wall_us == Some(20000L))

  let engine = summary.tools.get("moonbit-engine").unwrap()
  assert_eq(engine.total_files, 2)
  assert_eq(engine.total_runs, 6)
  assert_true(engine.median_wall_ms == Some(30L))
  assert_true(engine.median_wall_us == Some(30500L))

  let comparison_rows = summary.comparison.rows
  assert_eq(comparison_rows.length(), 2)
  let html_row = find_bench_comparison(comparison_rows, "html_medium_beta_v1")
  assert_eq(html_row.bench_id, "html_medium_beta_v1")
  assert_true(html_row.speedup == None)
  assert_true(html_row.engine_speedup == Some(10.851063829787234))
  assert_eq(html_row.moonbit_status, "partial_success")
  assert_eq(html_row.moonbit_engine_status, "ok")
  assert_eq(html_row.markitdown_status, "ok")
  assert_eq(html_row.timing_precision, "wall_us")
  let txt_row = find_bench_comparison(comparison_rows, "txt_small_alpha_v1")
  assert_eq(txt_row.bench_id, "txt_small_alpha_v1")
  assert_true(txt_row.moonbit_median_wall_ms == Some(20L))
  assert_true(txt_row.moonbit_engine_median_wall_ms == Some(14L))
  assert_true(txt_row.markitdown_median_wall_ms == Some(110L))
  assert_true(txt_row.moonbit_median_wall_us == Some(20000L))
  assert_true(txt_row.moonbit_engine_median_wall_us == Some(14000L))
  assert_true(txt_row.markitdown_median_wall_us == Some(110000L))
  assert_true(txt_row.speedup == Some(5.5))
  assert_true(txt_row.engine_speedup == Some(7.857142857142857))
  assert_true(txt_row.fixed_overhead_ms == Some(6L))
  assert_true(txt_row.fixed_overhead_us == Some(6000L))

  let txt_format = find_format_comparison(summary.comparison.by_format, "txt")
  assert_eq(txt_format.format, "txt")
  assert_true(txt_format.median_speedup == Some(5.5))
  assert_true(txt_format.engine_median_speedup == Some(7.857142857142857))
  assert_true(txt_format.median_fixed_overhead_ms == Some(6L))
  assert_true(txt_format.median_fixed_overhead_us == Some(6000L))
  assert_eq(txt_format.timing_precision, "wall_us")
  assert_eq(txt_format.status, "ok")
}

///|
test "summary prefers requested selector tier over first row enabled tier" {
  let selector_stats_path = summary_test_tmp_root() + "/selector-regular.json"
  ensure_summary_test_dir(summary_test_tmp_root())
  @fs.write_string_to_file(
    selector_stats_path,
    "{\"requested_tier\":\"regular\",\"selected_rows\":42,\"formats\":[\"txt\",\"txt\",\"txt\"],\"skipped_by_reason\":{\"tier_excluded\":22}}\n",
    encoding="utf8",
  ) catch {
    err => abort("failed to write selector stats fixture: " + err.to_string())
  }
  let summary = summarize_rows(summary_test_rows(), Some(selector_stats_path))
  assert_eq(summary.corpus.tier, "regular")
  assert_eq(summary.corpus.selected_rows, 42)
  assert_eq(summary.corpus.formats.length(), 3)
}

///|
test "summary markdown report includes speedup and hotspot sections" {
  let summary = summarize_rows(summary_test_rows(), None)
  let report = render_markdown_report(summary)
  assert_true(report.contains("runner mode"))
  assert_true(report.contains("canonical performance"))
  assert_true(report.contains("## Comparison Coverage"))
  assert_true(report.contains("## Speedup Summary"))
  assert_true(report.contains("## By Format"))
  assert_true(report.contains("## Fixed Overhead Summary"))
  assert_true(report.contains("## Lowest CLI Speedup Rows"))
  assert_true(report.contains("## Lowest Engine Speedup Rows"))
  assert_true(report.contains("## External Baseline Non-OK Rows"))
  assert_true(report.contains("## MoonBit Non-OK Rows"))
  assert_true(report.contains("## Slowest MoonBit Rows"))
  assert_true(report.contains("## Highest RSS Rows"))
  assert_true(report.contains("txt_small_alpha_v1"))
  assert_true(report.contains("5.5x"))
  assert_true(report.contains("30%"))
  assert_true(report.contains("partial_success"))
  assert_true(report.contains("20.000 ms (20000 us)"))
  assert_true(report.contains("timing precision"))
}

///|
test "summary warns when external baseline excludes otherwise successful MoonBit rows" {
  let rows = summary_test_rows().map(fn(row) {
    if row.bench_id == "html_medium_beta_v1" && row.tool == "moonbit-cli" {
      {
        ..row,
        status: "ok",
        exit_code: 0,
        timed_out: false,
        error: None,
        stderr_excerpt: "",
      }
    } else if row.bench_id == "html_medium_beta_v1" && row.tool == "markitdown" {
      {
        ..row,
        status: "failed",
        exit_code: 1,
        timed_out: false,
        error: Some("external failed"),
        stderr_excerpt: "external failed",
      }
    } else {
      row
    }
  })
  let summary = summarize_rows(rows, None)
  assert_true(
    summary.warnings.any(fn(line) {
      line.contains("External MarkItDown baseline has 1 non-ok bench row(s)")
    }),
  )
  assert_true(
    summary.warnings.any(fn(line) {
      line.contains("MoonBit CLI/engine remained ok for 1 row(s)")
    }),
  )
  let report = render_markdown_report(summary)
  assert_true(
    report.contains("MoonBit-only success rows excluded by external baseline"),
  )
  assert_true(report.contains("html_medium_beta_v1"))
}

///|
test "summary speedup and fixed overhead prefer wall_us over rounded wall_ms" {
  let rows = [
    summary_test_result(
      "moonbit-cli",
      "html_tiny_precision_v1",
      "html",
      "tiny",
      1L,
      wall_us=Some(1499L),
      repeat_index=0,
      repeat_count=1,
    ),
    summary_test_result(
      "moonbit-engine",
      "html_tiny_precision_v1",
      "html",
      "tiny",
      1L,
      wall_us=Some(1201L),
      repeat_index=0,
      repeat_count=1,
    ),
    summary_test_result(
      "markitdown",
      "html_tiny_precision_v1",
      "html",
      "tiny",
      1L,
      wall_us=Some(1602L),
      repeat_index=0,
      repeat_count=1,
      peak_rss_kb=300L,
    ),
  ]
  let summary = summarize_rows(rows, None)
  let row = find_bench_comparison(
    summary.comparison.rows,
    "html_tiny_precision_v1",
  )
  assert_optional_double_close(row.speedup, 1.0687124749833221)
  assert_optional_double_close(row.engine_speedup, 1.3338884263114072)
  assert_true(row.fixed_overhead_us == Some(298L))
  assert_true(row.fixed_overhead_ms == Some(0L))
  assert_optional_double_close(row.fixed_overhead_share, 0.19879919946631088)
  assert_eq(row.timing_precision, "wall_us")
}

///|
test "load_jsonl_results accepts wall_ms only rows and marks ms fallback" {
  let path = summary_test_tmp_root() + "/wall-ms-only.jsonl"
  write_summary_test_jsonl(path, [
    "{\"schema_version\":1,\"run_id\":\"run-old\",\"repo_commit\":\"deadbeef\",\"tool\":\"moonbit-cli\",\"tool_version\":\"moonbit-cli-v\",\"measurement_mode\":\"process-cli\",\"output_write_mode\":\"file\",\"bench_id\":\"txt_old_fixture_v1\",\"format\":\"txt\",\"size_class\":\"tiny\",\"enabled_tier\":\"smoke\",\"bench_layers\":\"product\",\"tags\":\"\",\"rel_path\":\"samples/bench/txt/txt_old_fixture_v1.txt\",\"input_bytes\":12,\"input_sha256\":\"sha\",\"command_kind\":\"cli-baseline\",\"command_display\":\"moonbit-cli <input>\",\"repeat_index\":0,\"repeat_count\":1,\"exit_code\":0,\"status\":\"ok\",\"timed_out\":false,\"wall_ms\":2,\"stdout_bytes\":0,\"stderr_bytes\":0,\"output_bytes\":4,\"stdout_excerpt\":\"\",\"stderr_excerpt\":\"\"}",
    "{\"schema_version\":1,\"run_id\":\"run-old\",\"repo_commit\":\"deadbeef\",\"tool\":\"markitdown\",\"tool_version\":\"markitdown-v\",\"measurement_mode\":\"process-cli\",\"output_write_mode\":\"file\",\"bench_id\":\"txt_old_fixture_v1\",\"format\":\"txt\",\"size_class\":\"tiny\",\"enabled_tier\":\"smoke\",\"bench_layers\":\"external\",\"tags\":\"\",\"rel_path\":\"samples/bench/txt/txt_old_fixture_v1.txt\",\"input_bytes\":12,\"input_sha256\":\"sha\",\"command_kind\":\"cli-baseline\",\"command_display\":\"markitdown <input>\",\"repeat_index\":0,\"repeat_count\":1,\"exit_code\":0,\"status\":\"ok\",\"timed_out\":false,\"wall_ms\":6,\"stdout_bytes\":0,\"stderr_bytes\":0,\"output_bytes\":4,\"stdout_excerpt\":\"\",\"stderr_excerpt\":\"\"}",
  ])
  let rows = load_jsonl_results(path)
  assert_eq(rows.length(), 2)
  assert_true(rows[0].wall_us == None)
  let summary = summarize_rows(rows, None)
  assert_eq(summary.comparison.timing_precision, "ms_fallback")
  assert_eq(summary.environment.runner_mode, "unknown")
  assert_true(!summary.environment.canonical_performance)
  assert_true(summary.warnings.length() >= 1)
  let row = find_bench_comparison(summary.comparison.rows, "txt_old_fixture_v1")
  assert_true(row.speedup == Some(3.0))
  assert_true(row.fixed_overhead_us == None)
  assert_eq(row.timing_precision, "ms_fallback")
}

///|
test "summary warns when runner mode is dev moon run" {
  let rows = summary_test_rows().map(fn(row) {
    {
      ..row,
      runner_mode: Some("dev_moon_run"),
      canonical_performance: Some(false),
    }
  })
  let summary = summarize_rows(rows, None)
  assert_eq(summary.environment.runner_mode, "dev_moon_run")
  assert_true(!summary.environment.canonical_performance)
  assert_true(summary.warnings.length() >= 2)
  let report = render_markdown_report(summary)
  assert_true(report.contains("## Warnings"))
  assert_true(report.contains("not marked as release runner mode"))
  assert_true(
    report.contains("In-process engine timing under moon run/dev mode"),
  )
}

///|
test "summary keeps per-tool output modes in tool summary" {
  let rows = [
    {
      ..summary_test_result(
        "moonbit-cli",
        "txt_stdout_mode_v1",
        "txt",
        "tiny",
        3L,
        repeat_count=1,
      ),
      output_write_mode: Some("stdout_capture"),
    },
    {
      ..summary_test_result(
        "moonbit-engine",
        "txt_stdout_mode_v1",
        "txt",
        "tiny",
        2L,
        repeat_count=1,
      ),
      output_write_mode: Some("memory"),
    },
    summary_test_result(
      "markitdown",
      "txt_stdout_mode_v1",
      "txt",
      "tiny",
      9L,
      repeat_count=1,
    ),
  ]
  let summary = summarize_rows(rows, None)
  assert_true(
    summary.tools.get("moonbit-cli").unwrap().output_write_mode ==
    Some("stdout_capture"),
  )
  assert_true(
    summary.tools.get("moonbit-engine").unwrap().output_write_mode ==
    Some("memory"),
  )
}

///|
test "summary report explains diagnostic engine output modes" {
  let report = render_markdown_report(summarize_rows(summary_test_rows(), None))
  assert_true(
    report.contains(
      "CLI canonical rows include the selected real output behavior",
    ),
  )
  assert_true(
    report.contains(
      "Engine `memory` and `none` rows are diagnostic attribution modes only",
    ),
  )
  assert_true(report.contains("Engine `none` still renders Markdown"))
}

///|
test "summary warns about diagnostic output modes when present" {
  let rows = [
    {
      ..summary_test_result(
        "moonbit-cli",
        "txt_diag_modes_v1",
        "txt",
        "tiny",
        3L,
        repeat_count=1,
      ),
      output_write_mode: Some("stdout_capture"),
    },
    {
      ..summary_test_result(
        "moonbit-engine",
        "txt_diag_modes_v1",
        "txt",
        "tiny",
        2L,
        repeat_count=1,
      ),
      output_write_mode: Some("none"),
    },
    summary_test_result(
      "markitdown",
      "txt_diag_modes_v1",
      "txt",
      "tiny",
      9L,
      repeat_count=1,
    ),
  ]
  let summary = summarize_rows(rows, None)
  assert_true(
    summary.warnings.any(fn(line) {
      line.contains("Engine `none` output mode is diagnostic-only")
    }),
  )
  assert_true(
    summary.warnings.any(fn(line) {
      line.contains("CLI `stdout_capture` rows are attribution runs")
    }),
  )
}
