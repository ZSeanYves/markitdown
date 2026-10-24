///|
// Only the declared extent is large; the complete compressed payload is tiny.
// A zero inflate budget rejects the first produced bytes before any consumer
// callback or declared-size mismatch can occur.
fn visitor_large_declared_fixture(deflated : Bool) -> Bytes {
  let bytes = zip_budget_fixture(b"abcd", deflated).to_array()
  let compressed_length = if deflated {
    @flate.deflate_all(b"abcd").length()
  } else {
    4
  }
  let central = 30 + "payload.bin".length() + compressed_length
  let declared = 128 * 1024 * 1024 + 1
  zip_budget_set_u32(bytes, 22, declared)
  zip_budget_set_u32(bytes, central + 24, declared)
  Bytes::from_array(bytes)
}

///|
async test "omitted visitor cap preserves declared extent while explicit cap rejects before inflate" {
  for deflated in [false, true] {
    for explicit_cap in [false, true] {
      let bytes = visitor_large_declared_fixture(deflated)
      let reads = Ref(0)
      let (context, retained) = zip_budget_scope(inflate=Some(0L))
      let archive = open_zip_reader(
        bytes.length(),
        fn(offset, length) {
          reads.val += 1
          Ok(bytes[offset:offset + length].to_owned())
        },
        budget_context=context,
      )
      let delivered = Ref(0)
      let result = if explicit_cap {
        visit_inflated_entry_chunks(
          archive,
          "payload.bin",
          max_output_size=128 * 1024 * 1024,
          chunk => {
            delivered.val += chunk.length()
            Ok(())
          },
        )
      } else {
        visit_inflated_entry_chunks(archive, "payload.bin", chunk => {
          delivered.val += chunk.length()
          Ok(())
        })
      }
      guard result is Err(message) else {
        fail("large virtual entry must reject")
      }
      assert_eq(delivered.val, 0)
      assert_eq(context.account.snapshot().cumulative.inflate_bytes, 0L)
      if explicit_cap {
        assert_true(
          message.contains("max_output_size: max=134217728, actual=134217729"),
        )
        assert_true(context.account.failure() is None)
      } else {
        match context.account.failure() {
          Some(
            LimitExceeded(Cumulative(InflateBytes), used~, requested~, limit~)
          ) => {
            assert_eq(used, 0L)
            assert_eq(requested, 4L)
            assert_eq(limit, 0L)
          }
          _ => fail("omitted cap must reach the shared produced-byte budget")
        }
      }
      let failed_reads = reads.val
      assert_true(
        visit_inflated_entry_chunks(archive, "payload.bin", _ => Ok(()))
        is Err(_),
      )
      assert_eq(reads.val, failed_reads)
      assert_true(archive_hard_failure(archive) is Some(_))
      zip_budget_scope_end(context, retained)
    }
  }
}

///|
async test "collecting ZIP reads retain their existing 128MiB default" {
  for transient in [false, true] {
    let archive = open_zip(visitor_large_declared_fixture(true))
    let result = try {
      if transient {
        ignore(read_entry_transient(archive, "payload.bin"))
      } else {
        ignore(read_entry(archive, "payload.bin"))
      }
      false
    } catch {
      InvalidStructure(message) =>
        message.contains("max_output_size: max=134217728, actual=134217729")
      _ => false
    }
    assert_true(result)
    assert_eq(archive.read_entry_cache.length(), 0)
  }
}

///|
async test "slice visitor shares omitted cap semantics and still charges first produced bytes" {
  for explicit_cap in [false, true] {
    let bytes = visitor_large_declared_fixture(true)
    let archive = open_zip(bytes)
    let slice = read_entry_data_slice(archive, "payload.bin")
    let (context, retained) = zip_budget_scope(inflate=Some(0L))
    let delivered = Ref(0)
    let result = if explicit_cap {
      visit_inflated_entry_chunks_from_slice(
        bytes,
        slice,
        budget_context=context,
        max_output_size=128 * 1024 * 1024,
        chunk => {
          delivered.val += chunk.length()
          Ok(())
        },
      )
    } else {
      visit_inflated_entry_chunks_from_slice(
        bytes,
        slice,
        budget_context=context,
        chunk => {
          delivered.val += chunk.length()
          Ok(())
        },
      )
    }
    assert_true(result is Err(_))
    assert_eq(delivered.val, 0)
    assert_eq(context.account.snapshot().cumulative.inflate_bytes, 0L)
    assert_eq(context.account.failure() is Some(_), !explicit_cap)
    zip_budget_scope_end(context, retained)
  }
}
