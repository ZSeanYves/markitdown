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
  OutputTooLarge(max : Int, actual : Int)
}

///|
pub fn decompress(
  method : CompressionMethod,
  compressed : Bytes,
  max_output_size~ : Int = 128 * 1024 * 1024,
) -> Bytes raise CodecError {
  if max_output_size < 0 {
    raise OutputTooLarge(max_output_size, 0)
  }

  let out = match method {
    Store => compressed
    DeflateRaw => decompress_deflate_raw_backend(compressed)
    Unsupported(code) => raise UnsupportedCompressionMethod(code)
  }

  if out.length() > max_output_size {
    raise OutputTooLarge(max_output_size, out.length())
  }

  out
}
