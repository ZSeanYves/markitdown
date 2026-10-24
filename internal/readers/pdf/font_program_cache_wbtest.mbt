///|
fn font_cache_test_sfnt() -> Bytes {
  pdf_wbtest_bytes_from_hex(
    "000100000005004000020010636d6170000c00750000005c0000002c686561645f1040dd00000088000000366868656100010003000000c000000024686d747807080000000000e40000000c6d61787000040000000000f00000000600000001000300010000000c00040020000000040004000100000042ffff00000041ffffffc00001000000000001000000000000000000005f0f3cf5000003e800000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000301f400000258000002bc00000001000000030000",
  )
}

///|
async fn font_cache_test_get(
  object : PdfNativeObject,
  cache : PdfFontProgramCache,
  kind~ : Int32? = Some(0),
) -> Result[PdfEmbeddedFontProgram?, PdfNativeError] {
  Ok(
    pdf_font_program_for_object(
      object,
      "FontFile cache fixture",
      kind,
      Some(cache),
    ),
  ) catch {
    PdfHardDecodeFailure(error) => Err(error)
    error => raise error
  }
}

///|
fn font_cache_test_shared_pdf() -> Bytes {
  let objects : Array[(Int32, String)] = [
    (1, "<< /Type /Catalog /Pages 2 0 R >>"),
    (2, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>"),
    (
      90, "<< /Type /Font /Subtype /CIDFontType2 /BaseFont /Shared /FontDescriptor 91 0 R /CIDToGIDMap /Identity /W [65 [500]] /DW 1000 >>",
    ),
    (91, "<< /Type /FontDescriptor /FontFile2 103 0 R >>"),
    (103, bounded_pdf_test_stream(@zlib.zlib_compress(font_cache_test_sfnt()))),
  ]
  let aliases : Array[String] = []
  let content : Array[String] = []
  for index in 0..<8 {
    let id = 10 + index
    aliases.push("/F" + index.to_string() + " " + id.to_string() + " 0 R")
    content.push(
      "BT /F" +
      index.to_string() +
      " 12 Tf 1 0 0 1 10 " +
      (20 + index * 15).to_string() +
      " Tm <0041> Tj ET",
    )
    objects.push(
      (
        id, "<< /Type /Font /Subtype /Type0 /BaseFont /Shared /DescendantFonts [90 0 R] /Encoding /Identity-H >>",
      ),
    )
  }
  let content = content.join("\n")
  objects.append([
    (
      3,
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Resources << /Font << " +
      aliases.join(" ") +
      " >> >> /Contents 4 0 R >>",
    ),
    (
      4,
      "<< /Length " +
      content.length().to_string() +
      " >>\nstream\n" +
      content +
      "\nendstream",
    ),
  ])
  pdf_wbtest_xref_stream_pdf_bytes(objects, 1, 110)
}

///|
async test "one store shares the parsed FontFile across nine font consumers without changing fields" {
  let account = @budget.Budget::new(bounded_pdf_test_limits(None))
  let owner = @input.begin_input_session(
    @input.input_from_bytes(font_cache_test_shared_pdf()),
    budget=account,
  )
  defer @input.end_input_session(owner)
  let store = pdf_load_object_store(
    owner.source,
    pdf_make_stream_decode_context(owner.source),
  ).unwrap()
  let cache = pdf_make_font_program_cache(owner.source).unwrap()
  let before = account.snapshot().cumulative.inflate_bytes
  let cached = pdf_collect_font_infos(
    store.object_index,
    program_cache=Some(cache),
  ).unwrap()
  let once = account.snapshot().cumulative.inflate_bytes - before
  assert_eq(once, font_cache_test_sfnt().length().to_int64())
  assert_eq(cache.programs.length(), 1)
  let shared = cached.infos.get(90).unwrap().embedded_font_program.unwrap()
  assert_eq(pdf_embedded_font_program_unicode(shared, 1), Some("A"))
  assert_eq(pdf_embedded_font_program_unicode(shared, 2), Some("B"))
  assert_eq(shared.gid_advance_pairs, [0, 500, 1, 600, 2, 700])
  for index in 10..<18 {
    let info = cached.infos.get(index).unwrap()
    let program = info.embedded_font_program.unwrap()
    assert_true(
      physical_equal(shared.gid_unicode_gids, program.gid_unicode_gids),
    )
    assert_true(
      physical_equal(shared.gid_advance_pairs, program.gid_advance_pairs),
    )
  }
  let before_uncached = account.snapshot().cumulative.inflate_bytes
  let uncached = pdf_collect_font_infos(store.object_index).unwrap()
  assert_eq(
    account.snapshot().cumulative.inflate_bytes - before_uncached,
    once * 9L,
  )
  assert_eq(cached.infos.length(), uncached.infos.length())
  for id, info in cached.infos {
    let old = uncached.infos.get(id).unwrap()
    assert_eq(info.tounicode_decode_failed, old.tounicode_decode_failed)
    assert_eq(info.unicode_map, old.unicode_map)
    assert_eq(info.cid_width_pairs, old.cid_width_pairs)
    assert_eq(info.cid_default_width, old.cid_default_width)
    if info.embedded_font_program is Some(program) &&
      old.embedded_font_program is Some(old_program) {
      assert_eq(program.gid_unicode_gids, old_program.gid_unicode_gids)
      assert_eq(program.gid_unicode_values, old_program.gid_unicode_values)
      assert_eq(program.gid_advance_pairs, old_program.gid_advance_pairs)
    }
  }
  let document = pdf_extract_document_from_store(owner.source, store).unwrap()
  let text : Array[String] = []
  for block in document.pages[0].text_blocks {
    for line in block.lines {
      text.push(pdf_native_line_text(line))
    }
  }
  assert_eq(text.join(""), "AAAAAAAA")
}

///|
async test "ranged program keys distinguish definitions generations kinds and document owners" {
  let payload = @zlib.zlib_compress(font_cache_test_sfnt())
  let (bytes, offset) = ranged_test_bytes(
    payload,
    "/Length " + payload.length().to_string(),
    b"\n",
  )
  for _ in 0..<2 {
    let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
    let cache = pdf_make_font_program_cache(owner.source).unwrap()
    assert_eq(cache.programs.length(), 0)
    let object = ranged_test_object(
      owner.source,
      @input.open_source_cursor(owner.source).unwrap(),
      bytes,
      offset,
    )
    let range = ranged_test_range(object)
    assert_true(font_cache_test_get(object, cache).unwrap() is Some(_))
    for
      alternate in [
        { ..range, definition_offset: range.definition_offset + 1L, },
        { ..range, generation: range.generation + 1, },
        { ..range, object_id: range.object_id + 1, },
      ] {
      assert_true(
        font_cache_test_get(
          { ..object, stream: Some(Ranged(alternate)), },
          cache,
        ).unwrap()
        is Some(_),
      )
    }
    assert_true(
      font_cache_test_get(object, cache, kind=Some(1)).unwrap() is Some(_),
    )
    assert_true(
      font_cache_test_get(object, cache, kind=Some(2)).unwrap() is Some(_),
    )
    assert_eq(cache.programs.length(), 6)
    @input.end_input_session(owner)
  }
}

///|
async test "program cache hit checks source first failure and closed owner before reuse" {
  let payload = @zlib.zlib_compress(font_cache_test_sfnt())
  let (bytes, offset) = ranged_test_bytes(
    payload,
    "/Length " + payload.length().to_string(),
    b"\n",
  )
  for failure in 0..<4 {
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
    let cache = pdf_make_font_program_cache(owner.source).unwrap()
    let object = ranged_test_object(
      owner.source,
      @input.open_source_cursor(owner.source).unwrap(),
      bytes,
      offset,
    )
    let program = font_cache_test_get(object, cache).unwrap().unwrap()
    let snapshot = account.snapshot()
    let reads = calls.val
    assert_true(font_cache_test_get(object, cache).unwrap() is Some(_))
    assert_true(account.snapshot() == snapshot)
    assert_eq(calls.val, reads)
    match failure {
      0 =>
        @input.record_input_failure(owner.source, "forced cached FontFile IO")
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
    let result = font_cache_test_get(object, cache)
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
    assert_eq(
      account.snapshot().cumulative.inflate_bytes,
      snapshot.cumulative.inflate_bytes,
    )
    assert_eq(pdf_embedded_font_program_unicode(program, 1), Some("A"))
    @input.end_input_session(owner)
    assert_eq(account.snapshot().active_leases, 0L)
  }
}

///|
async test "unknown and unsupported fonts preserve decode first and do not create negative cache entries" {
  for corrupt in [false, true] {
    let payload = if corrupt {
      b"\x78\x9c\x00"
    } else {
      @zlib.zlib_compress(b"font")
    }
    let (bytes, offset) = ranged_test_bytes(
      payload,
      "/Length " + payload.length().to_string(),
      b"\n",
    )
    let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
    let cache = pdf_make_font_program_cache(owner.source).unwrap()
    let object = ranged_test_object(
      owner.source,
      @input.open_source_cursor(owner.source).unwrap(),
      bytes,
      offset,
    )
    let result = font_cache_test_get(object, cache, kind=None)
    if corrupt {
      assert_true(result is Err(StreamIntegrityFailed(_, _)))
    } else {
      assert_true(result is Ok(None))
    }
    assert_eq(cache.programs.length(), 0)
    @input.end_input_session(owner)
  }
}

///|
async test "loaded font streams remain uncached while FontFile3 parser modes preserve results" {
  let payload = @zlib.zlib_compress(font_cache_test_sfnt())
  let (bytes, offset) = ranged_test_bytes(
    payload,
    "/Length " + payload.length().to_string(),
    b"\n",
  )
  let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
  defer @input.end_input_session(owner)
  let cache = pdf_make_font_program_cache(owner.source).unwrap()
  let loaded = pdf_parse_indirect_object_at(
    bytes,
    offset,
    decode_context=pdf_make_stream_decode_context(owner.source),
  ).unwrap()
  for kind in [Some(0), Some(1), Some(2), None] {
    let first = font_cache_test_get(loaded, cache, kind~).unwrap()
    let second = font_cache_test_get(loaded, cache, kind~).unwrap()
    assert_eq(first is Some(_), second is Some(_))
    assert_eq(cache.programs.length(), 0)
  }
}

///|
async test "cache publication budget failure is typed sticky and never publishes the program" {
  let payload = @zlib.zlib_compress(font_cache_test_sfnt())
  let (bytes, offset) = ranged_test_bytes(
    payload,
    "/Length " + payload.length().to_string(),
    b"\n",
  )
  let limits = @budget.BudgetLimits::new(
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
  let account = @budget.Budget::new(limits)
  let owner = @input.begin_input_session(
    @input.input_from_bytes(bytes),
    budget=account,
  )
  defer @input.end_input_session(owner)
  let cache = pdf_make_font_program_cache(owner.source).unwrap()
  // Construct range metadata before attaching the measured context so this
  // fixture isolates post-parse publication admission from metadata admission.
  let unmeasured = pdf_parse_indirect_object_at(bytes, offset).unwrap()
  let cursor = @input.open_source_cursor(owner.source).unwrap()
  let slice = pdf_wbtest_loaded_stream(unmeasured.stream.unwrap())
  let object = {
    ..unmeasured,
    stream: Some(
      Ranged({
        cursor,
        definition_offset: offset.to_int64(),
        generation: 0,
        object_id: 1,
        payload_start: (bytes.length() -
        b"endstream\nendobj\nSUFFIX".length() -
        1 -
        payload.length()).to_int64(),
        primary_length: payload.length(),
        endstream_length: payload.length(),
        endstream_eol_suffix: slice.endstream_eol_suffix,
        endstream_eol_length: slice.endstream_eol_length,
        declared_length: Some(payload.length()),
        decode_context: Some(cache.context),
      }),
    ),
  }
  assert_true(
    font_cache_test_get(object, cache)
    is Err(BudgetExceeded(LimitExceeded(Resident(CacheBytes), ..))),
  )
  assert_eq(cache.programs.length(), 0)
  assert_true(
    @input.input_source_failure(owner.source)
    is Some(BudgetFailure(LimitExceeded(Resident(CacheBytes), ..))),
  )
  let charged = account.snapshot().cumulative.inflate_bytes
  assert_eq(charged, font_cache_test_sfnt().length().to_int64())
  assert_true(font_cache_test_get(object, cache) is Err(BudgetExceeded(_)))
  assert_eq(account.snapshot().cumulative.inflate_bytes, charged)
}

///|
async test "cancelled FontFile miss publishes nothing and releases private scratch" {
  let payload = @zlib.zlib_compress(font_cache_test_sfnt())
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
  let cache = pdf_make_font_program_cache(owner.source).unwrap()
  let object = ranged_test_object(
    owner.source,
    @input.open_source_cursor(owner.source).unwrap(),
    bytes,
    offset,
  )
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @async.handle_cancellation(() => font_cache_test_get(object, cache))
    })
    while !entered.val {
      @async.pause()
    }
    task.cancel()
    assert_true(task.wait() is None)
  })
  assert_eq(cache.programs.length(), 0)
  assert_true(@input.input_source_failure(owner.source) is None)
  assert_eq(account.snapshot().resident.working_bytes, 0L)
  @input.end_input_session(owner)
  assert_eq(account.snapshot().active_leases, 0L)
}

///|
async test "FontFile3 dispatch shares OpenType with FontFile2 but keeps CFF modes distinct" {
  let payload = @zlib.zlib_compress(font_cache_test_sfnt())
  let (bytes, offset) = ranged_test_bytes(
    payload,
    "/Length " + payload.length().to_string(),
    b"\n",
  )
  let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
  defer @input.end_input_session(owner)
  let cache = pdf_make_font_program_cache(owner.source).unwrap()
  let object = ranged_test_object(
    owner.source,
    @input.open_source_cursor(owner.source).unwrap(),
    bytes,
    offset,
  )
  let descriptor : PdfNativeObject = {
    object_id: 2,
    dict_text: "<< /FontFile2 1 0 R >>",
    stream: None,
  }
  let index = Map([(1, object), (2, descriptor)])
  let font = "<< /FontDescriptor 2 0 R >>"
  let sfnt = pdf_extract_embedded_font_program(font, index, cache=Some(cache)).unwrap()
  index.set(2, { ..descriptor, dict_text: "<< /FontFile3 1 0 R >>", })
  for subtype in ["OpenType", "Type1C", "CIDFontType0C", "Unknown"] {
    let replacement = "/Subtype /" + subtype + " >>"
    index.set(1, {
      ..object,
      dict_text: object.dict_text.replace(old=">>", new=replacement[:]),
    })
    let program = pdf_extract_embedded_font_program(
      font,
      index,
      cache=Some(cache),
    )
    if subtype == "Unknown" {
      assert_true(program is None)
    } else {
      let program = program.unwrap()
      if subtype == "OpenType" {
        assert_true(
          physical_equal(sfnt.gid_unicode_gids, program.gid_unicode_gids),
        )
      } else {
        assert_eq(program.gid_unicode_gids.length(), 0)
      }
    }
  }
  assert_eq(cache.programs.length(), 3)
}

///|
async test "FontFile miss hard integrity IO and budget failures cannot become cached absence" {
  for failure in 0..<3 {
    let payload = if failure == 0 {
      b"\x78\x9c\x00"
    } else {
      @zlib.zlib_compress(font_cache_test_sfnt())
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
          Err("forced FontFile miss IO")
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
    let cache = pdf_make_font_program_cache(owner.source).unwrap()
    let object = ranged_test_object(
      owner.source,
      @input.open_source_cursor(owner.source).unwrap(),
      bytes,
      offset,
    )
    let result = font_cache_test_get(object, cache)
    match failure {
      0 => assert_true(result is Err(StreamIntegrityFailed(_, _)))
      1 => assert_true(result is Err(ReadFailed(_)))
      _ => assert_true(result is Err(BudgetExceeded(_)))
    }
    assert_eq(cache.programs.length(), 0)
    let read_calls = calls.val
    let inflated = account.snapshot().cumulative.inflate_bytes
    assert_true(font_cache_test_get(object, cache) is Err(_))
    assert_eq(calls.val, read_calls)
    assert_eq(account.snapshot().cumulative.inflate_bytes, inflated)
    @input.end_input_session(owner)
    assert_eq(account.snapshot().active_leases, 0L)
  }
}

///|
async test "unsupported filter remains a recoverable miss without negative caching" {
  let payload = @zlib.zlib_compress(font_cache_test_sfnt())
  let (bytes, offset) = ranged_test_bytes(
    payload,
    "/Length " + payload.length().to_string(),
    b"\n",
  )
  let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
  defer @input.end_input_session(owner)
  let cache = pdf_make_font_program_cache(owner.source).unwrap()
  let object = ranged_test_object(
    owner.source,
    @input.open_source_cursor(owner.source).unwrap(),
    bytes,
    offset,
  )
  let unsupported = { ..object, dict_text: "<< /Filter /UnknownFilter >>", }
  assert_true(font_cache_test_get(unsupported, cache) is Ok(None))
  assert_eq(cache.programs.length(), 0)
  assert_true(font_cache_test_get(object, cache).unwrap() is Some(_))
  assert_eq(cache.programs.length(), 1)
}

///|
async test "retained program payload overflow stays a typed budget first error" {
  let owner = @input.begin_input_session(@input.input_from_bytes(b""))
  defer @input.end_input_session(owner)
  let cache = pdf_make_font_program_cache(owner.source).unwrap()
  let result = Ok(pdf_font_payload_add(cache.context, 9223372036854775807L, 1L)) catch {
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
    @input.input_source_failure(owner.source)
    is Some(BudgetFailure(ArithmeticOverflow(Resident(CacheBytes), ..))),
  )
}
