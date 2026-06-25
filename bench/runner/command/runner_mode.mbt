///|
pub struct RunnerContext {
  runner_mode : String
  canonical_performance : Bool
  runner_path : String?
} derive(Eq)

///|
pub fn default_runner_context() -> RunnerContext {
  make_runner_context("unknown", None)
}

///|
pub fn make_runner_context(
  runner_mode : String,
  runner_path : String?,
) -> RunnerContext {
  let normalized_mode = normalize_runner_mode(runner_mode)
  {
    runner_mode: normalized_mode,
    canonical_performance: normalized_mode == "release",
    runner_path,
  }
}

///|
pub fn detect_runner_context(raw_args : Array[String]) -> RunnerContext {
  let runner_path = detect_runner_path(raw_args)
  match normalized_override_mode() {
    Some(mode) => make_runner_context(mode, runner_path)
    None => infer_runner_context(raw_args, runner_path)
  }
}

///|
fn infer_runner_context(
  raw_args : Array[String],
  runner_path : String?,
) -> RunnerContext {
  if is_dev_moon_run_args(raw_args) {
    return make_runner_context("dev_moon_run", runner_path)
  }
  if runner_path.map(path => is_dev_runner_path(path)).unwrap_or(false) {
    return make_runner_context("dev_moon_run", runner_path)
  }
  if runner_path.map(path => is_release_runner_path(path)).unwrap_or(false) {
    return make_runner_context("release", runner_path)
  }
  make_runner_context("unknown", runner_path)
}

///|
fn normalized_override_mode() -> String? {
  match @env.get_env_var("MARKITDOWN_BENCH_RUNNER_MODE") {
    Some(value) => Some(normalize_runner_mode(value))
    None => None
  }
}

///|
fn normalize_runner_mode(mode : String) -> String {
  let normalized = mode.trim().to_owned()
  match normalized {
    "release" => "release"
    "dev_moon_run" => "dev_moon_run"
    "unknown" => "unknown"
    _ => "unknown"
  }
}

///|
fn detect_runner_path(raw_args : Array[String]) -> String? {
  if raw_args.length() == 0 {
    return None
  }
  let first = raw_args[0].trim().to_owned()
  if first == "" {
    return None
  }
  if first.contains("/") ||
    first.contains("\\") ||
    first == "runner" ||
    first == "runner.exe" ||
    first.has_suffix("/runner") ||
    first.has_suffix("/runner.exe") {
    Some(first)
  } else {
    None
  }
}

///|
fn is_dev_moon_run_args(raw_args : Array[String]) -> Bool {
  raw_args.length() >= 2 &&
  (raw_args[1] == "bench/runner" || raw_args[1] == "tools/bench")
}

///|
fn is_release_runner_path(path : String) -> Bool {
  let normalized = path.trim().to_owned()
  normalized.contains("_build/native/release") &&
  (
    normalized.contains("/bench/runner/") ||
    normalized.has_suffix("/runner") ||
    normalized.has_suffix("/runner.exe") ||
    normalized == "runner" ||
    normalized == "runner.exe"
  )
}

///|
fn is_dev_runner_path(path : String) -> Bool {
  let normalized = path.trim().to_owned()
  normalized.contains("_build/native/debug") &&
  normalized.contains("/bench/runner/")
}
