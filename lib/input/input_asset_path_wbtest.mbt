///|
async test "asset path factory preserves failed and closed parent ownership without opens or reads" {
  for closed in [false, true] {
    let session = begin_input_session(input_from_bytes(b"x"), max_bytes=1L)
    defer end_input_session(session)
    if closed {
      end_input_session(session)
    } else {
      record_input_resource_failure(
        session.source,
        make_resource_limit_failure(SingleAssetBytes, 3L, 2L),
      )
    }
    let child = input_from_asset_path(
      session.source,
      "/no-asset-parent/missing.bin",
      asset_limit=3L,
    )
    assert_true(child.physical_bytes is None)
    assert_eq(child.derived_entry_limit, Some(3L))
    assert_eq(child.byte_limit, Some(3L))
    assert_true(
      physical_equal(
        child.session.unwrap().closed,
        session.source.session.unwrap().closed,
      ),
    )
    assert_true(input_source_size(child) is Err(_))
    assert_eq(session.source.session.unwrap().cursors.length(), 0)
    assert_eq(
      input_source_budget_context(child).unwrap().account.snapshot().cumulative.read_traffic_bytes,
      0L,
    )
    if !closed {
      assert_true(input_source_failure(child) is Some(ResourceLimit(_)))
      assert_true(
        input_source_failure(session.source) is Some(ResourceLimit(_)),
      )
    }
  }
}
