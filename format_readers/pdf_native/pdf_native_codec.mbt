///|
pub fn inflate_pdf_stream(compressed : Bytes) -> Result[Bytes, String] {
  try @zlib.decompress(compressed) |> Ok catch {
    err => Err(err.to_string())
  }
}
