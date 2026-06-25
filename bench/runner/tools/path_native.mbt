///|
#borrow(path_blob)
extern "C" fn native_is_executable_file(path_blob : Bytes) -> Int = "markitdown_bench_is_executable_file"

///|
#borrow(name_blob, path_blob)
extern "C" fn native_find_in_path(
  name_blob : Bytes,
  path_blob : Bytes,
) -> Bytes = "markitdown_bench_find_in_path"

///|
pub fn is_executable_file(path : String) -> Bool {
  if path.trim() == "" {
    return false
  }
  native_is_executable_file(@measure.encode_c_path(path)) != 0
}

///|
pub fn find_in_path(name : String, path_env : String?) -> String? {
  if name.trim() == "" {
    return None
  }
  let path_blob = match path_env {
    Some(value) => @measure.encode_c_path(value)
    None => b""
  }
  let result = native_find_in_path(
    @measure.encode_c_path(name.trim().to_owned()),
    path_blob,
  )
  let text = (@utf8.decode(result, ignore_bom=false) catch { _ => "" })
    .trim()
    .to_owned()
  if text == "" {
    None
  } else {
    Some(text)
  }
}
