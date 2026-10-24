///|
// The payload is valid zlib and has eight actual decoded bytes. Only ObjStm
// syntax (First9 >8), or a filter after the valid Flate, is intentionally bad.
fn objstm_result_test_document(
  soft_filter~ : Bool = false,
  healthy~ : Bool = false,
  missing_member~ : Bool = false,
  wrong_member_index~ : Bool = false,
) -> Bytes {
  let content = "BT /F1 12 Tf (ObjStm result fixture) Tj ET"
  let body = bounded_pdf_test_stream(
    @zlib.zlib_compress(b"5 0 <<>>"),
    extra="/Type /ObjStm /N 1 /First " +
      (if soft_filter || healthy { "4" } else { "9" }),
  )
  let body = if soft_filter {
    body.replace(
      old="[ /ASCIIHexDecode /FlateDecode ]",
      new="[ /ASCIIHexDecode /FlateDecode /UnknownFilter ]",
    )
  } else {
    body
  }
  let extra : Array[PdfWbtestXrefEntry] = [
    {
      object_id: 5,
      entry_type: 2,
      field1: 6,
      field2: if wrong_member_index {
        99
      } else {
        0
      },
    },
  ]
  if missing_member {
    extra.push({ object_id: 42, entry_type: 2, field1: 6, field2: 1, })
  }
  pdf_wbtest_xref_stream_pdf_bytes(
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
        3, "<< /Type /Page /Parent 4 0 R /MediaBox [0 0 200 200] /Resources << /Font << /F1 1 0 R >> >> /Contents 2 0 R >>",
      ),
      (4, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>"),
      (6, body),
    ],
    5,
    7,
    extra_entries=extra,
  )
}

///|
async test "ObjStm ordinary syntax Result is reused between probe and full before independent Loaded repair" {
  let account = @budget.Budget::new(bounded_pdf_test_limits(None))
  let owner = @input.begin_input_session(
    session_test_source(objstm_result_test_document()),
    budget=account,
  )
  defer @input.end_input_session(owner)
  let session = open_pdf_native_session(owner.source).unwrap()
  let probe = session.indexed.unwrap()
  assert_true(probe.objects.get(6).unwrap().stream is Some(Ranged(_)))
  assert_eq(pdf_structural_facts(session).page_count, None)
  assert_true(pdf_structural_facts(session).deferred_repair)
  assert_eq(pdf_structural_facts(session).metadata_object_stream_count, 0)
  assert_eq(account.snapshot().cumulative.inflate_bytes, 8L)
  match extract_pdf_native_document_from_session(session) {
    Err(ParseFailed(message)) =>
      assert_eq(message, "object stream 6 is missing valid /First")
    _ =>
      fail("ordinary malformed ObjStm must preserve its original parse failure")
  }
  assert_true(@input.input_source_failure(owner.source) is None)
  // One ranged decode, then the two still-uncached Loaded repair decodes.
  assert_eq(account.snapshot().cumulative.inflate_bytes, 24L)
}

///|
async test "ObjStm ordinary syntax Result does not decode the same selected parent for each member request" {
  let account = @budget.Budget::new(bounded_pdf_test_limits(None))
  let owner = @input.begin_input_session(
    session_test_source(objstm_result_test_document()),
    budget=account,
  )
  defer @input.end_input_session(owner)
  let session = open_pdf_native_session(owner.source).unwrap()
  let probe = session.indexed.unwrap()
  assert_eq(account.snapshot().cumulative.inflate_bytes, 8L)
  for _ in 0..<8 {
    assert_true(
      pdf_probe_load_object(probe, session.cursor, session.decode_context, 5, 0)
      is Err(ParseFailed(_)),
    )
  }
  assert_true(@input.input_source_failure(owner.source) is None)
  assert_eq(pdf_structural_facts(session).metadata_object_stream_count, 0)
  assert_eq(account.snapshot().cumulative.inflate_bytes, 8L)
}

///|
async test "ObjStm ordinary later filter Result retains one completed Flate decode" {
  let account = @budget.Budget::new(bounded_pdf_test_limits(None))
  let owner = @input.begin_input_session(
    session_test_source(objstm_result_test_document(soft_filter=true)),
    budget=account,
  )
  defer @input.end_input_session(owner)
  let session = open_pdf_native_session(owner.source).unwrap()
  let probe = session.indexed.unwrap()
  assert_true(probe.objects.get(6).unwrap().stream is Some(Ranged(_)))
  assert_eq(account.snapshot().cumulative.inflate_bytes, 8L)
  for _ in 0..<8 {
    assert_true(
      pdf_probe_load_object(probe, session.cursor, session.decode_context, 5, 0)
      is Err(UnsupportedFeature(_)),
    )
  }
  assert_true(@input.input_source_failure(owner.source) is None)
  assert_eq(account.snapshot().cumulative.inflate_bytes, 8L)
}

///|
async test "ObjStm direct extractor preserves the three uncached repair attempts as an explicit boundary" {
  let account = @budget.Budget::new(bounded_pdf_test_limits(None))
  let owner = @input.begin_input_session(
    session_test_source(objstm_result_test_document()),
    budget=account,
  )
  defer @input.end_input_session(owner)
  assert_true(extract_pdf_native_document(owner.source) is Err(ParseFailed(_)))
  assert_true(@input.input_source_failure(owner.source) is None)
  assert_eq(account.snapshot().cumulative.inflate_bytes, 24L)
}

///|
// Metadata is prepaid only in this focused test fixture, so finite Cache tests
// isolate the old text logical admission and the new publication fields.
async fn objstm_result_test_ranged_fixture(
  payload : Bytes,
  dict : String,
  limits~ : @budget.BudgetLimits? = None,
  io_error~ : Bool = false,
) -> (
  @input.InputSession,
  PdfObjectStreamResultCache,
  PdfNativeObject,
  Ref[Int32],
) {
  let (bytes, offset) = ranged_test_bytes(
    payload,
    "/Length " + payload.length().to_string(),
    b"\n",
  )
  let calls = Ref(0)
  let reader = @input.make_input_reader(
    fn(start, length) {
      calls.val += 1
      if io_error {
        Err("controlled ObjStm range IO")
      } else {
        Ok(
          bytes[start.to_int():(start.to_int() + length).min(bytes.length())].to_owned(),
        )
      }
    },
    size=bytes.length().to_int64(),
  )
  let account = @budget.Budget::new(
    limits.unwrap_or(bounded_pdf_test_limits(None)),
  )
  let owner = @input.begin_input_session(
    @input.input_from_reader(reader),
    budget=account,
  )
  let context = pdf_make_stream_decode_context(owner.source).unwrap()
  let cache = pdf_make_object_stream_result_cache(Some(context))
  let object = pdf_parse_indirect_object_at(
    bytes,
    offset,
    decode_context=Some(context),
    range_source=Some({
      cursor: @input.open_source_cursor(owner.source).unwrap(),
      window_start: 0L,
      definition_offset: offset.to_int64(),
      generation: 7,
      metadata_prepaid: true,
    }),
  ).unwrap()
  (owner, cache, { ..object, dict_text: dict, }, calls)
}

///|
async fn objstm_result_test_get(
  object : PdfNativeObject,
  cache : PdfObjectStreamResultCache,
) -> Result[Array[PdfNativeObject], PdfNativeError] {
  pdf_parse_object_stream_entries(object, cache~) catch {
    PdfHardDecodeFailure(error) => Err(error)
    error => raise error
  }
}

///|
async test "ObjStm cache distinguishes parsed empty entries from both ordinary failure variants" {
  for mode in 0..<4 {
    let text = if mode == 0 { b"" } else { b"5 0 <<>>" }
    let dict = match mode {
      0 => "<< /Type /ObjStm /N 0 /First 0 /Filter /FlateDecode >>"
      1 => "<< /Type /ObjStm /N 1 /First 4 /Filter /FlateDecode >>"
      2 => "<< /Type /ObjStm /N 1 /First 9 /Filter /FlateDecode >>"
      _ =>
        "<< /Type /ObjStm /N 1 /First 4 /Filter [/FlateDecode /UnknownFilter] >>"
    }
    let (owner, cache, object, calls) = objstm_result_test_ranged_fixture(
      @zlib.zlib_compress(text),
      dict,
    )
    let result = objstm_result_test_get(object, cache)
    match mode {
      0 => assert_eq(result.unwrap().length(), 0)
      1 => assert_eq(result.unwrap()[0].object_id, 5)
      2 => assert_true(result is Err(ParseFailed(_)))
      _ => assert_true(result is Err(UnsupportedFeature(_)))
    }
    assert_eq(cache.entries.length(), 1)
    assert_eq(cache.length(), if mode < 2 { 1 } else { 0 })
    let snapshot = cache.context.unwrap().budget.account.snapshot()
    let reads = calls.val
    let repeated = objstm_result_test_get(object, cache)
    assert_eq(result is Ok(_), repeated is Ok(_))
    if result is Ok(entries) && repeated is Ok(again) {
      assert_true(physical_equal(entries, again))
      let copied : Array[PdfNativeObject] = []
      copied.append(entries[:])
      if copied.length() > 0 {
        copied[0] = {
          ..copied[0],
          dict_text: "changed only in destination array",
        }
        assert_eq(again[0].dict_text, "<<>>")
      }
    }
    assert_eq(calls.val, reads)
    assert_true(cache.context.unwrap().budget.account.snapshot() == snapshot)
    assert_true(@input.input_source_failure(owner.source) is None)
    @input.end_input_session(owner)
    assert_eq(
      cache.context.unwrap().budget.account.snapshot().active_leases,
      0L,
    )
  }
}

///|
async test "ObjStm complete dictionary plans cannot poison successful and failed entries in either order" {
  for bad_first in [false, true] {
    let (owner, cache, good, calls) = objstm_result_test_ranged_fixture(
      @zlib.zlib_compress(b"5 0 <<>>"),
      "<< /Type /ObjStm /N 1 /First 4 /Filter /FlateDecode >>",
    )
    defer @input.end_input_session(owner)
    let bad = {
      ..good,
      dict_text: "<< /Type /ObjStm /N 1 /First 9 /Filter /FlateDecode >>",
    }
    if bad_first {
      assert_true(objstm_result_test_get(bad, cache) is Err(ParseFailed(_)))
    }
    assert_eq(objstm_result_test_get(good, cache).unwrap()[0].object_id, 5)
    if !bad_first {
      assert_true(objstm_result_test_get(bad, cache) is Err(ParseFailed(_)))
    }
    let reads = calls.val
    let before = cache.context.unwrap().budget.account.snapshot().cumulative
    assert_true(objstm_result_test_get(bad, cache) is Err(ParseFailed(_)))
    assert_true(objstm_result_test_get(good, cache) is Ok(_))
    assert_eq(calls.val, reads)
    assert_true(
      cache.context.unwrap().budget.account.snapshot().cumulative == before,
    )
    assert_eq(cache.entries.length(), 2)
    assert_eq(cache.length(), 1)
  }
}

///|
async test "ObjStm selected definition dictionary framing and generation all participate in identity" {
  let (owner, _, object, _) = objstm_result_test_ranged_fixture(
    @zlib.zlib_compress(b"5 0 <<>>"),
    "<< /N 1 /First 9 /Filter /FlateDecode >>",
  )
  defer @input.end_input_session(owner)
  let key = pdf_object_stream_result_key(object).unwrap()
  let range = ranged_test_range(object)
  for
    changed in [
      { ..range, definition_offset: range.definition_offset + 1L, },
      { ..range, generation: range.generation + 1, },
      { ..range, object_id: range.object_id + 1, },
      { ..range, payload_start: range.payload_start + 1L, },
      { ..range, primary_length: range.primary_length + 1, },
      { ..range, endstream_length: range.endstream_length + 1, },
      { ..range, endstream_eol_suffix: range.endstream_eol_suffix + 1, },
      { ..range, endstream_eol_length: range.endstream_eol_length + 1, },
      { ..range, declared_length: None, },
    ] {
    assert_false(
      pdf_object_stream_result_key({ ..object, stream: Some(Ranged(changed)), }).unwrap() ==
      key,
    )
  }
  assert_false(
    pdf_object_stream_result_key({ ..object, object_id: object.object_id + 1, }).unwrap() ==
    key,
  )
  for
    dict in [
      "<< /N 2 /First 9 /Filter /FlateDecode >>", "<< /N 1 /First 4 /Filter /FlateDecode >>",
      "<< /N 1 /First 9 /Filter [/FlateDecode /UnknownFilter] >>", "<< /N 1 /First 9 /Filter /FlateDecode /DecodeParms << /Predictor 99 >> >>",
    ] {
    assert_false(
      pdf_object_stream_result_key({ ..object, dict_text: dict, }).unwrap() ==
      key,
    )
  }
}

///|
async test "ObjStm member absence depth and loading cycle do not become parent parse failures" {
  let account = @budget.Budget::new(bounded_pdf_test_limits(None))
  let owner = @input.begin_input_session(
    session_test_source(
      objstm_result_test_document(
        healthy=true,
        missing_member=true,
        wrong_member_index=true,
      ),
    ),
    budget=account,
  )
  defer @input.end_input_session(owner)
  let session = open_pdf_native_session(owner.source).unwrap()
  let probe = session.indexed.unwrap()
  assert_eq(probe.object_streams.length(), 1)
  assert_eq(pdf_structural_facts(session).metadata_object_stream_count, 1)
  let before = account.snapshot().cumulative.inflate_bytes
  assert_true(
    pdf_probe_load_object(
      probe,
      session.cursor,
      session.decode_context,
      42,
      256,
    )
    is Ok(None),
  )
  probe.loading.set(42, true)
  assert_true(
    pdf_probe_load_object(probe, session.cursor, session.decode_context, 42, 0)
    is Ok(None),
  )
  probe.loading.set(42, false)
  assert_true(
    pdf_probe_load_object(probe, session.cursor, session.decode_context, 42, 0)
    is Ok(None),
  )
  ignore(probe.objects.remove(5))
  assert_true(
    pdf_probe_load_object(probe, session.cursor, session.decode_context, 5, 0)
    is Ok(Some(_)),
  )
  assert_eq(account.snapshot().cumulative.inflate_bytes, before)
  assert_eq(probe.object_streams.entries.length(), 1)
  assert_eq(probe.object_streams.length(), 1)
}

///|
async test "ObjStm ordinary negative hit checks closed owner IO Budget and Resource first failures" {
  for failure in 0..<4 {
    let (owner, cache, object, calls) = objstm_result_test_ranged_fixture(
      @zlib.zlib_compress(b"5 0 <<>>"),
      "<< /N 1 /First 9 /Filter /FlateDecode >>",
    )
    assert_true(objstm_result_test_get(object, cache) is Err(ParseFailed(_)))
    let before = cache.context.unwrap().budget.account.snapshot().cumulative
    let reads = calls.val
    match failure {
      0 =>
        @input.record_input_failure(
          owner.source,
          "controlled cached ObjStm source failure",
        )
      1 =>
        @input.record_input_budget_failure(
          owner.source,
          LimitExceeded(Resident(CacheBytes), used=0L, requested=1L, limit=0L),
        )
      2 =>
        @input.record_input_resource_failure(
          owner.source,
          @input.make_resource_limit_failure(SingleAssetBytes, 1L, 0L),
        )
      _ => @input.end_input_session(owner)
    }
    let result = objstm_result_test_get(object, cache)
    if failure == 1 {
      assert_true(result is Err(BudgetExceeded(_)))
      assert_true(
        @input.input_source_failure(owner.source) is Some(BudgetFailure(_)),
      )
    } else {
      assert_true(result is Err(ReadFailed(_)))
      if failure == 2 {
        assert_true(
          @input.input_source_failure(owner.source) is Some(ResourceLimit(_)),
        )
      }
    }
    assert_eq(calls.val, reads)
    assert_true(
      cache.context.unwrap().budget.account.snapshot().cumulative == before,
    )
    assert_eq(cache.entries.length(), 1)
    @input.end_input_session(owner)
    assert_eq(
      cache.context.unwrap().budget.account.snapshot().active_leases,
      0L,
    )
  }
}

///|
async test "ObjStm hard CRC IO and Inflate failures cannot be published or retried as ordinary errors" {
  for failure in 0..<3 {
    let payload = if failure == 0 {
      b"\x78\x9c\x00"
    } else {
      @zlib.zlib_compress(b"5 0 <<>>")
    }
    let (owner, cache, object, calls) = objstm_result_test_ranged_fixture(
      payload,
      "<< /N 1 /First 9 /Filter [/FlateDecode /UnknownFilter] >>",
      limits=Some(
        bounded_pdf_test_limits(if failure == 2 { Some(0L) } else { None }),
      ),
      io_error=failure == 1,
    )
    let result = objstm_result_test_get(object, cache)
    match failure {
      0 => assert_true(result is Err(StreamIntegrityFailed(_, _)))
      1 => assert_true(result is Err(ReadFailed(_)))
      _ => assert_true(result is Err(BudgetExceeded(_)))
    }
    if failure == 2 {
      assert_true(
        @input.input_source_failure(owner.source) is Some(BudgetFailure(_)),
      )
    }
    assert_eq(cache.entries.length(), 0)
    let reads = calls.val
    let inflated = cache.context.unwrap().budget.account.snapshot().cumulative.inflate_bytes
    assert_true(objstm_result_test_get(object, cache) is Err(_))
    assert_eq(calls.val, reads)
    assert_eq(
      cache.context.unwrap().budget.account.snapshot().cumulative.inflate_bytes,
      inflated,
    )
    @input.end_input_session(owner)
    assert_eq(
      cache.context.unwrap().budget.account.snapshot().active_leases,
      0L,
    )
  }
}

///|
async test "ObjStm shared probe full and Loaded repair cannot replace the original finite Inflate account" {
  let account = @budget.Budget::new(bounded_pdf_test_limits(Some(8L)))
  let owner = @input.begin_input_session(
    session_test_source(objstm_result_test_document()),
    budget=account,
  )
  let session = open_pdf_native_session(owner.source).unwrap()
  let probe = session.indexed.unwrap()
  assert_eq(account.snapshot().cumulative.inflate_bytes, 8L)
  assert_eq(probe.object_streams.entries.length(), 1)
  assert_true(
    extract_pdf_native_document_from_session(session) is Err(BudgetExceeded(_)),
  )
  assert_true(
    @input.input_source_failure(owner.source) is Some(BudgetFailure(_)),
  )
  let before = account.snapshot().cumulative
  let parent = probe.objects.get(6).unwrap()
  assert_true(
    objstm_result_test_get(parent, probe.object_streams)
    is Err(BudgetExceeded(_)),
  )
  assert_true(account.snapshot().cumulative == before)
  @input.end_input_session(owner)
  assert_eq(account.snapshot().active_leases, 0L)
}

///|
async test "ObjStm Loaded repair objects keep independent ordinary failures and no invented cache identity" {
  let payload = @zlib.zlib_compress(b"5 0 <<>>")
  let (bytes, offset) = ranged_test_bytes(
    payload,
    "/Length " + payload.length().to_string(),
    b"\n",
  )
  let account = @budget.Budget::new(bounded_pdf_test_limits(None))
  let owner = @input.begin_input_session(
    @input.input_from_bytes(bytes),
    budget=account,
  )
  defer @input.end_input_session(owner)
  let context = pdf_make_stream_decode_context(owner.source).unwrap()
  let cache = pdf_make_object_stream_result_cache(Some(context))
  let loaded = pdf_parse_indirect_object_at(
    bytes,
    offset,
    decode_context=Some(context),
  ).unwrap()
  let object = {
    ..loaded,
    dict_text: "<< /N 1 /First 9 /Filter /FlateDecode >>",
  }
  assert_true(pdf_object_stream_result_key(object) is None)
  for _ in 0..<2 {
    assert_true(objstm_result_test_get(object, cache) is Err(ParseFailed(_)))
  }
  assert_eq(account.snapshot().cumulative.inflate_bytes, 16L)
  assert_eq(cache.entries.length(), 0)
  assert_eq(cache.length(), 0)
}

///|
async test "ObjStm additional result fields enforce publication admission before a later decode" {
  let limits = @budget.BudgetLimits::new(
    MeasurementOnly,
    inflate_bytes=None,
    parse_work=None,
    output_utf8_bytes=None,
    source_metadata_bytes=None,
    rag_metadata_bytes=None,
    read_traffic_bytes=None,
    cache_bytes=Some(48L),
    working_bytes=None,
    temporary_bytes=None,
    ir_bytes=None,
  ).unwrap()
  let (owner, cache, object, calls) = objstm_result_test_ranged_fixture(
    @zlib.zlib_compress(b"5 0 <<>>"),
    "<< /N 1 /First 9 /Filter /FlateDecode >>",
    limits=Some(limits),
  )
  // The original text4N+16 admission consumes48 exactly; the new key/Result
  // fields cannot publish an ordinary Err without their own admission.
  assert_true(
    objstm_result_test_get(object, cache)
    is Err(BudgetExceeded(LimitExceeded(Resident(CacheBytes), ..))),
  )
  assert_true(
    @input.input_source_failure(owner.source) is Some(BudgetFailure(_)),
  )
  assert_eq(cache.entries.length(), 0)
  let reads = calls.val
  let before = cache.context.unwrap().budget.account.snapshot().cumulative
  let range = ranged_test_range(object)
  let corrupt = {
    ..object,
    stream: Some(
      Ranged({
        ..range,
        primary_length: 3,
        endstream_length: 3,
        declared_length: Some(3),
        endstream_eol_suffix: 0,
        endstream_eol_length: 0,
      }),
    ),
  }
  assert_true(objstm_result_test_get(corrupt, cache) is Err(BudgetExceeded(_)))
  assert_eq(calls.val, reads)
  assert_true(
    cache.context.unwrap().budget.account.snapshot().cumulative == before,
  )
  @input.end_input_session(owner)
  assert_eq(cache.context.unwrap().budget.account.snapshot().active_leases, 0L)
}

///|
async test "ObjStm caches and negative entries remain private to fresh documents" {
  for _ in 0..<2 {
    let account = @budget.Budget::new(bounded_pdf_test_limits(None))
    let owner = @input.begin_input_session(
      session_test_source(objstm_result_test_document()),
      budget=account,
    )
    let before = account.snapshot().cumulative.inflate_bytes
    let session = open_pdf_native_session(owner.source).unwrap()
    assert_eq(account.snapshot().cumulative.inflate_bytes - before, 8L)
    assert_eq(session.indexed.unwrap().object_streams.entries.length(), 1)
    assert_eq(session.indexed.unwrap().object_streams.length(), 0)
    @input.end_input_session(owner)
    assert_eq(account.snapshot().active_leases, 0L)
  }
}

///|
async test "two ObjStm document sessions on one live owner and account still get independent result caches" {
  let account = @budget.Budget::new(bounded_pdf_test_limits(None))
  let owner = @input.begin_input_session(
    session_test_source(objstm_result_test_document()),
    budget=account,
  )
  for _ in 0..<2 {
    let before = account.snapshot().cumulative.inflate_bytes
    let session = open_pdf_native_session(owner.source).unwrap()
    assert_eq(account.snapshot().cumulative.inflate_bytes - before, 8L)
    assert_eq(session.indexed.unwrap().object_streams.entries.length(), 1)
    assert_eq(session.indexed.unwrap().object_streams.length(), 0)
  }
  @input.end_input_session(owner)
  assert_eq(account.snapshot().active_leases, 0L)
}

///|
async test "cancelled ObjStm miss never publishes an ordinary result and releases private scratch" {
  let payload = @zlib.zlib_compress(b"5 0 <<>>")
  let (bytes, offset) = ranged_test_bytes(
    payload,
    "/Length " + payload.length().to_string(),
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
  let context = pdf_make_stream_decode_context(owner.source).unwrap()
  let cache = pdf_make_object_stream_result_cache(Some(context))
  let range = ranged_test_object(
    owner.source,
    @input.open_source_cursor(owner.source).unwrap(),
    bytes,
    offset,
  )
  let object = {
    ..range,
    dict_text: "<< /N 1 /First 9 /Filter /FlateDecode >>",
  }
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @async.handle_cancellation(() => objstm_result_test_get(object, cache))
    })
    while !entered.val {
      @async.pause()
    }
    task.cancel()
    assert_true(task.wait() is None)
  })
  assert_eq(cache.entries.length(), 0)
  assert_true(@input.input_source_failure(owner.source) is None)
  assert_eq(account.snapshot().resident.working_bytes, 0L)
  @input.end_input_session(owner)
  assert_eq(account.snapshot().active_leases, 0L)
}

///|
async test "ObjStm postparse field overflow remains typed and cannot enter an ordinary Result cache" {
  let (owner, cache, _, _) = objstm_result_test_ranged_fixture(
    @zlib.zlib_compress(b"5 0 <<>>"),
    "<< /N 1 /First 9 /Filter /FlateDecode >>",
  )
  let result = Ok(
    pdf_objstm_payload_add(cache.context.unwrap(), 9223372036854775807L, 1L),
  ) catch {
    error => Err(error)
  }
  assert_true(
    result
    is Err(
      PdfHardDecodeFailure(
        BudgetExceeded(ArithmeticOverflow(Resident(CacheBytes), ..))
      )
    ),
  )
  assert_true(
    @input.input_source_failure(owner.source) is Some(BudgetFailure(_)),
  )
  assert_eq(cache.entries.length(), 0)
  @input.end_input_session(owner)
  assert_eq(cache.context.unwrap().budget.account.snapshot().active_leases, 0L)
}

///|
async test "ObjStm stored field model counts cache once and fixed None Some length slots" {
  let (owner, cache, object, _) = objstm_result_test_ranged_fixture(
    @zlib.zlib_compress(b"5 0 <<>>"),
    "<< /N 1 /First 9 /Filter /FlateDecode >>",
  )
  defer @input.end_input_session(owner)
  let context = cache.context.unwrap()
  let key = { ..pdf_object_stream_result_key(object).unwrap(), dict_text: "", }
  assert_eq(
    pdf_object_stream_result_retained_payload(context, cache, key, Ok([])),
    100L,
  )
  assert_eq(
    pdf_object_stream_result_retained_payload(
      context,
      cache,
      key,
      Err(ParseFailed("")),
    ),
    108L,
  )
  assert_eq(
    pdf_object_stream_result_retained_payload(
      context,
      cache,
      key,
      Err(UnsupportedFeature("bad")),
    ),
    114L,
  )
  assert_eq(
    pdf_object_stream_result_retained_payload(
      context,
      cache,
      { ..key, declared_length: None, },
      Ok([]),
    ),
    100L,
  )
  // Test-only insertion isolates the first-entry wrapper fee from the fixed
  // per-entry fields; the normal gateway always admits before insertion.
  cache.entries.set(key, Ok([]))
  assert_eq(
    pdf_object_stream_result_retained_payload(context, cache, key, Ok([])),
    84L,
  )
  assert_eq(
    pdf_object_stream_result_retained_payload(
      context,
      cache,
      key,
      Err(ParseFailed("")),
    ),
    92L,
  )
}
