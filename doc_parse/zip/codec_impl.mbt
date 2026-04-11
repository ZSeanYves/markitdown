///|
fn decompress_deflate_raw_backend(compressed : Bytes) -> Bytes raise CodecError {
  @flate.decompress(compressed) catch {
    err => raise DecodeFailed(err.to_string())
  }
}
