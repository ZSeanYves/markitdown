///|
#borrow(path_blob)
extern "C" fn native_is_executable_file(path_blob : Bytes) -> Int = "markitdown_runtime_is_executable_file"

///|
#borrow(name_blob, path_blob)
extern "C" fn native_find_in_path(
  name_blob : Bytes,
  path_blob : Bytes,
) -> Bytes = "markitdown_runtime_find_in_path"
