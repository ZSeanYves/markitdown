///|
async test "memory cursor clips large lengths without integer wraparound" {
  let cursor = open_source_cursor(input_from_bytes(b"abc")).unwrap()
  assert_eq(source_cursor_read_at(cursor, 1L, length=2147483647), Ok(b"bc"))
  assert_eq(
    source_cursor_view_at(cursor, 2, 2147483647).unwrap().to_owned(),
    b"c",
  )
}

///|
async test "Path cursors reject embedded NUL characters" {
  assert_true(
    open_source_cursor(input_from_path("lib/input/README.md\u{0}ignored"))
    is Err(_),
  )
  let invalid_path = String::from_array([(0xD800).unsafe_to_char(), 'A'])
  assert_true(open_source_cursor(input_from_path(invalid_path)) is Err(_))
  assert_true(input_source_size(input_from_path(invalid_path)) is Err(_))
}

///|
async test "Path size metadata errors remain fatal to the input session" {
  let session = begin_input_session(
    input_from_path("lib/input/README.md/child"),
  )
  defer end_input_session(session)
  assert_true(input_source_size(session.source) is Err(_))
  assert_true(input_session_error(session) is Some(_))
}

///|
async test "nested Path sessions honor a smaller request ceiling after a cache hit" {
  let outer = begin_input_session(input_from_path("lib/input/README.md"))
  defer end_input_session(outer)
  let cursor = open_source_cursor(outer.source).unwrap()
  assert_true(source_cursor_read_at(cursor, 0L, length=1) is Ok(_))
  let nested = begin_input_session(outer.source, max_bytes=1L)
  defer end_input_session(nested)
  match open_source_cursor(nested.source) {
    Err(message) => assert_true(message.contains("input byte limit exceeded"))
    Ok(_) =>
      fail("a cached Path handle must not bypass a nested request ceiling")
  }
}

///|
async test "a caught cursor byte ceiling error remains fatal to its session" {
  let session = begin_input_session(input_from_path("lib/input/README.md"))
  defer end_input_session(session)
  assert_true(open_source_cursor(session.source) is Ok(_))
  assert_true(open_source_cursor(session.source, max_bytes=1L) is Err(_))
  match input_session_error(session) {
    Some(message) => assert_true(message.contains("input byte limit exceeded"))
    None => fail("a caught resource error must not allow format fallback")
  }
}

///|
async test "known-size Reader cursors reject premature empty reads" {
  let session = begin_input_session(
    input_from_reader(
      make_input_reader(
        fn(offset, _) { if offset == 0L { Ok(b"a") } else { Ok(b"") } },
        size=4L,
      ),
    ),
  )
  defer end_input_session(session)
  let cursor = open_source_cursor(session.source).unwrap()
  assert_eq(source_cursor_read_at(cursor, 0L, length=4), Ok(b"a"))
  for result in [source_cursor_read_at(cursor, 1L, length=4)] {
    match result {
      Err(message) =>
        assert_true(message.contains("reader ended before declared size"))
      Ok(_) => fail("an empty read before the declared end must not be EOF")
    }
  }
  assert_true(input_session_error(session) is Some(_))
}

///|
async test "closed Path cursors reject reads at the cached EOF boundary" {
  let session = begin_input_session(input_from_path("lib/input/README.md"))
  defer end_input_session(session)
  let cursor = open_source_cursor(session.source).unwrap()
  let eof = cursor.size.unwrap()
  assert_eq(source_cursor_read_at(cursor, eof, length=1), Ok(b""))
  end_input_session(session)
  assert_true(source_cursor_read_at(cursor, eof, length=1) is Err(_))
}

///|
async test "recoverable text decoding failure does not latch a Reader I/O failure" {
  let bytes = Bytes::from_array([0x96, 0xBC, 0x91, 0x4F])
  let session = begin_input_session(
    input_from_reader(
      make_input_reader(
        fn(offset, length) {
          if offset >= bytes.length().to_int64() {
            Ok(b"")
          } else {
            let start = offset.to_int()
            Ok(
              bytes
              .exact_view(start~, end=(start + length).min(bytes.length()))
              .to_owned(),
            )
          }
        },
        size=bytes.length().to_int64(),
      ),
      source_name="cp932.csv",
    ),
  )
  defer end_input_session(session)
  assert_true(read_input_text(session.source) is Err(_))
  assert_eq(input_session_error(session), None)
  assert_eq(read_input_bytes(session.source), Ok(bytes))
}

///|
async test "prefix and fixed ranges fill legal one-byte asynchronous short reads" {
  let bytes = @utf8.encode("\u{FEFF}中文😀\r\nbody")
  let calls = Ref(0)
  let source = input_from_reader(
    make_async_input_reader(
      async fn(offset, _) {
        @async.pause()
        calls.val += 1
        if offset >= bytes.length().to_int64() {
          return Ok(b"")
        }
        Ok(
          bytes
          .exact_view(start=offset.to_int(), end=offset.to_int() + 1)
          .to_owned(),
        )
      },
      size=bytes.length().to_int64(),
    ),
  )
  assert_eq(read_input_prefix(source, 3), Ok(b"\xef\xbb\xbf"))
  let cursor = open_source_cursor(source).unwrap()
  assert_eq(source_cursor_read_exact_at(cursor, 0L, bytes.length()), Ok(bytes))
  assert_true(calls.val > bytes.length())
}

///|
async test "unknown-size discovery uses bounded one-byte probes and checks the exact ceiling" {
  let bytes = @utf8.encode(
    "12345678901234567890123456789012345678901234567890123456789012345",
  )
  let calls = Ref(0)
  let source = input_from_reader(
    make_async_input_reader(async fn(offset, length) {
      @async.pause()
      calls.val += 1
      assert_eq(length, 1)
      if offset >= bytes.length().to_int64() {
        return Ok(b"")
      }
      Ok(
        bytes
        .exact_view(start=offset.to_int(), end=offset.to_int() + 1)
        .to_owned(),
      )
    }),
  )
  let cursor = open_source_cursor(source, max_bytes=bytes.length().to_int64()).unwrap()
  assert_eq(discover_source_size(cursor), Ok(bytes.length().to_int64()))
  assert_true(calls.val < 20)
  let too_small = open_source_cursor(
    source,
    max_bytes=bytes.length().to_int64() - 1L,
  ).unwrap()
  assert_true(discover_source_size(too_small) is Err(_))
  assert_true(
    source_cursor_error(too_small)
    .unwrap()
    .contains("input byte limit exceeded"),
  )
  let empty = open_source_cursor(
    input_from_reader(make_input_reader(fn(_, _) { Ok(b"") })),
    max_bytes=0L,
  ).unwrap()
  assert_eq(discover_source_size(empty), Ok(0L))
}

///|
async test "all memory input paths respect a nested byte ceiling" {
  for source in [input_from_text("中文"), input_from_bytes(b"abcdef")] {
    let outer = begin_input_session(source)
    defer end_input_session(outer)
    let smaller = begin_input_session(outer.source, max_bytes=5L)
    defer end_input_session(smaller)
    assert_true(read_input_bytes(smaller.source) is Err(_))
    assert_true(read_input_text(smaller.source) is Err(_))
    assert_true(input_session_error(outer) is Some(_))
  }
}

///|
async test "a negative declared Reader size is rejected before invoking its callback" {
  let calls = Ref(0)
  let source = input_from_reader(
    make_input_reader(
      fn(_, _) {
        calls.val += 1
        Ok(b"")
      },
      size=-1L,
    ),
  )
  assert_true(open_source_cursor(source) is Err(_))
  assert_true(input_source_size(source) is Err(_))
  assert_eq(calls.val, 0)
}

///|
async test "ended memory and Reader sessions reject further adapter access without closing callers" {
  let reader = make_input_reader(fn(_, _) { Ok(b"x") }, size=1L)
  for
    source in [
      input_from_text("x"),
      input_from_bytes(b"x"),
      input_from_reader(reader),
    ] {
    let session = begin_input_session(source)
    let cursor = open_source_cursor(session.source).unwrap()
    end_input_session(session)
    assert_true(open_source_cursor(session.source) is Err(_))
    assert_true(input_source_size(session.source) is Err(_))
    assert_true(source_cursor_read_at(cursor, 0L, length=1) is Err(_))
  }
  assert_eq((reader.read_at)(0L, 1), Ok(b"x"))
}

///|
async test "first hard cursor failure stops all later reads and size discovery" {
  let calls = Ref(0)
  let cursor = open_source_cursor(
    input_from_reader(
      make_input_reader(
        fn(_, _) {
          calls.val += 1
          if calls.val == 1 {
            Err("first I/O failure")
          } else {
            Ok(b"x")
          }
        },
        size=1L,
      ),
    ),
  ).unwrap()
  assert_eq(
    source_cursor_read_at(cursor, 0L, length=1),
    Err("first I/O failure"),
  )
  assert_eq(
    source_cursor_read_at(cursor, 0L, length=1),
    Err("first I/O failure"),
  )
  assert_eq(discover_source_size(cursor), Err("first I/O failure"))
  assert_eq(calls.val, 1)
  let closed = open_source_cursor(input_from_bytes(b"x")).unwrap()
  let session = begin_input_session(input_from_bytes(b"x"))
  let ended = open_source_cursor(session.source).unwrap()
  end_input_session(session)
  assert_true(discover_source_size(ended) is Err(_))
  assert_eq(discover_source_size(closed), Ok(1L))
}

///|
async test "invalid UTF16 Text is rejected before Native UTF8 encoding can abort" {
  for
    text in [
      String::from_array([(0xD800).unsafe_to_char(), 'A']),
      String::from_array(['A', (0xDC00).unsafe_to_char()]),
    ] {
    let source = input_from_text(text)
    assert_true(input_source_size(source) is Err(_))
    assert_true(open_source_cursor(source) is Err(_))
    assert_true(read_input_text(source) is Err(_))
    assert_true(read_input_bytes(source) is Err(_))
  }
}

///|
async test "prepared text keeps raw extent limits separate from representation offsets" {
  let original = input_source_with_reader_limit(input_from_bytes(b"abc"), 3L)
  let prepared = with_prepared_text_payload(original, "éé", physical_bytes=3L)
  assert_eq(input_size(prepared), Some(3L))
  assert_eq(input_source_size(prepared), Ok(Some(3L)))
  let cursor = open_source_cursor(prepared).unwrap()
  assert_eq(cursor.size, Some(4L))
  assert_eq(source_cursor_read_exact_at(cursor, 0L, 4), Ok(b"\xc3\xa9\xc3\xa9"))
  assert_eq(read_input_text(prepared), Ok("éé"))
  assert_true(open_source_cursor(prepared, max_bytes=2L) is Err(_))
  // A manual replacement is a new payload, so it cannot manufacture the
  // successful decoder's exemption from representation-as-raw size checking.
  assert_true(read_input_text(with_text_payload(prepared, "éé")) is Err(_))
}
