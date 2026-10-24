///|
fn resident_limit_of(
  limits : @resource_budget.BudgetLimits,
  kind : @resource_budget.ResidentKind,
) -> Int64? {
  match kind {
    CacheBytes => limits.cache_bytes
    WorkingBytes => limits.working_bytes
    TemporaryBytes => limits.temporary_bytes
    IrBytes => limits.ir_bytes
  }
}

///|
test "tightening resident limits shares the ledger and freezes prior snapshots" {
  for
    kind in [
      @resource_budget.ResidentKind::CacheBytes,
      WorkingBytes,
      TemporaryBytes,
      IrBytes,
    ] {
    let account = @resource_budget.Budget::new(
      @resource_budget.BudgetLimits::measurement_only(),
    )
    let borrowed = account
    account.charge(ParseWork, 3L).unwrap()
    let lease = account.reserve(kind, 2L).unwrap()
    let before = account.snapshot()
    borrowed.tighten_resident_limit(kind, 2L).unwrap()
    let after = account.snapshot()
    assert_true(resident_limit_of(before.limits, kind) is None)
    assert_true(resident_limit_of(after.limits, kind) == Some(2L))
    assert_true(after.limits.profile == MeasurementOnly)
    assert_true(after.cumulative == before.cumulative)
    assert_true(after.resident == before.resident)
    assert_true(after.resident_peak == before.resident_peak)
    assert_eq(after.active_leases, 1L)
    assert_true(after.first_error is None)
    // A larger nested request retains the original effective boundary.
    account.tighten_resident_limit(kind, 9L).unwrap()
    assert_true(resident_limit_of(borrowed.snapshot().limits, kind) == Some(2L))
    assert_true(
      borrowed.reserve(kind, 1L)
      is Err(LimitExceeded(Resident(actual), used=2L, requested=1L, limit=2L)) &&
      actual == kind,
    )
    assert_true(before.first_error is None)
    lease.release()
    assert_eq(account.snapshot().active_leases, 0L)
    account.close().unwrap()
  }
}

///|
test "an already used resident cap rejects without changing limits or existing leases" {
  for
    kind in [
      @resource_budget.ResidentKind::CacheBytes,
      WorkingBytes,
      TemporaryBytes,
      IrBytes,
    ] {
    let account = @resource_budget.Budget::new(
      @resource_budget.BudgetLimits::measurement_only(),
    )
    let lease = account.reserve(kind, 6L).unwrap()
    let before = account.snapshot()
    assert_true(
      account.tighten_resident_limit(kind, 5L)
      is Err(LimitExceeded(Resident(actual), used=6L, requested=0L, limit=5L)) &&
      actual == kind,
    )
    let failed = account.snapshot()
    assert_true(failed.limits == before.limits)
    assert_true(failed.resident == before.resident)
    assert_true(failed.resident_peak == before.resident_peak)
    assert_eq(failed.active_leases, before.active_leases)
    let first = account.failure().unwrap()
    assert_true(
      account.tighten_resident_limit(kind, 8L) is Err(error) && error == first,
    )
    lease.release()
    assert_eq(account.snapshot().active_leases, 0L)
    assert_true(account.snapshot().limits == before.limits)
    account.close().unwrap()
  }
}

///|
test "tightening below a released historical peak preserves the peak and other dimensions" {
  let account = @resource_budget.Budget::new(
    @resource_budget.BudgetLimits::measurement_only(),
  )
  let lease = account.reserve(TemporaryBytes, 8L).unwrap()
  lease.release()
  account.tighten_resident_limit(TemporaryBytes, 1L).unwrap()
  let sample = account.snapshot()
  assert_eq(sample.resident.temporary_bytes, 0L)
  assert_eq(sample.resident_peak.temporary_bytes, 8L)
  assert_true(sample.limits.temporary_bytes == Some(1L))
  assert_true(sample.limits.cache_bytes is None)
  assert_true(sample.limits.working_bytes is None)
  assert_true(sample.limits.ir_bytes is None)
  assert_true(sample.limits.parse_work is None)
  account.reserve(TemporaryBytes, 1L).unwrap().release()
  account.close().unwrap()
}

///|
test "zero resident limit permits zero reservations without creating a lease" {
  let account = @resource_budget.Budget::new(
    @resource_budget.BudgetLimits::measurement_only(),
  )
  account.tighten_resident_limit(TemporaryBytes, 0L).unwrap()
  account.reserve(TemporaryBytes, 0L).unwrap().release()
  assert_eq(account.snapshot().active_leases, 0L)
  assert_true(
    account.reserve(TemporaryBytes, 1L)
    is Err(
      LimitExceeded(Resident(TemporaryBytes), used=0L, requested=1L, limit=0L)
    ),
  )
  account.close().unwrap()
}

///|
test "negative and closed tightening requests preserve first failure and previous limits" {
  let account = @resource_budget.Budget::new(
    @resource_budget.BudgetLimits::measurement_only(),
  )
  let before = account.snapshot()
  assert_true(
    account.tighten_resident_limit(CacheBytes, -1L)
    is Err(InvalidLimit(Resident(CacheBytes), -1L)),
  )
  let first = account.failure().unwrap()
  assert_true(
    account.tighten_resident_limit(TemporaryBytes, 0L) is Err(error) &&
    error == first,
  )
  assert_true(account.snapshot().limits == before.limits)
  account.close().unwrap()
  assert_true(
    account.tighten_resident_limit(CacheBytes, 0L) is Err(error) &&
    error == first,
  )
  let closed = @resource_budget.Budget::new(
    @resource_budget.BudgetLimits::measurement_only(),
  )
  closed.close().unwrap()
  assert_true(closed.tighten_resident_limit(CacheBytes, -1L) is Err(Closed))
  assert_true(closed.snapshot().limits == before.limits)
}

///|
test "a previous cumulative error is not reset by tightening or releasing resident storage" {
  let account = @resource_budget.Budget::new(
    @resource_budget.BudgetLimits::measurement_only(),
  )
  let lease = account.reserve(TemporaryBytes, 3L).unwrap()
  assert_true(account.charge(ParseWork, -1L) is Err(_))
  let first = account.failure().unwrap()
  let before = account.snapshot()
  assert_true(
    account.tighten_resident_limit(TemporaryBytes, 2L) is Err(error) &&
    error == first,
  )
  assert_true(account.snapshot().limits == before.limits)
  lease.release()
  assert_true(account.failure() == Some(first))
  account.close().unwrap()
}

///|
test "tightening an enforced account changes only the selected finite resident cap" {
  let limits = @resource_budget.BudgetLimits::new(
    Enforced,
    inflate_bytes=Some(10L),
    parse_work=Some(10L),
    output_utf8_bytes=Some(10L),
    source_metadata_bytes=Some(10L),
    rag_metadata_bytes=Some(10L),
    read_traffic_bytes=Some(10L),
    cache_bytes=Some(10L),
    working_bytes=Some(10L),
    temporary_bytes=Some(10L),
    ir_bytes=Some(10L),
  ).unwrap()
  let account = @resource_budget.Budget::new(limits)
  account.tighten_resident_limit(TemporaryBytes, 4L).unwrap()
  let current = account.snapshot().limits
  assert_true(current.profile == Enforced)
  assert_true(current.inflate_bytes == limits.inflate_bytes)
  assert_true(current.parse_work == limits.parse_work)
  assert_true(current.output_utf8_bytes == limits.output_utf8_bytes)
  assert_true(current.source_metadata_bytes == limits.source_metadata_bytes)
  assert_true(current.rag_metadata_bytes == limits.rag_metadata_bytes)
  assert_true(current.read_traffic_bytes == limits.read_traffic_bytes)
  assert_true(current.cache_bytes == limits.cache_bytes)
  assert_true(current.working_bytes == limits.working_bytes)
  assert_true(current.temporary_bytes == Some(4L))
  assert_true(current.ir_bytes == limits.ir_bytes)
  account.close().unwrap()
}
