///|
fn ensure_bench_dirs(run_id : String) -> Unit raise @fs.IOError {
  ensure_dir_tree(run_root(run_id))
  ensure_dir_tree(results_root(run_id))
  ensure_dir_tree(reports_root(run_id))
  ensure_dir_tree(outputs_root(run_id))
}

///|
fn ensure_parent_dir(path : String) -> Unit raise @fs.IOError {
  ensure_dir_tree(dirname(path))
}

///|
fn dirname(path : String) -> String {
  let chars = path.to_array()
  let mut last = -1
  for i in 0..<chars.length() {
    if chars[i] == '/' || chars[i] == '\\' {
      last = i
    }
  }
  if last <= 0 {
    "."
  } else {
    path[:last].to_owned()
  }
}

///|
fn ensure_dir_tree(path : String) -> Unit raise @fs.IOError {
  let normalized = path.trim().to_owned()
  if normalized == "" || normalized == "." || @fs.path_exists(normalized) {
    return
  }
  let parts = normalized.split("/")
  let mut current = if normalized.has_prefix("/") { "/" } else { "" }
  for raw in parts {
    let part = raw.trim().to_owned()
    if part == "" || part == "." {
      continue
    }
    if current == "" || current == "/" {
      current = if current == "/" { "/" + part } else { part }
    } else {
      current = current + "/" + part
    }
    if !@fs.path_exists(current) {
      @fs.create_dir(current) catch {
        err => if !@fs.path_exists(current) { raise err }
      }
    }
  }
}

///|
fn allocate_run_id(args : Array[String]) -> Result[String, BenchError] {
  let base = make_run_id(args)
  let mut suffix = 0
  while suffix < 1024 {
    let candidate = if suffix == 0 {
      base
    } else {
      base + "-" + suffix.to_string()
    }
    match try_reserve_run_root(candidate) {
      Ok(_) => {
        ensure_dir_tree(results_root(candidate)) catch {
          err =>
            return Err(
              RuntimeFailure("init run dirs failed: " + err.to_string()),
            )
        }
        ensure_dir_tree(reports_root(candidate)) catch {
          err =>
            return Err(
              RuntimeFailure("init run dirs failed: " + err.to_string()),
            )
        }
        ensure_dir_tree(outputs_root(candidate)) catch {
          err =>
            return Err(
              RuntimeFailure("init run dirs failed: " + err.to_string()),
            )
        }
        return Ok(candidate)
      }
      Err(err) => {
        if @fs.path_exists(run_root(candidate)) {
          suffix += 1
          continue
        }
        return Err(RuntimeFailure("init run dirs failed: " + err.to_string()))
      }
    }
  }
  Err(
    RuntimeFailure(
      "init run dirs failed: exhausted run id attempts for `" + base + "`",
    ),
  )
}

///|
fn try_reserve_run_root(run_id : String) -> Result[Unit, @fs.IOError] {
  try_reserve_dir(run_root(run_id))
}

///|
fn try_reserve_dir(path : String) -> Result[Unit, @fs.IOError] {
  ensure_dir_tree(dirname(path)) catch {
    err => return Err(err)
  }
  try @fs.create_dir(path) |> Ok catch {
    err => Err(err)
  }
}

///|
fn run_root(run_id : String) -> String {
  ".tmp/bench/runs/" + run_id
}

///|
fn results_root(run_id : String) -> String {
  run_root(run_id) + "/results"
}

///|
fn reports_root(run_id : String) -> String {
  run_root(run_id) + "/reports"
}

///|
fn outputs_root(run_id : String) -> String {
  run_root(run_id) + "/outputs"
}

///|
fn samples_jsonl_path(run_id : String) -> String {
  results_root(run_id) + "/samples.jsonl"
}

///|
fn cases_jsonl_path(run_id : String) -> String {
  results_root(run_id) + "/cases.jsonl"
}

///|
fn summary_json_path(run_id : String) -> String {
  results_root(run_id) + "/summary.json"
}

///|
fn report_markdown_path(run_id : String) -> String {
  reports_root(run_id) + "/report.md"
}

///|
fn output_path(
  run_id : String,
  scenario_id : String,
  tool_name : String,
  bench_id : String,
  repeat_index : Int,
  repeat_count : Int,
) -> String {
  let suffix = if repeat_count <= 1 {
    ".md"
  } else {
    "-repeat-" + (repeat_index + 1).to_string() + ".md"
  }
  outputs_root(run_id) +
  "/" +
  scenario_path_token(scenario_id) +
  "/" +
  tool_name +
  "/" +
  bench_id +
  suffix
}

///|
fn provenance_output_path(
  run_id : String,
  scenario_id : String,
  tool_name : String,
  bench_id : String,
) -> String {
  outputs_root(run_id) +
  "/" +
  scenario_path_token(scenario_id) +
  "/" +
  tool_name +
  "/" +
  bench_id +
  ".provenance.json"
}

///|
fn stdout_output_path(
  run_id : String,
  scenario_id : String,
  tool_name : String,
  bench_id : String,
) -> String {
  outputs_root(run_id) +
  "/" +
  scenario_path_token(scenario_id) +
  "/" +
  tool_name +
  "/" +
  bench_id +
  ".stdout.log"
}

///|
fn stderr_output_path(
  run_id : String,
  scenario_id : String,
  tool_name : String,
  bench_id : String,
) -> String {
  outputs_root(run_id) +
  "/" +
  scenario_path_token(scenario_id) +
  "/" +
  tool_name +
  "/" +
  bench_id +
  ".stderr.log"
}

///|
fn file_size_or_zero(path : String) -> Int64 {
  if !@fs.path_exists(path) {
    return 0L
  }
  let bytes = @fs.read_file_to_bytes(path) catch { _ => return 0L }
  bytes.length().to_int64()
}

///|
fn directory_size_bytes(path : String) -> Int64 raise {
  if !@fs.path_exists(path) {
    return 0L
  }
  if @fs.is_file(path) {
    return file_size_or_zero(path)
  }
  let mut total = 0L
  for name in @fs.read_dir(path) {
    total += directory_size_bytes(path + "/" + name)
  }
  total
}

///|
fn read_json_or_default(path : String, fallback : Json) -> Json {
  if !@fs.path_exists(path) {
    return fallback
  }
  let text = @fs.read_file_to_string(path, encoding="utf8") catch {
    _ => return fallback
  }
  @json.parse(text) catch {
    _ => fallback
  }
}

///|
fn route_provenance_complete(json : Json) -> Bool {
  match json {
    Object(map) => {
      let route_plan_ok = match map.get("route_plan") {
        Some(Object(route_plan)) =>
          route_plan.get("selected_route") is Some(_) &&
          route_plan.get("route_reason") is Some(_) &&
          route_plan.get("route_probe_summary") is Some(_)
        _ => false
      }
      route_plan_ok &&
      map.get("effective_parser_mode") is Some(_) &&
      map.get("parse_result_kind") is Some(_) &&
      map.get("pipeline_output_kind") is Some(_) &&
      map.get("render_input_kind") is Some(_) &&
      map.get("route_fidelity_status") is Some(_)
    }
    _ => false
  }
}

///|
fn scenario_path_token(scenario_id : String) -> String {
  let chars = scenario_id.to_array()
  let out : Array[Char] = []
  for char in chars {
    if (char >= 'a' && char <= 'z') ||
      (char >= 'A' && char <= 'Z') ||
      (char >= '0' && char <= '9') ||
      char == '-' ||
      char == '_' {
      out.push(char)
    } else {
      out.push('_')
    }
  }
  String::from_array(out)
}

///|
fn make_run_id(args : Array[String]) -> String {
  let fingerprint = run_id_fingerprint(args)
  "run-" + @env.now().to_string() + "-" + fingerprint
}

///|
fn run_id_fingerprint(args : Array[String]) -> String {
  let raw = args.join("|") + "|" + @env.now().to_string()
  let digest = @crypto.bytes_to_hex_string(@crypto.sha1(@utf8.encode(raw)))
  if digest.length() <= 10 {
    digest
  } else {
    digest[:10].to_owned()
  }
}
