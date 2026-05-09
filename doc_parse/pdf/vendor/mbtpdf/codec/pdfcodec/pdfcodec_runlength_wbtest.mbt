///|
test "runlength roundtrip" {
  let original = @pdfio.bytes_of_string("aaabbbccccccdde")
  let encoded = encode_runlength(original)
  let decoded = decode_runlength(
    @pdfio.Input::of_bytes(encoded, source="runlength"),
  )
  assert_eq(@pdfio.string_of_bytes(decoded), "aaabbbccccccdde")
}

///|
test "runlength literal chunk" {
  let original = @pdfio.bytes_of_string("abcdefg")
  let encoded = encode_runlength(original)
  let decoded = decode_runlength(
    @pdfio.Input::of_bytes(encoded, source="runlength"),
  )
  assert_eq(@pdfio.string_of_bytes(decoded), "abcdefg")
}
