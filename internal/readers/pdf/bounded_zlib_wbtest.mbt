///|
fn bounded_pdf_decode_result(
  bytes : Bytes,
  source : @input.InputSource,
) -> Result[Bytes, PdfNativeError] {
  try
    pdf_inflate_zlib_bounded(bytes, pdf_make_stream_decode_context(source))
    |> Ok
  catch {
    PdfHardDecodeFailure(error) => Err(error)
  }
}

///|
test "bounded zlib matches pinned normal streams and retains only returned payload" {
  let payloads = [
    b"",
    b"A",
    Bytes::makei(70001, i => (i % 251).to_byte()),
    Bytes::makei(100000, _ => b'Z'),
  ]
  for payload in payloads {
    for level in [0, 1, 6, 9] {
      let compressed = @zlib.zlib_compress(payload, level~)
      let account = @budget.Budget::new(bounded_pdf_test_limits(None))
      let session = @input.begin_input_session(
        @input.input_from_bytes(compressed),
        budget=account,
      )
      let result = bounded_pdf_decode_result(compressed, session.source).unwrap()
      assert_eq(result, @zlib.zlib_decompress(compressed))
      assert_eq(result, payload)
      let snapshot = account.snapshot()
      assert_eq(snapshot.cumulative.inflate_bytes, payload.length().to_int64())
      assert_eq(snapshot.resident.working_bytes, payload.length().to_int64())
      @input.end_input_session(session)
      assert_eq(account.snapshot().resident.working_bytes, 0L)
      assert_eq(account.snapshot().active_leases, 0L)
    }
  }
}

///|
test "bounded zlib charges partial corrupt step and budget error takes priority" {
  // Physical scratch contains A before the reserved next-block BTYPE fails.
  let compressed = b"\x78\x01\x00\x01\x00\xfe\xffA\x07\x00\x42\x00\x42"
  for cap in [None, Some(0L)] {
    let account = @budget.Budget::new(bounded_pdf_test_limits(cap))
    let session = @input.begin_input_session(
      @input.input_from_bytes(compressed),
      budget=account,
    )
    let result = bounded_pdf_decode_result(compressed, session.source)
    match cap {
      None => {
        assert_true(result is Err(StreamIntegrityFailed(InvalidDeflate, _)))
        assert_eq(account.snapshot().cumulative.inflate_bytes, 1L)
      }
      Some(_) => {
        assert_true(
          result
          is Err(
            BudgetExceeded(
              @budget.LimitExceeded(
                Cumulative(InflateBytes),
                used=0L,
                requested=1L,
                limit=0L
              )
            )
          ),
        )
        assert_true(
          @input.input_source_failure(session.source) is Some(BudgetFailure(_)),
        )
      }
    }
    assert_eq(account.snapshot().resident.working_bytes, 0L)
    assert_eq(account.snapshot().active_leases, 0L)
    @input.end_input_session(session)
  }
}

///|
test "bounded zlib rejects framing checksum trailing and truncation before publishing" {
  let valid = @zlib.zlib_compress(b"checksum")
  let wrong_adler = valid.to_array()
  wrong_adler[wrong_adler.length() - 1] = (wrong_adler[wrong_adler.length() - 1].to_int() ^
  1).to_byte()
  let trailing = valid[:valid.length() - 4].to_owned().to_array()
  trailing.push(b'X')
  trailing.append(valid[valid.length() - 4:].to_array())
  let cases : Array[(Bytes, @zlib.ZlibErrorKind)] = [
    (b"", Truncated),
    (b"\x00\x00\x00\x00\x00\x00", InvalidHeader),
    (b"\x78\x20\x00\x00\x00\x00", DictionaryRequired),
    (Bytes::from_array(wrong_adler), ChecksumMismatch),
    (Bytes::from_array(trailing), TrailingData),
    (b"\x78\x01\x01\x01\x00\xfe\xff\x00\x00\x00\x00", Truncated),
  ]
  for item in cases {
    let account = @budget.Budget::new(bounded_pdf_test_limits(None))
    let session = @input.begin_input_session(
      @input.input_from_bytes(item.0),
      budget=account,
    )
    match bounded_pdf_decode_result(item.0, session.source) {
      Err(StreamIntegrityFailed(kind, _)) => assert_eq(kind, item.1)
      _ => fail("expected exact typed zlib framing/integrity failure")
    }
    assert_eq(account.snapshot().resident.working_bytes, 0L)
    assert_eq(account.snapshot().active_leases, 0L)
    @input.end_input_session(session)
  }
}

///|
test "bounded zlib cumulative and working limits remain shared and sticky" {
  let compressed = @zlib.zlib_compress(Bytes::makei(70000, _ => b'A'))
  let account = @budget.Budget::new(bounded_pdf_test_limits(Some(32768L)))
  let session = @input.begin_input_session(
    @input.input_from_bytes(compressed),
    budget=account,
  )
  let first = bounded_pdf_decode_result(compressed, session.source)
  assert_true(first is Err(BudgetExceeded(_)))
  let first_error = account.failure()
  assert_eq(account.snapshot().cumulative.inflate_bytes, 32768L)
  assert_eq(account.snapshot().resident.working_bytes, 0L)
  assert_true(
    bounded_pdf_decode_result(@zlib.zlib_compress(b""), session.source)
    is Err(BudgetExceeded(_)),
  )
  assert_true(account.failure() == first_error)
  @input.end_input_session(session)
  let limits = @budget.BudgetLimits::new(
    MeasurementOnly,
    inflate_bytes=None,
    parse_work=None,
    output_utf8_bytes=None,
    source_metadata_bytes=None,
    rag_metadata_bytes=None,
    read_traffic_bytes=None,
    cache_bytes=None,
    working_bytes=Some(0L),
    temporary_bytes=None,
    ir_bytes=None,
  ).unwrap()
  let account = @budget.Budget::new(limits)
  let session = @input.begin_input_session(
    @input.input_from_bytes(compressed),
    budget=account,
  )
  assert_true(
    bounded_pdf_decode_result(compressed, session.source)
    is Err(BudgetExceeded(_)),
  )
  assert_eq(account.snapshot().cumulative.inflate_bytes, 0L)
  assert_eq(account.snapshot().resident.working_bytes, 0L)
  assert_eq(account.snapshot().active_leases, 0L)
  @input.end_input_session(session)
}

///|
async test "bounded PDF legal stream kinds retain text and source account accounting" {
  for
    kind in [
      "content", "cmap", "font", "cid", "image", "mask", "lookup", "form",
    ] {
    let account = @budget.Budget::new(bounded_pdf_test_limits(None))
    let session = @input.begin_input_session(
      @input.input_from_bytes(bounded_pdf_test_document(kind, false)),
      budget=account,
    )
    let document = extract_pdf_native_document(session.source).unwrap()
    assert_eq(document.pages.length(), 1)
    assert_true(
      pdf_native_line_text(document.pages[0].text_blocks[0].lines[0]).contains(
        "bounded PDF",
      ),
    )
    assert_true(account.snapshot().cumulative.inflate_bytes > 0L, msg=kind)
    assert_true(account.failure() is None)
    @input.end_input_session(session)
    assert_eq(account.snapshot().resident.working_bytes, 0L)
    assert_eq(account.snapshot().active_leases, 0L)
  }
}

///|
async test "bounded PDF cancellation is rethrown across the hard-decode bridge" {
  let entered = Ref(false)
  let account = @budget.Budget::new(bounded_pdf_test_limits(None))
  let session = @input.begin_input_session(
    @input.input_from_reader(
      @input.make_async_input_reader(
        async fn(_, _) {
          entered.val = true
          @async.sleep(60000)
          Ok(b"")
        },
        size=100L,
      ),
    ),
    budget=account,
  )
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @async.handle_cancellation(() => {
        extract_pdf_native_document(session.source)
      })
    })
    while !entered.val {
      @async.pause()
    }
    task.cancel()
    assert_true(task.wait() is None)
  })
  assert_eq(account.snapshot().cumulative.inflate_bytes, 0L)
  assert_eq(account.snapshot().resident.working_bytes, 0L)
  @input.end_input_session(session)
  assert_eq(account.snapshot().active_leases, 0L)
}

///|
async test "bounded PDF child inherits and latches the parent account failure" {
  for corrupt in [false, true] {
    let account = @budget.Budget::new(
      bounded_pdf_test_limits(if corrupt { None } else { Some(0L) }),
    )
    let parent = @input.begin_input_session(
      @input.input_from_bytes(b"container"),
      budget=account,
    )
    let child = @input.input_source_inherit_session(
      @input.input_from_bytes(bounded_pdf_test_document("cmap", corrupt)),
      parent.source,
    )
    let result = extract_pdf_native_document(child)
    if corrupt {
      assert_true(result is Err(StreamIntegrityFailed(_, _)))
      assert_true(
        @input.input_source_failure(parent.source) is Some(InputError(_)),
      )
    } else {
      assert_true(result is Err(BudgetExceeded(_)))
      assert_true(
        @input.input_source_failure(parent.source) is Some(BudgetFailure(_)),
      )
    }
    assert_true(@input.read_input_bytes(parent.source) is Err(_))
    assert_eq(account.snapshot().resident.working_bytes, 0L)
    @input.end_input_session(parent)
    assert_eq(account.snapshot().active_leases, 0L)
  }
}
