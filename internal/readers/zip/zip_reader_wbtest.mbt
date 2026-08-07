///|
fn wb_bytes_of_string(s : String) -> Array[Byte] {
  let out : Array[Byte] = []
  for ch in s.to_array() {
    out.push(ch.to_int().to_byte())
  }
  out
}

///|
fn wb_crc32_update_uint(crc : UInt, value : UInt) -> UInt {
  let mut acc = UInt::lxor(crc, value)
  let mut i = 0
  while i < 8 {
    if UInt::land(acc, 1) != 0 {
      acc = UInt::lxor(acc >> 1, 0xEDB88320)
    } else {
      acc = acc >> 1
    }
    i += 1
  }
  acc
}

///|
fn wb_crc32_of_string(s : String) -> Int {
  let mut crc : UInt = 0xFFFFFFFF
  for ch in s.to_array() {
    crc = wb_crc32_update_uint(crc, ch.to_int().reinterpret_as_uint())
  }
  UInt::lxor(crc, 0xFFFFFFFF).reinterpret_as_int()
}

///|
fn wb_append_u16_le(out : Array[Byte], value : Int) -> Unit {
  out.push((value & 0xFF).to_byte())
  out.push(((value >> 8) & 0xFF).to_byte())
}

///|
fn wb_append_u32_le(out : Array[Byte], value : Int) -> Unit {
  out.push((value & 0xFF).to_byte())
  out.push(((value >> 8) & 0xFF).to_byte())
  out.push(((value >> 16) & 0xFF).to_byte())
  out.push(((value >> 24) & 0xFF).to_byte())
}

///|
fn wb_add_entry(
  out : Array[Byte],
  central : Array[(String, Int, Int, Int)],
  name : String,
  data : String,
) -> Unit {
  let local_offset = out.length()
  let name_bytes = wb_bytes_of_string(name)
  let data_bytes = wb_bytes_of_string(data)
  let crc32 = wb_crc32_of_string(data)

  wb_append_u32_le(out, 0x04034b50)
  wb_append_u16_le(out, 20)
  wb_append_u16_le(out, 0)
  wb_append_u16_le(out, 0)
  wb_append_u16_le(out, 0)
  wb_append_u16_le(out, 0)
  wb_append_u32_le(out, crc32)
  wb_append_u32_le(out, data_bytes.length())
  wb_append_u32_le(out, data_bytes.length())
  wb_append_u16_le(out, name_bytes.length())
  wb_append_u16_le(out, 0)
  for b in name_bytes {
    out.push(b)
  }
  for b in data_bytes {
    out.push(b)
  }

  central.push((name, data_bytes.length(), local_offset, crc32))
}

///|
fn wb_build_store_zip(entries : Array[(String, String)]) -> Bytes {
  let out : Array[Byte] = []
  let central : Array[(String, Int, Int, Int)] = []

  for entry in entries {
    let (name, data) = entry
    wb_add_entry(out, central, name, data)
  }

  let cd_offset = out.length()
  for item in central {
    let (name, size, local_offset, crc32) = item
    let name_bytes = wb_bytes_of_string(name)
    wb_append_u32_le(out, 0x02014b50)
    wb_append_u16_le(out, 20)
    wb_append_u16_le(out, 20)
    wb_append_u16_le(out, 0)
    wb_append_u16_le(out, 0)
    wb_append_u16_le(out, 0)
    wb_append_u16_le(out, 0)
    wb_append_u32_le(out, crc32)
    wb_append_u32_le(out, size)
    wb_append_u32_le(out, size)
    wb_append_u16_le(out, name_bytes.length())
    wb_append_u16_le(out, 0)
    wb_append_u16_le(out, 0)
    wb_append_u16_le(out, 0)
    wb_append_u16_le(out, 0)
    wb_append_u32_le(out, 0)
    wb_append_u32_le(out, local_offset)
    for b in name_bytes {
      out.push(b)
    }
  }
  let cd_size = out.length() - cd_offset

  wb_append_u32_le(out, 0x06054b50)
  wb_append_u16_le(out, 0)
  wb_append_u16_le(out, 0)
  wb_append_u16_le(out, central.length())
  wb_append_u16_le(out, central.length())
  wb_append_u32_le(out, cd_size)
  wb_append_u32_le(out, cd_offset)
  wb_append_u16_le(out, 0)

  Bytes::from_array(out)
}

///|
test "zip reader private caches record inspect and entry reuse" {
  let archive = open_zip(
    wb_build_store_zip([
      ("alpha/readme.md", "# Alpha\n\nBody\n"),
      ("beta/page.html", "<html><body><h1>Beta</h1></body></html>"),
    ]),
  ) catch {
    e => fail("open wb zip failed: " + e.to_string())
  }

  ignore(inspect_zip_archive(archive))
  ignore(inspect_zip_archive(archive))
  ignore(
    read_entry(archive, "alpha/readme.md") catch {
      e => fail("first read_entry failed: " + e.to_string())
    },
  )
  ignore(
    read_entry(archive, "alpha/readme.md") catch {
      e => fail("second read_entry failed: " + e.to_string())
    },
  )

  assert_eq(archive.inspect_miss_count.val, 1)
  assert_eq(archive.inspect_hit_count.val, 1)
  assert_eq(archive.read_miss_count.val, 1)
  assert_eq(archive.read_hit_count.val, 1)
  assert_eq(archive.read_entry_cache.length(), 1)
  assert_true(archive.inspect_cache.val is Some(_))
}

///|
test "zip reader repeated opens keep archive-local caches independent" {
  let bytes = wb_build_store_zip([
    ("cache/readme.md", "# Cache\n\nBody\n"),
    ("cache/page.html", "<html><body><h1>Cache</h1></body></html>"),
  ])
  let first = open_zip(bytes) catch {
    e => fail("first open_zip failed: " + e.to_string())
  }
  ignore(inspect_zip_archive(first))
  let second = open_zip(bytes) catch {
    e => fail("second open_zip failed: " + e.to_string())
  }
  ignore(inspect_zip_archive(second))

  assert_eq(first.inspect_miss_count.val, 1)
  assert_eq(first.inspect_hit_count.val, 0)
  assert_eq(second.inspect_miss_count.val, 1)
  assert_eq(second.inspect_hit_count.val, 0)
}

///|
test "zip transient reads validate payload without populating cache" {
  let archive = open_zip(
    wb_build_store_zip([("large/sheet.xml", "<sheet>payload</sheet>")]),
  ) catch {
    e => fail("open transient zip failed: " + e.to_string())
  }
  let first = read_entry_transient(archive, "large/sheet.xml") catch {
    e => fail("transient read failed: " + e.to_string())
  }
  let second = read_entry_transient(archive, "large/sheet.xml") catch {
    e => fail("second transient read failed: " + e.to_string())
  }
  assert_eq(first, second)
  assert_eq(archive.read_entry_cache.length(), 0)
  assert_eq(archive.read_hit_count.val, 0)
  assert_eq(archive.read_miss_count.val, 0)
}

///|
test "zip transient reads enforce the decoded output limit" {
  let archive = open_zip(
    wb_build_store_zip([("large/sheet.xml", "0123456789")]),
  ) catch {
    e => fail("open limited transient zip failed: " + e.to_string())
  }
  let result = try
    read_entry_transient(archive, "large/sheet.xml", max_output_size=4) |> Ok
  catch {
    e => Err(e)
  }
  match result {
    Err(InvalidStructure(message)) =>
      assert_true(message.contains("exceeds max_output_size"))
    Err(err) => fail("unexpected transient limit error: " + err.to_string())
    Ok(_) => fail("transient read should enforce max_output_size")
  }
  assert_eq(archive.read_entry_cache.length(), 0)
}

///|
test "zip seekable reader opens from tail and central directory" {
  let payload = wb_build_store_zip([("large/payload.bin", "x".repeat(70_000))])
  let reads : Array[(Int, Int)] = []
  let archive = open_zip_reader(payload.length(), fn(offset, length) {
    reads.push((offset, length))
    if offset < 0 || length < 0 || offset > payload.length() {
      return Err("outside payload")
    }
    Ok(payload[offset:(offset + length).min(payload.length())].to_owned())
  }) catch {
    e => fail("open seekable zip failed: " + e.to_string())
  }
  assert_eq(archive.bytes.length(), 0)
  assert_eq(reads[0].1, 65535 + 22)
  assert_true(reads[0].1 < payload.length())
  let decoded = read_entry_transient(archive, "large/payload.bin") catch {
    e => fail("seekable entry read failed: " + e.to_string())
  }
  assert_eq(decoded.length(), 70_000)
  assert_eq(decoded[0], 'x'.to_int().to_byte())
  assert_true(reads.length() >= 4)
}

///|
test "zip seekable reader rejects invalid size and reader contracts" {
  let undersized = try open_zip_reader(10, fn(_, _) { Ok(b"") }) |> Ok catch {
    e => Err(e)
  }
  match undersized {
    Err(UnexpectedEOF(_)) => ()
    _ => fail("undersized seekable ZIP should fail")
  }
  assert_true(read_zip_source_fully(fn(_, _) { Ok(b"") }, -1, 1) is Err(_))
  assert_true(read_zip_source_fully(fn(_, _) { Ok(b"") }, 0, 0) == Ok(b""))
  assert_true(
    read_zip_source_fully(fn(_, _) { Err("read failure") }, 0, 1) is Err(_),
  )
  assert_true(read_zip_source_fully(fn(_, _) { Ok(b"") }, 0, 1) is Err(_))
  assert_true(
    read_zip_source_fully(fn(_, _) { Ok(b"too long") }, 0, 1) is Err(_),
  )
}
