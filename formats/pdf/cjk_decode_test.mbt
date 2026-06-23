///|
test "pdf native GB2312-first decoder handles SimFang target bytes" {
  let bytes = [
    0xC8, 0xAB, 0x20, 0xCA, 0xC0, 0x20, 0xBD, 0xE7, 0x20, 0xCE, 0xDE, 0xB2, 0xFA,
    0xD5, 0xDF, 0xA3, 0xAC, 0xC1, 0xAA, 0xBA, 0xCF, 0xC6, 0xF0, 0xC0, 0xB4, 0x20,
    0x41,
  ]
  let decoded = pdf_decode_gb2312_first_bytes(bytes)
  assert_eq(decoded.text, "全 世 界 无产者，联合起来 A")
  assert_eq(decoded.decoded_two_byte_count, 11)
  assert_eq(decoded.decoded_cjk_count, 10)
  assert_eq(decoded.invalid_byte_count, 0)
  assert_true(pdf_raw_cjk_decode_result_is_confident_gb2312(decoded))
}

///|
test "pdf native GB2312-first decoder handles XiaoBiaoSong target bytes" {
  let bytes = [0xC4, 0xBF, 0x20, 0xC2, 0xBC, 0x20, 0xB9, 0xD8, 0xD3, 0xDA]
  let decoded = pdf_decode_gb2312_first_bytes(bytes)
  assert_eq(decoded.text, "目 录 关于")
  assert_eq(decoded.decoded_two_byte_count, 4)
  assert_eq(decoded.decoded_cjk_count, 4)
  assert_eq(decoded.invalid_byte_count, 0)
  assert_true(pdf_raw_cjk_decode_result_is_confident_gb2312(decoded))
}

///|
test "pdf native GB2312-first decoder preserves ascii without forcing CJK success" {
  let decoded = pdf_decode_gb2312_first_bytes([
    'H'.to_int(),
    'e'.to_int(),
    'l'.to_int(),
    'l'.to_int(),
    'o'.to_int(),
    ' '.to_int(),
    'A'.to_int(),
  ])
  assert_eq(decoded.text, "Hello A")
  assert_eq(decoded.decoded_two_byte_count, 0)
  assert_eq(decoded.decoded_cjk_count, 0)
  assert_eq(decoded.invalid_byte_count, 0)
  assert_true(!pdf_raw_cjk_decode_result_is_confident_gb2312(decoded))
}

///|
test "pdf native GB2312-first decoder fails soft on invalid bytes" {
  let decoded = pdf_decode_gb2312_first_bytes([0x81, 0x3F])
  assert_eq(decoded.text, "")
  assert_eq(decoded.invalid_byte_count, 2)
  assert_true(!pdf_raw_cjk_decode_result_is_confident_gb2312(decoded))
}

///|
test "pdf native GB2312-first decoder covers characters outside observed samples" {
  let decoded = pdf_decode_gb2312_first_bytes([
    0xD6, 0xD0, 0xCE, 0xC4, 0xB2, 0xE2, 0xCA, 0xD4, 0xB9, 0xFA,
  ])
  assert_eq(decoded.text, "中文测试国")
  assert_eq(decoded.decoded_two_byte_count, 5)
  assert_eq(decoded.decoded_cjk_count, 5)
  assert_eq(decoded.invalid_byte_count, 0)
}

///|
test "pdf native GB2312-first decoder rejects Big5-like invalid pair under GB2312" {
  let decoded = pdf_decode_gb2312_first_bytes([0xA4, 0x40])
  assert_eq(decoded.text, "")
  assert_eq(decoded.invalid_byte_count, 2)
  assert_true(!pdf_raw_cjk_decode_result_is_confident_gb2312(decoded))
}
