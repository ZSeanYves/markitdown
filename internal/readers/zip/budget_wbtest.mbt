///|
fn zip_budget_scope(
  inflate~ : Int64? = None,
  cache~ : Int64? = None,
  working~ : Int64? = None,
) -> (@budget.BudgetContext, Array[@budget.BudgetLease]) {
  let account = @budget.Budget::new(
    @budget.BudgetLimits::new(
      MeasurementOnly,
      inflate_bytes=inflate,
      parse_work=None,
      output_utf8_bytes=None,
      source_metadata_bytes=None,
      rag_metadata_bytes=None,
      read_traffic_bytes=None,
      cache_bytes=cache,
      working_bytes=working,
      temporary_bytes=None,
      ir_bytes=None,
    ).unwrap(),
  )
  let retained : Array[@budget.BudgetLease] = []
  let context = @budget.BudgetContext::new(account, fn(kind, amount) {
    match account.reserve(kind, amount) {
      Ok(lease) => {
        retained.push(lease)
        Ok(())
      }
      Err(error) => Err(error)
    }
  })
  (context, retained)
}

///|
fn zip_budget_scope_end(
  context : @budget.BudgetContext,
  retained : Array[@budget.BudgetLease],
) -> Unit raise {
  for lease in retained {
    lease.release()
  }
  assert_true(context.account.close() is Ok(_))
  let snapshot = context.account.snapshot()
  assert_eq(snapshot.resident.cache_bytes, 0L)
  assert_eq(snapshot.resident.working_bytes, 0L)
  assert_eq(snapshot.active_leases, 0L)
}

///|
fn zip_budget_set_u32(
  bytes : Array[Byte],
  start : Int32,
  value : Int32,
) -> Unit {
  for i in 0..<4 {
    bytes[start + i] = ((value >> (i * 8)) & 0xFF).to_byte()
  }
}

///|
fn zip_budget_fixture(
  payload : Bytes,
  deflated : Bool,
  bad_crc~ : Bool = false,
) -> Bytes {
  let compressed = if deflated { @flate.deflate_all(payload) } else { payload }
  let bytes = build_store_zip_bytes([("payload.bin", compressed)]).to_array()
  let central = 30 + "payload.bin".length() + compressed.length()
  let crc = if bad_crc { 0 } else { zip_builder_crc32(payload) }
  zip_budget_set_u32(bytes, 14, crc)
  zip_budget_set_u32(bytes, 22, payload.length())
  zip_budget_set_u32(bytes, central + 16, crc)
  zip_budget_set_u32(bytes, central + 24, payload.length())
  if deflated {
    bytes[8] = b'\x08'
    bytes[central + 10] = b'\x08'
  }
  Bytes::from_array(bytes)
}

///|
async test "ZIP cache hit does not inflate again or refund an escaped cache payload" {
  for deflated in [false, true] {
    let (context, retained) = zip_budget_scope()
    let archive = open_zip(
      zip_budget_fixture(b"payload", deflated),
      budget_context=context,
    )
    let first = read_entry(archive, "payload.bin")
    assert_eq(first, b"payload")
    assert_eq(context.account.snapshot().cumulative.inflate_bytes, 7L)
    assert_eq(context.account.snapshot().resident.cache_bytes, 7L)
    assert_eq(context.account.snapshot().resident.working_bytes, 0L)
    assert_eq(read_entry(archive, "payload.bin"), first)
    assert_eq(context.account.snapshot().cumulative.inflate_bytes, 7L)
    ignore(archive.read_entry_cache.remove("payload.bin"))
    assert_eq(first, b"payload")
    assert_eq(context.account.snapshot().resident.cache_bytes, 7L)
    zip_budget_scope_end(context, retained)
  }
}

///|
async test "ZIP transient reads retain escaped WorkingBytes but release their private scratch" {
  for deflated in [false, true] {
    let (context, retained) = zip_budget_scope()
    let archive = open_zip(
      zip_budget_fixture(b"payload", deflated),
      budget_context=context,
    )
    let first = read_entry_transient(archive, "payload.bin")
    let second = read_entry_transient(archive, "payload.bin")
    assert_eq(first, second)
    let snapshot = context.account.snapshot()
    assert_eq(snapshot.cumulative.inflate_bytes, 14L)
    assert_eq(snapshot.resident.cache_bytes, 0L)
    assert_eq(snapshot.resident.working_bytes, 14L)
    assert_eq(archive.read_entry_cache.length(), 0)
    zip_budget_scope_end(context, retained)
  }
}

///|
async test "ZIP visitor callback completion does not refund retained bare byte chunks" {
  for deflated in [false, true] {
    let (context, retained) = zip_budget_scope()
    let archive = open_zip(
      zip_budget_fixture(b"payload", deflated),
      budget_context=context,
    )
    let chunks : Array[Bytes] = []
    visit_inflated_entry_chunks(archive, "payload.bin", chunk_size=3, chunk => {
      chunks.push(chunk)
      Ok(())
    }).unwrap()
    assert_eq(chunks[0] + chunks[1] + chunks[2], b"payload")
    assert_eq(context.account.snapshot().cumulative.inflate_bytes, 7L)
    assert_eq(context.account.snapshot().resident.working_bytes, 7L)
    assert_eq(context.account.snapshot().resident.cache_bytes, 0L)
    zip_budget_scope_end(context, retained)
  }
}

///|
async test "ZIP all entry paths share aggregate inflate exhaustion and retain earlier charges" {
  for deflated in [false, true] {
    for mode in [0, 1, 2] {
      let (context, retained) = zip_budget_scope(inflate=Some(65536L))
      let archive = open_zip(
        zip_budget_fixture(Bytes::make(70000, b'A'), deflated),
        budget_context=context,
      )
      let rejected = if mode == 2 {
        visit_inflated_entry_chunks(archive, "payload.bin", _ => Ok(()))
        is Err(_)
      } else {
        try {
          if mode == 0 {
            ignore(read_entry(archive, "payload.bin"))
          } else {
            ignore(read_entry_transient(archive, "payload.bin"))
          }
          false
        } catch {
          BudgetExceeded(_) => true
          _ => false
        }
      }
      assert_true(rejected)
      match context.account.failure() {
        Some(
          @budget.LimitExceeded(
            Cumulative(InflateBytes),
            used~,
            requested~,
            limit~
          )
        ) => {
          assert_eq(used, 65536L)
          assert_eq(requested, 4464L)
          assert_eq(limit, 65536L)
        }
        _ => fail("inflate exhaustion must preserve its typed account failure")
      }
      assert_eq(context.account.snapshot().cumulative.inflate_bytes, 65536L)
      assert_eq(archive.read_entry_cache.length(), 0)
      assert_true(archive_hard_failure(archive) is Some(_))
      zip_budget_scope_end(context, retained)
    }
  }
}

///|
async test "ZIP resident reservation fails before decoded output allocation or inflation" {
  for mode in [0, 1, 2] {
    let (context, retained) = zip_budget_scope(
      cache=if mode == 0 { Some(3L) } else { None },
      working=if mode == 0 { None } else { Some(3L) },
    )
    let archive = open_zip(
      zip_budget_fixture(b"data", false),
      budget_context=context,
    )
    let rejected = if mode == 2 {
      visit_inflated_entry_chunks(archive, "payload.bin", _ => Ok(())) is Err(_)
    } else {
      try {
        if mode == 0 {
          ignore(read_entry(archive, "payload.bin"))
        } else {
          ignore(read_entry_transient(archive, "payload.bin"))
        }
        false
      } catch {
        BudgetExceeded(_) => true
        _ => false
      }
    }
    assert_true(rejected)
    match context.account.failure() {
      Some(@budget.LimitExceeded(dimension, used~, requested~, limit~)) => {
        assert_true(dimension is Resident(_))
        assert_eq(used, 0L)
        assert_true(requested >= 4L)
        assert_eq(limit, 3L)
      }
      _ => fail("resident capacity must fail with its typed limit dimension")
    }
    assert_eq(context.account.snapshot().cumulative.inflate_bytes, 0L)
    assert_eq(archive.read_entry_cache.length(), 0)
    zip_budget_scope_end(context, retained)
  }
}

///|
async test "ZIP CRC failures share one typed integrity core and never populate a payload cache" {
  for mode in [0, 1, 2] {
    let (context, retained) = zip_budget_scope()
    let archive = open_zip(
      zip_budget_fixture(b"data", true, bad_crc=true),
      budget_context=context,
    )
    let rejected = if mode == 2 {
      visit_inflated_entry_chunks(archive, "payload.bin", _ => Ok(())) is Err(_)
    } else {
      try {
        if mode == 0 {
          ignore(read_entry(archive, "payload.bin"))
        } else {
          ignore(read_entry_transient(archive, "payload.bin"))
        }
        false
      } catch {
        ChecksumMismatch("payload.bin", 0, _) => true
        _ => false
      }
    }
    assert_true(rejected)
    assert_eq(context.account.snapshot().cumulative.inflate_bytes, 4L)
    assert_true(context.account.failure() is None)
    assert_true(archive_hard_failure(archive) is Some(_))
    assert_eq(archive.read_entry_cache.length(), 0)
    zip_budget_scope_end(context, retained)
  }
}

///|
async test "ZIP consumer rejection preserves syntax fallback without caching a reusable failure" {
  let (context, retained) = zip_budget_scope()
  let archive = open_zip(
    zip_budget_fixture(b"data", false),
    budget_context=context,
  )
  assert_true(
    visit_inflated_entry_chunks(archive, "payload.bin", chunk_size=2, _ => {
      Err("unsupported consumer shape")
    })
    is Err(_),
  )
  assert_eq(context.account.snapshot().cumulative.inflate_bytes, 2L)
  assert_eq(context.account.snapshot().resident.working_bytes, 2L)
  assert_true(archive_hard_failure(archive) is None)
  assert_eq(read_entry(archive, "payload.bin"), b"data")
  assert_eq(context.account.snapshot().cumulative.inflate_bytes, 6L)
  zip_budget_scope_end(context, retained)
}

///|
async test "ZIP child archives borrow the parent's aggregate inflate account" {
  let inner = zip_budget_fixture(b"data", false)
  let (context, retained) = zip_budget_scope(
    inflate=Some(inner.length().to_int64() + 3L),
  )
  let parent = open_zip(
    build_store_zip_bytes([("child.zip", inner)]),
    budget_context=context,
  )
  let child_bytes = read_entry(parent, "child.zip")
  let child = open_zip(child_bytes, budget_context=context)
  let rejected = try {
    ignore(read_entry(child, "payload.bin"))
    false
  } catch {
    BudgetExceeded(_) => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(
    context.account.snapshot().cumulative.inflate_bytes,
    inner.length().to_int64(),
  )
  assert_eq(child.read_entry_cache.length(), 0)
  zip_budget_scope_end(context, retained)
}

///|
fn zip_budget_partial_error_fixture() -> Bytes {
  let compressed = b"\x00\x01\x00\xfe\xffA\x07"
  let bytes = build_store_zip_bytes([("payload.bin", compressed)]).to_array()
  let central = 30 + "payload.bin".length() + compressed.length()
  let crc = zip_builder_crc32(b"A")
  bytes[8] = b'\x08'
  bytes[central + 10] = b'\x08'
  zip_budget_set_u32(bytes, 14, crc)
  zip_budget_set_u32(bytes, 22, 1)
  zip_budget_set_u32(bytes, central + 16, crc)
  zip_budget_set_u32(bytes, central + 24, 1)
  Bytes::from_array(bytes)
}

///|
async test "ZIP charges failed-step physical output without delivering it and preserves budget error priority" {
  for limited in [false, true] {
    for mode in [0, 1, 2] {
      let (context, retained) = zip_budget_scope(
        inflate=if limited { Some(0L) } else { None },
      )
      let archive = open_zip(
        zip_budget_partial_error_fixture(),
        budget_context=context,
      )
      let delivered = Ref(0)
      let rejected = if mode == 2 {
        visit_inflated_entry_chunks(archive, "payload.bin", chunk => {
          delivered.val += chunk.length()
          Ok(())
        })
        is Err(_)
      } else {
        try {
          if mode == 0 {
            ignore(read_entry(archive, "payload.bin"))
          } else {
            ignore(read_entry_transient(archive, "payload.bin"))
          }
          false
        } catch {
          BudgetExceeded(_) if limited => true
          DecodeFailed(_) if !limited => true
          _ => false
        }
      }
      assert_true(rejected)
      assert_eq(delivered.val, 0)
      assert_eq(
        context.account.snapshot().cumulative.inflate_bytes,
        if limited {
          0L
        } else {
          1L
        },
      )
      if limited {
        match context.account.failure() {
          Some(
            @budget.LimitExceeded(
              Cumulative(InflateBytes),
              used~,
              requested~,
              limit~
            )
          ) => {
            assert_eq(used, 0L)
            assert_eq(requested, 1L)
            assert_eq(limit, 0L)
          }
          _ =>
            fail(
              "partial failed output must be charged before returning the codec error",
            )
        }
      } else {
        assert_true(context.account.failure() is None)
      }
      assert_eq(archive.read_entry_cache.length(), 0)
      assert_true(archive_hard_failure(archive) is Some(_))
      zip_budget_scope_end(context, retained)
    }
  }
}
