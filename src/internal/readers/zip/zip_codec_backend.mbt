///|
fn decompress_deflate_raw_backend(
  compressed : Bytes,
  max_output_size : Int,
) -> Bytes raise CodecError {
  @flate.inflate_exact(compressed, max_output=Some(max_output_size)) catch {
    @flate.InflateError(OutputLimitExceeded, _) =>
      raise OutputTooLarge(max_output_size, max_output_size + 1)
    @flate.InflateError(_, message) => raise DecodeFailed(message)
  }
}
