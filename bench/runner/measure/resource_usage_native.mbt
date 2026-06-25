///|
#borrow(argv_blob, env_blob, stdout_path, stderr_path, cwd, out_exit_code, out_timed_out, out_measurement_error, out_spawn_error, out_wait_error, out_signal, out_wall_us, out_user_time_us, out_sys_time_us, out_peak_rss_kb)
extern "C" fn native_measure_command_ffi(
  argv_blob : Bytes,
  argv_blob_len : Int,
  argv_count : Int,
  env_blob : Bytes,
  env_blob_len : Int,
  env_count : Int,
  stdout_path : Bytes,
  stderr_path : Bytes,
  cwd : Bytes,
  timeout_ms : Int64,
  out_exit_code : Ref[Int],
  out_timed_out : Ref[Int],
  out_measurement_error : Ref[Int],
  out_spawn_error : Ref[Int],
  out_wait_error : Ref[Int],
  out_signal : Ref[Int],
  out_wall_us : Ref[Int64],
  out_user_time_us : Ref[Int64],
  out_sys_time_us : Ref[Int64],
  out_peak_rss_kb : Ref[Int64],
) -> Int = "markitdown_bench_native_measure_command"

///|
pub fn native_measure_command(spec : NativeMeasureSpec) -> NativeMeasureResult {
  let exit_code = Ref(0)
  let timed_out = Ref(0)
  let measurement_error = Ref(0)
  let spawn_error = Ref(0)
  let wait_error = Ref(0)
  let signal = Ref(0)
  let wall_us = Ref(0L)
  let user_time_us = Ref(0L)
  let sys_time_us = Ref(0L)
  let peak_rss_kb = Ref(0L)
  let stdout_path = encode_c_path(spec.stdout_path)
  let stderr_path = encode_c_path(spec.stderr_path)
  let cwd = match spec.cwd {
    Some(value) => encode_c_path(value)
    None => encode_c_path("")
  }
  let status = native_measure_command_ffi(
    spec.argv_blob,
    spec.argv_blob_len,
    spec.argv_count,
    spec.env_blob,
    spec.env_blob_len,
    spec.env_count,
    stdout_path,
    stderr_path,
    cwd,
    spec.timeout_ms,
    exit_code,
    timed_out,
    measurement_error,
    spawn_error,
    wait_error,
    signal,
    wall_us,
    user_time_us,
    sys_time_us,
    peak_rss_kb,
  )
  {
    status,
    data: {
      exit_code: exit_code.val,
      timed_out: timed_out.val != 0,
      measurement_error: measurement_error.val != 0,
      spawn_error: spawn_error.val,
      wait_error: wait_error.val,
      signal: signal.val,
      wall_us: wall_us.val,
      user_time_us: user_time_us.val,
      sys_time_us: sys_time_us.val,
      peak_rss_kb: peak_rss_kb.val,
    },
  }
}
