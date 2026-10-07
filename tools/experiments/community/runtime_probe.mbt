///|
async test "official file supports bounded random reads without moving the sequential cursor" {
  let dir = @fs.tmpdir(prefix="markitdown-random-")
  defer @fs.rmdir(dir, recursive=true)
  let path = dir + "/input"
  @fs.write_file(path, b"0123456789")
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  assert_eq(file.size(), 10L)
  assert_eq(file.read_exactly_at(3, position=5L), b"567")
  assert_eq(file.read_exactly(2), b"01")
  let buffer = FixedArray::make(4, b'?')
  assert_eq(file.read_at(buffer, position=9L), 1)
  assert_eq(buffer[0], b'9')
  assert_eq(buffer[1], b'?')
  assert_eq(file.read_at(buffer, position=10L), 0)
  assert_eq(file.read_at(buffer, position=100L), 0)
  let eof = try { ignore(file.read_exactly_at(3, position=9L)); false } catch { _ => true }
  assert_true(eof)
}

///|
async test "official file rejects writes to a readonly descriptor" {
  let dir = @fs.tmpdir(prefix="markitdown-write-failure-")
  defer @fs.rmdir(dir, recursive=true)
  let path = dir + "/input"
  @fs.write_file(path, b"original")
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  let failed = try { file.write(b"changed"); false } catch { _ => true }
  assert_true(failed)
  assert_eq(file.read_exactly_at(8, position=0L), b"original")
}

///|
async test "official file sync close and rename support replacing a complete output" {
  let dir = @fs.tmpdir(prefix="markitdown-atomic-")
  defer @fs.rmdir(dir, recursive=true)
  let target = dir + "/output"
  let temporary = dir + "/pending"
  @fs.write_file(target, "old")
  let file = @fs.open(temporary, mode=WriteOnly, create_mode=CreateNew)
  file.write("new")
  file.sync()
  file.close()
  assert_eq(@fs.read_file(target).text(), "old")
  @fs.rename(temporary, target, replace=true)
  assert_false(@fs.exists(temporary))
  assert_eq(@fs.read_file(target).text(), "new")
}

///|
async test "cancellation unwinds file close and nocancel temporary cleanup" {
  let dir = @fs.tmpdir(prefix="markitdown-cancel-")
  defer @fs.rmdir(dir, recursive=true)
  let temporary = dir + "/pending"
  let ready : @async.Queue[Unit] = @async.Queue(kind=Blocking(1))
  let closed = Ref(false)
  @async.with_task_group(async fn(group) {
    let task = group.spawn(async fn() {
      let file = @fs.open(temporary, mode=WriteOnly, create_mode=CreateNew)
      defer @fs.remove(temporary)
      defer { file.close(); closed.val = true }
      file.write("partial")
      ready.put(())
      @async.sleep(10000)
    })
    ready.get() |> ignore
    task.cancel()
  })
  assert_true(closed.val)
  assert_false(@fs.exists(temporary))
}

///|
async test "readers can suspend between short reads without consuming beyond demand" {
  let reads = Ref(0)
  let reader : async (Int, Int) -> Bytes = async fn(offset, length) {
    reads.val += 1
    @async.pause()
    let input = b"abcdef"
    input[offset:(offset + length.min(2)).min(input.length())].to_owned()
  }
  let collected = Buffer()
  while collected.length() < 5 {
    let chunk = reader(collected.length(), 5 - collected.length())
    assert_true(chunk.length() > 0)
    collected.write_bytes(chunk)
  }
  assert_eq(collected.to_bytes(), b"abcde")
  assert_eq(reads.val, 3)
}

///|
async test "async pull and sink preserve backpressure across suspension and write failure" {
  let consumed = Ref(0)
  let written = Ref(0)
  let next : async () -> Int = async fn() {
    consumed.val += 1
    @async.pause()
    consumed.val
  }
  let sink : async (Int) -> Result[Unit, String] = async fn(value) {
    assert_eq(consumed.val, written.val + 1)
    @async.pause()
    if value == 3 { return Err("synthetic write failure") }
    written.val += 1
    Ok(())
  }
  for _ in 0..<10 {
    if sink(next()) is Err(_) { break }
  }
  assert_eq(consumed.val, 3)
  assert_eq(written.val, 2)
}
