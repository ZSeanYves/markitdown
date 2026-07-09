///|
fn aggregate_cases(
  run_id : String,
  samples : Array[SampleRow],
  scenarios : Array[ScenarioSpec],
  policy : BenchPolicy,
) -> Array[CaseAggregate] {
  let scenario_map = scenario_map(scenarios)
  let groups : Map[String, Array[SampleRow]] = {}
  for sample in samples {
    let key = sample.scenario_id + "|" + sample.tool + "|" + sample.bench_id
    groups[key] = match groups.get(key) {
      Some(existing) => {
        let next = existing.copy()
        next.push(sample)
        next
      }
      None => [sample]
    }
  }
  let out : Array[CaseAggregate] = []
  for entry in groups {
    let rows = entry.1
    let first = rows[0]
    let ok_rows = rows.filter(item => item.status == "ok")
    let walls = ok_rows.map(item => item.wall_us.unwrap_or(0L))
    walls.sort()
    let output_values = ok_rows.map(item => item.output_bytes)
    output_values.sort()
    let scenario = scenario_map
      .get(first.scenario_id)
      .unwrap_or_else(fn() {
        abort("missing scenario metadata for " + first.scenario_id)
      })
    let expected_route = expected_route_for_case(first, scenario, policy)
    let actual_route = actual_route_name(first.route_provenance)
    let route_fidelity_status = route_fidelity_status(first.route_provenance)
    let provenance_complete = route_provenance_complete(first.route_provenance)
    let median_output = median_sorted_int64(output_values)
    let density = output_density(median_output, first.input_bytes)
    let semantic_coverage = semantic_coverage(first, median_output, density)
    let coverage_status = route_coverage_status(
      first.tool,
      first.route_provenance,
      expected_route,
      actual_route,
    )
    out.push({
      schema_version: 2,
      run_id,
      scenario_id: first.scenario_id,
      tool: first.tool,
      bench_id: first.bench_id,
      format: first.format,
      size_class: first.size_class,
      input_bytes: first.input_bytes,
      sample_count: rows.length(),
      success_count: ok_rows.length(),
      median_wall_us: median_sorted_int64(walls),
      min_wall_us: first_sorted_int64(walls),
      max_wall_us: last_sorted_int64(walls),
      median_output_bytes: median_output,
      output_density: density,
      comparable_status: if ok_rows.length() == rows.length() {
        "comparable"
      } else if ok_rows.length() == 0 {
        "non_ok"
      } else {
        "partial"
      },
      route_coverage_status: coverage_status,
      semantic_coverage,
      render_path: render_path(first.route_provenance),
      trust_status: case_trust_status(
        first.tool,
        coverage_status,
        semantic_coverage,
        route_fidelity_status,
        provenance_complete,
      ),
      trust_failure_reason: case_trust_failure_reason(
        first.tool,
        coverage_status,
        semantic_coverage,
        route_fidelity_status,
        provenance_complete,
      ),
      expected_route,
      actual_route,
      route_fidelity_status,
      provenance_complete,
      route_provenance: first.route_provenance,
    })
  }
  out
}

///|
fn summarize_run(
  run_id : String,
  scenarios : Array[ScenarioSpec],
  samples : Array[SampleRow],
  cases : Array[CaseAggregate],
  contract : BinaryContract,
  preset : String?,
  baseline_run_id : String?,
) -> RunSummary {
  ignore(samples)
  let scenario_summaries = summarize_scenarios(scenarios, cases)
  {
    schema_version: 2,
    run_id,
    preset,
    scenario_ids: scenarios.map(item => item.scenario_id),
    binary_only_contract: Json::object({
      "runner_path": contract.runner_path.to_json(),
      "cli_path": contract.cli_path.to_json(),
      "runner_release_ok": contract.runner_release_ok.to_json(),
      "cli_release_ok": contract.cli_release_ok.to_json(),
      "used_moon_delegate": contract.used_moon_delegate.to_json(),
    }),
    trust_status: if cases
      .filter(item => item.trust_status == "failed")
      .length() ==
      0 {
      "trusted"
    } else {
      "failed"
    },
    gate_summary: Json::object({
      "selected_rows": bench_row_count(cases).to_json(),
      "comparable_rows": comparable_row_count(cases).to_json(),
      "status": gate_status(cases).to_json(),
    }),
    route_coverage_summary: Json::object({
      "covered_cases": cases
      .filter(item => item.route_coverage_status == "covered")
      .length()
      .to_json(),
      "mismatch_cases": cases
      .filter(item => item.route_coverage_status == "mismatch")
      .length()
      .to_json(),
      "missing_cases": cases
      .filter(item => item.route_coverage_status == "missing")
      .length()
      .to_json(),
      "not_applicable_cases": cases
      .filter(item => item.route_coverage_status == "not_applicable")
      .length()
      .to_json(),
    }),
    truth_summary: Json::object({
      "trusted_cases": cases
      .filter(item => item.trust_status == "trusted")
      .length()
      .to_json(),
      "failed_cases": cases
      .filter(item => item.trust_status == "failed")
      .length()
      .to_json(),
      "low_density_cases": cases
      .filter(item => item.semantic_coverage == "low_density_untrusted")
      .length()
      .to_json(),
      "missing_provenance_cases": cases
      .filter(item => item.trust_failure_reason == "missing_provenance")
      .length()
      .to_json(),
      "route_mismatch_cases": cases
      .filter(item => item.trust_failure_reason == "route_mismatch")
      .length()
      .to_json(),
      "fidelity_mismatch_cases": cases
      .filter(item => item.trust_failure_reason == "fidelity_mismatch")
      .length()
      .to_json(),
    }),
    diff_summary: baseline_run_id.map(id => {
      Json::object({ "baseline_run_id": id.to_json() })
    }),
    scenarios: scenario_summaries,
    tools: summarize_tools(cases),
    by_format: summarize_formats(cases),
  }
}

///|
fn summarize_doctor_run(
  run_id : String,
  scenario : ScenarioSpec,
  opts : RunOptions,
  contract : BinaryContract,
) -> RunSummary {
  ignore(opts)
  {
    schema_version: 2,
    run_id,
    preset: Some("doctor"),
    scenario_ids: [scenario.scenario_id],
    binary_only_contract: Json::object({
      "runner_path": contract.runner_path.to_json(),
      "cli_path": contract.cli_path.to_json(),
      "runner_release_ok": contract.runner_release_ok.to_json(),
      "cli_release_ok": contract.cli_release_ok.to_json(),
      "used_moon_delegate": contract.used_moon_delegate.to_json(),
    }),
    trust_status: "trusted",
    gate_summary: Json::object({ "status": "ok".to_json() }),
    route_coverage_summary: Json::object({
      "status": "not_applicable".to_json(),
    }),
    truth_summary: Json::object({ "status": "not_applicable".to_json() }),
    diff_summary: None,
    scenarios: [
      {
        scenario_id: scenario.scenario_id,
        scenario_kind: scenario.scenario_kind,
        official_membership: scenario.official_membership,
        selected_rows: 0,
        comparable_rows: 0,
        trust_status: "trusted",
        gate_status: "ok",
      },
    ],
    tools: [],
    by_format: [],
  }
}

///|
fn summarize_scenarios(
  scenarios : Array[ScenarioSpec],
  cases : Array[CaseAggregate],
) -> Array[ScenarioSummary] {
  let out : Array[ScenarioSummary] = []
  for scenario in scenarios {
    let scenario_cases = cases.filter(item => {
      item.scenario_id == scenario.scenario_id
    })
    out.push({
      scenario_id: scenario.scenario_id,
      scenario_kind: scenario.scenario_kind,
      official_membership: scenario.official_membership,
      selected_rows: bench_row_count(scenario_cases),
      comparable_rows: comparable_row_count(scenario_cases),
      trust_status: if scenario_cases
        .filter(item => item.trust_status == "failed")
        .length() ==
        0 {
        "trusted"
      } else {
        "failed"
      },
      gate_status: gate_status(scenario_cases),
    })
  }
  out
}

///|
fn summarize_tools(cases : Array[CaseAggregate]) -> Array[ToolSummary] {
  let groups : Map[String, Array[CaseAggregate]] = {}
  for case_ in cases {
    groups[case_.tool] = match groups.get(case_.tool) {
      Some(existing) => {
        let next = existing.copy()
        next.push(case_)
        next
      }
      None => [case_]
    }
  }
  let out : Array[ToolSummary] = []
  for entry in groups {
    let medians = entry.1
      .map(item => item.median_wall_us.unwrap_or(0L))
      .filter(value => value > 0L)
    medians.sort()
    out.push({
      tool: entry.0,
      rows: entry.1.length(),
      success_rows: entry.1.filter(item => item.success_count > 0).length(),
      median_wall_us: median_sorted_int64(medians),
    })
  }
  out
}

///|
fn summarize_formats(cases : Array[CaseAggregate]) -> Array[FormatSummary] {
  let groups : Map[String, Array[CaseAggregate]] = {}
  for case_ in cases {
    groups[case_.format] = match groups.get(case_.format) {
      Some(existing) => {
        let next = existing.copy()
        next.push(case_)
        next
      }
      None => [case_]
    }
  }
  let out : Array[FormatSummary] = []
  for entry in groups {
    let speedups = speedups_for_format(entry.1, "moonbit-cli")
    let engine_speedups = speedups_for_format(entry.1, "moonbit-engine")
    let rows = bench_rows_for_format(entry.1)
    let comparable_rows = comparable_rows_for_format(entry.1)
    out.push({
      format: entry.0,
      rows,
      comparable_rows,
      cli_geomean_speedup: geomean_speedup(speedups),
      engine_geomean_speedup: geomean_speedup(engine_speedups),
      status: if comparable_rows == rows {
        "ok"
      } else if comparable_rows == 0 {
        "non_comparable"
      } else {
        "partial"
      },
    })
  }
  out
}

///|
fn speedups_for_format(
  cases : Array[CaseAggregate],
  tool_name : String,
) -> Array[Double] {
  let out : Array[Double] = []
  let markitdown = cases.filter(item => item.tool == "markitdown")
  let tool_rows = cases.filter(item => item.tool == tool_name)
  for left in tool_rows {
    for right in markitdown {
      if left.bench_id == right.bench_id &&
        left.median_wall_us is Some(lhs) &&
        right.median_wall_us is Some(rhs) &&
        lhs > 0L {
        out.push(rhs.to_double() / lhs.to_double())
      }
    }
  }
  out
}

///|
fn bench_row_count(cases : Array[CaseAggregate]) -> Int {
  let keys : Array[String] = []
  for case_ in cases {
    let key = case_.scenario_id + "|" + case_.bench_id
    if !keys.contains(key) {
      keys.push(key)
    }
  }
  keys.length()
}

///|
fn comparable_row_count(cases : Array[CaseAggregate]) -> Int {
  let grouped : Map[String, Bool] = {}
  for case_ in cases {
    let key = case_.scenario_id + "|" + case_.bench_id
    let ok = case_.comparable_status == "comparable"
    grouped[key] = match grouped.get(key) {
      Some(existing) => existing && ok
      None => ok
    }
  }
  grouped.values().filter(item => item).length()
}

///|
fn gate_status(cases : Array[CaseAggregate]) -> String {
  let selected = bench_row_count(cases)
  let comparable = comparable_row_count(cases)
  if comparable == selected {
    "ok"
  } else if comparable == 0 {
    "failed"
  } else {
    "partial"
  }
}

///|
fn bench_rows_for_format(cases : Array[CaseAggregate]) -> Int {
  let keys : Array[String] = []
  for case_ in cases {
    let key = case_.bench_id + "|" + case_.format
    if !keys.contains(key) {
      keys.push(key)
    }
  }
  keys.length()
}

///|
fn comparable_rows_for_format(cases : Array[CaseAggregate]) -> Int {
  let grouped : Map[String, Bool] = {}
  for case_ in cases {
    let key = case_.bench_id + "|" + case_.format
    let ok = case_.comparable_status == "comparable"
    grouped[key] = match grouped.get(key) {
      Some(existing) => existing && ok
      None => ok
    }
  }
  grouped.values().filter(item => item).length()
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
fn first_sorted_int64(values : Array[Int64]) -> Int64? {
  if values.length() == 0 {
    None
  } else {
    Some(values[0])
  }
}

///|
fn last_sorted_int64(values : Array[Int64]) -> Int64? {
  if values.length() == 0 {
    None
  } else {
    Some(values[values.length() - 1])
  }
}

///|
fn geomean_speedup(values : Array[Double]) -> Double? {
  if values.length() == 0 {
    return None
  }
  let positive = values.filter(item => item > 0.0)
  if positive.length() == 0 {
    return None
  }
  let total_ln = positive.fold(init=0.0, fn(acc, value) {
    acc + @math.ln(value)
  })
  Some(@math.exp(total_ln / positive.length().to_double()))
}
