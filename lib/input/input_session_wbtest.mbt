///|
async test "input session reuses Path handles and closes only at the outer boundary" {
  let session = begin_input_session(input_from_path("lib/input/README.md"))
  let first = open_source_cursor(session.source).unwrap()
  let prefix = source_cursor_read_at(first, 0L, length=8).unwrap()
  let nested = begin_input_session(session.source)
  let second = open_source_cursor(nested.source).unwrap()
  assert_eq(session.source.session.unwrap().cursors.length(), 1)
  end_input_session(nested)
  assert_eq(source_cursor_read_at(second, 0L, length=8), Ok(prefix))
  end_input_session(session)
  end_input_session(session)
  assert_true(source_cursor_read_at(first, 0L, length=8) is Err(_))
  assert_true(open_source_cursor(session.source) is Err(_))
}

///|
async test "input session cache still checks each requested byte ceiling" {
  let session = begin_input_session(input_from_path("lib/input/README.md"))
  defer end_input_session(session)
  let cursor = open_source_cursor(session.source).unwrap()
  assert_true(source_cursor_read_at(cursor, 0L, length=1) is Ok(_))
  assert_true(open_source_cursor(session.source, max_bytes=1L) is Err(_))
  assert_true(source_cursor_read_at(cursor, 0L, length=1) is Err(_))
  let bounded = begin_input_session(
    input_from_path("lib/input/README.md"),
    max_bytes=1L,
  )
  defer end_input_session(bounded)
  assert_true(open_source_cursor(bounded.source) is Err(_))
}

///|
async test "input session leaves caller Reader resources usable" {
  let calls = Ref(0)
  let reader = make_input_reader(
    fn(_, _) {
      calls.val += 1
      Ok(b"x")
    },
    size=1L,
  )
  let source = input_from_reader(reader)
  let session = begin_input_session(source)
  let cursor = open_source_cursor(session.source).unwrap()
  assert_eq(source_cursor_read_at(cursor, 0L, length=1), Ok(b"x"))
  end_input_session(session)
  assert_eq((reader.read_at)(0L, 1), Ok(b"x"))
  assert_eq(calls.val, 2)
}

///|
async test "native Path cursor distinguishes early EOF from a successful end" {
  let path = "_build/input-session-truncate.txt"
  @fs.write_string_to_file(path, "initial bytes")
  defer @fs.remove_file(path)
  let cursor = open_source_cursor(input_from_path(path)).unwrap()
  defer source_cursor_close(cursor)
  @fs.write_string_to_file(path, "")
  match source_cursor_read_at(cursor, 0L, length=8) {
    Err(message) =>
      assert_true(message.contains("reader ended before declared size"))
    Ok(_) => fail("truncated input must not become a successful empty read")
  }
}

///|
async test "input session retains hard Reader failures after a caller catches them" {
  let source = input_from_reader(
    make_input_reader(fn(_, _) { Err("injected I/O failure") }),
  )
  let session = begin_input_session(source)
  defer end_input_session(session)
  assert_true(read_input_bytes(session.source) is Err(_))
  match input_session_error(session) {
    Some(message) => assert_true(message.contains("injected I/O failure"))
    None => fail("a caught read error must remain fatal to the conversion")
  }
}
