///|
fn loaded_definition_test_file(
  payload : Bytes,
  generation~ : Int32 = 7,
  indent~ : Int32 = 0,
  separator~ : Bytes = b"\r\n",
  indirect_length~ : Bool = false,
) -> (Bytes, Int32, Int32) {
  let encoded = @zlib.zlib_compress(payload)
  let out = Buffer()
  out.write_bytes(b"%PDF-1.4\n% owned snapshot\n")
  out.write_bytes(pdf_ascii_bytes(String::make(indent, ' ')))
  let offset = out.length()
  out.write_bytes(
    pdf_ascii_bytes(
      "71 " +
      generation.to_string() +
      " obj\n<< /Type /Example /Length " +
      (if indirect_length { "99 0 R" } else { encoded.length().to_string() }) +
      " /Filter /FlateDecode >>\nstream\n",
    ),
  )
  let payload_start = out.length()
  out.write_bytes(encoded)
  out.write_bytes(separator)
  out.write_bytes(b"endstream\nendobj\n")
  if indirect_length {
    out.write_bytes(
      pdf_ascii_bytes(
        "99 0 obj\n" + encoded.length().to_string() + "\nendobj\n",
      ),
    )
  }
  (out.to_bytes(), offset, payload_start)
}

///|
async test "identity baseline observation preserves legacy owned bytes without inventing a definition" {
  let (bytes, offset, _) = loaded_definition_test_file(b"authority")
  let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
  defer @input.end_input_session(owner)
  let object = pdf_parse_indirect_object_at(
    bytes,
    offset,
    decode_context=pdf_make_stream_decode_context(owner.source),
  ).unwrap()
  assert_eq(object.object_id, 71)
  assert_true(object.stream is Some(Loaded(_)))
  assert_true(pdf_font_program_cache_key(object, Some(0)) is None)
  assert_eq(
    pdf_decode_stream_bytes(object, "identity observation").unwrap(),
    b"authority",
  )
}

///|
async test "identity baseline observation keeps distinct raw definitions with the same object ID" {
  for (generation, expected) in [(7, b"authority"), (8, b"another")] {
    let (bytes, offset, _) = loaded_definition_test_file(expected, generation~)
    let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
    defer @input.end_input_session(owner)
    let object = pdf_parse_indirect_object_at(
      bytes,
      offset,
      decode_context=pdf_make_stream_decode_context(owner.source),
    ).unwrap()
    assert_eq(object.object_id, 71)
    assert_true(object.stream is Some(Loaded(_)))
    assert_eq(
      pdf_decode_stream_bytes(object, "identity observation").unwrap(),
      expected,
    )
  }
}

///|
async fn loaded_definition_test_store(
  source : @input.InputSource,
  bytes : Bytes,
) -> Result[PdfParsedObjectStore, PdfNativeError] {
  pdf_parse_objects(
    bytes,
    pdf_byte_string(bytes),
    decode_context=pdf_make_stream_decode_context(source),
  ) catch {
    PdfHardDecodeFailure(error) => Err(error)
    error => raise error
  }
}

///|
async test "scan selected definition keeps real header generation absolute offsets and owned bytes" {
  for (indent, separator) in [(0, b""), (3, b"\n"), (2, b"\r\n")] {
    let (bytes, offset, payload_start) = loaded_definition_test_file(
      b"authority\x00endobj-style",
      indent~,
      separator~,
    )
    let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
    defer @input.end_input_session(owner)
    let store = loaded_definition_test_store(owner.source, bytes).unwrap()
    match store.object_index.get(71).unwrap().stream {
      Some(SelectedLoaded(slice, definition)) => {
        assert_eq(definition.object_id, 71)
        assert_eq(definition.generation, 7)
        assert_eq(definition.definition_offset, offset.to_int64())
        assert_eq(definition.payload_start, payload_start.to_int64())
        assert_true(definition.body_start > definition.definition_offset)
        assert_eq(
          slice.primary_bytes,
          @zlib.zlib_compress(b"authority\x00endobj-style"),
        )
        assert_eq(
          slice.primary_bytes,
          bytes[payload_start:payload_start + slice.primary_bytes.length()].to_owned(),
        )
        assert_eq(definition.snapshot.source_size, bytes.length())
      }
      _ =>
        fail(
          "a proven scan definition must retain its actual source coordinates",
        )
    }
    // Field payload only: snapshot24 + definition/SelectedLoaded56.
    let context = pdf_make_stream_decode_context(owner.source).unwrap()
    assert_eq(context.budget.account.snapshot().resident.cache_bytes, 80L)
  }
}

///|
async test "fresh materializations on one live owner get distinct Native mutable authorities" {
  let (bytes, _, _) = loaded_definition_test_file(b"same bytes")
  let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
  defer @input.end_input_session(owner)
  let first = loaded_definition_test_store(owner.source, bytes).unwrap()
  let second = loaded_definition_test_store(owner.source, bytes).unwrap()
  match
    (
      first.object_index.get(71).unwrap().stream,
      second.object_index.get(71).unwrap().stream,
    ) {
    (Some(SelectedLoaded(left, a)), Some(SelectedLoaded(right, b))) => {
      assert_eq(left.primary_bytes, right.primary_bytes)
      assert_eq(a.snapshot.authority.val, b.snapshot.authority.val)
      assert_true(physical_equal(a.snapshot.authority, a.snapshot.authority))
      assert_false(physical_equal(a.snapshot.authority, b.snapshot.authority))
    }
    _ => fail("both materializations must carry their own snapshot authority")
  }
}

///|
async test "two selected definitions share one authority while offsets generations and duplicate selection remain exact" {
  let (left, left_offset, _) = loaded_definition_test_file(
    b"first",
    generation=7,
  )
  let (right, right_offset, _) = loaded_definition_test_file(
    b"second",
    generation=8,
  )
  let bytes = left + right
  let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
  defer @input.end_input_session(owner)
  let store = loaded_definition_test_store(owner.source, bytes).unwrap()
  assert_eq(store.objects.length(), 2)
  match (store.objects[0].stream, store.objects[1].stream) {
    (Some(SelectedLoaded(a, first)), Some(SelectedLoaded(b, second))) => {
      assert_true(
        physical_equal(first.snapshot.authority, second.snapshot.authority),
      )
      assert_eq(first.definition_offset, left_offset.to_int64())
      assert_eq(
        second.definition_offset,
        (left.length() + right_offset).to_int64(),
      )
      assert_eq(first.generation, 7)
      assert_eq(second.generation, 8)
      assert_true(a.primary_bytes != b.primary_bytes)
    }
    _ => fail("both actual definitions retain their own data and one snapshot")
  }
  // Preserve existing scan last-definition behavior, without a generation fix.
  match store.object_index.get(71).unwrap().stream {
    Some(SelectedLoaded(_, selected)) => assert_eq(selected.generation, 8)
    _ => fail("selected last definition must be preserved")
  }
}

///|
async test "selected definition survives indirect Length framing resolution with current owned bytes" {
  let payload = b"indirect"
  let encoded = @zlib.zlib_compress(payload)
  let (bytes, offset, _) = loaded_definition_test_file(
    payload,
    indirect_length=true,
  )
  let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
  defer @input.end_input_session(owner)
  let store = loaded_definition_test_store(owner.source, bytes).unwrap()
  let object = store.object_index.get(71).unwrap()
  match object.stream {
    Some(SelectedLoaded(slice, definition)) => {
      assert_eq(definition.definition_offset, offset.to_int64())
      assert_eq(definition.generation, 7)
      assert_eq(slice.declared_length, Some(encoded.length()))
      assert_eq(slice.primary_bytes, encoded)
      let start = definition.payload_start.to_int()
      assert_eq(bytes[start:start + encoded.length()], encoded[:])
    }
    _ =>
      fail("Length fixup must retain the original snapshot and header identity")
  }
  assert_eq(
    pdf_decode_stream_bytes(object, "resolved Length").unwrap(),
    payload,
  )
}

///|
fn loaded_definition_test_xref(
  bytes : Bytes,
  object_offset : Int32,
  generation : Int32,
) -> Bytes {
  let offset_text = object_offset.to_string()
  let generation_text = generation.to_string()
  bytes +
  pdf_ascii_bytes(
    "xref\n0 1\n0000000000 65535 f \n71 1\n" +
    String::make(10 - offset_text.length(), '0') +
    offset_text +
    " " +
    String::make(5 - generation_text.length(), '0') +
    generation_text +
    " n \ntrailer\n<< /Size 72 >>\nstartxref\n" +
    bytes.length().to_string() +
    "\n%%EOF\n",
  )
}

///|
async test "materialized xref records exact selected generations and bypasses ambiguous legacy selection" {
  let (body, offset, payload_start) = loaded_definition_test_file(b"xref")
  for selected_generation in [7, 8] {
    let bytes = loaded_definition_test_xref(body, offset, selected_generation)
    let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
    defer @input.end_input_session(owner)
    let store = loaded_definition_test_store(owner.source, bytes).unwrap()
    let object = store.object_index.get(71).unwrap()
    if selected_generation == 7 {
      match object.stream {
        Some(SelectedLoaded(_, definition)) => {
          assert_eq(definition.definition_offset, offset.to_int64())
          assert_eq(definition.generation, 7)
          assert_eq(definition.payload_start, payload_start.to_int64())
        }
        _ => fail("exact xref and header coordinates must agree")
      }
    } else {
      assert_true(object.stream is Some(Loaded(_)))
    }
    assert_eq(
      pdf_decode_stream_bytes(object, "selected xref").unwrap(),
      b"xref",
    )
  }
}

///|
async test "selected Loaded snapshot and definition admissions fail typed without legacy bypass" {
  let (bytes, _, _) = loaded_definition_test_file(b"scope")
  for (cap, used, requested) in [(23L, 0L, 24L), (79L, 24L, 56L)] {
    let account = @budget.Budget::new(
      loaded_objstm_limits(cache_bytes=Some(cap)),
    )
    let owner = @input.begin_input_session(
      @input.input_from_bytes(bytes),
      budget=account,
    )
    defer @input.end_input_session(owner)
    match loaded_definition_test_store(owner.source, bytes) {
      Err(
        BudgetExceeded(
          LimitExceeded(
            Resident(CacheBytes),
            used=actual_used,
            requested=actual_requested,
            limit~
          )
        )
      ) => {
        assert_eq(actual_used, used)
        assert_eq(actual_requested, requested)
        assert_eq(limit, cap)
      }
      _ => fail("identity admission cannot fall back to unproven success")
    }
    assert_true(
      @input.input_source_failure(owner.source) is Some(BudgetFailure(_)),
    )
    assert_eq(account.snapshot().cumulative.inflate_bytes, 0L)
    let before = account.snapshot().cumulative
    assert_true(
      loaded_definition_test_store(owner.source, bytes)
      is Err(BudgetExceeded(_)),
    )
    assert_true(account.snapshot().cumulative == before)
  }
}

///|
async test "selected Loaded live gateway rejects closure before decode on the original owner" {
  let (bytes, _, _) = loaded_definition_test_file(b"closed")
  let account = @budget.Budget::new(loaded_objstm_limits())
  let owner = @input.begin_input_session(
    @input.input_from_bytes(bytes),
    budget=account,
  )
  let store = loaded_definition_test_store(owner.source, bytes).unwrap()
  let object = store.object_index.get(71).unwrap()
  assert_true(object.stream is Some(SelectedLoaded(_, _)))
  @input.end_input_session(owner)
  let before = account.snapshot().cumulative
  let result = pdf_decode_stream_bytes(object, "closed selected stream") catch {
    PdfHardDecodeFailure(error) => Err(error)
    error => raise error
  }
  assert_true(result is Err(ReadFailed(_)))
  assert_true(account.snapshot().cumulative == before)
  assert_eq(account.snapshot().active_leases, 0L)
}

///|
async test "selected Loaded nonzero materialized window adds its absolute origin exactly once" {
  let (bytes, offset, payload_start) = loaded_definition_test_file(b"window")
  let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
  defer @input.end_input_session(owner)
  let store = loaded_definition_test_store(owner.source, bytes).unwrap()
  let snapshot = pdf_loaded_store_snapshot(store.objects).unwrap()
  let start = offset - 2
  let object = pdf_parse_indirect_object_at(
    bytes[start:].to_owned(),
    2,
    decode_context=Some(snapshot.context),
    loaded_source=Some({
      snapshot,
      window_start: start.to_int64(),
      selected: Some((offset.to_int64(), 7)),
    }),
  ).unwrap()
  match object.stream {
    Some(SelectedLoaded(_, definition)) => {
      assert_eq(definition.definition_offset, offset.to_int64())
      assert_eq(definition.payload_start, payload_start.to_int64())
    }
    _ => fail("a nonzero materialized window must retain absolute coordinates")
  }
  assert_eq(
    pdf_decode_stream_bytes(object, "nonzero window").unwrap(),
    b"window",
  )
}

///|
async test "selected Loaded incomplete origin proof preserves legacy repair instead of fabricating identity" {
  let (bytes, offset, _) = loaded_definition_test_file(b"legacy")
  let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
  defer @input.end_input_session(owner)
  let context = pdf_make_stream_decode_context(owner.source).unwrap()
  for
    (extent, window_start, selected) in [
      (0, 0L, None),
      (bytes.length(), -1L, None),
      (bytes.length(), 0L, Some((offset.to_int64(), 8))),
    ] {
    let object = pdf_parse_indirect_object_at(
      bytes,
      offset,
      decode_context=Some(context),
      loaded_source=Some({
        snapshot: { authority: Ref(false), source_size: extent, context, },
        window_start,
        selected,
      }),
    ).unwrap()
    assert_true(object.stream is Some(Loaded(_)))
    assert_eq(
      pdf_decode_stream_bytes(object, "legacy proof").unwrap(),
      b"legacy",
    )
  }
}

///|
async test "selected snapshot construction checks its original first failure before retaining metadata" {
  let (bytes, _, _) = loaded_definition_test_file(b"first failure")
  let owner = @input.begin_input_session(@input.input_from_bytes(bytes))
  @input.record_input_failure(owner.source, "snapshot first IO")
  let account = pdf_make_stream_decode_context(owner.source).unwrap().budget.account
  let before = account.snapshot()
  assert_true(
    loaded_definition_test_store(owner.source, bytes)
    is Err(ReadFailed("snapshot first IO")),
  )
  assert_eq(
    account.snapshot().resident.cache_bytes,
    before.resident.cache_bytes,
  )
  assert_true(account.snapshot().cumulative == before.cumulative)
  @input.end_input_session(owner)
  assert_eq(account.snapshot().active_leases, 0L)
}
