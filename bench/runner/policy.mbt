///|
priv struct PolicyDefaults {
  repeat_count : Int
  warmup_count : Int
  timeout_ms : Int
  tiers : Array[String]
}

///|
priv struct ScenarioPolicy {
  scenario_id : String
  scenario_kind : String
  tool_set : String
  exact_tiers : Array[String]
  format_filters : Array[String]
  comparison_classes : Array[String]
  official_membership : String
  route_expectation : String
}

///|
priv struct PresetPolicy {
  scenario_ids : Array[String]
  tiers : Array[String]
  repeat_count : Int
  warmup_count : Int
  timeout_ms : Int
}

///|
priv struct BenchPolicy {
  defaults : PolicyDefaults
  default_rss_limit_mb : Int
  rss_limits_mb : Map[String, Int]
  tool_matrix : Map[String, Array[String]]
  presets : Map[String, PresetPolicy]
  scenarios : Array[ScenarioPolicy]
  row_expected_routes : Map[String, String]
}

///|
fn parse_run_options(args : Array[String]) -> RunOptions raise {
  let preset : Ref[String?] = Ref(None)
  let scenario_id : Ref[String?] = Ref(None)
  let exact_tiers : Ref[Array[String]] = Ref([])
  let bench_ids : Ref[Array[String]] = Ref([])
  let formats : Ref[Array[String]] = Ref([])
  let limit : Ref[Int?] = Ref(None)
  let repeat_count = Ref(-1)
  let warmup_count = Ref(-1)
  let timeout_ms = Ref(-1)
  let markitdown_path : Ref[String?] = Ref(None)
  let baseline_run_id : Ref[String?] = Ref(None)
  let progress_mode = Ref("auto")
  let keep_outputs = Ref("failures")
  let resume_run_id : Ref[String?] = Ref(None)
  let max_disk_mb = Ref(4096)
  let i = Ref(0)
  while i.val < args.length() {
    let arg = args[i.val]
    match arg {
      "--preset" => {
        ensure_next_arg(args, i.val, "--preset")
        preset.val = Some(args[i.val + 1].trim().to_owned())
        i.val += 2
      }
      "--scenario" => {
        ensure_next_arg(args, i.val, "--scenario")
        scenario_id.val = Some(args[i.val + 1].trim().to_owned())
        i.val += 2
      }
      "--tiers" => {
        ensure_next_arg(args, i.val, "--tiers")
        exact_tiers.val = @manifest.parse_tier_list(args[i.val + 1], "--tiers")
        i.val += 2
      }
      "--bench-id" => {
        ensure_next_arg(args, i.val, "--bench-id")
        bench_ids.val = parse_csv(args[i.val + 1], "--bench-id")
        i.val += 2
      }
      "--format" => {
        ensure_next_arg(args, i.val, "--format")
        formats.val = parse_csv(args[i.val + 1], "--format")
        i.val += 2
      }
      "--limit" => {
        ensure_next_arg(args, i.val, "--limit")
        limit.val = Some(parse_non_negative_int(args[i.val + 1], "--limit"))
        i.val += 2
      }
      "--repeat" => {
        ensure_next_arg(args, i.val, "--repeat")
        repeat_count.val = parse_non_negative_int(args[i.val + 1], "--repeat")
        i.val += 2
      }
      "--warmup" => {
        ensure_next_arg(args, i.val, "--warmup")
        warmup_count.val = parse_non_negative_int(args[i.val + 1], "--warmup")
        i.val += 2
      }
      "--timeout-ms" => {
        ensure_next_arg(args, i.val, "--timeout-ms")
        timeout_ms.val = parse_non_negative_int(args[i.val + 1], "--timeout-ms")
        i.val += 2
      }
      "--markitdown-path" => {
        ensure_next_arg(args, i.val, "--markitdown-path")
        markitdown_path.val = Some(args[i.val + 1].trim().to_owned())
        i.val += 2
      }
      "--baseline" => {
        ensure_next_arg(args, i.val, "--baseline")
        baseline_run_id.val = Some(args[i.val + 1].trim().to_owned())
        i.val += 2
      }
      "--progress" => {
        ensure_next_arg(args, i.val, "--progress")
        progress_mode.val = parse_choice(args[i.val + 1], "--progress", [
          "auto", "json", "off",
        ])
        i.val += 2
      }
      "--keep-outputs" => {
        ensure_next_arg(args, i.val, "--keep-outputs")
        keep_outputs.val = parse_choice(args[i.val + 1], "--keep-outputs", [
          "failures", "all", "none",
        ])
        i.val += 2
      }
      "--resume" => {
        ensure_next_arg(args, i.val, "--resume")
        resume_run_id.val = Some(args[i.val + 1].trim().to_owned())
        i.val += 2
      }
      "--max-disk-mb" => {
        ensure_next_arg(args, i.val, "--max-disk-mb")
        let value = parse_non_negative_int(args[i.val + 1], "--max-disk-mb")
        if value == 0 {
          raise InvalidArgument("zero is not allowed for --max-disk-mb")
        }
        max_disk_mb.val = value
        i.val += 2
      }
      _ if arg.has_prefix("--progress=") => {
        progress_mode.val = parse_choice(arg[11:].to_owned(), "--progress", [
          "auto", "json", "off",
        ])
        i.val += 1
      }
      _ if arg.has_prefix("--keep-outputs=") => {
        keep_outputs.val = parse_choice(arg[15:].to_owned(), "--keep-outputs", [
          "failures", "all", "none",
        ])
        i.val += 1
      }
      _ => raise InvalidArgument("unsupported argument: " + arg)
    }
  }
  {
    preset: preset.val,
    scenario_id: scenario_id.val,
    exact_tiers: exact_tiers.val,
    bench_ids: bench_ids.val,
    format_filters: formats.val,
    limit: limit.val,
    repeat_count: repeat_count.val,
    warmup_count: warmup_count.val,
    timeout_ms: timeout_ms.val,
    markitdown_path: markitdown_path.val,
    baseline_run_id: baseline_run_id.val,
    progress_mode: progress_mode.val,
    keep_outputs: keep_outputs.val,
    resume_run_id: resume_run_id.val,
    max_disk_mb: max_disk_mb.val,
  }
}

///|
fn parse_choice(
  value : String,
  flag : String,
  choices : Array[String],
) -> String raise {
  let normalized = value.trim().to_lower().to_owned()
  if !choices.contains(normalized) {
    raise InvalidArgument(flag + " must be one of: " + choices.join(", "))
  }
  normalized
}

///|
fn ensure_next_arg(
  args : Array[String],
  index : Int,
  flag : String,
) -> Unit raise {
  if index + 1 >= args.length() {
    raise InvalidArgument("missing value for " + flag)
  }
}

///|
fn parse_csv(text : String, flag : String) -> Array[String] raise {
  let items = text
    .split(",")
    .to_array()
    .map(item => item.trim().to_owned())
    .filter(item => item != "")
  if items.length() == 0 {
    raise InvalidArgument("empty value is not allowed for " + flag)
  }
  items
}

///|
fn parse_non_negative_int(text : String, flag : String) -> Int raise {
  let value = @string.parse_int(text.trim()) catch {
    _ => raise InvalidArgument("invalid integer for " + flag + ": " + text)
  }
  if value < 0 {
    raise InvalidArgument("negative integer is not allowed for " + flag)
  }
  value
}

///|
fn resolve_scenarios(
  opts : RunOptions,
  policy : BenchPolicy,
) -> Array[ScenarioSpec] {
  let scenarios = policy_scenarios(policy)
  match opts.scenario_id {
    Some(wanted) => [find_scenario_or_abort(scenarios, wanted)]
    None =>
      match opts.preset {
        Some(name) => resolve_preset_scenarios(name, scenarios, policy)
        None => abort("run requires --preset or --scenario")
      }
  }
}

///|
fn find_scenario_or_abort(
  scenarios : Array[ScenarioSpec],
  wanted : String,
) -> ScenarioSpec {
  for scenario in scenarios {
    if scenario.scenario_id == wanted {
      return scenario
    }
  }
  abort("unknown scenario: " + wanted)
}

///|
fn resolve_preset_scenarios(
  preset_name : String,
  scenarios : Array[ScenarioSpec],
  policy : BenchPolicy,
) -> Array[ScenarioSpec] {
  match policy.presets.get(preset_name) {
    Some(preset) => {
      if preset.scenario_ids.length() == 0 {
        abort("preset has no scenario_ids: " + preset_name)
      }
      let out : Array[ScenarioSpec] = []
      for scenario_id in preset.scenario_ids {
        out.push(find_scenario_or_abort(scenarios, scenario_id))
      }
      out
    }
    None => abort("unknown preset: " + preset_name)
  }
}

///|
fn policy_scenarios(policy : BenchPolicy) -> Array[ScenarioSpec] {
  policy.scenarios.map(item => {
    scenario_id: item.scenario_id,
    scenario_kind: item.scenario_kind,
    tool_names: policy.tool_matrix.get(item.tool_set).unwrap_or([]),
    exact_tiers: item.exact_tiers,
    format_filters: item.format_filters,
    comparison_classes: item.comparison_classes,
    official_membership: item.official_membership,
    route_expectation: item.route_expectation,
  })
}

///|
fn load_policy() -> Result[BenchPolicy, BenchError] {
  let text = @fs.read_file_to_string(
    "bench/config/policy.json",
    encoding="utf8",
  ) catch {
    err =>
      return Err(
        RuntimeFailure(
          "read bench/config/policy.json failed: " + err.to_string(),
        ),
      )
  }
  let json = @json.parse(text) catch {
    err =>
      return Err(
        RuntimeFailure(
          "parse bench/config/policy.json failed: " + err.to_string(),
        ),
      )
  }
  Ok(decode_policy(json))
}

///|
fn decode_policy(json : Json) -> BenchPolicy {
  let root = json_object_value_required(json, "bench policy root")
  let rss_limits = json_object_required(root, "rss_limits_mb")
  {
    defaults: {
      repeat_count: json_int_required_in(
        json_object_required(root, "defaults"),
        "repeat_count",
        "defaults",
      ),
      warmup_count: json_int_required_in(
        json_object_required(root, "defaults"),
        "warmup_count",
        "defaults",
      ),
      timeout_ms: json_int_required_in(
        json_object_required(root, "defaults"),
        "timeout_ms",
        "defaults",
      ),
      tiers: json_string_array(json_object_required(root, "defaults"), "tiers"),
    },
    default_rss_limit_mb: json_int_required_in(
      rss_limits, "default", "rss_limits_mb",
    ),
    rss_limits_mb: decode_rss_limits(rss_limits),
    tool_matrix: decode_tool_matrix(json_object_required(root, "tool_matrix")),
    presets: decode_presets(json_object_required(root, "gate_presets")),
    scenarios: decode_scenarios(json_array_required(root, "scenarios")),
    row_expected_routes: decode_row_expected_routes(
      json_object_required(root, "row_overrides"),
    ),
  }
}

///|
fn decode_rss_limits(json : Map[String, Json]) -> Map[String, Int] {
  let out : Map[String, Int] = {}
  for entry in json {
    if entry.0 != "default" {
      out[entry.0] = match entry.1 {
        Json::Number(value, ..) => value.to_int()
        _ => abort("bench policy RSS limit must be an integer: " + entry.0)
      }
    }
  }
  out
}

///|
fn decode_tool_matrix(json : Map[String, Json]) -> Map[String, Array[String]] {
  let out : Map[String, Array[String]] = {}
  for entry in json {
    out[entry.0] = json_string_array_value(entry.1)
  }
  out
}

///|
fn decode_presets(json : Map[String, Json]) -> Map[String, PresetPolicy] {
  let out : Map[String, PresetPolicy] = {}
  for entry in json {
    let object = json_object_value_required(
      entry.1,
      "gate preset `" + entry.0 + "`",
    )
    out[entry.0] = {
      scenario_ids: json_string_array(object, "scenario_ids"),
      tiers: json_string_array(object, "tiers"),
      repeat_count: json_int_required_in(
        object,
        "repeat_count",
        "gate preset `" + entry.0 + "`",
      ),
      warmup_count: json_int_required_in(
        object,
        "warmup_count",
        "gate preset `" + entry.0 + "`",
      ),
      timeout_ms: json_int_required_in(
        object,
        "timeout_ms",
        "gate preset `" + entry.0 + "`",
      ),
    }
  }
  out
}

///|
fn decode_scenarios(json : Array[Json]) -> Array[ScenarioPolicy] {
  json.map(item => {
    let object = json_object_value_required(item, "scenario")
    let row_selector = json_object_required(object, "row_selector")
    {
      scenario_id: json_string_required_in(object, "scenario_id", "scenario"),
      scenario_kind: json_string_required_in(
        object, "scenario_kind", "scenario",
      ),
      tool_set: json_string_required_in(object, "tool_set", "scenario"),
      exact_tiers: if row_selector.get("tiers") is Some(_) {
        json_string_array(row_selector, "tiers")
      } else {
        []
      },
      format_filters: if row_selector.get("formats") is Some(_) {
        json_string_array(row_selector, "formats")
      } else {
        []
      },
      comparison_classes: if row_selector.get("comparison_classes") is Some(_) {
        json_string_array(row_selector, "comparison_classes")
      } else {
        []
      },
      official_membership: json_string_required_in(
        object, "official_membership", "scenario",
      ),
      route_expectation: json_string_required_in(
        object, "route_expectation", "scenario",
      ),
    }
  })
}

///|
fn decode_row_expected_routes(json : Map[String, Json]) -> Map[String, String] {
  let out : Map[String, String] = {}
  for entry in json {
    let object = json_object_value_required(
      entry.1,
      "row override `" + entry.0 + "`",
    )
    match object.get("route_expectation") {
      Some(Json::String(value)) => out[entry.0] = value
      Some(Json::Object(route_object)) =>
        match route_object.get("selected_route") {
          Some(Json::String(value)) => out[entry.0] = value
          _ => ()
        }
      _ => ()
    }
  }
  out
}

///|
fn apply_policy_defaults(opts : RunOptions, policy : BenchPolicy) -> RunOptions {
  let preset = opts.preset.bind(fn(name) { policy.presets.get(name) })
  {
    ..opts,
    exact_tiers: if opts.exact_tiers.length() > 0 {
      opts.exact_tiers
    } else {
      preset.map(item => item.tiers).unwrap_or(policy.defaults.tiers)
    },
    repeat_count: if opts.repeat_count < 0 {
      preset
      .map(item => item.repeat_count)
      .unwrap_or(policy.defaults.repeat_count)
    } else {
      opts.repeat_count
    },
    warmup_count: if opts.warmup_count < 0 {
      preset
      .map(item => item.warmup_count)
      .unwrap_or(policy.defaults.warmup_count)
    } else {
      opts.warmup_count
    },
    timeout_ms: if opts.timeout_ms < 0 {
      preset.map(item => item.timeout_ms).unwrap_or(policy.defaults.timeout_ms)
    } else {
      opts.timeout_ms
    },
  }
}

///|
fn expected_route_for_case(
  sample : SampleRow,
  scenario : ScenarioSpec,
  policy : BenchPolicy,
) -> String? {
  if sample.tool != "moonbit-cli" && sample.tool != "moonbit-engine" {
    return None
  }
  match policy.row_expected_routes.get(sample.bench_id) {
    Some(value) => Some(value)
    None =>
      if scenario.route_expectation == "product_default" ||
        scenario.route_expectation == "not_applicable" {
        None
      } else {
        Some(scenario.route_expectation)
      }
  }
}

///|
fn actual_route_name(route_provenance : Json) -> String? {
  match route_provenance {
    Json::Object(map) =>
      match map.get("route_plan") {
        Some(Json::Object(route_plan)) =>
          match route_plan.get("selected_route") {
            Some(Json::String(value)) => Some(value)
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn route_coverage_status(
  tool_name : String,
  _route_provenance : Json,
  expected_route : String?,
  actual_route : String?,
) -> String {
  if tool_name != "moonbit-cli" && tool_name != "moonbit-engine" {
    return "not_applicable"
  }
  match expected_route {
    Some(expected) =>
      if actual_route == Some(expected) {
        "covered"
      } else {
        "mismatch"
      }
    None => "covered"
  }
}

///|
fn output_density(output_bytes : Int64?, input_bytes : Int) -> Double? {
  match output_bytes {
    Some(value) =>
      if input_bytes > 0 {
        Some(value.to_double() / input_bytes.to_double())
      } else {
        None
      }
    None => None
  }
}

///|
fn semantic_coverage(
  sample : SampleRow,
  output_bytes : Int64?,
  density : Double?,
) -> String {
  if sample.tool != "moonbit-cli" && sample.tool != "moonbit-engine" {
    return "not_applicable"
  }
  if sample.status != "ok" {
    return "not_applicable"
  }
  if !structured_text_format_requires_density_guard(sample.format) {
    return "ok"
  }
  if sample.size_class != "large" && sample.size_class != "huge" {
    return "ok"
  }
  let bytes = output_bytes.unwrap_or(0L)
  let ratio = density.unwrap_or(0.0)
  if bytes < 256L && ratio < 0.001 {
    "low_density_untrusted"
  } else {
    "ok"
  }
}

///|
fn structured_text_format_requires_density_guard(format : String) -> Bool {
  format == "json" || format == "yaml" || format == "xml"
}

///|
fn render_path(route_provenance : Json) -> String {
  match route_provenance {
    Json::Object(map) =>
      match map.get("render_input_kind") {
        Some(Json::String(value)) => value
        _ => "unknown"
      }
    _ => "unknown"
  }
}

///|
fn case_trust_status(
  tool_name : String,
  route_coverage_status : String,
  semantic_coverage : String,
  route_fidelity_status : String?,
  provenance_complete : Bool,
) -> String {
  if case_trust_failure_reason(
      tool_name, route_coverage_status, semantic_coverage, route_fidelity_status,
      provenance_complete,
    ) !=
    "none" {
    "failed"
  } else {
    "trusted"
  }
}

///|
fn case_trust_failure_reason(
  tool_name : String,
  route_coverage_status : String,
  semantic_coverage : String,
  route_fidelity_status : String?,
  provenance_complete : Bool,
) -> String {
  if tool_name == "moonbit-cli" || tool_name == "moonbit-engine" {
    if !provenance_complete {
      return "missing_provenance"
    }
    if route_fidelity_status != Some("matched") {
      return "fidelity_mismatch"
    }
    if route_coverage_status == "mismatch" {
      return "route_mismatch"
    }
  }
  if semantic_coverage == "low_density_untrusted" {
    return "low_density_untrusted"
  }
  "none"
}

///|
fn route_fidelity_status(route_provenance : Json) -> String? {
  json_optional_string_field(route_provenance, "route_fidelity_status")
}

///|
fn scenario_map(scenarios : Array[ScenarioSpec]) -> Map[String, ScenarioSpec] {
  let out : Map[String, ScenarioSpec] = {}
  for scenario in scenarios {
    out[scenario.scenario_id] = scenario
  }
  out
}

///|
fn scenario_specs_for_run(
  samples : Array[SampleRow],
  policy : BenchPolicy,
) -> Array[ScenarioSpec] {
  let catalog = scenario_map(policy_scenarios(policy))
  let out : Array[ScenarioSpec] = []
  for sample in samples {
    let key = sample.scenario_id
    if out.any(fn(item) { item.scenario_id == key }) {
      continue
    }
    match catalog.get(key) {
      Some(scenario) => out.push(scenario)
      None => abort("unknown scenario recorded in run: " + key)
    }
  }
  out
}
