///|
fn command_with_env(
  name : String,
  value : String,
  body : () -> Unit raise,
) -> Unit raise {
  let previous = @env.get_env_var(name)
  @env.set_env_var(name, value)
  defer (match previous {
    Some(old) => @env.set_env_var(name, old)
    None => @env.unset_env_var(name)
  })
  body()
}

///|
fn command_test_module_root() -> String raise {
  let root = "/tmp/markitdown-runtime-command-" + @env.now().to_string()
  @fs.create_dir(root)
  @fs.create_dir(root + "/env")
  @fs.create_dir(root + "/env/managed-paths")
  root
}

///|
fn cleanup_command_test_module_root(root : String, record : String) -> Unit {
  ignore(
    try @fs.remove_file(record) |> Ok catch {
      _ => Err(())
    },
  )
  ignore(
    try @fs.remove_dir(root + "/env/managed-paths") |> Ok catch {
      _ => Err(())
    },
  )
  ignore(
    try @fs.remove_dir(root + "/env") |> Ok catch {
      _ => Err(())
    },
  )
  ignore(
    try @fs.remove_dir(root) |> Ok catch {
      _ => Err(())
    },
  )
}

///|
test "resolved commands expose stable provenance labels" {
  let sources : Array[(ResolvedCommandSource, String)] = [
    (ExplicitArg, "explicit_arg"),
    (RepoManaged, "repo_managed"),
    (EnvVar, "env_var"),
    (Path, "path"),
    (Fallback, "fallback"),
  ]
  for entry in sources {
    assert_eq(resolved_command_source_label(entry.0), entry.1)
  }
  let fallback = fallback_command("tool")
  assert_eq(resolved_command_context(fallback), "source=fallback;path=tool")
  assert_true(
    resolved_command_from_parts(["tool", "two words"], ExplicitArg) ==
    Some(make_resolved_command("tool", "tool \"two words\"", ExplicitArg)),
  )
  assert_true(resolved_command_from_parts([], ExplicitArg) is None)
}

///|
test "shell command quoting and splitting round trips complex arguments" {
  assert_eq(shell_quote_command_part("plain"), "plain")
  assert_eq(shell_quote_command_part("two words"), "\"two words\"")
  assert_eq(shell_quote_command_part("a\"b\\c"), "\"a\\\"b\\\\c\"")
  let command = join_shell_command([
    "tool", "two words", "quote\"value", "slash\\value",
  ])
  assert_true(
    split_shell_command(command) ==
    Ok(["tool", "two words", "quote\"value", "slash\\value"]),
  )
  assert_true(
    split_shell_command("tool 'single value' \"double value\"") ==
    Ok(["tool", "single value", "double value"]),
  )
  assert_true(split_shell_command("tool trailing\\") == Err(TrailingEscape))
  assert_true(
    split_shell_command("tool 'unterminated") == Err(UnterminatedQuotes),
  )
}

///|
test "command environment and repo-relative paths normalize safely" {
  command_with_env("MARKITDOWN_COMMAND_TEST", "  value  ", () => {
    assert_true(normalized_env_var("MARKITDOWN_COMMAND_TEST") == Some("value"))
  })
  command_with_env("MARKITDOWN_COMMAND_TEST", "   ", () => {
    assert_true(normalized_env_var("MARKITDOWN_COMMAND_TEST") is None)
  })
  command_with_env(markitdown_module_root_env_var(), "/tmp/project///", () => {
    assert_eq(resolve_repo_relative_path("env/tool"), "/tmp/project/env/tool")
    assert_eq(resolve_repo_relative_path("/absolute/tool"), "/absolute/tool")
    assert_eq(resolve_repo_relative_path(""), "")
  })
  command_with_env(markitdown_module_root_env_var(), "/", () => {
    assert_eq(resolve_repo_relative_path("env/tool"), "/env/tool")
  })
  command_with_env(markitdown_module_root_env_var(), ".", () => {
    assert_eq(resolve_repo_relative_path("env/tool"), "env/tool")
  })
}

///|
test "command executable resolution rejects invalid paths and finds PATH tools" {
  assert_true(!is_executable_file(""))
  assert_true(find_in_path("", None) is None)
  let empty = resolve_executable_path(" ", "tool", ExplicitArg)
  assert_true(empty == Err("tool must not be empty"))
  let missing = resolve_executable_path(
    "/definitely/missing/markitdown-tool",
    "tool",
    ExplicitArg,
  )
  assert_true(
    missing ==
    Err("tool path does not exist: /definitely/missing/markitdown-tool"),
  )
  assert_true(is_executable_file("/bin/sh"))
  let resolved = resolve_executable_path("/bin/sh", "shell", ExplicitArg)
  assert_true(resolved.unwrap().program == "/bin/sh")
  assert_true(find_in_path("sh", Some("/bin:/usr/bin")) is Some(_))
  assert_true(resolve_path_command("sh") is Some(_))
  assert_true(find_in_path("markitdown-definitely-missing", None) is None)
  assert_true(resolve_path_command("markitdown-definitely-missing") is None)
  assert_true(split_shell_command("/bin/sh") == Ok(["/bin/sh"]))
  let non_executable = resolve_executable_path(
    "moon.mod",
    "module",
    ExplicitArg,
  )
  let non_executable_error = match non_executable {
    Err(message) => message.contains("not executable")
    Ok(_) => false
  }
  assert_true(non_executable_error)
  assert_true(split_shell_command("   ") == Ok([]))
}

///|
test "repo-managed command records resolve hermetically" {
  let root = command_test_module_root()
  let name = "command-wbtest-shell"
  let record = root + "/env/managed-paths/" + name
  defer cleanup_command_test_module_root(root, record)
  command_with_env(markitdown_module_root_env_var(), root, () => {
    assert_eq(repo_managed_command_record_path(name), record)
    @fs.write_string_to_file(record, "/bin/sh\n", encoding="utf8")
    let resolved = resolve_repo_managed_command(name).unwrap()
    assert_eq(resolved.program, "/bin/sh")
    assert_true(resolved.source == RepoManaged)

    @fs.write_string_to_file(record, "", encoding="utf8")
    assert_true(resolve_repo_managed_command(name) is None)
    @fs.write_string_to_file(record, "bin/sh\n", encoding="utf8")
    assert_true(resolve_repo_managed_command(name) is None)
    @fs.write_string_to_file(record, "/bin/sh\n/usr/bin/sh\n", encoding="utf8")
    assert_true(resolve_repo_managed_command(name) is None)
    @fs.write_string_to_file(
      record,
      "/definitely/missing/markitdown-managed-command\n",
      encoding="utf8",
    )
    assert_true(resolve_repo_managed_command(name) is None)
  })
}

///|
test "external runner passes argv directly and captures separate outputs" {
  let command = make_resolved_command("/bin/sh", "/bin/sh", ExplicitArg)
  let output = run_resolved_command(command, [
    "-c", "printf 'out:%s' \"$1\"; printf 'err' >&2; exit 7", "sh", "$(literal)",
  ]).unwrap()
  assert_eq(output.exit_code, 7)
  assert_eq(output.stdout, "out:$(literal)")
  assert_eq(output.stderr, "err")
  assert_true(!output.timed_out)
}

///|
test "external runner enforces timeout and output ceilings" {
  let shell = make_resolved_command("/bin/sh", "/bin/sh", ExplicitArg)
  let timed = run_resolved_command(
    shell,
    ["-c", "sleep 2"],
    limits=make_command_limits(
      timeout_ms=50,
      termination_grace_ms=20,
      max_stdout_bytes=1024,
      max_stderr_bytes=1024,
    ),
  ).unwrap()
  assert_true(timed.timed_out)
  let limited = run_resolved_command(
    shell,
    ["-c", "while true; do printf 1234567890; done"],
    limits=make_command_limits(
      timeout_ms=2000,
      termination_grace_ms=20,
      max_stdout_bytes=256,
      max_stderr_bytes=256,
    ),
  ).unwrap()
  assert_true(limited.stdout_limit_exceeded)
  assert_eq(@utf8.encode(limited.stdout).length(), 256)
}

///|
async test "async external runner enforces timeout and output ceilings" {
  let shell = make_resolved_command("/bin/sh", "/bin/sh", ExplicitArg)
  let timed = run_resolved_command_async(
    shell,
    ["-c", "sleep 2"],
    limits=make_command_limits(
      timeout_ms=50,
      termination_grace_ms=20,
      max_stdout_bytes=1024,
      max_stderr_bytes=1024,
    ),
  ).unwrap()
  assert_true(timed.timed_out)
  let limited = run_resolved_command_async(
    shell,
    ["-c", "while true; do printf 1234567890; done"],
    limits=make_command_limits(
      timeout_ms=2000,
      termination_grace_ms=20,
      max_stdout_bytes=256,
      max_stderr_bytes=256,
    ),
  ).unwrap()
  assert_true(limited.stdout_limit_exceeded)
  assert_eq(@utf8.encode(limited.stdout).length(), 256)
}

///|
async test "async external runner is cancellable and reaps the child" {
  let shell = make_resolved_command("/bin/sh", "/bin/sh", ExplicitArg)
  let started = @env.now()
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      run_resolved_command_async(
        shell,
        ["-c", "sleep 10"],
        limits=make_command_limits(
          timeout_ms=20000,
          termination_grace_ms=20,
          max_stdout_bytes=1024,
          max_stderr_bytes=1024,
        ),
      )
    })
    @async.sleep(50)
    task.cancel()
    let cancelled = Ref(false)
    try task.wait() catch {
      _ => cancelled.val = true
    } noraise {
      _ => ()
    }
    assert_true(cancelled.val)
  })
  assert_true(@env.now() - started < 2000)
}
