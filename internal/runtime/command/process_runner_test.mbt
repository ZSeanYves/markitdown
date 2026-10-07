///|
#cfg(target="native")
test "native command runner preserves argv and bounded output" {
  let shell = @command.make_resolved_command("/bin/sh", "/bin/sh", ExplicitArg)
  let output = @command.run_resolved_command(
    shell,
    ["-c", "printf '%s' \"$1\"", "sh", "$(literal)"],
    limits=@command.make_command_limits(
      timeout_ms=1000,
      max_stdout_bytes=1024,
      max_stderr_bytes=1024,
      termination_grace_ms=20,
    ),
  ).unwrap()
  assert_eq(output.exit_code, 0)
  assert_eq(output.stdout, "$(literal)")
  assert_true(!output.timed_out)
  assert_true(!output.stdout_limit_exceeded)
}

///|
#cfg(target="wasm")
test "wasm command runner fails closed" {
  let command = @command.make_resolved_command("tool", "tool", Fallback)
  let result = @command.run_resolved_command(command, [])
  match result {
    Err(message) =>
      assert_true(
        message == "external command execution is unsupported on wasm",
      )
    Ok(_) => assert_true(false)
  }
}

///|
#cfg(target="wasm")
async test "wasm async command runner fails closed" {
  let command = @command.make_resolved_command("tool", "tool", Fallback)
  let result = @command.run_resolved_command_async(command, [])
  match result {
    Err(message) =>
      assert_true(
        message == "external command execution is unsupported on wasm",
      )
    Ok(_) => assert_true(false)
  }
}
