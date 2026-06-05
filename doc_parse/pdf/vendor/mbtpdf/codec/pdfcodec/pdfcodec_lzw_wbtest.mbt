///|
test "lzw roundtrip early 1" {
  let original = @pdfio.bytes_of_string("TOBEORNOTTOBEORTOBEORNOT")
  let encoded = encode_lzw(1, original)
  let decoded = decode_lzw(1, @pdfio.Input::of_bytes(encoded, source="lzw"))
  assert_eq(@pdfio.string_of_bytes(decoded), "TOBEORNOTTOBEORTOBEORNOT")
}

///|
test "lzw roundtrip early 0" {
  let original = @pdfio.bytes_of_string("ABRACADABRABRABRA")
  let encoded = encode_lzw(0, original)
  let decoded = decode_lzw(0, @pdfio.Input::of_bytes(encoded, source="lzw"))
  assert_eq(@pdfio.string_of_bytes(decoded), "ABRACADABRABRABRA")
}

///|
test "lzw empty" {
  let original = @pdfio.bytes_of_string("")
  let encoded = encode_lzw(1, original)
  let decoded = decode_lzw(1, @pdfio.Input::of_bytes(encoded, source="lzw"))
  assert_eq(@pdfio.string_of_bytes(decoded), "")
}
