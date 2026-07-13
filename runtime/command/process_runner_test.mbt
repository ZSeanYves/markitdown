///|
test "native command runner preserves argv and bounded output" {
  let shell = @command.make_resolved_command(
    "/bin/sh",
    "/bin/sh",
    @command.ResolvedCommandSource::ExplicitArg,
  )
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
