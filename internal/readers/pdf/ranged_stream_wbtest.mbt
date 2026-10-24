///|
fn pdf_wbtest_loaded_stream(
  reference : PdfNativeStreamRef,
) -> PdfNativeStreamSlice raise {
  match reference {
    Loaded(stream) | SelectedLoaded(stream, _) => stream
    Ranged(_) => fail("expected an explicit in-memory test stream")
  }
}

///|
fn ranged_test_bytes(
  payload : Bytes,
  length_dict : String,
  separator : Bytes,
) -> (Bytes, Int32) {
  let buffer = Buffer()
  buffer.write_bytes(b"%PDF-1.4\nPREFIX\n")
  let offset = buffer.length()
  buffer.write_bytes(
    pdf_ascii_bytes(
      "1 0 obj\n<< " + length_dict + " /Filter /FlateDecode >>\nstream\n",
    ),
  )
  buffer.write_bytes(payload)
  buffer.write_bytes(separator)
  buffer.write_bytes(b"endstream\nendobj\nSUFFIX")
  (buffer.to_bytes(), offset)
}

///|
fn ranged_test_object(
  source : @input.InputSource,
  cursor : @input.SourceCursor,
  bytes : Bytes,
  offset : Int32,
  window_start~ : Int32 = 0,
  generation~ : Int32 = 7,
) -> PdfNativeObject raise PdfHardDecodeFailure {
  pdf_parse_indirect_object_at(
    bytes[window_start:].to_owned(),
    offset - window_start,
    decode_context=pdf_make_stream_decode_context(source),
    range_source=Some({
      cursor,
      window_start: window_start.to_int64(),
      definition_offset: offset.to_int64(),
      generation,
      metadata_prepaid: false,
    }),
  ).unwrap()
}

///|
fn ranged_test_range(object : PdfNativeObject) -> PdfNativeStreamRange raise {
  match object.stream {
    Some(Ranged(range)) => range
    _ => fail("expected a source-range descriptor")
  }
}

///|
async test "indexed metadata survey retains range descriptors and preserves unused image resources" {
  let content = "BT /F1 12 Tf (range text) Tj ET"
  let unrelated = "Z".repeat(2 * 1024 * 1024)
  let bytes = pdf_wbtest_xref_stream_pdf_bytes(
    [
      (1, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"),
      (
        2,
        "<< /Length " +
        content.length().to_string() +
        " >>\nstream\n" +
        content +
        "\nendstream",
      ),
      (
        3, "<< /Type /Page /Parent 4 0 R /Contents 2 0 R /MediaBox [0 0 200 200] /Resources << /Font << /F1 1 0 R >> /XObject << /Unused 6 0 R >> >> >>",
      ),
      (4, "<< /Type /Pages /Kids [3 0 R] /Count 99 >>"),
      (5, "<< /Type /Catalog /Pages 4 0 R >>"),
      (
        6,
        "<< /Type /XObject /Subtype /Image /Width 1 /Height 1 /Length " +
        unrelated.length().to_string() +
        " >>\nstream\n" +
        unrelated +
        "\nendstream",
      ),
    ],
    5,
    9,
  )
  let calls : Array[(Int64, Int32)] = []
  let reader = @input.make_input_reader(
    fn(offset, length) {
      calls.push((offset, length))
      let start = offset.to_int()
      Ok(bytes[start:(start + length).min(bytes.length())].to_owned())
    },
    size=bytes.length().to_int64(),
  )
  let account = @budget.Budget::new(bounded_pdf_test_limits(None))
  let owner = @input.begin_input_session(
    @input.input_from_reader_with_format(reader, "ranges.pdf", Some(Pdf)),
    budget=account,
  )
  let store = pdf_load_object_store(
    owner.source,
    pdf_make_stream_decode_context(owner.source),
  ).unwrap()
  let mut retained = 0
  let mut ranged = 0
  for object in store.objects {
    match object.stream {
      Some(Loaded(stream) | SelectedLoaded(stream, _)) =>
        retained += stream.primary_bytes.length() +
          stream.endstream_bytes.length()
      Some(Ranged(_)) => ranged += 1
      None => ()
    }
  }
  assert_eq(retained, 0)
  assert_true(ranged >= 3)
  let unused = ranged_test_range(store.object_index.get(6).unwrap())
  assert_eq(unused.primary_length, unrelated.length())
  let before = calls.length()
  let document = pdf_extract_document_from_store(owner.source, store).unwrap()
  assert_eq(document.pages.length(), 1)
  assert_eq(document.pages[0].image_candidates.length(), 0)
  assert_eq(
    pdf_native_line_text(document.pages[0].text_blocks[0].lines[0]),
    "range text",
  )
  // The metadata survey read the source windows. Subsequent interpretation
  // reads the content range, never the still-present unused image payload.
  for (offset, length) in calls[before:] {
    assert_true(
      offset + length.to_int64() <= unused.payload_start ||
      offset >= unused.payload_start + unused.primary_length.to_int64(),
    )
  }
  @input.end_input_session(owner)
  assert_eq(account.snapshot().active_leases, 0L)
}

///|
async test "ranged primary endstream and source EOL exactly match owned framing at nonzero offsets" {
  for decoded in [b"\x0c", b"\x09", b"range payload"] {
    let payload = @zlib.zlib_compress(decoded)
    for separator in [b"\n", b"\r\n"] {
      for indirect in [false, true] {
        let length = if indirect {
          "/Length 2 0 R"
        } else {
          "/Length " + payload.length().to_string()
        }
        let (bytes, offset) = ranged_test_bytes(payload, length, separator)
        let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
        let cursor = @input.open_source_cursor(owner.source).unwrap()
        let object = ranged_test_object(
          owner.source,
          cursor,
          bytes,
          offset,
          window_start=5,
        )
        let owned = pdf_parse_indirect_object_at(bytes, offset).unwrap()
        let scalar : PdfNativeObject = {
          object_id: 2,
          dict_text: payload.length().to_string(),
          stream: None,
        }
        let ranged_store = pdf_build_parsed_object_store(
          [object, scalar],
          Map([(1, object), (2, scalar)]),
          [],
          "fixture",
          "fixture",
        )
        let owned_store = pdf_build_parsed_object_store(
          [owned, scalar],
          Map([(1, owned), (2, scalar)]),
          [],
          "fixture",
          "fixture",
        )
        let selected = ranged_store.object_index.get(1).unwrap()
        let range = ranged_test_range(selected)
        assert_eq(range.definition_offset, offset.to_int64())
        assert_eq(range.generation, 7)
        let read = pdf_load_stream_reference(selected.stream.unwrap())
        let expected = pdf_wbtest_loaded_stream(
          owned_store.object_index.get(1).unwrap().stream.unwrap(),
        )
        assert_eq(read.stream.primary_bytes, expected.primary_bytes)
        assert_eq(read.stream.endstream_bytes, expected.endstream_bytes)
        assert_eq(
          read.stream.endstream_eol_suffix,
          expected.endstream_eol_suffix,
        )
        assert_eq(
          read.stream.endstream_eol_length,
          expected.endstream_eol_length,
        )
        pdf_release_stream_read(read)
        assert_eq(framing_test_decode(selected).unwrap(), decoded)
        @input.end_input_session(owner)
      }
    }
  }
}

///|
async test "ranged payload publication is scope held and owner closure prevents consumption" {
  let (bytes, offset) = ranged_test_bytes(
    @zlib.zlib_compress(b"published"),
    "/Length 2 0 R",
    b"\n",
  )
  let calls = Ref(0)
  let reader = @input.make_input_reader(
    fn(start, length) {
      calls.val += 1
      Ok(
        bytes[start.to_int():(start.to_int() + length).min(bytes.length())].to_owned(),
      )
    },
    size=bytes.length().to_int64(),
  )
  let account = @budget.Budget::new(bounded_pdf_test_limits(None))
  let owner = @input.begin_input_session(
    @input.input_from_reader(reader),
    budget=account,
  )
  let object = ranged_test_object(
    owner.source,
    @input.open_source_cursor(owner.source).unwrap(),
    bytes,
    offset,
  )
  let payload = framing_test_decode(object).unwrap()
  assert_eq(payload, b"published")
  assert_true(account.snapshot().resident.working_bytes > 0L)
  let read_calls = calls.val
  @input.end_input_session(owner)
  assert_true(framing_test_decode(object) is Err(ReadFailed(_)))
  assert_eq(calls.val, read_calls)
  assert_eq(account.snapshot().active_leases, 0L)
  assert_eq(payload, b"published")
}

///|
async test "ranged Working admission fails before Reader callback and keeps typed first failure" {
  let (bytes, offset) = ranged_test_bytes(
    @zlib.zlib_compress(b"budget"),
    "/Length 2 0 R",
    b"\n",
  )
  let calls = Ref(0)
  let reader = @input.make_input_reader(
    fn(start, length) {
      calls.val += 1
      Ok(
        bytes[start.to_int():(start.to_int() + length).min(bytes.length())].to_owned(),
      )
    },
    size=bytes.length().to_int64(),
  )
  let limits = @budget.BudgetLimits::new(
    MeasurementOnly,
    working_bytes=Some(0L),
    cache_bytes=None,
    inflate_bytes=None,
    parse_work=None,
    output_utf8_bytes=None,
    read_traffic_bytes=None,
    source_metadata_bytes=None,
    rag_metadata_bytes=None,
    temporary_bytes=None,
    ir_bytes=None,
  ).unwrap()
  let account = @budget.Budget::new(limits)
  let owner = @input.begin_input_session(
    @input.input_from_reader(reader),
    budget=account,
  )
  let object = ranged_test_object(
    owner.source,
    @input.open_source_cursor(owner.source).unwrap(),
    bytes,
    offset,
  )
  assert_true(framing_test_decode(object) is Err(BudgetExceeded(_)))
  assert_true(
    @input.input_source_failure(owner.source) is Some(BudgetFailure(_)),
  )
  assert_true(framing_test_decode(object) is Err(BudgetExceeded(_)))
  assert_eq(calls.val, 0)
  assert_eq(account.snapshot().resident.working_bytes, 0L)
  @input.end_input_session(owner)
  assert_eq(account.snapshot().active_leases, 0L)
}

///|
async fn ranged_test_gateway(
  object : PdfNativeObject,
  kind : Int32,
) -> Result[Unit, PdfNativeError] {
  try {
    match kind {
      0 => ignore(pdf_decode_stream_bytes(object, "late IO"))
      1 => ignore(pdf_decode_cmap_stream_text(object))
      _ =>
        ignore(
          pdf_exportable_image_payload(
            object,
            Map([(object.object_id, object)]),
          ),
        )
    }
    Ok(())
  } catch {
    PdfHardDecodeFailure(error) => Err(error)
    error => raise error
  }
}

///|
async test "deferred source IO cannot become optional CMap or image fallback and cannot retry" {
  for kind in [0, 1, 2] {
    let (bytes, offset) = ranged_test_bytes(
      @zlib.zlib_compress(b"late read"),
      "/Length 2 0 R",
      b"\n",
    )
    let calls = Ref(0)
    let reader = @input.make_input_reader(
      fn(_, _) {
        calls.val += 1
        Err("forced late range IO")
      },
      size=bytes.length().to_int64(),
    )
    let account = @budget.Budget::new(bounded_pdf_test_limits(None))
    let owner = @input.begin_input_session(
      @input.input_from_reader(reader),
      budget=account,
    )
    let object = ranged_test_object(
      owner.source,
      @input.open_source_cursor(owner.source).unwrap(),
      bytes,
      offset,
    )
    match ranged_test_gateway(object, kind) {
      Err(ReadFailed(message)) =>
        assert_true(message.contains("forced late range IO"))
      _ => fail("source IO must bypass optional recovery")
    }
    assert_eq(calls.val, 1)
    assert_true(ranged_test_gateway(object, kind) is Err(ReadFailed(_)))
    assert_eq(calls.val, 1)
    assert_eq(account.snapshot().resident.working_bytes, 0L)
    @input.end_input_session(owner)
    assert_eq(account.snapshot().active_leases, 0L)
  }
}

///|
async test "ObjStm cache uses definition and generation and rejects pre-existing typed source failure" {
  for budget_failure in [false, true] {
    let account = @budget.Budget::new(bounded_pdf_test_limits(None))
    let owner = @input.begin_input_session(
      session_test_source(session_test_metadata_pdf(compressed=true)),
      budget=account,
    )
    let session = open_pdf_native_session(owner.source).unwrap()
    let probe = session.indexed.unwrap()
    let parent = probe.objects.get(6).unwrap()
    let range = ranged_test_range(parent)
    let before = account.snapshot().cumulative.inflate_bytes
    assert_true(
      pdf_parse_object_stream_entries(parent, cache=probe.object_streams)
      is Ok(_),
    )
    assert_eq(account.snapshot().cumulative.inflate_bytes, before)
    let alternate = {
      ..parent,
      stream: Some(Ranged({ ..range, generation: range.generation + 1, })),
    }
    assert_true(
      pdf_parse_object_stream_entries(alternate, cache=probe.object_streams)
      is Ok(_),
    )
    assert_eq(probe.object_streams.length(), 2)
    assert_true(account.snapshot().cumulative.inflate_bytes > before)
    let charged = account.snapshot().cumulative.inflate_bytes
    if budget_failure {
      @input.record_input_budget_failure(
        owner.source,
        LimitExceeded(Resident(WorkingBytes), used=0L, requested=1L, limit=0L),
      )
    } else {
      @input.record_input_failure(
        owner.source,
        "forced source first failure after ObjStm cache",
      )
    }
    let result = pdf_parse_object_stream_entries(
      parent,
      cache=probe.object_streams,
    ) catch {
      PdfHardDecodeFailure(error) => Err(error)
      error => raise error
    }
    if budget_failure {
      assert_true(result is Err(BudgetExceeded(_)))
    } else {
      assert_true(result is Err(ReadFailed(_)))
    }
    assert_eq(account.snapshot().cumulative.inflate_bytes, charged)
    @input.end_input_session(owner)
    assert_eq(account.snapshot().active_leases, 0L)
  }
}

///|
async test "ranged read cancellation stays independent and releases private reservations" {
  let (bytes, offset) = ranged_test_bytes(
    @zlib.zlib_compress(b"cancel"),
    "/Length 2 0 R",
    b"\n",
  )
  let entered = Ref(false)
  let reader = @input.make_async_input_reader(
    async fn(_, _) {
      entered.val = true
      while true {
        @async.pause()
      }
      Ok(b"")
    },
    size=bytes.length().to_int64(),
  )
  let account = @budget.Budget::new(bounded_pdf_test_limits(None))
  let owner = @input.begin_input_session(
    @input.input_from_reader(reader),
    budget=account,
  )
  let object = ranged_test_object(
    owner.source,
    @input.open_source_cursor(owner.source).unwrap(),
    bytes,
    offset,
  )
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @async.handle_cancellation(() => framing_test_decode(object))
    })
    while !entered.val {
      @async.pause()
    }
    task.cancel()
    assert_true(task.wait() is None)
  })
  assert_true(@input.input_source_failure(owner.source) is None)
  assert_eq(account.snapshot().resident.working_bytes, 0L)
  @input.end_input_session(owner)
  assert_eq(account.snapshot().active_leases, 0L)
}

///|
async test "ranged framing preserves hard Adler errors ending EOL and never drops non-EOL junk" {
  let compressed = @zlib.zlib_compress(b"guarded")
  for kind in [0, 1, 2] {
    for last in [b'\r', b'\n'] {
      let bad = Bytes::makei(compressed.length(), i => {
        if i + 1 == compressed.length() {
          last
        } else {
          compressed[i]
        }
      })
      let (bytes, offset) = ranged_test_bytes(
        bad,
        "/Length " + bad.length().to_string(),
        b"\n",
      )
      let account = @budget.Budget::new(bounded_pdf_test_limits(None))
      let owner = @input.begin_input_session(
        @input.input_from_bytes(bytes),
        budget=account,
      )
      let parsed = ranged_test_object(
        owner.source,
        @input.open_source_cursor(owner.source).unwrap(),
        bytes,
        offset,
      )
      let image_dict = " /Type /XObject /Subtype /Image /Width 1 /Height 7 /ColorSpace /DeviceGray /BitsPerComponent 8"
      let object = if kind == 2 {
        {
          ..parsed,
          dict_text: parsed.dict_text.replace(old=">>", new=image_dict + " >>"),
        }
      } else {
        parsed
      }
      let ranged_result = ranged_test_gateway(object, kind)
      if !(ranged_result is Err(StreamIntegrityFailed(ChecksumMismatch, _))) {
        let message = match ranged_result {
          Ok(_) => "unexpected success"
          Err(error) => error.to_string()
        }
        fail(
          "kind=" +
          kind.to_string() +
          ", last=" +
          last.to_int().to_string() +
          ": " +
          message,
        )
      }
      let owned_account = @budget.Budget::new(bounded_pdf_test_limits(None))
      let owned_owner = @input.begin_input_session(
        @input.input_from_bytes(bytes),
        budget=owned_account,
      )
      let owned_parsed = pdf_parse_indirect_object_at(
        bytes,
        offset,
        decode_context=pdf_make_stream_decode_context(owned_owner.source),
      ).unwrap()
      let owned = if kind == 2 {
        {
          ..owned_parsed,
          dict_text: owned_parsed.dict_text.replace(
            old=">>",
            new=image_dict + " >>",
          ),
        }
      } else {
        owned_parsed
      }
      assert_true(
        ranged_test_gateway(owned, kind)
        is Err(StreamIntegrityFailed(ChecksumMismatch, _)),
      )
      // CMap/image retain the existing selected-bytes EOL policy. If that
      // first span is truncated, its actual production is still charged
      // before the strict exact-length candidate reaches terminal bad Adler.
      assert_eq(
        account.snapshot().cumulative.inflate_bytes,
        owned_account.snapshot().cumulative.inflate_bytes,
      )
      assert_eq(
        account.snapshot().resident.working_bytes,
        owned_account.snapshot().resident.working_bytes,
      )
      if kind == 0 {
        assert_eq(account.snapshot().cumulative.inflate_bytes, 7L)
      }
      @input.end_input_session(owner)
      @input.end_input_session(owned_owner)
      assert_eq(account.snapshot().active_leases, 0L)
      assert_eq(owned_account.snapshot().active_leases, 0L)
    }
  }
  for suffix in [b"X\n", b"\x00\n", b" \n"] {
    let output = Buffer()
    output.write_bytes(compressed)
    output.write_bytes(suffix)
    let bad = output.to_bytes()
    let (bytes, offset) = ranged_test_bytes(
      bad,
      "/Length " + bad.length().to_string(),
      b"\r\n",
    )
    let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
    let object = ranged_test_object(
      owner.source,
      @input.open_source_cursor(owner.source).unwrap(),
      bytes,
      offset,
    )
    assert_true(framing_test_decode(object) is Err(StreamIntegrityFailed(_, _)))
    @input.end_input_session(owner)
  }
}
