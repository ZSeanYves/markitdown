///|
test "UTF16 preserves explicit endian, BOM, NUL and supplementary characters" {
  let text = "\u{FEFF}A\u{0000}中😀"
  let le = b"\xff\xfeA\x00\x00\x00\x2d\x4e\x3d\xd8\x00\xde"
  let be = b"\xfe\xff\x00A\x00\x00\x4e\x2d\xd8\x3d\xde\x00"
  inspect(@utf16.decode(le, ignore_bom=false, endianness=Little), content="\u{FEFF}A\u{0000}中😀")
  inspect(@utf16.decode(be, ignore_bom=false, endianness=Big), content="\u{FEFF}A\u{0000}中😀")
  assert_eq(@utf16.encode(text, bom=false, endianness=Little), le)
  assert_eq(@utf16.encode(text, bom=false, endianness=Big), be)
}

///|
test "UTF16 strict rejection retains malformed and truncated input boundaries" {
  for bytes in [b"\x41", b"\x00\xd8", b"\x00\xdc", b"\x00\xd8A\x00", b"\xff\xfe\x00"] {
    let accepted = try {
      ignore(@utf16.decode(bytes, ignore_bom=false, endianness=Little))
      true
    } catch { _ => false }
    assert_false(accepted)
  }
  inspect(@utf16.decode(b"", ignore_bom=false), content="")
}

///|
test "UTF16 BMP corpus preserves the bytes used by RAG identifiers" {
  for code in 0..<65536 {
    if code >= 0xD800 && code <= 0xDFFF { continue }
    let text = String::from_array([code.unsafe_to_char()])
    let le = Bytes::from_array([(code & 255).to_byte(), (code >> 8).to_byte()])
    let be = Bytes::from_array([(code >> 8).to_byte(), (code & 255).to_byte()])
    assert_eq(@utf16.encode(text, bom=false, endianness=Little), le)
    assert_eq(@utf16.decode(le, ignore_bom=false, endianness=Little), text)
    assert_eq(@utf16.decode(be, ignore_bom=false, endianness=Big), text)
  }
}

///|
test "legacy and candidate deflate/zlib cross-decode representative payloads" {
  let large = Bytes::makei(140000, i => ((i * 29 + i / 7) & 255).to_byte())
  for source in [b"", b"hello\x00world", @utf8.encode("中文、名前、😀"), large] {
    assert_eq(@flate.inflate_exact(@old_flate.compress(source)), source)
    assert_eq(@old_flate.decompress(@flate.deflate_all(source)), source)
    assert_eq(@zlib.zlib_decompress(@old_zlib.compress(source)), source)
    assert_eq(@old_zlib.decompress(@zlib.zlib_compress(source)), source)
  }
}

///|
test "candidate incremental inflater handles tiny chunks with bounded output" {
  let source = Bytes::makei(100000, i => ((i * 13 + i / 19) & 255).to_byte())
  let compressed = @old_flate.compress(source)
  for input_chunk in [1, 7, 65536] {
    let decoder = @flate.Inflater()
    let output = FixedArray::make(31, b'\x00')
    let collected = Buffer()
    let mut position = 0
    let mut steps = 0
    for ;; {
      let end = (position + input_chunk).min(compressed.length())
      let status = decoder.step(compressed[position:end], output.mut_view(), end=end == compressed.length())
      position += decoder.last_consumed()
      let count = decoder.last_produced()
      assert_true(count <= 31)
      for i in 0..<count { collected.write_byte(output[i]) }
      steps += 1
      assert_true(steps < 200000)
      if status is Done { break }
    }
    assert_eq(position, compressed.length())
    assert_eq(collected.to_bytes(), source)
  }
}

///|
test "candidate output ceiling, trailing bytes, truncation and CRC" {
  let compressed = @old_flate.compress(Bytes::make(100000, b'A'))
  let limited = try {
    ignore(@flate.inflate_all_limited(compressed, max_output=4096))
    false
  } catch {
    @flate.InflateError(OutputLimitExceeded, _) => true
    _ => false
  }
  assert_true(limited)
  let trailing = compressed.to_array()
  trailing.push(0)
  let rejected = try {
    ignore(@flate.inflate_exact(Bytes::from_array(trailing)))
    false
  } catch { @flate.InflateError(TrailingData, _) => true; _ => false }
  assert_true(rejected)
  let truncated = try {
    ignore(@flate.inflate_exact(compressed[:compressed.length() - 1].to_owned()))
    false
  } catch { _ => true }
  assert_true(truncated)
  assert_eq(@checksum.crc32(b"123456789"), 0xCBF43926U)
}
