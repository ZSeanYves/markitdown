///|
suberror AsyncZipProbeError {
  InjectedReadFailure(String)
}

///|
impl Show for AsyncZipProbeError with fn to_string(self) {
  match self {
    InjectedReadFailure(message) => "injected ZIP reader error: " + message
  }
}

///|
impl Show for AsyncZipProbeError with fn output(self, logger) {
  logger.write_string(Show::to_string(self))
}

///|
async test "ZIP reader converts a callback exception into its controlled read error" {
  let bytes = build_store_zip_bytes([("body.txt", b"body")])
  let opened = try
    open_zip_reader(bytes.length(), async fn(_, _) {
      @async.sleep(0)
      raise InjectedReadFailure("injected read exception")
    })
    |> Ok
  catch {
    error => Err(error)
  }
  match opened {
    Err(DecodeFailed(message)) =>
      assert_true(message.contains("injected read exception"))
    _ => fail("callback exceptions must become controlled ZIP read failures")
  }
}

///|
async test "ZIP chunk visitor waits for an asynchronous consumer before reading again" {
  let payload = b"abcdefghijklmnopqrstuvwxyz012345"
  let bytes = build_store_zip_bytes([("body.txt", payload)])
  let busy = Ref(false)
  let reads = Ref(0)
  let archive = open_zip_reader(bytes.length(), async fn(offset, length) {
    assert_true(!busy.val)
    reads.val += 1
    @async.sleep(0)
    Ok(bytes[offset:(offset + length).min(bytes.length())].to_owned())
  })
  let chunks : Array[Bytes] = []
  visit_inflated_entry_chunks(archive, "body.txt", chunk_size=8, async fn(
    chunk,
  ) {
    busy.val = true
    let reads_before = reads.val
    @async.sleep(1)
    assert_eq(reads.val, reads_before)
    chunks.push(chunk)
    busy.val = false
    Ok(())
  }).unwrap()
  assert_eq(chunks.length(), 4)
  assert_eq(chunks[0] + chunks[1] + chunks[2] + chunks[3], payload)
}
