///|
test "markitdown tool fallback candidates keep fixed system fallbacks" {
  let candidates = fallback_candidates()
  assert_true(candidates.length() >= 2)
  assert_eq(candidates[0], "/usr/local/bin/markitdown")
  assert_eq(candidates[1], "/opt/homebrew/bin/markitdown")
}

///|
test "markitdown tool keeps the repository managed baseline path" {
  assert_eq(
    repo_local_markitdown_baseline_path(),
    "env/.venv-markitdown-bench/bin/markitdown",
  )
}
