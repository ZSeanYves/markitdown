///|
async test "unknown-size ZIP reads a suspending short reader without retaining archive bytes" {
  let bytes = @dzip.build_store_zip_bytes([
    ("padding.bin", Bytes::make(160_000, b'x')),
    ("body.txt", b"body"),
  ])
  let ranges : Array[(Int64, Int32)] = []
  let reader = @input.make_async_input_reader(async fn(offset, length) {
    @async.sleep(0)
    ranges.push((offset, length))
    if offset >= bytes.length().to_int64() {
      return Ok(b"")
    }
    let start = offset.to_int()
    let end = (start + length.min(7)).min(bytes.length())
    Ok(bytes[start:end].to_owned())
  })
  let source = @input.input_from_reader(reader, source_name="short.zip")
  let session = @input.begin_input_session(source, max_bytes=200_000L)
  defer @input.end_input_session(session)
  let prepared = prepare_zip_from_source(session.source).unwrap()
  assert_eq(prepared.archive.bytes, b"")
  assert_true(@input.input_bytes(prepared.prepared_source) is None)
  assert_eq(@dzip.read_entry(prepared.archive, "body.txt"), b"body")
  assert_true(ranges.all(range => range.1 <= 65557))
  assert_true(ranges.any(range => range.0 > 100_000L))
}

///|
async test "unknown-size ZIP rejects its effective input limit before opening the archive" {
  let bytes = @dzip.build_store_zip_bytes([("body.txt", b"body")])
  let reader = @input.make_async_input_reader(async fn(offset, length) {
    @async.sleep(0)
    if offset >= bytes.length().to_int64() {
      return Ok(b"")
    }
    let start = offset.to_int()
    Ok(bytes[start:(start + length).min(bytes.length())].to_owned())
  })
  let session = @input.begin_input_session(
    @input.input_from_reader(reader, source_name="limited.zip"),
    max_bytes=32L,
  )
  defer @input.end_input_session(session)
  let prepared = prepare_zip_from_source(session.source)
  match prepared {
    Err(message) => assert_true(message.contains("input byte limit exceeded"))
    Ok(_) =>
      fail("unknown-size archive must respect the effective source limit")
  }
}
