///|
pub struct NativeMeasureSpec {
  argv_blob : Bytes
  argv_blob_len : Int
  argv_count : Int
  env_blob : Bytes
  env_blob_len : Int
  env_count : Int
  stdout_path : String
  stderr_path : String
  cwd : String?
  timeout_ms : Int64
} derive(Eq)

///|
pub struct NativeMeasureData {
  exit_code : Int
  timed_out : Bool
  measurement_error : Bool
  spawn_error : Int
  wait_error : Int
  signal : Int
  wall_us : Int64
  user_time_us : Int64
  sys_time_us : Int64
  peak_rss_kb : Int64
} derive(Eq)

///|
pub struct NativeMeasureResult {
  status : Int
  data : NativeMeasureData
} derive(Eq)

///|
pub fn encode_c_string_blob(values : Array[String]) -> Bytes {
  let bytes : Array[Byte] = []
  for value in values {
    let encoded = @utf8.encode(value)
    for b in encoded {
      bytes.push(b)
    }
    bytes.push(b'\x00')
  }
  Bytes::from_array(bytes)
}

///|
pub fn make_native_measure_spec(
  argv_blob : Bytes,
  argv_blob_len : Int,
  argv_count : Int,
  env_blob : Bytes,
  env_blob_len : Int,
  env_count : Int,
  stdout_path : String,
  stderr_path : String,
  cwd : String?,
  timeout_ms : Int64,
) -> NativeMeasureSpec {
  {
    argv_blob,
    argv_blob_len,
    argv_count,
    env_blob,
    env_blob_len,
    env_count,
    stdout_path,
    stderr_path,
    cwd,
    timeout_ms,
  }
}

///|
pub fn encode_c_path(value : String) -> Bytes {
  encode_c_string_blob([value])
}
