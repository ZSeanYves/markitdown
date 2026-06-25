///|
test "parse run request captures markitdown path" {
  let request = parse_run_request([
    "--tool", "markitdown", "--tier", "smoke", "--limit", "3", "--markitdown-path",
    "/tmp/markitdown-bin",
  ]) catch {
    err => fail("expected request to parse: " + err.to_string())
  }
  assert_eq(request.tool_name, "markitdown")
  assert_eq(request.tier, "smoke")
  assert_true(request.limit == Some(3))
  assert_true(request.markitdown_path == Some("/tmp/markitdown-bin"))
  assert_eq(cli_output_mode_name(request.cli_output_mode), "file")
  assert_eq(engine_output_mode_name(request.engine_output_mode), "file")
  assert_eq(request.timeout_ms, 60000)
  assert_eq(request.runner.runner_mode, "unknown")
  assert_true(!request.runner.canonical_performance)
}

///|
test "output path helpers use .tmp bench run scoped roots" {
  let run_id = "run-123"
  assert_eq(run_root(run_id), ".tmp/bench/runs/run-123")
  assert_eq(results_root(run_id), ".tmp/bench/runs/run-123/results")
  assert_eq(reports_root(run_id), ".tmp/bench/runs/run-123/reports")
  assert_eq(outputs_root(run_id), ".tmp/bench/runs/run-123/outputs")
  assert_eq(
    result_jsonl_path(run_id, "moonbit-cli", "smoke"),
    ".tmp/bench/runs/run-123/results/run-123-moonbit-cli-smoke.jsonl",
  )
  assert_eq(
    summary_json_path(run_id),
    ".tmp/bench/runs/run-123/results/run-123-summary.json",
  )
  assert_eq(
    report_markdown_path(run_id),
    ".tmp/bench/runs/run-123/reports/run-123.md",
  )
  assert_eq(
    selector_stats_path(run_id),
    ".tmp/bench/runs/run-123/results/run-123-selector-stats.json",
  )
  assert_eq(
    overhead_result_jsonl_path(run_id),
    ".tmp/bench/runs/run-123/results/run-123-overhead.jsonl",
  )
  assert_eq(
    overhead_report_markdown_path(run_id),
    ".tmp/bench/runs/run-123/reports/run-123-overhead.md",
  )
  assert_eq(
    tool_output_root(run_id, "moonbit-cli"),
    ".tmp/bench/runs/run-123/outputs/moonbit-cli",
  )
  assert_eq(
    output_markdown_path(run_id, "moonbit-cli", "txt_tiny_plain_v1", 0, 1),
    ".tmp/bench/runs/run-123/outputs/moonbit-cli/txt_tiny_plain_v1.md",
  )
  assert_eq(
    output_markdown_path(run_id, "moonbit-cli", "txt_tiny_plain_v1", 1, 3),
    ".tmp/bench/runs/run-123/outputs/moonbit-cli/txt_tiny_plain_v1-repeat-2.md",
  )
}

///|
test "parse compare request captures markitdown path" {
  let request = parse_compare_request([
    "--tier", "smoke", "--limit", "2", "--markitdown-path", "/tmp/markitdown-bin",
  ]) catch {
    err => fail("expected compare request to parse: " + err.to_string())
  }
  assert_eq(request.tier, "smoke")
  assert_true(request.limit == Some(2))
  assert_true(request.markitdown_path == Some("/tmp/markitdown-bin"))
  assert_eq(cli_output_mode_name(request.cli_output_mode), "file")
  assert_eq(engine_output_mode_name(request.engine_output_mode), "file")
  assert_eq(request.timeout_ms, 60000)
  assert_eq(request.runner.runner_mode, "unknown")
}

///|
test "parse run request captures repeat count" {
  let request = parse_run_request(["--tool", "moonbit-cli", "--repeat", "3"]) catch {
    err => fail("expected request to parse: " + err.to_string())
  }
  assert_eq(request.repeat_count, 3)
}

///|
test "parse diagnose request defaults to twenty repeats" {
  let request = parse_diagnose_request([]) catch {
    err => fail("expected diagnose request to parse: " + err.to_string())
  }
  assert_eq(request.repeat_count, 20)
  assert_eq(request.timeout_ms, 60000)
  assert_eq(request.runner.runner_mode, "unknown")
}

///|
test "parse diagnose request accepts timeout ms alias" {
  let request = parse_diagnose_request(["--repeat", "7", "--timeout-ms", "1234"]) catch {
    err => fail("expected diagnose request to parse: " + err.to_string())
  }
  assert_eq(request.repeat_count, 7)
  assert_eq(request.timeout_ms, 1234)
}

///|
test "parse compare request defaults repeat count to one" {
  let request = parse_compare_request(["--tier", "smoke"]) catch {
    err => fail("expected compare request to parse: " + err.to_string())
  }
  assert_eq(request.repeat_count, 1)
}

///|
test "detect runner context recognizes moon run dev mode" {
  let context = detect_runner_context([
    "_build/native/debug/build/bench/runner/runner.exe", "bench/runner", "compare",
  ])
  assert_eq(context.runner_mode, "dev_moon_run")
  assert_true(!context.canonical_performance)
  assert_true(
    context.runner_path ==
    Some("_build/native/debug/build/bench/runner/runner.exe"),
  )
}

///|
test "detect runner context recognizes release runner path" {
  let context = detect_runner_context([
    "_build/native/release/build/bench/runner/runner.exe", "compare",
  ])
  assert_eq(context.runner_mode, "release")
  assert_true(context.canonical_performance)
  assert_true(
    context.runner_path ==
    Some("_build/native/release/build/bench/runner/runner.exe"),
  )
}

///|
test "parse run request keeps explicit runner context" {
  let context = make_runner_context(
    "release",
    Some("_build/native/release/build/bench/runner/runner.exe"),
  )
  let request = parse_run_request_with_context(
    ["--tool", "moonbit-cli", "--repeat", "2"],
    context,
  ) catch {
    err => fail("expected request to parse: " + err.to_string())
  }
  assert_eq(request.runner.runner_mode, "release")
  assert_true(request.runner.canonical_performance)
  assert_true(request.runner.runner_path == context.runner_path)
}

///|
test "parse compare request accepts common flags and keeps explicit runner context" {
  let context = make_runner_context(
    "release",
    Some("_build/native/release/build/bench/runner/runner.exe"),
  )
  let request = parse_compare_request_with_context(
    [
      "--tier", "smoke", "--format", "html", "--limit", "5", "--repeat", "4", "--timeout-sec",
      "60", "--markitdown-path", "/tmp/markitdown-bin",
    ],
    context,
  ) catch {
    err => fail("expected compare request to parse: " + err.to_string())
  }
  assert_eq(request.tier, "smoke")
  assert_true(request.format_filter == Some("html"))
  assert_true(request.limit == Some(5))
  assert_eq(request.repeat_count, 4)
  assert_eq(request.timeout_ms, 60000)
  assert_true(request.markitdown_path == Some("/tmp/markitdown-bin"))
  assert_eq(cli_output_mode_name(request.cli_output_mode), "file")
  assert_eq(engine_output_mode_name(request.engine_output_mode), "file")
  assert_eq(request.runner.runner_mode, "release")
  assert_true(request.runner.canonical_performance)
  assert_true(request.runner.runner_path == context.runner_path)
}

///|
test "parse diagnose request keeps explicit runner context" {
  let context = make_runner_context(
    "release",
    Some("_build/native/release/build/bench/runner/runner.exe"),
  )
  let request = parse_diagnose_request_with_context(
    ["--repeat", "8", "--timeout-ms", "4321"],
    context,
  ) catch {
    err => fail("expected diagnose request to parse: " + err.to_string())
  }
  assert_eq(request.repeat_count, 8)
  assert_eq(request.timeout_ms, 4321)
  assert_eq(cli_output_mode_name(request.cli_output_mode), "file")
  assert_eq(engine_output_mode_name(request.engine_output_mode), "file")
  assert_eq(request.runner.runner_mode, "release")
  assert_true(request.runner.canonical_performance)
  assert_true(request.runner.runner_path == context.runner_path)
}

///|
test "parse run request rejects zero repeat count" {
  let parsed = try
    parse_run_request(["--tool", "moonbit-cli", "--repeat", "0"]) |> Ok
  catch {
    err => Err(err.to_string())
  }
  match parsed {
    Ok(_) => fail("expected zero repeat count to be rejected")
    Err(message) =>
      assert_true(
        message.contains("non-positive integer is not allowed for --repeat"),
      )
  }
}

///|
test "parse run request rejects empty markitdown path" {
  let parsed = try
    parse_run_request(["--tool", "markitdown", "--markitdown-path", "   "])
    |> Ok
  catch {
    err => Err(err.to_string())
  }
  match parsed {
    Ok(_) => fail("expected empty markitdown path to be rejected")
    Err(message) =>
      assert_true(
        message.contains("empty value is not allowed for --markitdown-path"),
      )
  }
}

///|
test "parse run request accepts timeout ms" {
  let request = parse_run_request([
    "--tool", "moonbit-cli", "--timeout-ms", "1234",
  ]) catch {
    err => fail("expected timeout-ms request to parse: " + err.to_string())
  }
  assert_eq(request.timeout_ms, 1234)
}

///|
test "parse run request accepts timeout sec alias" {
  let request = parse_run_request([
    "--tool", "moonbit-cli", "--timeout-sec", "60",
  ]) catch {
    err => fail("expected timeout-sec request to parse: " + err.to_string())
  }
  assert_eq(request.timeout_ms, 60000)
}

///|
test "parse run request rejects mixed timeout flags" {
  let parsed = try
    parse_run_request([
      "--tool", "moonbit-cli", "--timeout-sec", "60", "--timeout-ms", "60000",
    ])
    |> Ok
  catch {
    err => Err(err.to_string())
  }
  match parsed {
    Ok(_) => fail("expected mixed timeout flags to be rejected")
    Err(message) =>
      assert_true(
        message.contains("cannot use --timeout-sec and --timeout-ms together"),
      )
  }
}

///|
test "parse diagnose request rejects mixed timeout flags" {
  let parsed = try
    parse_diagnose_request(["--timeout-sec", "60", "--timeout-ms", "60000"])
    |> Ok
  catch {
    err => Err(err.to_string())
  }
  match parsed {
    Ok(_) => fail("expected mixed diagnose timeout flags to be rejected")
    Err(message) =>
      assert_true(
        message.contains("cannot use --timeout-sec and --timeout-ms together"),
      )
  }
}

///|
test "parse run request accepts explicit output modes" {
  let request = parse_run_request([
    "--tool", "moonbit-engine", "--cli-output-mode", "stdout_capture", "--engine-output-mode",
    "memory",
  ]) catch {
    err => fail("expected output mode request to parse: " + err.to_string())
  }
  assert_eq(cli_output_mode_name(request.cli_output_mode), "stdout_capture")
  assert_eq(engine_output_mode_name(request.engine_output_mode), "memory")
}

///|
test "parse compare request accepts explicit output modes" {
  let request = parse_compare_request([
    "--tier", "smoke", "--cli-output-mode", "stdout_capture", "--engine-output-mode",
    "none",
  ]) catch {
    err => fail("expected compare output modes to parse: " + err.to_string())
  }
  assert_eq(cli_output_mode_name(request.cli_output_mode), "stdout_capture")
  assert_eq(engine_output_mode_name(request.engine_output_mode), "none")
}

///|
test "parse run request rejects unsupported cli output mode" {
  let parsed = try
    parse_run_request(["--tool", "moonbit-cli", "--cli-output-mode", "stdout"])
    |> Ok
  catch {
    err => Err(err.to_string())
  }
  match parsed {
    Ok(_) => fail("expected unsupported cli output mode to be rejected")
    Err(message) =>
      assert_true(
        message.contains(
          "unsupported --cli-output-mode value: stdout (expected file|stdout_capture)",
        ),
      )
  }
}

///|
test "parse run request rejects unsupported engine output mode" {
  let parsed = try
    parse_run_request([
      "--tool", "moonbit-engine", "--engine-output-mode", "discard",
    ])
    |> Ok
  catch {
    err => Err(err.to_string())
  }
  match parsed {
    Ok(_) => fail("expected unsupported engine output mode to be rejected")
    Err(message) =>
      assert_true(
        message.contains(
          "unsupported --engine-output-mode value: discard (expected file|memory|none)",
        ),
      )
  }
}
