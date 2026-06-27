///|
pub fn run_root(run_id : String) -> String {
  ".tmp/bench/runs/" + run_id
}

///|
pub fn results_root(run_id : String) -> String {
  run_root(run_id) + "/results"
}

///|
pub fn reports_root(run_id : String) -> String {
  run_root(run_id) + "/reports"
}

///|
pub fn outputs_root(run_id : String) -> String {
  run_root(run_id) + "/outputs"
}

///|
pub fn profiles_root() -> String {
  ".tmp/bench/profiles"
}

///|
pub fn profile_run_root(run_id : String) -> String {
  profiles_root() + "/" + run_id
}

///|
pub fn profile_results_root(run_id : String) -> String {
  profile_run_root(run_id) + "/results"
}

///|
pub fn profile_reports_root(run_id : String) -> String {
  profile_run_root(run_id) + "/reports"
}

///|
pub fn result_jsonl_path(
  run_id : String,
  tool_name : String,
  tier : String,
) -> String {
  results_root(run_id) + "/" + run_id + "-" + tool_name + "-" + tier + ".jsonl"
}

///|
pub fn result_tier_label(tier : String, exact_tiers : Array[String]) -> String {
  if exact_tiers.length() == 0 {
    tier.trim().to_lower().to_owned()
  } else {
    "tiers-" + exact_tiers.map(t => t.trim().to_lower().to_owned()).join("-")
  }
}

///|
pub fn summary_json_path(run_id : String) -> String {
  results_root(run_id) + "/" + run_id + "-summary.json"
}

///|
pub fn report_markdown_path(run_id : String) -> String {
  reports_root(run_id) + "/" + run_id + ".md"
}

///|
pub fn selector_stats_path(run_id : String) -> String {
  results_root(run_id) + "/" + run_id + "-selector-stats.json"
}

///|
pub fn overhead_result_jsonl_path(run_id : String) -> String {
  results_root(run_id) + "/" + run_id + "-overhead.jsonl"
}

///|
pub fn overhead_report_markdown_path(run_id : String) -> String {
  reports_root(run_id) + "/" + run_id + "-overhead.md"
}

///|
pub fn profile_index_path(run_id : String) -> String {
  profile_results_root(run_id) + "/" + run_id + "-index.json"
}

///|
pub fn profile_bench_stdout_path(
  run_id : String,
  profile_key : String,
) -> String {
  profile_results_root(run_id) + "/" + profile_key + ".stdout.log"
}

///|
pub fn profile_bench_stderr_path(
  run_id : String,
  profile_key : String,
) -> String {
  profile_results_root(run_id) + "/" + profile_key + ".stderr.log"
}

///|
pub fn tool_output_root(run_id : String, tool_name : String) -> String {
  outputs_root(run_id) + "/" + tool_name
}

///|
pub fn output_markdown_path(
  run_id : String,
  tool_name : String,
  bench_id : String,
  repeat_index : Int,
  repeat_count : Int,
) -> String {
  tool_output_root(run_id, tool_name) +
  "/" +
  bench_id +
  repeat_suffix(repeat_index, repeat_count) +
  ".md"
}

///|
fn repeat_suffix(repeat_index : Int, repeat_count : Int) -> String {
  if repeat_count <= 1 {
    ""
  } else {
    "-repeat-" + (repeat_index + 1).to_string()
  }
}
