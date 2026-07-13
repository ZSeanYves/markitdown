///|
/// Resource ceilings for one external command invocation.
pub struct CommandLimits {
  timeout_ms : Int
  max_stdout_bytes : Int
  max_stderr_bytes : Int
  termination_grace_ms : Int
}

///|
/// Captured command result after the child process has been reaped.
pub struct CommandOutput {
  exit_code : Int
  signal : Int
  stdout : String
  stderr : String
  timed_out : Bool
  stdout_limit_exceeded : Bool
  stderr_limit_exceeded : Bool
}

///|
priv type NativeCommandResult

///|
#borrow(argv_blob)
extern "c" fn native_run_command(
  argv_blob : Bytes,
  argv_blob_len : Int,
  argv_count : Int,
  timeout_ms : Int,
  max_stdout_bytes : Int,
  max_stderr_bytes : Int,
  termination_grace_ms : Int,
) -> NativeCommandResult = "markitdown_command_run"

///|
#borrow(result)
extern "c" fn native_command_result_is_null(
  result : NativeCommandResult,
) -> Bool = "markitdown_command_result_is_null"

///|
#borrow(result)
extern "c" fn native_command_result_spawn_error(
  result : NativeCommandResult,
) -> Int = "markitdown_command_result_spawn_error"

///|
#borrow(result)
extern "c" fn native_command_result_wait_error(
  result : NativeCommandResult,
) -> Int = "markitdown_command_result_wait_error"

///|
#borrow(result)
extern "c" fn native_command_result_exit_code(
  result : NativeCommandResult,
) -> Int = "markitdown_command_result_exit_code"

///|
#borrow(result)
extern "c" fn native_command_result_signal(result : NativeCommandResult) -> Int = "markitdown_command_result_signal"

///|
#borrow(result)
extern "c" fn native_command_result_timed_out(
  result : NativeCommandResult,
) -> Bool = "markitdown_command_result_timed_out"

///|
#borrow(result)
extern "c" fn native_command_result_stdout_limited(
  result : NativeCommandResult,
) -> Bool = "markitdown_command_result_stdout_limited"

///|
#borrow(result)
extern "c" fn native_command_result_stderr_limited(
  result : NativeCommandResult,
) -> Bool = "markitdown_command_result_stderr_limited"

///|
#borrow(result)
extern "c" fn native_command_result_stdout(
  result : NativeCommandResult,
) -> Bytes = "markitdown_command_result_stdout"

///|
#borrow(result)
extern "c" fn native_command_result_stderr(
  result : NativeCommandResult,
) -> Bytes = "markitdown_command_result_stderr"

///|
pub fn default_command_limits() -> CommandLimits {
  {
    timeout_ms: 300000,
    max_stdout_bytes: 8 * 1024 * 1024,
    max_stderr_bytes: 8 * 1024 * 1024,
    termination_grace_ms: 2000,
  }
}

///|
pub fn make_command_limits(
  timeout_ms? : Int = 300000,
  max_stdout_bytes? : Int = 8 * 1024 * 1024,
  max_stderr_bytes? : Int = 8 * 1024 * 1024,
  termination_grace_ms? : Int = 2000,
) -> CommandLimits {
  { timeout_ms, max_stdout_bytes, max_stderr_bytes, termination_grace_ms }
}

///|
pub fn run_resolved_command(
  command : ResolvedCommand,
  args : Array[String],
  limits? : CommandLimits = default_command_limits(),
) -> Result[CommandOutput, String] {
  if limits.timeout_ms <= 0 ||
    limits.max_stdout_bytes < 0 ||
    limits.max_stderr_bytes < 0 ||
    limits.termination_grace_ms < 0 {
    return Err(
      "external command limits must be non-negative and timeout positive",
    )
  }
  let argv : Array[String] = [command.program]
  argv.append(args)
  let blob = encode_command_argv(argv)
  let result = native_run_command(
    blob,
    blob.length(),
    argv.length(),
    limits.timeout_ms,
    limits.max_stdout_bytes,
    limits.max_stderr_bytes,
    limits.termination_grace_ms,
  )
  if native_command_result_is_null(result) {
    return Err("external command runner allocation failed")
  }
  let spawn_error = native_command_result_spawn_error(result)
  if spawn_error != 0 {
    return Err(
      "external command spawn failed: errno=" + spawn_error.to_string(),
    )
  }
  let wait_error = native_command_result_wait_error(result)
  if wait_error != 0 {
    return Err("external command wait failed: errno=" + wait_error.to_string())
  }
  let stdout = @utf8.decode(
    native_command_result_stdout(result),
    ignore_bom=false,
  ) catch {
    _ => return Err("external command stdout is not valid UTF-8")
  }
  let stderr = @utf8.decode(
    native_command_result_stderr(result),
    ignore_bom=false,
  ) catch {
    _ => return Err("external command stderr is not valid UTF-8")
  }
  Ok({
    exit_code: native_command_result_exit_code(result),
    signal: native_command_result_signal(result),
    stdout,
    stderr,
    timed_out: native_command_result_timed_out(result),
    stdout_limit_exceeded: native_command_result_stdout_limited(result),
    stderr_limit_exceeded: native_command_result_stderr_limited(result),
  })
}

///|
/// Run a command without blocking the async event loop. Cancellation and the
/// deadline both terminate the child process, wait through the grace period,
/// and then forcefully reap it if necessary.
pub async fn run_resolved_command_async(
  command : ResolvedCommand,
  args : Array[String],
  limits? : CommandLimits = default_command_limits(),
) -> Result[CommandOutput, String] {
  if limits.timeout_ms <= 0 ||
    limits.max_stdout_bytes < 0 ||
    limits.max_stderr_bytes < 0 ||
    limits.termination_grace_ms < 0 {
    return Err(
      "external command limits must be non-negative and timeout positive",
    )
  }
  let completed = @async.with_timeout_opt(limits.timeout_ms, () => {
    @async.with_task_group(group => {
      let (stdout_reader, stdout_target) = @process.read_from_process()
      let (stderr_reader, stderr_target) = @process.read_from_process()
      let process = @process.spawn(
        group,
        command.program,
        args,
        stdout=stdout_target,
        stderr=stderr_target,
        cancel_handler=@process.graceful_cancel(
          timeout=limits.termination_grace_ms,
        ),
        no_wait=true,
      )
      let stdout_task = group.spawn(() => {
        defer stdout_reader.close()
        read_bounded_process_output(
          stdout_reader,
          limits.max_stdout_bytes,
          process,
        )
      })
      let stderr_task = group.spawn(() => {
        defer stderr_reader.close()
        read_bounded_process_output(
          stderr_reader,
          limits.max_stderr_bytes,
          process,
        )
      })
      let exit_code = process.wait() catch { _ => -1 }
      let (stdout_bytes, stdout_limited) = stdout_task.wait()
      let (stderr_bytes, stderr_limited) = stderr_task.wait()
      (exit_code, stdout_bytes, stderr_bytes, stdout_limited, stderr_limited)
    })
  })
  let (exit_code, stdout_bytes, stderr_bytes, stdout_limited, stderr_limited) = match
    completed {
    Some(value) => value
    None =>
      return Ok({
        exit_code: -1,
        signal: 0,
        stdout: "",
        stderr: "",
        timed_out: true,
        stdout_limit_exceeded: false,
        stderr_limit_exceeded: false,
      })
  }
  let stdout = @utf8.decode(stdout_bytes, ignore_bom=false) catch {
    _ => return Err("external command stdout is not valid UTF-8")
  }
  let stderr = @utf8.decode(stderr_bytes, ignore_bom=false) catch {
    _ => return Err("external command stderr is not valid UTF-8")
  }
  Ok({
    exit_code,
    signal: 0,
    stdout,
    stderr,
    timed_out: false,
    stdout_limit_exceeded: stdout_limited,
    stderr_limit_exceeded: stderr_limited,
  })
}

///|
async fn[R : @aio.Reader] read_bounded_process_output(
  reader : R,
  limit : Int,
  process : @process.Process,
) -> (Bytes, Bool) {
  let output = Buffer(size_hint=limit.min(64 * 1024))
  while reader.read_some(max_len=(limit - output.length()).max(0) + 1)
        is Some(chunk) {
    let remaining = (limit - output.length()).max(0)
    if chunk.length() > remaining {
      if remaining > 0 {
        output.write_bytes(chunk[:remaining])
      }
      process.cancel()
      return (output.to_bytes(), true)
    }
    output.write_bytes(chunk)
  }
  (output.to_bytes(), false)
}

///|
fn encode_command_argv(argv : Array[String]) -> Bytes {
  let out : Array[Byte] = []
  for value in argv {
    for byte in @utf8.encode(value) {
      out.push(byte)
    }
    out.push(b'\x00')
  }
  Bytes::from_array(out)
}
