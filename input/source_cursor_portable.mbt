///|
fn open_path_source_cursor(path : String) -> Result[SourceCursor, String] {
  let bytes = try @fs.read_file_to_bytes(path) |> Ok catch {
    error => Err("read bytes failed: " + error.to_string())
  }
  match bytes {
    Ok(value) => Ok(source_cursor_from_bytes(value))
    Err(message) => Err(message)
  }
}
