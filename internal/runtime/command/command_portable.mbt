/// Portable command discovery deliberately fails closed. Wasm has no process
/// environment or executable search contract, so callers receive `None` and
/// can report the capability as unavailable.

///|
fn native_is_executable_file(_path_blob : Bytes) -> Int {
  0
}

///|
fn native_find_in_path(_name_blob : Bytes, _path_blob : Bytes) -> Bytes {
  b""
}
