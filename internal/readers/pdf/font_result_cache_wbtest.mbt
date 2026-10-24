///|
// The range is assembled from test-owned bytes. Metadata admission is prepaid
// here solely to isolate local FontFile cache publication (including Cache=0).
async fn font_result_test_reader_fixture(
  payload : Bytes,
  plan : String,
  limits~ : @budget.BudgetLimits? = None,
  read_error~ : Bool = false,
) -> (@input.InputSession, PdfFontProgramCache, PdfNativeObject, Ref[Int32]) {
  let (bytes, offset) = ranged_test_bytes(
    payload,
    "/Length " + payload.length().to_string(),
    b"\n",
  )
  let calls = Ref(0)
  let reader = @input.make_input_reader(
    fn(start, length) {
      calls.val += 1
      if read_error {
        Err("controlled negative FontFile range IO")
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
  let cache = pdf_make_font_program_cache(owner.source).unwrap()
  let object = pdf_parse_indirect_object_at(
    bytes,
    offset,
    decode_context=Some(cache.context),
    range_source=Some({
      cursor: @input.open_source_cursor(owner.source).unwrap(),
      window_start: 0L,
      definition_offset: offset.to_int64(),
      generation: 7,
      metadata_prepaid: true,
    }),
  ).unwrap()
  (
    owner,
    cache,
    {
      ..object,
      dict_text: "<< /Length " +
      payload.length().to_string() +
      " " +
      plan +
      " >>",
    },
    calls,
  )
}

///|
async test "FontFile local None repeats one validated decode rather than eight" {
  let (owner, cache, object, calls) = font_result_test_reader_fixture(
    @zlib.zlib_compress(b"font"),
    "/Filter /FlateDecode",
  )
  defer @input.end_input_session(owner)
  for _ in 0..<8 {
    assert_true(font_cache_test_get(object, cache, kind=None) is Ok(None))
  }
  assert_eq(
    cache.context.budget.account.snapshot().cumulative.inflate_bytes,
    4L,
  )
  assert_eq(calls.val, 1)
  assert_eq(cache.programs.length(), 1)
}

///|
async test "FontFile ordinary filter Err repeats only one prior valid Flate decode" {
  let payload = font_cache_test_sfnt()
  let (owner, cache, object, calls) = font_result_test_reader_fixture(
    @zlib.zlib_compress(payload),
    "/Filter [/FlateDecode /UnknownFilter]",
  )
  defer @input.end_input_session(owner)
  for _ in 0..<8 {
    assert_true(font_cache_test_get(object, cache) is Ok(None))
  }
  assert_eq(
    cache.context.budget.account.snapshot().cumulative.inflate_bytes,
    payload.length().to_int64(),
  )
  assert_eq(calls.val, 1)
  assert_eq(cache.programs.length(), 1)
}

///|
async test "FontFile ordinary predictor Err repeats only one actual decode" {
  let payload = font_cache_test_sfnt()
  let (owner, cache, object, calls) = font_result_test_reader_fixture(
    @zlib.zlib_compress(payload),
    "/Filter /FlateDecode /DecodeParms << /Predictor 99 >>",
  )
  defer @input.end_input_session(owner)
  for _ in 0..<8 {
    assert_true(font_cache_test_get(object, cache) is Ok(None))
  }
  assert_eq(
    cache.context.budget.account.snapshot().cumulative.inflate_bytes,
    payload.length().to_int64(),
  )
  assert_eq(calls.val, 1)
  assert_eq(cache.programs.length(), 1)
}

///|
async test "FontFile rejected DecodeParms plan reuses its original ordinary Err" {
  let (owner, cache, object, calls) = font_result_test_reader_fixture(
    @zlib.zlib_compress(b"font"),
    "/Filter [/FlateDecode /FlateDecode] /DecodeParms << /Predictor 1 >>",
  )
  defer @input.end_input_session(owner)
  for _ in 0..<8 {
    assert_true(font_cache_test_get(object, cache) is Ok(None))
  }
  assert_eq(calls.val, 1)
  assert_eq(
    cache.context.budget.account.snapshot().cumulative.inflate_bytes,
    0L,
  )
  assert_eq(cache.programs.length(), 1)
}

///|
fn font_result_test_shared_unknown_pdf() -> Bytes {
  let payload = @zlib.zlib_compress(b"font")
  let objects : Array[(Int32, String)] = [
    (1, "<< /Type /Catalog /Pages 2 0 R >>"),
    (2, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>"),
    (
      90, "<< /Type /Font /Subtype /CIDFontType2 /BaseFont /Shared /FontDescriptor 91 0 R /CIDToGIDMap /Identity /W [65 [500]] /DW 1000 >>",
    ),
    (91, "<< /Type /FontDescriptor /FontFile3 103 0 R >>"),
    (103, bounded_pdf_test_stream(payload, extra="/Subtype /Unknown")),
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
async test "nine real font-registry consumers share validated unknown FontFile3 absence" {
  let account = @budget.Budget::new(bounded_pdf_test_limits(None))
  let owner = @input.begin_input_session(
    @input.input_from_bytes(font_result_test_shared_unknown_pdf()),
    budget=account,
  )
  defer @input.end_input_session(owner)
  let store = pdf_load_object_store(
    owner.source,
    pdf_make_stream_decode_context(owner.source),
  ).unwrap()
  let selected = store.object_index.get(103).unwrap()
  assert_true(selected.stream is Some(Ranged(_)))
  let initial = account.snapshot().cumulative.inflate_bytes
  let uncached = pdf_collect_font_infos(store.object_index).unwrap()
  let uncached_bytes = account.snapshot().cumulative.inflate_bytes - initial
  let cache = pdf_make_font_program_cache(owner.source).unwrap()
  let before = account.snapshot().cumulative.inflate_bytes
  let cached = pdf_collect_font_infos(
    store.object_index,
    program_cache=Some(cache),
  ).unwrap()
  let cached_bytes = account.snapshot().cumulative.inflate_bytes - before
  assert_eq(uncached_bytes, 36L)
  assert_eq(cached_bytes, 4L)
  assert_eq(cache.programs.length(), 1)
  assert_eq(cached.infos.length(), uncached.infos.length())
  for id, info in cached.infos {
    let original = uncached.infos.get(id).unwrap()
    assert_true(info.embedded_font_program is None)
    assert_true(original.embedded_font_program is None)
    assert_eq(info.tounicode_decode_failed, original.tounicode_decode_failed)
    assert_eq(info.unicode_map, original.unicode_map)
    assert_eq(info.cid_width_pairs, original.cid_width_pairs)
    assert_eq(info.cid_default_width, original.cid_default_width)
  }
}

///|
async test "FontFile descriptor and selected target lookup remain outside local negative caching" {
  let (owner, cache, object, _) = font_result_test_reader_fixture(
    @zlib.zlib_compress(font_cache_test_sfnt()),
    "/Filter /FlateDecode",
  )
  defer @input.end_input_session(owner)
  let descriptor : PdfNativeObject = {
    object_id: 2,
    dict_text: "<< /FontFile2 1 0 R >>",
    stream: None,
  }
  let index = Map([(2, descriptor)])
  let font = "<< /FontDescriptor 2 0 R >>"
  assert_true(
    pdf_extract_embedded_font_program(font, index, cache=Some(cache)) is None,
  )
  assert_eq(cache.programs.length(), 0)
  index.set(1, object)
  assert_true(
    pdf_extract_embedded_font_program(font, index, cache=Some(cache)) is Some(_),
  )
  assert_eq(cache.programs.length(), 1)
  assert_true(
    pdf_extract_embedded_font_program(font, Map([]), cache=Some(cache)) is None,
  )
  index.set(1, { ..object, dict_text: "<< /Filter /UnknownFilter >>", })
  assert_true(
    pdf_extract_embedded_font_program(font, index, cache=Some(cache)) is None,
  )
  assert_eq(cache.programs.length(), 2)
}

///|
async test "FontFile local Result distinguishes Some empty None and ordinary Err" {
  for empty in [false, true] {
    let payload = if empty { b"" } else { b"font" }
    let (owner, cache, object, calls) = font_result_test_reader_fixture(
      @zlib.zlib_compress(payload),
      "/Filter /FlateDecode",
    )
    defer @input.end_input_session(owner)
    let program = font_cache_test_get(object, cache).unwrap().unwrap()
    assert_eq(program.gid_unicode_gids.length(), 0)
    assert_true(font_cache_test_get(object, cache, kind=None) is Ok(None))
    let rejected = { ..object, dict_text: "<< /Filter /UnknownFilter >>", }
    assert_true(font_cache_test_get(rejected, cache) is Ok(None))
    let successful = cache.programs
      .get(pdf_font_program_cache_key(object, Some(0)).unwrap())
      .unwrap()
    let absent = cache.programs
      .get(pdf_font_program_cache_key(object, None).unwrap())
      .unwrap()
    let failed = cache.programs
      .get(pdf_font_program_cache_key(rejected, Some(0)).unwrap())
      .unwrap()
    assert_true(successful is Ok(Some(_)))
    assert_true(absent is Ok(None))
    assert_true(failed is Err(_))
    let snapshot = cache.context.budget.account.snapshot()
    let reads = calls.val
    assert_true(font_cache_test_get(object, cache).unwrap() is Some(_))
    assert_true(font_cache_test_get(object, cache, kind=None) is Ok(None))
    assert_true(font_cache_test_get(rejected, cache) is Ok(None))
    assert_eq(calls.val, reads)
    assert_true(cache.context.budget.account.snapshot() == snapshot)
  }
}

///|
async test "FontFile Result key contains every selected range field and parser dispatch" {
  let (owner, _, object, _) = font_result_test_reader_fixture(
    @zlib.zlib_compress(b"font"),
    "/Filter /FlateDecode",
  )
  defer @input.end_input_session(owner)
  let key = pdf_font_program_cache_key(object, Some(0)).unwrap()
  let range = ranged_test_range(object)
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
    let changed = { ..object, stream: Some(Ranged(alternate)), }
    assert_false(pdf_font_program_cache_key(changed, Some(0)).unwrap() == key)
  }
  assert_false(
    pdf_font_program_cache_key(
      { ..object, object_id: object.object_id + 1, },
      Some(0),
    ).unwrap() ==
    key,
  )
  for kind in [Some(1), Some(2), Some(3), None] {
    assert_false(pdf_font_program_cache_key(object, kind).unwrap() == key)
  }
}

///|
async test "FontFile typed filter plan distinguishes parameters order and invalid specifications" {
  let (owner, _, object, _) = font_result_test_reader_fixture(
    @zlib.zlib_compress(b"font"),
    "/Filter /FlateDecode",
  )
  defer @input.end_input_session(owner)
  let base = {
    ..object,
    dict_text: "<< /Filter /FlateDecode /DecodeParms << /Predictor 1 /Colors 1 /BitsPerComponent 8 /Columns 1 /EarlyChange 1 >> >>",
  }
  let key = pdf_font_program_cache_key(base, Some(0)).unwrap()
  for
    params in [
      "/Colors 1 /BitsPerComponent 8 /Columns 1 /EarlyChange 1", "/Predictor 2 /Colors 1 /BitsPerComponent 8 /Columns 1 /EarlyChange 1",
      "/Predictor 1 /Colors 2 /BitsPerComponent 8 /Columns 1 /EarlyChange 1", "/Predictor 1 /Colors 1 /BitsPerComponent 16 /Columns 1 /EarlyChange 1",
      "/Predictor 1 /Colors 1 /BitsPerComponent 8 /Columns 2 /EarlyChange 1", "/Predictor 1 /Colors 1 /BitsPerComponent 8 /Columns 1 /EarlyChange 0",
    ] {
    let changed = {
      ..object,
      dict_text: "<< /Filter /FlateDecode /DecodeParms << " + params + " >> >>",
    }
    assert_false(pdf_font_program_cache_key(changed, Some(0)).unwrap() == key)
  }
  let equivalent = {
    ..object,
    dict_text: "<< /F /FlateDecode /DP << /EarlyChange 1 /Columns 1 /BitsPerComponent 8 /Colors 1 /Predictor 1 >> /Subtype /OpenType >>",
  }
  assert_true(pdf_font_program_cache_key(equivalent, Some(0)).unwrap() == key)
  let first = {
    ..object,
    dict_text: "<< /Filter [/FlateDecode /UnknownFilter] >>",
  }
  let reversed = {
    ..object,
    dict_text: "<< /Filter [/UnknownFilter /FlateDecode] >>",
  }
  assert_false(
    pdf_font_program_cache_key(first, Some(0)) ==
    pdf_font_program_cache_key(reversed, Some(0)),
  )
  let bad = {
    ..object,
    dict_text: "<< /Filter [/FlateDecode /FlateDecode] /DecodeParms <<>> >>",
  }
  let other_bad = {
    ..object,
    dict_text: "<< /Filter [/FlateDecode /FlateDecode] /DecodeParms <<>> /Unrelated 1 >>",
  }
  let bad_key = pdf_font_program_cache_key(bad, Some(0)).unwrap()
  assert_true(bad_key.plan is Rejected(_))
  assert_false(
    bad_key == pdf_font_program_cache_key(other_bad, Some(0)).unwrap(),
  )
}

///|
async test "FontFile supported plan and ordinary failure cannot poison either call order" {
  for fail_first in [false, true] {
    let (owner, cache, good, calls) = font_result_test_reader_fixture(
      @zlib.zlib_compress(font_cache_test_sfnt()),
      "/Filter /FlateDecode",
    )
    defer @input.end_input_session(owner)
    let bad = {
      ..good,
      dict_text: "<< /Filter [/FlateDecode /UnknownFilter] >>",
    }
    if fail_first {
      assert_true(font_cache_test_get(bad, cache) is Ok(None))
    }
    let program = font_cache_test_get(good, cache).unwrap().unwrap()
    if !fail_first {
      assert_true(font_cache_test_get(bad, cache) is Ok(None))
    }
    let reads = calls.val
    let snapshot = cache.context.budget.account.snapshot()
    let shared = font_cache_test_get(good, cache).unwrap().unwrap()
    assert_true(
      physical_equal(program.gid_unicode_gids, shared.gid_unicode_gids),
    )
    assert_true(font_cache_test_get(bad, cache) is Ok(None))
    assert_eq(calls.val, reads)
    assert_true(cache.context.budget.account.snapshot() == snapshot)
    assert_eq(cache.programs.length(), 2)
  }
}

///|
async test "FontFile negative hit cannot bypass Input Budget Resource first failure or closed owner" {
  for ordinary_err in [false, true] {
    for failure in 0..<4 {
      let (owner, cache, object, calls) = font_result_test_reader_fixture(
        @zlib.zlib_compress(b"font"),
        if ordinary_err {
          "/Filter [/FlateDecode /UnknownFilter]"
        } else {
          "/Filter /FlateDecode"
        },
      )
      assert_true(font_cache_test_get(object, cache, kind=None) is Ok(None))
      let reads = calls.val
      let before = cache.context.budget.account.snapshot().cumulative
      match failure {
        0 =>
          @input.record_input_failure(
            owner.source,
            "controlled negative-cache IO failure",
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
      let result = font_cache_test_get(object, cache, kind=None)
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
      assert_true(cache.context.budget.account.snapshot().cumulative == before)
      assert_eq(cache.programs.length(), 1)
      @input.end_input_session(owner)
      assert_eq(cache.context.budget.account.snapshot().active_leases, 0L)
    }
  }
}

///|
async test "FontFile negative results remain private to fresh document owners" {
  for payload in [b"font", b"word"] {
    let (owner, cache, object, calls) = font_result_test_reader_fixture(
      @zlib.zlib_compress(payload),
      "/Filter /FlateDecode",
    )
    assert_eq(cache.programs.length(), 0)
    assert_true(font_cache_test_get(object, cache, kind=None) is Ok(None))
    assert_eq(calls.val, 1)
    assert_eq(
      cache.context.budget.account.snapshot().cumulative.inflate_bytes,
      4L,
    )
    assert_eq(cache.programs.length(), 1)
    @input.end_input_session(owner)
    assert_eq(cache.context.budget.account.snapshot().active_leases, 0L)
  }
}

///|
async test "FontFile hard integrity precedes unsupported kind filter and predictor without negative publication" {
  for
    plan in [
      "/Filter /FlateDecode", "/Filter [/FlateDecode /UnknownFilter]", "/Filter /FlateDecode /DecodeParms << /Predictor 99 >>",
    ] {
    let (owner, cache, object, calls) = font_result_test_reader_fixture(
      b"\x78\x9c\x00", plan,
    )
    assert_true(
      font_cache_test_get(object, cache, kind=None)
      is Err(StreamIntegrityFailed(_, _)),
    )
    assert_eq(cache.programs.length(), 0)
    let reads = calls.val
    let inflated = cache.context.budget.account.snapshot().cumulative.inflate_bytes
    assert_true(font_cache_test_get(object, cache, kind=None) is Err(_))
    assert_eq(calls.val, reads)
    assert_eq(
      cache.context.budget.account.snapshot().cumulative.inflate_bytes,
      inflated,
    )
    @input.end_input_session(owner)
    assert_eq(cache.context.budget.account.snapshot().active_leases, 0L)
  }
}

///|
async test "FontFile unsupported first filter retains its ordinary short circuit before later Flate" {
  let (owner, cache, object, calls) = font_result_test_reader_fixture(
    b"\x78\x9c\x00", "/Filter [/UnknownFilter /FlateDecode]",
  )
  defer @input.end_input_session(owner)
  assert_true(font_cache_test_get(object, cache, kind=None) is Ok(None))
  assert_true(font_cache_test_get(object, cache, kind=None) is Ok(None))
  assert_eq(calls.val, 1)
  assert_eq(
    cache.context.budget.account.snapshot().cumulative.inflate_bytes,
    0L,
  )
  assert_true(@input.input_source_failure(owner.source) is None)
}

///|
async test "FontFile Inflate budget first failure cannot become a cached absence or ordinary Err" {
  for ordinary_err in [false, true] {
    let (owner, cache, object, calls) = font_result_test_reader_fixture(
      @zlib.zlib_compress(b"font"),
      if ordinary_err {
        "/Filter [/FlateDecode /UnknownFilter]"
      } else {
        "/Filter /FlateDecode"
      },
      limits=Some(bounded_pdf_test_limits(Some(0L))),
    )
    assert_true(
      font_cache_test_get(object, cache, kind=None) is Err(BudgetExceeded(_)),
    )
    assert_true(
      @input.input_source_failure(owner.source) is Some(BudgetFailure(_)),
    )
    assert_eq(cache.programs.length(), 0)
    let reads = calls.val
    let inflated = cache.context.budget.account.snapshot().cumulative.inflate_bytes
    assert_true(
      font_cache_test_get(object, cache, kind=None) is Err(BudgetExceeded(_)),
    )
    assert_eq(calls.val, reads)
    assert_eq(
      cache.context.budget.account.snapshot().cumulative.inflate_bytes,
      inflated,
    )
    @input.end_input_session(owner)
    assert_eq(cache.context.budget.account.snapshot().active_leases, 0L)
  }
}

///|
async test "FontFile IO on a negative candidate is hard and cannot be retried from an absence" {
  for ordinary_err in [false, true] {
    let (owner, cache, object, calls) = font_result_test_reader_fixture(
      @zlib.zlib_compress(b"font"),
      if ordinary_err {
        "/Filter [/FlateDecode /UnknownFilter]"
      } else {
        "/Filter /FlateDecode"
      },
      read_error=true,
    )
    assert_true(
      font_cache_test_get(object, cache, kind=None) is Err(ReadFailed(_)),
    )
    assert_true(
      @input.input_source_failure(owner.source) is Some(InputError(_)),
    )
    assert_eq(cache.programs.length(), 0)
    let reads = calls.val
    assert_true(
      font_cache_test_get(object, cache, kind=None) is Err(ReadFailed(_)),
    )
    assert_eq(calls.val, reads)
    assert_eq(
      cache.context.budget.account.snapshot().cumulative.inflate_bytes,
      0L,
    )
    @input.end_input_session(owner)
    assert_eq(cache.context.budget.account.snapshot().active_leases, 0L)
  }
}

///|
async test "FontFile callback first failure prevents publication of a newly computed negative result" {
  for failure in 0..<3 {
    let payload = @zlib.zlib_compress(b"font")
    let (bytes, offset) = ranged_test_bytes(
      payload,
      "/Length " + payload.length().to_string(),
      b"\n",
    )
    let exposed : Ref[@input.InputSource?] = Ref(None)
    let reads = Ref(0)
    let reader = @input.make_input_reader(
      fn(start, length) {
        reads.val += 1
        let source = exposed.val.unwrap()
        match failure {
          0 => @input.record_input_failure(source, "FontFile callback failure")
          1 =>
            @input.record_input_budget_failure(
              source,
              LimitExceeded(
                Resident(CacheBytes),
                used=0L,
                requested=1L,
                limit=0L,
              ),
            )
          _ =>
            @input.record_input_resource_failure(
              source,
              @input.make_resource_limit_failure(SingleAssetBytes, 1L, 0L),
            )
        }
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
    exposed.val = Some(owner.source)
    let cache = pdf_make_font_program_cache(owner.source).unwrap()
    let object = ranged_test_object(
      owner.source,
      @input.open_source_cursor(owner.source).unwrap(),
      bytes,
      offset,
    )
    let result = font_cache_test_get(object, cache, kind=None)
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
    assert_eq(cache.programs.length(), 0)
    let before = reads.val
    assert_true(font_cache_test_get(object, cache, kind=None) is Err(_))
    assert_eq(reads.val, before)
    @input.end_input_session(owner)
    assert_eq(account.snapshot().active_leases, 0L)
  }
}

///|
async test "FontFile negative Cache admission immediately terminates before a scheduled later corrupt range" {
  for ordinary_err in [false, true] {
    for limited in [false, true] {
      let limits = @budget.BudgetLimits::new(
        MeasurementOnly,
        inflate_bytes=None,
        parse_work=None,
        output_utf8_bytes=None,
        source_metadata_bytes=None,
        rag_metadata_bytes=None,
        read_traffic_bytes=None,
        cache_bytes=if limited { Some(0L) } else { None },
        working_bytes=None,
        temporary_bytes=None,
        ir_bytes=None,
      ).unwrap()
      let (owner, cache, object, calls) = font_result_test_reader_fixture(
        @zlib.zlib_compress(b"font"),
        if ordinary_err {
          "/Filter [/FlateDecode /UnknownFilter]"
        } else {
          "/Filter /FlateDecode"
        },
        limits=Some(limits),
      )
      let range = ranged_test_range(object)
      // A genuine truncated zlib prefix in this same source/session; the test
      // schedules the second gateway only after the first local outcome.
      let corrupt = {
        ..object,
        dict_text: "<< /Filter /FlateDecode /Length 3 >>",
        stream: Some(
          Ranged({
            ..range,
            definition_offset: range.definition_offset + 1L,
            primary_length: 3,
            endstream_length: 3,
            endstream_eol_suffix: 0,
            endstream_eol_length: 0,
            declared_length: Some(3),
          }),
        ),
      }
      let first = font_cache_test_get(object, cache, kind=None)
      let reads = calls.val
      let second = font_cache_test_get(corrupt, cache, kind=None)
      if limited {
        assert_true(
          first is Err(BudgetExceeded(LimitExceeded(Resident(CacheBytes), ..))),
        )
        assert_true(second is Err(BudgetExceeded(_)))
        assert_true(
          @input.input_source_failure(owner.source) is Some(BudgetFailure(_)),
        )
        assert_eq(calls.val, reads)
        assert_eq(cache.programs.length(), 0)
      } else {
        assert_true(first is Ok(None))
        assert_true(second is Err(StreamIntegrityFailed(_, _)))
        assert_true(calls.val > reads)
        assert_eq(cache.programs.length(), 1)
      }
      @input.end_input_session(owner)
      assert_eq(cache.context.budget.account.snapshot().active_leases, 0L)
    }
  }
}

///|
async test "FontFile retained payload counts None Some error and fixed optional fields" {
  let (owner, cache, object, _) = font_result_test_reader_fixture(
    @zlib.zlib_compress(b"font"),
    "/Filter /FlateDecode",
  )
  defer @input.end_input_session(owner)
  let base = {
    ..pdf_font_program_cache_key(object, None).unwrap(),
    plan: Resolved([], []),
  }
  let empty : PdfEmbeddedFontProgram = {
    gid_unicode_gids: [],
    gid_unicode_values: [],
    gid_glyph_name_gids: [],
    gid_glyph_name_values: [],
    gid_advance_pairs: [],
    default_advance_width: None,
  }
  assert_eq(
    pdf_font_result_retained_payload(cache.context, base, Ok(None)),
    108L,
  )
  assert_eq(
    pdf_font_result_retained_payload(cache.context, base, Err("no")),
    112L,
  )
  assert_eq(
    pdf_font_result_retained_payload(cache.context, base, Ok(Some(empty))),
    156L,
  )
  assert_eq(
    pdf_font_result_retained_payload(
      cache.context,
      base,
      Ok(Some({ ..empty, default_advance_width: Some(0), })),
    ),
    156L,
  )
  let optional = { ..base, kind: Some(0), declared_length: None, }
  assert_eq(
    pdf_font_result_retained_payload(cache.context, optional, Ok(None)),
    108L,
  )
  let rejected = { ..base, plan: Rejected("x"), }
  assert_eq(
    pdf_font_result_retained_payload(cache.context, rejected, Ok(None)),
    102L,
  )
  let params : PdfFontDecodeParamsKey = {
    predictor: None,
    colors: None,
    bits_per_component: None,
    columns: None,
    early_change: None,
  }
  let absent_params = { ..base, plan: Resolved([], [None]), }
  let present_params = { ..base, plan: Resolved([], [Some(params)]), }
  assert_eq(
    pdf_font_result_retained_payload(cache.context, present_params, Ok(None)) -
    pdf_font_result_retained_payload(cache.context, absent_params, Ok(None)),
    40L,
  )
}

///|
async test "cancelled FontFile negative candidates publish nothing and release scratch" {
  for ordinary_err in [false, true] {
    let payload = @zlib.zlib_compress(b"font")
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
    let object = if ordinary_err {
      { ..object, dict_text: "<< /Filter [/FlateDecode /UnknownFilter] >>", }
    } else {
      object
    }
    @async.with_task_group(group => {
      let task = group.spawn(() => {
        @async.handle_cancellation(() => {
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
    assert_true(@input.input_source_failure(owner.source) is None)
    assert_eq(account.snapshot().resident.working_bytes, 0L)
    @input.end_input_session(owner)
    assert_eq(account.snapshot().active_leases, 0L)
  }
}
