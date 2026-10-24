///|
async fn wrapper_font_publication_contract(loaded : Bool) -> Unit {
  for outcome in ["success", "none", "ordinary_error"] {
    let encoded = @zlib.zlib_compress(font_cache_test_sfnt())
    let plan = if outcome == "ordinary_error" {
      "/Filter [/FlateDecode /UnsupportedWrapperFilter]"
    } else {
      "/Filter /FlateDecode"
    }
    let (owner, cache, object) = if loaded {
      loaded_font_result_test_fixture(encoded, plan)
    } else {
      let (owner, cache, object, _) = font_result_test_reader_fixture(
        encoded, plan,
      )
      (owner, cache, object)
    }
    defer @input.end_input_session(owner)
    let account = cache.context.budget.account
    let before = account.snapshot().resident.cache_bytes
    let kind = if outcome == "none" { None } else { Some(0) }
    let first = font_cache_test_get(object, cache, kind~).unwrap()
    assert_eq(first is Some(_), outcome == "success")
    let key = pdf_font_program_cache_key(object, kind).unwrap()
    let stored = cache.programs.get(key).unwrap()
    assert_eq(stored is Err(_), outcome == "ordinary_error")
    let entry = pdf_font_result_retained_payload(cache.context, key, stored)
    assert_eq(account.snapshot().resident.cache_bytes - before, entry + 24L)
    let snapshot = account.snapshot()
    ignore(font_cache_test_get(object, cache, kind~).unwrap())
    assert_true(account.snapshot() == snapshot)
    assert_eq(cache.programs.length(), 1)
  }
}

///|
async fn wrapper_cmap_publication_contract(loaded : Bool) -> Unit {
  for kind in ["valid", "empty", "soft"] {
    let bytes = cmap_cache_test_pdf(kind~)
    let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
    defer @input.end_input_session(owner)
    let store = if loaded {
      loaded_font_result_test_store(owner.source, bytes)
    } else {
      pdf_load_object_store(
        owner.source,
        pdf_make_stream_decode_context(owner.source),
      ).unwrap()
    }
    let cache = pdf_make_local_cmap_cache(
      owner.source,
      loaded_snapshot=pdf_loaded_store_snapshot(store.objects),
    ).unwrap()
    let object = store.object_index.get(101).unwrap()
    let account = cache.context.budget.account
    let before = account.snapshot().resident.cache_bytes
    let result = cmap_cache_test_get(object, Some(cache)).unwrap()
    assert_eq(result is Err(_), kind == "soft")
    let key = pdf_local_cmap_key(object).unwrap()
    let stored = cache.entries.get(key).unwrap()
    let entry = pdf_local_cmap_retained_payload(cache.context, key, stored)
    assert_eq(account.snapshot().resident.cache_bytes - before, entry + 24L)
    let snapshot = account.snapshot()
    ignore(cmap_cache_test_get(object, Some(cache)).unwrap())
    assert_true(account.snapshot() == snapshot)
    assert_eq(cache.entries.length(), 1)
  }
}

///|
async test "Ranged Font cache first result charges all three wrapper references once" {
  wrapper_font_publication_contract(false)
}

///|
async test "Loaded Font cache first result charges all three wrapper references once" {
  wrapper_font_publication_contract(true)
}

///|
async test "Ranged CMap cache first result charges all three wrapper references once" {
  wrapper_cmap_publication_contract(false)
}

///|
async test "Loaded CMap cache first result charges all three wrapper references once" {
  wrapper_cmap_publication_contract(true)
}

///|
test "empty Font and CMap factories do not precharge wrapper fields" {
  let owner = @input.begin_input_session(@input.input_from_bytes(b"%PDF-1.4"))
  defer @input.end_input_session(owner)
  let account = @input.input_source_budget_context(owner.source).unwrap().account
  let before = account.snapshot()
  let font = pdf_make_font_program_cache(owner.source).unwrap()
  let cmap = pdf_make_local_cmap_cache(owner.source).unwrap()
  assert_true(font.programs.is_empty())
  assert_true(cmap.entries.is_empty())
  assert_true(account.snapshot() == before)
}

///|
async test "failed first Font and CMap integrity checks never publish or charge wrapper fields" {
  for consumer in ["font", "cmap"] {
    let bytes = loaded_font_result_test_raw_file(
      b"\x78\x9c\x00", "/Filter /FlateDecode",
    )
    let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
    let store = loaded_font_result_test_store(owner.source, bytes)
    let snapshot = pdf_loaded_store_snapshot(store.objects)
    let font = pdf_make_font_program_cache(
      owner.source,
      loaded_snapshot=snapshot,
    ).unwrap()
    let cmap = pdf_make_local_cmap_cache(owner.source, loaded_snapshot=snapshot).unwrap()
    let object = store.object_index.get(71).unwrap()
    let account = font.context.budget.account
    let before = account.snapshot().resident.cache_bytes
    if consumer == "font" {
      assert_true(
        font_cache_test_get(object, font) is Err(StreamIntegrityFailed(_, _)),
      )
    } else {
      assert_true(
        cmap_cache_test_get(object, Some(cmap))
        is Err(StreamIntegrityFailed(_, _)),
      )
    }
    assert_eq(account.snapshot().resident.cache_bytes, before)
    assert_eq(font.programs.length(), 0)
    assert_eq(cmap.entries.length(), 0)
    let cumulative = account.snapshot().cumulative
    if consumer == "font" {
      assert_true(font_cache_test_get(object, font) is Err(ReadFailed(_)))
    } else {
      assert_true(cmap_cache_test_get(object, Some(cmap)) is Err(ReadFailed(_)))
    }
    assert_true(account.snapshot().cumulative == cumulative)
    assert_eq(account.snapshot().resident.cache_bytes, before)
    @input.end_input_session(owner)
    assert_eq(account.snapshot().active_leases, 0L)
  }
}
