///|
fn with_env_var(
  name : String,
  value : String,
  body : () -> Unit raise,
) -> Unit raise {
  @therm.with_env_var(name, value, body)
}

///|
fn with_repo_local_baseline_stub(body : () -> Unit raise) -> Unit raise {
  @therm.with_executable_stub(
    repo_local_markitdown_baseline_path(),
    "env/.venv-markitdown-baseline/bin",
    "#!/bin/sh\nexit 0\n",
    body,
  )
}

///|
test "markitdown tool fallback candidates keep fixed system fallbacks" {
  let candidates = fallback_candidates()
  assert_true(candidates.length() >= 2)
  assert_eq(candidates[0], "/usr/local/bin/markitdown")
  assert_eq(candidates[1], "/opt/homebrew/bin/markitdown")
}

///|
test "markitdown tool prefers repo-local baseline before MARKITDOWN_BIN" {
  with_repo_local_baseline_stub(fn() raise {
    with_env_var("MARKITDOWN_BIN", "/bin/sh", fn() raise {
      let tool = markitdown_tool()
      assert_true(tool.is_available())
      assert_true(
        tool.tool_version ==
        Some(
          "path=" +
          repo_local_markitdown_baseline_path() +
          ";source=repo_managed",
        ),
      )
    })
  })
}
