///|
#cfg(not(target="native"))
fn decode_cp932_native(payload : Bytes) -> Bytes {
  // `encoding_sjis` intentionally implements the portable Shift_JIS/JIS
  // X 0208 subset.  Microsoft CP932 extension rows (FA-FC and other
  // vendor mappings) are not silently approximated here: the replacement
  // flag turns them into a controlled decode error in the caller.  Native
  // targets use the isolated iconv adapter for those additional mappings.
  let (text, had_replacements) = @encoding_sjis.decode(src=payload)
  if had_replacements {
    // The source contract fails closed on an unmappable byte. Do not turn a
    // replacement character into a successful document conversion.
    Bytes::new(0)
  } else {
    @utf8.encode(text)
  }
}
