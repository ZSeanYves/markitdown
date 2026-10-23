///|
test "PDF byte search preserves empty needle offset and binary marker boundaries" {
  for
    (haystack, needle, start, expected) in [
      (b"", b"", 0, Some(0)),
      (b"abc", b"", -1, Some(-1)),
      (b"abc", b"", 4, Some(4)),
      (b"a", b"abc", -1, None),
      (b"", b"a", 0, None),
      (b"abc", b"a", 4, None),
      (b"abc", b"a", 3, None),
      (b"a\x00endobjendstream\xff", b"\x00endobj", 0, Some(1)),
      (b"a\x00endobjendstream\xff", b"endobj", 2, Some(2)),
      (b"a\x00endobjendstream\xff", b"endobj", 3, None),
      (b"xendobjxendobj", b"endobj", 2, Some(8)),
      (b"aaaaab", b"aaab", 0, Some(2)),
    ] {
    assert_eq(pdf_find_bytes(haystack, needle, start), expected)
  }
  let backing = b"prefix\x00endobj\xffsuffix"
  // BytesView offsets are local and cannot see outside the selected range.
  assert_eq(pdf_find_bytes(backing[6:14], b"endobj", 0), Some(1))
  assert_eq(pdf_find_bytes(backing[6:14], b"suffix", 0), None)
  assert_eq(pdf_find_bytes(backing[7:10], b"endobj", 0), None)
  assert_eq(pdf_byte_string(backing[6:14]), "\u{0000}endobjÿ")
}

///|
test "PDF range search agrees with frozen legacy matching on sliced binary data" {
  // Retain the original allocation-heavy matcher as a test-only differential
  // oracle. It is deliberately not a second production search implementation.
  fn legacy(bytes : Bytes, needle : Bytes, start : Int32) -> Int32? {
    let haystack = bytes.to_array()
    let target = needle.to_array()
    if target.length() == 0 {
      return Some(start)
    }
    let mut index = start
    while index + target.length() <= haystack.length() {
      let mut matched = true
      for offset in 0..<target.length() {
        if haystack[index + offset] != target[offset] {
          matched = false
          break
        }
      }
      if matched {
        return Some(index)
      }
      index += 1
    }
    None
  }
  for
    backing in [
      b"", b"a", b"aaaaab", b"\x00endobj\xffendstream\x00", b"\xff\x80\x00\xff\x80",
    ] {
    for left in 0..<=backing.length() {
      for right in left..<=backing.length() {
        let view = backing[left:right]
        for
          needle in [
            b"", b"a", b"aaab", b"end", b"endobj", b"endstream", b"\x00", b"\xff",
            b"\xff\x80",
          ] {
          for start in 0..<=(view.length() + 1) {
            assert_eq(
              pdf_find_bytes(view, needle, start),
              legacy(view.to_owned(), needle, start),
            )
          }
        }
      }
    }
  }
  let all = Bytes::makei(256, i => i.to_byte())
  let text = pdf_byte_string(all)
  assert_eq(text.length(), 256)
  for i in 0..<256 {
    assert_eq(text[i].to_int(), i)
  }
}

///|
test "PDF borrowed body parsing keeps first binary endobj and exact stream spans" {
  let compressed = @zlib.zlib_compress(b"\x0c")
  for separator in [b"\n", b"\r\n"] {
    let object = framing_test_object(
      compressed,
      "/Length " + compressed.length().to_string(),
      separator,
    )
    let slice = object.stream.unwrap()
    assert_eq(slice.primary_bytes, compressed)
    assert_eq(framing_test_decode(object).unwrap(), b"\x0c")
  }
  let bytes = b"1 0 obj\n<< /Length 16 >>\nstream\nA\x00endobj B endstream\nendobj"
  // Preserve the legacy first-endobj parser policy rather than silently using
  // a different marker finder or searching past a binary marker substring.
  assert_true(pdf_parse_indirect_object_at(bytes, 0) is Err(ParseFailed(_)))
}
