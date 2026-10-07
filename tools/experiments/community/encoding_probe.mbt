///|
test "portable Shift_JIS representative corpus" {
  let cases : Array[(Bytes, String)] = [
    (b"A", "A"),
    (Bytes::from_array([0xA6].map(Int::to_byte)), "ｦ"),
    (Bytes::from_array([0x81, 0x40].map(Int::to_byte)), "　"),
    (Bytes::from_array([0x96, 0xBC, 0x91, 0x4F].map(Int::to_byte)), "名前"),
  ]
  for case_ in cases {
    let (text, had_replacements) = @encoding_sjis.decode(src=case_.0)
    assert_false(had_replacements)
    assert_eq(text, case_.1)
  }
}

///|
test "portable Shift_JIS replacement flag covers unsupported and malformed bytes" {
  for bytes in [
    Bytes::from_array([0xFA, 0x40].map(Int::to_byte)),
    Bytes::from_array([0x80].map(Int::to_byte)),
    Bytes::from_array([0x82].map(Int::to_byte)),
    Bytes::from_array([0x82, 0x20].map(Int::to_byte)),
  ] {
    let (_, had_replacements) = @encoding_sjis.decode(src=bytes)
    assert_true(had_replacements)
  }
}

///|
test "portable Shift_JIS streaming decoder preserves a split character" {
  let decoder = @encoding_sjis.new_decoder()
  assert_eq(
    decoder.decode_to_string(
      src=Bytes::from_array([0x82].map(Int::to_byte)),
      false,
    ),
    "",
  )
  assert_eq(
    decoder.decode_to_string(
      src=Bytes::from_array([0xA0].map(Int::to_byte)),
      true,
    ),
    "あ",
  )
  assert_false(decoder.had_replacements())
}
