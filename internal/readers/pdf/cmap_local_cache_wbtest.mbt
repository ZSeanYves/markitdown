///|
fn cmap_cache_test_text(code : String, text : String) -> String {
  "begincmap 1 beginbfchar <" + code + "> <" + text + "> endbfchar endcmap"
}

///|
fn cmap_cache_test_pdf(kind~ : String = "valid") -> Bytes {
  let content = "BT /F0 12 Tf <41> Tj ET"
  let objects : Array[(Int32, String)] = [
    (1, "<< /Type /Catalog /Pages 2 0 R >>"),
    (2, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>"),
    (
      3, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Resources << /Font << /F0 10 0 R >> >> /Contents 4 0 R >>",
    ),
    (
      4,
      "<< /Length " +
      content.length().to_string() +
      " >>\nstream\n" +
      content +
      "\nendstream",
    ),
  ]
  if kind == "depth" {
    for id in 101..<113 {
      objects.push(
        (
          id,
          bounded_pdf_test_stream(
            @zlib.zlib_compress(
              pdf_ascii_bytes(
                cmap_cache_test_text(
                  pdf_hex_upper(id - 100, 2),
                  pdf_hex_upper(id - 36, 4),
                ),
              ),
            ),
            extra=if id < 112 {
              "/UseCMap " + (id + 1).to_string() + " 0 R"
            } else {
              ""
            },
          ),
        ),
      )
    }
    return pdf_wbtest_xref_stream_pdf_bytes(objects, 1, 114)
  }
  for id in 10..<18 {
    objects.push(
      (
        id, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /ToUnicode 101 0 R >>",
      ),
    )
  }
  let text = match kind {
    "empty" => ""
    "invalid" => "1 beginbfchar <41> <D800> endbfchar"
    "named" => cmap_cache_test_text("41", "0041") + " /Parent usecmap"
    _ => cmap_cache_test_text("41", "0041")
  }
  if kind == "soft" {
    objects.push(
      (
        101, "<< /Length 1 /Filter /UnsupportedCMapFilter >>\nstream\nx\nendstream",
      ),
    )
  } else {
    objects.push(
      (
        101,
        bounded_pdf_test_stream(
          @zlib.zlib_compress(pdf_ascii_bytes(text)),
          extra=if kind == "valid" || kind == "cycle" || kind == "dual" {
            "/UseCMap 102 0 R"
          } else {
            ""
          },
        ),
      ),
    )
  }
  if kind == "valid" || kind == "cycle" || kind == "dual" || kind == "named" {
    objects.push(
      (
        102,
        bounded_pdf_test_stream(
          if kind == "dual" {
            b"\x78\x9c\x00"
          } else {
            @zlib.zlib_compress(
              pdf_ascii_bytes(cmap_cache_test_text("42", "0042")),
            )
          },
          extra=if kind == "cycle" {
            "/UseCMap 101 0 R"
          } else if kind == "named" {
            "/CMapName /Parent"
          } else {
            ""
          },
        ),
      ),
    )
  }
  pdf_wbtest_xref_stream_pdf_bytes(objects, 1, 110)
}

///|
async fn cmap_cache_test_get(
  object : PdfNativeObject,
  cache : PdfLocalCMapCache?,
) -> Result[Result[PdfToUnicodeCMapInfo, String], PdfNativeError] {
  Ok(pdf_local_tounicode_cmap_info(object, cache)) catch {
    PdfHardDecodeFailure(error) => Err(error)
    error => raise error
  }
}

///|
fn cmap_cache_test_equal(
  left : PdfToUnicodeCMapInfo,
  right : PdfToUnicodeCMapInfo,
) -> Unit raise {
  assert_eq(left.mapping, right.mapping)
  assert_eq(left.invalid_keys, right.invalid_keys)
  assert_eq(left.widths, right.widths)
  assert_eq(left.usecmap_name, right.usecmap_name)
  assert_eq(left.builtin_parent_name, right.builtin_parent_name)
}

///|
async test "local CMap cache reuses two shared streams while preserving eight font results" {
  let account = @budget.Budget::new(bounded_pdf_test_limits(None))
  let owner = @input.begin_input_session(
    @input.input_from_bytes(cmap_cache_test_pdf()),
    budget=account,
  )
  defer @input.end_input_session(owner)
  let store = pdf_load_object_store(
    owner.source,
    pdf_make_stream_decode_context(owner.source),
  ).unwrap()
  let before = account.snapshot().cumulative.inflate_bytes
  let uncached = pdf_collect_font_infos(store.object_index).unwrap()
  let old_inflate = account.snapshot().cumulative.inflate_bytes - before
  let cache = pdf_make_local_cmap_cache(owner.source).unwrap()
  let before = account.snapshot().cumulative.inflate_bytes
  let cached = pdf_collect_font_infos(
    store.object_index,
    local_cache=Some(cache),
  ).unwrap()
  let new_inflate = account.snapshot().cumulative.inflate_bytes - before
  println(
    "CMAP_SHARED_INFLATE\tuncached=" +
    old_inflate.to_string() +
    "\tcached=" +
    new_inflate.to_string(),
  )
  assert_eq(old_inflate, new_inflate * 8L)
  assert_eq(cache.entries.length(), 2)
  for id, info in cached.infos {
    let old = uncached.infos.get(id).unwrap()
    assert_eq(info.unicode_map, old.unicode_map)
    assert_eq(info.tounicode_invalid_keys, old.tounicode_invalid_keys)
    assert_eq(info.code_hex_widths, old.code_hex_widths)
    assert_eq(info.has_tounicode, old.has_tounicode)
    assert_eq(info.tounicode_decode_failed, old.tounicode_decode_failed)
    assert_eq(info.tounicode_builtin_name, old.tounicode_builtin_name)
  }
  assert_eq(cached.infos.get(10).unwrap().unicode_map.get("41"), Some("A"))
  assert_eq(cached.infos.get(10).unwrap().unicode_map.get("42"), Some("B"))
  let document = pdf_extract_document_from_store(owner.source, store).unwrap()
  let text : Array[String] = []
  for page in document.pages {
    for block in page.text_blocks {
      for line in block.lines {
        text.push(pdf_native_line_text(line))
      }
    }
  }
  assert_eq(text.join(""), "A")
}

///|
async test "local CMap success empty and soft failure each remove seven actual Reader callbacks" {
  for kind in ["valid", "empty", "soft"] {
    let bytes = cmap_cache_test_pdf(kind~)
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
    let owner = @input.begin_input_session(@input.input_from_reader(reader))
    defer @input.end_input_session(owner)
    let store = pdf_load_object_store(
      owner.source,
      pdf_make_stream_decode_context(owner.source),
    ).unwrap()
    let object = store.object_index.get(101).unwrap()
    let before = calls.val
    for _ in 0..<8 {
      ignore(pdf_local_tounicode_cmap_info(object, None))
    }
    let uncached = calls.val - before
    let cache = pdf_make_local_cmap_cache(owner.source).unwrap()
    let before = calls.val
    for _ in 0..<8 {
      ignore(pdf_local_tounicode_cmap_info(object, Some(cache)))
    }
    let cached = calls.val - before
    println(
      "CMAP_LOCAL_READS\tkind=" +
      kind +
      "\tuncached=" +
      uncached.to_string() +
      "\tcached=" +
      cached.to_string(),
    )
    assert_eq(uncached, 8)
    assert_eq(cached, 1)
    assert_eq(cache.entries.length(), 1)
  }
}

///|
async test "successful empty invalid and ordinary negative CMap results all have distinct reusable values" {
  for kind in ["valid", "empty", "invalid", "soft"] {
    let owner = @input.begin_input_session(
      @input.input_from_bytes(cmap_cache_test_pdf(kind~)),
    )
    defer @input.end_input_session(owner)
    let store = pdf_load_object_store(
      owner.source,
      pdf_make_stream_decode_context(owner.source),
    ).unwrap()
    let cache = pdf_make_local_cmap_cache(owner.source).unwrap()
    let object = store.object_index.get(101).unwrap()
    let first = pdf_local_tounicode_cmap_info(object, Some(cache))
    let snapshot = cache.context.budget.account.snapshot()
    let second = pdf_local_tounicode_cmap_info(object, Some(cache))
    assert_true(cache.context.budget.account.snapshot() == snapshot)
    assert_eq(cache.entries.length(), 1)
    match (first, second) {
      (Ok(first), Ok(second)) => {
        cmap_cache_test_equal(first, second)
        assert_true(physical_equal(first.mapping, second.mapping))
        assert_true(physical_equal(first.widths, second.widths))
        if kind == "empty" {
          assert_eq(first.widths, [])
          assert_eq(first.mapping.length(), 0)
        }
        if kind == "invalid" {
          assert_eq(first.invalid_keys.get("41"), Some(true))
          assert_eq(first.widths, [1])
        }
      }
      (Err(first), Err(second)) => {
        assert_eq(kind, "soft")
        assert_eq(first, second)
      }
      _ => fail("cached local outcome changed variant")
    }
    assert_true(@input.input_source_failure(owner.source) is None)
    let registry = pdf_collect_font_infos(
      store.object_index,
      local_cache=Some(cache),
    ).unwrap()
    let font = registry.infos.get(10).unwrap()
    assert_eq(font.tounicode_decode_failed, kind == "soft")
    assert_eq(font.has_tounicode, kind != "soft")
  }
}

///|
async test "local CMap cache never memoizes the eight-edge depth cutoff or caller visited set" {
  let owner = @input.begin_input_session(
    @input.input_from_bytes(cmap_cache_test_pdf(kind="depth")),
  )
  defer @input.end_input_session(owner)
  let store = pdf_load_object_store(
    owner.source,
    pdf_make_stream_decode_context(owner.source),
  ).unwrap()
  let cache = pdf_make_local_cmap_cache(owner.source).unwrap()
  for id in [101, 105, 101] {
    for depth in [1, 7, 8, 9] {
      for excluded in [0, 106] {
        let old_visited = Map([])
        let new_visited = Map([])
        if excluded != 0 {
          old_visited.set(excluded, true)
          new_visited.set(excluded, true)
        }
        let old = pdf_collect_tounicode_cmap_info(
          id,
          store.object_index,
          old_visited,
          depth,
        ).unwrap()
        let new = pdf_collect_tounicode_cmap_info(
          id,
          store.object_index,
          new_visited,
          depth,
          local_cache=Some(cache),
        ).unwrap()
        cmap_cache_test_equal(old, new)
        assert_eq(old_visited, new_visited)
      }
    }
  }
}

///|
async test "local CMap reuse keeps cycle depth and merged maps independent from cached aliases" {
  let owner = @input.begin_input_session(
    @input.input_from_bytes(cmap_cache_test_pdf(kind="cycle")),
  )
  defer @input.end_input_session(owner)
  let store = pdf_load_object_store(
    owner.source,
    pdf_make_stream_decode_context(owner.source),
  ).unwrap()
  let cache = pdf_make_local_cmap_cache(owner.source).unwrap()
  for id in [101, 102, 101] {
    for depth in [0, 1, 2, 8] {
      let old = pdf_collect_tounicode_cmap_info(
        id,
        store.object_index,
        Map([]),
        depth,
      ).unwrap()
      let new = pdf_collect_tounicode_cmap_info(
        id,
        store.object_index,
        Map([]),
        depth,
        local_cache=Some(cache),
      ).unwrap()
      cmap_cache_test_equal(old, new)
      // Only the freshly merged result is mutable, not the cache's local map.
      new.mapping.set("AA", "mutation outside the local cache")
      let next = pdf_collect_tounicode_cmap_info(
        id,
        store.object_index,
        Map([]),
        depth,
        local_cache=Some(cache),
      ).unwrap()
      assert_eq(next.mapping.get("AA"), None)
    }
  }
  assert_eq(cache.entries.length(), 2)
}

///|
async test "local CMap cache preserves both program and dictionary name-based parent lookup" {
  let owner = @input.begin_input_session(
    @input.input_from_bytes(cmap_cache_test_pdf(kind="named")),
  )
  defer @input.end_input_session(owner)
  let store = pdf_load_object_store(
    owner.source,
    pdf_make_stream_decode_context(owner.source),
  ).unwrap()
  let cache = pdf_make_local_cmap_cache(owner.source).unwrap()
  let child = store.object_index.get(101).unwrap()
  // Program /Parent usecmap and explicit dict /UseCMap /Parent take the same
  // existing global-name lookup path, while retaining their distinct plans.
  for
    object in [
      child,
      {
        ..child,
        dict_text: child.dict_text.replace(old="<<", new="<< /UseCMap /Parent "),
      },
    ] {
    let index = Map([(101, object), (102, store.object_index.get(102).unwrap())])
    let old = pdf_collect_tounicode_cmap_info(101, index, Map([]), 8).unwrap()
    let new = pdf_collect_tounicode_cmap_info(
      101,
      index,
      Map([]),
      8,
      local_cache=Some(cache),
    ).unwrap()
    cmap_cache_test_equal(old, new)
    assert_eq(new.mapping.get("41"), Some("A"))
    assert_eq(new.mapping.get("42"), Some("B"))
  }
  assert_eq(cache.entries.length(), 3)
}

///|
async test "local CMap keys distinguish exact definitions generations dictionaries and framing plans" {
  let owner = @input.begin_input_session(
    @input.input_from_bytes(cmap_cache_test_pdf(kind="empty")),
  )
  defer @input.end_input_session(owner)
  let store = pdf_load_object_store(
    owner.source,
    pdf_make_stream_decode_context(owner.source),
  ).unwrap()
  let object = store.object_index.get(101).unwrap()
  let range = ranged_test_range(object)
  let original = pdf_local_cmap_key(object).unwrap()
  for
    alternate in [
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
    assert_true(
      original !=
      pdf_local_cmap_key({ ..object, stream: Some(Ranged(alternate)), }).unwrap(),
    )
  }
  let changed = {
    ..object,
    dict_text: object.dict_text + " /DecodeParms << /Predictor 12 >>",
  }
  assert_true(original != pdf_local_cmap_key(changed).unwrap())
  assert_true(
    original != pdf_local_cmap_key({ ..object, object_id: 999, }).unwrap(),
  )
  let cache = pdf_make_local_cmap_cache(owner.source).unwrap()
  assert_true(pdf_local_tounicode_cmap_info(object, Some(cache)) is Ok(_))
  let soft = { ..object, dict_text: "<< /Filter /UnsupportedCMapFilter >>", }
  assert_true(pdf_local_tounicode_cmap_info(soft, Some(cache)) is Err(_))
  assert_eq(cache.entries.length(), 2)
  // A new document owns an empty cache even when it uses the same account.
  let other = @input.begin_input_session(
    @input.input_source_inherit_session(
      @input.input_from_bytes(cmap_cache_test_pdf(kind="empty")),
      owner.source,
    ),
  )
  let other_cache = pdf_make_local_cmap_cache(other.source).unwrap()
  assert_eq(other_cache.entries.length(), 0)
  @input.end_input_session(other)
}

///|
async test "loaded CMap streams remain outside the range-only cache" {
  let payload = @zlib.zlib_compress(
    pdf_ascii_bytes(cmap_cache_test_text("41", "0041")),
  )
  let (bytes, offset) = ranged_test_bytes(
    payload,
    "/Length " + payload.length().to_string(),
    b"\n",
  )
  let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
  defer @input.end_input_session(owner)
  let cache = pdf_make_local_cmap_cache(owner.source).unwrap()
  let loaded = pdf_parse_indirect_object_at(
    bytes,
    offset,
    decode_context=Some(cache.context),
  ).unwrap()
  let first = pdf_local_tounicode_cmap_info(loaded, Some(cache)).unwrap()
  let before = cache.context.budget.account.snapshot().cumulative.inflate_bytes
  let second = pdf_local_tounicode_cmap_info(loaded, Some(cache)).unwrap()
  cmap_cache_test_equal(first, second)
  assert_true(
    cache.context.budget.account.snapshot().cumulative.inflate_bytes > before,
  )
  assert_eq(cache.entries.length(), 0)
}

///|
async test "both positive and ordinary negative local hits reject source first errors and closed owners" {
  for kind in ["empty", "soft"] {
    for failure in 0..<4 {
      let owner = @input.begin_input_session(
        @input.input_from_bytes(cmap_cache_test_pdf(kind~)),
      )
      let store = pdf_load_object_store(
        owner.source,
        pdf_make_stream_decode_context(owner.source),
      ).unwrap()
      let cache = pdf_make_local_cmap_cache(owner.source).unwrap()
      let object = store.object_index.get(101).unwrap()
      ignore(cmap_cache_test_get(object, Some(cache)).unwrap())
      let before = cache.context.budget.account.snapshot().cumulative
      match failure {
        0 =>
          @input.record_input_failure(
            owner.source,
            "first cached CMap IO error",
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
      @input.end_input_session(owner)
      assert_eq(cache.context.budget.account.snapshot().active_leases, 0L)
    }
  }
}

///|
async test "cancelled local CMap read publishes no negative entry and releases private scratch" {
  let payload = @zlib.zlib_compress(b"cmap")
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
  let owner = @input.begin_input_session(@input.input_from_reader(reader))
  let cache = pdf_make_local_cmap_cache(owner.source).unwrap()
  let object = ranged_test_object(
    owner.source,
    @input.open_source_cursor(owner.source).unwrap(),
    bytes,
    offset,
  )
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @async.handle_cancellation(() => cmap_cache_test_get(object, Some(cache)))
    })
    while !entered.val {
      @async.pause()
    }
    task.cancel()
    assert_true(task.wait() is None)
  })
  assert_eq(cache.entries.length(), 0)
  assert_true(@input.input_source_failure(owner.source) is None)
  assert_eq(cache.context.budget.account.snapshot().resident.working_bytes, 0L)
  @input.end_input_session(owner)
  assert_eq(cache.context.budget.account.snapshot().active_leases, 0L)
}

///|
// Metadata is prepaid so CacheBytes=0 isolates this stage's publication
// admission rather than failing the earlier ranged metadata survey.
async fn cmap_cache_test_prepaid_object(
  source : @input.InputSource,
  bytes : Bytes,
  offset : Int32,
) -> PdfNativeObject {
  pdf_parse_indirect_object_at(
    bytes,
    offset,
    decode_context=pdf_make_stream_decode_context(source),
    range_source=Some({
      cursor: @input.open_source_cursor(source).unwrap(),
      window_start: 0L,
      definition_offset: offset.to_int64(),
      generation: 0,
      metadata_prepaid: true,
    }),
  ).unwrap()
}

///|
async test "local CMap hard integrity IO and Inflate failures never enter the negative cache or retry" {
  for failure in 0..<3 {
    let payload = if failure == 0 {
      b"\x78\x9c\x00"
    } else {
      @zlib.zlib_compress(pdf_ascii_bytes(cmap_cache_test_text("41", "0041")))
    }
    let (bytes, offset) = ranged_test_bytes(
      payload,
      "/Length " + payload.length().to_string(),
      b"\n",
    )
    let calls = Ref(0)
    let reader = @input.make_input_reader(
      fn(start, length) {
        calls.val += 1
        if failure == 1 {
          Err("controlled late CMap read failure")
        } else {
          Ok(
            bytes[start.to_int():(start.to_int() + length).min(bytes.length())].to_owned(),
          )
        }
      },
      size=bytes.length().to_int64(),
    )
    let account = @budget.Budget::new(
      bounded_pdf_test_limits(if failure == 2 { Some(0L) } else { None }),
    )
    let owner = @input.begin_input_session(
      @input.input_from_reader(reader),
      budget=account,
    )
    let cache = pdf_make_local_cmap_cache(owner.source).unwrap()
    let object = cmap_cache_test_prepaid_object(owner.source, bytes, offset)
    let result = cmap_cache_test_get(object, Some(cache))
    match failure {
      0 => assert_true(result is Err(StreamIntegrityFailed(_, _)))
      1 => assert_true(result is Err(ReadFailed(_)))
      _ => {
        assert_true(result is Err(BudgetExceeded(_)))
        assert_true(
          @input.input_source_failure(owner.source) is Some(BudgetFailure(_)),
        )
      }
    }
    assert_eq(cache.entries.length(), 0)
    let reads = calls.val
    let cumulative = account.snapshot().cumulative
    assert_true(cmap_cache_test_get(object, Some(cache)) is Err(_))
    assert_eq(calls.val, reads)
    assert_true(account.snapshot().cumulative == cumulative)
    @input.end_input_session(owner)
    assert_eq(account.snapshot().active_leases, 0L)
  }
}

///|
fn cmap_cache_test_zero_cache_limits() -> @budget.BudgetLimits {
  @budget.BudgetLimits::new(
    MeasurementOnly,
    inflate_bytes=None,
    parse_work=None,
    output_utf8_bytes=None,
    source_metadata_bytes=None,
    rag_metadata_bytes=None,
    read_traffic_bytes=None,
    cache_bytes=Some(0L),
    working_bytes=None,
    temporary_bytes=None,
    ir_bytes=None,
  ).unwrap()
}

///|
async test "local CMap publication admission precedes a later parent CRC and preserves typed first failure" {
  let local_payload = @zlib.zlib_compress(
    pdf_ascii_bytes(cmap_cache_test_text("41", "0041")),
  )
  let buffer = Buffer()
  buffer.write_bytes(b"%PDF-1.4\n")
  let first_offset = buffer.length()
  buffer.write_bytes(
    pdf_ascii_bytes(
      "1 0 obj\n<< /UseCMap 2 0 R /Filter /FlateDecode /Length " +
      local_payload.length().to_string() +
      " >>\nstream\n",
    ),
  )
  buffer.write_bytes(local_payload)
  buffer.write_bytes(b"\nendstream\nendobj\n")
  let second_offset = buffer.length()
  buffer.write_bytes(
    b"2 0 obj\n<< /Filter /FlateDecode /Length 3 >>\nstream\n\x78\x9c\x00\nendstream\nendobj\n",
  )
  let bytes = buffer.to_bytes()
  for enabled in [false, true] {
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
    let account = @budget.Budget::new(cmap_cache_test_zero_cache_limits())
    let owner = @input.begin_input_session(
      @input.input_from_reader(reader),
      budget=account,
    )
    let cache = pdf_make_local_cmap_cache(owner.source).unwrap()
    let index = Map([
      (1, cmap_cache_test_prepaid_object(owner.source, bytes, first_offset)),
      (2, cmap_cache_test_prepaid_object(owner.source, bytes, second_offset)),
    ])
    let result = Ok(
      pdf_collect_tounicode_cmap_info(
        1,
        index,
        Map([]),
        8,
        local_cache=if enabled { Some(cache) } else { None },
      ),
    ) catch {
      PdfHardDecodeFailure(error) => Err(error)
      error => raise error
    }
    if enabled {
      assert_true(
        result is Err(BudgetExceeded(LimitExceeded(Resident(CacheBytes), ..))),
      )
      assert_eq(calls.val, 1)
      assert_eq(cache.entries.length(), 0)
      assert_true(
        @input.input_source_failure(owner.source) is Some(BudgetFailure(_)),
      )
      let reads = calls.val
      assert_true(
        cmap_cache_test_get(index.get(1).unwrap(), Some(cache))
        is Err(BudgetExceeded(_)),
      )
      assert_eq(calls.val, reads)
    } else {
      assert_true(result is Err(StreamIntegrityFailed(_, _)))
      assert_eq(calls.val, 2)
    }
    @input.end_input_session(owner)
    assert_eq(account.snapshot().active_leases, 0L)
  }
}

///|
async test "local CMap payload arithmetic overflow keeps typed budget semantics" {
  let owner = @input.begin_input_session(@input.input_from_bytes(b""))
  defer @input.end_input_session(owner)
  let cache = pdf_make_local_cmap_cache(owner.source).unwrap()
  let result = Ok(pdf_cmap_payload_add(cache.context, 9223372036854775807L, 1L)) catch {
    PdfHardDecodeFailure(error) => Err(error)
  }
  assert_true(
    result is Err(BudgetExceeded(ArithmeticOverflow(Resident(CacheBytes), ..))),
  )
  assert_true(
    @input.input_source_failure(owner.source) is Some(BudgetFailure(_)),
  )
}

///|
async test "Native64 local CMap model counts packed optional slots result Info and selected Entry fields" {
  let owner = @input.begin_input_session(@input.input_from_bytes(b""))
  defer @input.end_input_session(owner)
  let context = pdf_make_stream_decode_context(owner.source).unwrap()
  let absent : PdfLocalCMapKey = {
    object_id: 1,
    selected_object_id: 1,
    definition_offset: 0L,
    generation: 0,
    dict_text: "",
    payload_start: 0L,
    primary_length: 0,
    endstream_length: 0,
    endstream_eol_suffix: 0,
    endstream_eol_length: 0,
    declared_length: None,
    loaded: None,
  }
  let present = { ..absent, declared_length: Some(0), }
  // Proposed Native64: key fields68, Entry key/result refs16 and Result
  // value ref8. Option[Int] is an int64 slot even when it represents None.
  for key in [absent, present] {
    assert_eq(pdf_local_cmap_retained_payload(context, key, Err("")), 92L)
    assert_eq(pdf_local_cmap_retained_payload(context, key, Err("bad")), 98L)
    let empty = pdf_empty_tounicode_cmap_info()
    assert_eq(empty.mapping.capacity(), 8)
    assert_eq(empty.invalid_keys.capacity(), 8)
    assert_eq(empty.widths.capacity(), 0)
    // Info5refs40 + two empty8-slot map buffers128. Headers/padding excluded.
    assert_eq(pdf_local_cmap_retained_payload(context, key, Ok(empty)), 260L)
    let info : PdfToUnicodeCMapInfo = {
      mapping: Map([("41", "A")], capacity=8),
      invalid_keys: Map([("42", true)], capacity=8),
      widths: [1],
      usecmap_name: Some("P"),
      builtin_parent_name: None,
    }
    assert_eq(pdf_local_cmap_retained_payload(context, key, Ok(info)), 304L)
  }
}
