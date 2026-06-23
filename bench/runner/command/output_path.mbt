///|
pub fn result_jsonl_path(
  run_id : String,
  tool_name : String,
  tier : String,
) -> String {
  "bench/runner/results/" + run_id + "-" + tool_name + "-" + tier + ".jsonl"
}

///|
pub fn summary_json_path(run_id : String) -> String {
  "bench/runner/results/" + run_id + "-summary.json"
}

///|
pub fn report_markdown_path(run_id : String) -> String {
  "bench/runner/reports/" + run_id + ".md"
}

///|
pub fn selector_stats_path(run_id : String) -> String {
  "bench/runner/results/" + run_id + "-selector-stats.json"
}

///|
pub fn overhead_result_jsonl_path(run_id : String) -> String {
  "bench/runner/results/" + run_id + "-overhead.jsonl"
}

///|
pub fn overhead_report_markdown_path(run_id : String) -> String {
  "bench/runner/reports/" + run_id + "-overhead.md"
}

///|
pub fn tool_output_root(run_id : String, tool_name : String) -> String {
  ".tmp/markitdown-bench-output/" + run_id + "/" + tool_name
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
