///|
pub fn native_measure_status(data : @measure.NativeMeasureData) -> String {
  if data.measurement_error {
    "measurement_error"
  } else if data.timed_out {
    "timeout"
  } else if data.exit_code == 0 {
    "ok"
  } else {
    "failed"
  }
}

///|
pub fn native_measure_error(
  data : @measure.NativeMeasureData,
  timeout_ms : Int,
  stderr_excerpt? : String = "",
) -> String? {
  if data.measurement_error {
    Some(
      "measurement_error" +
      native_error_detail_suffix(data) +
      native_stderr_suffix(stderr_excerpt),
    )
  } else if data.timed_out {
    Some("timeout after " + timeout_ms.to_string() + "ms")
  } else if data.exit_code == 0 {
    None
  } else {
    Some(native_failure_detail(data) + native_stderr_suffix(stderr_excerpt))
  }
}

///|
fn native_failure_detail(data : @measure.NativeMeasureData) -> String {
  if data.spawn_error < 0 {
    "cwd_invalid errno=" + (-data.spawn_error).to_string()
  } else if data.spawn_error > 0 {
    let kind = if data.exit_code == 127 {
      "exec_not_found"
    } else {
      "spawn_failed"
    }
    kind + " errno=" + data.spawn_error.to_string()
  } else if data.signal > 0 {
    "signal " + data.signal.to_string()
  } else {
    "exit_code " + data.exit_code.to_string()
  }
}

///|
fn native_error_detail_suffix(data : @measure.NativeMeasureData) -> String {
  if data.spawn_error != 0 {
    "; spawn_error=" + data.spawn_error.to_string()
  } else if data.wait_error != 0 {
    "; wait_error=" + data.wait_error.to_string()
  } else if data.signal != 0 {
    "; signal=" + data.signal.to_string()
  } else {
    ""
  }
}

///|
fn native_stderr_suffix(stderr_excerpt : String) -> String {
  let normalized = stderr_excerpt.trim().to_owned()
  if normalized == "" {
    ""
  } else {
    "; stderr: " + normalized
  }
}
