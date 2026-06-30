///|
fn decompress_deflate_raw_backend(compressed : Bytes) -> Bytes raise CodecError {
  let inflater = @flate.Inflater::new()
  inflater.src(compressed[:])
  let sink = @blit.Buffer::new(size_hint=(compressed.length() * 2).max(32768))
  let mut done = false
  while !done {
    match inflater.decode() {
      Await =>
        raise DecodeFailed("unexpected EOF while decoding raw deflate entry")
      Data(chunk) => sink.write_bytesview(chunk)
      End => done = true
      Error(err) => raise DecodeFailed(err.to_string())
    }
  }
  sink.to_bytes()
}
