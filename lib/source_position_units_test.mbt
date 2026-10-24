///|
fn position_store_zip(name : Bytes, payload : Bytes) -> Bytes {
  let out : Array[Byte] = []
  let u16 = fn(value : Int32) {
    for shift in [0, 8] {
      out.push(((value >> shift) & 255).to_byte())
    }
  }
  let u32 = fn(value : UInt32) {
    for shift in [0, 8, 16, 24] {
      out.push(((value >> shift) & 255U).to_byte())
    }
  }
  let mut crc = 0xffffffffU
  for byte in payload {
    crc = crc ^ byte.to_uint()
    for _ in 0..<8 {
      crc = if (crc & 1U) == 1U { (crc >> 1) ^ 0xedb88320U } else { crc >> 1 }
    }
  }
  crc = crc ^ 0xffffffffU
  u32(0x04034b50U)
  for value in [20, 0, 0, 0, 0] {
    u16(value)
  }
  u32(crc)
  u32(payload.length().reinterpret_as_uint())
  u32(payload.length().reinterpret_as_uint())
  u16(name.length())
  u16(0)
  out.append(name.to_array())
  out.append(payload.to_array())
  let offset = out.length()
  u32(0x02014b50U)
  for value in [20, 20, 0, 0, 0, 0] {
    u16(value)
  }
  u32(crc)
  u32(payload.length().reinterpret_as_uint())
  u32(payload.length().reinterpret_as_uint())
  for value in [name.length(), 0, 0, 0, 0] {
    u16(value)
  }
  u32(0U)
  u32(0U)
  out.append(name.to_array())
  let central_size = out.length() - offset
  u32(0x06054b50U)
  for value in [0, 0, 1, 1] {
    u16(value)
  }
  u32(central_size.reinterpret_as_uint())
  u32(offset.reinterpret_as_uint())
  u16(0)
  Bytes::from_array(out)
}

///|
async test "public JSON scalar source refs distinguish normalized UTF8 from physical BOM CRLF bytes on every input route" {
  let text = "\u{FEFF}\r\n\"é😀\\u0061\"\r\n"
  // UTF8 literals let the oracle retain physical/decoded views separately.
  let bytes = b"\xEF\xBB\xBF\r\n\"\xC3\xA9\xF0\x9F\x98\x80\\u0061\"\r\n"
  let options = @lib.ConvertOptions::default()
    .with_mode(Stream)
    .with_format_hint(Some("json"))
    .with_output_mode(Rag)
  let inputs = [
    @lib.Input::from_text(text, source_name="units.json"),
    @lib.Input::from_bytes(bytes, source_name="units.json"),
    @lib.Input::from_async_reader(
      async fn(offset, length) {
        @async.pause()
        let start = offset.to_int()
        let end = (start + length.min(1)).min(bytes.length())
        Ok(bytes.exact_view(start~, end~).to_owned())
      },
      size=bytes.length().to_int64(),
      source_name="units.json",
    ),
  ]
  for input in inputs {
    let output = @lib.convert(input, options~).unwrap()
    let seen : Map[String, Bool] = Map([])
    for chunk in output.chunks {
      for source in chunk.source_refs {
        if source.byte_start is Some(start) && source.byte_end is Some(end) {
          let pointer = source.json_pointer.unwrap()
          assert_eq(pointer, "/")
          // The independent literal byte positions include BMP/non-BMP widths.
          assert_eq(start, 1)
          assert_eq(end, 15)
          assert_true(end < bytes.length())
          assert_eq(
            source.extra.get("byte_basis"),
            Some("normalized_decoded_utf8"),
          )
          assert_eq(
            source.extra.get("byte_normalization"),
            Some("leading_bom_removed_crlf_to_lf"),
          )
          seen.set(pointer, true)
        }
      }
    }
    assert_true(seen.contains("/"))
  }
  for
    input in [
      @lib.Input::from_bytes(b"\xFF\xFE[\x00]\x00", source_name="utf16.json"),
      @lib.Input::from_bytes(b"\xC3\x28", source_name="invalid.json"),
    ] {
    match @lib.convert(input, options~) {
      Err(ParseFailed(message)) => assert_true(message.contains("utf8"))
      _ => fail("invalid encoded JSON must be a controlled decode failure")
    }
  }
}

///|
async test "public nested malformed XML range stays relative to decoded entry not ZIP physical offsets" {
  let payload = b"\xEF\xBB\xBF<r>\xC3\xA9\xF0\x9F\x98\x80\r\n<broken"
  let archive = position_store_zip(b"entry.xml", payload)
  let output = @lib.convert(
    @lib.Input::from_bytes(archive, source_name="outer.zip"),
    options=@lib.ConvertOptions::default().with_output_mode(Rag),
  ).unwrap()
  let mut found = false
  for chunk in output.chunks {
    for source in chunk.source_refs {
      if source.entry_path == Some("entry.xml") && source.byte_end is Some(end) {
        assert_eq(source.container_path, Some("outer.zip"))
        assert_eq(source.byte_start, Some(0))
        assert_eq(end, payload.length() - 3)
        assert_eq(
          source.extra.get("byte_basis"),
          Some("normalized_decoded_utf8"),
        )
        assert_eq(
          source.extra.get("byte_normalization"),
          Some("leading_bom_removed"),
        )
        assert_true(end < archive.length())
        found = true
      }
    }
  }
  assert_true(found)
}
