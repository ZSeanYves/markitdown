///|
// The before version uses the original source-only cache factory. Its after
// counterpart explicitly binds the same fixed store, as the real extractor.
fn loaded_cmap_test_cache(
  source : @input.InputSource,
  store : PdfParsedObjectStore,
) -> PdfLocalCMapCache {
  pdf_make_local_cmap_cache(
    source,
    loaded_snapshot=pdf_loaded_store_snapshot(store.objects),
  ).unwrap()
}

///|
async test "Loaded CMap real font registry decodes shared local and parent streams only once" {
  let bytes = cmap_cache_test_pdf()
  let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
  defer @input.end_input_session(owner)
  let store = loaded_font_result_test_store(owner.source, bytes)
  let account = pdf_make_stream_decode_context(owner.source).unwrap().budget.account
  let before = account.snapshot().cumulative.inflate_bytes
  let document = pdf_extract_document_from_store(owner.source, store).unwrap()
  assert_eq(
    pdf_native_line_text(document.pages[0].text_blocks[0].lines[0]),
    "A",
  )
  let once = cmap_cache_test_text("41", "0041").length().to_int64() +
    cmap_cache_test_text("42", "0042").length().to_int64()
  assert_eq(account.snapshot().cumulative.inflate_bytes - before, once)
}

///|
async test "Loaded local CMap success retains one immutable local result across eight consumers" {
  let bytes = cmap_cache_test_pdf()
  let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
  defer @input.end_input_session(owner)
  let store = loaded_font_result_test_store(owner.source, bytes)
  let object = store.object_index.get(101).unwrap()
  let cache = loaded_cmap_test_cache(owner.source, store)
  let before = cache.context.budget.account.snapshot().cumulative.inflate_bytes
  let first = pdf_local_tounicode_cmap_info(object, Some(cache)).unwrap()
  for _ in 0..<7 {
    let next = pdf_local_tounicode_cmap_info(object, Some(cache)).unwrap()
    cmap_cache_test_equal(first, next)
  }
  assert_eq(
    cache.context.budget.account.snapshot().cumulative.inflate_bytes - before,
    cmap_cache_test_text("41", "0041").length().to_int64(),
  )
  assert_eq(cache.entries.length(), 1)
}

///|
async test "Loaded zero-text CMap shares its local empty maps without inventing parser calls" {
  let bytes = cmap_cache_test_pdf(kind="empty")
  let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
  defer @input.end_input_session(owner)
  let store = loaded_font_result_test_store(owner.source, bytes)
  let object = store.object_index.get(101).unwrap()
  let cache = loaded_cmap_test_cache(owner.source, store)
  let first = pdf_local_tounicode_cmap_info(object, Some(cache)).unwrap()
  let next = pdf_local_tounicode_cmap_info(object, Some(cache)).unwrap()
  assert_true(first.mapping.is_empty())
  assert_true(physical_equal(first.mapping, next.mapping))
  assert_eq(cache.entries.length(), 1)
}

///|
async test "Loaded ordinary post-Flate filter CMap error avoids seven repeated actual inflates" {
  let bytes = cmap_cache_test_pdf()
  let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
  defer @input.end_input_session(owner)
  let store = loaded_font_result_test_store(owner.source, bytes)
  let original = store.object_index.get(101).unwrap()
  assert_true(original.dict_text.contains("/ASCIIHexDecode /FlateDecode"))
  let object = {
    ..original,
    dict_text: original.dict_text.replace(
      old="/ASCIIHexDecode /FlateDecode",
      new="/ASCIIHexDecode /FlateDecode /UnknownCMapFilter",
    ),
  }
  let cache = loaded_cmap_test_cache(owner.source, store)
  let before = cache.context.budget.account.snapshot().cumulative.inflate_bytes
  for _ in 0..<8 {
    assert_true(pdf_local_tounicode_cmap_info(object, Some(cache)) is Err(_))
  }
  assert_eq(
    cache.context.budget.account.snapshot().cumulative.inflate_bytes - before,
    cmap_cache_test_text("41", "0041").length().to_int64(),
  )
  assert_eq(cache.entries.length(), 1)
}

///|
async test "Loaded ordinary post-Flate predictor CMap error keeps the same local failure" {
  let bytes = cmap_cache_test_pdf()
  let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
  defer @input.end_input_session(owner)
  let store = loaded_font_result_test_store(owner.source, bytes)
  let original = store.object_index.get(101).unwrap()
  let object = {
    ..original,
    dict_text: original.dict_text.replace(
      old="/FlateDecode ]",
      new="/FlateDecode ] /DecodeParms [null << /Predictor 99 >>]",
    ),
  }
  let cache = loaded_cmap_test_cache(owner.source, store)
  let before = cache.context.budget.account.snapshot().cumulative.inflate_bytes
  for _ in 0..<8 {
    assert_true(pdf_local_tounicode_cmap_info(object, Some(cache)) is Err(_))
  }
  assert_eq(
    cache.context.budget.account.snapshot().cumulative.inflate_bytes - before,
    cmap_cache_test_text("41", "0041").length().to_int64(),
  )
  assert_eq(cache.entries.length(), 1)
}

///|
async fn loaded_cmap_test_fixture(
  payload : Bytes,
  plan~ : String = "/Filter /FlateDecode",
) -> (@input.InputSession, PdfLocalCMapCache, PdfNativeObject) {
  let bytes = loaded_font_result_test_raw_file(payload, plan)
  let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
  let store = loaded_font_result_test_store(owner.source, bytes)
  (
    owner,
    loaded_cmap_test_cache(owner.source, store),
    store.object_index.get(71).unwrap(),
  )
}

///|
async test "Loaded CMap expected store bypasses foreign snapshots before and after its first hit" {
  let bytes = cmap_cache_test_pdf(kind="empty")
  let account = @budget.Budget::new(loaded_objstm_limits())
  let owner = @input.begin_input_session(
    @input.input_from_bytes(bytes),
    budget=account,
  )
  // Real nested documents borrow one session. Two independent owners that
  // close the same account while each retains leases would correctly latch
  // OutstandingLeases, rather than isolate this owner-close contract.
  let other = @input.begin_input_session(
    @input.input_source_inherit_session(
      @input.input_from_bytes(bytes),
      owner.source,
    ),
  )
  defer @input.end_input_session(owner)
  defer @input.end_input_session(other)
  let store = loaded_font_result_test_store(owner.source, bytes)
  let foreign = loaded_font_result_test_store(other.source, bytes)
  let cache = loaded_cmap_test_cache(owner.source, store)
  let object = store.object_index.get(101).unwrap()
  let other_object = foreign.object_index.get(101).unwrap()
  let first_key = pdf_local_cmap_key(object).unwrap()
  let other_key = pdf_local_cmap_key(other_object).unwrap()
  assert_false(first_key == other_key)
  assert_eq(Hash::hash(first_key), Hash::hash(other_key))
  assert_true(cmap_cache_test_get(other_object, Some(cache)).unwrap() is Ok(_))
  assert_eq(cache.entries.length(), 0)
  assert_true(cmap_cache_test_get(object, Some(cache)).unwrap() is Ok(_))
  assert_eq(cache.entries.length(), 1)
  assert_true(cmap_cache_test_get(other_object, Some(cache)).unwrap() is Ok(_))
  assert_eq(cache.entries.length(), 1)
  let rematerialized = loaded_font_result_test_store(owner.source, bytes)
  assert_true(
    cmap_cache_test_get(
      rematerialized.object_index.get(101).unwrap(),
      Some(cache),
    ).unwrap()
    is Ok(_),
  )
  assert_eq(cache.entries.length(), 1)
  @input.end_input_session(owner)
  let before = account.snapshot().cumulative
  assert_true(
    cmap_cache_test_get(other_object, Some(cache)) is Err(ReadFailed(_)),
  )
  assert_true(account.snapshot().cumulative == before)
}

///|
async test "Loaded CMap first hard failure and close cannot be bypassed by positive or ordinary negative hits" {
  for kind in ["valid", "empty", "soft"] {
    for failure in 0..<4 {
      let bytes = cmap_cache_test_pdf(kind~)
      let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
      let store = loaded_font_result_test_store(owner.source, bytes)
      let cache = loaded_cmap_test_cache(owner.source, store)
      let object = store.object_index.get(101).unwrap()
      ignore(cmap_cache_test_get(object, Some(cache)).unwrap())
      assert_eq(cache.entries.length(), 1)
      let before = cache.context.budget.account.snapshot().cumulative
      match failure {
        0 => @input.record_input_failure(owner.source, "Loaded CMap first IO")
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
      let result = cmap_cache_test_get(object, Some(cache))
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
      assert_true(cache.context.budget.account.snapshot().cumulative == before)
      assert_eq(cache.entries.length(), 1)
      @input.end_input_session(owner)
      assert_eq(cache.context.budget.account.snapshot().active_leases, 0L)
    }
  }
}

///|
async test "Loaded CMap current raw proof and indirect Length cannot alias an earlier local result" {
  let text = pdf_ascii_bytes(cmap_cache_test_text("41", "0041"))
  let (bytes, _, _) = loaded_definition_test_file(text, indirect_length=true)
  let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
  defer @input.end_input_session(owner)
  let store = loaded_font_result_test_store(owner.source, bytes)
  let cache = loaded_cmap_test_cache(owner.source, store)
  let object = store.object_index.get(71).unwrap()
  let (slice, definition) = match object.stream {
    Some(SelectedLoaded(slice, definition)) => (slice, definition)
    _ => fail("actual selected indirect Length definition required")
  }
  for
    next in [
      { ..definition, generation: definition.generation + 1, },
      { ..definition, definition_offset: definition.definition_offset + 1L, },
      { ..definition, payload_start: definition.payload_start + 1L, },
      { ..definition, body_start: definition.body_start + 1L, },
      { ..definition, object_id: definition.object_id + 1, },
    ] {
    let changed = { ..object, stream: Some(SelectedLoaded(slice, next)), }
    assert_false(pdf_local_cmap_key(object) == pdf_local_cmap_key(changed))
  }
  assert_true(cmap_cache_test_get(object, Some(cache)).unwrap() is Ok(_))
  let unresolved = {
    ..object,
    stream: Some(
      SelectedLoaded({ ..slice, declared_length: None, }, definition),
    ),
  }
  assert_false(pdf_local_cmap_key(object) == pdf_local_cmap_key(unresolved))
  assert_true(cmap_cache_test_get(unresolved, Some(cache)).unwrap() is Ok(_))
  assert_eq(cache.entries.length(), 2)
  let raw = Bytes::makei(slice.primary_bytes.length(), i => {
    if i + 1 == slice.primary_bytes.length() {
      slice.primary_bytes[i] ^ b'\x01'
    } else {
      slice.primary_bytes[i]
    }
  })
  let corrupt = {
    ..object,
    stream: Some(
      SelectedLoaded(
        { ..slice, primary_bytes: raw, endstream_bytes: raw, },
        definition,
      ),
    ),
  }
  assert_false(pdf_local_cmap_key(object) == pdf_local_cmap_key(corrupt))
  assert_true(
    cmap_cache_test_get(corrupt, Some(cache))
    is Err(StreamIntegrityFailed(_, _)),
  )
  assert_eq(cache.entries.length(), 2)
  let before = cache.context.budget.account.snapshot().cumulative
  assert_true(cmap_cache_test_get(object, Some(cache)) is Err(ReadFailed(_)))
  assert_true(cache.context.budget.account.snapshot().cumulative == before)
}

///|
fn loaded_cmap_test_parent_file(named : Bool, corrupt : Bool) -> Bytes {
  let out = Buffer()
  out.write_bytes(b"%PDF-1.4\n")
  for
    (id, extra, text) in [
      (
        71,
        if named {
          ""
        } else {
          "/UseCMap 72 0 R"
        },
        cmap_cache_test_text("41", "0041") +
        (if named { " /Parent usecmap" } else { "" }),
      ),
      (
        72,
        if named {
          "/CMapName /Parent"
        } else {
          ""
        },
        cmap_cache_test_text("42", "0042"),
      ),
    ] {
    let payload = if id == 72 && corrupt {
      b"\x78\x9c\x00"
    } else {
      @zlib.zlib_compress(pdf_ascii_bytes(text))
    }
    out.write_bytes(
      pdf_ascii_bytes(
        id.to_string() +
        " 0 obj\n<< " +
        extra +
        " /Filter /FlateDecode /Length " +
        payload.length().to_string() +
        " >>\nstream\n",
      ),
    )
    out.write_bytes(payload)
    out.write_bytes(b"\nendstream\nendobj\n")
  }
  out.to_bytes()
}

///|
async fn loaded_cmap_test_collect(
  id : Int32,
  index : Map[Int32, PdfNativeObject],
  cache : PdfLocalCMapCache?,
  depth~ : Int32 = 8,
  visited~ : Map[Int32, Bool] = Map([]),
) -> Result[Result[PdfToUnicodeCMapInfo, String], PdfNativeError] {
  Ok(
    pdf_collect_tounicode_cmap_info(
      id,
      index,
      visited,
      depth,
      local_cache=cache,
    ),
  ) catch {
    PdfHardDecodeFailure(error) => Err(error)
    error => raise error
  }
}

///|
async test "Loaded CMap parent dictionary and name lookups remain dynamic after local publication" {
  for named in [false, true] {
    let bytes = loaded_cmap_test_parent_file(named, false)
    let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
    defer @input.end_input_session(owner)
    let store = loaded_font_result_test_store(owner.source, bytes)
    let cache = loaded_cmap_test_cache(owner.source, store)
    let index = Map([(71, store.object_index.get(71).unwrap())])
    let first = loaded_cmap_test_collect(71, index, Some(cache))
      .unwrap()
      .unwrap()
    assert_true(first.mapping.get("41") == Some("A"))
    assert_true(first.mapping.get("42") is None)
    assert_eq(cache.entries.length(), 1)
    index.set(72, store.object_index.get(72).unwrap())
    let second = loaded_cmap_test_collect(71, index, Some(cache))
      .unwrap()
      .unwrap()
    assert_true(second.mapping.get("42") == Some("B"))
    assert_eq(cache.entries.length(), 2)
    second.mapping.set("AA", "outside mutation")
    let again = loaded_cmap_test_collect(71, index, Some(cache))
      .unwrap()
      .unwrap()
    assert_true(again.mapping.get("AA") is None)
  }
}

///|
async test "Loaded CMap local memoization leaves visited depth and cycle resolution outside the cache" {
  let bytes = cmap_cache_test_pdf(kind="cycle")
  let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
  defer @input.end_input_session(owner)
  let store = loaded_font_result_test_store(owner.source, bytes)
  let cache = loaded_cmap_test_cache(owner.source, store)
  for depth in [0, 1, 2, 7, 8, 9] {
    for blocked in [None, Some(101), Some(102)] {
      let visited : Map[Int32, Bool] = Map([])
      if blocked is Some(id) {
        visited.set(id, true)
      }
      let old = loaded_cmap_test_collect(
          101,
          store.object_index,
          None,
          depth~,
          visited=visited.copy(),
        )
        .unwrap()
        .unwrap()
      let new_value = loaded_cmap_test_collect(
          101,
          store.object_index,
          Some(cache),
          depth~,
          visited=visited.copy(),
        )
        .unwrap()
        .unwrap()
      cmap_cache_test_equal(old, new_value)
    }
  }
  assert_eq(cache.entries.length(), 2)
}

///|
async test "Loaded CMap publication cap precedes a later parent CRC while CRC remains hard without the cap" {
  for limited in [false, true] {
    let bytes = loaded_cmap_test_parent_file(false, true)
    let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
    let store = loaded_font_result_test_store(owner.source, bytes)
    let cache = loaded_cmap_test_cache(owner.source, store)
    let account = cache.context.budget.account
    if limited {
      account
      .tighten_resident_limit(
        CacheBytes,
        account.snapshot().resident.cache_bytes,
      )
      .unwrap()
    }
    let before = account.snapshot().cumulative.inflate_bytes
    let result = loaded_cmap_test_collect(71, store.object_index, Some(cache))
    if limited {
      assert_true(result is Err(BudgetExceeded(_)))
      assert_true(
        @input.input_source_failure(owner.source) is Some(BudgetFailure(_)),
      )
      assert_eq(cache.entries.length(), 0)
    } else {
      assert_true(result is Err(StreamIntegrityFailed(_, _)))
      assert_eq(cache.entries.length(), 1)
    }
    assert_eq(
      account.snapshot().cumulative.inflate_bytes - before,
      cmap_cache_test_text("41", "0041").length().to_int64(),
    )
    let cumulative = account.snapshot().cumulative
    assert_true(
      cmap_cache_test_get(store.object_index.get(71).unwrap(), Some(cache))
      is Err(_),
    )
    assert_true(account.snapshot().cumulative == cumulative)
    @input.end_input_session(owner)
    assert_eq(account.snapshot().active_leases, 0L)
  }
}

///|
async test "Loaded CMap retained payload includes the shared proof and fixed expected snapshot publication slot" {
  let (owner, cache, object) = loaded_cmap_test_fixture(
    @zlib.zlib_compress(b""),
  )
  defer @input.end_input_session(owner)
  let key = pdf_local_cmap_key(object).unwrap()
  let proof = key.loaded.unwrap()
  let expected = 92L +
    2L * key.dict_text.length().to_int64() +
    pdf_loaded_stream_proof_retained_payload(proof)
  assert_eq(
    pdf_local_cmap_retained_payload(cache.context, key, Err("")),
    expected,
  )
  assert_eq(
    pdf_local_cmap_retained_payload(
      cache.context,
      { ..key, declared_length: None, },
      Err("x"),
    ),
    expected + 2L,
  )
  let result = Ok(pdf_empty_tounicode_cmap_info())
  let entry = pdf_local_cmap_retained_payload(cache.context, key, result)
  let before = cache.context.budget.account.snapshot().resident.cache_bytes
  assert_true(cmap_cache_test_get(object, Some(cache)).unwrap() is Ok(_))
  assert_eq(
    cache.context.budget.account.snapshot().resident.cache_bytes - before,
    entry + 24L,
  )
  assert_true(cmap_cache_test_get(object, Some(cache)).unwrap() is Ok(_))
  assert_eq(
    cache.context.budget.account.snapshot().resident.cache_bytes - before,
    entry + 24L,
  )
}

///|
async test "Loaded CMap cooperative cancellation before local lookup cannot publish a cached absence" {
  let (owner, cache, object) = loaded_cmap_test_fixture(
    @zlib.zlib_compress(b""),
  )
  let entered = Ref(false)
  let before = cache.context.budget.account.snapshot().cumulative
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @async.handle_cancellation(() => {
        entered.val = true
        while true {
          @async.pause()
        }
        cmap_cache_test_get(object, Some(cache))
      })
    })
    while !entered.val {
      @async.pause()
    }
    task.cancel()
    assert_true(task.wait() is None)
  })
  assert_eq(cache.entries.length(), 0)
  assert_true(cache.context.budget.account.snapshot().cumulative == before)
  @input.end_input_session(owner)
  assert_eq(cache.context.budget.account.snapshot().active_leases, 0L)
}

///|
async test "Loaded CMap exact cap includes its first publication wrapper and rejects one byte short" {
  for short in [false, true] {
    let (owner, cache, object) = loaded_cmap_test_fixture(
      @zlib.zlib_compress(b""),
    )
    let account = cache.context.budget.account
    let used = account.snapshot().resident.cache_bytes
    let required = pdf_local_cmap_retained_payload(
        cache.context,
        pdf_local_cmap_key(object).unwrap(),
        Ok(pdf_empty_tounicode_cmap_info()),
      ) +
      24L
    let cap = used + required - (if short { 1L } else { 0L })
    account.tighten_resident_limit(CacheBytes, cap).unwrap()
    let result = cmap_cache_test_get(object, Some(cache))
    if short {
      match result {
        Err(
          BudgetExceeded(
            LimitExceeded(
              Resident(CacheBytes),
              used=actual_used,
              requested~,
              limit~
            )
          )
        ) => {
          assert_eq(actual_used, used)
          assert_eq(requested, required)
          assert_eq(limit, cap)
        }
        _ =>
          fail("one byte short must retain the exact typed publication extent")
      }
      assert_eq(cache.entries.length(), 0)
      assert_true(
        @input.input_source_failure(owner.source) is Some(BudgetFailure(_)),
      )
    } else {
      assert_true(result.unwrap() is Ok(_))
      assert_eq(cache.entries.length(), 1)
      assert_eq(account.snapshot().resident.cache_bytes, cap)
      assert_true(cmap_cache_test_get(object, Some(cache)).unwrap() is Ok(_))
      assert_eq(account.snapshot().resident.cache_bytes, cap)
    }
    @input.end_input_session(owner)
    assert_eq(account.snapshot().active_leases, 0L)
  }
}
