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
test "resolved commands expose stable provenance labels" {
  let sources : Array[(ResolvedCommandSource, String)] = [
    (ResolvedCommandSource::ExplicitArg, "explicit_arg"),
    (ResolvedCommandSource::RepoManaged, "repo_managed"),
    (ResolvedCommandSource::EnvVar, "env_var"),
    (ResolvedCommandSource::Path, "path"),
    (ResolvedCommandSource::Fallback, "fallback"),
  ]
  for entry in sources {
    assert_eq(resolved_command_source_label(entry.0), entry.1)
  }
  let fallback = fallback_command("tool")
  assert_eq(resolved_command_context(fallback), "source=fallback;path=tool")
  assert_true(
    resolved_command_from_parts(
      ["tool", "two words"],
      ResolvedCommandSource::ExplicitArg,
    ) ==
    Some(
      make_resolved_command(
        "tool",
        "tool \"two words\"",
        ResolvedCommandSource::ExplicitArg,
      ),
    ),
  )
  assert_true(
    resolved_command_from_parts([], ResolvedCommandSource::ExplicitArg) is None,
  )
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
  assert_true(
    split_shell_command("tool trailing\\") ==
    Err(ShellCommandSplitError::TrailingEscape),
  )
  assert_true(
    split_shell_command("tool 'unterminated") ==
    Err(ShellCommandSplitError::UnterminatedQuotes),
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
  let empty = resolve_executable_path(
    " ",
    "tool",
    ResolvedCommandSource::ExplicitArg,
  )
  assert_true(empty == Err("tool must not be empty"))
  let missing = resolve_executable_path(
    "/definitely/missing/markitdown-tool",
    "tool",
    ResolvedCommandSource::ExplicitArg,
  )
  assert_true(
    missing ==
    Err("tool path does not exist: /definitely/missing/markitdown-tool"),
  )
  assert_true(is_executable_file("/bin/sh"))
  let resolved = resolve_executable_path(
    "/bin/sh",
    "shell",
    ResolvedCommandSource::ExplicitArg,
  )
  assert_true(resolved.unwrap().program == "/bin/sh")
  assert_true(find_in_path("sh", Some("/bin:/usr/bin")) is Some(_))
  assert_true(resolve_path_command("sh") is Some(_))
  assert_true(find_in_path("markitdown-definitely-missing", None) is None)
  assert_true(resolve_path_command("markitdown-definitely-missing") is None)
  assert_true(
    resolve_repo_managed_command("markitdown-definitely-missing") is None,
  )
  assert_true(split_shell_command("/bin/sh") == Ok(["/bin/sh"]))
  let non_executable = resolve_executable_path(
    "moon.mod",
    "module",
    ResolvedCommandSource::ExplicitArg,
  )
  let non_executable_error = match non_executable {
    Err(message) => message.contains("not executable")
    Ok(_) => false
  }
  assert_true(non_executable_error)
  assert_true(split_shell_command("   ") == Ok([]))
}
