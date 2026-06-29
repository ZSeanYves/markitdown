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
fn normalize_runner_mode(mode : String) -> String {
  let normalized = mode.trim().to_owned()
  match normalized {
    "release" => "release"
    "dev_moon_run" => "dev_moon_run"
    "unknown" => "unknown"
    _ => "unknown"
  }
}
