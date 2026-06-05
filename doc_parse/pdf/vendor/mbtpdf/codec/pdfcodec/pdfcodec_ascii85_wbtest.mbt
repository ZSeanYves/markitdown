///|
test "ascii85 roundtrip" {
  let original = @pdfio.bytes_of_string("Hello")
  let encoded = encode_ascii85(original)
  let decoded = decode_ascii85(
    @pdfio.Input::of_bytes(encoded, source="ascii85"),
  )
  assert_eq(@pdfio.string_of_bytes(decoded), "Hello")
}

///|
test "ascii85 zero tuple" {
  let zeros = [(0).to_byte(), (0).to_byte(), (0).to_byte(), (0).to_byte()]
  let encoded = encode_ascii85(zeros)
  assert_true(@pdfio.string_of_bytes(encoded).contains("z"))
  let decoded = decode_ascii85(
    @pdfio.Input::of_bytes(encoded, source="ascii85"),
  )
  assert_eq(decoded.length(), 4)
  for b in decoded {
    assert_eq(b, (0).to_byte())
  }
}
