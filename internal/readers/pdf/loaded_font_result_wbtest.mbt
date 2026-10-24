///|
async fn loaded_font_result_test_store(
  source : @input.InputSource,
  bytes : Bytes,
) -> PdfParsedObjectStore {
  pdf_parse_objects(
    bytes,
    pdf_byte_string(bytes),
    decode_context=pdf_make_stream_decode_context(source),
  ).unwrap()
}

///|
async fn loaded_font_result_test_repeat(
  payload : Bytes,
  plan : String,
  kind : Int32?,
) -> Unit {
  let (bytes, _, _) = loaded_definition_test_file(payload)
  let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
  defer @input.end_input_session(owner)
  let store = loaded_font_result_test_store(owner.source, bytes)
  let original = store.object_index.get(71).unwrap()
  let object = { ..original, dict_text: "<< " + plan + " >>", }
  let cache = pdf_make_font_program_cache(
    owner.source,
    loaded_snapshot=pdf_loaded_store_snapshot(store.objects),
  ).unwrap()
  let before = cache.context.budget.account.snapshot().cumulative.inflate_bytes
  for _ in 0..<8 {
    assert_true(font_cache_test_get(object, cache, kind~).unwrap() is None)
  }
  assert_eq(
    cache.context.budget.account.snapshot().cumulative.inflate_bytes - before,
    payload.length().to_int64(),
  )
  assert_eq(cache.programs.length(), 1)
}

///|
async test "Loaded shared FontFile success decodes and parses once across the real font registry" {
  let bytes = font_cache_test_shared_pdf()
  let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
  defer @input.end_input_session(owner)
  let store = loaded_font_result_test_store(owner.source, bytes)
  let cache = pdf_make_font_program_cache(
    owner.source,
    loaded_snapshot=pdf_loaded_store_snapshot(store.objects),
  ).unwrap()
  let before = cache.context.budget.account.snapshot().cumulative.inflate_bytes
  let registry = pdf_collect_font_infos(
    store.object_index,
    program_cache=Some(cache),
  ).unwrap()
  assert_eq(
    cache.context.budget.account.snapshot().cumulative.inflate_bytes - before,
    font_cache_test_sfnt().length().to_int64(),
  )
  assert_eq(cache.programs.length(), 1)
  let shared = registry.infos.get(90).unwrap().embedded_font_program.unwrap()
  assert_eq(pdf_embedded_font_program_unicode(shared, 1), Some("A"))
  for id in 10..<18 {
    let actual = registry.infos.get(id).unwrap().embedded_font_program.unwrap()
    assert_true(
      physical_equal(shared.gid_unicode_gids, actual.gid_unicode_gids),
    )
    assert_eq(actual.gid_advance_pairs, [0, 500, 1, 600, 2, 700])
  }
}

///|
async test "Loaded unknown FontFile subtype reuses a validated local absence" {
  loaded_font_result_test_repeat(b"font", "/Filter /FlateDecode", None)
}

///|
async test "Loaded ordinary filter failure reuses the exact local decode plan" {
  loaded_font_result_test_repeat(
    font_cache_test_sfnt(),
    "/Filter [/FlateDecode /UnknownFilter]",
    Some(0),
  )
}

///|
async test "Loaded ordinary predictor failure reuses the exact local decode plan" {
  loaded_font_result_test_repeat(
    font_cache_test_sfnt(),
    "/Filter /FlateDecode /DecodeParms << /Predictor 99 >>",
    Some(0),
  )
}

///|
fn loaded_font_result_test_raw_file(encoded : Bytes, plan : String) -> Bytes {
  let out = Buffer()
  out.write_bytes(
    pdf_ascii_bytes(
      "%PDF-1.4\n71 7 obj\n<< /Length " +
      encoded.length().to_string() +
      " " +
      plan +
      " >>\nstream\n",
    ),
  )
  out.write_bytes(encoded)
  out.write_bytes(b"\r\nendstream\nendobj\n")
  out.to_bytes()
}

///|
async fn loaded_font_result_test_fixture(
  encoded : Bytes,
  plan : String,
) -> (@input.InputSession, PdfFontProgramCache, PdfNativeObject) {
  let bytes = loaded_font_result_test_raw_file(encoded, plan)
  let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
  let store = loaded_font_result_test_store(owner.source, bytes)
  let cache = pdf_make_font_program_cache(
    owner.source,
    loaded_snapshot=pdf_loaded_store_snapshot(store.objects),
  ).unwrap()
  (owner, cache, store.object_index.get(71).unwrap())
}

///|
async test "Loaded store binding bypasses a foreign snapshot on the same account including the first lookup" {
  let bytes = loaded_font_result_test_raw_file(
    @zlib.zlib_compress(b"font"),
    "/Filter /FlateDecode",
  )
  let account = @budget.Budget::new(loaded_objstm_limits())
  let owner = @input.begin_input_session(
    @input.input_from_bytes(bytes),
    budget=account,
  )
  let foreign = @input.begin_input_session(
    @input.input_from_bytes(bytes),
    budget=account,
  )
  defer @input.end_input_session(owner)
  defer @input.end_input_session(foreign)
  let store = loaded_font_result_test_store(owner.source, bytes)
  let other = loaded_font_result_test_store(foreign.source, bytes)
  let object = store.object_index.get(71).unwrap()
  let foreign_object = other.object_index.get(71).unwrap()
  let key = pdf_font_program_cache_key(object, None).unwrap()
  let foreign_key = pdf_font_program_cache_key(foreign_object, None).unwrap()
  assert_false(key == foreign_key)
  // Hash collisions of different opaque authorities are deliberately safe.
  assert_eq(Hash::hash(key), Hash::hash(foreign_key))
  let cache = pdf_make_font_program_cache(
    owner.source,
    loaded_snapshot=pdf_loaded_store_snapshot(store.objects),
  ).unwrap()
  let before = account.snapshot().cumulative.inflate_bytes
  assert_true(font_cache_test_get(foreign_object, cache, kind=None) is Ok(None))
  assert_eq(cache.programs.length(), 0)
  assert_true(font_cache_test_get(object, cache, kind=None) is Ok(None))
  assert_eq(cache.programs.length(), 1)
  assert_true(font_cache_test_get(foreign_object, cache, kind=None) is Ok(None))
  assert_eq(cache.programs.length(), 1)
  assert_eq(account.snapshot().cumulative.inflate_bytes - before, 12L)
}

///|
async test "Loaded new materialization on the original live owner cannot reuse the first snapshot cache" {
  let (bytes, _, _) = loaded_definition_test_file(b"font")
  let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
  defer @input.end_input_session(owner)
  let first = loaded_font_result_test_store(owner.source, bytes)
  let second = loaded_font_result_test_store(owner.source, bytes)
  let cache = pdf_make_font_program_cache(
    owner.source,
    loaded_snapshot=pdf_loaded_store_snapshot(first.objects),
  ).unwrap()
  let before = cache.context.budget.account.snapshot().cumulative.inflate_bytes
  assert_true(
    font_cache_test_get(first.object_index.get(71).unwrap(), cache, kind=None)
    is Ok(None),
  )
  for _ in 0..<2 {
    assert_true(
      font_cache_test_get(
        second.object_index.get(71).unwrap(),
        cache,
        kind=None,
      )
      is Ok(None),
    )
  }
  assert_eq(cache.programs.length(), 1)
  assert_eq(
    cache.context.budget.account.snapshot().cumulative.inflate_bytes - before,
    12L,
  )
}

///|
async test "Loaded cache requires an explicit full store binding and leaves unproven Loaded uncached" {
  let (bytes, offset, _) = loaded_definition_test_file(b"font")
  let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
  defer @input.end_input_session(owner)
  let store = loaded_font_result_test_store(owner.source, bytes)
  let unbound = pdf_make_font_program_cache(owner.source).unwrap()
  let legacy = pdf_parse_indirect_object_at(
    bytes,
    offset,
    decode_context=pdf_make_stream_decode_context(owner.source),
  ).unwrap()
  let bound = pdf_make_font_program_cache(
    owner.source,
    loaded_snapshot=pdf_loaded_store_snapshot(store.objects),
  ).unwrap()
  let before = bound.context.budget.account.snapshot().cumulative.inflate_bytes
  for _ in 0..<2 {
    assert_true(
      font_cache_test_get(
        store.object_index.get(71).unwrap(),
        unbound,
        kind=None,
      )
      is Ok(None),
    )
    assert_true(font_cache_test_get(legacy, bound, kind=None) is Ok(None))
  }
  assert_eq(unbound.programs.length(), 0)
  assert_eq(bound.programs.length(), 0)
  assert_eq(
    bound.context.budget.account.snapshot().cumulative.inflate_bytes - before,
    16L,
  )
}

///|
async test "Loaded definition generation offset and kind remain independent local cache keys" {
  let (first, _, _) = loaded_definition_test_file(b"first", generation=7)
  let (second, _, _) = loaded_definition_test_file(b"second", generation=8)
  let bytes = first + second
  let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
  defer @input.end_input_session(owner)
  let store = loaded_font_result_test_store(owner.source, bytes)
  let cache = pdf_make_font_program_cache(
    owner.source,
    loaded_snapshot=pdf_loaded_store_snapshot(store.objects),
  ).unwrap()
  for object in store.objects {
    assert_true(font_cache_test_get(object, cache).unwrap() is Some(_))
  }
  assert_eq(cache.programs.length(), 2)
  let object = store.objects[0]
  for kind in [None, Some(1), Some(2)] {
    ignore(font_cache_test_get(object, cache, kind~).unwrap())
  }
  assert_eq(cache.programs.length(), 5)
}

///|
async test "Loaded current indirect Length framing and full dictionary participate in the key" {
  let (bytes, _, _) = loaded_definition_test_file(b"font", indirect_length=true)
  let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
  defer @input.end_input_session(owner)
  let store = loaded_font_result_test_store(owner.source, bytes)
  let object = store.object_index.get(71).unwrap()
  let cache = pdf_make_font_program_cache(
    owner.source,
    loaded_snapshot=pdf_loaded_store_snapshot(store.objects),
  ).unwrap()
  let unresolved = match object.stream {
    Some(SelectedLoaded(slice, definition)) =>
      {
        ..object,
        stream: Some(
          SelectedLoaded({ ..slice, declared_length: None, }, definition),
        ),
      }
    _ => fail("expected the proven indirect definition")
  }
  let extra = { ..object, dict_text: object.dict_text + " /Unused 0", }
  let before = cache.context.budget.account.snapshot().cumulative.inflate_bytes
  for candidate in [unresolved, object, extra] {
    assert_true(font_cache_test_get(candidate, cache, kind=None) is Ok(None))
  }
  assert_eq(cache.programs.length(), 3)
  assert_eq(
    cache.context.budget.account.snapshot().cumulative.inflate_bytes - before,
    12L,
  )
}

///|
async test "Loaded raw byte proof prevents a cached success from concealing corrupted Adler bytes" {
  let (owner, cache, object) = loaded_font_result_test_fixture(
    @zlib.zlib_compress(b"font"),
    "/Filter /FlateDecode",
  )
  defer @input.end_input_session(owner)
  assert_true(font_cache_test_get(object, cache, kind=None) is Ok(None))
  let corrupt = match object.stream {
    Some(SelectedLoaded(slice, definition)) => {
      let raw = Bytes::makei(slice.primary_bytes.length(), i => {
        if i + 1 == slice.primary_bytes.length() {
          slice.primary_bytes[i] ^ b'\x01'
        } else {
          slice.primary_bytes[i]
        }
      })
      {
        ..object,
        stream: Some(
          SelectedLoaded(
            { ..slice, primary_bytes: raw, endstream_bytes: raw, },
            definition,
          ),
        ),
      }
    }
    _ => fail("expected a selected definition")
  }
  assert_false(
    pdf_font_program_cache_key(object, None) ==
    pdf_font_program_cache_key(corrupt, None),
  )
  assert_true(
    font_cache_test_get(corrupt, cache, kind=None)
    is Err(StreamIntegrityFailed(_, _)),
  )
  assert_eq(cache.programs.length(), 1)
  let before = cache.context.budget.account.snapshot().cumulative
  assert_true(
    font_cache_test_get(object, cache, kind=None) is Err(ReadFailed(_)),
  )
  assert_true(cache.context.budget.account.snapshot().cumulative == before)
}

///|
async test "Loaded hard integrity wins before postparse publication and is never a negative result" {
  for
    plan in [
      "/Filter /FlateDecode", "/Filter [/FlateDecode /UnknownFilter]", "/Filter /FlateDecode /DecodeParms << /Predictor 99 >>",
    ] {
    let (owner, cache, object) = loaded_font_result_test_fixture(
      b"\x78\x9c\x00", plan,
    )
    let account = cache.context.budget.account
    let used = account.snapshot().resident.cache_bytes
    assert_true(account.tighten_resident_limit(CacheBytes, used) is Ok(_))
    assert_true(
      font_cache_test_get(object, cache, kind=None)
      is Err(StreamIntegrityFailed(_, _)),
    )
    assert_eq(cache.programs.length(), 0)
    assert_true(
      @input.input_source_failure(owner.source) is Some(InputError(_)),
    )
    let before = account.snapshot().cumulative
    assert_true(
      font_cache_test_get(object, cache, kind=None) is Err(ReadFailed(_)),
    )
    assert_true(account.snapshot().cumulative == before)
    @input.end_input_session(owner)
    assert_eq(account.snapshot().active_leases, 0L)
  }
}

///|
async test "Loaded negative publication cap fails typed before a scheduled later malformed stream" {
  let (owner, cache, object) = loaded_font_result_test_fixture(
    @zlib.zlib_compress(b"font"),
    "/Filter /FlateDecode",
  )
  let account = cache.context.budget.account
  let used = account.snapshot().resident.cache_bytes
  assert_true(account.tighten_resident_limit(CacheBytes, used) is Ok(_))
  let key = pdf_font_program_cache_key(object, None).unwrap()
  let required = pdf_font_result_retained_payload(cache.context, key, Ok(None)) +
    24L
  match font_cache_test_get(object, cache, kind=None) {
    Err(
      BudgetExceeded(
        LimitExceeded(Resident(CacheBytes), used=actual, requested~, limit~)
      )
    ) => {
      assert_eq(actual, used)
      assert_eq(limit, used)
      assert_eq(requested, required)
    }
    _ => fail("postparse publication must preserve the typed exact admission")
  }
  assert_true(
    @input.input_source_failure(owner.source) is Some(BudgetFailure(_)),
  )
  assert_eq(cache.programs.length(), 0)
  let corrupt = match object.stream {
    Some(SelectedLoaded(slice, definition)) =>
      {
        ..object,
        stream: Some(
          SelectedLoaded(
            {
              ..slice,
              primary_bytes: b"\x78\x9c\x00",
              endstream_bytes: b"\x78\x9c\x00",
              declared_length: Some(3),
            },
            definition,
          ),
        ),
      }
    _ => fail("expected a selected definition")
  }
  let before = account.snapshot().cumulative
  assert_true(
    font_cache_test_get(corrupt, cache, kind=None) is Err(BudgetExceeded(_)),
  )
  assert_true(account.snapshot().cumulative == before)
  @input.end_input_session(owner)
  assert_eq(account.snapshot().active_leases, 0L)
}

///|
async test "Loaded success and negative hits honor IO Budget Resource and closed first failures" {
  for kind in [None, Some(0)] {
    for failure in 0..<4 {
      let (owner, cache, object) = loaded_font_result_test_fixture(
        @zlib.zlib_compress(b"font"),
        "/Filter /FlateDecode",
      )
      ignore(font_cache_test_get(object, cache, kind~).unwrap())
      let before = cache.context.budget.account.snapshot().cumulative
      match failure {
        0 =>
          @input.record_input_failure(owner.source, "Loaded fixture first IO")
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
      let result = font_cache_test_get(object, cache, kind~)
      if failure == 1 {
        assert_true(result is Err(BudgetExceeded(_)))
      } else {
        assert_true(result is Err(ReadFailed(_)))
      }
      assert_eq(cache.programs.length(), 1)
      assert_true(cache.context.budget.account.snapshot().cumulative == before)
      @input.end_input_session(owner)
      assert_eq(cache.context.budget.account.snapshot().active_leases, 0L)
    }
  }
}

///|
async test "Loaded cooperative cancellation before lookup publishes neither absence nor success" {
  let (owner, cache, object) = loaded_font_result_test_fixture(
    @zlib.zlib_compress(b"font"),
    "/Filter /FlateDecode",
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
        font_cache_test_get(object, cache, kind=None)
      })
    })
    while !entered.val {
      @async.pause()
    }
    task.cancel()
    assert_true(task.wait() is None)
  })
  assert_eq(cache.programs.length(), 0)
  assert_true(cache.context.budget.account.snapshot().cumulative == before)
  assert_true(@input.input_source_failure(owner.source) is None)
  @input.end_input_session(owner)
  assert_eq(cache.context.budget.account.snapshot().active_leases, 0L)
}

///|
async test "Loaded retained model counts native key proof fixed slots and both raw candidates" {
  let (owner, cache, object) = loaded_font_result_test_fixture(
    @zlib.zlib_compress(b"font"),
    "/Filter /FlateDecode",
  )
  defer @input.end_input_session(owner)
  let key = {
    ..pdf_font_program_cache_key(object, None).unwrap(),
    plan: Resolved([], []),
  }
  let proof = key.loaded.unwrap()
  let expected = 100L +
    40L +
    16L +
    proof.dict_text.length().to_int64() * 2L +
    proof.primary_bytes.length().to_int64() +
    proof.endstream_bytes.length().to_int64()
  assert_eq(
    pdf_font_result_retained_payload(cache.context, key, Ok(None)),
    expected,
  )
  assert_eq(
    pdf_font_result_retained_payload(
      cache.context,
      { ..key, kind: Some(0), declared_length: None, },
      Ok(None),
    ),
    expected,
  )
  assert_eq(
    pdf_font_result_retained_payload(cache.context, key, Err("no")),
    expected + 4L,
  )
  let empty : PdfEmbeddedFontProgram = {
    gid_unicode_gids: [],
    gid_unicode_values: [],
    gid_glyph_name_gids: [],
    gid_glyph_name_values: [],
    gid_advance_pairs: [],
    default_advance_width: None,
  }
  assert_eq(
    pdf_font_result_retained_payload(cache.context, key, Ok(Some(empty))),
    expected + 48L,
  )
  assert_eq(
    pdf_font_result_retained_payload(
      cache.context,
      { ..key, loaded: None, },
      Ok(None),
    ),
    116L,
  )
}

///|
async test "Loaded first publication admits its cache wrapper exactly once with exact cap boundaries" {
  for short in [false, true] {
    let (owner, cache, object) = loaded_font_result_test_fixture(
      @zlib.zlib_compress(b"font"),
      "/Filter /FlateDecode",
    )
    let account = cache.context.budget.account
    let before = account.snapshot().resident.cache_bytes
    let payload = pdf_font_result_retained_payload(
      cache.context,
      pdf_font_program_cache_key(object, None).unwrap(),
      Ok(None),
    )
    let cap = before + payload + 24L - (if short { 1L } else { 0L })
    assert_true(account.tighten_resident_limit(CacheBytes, cap) is Ok(_))
    let result = font_cache_test_get(object, cache, kind=None)
    if short {
      assert_true(result is Err(BudgetExceeded(_)))
      assert_eq(cache.programs.length(), 0)
      assert_eq(account.snapshot().resident.cache_bytes, before)
    } else {
      assert_true(result is Ok(None))
      assert_eq(account.snapshot().resident.cache_bytes, before + payload + 24L)
      assert_true(font_cache_test_get(object, cache, kind=None) is Ok(None))
      assert_eq(account.snapshot().resident.cache_bytes, before + payload + 24L)
      assert_eq(cache.programs.length(), 1)
    }
    @input.end_input_session(owner)
    assert_eq(account.snapshot().active_leases, 0L)
  }
}
