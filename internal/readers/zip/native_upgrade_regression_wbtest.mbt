///|
async test "native upgrade ZIP cached entry honors a smaller request budget" {
  for limit in [1, 0, -1] {
    // A rejected request latches the archive's first failure. Each request
    // limit is an independent case, starting with the same populated cache.
    let archive = open_zip(build_store_zip_bytes([("a.txt", b"abcd")]))
    assert_eq(read_entry(archive, "a.txt", max_output_size=4), b"abcd")
    let cached = try
      read_entry(archive, "a.txt", max_output_size=limit) |> Ok
    catch {
      error => Err(error)
    }
    match cached {
      Err(InvalidStructure(message)) =>
        assert_true(message.contains("max_output_size"))
      _ => fail("a cached ZIP entry must honor the current output budget")
    }
  }
}

///|
async test "native upgrade ZIP transient entry rejects an undersized budget" {
  let archive = open_zip(build_store_zip_bytes([("a.txt", b"abcd")]))
  let transient = try
    read_entry_transient(archive, "a.txt", max_output_size=1) |> Ok
  catch {
    error => Err(error)
  }
  match transient {
    Err(InvalidStructure(message)) =>
      assert_true(message.contains("max_output_size"))
    _ => fail("a transient ZIP entry must honor the current output budget")
  }
}
