///|
pub(all) enum CompressionMethod {
  Store
  DeflateRaw
  Unsupported(Int)
} derive(Eq, Show)

///|
pub(all) suberror CodecError {
  UnsupportedCompressionMethod(Int)
  DecodeFailed(String)
  OutputTooLarge(Int, Int)
}

///|
pub impl Show for CodecError with to_string(self : CodecError) -> String {
  match self {
    UnsupportedCompressionMethod(code) =>
      "unsupported compression method: " + code.to_string()
    DecodeFailed(msg) => "codec decode failed: " + msg
    OutputTooLarge(limit, actual) =>
      "decoded output too large: limit=" +
      limit.to_string() +
      ", actual=" +
      actual.to_string()
  }
}

///|
pub impl Show for CodecError with output(
  self : CodecError,
  logger : &Logger,
) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub fn decompress(
  compression_method : CompressionMethod,
  compressed : Bytes,
  max_output_size? : Int = 128 * 1024 * 1024,
) -> Bytes raise CodecError {
  if max_output_size < 0 {
    raise OutputTooLarge(max_output_size, 0)
  }

  let out = match compression_method {
    Store => compressed
    DeflateRaw => decompress_deflate_raw_backend(compressed)
    Unsupported(code) => raise UnsupportedCompressionMethod(code)
  }

  if out.length() > max_output_size {
    raise OutputTooLarge(max_output_size, out.length())
  }

  out
}
