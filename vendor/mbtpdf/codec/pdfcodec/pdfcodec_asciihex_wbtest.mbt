///|
test "asciihex roundtrip" {
  let original = @pdfio.bytes_of_string("Hello")
  let encoded = encode_asciihex(original)
  let decoded = decode_asciihex(
    @pdfio.Input::of_bytes(encoded, source="asciihex"),
  )
  assert_eq(@pdfio.string_of_bytes(decoded), "Hello")
}

///|
test "asciihex odd nibble" {
  let encoded = @pdfio.bytes_of_string("F>")
  let decoded = decode_asciihex(
    @pdfio.Input::of_bytes(encoded, source="asciihex"),
  )
  assert_eq(decoded.length(), 1)
  assert_eq(decoded[0], (240).to_byte())
}
