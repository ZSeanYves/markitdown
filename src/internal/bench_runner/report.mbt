///|
fn regenerate_report(
  run_id : String,
  baseline_run_id : String?,
) -> Result[RunSummary, BenchError] {
  let policy = match load_policy() {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let samples = match load_sample_rows(samples_jsonl_path(run_id), "sample") {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let run_scenarios = scenario_specs_for_run(samples, policy)
  let cases = aggregate_cases(run_id, samples, run_scenarios, policy)
  write_jsonl(cases_jsonl_path(run_id), cases.map(item => item.to_json())) catch {
    err =>
      return Err(RuntimeFailure("rewrite cases failed: " + err.to_string()))
  }
  let previous = match load_summary(run_id) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let contract = match
    binary_contract_from_summary(previous.binary_only_contract) {
    Ok(value) => value
    Err(err) => return Err(err)
  }
  let baseline = match baseline_run_id {
    Some(value) => Some(value)
    None =>
      previous.diff_summary.bind(fn(diff) {
        json_optional_string_field(diff, "baseline_run_id")
      })
  }
  let next = summarize_run(
    run_id,
    run_scenarios,
    samples,
    cases,
    contract,
    previous.preset,
    baseline,
    policy,
    resource_summary=previous.resource_summary,
    resume_summary=previous.resume_summary,
  )
  write_summary_and_report(run_id, next) catch {
    err =>
      return Err(RuntimeFailure("rewrite report failed: " + err.to_string()))
  }
  Ok(next)
}

///|
fn write_summary_and_report(
  run_id : String,
  summary : RunSummary,
) -> Unit raise {
  @fs.write_string_to_file(
    summary_json_path(run_id),
    summary.to_json().stringify(indent=2) + "\n",
    encoding="utf8",
  )
  @fs.write_string_to_file(
    report_markdown_path(run_id),
    render_markdown_report(summary),
    encoding="utf8",
  )
}

///|
fn render_markdown_report(summary : RunSummary) -> String {
  let lines : Array[String] = [
    "# Bench Report",
    "",
    "- run_id: `" + summary.run_id + "`",
    "- preset: `" + summary.preset.unwrap_or("n/a") + "`",
    "- scenarios: `" + summary.scenario_ids.join(", ") + "`",
    "- trust_status: `" + summary.trust_status + "`",
    "- gate_status: `" + json_string_field(summary.gate_summary, "status") + "`",
    "",
    "## Scenarios",
  ]
  for scenario in summary.scenarios {
    lines.push(
      "- `" +
      scenario.scenario_id +
      "` selected=`" +
      scenario.selected_rows.to_string() +
      "` comparable=`" +
      scenario.comparable_rows.to_string() +
      "` trust=`" +
      scenario.trust_status +
      "` gate=`" +
      scenario.gate_status +
      "`",
    )
  }
  lines.push("")
  lines.push("## Tools")
  for tool in summary.tools {
    lines.push(
      "- `" +
      tool.tool +
      "` rows=`" +
      tool.rows.to_string() +
      "` success=`" +
      tool.success_rows.to_string() +
      "` median_wall_us=`" +
      tool.median_wall_us.map(v => v.to_string()).unwrap_or("n/a") +
      "`",
    )
  }
  lines.push("")
  lines.push("## Performance Gate")
  match summary.gate_summary {
    Object(gate) =>
      match gate.get("performance") {
        Some(performance) => lines.push("- `" + performance.stringify() + "`")
        None => lines.push("- `not_available`")
      }
    _ => lines.push("- `not_available`")
  }
  lines.push("")
  lines.push("## Route Coverage")
  lines.push(
    "- covered_cases=`" +
    json_int_field(summary.route_coverage_summary, "covered_cases").to_string() +
    "` mismatch_cases=`" +
    json_int_field(summary.route_coverage_summary, "mismatch_cases").to_string() +
    "` missing_cases=`" +
    json_int_field(summary.route_coverage_summary, "missing_cases").to_string() +
    "` not_applicable_cases=`" +
    json_int_field(summary.route_coverage_summary, "not_applicable_cases").to_string() +
    "`",
  )
  lines.push("")
  lines.push("## Truth Guard")
  lines.push(
    "- trusted_cases=`" +
    json_int_field(summary.truth_summary, "trusted_cases").to_string() +
    "` failed_cases=`" +
    json_int_field(summary.truth_summary, "failed_cases").to_string() +
    "` low_density_cases=`" +
    json_int_field(summary.truth_summary, "low_density_cases").to_string() +
    "` missing_provenance_cases=`" +
    json_int_field(summary.truth_summary, "missing_provenance_cases").to_string() +
    "` route_mismatch_cases=`" +
    json_int_field(summary.truth_summary, "route_mismatch_cases").to_string() +
    "` fidelity_mismatch_cases=`" +
    json_int_field(summary.truth_summary, "fidelity_mismatch_cases").to_string() +
    "`",
  )
  lines.push("")
  lines.push("## By Format")
  for row in summary.by_format {
    lines.push(
      "- `" +
      row.format +
      "` comparable=`" +
      row.comparable_rows.to_string() +
      "/" +
      row.rows.to_string() +
      "` cli_geomean=`" +
      format_optional_speedup(row.cli_geomean_speedup) +
      "` engine_geomean=`" +
      format_optional_speedup(row.engine_geomean_speedup) +
      "` status=`" +
      row.status +
      "`",
    )
  }
  match summary.resource_summary {
    Some(resource) => {
      lines.push("")
      lines.push("## Resources")
      lines.push("- `" + resource.stringify() + "`")
    }
    None => ()
  }
  match summary.resume_summary {
    Some(resume_info) => {
      lines.push("")
      lines.push("## Resume")
      lines.push("- `" + resume_info.stringify() + "`")
    }
    None => ()
  }
  lines.join("\n") + "\n"
}

///|
fn format_optional_speedup(value : Double?) -> String {
  match value {
    Some(v) => v.to_string() + "x"
    None => "n/a"
  }
}

///|
fn measurement_policy(opts : RunOptions) -> String {
  "warmup=" +
  opts.warmup_count.to_string() +
  ";samples=" +
  opts.repeat_count.to_string() +
  ";order=row_major_interleaved"
}

///|
fn load_summary(run_id : String) -> Result[RunSummary, BenchError] {
  let content = @fs.read_file_to_string(
    summary_json_path(run_id),
    encoding="utf8",
  ) catch {
    err => return Err(RuntimeFailure("read summary failed: " + err.to_string()))
  }
  let json = @json.parse(content) catch {
    err =>
      return Err(RuntimeFailure("parse summary failed: " + err.to_string()))
  }
  let summary = (@json.from_json(json) : RunSummary) catch {
    err =>
      return Err(RuntimeFailure("decode summary failed: " + err.to_string()))
  }
  Ok(summary)
}

///|
fn binary_contract_from_summary(
  json : Json,
) -> Result[BinaryContract, BenchError] {
  match json {
    Object(map) => {
      let runner_path = json_string_required_from_json(
        map, "runner_path", "binary_only_contract",
      )
      let cli_path = json_string_required_from_json(
        map, "cli_path", "binary_only_contract",
      )
      let runner_release_ok = json_bool_required_from_json(
        map, "runner_release_ok", "binary_only_contract",
      )
      let cli_release_ok = json_bool_required_from_json(
        map, "cli_release_ok", "binary_only_contract",
      )
      let used_moon_delegate = json_bool_required_from_json(
        map, "used_moon_delegate", "binary_only_contract",
      )
      Ok({
        runner_path,
        cli_path,
        runner_release_ok,
        cli_release_ok,
        used_moon_delegate,
      })
    }
    _ =>
      Err(
        RuntimeFailure("binary_only_contract must decode from summary object"),
      )
  }
}

///|
fn load_sample_rows(
  path : String,
  label : String,
) -> Result[Array[SampleRow], BenchError] {
  let content = @fs.read_file_to_string(path, encoding="utf8") catch {
    err =>
      return Err(
        RuntimeFailure("read " + label + " jsonl failed: " + err.to_string()),
      )
  }
  let out : Array[SampleRow] = []
  for line in content.split("\n") {
    let trimmed = line.trim().to_owned()
    if trimmed == "" {
      continue
    }
    let json = @json.parse(trimmed) catch {
      err =>
        return Err(
          RuntimeFailure(
            "parse " + label + " jsonl row failed: " + err.to_string(),
          ),
        )
    }
    let row = (@json.from_json(json) : SampleRow) catch {
      err =>
        return Err(
          RuntimeFailure(
            "decode " + label + " jsonl row failed: " + err.to_string(),
          ),
        )
    }
    out.push(row)
  }
  Ok(out)
}

///|
fn json_optional_string_field(json : Json, key : String) -> String? {
  match json {
    Object(map) =>
      match map.get(key) {
        Some(String(value)) => Some(value)
        _ => None
      }
    _ => None
  }
}

///|
fn json_string_required_from_json(
  json : Map[String, Json],
  key : String,
  label : String,
) -> String {
  match json.get(key) {
    Some(String(value)) => value
    _ => abort(label + " missing string field `" + key + "`")
  }
}

///|
fn json_bool_required_from_json(
  json : Map[String, Json],
  key : String,
  label : String,
) -> Bool {
  match json.get(key) {
    Some(True) => true
    Some(False) => false
    _ => abort(label + " missing bool field `" + key + "`")
  }
}

///|
fn json_object_required(
  json : Map[String, Json],
  key : String,
) -> Map[String, Json] {
  match json.get(key) {
    Some(Object(value)) => value
    _ => abort("bench policy missing object field: " + key)
  }
}

///|
fn json_array_required(json : Map[String, Json], key : String) -> Array[Json] {
  match json.get(key) {
    Some(Array(value)) => value
    _ => abort("bench policy missing array field: " + key)
  }
}

///|
fn json_object_value_required(json : Json, label : String) -> Map[String, Json] {
  match json {
    Object(value) => value
    _ => abort(label + " must be an object")
  }
}

///|
fn json_string_array(json : Map[String, Json], key : String) -> Array[String] {
  match json.get(key) {
    Some(value) => json_string_array_value(value)
    None => abort("bench policy missing array field: " + key)
  }
}

///|
fn json_string_array_value(json : Json) -> Array[String] {
  match json {
    Array(items) =>
      items.map(item => {
        match item {
          String(value) => value
          _ => abort("bench policy string array contains non-string value")
        }
      })
    _ => abort("bench policy value must be a string array")
  }
}

///|
fn json_string_required_in(
  json : Map[String, Json],
  key : String,
  label : String,
) -> String {
  match json.get(key) {
    Some(String(value)) => value
    _ => abort(label + " missing string field `" + key + "`")
  }
}

///|
fn json_int_required_in(
  json : Map[String, Json],
  key : String,
  label : String,
) -> Int {
  match json.get(key) {
    Some(Number(value, ..)) => value.to_int()
    _ => abort(label + " missing integer field `" + key + "`")
  }
}

///|
fn write_jsonl(path : String, rows : Array[Json]) -> Unit raise {
  let out = Ref("")
  for row in rows {
    out.val += row.stringify() + "\n"
  }
  @fs.write_string_to_file(path, out.val, encoding="utf8")
}

///|
fn parse_report_run_id(args : Array[String]) -> String raise {
  let i = Ref(0)
  while i.val < args.length() {
    if args[i.val] == "--run" {
      ensure_next_arg(args, i.val, "--run")
      let run_id = args[i.val + 1].trim().to_owned()
      if run_id == "" {
        raise InvalidArgument("empty value is not allowed for --run")
      }
      return run_id
    }
    i.val += 1
  }
  raise InvalidArgument("report requires --run <run_id>")
}

///|
fn parse_report_baseline(args : Array[String]) -> String? {
  let i = Ref(0)
  while i.val < args.length() {
    if args[i.val] == "--baseline" && i.val + 1 < args.length() {
      return Some(args[i.val + 1].trim().to_owned())
    }
    i.val += 1
  }
  None
}

///|
fn json_string_field(json : Json, key : String) -> String {
  match json {
    Object(map) =>
      match map.get(key) {
        Some(String(value)) => value
        _ => "unknown"
      }
    _ => "unknown"
  }
}

///|
fn json_int_field(json : Json, key : String) -> Int {
  match json {
    Object(map) =>
      match map.get(key) {
        Some(Number(value, ..)) => value.to_int()
        _ => 0
      }
    _ => 0
  }
}
